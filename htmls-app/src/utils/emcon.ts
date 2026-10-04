/**
 * Export side of the SAM weapons-control choice, written to `emconData`.
 * Each entry names a live SAM unit by GUID, so the host can apply it without
 * guessing which platform a menu id stood for.
 */
export interface SamDoctrineEntry {
  guid: string;
  name: string;
  weaponFree: boolean;
}

export interface EmconResult {
  sams: SamDoctrineEntry[];
}

/** Units that were never switched simply carry the status they already have. */
export function toEmconResult(sams: SamDoctrineEntry[]): EmconResult {
  return { sams };
}
