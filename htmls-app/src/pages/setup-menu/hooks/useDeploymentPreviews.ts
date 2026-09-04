import { useMemo } from 'react';
import type { DeployedMissileSystemData } from '@/types/setupMenu';
import { isPointInTaiwan, determineOpeningAngle } from '@/utils/map';
import { calculateBearing, generateSquareVerticesPublic } from '@/utils/tacticalAreaGenerator';
import type { Coordinate } from '@/utils/tacticalAreaGenerator';
import { AREA_SQUARE_SIZE, generateRotationPreview } from '@/utils/missileDeployment';
import type { OffsetVertex } from '@/utils/missileDeployment';
import type { RandomSource } from '@/utils/random';
import type { DeploymentMode, LatLng } from './deploymentMode';

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
  mousePosition: LatLng | null;
  deployedSystems: Map<string, DeployedMissileSystemData>;
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

    const angle = determineOpeningAngle(mousePosition.lat, mousePosition.lng);
    const offsets = mode.offsets[angle];
    if (!offsets) return null;

    const translate = (offset: OffsetVertex): Coordinate => ({
      latitude: mousePosition.lat + offset.dLat,
      longitude: mousePosition.lng + offset.dLng,
    });

    const uShapeVertices = offsets.uShapeVertices.map(translate);
    const ammoArea = offsets.ammoArea.map(translate);
    const firePoints = offsets.firePoints.map((fp) => fp.map(translate));

    const allVerticesInTaiwan =
      !shouldValidateTaiwanBoundary ||
      (uShapeVertices.every((v) => isPointInTaiwan(v.latitude, v.longitude)) &&
        firePoints.every((fp) => fp.every((v) => isPointInTaiwan(v.latitude, v.longitude))) &&
        ammoArea.every((v) => isPointInTaiwan(v.latitude, v.longitude)));

    return {
      uShapeVertices,
      ammoArea,
      hideArea: offsets.hideArea.map(translate),
      reloadArea: offsets.reloadArea.map(translate),
      firePoints,
      isValid: allVerticesInTaiwan,
    };
  }, [mode, mousePosition, shouldValidateTaiwanBoundary]);

  /** Area relocation: the U-shape translates, a single square re-squares */
  const relocatePreviewVertices = useMemo<Coordinate[] | null>(() => {
    if (mode.kind !== 'relocateArea' || !mousePosition) return null;

    const deployment = deployedSystems.get(mode.area.unitKey);
    if (!deployment) return null;

    if (mode.area.type === 'ushape') {
      return deployment.tacticalAreas.uShapeVertices.map((v) => ({
        latitude: v.latitude + (mousePosition.lat - deployment.center.lat),
        longitude: v.longitude + (mousePosition.lng - deployment.center.lng),
      }));
    }

    const bearingToCenter = calculateBearing(
      mousePosition.lat,
      mousePosition.lng,
      deployment.center.lat,
      deployment.center.lng
    );
    return generateSquareVerticesPublic(
      mousePosition.lat,
      mousePosition.lng,
      AREA_SQUARE_SIZE[mode.area.type],
      bearingToCenter
    );
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
      (preview.uShapeVertices.every((v) => isPointInTaiwan(v.latitude, v.longitude)) &&
        preview.ammoArea.every((v) => isPointInTaiwan(v.latitude, v.longitude)));

    // Fire points are user-placed, so rotation leaves them where they are
    return { ...preview, firePoints: deployment.tacticalAreas.firePoints ?? [], isValid };
  }, [mode, deployedSystems, shouldValidateTaiwanBoundary, rng]);

  return { previewData, relocatePreviewVertices, rotationPreviewData };
}
