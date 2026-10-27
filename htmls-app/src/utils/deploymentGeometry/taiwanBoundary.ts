import type { Coordinate } from '@/types/geo';
import { TAIWAN_BOUNDARY } from '@/constants/taiwanBoundary';
import { areAllPointsInPolygon, isPointInPolygon } from '@/utils/geo';

const TAIWAN_POLYGON: Coordinate[] = TAIWAN_BOUNDARY.map(([latitude, longitude]) => ({
  latitude,
  longitude,
}));

export function isPointInTaiwan(point: Coordinate): boolean {
  return isPointInPolygon(point, TAIWAN_POLYGON);
}

export function areAllPointsInTaiwan(points: Coordinate[]): boolean {
  return areAllPointsInPolygon(points, TAIWAN_POLYGON);
}
