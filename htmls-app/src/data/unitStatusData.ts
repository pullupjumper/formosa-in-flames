import type {
  SignalData,
  BatteryStatus,
  C2Data,
  Base,
  LandingUnitsData,
  UnitStatusData,
} from '@/types/unitStatus';

// ===========================================================================
// SIGNAL DATA
// ===========================================================================
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

// ===========================================================================
// BATTERY STATUS DATA
// ===========================================================================
export const BATTERY_STATUSES_DATA: BatteryStatus[] = [
  // Names match the control panel mock so the control panel cards show their status
  {
    name: '1st Coy, 613rd Bn, 792nd AFAD & Arty Bde',
    missileSystemType: 'sam',
    firingUnitState: 'STATIC',
    resupplyUnitState: 'RELOAD',
    firingUnitReloadTime: 0,
    defaultReloadTime: 10,
    resupplyUnitReloadTime: 4,
    missilesInAmmoVehicles: 12,
    missilesInTransloaderDefault: 20,
    missilesInAHA: 40,
    missilesInAHADefault: 49,
  },
  {
    name: 'Rocket Arty Coy, 58th Arty Command',
    missileSystemType: 'srbm',
    firingUnitState: 'HIDE',
    resupplyUnitState: 'STATIC',
    firingUnitReloadTime: 6,
    defaultReloadTime: 10,
    resupplyUnitReloadTime: 0,
    missilesInAmmoVehicles: 6,
    missilesInTransloaderDefault: 20,
    missilesInAHA: 40,
    missilesInAHADefault: 49,
  },
  {
    name: '1st Coy, 613rd Bn, 792nd AFAD & Arty Bde',
    missileSystemType: 'sam',
    firingUnitState: 'STATIC',
    resupplyUnitState: 'STATIC',
    firingUnitReloadTime: 10,
    defaultReloadTime: 100,
    resupplyUnitReloadTime: 20,
    missilesInAmmoVehicles: 5,
    missilesInTransloaderDefault: 20,
    missilesInAHA: 40,
    missilesInAHADefault: 49,
  },
  {
    name: 'Rocket Arty Coy, 58th Arty Command',
    missileSystemType: 'srbm',
    firingUnitState: 'STATIC',
    resupplyUnitState: 'STATIC',
    firingUnitReloadTime: 10,
    defaultReloadTime: 100,
    resupplyUnitReloadTime: 20,
    missilesInAmmoVehicles: 5,
    missilesInTransloaderDefault: 20,
    missilesInAHA: 40,
    missilesInAHADefault: 49,
  },
  {
    name: '1st Hai Feng Shore-based ASM MOB Sqn',
    missileSystemType: 'ascm',
    firingUnitState: 'STATIC',
    resupplyUnitState: 'STATIC',
    firingUnitReloadTime: 10,
    defaultReloadTime: 100,
    resupplyUnitReloadTime: 20,
    missilesInAmmoVehicles: 5,
    missilesInTransloaderDefault: 20,
    missilesInAHA: 40,
    missilesInAHADefault: 49,
  },
];

// ===========================================================================
// C2 NODES DATA
// ===========================================================================
export const C2_DATA: C2Data = {
  'IC8B0X-0HNE084PJAHI0': {
    type: 'c2',
    pos: { latitude: 24.2847165330236, longitude: 120.73412101965434 },
    areas: [
      [
        { longitude: 120.803308419605, latitude: 24.7515519114964 },
        { longitude: 121.437805556511, latitude: 24.3811472824897 },
        { longitude: 121.028302275302, latitude: 23.4579812355275 },
        { longitude: 120.872290907731, latitude: 23.4718245350232 },
        { longitude: 120.630850200435, latitude: 23.2494619454537 },
        { longitude: 120.504879344104, latitude: 23.2535811539538 },
        { longitude: 120.429394784948, latitude: 23.3954671223194 },
        { longitude: 120.120481327991, latitude: 23.328616097029 },
        { longitude: 120.184128052671, latitude: 23.8339578493928 },
      ],
    ],
    name: 'Suspected C2 Facility#HJ/Shanwei',
    radar: {},
    sam: {
      'X58F5H-0HMT5ODVUHVLM': {
        type: 'c2',
        name: 'SAM Bn (HQ-12)',
        OODADetection: '15/15',
        OODATargeting: '5/5',
        isOutOfComms: false,
        EMCONSetting: 'Radar=Passive',
        isDestroyed: false,
        weaponFree: false,
        pos: { latitude: 24.073313664577057, longitude: 120.60438145577052 },
      },
      'XXXXXX-222': {
        type: 'c2',
        name: '1st Coy, 613rd Bn, 792nd AFAD & Arty Bde',
        OODADetection: '15/15',
        OODATargeting: '5/5',
        isOutOfComms: false,
        EMCONSetting: 'Radar=Passive',
        isDestroyed: false,
        weaponFree: false,
        pos: { latitude: 23.95115249996755, longitude: 120.53942497864303 },
      },
    },
  },
  'IC8B0X-0HNE084PJAHI1': {
    type: 'c2',
    pos: { latitude: 22.732744117343334, longitude: 120.39802826520243 },
    areas: [
      [
        { longitude: 120.881887906822, latitude: 22.2055997768524 },
        { longitude: 120.874932344667, latitude: 21.8779434850705 },
        { longitude: 120.670470580635, latitude: 21.9416214982707 },
        { longitude: 120.326353746669, latitude: 22.3021186326815 },
        { longitude: 120.004886826341, latitude: 23.0505496549716 },
        { longitude: 120.088623521161, latitude: 23.3069645712745 },
        { longitude: 120.408155026313, latitude: 23.3647132308967 },
        { longitude: 120.49249108325, latitude: 23.2291393134088 },
        { longitude: 120.617702565194, latitude: 23.2204195602708 },
        { longitude: 120.867135049528, latitude: 23.4392344106036 },
        { longitude: 121.00553042947, latitude: 23.4448385396814 },
        { longitude: 120.865389642278, latitude: 23.1526581146023 },
        { longitude: 120.769435403132, latitude: 22.2984708560583 },
      ],
    ],
    name: 'Suspected C2 Facility#HJ/Shanwei',
    radar: {
      'X58F5H-0HMT5': {
        type: 'c2',
        name: 'Radar',
        OODADetection: '15/15',
        OODATargeting: '5/5',
        isOutOfComms: false,
        EMCONSetting: 'Radar=Passive',
        isDestroyed: false,
        weaponFree: false,
        pos: { latitude: 22.898030831712553, longitude: 120.50633950145831 },
      },
    },
    sam: {
      'X58F5H-0HMT5ODVUIBTM': {
        type: 'c2',
        name: 'SAM Bn (HQ-12)',
        OODADetection: '15/15',
        OODATargeting: '5/5',
        isOutOfComms: false,
        EMCONSetting: 'Radar=Passive',
        isDestroyed: false,
        weaponFree: false,
        pos: { latitude: 23.053439219567753, longitude: 120.3895476027512 },
      },
      'X58F5H-0HMT5ODVUIBFJ': {
        type: 'c2',
        name: 'SAM Bn (HQ-22)',
        OODADetection: '15/15',
        OODATargeting: '5/5',
        isOutOfComms: false,
        EMCONSetting: 'Radar=Passive',
        isDestroyed: false,
        weaponFree: false,
        pos: { latitude: 22.96226960827228, longitude: 120.5357141229775 },
      },
    },
  },
};

// ===========================================================================
// BASE WEAPONS DATA
// ===========================================================================
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

// ===========================================================================
// LANDING UNITS DATA
// ===========================================================================
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

// ===========================================================================
// COMBINED UNIT STATUS DATA
// ===========================================================================
export const UNIT_STATUS_DATA: UnitStatusData = {
  signals: SIGNALS_DATA,
  batteryStatuses: BATTERY_STATUSES_DATA,
  c2: C2_DATA,
  baseWeapons: BASE_WEAPONS_DATA,
  landingUnits: LANDING_UNITS_DATA,
};
