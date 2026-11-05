import { describe, it, expect } from 'vitest';
import type { Coordinate } from '@/types/geo';
import {
  calculateBearing,
  calculateCentroid,
  calculateDistance,
  isPointInPolygon,
} from '@/utils/geo';
import { createSeededRandom } from '@/utils/random';
import { AREA_CONFIG } from './config';
import { generateLayout } from './layout';
import { generateSquareFacing, generateSquareVertices } from './squares';

const CENTER: Coordinate = { latitude: 23.8, longitude: 121.0 };
const SEEDS = [1, 2, 3, 7, 11, 42, 1337, 20260831];

// ============================================================================
// SQUARES
// ============================================================================
describe('generateSquareVertices', () => {
  it('produces 4 vertices at the square half-diagonal', () => {
    const size = 0.3;
    const vertices = generateSquareVertices(CENTER, size, 0);
    expect(vertices).toHaveLength(4);
    const halfDiagonal = (Math.sqrt(2) * size) / 2;
    for (const vertex of vertices) {
      expect(calculateDistance(CENTER, vertex)).toBeCloseTo(halfDiagonal, 6);
    }
  });

  it('keeps its centroid at the requested center under rotation', () => {
    for (const angle of [0, 45, 90, 217]) {
      const center = calculateCentroid(generateSquareVertices(CENTER, 0.3, angle));
      expect(center.latitude).toBeCloseTo(CENTER.latitude, 5);
      expect(center.longitude).toBeCloseTo(CENTER.longitude, 5);
    }
  });
});

describe('generateSquareFacing', () => {
  it('rotates the square so an edge faces the deployment center', () => {
    const position: Coordinate = { latitude: 23.85, longitude: 121.0 };
    const facing = generateSquareFacing(position, 0.3, CENTER);
    const expected = generateSquareVertices(position, 0.3, calculateBearing(position, CENTER));
    expect(facing).toEqual(expected);
  });
});

// ============================================================================
// LAYOUT INVARIANTS
// ============================================================================
describe('generateLayout', () => {
  it('is reproducible for a given seed', () => {
    const a = generateLayout(CENTER, 90, {}, createSeededRandom(42));
    const b = generateLayout(CENTER, 90, {}, createSeededRandom(42));
    expect(a).toEqual(b);
  });

  it.each([
    ['center', { latitude: NaN, longitude: CENTER.longitude }, 90],
    ['openingAngle', CENTER, NaN],
  ])('throws on a non-finite %s', (_name, center, angle) => {
    expect(() => generateLayout(center, angle, {}, createSeededRandom(1))).toThrow();
  });

  it('builds the boundary as a 4-corner rectangle around the center', () => {
    const { uShapeVertices } = generateLayout(CENTER, 90, {}, createSeededRandom(5));
    expect(uShapeVertices).toHaveLength(4);

    const halfDiagonal = Math.hypot(AREA_CONFIG.width / 2, AREA_CONFIG.height / 2);
    for (const vertex of uShapeVertices) {
      expect(calculateDistance(CENTER, vertex)).toBeCloseTo(halfDiagonal, 5);
    }
    const center = calculateCentroid(uShapeVertices);
    expect(center.latitude).toBeCloseTo(CENTER.latitude, 5);
    expect(center.longitude).toBeCloseTo(CENTER.longitude, 5);
  });

  describe.each(SEEDS)('seed %i', (seed) => {
    describe.each([0, 90, 180, 270])('opening angle %i', (angle) => {
      const layout = generateLayout(CENTER, angle, {}, createSeededRandom(seed));

      it('keeps HA and RL inside the boundary', () => {
        for (const area of [layout.hideArea, layout.reloadArea]) {
          expect(area).toHaveLength(4);
          for (const vertex of area) {
            expect(isPointInPolygon(vertex, layout.uShapeVertices)).toBe(true);
          }
        }
      });

      it('does not overlap HA with RL', () => {
        const gap = calculateDistance(
          calculateCentroid(layout.hideArea),
          calculateCentroid(layout.reloadArea)
        );
        const { size, marginBetweenSquares } = AREA_CONFIG.internalSquares;
        expect(gap).toBeGreaterThanOrEqual(size + marginBetweenSquares - 1e-9);
      });

      it('keeps HA and RL off the boundary wall', () => {
        const halfWidth = AREA_CONFIG.width / 2;
        const halfHeight = AREA_CONFIG.height / 2;
        const minMargin = AREA_CONFIG.internalSquares.marginToWall;
        for (const area of [layout.hideArea, layout.reloadArea]) {
          for (const vertex of area) {
            // Project the vertex onto the boundary's own axes.
            const range = calculateDistance(CENTER, vertex);
            const bearing = calculateBearing(CENTER, vertex);
            const local = ((bearing - angle) * Math.PI) / 180;
            const alongHeight = Math.abs(range * Math.cos(local));
            const alongWidth = Math.abs(range * Math.sin(local));
            // marginToWall applies to the square center; a vertex may sit up to
            // half a square closer, so allow that slack explicitly.
            const slack = AREA_CONFIG.internalSquares.size / 2;
            expect(alongHeight).toBeLessThanOrEqual(halfHeight - minMargin + slack + 1e-6);
            expect(alongWidth).toBeLessThanOrEqual(halfWidth - minMargin + slack + 1e-6);
          }
        }
      });

      it('places the requested number of fire points on the FP radius', () => {
        expect(layout.firePoints).toHaveLength(AREA_CONFIG.firePoints.count);
        for (const firePoint of layout.firePoints) {
          expect(firePoint).toHaveLength(4);
          const range = calculateDistance(CENTER, calculateCentroid(firePoint));
          expect(range).toBeCloseTo(AREA_CONFIG.firePoints.radius, 3);
        }
      });

      it('keeps fire points inside the configured angular sector', () => {
        // The sector is centred on the back side of the boundary (openingAngle + 180).
        const sectorCenter = (angle + 180) % 360;
        const halfRange = AREA_CONFIG.firePoints.angleRange / 2;
        for (const firePoint of layout.firePoints) {
          const bearing = calculateBearing(CENTER, calculateCentroid(firePoint));
          const delta = Math.abs(((bearing - sectorCenter + 540) % 360) - 180);
          expect(delta).toBeLessThanOrEqual(halfRange + 1e-6);
        }
      });

      it('keeps fire points apart from each other', () => {
        const [first, second] = layout.firePoints;
        const gap = calculateDistance(calculateCentroid(first), calculateCentroid(second));
        expect(gap).toBeGreaterThanOrEqual(
          AREA_CONFIG.firePoints.squareSize + AREA_CONFIG.firePoints.margin - 1e-9
        );
      });

      it('keeps fire points outside the boundary', () => {
        for (const firePoint of layout.firePoints) {
          for (const vertex of firePoint) {
            expect(isPointInPolygon(vertex, layout.uShapeVertices)).toBe(false);
          }
        }
      });

      it('puts the ATP area on the ATP radius', () => {
        expect(layout.atpArea).toHaveLength(4);
        const range = calculateDistance(CENTER, calculateCentroid(layout.atpArea));
        expect(range).toBeCloseTo(AREA_CONFIG.atp.radius, 3);
      });
    });
  });

  it('honours an explicit ATP radius', () => {
    const layout = generateLayout(CENTER, 90, { atpRadius: 4 }, createSeededRandom(3));
    const range = calculateDistance(CENTER, calculateCentroid(layout.atpArea));
    expect(range).toBeCloseTo(4, 3);
  });

  it('honours an explicit ATP center', () => {
    const atpCenter: Coordinate = { latitude: 24.2, longitude: 121.3 };
    const layout = generateLayout(CENTER, 90, { atpCenter }, createSeededRandom(3));
    const center = calculateCentroid(layout.atpArea);
    expect(center.latitude).toBeCloseTo(atpCenter.latitude, 5);
    expect(center.longitude).toBeCloseTo(atpCenter.longitude, 5);
  });
});
