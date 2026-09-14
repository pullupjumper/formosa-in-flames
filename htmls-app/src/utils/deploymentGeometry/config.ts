import type { Coordinate } from '@/types/geo';
import type { SquareAreaType } from '@/types/deployment';

/**
 * Every distance the geometry engine uses, in nautical miles. Internal to the
 * module: callers pick verbs, not knobs.
 */
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
export const SHELTER_PLAN_MAX_ATTEMPTS = 50;

/** Outer retry that regenerates the whole layout when shelters cannot converge */
export const DEPLOYMENT_MAX_ATTEMPTS = 50;

/** Fixed reference point used to precompute angle-specific preview offsets */
export const REF_CENTER: Coordinate = { latitude: 23.8, longitude: 121.0 };

export const AREA_SQUARE_SIZE: Record<SquareAreaType, number> = {
  aha: AREA_CONFIG.ahaPoint.squareSize,
  hide: AREA_CONFIG.internalSquares.size,
  reload: AREA_CONFIG.internalSquares.size,
  fp: AREA_CONFIG.firePoints.squareSize,
};
