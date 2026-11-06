import type { TacticalAreaLayout } from '@/types/generated';
import { memo, useMemo, useCallback } from 'react';
import { CircleMarker, Polyline, Tooltip, Marker } from 'react-leaflet';
import L from 'leaflet';
import type { LatLngExpression } from 'leaflet';
import type { Coordinate } from '@/types/geo';
import type { AreaType, MissileDeployment, RelocatingArea } from '@/types/deployment';
import { getAreaColor } from '@/constants/deployment';
import { CONFIG } from '@/constants/controlPanel';
import { calculateCentroid, toLeafletLatLng, toLeafletPositions } from '@/utils/geo';
import { TacticalPolygon, RangeCircle, ZoomGate, DETAIL_MIN_ZOOM } from './primitives';
import { createImageIcon, ICON_IMAGES, getBatteryImage } from './icons';
import { MapPopup } from './MapPopup';
import type { DeploymentPreview } from '@/utils/deploymentGeometry';

/** Weapon system display name for a missile system type key. */
function getWeaponSystemName(missileSystemType: string): string {
  return CONFIG.WEAPON_NAMES[missileSystemType] || missileSystemType.toUpperCase();
}

/**
 * Whether a click on a tactical area should do anything: nothing while another
 * area is armed for relocation, everything when idle.
 */
interface CanInteractAreaParams {
  hasHandler: boolean;
  isAnyRelocating: boolean;
  isThisRelocating: boolean;
}

function canInteractArea({
  hasHandler,
  isAnyRelocating,
  isThisRelocating,
}: CanInteractAreaParams): boolean {
  if (!hasHandler) return false;
  if (!isAnyRelocating) return true;
  return isThisRelocating;
}

// ============================================================================
// COLORS
// ============================================================================
const WEAPON_RANGE_COLOR = '#ff4444';
const SHELTER_COLOR = '#c084fc';

// ============================================================================
// Static pathOptions (never re-created)
// ============================================================================
const PATH_OPTIONS_HA = { color: getAreaColor('hide'), weight: 2, opacity: 0.7, dashArray: '5, 5' };
const PATH_OPTIONS_ATP = { color: getAreaColor('atp'), weight: 2, opacity: 0.7, dashArray: '5, 5' };
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
  field: keyof Pick<TacticalAreaLayout, 'uShapeVertices' | 'atpArea' | 'hideArea' | 'reloadArea'>;
  label: string;
}

const SINGLE_AREAS: readonly SingleArea[] = [
  { type: 'ushape', field: 'uShapeVertices', label: 'U-Shape Area' },
  { type: 'atp', field: 'atpArea', label: 'Ammunition Transfer Point (ATP)' },
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
  const { unitname, missileSystemType, tacticalAreas, paths } = data;

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
  const atpPathPositions = useMemo(() => toPathPositions(paths.ATP?.waypoints), [paths.ATP]);
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

  const atpCenter = useMemo<Coordinate | null>(
    () => (tacticalAreas.atpArea?.length ? calculateCentroid(tacticalAreas.atpArea) : null),
    [tacticalAreas.atpArea]
  );

  const icon = useMemo(
    () => createImageIcon(getBatteryImage(missileSystemType)),
    [missileSystemType]
  );

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
          <MapPopup
            name={unitname}
            subtitle={getWeaponSystemName(missileSystemType)}
            rows={[
              { label: 'Latitude', value: `${data.center.latitude.toFixed(6)}°` },
              { label: 'Longitude', value: `${data.center.longitude.toFixed(6)}°` },
              { label: 'Angle', value: `${data.openingAngle}°` },
              { label: 'Range', value: `${rangeNm} NM` },
            ]}
          />
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
              <strong>{unitname}</strong>
            </Tooltip>
          </Marker>
          <RangeCircle center={hideCenter} radiusNm={rangeNm} color={WEAPON_RANGE_COLOR} />
        </>
      )}

      {atpCenter && (
        <>
          <Marker position={toLeafletLatLng(atpCenter)} icon={createImageIcon(ICON_IMAGES.atp)} />
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
        {atpPathPositions && (
          <Polyline positions={atpPathPositions} pathOptions={PATH_OPTIONS_ATP}>
            <Tooltip direction="top">
              <strong>RL → ATP</strong>
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
  /** Weapon range in NM by unit key; units without an entry draw no range circle */
  weaponRanges: ReadonlyMap<string, number>;
  onAreaClick?: (area: RelocatingArea) => void;
  onRotateClick?: (unitKey: string) => void;
  relocatingArea?: RelocatingArea | null;
  rotatingUnitKey?: string | null;
}

export function DeployedMissileSystems({
  deployedMissileSystems,
  weaponRanges,
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
          rangeNm={weaponRanges.get(unitKey) ?? 0}
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
  atpArea,
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
      <TacticalPolygon type="atp" variant="preview" vertices={atpArea} isValid={isValid} />
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
