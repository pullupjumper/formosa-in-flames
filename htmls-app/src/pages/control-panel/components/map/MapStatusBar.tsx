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
    <div className="pointer-events-none absolute bottom-3 left-3 z-1100 max-w-[45%] border border-aip-border bg-aip-panel/95 p-2.5 text-xs">
      <div>{status}</div>
      {coordinates && (
        <div className="mt-1.5 font-mono text-[11px] text-text-secondary">
          {coordinates.latitude.toFixed(6)}°, {coordinates.longitude.toFixed(6)}°
        </div>
      )}
    </div>
  );
}
