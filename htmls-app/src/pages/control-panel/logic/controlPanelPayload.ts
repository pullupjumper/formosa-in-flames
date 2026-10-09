import type {
  AddUnitAction,
  AddUnitsMenuResult,
  Airbase,
  AmphibiousLocation,
  Jammer,
  MissileSystemTypes,
  ControlPanelResult,
} from '@/types/controlPanel';
import type { BatteryStatus, C2Nodes, LandingUnits, Signal } from '@/types/controlPanel';
import {
  AIRBASES_DATA,
  JAMMERS_DATA,
  MISSILE_SYSTEMS_DATA,
  AMPHIBIOUS_LOCATION_DATA,
  MOCK_ADD_UNIT_ACTIONS,
} from '@/data/controlPanelData';
import { LIVE_STATUS_DATA } from '@/data/liveStatusData';
import type { C2ContextEntry, SamDoctrineEntry } from './c2Nodes';
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
    __INJECT_BATTERY_STATUSES__?: string;
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
  missileSystems: MissileSystemTypes;
  amphibiousLocations: AmphibiousLocation[];
  c2Data: C2Nodes;
  signals: Signal[];
  batteryStatuses: BatteryStatus[];
  landingUnits: LandingUnits;
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
    missileSystems: parseInjectedJSON<MissileSystemTypes>(
      window.__INJECT_MISSILE_SYSTEMS__,
      MISSILE_SYSTEMS_DATA,
      'MISSILE_SYSTEMS'
    ),
    amphibiousLocations: parseInjectedJSON<AmphibiousLocation[]>(
      window.__INJECT_AMPHIBIOUS_LOCATIONS__,
      AMPHIBIOUS_LOCATION_DATA,
      'AMPHIBIOUS_LOCATIONS'
    ),
    c2Data: parseInjectedJSON<C2Nodes>(window.__INJECT_C2__, LIVE_STATUS_DATA.c2, 'C2'),
    signals: parseInjectedJSON<Signal[]>(
      window.__INJECT_SIGNALS__,
      LIVE_STATUS_DATA.signals,
      'SIGNALS'
    ),
    batteryStatuses: parseInjectedJSON<BatteryStatus[]>(
      window.__INJECT_BATTERY_STATUSES__,
      LIVE_STATUS_DATA.batteryStatuses,
      'BATTERY_STATUSES'
    ),
    landingUnits: parseInjectedJSON<LandingUnits>(
      window.__INJECT_LANDING_UNITS__,
      LIVE_STATUS_DATA.landingUnits,
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
/**
 * SAM weapons-control choice, written to `emconData`. Each entry names a live
 * SAM unit by GUID, so the host can apply it without guessing which platform a
 * menu id stood for. Units that were never switched carry the status they had.
 */
export interface EmconResult {
  sams: SamDoctrineEntry[];
  /** C2 nodes whose SAM units changed after the player's redeployment */
  c2Nodes: C2ContextEntry[];
}

/** Deployment and SAM doctrine are one submission: both inputs or neither counts. */
export function submitDeployment(result: ControlPanelResult, doctrine: EmconResult): boolean {
  const isDeploymentWritten = writeHostInput('summaryData', result);
  const isDoctrineWritten = writeHostInput('emconData', doctrine);
  return isDeploymentWritten && isDoctrineWritten;
}

export function submitSelectedActions(result: AddUnitsMenuResult): boolean {
  return writeHostInput('selectedActions', result);
}
