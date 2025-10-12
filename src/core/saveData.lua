local config = require('src.core.constants')

---@class SBJ__SaveData
local saveData = {}
saveData.c = {}
saveData.c.targetlist = {}
saveData.c.air = {}
saveData.c.air.landBased = {}
saveData.c.air.shipBased = {}
saveData.c.air.dynamicATO = {}
saveData.c.dynamicOperations = {}
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
}

-- Comms jamming
saveData.c.commsJamming.isActivated = true
saveData.c.commsJamming.jammers = {
  -- { guid = '' },
}

-- GPS Jamming
saveData.c.GPSJamming.isActivated = true
saveData.c.GPSJamming.jammers = {
  ['1st Bn, 1st ECM Bde'] = {
    zoneName = 'JAMMING ZONE/1',
    name = '1st Bn, 1st ECM Bde',
    point = { lat = 'N 25.28.17', lon = 'E 119.35.17' },
    randomRadius = config.c.GPSJamming.randomRadius,
    radius = config.c.GPSJamming.radius
  },
  ['2nd Bn, 1st ECM Bde'] = {
    zoneName = 'JAMMING ZONE/2',
    name = '2nd Bn, 1st ECM Bde',
    point = { lat = 'N 24.43.49', lon = 'E 118.29.41' },
    randomRadius = config.c.GPSJamming.randomRadius,
    radius = config.c.GPSJamming.radius
  },
}
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
    weaponDBID = config.weapon.FD280,
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
    weaponDBID = config.weapon.FD280,
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
    weaponDBID = config.weapon.CJ10,
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
    weaponDBID = config.weapon.DF11A,
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
    weaponDBID = config.weapon.DF11A,
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
    weaponDBID = config.weapon.DF16A,
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
    weaponDBID = config.weapon.DF15C,
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
    weaponDBID = config.weapon.DF15B,
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
    weaponDBID = config.weapon.DF16A,
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
    weaponDBID = config.weapon.DF21D,
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
    baseGUID = config.base.LIUAN_AB,
    unitDBID = config.platform.H6N,
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
saveData.c.ground.FSP = {}

-- Air tasking order (NEW VERSION WITH LOADOUT SUPPORT)
saveData.c.air.isActivated = true
saveData.c.air.ATO = {}



-- Amphibious ops
saveData.c.PHIBOP.startTime = config.c.triggers.amphibiousOps.startTime
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
      type075 = { locations = {}, locationIndex = 1, dbid = config.platform.TYPE_075, },
      type071 = { locations = {}, locationIndex = 1, dbid = config.platform.TYPE_071, },
      type076 = { locations = {}, locationIndex = 1, dbid = config.platform.TYPE_076, },
      type072iii = { locations = {}, locationIndex = 1, dbid = config.platform.TYPE_072III, },
      type072a = { locations = {}, locationIndex = 1, dbid = config.platform.TYPE_072A, },
      type073a = { locations = {}, locationIndex = 1, dbid = config.platform.TYPE_073A, },
      type071InLSTArea = { locations = {}, locationIndex = 1, dbid = config.platform.TYPE_071, },
      ferry = { locations = {}, locationIndex = 1, dbid = config.platform.FERRY, },
      roro = { locations = {}, locationIndex = 1, dbid = config.platform.FERRY, },
      barge = { locations = {}, locationIndex = 1, dbid = config.platform.BARGE, },
    }
  },
  ['Penghu'] = {
    name = 'Penghu',
    result = {
      type075 = { locations = {}, locationIndex = 1, dbid = config.platform.TYPE_075, },
      type071 = { locations = {}, locationIndex = 1, dbid = config.platform.TYPE_071, },
      type076 = { locations = {}, locationIndex = 1, dbid = config.platform.TYPE_076, },
      type072iii = { locations = {}, locationIndex = 1, dbid = config.platform.TYPE_072III, },
      type072a = { locations = {}, locationIndex = 1, dbid = config.platform.TYPE_072A, },
      type073a = { locations = {}, locationIndex = 1, dbid = config.platform.TYPE_073A, },
      type071InLSTArea = { locations = {}, locationIndex = 1, dbid = config.platform.TYPE_071, },
      ferry = { locations = {}, locationIndex = 1, dbid = config.platform.FERRY, },
      roro = { locations = {}, locationIndex = 1, dbid = config.platform.FERRY, },
      barge = { locations = {}, locationIndex = 1, dbid = config.platform.BARGE, },
    }
  },
  ['Sishu'] = {
    name = 'Sishu',
    result = {
      type075 = { locations = {}, locationIndex = 1, dbid = config.platform.TYPE_075, },
      type071 = { locations = {}, locationIndex = 1, dbid = config.platform.TYPE_071, },
      type076 = { locations = {}, locationIndex = 1, dbid = config.platform.TYPE_076, },
      type072iii = { locations = {}, locationIndex = 1, dbid = config.platform.TYPE_072III, },
      type072a = { locations = {}, locationIndex = 1, dbid = config.platform.TYPE_072A, },
      type073a = { locations = {}, locationIndex = 1, dbid = config.platform.TYPE_073A, },
      type071InLSTArea = { locations = {}, locationIndex = 1, dbid = config.platform.TYPE_071, },
      ferry = { locations = {}, locationIndex = 1, dbid = config.platform.FERRY, },
      roro = { locations = {}, locationIndex = 1, dbid = config.platform.FERRY, },
      barge = { locations = {}, locationIndex = 1, dbid = config.platform.BARGE, },
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
saveData.c.surface.lacm.startTime = config.c.triggers.launchLACM.startTime


-- SLCM
saveData.c.subSurface.slcm.isActivated = true
saveData.c.subSurface.slcm.startTime = config.c.triggers.launchSLCM.startTime


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
    weaponDBID = config.weapon.MK45_AMLRS,
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
    weaponDBID = config.weapon.ATACMS,
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
    unitCount = 3,
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
    unitCount = 3,
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
    weaponDBID = config.weapon.HF2E,
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
    weaponDBID = config.weapon.HF2E,
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
    weaponDBID = config.weapon.HF2,
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
    weaponDBID = config.weapon.HF2,
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
    weaponDBID = config.weapon.HF2,
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
    weaponDBID = config.weapon.HF2,
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
    weaponDBID = config.weapon.HF2,
    ammoThreshold = config.t.ground.ascm.ammoThreshold,
    ammunitionSection = 'IC8B0X-0HN87KFOFSGUB'
  },
}
saveData.t.ground.ascm.test = {
  isAntishipMissionActivated = false,
  nai1 = config.t.area.groundAscmTestNai1,
  nai2 = config.t.area.groundAscmTestNai2,
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
    areas = { config.t.area.THEATER_OF_OPS_3RD, },
    SAM = {},
    radar = {}
  },
  ['IC8B0X-0HNC3OB4KJKTC'] = {
    name = 'ROCC/East',
    msg = 'Radio source, C2',
    guid = 'IC8B0X-0HNC3OB4KJKTC',
    areas = { config.t.area.THEATER_OF_OPS_2ND, config.t.area.THEATER_OF_OPS_5TH, },
    SAM = {},
    radar = {}
  },
  ['IC8B0X-0HNC3OB4KJL2M'] = {
    name = 'ROCC/South',
    msg = 'Radio source, C2',
    guid = 'IC8B0X-0HNC3OB4KJL2M',
    areas = { config.t.area.THEATER_OF_OPS_4TH, },
    SAM = {},
    radar = {}
  },
}
saveData.t.IADS.TAAOC = {
  ['IC8B0X-0HN41D1QKTVU7'] = {
    name = 'TAAOC/3rd OPAREA',
    msg = 'Radio source, C2',
    guid = 'IC8B0X-0HN41D1QKTVU7',
    areas = { config.t.area.THEATER_OF_OPS_3RD, },
    SAM = {},
  },
  ['IC8B0X-0HN41D1QKU1ED'] = {
    name = 'TAAOC/5th OPAREA',
    msg = 'Radio source, C2',
    guid = 'IC8B0X-0HN41D1QKU1ED',
    areas = { config.t.area.THEATER_OF_OPS_5TH, },
    SAM = {},
  },
  ['IC8B0X-0HN41D1QKU0JP'] = {
    name = 'TAAOC/4th OPAREA',
    msg = 'Radio source, C2',
    guid = 'IC8B0X-0HN41D1QKU0JP',
    areas = { config.t.area.THEATER_OF_OPS_4TH, },
    SAM = {},
  },
  ['IC8B0X-0HNC27TV5Q0AS'] = {
    name = 'TAAOC/2nd OPAREA',
    msg = 'Radio source, C2',
    guid = 'IC8B0X-0HNC27TV5Q0AS',
    areas = { config.t.area.THEATER_OF_OPS_2ND, },
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

-- Dynamic Operations (unified reconnaissance schedule)
saveData.c.dynamicOperations.enabled = true
saveData.c.dynamicOperations.lastEvaluationTime = nil
saveData.c.dynamicOperations.generatedOperations = {
  air = {},   -- Track generated air operations
  ground = {} -- Track generated ground operations
}
saveData.c.dynamicOperations.reconSchedule = {
  {
    -- time = "2027-06-09 02:14:00",
    time = "2027-06-09 01:00:00",
    type = "satellite",
    delay = 0,
    executed = false,
    operations = {
      -- {
      --   type = "air",
      --   executed = false,
      --   template = {
      --     name = "STRIKE/AB/W/1",
      --     targetType = "STRIKE",
      --     isFirstWave = true,
      --     strikeInterval = 30 * 60,
      --     packages = config.c.packageTemplate.STRIKE_AB_W_1
      --   }
      -- },
      {
        type = "air",
        executed = false,
        template = {
          name = "STRIKE/AB/W/1",
          targetType = "STRIKE",
          isFirstWave = true,
          strikeInterval = 30 * 60,
          packages = config.c.packageTemplate.STRIKE_AB_W_AAR_1
        }
      },
      {
        type = "ground",
        executed = false,
        template = {
          name = "INFRASTRUCTURE/1",
          strikeInterval = 0,
          isFirstWave = true,
          FSTs = config.c.FSEMTemplate.STRIKE_INFRASTRUCTURE_1
        }
      },
      {
        type = "ground",
        executed = false,
        template = {
          name = "HELIPAD/1",
          strikeInterval = 0,
          isFirstWave = true,
          FSTs = config.c.FSEMTemplate.STRIKE_HELIPAD
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
    operations = {
      {
        type = "air",
        executed = false,
        template = {
          name = "STRIKE/AB/W/2",
          targetType = "STRIKE",
          isFirstWave = false,
          strikeInterval = 30 * 60,
          packages = config.c.packageTemplate.STRIKE_AB_W_2
        }
      },
      {
        type = "ground",
        executed = false,
        template = {
          name = "INFRASTRUCTURE/2",
          strikeInterval = 0,
          isFirstWave = false,
          FSTs = config.c.FSEMTemplate.STRIKE_INFRASTRUCTURE_2
        }
      },
      {
        type = "ground",
        executed = false,
        template = {
          name = "ANTISHIP/1",
          strikeInterval = 0,
          isFirstWave = false,
          FSTs = config.c.FSEMTemplate.ANTISHIP
        }
      },
      {
        type = "ground",
        executed = false,
        template = {
          name = "C2/1",
          strikeInterval = 0,
          isFirstWave = false,
          FSTs = config.c.FSEMTemplate.STRIKE_C2
        }
      }
    }
  },
  -- {
  --   -- time = "2027-06-09 04:40:00",
  --   time = "2027-06-09 01:00:00",
  --   type = "satellite",
  --   delay = 0,
  --   executed = false,
  --   operations = {
  --     {
  --       type = "air",
  --       executed = false,
  --       template = {
  --         name = "AIR INTERCEPT/E",
  --         targetType = "STRIKE",
  --         isFirstWave = true,
  --         strikeInterval = 30 * 60,
  --         packages = config.c.packageTemplate.AIR_INTERCEPT_E
  --       }
  --     }
  --   }
  -- },
  {
    time = "2027-06-09 05:44:00",
    type = "satellite",
    delay = 0,
    executed = false,
    operations = {}
  },
  {
    time = "2027-06-09 08:04:00",
    type = "satellite",
    delay = 0,
    executed = false,
    operations = {}
  },
  {
    time = "2027-06-09 11:25:00",
    type = "satellite",
    delay = 0,
    executed = false,
    operations = {}
  }
}

return saveData
