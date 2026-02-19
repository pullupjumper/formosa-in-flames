import { CONFIG } from '@/types/setupMenu';

/**
 * Check if a point is inside Taiwan boundary using ray casting algorithm
 */
export function isPointInTaiwan(lat: number, lng: number): boolean {
  let inside = false;
  const x = lng;
  const y = lat;
  const boundary = CONFIG.TAIWAN_BOUNDARY;

  for (let i = 0, j = boundary.length - 1; i < boundary.length; j = i++) {
    const xi = boundary[i][1];
    const yi = boundary[i][0];
    const xj = boundary[j][1];
    const yj = boundary[j][0];

    if (yi > y !== yj > y && x < ((xj - xi) * (y - yi)) / (yj - yi) + xi) {
      inside = !inside;
    }
  }
  return inside;
}

/**
 * Determine suggested opening angle based on position
 */
export function determineOpeningAngle(lat: number, lng: number): number {
  let centerLng: number;
  if (lat >= 25) centerLng = 121.5;
  else if (lat >= 24) centerLng = 121.0 + (lat - 24) * 0.5;
  else if (lat >= 23) centerLng = 120.8 + (lat - 23) * 0.2;
  else centerLng = 120.8;

  return lng < centerLng ? 90 : 270;
}

/**
 * Get weapon system display name
 */
export function getWeaponSystemName(category: string): string {
  return CONFIG.WEAPON_NAMES[category] || category.toUpperCase();
}

/**
 * Calculate center point of polygon vertices
 */
export function calculateCenter(vertices: { latitude: number; longitude: number }[]): {
  lat: number;
  lng: number;
} {
  const lat = vertices.reduce((sum, v) => sum + v.latitude, 0) / vertices.length;
  const lng = vertices.reduce((sum, v) => sum + v.longitude, 0) / vertices.length;
  return { lat, lng };
}

/**
 * Check if all vertices of a polygon are within Taiwan boundary
 */
export function checkPolygonInTaiwan(vertices: { latitude: number; longitude: number }[]): boolean {
  return vertices.every((v) => isPointInTaiwan(v.latitude, v.longitude));
}
