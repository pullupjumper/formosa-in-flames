import type { AirbaseDeploymentDescriptor, GNSSJammerDescriptor, Signal } from '@/types/generated';
import type { Coordinate } from '@/types/geo';
import type { MissileDeployment } from '@/types/deployment';
import {
  BaseMap,
  AirbaseMarkers,
  SignalMarkers,
  C2Layers,
  DeployedMissileSystems,
  MissileSystemPreview,
  AreaRelocatePreview,
  DeployedJammers,
  JammerRelocatePreview,
} from '@/components/map';
import type { RelocatingArea } from '@/types/deployment';
import type { C2MapLayers } from '../../logic/c2Nodes';
import type { DeploymentPreview } from '../../hooks/useDeploymentPreviews';

// ============================================================================
// DeploymentMap — the map layer stack for the Deployment tab
// ============================================================================
interface DeploymentMapProps {
  sideName: string;
  airbases: AirbaseDeploymentDescriptor[];
  jammers: GNSSJammerDescriptor[];
  deployedMissileSystems: Map<string, MissileDeployment>;
  weaponRanges: ReadonlyMap<string, number>;
  deployedJammers: Map<number, Coordinate>;
  /** Detected signals shown as suspected C2 markers */
  signals: Signal[];
  /** C2 operating zones and C2 / SAM / radar markers */
  c2Layers: C2MapLayers;

  /** True while some mode owns the next map click; drives cursor and hover */
  isPlacementActive: boolean;
  mousePosition: Coordinate | null;

  /** Area currently armed for relocation, highlighted on the map */
  relocatingArea: RelocatingArea | null;
  rotatingUnitKey: string | null;
  /** Jammer index being relocated, null while deploying a fresh one */
  relocatingJammerIndex: number | null;
  /** Jammer whose range circle follows the cursor, null outside jammer modes */
  placingJammerUnit: GNSSJammerDescriptor | null;

  deployPreview: DeploymentPreview | null;
  rotationPreview: DeploymentPreview | null;
  relocatePreviewVertices: Coordinate[] | null;

  onMapClick: (position: Coordinate) => void;
  onMouseMove: (position: Coordinate) => void;
  onAreaClick: (area: RelocatingArea) => void;
  onRotateClick: (unitKey: string) => void;
  onJammerRelocateClick: (index: number) => void;
}

export function DeploymentMap({
  sideName,
  airbases,
  jammers,
  deployedMissileSystems,
  weaponRanges,
  deployedJammers,
  signals,
  c2Layers,
  isPlacementActive,
  mousePosition,
  relocatingArea,
  rotatingUnitKey,
  relocatingJammerIndex,
  placingJammerUnit,
  deployPreview,
  rotationPreview,
  relocatePreviewVertices,
  onMapClick,
  onMouseMove,
  onAreaClick,
  onRotateClick,
  onJammerRelocateClick,
}: DeploymentMapProps) {
  return (
    <BaseMap
      onMapClick={onMapClick}
      onMouseMove={isPlacementActive ? onMouseMove : undefined}
      cursorStyle={isPlacementActive ? 'crosshair' : undefined}
      sideName={sideName}
    >
      <C2Layers layers={c2Layers} />
      <AirbaseMarkers airbases={airbases} />
      <DeployedMissileSystems
        deployedMissileSystems={deployedMissileSystems}
        weaponRanges={weaponRanges}
        onAreaClick={onAreaClick}
        onRotateClick={onRotateClick}
        relocatingArea={relocatingArea}
        rotatingUnitKey={rotatingUnitKey}
      />
      <SignalMarkers signals={signals} />
      <DeployedJammers
        jammers={jammers}
        deployedPositions={deployedJammers}
        relocatingIndex={relocatingJammerIndex}
        onRelocateClick={onJammerRelocateClick}
      />

      {placingJammerUnit && mousePosition && (
        <JammerRelocatePreview radius={placingJammerUnit.radiusNm} position={mousePosition} />
      )}
      {relocatePreviewVertices && relocatingArea && (
        <AreaRelocatePreview vertices={relocatePreviewVertices} areaType={relocatingArea.type} />
      )}
      {rotationPreview && <MissileSystemPreview {...rotationPreview} />}
      {deployPreview && <MissileSystemPreview {...deployPreview} />}
    </BaseMap>
  );
}
