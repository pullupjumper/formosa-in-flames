import { describe, expect, it } from 'vitest';
import { resolveControlPanelView } from './controlPanelMode';

describe('resolveControlPanelView', () => {
  it('edit mode shows everything and never locks', () => {
    expect(resolveControlPanelView({ isEditMode: true, isDeployLocked: true })).toEqual({
      shouldShowLandingUnits: true,
      showAddUnits: true,
      isDeploymentLocked: false,
    });
  });

  it('play mode hides landing units and add units', () => {
    const view = resolveControlPanelView({ isEditMode: false, isDeployLocked: false });
    expect(view.shouldShowLandingUnits).toBe(false);
    expect(view.showAddUnits).toBe(false);
    expect(view.isDeploymentLocked).toBe(false);
  });

  it('play mode locks deployment once it was submitted', () => {
    const view = resolveControlPanelView({ isEditMode: false, isDeployLocked: true });
    expect(view.isDeploymentLocked).toBe(true);
  });
});
