import type { Coordinate } from '@/types/geo';
import type { MovementPaths, TacticalAreas } from '@/types/controlPanel';
import { calculateBearing, calculateDistance, getPointFromBearing } from '@/utils/geo';
import { MOVEMENT_PATH_AVOIDANCE_MARGIN } from './config';
import { calculateSquareCenter, doesSegmentCrossSquare } from './squares';
import type { Gateways } from './shelter';

/**
 * Vehicle routes between the tactical areas. Straight lines, bent around any
 * square they would otherwise drive through.
 */

export function createEmptyMovementPaths(): MovementPaths {
  return {
    FP: [],
    HA: { waypoints: [] },
    RL: [],
    AHA: { waypoints: [] },
    SHRL: { waypoints: [] },
  };
}

// ============================================================================
// AVOIDANCE
// ============================================================================
function calculateSquareOffsetCorners(squareVertices: Coordinate[], offset: number): Coordinate[] {
  const squareCenter = calculateSquareCenter(squareVertices);
  const offsetDistance = offset * 1.2;
  return squareVertices.map((vertex) =>
    getPointFromBearing(vertex, calculateBearing(squareCenter, vertex), offsetDistance)
  );
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

export function generatePathWithAvoidance(
  start: Coordinate,
  end: Coordinate,
  avoidSquares: Coordinate[][],
  avoidanceMargin = MOVEMENT_PATH_AVOIDANCE_MARGIN
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
// MOVEMENT PATHS
// ============================================================================
/**
 * Every route for one deployment. Without gateways the FP path falls back to
 * starting at the hide area and the SHRL path is left empty. Empty when any of
 * AHA/HA/RL is missing.
 */
export function buildMovementPaths(
  tacticalAreas: TacticalAreas,
  gateways: Gateways | null
): MovementPaths {
  const { ammoArea, hideArea, reloadArea, firePoints } = tacticalAreas;
  if (!ammoArea || !hideArea || !reloadArea) {
    return createEmptyMovementPaths();
  }

  const paths = createEmptyMovementPaths();

  const ammoCenter = calculateSquareCenter(ammoArea);
  const hideCenter = calculateSquareCenter(hideArea);
  const reloadCenter = calculateSquareCenter(reloadArea);

  // HA: reload -> hide, avoid ammo
  paths.HA.waypoints = generatePathWithAvoidance(reloadCenter, hideCenter, [ammoArea]);

  // AHA: reload -> ammo, avoid hide
  paths.AHA.waypoints = generatePathWithAvoidance(reloadCenter, ammoCenter, [hideArea]);

  if (firePoints) {
    // FP: gateway (or hide center fallback) -> fire points. Shelter vehicles
    // prepend their own position, so the shared path must avoid HA and RL.
    const fpOrigin = gateways?.fpGateway ?? hideCenter;
    const fpAvoid = gateways ? [hideArea, reloadArea] : [ammoArea, reloadArea];

    firePoints.forEach((firePoint, index) => {
      const firePointCenter = calculateSquareCenter(firePoint);
      paths.FP[index] = {
        waypoints: generatePathWithAvoidance(fpOrigin, firePointCenter, fpAvoid),
      };
      // RL: fire points -> reload, avoid ammo & hide
      paths.RL[index] = {
        waypoints: generatePathWithAvoidance(firePointCenter, reloadCenter, [ammoArea, hideArea]),
      };
    });
  }

  // SHRL: shelter-gateway -> reload, avoid HA only. The gateway stays in the
  // waypoint list so the approach stays HA-clear.
  if (gateways) {
    paths.SHRL.waypoints = generatePathWithAvoidance(gateways.shrlGateway, reloadCenter, [
      hideArea,
    ]);
  }

  return paths;
}
