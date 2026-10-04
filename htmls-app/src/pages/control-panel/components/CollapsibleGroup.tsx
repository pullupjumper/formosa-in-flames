import type { ReactNode } from 'react';

// ============================================================================
// CollapsibleGroup — sidebar section whose header collapses its contents
// ============================================================================
interface CollapsibleGroupProps {
  /** `aip` is the control panel's plain bold heading with a link-blue counter */
  variant?: 'default' | 'aip';
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
  variant = 'default',
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
        className={`mb-2 flex w-full items-center gap-2 text-left transition-colors ${
          variant === 'aip'
            ? 'px-0 py-1 text-[13px] font-bold text-text-primary hover:text-aip-link'
            : 'border-l-[3px] border-accent-blue bg-accent-blue/15 px-2 py-2 text-xs font-bold text-accent-blue hover:bg-accent-blue/25'
        }`}
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
          className={`font-mono font-semibold ${
            variant === 'aip' ? 'text-[11px]' : 'text-[10px]'
          } ${
            isComplete
              ? 'text-status-success'
              : variant === 'aip'
                ? 'text-aip-link'
                : 'text-accent-blue/70'
          }`}
        >
          {deployedCount}/{totalCount}
        </span>
      </button>

      {!isCollapsed && <div className="space-y-2">{children}</div>}
    </div>
  );
}
