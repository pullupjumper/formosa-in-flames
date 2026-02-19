import { useState, useCallback } from 'react';
import type { MissileSystems, Airbase, DeployedMissileSystemData } from '@/types/setupMenu';
import { BaseMap, AirbaseMarkers, DeployedMissileSystems } from '@/components/Map';
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
  thickness: 0.5,
  width: 2.5,
  height: 2.0,
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
};

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
    angle: number
  ): DeployedMissileSystemData | null => {
    try {
      const areaConfig = {
        centerLat: lat,
        centerLon: lng,
        openingAngle: angle,
        ...AREA_CONFIG,
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
        const pathConfig = {
          centerLat: lat,
          centerLon: lng,
          width: AREA_CONFIG.width,
          height: AREA_CONFIG.height,
          thickness: AREA_CONFIG.thickness,
          openingAngle: angle,
          ammoArea: result.ammoArea,
          hideArea: result.hideArea,
          reloadArea: result.reloadArea,
          firePoints: result.firePoints,
          avoidanceMargin: 0.05,
        };

        paths = calculateMovementPaths(pathConfig);
      }

      return {
        unitName,
        category,
        center: { lat, lng },
        openingAngle: angle,
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

  const handleMapClick = (lat: number, lng: number) => {
    setCoordinates({ lat, lng });
    setExpandedUnitKey(null); // Collapse expanded items when clicking map

    // If no unit selected, just clear selection state
    if (selectedUnit === null) {
      return;
    }

    if (!isPointInTaiwan(lat, lng)) {
      setStatus('⚠️ Missile systems can only be deployed on Taiwan mainland');
      return;
    }

    const autoAngle = determineOpeningAngle(lat, lng);
    const deploymentData = generateDeploymentData(
      selectedUnit.name,
      selectedUnit.category,
      lat,
      lng,
      autoAngle
    );

    if (!deploymentData) {
      setStatus('⚠️ Generated tactical area extends outside Taiwan boundary');
      return;
    }

    onDeploySystem(selectedUnit.key, deploymentData);
    setStatus(
      `✓ ${selectedUnit.name} deployed at ${lat.toFixed(4)}°, ${lng.toFixed(4)}°, Angle: ${autoAngle}°`
    );
    setSelectedUnit(null);
  };

  const handleUnitSelect = (unitKey: string, unitName: string, category: string) => {
    if (deployedSystems.has(unitKey)) {
      return;
    }
    setSelectedUnit({ key: unitKey, name: unitName, category });
    setStatus(`${unitName} selected - Click map to deploy`);
  };

  const handleCancelSelect = () => {
    setSelectedUnit(null);
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
        newAngle
      );

      if (newData) {
        onDeploySystem(unitKey, newData);
      }
    }
  };

  return (
    <div className="flex h-full">
      {/* Map Container */}
      <div className="flex-1">
        <BaseMap onMapClick={handleMapClick}>
          <AirbaseMarkers airbases={airbases} />
          <DeployedMissileSystems deployedSystems={deployedSystems} getUnitInfo={getUnitInfo} />
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
                                    className="mt-1 mb-2 w-full rounded border border-accent-blue bg-dark-bg px-2 py-1 text-xs"
                                    placeholder="Angle (0-359°)"
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
