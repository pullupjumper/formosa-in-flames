// ============================================================================
// Control panel mode — what the page shows and what it lets the player change
// ============================================================================
export interface ControlPanelMode {
  /** Edit build: nothing hidden */
  isEditMode: boolean;
  /** The deployment can no longer be changed (play: submitted once; edit: scenario begun) */
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
    isDeploymentLocked: isDeployLocked,
  };
}
