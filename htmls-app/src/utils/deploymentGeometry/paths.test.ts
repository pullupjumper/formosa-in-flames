import { describe, it, expect } from 'vitest';
import type { Coordinate } from '@/types/geo';
import { calculateCentroid, calculateDistance } from '@/utils/geo';
import { createSeededRandom } from '@/utils/random';
import { AREA_CONFIG } from './config';
import { generateLayout, toTacticalAreas } from './layout';
import { buildMovementPaths, createEmptyMovementPaths } from './paths';
import { buildShelterPlan } from './shelter';

const CENTER: Coordinate = { latitude: 23.8, longitude: 121.0 };

describe('createEmptyMovementPaths', () => {
  it('returns every path list empty', () => {
    expect(createEmptyMovementPaths()).toEqual({
      paths: { FP: [], HA: [], ATP: [], RL: [], SHRL: [] },
      reloadReturnPaths: [],
    });
  });
});

describe('buildMovementPaths', () => {
  const layout = generateLayout(CENTER, 90, {}, createSeededRandom(42));
  const tacticalAreas = toTacticalAreas(layout);
  const reloadCenter = calculateCentroid(layout.reloadArea);
  const plan = buildShelterPlan(
    CENTER,
    90,
    layout.hideArea,
    layout.reloadArea,
    createSeededRandom(42)
  );

  it('returns empty paths when an area is missing', () => {
    expect(
      buildMovementPaths({ uShapeVertices: [], FP: [], HA: [], ATP: [], RL: [] }, null)
    ).toEqual(createEmptyMovementPaths());
  });

  it('emits one FP path per fire point, each ending at that fire point', () => {
    const { paths } = buildMovementPaths(tacticalAreas, null);

    expect(paths.FP).toHaveLength(layout.firePoints.length);
    paths.FP.forEach((path, index) => {
      expect(path.waypoints.length).toBeGreaterThanOrEqual(2);
      const last = path.waypoints[path.waypoints.length - 1];
      const target = calculateCentroid(layout.firePoints[index]);
      expect(calculateDistance(last, target)).toBeLessThan(1e-6);
    });
  });

  it('emits one HA and one ATP path with at least a start and an end', () => {
    const { paths } = buildMovementPaths(tacticalAreas, null);
    expect(paths.HA).toHaveLength(1);
    expect(paths.ATP).toHaveLength(1);
    expect(paths.HA[0].waypoints.length).toBeGreaterThanOrEqual(2);
    expect(paths.ATP[0].waypoints.length).toBeGreaterThanOrEqual(2);
  });

  it('draws a way back to the reload area from every fire point', () => {
    const { reloadReturnPaths } = buildMovementPaths(tacticalAreas, null);

    expect(reloadReturnPaths).toHaveLength(layout.firePoints.length);
    reloadReturnPaths.forEach((path, index) => {
      const { waypoints } = path;
      expect(
        calculateDistance(waypoints[0], calculateCentroid(layout.firePoints[index]))
      ).toBeLessThan(1e-6);
      expect(calculateDistance(waypoints[waypoints.length - 1], reloadCenter)).toBeLessThan(1e-6);
    });
  });

  it('sends the first fire point way back as the one reload path', () => {
    const { paths, reloadReturnPaths } = buildMovementPaths(tacticalAreas, null);

    expect(paths.RL).toEqual([reloadReturnPaths[0]]);
  });

  it('starts FP and SHRL paths at the gateways when given', () => {
    expect(plan.gateways).not.toBeNull();
    const { paths } = buildMovementPaths(tacticalAreas, plan.gateways);

    expect(paths.FP).toHaveLength(AREA_CONFIG.firePoints.count);
    for (const path of paths.FP) {
      expect(path.waypoints[0]).toEqual(plan.gateways!.fpGateway);
    }
    expect(paths.SHRL).toHaveLength(1);
    expect(paths.SHRL[0].waypoints[0]).toEqual(plan.gateways!.shrlGateway);
  });

  it('leaves SHRL empty without gateways', () => {
    expect(buildMovementPaths(tacticalAreas, null).paths.SHRL).toEqual([]);
  });
});
