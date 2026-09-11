/**
 * Tactical Area Generator
 * Generates rectangular boundary areas, internal squares, fire points, and movement paths.
 * All distances are nautical miles; every position is a `Coordinate`.
 */

import type { Coordinate, MovementPath } from '@/types/geo';
import type { RandomSource } from '@/utils/random';
import { calculateCentroid } from '@/utils/geo';

// ============================================================================
// Types
// ============================================================================

export interface AreaConfig {
  center: Coordinate;
  width: number;
  height: number;
  openingAngle: number;
  internalSquares?: {
    size: number;
    marginToWall: number;
    marginBetweenSquares: number;
  };
  firePoints?: {
    radius: number;
    squareSize: number;
    count: number;
    angleRange?: number;
    margin?: number;
  };
  ahaPoint?: {
    radius: number;
    squareSize: number;
    center?: Coordinate;
  };
}

export interface PathConfig {
  ammoArea: Coordinate[];
  hideArea: Coordinate[];
  reloadArea: Coordinate[];
  firePoints?: Coordinate[][];
  avoidanceMargin?: number;
  /** Shared FP-path origin (e.g. result of selectFpGateway). When provided,
   *  FP path starts here and avoids [HA, RL]; otherwise legacy HA-origin + [AHA, RL]. */
  fpGateway?: Coordinate;
  /** Shared shelter→RL gateway (e.g. result of selectShrlGateway). When provided,
   *  SHRL path starts here and goes to RL center, avoiding HA only. */
  shrlGateway?: Coordinate;
}

export interface GenerateResult {
  uShapeVertices: Coordinate[];
  ammoArea?: Coordinate[];
  hideArea?: Coordinate[];
  reloadArea?: Coordinate[];
  firePoints?: Coordinate[][];
}

export interface PathResult {
  FP: MovementPath[];
  HA: MovementPath;
  RL: MovementPath[];
  AHA: MovementPath;
  SHRL: MovementPath;
}

// ============================================================================
// Geographic Calculation Utilities
// ============================================================================

const EARTH_RADIUS_NM = 3440.065;

function toRadians(degrees: number): number {
  return (degrees * Math.PI) / 180;
}

function toDegrees(radians: number): number {
  return (radians * 180) / Math.PI;
}

/** Great-circle distance in nautical miles (haversine). */
export function calculateDistance(from: Coordinate, to: Coordinate): number {
  const latitudeDelta = toRadians(to.latitude - from.latitude);
  const longitudeDelta = toRadians(to.longitude - from.longitude);
  const a =
    Math.sin(latitudeDelta / 2) * Math.sin(latitudeDelta / 2) +
    Math.cos(toRadians(from.latitude)) *
      Math.cos(toRadians(to.latitude)) *
      Math.sin(longitudeDelta / 2) *
      Math.sin(longitudeDelta / 2);

  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return EARTH_RADIUS_NM * c;
}

/** Initial bearing from `from` to `to`, in degrees [0, 360). */
export function calculateBearing(from: Coordinate, to: Coordinate): number {
  const longitudeDelta = toRadians(to.longitude - from.longitude);
  const fromLatitude = toRadians(from.latitude);
  const toLatitude = toRadians(to.latitude);

  const y = Math.sin(longitudeDelta) * Math.cos(toLatitude);
  const x =
    Math.cos(fromLatitude) * Math.sin(toLatitude) -
    Math.sin(fromLatitude) * Math.cos(toLatitude) * Math.cos(longitudeDelta);

  const bearing = toDegrees(Math.atan2(y, x));
  return (bearing + 360) % 360;
}

/** Destination point `distance` NM from `origin` along `bearing` degrees. */
export function getPointFromBearing(
  origin: Coordinate,
  bearing: number,
  distance: number
): Coordinate {
  const bearingRad = toRadians(bearing);
  const latitudeRad = toRadians(origin.latitude);
  const longitudeRad = toRadians(origin.longitude);
  const angularDistance = distance / EARTH_RADIUS_NM;

  const newLatitudeRad = Math.asin(
    Math.sin(latitudeRad) * Math.cos(angularDistance) +
      Math.cos(latitudeRad) * Math.sin(angularDistance) * Math.cos(bearingRad)
  );

  const newLongitudeRad =
    longitudeRad +
    Math.atan2(
      Math.sin(bearingRad) * Math.sin(angularDistance) * Math.cos(latitudeRad),
      Math.cos(angularDistance) - Math.sin(latitudeRad) * Math.sin(newLatitudeRad)
    );

  return {
    latitude: toDegrees(newLatitudeRad),
    longitude: toDegrees(newLongitudeRad),
  };
}

// ============================================================================
// Square Helpers
// ============================================================================

function generateRandomSquareCenter(
  center: Coordinate,
  maxOffsetX: number,
  maxOffsetY: number,
  openingAngle: number,
  rng: RandomSource
): Coordinate {
  const offsetX = (rng() * 2 - 1) * maxOffsetX;
  const offsetY = (rng() * 2 - 1) * maxOffsetY;

  const lateral = getPointFromBearing(center, (90 + openingAngle) % 360, offsetX);
  return getPointFromBearing(lateral, (180 + openingAngle) % 360, offsetY);
}

/** Centroid of a 4-vertex square; throws on any other vertex count. */
export function calculateSquareCenter(vertices: Coordinate[]): Coordinate {
  if (vertices.length !== 4) {
    throw new Error('Square must have exactly 4 vertices');
  }
  return calculateCentroid(vertices);
}

/** Mean of two adjacent edge lengths, i.e. the side of a generated square. */
function estimateSquareSize(vertices: Coordinate[]): number {
  const edgeA = calculateDistance(vertices[0], vertices[1]);
  const edgeB = calculateDistance(vertices[1], vertices[2]);
  return (edgeA + edgeB) / 2;
}

function getSquareHalfDiagonal(vertices: Coordinate[]): number {
  return calculateDistance(calculateSquareCenter(vertices), vertices[0]);
}

export function doSquaresOverlap(
  centerA: Coordinate,
  centerB: Coordinate,
  squareSize: number,
  margin: number
): boolean {
  return calculateDistance(centerA, centerB) < squareSize + margin;
}

function isPointInSquare(
  point: Coordinate,
  squareCenter: Coordinate,
  squareSize: number,
  margin: number
): boolean {
  const halfSize = squareSize / 2 + margin;
  return calculateDistance(squareCenter, point) < halfSize;
}

/** Four corners of a square, rotated by `rotationAngle` degrees. */
export function generateSquareVertices(
  center: Coordinate,
  size: number,
  rotationAngle: number
): Coordinate[] {
  const halfSize = size / 2;
  const diagonalDistance = Math.sqrt(2) * halfSize;
  const cornerAngles = [45, 135, 225, 315];
  return cornerAngles.map((cornerAngle) =>
    getPointFromBearing(center, (cornerAngle + rotationAngle) % 360, diagonalDistance)
  );
}

function doesPathIntersectSquare(
  start: Coordinate,
  end: Coordinate,
  squareVertices: Coordinate[],
  margin: number
): boolean {
  const squareCenter = calculateSquareCenter(squareVertices);
  const squareSize = estimateSquareSize(squareVertices);

  const sampleCount = 10;
  for (let i = 0; i <= sampleCount; i++) {
    const t = i / sampleCount;
    const sample: Coordinate = {
      latitude: start.latitude + t * (end.latitude - start.latitude),
      longitude: start.longitude + t * (end.longitude - start.longitude),
    };
    if (isPointInSquare(sample, squareCenter, squareSize, margin)) {
      return true;
    }
  }
  return false;
}

function calculateSquareOffsetCorners(squareVertices: Coordinate[], offset: number): Coordinate[] {
  const squareCenter = calculateSquareCenter(squareVertices);
  const offsetDistance = offset * 1.2;
  return squareVertices.map((vertex) =>
    getPointFromBearing(vertex, calculateBearing(squareCenter, vertex), offsetDistance)
  );
}

/** True when the segment crosses `square` while neither endpoint lies inside it. */
function doesSegmentCrossSquare(
  start: Coordinate,
  end: Coordinate,
  square: Coordinate[],
  margin: number
): boolean {
  const squareCenter = calculateSquareCenter(square);
  const squareSize = estimateSquareSize(square);
  const startInside = isPointInSquare(start, squareCenter, squareSize, 0);
  const endInside = isPointInSquare(end, squareCenter, squareSize, 0);
  return !startInside && !endInside && doesPathIntersectSquare(start, end, square, margin);
}

function selectBestAvoidanceCornerPair(
  start: Coordinate,
  end: Coordinate,
  offsetCorners: Coordinate[],
  otherSquares: Coordinate[][],
  margin: number
): [Coordinate | null, Coordinate | null] {
  if (offsetCorners.length !== 4) {
    return [null, null];
  }

  let bestPair: [Coordinate, Coordinate] | null = null;
  let minDistance = Infinity;

  for (let i = 0; i < 4; i++) {
    const pairs: [Coordinate, Coordinate][] = [
      [offsetCorners[i], offsetCorners[(i + 1) % 4]],
      [offsetCorners[(i + 1) % 4], offsetCorners[i]],
    ];

    for (const [cornerA, cornerB] of pairs) {
      const legs: [Coordinate, Coordinate][] = [
        [start, cornerA],
        [cornerA, cornerB],
        [cornerB, end],
      ];
      const hasCollision = legs.some(([legStart, legEnd]) =>
        otherSquares.some((square) => doesSegmentCrossSquare(legStart, legEnd, square, margin))
      );
      if (hasCollision) continue;

      const totalDistance =
        calculateDistance(start, cornerA) +
        calculateDistance(cornerA, cornerB) +
        calculateDistance(cornerB, end);
      if (totalDistance < minDistance) {
        minDistance = totalDistance;
        bestPair = [cornerA, cornerB];
      }
    }
  }

  return bestPair || [null, null];
}

// ============================================================================
// Path Generation (avoid other position squares only)
// ============================================================================

function generatePathWithAvoidance(
  start: Coordinate,
  end: Coordinate,
  avoidanceMargin: number,
  avoidSquares: Coordinate[][]
): Coordinate[] {
  const waypoints: Coordinate[] = [{ ...start }, { ...end }];

  if (avoidSquares.length === 0) return waypoints;

  const maxIterations = 20;
  const offsetMultipliers = [2.0, 2.5, 3.0, 3.5, 4.0, 5.0];
  let modified = true;
  let iteration = 0;

  while (modified && iteration < maxIterations) {
    modified = false;
    iteration++;

    for (let i = 0; i < waypoints.length - 1 && !modified; i++) {
      const segmentStart = waypoints[i];
      const segmentEnd = waypoints[i + 1];

      for (let squareIndex = 0; squareIndex < avoidSquares.length; squareIndex++) {
        const squareVertices = avoidSquares[squareIndex];
        if (!doesSegmentCrossSquare(segmentStart, segmentEnd, squareVertices, avoidanceMargin)) {
          continue;
        }

        const otherSquares = avoidSquares.filter((_, index) => index !== squareIndex);
        let cornerA: Coordinate | null = null;
        let cornerB: Coordinate | null = null;

        for (const multiplier of offsetMultipliers) {
          const offsetCorners = calculateSquareOffsetCorners(
            squareVertices,
            avoidanceMargin * multiplier
          );
          [cornerA, cornerB] = selectBestAvoidanceCornerPair(
            segmentStart,
            segmentEnd,
            offsetCorners,
            otherSquares,
            avoidanceMargin
          );
          if (cornerA && cornerB) break;
        }

        if (cornerA && cornerB) {
          waypoints.splice(i + 1, 0, { ...cornerA }, { ...cornerB });
          modified = true;
          break;
        }
      }
    }
  }

  return waypoints;
}

// ============================================================================
// Internal Area Generation
// ============================================================================

function generateInternalSquares(
  boundaryCorners: Coordinate[],
  openingAngle: number,
  squareSize: number,
  areaWidth: number,
  areaHeight: number,
  rng: RandomSource,
  marginToWall = 0.1,
  marginBetweenSquares = 0.1
): { hideArea: Coordinate[]; reloadArea: Coordinate[] } {
  const maxAttempts = 100;
  const halfSquare = squareSize / 2;
  const boundaryCenter = calculateCentroid(boundaryCorners);

  const maxOffsetX = areaWidth / 2 - halfSquare - marginToWall;
  const maxOffsetY = areaHeight / 2 - halfSquare - marginToWall;

  if (maxOffsetX <= 0 || maxOffsetY <= 0) {
    console.error(
      `Square size (${squareSize} nm) too large for boundary area (${areaWidth} x ${areaHeight} nm)`
    );
    return { hideArea: [], reloadArea: [] };
  }

  const centers: Coordinate[] = [];
  const areaNames = ['hideArea', 'reloadArea'];

  for (let i = 0; i < 2; i++) {
    let isPlaced = false;
    let attempts = 0;

    while (!isPlaced && attempts < maxAttempts) {
      attempts++;
      const candidate = generateRandomSquareCenter(
        boundaryCenter,
        maxOffsetX,
        maxOffsetY,
        openingAngle,
        rng
      );

      const overlaps = centers.some((existing) =>
        doSquaresOverlap(candidate, existing, squareSize, marginBetweenSquares)
      );
      if (!overlaps) {
        centers.push(candidate);
        isPlaced = true;
      }
    }

    if (!isPlaced) {
      console.error(`Failed to place ${areaNames[i]} after ${maxAttempts} attempts`);
    }
  }

  const verticesAt = (index: number): Coordinate[] =>
    centers[index] ? generateSquareVertices(centers[index], squareSize, openingAngle) : [];

  return { hideArea: verticesAt(0), reloadArea: verticesAt(1) };
}

function generateAhaPosition(
  center: Coordinate,
  radius: number,
  squareSize: number,
  openingAngle: number,
  customCenter?: Coordinate
): Coordinate[] {
  if (customCenter) {
    const bearingToCenter = calculateBearing(customCenter, center);
    return generateSquareVertices(customCenter, squareSize, bearingToCenter);
  }
  const ahaCenter = getPointFromBearing(center, openingAngle, radius);
  return generateSquareVertices(ahaCenter, squareSize, openingAngle);
}

function generateFirePoints(
  center: Coordinate,
  radius: number,
  squareSize: number,
  count: number,
  angleRange: number,
  openingAngle: number,
  margin: number,
  boundaryWidth: number,
  boundaryHeight: number,
  rng: RandomSource
): Coordinate[][] {
  const firePoints: { center: Coordinate; vertices: Coordinate[] }[] = [];
  const maxAttempts = 200;

  const boundaryMaxDistance = Math.sqrt((boundaryWidth / 2) ** 2 + (boundaryHeight / 2) ** 2);
  const startAngle = openingAngle + 180 - angleRange / 2;
  const squareDiagonal = Math.sqrt(2) * (squareSize / 2);
  const minSafeDistance = boundaryMaxDistance + squareDiagonal + margin;

  for (let i = 0; i < count; i++) {
    let isPlaced = false;
    let attempts = 0;

    while (!isPlaced && attempts < maxAttempts) {
      attempts++;

      const randomAngle = (startAngle + rng() * angleRange) % 360;
      const candidate = getPointFromBearing(center, randomAngle, radius);

      // Ensure fire point is outside the boundary rectangle
      if (calculateDistance(center, candidate) < minSafeDistance) continue;

      const overlaps = firePoints.some((existing) =>
        doSquaresOverlap(candidate, existing.center, squareSize, margin)
      );
      if (overlaps) continue;

      const bearingToCenter = calculateBearing(candidate, center);
      firePoints.push({
        center: candidate,
        vertices: generateSquareVertices(candidate, squareSize, bearingToCenter),
      });
      isPlaced = true;
    }

    if (!isPlaced) {
      console.error(`Failed to place fire point ${i + 1}/${count} after ${maxAttempts} attempts`);
    }
  }

  return firePoints.map((firePoint) => firePoint.vertices);
}

// ============================================================================
// Shelter Points Generation
// ============================================================================

export interface ShelterPointsConfig {
  center: Coordinate;
  areaWidth: number;
  areaHeight: number;
  openingAngle: number;
  avoidAreas?: Coordinate[][];
  count?: number;
  marginToWall?: number;
  marginToAreas?: number;
  marginBetweenPoints?: number;
  maxAttemptsPerPoint?: number;
  /** Defaults to `Math.random`; pass a seeded source for reproducible output. */
  rng?: RandomSource;
}

/**
 * Generate random shelter coordinates inside the U-shape rectangle,
 * avoiding the supplied tactical squares (typically HA and RL).
 */
export function generateShelterPoints(config: ShelterPointsConfig): Coordinate[] {
  const {
    center,
    areaWidth,
    areaHeight,
    openingAngle,
    avoidAreas = [],
    count = 2,
    marginToWall = 0.1,
    marginToAreas = 0.1,
    marginBetweenPoints = 0.2,
    maxAttemptsPerPoint = 200,
    rng = Math.random,
  } = config;

  const maxOffsetX = areaWidth / 2 - marginToWall;
  const maxOffsetY = areaHeight / 2 - marginToWall;
  if (maxOffsetX <= 0 || maxOffsetY <= 0 || count <= 0) {
    return [];
  }

  const exclusions = avoidAreas
    .filter((area) => area.length === 4)
    .map((area) => ({
      center: calculateSquareCenter(area),
      radius: getSquareHalfDiagonal(area) + marginToAreas,
    }));

  const points: Coordinate[] = [];

  for (let i = 0; i < count; i++) {
    let isPlaced = false;

    for (let attempt = 0; attempt < maxAttemptsPerPoint && !isPlaced; attempt++) {
      const candidate = generateRandomSquareCenter(
        center,
        maxOffsetX,
        maxOffsetY,
        openingAngle,
        rng
      );

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
// FP Gateway Selection
// ============================================================================

export interface GatewayConfig {
  uShapeCenter: Coordinate;
  openingAngle: number;
  areaWidth: number;
  areaHeight: number;
  hideArea: Coordinate[];
  reloadArea: Coordinate[];
  shelterPoints: Coordinate[];
  avoidanceMargin?: number;
  backOffsetRatios?: number[];
  lateralOffsetRatios?: number[];
}

/**
 * Pick a shared FP-path origin on the back side of the U-shape such that every
 * shelter has line-of-sight to it without crossing HA or RL. Returns null when
 * no candidate satisfies the constraints.
 */
export function selectFpGateway(config: GatewayConfig): Coordinate | null {
  const {
    uShapeCenter,
    openingAngle,
    areaWidth,
    areaHeight,
    hideArea,
    reloadArea,
    shelterPoints,
    avoidanceMargin = 0.1,
    backOffsetRatios = [0.95, 1.05, 0.8],
    lateralOffsetRatios = [0, -0.4, 0.4, -0.6, 0.6],
  } = config;

  if (shelterPoints.length === 0) return null;

  const halfHeight = areaHeight / 2;
  const halfWidth = areaWidth / 2;
  const backBearing = (openingAngle + 180) % 360;
  const rightBearing = (openingAngle + 90) % 360;

  const avoidSquares = [hideArea, reloadArea].filter((area) => area.length === 4);

  const candidates: Coordinate[] = [];
  for (const backRatio of backOffsetRatios) {
    const back = getPointFromBearing(uShapeCenter, backBearing, halfHeight * backRatio);
    for (const lateralRatio of lateralOffsetRatios) {
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
        getSquareHalfDiagonal(square) + avoidanceMargin
    );
    if (isBlockedByArea) continue;

    const isVisibleFromAllShelters = shelterPoints.every((shelter) =>
      avoidSquares.every(
        (square) => !doesPathIntersectSquare(shelter, candidate, square, avoidanceMargin)
      )
    );
    if (!isVisibleFromAllShelters) continue;

    return candidate;
  }

  return null;
}

// ============================================================================
// SHRL Gateway Selection (shelter → reload area)
// ============================================================================

export interface ShrlGatewayConfig {
  hideArea: Coordinate[];
  reloadArea: Coordinate[];
  shelterPoints: Coordinate[];
  avoidanceMargin?: number;
  /** Offsets (nm) added to RL half-diagonal to form candidate rings. */
  ringOffsets?: number[];
  /** Angular step (degrees) between candidates on each ring. */
  angularStepDegrees?: number;
}

/**
 * Pick a shared shelter→reload gateway placed on a ring around RL such that
 * (a) candidate is not inside HA, (b) every shelter reaches it without crossing
 * HA, and (c) the candidate → reload-center line does not cross HA.
 */
export function selectShrlGateway(config: ShrlGatewayConfig): Coordinate | null {
  const {
    hideArea,
    reloadArea,
    shelterPoints,
    avoidanceMargin = 0.1,
    ringOffsets = [0.1, 0.25, 0.4],
    angularStepDegrees = 45,
  } = config;

  if (shelterPoints.length === 0 || hideArea.length !== 4 || reloadArea.length !== 4) {
    return null;
  }

  const reloadCenter = calculateSquareCenter(reloadArea);
  const reloadHalfDiagonal = getSquareHalfDiagonal(reloadArea);
  const hideCenter = calculateSquareCenter(hideArea);
  const hideHalfDiagonal = getSquareHalfDiagonal(hideArea);

  const candidates: Coordinate[] = [];
  for (const offset of ringOffsets) {
    const radius = reloadHalfDiagonal + offset;
    for (let angle = 0; angle < 360; angle += angularStepDegrees) {
      candidates.push(getPointFromBearing(reloadCenter, angle, radius));
    }
  }

  for (const candidate of candidates) {
    const isInsideHide =
      calculateDistance(candidate, hideCenter) < hideHalfDiagonal + avoidanceMargin;
    if (isInsideHide) continue;

    const isGatewayToReloadBlocked = doesPathIntersectSquare(
      candidate,
      reloadCenter,
      hideArea,
      avoidanceMargin
    );
    if (isGatewayToReloadBlocked) continue;

    // Every shelter → gateway line must clear both HA and RL. RL is the final
    // destination but only the last leg (gateway → RL center) is allowed to
    // enter it — earlier legs crossing RL would mean the vehicle passes through
    // the reload area just to reach the gateway, which is semantically wrong.
    const isVisibleFromAllShelters = shelterPoints.every(
      (shelter) =>
        !doesPathIntersectSquare(shelter, candidate, hideArea, avoidanceMargin) &&
        !doesPathIntersectSquare(shelter, candidate, reloadArea, avoidanceMargin)
    );
    if (!isVisibleFromAllShelters) continue;

    return candidate;
  }

  return null;
}

// ============================================================================
// Public API Functions
// ============================================================================

export function generateUShapeVertices(
  areaConfig: AreaConfig,
  rng: RandomSource = Math.random
): GenerateResult {
  if (!areaConfig.center?.latitude) throw new Error('config.center.latitude is required');
  if (!areaConfig.center?.longitude) throw new Error('config.center.longitude is required');
  if (!areaConfig.width) throw new Error('config.width is required');
  if (!areaConfig.height) throw new Error('config.height is required');
  if (areaConfig.openingAngle === undefined) throw new Error('config.openingAngle is required');

  const { center, width, height, openingAngle } = areaConfig;

  const halfWidth = width / 2;
  const halfHeight = height / 2;

  const outerDiagonalDistance = Math.sqrt(halfWidth * halfWidth + halfHeight * halfHeight);
  const baseAngle = toDegrees(Math.atan2(halfWidth, halfHeight));
  const outerAngles = [360 - baseAngle, baseAngle, 180 - baseAngle, 180 + baseAngle];

  // Boundary is a simple quadrilateral (4 vertices)
  const outerCorners = outerAngles.map((outerAngle) =>
    getPointFromBearing(center, (outerAngle + openingAngle) % 360, outerDiagonalDistance)
  );

  const result: GenerateResult = { uShapeVertices: outerCorners };

  if (areaConfig.internalSquares) {
    const internalSquares = generateInternalSquares(
      outerCorners,
      openingAngle,
      areaConfig.internalSquares.size,
      width,
      height,
      rng,
      areaConfig.internalSquares.marginToWall,
      areaConfig.internalSquares.marginBetweenSquares
    );
    result.hideArea = internalSquares.hideArea;
    result.reloadArea = internalSquares.reloadArea;
  }

  if (areaConfig.ahaPoint) {
    result.ammoArea = generateAhaPosition(
      center,
      areaConfig.ahaPoint.radius,
      areaConfig.ahaPoint.squareSize,
      openingAngle,
      areaConfig.ahaPoint.center
    );
  }

  if (areaConfig.firePoints) {
    result.firePoints = generateFirePoints(
      center,
      areaConfig.firePoints.radius,
      areaConfig.firePoints.squareSize,
      areaConfig.firePoints.count,
      areaConfig.firePoints.angleRange || 360,
      openingAngle,
      areaConfig.firePoints.margin || 0.1,
      width,
      height,
      rng
    );
  }

  return result;
}

export function calculateMovementPaths(pathConfig: PathConfig): PathResult {
  if (!pathConfig.ammoArea) throw new Error('config.ammoArea is required');
  if (!pathConfig.hideArea) throw new Error('config.hideArea is required');
  if (!pathConfig.reloadArea) throw new Error('config.reloadArea is required');

  const avoidanceMargin = pathConfig.avoidanceMargin || 0.3;
  const paths: PathResult = {
    FP: [],
    HA: { waypoints: [] },
    RL: [],
    AHA: { waypoints: [] },
    SHRL: { waypoints: [] },
  };

  const ammoCenter = calculateSquareCenter(pathConfig.ammoArea);
  const hideCenter = calculateSquareCenter(pathConfig.hideArea);
  const reloadCenter = calculateSquareCenter(pathConfig.reloadArea);

  // HA: reload -> hide, avoid ammo
  paths.HA.waypoints = generatePathWithAvoidance(reloadCenter, hideCenter, avoidanceMargin, [
    pathConfig.ammoArea,
  ]);

  // AHA: reload -> ammo, avoid hide
  paths.AHA.waypoints = generatePathWithAvoidance(reloadCenter, ammoCenter, avoidanceMargin, [
    pathConfig.hideArea,
  ]);

  if (pathConfig.firePoints) {
    // FP: gateway (or hide center fallback) -> fire points.
    // When fpGateway is supplied we assume shelter vehicles will prepend their own
    // position, so the shared path must avoid HA and RL. Without a gateway we fall
    // back to the legacy HA-origin behaviour.
    const fpOrigin = pathConfig.fpGateway ?? hideCenter;
    const fpAvoid = pathConfig.fpGateway
      ? [pathConfig.hideArea, pathConfig.reloadArea]
      : [pathConfig.ammoArea, pathConfig.reloadArea];

    pathConfig.firePoints.forEach((firePoint, index) => {
      const firePointCenter = calculateSquareCenter(firePoint);
      paths.FP[index] = {
        waypoints: generatePathWithAvoidance(fpOrigin, firePointCenter, avoidanceMargin, fpAvoid),
      };
      // RL: fire points -> reload, avoid ammo & hide
      paths.RL[index] = {
        waypoints: generatePathWithAvoidance(firePointCenter, reloadCenter, avoidanceMargin, [
          pathConfig.ammoArea,
          pathConfig.hideArea,
        ]),
      };
    });
  }

  // SHRL: shelter-gateway -> reload, avoid HA only.
  // As with FP, vehicles at individual shelters prepend their own position;
  // the gateway must stay in the waypoint list so the approach stays HA-clear.
  if (pathConfig.shrlGateway) {
    paths.SHRL.waypoints = generatePathWithAvoidance(
      pathConfig.shrlGateway,
      reloadCenter,
      avoidanceMargin,
      [pathConfig.hideArea]
    );
  }

  return paths;
}
