/**
 * Tactical Area Generator
 * JavaScript port of tacticalAreaGenerator.lua
 * Generates U-shaped tactical areas, internal squares, fire points, and movement paths
 */

const TacticalAreaGenerator = (() => {
  'use strict';

  // ============================================================================
  // Geographic Calculation Utilities
  // ============================================================================

  /**
   * Calculate distance between two points using Haversine formula
   * @param {number} lat1 - First point latitude
   * @param {number} lon1 - First point longitude
   * @param {number} lat2 - Second point latitude
   * @param {number} lon2 - Second point longitude
   * @returns {number} Distance in nautical miles
   */
  function calculateDistance(lat1, lon1, lat2, lon2) {
    const R = 3440.065; // Earth radius in nautical miles
    const dLat = toRadians(lat2 - lat1);
    const dLon = toRadians(lon2 - lon1);
    const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
              Math.cos(toRadians(lat1)) * Math.cos(toRadians(lat2)) *
              Math.sin(dLon / 2) * Math.sin(dLon / 2);

    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return R * c;
  }

  /**
   * Calculate bearing from point1 to point2
   * @param {number} lat1 - First point latitude
   * @param {number} lon1 - First point longitude
   * @param {number} lat2 - Second point latitude
   * @param {number} lon2 - Second point longitude
   * @returns {number} Bearing in degrees (0-360)
   */
  function calculateBearing(lat1, lon1, lat2, lon2) {
    const dLon = toRadians(lon2 - lon1);
    const lat1Rad = toRadians(lat1);
    const lat2Rad = toRadians(lat2);

    const y = Math.sin(dLon) * Math.cos(lat2Rad);
    const x = Math.cos(lat1Rad) * Math.sin(lat2Rad) -
              Math.sin(lat1Rad) * Math.cos(lat2Rad) * Math.cos(dLon);

    const bearing = toDegrees(Math.atan2(y, x));
    return (bearing + 360) % 360;
  }

  /**
   * Get point from bearing and distance
   * @param {number} lat - Starting latitude
   * @param {number} lon - Starting longitude
   * @param {number} bearing - Bearing in degrees
   * @param {number} distance - Distance in nautical miles
   * @returns {{latitude: number, longitude: number}} New point
   */
  function getPointFromBearing(lat, lon, bearing, distance) {
    const R = 3440.065; // Earth radius in nautical miles
    const bearingRad = toRadians(bearing);
    const latRad = toRadians(lat);
    const lonRad = toRadians(lon);

    const newLatRad = Math.asin(
      Math.sin(latRad) * Math.cos(distance / R) +
      Math.cos(latRad) * Math.sin(distance / R) * Math.cos(bearingRad)
    );

    const newLonRad = lonRad + Math.atan2(
      Math.sin(bearingRad) * Math.sin(distance / R) * Math.cos(latRad),
      Math.cos(distance / R) - Math.sin(latRad) * Math.sin(newLatRad)
    );

    return {
      latitude: toDegrees(newLatRad),
      longitude: toDegrees(newLonRad)
    };
  }

  /**
   * Convert degrees to radians
   */
  function toRadians(degrees) {
    return degrees * Math.PI / 180;
  }

  /**
   * Convert radians to degrees
   */
  function toDegrees(radians) {
    return radians * 180 / Math.PI;
  }

  // ============================================================================
  // Helper Functions
  // ============================================================================

  /**
   * Generate a random square center within valid bounds of internal rectangle
   */
  function generateRandomSquareCenter(centerLat, centerLon, maxOffsetX, maxOffsetY, openingAngle) {
    const offsetX = (Math.random() * 2 - 1) * maxOffsetX;
    const offsetY = (Math.random() * 2 - 1) * maxOffsetY;

    const tempPos = getPointFromBearing(
      centerLat, centerLon,
      (90 + openingAngle) % 360,
      offsetX
    );

    return getPointFromBearing(
      tempPos.latitude, tempPos.longitude,
      (180 + openingAngle) % 360,
      offsetY
    );
  }

  /**
   * Calculate center point of square from four vertices
   */
  function calculateSquareCenter(vertices) {
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
      longitude: sumLon / 4
    };
  }

  /**
   * Check if two squares overlap based on center distance and size
   */
  function checkSquaresOverlap(center1Lat, center1Lon, center2Lat, center2Lon, squareSize, margin) {
    const distance = calculateDistance(center1Lat, center1Lon, center2Lat, center2Lon);
    return distance < (squareSize + margin);
  }

  /**
   * Check if a point is inside a square
   */
  function checkPointInSquare(pointLat, pointLon, squareCenter, squareSize, margin) {
    const distance = calculateDistance(squareCenter.latitude, squareCenter.longitude, pointLat, pointLon);
    const halfDiagonal = Math.sqrt(2) * (squareSize / 2 + margin);

    if (distance >= halfDiagonal) {
      return false;
    }

    const halfSize = squareSize / 2 + margin;
    return distance < halfSize;
  }

  /**
   * Check if a fire point square overlaps with U-shape bounding box
   */
  function checkFirePointOverlapsWithUShape(squareLat, squareLon, centerLat, centerLon, uShapeMaxDist, squareSize, margin) {
    const distanceToCenter = calculateDistance(centerLat, centerLon, squareLat, squareLon);
    const halfSquare = squareSize / 2;
    const squareDiagonal = Math.sqrt(2) * halfSquare;
    const minSafeDistance = uShapeMaxDist + squareDiagonal + margin;

    return distanceToCenter < minSafeDistance;
  }

  /**
   * Generate square vertices from center point
   */
  function generateSquareVertices(centerLat, centerLon, size, rotationAngle) {
    const halfSize = size / 2;
    const diagonalDist = Math.sqrt(2) * halfSize;
    const vertices = [];

    const cornerAngles = [45, 135, 225, 315];
    for (const cornerAngle of cornerAngles) {
      const vertex = getPointFromBearing(
        centerLat, centerLon,
        (cornerAngle + rotationAngle) % 360,
        diagonalDist
      );
      vertices.push(vertex);
    }

    return vertices;
  }

  /**
   * Check if a line segment intersects with a square area
   */
  function checkPathIntersectsSquare(startLat, startLon, endLat, endLon, squareVertices, margin) {
    const squareCenter = calculateSquareCenter(squareVertices);

    const dist1 = calculateDistance(
      squareVertices[0].latitude, squareVertices[0].longitude,
      squareVertices[1].latitude, squareVertices[1].longitude
    );
    const dist2 = calculateDistance(
      squareVertices[1].latitude, squareVertices[1].longitude,
      squareVertices[2].latitude, squareVertices[2].longitude
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

  /**
   * Calculate four external offset corners of a square
   */
  function calculateSquareOffsetCorners(squareVertices, offset) {
    const squareCenter = calculateSquareCenter(squareVertices);
    const offsetCorners = [];

    // For each vertex, calculate offset corner in the direction away from center
    for (const vertex of squareVertices) {
      const bearing = calculateBearing(
        squareCenter.latitude, squareCenter.longitude,
        vertex.latitude, vertex.longitude
      );

      // Calculate offset distance (reduced from sqrt(2) to 1.2 to minimize collision)
      const offsetDist = offset * 1.2;

      const offsetCorner = getPointFromBearing(
        vertex.latitude, vertex.longitude,
        bearing,
        offsetDist
      );

      offsetCorners.push(offsetCorner);
    }

    return offsetCorners;
  }

  /**
   * Select best pair of adjacent avoidance corners from offset corners
   */
  function selectBestAvoidanceCornerPair(startLat, startLon, endLat, endLon, offsetCorners, allSquares, margin) {
    if (offsetCorners.length !== 4) {
      return [null, null];
    }

    let bestPair = null;
    let minDistance = Infinity;

    // Try all 4 pairs of adjacent corners in BOTH directions
    for (let i = 0; i < 4; i++) {
      const pairs = [
        [offsetCorners[i], offsetCorners[(i + 1) % 4]],  // Clockwise
        [offsetCorners[(i + 1) % 4], offsetCorners[i]]   // Counter-clockwise
      ];

      for (const pair of pairs) {
        const corner1 = pair[0];
        const corner2 = pair[1];
        let hasCollision = false;

        // Check path segment: start -> corner1
        for (const squareVertices of allSquares) {
          const squareCenter = calculateSquareCenter(squareVertices);
          const dist1 = calculateDistance(
            squareVertices[0].latitude, squareVertices[0].longitude,
            squareVertices[1].latitude, squareVertices[1].longitude
          );
          const dist2 = calculateDistance(
            squareVertices[1].latitude, squareVertices[1].longitude,
            squareVertices[2].latitude, squareVertices[2].longitude
          );
          const squareSize = (dist1 + dist2) / 2;

          const startInSquare = checkPointInSquare(startLat, startLon, squareCenter, squareSize, 0);
          const corner1InSquare = checkPointInSquare(corner1.latitude, corner1.longitude, squareCenter, squareSize, 0);

          if (!startInSquare && !corner1InSquare && checkPathIntersectsSquare(
            startLat, startLon, corner1.latitude, corner1.longitude, squareVertices, margin
          )) {
            hasCollision = true;
            break;
          }
        }

        // Check path segment: corner1 -> corner2
        if (!hasCollision) {
          for (const squareVertices of allSquares) {
            const squareCenter = calculateSquareCenter(squareVertices);
            const dist1 = calculateDistance(
              squareVertices[0].latitude, squareVertices[0].longitude,
              squareVertices[1].latitude, squareVertices[1].longitude
            );
            const dist2 = calculateDistance(
              squareVertices[1].latitude, squareVertices[1].longitude,
              squareVertices[2].latitude, squareVertices[2].longitude
            );
            const squareSize = (dist1 + dist2) / 2;

            const corner1InSquare = checkPointInSquare(corner1.latitude, corner1.longitude, squareCenter, squareSize, 0);
            const corner2InSquare = checkPointInSquare(corner2.latitude, corner2.longitude, squareCenter, squareSize, 0);

            if (!corner1InSquare && !corner2InSquare && checkPathIntersectsSquare(
              corner1.latitude, corner1.longitude, corner2.latitude, corner2.longitude, squareVertices, margin
            )) {
              hasCollision = true;
              break;
            }
          }
        }

        // Check path segment: corner2 -> end
        if (!hasCollision) {
          for (const squareVertices of allSquares) {
            const squareCenter = calculateSquareCenter(squareVertices);
            const dist1 = calculateDistance(
              squareVertices[0].latitude, squareVertices[0].longitude,
              squareVertices[1].latitude, squareVertices[1].longitude
            );
            const dist2 = calculateDistance(
              squareVertices[1].latitude, squareVertices[1].longitude,
              squareVertices[2].latitude, squareVertices[2].longitude
            );
            const squareSize = (dist1 + dist2) / 2;

            const corner2InSquare = checkPointInSquare(corner2.latitude, corner2.longitude, squareCenter, squareSize, 0);
            const endInSquare = checkPointInSquare(endLat, endLon, squareCenter, squareSize, 0);

            if (!corner2InSquare && !endInSquare && checkPathIntersectsSquare(
              corner2.latitude, corner2.longitude, endLat, endLon, squareVertices, margin
            )) {
              hasCollision = true;
              break;
            }
          }
        }

        // Only consider corner pairs that don't create new collisions
        if (!hasCollision) {
          const dist1 = calculateDistance(startLat, startLon, corner1.latitude, corner1.longitude);
          const dist2 = calculateDistance(corner1.latitude, corner1.longitude, corner2.latitude, corner2.longitude);
          const dist3 = calculateDistance(corner2.latitude, corner2.longitude, endLat, endLon);
          const totalDist = dist1 + dist2 + dist3;

          if (totalDist < minDistance) {
            minDistance = totalDist;
            bestPair = [corner1, corner2];
          }
        }
      }
    }

    if (bestPair) {
      return bestPair;
    } else {
      return [null, null];
    }
  }

  /**
   * Check if a line segment intersects with U-shape wall area
   */
  function checkPathIntersectsUShape(startLat, startLon, endLat, endLon, uShapeCenterLat, uShapeCenterLon,
                                     uShapeMaxDist, uShapeInnerDist, openingAngle, margin) {
    // Calculate distances from start and end points to U-shape center
    const startDist = calculateDistance(uShapeCenterLat, uShapeCenterLon, startLat, startLon);
    const endDist = calculateDistance(uShapeCenterLat, uShapeCenterLon, endLat, endLon);

    // If both points are inside the inner area, no avoidance needed
    if (startDist < uShapeInnerDist && endDist < uShapeInnerDist) {
      return false;
    }

    // If both points are far outside, check path midpoint
    if (startDist > (uShapeMaxDist + margin) && endDist > (uShapeMaxDist + margin)) {
      return false;
    }

    // Critical case: path from outside to inside (or vice versa)
    if ((startDist > uShapeInnerDist && endDist < uShapeInnerDist) ||
        (startDist < uShapeInnerDist && endDist > uShapeInnerDist)) {
      // Determine which point is outside
      let outsideLat = startLat;
      let outsideLon = startLon;
      if (endDist > startDist) {
        outsideLat = endLat;
        outsideLon = endLon;
      }

      // Calculate bearing from U-shape center to outside point
      const bearingToOutside = calculateBearing(
        uShapeCenterLat, uShapeCenterLon,
        outsideLat, outsideLon
      );

      // Calculate angular difference from opening direction
      let angleDiff = (bearingToOutside - openingAngle + 360) % 360;
      // Normalize to [-180, 180]
      if (angleDiff > 180) {
        angleDiff = angleDiff - 360;
      }

      // If outside point is in opening direction (within ±90°), allow passage
      if (Math.abs(angleDiff) <= 90) {
        return false; // Entering/exiting through opening is valid
      }

      // Otherwise, path crosses walls
      return true;
    }

    // Sample-based detection for other cases
    const numSamples = 10;
    for (let i = 0; i <= numSamples; i++) {
      const t = i / numSamples;
      const sampleLat = startLat + t * (endLat - startLat);
      const sampleLon = startLon + t * (endLon - startLon);
      const sampleDist = calculateDistance(uShapeCenterLat, uShapeCenterLon, sampleLat, sampleLon);

      // Check if sample point is in the wall area
      if (sampleDist > uShapeInnerDist && sampleDist < (uShapeMaxDist + margin)) {
        return true;
      }
    }

    return false;
  }

  /**
   * Calculate U-shape outline corner points with offset
   */
  function calculateOutlineCorners(uShapeCenterLat, uShapeCenterLon, width, height, thickness, openingAngle, offset) {
    const corners = {};

    // Calculate outer rectangle corners
    const halfWidth = width / 2;
    const halfHeight = height / 2;
    const outerDiagonalDist = Math.sqrt(halfWidth * halfWidth + halfHeight * halfHeight);
    const outerBaseAngle = toDegrees(Math.atan2(halfWidth, halfHeight));

    // Outer corners without offset (base points)
    const outerTopRight = getPointFromBearing(
      uShapeCenterLat, uShapeCenterLon,
      (openingAngle + outerBaseAngle) % 360,
      outerDiagonalDist
    );

    const outerTopLeft = getPointFromBearing(
      uShapeCenterLat, uShapeCenterLon,
      (openingAngle - outerBaseAngle + 360) % 360,
      outerDiagonalDist
    );

    // Outer corners with offset
    const outerHalfWidthOffset = halfWidth + offset;
    const outerHalfHeightOffset = halfHeight + offset;
    const outerDiagonalDistOffset = Math.sqrt(
      outerHalfWidthOffset * outerHalfWidthOffset + outerHalfHeightOffset * outerHalfHeightOffset
    );
    const outerBaseAngleOffset = toDegrees(Math.atan2(outerHalfWidthOffset, outerHalfHeightOffset));

    corners.topRight = getPointFromBearing(
      uShapeCenterLat, uShapeCenterLon,
      (openingAngle + outerBaseAngleOffset) % 360,
      outerDiagonalDistOffset
    );

    corners.topLeft = getPointFromBearing(
      uShapeCenterLat, uShapeCenterLon,
      (openingAngle - outerBaseAngleOffset + 360) % 360,
      outerDiagonalDistOffset
    );

    corners.bottomRight = getPointFromBearing(
      uShapeCenterLat, uShapeCenterLon,
      (openingAngle + 180 - outerBaseAngleOffset) % 360,
      outerDiagonalDistOffset
    );

    corners.bottomLeft = getPointFromBearing(
      uShapeCenterLat, uShapeCenterLon,
      (openingAngle + 180 + outerBaseAngleOffset) % 360,
      outerDiagonalDistOffset
    );

    // Calculate inner rectangle corners
    const innerTopRightBase = getPointFromBearing(
      outerTopRight.latitude, outerTopRight.longitude,
      (270 + openingAngle) % 360,
      thickness
    );

    const innerTopLeftBase = getPointFromBearing(
      outerTopLeft.latitude, outerTopLeft.longitude,
      (90 + openingAngle) % 360,
      thickness
    );

    // Apply diagonal offset from base points
    const offsetDiagonal = offset * Math.sqrt(2);

    corners.innerTopRight = getPointFromBearing(
      innerTopRightBase.latitude, innerTopRightBase.longitude,
      (openingAngle - 45 + 360) % 360,
      offsetDiagonal
    );

    corners.innerTopLeft = getPointFromBearing(
      innerTopLeftBase.latitude, innerTopLeftBase.longitude,
      (openingAngle + 45) % 360,
      offsetDiagonal
    );

    return corners;
  }

  /**
   * Generate path with U-shape avoidance by following rectangular perimeter
   */
  function generatePathWithAvoidance(startLat, startLon, endLat, endLon, uShapeCenterLat, uShapeCenterLon,
                                     uShapeMaxDist, uShapeInnerDist, openingAngle, avoidanceMargin,
                                     avoidanceDistance, width, height, thickness, internalSquares) {
    const waypoints = [];

    // Add start waypoint
    waypoints.push({
      latitude: startLat,
      longitude: startLon
    });

    // Check if direct path intersects U-shape
    const intersectsUShape = checkPathIntersectsUShape(
      startLat, startLon, endLat, endLon,
      uShapeCenterLat, uShapeCenterLon,
      uShapeMaxDist, uShapeInnerDist, openingAngle, avoidanceMargin
    );

    if (intersectsUShape) {
      // Calculate U-shape outline corners
      const corners = calculateOutlineCorners(
        uShapeCenterLat, uShapeCenterLon, width, height, thickness,
        openingAngle, avoidanceMargin
      );

      // Determine path direction
      const startDist = calculateDistance(uShapeCenterLat, uShapeCenterLon, startLat, startLon);
      const endDist = calculateDistance(uShapeCenterLat, uShapeCenterLon, endLat, endLon);
      const startInside = startDist < uShapeInnerDist;
      const endInside = endDist < uShapeInnerDist;

      // Calculate bearings
      const bearingToStart = calculateBearing(
        uShapeCenterLat, uShapeCenterLon,
        startLat, startLon
      );
      const bearingToEnd = calculateBearing(
        uShapeCenterLat, uShapeCenterLon,
        endLat, endLon
      );

      // Calculate angular differences
      const normalizedOpening = openingAngle % 360;
      const normalizedStart = bearingToStart % 360;
      const normalizedEnd = bearingToEnd % 360;
      let angleDiffStart = (normalizedStart - normalizedOpening + 180) % 360 - 180;
      let angleDiffEnd = (normalizedEnd - normalizedOpening + 180) % 360 - 180;

      // Select which angle to use for routing
      let angleDiff, useRightPath;
      if (!startInside) {
        angleDiff = angleDiffStart;
        useRightPath = angleDiff > 0;
      } else {
        angleDiff = angleDiffEnd;
        useRightPath = angleDiff > 0;
      }

      // Build corner sequence
      const cornerSequence = [];

      if (!startInside) {
        // Outside → Inside
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
        // Add inner corner
        if (useRightPath) {
          cornerSequence.push(corners.innerTopRight);
        } else {
          cornerSequence.push(corners.innerTopLeft);
        }
      } else {
        // Inside → Outside
        if (useRightPath) {
          cornerSequence.push(corners.innerTopRight);
        } else {
          cornerSequence.push(corners.innerTopLeft);
        }

        // Add outer corners
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

      // Add all corners to waypoints
      for (const corner of cornerSequence) {
        waypoints.push({
          latitude: corner.latitude,
          longitude: corner.longitude
        });
      }
    }

    // Add end waypoint
    waypoints.push({
      latitude: endLat,
      longitude: endLon
    });

    // Handle internal square obstacle avoidance
    if (internalSquares) {
      const internalAreas = [internalSquares.ammoArea, internalSquares.hideArea, internalSquares.reloadArea];
      const maxIterations = 20;
      let modified = true;
      let iteration = 0;

      while (modified && iteration < maxIterations) {
        modified = false;
        iteration++;

        // Check each path segment
        for (let i = 0; i < waypoints.length - 1; i++) {
          const segStart = waypoints[i];
          const segEnd = waypoints[i + 1];

          // Check if this segment intersects any internal square
          for (let squareIdx = 0; squareIdx < internalAreas.length; squareIdx++) {
            const squareVertices = internalAreas[squareIdx];
            const squareCenter = calculateSquareCenter(squareVertices);
            const dist1 = calculateDistance(
              squareVertices[0].latitude, squareVertices[0].longitude,
              squareVertices[1].latitude, squareVertices[1].longitude
            );
            const dist2 = calculateDistance(
              squareVertices[1].latitude, squareVertices[1].longitude,
              squareVertices[2].latitude, squareVertices[2].longitude
            );
            const squareSize = (dist1 + dist2) / 2;

            const startInSquare = checkPointInSquare(segStart.latitude, segStart.longitude, squareCenter, squareSize, 0);
            const endInSquare = checkPointInSquare(segEnd.latitude, segEnd.longitude, squareCenter, squareSize, 0);

            if (!startInSquare && !endInSquare && checkPathIntersectsSquare(
              segStart.latitude, segStart.longitude,
              segEnd.latitude, segEnd.longitude,
              squareVertices, avoidanceMargin
            )) {
              // Try multiple offset distances
              let corner1 = null;
              let corner2 = null;
              const offsetMultipliers = [2.0, 2.5, 3.0, 3.5, 4.0, 5.0];

              // Create filtered list excluding current square
              const otherSquares = [];
              for (let idx = 0; idx < internalAreas.length; idx++) {
                if (idx !== squareIdx) {
                  otherSquares.push(internalAreas[idx]);
                }
              }

              for (const multiplier of offsetMultipliers) {
                const offsetDist = avoidanceMargin * multiplier;
                const offsetCorners = calculateSquareOffsetCorners(squareVertices, offsetDist);

                [corner1, corner2] = selectBestAvoidanceCornerPair(
                  segStart.latitude, segStart.longitude,
                  segEnd.latitude, segEnd.longitude,
                  offsetCorners,
                  otherSquares,
                  avoidanceMargin
                );

                if (corner1 && corner2) {
                  break;
                }
              }

              if (corner1 && corner2) {
                // Insert TWO avoidance waypoints
                waypoints.splice(i + 1, 0, {
                  latitude: corner1.latitude,
                  longitude: corner1.longitude
                });
                waypoints.splice(i + 2, 0, {
                  latitude: corner2.latitude,
                  longitude: corner2.longitude
                });

                modified = true;
                break;
              } else {
                console.error(`Cannot find valid avoidance path at segment ${i}->${i + 1}`);
              }
            }
          }

          if (modified) {
            break;
          }
        }
      }

      if (iteration >= maxIterations) {
        console.error(`Failed to generate collision-free path after ${maxIterations} iterations`);
      }
    }

    return waypoints;
  }

  /**
   * Generate three non-overlapping squares inside the U-shape's internal rectangle
   */
  function generateInternalSquares(innerCorners, openingAngle, squareSize, innerWidth, innerHeight, marginToWall = 0.1, marginBetweenSquares = 0.1) {
    const areas = {};
    const maxAttempts = 100;
    const halfSquare = squareSize / 2;

    // Calculate the center of internal rectangle
    const centerLat = (innerCorners[0].latitude + innerCorners[1].latitude +
                       innerCorners[2].latitude + innerCorners[3].latitude) / 4;
    const centerLon = (innerCorners[0].longitude + innerCorners[1].longitude +
                       innerCorners[2].longitude + innerCorners[3].longitude) / 4;

    // Calculate valid range for square centers
    const maxOffsetX = (innerWidth / 2) - halfSquare - marginToWall;
    const maxOffsetY = (innerHeight / 2) - halfSquare - marginToWall;

    if (maxOffsetX <= 0 || maxOffsetY <= 0) {
      console.error(`Square size (${squareSize} nm) too large for internal area (${innerWidth} x ${innerHeight} nm)`);
      return areas;
    }

    // Generate three square centers
    const centers = [];
    const areaNames = ['ammoArea', 'hideArea', 'reloadArea'];

    for (let i = 0; i < 3; i++) {
      let validCenter = false;
      let attempts = 0;

      while (!validCenter && attempts < maxAttempts) {
        attempts++;
        const candidate = generateRandomSquareCenter(centerLat, centerLon, maxOffsetX, maxOffsetY, openingAngle);

        // Check if this center doesn't overlap with existing squares
        let overlap = false;
        for (const existingCenter of centers) {
          if (checkSquaresOverlap(
            candidate.latitude, candidate.longitude,
            existingCenter.latitude, existingCenter.longitude,
            squareSize, marginBetweenSquares
          )) {
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

    // Generate vertices for each square
    areas.ammoArea = generateSquareVertices(centers[0].latitude, centers[0].longitude, squareSize, openingAngle);
    areas.hideArea = generateSquareVertices(centers[1].latitude, centers[1].longitude, squareSize, openingAngle);
    areas.reloadArea = generateSquareVertices(centers[2].latitude, centers[2].longitude, squareSize, openingAngle);

    return areas;
  }

  /**
   * Generate fire point squares on circle perimeter around U-shape
   */
  function generateFirePoints(centerLat, centerLon, radius, squareSize, count, angleRange, openingAngle, margin, uShapeVertices, uShapeWidth, uShapeHeight) {
    const firePoints = [];
    const maxAttempts = 200;

    // Calculate U-shape bounding box
    const uShapeMaxDist = Math.sqrt((uShapeWidth / 2) ** 2 + (uShapeHeight / 2) ** 2);

    // Calculate angle range boundaries
    const startAngle = openingAngle + 180 - (angleRange / 2);

    // Generate fire points
    for (let i = 0; i < count; i++) {
      let validPosition = false;
      let attempts = 0;

      while (!validPosition && attempts < maxAttempts) {
        attempts++;

        // Generate random angle within range
        const randomAngle = (startAngle + (Math.random() * angleRange)) % 360;

        // Calculate position on circle perimeter
        const candidate = getPointFromBearing(centerLat, centerLon, randomAngle, radius);

        // Check if position is valid
        let valid = true;

        // Check overlap with U-shape
        if (checkFirePointOverlapsWithUShape(
          candidate.latitude, candidate.longitude,
          centerLat, centerLon,
          uShapeMaxDist, squareSize, margin
        )) {
          valid = false;
        }

        // Check overlap with existing fire points
        if (valid) {
          for (const existingFirePoint of firePoints) {
            if (checkSquaresOverlap(
              candidate.latitude, candidate.longitude,
              existingFirePoint.center.latitude, existingFirePoint.center.longitude,
              squareSize, margin
            )) {
              valid = false;
              break;
            }
          }
        }

        if (valid) {
          // Calculate square rotation to face toward U-shape center
          const bearingToCenter = calculateBearing(
            candidate.latitude, candidate.longitude,
            centerLat, centerLon
          );

          const vertices = generateSquareVertices(
            candidate.latitude, candidate.longitude,
            squareSize, bearingToCenter
          );

          firePoints.push({
            center: candidate,
            vertices: vertices
          });
          validPosition = true;
        }
      }

      if (!validPosition) {
        console.error(`Failed to place fire point ${i + 1}/${count} after ${maxAttempts} attempts`);
      }
    }

    // Return only vertices arrays
    return firePoints.map(fp => fp.vertices);
  }

  // ============================================================================
  // Public API Functions
  // ============================================================================

  /**
   * Generate U-shaped area vertices with specified configuration
   * @param {Object} areaConfig - Configuration object
   * @returns {Object} Result containing uShapeVertices and optionally internal areas
   */
  function generateUShapeVertices(areaConfig) {
    // Validate required fields
    if (!areaConfig.centerLat) throw new Error('config.centerLat is required');
    if (!areaConfig.centerLon) throw new Error('config.centerLon is required');
    if (!areaConfig.thickness) throw new Error('config.thickness is required');
    if (!areaConfig.width) throw new Error('config.width is required');
    if (!areaConfig.height) throw new Error('config.height is required');
    if (areaConfig.openingAngle === undefined) throw new Error('config.openingAngle is required');

    const result = {};
    const vertices = [];

    const { centerLat, centerLon, thickness, width, height, openingAngle } = areaConfig;

    // Calculate half dimensions
    const halfWidth = width / 2;
    const halfHeight = height / 2;

    // Calculate diagonal distance and angle for outer rectangle corners
    const outerDiagonalDist = Math.sqrt(halfWidth * halfWidth + halfHeight * halfHeight);
    const baseAngle = toDegrees(Math.atan2(halfWidth, halfHeight));

    // Calculate 4 corners of outer rectangle
    const outerAngles = [
      360 - baseAngle,  // Top-left
      baseAngle,        // Top-right
      180 - baseAngle,  // Bottom-right
      180 + baseAngle   // Bottom-left
    ];

    // Generate outer corners
    const outerCorners = [];
    for (let i = 0; i < 4; i++) {
      outerCorners[i] = getPointFromBearing(
        centerLat, centerLon,
        (outerAngles[i] + openingAngle) % 360,
        outerDiagonalDist
      );
    }

    // Generate inner corners
    const innerCorners = [];

    // Inner top-left
    innerCorners[0] = getPointFromBearing(
      outerCorners[0].latitude, outerCorners[0].longitude,
      (90 + openingAngle) % 360,
      thickness
    );

    // Inner top-right
    innerCorners[1] = getPointFromBearing(
      outerCorners[1].latitude, outerCorners[1].longitude,
      (270 + openingAngle) % 360,
      thickness
    );

    // Inner bottom-right
    innerCorners[2] = getPointFromBearing(
      innerCorners[1].latitude, innerCorners[1].longitude,
      (180 + openingAngle) % 360,
      height - thickness
    );

    // Inner bottom-left
    innerCorners[3] = getPointFromBearing(
      innerCorners[0].latitude, innerCorners[0].longitude,
      (180 + openingAngle) % 360,
      height - thickness
    );

    // Build U-shape vertices (counter-clockwise)
    vertices.push(outerCorners[3]); // Outer bottom-left
    vertices.push(outerCorners[2]); // Outer bottom-right
    vertices.push(outerCorners[1]); // Outer top-right
    vertices.push(innerCorners[1]); // Inner top-right
    vertices.push(innerCorners[2]); // Inner bottom-right
    vertices.push(innerCorners[3]); // Inner bottom-left
    vertices.push(innerCorners[0]); // Inner top-left
    vertices.push(outerCorners[0]); // Outer top-left

    result.uShapeVertices = vertices;

    // Generate internal squares if configured
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

    // Generate fire points if configured
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

  /**
   * Calculate movement paths between tactical positions with U-shape avoidance
   * Generates optimized paths for TEL movement between different tactical zones
   * @param {Object} pathConfig - Configuration for path calculation
   * @returns {Object} Movement paths organized by type (FP, HA, RL, AHA)
   */
  function calculateMovementPaths(pathConfig) {
    // Validate required fields
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
    const paths = {
      FP: [],
      HA: { waypoints: [] },
      RL: [],
      AHA: { waypoints: [] }
    };

    // Calculate U-shape bounding parameters
    const uShapeMaxDist = Math.sqrt((pathConfig.width / 2) ** 2 + (pathConfig.height / 2) ** 2);
    const avoidanceDistance = uShapeMaxDist + avoidanceMargin + 0.5;

    // Calculate inner rectangle dimensions
    const innerWidth = pathConfig.width - 2 * pathConfig.thickness;
    const innerHeight = pathConfig.height - pathConfig.thickness;
    const uShapeInnerDist = Math.sqrt((innerWidth / 2) ** 2 + (innerHeight / 2) ** 2);

    // Calculate center points of tactical zones
    const ammoCtr = calculateSquareCenter(pathConfig.ammoArea);
    const hideCtr = calculateSquareCenter(pathConfig.hideArea);
    const reloadCtr = calculateSquareCenter(pathConfig.reloadArea);

    // Prepare internal squares for obstacle avoidance
    const internalSquares = {
      ammoArea: pathConfig.ammoArea,
      hideArea: pathConfig.hideArea,
      reloadArea: pathConfig.reloadArea
    };

    // Generate HA path: Reload Area -> Hide Area
    paths.HA.waypoints = generatePathWithAvoidance(
      reloadCtr.latitude, reloadCtr.longitude,
      hideCtr.latitude, hideCtr.longitude,
      pathConfig.centerLat, pathConfig.centerLon,
      uShapeMaxDist, uShapeInnerDist, pathConfig.openingAngle,
      avoidanceMargin, avoidanceDistance,
      pathConfig.width, pathConfig.height, pathConfig.thickness,
      null // No internal obstacle avoidance for HA path
    );

    // Generate AHA path: Reload Area -> Ammo Holding Area
    paths.AHA.waypoints = generatePathWithAvoidance(
      reloadCtr.latitude, reloadCtr.longitude,
      ammoCtr.latitude, ammoCtr.longitude,
      pathConfig.centerLat, pathConfig.centerLon,
      uShapeMaxDist, uShapeInnerDist, pathConfig.openingAngle,
      avoidanceMargin, avoidanceDistance,
      pathConfig.width, pathConfig.height, pathConfig.thickness,
      null // No internal obstacle avoidance for AHA path
    );

    // Generate FP paths: Hide Area -> each Fire Point
    if (pathConfig.firePoints) {
      for (let i = 0; i < pathConfig.firePoints.length; i++) {
        const firePoint = pathConfig.firePoints[i];
        const fpCtr = calculateSquareCenter(firePoint);
        paths.FP[i] = {
          waypoints: generatePathWithAvoidance(
            hideCtr.latitude, hideCtr.longitude,
            fpCtr.latitude, fpCtr.longitude,
            pathConfig.centerLat, pathConfig.centerLon,
            uShapeMaxDist, uShapeInnerDist, pathConfig.openingAngle,
            avoidanceMargin, avoidanceDistance,
            pathConfig.width, pathConfig.height, pathConfig.thickness,
            internalSquares
          )
        };
      }
    }

    // Generate RL paths: each Fire Point -> Reload Area
    if (pathConfig.firePoints) {
      for (let i = 0; i < pathConfig.firePoints.length; i++) {
        const firePoint = pathConfig.firePoints[i];
        const fpCtr = calculateSquareCenter(firePoint);
        paths.RL[i] = {
          waypoints: generatePathWithAvoidance(
            fpCtr.latitude, fpCtr.longitude,
            reloadCtr.latitude, reloadCtr.longitude,
            pathConfig.centerLat, pathConfig.centerLon,
            uShapeMaxDist, uShapeInnerDist, pathConfig.openingAngle,
            avoidanceMargin, avoidanceDistance,
            pathConfig.width, pathConfig.height, pathConfig.thickness,
            internalSquares
          )
        };
      }
    }

    return paths;
  }

  // Export public API
  return {
    // Utility functions
    calculateDistance,
    calculateBearing,
    getPointFromBearing,
    toRadians,
    toDegrees,

    // Main API
    generateUShapeVertices,
    calculateMovementPaths
  };
})();

// Export for use in browser or Node.js
if (typeof module !== 'undefined' && module.exports) {
  module.exports = TacticalAreaGenerator;
}
