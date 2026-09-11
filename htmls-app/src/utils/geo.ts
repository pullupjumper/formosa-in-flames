import type { LatLng, LatLngExpression } from 'leaflet';
import type { Coordinate, CoordinateOffset } from '@/types/geo';
import { CONFIG } from '@/constants/setupMenu';

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
