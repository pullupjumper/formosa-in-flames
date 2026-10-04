import { memo } from 'react';
import { Marker, Tooltip } from 'react-leaflet';
import type { SignalData } from '@/types/unitStatus';
import { toLeafletLatLng } from '@/utils/geo';
import { createImageIcon, ICON_IMAGES } from './icons';

// ============================================================================
// SignalMarker — suspected C2 position of a detected signal
// ============================================================================
const SUSPECTED_C2_ICON = createImageIcon(ICON_IMAGES.suspectedC2);

interface SignalMarkersProps {
  signals: SignalData[];
}

/** One marker per signal that carries a position; the rest only appear in the sidebar. */
export const SignalMarkers = memo(function SignalMarkers({ signals }: SignalMarkersProps) {
  return (
    <>
      {signals.map((signal, index) =>
        signal.latitude === undefined || signal.longitude === undefined ? null : (
          <Marker
            key={`${signal.name}-${index}`}
            position={toLeafletLatLng({ latitude: signal.latitude, longitude: signal.longitude })}
            icon={SUSPECTED_C2_ICON}
          >
            <Tooltip direction="top">
              <strong>{signal.name}</strong>
            </Tooltip>
          </Marker>
        )
      )}
    </>
  );
});
