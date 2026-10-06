import type { ReactNode } from 'react';

// ============================================================================
// InfoCard — read-only card with the deployable cards' look
// ============================================================================
interface InfoCardProps {
  name: string;
  icon?: ReactNode;
  details: ReactNode;
}

export function InfoCard({ name, icon, details }: InfoCardProps) {
  return (
    <div className="border border-aip-card-border bg-aip-card p-2.5 text-xs">
      <div className="flex items-start gap-2.5">
        {icon}
        <div className="min-w-0 flex-1">
          <div className="mb-1 font-semibold">{name}</div>
          <div className="text-text-secondary">{details}</div>
        </div>
      </div>
    </div>
  );
}
