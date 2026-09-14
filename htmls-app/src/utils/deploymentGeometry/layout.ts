import type { Coordinate } from '@/types/geo';
import type { RandomSource } from '@/utils/random';
import {
  calculateBearing,
  calculateCentroid,
  calculateDistance,
  getPointFromBearing,
} from '@/utils/geo';
import { AREA_CONFIG } from './config';
import { doSquaresOverlap, generateRandomPointInBox, generateSquareVertices } from './squares';

/**
 * The random part of a deployment: boundary rectangle, HA/RL inside it, fire
 * points on the FP arc and the AHA square. Shelters and paths build on top of
 * this in `shelter.ts` and `paths.ts`.
 */

export interface Layout {
  uShapeVertices: Coordinate[];
  ammoArea: Coordinate[];
  hideArea: Coordinate[];
  reloadArea: Coordinate[];
  firePoints: Coordinate[][];
}

export interface LayoutOptions {
  /** Scenario-placed units may sit at a non-default AHA distance */
  ahaRadius?: number;
  /** A hand-placed AHA stays where the user put it */
  ahaCenter?: Coordinate;
}

// ============================================================================
// BOUNDARY
// ============================================================================
function generateBoundary(center: Coordinate, openingAngle: number): Coordinate[] {
  const halfWidth = AREA_CONFIG.width / 2;
  const halfHeight = AREA_CONFIG.height / 2;

  const outerDiagonalDistance = Math.hypot(halfWidth, halfHeight);
  const baseAngle = (Math.atan2(halfWidth, halfHeight) * 180) / Math.PI;
  const outerAngles = [360 - baseAngle, baseAngle, 180 - baseAngle, 180 + baseAngle];

  return outerAngles.map((outerAngle) =>
    getPointFromBearing(center, (outerAngle + openingAngle) % 360, outerDiagonalDistance)
  );
}

// ============================================================================
// HA / RL
// ============================================================================
function generateInternalSquares(
  boundaryCorners: Coordinate[],
  openingAngle: number,
  rng: RandomSource
): { hideArea: Coordinate[]; reloadArea: Coordinate[] } {
  const { size, marginToWall, marginBetweenSquares } = AREA_CONFIG.internalSquares;
  const maxAttempts = 100;
  const halfSquare = size / 2;
  const boundaryCenter = calculateCentroid(boundaryCorners);

  const maxOffsetX = AREA_CONFIG.width / 2 - halfSquare - marginToWall;
  const maxOffsetY = AREA_CONFIG.height / 2 - halfSquare - marginToWall;

  if (maxOffsetX <= 0 || maxOffsetY <= 0) {
    console.error(
      `Square size (${size} nm) too large for boundary area (${AREA_CONFIG.width} x ${AREA_CONFIG.height} nm)`
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
      const candidate = generateRandomPointInBox(
        boundaryCenter,
        maxOffsetX,
        maxOffsetY,
        openingAngle,
        rng
      );

      const overlaps = centers.some((existing) =>
        doSquaresOverlap(candidate, existing, size, marginBetweenSquares)
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
    centers[index] ? generateSquareVertices(centers[index], size, openingAngle) : [];

  return { hideArea: verticesAt(0), reloadArea: verticesAt(1) };
}

// ============================================================================
// AHA
// ============================================================================
function generateAhaArea(
  center: Coordinate,
  openingAngle: number,
  { ahaRadius, ahaCenter }: LayoutOptions
): Coordinate[] {
  const { squareSize, radius } = AREA_CONFIG.ahaPoint;
  if (ahaCenter) {
    const bearingToCenter = calculateBearing(ahaCenter, center);
    return generateSquareVertices(ahaCenter, squareSize, bearingToCenter);
  }
  const position = getPointFromBearing(center, openingAngle, ahaRadius ?? radius);
  return generateSquareVertices(position, squareSize, openingAngle);
}

// ============================================================================
// FIRE POINTS
// ============================================================================
function generateFirePoints(
  center: Coordinate,
  openingAngle: number,
  rng: RandomSource
): Coordinate[][] {
  const { radius, squareSize, count, angleRange, margin } = AREA_CONFIG.firePoints;
  const firePoints: { center: Coordinate; vertices: Coordinate[] }[] = [];
  const maxAttempts = 200;

  const boundaryMaxDistance = Math.hypot(AREA_CONFIG.width / 2, AREA_CONFIG.height / 2);
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
// LAYOUT
// ============================================================================
/**
 * One random layout around `center`. Throws on a non-finite center or angle
 * so a bad input cannot silently become a layout in the ocean.
 */
export function generateLayout(
  center: Coordinate,
  openingAngle: number,
  options: LayoutOptions = {},
  rng: RandomSource = Math.random
): Layout {
  if (!Number.isFinite(center?.latitude) || !Number.isFinite(center?.longitude)) {
    throw new Error('generateLayout: center must be a finite Coordinate');
  }
  if (!Number.isFinite(openingAngle)) {
    throw new Error('generateLayout: openingAngle must be a finite number');
  }

  const uShapeVertices = generateBoundary(center, openingAngle);
  const { hideArea, reloadArea } = generateInternalSquares(uShapeVertices, openingAngle, rng);

  return {
    uShapeVertices,
    hideArea,
    reloadArea,
    ammoArea: generateAhaArea(center, openingAngle, options),
    firePoints: generateFirePoints(center, openingAngle, rng),
  };
}
