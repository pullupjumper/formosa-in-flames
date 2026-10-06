import type { Coordinate } from '@/types/geo';
import type { MissileDeployment, TacticalAreas } from '@/types/controlPanel';
import type { RandomSource } from '@/utils/random';
import { areAllPointsInTaiwan } from '@/utils/geo';
import { AREA_CONFIG, DEPLOYMENT_MAX_ATTEMPTS } from './config';
import { generateLayout } from './layout';
import { buildMovementPaths } from './paths';
import { buildShelterPlan } from './shelter';

/**
 * The two verbs that produce a whole deployment: `generate` from a map click
 * and `rotate` of an existing one. Both run the same pipeline:
 * layout → shelter plan (with gateways) → movement paths.
 */

export interface GenerateDeploymentParams {
  unitname: string;
  category: string;
  center: Coordinate;
  angle: number;
  validateTaiwanBoundary: boolean;
  ahaRadiusOverride?: number;
  ahaCenterOverride?: Coordinate;
  /** Keep these fire points instead of generating new ones (rotation) */
  firePointsOverride?: Coordinate[][];
  /** Defaults to `Math.random`; pass a seeded source for reproducible output. */
  rng?: RandomSource;
}

export function isValidAngle(angle: number): boolean {
  return Number.isFinite(angle) && angle >= 0 && angle <= 359;
}

/**
 * Produce a complete deployment (tactical areas + movement paths) for one unit.
 * Returns null when the location fails the Taiwan boundary check or when no
 * layout with both gateways could be found.
 */
export function generateDeploymentData({
  unitname,
  category,
  center,
  angle,
  validateTaiwanBoundary,
  ahaRadiusOverride,
  ahaCenterOverride,
  firePointsOverride,
  rng = Math.random,
}: GenerateDeploymentParams): MissileDeployment | null {
  try {
    const layoutOptions = { ahaRadius: ahaRadiusOverride, ahaCenter: ahaCenterOverride };

    // Outer retry: if the shelter plan can't converge on both gateways with
    // this HA/RL layout, regenerate the layout (which re-randomizes HA/RL/FP)
    // and try again. The shelter inner retry is bounded separately.
    for (let attempt = 0; attempt < DEPLOYMENT_MAX_ATTEMPTS; attempt++) {
      const layout = generateLayout(center, angle, layoutOptions, rng);

      // Taiwan boundary is deterministic w.r.t. center/angle; no point retrying.
      if (validateTaiwanBoundary && !areAllPointsInTaiwan(layout.uShapeVertices)) {
        return null;
      }

      const plan = buildShelterPlan(center, angle, layout.hideArea, layout.reloadArea, rng);
      if (!plan.gateways) continue;

      const tacticalAreas: TacticalAreas = {
        ...layout,
        firePoints: firePointsOverride ?? layout.firePoints,
        shelterPoints: plan.shelterPoints,
      };

      return {
        unitname,
        missileSystemType: category,
        center,
        openingAngle: angle,
        ahaRadius: ahaRadiusOverride ?? AREA_CONFIG.ahaPoint.radius,
        ...(ahaCenterOverride ? { ahaCenter: ahaCenterOverride } : {}),
        tacticalAreas,
        paths: buildMovementPaths(tacticalAreas, plan.gateways),
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

export interface RotateDeploymentParams {
  deployment: MissileDeployment;
  angle: number;
  validateTaiwanBoundary: boolean;
  rng?: RandomSource;
}

/**
 * Re-generate a deployed unit at a new opening angle. Fire points and the AHA
 * are user-placed, so they stay where they are; paths are rebuilt once against
 * the kept fire points. Null when the angle is unusable (out of range, the
 * rotated boundary leaves Taiwan, or no gateway fits).
 */
export function rotateDeployment({
  deployment,
  angle,
  validateTaiwanBoundary,
  rng = Math.random,
}: RotateDeploymentParams): MissileDeployment | null {
  if (!isValidAngle(angle)) return null;
  return generateDeploymentData({
    unitname: deployment.unitname,
    category: deployment.missileSystemType,
    center: deployment.center,
    angle,
    validateTaiwanBoundary,
    ahaRadiusOverride: deployment.ahaRadius,
    ahaCenterOverride: deployment.ahaCenter,
    firePointsOverride: deployment.tacticalAreas.firePoints,
    rng,
  });
}
