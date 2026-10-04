import { useMemo } from 'react';
import type { Coordinate } from '@/types/geo';
import type { MissileDeployment } from '@/types/controlPanel';
import { resolveOpeningAngle } from '@/utils/map';
import { previewDeployment, previewRelocation, previewRotation } from '@/utils/deploymentGeometry';
import type { DeploymentPreview } from '@/utils/deploymentGeometry';
import type { RandomSource } from '@/utils/random';
import type { DeploymentMode } from '../deploymentMode';

export type { DeploymentPreview } from '@/utils/deploymentGeometry';

/**
 * Everything the map draws while a mode is pending. Thin memo wrappers over
 * the preview verbs in `deploymentGeometry`; no geometry lives here.
 */

export interface UseDeploymentPreviewsParams {
  mode: DeploymentMode;
  mousePosition: Coordinate | null;
  deployedMissileSystems: Map<string, MissileDeployment>;
  shouldValidateTaiwanBoundary: boolean;
  rng: RandomSource;
}

export function useDeploymentPreviews({
  mode,
  mousePosition,
  deployedMissileSystems,
  shouldValidateTaiwanBoundary,
  rng,
}: UseDeploymentPreviewsParams) {
  const previewData = useMemo<DeploymentPreview | null>(() => {
    if (mode.kind !== 'deploy' || !mousePosition) return null;
    const offsets = mode.offsets[resolveOpeningAngle(mousePosition)];
    if (!offsets) return null;
    return previewDeployment(offsets, mousePosition, shouldValidateTaiwanBoundary);
  }, [mode, mousePosition, shouldValidateTaiwanBoundary]);

  const relocatePreviewVertices = useMemo<Coordinate[] | null>(() => {
    if (mode.kind !== 'relocateArea' || !mousePosition) return null;
    const deployment = deployedMissileSystems.get(mode.area.unitKey);
    if (!deployment) return null;
    return previewRelocation(deployment, mode.area, mousePosition);
  }, [mode, mousePosition, deployedMissileSystems]);

  const rotationPreviewData = useMemo<DeploymentPreview | null>(() => {
    if (mode.kind !== 'rotate' || mode.previewAngle === null) return null;
    const deployment = deployedMissileSystems.get(mode.unitKey);
    if (!deployment) return null;
    return previewRotation(deployment, mode.previewAngle, shouldValidateTaiwanBoundary, rng);
  }, [mode, deployedMissileSystems, shouldValidateTaiwanBoundary, rng]);

  return { previewData, relocatePreviewVertices, rotationPreviewData };
}
