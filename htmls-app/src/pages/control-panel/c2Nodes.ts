import type { C2Data, C2Node, C2Unit } from '@/types/unitStatus';
import type { MissileGroupUnit } from '@pages/control-panel/missileGroups';

/**
 * View model for the C2 Nodes section: each node with its radar and SAM units,
 * and the battery a SAM unit can be deployed through when the missile system
 * list knows it too.
 */

// ============================================================================
// TYPES
// ============================================================================
export interface C2Child {
  key: string;
  type: 'SAM' | 'Radar';
  unit: C2Unit;
  /** Matching missile battery, present only for SAM units that can be deployed */
  battery: MissileGroupUnit | null;
}

/** One live SAM unit and its weapons control status, as written to `emconData`. */
export interface SamDoctrineEntry {
  guid: string;
  name: string;
  weaponFree: boolean;
}

export interface C2NodeView {
  key: string;
  name: string;
  children: C2Child[];
}

// ============================================================================
// BUILDER
// ============================================================================
/**
 * Flatten injected C2 data into `guid -> node`. Accepts both direct nodes
 * `{ ROCC: {...}, TAAOC: {...} }` and the Lua payload's wrapped groups
 * `{ rocc: { guid1: {...}, guid2: {...} } }`.
 */
function flattenC2Nodes(data: C2Data): Record<string, C2Node> {
  const flatNodes: Record<string, C2Node> = {};

  for (const [key, value] of Object.entries(data)) {
    if (value && typeof value === 'object' && 'name' in value) {
      flatNodes[key] = value as C2Node;
    } else if (value && typeof value === 'object') {
      for (const [subKey, subValue] of Object.entries(value as Record<string, C2Node>)) {
        flatNodes[subKey] = subValue;
      }
    }
  }

  return flatNodes;
}

/**
 * Pair every SAM unit with its battery: by GUID first (the C2 payload keys SAM
 * units by game GUID), then by name. A battery backs at most one SAM unit so
 * two cards never drive the same deployment.
 */
export function buildC2NodeViews(c2Data: C2Data, samBatteries: MissileGroupUnit[]): C2NodeView[] {
  const claimed = new Set<string>();

  const findBattery = (guid: string, name: string): MissileGroupUnit | null => {
    const battery =
      samBatteries.find((unit) => unit.guid === guid && !claimed.has(unit.unitKey)) ??
      samBatteries.find((unit) => unit.name === name && !claimed.has(unit.unitKey)) ??
      null;
    if (battery) claimed.add(battery.unitKey);
    return battery;
  };

  return Object.entries(flattenC2Nodes(c2Data)).map(([key, node]) => {
    const children: C2Child[] = [];

    for (const [guid, unit] of Object.entries(node.radar ?? {})) {
      children.push({ key: guid, type: 'Radar', unit, battery: null });
    }
    for (const [guid, unit] of Object.entries(node.SAM ?? {})) {
      children.push({ key: guid, type: 'SAM', unit, battery: findBattery(guid, unit.name) });
    }

    return { key, name: node.name, children };
  });
}

/** Every live SAM unit under any node; destroyed ones can no longer be ordered. */
export function collectSamUnits(views: C2NodeView[]): SamDoctrineEntry[] {
  return views.flatMap((view) =>
    view.children
      .filter((child) => child.type === 'SAM' && !child.unit.isDestroyed)
      .map((child) => ({
        guid: child.key,
        name: child.unit.name,
        weaponFree: child.unit.weaponFree,
      }))
  );
}

/**
 * The nodes as the player's checkbox would leave them: every SAM unit takes the
 * chosen status. `null` is "untouched" and returns the nodes as they are.
 */
export function applySamWeaponsFree(views: C2NodeView[], weaponFree: boolean | null): C2NodeView[] {
  if (weaponFree === null) return views;

  return views.map((view) => ({
    ...view,
    children: view.children.map((child) =>
      child.type === 'SAM' ? { ...child, unit: { ...child.unit, weaponFree } } : child
    ),
  }));
}
