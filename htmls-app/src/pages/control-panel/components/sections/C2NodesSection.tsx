import { ImageIcon } from '@/components/ImageIcon';
import { ICON_IMAGES } from '@/components/map';
import { DeployableUnitCard } from '@pages/control-panel/components/sections/DeployableUnitCard';
import type { Battery } from '../../logic/batteryGroups';
import type { C2Child, C2NodeView } from '../../logic/c2Nodes';
import { DetailsBox, TextRow } from '@pages/control-panel/components/shared/DetailsBox';
import { InfoCard } from '@pages/control-panel/components/shared/InfoCard';
import { BatteryStatusDetails } from '@pages/control-panel/components/sections/BatteryStatusDetails';
import { SamDoctrineToggle } from '@pages/control-panel/components/sections/SamDoctrineToggle';
import { TreeRow } from '@pages/control-panel/components/shared/TreeRow';

// ============================================================================
// C2NodesSection — C2 nodes on the left, their radar and SAM units on the right
// ============================================================================
interface C2NodesSectionProps {
  nodes: C2NodeView[];
  isSamWeaponsFree: boolean;
  onSamWeaponsFreeChange: (isWeaponsFree: boolean) => void;
  expandedUnitKey: string | null;
  selectedUnitKey: string | null;
  onUnitSelect: (battery: Battery) => void;
  onUndeploy: (battery: Battery) => void;
  onCancelSelection: () => void;
}

export function C2NodesSection({
  nodes,
  isSamWeaponsFree,
  onSamWeaponsFreeChange,
  expandedUnitKey,
  selectedUnitKey,
  onUnitSelect,
  onUndeploy,
  onCancelSelection,
}: C2NodesSectionProps) {
  return (
    <div>
      <SamDoctrineToggle isWeaponsFree={isSamWeaponsFree} onChange={onSamWeaponsFreeChange} />
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
  'nodes' | 'isSamWeaponsFree' | 'onSamWeaponsFreeChange'
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
  const details = battery && (
    <div>
      {battery.missileSystemType.toUpperCase()}|{battery.missileSystem}
    </div>
  );
  // Folds open when the card is clicked
  const foldedDetails = (
    <DetailsBox title="Details">
      <UnitDetails type={type} unit={unit} />
      {battery?.status && <BatteryStatusDetails status={battery.status} />}
    </DetailsBox>
  );
  const icon = <ImageIcon image={type === 'sam' ? ICON_IMAGES.sam : ICON_IMAGES.radar} />;

  if (!battery) {
    return (
      <InfoCard name={unit.name} icon={icon} details={details} foldedDetails={foldedDetails} />
    );
  }

  return (
    <DeployableUnitCard
      name={battery.name}
      icon={icon}
      details={details}
      foldedDetails={foldedDetails}
      deployedSummary={
        battery.deployment ? `Deployed | Angle: ${battery.deployment.openingAngle}°` : null
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

function UnitDetails({ type, unit }: { type: C2Child['type']; unit: C2Child['unit'] }) {
  return (
    <>
      <TextRow label="Type" value={type.toUpperCase()} />
      <TextRow label="Detection" value={unit.OODADetection} />
      <TextRow label="Targeting" value={unit.OODATargeting} />
      <TextRow label="EMCON" value={unit.EMCONSetting} />
      {unit.isOutOfComms && <TextRow label="Comms" value="OUT OF COMMS" tone="danger" />}
      {unit.isDestroyed && <TextRow label="Condition" value="DESTROYED" tone="danger" />}
      {'weaponFree' in unit && unit.weaponFree ? (
        <TextRow label="Doctrine" value="WEAPON FREE" tone="danger" />
      ) : (
        <TextRow label="Doctrine" value="HOLD FIRE" tone="warning" />
      )}
    </>
  );
}
