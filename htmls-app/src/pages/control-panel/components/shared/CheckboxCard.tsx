import type { ReactNode } from 'react';

// ============================================================================
// CheckboxCard — card with a square checkbox, in the control panel's palette
// ============================================================================
interface CheckboxCardProps {
  label: string;
  checked: boolean;
  onChange: (checked: boolean) => void;
  /** Right-aligned content, e.g. what the checked state means */
  trailing?: ReactNode;
}

export function CheckboxCard({ label, checked, onChange, trailing }: CheckboxCardProps) {
  return (
    <label className="flex cursor-pointer items-center justify-between border border-aip-card-border bg-aip-card p-2.5 text-xs transition-colors select-none hover:border-aip-link">
      <span className="flex items-center gap-2.5">
        <input
          type="checkbox"
          checked={checked}
          onChange={(event) => onChange(event.target.checked)}
          className="peer sr-only"
        />
        <span
          aria-hidden="true"
          className={`relative h-4 w-4 shrink-0 border transition-colors peer-focus-visible:outline peer-focus-visible:outline-aip-link ${
            checked ? 'border-aip-link bg-aip-link' : 'border-text-secondary bg-aip-pane'
          }`}
        >
          {checked && (
            <span className="absolute top-px left-1 h-2 w-1 rotate-45 border-r-2 border-b-2 border-white" />
          )}
        </span>
        <span className="font-semibold">{label}</span>
      </span>
      {trailing}
    </label>
  );
}
