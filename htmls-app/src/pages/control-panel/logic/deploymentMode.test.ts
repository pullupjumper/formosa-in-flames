import { describe, it, expect } from 'vitest';
import {
  IDLE_STATE,
  deploymentModeReducer,
  formatAreaLabel,
  selectRelocatingArea,
  selectRotatingBatteryName,
  selectSelectedBatteryName,
  selectSelectedJammerIndex,
  selectRelocatingJammerIndex,
} from './deploymentMode';
import type { DeploymentMode } from './deploymentMode';

const UNIT = { name: 'HF3_01', missileSystemType: 'ascm' };
const CENTER = { latitude: 24, longitude: 121 };

const MODES: Record<string, DeploymentMode> = {
  idle: { kind: 'idle' },
  deploy: { kind: 'deploy', unit: UNIT, offsets: {} },
  relocateArea: { kind: 'relocateArea', area: { batteryName: UNIT.name, type: 'fp', fpIndex: 1 } },
  rotate: { kind: 'rotate', batteryName: UNIT.name, center: CENTER, previewAngle: null },
  placeJammer: { kind: 'placeJammer', index: 2, isRelocate: false },
  relocateJammer: { kind: 'placeJammer', index: 3, isRelocate: true },
};

describe('selectors', () => {
  it.each(Object.entries(MODES))('%s answers every selector without throwing', (_, mode) => {
    expect(() => {
      selectRelocatingArea(mode);
      selectRotatingBatteryName(mode);
      selectSelectedBatteryName(mode);
      selectSelectedJammerIndex(mode);
      selectRelocatingJammerIndex(mode);
    }).not.toThrow();
  });

  it('only the owning mode is non-null', () => {
    expect(selectRelocatingArea(MODES.relocateArea)).toEqual({
      batteryName: UNIT.name,
      type: 'fp',
      fpIndex: 1,
    });
    expect(selectRelocatingArea(MODES.rotate)).toBeNull();

    expect(selectRotatingBatteryName(MODES.rotate)).toBe(UNIT.name);
    expect(selectRotatingBatteryName(MODES.deploy)).toBeNull();

    expect(selectSelectedBatteryName(MODES.deploy)).toBe(UNIT.name);
    expect(selectSelectedBatteryName(MODES.idle)).toBeNull();

    expect(selectSelectedJammerIndex(MODES.placeJammer)).toBe(2);
    expect(selectSelectedJammerIndex(MODES.relocateJammer)).toBeNull();

    expect(selectRelocatingJammerIndex(MODES.relocateJammer)).toBe(3);
    expect(selectRelocatingJammerIndex(MODES.placeJammer)).toBeNull();
  });
});

describe('formatAreaLabel', () => {
  it('numbers fire points from 1 and labels the rest by type', () => {
    expect(formatAreaLabel({ batteryName: 'k', type: 'fp', fpIndex: 1 })).toBe('Fire Point 2');
    expect(formatAreaLabel({ batteryName: 'k', type: 'atp' })).toBe('ATP');
  });
});

describe('reducer', () => {
  it('hover only carries the angle while rotating', () => {
    const rotating = deploymentModeReducer(IDLE_STATE, {
      type: 'rotate',
      batteryName: UNIT.name,
      center: CENTER,
    });
    const swept = deploymentModeReducer(rotating, {
      type: 'hover',
      position: CENTER,
      rotationAngle: 45,
    });
    expect(selectRotatingBatteryName(swept.mode)).toBe(UNIT.name);
    expect(swept.mode.kind === 'rotate' && swept.mode.previewAngle).toBe(45);

    const idleHover = deploymentModeReducer(IDLE_STATE, {
      type: 'hover',
      position: CENTER,
      rotationAngle: 45,
    });
    expect(idleHover.mode).toEqual({ kind: 'idle' });
  });
});
