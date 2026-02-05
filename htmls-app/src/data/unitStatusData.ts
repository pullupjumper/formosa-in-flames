import type {
  SignalData,
  MissileSystemData,
  C2Data,
  Base,
  LandingUnitsData,
  UnitStatusData,
} from '@/types/unitStatus';

// ============================================================================
// SIGNAL DATA
// ============================================================================
export const SIGNALS_DATA: SignalData[] = [
  {
    name: 'Signal 1',
    type: 'Type A',
    autodetectable: true,
    latitude: 23.5505,
    longitude: 120.6728,
    firstDetected: 1704067200,
    lastDetected: 1704067500,
    detectionCount: 5,
    confidence: 0.9,
    currentDetectionLevel: 3,
  },
  {
    name: 'Signal 2',
    type: 'Type B',
    autodetectable: false,
    latitude: 24.1478,
    longitude: 120.6839,
    firstDetected: 1704070800,
    lastDetected: 1704071400,
    detectionCount: 3,
    confidence: 0.7,
    currentDetectionLevel: 2,
  },
];

// ============================================================================
// MISSILE SYSTEM DATA (Mobile Launchers)
// ============================================================================
export const LAUNCHERS_DATA: MissileSystemData = {
  'Area A': [
    {
      name: 'Launcher 1',
      missileSystem: 'Type 1',
      firingUnitState: 'STATIC',
      resupplyUnitState: 'STATIC',
      firingUnitReloadTime: 10,
      defaultReloadTime: 100,
      resupplyUnitReloadTime: 20,
      missilesInAmmoVehicles: 5,
      missilesInAHA: 10,
    },
    {
      name: 'Launcher 2',
      missileSystem: 'Type 1',
      firingUnitState: 'STATIC',
      resupplyUnitState: 'STATIC',
      firingUnitReloadTime: 10,
      defaultReloadTime: 100,
      resupplyUnitReloadTime: 20,
      missilesInAmmoVehicles: 5,
      missilesInAHA: 10,
    },
  ],
};

// ============================================================================
// C2 NODES DATA
// ============================================================================
export const C2_DATA: C2Data = {
  'IC8B0X-0HNE084PJAHI0': {
    name: 'Suspected C2 Facility#HJ/Shanwei',
    radar: {},
    SAM: {
      'X58F5H-0HMT5ODVUHVLM': {
        name: 'SAM Bn (HQ-12)',
        OODADetection: '15/15',
        OODATargeting: '5/5',
        isOutOfComms: false,
        EMCONSetting: 'Radar=Passive',
        isDestroyed: false,
      },
    },
  },
  'IC8B0X-0HNE084PJAHI1': {
    name: 'Suspected C2 Facility#HJ/Shanwei',
    radar: {},
    SAM: {
      'X58F5H-0HMT5ODVUIBTM': {
        name: 'SAM Bn (HQ-12)',
        OODADetection: '15/15',
        OODATargeting: '5/5',
        isOutOfComms: false,
        EMCONSetting: 'Radar=Passive',
        isDestroyed: false,
      },
      'X58F5H-0HMT5ODVUIBFJ': {
        name: 'SAM Bn (HQ-22)',
        OODADetection: '15/15',
        OODATargeting: '5/5',
        isOutOfComms: false,
        EMCONSetting: 'Radar=Passive',
        isDestroyed: false,
      },
    },
  },
};

// ============================================================================
// BASE WEAPONS DATA
// ============================================================================
export const BASE_WEAPONS_DATA: Base[] = [
  {
    name: 'Base1',
    wpns: [
      { name: 'wpn1', currWpn: 6 },
      { name: 'wpn2', currWpn: 6 },
    ],
  },
  {
    name: 'Base2',
    wpns: [
      { name: 'wpn1', currWpn: 6 },
      { name: 'wpn2', currWpn: 6 },
    ],
  },
];

// ============================================================================
// LANDING UNITS DATA
// ============================================================================
export const LANDING_UNITS_DATA: LandingUnitsData = {
  'Area A': {
    'ZBD-05': 0,
    'ZTD-05': 0,
    'PLL-05': 0,
    'PLZ-96': 0,
    'PGZ-09': 0,
    'PGZ-95': 0,
    'SA-15': 0,
  },
  'Area B': {
    'ZBD-05': 0,
    'ZTD-05': 0,
    'PLL-05': 0,
    'PLZ-96': 0,
    'PGZ-09': 0,
    'PGZ-95': 0,
    'SA-15': 0,
  },
};

// ============================================================================
// COMBINED UNIT STATUS DATA
// ============================================================================
export const UNIT_STATUS_DATA: UnitStatusData = {
  signals: SIGNALS_DATA,
  launchers: LAUNCHERS_DATA,
  c2: C2_DATA,
  baseWeapons: BASE_WEAPONS_DATA,
  landingUnits: LANDING_UNITS_DATA,
};
