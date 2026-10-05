// Control Panel Types
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
  randomRadiusNm: number;
  radius: number;
  pos?: Coordinate;
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
  name: string;
  operationalArea: OperationalArea;
  missileSystem: string;
  /** Weapon range in NM, drives the range circle on the map */
  weaponRange: number;
}

export interface MissileSystemCategory {
  firingUnits: Record<string, FiringUnit>;
}

export type MissileSystems = Record<string, MissileSystemCategory>;

export interface AmphibiousLocation {
  name: string;
  waypoints: Coordinate[];
}

// ============================================================================
// HOST RESULT (what `summaryData` sends back to unitStatusUI.lua)
// Field names mirror `SBJ__ControlPanelResult` in schema.lua and must not change.
// ============================================================================
export interface BudgetResult {
  initial: number;
  used: number;
  remaining: number;
}

export interface JammerResult {
  zoneName: string;
  name: string;
  pos: Coordinate;
  randomRadiusNm: number;
  radius: number;
}

export interface MissileSystemResult {
  key: string;
  unitname: string;
  missileSystemType: string;
  center: Coordinate;
  openingAngle: number;
  tacticalAreas: TacticalAreas;
  paths: MovementPaths;
}

export interface ControlPanelResult {
  budget: BudgetResult;
  airbases: Airbase[];
  jammers: JammerResult[];
  missileSystems: MissileSystemResult[];
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
  missileSystemType: string;
  center: Coordinate;
  openingAngle: number;
  /** Absent on scenario-placed units; the generator then uses AREA_CONFIG. */
  ahaRadius?: number;
  /** Where the AHA square sits; set by hand-relocation or scenario placement. */
  ahaCenter?: Coordinate;
  tacticalAreas: TacticalAreas;
  paths: MovementPaths;
}

export interface ForceImage {
  url: string | null;
  label: string;
  width: number;
  height: number;
}
