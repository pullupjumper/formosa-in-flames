import type { PanelBattery } from '@/types/generated';
import type { MissileDeployment } from '@/types/deployment';

/**
 * Groups the injected batteries the sidebar renders, each carrying its
 * deployment. Pure, so grouping and deployed counters can be tested without
 * mounting the map.
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
export interface Battery extends Pick<
  PanelBattery,
  'name' | 'missileSystem' | 'missileSystemType' | 'status'
> {
  /** Key shared by the deployment map and the weapon ranges: type plus name */
  unitKey: string;
  /** Placement on the map, null until the battery is deployed */
  deployment: MissileDeployment | null;
}

export interface BatteryGroup {
  missileSystemType: string;
  deployedCount: number;
  batteries: Battery[];
}

// ============================================================================
// BUILDER
// ============================================================================
/** Groups batteries by type, in the order each type first appears. */
export function buildBatteryGroups(
  batteries: PanelBattery[],
  deployments: Map<string, MissileDeployment>
): BatteryGroup[] {
  const groups = new Map<string, BatteryGroup>();

  for (const { name, missileSystem, missileSystemType, status } of batteries) {
    const unitKey = buildUnitKey(missileSystemType, name);
    const battery: Battery = {
      unitKey,
      name,
      missileSystem,
      missileSystemType,
      deployment: deployments.get(unitKey) ?? null,
      status,
    };
    const group = groups.get(battery.missileSystemType) ?? {
      missileSystemType: battery.missileSystemType,
      deployedCount: 0,
      batteries: [],
    };

    group.batteries.push(battery);
    if (battery.deployment) group.deployedCount += 1;
    groups.set(battery.missileSystemType, group);
  }

  return Array.from(groups.values());
}

/** Weapon range in NM per unit key, for the map's range circles. */
export function buildWeaponRanges(batteries: PanelBattery[]): Map<string, number> {
  return new Map(
    batteries.map((battery) => [
      buildUnitKey(battery.missileSystemType, battery.name),
      battery.weaponRange,
    ])
  );
}
