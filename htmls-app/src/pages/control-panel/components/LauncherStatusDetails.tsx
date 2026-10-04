import { calculateProgress } from '@/utils/format';
import type { LauncherStatus } from '../launcherStatus';

// ============================================================================
// LauncherStatusDetails — live battery status lines for a launcher card
// ============================================================================
interface LauncherStatusDetailsProps {
  status: LauncherStatus;
}

export function LauncherStatusDetails({ status }: LauncherStatusDetailsProps) {
  return (
    <div className="mt-1.5 space-y-1.5 border-t border-aip-card-border/60 pt-1.5">
      <div>
        FIRING: {status.firingUnitState} | RESUPPLY: {status.resupplyUnitState}
      </div>
      <div className="truncate" title={status.resupplyUnitName}>
        RESUPPLY UNIT: {status.resupplyUnitName}
      </div>
      <ReloadBar
        label="FIRING RELOAD"
        current={status.firingUnitReloadTime}
        total={status.defaultReloadTime}
      />
      <ReloadBar
        label="RESUPPLY RELOAD"
        current={status.resupplyUnitReloadTime}
        total={status.defaultReloadTime}
      />
      <div>
        MISSILES: {status.missilesInAmmoVehicles} (AMMO) | {status.missilesInAHA} (AHA)
      </div>
    </div>
  );
}

function ReloadBar({ label, current, total }: { label: string; current: number; total: number }) {
  const percentage = calculateProgress(current, total);

  return (
    <div>
      <div className="flex justify-between">
        <span>{label}</span>
        <span className="font-mono text-[10px]">{percentage}%</span>
      </div>
      <div className="mt-0.5 h-1.5 overflow-hidden bg-aip-pane">
        <div
          className="h-full bg-aip-link transition-[width] duration-300"
          style={{ width: `${Math.min(100, percentage)}%` }}
        />
      </div>
    </div>
  );
}
