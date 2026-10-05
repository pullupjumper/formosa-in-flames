import type { BatteryStatus } from '@/types/unitStatus';

/**
 * Lookup of the battery statuses, so a card can show the live status of its
 * own unit. Keyed by what a card knows: weapon category plus unit name.
 */

// ============================================================================
// TYPES
// ============================================================================
export type BatteryStatusMap = Map<string, BatteryStatus>;

// ============================================================================
// BUILDER / LOOKUP
// ============================================================================
function statusKey(category: string, name: string): string {
  return `${category}\u0000${name}`;
}

export function buildBatteryStatusMap(data: BatteryStatus[] | undefined): BatteryStatusMap {
  const map: BatteryStatusMap = new Map();

  if (!Array.isArray(data)) return map;
  for (const status of data) {
    map.set(statusKey(status.missileSystemType, status.name), status);
  }

  return map;
}

export function getBatteryStatus(
  map: BatteryStatusMap,
  category: string,
  name: string
): BatteryStatus | undefined {
  return map.get(statusKey(category, name));
}
