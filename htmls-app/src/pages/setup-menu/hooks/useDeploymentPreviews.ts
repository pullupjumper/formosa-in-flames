import { useMemo } from 'react';
import type { Coordinate } from '@/types/geo';
import type { MissileDeployment } from '@/types/setupMenu';
import { areAllPointsInTaiwan, translateCoordinate } from '@/utils/geo';
import { resolveOpeningAngle } from '@/utils/map';
import { calculateBearing, generateSquareVertices } from '@/utils/tacticalAreaGenerator';
import { AREA_SQUARE_SIZE, generateRotationPreview } from '@/utils/missileDeployment';
import type { RandomSource } from '@/utils/random';
import type { DeploymentMode } from './deploymentMode';

/**
 * Everything the map draws while a mode is pending. Pure derivations of the
 * current mode plus the cursor, so they hold no state of their own.
 */

// ============================================================================
// TYPES
// ============================================================================
export interface DeploymentPreview {
  uShapeVertices: Coordinate[];
  ammoArea: Coordinate[];
  hideArea: Coordinate[];
  reloadArea: Coordinate[];
  firePoints: Coordinate[][];
  /** Boundary check only; gateway feasibility is resolved on commit */
  isValid: boolean;
}

export interface UseDeploymentPreviewsParams {
  mode: DeploymentMode;
  mousePosition: Coordinate | null;
  deployedSystems: Map<string, MissileDeployment>;
  shouldValidateTaiwanBoundary: boolean;
  rng: RandomSource;
}

// ============================================================================
// HOOK
// ============================================================================
export function useDeploymentPreviews({
  mode,
  mousePosition,
  deployedSystems,
  shouldValidateTaiwanBoundary,
  rng,
}: UseDeploymentPreviewsParams) {
  /** New deployment: translate the precomputed offsets to the cursor */
  const previewData = useMemo<DeploymentPreview | null>(() => {
    if (mode.kind !== 'deploy' || !mousePosition) return null;

    const angle = resolveOpeningAngle(mousePosition);
    const offsets = mode.offsets[angle];
    if (!offsets) return null;

    const translate = (offset: Parameters<typeof translateCoordinate>[1]): Coordinate =>
      translateCoordinate(mousePosition, offset);

    const uShapeVertices = offsets.uShapeVertices.map(translate);
    const ammoArea = offsets.ammoArea.map(translate);
    const firePoints = offsets.firePoints.map((firePoint) => firePoint.map(translate));

    const isValid =
      !shouldValidateTaiwanBoundary ||
      (areAllPointsInTaiwan(uShapeVertices) &&
        areAllPointsInTaiwan(ammoArea) &&
        firePoints.every(areAllPointsInTaiwan));

    return {
      uShapeVertices,
      ammoArea,
      hideArea: offsets.hideArea.map(translate),
      reloadArea: offsets.reloadArea.map(translate),
      firePoints,
      isValid,
    };
  }, [mode, mousePosition, shouldValidateTaiwanBoundary]);

  /** Area relocation: the U-shape translates, a single square re-squares */
  const relocatePreviewVertices = useMemo<Coordinate[] | null>(() => {
    if (mode.kind !== 'relocateArea' || !mousePosition) return null;

    const deployment = deployedSystems.get(mode.area.unitKey);
    if (!deployment) return null;

    if (mode.area.type === 'ushape') {
      const offset = {
        latitudeDelta: mousePosition.latitude - deployment.center.latitude,
        longitudeDelta: mousePosition.longitude - deployment.center.longitude,
      };
      return deployment.tacticalAreas.uShapeVertices.map((vertex) =>
        translateCoordinate(vertex, offset)
      );
    }

    const bearingToCenter = calculateBearing(mousePosition, deployment.center);
    return generateSquareVertices(mousePosition, AREA_SQUARE_SIZE[mode.area.type], bearingToCenter);
  }, [mode, mousePosition, deployedSystems]);

  /** Rotation: regenerate the layout at the swept angle */
  const rotationPreviewData = useMemo<DeploymentPreview | null>(() => {
    if (mode.kind !== 'rotate' || mode.previewAngle === null) return null;

    const deployment = deployedSystems.get(mode.unitKey);
    if (!deployment) return null;

    const preview = generateRotationPreview(
      mode.center,
      mode.previewAngle,
      deployment.ahaRadius,
      deployment.ahaCenter,
      rng
    );
    if (!preview) return null;

    // A green preview is necessary but not sufficient — handleMapClick still
    // rejects the angle when no gateway fits.
    const isValid =
      !shouldValidateTaiwanBoundary ||
      (areAllPointsInTaiwan(preview.uShapeVertices) && areAllPointsInTaiwan(preview.ammoArea));

    // Fire points are user-placed, so rotation leaves them where they are
    return { ...preview, firePoints: deployment.tacticalAreas.firePoints ?? [], isValid };
  }, [mode, deployedSystems, shouldValidateTaiwanBoundary, rng]);

  return { previewData, relocatePreviewVertices, rotationPreviewData };
}
