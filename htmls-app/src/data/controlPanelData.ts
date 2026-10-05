import type { Airbase, Jammer, MissileSystems, AmphibiousLocation } from '@/types/controlPanel';

// ============================================================================
// JAMMERS DATA
// ============================================================================
export const JAMMERS_DATA: Jammer[] = [
  {
    zoneName: 'JAMMING ZONE/1',
    name: 'Comm and Info Coy, 584th Mech Bde',
    randomRadiusNm: 20,
    radius: 11,
  },
  {
    zoneName: 'JAMMING ZONE/2',
    name: 'Comm and Info Coy, 269th Mech Bde',
    randomRadiusNm: 20,
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
  sam: {
    firingUnits: {
      '1st Coy, 613rd Bn, 792nd AFAD & Arty Bde': {
        name: '1st Coy, 613rd Bn, 792nd AFAD & Arty Bde',
        operationalArea: {
          RL: [
            {
              course: [{ latitude: 23.963022356482984, longitude: 120.53858344139019 }],
              area: [
                { latitude: 23.961356812968535, longitude: 120.54040605885487 },
                { latitude: 23.961356812968535, longitude: 120.53676082392549 },
                { latitude: 23.96468789999743, longitude: 120.53676077682854 },
                { latitude: 23.96468789999743, longitude: 120.54040610595182 },
              ],
            },
          ],
          FP: [
            {
              course: [
                { latitude: 23.946720847060654, longitude: 120.52351359314495 },
                { latitude: 23.925810998868357, longitude: 120.49152295884694 },
              ],
              area: [
                { latitude: 23.925176455038955, longitude: 120.49532538653906 },
                { latitude: 23.92233531417852, longitude: 120.49082880718687 },
                { latitude: 23.926445497482927, longitude: 120.4877204937881 },
                { latitude: 23.92928672877303, longitude: 120.49221714787369 },
              ],
            },
            {
              course: [
                { latitude: 23.946720847060654, longitude: 120.52351359314495 },
                { latitude: 23.935372343642182, longitude: 120.48586452509319 },
              ],
              area: [
                { latitude: 23.934001272274976, longitude: 120.48942714400938 },
                { latitude: 23.93211607921884, longitude: 120.48436450934267 },
                { latitude: 23.936743381218047, longitude: 120.48230183049377 },
                { latitude: 23.938628641856866, longitude: 120.48736461652692 },
              ],
            },
          ],
          AHA: [
            {
              course: [{ latitude: 23.95416361550089, longitude: 120.66407514630362 }],
              area: [
                { latitude: 23.95166530022992, longitude: 120.6668088670367 },
                { latitude: 23.95166530022992, longitude: 120.66134142557051 },
                { latitude: 23.956661930771855, longitude: 120.66134131965377 },
                { latitude: 23.956661930771855, longitude: 120.66680897295345 },
              ],
            },
          ],
          HA: [
            {
              course: [{ latitude: 23.95115249996755, longitude: 120.53942497864303 }],
              area: [
                { latitude: 23.949486956453104, longitude: 120.54124742835427 },
                { latitude: 23.949486956453104, longitude: 120.5376025289318 },
                { latitude: 23.95281804348199, longitude: 120.53760248186548 },
                { latitude: 23.95281804348199, longitude: 120.54124747542058 },
              ],
            },
          ],
          SHRL: [
            {
              course: [
                { latitude: 23.963022191638004, longitude: 120.53144924355222 },
                { latitude: 23.963022356482984, longitude: 120.53858344139019 },
              ],
              area: [
                { latitude: 23.961356812968535, longitude: 120.54040605885487 },
                { latitude: 23.961356812968535, longitude: 120.53676082392549 },
                { latitude: 23.96468789999743, longitude: 120.53676077682854 },
                { latitude: 23.96468789999743, longitude: 120.54040610595182 },
              ],
            },
          ],
          uShapeVertices: [
            { latitude: 23.966707310096808, longitude: 120.55016922173337 },
            { latitude: 23.941724157689617, longitude: 120.55016657380727 },
            { latitude: 23.941724157689617, longitude: 120.52283147306775 },
            { latitude: 23.966707310096808, longitude: 120.52282882514166 },
          ],
          shelterPoints: [
            { latitude: 23.948770249240464, longitude: 120.54668912131177 },
            { latitude: 23.943869164377904, longitude: 120.53845933003232 },
          ],
        },
        missileSystem: 'PAC-3',
        weaponRange: 65,
      },
    },
  },
  srbm: {
    firingUnits: {
      'Rocket Arty Coy, 58th Arty Command': {
        name: 'Rocket Arty Coy, 58th Arty Command',
        operationalArea: {
          RL: [
            {
              course: [{ latitude: 23.806603553624733, longitude: 120.4059782850404 }],
              area: [
                { latitude: 23.80493801011028, longitude: 120.40779870061961 },
                { latitude: 23.80493801011028, longitude: 120.4041578694612 },
                { latitude: 23.80826909713918, longitude: 120.40415782276673 },
                { latitude: 23.80826909713918, longitude: 120.40779874731409 },
              ],
            },
          ],
          FP: [
            {
              course: [
                { latitude: 23.79832944742452, longitude: 120.4026796129023 },
                { latitude: 23.802577911741974, longitude: 120.3612365455408 },
              ],
              area: [
                { latitude: 23.799876684564097, longitude: 120.36372560442521 },
                { latitude: 23.800300517029257, longitude: 120.35828424328788 },
                { latitude: 23.80527914704259, longitude: 120.3587473831287 },
                { latitude: 23.804855298331958, longitude: 120.36418895132145 },
              ],
            },
            {
              course: [
                { latitude: 23.79832944742452, longitude: 120.4026796129023 },
                { latitude: 23.79298295201252, longitude: 120.36135442758274 },
              ],
              area: [
                { latitude: 23.790766854389595, longitude: 120.36436171641414 },
                { latitude: 23.790231213611374, longitude: 120.35893254388633 },
                { latitude: 23.795199039396785, longitude: 120.35834703618046 },
                { latitude: 23.795734700652314, longitude: 120.36377641385002 },
              ],
            },
          ],
          AHA: [
            {
              course: [{ latitude: 23.798277652191537, longitude: 120.54307198810082 }],
              area: [
                { latitude: 23.79577933692056, longitude: 120.5458024189589 },
                { latitude: 23.79577933692056, longitude: 120.54034155724275 },
                { latitude: 23.80077596746251, longitude: 120.54034145222829 },
                { latitude: 23.80077596746251, longitude: 120.54580252397335 },
              ],
            },
          ],
          HA: [
            {
              course: [{ latitude: 23.806559362575843, longitude: 120.42303920983716 }],
              area: [
                { latitude: 23.804893819061395, longitude: 120.42485962479697 },
                { latitude: 23.804893819061395, longitude: 120.42121879487733 },
                { latitude: 23.80822490609029, longitude: 120.42121874818297 },
                { latitude: 23.80822490609029, longitude: 120.4248596714913 },
              ],
            },
          ],
          SHRL: [
            {
              course: [
                { latitude: 23.80944677778654, longitude: 120.40908603088032 },
                { latitude: 23.806603553624733, longitude: 120.4059782850404 },
              ],
              area: [
                { latitude: 23.80493801011028, longitude: 120.40779870061961 },
                { latitude: 23.80493801011028, longitude: 120.4041578694612 },
                { latitude: 23.80826909713918, longitude: 120.40415782276673 },
                { latitude: 23.80826909713918, longitude: 120.40779874731409 },
              ],
            },
          ],
          uShapeVertices: [
            { latitude: 23.810820965076836, longitude: 120.42930314935944 },
            { latitude: 23.78583781266794, longitude: 120.42930052399022 },
            { latitude: 23.78583781266794, longitude: 120.40199830413479 },
            { latitude: 23.810820965076836, longitude: 120.40199567876557 },
          ],
          shelterPoints: [
            { latitude: 23.801503300471502, longitude: 120.41353863214489 },
            { latitude: 23.801672159940395, longitude: 120.41768774016136 },
          ],
        },
        missileSystem: 'HIMARS',
        weaponRange: 150,
      },
    },
  },
  ascm: {
    firingUnits: {
      '1st Hai Feng Shore-based ASM MOB Sqn': {
        name: '1st Hai Feng Shore-based ASM MOB Sqn',
        operationalArea: {
          RL: [
            {
              course: [{ latitude: 23.679917918891974, longitude: 120.36842468141906 }],
              area: [
                { latitude: 23.678252375377525, longitude: 120.37024332748199 },
                { latitude: 23.678252375377525, longitude: 120.36660603535613 },
                { latitude: 23.68158346240643, longitude: 120.36660598898607 },
                { latitude: 23.68158346240643, longitude: 120.37024337385202 },
              ],
            },
          ],
          FP: [
            {
              course: [
                { latitude: 23.67251795084056, longitude: 120.35874632151304 },
                { latitude: 23.65890263488067, longitude: 120.32107513473466 },
              ],
              area: [
                { latitude: 23.657515300922565, longitude: 120.32462265266865 },
                { latitude: 23.655653265493285, longitude: 120.31956055208894 },
                { latitude: 23.660289935829223, longitude: 120.3175275415345 },
                { latitude: 23.662152037277586, longitude: 120.32258979264651 },
              ],
            },
            {
              course: [
                { latitude: 23.67251795084056, longitude: 120.35874632151304 },
                { latitude: 23.702882348519097, longitude: 120.32469463038714 },
              ],
              area: [
                { latitude: 23.69946175035845, longitude: 120.32566070671511 },
                { latitude: 23.701997724000687, longitude: 120.32095889687774 },
                { latitude: 23.706302988509798, longitude: 120.32372850341513 },
                { latitude: 23.703766931207454, longitude: 120.3284304145406 },
              ],
            },
          ],
          AHA: [
            {
              course: [{ latitude: 23.677463081689957, longitude: 120.49900857387644 }],
              area: [
                { latitude: 23.674964766418974, longitude: 120.50173647433576 },
                { latitude: 23.674964766418974, longitude: 120.49628067341712 },
                { latitude: 23.67996139696094, longitude: 120.49628056909866 },
                { latitude: 23.67996139696094, longitude: 120.50173657865425 },
              ],
            },
          ],
          HA: [
            {
              course: [{ latitude: 23.669039555413118, longitude: 120.38140924101904 }],
              area: [
                { latitude: 23.667374011898666, longitude: 120.38322773571016 },
                { latitude: 23.667374011898666, longitude: 120.37959074632792 },
                { latitude: 23.670705098927566, longitude: 120.37959069998568 },
                { latitude: 23.670705098927566, longitude: 120.3832277820524 },
              ],
            },
          ],
          SHRL: [
            {
              course: [
                { latitude: 23.683938889127205, longitude: 120.36842468141904 },
                { latitude: 23.679917918891974, longitude: 120.36842468141906 },
              ],
              area: [
                { latitude: 23.678252375377525, longitude: 120.37024332748199 },
                { latitude: 23.678252375377525, longitude: 120.36660603535613 },
                { latitude: 23.68158346240643, longitude: 120.36660598898607 },
                { latitude: 23.68158346240643, longitude: 120.37024337385202 },
              ],
            },
          ],
          uShapeVertices: [
            { latitude: 23.690006099372084, longitude: 120.38534517435718 },
            { latitude: 23.66502294696188, longitude: 120.3853425663875 },
            { latitude: 23.66502294696188, longitude: 120.35806563673752 },
            { latitude: 23.690006099372084, longitude: 120.35806302876783 },
          ],
          shelterPoints: [
            { latitude: 23.681035548170605, longitude: 120.3820677948902 },
            { latitude: 23.685636542906167, longitude: 120.36564943890005 },
          ],
        },
        missileSystem: 'HF-3',
        weaponRange: 100,
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
  },
};

// ============================================================================
// AMPHIBIOUS LOCATION DATA
// ============================================================================
export const AMPHIBIOUS_LOCATION_DATA: AmphibiousLocation[] = [
  {
    name: 'Taoyuan',
    waypoints: [
      {
        latitude: 30.1,
        longitude: 122.3,
      },
      {
        latitude: 27.0,
        longitude: 121.5,
      },
      {
        latitude: 25.09,
        longitude: 121.24,
      },
    ],
  },
  {
    name: 'Sishu',
    waypoints: [
      {
        latitude: 25.3,
        longitude: 119.5,
      },
      {
        latitude: 23.31,
        longitude: 120.18,
      },
    ],
  },
  {
    name: 'Penghu',
    waypoints: [
      {
        latitude: 23.78,
        longitude: 117.84,
      },
      {
        latitude: 23.53,
        longitude: 119.55,
      },
    ],
  },
];
