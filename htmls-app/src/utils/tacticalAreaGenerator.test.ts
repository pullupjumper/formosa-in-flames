import { describe, it, expect } from 'vitest';
import {
  calculateDistance,
  calculateBearing,
  getPointFromBearing,
  generateSquareVertices,
  generateUShapeVertices,
  generateShelterPoints,
  selectFpGateway,
  selectShrlGateway,
  calculateMovementPaths,
} from '@/utils/tacticalAreaGenerator';
import type { Coordinate } from '@/types/geo';
import { calculateCentroid, isPointInPolygon } from '@/utils/geo';
import { AREA_CONFIG, MOVEMENT_PATH_AVOIDANCE_MARGIN } from '@/utils/missileDeployment';
import { createSeededRandom } from '@/utils/random';

// ============================================================================
// FIXTURES
// ============================================================================
const CENTER: Coordinate = { latitude: 23.8, longitude: 121.0 };
const SEEDS = [1, 2, 3, 7, 11, 42, 1337, 20260831];

function buildAreaConfig(openingAngle: number) {
  return { center: CENTER, openingAngle, ...AREA_CONFIG };
}

function at(latitude: number, longitude: number): Coordinate {
  return { latitude, longitude };
}

// ============================================================================
// GEO PRIMITIVES
// ============================================================================
describe('calculateDistance', () => {
  it('is zero for identical points', () => {
    expect(calculateDistance(CENTER, CENTER)).toBe(0);
  });

  it('matches one nautical mile per latitude minute', () => {
    expect(calculateDistance(CENTER, at(23.8 + 1 / 60, 121))).toBeCloseTo(1, 2);
  });

  it('is symmetric', () => {
    const forward = calculateDistance(at(23.8, 121), at(24.2, 120.6));
    const backward = calculateDistance(at(24.2, 120.6), at(23.8, 121));
    expect(forward).toBeCloseTo(backward, 10);
  });
});

describe('calculateBearing', () => {
  it.each([
    ['north', 24.0, 121.0, 0],
    ['east', 23.8, 121.2, 90],
    ['south', 23.6, 121.0, 180],
    ['west', 23.8, 120.8, 270],
  ])('reports %s', (_label, latitude, longitude, expected) => {
    expect(calculateBearing(CENTER, at(latitude, longitude))).toBeCloseTo(expected, 1);
  });

  it('always returns a value in [0, 360)', () => {
    for (let i = 0; i < 360; i += 7) {
      const point = getPointFromBearing(CENTER, i, 2);
      const bearing = calculateBearing(CENTER, point);
      expect(bearing).toBeGreaterThanOrEqual(0);
      expect(bearing).toBeLessThan(360);
    }
  });
});

describe('getPointFromBearing', () => {
  it('round-trips through calculateDistance/calculateBearing', () => {
    for (const bearing of [0, 37, 123, 271, 359]) {
      const point = getPointFromBearing(CENTER, bearing, 3);
      expect(calculateDistance(CENTER, point)).toBeCloseTo(3, 6);
      expect(calculateBearing(CENTER, point)).toBeCloseTo(bearing, 4);
    }
  });
});

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

// ============================================================================
// U-SHAPE LAYOUT INVARIANTS
// ============================================================================
describe('generateUShapeVertices', () => {
  it('is reproducible for a given seed', () => {
    const a = generateUShapeVertices(buildAreaConfig(90), createSeededRandom(42));
    const b = generateUShapeVertices(buildAreaConfig(90), createSeededRandom(42));
    expect(a).toEqual(b);
  });

  it.each([
    ['center.latitude', { center: at(0, CENTER.longitude) }],
    ['center.longitude', { center: at(CENTER.latitude, 0) }],
    ['width', { width: 0 }],
    ['height', { height: 0 }],
  ])('throws when %s is missing', (name, override) => {
    expect(() =>
      generateUShapeVertices({ ...buildAreaConfig(90), ...override }, createSeededRandom(1))
    ).toThrow(new RegExp(name.replace('.', '\\.')));
  });

  it('builds the boundary as a 4-corner rectangle around the center', () => {
    const { uShapeVertices } = generateUShapeVertices(buildAreaConfig(90), createSeededRandom(5));
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
      const result = generateUShapeVertices(buildAreaConfig(angle), createSeededRandom(seed));

      it('keeps HA and RL inside the boundary', () => {
        for (const area of [result.hideArea!, result.reloadArea!]) {
          expect(area).toHaveLength(4);
          for (const vertex of area) {
            expect(isPointInPolygon(vertex, result.uShapeVertices)).toBe(true);
          }
        }
      });

      it('does not overlap HA with RL', () => {
        const gap = calculateDistance(
          calculateCentroid(result.hideArea!),
          calculateCentroid(result.reloadArea!)
        );
        const { size, marginBetweenSquares } = AREA_CONFIG.internalSquares;
        expect(gap).toBeGreaterThanOrEqual(size + marginBetweenSquares - 1e-9);
      });

      it('keeps HA and RL off the boundary wall', () => {
        const halfWidth = AREA_CONFIG.width / 2;
        const halfHeight = AREA_CONFIG.height / 2;
        const minMargin = AREA_CONFIG.internalSquares.marginToWall;
        for (const area of [result.hideArea!, result.reloadArea!]) {
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
        expect(result.firePoints).toHaveLength(AREA_CONFIG.firePoints.count);
        for (const firePoint of result.firePoints!) {
          expect(firePoint).toHaveLength(4);
          const range = calculateDistance(CENTER, calculateCentroid(firePoint));
          expect(range).toBeCloseTo(AREA_CONFIG.firePoints.radius, 3);
        }
      });

      it('keeps fire points inside the configured angular sector', () => {
        // The sector is centred on the back side of the U-shape (openingAngle + 180).
        const sectorCenter = (angle + 180) % 360;
        const halfRange = AREA_CONFIG.firePoints.angleRange / 2;
        for (const firePoint of result.firePoints!) {
          const bearing = calculateBearing(CENTER, calculateCentroid(firePoint));
          const delta = Math.abs(((bearing - sectorCenter + 540) % 360) - 180);
          expect(delta).toBeLessThanOrEqual(halfRange + 1e-6);
        }
      });

      it('keeps fire points apart from each other', () => {
        const [first, second] = result.firePoints!;
        const gap = calculateDistance(calculateCentroid(first), calculateCentroid(second));
        expect(gap).toBeGreaterThanOrEqual(
          AREA_CONFIG.firePoints.squareSize + AREA_CONFIG.firePoints.margin - 1e-9
        );
      });

      it('keeps fire points outside the boundary', () => {
        for (const firePoint of result.firePoints!) {
          for (const vertex of firePoint) {
            expect(isPointInPolygon(vertex, result.uShapeVertices)).toBe(false);
          }
        }
      });

      it('puts the ammo area on the AHA radius', () => {
        expect(result.ammoArea).toHaveLength(4);
        const range = calculateDistance(CENTER, calculateCentroid(result.ammoArea!));
        expect(range).toBeCloseTo(AREA_CONFIG.ahaPoint.radius, 3);
      });
    });
  });

  it('honours an explicit AHA center override', () => {
    const override = at(24.2, 121.3);
    const result = generateUShapeVertices(
      {
        ...buildAreaConfig(90),
        ahaPoint: { ...AREA_CONFIG.ahaPoint, center: override },
      },
      createSeededRandom(3)
    );
    const center = calculateCentroid(result.ammoArea!);
    expect(center.latitude).toBeCloseTo(override.latitude, 5);
    expect(center.longitude).toBeCloseTo(override.longitude, 5);
  });

  it('omits optional areas when their config is absent', () => {
    const result = generateUShapeVertices(
      {
        center: CENTER,
        width: AREA_CONFIG.width,
        height: AREA_CONFIG.height,
        openingAngle: 90,
      },
      createSeededRandom(1)
    );
    expect(result.uShapeVertices).toHaveLength(4);
    expect(result.hideArea).toBeUndefined();
    expect(result.reloadArea).toBeUndefined();
    expect(result.firePoints).toBeUndefined();
    expect(result.ammoArea).toBeUndefined();
  });
});

// ============================================================================
// SHELTER POINTS
// ============================================================================
describe('generateShelterPoints', () => {
  function shelterConfig(seed: number, avoidAreas: Coordinate[][] = []) {
    return {
      center: CENTER,
      areaWidth: AREA_CONFIG.width,
      areaHeight: AREA_CONFIG.height,
      openingAngle: 90,
      avoidAreas,
      count: AREA_CONFIG.shelter.count,
      marginToWall: AREA_CONFIG.shelter.marginToWall,
      marginToAreas: AREA_CONFIG.shelter.marginToAreas,
      marginBetweenPoints: AREA_CONFIG.shelter.marginBetweenPoints,
      rng: createSeededRandom(seed),
    };
  }

  it.each(SEEDS)('places the requested count inside the boundary (seed %i)', (seed) => {
    const layout = generateUShapeVertices(buildAreaConfig(90), createSeededRandom(seed));
    const points = generateShelterPoints(
      shelterConfig(seed, [layout.hideArea!, layout.reloadArea!])
    );

    expect(points).toHaveLength(AREA_CONFIG.shelter.count);
    for (const point of points) {
      expect(isPointInPolygon(point, layout.uShapeVertices)).toBe(true);
    }
  });

  it.each(SEEDS)('keeps shelters apart and clear of HA/RL (seed %i)', (seed) => {
    const layout = generateUShapeVertices(buildAreaConfig(90), createSeededRandom(seed));
    const points = generateShelterPoints(
      shelterConfig(seed, [layout.hideArea!, layout.reloadArea!])
    );

    expect(calculateDistance(points[0], points[1])).toBeGreaterThanOrEqual(
      AREA_CONFIG.shelter.marginBetweenPoints - 1e-9
    );
    for (const point of points) {
      expect(isPointInPolygon(point, layout.hideArea!)).toBe(false);
      expect(isPointInPolygon(point, layout.reloadArea!)).toBe(false);
    }
  });

  it('returns nothing when the wall margin leaves no room', () => {
    expect(generateShelterPoints({ ...shelterConfig(1), marginToWall: AREA_CONFIG.width })).toEqual(
      []
    );
  });

  it('returns nothing for a non-positive count', () => {
    expect(generateShelterPoints({ ...shelterConfig(1), count: 0 })).toEqual([]);
  });
});

// ============================================================================
// GATEWAYS AND PATHS
// ============================================================================
describe('gateways', () => {
  it('returns null when there are no shelters to serve', () => {
    const layout = generateUShapeVertices(buildAreaConfig(90), createSeededRandom(9));
    const base = {
      hideArea: layout.hideArea!,
      reloadArea: layout.reloadArea!,
      shelterPoints: [],
      avoidanceMargin: MOVEMENT_PATH_AVOIDANCE_MARGIN,
    };
    expect(
      selectFpGateway({
        ...base,
        uShapeCenter: CENTER,
        openingAngle: 90,
        areaWidth: AREA_CONFIG.width,
        areaHeight: AREA_CONFIG.height,
      })
    ).toBeNull();
    expect(selectShrlGateway(base)).toBeNull();
  });
});

describe('calculateMovementPaths', () => {
  const layout = generateUShapeVertices(buildAreaConfig(90), createSeededRandom(42));

  it.each(['ammoArea', 'hideArea', 'reloadArea'])('requires %s', (field) => {
    const config = {
      ammoArea: layout.ammoArea!,
      hideArea: layout.hideArea!,
      reloadArea: layout.reloadArea!,
    } as Record<string, unknown>;
    delete config[field];
    expect(() => calculateMovementPaths(config as never)).toThrow(new RegExp(field));
  });

  it('emits one FP path per fire point, each ending at that fire point', () => {
    const paths = calculateMovementPaths({
      ammoArea: layout.ammoArea!,
      hideArea: layout.hideArea!,
      reloadArea: layout.reloadArea!,
      firePoints: layout.firePoints,
      avoidanceMargin: MOVEMENT_PATH_AVOIDANCE_MARGIN,
    });

    expect(paths.FP).toHaveLength(layout.firePoints!.length);
    paths.FP.forEach((path, index) => {
      expect(path.waypoints.length).toBeGreaterThanOrEqual(2);
      const last = path.waypoints[path.waypoints.length - 1];
      const target = calculateCentroid(layout.firePoints![index]);
      expect(calculateDistance(last, target)).toBeLessThan(1e-6);
    });
  });

  it('emits HA and AHA paths with at least a start and an end', () => {
    const paths = calculateMovementPaths({
      ammoArea: layout.ammoArea!,
      hideArea: layout.hideArea!,
      reloadArea: layout.reloadArea!,
      firePoints: layout.firePoints,
      avoidanceMargin: MOVEMENT_PATH_AVOIDANCE_MARGIN,
    });

    expect(paths.HA.waypoints.length).toBeGreaterThanOrEqual(2);
    expect(paths.AHA.waypoints.length).toBeGreaterThanOrEqual(2);
  });
});
