import { useState, useCallback, useRef, useMemo, useEffect } from 'react';
import type { MissileSystems, Airbase, DeployedMissileSystemData } from '@/types/setupMenu';
import {
  BaseMap,
  AirbaseMarkers,
  DeployedMissileSystems,
  MissileSystemPreview,
  AreaRelocatePreview,
} from '@/components/Map';
import type { RelocatingArea, AreaType } from '@/components/Map';
import {
  getWeaponSystemName,
  isPointInTaiwan,
  determineOpeningAngle,
  checkPolygonInTaiwan,
} from '@/utils/map';
import {
  generateUShapeVertices,
  calculateMovementPaths,
  calculateBearing,
  generateSquareVerticesPublic,
  checkSquaresOverlap,
} from '@/utils/tacticalAreaGenerator';

// ============================================================================
// AREA CONFIG
// ============================================================================
const AREA_CONFIG = {
  width: 1.5,
  height: 1.5,
  internalSquares: {
    size: 0.2,
    marginToWall: 0.1,
    marginBetweenSquares: 0.5,
  },
  firePoints: {
    radius: 3,
    squareSize: 0.3,
    count: 2,
    angleRange: 90,
    margin: 0.2,
  },
  ahaPoint: {
    radius: 7,
    squareSize: 0.3,
  },
};

const MOVEMENT_PATH_AVOIDANCE_MARGIN = 0.05;
const DEFAULT_STATUS = 'Select a missile system unit then click on the map to deploy';

type RelocatableSquareType = Exclude<AreaType, 'ushape'>;

const AREA_SQUARE_SIZE: Record<RelocatableSquareType, number> = {
  aha: AREA_CONFIG.ahaPoint.squareSize,
  hide: AREA_CONFIG.internalSquares.size,
  reload: AREA_CONFIG.internalSquares.size,
  fp: AREA_CONFIG.firePoints.squareSize,
};

const AREA_LABEL: Record<AreaType, string> = {
  ushape: 'U-Shape',
  aha: 'AHA',
  hide: 'Hide Area',
  reload: 'Reload Area',
  fp: 'Fire Point',
};

function createEmptyMovementPaths(): DeployedMissileSystemData['paths'] {
  return {
    FP: [],
    HA: { waypoints: [] },
    RL: [],
    AHA: { waypoints: [] },
  };
}

function buildMovementPaths(
  tacticalAreas: DeployedMissileSystemData['tacticalAreas']
): DeployedMissileSystemData['paths'] {
  if (!tacticalAreas.ammoArea || !tacticalAreas.hideArea || !tacticalAreas.reloadArea) {
    return createEmptyMovementPaths();
  }

  return calculateMovementPaths({
    ammoArea: tacticalAreas.ammoArea,
    hideArea: tacticalAreas.hideArea,
    reloadArea: tacticalAreas.reloadArea,
    firePoints: tacticalAreas.firePoints,
    avoidanceMargin: MOVEMENT_PATH_AVOIDANCE_MARGIN,
  });
}

function isValidAngle(angle: number): boolean {
  return Number.isFinite(angle) && angle >= 0 && angle <= 359;
}

function isPointInPolygon(
  point: { latitude: number; longitude: number },
  polygon: { latitude: number; longitude: number }[]
): boolean {
  let inside = false;
  for (let i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
    const yi = polygon[i].latitude;
    const xi = polygon[i].longitude;
    const yj = polygon[j].latitude;
    const xj = polygon[j].longitude;
    if (
      yi > point.latitude !== yj > point.latitude &&
      point.longitude < ((xj - xi) * (point.latitude - yi)) / (yj - yi) + xi
    ) {
      inside = !inside;
    }
  }
  return inside;
}

function areAllPointsInPolygon(
  points: { latitude: number; longitude: number }[],
  polygon: { latitude: number; longitude: number }[]
): boolean {
  return points.every((point) => isPointInPolygon(point, polygon));
}

function formatAreaLabel(area: RelocatingArea): string {
  if (area.type !== 'fp') return AREA_LABEL[area.type];
  return `${AREA_LABEL.fp} ${(area.fpIndex ?? 0) + 1}`;
}

// ============================================================================
// PREVIEW TYPES & CONSTANTS
// ============================================================================
interface OffsetVertex {
  dLat: number;
  dLng: number;
}

interface PreviewOffsets {
  uShapeVertices: OffsetVertex[];
  ammoArea: OffsetVertex[];
  hideArea: OffsetVertex[];
  reloadArea: OffsetVertex[];
  firePoints: OffsetVertex[][];
}

const REF_CENTER = { lat: 23.8, lng: 121.0 };

function resultToOffsets(
  result: ReturnType<typeof generateUShapeVertices>,
  refLat: number,
  refLng: number
): PreviewOffsets {
  const toOffset = (c: { latitude: number; longitude: number }): OffsetVertex => ({
    dLat: c.latitude - refLat,
    dLng: c.longitude - refLng,
  });
  return {
    uShapeVertices: result.uShapeVertices.map(toOffset),
    ammoArea: (result.ammoArea ?? []).map(toOffset),
    hideArea: (result.hideArea ?? []).map(toOffset),
    reloadArea: (result.reloadArea ?? []).map(toOffset),
    firePoints: (result.firePoints ?? []).map((fp) => fp.map(toOffset)),
  };
}

interface MissileSystemsTabProps {
  missileSystems: MissileSystems;
  airbases: Airbase[];
  deployedSystems: Map<string, DeployedMissileSystemData>;
  shouldValidateTaiwanBoundary: boolean;
  onDeploySystem: (key: string, data: DeployedMissileSystemData) => void;
  onUndeploySystem: (key: string) => void;
}

export function MissileSystemsTab({
  missileSystems,
  airbases,
  deployedSystems,
  shouldValidateTaiwanBoundary,
  onDeploySystem,
  onUndeploySystem,
}: MissileSystemsTabProps) {
  const [selectedUnit, setSelectedUnit] = useState<{
    key: string;
    name: string;
    category: string;
  } | null>(null);
  const [expandedUnitKey, setExpandedUnitKey] = useState<string | null>(null);
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
  const lastMouseMoveRef = useRef(0);

  const categories = Object.keys(missileSystems);

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

  const generateDeploymentData = useCallback(
    (
      unitName: string,
      category: string,
      lat: number,
      lng: number,
      angle: number,
      ahaRadiusOverride?: number,
      ahaCenterOverride?: { lat: number; lng: number }
    ): DeployedMissileSystemData | null => {
      try {
        const areaConfig = {
          centerLat: lat,
          centerLon: lng,
          openingAngle: angle,
          ...AREA_CONFIG,
          ahaPoint: {
            ...AREA_CONFIG.ahaPoint,
            radius: ahaRadiusOverride ?? AREA_CONFIG.ahaPoint.radius,
            ...(ahaCenterOverride
              ? { center: { latitude: ahaCenterOverride.lat, longitude: ahaCenterOverride.lng } }
              : {}),
          },
        };

        const result = generateUShapeVertices(areaConfig);

        // Check if U-shape is within Taiwan
        if (shouldValidateTaiwanBoundary && !checkPolygonInTaiwan(result.uShapeVertices)) {
          return null;
        }

        const tacticalAreas = {
          uShapeVertices: result.uShapeVertices,
          ammoArea: result.ammoArea,
          hideArea: result.hideArea,
          reloadArea: result.reloadArea,
          firePoints: result.firePoints,
        };

        return {
          unitName,
          category,
          center: { lat, lng },
          openingAngle: angle,
          ahaRadius: ahaRadiusOverride ?? AREA_CONFIG.ahaPoint.radius,
          ...(ahaCenterOverride ? { ahaCenter: ahaCenterOverride } : {}),
          tacticalAreas,
          paths: buildMovementPaths(tacticalAreas),
        };
      } catch (error) {
        console.error('Error generating tactical areas:', error);
        return null;
      }
    },
    [shouldValidateTaiwanBoundary]
  );

  const generateOffsetsForAngle = useCallback(
    (angle: number, ahaRadiusOverride?: number): PreviewOffsets | null => {
      try {
        const result = generateUShapeVertices({
          centerLat: REF_CENTER.lat,
          centerLon: REF_CENTER.lng,
          ...AREA_CONFIG,
          ahaPoint: {
            ...AREA_CONFIG.ahaPoint,
            radius: ahaRadiusOverride ?? AREA_CONFIG.ahaPoint.radius,
          },
          openingAngle: angle,
        });
        return resultToOffsets(result, REF_CENTER.lat, REF_CENTER.lng);
      } catch (error) {
        console.error('Failed to generate offsets for angle:', angle, error);
        return null;
      }
    },
    []
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
        const regenerated = generateDeploymentData(
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
      }

      // Recalculate paths with updated areas
      const paths = buildMovementPaths(newTacticalAreas);
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
    [relocatingArea, deployedSystems, generateDeploymentData, onDeploySystem]
  );

  const handleAngleChange = useCallback(
    (unitKey: string, newAngle: number) => {
      const deployment = deployedSystems.get(unitKey);
      if (!deployment) return;

      if (isValidAngle(newAngle)) {
        const newData = generateDeploymentData(
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
          newData.paths = buildMovementPaths(newData.tacticalAreas);
          onDeploySystem(unitKey, newData);
        }
      }
    },
    [deployedSystems, generateDeploymentData, onDeploySystem]
  );

  const handleMapClick = useCallback(
    (lat: number, lng: number) => {
      setCoordinates({ lat, lng });
      setExpandedUnitKey(null);

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
        setStatus('Warning: Missile systems can only be deployed on Taiwan mainland');
        return;
      }

      const autoAngle = previewAngle ?? determineOpeningAngle(lat, lng);

      let offsets: PreviewOffsets | null = previewOffsets[autoAngle] ?? null;
      if (!offsets) {
        offsets = generateOffsetsForAngle(autoAngle);
      }
      if (!offsets) {
        setStatus('Warning: Failed to generate tactical area for this angle');
        return;
      }

      const translate = (o: OffsetVertex) => ({
        latitude: lat + o.dLat,
        longitude: lng + o.dLng,
      });

      const uShapeVertices = offsets.uShapeVertices.map(translate);
      const ammoArea = offsets.ammoArea.map(translate);
      const hideArea = offsets.hideArea.map(translate);
      const reloadArea = offsets.reloadArea.map(translate);
      const firePoints = offsets.firePoints.map((fp) => fp.map(translate));

      if (shouldValidateTaiwanBoundary && !checkPolygonInTaiwan(uShapeVertices)) {
        setStatus('Warning: Generated tactical area extends outside Taiwan boundary');
        return;
      }

      const tacticalAreas: DeployedMissileSystemData['tacticalAreas'] = {
        uShapeVertices,
        ammoArea,
        hideArea,
        reloadArea,
        firePoints,
      };

      onDeploySystem(selectedUnit.key, {
        unitName: selectedUnit.name,
        category: selectedUnit.category,
        center: { lat, lng },
        openingAngle: autoAngle,
        ahaRadius: AREA_CONFIG.ahaPoint.radius,
        tacticalAreas,
        paths: buildMovementPaths(tacticalAreas),
      });

      setStatus(
        `Done: ${selectedUnit.name} deployed at ${lat.toFixed(4)}, ${lng.toFixed(4)}, Angle: ${autoAngle}`
      );
      setSelectedUnit(null);
      setPreviewOffsets(null);
      setPreviewAngle(null);
      setMousePosition(null);
    },
    [
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
      generateOffsetsForAngle,
      onDeploySystem,
    ]
  );

  const handleUnitSelect = useCallback(
    (unitKey: string, unitName: string, category: string) => {
      if (deployedSystems.has(unitKey)) {
        return;
      }
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
    [deployedSystems, generateOffsetsForAngle]
  );

  const handleCancelSelect = () => {
    setSelectedUnit(null);
    setPreviewOffsets(null);
    setPreviewAngle(null);
    setMousePosition(null);
    setRelocatingArea(null);
    setRotatingUnit(null);
    setRotationPreviewAngle(null);
    setStatus(DEFAULT_STATUS);
  };

  const handleAreaClick = useCallback(
    (area: RelocatingArea) => {
      // Toggle off if clicking the same area
      if (
        relocatingArea &&
        relocatingArea.unitKey === area.unitKey &&
        relocatingArea.type === area.type &&
        relocatingArea.fpIndex === area.fpIndex
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
    },
    [relocatingArea]
  );

  const handleRotateClick = useCallback(
    (unitKey: string) => {
      const deployment = deployedSystems.get(unitKey);
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
    },
    [deployedSystems]
  );

  useEffect(() => {
    if (!relocatingArea && !rotatingUnit) return;
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        setRelocatingArea(null);
        setRotatingUnit(null);
        setRotationPreviewAngle(null);
        setMousePosition(null);
        setStatus(rotatingUnit ? 'Rotation cancelled' : 'Relocation cancelled');
      }
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [relocatingArea, rotatingUnit]);

  const handleUndeploy = (unitKey: string, unitName: string) => {
    onUndeploySystem(unitKey);
    setStatus(`${unitName} deployment cancelled`);
  };

  const handleMouseMove = useCallback(
    (lat: number, lng: number) => {
      if (!selectedUnit && !relocatingArea && !rotatingUnit) return;
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
    [selectedUnit, relocatingArea, rotatingUnit]
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

    try {
      const result = generateUShapeVertices({
        centerLat: rotatingUnit.center.lat,
        centerLon: rotatingUnit.center.lng,
        ...AREA_CONFIG,
        ahaPoint: {
          ...AREA_CONFIG.ahaPoint,
          radius: deployment.ahaRadius ?? AREA_CONFIG.ahaPoint.radius,
          ...(deployment.ahaCenter
            ? {
                center: {
                  latitude: deployment.ahaCenter.lat,
                  longitude: deployment.ahaCenter.lng,
                },
              }
            : {}),
        },
        openingAngle: rotationPreviewAngle,
      });

      return {
        uShapeVertices: result.uShapeVertices,
        ammoArea: result.ammoArea ?? [],
        hideArea: result.hideArea ?? [],
        reloadArea: result.reloadArea ?? [],
        firePoints: deployment.tacticalAreas.firePoints ?? [],
      };
    } catch {
      return null;
    }
  }, [rotatingUnit, rotationPreviewAngle, deployedSystems]);

  const isInteractive = selectedUnit || relocatingArea || rotatingUnit;

  return (
    <div className="flex h-full">
      {/* Map Container */}
      <div className="flex-1">
        <BaseMap
          onMapClick={handleMapClick}
          onMouseMove={isInteractive ? handleMouseMove : undefined}
          cursorStyle={isInteractive ? 'crosshair' : undefined}
        >
          <AirbaseMarkers airbases={airbases} />
          <DeployedMissileSystems
            deployedSystems={deployedSystems}
            getUnitInfo={getUnitInfo}
            onAreaClick={handleAreaClick}
            onRotateClick={handleRotateClick}
            relocatingArea={relocatingArea}
            rotatingUnitKey={rotatingUnit?.unitKey ?? null}
          />
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
      <div className="w-80 overflow-y-auto border-l border-dark-border bg-dark-panel p-4">
        <div className="mb-4 text-xs font-bold uppercase tracking-wide text-text-secondary">
          Missile System Deployment
        </div>

        <div className="mb-4">
          <div className="mb-2 text-xs font-semibold">Available Units</div>
          {categories.length === 0 ? (
            <div className="text-xs italic text-text-secondary">
              No missile system units available
            </div>
          ) : (
            <div className="space-y-2">
              {categories.map((category) => {
                const categoryData = missileSystems[category];
                if (!categoryData?.firingUnits) return null;

                const weaponName = getWeaponSystemName(category);

                return (
                  <div key={category}>
                    {/* Category Header */}
                    <div className="mb-2 border-l-[3px] border-accent-blue bg-accent-blue/15 px-2 py-2 text-xs font-bold text-accent-blue">
                      {weaponName}
                    </div>

                    {/* Units */}
                    {Object.entries(categoryData.firingUnits).map(([unitName, unit]) => {
                      const unitKey = `${category}_${unitName}`;
                      const isDeployed = deployedSystems.has(unitKey);
                      const isSelected = selectedUnit?.key === unitKey;
                      const isExpanded = expandedUnitKey === unitKey;
                      const deployment = deployedSystems.get(unitKey);

                      return (
                        <div
                          key={unitKey}
                          className={`mb-2 cursor-pointer rounded-sm border p-2.5 text-xs transition-colors ${
                            isDeployed
                              ? 'border-status-success border-l-4 bg-status-success/10'
                              : isSelected
                                ? 'border-accent-blue bg-accent-blue/20'
                                : 'border-dark-border bg-dark-hover hover:bg-dark-border'
                          }`}
                          onClick={() => {
                            if (isDeployed) {
                              setExpandedUnitKey(isExpanded ? null : unitKey);
                            } else {
                              handleUnitSelect(unitKey, unit.name, category);
                            }
                          }}
                        >
                          <div className="mb-1 font-semibold">{unit.name}</div>
                          <div className="text-text-secondary">
                            <div>SYSTEM: {weaponName.split('(')[0].trim()}</div>
                          </div>

                          {isDeployed && deployment && (
                            <div className="mt-2 rounded bg-status-success/10 p-1.5">
                              <div className="text-[11px] text-status-success">
                                ✓ Deployed | Angle: {deployment.openingAngle}°
                              </div>
                              {isExpanded && (
                                <button
                                  className="w-full rounded bg-status-danger px-2 py-1 text-[11px] font-semibold text-white hover:bg-red-700"
                                  onClick={(e) => {
                                    e.stopPropagation();
                                    handleUndeploy(unitKey, unit.name);
                                  }}
                                >
                                  Cancel Deployment
                                </button>
                              )}
                            </div>
                          )}

                          {isSelected && !isDeployed && (
                            <div className="mt-2 rounded bg-accent-blue/10 p-1.5">
                              <div className="text-[11px] text-accent-blue">
                                Click map to deploy
                              </div>
                              <button
                                className="mt-2 w-full rounded bg-dark-border px-2 py-1 text-[11px] font-semibold text-text-secondary hover:bg-dark-hover"
                                onClick={(e) => {
                                  e.stopPropagation();
                                  handleCancelSelect();
                                }}
                              >
                                Cancel Selection
                              </button>
                            </div>
                          )}
                        </div>
                      );
                    })}
                  </div>
                );
              })}
            </div>
          )}
        </div>

        {/* Status */}
        <div className="rounded-sm border border-dark-border bg-black/30 p-2.5 text-xs">
          {status}
        </div>

        {/* Coordinates Display */}
        {coordinates && (
          <div className="mt-5 font-mono text-[11px] text-text-secondary">
            Latitude: {coordinates.lat.toFixed(6)}°, Longitude: {coordinates.lng.toFixed(6)}°
          </div>
        )}
      </div>
    </div>
  );
}
