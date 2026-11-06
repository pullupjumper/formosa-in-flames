import type {
  AddUnitOption,
  AddUnitsMenuResult,
  AirbaseDeploymentDescriptor,
  AmphibiousLocation,
  C2NodeSet,
  ControlPanelResult,
  EmconResult,
  GNSSJammerDescriptor,
  LandingUnitCountSet,
  PanelBattery,
  Signal,
} from '@/types/generated';
import {
  AIRBASES_DATA,
  JAMMERS_DATA,
  BATTERIES_DATA,
  AMPHIBIOUS_LOCATION_DATA,
  MOCK_ADD_UNIT_ACTIONS,
} from '@/data/controlPanelData';
import { LIVE_STATUS_DATA } from '@/data/liveStatusData';
import {
  parseInjectedJSON,
  readInjectedBoolean,
  readInjectedString,
  writeHostInput,
} from '@/utils/inject';
import type { ControlPanelMode } from './controlPanelMode';

/**
 * The one place that knows what `unitStatusUI.lua` injects into the control
 * panel (`window.__INJECT_*__`) and which hidden inputs it reads back.
 *
 * Read side: `readControlPanelPayload`, once per page load. Unfilled
 * placeholders (local dev) fall back to mock data, so pages never see a
 * missing field.
 * Write side: one `submit*` per hidden input, so no page names an input id.
 */

declare global {
  interface Window {
    __INJECT_JAMMERS__?: string;
    __INJECT_AIRBASES__?: string;
    __INJECT_BATTERIES__?: string;
    __INJECT_SIDE_NAME__?: string;
    __INJECT_ADD_UNIT_ACTIONS__?: string;
    __INJECT_AMPHIBIOUS_LOCATIONS__?: string;
    __INJECT_C2__?: string;
    __INJECT_SIGNALS__?: string;
    __INJECT_LANDING_UNITS__?: string;
    __INJECT_IS_EDIT_MODE__?: string;
    __INJECT_IS_DEPLOY_LOCKED__?: string;
  }
}

// ============================================================================
// READ
// ============================================================================
export interface ControlPanelPayload {
  sideName: string;
  mode: ControlPanelMode;
  airbases: AirbaseDeploymentDescriptor[];
  jammers: GNSSJammerDescriptor[];
  batteries: PanelBattery[];
  amphibiousLocations: AmphibiousLocation[];
  c2Data: C2NodeSet;
  signals: Signal[];
  landingUnits: LandingUnitCountSet;
  addUnitActions: AddUnitOption[];
}

export function readControlPanelPayload(): ControlPanelPayload {
  return {
    sideName: readInjectedString(window.__INJECT_SIDE_NAME__, 'Taiwan'),
    // Unfilled placeholders mean local dev: edit mode, nothing locked
    mode: {
      isEditMode: readInjectedBoolean(window.__INJECT_IS_EDIT_MODE__, true),
      isDeployLocked: readInjectedBoolean(window.__INJECT_IS_DEPLOY_LOCKED__, false),
    },
    airbases: parseInjectedJSON<AirbaseDeploymentDescriptor[]>(
      window.__INJECT_AIRBASES__,
      AIRBASES_DATA,
      'AIRBASES'
    ),
    jammers: parseInjectedJSON<GNSSJammerDescriptor[]>(
      window.__INJECT_JAMMERS__,
      JAMMERS_DATA,
      'JAMMERS'
    ),
    batteries: parseInjectedJSON<PanelBattery[]>(
      window.__INJECT_BATTERIES__,
      BATTERIES_DATA,
      'BATTERIES'
    ),
    amphibiousLocations: parseInjectedJSON<AmphibiousLocation[]>(
      window.__INJECT_AMPHIBIOUS_LOCATIONS__,
      AMPHIBIOUS_LOCATION_DATA,
      'AMPHIBIOUS_LOCATIONS'
    ),
    c2Data: parseInjectedJSON<C2NodeSet>(window.__INJECT_C2__, LIVE_STATUS_DATA.c2, 'C2'),
    signals: parseInjectedJSON<Signal[]>(
      window.__INJECT_SIGNALS__,
      LIVE_STATUS_DATA.signals,
      'SIGNALS'
    ),
    landingUnits: parseInjectedJSON<LandingUnitCountSet>(
      window.__INJECT_LANDING_UNITS__,
      LIVE_STATUS_DATA.landingUnits,
      'LANDING_UNITS'
    ),
    addUnitActions: parseInjectedJSON<AddUnitOption[]>(
      window.__INJECT_ADD_UNIT_ACTIONS__,
      MOCK_ADD_UNIT_ACTIONS,
      'ADD_UNIT_ACTIONS'
    ),
  };
}

// ============================================================================
// WRITE
// ============================================================================
/** Deployment and SAM doctrine are one submission: both inputs or neither counts. */
export function submitDeployment(result: ControlPanelResult, doctrine: EmconResult): boolean {
  const isDeploymentWritten = writeHostInput('summaryData', result);
  const isDoctrineWritten = writeHostInput('emconData', doctrine);
  return isDeploymentWritten && isDoctrineWritten;
}

export function submitSelectedActions(result: AddUnitsMenuResult): boolean {
  return writeHostInput('selectedActions', result);
}
