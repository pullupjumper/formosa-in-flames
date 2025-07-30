local config = require('src.core.constants')

---@class SBJ__SaveData
local saveData = {}
saveData.c = {}
saveData.c.targetlist = {}
saveData.c.air = {}
saveData.c.air.landBased = {}
saveData.c.air.shipBased = {}
saveData.c.ground = {}
saveData.c.ground.mlrs = {}
saveData.c.ground.srbm = {}
saveData.c.ground.mrbm = {}
saveData.c.ground.glcm = {}
saveData.c.ground.ascm = {}
saveData.c.ground.dynamicFSP = {}
saveData.c.surface = {}
saveData.c.surface.lacm = {}
saveData.c.subSurface = {}
saveData.c.subSurface.slcm = {}
saveData.c.PHIBOP = {}
saveData.c.recon = {}
saveData.c.GPSJamming = {}
saveData.c.commsJamming = {}
saveData.c.repairRunway = {}
saveData.c.IADS = {}
saveData.c.SIGINT = {}
saveData.t = {}
saveData.t.ground = {}
saveData.t.ground.mlrs = {}
saveData.t.ground.glcm = {}
saveData.t.ground.srbm = {}
saveData.t.ground.ascm = {}
saveData.t.repairRunway = {}
saveData.t.IADS = {}
saveData.t.air = {}
saveData.t.air.landBased = {}
saveData.u = {}
saveData.u.SIGINT = {}
saveData.s = {}

-- SIGINT
saveData.c.SIGINT.isActivated = true
saveData.c.SIGINT.RA = {}
saveData.c.SIGINT.transmissions = {
  -- [''] = {
  --     name = '',
  --     latitude = 0,
  --     longitude = 0,
  --     contacts = { { guid = '' } }
  -- },
}


-- IADS
saveData.c.IADS.isActivated = true
saveData.c.IADS.C2 = {
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
saveData.c.commsJamming.isActivated = true
saveData.c.commsJamming.jammers = {
  -- { guid = '' },
}

-- GPS Jamming
saveData.c.GPSJamming.isActivated = true
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
saveData.c.ground.mlrs.isActivated = true
saveData.c.ground.mlrs.ammunitions = {
  ['IC8B0X-0HN9ASEFCGDKF'] = {
    guid = 'IC8B0X-0HN9ASEFCGDKF',
    wpnCurrent = config.c.ground.mlrs.wpnDefault,
    wpnDefault = config.c.ground.mlrs.wpnDefault,
  },
  ['IC8B0X-0HNBRRE2PRT40'] = {
    guid = 'IC8B0X-0HNBRRE2PRT40',
    wpnCurrent = config.c.ground.mlrs.wpnDefault,
    wpnDefault = config.c.ground.mlrs.wpnDefault,
  },
}
saveData.c.ground.mlrs.ammunitionSections = {
  ['IC8B0X-0HN7R5QOERV4D'] = {
    guid = 'IC8B0X-0HN7R5QOERV4D',
    name = 'Ammo Sec, 1st Bn, 1st Rockets Arty Bde',
    wpnCurrent = config.c.ground.mlrs.wpnDefault,
    wpnDefault = config.c.ground.mlrs.wpnDefault,
    unitCount = 3,
    position = config.c.ground.mlrs.positions.pingtan,
    reloadStartTime = nil,
    state = config.batteryState.STATIC,
    ammunition = 'IC8B0X-0HN9ASEFCGDKF',
  },
  ['IC8B0X-0HNBRRE2PRRG9'] = {
    guid = 'IC8B0X-0HNBRRE2PRRG9',
    name = 'Ammo Sec, 6th Bn, 73rd Arty Bde',
    wpnCurrent = config.c.ground.mlrs.wpnDefault,
    wpnDefault = config.c.ground.mlrs.wpnDefault,
    unitCount = 3,
    position = config.c.ground.mlrs.positions.chinchew,
    reloadStartTime = nil,
    state = config.batteryState.STATIC,
    ammunition = 'IC8B0X-0HNBRRE2PRT40',
  },
}
saveData.c.ground.mlrs.batteries = {
  ['IC8B0X-0HND05GGU36EN'] = {
    name = '1st Bn, 1st Rockets Arty Bde',
    msg = 'Radio source, Bty',
    guid = 'IC8B0X-0HND05GGU36EN',
    reloadStartTime = nil,
    state = config.batteryState.HIDE,
    position = config.c.ground.mlrs.positions.pingtan,
    weaponDBID = config.weaponDBID1,
    ammoThreshold = config.c.ground.mlrs.ammoThreshold,
    ammunitionSection = 'IC8B0X-0HN7R5QOERV4D'
  },
  ['IC8B0X-0HNBRRE2PRQAL'] = {
    name = '6th Bn, 73rd Arty Bde',
    msg = 'Radio source, Bty',
    guid = 'IC8B0X-0HNBRRE2PRQAL',
    reloadStartTime = nil,
    state = config.batteryState.HIDE,
    position = config.c.ground.mlrs.positions.chinchew,
    weaponDBID = config.weaponDBID1,
    ammoThreshold = config.c.ground.mlrs.ammoThreshold,
    ammunitionSection = 'IC8B0X-0HNBRRE2PRRG9'
  },
}


-- GLCM
saveData.c.ground.glcm.isActivated = true
saveData.c.ground.glcm.ammunitions = {
  ['IC8B0X-0HN99I5RL5KR9'] = {
    guid = 'IC8B0X-0HN99I5RL5KR9',
    wpnCurrent = config.c.ground.glcm.wpnDefault,
    wpnDefault = config.c.ground.glcm.wpnDefault,
  },
}
saveData.c.ground.glcm.ammunitionSections = {
  ['IC8B0X-0HN7R5QOIVG88'] = {
    guid = 'IC8B0X-0HN7R5QOIVG88',
    name = 'Ammo Sec, 635th Bde, PLARF',
    wpnCurrent = config.c.ground.glcm.wpnDefault,
    wpnDefault = config.c.ground.glcm.wpnDefault,
    unitCount = 8,
    position = config.c.ground.glcm.positions.brigade635,
    reloadStartTime = nil,
    state = config.batteryState.STATIC,
    ammunition = 'IC8B0X-0HN99I5RL5KR9',
  },
}


saveData.c.ground.glcm.batteries = {
  ---@type SBJ__Battery
  ['6Z8LM5-0HMN97ERAUODK'] = {
    guid = '6Z8LM5-0HMN97ERAUODK',
    name = '635th Bde',
    msg = 'Radio source, Bty',
    reloadStartTime = nil,
    state = config.batteryState.HIDE,
    position = config.c.ground.glcm.positions.brigade635,
    weaponDBID = config.weaponDBID2,
    ammoThreshold = config.c.ground.glcm.ammoThreshold,
    ammunitionSection = 'IC8B0X-0HN7R5QOIVG88'
  },
}


-- SRBM
saveData.c.ground.srbm.isActivated = true
saveData.c.ground.srbm.ammunitions = {
  ['IC8B0X-0HN9ASEFCG848'] = {
    guid = 'IC8B0X-0HN9ASEFCG848',
    wpnCurrent = config.c.ground.srbm.wpnDefault * 2,
    wpnDefault = config.c.ground.srbm.wpnDefault * 2,
  },
  ['IC8B0X-0HN9ASEFCG95Q'] = {
    guid = 'IC8B0X-0HN9ASEFCG95Q',
    wpnCurrent = config.c.ground.srbm.wpnDefault * 2,
    wpnDefault = config.c.ground.srbm.wpnDefault * 2,
  },
  ['IC8B0X-0HN9ASEFCG8CT'] = {
    guid = 'IC8B0X-0HN9ASEFCG8CT',
    wpnCurrent = config.c.ground.srbm.wpnDefault * 2,
    wpnDefault = config.c.ground.srbm.wpnDefault * 2,
  },
  ['IC8B0X-0HN9ASEFCG8OK'] = {
    guid = 'IC8B0X-0HN9ASEFCG8OK',
    wpnCurrent = config.c.ground.srbm.wpnDefault * 2,
    wpnDefault = config.c.ground.srbm.wpnDefault * 2,
  },
  ['IC8B0X-0HN9ASEFCG9GA'] = {
    guid = 'IC8B0X-0HN9ASEFCG9GA',
    wpnCurrent = config.c.ground.srbm.wpnDefault * 2,
    wpnDefault = config.c.ground.srbm.wpnDefault * 2,
  },
  ['IC8B0X-0HN9ASEFCGA5A'] = {
    guid = 'IC8B0X-0HN9ASEFCGA5A',
    wpnCurrent = config.c.ground.srbm.wpnDefault * 2,
    wpnDefault = config.c.ground.srbm.wpnDefault * 2,
  },
}
saveData.c.ground.srbm.ammunitionSections = {
  ['IC8B0X-0HN7R5QOIVL7D'] = {
    guid = 'IC8B0X-0HN7R5QOIVL7D',
    name = 'Ammo Sec, 615th Bde, PLARF',
    wpnCurrent = config.c.ground.srbm.wpnDefault,
    wpnDefault = config.c.ground.srbm.wpnDefault,
    unitCount = 9,
    position = config.c.ground.srbm.positions.brigade615,
    reloadStartTime = nil,
    state = config.batteryState.STATIC,
    ammunition = 'IC8B0X-0HN9ASEFCG848',
  },
  ['IC8B0X-0HN7R5QOIVLSG'] = {
    guid = 'IC8B0X-0HN7R5QOIVLSG',
    name = 'Ammo Sec, 614th Bde, PLARF',
    wpnCurrent = config.c.ground.srbm.wpnDefault,
    wpnDefault = config.c.ground.srbm.wpnDefault,
    unitCount = 9,
    position = config.c.ground.srbm.positions.brigade614,
    reloadStartTime = nil,
    state = config.batteryState.STATIC,
    ammunition = 'IC8B0X-0HN9ASEFCG95Q',
  },
  ['IC8B0X-0HN7R5QOIVMO1'] = {
    guid = 'IC8B0X-0HN7R5QOIVMO1',
    name = 'Ammo Sec, 636th Bde, PLARF',
    wpnCurrent = config.c.ground.srbm.wpnDefault,
    wpnDefault = config.c.ground.srbm.wpnDefault,
    unitCount = 9,
    position = config.c.ground.srbm.positions.brigade636,
    reloadStartTime = nil,
    state = config.batteryState.STATIC,
    ammunition = 'IC8B0X-0HN9ASEFCG8CT',
  },
  ['IC8B0X-0HN7R5QOIVOSN'] = {
    guid = 'IC8B0X-0HN7R5QOIVOSN',
    name = 'Ammo Sec, 616th Bde, PLARF',
    wpnCurrent = config.c.ground.srbm.wpnDefault,
    wpnDefault = config.c.ground.srbm.wpnDefault,
    unitCount = 9,
    position = config.c.ground.srbm.positions.brigade616,
    reloadStartTime = nil,
    state = config.batteryState.STATIC,
    ammunition = 'IC8B0X-0HN9ASEFCG8OK',
  },
  ['IC8B0X-0HN7R5QOIVPNC'] = {
    guid = 'IC8B0X-0HN7R5QOIVPNC',
    name = 'Ammo Sec, 613rd Bde, PLARF',
    wpnCurrent = config.c.ground.srbm.wpnDefault,
    wpnDefault = config.c.ground.srbm.wpnDefault,
    unitCount = 9,
    position = config.c.ground.srbm.positions.brigade613,
    reloadStartTime = nil,
    state = config.batteryState.STATIC,
    ammunition = 'IC8B0X-0HN9ASEFCG9GA',
  },
  ['IC8B0X-0HN7R5QOIVQ6P'] = {
    guid = 'IC8B0X-0HN7R5QOIVQ6P',
    name = 'Ammo Sec, 617th Bde, PLARF',
    wpnCurrent = config.c.ground.srbm.wpnDefault,
    wpnDefault = config.c.ground.srbm.wpnDefault,
    unitCount = 9,
    position = config.c.ground.srbm.positions.brigade617,
    reloadStartTime = nil,
    state = config.batteryState.STATIC,
    ammunition = 'IC8B0X-0HN9ASEFCGA5A',
  },
}
saveData.c.ground.srbm.batteries = {
  ['X58F5H-0HN1G2IFLNKG9'] = {
    guid = 'X58F5H-0HN1G2IFLNKG9',
    name = '615th Bde',
    msg = 'Radio source, Bty',
    reloadStartTime = nil,
    state = config.batteryState.HIDE,
    position = config.c.ground.srbm.positions.brigade615,
    weaponDBID = config.weaponDBID3,
    ammoThreshold = config.c.ground.srbm.ammoThreshold,
    ammunitionSection = 'IC8B0X-0HN7R5QOIVL7D'
  },
  ['X58F5H-0HN1LQGRV8HNQ'] = {
    guid = 'X58F5H-0HN1LQGRV8HNQ',
    name = '614th Bde',
    msg = 'Radio source, Bty',
    reloadStartTime = nil,
    state = config.batteryState.HIDE,
    position = config.c.ground.srbm.positions.brigade614,
    weaponDBID = config.weaponDBID3,
    ammoThreshold = config.c.ground.srbm.ammoThreshold,
    ammunitionSection = 'IC8B0X-0HN7R5QOIVLSG'
  },
  ['IC8B0X-0HN822OHANPB3'] = {
    guid = 'IC8B0X-0HN822OHANPB3',
    name = '636th Bde',
    msg = 'Radio source, Bty',
    reloadStartTime = nil,
    state = config.batteryState.HIDE,
    position = config.c.ground.srbm.positions.brigade636,
    weaponDBID = config.weaponDBID4,
    ammoThreshold = config.c.ground.srbm.ammoThreshold,
    ammunitionSection = 'IC8B0X-0HN7R5QOIVMO1'
  },
  ['X58F5H-0HN1G2IFLF6QE'] = {
    guid = 'X58F5H-0HN1G2IFLF6QE',
    name = '616th Bde',
    msg = 'Radio source, Bty',
    reloadStartTime = nil,
    state = config.batteryState.HIDE,
    position = config.c.ground.srbm.positions.brigade616,
    weaponDBID = config.weaponDBID5,
    ammoThreshold = config.c.ground.srbm.ammoThreshold,
    ammunitionSection = 'IC8B0X-0HN7R5QOIVOSN'
  },
  ['X58F5H-0HN1G2DEBC7O8'] = {
    guid = 'X58F5H-0HN1G2DEBC7O8',
    name = '613rd Bde',
    msg = 'Radio source, Bty',
    reloadStartTime = nil,
    state = config.batteryState.HIDE,
    position = config.c.ground.srbm.positions.brigade613,
    weaponDBID = config.weaponDBID6,
    ammoThreshold = config.c.ground.srbm.ammoThreshold,
    ammunitionSection = 'IC8B0X-0HN7R5QOIVPNC'
  },
  ['IC8B0X-0HN822OHANRHI'] = {
    guid = 'IC8B0X-0HN822OHANRHI',
    name = '617th Bde',
    msg = 'Radio source, Bty',
    reloadStartTime = nil,
    state = config.batteryState.HIDE,
    position = config.c.ground.srbm.positions.brigade617,
    weaponDBID = config.weaponDBID4,
    ammoThreshold = config.c.ground.srbm.ammoThreshold,
    ammunitionSection = 'IC8B0X-0HN7R5QOIVQ6P'
  },
}

-- MRBM
saveData.c.ground.mrbm.isActivated = true
saveData.c.ground.mrbm.ammunitions = {
  ['IC8B0X-0HNCOR6HG2KK5'] = {
    guid = 'IC8B0X-0HNCOR6HG2KK5',
    wpnCurrent = config.c.ground.mrbm.wpnDefault * 2,
    wpnDefault = config.c.ground.mrbm.wpnDefault * 2,
  },
}
saveData.c.ground.mrbm.ammunitionSections = {
  ['IC8B0X-0HNCOR6HG2KF9'] = {
    guid = 'IC8B0X-0HNCOR6HG2KF9',
    name = 'Ammo Sec, 624th Bde, PLARF',
    wpnCurrent = config.c.ground.mrbm.wpnDefault,
    wpnDefault = config.c.ground.mrbm.wpnDefault,
    unitCount = 6,
    position = config.c.ground.mrbm.positions.brigade624,
    reloadStartTime = nil,
    state = config.batteryState.STATIC,
    ammunition = 'IC8B0X-0HNCOR6HG2KK5',
  },
}
saveData.c.ground.mrbm.batteries = {
  ['IC8B0X-0HNCOR6HG2JE1'] = {
    guid = 'IC8B0X-0HNCOR6HG2JE1',
    name = '624th Bde',
    msg = 'Radio source, Bty',
    reloadStartTime = nil,
    state = config.batteryState.HIDE,
    position = config.c.ground.mrbm.positions.brigade624,
    weaponDBID = config.weaponDBID7,
    ammoThreshold = config.c.ground.mrbm.ammoThreshold,
    ammunitionSection = 'IC8B0X-0HNCOR6HG2KF9'
  },
}

-- Recon
saveData.c.recon.isActivated = true
saveData.c.recon.temp = {
  H6N = {},
  WZ8 = {},
  BZK005 = {}
}
saveData.c.recon.queue = {
  {
    baseGUID = config.baseGUID11,
    unitDBID = config.platformDBID76,
    unitGUID = nil,
    missionName = nil,
    course = config.c.recon.courses.H6N,
    unitCount = 1,
    -- takeoffTime = '2027-06-09 01:20:00',
    takeoffTime = '2027-06-09 01:00:00',
    missionStartTime = nil,
    hasLaunched = false,
    isTracking = true
  },
}

-- Fire support plan
saveData.c.ground.isActivated = true
saveData.c.ground.FSP = {
  -- ['STRIKE/INFRASTRUCTURE/1'] = {
  --   name = 'STRIKE/INFRASTRUCTURE/1',
  --   isActivated = true,
  --   isFirstWave = true,
  --   strikeInterval = 0 * 60,
  --   reconUAVs = nil,
  --   allBatteriesInPosition = false,
  --   isFinished = false,
  --   -- Fire support task
  --   ---@type SBJ__FireSupportTask[]
  --   FSTs = {
  --     {
  --       name = 'RADAR',
  --       wpnSystem = 'SRBM',
  --       batteries = {
  --         {
  --           name = '614th Bde',
  --           guid = 'X58F5H-0HN1LQGRV8HNQ',
  --           weaponDBID = saveData.c.ground.srbm.batteries['X58F5H-0HN1LQGRV8HNQ'].weaponDBID
  --         },
  --         {
  --           name = '613rd Bde',
  --           guid = 'X58F5H-0HN1G2DEBC7O8',
  --           weaponDBID = saveData.c.ground.srbm.batteries['X58F5H-0HN1G2DEBC7O8'].weaponDBID
  --         }
  --       },
  --       target = {
  --         list = {},
  --         evaluatedlist = {},
  --         objs = {
  --           { baseName = nil, subTypes = { 'Radar', 'Hengshan ROC command', 'Sky Bow' } },
  --         },
  --         areas = {},
  --         filterNames = nil,
  --         contactAge = config.c.ground.srbm.contactAge,
  --         minTargetCount = 4,
  --         ammoPerTarget = 3
  --       },
  --       startTime = '2027-06-09 01:00:00',
  --       isFinished = false
  --     },
  --     {
  --       name = 'RUNWAY',
  --       wpnSystem = 'SRBM',
  --       batteries = {
  --         {
  --           name = '636th Bde',
  --           guid = 'IC8B0X-0HN822OHANPB3',
  --           weaponDBID = saveData.c.ground.srbm.batteries['IC8B0X-0HN822OHANPB3'].weaponDBID
  --         },
  --         {
  --           name = '617th Bde',
  --           guid = 'IC8B0X-0HN822OHANRHI',
  --           weaponDBID = saveData.c.ground.srbm.batteries['IC8B0X-0HN822OHANRHI'].weaponDBID
  --         }
  --       },
  --       target = {
  --         list = {},
  --         evaluatedlist = {},
  --         objs = {
  --           { baseName = 'Hualien AB',           subTypes = { 'Runway %(%d+m%)', 'Taxiway' } },
  --           { baseName = 'Taitung/Jhihhang AB',  subTypes = { 'Runway %(%d+m%)', 'Taxiway' } },
  --           { baseName = 'Ching Chuang Kang AB', subTypes = { 'Runway %(%d+m%)', 'Taxiway' } },
  --           { baseName = 'Chiayi AB',            subTypes = { 'Runway %(%d+m%)', 'Taxiway' } },
  --           { baseName = 'Tainan AB',            subTypes = { 'Runway %(%d+m%)', 'Taxiway' } },
  --           { baseName = 'Pingtung South AB',    subTypes = { 'Runway %(%d+m%)', 'Taxiway' } },
  --           { baseName = 'Pingtung North AB',    subTypes = { 'Runway %(%d+m%)', 'Taxiway' } },
  --           { baseName = 'Magong AB',            subTypes = { 'Runway %(%d+m%)', 'Taxiway' } },
  --           { baseName = 'Hsinchu AB',           subTypes = { 'Runway %(%d+m%)', 'Taxiway' } },
  --         },
  --         areas = {},
  --         filterNames = nil,
  --         contactAge = config.c.ground.srbm.contactAge,
  --         minTargetCount = 4,
  --         ammoPerTarget = 4
  --       },
  --       startTime = nil,
  --       isFinished = false
  --     },
  --     {
  --       name = 'PORT',
  --       wpnSystem = 'SRBM',
  --       batteries = {
  --         {
  --           name = '615th Bde',
  --           guid = 'X58F5H-0HN1G2IFLNKG9',
  --           weaponDBID = saveData.c.ground.srbm.batteries['X58F5H-0HN1G2IFLNKG9'].weaponDBID
  --         }
  --       },
  --       target = {
  --         list = {},
  --         evaluatedlist = {},
  --         objs = {
  --           { baseName = 'Port of Keelung', subTypes = { 'Pier' } },
  --           { baseName = 'Suao Port',       subTypes = { 'Pier' } },
  --           { baseName = 'Kaohsiung Port',  subTypes = { 'Pier' } },
  --           { baseName = 'Magong Port',     subTypes = { 'Pier' } },
  --           { baseName = nil,               subTypes = { 'ASM' } },
  --         },
  --         areas = {},
  --         filterNames = nil,
  --         contactAge = config.c.ground.srbm.contactAge,
  --         minTargetCount = 4,
  --         ammoPerTarget = 2
  --       },
  --       startTime = nil,
  --       isFinished = false
  --     },
  --     {
  --       name = 'SHELTER',
  --       wpnSystem = 'SRBM',
  --       batteries = {
  --         {
  --           name = '616th Bde',
  --           guid = 'X58F5H-0HN1G2IFLF6QE',
  --           weaponDBID = saveData.c.ground.srbm.batteries['X58F5H-0HN1G2IFLF6QE'].weaponDBID
  --         }
  --       },
  --       target = {
  --         list = {},
  --         evaluatedlist = {},
  --         objs = {
  --           { baseName = 'Chiayi AB',            subTypes = { 'Shelter', 'Tarmac', 'Hangar' } },
  --           { baseName = 'Pingtung South AB',    subTypes = { 'Shelter', 'Tarmac', 'Hangar' } },
  --           { baseName = 'Ching Chuang Kang AB', subTypes = { 'Shelter', 'Tarmac', 'Hangar' } },
  --           { baseName = 'Magong AB',            subTypes = { 'Shelter', 'Tarmac', 'Hangar' } },
  --         },
  --         areas = {},
  --         filterNames = nil,
  --         contactAge = config.c.ground.srbm.contactAge,
  --         minTargetCount = 4,
  --         ammoPerTarget = 2
  --       },
  --       startTime = nil,
  --       isFinished = false
  --     },
  --   }
  -- },
  -- ['STRIKE/C2/1'] = {
  --   name = 'STRIKE/C2/1',
  --   isActivated = true,
  --   isFirstWave = false,
  --   strikeInterval = 0 * 60,
  --   reconUAVs = nil,
  --   isFinished = false,
  --   allBatteriesInPosition = false,
  --   -- Fire support task
  --   ---@type SBJ__FireSupportTask[]
  --   FSTs = {
  --     {
  --       name = 'PINGTAN',
  --       wpnSystem = 'MLRS',
  --       batteries = {
  --         {
  --           name = '1st Bn, 1st Rockets Arty Bde',
  --           guid = 'IC8B0X-0HND05GGU36EN',
  --           weaponDBID = saveData.c.ground.mlrs.batteries['IC8B0X-0HND05GGU36EN'].weaponDBID
  --         }
  --       },
  --       target = {
  --         list = {},
  --         evaluatedlist = {},
  --         objs = {},
  --         areas = { config.c.areas["OPAREA/NORTH"] },
  --         filterNames = { 'analyzeEmissions', 'findRadioDirection' },
  --         contactAge = config.c.ground.mlrs.contactAge,
  --         minTargetCount = 2,
  --         ammoPerTarget = 8
  --       },
  --       startTime = '2027-06-09 01:30:00',
  --       -- startTime =  '2027-06-09 03:10:00'
  --       isFinished = false
  --     },
  --     {
  --       name = 'CHINCHEW',
  --       wpnSystem = 'MLRS',
  --       batteries = {
  --         {
  --           name = '6th Bn, 73rd Arty Bde',
  --           guid = 'IC8B0X-0HNBRRE2PRQAL',
  --           weaponDBID = saveData.c.ground.mlrs.batteries['IC8B0X-0HNBRRE2PRQAL'].weaponDBID
  --         }
  --       },
  --       target = {
  --         list = {},
  --         evaluatedlist = {},
  --         objs = {},
  --         areas = { config.c.areas["OPAREA/CENTER"] },
  --         filterNames = { 'analyzeEmissions', 'findRadioDirection' },
  --         contactAge = config.c.ground.mlrs.contactAge,
  --         minTargetCount = 2,
  --         ammoPerTarget = 8
  --       },
  --       startTime = nil,
  --       isFinished = false
  --     },
  --   }
  -- },
  -- ['STRIKE/HELIPAD'] = {
  --   name = 'STRIKE/HELIPAD',
  --   isActivated = true,
  --   isFirstWave = true,
  --   strikeInterval = 60 * 60,
  --   reconUAVs = nil,
  --   isFinished = false,
  --   allBatteriesInPosition = false,
  --   -- Fire support task
  --   FSTs = {
  --     {
  --       name = 'HELIPAD',
  --       wpnSystem = 'GLCM',
  --       batteries = {
  --         {
  --           name = '635th Bde',
  --           guid = '6Z8LM5-0HMN97ERAUODK',
  --           weaponDBID = saveData.c.ground.glcm.batteries['6Z8LM5-0HMN97ERAUODK'].weaponDBID
  --         }
  --       },
  --       target = {
  --         list = {},
  --         evaluatedlist = {},
  --         objs = {
  --           { baseName = 'Guiren AAB',  subTypes = { 'Helipad' } },
  --           { baseName = 'Longtan AAB', subTypes = { 'Helipad' } },
  --         },
  --         areas = {},
  --         filterNames = nil,
  --         contactAge = config.c.ground.glcm.contactAge,
  --         minTargetCount = 1,
  --         ammoPerTarget = 2
  --       },
  --       -- startTime = '2027-06-09 05:30:00',
  --       startTime = '2027-06-09 02:00:00',
  --       isFinished = false
  --     },
  --     {
  --       name = 'EMERGENCY HIGHWAY STRIP',
  --       wpnSystem = 'GLCM',
  --       batteries = {
  --         {
  --           name = '635th Bde',
  --           guid = '6Z8LM5-0HMN97ERAUODK',
  --           weaponDBID = saveData.c.ground.glcm.batteries['6Z8LM5-0HMN97ERAUODK'].weaponDBID
  --         }
  --       },
  --       target = {
  --         list = {},
  --         evaluatedlist = {},
  --         objs = {
  --           { baseName = 'Minxiong Emergency Highway Strip', subTypes = { 'Runway %(%d+m%)', 'Taxiway' } },
  --           { baseName = 'Madou Emergency Highway Strip',    subTypes = { 'Runway %(%d+m%)', 'Taxiway' } },
  --           { baseName = 'Rende Emergency Highway Strip',    subTypes = { 'Runway %(%d+m%)', 'Taxiway' } },
  --         },
  --         areas = {},
  --         filterNames = nil,
  --         contactAge = config.c.ground.glcm.contactAge,
  --         minTargetCount = 1,
  --         ammoPerTarget = 4
  --       },
  --       startTime = nil,
  --       isFinished = false
  --     },
  --   }
  -- },
  -- ['ANTISHIP/EAST'] = {
  --   name = 'ANTISHIP/EAST',
  --   isActivated = true,
  --   isFirstWave = false,
  --   strikeInterval = 0 * 60,
  --   reconUAVs = nil,
  --   isFinished = false,
  --   allBatteriesInPosition = false,
  --   -- Fire support task
  --   FSTs = {
  --     {
  --       name = 'ANTISHIP',
  --       wpnSystem = 'MRBM',
  --       batteries = {
  --         {
  --           name = '624th Bde',
  --           guid = 'IC8B0X-0HNCOR6HG2JE1',
  --           weaponDBID = saveData.c.ground.mrbm.batteries['IC8B0X-0HNCOR6HG2JE1'].weaponDBID
  --         }
  --       },
  --       target = {
  --         list = {},
  --         evaluatedlist = {},
  --         objs = {},
  --         areas = { config.c.areas["OPAREA/PACIFIC"] },
  --         filterNames = { 'findNavalTargets' },
  --         contactAge = config.c.ground.mrbm.contactAge,
  --         minTargetCount = 1,
  --         ammoPerTarget = 6
  --       },
  --       startTime = '2027-06-09 02:10:00',
  --       isFinished = false
  --     },
  --   }
  -- }
}

-- Air tasking order (NEW VERSION WITH LOADOUT SUPPORT)
saveData.c.air.isActivated = true
saveData.c.air.ATO = {
  ['STRIKE/AB/W/1'] = {
    name = 'STRIKE/AB/W/1',
    isActivated = true,
    isFirstWave = true,
    hasLaunched = false,
    strikeInterval = 30 * 60,
    ---@type SBJ__Package[]
    packages = {
      ---@type SBJ__Package
      {
        timeToReady = 5, -- 此 package 的武器掛載準備時間（分鐘）
        loadoutStatus = {
          isLoadoutInitiated = false,
          loadoutInitiatedTime = nil,
          expectedReadyTime = nil,
          loadoutStartTime = nil
        },
        striker = {
          baseGUID = config.baseGUID2,
          weaponDBID = config.weaponDBID10,
          unitDBID = config.platformDBID29,
          unitCount = 12,
          loadoutID = config.loadoutDBID7,
          startTime = '2027-06-09 01:25:00',
          missionParams = { name = 'STRIKE/AB/W/1', type = 'strike', opts = { type = 'land' } },
          emcon = 'Radar=Passive;OECM=Active'
        },
        escort = {
          baseGUID = config.baseGUID5,
          weaponDBID = config.weaponDBID11,
          unitDBID = config.platformDBID28,
          unitCount = 8,
          loadoutID = config.loadoutDBID8,
          -- startTime = '2027-06-09 01:05:00',
          missionParams = {
            name = 'SWEAP/AB/W/1',
            type = 'patrol',
            opts = {
              type = 'aaw',
              OneThirdRule = false,
              FlightSize = 4,
              CheckOPAREA = false,
              CheckWWR = false,
              prosecutionZone = config.c.areas["SWEAP/SOUTH/PROSECUTION"],
              patrolZone = config.c.areas["SWEAP/SOUTH/PATROL"]
            }
          },
          emcon = 'Radar=Passive;OECM=Active'
        },
        wildWeasel = {
          baseGUID = config.baseGUID4,
          weaponDBID = config.weaponDBID12,
          unitDBID = config.platformDBID30,
          unitCount = 8,
          loadoutID = config.loadoutDBID9,
          -- startTime = '2027-06-09 01:05:00',
          missionParams = {
            name = 'SEAD/AB/W/1',
            type = 'patrol',
            opts = {
              type = 'sead',
              OneThirdRule = false,
              FlightSize = 4,
              CheckOPAREA = false,
              CheckWWR = false,
              prosecutionZone = config.c.areas["SWEAP/SOUTH/PROSECUTION"],
              patrolZone = config.c.areas["SWEAP/SOUTH/PATROL"]
            }
          },
          emcon = 'Radar=Passive;OECM=Active'
        },
        jammer = {
          baseGUID = config.baseGUID3,
          unitDBID = config.platformDBID35,
          weaponDBID = 0,
          unitCount = 1,
          loadoutID = nil, -- Electronic warfare aircraft
          -- startTime = '2027-06-09 01:05:00', -- 與護航機同時出發
          missionParams = {
            name = 'JAMMING/AB/W/1',
            type = 'support',
            opts = { zone = config.c.areas["SWEAP/SOUTH/PATROL"] }
          },
          emcon = 'Radar=Passive;OECM=Active'
        },
        tanker = nil,
        reconUAV = {
          baseGUID = config.c.recon.bases.BZK005.guid,
          unitDBID = config.platformDBID13,
          unitGUID = nil,
          missionName = 'RECON/1',
          course = { { lat = 'N 25.27.28', lon = 'E 120.46.09' } },
          unitCount = 1,
          takeoffTime = '2027-06-09 01:00:00',
          missionStartTime = '2027-06-09 01:30:00',
          hasLaunched = false
        },
        target = {
          list = {},
          objs = {
            { baseName = 'Pingtung South AB', subTypes = { 'Shelter', 'Tarmac', 'Hangar' } },
            { baseName = 'Pingtung North AB', subTypes = { 'Shelter', 'Tarmac', 'Hangar' } }
          },
          areas = { config.c.areas["OPAREA/SOUTH"] },
          filterNames = { 'findC2' },
          contactAge = 60 * 60,
          minTargetCount = 1
        },
        hasLaunched = false
      },
      {
        timeToReady = 5,
        loadoutStatus = {
          isLoadoutInitiated = false,
          loadoutInitiatedTime = nil,
          expectedReadyTime = nil,
          loadoutStartTime = nil
        },
        striker = {
          baseGUID = config.baseGUID2,
          weaponDBID = config.weaponDBID10,
          unitDBID = config.platformDBID29,
          unitCount = 12,
          loadoutID = config.loadoutDBID7,
          startTime = nil,
          missionParams = { name = 'STRIKE/AB/C', type = 'strike', opts = { type = 'land' } },
          emcon = 'Radar=Passive;OECM=Active'
        },
        escort = {
          baseGUID = config.baseGUID5,
          weaponDBID = config.weaponDBID11,
          unitDBID = config.platformDBID28,
          unitCount = 8,
          loadoutID = config.loadoutDBID8,
          missionParams = {
            name = 'SWEAP/AB/C',
            type = 'patrol',
            opts = {
              type = 'aaw',
              OneThirdRule = false,
              FlightSize = 4,
              CheckOPAREA = false,
              CheckWWR = false,
              prosecutionZone = config.c.areas["SWEAP/CENTER/PROSECUTION"],
              patrolZone = config.c.areas["SWEAP/CENTER/PATROL"]
            }
          },
          emcon = 'Radar=Passive;OECM=Active'
        },
        wildWeasel = {
          baseGUID = config.baseGUID4,
          weaponDBID = config.weaponDBID12,
          unitDBID = config.platformDBID30,
          unitCount = 8,
          loadoutID = config.loadoutDBID9,
          missionParams = {
            name = 'SEAD/AB/C',
            type = 'patrol',
            opts = {
              type = 'sead',
              OneThirdRule = false,
              FlightSize = 4,
              CheckOPAREA = false,
              CheckWWR = false,
              prosecutionZone = config.c.areas["SWEAP/CENTER/PROSECUTION"],
              patrolZone = config.c.areas["SWEAP/CENTER/PATROL"]
            }
          },
          emcon = 'Radar=Passive;OECM=Active'
        },
        jammer = {
          baseGUID = config.baseGUID3,
          unitDBID = config.platformDBID35,
          weaponDBID = 0,
          unitCount = 1,
          loadoutID = nil,
          missionParams = {
            name = 'JAMMING/AB/C',
            type = 'support',
            opts = { zone = config.c.areas["SWEAP/CENTER/PATROL"] }
          },
          emcon = 'Radar=Passive;OECM=Active'
        },
        tanker = nil,
        reconUAV = nil,
        target = {
          list = {},
          objs = {
            { baseName = 'Ching Chuang Kang AB', subTypes = { 'Shelter', 'Ammo Bunker' } },
            { baseName = 'Chiayi AB',            subTypes = { 'Shelter', 'Ammo Bunker' } }
          },
          areas = { config.c.areas["OPAREA/CENTER"] },
          filterNames = { 'findC2' },
          contactAge = 60 * 60,
          minTargetCount = 1
        },
        hasLaunched = false
      },
      {
        timeToReady = 5,
        loadoutStatus = {
          isLoadoutInitiated = false,
          loadoutInitiatedTime = nil,
          expectedReadyTime = nil,
          loadoutStartTime = nil
        },
        striker = {
          baseGUID = config.baseGUID5,
          weaponDBID = config.weaponDBID10,
          unitDBID = config.platformDBID29,
          unitCount = 12,
          loadoutID = config.loadoutDBID7,
          startTime = nil,
          missionParams = { name = 'STRIKE/AB/N/1', type = 'strike', opts = { type = 'land' } },
          emcon = 'Radar=Passive;OECM=Active'
        },
        escort = {
          baseGUID = config.baseGUID5,
          weaponDBID = config.weaponDBID11,
          unitDBID = config.platformDBID28,
          unitCount = 8,
          loadoutID = config.loadoutDBID8,
          missionParams = {
            name = 'SWEAP/AB/N/1',
            type = 'patrol',
            opts = {
              type = 'aaw',
              OneThirdRule = false,
              FlightSize = 4,
              CheckOPAREA = false,
              CheckWWR = false,
              prosecutionZone = config.c.areas["SWEAP/NORTH/PROSECUTION"],
              patrolZone = config.c.areas["SWEAP/NORTH/PATROL"]
            }
          },
          emcon = 'Radar=Passive;OECM=Active'
        },
        wildWeasel = {
          baseGUID = config.baseGUID6,
          weaponDBID = config.weaponDBID12,
          unitDBID = config.platformDBID30,
          unitCount = 8,
          loadoutID = config.loadoutDBID9,
          missionParams = {
            name = 'SEAD/AB/N/1',
            type = 'patrol',
            opts = {
              type = 'sead',
              OneThirdRule = false,
              FlightSize = 4,
              CheckOPAREA = false,
              CheckWWR = false,
              prosecutionZone = config.c.areas["SWEAP/NORTH/PROSECUTION"],
              patrolZone = config.c.areas["SWEAP/NORTH/PATROL"]
            }
          },
          emcon = 'Radar=Passive;OECM=Active'
        },
        jammer = {
          baseGUID = config.baseGUID3,
          unitDBID = config.platformDBID35,
          weaponDBID = 0,
          unitCount = 1,
          loadoutID = nil,
          missionParams = {
            name = 'JAMMING/AB/N/1',
            type = 'support',
            opts = { zone = config.c.areas["SWEAP/NORTH/PATROL"] }
          },
          emcon = 'Radar=Passive;OECM=Active'
        },
        tanker = nil,
        reconUAV = nil,
        target = {
          list = {},
          objs = {
            { baseName = 'Hsinchu AB', subTypes = { 'Shelter', 'Helipad', 'Ammo Bunker' } }
          },
          areas = { config.c.areas["OPAREA/NORTH"] },
          filterNames = { 'findC2' },
          contactAge = 60 * 60,
          minTargetCount = 1
        },
        hasLaunched = false
      }
    }
  },
  ['STRIKE/AB/W/2'] = {
    name = 'STRIKE/AB/W/2',
    isActivated = true,
    isFirstWave = false,
    hasLaunched = false,
    strikeInterval = 30 * 60,
    packages = {
      {
        timeToReady = 5,
        loadoutStatus = {
          isLoadoutInitiated = false,
          loadoutInitiatedTime = nil,
          expectedReadyTime = nil,
          loadoutStartTime = nil
        },
        striker = {
          baseGUID = config.baseGUID7,
          weaponDBID = config.weaponDBID13,
          unitDBID = config.platformDBID31,
          unitCount = 12,
          loadoutID = config.loadoutDBID15,
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
            { baseName = 'Pingtung North AB', subTypes = { 'Shelter', 'Tarmac', 'Hangar' } }
          },
          areas = { config.c.areas["OPAREA/SOUTH"] },
          filterNames = { 'findC2' },
          contactAge = 60 * 60,
          minTargetCount = 1
        },
        hasLaunched = false
      },
      {
        timeToReady = 5,
        loadoutStatus = {
          isLoadoutInitiated = false,
          loadoutInitiatedTime = nil,
          expectedReadyTime = nil,
          loadoutStartTime = nil
        },
        striker = {
          baseGUID = config.baseGUID9,
          weaponDBID = config.weaponDBID13,
          unitDBID = config.platformDBID31,
          unitCount = 12,
          loadoutID = config.loadoutDBID15,
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
            { baseName = 'Hsinchu AB', subTypes = { 'Shelter', 'Helipad', 'Ammo Bunker' } }
          },
          areas = { config.c.areas["OPAREA/NORTH"] },
          filterNames = { 'findC2' },
          contactAge = 60 * 60,
          minTargetCount = 1
        },
        hasLaunched = false
      }
    }
  },
  ['STRIKE/AB/W/3'] = {
    name = 'STRIKE/AB/W/3',
    isActivated = true,
    isFirstWave = false,
    hasLaunched = false,
    strikeInterval = 30 * 60,
    packages = {
      {
        timeToReady = 5,
        loadoutStatus = {
          isLoadoutInitiated = false,
          loadoutInitiatedTime = nil,
          expectedReadyTime = nil,
          loadoutStartTime = nil
        },
        striker = {
          baseGUID = config.baseGUID3,
          weaponDBID = config.weaponDBID14,
          unitDBID = config.platformDBID30,
          unitCount = 12,
          loadoutID = config.loadoutDBID11,
          startTime = '2027-06-09 05:40:00',
          missionParams = { name = 'STRIKE/AB/S/2', type = 'strike', opts = { type = 'land' } },
          emcon = 'Radar=Passive;OECM=Active'
        },
        escort = {
          baseGUID = config.baseGUID5,
          weaponDBID = config.weaponDBID11,
          unitDBID = config.platformDBID28,
          unitCount = 8,
          loadoutID = config.loadoutDBID8,
          missionParams = {
            name = 'SWEAP/AB/S/2',
            type = 'patrol',
            opts = {
              type = 'aaw',
              OneThirdRule = false,
              FlightSize = 4,
              CheckOPAREA = false,
              CheckWWR = false,
              prosecutionZone = config.c.areas["SWEAP/SOUTH/PROSECUTION"],
              patrolZone = config.c.areas["SWEAP/SOUTH/PATROL"]
            }
          },
          emcon = 'Radar=Passive;OECM=Active'
        },
        wildWeasel = {
          baseGUID = config.baseGUID4,
          weaponDBID = config.weaponDBID12,
          unitDBID = config.platformDBID30,
          unitCount = 8,
          loadoutID = config.loadoutDBID9,
          missionParams = {
            name = 'SEAD/AB/S/2',
            type = 'patrol',
            opts = {
              type = 'sead',
              OneThirdRule = false,
              FlightSize = 4,
              CheckOPAREA = false,
              CheckWWR = false,
              prosecutionZone = config.c.areas["SWEAP/SOUTH/PROSECUTION"],
              patrolZone = config.c.areas["SWEAP/SOUTH/PATROL"]
            }
          },
          emcon = 'Radar=Passive;OECM=Active'
        },
        jammer = {
          baseGUID = config.baseGUID3,
          unitDBID = config.platformDBID35,
          weaponDBID = 0,
          unitCount = 1,
          loadoutID = nil,
          missionParams = {
            name = 'JAMMING/AB/S/2',
            type = 'support',
            opts = { zone = config.c.areas["SWEAP/SOUTH/PATROL"] }
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
            { baseName = 'Magong AB',         subTypes = { 'Ammo Bunker' } }
          },
          areas = { config.c.areas["OPAREA/SOUTH"] },
          filterNames = { 'findC2' },
          contactAge = 60 * 60,
          minTargetCount = 1
        },
        hasLaunched = false
      }
    }
  },
  ['STRIKE/AB/E/1'] = {
    name = 'STRIKE/AB/E/1',
    isActivated = true,
    isFirstWave = false,
    hasLaunched = false,
    strikeInterval = 80 * 60,
    packages = {
      {
        timeToReady = 5,
        loadoutStatus = {
          isLoadoutInitiated = false,
          loadoutInitiatedTime = nil,
          expectedReadyTime = nil,
          loadoutStartTime = nil
        },
        striker = {
          baseGUID = 'CSG',
          weaponDBID = config.weaponDBID15,
          unitDBID = config.platformDBID82,
          unitCount = 12,
          loadoutID = config.loadoutDBID23,
          startTime = '2027-06-09 07:00:00',
          missionParams = { name = 'STRIKE/AB/JHI', type = 'strike', opts = { type = 'land' } },
          emcon = 'Radar=Passive;OECM=Active'
        },
        escort = nil,
        -- escort = {
        --   baseGUID = 'CSG',
        --   weaponDBID = config.weaponDBID11,
        --   unitDBID = config.platformDBID82,
        --   unitCount = 8,
        --   loadoutID = config.loadoutDBID22,
        --   missionParams = {
        --     name = 'SWEAP/AB/JHI',
        --     type = 'patrol',
        --     opts = {
        --       type = 'aaw',
        --       OneThirdRule = false,
        --       FlightSize = 4,
        --       CheckOPAREA = false,
        --       CheckWWR = false,
        --       prosecutionZone = config.c.areas["SWEAP/JHI/PROSECUTION"],
        --       patrolZone = config.c.areas["SWEAP/JHI/PATROL"]
        --     }
        --   },
        --   emcon = 'Radar=Passive;OECM=Active'
        -- },
        wildWeasel = {
          baseGUID = 'CSG',
          weaponDBID = config.weaponDBID16,
          unitDBID = config.platformDBID82,
          unitCount = 8,
          loadoutID = config.loadoutDBID22,
          missionParams = {
            name = 'SEAD/AB/JHI',
            type = 'patrol',
            opts = {
              type = 'sead',
              OneThirdRule = false,
              FlightSize = 4,
              CheckOPAREA = false,
              CheckWWR = false,
              prosecutionZone = config.c.areas["SWEAP/JHI/PROSECUTION"],
              patrolZone = config.c.areas["SWEAP/JHI/PATROL"]
            }
          },
          emcon = 'Radar=Passive;OECM=Active'
        },
        jammer = {
          baseGUID = 'CSG',
          unitDBID = config.platformDBID37,
          weaponDBID = 0,
          unitCount = 1,
          loadoutID = config.loadoutDBID26,
          missionParams = {
            name = 'JAMMING/AB/JHI',
            type = 'support',
            opts = { zone = config.c.areas["SWEAP/JHI/PATROL"] }
          },
          emcon = 'Radar=Passive;OECM=Active'
        },
        tanker = nil,
        reconUAV = nil,
        target = {
          list = {},
          objs = {
            { baseName = 'Jhihhang AB', subTypes = { 'Shelter' } }
          },
          areas = { config.c.areas["OPAREA/EAST"] },
          filterNames = nil,
          contactAge = 60 * 60,
          minTargetCount = 1
        },
        hasLaunched = false
      },
      {
        timeToReady = 5,
        loadoutStatus = {
          isLoadoutInitiated = false,
          loadoutInitiatedTime = nil,
          expectedReadyTime = nil,
          loadoutStartTime = nil
        },
        striker = {
          baseGUID = 'CSG',
          weaponDBID = config.weaponDBID15,
          unitDBID = config.platformDBID82,
          unitCount = 12,
          loadoutID = config.loadoutDBID23,
          startTime = nil,
          missionParams = { name = 'STRIKE/AB/E', type = 'strike', opts = { type = 'land' } },
          emcon = 'Radar=Passive;OECM=Active'
        },
        escort = nil,
        -- escort = {
        --   baseGUID = '6Z8LM5-0HMIJ3QGCRQ5F',
        --   weaponDBID = config.weaponDBID11,
        --   unitDBID = config.platformDBID82,
        --   unitCount = 8,
        --   loadoutID = config.loadoutDBID8,
        --   missionParams = {
        --     name = 'SWEAP/AB/E',
        --     type = 'patrol',
        --     opts = {
        --       type = 'aaw',
        --       OneThirdRule = false,
        --       FlightSize = 4,
        --       CheckOPAREA = false,
        --       CheckWWR = false,
        --       prosecutionZone = config.c.areas["SWEAP/E/PROSECUTION"],
        --       patrolZone = config.c.areas["SWEAP/E/PATROL"]
        --     }
        --   },
        --   emcon = 'Radar=Passive;OECM=Active'
        -- },
        wildWeasel = {
          baseGUID = 'CSG',
          weaponDBID = config.weaponDBID16,
          unitDBID = config.platformDBID82,
          unitCount = 8,
          loadoutID = config.loadoutDBID22,
          missionParams = {
            name = 'SEAD/AB/E',
            type = 'patrol',
            opts = {
              type = 'sead',
              OneThirdRule = false,
              FlightSize = 4,
              CheckOPAREA = false,
              CheckWWR = false,
              prosecutionZone = config.c.areas["SWEAP/E/PROSECUTION"],
              patrolZone = config.c.areas["SWEAP/E/PATROL"]
            }
          },
          emcon = 'Radar=Passive;OECM=Active'
        },
        jammer = {
          baseGUID = 'CSG',
          unitDBID = config.platformDBID37,
          weaponDBID = 0,
          unitCount = 1,
          loadoutID = config.loadoutDBID26,
          missionParams = {
            name = 'JAMMING/AB/E',
            type = 'support',
            opts = { zone = config.c.areas["SWEAP/E/PATROL"] }
          },
          emcon = 'Radar=Passive;OECM=Active'
        },
        tanker = nil,
        reconUAV = nil,
        target = {
          list = {},
          objs = {
            { baseName = 'Jiashan AB', subTypes = { 'Shelter' } }
          },
          areas = { config.c.areas["OPAREA/EAST"] },
          filterNames = nil,
          contactAge = 60 * 60,
          minTargetCount = 1
        },
        hasLaunched = false
      }
    }
  },
  ['ASUW/N/1'] = {
    name = 'ASUW/N/1',
    isActivated = true,
    isFirstWave = false,
    hasLaunched = false,
    strikeInterval = 30 * 60,
    packages = {
      {
        timeToReady = 5,
        loadoutStatus = {
          isLoadoutInitiated = false,
          loadoutInitiatedTime = nil,
          expectedReadyTime = nil,
          loadoutStartTime = nil
        },
        striker = {
          baseGUID = config.baseGUID8,
          weaponDBID = config.weaponDBID17,
          unitDBID = config.platformDBID29,
          unitCount = 8,
          loadoutID = config.loadoutDBID16,
          startTime = '2027-06-09 02:40:00',
          missionParams = { name = 'ASUW/N', type = 'strike', opts = { type = 'sea' } },
          emcon = 'Radar=Passive;OECM=Active'
        },
        escort = nil,
        wildWeasel = {
          baseGUID = config.baseGUID8,
          weaponDBID = config.weaponDBID12,
          unitDBID = config.platformDBID30,
          unitCount = 8,
          loadoutID = config.loadoutDBID9,
          missionParams = {
            name = 'SEAD/ASUW/N',
            type = 'patrol',
            opts = {
              type = 'sead',
              OneThirdRule = false,
              FlightSize = 4,
              CheckOPAREA = false,
              CheckWWR = false,
              zone = config.c.areas["OPAREA/D"]
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
          areas = { config.c.areas["OPAREA/D"] },
          filterNames = { 'findNavalTargets' },
          contactAge = 60 * 60,
          minTargetCount = 1
        },
        hasLaunched = false
      }
    }
  },
  ['AIR INTERCEPT/E/1'] = {
    name = 'AIR INTERCEPT/E/1',
    isActivated = true,
    isFirstWave = false,
    hasLaunched = false,
    strikeInterval = 30 * 60,
    packages = {
      {
        timeToReady = 5,
        loadoutStatus = {
          isLoadoutInitiated = false,
          loadoutInitiatedTime = nil,
          expectedReadyTime = nil,
          loadoutStartTime = nil
        },
        striker = {
          baseGUID = config.baseGUID10,
          weaponDBID = config.weaponDBID11,
          unitDBID = config.platformDBID28,
          unitCount = 6,
          loadoutID = config.loadoutDBID8,
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
          areas = { config.c.areas["OPAREA/PACIFIC"] },
          filterNames = { 'findAirborne' },
          contactAge = 60 * 60,
          minTargetCount = 1
        },
        hasLaunched = false
      }
    }
  },
  ['CAS/N/1'] = {
    name = 'CAS/N/1',
    isActivated = false,
    isFirstWave = false,
    hasLaunched = false,
    strikeInterval = 30 * 60,
    packages = {
      {
        timeToReady = 5,
        loadoutStatus = {
          isLoadoutInitiated = false,
          loadoutInitiatedTime = nil,
          expectedReadyTime = nil,
          loadoutStartTime = nil
        },
        striker = {
          baseGUID = config.baseGUID8,
          weaponDBID = config.weaponDBID15,
          unitDBID = config.platformDBID57,
          unitCount = 8,
          loadoutID = config.loadoutDBID19,
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
          areas = { config.c.areas["LANDING/TAOYUAN"] },
          filterNames = { 'findInfantry' },
          contactAge = 60 * 60,
          minTargetCount = 1
        },
        hasLaunched = false
      }
    }
  }
}



-- Amphibious ops
saveData.c.PHIBOP.startTime = config.c.triggers['(China) (Amphibious ops) start time'].startTime
saveData.c.PHIBOP.isTesting = true
saveData.c.PHIBOP.isShipsStartedMoving = true
saveData.c.PHIBOP.isWaitingForShipArrival = false
saveData.c.PHIBOP.amphibiousAssaultStartTime = nil
saveData.c.PHIBOP.isWaitingForAmphibiousAssault = false
saveData.c.PHIBOP.isWaitingForSecondWaveUnloading = false
saveData.c.PHIBOP.airlandingMissionStartTime = nil
saveData.c.PHIBOP.calculations = {
  ['Taoyuan'] = {
    name = 'Taoyuan',
    result = {
      type075 = { locations = {}, locationIndex = 1, dbid = config.platformDBID6, },
      type071 = { locations = {}, locationIndex = 1, dbid = config.platformDBID7, },
      type076 = { locations = {}, locationIndex = 1, dbid = config.platformDBID54, },
      type072iii = { locations = {}, locationIndex = 1, dbid = config.platformDBID8, },
      type072a = { locations = {}, locationIndex = 1, dbid = config.platformDBID9, },
      type073a = { locations = {}, locationIndex = 1, dbid = config.platformDBID10, },
      type071InLSTArea = { locations = {}, locationIndex = 1, dbid = config.platformDBID7, },
      ferry = { locations = {}, locationIndex = 1, dbid = config.platformDBID56, },
      roro = { locations = {}, locationIndex = 1, dbid = config.platformDBID56, },
      barge = { locations = {}, locationIndex = 1, dbid = config.platformDBID72, },
    }
  },
  ['Penghu'] = {
    name = 'Penghu',
    result = {
      type075 = { locations = {}, locationIndex = 1, dbid = config.platformDBID6, },
      type071 = { locations = {}, locationIndex = 1, dbid = config.platformDBID7, },
      type076 = { locations = {}, locationIndex = 1, dbid = config.platformDBID54, },
      type072iii = { locations = {}, locationIndex = 1, dbid = config.platformDBID8, },
      type072a = { locations = {}, locationIndex = 1, dbid = config.platformDBID9, },
      type073a = { locations = {}, locationIndex = 1, dbid = config.platformDBID10, },
      type071InLSTArea = { locations = {}, locationIndex = 1, dbid = config.platformDBID7, },
      ferry = { locations = {}, locationIndex = 1, dbid = config.platformDBID56, },
      roro = { locations = {}, locationIndex = 1, dbid = config.platformDBID56, },
      barge = { locations = {}, locationIndex = 1, dbid = config.platformDBID72, },
    }
  },
  ['Sishu'] = {
    name = 'Sishu',
    result = {
      type075 = { locations = {}, locationIndex = 1, dbid = config.platformDBID6, },
      type071 = { locations = {}, locationIndex = 1, dbid = config.platformDBID7, },
      type076 = { locations = {}, locationIndex = 1, dbid = config.platformDBID54, },
      type072iii = { locations = {}, locationIndex = 1, dbid = config.platformDBID8, },
      type072a = { locations = {}, locationIndex = 1, dbid = config.platformDBID9, },
      type073a = { locations = {}, locationIndex = 1, dbid = config.platformDBID10, },
      type071InLSTArea = { locations = {}, locationIndex = 1, dbid = config.platformDBID7, },
      ferry = { locations = {}, locationIndex = 1, dbid = config.platformDBID56, },
      roro = { locations = {}, locationIndex = 1, dbid = config.platformDBID56, },
      barge = { locations = {}, locationIndex = 1, dbid = config.platformDBID72, },
    }
  },
}
saveData.c.PHIBOP.barges = {
  -- [''] = {
  --     guid = '',
  --     bridgeGUID = '',
  --     roros = {},
  -- },
}

-- Land strike from DDG
saveData.c.surface.lacm.isActivated = true
saveData.c.surface.lacm.startTime = config.c.triggers['(China) (Surface/LACM) start time'].startTime


-- SLCM
saveData.c.subSurface.slcm.isActivated = true
saveData.c.subSurface.slcm.startTime = config.c.triggers['(China) (Sub-surface/SLCM) start time'].startTime


-- Runway repairment
saveData.c.repairRunway.isActivated = false
saveData.c.repairRunway.runways = {
  -- { guid = '', startTime = nil }
}

-- MLRS
saveData.t.ground.mlrs.isActivated = true
saveData.t.ground.mlrs.ammunitions = {
  ['IC8B0X-0HN9B47GHVJ7G'] = {
    guid = 'IC8B0X-0HN9B47GHVJ7G',
    wpnCurrent = config.t.ground.mlrs.wpnDefault,
    wpnDefault = config.t.ground.mlrs.wpnDefault,
  }
}
saveData.t.ground.mlrs.ammunitionSections = {
  ['IC8B0X-0HN7RT1I581BB'] = {
    name = 'Ammo Sec, Rocket Arty Coy, 21st Arty Command',
    guid = 'IC8B0X-0HN7RT1I581BB',
    wpnCurrent = config.t.ground.mlrs.wpnDefault,
    wpnDefault = config.t.ground.mlrs.wpnDefault,
    unitCount = 2,
    position = config.t.ground.mlrs.positions.pingzhen,
    reloadStartTime = nil,
    state = config.batteryState.STATIC,
    ammunition = 'IC8B0X-0HN9B47GHVJ7G',
  }
}
saveData.t.ground.mlrs.batteries = {
  ['IC8B0X-0HN7RU9I3KV9T'] = {
    name = 'Rocket Arty Coy, 21st Arty Command',
    msg = 'Radio source, Bty',
    guid = 'IC8B0X-0HN7RU9I3KV9T',
    reloadStartTime = nil,
    state = config.batteryState.HIDE,
    position = config.t.ground.mlrs.positions.pingzhen,
    weaponDBID = config.weaponDBID18,
    ammoThreshold = config.t.ground.mlrs.ammoThreshold,
    ammunitionSection = 'IC8B0X-0HN7RT1I581BB'
  },
}


-- SRBM
saveData.t.ground.srbm.isActivated = true
saveData.t.ground.srbm.ammunitions = {
  ['IC8B0X-0HN9B47GHVJG6'] = {
    guid = 'IC8B0X-0HN9B47GHVJG6',
    wpnCurrent = config.t.ground.srbm.wpnDefault,
    wpnDefault = config.t.ground.srbm.wpnDefault,
  }
}
saveData.t.ground.srbm.ammunitionSections = {
  ['IC8B0X-0HN7R5QOIVSFS'] = {
    name = 'Ammo Sec, Rocket Arty Coy, 58th Arty Command',
    guid = 'IC8B0X-0HN7R5QOIVSFS',
    wpnCurrent = config.t.ground.srbm.wpnDefault,
    wpnDefault = config.t.ground.srbm.wpnDefault,
    unitCount = 2,
    position = config.t.ground.srbm.positions.dadu,
    reloadStartTime = nil,
    state = config.batteryState.STATIC,
    ammunition = 'IC8B0X-0HN9B47GHVJG6',
  }
}
saveData.t.ground.srbm.batteries = {
  ['IC8B0X-0HN7SOIUF4D47'] = {
    name = 'Rocket Arty Coy, 58th Arty Command',
    msg = 'Radio source, Bty',
    guid = 'IC8B0X-0HN7SOIUF4D47',
    reloadStartTime = nil,
    state = config.batteryState.HIDE,
    position = config.t.ground.srbm.positions.dadu,
    weaponDBID = config.weaponDBID19,
    ammoThreshold = config.t.ground.srbm.ammoThreshold,
    ammunitionSection = 'IC8B0X-0HN7R5QOIVSFS'
  },
}



-- GLCM
saveData.t.ground.glcm.isActivated = true
saveData.t.ground.glcm.ammunitions = {
  ['IC8B0X-0HN9B47GHVKAG'] = {
    guid = 'IC8B0X-0HN9B47GHVKAG',
    wpnCurrent = config.t.ground.glcm.wpnDefault * 2,
    wpnDefault = config.t.ground.glcm.wpnDefault * 2,
  },
  ['IC8B0X-0HN9B47GHVL3V'] = {
    guid = 'IC8B0X-0HN9B47GHVL3V',
    wpnCurrent = config.t.ground.glcm.wpnDefault * 2,
    wpnDefault = config.t.ground.glcm.wpnDefault * 2,
  }
}
saveData.t.ground.glcm.ammunitionSections = {
  ['IC8B0X-0HN7R5QOIVTHT'] = {
    name = 'Ammo Sec, 641st Bn, 791st AFAD & Arty Bde',
    guid = 'IC8B0X-0HN7R5QOIVTHT',
    wpnCurrent = config.t.ground.glcm.wpnDefault,
    wpnDefault = config.t.ground.glcm.wpnDefault,
    unitCount = 2,
    position = config.t.ground.glcm.positions.quanxi,
    reloadStartTime = nil,
    state = config.batteryState.STATIC,
    ammunition = 'IC8B0X-0HN9B47GHVKAG',
  },
  ['IC8B0X-0HN7R5QOIVUDC'] = {
    name = 'Ammo Sec, 642nd Bn, 791st AFAD & Arty Bde',
    guid = 'IC8B0X-0HN7R5QOIVUDC',
    wpnCurrent = config.t.ground.glcm.wpnDefault,
    wpnDefault = config.t.ground.glcm.wpnDefault,
    unitCount = 2,
    position = config.t.ground.glcm.positions.neipu,
    reloadStartTime = nil,
    state = config.batteryState.STATIC,
    ammunition = 'IC8B0X-0HN9B47GHVL3V',
  },
}
saveData.t.ground.glcm.batteries = {
  ['X58F5H-0HN1ESDRTUULO'] = {
    guid = 'X58F5H-0HN1ESDRTUULO',
    name = '641st Bn, 791st AFAD & Arty Bde',
    msg = 'Radio source, Bty',
    reloadStartTime = nil,
    state = config.batteryState.HIDE,
    position = config.t.ground.glcm.positions.quanxi,
    weaponDBID = config.weaponDBID20,
    ammoThreshold = config.t.ground.glcm.ammoThreshold,
    ammunitionSection = 'IC8B0X-0HN7R5QOIVTHT'
  },
  ['X58F5H-0HN1ESDRTLGU7'] = {
    guid = 'X58F5H-0HN1ESDRTLGU7',
    name = '642nd Bn, 791st AFAD & Arty Bde',
    msg = 'Radio source, Bty',
    reloadStartTime = nil,
    state = config.batteryState.HIDE,
    position = config.t.ground.glcm.positions.neipu,
    weaponDBID = config.weaponDBID20,
    ammoThreshold = config.t.ground.glcm.ammoThreshold,
    ammunitionSection = 'IC8B0X-0HN7R5QOIVUDC'
  }
}




-- ASM
saveData.t.ground.ascm.isActivated = true
saveData.t.ground.ascm.ammunitions = {
  ['IC8B0X-0HN9B47GHVLV9'] = {
    guid = 'IC8B0X-0HN9B47GHVLV9',
    wpnCurrent = config.t.ground.ascm.wpnDefault * 2,
    wpnDefault = config.t.ground.ascm.wpnDefault * 2,
  },
  ['IC8B0X-0HN9JFGVR06D8'] = {
    guid = 'IC8B0X-0HN9JFGVR06D8',
    wpnCurrent = config.t.ground.ascm.wpnDefault * 2,
    wpnDefault = config.t.ground.ascm.wpnDefault * 2,
  },
}
saveData.t.ground.ascm.ammunitionSections = {
  ['IC8B0X-0HN87KFOFSGUB'] = {
    name = 'Hai Feng Shore-based ASM SUPP Sqn',
    guid = 'IC8B0X-0HN87KFOFSGUB',
    wpnCurrent = config.t.ground.ascm.wpnDefault,
    wpnDefault = config.t.ground.ascm.wpnDefault,
    unitCount = 2,
    position = config.t.ground.ascm.positions.pingzhen,
    reloadStartTime = nil,
    state = config.batteryState.STATIC,
    ammunition = 'IC8B0X-0HN9B47GHVLV9',
  },
  ['IC8B0X-0HN9JFGVR07U5'] = {
    name = 'Hai Feng Shore-based ASM SUPP Sqn',
    guid = 'IC8B0X-0HN9JFGVR07U5',
    wpnCurrent = config.t.ground.ascm.wpnDefault,
    wpnDefault = config.t.ground.ascm.wpnDefault,
    unitCount = 2,
    position = config.t.ground.ascm.positions.dong,
    reloadStartTime = nil,
    state = config.batteryState.STATIC,
    ammunition = 'IC8B0X-0HN9JFGVR06D8',
  },
}
saveData.t.ground.ascm.batteries = {
  ['IC8B0X-0HN87MOIE9C4U'] = {
    name = '2nd Hai Feng Shore-based ASM MOB Sqn',
    msg = 'Radio source, Bty',
    guid = 'IC8B0X-0HN87MOIE9C4U',
    reloadStartTime = nil,
    state = config.batteryState.HIDE,
    position = config.t.ground.ascm.positions.luzhu,
    weaponDBID = config.weaponDBID21,
    ammoThreshold = config.t.ground.ascm.ammoThreshold,
    ammunitionSection = 'IC8B0X-0HN87KFOFSGUB'
  },
  ['X58F5H-0HMVEU1FUVOLC'] = {
    name = '4th Hai Feng Shore-based ASM MOB Sqn',
    msg = 'Radio source, Bty',
    guid = 'X58F5H-0HMVEU1FUVOLC',
    reloadStartTime = nil,
    state = config.batteryState.HIDE,
    position = config.t.ground.ascm.positions.luzhu,
    weaponDBID = config.weaponDBID21,
    ammoThreshold = config.t.ground.ascm.ammoThreshold,
    ammunitionSection = 'IC8B0X-0HN87KFOFSGUB'
  },
  ['X58F5H-0HMVEU1FUVO8I'] = {
    name = '1st Hai Feng Shore-based ASM MOB Sqn',
    msg = 'Radio source, Bty',
    guid = 'X58F5H-0HMVEU1FUVO8I',
    reloadStartTime = nil,
    state = config.batteryState.HIDE,
    position = config.t.ground.ascm.positions.dong,
    weaponDBID = config.weaponDBID21,
    ammoThreshold = config.t.ground.ascm.ammoThreshold,
    ammunitionSection = 'IC8B0X-0HN9JFGVR07U5'
  },
  ['X58F5H-0HMVEU1FUVO6J'] = {
    name = '3rd Hai Feng Shore-based ASM MOB Sqn',
    msg = 'Radio source, Bty',
    guid = 'X58F5H-0HMVEU1FUVO6J',
    reloadStartTime = nil,
    state = config.batteryState.HIDE,
    position = config.t.ground.ascm.positions.dong,
    weaponDBID = config.weaponDBID21,
    ammoThreshold = config.t.ground.ascm.ammoThreshold,
    ammunitionSection = 'IC8B0X-0HN9JFGVR07U5'
  },
  ['IC8B0X-0HN8CEO4EUE8B'] = {
    name = '5th Hai Feng Shore-based ASM MOB Sqn',
    msg = 'Radio source, Bty',
    guid = 'IC8B0X-0HN8CEO4EUE8B',
    reloadStartTime = nil,
    state = config.batteryState.HIDE,
    position = config.t.ground.ascm.positions.luzhu,
    weaponDBID = config.weaponDBID21,
    ammoThreshold = config.t.ground.ascm.ammoThreshold,
    ammunitionSection = 'IC8B0X-0HN87KFOFSGUB'
  },
}
saveData.t.ground.ascm.test = {
  isAntishipMissionActivated = false,
  nai1 = config.t.areas.groundAscmTestNai1,
  nai2 = config.t.areas.groundAscmTestNai2,
  shipNumInNai1 = 4,
  helicopterNumInNai2 = 4
}

-- Runway repairment
saveData.t.repairRunway.isActivated = false
saveData.t.repairRunway.runways = {
  -- { guid = '', startTime = nil }
}


-- IADS
saveData.t.IADS.isActivated = true
saveData.t.IADS.ROCC = {
  ['IC8B0X-0HNC3OB4KJKIF'] = {
    name = 'ROCC/North',
    msg = 'Radio source, C2',
    guid = 'IC8B0X-0HNC3OB4KJKIF',
    areas = {
      config.t.areas["OPAREA/3RD"],
    },
    SAM = {},
    radar = {}
  },
  ['IC8B0X-0HNC3OB4KJKTC'] = {
    name = 'ROCC/East',
    msg = 'Radio source, C2',
    guid = 'IC8B0X-0HNC3OB4KJKTC',
    areas = { config.t.areas["OPAREA/2ND"], config.t.areas["OPAREA/5TH"], },
    SAM = {},
    radar = {}
  },
  ['IC8B0X-0HNC3OB4KJL2M'] = {
    name = 'ROCC/South',
    msg = 'Radio source, C2',
    guid = 'IC8B0X-0HNC3OB4KJL2M',
    areas = {
      config.t.areas["OPAREA/4TH"],
    },
    SAM = {},
    radar = {}
  },
}
saveData.t.IADS.TAAOC = {
  ['IC8B0X-0HN41D1QKTVU7'] = {
    name = 'TAAOC/3rd OPAREA',
    msg = 'Radio source, C2',
    guid = 'IC8B0X-0HN41D1QKTVU7',
    areas = {
      config.t.areas["OPAREA/3RD"],
    },
    SAM = {},
  },
  ['IC8B0X-0HN41D1QKU1ED'] = {
    name = 'TAAOC/5th OPAREA',
    msg = 'Radio source, C2',
    guid = 'IC8B0X-0HN41D1QKU1ED',
    areas = {
      config.t.areas["OPAREA/5TH"],
    },
    SAM = {},
  },
  ['IC8B0X-0HN41D1QKU0JP'] = {
    name = 'TAAOC/4th OPAREA',
    msg = 'Radio source, C2',
    guid = 'IC8B0X-0HN41D1QKU0JP',
    areas = {
      config.t.areas["OPAREA/4TH"],
    },
    SAM = {},
  },
  ['IC8B0X-0HNC27TV5Q0AS'] = {
    name = 'TAAOC/2nd OPAREA',
    msg = 'Radio source, C2',
    guid = 'IC8B0X-0HNC27TV5Q0AS',
    areas = {
      config.t.areas["OPAREA/2ND"],
    },
    SAM = {},
  },
}


-- Aircraft
saveData.t.air.landBased.AEW = {
  -- {guid=''}
}
saveData.t.air.landBased.AC = {
  -- {guid=''}
}


-- SIGINT
saveData.u.SIGINT.isActivated = true
saveData.u.SIGINT.RA = {}
saveData.u.SIGINT.transmissions = {
  -- [''] = {
  --     name = '',
  --     latitude = 0,
  --     longitude = 0,
  --     contacts = { { guid = '' } }
  -- },
}

-- ScenEdit_SetLoadout({unitname='5th Tactical Mixed Wing #1', LoadoutID=22790, TimeToReady_Minutes=90})

-- Dynamic Fire Support Plan
saveData.c.ground.dynamicFSP.enabled = true
saveData.c.ground.dynamicFSP.reconSchedule = {
  {
    -- time = "2027-06-09 02:14:00",
    time = "2027-06-09 01:00:00",
    type = "satellite", -- Large-scale reconnaissance (satellite)
    delay = 0,          -- Trigger assessment after 5 minutes
    executed = false,   -- Execution status flag
    fsemTemplate = {
      name = "INFRASTRUCTURE/1",
      strikeInterval = 0, -- 10-minute interval,
      isFirstWave = true,
      FSTs = {
        {
          name = 'RADAR',
          wpnSystem = 'SRBM',
          batteries = {
            {
              name = '614th Bde',
              guid = 'X58F5H-0HN1LQGRV8HNQ',
              weaponDBID = saveData.c.ground.srbm.batteries['X58F5H-0HN1LQGRV8HNQ'].weaponDBID
            },
            {
              name = '613rd Bde',
              guid = 'X58F5H-0HN1G2DEBC7O8',
              weaponDBID = saveData.c.ground.srbm.batteries['X58F5H-0HN1G2DEBC7O8'].weaponDBID
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
            contactAge = config.c.ground.srbm.contactAge,
            minTargetCount = 4,
            ammoPerTarget = 3
          },
        },
        {
          name = 'RUNWAY',
          wpnSystem = 'SRBM',
          batteries = {
            {
              name = '636th Bde',
              guid = 'IC8B0X-0HN822OHANPB3',
              weaponDBID = saveData.c.ground.srbm.batteries['IC8B0X-0HN822OHANPB3'].weaponDBID
            },
            {
              name = '617th Bde',
              guid = 'IC8B0X-0HN822OHANRHI',
              weaponDBID = saveData.c.ground.srbm.batteries['IC8B0X-0HN822OHANRHI'].weaponDBID
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
            contactAge = config.c.ground.srbm.contactAge,
            minTargetCount = 4,
            ammoPerTarget = 4
          },
        },
        {
          name = 'PORT',
          wpnSystem = 'SRBM',
          batteries = {
            {
              name = '615th Bde',
              guid = 'X58F5H-0HN1G2IFLNKG9',
              weaponDBID = saveData.c.ground.srbm.batteries['X58F5H-0HN1G2IFLNKG9'].weaponDBID
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
            contactAge = config.c.ground.srbm.contactAge,
            minTargetCount = 4,
            ammoPerTarget = 2
          },
        },
        {
          name = 'SHELTER',
          wpnSystem = 'SRBM',
          batteries = {
            {
              name = '616th Bde',
              guid = 'X58F5H-0HN1G2IFLF6QE',
              weaponDBID = saveData.c.ground.srbm.batteries['X58F5H-0HN1G2IFLF6QE'].weaponDBID
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
            contactAge = config.c.ground.srbm.contactAge,
            minTargetCount = 4,
            ammoPerTarget = 2
          },
        },
      }
    }
  },
  {
    -- time = "2027-06-09 03:00:00",
    time = "2027-06-09 02:14:00",
    type = "satellite",
    delay = 0,
    executed = false,
    fsemTemplate = {
      name = "INFRASTRUCTURE/2",
      strikeInterval = 0,
      isFirstWave = false,
      FSTs = {
        {
          name = 'RADAR',
          wpnSystem = 'SRBM',
          batteries = {
            {
              name = '614th Bde',
              guid = 'X58F5H-0HN1LQGRV8HNQ',
              weaponDBID = saveData.c.ground.srbm.batteries['X58F5H-0HN1LQGRV8HNQ'].weaponDBID
            },
            {
              name = '613rd Bde',
              guid = 'X58F5H-0HN1G2DEBC7O8',
              weaponDBID = saveData.c.ground.srbm.batteries['X58F5H-0HN1G2DEBC7O8'].weaponDBID
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
            contactAge = config.c.ground.srbm.contactAge,
            minTargetCount = 1,
            ammoPerTarget = 3
          },
        },
        {
          name = 'RUNWAY',
          wpnSystem = 'SRBM',
          batteries = {
            {
              name = '636th Bde',
              guid = 'IC8B0X-0HN822OHANPB3',
              weaponDBID = saveData.c.ground.srbm.batteries['IC8B0X-0HN822OHANPB3'].weaponDBID
            },
            {
              name = '617th Bde',
              guid = 'IC8B0X-0HN822OHANRHI',
              weaponDBID = saveData.c.ground.srbm.batteries['IC8B0X-0HN822OHANRHI'].weaponDBID
            }
          },
          target = {
            list = {},
            evaluatedlist = {},
            objs = {
              { baseName = 'Hualien AB',              subTypes = { 'Runway %(%d+m%)', 'Taxiway' } },
              { baseName = 'Taitung/Jhihhang AB',     subTypes = { 'Runway %(%d+m%)', 'Taxiway' } },
              { baseName = 'Ching Chuang Kang AB',    subTypes = { 'Runway %(%d+m%)', 'Taxiway' } },
              { baseName = 'Chiayi AB',               subTypes = { 'Runway %(%d+m%)', 'Taxiway' } },
              { baseName = 'Tainan AB',               subTypes = { 'Runway %(%d+m%)', 'Taxiway' } },
              { baseName = 'Pingtung South AB',       subTypes = { 'Runway %(%d+m%)', 'Taxiway' } },
              { baseName = 'Pingtung North AB',       subTypes = { 'Runway %(%d+m%)', 'Taxiway' } },
              { baseName = 'Magong AB',               subTypes = { 'Runway %(%d+m%)', 'Taxiway' } },
              { baseName = 'Hsinchu AB',              subTypes = { 'Runway %(%d+m%)', 'Taxiway' } },
              { baseName = 'Taitung/Jhihhang AB',     subTypes = { 'Runway %(%d+m%)', 'Taxiway' } },
              { baseName = 'Guiren AAB',              subTypes = { 'Runway %(%d+m%)', 'Taxiway' } },
              { baseName = 'Longtan AAB',             subTypes = { 'Runway %(%d+m%)', 'Taxiway' } },
              { baseName = 'Gangshan AB',             subTypes = { 'Runway %(%d+m%)', 'Taxiway' } },
              { baseName = 'Taipei Songshan Airport', subTypes = { 'Runway %(%d+m%)', 'Taxiway' } },
            },
            areas = {},
            filterNames = nil,
            contactAge = config.c.ground.srbm.contactAge,
            minTargetCount = 1,
            ammoPerTarget = 4
          },
        },
        {
          name = 'PORT',
          wpnSystem = 'SRBM',
          batteries = {
            {
              name = '615th Bde',
              guid = 'X58F5H-0HN1G2IFLNKG9',
              weaponDBID = saveData.c.ground.srbm.batteries['X58F5H-0HN1G2IFLNKG9'].weaponDBID
            }
          },
          target = {
            list = {},
            evaluatedlist = {},
            objs = {
              { baseName = 'Port of Keelung',          subTypes = { 'Pier' } },
              { baseName = 'Suao Port',                subTypes = { 'Pier' } },
              { baseName = 'Kaohsiung Port',           subTypes = { 'Pier' } },
              { baseName = 'Magong Port',              subTypes = { 'Pier' } },
              { baseName = 'HuangGang Fishing Harbor', subTypes = { 'Terminal' } },
              { baseName = 'Donggang Wharf',           subTypes = { 'Terminal' } },
              { baseName = nil,                        subTypes = { 'ASM' } },
            },
            areas = {},
            filterNames = nil,
            contactAge = config.c.ground.srbm.contactAge,
            minTargetCount = 1,
            ammoPerTarget = 2
          },
        },
        {
          name = 'SHELTER',
          wpnSystem = 'SRBM',
          batteries = {
            {
              name = '616th Bde',
              guid = 'X58F5H-0HN1G2IFLF6QE',
              weaponDBID = saveData.c.ground.srbm.batteries['X58F5H-0HN1G2IFLF6QE'].weaponDBID
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
              { baseName = 'Pingtung North AB',    subTypes = { 'Shelter', 'Tarmac', 'Hangar' } },
              { baseName = 'Hsinchu AB',           subTypes = { 'Shelter', 'Tarmac', 'Hangar' } },
              { baseName = 'Gangshan AB',          subTypes = { 'Shelter', 'Tarmac', 'Hangar' } },
              { baseName = 'Tainan AB',            subTypes = { 'Shelter', 'Tarmac', 'Hangar' } },
            },
            areas = {},
            filterNames = nil,
            contactAge = config.c.ground.srbm.contactAge,
            minTargetCount = 1,
            ammoPerTarget = 2
          },
        },
      }
    }
  },
  {
    -- time = "2027-06-09 03:00:00",
    time = "2027-06-09 02:14:00",
    type = "satellite",
    delay = 0,
    executed = false,
    fsemTemplate = {
      name = "ANTISHIP/1",
      strikeInterval = 0,
      isFirstWave = false,
      FSTs = {
        {
          name = "ANTISHIP",
          wpnSystem = "MRBM",
          batteries = {
            {
              name = '624th Bde',
              guid = 'IC8B0X-0HNCOR6HG2JE1',
              weaponDBID = saveData.c.ground.mrbm.batteries['IC8B0X-0HNCOR6HG2JE1'].weaponDBID
            }
          },
          target = {
            list = {},
            evaluatedlist = {},
            objs = {},
            areas = { config.c.areas["OPAREA/PACIFIC"] },
            filterNames = { "findNavalTargets" },
            contactAge = config.c.ground.mrbm.contactAge,
            minTargetCount = 1,
            ammoPerTarget = 6
          },
        }
      }
    }
  },
  {
    -- time = "2027-06-09 03:00:00",
    time = "2027-06-09 02:14:00",
    type = "satellite",
    delay = 0,
    executed = false,
    fsemTemplate = {
      name = "C2/1",
      strikeInterval = 0,
      isFirstWave = false,
      FSTs = {
        {
          name = 'PINGTAN',
          wpnSystem = 'MLRS',
          batteries = {
            {
              name = '1st Bn, 1st Rockets Arty Bde',
              guid = 'IC8B0X-0HND05GGU36EN',
              weaponDBID = saveData.c.ground.mlrs.batteries['IC8B0X-0HND05GGU36EN'].weaponDBID
            }
          },
          target = {
            list = {},
            evaluatedlist = {},
            objs = {},
            areas = { config.c.areas["OPAREA/NORTH"] },
            filterNames = { 'analyzeEmissions', 'findRadioDirection' },
            contactAge = config.c.ground.mlrs.contactAge,
            minTargetCount = 1,
            ammoPerTarget = 8
          },
        },
        {
          name = 'CHINCHEW',
          wpnSystem = 'MLRS',
          batteries = {
            {
              name = '6th Bn, 73rd Arty Bde',
              guid = 'IC8B0X-0HNBRRE2PRQAL',
              weaponDBID = saveData.c.ground.mlrs.batteries['IC8B0X-0HNBRRE2PRQAL'].weaponDBID
            }
          },
          target = {
            list = {},
            evaluatedlist = {},
            objs = {},
            areas = { config.c.areas["OPAREA/CENTER"] },
            filterNames = { 'analyzeEmissions', 'findRadioDirection' },
            contactAge = config.c.ground.mlrs.contactAge,
            minTargetCount = 1,
            ammoPerTarget = 8
          },
        },
      }
    }
  },
  {
    time = "2027-06-09 05:44:00",
    type = "satellite",
    delay = 180,
    executed = false,
    fsemTemplate = {
      name = "HELIPAD/1",
      strikeInterval = 0,
      isFirstWave = true,
      FSTs = {
        {
          name = 'HELIPAD',
          wpnSystem = 'GLCM',
          batteries = {
            {
              name = '635th Bde',
              guid = '6Z8LM5-0HMN97ERAUODK',
              weaponDBID = saveData.c.ground.glcm.batteries['6Z8LM5-0HMN97ERAUODK'].weaponDBID
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
            contactAge = config.c.ground.glcm.contactAge,
            minTargetCount = 1,
            ammoPerTarget = 2
          },
        },
        {
          name = 'EMERGENCY HIGHWAY STRIP',
          wpnSystem = 'GLCM',
          batteries = {
            {
              name = '635th Bde',
              guid = '6Z8LM5-0HMN97ERAUODK',
              weaponDBID = saveData.c.ground.glcm.batteries['6Z8LM5-0HMN97ERAUODK'].weaponDBID
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
            contactAge = config.c.ground.glcm.contactAge,
            minTargetCount = 1,
            ammoPerTarget = 4
          },
        },
      }
    }
  },
  {
    time = "2027-06-09 08:04:00",
    type = "satellite",
    delay = 300,
    executed = false,
    fsemTemplate = {
      name = "DYNAMIC/SATELLITE/BDA/2",
      strikeInterval = 0, -- 15-minute interval,
      isFirstWave = false,
      FSTs = {}
    }
  },
  {
    time = "2027-06-09 11:25:00",
    type = "satellite",
    delay = 300,
    executed = false,
    fsemTemplate = {
      name = "DYNAMIC/SATELLITE/BDA/2",
      strikeInterval = 0, -- 15-minute interval,
      isFirstWave = false,
      FSTs = {}
    }
  }
}

return saveData
