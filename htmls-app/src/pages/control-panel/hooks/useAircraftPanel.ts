import { useCallback, useEffect, useRef, useState } from 'react';
import { DEFAULT_STATUS } from './deploymentMode';

/**
 * Sidebar panel switching and airbase selection. Split from the deployment
 * state machine because the only coupling is one-way: entering this panel has
 * to drop whatever placement mode owns the map click.
 */

// ============================================================================
// UI CONSTANTS
// ============================================================================
export const AIRCRAFT_PANEL_STATUS = 'Select an airbase on the map to edit its loadouts';

// ============================================================================
// TYPES
// ============================================================================
export type SidebarPanel = 'aircraft' | 'ground';

export interface UseAircraftPanelParams {
  /** Raw status line owned by the deployment hook */
  status: string;
  /** True while a placement mode owns the next map click */
  isPlacementActive: boolean;
  /** Drops any pending placement mode; invoked when this panel takes over */
  onEnterPanel: () => void;
}

// ============================================================================
// HOOK
// ============================================================================
export function useAircraftPanel({
  status,
  isPlacementActive,
  onEnterPanel,
}: UseAircraftPanelParams) {
  const [sidebarPanel, setSidebarPanel] = useState<SidebarPanel>('aircraft');
  const [selectedBaseIndex, setSelectedBaseIndex] = useState<number | null>(null);

  // AirbaseMarkers is memoized, so these handlers have to keep a stable
  // identity; the live values are read through refs instead. Kept inline
  // because React Compiler only infers stability from `useRef` directly — a
  // shared helper hook would turn these into dependencies of the callbacks.
  const isPlacementActiveRef = useRef(isPlacementActive);
  useEffect(() => {
    isPlacementActiveRef.current = isPlacementActive;
  }, [isPlacementActive]);
  const onEnterPanelRef = useRef(onEnterPanel);
  useEffect(() => {
    onEnterPanelRef.current = onEnterPanel;
  }, [onEnterPanel]);

  /**
   * Selecting a base switches the sidebar to this panel. Guarded so a stray
   * airbase click cannot swallow a pending deployment.
   */
  const handleAirbaseClick = useCallback((index: number) => {
    if (isPlacementActiveRef.current) return;
    setSelectedBaseIndex(index);
    setSidebarPanel('aircraft');
  }, []);

  const handleSidebarPanelChange = useCallback((panel: SidebarPanel) => {
    setSidebarPanel(panel);
    // handleAirbaseClick suppresses base selection while a placement mode is
    // live, so map-driven modes have to be cleared here too — otherwise the
    // panel is silently inert until the user happens to press ESC.
    if (panel === 'aircraft') onEnterPanelRef.current();
  }, []);

  // The generic hint is about placing units, which does not apply here. Any
  // real deployment result still shows through.
  const displayStatus =
    sidebarPanel === 'aircraft' && status === DEFAULT_STATUS ? AIRCRAFT_PANEL_STATUS : status;

  return {
    sidebarPanel,
    selectedBaseIndex,
    displayStatus,
    handleAirbaseClick,
    handleSidebarPanelChange,
  };
}
