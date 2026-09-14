/**
 * Deployment geometry: everything that turns a map click into a missile
 * deployment and keeps it consistent while the user edits it.
 *
 * Four verbs — generate, relocate, rotate, preview — plus the offset cache the
 * hover preview needs. Distances, retry policies, shelter placement, gateway
 * selection and path avoidance are internal; tests reach them through the
 * sibling files, callers do not.
 */

export {
  generateDeploymentData,
  rotateDeployment,
  isValidAngle,
  type GenerateDeploymentParams,
  type RotateDeploymentParams,
} from './deploy';

export {
  relocateArea,
  type RelocateAreaParams,
  type RelocateFailure,
  type RelocateResult,
  type RelocateTarget,
} from './relocate';

export {
  generateOffsetsForAngle,
  previewDeployment,
  previewRelocation,
  previewRotation,
  type DeploymentPreview,
  type PreviewOffsets,
} from './preview';

export { createEmptyMovementPaths } from './paths';
