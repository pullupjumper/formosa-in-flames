import { describe, it, expect, vi, beforeEach } from 'vitest';
import { act, renderHook } from '@testing-library/react';
import type { DeployedMissileSystemData, Jammer, MissileSystems } from '@/types/setupMenu';
import {
  useDeploymentState,
  formatAreaLabel,
  AREA_LABEL,
  DEFAULT_STATUS,
  AIRCRAFT_PANEL_STATUS,
} from '@/pages/setup-menu/hooks/useDeploymentState';
import type { UseDeploymentStateParams } from '@/pages/setup-menu/hooks/useDeploymentState';
import { generateDeploymentData } from '@/utils/missileDeployment';
import { createSeededRandom } from '@/utils/random';

// ============================================================================
// FIXTURES
// ============================================================================
const INLAND = { lat: 23.9, lng: 120.75 };
const OFFSHORE = { lat: 23.9, lng: 118.5 };

/** Fixed so the rejection-sampled layouts are identical on every run. */
const SEED = 42;

const UNIT_KEY = 'ascm_HF3_01';
const UNIT_NAME = 'HF3 Battery 1';

const MISSILE_SYSTEMS = {
  ascm: {
    firingUnits: {
      HF3_01: { name: UNIT_NAME },
    },
  },
} as unknown as MissileSystems;

const JAMMERS = [
  { zoneName: 'Z1', name: 'EW North', randomRadius: 5, radius: 50 },
  { zoneName: 'Z2', name: 'EW South', randomRadius: 5, radius: 50 },
] as Jammer[];

function makeDeployment(): DeployedMissileSystemData {
  const data = generateDeploymentData({
    unitName: UNIT_NAME,
    category: 'ascm',
    lat: INLAND.lat,
    lng: INLAND.lng,
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

function setup(overrides: Partial<UseDeploymentStateParams> = {}) {
  // One stream per hook instance, created outside the render callback so the
  // reference stays stable and the sequence is not reset on every render.
  const rng = createSeededRandom(SEED);
  return renderHook(() =>
    useDeploymentState({
      missileSystems: MISSILE_SYSTEMS,
      jammers: JAMMERS,
      deployedSystems: new Map(),
      deployedJammers: new Map(),
      shouldValidateTaiwanBoundary: true,
      rng,
      ...handlers,
      ...overrides,
    })
  );
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
    expect(formatAreaLabel({ unitKey: UNIT_KEY, type })).toBe(AREA_LABEL[type]);
  });

  it('numbers fire points from 1', () => {
    expect(formatAreaLabel({ unitKey: UNIT_KEY, type: 'fp', fpIndex: 0 })).toBe('Fire Point 1');
    expect(formatAreaLabel({ unitKey: UNIT_KEY, type: 'fp', fpIndex: 1 })).toBe('Fire Point 2');
  });

  it('defaults a missing fire point index to the first', () => {
    expect(formatAreaLabel({ unitKey: UNIT_KEY, type: 'fp' })).toBe('Fire Point 1');
  });
});

// ============================================================================
// INITIAL STATE
// ============================================================================
describe('useDeploymentState initial state', () => {
  it('starts idle on the aircraft panel', () => {
    const { result } = setup();
    expect(result.current.selectedUnit).toBeNull();
    expect(result.current.relocatingArea).toBeNull();
    expect(result.current.rotatingUnit).toBeNull();
    expect(result.current.placingJammer).toBeNull();
    expect(result.current.isPlacementActive).toBe(false);
    expect(result.current.status).toBe(DEFAULT_STATUS);
    // The generic hint is replaced while the aircraft panel is showing.
    expect(result.current.displayStatus).toBe(AIRCRAFT_PANEL_STATUS);
  });

  it('resolves a unit key back to its name and category', () => {
    const { result } = setup();
    expect(result.current.getUnitInfo(UNIT_KEY)).toEqual({ name: UNIT_NAME, category: 'ascm' });
    expect(result.current.getUnitInfo('ascm_UNKNOWN')).toBeNull();
    expect(result.current.getUnitInfo('nosuch_HF3_01')).toBeNull();
  });
});

// ============================================================================
// MODE ARBITRATION
// ============================================================================
describe('mode arbitration', () => {
  it('activates missile mode on unit select', () => {
    const { result } = setup();
    act(() => result.current.handleUnitSelect(UNIT_KEY, UNIT_NAME, 'ascm'));

    expect(result.current.selectedUnit).toEqual({
      key: UNIT_KEY,
      name: UNIT_NAME,
      category: 'ascm',
    });
    expect(result.current.isMissileModeActive).toBe(true);
    expect(result.current.status).toContain('selected');
  });

  it('ignores selecting an already deployed unit', () => {
    const deployedSystems = new Map([[UNIT_KEY, makeDeployment()]]);
    const { result } = setup({ deployedSystems });
    act(() => result.current.handleUnitSelect(UNIT_KEY, UNIT_NAME, 'ascm'));
    expect(result.current.selectedUnit).toBeNull();
  });

  it('drops a pending unit selection when a jammer is selected', () => {
    const { result } = setup();
    act(() => result.current.handleUnitSelect(UNIT_KEY, UNIT_NAME, 'ascm'));
    act(() => result.current.handleJammerSelect(0));

    expect(result.current.selectedUnit).toBeNull();
    expect(result.current.placingJammer).toEqual({ index: 0, isRelocate: false });
    expect(result.current.placingJammerUnit).toEqual(JAMMERS[0]);
  });

  it('drops jammer placement when a unit is selected', () => {
    const { result } = setup();
    act(() => result.current.handleJammerSelect(0));
    act(() => result.current.handleUnitSelect(UNIT_KEY, UNIT_NAME, 'ascm'));

    expect(result.current.placingJammer).toBeNull();
    expect(result.current.selectedUnit).not.toBeNull();
  });

  it('drops a pending unit selection when an area relocation starts', () => {
    const deployedSystems = new Map([[UNIT_KEY, makeDeployment()]]);
    const { result } = setup({ deployedSystems });
    act(() => result.current.handleUnitSelect('ascm_OTHER', 'Other', 'ascm'));
    act(() => result.current.handleAreaClick({ unitKey: UNIT_KEY, type: 'hide' }));

    expect(result.current.selectedUnit).toBeNull();
    expect(result.current.relocatingArea).toEqual({ unitKey: UNIT_KEY, type: 'hide' });
  });

  it('toggles area relocation off when the same area is clicked again', () => {
    const deployedSystems = new Map([[UNIT_KEY, makeDeployment()]]);
    const { result } = setup({ deployedSystems });
    const area = { unitKey: UNIT_KEY, type: 'fp' as const, fpIndex: 1 };

    act(() => result.current.handleAreaClick(area));
    expect(result.current.relocatingArea).toEqual(area);
    act(() => result.current.handleAreaClick(area));
    expect(result.current.relocatingArea).toBeNull();
    expect(result.current.status).toBe('Relocation cancelled');
  });

  it('ignores an area click while a jammer is being placed', () => {
    const deployedSystems = new Map([[UNIT_KEY, makeDeployment()]]);
    const { result } = setup({ deployedSystems });
    act(() => result.current.handleJammerSelect(0));
    act(() => result.current.handleAreaClick({ unitKey: UNIT_KEY, type: 'hide' }));

    expect(result.current.relocatingArea).toBeNull();
    expect(result.current.placingJammer).not.toBeNull();
  });

  it('ignores a rotate click while a jammer is being placed', () => {
    const deployedSystems = new Map([[UNIT_KEY, makeDeployment()]]);
    const { result } = setup({ deployedSystems });
    act(() => result.current.handleJammerSelect(0));
    act(() => result.current.handleRotateClick(UNIT_KEY));

    expect(result.current.rotatingUnit).toBeNull();
  });

  it('ignores a jammer relocate click while a missile mode is live', () => {
    const { result } = setup();
    act(() => result.current.handleUnitSelect(UNIT_KEY, UNIT_NAME, 'ascm'));
    act(() => result.current.handleJammerRelocateClick(0));

    expect(result.current.placingJammer).toBeNull();
    expect(result.current.selectedUnit).not.toBeNull();
  });

  it('replaces area relocation with rotation', () => {
    const deployedSystems = new Map([[UNIT_KEY, makeDeployment()]]);
    const { result } = setup({ deployedSystems });
    act(() => result.current.handleAreaClick({ unitKey: UNIT_KEY, type: 'hide' }));
    act(() => result.current.handleRotateClick(UNIT_KEY));

    expect(result.current.relocatingArea).toBeNull();
    expect(result.current.rotatingUnit).toEqual({ unitKey: UNIT_KEY, center: INLAND });
  });

  it('ignores rotation of an undeployed unit', () => {
    const { result } = setup();
    act(() => result.current.handleRotateClick(UNIT_KEY));
    expect(result.current.rotatingUnit).toBeNull();
  });

  it('suppresses airbase selection while a placement mode owns the map click', () => {
    const { result } = setup();
    act(() => result.current.handleUnitSelect(UNIT_KEY, UNIT_NAME, 'ascm'));
    act(() => result.current.handleAirbaseClick(2));
    expect(result.current.selectedBaseIndex).toBeNull();

    act(() => result.current.handleCancelSelect());
    act(() => result.current.handleAirbaseClick(2));
    expect(result.current.selectedBaseIndex).toBe(2);
    expect(result.current.sidebarPanel).toBe('aircraft');
  });

  it('clears pending modes when switching back to the aircraft panel', () => {
    const { result } = setup();
    act(() => result.current.handleSidebarPanelChange('ground'));
    act(() => result.current.handleUnitSelect(UNIT_KEY, UNIT_NAME, 'ascm'));
    act(() => result.current.handleSidebarPanelChange('aircraft'));

    expect(result.current.selectedUnit).toBeNull();
    expect(result.current.placingJammer).toBeNull();
    expect(result.current.isPlacementActive).toBe(false);
    expect(result.current.status).toBe(DEFAULT_STATUS);
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

    expect(result.current.selectedUnit).toBeNull();
    expect(result.current.status).toBe('Selection cancelled');
  });

  it('cancels area relocation', () => {
    const deployedSystems = new Map([[UNIT_KEY, makeDeployment()]]);
    const { result } = setup({ deployedSystems });
    act(() => result.current.handleAreaClick({ unitKey: UNIT_KEY, type: 'reload' }));
    pressEscape();

    expect(result.current.relocatingArea).toBeNull();
    expect(result.current.status).toBe('Relocation cancelled');
  });

  it('cancels rotation', () => {
    const deployedSystems = new Map([[UNIT_KEY, makeDeployment()]]);
    const { result } = setup({ deployedSystems });
    act(() => result.current.handleRotateClick(UNIT_KEY));
    pressEscape();

    expect(result.current.rotatingUnit).toBeNull();
    expect(result.current.status).toBe('Rotation cancelled');
  });

  it('cancels jammer relocation', () => {
    const deployedJammers = new Map([[0, INLAND]]);
    const { result } = setup({ deployedJammers });
    act(() => result.current.handleJammerRelocateClick(0));
    pressEscape();

    expect(result.current.placingJammer).toBeNull();
    expect(result.current.status).toBe('Relocation cancelled');
  });

  it('ignores other keys', () => {
    const { result } = setup();
    act(() => result.current.handleUnitSelect(UNIT_KEY, UNIT_NAME, 'ascm'));
    act(() => {
      window.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter' }));
    });
    expect(result.current.selectedUnit).not.toBeNull();
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
    act(() => result.current.handleMapClick(INLAND.lat, INLAND.lng));

    expect(handlers.onDeploySystem).toHaveBeenCalledOnce();
    const [key, data] = handlers.onDeploySystem.mock.calls[0];
    expect(key).toBe(UNIT_KEY);
    expect(data.center).toEqual(INLAND);
    expect(result.current.selectedUnit).toBeNull();
    expect(result.current.status).toContain('Done:');
  });

  it('refuses an offshore click and keeps the unit selected', () => {
    const { result } = setup();
    act(() => result.current.handleUnitSelect(UNIT_KEY, UNIT_NAME, 'ascm'));
    act(() => result.current.handleMapClick(OFFSHORE.lat, OFFSHORE.lng));

    expect(handlers.onDeploySystem).not.toHaveBeenCalled();
    expect(result.current.selectedUnit).not.toBeNull();
    expect(result.current.status).toContain('Taiwan mainland');
  });

  it('allows an offshore click when the boundary rule is off', () => {
    const { result } = setup({ shouldValidateTaiwanBoundary: false });
    act(() => result.current.handleUnitSelect(UNIT_KEY, UNIT_NAME, 'ascm'));
    act(() => result.current.handleMapClick(OFFSHORE.lat, OFFSHORE.lng));

    expect(handlers.onDeploySystem).toHaveBeenCalledOnce();
  });

  it('does nothing when no mode owns the click', () => {
    const { result } = setup();
    act(() => result.current.handleMapClick(INLAND.lat, INLAND.lng));

    expect(handlers.onDeploySystem).not.toHaveBeenCalled();
    expect(handlers.onDeployJammer).not.toHaveBeenCalled();
    expect(result.current.coordinates).toEqual(INLAND);
  });

  it('deploys a jammer and leaves placement mode', () => {
    const { result } = setup();
    act(() => result.current.handleJammerSelect(1));
    act(() => result.current.handleMapClick(INLAND.lat, INLAND.lng));

    expect(handlers.onDeployJammer).toHaveBeenCalledWith(1, INLAND.lat, INLAND.lng);
    expect(result.current.placingJammer).toBeNull();
    expect(result.current.status).toContain('Done:');
  });

  it('refuses an offshore jammer placement', () => {
    const { result } = setup();
    act(() => result.current.handleJammerSelect(1));
    act(() => result.current.handleMapClick(OFFSHORE.lat, OFFSHORE.lng));

    expect(handlers.onDeployJammer).not.toHaveBeenCalled();
    expect(result.current.placingJammer).not.toBeNull();
    expect(result.current.status).toContain('EW units');
  });

  it('reports relocation wording when committing a jammer relocation', () => {
    const deployedJammers = new Map([[0, OFFSHORE]]);
    const { result } = setup({ deployedJammers });
    act(() => result.current.handleJammerRelocateClick(0));
    act(() => result.current.handleMapClick(INLAND.lat, INLAND.lng));

    expect(handlers.onDeployJammer).toHaveBeenCalledWith(0, INLAND.lat, INLAND.lng);
    expect(result.current.status).toContain('relocated');
  });

  it('commits a rotation once an angle has been previewed', () => {
    const deployedSystems = new Map([[UNIT_KEY, makeDeployment()]]);
    const { result } = setup({ deployedSystems });
    act(() => result.current.handleRotateClick(UNIT_KEY));
    act(() => result.current.handleMouseMove(INLAND.lat, INLAND.lng - 0.2));
    const previewedAngle = result.current.rotationPreviewData;
    expect(previewedAngle).not.toBeNull();

    act(() => result.current.handleMapClick(INLAND.lat, INLAND.lng - 0.2));

    expect(handlers.onDeploySystem).toHaveBeenCalledOnce();
    expect(result.current.rotatingUnit).toBeNull();
    expect(result.current.status).toContain('Angle set to');
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
    act(() => result.current.handleMouseMove(INLAND.lat, INLAND.lng));

    const preview = result.current.previewData!;
    expect(preview.uShapeVertices).toHaveLength(4);
    expect(preview.isValid).toBe(true);
    for (const vertex of preview.uShapeVertices) {
      expect(Math.abs(vertex.latitude - INLAND.lat)).toBeLessThan(0.1);
      expect(Math.abs(vertex.longitude - INLAND.lng)).toBeLessThan(0.1);
    }
  });

  it('marks an offshore preview invalid without blocking it', () => {
    const { result } = setup();
    act(() => result.current.handleUnitSelect(UNIT_KEY, UNIT_NAME, 'ascm'));
    act(() => result.current.handleMouseMove(OFFSHORE.lat, OFFSHORE.lng));

    expect(result.current.previewData!.isValid).toBe(false);
  });

  it('follows the cursor while relocating an area', () => {
    const deployedSystems = new Map([[UNIT_KEY, makeDeployment()]]);
    const { result } = setup({ deployedSystems });
    act(() => result.current.handleAreaClick({ unitKey: UNIT_KEY, type: 'hide' }));
    act(() => result.current.handleMouseMove(INLAND.lat + 0.01, INLAND.lng));

    const vertices = result.current.relocatePreviewVertices!;
    expect(vertices).toHaveLength(4);
    for (const vertex of vertices) {
      expect(vertex.latitude).toBeCloseTo(INLAND.lat + 0.01, 2);
    }
  });

  it('ignores mouse movement when no mode is active', () => {
    const { result } = setup();
    act(() => result.current.handleMouseMove(INLAND.lat, INLAND.lng));
    expect(result.current.mousePosition).toBeNull();
  });
});

// ============================================================================
// SIDEBAR COLLAPSE
// ============================================================================
describe('sidebar collapse', () => {
  it('drops a pending selection in the collapsed category', () => {
    const { result } = setup();
    act(() => result.current.handleUnitSelect(UNIT_KEY, UNIT_NAME, 'ascm'));
    act(() => result.current.toggleCategory('ascm'));

    expect(result.current.collapsedCategories.has('ascm')).toBe(true);
    expect(result.current.selectedUnit).toBeNull();
    expect(result.current.status).toBe(DEFAULT_STATUS);
  });

  it('keeps a selection in a different category', () => {
    const { result } = setup();
    act(() => result.current.handleUnitSelect(UNIT_KEY, UNIT_NAME, 'ascm'));
    act(() => result.current.toggleCategory('sam'));

    expect(result.current.selectedUnit).not.toBeNull();
  });

  it('drops a pending jammer deployment when the jammer list collapses', () => {
    const { result } = setup();
    act(() => result.current.handleJammerSelect(0));
    act(() => result.current.toggleJammers());

    expect(result.current.jammersCollapsed).toBe(true);
    expect(result.current.placingJammer).toBeNull();
  });

  it('keeps a map-driven jammer relocation when the list collapses', () => {
    const deployedJammers = new Map([[0, INLAND]]);
    const { result } = setup({ deployedJammers });
    act(() => result.current.handleJammerRelocateClick(0));
    act(() => result.current.toggleJammers());

    expect(result.current.placingJammer).toEqual({ index: 0, isRelocate: true });
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
    expect(result.current.placingJammer).toBeNull();
  });
});
