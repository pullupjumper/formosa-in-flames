import type { RelocatingArea, AreaType } from '@/components/Map';
import type { PreviewOffsets, RelocateFailure } from '@/utils/missileDeployment';

/**
 * The Deployment tab's map click has exactly one owner at a time. Modelling
 * that as a discriminated union makes the exclusivity a type-level fact rather
 * than something every handler has to maintain by clearing four setters.
 */

// ============================================================================
// TYPES
// ============================================================================
export interface SelectedUnit {
  key: string;
  name: string;
  category: string;
}

export interface LatLng {
  lat: number;
  lng: number;
}

export type DeploymentMode =
  | { kind: 'idle' }
  /** A sidebar unit is armed; `offsets` drives the hover preview */
  | { kind: 'deploy'; unit: SelectedUnit; offsets: Record<number, PreviewOffsets> }
  | { kind: 'relocateArea'; area: RelocatingArea }
  | { kind: 'rotate'; unitKey: string; center: LatLng; previewAngle: number | null }
  /** Deploy and relocate share the same commit path, so they are one mode */
  | { kind: 'placeJammer'; index: number; isRelocate: boolean };

export interface DeploymentModeState {
  mode: DeploymentMode;
  /** Cursor position feeding the hover preview; every transition clears it */
  mousePosition: LatLng | null;
}

export type DeploymentAction =
  | { type: 'reset' }
  | { type: 'selectUnit'; unit: SelectedUnit; offsets: Record<number, PreviewOffsets> }
  | { type: 'relocateArea'; area: RelocatingArea }
  | { type: 'rotate'; unitKey: string; center: LatLng }
  | { type: 'placeJammer'; index: number; isRelocate: boolean }
  /** `rotationAngle` is ignored unless the rotate mode is active */
  | { type: 'hover'; lat: number; lng: number; rotationAngle?: number };

// ============================================================================
// REDUCER
// ============================================================================
export const IDLE_STATE: DeploymentModeState = { mode: { kind: 'idle' }, mousePosition: null };

export function deploymentModeReducer(
  state: DeploymentModeState,
  action: DeploymentAction
): DeploymentModeState {
  switch (action.type) {
    case 'reset':
      return IDLE_STATE;

    case 'selectUnit':
      return {
        mode: { kind: 'deploy', unit: action.unit, offsets: action.offsets },
        mousePosition: null,
      };

    case 'relocateArea':
      return { mode: { kind: 'relocateArea', area: action.area }, mousePosition: null };

    case 'rotate':
      return {
        mode: {
          kind: 'rotate',
          unitKey: action.unitKey,
          center: action.center,
          previewAngle: null,
        },
        mousePosition: null,
      };

    case 'placeJammer':
      return {
        mode: { kind: 'placeJammer', index: action.index, isRelocate: action.isRelocate },
        mousePosition: null,
      };

    case 'hover': {
      const mousePosition = { lat: action.lat, lng: action.lng };
      if (state.mode.kind !== 'rotate') return { ...state, mousePosition };
      return {
        mode: { ...state.mode, previewAngle: action.rotationAngle ?? null },
        mousePosition,
      };
    }
  }
}

// ============================================================================
// PREDICATES
// ============================================================================
/** Missile-side modes, i.e. everything a jammer click has to yield to */
export function isMissileMode(mode: DeploymentMode): boolean {
  return mode.kind === 'deploy' || mode.kind === 'relocateArea' || mode.kind === 'rotate';
}

/** True while any mode owns the next map click */
export function isPlacementMode(mode: DeploymentMode): boolean {
  return mode.kind !== 'idle';
}

export function isSameArea(a: RelocatingArea, b: RelocatingArea): boolean {
  return a.unitKey === b.unitKey && a.type === b.type && a.fpIndex === b.fpIndex;
}

// ============================================================================
// STATUS VOCABULARY
// ============================================================================
export const DEFAULT_STATUS = 'Select a unit from the sidebar, then click on the map to deploy';

export const OUT_OF_BOUNDS_JAMMER = 'Warning: EW units can only be deployed on Taiwan mainland';
export const OUT_OF_BOUNDS_MISSILE =
  'Warning: Missile systems can only be deployed on Taiwan mainland';

export const AREA_LABEL: Record<AreaType, string> = {
  ushape: 'U-Shape',
  aha: 'AHA',
  hide: 'Hide Area',
  reload: 'Reload Area',
  fp: 'Fire Point',
};

/** Fire points are numbered in the UI, every other area has a fixed label */
export function formatAreaLabel(area: RelocatingArea): string {
  if (area.type !== 'fp') return AREA_LABEL[area.type];
  return `${AREA_LABEL.fp} ${(area.fpIndex ?? 0) + 1}`;
}

/** Turn a rejection from `relocateArea` into the status line */
export function describeRelocateFailure(failure: RelocateFailure): string {
  switch (failure.code) {
    case 'ushape-generation-failed':
      return 'Warning: Failed to relocate U-Shape';
    case 'outside-boundary':
      return 'Warning: Must be within the boundary area';
    case 'overlaps-other-area':
      return `Warning: Overlaps with ${AREA_LABEL[failure.other]}, choose another location`;
  }
}

/** Status line shown when ESC drops the given mode */
export function cancellationMessage(mode: DeploymentMode): string {
  switch (mode.kind) {
    case 'rotate':
      return 'Rotation cancelled';
    case 'relocateArea':
      return 'Relocation cancelled';
    case 'placeJammer':
      return mode.isRelocate ? 'Relocation cancelled' : 'Selection cancelled';
    default:
      return 'Selection cancelled';
  }
}
