import type { ReactNode } from 'react';
import { calculateProgress } from '@/pages/control-panel/logic/format';

// ============================================================================
// DetailsBox — titled box inside a card; rows line up as label | value | bar
// ============================================================================
interface DetailsBoxProps {
  title: string;
  /**
   * `TextRow` / `BarRow` elements; they join one grid so columns line up. A box
   * wider than 32rem sets its rows two to a line, so the width of the card
   * decides the layout.
   */
  children: ReactNode;
}

// Labels wrap inside the card instead of pushing it wider; every bar has the
// same width, so rows read as columns. Wide boxes repeat the three columns twice.
const GRID =
  'grid grid-cols-[minmax(0,1fr)_auto_3.5rem] items-center gap-x-3 gap-y-2 ' +
  '@lg:grid-cols-[minmax(0,1fr)_auto_3.5rem_minmax(0,1fr)_auto_3.5rem] @lg:gap-x-5';

export function DetailsBox({ title, children }: DetailsBoxProps) {
  return (
    <div
      className="@container min-w-0 border border-aip-border bg-aip-pane/60 p-2.5 text-xs"
      onClick={(event) => event.stopPropagation()}
    >
      <div className="mb-2 font-semibold text-text-primary">{title}</div>
      <div className={GRID}>{children}</div>
    </div>
  );
}

const VALUE_TONES = {
  default: 'text-text-primary',
  danger: 'text-status-danger',
  warning: 'text-status-warning',
};

interface TextRowProps {
  label: string;
  value: ReactNode;
  tone?: keyof typeof VALUE_TONES;
}

/** Longer than this, a text value takes the whole line of a two-column box */
const LONG_VALUE_LENGTH = 24;

export function TextRow({ label, value, tone = 'default' }: TextRowProps) {
  const isLong = typeof value === 'string' && value.length > LONG_VALUE_LENGTH;

  return (
    <>
      <span className="text-text-secondary">{label}</span>
      <span className={`col-span-2 ${isLong ? '@lg:col-span-5' : ''} ${VALUE_TONES[tone]}`}>
        {value}
      </span>
    </>
  );
}

interface BarRowProps {
  label: string;
  current: number;
  total: number;
}

export function BarRow({ label, current, total }: BarRowProps) {
  const percentage = calculateProgress(current, total);

  return (
    <>
      <span className="text-text-secondary">{label}</span>
      <span className="whitespace-nowrap text-text-primary tabular-nums">
        {current} / {total}
      </span>
      <div className="h-2.5 overflow-hidden rounded-xs bg-white/15">
        <div
          className="h-full bg-aip-link transition-[width] duration-300"
          style={{ width: `${Math.min(100, percentage)}%` }}
        />
      </div>
    </>
  );
}
