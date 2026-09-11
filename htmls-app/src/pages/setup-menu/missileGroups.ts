import type { MissileSystems, MissileDeployment } from '@/types/setupMenu';
import { getWeaponSystemName, makeUnitKey } from '@/utils/map';

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
  isDeployed: boolean;
  /** Summary line shown on the card once the unit is on the map */
  openingAngle: number | null;
}

export interface MissileGroup {
  category: string;
  weaponName: string;
  /** Weapon name without the parenthesised suffix, used on the unit cards */
  systemName: string;
  deployedCount: number;
  units: MissileGroupUnit[];
}

// ============================================================================
// BUILDER
// ============================================================================
export function buildMissileGroups(
  missileSystems: MissileSystems,
  deployedSystems: Map<string, MissileDeployment>
): MissileGroup[] {
  const groups: MissileGroup[] = [];

  for (const category of Object.keys(missileSystems)) {
    const firingUnits = missileSystems[category]?.firingUnits;
    if (!firingUnits) continue;

    const weaponName = getWeaponSystemName(category);
    const units = Object.entries(firingUnits).map(([unitName, unit]) => {
      const unitKey = makeUnitKey(category, unitName);
      const deployment = deployedSystems.get(unitKey);
      return {
        unitKey,
        name: unit.name,
        isDeployed: deployment !== undefined,
        openingAngle: deployment?.openingAngle ?? null,
      };
    });

    groups.push({
      category,
      weaponName,
      systemName: weaponName.split('(')[0].trim(),
      deployedCount: units.filter((unit) => unit.isDeployed).length,
      units,
    });
  }

  return groups;
}
