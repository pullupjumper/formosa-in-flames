import { Marker, Circle, Popup } from 'react-leaflet';
import L from 'leaflet';
import type { Jammer } from '@/types/setupMenu';

// EW unit icon
const ewIcon = L.icon({
  iconUrl: 'https://i.meee.com.tw/XENYCji.png',
  iconSize: [40, 30],
  iconAnchor: [20, 15],
  popupAnchor: [0, -15],
});

interface JammerMarkerProps {
  jammer: Jammer;
  // index: number;
  position: { lat: number; lng: number };
  // onRemove?: () => void;
}

export function JammerMarker({ jammer, position }: JammerMarkerProps) {
  const radiusMeters = jammer.radius * 1852; // Convert NM to meters

  return (
    <>
      <Circle
        center={[position.lat, position.lng]}
        radius={radiusMeters}
        pathOptions={{
          color: '#ff6b6b',
          fillColor: '#ff6b6b',
          fillOpacity: 0.1,
          weight: 2,
        }}
      />
      <Marker position={[position.lat, position.lng]} icon={ewIcon}>
        <Popup>
          <div className="text-text-primary">
            <strong>{jammer.name}</strong>
            <br />
            {jammer.zoneName}
            <br />
            <br />
            Lat: {position.lat.toFixed(6)}°
            <br />
            Lng: {position.lng.toFixed(6)}°
            <br />
            Range: {jammer.radius} NM
          </div>
        </Popup>
      </Marker>
    </>
  );
}

interface DeployedJammersProps {
  jammers: Jammer[];
  deployedPositions: Map<number, { lat: number; lng: number }>;
}

export function DeployedJammers({ jammers, deployedPositions }: DeployedJammersProps) {
  return (
    <>
      {Array.from(deployedPositions.entries()).map(([index, position]) => {
        const jammer = jammers[index];
        if (!jammer) return null;

        return <JammerMarker key={index} jammer={jammer} position={position} />;
      })}
    </>
  );
}
