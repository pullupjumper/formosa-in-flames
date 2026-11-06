import type { PanelBattery } from '@/types/generated';
import type { DeployedBattery } from '@/types/deployment';

/**
 * Groups the injected batteries the sidebar renders, each carrying its
 * deployment. Pure, so grouping and deployed counters can be tested without
 * mounting the map.
 */

// ============================================================================
// TYPES
// ============================================================================
export interface Battery extends Pick<
  PanelBattery,
  'name' | 'missileSystem' | 'missileSystemType' | 'status'
> {
  /** Placement on the map, null until the battery is deployed */
  deployment: DeployedBattery | null;
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
  deployments: Map<string, DeployedBattery>
): BatteryGroup[] {
  const groups = new Map<string, BatteryGroup>();

  for (const { name, missileSystem, missileSystemType, status } of batteries) {
    const battery: Battery = {
      name,
      missileSystem,
      missileSystemType,
      deployment: deployments.get(name) ?? null,
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

/** Weapon range in NM per battery name, for the map's range circles. */
export function buildWeaponRanges(batteries: PanelBattery[]): Map<string, number> {
  return new Map(batteries.map((battery) => [battery.name, battery.weaponRange]));
}
