import type { Coordinate } from '@/types/geo';

// ============================================================================
// MapStatusBar — deployment hint and cursor coordinates over the map
// ============================================================================
interface MapStatusBarProps {
  status: string;
  coordinates: Coordinate | null;
}

/**
 * Bottom-left of the map, clear of the zoom control and coordinate search at the
 * top. Click-through so it never swallows a placement click.
 */
export function MapStatusBar({ status, coordinates }: MapStatusBarProps) {
  return (
    <div className="pointer-events-none absolute bottom-3 left-3 z-1100 max-w-[45%] rounded-xs bg-[rgba(240,242,244,0.82)] p-2.5 text-xs text-[#394b59] shadow-[0_1px_3px_rgba(0,0,0,0.45)]">
      <div>{status}</div>
      {coordinates && (
        <div className="mt-1.5 font-mono text-[11px] text-[#5c7080]">
          {coordinates.latitude.toFixed(6)}°, {coordinates.longitude.toFixed(6)}°
        </div>
      )}
    </div>
  );
}
