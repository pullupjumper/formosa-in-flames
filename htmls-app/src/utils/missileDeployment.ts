import type { Coordinate, CoordinateOffset } from '@/types/geo';
import type { MissileDeployment, MovementPaths, TacticalAreas } from '@/types/setupMenu';
import { areAllPointsInPolygon, areAllPointsInTaiwan, calculateCentroid } from '@/utils/geo';
import {
  generateUShapeVertices,
  calculateMovementPaths,
  generateShelterPoints,
  selectFpGateway,
  selectShrlGateway,
  calculateBearing,
  generateSquareVertices,
  doSquaresOverlap,
} from '@/utils/tacticalAreaGenerator';
import type { RandomSource } from '@/utils/random';

/**
 * Domain layer over `tacticalAreaGenerator`: applies the project's AREA_CONFIG
 * and retry policies to turn a map click into a complete missile deployment.
 * Pure functions only — no React, no component state.
 */

// ============================================================================
// AREA CONFIG
// ============================================================================
/** All distances are nautical miles (tacticalAreaGenerator works in NM) */
export const AREA_CONFIG = {
  width: 1.5,
  height: 1.5,
  internalSquares: {
    size: 0.2,
    marginToWall: 0.1,
    marginBetweenSquares: 0.5,
  },
  firePoints: {
    radius: 3,
    squareSize: 0.3,
    count: 2,
    angleRange: 90,
    margin: 0.2,
  },
  ahaPoint: {
    radius: 7,
    squareSize: 0.3,
  },
  shelter: {
    count: 2,
    marginToWall: 0.1,
    marginToAreas: 0.1,
    marginBetweenPoints: 0.2,
  },
};

export const MOVEMENT_PATH_AVOIDANCE_MARGIN = 0.05;

/** Shelter placement is randomized; retry until both gateways resolve */
const SHELTER_PLAN_MAX_ATTEMPTS = 50;

/** Outer retry that regenerates the whole U-shape when shelters cannot converge */
const DEPLOYMENT_MAX_ATTEMPTS = 50;

/** Fixed reference point used to precompute angle-specific preview offsets */
export const REF_CENTER: Coordinate = { latitude: 23.8, longitude: 121.0 };

export type RelocatableSquareType = 'aha' | 'hide' | 'reload' | 'fp';

export const AREA_SQUARE_SIZE: Record<RelocatableSquareType, number> = {
  aha: AREA_CONFIG.ahaPoint.squareSize,
  hide: AREA_CONFIG.internalSquares.size,
  reload: AREA_CONFIG.internalSquares.size,
  fp: AREA_CONFIG.firePoints.squareSize,
};

// ============================================================================
// TYPES
// ============================================================================
export interface DeploymentContext {
  center: Coordinate;
  openingAngle: number;
}

export interface ShelterPlan {
  shelterPoints: Coordinate[];
  fpGateway: Coordinate | null;
  shrlGateway: Coordinate | null;
}

export interface PreviewOffsets {
  uShapeVertices: CoordinateOffset[];
  ammoArea: CoordinateOffset[];
  hideArea: CoordinateOffset[];
  reloadArea: CoordinateOffset[];
  firePoints: CoordinateOffset[][];
}

export interface GenerateDeploymentParams {
  unitName: string;
  category: string;
  center: Coordinate;
  angle: number;
  validateTaiwanBoundary: boolean;
  ahaRadiusOverride?: number;
  ahaCenterOverride?: Coordinate;
  /** Defaults to `Math.random`; pass a seeded source for reproducible output. */
  rng?: RandomSource;
}

export interface RotationPreview {
  uShapeVertices: Coordinate[];
  ammoArea: Coordinate[];
  hideArea: Coordinate[];
  reloadArea: Coordinate[];
}

/** The U-shape moves the whole deployment; the other types move one square. */
export type RelocateTargetType = 'ushape' | RelocatableSquareType;

/**
 * Structural subset of the map layer's `RelocatingArea`, so this module stays
 * free of component imports.
 */
export interface RelocateTarget {
  type: RelocateTargetType;
  fpIndex?: number;
}

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

// ============================================================================
// HELPERS
// ============================================================================
export function createEmptyMovementPaths(): MovementPaths {
  return {
    FP: [],
    HA: { waypoints: [] },
    RL: [],
    AHA: { waypoints: [] },
    SHRL: { waypoints: [] },
  };
}

export function isValidAngle(angle: number): boolean {
  return Number.isFinite(angle) && angle >= 0 && angle <= 359;
}

function isSquare(area: Coordinate[] | undefined): area is Coordinate[] {
  return !!area && area.length === 4;
}

// ============================================================================
// SHELTER PLANNING
// ============================================================================
function buildShelterPoints(
  center: Coordinate,
  openingAngle: number,
  hideArea: Coordinate[] | undefined,
  reloadArea: Coordinate[] | undefined,
  rng: RandomSource
): Coordinate[] {
  const avoidAreas: Coordinate[][] = [];
  if (isSquare(hideArea)) avoidAreas.push(hideArea);
  if (isSquare(reloadArea)) avoidAreas.push(reloadArea);

  return generateShelterPoints({
    center,
    areaWidth: AREA_CONFIG.width,
    areaHeight: AREA_CONFIG.height,
    openingAngle,
    avoidAreas,
    count: AREA_CONFIG.shelter.count,
    marginToWall: AREA_CONFIG.shelter.marginToWall,
    marginToAreas: AREA_CONFIG.shelter.marginToAreas,
    marginBetweenPoints: AREA_CONFIG.shelter.marginBetweenPoints,
    rng,
  });
}

/**
 * Generate shelter points that share BOTH the FP and SHRL gateways. Retries
 * shelter placement until both gateways succeed or we hit the attempt cap.
 */
export function buildShelterPlan(
  center: Coordinate,
  openingAngle: number,
  hideArea?: Coordinate[],
  reloadArea?: Coordinate[],
  rng: RandomSource = Math.random
): ShelterPlan {
  const hasValidAreas = isSquare(hideArea) && isSquare(reloadArea);

  let lastShelters: Coordinate[] = [];

  for (let attempt = 0; attempt < SHELTER_PLAN_MAX_ATTEMPTS; attempt++) {
    const shelters = buildShelterPoints(center, openingAngle, hideArea, reloadArea, rng);
    lastShelters = shelters;
    if (!hasValidAreas || shelters.length === 0) continue;

    const fpGateway = selectFpGateway({
      uShapeCenter: center,
      openingAngle,
      areaWidth: AREA_CONFIG.width,
      areaHeight: AREA_CONFIG.height,
      hideArea,
      reloadArea,
      shelterPoints: shelters,
      avoidanceMargin: MOVEMENT_PATH_AVOIDANCE_MARGIN,
    });
    if (!fpGateway) continue;

    const shrlGateway = selectShrlGateway({
      hideArea,
      reloadArea,
      shelterPoints: shelters,
      avoidanceMargin: MOVEMENT_PATH_AVOIDANCE_MARGIN,
    });
    if (!shrlGateway) continue;

    return { shelterPoints: shelters, fpGateway, shrlGateway };
  }

  return { shelterPoints: lastShelters, fpGateway: null, shrlGateway: null };
}

// ============================================================================
// MOVEMENT PATHS
// ============================================================================
function resolveGateways(
  tacticalAreas: TacticalAreas,
  context: DeploymentContext
): { fpGateway: Coordinate | null; shrlGateway: Coordinate | null } {
  const { hideArea, reloadArea, shelterPoints } = tacticalAreas;
  if (!isSquare(hideArea) || !isSquare(reloadArea) || !shelterPoints?.length) {
    return { fpGateway: null, shrlGateway: null };
  }

  const fpGateway = selectFpGateway({
    uShapeCenter: context.center,
    openingAngle: context.openingAngle,
    areaWidth: AREA_CONFIG.width,
    areaHeight: AREA_CONFIG.height,
    hideArea,
    reloadArea,
    shelterPoints,
    avoidanceMargin: MOVEMENT_PATH_AVOIDANCE_MARGIN,
  });

  const shrlGateway = selectShrlGateway({
    hideArea,
    reloadArea,
    shelterPoints,
    avoidanceMargin: MOVEMENT_PATH_AVOIDANCE_MARGIN,
  });

  return { fpGateway, shrlGateway };
}

export function buildMovementPaths(
  tacticalAreas: TacticalAreas,
  context: DeploymentContext
): MovementPaths {
  if (!tacticalAreas.ammoArea || !tacticalAreas.hideArea || !tacticalAreas.reloadArea) {
    return createEmptyMovementPaths();
  }

  const { fpGateway, shrlGateway } = resolveGateways(tacticalAreas, context);

  return calculateMovementPaths({
    ammoArea: tacticalAreas.ammoArea,
    hideArea: tacticalAreas.hideArea,
    reloadArea: tacticalAreas.reloadArea,
    firePoints: tacticalAreas.firePoints,
    avoidanceMargin: MOVEMENT_PATH_AVOIDANCE_MARGIN,
    fpGateway: fpGateway ?? undefined,
    shrlGateway: shrlGateway ?? undefined,
  });
}

// ============================================================================
// DEPLOYMENT GENERATION
// ============================================================================
/** Build the AreaConfig passed to generateUShapeVertices, honouring AHA overrides */
function buildAreaConfig(
  center: Coordinate,
  openingAngle: number,
  ahaRadiusOverride?: number,
  ahaCenterOverride?: Coordinate
) {
  return {
    center,
    openingAngle,
    ...AREA_CONFIG,
    ahaPoint: {
      ...AREA_CONFIG.ahaPoint,
      radius: ahaRadiusOverride ?? AREA_CONFIG.ahaPoint.radius,
      ...(ahaCenterOverride ? { center: ahaCenterOverride } : {}),
    },
  };
}

/**
 * Produce a complete deployment (tactical areas + movement paths) for one unit.
 * Returns null when the location fails the Taiwan boundary check or when no
 * layout with both gateways could be found.
 */
export function generateDeploymentData({
  unitName,
  category,
  center,
  angle,
  validateTaiwanBoundary,
  ahaRadiusOverride,
  ahaCenterOverride,
  rng = Math.random,
}: GenerateDeploymentParams): MissileDeployment | null {
  try {
    const areaConfig = buildAreaConfig(center, angle, ahaRadiusOverride, ahaCenterOverride);

    // Outer retry: if buildShelterPlan can't converge on both gateways with
    // this HA/RL layout, regenerate the U-shape (which re-randomizes HA/RL/FP)
    // and try again. Shelter inner retry is bounded separately.
    for (let attempt = 0; attempt < DEPLOYMENT_MAX_ATTEMPTS; attempt++) {
      const result = generateUShapeVertices(areaConfig, rng);

      // Taiwan boundary is deterministic w.r.t. center/angle; no point retrying.
      if (validateTaiwanBoundary && !areAllPointsInTaiwan(result.uShapeVertices)) {
        return null;
      }

      const plan = buildShelterPlan(center, angle, result.hideArea, result.reloadArea, rng);
      if (!plan.fpGateway || !plan.shrlGateway) {
        continue;
      }

      const tacticalAreas: TacticalAreas = {
        uShapeVertices: result.uShapeVertices,
        ammoArea: result.ammoArea,
        hideArea: result.hideArea,
        reloadArea: result.reloadArea,
        firePoints: result.firePoints,
        shelterPoints: plan.shelterPoints,
      };

      return {
        unitName,
        category,
        center,
        openingAngle: angle,
        ahaRadius: ahaRadiusOverride ?? AREA_CONFIG.ahaPoint.radius,
        ...(ahaCenterOverride ? { ahaCenter: ahaCenterOverride } : {}),
        tacticalAreas,
        paths: buildMovementPaths(tacticalAreas, { center, openingAngle: angle }),
      };
    }

    console.error(
      `generateDeploymentData: failed to find both gateways after ${DEPLOYMENT_MAX_ATTEMPTS} outer retries`
    );
    return null;
  } catch (error) {
    console.error('Error generating tactical areas:', error);
    return null;
  }
}

// ============================================================================
// AREA RELOCATION
// ============================================================================
interface AreaUpdate {
  tacticalAreas: TacticalAreas;
  /** Only the fields the move actually changes, so a spread cannot blank others */
  extraFields: Partial<MissileDeployment>;
}

type AreaUpdateResult = { ok: true; update: AreaUpdate } | { ok: false; failure: RelocateFailure };

/**
 * Moving the U-shape moves everything with it, so the layout is regenerated at
 * the new center. AHA and fire points are user-placed and stay where they are.
 */
function buildUShapeUpdate(
  deployment: MissileDeployment,
  position: Coordinate,
  validateTaiwanBoundary: boolean,
  rng: RandomSource
): AreaUpdateResult {
  const regenerated = generateDeploymentData({
    unitName: deployment.unitName,
    category: deployment.category,
    center: position,
    angle: deployment.openingAngle,
    validateTaiwanBoundary,
    ahaRadiusOverride: deployment.ahaRadius,
    ahaCenterOverride: deployment.ahaCenter,
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
    },
  };
}

/**
 * Hide and reload areas must stay inside the U-shape and clear of each other.
 * Returns null when the candidate position is acceptable.
 */
function validateInternalSquare(
  tacticalAreas: TacticalAreas,
  type: 'hide' | 'reload',
  vertices: Coordinate[],
  position: Coordinate,
  squareSize: number
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
      squareSize,
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
  type: RelocatableSquareType,
  fpIndex: number,
  position: Coordinate,
  rng: RandomSource
): AreaUpdateResult {
  const { tacticalAreas } = deployment;
  const bearingToCenter = calculateBearing(position, deployment.center);
  const squareSize = AREA_SQUARE_SIZE[type];
  const vertices = generateSquareVertices(position, squareSize, bearingToCenter);
  const isInternal = type === 'hide' || type === 'reload';

  if (isInternal) {
    const failure = validateInternalSquare(tacticalAreas, type, vertices, position, squareSize);
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
  if (isInternal) {
    next.shelterPoints = buildShelterPlan(
      deployment.center,
      deployment.openingAngle,
      next.hideArea,
      next.reloadArea,
      rng
    ).shelterPoints;
  }

  return { ok: true, update: { tacticalAreas: next, extraFields } };
}

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
  const paths = buildMovementPaths(tacticalAreas, {
    center: extraFields.center ?? deployment.center,
    openingAngle: deployment.openingAngle,
  });

  return { ok: true, data: { ...deployment, ...extraFields, tacticalAreas, paths } };
}

// ============================================================================
// PREVIEWS
// ============================================================================
function resultToOffsets(
  result: ReturnType<typeof generateUShapeVertices>,
  reference: Coordinate
): PreviewOffsets {
  const toOffset = (coordinate: Coordinate): CoordinateOffset => ({
    latitudeDelta: coordinate.latitude - reference.latitude,
    longitudeDelta: coordinate.longitude - reference.longitude,
  });
  return {
    uShapeVertices: result.uShapeVertices.map(toOffset),
    ammoArea: (result.ammoArea ?? []).map(toOffset),
    hideArea: (result.hideArea ?? []).map(toOffset),
    reloadArea: (result.reloadArea ?? []).map(toOffset),
    firePoints: (result.firePoints ?? []).map((firePoint) => firePoint.map(toOffset)),
  };
}

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
    const result = generateUShapeVertices(
      buildAreaConfig(REF_CENTER, angle, ahaRadiusOverride),
      rng
    );
    return resultToOffsets(result, REF_CENTER);
  } catch (error) {
    console.error('Failed to generate offsets for angle:', angle, error);
    return null;
  }
}

/** Regenerate a deployed unit's areas at a candidate opening angle */
export function generateRotationPreview(
  center: Coordinate,
  angle: number,
  ahaRadius?: number,
  ahaCenter?: Coordinate,
  rng: RandomSource = Math.random
): RotationPreview | null {
  try {
    const result = generateUShapeVertices(
      buildAreaConfig(center, angle, ahaRadius, ahaCenter),
      rng
    );
    return {
      uShapeVertices: result.uShapeVertices,
      ammoArea: result.ammoArea ?? [],
      hideArea: result.hideArea ?? [],
      reloadArea: result.reloadArea ?? [],
    };
  } catch {
    return null;
  }
}
