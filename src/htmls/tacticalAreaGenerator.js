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

  // Export public API
  return {
    // Utility functions
    calculateDistance,
    calculateBearing,
    getPointFromBearing,
    toRadians,
    toDegrees,

    // Main API
    generateUShapeVertices
  };
})();

// Export for use in browser or Node.js
if (typeof module !== 'undefined' && module.exports) {
  module.exports = TacticalAreaGenerator;
}
