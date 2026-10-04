import { describe, it, expect } from 'vitest';
import {
  IDLE_STATE,
  deploymentModeReducer,
  formatAreaLabel,
  selectRelocatingArea,
  selectRotatingUnitKey,
  selectSelectedUnitKey,
  selectSelectedJammerIndex,
  selectRelocatingJammerIndex,
} from './deploymentMode';
import type { DeploymentMode } from './deploymentMode';

const UNIT = { key: 'ascm_HF3_01', name: 'HF3_01', category: 'ascm' };
const CENTER = { latitude: 24, longitude: 121 };

const MODES: Record<string, DeploymentMode> = {
  idle: { kind: 'idle' },
  deploy: { kind: 'deploy', unit: UNIT, offsets: {} },
  relocateArea: { kind: 'relocateArea', area: { unitKey: UNIT.key, type: 'fp', fpIndex: 1 } },
  rotate: { kind: 'rotate', unitKey: UNIT.key, center: CENTER, previewAngle: null },
  placeJammer: { kind: 'placeJammer', index: 2, isRelocate: false },
  relocateJammer: { kind: 'placeJammer', index: 3, isRelocate: true },
};

describe('selectors', () => {
  it.each(Object.entries(MODES))('%s answers every selector without throwing', (_, mode) => {
    expect(() => {
      selectRelocatingArea(mode);
      selectRotatingUnitKey(mode);
      selectSelectedUnitKey(mode);
      selectSelectedJammerIndex(mode);
      selectRelocatingJammerIndex(mode);
    }).not.toThrow();
  });

  it('only the owning mode is non-null', () => {
    expect(selectRelocatingArea(MODES.relocateArea)).toEqual({
      unitKey: UNIT.key,
      type: 'fp',
      fpIndex: 1,
    });
    expect(selectRelocatingArea(MODES.rotate)).toBeNull();

    expect(selectRotatingUnitKey(MODES.rotate)).toBe(UNIT.key);
    expect(selectRotatingUnitKey(MODES.deploy)).toBeNull();

    expect(selectSelectedUnitKey(MODES.deploy)).toBe(UNIT.key);
    expect(selectSelectedUnitKey(MODES.idle)).toBeNull();

    expect(selectSelectedJammerIndex(MODES.placeJammer)).toBe(2);
    expect(selectSelectedJammerIndex(MODES.relocateJammer)).toBeNull();

    expect(selectRelocatingJammerIndex(MODES.relocateJammer)).toBe(3);
    expect(selectRelocatingJammerIndex(MODES.placeJammer)).toBeNull();
  });
});

describe('formatAreaLabel', () => {
  it('numbers fire points from 1 and labels the rest by type', () => {
    expect(formatAreaLabel({ unitKey: 'k', type: 'fp', fpIndex: 1 })).toBe('Fire Point 2');
    expect(formatAreaLabel({ unitKey: 'k', type: 'aha' })).toBe('AHA');
  });
});

describe('reducer', () => {
  it('hover only carries the angle while rotating', () => {
    const rotating = deploymentModeReducer(IDLE_STATE, {
      type: 'rotate',
      unitKey: UNIT.key,
      center: CENTER,
    });
    const swept = deploymentModeReducer(rotating, {
      type: 'hover',
      position: CENTER,
      rotationAngle: 45,
    });
    expect(selectRotatingUnitKey(swept.mode)).toBe(UNIT.key);
    expect(swept.mode.kind === 'rotate' && swept.mode.previewAngle).toBe(45);

    const idleHover = deploymentModeReducer(IDLE_STATE, {
      type: 'hover',
      position: CENTER,
      rotationAngle: 45,
    });
    expect(idleHover.mode).toEqual({ kind: 'idle' });
  });
});
