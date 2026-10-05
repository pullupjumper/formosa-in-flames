import { ImageIcon } from '@/components/ImageIcon';
import { getBatteryImage } from '@/components/Map';
import { DeployableUnitCard } from '@pages/control-panel/components/DeployableUnitCard';
import type { MissileGroup } from '@pages/control-panel/missileGroups';
import { getBatteryStatus, type BatteryStatusMap } from '../batteryStatus';
import { BatteryStatusDetails } from './BatteryStatusDetails';

// ============================================================================
// BatterySection — missile battery groups for the control panel
// ============================================================================
interface BatterySectionProps {
  missileGroups: MissileGroup[];
  batteryStatusMap: BatteryStatusMap;
  expandedUnitKey: string | null;
  /** Missile unit armed for deployment, null when no deploy mode is live */
  selectedUnitKey: string | null;
  onUnitSelect: (unitKey: string, unitName: string, category: string) => void;
  onUndeploy: (unitKey: string, unitName: string) => void;
  onCancelSelection: () => void;
}

export function BatterySection({
  missileGroups,
  batteryStatusMap,
  expandedUnitKey,
  selectedUnitKey,
  onUnitSelect,
  onUndeploy,
  onCancelSelection,
}: BatterySectionProps) {
  if (missileGroups.length === 0) {
    return (
      <div className="text-xs italic text-text-secondary">No missile system units available</div>
    );
  }

  return (
    <div className="space-y-2">
      {missileGroups.flatMap((group) =>
        group.units.map((unit) => (
          <DeployableUnitCard
            key={unit.unitKey}
            name={unit.name}
            icon={<ImageIcon image={getBatteryImage(group.category)} />}
            details={
              <BatteryDetails
                group={group}
                unit={unit}
                batteryStatusMap={batteryStatusMap}
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
        ))
      )}
    </div>
  );
}

function BatteryDetails({
  group,
  unit,
  batteryStatusMap,
  isOpen,
}: {
  group: MissileGroup;
  unit: MissileGroup['units'][number];
  batteryStatusMap: BatteryStatusMap;
  /** Status stays folded until the card is clicked open */
  isOpen: boolean;
}) {
  const status = getBatteryStatus(batteryStatusMap, group.category, unit.name);
  return (
    <>
      <div>SYSTEM: {group.systemName}</div>
      {isOpen && status && <BatteryStatusDetails status={status} />}
    </>
  );
}
