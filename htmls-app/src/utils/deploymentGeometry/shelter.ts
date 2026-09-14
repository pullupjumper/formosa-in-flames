import type { Coordinate } from '@/types/geo';
import type { RandomSource } from '@/utils/random';
import { calculateDistance, getPointFromBearing } from '@/utils/geo';
import { AREA_CONFIG, MOVEMENT_PATH_AVOIDANCE_MARGIN, SHELTER_PLAN_MAX_ATTEMPTS } from './config';
import {
  calculateSquareCenter,
  doesPathIntersectSquare,
  generateRandomPointInBox,
  getSquareHalfDiagonal,
  isSquare,
} from './squares';

/**
 * Shelters are random points inside the boundary that every path starts from.
 * They only count when two shared gateways exist: one on the back side for the
 * FP runs and one beside RL for the reload runs. Placement and gateway
 * selection are one operation here so the gateways are computed exactly once.
 */

export interface Gateways {
  fpGateway: Coordinate;
  shrlGateway: Coordinate;
}

export interface ShelterPlan {
  shelterPoints: Coordinate[];
  gateways: Gateways | null;
}

// ============================================================================
// SHELTER POINTS
// ============================================================================
/** Random shelters inside the boundary, clear of HA/RL and of each other. */
export function generateShelterPoints(
  center: Coordinate,
  openingAngle: number,
  avoidAreas: Coordinate[][],
  rng: RandomSource
): Coordinate[] {
  const { count, marginToWall, marginToAreas, marginBetweenPoints } = AREA_CONFIG.shelter;
  const maxAttemptsPerPoint = 200;

  const maxOffsetX = AREA_CONFIG.width / 2 - marginToWall;
  const maxOffsetY = AREA_CONFIG.height / 2 - marginToWall;
  if (maxOffsetX <= 0 || maxOffsetY <= 0 || count <= 0) {
    return [];
  }

  const exclusions = avoidAreas.filter(isSquare).map((area) => ({
    center: calculateSquareCenter(area),
    radius: getSquareHalfDiagonal(area) + marginToAreas,
  }));

  const points: Coordinate[] = [];

  for (let i = 0; i < count; i++) {
    let isPlaced = false;

    for (let attempt = 0; attempt < maxAttemptsPerPoint && !isPlaced; attempt++) {
      const candidate = generateRandomPointInBox(center, maxOffsetX, maxOffsetY, openingAngle, rng);

      const conflictsWithAreas = exclusions.some(
        (exclusion) => calculateDistance(candidate, exclusion.center) < exclusion.radius
      );
      if (conflictsWithAreas) continue;

      const conflictsWithShelters = points.some(
        (existing) => calculateDistance(candidate, existing) < marginBetweenPoints
      );
      if (conflictsWithShelters) continue;

      points.push(candidate);
      isPlaced = true;
    }

    if (!isPlaced) {
      console.error(
        `Failed to place shelter point ${i + 1}/${count} after ${maxAttemptsPerPoint} attempts`
      );
    }
  }

  return points;
}

// ============================================================================
// FP GATEWAY
// ============================================================================
const FP_BACK_OFFSET_RATIOS = [0.95, 1.05, 0.8];
const FP_LATERAL_OFFSET_RATIOS = [0, -0.4, 0.4, -0.6, 0.6];

/**
 * Pick a shared FP-path origin on the back side of the boundary such that every
 * shelter has line-of-sight to it without crossing HA or RL.
 */
export function selectFpGateway(
  center: Coordinate,
  openingAngle: number,
  hideArea: Coordinate[],
  reloadArea: Coordinate[],
  shelterPoints: Coordinate[]
): Coordinate | null {
  if (shelterPoints.length === 0) return null;

  const halfHeight = AREA_CONFIG.height / 2;
  const halfWidth = AREA_CONFIG.width / 2;
  const backBearing = (openingAngle + 180) % 360;
  const rightBearing = (openingAngle + 90) % 360;
  const margin = MOVEMENT_PATH_AVOIDANCE_MARGIN;

  const avoidSquares = [hideArea, reloadArea].filter(isSquare);

  const candidates: Coordinate[] = [];
  for (const backRatio of FP_BACK_OFFSET_RATIOS) {
    const back = getPointFromBearing(center, backBearing, halfHeight * backRatio);
    for (const lateralRatio of FP_LATERAL_OFFSET_RATIOS) {
      if (lateralRatio === 0) {
        candidates.push(back);
        continue;
      }
      const bearing = lateralRatio > 0 ? rightBearing : (rightBearing + 180) % 360;
      candidates.push(getPointFromBearing(back, bearing, halfWidth * Math.abs(lateralRatio)));
    }
  }

  for (const candidate of candidates) {
    const isBlockedByArea = avoidSquares.some(
      (square) =>
        calculateDistance(candidate, calculateSquareCenter(square)) <
        getSquareHalfDiagonal(square) + margin
    );
    if (isBlockedByArea) continue;

    const isVisibleFromAllShelters = shelterPoints.every((shelter) =>
      avoidSquares.every((square) => !doesPathIntersectSquare(shelter, candidate, square, margin))
    );
    if (!isVisibleFromAllShelters) continue;

    return candidate;
  }

  return null;
}

// ============================================================================
// SHRL GATEWAY (shelter → reload area)
// ============================================================================
const SHRL_RING_OFFSETS = [0.1, 0.25, 0.4];
const SHRL_ANGULAR_STEP_DEGREES = 45;

/**
 * Pick a shared shelter→reload gateway on a ring around RL such that it is not
 * inside HA, every shelter reaches it without crossing HA or RL, and the
 * gateway→RL leg does not cross HA.
 */
export function selectShrlGateway(
  hideArea: Coordinate[],
  reloadArea: Coordinate[],
  shelterPoints: Coordinate[]
): Coordinate | null {
  if (shelterPoints.length === 0 || !isSquare(hideArea) || !isSquare(reloadArea)) {
    return null;
  }
  const margin = MOVEMENT_PATH_AVOIDANCE_MARGIN;

  const reloadCenter = calculateSquareCenter(reloadArea);
  const reloadHalfDiagonal = getSquareHalfDiagonal(reloadArea);
  const hideCenter = calculateSquareCenter(hideArea);
  const hideHalfDiagonal = getSquareHalfDiagonal(hideArea);

  const candidates: Coordinate[] = [];
  for (const offset of SHRL_RING_OFFSETS) {
    const radius = reloadHalfDiagonal + offset;
    for (let angle = 0; angle < 360; angle += SHRL_ANGULAR_STEP_DEGREES) {
      candidates.push(getPointFromBearing(reloadCenter, angle, radius));
    }
  }

  for (const candidate of candidates) {
    const isInsideHide = calculateDistance(candidate, hideCenter) < hideHalfDiagonal + margin;
    if (isInsideHide) continue;

    if (doesPathIntersectSquare(candidate, reloadCenter, hideArea, margin)) continue;

    // Every shelter → gateway line must clear both HA and RL. RL is the final
    // destination but only the last leg (gateway → RL center) may enter it.
    const isVisibleFromAllShelters = shelterPoints.every(
      (shelter) =>
        !doesPathIntersectSquare(shelter, candidate, hideArea, margin) &&
        !doesPathIntersectSquare(shelter, candidate, reloadArea, margin)
    );
    if (!isVisibleFromAllShelters) continue;

    return candidate;
  }

  return null;
}

// ============================================================================
// PLAN
// ============================================================================
/** Both gateways for a given shelter set, or null when either is missing. */
export function resolveGateways(
  center: Coordinate,
  openingAngle: number,
  hideArea: Coordinate[] | undefined,
  reloadArea: Coordinate[] | undefined,
  shelterPoints: Coordinate[] | undefined
): Gateways | null {
  if (!isSquare(hideArea) || !isSquare(reloadArea) || !shelterPoints?.length) return null;

  const fpGateway = selectFpGateway(center, openingAngle, hideArea, reloadArea, shelterPoints);
  if (!fpGateway) return null;

  const shrlGateway = selectShrlGateway(hideArea, reloadArea, shelterPoints);
  if (!shrlGateway) return null;

  return { fpGateway, shrlGateway };
}

/**
 * Place shelters and retry until both gateways resolve. The last attempt's
 * shelters are returned even on failure so callers can show what was tried.
 */
export function buildShelterPlan(
  center: Coordinate,
  openingAngle: number,
  hideArea: Coordinate[] | undefined,
  reloadArea: Coordinate[] | undefined,
  rng: RandomSource = Math.random
): ShelterPlan {
  const avoidAreas = [hideArea, reloadArea].filter(isSquare);
  const hasValidAreas = avoidAreas.length === 2;

  let lastShelters: Coordinate[] = [];

  for (let attempt = 0; attempt < SHELTER_PLAN_MAX_ATTEMPTS; attempt++) {
    const shelterPoints = generateShelterPoints(center, openingAngle, avoidAreas, rng);
    lastShelters = shelterPoints;
    if (!hasValidAreas) continue;

    const gateways = resolveGateways(center, openingAngle, hideArea, reloadArea, shelterPoints);
    if (gateways) return { shelterPoints, gateways };
  }

  return { shelterPoints: lastShelters, gateways: null };
}
