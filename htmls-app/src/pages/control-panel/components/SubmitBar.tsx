// ============================================================================
// SubmitBar — hands a result to the CMO host through a hidden input
// ============================================================================
interface SubmitBarProps {
  onSubmit: () => void;
  /** True while the host input still holds the current result */
  isSubmitted: boolean;
  label?: string;
  savedMessage?: string;
  disabled?: boolean;
}

export function SubmitBar({
  onSubmit,
  isSubmitted,
  label = 'Submit Configuration',
  savedMessage = 'Configuration saved. Press Done to apply it.',
  disabled = false,
}: SubmitBarProps) {
  return (
    <div className="shrink-0 border border-aip-border bg-aip-panel p-3">
      <button
        type="button"
        disabled={disabled}
        className="w-full bg-aip-link px-4 py-2.5 text-xs font-semibold uppercase tracking-wide text-white transition-colors hover:bg-accent-blue-hover disabled:opacity-50"
        onClick={onSubmit}
      >
        {label}
      </button>
      {isSubmitted && (
        <p className="mt-2 text-center text-[11px] text-status-warning">{savedMessage}</p>
      )}
    </div>
  );
}
