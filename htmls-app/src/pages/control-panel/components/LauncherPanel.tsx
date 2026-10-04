import { ImageIcon } from '@/components/ImageIcon';
import { getLauncherImage } from '@/components/Map';
import { CollapsibleGroup } from '@pages/control-panel/components/CollapsibleGroup';
import { DeployableUnitCard } from '@pages/control-panel/components/DeployableUnitCard';
import type { MissileGroup } from '@pages/control-panel/missileGroups';
import { getLauncherStatus, type LauncherStatusMap } from '../launcherStatus';
import { LauncherStatusDetails } from './LauncherStatusDetails';

// ============================================================================
// LauncherPanel — missile launcher groups for the control panel
// ============================================================================
interface LauncherPanelProps {
  missileGroups: MissileGroup[];
  launcherStatus: LauncherStatusMap;
  collapsedCategories: Set<string>;
  expandedUnitKey: string | null;
  /** Missile unit armed for deployment, null when no deploy mode is live */
  selectedUnitKey: string | null;
  onToggleCategory: (category: string) => void;
  onUnitSelect: (unitKey: string, unitName: string, category: string) => void;
  onUndeploy: (unitKey: string, unitName: string) => void;
  onCancelSelection: () => void;
}

export function LauncherPanel({
  missileGroups,
  launcherStatus,
  collapsedCategories,
  expandedUnitKey,
  selectedUnitKey,
  onToggleCategory,
  onUnitSelect,
  onUndeploy,
  onCancelSelection,
}: LauncherPanelProps) {
  if (missileGroups.length === 0) {
    return (
      <div className="text-xs italic text-text-secondary">No missile system units available</div>
    );
  }

  return (
    <div className="space-y-2">
      {missileGroups.map((group) => (
        <CollapsibleGroup
          variant="aip"
          key={group.category}
          title={group.weaponName}
          deployedCount={group.deployedCount}
          totalCount={group.units.length}
          isCollapsed={collapsedCategories.has(group.category)}
          onToggle={() => onToggleCategory(group.category)}
        >
          {group.units.map((unit) => (
            <DeployableUnitCard
              variant="aip"
              key={unit.unitKey}
              name={unit.name}
              icon={<ImageIcon image={getLauncherImage(group.category)} />}
              details={
                <LauncherDetails
                  group={group}
                  unit={unit}
                  launcherStatus={launcherStatus}
                  isOpen={selectedUnitKey === unit.unitKey || expandedUnitKey === unit.unitKey}
                />
              }
              deployedSummary={unit.isDeployed ? `✓ Deployed | Angle: ${unit.openingAngle}°` : null}
              isDeployed={unit.isDeployed}
              isSelected={selectedUnitKey === unit.unitKey}
              isExpanded={expandedUnitKey === unit.unitKey}
              onSelect={() => onUnitSelect(unit.unitKey, unit.name, group.category)}
              onCancelDeployment={() => onUndeploy(unit.unitKey, unit.name)}
              onCancelSelection={onCancelSelection}
            />
          ))}
        </CollapsibleGroup>
      ))}
    </div>
  );
}

function LauncherDetails({
  group,
  unit,
  launcherStatus,
  isOpen,
}: {
  group: MissileGroup;
  unit: MissileGroup['units'][number];
  launcherStatus: LauncherStatusMap;
  /** Status stays folded until the card is clicked open */
  isOpen: boolean;
}) {
  const status = getLauncherStatus(launcherStatus, group.category, unit.name);
  return (
    <>
      <div>SYSTEM: {group.systemName}</div>
      {isOpen && status && <LauncherStatusDetails status={status} />}
    </>
  );
}
