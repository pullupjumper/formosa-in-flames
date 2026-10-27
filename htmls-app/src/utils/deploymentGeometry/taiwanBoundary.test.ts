import { describe, it, expect } from 'vitest';
import { areAllPointsInTaiwan, isPointInTaiwan } from './taiwanBoundary';

describe('isPointInTaiwan', () => {
  it.each([
    ['Taichung plain', 24.15, 120.7],
    ['Tainan', 23.0, 120.2],
    ['Taipei basin', 25.05, 121.55],
  ])('accepts %s', (_label, latitude, longitude) => {
    expect(isPointInTaiwan({ latitude, longitude })).toBe(true);
  });

  it.each([
    ['Taiwan Strait', 24.0, 119.5],
    ['Pacific side', 24.0, 123.0],
    ['south of Hengchun', 21.0, 120.8],
    ['north of Keelung', 26.0, 121.7],
  ])('rejects %s', (_label, latitude, longitude) => {
    expect(isPointInTaiwan({ latitude, longitude })).toBe(false);
  });
});

describe('areAllPointsInTaiwan', () => {
  const inland = { latitude: 23.9, longitude: 120.7 };
  const offshore = { latitude: 23.9, longitude: 119.0 };

  it('accepts a polygon fully inland', () => {
    expect(areAllPointsInTaiwan([inland, { latitude: 23.95, longitude: 120.75 }])).toBe(true);
  });

  it('rejects a polygon with any vertex offshore', () => {
    expect(areAllPointsInTaiwan([inland, offshore])).toBe(false);
  });
});
