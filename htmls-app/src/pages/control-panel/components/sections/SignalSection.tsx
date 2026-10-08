import type { SignalData } from '@/types/unitStatus';
import { InfoCard } from '@pages/control-panel/components/shared/InfoCard';
import { ImageIcon } from '@/components/ImageIcon';
import { ICON_IMAGES } from '@/components/map';
import { formatTimestamp } from '@/utils/format';

// ============================================================================
// SignalSection — one suspected C2 card per detected signal
// ============================================================================
interface SignalSectionProps {
  signals: SignalData[];
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
          details={
            <>
              <div>
                {signal.type ? signal.type.toUpperCase() : 'N/A'} |{' '}
                {signal.autodetectable ? 'AUTODETECTABLE' : 'NOT AUTODETECTABLE'}
              </div>
              <div>
                CONFIDENCE {Math.floor((signal.confidence || 0) * 100)}% | LEVEL{' '}
                {signal.currentDetectionLevel || 0} | SEEN {signal.detectionCount || 0}x
              </div>
              <div>LAST {formatTimestamp(signal.lastDetected)}</div>
              {signal.latitude === undefined || signal.longitude === undefined ? (
                <div className="italic">No position</div>
              ) : (
                <div className="font-mono">
                  {signal.latitude.toFixed(4)}°, {signal.longitude.toFixed(4)}°
                </div>
              )}
            </>
          }
        />
      ))}
    </div>
  );
}
