import { CheckboxCard } from '@pages/control-panel/components/shared/CheckboxCard';

// ============================================================================
// SamDoctrineToggle — one checkbox for every SAM's weapons control status
// ============================================================================
interface SamDoctrineToggleProps {
  isWeaponsFree: boolean;
  onChange: (isWeaponsFree: boolean) => void;
}

export function SamDoctrineToggle({ isWeaponsFree, onChange }: SamDoctrineToggleProps) {
  return (
    <div className="mb-3">
      <CheckboxCard
        label="All SAMs weapons free"
        checked={isWeaponsFree}
        onChange={onChange}
        trailing={
          <span
            className={`font-semibold ${isWeaponsFree ? 'text-status-danger' : 'text-status-warning'}`}
          >
            {isWeaponsFree ? 'Weapons Free' : 'Hold Fire'}
          </span>
        }
      />
    </div>
  );
}
