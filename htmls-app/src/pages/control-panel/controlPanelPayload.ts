import type { AddUnitAction, AddUnitsMenuResult } from '@/types/addUnitsMenu';
import type {
  Airbase,
  AmphibiousLocation,
  Jammer,
  MissileSystems,
  SetupResult,
} from '@/types/setupMenu';
import type { C2Data, LandingUnitsData, MissileSystemData, SignalData } from '@/types/unitStatus';
import { MOCK_ADD_UNIT_ACTIONS } from '@/data/addUnitsMenuData';
import {
  AIRBASES_DATA,
  JAMMERS_DATA,
  MISSILE_SYSTEMS_DATA,
  AMPHIBIOUS_LOCATION_DATA,
} from '@/data/setupMenuData';
import { UNIT_STATUS_DATA } from '@/data/unitStatusData';
import type { EmconResult } from '@/utils/emcon';
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
    __INJECT_MISSILE_SYSTEMS__?: string;
    __INJECT_SIDE_NAME__?: string;
    __INJECT_ADD_UNIT_ACTIONS__?: string;
    __INJECT_AMPHIBIOUS_LOCATIONS__?: string;
    __INJECT_C2__?: string;
    __INJECT_SIGNALS__?: string;
    __INJECT_LAUNCHERS__?: string;
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
  airbases: Airbase[];
  jammers: Jammer[];
  missileSystems: MissileSystems;
  amphibiousLocations: AmphibiousLocation[];
  c2Data: C2Data;
  signals: SignalData[];
  launcherData: MissileSystemData;
  landingUnits: LandingUnitsData;
  addUnitActions: AddUnitAction[];
}

export function readControlPanelPayload(): ControlPanelPayload {
  return {
    sideName: readInjectedString(window.__INJECT_SIDE_NAME__, 'Taiwan'),
    // Unfilled placeholders mean local dev: edit mode, nothing locked
    mode: {
      isEditMode: readInjectedBoolean(window.__INJECT_IS_EDIT_MODE__, true),
      isDeployLocked: readInjectedBoolean(window.__INJECT_IS_DEPLOY_LOCKED__, false),
    },
    airbases: parseInjectedJSON<Airbase[]>(window.__INJECT_AIRBASES__, AIRBASES_DATA, 'AIRBASES'),
    jammers: parseInjectedJSON<Jammer[]>(window.__INJECT_JAMMERS__, JAMMERS_DATA, 'JAMMERS'),
    missileSystems: parseInjectedJSON<MissileSystems>(
      window.__INJECT_MISSILE_SYSTEMS__,
      MISSILE_SYSTEMS_DATA,
      'MISSILE_SYSTEMS'
    ),
    amphibiousLocations: parseInjectedJSON<AmphibiousLocation[]>(
      window.__INJECT_AMPHIBIOUS_LOCATIONS__,
      AMPHIBIOUS_LOCATION_DATA,
      'AMPHIBIOUS_LOCATIONS'
    ),
    c2Data: parseInjectedJSON<C2Data>(window.__INJECT_C2__, UNIT_STATUS_DATA.c2, 'C2'),
    signals: parseInjectedJSON<SignalData[]>(
      window.__INJECT_SIGNALS__,
      UNIT_STATUS_DATA.signals,
      'SIGNALS'
    ),
    launcherData: parseInjectedJSON<MissileSystemData>(
      window.__INJECT_LAUNCHERS__,
      UNIT_STATUS_DATA.launchers,
      'LAUNCHERS'
    ),
    landingUnits: parseInjectedJSON<LandingUnitsData>(
      window.__INJECT_LANDING_UNITS__,
      UNIT_STATUS_DATA.landingUnits,
      'LANDING_UNITS'
    ),
    addUnitActions: parseInjectedJSON<AddUnitAction[]>(
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
export function submitDeployment(result: SetupResult, doctrine: EmconResult): boolean {
  const isDeploymentWritten = writeHostInput('summaryData', result);
  const isDoctrineWritten = writeHostInput('emconData', doctrine);
  return isDeploymentWritten && isDoctrineWritten;
}

export function submitSelectedActions(result: AddUnitsMenuResult): boolean {
  return writeHostInput('selectedActions', result);
}
