import type { Coordinate } from '@/types/geo';
import type { MissileDeployment, TacticalAreas } from '@/types/controlPanel';
import type { RelocatingArea, SquareAreaType } from '@/types/deployment';
import type { RandomSource } from '@/utils/random';
import { areAllPointsInPolygon, calculateCentroid } from '@/utils/geo';
import { AREA_CONFIG, AREA_SQUARE_SIZE } from './config';
import { generateDeploymentData } from './deploy';
import { buildMovementPaths } from './paths';
import { buildShelterPlan, resolveGateways } from './shelter';
import type { Gateways } from './shelter';
import { doSquaresOverlap, generateSquareFacing, isSquare } from './squares';

/**
 * The `relocate` verb: move one area of an existing deployment. Moving the
 * boundary regenerates HA/RL/shelters at the new center; moving a square keeps
 * everything else in place. Either way the paths are rebuilt afterwards.
 */

/** Which area to move; the unit is already known from `deployment`. */
export type RelocateTarget = Omit<RelocatingArea, 'unitKey'>;

/** Machine-readable rejection; callers own the user-facing wording. */
export type RelocateFailure =
  | { code: 'ushape-generation-failed' }
  | { code: 'outside-boundary' }
  | { code: 'overlaps-other-area'; other: 'hide' | 'reload' };

export type RelocateResult =
  | { ok: true; data: MissileDeployment }
  | { ok: false; failure: RelocateFailure };

export interface RelocateAreaParams {
  deployment: MissileDeployment;
  target: RelocateTarget;
  position: Coordinate;
  validateTaiwanBoundary: boolean;
  /** Defaults to `Math.random`; pass a seeded source for reproducible output. */
  rng?: RandomSource;
}

interface AreaUpdate {
  tacticalAreas: TacticalAreas;
  /** Only the fields the move actually changes, so a spread cannot blank others */
  extraFields: Partial<MissileDeployment>;
  /** Fresh gateways when the move replanned shelters; null means "look them up" */
  gateways: Gateways | null;
}

type AreaUpdateResult = { ok: true; update: AreaUpdate } | { ok: false; failure: RelocateFailure };

// ============================================================================
// BOUNDARY MOVE
// ============================================================================
/**
 * Moving the boundary moves everything with it, so the layout is regenerated at
 * the new center. AHA and fire points are user-placed and stay where they are.
 */
function buildUShapeUpdate(
  deployment: MissileDeployment,
  position: Coordinate,
  validateTaiwanBoundary: boolean,
  rng: RandomSource
): AreaUpdateResult {
  const regenerated = generateDeploymentData({
    unitname: deployment.unitname,
    category: deployment.missileSystemType,
    center: position,
    angle: deployment.openingAngle,
    validateTaiwanBoundary,
    ahaRadiusOverride: deployment.ahaRadius,
    ahaCenterOverride: deployment.ahaCenter,
    firePointsOverride: deployment.tacticalAreas.firePoints,
    rng,
  });
  if (!regenerated) return { ok: false, failure: { code: 'ushape-generation-failed' } };

  return {
    ok: true,
    update: {
      tacticalAreas: {
        ...deployment.tacticalAreas,
        uShapeVertices: regenerated.tacticalAreas.uShapeVertices,
        hideArea: regenerated.tacticalAreas.hideArea,
        reloadArea: regenerated.tacticalAreas.reloadArea,
        shelterPoints: regenerated.tacticalAreas.shelterPoints,
      },
      extraFields: { center: position },
      gateways: null,
    },
  };
}

// ============================================================================
// SQUARE MOVE
// ============================================================================
/**
 * Hide and reload areas must stay inside the boundary and clear of each other.
 * Returns null when the candidate position is acceptable.
 */
function validateInternalSquare(
  tacticalAreas: TacticalAreas,
  type: 'hide' | 'reload',
  vertices: Coordinate[],
  position: Coordinate
): RelocateFailure | null {
  const boundary = tacticalAreas.uShapeVertices;
  if (boundary && boundary.length >= 3 && !areAllPointsInPolygon(vertices, boundary)) {
    return { code: 'outside-boundary' };
  }

  const other = type === 'hide' ? tacticalAreas.reloadArea : tacticalAreas.hideArea;
  if (isSquare(other)) {
    const overlaps = doSquaresOverlap(
      position,
      calculateCentroid(other),
      AREA_SQUARE_SIZE[type],
      AREA_CONFIG.internalSquares.marginBetweenSquares
    );
    if (overlaps) {
      return { code: 'overlaps-other-area', other: type === 'hide' ? 'reload' : 'hide' };
    }
  }

  return null;
}

/** Move one square, leaving every other tactical area untouched */
function buildSquareUpdate(
  deployment: MissileDeployment,
  type: SquareAreaType,
  fpIndex: number,
  position: Coordinate,
  rng: RandomSource
): AreaUpdateResult {
  const { tacticalAreas } = deployment;
  const vertices = generateSquareFacing(position, AREA_SQUARE_SIZE[type], deployment.center);
  const isInternal = type === 'hide' || type === 'reload';

  if (isInternal) {
    const failure = validateInternalSquare(tacticalAreas, type, vertices, position);
    if (failure) return { ok: false, failure };
  }

  const next = { ...tacticalAreas };
  const extraFields: Partial<MissileDeployment> = {};

  switch (type) {
    case 'aha':
      next.ammoArea = vertices;
      extraFields.ahaCenter = position;
      break;
    case 'hide':
      next.hideArea = vertices;
      break;
    case 'reload':
      next.reloadArea = vertices;
      break;
    case 'fp':
      if (tacticalAreas.firePoints) {
        const firePoints = [...tacticalAreas.firePoints];
        firePoints[fpIndex] = vertices;
        next.firePoints = firePoints;
      }
      break;
  }

  // Shelters are placed relative to HA/RL, so they have to be replanned (with
  // gateway validation) whenever either of those two moves.
  let gateways: Gateways | null = null;
  if (isInternal) {
    const plan = buildShelterPlan(
      deployment.center,
      deployment.openingAngle,
      next.hideArea,
      next.reloadArea,
      rng
    );
    next.shelterPoints = plan.shelterPoints;
    gateways = plan.gateways;
  }

  return { ok: true, update: { tacticalAreas: next, extraFields, gateways } };
}

// ============================================================================
// VERB
// ============================================================================
/**
 * Move one tactical area of an existing deployment to a new position and
 * recompute the movement paths. Returns a failure code instead of throwing when
 * the target position breaks a placement rule.
 */
export function relocateArea({
  deployment,
  target,
  position,
  validateTaiwanBoundary,
  rng = Math.random,
}: RelocateAreaParams): RelocateResult {
  const result =
    target.type === 'ushape'
      ? buildUShapeUpdate(deployment, position, validateTaiwanBoundary, rng)
      : buildSquareUpdate(deployment, target.type, target.fpIndex ?? 0, position, rng);

  if (!result.ok) return result;

  const { tacticalAreas, extraFields } = result.update;
  const center = extraFields.center ?? deployment.center;
  const gateways =
    result.update.gateways ??
    resolveGateways(
      center,
      deployment.openingAngle,
      tacticalAreas.hideArea,
      tacticalAreas.reloadArea,
      tacticalAreas.shelterPoints
    );

  return {
    ok: true,
    data: {
      ...deployment,
      ...extraFields,
      tacticalAreas,
      paths: buildMovementPaths(tacticalAreas, gateways),
    },
  };
}
