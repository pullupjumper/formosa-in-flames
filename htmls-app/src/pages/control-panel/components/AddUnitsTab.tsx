import type { AddUnitAction } from '@/types/addUnitsMenu';
import { CheckboxCard } from './CheckboxCard';
import { Panel } from './Panel';
import { SubmitBar } from './SubmitBar';

// ============================================================================
// AddUnitsTab — pick the `addXXX` actions to run when the dialog is confirmed
// ============================================================================
interface AddUnitsTabProps {
  actions: AddUnitAction[];
  checked: ReadonlySet<string>;
  selectedIds: string[];
  isSubmitted: boolean;
  onToggle: (id: string) => void;
  onToggleAll: () => void;
  onSubmit: () => void;
}

export function AddUnitsTab({
  actions,
  checked,
  selectedIds,
  isSubmitted,
  onToggle,
  onToggleAll,
  onSubmit,
}: AddUnitsTabProps) {
  return (
    <div className="h-full overflow-y-auto bg-aip-pane p-3">
      <div className="mx-auto flex max-w-xl flex-col gap-3">
        <Panel title="Add Units" badge={`${selectedIds.length}/${actions.length}`}>
          <button
            type="button"
            className="mb-3 text-[11px] font-semibold uppercase tracking-wide text-aip-link hover:text-accent-blue-hover"
            onClick={onToggleAll}
          >
            {checked.size === actions.length ? 'Clear all' : 'Select all'}
          </button>
          <div className="space-y-2">
            {actions.map((action) => (
              <CheckboxCard
                key={action.id}
                label={action.label}
                checked={checked.has(action.id)}
                onChange={() => onToggle(action.id)}
              />
            ))}
          </div>
        </Panel>

        <SubmitBar
          label={`Submit (${selectedIds.length})`}
          savedMessage="Selection saved. Press Done to add the units."
          disabled={selectedIds.length === 0}
          isSubmitted={isSubmitted}
          onSubmit={onSubmit}
        />
      </div>
    </div>
  );
}
