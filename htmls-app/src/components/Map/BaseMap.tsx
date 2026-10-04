import { useEffect, useState, useCallback } from 'react';
import { CircleMarker, useMap, useMapEvents } from 'react-leaflet';
import type { Coordinate } from '@/types/geo';
import { fromLeafletLatLng, toLeafletLatLng } from '@/utils/geo';
import { MapShell } from './primitives';

// Taiwan center coordinates
const TAIWAN_CENTER: Coordinate = { latitude: 23.8, longitude: 121.0 };
// Fujian coast — China side deployment area, across the strait from Taiwan
const FUJIAN_COAST_CENTER: Coordinate = { latitude: 25.3, longitude: 119.2 };
const DEFAULT_ZOOM = 8;

interface BaseMapProps {
  children?: React.ReactNode;
  onMapClick?: (position: Coordinate) => void;
  onMouseMove?: (position: Coordinate) => void;
  cursorStyle?: string;
  className?: string;
  sideName?: string;
}

export function BaseMap({
  children,
  onMapClick,
  onMouseMove,
  cursorStyle,
  className = '',
  sideName,
}: BaseMapProps) {
  // China side plans its deployment from the Fujian coast; everyone else starts on Taiwan
  const center = sideName === 'China' ? FUJIAN_COAST_CENTER : TAIWAN_CENTER;
  return (
    <MapShell center={center} zoom={sideName === 'China' ? 5 : DEFAULT_ZOOM} className={className}>
      {onMapClick && <MapClickHandler onClick={onMapClick} />}
      {onMouseMove && <MapMouseMoveHandler onMouseMove={onMouseMove} />}
      {cursorStyle && <MapCursorStyle cursor={cursorStyle} />}
      <MapResizeHandler />
      <CoordinateSearch />
      {children}
    </MapShell>
  );
}

interface MapClickHandlerProps {
  onClick: (position: Coordinate) => void;
}

function MapClickHandler({ onClick }: MapClickHandlerProps) {
  useMapEvents({
    click: (event) => {
      onClick(fromLeafletLatLng(event.latlng));
    },
  });
  return null;
}

interface MapMouseMoveHandlerProps {
  onMouseMove: (position: Coordinate) => void;
}

function MapMouseMoveHandler({ onMouseMove }: MapMouseMoveHandlerProps) {
  useMapEvents({
    mousemove: (event) => {
      onMouseMove(fromLeafletLatLng(event.latlng));
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

  // Leaflet does not notice container resizes (window or a dragged splitter) on its own
  useEffect(() => {
    const container = map.getContainer();
    const observer = new ResizeObserver(() => map.invalidateSize());
    observer.observe(container);
    const timeout = setTimeout(() => map.invalidateSize(), 100);

    return () => {
      observer.disconnect();
      clearTimeout(timeout);
    };
  }, [map]);

  return null;
}

// ============================================================================
// CoordinateSearch — input box on the map to jump to a "latitude, longitude"
// ============================================================================
const PIN_PATH_OPTIONS = {
  color: '#fff',
  fillColor: '#137cbd',
  fillOpacity: 1,
  weight: 2,
};

function CoordinateSearch() {
  const map = useMap();
  const [value, setValue] = useState('');
  const [pin, setPin] = useState<Coordinate | null>(null);

  const handleSubmit = useCallback(
    (event: React.FormEvent) => {
      event.preventDefault();
      const trimmed = value.trim();
      if (!trimmed) return;

      // Accept "latitude, longitude" or "latitude longitude"
      const parts = trimmed.split(/[,\s]+/).filter(Boolean);
      if (parts.length < 2) return;

      const latitude = parseFloat(parts[0]);
      const longitude = parseFloat(parts[1]);
      if (isNaN(latitude) || isNaN(longitude)) return;

      const target: Coordinate = { latitude, longitude };
      map.setView(toLeafletLatLng(target), map.getZoom(), { animate: true });
      setPin(target);
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
            onChange={(event) => setValue(event.target.value)}
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
          center={toLeafletLatLng(pin)}
          radius={7}
          pathOptions={PIN_PATH_OPTIONS}
          eventHandlers={{
            click: (event) => {
              event.originalEvent.stopPropagation();
              clearPin();
            },
          }}
        />
      )}
    </>
  );
}

export { TAIWAN_CENTER, FUJIAN_COAST_CENTER, DEFAULT_ZOOM };
