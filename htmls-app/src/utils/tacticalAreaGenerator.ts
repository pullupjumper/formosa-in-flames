/**
 * Tactical Area Generator
 * Generates rectangular boundary areas, internal squares, fire points, and movement paths
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
    center?: { latitude: number; longitude: number };
  };
}

export interface PathConfig {
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

export function checkSquaresOverlap(
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

// ============================================================================
// Path Generation (avoid other position squares only)
// ============================================================================

function generatePathWithAvoidance(
  startLat: number,
  startLon: number,
  endLat: number,
  endLon: number,
  avoidanceMargin: number,
  avoidSquares: Coordinate[][]
): Coordinate[] {
  const waypoints: Coordinate[] = [
    { latitude: startLat, longitude: startLon },
    { latitude: endLat, longitude: endLon },
  ];

  if (avoidSquares.length === 0) return waypoints;

  const maxIterations = 20;
  let modified = true;
  let iteration = 0;

  while (modified && iteration < maxIterations) {
    modified = false;
    iteration++;

    for (let i = 0; i < waypoints.length - 1; i++) {
      const segStart = waypoints[i];
      const segEnd = waypoints[i + 1];

      for (let squareIdx = 0; squareIdx < avoidSquares.length; squareIdx++) {
        const squareVertices = avoidSquares[squareIdx];
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
          for (let idx = 0; idx < avoidSquares.length; idx++) {
            if (idx !== squareIdx) {
              otherSquares.push(avoidSquares[idx]);
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
  marginToWall = 0.1,
  marginBetweenSquares = 0.1
): { hideArea: Coordinate[]; reloadArea: Coordinate[] } {
  const maxAttempts = 100;
  const halfSquare = squareSize / 2;

  const centerLat =
    (boundaryCorners[0].latitude +
      boundaryCorners[1].latitude +
      boundaryCorners[2].latitude +
      boundaryCorners[3].latitude) /
    4;
  const centerLon =
    (boundaryCorners[0].longitude +
      boundaryCorners[1].longitude +
      boundaryCorners[2].longitude +
      boundaryCorners[3].longitude) /
    4;

  const maxOffsetX = areaWidth / 2 - halfSquare - marginToWall;
  const maxOffsetY = areaHeight / 2 - halfSquare - marginToWall;

  if (maxOffsetX <= 0 || maxOffsetY <= 0) {
    console.error(
      `Square size (${squareSize} nm) too large for boundary area (${areaWidth} x ${areaHeight} nm)`
    );
    return {
      hideArea: [],
      reloadArea: [],
    };
  }

  const centers: Coordinate[] = [];
  const areaNames = ['hideArea', 'reloadArea'];

  for (let i = 0; i < 2; i++) {
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

  const safeVertices = (index: number): Coordinate[] =>
    centers[index]
      ? generateSquareVertices(
          centers[index].latitude,
          centers[index].longitude,
          squareSize,
          openingAngle
        )
      : [];

  return {
    hideArea: safeVertices(0),
    reloadArea: safeVertices(1),
  };
}

function generateAhaPosition(
  centerLat: number,
  centerLon: number,
  radius: number,
  squareSize: number,
  openingAngle: number,
  customCenter?: { latitude: number; longitude: number }
): Coordinate[] {
  if (customCenter) {
    const bearingToCenter = calculateBearing(
      customCenter.latitude,
      customCenter.longitude,
      centerLat,
      centerLon
    );
    return generateSquareVertices(
      customCenter.latitude,
      customCenter.longitude,
      squareSize,
      bearingToCenter
    );
  }
  const ahaCenter = getPointFromBearing(centerLat, centerLon, openingAngle, radius);
  return generateSquareVertices(ahaCenter.latitude, ahaCenter.longitude, squareSize, openingAngle);
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
  boundaryWidth: number,
  boundaryHeight: number
): Coordinate[][] {
  const firePoints: { center: Coordinate; vertices: Coordinate[] }[] = [];
  const maxAttempts = 200;

  const boundaryMaxDist = Math.sqrt((boundaryWidth / 2) ** 2 + (boundaryHeight / 2) ** 2);
  const startAngle = openingAngle + 180 - angleRange / 2;

  for (let i = 0; i < count; i++) {
    let validPosition = false;
    let attempts = 0;

    while (!validPosition && attempts < maxAttempts) {
      attempts++;

      const randomAngle = (startAngle + Math.random() * angleRange) % 360;
      const candidate = getPointFromBearing(centerLat, centerLon, randomAngle, radius);

      let valid = true;

      // Ensure fire point is outside the boundary rectangle
      const distanceToCenter = calculateDistance(
        centerLat,
        centerLon,
        candidate.latitude,
        candidate.longitude
      );
      const halfSquare = squareSize / 2;
      const squareDiagonal = Math.sqrt(2) * halfSquare;
      const minSafeDistance = boundaryMaxDist + squareDiagonal + margin;

      if (distanceToCenter < minSafeDistance) {
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

export function generateSquareVerticesPublic(
  centerLat: number,
  centerLon: number,
  size: number,
  rotationAngle: number
): Coordinate[] {
  return generateSquareVertices(centerLat, centerLon, size, rotationAngle);
}

// ============================================================================
// Public API Functions
// ============================================================================

export function generateUShapeVertices(areaConfig: AreaConfig): GenerateResult {
  if (!areaConfig.centerLat) throw new Error('config.centerLat is required');
  if (!areaConfig.centerLon) throw new Error('config.centerLon is required');
  if (!areaConfig.width) throw new Error('config.width is required');
  if (!areaConfig.height) throw new Error('config.height is required');
  if (areaConfig.openingAngle === undefined) throw new Error('config.openingAngle is required');

  const result: GenerateResult = {
    uShapeVertices: [],
  };

  const { centerLat, centerLon, width, height, openingAngle } = areaConfig;

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

  // Boundary is a simple quadrilateral (4 vertices)
  result.uShapeVertices = [outerCorners[0], outerCorners[1], outerCorners[2], outerCorners[3]];

  if (areaConfig.internalSquares) {
    const internalSquares = generateInternalSquares(
      outerCorners,
      openingAngle,
      areaConfig.internalSquares.size,
      width,
      height,
      areaConfig.internalSquares.marginToWall,
      areaConfig.internalSquares.marginBetweenSquares
    );

    result.hideArea = internalSquares.hideArea;
    result.reloadArea = internalSquares.reloadArea;
  }

  if (areaConfig.ahaPoint) {
    result.ammoArea = generateAhaPosition(
      centerLat,
      centerLon,
      areaConfig.ahaPoint.radius,
      areaConfig.ahaPoint.squareSize,
      openingAngle,
      areaConfig.ahaPoint.center
    );
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
      width,
      height
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
  };

  const ammoCtr = calculateSquareCenter(pathConfig.ammoArea);
  const hideCtr = calculateSquareCenter(pathConfig.hideArea);
  const reloadCtr = calculateSquareCenter(pathConfig.reloadArea);

  // HA: reload -> hide, avoid ammo
  paths.HA.waypoints = generatePathWithAvoidance(
    reloadCtr.latitude,
    reloadCtr.longitude,
    hideCtr.latitude,
    hideCtr.longitude,
    avoidanceMargin,
    [pathConfig.ammoArea]
  );

  // AHA: reload -> ammo, avoid hide
  paths.AHA.waypoints = generatePathWithAvoidance(
    reloadCtr.latitude,
    reloadCtr.longitude,
    ammoCtr.latitude,
    ammoCtr.longitude,
    avoidanceMargin,
    [pathConfig.hideArea]
  );

  // FP: hide -> fire points, avoid ammo & reload
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
          avoidanceMargin,
          [pathConfig.ammoArea, pathConfig.reloadArea]
        ),
      };
    }
  }

  // RL: fire points -> reload, avoid ammo & hide
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
          avoidanceMargin,
          [pathConfig.ammoArea, pathConfig.hideArea]
        ),
      };
    }
  }

  return paths;
}
