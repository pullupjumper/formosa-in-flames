import type { ReactNode } from 'react';

export interface PageTab<TabId extends string> {
  id: TabId;
  label: string;
}

interface PageShellProps<TabId extends string> {
  /** Highlighted part of the top bar, e.g. the side name. */
  title: string;
  /** Text centred in the green banner above the title, e.g. the panel name. */
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
      <div className="relative z-10 shadow-[0_2px_4px_rgba(0,0,0,0.45)]">
        <div className="h-4 border-b border-aip-banner-edge bg-aip-banner text-center text-[11px] leading-[15px] font-medium tracking-wide text-white uppercase">
          {subtitle}
        </div>

        <div className="flex h-12.5 items-stretch bg-aip-header px-5">
          <div className="flex items-center pr-8 text-base font-bold text-text-primary">
            {title}
          </div>
          {tabs?.map((tab) => (
            <button
              key={tab.id}
              className={`border-b-2 px-4 text-sm transition-colors ${
                activeTab === tab.id
                  ? 'border-aip-tab-active text-aip-tab-active'
                  : 'border-transparent text-text-primary hover:text-aip-tab-active'
              }`}
              onClick={() => onTabChange?.(tab.id)}
            >
              {tab.label}
            </button>
          ))}
        </div>
      </div>

      <div className={contentClassName}>{children}</div>
    </div>
  );
}
