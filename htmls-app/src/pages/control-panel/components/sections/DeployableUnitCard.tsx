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
  idle: 'border-aip-card-border hover:border-aip-link',
  selected: 'border-aip-link',
  deployed: 'border-aip-card-border',
};

const BUTTON_BASE = 'rounded-xs border px-2 py-0.5 text-[11px] transition-colors';

/**
 * Three-state card: idle, selected (awaiting a map click), or deployed.
 * The state shows in a status strip under the body; deployed cards reveal
 * their Cancel Deployment button only when expanded.
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
      className={`cursor-pointer rounded-xs border-2 bg-aip-card text-xs transition-colors ${
        isDeployed ? CARD_TONES.deployed : isSelected ? CARD_TONES.selected : CARD_TONES.idle
      }`}
      onClick={onSelect}
    >
      <div className="flex items-start gap-2.5 p-2.5">
        {icon}
        <div className="min-w-0 flex-1">
          <div className="mb-1 text-[13px] text-text-primary">{name}</div>
          <div className="text-[11px] leading-snug text-text-secondary">{details}</div>
        </div>
      </div>

      {isDeployed && (
        <StatusStrip tone="deployed" label={deployedSummary}>
          {isExpanded && (
            <button
              className={`${BUTTON_BASE} border-status-danger text-status-danger hover:bg-status-danger hover:text-white`}
              onClick={(event) => {
                event.stopPropagation();
                onCancelDeployment();
              }}
            >
              Cancel Deployment
            </button>
          )}
        </StatusStrip>
      )}

      {isSelected && !isDeployed && (
        <StatusStrip tone="selected" label="Click map to deploy">
          <button
            className={`${BUTTON_BASE} border-aip-card-border text-text-secondary hover:border-aip-link hover:text-text-primary`}
            onClick={(event) => {
              event.stopPropagation();
              onCancelSelection();
            }}
          >
            Cancel Selection
          </button>
        </StatusStrip>
      )}
    </div>
  );
}

// ============================================================================
// StatusStrip — full-width row under the card body: status dot, text, action
// ============================================================================
const STRIP_DOT = {
  deployed: 'bg-status-success',
  selected: 'bg-aip-link',
};

interface StatusStripProps {
  tone: keyof typeof STRIP_DOT;
  label: ReactNode;
  children?: ReactNode;
}

function StatusStrip({ tone, label, children }: StatusStripProps) {
  return (
    <div className="flex items-center gap-2 border-t border-aip-border bg-aip-pane/60 px-2.5 py-1.5">
      <span aria-hidden="true" className={`h-1.5 w-1.5 shrink-0 rounded-full ${STRIP_DOT[tone]}`} />
      <span className="min-w-0 flex-1 text-[11px] text-text-secondary">{label}</span>
      {children}
    </div>
  );
}
