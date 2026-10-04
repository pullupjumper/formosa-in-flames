import { ImageIcon } from '@/components/ImageIcon';
import { ICON_IMAGES } from '@/components/Map';
import { DeployableUnitCard } from '@pages/control-panel/components/DeployableUnitCard';
import type { C2Child, C2NodeView } from '../c2Nodes';
import { getLauncherStatus, type LauncherStatusMap } from '../launcherStatus';
import { InfoCard } from './InfoCard';
import { LauncherStatusDetails } from './LauncherStatusDetails';
import { SamDoctrineToggle } from './SamDoctrineToggle';
import { TreeRow } from './TreeRow';

// ============================================================================
// C2NodesPanel — C2 nodes on the left, their radar and SAM units on the right
// ============================================================================
interface C2NodesPanelProps {
  nodes: C2NodeView[];
  samWeaponsFree: boolean;
  onSamWeaponsFreeChange: (weaponsFree: boolean) => void;
  launcherStatus: LauncherStatusMap;
  /** Weapon category the SAM launchers are deployed under */
  samCategory: string;
  expandedUnitKey: string | null;
  selectedUnitKey: string | null;
  onUnitSelect: (unitKey: string, unitName: string, category: string) => void;
  onUndeploy: (unitKey: string, unitName: string) => void;
  onCancelSelection: () => void;
}

export function C2NodesPanel({
  nodes,
  samWeaponsFree,
  onSamWeaponsFreeChange,
  launcherStatus,
  samCategory,
  expandedUnitKey,
  selectedUnitKey,
  onUnitSelect,
  onUndeploy,
  onCancelSelection,
}: C2NodesPanelProps) {
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
                  launcherStatus={launcherStatus}
                  samCategory={samCategory}
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
// ChildCard — deployable when the SAM has a launcher, plain otherwise
// ============================================================================
interface ChildCardProps extends Omit<
  C2NodesPanelProps,
  'nodes' | 'samWeaponsFree' | 'onSamWeaponsFreeChange'
> {
  child: C2Child;
}

function ChildCard({
  child,
  launcherStatus,
  samCategory,
  expandedUnitKey,
  selectedUnitKey,
  onUnitSelect,
  onUndeploy,
  onCancelSelection,
}: ChildCardProps) {
  const { unit, launcher, type } = child;
  const launcherState = launcher
    ? getLauncherStatus(launcherStatus, samCategory, launcher.name)
    : undefined;
  // Status stays folded until the card is clicked open
  const isOpen =
    launcher !== null &&
    (selectedUnitKey === launcher.unitKey || expandedUnitKey === launcher.unitKey);
  const details = (
    <>
      <UnitDetails type={type} unit={unit} />
      {isOpen && launcherState && <LauncherStatusDetails status={launcherState} />}
    </>
  );
  const icon = type === 'SAM' ? <ImageIcon image={ICON_IMAGES.sam} /> : undefined;

  if (!launcher) {
    return <InfoCard name={unit.name} icon={icon} details={details} />;
  }

  return (
    <DeployableUnitCard
      name={launcher.name}
      icon={icon}
      details={details}
      deployedSummary={`✓ Deployed | Angle: ${launcher.openingAngle}°`}
      isDeployed={launcher.isDeployed}
      isSelected={selectedUnitKey === launcher.unitKey}
      isExpanded={expandedUnitKey === launcher.unitKey}
      onSelect={() => onUnitSelect(launcher.unitKey, launcher.name, samCategory)}
      onCancelDeployment={() => onUndeploy(launcher.unitKey, launcher.name)}
      onCancelSelection={onCancelSelection}
    />
  );
}

function UnitDetails({ type, unit }: { type: C2Child['type']; unit: C2Child['unit'] }) {
  return (
    <>
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
