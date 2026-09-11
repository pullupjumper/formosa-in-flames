import { describe, it, expect, vi, afterEach } from 'vitest';
import {
  AREA_CONFIG,
  REF_CENTER,
  AREA_SQUARE_SIZE,
  buildMovementPaths,
  buildShelterPlan,
  createEmptyMovementPaths,
  generateDeploymentData,
  generateOffsetsForAngle,
  generateRotationPreview,
  isValidAngle,
  relocateArea,
} from '@/utils/missileDeployment';
import { generateUShapeVertices, calculateDistance } from '@/utils/tacticalAreaGenerator';
import { areAllPointsInPolygon, calculateCentroid } from '@/utils/geo';
import type { Coordinate } from '@/types/geo';
import { createSeededRandom } from '@/utils/random';

// ============================================================================
// FIXTURES
// ============================================================================
/** Inland point that clears the Taiwan boundary check for a whole U-shape */
const INLAND: Coordinate = { latitude: 23.9, longitude: 120.75 };
/** Well out in the strait, so every boundary check fails */
const OFFSHORE: Coordinate = { latitude: 23.9, longitude: 118.5 };

function shifted(base: Coordinate, latitudeDelta: number, longitudeDelta: number): Coordinate {
  return { latitude: base.latitude + latitudeDelta, longitude: base.longitude + longitudeDelta };
}

function layoutAt(center: Coordinate, angle: number, seed: number) {
  return generateUShapeVertices(
    { center, openingAngle: angle, ...AREA_CONFIG },
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
    const layout = layoutAt(INLAND, 90, 42);
    const plan = buildShelterPlan(
      INLAND,
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
    const layout = layoutAt(INLAND, 90, 7);
    const run = () =>
      buildShelterPlan(INLAND, 90, layout.hideArea, layout.reloadArea, createSeededRandom(7));
    expect(run()).toEqual(run());
  });

  it.each([
    ['hideArea missing', false],
    ['reloadArea missing', true],
  ])('gives up without gateways when %s', (_label, keepHide) => {
    const layout = layoutAt(INLAND, 90, 3);
    const plan = buildShelterPlan(
      INLAND,
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
    const layout = layoutAt(INLAND, 90, 3);
    const plan = buildShelterPlan(
      INLAND,
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
      buildMovementPaths({ uShapeVertices: [] } as never, { center: INLAND, openingAngle: 90 })
    ).toEqual(createEmptyMovementPaths());
  });

  it('builds FP paths for a complete deployment', () => {
    const layout = layoutAt(INLAND, 90, 42);
    const plan = buildShelterPlan(
      INLAND,
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
      { center: INLAND, openingAngle: 90 }
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
      center: INLAND,
      rng: createSeededRandom(42),
    });

    expect(data).not.toBeNull();
    expect(data!.unitName).toBe('HF3_01');
    expect(data!.category).toBe('ascm');
    expect(data!.center).toEqual(INLAND);
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

  it('returns null and reports when the generator throws', () => {
    const error = vi.spyOn(console, 'error').mockImplementation(() => {});
    const data = generateDeploymentData({
      ...baseParams,
      // generateUShapeVertices rejects a falsy center latitude
      center: { latitude: 0, longitude: INLAND.longitude },
      rng: createSeededRandom(1),
    });

    expect(data).toBeNull();
    expect(error).toHaveBeenCalled();
  });
});

// ============================================================================
// AREA RELOCATION
// ============================================================================
describe('relocateArea', () => {
  /** Deterministic deployment used as the "before" state of every move */
  function deployed() {
    const data = generateDeploymentData({
      unitName: 'HF3 Battery 1',
      category: 'ascm',
      center: INLAND,
      angle: 90,
      validateTaiwanBoundary: true,
      rng: createSeededRandom(42),
    });
    if (!data) throw new Error('fixture deployment failed to generate');
    return data;
  }

  function move(
    deployment: ReturnType<typeof deployed>,
    target: Parameters<typeof relocateArea>[0]['target'],
    position: Coordinate,
    validateTaiwanBoundary = true
  ) {
    return relocateArea({
      deployment,
      target,
      position,
      validateTaiwanBoundary,
      rng: createSeededRandom(7),
    });
  }

  it('moves the AHA square and records its new center', () => {
    const deployment = deployed();
    const target = shifted(INLAND, 0.05, 0.05);
    const result = move(deployment, { type: 'aha' }, target);

    expect(result.ok).toBe(true);
    if (!result.ok) return;
    expect(result.data.ahaCenter).toEqual(target);
    expect(result.data.tacticalAreas.ammoArea).toHaveLength(4);
    expect(result.data.tacticalAreas.ammoArea).not.toEqual(deployment.tacticalAreas.ammoArea);
  });

  it('leaves every other tactical area untouched', () => {
    const deployment = deployed();
    const result = move(deployment, { type: 'aha' }, shifted(INLAND, 0.05, 0.05));

    expect(result.ok).toBe(true);
    if (!result.ok) return;
    const { tacticalAreas: before } = deployment;
    const { tacticalAreas: after } = result.data;
    expect(after.uShapeVertices).toEqual(before.uShapeVertices);
    expect(after.hideArea).toEqual(before.hideArea);
    expect(after.reloadArea).toEqual(before.reloadArea);
    expect(after.firePoints).toEqual(before.firePoints);
    // AHA does not affect shelter placement, so those stay put too
    expect(after.shelterPoints).toEqual(before.shelterPoints);
  });

  it('replaces only the addressed fire point', () => {
    const deployment = deployed();
    const result = move(deployment, { type: 'fp', fpIndex: 1 }, shifted(INLAND, 0.02, 0));

    expect(result.ok).toBe(true);
    if (!result.ok) return;
    const before = deployment.tacticalAreas.firePoints!;
    const after = result.data.tacticalAreas.firePoints!;
    expect(after[0]).toEqual(before[0]);
    expect(after[1]).not.toEqual(before[1]);
  });

  it('defaults a missing fire point index to the first', () => {
    const deployment = deployed();
    const result = move(deployment, { type: 'fp' }, shifted(INLAND, 0.02, 0));

    expect(result.ok).toBe(true);
    if (!result.ok) return;
    const after = result.data.tacticalAreas.firePoints!;
    expect(after).toHaveLength(deployment.tacticalAreas.firePoints!.length);
    expect(after[0]).not.toEqual(deployment.tacticalAreas.firePoints![0]);
  });

  it('rejects a hide area pushed outside the U-Shape', () => {
    const result = move(deployed(), { type: 'hide' }, shifted(INLAND, 1, 1));

    expect(result).toEqual({ ok: false, failure: { code: 'outside-boundary' } });
  });

  it('rejects a hide area dropped on top of the reload area', () => {
    const deployment = deployed();
    const onReload = calculateCentroid(deployment.tacticalAreas.reloadArea!);
    const result = move(deployment, { type: 'hide' }, onReload);

    expect(result).toEqual({
      ok: false,
      failure: { code: 'overlaps-other-area', other: 'reload' },
    });
  });

  it('names the hide area when the reload area is the one being moved', () => {
    const deployment = deployed();
    const onHide = calculateCentroid(deployment.tacticalAreas.hideArea!);
    const result = move(deployment, { type: 'reload' }, onHide);

    expect(result).toEqual({ ok: false, failure: { code: 'overlaps-other-area', other: 'hide' } });
  });

  it('replans shelters when the hide area moves', () => {
    const deployment = deployed();
    // Nudge just far enough to change the layout without leaving the boundary
    const from = calculateCentroid(deployment.tacticalAreas.hideArea!);
    const result = move(deployment, { type: 'hide' }, shifted(from, 0.001, 0));

    expect(result.ok).toBe(true);
    if (!result.ok) return;
    expect(result.data.tacticalAreas.shelterPoints).toBeDefined();
    expect(result.data.tacticalAreas.hideArea).not.toEqual(deployment.tacticalAreas.hideArea);
  });

  it('regenerates the whole layout when the U-Shape moves', () => {
    const deployment = deployed();
    const target = shifted(INLAND, 0.05, 0);
    const result = move(deployment, { type: 'ushape' }, target);

    expect(result.ok).toBe(true);
    if (!result.ok) return;
    expect(result.data.center).toEqual(target);
    expect(result.data.tacticalAreas.uShapeVertices).not.toEqual(
      deployment.tacticalAreas.uShapeVertices
    );
    // AHA and fire points are user-placed, so the move leaves them alone
    expect(result.data.tacticalAreas.ammoArea).toEqual(deployment.tacticalAreas.ammoArea);
    expect(result.data.tacticalAreas.firePoints).toEqual(deployment.tacticalAreas.firePoints);
  });

  it('reports a U-Shape move that leaves the coast', () => {
    const result = move(deployed(), { type: 'ushape' }, OFFSHORE);

    expect(result).toEqual({ ok: false, failure: { code: 'ushape-generation-failed' } });
  });

  it('allows a U-Shape move offshore when the boundary rule is off', () => {
    const result = move(deployed(), { type: 'ushape' }, OFFSHORE, false);

    expect(result.ok).toBe(true);
  });

  it('recomputes the movement paths against the updated areas', () => {
    const deployment = deployed();
    const result = move(deployment, { type: 'aha' }, shifted(INLAND, 0.05, 0.05));

    expect(result.ok).toBe(true);
    if (!result.ok) return;
    expect(result.data.paths).not.toEqual(deployment.paths);
    expect(result.data.paths.AHA.waypoints.length).toBeGreaterThan(0);
  });

  it('never mutates the deployment it was given', () => {
    const deployment = deployed();
    const snapshot = structuredClone(deployment);
    move(deployment, { type: 'hide' }, shifted(INLAND, 1, 1));
    move(deployment, { type: 'aha' }, shifted(INLAND, 0.05, 0));
    move(deployment, { type: 'ushape' }, shifted(INLAND, 0.05, 0));

    expect(deployment).toEqual(snapshot);
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

    const layout = layoutAt(REF_CENTER, 90, 5);
    offsets.uShapeVertices.forEach((offset, index) => {
      expect(offset.latitudeDelta).toBeCloseTo(
        layout.uShapeVertices[index].latitude - REF_CENTER.latitude,
        10
      );
      expect(offset.longitudeDelta).toBeCloseTo(
        layout.uShapeVertices[index].longitude - REF_CENTER.longitude,
        10
      );
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
    expect(generateRotationPreview({ latitude: 0, longitude: 0 }, 90)).toBeNull();
    expect(error).not.toHaveBeenCalled();
  });
});
