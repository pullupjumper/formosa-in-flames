// ============================================================================
// Control panel mode — what the page shows and what it lets the player change
// ============================================================================
export interface ControlPanelMode {
  /** Edit build: nothing hidden, nothing locked */
  isEditMode: boolean;
  /** Play build only: the one allowed deployment has already been submitted */
  isDeployLocked: boolean;
}

export interface ControlPanelView {
  shouldShowLandingUnits: boolean;
  shouldShowAddUnits: boolean;
  /** Jammer, battery and aircraft deployment can no longer be changed */
  isDeploymentLocked: boolean;
}

export function resolveControlPanelView({
  isEditMode,
  isDeployLocked,
}: ControlPanelMode): ControlPanelView {
  return {
    shouldShowLandingUnits: isEditMode,
    shouldShowAddUnits: isEditMode,
    isDeploymentLocked: !isEditMode && isDeployLocked,
  };
}
