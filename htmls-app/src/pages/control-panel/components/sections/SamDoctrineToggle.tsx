import { CheckboxCard } from '@pages/control-panel/components/shared/CheckboxCard';

// ============================================================================
// SamDoctrineToggle — one checkbox for every SAM's weapons control status
// ============================================================================
interface SamDoctrineToggleProps {
  weaponsFree: boolean;
  onChange: (weaponsFree: boolean) => void;
}

export function SamDoctrineToggle({ weaponsFree, onChange }: SamDoctrineToggleProps) {
  return (
    <div className="mb-3">
      <CheckboxCard
        label="All SAMs weapons free"
        checked={weaponsFree}
        onChange={onChange}
        trailing={
          <span
            className={`font-semibold ${weaponsFree ? 'text-status-danger' : 'text-status-warning'}`}
          >
            {weaponsFree ? 'Weapons Free' : 'Hold Fire'}
          </span>
        }
      />
    </div>
  );
}
