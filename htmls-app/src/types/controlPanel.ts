// Control Panel Types
//
// The payload and result types are generated from `src/core/schema.lua` into
// `@/types/generated`; only the page-side root lives here.

import type { C2NodeSet, LandingUnitCountSet, Signal } from '@/types/generated';

export interface LiveStatusData {
  signals: Signal[];
  c2: C2NodeSet;
  landingUnits: LandingUnitCountSet;
}
