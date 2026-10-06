import { describe, it, expect } from 'vitest';
import type { Coordinate } from '@/types/geo';
import { calculateCentroid } from '@/utils/geo';
import { createSeededRandom } from '@/utils/random';
import { generateDeploymentData } from './deploy';
import { relocateArea } from './relocate';

/** Inland point that clears the Taiwan boundary check for a whole boundary */
const INLAND: Coordinate = { latitude: 23.9, longitude: 120.75 };
/** Well out in the strait, so every boundary check fails */
const OFFSHORE: Coordinate = { latitude: 23.9, longitude: 118.5 };

function shifted(base: Coordinate, latitudeDelta: number, longitudeDelta: number): Coordinate {
  return { latitude: base.latitude + latitudeDelta, longitude: base.longitude + longitudeDelta };
}

/** Deterministic deployment used as the "before" state of every move */
function deployed() {
  const data = generateDeploymentData({
    unitname: 'HF3 Battery 1',
    missileSystemType: 'ascm',
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

describe('relocateArea', () => {
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

  it('keeps the gateway-based paths after an AHA move', () => {
    const deployment = deployed();
    const result = move(deployment, { type: 'aha' }, shifted(INLAND, 0.05, 0.05));

    expect(result.ok).toBe(true);
    if (!result.ok) return;
    // Shelters did not change, so the shared FP origin must not either.
    expect(result.data.paths.FP[0].waypoints[0]).toEqual(deployment.paths.FP[0].waypoints[0]);
    expect(result.data.paths.SHRL.waypoints[0]).toEqual(deployment.paths.SHRL.waypoints[0]);
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

  it('rejects a hide area pushed outside the boundary', () => {
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

  it('regenerates the whole layout when the boundary moves', () => {
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

  it('reports a boundary move that leaves the coast', () => {
    const result = move(deployed(), { type: 'ushape' }, OFFSHORE);

    expect(result).toEqual({ ok: false, failure: { code: 'ushape-generation-failed' } });
  });

  it('allows a boundary move offshore when the boundary rule is off', () => {
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
