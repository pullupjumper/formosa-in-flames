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

export interface MissileSystemUnit {
  name: string;
  missileSystem: string;
  firingUnitState: string;
  resupplyUnitState: string;
  firingUnitReloadTime: number;
  defaultReloadTime: number;
  resupplyUnitReloadTime: number;
  missilesInAmmoVehicles: number;
  missilesInAHA: number;
}

export type MissileSystemData = Record<string, MissileSystemUnit[]>;

export interface C2Unit {
  name: string;
  OODADetection: string;
  OODATargeting: string;
  isOutOfComms: boolean;
  EMCONSetting: string;
  isDestroyed: boolean;
}

export interface C2Node {
  name: string;
  SAM?: Record<string, C2Unit>;
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
  launchers: MissileSystemData;
  c2: C2Data;
  baseWeapons: Base[];
  landingUnits: LandingUnitsData;
}
