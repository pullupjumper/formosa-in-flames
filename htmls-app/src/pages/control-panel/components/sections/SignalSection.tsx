import type { Signal } from '@/types/controlPanel';
import { DetailsBox, TextRow } from '@pages/control-panel/components/shared/DetailsBox';
import { InfoCard } from '@pages/control-panel/components/shared/InfoCard';
import { ImageIcon } from '@/components/ImageIcon';
import { ICON_IMAGES } from '@/components/map';
import { formatTimestamp } from '@/pages/control-panel/logic/format';

// ============================================================================
// SignalSection — one suspected C2 card per detected signal
// ============================================================================
interface SignalSectionProps {
  signals: Signal[];
}

export function SignalSection({ signals }: SignalSectionProps) {
  if (signals.length === 0) {
    return <div className="text-xs italic text-text-secondary">No signal data available</div>;
  }

  return (
    <div className="space-y-2">
      {signals.map((signal, index) => (
        <InfoCard
          key={`${signal.name}-${index}`}
          name={signal.name || 'N/A'}
          icon={<ImageIcon image={ICON_IMAGES.suspectedC2} />}
          details={<div>{signal.type ? signal.type.toUpperCase() : 'N/A'}</div>}
          foldedDetails={
            <DetailsBox title="Details">
              <TextRow
                label="Detectability"
                value={signal.autodetectable ? 'AUTODETECTABLE' : 'NOT AUTODETECTABLE'}
              />
              <TextRow
                label="Confidence"
                value={`${Math.floor((signal.confidence || 0) * 100)}%`}
              />
              <TextRow label="Level" value={signal.currentDetectionLevel || 0} />
              <TextRow label="Seen" value={`${signal.detectionCount || 0}x`} />
              <TextRow label="Last Detected" value={formatTimestamp(signal.lastDetected)} />
              <TextRow
                label="Position"
                value={
                  signal.latitude === undefined || signal.longitude === undefined
                    ? 'No position'
                    : `${signal.latitude.toFixed(4)}°, ${signal.longitude.toFixed(4)}°`
                }
              />
            </DetailsBox>
          }
        />
      ))}
    </div>
  );
}
