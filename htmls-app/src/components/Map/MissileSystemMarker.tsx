import { Circle, CircleMarker, Polygon, Polyline, Popup } from 'react-leaflet';
import type { LatLngExpression } from 'leaflet';
import type { DeployedMissileSystemData } from '@/types/setupMenu';
import { CONFIG } from '@/types/setupMenu';
import { getWeaponSystemName } from '@/utils/map';

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

// ============================================================================
// Helper Functions
// ============================================================================
function coordinatesToLatLng(
  coords: { latitude: number; longitude: number }[]
): LatLngExpression[] {
  return coords.map((c) => [c.latitude, c.longitude] as LatLngExpression);
}

function calculateCenter(
  coords: { latitude: number; longitude: number }[]
): { lat: number; lng: number } {
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
}

export function MissileSystemMarker({ data }: MissileSystemMarkerProps) {
  const { unitName, category, tacticalAreas, paths } = data;
  const rangeNM = CONFIG.WEAPON_RANGES[category] || 100;
  const radiusMeters = rangeNM * 1852;

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
            fillOpacity: 0.08,
            weight: 2,
            opacity: 0.5,
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
        interactive={false}
        pathOptions={{
          color: COLORS.USHAPE,
          fillColor: COLORS.USHAPE,
          fillOpacity: 0.15,
          weight: 2,
        }}
      />

      {/* Ammo Area */}
      {tacticalAreas.ammoArea && tacticalAreas.ammoArea.length > 0 && (
        <Polygon
          positions={coordinatesToLatLng(tacticalAreas.ammoArea)}
          pathOptions={{
            color: COLORS.AMMO_AREA,
            fillColor: COLORS.AMMO_AREA,
            fillOpacity: 0.3,
            weight: 2,
          }}
        >
          <Popup>
            <strong>Ammo Holding Area (AHA)</strong>
            <br />
            {unitName}
          </Popup>
        </Polygon>
      )}

      {/* Hide Area */}
      {tacticalAreas.hideArea && tacticalAreas.hideArea.length > 0 && (
        <>
          <Polygon
            positions={coordinatesToLatLng(tacticalAreas.hideArea)}
            pathOptions={{
              color: COLORS.HIDE_AREA,
              fillColor: COLORS.HIDE_AREA,
              fillOpacity: 0.3,
              weight: 2,
            }}
          >
            <Popup>
              <strong>Hide Area (HA)</strong>
              <br />
              {unitName}
            </Popup>
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
              <Popup>
                <strong>Hide Area Center</strong>
                <br />
                {unitName}
              </Popup>
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
                fillOpacity: 0.08,
                weight: 2,
                opacity: 0.5,
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
          pathOptions={{
            color: COLORS.RELOAD_AREA,
            fillColor: COLORS.RELOAD_AREA,
            fillOpacity: 0.3,
            weight: 2,
          }}
        >
          <Popup>
            <strong>Reload Area (RL)</strong>
            <br />
            {unitName}
          </Popup>
        </Polygon>
      )}

      {/* Fire Points */}
      {tacticalAreas.firePoints &&
        tacticalAreas.firePoints.map((fp, i) => (
          <Polygon
            key={`fp-${i}`}
            positions={coordinatesToLatLng(fp)}
            pathOptions={{
              color: COLORS.FIRE_POINT,
              fillColor: COLORS.FIRE_POINT,
              fillOpacity: 0.3,
              weight: 2,
            }}
          >
            <Popup>
              <strong>Fire Point {i + 1}</strong>
              <br />
              {unitName}
            </Popup>
          </Polygon>
        ))}

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
}

export function DeployedMissileSystems({
  deployedSystems,
}: DeployedMissileSystemsProps) {
  return (
    <>
      {Array.from(deployedSystems.entries()).map(([unitKey, data]) => (
        <MissileSystemMarker key={unitKey} unitKey={unitKey} data={data} />
      ))}
    </>
  );
}
