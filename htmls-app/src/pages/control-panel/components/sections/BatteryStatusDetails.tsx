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
      <TextRow label="Launcher" value={status.launcherPosture} />
      <TextRow label="Transloader" value={status.transloaderPosture} />
      <BarRow
        label="Launcher Reload (min)"
        current={status.launcherReloadMinutes}
        total={status.reloadMinutesDefault}
      />
      <BarRow
        label="Transloader Reload (min)"
        current={status.transloaderReloadMinutes}
        total={status.reloadMinutesDefault}
      />
      <BarRow
        label="Transloader Missiles"
        current={status.transloaderMissiles}
        total={status.transloaderMissilesDefault}
      />
      <BarRow
        label="ATP Missiles"
        current={status.canisterMissiles}
        total={status.canisterMissilesDefault}
      />
    </>
  );
}
