import { useState } from 'react';
import { DeploymentMap } from '@pages/control-panel/components/map/DeploymentMap';
import { toControlPanelResult } from '@/pages/control-panel/logic/deploymentPayload';
import { submitDeployment, type ControlPanelPayload } from '../../logic/controlPanelPayload';
import type { DeploymentSession } from '@pages/control-panel/hooks/useDeploymentSession';
import { useBatteryGroups } from '@pages/control-panel/hooks/useBatteryGroups';
import { useC2Nodes } from '@pages/control-panel/hooks/useC2Nodes';
import { useDeploymentState } from '@pages/control-panel/hooks/useDeploymentState';
import { Panel } from '@pages/control-panel/components/shared/Panel';
import { JammerSection } from '@pages/control-panel/components/sections/JammerSection';
import { LandingUnitsSection } from '@pages/control-panel/components/sections/LandingUnitsSection';
import { MapStatusBar } from '@pages/control-panel/components/map/MapStatusBar';
import { SubmitBar } from '@pages/control-panel/components/shared/SubmitBar';
import { SignalSection } from '@pages/control-panel/components/sections/SignalSection';
import { C2NodesSection } from '@pages/control-panel/components/sections/C2NodesSection';
import { AircraftBasesSection } from '@pages/control-panel/components/sections/AircraftBasesSection';
import { BatterySection } from '@pages/control-panel/components/sections/BatterySection';
import { ResizeHandle } from '@pages/control-panel/components/shared/ResizeHandle';

const MIN_SIDEBAR_WIDTH = 300;
const MAX_SIDEBAR_WIDTH = 900;
const DEFAULT_SIDEBAR_WIDTH = 650;

interface ControlDeploymentTabProps {
  /** Injected payload; its airbases are the untouched budget floor. See BaseEditor. */
  payload: ControlPanelPayload;
  /** What the player has deployed and spent so far; lives above the tabs */
  session: DeploymentSession;
  showLandingUnits: boolean;
  /** Deployment was already submitted once: jammers, batteries and aircraft are read-only */
  isDeploymentLocked: boolean;
}

/**
 * Deployment tab, AIP-terminal style: stacked panels on the left (jammers,
 * batteries, aircraft), map on the right.
 */
export function ControlDeploymentTab({
  payload,
  session,
  showLandingUnits,
  isDeploymentLocked,
}: ControlDeploymentTabProps) {
  const { jammers, sideName, signals, landingUnits } = payload;
  const {
    airbases,
    budget,
    deployedMissileSystems,
    deployedJammers,
    setBudget: onBudgetChange,
    updateAirbase: onUpdateAirbase,
  } = session;
  const shouldValidateTaiwanBoundary = sideName === 'Taiwan';
  const batteries = useBatteryGroups(payload, deployedMissileSystems);
  const c2 = useC2Nodes(payload, batteries.samBatteries);
  const deployment = useDeploymentState({
    jammers,
    deployedMissileSystems,
    deployedJammers,
    shouldValidateTaiwanBoundary,
    isLocked: isDeploymentLocked,
    validateMissilePosition: c2.validateMissilePosition,
    onDeploySystem: session.deployMissileSystem,
    onUndeploySystem: session.undeployMissileSystem,
    onDeployJammer: session.deployJammer,
    onUndeployJammer: session.undeployJammer,
  });
  const { isPlacementActive, coordinates, status } = deployment;

  // The host input holds the last submitted result; it goes stale as soon as any
  // input of that result changes, so remember which inputs it was built from
  const resultInputs = [
    budget,
    airbases,
    deployedJammers,
    deployedMissileSystems,
    c2.samWeaponsFreeChoice,
  ];
  const [submittedInputs, setSubmittedInputs] = useState<unknown[] | null>(null);
  const isSubmitted =
    submittedInputs !== null && submittedInputs.every((input, i) => input === resultInputs[i]);

  const handleSubmit = () => {
    const result = toControlPanelResult({
      budget,
      airbases,
      jammers,
      deployedJammers,
      deployedMissileSystems,
    });
    const doctrine = c2.buildEmconResult();
    console.log('Export data:', result, doctrine);
    if (submitDeployment(result, doctrine)) setSubmittedInputs(resultInputs);
  };

  const [sidebarWidth, setSidebarWidth] = useState(DEFAULT_SIDEBAR_WIDTH);

  return (
    <div className="flex h-full">
      {/* Left column: stacked panels + submit */}
      <div
        className="flex shrink-0 flex-col gap-9 overflow-y-auto bg-aip-pane p-9"
        style={{ width: sidebarWidth }}
      >
        <Panel
          title="GPS Jammers"
          locked={isDeploymentLocked}
          badge={`${deployedJammers.size}/${jammers.length}`}
        >
          <JammerSection
            jammers={jammers}
            deployedJammers={deployedJammers}
            expandedJammerIndex={deployment.expandedJammerIndex}
            selectedJammerIndex={deployment.selectedJammerIndex}
            onJammerSelect={deployment.handleJammerSelect}
            onUndeployJammer={deployment.handleUndeployJammer}
            onCancelSelection={deployment.handleCancelSelect}
          />
        </Panel>

        <Panel title="C2 Nodes" badge={`${c2.nodes.length}`}>
          <C2NodesSection
            nodes={c2.nodes}
            samWeaponsFree={c2.isAllSamWeaponsFree}
            onSamWeaponsFreeChange={c2.setSamWeaponsFreeChoice}
            expandedUnitKey={deployment.expandedUnitKey}
            selectedUnitKey={deployment.selectedUnitKey}
            onUnitSelect={deployment.handleUnitSelect}
            onUndeploy={deployment.handleUndeploy}
            onCancelSelection={deployment.handleCancelSelect}
          />
        </Panel>

        <Panel title="Signals" badge={`${signals.length}`}>
          <SignalSection signals={signals} />
        </Panel>

        {showLandingUnits && (
          <Panel title="Landing Units" badge={`${Object.keys(landingUnits).length}`}>
            <LandingUnitsSection landingUnits={landingUnits} />
          </Panel>
        )}

        <Panel
          title="Missile Batteries"
          locked={isDeploymentLocked}
          badge={`${batteries.deployedCount}/${batteries.totalCount}`}
        >
          <BatterySection
            batteryGroups={batteries.batteryGroups}
            expandedUnitKey={deployment.expandedUnitKey}
            selectedUnitKey={deployment.selectedUnitKey}
            onUnitSelect={deployment.handleUnitSelect}
            onUndeploy={deployment.handleUndeploy}
            onCancelSelection={deployment.handleCancelSelect}
          />
        </Panel>

        <Panel
          title="Aircraft Deployment"
          locked={isDeploymentLocked}
          badge={`Budget ${budget.current}`}
        >
          <AircraftBasesSection
            airbases={airbases}
            baselineAirbases={payload.airbases}
            budget={budget}
            onBudgetChange={onBudgetChange}
            onUpdateAirbase={onUpdateAirbase}
            onError={deployment.handleAircraftError}
          />
        </Panel>

        <SubmitBar onSubmit={handleSubmit} isSubmitted={isSubmitted} />
      </div>

      <ResizeHandle
        width={sidebarWidth}
        minWidth={MIN_SIDEBAR_WIDTH}
        maxWidth={MAX_SIDEBAR_WIDTH}
        onWidthChange={setSidebarWidth}
      />

      {/* Map */}
      <div className="relative min-w-0 flex-1">
        <MapStatusBar status={status} coordinates={coordinates} />
        <DeploymentMap
          sideName={sideName}
          airbases={airbases}
          jammers={jammers}
          deployedMissileSystems={deployedMissileSystems}
          weaponRanges={batteries.weaponRanges}
          deployedJammers={deployedJammers}
          signals={signals}
          c2Layers={c2.layers}
          isPlacementActive={isPlacementActive}
          mousePosition={deployment.mousePosition}
          relocatingArea={deployment.relocatingArea}
          rotatingUnitKey={deployment.rotatingUnitKey}
          relocatingJammerIndex={deployment.relocatingJammerIndex}
          placingJammerUnit={deployment.placingJammerUnit}
          deployPreview={deployment.previewData}
          rotationPreview={deployment.rotationPreviewData}
          relocatePreviewVertices={deployment.relocatePreviewVertices}
          onMapClick={deployment.handleMapClick}
          onMouseMove={deployment.handleMouseMove}
          onAreaClick={deployment.handleAreaClick}
          onRotateClick={deployment.handleRotateClick}
          onJammerRelocateClick={deployment.handleJammerRelocateClick}
        />
      </div>
    </div>
  );
}
