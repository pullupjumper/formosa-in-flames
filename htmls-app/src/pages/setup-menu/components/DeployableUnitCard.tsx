import type { ReactNode } from 'react';

// ============================================================================
// DeployableUnitCard — shared sidebar card for jammers and missile systems
// ============================================================================
interface DeployableUnitCardProps {
  name: string;
  /** Secondary lines describing the unit (zone, range, weapon system, ...) */
  details: ReactNode;
  /** Line shown inside the green block once the unit is on the map */
  deployedSummary: ReactNode;
  isDeployed: boolean;
  isSelected: boolean;
  isExpanded: boolean;
  onSelect: () => void;
  onCancelDeployment: () => void;
  onCancelSelection: () => void;
}

/**
 * Three-state card: idle, selected (awaiting a map click), or deployed.
 * Deployed cards reveal their Cancel Deployment button only when expanded.
 */
export function DeployableUnitCard({
  name,
  details,
  deployedSummary,
  isDeployed,
  isSelected,
  isExpanded,
  onSelect,
  onCancelDeployment,
  onCancelSelection,
}: DeployableUnitCardProps) {
  return (
    <div
      className={`cursor-pointer rounded-sm border p-2.5 text-xs transition-colors ${
        isDeployed
          ? 'border-status-success border-l-4 bg-status-success/10'
          : isSelected
            ? 'border-accent-blue bg-accent-blue/20'
            : 'border-dark-border bg-dark-hover hover:bg-dark-border'
      }`}
      onClick={onSelect}
    >
      <div className="mb-1 font-semibold">{name}</div>
      <div className="text-text-secondary">{details}</div>

      {isDeployed && (
        <div className="mt-2 rounded bg-status-success/10 p-1.5">
          <div className="text-[11px] text-status-success">{deployedSummary}</div>
          {isExpanded && (
            <button
              className="mt-2 w-full rounded bg-status-danger px-2 py-1 text-[11px] font-semibold text-white hover:bg-red-700"
              onClick={(e) => {
                e.stopPropagation();
                onCancelDeployment();
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
          <button
            className="mt-2 w-full rounded bg-dark-border px-2 py-1 text-[11px] font-semibold text-text-secondary hover:bg-dark-hover"
            onClick={(e) => {
              e.stopPropagation();
              onCancelSelection();
            }}
          >
            Cancel Selection
          </button>
        </div>
      )}
    </div>
  );
}
