import { readInjectedBoolean } from '@/utils/inject';

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
  showLandingUnits: boolean;
  showAddUnits: boolean;
  /** Jammer, launcher and aircraft deployment can no longer be changed */
  isDeploymentLocked: boolean;
}

declare global {
  interface Window {
    __INJECT_C2__?: string;
    __INJECT_SIGNALS__?: string;
    __INJECT_LAUNCHERS__?: string;
    __INJECT_LANDING_UNITS__?: string;
    __INJECT_IS_EDIT_MODE__?: string;
    __INJECT_IS_DEPLOY_LOCKED__?: string;
  }
}

/** Unfilled placeholders mean local dev: edit mode, nothing locked. */
export function readControlPanelMode(): ControlPanelMode {
  return {
    isEditMode: readInjectedBoolean(window.__INJECT_IS_EDIT_MODE__, true),
    isDeployLocked: readInjectedBoolean(window.__INJECT_IS_DEPLOY_LOCKED__, false),
  };
}

export function resolveControlPanelView({
  isEditMode,
  isDeployLocked,
}: ControlPanelMode): ControlPanelView {
  return {
    showLandingUnits: isEditMode,
    showAddUnits: isEditMode,
    isDeploymentLocked: !isEditMode && isDeployLocked,
  };
}
