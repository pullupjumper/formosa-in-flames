import { memo, useMemo, useCallback } from 'react';
import { CircleMarker, Polyline, Popup, Tooltip, Marker } from 'react-leaflet';
import L from 'leaflet';
import type { LatLngExpression } from 'leaflet';
import type { Coordinate } from '@/types/geo';
import type { MissileDeployment, MissileSystems, TacticalAreas } from '@/types/controlPanel';
import type { AreaType, RelocatingArea } from '@/types/deployment';
import { getAreaColor } from '@/constants/deployment';
import { canInteractArea, getWeaponSystemName } from '@/utils/map';
import { calculateCentroid, toLeafletLatLng, toLeafletPositions } from '@/utils/geo';
import { TacticalPolygon, RangeCircle, ZoomGate, DETAIL_MIN_ZOOM } from './primitives';
import { createImageIcon, ICON_IMAGES, getBatteryImage } from './icons';
import type { DeploymentPreview } from '@/utils/deploymentGeometry';

// ============================================================================
// COLORS
// ============================================================================
const WEAPON_RANGE_COLOR = '#ff4444';
const SHELTER_COLOR = '#c084fc';

// ============================================================================
// Static pathOptions (never re-created)
// ============================================================================
const PATH_OPTIONS_HA = { color: getAreaColor('hide'), weight: 2, opacity: 0.7, dashArray: '5, 5' };
const PATH_OPTIONS_AHA = { color: getAreaColor('aha'), weight: 2, opacity: 0.7, dashArray: '5, 5' };
const PATH_OPTIONS_FP = { color: getAreaColor('fp'), weight: 2, opacity: 0.7, dashArray: '5, 5' };
const PATH_OPTIONS_RL = {
  color: getAreaColor('reload'),
  weight: 2,
  opacity: 0.7,
  dashArray: '5, 5',
};
const PATH_OPTIONS_SHRL = { color: SHELTER_COLOR, weight: 2, opacity: 0.7, dashArray: '2, 6' };
const PATH_OPTIONS_ROTATE_HANDLE = {
  color: '#fff',
  fillColor: getAreaColor('ushape'),
  fillOpacity: 1,
  weight: 2,
};
const PATH_OPTIONS_SHELTER = {
  color: '#fff',
  fillColor: SHELTER_COLOR,
  fillOpacity: 0.9,
  weight: 1.5,
};
const PATH_OPTIONS_FALLBACK_MARKER = {
  color: '#fff',
  fillColor: getAreaColor('ushape'),
  fillOpacity: 1,
  weight: 2,
};

// ============================================================================
// AREA TABLE — the four single polygons; fire points are indexed separately
// ============================================================================
interface SingleArea {
  type: Exclude<AreaType, 'fp'>;
  field: keyof Pick<TacticalAreas, 'uShapeVertices' | 'ammoArea' | 'hideArea' | 'reloadArea'>;
  label: string;
}

const SINGLE_AREAS: readonly SingleArea[] = [
  { type: 'ushape', field: 'uShapeVertices', label: 'U-Shape Area' },
  { type: 'aha', field: 'ammoArea', label: 'Ammo Holding Area (AHA)' },
  { type: 'hide', field: 'hideArea', label: 'Hide Area (HA)' },
  { type: 'reload', field: 'reloadArea', label: 'Reload Area (RL)' },
];

/** Leaflet positions for a path, or null when it has fewer than two waypoints */
function toPathPositions(waypoints: Coordinate[] | undefined): LatLngExpression[] | null {
  return waypoints && waypoints.length > 1 ? toLeafletPositions(waypoints) : null;
}

// ============================================================================
// MissileSystemMarker Component
// ============================================================================
interface MissileSystemMarkerProps {
  unitKey: string;
  data: MissileDeployment;
  /** Weapon range of this unit's firing unit, in NM */
  rangeNm: number;
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
  rangeNm,
  onAreaClick,
  onRotateClick,
  relocatingArea,
  isAnyRelocating = false,
  isRotating,
}: MissileSystemMarkerProps) {
  const { unitName, missileSystemType: category, tacticalAreas, paths } = data;

  const isAreaRelocating = useCallback(
    (type: AreaType, fpIndex?: number) =>
      relocatingArea?.unitKey === unitKey &&
      relocatingArea.type === type &&
      (type !== 'fp' || relocatingArea.fpIndex === fpIndex),
    [relocatingArea, unitKey]
  );

  const areaClickHandler = useCallback(
    (type: AreaType, fpIndex?: number) =>
      canInteractArea({
        hasHandler: Boolean(onAreaClick),
        isAnyRelocating,
        isThisRelocating: isAreaRelocating(type, fpIndex),
      })
        ? () => onAreaClick?.({ unitKey, type, fpIndex })
        : undefined,
    [onAreaClick, isAnyRelocating, isAreaRelocating, unitKey]
  );

  const handleRotateClick = useCallback(
    (event: L.LeafletMouseEvent) => {
      event.originalEvent.stopImmediatePropagation?.();
      event.originalEvent.stopPropagation();
      onRotateClick?.(unitKey);
    },
    [onRotateClick, unitKey]
  );
  const rotateEventHandlers = useMemo(() => ({ click: handleRotateClick }), [handleRotateClick]);

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
  const hideCenter = useMemo<Coordinate | null>(
    () => (tacticalAreas.hideArea?.length ? calculateCentroid(tacticalAreas.hideArea) : null),
    [tacticalAreas.hideArea]
  );

  const ahaCenter = useMemo<Coordinate | null>(
    () => (tacticalAreas.ammoArea?.length ? calculateCentroid(tacticalAreas.ammoArea) : null),
    [tacticalAreas.ammoArea]
  );

  const reloadCenter = useMemo<Coordinate | null>(
    () => (tacticalAreas.reloadArea?.length ? calculateCentroid(tacticalAreas.reloadArea) : null),
    [tacticalAreas.reloadArea]
  );

  const icon = useMemo(() => createImageIcon(getBatteryImage(category)), [category]);

  // Fallback if no tactical areas
  if (!tacticalAreas.uShapeVertices || tacticalAreas.uShapeVertices.length === 0) {
    return (
      <>
        <RangeCircle center={data.center} radiusNm={rangeNm} color={WEAPON_RANGE_COLOR} />
        <CircleMarker
          center={toLeafletLatLng(data.center)}
          radius={8}
          pathOptions={PATH_OPTIONS_FALLBACK_MARKER}
        >
          <Popup>
            <div className="text-text-primary">
              <strong>{unitName}</strong>
              <br />
              <span className="text-text-secondary">{getWeaponSystemName(category)}</span>
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
      {SINGLE_AREAS.map(({ type, field, label }) => (
        <TacticalPolygon
          key={type}
          type={type}
          vertices={tacticalAreas[field]}
          isRelocating={isAreaRelocating(type)}
          tooltip={<strong>{label}</strong>}
          onClick={areaClickHandler(type)}
        />
      ))}

      {/* Rotation Handle */}
      {onRotateClick && !isAnyRelocating && !isRotating && (
        <CircleMarker
          center={toLeafletLatLng(tacticalAreas.uShapeVertices[0])}
          radius={5}
          pathOptions={PATH_OPTIONS_ROTATE_HANDLE}
          eventHandlers={rotateEventHandlers}
        >
          <Tooltip direction="top">Rotate</Tooltip>
        </CircleMarker>
      )}

      {/* Unit marker and weapon range, anchored on the hide area */}
      {hideCenter && (
        <>
          <Marker position={toLeafletLatLng(hideCenter)} icon={icon}>
            <Tooltip direction="top">
              <strong>{unitName}</strong>
            </Tooltip>
          </Marker>
          <RangeCircle center={hideCenter} radiusNm={rangeNm} color={WEAPON_RANGE_COLOR} />
        </>
      )}

      {ahaCenter && (
        <>
          <Marker position={toLeafletLatLng(ahaCenter)} icon={createImageIcon(ICON_IMAGES.atp)} />
        </>
      )}

      {reloadCenter && (
        <>
          <Marker
            position={toLeafletLatLng(reloadCenter)}
            icon={createImageIcon(ICON_IMAGES.msl)}
          />
        </>
      )}

      {/* Fire Points */}
      {(tacticalAreas.firePoints ?? []).map((firePoint, index) => (
        <TacticalPolygon
          key={`fp-${index}`}
          type="fp"
          vertices={firePoint}
          isRelocating={isAreaRelocating('fp', index)}
          tooltip={<strong>Fire Point {index + 1}</strong>}
          onClick={areaClickHandler('fp', index)}
        />
      ))}

      {/* Detail layers: sub-pixel at low zoom, and the bulk of the draw cost */}
      <ZoomGate minZoom={DETAIL_MIN_ZOOM}>
        {/* Shelter Points */}
        {(tacticalAreas.shelterPoints ?? []).map((point, index) => (
          <CircleMarker
            key={`shelter-${index}`}
            center={toLeafletLatLng(point)}
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
              <Polyline
                key={`path-fp-${index}`}
                positions={positions}
                pathOptions={PATH_OPTIONS_FP}
              >
                <Tooltip direction="top">
                  <strong>HA → FP {index + 1}</strong>
                </Tooltip>
              </Polyline>
            )
        )}
        {reloadPathPositions.map(
          (positions, index) =>
            positions && (
              <Polyline
                key={`path-rl-${index}`}
                positions={positions}
                pathOptions={PATH_OPTIONS_RL}
              >
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
      </ZoomGate>
    </>
  );
});

// ============================================================================
// DeployedMissileSystems Component
// ============================================================================
interface DeployedMissileSystemsProps {
  deployedMissileSystems: Map<string, MissileDeployment>;
  missileSystems: MissileSystems;
  onAreaClick?: (area: RelocatingArea) => void;
  onRotateClick?: (unitKey: string) => void;
  relocatingArea?: RelocatingArea | null;
  rotatingUnitKey?: string | null;
}

export function DeployedMissileSystems({
  deployedMissileSystems,
  missileSystems,
  onAreaClick,
  onRotateClick,
  relocatingArea,
  rotatingUnitKey,
}: DeployedMissileSystemsProps) {
  const isAnyRelocating = Boolean(relocatingArea);

  return (
    <>
      {Array.from(deployedMissileSystems.entries()).map(([unitKey, data]) => (
        <MissileSystemMarker
          key={unitKey}
          unitKey={unitKey}
          data={data}
          rangeNm={
            missileSystems[data.missileSystemType]?.firingUnits[data.unitName]?.weaponRange ?? 0
          }
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
export function MissileSystemPreview({
  uShapeVertices,
  ammoArea,
  hideArea,
  reloadArea,
  firePoints,
  isValid,
}: DeploymentPreview) {
  return (
    <>
      <TacticalPolygon
        type="ushape"
        variant="preview"
        vertices={uShapeVertices}
        isValid={isValid}
      />
      <TacticalPolygon type="aha" variant="preview" vertices={ammoArea} isValid={isValid} />
      <TacticalPolygon type="hide" variant="preview" vertices={hideArea} isValid={isValid} />
      <TacticalPolygon type="reload" variant="preview" vertices={reloadArea} isValid={isValid} />
      {firePoints.map((firePoint, index) => (
        <TacticalPolygon
          key={`preview-fp-${index}`}
          type="fp"
          variant="preview"
          vertices={firePoint}
          isValid={isValid}
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
  return <TacticalPolygon type={areaType} variant="relocate-preview" vertices={vertices} />;
}
