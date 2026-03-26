import { useEffect, useState, useCallback } from 'react';
import {
  CircleMarker,
  LayersControl,
  MapContainer,
  TileLayer,
  useMap,
  useMapEvents,
} from 'react-leaflet';
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
      <CoordinateSearch />
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

// ============================================================================
// CoordinateSearch — input box on the map to jump to a lat,lng
// ============================================================================
function CoordinateSearch() {
  const map = useMap();
  const [value, setValue] = useState('');
  const [pin, setPin] = useState<{ lat: number; lng: number } | null>(null);

  const handleSubmit = useCallback(
    (e: React.FormEvent) => {
      e.preventDefault();
      const trimmed = value.trim();
      if (!trimmed) return;

      // Accept "lat, lng" or "lat lng"
      const parts = trimmed.split(/[,\s]+/).filter(Boolean);
      if (parts.length < 2) return;

      const lat = parseFloat(parts[0]);
      const lng = parseFloat(parts[1]);
      if (isNaN(lat) || isNaN(lng)) return;

      map.setView([lat, lng], map.getZoom(), { animate: true });
      setPin({ lat, lng });
      setValue('');
    },
    [value, map]
  );

  const clearPin = useCallback(() => {
    setPin(null);
  }, []);

  return (
    <>
      {/* Search input overlay */}
      <div
        style={{
          position: 'absolute',
          top: 10,
          left: 60,
          zIndex: 1000,
        }}
      >
        <form onSubmit={handleSubmit} style={{ display: 'flex', gap: 4 }}>
          <input
            type="text"
            value={value}
            onChange={(e) => setValue(e.target.value)}
            placeholder="lat, lng"
            style={{
              width: 200,
              padding: '4px 8px',
              fontSize: 12,
              background: '#202b33',
              border: '1px solid #30404d',
              borderRadius: 4,
              color: '#e1e8ed',
              outline: 'none',
            }}
          />
          <button
            type="submit"
            style={{
              padding: '4px 8px',
              fontSize: 12,
              background: '#137cbd',
              border: '1px solid #137cbd',
              borderRadius: 4,
              color: '#e1e8ed',
              cursor: 'pointer',
            }}
          >
            Go
          </button>
        </form>
      </div>

      {/* Pin marker */}
      {pin && (
        <CircleMarker
          center={[pin.lat, pin.lng]}
          radius={7}
          pathOptions={{
            color: '#fff',
            fillColor: '#137cbd',
            fillOpacity: 1,
            weight: 2,
          }}
          eventHandlers={{
            click: (e) => {
              e.originalEvent.stopPropagation();
              clearPin();
            },
          }}
        />
      )}
    </>
  );
}

export { TAIWAN_CENTER, DEFAULT_ZOOM };
