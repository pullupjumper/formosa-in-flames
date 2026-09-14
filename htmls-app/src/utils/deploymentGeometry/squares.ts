import type { Coordinate } from '@/types/geo';
import type { RandomSource } from '@/utils/random';
import {
  calculateBearing,
  calculateCentroid,
  calculateDistance,
  getPointFromBearing,
} from '@/utils/geo';

/**
 * Helpers over the 4-vertex squares every tactical area is drawn as.
 */

/** Centroid of a 4-vertex square; throws on any other vertex count. */
export function calculateSquareCenter(vertices: Coordinate[]): Coordinate {
  if (vertices.length !== 4) {
    throw new Error('Square must have exactly 4 vertices');
  }
  return calculateCentroid(vertices);
}

export function isSquare(area: Coordinate[] | undefined): area is Coordinate[] {
  return !!area && area.length === 4;
}

/** Mean of two adjacent edge lengths, i.e. the side of a generated square. */
export function estimateSquareSize(vertices: Coordinate[]): number {
  const edgeA = calculateDistance(vertices[0], vertices[1]);
  const edgeB = calculateDistance(vertices[1], vertices[2]);
  return (edgeA + edgeB) / 2;
}

export function getSquareHalfDiagonal(vertices: Coordinate[]): number {
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

export function isPointInSquare(
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

/** A square whose edges face the deployment center, as every relocated square does. */
export function generateSquareFacing(
  position: Coordinate,
  size: number,
  center: Coordinate
): Coordinate[] {
  return generateSquareVertices(position, size, calculateBearing(position, center));
}

/** Random point inside a `maxOffsetX` by `maxOffsetY` box rotated to `openingAngle`. */
export function generateRandomPointInBox(
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

/** True when any sample along the segment lies within `margin` of the square. */
export function doesPathIntersectSquare(
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

/** True when the segment crosses `square` while neither endpoint lies inside it. */
export function doesSegmentCrossSquare(
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
