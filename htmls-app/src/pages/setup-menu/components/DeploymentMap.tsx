import type { Airbase, DeployedMissileSystemData, Jammer } from '@/types/setupMenu';
import type { Coordinate } from '@/utils/tacticalAreaGenerator';
import {
  BaseMap,
  AirbaseMarkers,
  DeployedMissileSystems,
  MissileSystemPreview,
  AreaRelocatePreview,
  DeployedJammers,
  JammerRelocatePreview,
} from '@/components/Map';
import type { RelocatingArea } from '@/components/Map';
import type { DeploymentPreview } from '../hooks/useDeploymentPreviews';
import type { LatLng } from '../hooks/deploymentMode';

// ============================================================================
// DeploymentMap — the map layer stack for the Deployment tab
// ============================================================================
interface DeploymentMapProps {
  sideName: string;
  airbases: Airbase[];
  jammers: Jammer[];
  deployedSystems: Map<string, DeployedMissileSystemData>;
  deployedJammers: Map<number, LatLng>;

  /** True while some mode owns the next map click; drives cursor and hover */
  isPlacementActive: boolean;
  mousePosition: LatLng | null;

  /** Area currently armed for relocation, highlighted on the map */
  relocatingArea: RelocatingArea | null;
  rotatingUnitKey: string | null;
  /** Jammer index being relocated, null while deploying a fresh one */
  relocatingJammerIndex: number | null;
  /** Jammer whose range circle follows the cursor, null outside jammer modes */
  placingJammerUnit: Jammer | null;

  deployPreview: DeploymentPreview | null;
  rotationPreview: DeploymentPreview | null;
  relocatePreviewVertices: Coordinate[] | null;

  getUnitInfo: (unitKey: string) => { name: string; category: string } | null;
  onMapClick: (lat: number, lng: number) => void;
  onMouseMove: (lat: number, lng: number) => void;
  onAreaClick: (area: RelocatingArea) => void;
  onRotateClick: (unitKey: string) => void;
  onAirbaseClick: (index: number) => void;
  onJammerRelocateClick: (index: number) => void;
}

export function DeploymentMap({
  sideName,
  airbases,
  jammers,
  deployedSystems,
  deployedJammers,
  isPlacementActive,
  mousePosition,
  relocatingArea,
  rotatingUnitKey,
  relocatingJammerIndex,
  placingJammerUnit,
  deployPreview,
  rotationPreview,
  relocatePreviewVertices,
  getUnitInfo,
  onMapClick,
  onMouseMove,
  onAreaClick,
  onRotateClick,
  onAirbaseClick,
  onJammerRelocateClick,
}: DeploymentMapProps) {
  return (
    <BaseMap
      onMapClick={onMapClick}
      onMouseMove={isPlacementActive ? onMouseMove : undefined}
      cursorStyle={isPlacementActive ? 'crosshair' : undefined}
      sideName={sideName}
    >
      <AirbaseMarkers airbases={airbases} onAirbaseClick={onAirbaseClick} />
      <DeployedMissileSystems
        deployedSystems={deployedSystems}
        getUnitInfo={getUnitInfo}
        onAreaClick={onAreaClick}
        onRotateClick={onRotateClick}
        relocatingArea={relocatingArea}
        rotatingUnitKey={rotatingUnitKey}
      />
      <DeployedJammers
        jammers={jammers}
        deployedPositions={deployedJammers}
        relocatingIndex={relocatingJammerIndex}
        onRelocateClick={onJammerRelocateClick}
      />

      {placingJammerUnit && mousePosition && (
        <JammerRelocatePreview radius={placingJammerUnit.radius} position={mousePosition} />
      )}
      {relocatePreviewVertices && relocatingArea && (
        <AreaRelocatePreview vertices={relocatePreviewVertices} areaType={relocatingArea.type} />
      )}
      {rotationPreview && <MissileSystemPreview {...rotationPreview} />}
      {deployPreview && <MissileSystemPreview {...deployPreview} />}
    </BaseMap>
  );
}
