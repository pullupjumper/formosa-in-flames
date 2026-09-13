import { useState, useCallback } from 'react';
import type { Coordinate } from '@/types/geo';
import type { Airbase, SetupMenuTabId, MissileDeployment } from '@/types/setupMenu';
import { CONFIG } from '@/constants/setupMenu';
import { PageShell, type PageTab } from '@/components/PageShell';
import { readSetupMenuData, buildInjectedDeployments } from '@/utils/setupMenuPayload';
import { createBudgetState } from '@/utils/budgetLedger';
import { MechanicsTab } from './components/MechanicsTab';
import { DeploymentTab } from './components/DeploymentTab';
import { OpordTab } from './components/OpordTab';
import { SummaryTab } from './components/SummaryTab';

// ============================================================================
// TAB CONFIGURATION
// ============================================================================
const TABS: PageTab<SetupMenuTabId>[] = [
  { id: 'opord', label: 'OPORD' },
  { id: 'mechanics', label: 'Game Mechanics' },
  { id: 'deployment', label: 'Deployment' },
  { id: 'summary', label: 'Summary' },
];

// ============================================================================
// MAIN COMPONENT
// ============================================================================
function SetupMenuPage() {
  const [activeTab, setActiveTab] = useState<SetupMenuTabId>('opord');
  const [budget, setBudget] = useState(() => createBudgetState(CONFIG.INITIAL_SCORE));
  const [injectedData] = useState(readSetupMenuData);
  const [airbases, setAirbases] = useState(() => structuredClone(injectedData.airbases));
  const { jammers, amphibiousLocations, missileSystems, sideName } = injectedData;
  const shouldValidateTaiwanBoundary = sideName === 'Taiwan';
  const [deployedJammers, setDeployedJammers] = useState<Map<number, Coordinate>>(new Map());
  // Units the scenario already placed start out deployed; the injected payload
  // is read once, so seeding state here replaces a setState-in-effect.
  const [deployedMissileSystems, setDeployedMissileSystems] = useState(() =>
    buildInjectedDeployments(missileSystems)
  );

  const updateAirbase = useCallback((index: number, updater: (base: Airbase) => Airbase) => {
    setAirbases((prev) => prev.map((base, i) => (i === index ? updater(base) : base)));
  }, []);

  // Deployment handlers — kept stable so DeploymentTab's memoized map layers are
  // not invalidated by unrelated re-renders (e.g. budget edits)
  const deployMissileSystem = useCallback((key: string, data: MissileDeployment) => {
    setDeployedMissileSystems((prev) => new Map(prev).set(key, data));
  }, []);

  const undeployMissileSystem = useCallback((key: string) => {
    setDeployedMissileSystems((prev) => {
      const next = new Map(prev);
      next.delete(key);
      return next;
    });
  }, []);

  const deployJammer = useCallback((index: number, position: Coordinate) => {
    setDeployedJammers((prev) => new Map(prev).set(index, position));
  }, []);

  const undeployJammer = useCallback((index: number) => {
    setDeployedJammers((prev) => {
      const next = new Map(prev);
      next.delete(index);
      return next;
    });
  }, []);

  return (
    <PageShell
      title={sideName.toUpperCase()}
      subtitle="DEPLOYMENT PLANNING"
      tabs={TABS}
      activeTab={activeTab}
      onTabChange={setActiveTab}
    >
      {activeTab === 'opord' && <OpordTab amphibiousLocations={amphibiousLocations} />}
      {activeTab === 'mechanics' && <MechanicsTab />}
      {activeTab === 'deployment' && (
        <DeploymentTab
          missileSystems={missileSystems}
          airbases={airbases}
          baselineAirbases={injectedData.airbases}
          jammers={jammers}
          budget={budget}
          deployedSystems={deployedMissileSystems}
          deployedJammers={deployedJammers}
          shouldValidateTaiwanBoundary={shouldValidateTaiwanBoundary}
          sideName={sideName}
          onDeploySystem={deployMissileSystem}
          onUndeploySystem={undeployMissileSystem}
          onDeployJammer={deployJammer}
          onUndeployJammer={undeployJammer}
          onBudgetChange={setBudget}
          onUpdateAirbase={updateAirbase}
        />
      )}
      {activeTab === 'summary' && (
        <SummaryTab
          budget={budget}
          airbases={airbases}
          jammers={jammers}
          missileSystems={missileSystems}
          deployedJammers={deployedJammers}
          deployedMissileSystems={deployedMissileSystems}
        />
      )}
    </PageShell>
  );
}

export default SetupMenuPage;
