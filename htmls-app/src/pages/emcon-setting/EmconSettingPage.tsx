import { useState } from 'react';

interface DoctrineEntry {
  id: string;
  label: string;
  weaponsFree: boolean;
}

const INITIAL_DOCTRINE: DoctrineEntry[] = [
  { id: 'pac23', label: 'Pac-2/3', weaponsFree: false },
  { id: 'skybow3', label: 'Sky Bow-3', weaponsFree: false },
  { id: 'tc2', label: 'TC-2', weaponsFree: false },
];

function EmconSettingPage() {
  const [doctrine, setDoctrine] = useState<DoctrineEntry[]>(INITIAL_DOCTRINE);

  const handleToggle = (id: string) => {
    setDoctrine((prev) =>
      prev.map((entry) => (entry.id === id ? { ...entry, weaponsFree: !entry.weaponsFree } : entry))
    );
  };

  const handleSubmit = () => {
    const exportData = {
      doctrine: doctrine.map((entry) => ({
        id: entry.id,
        weaponsFree: entry.weaponsFree,
      })),
    };
    const jsonString = JSON.stringify(exportData);
    const emconDataInput = document.getElementById('emconData') as HTMLInputElement | null;
    if (emconDataInput) {
      emconDataInput.value = jsonString;
    }
    console.log('Doctrine Configuration:', exportData);
    alert('Doctrine configuration submitted');
  };

  return (
    <div className="flex h-screen flex-col">
      {/* Top Bar */}
      <div className="flex h-12.5 items-center justify-between border-b border-dark-border bg-dark-panel px-5">
        <div className="text-sm font-medium text-text-secondary">
          <span className="text-text-primary">Weapons Doctrine</span>
        </div>
      </div>

      {/* Content */}
      <div className="flex flex-1 items-start justify-center overflow-auto p-5">
        <div className="w-full max-w-100 rounded-sm border border-dark-border bg-dark-panel p-6 shadow-lg">
          <h2 className="mb-5 border-b border-dark-border pb-2.5 text-lg font-semibold text-text-primary">
            SAM Systems Doctrine
          </h2>
          <div className="space-y-4">
            {doctrine.map((entry) => (
              <DoctrineItem
                key={entry.id}
                id={entry.id}
                label={entry.label}
                weaponsFree={entry.weaponsFree}
                onChange={() => handleToggle(entry.id)}
              />
            ))}
          </div>

          {/* Submit Button */}
          <button
            className="mt-6 w-full rounded-sm bg-accent-blue px-4 py-2.5 text-xs font-semibold uppercase tracking-wide text-white transition-colors hover:bg-accent-blue-hover"
            onClick={handleSubmit}
          >
            Submit Configuration
          </button>
        </div>
      </div>
    </div>
  );
}

interface DoctrineItemProps {
  id: string;
  label: string;
  weaponsFree: boolean;
  onChange: () => void;
}

function DoctrineItem({ id, label, weaponsFree, onChange }: DoctrineItemProps) {
  return (
    <div className="flex items-center justify-between rounded p-2 transition-colors hover:bg-white/5">
      <label
        htmlFor={id}
        className="relative flex cursor-pointer items-center pl-7.5 text-sm text-text-primary select-none"
      >
        <input
          type="checkbox"
          id={id}
          name={id}
          checked={weaponsFree}
          onChange={onChange}
          className="absolute h-0 w-0 opacity-0"
        />
        <span
          className={`absolute left-0 top-0 h-4.5 w-4.5 rounded-[3px] border transition-colors ${
            weaponsFree
              ? 'border-accent-blue bg-accent-blue'
              : 'border-text-secondary bg-dark-bg hover:border-accent-blue'
          }`}
        >
          {weaponsFree && (
            <span className="absolute left-1.5 top-0.5 h-2.25 w-1 rotate-45 border-b-2 border-r-2 border-white" />
          )}
        </span>
        {label}
      </label>
      <span
        className={`text-xs font-semibold ${weaponsFree ? 'text-status-danger' : 'text-status-warning'}`}
      >
        {weaponsFree ? 'Weapons Free' : 'Hold Fire'}
      </span>
    </div>
  );
}

export default EmconSettingPage;
