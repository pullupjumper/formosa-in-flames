// Control Panel Types
//
// The payload and result types are generated from `src/core/schema.lua` into
// `@/types/generated`; only the page-side root lives here.

import type { BatteryStatus, C2NodeSet, LandingUnitCountSet, Signal } from '@/types/generated';

export interface LiveStatusData {
  signals: Signal[];
  batteryStatuses: BatteryStatus[];
  c2: C2NodeSet;
  landingUnits: LandingUnitCountSet;
}
