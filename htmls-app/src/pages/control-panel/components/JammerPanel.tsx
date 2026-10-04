import type { Coordinate } from '@/types/geo';
import type { Jammer } from '@/types/setupMenu';
import { EW_ICON_URL, EW_ICON_SIZE } from '@/components/Map';
import { DeployableUnitCard } from '@pages/control-panel/components/DeployableUnitCard';

// ============================================================================
// JammerPanel — GPS jammer cards for the control panel
// ============================================================================
interface JammerPanelProps {
  jammers: Jammer[];
  deployedJammers: Map<number, Coordinate>;
  expandedJammerIndex: number | null;
  /** Jammer index armed for a fresh deployment, null while relocating or idle */
  selectedJammerIndex: number | null;
  onJammerSelect: (index: number) => void;
  onUndeployJammer: (index: number) => void;
  onCancelSelection: () => void;
}

export function JammerPanel({
  jammers,
  deployedJammers,
  expandedJammerIndex,
  selectedJammerIndex,
  onJammerSelect,
  onUndeployJammer,
  onCancelSelection,
}: JammerPanelProps) {
  if (jammers.length === 0) {
    return <div className="text-xs italic text-text-secondary">No jammer units available</div>;
  }

  return (
    <div className="space-y-2">
      {jammers.map((jammer, index) => {
        const deployment = deployedJammers.get(index);
        return (
          <DeployableUnitCard
            icon={
              <img
                src={EW_ICON_URL}
                alt="EW"
                width={EW_ICON_SIZE.width * 1.4}
                height={EW_ICON_SIZE.height * 1.4}
                className="shrink-0 object-contain"
              />
            }
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
      })}
    </div>
  );
}
