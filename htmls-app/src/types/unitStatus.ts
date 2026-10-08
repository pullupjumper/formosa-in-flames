import type { Coordinate } from './geo';
// Unit Status Dashboard Types

export interface SignalData {
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
  missilesInAHA: number;
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
export type C2Data = Record<string, C2Node>;

export interface BaseWeapon {
  name: string;
  currWpn: number;
}

export interface Base {
  name: string;
  wpns: BaseWeapon[];
}

export type LandingUnitsData = Record<string, Record<string, number>>;

export interface UnitStatusData {
  signals: SignalData[];
  batteryStatuses: BatteryStatus[];
  c2: C2Data;
  baseWeapons: Base[];
  landingUnits: LandingUnitsData;
}
