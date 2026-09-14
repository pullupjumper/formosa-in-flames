import { memo, useMemo, useCallback } from 'react';
import { Circle, CircleMarker, Polygon, Polyline, Popup, Tooltip, Marker } from 'react-leaflet';
import L from 'leaflet';
import type { LatLngExpression } from 'leaflet';
import type { Coordinate } from '@/types/geo';
import type { MissileDeployment, ForceImage } from '@/types/setupMenu';
import { CONFIG } from '@/constants/setupMenu';
import { getAreaColor } from '@/constants/deployment';
import type { AreaType, RelocatingArea } from '@/types/deployment';
import { getWeaponSystemName } from '@/utils/map';
import { calculateCentroid, nauticalMilesToMeters, toLeafletPositions } from '@/utils/geo';

// ============================================================================
// COLORS
// ============================================================================
const COLORS = {
  USHAPE: getAreaColor('ushape'),
  AMMO_AREA: getAreaColor('aha'),
  HIDE_AREA: getAreaColor('hide'),
  RELOAD_AREA: getAreaColor('reload'),
  FIRE_POINT: getAreaColor('fp'),
  WEAPON_RANGE: '#ff4444',
  SHELTER: '#c084fc',
  PATH_HA: getAreaColor('hide'),
  PATH_AHA: getAreaColor('aha'),
  PATH_FP: getAreaColor('fp'),
  PATH_RL: getAreaColor('reload'),
  PATH_SHRL: '#c084fc',
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
// ICON
// ============================================================================
const MISSILE_ICON_URL = 'https://i.meee.com.tw/suDq81b.png';
const SAM_ICON_URL = 'https://i.meee.com.tw/PCUEceO.png';
const ICON_IMAGES: Record<string, ForceImage> = {
  sam: { url: SAM_ICON_URL, label: 'SAM', width: 25, height: 15 },
  ssm: { url: MISSILE_ICON_URL, label: 'SSM', width: 25, height: 15 },
};

// ============================================================================
// Helper Functions
// ============================================================================
/**
 * Anchor a polygon's tooltip at its top edge (max latitude) rather than its
 * geometric center, so the label does not cover the shape.
 */
function calculateTooltipAnchor(vertices: Coordinate[] | undefined): L.LatLng | null {
  if (!vertices || vertices.length < 3) return null;
  const center = calculateCentroid(vertices);
  const maxLatitude = Math.max(...vertices.map((vertex) => vertex.latitude));
  return L.latLng(maxLatitude, center.longitude);
}

/** Ref callback that overrides Leaflet's `getCenter` with the tooltip anchor. */
function createAnchorRef(anchor: L.LatLng | null) {
  return (node: L.Polygon | null) => {
    if (node && anchor) {
      node.getCenter = () => anchor;
    }
  };
}

function useTooltipAnchorRef(vertices: Coordinate[] | undefined) {
  return useMemo(() => createAnchorRef(calculateTooltipAnchor(vertices)), [vertices]);
}

/** Leaflet positions for a path, or null when it has fewer than two waypoints */
function toPathPositions(waypoints: Coordinate[] | undefined): LatLngExpression[] | null {
  return waypoints && waypoints.length > 1 ? toLeafletPositions(waypoints) : null;
}

function createIcon(images: Record<string, ForceImage>, category: string): L.DivIcon {
  const image = category === 'sam' ? images.sam : images.ssm;
  const inner = image.url
    ? `<img src="${image.url}" alt="${image.label}" style="width:100%;height:100%;object-fit:contain" />`
    : `<div style="display:flex;align-items:center;justify-content:center;width:100%;height:100%;
       border:1px dashed #137cbd;background:rgba(19,124,189,0.12);color:#a7b6c2;
       font-size:10px;letter-spacing:1px;text-align:center">${image.label}<br/>IMAGE</div>`;

  return L.divIcon({
    className: '',
    html: `<div style="width:${image.width}px;height:${image.height}px">${inner}</div>`,
    iconSize: [image.width, image.height],
    iconAnchor: [image.width / 2, image.height / 2],
  });
}

// ============================================================================
// MissileSystemMarker Component
// ============================================================================
interface MissileSystemMarkerProps {
  unitKey: string;
  data: MissileDeployment;
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
  const rangeNm = CONFIG.WEAPON_RANGES[category] || 100;
  const radiusMeters = nauticalMilesToMeters(rangeNm);

  const ushapePolygonRef = useTooltipAnchorRef(tacticalAreas.uShapeVertices);
  const ahaPolygonRef = useTooltipAnchorRef(tacticalAreas.ammoArea);
  const hidePolygonRef = useTooltipAnchorRef(tacticalAreas.hideArea);
  const reloadPolygonRef = useTooltipAnchorRef(tacticalAreas.reloadArea);

  const firePointPolygonRefs = useMemo(
    () =>
      (tacticalAreas.firePoints ?? []).map((firePoint) =>
        createAnchorRef(calculateTooltipAnchor(firePoint))
      ),
    [tacticalAreas.firePoints]
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

  const handleAreaClick = useCallback(
    (event: L.LeafletMouseEvent, type: AreaType, fpIndex?: number) => {
      event.originalEvent.stopImmediatePropagation?.();
      event.originalEvent.stopPropagation();
      onAreaClick?.({ unitKey, type, fpIndex });
    },
    [onAreaClick, unitKey]
  );

  const handleRotateClick = useCallback(
    (event: L.LeafletMouseEvent) => {
      event.originalEvent.stopImmediatePropagation?.();
      event.originalEvent.stopPropagation();
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

  const firePointPathOptions = useMemo(
    () =>
      (tacticalAreas.firePoints ?? []).map((_firePoint, index) => {
        const relocating = isAreaRelocating('fp', index);
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
  const ushapeEventHandlers = useMemo(
    () =>
      canInteractArea('ushape')
        ? { click: (event: L.LeafletMouseEvent) => handleAreaClick(event, 'ushape') }
        : undefined,
    [canInteractArea, handleAreaClick]
  );
  const ahaEventHandlers = useMemo(
    () =>
      canInteractArea('aha')
        ? { click: (event: L.LeafletMouseEvent) => handleAreaClick(event, 'aha') }
        : undefined,
    [canInteractArea, handleAreaClick]
  );
  const hideEventHandlers = useMemo(
    () =>
      canInteractArea('hide')
        ? { click: (event: L.LeafletMouseEvent) => handleAreaClick(event, 'hide') }
        : undefined,
    [canInteractArea, handleAreaClick]
  );
  const reloadEventHandlers = useMemo(
    () =>
      canInteractArea('reload')
        ? { click: (event: L.LeafletMouseEvent) => handleAreaClick(event, 'reload') }
        : undefined,
    [canInteractArea, handleAreaClick]
  );
  const firePointEventHandlers = useMemo(
    () =>
      (tacticalAreas.firePoints ?? []).map((_firePoint, index) =>
        canInteractArea('fp', index)
          ? { click: (event: L.LeafletMouseEvent) => handleAreaClick(event, 'fp', index) }
          : undefined
      ),
    [tacticalAreas.firePoints, canInteractArea, handleAreaClick]
  );

  const rotateEventHandlers = useMemo(() => ({ click: handleRotateClick }), [handleRotateClick]);

  // Memoized positions
  const ushapePositions = useMemo(
    () => toLeafletPositions(tacticalAreas.uShapeVertices ?? []),
    [tacticalAreas.uShapeVertices]
  );
  const ahaPositions = useMemo(
    () => toLeafletPositions(tacticalAreas.ammoArea ?? []),
    [tacticalAreas.ammoArea]
  );
  const hidePositions = useMemo(
    () => toLeafletPositions(tacticalAreas.hideArea ?? []),
    [tacticalAreas.hideArea]
  );
  const reloadPositions = useMemo(
    () => toLeafletPositions(tacticalAreas.reloadArea ?? []),
    [tacticalAreas.reloadArea]
  );
  const firePointPositions = useMemo(
    () => (tacticalAreas.firePoints ?? []).map(toLeafletPositions),
    [tacticalAreas.firePoints]
  );

  // Path positions (null when the path has fewer than two waypoints)
  const haPathPositions = useMemo(() => toPathPositions(paths.HA?.waypoints), [paths.HA]);
  const ahaPathPositions = useMemo(() => toPathPositions(paths.AHA?.waypoints), [paths.AHA]);
  const firePointPathPositions = useMemo(
    () => (paths.FP ?? []).map((path) => toPathPositions(path?.waypoints)),
    [paths.FP]
  );
  const reloadPathPositions = useMemo(
    () => (paths.RL ?? []).map((path) => toPathPositions(path?.waypoints)),
    [paths.RL]
  );
  const shrlPathPositions = useMemo(() => toPathPositions(paths.SHRL?.waypoints), [paths.SHRL]);

  // Hide area center anchors the unit marker and its weapon range circle
  const hideCenterLatLng = useMemo<LatLngExpression | null>(() => {
    if (!tacticalAreas.hideArea || tacticalAreas.hideArea.length === 0) return null;
    const center = calculateCentroid(tacticalAreas.hideArea);
    return [center.latitude, center.longitude];
  }, [tacticalAreas.hideArea]);

  const icon = useMemo(() => createIcon(ICON_IMAGES, category), [category]);

  // Fallback if no tactical areas
  if (!tacticalAreas.uShapeVertices || tacticalAreas.uShapeVertices.length === 0) {
    const weaponName = getWeaponSystemName(category);
    const center: LatLngExpression = [data.center.latitude, data.center.longitude];
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
              Lat: {data.center.latitude.toFixed(6)}°
              <br />
              Lng: {data.center.longitude.toFixed(6)}°
              <br />
              Angle: {data.openingAngle}°
              <br />
              Range: {rangeNm} NM
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
        ref={ushapePolygonRef}
        positions={ushapePositions}
        interactive={canInteractArea('ushape')}
        pathOptions={ushapePathOptions}
        eventHandlers={ushapeEventHandlers}
      >
        <Tooltip direction="top">
          <strong>U-Shape Area</strong>
          <br />
          {/*{unitName}*/}
        </Tooltip>
      </Polygon>

      {/* Rotation Handle */}
      {onRotateClick && !isAnyRelocating && !isRotating && tacticalAreas.uShapeVertices[0] && (
        <CircleMarker
          center={ushapePositions[0]}
          radius={5}
          pathOptions={PATH_OPTIONS_ROTATE_HANDLE}
          eventHandlers={rotateEventHandlers}
        >
          <Tooltip direction="top">Rotate</Tooltip>
        </CircleMarker>
      )}

      {/* Ammo Area */}
      {ahaPositions.length > 0 && (
        <Polygon
          ref={ahaPolygonRef}
          positions={ahaPositions}
          interactive={canInteractArea('aha')}
          pathOptions={ahaPathOptions}
          eventHandlers={ahaEventHandlers}
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
            ref={hidePolygonRef}
            positions={hidePositions}
            interactive={canInteractArea('hide')}
            pathOptions={hidePathOptions}
            eventHandlers={hideEventHandlers}
          >
            <Tooltip direction="top">
              <strong>Hide Area (HA)</strong>
            </Tooltip>
          </Polygon>

          {/* Hide Area Center Marker */}
          {hideCenterLatLng && (
            <Marker position={hideCenterLatLng} icon={icon}>
              <Tooltip direction="top">
                <strong>{unitName}</strong>
              </Tooltip>
            </Marker>
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
          ref={reloadPolygonRef}
          positions={reloadPositions}
          interactive={canInteractArea('reload')}
          pathOptions={reloadPathOptions}
          eventHandlers={reloadEventHandlers}
        >
          <Tooltip direction="top">
            <strong>Reload Area (RL)</strong>
          </Tooltip>
        </Polygon>
      )}

      {/* Fire Points */}
      {firePointPositions.map((positions, index) => (
        <Polygon
          key={`fp-${index}`}
          ref={firePointPolygonRefs[index]}
          positions={positions}
          interactive={canInteractArea('fp', index)}
          pathOptions={firePointPathOptions[index]}
          eventHandlers={firePointEventHandlers[index]}
        >
          <Tooltip direction="top">
            <strong>Fire Point {index + 1}</strong>
          </Tooltip>
        </Polygon>
      ))}

      {/* Shelter Points */}
      {(tacticalAreas.shelterPoints ?? []).map((point, index) => (
        <CircleMarker
          key={`shelter-${index}`}
          center={[point.latitude, point.longitude]}
          radius={4}
          interactive={false}
          pathOptions={PATH_OPTIONS_SHELTER}
        >
          <Tooltip direction="top">
            <strong>Shelter {index + 1}</strong>
          </Tooltip>
        </CircleMarker>
      ))}

      {/* Movement Paths */}
      {haPathPositions && (
        <Polyline positions={haPathPositions} pathOptions={PATH_OPTIONS_HA}>
          <Tooltip direction="top">
            <strong>RL → HA</strong>
          </Tooltip>
        </Polyline>
      )}
      {ahaPathPositions && (
        <Polyline positions={ahaPathPositions} pathOptions={PATH_OPTIONS_AHA}>
          <Tooltip direction="top">
            <strong>RL → AHA</strong>
          </Tooltip>
        </Polyline>
      )}
      {firePointPathPositions.map(
        (positions, index) =>
          positions && (
            <Polyline key={`path-fp-${index}`} positions={positions} pathOptions={PATH_OPTIONS_FP}>
              <Tooltip direction="top">
                <strong>HA → FP {index + 1}</strong>
              </Tooltip>
            </Polyline>
          )
      )}
      {reloadPathPositions.map(
        (positions, index) =>
          positions && (
            <Polyline key={`path-rl-${index}`} positions={positions} pathOptions={PATH_OPTIONS_RL}>
              <Tooltip direction="top">
                <strong>FP {index + 1} → RL </strong>
              </Tooltip>
            </Polyline>
          )
      )}
      {shrlPathPositions && (
        <Polyline positions={shrlPathPositions} pathOptions={PATH_OPTIONS_SHRL}>
          <Tooltip direction="top">
            <strong>Shelter → RL (SHRL)</strong>
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
  deployedSystems: Map<string, MissileDeployment>;
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
  uShapeVertices: Coordinate[];
  ammoArea: Coordinate[];
  hideArea: Coordinate[];
  reloadArea: Coordinate[];
  firePoints: Coordinate[][];
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
          positions={toLeafletPositions(uShapeVertices)}
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
          positions={toLeafletPositions(ammoArea)}
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
          positions={toLeafletPositions(hideArea)}
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
          positions={toLeafletPositions(reloadArea)}
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

      {firePoints.map((firePoint, index) => (
        <Polygon
          key={`preview-fp-${index}`}
          positions={toLeafletPositions(firePoint)}
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
  vertices: Coordinate[];
  areaType: AreaType;
}

export function AreaRelocatePreview({ vertices, areaType }: AreaRelocatePreviewProps) {
  if (vertices.length === 0) return null;
  const areaColor = getAreaColor(areaType);
  return (
    <Polygon
      positions={toLeafletPositions(vertices)}
      interactive={false}
      pathOptions={{
        color: areaColor,
        fillColor: areaColor,
        fillOpacity: 0.15,
        weight: 2,
        dashArray: '6, 4',
      }}
    />
  );
}
