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
import { getWeaponSystemName } from '@/utils/map';
import { CollapsibleGroup } from './CollapsibleGroup';
import { DeployableUnitCard } from './DeployableUnitCard';
import { AircraftPanel } from './AircraftPanel';
import { useDeploymentState } from '../hooks/useDeploymentState';
import type { SidebarPanel } from '../hooks/useDeploymentState';

// ============================================================================
// UI CONSTANTS
// ============================================================================
const SIDEBAR_PANELS: { id: SidebarPanel; label: string }[] = [
  { id: 'aircraft', label: 'Aircraft' },
  { id: 'ground', label: 'Ground & EW' },
];

interface DeploymentTabProps {
  missileSystems: MissileSystems;
  airbases: Airbase[];
  /** Untouched injected airbases, used as the budget floor. See AircraftPanel. */
  baselineAirbases: Airbase[];
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

export function DeploymentTab({
  missileSystems,
  airbases,
  baselineAirbases,
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
  const {
    selectedUnit,
    expandedUnitKey,
    setExpandedUnitKey,
    collapsedCategories,
    coordinates,
    mousePosition,
    relocatingArea,
    rotatingUnit,
    placingJammer,
    expandedJammerIndex,
    jammersCollapsed,
    sidebarPanel,
    selectedBaseIndex,
    displayStatus,
    isPlacementActive,
    placingJammerUnit,
    previewData,
    relocatePreviewVertices,
    rotationPreviewData,
    getUnitInfo,
    handleMapClick,
    handleMouseMove,
    handleUnitSelect,
    handleCancelSelect,
    handleUndeploy,
    toggleCategory,
    toggleJammers,
    handleAreaClick,
    handleRotateClick,
    handleJammerSelect,
    handleJammerRelocateClick,
    handleUndeployJammer,
    handleAirbaseClick,
    handleAircraftError,
    handleSidebarPanelChange,
  } = useDeploymentState({
    missileSystems,
    jammers,
    deployedSystems,
    deployedJammers,
    shouldValidateTaiwanBoundary,
    onDeploySystem,
    onUndeploySystem,
    onDeployJammer,
    onUndeployJammer,
  });

  const categories = Object.keys(missileSystems);
  const isInteractive = isPlacementActive;

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
              isValid={rotationPreviewData.isValid}
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
              baselineAirbases={baselineAirbases}
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
