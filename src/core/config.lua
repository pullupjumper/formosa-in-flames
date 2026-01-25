local constants = require("src.core.constants")

---@class SBJ__Config
local config = {}
config.isDevMode = true
config.isSaved = true
config.difficulty = "normal"

-- Logging configuration
config.logging = {
  modules = {
    ground = { verbose = true },
    air = { verbose = true },
    PHIBOP = { verbose = false },
    recon = { verbose = true },
    dynamicOperations = { verbose = true },
    SIGINT = { verbose = false },
    commsJamming = { verbose = false },
    GPSJamming = { verbose = false },
    IADS = { verbose = false },
    attackManager = { verbose = false },
    unitGenerator = { verbose = false },
    missileSystem = { verbose = false },
    score = { verbose = true },
    init = { verbose = true },
  }
}
config.c = {}
config.t = {}
config.u = {}
config.s = {}

config.targetScanning = {
  distanceThreshold = 1, -- nautical miles
  taiwanAirBases = {
    "Jiashan AB",
    "Hualien AB",
    "Taitung/Jhihhang AB",
    "Pingtung North AB",
    "Pingtung South AB",
    "Gangshan AB",
    "Tainan AB",
    "Guiren AAB",
    "Magong AB",
    "Chiayi AB",
    "Ching Chuang Kang AB",
    "Hsinchu AB",
    "Longtan AAB",
    "Taipei Songshan Airport",
    "Taoyuan International Airport",
    "Hsinchu Field Airdrome",
    "Minxiong Emergency Highway Strip",
    "Madou Emergency Highway Strip",
    "Rende Emergency Highway Strip",
    "Tainan Field Airdrome",
  },
  taiwanPorts = {
    "Kaohsiung Port",
    "Donggang Wharf",
    "Port of Taipei",
    "Port of Keelung",
    "Suao Port",
    "HuangGang Fishing Harbor",
    "Magong Port",
  },
  targetCategories = {
    airfield = {
      runwayPattern = "Runway %(%d+m%)",
      taxiwayPattern = "Taxiway",
      shelterPattern = "Shelter",
      hangarPattern = "Hangar",
      tarmacPattern = "Tarmac",
      helipadPattern = "Helipad",
      ammoBunkerPattern = "Ammo Bunker",
      ammoRevetmentPattern = "Ammo Revetment",
    },
    port = {
      pierPattern = "Pier",
    },
    radar = {
      radarPattern = "Radar",
    },
    sam = {
      skyBowPattern = "Sky Bow",
    },
    asm = {
      asmPattern = "ASM",
    },
    c2 = {
      hengshanPattern = "Hengshan ROC command",
    }
  }
}

config.radarDistance = 70
-- config.readytime = 3600 * 1.5
config.readytime = 5 * 60


--- Battery states for the ground units
---@enum batteryState
config.batteryState = {
  STATIC = 0,
  REPOSITIONING = 1,
  RELOAD = 2,
  HIDE = 3,
}


-- ============================================================================
-- Setup Start Time
-- ============================================================================

config.c.triggers = {
  amphibiousOps = { startTime = "2027-06-09 02:40:00" },
  -- amphibiousOps = { startTime = "2027-06-09 1:00:00" },
  launchLACM = { startTime = "2027-06-09 06:00:00" },
  launchSLCM = { startTime = "2027-06-09 06:30:00" },
  -- launchSLCM = { startTime = "2027-06-09 01:00:00" },
}


-- ============================================================================
-- SIGINT (China)
-- ============================================================================

config.c.SIGINT = {}
config.c.SIGINT.maxCount = 6
-- config.c.SIGINT.maxCount = 1
config.c.SIGINT.maxRange = 2.5

-- Detection parameters
config.c.SIGINT.detectionThreshold = 60
config.c.SIGINT.maxDetectionRange = { 300, 340 }

-- Detection formula constants
config.c.SIGINT.formulaConstants = {
  decayRate = -1 / 450,
  power = 0.8,
  baseCoefficient = 0.00007937,
  powerDivisor = 10 ^ 6.1,
  randomFactor = 120,
  randomDivisor = 1500000,
  randomPowerDivisor = 10 ^ 5,
  distancePower = 2.25,
  distanceDivisor = 10 ^ 2.4
}

-- Default display configuration for map notifications
config.c.SIGINT.defaultDisplay = {
  r = 255,
  g = 255,
  b = 255,
  lifeTime = 4,
  fontSize = 16
}

-- Area and performance parameters
config.c.SIGINT.minPolygonPoints = 3
config.c.SIGINT.detectionSkipProbability = 0.3


-- ============================================================================
-- IADS (China)
-- ============================================================================

config.c.IADS = {}
config.c.IADS.ratio = { C2 = 1.5, }
config.c.IADS.C2FacilityDBIDs = { 319, 318, 115, 113 }
config.c.IADS.randomRadius = 10
config.c.IADS.C2Deployments = {
  {
    position = { latitude = "N 25.30.37", longitude = "E 119.30.54" },
    areas = { constants.AREAS.MILITARY_SUB_DISTRICT_FUZHOU, },
    name = "Fuzhou"
  },
  {
    position = { latitude = "N 25.19.12", longitude = "E 119.06.36" },
    areas = { constants.AREAS.MILITARY_SUB_DISTRICT_PUTIAN, },
    name = "Putian"
  },
  {
    position = { latitude = "N 24.57.01", longitude = "E 118.34.22" },
    areas = { constants.AREAS.MILITARY_SUB_DISTRICT_CHANGZHOU, },
    name = "Changzhou"
  },
  {
    position = { latitude = "N 24.43.19", longitude = "E 118.12.29" },
    areas = { constants.AREAS.MILITARY_SUB_DISTRICT_XIAMEN, },
    name = "Xiamen"
  },
  {
    position = { latitude = "N 24.10.12", longitude = "E 117.28.46" },
    areas = { constants.AREAS.MILITARY_SUB_DISTRICT_ZHANGZHOU, },
    name = "Zhangzhou"
  },
  {
    position = { latitude = "N 23.39.17", longitude = "E 116.41.26" },
    areas = { constants.AREAS.MILITARY_SUB_DISTRICT_SHANTOU, },
    name = "Shantou"
  },
  {
    position = { latitude = "N 23.08.19", longitude = "E 115.22.49" },
    areas = { constants.AREAS.MILITARY_SUB_DISTRICT_SHANWEI, },
    name = "Shanwei"
  },
  {
    position = { latitude = "N 24.06.12", longitude = "E 116.05.36" },
    areas = { constants.AREAS.MILITARY_SUB_DISTRICT_MEIZHOU, },
    name = "Meizhou"
  },
}


-- ============================================================================
-- Communications Jamming (China)
-- ============================================================================

config.c.commsJamming = {}
config.c.commsJamming.limit = 4
config.c.commsJamming.range = 50
config.c.commsJamming.initialComms = -20
config.c.commsJamming.baseJammingPower = -120
config.c.commsJamming.distanceExponent = 1.04
config.c.commsJamming.effectivenessFormula = { base = 1.9, range = 1.8 }
config.c.commsJamming.distanceThresholds = {
  close = 100,
  medium = 200,
  far = 300,
  distant = 400
}
config.c.commsJamming.aewSupport = {
  close = 400,  -- < 100nm
  medium = 350, -- < 200nm
  far = 250,    -- < 300nm
  distant = 150 -- < 400nm
}
-- config.c.commsJamming.recoveryTime = { min = 15, max = 25 }
config.c.commsJamming.recoveryTime = { min = 5, max = 10 }
config.c.commsJamming.jammingTime = { min = 5, max = 10 }
config.c.commsJamming.cooldownTime = { min = -5, max = -1 }
config.c.commsJamming.randomVariance = {
  close = { min = -1, max = 1 },
  medium = { min = -3, max = 3 },
  far = { min = -6, max = 6 },
  distant = { min = -10, max = 10 }
}


-- ============================================================================
-- GPS Jamming (China)
-- ============================================================================

config.c.GPSJamming = {}
config.c.GPSJamming.randomRadius = 20 -- random radius
config.c.GPSJamming.radius = 14
config.c.GPSJamming.GPSGuidedWeapons = {
  { dbid = constants.WEAPONS.JDAM,       jammingResistance = 50 },
  { dbid = constants.WEAPONS.WAN_CHIEN,  jammingResistance = 50 },
  { dbid = constants.WEAPONS.HARPOON_II, jammingResistance = 50 },
  { dbid = constants.WEAPONS.JSOW,       jammingResistance = 50 },
  { dbid = constants.WEAPONS.SLAMER,     jammingResistance = 50 },
}
config.c.GPSJamming.jammers = {
  ["1st Bn, 1st ECM Bde"] = {
    zoneName = "JAMMING ZONE/1",
    name = "1st Bn, 1st ECM Bde",
    point = { latitude = "N 25.28.17", longitude = "E 119.35.17" },
    randomRadius = config.c.GPSJamming.randomRadius,
    radius = config.c.GPSJamming.radius
  },
  ["2nd Bn, 1st ECM Bde"] = {
    zoneName = "JAMMING ZONE/2",
    name = "2nd Bn, 1st ECM Bde",
    point = { latitude = "N 24.43.49", longitude = "E 118.29.41" },
    randomRadius = config.c.GPSJamming.randomRadius,
    radius = config.c.GPSJamming.radius
  },
}

-- ============================================================================
-- MLRS (China)
-- ============================================================================

config.c.ground = {}
config.c.ground.mlrs = {}
config.c.ground.mlrs.wpnDefault = 192
config.c.ground.mlrs.ammoThreshold = 50
config.c.ground.mlrs.operationalAreas = {
  Pingtan = constants.OPERATIONAL_AREAS.PINGTAN,
  Chinchew = constants.OPERATIONAL_AREAS.CHINCHEW,
}
config.c.ground.mlrs.contactAge = 30 * 60
config.c.ground.mlrs.reloadTime = 30 * 60
config.c.ground.mlrs.ammunitions = {
  ["Ammo Revetment, 1st Bn, 1st Rockets Arty Bde"] = {
    guid = "IC8B0X-0HN9ASEFCGDKF",
    name = "Ammo Revetment, 1st Bn, 1st Rockets Arty Bde",
    wpnCurrent = config.c.ground.mlrs.wpnDefault,
    wpnDefault = config.c.ground.mlrs.wpnDefault,
  },
  ["Ammo Revetment, 6th Bn, 73rd Arty Bde"] = {
    guid = "IC8B0X-0HNBRRE2PRT40",
    name = "Ammo Revetment, 6th Bn, 73rd Arty Bde",
    wpnCurrent = config.c.ground.mlrs.wpnDefault,
    wpnDefault = config.c.ground.mlrs.wpnDefault,
  },
}
config.c.ground.mlrs.resupplyUnits = {
  ["Ammo Sec, 1st Bn, 1st Rockets Arty Bde"] = {
    guid = "IC8B0X-0HN7R5QOERV4D",
    name = "Ammo Sec, 1st Bn, 1st Rockets Arty Bde",
    wpnCurrent = config.c.ground.mlrs.wpnDefault,
    wpnDefault = config.c.ground.mlrs.wpnDefault,
    unitCount = 3,
    operationalArea = config.c.ground.mlrs.operationalAreas.Pingtan,
    state = config.batteryState.STATIC,
    ammunition = "Ammo Revetment, 1st Bn, 1st Rockets Arty Bde",
  },
  ["Ammo Sec, 6th Bn, 73rd Arty Bde"] = {
    guid = "IC8B0X-0HNBRRE2PRRG9",
    name = "Ammo Sec, 6th Bn, 73rd Arty Bde",
    wpnCurrent = config.c.ground.mlrs.wpnDefault,
    wpnDefault = config.c.ground.mlrs.wpnDefault,
    unitCount = 3,
    operationalArea = config.c.ground.mlrs.operationalAreas.Chinchew,
    state = config.batteryState.STATIC,
    ammunition = "Ammo Revetment, 6th Bn, 73rd Arty Bde",
  },
}
config.c.ground.mlrs.firingUnits = {
  ["1st Bn, 1st Rockets Arty Bde"] = {
    name = "1st Bn, 1st Rockets Arty Bde",
    msg = "Radio source, Bty",
    guid = "IC8B0X-0HND05GGU36EN",
    state = config.batteryState.HIDE,
    operationalArea = config.c.ground.mlrs.operationalAreas.Pingtan,
    weaponDBID = constants.WEAPONS.FD280,
    ammoThreshold = config.c.ground.mlrs.ammoThreshold,
    resupplyUnit = "Ammo Sec, 1st Bn, 1st Rockets Arty Bde",
    dbid = constants.PLATFORMS.PHL16
  },
  ["6th Bn, 73rd Arty Bde"] = {
    name = "6th Bn, 73rd Arty Bde",
    msg = "Radio source, Bty",
    guid = "IC8B0X-0HNBRRE2PRQAL",
    state = config.batteryState.HIDE,
    operationalArea = config.c.ground.mlrs.operationalAreas.Chinchew,
    weaponDBID = constants.WEAPONS.FD280,
    ammoThreshold = config.c.ground.mlrs.ammoThreshold,
    resupplyUnit = "Ammo Sec, 6th Bn, 73rd Arty Bde",
    dbid = constants.PLATFORMS.PHL16
  },
}


-- ============================================================================
-- GLCM (China)
-- ============================================================================

config.c.ground.glcm = {}
config.c.ground.glcm.wpnDefault = 120
config.c.ground.glcm.ammoThreshold = 50
config.c.ground.glcm.operationalAreas = {
  Brigade635 = constants.OPERATIONAL_AREAS.BRIGADE_635,
}
config.c.ground.glcm.contactAge = 30 * 60
config.c.ground.glcm.reloadTime = 45 * 60
config.c.ground.glcm.ammunitions = {
  ["Ammo Revetment, 635th Bde, PLARF"] = {
    guid = "IC8B0X-0HN99I5RL5KR9",
    name = "Ammo Revetment, 635th Bde, PLARF",
    wpnCurrent = config.c.ground.glcm.wpnDefault / 2,
    wpnDefault = config.c.ground.glcm.wpnDefault / 2,
  },
}
config.c.ground.glcm.resupplyUnits = {
  ["Ammo Sec, 635th Bde, PLARF"] = {
    guid = "IC8B0X-0HN7R5QOIVG88",
    name = "Ammo Sec, 635th Bde, PLARF",
    wpnCurrent = config.c.ground.glcm.wpnDefault / 2,
    wpnDefault = config.c.ground.glcm.wpnDefault / 2,
    unitCount = 5,
    operationalArea = config.c.ground.glcm.operationalAreas.Brigade635,
    state = config.batteryState.STATIC,
    ammunition = "Ammo Revetment, 635th Bde, PLARF",
  },
}
config.c.ground.glcm.firingUnits = {
  ["635th Bde, PLARF"] = {
    guid = "6Z8LM5-0HMN97ERAUODK",
    name = "635th Bde, PLARF",
    msg = "Radio source, Bty",
    state = config.batteryState.HIDE,
    operationalArea = config.c.ground.glcm.operationalAreas.Brigade635,
    weaponDBID = constants.WEAPONS.CJ10A,
    ammoThreshold = config.c.ground.glcm.ammoThreshold,
    resupplyUnit = "Ammo Sec, 635th Bde, PLARF",
    dbid = constants.PLATFORMS.CH_SSC_9
  },
}

-- ============================================================================
-- SRBM (China)
-- ============================================================================

config.c.ground.srbm = {}
config.c.ground.srbm.wpnDefault = 36
config.c.ground.srbm.ammoThreshold = 35
config.c.ground.srbm.operationalAreas = {
  Brigade615 = constants.OPERATIONAL_AREAS.BRIGADE_615,
  Brigade614 = constants.OPERATIONAL_AREAS.BRIGADE_614,
  Brigade636 = constants.OPERATIONAL_AREAS.BRIGADE_636,
  Brigade616 = constants.OPERATIONAL_AREAS.BRIGADE_616,
  Brigade613 = constants.OPERATIONAL_AREAS.BRIGADE_613,
  Brigade617 = constants.OPERATIONAL_AREAS.BRIGADE_617,
}
config.c.ground.srbm.contactAge = 30 * 60
config.c.ground.srbm.reloadTime = 5 * 60
config.c.ground.srbm.ammunitions = {
  ["Ammo Revetment, 615th Bde, PLARF"] = {
    guid = "IC8B0X-0HN9ASEFCG848",
    name = "Ammo Revetment, 615th Bde, PLARF",
    wpnCurrent = config.c.ground.srbm.wpnDefault * 2,
    wpnDefault = config.c.ground.srbm.wpnDefault * 2,
  },
  ["Ammo Revetment, 614th Bde, PLARF"] = {
    guid = "IC8B0X-0HN9ASEFCG95Q",
    name = "Ammo Revetment, 614th Bde, PLARF",
    wpnCurrent = config.c.ground.srbm.wpnDefault * 2,
    wpnDefault = config.c.ground.srbm.wpnDefault * 2,
  },
  ["Ammo Revetment, 636th Bde, PLARF"] = {
    guid = "IC8B0X-0HN9ASEFCG8CT",
    name = "Ammo Revetment, 636th Bde, PLARF",
    wpnCurrent = config.c.ground.srbm.wpnDefault * 2,
    wpnDefault = config.c.ground.srbm.wpnDefault * 2,
  },
  ["Ammo Revetment, 616th Bde, PLARF"] = {
    guid = "IC8B0X-0HN9ASEFCG8OK",
    name = "Ammo Revetment, 616th Bde, PLARF",
    wpnCurrent = config.c.ground.srbm.wpnDefault * 2,
    wpnDefault = config.c.ground.srbm.wpnDefault * 2,
  },
  ["Ammo Revetment, 613rd Bde, PLARF"] = {
    guid = "IC8B0X-0HN9ASEFCG9GA",
    name = "Ammo Revetment, 613rd Bde, PLARF",
    wpnCurrent = config.c.ground.srbm.wpnDefault * 2,
    wpnDefault = config.c.ground.srbm.wpnDefault * 2,
  },
  ["Ammo Revetment, 617th Bde, PLARF"] = {
    guid = "IC8B0X-0HN9ASEFCGA5A",
    name = "Ammo Revetment, 617th Bde, PLARF",
    wpnCurrent = config.c.ground.srbm.wpnDefault * 2,
    wpnDefault = config.c.ground.srbm.wpnDefault * 2,
  },
}
config.c.ground.srbm.resupplyUnits = {
  ["Ammo Sec, 615th Bde, PLARF"] = {
    guid = "IC8B0X-0HN7R5QOIVL7D",
    name = "Ammo Sec, 615th Bde, PLARF",
    wpnCurrent = config.c.ground.srbm.wpnDefault,
    wpnDefault = config.c.ground.srbm.wpnDefault,
    unitCount = 6,
    operationalArea = config.c.ground.srbm.operationalAreas.Brigade615,
    state = config.batteryState.STATIC,
    ammunition = "Ammo Revetment, 615th Bde, PLARF",
  },
  ["Ammo Sec, 614th Bde, PLARF"] = {
    guid = "IC8B0X-0HN7R5QOIVLSG",
    name = "Ammo Sec, 614th Bde, PLARF",
    wpnCurrent = config.c.ground.srbm.wpnDefault,
    wpnDefault = config.c.ground.srbm.wpnDefault,
    unitCount = 6,
    operationalArea = config.c.ground.srbm.operationalAreas.Brigade614,
    state = config.batteryState.STATIC,
    ammunition = "Ammo Revetment, 614th Bde, PLARF",
  },
  ["Ammo Sec, 636th Bde, PLARF"] = {
    guid = "IC8B0X-0HN7R5QOIVMO1",
    name = "Ammo Sec, 636th Bde, PLARF",
    wpnCurrent = config.c.ground.srbm.wpnDefault,
    wpnDefault = config.c.ground.srbm.wpnDefault,
    unitCount = 9,
    operationalArea = config.c.ground.srbm.operationalAreas.Brigade636,
    state = config.batteryState.STATIC,
    ammunition = "Ammo Revetment, 636th Bde, PLARF",
  },
  ["Ammo Sec, 616th Bde, PLARF"] = {
    guid = "IC8B0X-0HN7R5QOIVOSN",
    name = "Ammo Sec, 616th Bde, PLARF",
    wpnCurrent = config.c.ground.srbm.wpnDefault,
    wpnDefault = config.c.ground.srbm.wpnDefault,
    unitCount = 6,
    operationalArea = config.c.ground.srbm.operationalAreas.Brigade616,
    state = config.batteryState.STATIC,
    ammunition = "Ammo Revetment, 616th Bde, PLARF",
  },
  ["Ammo Sec, 613rd Bde, PLARF"] = {
    guid = "IC8B0X-0HN7R5QOIVPNC",
    name = "Ammo Sec, 613rd Bde, PLARF",
    wpnCurrent = config.c.ground.srbm.wpnDefault,
    wpnDefault = config.c.ground.srbm.wpnDefault,
    unitCount = 6,
    operationalArea = config.c.ground.srbm.operationalAreas.Brigade613,
    state = config.batteryState.STATIC,
    ammunition = "Ammo Revetment, 613rd Bde, PLARF",
  },
  ["Ammo Sec, 617th Bde, PLARF"] = {
    guid = "IC8B0X-0HN7R5QOIVQ6P",
    name = "Ammo Sec, 617th Bde, PLARF",
    wpnCurrent = config.c.ground.srbm.wpnDefault,
    wpnDefault = config.c.ground.srbm.wpnDefault,
    unitCount = 9,
    operationalArea = config.c.ground.srbm.operationalAreas.Brigade617,
    state = config.batteryState.STATIC,
    ammunition = "Ammo Revetment, 617th Bde, PLARF",
  },
}
config.c.ground.srbm.firingUnits = {
  ["615th Bde, PLARF"] = {
    guid = "X58F5H-0HN1G2IFLNKG9",
    name = "615th Bde, PLARF",
    msg = "Radio source, Bty",
    state = config.batteryState.HIDE,
    operationalArea = config.c.ground.srbm.operationalAreas.Brigade615,
    weaponDBID = constants.WEAPONS.DF11A,
    ammoThreshold = config.c.ground.srbm.ammoThreshold,
    resupplyUnit = "Ammo Sec, 615th Bde, PLARF",
    dbid = constants.PLATFORMS.CSS7_MOD2
  },
  ["614th Bde, PLARF"] = {
    guid = "X58F5H-0HN1LQGRV8HNQ",
    name = "614th Bde, PLARF",
    msg = "Radio source, Bty",
    state = config.batteryState.HIDE,
    operationalArea = config.c.ground.srbm.operationalAreas.Brigade614,
    weaponDBID = constants.WEAPONS.DF11A,
    ammoThreshold = config.c.ground.srbm.ammoThreshold,
    resupplyUnit = "Ammo Sec, 614th Bde, PLARF",
    dbid = constants.PLATFORMS.CSS7_MOD2
  },
  ["636th Bde, PLARF"] = {
    guid = "IC8B0X-0HN822OHANPB3",
    name = "636th Bde, PLARF",
    msg = "Radio source, Bty",
    state = config.batteryState.HIDE,
    operationalArea = config.c.ground.srbm.operationalAreas.Brigade636,
    weaponDBID = constants.WEAPONS.DF16A,
    ammoThreshold = config.c.ground.srbm.ammoThreshold,
    resupplyUnit = "Ammo Sec, 636th Bde, PLARF",
    dbid = constants.PLATFORMS.CSS11_MOD1
  },
  ["616th Bde, PLARF"] = {
    guid = "X58F5H-0HN1G2IFLF6QE",
    name = "616th Bde, PLARF",
    msg = "Radio source, Bty",
    state = config.batteryState.HIDE,
    operationalArea = config.c.ground.srbm.operationalAreas.Brigade616,
    weaponDBID = constants.WEAPONS.DF15C,
    ammoThreshold = config.c.ground.srbm.ammoThreshold,
    resupplyUnit = "Ammo Sec, 616th Bde, PLARF",
    dbid = constants.PLATFORMS.CSS6_MOD2
  },
  ["613rd Bde, PLARF"] = {
    guid = "X58F5H-0HN1G2DEBC7O8",
    name = "613rd Bde, PLARF",
    msg = "Radio source, Bty",
    state = config.batteryState.HIDE,
    operationalArea = config.c.ground.srbm.operationalAreas.Brigade613,
    weaponDBID = constants.WEAPONS.DF15B,
    ammoThreshold = config.c.ground.srbm.ammoThreshold,
    resupplyUnit = "Ammo Sec, 613rd Bde, PLARF",
    dbid = constants.PLATFORMS.CSS6_MOD3
  },
  ["617th Bde, PLARF"] = {
    guid = "IC8B0X-0HN822OHANRHI",
    name = "617th Bde, PLARF",
    msg = "Radio source, Bty",
    state = config.batteryState.HIDE,
    operationalArea = config.c.ground.srbm.operationalAreas.Brigade617,
    weaponDBID = constants.WEAPONS.DF16A,
    ammoThreshold = config.c.ground.srbm.ammoThreshold,
    resupplyUnit = "Ammo Sec, 617th Bde, PLARF",
    dbid = constants.PLATFORMS.CSS11_MOD1
  },
}

-- ============================================================================
-- MRBM (China)
-- ============================================================================

config.c.ground.mrbm = {}
config.c.ground.mrbm.wpnDefault = 24
config.c.ground.mrbm.ammoThreshold = 35
config.c.ground.mrbm.operationalAreas = {
  Brigade624 = constants.OPERATIONAL_AREAS.BRIGADE_624,
}
config.c.ground.mrbm.contactAge = 15 * 60
config.c.ground.mrbm.reloadTime = 5 * 60
config.c.ground.mrbm.ammunitions = {
  ["Ammo Revetment, 624th Bde, PLARF"] = {
    guid = "IC8B0X-0HNCOR6HG2KK5",
    name = "Ammo Revetment, 624th Bde, PLARF",
    wpnCurrent = config.c.ground.mrbm.wpnDefault * 2,
    wpnDefault = config.c.ground.mrbm.wpnDefault * 2,
  },
}
config.c.ground.mrbm.resupplyUnits = {
  ["Ammo Sec, 624th Bde, PLARF"] = {
    guid = "IC8B0X-0HNCOR6HG2KF9",
    name = "Ammo Sec, 624th Bde, PLARF",
    wpnCurrent = config.c.ground.mrbm.wpnDefault,
    wpnDefault = config.c.ground.mrbm.wpnDefault,
    unitCount = 6,
    operationalArea = config.c.ground.mrbm.operationalAreas.Brigade624,
    state = config.batteryState.STATIC,
    ammunition = "Ammo Revetment, 624th Bde, PLARF",
  },
}
config.c.ground.mrbm.firingUnits = {
  ["624th Bde, PLARF"] = {
    guid = "IC8B0X-0HNCOR6HG2JE1",
    name = "624th Bde, PLARF",
    msg = "Radio source, Bty",
    state = config.batteryState.HIDE,
    operationalArea = config.c.ground.mrbm.operationalAreas.Brigade624,
    weaponDBID = constants.WEAPONS.DF21D,
    ammoThreshold = config.c.ground.mrbm.ammoThreshold,
    resupplyUnit = "Ammo Sec, 624th Bde, PLARF",
    dbid = constants.PLATFORMS.CSS5_MOD5
  },
}

-- ============================================================================
-- Reconnaissance (China)
-- ============================================================================

config.c.recon = {}
config.c.recon.template = {
  BZK005_RECON_1 = {
    type = "UAV",
    baseGUID = constants.BASES.LONGTIAN_AAB,
    unitDBID = constants.PLATFORMS.BZK005,
    course = constants.COURSES.BZK005_1,
    unitCount = 1,
    speed = 115,
    isTracking = false
  },
  BZK005_RECON_2 = {
    type = "UAV",
    baseGUID = constants.BASES.SHANTOU_WAISHA_AB,
    unitDBID = constants.PLATFORMS.BZK005,
    course = constants.COURSES.BZK005_2,
    unitCount = 1,
    speed = 115,
    isTracking = false
  },
  WZ8_RECON_ISLAND = {
    type = "UAV",
    baseGUID = constants.BASES.LIUAN_AB,
    unitDBID = constants.PLATFORMS.H6N,
    course = constants.COURSES.H6N,
    unitCount = 1,
    speed = 450,
    isTracking = true
  },
  WZ7_RECON_1 = {
    type = "UAV",
    baseGUID = constants.BASES.LONGTIAN_AAB,
    unitDBID = constants.PLATFORMS.WZ7,
    course = constants.COURSES.BZK005_1,
    unitCount = 1,
    speed = 450,
    isTracking = false
  },
  TB001_RECON_1 = {
    type = "UAV",
    baseGUID = constants.BASES.LONGTIAN_AAB,
    unitDBID = constants.PLATFORMS.TB001,
    course = constants.COURSES.BZK005_1,
    unitCount = 1,
    speed = 135,
    isTracking = false
  },
  GJ11_RECON = {
    type = "UAV",
    baseGUID = "Type 076",
    unitDBID = constants.PLATFORMS.GJ11,
    course = constants.COURSES.GJ11,
    unitCount = 1,
    speed = 600,
    isTracking = false
  }
}
config.c.recon.reconStrikeMatrix = {
  UAV = {
    BZK005 = {
      { name = "STRIKE/C2/1", type = "ground", }
    },
    GJ11 = {
      { name = "CAS/N/1",     type = "air", },
      { name = "STRIKE/C2/1", type = "ground", }
    },
    H6N = {
      { name = "ANTISHIP/1",    type = "ground" },
      { name = "ASUW/N/1",      type = "air" },
      { name = "STRIKE/AB/E/1", type = "air" },
      { name = "STRIKE/AB/W/1", type = "air" }
    },
  },
  satellite = {
    EOS = {
      { name = "STRIKE/AB/W/1",           type = "air" },
      { name = "STRIKE/AB/E/1",           type = "air" },
      { name = "STRIKE/HELIPAD/1",        type = "ground" },
      { name = "STRIKE/INFRASTRUCTURE/1", type = "ground" },
    }
  }
}
config.c.recon.queue = {
  {
    type = "UAV",
    baseGUID = constants.BASES.LIUAN_AB,
    unitDBID = constants.PLATFORMS.H6N,
    unitGUID = nil,
    course = constants.COURSES.H6N,
    unitCount = 1,
    -- takeoffTime = "2027-06-09 01:20:00",
    takeoffTime = "2027-06-09 01:00:00",
    endTime = "2027-06-09 02:00:00",
    isFinished = false,
    trackingTargetGUID = nil,
    speed = 450
  },
  {
    type = "satellite",
    endTime = "2027-06-09 01:00:00",
    -- endTime = "2027-06-09 04:40:00",
  },
  {
    type = "satellite",
    -- endTime = "2027-06-09 01:00:00",
    endTime = "2027-06-09 05:44:00",
  },
  {
    type = "satellite",
    -- endTime = "2027-06-09 01:30:00",
    endTime = "2027-06-09 08:04:00",
  },
  {
    type = "satellite",
    endTime = "2027-06-09 11:25:00",
  },
}


-- ============================================================================
-- Aircraft Deployment (China)
-- ============================================================================

config.c.air = {}
config.c.air.landBased = {}
config.c.air.shipBased = {}
config.c.air.landBased.deployedACs = {
  {
    name = "Huizhou Pingtan AB (PLAAF)",
    baseGUID = constants.BASES.HUIZHOU_PINGTAN_AB,
    embarkedUnits = {
      {
        side = "China",
        type = "Air",
        dbid = constants.PLATFORMS.Y8Q_CUB,
        platformName = "Y-8Q CUB",
        name = "1st Naval AF Div",
        loadouts = {
          { name = "ASW Patrol", loadoutId = constants.LOADOUTS.Y8Q_ASW, num = 3, missionName = "ASW/PATROL AC" },
        }
      }
    }
  },
  {
    name = "Shantou Waisha AB (PLAAF)",
    baseGUID = constants.BASES.SHANTOU_WAISHA_AB,
    embarkedUnits = {
      {
        side = "China",
        type = "Air",
        dbid = constants.PLATFORMS.J16,
        platformName = "J-16",
        name = "7th Air Bde",
        loadouts = {
          { name = "AKD-88 Strike", loadoutId = constants.LOADOUTS.J16_AKD88, num = 24 },
        }
      },
      {
        side = "China",
        type = "Air",
        dbid = constants.PLATFORMS.BZK005,
        platformName = "BZK-005",
        name = "60th Det, PLARF UAV Reg",
        loadouts = {
          { loadoutId = constants.LOADOUTS.BZK005_RECON, num = 6 },
        }
      },
    },
    loadouts = {
      { name = "AKD-88 Strike", loadoutId = constants.LOADOUTS.J16_AKD88, num = 24 }, --AKD-88 X 2
    }
  },
  {
    name = "Zhangpu AAB",
    baseGUID = constants.BASES.ZHANGPU_AAB,
    embarkedUnits = {
      {
        side = "China",
        type = "Air",
        dbid = constants.PLATFORMS.SU30,
        platformName = "Su-30",
        name = "804th Air Bde",
        loadouts = {
          { name = "KAB-1500 Strike", loadoutId = constants.LOADOUTS.SU30_KAB1500, num = 12 },
        }
      },
      {
        side = "China",
        type = "Air",
        dbid = constants.PLATFORMS.J16D,
        platformName = "J-16D",
        name = "40th Air Bde",
        loadouts = {
          { name = "Electronic Warfare", loadoutId = constants.LOADOUTS.J16D_OECM, num = 4 },
        }
      },
      {
        side = "China",
        type = "Air",
        dbid = constants.PLATFORMS.IL76,
        platformName = "Il-76",
        name = "39th Air Reg",
        loadouts = {
          { name = "Transport", loadoutId = constants.LOADOUTS.IL76_TRANSPORT, num = 3 },
        }
      },
      {
        side = "China",
        type = "Air",
        dbid = constants.PLATFORMS.Y9DZ,
        platformName = "Y-9DZ",
        name = "60th Air Reg",
        loadouts = {
          { name = "SIGINT", loadoutId = constants.LOADOUTS.Y9DZ_SIGINT, num = 3, missionName = "SIGINT" },
        }
      },
    },
    loadouts = {
      { name = "KAB-1500 Strike",    loadoutId = constants.LOADOUTS.SU30_KAB1500, num = 12 }, --KAB-1500 X 2
      { name = "Electronic Warfare", loadoutId = constants.LOADOUTS.J16D_OECM,    num = 4 },
    }
  },
  {
    name = "Zhangzhou-Longxi AB (PLAAF)",
    baseGUID = constants.BASES.ZHANGZHOU_LONGXI_AB,
    embarkedUnits = {
      {
        side = "China",
        type = "Air",
        dbid = constants.PLATFORMS.SU30,
        platformName = "Su-30",
        name = "804th Air Bde",
        loadouts = {
          { name = "YJ-91 ARM", loadoutId = constants.LOADOUTS.SU30_YJ91, num = 24 },
        }
      }
    },
    loadouts = {
      { name = "YJ-91 ARM", loadoutId = constants.LOADOUTS.SU30_YJ91, num = 24 }, --YJ-91 X 2
    }
  },
  {
    name = "Huian AAB",
    baseGUID = constants.BASES.HUIAN_AAB,
    embarkedUnits = {
      {
        side = "China",
        type = "Air",
        dbid = constants.PLATFORMS.J16,
        platformName = "J-16",
        name = "40th Air Bde",
        loadouts = {
          { name = "AKD-88 Strike", loadoutId = constants.LOADOUTS.J16_AKD88, num = 12 },
        }
      },
      {
        side = "China",
        type = "Air",
        dbid = constants.PLATFORMS.J20,
        platformName = "J-20",
        name = "41st Air Bde",
        loadouts = {
          { name = "PL-15 AAM", loadoutId = constants.LOADOUTS.J20_PL15, num = 12 },
        }
      },
    },
    loadouts = {
      { name = "PL-15 AAM",     loadoutId = constants.LOADOUTS.J20_PL15,  num = 12 }, --PL-15 X 4
      { name = "AKD-88 Strike", loadoutId = constants.LOADOUTS.J16_AKD88, num = 12 }, --AKD-88 X 2
    }
  },
  {
    name = "Longtian AAB",
    baseGUID = constants.BASES.LONGTIAN_AAB,
    embarkedUnits = {
      {
        side = "China",
        type = "Air",
        dbid = constants.PLATFORMS.BZK005,
        platformName = "BZK-005",
        name = "62nd Det, PLARF UAV Reg",
        loadouts = {
          { name = "Reconnaissance", loadoutId = constants.LOADOUTS.BZK005_RECON, num = 6 },
        }
      },
      {
        side = "China",
        type = "Air",
        dbid = constants.PLATFORMS.SU30,
        platformName = "Su-30",
        name = "804th Air Bde",
        loadouts = {
          { name = "YJ-91 ARM", loadoutId = constants.LOADOUTS.SU30_YJ91, num = 8 },
        }
      }
    },
    loadouts = {
      { name = "YJ-91 ARM", loadoutId = constants.LOADOUTS.SU30_YJ91, num = 8 }, --YJ-91 X 2
    }
  },
  {
    name = "Xingning AB (PLAAF)",
    baseGUID = constants.BASES.XINGNING_AB,
    embarkedUnits = {
      {
        side = "China",
        type = "Air",
        dbid = constants.PLATFORMS.H6K,
        platformName = "H-6K",
        name = "29th Air Reg",
        loadouts = {
          { name = "YJ-63 Strike", loadoutId = constants.LOADOUTS.H6K_YJ63, num = 12 },
        }
      }
    },
    loadouts = {
      { name = "YJ-63 Strike", loadoutId = constants.LOADOUTS.H6K_YJ63, num = 12 }, --YJ-63 X 4
    }
  },
  {
    name = "Shuimen AAB (PLAAF)",
    baseGUID = constants.BASES.SHUIMEN_AAB,
    embarkedUnits = {
      {
        side = "China",
        type = "Air",
        dbid = constants.PLATFORMS.SU30,
        platformName = "Su-30",
        name = "804th Air Bde",
        loadouts = {
          { name = "YJ-91 ARM", loadoutId = constants.LOADOUTS.SU30_YJ91, num = 8 },
        }
      },
      {
        side = "China",
        type = "Air",
        dbid = constants.PLATFORMS.J16,
        platformName = "J-16",
        name = "40th Air Bde",
        loadouts = {
          { name = "YJ-83 Anti-Ship", loadoutId = constants.LOADOUTS.J16_YJ83, num = 8 },
        }
      },
      {
        side = "China",
        type = "Air",
        dbid = constants.PLATFORMS.KJ500,
        platformName = "KJ-500",
        name = "75th Air Reg",
        loadouts = {
          { name = "AEW", loadoutId = constants.LOADOUTS.KJ500_AEW, num = 3, missionName = "AEW/N" },
        }
      },
      {
        side = "China",
        type = "Air",
        dbid = constants.PLATFORMS.HY6U_BADGER,
        platformName = "HY-6U Badger",
        name = "23rd Air Reg",
        loadouts = {
          { name = "Aerial Refueling", loadoutId = constants.LOADOUTS.HY6U_AAR, num = 8, },
        }
      },
      {
        side = "China",
        type = "Air",
        dbid = constants.PLATFORMS.J10C,
        platformName = "J-10C",
        name = "25th Air Bde",
        loadouts = {
          { name = "CS-BBC-5 Strike", loadoutId = constants.LOADOUTS.J10C_CS_BBC_5, num = 8 },
        }
      },
    },
    loadouts = {
      { name = "YJ-91 ARM",       loadoutId = constants.LOADOUTS.SU30_YJ91,     num = 8 }, --YJ-91 X 2
      { name = "YJ-83 Anti-Ship", loadoutId = constants.LOADOUTS.J16_YJ83,      num = 8 }, --YJ-83 X 2
      { name = "CS-BBC-5 Strike", loadoutId = constants.LOADOUTS.J10C_CS_BBC_5, num = 8 }, --CS-BBC-5 X 2
    }
  },
  {
    name = "Anqing AB (PLAAF)",
    baseGUID = constants.BASES.ANQING_AB,
    embarkedUnits = {
      {
        side = "China",
        type = "Air",
        dbid = constants.PLATFORMS.H6K,
        platformName = "H-6K",
        name = "28th Air Reg",
        loadouts = {
          { name = "YJ-63 Strike", loadoutId = constants.LOADOUTS.H6K_YJ63, num = 12 },
        }
      }
    },
    loadouts = {
      { name = "YJ-63 Strike", loadoutId = constants.LOADOUTS.H6K_YJ63, num = 12 }, --YJ-63 X 4
    }
  },
  {
    name = "Wuhu AB (PLAAF)",
    baseGUID = constants.BASES.WUHU_AB,
    embarkedUnits = {
      {
        side = "China",
        type = "Air",
        dbid = constants.PLATFORMS.J20,
        platformName = "J-20",
        name = "9th Air Bde",
        loadouts = {
          { name = "PL-15 AAM", loadoutId = constants.LOADOUTS.J20_PL15, num = 12 },
        }
      }
    },
    loadouts = {
      { name = "PL-15 AAM", loadoutId = constants.LOADOUTS.J20_PL15, num = 12 }, --PL-15 X 4
    }
  },
  {
    name = "Liuan AB",
    baseGUID = constants.BASES.LIUAN_AB,
    embarkedUnits = {
      {
        side = "China",
        type = "Air",
        dbid = constants.PLATFORMS.H6N,
        platformName = "H-6N",
        name = "107th Air Reg",
        loadouts = {
          { name = "Transport", loadoutId = constants.LOADOUTS.H6N_TRANSPORT, num = 4 },
        }
      }
    }
  },
  {
    name = "Taizhou AB (PLAAF)",
    baseGUID = constants.BASES.TAIZHOU_AB,
    embarkedUnits = {
      {
        side = "China",
        type = "Air",
        dbid = constants.PLATFORMS.SU30,
        platformName = "Su-30",
        name = "94th Air Bde",
        loadouts = {
          { name = "YJ-91 ARM", loadoutId = constants.LOADOUTS.SU30_YJ91, num = 12 },
        }
      }
    },
    loadouts = {
      { name = "YJ-91 ARM", loadoutId = constants.LOADOUTS.SU30_YJ91, num = 12 }, --YJ-91 X 4
    }
  },
  -- {
  --   name = "Rugao AB (PLAAF)",
  --   baseGUID = constants.BASES.RUGAO_AB,
  --   embarkedUnits = {
  --     {
  --       side = "China",
  --       type = "Air",
  --       dbid = constants.PLATFORMS.J16,
  --       name = "7th Air Bde",
  --       loadouts = {
  --         { loadoutId = constants.LOADOUTS.J16_AKD88, num = 12 },
  --         { loadoutId = constants.LOADOUTS.J16_YJ91,  num = 12 },
  --       }
  --     }
  --   },
  --   loadouts = {
  --     { loadoutId = constants.LOADOUTS.J16_AKD88, num = 12 }, --AKD-88 X 4
  --     { loadoutId = constants.LOADOUTS.J16_YJ91,  num = 12 }, --YJ-91 X 4
  --   }
  -- },
  {
    name = "Nanchang Xiangtang AB (PLAAF)",
    baseGUID = constants.BASES.XIAHGTANG_AB,
    embarkedUnits = {
      {
        side = "China",
        type = "Air",
        dbid = constants.PLATFORMS.J16D,
        platformName = "J-16D",
        name = "40th Air Bde",
        loadouts = {
          { name = "Electronic Warfare", loadoutId = constants.LOADOUTS.J16D_OECM, num = 8 },
        }
      }
    },
    loadouts = {
      { name = "Electronic Warfare", loadoutId = constants.LOADOUTS.J16D_OECM, num = 8 },
    }
  },
  -- {
  --   name = "Wuyishan AB",
  --   baseGUID = constants.BASES.WUYISHAN_AB,
  --   embarkedUnits = {
  --     {
  --       side = "China",
  --       type = "Air",
  --       dbid = constants.PLATFORMS.J20,
  --       name = "41st Air Bde",
  --       loadouts = {
  --         { loadoutId = constants.LOADOUTS.J20_PL15, num = 12 },
  --       }
  --     }
  --   },
  --   loadouts = {
  --     { loadoutId = constants.LOADOUTS.J20_PL15, num = 12 }, --PL-15 X 4
  --   }
  -- },
  {
    name = "Jiaxing AB (PLAAF)",
    baseGUID = constants.BASES.JIAXING_AB,
    embarkedUnits = {
      {
        side = "China",
        type = "Air",
        dbid = constants.PLATFORMS.J16,
        platformName = "J-16",
        name = "78th Air Bde",
        loadouts = {
          { name = "AKD-88 Strike", loadoutId = constants.LOADOUTS.J16_AKD88, num = 12 },
        }
      }
    },
    loadouts = {
      { name = "AKD-88 Strike", loadoutId = constants.LOADOUTS.J16_AKD88, num = 12 }, --AKD-88 X 4
    }
  },
}


-- ============================================================================
-- Amphibious Operations (China)
-- ============================================================================

config.c.PHIBOP = {}
config.c.PHIBOP.periodOfTime = 5 * 60
config.c.PHIBOP.cargoList = {
  type075 = {
    { type = 2, num = 21, dbid = constants.PLATFORMS.PLL05 }, -- PLL-05 11
    { type = 2, num = 12, dbid = constants.PLATFORMS.PLZ96 }, -- PLZ-96 12
    { type = 3, num = 3,  dbid = constants.PLATFORMS.PGZ09 }, -- PGZ-09 3
    { type = 3, num = 1,  dbid = constants.PLATFORMS.PGZ95 }, -- PGZ-95 1
    { type = 3, num = 30, dbid = constants.PLATFORMS.HMMWV }, -- HMMWV 30
    { type = 3, num = 76, dbid = constants.PLATFORMS.MC },    -- MC 76
  },
  type071 = {
    { type = 2, num = 5,  dbid = constants.PLATFORMS.PLL05 }, -- PLL-05 11
    { type = 2, num = 12, dbid = constants.PLATFORMS.PLZ96 }, -- PLZ-96 12
    { type = 3, num = 3,  dbid = constants.PLATFORMS.PGZ09 }, -- PGZ-09 3
    { type = 3, num = 1,  dbid = constants.PLATFORMS.PGZ95 }, -- PGZ-95 1
    { type = 3, num = 2,  dbid = constants.PLATFORMS.SA15 },  -- SA-15 2
    { type = 3, num = 22, dbid = constants.PLATFORMS.MC }     -- MC
  },
  type072iii = {
    { type = 2, num = 5, dbid = constants.PLATFORMS.ZBD05 }, -- ZBD-05
    { type = 2, num = 5, dbid = constants.PLATFORMS.ZTD05 }, -- ZTD-05
    { type = 3, num = 6, dbid = constants.PLATFORMS.MC }
  },
  type072a = {
    { type = 2, num = 5, dbid = constants.PLATFORMS.ZBD05 }, -- ZBD-05
    { type = 2, num = 5, dbid = constants.PLATFORMS.ZTD05 }, -- ZTD-05
    { type = 3, num = 6, dbid = constants.PLATFORMS.MC }
  },
  type073a = {
    { type = 2, num = 3, dbid = constants.PLATFORMS.ZBD05 },
    { type = 2, num = 3, dbid = constants.PLATFORMS.ZTD05 }, -- ZTD-05
  },
  ferry = {
    { type = 2, num = 56, dbid = constants.PLATFORMS.ZBD05 }, -- ZBD-05
    { type = 2, num = 56, dbid = constants.PLATFORMS.ZTD05 }, -- ZTD-05
  },
  barge = {
    { type = 2, num = 28, dbid = constants.PLATFORMS.ZBD04 },  -- ZBD-04
    { type = 2, num = 28, dbid = constants.PLATFORMS.ZTZ96A }, -- ZTZ-96A
    { type = 2, num = 9,  dbid = constants.PLATFORMS.PLL05 },  -- PLL-05
    { type = 3, num = 2,  dbid = constants.PLATFORMS.PGZ95 },  -- PGZ-95
    { type = 3, num = 1,  dbid = constants.PLATFORMS.PGZ09 },  -- PGZ-09
    { type = 2, num = 7,  dbid = constants.PLATFORMS.PLZ96 },  -- PLZ-07/PLZ-96
    { type = 3, num = 1,  dbid = constants.PLATFORMS.SA15 },   -- SA-15
    { type = 2, num = 4,  dbid = constants.PLATFORMS.M977 },   -- M977
  }
}
config.c.PHIBOP.cargoListForTransfer = {
  boat = {
    { type = 2, num = 1, dbid = constants.PLATFORMS.ZBD05 }, -- ZBD-05
    { type = 2, num = 1, dbid = constants.PLATFORMS.ZTD05 }, -- ZTD-05
  },
  assultLandingGroup = {
    { type = 2, num = 4, dbid = constants.PLATFORMS.PLL05 }, -- PLL-05
    -- Assault Landing Group
  },
  deepAssaultGroup1 = {
    { type = 2, num = 1, dbid = constants.PLATFORMS.PLZ96 }, -- PLZ-96
    { type = 3, num = 1, dbid = constants.PLATFORMS.PGZ09 }, -- PGZ-09
    -- Deep Assault Group
  },
  deepAssaultGroup2 = {
    { type = 2, num = 1, dbid = constants.PLATFORMS.PLZ96 }, -- PLZ-96
    { type = 3, num = 1, dbid = constants.PLATFORMS.PGZ95 }, -- PGZ-95
    -- Deep Assault Group
  },
  deepAssaultGroup3 = {
    { type = 3, num = 1, dbid = constants.PLATFORMS.SA15 }, -- SA-15
    -- Deep Assault Group
  },
  airAssaultGroup1 = {
    { type = 3, num = 2, dbid = constants.PLATFORMS.MC }, -- MC -- 075/071 Z-18
  },
  airAssaultGroup2 = {
    { type = 3, num = 1, dbid = constants.PLATFORMS.HMMWV }, -- HMMWV
  },
  airAssaultGroup3 = {
    { type = 2, num = 3, dbid = constants.PLATFORMS.ZBD03 }, -- II-76 ZBD-03
  },
}
config.c.PHIBOP.missionStartime = {
  transportHelicopter = { 42 * 60, 72 * 60, 92 * 60, 112 * 60 },
  attackHelicopter = { 40 * 60, },
  boat = { 41 * 60, 61 * 60, },
  reconUAV = { 0 }
}
config.c.PHIBOP.formationSettings = {
  distanceBetweenLSTAndLPDArea = 13,
  horizontalDistance = 0.4,
  verticalDistance = 0.4,
  transitDistance = 13,
  shipSpeed = 14,
  heading = {
    north = {
      horizontal  = 220 - 90,
      vertical    = 220,
      destination = {
        { latitude = "N 25.04.44", longitude = "E 121.13.54", },
      }
    },
    west = {
      horizontal = 150 - 90,
      vertical = 150,
      destination = {
        { latitude = "N 25.04.52", longitude = "E 121.10.05", },
        { latitude = "N 25.04.44", longitude = "E 121.13.54", },
      }
    },
    south = {
      horizontal = 45 - 90,
      vertical = 45,
      destination = {
        { latitude = "N 25.04.44", longitude = "E 121.13.54", },
      }
    },
    penghu = {
      horizontal = 82 - 90,
      vertical = 82,
      destination = {
        { latitude = "N 23.31.00", longitude = "E 119.33.54", },
        { latitude = "N 23.31.35", longitude = "E 119.35.36", },
        { latitude = "N 23.34.09", longitude = "E 119.37.41", },
      }
    },
    sishu = {
      horizontal = 73 - 90,
      vertical = 73,
      destination = {
        { latitude = "N 22.56.39", longitude = "E 120.10.37", },
        { latitude = "N 22.57.14", longitude = "E 120.12.09", },
      }
    },
  },
  ACVSpeed = 8,
  ACVTransitDistance = 5,
  ACVHorizontalDistance = 0.05,
}
config.c.PHIBOP.operations = {
  {
    name = "Taoyuan",
    names = {
      "Air Assault Bn",
      "Combined Arms Bn",
      "5th Landing Ship Div"
    },
    from = {
      areas = { {
        startingPoints = { type075 = { sideName = "China", area = constants.AREAS.STARTING_POINT_075_TAOYUAN } },
        heading = config.c.PHIBOP.formationSettings.heading.north
      } },
      stagingArea = constants.AREAS.AREA_OF_OPS_D,
      num = {
        type075 = 2,
        type071 = 4,
        type076 = 1,
        type072iii = 7,
        type072a = 8,
        type073a = 7,
        ferry = 4,
        roro = 2,
        barge = 1,
      }
    },
    to = {
      areas = {
        {
          startingPoints = {
            type075 = { sideName = "China", area = constants.AREAS.DESTINATION_075_TAOYUAN },
            type071 = { sideName = "China", area = constants.AREAS.DESTINATION_071_TAOYUAN },
          },
          heading = config.c.PHIBOP.formationSettings.heading.west,
          num = {
            type075 = 2,
            type071 = 4,
            type076 = 1,
            type072iii = 7,
            type072a = 8,
            type073a = 7,
            type071InLSTArea = 0,
            ferry = 4,
            roro = 2,
            barge = 1,
          }
        },
      }
    },
    airLandingZone = constants.AREAS.AIRLANDING_TAOYUAN,
    numOfContactsInAirLandingZone = 3
  },
  {
    name = "Sishu",
    names = {
      "Air Assault Bn",
      "Combined Arms Bn",
      "5th Landing Ship Div"
    },
    from = {
      areas = { {
        startingPoints = { type075 = { sideName = "China", area = constants.AREAS.STARTING_POINT_075_SISHU } },
        heading = config.c.PHIBOP.formationSettings.heading.sishu
      } },
      stagingArea = constants.AREAS.AREA_OF_OPS_F,
      num = {
        type075 = 1,
        type071 = 3,
        type076 = 0,
        type072iii = 2,
        type072a = 4,
        type073a = 2,
        type071InLSTArea = 0,
        ferry = 4,
        roro = 2,
        barge = 1,
      }
    },
    to = {
      areas = {
        {
          startingPoints = {
            type075 = { sideName = "China", area = constants.AREAS.DESTINATION_075_SISHU },
            type071 = { sideName = "China", area = constants.AREAS.DESTINATION_071_SISHU },
          },
          heading = config.c.PHIBOP.formationSettings.heading.sishu,
          num = {
            type075 = 1,
            type071 = 3,
            type076 = 0,
            type072iii = 2,
            type072a = 4,
            type073a = 2,
            type071InLSTArea = 0,
            ferry = 4,
            roro = 2,
            barge = 1,
          }
        },
      }
    },
    airLandingZone = constants.AREAS.AIRLANDING_TAOYUAN,
    numOfContactsInAirLandingZone = 3
  },
  {
    name = "Penghu",
    names = {
      "Air Assault Bn",
      "Combined Arms Bn",
      "5th Landing Ship Div"
    },
    from = {
      areas = { {
        startingPoints = { type075 = { sideName = "China", area = constants.AREAS.STARTING_POINT_075_PENGHU } },
        heading = config.c.PHIBOP.formationSettings.heading.penghu
      } },
      stagingArea = constants.AREAS.AREA_OF_OPS_E,
      num = {
        type075 = 1,
        type071 = 1,
        type076 = 0,
        type072iii = 2,
        type072a = 3,
        type073a = 1,
        type071InLSTArea = 0,
        ferry = 0,
        roro = 0,
        barge = 0,
      }
    },
    to = {
      areas = {
        {
          startingPoints = {
            type075 = { sideName = "China", area = constants.AREAS.DESTINATION_075_PENGHU },
            type071 = { sideName = "China", area = constants.AREAS.DESTINATION_071_PENGHU },
          },
          heading = config.c.PHIBOP.formationSettings.heading.penghu,
          num = {
            type075 = 1,
            type071 = 1,
            type076 = 0,
            type072iii = 2,
            type072a = 3,
            type073a = 1,
            type071InLSTArea = 0,
            ferry = 0,
            roro = 0,
            barge = 0,
          }
        },
      }
    },
    airLandingZone = constants.AREAS.AIRLANDING_TAOYUAN,
    numOfContactsInAirLandingZone = 3
  },
}
config.c.PHIBOP.operationalZones = {
  {
    name = "Taoyuan",
    baseGUID = constants.BASES.PINGTAN_PORT,
    anchorageArea = constants.AREAS.ANCH_AREA_TAOYUAN,
    LSTAnchorageArea = constants.AREAS.LST_ANCH_AREA_TAOYUAN,
    area = constants.AREAS.CAS_E,
    offloadArea = constants.AREAS.OFFLOAD_AREA_TAOYUAN,
    boat = {
      dbid = constants.PLATFORMS.TYPE_726A,
      missions = {
        {
          name = "LANDING/TAO/1/1",
          loadoutId = 0,
          unitCount = 1,
          startTime = config.c.PHIBOP.missionStartime.boat[1],
        },
        {
          name = "LANDING/TAO/1/2",
          loadoutId = 0,
          unitCount = 3,
          startTime = config.c.PHIBOP.missionStartime.boat[2],
        },
      },
      zone = constants.AREAS.LANDING_TAOYUAN,
      settings = {
        Subtype = "delivery",
        TransitThrottleShip = "Full",
        StationThrottleShip = "Full",
        isactive = false
      },
      transferManifest = {
        type075 = {
          {
            loadoutId = 0,
            cargoItems = {
              config.c.PHIBOP.cargoListForTransfer.assultLandingGroup,
              config.c.PHIBOP.cargoListForTransfer.deepAssaultGroup1,
              config.c.PHIBOP.cargoListForTransfer.deepAssaultGroup2,
            }
          },
        },
        type071 = {
          {
            loadoutId = 0,
            cargoItems = {
              config.c.PHIBOP.cargoListForTransfer.assultLandingGroup,
              config.c.PHIBOP.cargoListForTransfer.deepAssaultGroup1,
              config.c.PHIBOP.cargoListForTransfer.deepAssaultGroup2,
              config.c.PHIBOP.cargoListForTransfer.deepAssaultGroup3,
            }
          },
        }
      },
    },
    transportHelicopter = {
      dbid = constants.PLATFORMS.Z18,
      missions = {
        {
          name = "AIRLANDING/TAO/1/1",
          loadoutId = constants.LOADOUTS.Z18_TRANSPORT_1,
          unitCount = 3,
          startTime = config.c.PHIBOP.missionStartime.transportHelicopter[1],
        },
        {
          name = "AIRLANDING/TAO/1/2",
          loadoutId = constants.LOADOUTS.Z18_TRANSPORT_1,
          unitCount = 3,
          startTime = config.c.PHIBOP.missionStartime.transportHelicopter[2],
        },
        {
          name = "AIRLANDING/TAO/2/1",
          loadoutId = constants.LOADOUTS.Z18_TRANSPORT_2,
          unitCount = 3,
          startTime = config.c.PHIBOP.missionStartime.transportHelicopter[3],
        },
        {
          name = "AIRLANDING/TAO/2/2",
          loadoutId = constants.LOADOUTS.Z18_TRANSPORT_2,
          unitCount = 3,
          startTime = config.c.PHIBOP.missionStartime.transportHelicopter[4],
        },
      },
      zone = constants.AREAS.AIRLANDING_TAOYUAN,
      settings = {
        Subtype = "delivery",
        TransitThrottleAircraft = "Military",
        TransitAltitudeAircraft = 304,
        StationThrottleAircraft = "Afterburner",
        StationAltitudeAircraft = 304,
        isactive = false
      },
      transferManifest = {
        type075 = {
          {
            loadoutId = constants.LOADOUTS.Z18_TRANSPORT_1,
            cargoItems = { config.c.PHIBOP.cargoListForTransfer.airAssaultGroup1 }
          },
          {
            loadoutId = constants.LOADOUTS.Z18_TRANSPORT_2,
            cargoItems = { config.c.PHIBOP.cargoListForTransfer.airAssaultGroup2 }
          },
        },
        type071 = {
          {
            loadoutId = constants.LOADOUTS.Z18_TRANSPORT_1,
            cargoItems = { config.c.PHIBOP.cargoListForTransfer.airAssaultGroup1 }
          },
        }
      },
    },
    attackHelicopter = {
      dbid = constants.PLATFORMS.Z10,
      missions = {
        {
          name = "CAS/E",
          loadoutId = constants.LOADOUTS.Z10_ATTACK,
          unitCount = 13,
          startTime = config.c.PHIBOP.missionStartime.attackHelicopter[1],
        },
      }
    },
    LSTSettings = {
      speed = config.c.PHIBOP.formationSettings.shipSpeed,
      course = {
        bearing = config.c.PHIBOP.formationSettings.heading.west.vertical,
        distance = config.c.PHIBOP.formationSettings.transitDistance
      }
    },
    ACV = {
      bearing = config.c.PHIBOP.formationSettings.heading.west.horizontal,
      distance = config.c.PHIBOP.formationSettings.ACVHorizontalDistance,
      speed = config.c.PHIBOP.formationSettings.ACVSpeed,
      destination = config.c.PHIBOP.formationSettings.heading.west.destination,
      area = constants.AREAS.AMPH_VEH_STAGING_AREA_TAOYUAN
    },
  },
  {
    name = "Sishu",
    baseGUID = constants.BASES.KWANG_CHOW_WAN_NB,
    anchorageArea = constants.AREAS.ANCH_AREA_SISHU,
    LSTAnchorageArea = constants.AREAS.LST_ANCH_AREA_SISHU,
    area = constants.AREAS.CAS_S,
    offloadArea = constants.AREAS.OFFLOAD_AREA_SISHU,
    boat = {
      dbid = constants.PLATFORMS.TYPE_726A,
      missions = {
        {
          name = "LANDING/SISHU/1/1",
          loadoutId = 0,
          unitCount = 1,
          startTime = config.c.PHIBOP.missionStartime.boat[1],
        },
        {
          name = "LANDING/SISHU/1/2",
          loadoutId = 0,
          unitCount = 3,
          startTime = config.c.PHIBOP.missionStartime.boat[2],
        },
      },
      zone = constants.AREAS.LANDING_SISHU,
      settings = {
        Subtype = "delivery",
        TransitThrottleShip = "Full",
        StationThrottleShip = "Full",
        isactive = false
      },
      transferManifest = {
        type075 = {
          {
            loadoutId = 0,
            cargoItems = {
              config.c.PHIBOP.cargoListForTransfer.assultLandingGroup,
              config.c.PHIBOP.cargoListForTransfer.deepAssaultGroup1,
              config.c.PHIBOP.cargoListForTransfer.deepAssaultGroup2,
            }
          },
        },
        type071 = {
          {
            loadoutId = 0,
            cargoItems = {
              config.c.PHIBOP.cargoListForTransfer.assultLandingGroup,
              config.c.PHIBOP.cargoListForTransfer.deepAssaultGroup1,
              config.c.PHIBOP.cargoListForTransfer.deepAssaultGroup2,
              config.c.PHIBOP.cargoListForTransfer.deepAssaultGroup3
            }
          },
        }
      },
    },
    transportHelicopter = {
      dbid = constants.PLATFORMS.Z18,
      missions = {
        {
          name = "AIRLANDING/CHANGLONG/1/1",
          loadoutId = constants.LOADOUTS.Z18_TRANSPORT_1,
          unitCount = 3,
          startTime = config.c.PHIBOP.missionStartime.transportHelicopter[1],
        },
        {
          name = "AIRLANDING/CHANGLONG/1/2",
          loadoutId = constants.LOADOUTS.Z18_TRANSPORT_1,
          unitCount = 3,
          startTime = config.c.PHIBOP.missionStartime.transportHelicopter[2],
        },
        {
          name = "AIRLANDING/CHANGLONG/2/1",
          loadoutId = constants.LOADOUTS.Z18_TRANSPORT_2,
          unitCount = 3,
          startTime = config.c.PHIBOP.missionStartime.transportHelicopter[3],
        },
        {
          name = "AIRLANDING/CHANGLONG/2/2",
          loadoutId = constants.LOADOUTS.Z18_TRANSPORT_2,
          unitCount = 3,
          startTime = config.c.PHIBOP.missionStartime.transportHelicopter[4],
        },
      },
      zone = constants.AREAS.AIRLANDING_CHANGLONG,
      settings = {
        Subtype = "delivery",
        TransitThrottleAircraft = "Military",
        TransitAltitudeAircraft = 304,
        StationThrottleAircraft = "Afterburner",
        StationAltitudeAircraft = 304,
        isactive = false
      },
      transferManifest = {
        type075 = {
          {
            loadoutId = constants.LOADOUTS.Z18_TRANSPORT_1,
            cargoItems = { config.c.PHIBOP.cargoListForTransfer.airAssaultGroup1 }
          },
          {
            loadoutId = constants.LOADOUTS.Z18_TRANSPORT_2,
            cargoItems = { config.c.PHIBOP.cargoListForTransfer.airAssaultGroup2 }
          },
        },
        type071 = {
          {
            loadoutId = constants.LOADOUTS.Z18_TRANSPORT_1,
            cargoItems = { config.c.PHIBOP.cargoListForTransfer.airAssaultGroup1 }
          },
        }
      },
    },
    attackHelicopter = {
      dbid = constants.PLATFORMS.Z10,
      missions = {
        {
          name = "CAS/S",
          loadoutId = constants.LOADOUTS.Z10_ATTACK,
          unitCount = 13,
          startTime = config.c.PHIBOP.missionStartime.attackHelicopter[1],
        },
      }
    },
    LSTSettings = {
      speed = config.c.PHIBOP.formationSettings.shipSpeed,
      course = {
        bearing = config.c.PHIBOP.formationSettings.heading.sishu.vertical,
        distance = config.c.PHIBOP.formationSettings.transitDistance
      }
    },
    ACV = {
      bearing = config.c.PHIBOP.formationSettings.heading.sishu.horizontal,
      distance = config.c.PHIBOP.formationSettings.ACVHorizontalDistance,
      speed = config.c.PHIBOP.formationSettings.ACVSpeed,
      destination = config.c.PHIBOP.formationSettings.heading.sishu.destination,
      area = constants.AREAS.AMPH_VEH_STAGING_AREA_SHISHU
    }
  },
  {
    name = "Penghu",
    baseGUID = constants.BASES.KWANG_CHOW_WAN_NB,
    anchorageArea = constants.AREAS.ANCH_AREA_PENGHU,
    LSTAnchorageArea = constants.AREAS.LST_ANCH_AREA_PENGHU,
    area = constants.AREAS.CAS_PENGHU,
    offloadArea = constants.AREAS.OFFLOAD_AREA_PENGHU,
    boat = {
      dbid = constants.PLATFORMS.TYPE_726A,
      missions = {
        {
          name = "LANDING/PENGHU/1/1",
          loadoutId = 0,
          unitCount = 1,
          startTime = config.c.PHIBOP.missionStartime.boat[1],
        },
        {
          name = "LANDING/PENGHU/1/2",
          loadoutId = 0,
          unitCount = 3,
          startTime = config.c.PHIBOP.missionStartime.boat[2],
        },
      },
      zone = constants.AREAS.LANDING_PENGHU,
      settings = {
        Subtype = "delivery",
        TransitThrottleShip = "Full",
        StationThrottleShip = "Full",
        isactive = false
      },
      transferManifest = {
        type075 = {
          {
            loadoutId = 0,
            cargoItems = {
              config.c.PHIBOP.cargoListForTransfer.assultLandingGroup,
              config.c.PHIBOP.cargoListForTransfer.deepAssaultGroup1,
              config.c.PHIBOP.cargoListForTransfer.deepAssaultGroup2,
            }
          },
        },
        type071 = {
          {
            loadoutId = 0,
            cargoItems = {
              config.c.PHIBOP.cargoListForTransfer.assultLandingGroup,
              config.c.PHIBOP.cargoListForTransfer.deepAssaultGroup1,
              config.c.PHIBOP.cargoListForTransfer.deepAssaultGroup2,
              config.c.PHIBOP.cargoListForTransfer.deepAssaultGroup3
            }
          },
        }
      },
    },
    transportHelicopter = {
      dbid = constants.PLATFORMS.Z18,
      missions = {
        {
          name = "AIRLANDING/PENGHU/1/1",
          loadoutId = constants.LOADOUTS.Z18_TRANSPORT_1,
          unitCount = 3,
          startTime = config.c.PHIBOP.missionStartime.transportHelicopter[1],
        },
        {
          name = "AIRLANDING/PENGHU/1/2",
          loadoutId = constants.LOADOUTS.Z18_TRANSPORT_1,
          unitCount = 3,
          startTime = config.c.PHIBOP.missionStartime.transportHelicopter[2],
        },
        {
          name = "AIRLANDING/PENGHU/2/1",
          loadoutId = constants.LOADOUTS.Z18_TRANSPORT_2,
          unitCount = 3,
          startTime = config.c.PHIBOP.missionStartime.transportHelicopter[3],
        },
        {
          name = "AIRLANDING/PENGHU/2/2",
          loadoutId = constants.LOADOUTS.Z18_TRANSPORT_2,
          unitCount = 3,
          startTime = config.c.PHIBOP.missionStartime.transportHelicopter[4],
        },
      },
      zone = constants.AREAS.AIRLANDING_PENGHU,
      settings = {
        Subtype = "delivery",
        TransitThrottleAircraft = "Military",
        TransitAltitudeAircraft = 304,
        StationThrottleAircraft = "Afterburner",
        StationAltitudeAircraft = 304,
        isactive = false
      },
      transferManifest = {
        type075 = {
          {
            loadoutId = constants.LOADOUTS.Z18_TRANSPORT_1,
            cargoItems = { config.c.PHIBOP.cargoListForTransfer.airAssaultGroup1 }
          },
          {
            loadoutId = constants.LOADOUTS.Z18_TRANSPORT_2,
            cargoItems = { config.c.PHIBOP.cargoListForTransfer.airAssaultGroup2 }
          },
        },
        type071 = {
          {
            loadoutId = constants.LOADOUTS.Z18_TRANSPORT_1,
            cargoItems = { config.c.PHIBOP.cargoListForTransfer.airAssaultGroup1 }
          },
        }
      },
    },
    attackHelicopter = {
      dbid = constants.PLATFORMS.Z10,
      missions = {
        {
          name = "CAS/PENGHU",
          loadoutId = constants.LOADOUTS.Z10_ATTACK,
          unitCount = 13,
          startTime = config.c.PHIBOP.missionStartime.attackHelicopter[1],
        },
      }
    },
    LSTSettings = {
      speed = config.c.PHIBOP.formationSettings.shipSpeed,
      course = {
        bearing = config.c.PHIBOP.formationSettings.heading.penghu.vertical,
        distance = config.c.PHIBOP.formationSettings.transitDistance
      }
    },
    ACV = {
      bearing = config.c.PHIBOP.formationSettings.heading.penghu.horizontal,
      distance = config.c.PHIBOP.formationSettings.ACVHorizontalDistance,
      speed = config.c.PHIBOP.formationSettings.ACVSpeed,
      destination = config.c.PHIBOP.formationSettings.heading.penghu.destination,
      area = constants.AREAS.AMPH_VEH_STAGING_AREA_PENGHU
    }
  },
}
config.c.PHIBOP.transportAircraft = {
  {
    name = "Zhangpu AAB",
    guid = constants.BASES.ZHANGPU_AAB,
    dbid = constants.PLATFORMS.IL76,
    missions = {
      {
        name = "AIRLANDING/PENGHU/2/2",
        loadoutId = constants.LOADOUTS.IL76_TRANSPORT,
        unitCount = 3,
        startTime = 0
      },
    },
    cargoItemsForTransfer = {
      {
        loadoutId = constants.LOADOUTS.IL76_TRANSPORT,
        cargoItems = { config.c.PHIBOP.cargoListForTransfer.airAssaultGroup3 }
      },
    }
  },
}
config.c.PHIBOP.sag = {
  ["SAG 173"] = {
    groupName = "SAG 173",
    unitList = {
      type054a = { dbid = constants.PLATFORMS.TYPE_054A, },
      type052d = { dbid = constants.PLATFORMS.TYPE_052D, }
    },
    from = {
      startingPoint = { latitude = "N 26.54.18", longitude = "E 121.31.38", },
      heading = 225
    },
    to = {
      anchorageArea = {
        { latitude = "N 25.17.39", longitude = "E 120.56.04", desiredSpeed = 14, },
        { latitude = "N 25.17.32", longitude = "E 120.56.07", desiredSpeed = 14, },
      },
      amphibiousVehicleStagingArea = {
        { latitude = "N 25.06.19", longitude = "E 121.04.15", desiredSpeed = 14, },
      },
      heading = config.c.PHIBOP.formationSettings.heading.west.vertical,
    },
    area = constants.AREAS.AIRLANDING_TAOYUAN
  },
  ["SAG 155"] = {
    groupName = "SAG 155",
    unitList = {
      type054a = { dbid = constants.PLATFORMS.TYPE_054A, },
      type052d = { dbid = constants.PLATFORMS.TYPE_052D, }
    },
    from = {
      startingPoint = { latitude = "N 26.13.13", longitude = "E 120.59.55", },
      heading = 225
    },
    to = {
      anchorageArea = {
        { latitude = "N 25.33.23", longitude = "E 120.54.45", desiredSpeed = 14, },
        { latitude = "N 25.21.00", longitude = "E 121.04.12", desiredSpeed = 14, },
      },
      amphibiousVehicleStagingArea = {
        { latitude = "N 25.08.29", longitude = "E 121.10.20", desiredSpeed = 14, },
      },
      heading = config.c.PHIBOP.formationSettings.heading.west.vertical,
    },
    area = constants.AREAS.AIRLANDING_TAOYUAN
  },
  ["SAG 167"] = {
    groupName = "SAG 167",
    unitList = {
      type054a = { dbid = constants.PLATFORMS.TYPE_054A, },
      type052d = { dbid = constants.PLATFORMS.TYPE_052D, }
    },
    from = {
      startingPoint = { latitude = "N 23.29.19", longitude = "E 118.04.37", },
      heading = config.c.PHIBOP.formationSettings.heading.penghu.vertical,
    },
    to = {
      anchorageArea = {
        { latitude = "N 23.32.46", longitude = "E 119.16.11", desiredSpeed = 14, },
      },
      amphibiousVehicleStagingArea = {
        { latitude = "N 23.32.34", longitude = "E 119.29.14", desiredSpeed = 14, },
      },
      heading = config.c.PHIBOP.formationSettings.heading.penghu.vertical,
    },
    area = constants.AREAS.AIRLANDING_PENGHU,
  },
  ["SAG 154"] = {
    groupName = "SAG 154",
    unitList = {
      type054a = { dbid = constants.PLATFORMS.TYPE_054A, },
      type052d = { dbid = constants.PLATFORMS.TYPE_052D, }
    },
    from = {
      startingPoint = { latitude = "N 22.32.59", longitude = "E 118.04.52", },
      heading = config.c.PHIBOP.formationSettings.heading.sishu.vertical,
    },
    to = {
      anchorageArea = {
        { latitude = "N 22.49.20", longitude = "E 119.55.57", desiredSpeed = 14, },
      },
      amphibiousVehicleStagingArea = {
        { latitude = "N 22.53.16", longitude = "E 120.07.39", desiredSpeed = 14, },
      },
      heading = config.c.PHIBOP.formationSettings.heading.sishu.vertical,
    },
    area = constants.AREAS.AIRLANDING_CHANGLONG,
  },
  ["SAG 175"] = {
    groupName = "SAG 175",
    unitList = {
      type054a = { dbid = constants.PLATFORMS.TYPE_054A, },
      type052d = { dbid = constants.PLATFORMS.TYPE_052D, }
    },
    from = {
      startingPoint = { latitude = "N 22.44.28", longitude = "E 118.01.16", },
      heading = config.c.PHIBOP.formationSettings.heading.sishu.vertical,
    },
    to = {
      anchorageArea = {
        { latitude = "N 22.55.20", longitude = "E 119.52.25", desiredSpeed = 14, },
      },
      amphibiousVehicleStagingArea = {
        { latitude = "N 22.58.52", longitude = "E 120.05.48", desiredSpeed = 14, },
      },
      heading = config.c.PHIBOP.formationSettings.heading.sishu.vertical,
    },
    area = constants.AREAS.AIRLANDING_CHANGLONG,
  },
}


-- ============================================================================
-- Land Attack Cruise Missiles - Surface Launch (China)
-- ============================================================================

config.c.surface = {}
config.c.surface.lacm = {}
config.c.surface.lacm.weaponDBID = constants.WEAPONS.YJ21
config.c.surface.lacm.csg = {
  groupName = "CSG",
  unitList = {
    type002 = {
      dbid = constants.PLATFORMS.TYPE_002,
      embarkedUnits = {
        {
          side = "China",
          type = "Air",
          dbid = constants.PLATFORMS.J15,
          platformName = "J-15",
          name = "2nd Carrier Air Wing",
          loadouts = {
            { loadoutId = constants.LOADOUTS.J15_YJ91,    num = 16 },
            { loadoutId = constants.LOADOUTS.J15_LS6_500, num = 24 },
          }
        },
        {
          side = "China",
          type = "Air",
          dbid = constants.PLATFORMS.Z18F_SEA_EAGLE,
          platformName = "Z-18F Sea Eagle",
          name = "10th Naval Air Bde",
          loadouts = {
            { loadoutId = constants.LOADOUTS.Z18F_CARRIER_ASW, num = 6, missionName = "ASW/CSG" },
          }
        },
        {
          side = "China",
          type = "Air",
          dbid = constants.PLATFORMS.Z18J,
          platformName = "Z-18J",
          name = "10th Naval Air Bde",
          loadouts = {
            { loadoutId = constants.LOADOUTS.Z18J_AEW, num = 3, missionName = "AEW/CSG" },
          }
        },
        {
          side = "China",
          type = "Air",
          dbid = constants.PLATFORMS.J15D,
          platformName = "J-15D",
          name = "2nd Carrier Air Wing",
          loadouts = {
            { loadoutId = constants.LOADOUTS.J15D_EW, num = 3, },
          }
        },
      },
      loadouts = {
        { loadoutId = constants.LOADOUTS.J15_LS6_500, num = 24, }, -- LS-6-500 X 4
        { loadoutId = constants.LOADOUTS.J15_YJ91,    num = 16, }, -- YJ-91 X 4
      }
    },
    type055 = {
      dbid = constants.PLATFORMS.TYPE_055,
      embarkedUnits = {
        {
          side = "China",
          type = "Air",
          dbid = constants.PLATFORMS.KA28,
          platformName = "Ka-28",
          name = "10th Naval Air Bde",
          loadouts = {
            { loadoutId = constants.LOADOUTS.KA28_ASW, num = 1, missionName = "ASW/CSG" },
          }
        },
      }
    },
    type054a = {
      dbid = constants.PLATFORMS.TYPE_054A,
      embarkedUnits = {
        {
          side = "China",
          type = "Air",
          dbid = constants.PLATFORMS.KA28,
          platformName = "Ka-28",
          name = "10th Naval Air Bde",
          loadouts = {
            { loadoutId = constants.LOADOUTS.KA28_ASW, num = 1, missionName = "ASW/CSG" },
          }
        },
      }
    },
    type901 = {
      dbid = constants.PLATFORMS.TYPE_901,
      embarkedUnits = {
        {
          side = "China",
          type = "Air",
          dbid = constants.PLATFORMS.Z18F_SEA_EAGLE,
          platformName = "Z-18F Sea Eagle",
          name = "10th Naval Air Bde",
          loadouts = {
            { loadoutId = constants.LOADOUTS.Z18F_CARRIER_ASW, num = 1, missionName = "ASW/CSG" },
          }
        },
      }
    },
  },
  from = {
    startingPoint = { latitude = "N 21.09.59", longitude = "E 120.48.05", },
    heading = 83
  },
  to = {
    area = {
      { latitude = "N 21.14.11", longitude = "E 121.34.36", },
      { latitude = "N 21.32.59", longitude = "E 122.12.58", },
    },
    -- heading = CONFIG.c.PHIBOP.shipInfo.heading.west.vertical,
  },
}
config.c.surface.lacm.targetlist = {
  "6Z8LM5-0HMIJ7B89BC71",
  "6Z8LM5-0HMIJ7B89BC73",
  "6Z8LM5-0HMIJ7B89BC6V",
}


-- ============================================================================
-- Submarine-Launched Cruise Missiles (China)
-- ============================================================================

config.c.subSurface = {}
config.c.subSurface.slcm = {}
config.c.subSurface.slcm.weaponDBID = constants.WEAPONS.CJ10_SLCM
config.c.subSurface.slcm.submarines = {
  ["407"] = {
    name = "407",
    guid = "",
    course = {
      { latitude = "N 25.07.57", longitude = "E 122.46.06", presetDepth = 3 },
      { latitude = "N 24.33.33", longitude = "E 122.05.57", presetDepth = 3 },
      { latitude = "N 24.30.54", longitude = "E 122.48.02", presetDepth = 3 },
    },
    from = {
      startingPoint = { latitude = "N 25.05.32", longitude = "E 122.11.39" },
      heading = 180
    },
    weaponDBID = config.c.subSurface.slcm.weaponDBID
  },
  ["408"] = {
    name = "408",
    guid = "",
    course = {
      { latitude = "N 25.11.06", longitude = "E 122.42.15", presetDepth = 3 },
      { latitude = "N 24.33.33", longitude = "E 122.08.38", presetDepth = 3 },
      { latitude = "N 25.09.37", longitude = "E 122.06.45", presetDepth = 3 },
    },
    from = {
      startingPoint = { latitude = "N 24.32.30", longitude = "E 122.47.45", },
      heading = 270
    },
    weaponDBID = config.c.subSurface.slcm.weaponDBID
  },
  ["409"] = {
    name = "409",
    guid = "",
    course = {
      { latitude = 23.1405738004732, longitude = 122.453896349795, presetDepth = 3 },
      { latitude = 24.3097078500905, longitude = 122.142301456749, presetDepth = 3 },
      { latitude = 23.3573584800694, longitude = 121.777514450334, presetDepth = 3 }
    },
    from = {
      startingPoint = { latitude = "N 23.29.41", longitude = "E 122.39.12", },
      heading = 180
    },
    weaponDBID = config.c.subSurface.slcm.weaponDBID
  },
  ["410"] = {
    name = "410",
    guid = "",
    course = {
      { latitude = 24.2344610141018, longitude = 122.681795983267, presetDepth = 3 },
      { latitude = 23.4458260682078, longitude = 121.855392759008, presetDepth = 3 },
      { latitude = 24.280771111992,  longitude = 121.981212557257, presetDepth = 3 }
    },
    from = {
      startingPoint = { latitude = "N 22.41.17", longitude = "E 122.01.36", },
      heading = 30
    },
    weaponDBID = config.c.subSurface.slcm.weaponDBID
  },
}
config.c.subSurface.slcm.targetlist = {
  "6Z8LM5-0HMIJ7B89BCF3",
  "6Z8LM5-0HMIJ7B89BCF4",
  "6Z8LM5-0HMIJ7B89BCF5",
}
config.c.subSurface.slcm.randomRadius = 20


-- ============================================================================
-- Runway Repair Configuration
-- ============================================================================

config.repairRunway = {
  percentagePerHour = 3,
  runwayDBIDs = { 55, 43, 757, 1422, 1424, 1423, 1421 },
  airBases = {
    "Hualien AB",
    "Taitung/Jhihhang AB",
    "Ching Chuang Kang AB",
    "Chiayi AB",
    "Tainan AB",
    "Pingtung South AB",
    "Pingtung North AB",
    "Magong AB",
    "Hsinchu AB",
    "Jiashan AB",
    "Guiren AAB",
    "Longtan AAB",
    "Gangshan AB",
    "Taipei Songshan Airport",
    "Taoyuan International Airport",
  },
  runwaySubTypes = { "Runway %(%d+m%)", "Taxiway" }
}


-- ============================================================================
-- Fire Support Task Templates (China)
-- ============================================================================

config.c.FSTTemplate = {
  STRIKE_INFRASTRUCTURE_1 = {
    {
      name = "RADAR",
      wpnSystem = "SRBM",
      firingUnits = {
        { name = "614th Bde, PLARF", guid = "X58F5H-0HN1LQGRV8HNQ", weaponDBID = constants.WEAPONS.DF11A },
        { name = "613rd Bde, PLARF", guid = "X58F5H-0HN1G2DEBC7O8", weaponDBID = constants.WEAPONS.DF15B }
      },
      target = {
        list = {},
        objs = {
          { baseName = nil, subTypes = { "Radar", "Hengshan ROC command", "Sky Bow" } },
        },
        areas = {},
        filterNames = nil,
        contactAge = config.c.ground.srbm.contactAge,
        minTargetCount = 4,
        ammoPerTarget = 3
      },
    },
    {
      name = "RUNWAY",
      wpnSystem = "SRBM",
      firingUnits = {
        { name = "636th Bde, PLARF", guid = "IC8B0X-0HN822OHANPB3", weaponDBID = constants.WEAPONS.DF16A },
        { name = "617th Bde, PLARF", guid = "IC8B0X-0HN822OHANRHI", weaponDBID = constants.WEAPONS.DF16A }
      },
      target = {
        list = {},
        objs = {
          { baseName = "Hualien AB",           subTypes = { "Runway %(%d+m%)", "Taxiway" } },
          { baseName = "Taitung/Jhihhang AB",  subTypes = { "Runway %(%d+m%)", "Taxiway" } },
          { baseName = "Ching Chuang Kang AB", subTypes = { "Runway %(%d+m%)", "Taxiway" } },
          { baseName = "Chiayi AB",            subTypes = { "Runway %(%d+m%)", "Taxiway" } },
          { baseName = "Tainan AB",            subTypes = { "Runway %(%d+m%)", "Taxiway" } },
          { baseName = "Pingtung South AB",    subTypes = { "Runway %(%d+m%)", "Taxiway" } },
          { baseName = "Pingtung North AB",    subTypes = { "Runway %(%d+m%)", "Taxiway" } },
          { baseName = "Magong AB",            subTypes = { "Runway %(%d+m%)", "Taxiway" } },
          { baseName = "Hsinchu AB",           subTypes = { "Runway %(%d+m%)", "Taxiway" } },
        },
        areas = {},
        filterNames = nil,
        contactAge = config.c.ground.srbm.contactAge,
        minTargetCount = 4,
        ammoPerTarget = 4
      },
    },
    {
      name = "PORT",
      wpnSystem = "SRBM",
      firingUnits = {
        { name = "615th Bde, PLARF", guid = "X58F5H-0HN1G2IFLNKG9", weaponDBID = constants.WEAPONS.DF11A }
      },
      target = {
        list = {},
        objs = {
          { baseName = "Port of Keelung", subTypes = { "Pier" } },
          { baseName = "Suao Port",       subTypes = { "Pier" } },
          { baseName = "Kaohsiung Port",  subTypes = { "Pier" } },
          { baseName = "Magong Port",     subTypes = { "Pier" } },
          { baseName = nil,               subTypes = { "ASM" } },
        },
        areas = {},
        filterNames = nil,
        contactAge = config.c.ground.srbm.contactAge,
        minTargetCount = 4,
        ammoPerTarget = 2
      },
    },
    {
      name = "SHELTER",
      wpnSystem = "SRBM",
      firingUnits = {
        { name = "616th Bde, PLARF", guid = "X58F5H-0HN1G2IFLF6QE", weaponDBID = constants.WEAPONS.DF15C }
      },
      target = {
        list = {},
        objs = {
          { baseName = "Chiayi AB",            subTypes = { "Shelter", "Tarmac", "Hangar" } },
          { baseName = "Pingtung South AB",    subTypes = { "Shelter", "Tarmac", "Hangar" } },
          { baseName = "Ching Chuang Kang AB", subTypes = { "Shelter", "Tarmac", "Hangar" } },
          { baseName = "Magong AB",            subTypes = { "Shelter", "Tarmac", "Hangar" } },
        },
        areas = {},
        filterNames = nil,
        contactAge = config.c.ground.srbm.contactAge,
        minTargetCount = 4,
        ammoPerTarget = 2
      },
    },
  },
  STRIKE_INFRASTRUCTURE_2 = {
    {
      name = "RADAR",
      wpnSystem = "SRBM",
      firingUnits = {
        { name = "614th Bde, PLARF", guid = "X58F5H-0HN1LQGRV8HNQ", weaponDBID = constants.WEAPONS.DF11A },
        { name = "613rd Bde, PLARF", guid = "X58F5H-0HN1G2DEBC7O8", weaponDBID = constants.WEAPONS.DF15B }
      },
      target = {
        list = {},
        objs = {
          { baseName = nil, subTypes = { "Radar", "Hengshan ROC command", "Sky Bow" } },
        },
        areas = {},
        filterNames = nil,
        contactAge = config.c.ground.srbm.contactAge,
        minTargetCount = 1,
        ammoPerTarget = 3
      },
    },
    {
      name = "RUNWAY",
      wpnSystem = "SRBM",
      firingUnits = {
        { name = "636th Bde, PLARF", guid = "IC8B0X-0HN822OHANPB3", weaponDBID = constants.WEAPONS.DF16A },
        { name = "617th Bde, PLARF", guid = "IC8B0X-0HN822OHANRHI", weaponDBID = constants.WEAPONS.DF16A }
      },
      target = {
        list = {},
        objs = {
          { baseName = "Hualien AB",              subTypes = { "Runway %(%d+m%)", "Taxiway" } },
          { baseName = "Taitung/Jhihhang AB",     subTypes = { "Runway %(%d+m%)", "Taxiway" } },
          { baseName = "Ching Chuang Kang AB",    subTypes = { "Runway %(%d+m%)", "Taxiway" } },
          { baseName = "Chiayi AB",               subTypes = { "Runway %(%d+m%)", "Taxiway" } },
          { baseName = "Tainan AB",               subTypes = { "Runway %(%d+m%)", "Taxiway" } },
          { baseName = "Pingtung South AB",       subTypes = { "Runway %(%d+m%)", "Taxiway" } },
          { baseName = "Pingtung North AB",       subTypes = { "Runway %(%d+m%)", "Taxiway" } },
          { baseName = "Magong AB",               subTypes = { "Runway %(%d+m%)", "Taxiway" } },
          { baseName = "Hsinchu AB",              subTypes = { "Runway %(%d+m%)", "Taxiway" } },
          { baseName = "Taitung/Jhihhang AB",     subTypes = { "Runway %(%d+m%)", "Taxiway" } },
          { baseName = "Guiren AAB",              subTypes = { "Runway %(%d+m%)", "Taxiway" } },
          { baseName = "Longtan AAB",             subTypes = { "Runway %(%d+m%)", "Taxiway" } },
          { baseName = "Gangshan AB",             subTypes = { "Runway %(%d+m%)", "Taxiway" } },
          { baseName = "Taipei Songshan Airport", subTypes = { "Runway %(%d+m%)", "Taxiway" } },
        },
        areas = {},
        filterNames = nil,
        contactAge = config.c.ground.srbm.contactAge,
        minTargetCount = 1,
        ammoPerTarget = 4
      },
    },
    {
      name = "PORT",
      wpnSystem = "SRBM",
      firingUnits = {
        { name = "615th Bde, PLARF", guid = "X58F5H-0HN1G2IFLNKG9", weaponDBID = constants.WEAPONS.DF11A }
      },
      target = {
        list = {},
        objs = {
          { baseName = "Port of Keelung",          subTypes = { "Pier" } },
          { baseName = "Suao Port",                subTypes = { "Pier" } },
          { baseName = "Kaohsiung Port",           subTypes = { "Pier" } },
          { baseName = "Magong Port",              subTypes = { "Pier" } },
          { baseName = "HuangGang Fishing Harbor", subTypes = { "Terminal" } },
          { baseName = "Donggang Wharf",           subTypes = { "Terminal" } },
          { baseName = nil,                        subTypes = { "ASM" } },
        },
        areas = {},
        filterNames = nil,
        contactAge = config.c.ground.srbm.contactAge,
        minTargetCount = 1,
        ammoPerTarget = 2
      },
    },
    {
      name = "SHELTER",
      wpnSystem = "SRBM",
      firingUnits = {
        { name = "616th Bde, PLARF", guid = "X58F5H-0HN1G2IFLF6QE", weaponDBID = constants.WEAPONS.DF15C }
      },
      target = {
        list = {},
        objs = {
          { baseName = "Chiayi AB",            subTypes = { "Shelter", "Tarmac", "Hangar" } },
          { baseName = "Pingtung South AB",    subTypes = { "Shelter", "Tarmac", "Hangar" } },
          { baseName = "Ching Chuang Kang AB", subTypes = { "Shelter", "Tarmac", "Hangar" } },
          { baseName = "Magong AB",            subTypes = { "Shelter", "Tarmac", "Hangar" } },
          { baseName = "Pingtung North AB",    subTypes = { "Shelter", "Tarmac", "Hangar" } },
          { baseName = "Hsinchu AB",           subTypes = { "Shelter", "Tarmac", "Hangar" } },
          { baseName = "Gangshan AB",          subTypes = { "Shelter", "Tarmac", "Hangar" } },
          { baseName = "Tainan AB",            subTypes = { "Shelter", "Tarmac", "Hangar" } },
        },
        areas = {},
        filterNames = nil,
        contactAge = config.c.ground.srbm.contactAge,
        minTargetCount = 1,
        ammoPerTarget = 2
      },
    },
  },
  ANTISHIP_1 = {
    {
      name = "ANTISHIP",
      wpnSystem = "MRBM",
      firingUnits = {
        { name = "624th Bde, PLARF", guid = "IC8B0X-0HNCOR6HG2JE1", weaponDBID = constants.WEAPONS.DF21D }
      },
      target = {
        list = {},
        objs = {},
        areas = { constants.AREAS.AREA_OF_OPS_PACIFIC },
        filterNames = { "findNavalTargets" },
        contactAge = config.c.ground.mrbm.contactAge,
        minTargetCount = 1,
        ammoPerTarget = 6
      },
    }
  },
  STRIKE_C2_1 = {
    {
      name = "PINGTAN",
      wpnSystem = "MLRS",
      firingUnits = {
        { name = "1st Bn, 1st Rockets Arty Bde", guid = "IC8B0X-0HND05GGU36EN", weaponDBID = constants.WEAPONS.FD280 }
      },
      target = {
        list = {},
        objs = {},
        areas = { constants.AREAS.AREA_OF_OPS_NORTH },
        filterNames = { "analyzeEmissions", "findRadioDirection" },
        contactAge = config.c.ground.mlrs.contactAge,
        minTargetCount = 1,
        ammoPerTarget = 8
      },
    },
    {
      name = "CHINCHEW",
      wpnSystem = "MLRS",
      firingUnits = {
        { name = "6th Bn, 73rd Arty Bde", guid = "IC8B0X-0HNBRRE2PRQAL", weaponDBID = constants.WEAPONS.FD280 }
      },
      target = {
        list = {},
        objs = {},
        areas = { constants.AREAS.AREA_OF_OPS_CENTER },
        filterNames = { "analyzeEmissions", "findRadioDirection" },
        contactAge = config.c.ground.mlrs.contactAge,
        minTargetCount = 1,
        ammoPerTarget = 8
      },
    },
  },
  STRIKE_HELIPAD_1 = {
    {
      name = "HELIPAD",
      wpnSystem = "GLCM",
      firingUnits = {
        { name = "635th Bde, PLARF", guid = "6Z8LM5-0HMN97ERAUODK", weaponDBID = constants.WEAPONS.CJ10A }
      },
      target = {
        list = {},
        objs = {
          { baseName = "Guiren AAB",                       subTypes = { "Helipad" } },
          { baseName = "Longtan AAB",                      subTypes = { "Helipad" } },
          { baseName = "Minxiong Emergency Highway Strip", subTypes = { "Runway %(%d+m%)", "Taxiway" } },
          { baseName = "Madou Emergency Highway Strip",    subTypes = { "Runway %(%d+m%)", "Taxiway" } },
          { baseName = "Rende Emergency Highway Strip",    subTypes = { "Runway %(%d+m%)", "Taxiway" } },
        },
        areas = {},
        filterNames = nil,
        contactAge = config.c.ground.glcm.contactAge,
        minTargetCount = 1,
        ammoPerTarget = 4
      },
    },
  },
}


-- ============================================================================
-- Air Package Templates (China)
-- ============================================================================

config.c.packageTemplate = {
  STRIKE_AB_W_1 = {
    {
      timeToReady = config.readytime,
      striker = {
        baseGUID = constants.BASES.SHANTOU_WAISHA_AB,
        weaponDBID = constants.WEAPONS.AKD88,
        unitDBID = constants.PLATFORMS.J16,
        unitCount = 12,
        loadoutID = constants.LOADOUTS.J16_AKD88,
        -- startTime = "2027-06-09 01:25:00",
        missionCreationParams = { name = "STRIKE/AB/S/1", type = "strike", opts = { type = "land" } },
        emcon = "Radar=Passive;OECM=Active"
      },
      escort = {
        baseGUID = constants.BASES.HUIAN_AAB,
        weaponDBID = constants.WEAPONS.PL15,
        unitDBID = constants.PLATFORMS.J20,
        unitCount = 8,
        loadoutID = constants.LOADOUTS.J20_PL15,
        -- startTime = "2027-06-09 01:05:00",
        missionCreationParams = {
          name = "SWEEP/AB/S/1",
          type = "patrol",
          opts = {
            type = "aaw",
            OneThirdRule = false,
            FlightSize = 4,
            CheckOPAREA = false,
            CheckWWR = false,
            prosecutionZone = constants.AREAS.TARGET_AREA_SOUTH_PROSECUTION,
            patrolZone = constants.AREAS.TARGET_AREA_SOUTH_PATROL
          }
        },
        emcon = "Radar=Passive;OECM=Active"
      },
      wildWeasel = {
        baseGUID = constants.BASES.ZHANGZHOU_LONGXI_AB,
        weaponDBID = constants.WEAPONS.YJ91_ARM,
        unitDBID = constants.PLATFORMS.SU30,
        unitCount = 8,
        loadoutID = constants.LOADOUTS.SU30_YJ91,
        -- startTime = "2027-06-09 01:05:00",
        missionCreationParams = {
          name = "SEAD/AB/S/1",
          type = "patrol",
          opts = {
            type = "sead",
            OneThirdRule = false,
            FlightSize = 4,
            CheckOPAREA = false,
            CheckWWR = false,
            prosecutionZone = constants.AREAS.TARGET_AREA_SOUTH_PROSECUTION,
            patrolZone = constants.AREAS.TARGET_AREA_SOUTH_PATROL
          }
        },
        emcon = "Radar=Passive;OECM=Active"
      },
      jammer = {
        baseGUID = constants.BASES.ZHANGPU_AAB,
        unitDBID = constants.PLATFORMS.J16D,
        weaponDBID = 0,
        unitCount = 1,
        loadoutID = nil, -- Electronic warfare aircraft
        -- startTime = "2027-06-09 01:05:00", -- Escort launch time
        missionCreationParams = {
          name = "JAMMING/AB/S/1",
          type = "support",
          opts = { zone = constants.AREAS.TARGET_AREA_SOUTH_PATROL }
        },
        emcon = "Radar=Passive;OECM=Active"
      },
      tanker = nil,
      reconUAV = config.c.recon.template.BZK005_RECON_1,
      target = {
        list = {},
        objs = {
          { baseName = "Pingtung South AB", subTypes = { "Shelter", "Tarmac", "Hangar" } },
          { baseName = "Pingtung North AB", subTypes = { "Shelter", "Tarmac", "Hangar" } }
        },
        areas = { constants.AREAS.AREA_OF_OPS_SOUTH },
        filterNames = {},
        contactAge = 60 * 60,
        minTargetCount = 1
      },
    },
    {
      timeToReady = config.readytime,
      striker = {
        baseGUID = constants.BASES.SHANTOU_WAISHA_AB,
        weaponDBID = constants.WEAPONS.AKD88,
        unitDBID = constants.PLATFORMS.J16,
        unitCount = 12,
        loadoutID = constants.LOADOUTS.J16_AKD88,
        startTime = nil,
        missionCreationParams = { name = "STRIKE/AB/C", type = "strike", opts = { type = "land" } },
        emcon = "Radar=Passive;OECM=Active"
      },
      escort = {
        baseGUID = constants.BASES.HUIAN_AAB,
        weaponDBID = constants.WEAPONS.PL15,
        unitDBID = constants.PLATFORMS.J20,
        unitCount = 8,
        loadoutID = constants.LOADOUTS.J20_PL15,
        missionCreationParams = {
          name = "SWEEP/AB/C",
          type = "patrol",
          opts = {
            type = "aaw",
            OneThirdRule = false,
            FlightSize = 4,
            CheckOPAREA = false,
            CheckWWR = false,
            prosecutionZone = constants.AREAS.TARGET_AREA_CENTER_PROSECUTION,
            patrolZone = constants.AREAS.TARGET_AREA_CENTER_PATROL
          }
        },
        emcon = "Radar=Passive;OECM=Active"
      },
      wildWeasel = {
        baseGUID = constants.BASES.ZHANGZHOU_LONGXI_AB,
        weaponDBID = constants.WEAPONS.YJ91_ARM,
        unitDBID = constants.PLATFORMS.SU30,
        unitCount = 8,
        loadoutID = constants.LOADOUTS.SU30_YJ91,
        missionCreationParams = {
          name = "SEAD/AB/C",
          type = "patrol",
          opts = {
            type = "sead",
            OneThirdRule = false,
            FlightSize = 4,
            CheckOPAREA = false,
            CheckWWR = false,
            prosecutionZone = constants.AREAS.TARGET_AREA_CENTER_PROSECUTION,
            patrolZone = constants.AREAS.TARGET_AREA_CENTER_PATROL
          }
        },
        emcon = "Radar=Passive;OECM=Active"
      },
      jammer = {
        baseGUID = constants.BASES.ZHANGPU_AAB,
        unitDBID = constants.PLATFORMS.J16D,
        weaponDBID = 0,
        unitCount = 1,
        loadoutID = nil,
        missionCreationParams = {
          name = "JAMMING/AB/C",
          type = "support",
          opts = { zone = constants.AREAS.TARGET_AREA_CENTER_PATROL }
        },
        emcon = "Radar=Passive;OECM=Active"
      },
      tanker = nil,
      reconUAV = nil,
      target = {
        list = {},
        objs = {
          { baseName = "Ching Chuang Kang AB", subTypes = { "Shelter", "Ammo Bunker" } },
          { baseName = "Chiayi AB",            subTypes = { "Shelter", "Ammo Bunker" } }
        },
        areas = { constants.AREAS.AREA_OF_OPS_CENTER },
        filterNames = {},
        contactAge = 60 * 60,
        minTargetCount = 1
      },
    },
    {
      timeToReady = config.readytime,
      striker = {
        baseGUID = constants.BASES.HUIAN_AAB,
        weaponDBID = constants.WEAPONS.AKD88,
        unitDBID = constants.PLATFORMS.J16,
        unitCount = 12,
        loadoutID = constants.LOADOUTS.J16_AKD88,
        startTime = nil,
        missionCreationParams = { name = "STRIKE/AB/N/1", type = "strike", opts = { type = "land" } },
        emcon = "Radar=Passive;OECM=Active"
      },
      escort = {
        baseGUID = constants.BASES.HUIAN_AAB,
        weaponDBID = constants.WEAPONS.PL15,
        unitDBID = constants.PLATFORMS.J20,
        unitCount = 8,
        loadoutID = constants.LOADOUTS.J20_PL15,
        missionCreationParams = {
          name = "SWEEP/AB/N/1",
          type = "patrol",
          opts = {
            type = "aaw",
            OneThirdRule = false,
            FlightSize = 4,
            CheckOPAREA = false,
            CheckWWR = false,
            prosecutionZone = constants.AREAS.TARGET_AREA_NORTH_PROSECUTION,
            patrolZone = constants.AREAS.TARGET_AREA_NORTH_PATROL
          }
        },
        emcon = "Radar=Passive;OECM=Active"
      },
      wildWeasel = {
        baseGUID = constants.BASES.LONGTIAN_AAB,
        weaponDBID = constants.WEAPONS.YJ91_ARM,
        unitDBID = constants.PLATFORMS.SU30,
        unitCount = 8,
        loadoutID = constants.LOADOUTS.SU30_YJ91,
        missionCreationParams = {
          name = "SEAD/AB/N/1",
          type = "patrol",
          opts = {
            type = "sead",
            OneThirdRule = false,
            FlightSize = 4,
            CheckOPAREA = false,
            CheckWWR = false,
            prosecutionZone = constants.AREAS.TARGET_AREA_NORTH_PROSECUTION,
            patrolZone = constants.AREAS.TARGET_AREA_NORTH_PATROL
          }
        },
        emcon = "Radar=Passive;OECM=Active"
      },
      jammer = {
        baseGUID = constants.BASES.ZHANGPU_AAB,
        unitDBID = constants.PLATFORMS.J16D,
        weaponDBID = 0,
        unitCount = 1,
        loadoutID = nil,
        missionCreationParams = {
          name = "JAMMING/AB/N/1",
          type = "support",
          opts = { zone = constants.AREAS.TARGET_AREA_NORTH_PATROL }
        },
        emcon = "Radar=Passive;OECM=Active"
      },
      tanker = nil,
      reconUAV = nil,
      target = {
        list = {},
        objs = {
          { baseName = "Hsinchu AB", subTypes = { "Shelter", "Helipad", "Ammo Bunker" } }
        },
        areas = { constants.AREAS.AREA_OF_OPS_NORTH },
        filterNames = {},
        contactAge = 60 * 60,
        minTargetCount = 1
      },
    }
  },
  STRIKE_AB_W_2 = {
    {
      timeToReady = config.readytime,
      striker = {
        baseGUID = constants.BASES.XINGNING_AB,
        weaponDBID = constants.WEAPONS.YJ63,
        unitDBID = constants.PLATFORMS.H6K,
        unitCount = 12,
        loadoutID = constants.LOADOUTS.H6K_YJ63,
        -- startTime = "2027-06-09 04:40:00",
        startTime = nil,
        missionCreationParams = { name = "STRIKE/AB/S/2", type = "strike", opts = { type = "land" } },
        emcon = "Radar=Passive;OECM=Active"
      },
      escort = nil,
      wildWeasel = nil,
      jammer = nil,
      tanker = nil,
      reconUAV = nil,
      target = {
        list = {},
        objs = {
          { baseName = "Pingtung South AB", subTypes = { "Shelter", "Tarmac", "Hangar" } },
          { baseName = "Pingtung North AB", subTypes = { "Shelter", "Tarmac", "Hangar" } }
        },
        areas = { constants.AREAS.AREA_OF_OPS_SOUTH },
        filterNames = { "findC2" },
        contactAge = 60 * 60,
        minTargetCount = 1
      },
    },
    {
      timeToReady = config.readytime,
      striker = {
        baseGUID = constants.BASES.ANQING_AB,
        weaponDBID = constants.WEAPONS.YJ63,
        unitDBID = constants.PLATFORMS.H6K,
        unitCount = 12,
        loadoutID = constants.LOADOUTS.H6K_YJ63,
        startTime = nil,
        missionCreationParams = { name = "STRIKE/AB/N/2", type = "strike", opts = { type = "land" } },
        emcon = "Radar=Passive;OECM=Active"
      },
      escort = nil,
      wildWeasel = nil,
      jammer = nil,
      tanker = nil,
      reconUAV = nil,
      target = {
        list = {},
        objs = {
          { baseName = "Hsinchu AB", subTypes = { "Shelter", "Helipad", "Ammo Bunker" } }
        },
        areas = { constants.AREAS.AREA_OF_OPS_NORTH },
        filterNames = { "findC2" },
        contactAge = 60 * 60,
        minTargetCount = 1
      },
    }
  },
  STRIKE_AB_W_3 = {
    {
      timeToReady = config.readytime,
      striker = {
        baseGUID = constants.BASES.ZHANGPU_AAB,
        weaponDBID = constants.WEAPONS.KAB1500,
        unitDBID = constants.PLATFORMS.SU30,
        unitCount = 12,
        loadoutID = constants.LOADOUTS.SU30_KAB1500,
        -- startTime = "2027-06-09 05:40:00",
        missionCreationParams = { name = "STRIKE/AB/S/3", type = "strike", opts = { type = "land" } },
        emcon = "Radar=Passive;OECM=Active"
      },
      escort = {
        baseGUID = constants.BASES.HUIAN_AAB,
        weaponDBID = constants.WEAPONS.PL15,
        unitDBID = constants.PLATFORMS.J20,
        unitCount = 8,
        loadoutID = constants.LOADOUTS.J20_PL15,
        missionCreationParams = {
          name = "SWEEP/AB/S/2",
          type = "patrol",
          opts = {
            type = "aaw",
            OneThirdRule = false,
            FlightSize = 4,
            CheckOPAREA = false,
            CheckWWR = false,
            prosecutionZone = constants.AREAS.TARGET_AREA_SOUTH_PROSECUTION,
            patrolZone = constants.AREAS.TARGET_AREA_SOUTH_PATROL
          }
        },
        emcon = "Radar=Passive;OECM=Active"
      },
      wildWeasel = {
        baseGUID = constants.BASES.ZHANGZHOU_LONGXI_AB,
        weaponDBID = constants.WEAPONS.YJ91_ARM,
        unitDBID = constants.PLATFORMS.SU30,
        unitCount = 8,
        loadoutID = constants.LOADOUTS.SU30_YJ91,
        missionCreationParams = {
          name = "SEAD/AB/S/3",
          type = "patrol",
          opts = {
            type = "sead",
            OneThirdRule = false,
            FlightSize = 4,
            CheckOPAREA = false,
            CheckWWR = false,
            prosecutionZone = constants.AREAS.TARGET_AREA_SOUTH_PROSECUTION,
            patrolZone = constants.AREAS.TARGET_AREA_SOUTH_PATROL
          }
        },
        emcon = "Radar=Passive;OECM=Active"
      },
      jammer = {
        baseGUID = constants.BASES.ZHANGPU_AAB,
        unitDBID = constants.PLATFORMS.J16D,
        weaponDBID = 0,
        unitCount = 1,
        loadoutID = nil,
        missionCreationParams = {
          name = "JAMMING/AB/S/3",
          type = "support",
          opts = { zone = constants.AREAS.TARGET_AREA_SOUTH_PATROL }
        },
        emcon = "Radar=Passive;OECM=Active"
      },
      tanker = nil,
      reconUAV = nil,
      target = {
        list = {},
        objs = {
          { baseName = "Pingtung South AB", subTypes = { "Ammo Bunker" } },
          { baseName = "Tainan AB",         subTypes = { "Ammo Bunker" } },
          { baseName = "Magong AB",         subTypes = { "Ammo Bunker" } }
        },
        areas = { constants.AREAS.AREA_OF_OPS_SOUTH },
        filterNames = { "findC2" },
        contactAge = 60 * 60,
        minTargetCount = 1
      },
    }
  },
  STRIKE_AB_W_AAR_1 = {
    {
      timeToReady = config.readytime,
      striker = {
        baseGUID = constants.BASES.JIAXING_AB,
        weaponDBID = constants.WEAPONS.AKD88,
        unitDBID = constants.PLATFORMS.J16,
        unitCount = 12,
        loadoutID = constants.LOADOUTS.J16_AKD88,
        startTime = nil,
        missionCreationParams = {
          name = "STRIKE/AB/N/1",
          type = "strike",
          opts = {
            type = "land",
            -- TankerUsage = 1,
            -- TankerMissionList = { "AAR/E" },
            -- FuelQtyToStartLookingForTanker_airborne = 85,
            -- MaxReceiversInQueuePerTanker_airborne = 1,
            -- LaunchMissionWithoutTankersInPlace = true,
            -- TankerMaxDistance_airborne = 50
          }
        },
        emcon = "Radar=Passive;OECM=Active"
      },
      escort = {
        baseGUID = constants.BASES.WUHU_AB,
        weaponDBID = constants.WEAPONS.PL15,
        unitDBID = constants.PLATFORMS.J20,
        unitCount = 4,
        loadoutID = constants.LOADOUTS.J20_PL15,
        missionCreationParams = {
          name = "SWEEP/AB/N/1",
          type = "patrol",
          opts = {
            type = "aaw",
            OneThirdRule = false,
            FlightSize = 4,
            CheckOPAREA = false,
            CheckWWR = false,
            prosecutionZone = constants.AREAS.TARGET_AREA_NORTH_PROSECUTION,
            patrolZone = constants.AREAS.TARGET_AREA_NORTH_PATROL,
            TankerUsage = 1,
            TankerMissionList = { "AAR/E" },
            FuelQtyToStartLookingForTanker_airborne = 85,
            MaxReceiversInQueuePerTanker_airborne = 1,
            LaunchMissionWithoutTankersInPlace = true,
            TankerMaxDistance_airborne = 50
          }
        },
        emcon = "Radar=Passive;OECM=Active"
      },
      wildWeasel = {
        baseGUID = constants.BASES.TAIZHOU_AB,
        weaponDBID = constants.WEAPONS.YJ91_ARM,
        unitDBID = constants.PLATFORMS.SU30,
        unitCount = 4,
        loadoutID = constants.LOADOUTS.SU30_YJ91,
        missionCreationParams = {
          name = "SEAD/AB/N/1",
          type = "patrol",
          opts = {
            type = "sead",
            OneThirdRule = false,
            FlightSize = 4,
            CheckOPAREA = false,
            CheckWWR = false,
            prosecutionZone = constants.AREAS.TARGET_AREA_NORTH_PROSECUTION,
            patrolZone = constants.AREAS.TARGET_AREA_NORTH_PATROL,
            TankerUsage = 1,
            TankerMissionList = { "AAR/E" },
            FuelQtyToStartLookingForTanker_airborne = 85,
            MaxReceiversInQueuePerTanker_airborne = 1,
            LaunchMissionWithoutTankersInPlace = true,
            TankerMaxDistance_airborne = 50
          }
        },
        emcon = "Radar=Passive;OECM=Active"
      },
      jammer = {
        baseGUID = constants.BASES.XIAHGTANG_AB,
        unitDBID = constants.PLATFORMS.J16D,
        weaponDBID = 0,
        unitCount = 1,
        loadoutID = nil,
        missionCreationParams = {
          name = "JAMMING/AB/N/1",
          type = "support",
          opts = {
            zone = constants.AREAS.TARGET_AREA_NORTH_PATROL,
            TankerUsage = 1,
            TankerMissionList = { "AAR/E" },
            FuelQtyToStartLookingForTanker_airborne = 85,
            MaxReceiversInQueuePerTanker_airborne = 1,
            LaunchMissionWithoutTankersInPlace = true,
            TankerMaxDistance_airborne = 50
          }
        },
        emcon = "Radar=Passive;OECM=Active"
      },
      tanker = {
        baseGUID = constants.BASES.SHUIMEN_AAB,
        unitDBID = constants.PLATFORMS.HY6U_BADGER,
        weaponDBID = 0,
        unitCount = 8,
        loadoutID = nil,
        missionCreationParams = {
          name = "AAR/E",
          type = "support",
          opts = {
            OneThirdRule = false,
            FlightSize = 2,
            zone = constants.AREAS.AAR_PATROL_2
          }
        },
        emcon = "Radar=Passive;OECM=Passive"
      },
      reconUAV = nil,
      target = {
        list = {},
        objs = {
          { baseName = "Hsinchu AB", subTypes = { "Shelter", "Helipad", "Ammo Bunker" } }
        },
        areas = { constants.AREAS.AREA_OF_OPS_NORTH },
        filterNames = {},
        contactAge = 60 * 60,
        minTargetCount = 1
      },
    },
    {
      timeToReady = config.readytime,
      striker = {
        baseGUID = constants.BASES.JIAXING_AB,
        weaponDBID = constants.WEAPONS.AKD88,
        unitDBID = constants.PLATFORMS.J16,
        unitCount = 12,
        loadoutID = constants.LOADOUTS.J16_AKD88,
        startTime = nil,
        missionCreationParams = {
          name = "STRIKE/AB/C/1",
          type = "strike",
          opts = {
            type = "land",
            TankerMissionList = { "AAR/C" },
            FuelQtyToStartLookingForTanker_airborne = 85,
            MaxReceiversInQueuePerTanker_airborne = 1,
            LaunchMissionWithoutTankersInPlace = true,
            TankerMaxDistance_airborne = 50
          }
        },
        emcon = "Radar=Passive;OECM=Active"
      },
      escort = {
        baseGUID = constants.BASES.WUHU_AB,
        weaponDBID = constants.WEAPONS.PL15,
        unitDBID = constants.PLATFORMS.J20,
        unitCount = 4,
        loadoutID = constants.LOADOUTS.J20_PL15,
        missionCreationParams = {
          name = "SWEEP/AB/C/1",
          type = "patrol",
          opts = {
            type = "aaw",
            OneThirdRule = false,
            FlightSize = 4,
            CheckOPAREA = false,
            CheckWWR = false,
            prosecutionZone = constants.AREAS.TARGET_AREA_CENTER_PROSECUTION,
            patrolZone = constants.AREAS.TARGET_AREA_CENTER_PATROL,
            TankerUsage = 1,
            TankerMissionList = { "AAR/C" },
            FuelQtyToStartLookingForTanker_airborne = 85,
            MaxReceiversInQueuePerTanker_airborne = 1,
            LaunchMissionWithoutTankersInPlace = true,
            TankerMaxDistance_airborne = 50
          }
        },
        emcon = "Radar=Passive;OECM=Active"
      },
      wildWeasel = {
        baseGUID = constants.BASES.TAIZHOU_AB,
        weaponDBID = constants.WEAPONS.YJ91_ARM,
        unitDBID = constants.PLATFORMS.SU30,
        unitCount = 4,
        loadoutID = constants.LOADOUTS.SU30_YJ91,
        missionCreationParams = {
          name = "SEAD/AB/C/1",
          type = "patrol",
          opts = {
            type = "sead",
            OneThirdRule = false,
            FlightSize = 4,
            CheckOPAREA = false,
            CheckWWR = false,
            prosecutionZone = constants.AREAS.TARGET_AREA_CENTER_PROSECUTION,
            patrolZone = constants.AREAS.TARGET_AREA_CENTER_PATROL,
            TankerUsage = 1,
            TankerMissionList = { "AAR/C" },
            FuelQtyToStartLookingForTanker_airborne = 85,
            MaxReceiversInQueuePerTanker_airborne = 1,
            LaunchMissionWithoutTankersInPlace = true,
            TankerMaxDistance_airborne = 60
          }
        },
        emcon = "Radar=Passive;OECM=Active"
      },
      jammer = {
        baseGUID = constants.BASES.XIAHGTANG_AB,
        unitDBID = constants.PLATFORMS.J16D,
        weaponDBID = 0,
        unitCount = 1,
        loadoutID = nil,
        missionCreationParams = {
          name = "JAMMING/AB/C/1",
          type = "support",
          opts = {
            zone = constants.AREAS.TARGET_AREA_CENTER_PATROL,
            TankerUsage = 1,
            TankerMissionList = { "AAR/C" },
            FuelQtyToStartLookingForTanker_airborne = 85,
            MaxReceiversInQueuePerTanker_airborne = 1,
            LaunchMissionWithoutTankersInPlace = true,
            TankerMaxDistance_airborne = 70
          }
        },
        emcon = "Radar=Passive;OECM=Active"
      },
      tanker = {
        baseGUID = constants.BASES.SHUIMEN_AAB,
        unitDBID = constants.PLATFORMS.HY6U_BADGER,
        weaponDBID = 0,
        unitCount = 8,
        loadoutID = nil,
        missionCreationParams = {
          name = "AAR/C",
          type = "support",
          opts = {
            OneThirdRule = false,
            FlightSize = 4,
            zone = constants.AREAS.AAR_PATROL
          }
        },
        emcon = "Radar=Passive;OECM=Passive"
      },
      reconUAV = nil,
      target = {
        list = {},
        objs = {
          { baseName = "Ching Chuang Kang AB", subTypes = { "Shelter", "Ammo Bunker" } },
          { baseName = "Chiayi AB",            subTypes = { "Shelter", "Ammo Bunker" } }
        },
        areas = { constants.AREAS.AREA_OF_OPS_CENTER },
        filterNames = {},
        contactAge = 60 * 60,
        minTargetCount = 1
      },
    },
    {
      timeToReady = config.readytime,
      striker = {
        baseGUID = constants.BASES.JIAXING_AB,
        weaponDBID = constants.WEAPONS.AKD88,
        unitDBID = constants.PLATFORMS.J16,
        unitCount = 12,
        loadoutID = constants.LOADOUTS.J16_AKD88,
        startTime = nil,
        missionCreationParams = {
          name = "STRIKE/AB/S/1",
          type = "strike",
          opts = {
            type = "land",
            TankerMissionList = { "AAR/S" },
            FuelQtyToStartLookingForTanker_airborne = 85,
            MaxReceiversInQueuePerTanker_airborne = 1,
            LaunchMissionWithoutTankersInPlace = true,
            TankerMaxDistance_airborne = 50
          }
        },
        emcon = "Radar=Passive;OECM=Active"
      },
      escort = {
        baseGUID = constants.BASES.WUHU_AB,
        weaponDBID = constants.WEAPONS.PL15,
        unitDBID = constants.PLATFORMS.J20,
        unitCount = 4,
        loadoutID = constants.LOADOUTS.J20_PL15,
        missionCreationParams = {
          name = "SWEEP/AB/S/1",
          type = "patrol",
          opts = {
            type = "aaw",
            OneThirdRule = false,
            FlightSize = 4,
            CheckOPAREA = false,
            CheckWWR = false,
            prosecutionZone = constants.AREAS.TARGET_AREA_SOUTH_PROSECUTION,
            patrolZone = constants.AREAS.TARGET_AREA_SOUTH_PATROL,
            TankerUsage = 1,
            TankerMissionList = { "AAR/S" },
            FuelQtyToStartLookingForTanker_airborne = 85,
            MaxReceiversInQueuePerTanker_airborne = 1,
            LaunchMissionWithoutTankersInPlace = true,
            TankerMaxDistance_airborne = 50
          }
        },
        emcon = "Radar=Passive;OECM=Active"
      },
      wildWeasel = {
        baseGUID = constants.BASES.TAIZHOU_AB,
        weaponDBID = constants.WEAPONS.YJ91_ARM,
        unitDBID = constants.PLATFORMS.SU30,
        unitCount = 4,
        loadoutID = constants.LOADOUTS.SU30_YJ91,
        missionCreationParams = {
          name = "SEAD/AB/S/1",
          type = "patrol",
          opts = {
            type = "sead",
            OneThirdRule = false,
            FlightSize = 4,
            CheckOPAREA = false,
            CheckWWR = false,
            prosecutionZone = constants.AREAS.TARGET_AREA_SOUTH_PROSECUTION,
            patrolZone = constants.AREAS.TARGET_AREA_SOUTH_PATROL,
            TankerUsage = 1,
            TankerMissionList = { "AAR/S" },
            FuelQtyToStartLookingForTanker_airborne = 85,
            MaxReceiversInQueuePerTanker_airborne = 1,
            LaunchMissionWithoutTankersInPlace = true,
            TankerMaxDistance_airborne = 60
          }
        },
        emcon = "Radar=Passive;OECM=Active"
      },
      jammer = {
        baseGUID = constants.BASES.XIAHGTANG_AB,
        unitDBID = constants.PLATFORMS.J16D,
        weaponDBID = 0,
        unitCount = 1,
        loadoutID = nil,
        missionCreationParams = {
          name = "JAMMING/AB/C/1",
          type = "support",
          opts = {
            zone = constants.AREAS.TARGET_AREA_SOUTH_PATROL,
            TankerUsage = 1,
            TankerMissionList = { "AAR/S" },
            FuelQtyToStartLookingForTanker_airborne = 85,
            MaxReceiversInQueuePerTanker_airborne = 1,
            LaunchMissionWithoutTankersInPlace = true,
            TankerMaxDistance_airborne = 50
          }
        },
        emcon = "Radar=Passive;OECM=Active"
      },
      tanker = {
        baseGUID = constants.BASES.SHUIMEN_AAB,
        unitDBID = constants.PLATFORMS.HY6U_BADGER,
        weaponDBID = 0,
        unitCount = 8,
        loadoutID = nil,
        missionCreationParams = {
          name = "AAR/S",
          type = "support",
          opts = {
            OneThirdRule = false,
            FlightSize = 4,
            zone = constants.AREAS.AAR_PATROL
          }
        },
        emcon = "Radar=Passive;OECM=Passive"
      },
      reconUAV = nil,
      target = {
        list = {},
        objs = {
          { baseName = "Pingtung South AB", subTypes = { "Shelter", "Tarmac", "Hangar" } },
          { baseName = "Pingtung North AB", subTypes = { "Shelter", "Tarmac", "Hangar" } }
        },
        areas = { constants.AREAS.AREA_OF_OPS_SOUTH },
        filterNames = {},
        contactAge = 60 * 60,
        minTargetCount = 1
      },
    }
  },
  AIR_INTERCEPT_E = {
    {
      timeToReady = config.readytime,
      striker = {
        baseGUID = constants.BASES.WUHU_AB,
        weaponDBID = constants.WEAPONS.PL15,
        unitDBID = constants.PLATFORMS.J20,
        unitCount = 6,
        loadoutID = constants.LOADOUTS.J20_PL15,
        -- startTime = "2027-06-09 06:40:00",
        -- startTime = "2027-06-09 01:05:00",
        missionCreationParams = {
          name = "AIR INTERCEPT/E",
          type = "strike",
          opts = {
            type = "aaw",
            TankerUsage = 1,
            TankerMissionList = { "AAR/E" },
            FuelQtyToStartLookingForTanker_airborne = 65,
            MaxReceiversInQueuePerTanker_airborne = 2,
            LaunchMissionWithoutTankersInPlace = true
          }
        },
        emcon = "Radar=Passive;OECM=Active"
      },
      escort = nil,
      wildWeasel = nil,
      jammer = nil,
      tanker = {
        baseGUID = constants.BASES.SHUIMEN_AAB,
        unitDBID = constants.PLATFORMS.HY6U_BADGER,
        weaponDBID = 0,
        unitCount = 3,
        loadoutID = nil,
        missionCreationParams = {
          name = "AAR/E",
          type = "support",
          opts = {
            OneThirdRule = false,
            FlightSize = 1,
            zone = constants.AREAS.AAR_PATROL
          }
        },
        emcon = "Radar=Passive;OECM=Passive"
      },
      reconUAV = nil,
      target = {
        list = {},
        objs = nil,
        areas = { constants.AREAS.AREA_OF_OPS_PACIFIC },
        filterNames = { "findAirborne" },
        contactAge = 60 * 60,
        minTargetCount = 1
      }
    }
  },
  STRIKE_AB_E_1 = {
    {
      timeToReady = config.readytime,
      striker = {
        baseGUID = "CSG",
        weaponDBID = constants.WEAPONS.LS_6_500,
        unitDBID = constants.PLATFORMS.J15,
        unitCount = 12,
        loadoutID = constants.LOADOUTS.J15_LS6_500,
        -- startTime = "2027-06-09 07:00:00",
        missionCreationParams = { name = "STRIKE/AB/JHI/1", type = "strike", opts = { type = "land" } },
        emcon = "Radar=Passive;OECM=Active"
      },
      escort = nil,
      -- escort = {
      --   baseGUID = "CSG",
      --   weaponDBID = constants.WEAPONS.PL15,
      --   unitDBID = constants.PLATFORMS.J_15,
      --   unitCount = 8,
      --   loadoutID = constants.LOADOUTS.J15_YJ91,
      --   missionCreationParams = {
      --     name = "SWEAP/AB/JHI/1",
      --     type = "patrol",
      --     opts = {
      --       type = "aaw",
      --       OneThirdRule = false,
      --       FlightSize = 4,
      --       CheckOPAREA = false,
      --       CheckWWR = false,
      --       prosecutionZone = constants.AREASs.TARGET_AREA_JHI_PROSECUTION,
      --       patrolZone = constants.AREASs.TARGET_AREA_JHI_PATROL
      --     }
      --   },
      --   emcon = "Radar=Passive;OECM=Active"
      -- },
      wildWeasel = {
        baseGUID = "CSG",
        weaponDBID = constants.WEAPONS.YJ91_ASM,
        unitDBID = constants.PLATFORMS.J15,
        unitCount = 8,
        loadoutID = constants.LOADOUTS.J15_YJ91,
        missionCreationParams = {
          name = "SEAD/AB/JHI/1",
          type = "patrol",
          opts = {
            type = "sead",
            OneThirdRule = false,
            FlightSize = 4,
            CheckOPAREA = false,
            CheckWWR = false,
            prosecutionZone = constants.AREAS.TARGET_AREA_JHI_PROSECUTION,
            patrolZone = constants.AREAS.TARGET_AREA_JHI_PATROL
          }
        },
        emcon = "Radar=Passive;OECM=Active"
      },
      jammer = {
        baseGUID = "CSG",
        unitDBID = constants.PLATFORMS.J15D,
        weaponDBID = 0,
        unitCount = 1,
        loadoutID = constants.LOADOUTS.J15D_EW,
        missionCreationParams = {
          name = "JAMMING/AB/JHI/1",
          type = "support",
          opts = { zone = constants.AREAS.TARGET_AREA_JHI_PATROL }
        },
        emcon = "Radar=Passive;OECM=Active"
      },
      tanker = nil,
      reconUAV = nil,
      target = {
        list = {},
        objs = {
          { baseName = "Jhihhang AB", subTypes = { "Shelter" } }
        },
        areas = { constants.AREAS.AREA_OF_OPS_EAST },
        filterNames = nil,
        contactAge = 60 * 60,
        minTargetCount = 1
      },
    },
    {
      timeToReady = config.readytime,
      striker = {
        baseGUID = "CSG",
        weaponDBID = constants.WEAPONS.LS_6_500,
        unitDBID = constants.PLATFORMS.J15,
        unitCount = 12,
        loadoutID = constants.LOADOUTS.J15_LS6_500,
        startTime = nil,
        missionCreationParams = { name = "STRIKE/AB/JIA/1", type = "strike", opts = { type = "land" } },
        emcon = "Radar=Passive;OECM=Active"
      },
      escort = nil,
      -- escort = {
      --   baseGUID = "6Z8LM5-0HMIJ3QGCRQ5F",
      --   weaponDBID = constants.WEAPONS.PL15,
      --   unitDBID = constants.PLATFORMS.J_15,
      --   unitCount = 8,
      --   loadoutID = constants.LOADOUTS.J20_PL15,
      --   missionCreationParams = {
      --     name = "SWEAP/AB/JIA/1",
      --     type = "patrol",
      --     opts = {
      --       type = "aaw",
      --       OneThirdRule = false,
      --       FlightSize = 4,
      --       CheckOPAREA = false,
      --       CheckWWR = false,
      --       prosecutionZone = constants.AREASs.TARGET_AREA_JIASHAN_PROSECUTION,
      --       patrolZone = constants.AREASs.TARGET_AREA_JIASHAN_PATROL
      --     }
      --   },
      --   emcon = "Radar=Passive;OECM=Active"
      -- },
      wildWeasel = {
        baseGUID = "CSG",
        weaponDBID = constants.WEAPONS.YJ91_ASM,
        unitDBID = constants.PLATFORMS.J15,
        unitCount = 8,
        loadoutID = constants.LOADOUTS.J15_YJ91,
        missionCreationParams = {
          name = "SEAD/AB/JIA/1",
          type = "patrol",
          opts = {
            type = "sead",
            OneThirdRule = false,
            FlightSize = 4,
            CheckOPAREA = false,
            CheckWWR = false,
            prosecutionZone = constants.AREAS.TARGET_AREA_JIASHAN_PROSECUTION,
            patrolZone = constants.AREAS.TARGET_AREA_JIASHAN_PATROL
          }
        },
        emcon = "Radar=Passive;OECM=Active"
      },
      jammer = {
        baseGUID = "CSG",
        unitDBID = constants.PLATFORMS.J15D,
        weaponDBID = 0,
        unitCount = 1,
        loadoutID = constants.LOADOUTS.J15D_EW,
        missionCreationParams = {
          name = "JAMMING/AB/JIA/1",
          type = "support",
          opts = { zone = constants.AREAS.TARGET_AREA_JIASHAN_PATROL }
        },
        emcon = "Radar=Passive;OECM=Active"
      },
      tanker = nil,
      reconUAV = nil,
      target = {
        list = {},
        objs = {
          { baseName = "Jiashan AB", subTypes = { "Shelter" } }
        },
        areas = { constants.AREAS.AREA_OF_OPS_EAST },
        filterNames = nil,
        contactAge = 60 * 60,
        minTargetCount = 1
      },
    }
  },
  ASUW_N_1 = {
    {
      timeToReady = config.readytime,
      striker = {
        baseGUID = constants.BASES.SHUIMEN_AAB,
        weaponDBID = constants.WEAPONS.YJ83,
        unitDBID = constants.PLATFORMS.J16,
        unitCount = 8,
        loadoutID = constants.LOADOUTS.J16_YJ83,
        -- startTime = "2027-06-09 02:40:00",
        missionCreationParams = { name = "ASUW/N", type = "strike", opts = { type = "sea" } },
        emcon = "Radar=Passive;OECM=Active"
      },
      escort = nil,
      wildWeasel = {
        baseGUID = constants.BASES.SHUIMEN_AAB,
        weaponDBID = constants.WEAPONS.YJ91_ARM,
        unitDBID = constants.PLATFORMS.SU30,
        unitCount = 8,
        loadoutID = constants.LOADOUTS.SU30_YJ91,
        missionCreationParams = {
          name = "SEAD/ASUW/N",
          type = "patrol",
          opts = {
            type = "sead",
            OneThirdRule = false,
            FlightSize = 4,
            CheckOPAREA = false,
            CheckWWR = false,
            zone = constants.AREAS.AREA_OF_OPS_D
          }
        },
        emcon = "Radar=Passive;OECM=Active"
      },
      jammer = nil,
      tanker = nil,
      reconUAV = nil,
      target = {
        list = {},
        objs = nil,
        areas = { constants.AREAS.AREA_OF_OPS_D },
        filterNames = { "findNavalTargets" },
        contactAge = 60 * 60,
        minTargetCount = 1
      },
    }
  },
  CAS_N_1 = {
    {
      timeToReady = config.readytime,
      striker = {
        baseGUID = constants.BASES.SHUIMEN_AAB,
        weaponDBID = constants.WEAPONS.CS_BBC_5,
        unitDBID = constants.PLATFORMS.J10C,
        unitCount = 8,
        loadoutID = constants.LOADOUTS.J10C_CS_BBC_5,
        -- startTime = "2027-06-09 01:30:00",
        missionCreationParams = { name = "CAS/N", type = "strike", opts = { type = "land" } },
        emcon = "Radar=Passive;OECM=Active"
      },
      escort = nil,
      wildWeasel = nil,
      jammer = nil,
      tanker = nil,
      reconUAV = nil,
      target = {
        list = {},
        objs = nil,
        areas = { constants.AREAS.LANDING_TAOYUAN },
        filterNames = { "findInfantry" },
        contactAge = 60 * 60,
        minTargetCount = 1
      },
    }
  }
}


-- ============================================================================
-- GPS Jamming (Taiwan)
-- ============================================================================

config.t.GPSJamming = {}
config.t.GPSJamming.randomRadius = 20 -- random radius
config.t.GPSJamming.radius = 11
config.t.GPSJamming.GPSGuidedWeapons = {
  { dbid = constants.WEAPONS.FD280,    jammingResistance = 50 },
  { dbid = constants.WEAPONS.CJ10A,    jammingResistance = 50 },
  { dbid = constants.WEAPONS.AKD88,    jammingResistance = 50 },
  { dbid = constants.WEAPONS.LS_6_500, jammingResistance = 50 },
  { dbid = constants.WEAPONS.CS_BBC_5, jammingResistance = 50 },
}
config.t.GPSJamming.jammers = {
  ["Comms & Info Coy, 584th Mech Bde"] = {
    zoneName = "(Taiwan) Jamming Zone/1",
    name = "Comms & Info Coy, 584th Mech Bde",
    point = nil,
    randomRadius = config.t.GPSJamming.randomRadius,
    radius = config.t.GPSJamming.radius
  },
  ["Comms & Info Coy, 269th Mech Bde"] = {
    zoneName = "(Taiwan) Jamming Zone/2",
    name = "Comms & Info Coy, 269th Mech Bde",
    point = nil,
    randomRadius = config.t.GPSJamming.randomRadius,
    radius = config.t.GPSJamming.radius
  },
}

-- ============================================================================
-- MLRS (Taiwan)
-- ============================================================================

config.t.ground = {}
config.t.ground.mlrs = {}
config.t.ground.mlrs.wpnDefault = 144
config.t.ground.mlrs.ammoThreshold = 25
config.t.ground.mlrs.operationalAreas = {
  Pingzhen = constants.OPERATIONAL_AREAS.PINGZHEN,
}
config.t.ground.mlrs.reloadTime = 30 * 60
config.t.ground.mlrs.ammunitions = {
  ["Ammo Revetment, Rocket Arty Coy, 21st Arty Command"] = {
    guid = "IC8B0X-0HN9B47GHVJ7G",
    name = "Ammo Revetment, Rocket Arty Coy, 21st Arty Command",
    wpnCurrent = config.t.ground.mlrs.wpnDefault,
    wpnDefault = config.t.ground.mlrs.wpnDefault,
  }
}
config.t.ground.mlrs.resupplyUnits = {
  ["Ammo Sec, Rocket Arty Coy, 21st Arty Command"] = {
    name = "Ammo Sec, Rocket Arty Coy, 21st Arty Command",
    guid = "IC8B0X-0HN7RT1I581BB",
    wpnCurrent = config.t.ground.mlrs.wpnDefault,
    wpnDefault = config.t.ground.mlrs.wpnDefault,
    unitCount = 2,
    operationalArea = config.t.ground.mlrs.operationalAreas.Pingzhen,
    state = config.batteryState.STATIC,
    ammunition = "Ammo Revetment, Rocket Arty Coy, 21st Arty Command",
  }
}
config.t.ground.mlrs.firingUnits = {
  ["Rocket Arty Coy, 21st Arty Command"] = {
    name = "Rocket Arty Coy, 21st Arty Command",
    msg = "Radio source, Bty",
    guid = "IC8B0X-0HN7RU9I3KV9T",
    state = config.batteryState.HIDE,
    operationalArea = config.t.ground.mlrs.operationalAreas.Pingzhen,
    weaponDBID = constants.WEAPONS.MK45_AMLRS,
    ammoThreshold = config.t.ground.mlrs.ammoThreshold,
    resupplyUnit = "Ammo Sec, Rocket Arty Coy, 21st Arty Command",
    dbid = constants.PLATFORMS.LT2000
  },
}


-- ============================================================================
-- SRBM (Taiwan)
-- ============================================================================

config.t.ground.srbm = {}
config.t.ground.srbm.wpnDefault = 27
config.t.ground.srbm.ammoThreshold = 25
config.t.ground.srbm.operationalAreas = {
  Pingzhen = constants.OPERATIONAL_AREAS.PINGZHEN,
  Dadu = constants.OPERATIONAL_AREAS.DADU,
}
config.t.ground.srbm.reloadTime = 10 * 60
config.t.ground.srbm.ammunitions = {
  ["Ammo Revetment, Rocket Arty Coy, 58th Arty Command"] = {
    guid = "IC8B0X-0HN9B47GHVJG6",
    name = "Ammo Revetment, Rocket Arty Coy, 58th Arty Command",
    wpnCurrent = config.t.ground.srbm.wpnDefault,
    wpnDefault = config.t.ground.srbm.wpnDefault,
  }
}
config.t.ground.srbm.resupplyUnits = {
  ["Ammo Sec, Rocket Arty Coy, 58th Arty Command"] = {
    name = "Ammo Sec, Rocket Arty Coy, 58th Arty Command",
    guid = "IC8B0X-0HN7R5QOIVSFS",
    wpnCurrent = config.t.ground.srbm.wpnDefault,
    wpnDefault = config.t.ground.srbm.wpnDefault,
    unitCount = 2,
    operationalArea = config.t.ground.srbm.operationalAreas.Dadu,
    state = config.batteryState.STATIC,
    ammunition = "Ammo Revetment, Rocket Arty Coy, 58th Arty Command",
  }
}
config.t.ground.srbm.firingUnits = {
  ["Rocket Arty Coy, 58th Arty Command"] = {
    name = "Rocket Arty Coy, 58th Arty Command",
    msg = "Radio source, Bty",
    guid = "IC8B0X-0HN7SOIUF4D47",
    state = config.batteryState.HIDE,
    operationalArea = config.t.ground.srbm.operationalAreas.Dadu,
    weaponDBID = constants.WEAPONS.ATACMS,
    ammoThreshold = config.t.ground.srbm.ammoThreshold,
    resupplyUnit = "Ammo Sec, Rocket Arty Coy, 58th Arty Command",
    dbid = constants.PLATFORMS.HIMARS
  },
}

-- ============================================================================
-- GLCM (Taiwan)
-- ============================================================================

config.t.ground.glcm = {}
config.t.ground.glcm.wpnDefault = 48
config.t.ground.glcm.ammoThreshold = 25
config.t.ground.glcm.operationalAreas = {
  Quanxi = constants.OPERATIONAL_AREAS.QUANXI,
  Neipu = constants.OPERATIONAL_AREAS.NEIPU,
}
config.t.ground.glcm.reloadTime = 45 * 60
config.t.ground.glcm.ammunitions = {
  ["Ammo Revetment, 641st Bn, 791st AFAD & Arty Bde"] = {
    guid = "IC8B0X-0HN9B47GHVKAG",
    name = "Ammo Revetment, 641st Bn, 791st AFAD & Arty Bde",
    wpnCurrent = config.t.ground.glcm.wpnDefault * 2,
    wpnDefault = config.t.ground.glcm.wpnDefault * 2,
  },
  ["Ammo Revetment, 642nd Bn, 791st AFAD & Arty Bde"] = {
    guid = "IC8B0X-0HN9B47GHVL3V",
    name = "Ammo Revetment, 642nd Bn, 791st AFAD & Arty Bde",
    wpnCurrent = config.t.ground.glcm.wpnDefault * 2,
    wpnDefault = config.t.ground.glcm.wpnDefault * 2,
  }
}
config.t.ground.glcm.resupplyUnits = {
  ["Ammo Sec, 641st Bn, 791st AFAD & Arty Bde"] = {
    name = "Ammo Sec, 641st Bn, 791st AFAD & Arty Bde",
    guid = "IC8B0X-0HN7R5QOIVTHT",
    wpnCurrent = config.t.ground.glcm.wpnDefault,
    wpnDefault = config.t.ground.glcm.wpnDefault,
    unitCount = 3,
    operationalArea = config.t.ground.glcm.operationalAreas.Quanxi,
    state = config.batteryState.STATIC,
    ammunition = "Ammo Revetment, 641st Bn, 791st AFAD & Arty Bde",
  },
  ["Ammo Sec, 642nd Bn, 791st AFAD & Arty Bde"] = {
    name = "Ammo Sec, 642nd Bn, 791st AFAD & Arty Bde",
    guid = "IC8B0X-0HN7R5QOIVUDC",
    wpnCurrent = config.t.ground.glcm.wpnDefault,
    wpnDefault = config.t.ground.glcm.wpnDefault,
    unitCount = 3,
    operationalArea = config.t.ground.glcm.operationalAreas.Neipu,
    state = config.batteryState.STATIC,
    ammunition = "Ammo Revetment, 642nd Bn, 791st AFAD & Arty Bde",
  },
}
config.t.ground.glcm.firingUnits = {
  ["641st Bn, 791st AFAD & Arty Bde"] = {
    guid = "X58F5H-0HN1ESDRTUULO",
    name = "641st Bn, 791st AFAD & Arty Bde",
    msg = "Radio source, Bty",
    state = config.batteryState.HIDE,
    operationalArea = config.t.ground.glcm.operationalAreas.Quanxi,
    weaponDBID = constants.WEAPONS.HF2E,
    ammoThreshold = config.t.ground.glcm.ammoThreshold,
    resupplyUnit = "Ammo Sec, 641st Bn, 791st AFAD & Arty Bde",
    dbid = constants.PLATFORMS.HF2E
  },
  ["642nd Bn, 791st AFAD & Arty Bde"] = {
    guid = "X58F5H-0HN1ESDRTLGU7",
    name = "642nd Bn, 791st AFAD & Arty Bde",
    msg = "Radio source, Bty",
    state = config.batteryState.HIDE,
    operationalArea = config.t.ground.glcm.operationalAreas.Neipu,
    weaponDBID = constants.WEAPONS.HF2E,
    ammoThreshold = config.t.ground.glcm.ammoThreshold,
    resupplyUnit = "Ammo Sec, 642nd Bn, 791st AFAD & Arty Bde",
    dbid = constants.PLATFORMS.HF2E
  }
}

-- ============================================================================
-- ASCM (Taiwan)
-- ============================================================================

config.t.ground.ascm = {}
config.t.ground.ascm.wpnDefault = 16
config.t.ground.ascm.ammoThreshold = 25
config.t.ground.ascm.operationalAreas = {
  Pingzhen = constants.OPERATIONAL_AREAS.PINGZHEN,
  Dadu = constants.OPERATIONAL_AREAS.DADU,
  Neipu = constants.OPERATIONAL_AREAS.NEIPU,
  Luzhu = constants.OPERATIONAL_AREAS.LUZHU,
  Dong = constants.OPERATIONAL_AREAS.DONG,
}
config.t.ground.ascm.reloadTime = 45 * 60
-- config.t.ground.ascm.reloadTime = 5 * 60
config.t.ground.ascm.ammunitions = {
  ["Ammo Revetment, Hai Feng Shore-based ASM SUPP Sqn, Luzhu"] = {
    guid = "IC8B0X-0HN9B47GHVLV9",
    name = "Ammo Revetment, Hai Feng Shore-based ASM SUPP Sqn, Luzhu",
    wpnCurrent = config.t.ground.ascm.wpnDefault * 2,
    wpnDefault = config.t.ground.ascm.wpnDefault * 2,
  },
  ["Ammo Revetment, Hai Feng Shore-based ASM SUPP Sqn, Dong"] = {
    guid = "IC8B0X-0HN9JFGVR06D8",
    name = "Ammo Revetment, Hai Feng Shore-based ASM SUPP Sqn, Dong",
    wpnCurrent = config.t.ground.ascm.wpnDefault * 2,
    wpnDefault = config.t.ground.ascm.wpnDefault * 2,
  },
}
config.t.ground.ascm.resupplyUnits = {
  ["Hai Feng Shore-based ASM SUPP Sqn, Luzhu"] = {
    name = "Hai Feng Shore-based ASM SUPP Sqn, Luzhu",
    guid = "IC8B0X-0HN87KFOFSGUB",
    wpnCurrent = config.t.ground.ascm.wpnDefault,
    wpnDefault = config.t.ground.ascm.wpnDefault,
    unitCount = 2,
    operationalArea = config.t.ground.ascm.operationalAreas.Luzhu,
    state = config.batteryState.STATIC,
    ammunition = "Ammo Revetment, Hai Feng Shore-based ASM SUPP Sqn, Luzhu",
  },
  ["Hai Feng Shore-based ASM SUPP Sqn, Dong"] = {
    name = "Hai Feng Shore-based ASM SUPP Sqn, Dong",
    guid = "IC8B0X-0HN9JFGVR07U5",
    wpnCurrent = config.t.ground.ascm.wpnDefault,
    wpnDefault = config.t.ground.ascm.wpnDefault,
    unitCount = 2,
    operationalArea = config.t.ground.ascm.operationalAreas.Dong,
    state = config.batteryState.STATIC,
    ammunition = "Ammo Revetment, Hai Feng Shore-based ASM SUPP Sqn, Dong",
  },
}
config.t.ground.ascm.firingUnits = {
  ["2nd Hai Feng Shore-based ASM MOB Sqn"] = {
    name = "2nd Hai Feng Shore-based ASM MOB Sqn",
    msg = "Radio source, Bty",
    guid = "IC8B0X-0HN87MOIE9C4U",
    state = config.batteryState.HIDE,
    operationalArea = config.t.ground.ascm.operationalAreas.Luzhu,
    weaponDBID = constants.WEAPONS.HF3,
    ammoThreshold = config.t.ground.ascm.ammoThreshold,
    resupplyUnit = "Hai Feng Shore-based ASM SUPP Sqn, Luzhu",
    dbid = constants.PLATFORMS.HF3
  },
  ["4th Hai Feng Shore-based ASM MOB Sqn"] = {
    name = "4th Hai Feng Shore-based ASM MOB Sqn",
    msg = "Radio source, Bty",
    guid = "X58F5H-0HMVEU1FUVOLC",
    state = config.batteryState.HIDE,
    operationalArea = config.t.ground.ascm.operationalAreas.Luzhu,
    weaponDBID = constants.WEAPONS.HF3,
    ammoThreshold = config.t.ground.ascm.ammoThreshold,
    resupplyUnit = "Hai Feng Shore-based ASM SUPP Sqn, Luzhu",
    dbid = constants.PLATFORMS.HF3
  },
  ["1st Hai Feng Shore-based ASM MOB Sqn"] = {
    name = "1st Hai Feng Shore-based ASM MOB Sqn",
    msg = "Radio source, Bty",
    guid = "X58F5H-0HMVEU1FUVO8I",
    state = config.batteryState.HIDE,
    operationalArea = config.t.ground.ascm.operationalAreas.Dong,
    weaponDBID = constants.WEAPONS.HF3,
    ammoThreshold = config.t.ground.ascm.ammoThreshold,
    resupplyUnit = "Hai Feng Shore-based ASM SUPP Sqn, Dong",
    dbid = constants.PLATFORMS.HF3
  },
  ["3rd Hai Feng Shore-based ASM MOB Sqn"] = {
    name = "3rd Hai Feng Shore-based ASM MOB Sqn",
    msg = "Radio source, Bty",
    guid = "X58F5H-0HMVEU1FUVO6J",
    state = config.batteryState.HIDE,
    operationalArea = config.t.ground.ascm.operationalAreas.Dong,
    weaponDBID = constants.WEAPONS.HF3,
    ammoThreshold = config.t.ground.ascm.ammoThreshold,
    resupplyUnit = "Hai Feng Shore-based ASM SUPP Sqn, Dong",
    dbid = constants.PLATFORMS.HF3
  },
  ["5th Hai Feng Shore-based ASM MOB Sqn"] = {
    name = "5th Hai Feng Shore-based ASM MOB Sqn",
    msg = "Radio source, Bty",
    guid = "IC8B0X-0HN8CEO4EUE8B",
    state = config.batteryState.HIDE,
    operationalArea = config.t.ground.ascm.operationalAreas.Luzhu,
    weaponDBID = constants.WEAPONS.HF3,
    ammoThreshold = config.t.ground.ascm.ammoThreshold,
    resupplyUnit = "Hai Feng Shore-based ASM SUPP Sqn, Luzhu",
    dbid = constants.PLATFORMS.HF3
  },
  ["6th Hai Feng Shore-based ASM MOB Sqn"] = {
    name = "6th Hai Feng Shore-based ASM MOB Sqn",
    msg = "Radio source, Bty",
    guid = "IC8B0X-0HNHAETCJHDEA",
    state = config.batteryState.HIDE,
    operationalArea = config.t.ground.ascm.operationalAreas.Dong,
    weaponDBID = constants.WEAPONS.HF3,
    ammoThreshold = config.t.ground.ascm.ammoThreshold,
    resupplyUnit = "Hai Feng Shore-based ASM SUPP Sqn, Dong",
    dbid = constants.PLATFORMS.HF3
  },
}

-- ============================================================================
-- IADS (Taiwan)
-- ============================================================================

config.t.IADS = {}
config.t.IADS.ratio = { ROCC = 1.5, TAAOC = 1.5 }
config.t.IADS.ROCC = {
  ["IC8B0X-0HNC3OB4KJKIF"] = {
    name = "ROCC/North",
    msg = "Radio source, C2",
    guid = "IC8B0X-0HNC3OB4KJKIF",
    areas = { constants.AREAS.THEATER_OF_OPS_3RD, },
    SAM = {},
    radar = {}
  },
  ["IC8B0X-0HNC3OB4KJKTC"] = {
    name = "ROCC/East",
    msg = "Radio source, C2",
    guid = "IC8B0X-0HNC3OB4KJKTC",
    areas = { constants.AREAS.THEATER_OF_OPS_2ND, constants.AREAS.THEATER_OF_OPS_5TH, },
    SAM = {},
    radar = {}
  },
  ["IC8B0X-0HNC3OB4KJL2M"] = {
    name = "ROCC/South",
    msg = "Radio source, C2",
    guid = "IC8B0X-0HNC3OB4KJL2M",
    areas = { constants.AREAS.THEATER_OF_OPS_4TH, },
    SAM = {},
    radar = {}
  },
}
config.t.IADS.TAAOC = {
  ["IC8B0X-0HN41D1QKTVU7"] = {
    name = "TAAOC/3rd OPAREA",
    msg = "Radio source, C2",
    guid = "IC8B0X-0HN41D1QKTVU7",
    areas = { constants.AREAS.THEATER_OF_OPS_3RD, },
    SAM = {},
  },
  ["IC8B0X-0HN41D1QKU1ED"] = {
    name = "TAAOC/5th OPAREA",
    msg = "Radio source, C2",
    guid = "IC8B0X-0HN41D1QKU1ED",
    areas = { constants.AREAS.THEATER_OF_OPS_5TH, },
    SAM = {},
  },
  ["IC8B0X-0HN41D1QKU0JP"] = {
    name = "TAAOC/4th OPAREA",
    msg = "Radio source, C2",
    guid = "IC8B0X-0HN41D1QKU0JP",
    areas = { constants.AREAS.THEATER_OF_OPS_4TH, },
    SAM = {},
  },
  ["IC8B0X-0HNC27TV5Q0AS"] = {
    name = "TAAOC/2nd OPAREA",
    msg = "Radio source, C2",
    guid = "IC8B0X-0HNC27TV5Q0AS",
    areas = { constants.AREAS.THEATER_OF_OPS_2ND, },
    SAM = {},
  },
}



-- ============================================================================
-- Aircraft Settings (Taiwan)
-- ============================================================================

config.t.air = {}
config.t.air.landBased = {}
config.t.air.landBased.wpnNum = 8
config.t.air.landBased.deployedACs = {
  {
    name = "Ching Chuang Kang AB",
    baseGUID = constants.BASES.CHING_CHUANG_KANG_AB,
    embarkedUnits = {
      {
        side = "Taiwan",
        type = "Air",
        dbid = constants.PLATFORMS.IDF,
        platformName = "IDF",
        name = "3rd Tactical Fighter Wing",
        loadouts = {
          { name = "Wan Chien", loadoutId = constants.LOADOUTS.IDF_WAN_CHIEN, num = 8 },
        }
      }
    },
    loadouts = {
      { name = "Wan Chien", loadoutId = constants.LOADOUTS.IDF_WAN_CHIEN, num = config.t.air.landBased.wpnNum }, --Wan Chien X 2
    }
  },
  {
    name = "Chiayi AB",
    baseGUID = constants.BASES.CHIAYI_AB,
    embarkedUnits = {
      {
        side = "Taiwan",
        type = "Air",
        dbid = constants.PLATFORMS.F16V_BLK20,
        platformName = "F-16V Block 20",
        name = "4th Tactical Fighter Wing",
        loadouts = {
          { name = "AMRAAM", loadoutId = constants.LOADOUTS.F16V_BLK20_AMRAAM, num = 8 },
        }
      }
    },
    loadouts = {
      { name = "AMRAAM",  loadoutId = constants.LOADOUTS.F16V_BLK20_AMRAAM,  num = config.t.air.landBased.wpnNum }, --AMRAAM X 4
      { name = "Harpoon", loadoutId = constants.LOADOUTS.F16V_BLK20_HARPOON, num = config.t.air.landBased.wpnNum }, --Harpoon X 2
      { name = "GBU",     loadoutId = constants.LOADOUTS.F16V_BLK20_GBU,     num = config.t.air.landBased.wpnNum }, --GBU X 2
    }
  },
  {
    name = "Tainan AB",
    baseGUID = constants.BASES.TAINAN_AB,
    embarkedUnits = {
      {
        side = "Taiwan",
        type = "Air",
        dbid = constants.PLATFORMS.IDF,
        platformName = "IDF",
        name = "1st Tactical Fighter Wing",
        loadouts = {
          { name = "Wan Chien", loadoutId = constants.LOADOUTS.IDF_WAN_CHIEN, num = 4 },
        }
      }
    },
    loadouts = {
      { name = "Wan Chien", loadoutId = constants.LOADOUTS.IDF_WAN_CHIEN, num = config.t.air.landBased.wpnNum }, --Wan Chien X 2
    }
  },
  {
    name = "Magong AB",
    baseGUID = constants.BASES.MAGONG_AB,
    embarkedUnits = {
      {
        side = "Taiwan",
        type = "Air",
        dbid = constants.PLATFORMS.IDF,
        platformName = "IDF",
        name = "1st Tactical Fighter Wing",
        loadouts = {
          { name = "Wan Chien", loadoutId = constants.LOADOUTS.IDF_WAN_CHIEN, num = 4 },
        }
      }
    },
    loadouts = {
      { name = "Wan Chien", loadoutId = constants.LOADOUTS.IDF_WAN_CHIEN, num = config.t.air.landBased.wpnNum }, --Wan Chien X 2
    }
  },
  {
    name = "Guiren AAB",
    baseGUID = constants.BASES.GUIREN_AAB,
    embarkedUnits = {
      {
        side = "Taiwan",
        type = "Air",
        dbid = constants.PLATFORMS.AH1W,
        platformName = "AH-1W",
        name = "603rd Air Cavalry Bde",
        loadouts = {
          { name = "Hellfire", loadoutId = constants.LOADOUTS.AH1W_HELLFIRE, num = 8, missionName = "ASUW/ACV/PENGHU" },
        }
      }
    },
    loadouts = {
      { name = "Hellfire", loadoutId = constants.LOADOUTS.AH1W_HELLFIRE, num = config.t.air.landBased.wpnNum }, --Hellfire X 8
    }
  },
  {
    name = "Pingtung North AB",
    baseGUID = constants.BASES.PINGTUNG_NORTH_AB,
    embarkedUnits = {
      {
        side = "Taiwan",
        type = "Air",
        dbid = constants.PLATFORMS.E2K,
        platformName = "E-2K",
        name = "6th Mixed Wing",
        loadouts = {
          { name = "AEW", loadoutId = constants.LOADOUTS.E2K_AEW, num = 3, missionName = "FERRY/2" },
        }
      },
    }
  },
  {
    name = "Pingtung South AB",
    baseGUID = constants.BASES.PINGTUNG_SOUTH_AB,
    embarkedUnits = {
      {
        side = "Taiwan",
        type = "Air",
        dbid = constants.PLATFORMS.P3C,
        platformName = "P-3C",
        name = "6th Mixed Wing",
        loadouts = {
          { name = "ASW Patrol", loadoutId = constants.LOADOUTS.P3C_ASW, num = 3, missionName = "ASW/E" },
        }
      },
      {
        side = "Taiwan",
        type = "Air",
        dbid = constants.PLATFORMS.C130HE,
        platformName = "C-130HE",
        name = "6th Mixed Wing",
        loadouts = {
          { name = "Electronic Warfare", loadoutId = constants.LOADOUTS.C130HE_EW, num = 1, missionName = "FERRY/2" },
        }
      },
    }
  },
  {
    name = "Taitung/Jhihhang AB",
    baseGUID = constants.BASES.TAITUNG_JHIHHANG_AB,
    embarkedUnits = {
      {
        side = "Taiwan",
        type = "Air",
        dbid = constants.PLATFORMS.F16V_BLK70,
        platformName = "F-16V Block 70",
        name = "7th Tactical Fighter Wing",
        loadouts = {
          { name = "SLAM-ER", loadoutId = constants.LOADOUTS.F16V_BLK70_SLAM_ER, num = 8, missionName = "FERRY/3" },
        }
      }
    },
    loadouts = {
      { name = "SLAM-ER", loadoutId = constants.LOADOUTS.F16V_BLK70_SLAM_ER, num = config.t.air.landBased.wpnNum }, --SLAMER X 2
      { name = "JDAM",    loadoutId = constants.LOADOUTS.F16V_BLK70_JDAM,    num = config.t.air.landBased.wpnNum }, --JDAM X 4
      { name = "HARM",    loadoutId = constants.LOADOUTS.F16V_BLK70_HARM,    num = config.t.air.landBased.wpnNum }, --HARM X 2
      { name = "JSOW",    loadoutId = constants.LOADOUTS.F16V_BLK70_JSOW,    num = config.t.air.landBased.wpnNum }, --JSOW X 4
    }
  },
  {
    name = "Jiashan AB",
    baseGUID = constants.BASES.JIASHAN_AB,
    embarkedUnits = {
      {
        side = "Taiwan",
        type = "Air",
        dbid = constants.PLATFORMS.MQ9B,
        platformName = "MQ-9B",
        name = "5th Tactical Mixed Wing",
        loadouts = {
          { name = "Reconnaissance", loadoutId = constants.LOADOUTS.MQ9B_RECON, num = 3, missionName = "AEW/S" },
        }
      },
      {
        side = "Taiwan",
        type = "Air",
        dbid = constants.PLATFORMS.F16V_BLK20,
        platformName = "F-16V Block 20",
        name = "5th Tactical Mixed Wing",
        loadouts = {
          { name = "Harpoon", loadoutId = constants.LOADOUTS.F16V_BLK20_HARPOON, num = 8, },
        }
      }
    },
    loadouts = {
      { name = "AMRAAM",  loadoutId = constants.LOADOUTS.F16V_BLK20_AMRAAM,  num = config.t.air.landBased.wpnNum }, --AMRAAM X 4
      { name = "Harpoon", loadoutId = constants.LOADOUTS.F16V_BLK20_HARPOON, num = config.t.air.landBased.wpnNum }, --Harpoon X 2
      { name = "GBU",     loadoutId = constants.LOADOUTS.F16V_BLK20_GBU,     num = config.t.air.landBased.wpnNum }, --GBU X 2
    }
  },
  {
    name = "Hsinchu AB",
    baseGUID = constants.BASES.HSINCHU_AB,
    embarkedUnits = {
      {
        side = "Taiwan",
        type = "Air",
        dbid = constants.PLATFORMS.MIRAGE2000,
        platformName = "Mirage 2000",
        name = "2nd Tactical Fighter Wing",
        loadouts = {
          { name = "MICA AAM", loadoutId = constants.LOADOUTS.MIRAGE2000_MICA, num = 8, },
        }
      }
    },
    loadouts = {
      { name = "MICA AAM", loadoutId = constants.LOADOUTS.MIRAGE2000_MICA, num = config.t.air.landBased.wpnNum }, --MICA X 4

    }
  },
  {
    name = "Longtan AAB",
    baseGUID = constants.BASES.LONGTAN_AAB,
    embarkedUnits = {
      {
        side = "Taiwan",
        type = "Air",
        dbid = constants.PLATFORMS.AH64E,
        platformName = "AH-64E",
        name = "601st Air Cavalry Bde",
        loadouts = {
          { name = "Hellfire", loadoutId = constants.LOADOUTS.AH64E_HELLFIRE, num = 8, missionName = "ASUW/ACV/W" },
        }
      }
    },
    loadouts = {
      { name = "Hellfire", loadoutId = constants.LOADOUTS.AH64E_HELLFIRE, num = config.t.air.landBased.wpnNum }, --Hellfire X 16
    }
  },
  {
    name = "Taoyuan International Airport",
    baseGUID = constants.BASES.TAOYUAN_AIRPORT,
    embarkedUnits = {
      {
        side = "Taiwan",
        type = "Air",
        dbid = constants.PLATFORMS.CHUNG_SHYANG_II,
        platformName = "Chung Shyang II",
        name = "1st Maritime Tactical Recon Sqn",
        loadouts = {
          { name = "Reconnaissance", loadoutId = constants.LOADOUTS.CHUNG_SHYANG_II_RECON, num = 3, missionName = "RECON/3" },
        }
      }
    }
  },
  {
    name = "Rende Emergency Highway Strip",
    baseGUID = constants.BASES.RENDE_STRIP,
    loadouts = {
      { name = "Wan Chien", loadoutId = constants.LOADOUTS.IDF_WAN_CHIEN, num = config.t.air.landBased.wpnNum }, --Wan Chien X 2
    }
  },
  {
    name = "Madou Emergency Highway Strip",
    baseGUID = constants.BASES.MADOU_STRIP,
    loadouts = {
      { name = "AMRAAM",  loadoutId = constants.LOADOUTS.F16V_BLK20_AMRAAM,  num = config.t.air.landBased.wpnNum }, --AMRAAM X 4
      { name = "Harpoon", loadoutId = constants.LOADOUTS.F16V_BLK20_HARPOON, num = config.t.air.landBased.wpnNum }, --Harpoon X 2
      { name = "GBU",     loadoutId = constants.LOADOUTS.F16V_BLK20_GBU,     num = config.t.air.landBased.wpnNum }, --GBU X 2
    }
  },
  {
    name = "Minxiong Emergency Highway Strip",
    baseGUID = constants.BASES.MINXIONG_STRIP,
    loadouts = {
      { name = "AMRAAM",  loadoutId = constants.LOADOUTS.F16V_BLK20_AMRAAM,  num = config.t.air.landBased.wpnNum }, --AMRAAM X 4
      { name = "Harpoon", loadoutId = constants.LOADOUTS.F16V_BLK20_HARPOON, num = config.t.air.landBased.wpnNum }, --Harpoon X 2
      { name = "GBU",     loadoutId = constants.LOADOUTS.F16V_BLK20_GBU,     num = config.t.air.landBased.wpnNum }, --GBU X 2
    }
  },
  {
    name = "Tainan Field Airdrome",
    baseGUID = constants.BASES.TAINAN_FIELD_AIRDROME,
    loadouts = {
      { name = "Hellfire", loadoutId = constants.LOADOUTS.AH1W_HELLFIRE, num = config.t.air.landBased.wpnNum }, --Hellfire X 8
    }
  },
  {
    name = "Hsinchu Field Airdrome ",
    baseGUID = constants.BASES.HSINCHU_FIELD_AIRDROME,
    loadouts = {
      { name = "Hellfire", loadoutId = constants.LOADOUTS.AH64E_HELLFIRE, num = config.t.air.landBased.wpnNum }, --Hellfire X 16
    }
  },
}
config.t.surface = {}
config.t.surface.sag = {
  ["264th Sqn"] = {
    groupName = "264th Sqn",
    unitList = {
      kidd = {
        dbid = constants.PLATFORMS.KIDD,
        embarkedUnits = {
          {
            side = "Taiwan",
            type = "Air",
            dbid = constants.PLATFORMS.S70C,
            platformName = "S-70C",
            name = "2nd ASW Aviation Grp",
            loadouts = {
              { loadoutId = constants.LOADOUTS.S70C_ASW, num = 2 },
            }
          },
        },
      },
      kangDing = {
        dbid = constants.PLATFORMS.KANG_DING,
        embarkedUnits = {
          {
            side = "Taiwan",
            type = "Air",
            dbid = constants.PLATFORMS.S70C,
            platformName = "S-70C",
            name = "2nd ASW Aviation Grp",
            loadouts = {
              { loadoutId = constants.LOADOUTS.S70C_ASW, num = 1 },
            }
          },
        }
      },
    },
    missionName = "ASW/E",
    from = {
      startingPoint = { latitude = "N 24.28.47", longitude = "E 122.25.49", },
      heading = 0
    },
  },
}
config.t.surface.deployedShips = {
  {
    name = "Port of Keelung",
    baseGUID = constants.BASES.PORT_OF_KEELUNG,
    embarkedUnits = {
      {
        side = "Taiwan",
        type = "Ship",
        dbid = constants.PLATFORMS.TA_CHIANG,
        platformName = "Ta Chiang",
        name = "131st Fleet",
        loadouts = {
          { loadoutId = 0, num = 6 },
        }
      }
    }
  },
}


-- ============================================================================
-- SIGINT (US)
-- ============================================================================

-- CONFIG.u.SIGINT.maxCount = 5
config.u.SIGINT = {}
config.u.SIGINT.maxCount = config.c.SIGINT.maxCount
config.u.SIGINT.maxRange = config.c.SIGINT.maxRange

-- Detection parameters (shared with China)
config.u.SIGINT.detectionThreshold = config.c.SIGINT.detectionThreshold
config.u.SIGINT.maxDetectionRange = config.c.SIGINT.maxDetectionRange

-- Detection formula constants (shared with China)
config.u.SIGINT.formulaConstants = config.c.SIGINT.formulaConstants

-- Default display configuration (shared with China)
config.u.SIGINT.defaultDisplay = config.c.SIGINT.defaultDisplay

-- Area and performance parameters (shared with China)
config.u.SIGINT.minPolygonPoints = config.c.SIGINT.minPolygonPoints
config.u.SIGINT.detectionSkipProbability = config.c.SIGINT.detectionSkipProbability


-- ============================================================================
-- Scoring Configuration
-- ============================================================================

config.s.destroyingAircraftOnTheGround = 5
config.s.destroyingAmmo = 100
config.s.destroyingAmmoTruck = 20
config.s.lhd = 10
config.s.lst = 10
config.s.ddg = 10
config.s.cv = 100
config.s.ifv = -5
config.s.infantry = -3
config.s.sub = 15
config.s.uav = 20
config.s.tel = 20
config.s.weaponDBID = constants.WEAPONS.MK48_TORPEDO
config.s.attackBeforeTheHHour = -1000
config.s.undergroundShelterIsDestroyed = -200
config.s.destroyingCivilianFacility = -100

return config
