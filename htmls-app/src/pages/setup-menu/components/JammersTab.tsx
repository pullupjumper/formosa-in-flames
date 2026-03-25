import { useState } from 'react';
import type { Jammer, Airbase } from '@/types/setupMenu';
import { BaseMap, AirbaseMarkers, DeployedJammers } from '@/components/Map';
import { isPointInTaiwan } from '@/utils/map';

interface JammersTabProps {
  jammers: Jammer[];
  airbases: Airbase[];
  deployedJammers: Map<number, { lat: number; lng: number }>;
  shouldValidateTaiwanBoundary: boolean;
  onDeployJammer: (index: number, lat: number, lng: number) => void;
  onUndeployJammer: (index: number) => void;
}

export function JammersTab({
  jammers,
  airbases,
  deployedJammers,
  shouldValidateTaiwanBoundary,
  onDeployJammer,
  onUndeployJammer,
}: JammersTabProps) {
  const [selectedUnit, setSelectedUnit] = useState<number | null>(null);
  const [expandedIndex, setExpandedIndex] = useState<number | null>(null);
  const [status, setStatus] = useState('Select an EW unit then click on the map to deploy');
  const [coordinates, setCoordinates] = useState<{ lat: number; lng: number } | null>(null);

  const handleMapClick = (lat: number, lng: number) => {
    setCoordinates({ lat, lng });
    setExpandedIndex(null); // Collapse expanded items when clicking map

    if (selectedUnit !== null) {
      if (shouldValidateTaiwanBoundary && !isPointInTaiwan(lat, lng)) {
        setStatus('⚠️ EW units can only be deployed on Taiwan mainland');
        return;
      }

      const jammer = jammers[selectedUnit];
      onDeployJammer(selectedUnit, lat, lng);
      setStatus(`✓ ${jammer.name} deployed at ${lat.toFixed(4)}°, ${lng.toFixed(4)}°`);
      setSelectedUnit(null);
    }
  };

  const handleUnitSelect = (index: number) => {
    if (deployedJammers.has(index)) {
      // Already deployed, toggle expand
      setExpandedIndex(expandedIndex === index ? null : index);
      return;
    }
    setSelectedUnit(index);
    const jammer = jammers[index];
    setStatus(`${jammer.name} selected - Click map to deploy`);
  };

  const handleUndeploy = (index: number) => {
    const jammer = jammers[index];
    onUndeployJammer(index);
    setExpandedIndex(null);
    setStatus(`${jammer.name} deployment cancelled`);
  };

  return (
    <div className="flex h-full">
      {/* Map Container */}
      <div className="flex-1">
        <BaseMap onMapClick={handleMapClick}>
          <AirbaseMarkers airbases={airbases} />
          <DeployedJammers jammers={jammers} deployedPositions={deployedJammers} />
        </BaseMap>
      </div>

      {/* Controls Panel */}
      <div className="w-80 overflow-y-auto border-l border-dark-border bg-dark-panel p-4">
        <div className="mb-4 text-xs font-bold uppercase tracking-wide text-text-secondary">
          GPS Jammer Deployment
        </div>

        <div className="mb-4">
          <div className="mb-2 text-xs font-semibold">Available Units</div>
          {jammers.length === 0 ? (
            <div className="text-xs italic text-text-secondary">No jammer units available</div>
          ) : (
            <div className="space-y-2">
              {jammers.map((jammer, index) => {
                const isDeployed = deployedJammers.has(index);
                const isSelected = selectedUnit === index;
                const isExpanded = expandedIndex === index;
                const deployment = deployedJammers.get(index);

                return (
                  <div
                    key={index}
                    className={`cursor-pointer rounded-sm border p-2.5 text-xs transition-colors ${
                      isDeployed
                        ? 'border-status-success border-l-4 bg-status-success/10'
                        : isSelected
                          ? 'border-accent-blue bg-accent-blue/20'
                          : 'border-dark-border bg-dark-hover hover:bg-dark-border'
                    }`}
                    onClick={() => handleUnitSelect(index)}
                  >
                    <div className="mb-1 font-semibold">{jammer.name}</div>
                    <div className="text-text-secondary">
                      <div>ZONE: {jammer.zoneName}</div>
                      <div>RANGE: {jammer.radius} NM</div>
                    </div>

                    {isDeployed && deployment && (
                      <div className="mt-2 rounded bg-status-success/10 p-1.5">
                        <div className="text-[11px] text-status-success">
                          ✓ Deployed at {deployment.lat.toFixed(4)}°, {deployment.lng.toFixed(4)}°
                        </div>
                        {isExpanded && (
                          <button
                            className="mt-2 w-full rounded bg-status-danger px-2 py-1 text-[11px] font-semibold text-white hover:bg-red-700"
                            onClick={(e) => {
                              e.stopPropagation();
                              handleUndeploy(index);
                            }}
                          >
                            Cancel Deployment
                          </button>
                        )}
                      </div>
                    )}

                    {isSelected && !isDeployed && (
                      <div className="mt-2 rounded bg-accent-blue/10 p-1.5">
                        <div className="text-[11px] text-accent-blue">Click map to deploy</div>
                      </div>
                    )}
                  </div>
                );
              })}
            </div>
          )}
        </div>

        {/* Status */}
        <div className="rounded-sm border border-dark-border bg-black/30 p-2.5 text-xs">
          {status}
        </div>

        {/* Coordinates Display */}
        {coordinates && (
          <div className="mt-5 font-mono text-[11px] text-text-secondary">
            Latitude: {coordinates.lat.toFixed(6)}°, Longitude: {coordinates.lng.toFixed(6)}°
          </div>
        )}
      </div>
    </div>
  );
}
