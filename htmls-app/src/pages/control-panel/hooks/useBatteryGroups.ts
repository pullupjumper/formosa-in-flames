import { useMemo } from 'react';
import type { DeployedBattery } from '@/types/deployment';
import { buildBatteryGroups, buildWeaponRanges } from '../logic/batteryGroups';
import type { ControlPanelPayload } from '../logic/controlPanelPayload';

// SAM batteries are deployed from their C2 node card, not the battery list
const SAM_TYPE = 'sam';

/**
 * Missile batteries of the Deployment tab: the SAM batteries (listed under C2
 * nodes), the other battery groups with their deployed counts, and the weapon
 * ranges the map draws.
 */
export function useBatteryGroups(
  payload: ControlPanelPayload,
  deployedBatteries: Map<string, DeployedBattery>
) {
  const { batteries } = payload;

  const allGroups = useMemo(
    () => buildBatteryGroups(batteries, deployedBatteries),
    [batteries, deployedBatteries]
  );
  const samBatteries = useMemo(
    () => allGroups.find((group) => group.missileSystemType === SAM_TYPE)?.batteries ?? [],
    [allGroups]
  );
  const batteryGroups = useMemo(
    () => allGroups.filter((group) => group.missileSystemType !== SAM_TYPE),
    [allGroups]
  );
  const weaponRanges = useMemo(() => buildWeaponRanges(batteries), [batteries]);

  return {
    samBatteries,
    batteryGroups,
    weaponRanges,
    deployedCount: batteryGroups.reduce((sum, group) => sum + group.deployedCount, 0),
    totalCount: batteryGroups.reduce((sum, group) => sum + group.batteries.length, 0),
  };
}
