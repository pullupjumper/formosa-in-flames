import type { BatteryStatus } from '@/types/generated';
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
      <TextRow label="Firing Unit" value={status.firingPosture} />
      <TextRow label="Resupply Unit" value={status.resupplyPosture} />
      <BarRow
        label="Firing Reload (min)"
        current={status.firingReloadMinutes}
        total={status.reloadMinutesDefault}
      />
      <BarRow
        label="Resupply Reload (min)"
        current={status.resupplyReloadMinutes}
        total={status.reloadMinutesDefault}
      />
      <BarRow
        label="Transloader Missiles"
        current={status.resupplyMissiles}
        total={status.resupplyMissilesDefault}
      />
      <BarRow
        label="ATP Missiles"
        current={status.canisterMissiles}
        total={status.canisterMissilesDefault}
      />
    </>
  );
}
