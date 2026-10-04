import { memo, useMemo } from 'react';
import { Marker, Popup } from 'react-leaflet';
import L from 'leaflet';
import type { Airbase } from '@/types/setupMenu';
import { toLeafletLatLng } from '@/utils/geo';
import { AIRBASE_ICON_URL, AIRBASE_ICON_SIZE } from './icons';

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
      <Popup>
        <div className="text-text-primary">
          <strong className="text-status-success">{airbase.name}</strong>
          <br />
          <br />
          <strong>Coordinates:</strong>
          <br />
          <span className="text-status-success">Lat: {airbase.latitude.toFixed(6)}°</span>
          <br />
          <span className="text-status-success">Lng: {airbase.longitude.toFixed(6)}°</span>

          {airbase.embarkedUnits && airbase.embarkedUnits.length > 0 && (
            <div className="mt-3">
              <div className="font-semibold">Deployed Aircraft</div>
              {airbase.embarkedUnits.map((unit, unitIndex) => {
                const count = unit.loadouts?.reduce((sum, loadout) => sum + loadout.num, 0) || 0;
                return (
                  <div key={unitIndex}>
                    {unit.platformName} x {count}
                  </div>
                );
              })}
            </div>
          )}

          {airbase.loadouts && airbase.loadouts.length > 0 && (
            <div className="mt-3">
              <div className="font-semibold">Ammunition Storage</div>
              {airbase.loadouts.map((loadout, loadoutIndex) => (
                <div key={loadoutIndex}>
                  {loadout.name} x {loadout.num}
                </div>
              ))}
            </div>
          )}
        </div>
      </Popup>
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
