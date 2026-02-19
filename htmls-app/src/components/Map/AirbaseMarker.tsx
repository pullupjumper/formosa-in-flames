import { Marker, Popup } from 'react-leaflet';
import L from 'leaflet';
import type { Airbase } from '@/types/setupMenu';

// Airbase icon
const airbaseIcon = L.icon({
  iconUrl: 'https://i.meee.com.tw/5afNBSQ.png',
  iconSize: [20, 20],
  iconAnchor: [10, 10],
  popupAnchor: [0, -10],
});

interface AirbaseMarkerProps {
  airbase: Airbase;
  onClick?: () => void;
}

export function AirbaseMarker({ airbase, onClick }: AirbaseMarkerProps) {
  return (
    <Marker
      position={[airbase.latitude, airbase.longitude]}
      icon={airbaseIcon}
      eventHandlers={{
        click: onClick,
      }}
    >
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
              {airbase.embarkedUnits.map((unit, i) => {
                const count = unit.loadouts?.reduce((s, lo) => s + lo.num, 0) || 0;
                return (
                  <div key={i}>
                    {unit.platformName} x {count}
                  </div>
                );
              })}
            </div>
          )}

          {airbase.loadouts && airbase.loadouts.length > 0 && (
            <div className="mt-3">
              <div className="font-semibold">Ammunition Storage</div>
              {airbase.loadouts.map((lo, i) => (
                <div key={i}>
                  {lo.name} x {lo.num}
                </div>
              ))}
            </div>
          )}
        </div>
      </Popup>
    </Marker>
  );
}

interface AirbaseMarkersProps {
  airbases: Airbase[];
  onAirbaseClick?: (index: number) => void;
}

export function AirbaseMarkers({ airbases, onAirbaseClick }: AirbaseMarkersProps) {
  return (
    <>
      {airbases.map((airbase, index) => (
        <AirbaseMarker
          key={airbase.baseGUID || index}
          airbase={airbase}
          onClick={() => onAirbaseClick?.(index)}
        />
      ))}
    </>
  );
}
