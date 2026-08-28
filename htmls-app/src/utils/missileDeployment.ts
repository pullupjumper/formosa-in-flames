import type { DeployedMissileSystemData } from '@/types/setupMenu';
import { checkPolygonInTaiwan } from '@/utils/map';
import {
  generateUShapeVertices,
  calculateMovementPaths,
  generateShelterPoints,
  chooseFpGateway,
  chooseShrlGateway,
} from '@/utils/tacticalAreaGenerator';
import type { Coordinate } from '@/utils/tacticalAreaGenerator';

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
export const REF_CENTER = { lat: 23.8, lng: 121.0 };

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
  centerLat: number;
  centerLng: number;
  openingAngle: number;
}

export interface ShelterPlan {
  shelterPoints: Coordinate[];
  fpGateway: Coordinate | null;
  shrlGateway: Coordinate | null;
}

export interface OffsetVertex {
  dLat: number;
  dLng: number;
}

export interface PreviewOffsets {
  uShapeVertices: OffsetVertex[];
  ammoArea: OffsetVertex[];
  hideArea: OffsetVertex[];
  reloadArea: OffsetVertex[];
  firePoints: OffsetVertex[][];
}

export interface GenerateDeploymentParams {
  unitName: string;
  category: string;
  lat: number;
  lng: number;
  angle: number;
  validateTaiwanBoundary: boolean;
  ahaRadiusOverride?: number;
  ahaCenterOverride?: { lat: number; lng: number };
}

export interface RotationPreview {
  uShapeVertices: Coordinate[];
  ammoArea: Coordinate[];
  hideArea: Coordinate[];
  reloadArea: Coordinate[];
}

// ============================================================================
// GEOMETRY HELPERS
// ============================================================================
export function createEmptyMovementPaths(): DeployedMissileSystemData['paths'] {
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

/** Ray casting against a lat/lng polygon */
export function isPointInPolygon(point: Coordinate, polygon: Coordinate[]): boolean {
  let inside = false;
  for (let i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
    const yi = polygon[i].latitude;
    const xi = polygon[i].longitude;
    const yj = polygon[j].latitude;
    const xj = polygon[j].longitude;
    if (
      yi > point.latitude !== yj > point.latitude &&
      point.longitude < ((xj - xi) * (point.latitude - yi)) / (yj - yi) + xi
    ) {
      inside = !inside;
    }
  }
  return inside;
}

export function areAllPointsInPolygon(points: Coordinate[], polygon: Coordinate[]): boolean {
  return points.every((point) => isPointInPolygon(point, polygon));
}

// ============================================================================
// SHELTER PLANNING
// ============================================================================
function buildShelterPoints(
  centerLat: number,
  centerLon: number,
  openingAngle: number,
  hideArea?: Coordinate[],
  reloadArea?: Coordinate[]
): Coordinate[] {
  const avoidAreas: Coordinate[][] = [];
  if (hideArea && hideArea.length === 4) avoidAreas.push(hideArea);
  if (reloadArea && reloadArea.length === 4) avoidAreas.push(reloadArea);

  return generateShelterPoints({
    centerLat,
    centerLon,
    areaWidth: AREA_CONFIG.width,
    areaHeight: AREA_CONFIG.height,
    openingAngle,
    avoidAreas,
    count: AREA_CONFIG.shelter.count,
    marginToWall: AREA_CONFIG.shelter.marginToWall,
    marginToAreas: AREA_CONFIG.shelter.marginToAreas,
    marginBetweenPoints: AREA_CONFIG.shelter.marginBetweenPoints,
  });
}

/**
 * Generate shelter points that share BOTH the FP and SHRL gateways. Retries
 * shelter placement until both gateways succeed or we hit the attempt cap.
 */
export function buildShelterPlan(
  centerLat: number,
  centerLon: number,
  openingAngle: number,
  hideArea?: Coordinate[],
  reloadArea?: Coordinate[]
): ShelterPlan {
  const hasValidAreas =
    !!hideArea && hideArea.length === 4 && !!reloadArea && reloadArea.length === 4;

  let lastShelters: Coordinate[] = [];

  for (let attempt = 0; attempt < SHELTER_PLAN_MAX_ATTEMPTS; attempt++) {
    const shelters = buildShelterPoints(centerLat, centerLon, openingAngle, hideArea, reloadArea);
    lastShelters = shelters;
    if (!hasValidAreas || shelters.length === 0) continue;

    const fpGateway = chooseFpGateway({
      uShapeCenterLat: centerLat,
      uShapeCenterLon: centerLon,
      openingAngle,
      areaWidth: AREA_CONFIG.width,
      areaHeight: AREA_CONFIG.height,
      hideArea: hideArea!,
      reloadArea: reloadArea!,
      shelterPoints: shelters,
      avoidanceMargin: MOVEMENT_PATH_AVOIDANCE_MARGIN,
    });
    if (!fpGateway) continue;

    const shrlGateway = chooseShrlGateway({
      hideArea: hideArea!,
      reloadArea: reloadArea!,
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
  tacticalAreas: DeployedMissileSystemData['tacticalAreas'],
  context: DeploymentContext
): { fpGateway: Coordinate | null; shrlGateway: Coordinate | null } {
  if (
    !tacticalAreas.hideArea ||
    tacticalAreas.hideArea.length !== 4 ||
    !tacticalAreas.reloadArea ||
    tacticalAreas.reloadArea.length !== 4 ||
    !tacticalAreas.shelterPoints ||
    tacticalAreas.shelterPoints.length === 0
  ) {
    return { fpGateway: null, shrlGateway: null };
  }

  const fpGateway = chooseFpGateway({
    uShapeCenterLat: context.centerLat,
    uShapeCenterLon: context.centerLng,
    openingAngle: context.openingAngle,
    areaWidth: AREA_CONFIG.width,
    areaHeight: AREA_CONFIG.height,
    hideArea: tacticalAreas.hideArea,
    reloadArea: tacticalAreas.reloadArea,
    shelterPoints: tacticalAreas.shelterPoints,
    avoidanceMargin: MOVEMENT_PATH_AVOIDANCE_MARGIN,
  });

  const shrlGateway = chooseShrlGateway({
    hideArea: tacticalAreas.hideArea,
    reloadArea: tacticalAreas.reloadArea,
    shelterPoints: tacticalAreas.shelterPoints,
    avoidanceMargin: MOVEMENT_PATH_AVOIDANCE_MARGIN,
  });

  return { fpGateway, shrlGateway };
}

export function buildMovementPaths(
  tacticalAreas: DeployedMissileSystemData['tacticalAreas'],
  context: DeploymentContext
): DeployedMissileSystemData['paths'] {
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
  centerLat: number,
  centerLon: number,
  openingAngle: number,
  ahaRadiusOverride?: number,
  ahaCenterOverride?: { lat: number; lng: number }
) {
  return {
    centerLat,
    centerLon,
    openingAngle,
    ...AREA_CONFIG,
    ahaPoint: {
      ...AREA_CONFIG.ahaPoint,
      radius: ahaRadiusOverride ?? AREA_CONFIG.ahaPoint.radius,
      ...(ahaCenterOverride
        ? { center: { latitude: ahaCenterOverride.lat, longitude: ahaCenterOverride.lng } }
        : {}),
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
  lat,
  lng,
  angle,
  validateTaiwanBoundary,
  ahaRadiusOverride,
  ahaCenterOverride,
}: GenerateDeploymentParams): DeployedMissileSystemData | null {
  try {
    const areaConfig = buildAreaConfig(lat, lng, angle, ahaRadiusOverride, ahaCenterOverride);

    // Outer retry: if buildShelterPlan can't converge on both gateways with
    // this HA/RL layout, regenerate the U-shape (which re-randomizes HA/RL/FP)
    // and try again. Shelter inner retry is bounded separately.
    for (let attempt = 0; attempt < DEPLOYMENT_MAX_ATTEMPTS; attempt++) {
      const result = generateUShapeVertices(areaConfig);

      // Taiwan boundary is deterministic w.r.t. lat/lng/angle; no point retrying.
      if (validateTaiwanBoundary && !checkPolygonInTaiwan(result.uShapeVertices)) {
        return null;
      }

      const plan = buildShelterPlan(lat, lng, angle, result.hideArea, result.reloadArea);
      if (!plan.fpGateway || !plan.shrlGateway) {
        continue;
      }

      const tacticalAreas = {
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
        center: { lat, lng },
        openingAngle: angle,
        ahaRadius: ahaRadiusOverride ?? AREA_CONFIG.ahaPoint.radius,
        ...(ahaCenterOverride ? { ahaCenter: ahaCenterOverride } : {}),
        tacticalAreas,
        paths: buildMovementPaths(tacticalAreas, {
          centerLat: lat,
          centerLng: lng,
          openingAngle: angle,
        }),
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
// PREVIEWS
// ============================================================================
function resultToOffsets(
  result: ReturnType<typeof generateUShapeVertices>,
  refLat: number,
  refLng: number
): PreviewOffsets {
  const toOffset = (c: Coordinate): OffsetVertex => ({
    dLat: c.latitude - refLat,
    dLng: c.longitude - refLng,
  });
  return {
    uShapeVertices: result.uShapeVertices.map(toOffset),
    ammoArea: (result.ammoArea ?? []).map(toOffset),
    hideArea: (result.hideArea ?? []).map(toOffset),
    reloadArea: (result.reloadArea ?? []).map(toOffset),
    firePoints: (result.firePoints ?? []).map((fp) => fp.map(toOffset)),
  };
}

/**
 * Precompute a layout at REF_CENTER as lat/lng deltas, so the hover preview can
 * follow the cursor by translation instead of regenerating geometry per frame.
 */
export function generateOffsetsForAngle(
  angle: number,
  ahaRadiusOverride?: number
): PreviewOffsets | null {
  try {
    const result = generateUShapeVertices(
      buildAreaConfig(REF_CENTER.lat, REF_CENTER.lng, angle, ahaRadiusOverride)
    );
    return resultToOffsets(result, REF_CENTER.lat, REF_CENTER.lng);
  } catch (error) {
    console.error('Failed to generate offsets for angle:', angle, error);
    return null;
  }
}

/** Regenerate a deployed unit's areas at a candidate opening angle */
export function generateRotationPreview(
  center: { lat: number; lng: number },
  angle: number,
  ahaRadius?: number,
  ahaCenter?: { lat: number; lng: number }
): RotationPreview | null {
  try {
    const result = generateUShapeVertices(
      buildAreaConfig(center.lat, center.lng, angle, ahaRadius, ahaCenter)
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
