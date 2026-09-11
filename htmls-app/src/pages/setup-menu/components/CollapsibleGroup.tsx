import type { ReactNode } from 'react';

// ============================================================================
// CollapsibleGroup — sidebar section whose header collapses its contents
// ============================================================================
interface CollapsibleGroupProps {
  title: string;
  deployedCount: number;
  totalCount: number;
  isCollapsed: boolean;
  onToggle: () => void;
  children: ReactNode;
}

/**
 * Sidebar section with a clickable header. The deployed/total counter stays on
 * the header so a collapsed group still conveys progress.
 */
export function CollapsibleGroup({
  title,
  deployedCount,
  totalCount,
  isCollapsed,
  onToggle,
  children,
}: CollapsibleGroupProps) {
  const isComplete = totalCount > 0 && deployedCount === totalCount;

  return (
    <div>
      <button
        type="button"
        aria-expanded={!isCollapsed}
        className="mb-2 flex w-full items-center gap-2 border-l-[3px] border-accent-blue bg-accent-blue/15 px-2 py-2 text-left text-xs font-bold text-accent-blue transition-colors hover:bg-accent-blue/25"
        onClick={onToggle}
      >
        <span
          aria-hidden="true"
          className={`inline-block leading-none transition-transform duration-150 ${
            isCollapsed ? '-rotate-90' : ''
          }`}
        >
          ▾
        </span>
        <span className="flex-1">{title}</span>
        <span
          className={`font-mono text-[10px] font-semibold ${
            isComplete ? 'text-status-success' : 'text-accent-blue/70'
          }`}
        >
          {deployedCount}/{totalCount}
        </span>
      </button>

      {!isCollapsed && <div className="space-y-2">{children}</div>}
    </div>
  );
}
