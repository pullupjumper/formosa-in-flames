import type { Airbase, Jammer, MissileSystems } from '@/types/setupMenu';

// ============================================================================
// JAMMERS DATA
// ============================================================================
export const JAMMERS_DATA: Jammer[] = [
  {
    zoneName: 'JAMMING ZONE/1',
    name: 'Comm and Info Coy, 584th Mech Bde',
    randomRadius: 20,
    radius: 11,
  },
  {
    zoneName: 'JAMMING ZONE/2',
    name: 'Comm and Info Coy, 269th Mech Bde',
    randomRadius: 20,
    radius: 11,
  },
];

// ============================================================================
// AIRBASES DATA
// ============================================================================
export const AIRBASES_DATA: Airbase[] = [
  {
    name: 'Ching Chuang Kang AB',
    longitude: 120.61987074635,
    latitude: 24.266687043134,
    baseGUID: '6Z8LM5-0HMIHS2L949R0',
    embarkedUnits: [
      {
        dbid: 3795,
        platformName: 'IDF',
        type: 'Air',
        side: 'Taiwan',
        loadouts: [{ num: 8, loadoutId: 19104, name: 'Wan Chien' }],
        name: '3rd Tactical Fighter Wing',
      },
    ],
    loadouts: [{ num: 8, loadoutId: 19104, name: 'Wan Chien' }],
  },
  {
    name: 'Chiayi AB',
    longitude: 120.39031110523,
    latitude: 23.463954680839,
    baseGUID: '6Z8LM5-0HMIJ3QGCHSUB',
    embarkedUnits: [
      {
        dbid: 3962,
        platformName: 'F-16V Block 20',
        type: 'Air',
        side: 'Taiwan',
        loadouts: [{ num: 8, loadoutId: 22785, name: 'AMRAAM' }],
        name: '4th Tactical Fighter Wing',
      },
    ],
    loadouts: [
      { num: 8, loadoutId: 22785, name: 'AMRAAM' },
      { num: 8, loadoutId: 22789, name: 'Harpoon' },
      { num: 8, loadoutId: 22790, name: 'GBU' },
    ],
  },
  {
    name: 'Tainan AB',
    longitude: 120.20421803987,
    latitude: 22.950204912894,
    baseGUID: '6Z8LM5-0HMIJ3QGCHVVS',
    embarkedUnits: [
      {
        dbid: 3795,
        platformName: 'IDF',
        type: 'Air',
        side: 'Taiwan',
        loadouts: [{ num: 4, loadoutId: 19104, name: 'Wan Chien' }],
        name: '1st Tactical Fighter Wing',
      },
    ],
    loadouts: [{ num: 8, loadoutId: 19104, name: 'Wan Chien' }],
  },
  {
    name: 'Magong AB',
    longitude: 119.62810201945,
    latitude: 23.569032242702,
    baseGUID: '6Z8LM5-0HMISSTNL3T8K',
    embarkedUnits: [
      {
        dbid: 3795,
        platformName: 'IDF',
        type: 'Air',
        side: 'Taiwan',
        loadouts: [{ num: 4, loadoutId: 19104, name: 'Wan Chien' }],
        name: '1st Tactical Fighter Wing',
      },
    ],
    loadouts: [{ num: 8, loadoutId: 19104, name: 'Wan Chien' }],
  },
  {
    name: 'Guiren AAB',
    longitude: 120.28448603465,
    latitude: 22.981265758066,
    baseGUID: 'IC8B0X-0HN37BVOG0T9O',
    embarkedUnits: [
      {
        dbid: 2126,
        platformName: 'AH-1W',
        type: 'Air',
        side: 'Taiwan',
        loadouts: [{ loadoutId: 7347, num: 8, name: 'Hellfire' }],
        name: '603rd Air Cavalry Bde',
      },
    ],
    loadouts: [{ num: 8, loadoutId: 7347, name: 'Hellfire' }],
  },
  {
    name: 'Pingtung North AB',
    longitude: 120.48108029825,
    latitude: 22.700322757856,
    baseGUID: 'IC8B0X-0HNCTPETEF6GG',
    embarkedUnits: [
      {
        dbid: 2095,
        platformName: 'E-2K',
        type: 'Air',
        side: 'Taiwan',
        loadouts: [{ loadoutId: 14639, num: 3, name: 'AEW' }],
        name: '6th Mixed Wing',
      },
    ],
  },
  {
    name: 'Pingtung South AB',
    longitude: 120.46165747758,
    latitude: 22.673094464097,
    baseGUID: 'IC8B0X-0HNCTPETEF6F9',
    embarkedUnits: [
      {
        dbid: 2825,
        platformName: 'P-3C',
        type: 'Air',
        side: 'Taiwan',
        loadouts: [{ loadoutId: 13537, num: 3, name: 'ASW Patrol' }],
        name: '6th Mixed Wing',
      },
      {
        dbid: 4755,
        platformName: 'C-130HE',
        type: 'Air',
        side: 'Taiwan',
        loadouts: [{ loadoutId: 25876, num: 1, name: 'Electronic Warfare' }],
        name: '6th Mixed Wing',
      },
    ],
  },
  {
    name: 'Taitung/Jhihhang AB',
    longitude: 121.18112220849,
    latitude: 22.792770581932,
    baseGUID: '6Z8LM5-0HMIJ3QGCI3V3',
    embarkedUnits: [
      {
        dbid: 6889,
        platformName: 'F-16V Block 70',
        type: 'Air',
        side: 'Taiwan',
        loadouts: [{ loadoutId: 33012, num: 8, name: 'SLAM-ER' }],
        name: '7th Tactical Fighter Wing',
      },
    ],
    loadouts: [
      { num: 8, loadoutId: 33012, name: 'SLAM-ER' },
      { num: 8, loadoutId: 9479, name: 'JDAM' },
      { num: 8, loadoutId: 9326, name: 'HARM' },
      { num: 8, loadoutId: 9481, name: 'JSOW' },
    ],
  },
  {
    name: 'Jiashan AB',
    longitude: 121.59074054977,
    latitude: 24.02678653108,
    baseGUID: 'IC8B0X-0HNCTPETEF5C1',
    embarkedUnits: [
      {
        dbid: 6039,
        platformName: 'MQ-9B',
        type: 'Air',
        side: 'Taiwan',
        loadouts: [{ loadoutId: 32059, num: 3, name: 'Reconnaissance' }],
        name: '5th Tactical Mixed Wing',
      },
      {
        dbid: 3962,
        platformName: 'F-16V Block 20',
        type: 'Air',
        side: 'Taiwan',
        loadouts: [{ num: 8, loadoutId: 22789, name: 'Harpoon' }],
        name: '5th Tactical Mixed Wing',
      },
    ],
    loadouts: [
      { num: 8, loadoutId: 22785, name: 'AMRAAM' },
      { num: 8, loadoutId: 22789, name: 'Harpoon' },
      { num: 8, loadoutId: 22790, name: 'GBU' },
    ],
  },
  {
    name: 'Hsinchu AB',
    longitude: 120.94001989278,
    latitude: 24.818223765531,
    baseGUID: '6Z8LM5-0HMIK08HEK556',
    embarkedUnits: [
      {
        dbid: 175,
        platformName: 'Mirage 2000',
        type: 'Air',
        side: 'Taiwan',
        loadouts: [{ num: 8, loadoutId: 5732, name: 'MICA AAM' }],
        name: '2nd Tactical Fighter Wing',
      },
    ],
    loadouts: [{ num: 8, loadoutId: 5732, name: 'MICA AAM' }],
  },
  {
    name: 'Longtan AAB',
    longitude: 121.23728163269,
    latitude: 24.854988201865,
    baseGUID: 'IC8B0X-0HN3ADVRF2U7P',
    embarkedUnits: [
      {
        dbid: 2419,
        platformName: 'AH-64E',
        type: 'Air',
        side: 'Taiwan',
        loadouts: [{ loadoutId: 15213, num: 8, name: 'Hellfire' }],
        name: '601st Air Cavalry Bde',
      },
    ],
    loadouts: [{ num: 8, loadoutId: 15213, name: 'Hellfire' }],
  },
  {
    name: 'Taoyuan International Airport',
    longitude: 121.23018110638,
    latitude: 25.084411507528,
    baseGUID: '6Z8LM5-0HMJ1GE4HSIU5',
    embarkedUnits: [
      {
        dbid: 5035,
        platformName: 'Chung Shyang II',
        type: 'Air',
        side: 'Taiwan',
        loadouts: [{ loadoutId: 28116, num: 3, name: 'Reconnaissance' }],
        name: '1st Maritime Tactical Recon Sqn',
      },
    ],
  },
  {
    name: 'Rende Emergency Highway Strip',
    longitude: 120.24984614501,
    latitude: 22.951039712644,
    baseGUID: 'X58F5H-0HMU28MM77N82',
    loadouts: [{ num: 8, loadoutId: 19104, name: 'Wan Chien' }],
  },
  {
    name: 'Madou Emergency Highway Strip',
    longitude: 120.23609817812,
    latitude: 23.181856645595,
    baseGUID: 'X58F5H-0HMU28MM7836P',
    loadouts: [
      { num: 8, loadoutId: 22785, name: 'AMRAAM' },
      { num: 8, loadoutId: 22789, name: 'Harpoon' },
      { num: 8, loadoutId: 22790, name: 'GBU' },
    ],
  },
  {
    name: 'Minxiong Emergency Highway Strip',
    longitude: 120.41153010785,
    latitude: 23.543783221176,
    baseGUID: 'X58F5H-0HMU28MM78J9P',
    loadouts: [
      { num: 8, loadoutId: 22785, name: 'AMRAAM' },
      { num: 8, loadoutId: 22789, name: 'Harpoon' },
      { num: 8, loadoutId: 22790, name: 'GBU' },
    ],
  },
  {
    name: 'Tainan Field Airdrome',
    longitude: 120.21113094617,
    latitude: 23.203959723785,
    baseGUID: 'IC8B0X-0HN81FNLB6M8Q',
    loadouts: [{ num: 8, loadoutId: 7347, name: 'Hellfire' }],
  },
  {
    name: 'Hsinchu Field Airdrome',
    longitude: 121.04044915856,
    latitude: 24.812525208369,
    baseGUID: 'IC8B0X-0HN81FNLB2OPJ',
    loadouts: [{ num: 8, loadoutId: 15213, name: 'Hellfire' }],
  },
];

// ============================================================================
// MISSILE SYSTEMS DATA (Simplified - only firingUnits for UI)
// ============================================================================
export const MISSILE_SYSTEMS_DATA: MissileSystems = {
  srbm: {
    operationalAreas: {},
    reloadTime: 600,
    wpnDefault: 27,
    firingUnits: {
      'Rocket Arty Coy, 58th Arty Command': {
        dbid: 2446,
        resupplyUnit: 'Ammo Sec, Rocket Arty Coy, 58th Arty Command',
        guid: 'IC8B0X-0HN7SOIUF4D47',
        ammoThreshold: 25,
        weaponDBID: 1717,
        name: 'Rocket Arty Coy, 58th Arty Command',
        operationalArea: {
          RL: [],
          FP: [],
          AHA: [],
          HA: [],
        },
        state: 3,
        msg: 'Radio source, Bty',
      },
    },
    resupplyUnits: {},
    ammoThreshold: 25,
    ammunitions: {},
  },
  ascm: {
    operationalAreas: {},
    reloadTime: 2700,
    wpnDefault: 16,
    firingUnits: {
      '1st Hai Feng Shore-based ASM MOB Sqn': {
        dbid: 3531,
        resupplyUnit: 'Hai Feng Shore-based ASM SUPP Sqn, Dong',
        guid: 'X58F5H-0HMVEU1FUVO8I',
        ammoThreshold: 25,
        weaponDBID: 1133,
        name: '1st Hai Feng Shore-based ASM MOB Sqn',
        operationalArea: { RL: [], FP: [], AHA: [], HA: [] },
        state: 3,
        msg: 'Radio source, Bty',
      },
      // '2nd Hai Feng Shore-based ASM MOB Sqn': {
      //   dbid: 3531,
      //   resupplyUnit: 'Hai Feng Shore-based ASM SUPP Sqn, Luzhu',
      //   guid: 'IC8B0X-0HN87MOIE9C4U',
      //   ammoThreshold: 25,
      //   weaponDBID: 1133,
      //   name: '2nd Hai Feng Shore-based ASM MOB Sqn',
      //   operationalArea: { RL: [], FP: [], AHA: [], HA: [] },
      //   state: 3,
      //   msg: 'Radio source, Bty',
      // },
      // '3rd Hai Feng Shore-based ASM MOB Sqn': {
      //   dbid: 3531,
      //   resupplyUnit: 'Hai Feng Shore-based ASM SUPP Sqn, Dong',
      //   guid: 'X58F5H-0HMVEU1FUVO6J',
      //   ammoThreshold: 25,
      //   weaponDBID: 1133,
      //   name: '3rd Hai Feng Shore-based ASM MOB Sqn',
      //   operationalArea: { RL: [], FP: [], AHA: [], HA: [] },
      //   state: 3,
      //   msg: 'Radio source, Bty',
      // },
      // '4th Hai Feng Shore-based ASM MOB Sqn': {
      //   dbid: 3531,
      //   resupplyUnit: 'Hai Feng Shore-based ASM SUPP Sqn, Luzhu',
      //   guid: 'X58F5H-0HMVEU1FUVOLC',
      //   ammoThreshold: 25,
      //   weaponDBID: 1133,
      //   name: '4th Hai Feng Shore-based ASM MOB Sqn',
      //   operationalArea: { RL: [], FP: [], AHA: [], HA: [] },
      //   state: 3,
      //   msg: 'Radio source, Bty',
      // },
      // '5th Hai Feng Shore-based ASM MOB Sqn': {
      //   dbid: 3531,
      //   resupplyUnit: 'Hai Feng Shore-based ASM SUPP Sqn, Luzhu',
      //   guid: 'IC8B0X-0HN8CEO4EUE8B',
      //   ammoThreshold: 25,
      //   weaponDBID: 1133,
      //   name: '5th Hai Feng Shore-based ASM MOB Sqn',
      //   operationalArea: { RL: [], FP: [], AHA: [], HA: [] },
      //   state: 3,
      //   msg: 'Radio source, Bty',
      // },
      // '6th Hai Feng Shore-based ASM MOB Sqn': {
      //   dbid: 3531,
      //   resupplyUnit: 'Hai Feng Shore-based ASM SUPP Sqn, Dong',
      //   guid: 'IC8B0X-0HNHAETCJHDEA',
      //   ammoThreshold: 25,
      //   weaponDBID: 1133,
      //   name: '6th Hai Feng Shore-based ASM MOB Sqn',
      //   operationalArea: { RL: [], FP: [], AHA: [], HA: [] },
      //   state: 3,
      //   msg: 'Radio source, Bty',
      // },
    },
    resupplyUnits: {},
    ammoThreshold: 25,
    ammunitions: {},
  },
};
