import { describe, it, expect } from 'vitest';
import type { Coordinate } from '@/types/geo';
import { calculateDistance, isPointInPolygon } from '@/utils/geo';
import { createSeededRandom } from '@/utils/random';
import { AREA_CONFIG } from './config';
import { generateLayout } from './layout';
import { buildShelterPlan, generateShelterPoints, resolveGateways } from './shelter';

const CENTER: Coordinate = { latitude: 23.8, longitude: 121.0 };
const SEEDS = [1, 2, 3, 7, 11, 42, 1337, 20260831];

// ============================================================================
// SHELTER POINTS
// ============================================================================
describe('generateShelterPoints', () => {
  it.each(SEEDS)('places the requested count inside the boundary (seed %i)', (seed) => {
    const layout = generateLayout(CENTER, 90, {}, createSeededRandom(seed));
    const points = generateShelterPoints(
      CENTER,
      90,
      [layout.hideArea, layout.reloadArea],
      createSeededRandom(seed)
    );

    expect(points).toHaveLength(AREA_CONFIG.shelter.count);
    for (const point of points) {
      expect(isPointInPolygon(point, layout.uShapeVertices)).toBe(true);
    }
  });

  it.each(SEEDS)('keeps shelters apart and clear of HA/RL (seed %i)', (seed) => {
    const layout = generateLayout(CENTER, 90, {}, createSeededRandom(seed));
    const points = generateShelterPoints(
      CENTER,
      90,
      [layout.hideArea, layout.reloadArea],
      createSeededRandom(seed)
    );

    expect(calculateDistance(points[0], points[1])).toBeGreaterThanOrEqual(
      AREA_CONFIG.shelter.marginBetweenPoints - 1e-9
    );
    for (const point of points) {
      expect(isPointInPolygon(point, layout.hideArea)).toBe(false);
      expect(isPointInPolygon(point, layout.reloadArea)).toBe(false);
    }
  });

  it('ignores avoid areas that are not squares', () => {
    const withGarbage = generateShelterPoints(CENTER, 90, [[CENTER]], createSeededRandom(4));
    const without = generateShelterPoints(CENTER, 90, [], createSeededRandom(4));
    expect(withGarbage).toEqual(without);
  });
});

// ============================================================================
// GATEWAYS
// ============================================================================
describe('resolveGateways', () => {
  it('returns null when there are no shelters to serve', () => {
    const layout = generateLayout(CENTER, 90, {}, createSeededRandom(9));
    expect(resolveGateways(CENTER, 90, layout.hideArea, layout.reloadArea, [])).toBeNull();
  });

  it('returns null when an area is missing', () => {
    const layout = generateLayout(CENTER, 90, {}, createSeededRandom(9));
    expect(resolveGateways(CENTER, 90, undefined, layout.reloadArea, [CENTER])).toBeNull();
    expect(resolveGateways(CENTER, 90, layout.hideArea, undefined, [CENTER])).toBeNull();
  });

  it('is deterministic for a given shelter set', () => {
    const layout = generateLayout(CENTER, 90, {}, createSeededRandom(9));
    const plan = buildShelterPlan(
      CENTER,
      90,
      layout.hideArea,
      layout.reloadArea,
      createSeededRandom(9)
    );
    const again = resolveGateways(
      CENTER,
      90,
      layout.hideArea,
      layout.reloadArea,
      plan.shelterPoints
    );
    expect(again).toEqual(plan.gateways);
  });
});

// ============================================================================
// SHELTER PLAN
// ============================================================================
describe('buildShelterPlan', () => {
  it('resolves both gateways for a normal layout', () => {
    const layout = generateLayout(CENTER, 90, {}, createSeededRandom(42));
    const plan = buildShelterPlan(
      CENTER,
      90,
      layout.hideArea,
      layout.reloadArea,
      createSeededRandom(42)
    );

    expect(plan.shelterPoints).toHaveLength(AREA_CONFIG.shelter.count);
    expect(plan.gateways).not.toBeNull();
  });

  it('is reproducible for a given seed', () => {
    const layout = generateLayout(CENTER, 90, {}, createSeededRandom(7));
    const run = () =>
      buildShelterPlan(CENTER, 90, layout.hideArea, layout.reloadArea, createSeededRandom(7));
    expect(run()).toEqual(run());
  });

  it.each([
    ['hideArea missing', false],
    ['reloadArea missing', true],
  ])('gives up without gateways when %s', (_label, keepHide) => {
    const layout = generateLayout(CENTER, 90, {}, createSeededRandom(3));
    const plan = buildShelterPlan(
      CENTER,
      90,
      keepHide ? layout.hideArea : undefined,
      keepHide ? undefined : layout.reloadArea,
      createSeededRandom(3)
    );

    expect(plan.gateways).toBeNull();
    // Shelters are still returned so the caller can show what was attempted.
    expect(plan.shelterPoints.length).toBeGreaterThan(0);
  });

  it('rejects a degenerate area that is not a quadrilateral', () => {
    const layout = generateLayout(CENTER, 90, {}, createSeededRandom(3));
    const plan = buildShelterPlan(
      CENTER,
      90,
      layout.hideArea.slice(0, 3),
      layout.reloadArea,
      createSeededRandom(3)
    );
    expect(plan.gateways).toBeNull();
  });
});
