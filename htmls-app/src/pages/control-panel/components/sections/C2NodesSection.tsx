import { ImageIcon } from '@/components/ImageIcon';
import { ICON_IMAGES } from '@/components/Map';
import { DeployableUnitCard } from '@pages/control-panel/components/sections/DeployableUnitCard';
import type { Battery } from '../../logic/batteryGroups';
import type { C2Child, C2NodeView } from '../../logic/c2Nodes';
import { InfoCard } from '@pages/control-panel/components/shared/InfoCard';
import { BatteryStatusDetails } from '@pages/control-panel/components/sections/BatteryStatusDetails';
import { SamDoctrineToggle } from '@pages/control-panel/components/sections/SamDoctrineToggle';
import { TreeRow } from '@pages/control-panel/components/shared/TreeRow';

// ============================================================================
// C2NodesSection — C2 nodes on the left, their radar and SAM units on the right
// ============================================================================
interface C2NodesSectionProps {
  nodes: C2NodeView[];
  samWeaponsFree: boolean;
  onSamWeaponsFreeChange: (weaponsFree: boolean) => void;
  expandedUnitKey: string | null;
  selectedUnitKey: string | null;
  onUnitSelect: (battery: Battery) => void;
  onUndeploy: (battery: Battery) => void;
  onCancelSelection: () => void;
}

export function C2NodesSection({
  nodes,
  samWeaponsFree,
  onSamWeaponsFreeChange,
  expandedUnitKey,
  selectedUnitKey,
  onUnitSelect,
  onUndeploy,
  onCancelSelection,
}: C2NodesSectionProps) {
  return (
    <div>
      <SamDoctrineToggle weaponsFree={samWeaponsFree} onChange={onSamWeaponsFreeChange} />
      {nodes.length === 0 && (
        <div className="text-xs italic text-text-secondary">No C2 node data available</div>
      )}
      <div className="space-y-4">
        {nodes.map((node) => (
          <TreeRow
            key={node.key}
            root={
              <InfoCard
                name={node.name}
                icon={<ImageIcon image={ICON_IMAGES.c2} />}
                details={<div>{node.children.length} subordinate units</div>}
              />
            }
            leaves={node.children.map((child) => ({
              key: child.key,
              node: (
                <ChildCard
                  child={child}
                  expandedUnitKey={expandedUnitKey}
                  selectedUnitKey={selectedUnitKey}
                  onUnitSelect={onUnitSelect}
                  onUndeploy={onUndeploy}
                  onCancelSelection={onCancelSelection}
                />
              ),
            }))}
            emptyMessage="No subordinate units"
          />
        ))}
      </div>
    </div>
  );
}

// ============================================================================
// ChildCard — deployable when the SAM has a battery, plain otherwise
// ============================================================================
interface ChildCardProps extends Omit<
  C2NodesSectionProps,
  'nodes' | 'samWeaponsFree' | 'onSamWeaponsFreeChange'
> {
  child: C2Child;
}

function ChildCard({
  child,
  expandedUnitKey,
  selectedUnitKey,
  onUnitSelect,
  onUndeploy,
  onCancelSelection,
}: ChildCardProps) {
  const { unit, battery, type } = child;
  // Status stays folded until the card is clicked open
  const isOpen =
    battery !== null &&
    (selectedUnitKey === battery.unitKey || expandedUnitKey === battery.unitKey);
  const details = (
    <>
      <UnitDetails type={type} unit={unit} battery={battery} />
      {isOpen && battery?.status && <BatteryStatusDetails status={battery.status} />}
    </>
  );
  const icon = type === 'SAM' ? <ImageIcon image={ICON_IMAGES.sam} /> : undefined;

  if (!battery) {
    return <InfoCard name={unit.name} icon={icon} details={details} />;
  }

  return (
    <DeployableUnitCard
      name={battery.name}
      icon={icon}
      details={details}
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
  );
}

function UnitDetails({
  type,
  unit,
  battery,
}: {
  type: C2Child['type'];
  unit: C2Child['unit'];
  battery: C2Child['battery'];
}) {
  return (
    <>
      {battery && (
        <div>
          {battery.missileSystemType.toUpperCase()}|{battery.missileSystem}
        </div>
      )}
      <div>
        {type.toUpperCase()} | DETECT {unit.OODADetection} | TARGET {unit.OODATargeting}
      </div>
      <div>{unit.EMCONSetting}</div>
      {unit.isOutOfComms && <div className="text-status-danger">OUT OF COMMS</div>}
      {unit.isDestroyed && <div className="text-status-danger">DESTROYED</div>}
      {unit.weaponFree == true ? (
        <div className="text-status-danger">WEAPON FREE</div>
      ) : (
        <div className="text-status-warning">HOLD FIRE</div>
      )}
    </>
  );
}
