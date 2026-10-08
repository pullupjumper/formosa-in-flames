import type { Coordinate } from '@/types/geo';
import { calculateCentroid, calculateDistance, isPointInPolygon } from '@/utils/geo';
import type { C2Data, C2Node, C2Unit } from '@/types/unitStatus';
import type { Battery } from '@pages/control-panel/logic/batteryGroups';

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
  type: 'sam' | 'radar';
  unit: C2Unit;
  /** Matching missile battery, present only for SAM units that can be deployed */
  battery: Battery | null;
}

/** One live SAM unit and its weapons control status, as written to `emconData`. */
export interface SamDoctrineEntry {
  guid: string;
  name: string;
  weaponFree: boolean;
}

export interface C2NodeView {
  key: string;
  type: string;
  name: string;
  pos: Coordinate;
  /** Operating zones of the node, one polygon each */
  areas: Coordinate[][];
  children: C2Child[];
}

export interface C2ZoneLayer {
  key: string;
  vertices: Coordinate[];
}

export interface C2MarkerLayer {
  key: string;
  kind: 'c2' | 'sam' | 'radar';
  name: string;
  pos: Coordinate;
  isDestroyed: boolean;
}

export interface C2LinkLayer {
  key: string;
  from: Coordinate;
  to: Coordinate;
}

export interface C2MapLayers {
  zones: C2ZoneLayer[];
  links: C2LinkLayer[];
  markers: C2MarkerLayer[];
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
 * Pair every SAM unit with its battery by name. A battery backs at most one SAM
 * unit so two cards never drive the same deployment.
 */
export function buildC2NodeViews(c2Data: C2Data, samBatteries: Battery[]): C2NodeView[] {
  const claimed = new Set<string>();

  const findBattery = (name: string): Battery | null => {
    const battery =
      samBatteries.find((unit) => unit.name === name && !claimed.has(unit.unitKey)) ?? null;
    if (battery) claimed.add(battery.unitKey);
    return battery;
  };

  return Object.entries(flattenC2Nodes(c2Data)).map(([key, node]) => {
    const children: C2Child[] = [];

    for (const [guid, unit] of Object.entries(node.radar ?? {})) {
      children.push({ key: guid, type: 'radar', unit, battery: null });
    }
    for (const [guid, unit] of Object.entries(node.sam ?? {})) {
      children.push({ key: guid, type: 'sam', unit, battery: findBattery(unit.name) });
    }

    return {
      key,
      type: node.type,
      name: node.name,
      pos: node.pos,
      areas: node.areas ?? [],
      children,
    };
  });
}

/** Every live SAM unit under any node; destroyed ones can no longer be ordered. */
export function collectSamUnits(views: C2NodeView[]): SamDoctrineEntry[] {
  return views.flatMap((view) =>
    view.children
      .filter((child) => child.type === 'sam' && !child.unit.isDestroyed)
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
      child.type === 'sam' ? { ...child, unit: { ...child.unit, weaponFree } } : child
    ),
  }));
}

// ============================================================================
// MAP LAYERS
// ============================================================================
function zoneKey(vertices: Coordinate[]): string {
  return vertices.map((v) => `${v.latitude.toFixed(5)},${v.longitude.toFixed(5)}`).join('|');
}

/**
 * The node a redeployed SAM reports to: the closest C2 of the SAM's own C2 type
 * (a ROCC SAM never links to a TAAOC node), and only when the deployed position
 * lies inside one of that node's operating zones.
 */
function findCommandingNode(
  position: Coordinate,
  c2Type: string,
  views: C2NodeView[]
): C2NodeView | null {
  let nearest: C2NodeView | null = null;
  let nearestDistance = Infinity;

  for (const view of views) {
    if (!view.pos || view.type !== c2Type) continue;
    const distance = calculateDistance(view.pos, position);
    if (distance < nearestDistance) {
      nearest = view;
      nearestDistance = distance;
    }
  }

  return nearest && nearest.areas.some((area) => isPointInPolygon(position, area)) ? nearest : null;
}

/**
 * What the map draws for the nodes: each operating zone once (nodes may share
 * the same polygon) and one marker per node, SAM and radar that has a position.
 * SAM units already deployed through a battery are left out so the unit is not
 * drawn twice.
 */
export function buildC2MapLayers(views: C2NodeView[]): C2MapLayers {
  const zones = new Map<string, C2ZoneLayer>();
  const markers: C2MarkerLayer[] = [];
  const links: C2LinkLayer[] = [];

  for (const view of views) {
    for (const vertices of view.areas) {
      const key = zoneKey(vertices);
      if (vertices.length >= 3 && !zones.has(key)) zones.set(key, { key, vertices });
    }

    if (view.pos) {
      markers.push({
        key: view.key,
        kind: 'c2',
        name: view.name,
        pos: view.pos,
        isDestroyed: false,
      });
    }
    for (const child of view.children) {
      // A deployed SAM already has its own marker on the deployment layer; it is
      // linked by where the player put it, not by where the unit was before
      const deployment = child.battery?.deployment;
      if (deployment) {
        const hideArea = deployment.tacticalAreas.hideArea;
        const position = hideArea?.length ? calculateCentroid(hideArea) : null;
        const commander = position ? findCommandingNode(position, child.unit.type, views) : null;
        if (position && commander) {
          links.push({ key: `${commander.key}-${child.key}`, from: commander.pos, to: position });
        }
        continue;
      }
      if (!child.unit.pos) continue;
      markers.push({
        key: child.key,
        kind: child.type,
        name: child.unit.name,
        pos: child.unit.pos,
        isDestroyed: child.unit.isDestroyed,
      });
      if (view.pos) {
        links.push({ key: `${view.key}-${child.key}`, from: view.pos, to: child.unit.pos });
      }
    }
  }

  return { zones: [...zones.values()], links, markers };
}
