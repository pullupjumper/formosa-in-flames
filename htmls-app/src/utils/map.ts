import type { Coordinate } from '@/types/geo';
import { CONFIG } from '@/constants/controlPanel';

/**
 * Suggest which way a U-shape should open at a position: toward the coast the
 * unit is closest to, using a rough north-south ridge line as the divider.
 */
export function resolveOpeningAngle(point: Coordinate): number {
  const { latitude, longitude } = point;
  let ridgeLongitude: number;
  if (latitude >= 25) ridgeLongitude = 121.5;
  else if (latitude >= 24) ridgeLongitude = 121.0 + (latitude - 24) * 0.5;
  else if (latitude >= 23) ridgeLongitude = 120.8 + (latitude - 23) * 0.2;
  else ridgeLongitude = 120.8;

  return longitude < ridgeLongitude ? 90 : 270;
}

/** Weapon system display name for a missile system type key. */
export function getWeaponSystemName(missileSystemType: string): string {
  return CONFIG.WEAPON_NAMES[missileSystemType] || missileSystemType.toUpperCase();
}

/**
 * Build the key identifying a firing unit inside a missile system type.
 * Deployment maps are keyed by this string throughout the control panel.
 */
export function buildUnitKey(missileSystemType: string, unitname: string): string {
  return `${missileSystemType}_${unitname}`;
}

/**
 * Whether a click on a tactical area should do anything: nothing while another
 * area is armed for relocation, everything when idle.
 */
export interface CanInteractAreaParams {
  hasHandler: boolean;
  isAnyRelocating: boolean;
  isThisRelocating: boolean;
}

export function canInteractArea({
  hasHandler,
  isAnyRelocating,
  isThisRelocating,
}: CanInteractAreaParams): boolean {
  if (!hasHandler) return false;
  if (!isAnyRelocating) return true;
  return isThisRelocating;
}
