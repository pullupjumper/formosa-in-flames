import { describe, it, expect, vi, beforeEach } from 'vitest';
import { act, renderHook } from '@testing-library/react';
import type { Coordinate } from '@/types/geo';
import type { MissileDeployment, Jammer } from '@/types/controlPanel';
import { useDeploymentState } from '@/pages/control-panel/hooks/useDeploymentState';
import type { UseDeploymentStateParams } from '@/pages/control-panel/hooks/useDeploymentState';
import {
  deploymentModeReducer,
  IDLE_STATE,
  DEFAULT_STATUS,
  formatCancellationMessage,
  formatRelocateFailure,
  formatAreaLabel,
  isMissileMode,
  isSameArea,
} from '@/pages/control-panel/logic/deploymentMode';
import type { DeploymentMode } from '@/pages/control-panel/logic/deploymentMode';
import { getAreaLabel } from '@/constants/deployment';
import { generateDeploymentData } from '@/utils/deploymentGeometry';
import { createSeededRandom } from '@/utils/random';

// ============================================================================
// FIXTURES
// ============================================================================
const INLAND: Coordinate = { latitude: 23.9, longitude: 120.75 };
const OFFSHORE: Coordinate = { latitude: 23.9, longitude: 118.5 };

/** Fixed so the rejection-sampled layouts are identical on every run. */
const SEED = 42;

const UNIT_KEY = 'ascm_HF3_01';
const UNIT_NAME = 'HF3 Battery 1';

const JAMMERS = [
  { zoneName: 'Z1', name: 'EW North', randomRadiusNm: 5, radius: 50 },
  { zoneName: 'Z2', name: 'EW South', randomRadiusNm: 5, radius: 50 },
] as Jammer[];

function makeDeployment(): MissileDeployment {
  const data = generateDeploymentData({
    unitname: UNIT_NAME,
    category: 'ascm',
    center: INLAND,
    angle: 90,
    validateTaiwanBoundary: true,
    rng: createSeededRandom(SEED),
  });
  if (!data) throw new Error('fixture deployment failed to generate');
  return data;
}

let handlers: {
  onDeploySystem: ReturnType<typeof vi.fn>;
  onUndeploySystem: ReturnType<typeof vi.fn>;
  onDeployJammer: ReturnType<typeof vi.fn>;
  onUndeployJammer: ReturnType<typeof vi.fn>;
};

beforeEach(() => {
  handlers = {
    onDeploySystem: vi.fn(),
    onUndeploySystem: vi.fn(),
    onDeployJammer: vi.fn(),
    onUndeployJammer: vi.fn(),
  };
});

/**
 * Mirrors ControlDeploymentTab: the deployment state machine, rendered on its own.
 */
function setup(overrides: Partial<UseDeploymentStateParams> = {}) {
  // One stream per hook instance, created outside the render callback so the
  // reference stays stable and the sequence is not reset on every render.
  const rng = createSeededRandom(SEED);
  return renderHook(() =>
    useDeploymentState({
      jammers: JAMMERS,
      deployedMissileSystems: new Map(),
      deployedJammers: new Map(),
      shouldValidateTaiwanBoundary: true,
      rng,
      ...handlers,
      ...overrides,
    })
  );
}

/** Asserts the active mode and narrows it for the caller's follow-up checks */
function expectMode<K extends DeploymentMode['kind']>(
  mode: DeploymentMode,
  kind: K
): Extract<DeploymentMode, { kind: K }> {
  expect(mode.kind).toBe(kind);
  return mode as Extract<DeploymentMode, { kind: K }>;
}

function expectIdle(mode: DeploymentMode) {
  expect(mode).toEqual({ kind: 'idle' });
}

function pressEscape() {
  act(() => {
    window.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape' }));
  });
}

// ============================================================================
// PURE HELPERS
// ============================================================================
describe('formatAreaLabel', () => {
  it.each(['ushape', 'aha', 'hide', 'reload'] as const)('uses the plain label for %s', (type) => {
    expect(formatAreaLabel({ unitKey: UNIT_KEY, type })).toBe(getAreaLabel(type));
  });

  it('numbers fire points from 1', () => {
    expect(formatAreaLabel({ unitKey: UNIT_KEY, type: 'fp', fpIndex: 0 })).toBe('Fire Point 1');
    expect(formatAreaLabel({ unitKey: UNIT_KEY, type: 'fp', fpIndex: 1 })).toBe('Fire Point 2');
  });

  it('defaults a missing fire point index to the first', () => {
    expect(formatAreaLabel({ unitKey: UNIT_KEY, type: 'fp' })).toBe('Fire Point 1');
  });
});

describe('formatRelocateFailure', () => {
  it('reports a failed U-Shape regeneration', () => {
    expect(formatRelocateFailure({ code: 'ushape-generation-failed' })).toContain('U-Shape');
  });

  it('reports leaving the U-Shape boundary', () => {
    expect(formatRelocateFailure({ code: 'outside-boundary' })).toContain('boundary');
  });

  it('names the area that is in the way', () => {
    expect(formatRelocateFailure({ code: 'overlaps-other-area', other: 'reload' })).toContain(
      getAreaLabel('reload')
    );
    expect(formatRelocateFailure({ code: 'overlaps-other-area', other: 'hide' })).toContain(
      getAreaLabel('hide')
    );
  });
});

// ============================================================================
// MODE REDUCER
// ============================================================================
describe('deploymentModeReducer', () => {
  const AREA = { unitKey: UNIT_KEY, type: 'hide' as const };

  it('drops the previous mode on every transition', () => {
    const deploying = deploymentModeReducer(IDLE_STATE, {
      type: 'selectUnit',
      unit: { key: UNIT_KEY, name: UNIT_NAME, category: 'ascm' },
      offsets: {},
    });
    const rotating = deploymentModeReducer(deploying, {
      type: 'rotate',
      unitKey: UNIT_KEY,
      center: INLAND,
    });

    // No leftover deploy state to clean up — the union holds one mode at a time
    expect(rotating.mode.kind).toBe('rotate');
  });

  it('clears the cursor whenever the mode changes', () => {
    const hovering = deploymentModeReducer(
      { mode: { kind: 'relocateArea', area: AREA }, mousePosition: null },
      { type: 'hover', position: INLAND }
    );
    expect(hovering.mousePosition).toEqual(INLAND);

    const switched = deploymentModeReducer(hovering, {
      type: 'placeJammer',
      index: 0,
      isRelocate: false,
    });
    expect(switched.mousePosition).toBeNull();
  });

  it('records the swept angle only while rotating', () => {
    const rotating = deploymentModeReducer(IDLE_STATE, {
      type: 'rotate',
      unitKey: UNIT_KEY,
      center: INLAND,
    });
    const swept = deploymentModeReducer(rotating, {
      type: 'hover',
      position: INLAND,
      rotationAngle: 135,
    });
    expect(expectMode(swept.mode, 'rotate').previewAngle).toBe(135);

    const relocating = deploymentModeReducer(IDLE_STATE, { type: 'relocateArea', area: AREA });
    const ignored = deploymentModeReducer(relocating, {
      type: 'hover',
      position: INLAND,
      rotationAngle: 135,
    });
    expect(ignored.mode).toEqual({ kind: 'relocateArea', area: AREA });
  });

  it('classifies which modes block a jammer click', () => {
    expect(isMissileMode({ kind: 'relocateArea', area: AREA })).toBe(true);
    expect(
      isMissileMode({ kind: 'rotate', unitKey: UNIT_KEY, center: INLAND, previewAngle: null })
    ).toBe(true);
    expect(isMissileMode({ kind: 'placeJammer', index: 0, isRelocate: false })).toBe(false);
    expect(isMissileMode({ kind: 'idle' })).toBe(false);
  });

  it('compares areas by unit, type and fire point index', () => {
    expect(isSameArea(AREA, { ...AREA })).toBe(true);
    expect(isSameArea(AREA, { ...AREA, type: 'reload' })).toBe(false);
    const fp = { unitKey: UNIT_KEY, type: 'fp' as const, fpIndex: 0 };
    expect(isSameArea(fp, { ...fp, fpIndex: 1 })).toBe(false);
  });

  it('words the ESC message per mode', () => {
    expect(
      formatCancellationMessage({
        kind: 'rotate',
        unitKey: UNIT_KEY,
        center: INLAND,
        previewAngle: null,
      })
    ).toBe('Rotation cancelled');
    expect(formatCancellationMessage({ kind: 'relocateArea', area: AREA })).toBe(
      'Relocation cancelled'
    );
    expect(formatCancellationMessage({ kind: 'placeJammer', index: 0, isRelocate: true })).toBe(
      'Relocation cancelled'
    );
    expect(formatCancellationMessage({ kind: 'placeJammer', index: 0, isRelocate: false })).toBe(
      'Selection cancelled'
    );
  });
});

// ============================================================================
// INITIAL STATE
// ============================================================================
describe('useDeploymentState initial state', () => {
  it('starts idle', () => {
    const { result } = setup();
    expectIdle(result.current.mode);
    expect(result.current.mousePosition).toBeNull();
    expect(result.current.isPlacementActive).toBe(false);
    expect(result.current.status).toBe(DEFAULT_STATUS);
  });
});

// ============================================================================
// LOCK
// ============================================================================
describe('isLocked', () => {
  it('ignores every handler that edits a deployment', () => {
    const deployedMissileSystems = new Map([[UNIT_KEY, makeDeployment()]]);
    const { result } = setup({
      isLocked: true,
      deployedMissileSystems,
      deployedJammers: new Map([[0, INLAND]]),
    });

    act(() => {
      result.current.handleUnitSelect('ascm_other', 'Other', 'ascm');
      result.current.handleJammerSelect(1);
      result.current.handleAreaClick({ unitKey: UNIT_KEY, type: 'hide' });
      result.current.handleRotateClick(UNIT_KEY);
      result.current.handleJammerRelocateClick(0);
      result.current.handleUndeploy(UNIT_KEY, UNIT_NAME);
      result.current.handleUndeployJammer(0);
      result.current.handleMapClick(INLAND);
    });

    expectIdle(result.current.mode);
    expect(handlers.onUndeploySystem).not.toHaveBeenCalled();
    expect(handlers.onUndeployJammer).not.toHaveBeenCalled();
    expect(handlers.onDeploySystem).not.toHaveBeenCalled();
    expect(handlers.onDeployJammer).not.toHaveBeenCalled();
  });
});

// ============================================================================
// MODE ARBITRATION
// ============================================================================
describe('mode arbitration', () => {
  it('activates deploy mode on unit select', () => {
    const { result } = setup();
    act(() => result.current.handleUnitSelect(UNIT_KEY, UNIT_NAME, 'ascm'));

    expect(expectMode(result.current.mode, 'deploy').unit).toEqual({
      key: UNIT_KEY,
      name: UNIT_NAME,
      category: 'ascm',
    });
    expect(result.current.isPlacementActive).toBe(true);
    expect(result.current.status).toContain('selected');
  });

  it('expands an already deployed unit instead of arming a placement', () => {
    const deployedMissileSystems = new Map([[UNIT_KEY, makeDeployment()]]);
    const { result } = setup({ deployedMissileSystems });

    act(() => result.current.handleUnitSelect(UNIT_KEY, UNIT_NAME, 'ascm'));
    expectIdle(result.current.mode);
    expect(result.current.expandedUnitKey).toBe(UNIT_KEY);

    act(() => result.current.handleUnitSelect(UNIT_KEY, UNIT_NAME, 'ascm'));
    expect(result.current.expandedUnitKey).toBeNull();
  });

  it('drops a pending unit selection when a jammer is selected', () => {
    const { result } = setup();
    act(() => result.current.handleUnitSelect(UNIT_KEY, UNIT_NAME, 'ascm'));
    act(() => result.current.handleJammerSelect(0));

    expect(expectMode(result.current.mode, 'placeJammer')).toMatchObject({
      index: 0,
      isRelocate: false,
    });
    expect(result.current.placingJammerUnit).toEqual(JAMMERS[0]);
  });

  it('drops jammer placement when a unit is selected', () => {
    const { result } = setup();
    act(() => result.current.handleJammerSelect(0));
    act(() => result.current.handleUnitSelect(UNIT_KEY, UNIT_NAME, 'ascm'));

    expectMode(result.current.mode, 'deploy');
  });

  it('drops a pending unit selection when an area relocation starts', () => {
    const deployedMissileSystems = new Map([[UNIT_KEY, makeDeployment()]]);
    const { result } = setup({ deployedMissileSystems });
    act(() => result.current.handleUnitSelect('ascm_OTHER', 'Other', 'ascm'));
    act(() => result.current.handleAreaClick({ unitKey: UNIT_KEY, type: 'hide' }));

    expect(expectMode(result.current.mode, 'relocateArea').area).toEqual({
      unitKey: UNIT_KEY,
      type: 'hide',
    });
  });

  it('toggles area relocation off when the same area is clicked again', () => {
    const deployedMissileSystems = new Map([[UNIT_KEY, makeDeployment()]]);
    const { result } = setup({ deployedMissileSystems });
    const area = { unitKey: UNIT_KEY, type: 'fp' as const, fpIndex: 1 };

    act(() => result.current.handleAreaClick(area));
    expect(expectMode(result.current.mode, 'relocateArea').area).toEqual(area);
    act(() => result.current.handleAreaClick(area));
    expectIdle(result.current.mode);
    expect(result.current.status).toBe('Relocation cancelled');
  });

  it('ignores an area click while a jammer is being placed', () => {
    const deployedMissileSystems = new Map([[UNIT_KEY, makeDeployment()]]);
    const { result } = setup({ deployedMissileSystems });
    act(() => result.current.handleJammerSelect(0));
    act(() => result.current.handleAreaClick({ unitKey: UNIT_KEY, type: 'hide' }));

    expectMode(result.current.mode, 'placeJammer');
  });

  it('ignores a rotate click while a jammer is being placed', () => {
    const deployedMissileSystems = new Map([[UNIT_KEY, makeDeployment()]]);
    const { result } = setup({ deployedMissileSystems });
    act(() => result.current.handleJammerSelect(0));
    act(() => result.current.handleRotateClick(UNIT_KEY));

    expectMode(result.current.mode, 'placeJammer');
  });

  it('ignores a jammer relocate click while a missile mode is live', () => {
    const { result } = setup();
    act(() => result.current.handleUnitSelect(UNIT_KEY, UNIT_NAME, 'ascm'));
    act(() => result.current.handleJammerRelocateClick(0));

    expectMode(result.current.mode, 'deploy');
  });

  it('replaces area relocation with rotation', () => {
    const deployedMissileSystems = new Map([[UNIT_KEY, makeDeployment()]]);
    const { result } = setup({ deployedMissileSystems });
    act(() => result.current.handleAreaClick({ unitKey: UNIT_KEY, type: 'hide' }));
    act(() => result.current.handleRotateClick(UNIT_KEY));

    const rotating = expectMode(result.current.mode, 'rotate');
    expect(rotating.unitKey).toBe(UNIT_KEY);
    expect(rotating.center).toEqual(INLAND);
    expect(rotating.previewAngle).toBeNull();
  });

  it('ignores rotation of an undeployed unit', () => {
    const { result } = setup();
    act(() => result.current.handleRotateClick(UNIT_KEY));
    expectIdle(result.current.mode);
  });
});

// ============================================================================
// ESC CANCELLATION
// ============================================================================
describe('ESC cancellation', () => {
  it('cancels a pending unit selection', () => {
    const { result } = setup();
    act(() => result.current.handleUnitSelect(UNIT_KEY, UNIT_NAME, 'ascm'));
    pressEscape();

    expectIdle(result.current.mode);
    expect(result.current.status).toBe('Selection cancelled');
  });

  it('cancels area relocation', () => {
    const deployedMissileSystems = new Map([[UNIT_KEY, makeDeployment()]]);
    const { result } = setup({ deployedMissileSystems });
    act(() => result.current.handleAreaClick({ unitKey: UNIT_KEY, type: 'reload' }));
    pressEscape();

    expectIdle(result.current.mode);
    expect(result.current.status).toBe('Relocation cancelled');
  });

  it('cancels rotation', () => {
    const deployedMissileSystems = new Map([[UNIT_KEY, makeDeployment()]]);
    const { result } = setup({ deployedMissileSystems });
    act(() => result.current.handleRotateClick(UNIT_KEY));
    pressEscape();

    expectIdle(result.current.mode);
    expect(result.current.status).toBe('Rotation cancelled');
  });

  it('cancels jammer relocation', () => {
    const deployedJammers = new Map([[0, INLAND]]);
    const { result } = setup({ deployedJammers });
    act(() => result.current.handleJammerRelocateClick(0));
    pressEscape();

    expectIdle(result.current.mode);
    expect(result.current.status).toBe('Relocation cancelled');
  });

  it('reads the mode at key-press time, not at listener registration', () => {
    const deployedMissileSystems = new Map([[UNIT_KEY, makeDeployment()]]);
    const { result } = setup({ deployedMissileSystems });
    // The listener is keyed on "a mode is live", so this switch does not
    // re-register it — the message still has to follow the current mode.
    act(() => result.current.handleUnitSelect('ascm_OTHER', 'Other', 'ascm'));
    act(() => result.current.handleRotateClick(UNIT_KEY));
    pressEscape();

    expect(result.current.status).toBe('Rotation cancelled');
  });

  it('ignores other keys', () => {
    const { result } = setup();
    act(() => result.current.handleUnitSelect(UNIT_KEY, UNIT_NAME, 'ascm'));
    act(() => {
      window.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter' }));
    });
    expectMode(result.current.mode, 'deploy');
  });

  it('does nothing when no mode is active', () => {
    const { result } = setup();
    pressEscape();
    expect(result.current.status).toBe(DEFAULT_STATUS);
  });
});

// ============================================================================
// MAP CLICK COMMITS
// ============================================================================
describe('handleMapClick', () => {
  it('deploys the selected unit on an inland click', () => {
    const { result } = setup();
    act(() => result.current.handleUnitSelect(UNIT_KEY, UNIT_NAME, 'ascm'));
    act(() => result.current.handleMapClick(INLAND));

    expect(handlers.onDeploySystem).toHaveBeenCalledOnce();
    const [key, data] = handlers.onDeploySystem.mock.calls[0];
    expect(key).toBe(UNIT_KEY);
    expect(data.center).toEqual(INLAND);
    expectIdle(result.current.mode);
    expect(result.current.status).toContain('Done:');
  });

  it('refuses an offshore click and keeps the unit selected', () => {
    const { result } = setup();
    act(() => result.current.handleUnitSelect(UNIT_KEY, UNIT_NAME, 'ascm'));
    act(() => result.current.handleMapClick(OFFSHORE));

    expect(handlers.onDeploySystem).not.toHaveBeenCalled();
    expectMode(result.current.mode, 'deploy');
    expect(result.current.status).toContain('Taiwan mainland');
  });

  it('allows an offshore click when the boundary rule is off', () => {
    const { result } = setup({ shouldValidateTaiwanBoundary: false });
    act(() => result.current.handleUnitSelect(UNIT_KEY, UNIT_NAME, 'ascm'));
    act(() => result.current.handleMapClick(OFFSHORE));

    expect(handlers.onDeploySystem).toHaveBeenCalledOnce();
  });

  it('does nothing when no mode owns the click', () => {
    const { result } = setup();
    act(() => result.current.handleMapClick(INLAND));

    expect(handlers.onDeploySystem).not.toHaveBeenCalled();
    expect(handlers.onDeployJammer).not.toHaveBeenCalled();
    expect(result.current.coordinates).toEqual(INLAND);
  });

  it('deploys a jammer and leaves placement mode', () => {
    const { result } = setup();
    act(() => result.current.handleJammerSelect(1));
    act(() => result.current.handleMapClick(INLAND));

    expect(handlers.onDeployJammer).toHaveBeenCalledWith(1, INLAND);
    expectIdle(result.current.mode);
    expect(result.current.status).toContain('Done:');
  });

  it('refuses an offshore jammer placement', () => {
    const { result } = setup();
    act(() => result.current.handleJammerSelect(1));
    act(() => result.current.handleMapClick(OFFSHORE));

    expect(handlers.onDeployJammer).not.toHaveBeenCalled();
    expectMode(result.current.mode, 'placeJammer');
    expect(result.current.status).toContain('EW units');
  });

  it('reports relocation wording when committing a jammer relocation', () => {
    const deployedJammers = new Map([[0, OFFSHORE]]);
    const { result } = setup({ deployedJammers });
    act(() => result.current.handleJammerRelocateClick(0));
    act(() => result.current.handleMapClick(INLAND));

    expect(handlers.onDeployJammer).toHaveBeenCalledWith(0, INLAND);
    expect(result.current.status).toContain('relocated');
  });

  it('ignores a rotation click before an angle has been swept', () => {
    const deployedMissileSystems = new Map([[UNIT_KEY, makeDeployment()]]);
    const { result } = setup({ deployedMissileSystems });
    act(() => result.current.handleRotateClick(UNIT_KEY));
    act(() => result.current.handleMapClick(INLAND));

    expect(handlers.onDeploySystem).not.toHaveBeenCalled();
    expectMode(result.current.mode, 'rotate');
  });

  it('commits a rotation once an angle has been previewed', () => {
    const deployedMissileSystems = new Map([[UNIT_KEY, makeDeployment()]]);
    const { result } = setup({ deployedMissileSystems });
    act(() => result.current.handleRotateClick(UNIT_KEY));
    act(() => result.current.handleMouseMove({ ...INLAND, longitude: INLAND.longitude - 0.2 }));
    expect(result.current.rotationPreviewData).not.toBeNull();

    act(() => result.current.handleMapClick({ ...INLAND, longitude: INLAND.longitude - 0.2 }));

    expect(handlers.onDeploySystem).toHaveBeenCalledOnce();
    expectIdle(result.current.mode);
    expect(result.current.status).toContain('Angle set to');
  });

  it('relocates a hide area and reports the move', () => {
    const deployment = makeDeployment();
    const deployedMissileSystems = new Map([[UNIT_KEY, deployment]]);
    const { result } = setup({ deployedMissileSystems });
    const target = deployment.tacticalAreas.hideArea![0];

    act(() => result.current.handleAreaClick({ unitKey: UNIT_KEY, type: 'hide' }));
    act(() => result.current.handleMapClick(target));

    // Either the move lands (deployment pushed, mode cleared) or the position is
    // rejected with a warning; both must leave a coherent state.
    if (handlers.onDeploySystem.mock.calls.length > 0) {
      expectIdle(result.current.mode);
      expect(result.current.status).toContain(getAreaLabel('hide'));
    } else {
      expectMode(result.current.mode, 'relocateArea');
      expect(result.current.status).toContain('Warning');
    }
  });

  it('leaves relocation mode when the unit disappeared underneath it', () => {
    const deployedMissileSystems = new Map([[UNIT_KEY, makeDeployment()]]);
    const { result, rerender } = setup({ deployedMissileSystems });
    act(() => result.current.handleAreaClick({ unitKey: UNIT_KEY, type: 'hide' }));

    deployedMissileSystems.delete(UNIT_KEY);
    rerender();
    act(() => result.current.handleMapClick(INLAND));

    expect(handlers.onDeploySystem).not.toHaveBeenCalled();
    expectIdle(result.current.mode);
  });
});

// ============================================================================
// PREVIEWS
// ============================================================================
describe('preview data', () => {
  it('has no preview until the mouse moves', () => {
    const { result } = setup();
    act(() => result.current.handleUnitSelect(UNIT_KEY, UNIT_NAME, 'ascm'));
    expect(result.current.previewData).toBeNull();
  });

  it('translates the precomputed offsets to the cursor', () => {
    const { result } = setup();
    act(() => result.current.handleUnitSelect(UNIT_KEY, UNIT_NAME, 'ascm'));
    act(() => result.current.handleMouseMove(INLAND));

    const preview = result.current.previewData!;
    expect(preview.uShapeVertices).toHaveLength(4);
    expect(preview.isValid).toBe(true);
    for (const vertex of preview.uShapeVertices) {
      expect(Math.abs(vertex.latitude - INLAND.latitude)).toBeLessThan(0.1);
      expect(Math.abs(vertex.longitude - INLAND.longitude)).toBeLessThan(0.1);
    }
  });

  it('marks an offshore preview invalid without blocking it', () => {
    const { result } = setup();
    act(() => result.current.handleUnitSelect(UNIT_KEY, UNIT_NAME, 'ascm'));
    act(() => result.current.handleMouseMove(OFFSHORE));

    expect(result.current.previewData!.isValid).toBe(false);
  });

  it('follows the cursor while relocating an area', () => {
    const deployedMissileSystems = new Map([[UNIT_KEY, makeDeployment()]]);
    const { result } = setup({ deployedMissileSystems });
    act(() => result.current.handleAreaClick({ unitKey: UNIT_KEY, type: 'hide' }));
    act(() => result.current.handleMouseMove({ ...INLAND, latitude: INLAND.latitude + 0.01 }));

    const vertices = result.current.relocatePreviewVertices!;
    expect(vertices).toHaveLength(4);
    for (const vertex of vertices) {
      expect(vertex.latitude).toBeCloseTo(INLAND.latitude + 0.01, 2);
    }
  });

  it('ignores mouse movement when no mode is active', () => {
    const { result } = setup();
    act(() => result.current.handleMouseMove(INLAND));
    expect(result.current.mousePosition).toBeNull();
  });

  it('drops a stale hover preview when the mode changes', () => {
    const { result } = setup();
    act(() => result.current.handleUnitSelect(UNIT_KEY, UNIT_NAME, 'ascm'));
    act(() => result.current.handleMouseMove(INLAND));
    expect(result.current.previewData).not.toBeNull();

    act(() => result.current.handleJammerSelect(0));
    expect(result.current.mousePosition).toBeNull();
    expect(result.current.previewData).toBeNull();
  });
});

// ============================================================================
// UNDEPLOY
// ============================================================================
describe('undeploy', () => {
  it('reports the cancelled missile deployment', () => {
    const { result } = setup();
    act(() => result.current.handleUndeploy(UNIT_KEY, UNIT_NAME));

    expect(handlers.onUndeploySystem).toHaveBeenCalledWith(UNIT_KEY);
    expect(result.current.status).toContain(UNIT_NAME);
  });

  it('leaves placement mode when the jammer being placed is undeployed', () => {
    const deployedJammers = new Map([[0, INLAND]]);
    const { result } = setup({ deployedJammers });
    act(() => result.current.handleJammerRelocateClick(0));
    act(() => result.current.handleUndeployJammer(0));

    expect(handlers.onUndeployJammer).toHaveBeenCalledWith(0);
    expectIdle(result.current.mode);
  });

  it('keeps placement mode when a different jammer is undeployed', () => {
    const deployedJammers = new Map([[1, INLAND]]);
    const { result } = setup({ deployedJammers });
    act(() => result.current.handleJammerSelect(0));
    act(() => result.current.handleUndeployJammer(1));

    expect(expectMode(result.current.mode, 'placeJammer').index).toBe(0);
  });
});
