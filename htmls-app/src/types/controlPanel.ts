// Control Panel Types
//
// Field names on the injected payload types (`Airbase`, `Jammer`,
// `OperationalArea`, `C2Node`, ...) are dictated by `unitStatusUI.lua` and must
// not be renamed here.

import type { Coordinate } from '@/types/geo';
import type { MovementPaths, TacticalAreas } from '@/types/deployment';

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
  radiusNm: number;
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

export interface MissileSystemConfig {
  firingUnits: Record<string, FiringUnit>;
}

export type MissileSystemTypes = Record<string, MissileSystemConfig>;

export interface AmphibiousLocation {
  name: string;
  waypoints: Coordinate[];
}

/** One `addXXX` option the side can run. */
export interface AddUnitAction {
  id: string;
  label: string;
}

// ============================================================================
// INJECTED PAYLOAD (live status: signals, batteries, C2, landing units)
// ============================================================================
export interface Signal {
  name: string;
  type: string;
  autodetectable: boolean;
  latitude?: number;
  longitude?: number;
  firstDetected: number | string;
  lastDetected: number | string;
  detectionCount: number;
  confidence: number;
  currentDetectionLevel?: number;
}

export interface BatteryStatus {
  name: string;
  missileSystemType: string;
  firingUnitState: string;
  resupplyUnitState: string;
  firingUnitReloadTime: number;
  defaultReloadTime: number;
  resupplyUnitReloadTime: number;
  missilesInAmmoVehicles: number;
  missilesInTransloaderDefault: number;
  missilesInAHA: number;
  missilesInAHADefault: number;
}

export interface C2Unit {
  /** Type of the C2 node the unit reports to: 'c2', 'rocc' or 'taaoc' */
  type: string;
  name: string;
  OODADetection: string;
  OODATargeting: string;
  isOutOfComms: boolean;
  EMCONSetting: string;
  isDestroyed: boolean;
  weaponFree: boolean;
  pos: Coordinate;
}

export interface C2Node {
  /** IADS group the node belongs to: 'c2', 'rocc' or 'taaoc' */
  type: string;
  name: string;
  pos: Coordinate;
  areas: Coordinate[][];
  sam?: Record<string, C2Unit>;
  radar?: Record<string, C2Unit>;
}

// C2 data: direct mapping of node keys to C2Node
export type C2Nodes = Record<string, C2Node>;

export type LandingUnits = Record<string, Record<string, number>>;

export interface LiveStatusData {
  signals: Signal[];
  batteryStatuses: BatteryStatus[];
  c2: C2Nodes;
  landingUnits: LandingUnits;
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
  radiusNm: number;
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

/** What `selectedActions` sends back to `addUnitsMenu.lua`. */
export interface AddUnitsMenuResult {
  actionIds: string[];
}
