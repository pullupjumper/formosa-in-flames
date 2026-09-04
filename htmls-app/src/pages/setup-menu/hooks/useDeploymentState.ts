import { useState, useCallback, useRef, useReducer, useEffect } from 'react';
import type { MissileSystems, DeployedMissileSystemData, Jammer } from '@/types/setupMenu';
import type { RelocatingArea } from '@/components/Map';
import { isPointInTaiwan, determineOpeningAngle, parseUnitKey } from '@/utils/map';
import { calculateBearing } from '@/utils/tacticalAreaGenerator';
import {
  buildMovementPaths,
  generateDeploymentData,
  generateOffsetsForAngle,
  isValidAngle,
  relocateArea,
} from '@/utils/missileDeployment';
import type { PreviewOffsets } from '@/utils/missileDeployment';
import type { RandomSource } from '@/utils/random';
import {
  DEFAULT_STATUS,
  IDLE_STATE,
  OUT_OF_BOUNDS_JAMMER,
  OUT_OF_BOUNDS_MISSILE,
  cancellationMessage,
  deploymentModeReducer,
  describeRelocateFailure,
  formatAreaLabel,
  isMissileMode,
  isPlacementMode,
  isSameArea,
} from './deploymentMode';
import type { DeploymentMode, SelectedUnit } from './deploymentMode';
import { useDeploymentPreviews } from './useDeploymentPreviews';

/**
 * Interaction state for the Deployment tab: which mode owns the next map click,
 * what the hover preview shows, and the status line. Kept apart from
 * DeploymentTab's markup so the mode arbitration can be exercised without
 * mounting Leaflet.
 */

// ============================================================================
// UI CONSTANTS
// ============================================================================
/** Hover previews regenerate geometry, so cap them well below frame rate */
const MOUSE_MOVE_THROTTLE_MS = 50;

// ============================================================================
// TYPES
// ============================================================================
export interface UseDeploymentStateParams {
  missileSystems: MissileSystems;
  jammers: Jammer[];
  deployedSystems: Map<string, DeployedMissileSystemData>;
  deployedJammers: Map<number, { lat: number; lng: number }>;
  shouldValidateTaiwanBoundary: boolean;
  onDeploySystem: (key: string, data: DeployedMissileSystemData) => void;
  onUndeploySystem: (key: string) => void;
  onDeployJammer: (index: number, lat: number, lng: number) => void;
  onUndeployJammer: (index: number) => void;
  /**
   * Defaults to `Math.random`. Pass a seeded source to make the generated
   * layouts reproducible; the reference must be stable across renders.
   */
  rng?: RandomSource;
}

// ============================================================================
// HOOK
// ============================================================================
export function useDeploymentState({
  missileSystems,
  jammers,
  deployedSystems,
  deployedJammers,
  shouldValidateTaiwanBoundary,
  onDeploySystem,
  onUndeploySystem,
  onDeployJammer,
  onUndeployJammer,
  rng = Math.random,
}: UseDeploymentStateParams) {
  const [{ mode, mousePosition }, dispatch] = useReducer(deploymentModeReducer, IDLE_STATE);
  const [status, setStatus] = useState(DEFAULT_STATUS);
  const [coordinates, setCoordinates] = useState<{ lat: number; lng: number } | null>(null);

  // Sidebar presentation state, independent of the mode machine
  const [expandedUnitKey, setExpandedUnitKey] = useState<string | null>(null);
  const [collapsedCategories, setCollapsedCategories] = useState<Set<string>>(new Set());
  const [expandedJammerIndex, setExpandedJammerIndex] = useState<number | null>(null);
  const [jammersCollapsed, setJammersCollapsed] = useState(false);

  const lastMouseMoveRef = useRef(0);
  const isPlacementActive = isPlacementMode(mode);

  // Marker layers are memoized, so their click handlers must keep a stable
  // identity; they read the live values through these refs.
  //
  // Deliberately inlined rather than extracted into a `useLatestRef` helper:
  // React Compiler only treats `useRef` itself as returning a stable value, so
  // routing these through a custom hook makes the ref an inferred dependency of
  // every `useCallback([], ...)` below and disables optimization for this file.
  const modeRef = useRef<DeploymentMode>(mode);
  useEffect(() => {
    modeRef.current = mode;
  }, [mode]);
  const deployedSystemsRef = useRef(deployedSystems);
  useEffect(() => {
    deployedSystemsRef.current = deployedSystems;
  }, [deployedSystems]);
  const jammersRef = useRef(jammers);
  useEffect(() => {
    jammersRef.current = jammers;
  }, [jammers]);

  const getUnitInfo = useCallback(
    (unitKey: string) => {
      const { category, unitName } = parseUnitKey(unitKey);
      const unit = missileSystems[category]?.firingUnits?.[unitName];
      if (!unit) return null;
      return { name: unit.name, category };
    },
    [missileSystems]
  );

  /** Injects the side's boundary rule into the pure generator */
  const createDeployment = useCallback(
    (
      unitName: string,
      category: string,
      lat: number,
      lng: number,
      angle: number,
      ahaRadiusOverride?: number,
      ahaCenterOverride?: { lat: number; lng: number }
    ): DeployedMissileSystemData | null =>
      generateDeploymentData({
        unitName,
        category,
        lat,
        lng,
        angle,
        validateTaiwanBoundary: shouldValidateTaiwanBoundary,
        ahaRadiusOverride,
        ahaCenterOverride,
        rng,
      }),
    [shouldValidateTaiwanBoundary, rng]
  );

  /**
   * Re-generate the deployment at a new opening angle. Returns false when the
   * angle is unusable — the rotated U-shape left the boundary, or no valid
   * gateway was found — so the caller can keep the user in rotation mode.
   */
  const applyAngleChange = useCallback(
    (unitKey: string, newAngle: number): boolean => {
      const deployment = deployedSystems.get(unitKey);
      if (!deployment || !isValidAngle(newAngle)) return false;

      const newData = createDeployment(
        deployment.unitName,
        deployment.category,
        deployment.center.lat,
        deployment.center.lng,
        newAngle,
        deployment.ahaRadius,
        deployment.ahaCenter
      );
      if (!newData) return false;

      // Preserve existing fire points (like AHA)
      newData.tacticalAreas.firePoints = deployment.tacticalAreas.firePoints;
      newData.paths = buildMovementPaths(newData.tacticalAreas, {
        centerLat: deployment.center.lat,
        centerLng: deployment.center.lng,
        openingAngle: newAngle,
      });
      onDeploySystem(unitKey, newData);
      return true;
    },
    [deployedSystems, createDeployment, onDeploySystem]
  );

  // ============================================================================
  // Commit Paths — one per mode, all reached from handleMapClick
  // ============================================================================
  const commitJammerPlacement = useCallback(
    (index: number, isRelocate: boolean, lat: number, lng: number) => {
      const jammer = jammers[index];
      if (!jammer) {
        dispatch({ type: 'reset' });
        return;
      }
      if (shouldValidateTaiwanBoundary && !isPointInTaiwan(lat, lng)) {
        setStatus(OUT_OF_BOUNDS_JAMMER);
        return;
      }
      onDeployJammer(index, lat, lng);
      setStatus(
        isRelocate
          ? `${jammer.name} relocated to ${lat.toFixed(4)}°, ${lng.toFixed(4)}°`
          : `Done: ${jammer.name} deployed at ${lat.toFixed(4)}°, ${lng.toFixed(4)}°`
      );
      dispatch({ type: 'reset' });
    },
    [jammers, shouldValidateTaiwanBoundary, onDeployJammer]
  );

  const commitRotation = useCallback(
    (unitKey: string, angle: number) => {
      const label = deployedSystems.get(unitKey)?.unitName ?? unitKey;
      if (!applyAngleChange(unitKey, angle)) {
        // Stay in rotation mode: the unit keeps its old angle and the user can
        // sweep to another one without restarting.
        setStatus(`Warning: ${angle}° leaves no valid layout for ${label}`);
        return;
      }
      setStatus(`Angle set to ${angle}° for ${label}`);
      dispatch({ type: 'reset' });
    },
    [deployedSystems, applyAngleChange]
  );

  const commitAreaRelocation = useCallback(
    (area: RelocatingArea, lat: number, lng: number) => {
      const deployment = deployedSystems.get(area.unitKey);
      if (!deployment) {
        dispatch({ type: 'reset' });
        return;
      }

      const result = relocateArea({
        deployment,
        target: area,
        lat,
        lng,
        validateTaiwanBoundary: shouldValidateTaiwanBoundary,
        rng,
      });
      if (!result.ok) {
        setStatus(describeRelocateFailure(result.failure));
        return;
      }

      onDeploySystem(area.unitKey, result.data);
      setStatus(`${formatAreaLabel(area)} relocated for ${deployment.unitName}`);
      dispatch({ type: 'reset' });
    },
    [deployedSystems, shouldValidateTaiwanBoundary, rng, onDeploySystem]
  );

  const commitDeployment = useCallback(
    (unit: SelectedUnit, lat: number, lng: number) => {
      if (shouldValidateTaiwanBoundary && !isPointInTaiwan(lat, lng)) {
        setStatus(OUT_OF_BOUNDS_MISSILE);
        return;
      }

      const autoAngle = determineOpeningAngle(lat, lng);

      // Preview offsets pre-compute a specific HA/RL layout, but we need both
      // FP and SHRL gateways to exist. Delegate to createDeployment which has
      // the outer retry loop that regenerates HA/RL when gateways fail.
      const deployment = createDeployment(unit.name, unit.category, lat, lng, autoAngle);
      if (!deployment) {
        // The clicked point already passed the boundary check above, so the
        // failure is the surrounding areas spilling out or no gateway fitting.
        setStatus(
          shouldValidateTaiwanBoundary
            ? 'Warning: Tactical areas extend past the coast, pick a point further inland'
            : 'Warning: Failed to place tactical areas at this location'
        );
        return;
      }

      onDeploySystem(unit.key, deployment);
      setStatus(
        `Done: ${unit.name} deployed at ${lat.toFixed(4)}, ${lng.toFixed(4)}, Angle: ${autoAngle}`
      );
      dispatch({ type: 'reset' });
    },
    [shouldValidateTaiwanBoundary, createDeployment, onDeploySystem]
  );

  const handleMapClick = useCallback(
    (lat: number, lng: number) => {
      setCoordinates({ lat, lng });
      setExpandedUnitKey(null);
      setExpandedJammerIndex(null);

      switch (mode.kind) {
        case 'idle':
          return;
        case 'placeJammer':
          return commitJammerPlacement(mode.index, mode.isRelocate, lat, lng);
        case 'rotate':
          // No angle swept yet, so there is nothing to commit
          if (mode.previewAngle === null) return;
          return commitRotation(mode.unitKey, mode.previewAngle);
        case 'relocateArea':
          return commitAreaRelocation(mode.area, lat, lng);
        case 'deploy':
          return commitDeployment(mode.unit, lat, lng);
      }
    },
    [mode, commitJammerPlacement, commitRotation, commitAreaRelocation, commitDeployment]
  );

  const handleMouseMove = useCallback((lat: number, lng: number) => {
    const current = modeRef.current;
    if (current.kind === 'idle') return;

    const now = Date.now();
    if (now - lastMouseMoveRef.current < MOUSE_MOVE_THROTTLE_MS) return;
    lastMouseMoveRef.current = now;

    if (current.kind !== 'rotate') {
      dispatch({ type: 'hover', lat, lng });
      return;
    }

    const angle = Math.round(calculateBearing(current.center.lat, current.center.lng, lat, lng));
    dispatch({ type: 'hover', lat, lng, rotationAngle: angle });
    setStatus(`Rotating: ${angle}° — Click to confirm. ESC to cancel`);
  }, []);

  // ============================================================================
  // Mode Entry — the reducer guarantees the previous mode is dropped
  // ============================================================================
  /**
   * Sidebar click on a missile unit. A deployed unit has nothing left to arm,
   * so the click toggles its card open — same split as `handleJammerSelect`.
   */
  const handleUnitSelect = useCallback(
    (unitKey: string, unitName: string, category: string) => {
      if (deployedSystems.has(unitKey)) {
        setExpandedUnitKey((current) => (current === unitKey ? null : unitKey));
        return;
      }

      const offsets: Record<number, PreviewOffsets> = {};
      const o90 = generateOffsetsForAngle(90, undefined, rng);
      const o270 = generateOffsetsForAngle(270, undefined, rng);
      if (o90) offsets[90] = o90;
      if (o270) offsets[270] = o270;

      dispatch({ type: 'selectUnit', unit: { key: unitKey, name: unitName, category }, offsets });
      setStatus(`${unitName} selected - Click map to deploy`);
    },
    [deployedSystems, rng]
  );

  const handleCancelSelect = useCallback(() => {
    dispatch({ type: 'reset' });
    setStatus(DEFAULT_STATUS);
  }, []);

  /** Drops a pending mode without overwriting a real result in the status line */
  const clearPlacement = useCallback(() => {
    if (modeRef.current.kind === 'idle') return;
    dispatch({ type: 'reset' });
    setStatus(DEFAULT_STATUS);
  }, []);

  // Cross-mode arbitration lives in these handlers, not in Leaflet hit-testing:
  // react-leaflet only reads `interactive` when it constructs a layer, so
  // toggling that prop on a mounted Polygon/Marker has no effect. A layer that
  // owns the click also suppresses the map click, so the guards below just
  // ignore the click rather than letting another mode hijack the session.
  const handleAreaClick = useCallback((area: RelocatingArea) => {
    const current = modeRef.current;
    if (current.kind === 'placeJammer') return;

    // Toggle off if clicking the same area
    if (current.kind === 'relocateArea' && isSameArea(current.area, area)) {
      dispatch({ type: 'reset' });
      setStatus('Relocation cancelled');
      return;
    }

    dispatch({ type: 'relocateArea', area });
    setStatus(
      `Click on the map to relocate ${formatAreaLabel(area)}, or click it again / press ESC to cancel`
    );
  }, []);

  const handleRotateClick = useCallback((unitKey: string) => {
    if (modeRef.current.kind === 'placeJammer') return;

    const deployment = deployedSystemsRef.current.get(unitKey);
    if (!deployment) return;

    dispatch({ type: 'rotate', unitKey, center: deployment.center });
    setStatus(
      `Rotating: ${deployment.openingAngle}° — Move mouse to set angle, click to confirm. ESC to cancel`
    );
  }, []);

  // ============================================================================
  // Jammer Handlers
  // ============================================================================
  const handleJammerSelect = useCallback(
    (index: number) => {
      if (deployedJammers.has(index)) {
        setExpandedJammerIndex((current) => (current === index ? null : index));
        return;
      }
      dispatch({ type: 'placeJammer', index, isRelocate: false });
      setStatus(`${jammers[index]?.name ?? 'EW unit'} selected - Click map to deploy`);
    },
    [deployedJammers, jammers]
  );

  const handleJammerRelocateClick = useCallback((index: number) => {
    const current = modeRef.current;
    if (isMissileMode(current)) return;

    // Toggle off if clicking the same jammer
    if (current.kind === 'placeJammer' && current.index === index && current.isRelocate) {
      dispatch({ type: 'reset' });
      setStatus('Relocation cancelled');
      return;
    }

    dispatch({ type: 'placeJammer', index, isRelocate: true });
    setStatus(
      `Click on the map to relocate ${jammersRef.current[index]?.name ?? 'EW unit'}, or click it again / press ESC to cancel`
    );
  }, []);

  const handleUndeployJammer = useCallback(
    (index: number) => {
      onUndeployJammer(index);
      setExpandedJammerIndex(null);
      // The jammer commit path calls onDeployJammer without checking that the
      // unit is still deployed, so leaving this jammer in placement mode would
      // resurrect it on the next map click.
      if (mode.kind === 'placeJammer' && mode.index === index) {
        dispatch({ type: 'reset' });
      }
      setStatus(`${jammers[index]?.name ?? 'EW unit'} deployment cancelled`);
    },
    [onUndeployJammer, jammers, mode]
  );

  const handleUndeploy = useCallback(
    (unitKey: string, unitName: string) => {
      onUndeploySystem(unitKey);
      setStatus(`${unitName} deployment cancelled`);
    },
    [onUndeploySystem]
  );

  const handleAircraftError = useCallback((message: string) => {
    setStatus(message);
  }, []);

  // ============================================================================
  // Sidebar Collapse
  // ============================================================================
  const toggleCategory = useCallback(
    (category: string) => {
      const willCollapse = !collapsedCategories.has(category);

      setCollapsedCategories((prev) => {
        const next = new Set(prev);
        if (willCollapse) next.add(category);
        else next.delete(category);
        return next;
      });

      if (!willCollapse) return;

      // Collapsing hides the per-unit controls, so drop any pending sidebar
      // state in this category that would otherwise become unreachable.
      if (expandedUnitKey && deployedSystems.get(expandedUnitKey)?.category === category) {
        setExpandedUnitKey(null);
      }
      if (mode.kind === 'deploy' && mode.unit.category === category) {
        dispatch({ type: 'reset' });
        setStatus(DEFAULT_STATUS);
      }
    },
    [collapsedCategories, expandedUnitKey, deployedSystems, mode]
  );

  const toggleJammers = useCallback(() => {
    const willCollapse = !jammersCollapsed;
    setJammersCollapsed(willCollapse);
    if (!willCollapse) return;

    setExpandedJammerIndex(null);
    // Same reasoning as toggleCategory: a pending selection would lose its
    // Cancel button. Relocation is driven from the map, so it survives.
    if (mode.kind === 'placeJammer' && !mode.isRelocate) {
      dispatch({ type: 'reset' });
      setStatus(DEFAULT_STATUS);
    }
  }, [jammersCollapsed, mode]);

  // ESC cancels whichever mode currently owns the map click. Keyed on whether a
  // mode is live rather than on `mode` itself, so sweeping a rotation angle does
  // not re-register the listener on every mouse move.
  useEffect(() => {
    if (!isPlacementActive) return;
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key !== 'Escape') return;
      dispatch({ type: 'reset' });
      setStatus(cancellationMessage(modeRef.current));
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [isPlacementActive]);

  // ============================================================================
  // Derived Data
  // ============================================================================
  const { previewData, relocatePreviewVertices, rotationPreviewData } = useDeploymentPreviews({
    mode,
    mousePosition,
    deployedSystems,
    shouldValidateTaiwanBoundary,
    rng,
  });

  const placingJammerUnit = mode.kind === 'placeJammer' ? (jammers[mode.index] ?? null) : null;

  return {
    // Mode machine
    mode,
    mousePosition,
    isPlacementActive,
    coordinates,
    status,

    // Sidebar
    expandedUnitKey,
    collapsedCategories,
    expandedJammerIndex,
    jammersCollapsed,

    // Derived
    placingJammerUnit,
    previewData,
    relocatePreviewVertices,
    rotationPreviewData,
    getUnitInfo,

    // Handlers
    handleMapClick,
    handleMouseMove,
    handleUnitSelect,
    handleCancelSelect,
    clearPlacement,
    handleUndeploy,
    toggleCategory,
    toggleJammers,
    handleAreaClick,
    handleRotateClick,
    handleJammerSelect,
    handleJammerRelocateClick,
    handleUndeployJammer,
    handleAircraftError,
  };
}
