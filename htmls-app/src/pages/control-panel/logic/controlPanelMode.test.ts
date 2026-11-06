import { describe, expect, it } from 'vitest';
import { resolveControlPanelView } from './controlPanelMode';

describe('resolveControlPanelView', () => {
  it('edit mode shows everything', () => {
    expect(resolveControlPanelView({ isEditMode: true, isDeployLocked: false })).toEqual({
      shouldShowLandingUnits: true,
      shouldShowAddUnits: true,
      isDeploymentLocked: false,
    });
  });

  it('edit mode still honours the lock', () => {
    const view = resolveControlPanelView({ isEditMode: true, isDeployLocked: true });
    expect(view.isDeploymentLocked).toBe(true);
  });

  it('play mode hides landing units and add units', () => {
    const view = resolveControlPanelView({ isEditMode: false, isDeployLocked: false });
    expect(view.shouldShowLandingUnits).toBe(false);
    expect(view.shouldShowAddUnits).toBe(false);
    expect(view.isDeploymentLocked).toBe(false);
  });

  it('play mode locks deployment once it was submitted', () => {
    const view = resolveControlPanelView({ isEditMode: false, isDeployLocked: true });
    expect(view.isDeploymentLocked).toBe(true);
  });
});
