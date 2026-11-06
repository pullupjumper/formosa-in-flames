import type { Airbase } from '@/types/generated';
import { memo, useMemo } from 'react';
import { Marker } from 'react-leaflet';
import L from 'leaflet';
import { toLeafletLatLng } from '@/utils/geo';
import { AIRBASE_ICON_URL, AIRBASE_ICON_SIZE } from './icons';
import { MapPopup, PopupSection } from './MapPopup';

// Airbase icon
const AIRBASE_ICON = L.icon({
  iconUrl: AIRBASE_ICON_URL,
  iconSize: [AIRBASE_ICON_SIZE.width, AIRBASE_ICON_SIZE.height],
  iconAnchor: [AIRBASE_ICON_SIZE.width / 2, AIRBASE_ICON_SIZE.height / 2],
  popupAnchor: [0, -10],
});

interface AirbaseMarkerProps {
  airbase: Airbase;
  index: number;
  onClick?: (index: number) => void;
}

export const AirbaseMarker = memo(function AirbaseMarker({
  airbase,
  index,
  onClick,
}: AirbaseMarkerProps) {
  const eventHandlers = useMemo(
    () => (onClick ? { click: () => onClick(index) } : undefined),
    [onClick, index]
  );

  return (
    <Marker position={toLeafletLatLng(airbase)} icon={AIRBASE_ICON} eventHandlers={eventHandlers}>
      <MapPopup
        name={airbase.name}
        subtitle="Airbase"
        // rows={[
        //   { label: 'Latitude', value: `${airbase.latitude.toFixed(6)}°` },
        //   { label: 'Longitude', value: `${airbase.longitude.toFixed(6)}°` },
        // ]}
      >
        {airbase.embarkedUnits && airbase.embarkedUnits.length > 0 && (
          <PopupSection
            title="Deployed Aircraft"
            rows={airbase.embarkedUnits.map((unit) => ({
              label: unit.platformName,
              value: `x ${unit.loadouts?.reduce((sum, loadout) => sum + loadout.num, 0) || 0}`,
            }))}
          />
        )}
        {airbase.loadouts && airbase.loadouts.length > 0 && (
          <PopupSection
            title="Ammunition Storage"
            rows={airbase.loadouts.map((loadout) => ({
              label: loadout.name ?? `Loadout ${loadout.loadoutId}`,
              value: `x ${loadout.num}`,
            }))}
          />
        )}
      </MapPopup>
    </Marker>
  );
});

interface AirbaseMarkersProps {
  airbases: Airbase[];
  /** Must be referentially stable, otherwise every marker rebinds its listener */
  onAirbaseClick?: (index: number) => void;
}

export function AirbaseMarkers({ airbases, onAirbaseClick }: AirbaseMarkersProps) {
  return (
    <>
      {airbases.map((airbase, index) => (
        <AirbaseMarker
          key={airbase.baseGUID || index}
          airbase={airbase}
          index={index}
          onClick={onAirbaseClick}
        />
      ))}
    </>
  );
}
