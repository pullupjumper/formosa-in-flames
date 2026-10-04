import type { ReactNode } from 'react';

// ============================================================================
// DeployableUnitCard — shared sidebar card for jammers and missile systems
// ============================================================================
interface DeployableUnitCardProps {
  name: string;
  /** Optional symbol shown left of the name and details */
  icon?: ReactNode;
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

const CARD_TONES = {
  idle: 'border-aip-card-border bg-aip-card hover:border-aip-link',
  selected: 'border-aip-link bg-aip-card',
  deployed: 'border-aip-card-border border-l-4 border-l-status-success bg-aip-card',
};

/**
 * Three-state card: idle, selected (awaiting a map click), or deployed.
 * Deployed cards reveal their Cancel Deployment button only when expanded.
 */
export function DeployableUnitCard({
  name,
  icon,
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
      className={`cursor-pointer border p-2.5 text-xs transition-colors ${
        isDeployed ? CARD_TONES.deployed : isSelected ? CARD_TONES.selected : CARD_TONES.idle
      }`}
      onClick={onSelect}
    >
      <div className="flex items-start gap-2.5">
        {icon}
        <div className="min-w-0 flex-1">
          <div className="mb-1 font-semibold">{name}</div>
          <div className="text-text-secondary">{details}</div>
        </div>
      </div>

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
