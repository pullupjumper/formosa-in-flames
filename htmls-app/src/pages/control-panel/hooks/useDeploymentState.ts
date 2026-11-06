import type { GNSSJammerDescriptor } from '@/types/generated';
import { useState, useCallback, useRef, useReducer, useEffect } from 'react';
import type { Coordinate } from '@/types/geo';
import type { DeployedBattery } from '@/types/deployment';
import type { RelocatingArea, SelectedUnit } from '@/types/deployment';
import { calculateBearing, calculateCentroid } from '@/utils/geo';
import {
  generateBattery,
  generateOffsetsForAngle,
  isPointInTaiwan,
  relocateArea,
  resolveOpeningAngle,
  rotateBattery,
} from '@/utils/deploymentGeometry';
import type { PreviewOffsets } from '@/utils/deploymentGeometry';
import type { Battery } from '../logic/batteryGroups';
import type { RandomSource } from '@/utils/random';
import {
  DEFAULT_STATUS,
  IDLE_STATE,
  OUT_OF_BOUNDS_JAMMER,
  OUT_OF_BOUNDS_MISSILE,
  formatCancellationMessage,
  deploymentModeReducer,
  formatRelocateFailure,
  formatAreaLabel,
  isMissileMode,
  isPlacementMode,
  isSameArea,
  selectRelocatingArea,
  selectRotatingBatteryName,
  selectSelectedBatteryName,
  selectSelectedJammerIndex,
  selectRelocatingJammerIndex,
} from '../logic/deploymentMode';
import type { DeploymentMode } from '../logic/deploymentMode';
import { useDeploymentPreviews } from './useDeploymentPreviews';

/**
 * Interaction state for the Deployment tab: which mode owns the next map click,
 * what the hover preview shows, and the status line. Kept apart from
 * ControlDeploymentTab's markup so the mode arbitration can be exercised without
 * mounting Leaflet.
 */

// ============================================================================
// UI CONSTANTS
// ============================================================================
/** Hover previews regenerate geometry, so cap them well below frame rate */
const MOUSE_MOVE_THROTTLE_MS = 50;

/** Status-line rendering of a map position */
function formatPosition(position: Coordinate): string {
  return `${position.latitude.toFixed(4)}°, ${position.longitude.toFixed(4)}°`;
}

/** Stands in for every handler that would change a deployment while locked */
const noop = () => {};

// ============================================================================
// TYPES
// ============================================================================
export interface UseDeploymentStateParams {
  jammers: GNSSJammerDescriptor[];
  deployedBatteries: Map<string, DeployedBattery>;
  deployedJammers: Map<number, Coordinate>;
  shouldValidateTaiwanBoundary: boolean;
  /**
   * Deployment was already submitted: every handler that selects, places,
   * moves or removes a unit is inert. Cancel and the status line still work.
   */
  isLocked?: boolean;
  /**
   * Extra check on where a missile unit ends up (deploy click, or the centre of
   * its hide area after a relocation or rotation), run after the boundary check.
   * Returns a warning to show instead of applying the change, or null to allow it.
   */
  validateMissilePosition?: (batteryName: string, position: Coordinate) => string | null;
  onDeployBattery: (key: string, data: DeployedBattery) => void;
  onUndeploySystem: (key: string) => void;
  onDeployJammer: (index: number, position: Coordinate) => void;
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
  jammers,
  deployedBatteries,
  deployedJammers,
  shouldValidateTaiwanBoundary,
  isLocked = false,
  validateMissilePosition,
  onDeployBattery,
  onUndeploySystem,
  onDeployJammer,
  onUndeployJammer,
  rng = Math.random,
}: UseDeploymentStateParams) {
  const [{ mode, mousePosition }, dispatch] = useReducer(deploymentModeReducer, IDLE_STATE);
  const [status, setStatus] = useState(DEFAULT_STATUS);
  const [coordinates, setCoordinates] = useState<Coordinate | null>(null);

  // Sidebar presentation state, independent of the mode machine
  const [expandedBatteryName, setExpandedBatteryName] = useState<string | null>(null);
  const [expandedJammerIndex, setExpandedJammerIndex] = useState<number | null>(null);

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
  const deployedBatteriesRef = useRef(deployedBatteries);
  useEffect(() => {
    deployedBatteriesRef.current = deployedBatteries;
  }, [deployedBatteries]);
  const jammersRef = useRef(jammers);
  useEffect(() => {
    jammersRef.current = jammers;
  }, [jammers]);

  /** Injects the side's boundary rule into the pure generator */
  const createDeployment = useCallback(
    (name: string, missileSystemType: string, center: Coordinate, angle: number) =>
      generateBattery({
        name,
        missileSystemType,
        center,
        angle,
        validateTaiwanBoundary: shouldValidateTaiwanBoundary,
        rng,
      }),
    [shouldValidateTaiwanBoundary, rng]
  );

  /** Warning when the hide area of `deployment` sits where `batteryName` may not go */
  const rejectHideAreaPosition = useCallback(
    (batteryName: string, deployment: DeployedBattery): string | null => {
      const hideArea = deployment.tacticalAreas.HA[0];
      if (!validateMissilePosition || !hideArea?.length) return null;
      return validateMissilePosition(batteryName, calculateCentroid(hideArea));
    },
    [validateMissilePosition]
  );

  /**
   * Re-generate the deployment at a new opening angle. Returns false when the
   * angle is unusable — the rotated U-shape left the boundary, or no valid
   * gateway was found — so the caller can keep the user in rotation mode. The
   * failure carries the warning to show.
   */
  const applyAngleChange = useCallback(
    (batteryName: string, newAngle: number): string | null => {
      const label = deployedBatteries.get(batteryName)?.name ?? batteryName;
      const deployment = deployedBatteries.get(batteryName);
      if (!deployment) return `Warning: ${label} is not deployed`;

      const rotated = rotateBattery({
        deployment,
        angle: newAngle,
        validateTaiwanBoundary: shouldValidateTaiwanBoundary,
        rng,
      });
      if (!rotated) return `Warning: ${newAngle}° leaves no valid layout for ${label}`;
      const rejection = rejectHideAreaPosition(batteryName, rotated);
      if (rejection) return rejection;

      onDeployBattery(batteryName, rotated);
      return null;
    },
    [deployedBatteries, shouldValidateTaiwanBoundary, rng, onDeployBattery, rejectHideAreaPosition]
  );

  // ============================================================================
  // Commit Paths — one per mode, all reached from handleMapClick
  // ============================================================================
  const commitJammerPlacement = useCallback(
    (index: number, isRelocate: boolean, position: Coordinate) => {
      const jammer = jammers[index];
      if (!jammer) {
        dispatch({ type: 'reset' });
        return;
      }
      if (shouldValidateTaiwanBoundary && !isPointInTaiwan(position)) {
        setStatus(OUT_OF_BOUNDS_JAMMER);
        return;
      }
      onDeployJammer(index, position);
      setStatus(
        isRelocate
          ? `${jammer.name} relocated to ${formatPosition(position)}`
          : `Done: ${jammer.name} deployed at ${formatPosition(position)}`
      );
      dispatch({ type: 'reset' });
    },
    [jammers, shouldValidateTaiwanBoundary, onDeployJammer]
  );

  const commitRotation = useCallback(
    (batteryName: string, angle: number) => {
      const label = deployedBatteries.get(batteryName)?.name ?? batteryName;
      const failure = applyAngleChange(batteryName, angle);
      if (failure) {
        // Stay in rotation mode: the unit keeps its old angle and the user can
        // sweep to another one without restarting.
        setStatus(failure);
        return;
      }
      setStatus(`Angle set to ${angle}° for ${label}`);
      dispatch({ type: 'reset' });
    },
    [deployedBatteries, applyAngleChange]
  );

  const commitAreaRelocation = useCallback(
    (area: RelocatingArea, position: Coordinate) => {
      const deployment = deployedBatteries.get(area.batteryName);
      if (!deployment) {
        dispatch({ type: 'reset' });
        return;
      }

      const result = relocateArea({
        deployment,
        target: area,
        position,
        validateTaiwanBoundary: shouldValidateTaiwanBoundary,
        rng,
      });
      if (!result.ok) {
        setStatus(formatRelocateFailure(result.failure));
        return;
      }

      const rejection = rejectHideAreaPosition(area.batteryName, result.data);
      if (rejection) {
        setStatus(rejection);
        return;
      }

      onDeployBattery(area.batteryName, result.data);
      setStatus(`${formatAreaLabel(area)} relocated for ${deployment.name}`);
      dispatch({ type: 'reset' });
    },
    [deployedBatteries, shouldValidateTaiwanBoundary, rng, onDeployBattery, rejectHideAreaPosition]
  );

  const commitDeployment = useCallback(
    (unit: SelectedUnit, position: Coordinate) => {
      if (shouldValidateTaiwanBoundary && !isPointInTaiwan(position)) {
        setStatus(OUT_OF_BOUNDS_MISSILE);
        return;
      }
      const rejection = validateMissilePosition?.(unit.name, position);
      if (rejection) {
        setStatus(rejection);
        return;
      }

      const autoAngle = resolveOpeningAngle(position);

      // Preview offsets pre-compute a specific HA/RL layout, but we need both
      // FP and SHRL gateways to exist. Delegate to createDeployment which has
      // the outer retry loop that regenerates HA/RL when gateways fail.
      const deployment = createDeployment(unit.name, unit.missileSystemType, position, autoAngle);
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

      onDeployBattery(unit.name, deployment);
      setStatus(`Done: ${unit.name} deployed at ${formatPosition(position)}, Angle: ${autoAngle}`);
      dispatch({ type: 'reset' });
    },
    [shouldValidateTaiwanBoundary, validateMissilePosition, createDeployment, onDeployBattery]
  );

  const handleMapClick = useCallback(
    (position: Coordinate) => {
      setCoordinates(position);
      setExpandedBatteryName(null);
      setExpandedJammerIndex(null);

      switch (mode.kind) {
        case 'idle':
          return;
        case 'placeJammer':
          return commitJammerPlacement(mode.index, mode.isRelocate, position);
        case 'rotate':
          // No angle swept yet, so there is nothing to commit
          if (mode.previewAngle === null) return;
          return commitRotation(mode.batteryName, mode.previewAngle);
        case 'relocateArea':
          return commitAreaRelocation(mode.area, position);
        case 'deploy':
          return commitDeployment(mode.unit, position);
      }
    },
    [mode, commitJammerPlacement, commitRotation, commitAreaRelocation, commitDeployment]
  );

  const handleMouseMove = useCallback((position: Coordinate) => {
    const current = modeRef.current;
    if (current.kind === 'idle') return;

    const now = Date.now();
    if (now - lastMouseMoveRef.current < MOUSE_MOVE_THROTTLE_MS) return;
    lastMouseMoveRef.current = now;

    if (current.kind !== 'rotate') {
      dispatch({ type: 'hover', position });
      return;
    }

    const angle = Math.round(calculateBearing(current.center, position));
    dispatch({ type: 'hover', position, rotationAngle: angle });
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
    (battery: Battery) => {
      const { name } = battery;
      if (deployedBatteries.has(name)) {
        setExpandedBatteryName((current) => (current === name ? null : name));
        return;
      }

      const offsets: Record<number, PreviewOffsets> = {};
      const offsetsAt90 = generateOffsetsForAngle(90, undefined, rng);
      const offsetsAt270 = generateOffsetsForAngle(270, undefined, rng);
      if (offsetsAt90) offsets[90] = offsetsAt90;
      if (offsetsAt270) offsets[270] = offsetsAt270;

      const unit: SelectedUnit = {
        name,
        missileSystemType: battery.missileSystemType,
      };
      dispatch({ type: 'selectUnit', unit, offsets });
      setStatus(`${battery.name} selected - Click map to deploy`);
    },
    [deployedBatteries, rng]
  );

  const handleCancelSelect = useCallback(() => {
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

  const handleRotateClick = useCallback((batteryName: string) => {
    if (modeRef.current.kind === 'placeJammer') return;

    const deployment = deployedBatteriesRef.current.get(batteryName);
    if (!deployment) return;

    dispatch({ type: 'rotate', batteryName, center: deployment.center });
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
    (battery: Battery) => {
      onUndeploySystem(battery.name);
      setStatus(`${battery.name} deployment cancelled`);
    },
    [onUndeploySystem]
  );

  const handleAircraftError = useCallback((message: string) => {
    setStatus(message);
  }, []);

  // ESC cancels whichever mode currently owns the map click. Keyed on whether a
  // mode is live rather than on `mode` itself, so sweeping a rotation angle does
  // not re-register the listener on every mouse move.
  useEffect(() => {
    if (!isPlacementActive) return;
    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key !== 'Escape') return;
      dispatch({ type: 'reset' });
      setStatus(formatCancellationMessage(modeRef.current));
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
    deployedBatteries,
    shouldValidateTaiwanBoundary,
    rng,
  });

  const placingJammerUnit = mode.kind === 'placeJammer' ? (jammers[mode.index] ?? null) : null;

  // View model: components read these instead of pattern-matching `mode`
  const relocatingArea = selectRelocatingArea(mode);
  const rotatingBatteryName = selectRotatingBatteryName(mode);
  const selectedBatteryName = selectSelectedBatteryName(mode);
  const selectedJammerIndex = selectSelectedJammerIndex(mode);
  const relocatingJammerIndex = selectRelocatingJammerIndex(mode);

  return {
    // Mode machine
    mode,
    mousePosition,
    isPlacementActive,
    coordinates,
    status,

    // Sidebar
    expandedBatteryName,
    expandedJammerIndex,

    // Derived
    relocatingArea,
    rotatingBatteryName,
    selectedBatteryName,
    selectedJammerIndex,
    relocatingJammerIndex,
    placingJammerUnit,
    previewData,
    relocatePreviewVertices,
    rotationPreviewData,

    // Handlers that edit a deployment: inert while locked
    handleMapClick: isLocked ? noop : handleMapClick,
    handleUnitSelect: isLocked ? noop : handleUnitSelect,
    handleUndeploy: isLocked ? noop : handleUndeploy,
    handleAreaClick: isLocked ? noop : handleAreaClick,
    handleRotateClick: isLocked ? noop : handleRotateClick,
    handleJammerSelect: isLocked ? noop : handleJammerSelect,
    handleJammerRelocateClick: isLocked ? noop : handleJammerRelocateClick,
    handleUndeployJammer: isLocked ? noop : handleUndeployJammer,

    // Always live
    handleMouseMove,
    handleCancelSelect,
    handleAircraftError,
  };
}
