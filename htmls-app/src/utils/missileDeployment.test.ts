import { describe, it, expect, vi, afterEach } from 'vitest';
import {
  AREA_CONFIG,
  REF_CENTER,
  AREA_SQUARE_SIZE,
  areAllPointsInPolygon,
  buildMovementPaths,
  buildShelterPlan,
  createEmptyMovementPaths,
  generateDeploymentData,
  generateOffsetsForAngle,
  generateRotationPreview,
  isPointInPolygon,
  isValidAngle,
} from '@/utils/missileDeployment';
import { generateUShapeVertices, calculateDistance } from '@/utils/tacticalAreaGenerator';
import type { Coordinate } from '@/utils/tacticalAreaGenerator';
import { createSeededRandom } from '@/utils/random';

// ============================================================================
// FIXTURES
// ============================================================================
/** Inland point that clears the Taiwan boundary check for a whole U-shape */
const INLAND = { lat: 23.9, lng: 120.75 };
/** Well out in the strait, so every boundary check fails */
const OFFSHORE = { lat: 23.9, lng: 118.5 };

const SQUARE: Coordinate[] = [
  { latitude: 24, longitude: 120 },
  { latitude: 24, longitude: 121 },
  { latitude: 25, longitude: 121 },
  { latitude: 25, longitude: 120 },
];

function layoutAt(lat: number, lng: number, angle: number, seed: number) {
  return generateUShapeVertices(
    { centerLat: lat, centerLon: lng, openingAngle: angle, ...AREA_CONFIG },
    createSeededRandom(seed)
  );
}

afterEach(() => {
  vi.restoreAllMocks();
});

// ============================================================================
// PURE PREDICATES
// ============================================================================
describe('isValidAngle', () => {
  it.each([0, 1, 180, 359])('accepts %i', (angle) => {
    expect(isValidAngle(angle)).toBe(true);
  });

  it.each([-1, 360, 361, NaN, Infinity, -Infinity])('rejects %o', (angle) => {
    expect(isValidAngle(angle)).toBe(false);
  });
});

describe('isPointInPolygon', () => {
  it('accepts an interior point', () => {
    expect(isPointInPolygon({ latitude: 24.5, longitude: 120.5 }, SQUARE)).toBe(true);
  });

  it('rejects an exterior point', () => {
    expect(isPointInPolygon({ latitude: 24.5, longitude: 121.5 }, SQUARE)).toBe(false);
    expect(isPointInPolygon({ latitude: 26, longitude: 120.5 }, SQUARE)).toBe(false);
  });

  it('is consistent on the shared edge of two adjacent polygons', () => {
    // Ray casting is half-open, so a point on the shared boundary must belong
    // to exactly one of the two squares - never both, never neither.
    const right: Coordinate[] = [
      { latitude: 24, longitude: 121 },
      { latitude: 24, longitude: 122 },
      { latitude: 25, longitude: 122 },
      { latitude: 25, longitude: 121 },
    ];
    const onEdge = { latitude: 24.5, longitude: 121 };
    expect(Number(isPointInPolygon(onEdge, SQUARE)) + Number(isPointInPolygon(onEdge, right))).toBe(
      1
    );
  });
});

describe('areAllPointsInPolygon', () => {
  it('requires every point to be inside', () => {
    const inside = { latitude: 24.5, longitude: 120.5 };
    const outside = { latitude: 24.5, longitude: 121.5 };
    expect(areAllPointsInPolygon([inside, inside], SQUARE)).toBe(true);
    expect(areAllPointsInPolygon([inside, outside], SQUARE)).toBe(false);
  });

  it('is vacuously true for an empty list', () => {
    expect(areAllPointsInPolygon([], SQUARE)).toBe(true);
  });
});

describe('createEmptyMovementPaths', () => {
  it('returns every path slot empty', () => {
    expect(createEmptyMovementPaths()).toEqual({
      FP: [],
      HA: { waypoints: [] },
      RL: [],
      AHA: { waypoints: [] },
      SHRL: { waypoints: [] },
    });
  });
});

describe('AREA_SQUARE_SIZE', () => {
  it('mirrors the sizes each area is generated with', () => {
    expect(AREA_SQUARE_SIZE.aha).toBe(AREA_CONFIG.ahaPoint.squareSize);
    expect(AREA_SQUARE_SIZE.hide).toBe(AREA_CONFIG.internalSquares.size);
    expect(AREA_SQUARE_SIZE.reload).toBe(AREA_CONFIG.internalSquares.size);
    expect(AREA_SQUARE_SIZE.fp).toBe(AREA_CONFIG.firePoints.squareSize);
  });
});

// ============================================================================
// SHELTER PLAN
// ============================================================================
describe('buildShelterPlan', () => {
  it('resolves both gateways for a normal layout', () => {
    const layout = layoutAt(INLAND.lat, INLAND.lng, 90, 42);
    const plan = buildShelterPlan(
      INLAND.lat,
      INLAND.lng,
      90,
      layout.hideArea,
      layout.reloadArea,
      createSeededRandom(42)
    );

    expect(plan.shelterPoints).toHaveLength(AREA_CONFIG.shelter.count);
    expect(plan.fpGateway).not.toBeNull();
    expect(plan.shrlGateway).not.toBeNull();
  });

  it('is reproducible for a given seed', () => {
    const layout = layoutAt(INLAND.lat, INLAND.lng, 90, 7);
    const run = () =>
      buildShelterPlan(
        INLAND.lat,
        INLAND.lng,
        90,
        layout.hideArea,
        layout.reloadArea,
        createSeededRandom(7)
      );
    expect(run()).toEqual(run());
  });

  it.each([
    ['hideArea missing', false],
    ['reloadArea missing', true],
  ])('gives up without gateways when %s', (_label, keepHide) => {
    const layout = layoutAt(INLAND.lat, INLAND.lng, 90, 3);
    const plan = buildShelterPlan(
      INLAND.lat,
      INLAND.lng,
      90,
      keepHide ? layout.hideArea : undefined,
      keepHide ? undefined : layout.reloadArea,
      createSeededRandom(3)
    );

    expect(plan.fpGateway).toBeNull();
    expect(plan.shrlGateway).toBeNull();
    // Shelters are still returned so the caller can show what was attempted.
    expect(plan.shelterPoints.length).toBeGreaterThan(0);
  });

  it('rejects a degenerate area that is not a quadrilateral', () => {
    const layout = layoutAt(INLAND.lat, INLAND.lng, 90, 3);
    const plan = buildShelterPlan(
      INLAND.lat,
      INLAND.lng,
      90,
      layout.hideArea!.slice(0, 3),
      layout.reloadArea,
      createSeededRandom(3)
    );
    expect(plan.fpGateway).toBeNull();
    expect(plan.shrlGateway).toBeNull();
  });
});

// ============================================================================
// MOVEMENT PATHS
// ============================================================================
describe('buildMovementPaths', () => {
  it('returns empty paths when an area is missing', () => {
    expect(
      buildMovementPaths({ uShapeVertices: [] } as never, {
        centerLat: INLAND.lat,
        centerLng: INLAND.lng,
        openingAngle: 90,
      })
    ).toEqual(createEmptyMovementPaths());
  });

  it('builds FP paths for a complete deployment', () => {
    const layout = layoutAt(INLAND.lat, INLAND.lng, 90, 42);
    const plan = buildShelterPlan(
      INLAND.lat,
      INLAND.lng,
      90,
      layout.hideArea,
      layout.reloadArea,
      createSeededRandom(42)
    );

    const paths = buildMovementPaths(
      {
        uShapeVertices: layout.uShapeVertices,
        ammoArea: layout.ammoArea,
        hideArea: layout.hideArea,
        reloadArea: layout.reloadArea,
        firePoints: layout.firePoints,
        shelterPoints: plan.shelterPoints,
      },
      { centerLat: INLAND.lat, centerLng: INLAND.lng, openingAngle: 90 }
    );

    expect(paths.FP).toHaveLength(AREA_CONFIG.firePoints.count);
    expect(paths.HA.waypoints.length).toBeGreaterThanOrEqual(2);
  });
});

// ============================================================================
// DEPLOYMENT GENERATION
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
      lat: INLAND.lat,
      lng: INLAND.lng,
      rng: createSeededRandom(42),
    });

    expect(data).not.toBeNull();
    expect(data!.unitName).toBe('HF3_01');
    expect(data!.category).toBe('ascm');
    expect(data!.center).toEqual({ lat: INLAND.lat, lng: INLAND.lng });
    expect(data!.openingAngle).toBe(90);
    expect(data!.ahaRadius).toBe(AREA_CONFIG.ahaPoint.radius);
    expect(data!.ahaCenter).toBeUndefined();
    expect(data!.tacticalAreas.uShapeVertices).toHaveLength(4);
    expect(data!.tacticalAreas.firePoints).toHaveLength(AREA_CONFIG.firePoints.count);
    expect(data!.tacticalAreas.shelterPoints).toHaveLength(AREA_CONFIG.shelter.count);
    expect(data!.paths.FP).toHaveLength(AREA_CONFIG.firePoints.count);
  });

  it('keeps HA, RL and shelters inside the generated boundary', () => {
    const data = generateDeploymentData({
      ...baseParams,
      lat: INLAND.lat,
      lng: INLAND.lng,
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
      lat: OFFSHORE.lat,
      lng: OFFSHORE.lng,
      rng: createSeededRandom(1),
    });
    expect(data).toBeNull();
  });

  it('accepts the same offshore location when the boundary check is off', () => {
    const data = generateDeploymentData({
      ...baseParams,
      validateTaiwanBoundary: false,
      lat: OFFSHORE.lat,
      lng: OFFSHORE.lng,
      rng: createSeededRandom(1),
    });
    expect(data).not.toBeNull();
  });

  it('honours the AHA radius and center overrides', () => {
    const ahaCenterOverride = { lat: INLAND.lat + 0.05, lng: INLAND.lng + 0.05 };
    const data = generateDeploymentData({
      ...baseParams,
      lat: INLAND.lat,
      lng: INLAND.lng,
      ahaRadiusOverride: 4,
      ahaCenterOverride,
      rng: createSeededRandom(42),
    })!;

    expect(data.ahaRadius).toBe(4);
    expect(data.ahaCenter).toEqual(ahaCenterOverride);

    const ammoCenter = data.tacticalAreas.ammoArea!.reduce(
      (acc, v) => ({
        latitude: acc.latitude + v.latitude / 4,
        longitude: acc.longitude + v.longitude / 4,
      }),
      { latitude: 0, longitude: 0 }
    );
    expect(
      calculateDistance(
        ammoCenter.latitude,
        ammoCenter.longitude,
        ahaCenterOverride.lat,
        ahaCenterOverride.lng
      )
    ).toBeLessThan(1e-4);
  });

  it('is reproducible for a given seed', () => {
    const run = () =>
      generateDeploymentData({
        ...baseParams,
        lat: INLAND.lat,
        lng: INLAND.lng,
        rng: createSeededRandom(2024),
      });
    expect(run()).toEqual(run());
  });

  it('returns null and reports when the generator throws', () => {
    const error = vi.spyOn(console, 'error').mockImplementation(() => {});
    const data = generateDeploymentData({
      ...baseParams,
      lat: 0, // generateUShapeVertices rejects a falsy centerLat
      lng: INLAND.lng,
      rng: createSeededRandom(1),
    });

    expect(data).toBeNull();
    expect(error).toHaveBeenCalled();
  });
});

// ============================================================================
// PREVIEWS
// ============================================================================
describe('generateOffsetsForAngle', () => {
  it('returns offsets relative to REF_CENTER', () => {
    const offsets = generateOffsetsForAngle(90, undefined, createSeededRandom(5))!;
    expect(offsets.uShapeVertices).toHaveLength(4);
    expect(offsets.firePoints).toHaveLength(AREA_CONFIG.firePoints.count);

    const layout = layoutAt(REF_CENTER.lat, REF_CENTER.lng, 90, 5);
    offsets.uShapeVertices.forEach((offset, index) => {
      expect(offset.dLat).toBeCloseTo(layout.uShapeVertices[index].latitude - REF_CENTER.lat, 10);
      expect(offset.dLng).toBeCloseTo(layout.uShapeVertices[index].longitude - REF_CENTER.lng, 10);
    });
  });

  it('returns null and reports when the angle produces an invalid config', () => {
    const error = vi.spyOn(console, 'error').mockImplementation(() => {});
    expect(generateOffsetsForAngle(undefined as unknown as number)).toBeNull();
    expect(error).toHaveBeenCalled();
  });
});

describe('generateRotationPreview', () => {
  it('regenerates the boundary at the candidate angle', () => {
    const preview = generateRotationPreview(
      INLAND,
      270,
      undefined,
      undefined,
      createSeededRandom(8)
    )!;
    expect(preview.uShapeVertices).toHaveLength(4);
    expect(preview.ammoArea).toHaveLength(4);
    expect(preview.hideArea).toHaveLength(4);
    expect(preview.reloadArea).toHaveLength(4);
  });

  it('differs from the preview at another angle', () => {
    const a = generateRotationPreview(INLAND, 90, undefined, undefined, createSeededRandom(8))!;
    const b = generateRotationPreview(INLAND, 270, undefined, undefined, createSeededRandom(8))!;
    expect(a.uShapeVertices).not.toEqual(b.uShapeVertices);
  });

  it('returns null on an invalid center without logging', () => {
    const error = vi.spyOn(console, 'error').mockImplementation(() => {});
    expect(generateRotationPreview({ lat: 0, lng: 0 }, 90)).toBeNull();
    expect(error).not.toHaveBeenCalled();
  });
});
