import { useMemo, useState, type ReactNode } from 'react';
import {
  Circle,
  LayersControl,
  MapContainer,
  Polygon,
  TileLayer,
  Tooltip,
  useMap,
  useMapEvents,
} from 'react-leaflet';
import L from 'leaflet';
import type { Coordinate } from '@/types/geo';
import type { AreaType } from '@/types/deployment';
import { getAreaColor } from '@/constants/deployment';
import {
  calculateCentroid,
  nauticalMilesToMeters,
  toLeafletLatLng,
  toLeafletPositions,
} from '@/utils/geo';
import 'leaflet/dist/leaflet.css';
import './leaflet-dark.css';

/**
 * The only place that turns domain shapes into Leaflet layers. Everything
 * above this file passes `Coordinate`s and area types; Leaflet tuples, icons
 * and pathOptions stay in here.
 */

// ============================================================================
// MapShell — tile stack shared by every map on the site
// ============================================================================
interface MapShellProps {
  center: Coordinate;
  zoom: number;
  scrollWheelZoom?: boolean;
  className?: string;
  children?: ReactNode;
}

export function MapShell({
  center,
  zoom,
  scrollWheelZoom = true,
  className = '',
  children,
}: MapShellProps) {
  return (
    <MapContainer
      center={toLeafletLatLng(center)}
      zoom={zoom}
      scrollWheelZoom={scrollWheelZoom}
      // Canvas renderer: every vector path draws into one <canvas> instead of
      // one SVG node each. With 20+ deployed systems (~18 paths apiece, mostly
      // dashed) the SVG renderer makes zoom/pan visibly stutter in CMO's
      // embedded browser.
      preferCanvas
      className={`h-full w-full ${className}`}
      style={{ background: '#10161a' }}
    >
      <LayersControl position="topright">
        <LayersControl.BaseLayer name="Dark">
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
        <LayersControl.BaseLayer checked name="Satellite">
          <TileLayer
            attribution='&copy; <a href="https://www.esri.com/">Esri</a>, Maxar, Earthstar Geographics'
            url="https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}"
            maxZoom={18}
          />
        </LayersControl.BaseLayer>
      </LayersControl>
      {children}
    </MapContainer>
  );
}

// ============================================================================
// ZoomGate — mount children only once the map is zoomed in far enough
// ============================================================================
/**
 * Zoom level below which per-unit detail (movement paths, shelter points,
 * weapon range) is hidden. Tactical squares are ~370 m across, so anything
 * finer than the area outlines is sub-pixel noise before this level.
 */
export const DETAIL_MIN_ZOOM = 11;

interface ZoomGateProps {
  minZoom: number;
  children: ReactNode;
}

export function ZoomGate({ minZoom, children }: ZoomGateProps) {
  const map = useMap();
  const [zoom, setZoom] = useState(() => map.getZoom());
  useMapEvents({
    zoomend: () => setZoom(map.getZoom()),
  });
  return zoom >= minZoom ? <>{children}</> : null;
}

// ============================================================================
// TacticalPolygon — one tactical area, in any of its three looks
// ============================================================================
export type TacticalPolygonVariant = 'deployed' | 'preview' | 'relocate-preview';

interface TacticalPolygonProps {
  vertices: Coordinate[] | undefined;
  type: AreaType;
  variant?: TacticalPolygonVariant;
  /** Deployed: this area is armed for relocation, drawn dashed and lighter */
  isRelocating?: boolean;
  /** Preview: false draws the shape red */
  isValid?: boolean;
  tooltip?: ReactNode;
  /** Presence makes the polygon interactive; the click never reaches the map */
  onClick?: () => void;
}

const INVALID_COLOR = '#ff4444';
const DASHED = '6, 4';

function resolvePathOptions(
  type: AreaType,
  variant: TacticalPolygonVariant,
  isRelocating: boolean,
  isValid: boolean
): L.PathOptions {
  const isUshape = type === 'ushape';
  const areaColor = getAreaColor(type);

  switch (variant) {
    case 'deployed': {
      const fillOpacity = isUshape ? (isRelocating ? 0.08 : 0.15) : isRelocating ? 0.1 : 0.3;
      return {
        color: areaColor,
        fillColor: areaColor,
        fillOpacity,
        weight: 2,
        dashArray: isRelocating ? DASHED : undefined,
      };
    }
    case 'preview': {
      const color = isValid ? areaColor : INVALID_COLOR;
      const fillOpacity = isUshape ? (isValid ? 0.1 : 0.08) : isValid ? 0.15 : 0.1;
      return {
        color,
        fillColor: color,
        fillOpacity,
        weight: isUshape ? 2 : 1.5,
        dashArray: DASHED,
      };
    }
    case 'relocate-preview':
      return {
        color: areaColor,
        fillColor: areaColor,
        fillOpacity: 0.15,
        weight: 2,
        dashArray: DASHED,
      };
  }
}

/**
 * Anchor a polygon's tooltip at its top edge (max latitude) rather than its
 * geometric center, so the label does not cover the shape.
 */
function createTopEdgeAnchorRef(vertices: Coordinate[]) {
  if (vertices.length < 3) return undefined;
  const center = calculateCentroid(vertices);
  const maxLatitude = Math.max(...vertices.map((vertex) => vertex.latitude));
  const anchor = L.latLng(maxLatitude, center.longitude);
  return (node: L.Polygon | null) => {
    if (node) node.getCenter = () => anchor;
  };
}

export function TacticalPolygon({
  vertices,
  type,
  variant = 'deployed',
  isRelocating = false,
  isValid = true,
  tooltip,
  onClick,
}: TacticalPolygonProps) {
  const positions = useMemo(() => toLeafletPositions(vertices ?? []), [vertices]);
  const anchorRef = useMemo(
    () => (tooltip && vertices ? createTopEdgeAnchorRef(vertices) : undefined),
    [tooltip, vertices]
  );
  const pathOptions = useMemo(
    () => resolvePathOptions(type, variant, isRelocating, isValid),
    [type, variant, isRelocating, isValid]
  );
  const eventHandlers = useMemo(
    () =>
      onClick
        ? {
            click: (event: L.LeafletMouseEvent) => {
              event.originalEvent.stopImmediatePropagation?.();
              event.originalEvent.stopPropagation();
              onClick();
            },
          }
        : undefined,
    [onClick]
  );

  if (positions.length === 0) return null;

  return (
    <Polygon
      ref={anchorRef}
      positions={positions}
      interactive={Boolean(onClick)}
      pathOptions={pathOptions}
      eventHandlers={eventHandlers}
    >
      {tooltip && <Tooltip direction="top">{tooltip}</Tooltip>}
    </Polygon>
  );
}

// ============================================================================
// RangeCircle — weapon / jammer reach, never interactive
// ============================================================================
export type RangeCircleVariant = 'range' | 'relocating' | 'preview';

interface RangeCircleProps {
  center: Coordinate;
  radiusNm: number;
  color: string;
  variant?: RangeCircleVariant;
}

const RANGE_STYLE: Record<RangeCircleVariant, Omit<L.PathOptions, 'color' | 'fillColor'>> = {
  range: { fillOpacity: 0.1, weight: 1.5, opacity: 0.25 },
  relocating: { fillOpacity: 0.1, weight: 1.5, opacity: 0.15, dashArray: DASHED },
  preview: { fillOpacity: 0.1, weight: 2, dashArray: DASHED },
};

export function RangeCircle({ center, radiusNm, color, variant = 'range' }: RangeCircleProps) {
  const pathOptions = useMemo(
    () => ({ color, fillColor: color, ...RANGE_STYLE[variant] }),
    [color, variant]
  );
  return (
    <Circle
      center={toLeafletLatLng(center)}
      radius={nauticalMilesToMeters(radiusNm)}
      interactive={false}
      pathOptions={pathOptions}
    />
  );
}
