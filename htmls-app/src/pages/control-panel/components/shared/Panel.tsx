import type { ReactNode } from 'react';

// ============================================================================
// Panel — card for the control panel's left column
// ============================================================================
interface PanelProps {
  title: string;
  /** Right-aligned header text, e.g. a deployed/total counter */
  badge?: ReactNode;
  /** Marks the header; the sections inside decide what stays read-only */
  locked?: boolean;
  children: ReactNode;
}

/** Always fully expanded; the column scrolls as a whole, never the panel. */
export function Panel({ title, badge, locked = false, children }: PanelProps) {
  return (
    <section className="shrink-0 border border-aip-border bg-aip-panel">
      <div className="flex items-center gap-2 px-4 py-3">
        <span className="flex-1 text-[13px] font-bold text-text-primary">{title}</span>
        {locked && (
          <span className="font-mono text-[11px] uppercase text-status-warning">Locked</span>
        )}
        {badge && <span className="font-mono text-[11px] text-aip-link">{badge}</span>}
      </div>
      <div className="border-t border-aip-border p-3">{children}</div>
    </section>
  );
}
