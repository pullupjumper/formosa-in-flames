import { memo } from 'react';
import { Marker, Tooltip } from 'react-leaflet';
import { toLeafletLatLng } from '@/utils/geo';
import type { C2MapLayers, C2MarkerLayer } from '@pages/control-panel/logic/c2Nodes';
import { createImageIcon, ICON_IMAGES } from './icons';
import { LinkLine, ZonePolygon } from './primitives';

// ============================================================================
// C2Layers — node operating zones, links and C2 / SAM / radar markers
// ============================================================================
const KIND_ICONS = {
  c2: createImageIcon(ICON_IMAGES.c2),
  sam: createImageIcon(ICON_IMAGES.sam),
  radar: createImageIcon(ICON_IMAGES.radar),
};

interface C2LayersProps {
  layers: C2MapLayers;
}

function C2UnitMarker({ marker }: { marker: C2MarkerLayer }) {
  return (
    <Marker
      position={toLeafletLatLng(marker.pos)}
      icon={KIND_ICONS[marker.kind]}
      opacity={marker.isDestroyed ? 0.4 : 1}
    >
      <Tooltip direction="top">
        <strong>{marker.name}</strong>
        <br />
        {ICON_IMAGES[marker.kind].label}
        {marker.isDestroyed ? ' (destroyed)' : ''}
      </Tooltip>
    </Marker>
  );
}

export const C2Layers = memo(function C2Layers({ layers }: C2LayersProps) {
  return (
    <>
      {layers.zones.map((zone) => (
        <ZonePolygon key={zone.key} vertices={zone.vertices} />
      ))}
      {layers.links.map((link) => (
        <LinkLine key={link.key} from={link.from} to={link.to} />
      ))}
      {layers.markers.map((marker) => (
        <C2UnitMarker key={`${marker.kind}-${marker.key}`} marker={marker} />
      ))}
    </>
  );
});
