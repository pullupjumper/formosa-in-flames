import { memo, useMemo, useCallback } from 'react';
import { Marker, Circle, Tooltip } from 'react-leaflet';
import L from 'leaflet';
import type { Coordinate } from '@/types/geo';
import type { Jammer } from '@/types/setupMenu';
import { nauticalMilesToMeters, toLeafletLatLng } from '@/utils/geo';

// EW unit icon
const EW_ICON = L.icon({
  iconUrl: 'https://i.meee.com.tw/LO1UNjw.png',
  iconSize: [25, 15],
  iconAnchor: [25 / 2, 15 / 2],
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

const PATH_OPTIONS_RANGE_PREVIEW = {
  color: '#ff6b6b',
  fillColor: '#ff6b6b',
  fillOpacity: 0.05,
  weight: 2,
  dashArray: '6, 4',
};

interface JammerMarkerProps {
  jammer: Jammer;
  index: number;
  position: Coordinate;
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
  const radiusMeters = nauticalMilesToMeters(jammer.radius);
  const center = toLeafletLatLng(position);

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
        icon={EW_ICON}
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
  position: Coordinate;
}

export function JammerRelocatePreview({ radius, position }: JammerRelocatePreviewProps) {
  const radiusMeters = nauticalMilesToMeters(radius);
  const center = toLeafletLatLng(position);

  return (
    <>
      <Circle
        center={center}
        radius={radiusMeters}
        interactive={false}
        pathOptions={PATH_OPTIONS_RANGE_PREVIEW}
      />
      <Marker position={center} icon={EW_ICON} interactive={false} opacity={0.6} />
    </>
  );
}

// ============================================================================
// DeployedJammers Component
// ============================================================================
interface DeployedJammersProps {
  jammers: Jammer[];
  deployedPositions: Map<number, Coordinate>;
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
