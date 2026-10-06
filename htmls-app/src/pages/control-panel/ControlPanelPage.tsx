import { useState } from 'react';
import type { AddUnitsMenuResult } from '@/types/addUnitsMenu';
import { PageShell, type PageTab } from '@/components/PageShell';
import { useActionSelection } from '@pages/control-panel/hooks/useActionSelection';
import { MechanicsTab } from '@pages/control-panel/components/tabs/MechanicsTab';
import { OpordTab } from '@pages/control-panel/components/tabs/OpordTab';
import { useDeploymentSession } from '@pages/control-panel/hooks/useDeploymentSession';
import { AddUnitsTab } from '@pages/control-panel/components/tabs/AddUnitsTab';
import { ControlDeploymentTab } from '@pages/control-panel/components/tabs/ControlDeploymentTab';
import { resolveControlPanelView } from './logic/controlPanelMode';
import { readControlPanelPayload, submitSelectedActions } from './logic/controlPanelPayload';

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
  const [payload] = useState(readControlPanelPayload);
  const view = resolveControlPanelView(payload.mode);
  const tabs = view.showAddUnits ? ALL_TABS : ALL_TABS.filter((tab) => tab.id !== 'add-units');
  const [activeTab, setActiveTab] = useState<ControlPanelTabId>('opord');
  const session = useDeploymentSession(payload);
  const { sideName } = payload;

  // Selection lives above the tabs so it survives switching away and back
  const actions = payload.addUnitActions;
  const { checked, selectedIds, toggle, toggleAll } = useActionSelection({ actions });
  const [submittedKey, setSubmittedKey] = useState<string | null>(null);
  const selectionKey = selectedIds.join(',');

  const handleAddUnitsSubmit = () => {
    const result: AddUnitsMenuResult = { actionIds: selectedIds };
    console.log('Add units data:', result);
    if (submitSelectedActions(result)) setSubmittedKey(selectionKey);
  };

  return (
    <PageShell
      title={sideName.toUpperCase()}
      subtitle="CONTROL PANEL"
      tabs={tabs}
      activeTab={activeTab}
      onTabChange={setActiveTab}
    >
      {activeTab === 'opord' && <OpordTab amphibiousLocations={payload.amphibiousLocations} />}
      {activeTab === 'mechanics' && <MechanicsTab />}
      {activeTab === 'deployment' && (
        <ControlDeploymentTab
          payload={payload}
          session={session}
          showLandingUnits={view.showLandingUnits}
          isDeploymentLocked={view.isDeploymentLocked}
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
