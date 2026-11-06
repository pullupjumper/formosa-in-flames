import { describe, it, expect, vi, afterEach } from 'vitest';
import type { Coordinate } from '@/types/geo';
import { createSeededRandom } from '@/utils/random';
import { AREA_CONFIG, REF_CENTER } from './config';
import { generateDeploymentData } from './deploy';
import { generateLayout } from './layout';
import {
  generateOffsetsForAngle,
  previewDeployment,
  previewRelocation,
  previewRotation,
} from './preview';

const INLAND: Coordinate = { latitude: 23.9, longitude: 120.75 };

function place(seed: number) {
  const deployment = generateDeploymentData({
    name: 'u',
    missileSystemType: 'ascm',
    center: INLAND,
    angle: 90,
    validateTaiwanBoundary: false,
    rng: createSeededRandom(seed),
  });
  expect(deployment).not.toBeNull();
  return deployment!;
}

afterEach(() => {
  vi.restoreAllMocks();
});

describe('generateOffsetsForAngle', () => {
  it('returns offsets relative to REF_CENTER', () => {
    const offsets = generateOffsetsForAngle(90, undefined, createSeededRandom(5))!;
    expect(offsets.uShapeVertices).toHaveLength(4);
    expect(offsets.firePoints).toHaveLength(AREA_CONFIG.firePoints.count);

    const layout = generateLayout(REF_CENTER, 90, {}, createSeededRandom(5));
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

  it('returns null and reports on a non-finite angle', () => {
    const error = vi.spyOn(console, 'error').mockImplementation(() => {});
    expect(generateOffsetsForAngle(NaN)).toBeNull();
    expect(error).toHaveBeenCalled();
  });
});

describe('previewDeployment', () => {
  it('translates offsets onto the cursor', () => {
    const offsets = generateOffsetsForAngle(90, undefined, createSeededRandom(13))!;
    const preview = previewDeployment(offsets, INLAND, false);
    expect(preview.isValid).toBe(true);
    preview.uShapeVertices.forEach((vertex, index) => {
      expect(vertex.latitude).toBeCloseTo(
        INLAND.latitude + offsets.uShapeVertices[index].latitudeDelta,
        9
      );
    });
  });

  it('flags a cursor out at sea when the boundary rule is on', () => {
    const offsets = generateOffsetsForAngle(90, undefined, createSeededRandom(13))!;
    const preview = previewDeployment(offsets, { latitude: 23.9, longitude: 118.5 }, true);
    expect(preview.isValid).toBe(false);
  });
});

describe('previewRelocation', () => {
  it('translates the whole boundary when moving the U-shape', () => {
    const deployment = place(11);
    const cursor = { latitude: INLAND.latitude + 0.1, longitude: INLAND.longitude - 0.1 };
    const vertices = previewRelocation(deployment, { type: 'ushape' }, cursor);
    vertices.forEach((vertex, index) => {
      const original = deployment.tacticalAreas.uShapeVertices[index];
      expect(vertex.latitude - original.latitude).toBeCloseTo(0.1, 9);
      expect(vertex.longitude - original.longitude).toBeCloseTo(-0.1, 9);
    });
  });

  it('draws a single square at the cursor for the other areas', () => {
    const deployment = place(11);
    const cursor = { latitude: INLAND.latitude + 0.02, longitude: INLAND.longitude };
    const vertices = previewRelocation(deployment, { type: 'hide' }, cursor);
    expect(vertices).toHaveLength(4);
  });
});

describe('previewRotation', () => {
  it('regenerates the layout at the candidate angle and keeps the fire points', () => {
    const deployment = place(8);
    const preview = previewRotation(deployment, 270, false, createSeededRandom(8))!;
    expect(preview.uShapeVertices).toHaveLength(4);
    expect(preview.hideArea).toHaveLength(4);
    expect(preview.firePoints).toBe(deployment.tacticalAreas.firePoints);
    expect(preview.uShapeVertices).not.toEqual(deployment.tacticalAreas.uShapeVertices);
  });

  it('returns null on a non-finite angle without logging', () => {
    const error = vi.spyOn(console, 'error').mockImplementation(() => {});
    expect(previewRotation(place(8), NaN, false)).toBeNull();
    expect(error).not.toHaveBeenCalled();
  });
});
