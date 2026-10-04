import { useMemo, useState } from 'react';
import { DeploymentMap } from '@pages/control-panel/components/DeploymentMap';
import { buildMissileGroups } from '@pages/control-panel/missileGroups';
import { flattenC2Nodes } from '@/utils/c2';
import { parseInjectedJSON } from '@/utils/inject';
import { UNIT_STATUS_DATA } from '@/data/unitStatusData';
import type { Coordinate } from '@/types/geo';
import type {
  Airbase,
  BudgetState,
  Jammer,
  MissileDeployment,
  MissileSystems,
} from '@/types/setupMenu';
import type { C2Data, LandingUnitsData, MissileSystemData, SignalData } from '@/types/unitStatus';
import { toSetupResult } from '@/utils/setupMenuPayload';
import { writeHostInput } from '@/utils/inject';
import { toEmconResult } from '@/utils/emcon';
import { applySamWeaponsFree, buildC2NodeViews, collectSamUnits } from '../c2Nodes';
import { buildLauncherStatusMap } from '../launcherStatus';
import { useDeploymentState } from '@pages/control-panel/hooks/useDeploymentState';
import { Panel } from './Panel';
import { JammerPanel } from './JammerPanel';
import { LandingUnitsPanel } from './LandingUnitsPanel';
import { MapStatusBar } from './MapStatusBar';
import { SubmitBar } from './SubmitBar';
import { SignalPanel } from './SignalPanel';
import { C2NodesPanel } from './C2NodesPanel';
import { AircraftBasesPanel } from './AircraftBasesPanel';
import { LauncherPanel } from './LauncherPanel';
import { ResizeHandle } from './ResizeHandle';

// SAM launchers are deployed from their C2 node card, not the launcher list
const SAM_CATEGORY = 'sam';

const noop = () => {};

const MIN_SIDEBAR_WIDTH = 300;
const MAX_SIDEBAR_WIDTH = 900;
const DEFAULT_SIDEBAR_WIDTH = 650;

interface ControlDeploymentTabProps {
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
  onBudgetChange: (next: BudgetState) => void;
  onUpdateAirbase: (index: number, updater: (base: Airbase) => Airbase) => void;
  showLandingUnits: boolean;
  /** Deployment was already submitted once: jammers, launchers and aircraft are read-only */
  isDeploymentLocked: boolean;
}

/**
 * Deployment tab, AIP-terminal style: stacked panels on the left (jammers,
 * launchers, aircraft), map on the right. Same hooks as the setup menu's tab.
 */
export function ControlDeploymentTab({
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
  onBudgetChange,
  onUpdateAirbase,
  showLandingUnits,
  isDeploymentLocked,
}: ControlDeploymentTabProps) {
  const deployment = useDeploymentState({
    jammers,
    deployedSystems,
    deployedJammers,
    shouldValidateTaiwanBoundary,
    onDeploySystem,
    onUndeploySystem,
    onDeployJammer,
    onUndeployJammer,
  });
  const { isPlacementActive, coordinates, status } = deployment;

  // null until the player touches the checkbox; until then the SAMs keep their own status
  const [samWeaponsFree, setSamWeaponsFree] = useState<boolean | null>(null);

  // The host input holds the last submitted result; it goes stale as soon as any
  // input of that result changes, so remember which inputs it was built from
  const resultInputs = [budget, airbases, deployedJammers, deployedSystems, samWeaponsFree];
  const [submittedInputs, setSubmittedInputs] = useState<unknown[] | null>(null);
  const isSubmitted =
    submittedInputs !== null && submittedInputs.every((input, i) => input === resultInputs[i]);

  const handleSubmit = () => {
    const result = toSetupResult({
      budget,
      airbases,
      jammers,
      deployedJammers,
      deployedMissileSystems: deployedSystems,
    });
    const doctrine = toEmconResult(samUnits);
    const isDeploymentWritten = writeHostInput('summaryData', result);
    const isDoctrineWritten = writeHostInput('emconData', doctrine);
    console.log('Export data:', result, doctrine);
    if (isDeploymentWritten && isDoctrineWritten) setSubmittedInputs(resultInputs);
  };

  const [sidebarWidth, setSidebarWidth] = useState(DEFAULT_SIDEBAR_WIDTH);

  const missileGroups = useMemo(
    () => buildMissileGroups(missileSystems, deployedSystems),
    [missileSystems, deployedSystems]
  );
  const launcherGroups = useMemo(
    () => missileGroups.filter((group) => group.category !== SAM_CATEGORY),
    [missileGroups]
  );
  const deployedLaunchers = launcherGroups.reduce((sum, group) => sum + group.deployedCount, 0);
  const totalLaunchers = launcherGroups.reduce((sum, group) => sum + group.units.length, 0);

  const [c2Data] = useState(() =>
    parseInjectedJSON<C2Data>(window.__INJECT_C2__, UNIT_STATUS_DATA.c2, 'C2')
  );
  const [signals] = useState(() =>
    parseInjectedJSON<SignalData[]>(window.__INJECT_SIGNALS__, UNIT_STATUS_DATA.signals, 'SIGNALS')
  );
  const [launcherStatus] = useState(() =>
    buildLauncherStatusMap(
      parseInjectedJSON<MissileSystemData>(
        window.__INJECT_LAUNCHERS__,
        UNIT_STATUS_DATA.launchers,
        'LAUNCHERS'
      )
    )
  );
  const [landingUnits] = useState(() =>
    parseInjectedJSON<LandingUnitsData>(
      window.__INJECT_LANDING_UNITS__,
      UNIT_STATUS_DATA.landingUnits,
      'LANDING_UNITS'
    )
  );
  const c2Nodes = useMemo(() => {
    const samLaunchers = missileGroups.find((group) => group.category === SAM_CATEGORY)?.units;
    return buildC2NodeViews(flattenC2Nodes(c2Data), samLaunchers ?? []);
  }, [c2Data, missileGroups]);
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
          <JammerPanel
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
          <C2NodesPanel
            nodes={shownC2Nodes}
            samWeaponsFree={samUnits.length > 0 && samUnits.every((sam) => sam.weaponFree)}
            onSamWeaponsFreeChange={setSamWeaponsFree}
            launcherStatus={launcherStatus}
            samCategory={SAM_CATEGORY}
            expandedUnitKey={deployment.expandedUnitKey}
            selectedUnitKey={deployment.selectedUnitKey}
            onUnitSelect={isDeploymentLocked ? noop : deployment.handleUnitSelect}
            onUndeploy={isDeploymentLocked ? noop : deployment.handleUndeploy}
            onCancelSelection={deployment.handleCancelSelect}
          />
        </Panel>

        <Panel title="Signals" badge={`${signals.length}`}>
          <SignalPanel signals={signals} />
        </Panel>

        {showLandingUnits && (
          <Panel title="Landing Units" badge={`${Object.keys(landingUnits).length}`}>
            <LandingUnitsPanel landingUnits={landingUnits} />
          </Panel>
        )}

        <Panel
          title="Missile Launchers"
          locked={isDeploymentLocked}
          badge={`${deployedLaunchers}/${totalLaunchers}`}
        >
          <LauncherPanel
            missileGroups={launcherGroups}
            launcherStatus={launcherStatus}
            collapsedCategories={deployment.collapsedCategories}
            expandedUnitKey={deployment.expandedUnitKey}
            selectedUnitKey={deployment.selectedUnitKey}
            onToggleCategory={deployment.toggleCategory}
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
          <AircraftBasesPanel
            airbases={airbases}
            baselineAirbases={baselineAirbases}
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
          deployedSystems={deployedSystems}
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
          onMapClick={isDeploymentLocked ? noop : deployment.handleMapClick}
          onMouseMove={deployment.handleMouseMove}
          onAreaClick={isDeploymentLocked ? noop : deployment.handleAreaClick}
          onRotateClick={isDeploymentLocked ? noop : deployment.handleRotateClick}
          onJammerRelocateClick={isDeploymentLocked ? noop : deployment.handleJammerRelocateClick}
        />
      </div>
    </div>
  );
}
