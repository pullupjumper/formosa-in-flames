import { useState, useCallback, useRef, useMemo } from 'react';
import type { MissileSystems, Airbase, DeployedMissileSystemData } from '@/types/setupMenu';
import {
  BaseMap,
  AirbaseMarkers,
  DeployedMissileSystems,
  MissileSystemPreview,
} from '@/components/Map';
import {
  getWeaponSystemName,
  isPointInTaiwan,
  determineOpeningAngle,
  checkPolygonInTaiwan,
} from '@/utils/map';
import { generateUShapeVertices, calculateMovementPaths } from '@/utils/tacticalAreaGenerator';

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
    radius: 15,
    squareSize: 0.3,
  },
};

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
  onDeploySystem: (key: string, data: DeployedMissileSystemData) => void;
  onUndeploySystem: (key: string) => void;
}

export function MissileSystemsTab({
  missileSystems,
  airbases,
  deployedSystems,
  onDeploySystem,
  onUndeploySystem,
}: MissileSystemsTabProps) {
  const [selectedUnit, setSelectedUnit] = useState<{
    key: string;
    name: string;
    category: string;
  } | null>(null);
  const [expandedUnitKey, setExpandedUnitKey] = useState<string | null>(null);
  const [status, setStatus] = useState(
    'Select a missile system unit then click on the map to deploy'
  );
  const [coordinates, setCoordinates] = useState<{ lat: number; lng: number } | null>(null);
  const [previewOffsets, setPreviewOffsets] = useState<Record<number, PreviewOffsets> | null>(null);
  const [previewAngle, setPreviewAngle] = useState<number | null>(null);
  const [ahaRadius, setAhaRadius] = useState<number | null>(null);
  const [mousePosition, setMousePosition] = useState<{ lat: number; lng: number } | null>(null);
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

  const generateDeploymentData = (
    unitName: string,
    category: string,
    lat: number,
    lng: number,
    angle: number,
    ahaRadiusOverride?: number
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
        },
      };

      const result = generateUShapeVertices(areaConfig);

      // Check if U-shape is within Taiwan
      if (!checkPolygonInTaiwan(result.uShapeVertices)) {
        return null;
      }

      let paths = {
        FP: [] as { waypoints: { latitude: number; longitude: number }[] }[],
        HA: { waypoints: [] as { latitude: number; longitude: number }[] },
        RL: [] as { waypoints: { latitude: number; longitude: number }[] }[],
        AHA: { waypoints: [] as { latitude: number; longitude: number }[] },
      };

      if (result.ammoArea && result.hideArea && result.reloadArea) {
        paths = calculateMovementPaths({
          ammoArea: result.ammoArea,
          hideArea: result.hideArea,
          reloadArea: result.reloadArea,
          firePoints: result.firePoints,
          avoidanceMargin: 0.05,
        });
      }

      return {
        unitName,
        category,
        center: { lat, lng },
        openingAngle: angle,
        ahaRadius: ahaRadiusOverride ?? AREA_CONFIG.ahaPoint.radius,
        tacticalAreas: {
          uShapeVertices: result.uShapeVertices,
          ammoArea: result.ammoArea,
          hideArea: result.hideArea,
          reloadArea: result.reloadArea,
          firePoints: result.firePoints,
        },
        paths,
      };
    } catch (error) {
      console.error('Error generating tactical areas:', error);
      return null;
    }
  };

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

  const handleMapClick = (lat: number, lng: number) => {
    setCoordinates({ lat, lng });
    setExpandedUnitKey(null);

    if (selectedUnit === null || !previewOffsets) {
      return;
    }

    if (!isPointInTaiwan(lat, lng)) {
      setStatus('Warning: Missile systems can only be deployed on Taiwan mainland');
      return;
    }

    const autoAngle = previewAngle ?? determineOpeningAngle(lat, lng);

    let offsets: PreviewOffsets | null = previewOffsets[autoAngle] ?? null;
    if (!offsets) {
      offsets = generateOffsetsForAngle(autoAngle, ahaRadius ?? AREA_CONFIG.ahaPoint.radius);
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

    if (!checkPolygonInTaiwan(uShapeVertices)) {
      setStatus('Warning: Generated tactical area extends outside Taiwan boundary');
      return;
    }

    let paths: DeployedMissileSystemData['paths'] = {
      FP: [],
      HA: { waypoints: [] },
      RL: [],
      AHA: { waypoints: [] },
    };

    if (ammoArea.length > 0 && hideArea.length > 0 && reloadArea.length > 0) {
      paths = calculateMovementPaths({
        ammoArea,
        hideArea,
        reloadArea,
        firePoints,
        avoidanceMargin: 0.05,
      });
    }

    onDeploySystem(selectedUnit.key, {
      unitName: selectedUnit.name,
      category: selectedUnit.category,
      center: { lat, lng },
      openingAngle: autoAngle,
      ahaRadius: ahaRadius ?? AREA_CONFIG.ahaPoint.radius,
      tacticalAreas: { uShapeVertices, ammoArea, hideArea, reloadArea, firePoints },
      paths,
    });

    setStatus(
      `Done: ${selectedUnit.name} deployed at ${lat.toFixed(4)}, ${lng.toFixed(4)}, Angle: ${autoAngle}`
    );
    setSelectedUnit(null);
    setPreviewOffsets(null);
    setPreviewAngle(null);
    setMousePosition(null);
  };

  const handleUnitSelect = (unitKey: string, unitName: string, category: string) => {
    if (deployedSystems.has(unitKey)) {
      return;
    }
    setSelectedUnit({ key: unitKey, name: unitName, category });
    setPreviewAngle(null);
    setAhaRadius(null);
    setStatus(`${unitName} selected - Click map to deploy`);

    const offsets: Record<number, PreviewOffsets> = {};
    const o90 = generateOffsetsForAngle(90);
    const o270 = generateOffsetsForAngle(270);
    if (o90) offsets[90] = o90;
    if (o270) offsets[270] = o270;

    setPreviewOffsets(offsets);
  };

  const handleCancelSelect = () => {
    setSelectedUnit(null);
    setPreviewOffsets(null);
    setPreviewAngle(null);
    setMousePosition(null);
    setStatus('Select a missile system unit then click on the map to deploy');
  };

  const handleUndeploy = (unitKey: string, unitName: string) => {
    onUndeploySystem(unitKey);
    setStatus(`${unitName} deployment cancelled`);
  };

  const handleAngleChange = (unitKey: string, newAngle: number) => {
    const deployment = deployedSystems.get(unitKey);
    if (!deployment) return;

    if (!isNaN(newAngle) && newAngle >= 0 && newAngle <= 359) {
      const newData = generateDeploymentData(
        deployment.unitName,
        deployment.category,
        deployment.center.lat,
        deployment.center.lng,
        newAngle,
        deployment.ahaRadius
      );

      if (newData) {
        onDeploySystem(unitKey, newData);
      }
    }
  };

  const handleAhaRadiusChangeDeployed = (unitKey: string, newRadius: number) => {
    const deployment = deployedSystems.get(unitKey);
    if (!deployment) return;

    if (!isNaN(newRadius) && newRadius > 0) {
      const newData = generateDeploymentData(
        deployment.unitName,
        deployment.category,
        deployment.center.lat,
        deployment.center.lng,
        deployment.openingAngle,
        newRadius
      );

      if (newData) {
        onDeploySystem(unitKey, newData);
      }
    }
  };

  const handlePreviewAngleChange = useCallback(
    (newAngle: number) => {
      if (isNaN(newAngle) || newAngle < 0 || newAngle > 359) return;
      setPreviewAngle(newAngle);
      setPreviewOffsets((prev) => {
        if (!prev || prev[newAngle]) return prev;
        const effectiveRadius = ahaRadius ?? AREA_CONFIG.ahaPoint.radius;
        const offsets = generateOffsetsForAngle(newAngle, effectiveRadius);
        if (!offsets) return prev;
        return { ...prev, [newAngle]: offsets };
      });
    },
    [ahaRadius, generateOffsetsForAngle]
  );

  const handleAhaRadiusChange = useCallback(
    (newRadius: number | null) => {
      if (newRadius !== null && (isNaN(newRadius) || newRadius <= 0)) return;
      setAhaRadius(newRadius);
      const effectiveRadius = newRadius ?? AREA_CONFIG.ahaPoint.radius;
      // Regenerate all cached offsets with the new radius
      setPreviewOffsets((prev) => {
        if (!prev) return prev;
        const updated: Record<number, PreviewOffsets> = {};
        for (const angleKey of Object.keys(prev)) {
          const angle = Number(angleKey);
          const offsets = generateOffsetsForAngle(angle, effectiveRadius);
          if (offsets) updated[angle] = offsets;
        }
        return updated;
      });
    },
    [generateOffsetsForAngle]
  );

  const handleMouseMove = useCallback(
    (lat: number, lng: number) => {
      if (!selectedUnit) return;
      const now = Date.now();
      if (now - lastMouseMoveRef.current < 50) return;
      lastMouseMoveRef.current = now;
      setMousePosition({ lat, lng });
    },
    [selectedUnit]
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
      uShapeVertices.every((v) => isPointInTaiwan(v.latitude, v.longitude)) &&
      firePoints.every((fp) => fp.every((v) => isPointInTaiwan(v.latitude, v.longitude))) &&
      ammoArea.every((v) => isPointInTaiwan(v.latitude, v.longitude));

    return {
      uShapeVertices,
      ammoArea,
      hideArea: offsets.hideArea.map(translate),
      reloadArea: offsets.reloadArea.map(translate),
      firePoints,
      isValid: allVerticesInTaiwan,
    };
  }, [previewOffsets, previewAngle, mousePosition]);

  return (
    <div className="flex h-full">
      {/* Map Container */}
      <div className="flex-1">
        <BaseMap
          onMapClick={handleMapClick}
          onMouseMove={selectedUnit ? handleMouseMove : undefined}
          cursorStyle={selectedUnit ? 'crosshair' : undefined}
        >
          <AirbaseMarkers airbases={airbases} />
          <DeployedMissileSystems deployedSystems={deployedSystems} getUnitInfo={getUnitInfo} />
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
                                ✓ Deployed | Angle: {deployment.openingAngle}° | AHA:{' '}
                                {deployment.ahaRadius} NM
                              </div>
                              {isExpanded && (
                                <>
                                  <input
                                    type="number"
                                    min={0}
                                    max={359}
                                    value={deployment.openingAngle}
                                    onChange={(e) =>
                                      handleAngleChange(unitKey, parseInt(e.target.value))
                                    }
                                    onClick={(e) => e.stopPropagation()}
                                    className="mt-1 w-full rounded border border-accent-blue bg-dark-bg px-2 py-1 text-xs"
                                    placeholder="Angle (0-359°)"
                                  />
                                  <input
                                    type="number"
                                    min={1}
                                    max={50}
                                    step={0.5}
                                    value={deployment.ahaRadius}
                                    onChange={(e) =>
                                      handleAhaRadiusChangeDeployed(
                                        unitKey,
                                        parseFloat(e.target.value)
                                      )
                                    }
                                    onClick={(e) => e.stopPropagation()}
                                    className="mt-1 mb-2 w-full rounded border border-accent-blue bg-dark-bg px-2 py-1 text-xs"
                                    placeholder="AHA Distance (NM)"
                                  />
                                  <button
                                    className="w-full rounded bg-status-danger px-2 py-1 text-[11px] font-semibold text-white hover:bg-red-700"
                                    onClick={(e) => {
                                      e.stopPropagation();
                                      handleUndeploy(unitKey, unit.name);
                                    }}
                                  >
                                    Cancel Deployment
                                  </button>
                                </>
                              )}
                            </div>
                          )}

                          {isSelected && !isDeployed && (
                            <div className="mt-2 rounded bg-accent-blue/10 p-1.5">
                              <div className="text-[11px] text-accent-blue">
                                Click map to deploy
                              </div>
                              <div className="mt-1.5">
                                <label className="text-[11px] text-text-secondary">
                                  Opening Angle
                                </label>
                                <div className="mt-0.5 flex items-center gap-1.5">
                                  <input
                                    type="number"
                                    min={0}
                                    max={359}
                                    value={previewAngle ?? ''}
                                    onChange={(e) => {
                                      const val = e.target.value;
                                      if (val === '') {
                                        setPreviewAngle(null);
                                      } else {
                                        handlePreviewAngleChange(parseInt(val));
                                      }
                                    }}
                                    onClick={(e) => e.stopPropagation()}
                                    className="w-full rounded border border-accent-blue bg-dark-bg px-2 py-1 text-xs"
                                    placeholder="Auto (90/270)"
                                  />
                                  {previewAngle !== null && (
                                    <button
                                      className="shrink-0 rounded bg-dark-border px-1.5 py-1 text-[11px] text-text-secondary hover:bg-dark-hover"
                                      onClick={(e) => {
                                        e.stopPropagation();
                                        setPreviewAngle(null);
                                      }}
                                    >
                                      Auto
                                    </button>
                                  )}
                                </div>
                              </div>
                              <div className="mt-1.5">
                                <label className="text-[11px] text-text-secondary">
                                  AHA Distance (NM)
                                </label>
                                <div className="mt-0.5 flex items-center gap-1.5">
                                  <input
                                    type="number"
                                    min={1}
                                    max={50}
                                    step={0.5}
                                    value={ahaRadius ?? ''}
                                    onChange={(e) => {
                                      const val = e.target.value;
                                      if (val === '') {
                                        handleAhaRadiusChange(null);
                                      } else {
                                        handleAhaRadiusChange(parseFloat(val));
                                      }
                                    }}
                                    onClick={(e) => e.stopPropagation()}
                                    className="w-full rounded border border-accent-blue bg-dark-bg px-2 py-1 text-xs"
                                    placeholder={`Default (${AREA_CONFIG.ahaPoint.radius})`}
                                  />
                                </div>
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
