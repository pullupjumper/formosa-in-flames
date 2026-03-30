import { memo, useMemo, useCallback } from 'react';
import { Marker, Circle, Tooltip } from 'react-leaflet';
import L from 'leaflet';
import type { Jammer } from '@/types/setupMenu';

// EW unit icon
const ewIcon = L.icon({
  iconUrl: 'https://i.meee.com.tw/XENYCji.png',
  iconSize: [40, 30],
  iconAnchor: [20, 15],
  popupAnchor: [0, -15],
});

const PATH_OPTIONS_RANGE = {
  color: '#ff6b6b',
  fillColor: '#ff6b6b',
  fillOpacity: 0.01,
  weight: 1.5,
  opacity: 0.25,
  dashArray: '5, 10',
};

const PATH_OPTIONS_RANGE_RELOCATING = {
  color: '#ff6b6b',
  fillColor: '#ff6b6b',
  fillOpacity: 0.01,
  weight: 1.5,
  opacity: 0.15,
  dashArray: '6, 4',
};

interface JammerMarkerProps {
  jammer: Jammer;
  index: number;
  position: { lat: number; lng: number };
  isRelocating?: boolean;
  onRelocateClick?: (index: number) => void;
}

export const JammerMarker = memo(function JammerMarker({
  jammer,
  index,
  position,
  isRelocating = false,
  onRelocateClick,
}: JammerMarkerProps) {
  const radiusMeters = jammer.radius * 1852;
  const center: L.LatLngExpression = [position.lat, position.lng];

  const handleClick = useCallback(() => {
    onRelocateClick?.(index);
  }, [onRelocateClick, index]);

  const eventHandlers = useMemo(
    () => (onRelocateClick ? { click: handleClick } : undefined),
    [onRelocateClick, handleClick]
  );

  return (
    <>
      <Circle
        center={center}
        radius={radiusMeters}
        interactive={false}
        pathOptions={isRelocating ? PATH_OPTIONS_RANGE_RELOCATING : PATH_OPTIONS_RANGE}
      />
      <Marker
        position={center}
        icon={ewIcon}
        eventHandlers={eventHandlers}
        opacity={isRelocating ? 0.5 : 1}
      >
        <Tooltip direction="top">
          <strong>{jammer.name}</strong>
          <br />
          {jammer.zoneName} | {jammer.radius} NM
        </Tooltip>
      </Marker>
    </>
  );
});

// ============================================================================
// JammerRelocatePreview Component
// ============================================================================
interface JammerRelocatePreviewProps {
  radius: number;
  position: { lat: number; lng: number };
}

export function JammerRelocatePreview({ radius, position }: JammerRelocatePreviewProps) {
  const radiusMeters = radius * 1852;
  const center: L.LatLngExpression = [position.lat, position.lng];

  return (
    <>
      <Circle
        center={center}
        radius={radiusMeters}
        interactive={false}
        pathOptions={{
          color: '#ff6b6b',
          fillColor: '#ff6b6b',
          fillOpacity: 0.05,
          weight: 2,
          dashArray: '6, 4',
        }}
      />
      <Marker position={center} icon={ewIcon} interactive={false} opacity={0.6} />
    </>
  );
}

// ============================================================================
// DeployedJammers Component
// ============================================================================
interface DeployedJammersProps {
  jammers: Jammer[];
  deployedPositions: Map<number, { lat: number; lng: number }>;
  relocatingIndex?: number | null;
  onRelocateClick?: (index: number) => void;
}

export function DeployedJammers({
  jammers,
  deployedPositions,
  relocatingIndex = null,
  onRelocateClick,
}: DeployedJammersProps) {
  return (
    <>
      {Array.from(deployedPositions.entries()).map(([index, position]) => {
        const jammer = jammers[index];
        if (!jammer) return null;

        return (
          <JammerMarker
            key={index}
            jammer={jammer}
            index={index}
            position={position}
            isRelocating={relocatingIndex === index}
            onRelocateClick={onRelocateClick}
          />
        );
      })}
    </>
  );
}
