local CONFIG = require('src.core.constants')

---@class SBJ__SaveData
local SaveData = {}
SaveData.c = {}
SaveData.c.targetlist = {}
SaveData.c.air = {}
SaveData.c.air.landBased = {}
SaveData.c.air.shipBased = {}
SaveData.c.ground = {}
SaveData.c.ground.mlrs = {}
SaveData.c.ground.srbm = {}
SaveData.c.ground.mrbm = {}
SaveData.c.ground.glcm = {}
SaveData.c.ground.ascm = {}
SaveData.c.surface = {}
SaveData.c.surface.lacm = {}
SaveData.c.subSurface = {}
SaveData.c.subSurface.slcm = {}
SaveData.c.PHIBOP = {}
SaveData.c.recon = {}
SaveData.c.GPSJamming = {}
SaveData.c.commsJamming = {}
SaveData.c.repairRunway = {}
SaveData.c.IADS = {}
SaveData.c.SIGINT = {}
SaveData.t = {}
SaveData.t.ground = {}
SaveData.t.ground.mlrs = {}
SaveData.t.ground.glcm = {}
SaveData.t.ground.srbm = {}
SaveData.t.ground.ascm = {}
SaveData.t.repairRunway = {}
SaveData.t.IADS = {}
SaveData.t.air = {}
SaveData.t.air.landBased = {}
SaveData.u = {}
SaveData.u.SIGINT = {}
SaveData.s = {}

-- SIGINT
SaveData.c.SIGINT.isActivated = true
SaveData.c.SIGINT.RA = {}
SaveData.c.SIGINT.transmissions = {
  -- [''] = {
  --     name = '',
  --     latitude = 0,
  --     longitude = 0,
  --     contacts = { { guid = '' } }
  -- },
}


-- IADS
SaveData.c.IADS.isActivated = true
SaveData.c.IADS.C2 = {
  -- ['IC8B0X-0HN84DHD12BBJ'] = {
  --     name = '#A C2/IADS',
  --     msg = 'Radio source, C2/IADS',
  --     guid = 'IC8B0X-0HN84DHD12BBJ',
  --     area = { 'RP-85130', 'RP-85131', 'RP-85132', 'RP-85133', },
  --     radar = {},
  --     SAM = {},
  -- },
  -- ['IC8B0X-0HN84DHD12B7R'] = {
  --     name = '#B C2/IADS',
  --     msg = 'Radio source, C2/IADS',
  --     guid = 'IC8B0X-0HN84DHD12B7R',
  --     area = { 'RP-85134', 'RP-85135', 'RP-85136', 'RP-85137', },
  --     radar = {},
  --     SAM = {},
  -- },
  -- ['IC8B0X-0HN84DHD12B41'] = {
  --     name = '#C C2/IADS',
  --     msg = 'Radio source, C2/IADS',
  --     guid = 'IC8B0X-0HN84DHD12B41',
  --     area = { 'RP-85138', 'RP-85139', 'RP-85140', 'RP-85141', },
  --     radar = {},
  --     SAM = {},
  -- },
}

-- Comms jamming
SaveData.c.commsJamming.isActivated = true
SaveData.c.commsJamming.jammers = {
  -- { guid = '' },
}

-- GPS Jamming
SaveData.c.GPSJamming.isActivated = true
-- CONFIG.c.GPSJamming.GPSGuidedWeapons = {
--     { dbid = 779,  jammingResistance = 33 }, -- ATACMS
--     { dbid = 452,  jammingResistance = 33 }, -- SLAM-ER
--     { dbid = 826,  jammingResistance = 33 }, -- JSOW
--     { dbid = 870,  jammingResistance = 33 }, -- JDAM BLU-109
--     { dbid = 554,  jammingResistance = 33 }, -- JDAM
--     { dbid = 3026, jammingResistance = 66 }, -- WC
--     { dbid = 1717, jammingResistance = 33 }, -- ATACMS M57
-- }


-- MLRS
SaveData.c.ground.mlrs.isActivated = true
SaveData.c.ground.mlrs.ammunitions = {
  ['IC8B0X-0HN9ASEFCGDKF'] = {
    guid = 'IC8B0X-0HN9ASEFCGDKF',
    wpnCurrent = CONFIG.c.ground.mlrs.wpnDefault,
    wpnDefault = CONFIG.c.ground.mlrs.wpnDefault,
  },
  ['IC8B0X-0HNBRRE2PRT40'] = {
    guid = 'IC8B0X-0HNBRRE2PRT40',
    wpnCurrent = CONFIG.c.ground.mlrs.wpnDefault,
    wpnDefault = CONFIG.c.ground.mlrs.wpnDefault,
  },
}
SaveData.c.ground.mlrs.ammunitionSections = {
  ['IC8B0X-0HN7R5QOERV4D'] = {
    guid = 'IC8B0X-0HN7R5QOERV4D',
    name = 'Ammo Sec, 1st Bn, 1st Rockets Arty Bde',
    wpnCurrent = CONFIG.c.ground.mlrs.wpnDefault,
    wpnDefault = CONFIG.c.ground.mlrs.wpnDefault,
    unitCount = 3,
    position = CONFIG.c.ground.mlrs.positions.pingtan,
    reloadStartTime = nil,
    state = CONFIG.batteryState.STATIC,
    ammunition = 'IC8B0X-0HN9ASEFCGDKF',
  },
  ['IC8B0X-0HNBRRE2PRRG9'] = {
    guid = 'IC8B0X-0HNBRRE2PRRG9',
    name = 'Ammo Sec, 6th Bn, 73rd Arty Bde',
    wpnCurrent = CONFIG.c.ground.mlrs.wpnDefault,
    wpnDefault = CONFIG.c.ground.mlrs.wpnDefault,
    unitCount = 3,
    position = CONFIG.c.ground.mlrs.positions.chinchew,
    reloadStartTime = nil,
    state = CONFIG.batteryState.STATIC,
    ammunition = 'IC8B0X-0HNBRRE2PRT40',
  },
}
SaveData.c.ground.mlrs.batteries = {
  ['IC8B0X-0HND05GGU36EN'] = {
    name = '1st Bn, 1st Rockets Arty Bde',
    msg = 'Radio source, Bty',
    guid = 'IC8B0X-0HND05GGU36EN',
    reloadStartTime = nil,
    state = CONFIG.batteryState.HIDE,
    position = CONFIG.c.ground.mlrs.positions.pingtan,
    weaponDBID = 4472,
    ammoThreshold = CONFIG.c.ground.mlrs.ammoThreshold,
    ammunitionSection = 'IC8B0X-0HN7R5QOERV4D'
  },
  ['IC8B0X-0HNBRRE2PRQAL'] = {
    name = '6th Bn, 73rd Arty Bde',
    msg = 'Radio source, Bty',
    guid = 'IC8B0X-0HNBRRE2PRQAL',
    reloadStartTime = nil,
    state = CONFIG.batteryState.HIDE,
    position = CONFIG.c.ground.mlrs.positions.chinchew,
    weaponDBID = 4472,
    ammoThreshold = CONFIG.c.ground.mlrs.ammoThreshold,
    ammunitionSection = 'IC8B0X-0HNBRRE2PRRG9'
  },
}


-- GLCM
SaveData.c.ground.glcm.isActivated = true
SaveData.c.ground.glcm.ammunitions = {
  ['IC8B0X-0HN99I5RL5KR9'] = {
    guid = 'IC8B0X-0HN99I5RL5KR9',
    wpnCurrent = CONFIG.c.ground.glcm.wpnDefault,
    wpnDefault = CONFIG.c.ground.glcm.wpnDefault,
  },
}
SaveData.c.ground.glcm.ammunitionSections = {
  ['IC8B0X-0HN7R5QOIVG88'] = {
    guid = 'IC8B0X-0HN7R5QOIVG88',
    name = 'Ammo Sec, 635th Bde, PLARF',
    wpnCurrent = CONFIG.c.ground.glcm.wpnDefault,
    wpnDefault = CONFIG.c.ground.glcm.wpnDefault,
    unitCount = 8,
    position = CONFIG.c.ground.glcm.positions.brigade635,
    reloadStartTime = nil,
    state = CONFIG.batteryState.STATIC,
    ammunition = 'IC8B0X-0HN99I5RL5KR9',
  },
}


SaveData.c.ground.glcm.batteries = {
  ---@type SBJ__Battery
  ['6Z8LM5-0HMN97ERAUODK'] = {
    guid = '6Z8LM5-0HMN97ERAUODK',
    name = '635th Bde',
    msg = 'Radio source, Bty',
    reloadStartTime = nil,
    state = CONFIG.batteryState.HIDE,
    position = CONFIG.c.ground.glcm.positions.brigade635,
    weaponDBID = 2122,
    ammoThreshold = CONFIG.c.ground.glcm.ammoThreshold,
    ammunitionSection = 'IC8B0X-0HN7R5QOIVG88'
  },
}


-- SRBM
SaveData.c.ground.srbm.isActivated = true
SaveData.c.ground.srbm.ammunitions = {
  ['IC8B0X-0HN9ASEFCG848'] = {
    guid = 'IC8B0X-0HN9ASEFCG848',
    wpnCurrent = CONFIG.c.ground.srbm.wpnDefault * 2,
    wpnDefault = CONFIG.c.ground.srbm.wpnDefault * 2,
  },
  ['IC8B0X-0HN9ASEFCG95Q'] = {
    guid = 'IC8B0X-0HN9ASEFCG95Q',
    wpnCurrent = CONFIG.c.ground.srbm.wpnDefault * 2,
    wpnDefault = CONFIG.c.ground.srbm.wpnDefault * 2,
  },
  ['IC8B0X-0HN9ASEFCG8CT'] = {
    guid = 'IC8B0X-0HN9ASEFCG8CT',
    wpnCurrent = CONFIG.c.ground.srbm.wpnDefault * 2,
    wpnDefault = CONFIG.c.ground.srbm.wpnDefault * 2,
  },
  ['IC8B0X-0HN9ASEFCG8OK'] = {
    guid = 'IC8B0X-0HN9ASEFCG8OK',
    wpnCurrent = CONFIG.c.ground.srbm.wpnDefault * 2,
    wpnDefault = CONFIG.c.ground.srbm.wpnDefault * 2,
  },
  ['IC8B0X-0HN9ASEFCG9GA'] = {
    guid = 'IC8B0X-0HN9ASEFCG9GA',
    wpnCurrent = CONFIG.c.ground.srbm.wpnDefault * 2,
    wpnDefault = CONFIG.c.ground.srbm.wpnDefault * 2,
  },
  ['IC8B0X-0HN9ASEFCGA5A'] = {
    guid = 'IC8B0X-0HN9ASEFCGA5A',
    wpnCurrent = CONFIG.c.ground.srbm.wpnDefault * 2,
    wpnDefault = CONFIG.c.ground.srbm.wpnDefault * 2,
  },
}
SaveData.c.ground.srbm.ammunitionSections = {
  ['IC8B0X-0HN7R5QOIVL7D'] = {
    guid = 'IC8B0X-0HN7R5QOIVL7D',
    name = 'Ammo Sec, 615th Bde, PLARF',
    wpnCurrent = CONFIG.c.ground.srbm.wpnDefault,
    wpnDefault = CONFIG.c.ground.srbm.wpnDefault,
    unitCount = 9,
    position = CONFIG.c.ground.srbm.positions.brigade615,
    reloadStartTime = nil,
    state = CONFIG.batteryState.STATIC,
    ammunition = 'IC8B0X-0HN9ASEFCG848',
  },
  ['IC8B0X-0HN7R5QOIVLSG'] = {
    guid = 'IC8B0X-0HN7R5QOIVLSG',
    name = 'Ammo Sec, 614th Bde, PLARF',
    wpnCurrent = CONFIG.c.ground.srbm.wpnDefault,
    wpnDefault = CONFIG.c.ground.srbm.wpnDefault,
    unitCount = 9,
    position = CONFIG.c.ground.srbm.positions.brigade614,
    reloadStartTime = nil,
    state = CONFIG.batteryState.STATIC,
    ammunition = 'IC8B0X-0HN9ASEFCG95Q',
  },
  ['IC8B0X-0HN7R5QOIVMO1'] = {
    guid = 'IC8B0X-0HN7R5QOIVMO1',
    name = 'Ammo Sec, 636th Bde, PLARF',
    wpnCurrent = CONFIG.c.ground.srbm.wpnDefault,
    wpnDefault = CONFIG.c.ground.srbm.wpnDefault,
    unitCount = 9,
    position = CONFIG.c.ground.srbm.positions.brigade636,
    reloadStartTime = nil,
    state = CONFIG.batteryState.STATIC,
    ammunition = 'IC8B0X-0HN9ASEFCG8CT',
  },
  ['IC8B0X-0HN7R5QOIVOSN'] = {
    guid = 'IC8B0X-0HN7R5QOIVOSN',
    name = 'Ammo Sec, 616th Bde, PLARF',
    wpnCurrent = CONFIG.c.ground.srbm.wpnDefault,
    wpnDefault = CONFIG.c.ground.srbm.wpnDefault,
    unitCount = 9,
    position = CONFIG.c.ground.srbm.positions.brigade616,
    reloadStartTime = nil,
    state = CONFIG.batteryState.STATIC,
    ammunition = 'IC8B0X-0HN9ASEFCG8OK',
  },
  ['IC8B0X-0HN7R5QOIVPNC'] = {
    guid = 'IC8B0X-0HN7R5QOIVPNC',
    name = 'Ammo Sec, 613rd Bde, PLARF',
    wpnCurrent = CONFIG.c.ground.srbm.wpnDefault,
    wpnDefault = CONFIG.c.ground.srbm.wpnDefault,
    unitCount = 9,
    position = CONFIG.c.ground.srbm.positions.brigade613,
    reloadStartTime = nil,
    state = CONFIG.batteryState.STATIC,
    ammunition = 'IC8B0X-0HN9ASEFCG9GA',
  },
  ['IC8B0X-0HN7R5QOIVQ6P'] = {
    guid = 'IC8B0X-0HN7R5QOIVQ6P',
    name = 'Ammo Sec, 617th Bde, PLARF',
    wpnCurrent = CONFIG.c.ground.srbm.wpnDefault,
    wpnDefault = CONFIG.c.ground.srbm.wpnDefault,
    unitCount = 9,
    position = CONFIG.c.ground.srbm.positions.brigade617,
    reloadStartTime = nil,
    state = CONFIG.batteryState.STATIC,
    ammunition = 'IC8B0X-0HN9ASEFCGA5A',
  },
}
SaveData.c.ground.srbm.batteries = {
  ['X58F5H-0HN1G2IFLNKG9'] = {
    guid = 'X58F5H-0HN1G2IFLNKG9',
    name = '615th Bde',
    msg = 'Radio source, Bty',
    reloadStartTime = nil,
    state = CONFIG.batteryState.HIDE,
    position = CONFIG.c.ground.srbm.positions.brigade615,
    weaponDBID = 2142,
    ammoThreshold = CONFIG.c.ground.srbm.ammoThreshold,
    ammunitionSection = 'IC8B0X-0HN7R5QOIVL7D'
  },
  ['X58F5H-0HN1LQGRV8HNQ'] = {
    guid = 'X58F5H-0HN1LQGRV8HNQ',
    name = '614th Bde',
    msg = 'Radio source, Bty',
    reloadStartTime = nil,
    state = CONFIG.batteryState.HIDE,
    position = CONFIG.c.ground.srbm.positions.brigade614,
    weaponDBID = 2142,
    ammoThreshold = CONFIG.c.ground.srbm.ammoThreshold,
    ammunitionSection = 'IC8B0X-0HN7R5QOIVLSG'
  },
  ['IC8B0X-0HN822OHANPB3'] = {
    guid = 'IC8B0X-0HN822OHANPB3',
    name = '636th Bde',
    msg = 'Radio source, Bty',
    reloadStartTime = nil,
    state = CONFIG.batteryState.HIDE,
    position = CONFIG.c.ground.srbm.positions.brigade636,
    weaponDBID = 4511,
    ammoThreshold = CONFIG.c.ground.srbm.ammoThreshold,
    ammunitionSection = 'IC8B0X-0HN7R5QOIVMO1'
  },
  ['X58F5H-0HN1G2IFLF6QE'] = {
    guid = 'X58F5H-0HN1G2IFLF6QE',
    name = '616th Bde',
    msg = 'Radio source, Bty',
    reloadStartTime = nil,
    state = CONFIG.batteryState.HIDE,
    position = CONFIG.c.ground.srbm.positions.brigade616,
    weaponDBID = 2145,
    ammoThreshold = CONFIG.c.ground.srbm.ammoThreshold,
    ammunitionSection = 'IC8B0X-0HN7R5QOIVOSN'
  },
  ['X58F5H-0HN1G2DEBC7O8'] = {
    guid = 'X58F5H-0HN1G2DEBC7O8',
    name = '613rd Bde',
    msg = 'Radio source, Bty',
    reloadStartTime = nil,
    state = CONFIG.batteryState.HIDE,
    position = CONFIG.c.ground.srbm.positions.brigade613,
    weaponDBID = 40,
    ammoThreshold = CONFIG.c.ground.srbm.ammoThreshold,
    ammunitionSection = 'IC8B0X-0HN7R5QOIVPNC'
  },
  ['IC8B0X-0HN822OHANRHI'] = {
    guid = 'IC8B0X-0HN822OHANRHI',
    name = '617th Bde',
    msg = 'Radio source, Bty',
    reloadStartTime = nil,
    state = CONFIG.batteryState.HIDE,
    position = CONFIG.c.ground.srbm.positions.brigade617,
    weaponDBID = 4511,
    ammoThreshold = CONFIG.c.ground.srbm.ammoThreshold,
    ammunitionSection = 'IC8B0X-0HN7R5QOIVQ6P'
  },
}

-- MRBM
SaveData.c.ground.mrbm.isActivated = true
SaveData.c.ground.mrbm.ammunitions = {
  ['IC8B0X-0HNCOR6HG2KK5'] = {
    guid = 'IC8B0X-0HNCOR6HG2KK5',
    wpnCurrent = CONFIG.c.ground.mrbm.wpnDefault * 2,
    wpnDefault = CONFIG.c.ground.mrbm.wpnDefault * 2,
  },
}
SaveData.c.ground.mrbm.ammunitionSections = {
  ['IC8B0X-0HNCOR6HG2KF9'] = {
    guid = 'IC8B0X-0HNCOR6HG2KF9',
    name = 'Ammo Sec, 624th Bde, PLARF',
    wpnCurrent = CONFIG.c.ground.mrbm.wpnDefault,
    wpnDefault = CONFIG.c.ground.mrbm.wpnDefault,
    unitCount = 6,
    position = CONFIG.c.ground.mrbm.positions.brigade624,
    reloadStartTime = nil,
    state = CONFIG.batteryState.STATIC,
    ammunition = 'IC8B0X-0HNCOR6HG2KK5',
  },
}
SaveData.c.ground.mrbm.batteries = {
  ['IC8B0X-0HNCOR6HG2JE1'] = {
    guid = 'IC8B0X-0HNCOR6HG2JE1',
    name = '624th Bde',
    msg = 'Radio source, Bty',
    reloadStartTime = nil,
    state = CONFIG.batteryState.HIDE,
    position = CONFIG.c.ground.mrbm.positions.brigade624,
    weaponDBID = 2105,
    ammoThreshold = CONFIG.c.ground.mrbm.ammoThreshold,
    ammunitionSection = 'IC8B0X-0HNCOR6HG2KF9'
  },
}

-- Recon
SaveData.c.recon.isActivated = true
SaveData.c.recon.temp = {
  H6N = {},
  WZ8 = {},
  BZK005 = {}
}
SaveData.c.recon.queue = {
  {
    baseGUID = CONFIG.c.recon.bases.H6N.guid,
    unitDBID = CONFIG.platformDBID76,
    unitGUID = nil,
    missionName = nil,
    course = CONFIG.c.recon.courses.H6N,
    unitCount = 1,
    -- takeoffTime = '2027-06-09 01:20:00',
    takeoffTime = '2027-06-09 01:00:00',
    missionStartTime = nil,
    hasLaunched = false,
    isTracking = true
  },
}

-- Fire support plan
SaveData.c.ground.isActivated = true
SaveData.c.ground.FSP = {
  ['STRIKE/INFRASTRUCTURE/1'] = {
    name = 'STRIKE/INFRASTRUCTURE/1',
    isActivated = true,
    isFirstWave = true,
    strikeInterval = 0 * 60,
    reconUAVs = nil,
    allBatteriesInPosition = false,
    isFinished = false,
    -- Fire support task
    ---@type SBJ__FireSupportTask[]
    FSTs = {
      {
        name = 'RADAR',
        wpnSystem = 'SRBM',
        batteries = {
          {
            name = '614th Bde',
            guid = 'X58F5H-0HN1LQGRV8HNQ',
            weaponDBID = SaveData.c.ground.srbm.batteries['X58F5H-0HN1LQGRV8HNQ'].weaponDBID
          },
          {
            name = '613rd Bde',
            guid = 'X58F5H-0HN1G2DEBC7O8',
            weaponDBID = SaveData.c.ground.srbm.batteries['X58F5H-0HN1G2DEBC7O8'].weaponDBID
          }
        },
        target = {
          list = {},
          evaluatedlist = {},
          objs = {
            { baseName = nil, subTypes = { 'Radar', 'Hengshan ROC command', 'Sky Bow' } },
          },
          areas = {},
          filterNames = nil,
          contactAge = CONFIG.c.ground.srbm.contactAge,
          minTargetCount = 4,
          ammoPerTarget = 3
        },
        startTime = '2027-06-09 01:00:00',
        isFinished = false
      },
      -- {
      --   name = 'RADAR',
      --   wpnSystem = 'SRBM',
      --   queryParams = {
      --     { baseName = nil, subTypes = { 'Radar', 'Hengshan ROC command', 'Sky Bow' } },
      --   },
      --   targetlist = {},
      --   evaluatedTargetlist = {},
      --   batteries = {
      --     {
      --       name = '614th Bde',
      --       guid = 'X58F5H-0HN1LQGRV8HNQ',
      --       weaponDBID = SaveData.c.ground.srbm.batteries['X58F5H-0HN1LQGRV8HNQ'].weaponDBID
      --     },
      --     {
      --       name = '613rd Bde',
      --       guid = 'X58F5H-0HN1G2DEBC7O8',
      --       weaponDBID = SaveData.c.ground.srbm.batteries['X58F5H-0HN1G2DEBC7O8'].weaponDBID
      --     }
      --   },
      --   areas = nil,
      --   startTime = '2027-06-09 01:00:00',
      --   contactAge = CONFIG.c.ground.srbm.contactAge,
      --   ammoPerTarget = 3,
      --   minTargetCount = 4,
      --   filterNames = nil,
      --   isFinished = false
      -- },
      {
        name = 'RUNWAY',
        wpnSystem = 'SRBM',
        batteries = {
          {
            name = '636th Bde',
            guid = 'IC8B0X-0HN822OHANPB3',
            weaponDBID = SaveData.c.ground.srbm.batteries['IC8B0X-0HN822OHANPB3'].weaponDBID
          },
          {
            name = '617th Bde',
            guid = 'IC8B0X-0HN822OHANRHI',
            weaponDBID = SaveData.c.ground.srbm.batteries['IC8B0X-0HN822OHANRHI'].weaponDBID
          }
        },
        target = {
          list = {},
          evaluatedlist = {},
          objs = {
            { baseName = 'Hualien AB',           subTypes = { 'Runway %(%d+m%)', 'Taxiway' } },
            { baseName = 'Taitung/Jhihhang AB',  subTypes = { 'Runway %(%d+m%)', 'Taxiway' } },
            { baseName = 'Ching Chuang Kang AB', subTypes = { 'Runway %(%d+m%)', 'Taxiway' } },
            { baseName = 'Chiayi AB',            subTypes = { 'Runway %(%d+m%)', 'Taxiway' } },
            { baseName = 'Tainan AB',            subTypes = { 'Runway %(%d+m%)', 'Taxiway' } },
            { baseName = 'Pingtung South AB',    subTypes = { 'Runway %(%d+m%)', 'Taxiway' } },
            { baseName = 'Pingtung North AB',    subTypes = { 'Runway %(%d+m%)', 'Taxiway' } },
            { baseName = 'Magong AB',            subTypes = { 'Runway %(%d+m%)', 'Taxiway' } },
            { baseName = 'Hsinchu AB',           subTypes = { 'Runway %(%d+m%)', 'Taxiway' } },
          },
          areas = {},
          filterNames = nil,
          contactAge = CONFIG.c.ground.srbm.contactAge,
          minTargetCount = 4,
          ammoPerTarget = 4
        },
        startTime = nil,
        isFinished = false
      },
      -- {
      --   name = 'RUNWAY',
      --   wpnSystem = 'SRBM',
      --   queryParams = {
      --     { baseName = 'Hualien AB',           subTypes = { 'Runway %(%d+m%)', 'Taxiway' } },
      --     { baseName = 'Taitung/Jhihhang AB',  subTypes = { 'Runway %(%d+m%)', 'Taxiway' } },
      --     { baseName = 'Ching Chuang Kang AB', subTypes = { 'Runway %(%d+m%)', 'Taxiway' } },
      --     { baseName = 'Chiayi AB',            subTypes = { 'Runway %(%d+m%)', 'Taxiway' } },
      --     { baseName = 'Tainan AB',            subTypes = { 'Runway %(%d+m%)', 'Taxiway' } },
      --     { baseName = 'Pingtung South AB',    subTypes = { 'Runway %(%d+m%)', 'Taxiway' } },
      --     { baseName = 'Pingtung North AB',    subTypes = { 'Runway %(%d+m%)', 'Taxiway' } },
      --     { baseName = 'Magong AB',            subTypes = { 'Runway %(%d+m%)', 'Taxiway' } },
      --     { baseName = 'Hsinchu AB',           subTypes = { 'Runway %(%d+m%)', 'Taxiway' } },
      --   },
      --   targetlist = {},
      --   evaluatedTargetlist = {},
      --   batteries = {
      --     {
      --       name = '636th Bde',
      --       guid = 'IC8B0X-0HN822OHANPB3',
      --       weaponDBID = SaveData.c.ground.srbm.batteries['IC8B0X-0HN822OHANPB3'].weaponDBID
      --     },
      --     {
      --       name = '617th Bde',
      --       guid = 'IC8B0X-0HN822OHANRHI',
      --       weaponDBID = SaveData.c.ground.srbm.batteries['IC8B0X-0HN822OHANRHI'].weaponDBID
      --     }
      --   },
      --   areas = nil,
      --   startTime = nil,
      --   contactAge = CONFIG.c.ground.srbm.contactAge,
      --   ammoPerTarget = 4,
      --   minTargetCount = 4,
      --   filterNames = nil,
      --   isFinished = false
      -- },
      {
        name = 'PORT',
        wpnSystem = 'SRBM',
        batteries = {
          {
            name = '615th Bde',
            guid = 'X58F5H-0HN1G2IFLNKG9',
            weaponDBID = SaveData.c.ground.srbm.batteries['X58F5H-0HN1G2IFLNKG9'].weaponDBID
          }
        },
        target = {
          list = {},
          evaluatedlist = {},
          objs = {
            { baseName = 'Port of Keelung', subTypes = { 'Pier' } },
            { baseName = 'Suao Port',       subTypes = { 'Pier' } },
            { baseName = 'Kaohsiung Port',  subTypes = { 'Pier' } },
            { baseName = 'Magong Port',     subTypes = { 'Pier' } },
            { baseName = nil,               subTypes = { 'ASM' } },
          },
          areas = {},
          filterNames = nil,
          contactAge = CONFIG.c.ground.srbm.contactAge,
          minTargetCount = 4,
          ammoPerTarget = 2
        },
        startTime = nil,
        isFinished = false
      },
      -- {
      --   name = 'PORT',
      --   wpnSystem = 'SRBM',
      --   queryParams = {
      --     { baseName = 'Port of Keelung', subTypes = { 'Pier' } },
      --     { baseName = 'Suao Port',       subTypes = { 'Pier' } },
      --     { baseName = 'Kaohsiung Port',  subTypes = { 'Pier' } },
      --     { baseName = 'Magong Port',     subTypes = { 'Pier' } },
      --     { baseName = nil,               subTypes = { 'ASM' } },
      --   },
      --   targetlist = {},
      --   evaluatedTargetlist = {},
      --   batteries = {
      --     {
      --       name = '615th Bde',
      --       guid = 'X58F5H-0HN1G2IFLNKG9',
      --       weaponDBID = SaveData.c.ground.srbm.batteries['X58F5H-0HN1G2IFLNKG9'].weaponDBID
      --     }
      --   },
      --   areas = nil,
      --   startTime = nil,
      --   contactAge = CONFIG.c.ground.srbm.contactAge,
      --   ammoPerTarget = 2,
      --   minTargetCount = 4,
      --   filterNames = nil,
      --   isFinished = false
      -- },
      {
        name = 'SHELTER',
        wpnSystem = 'SRBM',
        batteries = {
          {
            name = '616th Bde',
            guid = 'X58F5H-0HN1G2IFLF6QE',
            weaponDBID = SaveData.c.ground.srbm.batteries['X58F5H-0HN1G2IFLF6QE'].weaponDBID
          }
        },
        target = {
          list = {},
          evaluatedlist = {},
          objs = {
            { baseName = 'Chiayi AB',            subTypes = { 'Shelter', 'Tarmac', 'Hangar' } },
            { baseName = 'Pingtung South AB',    subTypes = { 'Shelter', 'Tarmac', 'Hangar' } },
            { baseName = 'Ching Chuang Kang AB', subTypes = { 'Shelter', 'Tarmac', 'Hangar' } },
            { baseName = 'Magong AB',            subTypes = { 'Shelter', 'Tarmac', 'Hangar' } },
          },
          areas = {},
          filterNames = nil,
          contactAge = CONFIG.c.ground.srbm.contactAge,
          minTargetCount = 4,
          ammoPerTarget = 2
        },
        startTime = nil,
        isFinished = false
      },
      -- {
      --   name = 'SHELTER',
      --   wpnSystem = 'SRBM',
      --   queryParams = {
      --     { baseName = 'Chiayi AB',            subTypes = { 'Shelter', 'Tarmac', 'Hangar' } },
      --     { baseName = 'Pingtung South AB',    subTypes = { 'Shelter', 'Tarmac', 'Hangar' } },
      --     { baseName = 'Ching Chuang Kang AB', subTypes = { 'Shelter', 'Tarmac', 'Hangar' } },
      --     { baseName = 'Magong AB',            subTypes = { 'Shelter', 'Tarmac', 'Hangar' } },
      --   },
      --   targetlist = {},
      --   evaluatedTargetlist = {},
      --   batteries = {
      --     {
      --       name = '616th Bde',
      --       guid = 'X58F5H-0HN1G2IFLF6QE',
      --       weaponDBID = SaveData.c.ground.srbm.batteries['X58F5H-0HN1G2IFLF6QE'].weaponDBID
      --     }
      --   },
      --   areas = nil,
      --   startTime = nil,
      --   contactAge = CONFIG.c.ground.srbm.contactAge,
      --   ammoPerTarget = 2,
      --   minTargetCount = 4,
      --   filterNames = nil,
      --   isFinished = false
      -- },
    }
  },
  ['STRIKE/C2/1'] = {
    name = 'STRIKE/C2/1',
    isActivated = true,
    isFirstWave = false,
    strikeInterval = 0 * 60,
    reconUAVs = nil,
    isFinished = false,
    allBatteriesInPosition = false,
    -- Fire support task
    ---@type SBJ__FireSupportTask[]
    FSTs = {
      {
        name = 'PINGTAN',
        wpnSystem = 'MLRS',
        batteries = {
          {
            name = '1st Bn, 1st Rockets Arty Bde',
            guid = 'IC8B0X-0HND05GGU36EN',
            weaponDBID = SaveData.c.ground.mlrs.batteries['IC8B0X-0HND05GGU36EN'].weaponDBID
          }
        },
        target = {
          list = {},
          evaluatedlist = {},
          objs = {},
          areas = { CONFIG.c.areas["OPAREA/NORTH"] },
          filterNames = { 'analyzeEmissions', 'findRadioDirection' },
          contactAge = CONFIG.c.ground.mlrs.contactAge,
          minTargetCount = 2,
          ammoPerTarget = 8
        },
        startTime = '2027-06-09 01:30:00',
        -- startTime =  '2027-06-09 03:10:00'
        isFinished = false
      },
      -- {
      --   name = 'PINGTAN',
      --   wpnSystem = 'MLRS',
      --   targetlist = {},
      --   evaluatedTargetlist = {},
      --   batteries = {
      --     {
      --       name = '1st Bn, 1st Rockets Arty Bde',
      --       guid = 'IC8B0X-0HND05GGU36EN',
      --       weaponDBID = SaveData.c.ground.mlrs.batteries['IC8B0X-0HND05GGU36EN'].weaponDBID
      --     }
      --   },
      --   areas = { CONFIG.c.areas["OPAREA/NORTH"] },
      --   startTime = '2027-06-09 01:30:00',
      --   -- startTime =  '2027-06-09 03:10:00'
      --   contactAge = CONFIG.c.ground.mlrs.contactAge,
      --   ammoPerTarget = 8,
      --   minTargetCount = 2,
      --   filterNames = { 'analyzeEmissions', 'findRadioDirection' },
      --   isFinished = false
      -- },
      {
        name = 'CHINCHEW',
        wpnSystem = 'MLRS',
        batteries = {
          {
            name = '6th Bn, 73rd Arty Bde',
            guid = 'IC8B0X-0HNBRRE2PRQAL',
            weaponDBID = SaveData.c.ground.mlrs.batteries['IC8B0X-0HNBRRE2PRQAL'].weaponDBID
          }
        },
        target = {
          list = {},
          evaluatedlist = {},
          objs = {},
          areas = { CONFIG.c.areas["OPAREA/CENTER"] },
          filterNames = { 'analyzeEmissions', 'findRadioDirection' },
          contactAge = CONFIG.c.ground.mlrs.contactAge,
          minTargetCount = 2,
          ammoPerTarget = 8
        },
        startTime = nil,
        isFinished = false
      },
      -- {
      --   name = 'CHINCHEW',
      --   wpnSystem = 'MLRS',
      --   targetlist = {},
      --   evaluatedTargetlist = {},
      --   batteries = {
      --     {
      --       name = '6th Bn, 73rd Arty Bde',
      --       guid = 'IC8B0X-0HNBRRE2PRQAL',
      --       weaponDBID = SaveData.c.ground.mlrs.batteries['IC8B0X-0HNBRRE2PRQAL'].weaponDBID
      --     }
      --   },
      --   areas = { CONFIG.c.areas["OPAREA/CENTER"] },
      --   startTime = nil,
      --   contactAge = CONFIG.c.ground.mlrs.contactAge,
      --   ammoPerTarget = 8,
      --   minTargetCount = 2,
      --   filterNames = { 'analyzeEmissions', 'findRadioDirection' },
      --   isFinished = false
      -- },
    }
  },
  ['STRIKE/HELIPAD'] = {
    name = 'STRIKE/HELIPAD',
    isActivated = true,
    isFirstWave = true,
    strikeInterval = 60 * 60,
    reconUAVs = nil,
    isFinished = false,
    allBatteriesInPosition = false,
    -- Fire support task
    FSTs = {
      {
        name = 'HELIPAD',
        wpnSystem = 'GLCM',
        batteries = {
          {
            name = '635th Bde',
            guid = '6Z8LM5-0HMN97ERAUODK',
            weaponDBID = SaveData.c.ground.glcm.batteries['6Z8LM5-0HMN97ERAUODK'].weaponDBID
          }
        },
        target = {
          list = {},
          evaluatedlist = {},
          objs = {
            { baseName = 'Guiren AAB',  subTypes = { 'Helipad' } },
            { baseName = 'Longtan AAB', subTypes = { 'Helipad' } },
          },
          areas = {},
          filterNames = nil,
          contactAge = CONFIG.c.ground.glcm.contactAge,
          minTargetCount = 1,
          ammoPerTarget = 2
        },
        -- startTime = '2027-06-09 05:30:00',
        startTime = '2027-06-09 02:00:00',
        isFinished = false
      },
      -- {
      --   name = 'HELIPAD',
      --   wpnSystem = 'GLCM',
      --   queryParams = {
      --     { baseName = 'Guiren AAB',  subTypes = { 'Helipad' } },
      --     { baseName = 'Longtan AAB', subTypes = { 'Helipad' } },
      --   },
      --   targetlist = {},
      --   evaluatedTargetlist = {},
      --   batteries = {
      --     {
      --       name = '635th Bde',
      --       guid = '6Z8LM5-0HMN97ERAUODK',
      --       weaponDBID = SaveData.c.ground.glcm.batteries['6Z8LM5-0HMN97ERAUODK'].weaponDBID
      --     }
      --   },
      --   areas = nil,
      --   -- startTime = '2027-06-09 05:30:00',
      --   startTime = '2027-06-09 02:00:00',
      --   contactAge = CONFIG.c.ground.glcm.contactAge,
      --   ammoPerTarget = 2,
      --   minTargetCount = 1,
      --   filterNames = nil,
      --   isFinished = false
      -- },
      {
        name = 'EMERGENCY HIGHWAY STRIP',
        wpnSystem = 'GLCM',
        batteries = {
          {
            name = '635th Bde',
            guid = '6Z8LM5-0HMN97ERAUODK',
            weaponDBID = SaveData.c.ground.glcm.batteries['6Z8LM5-0HMN97ERAUODK'].weaponDBID
          }
        },
        target = {
          list = {},
          evaluatedlist = {},
          objs = {
            { baseName = 'Minxiong Emergency Highway Strip', subTypes = { 'Runway %(%d+m%)', 'Taxiway' } },
            { baseName = 'Madou Emergency Highway Strip',    subTypes = { 'Runway %(%d+m%)', 'Taxiway' } },
            { baseName = 'Rende Emergency Highway Strip',    subTypes = { 'Runway %(%d+m%)', 'Taxiway' } },
          },
          areas = {},
          filterNames = nil,
          contactAge = CONFIG.c.ground.glcm.contactAge,
          minTargetCount = 1,
          ammoPerTarget = 4
        },
        startTime = nil,
        isFinished = false
      },
      -- {
      --   name = 'EMERGENCY HIGHWAY STRIP',
      --   wpnSystem = 'GLCM',
      --   queryParams = {
      --     { baseName = 'Minxiong Emergency Highway Strip', subTypes = { 'Runway %(%d+m%)', 'Taxiway' } },
      --     { baseName = 'Madou Emergency Highway Strip',    subTypes = { 'Runway %(%d+m%)', 'Taxiway' } },
      --     { baseName = 'Rende Emergency Highway Strip',    subTypes = { 'Runway %(%d+m%)', 'Taxiway' } },
      --   },
      --   targetlist = {},
      --   evaluatedTargetlist = {},
      --   batteries = {
      --     {
      --       name = '635th Bde',
      --       guid = '6Z8LM5-0HMN97ERAUODK',
      --       weaponDBID = SaveData.c.ground.glcm.batteries['6Z8LM5-0HMN97ERAUODK'].weaponDBID
      --     }
      --   },
      --   areas = nil,
      --   startTime = nil,
      --   contactAge = CONFIG.c.ground.glcm.contactAge,
      --   ammoPerTarget = 4,
      --   minTargetCount = 1,
      --   filterNames = nil,
      --   isFinished = false
      -- }
    }
  },
  ['ANTISHIP/EAST'] = {
    name = 'ANTISHIP/EAST',
    isActivated = true,
    isFirstWave = false,
    strikeInterval = 0 * 60,
    reconUAVs = nil,
    isFinished = false,
    allBatteriesInPosition = false,
    -- Fire support task
    FSTs = {
      {
        name = 'ANTISHIP',
        wpnSystem = 'MRBM',
        batteries = {
          {
            name = '624th Bde',
            guid = 'IC8B0X-0HNCOR6HG2JE1',
            weaponDBID = SaveData.c.ground.mrbm.batteries['IC8B0X-0HNCOR6HG2JE1'].weaponDBID
          }
        },
        target = {
          list = {},
          evaluatedlist = {},
          objs = {},
          areas = { CONFIG.c.areas["OPAREA/PACIFIC"] },
          filterNames = { 'findNavalTargets' },
          contactAge = CONFIG.c.ground.mrbm.contactAge,
          minTargetCount = 1,
          ammoPerTarget = 6
        },
        startTime = '2027-06-09 02:10:00',
        isFinished = false
      },
      -- {
      --   name = 'ANTISHIP',
      --   wpnSystem = 'MRBM',
      --   targetlist = {},
      --   evaluatedTargetlist = {},
      --   batteries = {
      --     {
      --       name = '624th Bde',
      --       guid = 'IC8B0X-0HNCOR6HG2JE1',
      --       weaponDBID = SaveData.c.ground.mrbm.batteries['IC8B0X-0HNCOR6HG2JE1'].weaponDBID
      --     }
      --   },
      --   areas = { CONFIG.c.areas["OPAREA/PACIFIC"] },
      --   startTime = '2027-06-09 02:10:00',
      --   contactAge = CONFIG.c.ground.mrbm.contactAge,
      --   ammoPerTarget = 6,
      --   minTargetCount = 1,
      --   filterNames = { 'findNavalTargets' },
      --   isFinished = false
      -- }
    }
  }
}


-- Air tasking order
SaveData.c.air.isActivated = true
SaveData.c.air.ATO = {
  ['STRIKE/AB/W/1'] = {
    name = 'STRIKE/AB/W/1',
    isActivated = true,
    isFirstWave = true,
    haeLaunched = false,
    strikeInterval = 30 * 60,
    -- reconUAVs = {
    --   {
    --     baseGUID = CONFIG.c.recon.bases.BZK005.guid,
    --     unitDBID = CONFIG.platformDBID13,
    --     unitGUID = nil,
    --     missionName = 'RECON/1',
    --     course = { { lat = 'N 25.27.28', lon = 'E 120.46.09', } },
    --     num = 1,
    --     takeoffTime = '2027-06-09 01:00:00',
    --     missionStartTime = '2027-06-09 01:30:00',
    --     hasLaunched = false
    --   },
    --   -- {
    --   --   baseGUID = CONFIG.c.recon.bases.BZK005.guid,
    --   --   unitDBID = CONFIG.platformDBID13,
    --   --   unitGUID = nil,
    --   --   missionName = 'RECON/1',
    --   --   course = nil,
    --   --   num = 1,
    --   --   takeoffTime = nil,
    --   --   missionStartTime = '2027-06-09 01:00:00',
    --   --   hasLaunched = false
    --   -- },
    --   {
    --     baseGUID = CONFIG.c.recon.bases.H6N.guid,
    --     unitDBID = CONFIG.platformDBID76,
    --     unitGUID = nil,
    --     missionName = nil,
    --     course = CONFIG.c.recon.courses.H6N,
    --     num = 1,
    --     takeoffTime = '2027-06-09 03:40:00',
    --     missionStartTime = nil,
    --     hasLaunched = false
    --   },
    -- },
    ---@type SBJ__Package[]
    packages = {
      {
        striker = {
          baseGUID = '6Z8LM5-0HMLLEF9H5P44',
          weaponDBID = 2876,
          unitCount = 12,
          startTime = '2027-06-09 01:20:00',
          -- endTime = '2027-06-09 02:00:00',
          missionParams = { name = 'STRIKE/AB/W/1', type = 'strike', opts = { type = 'land' }, },
          emcon = 'Radar=Passive;OECM=Active'
        },
        escort = {
          baseGUID = '6Z8LM5-0HMIJ3QGCRQ5F',
          weaponDBID = 3413,
          unitCount = 8,
          -- startTime = '2027-06-09 01:00:00',
          -- endTime = '2027-06-09 02:00:00',
          missionParams = {
            name = 'SWEAP/AB/W/1',
            type = 'patrol',
            opts = {
              type = 'aaw',
              -- onDeactivateDelete = true,
              OneThirdRule = false,
              FlightSize = 4,
              CheckOPAREA = false,
              CheckWWR = false,
              prosecutionZone = CONFIG.c.areas["SWEAP/SOUTH/PROSECUTION"],
              patrolZone = CONFIG.c.areas["SWEAP/SOUTH/PATROL"],
            },
          },
          emcon = 'Radar=Passive;OECM=Active'
        },
        wildWeasel = {
          baseGUID = '6Z8LM5-0HMIJ3QGCRQ2G',
          weaponDBID = 2875,
          unitCount = 8,
          -- startTime = '2027-06-09 01:00:00',
          -- endTime = '2027-06-09 02:00:00',
          missionParams = {
            name = 'SEAD/AB/W/1',
            type = 'patrol',
            opts = {
              type = 'sead',
              OneThirdRule = false,
              FlightSize = 4,
              CheckOPAREA = false,
              CheckWWR = false,
              prosecutionZone = CONFIG.c.areas["SWEAP/SOUTH/PROSECUTION"],
              patrolZone = CONFIG.c.areas["SWEAP/SOUTH/PATROL"],
            },
          },
          emcon = 'Radar=Passive;OECM=Active'
        },
        jammer = {
          baseGUID = 'X58F5H-0HN00TRR0Q1JQ',
          unitDBID = 4203,
          weaponDBID = 0,
          unitCount = 1,
          -- startTime = '2027-06-09 01:00:00',
          -- endTime = '2027-06-09 02:00:00',
          missionParams = {
            name = 'JAMMING/AB/W/1',
            type = 'support',
            opts = {
              zone = CONFIG.c.areas["SWEAP/SOUTH/PATROL"],
            },
          },
          emcon = 'Radar=Passive;OECM=Active'
        },
        tanker = nil,
        reconUAV = {
          baseGUID = CONFIG.c.recon.bases.BZK005.guid,
          unitDBID = CONFIG.platformDBID13,
          unitGUID = nil,
          missionName = 'RECON/1',
          course = { { lat = 'N 25.27.28', lon = 'E 120.46.09', } },
          unitCount = 1,
          takeoffTime = '2027-06-09 01:00:00',
          missionStartTime = '2027-06-09 01:30:00',
          hasLaunched = false
        },
        target = {
          list = {},
          objs = {
            { baseName = 'Pingtung South AB', subTypes = { 'Shelter', 'Tarmac', 'Hangar' } },
            { baseName = 'Pingtung North AB', subTypes = { 'Shelter', 'Tarmac', 'Hangar' } },
          },
          areas = { CONFIG.c.areas["OPAREA/SOUTH"] },
          filterNames = { 'findC2', },
          contactAge = 60 * 60,
          minTargetCount = 1,
        },
        hasLaunched = false,
      },
      -- {
      --   striker = { baseGUID = '6Z8LM5-0HMLLEF9H5P44', weaponDBID = 2876, num = 12, },
      --   escort = nil,
      --   wildWeasel = { baseGUID = '6Z8LM5-0HMIJ3QGCRQ2G', weaponDBID = 2875, num = 8, },
      --   jammer = { baseGUID = 'X58F5H-0HN00TRR0Q1JQ', unitDBID = 4203, num = 1, },
      --   missionName = 'STRIKE/AB/S/1',
      --   missionType = 'land',
      --   targetlist = {},
      --   queryParams = {
      --     { baseName = 'Pingtung South AB', subTypes = { 'Shelter', 'Tarmac', 'Hangar' } },
      --     { baseName = 'Pingtung North AB', subTypes = { 'Shelter', 'Tarmac', 'Hangar' } },
      --   },
      --   area = CONFIG.c.areas["OPAREA/SOUTH"],
      --   hasLaunched = false,
      --   tanker = nil,
      --   filterName = 'makeC2Filter',
      --   contactAge = 60 * 60,
      --   minTargetCount = 1,
      --   -- takeoffTime = '2027-06-09 03:40:00',
      --   takeoffTime = '2027-06-09 01:00:00'
      -- },
      --[[
      {
        striker = { baseGUID = '6Z8LM5-0HMLLEF9H5P44', weaponDBID = 2876, num = 12, },
        escort = nil,
        wildWeasel = { baseGUID = '6Z8LM5-0HMIJ3QGCRQ2G', weaponDBID = 2875, num = 8, },
        jammer = { baseGUID = 'X58F5H-0HN00TRR0Q1JQ', unitDBID = 4203, num = 1, },
        missionName = 'STRIKE/AB/C',
        missionType = 'land',
        targetlist = {},
        queryParams = {
          { baseName = 'Ching Chuang Kang AB', subTypes = { 'Shelter', 'Ammo Bunker' } },
          { baseName = 'Chiayi AB',            subTypes = { 'Shelter', 'Ammo Bunker' } },
        },
        area = CONFIG.c.areas["OPAREA/CENTER"],
        hasLaunched = false,
        tanker = nil,
        filterName = 'makeC2Filter',
        contactAge = 60 * 60,
        minTargetCount = 1,
        takeoffTime = nil
      },
      {
        striker = { baseGUID = '6Z8LM5-0HMIJ3QGCRQ5F', weaponDBID = 2876, num = 12, },
        escort = nil,
        wildWeasel = { baseGUID = '6Z8LM5-0HMIJ3QGCRQC4', weaponDBID = 2875, num = 8, },
        jammer = { baseGUID = 'X58F5H-0HN00TRR0Q1JQ', unitDBID = 4203, num = 1, },
        missionName = 'STRIKE/AB/N/1',
        missionType = 'land',
        targetlist = {},
        queryParams = {
          { baseName = 'Hsinchu AB', subTypes = { 'Shelter', 'Helipad', 'Ammo Bunker' } },
        },
        area = CONFIG.c.areas["OPAREA/NORTH"],
        hasLaunched = false,
        tanker = nil,
        filterName = 'makeC2Filter',
        contactAge = 60 * 60,
        minTargetCount = 1,
        takeoffTime = nil
      },
--]]
      {
        striker = {
          baseGUID = '6Z8LM5-0HMLLEF9H5P44',
          weaponDBID = 2876,
          unitCount = 12,
          startTime = nil,
          missionParams = { name = 'STRIKE/AB/C', type = 'strike', opts = { type = 'land' } },
          emcon = 'Radar=Passive;OECM=Active'
        },
        escort = {
          baseGUID = '6Z8LM5-0HMIJ3QGCRQ5F',
          weaponDBID = 3413,
          unitCount = 8,
          -- startTime = '2027-06-09 01:00:00',
          -- endTime = '2027-06-09 02:00:00',
          missionParams = {
            name = 'SWEAP/AB/C',
            type = 'patrol',
            opts = {
              type = 'aaw',
              -- onDeactivateDelete = true,
              OneThirdRule = false,
              FlightSize = 4,
              CheckOPAREA = false,
              CheckWWR = false,
              prosecutionZone = CONFIG.c.areas["SWEAP/CENTER/PROSECUTION"],
              patrolZone = CONFIG.c.areas["SWEAP/CENTER/PATROL"],
            },
          },
          emcon = 'Radar=Passive;OECM=Active'
        },
        wildWeasel = {
          baseGUID = '6Z8LM5-0HMIJ3QGCRQ2G',
          weaponDBID = 2875,
          unitCount = 8,
          missionParams = {
            name = 'SEAD/AB/C',
            type = 'patrol',
            opts = {
              type = 'sead',
              OneThirdRule = false,
              FlightSize = 4,
              CheckOPAREA = false,
              CheckWWR = false,
              prosecutionZone = CONFIG.c.areas["SWEAP/CENTER/PROSECUTION"],
              patrolZone = CONFIG.c.areas["SWEAP/CENTER/PATROL"],
            }
          },
          emcon = 'Radar=Passive;OECM=Active'
        },
        jammer = {
          baseGUID = 'X58F5H-0HN00TRR0Q1JQ',
          unitDBID = 4203,
          weaponDBID = 0,
          unitCount = 1,
          missionParams = {
            name = 'JAMMING/AB/C',
            type = 'support',
            opts = { zone = CONFIG.c.areas["SWEAP/CENTER/PATROL"] }
          },
          emcon = 'Radar=Passive;OECM=Active'
        },
        tanker = nil,
        reconUAV = nil,
        target = {
          list = {},
          objs = {
            { baseName = 'Ching Chuang Kang AB', subTypes = { 'Shelter', 'Ammo Bunker' } },
            { baseName = 'Chiayi AB',            subTypes = { 'Shelter', 'Ammo Bunker' } },
          },
          areas = { CONFIG.c.areas["OPAREA/CENTER"] },
          filterNames = { 'findC2' },
          contactAge = 60 * 60,
          minTargetCount = 1,
        },
        hasLaunched = false,
      },
      {
        striker = {
          baseGUID = '6Z8LM5-0HMIJ3QGCRQ5F',
          weaponDBID = 2876,
          unitCount = 12,
          startTime = nil,
          missionParams = { name = 'STRIKE/AB/N/1', type = 'strike', opts = { type = 'land' } },
          emcon = 'Radar=Passive;OECM=Active'
        },
        escort = {
          baseGUID = '6Z8LM5-0HMIJ3QGCRQ5F',
          weaponDBID = 3413,
          unitCount = 8,
          missionParams = {
            name = 'SWEAP/AB/N/1',
            type = 'patrol',
            opts = {
              type = 'aaw',
              -- onDeactivateDelete = true,
              OneThirdRule = false,
              FlightSize = 4,
              CheckOPAREA = false,
              CheckWWR = false,
              prosecutionZone = CONFIG.c.areas["SWEAP/NORTH/PROSECUTION"],
              patrolZone = CONFIG.c.areas["SWEAP/NORTH/PATROL"],
            },
          },
          emcon = 'Radar=Passive;OECM=Active'
        },
        wildWeasel = {
          baseGUID = '6Z8LM5-0HMIJ3QGCRQC4',
          weaponDBID = 2875,
          unitCount = 8,
          missionParams = {
            name = 'SEAD/AB/N/1',
            type = 'patrol',
            opts = {
              type = 'sead',
              OneThirdRule = false,
              FlightSize = 4,
              CheckOPAREA = false,
              CheckWWR = false,
              prosecutionZone = CONFIG.c.areas["SWEAP/NORTH/PROSECUTION"],
              patrolZone = CONFIG.c.areas["SWEAP/NORTH/PATROL"],
            }
          },
          emcon = 'Radar=Passive;OECM=Active'
        },
        jammer = {
          baseGUID = 'X58F5H-0HN00TRR0Q1JQ',
          unitDBID = 4203,
          weaponDBID = 0,
          unitCount = 1,
          missionParams = {
            name = 'JAMMING/AB/N/1',
            type = 'support',
            opts = { zone = CONFIG.c.areas["SWEAP/NORTH/PATROL"] }
          },
          emcon = 'Radar=Passive;OECM=Active'
        },
        tanker = nil,
        reconUAV = nil,
        target = {
          list = {},
          objs = {
            { baseName = 'Hsinchu AB', subTypes = { 'Shelter', 'Helipad', 'Ammo Bunker' } },
          },
          areas = { CONFIG.c.areas["OPAREA/NORTH"] },
          filterNames = { 'findC2' },
          contactAge = 60 * 60,
          minTargetCount = 1,
        },
        hasLaunched = false,
      },
    }
  },
  ['STRIKE/AB/W/2'] = {
    name = 'STRIKE/AB/W/2',
    isActivated = true,
    isFirstWave = false,
    haeLaunched = false,
    strikeInterval = 30 * 60,
    reconUAVs = nil,
    --[[
    packages = {
      {
        striker = { baseGUID = '6Z8LM5-0HMLLEF9H7VDF', weaponDBID = 2107, num = 12, },
        escort = nil,
        wildWeasel = nil,
        missionName = 'STRIKE/AB/S/1',
        missionType = 'land',
        targetlist = {},
        queryParams = {
          { baseName = 'Pingtung South AB', subTypes = { 'Shelter', 'Tarmac', 'Hangar' } },
          { baseName = 'Pingtung North AB', subTypes = { 'Shelter', 'Tarmac', 'Hangar' } },
        },
        area = CONFIG.c.areas["OPAREA/SOUTH"],
        hasLaunched = false,
        tanker = nil,
        filterName = 'makeC2Filter',
        contactAge = 60 * 60,
        minTargetCount = 1,
        takeoffTime = '2027-06-09 04:40:00',
      },
      {
        striker = { baseGUID = '6Z8LM5-0HMIJ7B8971MA', weaponDBID = 2107, num = 12, },
        escort = nil,
        wildWeasel = nil,
        missionName = 'STRIKE/AB/N/1',
        missionType = 'land',
        targetlist = {},
        queryParams = {
          { baseName = 'Hsinchu AB', subTypes = { 'Shelter', 'Helipad', 'Ammo Bunker' } },
        },
        area = CONFIG.c.areas["OPAREA/NORTH"],
        hasLaunched = false,
        tanker = nil,
        filterName = 'makeC2Filter',
        contactAge = 60 * 60,
        minTargetCount = 1,
        takeoffTime = nil
      },
    }
--]]
    packages = {
      {
        striker = {
          baseGUID = '6Z8LM5-0HMLLEF9H7VDF',
          weaponDBID = 2107,
          unitCount = 12,
          startTime = '2027-06-09 04:40:00',
          missionParams = { name = 'STRIKE/AB/S/1', type = 'strike', opts = { type = 'land' } },
          emcon = 'Radar=Passive;OECM=Active'
        },
        escort = nil,
        wildWeasel = nil,
        jammer = nil,
        tanker = nil,
        reconUAV = nil,
        target = {
          list = {},
          objs = {
            { baseName = 'Pingtung South AB', subTypes = { 'Shelter', 'Tarmac', 'Hangar' } },
            { baseName = 'Pingtung North AB', subTypes = { 'Shelter', 'Tarmac', 'Hangar' } },
          },
          areas = { CONFIG.c.areas["OPAREA/SOUTH"] },
          filterNames = { 'findC2' },
          contactAge = 60 * 60,
          minTargetCount = 1,
        },
        hasLaunched = false,
      },
      {
        striker = {
          baseGUID = '6Z8LM5-0HMIJ7B8971MA',
          weaponDBID = 2107,
          unitCount = 12,
          startTime = nil,
          missionParams = { name = 'STRIKE/AB/N/1', type = 'strike', opts = { type = 'land' } },
          emcon = 'Radar=Passive;OECM=Active'
        },
        escort = nil,
        wildWeasel = nil,
        jammer = nil,
        tanker = nil,
        reconUAV = nil,
        target = {
          list = {},
          objs = {
            { baseName = 'Hsinchu AB', subTypes = { 'Shelter', 'Helipad', 'Ammo Bunker' } },
          },
          areas = { CONFIG.c.areas["OPAREA/NORTH"] },
          filterNames = { 'findC2' },
          contactAge = 60 * 60,
          minTargetCount = 1,
        },
        hasLaunched = false,
      },
    }
  },
  ['STRIKE/AB/W/3'] = {
    name = 'STRIKE/AB/W/3',
    isActivated = true,
    isFirstWave = false,
    haeLaunched = false,
    strikeInterval = 30 * 60,
    reconUAVs = nil,
    --[[
    packages = {
      {
        striker = { baseGUID = 'X58F5H-0HN00TRR0Q1JQ', weaponDBID = 3077, num = 12, },
        escort = nil,
        wildWeasel = { baseGUID = '6Z8LM5-0HMIJ3QGCRQ2G', weaponDBID = 2875, num = 8, },
        jammer = { baseGUID = 'X58F5H-0HN00TRR0Q1JQ', unitDBID = 4203, num = 1, },
        missionName = 'STRIKE/AB/S/2',
        missionType = 'land',
        targetlist = {},
        queryParams = {
          { baseName = 'Pingtung South AB', subTypes = { 'Ammo Bunker' } },
          { baseName = 'Tainan AB',         subTypes = { 'Ammo Bunker' } },
          { baseName = 'Magong AB',         subTypes = { 'Ammo Bunker' } },
        },
        area = CONFIG.c.areas["OPAREA/SOUTH"],
        hasLaunched = false,
        tanker = nil,
        filterName = 'makeC2Filter',
        contactAge = 60 * 60,
        minTargetCount = 1,
        takeoffTime = '2027-06-09 05:40:00',
      },
    }
--]]
    packages = {
      {
        striker = {
          baseGUID = 'X58F5H-0HN00TRR0Q1JQ',
          weaponDBID = 3077,
          unitCount = 12,
          startTime = '2027-06-09 05:40:00',
          missionParams = { name = 'STRIKE/AB/S/2', type = 'strike', opts = { type = 'land' } },
          emcon = 'Radar=Passive;OECM=Active'
        },
        escort = {
          baseGUID = '6Z8LM5-0HMIJ3QGCRQ5F',
          weaponDBID = 3413,
          unitCount = 8,
          missionParams = {
            name = 'SWEAP/AB/S/2',
            type = 'patrol',
            opts = {
              type = 'aaw',
              -- onDeactivateDelete = true,
              OneThirdRule = false,
              FlightSize = 4,
              CheckOPAREA = false,
              CheckWWR = false,
              prosecutionZone = CONFIG.c.areas["SWEAP/SOUTH/PROSECUTION"],
              patrolZone = CONFIG.c.areas["SWEAP/SOUTH/PATROL"],
            },
          },
          emcon = 'Radar=Passive;OECM=Active'
        },
        wildWeasel = {
          baseGUID = '6Z8LM5-0HMIJ3QGCRQ2G',
          weaponDBID = 2875,
          unitCount = 8,
          missionParams = {
            name = 'SEAD/AB/S/2',
            type = 'patrol',
            opts = {
              type = 'sead',
              OneThirdRule = false,
              FlightSize = 4,
              CheckOPAREA = false,
              CheckWWR = false,
              prosecutionZone = CONFIG.c.areas["SWEAP/SOUTH/PROSECUTION"],
              patrolZone = CONFIG.c.areas["SWEAP/SOUTH/PATROL"],
            }
          },
          emcon = 'Radar=Passive;OECM=Active'
        },
        jammer = {
          baseGUID = 'X58F5H-0HN00TRR0Q1JQ',
          unitDBID = 4203,
          weaponDBID = 0,
          unitCount = 1,
          missionParams = {
            name = 'JAMMING/AB/S/2',
            type = 'support',
            opts = { zone = CONFIG.c.areas["SWEAP/SOUTH/PATROL"] }
          },
          emcon = 'Radar=Passive;OECM=Active'
        },
        tanker = nil,
        reconUAV = nil,
        target = {
          list = {},
          objs = {
            { baseName = 'Pingtung South AB', subTypes = { 'Ammo Bunker' } },
            { baseName = 'Tainan AB',         subTypes = { 'Ammo Bunker' } },
            { baseName = 'Magong AB',         subTypes = { 'Ammo Bunker' } },
          },
          areas = { CONFIG.c.areas["OPAREA/SOUTH"] },
          filterNames = { 'findC2' },
          contactAge = 60 * 60,
          minTargetCount = 1,
        },
        hasLaunched = false,
      },
    }
  },
  ['STRIKE/AB/E/1'] = {
    name = 'STRIKE/AB/E/1',
    isActivated = true,
    isFirstWave = false,
    haeLaunched = false,
    strikeInterval = 80 * 60,
    reconUAVs = nil,
    --[[
    packages = {
      {
        striker = { baseGUID = 'CSG', weaponDBID = 3226, num = 12, },
        escort = nil,
        wildWeasel = { baseGUID = 'CSG', weaponDBID = 276, num = 8, },
        jammer = { baseGUID = 'CSG', unitDBID = 4817, num = 1, },
        missionName = 'STRIKE/AB/JHI',
        missionType = 'land',
        targetlist = {},
        queryParams = {
          { baseName = 'Jhihhang AB', subTypes = { 'Shelter' } },
        },
        area = CONFIG.c.areas["OPAREA/EAST"],
        hasLaunched = false,
        tanker = nil,
        filterName = nil,
        contactAge = 60 * 60,
        minTargetCount = 1,
        takeoffTime = '2027-06-09 07:00:00',
      },
      {
        striker = { baseGUID = 'CSG', weaponDBID = 3226, num = 12, },
        escort = nil,
        wildWeasel = { baseGUID = 'CSG', weaponDBID = 276, num = 8, },
        jammer = { baseGUID = 'CSG', unitDBID = 4817, num = 1, },
        missionName = 'STRIKE/AB/E',
        missionType = 'land',
        targetlist = {},
        queryParams = {
          { baseName = 'Jiashan AB', subTypes = { 'Shelter' } },
        },
        area = CONFIG.c.areas["OPAREA/EAST"],
        hasLaunched = false,
        tanker = nil,
        filterName = nil,
        contactAge = 60 * 60,
        minTargetCount = 1,
        takeoffTime = nil
      },
    }
--]]
    packages = {
      {
        striker = {
          baseGUID = 'CSG',
          weaponDBID = 3226,
          unitCount = 12,
          startTime = '2027-06-09 07:00:00',
          missionParams = { name = 'STRIKE/AB/JHI', type = 'strike', opts = { type = 'land' } },
          emcon = 'Radar=Passive;OECM=Active'
        },
        escort = {
          baseGUID = 'CSG',
          weaponDBID = 3413,
          unitCount = 8,
          missionParams = {
            name = 'SWEAP/AB/JHI',
            type = 'patrol',
            opts = {
              type = 'aaw',
              -- onDeactivateDelete = true,
              OneThirdRule = false,
              FlightSize = 4,
              CheckOPAREA = false,
              CheckWWR = false,
              prosecutionZone = CONFIG.c.areas["SWEAP/JHI/PROSECUTION"],
              patrolZone = CONFIG.c.areas["SWEAP/JHI/PATROL"],
            },
          },
          emcon = 'Radar=Passive;OECM=Active'
        },
        wildWeasel = {
          baseGUID = 'CSG',
          weaponDBID = 276,
          unitCount = 8,
          missionParams = {
            name = 'SEAD/AB/JHI',
            type = 'patrol',
            opts = {
              type = 'sead',
              OneThirdRule = false,
              FlightSize = 4,
              CheckOPAREA = false,
              CheckWWR = false,
              prosecutionZone = CONFIG.c.areas["SWEAP/JHI/PROSECUTION"],
              patrolZone = CONFIG.c.areas["SWEAP/JHI/PATROL"],
            }
          },
          emcon = 'Radar=Passive;OECM=Active'
        },
        jammer = {
          baseGUID = 'CSG',
          unitDBID = 4817,
          weaponDBID = 0,
          unitCount = 1,
          missionParams = {
            name = 'JAMMING/AB/JHI',
            type = 'support',
            opts = { zone = CONFIG.c.areas["SWEAP/JHI/PATROL"] }
          },
          emcon = 'Radar=Passive;OECM=Active'
        },
        tanker = nil,
        reconUAV = nil,
        target = {
          list = {},
          objs = {
            { baseName = 'Jhihhang AB', subTypes = { 'Shelter' } },
          },
          areas = { CONFIG.c.areas["OPAREA/EAST"] },
          filterNames = nil,
          contactAge = 60 * 60,
          minTargetCount = 1,
        },
        hasLaunched = false,
      },
      {
        striker = {
          baseGUID = 'CSG',
          weaponDBID = 3226,
          unitCount = 12,
          startTime = nil,
          missionParams = { name = 'STRIKE/AB/E', type = 'strike', opts = { type = 'land' } },
          emcon = 'Radar=Passive;OECM=Active'
        },
        escort = {
          baseGUID = '6Z8LM5-0HMIJ3QGCRQ5F',
          weaponDBID = 3413,
          unitCount = 8,
          missionParams = {
            name = 'SWEAP/AB/E',
            type = 'patrol',
            opts = {
              type = 'aaw',
              -- onDeactivateDelete = true,
              OneThirdRule = false,
              FlightSize = 4,
              CheckOPAREA = false,
              CheckWWR = false,
              prosecutionZone = CONFIG.c.areas["SWEAP/E/PROSECUTION"],
              patrolZone = CONFIG.c.areas["SWEAP/E/PATROL"],
            },
          },
          emcon = 'Radar=Passive;OECM=Active'
        },
        wildWeasel = {
          baseGUID = 'CSG',
          weaponDBID = 276,
          unitCount = 8,
          missionParams = {
            name = 'SEAD/AB/E',
            type = 'patrol',
            opts = {
              type = 'sead',
              OneThirdRule = false,
              FlightSize = 4,
              CheckOPAREA = false,
              CheckWWR = false,
              prosecutionZone = CONFIG.c.areas["SWEAP/E/PROSECUTION"],
              patrolZone = CONFIG.c.areas["SWEAP/E/PATROL"],
            }
          },
          emcon = 'Radar=Passive;OECM=Active'
        },
        jammer = {
          baseGUID = 'CSG',
          unitDBID = 4817,
          weaponDBID = 0,
          unitCount = 1,
          missionParams = {
            name = 'JAMMING/AB/E',
            type = 'support',
            opts = { zone = CONFIG.c.areas["SWEAP/E/PATROL"] }
          },
          emcon = 'Radar=Passive;OECM=Active'
        },
        tanker = nil,
        reconUAV = nil,
        target = {
          list = {},
          objs = {
            { baseName = 'Jiashan AB', subTypes = { 'Shelter' } },
          },
          areas = { CONFIG.c.areas["OPAREA/EAST"] },
          filterNames = nil,
          contactAge = 60 * 60,
          minTargetCount = 1,
        },
        hasLaunched = false,
      },
    }
  },
  ['ASUW/N/1'] = {
    name = 'ASUW/N/1',
    isActivated = true,
    isFirstWave = false,
    haeLaunched = false,
    strikeInterval = 30 * 60,
    reconUAVs = nil,
    --[[
    packages = {
      {
        striker = { baseGUID = '6Z8LM5-0HMMJDEFRFJ4V', weaponDBID = 2137, num = 8, },
        escort = nil,
        wildWeasel = { baseGUID = '6Z8LM5-0HMMJDEFRFJ4V', weaponDBID = 2875, num = 8, },
        missionName = 'ASUW/N',
        missionType = 'sea',
        targetlist = {},
        queryParams = nil,
        area = CONFIG.c.areas["OPAREA/D"],
        hasLaunched = false,
        tanker = nil,
        filterName = 'makeNavalTargetFilter',
        contactAge = 60 * 60,
        minTargetCount = 1,
        takeoffTime = '2027-06-09 02:40:00'
        -- takeoffTime = '2027-06-09 01:00:00'
      }
    },
--]]
    packages = {
      {
        striker = {
          baseGUID = '6Z8LM5-0HMMJDEFRFJ4V',
          weaponDBID = 2137,
          unitCount = 8,
          startTime = '2027-06-09 02:40:00',
          missionParams = { name = 'ASUW/N', type = 'strike', opts = { type = 'sea' } },
          emcon = 'Radar=Passive;OECM=Active'
        },
        escort = nil,
        wildWeasel = {
          baseGUID = '6Z8LM5-0HMMJDEFRFJ4V',
          weaponDBID = 2875,
          unitCount = 8,
          missionParams = {
            name = 'SEAD/ASUW/N',
            type = 'patrol',
            opts = {
              type = 'sead',
              OneThirdRule = false,
              FlightSize = 4,
              CheckOPAREA = false,
              CheckWWR = false,
              zone = CONFIG.c.areas["OPAREA/D"]
            }
          },
          emcon = 'Radar=Passive;OECM=Active'
        },
        jammer = nil,
        tanker = nil,
        reconUAV = nil,
        target = {
          list = {},
          objs = nil,
          areas = { CONFIG.c.areas["OPAREA/D"] },
          filterNames = { 'findNavalTargets' },
          contactAge = 60 * 60,
          minTargetCount = 1,
        },
        hasLaunched = false,
      }
    },
  },
  ['AIR INTERCEPT/E/1'] = {
    name = 'AIR INTERCEPT/E/1',
    isActivated = true,
    isFirstWave = false,
    haeLaunched = false,
    strikeInterval = 30 * 60,
    reconUAVs = nil,
    --[[
    packages = {
      {
        striker = { baseGUID = '6Z8LM5-0HMIJ7B896RA9', weaponDBID = 3413, num = 6, },
        escort = nil,
        wildWeasel = nil,
        missionName = 'AIR INTERCEPT/E',
        missionType = 'air',
        targetlist = {},
        queryParams = nil,
        area = CONFIG.c.areas["OPAREA/PACIFIC"],
        hasLaunched = false,
        tanker = { baseGUID = '', num = 3, units = {}, missionName = 'AAR' },
        filterName = 'makeAirborneFilter',
        contactAge = 60 * 60,
        minTargetCount = 1,
        takeoffTime = '2027-06-09 06:40:00',
        -- takeoffTime = '2027-06-09 01:00:00'
      }
    },
--]]
    packages = {
      {
        striker = {
          baseGUID = '6Z8LM5-0HMIJ7B896RA9',
          weaponDBID = 3413,
          unitCount = 6,
          startTime = '2027-06-09 06:40:00',
          missionParams = { name = 'AIR INTERCEPT/E', type = 'strike', opts = { type = 'aaw' } },
          emcon = 'Radar=Passive;OECM=Active'
        },
        escort = nil,
        wildWeasel = nil,
        jammer = nil,
        tanker = nil,
        reconUAV = nil,
        target = {
          list = {},
          objs = nil,
          areas = { CONFIG.c.areas["OPAREA/PACIFIC"] },
          filterNames = { 'findAirborne' },
          contactAge = 60 * 60,
          minTargetCount = 1,
        },
        hasLaunched = false,
      }
    },
  },
  ['CAS/N/1'] = {
    name = 'CAS/N/1',
    isActivated = false,
    isFirstWave = false,
    haeLaunched = false,
    strikeInterval = 30 * 60,
    reconUAVs = nil,
    --[[
    packages = {
      {
        striker = { baseGUID = '6Z8LM5-0HMMJDEFRFJ4V', weaponDBID = 3226, num = 8, },
        escort = nil,
        wildWeasel = nil,
        jammer = nil,
        missionName = 'CAS/N',
        missionType = 'land',
        targetlist = {},
        queryParams = nil,
        area = CONFIG.c.areas["LANDING/TAOYUAN"],
        hasLaunched = false,
        tanker = nil,
        filterName = 'makeInfentryFilter',
        contactAge = 60 * 60,
        minTargetCount = 1,
        takeoffTime = '2027-06-09 01:30:00'
      },
    }
--]]
    packages = {
      {
        striker = {
          baseGUID = '6Z8LM5-0HMMJDEFRFJ4V',
          weaponDBID = 3226,
          unitCount = 8,
          startTime = '2027-06-09 01:30:00',
          missionParams = { name = 'CAS/N', type = 'strike', opts = { type = 'land' } },
          emcon = 'Radar=Passive;OECM=Active'
        },
        escort = nil,
        wildWeasel = nil,
        jammer = nil,
        tanker = nil,
        reconUAV = nil,
        target = {
          list = {},
          objs = nil,
          areas = { CONFIG.c.areas["LANDING/TAOYUAN"] },
          filterNames = { 'findInfantry' },
          contactAge = 60 * 60,
          minTargetCount = 1,
        },
        hasLaunched = false,
      },
    }
  },
}



-- Amphibious ops
SaveData.c.PHIBOP.startTime = CONFIG.c.triggers['(China) (Amphibious ops) start time'].startTime
SaveData.c.PHIBOP.isTesting = true
SaveData.c.PHIBOP.isShipsStartedMoving = true
SaveData.c.PHIBOP.isWaitingForShipArrival = false
SaveData.c.PHIBOP.amphibiousAssaultStartTime = nil
SaveData.c.PHIBOP.isWaitingForAmphibiousAssault = false
SaveData.c.PHIBOP.isWaitingForSecondWaveUnloading = false
SaveData.c.PHIBOP.airlandingMissionStartTime = nil
SaveData.c.PHIBOP.calculations = {
  ['Taoyuan'] = {
    name = 'Taoyuan',
    result = {
      type075 = { locations = {}, locationIndex = 1, dbid = CONFIG.platformDBID6, },
      type071 = { locations = {}, locationIndex = 1, dbid = CONFIG.platformDBID7, },
      type076 = { locations = {}, locationIndex = 1, dbid = CONFIG.platformDBID54, },
      type072iii = { locations = {}, locationIndex = 1, dbid = CONFIG.platformDBID8, },
      type072a = { locations = {}, locationIndex = 1, dbid = CONFIG.platformDBID9, },
      type073a = { locations = {}, locationIndex = 1, dbid = CONFIG.platformDBID10, },
      type071InLSTArea = { locations = {}, locationIndex = 1, dbid = CONFIG.platformDBID7, },
      ferry = { locations = {}, locationIndex = 1, dbid = CONFIG.platformDBID56, },
      roro = { locations = {}, locationIndex = 1, dbid = CONFIG.platformDBID56, },
      barge = { locations = {}, locationIndex = 1, dbid = CONFIG.platformDBID72, },
    }
  },
  ['Penghu'] = {
    name = 'Penghu',
    result = {
      type075 = { locations = {}, locationIndex = 1, dbid = CONFIG.platformDBID6, },
      type071 = { locations = {}, locationIndex = 1, dbid = CONFIG.platformDBID7, },
      type076 = { locations = {}, locationIndex = 1, dbid = CONFIG.platformDBID54, },
      type072iii = { locations = {}, locationIndex = 1, dbid = CONFIG.platformDBID8, },
      type072a = { locations = {}, locationIndex = 1, dbid = CONFIG.platformDBID9, },
      type073a = { locations = {}, locationIndex = 1, dbid = CONFIG.platformDBID10, },
      type071InLSTArea = { locations = {}, locationIndex = 1, dbid = CONFIG.platformDBID7, },
      ferry = { locations = {}, locationIndex = 1, dbid = CONFIG.platformDBID56, },
      roro = { locations = {}, locationIndex = 1, dbid = CONFIG.platformDBID56, },
      barge = { locations = {}, locationIndex = 1, dbid = CONFIG.platformDBID72, },
    }
  },
  ['Sishu'] = {
    name = 'Sishu',
    result = {
      type075 = { locations = {}, locationIndex = 1, dbid = CONFIG.platformDBID6, },
      type071 = { locations = {}, locationIndex = 1, dbid = CONFIG.platformDBID7, },
      type076 = { locations = {}, locationIndex = 1, dbid = CONFIG.platformDBID54, },
      type072iii = { locations = {}, locationIndex = 1, dbid = CONFIG.platformDBID8, },
      type072a = { locations = {}, locationIndex = 1, dbid = CONFIG.platformDBID9, },
      type073a = { locations = {}, locationIndex = 1, dbid = CONFIG.platformDBID10, },
      type071InLSTArea = { locations = {}, locationIndex = 1, dbid = CONFIG.platformDBID7, },
      ferry = { locations = {}, locationIndex = 1, dbid = CONFIG.platformDBID56, },
      roro = { locations = {}, locationIndex = 1, dbid = CONFIG.platformDBID56, },
      barge = { locations = {}, locationIndex = 1, dbid = CONFIG.platformDBID72, },
    }
  },
}
SaveData.c.PHIBOP.barges = {
  -- [''] = {
  --     guid = '',
  --     bridgeGUID = '',
  --     roros = {},
  -- },
}

-- Land strike from DDG
SaveData.c.surface.lacm.isActivated = true
SaveData.c.surface.lacm.startTime = CONFIG.c.triggers['(China) (Surface/LACM) start time'].startTime


-- SLCM
SaveData.c.subSurface.slcm.isActivated = true
SaveData.c.subSurface.slcm.startTime = CONFIG.c.triggers['(China) (Sub-surface/SLCM) start time'].startTime


-- Runway repairment
SaveData.c.repairRunway.isActivated = false
SaveData.c.repairRunway.runways = {
  -- { guid = '', startTime = nil }
}

-- MLRS
SaveData.t.ground.mlrs.isActivated = true
SaveData.t.ground.mlrs.ammunitions = {
  ['IC8B0X-0HN9B47GHVJ7G'] = {
    guid = 'IC8B0X-0HN9B47GHVJ7G',
    wpnCurrent = CONFIG.t.ground.mlrs.wpnDefault,
    wpnDefault = CONFIG.t.ground.mlrs.wpnDefault,
  }
}
SaveData.t.ground.mlrs.ammunitionSections = {
  ['IC8B0X-0HN7RT1I581BB'] = {
    name = 'Ammo Sec, Rocket Arty Coy, 21st Arty Command',
    guid = 'IC8B0X-0HN7RT1I581BB',
    wpnCurrent = CONFIG.t.ground.mlrs.wpnDefault,
    wpnDefault = CONFIG.t.ground.mlrs.wpnDefault,
    unitCount = 2,
    position = CONFIG.t.ground.mlrs.positions.pingzhen,
    reloadStartTime = nil,
    state = CONFIG.batteryState.STATIC,
    ammunition = 'IC8B0X-0HN9B47GHVJ7G',
  }
}
SaveData.t.ground.mlrs.batteries = {
  ['IC8B0X-0HN7RU9I3KV9T'] = {
    name = 'Rocket Arty Coy, 21st Arty Command',
    msg = 'Radio source, Bty',
    guid = 'IC8B0X-0HN7RU9I3KV9T',
    reloadStartTime = nil,
    state = CONFIG.batteryState.HIDE,
    position = CONFIG.t.ground.mlrs.positions.pingzhen,
    weaponDBID = 2948,
    ammoThreshold = CONFIG.t.ground.mlrs.ammoThreshold,
    ammunitionSection = 'IC8B0X-0HN7RT1I581BB'
  },
}


-- SRBM
SaveData.t.ground.srbm.isActivated = true
SaveData.t.ground.srbm.ammunitions = {
  ['IC8B0X-0HN9B47GHVJG6'] = {
    guid = 'IC8B0X-0HN9B47GHVJG6',
    wpnCurrent = CONFIG.t.ground.srbm.wpnDefault,
    wpnDefault = CONFIG.t.ground.srbm.wpnDefault,
  }
}
SaveData.t.ground.srbm.ammunitionSections = {
  ['IC8B0X-0HN7R5QOIVSFS'] = {
    name = 'Ammo Sec, Rocket Arty Coy, 58th Arty Command',
    guid = 'IC8B0X-0HN7R5QOIVSFS',
    wpnCurrent = CONFIG.t.ground.srbm.wpnDefault,
    wpnDefault = CONFIG.t.ground.srbm.wpnDefault,
    unitCount = 2,
    position = CONFIG.t.ground.srbm.positions.dadu,
    reloadStartTime = nil,
    state = CONFIG.batteryState.STATIC,
    ammunition = 'IC8B0X-0HN9B47GHVJG6',
  }
}
SaveData.t.ground.srbm.batteries = {
  ['IC8B0X-0HN7SOIUF4D47'] = {
    name = 'Rocket Arty Coy, 58th Arty Command',
    msg = 'Radio source, Bty',
    guid = 'IC8B0X-0HN7SOIUF4D47',
    reloadStartTime = nil,
    state = CONFIG.batteryState.HIDE,
    position = CONFIG.t.ground.srbm.positions.dadu,
    weaponDBID = 1717,
    ammoThreshold = CONFIG.t.ground.srbm.ammoThreshold,
    ammunitionSection = 'IC8B0X-0HN7R5QOIVSFS'
  },
}



-- GLCM
SaveData.t.ground.glcm.isActivated = true
SaveData.t.ground.glcm.ammunitions = {
  ['IC8B0X-0HN9B47GHVKAG'] = {
    guid = 'IC8B0X-0HN9B47GHVKAG',
    wpnCurrent = CONFIG.t.ground.glcm.wpnDefault * 2,
    wpnDefault = CONFIG.t.ground.glcm.wpnDefault * 2,
  },
  ['IC8B0X-0HN9B47GHVL3V'] = {
    guid = 'IC8B0X-0HN9B47GHVL3V',
    wpnCurrent = CONFIG.t.ground.glcm.wpnDefault * 2,
    wpnDefault = CONFIG.t.ground.glcm.wpnDefault * 2,
  }
}
SaveData.t.ground.glcm.ammunitionSections = {
  ['IC8B0X-0HN7R5QOIVTHT'] = {
    name = 'Ammo Sec, 641st Bn, 791st AFAD & Arty Bde',
    guid = 'IC8B0X-0HN7R5QOIVTHT',
    wpnCurrent = CONFIG.t.ground.glcm.wpnDefault,
    wpnDefault = CONFIG.t.ground.glcm.wpnDefault,
    unitCount = 2,
    position = CONFIG.t.ground.glcm.positions.quanxi,
    reloadStartTime = nil,
    state = CONFIG.batteryState.STATIC,
    ammunition = 'IC8B0X-0HN9B47GHVKAG',
  },
  ['IC8B0X-0HN7R5QOIVUDC'] = {
    name = 'Ammo Sec, 642nd Bn, 791st AFAD & Arty Bde',
    guid = 'IC8B0X-0HN7R5QOIVUDC',
    wpnCurrent = CONFIG.t.ground.glcm.wpnDefault,
    wpnDefault = CONFIG.t.ground.glcm.wpnDefault,
    unitCount = 2,
    position = CONFIG.t.ground.glcm.positions.neipu,
    reloadStartTime = nil,
    state = CONFIG.batteryState.STATIC,
    ammunition = 'IC8B0X-0HN9B47GHVL3V',
  },
}
SaveData.t.ground.glcm.batteries = {
  ['X58F5H-0HN1ESDRTUULO'] = {
    guid = 'X58F5H-0HN1ESDRTUULO',
    name = '641st Bn, 791st AFAD & Arty Bde',
    msg = 'Radio source, Bty',
    reloadStartTime = nil,
    state = CONFIG.batteryState.HIDE,
    position = CONFIG.t.ground.glcm.positions.quanxi,
    weaponDBID = 3228,
    ammoThreshold = CONFIG.t.ground.glcm.ammoThreshold,
    ammunitionSection = 'IC8B0X-0HN7R5QOIVTHT'
  },
  ['X58F5H-0HN1ESDRTLGU7'] = {
    guid = 'X58F5H-0HN1ESDRTLGU7',
    name = '642nd Bn, 791st AFAD & Arty Bde',
    msg = 'Radio source, Bty',
    reloadStartTime = nil,
    state = CONFIG.batteryState.HIDE,
    position = CONFIG.t.ground.glcm.positions.neipu,
    weaponDBID = 3228,
    ammoThreshold = CONFIG.t.ground.glcm.ammoThreshold,
    ammunitionSection = 'IC8B0X-0HN7R5QOIVUDC'
  }
}




-- ASM
SaveData.t.ground.ascm.isActivated = true
SaveData.t.ground.ascm.ammunitions = {
  ['IC8B0X-0HN9B47GHVLV9'] = {
    guid = 'IC8B0X-0HN9B47GHVLV9',
    wpnCurrent = CONFIG.t.ground.ascm.wpnDefault * 2,
    wpnDefault = CONFIG.t.ground.ascm.wpnDefault * 2,
  },
  ['IC8B0X-0HN9JFGVR06D8'] = {
    guid = 'IC8B0X-0HN9JFGVR06D8',
    wpnCurrent = CONFIG.t.ground.ascm.wpnDefault * 2,
    wpnDefault = CONFIG.t.ground.ascm.wpnDefault * 2,
  },
}
SaveData.t.ground.ascm.ammunitionSections = {
  ['IC8B0X-0HN87KFOFSGUB'] = {
    name = 'Hai Feng Shore-based ASM SUPP Sqn',
    guid = 'IC8B0X-0HN87KFOFSGUB',
    wpnCurrent = CONFIG.t.ground.ascm.wpnDefault,
    wpnDefault = CONFIG.t.ground.ascm.wpnDefault,
    unitCount = 2,
    position = CONFIG.t.ground.ascm.positions.pingzhen,
    reloadStartTime = nil,
    state = CONFIG.batteryState.STATIC,
    ammunition = 'IC8B0X-0HN9B47GHVLV9',
  },
  ['IC8B0X-0HN9JFGVR07U5'] = {
    name = 'Hai Feng Shore-based ASM SUPP Sqn',
    guid = 'IC8B0X-0HN9JFGVR07U5',
    wpnCurrent = CONFIG.t.ground.ascm.wpnDefault,
    wpnDefault = CONFIG.t.ground.ascm.wpnDefault,
    unitCount = 2,
    position = CONFIG.t.ground.ascm.positions.dong,
    reloadStartTime = nil,
    state = CONFIG.batteryState.STATIC,
    ammunition = 'IC8B0X-0HN9JFGVR06D8',
  },
}
SaveData.t.ground.ascm.batteries = {
  ['IC8B0X-0HN87MOIE9C4U'] = {
    name = '2nd Hai Feng Shore-based ASM MOB Sqn',
    msg = 'Radio source, Bty',
    guid = 'IC8B0X-0HN87MOIE9C4U',
    reloadStartTime = nil,
    state = CONFIG.batteryState.HIDE,
    position = CONFIG.t.ground.ascm.positions.luzhu,
    weaponDBID = 1133,
    ammoThreshold = CONFIG.t.ground.ascm.ammoThreshold,
    ammunitionSection = 'IC8B0X-0HN87KFOFSGUB'
  },
  ['X58F5H-0HMVEU1FUVOLC'] = {
    name = '4th Hai Feng Shore-based ASM MOB Sqn',
    msg = 'Radio source, Bty',
    guid = 'X58F5H-0HMVEU1FUVOLC',
    reloadStartTime = nil,
    state = CONFIG.batteryState.HIDE,
    position = CONFIG.t.ground.ascm.positions.luzhu,
    weaponDBID = 1133,
    ammoThreshold = CONFIG.t.ground.ascm.ammoThreshold,
    ammunitionSection = 'IC8B0X-0HN87KFOFSGUB'
  },
  ['X58F5H-0HMVEU1FUVO8I'] = {
    name = '1st Hai Feng Shore-based ASM MOB Sqn',
    msg = 'Radio source, Bty',
    guid = 'X58F5H-0HMVEU1FUVO8I',
    reloadStartTime = nil,
    state = CONFIG.batteryState.HIDE,
    position = CONFIG.t.ground.ascm.positions.dong,
    weaponDBID = 1133,
    ammoThreshold = CONFIG.t.ground.ascm.ammoThreshold,
    ammunitionSection = 'IC8B0X-0HN9JFGVR07U5'
  },
  ['X58F5H-0HMVEU1FUVO6J'] = {
    name = '3rd Hai Feng Shore-based ASM MOB Sqn',
    msg = 'Radio source, Bty',
    guid = 'X58F5H-0HMVEU1FUVO6J',
    reloadStartTime = nil,
    state = CONFIG.batteryState.HIDE,
    position = CONFIG.t.ground.ascm.positions.dong,
    weaponDBID = 1133,
    ammoThreshold = CONFIG.t.ground.ascm.ammoThreshold,
    ammunitionSection = 'IC8B0X-0HN9JFGVR07U5'
  },
  ['IC8B0X-0HN8CEO4EUE8B'] = {
    name = '5th Hai Feng Shore-based ASM MOB Sqn',
    msg = 'Radio source, Bty',
    guid = 'IC8B0X-0HN8CEO4EUE8B',
    reloadStartTime = nil,
    state = CONFIG.batteryState.HIDE,
    position = CONFIG.t.ground.ascm.positions.luzhu,
    weaponDBID = 1133,
    ammoThreshold = CONFIG.t.ground.ascm.ammoThreshold,
    ammunitionSection = 'IC8B0X-0HN87KFOFSGUB'
  },
}
SaveData.t.ground.ascm.test = {
  isAntishipMissionActivated = false,
  nai1 = CONFIG.t.areas.groundAscmTestNai1,
  nai2 = CONFIG.t.areas.groundAscmTestNai2,
  shipNumInNai1 = 4,
  helicopterNumInNai2 = 4
}

-- Runway repairment
SaveData.t.repairRunway.isActivated = false
SaveData.t.repairRunway.runways = {
  -- { guid = '', startTime = nil }
}


-- IADS
SaveData.t.IADS.isActivated = true
SaveData.t.IADS.ROCC = {
  ['IC8B0X-0HNC3OB4KJKIF'] = {
    name = 'ROCC/North',
    msg = 'Radio source, C2',
    guid = 'IC8B0X-0HNC3OB4KJKIF',
    areas = {
      CONFIG.t.areas["OPAREA/3RD"],
    },
    SAM = {},
    radar = {}
  },
  ['IC8B0X-0HNC3OB4KJKTC'] = {
    name = 'ROCC/East',
    msg = 'Radio source, C2',
    guid = 'IC8B0X-0HNC3OB4KJKTC',
    areas = { CONFIG.t.areas["OPAREA/2ND"], CONFIG.t.areas["OPAREA/5TH"], },
    SAM = {},
    radar = {}
  },
  ['IC8B0X-0HNC3OB4KJL2M'] = {
    name = 'ROCC/South',
    msg = 'Radio source, C2',
    guid = 'IC8B0X-0HNC3OB4KJL2M',
    areas = {
      CONFIG.t.areas["OPAREA/4TH"],
    },
    SAM = {},
    radar = {}
  },
}
SaveData.t.IADS.TAAOC = {
  ['IC8B0X-0HN41D1QKTVU7'] = {
    name = 'TAAOC/3rd OPAREA',
    msg = 'Radio source, C2',
    guid = 'IC8B0X-0HN41D1QKTVU7',
    areas = {
      CONFIG.t.areas["OPAREA/3RD"],
    },
    SAM = {},
  },
  ['IC8B0X-0HN41D1QKU1ED'] = {
    name = 'TAAOC/5th OPAREA',
    msg = 'Radio source, C2',
    guid = 'IC8B0X-0HN41D1QKU1ED',
    areas = {
      CONFIG.t.areas["OPAREA/5TH"],
    },
    SAM = {},
  },
  ['IC8B0X-0HN41D1QKU0JP'] = {
    name = 'TAAOC/4th OPAREA',
    msg = 'Radio source, C2',
    guid = 'IC8B0X-0HN41D1QKU0JP',
    areas = {
      CONFIG.t.areas["OPAREA/4TH"],
    },
    SAM = {},
  },
  ['IC8B0X-0HNC27TV5Q0AS'] = {
    name = 'TAAOC/2nd OPAREA',
    msg = 'Radio source, C2',
    guid = 'IC8B0X-0HNC27TV5Q0AS',
    areas = {
      CONFIG.t.areas["OPAREA/2ND"],
    },
    SAM = {},
  },
}


-- Aircraft
SaveData.t.air.landBased.AEW = {
  -- {guid=''}
}
SaveData.t.air.landBased.AC = {
  -- {guid=''}
}


-- SIGINT
SaveData.u.SIGINT.isActivated = true
SaveData.u.SIGINT.RA = {}
SaveData.u.SIGINT.transmissions = {
  -- [''] = {
  --     name = '',
  --     latitude = 0,
  --     longitude = 0,
  --     contacts = { { guid = '' } }
  -- },
}

-- ScenEdit_SetLoadout({unitname='5th Tactical Mixed Wing #1', LoadoutID=22790, TimeToReady_Minutes=90})
return SaveData
