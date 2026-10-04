import { useState } from 'react';
import type { AddUnitsMenuResult } from '@/types/addUnitsMenu';
import { PageShell, type PageTab } from '@/components/PageShell';
import { readAddUnitsMenuData } from '@/utils/addUnitsMenuPayload';
import { writeHostInput } from '@/utils/inject';
import { useActionSelection } from '@pages/control-panel/hooks/useActionSelection';
import { MechanicsTab } from '@pages/control-panel/components/MechanicsTab';
import { OpordTab } from '@pages/control-panel/components/OpordTab';
import { useSetupMenuState } from '@pages/control-panel/hooks/useSetupMenuState';
import { AddUnitsTab } from './components/AddUnitsTab';
import { ControlDeploymentTab } from './components/ControlDeploymentTab';
import { readControlPanelMode, resolveControlPanelView } from './controlPanelMode';

// ============================================================================
// TAB CONFIGURATION
// ============================================================================
type ControlPanelTabId = 'opord' | 'mechanics' | 'deployment' | 'add-units';

const ALL_TABS: PageTab<ControlPanelTabId>[] = [
  { id: 'opord', label: 'OPORD' },
  { id: 'mechanics', label: 'Game Mechanics' },
  { id: 'deployment', label: 'Deployment' },
  { id: 'add-units', label: 'Add Units' },
];

// ============================================================================
// MAIN COMPONENT
// ============================================================================
function ControlPanelPage() {
  const [view] = useState(() => resolveControlPanelView(readControlPanelMode()));
  const tabs = view.showAddUnits ? ALL_TABS : ALL_TABS.filter((tab) => tab.id !== 'add-units');
  const [activeTab, setActiveTab] = useState<ControlPanelTabId>('opord');
  const state = useSetupMenuState();
  const { injectedData } = state;
  const { jammers, amphibiousLocations, missileSystems, sideName } = injectedData;

  // Selection lives above the tabs so it survives switching away and back
  const [{ actions }] = useState(readAddUnitsMenuData);
  const { checked, selectedIds, toggle, toggleAll } = useActionSelection({ actions });
  const [submittedKey, setSubmittedKey] = useState<string | null>(null);
  const selectionKey = selectedIds.join(',');

  const handleAddUnitsSubmit = () => {
    const result: AddUnitsMenuResult = { actionIds: selectedIds };
    console.log('Add units data:', result);
    if (writeHostInput('selectedActions', result)) setSubmittedKey(selectionKey);
  };

  return (
    <PageShell
      title={sideName.toUpperCase()}
      subtitle="CONTROL PANEL"
      tabs={tabs}
      activeTab={activeTab}
      onTabChange={setActiveTab}
    >
      {activeTab === 'opord' && <OpordTab amphibiousLocations={amphibiousLocations} />}
      {activeTab === 'mechanics' && <MechanicsTab />}
      {activeTab === 'deployment' && (
        <ControlDeploymentTab
          missileSystems={missileSystems}
          airbases={state.airbases}
          baselineAirbases={injectedData.airbases}
          jammers={jammers}
          budget={state.budget}
          deployedSystems={state.deployedMissileSystems}
          deployedJammers={state.deployedJammers}
          shouldValidateTaiwanBoundary={sideName === 'Taiwan'}
          sideName={sideName}
          showLandingUnits={view.showLandingUnits}
          isDeploymentLocked={view.isDeploymentLocked}
          onDeploySystem={state.deployMissileSystem}
          onUndeploySystem={state.undeployMissileSystem}
          onDeployJammer={state.deployJammer}
          onUndeployJammer={state.undeployJammer}
          onBudgetChange={state.setBudget}
          onUpdateAirbase={state.updateAirbase}
        />
      )}
      {view.showAddUnits && activeTab === 'add-units' && (
        <AddUnitsTab
          actions={actions}
          checked={checked}
          selectedIds={selectedIds}
          isSubmitted={submittedKey === selectionKey}
          onToggle={toggle}
          onToggleAll={toggleAll}
          onSubmit={handleAddUnitsSubmit}
        />
      )}
    </PageShell>
  );
}

export default ControlPanelPage;
