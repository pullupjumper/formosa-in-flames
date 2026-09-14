import { describe, it, expect } from 'vitest';
import {
  NM_TO_METERS,
  areAllPointsInPolygon,
  areAllPointsInTaiwan,
  calculateBearing,
  calculateCentroid,
  calculateDistance,
  getPointFromBearing,
  fromLeafletLatLng,
  isPointInPolygon,
  isPointInTaiwan,
  nauticalMilesToMeters,
  toLeafletLatLng,
  toLeafletPositions,
  translateCoordinate,
} from '@/utils/geo';
import type { Coordinate } from '@/types/geo';
import L from 'leaflet';

const SQUARE: Coordinate[] = [
  { latitude: 24, longitude: 120 },
  { latitude: 24, longitude: 121 },
  { latitude: 25, longitude: 121 },
  { latitude: 25, longitude: 120 },
];

describe('nauticalMilesToMeters', () => {
  it('uses the international nautical mile', () => {
    expect(NM_TO_METERS).toBe(1852);
    expect(nauticalMilesToMeters(2)).toBe(3704);
  });
});

const CENTER: Coordinate = { latitude: 23.8, longitude: 121.0 };

function at(latitude: number, longitude: number): Coordinate {
  return { latitude, longitude };
}

describe('calculateDistance', () => {
  it('is zero for identical points', () => {
    expect(calculateDistance(CENTER, CENTER)).toBe(0);
  });

  it('matches one nautical mile per latitude minute', () => {
    expect(calculateDistance(CENTER, at(23.8 + 1 / 60, 121))).toBeCloseTo(1, 2);
  });

  it('is symmetric', () => {
    const forward = calculateDistance(at(23.8, 121), at(24.2, 120.6));
    const backward = calculateDistance(at(24.2, 120.6), at(23.8, 121));
    expect(forward).toBeCloseTo(backward, 10);
  });
});

describe('calculateBearing', () => {
  it.each([
    ['north', 24.0, 121.0, 0],
    ['east', 23.8, 121.2, 90],
    ['south', 23.6, 121.0, 180],
    ['west', 23.8, 120.8, 270],
  ])('reports %s', (_label, latitude, longitude, expected) => {
    expect(calculateBearing(CENTER, at(latitude, longitude))).toBeCloseTo(expected, 1);
  });

  it('always returns a value in [0, 360)', () => {
    for (let i = 0; i < 360; i += 7) {
      const point = getPointFromBearing(CENTER, i, 2);
      const bearing = calculateBearing(CENTER, point);
      expect(bearing).toBeGreaterThanOrEqual(0);
      expect(bearing).toBeLessThan(360);
    }
  });
});

describe('getPointFromBearing', () => {
  it('round-trips through calculateDistance/calculateBearing', () => {
    for (const bearing of [0, 37, 123, 271, 359]) {
      const point = getPointFromBearing(CENTER, bearing, 3);
      expect(calculateDistance(CENTER, point)).toBeCloseTo(3, 6);
      expect(calculateBearing(CENTER, point)).toBeCloseTo(bearing, 4);
    }
  });
});

describe('calculateCentroid', () => {
  it('averages the vertices', () => {
    expect(calculateCentroid(SQUARE)).toEqual({ latitude: 24.5, longitude: 120.5 });
  });

  it('throws on an empty list', () => {
    expect(() => calculateCentroid([])).toThrow();
  });
});

describe('isPointInPolygon', () => {
  it('accepts an interior point', () => {
    expect(isPointInPolygon({ latitude: 24.5, longitude: 120.5 }, SQUARE)).toBe(true);
  });

  it('rejects an exterior point', () => {
    expect(isPointInPolygon({ latitude: 24.5, longitude: 121.5 }, SQUARE)).toBe(false);
    expect(isPointInPolygon({ latitude: 26, longitude: 120.5 }, SQUARE)).toBe(false);
  });

  it('is consistent on the shared edge of two adjacent polygons', () => {
    // Ray casting is half-open, so a point on the shared boundary must belong
    // to exactly one of the two squares - never both, never neither.
    const right: Coordinate[] = [
      { latitude: 24, longitude: 121 },
      { latitude: 24, longitude: 122 },
      { latitude: 25, longitude: 122 },
      { latitude: 25, longitude: 121 },
    ];
    const onEdge = { latitude: 24.5, longitude: 121 };
    expect(Number(isPointInPolygon(onEdge, SQUARE)) + Number(isPointInPolygon(onEdge, right))).toBe(
      1
    );
  });
});

describe('areAllPointsInPolygon', () => {
  it('requires every point to be inside', () => {
    const inside = { latitude: 24.5, longitude: 120.5 };
    const outside = { latitude: 24.5, longitude: 121.5 };
    expect(areAllPointsInPolygon([inside, inside], SQUARE)).toBe(true);
    expect(areAllPointsInPolygon([inside, outside], SQUARE)).toBe(false);
  });

  it('is vacuously true for an empty list', () => {
    expect(areAllPointsInPolygon([], SQUARE)).toBe(true);
  });
});

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

describe('translateCoordinate', () => {
  it('adds the degree deltas', () => {
    expect(
      translateCoordinate(
        { latitude: 24, longitude: 120 },
        { latitudeDelta: 0.5, longitudeDelta: -0.25 }
      )
    ).toEqual({ latitude: 24.5, longitude: 119.75 });
  });
});

describe('Leaflet conversion', () => {
  it('emits [latitude, longitude] tuples', () => {
    expect(toLeafletLatLng({ latitude: 24, longitude: 120 })).toEqual([24, 120]);
    expect(toLeafletPositions(SQUARE.slice(0, 2))).toEqual([
      [24, 120],
      [24, 121],
    ]);
  });

  it('reads Leaflet lat/lng back into a Coordinate', () => {
    expect(fromLeafletLatLng(L.latLng(24, 120))).toEqual({ latitude: 24, longitude: 120 });
  });
});
