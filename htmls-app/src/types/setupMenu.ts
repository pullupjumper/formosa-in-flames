// Setup Menu Types
//
// Field names on the injected payload types (`Airbase`, `Jammer`,
// `OperationalArea`, ...) are dictated by `unitStatusUI.lua` and must not be
// renamed here.

import type { Coordinate, MovementPath } from '@/types/geo';

// ============================================================================
// INJECTED PAYLOAD
// ============================================================================
export interface Loadout {
  num: number;
  loadoutId: number;
  name: string;
  missionName?: string;
}

export interface EmbarkedUnit {
  dbid: number;
  platformName: string;
  type: string;
  side: string;
  name: string;
  loadouts?: Loadout[];
}

export interface Airbase {
  name: string;
  longitude: number;
  latitude: number;
  baseGUID: string;
  embarkedUnits?: EmbarkedUnit[];
  loadouts?: Loadout[];
}

export interface Jammer {
  zoneName: string;
  name: string;
  randomRadius: number;
  radius: number;
  point?: Coordinate;
}

export interface AreaDefinition {
  course: Coordinate[];
  area: Coordinate[];
}

export interface OperationalArea {
  RL: AreaDefinition[];
  FP: AreaDefinition[];
  AHA: AreaDefinition[];
  HA: AreaDefinition[];
  SHRL: AreaDefinition[];
  uShapeVertices: Coordinate[];
  shelterPoints: Coordinate[];
}

export interface FiringUnit {
  dbid: number;
  resupplyUnit: string;
  guid: string;
  ammoThreshold: number;
  weaponDBID: number;
  name: string;
  operationalArea: OperationalArea;
  state: number;
  msg: string;
}

export interface ResupplyUnit {
  unitCount: number;
  wpnCurrent: number;
  ammunition: string;
  wpnDefault: number;
  name: string;
  state: number;
  guid: string;
  operationalArea: OperationalArea;
}

export interface Ammunition {
  name: string;
  wpnCurrent: number;
  guid: string;
  wpnDefault: number;
}

export interface MissileSystemCategory {
  operationalAreas: Record<string, OperationalArea>;
  reloadTime: number;
  wpnDefault: number;
  firingUnits: Record<string, FiringUnit>;
  resupplyUnits?: Record<string, ResupplyUnit>;
  ammoThreshold: number;
  ammunitions?: Record<string, Ammunition>;
}

export type MissileSystems = Record<string, MissileSystemCategory>;

export interface AmphibiousLocation {
  name: string;
  waypoints: Coordinate[];
}

export interface SetupMenuData {
  airbases: Airbase[];
  jammers: Jammer[];
  missileSystems: MissileSystems;
}

// ============================================================================
// UI STATE
// ============================================================================
export interface BudgetState {
  current: number;
  used: number;
  total: number;
}

export interface TacticalAreas {
  uShapeVertices: Coordinate[];
  ammoArea?: Coordinate[];
  hideArea?: Coordinate[];
  reloadArea?: Coordinate[];
  firePoints?: Coordinate[][];
  shelterPoints?: Coordinate[];
}

/** Keys mirror the Lua `SBJ__MovementPaths` shape and are exported verbatim. */
export interface MovementPaths {
  FP: MovementPath[];
  HA: MovementPath;
  RL: MovementPath[];
  AHA: MovementPath;
  SHRL: MovementPath;
}

/** One missile unit placed on the map, with everything the export needs. */
export interface MissileDeployment {
  unitName: string;
  category: string;
  center: Coordinate;
  openingAngle: number;
  ahaRadius: number;
  ahaCenter?: Coordinate;
  tacticalAreas: TacticalAreas;
  paths: MovementPaths;
}

export type SetupMenuTabId = 'opord' | 'mechanics' | 'deployment' | 'summary';

export interface ForceImage {
  url: string | null;
  label: string;
  width: number;
  height: number;
}
