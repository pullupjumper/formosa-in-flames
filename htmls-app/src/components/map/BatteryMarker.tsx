import type { MovementPath, TacticalAreaLayout } from '@/types/generated';
import { memo, useMemo, useCallback } from 'react';
import { CircleMarker, Polyline, Tooltip, Marker } from 'react-leaflet';
import L from 'leaflet';
import type { LatLngExpression } from 'leaflet';
import type { Coordinate } from '@/types/geo';
import type { AreaType, DeployedBattery, RelocatingArea } from '@/types/deployment';
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
// AREA TABLE — the squares of each position type; fire points are labelled by number
// ============================================================================
interface SquareArea {
  type: Exclude<AreaType, 'ushape' | 'fp'>;
  field: keyof Pick<TacticalAreaLayout, 'ATP' | 'HA' | 'RL'>;
  label: string;
}

const SQUARE_AREAS: readonly SquareArea[] = [
  { type: 'atp', field: 'ATP', label: 'Ammunition Transfer Point (ATP)' },
  { type: 'hide', field: 'HA', label: 'Hide Area (HA)' },
  { type: 'reload', field: 'RL', label: 'Reload Area (RL)' },
];

/** Leaflet positions for a path, or null when it has fewer than two waypoints */
function toPathPositions(waypoints: Coordinate[] | undefined): LatLngExpression[] | null {
  return waypoints && waypoints.length > 1 ? toLeafletPositions(waypoints) : null;
}

/** Leaflet positions for each path of a list, null for the ones too short to draw */
function toPathPositionsList(paths: MovementPath[] | undefined): (LatLngExpression[] | null)[] {
  return (paths ?? []).map((path) => toPathPositions(path?.waypoints));
}

// ============================================================================
// BatteryMarker Component
// ============================================================================
interface BatteryMarkerProps {
  batteryName: string;
  data: DeployedBattery;
  /** Weapon range of this unit's launcher, in NM */
  rangeNm: number;
  onAreaClick?: (area: RelocatingArea) => void;
  onRotateClick?: (batteryName: string) => void;
  /** Only the relocatingArea relevant to THIS unit (or null) */
  relocatingArea?: RelocatingArea | null;
  /** Whether ANY unit is currently in relocating mode */
  isAnyRelocating?: boolean;
  isRotating?: boolean;
}

export const BatteryMarker = memo(function BatteryMarker({
  batteryName,
  data,
  rangeNm,
  onAreaClick,
  onRotateClick,
  relocatingArea,
  isAnyRelocating = false,
  isRotating,
}: BatteryMarkerProps) {
  const { name, missileSystemType, tacticalAreas, paths } = data;

  const isAreaRelocating = useCallback(
    (type: AreaType, index = 0) =>
      relocatingArea?.batteryName === batteryName &&
      relocatingArea.type === type &&
      (relocatingArea.index ?? 0) === index,
    [relocatingArea, batteryName]
  );

  const areaClickHandler = useCallback(
    (type: AreaType, index = 0) =>
      canInteractArea({
        hasHandler: Boolean(onAreaClick),
        isAnyRelocating,
        isThisRelocating: isAreaRelocating(type, index),
      })
        ? () => onAreaClick?.({ batteryName, type, index })
        : undefined,
    [onAreaClick, isAnyRelocating, isAreaRelocating, batteryName]
  );

  const handleRotateClick = useCallback(
    (event: L.LeafletMouseEvent) => {
      event.originalEvent.stopImmediatePropagation?.();
      event.originalEvent.stopPropagation();
      onRotateClick?.(batteryName);
    },
    [onRotateClick, batteryName]
  );
  const rotateEventHandlers = useMemo(() => ({ click: handleRotateClick }), [handleRotateClick]);

  // Path positions (null when the path has fewer than two waypoints)
  const haPathPositions = useMemo(() => toPathPositionsList(paths.HA), [paths.HA]);
  const atpPathPositions = useMemo(() => toPathPositionsList(paths.ATP), [paths.ATP]);
  const firePointPathPositions = useMemo(() => toPathPositionsList(paths.FP), [paths.FP]);
  const reloadPathPositions = useMemo(
    () => toPathPositionsList(data.reloadReturnPaths),
    [data.reloadReturnPaths]
  );
  const shrlPathPositions = useMemo(() => toPathPositionsList(paths.SHRL), [paths.SHRL]);

  // Hide area center anchors the unit marker and its weapon range circle
  const hideCenter = useMemo<Coordinate | null>(
    () => (tacticalAreas.HA[0]?.length ? calculateCentroid(tacticalAreas.HA[0]) : null),
    [tacticalAreas.HA]
  );

  const atpCenter = useMemo<Coordinate | null>(
    () => (tacticalAreas.ATP[0]?.length ? calculateCentroid(tacticalAreas.ATP[0]) : null),
    [tacticalAreas.ATP]
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
            name={name}
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
      <TacticalPolygon
        type="ushape"
        vertices={tacticalAreas.uShapeVertices}
        isRelocating={isAreaRelocating('ushape')}
        tooltip={<strong>U-Shape Area</strong>}
        onClick={areaClickHandler('ushape')}
      />
      {SQUARE_AREAS.flatMap(({ type, field, label }) =>
        tacticalAreas[field].map((vertices, index) => (
          <TacticalPolygon
            key={`${type}-${index}`}
            type={type}
            vertices={vertices}
            isRelocating={isAreaRelocating(type, index)}
            tooltip={<strong>{label}</strong>}
            onClick={areaClickHandler(type, index)}
          />
        ))
      )}

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
              <strong>{name}</strong>
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
      {tacticalAreas.FP.map((firePoint, index) => (
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
        {haPathPositions.map(
          (positions, index) =>
            positions && (
              <Polyline
                key={`path-ha-${index}`}
                positions={positions}
                pathOptions={PATH_OPTIONS_HA}
              >
                <Tooltip direction="top">
                  <strong>RL → HA</strong>
                </Tooltip>
              </Polyline>
            )
        )}
        {atpPathPositions.map(
          (positions, index) =>
            positions && (
              <Polyline
                key={`path-atp-${index}`}
                positions={positions}
                pathOptions={PATH_OPTIONS_ATP}
              >
                <Tooltip direction="top">
                  <strong>RL → ATP</strong>
                </Tooltip>
              </Polyline>
            )
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
        {shrlPathPositions.map(
          (positions, index) =>
            positions && (
              <Polyline
                key={`path-shrl-${index}`}
                positions={positions}
                pathOptions={PATH_OPTIONS_SHRL}
              >
                <Tooltip direction="top">
                  <strong>Shelter → RL (SHRL)</strong>
                </Tooltip>
              </Polyline>
            )
        )}
      </ZoomGate>
    </>
  );
});

// ============================================================================
// DeployedBatteries Component
// ============================================================================
interface DeployedBatteriesProps {
  deployedBatteries: Map<string, DeployedBattery>;
  /** Weapon range in NM by battery name; units without an entry draw no range circle */
  weaponRanges: ReadonlyMap<string, number>;
  onAreaClick?: (area: RelocatingArea) => void;
  onRotateClick?: (batteryName: string) => void;
  relocatingArea?: RelocatingArea | null;
  rotatingBatteryName?: string | null;
}

export function DeployedBatteries({
  deployedBatteries,
  weaponRanges,
  onAreaClick,
  onRotateClick,
  relocatingArea,
  rotatingBatteryName,
}: DeployedBatteriesProps) {
  const isAnyRelocating = Boolean(relocatingArea);

  return (
    <>
      {Array.from(deployedBatteries.entries()).map(([batteryName, data]) => (
        <BatteryMarker
          key={batteryName}
          batteryName={batteryName}
          data={data}
          rangeNm={weaponRanges.get(batteryName) ?? 0}
          onAreaClick={onAreaClick}
          onRotateClick={onRotateClick}
          relocatingArea={relocatingArea?.batteryName === batteryName ? relocatingArea : null}
          isAnyRelocating={isAnyRelocating}
          isRotating={rotatingBatteryName === batteryName}
        />
      ))}
    </>
  );
}

// ============================================================================
// BatteryPreview Component
// ============================================================================
export function BatteryPreview({
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
