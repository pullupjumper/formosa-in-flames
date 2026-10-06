/**
 * Deployment-tab domain types shared by the state machine, the geometry utils
 * and the map layer. Types only; the per-area lookup tables live in
 * `constants/deployment.ts`.
 */

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
