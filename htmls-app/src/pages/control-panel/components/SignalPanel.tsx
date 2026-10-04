import type { SignalData } from '@/types/unitStatus';
import { ImageIcon } from '@/components/ImageIcon';
import { ICON_IMAGES } from '@/components/Map';
import { formatTimestamp } from '@/utils/format';

// ============================================================================
// SignalPanel — one suspected C2 card per detected signal
// ============================================================================
interface SignalPanelProps {
  signals: SignalData[];
}

export function SignalPanel({ signals }: SignalPanelProps) {
  if (signals.length === 0) {
    return <div className="text-xs italic text-text-secondary">No signal data available</div>;
  }

  return (
    <div className="space-y-2">
      {signals.map((signal, index) => (
        <div
          key={`${signal.name}-${index}`}
          className="border border-aip-card-border bg-aip-card p-2.5 text-xs"
        >
          <div className="flex items-start gap-2.5">
            <ImageIcon image={ICON_IMAGES.suspectedC2} />
            <div className="min-w-0 flex-1">
              <div className="mb-1 font-semibold">{signal.name || 'N/A'}</div>
              <div className="text-text-secondary">
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
              </div>
            </div>
          </div>
        </div>
      ))}
    </div>
  );
}
