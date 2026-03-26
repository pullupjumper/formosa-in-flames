import { Circle, CircleMarker, Polygon, Polyline, Popup, Tooltip } from 'react-leaflet';
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
  PATH_HA: '#6bcb77',
  PATH_AHA: '#ffd93d',
  PATH_FP: '#ff922b',
  PATH_RL: '#4d96ff',
};

const AREA_TYPE_COLOR: Record<AreaType, string> = {
  ushape: COLORS.USHAPE,
  aha: COLORS.AMMO_AREA,
  hide: COLORS.HIDE_AREA,
  reload: COLORS.RELOAD_AREA,
  fp: COLORS.FIRE_POINT,
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

// ============================================================================
// MissileSystemMarker Component
// ============================================================================
interface MissileSystemMarkerProps {
  unitKey: string;
  data: DeployedMissileSystemData;
  onAreaClick?: (area: RelocatingArea) => void;
  onRotateClick?: (unitKey: string) => void;
  relocatingArea?: RelocatingArea | null;
  isRotating?: boolean;
}

export function MissileSystemMarker({
  unitKey,
  data,
  onAreaClick,
  onRotateClick,
  relocatingArea,
  isRotating,
}: MissileSystemMarkerProps) {
  const { unitName, category, tacticalAreas, paths } = data;
  const rangeNM = CONFIG.WEAPON_RANGES[category] || 100;
  const radiusMeters = rangeNM * 1852;

  const isThisUnit = relocatingArea?.unitKey === unitKey;
  const isAnyRelocating = Boolean(relocatingArea);

  const isAreaRelocating = (type: AreaType, fpIndex?: number) =>
    isThisUnit &&
    relocatingArea?.type === type &&
    (type !== 'fp' || relocatingArea?.fpIndex === fpIndex);

  const canInteractArea = (type: AreaType, fpIndex?: number) => {
    if (!onAreaClick) return false;
    if (!isAnyRelocating) return true;
    return isAreaRelocating(type, fpIndex);
  };

  const makeClickHandler = (type: AreaType, fpIndex?: number) =>
    canInteractArea(type, fpIndex)
      ? {
          click: (e: L.LeafletMouseEvent) => {
            e.originalEvent.stopImmediatePropagation?.();
            e.originalEvent.stopPropagation();
            onAreaClick?.({ unitKey, type, fpIndex });
          },
        }
      : undefined;

  // Calculate hide area center for range circle
  const hideCenter =
    tacticalAreas.hideArea && tacticalAreas.hideArea.length > 0
      ? calculateCenter(tacticalAreas.hideArea)
      : null;

  // Fallback if no tactical areas
  if (!tacticalAreas.uShapeVertices || tacticalAreas.uShapeVertices.length === 0) {
    const weaponName = getWeaponSystemName(category);
    return (
      <>
        <Circle
          center={[data.center.lat, data.center.lng]}
          radius={radiusMeters}
          interactive={false}
          pathOptions={{
            color: '#ff4444',
            fillColor: '#ff4444',
            fillOpacity: 0.01,
            weight: 1.5,
            opacity: 0.25,
            dashArray: '5, 10',
          }}
        />
        <CircleMarker
          center={[data.center.lat, data.center.lng]}
          radius={8}
          pathOptions={{
            color: '#fff',
            fillColor: '#ff6b6b',
            fillOpacity: 1,
            weight: 2,
          }}
        >
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
        positions={coordinatesToLatLng(tacticalAreas.uShapeVertices)}
        interactive={canInteractArea('ushape')}
        pathOptions={{
          color: COLORS.USHAPE,
          fillColor: COLORS.USHAPE,
          fillOpacity: isAreaRelocating('ushape') ? 0.08 : 0.15,
          weight: 2,
          dashArray: isAreaRelocating('ushape') ? '6, 4' : undefined,
        }}
        eventHandlers={makeClickHandler('ushape')}
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
          pathOptions={{
            color: '#fff',
            fillColor: COLORS.USHAPE,
            fillOpacity: 1,
            weight: 2,
          }}
          eventHandlers={{
            click: (e: L.LeafletMouseEvent) => {
              e.originalEvent.stopImmediatePropagation?.();
              e.originalEvent.stopPropagation();
              onRotateClick(unitKey);
            },
          }}
        >
          <Tooltip direction="top">Rotate</Tooltip>
        </CircleMarker>
      )}

      {/* Ammo Area */}
      {tacticalAreas.ammoArea && tacticalAreas.ammoArea.length > 0 && (
        <Polygon
          positions={coordinatesToLatLng(tacticalAreas.ammoArea)}
          interactive={canInteractArea('aha')}
          pathOptions={{
            color: COLORS.AMMO_AREA,
            fillColor: COLORS.AMMO_AREA,
            fillOpacity: isAreaRelocating('aha') ? 0.1 : 0.3,
            weight: 2,
            dashArray: isAreaRelocating('aha') ? '6, 4' : undefined,
          }}
          eventHandlers={makeClickHandler('aha')}
        >
          <Tooltip direction="top">
            <strong>Ammo Holding Area (AHA)</strong>
          </Tooltip>
        </Polygon>
      )}

      {/* Hide Area */}
      {tacticalAreas.hideArea && tacticalAreas.hideArea.length > 0 && (
        <>
          <Polygon
            positions={coordinatesToLatLng(tacticalAreas.hideArea)}
            interactive={canInteractArea('hide')}
            pathOptions={{
              color: COLORS.HIDE_AREA,
              fillColor: COLORS.HIDE_AREA,
              fillOpacity: isAreaRelocating('hide') ? 0.1 : 0.3,
              weight: 2,
              dashArray: isAreaRelocating('hide') ? '6, 4' : undefined,
            }}
            eventHandlers={makeClickHandler('hide')}
          >
            <Tooltip direction="top">
              <strong>Hide Area (HA)</strong>
            </Tooltip>
          </Polygon>

          {/* Hide Area Center Marker */}
          {hideCenter && (
            <CircleMarker
              center={[hideCenter.lat, hideCenter.lng]}
              radius={6}
              pathOptions={{
                color: '#fff',
                fillColor: COLORS.HIDE_AREA,
                fillOpacity: 1,
                weight: 2,
              }}
            >
              <Tooltip direction="top">
                <strong>Hide Area Center</strong>
              </Tooltip>
            </CircleMarker>
          )}

          {/* Weapon Range Circle (from hide area center) */}
          {hideCenter && (
            <Circle
              center={[hideCenter.lat, hideCenter.lng]}
              radius={radiusMeters}
              interactive={false}
              pathOptions={{
                color: COLORS.WEAPON_RANGE,
                fillColor: COLORS.WEAPON_RANGE,
                fillOpacity: 0.01,
                weight: 1.5,
                opacity: 0.25,
                dashArray: '5, 10',
              }}
            />
          )}
        </>
      )}

      {/* Reload Area */}
      {tacticalAreas.reloadArea && tacticalAreas.reloadArea.length > 0 && (
        <Polygon
          positions={coordinatesToLatLng(tacticalAreas.reloadArea)}
          interactive={canInteractArea('reload')}
          pathOptions={{
            color: COLORS.RELOAD_AREA,
            fillColor: COLORS.RELOAD_AREA,
            fillOpacity: isAreaRelocating('reload') ? 0.1 : 0.3,
            weight: 2,
            dashArray: isAreaRelocating('reload') ? '6, 4' : undefined,
          }}
          eventHandlers={makeClickHandler('reload')}
        >
          <Tooltip direction="top">
            <strong>Reload Area (RL)</strong>
          </Tooltip>
        </Polygon>
      )}

      {/* Fire Points */}
      {tacticalAreas.firePoints &&
        tacticalAreas.firePoints.map((fp, i) => {
          const relocating = isAreaRelocating('fp', i);
          return (
            <Polygon
              key={`fp-${i}`}
              positions={coordinatesToLatLng(fp)}
              interactive={canInteractArea('fp', i)}
              pathOptions={{
                color: COLORS.FIRE_POINT,
                fillColor: COLORS.FIRE_POINT,
                fillOpacity: relocating ? 0.1 : 0.3,
                weight: 2,
                dashArray: relocating ? '6, 4' : undefined,
              }}
              eventHandlers={makeClickHandler('fp', i)}
            >
              <Tooltip direction="top">
                <strong>Fire Point {i + 1}</strong>
              </Tooltip>
            </Polygon>
          );
        })}

      {/* Movement Paths */}
      {/* HA Path: Reload -> Hide */}
      {paths.HA?.waypoints && paths.HA.waypoints.length > 1 && (
        <Polyline
          positions={coordinatesToLatLng(paths.HA.waypoints)}
          pathOptions={{
            color: COLORS.PATH_HA,
            weight: 2,
            opacity: 0.7,
            dashArray: '5, 5',
          }}
        />
      )}

      {/* AHA Path: Reload -> Ammo */}
      {paths.AHA?.waypoints && paths.AHA.waypoints.length > 1 && (
        <Polyline
          positions={coordinatesToLatLng(paths.AHA.waypoints)}
          pathOptions={{
            color: COLORS.PATH_AHA,
            weight: 2,
            opacity: 0.7,
            dashArray: '5, 5',
          }}
        />
      )}

      {/* FP Paths: Hide -> Fire Points */}
      {paths.FP &&
        paths.FP.map(
          (fp, i) =>
            fp?.waypoints &&
            fp.waypoints.length > 1 && (
              <Polyline
                key={`path-fp-${i}`}
                positions={coordinatesToLatLng(fp.waypoints)}
                pathOptions={{
                  color: COLORS.PATH_FP,
                  weight: 2,
                  opacity: 0.7,
                  dashArray: '5, 5',
                }}
              />
            )
        )}

      {/* RL Paths: Fire Points -> Reload */}
      {paths.RL &&
        paths.RL.map(
          (rl, i) =>
            rl?.waypoints &&
            rl.waypoints.length > 1 && (
              <Polyline
                key={`path-rl-${i}`}
                positions={coordinatesToLatLng(rl.waypoints)}
                pathOptions={{
                  color: COLORS.PATH_RL,
                  weight: 2,
                  opacity: 0.7,
                  dashArray: '5, 5',
                }}
              />
            )
        )}
    </>
  );
}

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
  return (
    <>
      {Array.from(deployedSystems.entries()).map(([unitKey, data]) => (
        <MissileSystemMarker
          key={unitKey}
          unitKey={unitKey}
          data={data}
          onAreaClick={onAreaClick}
          onRotateClick={onRotateClick}
          relocatingArea={relocatingArea}
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
