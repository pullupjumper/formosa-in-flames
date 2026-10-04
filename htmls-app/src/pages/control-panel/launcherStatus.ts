import type { MissileSystemData, MissileSystemUnit } from '@/types/unitStatus';

/**
 * Lookup of the status payload's launcher rows, so a card can show the live
 * status of its own unit. Rows come grouped by resupply unit name; here they
 * are flattened and keyed by what a card knows: weapon category plus name.
 */

// ============================================================================
// TYPES
// ============================================================================
export interface LauncherStatus extends MissileSystemUnit {
  /** Name of the paired resupply unit, the group the row arrived in */
  resupplyUnitName: string;
}

export type LauncherStatusMap = Map<string, LauncherStatus>;

// ============================================================================
// BUILDER / LOOKUP
// ============================================================================
function statusKey(category: string, name: string): string {
  return `${category}\u0000${name}`;
}

export function buildLauncherStatusMap(data: MissileSystemData | undefined): LauncherStatusMap {
  const map: LauncherStatusMap = new Map();

  for (const [resupplyUnitName, rows] of Object.entries(data || {})) {
    if (!Array.isArray(rows)) continue;
    for (const row of rows) {
      map.set(statusKey(row.missileSystemType, row.name), { ...row, resupplyUnitName });
    }
  }

  return map;
}

export function getLauncherStatus(
  map: LauncherStatusMap,
  category: string,
  name: string
): LauncherStatus | undefined {
  return map.get(statusKey(category, name));
}
