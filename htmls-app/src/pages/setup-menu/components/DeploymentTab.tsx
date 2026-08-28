import { useState, useCallback, useRef, useMemo, useEffect } from 'react';
import type {
  MissileSystems,
  Airbase,
  DeployedMissileSystemData,
  Jammer,
  BudgetState,
} from '@/types/setupMenu';
import {
  BaseMap,
  AirbaseMarkers,
  DeployedMissileSystems,
  MissileSystemPreview,
  AreaRelocatePreview,
  DeployedJammers,
  JammerRelocatePreview,
} from '@/components/Map';
import type { RelocatingArea, AreaType } from '@/components/Map';
import { getWeaponSystemName, isPointInTaiwan, determineOpeningAngle } from '@/utils/map';
import {
  calculateBearing,
  generateSquareVerticesPublic,
  checkSquaresOverlap,
} from '@/utils/tacticalAreaGenerator';
import {
  AREA_CONFIG,
  AREA_SQUARE_SIZE,
  areAllPointsInPolygon,
  buildMovementPaths,
  buildShelterPlan,
  generateDeploymentData,
  generateOffsetsForAngle,
  generateRotationPreview,
  isValidAngle,
} from '@/utils/missileDeployment';
import type { DeploymentContext, OffsetVertex, PreviewOffsets } from '@/utils/missileDeployment';
import { CollapsibleGroup } from './CollapsibleGroup';
import { DeployableUnitCard } from './DeployableUnitCard';
import { AircraftPanel } from './AircraftPanel';

// ============================================================================
// UI CONSTANTS
// ============================================================================
const DEFAULT_STATUS = 'Select a unit from the sidebar, then click on the map to deploy';
const OUT_OF_BOUNDS_JAMMER = 'Warning: EW units can only be deployed on Taiwan mainland';
const OUT_OF_BOUNDS_MISSILE = 'Warning: Missile systems can only be deployed on Taiwan mainland';

const AREA_LABEL: Record<AreaType, string> = {
  ushape: 'U-Shape',
  aha: 'AHA',
  hide: 'Hide Area',
  reload: 'Reload Area',
  fp: 'Fire Point',
};

function formatAreaLabel(area: RelocatingArea): string {
  if (area.type !== 'fp') return AREA_LABEL[area.type];
  return `${AREA_LABEL.fp} ${(area.fpIndex ?? 0) + 1}`;
}

interface DeploymentTabProps {
  missileSystems: MissileSystems;
  airbases: Airbase[];
  jammers: Jammer[];
  budget: BudgetState;
  deployedSystems: Map<string, DeployedMissileSystemData>;
  deployedJammers: Map<number, { lat: number; lng: number }>;
  shouldValidateTaiwanBoundary: boolean;
  sideName: string;
  onDeploySystem: (key: string, data: DeployedMissileSystemData) => void;
  onUndeploySystem: (key: string) => void;
  onDeployJammer: (index: number, lat: number, lng: number) => void;
  onUndeployJammer: (index: number) => void;
  onSpendBudget: (amount?: number) => boolean;
  onRefundBudget: (amount?: number) => void;
  onUpdateAirbase: (index: number, updater: (base: Airbase) => Airbase) => void;
}

/**
 * Jammer placement. Deploy and relocate share the same commit path
 * (validate boundary, then onDeployJammer), so they are one mode.
 */
interface PlacingJammer {
  index: number;
  isRelocate: boolean;
}

type SidebarPanel = 'aircraft' | 'ground';

const SIDEBAR_PANELS: { id: SidebarPanel; label: string }[] = [
  { id: 'aircraft', label: 'Aircraft' },
  { id: 'ground', label: 'Ground & EW' },
];

export function DeploymentTab({
  missileSystems,
  airbases,
  jammers,
  budget,
  deployedSystems,
  deployedJammers,
  shouldValidateTaiwanBoundary,
  sideName,
  onDeploySystem,
  onUndeploySystem,
  onDeployJammer,
  onUndeployJammer,
  onSpendBudget,
  onRefundBudget,
  onUpdateAirbase,
}: DeploymentTabProps) {
  const [selectedUnit, setSelectedUnit] = useState<{
    key: string;
    name: string;
    category: string;
  } | null>(null);
  const [expandedUnitKey, setExpandedUnitKey] = useState<string | null>(null);
  const [collapsedCategories, setCollapsedCategories] = useState<Set<string>>(new Set());
  const [status, setStatus] = useState(DEFAULT_STATUS);
  const [coordinates, setCoordinates] = useState<{ lat: number; lng: number } | null>(null);
  const [previewOffsets, setPreviewOffsets] = useState<Record<number, PreviewOffsets> | null>(null);
  const [previewAngle, setPreviewAngle] = useState<number | null>(null);
  const [mousePosition, setMousePosition] = useState<{ lat: number; lng: number } | null>(null);
  const [relocatingArea, setRelocatingArea] = useState<RelocatingArea | null>(null);
  const [rotatingUnit, setRotatingUnit] = useState<{
    unitKey: string;
    center: { lat: number; lng: number };
  } | null>(null);
  const [rotationPreviewAngle, setRotationPreviewAngle] = useState<number | null>(null);
  const [placingJammer, setPlacingJammer] = useState<PlacingJammer | null>(null);
  const [expandedJammerIndex, setExpandedJammerIndex] = useState<number | null>(null);
  const [jammersCollapsed, setJammersCollapsed] = useState(false);
  const [sidebarPanel, setSidebarPanel] = useState<SidebarPanel>('aircraft');
  const [selectedBaseIndex, setSelectedBaseIndex] = useState<number | null>(null);
  const lastMouseMoveRef = useRef(0);

  const categories = Object.keys(missileSystems);
  const isMissileModeActive = Boolean(selectedUnit || relocatingArea || rotatingUnit);
  const isPlacementActive = isMissileModeActive || placingJammer !== null;

  const getUnitInfo = useCallback(
    (unitKey: string) => {
      const [category, ...nameParts] = unitKey.split('_');
      const unitName = nameParts.join('_');
      const categoryData = missileSystems[category];
      if (!categoryData?.firingUnits?.[unitName]) return null;
      return {
        name: categoryData.firingUnits[unitName].name,
        category,
      };
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
      }),
    [shouldValidateTaiwanBoundary]
  );

  // ============================================================================
  // Area Relocation Logic
  // ============================================================================
  const applyAreaRelocation = useCallback(
    (lat: number, lng: number) => {
      if (!relocatingArea) return false;

      const deployment = deployedSystems.get(relocatingArea.unitKey);
      if (!deployment) {
        setRelocatingArea(null);
        return true;
      }

      const { tacticalAreas } = deployment;
      const newTacticalAreas = { ...tacticalAreas };
      const extraFields: Partial<DeployedMissileSystemData> = {};

      if (relocatingArea.type === 'ushape') {
        const regenerated = createDeployment(
          deployment.unitName,
          deployment.category,
          lat,
          lng,
          deployment.openingAngle,
          deployment.ahaRadius,
          deployment.ahaCenter
        );

        if (!regenerated) {
          setStatus('Warning: Failed to relocate U-Shape');
          return true;
        }

        newTacticalAreas.uShapeVertices = regenerated.tacticalAreas.uShapeVertices;
        newTacticalAreas.hideArea = regenerated.tacticalAreas.hideArea;
        newTacticalAreas.reloadArea = regenerated.tacticalAreas.reloadArea;
        newTacticalAreas.shelterPoints = regenerated.tacticalAreas.shelterPoints;
        extraFields.center = { lat, lng };
      } else {
        const bearingToCenter = calculateBearing(
          lat,
          lng,
          deployment.center.lat,
          deployment.center.lng
        );
        const squareSize = AREA_SQUARE_SIZE[relocatingArea.type];
        const newVertices = generateSquareVerticesPublic(lat, lng, squareSize, bearingToCenter);

        // Validate hide/reload must be inside U-Shape boundary
        if (relocatingArea.type === 'hide' || relocatingArea.type === 'reload') {
          const boundary = tacticalAreas.uShapeVertices;
          if (boundary && boundary.length >= 3) {
            const allInside = areAllPointsInPolygon(newVertices, boundary);
            if (!allInside) {
              setStatus('Warning: Must be within the boundary area');
              return true;
            }
          }
        }

        // Validate hide/reload don't overlap with each other
        if (relocatingArea.type === 'hide' || relocatingArea.type === 'reload') {
          const otherArea =
            relocatingArea.type === 'hide' ? tacticalAreas.reloadArea : tacticalAreas.hideArea;
          if (otherArea && otherArea.length === 4) {
            const otherCenterLat = otherArea.reduce((sum, vertex) => sum + vertex.latitude, 0) / 4;
            const otherCenterLon = otherArea.reduce((sum, vertex) => sum + vertex.longitude, 0) / 4;
            if (
              checkSquaresOverlap(
                lat,
                lng,
                otherCenterLat,
                otherCenterLon,
                squareSize,
                AREA_CONFIG.internalSquares.marginBetweenSquares
              )
            ) {
              const otherLabel =
                relocatingArea.type === 'hide' ? AREA_LABEL.reload : AREA_LABEL.hide;
              setStatus(`Warning: Overlaps with ${otherLabel}, choose another location`);
              return true;
            }
          }
        }

        // Build updated tactical areas — only replace the target area
        switch (relocatingArea.type) {
          case 'aha':
            newTacticalAreas.ammoArea = newVertices;
            extraFields.ahaCenter = { lat, lng };
            break;
          case 'hide':
            newTacticalAreas.hideArea = newVertices;
            break;
          case 'reload':
            newTacticalAreas.reloadArea = newVertices;
            break;
          case 'fp':
            if (tacticalAreas.firePoints) {
              const newFirePoints = [...tacticalAreas.firePoints];
              newFirePoints[relocatingArea.fpIndex!] = newVertices;
              newTacticalAreas.firePoints = newFirePoints;
            }
            break;
        }

        // Regenerate shelter points (with gateway validation) when HA/RL positions change
        if (relocatingArea.type === 'hide' || relocatingArea.type === 'reload') {
          const plan = buildShelterPlan(
            deployment.center.lat,
            deployment.center.lng,
            deployment.openingAngle,
            newTacticalAreas.hideArea,
            newTacticalAreas.reloadArea
          );
          newTacticalAreas.shelterPoints = plan.shelterPoints;
        }
      }

      // Recalculate paths with updated areas
      const pathContext: DeploymentContext = {
        centerLat: extraFields.center?.lat ?? deployment.center.lat,
        centerLng: extraFields.center?.lng ?? deployment.center.lng,
        openingAngle: deployment.openingAngle,
      };
      const paths = buildMovementPaths(newTacticalAreas, pathContext);
      const label = formatAreaLabel(relocatingArea);

      onDeploySystem(relocatingArea.unitKey, {
        ...deployment,
        ...extraFields,
        tacticalAreas: newTacticalAreas,
        paths,
      });
      setStatus(`${label} relocated for ${deployment.unitName}`);
      setRelocatingArea(null);
      setMousePosition(null);
      return true;
    },
    [relocatingArea, deployedSystems, createDeployment, onDeploySystem]
  );

  const handleAngleChange = useCallback(
    (unitKey: string, newAngle: number) => {
      const deployment = deployedSystems.get(unitKey);
      if (!deployment) return;

      if (isValidAngle(newAngle)) {
        const newData = createDeployment(
          deployment.unitName,
          deployment.category,
          deployment.center.lat,
          deployment.center.lng,
          newAngle,
          deployment.ahaRadius,
          deployment.ahaCenter
        );

        if (newData) {
          // Preserve existing fire points (like AHA)
          newData.tacticalAreas.firePoints = deployment.tacticalAreas.firePoints;
          newData.paths = buildMovementPaths(newData.tacticalAreas, {
            centerLat: deployment.center.lat,
            centerLng: deployment.center.lng,
            openingAngle: newAngle,
          });
          onDeploySystem(unitKey, newData);
        }
      }
    },
    [deployedSystems, createDeployment, onDeploySystem]
  );

  const handleMapClick = useCallback(
    (lat: number, lng: number) => {
      setCoordinates({ lat, lng });
      setExpandedUnitKey(null);
      setExpandedJammerIndex(null);

      // Jammer placement mode (deploy and relocate commit the same way)
      if (placingJammer) {
        const jammer = jammers[placingJammer.index];
        if (!jammer) {
          setPlacingJammer(null);
          return;
        }
        if (shouldValidateTaiwanBoundary && !isPointInTaiwan(lat, lng)) {
          setStatus(OUT_OF_BOUNDS_JAMMER);
          return;
        }
        onDeployJammer(placingJammer.index, lat, lng);
        setStatus(
          placingJammer.isRelocate
            ? `${jammer.name} relocated to ${lat.toFixed(4)}°, ${lng.toFixed(4)}°`
            : `Done: ${jammer.name} deployed at ${lat.toFixed(4)}°, ${lng.toFixed(4)}°`
        );
        setPlacingJammer(null);
        setMousePosition(null);
        return;
      }

      // Rotation mode
      if (rotatingUnit && rotationPreviewAngle !== null) {
        handleAngleChange(rotatingUnit.unitKey, rotationPreviewAngle);
        const deployment = deployedSystems.get(rotatingUnit.unitKey);
        setStatus(
          `Angle set to ${rotationPreviewAngle}° for ${deployment?.unitName ?? rotatingUnit.unitKey}`
        );
        setRotatingUnit(null);
        setRotationPreviewAngle(null);
        setMousePosition(null);
        return;
      }

      // Area relocation mode
      if (relocatingArea) {
        applyAreaRelocation(lat, lng);
        return;
      }

      if (selectedUnit === null || !previewOffsets) {
        return;
      }

      if (shouldValidateTaiwanBoundary && !isPointInTaiwan(lat, lng)) {
        setStatus(OUT_OF_BOUNDS_MISSILE);
        return;
      }

      const autoAngle = previewAngle ?? determineOpeningAngle(lat, lng);

      // Preview offsets pre-compute a specific HA/RL layout, but we need both
      // FP and SHRL gateways to exist. Delegate to createDeployment which
      // has the outer retry loop that regenerates HA/RL when gateways fail.
      const deployment = createDeployment(
        selectedUnit.name,
        selectedUnit.category,
        lat,
        lng,
        autoAngle
      );
      if (!deployment) {
        setStatus(
          shouldValidateTaiwanBoundary && !isPointInTaiwan(lat, lng)
            ? OUT_OF_BOUNDS_MISSILE
            : 'Warning: Failed to place tactical areas at this location'
        );
        return;
      }

      onDeploySystem(selectedUnit.key, deployment);

      setStatus(
        `Done: ${selectedUnit.name} deployed at ${lat.toFixed(4)}, ${lng.toFixed(4)}, Angle: ${autoAngle}`
      );
      setSelectedUnit(null);
      setPreviewOffsets(null);
      setPreviewAngle(null);
      setMousePosition(null);
    },
    [
      placingJammer,
      jammers,
      onDeployJammer,
      rotatingUnit,
      rotationPreviewAngle,
      handleAngleChange,
      deployedSystems,
      relocatingArea,
      applyAreaRelocation,
      selectedUnit,
      previewOffsets,
      shouldValidateTaiwanBoundary,
      previewAngle,
      createDeployment,
      onDeploySystem,
    ]
  );

  const handleUnitSelect = useCallback(
    (unitKey: string, unitName: string, category: string) => {
      if (deployedSystems.has(unitKey)) {
        return;
      }
      setPlacingJammer(null);
      setSelectedUnit({ key: unitKey, name: unitName, category });
      setPreviewAngle(null);
      setStatus(`${unitName} selected - Click map to deploy`);

      const offsets: Record<number, PreviewOffsets> = {};
      const o90 = generateOffsetsForAngle(90);
      const o270 = generateOffsetsForAngle(270);
      if (o90) offsets[90] = o90;
      if (o270) offsets[270] = o270;

      setPreviewOffsets(offsets);
    },
    [deployedSystems]
  );

  const clearMissileModes = useCallback(() => {
    setSelectedUnit(null);
    setPreviewOffsets(null);
    setPreviewAngle(null);
    setRelocatingArea(null);
    setRotatingUnit(null);
    setRotationPreviewAngle(null);
  }, []);

  const handleCancelSelect = useCallback(() => {
    clearMissileModes();
    setPlacingJammer(null);
    setMousePosition(null);
    setStatus(DEFAULT_STATUS);
  }, [clearMissileModes]);

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
      if (selectedUnit?.category === category) {
        setSelectedUnit(null);
        setPreviewOffsets(null);
        setPreviewAngle(null);
        setMousePosition(null);
        setStatus(DEFAULT_STATUS);
      }
    },
    [collapsedCategories, expandedUnitKey, deployedSystems, selectedUnit]
  );

  const toggleJammers = useCallback(() => {
    const willCollapse = !jammersCollapsed;
    setJammersCollapsed(willCollapse);
    if (!willCollapse) return;

    // Same reasoning as toggleCategory: a pending selection would lose its
    // Cancel button. Relocation is driven from the map, so it survives.
    setExpandedJammerIndex(null);
    if (placingJammer && !placingJammer.isRelocate) {
      setPlacingJammer(null);
      setMousePosition(null);
      setStatus(DEFAULT_STATUS);
    }
  }, [jammersCollapsed, placingJammer]);

  // Refs for stable callbacks (avoid breaking MissileSystemMarker/JammerMarker memo)
  const relocatingAreaRef = useRef(relocatingArea);
  useEffect(() => {
    relocatingAreaRef.current = relocatingArea;
  }, [relocatingArea]);
  const deployedSystemsRef = useRef(deployedSystems);
  useEffect(() => {
    deployedSystemsRef.current = deployedSystems;
  }, [deployedSystems]);
  const placingJammerRef = useRef(placingJammer);
  useEffect(() => {
    placingJammerRef.current = placingJammer;
  }, [placingJammer]);
  const jammersRef = useRef(jammers);
  useEffect(() => {
    jammersRef.current = jammers;
  }, [jammers]);
  const isMissileModeActiveRef = useRef(isMissileModeActive);
  useEffect(() => {
    isMissileModeActiveRef.current = isMissileModeActive;
  }, [isMissileModeActive]);
  const isPlacementActiveRef = useRef(isPlacementActive);
  useEffect(() => {
    isPlacementActiveRef.current = isPlacementActive;
  }, [isPlacementActive]);

  // Cross-mode arbitration lives in these handlers, not in Leaflet hit-testing:
  // react-leaflet only reads `interactive` when it constructs a layer, so
  // toggling that prop on a mounted Polygon/Marker has no effect. A layer that
  // owns the click also suppresses the map click, so the guards below just
  // ignore the click rather than letting another mode hijack the session.
  const handleAreaClick = useCallback((area: RelocatingArea) => {
    if (placingJammerRef.current) return;

    const current = relocatingAreaRef.current;
    // Toggle off if clicking the same area
    if (
      current &&
      current.unitKey === area.unitKey &&
      current.type === area.type &&
      current.fpIndex === area.fpIndex
    ) {
      setRelocatingArea(null);
      setMousePosition(null);
      setStatus('Relocation cancelled');
      return;
    }
    setRelocatingArea(area);
    setSelectedUnit(null);
    setPreviewOffsets(null);
    setPreviewAngle(null);
    setRotatingUnit(null);
    setRotationPreviewAngle(null);

    const label = formatAreaLabel(area);
    setStatus(`Click on the map to relocate ${label}, or click it again / press ESC to cancel`);
  }, []);

  const handleRotateClick = useCallback((unitKey: string) => {
    if (placingJammerRef.current) return;

    const deployment = deployedSystemsRef.current.get(unitKey);
    if (!deployment) return;

    setRotatingUnit({ unitKey, center: deployment.center });
    setRotationPreviewAngle(null);
    setRelocatingArea(null);
    setSelectedUnit(null);
    setPreviewOffsets(null);
    setPreviewAngle(null);
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
        setExpandedJammerIndex(expandedJammerIndex === index ? null : index);
        return;
      }
      clearMissileModes();
      setMousePosition(null);
      setPlacingJammer({ index, isRelocate: false });
      setStatus(`${jammers[index]?.name ?? 'EW unit'} selected - Click map to deploy`);
    },
    [deployedJammers, expandedJammerIndex, clearMissileModes, jammers]
  );

  const handleJammerRelocateClick = useCallback((index: number) => {
    if (isMissileModeActiveRef.current) return;

    const current = placingJammerRef.current;
    // Toggle off if clicking the same jammer
    if (current?.index === index && current.isRelocate) {
      setPlacingJammer(null);
      setMousePosition(null);
      setStatus('Relocation cancelled');
      return;
    }
    setMousePosition(null);
    setPlacingJammer({ index, isRelocate: true });
    setStatus(
      `Click on the map to relocate ${jammersRef.current[index]?.name ?? 'EW unit'}, or click it again / press ESC to cancel`
    );
  }, []);

  const handleUndeployJammer = useCallback(
    (index: number) => {
      onUndeployJammer(index);
      setExpandedJammerIndex(null);
      setStatus(`${jammers[index]?.name ?? 'EW unit'} deployment cancelled`);
    },
    [onUndeployJammer, jammers]
  );

  // ============================================================================
  // Aircraft Handlers
  // ============================================================================
  /**
   * Selecting a base switches the sidebar to the aircraft panel. Guarded so a
   * stray airbase click cannot swallow a pending deployment.
   */
  const handleAirbaseClick = useCallback((index: number) => {
    if (isPlacementActiveRef.current) return;
    setSelectedBaseIndex(index);
    setSidebarPanel('aircraft');
  }, []);

  const handleAircraftError = useCallback((message: string) => {
    setStatus(message);
  }, []);

  const handleSidebarPanelChange = useCallback(
    (panel: SidebarPanel) => {
      setSidebarPanel(panel);
      // Leaving the ground panel would hide the Cancel controls of a pending
      // sidebar selection, so drop it. Map-driven modes are left alone.
      if (panel === 'aircraft') {
        if (selectedUnit || (placingJammer && !placingJammer.isRelocate)) {
          setSelectedUnit(null);
          setPreviewOffsets(null);
          setPreviewAngle(null);
          setPlacingJammer(null);
          setMousePosition(null);
          setStatus(DEFAULT_STATUS);
        }
      }
    },
    [selectedUnit, placingJammer]
  );

  // ESC cancels whichever mode currently owns the map click
  useEffect(() => {
    if (!relocatingArea && !rotatingUnit && !placingJammer && !selectedUnit) return;
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key !== 'Escape') return;
      clearMissileModes();
      setPlacingJammer(null);
      setMousePosition(null);
      if (rotatingUnit) setStatus('Rotation cancelled');
      else if (relocatingArea || placingJammer?.isRelocate) setStatus('Relocation cancelled');
      else setStatus('Selection cancelled');
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [relocatingArea, rotatingUnit, placingJammer, selectedUnit, clearMissileModes]);

  const handleUndeploy = (unitKey: string, unitName: string) => {
    onUndeploySystem(unitKey);
    setStatus(`${unitName} deployment cancelled`);
  };

  const handleMouseMove = useCallback(
    (lat: number, lng: number) => {
      if (!selectedUnit && !relocatingArea && !rotatingUnit && !placingJammer) return;
      const now = Date.now();
      if (now - lastMouseMoveRef.current < 50) return;
      lastMouseMoveRef.current = now;
      setMousePosition({ lat, lng });

      if (rotatingUnit) {
        const angle = Math.round(
          calculateBearing(rotatingUnit.center.lat, rotatingUnit.center.lng, lat, lng)
        );
        setRotationPreviewAngle(angle);
        setStatus(`Rotating: ${angle}° — Click to confirm. ESC to cancel`);
      }
    },
    [selectedUnit, relocatingArea, rotatingUnit, placingJammer]
  );

  const previewData = useMemo(() => {
    if (!previewOffsets || !mousePosition) return null;

    const angle = previewAngle ?? determineOpeningAngle(mousePosition.lat, mousePosition.lng);
    const offsets = previewOffsets[angle];
    if (!offsets) return null;

    const translate = (o: OffsetVertex) => ({
      latitude: mousePosition.lat + o.dLat,
      longitude: mousePosition.lng + o.dLng,
    });

    const uShapeVertices = offsets.uShapeVertices.map(translate);
    const ammoArea = offsets.ammoArea.map(translate);
    const firePoints = offsets.firePoints.map((fp) => fp.map(translate));

    const allVerticesInTaiwan =
      !shouldValidateTaiwanBoundary ||
      (uShapeVertices.every((v) => isPointInTaiwan(v.latitude, v.longitude)) &&
        firePoints.every((fp) => fp.every((v) => isPointInTaiwan(v.latitude, v.longitude))) &&
        ammoArea.every((v) => isPointInTaiwan(v.latitude, v.longitude)));

    return {
      uShapeVertices,
      ammoArea,
      hideArea: offsets.hideArea.map(translate),
      reloadArea: offsets.reloadArea.map(translate),
      firePoints,
      isValid: allVerticesInTaiwan,
    };
  }, [previewOffsets, previewAngle, mousePosition, shouldValidateTaiwanBoundary]);

  const relocatePreviewVertices = useMemo(() => {
    if (!relocatingArea || !mousePosition) return null;
    const deployment = deployedSystems.get(relocatingArea.unitKey);
    if (!deployment) return null;

    if (relocatingArea.type === 'ushape') {
      return deployment.tacticalAreas.uShapeVertices.map((v) => ({
        latitude: v.latitude + (mousePosition.lat - deployment.center.lat),
        longitude: v.longitude + (mousePosition.lng - deployment.center.lng),
      }));
    }

    const bearingToCenter = calculateBearing(
      mousePosition.lat,
      mousePosition.lng,
      deployment.center.lat,
      deployment.center.lng
    );
    const squareSize = AREA_SQUARE_SIZE[relocatingArea.type];
    return generateSquareVerticesPublic(
      mousePosition.lat,
      mousePosition.lng,
      squareSize,
      bearingToCenter
    );
  }, [relocatingArea, mousePosition, deployedSystems]);

  const rotationPreviewData = useMemo(() => {
    if (!rotatingUnit || rotationPreviewAngle === null) return null;
    const deployment = deployedSystems.get(rotatingUnit.unitKey);
    if (!deployment) return null;

    const preview = generateRotationPreview(
      rotatingUnit.center,
      rotationPreviewAngle,
      deployment.ahaRadius,
      deployment.ahaCenter
    );
    if (!preview) return null;

    // Fire points are user-placed, so rotation leaves them where they are
    return { ...preview, firePoints: deployment.tacticalAreas.firePoints ?? [] };
  }, [rotatingUnit, rotationPreviewAngle, deployedSystems]);

  const placingJammerUnit = placingJammer ? (jammers[placingJammer.index] ?? null) : null;
  const isInteractive = isPlacementActive;

  // The default hint is about placing units, which does not apply to the
  // aircraft panel. Any real deployment result still shows through.
  const displayStatus =
    sidebarPanel === 'aircraft' && status === DEFAULT_STATUS
      ? 'Select an airbase on the map to edit its loadouts'
      : status;

  return (
    <div className="flex h-full">
      {/* Map Container */}
      <div className="flex-1">
        <BaseMap
          onMapClick={handleMapClick}
          onMouseMove={isInteractive ? handleMouseMove : undefined}
          cursorStyle={isInteractive ? 'crosshair' : undefined}
          sideName={sideName}
        >
          <AirbaseMarkers airbases={airbases} onAirbaseClick={handleAirbaseClick} />
          <DeployedMissileSystems
            deployedSystems={deployedSystems}
            getUnitInfo={getUnitInfo}
            onAreaClick={handleAreaClick}
            onRotateClick={handleRotateClick}
            relocatingArea={relocatingArea}
            rotatingUnitKey={rotatingUnit?.unitKey ?? null}
          />
          <DeployedJammers
            jammers={jammers}
            deployedPositions={deployedJammers}
            relocatingIndex={placingJammer?.isRelocate ? placingJammer.index : null}
            onRelocateClick={handleJammerRelocateClick}
          />
          {placingJammerUnit && mousePosition && (
            <JammerRelocatePreview radius={placingJammerUnit.radius} position={mousePosition} />
          )}
          {relocatePreviewVertices && relocatingArea && (
            <AreaRelocatePreview
              vertices={relocatePreviewVertices}
              areaType={relocatingArea.type}
            />
          )}
          {rotationPreviewData && (
            <MissileSystemPreview
              uShapeVertices={rotationPreviewData.uShapeVertices}
              ammoArea={rotationPreviewData.ammoArea}
              hideArea={rotationPreviewData.hideArea}
              reloadArea={rotationPreviewData.reloadArea}
              firePoints={rotationPreviewData.firePoints}
              isValid={true}
            />
          )}
          {previewData && (
            <MissileSystemPreview
              uShapeVertices={previewData.uShapeVertices}
              ammoArea={previewData.ammoArea}
              hideArea={previewData.hideArea}
              reloadArea={previewData.reloadArea}
              firePoints={previewData.firePoints}
              isValid={previewData.isValid}
            />
          )}
        </BaseMap>
      </div>

      {/* Controls Panel */}
      <div className="flex w-80 flex-col border-l border-dark-border bg-dark-panel">
        {/* Sidebar Sub-tabs */}
        <div className="flex shrink-0 border-b border-dark-border">
          {SIDEBAR_PANELS.map((panel) => (
            <button
              key={panel.id}
              type="button"
              aria-pressed={sidebarPanel === panel.id}
              className={`flex-1 border-b-2 px-3 py-2.5 text-[11px] font-bold uppercase tracking-wide transition-colors ${
                sidebarPanel === panel.id
                  ? 'border-accent-blue bg-accent-blue/10 text-accent-blue'
                  : 'border-transparent text-text-secondary hover:text-text-primary'
              }`}
              onClick={() => handleSidebarPanelChange(panel.id)}
            >
              {panel.label}
            </button>
          ))}
        </div>

        {/* Active Panel */}
        <div className="flex-1 overflow-y-auto p-4">
          {sidebarPanel === 'aircraft' ? (
            <AircraftPanel
              airbases={airbases}
              budget={budget}
              selectedBaseIndex={selectedBaseIndex}
              onSpendBudget={onSpendBudget}
              onRefundBudget={onRefundBudget}
              onUpdateAirbase={onUpdateAirbase}
              onError={handleAircraftError}
            />
          ) : (
            <div className="mb-4">
              <div className="mb-2 text-xs font-semibold">Available Units</div>
              <div className="space-y-2">
                {/* GPS Jammers */}
                <CollapsibleGroup
                  title="GPS Jammers"
                  deployedCount={deployedJammers.size}
                  totalCount={jammers.length}
                  collapsed={jammersCollapsed}
                  onToggle={toggleJammers}
                >
                  {jammers.length === 0 ? (
                    <div className="text-xs italic text-text-secondary">
                      No jammer units available
                    </div>
                  ) : (
                    jammers.map((jammer, index) => {
                      const deployment = deployedJammers.get(index);
                      return (
                        <DeployableUnitCard
                          key={index}
                          name={jammer.name}
                          details={
                            <>
                              <div>ZONE: {jammer.zoneName}</div>
                              <div>RANGE: {jammer.radius} NM</div>
                            </>
                          }
                          deployedSummary={
                            deployment
                              ? `✓ Deployed at ${deployment.lat.toFixed(4)}°, ${deployment.lng.toFixed(4)}°`
                              : null
                          }
                          isDeployed={deployment !== undefined}
                          isSelected={placingJammer?.index === index && !placingJammer.isRelocate}
                          isExpanded={expandedJammerIndex === index}
                          onSelect={() => handleJammerSelect(index)}
                          onCancelDeployment={() => handleUndeployJammer(index)}
                          onCancelSelection={handleCancelSelect}
                        />
                      );
                    })
                  )}
                </CollapsibleGroup>

                {/* Missile Systems */}
                {categories.length === 0 ? (
                  <div className="text-xs italic text-text-secondary">
                    No missile system units available
                  </div>
                ) : (
                  categories.map((category) => {
                    const categoryData = missileSystems[category];
                    if (!categoryData?.firingUnits) return null;

                    const weaponName = getWeaponSystemName(category);
                    const unitEntries = Object.entries(categoryData.firingUnits);
                    const deployedCount = unitEntries.filter(([unitName]) =>
                      deployedSystems.has(`${category}_${unitName}`)
                    ).length;

                    return (
                      <CollapsibleGroup
                        key={category}
                        title={weaponName}
                        deployedCount={deployedCount}
                        totalCount={unitEntries.length}
                        collapsed={collapsedCategories.has(category)}
                        onToggle={() => toggleCategory(category)}
                      >
                        {unitEntries.map(([unitName, unit]) => {
                          const unitKey = `${category}_${unitName}`;
                          const deployment = deployedSystems.get(unitKey);
                          const isExpanded = expandedUnitKey === unitKey;

                          return (
                            <DeployableUnitCard
                              key={unitKey}
                              name={unit.name}
                              details={<div>SYSTEM: {weaponName.split('(')[0].trim()}</div>}
                              deployedSummary={
                                deployment
                                  ? `✓ Deployed | Angle: ${deployment.openingAngle}°`
                                  : null
                              }
                              isDeployed={deployment !== undefined}
                              isSelected={selectedUnit?.key === unitKey}
                              isExpanded={isExpanded}
                              onSelect={() => {
                                if (deployment) {
                                  setExpandedUnitKey(isExpanded ? null : unitKey);
                                } else {
                                  handleUnitSelect(unitKey, unit.name, category);
                                }
                              }}
                              onCancelDeployment={() => handleUndeploy(unitKey, unit.name)}
                              onCancelSelection={handleCancelSelect}
                            />
                          );
                        })}
                      </CollapsibleGroup>
                    );
                  })
                )}
              </div>
            </div>
          )}
        </div>

        {/* Status + Coordinates (shared across panels) */}
        <div className="shrink-0 border-t border-dark-border p-4">
          <div className="rounded-sm border border-dark-border bg-black/30 p-2.5 text-xs">
            {displayStatus}
          </div>
          {coordinates && (
            <div className="mt-3 font-mono text-[11px] text-text-secondary">
              Latitude: {coordinates.lat.toFixed(6)}°, Longitude: {coordinates.lng.toFixed(6)}°
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
