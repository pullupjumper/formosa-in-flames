import type { Coordinate } from '@/types/geo';
import type { Jammer } from '@/types/setupMenu';
import { CollapsibleGroup } from './CollapsibleGroup';
import { DeployableUnitCard } from './DeployableUnitCard';
import type { MissileGroup } from '../missileGroups';

// ============================================================================
// GroundUnitsPanel — sidebar list of jammers and missile systems
// ============================================================================
interface GroundUnitsPanelProps {
  jammers: Jammer[];
  deployedJammers: Map<number, Coordinate>;
  isJammersCollapsed: boolean;
  expandedJammerIndex: number | null;
  /** Jammer index armed for a fresh deployment, null while relocating or idle */
  selectedJammerIndex: number | null;

  missileGroups: MissileGroup[];
  collapsedCategories: Set<string>;
  expandedUnitKey: string | null;
  /** Missile unit armed for deployment, null when no deploy mode is live */
  selectedUnitKey: string | null;

  onToggleJammers: () => void;
  onJammerSelect: (index: number) => void;
  onUndeployJammer: (index: number) => void;
  onToggleCategory: (category: string) => void;
  onUnitSelect: (unitKey: string, unitName: string, category: string) => void;
  onUndeploy: (unitKey: string, unitName: string) => void;
  onCancelSelection: () => void;
}

export function GroundUnitsPanel({
  jammers,
  deployedJammers,
  isJammersCollapsed,
  expandedJammerIndex,
  selectedJammerIndex,
  missileGroups,
  collapsedCategories,
  expandedUnitKey,
  selectedUnitKey,
  onToggleJammers,
  onJammerSelect,
  onUndeployJammer,
  onToggleCategory,
  onUnitSelect,
  onUndeploy,
  onCancelSelection,
}: GroundUnitsPanelProps) {
  return (
    <div className="mb-4">
      <div className="mb-2 text-xs font-semibold">Available Units</div>
      <div className="space-y-2">
        <CollapsibleGroup
          title="GPS Jammers"
          deployedCount={deployedJammers.size}
          totalCount={jammers.length}
          isCollapsed={isJammersCollapsed}
          onToggle={onToggleJammers}
        >
          {jammers.length === 0 ? (
            <div className="text-xs italic text-text-secondary">No jammer units available</div>
          ) : (
            jammers.map((jammer, index) => {
              const deployment = deployedJammers.get(index);
              return (
                <DeployableUnitCard
                  key={index}
                  name={jammer.name}
                  details={
                    <>
                      <div>ZONE: {jammer.zoneName}</div>
                      <div>RANGE: {jammer.radius} NM</div>
                    </>
                  }
                  deployedSummary={
                    deployment
                      ? `✓ Deployed at ${deployment.latitude.toFixed(4)}°, ${deployment.longitude.toFixed(4)}°`
                      : null
                  }
                  isDeployed={deployment !== undefined}
                  isSelected={selectedJammerIndex === index}
                  isExpanded={expandedJammerIndex === index}
                  onSelect={() => onJammerSelect(index)}
                  onCancelDeployment={() => onUndeployJammer(index)}
                  onCancelSelection={onCancelSelection}
                />
              );
            })
          )}
        </CollapsibleGroup>

        {missileGroups.length === 0 ? (
          <div className="text-xs italic text-text-secondary">
            No missile system units available
          </div>
        ) : (
          missileGroups.map((group) => (
            <CollapsibleGroup
              key={group.category}
              title={group.weaponName}
              deployedCount={group.deployedCount}
              totalCount={group.units.length}
              isCollapsed={collapsedCategories.has(group.category)}
              onToggle={() => onToggleCategory(group.category)}
            >
              {group.units.map((unit) => (
                <DeployableUnitCard
                  key={unit.unitKey}
                  name={unit.name}
                  details={<div>SYSTEM: {group.systemName}</div>}
                  deployedSummary={
                    unit.isDeployed ? `✓ Deployed | Angle: ${unit.openingAngle}°` : null
                  }
                  isDeployed={unit.isDeployed}
                  isSelected={selectedUnitKey === unit.unitKey}
                  isExpanded={expandedUnitKey === unit.unitKey}
                  onSelect={() => onUnitSelect(unit.unitKey, unit.name, group.category)}
                  onCancelDeployment={() => onUndeploy(unit.unitKey, unit.name)}
                  onCancelSelection={onCancelSelection}
                />
              ))}
            </CollapsibleGroup>
          ))
        )}
      </div>
    </div>
  );
}
