import { useEffect } from 'react';
import { LayersControl, MapContainer, TileLayer, useMap, useMapEvents } from 'react-leaflet';
import type { LatLngExpression } from 'leaflet';
import 'leaflet/dist/leaflet.css';
import './leaflet-dark.css';

// Taiwan center coordinates
const TAIWAN_CENTER: LatLngExpression = [23.8, 121.0];
const DEFAULT_ZOOM = 8;

interface BaseMapProps {
  children?: React.ReactNode;
  onMapClick?: (lat: number, lng: number) => void;
  onMouseMove?: (lat: number, lng: number) => void;
  cursorStyle?: string;
  className?: string;
}

export function BaseMap({
  children,
  onMapClick,
  onMouseMove,
  cursorStyle,
  className = '',
}: BaseMapProps) {
  return (
    <MapContainer
      center={TAIWAN_CENTER}
      zoom={DEFAULT_ZOOM}
      className={`h-full w-full ${className}`}
      style={{ background: '#10161a' }}
    >
      <LayersControl position="topright">
        <LayersControl.BaseLayer checked name="Dark">
          <TileLayer
            attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors, &copy; <a href="https://carto.com/attributions">CARTO</a>'
            url="https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png"
            maxZoom={18}
          />
        </LayersControl.BaseLayer>
        <LayersControl.BaseLayer name="Terrain">
          <TileLayer
            attribution='&copy; <a href="https://www.esri.com/">Esri</a>'
            url="https://server.arcgisonline.com/ArcGIS/rest/services/World_Topo_Map/MapServer/tile/{z}/{y}/{x}"
            maxZoom={18}
          />
        </LayersControl.BaseLayer>
      </LayersControl>
      {onMapClick && <MapClickHandler onClick={onMapClick} />}
      {onMouseMove && <MapMouseMoveHandler onMouseMove={onMouseMove} />}
      {cursorStyle && <MapCursorStyle cursor={cursorStyle} />}
      <MapResizeHandler />
      {children}
    </MapContainer>
  );
}

interface MapClickHandlerProps {
  onClick: (lat: number, lng: number) => void;
}

function MapClickHandler({ onClick }: MapClickHandlerProps) {
  useMapEvents({
    click: (e) => {
      onClick(e.latlng.lat, e.latlng.lng);
    },
  });
  return null;
}

function MapMouseMoveHandler({ onMouseMove }: { onMouseMove: (lat: number, lng: number) => void }) {
  useMapEvents({
    mousemove: (e) => {
      onMouseMove(e.latlng.lat, e.latlng.lng);
    },
  });
  return null;
}

function MapCursorStyle({ cursor }: { cursor: string }) {
  const map = useMap();

  useEffect(() => {
    const container = map.getContainer();
    container.style.cursor = cursor;
    return () => {
      container.style.cursor = '';
    };
  }, [map, cursor]);

  return null;
}

// Handle map resize when container size changes
function MapResizeHandler() {
  const map = useMap();

  useEffect(() => {
    const timeout = setTimeout(() => {
      map.invalidateSize();
    }, 100);

    return () => clearTimeout(timeout);
  }, [map]);

  return null;
}

export { TAIWAN_CENTER, DEFAULT_ZOOM };
