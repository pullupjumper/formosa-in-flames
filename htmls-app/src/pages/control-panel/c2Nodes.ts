import type { C2Node, C2Unit } from '@/types/unitStatus';
import type { SamDoctrineEntry } from '@/utils/emcon';
import type { MissileGroupUnit } from '@pages/control-panel/missileGroups';

/**
 * View model for the C2 Nodes panel: each node with its radar and SAM units,
 * and the launcher a SAM unit can be deployed through when the missile system
 * list knows it too.
 */

// ============================================================================
// TYPES
// ============================================================================
export interface C2Child {
  key: string;
  type: 'SAM' | 'Radar';
  unit: C2Unit;
  /** Matching missile launcher, present only for SAM units that can be deployed */
  launcher: MissileGroupUnit | null;
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
 * Pair every SAM unit with its launcher: by GUID first (the C2 payload keys SAM
 * units by game GUID), then by name. A launcher backs at most one SAM unit so
 * two cards never drive the same deployment.
 */
export function buildC2NodeViews(
  nodes: Record<string, C2Node>,
  samLaunchers: MissileGroupUnit[]
): C2NodeView[] {
  const claimed = new Set<string>();

  const findLauncher = (guid: string, name: string): MissileGroupUnit | null => {
    const launcher =
      samLaunchers.find((unit) => unit.guid === guid && !claimed.has(unit.unitKey)) ??
      samLaunchers.find((unit) => unit.name === name && !claimed.has(unit.unitKey)) ??
      null;
    if (launcher) claimed.add(launcher.unitKey);
    return launcher;
  };

  return Object.entries(nodes).map(([key, node]) => {
    const children: C2Child[] = [];

    for (const [guid, unit] of Object.entries(node.radar ?? {})) {
      children.push({ key: guid, type: 'Radar', unit, launcher: null });
    }
    for (const [guid, unit] of Object.entries(node.SAM ?? {})) {
      children.push({ key: guid, type: 'SAM', unit, launcher: findLauncher(guid, unit.name) });
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
