/**
 * Deployment-tab domain types shared by the state machine, the geometry utils
 * and the map layer. Types only; the per-area lookup tables live in
 * `constants/deployment.ts`.
 */

import type { BatteryPlacement, MovementPath } from '@/types/generated';
import type { Coordinate } from '@/types/geo';

/** Every tactical area a deployed unit can relocate by clicking it */
export type AreaType = 'ushape' | 'atp' | 'hide' | 'reload' | 'fp';

/** The single-square areas; the U-shape moves the whole layout instead */
export type SquareAreaType = Exclude<AreaType, 'ushape'>;

/** One clickable area of one deployed unit */
export interface RelocatingArea {
  batteryName: string;
  type: AreaType;
  /** Which position of its type; 0 for the single squares, absent for the U-shape */
  index?: number;
}

/** Unit armed from the sidebar, waiting for a map click */
export interface SelectedUnit {
  name: string;
  missileSystemType: string;
}

/** One battery placed on the map, with everything the export needs. */
export interface DeployedBattery extends BatteryPlacement {
  name: string;
  missileSystemType: string;
  /** Each fire point's way back to the reload area; drawn on the map, never sent to Lua */
  reloadReturnPaths: MovementPath[];
  /** Absent on scenario-placed units; the generator then uses AREA_CONFIG. */
  atpRadius?: number;
  /** Where the ATP square sits; set by hand-relocation or scenario placement. */
  atpCenter?: Coordinate;
}
