import { describe, it, expect } from 'vitest';
import {
  isPointInTaiwan,
  determineOpeningAngle,
  getWeaponSystemName,
  calculateCenter,
  checkPolygonInTaiwan,
} from '@/utils/map';

describe('isPointInTaiwan', () => {
  it.each([
    ['Taichung plain', 24.15, 120.7],
    ['Tainan', 23.0, 120.2],
    ['Taipei basin', 25.05, 121.55],
  ])('accepts %s', (_label, lat, lng) => {
    expect(isPointInTaiwan(lat, lng)).toBe(true);
  });

  it.each([
    ['Taiwan Strait', 24.0, 119.5],
    ['Pacific side', 24.0, 123.0],
    ['south of Hengchun', 21.0, 120.8],
    ['north of Keelung', 26.0, 121.7],
  ])('rejects %s', (_label, lat, lng) => {
    expect(isPointInTaiwan(lat, lng)).toBe(false);
  });
});

describe('determineOpeningAngle', () => {
  it('faces east (90) for west-coast positions', () => {
    expect(determineOpeningAngle(25.05, 121.0)).toBe(90);
    expect(determineOpeningAngle(23.5, 120.2)).toBe(90);
  });

  it('faces west (270) for east-coast positions', () => {
    expect(determineOpeningAngle(25.05, 121.8)).toBe(270);
    expect(determineOpeningAngle(23.5, 121.4)).toBe(270);
  });

  it('uses the interpolated ridge line between 23N and 25N', () => {
    // lat 24 -> centerLng 121.0; lat 23 -> centerLng 120.8
    expect(determineOpeningAngle(24, 120.99)).toBe(90);
    expect(determineOpeningAngle(24, 121.01)).toBe(270);
    expect(determineOpeningAngle(23, 120.79)).toBe(90);
    expect(determineOpeningAngle(23, 120.81)).toBe(270);
  });

  it('clamps to the southern reference below 23N', () => {
    expect(determineOpeningAngle(22.0, 120.79)).toBe(90);
    expect(determineOpeningAngle(22.0, 120.81)).toBe(270);
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

describe('calculateCenter', () => {
  it('averages the vertices', () => {
    const center = calculateCenter([
      { latitude: 24, longitude: 120 },
      { latitude: 24, longitude: 121 },
      { latitude: 25, longitude: 121 },
      { latitude: 25, longitude: 120 },
    ]);
    expect(center.lat).toBeCloseTo(24.5, 10);
    expect(center.lng).toBeCloseTo(120.5, 10);
  });
});

describe('checkPolygonInTaiwan', () => {
  const inland = { latitude: 23.9, longitude: 120.7 };
  const offshore = { latitude: 23.9, longitude: 119.0 };

  it('accepts a polygon fully inland', () => {
    expect(checkPolygonInTaiwan([inland, { latitude: 23.95, longitude: 120.75 }])).toBe(true);
  });

  it('rejects a polygon with any vertex offshore', () => {
    expect(checkPolygonInTaiwan([inland, offshore])).toBe(false);
  });
});
