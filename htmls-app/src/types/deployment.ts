/**
 * Deployment-tab domain types shared by the state machine, the geometry utils
 * and the map layer. Types only; the per-area lookup tables live in
 * `constants/deployment.ts`.
 */

import type { Coordinate, MovementPath } from '@/types/geo';

/** Every tactical area a deployed unit can relocate by clicking it */
export type AreaType = 'ushape' | 'aha' | 'hide' | 'reload' | 'fp';

/** The single-square areas; the U-shape moves the whole layout instead */
export type SquareAreaType = Exclude<AreaType, 'ushape'>;

/** One clickable area of one deployed unit */
export interface RelocatingArea {
  unitKey: string;
  type: AreaType;
  /** Which fire point, only meaningful when `type` is `'fp'` */
  fpIndex?: number;
}

/** Unit armed from the sidebar, waiting for a map click */
export interface SelectedUnit {
  key: string;
  name: string;
  missileSystemType: string;
}

export interface TacticalAreas {
  uShapeVertices: Coordinate[];
  ammoArea?: Coordinate[];
  hideArea?: Coordinate[];
  reloadArea?: Coordinate[];
  firePoints?: Coordinate[][];
  shelterPoints?: Coordinate[];
}

/** Keys mirror the Lua `SBJ__MovementPathSet` shape and are exported verbatim. */
export interface MovementPaths {
  FP: MovementPath[];
  HA: MovementPath;
  RL: MovementPath[];
  AHA: MovementPath;
  SHRL: MovementPath;
}

/** One missile unit placed on the map, with everything the export needs. */
export interface MissileDeployment {
  unitname: string;
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
