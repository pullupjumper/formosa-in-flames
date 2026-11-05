import type { BatteryStatus } from '@/types/controlPanel';
import { BarRow, TextRow } from '@pages/control-panel/components/shared/DetailsBox';

// ============================================================================
// BatteryStatusDetails — live battery status rows, placed inside a DetailsBox
// ============================================================================
interface BatteryStatusDetailsProps {
  status: BatteryStatus;
}

export function BatteryStatusDetails({ status }: BatteryStatusDetailsProps) {
  return (
    <>
      <TextRow label="Firing Unit" value={status.firingUnitState} />
      <TextRow label="Resupply Unit" value={status.resupplyUnitState} />
      <BarRow
        label="Firing Reload (min)"
        current={status.firingUnitReloadTime}
        total={status.defaultReloadTime}
      />
      <BarRow
        label="Resupply Reload (min)"
        current={status.resupplyUnitReloadTime}
        total={status.defaultReloadTime}
      />
      <BarRow
        label="Transloader Missiles"
        current={status.missilesInAmmoVehicles}
        total={status.missilesInTransloaderDefault}
      />
      <BarRow
        label="ATP Missiles"
        current={status.missilesInCanisterStock}
        total={status.missilesInCanisterStockDefault}
      />
    </>
  );
}
