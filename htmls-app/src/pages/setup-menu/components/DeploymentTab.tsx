import { useMemo } from 'react';
import type { Coordinate } from '@/types/geo';
import type {
  MissileSystems,
  Airbase,
  MissileDeployment,
  Jammer,
  BudgetState,
} from '@/types/setupMenu';
import { AircraftPanel } from './AircraftPanel';
import { DeploymentMap } from './DeploymentMap';
import { GroundUnitsPanel } from './GroundUnitsPanel';
import { buildMissileGroups } from '../missileGroups';
import { useDeploymentState } from '../hooks/useDeploymentState';
import { useAircraftPanel } from '../hooks/useAircraftPanel';
import type { SidebarPanel } from '../hooks/useAircraftPanel';

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
  deployedSystems: Map<string, MissileDeployment>;
  deployedJammers: Map<number, Coordinate>;
  shouldValidateTaiwanBoundary: boolean;
  sideName: string;
  onDeploySystem: (key: string, data: MissileDeployment) => void;
  onUndeploySystem: (key: string) => void;
  onDeployJammer: (index: number, position: Coordinate) => void;
  onUndeployJammer: (index: number) => void;
  onSpendBudget: (amount?: number) => boolean;
  onRefundBudget: (amount?: number) => void;
  onUpdateAirbase: (index: number, updater: (base: Airbase) => Airbase) => void;
}

/**
 * Layout shell for the Deployment tab: map on the left, sidebar on the right.
 * All interaction rules live in `useDeploymentState` / `useAircraftPanel`.
 */
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
  const deployment = useDeploymentState({
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
  const { mode, isPlacementActive, coordinates, status } = deployment;

  const {
    sidebarPanel,
    selectedBaseIndex,
    displayStatus,
    handleAirbaseClick,
    handleSidebarPanelChange,
  } = useAircraftPanel({
    status,
    isPlacementActive,
    onEnterPanel: deployment.clearPlacement,
  });

  // Narrow the active mode once, so the markup below stays declarative
  const placingJammer = mode.kind === 'placeJammer' ? mode : null;
  const missileGroups = useMemo(
    () => buildMissileGroups(missileSystems, deployedSystems),
    [missileSystems, deployedSystems]
  );

  return (
    <div className="flex h-full">
      {/* Map Container */}
      <div className="flex-1">
        <DeploymentMap
          sideName={sideName}
          airbases={airbases}
          jammers={jammers}
          deployedSystems={deployedSystems}
          deployedJammers={deployedJammers}
          isPlacementActive={isPlacementActive}
          mousePosition={deployment.mousePosition}
          relocatingArea={mode.kind === 'relocateArea' ? mode.area : null}
          rotatingUnitKey={mode.kind === 'rotate' ? mode.unitKey : null}
          relocatingJammerIndex={placingJammer?.isRelocate ? placingJammer.index : null}
          placingJammerUnit={deployment.placingJammerUnit}
          deployPreview={deployment.previewData}
          rotationPreview={deployment.rotationPreviewData}
          relocatePreviewVertices={deployment.relocatePreviewVertices}
          getUnitInfo={deployment.getUnitInfo}
          onMapClick={deployment.handleMapClick}
          onMouseMove={deployment.handleMouseMove}
          onAreaClick={deployment.handleAreaClick}
          onRotateClick={deployment.handleRotateClick}
          onAirbaseClick={handleAirbaseClick}
          onJammerRelocateClick={deployment.handleJammerRelocateClick}
        />
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
              onError={deployment.handleAircraftError}
            />
          ) : (
            <GroundUnitsPanel
              jammers={jammers}
              deployedJammers={deployedJammers}
              isJammersCollapsed={deployment.isJammersCollapsed}
              expandedJammerIndex={deployment.expandedJammerIndex}
              selectedJammerIndex={
                placingJammer && !placingJammer.isRelocate ? placingJammer.index : null
              }
              missileGroups={missileGroups}
              collapsedCategories={deployment.collapsedCategories}
              expandedUnitKey={deployment.expandedUnitKey}
              selectedUnitKey={mode.kind === 'deploy' ? mode.unit.key : null}
              onToggleJammers={deployment.toggleJammers}
              onJammerSelect={deployment.handleJammerSelect}
              onUndeployJammer={deployment.handleUndeployJammer}
              onToggleCategory={deployment.toggleCategory}
              onUnitSelect={deployment.handleUnitSelect}
              onUndeploy={deployment.handleUndeploy}
              onCancelSelection={deployment.handleCancelSelect}
            />
          )}
        </div>

        {/* Status + Coordinates (shared across panels) */}
        <div className="shrink-0 border-t border-dark-border p-4">
          <div className="rounded-sm border border-dark-border bg-black/30 p-2.5 text-xs">
            {displayStatus}
          </div>
          {coordinates && (
            <div className="mt-3 font-mono text-[11px] text-text-secondary">
              Latitude: {coordinates.latitude.toFixed(6)}°, Longitude:{' '}
              {coordinates.longitude.toFixed(6)}°
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
