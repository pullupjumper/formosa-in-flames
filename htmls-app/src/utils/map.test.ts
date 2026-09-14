import { describe, it, expect } from 'vitest';
import { resolveOpeningAngle, getWeaponSystemName, makeUnitKey } from '@/utils/map';

describe('resolveOpeningAngle', () => {
  const at = (latitude: number, longitude: number) => resolveOpeningAngle({ latitude, longitude });

  it('faces east (90) for west-coast positions', () => {
    expect(at(25.05, 121.0)).toBe(90);
    expect(at(23.5, 120.2)).toBe(90);
  });

  it('faces west (270) for east-coast positions', () => {
    expect(at(25.05, 121.8)).toBe(270);
    expect(at(23.5, 121.4)).toBe(270);
  });

  it('uses the interpolated ridge line between 23N and 25N', () => {
    // lat 24 -> ridge 121.0; lat 23 -> ridge 120.8
    expect(at(24, 120.99)).toBe(90);
    expect(at(24, 121.01)).toBe(270);
    expect(at(23, 120.79)).toBe(90);
    expect(at(23, 120.81)).toBe(270);
  });

  it('clamps to the southern reference below 23N', () => {
    expect(at(22.0, 120.79)).toBe(90);
    expect(at(22.0, 120.81)).toBe(270);
  });
});

describe('getWeaponSystemName', () => {
  it('maps a known category to its display name', () => {
    expect(getWeaponSystemName('sam')).toBe('SAM (Long-Range Air Defense/108 NM)');
  });

  it('upper-cases an unknown category', () => {
    expect(getWeaponSystemName('foo')).toBe('FOO');
  });
});

describe('unit keys', () => {
  it('joins the category and the unit name', () => {
    expect(makeUnitKey('ascm', 'HF3_01')).toBe('ascm_HF3_01');
  });
});
