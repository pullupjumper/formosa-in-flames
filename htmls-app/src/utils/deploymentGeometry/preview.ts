import type { Coordinate, CoordinateOffset } from '@/types/geo';
import type { MissileDeployment } from '@/types/controlPanel';
import type { RandomSource } from '@/utils/random';
import { areAllPointsInTaiwan, translateCoordinate } from '@/utils/geo';
import { AREA_SQUARE_SIZE, REF_CENTER } from './config';
import { generateLayout } from './layout';
import type { Layout } from './layout';
import type { RelocateTarget } from './relocate';
import { generateSquareFacing } from './squares';

/**
 * The `preview` verbs: what the map draws while a mode is pending. Boundary
 * check only; shelters and gateways are resolved on commit.
 */

/** A layout as degree deltas from REF_CENTER, so hover can translate it per frame */
export interface PreviewOffsets {
  uShapeVertices: CoordinateOffset[];
  ammoArea: CoordinateOffset[];
  hideArea: CoordinateOffset[];
  reloadArea: CoordinateOffset[];
  firePoints: CoordinateOffset[][];
}

export interface DeploymentPreview extends Layout {
  isValid: boolean;
}

function isLayoutInTaiwan(layout: Layout): boolean {
  return (
    areAllPointsInTaiwan(layout.uShapeVertices) &&
    areAllPointsInTaiwan(layout.ammoArea) &&
    layout.firePoints.every(areAllPointsInTaiwan)
  );
}

// ============================================================================
// NEW DEPLOYMENT
// ============================================================================
/**
 * Precompute a layout at REF_CENTER as degree deltas, so the hover preview can
 * follow the cursor by translation instead of regenerating geometry per frame.
 */
export function generateOffsetsForAngle(
  angle: number,
  ahaRadiusOverride?: number,
  rng: RandomSource = Math.random
): PreviewOffsets | null {
  try {
    const layout = generateLayout(REF_CENTER, angle, { ahaRadius: ahaRadiusOverride }, rng);
    const toOffset = (coordinate: Coordinate): CoordinateOffset => ({
      latitudeDelta: coordinate.latitude - REF_CENTER.latitude,
      longitudeDelta: coordinate.longitude - REF_CENTER.longitude,
    });
    return {
      uShapeVertices: layout.uShapeVertices.map(toOffset),
      ammoArea: layout.ammoArea.map(toOffset),
      hideArea: layout.hideArea.map(toOffset),
      reloadArea: layout.reloadArea.map(toOffset),
      firePoints: layout.firePoints.map((firePoint) => firePoint.map(toOffset)),
    };
  } catch (error) {
    console.error('Failed to generate offsets for angle:', angle, error);
    return null;
  }
}

/** New deployment: translate a precomputed offset layout to the cursor */
export function previewDeployment(
  offsets: PreviewOffsets,
  cursor: Coordinate,
  validateTaiwanBoundary: boolean
): DeploymentPreview {
  const translate = (offset: CoordinateOffset): Coordinate => translateCoordinate(cursor, offset);

  const layout: Layout = {
    uShapeVertices: offsets.uShapeVertices.map(translate),
    ammoArea: offsets.ammoArea.map(translate),
    hideArea: offsets.hideArea.map(translate),
    reloadArea: offsets.reloadArea.map(translate),
    firePoints: offsets.firePoints.map((firePoint) => firePoint.map(translate)),
  };

  return { ...layout, isValid: !validateTaiwanBoundary || isLayoutInTaiwan(layout) };
}

// ============================================================================
// RELOCATION
// ============================================================================
/** Area relocation: the boundary translates as a whole, a single square re-squares at the cursor */
export function previewRelocation(
  deployment: MissileDeployment,
  target: RelocateTarget,
  cursor: Coordinate
): Coordinate[] {
  if (target.type === 'ushape') {
    const offset: CoordinateOffset = {
      latitudeDelta: cursor.latitude - deployment.center.latitude,
      longitudeDelta: cursor.longitude - deployment.center.longitude,
    };
    return deployment.tacticalAreas.uShapeVertices.map((vertex) =>
      translateCoordinate(vertex, offset)
    );
  }

  return generateSquareFacing(cursor, AREA_SQUARE_SIZE[target.type], deployment.center);
}

// ============================================================================
// ROTATION
// ============================================================================
/** Rotation: regenerate the layout at the swept angle, fire points kept */
export function previewRotation(
  deployment: MissileDeployment,
  angle: number,
  validateTaiwanBoundary: boolean,
  rng: RandomSource = Math.random
): DeploymentPreview | null {
  let layout: Layout;
  try {
    layout = generateLayout(
      deployment.center,
      angle,
      { ahaRadius: deployment.ahaRadius, ahaCenter: deployment.ahaCenter },
      rng
    );
  } catch {
    return null;
  }

  const isValid =
    !validateTaiwanBoundary ||
    (areAllPointsInTaiwan(layout.uShapeVertices) && areAllPointsInTaiwan(layout.ammoArea));

  return { ...layout, firePoints: deployment.tacticalAreas.firePoints ?? [], isValid };
}
