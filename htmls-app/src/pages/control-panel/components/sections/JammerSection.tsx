import type { Coordinate } from '@/types/geo';
import type { Jammer } from '@/types/controlPanel';
import { ICON_IMAGES } from '@/components/map';
import { ImageIcon } from '@/components/ImageIcon';
import { DetailsBox, TextRow } from '@pages/control-panel/components/shared/DetailsBox';
import { DeployableUnitCard } from '@pages/control-panel/components/sections/DeployableUnitCard';

// ============================================================================
// JammerSection — GPS jammer cards for the control panel
// ============================================================================
interface JammerSectionProps {
  jammers: Jammer[];
  deployedJammers: Map<number, Coordinate>;
  expandedJammerIndex: number | null;
  /** Jammer index armed for a fresh deployment, null while relocating or idle */
  selectedJammerIndex: number | null;
  onJammerSelect: (index: number) => void;
  onUndeployJammer: (index: number) => void;
  onCancelSelection: () => void;
}

export function JammerSection({
  jammers,
  deployedJammers,
  expandedJammerIndex,
  selectedJammerIndex,
  onJammerSelect,
  onUndeployJammer,
  onCancelSelection,
}: JammerSectionProps) {
  if (jammers.length === 0) {
    return <div className="text-xs italic text-text-secondary">No jammer units available</div>;
  }

  return (
    <div className="space-y-2">
      {jammers.map((jammer, index) => {
        const deployment = deployedJammers.get(index);
        return (
          <DeployableUnitCard
            icon={<ImageIcon image={ICON_IMAGES.ew} />}
            key={index}
            name={jammer.name}
            foldedDetails={
              <DetailsBox title="Details">
                <TextRow label="Zone" value={jammer.zoneName} />
                <TextRow label="Range" value={`${jammer.radiusNm} NM`} />
              </DetailsBox>
            }
            deployedSummary={
              deployment
                ? `Deployed at ${deployment.latitude.toFixed(4)}°, ${deployment.longitude.toFixed(4)}°`
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
