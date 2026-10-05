import type { MissileSystems, MissileDeployment } from '@/types/controlPanel';
import { buildUnitKey } from '@/utils/map';

/**
 * Flattens the injected `MissileSystems` payload into the shape the sidebar
 * renders. Pure, so the grouping and the deployed counters can be tested without
 * mounting the map.
 */

// ============================================================================
// TYPES
// ============================================================================
export interface MissileGroupUnit {
  unitKey: string;
  /** Display name from the game database */
  name: string;
  /** Game unit GUID, the key C2 nodes list their SAM units by */
  isDeployed: boolean;
  /** Summary line shown on the card once the unit is on the map */
  openingAngle: number | null;
  missileSystem: string;
  /** Weapon name without the parenthesised suffix, e.g. `SAM` */
  missileSystemType: string;
}

export interface MissileGroup {
  missileSystemType: string;
  deployedCount: number;
  units: MissileGroupUnit[];
}

// ============================================================================
// BUILDER
// ============================================================================
export function buildMissileGroups(
  missileSystems: MissileSystems,
  deployedMissileSystems: Map<string, MissileDeployment>
): MissileGroup[] {
  const groups: MissileGroup[] = [];

  for (const missileSystemType of Object.keys(missileSystems)) {
    const firingUnits = missileSystems[missileSystemType]?.firingUnits;
    if (!firingUnits) continue;

    // const weaponName = getWeaponSystemName(category);
    // const missileSystemType = weaponName.split('(')[0].trim();
    const units = Object.entries(firingUnits).map(([unitName, unit]) => {
      const unitKey = buildUnitKey(missileSystemType, unitName);
      const deployment = deployedMissileSystems.get(unitKey);
      return {
        unitKey,
        name: unit.name,
        missileSystem: unit.missileSystem,
        missileSystemType: missileSystemType.toUpperCase(),
        // guid: unit.guid,
        isDeployed: deployment !== undefined,
        openingAngle: deployment?.openingAngle ?? null,
      };
    });

    groups.push({
      missileSystemType: missileSystemType,
      deployedCount: units.filter((unit) => unit.isDeployed).length,
      units,
    });
  }

  return groups;
}
