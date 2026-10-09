import type { MissileSystemTypes } from '@/types/controlPanel';
import type { MissileDeployment } from '@/types/deployment';
import type { BatteryStatus } from '@/types/controlPanel';

/**
 * Flattens the injected `MissileSystemTypes` payload into the batteries the sidebar
 * renders, each carrying its deployment and live status. Pure, so grouping,
 * deployed counters and status pairing can be tested without mounting the map.
 */

/**
 * Build the key identifying a firing unit inside a missile system type.
 * Deployment maps are keyed by this string throughout the control panel.
 */
export function buildUnitKey(missileSystemType: string, unitname: string): string {
  return `${missileSystemType}_${unitname}`;
}

// ============================================================================
// TYPES
// ============================================================================
export interface Battery {
  /** Key shared by the deployment map and the status lookup: type plus name */
  unitKey: string;
  /** Display name from the game database */
  name: string;
  /** Missile system designation, e.g. `HF-3` */
  missileSystem: string;
  /** Missile system type key the battery is grouped under, e.g. `sam`, `ascm` */
  missileSystemType: string;
  /** Placement on the map, null until the battery is deployed */
  deployment: MissileDeployment | null;
  /** Live status from the live status payload, absent when the game has none */
  status: BatteryStatus | undefined;
}

export interface BatteryGroup {
  missileSystemType: string;
  deployedCount: number;
  batteries: Battery[];
}

// ============================================================================
// BUILDER
// ============================================================================
function buildStatusLookup(statuses: BatteryStatus[] | undefined): Map<string, BatteryStatus> {
  const lookup = new Map<string, BatteryStatus>();

  if (!Array.isArray(statuses)) return lookup;
  for (const status of statuses) {
    lookup.set(buildUnitKey(status.missileSystemType, status.name), status);
  }

  return lookup;
}

export function buildBatteryGroups(
  missileSystemTypes: MissileSystemTypes,
  deployments: Map<string, MissileDeployment>,
  statuses: BatteryStatus[] | undefined
): BatteryGroup[] {
  const statusLookup = buildStatusLookup(statuses);
  const groups: BatteryGroup[] = [];

  for (const [missileSystemType, config] of Object.entries(missileSystemTypes)) {
    if (!config?.firingUnits) continue;

    const batteries = Object.entries(config.firingUnits).map(([unitname, unit]): Battery => {
      const unitKey = buildUnitKey(missileSystemType, unitname);
      return {
        unitKey,
        name: unit.name,
        missileSystem: unit.missileSystem,
        missileSystemType,
        deployment: deployments.get(unitKey) ?? null,
        status: statusLookup.get(buildUnitKey(missileSystemType, unit.name)),
      };
    });

    groups.push({
      missileSystemType,
      deployedCount: batteries.filter((battery) => battery.deployment !== null).length,
      batteries,
    });
  }

  return groups;
}

/** Weapon range in NM per unit key, for the map's range circles. */
export function buildWeaponRanges(missileSystemTypes: MissileSystemTypes): Map<string, number> {
  const ranges = new Map<string, number>();

  for (const [missileSystemType, config] of Object.entries(missileSystemTypes)) {
    for (const [unitname, unit] of Object.entries(config?.firingUnits ?? {})) {
      ranges.set(buildUnitKey(missileSystemType, unitname), unit.weaponRange);
    }
  }

  return ranges;
}
