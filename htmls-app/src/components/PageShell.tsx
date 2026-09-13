import type { ReactNode } from 'react';

export interface PageTab<TabId extends string> {
  id: TabId;
  label: string;
}

interface PageShellProps<TabId extends string> {
  /** Highlighted part of the top bar, e.g. the side name. */
  title: string;
  /** Muted text after the title, rendered as `TITLE / SUBTITLE`. */
  subtitle?: string;
  tabs?: readonly PageTab<TabId>[];
  activeTab?: TabId;
  onTabChange?: (tabId: TabId) => void;
  /** Extra classes for the content area below the tab strip. */
  contentClassName?: string;
  children: ReactNode;
}

/**
 * Full-height page frame shared by every CMO panel: top bar, optional tab
 * strip, and a flex-1 content area.
 */
export function PageShell<TabId extends string>({
  title,
  subtitle,
  tabs,
  activeTab,
  onTabChange,
  contentClassName = 'relative flex-1 overflow-hidden',
  children,
}: PageShellProps<TabId>) {
  return (
    <div className="flex h-screen flex-col">
      <div className="flex h-12.5 items-center justify-between border-b border-dark-border bg-dark-panel px-5">
        <div className="text-sm font-medium text-text-secondary">
          <span className="text-text-primary">{title}</span>
          {subtitle && ` / ${subtitle}`}
        </div>
      </div>

      {tabs && tabs.length > 0 && (
        <div className="flex border-b border-dark-border bg-dark-bg px-5">
          {tabs.map((tab) => (
            <button
              key={tab.id}
              className={`border-b-[3px] px-4 py-3 text-[13px] font-semibold uppercase tracking-wide transition-colors ${
                activeTab === tab.id
                  ? 'border-accent-blue text-accent-blue'
                  : 'border-transparent text-text-secondary hover:text-text-primary'
              }`}
              onClick={() => onTabChange?.(tab.id)}
            >
              {tab.label}
            </button>
          ))}
        </div>
      )}

      <div className={contentClassName}>{children}</div>
    </div>
  );
}
