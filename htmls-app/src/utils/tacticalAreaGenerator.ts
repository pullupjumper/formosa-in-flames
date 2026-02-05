/**
 * Tactical Area Generator
 * TypeScript port of tacticalAreaGenerator.js
 * Generates U-shaped tactical areas, internal squares, fire points, and movement paths
 */

// ============================================================================
// Types
// ============================================================================

export interface Coordinate {
  latitude: number;
  longitude: number;
}

export interface AreaConfig {
  centerLat: number;
  centerLon: number;
  thickness: number;
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
}

export interface PathConfig {
  centerLat: number;
  centerLon: number;
  width: number;
  height: number;
  thickness: number;
  openingAngle: number;
  ammoArea: Coordinate[];
  hideArea: Coordinate[];
  reloadArea: Coordinate[];
  firePoints?: Coordinate[][];
  avoidanceMargin?: number;
}

export interface GenerateResult {
  uShapeVertices: Coordinate[];
  ammoArea?: Coordinate[];
  hideArea?: Coordinate[];
  reloadArea?: Coordinate[];
  firePoints?: Coordinate[][];
}

export interface PathResult {
  FP: { waypoints: Coordinate[] }[];
  HA: { waypoints: Coordinate[] };
  RL: { waypoints: Coordinate[] }[];
  AHA: { waypoints: Coordinate[] };
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

export function calculateDistance(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const dLat = toRadians(lat2 - lat1);
  const dLon = toRadians(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRadians(lat1)) * Math.cos(toRadians(lat2)) * Math.sin(dLon / 2) * Math.sin(dLon / 2);

  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return EARTH_RADIUS_NM * c;
}

export function calculateBearing(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const dLon = toRadians(lon2 - lon1);
  const lat1Rad = toRadians(lat1);
  const lat2Rad = toRadians(lat2);

  const y = Math.sin(dLon) * Math.cos(lat2Rad);
  const x =
    Math.cos(lat1Rad) * Math.sin(lat2Rad) - Math.sin(lat1Rad) * Math.cos(lat2Rad) * Math.cos(dLon);

  const bearing = toDegrees(Math.atan2(y, x));
  return (bearing + 360) % 360;
}

export function getPointFromBearing(
  lat: number,
  lon: number,
  bearing: number,
  distance: number
): Coordinate {
  const bearingRad = toRadians(bearing);
  const latRad = toRadians(lat);
  const lonRad = toRadians(lon);

  const newLatRad = Math.asin(
    Math.sin(latRad) * Math.cos(distance / EARTH_RADIUS_NM) +
      Math.cos(latRad) * Math.sin(distance / EARTH_RADIUS_NM) * Math.cos(bearingRad)
  );

  const newLonRad =
    lonRad +
    Math.atan2(
      Math.sin(bearingRad) * Math.sin(distance / EARTH_RADIUS_NM) * Math.cos(latRad),
      Math.cos(distance / EARTH_RADIUS_NM) - Math.sin(latRad) * Math.sin(newLatRad)
    );

  return {
    latitude: toDegrees(newLatRad),
    longitude: toDegrees(newLonRad),
  };
}

// ============================================================================
// Helper Functions
// ============================================================================

function generateRandomSquareCenter(
  centerLat: number,
  centerLon: number,
  maxOffsetX: number,
  maxOffsetY: number,
  openingAngle: number
): Coordinate {
  const offsetX = (Math.random() * 2 - 1) * maxOffsetX;
  const offsetY = (Math.random() * 2 - 1) * maxOffsetY;

  const tempPos = getPointFromBearing(centerLat, centerLon, (90 + openingAngle) % 360, offsetX);

  return getPointFromBearing(
    tempPos.latitude,
    tempPos.longitude,
    (180 + openingAngle) % 360,
    offsetY
  );
}

function calculateSquareCenter(vertices: Coordinate[]): Coordinate {
  if (vertices.length !== 4) {
    throw new Error('Square must have exactly 4 vertices');
  }

  let sumLat = 0;
  let sumLon = 0;
  for (const vertex of vertices) {
    sumLat += vertex.latitude;
    sumLon += vertex.longitude;
  }

  return {
    latitude: sumLat / 4,
    longitude: sumLon / 4,
  };
}

function checkSquaresOverlap(
  center1Lat: number,
  center1Lon: number,
  center2Lat: number,
  center2Lon: number,
  squareSize: number,
  margin: number
): boolean {
  const distance = calculateDistance(center1Lat, center1Lon, center2Lat, center2Lon);
  return distance < squareSize + margin;
}

function checkPointInSquare(
  pointLat: number,
  pointLon: number,
  squareCenter: Coordinate,
  squareSize: number,
  margin: number
): boolean {
  const distance = calculateDistance(
    squareCenter.latitude,
    squareCenter.longitude,
    pointLat,
    pointLon
  );
  const halfSize = squareSize / 2 + margin;
  return distance < halfSize;
}

function checkFirePointOverlapsWithUShape(
  squareLat: number,
  squareLon: number,
  centerLat: number,
  centerLon: number,
  uShapeMaxDist: number,
  squareSize: number,
  margin: number
): boolean {
  const distanceToCenter = calculateDistance(centerLat, centerLon, squareLat, squareLon);
  const halfSquare = squareSize / 2;
  const squareDiagonal = Math.sqrt(2) * halfSquare;
  const minSafeDistance = uShapeMaxDist + squareDiagonal + margin;

  return distanceToCenter < minSafeDistance;
}

function generateSquareVertices(
  centerLat: number,
  centerLon: number,
  size: number,
  rotationAngle: number
): Coordinate[] {
  const halfSize = size / 2;
  const diagonalDist = Math.sqrt(2) * halfSize;
  const vertices: Coordinate[] = [];

  const cornerAngles = [45, 135, 225, 315];
  for (const cornerAngle of cornerAngles) {
    const vertex = getPointFromBearing(
      centerLat,
      centerLon,
      (cornerAngle + rotationAngle) % 360,
      diagonalDist
    );
    vertices.push(vertex);
  }

  return vertices;
}

function checkPathIntersectsSquare(
  startLat: number,
  startLon: number,
  endLat: number,
  endLon: number,
  squareVertices: Coordinate[],
  margin: number
): boolean {
  const squareCenter = calculateSquareCenter(squareVertices);

  const dist1 = calculateDistance(
    squareVertices[0].latitude,
    squareVertices[0].longitude,
    squareVertices[1].latitude,
    squareVertices[1].longitude
  );
  const dist2 = calculateDistance(
    squareVertices[1].latitude,
    squareVertices[1].longitude,
    squareVertices[2].latitude,
    squareVertices[2].longitude
  );
  const squareSize = (dist1 + dist2) / 2;

  const numSamples = 10;
  for (let i = 0; i <= numSamples; i++) {
    const t = i / numSamples;
    const sampleLat = startLat + t * (endLat - startLat);
    const sampleLon = startLon + t * (endLon - startLon);

    if (checkPointInSquare(sampleLat, sampleLon, squareCenter, squareSize, margin)) {
      return true;
    }
  }

  return false;
}

function calculateSquareOffsetCorners(squareVertices: Coordinate[], offset: number): Coordinate[] {
  const squareCenter = calculateSquareCenter(squareVertices);
  const offsetCorners: Coordinate[] = [];

  for (const vertex of squareVertices) {
    const bearing = calculateBearing(
      squareCenter.latitude,
      squareCenter.longitude,
      vertex.latitude,
      vertex.longitude
    );

    const offsetDist = offset * 1.2;
    const offsetCorner = getPointFromBearing(
      vertex.latitude,
      vertex.longitude,
      bearing,
      offsetDist
    );
    offsetCorners.push(offsetCorner);
  }

  return offsetCorners;
}

function selectBestAvoidanceCornerPair(
  startLat: number,
  startLon: number,
  endLat: number,
  endLon: number,
  offsetCorners: Coordinate[],
  allSquares: Coordinate[][],
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

    for (const pair of pairs) {
      const [corner1, corner2] = pair;
      let hasCollision = false;

      for (const squareVertices of allSquares) {
        const squareCenter = calculateSquareCenter(squareVertices);
        const dist1 = calculateDistance(
          squareVertices[0].latitude,
          squareVertices[0].longitude,
          squareVertices[1].latitude,
          squareVertices[1].longitude
        );
        const dist2 = calculateDistance(
          squareVertices[1].latitude,
          squareVertices[1].longitude,
          squareVertices[2].latitude,
          squareVertices[2].longitude
        );
        const squareSize = (dist1 + dist2) / 2;

        const startInSquare = checkPointInSquare(startLat, startLon, squareCenter, squareSize, 0);
        const corner1InSquare = checkPointInSquare(
          corner1.latitude,
          corner1.longitude,
          squareCenter,
          squareSize,
          0
        );

        if (
          !startInSquare &&
          !corner1InSquare &&
          checkPathIntersectsSquare(
            startLat,
            startLon,
            corner1.latitude,
            corner1.longitude,
            squareVertices,
            margin
          )
        ) {
          hasCollision = true;
          break;
        }
      }

      if (!hasCollision) {
        for (const squareVertices of allSquares) {
          const squareCenter = calculateSquareCenter(squareVertices);
          const dist1 = calculateDistance(
            squareVertices[0].latitude,
            squareVertices[0].longitude,
            squareVertices[1].latitude,
            squareVertices[1].longitude
          );
          const dist2 = calculateDistance(
            squareVertices[1].latitude,
            squareVertices[1].longitude,
            squareVertices[2].latitude,
            squareVertices[2].longitude
          );
          const squareSize = (dist1 + dist2) / 2;

          const corner1InSquare = checkPointInSquare(
            corner1.latitude,
            corner1.longitude,
            squareCenter,
            squareSize,
            0
          );
          const corner2InSquare = checkPointInSquare(
            corner2.latitude,
            corner2.longitude,
            squareCenter,
            squareSize,
            0
          );

          if (
            !corner1InSquare &&
            !corner2InSquare &&
            checkPathIntersectsSquare(
              corner1.latitude,
              corner1.longitude,
              corner2.latitude,
              corner2.longitude,
              squareVertices,
              margin
            )
          ) {
            hasCollision = true;
            break;
          }
        }
      }

      if (!hasCollision) {
        for (const squareVertices of allSquares) {
          const squareCenter = calculateSquareCenter(squareVertices);
          const dist1 = calculateDistance(
            squareVertices[0].latitude,
            squareVertices[0].longitude,
            squareVertices[1].latitude,
            squareVertices[1].longitude
          );
          const dist2 = calculateDistance(
            squareVertices[1].latitude,
            squareVertices[1].longitude,
            squareVertices[2].latitude,
            squareVertices[2].longitude
          );
          const squareSize = (dist1 + dist2) / 2;

          const corner2InSquare = checkPointInSquare(
            corner2.latitude,
            corner2.longitude,
            squareCenter,
            squareSize,
            0
          );
          const endInSquare = checkPointInSquare(endLat, endLon, squareCenter, squareSize, 0);

          if (
            !corner2InSquare &&
            !endInSquare &&
            checkPathIntersectsSquare(
              corner2.latitude,
              corner2.longitude,
              endLat,
              endLon,
              squareVertices,
              margin
            )
          ) {
            hasCollision = true;
            break;
          }
        }
      }

      if (!hasCollision) {
        const dist1 = calculateDistance(startLat, startLon, corner1.latitude, corner1.longitude);
        const dist2 = calculateDistance(
          corner1.latitude,
          corner1.longitude,
          corner2.latitude,
          corner2.longitude
        );
        const dist3 = calculateDistance(corner2.latitude, corner2.longitude, endLat, endLon);
        const totalDist = dist1 + dist2 + dist3;

        if (totalDist < minDistance) {
          minDistance = totalDist;
          bestPair = [corner1, corner2];
        }
      }
    }
  }

  return bestPair || [null, null];
}

function checkPathIntersectsUShape(
  startLat: number,
  startLon: number,
  endLat: number,
  endLon: number,
  uShapeCenterLat: number,
  uShapeCenterLon: number,
  uShapeMaxDist: number,
  uShapeInnerDist: number,
  openingAngle: number,
  margin: number
): boolean {
  const startDist = calculateDistance(uShapeCenterLat, uShapeCenterLon, startLat, startLon);
  const endDist = calculateDistance(uShapeCenterLat, uShapeCenterLon, endLat, endLon);

  if (startDist < uShapeInnerDist && endDist < uShapeInnerDist) {
    return false;
  }

  if (startDist > uShapeMaxDist + margin && endDist > uShapeMaxDist + margin) {
    return false;
  }

  if (
    (startDist > uShapeInnerDist && endDist < uShapeInnerDist) ||
    (startDist < uShapeInnerDist && endDist > uShapeInnerDist)
  ) {
    let outsideLat = startLat;
    let outsideLon = startLon;
    if (endDist > startDist) {
      outsideLat = endLat;
      outsideLon = endLon;
    }

    const bearingToOutside = calculateBearing(
      uShapeCenterLat,
      uShapeCenterLon,
      outsideLat,
      outsideLon
    );

    let angleDiff = (bearingToOutside - openingAngle + 360) % 360;
    if (angleDiff > 180) {
      angleDiff = angleDiff - 360;
    }

    if (Math.abs(angleDiff) <= 90) {
      return false;
    }

    return true;
  }

  const numSamples = 10;
  for (let i = 0; i <= numSamples; i++) {
    const t = i / numSamples;
    const sampleLat = startLat + t * (endLat - startLat);
    const sampleLon = startLon + t * (endLon - startLon);
    const sampleDist = calculateDistance(uShapeCenterLat, uShapeCenterLon, sampleLat, sampleLon);

    if (sampleDist > uShapeInnerDist && sampleDist < uShapeMaxDist + margin) {
      return true;
    }
  }

  return false;
}

interface OutlineCorners {
  topRight: Coordinate;
  topLeft: Coordinate;
  bottomRight: Coordinate;
  bottomLeft: Coordinate;
  innerTopRight: Coordinate;
  innerTopLeft: Coordinate;
}

function calculateOutlineCorners(
  uShapeCenterLat: number,
  uShapeCenterLon: number,
  width: number,
  height: number,
  thickness: number,
  openingAngle: number,
  offset: number
): OutlineCorners {
  const halfWidth = width / 2;
  const halfHeight = height / 2;
  const outerDiagonalDist = Math.sqrt(halfWidth * halfWidth + halfHeight * halfHeight);
  const outerBaseAngle = toDegrees(Math.atan2(halfWidth, halfHeight));

  const outerTopRight = getPointFromBearing(
    uShapeCenterLat,
    uShapeCenterLon,
    (openingAngle + outerBaseAngle) % 360,
    outerDiagonalDist
  );

  const outerTopLeft = getPointFromBearing(
    uShapeCenterLat,
    uShapeCenterLon,
    (openingAngle - outerBaseAngle + 360) % 360,
    outerDiagonalDist
  );

  const outerHalfWidthOffset = halfWidth + offset;
  const outerHalfHeightOffset = halfHeight + offset;
  const outerDiagonalDistOffset = Math.sqrt(
    outerHalfWidthOffset * outerHalfWidthOffset + outerHalfHeightOffset * outerHalfHeightOffset
  );
  const outerBaseAngleOffset = toDegrees(Math.atan2(outerHalfWidthOffset, outerHalfHeightOffset));

  const corners: OutlineCorners = {
    topRight: getPointFromBearing(
      uShapeCenterLat,
      uShapeCenterLon,
      (openingAngle + outerBaseAngleOffset) % 360,
      outerDiagonalDistOffset
    ),
    topLeft: getPointFromBearing(
      uShapeCenterLat,
      uShapeCenterLon,
      (openingAngle - outerBaseAngleOffset + 360) % 360,
      outerDiagonalDistOffset
    ),
    bottomRight: getPointFromBearing(
      uShapeCenterLat,
      uShapeCenterLon,
      (openingAngle + 180 - outerBaseAngleOffset) % 360,
      outerDiagonalDistOffset
    ),
    bottomLeft: getPointFromBearing(
      uShapeCenterLat,
      uShapeCenterLon,
      (openingAngle + 180 + outerBaseAngleOffset) % 360,
      outerDiagonalDistOffset
    ),
    innerTopRight: { latitude: 0, longitude: 0 },
    innerTopLeft: { latitude: 0, longitude: 0 },
  };

  const innerTopRightBase = getPointFromBearing(
    outerTopRight.latitude,
    outerTopRight.longitude,
    (270 + openingAngle) % 360,
    thickness
  );

  const innerTopLeftBase = getPointFromBearing(
    outerTopLeft.latitude,
    outerTopLeft.longitude,
    (90 + openingAngle) % 360,
    thickness
  );

  const offsetDiagonal = offset * Math.sqrt(2);

  corners.innerTopRight = getPointFromBearing(
    innerTopRightBase.latitude,
    innerTopRightBase.longitude,
    (openingAngle - 45 + 360) % 360,
    offsetDiagonal
  );

  corners.innerTopLeft = getPointFromBearing(
    innerTopLeftBase.latitude,
    innerTopLeftBase.longitude,
    (openingAngle + 45) % 360,
    offsetDiagonal
  );

  return corners;
}

function generatePathWithAvoidance(
  startLat: number,
  startLon: number,
  endLat: number,
  endLon: number,
  uShapeCenterLat: number,
  uShapeCenterLon: number,
  uShapeMaxDist: number,
  uShapeInnerDist: number,
  openingAngle: number,
  avoidanceMargin: number,
  _avoidanceDistance: number,
  width: number,
  height: number,
  thickness: number,
  internalSquares: {
    ammoArea: Coordinate[];
    hideArea: Coordinate[];
    reloadArea: Coordinate[];
  } | null
): Coordinate[] {
  const waypoints: Coordinate[] = [];

  waypoints.push({
    latitude: startLat,
    longitude: startLon,
  });

  const intersectsUShape = checkPathIntersectsUShape(
    startLat,
    startLon,
    endLat,
    endLon,
    uShapeCenterLat,
    uShapeCenterLon,
    uShapeMaxDist,
    uShapeInnerDist,
    openingAngle,
    avoidanceMargin
  );

  if (intersectsUShape) {
    const corners = calculateOutlineCorners(
      uShapeCenterLat,
      uShapeCenterLon,
      width,
      height,
      thickness,
      openingAngle,
      avoidanceMargin
    );

    const startDist = calculateDistance(uShapeCenterLat, uShapeCenterLon, startLat, startLon);
    // const endDist = calculateDistance(uShapeCenterLat, uShapeCenterLon, endLat, endLon);
    const startInside = startDist < uShapeInnerDist;

    const bearingToStart = calculateBearing(uShapeCenterLat, uShapeCenterLon, startLat, startLon);
    const bearingToEnd = calculateBearing(uShapeCenterLat, uShapeCenterLon, endLat, endLon);

    const normalizedOpening = openingAngle % 360;
    const normalizedStart = bearingToStart % 360;
    const normalizedEnd = bearingToEnd % 360;
    const angleDiffStart = ((normalizedStart - normalizedOpening + 180) % 360) - 180;
    const angleDiffEnd = ((normalizedEnd - normalizedOpening + 180) % 360) - 180;

    let angleDiff: number;
    let useRightPath: boolean;
    if (!startInside) {
      angleDiff = angleDiffStart;
      useRightPath = angleDiff > 0;
    } else {
      angleDiff = angleDiffEnd;
      useRightPath = angleDiff > 0;
    }

    const cornerSequence: Coordinate[] = [];

    if (!startInside) {
      if (angleDiff > 90 && angleDiff <= 135) {
        cornerSequence.push(corners.bottomRight);
        cornerSequence.push(corners.topRight);
      } else if (angleDiff > 135) {
        if (angleDiff > 170) {
          cornerSequence.push(corners.bottomLeft);
        }
        cornerSequence.push(corners.bottomRight);
        cornerSequence.push(corners.topRight);
      } else if (angleDiff < -135) {
        if (angleDiff < -170) {
          cornerSequence.push(corners.bottomRight);
        }
        cornerSequence.push(corners.bottomLeft);
        cornerSequence.push(corners.topLeft);
      } else if (angleDiff < -90 && angleDiff >= -135) {
        cornerSequence.push(corners.bottomLeft);
        cornerSequence.push(corners.topLeft);
      }
      if (useRightPath) {
        cornerSequence.push(corners.innerTopRight);
      } else {
        cornerSequence.push(corners.innerTopLeft);
      }
    } else {
      if (useRightPath) {
        cornerSequence.push(corners.innerTopRight);
      } else {
        cornerSequence.push(corners.innerTopLeft);
      }

      if (angleDiff > 90 && angleDiff <= 135) {
        cornerSequence.push(corners.topRight);
      } else if (angleDiff > 135) {
        cornerSequence.push(corners.topRight);
        cornerSequence.push(corners.bottomRight);
        if (angleDiff > 170) {
          cornerSequence.push(corners.bottomLeft);
        }
      } else if (angleDiff < -135) {
        cornerSequence.push(corners.topLeft);
        cornerSequence.push(corners.bottomLeft);
        if (angleDiff < -170) {
          cornerSequence.push(corners.bottomRight);
        }
      } else if (angleDiff < -90 && angleDiff >= -135) {
        cornerSequence.push(corners.topLeft);
      }
    }

    for (const corner of cornerSequence) {
      waypoints.push({
        latitude: corner.latitude,
        longitude: corner.longitude,
      });
    }
  }

  waypoints.push({
    latitude: endLat,
    longitude: endLon,
  });

  if (internalSquares) {
    const internalAreas = [
      internalSquares.ammoArea,
      internalSquares.hideArea,
      internalSquares.reloadArea,
    ];
    const maxIterations = 20;
    let modified = true;
    let iteration = 0;

    while (modified && iteration < maxIterations) {
      modified = false;
      iteration++;

      for (let i = 0; i < waypoints.length - 1; i++) {
        const segStart = waypoints[i];
        const segEnd = waypoints[i + 1];

        for (let squareIdx = 0; squareIdx < internalAreas.length; squareIdx++) {
          const squareVertices = internalAreas[squareIdx];
          const squareCenter = calculateSquareCenter(squareVertices);
          const dist1 = calculateDistance(
            squareVertices[0].latitude,
            squareVertices[0].longitude,
            squareVertices[1].latitude,
            squareVertices[1].longitude
          );
          const dist2 = calculateDistance(
            squareVertices[1].latitude,
            squareVertices[1].longitude,
            squareVertices[2].latitude,
            squareVertices[2].longitude
          );
          const squareSize = (dist1 + dist2) / 2;

          const startInSquare = checkPointInSquare(
            segStart.latitude,
            segStart.longitude,
            squareCenter,
            squareSize,
            0
          );
          const endInSquare = checkPointInSquare(
            segEnd.latitude,
            segEnd.longitude,
            squareCenter,
            squareSize,
            0
          );

          if (
            !startInSquare &&
            !endInSquare &&
            checkPathIntersectsSquare(
              segStart.latitude,
              segStart.longitude,
              segEnd.latitude,
              segEnd.longitude,
              squareVertices,
              avoidanceMargin
            )
          ) {
            let corner1: Coordinate | null = null;
            let corner2: Coordinate | null = null;
            const offsetMultipliers = [2.0, 2.5, 3.0, 3.5, 4.0, 5.0];

            const otherSquares: Coordinate[][] = [];
            for (let idx = 0; idx < internalAreas.length; idx++) {
              if (idx !== squareIdx) {
                otherSquares.push(internalAreas[idx]);
              }
            }

            for (const multiplier of offsetMultipliers) {
              const offsetDist = avoidanceMargin * multiplier;
              const offsetCorners = calculateSquareOffsetCorners(squareVertices, offsetDist);

              [corner1, corner2] = selectBestAvoidanceCornerPair(
                segStart.latitude,
                segStart.longitude,
                segEnd.latitude,
                segEnd.longitude,
                offsetCorners,
                otherSquares,
                avoidanceMargin
              );

              if (corner1 && corner2) {
                break;
              }
            }

            if (corner1 && corner2) {
              waypoints.splice(i + 1, 0, {
                latitude: corner1.latitude,
                longitude: corner1.longitude,
              });
              waypoints.splice(i + 2, 0, {
                latitude: corner2.latitude,
                longitude: corner2.longitude,
              });

              modified = true;
              break;
            }
          }
        }

        if (modified) {
          break;
        }
      }
    }
  }

  return waypoints;
}

function generateInternalSquares(
  innerCorners: Coordinate[],
  openingAngle: number,
  squareSize: number,
  innerWidth: number,
  innerHeight: number,
  marginToWall = 0.1,
  marginBetweenSquares = 0.1
): { ammoArea: Coordinate[]; hideArea: Coordinate[]; reloadArea: Coordinate[] } {
  const maxAttempts = 100;
  const halfSquare = squareSize / 2;

  const centerLat =
    (innerCorners[0].latitude +
      innerCorners[1].latitude +
      innerCorners[2].latitude +
      innerCorners[3].latitude) /
    4;
  const centerLon =
    (innerCorners[0].longitude +
      innerCorners[1].longitude +
      innerCorners[2].longitude +
      innerCorners[3].longitude) /
    4;

  const maxOffsetX = innerWidth / 2 - halfSquare - marginToWall;
  const maxOffsetY = innerHeight / 2 - halfSquare - marginToWall;

  if (maxOffsetX <= 0 || maxOffsetY <= 0) {
    console.error(
      `Square size (${squareSize} nm) too large for internal area (${innerWidth} x ${innerHeight} nm)`
    );
    return {
      ammoArea: [],
      hideArea: [],
      reloadArea: [],
    };
  }

  const centers: Coordinate[] = [];
  const areaNames = ['ammoArea', 'hideArea', 'reloadArea'];

  for (let i = 0; i < 3; i++) {
    let validCenter = false;
    let attempts = 0;

    while (!validCenter && attempts < maxAttempts) {
      attempts++;
      const candidate = generateRandomSquareCenter(
        centerLat,
        centerLon,
        maxOffsetX,
        maxOffsetY,
        openingAngle
      );

      let overlap = false;
      for (const existingCenter of centers) {
        if (
          checkSquaresOverlap(
            candidate.latitude,
            candidate.longitude,
            existingCenter.latitude,
            existingCenter.longitude,
            squareSize,
            marginBetweenSquares
          )
        ) {
          overlap = true;
          break;
        }
      }

      if (!overlap) {
        centers.push(candidate);
        validCenter = true;
      }
    }

    if (!validCenter) {
      console.error(`Failed to place ${areaNames[i]} after ${maxAttempts} attempts`);
    }
  }

  return {
    ammoArea: generateSquareVertices(
      centers[0].latitude,
      centers[0].longitude,
      squareSize,
      openingAngle
    ),
    hideArea: generateSquareVertices(
      centers[1].latitude,
      centers[1].longitude,
      squareSize,
      openingAngle
    ),
    reloadArea: generateSquareVertices(
      centers[2].latitude,
      centers[2].longitude,
      squareSize,
      openingAngle
    ),
  };
}

function generateFirePoints(
  centerLat: number,
  centerLon: number,
  radius: number,
  squareSize: number,
  count: number,
  angleRange: number,
  openingAngle: number,
  margin: number,
  _uShapeVertices: Coordinate[],
  uShapeWidth: number,
  uShapeHeight: number
): Coordinate[][] {
  const firePoints: { center: Coordinate; vertices: Coordinate[] }[] = [];
  const maxAttempts = 200;

  const uShapeMaxDist = Math.sqrt((uShapeWidth / 2) ** 2 + (uShapeHeight / 2) ** 2);
  const startAngle = openingAngle + 180 - angleRange / 2;

  for (let i = 0; i < count; i++) {
    let validPosition = false;
    let attempts = 0;

    while (!validPosition && attempts < maxAttempts) {
      attempts++;

      const randomAngle = (startAngle + Math.random() * angleRange) % 360;
      const candidate = getPointFromBearing(centerLat, centerLon, randomAngle, radius);

      let valid = true;

      if (
        checkFirePointOverlapsWithUShape(
          candidate.latitude,
          candidate.longitude,
          centerLat,
          centerLon,
          uShapeMaxDist,
          squareSize,
          margin
        )
      ) {
        valid = false;
      }

      if (valid) {
        for (const existingFirePoint of firePoints) {
          if (
            checkSquaresOverlap(
              candidate.latitude,
              candidate.longitude,
              existingFirePoint.center.latitude,
              existingFirePoint.center.longitude,
              squareSize,
              margin
            )
          ) {
            valid = false;
            break;
          }
        }
      }

      if (valid) {
        const bearingToCenter = calculateBearing(
          candidate.latitude,
          candidate.longitude,
          centerLat,
          centerLon
        );

        const vertices = generateSquareVertices(
          candidate.latitude,
          candidate.longitude,
          squareSize,
          bearingToCenter
        );

        firePoints.push({
          center: candidate,
          vertices: vertices,
        });
        validPosition = true;
      }
    }

    if (!validPosition) {
      console.error(`Failed to place fire point ${i + 1}/${count} after ${maxAttempts} attempts`);
    }
  }

  return firePoints.map((fp) => fp.vertices);
}

// ============================================================================
// Public API Functions
// ============================================================================

export function generateUShapeVertices(areaConfig: AreaConfig): GenerateResult {
  if (!areaConfig.centerLat) throw new Error('config.centerLat is required');
  if (!areaConfig.centerLon) throw new Error('config.centerLon is required');
  if (!areaConfig.thickness) throw new Error('config.thickness is required');
  if (!areaConfig.width) throw new Error('config.width is required');
  if (!areaConfig.height) throw new Error('config.height is required');
  if (areaConfig.openingAngle === undefined) throw new Error('config.openingAngle is required');

  const result: GenerateResult = {
    uShapeVertices: [],
  };
  const vertices: Coordinate[] = [];

  const { centerLat, centerLon, thickness, width, height, openingAngle } = areaConfig;

  const halfWidth = width / 2;
  const halfHeight = height / 2;

  const outerDiagonalDist = Math.sqrt(halfWidth * halfWidth + halfHeight * halfHeight);
  const baseAngle = toDegrees(Math.atan2(halfWidth, halfHeight));

  const outerAngles = [360 - baseAngle, baseAngle, 180 - baseAngle, 180 + baseAngle];

  const outerCorners: Coordinate[] = [];
  for (let i = 0; i < 4; i++) {
    outerCorners[i] = getPointFromBearing(
      centerLat,
      centerLon,
      (outerAngles[i] + openingAngle) % 360,
      outerDiagonalDist
    );
  }

  const innerCorners: Coordinate[] = [];

  innerCorners[0] = getPointFromBearing(
    outerCorners[0].latitude,
    outerCorners[0].longitude,
    (90 + openingAngle) % 360,
    thickness
  );

  innerCorners[1] = getPointFromBearing(
    outerCorners[1].latitude,
    outerCorners[1].longitude,
    (270 + openingAngle) % 360,
    thickness
  );

  innerCorners[2] = getPointFromBearing(
    innerCorners[1].latitude,
    innerCorners[1].longitude,
    (180 + openingAngle) % 360,
    height - thickness
  );

  innerCorners[3] = getPointFromBearing(
    innerCorners[0].latitude,
    innerCorners[0].longitude,
    (180 + openingAngle) % 360,
    height - thickness
  );

  vertices.push(outerCorners[3]);
  vertices.push(outerCorners[2]);
  vertices.push(outerCorners[1]);
  vertices.push(innerCorners[1]);
  vertices.push(innerCorners[2]);
  vertices.push(innerCorners[3]);
  vertices.push(innerCorners[0]);
  vertices.push(outerCorners[0]);

  result.uShapeVertices = vertices;

  if (areaConfig.internalSquares) {
    const internalSquares = generateInternalSquares(
      innerCorners,
      openingAngle,
      areaConfig.internalSquares.size,
      width - 2 * thickness,
      height - thickness,
      areaConfig.internalSquares.marginToWall,
      areaConfig.internalSquares.marginBetweenSquares
    );

    result.ammoArea = internalSquares.ammoArea;
    result.hideArea = internalSquares.hideArea;
    result.reloadArea = internalSquares.reloadArea;
  }

  if (areaConfig.firePoints) {
    result.firePoints = generateFirePoints(
      centerLat,
      centerLon,
      areaConfig.firePoints.radius,
      areaConfig.firePoints.squareSize,
      areaConfig.firePoints.count,
      areaConfig.firePoints.angleRange || 360,
      openingAngle,
      areaConfig.firePoints.margin || 0.1,
      vertices,
      width,
      height
    );
  }

  return result;
}

export function calculateMovementPaths(pathConfig: PathConfig): PathResult {
  if (!pathConfig.centerLat) throw new Error('config.centerLat is required');
  if (!pathConfig.centerLon) throw new Error('config.centerLon is required');
  if (!pathConfig.width) throw new Error('config.width is required');
  if (!pathConfig.height) throw new Error('config.height is required');
  if (!pathConfig.thickness) throw new Error('config.thickness is required');
  if (pathConfig.openingAngle === undefined) throw new Error('config.openingAngle is required');
  if (!pathConfig.ammoArea) throw new Error('config.ammoArea is required');
  if (!pathConfig.hideArea) throw new Error('config.hideArea is required');
  if (!pathConfig.reloadArea) throw new Error('config.reloadArea is required');

  const avoidanceMargin = pathConfig.avoidanceMargin || 0.3;
  const paths: PathResult = {
    FP: [],
    HA: { waypoints: [] },
    RL: [],
    AHA: { waypoints: [] },
  };

  const uShapeMaxDist = Math.sqrt((pathConfig.width / 2) ** 2 + (pathConfig.height / 2) ** 2);
  const avoidanceDistance = uShapeMaxDist + avoidanceMargin + 0.5;

  const innerWidth = pathConfig.width - 2 * pathConfig.thickness;
  const innerHeight = pathConfig.height - pathConfig.thickness;
  const uShapeInnerDist = Math.sqrt((innerWidth / 2) ** 2 + (innerHeight / 2) ** 2);

  const ammoCtr = calculateSquareCenter(pathConfig.ammoArea);
  const hideCtr = calculateSquareCenter(pathConfig.hideArea);
  const reloadCtr = calculateSquareCenter(pathConfig.reloadArea);

  const internalSquares = {
    ammoArea: pathConfig.ammoArea,
    hideArea: pathConfig.hideArea,
    reloadArea: pathConfig.reloadArea,
  };

  paths.HA.waypoints = generatePathWithAvoidance(
    reloadCtr.latitude,
    reloadCtr.longitude,
    hideCtr.latitude,
    hideCtr.longitude,
    pathConfig.centerLat,
    pathConfig.centerLon,
    uShapeMaxDist,
    uShapeInnerDist,
    pathConfig.openingAngle,
    avoidanceMargin,
    avoidanceDistance,
    pathConfig.width,
    pathConfig.height,
    pathConfig.thickness,
    null
  );

  paths.AHA.waypoints = generatePathWithAvoidance(
    reloadCtr.latitude,
    reloadCtr.longitude,
    ammoCtr.latitude,
    ammoCtr.longitude,
    pathConfig.centerLat,
    pathConfig.centerLon,
    uShapeMaxDist,
    uShapeInnerDist,
    pathConfig.openingAngle,
    avoidanceMargin,
    avoidanceDistance,
    pathConfig.width,
    pathConfig.height,
    pathConfig.thickness,
    null
  );

  if (pathConfig.firePoints) {
    for (let i = 0; i < pathConfig.firePoints.length; i++) {
      const firePoint = pathConfig.firePoints[i];
      const fpCtr = calculateSquareCenter(firePoint);
      paths.FP[i] = {
        waypoints: generatePathWithAvoidance(
          hideCtr.latitude,
          hideCtr.longitude,
          fpCtr.latitude,
          fpCtr.longitude,
          pathConfig.centerLat,
          pathConfig.centerLon,
          uShapeMaxDist,
          uShapeInnerDist,
          pathConfig.openingAngle,
          avoidanceMargin,
          avoidanceDistance,
          pathConfig.width,
          pathConfig.height,
          pathConfig.thickness,
          internalSquares
        ),
      };
    }
  }

  if (pathConfig.firePoints) {
    for (let i = 0; i < pathConfig.firePoints.length; i++) {
      const firePoint = pathConfig.firePoints[i];
      const fpCtr = calculateSquareCenter(firePoint);
      paths.RL[i] = {
        waypoints: generatePathWithAvoidance(
          fpCtr.latitude,
          fpCtr.longitude,
          reloadCtr.latitude,
          reloadCtr.longitude,
          pathConfig.centerLat,
          pathConfig.centerLon,
          uShapeMaxDist,
          uShapeInnerDist,
          pathConfig.openingAngle,
          avoidanceMargin,
          avoidanceDistance,
          pathConfig.width,
          pathConfig.height,
          pathConfig.thickness,
          internalSquares
        ),
      };
    }
  }

  return paths;
}
