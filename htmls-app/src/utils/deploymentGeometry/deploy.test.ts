import { describe, it, expect, vi, afterEach } from 'vitest';
import type { Coordinate } from '@/types/geo';
import { areAllPointsInPolygon, calculateCentroid, calculateDistance } from '@/utils/geo';
import { createSeededRandom } from '@/utils/random';
import { AREA_CONFIG } from './config';
import { generateDeploymentData, isValidAngle, rotateDeployment } from './deploy';
import { relocateArea } from './relocate';

/** Inland point that clears the Taiwan boundary check for a whole boundary */
const INLAND: Coordinate = { latitude: 23.9, longitude: 120.75 };
/** Well out in the strait, so every boundary check fails */
const OFFSHORE: Coordinate = { latitude: 23.9, longitude: 118.5 };

function shifted(base: Coordinate, latitudeDelta: number, longitudeDelta: number): Coordinate {
  return { latitude: base.latitude + latitudeDelta, longitude: base.longitude + longitudeDelta };
}

afterEach(() => {
  vi.restoreAllMocks();
});

describe('isValidAngle', () => {
  it.each([0, 1, 180, 359])('accepts %i', (angle) => {
    expect(isValidAngle(angle)).toBe(true);
  });

  it.each([-1, 360, 361, NaN, Infinity, -Infinity])('rejects %o', (angle) => {
    expect(isValidAngle(angle)).toBe(false);
  });
});

// ============================================================================
// GENERATE
// ============================================================================
describe('generateDeploymentData', () => {
  const baseParams = {
    unitName: 'HF3_01',
    category: 'ascm',
    angle: 90,
    validateTaiwanBoundary: true,
  };

  it('produces a complete deployment inland', () => {
    const data = generateDeploymentData({
      ...baseParams,
      center: INLAND,
      rng: createSeededRandom(42),
    });

    expect(data).not.toBeNull();
    expect(data!.unitName).toBe('HF3_01');
    expect(data!.missileSystemType).toBe('ascm');
    expect(data!.center).toEqual(INLAND);
    expect(data!.openingAngle).toBe(90);
    expect(data!.ahaRadius).toBe(AREA_CONFIG.ahaPoint.radius);
    expect(data!.ahaCenter).toBeUndefined();
    expect(data!.tacticalAreas.uShapeVertices).toHaveLength(4);
    expect(data!.tacticalAreas.firePoints).toHaveLength(AREA_CONFIG.firePoints.count);
    expect(data!.tacticalAreas.shelterPoints).toHaveLength(AREA_CONFIG.shelter.count);
    expect(data!.paths.FP).toHaveLength(AREA_CONFIG.firePoints.count);
    expect(data!.paths.SHRL.waypoints.length).toBeGreaterThanOrEqual(2);
  });

  it('keeps HA, RL and shelters inside the generated boundary', () => {
    const data = generateDeploymentData({
      ...baseParams,
      center: INLAND,
      rng: createSeededRandom(11),
    })!;
    const { uShapeVertices, hideArea, reloadArea, shelterPoints } = data.tacticalAreas;

    expect(areAllPointsInPolygon(hideArea!, uShapeVertices)).toBe(true);
    expect(areAllPointsInPolygon(reloadArea!, uShapeVertices)).toBe(true);
    expect(areAllPointsInPolygon(shelterPoints!, uShapeVertices)).toBe(true);
  });

  it('rejects an offshore location when the boundary check is on', () => {
    const data = generateDeploymentData({
      ...baseParams,
      center: OFFSHORE,
      rng: createSeededRandom(1),
    });
    expect(data).toBeNull();
  });

  it('accepts the same offshore location when the boundary check is off', () => {
    const data = generateDeploymentData({
      ...baseParams,
      validateTaiwanBoundary: false,
      center: OFFSHORE,
      rng: createSeededRandom(1),
    });
    expect(data).not.toBeNull();
  });

  it('honours the AHA radius and center overrides', () => {
    const ahaCenterOverride = shifted(INLAND, 0.05, 0.05);
    const data = generateDeploymentData({
      ...baseParams,
      center: INLAND,
      ahaRadiusOverride: 4,
      ahaCenterOverride,
      rng: createSeededRandom(42),
    })!;

    expect(data.ahaRadius).toBe(4);
    expect(data.ahaCenter).toEqual(ahaCenterOverride);

    const ammoCenter = calculateCentroid(data.tacticalAreas.ammoArea!);
    expect(calculateDistance(ammoCenter, ahaCenterOverride)).toBeLessThan(1e-4);
  });

  it('is reproducible for a given seed', () => {
    const run = () =>
      generateDeploymentData({
        ...baseParams,
        center: INLAND,
        rng: createSeededRandom(2024),
      });
    expect(run()).toEqual(run());
  });

  it('returns null and reports when the layout throws', () => {
    const error = vi.spyOn(console, 'error').mockImplementation(() => {});
    const data = generateDeploymentData({
      ...baseParams,
      center: { latitude: NaN, longitude: INLAND.longitude },
      rng: createSeededRandom(1),
    });

    expect(data).toBeNull();
    expect(error).toHaveBeenCalled();
  });
});

// ============================================================================
// ROTATE
// ============================================================================
describe('rotateDeployment', () => {
  function place(seed: number) {
    const rng = createSeededRandom(seed);
    const deployment = generateDeploymentData({
      unitName: 'u',
      category: 'ascm',
      center: INLAND,
      angle: 90,
      validateTaiwanBoundary: false,
      rng,
    });
    expect(deployment).not.toBeNull();
    return { deployment: deployment!, rng };
  }

  it('keeps the fire points and routes every FP path to them', () => {
    const { deployment, rng } = place(3);
    const rotated = rotateDeployment({
      deployment,
      angle: 270,
      validateTaiwanBoundary: false,
      rng,
    });
    expect(rotated).not.toBeNull();
    expect(rotated!.openingAngle).toBe(270);
    expect(rotated!.tacticalAreas.firePoints).toBe(deployment.tacticalAreas.firePoints);

    rotated!.paths.FP.forEach((path, index) => {
      const end = path.waypoints[path.waypoints.length - 1];
      const firePoint = rotated!.tacticalAreas.firePoints![index];
      expect(areAllPointsInPolygon([end], firePoint)).toBe(true);
    });
  });

  it('keeps a hand-placed AHA in place', () => {
    const { deployment, rng } = place(5);
    const moved = relocateArea({
      deployment,
      target: { type: 'aha' },
      position: shifted(INLAND, 0.05, 0.05),
      validateTaiwanBoundary: false,
      rng,
    });
    expect(moved.ok).toBe(true);
    if (!moved.ok) return;

    const rotated = rotateDeployment({
      deployment: moved.data,
      angle: 180,
      validateTaiwanBoundary: false,
      rng,
    });
    expect(rotated).not.toBeNull();
    expect(calculateCentroid(rotated!.tacticalAreas.ammoArea!)).toEqual(
      calculateCentroid(moved.data.tacticalAreas.ammoArea!)
    );
  });

  it('rejects an out-of-range angle', () => {
    const { deployment, rng } = place(7);
    expect(
      rotateDeployment({ deployment, angle: 400, validateTaiwanBoundary: false, rng })
    ).toBeNull();
  });
});
