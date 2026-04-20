import { memo, useMemo, useCallback } from 'react';
import { Circle, CircleMarker, Polygon, Polyline, Popup, Tooltip } from 'react-leaflet';
import L from 'leaflet';
import type { LatLngExpression } from 'leaflet';
import type { DeployedMissileSystemData } from '@/types/setupMenu';
import { CONFIG } from '@/types/setupMenu';
import { getWeaponSystemName } from '@/utils/map';

// ============================================================================
// Types
// ============================================================================
export type AreaType = 'ushape' | 'aha' | 'hide' | 'reload' | 'fp';

export interface RelocatingArea {
  unitKey: string;
  type: AreaType;
  fpIndex?: number;
}

// ============================================================================
// COLORS
// ============================================================================
const COLORS = {
  USHAPE: '#ff6b6b',
  AMMO_AREA: '#ffd93d',
  HIDE_AREA: '#6bcb77',
  RELOAD_AREA: '#4d96ff',
  FIRE_POINT: '#ff922b',
  WEAPON_RANGE: '#ff4444',
  SHELTER: '#c084fc',
  PATH_HA: '#6bcb77',
  PATH_AHA: '#ffd93d',
  PATH_FP: '#ff922b',
  PATH_RL: '#4d96ff',
  PATH_SHRL: '#c084fc',
};

const AREA_TYPE_COLOR: Record<AreaType, string> = {
  ushape: COLORS.USHAPE,
  aha: COLORS.AMMO_AREA,
  hide: COLORS.HIDE_AREA,
  reload: COLORS.RELOAD_AREA,
  fp: COLORS.FIRE_POINT,
};

// ============================================================================
// Static pathOptions (never re-created)
// ============================================================================
const PATH_OPTIONS_HA = { color: COLORS.PATH_HA, weight: 2, opacity: 0.7, dashArray: '5, 5' };
const PATH_OPTIONS_AHA = { color: COLORS.PATH_AHA, weight: 2, opacity: 0.7, dashArray: '5, 5' };
const PATH_OPTIONS_FP = { color: COLORS.PATH_FP, weight: 2, opacity: 0.7, dashArray: '5, 5' };
const PATH_OPTIONS_RL = { color: COLORS.PATH_RL, weight: 2, opacity: 0.7, dashArray: '5, 5' };
const PATH_OPTIONS_SHRL = { color: COLORS.PATH_SHRL, weight: 2, opacity: 0.7, dashArray: '2, 6' };
const PATH_OPTIONS_RANGE = {
  color: COLORS.WEAPON_RANGE,
  fillColor: COLORS.WEAPON_RANGE,
  fillOpacity: 0.01,
  weight: 1.5,
  opacity: 0.25,
  dashArray: '5, 10',
};
const PATH_OPTIONS_ROTATE_HANDLE = {
  color: '#fff',
  fillColor: COLORS.USHAPE,
  fillOpacity: 1,
  weight: 2,
};
const PATH_OPTIONS_HIDE_CENTER = {
  color: '#fff',
  fillColor: COLORS.HIDE_AREA,
  fillOpacity: 1,
  weight: 2,
};
const PATH_OPTIONS_SHELTER = {
  color: '#fff',
  fillColor: COLORS.SHELTER,
  fillOpacity: 0.9,
  weight: 1.5,
};
const PATH_OPTIONS_FALLBACK_RANGE = {
  color: '#ff4444',
  fillColor: '#ff4444',
  fillOpacity: 0.01,
  weight: 1.5,
  opacity: 0.25,
  dashArray: '5, 10',
};
const PATH_OPTIONS_FALLBACK_MARKER = {
  color: '#fff',
  fillColor: '#ff6b6b',
  fillOpacity: 1,
  weight: 2,
};

// ============================================================================
// Helper Functions
// ============================================================================
function coordinatesToLatLng(
  coords: { latitude: number; longitude: number }[]
): LatLngExpression[] {
  return coords.map((c) => [c.latitude, c.longitude] as LatLngExpression);
}

function calculateCenter(coords: { latitude: number; longitude: number }[]): {
  lat: number;
  lng: number;
} {
  const sum = coords.reduce(
    (acc, c) => ({ lat: acc.lat + c.latitude, lng: acc.lng + c.longitude }),
    { lat: 0, lng: 0 }
  );
  return { lat: sum.lat / coords.length, lng: sum.lng / coords.length };
}

function calcTooltipAnchor(
  coords: { latitude: number; longitude: number }[] | undefined
): L.LatLng | null {
  if (!coords || coords.length < 3) return null;
  const center = calculateCenter(coords);
  const maxLat = Math.max(...coords.map((v) => v.latitude));
  return L.latLng(center.lat + (maxLat - center.lat), center.lng);
}

function useTooltipAnchor(coords: { latitude: number; longitude: number }[] | undefined) {
  const anchor = useMemo(() => calcTooltipAnchor(coords), [coords]);
  const refCallback = useCallback(
    (node: L.Polygon | null) => {
      if (node && anchor) {
        node.getCenter = () => anchor;
      }
    },
    [anchor]
  );
  return refCallback;
}

// ============================================================================
// MissileSystemMarker Component
// ============================================================================
interface MissileSystemMarkerProps {
  unitKey: string;
  data: DeployedMissileSystemData;
  onAreaClick?: (area: RelocatingArea) => void;
  onRotateClick?: (unitKey: string) => void;
  /** Only the relocatingArea relevant to THIS unit (or null) */
  relocatingArea?: RelocatingArea | null;
  /** Whether ANY unit is currently in relocating mode */
  isAnyRelocating?: boolean;
  isRotating?: boolean;
}

export const MissileSystemMarker = memo(function MissileSystemMarker({
  unitKey,
  data,
  onAreaClick,
  onRotateClick,
  relocatingArea,
  isAnyRelocating = false,
  isRotating,
}: MissileSystemMarkerProps) {
  const { unitName, category, tacticalAreas, paths } = data;
  const rangeNM = CONFIG.WEAPON_RANGES[category] || 100;
  const radiusMeters = rangeNM * 1852;

  const ushapeRefCb = useTooltipAnchor(tacticalAreas.uShapeVertices);
  const ahaRefCb = useTooltipAnchor(tacticalAreas.ammoArea);
  const hideRefCb = useTooltipAnchor(tacticalAreas.hideArea);
  const reloadRefCb = useTooltipAnchor(tacticalAreas.reloadArea);

  const fpAnchors = useMemo(
    () => (tacticalAreas.firePoints ?? []).map((fp) => calcTooltipAnchor(fp)),
    [tacticalAreas.firePoints]
  );
  const fpRefCallbacks = useMemo(
    () =>
      fpAnchors.map((anchor) => (node: L.Polygon | null) => {
        if (node && anchor) {
          node.getCenter = () => anchor;
        }
      }),
    [fpAnchors]
  );

  // Relocating state for this unit
  const isThisUnit = relocatingArea?.unitKey === unitKey;

  const isAreaRelocating = useCallback(
    (type: AreaType, fpIndex?: number) =>
      isThisUnit &&
      relocatingArea?.type === type &&
      (type !== 'fp' || relocatingArea?.fpIndex === fpIndex),
    [isThisUnit, relocatingArea?.type, relocatingArea?.fpIndex]
  );

  const canInteractArea = useCallback(
    (type: AreaType, fpIndex?: number) => {
      if (!onAreaClick) return false;
      if (!isAnyRelocating) return true;
      return isAreaRelocating(type, fpIndex);
    },
    [onAreaClick, isAnyRelocating, isAreaRelocating]
  );

  const handleAreaClickCb = useCallback(
    (e: L.LeafletMouseEvent, type: AreaType, fpIndex?: number) => {
      e.originalEvent.stopImmediatePropagation?.();
      e.originalEvent.stopPropagation();
      onAreaClick?.({ unitKey, type, fpIndex });
    },
    [onAreaClick, unitKey]
  );

  const handleRotateClickCb = useCallback(
    (e: L.LeafletMouseEvent) => {
      e.originalEvent.stopImmediatePropagation?.();
      e.originalEvent.stopPropagation();
      onRotateClick?.(unitKey);
    },
    [onRotateClick, unitKey]
  );

  // Memoized pathOptions that change with relocating state
  const ushapePathOptions = useMemo(() => {
    const relocating = isAreaRelocating('ushape');
    return {
      color: COLORS.USHAPE,
      fillColor: COLORS.USHAPE,
      fillOpacity: relocating ? 0.08 : 0.15,
      weight: 2,
      dashArray: relocating ? '6, 4' : undefined,
    };
  }, [isAreaRelocating]);

  const ahaPathOptions = useMemo(() => {
    const relocating = isAreaRelocating('aha');
    return {
      color: COLORS.AMMO_AREA,
      fillColor: COLORS.AMMO_AREA,
      fillOpacity: relocating ? 0.1 : 0.3,
      weight: 2,
      dashArray: relocating ? '6, 4' : undefined,
    };
  }, [isAreaRelocating]);

  const hidePathOptions = useMemo(() => {
    const relocating = isAreaRelocating('hide');
    return {
      color: COLORS.HIDE_AREA,
      fillColor: COLORS.HIDE_AREA,
      fillOpacity: relocating ? 0.1 : 0.3,
      weight: 2,
      dashArray: relocating ? '6, 4' : undefined,
    };
  }, [isAreaRelocating]);

  const reloadPathOptions = useMemo(() => {
    const relocating = isAreaRelocating('reload');
    return {
      color: COLORS.RELOAD_AREA,
      fillColor: COLORS.RELOAD_AREA,
      fillOpacity: relocating ? 0.1 : 0.3,
      weight: 2,
      dashArray: relocating ? '6, 4' : undefined,
    };
  }, [isAreaRelocating]);

  const fpPathOptionsList = useMemo(
    () =>
      (tacticalAreas.firePoints ?? []).map((_fp, i) => {
        const relocating = isAreaRelocating('fp', i);
        return {
          color: COLORS.FIRE_POINT,
          fillColor: COLORS.FIRE_POINT,
          fillOpacity: relocating ? 0.1 : 0.3,
          weight: 2,
          dashArray: relocating ? '6, 4' : undefined,
        };
      }),
    [tacticalAreas.firePoints, isAreaRelocating]
  );

  // Memoized eventHandlers
  const ushapeHandlers = useMemo(
    () =>
      canInteractArea('ushape')
        ? { click: (e: L.LeafletMouseEvent) => handleAreaClickCb(e, 'ushape') }
        : undefined,
    [canInteractArea, handleAreaClickCb]
  );
  const ahaHandlers = useMemo(
    () =>
      canInteractArea('aha')
        ? { click: (e: L.LeafletMouseEvent) => handleAreaClickCb(e, 'aha') }
        : undefined,
    [canInteractArea, handleAreaClickCb]
  );
  const hideHandlers = useMemo(
    () =>
      canInteractArea('hide')
        ? { click: (e: L.LeafletMouseEvent) => handleAreaClickCb(e, 'hide') }
        : undefined,
    [canInteractArea, handleAreaClickCb]
  );
  const reloadHandlers = useMemo(
    () =>
      canInteractArea('reload')
        ? { click: (e: L.LeafletMouseEvent) => handleAreaClickCb(e, 'reload') }
        : undefined,
    [canInteractArea, handleAreaClickCb]
  );
  const fpHandlersList = useMemo(
    () =>
      (tacticalAreas.firePoints ?? []).map((_fp, i) =>
        canInteractArea('fp', i)
          ? { click: (e: L.LeafletMouseEvent) => handleAreaClickCb(e, 'fp', i) }
          : undefined
      ),
    [tacticalAreas.firePoints, canInteractArea, handleAreaClickCb]
  );

  const rotateHandlers = useMemo(() => ({ click: handleRotateClickCb }), [handleRotateClickCb]);

  // Memoized positions
  const ushapePositions = useMemo(
    () => coordinatesToLatLng(tacticalAreas.uShapeVertices ?? []),
    [tacticalAreas.uShapeVertices]
  );
  const ahaPositions = useMemo(
    () => (tacticalAreas.ammoArea ? coordinatesToLatLng(tacticalAreas.ammoArea) : []),
    [tacticalAreas.ammoArea]
  );
  const hidePositions = useMemo(
    () => (tacticalAreas.hideArea ? coordinatesToLatLng(tacticalAreas.hideArea) : []),
    [tacticalAreas.hideArea]
  );
  const reloadPositions = useMemo(
    () => (tacticalAreas.reloadArea ? coordinatesToLatLng(tacticalAreas.reloadArea) : []),
    [tacticalAreas.reloadArea]
  );
  const fpPositionsList = useMemo(
    () => (tacticalAreas.firePoints ?? []).map((fp) => coordinatesToLatLng(fp)),
    [tacticalAreas.firePoints]
  );

  // Path positions
  const haPathPositions = useMemo(
    () =>
      paths.HA?.waypoints && paths.HA.waypoints.length > 1
        ? coordinatesToLatLng(paths.HA.waypoints)
        : null,
    [paths.HA]
  );
  const ahaPathPositions = useMemo(
    () =>
      paths.AHA?.waypoints && paths.AHA.waypoints.length > 1
        ? coordinatesToLatLng(paths.AHA.waypoints)
        : null,
    [paths.AHA]
  );
  const fpPathPositionsList = useMemo(
    () =>
      (paths.FP ?? []).map((fp) =>
        fp?.waypoints && fp.waypoints.length > 1 ? coordinatesToLatLng(fp.waypoints) : null
      ),
    [paths.FP]
  );
  const rlPathPositionsList = useMemo(
    () =>
      (paths.RL ?? []).map((rl) =>
        rl?.waypoints && rl.waypoints.length > 1 ? coordinatesToLatLng(rl.waypoints) : null
      ),
    [paths.RL]
  );
  const shrlPathPositions = useMemo(
    () =>
      paths.SHRL?.waypoints && paths.SHRL.waypoints.length > 1
        ? coordinatesToLatLng(paths.SHRL.waypoints)
        : null,
    [paths.SHRL]
  );

  // Calculate hide area center for range circle
  const hideCenter = useMemo(
    () =>
      tacticalAreas.hideArea && tacticalAreas.hideArea.length > 0
        ? calculateCenter(tacticalAreas.hideArea)
        : null,
    [tacticalAreas.hideArea]
  );
  const hideCenterLatLng = useMemo(
    () => (hideCenter ? ([hideCenter.lat, hideCenter.lng] as LatLngExpression) : null),
    [hideCenter]
  );

  // Fallback if no tactical areas
  if (!tacticalAreas.uShapeVertices || tacticalAreas.uShapeVertices.length === 0) {
    const weaponName = getWeaponSystemName(category);
    const center: LatLngExpression = [data.center.lat, data.center.lng];
    return (
      <>
        <Circle
          center={center}
          radius={radiusMeters}
          interactive={false}
          pathOptions={PATH_OPTIONS_FALLBACK_RANGE}
        />
        <CircleMarker center={center} radius={8} pathOptions={PATH_OPTIONS_FALLBACK_MARKER}>
          <Popup>
            <div className="text-text-primary">
              <strong>{unitName}</strong>
              <br />
              <span className="text-text-secondary">{weaponName}</span>
              <br />
              <br />
              Lat: {data.center.lat.toFixed(6)}°
              <br />
              Lng: {data.center.lng.toFixed(6)}°
              <br />
              Angle: {data.openingAngle}°
              <br />
              Range: {rangeNM} NM
            </div>
          </Popup>
        </CircleMarker>
      </>
    );
  }

  return (
    <>
      {/* U-Shape */}
      <Polygon
        ref={ushapeRefCb}
        positions={ushapePositions}
        interactive={canInteractArea('ushape')}
        pathOptions={ushapePathOptions}
        eventHandlers={ushapeHandlers}
      >
        <Tooltip direction="top">
          <strong>U-Shape Area</strong>
          <br />
          {unitName}
        </Tooltip>
      </Polygon>

      {/* Rotation Handle */}
      {onRotateClick && !isAnyRelocating && !isRotating && tacticalAreas.uShapeVertices[0] && (
        <CircleMarker
          center={[
            tacticalAreas.uShapeVertices[0].latitude,
            tacticalAreas.uShapeVertices[0].longitude,
          ]}
          radius={5}
          pathOptions={PATH_OPTIONS_ROTATE_HANDLE}
          eventHandlers={rotateHandlers}
        >
          <Tooltip direction="top">Rotate</Tooltip>
        </CircleMarker>
      )}

      {/* Ammo Area */}
      {ahaPositions.length > 0 && (
        <Polygon
          ref={ahaRefCb}
          positions={ahaPositions}
          interactive={canInteractArea('aha')}
          pathOptions={ahaPathOptions}
          eventHandlers={ahaHandlers}
        >
          <Tooltip direction="top">
            <strong>Ammo Holding Area (AHA)</strong>
          </Tooltip>
        </Polygon>
      )}

      {/* Hide Area */}
      {hidePositions.length > 0 && (
        <>
          <Polygon
            ref={hideRefCb}
            positions={hidePositions}
            interactive={canInteractArea('hide')}
            pathOptions={hidePathOptions}
            eventHandlers={hideHandlers}
          >
            <Tooltip direction="top">
              <strong>Hide Area (HA)</strong>
            </Tooltip>
          </Polygon>

          {/* Hide Area Center Marker */}
          {hideCenterLatLng && (
            <CircleMarker
              center={hideCenterLatLng}
              radius={6}
              pathOptions={PATH_OPTIONS_HIDE_CENTER}
            >
              <Tooltip direction="top">
                <strong>Hide Area Center</strong>
              </Tooltip>
            </CircleMarker>
          )}

          {/* Weapon Range Circle (from hide area center) */}
          {hideCenterLatLng && (
            <Circle
              center={hideCenterLatLng}
              radius={radiusMeters}
              interactive={false}
              pathOptions={PATH_OPTIONS_RANGE}
            />
          )}
        </>
      )}

      {/* Reload Area */}
      {reloadPositions.length > 0 && (
        <Polygon
          ref={reloadRefCb}
          positions={reloadPositions}
          interactive={canInteractArea('reload')}
          pathOptions={reloadPathOptions}
          eventHandlers={reloadHandlers}
        >
          <Tooltip direction="top">
            <strong>Reload Area (RL)</strong>
          </Tooltip>
        </Polygon>
      )}

      {/* Fire Points */}
      {fpPositionsList.map((positions, i) => (
        <Polygon
          key={`fp-${i}`}
          ref={fpRefCallbacks[i]}
          positions={positions}
          interactive={canInteractArea('fp', i)}
          pathOptions={fpPathOptionsList[i]}
          eventHandlers={fpHandlersList[i]}
        >
          <Tooltip direction="top">
            <strong>Fire Point {i + 1}</strong>
          </Tooltip>
        </Polygon>
      ))}

      {/* Shelter Points */}
      {(tacticalAreas.shelterPoints ?? []).map((point, i) => (
        <CircleMarker
          key={`shelter-${i}`}
          center={[point.latitude, point.longitude] as LatLngExpression}
          radius={4}
          interactive={false}
          pathOptions={PATH_OPTIONS_SHELTER}
        >
          <Tooltip direction="top">
            <strong>Shelter {i + 1}</strong>
          </Tooltip>
        </CircleMarker>
      ))}

      {/* Movement Paths */}
      {haPathPositions && <Polyline positions={haPathPositions} pathOptions={PATH_OPTIONS_HA} />}
      {ahaPathPositions && <Polyline positions={ahaPathPositions} pathOptions={PATH_OPTIONS_AHA} />}
      {fpPathPositionsList.map(
        (positions, i) =>
          positions && (
            <Polyline key={`path-fp-${i}`} positions={positions} pathOptions={PATH_OPTIONS_FP} />
          )
      )}
      {rlPathPositionsList.map(
        (positions, i) =>
          positions && (
            <Polyline key={`path-rl-${i}`} positions={positions} pathOptions={PATH_OPTIONS_RL} />
          )
      )}
      {shrlPathPositions && (
        <Polyline positions={shrlPathPositions} pathOptions={PATH_OPTIONS_SHRL}>
          <Tooltip direction="top">
            <strong>Shelter → Reload (SHRL)</strong>
          </Tooltip>
        </Polyline>
      )}
    </>
  );
});

// ============================================================================
// DeployedMissileSystems Component
// ============================================================================
interface DeployedMissileSystemsProps {
  deployedSystems: Map<string, DeployedMissileSystemData>;
  getUnitInfo: (unitKey: string) => { name: string; category: string } | null;
  onAreaClick?: (area: RelocatingArea) => void;
  onRotateClick?: (unitKey: string) => void;
  relocatingArea?: RelocatingArea | null;
  rotatingUnitKey?: string | null;
}

export function DeployedMissileSystems({
  deployedSystems,
  onAreaClick,
  onRotateClick,
  relocatingArea,
  rotatingUnitKey,
}: DeployedMissileSystemsProps) {
  const isAnyRelocating = Boolean(relocatingArea);

  return (
    <>
      {Array.from(deployedSystems.entries()).map(([unitKey, data]) => (
        <MissileSystemMarker
          key={unitKey}
          unitKey={unitKey}
          data={data}
          onAreaClick={onAreaClick}
          onRotateClick={onRotateClick}
          relocatingArea={relocatingArea?.unitKey === unitKey ? relocatingArea : null}
          isAnyRelocating={isAnyRelocating}
          isRotating={rotatingUnitKey === unitKey}
        />
      ))}
    </>
  );
}

// ============================================================================
// MissileSystemPreview Component
// ============================================================================
interface MissileSystemPreviewProps {
  uShapeVertices: { latitude: number; longitude: number }[];
  ammoArea: { latitude: number; longitude: number }[];
  hideArea: { latitude: number; longitude: number }[];
  reloadArea: { latitude: number; longitude: number }[];
  firePoints: { latitude: number; longitude: number }[][];
  isValid: boolean;
}

export function MissileSystemPreview({
  uShapeVertices,
  ammoArea,
  hideArea,
  reloadArea,
  firePoints,
  isValid,
}: MissileSystemPreviewProps) {
  const invalidColor = '#ff4444';
  const dashArray = '6, 4';
  const color = (validColor: string) => (isValid ? validColor : invalidColor);

  return (
    <>
      {uShapeVertices.length > 0 && (
        <Polygon
          positions={coordinatesToLatLng(uShapeVertices)}
          interactive={false}
          pathOptions={{
            color: color(COLORS.USHAPE),
            fillColor: color(COLORS.USHAPE),
            fillOpacity: isValid ? 0.1 : 0.08,
            weight: 2,
            dashArray,
          }}
        />
      )}

      {ammoArea.length > 0 && (
        <Polygon
          positions={coordinatesToLatLng(ammoArea)}
          interactive={false}
          pathOptions={{
            color: color(COLORS.AMMO_AREA),
            fillColor: color(COLORS.AMMO_AREA),
            fillOpacity: isValid ? 0.15 : 0.1,
            weight: 1.5,
            dashArray,
          }}
        />
      )}

      {hideArea.length > 0 && (
        <Polygon
          positions={coordinatesToLatLng(hideArea)}
          interactive={false}
          pathOptions={{
            color: color(COLORS.HIDE_AREA),
            fillColor: color(COLORS.HIDE_AREA),
            fillOpacity: isValid ? 0.15 : 0.1,
            weight: 1.5,
            dashArray,
          }}
        />
      )}

      {reloadArea.length > 0 && (
        <Polygon
          positions={coordinatesToLatLng(reloadArea)}
          interactive={false}
          pathOptions={{
            color: color(COLORS.RELOAD_AREA),
            fillColor: color(COLORS.RELOAD_AREA),
            fillOpacity: isValid ? 0.15 : 0.1,
            weight: 1.5,
            dashArray,
          }}
        />
      )}

      {firePoints.map((fp, i) => (
        <Polygon
          key={`preview-fp-${i}`}
          positions={coordinatesToLatLng(fp)}
          interactive={false}
          pathOptions={{
            color: color(COLORS.FIRE_POINT),
            fillColor: color(COLORS.FIRE_POINT),
            fillOpacity: isValid ? 0.15 : 0.1,
            weight: 1.5,
            dashArray,
          }}
        />
      ))}
    </>
  );
}

// ============================================================================
// AreaRelocatePreview Component
// ============================================================================
interface AreaRelocatePreviewProps {
  vertices: { latitude: number; longitude: number }[];
  areaType: AreaType;
}

export function AreaRelocatePreview({ vertices, areaType }: AreaRelocatePreviewProps) {
  if (vertices.length === 0) return null;
  const c = AREA_TYPE_COLOR[areaType];
  return (
    <Polygon
      positions={coordinatesToLatLng(vertices)}
      interactive={false}
      pathOptions={{
        color: c,
        fillColor: c,
        fillOpacity: 0.15,
        weight: 2,
        dashArray: '6, 4',
      }}
    />
  );
}
