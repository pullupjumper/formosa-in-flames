import type { GNSSJammerDescriptor } from '@/types/generated';
import { memo, useMemo, useCallback } from 'react';
import { Marker, Tooltip } from 'react-leaflet';
import type { Coordinate } from '@/types/geo';
import { toLeafletLatLng } from '@/utils/geo';
import { RangeCircle } from './primitives';
import { createImageIcon, ICON_IMAGES } from './icons';

// EW unit icon
const EW_ICON = createImageIcon(ICON_IMAGES.ew);

const JAMMER_RANGE_COLOR = '#ff6b6b';

interface JammerMarkerProps {
  jammer: GNSSJammerDescriptor;
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
  const handleClick = useCallback(() => {
    onRelocateClick?.(index);
  }, [onRelocateClick, index]);

  const eventHandlers = useMemo(
    () => (onRelocateClick ? { click: handleClick } : undefined),
    [onRelocateClick, handleClick]
  );

  return (
    <>
      <RangeCircle
        center={position}
        radiusNm={jammer.radiusNm}
        color={JAMMER_RANGE_COLOR}
        variant={isRelocating ? 'relocating' : 'range'}
      />
      <Marker
        position={toLeafletLatLng(position)}
        icon={EW_ICON}
        eventHandlers={eventHandlers}
        opacity={isRelocating ? 0.5 : 1}
      >
        <Tooltip direction="top">
          <strong>{jammer.name}</strong>
          <br />
          {jammer.zoneName} | {jammer.radiusNm} NM
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
  return (
    <>
      <RangeCircle
        center={position}
        radiusNm={radius}
        color={JAMMER_RANGE_COLOR}
        variant="preview"
      />
      <Marker
        position={toLeafletLatLng(position)}
        icon={EW_ICON}
        interactive={false}
        opacity={0.6}
      />
    </>
  );
}

// ============================================================================
// DeployedJammers Component
// ============================================================================
interface DeployedJammersProps {
  jammers: GNSSJammerDescriptor[];
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
