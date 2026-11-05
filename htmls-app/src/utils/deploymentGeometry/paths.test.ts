import { describe, it, expect } from 'vitest';
import type { Coordinate } from '@/types/geo';
import { calculateCentroid, calculateDistance } from '@/utils/geo';
import { createSeededRandom } from '@/utils/random';
import { AREA_CONFIG } from './config';
import { generateLayout } from './layout';
import { buildMovementPaths, createEmptyMovementPaths } from './paths';
import { buildShelterPlan } from './shelter';

const CENTER: Coordinate = { latitude: 23.8, longitude: 121.0 };

describe('createEmptyMovementPaths', () => {
  it('returns every path slot empty', () => {
    expect(createEmptyMovementPaths()).toEqual({
      FP: [],
      HA: { waypoints: [] },
      RL: [],
      ATP: { waypoints: [] },
      SHRL: { waypoints: [] },
    });
  });
});

describe('buildMovementPaths', () => {
  const layout = generateLayout(CENTER, 90, {}, createSeededRandom(42));
  const plan = buildShelterPlan(
    CENTER,
    90,
    layout.hideArea,
    layout.reloadArea,
    createSeededRandom(42)
  );

  it('returns empty paths when an area is missing', () => {
    expect(buildMovementPaths({ uShapeVertices: [] }, null)).toEqual(createEmptyMovementPaths());
  });

  it('emits one FP path per fire point, each ending at that fire point', () => {
    const paths = buildMovementPaths(layout, null);

    expect(paths.FP).toHaveLength(layout.firePoints.length);
    paths.FP.forEach((path, index) => {
      expect(path.waypoints.length).toBeGreaterThanOrEqual(2);
      const last = path.waypoints[path.waypoints.length - 1];
      const target = calculateCentroid(layout.firePoints[index]);
      expect(calculateDistance(last, target)).toBeLessThan(1e-6);
    });
  });

  it('emits HA and ATP paths with at least a start and an end', () => {
    const paths = buildMovementPaths(layout, null);
    expect(paths.HA.waypoints.length).toBeGreaterThanOrEqual(2);
    expect(paths.ATP.waypoints.length).toBeGreaterThanOrEqual(2);
  });

  it('starts FP and SHRL paths at the gateways when given', () => {
    expect(plan.gateways).not.toBeNull();
    const paths = buildMovementPaths(layout, plan.gateways);

    expect(paths.FP).toHaveLength(AREA_CONFIG.firePoints.count);
    for (const path of paths.FP) {
      expect(path.waypoints[0]).toEqual(plan.gateways!.fpGateway);
    }
    expect(paths.SHRL.waypoints[0]).toEqual(plan.gateways!.shrlGateway);
  });

  it('leaves SHRL empty without gateways', () => {
    expect(buildMovementPaths(layout, null).SHRL.waypoints).toEqual([]);
  });
});
