import type { LatLng, LatLngExpression } from 'leaflet';
import type { Coordinate, CoordinateOffset } from '@/types/geo';
import { CONFIG } from '@/constants/controlPanel';

/**
 * Coordinate helpers that every layer shares. Pure functions over
 * `Coordinate`; the Leaflet `lat`/`lng` shape is converted here and nowhere
 * else.
 */

// ============================================================================
// UNITS
// ============================================================================
export const NM_TO_METERS = 1852;

/** Leaflet radii are in meters, the game works in nautical miles. */
export function nauticalMilesToMeters(nauticalMiles: number): number {
  return nauticalMiles * NM_TO_METERS;
}

// ============================================================================
// GREAT-CIRCLE MATH (nautical miles, degrees)
// ============================================================================
const EARTH_RADIUS_NM = 3440.065;

function toRadians(degrees: number): number {
  return (degrees * Math.PI) / 180;
}

function toDegrees(radians: number): number {
  return (radians * 180) / Math.PI;
}

/** Great-circle distance in nautical miles (haversine). */
export function calculateDistance(from: Coordinate, to: Coordinate): number {
  const latitudeDelta = toRadians(to.latitude - from.latitude);
  const longitudeDelta = toRadians(to.longitude - from.longitude);
  const a =
    Math.sin(latitudeDelta / 2) * Math.sin(latitudeDelta / 2) +
    Math.cos(toRadians(from.latitude)) *
      Math.cos(toRadians(to.latitude)) *
      Math.sin(longitudeDelta / 2) *
      Math.sin(longitudeDelta / 2);

  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return EARTH_RADIUS_NM * c;
}

/** Initial bearing from `from` to `to`, in degrees [0, 360). */
export function calculateBearing(from: Coordinate, to: Coordinate): number {
  const longitudeDelta = toRadians(to.longitude - from.longitude);
  const fromLatitude = toRadians(from.latitude);
  const toLatitude = toRadians(to.latitude);

  const y = Math.sin(longitudeDelta) * Math.cos(toLatitude);
  const x =
    Math.cos(fromLatitude) * Math.sin(toLatitude) -
    Math.sin(fromLatitude) * Math.cos(toLatitude) * Math.cos(longitudeDelta);

  const bearing = toDegrees(Math.atan2(y, x));
  return (bearing + 360) % 360;
}

/** Destination point `distance` NM from `origin` along `bearing` degrees. */
export function getPointFromBearing(
  origin: Coordinate,
  bearing: number,
  distance: number
): Coordinate {
  const bearingRad = toRadians(bearing);
  const latitudeRad = toRadians(origin.latitude);
  const longitudeRad = toRadians(origin.longitude);
  const angularDistance = distance / EARTH_RADIUS_NM;

  const newLatitudeRad = Math.asin(
    Math.sin(latitudeRad) * Math.cos(angularDistance) +
      Math.cos(latitudeRad) * Math.sin(angularDistance) * Math.cos(bearingRad)
  );

  const newLongitudeRad =
    longitudeRad +
    Math.atan2(
      Math.sin(bearingRad) * Math.sin(angularDistance) * Math.cos(latitudeRad),
      Math.cos(angularDistance) - Math.sin(latitudeRad) * Math.sin(newLatitudeRad)
    );

  return {
    latitude: toDegrees(newLatitudeRad),
    longitude: toDegrees(newLongitudeRad),
  };
}

// ============================================================================
// GEOMETRY
// ============================================================================
/** Arithmetic mean of the vertices; good enough for the small squares here. */
export function calculateCentroid(vertices: Coordinate[]): Coordinate {
  if (vertices.length === 0) {
    throw new Error('calculateCentroid requires at least one vertex');
  }
  let latitudeSum = 0;
  let longitudeSum = 0;
  for (const vertex of vertices) {
    latitudeSum += vertex.latitude;
    longitudeSum += vertex.longitude;
  }
  return {
    latitude: latitudeSum / vertices.length,
    longitude: longitudeSum / vertices.length,
  };
}

/** Ray casting; half-open, so a point on a shared edge belongs to one side. */
export function isPointInPolygon(point: Coordinate, polygon: Coordinate[]): boolean {
  let inside = false;
  for (let i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
    const yi = polygon[i].latitude;
    const xi = polygon[i].longitude;
    const yj = polygon[j].latitude;
    const xj = polygon[j].longitude;
    if (
      yi > point.latitude !== yj > point.latitude &&
      point.longitude < ((xj - xi) * (point.latitude - yi)) / (yj - yi) + xi
    ) {
      inside = !inside;
    }
  }
  return inside;
}

export function areAllPointsInPolygon(points: Coordinate[], polygon: Coordinate[]): boolean {
  return points.every((point) => isPointInPolygon(point, polygon));
}

export function translateCoordinate(base: Coordinate, offset: CoordinateOffset): Coordinate {
  return {
    latitude: base.latitude + offset.latitudeDelta,
    longitude: base.longitude + offset.longitudeDelta,
  };
}

// ============================================================================
// TAIWAN BOUNDARY
// ============================================================================
const TAIWAN_POLYGON: Coordinate[] = CONFIG.TAIWAN_BOUNDARY.map(([latitude, longitude]) => ({
  latitude,
  longitude,
}));

export function isPointInTaiwan(point: Coordinate): boolean {
  return isPointInPolygon(point, TAIWAN_POLYGON);
}

export function areAllPointsInTaiwan(points: Coordinate[]): boolean {
  return areAllPointsInPolygon(points, TAIWAN_POLYGON);
}

// ============================================================================
// LEAFLET CONVERSION
// ============================================================================
export function toLeafletLatLng(coordinate: Coordinate): LatLngExpression {
  return [coordinate.latitude, coordinate.longitude];
}

export function toLeafletPositions(coordinates: Coordinate[]): LatLngExpression[] {
  return coordinates.map(toLeafletLatLng);
}

export function fromLeafletLatLng(latLng: LatLng): Coordinate {
  return { latitude: latLng.lat, longitude: latLng.lng };
}
