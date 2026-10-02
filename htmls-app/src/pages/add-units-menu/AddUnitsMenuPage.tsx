import { useState } from 'react';
import type { AddUnitsMenuResult } from '@/types/addUnitsMenu';
import { PageShell } from '@/components/PageShell';
import { writeHostInput } from '@/utils/inject';
import { readAddUnitsMenuData } from '@/utils/addUnitsMenuPayload';
import { useActionSelection } from './hooks/useActionSelection';

function AddUnitsMenuPage() {
  const [{ sideName, actions }] = useState(readAddUnitsMenuData);
  const [submitted, setSubmitted] = useState(false);
  const { checked, selectedIds, toggle, toggleAll } = useActionSelection({ actions });

  const handleToggle = (id: string) => {
    setSubmitted(false);
    toggle(id);
  };

  const handleToggleAll = () => {
    setSubmitted(false);
    toggleAll();
  };

  const handleSubmit = () => {
    const result: AddUnitsMenuResult = { actionIds: selectedIds };
    setSubmitted(writeHostInput('selectedActions', result));
  };

  return (
    <PageShell
      title={sideName}
      subtitle="Add Units"
      contentClassName="flex flex-1 items-start justify-center overflow-auto p-5"
    >
      <div className="w-full max-w-100 rounded-sm border border-dark-border bg-dark-panel p-6 shadow-lg">
        <div className="mb-5 flex items-center justify-between border-b border-dark-border pb-2.5">
          <h2 className="text-lg font-semibold text-text-primary">Add Units</h2>
          <button
            className="text-xs font-semibold uppercase tracking-wide text-accent-blue hover:text-accent-blue-hover"
            onClick={handleToggleAll}
          >
            {checked.size === actions.length ? 'Clear all' : 'Select all'}
          </button>
        </div>

        <div className="space-y-2">
          {actions.map((action) => (
            <ActionItem
              key={action.id}
              id={action.id}
              label={action.label}
              checked={checked.has(action.id)}
              onChange={() => handleToggle(action.id)}
            />
          ))}
        </div>

        <button
          className="mt-6 w-full rounded-sm bg-accent-blue px-4 py-2.5 text-xs font-semibold uppercase tracking-wide text-white transition-colors hover:bg-accent-blue-hover disabled:opacity-50"
          disabled={selectedIds.length === 0}
          onClick={handleSubmit}
        >
          Submit ({selectedIds.length})
        </button>
        {submitted && (
          <p className="mt-3 text-center text-xs text-status-warning">
            Selection saved. Press Done to add the units.
          </p>
        )}
      </div>
    </PageShell>
  );
}

interface ActionItemProps {
  id: string;
  label: string;
  checked: boolean;
  onChange: () => void;
}

function ActionItem({ id, label, checked, onChange }: ActionItemProps) {
  return (
    <div className="rounded p-2 transition-colors hover:bg-white/5">
      <label
        htmlFor={id}
        className="relative flex cursor-pointer items-center pl-7.5 text-sm text-text-primary select-none"
      >
        <input
          type="checkbox"
          id={id}
          checked={checked}
          onChange={onChange}
          className="absolute h-0 w-0 opacity-0"
        />
        <span
          className={`absolute left-0 top-0 h-4.5 w-4.5 rounded-[3px] border transition-colors ${
            checked
              ? 'border-accent-blue bg-accent-blue'
              : 'border-text-secondary bg-dark-bg hover:border-accent-blue'
          }`}
        >
          {checked && (
            <span className="absolute left-1.5 top-0.5 h-2.25 w-1 rotate-45 border-b-2 border-r-2 border-white" />
          )}
        </span>
        {label}
      </label>
    </div>
  );
}

export default AddUnitsMenuPage;
