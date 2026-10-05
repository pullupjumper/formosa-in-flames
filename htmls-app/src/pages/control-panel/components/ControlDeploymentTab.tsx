import { useMemo, useState } from 'react';
import { DeploymentMap } from '@pages/control-panel/components/DeploymentMap';
import { buildMissileGroups } from '@pages/control-panel/missileGroups';
import { toControlPanelResult } from '@/utils/deploymentPayload';
import { applySamWeaponsFree, buildC2NodeViews, collectSamUnits } from '../c2Nodes';
import { buildBatteryStatusMap } from '../batteryStatus';
import { submitDeployment, type ControlPanelPayload } from '../controlPanelPayload';
import type { DeploymentSession } from '@pages/control-panel/hooks/useDeploymentSession';
import { useDeploymentState } from '@pages/control-panel/hooks/useDeploymentState';
import { Panel } from './Panel';
import { JammerSection } from './JammerSection';
import { LandingUnitsSection } from './LandingUnitsSection';
import { MapStatusBar } from './MapStatusBar';
import { SubmitBar } from './SubmitBar';
import { SignalSection } from './SignalSection';
import { C2NodesSection } from './C2NodesSection';
import { AircraftBasesSection } from './AircraftBasesSection';
import { BatterySection } from './BatterySection';
import { ResizeHandle } from './ResizeHandle';

// SAM batteries are deployed from their C2 node card, not the battery list
const SAM_CATEGORY = 'sam';

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
  const { missileSystems, jammers, sideName, signals, landingUnits } = payload;
  const {
    airbases,
    budget,
    deployedMissileSystems,
    deployedJammers,
    setBudget: onBudgetChange,
    updateAirbase: onUpdateAirbase,
  } = session;
  const shouldValidateTaiwanBoundary = sideName === 'Taiwan';
  const deployment = useDeploymentState({
    jammers,
    deployedMissileSystems,
    deployedJammers,
    shouldValidateTaiwanBoundary,
    isLocked: isDeploymentLocked,
    onDeploySystem: session.deployMissileSystem,
    onUndeploySystem: session.undeployMissileSystem,
    onDeployJammer: session.deployJammer,
    onUndeployJammer: session.undeployJammer,
  });
  const { isPlacementActive, coordinates, status } = deployment;

  // null until the player touches the checkbox; until then the SAMs keep their own status
  const [samWeaponsFree, setSamWeaponsFree] = useState<boolean | null>(null);

  // The host input holds the last submitted result; it goes stale as soon as any
  // input of that result changes, so remember which inputs it was built from
  const resultInputs = [budget, airbases, deployedJammers, deployedMissileSystems, samWeaponsFree];
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
    const doctrine = { sams: samUnits };
    console.log('Export data:', result, doctrine);
    if (submitDeployment(result, doctrine)) setSubmittedInputs(resultInputs);
  };

  const [sidebarWidth, setSidebarWidth] = useState(DEFAULT_SIDEBAR_WIDTH);

  const missileGroups = useMemo(
    () => buildMissileGroups(missileSystems, deployedMissileSystems),
    [missileSystems, deployedMissileSystems]
  );
  const batteryGroups = useMemo(
    () => missileGroups.filter((group) => group.category !== SAM_CATEGORY),
    [missileGroups]
  );
  const deployedBatteries = batteryGroups.reduce((sum, group) => sum + group.deployedCount, 0);
  const totalBatteries = batteryGroups.reduce((sum, group) => sum + group.units.length, 0);

  const [batteryStatusMap] = useState(() => buildBatteryStatusMap(payload.batteryStatuses));
  const c2Nodes = useMemo(() => {
    const samBatteries = missileGroups.find((group) => group.category === SAM_CATEGORY)?.units;
    return buildC2NodeViews(payload.c2Data, samBatteries ?? []);
  }, [payload.c2Data, missileGroups]);
  // Cards, checkbox and submitted result all read the nodes with the choice applied
  const shownC2Nodes = applySamWeaponsFree(c2Nodes, samWeaponsFree);
  const samUnits = collectSamUnits(shownC2Nodes);

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

        <Panel title="C2 Nodes" badge={`${c2Nodes.length}`}>
          <C2NodesSection
            nodes={shownC2Nodes}
            samWeaponsFree={samUnits.length > 0 && samUnits.every((sam) => sam.weaponFree)}
            onSamWeaponsFreeChange={setSamWeaponsFree}
            batteryStatusMap={batteryStatusMap}
            samCategory={SAM_CATEGORY}
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
          badge={`${deployedBatteries}/${totalBatteries}`}
        >
          <BatterySection
            missileGroups={batteryGroups}
            batteryStatusMap={batteryStatusMap}
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
          deployedJammers={deployedJammers}
          signals={signals}
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
