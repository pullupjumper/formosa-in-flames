import type { ReactNode } from 'react';
import { Popup, useMap } from 'react-leaflet';

// ============================================================================
// MapPopup — light "Selection" card shown when a map marker is clicked
// ============================================================================
export interface PopupRow {
  label: string;
  value: ReactNode;
}

interface MapPopupProps {
  name: string;
  /** Grey line under the name, e.g. the kind of unit */
  subtitle?: string;
  /** Symbol left of the name */
  icon?: ReactNode;
  /** Label / value pairs under the name */
  rows?: PopupRow[];
  /** `PopupSection`s */
  children?: ReactNode;
}

export function MapPopup({ name, subtitle, icon, rows = [], children }: MapPopupProps) {
  return (
    <Popup className="selection-popup" closeButton={false} minWidth={260} maxWidth={320}>
      <div className="text-sm text-selection-text">
        <PopupHeader />
        <div className="flex items-center gap-3 px-4 pt-4 pb-3">
          {icon}
          <div className="min-w-0">
            <div className="text-lg leading-tight font-medium">{name}</div>
            {subtitle && <div className="text-xs text-selection-muted">{subtitle}</div>}
          </div>
        </div>
        {rows.length > 0 && (
          <div className="px-4 pb-3">
            <PopupRows rows={rows} />
          </div>
        )}
        {children}
      </div>
    </Popup>
  );
}

function PopupHeader() {
  const map = useMap();

  return (
    <div className="flex items-center justify-between border-b border-selection-line px-4 py-2.5">
      <span className="font-semibold">Selection</span>
      <button
        type="button"
        aria-label="Close"
        className="cursor-pointer text-lg leading-none text-selection-muted hover:text-selection-text"
        onClick={() => map.closePopup()}
      >
        ×
      </button>
    </div>
  );
}

function PopupRows({ rows }: { rows: PopupRow[] }) {
  return (
    <dl className="grid grid-cols-[max-content_1fr] gap-x-6 gap-y-0.5">
      {rows.map((row) => (
        <div key={row.label} className="contents">
          <dt className="text-selection-muted">{row.label}</dt>
          <dd className="m-0 min-w-0">{row.value}</dd>
        </div>
      ))}
    </dl>
  );
}

// ============================================================================
// PopupSection — titled block under the header, split by a hairline
// ============================================================================
interface PopupSectionProps {
  title: string;
  rows: PopupRow[];
}

export function PopupSection({ title, rows }: PopupSectionProps) {
  return (
    <div className="border-t border-selection-line px-4 py-3">
      <div className="mb-2 font-semibold">{title}</div>
      <PopupRows rows={rows} />
    </div>
  );
}
