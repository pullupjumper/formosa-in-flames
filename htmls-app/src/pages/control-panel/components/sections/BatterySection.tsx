import { ImageIcon } from '@/components/ImageIcon';
import { getBatteryImage } from '@/components/map';
import { DeployableUnitCard } from '@pages/control-panel/components/sections/DeployableUnitCard';
import type { Battery, BatteryGroup } from '@pages/control-panel/logic/batteryGroups';
import { BatteryStatusDetails } from '@pages/control-panel/components/sections/BatteryStatusDetails';

// ============================================================================
// BatterySection — missile battery groups for the control panel
// ============================================================================
interface BatterySectionProps {
  batteryGroups: BatteryGroup[];
  expandedUnitKey: string | null;
  /** Missile unit armed for deployment, null when no deploy mode is live */
  selectedUnitKey: string | null;
  onUnitSelect: (battery: Battery) => void;
  onUndeploy: (battery: Battery) => void;
  onCancelSelection: () => void;
}

export function BatterySection({
  batteryGroups,
  expandedUnitKey,
  selectedUnitKey,
  onUnitSelect,
  onUndeploy,
  onCancelSelection,
}: BatterySectionProps) {
  if (batteryGroups.length === 0) {
    return (
      <div className="text-xs italic text-text-secondary">No missile system units available</div>
    );
  }

  return (
    <div className="space-y-2">
      {batteryGroups.flatMap((group) =>
        group.batteries.map((battery) => (
          <DeployableUnitCard
            key={battery.unitKey}
            name={battery.name}
            icon={<ImageIcon image={getBatteryImage(group.missileSystemType)} />}
            details={
              <BatteryDetails
                battery={battery}
                isOpen={selectedUnitKey === battery.unitKey || expandedUnitKey === battery.unitKey}
              />
            }
            deployedSummary={
              battery.deployment ? `✓ Deployed | Angle: ${battery.deployment.openingAngle}°` : null
            }
            isDeployed={battery.deployment !== null}
            isSelected={selectedUnitKey === battery.unitKey}
            isExpanded={expandedUnitKey === battery.unitKey}
            onSelect={() => onUnitSelect(battery)}
            onCancelDeployment={() => onUndeploy(battery)}
            onCancelSelection={onCancelSelection}
          />
        ))
      )}
    </div>
  );
}

function BatteryDetails({
  battery,
  isOpen,
}: {
  battery: Battery;
  /** Status stays folded until the card is clicked open */
  isOpen: boolean;
}) {
  return (
    <>
      <div>
        {battery.missileSystemType.toUpperCase()}|{battery.missileSystem}
      </div>
      {isOpen && battery.status && <BatteryStatusDetails status={battery.status} />}
    </>
  );
}
