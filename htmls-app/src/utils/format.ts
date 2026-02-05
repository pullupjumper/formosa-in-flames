/**
 * Format Unix timestamp to readable date string
 */
export function formatTimestamp(timestamp: number | string | undefined): string {
  if (!timestamp) return 'N/A';

  const ts = typeof timestamp === 'string' ? parseInt(timestamp, 10) : timestamp;
  if (isNaN(ts)) return String(timestamp);

  const date = new Date(ts * 1000);
  const year = date.getUTCFullYear();
  const month = String(date.getUTCMonth() + 1).padStart(2, '0');
  const day = String(date.getUTCDate()).padStart(2, '0');
  const hours = String(date.getUTCHours()).padStart(2, '0');
  const minutes = String(date.getUTCMinutes()).padStart(2, '0');
  const seconds = String(date.getUTCSeconds()).padStart(2, '0');

  return `${year}-${month}-${day} ${hours}:${minutes}:${seconds}`;
}

/**
 * Format coordinates to readable string
 */
export function formatCoordinates(
  latitude: number | undefined,
  longitude: number | undefined
): { lat: string; lng: string } {
  const lat = latitude || 0;
  const lng = longitude || 0;
  const latDir = lat >= 0 ? 'N' : 'S';
  const lngDir = lng >= 0 ? 'E' : 'W';

  return {
    lat: `${Math.abs(lat).toFixed(4)}° ${latDir}`,
    lng: `${Math.abs(lng).toFixed(4)}° ${lngDir}`,
  };
}

/**
 * Calculate progress percentage
 */
export function calculateProgress(current: number, total: number): number {
  if (total <= 0) return 0;
  return Math.round((current / total) * 100);
}

/**
 * Check if data is empty
 */
export function isDataEmpty(data: unknown): boolean {
  if (!data) return true;
  if (Array.isArray(data)) return data.length === 0;
  if (typeof data === 'object') return Object.keys(data).length === 0;
  return true;
}
