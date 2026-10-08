import { useState, type ReactNode } from 'react';

// ============================================================================
// InfoCard — read-only card with the deployable cards' look
// ============================================================================
interface InfoCardProps {
  name: string;
  icon?: ReactNode;
  details?: ReactNode;
  /** Shown under the body while the card is clicked open (e.g. a DetailsBox) */
  foldedDetails?: ReactNode;
}

export function InfoCard({ name, icon, details, foldedDetails }: InfoCardProps) {
  const [isOpen, setIsOpen] = useState(false);

  return (
    <div
      className={`rounded-xs border-2 border-aip-card-border bg-aip-card text-xs ${
        foldedDetails ? 'cursor-pointer transition-colors hover:border-aip-link' : ''
      }`}
      onClick={foldedDetails ? () => setIsOpen((previous) => !previous) : undefined}
    >
      <div className="flex items-start gap-2.5 p-2.5">
        {icon}
        <div className="min-w-0 flex-1">
          <div className="mb-1 text-[13px] text-text-primary">{name}</div>
          {details && (
            <div className="text-[11px] leading-snug text-text-secondary [overflow-wrap:anywhere]">
              {details}
            </div>
          )}
        </div>
      </div>
      {isOpen && foldedDetails && <div className="px-2.5 pb-2.5">{foldedDetails}</div>}
    </div>
  );
}
