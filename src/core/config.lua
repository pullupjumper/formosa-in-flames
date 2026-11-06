local constants = require("src.core.constants")
---@diagnostic disable: missing-fields
---@class SBJ__Config
local config = {}

config.version = "1.0.0"
config.isEditMode = true
config.difficulty = "normal"

-- Logging configuration
config.logging = {
  modules = {
    [constants.TAGS.GROUND] = { verbose = true },
    [constants.TAGS.AIR] = { verbose = true },
    [constants.TAGS.ADMIN_OFFLOADING] = { verbose = true },
    [constants.TAGS.RECON] = { verbose = true },
    [constants.TAGS.DYNAMIC_OPERATIONS] = { verbose = true },
    [constants.TAGS.TARGETING_PROCESS] = { verbose = true },
    [constants.TAGS.SIGINT] = { verbose = false },
    [constants.TAGS.COMMS_JAMMING] = { verbose = false },
    [constants.TAGS.GNSS_JAMMING] = { verbose = true },
    [constants.TAGS.INTEGRATED_AIR_DEFENSE_SYSTEM] = { verbose = false },
    [constants.TAGS.ATTACK_MANAGER] = { verbose = false },
    [constants.TAGS.UNIT_GENERATOR] = { verbose = false },
    [constants.TAGS.MISSILE_SYSTEM] = { verbose = true },
    [constants.TAGS.SCORE] = { verbose = true },
    [constants.TAGS.INIT] = { verbose = true },
    [constants.TAGS.SHIP_MOVEMENT] = { verbose = true },
    [constants.TAGS.AMPHIBIOUS_LOGISTICS] = { verbose = true },
    [constants.TAGS.AMPHIBIOUS_ASSAULT] = { verbose = true }
  }
}
config.red = {}
config.blue = {}
config.ally = {}
config.score = {}

config.red.targetScanning = {
  distanceThreshold = 1.5, -- nautical miles
  blueAirBases = {
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
  bluePorts = {
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
-- config.aircraftReadySec = 3600 * 1.5
config.aircraftReadySec = 5 * 60


-- ============================================================================
-- Setup Start Time
-- ============================================================================

config.red.triggers = {
  scenBegin = { startTime = "2027-06-09 01:00:00" },
  amphibiousOps = { startTime = "2027-06-09 02:40:00" },
  -- amphibiousOps = { startTime = "2027-06-09 2:15:00" },
  launchLACM = { startTime = "2027-06-09 06:00:00" },
  launchSLCM = { startTime = "2027-06-09 06:30:00" },
  -- launchSLCM = { startTime = "2027-06-09 01:00:00" },
}


-- ============================================================================
-- SIGINT (China)
-- ============================================================================

config.red.sigint = {}
config.red.sigint.maxCount = 6
-- config.red.sigint.maxRangeNm = 1
config.red.sigint.maxRangeNm = 2.5
-- Detection parameters
config.red.sigint.detectionThreshold = 60
config.red.sigint.maxDetectionRangeNm = { 300, 340 }
-- Detection formula constants
config.red.sigint.formulaConstants = {
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
config.red.sigint.defaultDisplay = {
  r = 255,
  g = 255,
  b = 255,
  lifeTime = 4,
  fontSize = 16
}
-- Area and performance parameters
config.red.sigint.minPolygonPoints = 3
config.red.sigint.detectionSkipProbability = 0.3


-- ============================================================================
-- IADS (China)
-- ============================================================================

config.red.iads = {}
config.red.iads.c2FacilityDBIDs = { 319, 318, 115, 113 }
config.red.iads.randomRadiusNm = 10
config.red.iads.radarDistanceNm = 70 -- nautical miles
config.red.iads.c2Deployments = {
  {
    pos = { latitude = "N 25.30.37", longitude = "E 119.30.54" },
    areas = { constants.AREAS.MILITARY_SUB_DISTRICT_FUZHOU, },
    name = "Fuzhou"
  },
  {
    pos = { latitude = "N 25.19.12", longitude = "E 119.06.36" },
    areas = { constants.AREAS.MILITARY_SUB_DISTRICT_PUTIAN, },
    name = "Putian"
  },
  {
    pos = { latitude = "N 24.57.01", longitude = "E 118.34.22" },
    areas = { constants.AREAS.MILITARY_SUB_DISTRICT_CHANGZHOU, },
    name = "Changzhou"
  },
  {
    pos = { latitude = "N 24.43.19", longitude = "E 118.12.29" },
    areas = { constants.AREAS.MILITARY_SUB_DISTRICT_XIAMEN, },
    name = "Xiamen"
  },
  {
    pos = { latitude = "N 24.10.12", longitude = "E 117.28.46" },
    areas = { constants.AREAS.MILITARY_SUB_DISTRICT_ZHANGZHOU, },
    name = "Zhangzhou"
  },
  {
    pos = { latitude = "N 23.39.17", longitude = "E 116.41.26" },
    areas = { constants.AREAS.MILITARY_SUB_DISTRICT_SHANTOU, },
    name = "Shantou"
  },
  {
    pos = { latitude = "N 23.08.19", longitude = "E 115.22.49" },
    areas = { constants.AREAS.MILITARY_SUB_DISTRICT_SHANWEI, },
    name = "Shanwei"
  },
  {
    pos = { latitude = "N 24.06.12", longitude = "E 116.05.36" },
    areas = { constants.AREAS.MILITARY_SUB_DISTRICT_MEIZHOU, },
    name = "Meizhou"
  },
  {
    pos = { latitude = "N 31.06.11", longitude = "E 121.03.35" },
    areas = { constants.AREAS.MILITARY_SUB_DISTRICT_SHANGHAI, },
    name = "Shanghai"
  },
  {
    pos = { latitude = "N 27.05.38", longitude = "E 119.55.05" },
    areas = { constants.AREAS.MILITARY_SUB_DISTRICT_NINGDE, },
    name = "Ningde"
  },
}


-- ============================================================================
-- Communications Jamming (China)
-- ============================================================================

config.red.commsJamming = {}
config.red.commsJamming.limit = 4
config.red.commsJamming.rangeNm = 50
config.red.commsJamming.initialComms = -20
config.red.commsJamming.baseJammingPower = -120
config.red.commsJamming.distanceExponent = 1.04
config.red.commsJamming.effectivenessFormula = { base = 1.9, range = 1.8 }
config.red.commsJamming.distanceThresholds = {
  close = 100,
  medium = 200,
  far = 300,
  distant = 400
}
config.red.commsJamming.aewSupport = {
  close = 400,  -- < 100nm
  medium = 350, -- < 200nm
  far = 250,    -- < 300nm
  distant = 150 -- < 400nm
}
-- config.red.commsJamming.recoveryTime = { min = 15, max = 25 }
config.red.commsJamming.recoveryTime = { min = 5, max = 10 }
config.red.commsJamming.jammingTime = { min = 5, max = 10 }
config.red.commsJamming.cooldownTime = { min = -5, max = -1 }
config.red.commsJamming.randomVariance = {
  close = { min = -1, max = 1 },
  medium = { min = -3, max = 3 },
  far = { min = -6, max = 6 },
  distant = { min = -10, max = 10 }
}
config.red.commsJamming.mode = "omnidirectional"
config.red.commsJamming.aircraftDefaults = {
  commsLevel = 40,
  commsBase = 40,
  commsThreshold = 30,
  outOfComms = 0,
}


-- ============================================================================
-- GPS Jamming (China)
-- ============================================================================

config.red.gnssJamming = {}
config.red.gnssJamming.randomRadiusNm = 20 -- random radius
config.red.gnssJamming.radiusNm = 14
config.red.gnssJamming.gnssGuidedWeapons = {
  { dbid = constants.WEAPONS.JDAM,       jammingResistance = 50 },
  { dbid = constants.WEAPONS.WAN_CHIEN,  jammingResistance = 50 },
  { dbid = constants.WEAPONS.HARPOON_II, jammingResistance = 50 },
  { dbid = constants.WEAPONS.JSOW,       jammingResistance = 50 },
  { dbid = constants.WEAPONS.SLAMER,     jammingResistance = 50 },
}
config.red.gnssJamming.jammers = {
  ["1st Bn, 1st ECM Bde"] = {
    zoneName = "JAMMING ZONE/1",
    name = "1st Bn, 1st ECM Bde",
    pos = { latitude = "N 25.28.17", longitude = "E 119.35.17" },
    randomRadiusNm = config.red.gnssJamming.randomRadiusNm,
    radiusNm = config.red.gnssJamming.radiusNm
  },
  ["2nd Bn, 1st ECM Bde"] = {
    zoneName = "JAMMING ZONE/2",
    name = "2nd Bn, 1st ECM Bde",
    pos = { latitude = "N 24.43.49", longitude = "E 118.29.41" },
    randomRadiusNm = config.red.gnssJamming.randomRadiusNm,
    radiusNm = config.red.gnssJamming.radiusNm
  },
}


-- ============================================================================
-- Ground policy (China)
-- ============================================================================

config.red.ground = {}
config.red.ground.policy = {
  isAuto = true,
  hideOnEnterHA = true,
  hideTransloaderOnRLNoMeeting = true
}
config.red.ground.missileSystemTypes = {}

-- ============================================================================
-- MLRS (China)
-- ============================================================================

config.red.ground.missileSystemTypes.mlrs = {}
config.red.ground.missileSystemTypes.mlrs.weaponCountDefault = 96
config.red.ground.missileSystemTypes.mlrs.ammoThreshold = 55
config.red.ground.missileSystemTypes.mlrs.contactAge = 30 * 60
config.red.ground.missileSystemTypes.mlrs.reloadTime = 30 * 60
config.red.ground.missileSystemTypes.mlrs.stowTime = 5 * 60
config.red.ground.missileSystemTypes.mlrs.canisterStocks = {
  ["Ammo Revetment, 1st Bn, 1st Rockets Arty Bde"] = {
    name = "Ammo Revetment, 1st Bn, 1st Rockets Arty Bde",
    weaponCountCurrent = config.red.ground.missileSystemTypes.mlrs.weaponCountDefault * 2,
    weaponCountDefault = config.red.ground.missileSystemTypes.mlrs.weaponCountDefault * 2,
  },
  ["Ammo Revetment, 6th Bn, 73rd Arty Bde"] = {
    name = "Ammo Revetment, 6th Bn, 73rd Arty Bde",
    weaponCountCurrent = config.red.ground.missileSystemTypes.mlrs.weaponCountDefault * 2,
    weaponCountDefault = config.red.ground.missileSystemTypes.mlrs.weaponCountDefault * 2,
  },
}
config.red.ground.missileSystemTypes.mlrs.transloaders = {
  ["Ammo Sec, 1st Bn, 1st Rockets Arty Bde"] = {
    name = "Ammo Sec, 1st Bn, 1st Rockets Arty Bde",
    weaponCountCurrent = config.red.ground.missileSystemTypes.mlrs.weaponCountDefault,
    weaponCountDefault = config.red.ground.missileSystemTypes.mlrs.weaponCountDefault,
    unitCount = 2,
    operationalArea = constants.OPERATIONAL_AREAS.JUK,
    state = constants.MISSILE_UNIT_POSTURE.STATIC,
    canisterStock = "Ammo Revetment, 1st Bn, 1st Rockets Arty Bde",
    launcher = "1st Bn, 1st Rockets Arty Bde"
  },
  ["Ammo Sec, 6th Bn, 73rd Arty Bde"] = {
    name = "Ammo Sec, 6th Bn, 73rd Arty Bde",
    weaponCountCurrent = config.red.ground.missileSystemTypes.mlrs.weaponCountDefault,
    weaponCountDefault = config.red.ground.missileSystemTypes.mlrs.weaponCountDefault,
    unitCount = 2,
    operationalArea = constants.OPERATIONAL_AREAS.YMC,
    state = constants.MISSILE_UNIT_POSTURE.STATIC,
    canisterStock = "Ammo Revetment, 6th Bn, 73rd Arty Bde",
    launcher = "6th Bn, 73rd Arty Bde"
  },
}
config.red.ground.missileSystemTypes.mlrs.launchers = {
  ["1st Bn, 1st Rockets Arty Bde"] = {
    name = "1st Bn, 1st Rockets Arty Bde",
    msg = "Radio source, Bty",
    state = constants.MISSILE_UNIT_POSTURE.HIDE,
    operationalArea = constants.OPERATIONAL_AREAS.JUK,
    weaponDBID = constants.WEAPONS.FD280,
    ammoThreshold = config.red.ground.missileSystemTypes.mlrs.ammoThreshold,
    transloader = "Ammo Sec, 1st Bn, 1st Rockets Arty Bde",
    dbid = constants.PLATFORMS.PHL16,
    missileSystem = "PHL-16",
  },
  ["6th Bn, 73rd Arty Bde"] = {
    name = "6th Bn, 73rd Arty Bde",
    msg = "Radio source, Bty",
    state = constants.MISSILE_UNIT_POSTURE.HIDE,
    operationalArea = constants.OPERATIONAL_AREAS.YMC,
    weaponDBID = constants.WEAPONS.FD280,
    ammoThreshold = config.red.ground.missileSystemTypes.mlrs.ammoThreshold,
    transloader = "Ammo Sec, 6th Bn, 73rd Arty Bde",
    dbid = constants.PLATFORMS.PHL16,
    missileSystem = "PHL-16",
  },
}


-- ============================================================================
-- GLCM (China)
-- ============================================================================

config.red.ground.missileSystemTypes.glcm = {}
config.red.ground.missileSystemTypes.glcm.weaponCountDefault = 120
config.red.ground.missileSystemTypes.glcm.ammoThreshold = 55
config.red.ground.missileSystemTypes.glcm.contactAge = 30 * 60
config.red.ground.missileSystemTypes.glcm.reloadTime = 45 * 60
config.red.ground.missileSystemTypes.glcm.stowTime = 5 * 60
config.red.ground.missileSystemTypes.glcm.canisterStocks = {
  ["Ammo Revetment, 635th Bde, PLARF"] = {
    name = "Ammo Revetment, 635th Bde, PLARF",
    weaponCountCurrent = config.red.ground.missileSystemTypes.glcm.weaponCountDefault / 2,
    weaponCountDefault = config.red.ground.missileSystemTypes.glcm.weaponCountDefault / 2,
  },
}
config.red.ground.missileSystemTypes.glcm.transloaders = {
  ["Ammo Sec, 635th Bde, PLARF"] = {
    name = "Ammo Sec, 635th Bde, PLARF",
    weaponCountCurrent = config.red.ground.missileSystemTypes.glcm.weaponCountDefault / 2,
    weaponCountDefault = config.red.ground.missileSystemTypes.glcm.weaponCountDefault / 2,
    unitCount = 5,
    operationalArea = constants.OPERATIONAL_AREAS.TXI,
    state = constants.MISSILE_UNIT_POSTURE.STATIC,
    canisterStock = "Ammo Revetment, 635th Bde, PLARF",
    launcher = "635th Bde, PLARF"
  },
}
config.red.ground.missileSystemTypes.glcm.launchers = {
  ["635th Bde, PLARF"] = {
    name = "635th Bde, PLARF",
    msg = "Radio source, Bty",
    state = constants.MISSILE_UNIT_POSTURE.HIDE,
    operationalArea = constants.OPERATIONAL_AREAS.TXI,
    weaponDBID = constants.WEAPONS.CJ10A,
    ammoThreshold = config.red.ground.missileSystemTypes.glcm.ammoThreshold,
    transloader = "Ammo Sec, 635th Bde, PLARF",
    dbid = constants.PLATFORMS.CUSTOMED_SSM,
    missileSystem = "CJ-10A",
    mountDescriptors = constants.MOUNT_DESCRIPTORS.CH_SSC_9,
  },
}


-- ============================================================================
-- SRBM (China)
-- ============================================================================

config.red.ground.missileSystemTypes.srbm = {}
config.red.ground.missileSystemTypes.srbm.weaponCountDefault = 36
config.red.ground.missileSystemTypes.srbm.ammoThreshold = 55
config.red.ground.missileSystemTypes.srbm.contactAge = 30 * 60
config.red.ground.missileSystemTypes.srbm.reloadTime = 5 * 60
config.red.ground.missileSystemTypes.srbm.stowTime = 5 * 60
config.red.ground.missileSystemTypes.srbm.canisterStocks = {
  ["Ammo Revetment, 613rd Bde, PLARF"] = {
    name = "Ammo Revetment, 613rd Bde, PLARF",
    weaponCountCurrent = config.red.ground.missileSystemTypes.srbm.weaponCountDefault * 2,
    weaponCountDefault = config.red.ground.missileSystemTypes.srbm.weaponCountDefault * 2,
  },
  ["Ammo Revetment, 614th Bde, PLARF"] = {
    name = "Ammo Revetment, 614th Bde, PLARF",
    weaponCountCurrent = config.red.ground.missileSystemTypes.srbm.weaponCountDefault * 2,
    weaponCountDefault = config.red.ground.missileSystemTypes.srbm.weaponCountDefault * 2,
  },
  ["Ammo Revetment, 615th Bde, PLARF"] = {
    name = "Ammo Revetment, 615th Bde, PLARF",
    weaponCountCurrent = config.red.ground.missileSystemTypes.srbm.weaponCountDefault * 2,
    weaponCountDefault = config.red.ground.missileSystemTypes.srbm.weaponCountDefault * 2,
  },
  ["Ammo Revetment, 616th Bde, PLARF"] = {
    name = "Ammo Revetment, 616th Bde, PLARF",
    weaponCountCurrent = config.red.ground.missileSystemTypes.srbm.weaponCountDefault * 2,
    weaponCountDefault = config.red.ground.missileSystemTypes.srbm.weaponCountDefault * 2,
  },
  ["Ammo Revetment, 617th Bde, PLARF"] = {
    name = "Ammo Revetment, 617th Bde, PLARF",
    weaponCountCurrent = config.red.ground.missileSystemTypes.srbm.weaponCountDefault * 2,
    weaponCountDefault = config.red.ground.missileSystemTypes.srbm.weaponCountDefault * 2,
  },
  ["Ammo Revetment, 636th Bde, PLARF"] = {
    name = "Ammo Revetment, 636th Bde, PLARF",
    weaponCountCurrent = config.red.ground.missileSystemTypes.srbm.weaponCountDefault * 2,
    weaponCountDefault = config.red.ground.missileSystemTypes.srbm.weaponCountDefault * 2,
  },
}
config.red.ground.missileSystemTypes.srbm.transloaders = {
  ["Ammo Sec, 613rd Bde, PLARF"] = {
    name = "Ammo Sec, 613rd Bde, PLARF",
    weaponCountCurrent = config.red.ground.missileSystemTypes.srbm.weaponCountDefault,
    weaponCountDefault = config.red.ground.missileSystemTypes.srbm.weaponCountDefault,
    unitCount = 6,
    operationalArea = constants.OPERATIONAL_AREAS.XZL,
    state = constants.MISSILE_UNIT_POSTURE.STATIC,
    canisterStock = "Ammo Revetment, 613rd Bde, PLARF",
    launcher = "613rd Bde, PLARF"
  },
  ["Ammo Sec, 614th Bde, PLARF"] = {
    name = "Ammo Sec, 614th Bde, PLARF",
    weaponCountCurrent = config.red.ground.missileSystemTypes.srbm.weaponCountDefault,
    weaponCountDefault = config.red.ground.missileSystemTypes.srbm.weaponCountDefault,
    unitCount = 6,
    operationalArea = constants.OPERATIONAL_AREAS.GSU,
    state = constants.MISSILE_UNIT_POSTURE.STATIC,
    canisterStock = "Ammo Revetment, 614th Bde, PLARF",
    launcher = "614th Bde, PLARF"
  },
  ["Ammo Sec, 615th Bde, PLARF"] = {
    name = "Ammo Sec, 615th Bde, PLARF",
    weaponCountCurrent = config.red.ground.missileSystemTypes.srbm.weaponCountDefault,
    weaponCountDefault = config.red.ground.missileSystemTypes.srbm.weaponCountDefault,
    unitCount = 6,
    operationalArea = constants.OPERATIONAL_AREAS.HUZ,
    state = constants.MISSILE_UNIT_POSTURE.STATIC,
    canisterStock = "Ammo Revetment, 615th Bde, PLARF",
    launcher = "615th Bde, PLARF"
  },
  ["Ammo Sec, 616th Bde, PLARF"] = {
    name = "Ammo Sec, 616th Bde, PLARF",
    weaponCountCurrent = config.red.ground.missileSystemTypes.srbm.weaponCountDefault,
    weaponCountDefault = config.red.ground.missileSystemTypes.srbm.weaponCountDefault,
    unitCount = 6,
    operationalArea = constants.OPERATIONAL_AREAS.IDP,
    state = constants.MISSILE_UNIT_POSTURE.STATIC,
    canisterStock = "Ammo Revetment, 616th Bde, PLARF",
    launcher = "616th Bde, PLARF"
  },
  ["Ammo Sec, 617th Bde, PLARF"] = {
    name = "Ammo Sec, 617th Bde, PLARF",
    weaponCountCurrent = config.red.ground.missileSystemTypes.srbm.weaponCountDefault,
    weaponCountDefault = config.red.ground.missileSystemTypes.srbm.weaponCountDefault,
    unitCount = 9,
    operationalArea = constants.OPERATIONAL_AREAS.GMJ,
    state = constants.MISSILE_UNIT_POSTURE.STATIC,
    canisterStock = "Ammo Revetment, 617th Bde, PLARF",
    launcher = "617th Bde, PLARF"
  },
  ["Ammo Sec, 636th Bde, PLARF"] = {
    name = "Ammo Sec, 636th Bde, PLARF",
    weaponCountCurrent = config.red.ground.missileSystemTypes.srbm.weaponCountDefault,
    weaponCountDefault = config.red.ground.missileSystemTypes.srbm.weaponCountDefault,
    unitCount = 9,
    operationalArea = constants.OPERATIONAL_AREAS.HMJ,
    state = constants.MISSILE_UNIT_POSTURE.STATIC,
    canisterStock = "Ammo Revetment, 636th Bde, PLARF",
    launcher = "636th Bde, PLARF"
  },
}
config.red.ground.missileSystemTypes.srbm.launchers = {
  ["613rd Bde, PLARF"] = {
    name = "613rd Bde, PLARF",
    msg = "Radio source, Bty",
    state = constants.MISSILE_UNIT_POSTURE.HIDE,
    operationalArea = constants.OPERATIONAL_AREAS.XZL,
    weaponDBID = constants.WEAPONS.DF15B,
    ammoThreshold = config.red.ground.missileSystemTypes.srbm.ammoThreshold,
    transloader = "Ammo Sec, 613rd Bde, PLARF",
    dbid = constants.PLATFORMS.CUSTOMED_SSM,
    missileSystem = "DF-15B",
    mountDescriptors = constants.MOUNT_DESCRIPTORS.CSS6_MOD3,
  },
  ["614th Bde, PLARF"] = {
    name = "614th Bde, PLARF",
    msg = "Radio source, Bty",
    state = constants.MISSILE_UNIT_POSTURE.HIDE,
    operationalArea = constants.OPERATIONAL_AREAS.GSU,
    weaponDBID = constants.WEAPONS.DF11A,
    ammoThreshold = config.red.ground.missileSystemTypes.srbm.ammoThreshold,
    transloader = "Ammo Sec, 614th Bde, PLARF",
    dbid = constants.PLATFORMS.CUSTOMED_SSM,
    missileSystem = "DF-11A",
    mountDescriptors = constants.MOUNT_DESCRIPTORS.CSS7_MOD2,
  },
  ["615th Bde, PLARF"] = {
    name = "615th Bde, PLARF",
    msg = "Radio source, Bty",
    state = constants.MISSILE_UNIT_POSTURE.HIDE,
    operationalArea = constants.OPERATIONAL_AREAS.HUZ,
    weaponDBID = constants.WEAPONS.DF11A,
    ammoThreshold = config.red.ground.missileSystemTypes.srbm.ammoThreshold,
    transloader = "Ammo Sec, 615th Bde, PLARF",
    dbid = constants.PLATFORMS.CUSTOMED_SSM,
    missileSystem = "DF-11A",
    mountDescriptors = constants.MOUNT_DESCRIPTORS.CSS7_MOD2,
  },
  ["616th Bde, PLARF"] = {
    name = "616th Bde, PLARF",
    msg = "Radio source, Bty",
    state = constants.MISSILE_UNIT_POSTURE.HIDE,
    operationalArea = constants.OPERATIONAL_AREAS.IDP,
    weaponDBID = constants.WEAPONS.DF15C,
    ammoThreshold = config.red.ground.missileSystemTypes.srbm.ammoThreshold,
    transloader = "Ammo Sec, 616th Bde, PLARF",
    dbid = constants.PLATFORMS.CUSTOMED_SSM,
    missileSystem = "DF-15C",
    mountDescriptors = constants.MOUNT_DESCRIPTORS.CSS6_MOD2,
  },
  ["617th Bde, PLARF"] = {
    name = "617th Bde, PLARF",
    msg = "Radio source, Bty",
    state = constants.MISSILE_UNIT_POSTURE.HIDE,
    operationalArea = constants.OPERATIONAL_AREAS.GMJ,
    weaponDBID = constants.WEAPONS.DF16A,
    ammoThreshold = config.red.ground.missileSystemTypes.srbm.ammoThreshold,
    transloader = "Ammo Sec, 617th Bde, PLARF",
    dbid = constants.PLATFORMS.CUSTOMED_SSM,
    missileSystem = "DF-16A",
    mountDescriptors = constants.MOUNT_DESCRIPTORS.CSS11_MOD1,
  },
  ["636th Bde, PLARF"] = {
    name = "636th Bde, PLARF",
    msg = "Radio source, Bty",
    state = constants.MISSILE_UNIT_POSTURE.HIDE,
    operationalArea = constants.OPERATIONAL_AREAS.HMJ,
    weaponDBID = constants.WEAPONS.DF16A,
    ammoThreshold = config.red.ground.missileSystemTypes.srbm.ammoThreshold,
    transloader = "Ammo Sec, 636th Bde, PLARF",
    dbid = constants.PLATFORMS.CUSTOMED_SSM,
    missileSystem = "DF-16A",
    mountDescriptors = constants.MOUNT_DESCRIPTORS.CSS11_MOD1,
  },
}


-- ============================================================================
-- MRBM (China)
-- ============================================================================

config.red.ground.missileSystemTypes.mrbm = {}
config.red.ground.missileSystemTypes.mrbm.weaponCountDefault = 24
config.red.ground.missileSystemTypes.mrbm.ammoThreshold = 55
config.red.ground.missileSystemTypes.mrbm.contactAge = 30 * 60
config.red.ground.missileSystemTypes.mrbm.reloadTime = 5 * 60
config.red.ground.missileSystemTypes.mrbm.stowTime = 5 * 60
config.red.ground.missileSystemTypes.mrbm.canisterStocks = {
  ["Ammo Revetment, 624th Bde, PLARF"] = {
    name = "Ammo Revetment, 624th Bde, PLARF",
    weaponCountCurrent = config.red.ground.missileSystemTypes.mrbm.weaponCountDefault * 2,
    weaponCountDefault = config.red.ground.missileSystemTypes.mrbm.weaponCountDefault * 2,
  },
}
config.red.ground.missileSystemTypes.mrbm.transloaders = {
  ["Ammo Sec, 624th Bde, PLARF"] = {
    name = "Ammo Sec, 624th Bde, PLARF",
    weaponCountCurrent = config.red.ground.missileSystemTypes.mrbm.weaponCountDefault,
    weaponCountDefault = config.red.ground.missileSystemTypes.mrbm.weaponCountDefault,
    unitCount = 6,
    operationalArea = constants.OPERATIONAL_AREAS.ZWQ,
    state = constants.MISSILE_UNIT_POSTURE.STATIC,
    canisterStock = "Ammo Revetment, 624th Bde, PLARF",
    launcher = "624th Bde, PLARF"
  },
}
config.red.ground.missileSystemTypes.mrbm.launchers = {
  ["624th Bde, PLARF"] = {
    name = "624th Bde, PLARF",
    msg = "Radio source, Bty",
    state = constants.MISSILE_UNIT_POSTURE.HIDE,
    operationalArea = constants.OPERATIONAL_AREAS.ZWQ,
    weaponDBID = constants.WEAPONS.DF21D,
    ammoThreshold = config.red.ground.missileSystemTypes.mrbm.ammoThreshold,
    transloader = "Ammo Sec, 624th Bde, PLARF",
    dbid = constants.PLATFORMS.CUSTOMED_SSM,
    missileSystem = "DF-21D",
    mountDescriptors = constants.MOUNT_DESCRIPTORS.CSS5_MOD5,
  },
}


-- ============================================================================
-- ASCM (China)
-- ============================================================================

config.red.ground.missileSystemTypes.ascm = {}
config.red.ground.missileSystemTypes.ascm.weaponCountDefault = 12
config.red.ground.missileSystemTypes.ascm.ammoThreshold = 55
config.red.ground.missileSystemTypes.ascm.contactAge = 30 * 60
config.red.ground.missileSystemTypes.ascm.reloadTime = 5 * 60
config.red.ground.missileSystemTypes.ascm.stowTime = 5 * 60
config.red.ground.missileSystemTypes.ascm.canisterStocks = {
  ["Ammo Revetment, 1st Pili Reg"] = {
    name = "Ammo Revetment, 1st Pili Reg",
    weaponCountCurrent = config.red.ground.missileSystemTypes.ascm.weaponCountDefault * 2,
    weaponCountDefault = config.red.ground.missileSystemTypes.ascm.weaponCountDefault * 2,
  },
}
config.red.ground.missileSystemTypes.ascm.transloaders = {
  ["Ammo Sec, 1st Pili Reg"] = {
    name = "Ammo Sec, 1st Pili Reg",
    weaponCountCurrent = config.red.ground.missileSystemTypes.ascm.weaponCountDefault,
    weaponCountDefault = config.red.ground.missileSystemTypes.ascm.weaponCountDefault,
    unitCount = 1,
    operationalArea = constants.OPERATIONAL_AREAS.RCU,
    state = constants.MISSILE_UNIT_POSTURE.STATIC,
    canisterStock = "Ammo Revetment, 1st Pili Reg",
    launcher = "1st Pili Reg"
  },
}
config.red.ground.missileSystemTypes.ascm.launchers = {
  ["1st Pili Reg"] = {
    name = "1st Pili Reg",
    msg = "Radio source, Bty",
    state = constants.MISSILE_UNIT_POSTURE.HIDE,
    operationalArea = constants.OPERATIONAL_AREAS.RCU,
    weaponDBID = constants.WEAPONS.YJ12,
    ammoThreshold = config.red.ground.missileSystemTypes.ascm.ammoThreshold,
    transloader = "Ammo Sec, 1st Pili Reg",
    dbid = constants.PLATFORMS.CUSTOMED_SSM,
    missileSystem = "YJ-12",
    mountDescriptors = constants.MOUNT_DESCRIPTORS.YJ12,
  },
}


-- ============================================================================
-- SAM (China)
-- ============================================================================

config.red.ground.missileSystemTypes.sam = {}
config.red.ground.missileSystemTypes.sam.weaponCountDefault = 16
config.red.ground.missileSystemTypes.sam.ammoThreshold = 55
config.red.ground.missileSystemTypes.sam.contactAge = 15 * 60
config.red.ground.missileSystemTypes.sam.reloadTime = 5 * 60
config.red.ground.missileSystemTypes.sam.stowTime = 5 * 60
config.red.ground.missileSystemTypes.sam.canisterStocks = {
  ["Ammo Revetment, 94695 Unit, PLAAF"] = {
    name = "Ammo Revetment, 94695 Unit, PLAAF",
    weaponCountCurrent = config.red.ground.missileSystemTypes.sam.weaponCountDefault * 2,
    weaponCountDefault = config.red.ground.missileSystemTypes.sam.weaponCountDefault * 2,
  },
  ["Ammo Revetment, 94759 Unit, PLAAF"] = {
    name = "Ammo Revetment, 94759 Unit, PLAAF",
    weaponCountCurrent = config.red.ground.missileSystemTypes.sam.weaponCountDefault * 2,
    weaponCountDefault = config.red.ground.missileSystemTypes.sam.weaponCountDefault * 2,
  },
  ["Ammo Revetment, 94774 Unit, PLAAF"] = {
    name = "Ammo Revetment, 94774 Unit, PLAAF",
    weaponCountCurrent = config.red.ground.missileSystemTypes.sam.weaponCountDefault * 2,
    weaponCountDefault = config.red.ground.missileSystemTypes.sam.weaponCountDefault * 2,
  },
  ["Ammo Revetment, 94777 Unit, PLAAF"] = {
    name = "Ammo Revetment, 94777 Unit, PLAAF",
    weaponCountCurrent = config.red.ground.missileSystemTypes.sam.weaponCountDefault * 2,
    weaponCountDefault = config.red.ground.missileSystemTypes.sam.weaponCountDefault * 2,
  },
  ["Ammo Revetment, 94807 Unit, PLAAF"] = {
    name = "Ammo Revetment, 94807 Unit, PLAAF",
    weaponCountCurrent = config.red.ground.missileSystemTypes.sam.weaponCountDefault * 2,
    weaponCountDefault = config.red.ground.missileSystemTypes.sam.weaponCountDefault * 2,
  },
  ["Ammo Revetment, 94908 Unit, PLAAF"] = {
    name = "Ammo Revetment, 94908 Unit, PLAAF",
    weaponCountCurrent = config.red.ground.missileSystemTypes.sam.weaponCountDefault * 2,
    weaponCountDefault = config.red.ground.missileSystemTypes.sam.weaponCountDefault * 2,
  },
  ["Ammo Revetment, 94967 Unit, PLAAF"] = {
    name = "Ammo Revetment, 94967 Unit, PLAAF",
    weaponCountCurrent = config.red.ground.missileSystemTypes.sam.weaponCountDefault * 2,
    weaponCountDefault = config.red.ground.missileSystemTypes.sam.weaponCountDefault * 2,
  },
  ["Ammo Revetment, 95324 Unit, PLAAF"] = {
    name = "Ammo Revetment, 95324 Unit, PLAAF",
    weaponCountCurrent = config.red.ground.missileSystemTypes.sam.weaponCountDefault * 2,
    weaponCountDefault = config.red.ground.missileSystemTypes.sam.weaponCountDefault * 2,
  },
}
config.red.ground.missileSystemTypes.sam.transloaders = {
  ["Ammo Sec, 94695 Unit, PLAAF"] = {
    name = "Ammo Sec, 94695 Unit, PLAAF",
    weaponCountCurrent = config.red.ground.missileSystemTypes.sam.weaponCountDefault,
    weaponCountDefault = config.red.ground.missileSystemTypes.sam.weaponCountDefault,
    unitCount = 1,
    operationalArea = constants.OPERATIONAL_AREAS.QXV,
    state = constants.MISSILE_UNIT_POSTURE.STATIC,
    canisterStock = "Ammo Revetment, 94695 Unit, PLAAF",
    launcher = "94695 Unit, PLAAF"
  },
  ["Ammo Sec, 94759 Unit, PLAAF"] = {
    name = "Ammo Sec, 94759 Unit, PLAAF",
    weaponCountCurrent = config.red.ground.missileSystemTypes.sam.weaponCountDefault,
    weaponCountDefault = config.red.ground.missileSystemTypes.sam.weaponCountDefault,
    unitCount = 1,
    operationalArea = constants.OPERATIONAL_AREAS.URF,
    state = constants.MISSILE_UNIT_POSTURE.STATIC,
    canisterStock = "Ammo Revetment, 94759 Unit, PLAAF",
    launcher = "94759 Unit, PLAAF"
  },
  ["Ammo Sec, 94774 Unit, PLAAF"] = {
    name = "Ammo Sec, 94774 Unit, PLAAF",
    weaponCountCurrent = config.red.ground.missileSystemTypes.sam.weaponCountDefault,
    weaponCountDefault = config.red.ground.missileSystemTypes.sam.weaponCountDefault,
    unitCount = 1,
    operationalArea = constants.OPERATIONAL_AREAS.WEP,
    state = constants.MISSILE_UNIT_POSTURE.STATIC,
    canisterStock = "Ammo Revetment, 94774 Unit, PLAAF",
    launcher = "94774 Unit, PLAAF"
  },
  ["Ammo Sec, 94777 Unit, PLAAF"] = {
    name = "Ammo Sec, 94777 Unit, PLAAF",
    weaponCountCurrent = config.red.ground.missileSystemTypes.sam.weaponCountDefault,
    weaponCountDefault = config.red.ground.missileSystemTypes.sam.weaponCountDefault,
    unitCount = 1,
    operationalArea = constants.OPERATIONAL_AREAS.EAJ,
    state = constants.MISSILE_UNIT_POSTURE.STATIC,
    canisterStock = "Ammo Revetment, 94777 Unit, PLAAF",
    launcher = "94777 Unit, PLAAF"
  },
  ["Ammo Sec, 94807 Unit, PLAAF"] = {
    name = "Ammo Sec, 94807 Unit, PLAAF",
    weaponCountCurrent = config.red.ground.missileSystemTypes.sam.weaponCountDefault,
    weaponCountDefault = config.red.ground.missileSystemTypes.sam.weaponCountDefault,
    unitCount = 1,
    operationalArea = constants.OPERATIONAL_AREAS.IDC,
    state = constants.MISSILE_UNIT_POSTURE.STATIC,
    canisterStock = "Ammo Revetment, 94807 Unit, PLAAF",
    launcher = "94807 Unit, PLAAF"
  },
  ["Ammo Sec, 94908 Unit, PLAAF"] = {
    name = "Ammo Sec, 94908 Unit, PLAAF",
    weaponCountCurrent = config.red.ground.missileSystemTypes.sam.weaponCountDefault,
    weaponCountDefault = config.red.ground.missileSystemTypes.sam.weaponCountDefault,
    unitCount = 1,
    operationalArea = constants.OPERATIONAL_AREAS.OJM,
    state = constants.MISSILE_UNIT_POSTURE.STATIC,
    canisterStock = "Ammo Revetment, 94908 Unit, PLAAF",
    launcher = "94908 Unit, PLAAF"
  },
  ["Ammo Sec, 94967 Unit, PLAAF"] = {
    name = "Ammo Sec, 94967 Unit, PLAAF",
    weaponCountCurrent = config.red.ground.missileSystemTypes.sam.weaponCountDefault,
    weaponCountDefault = config.red.ground.missileSystemTypes.sam.weaponCountDefault,
    unitCount = 1,
    operationalArea = constants.OPERATIONAL_AREAS.LPU,
    state = constants.MISSILE_UNIT_POSTURE.STATIC,
    canisterStock = "Ammo Revetment, 94967 Unit, PLAAF",
    launcher = "94967 Unit, PLAAF"
  },
  ["Ammo Sec, 95324 Unit, PLAAF"] = {
    name = "Ammo Sec, 95324 Unit, PLAAF",
    weaponCountCurrent = config.red.ground.missileSystemTypes.sam.weaponCountDefault,
    weaponCountDefault = config.red.ground.missileSystemTypes.sam.weaponCountDefault,
    unitCount = 1,
    operationalArea = constants.OPERATIONAL_AREAS.KRO,
    state = constants.MISSILE_UNIT_POSTURE.STATIC,
    canisterStock = "Ammo Revetment, 95324 Unit, PLAAF",
    launcher = "95324 Unit, PLAAF"
  },
}
config.red.ground.missileSystemTypes.sam.launchers = {
  ["94695 Unit, PLAAF"] = {
    name = "94695 Unit, PLAAF",
    msg = "Radio source, Bty",
    state = constants.MISSILE_UNIT_POSTURE.STATIC,
    operationalArea = constants.OPERATIONAL_AREAS.QXV,
    weaponDBID = { constants.WEAPONS.SA20, constants.WEAPONS.SA16 },
    ammoThreshold = config.red.ground.missileSystemTypes.sam.ammoThreshold,
    transloader = "Ammo Sec, 94695 Unit, PLAAF",
    dbid = constants.PLATFORMS.S300,
    missileSystem = "S-300",
  },
  ["94759 Unit, PLAAF"] = {
    name = "94759 Unit, PLAAF",
    msg = "Radio source, Bty",
    state = constants.MISSILE_UNIT_POSTURE.STATIC,
    operationalArea = constants.OPERATIONAL_AREAS.URF,
    weaponDBID = { constants.WEAPONS.SA20, constants.WEAPONS.SA16 },
    ammoThreshold = config.red.ground.missileSystemTypes.sam.ammoThreshold,
    transloader = "Ammo Sec, 94759 Unit, PLAAF",
    dbid = constants.PLATFORMS.S300,
    missileSystem = "S-300",
  },
  ["94774 Unit, PLAAF"] = {
    name = "94774 Unit, PLAAF",
    msg = "Radio source, Bty",
    state = constants.MISSILE_UNIT_POSTURE.STATIC,
    operationalArea = constants.OPERATIONAL_AREAS.WEP,
    weaponDBID = { constants.WEAPONS.SA20, constants.WEAPONS.SA16 },
    ammoThreshold = config.red.ground.missileSystemTypes.sam.ammoThreshold,
    transloader = "Ammo Sec, 94774 Unit, PLAAF",
    dbid = constants.PLATFORMS.S300,
    missileSystem = "S-300",
  },
  ["94777 Unit, PLAAF"] = {
    name = "94777 Unit, PLAAF",
    msg = "Radio source, Bty",
    state = constants.MISSILE_UNIT_POSTURE.STATIC,
    operationalArea = constants.OPERATIONAL_AREAS.EAJ,
    weaponDBID = { constants.WEAPONS.SA20, constants.WEAPONS.SA16 },
    ammoThreshold = config.red.ground.missileSystemTypes.sam.ammoThreshold,
    transloader = "Ammo Sec, 94777 Unit, PLAAF",
    dbid = constants.PLATFORMS.S300,
    missileSystem = "S-300",
  },
  ["94807 Unit, PLAAF"] = {
    name = "94807 Unit, PLAAF",
    msg = "Radio source, Bty",
    state = constants.MISSILE_UNIT_POSTURE.STATIC,
    operationalArea = constants.OPERATIONAL_AREAS.IDC,
    weaponDBID = { constants.WEAPONS.SA20, constants.WEAPONS.SA16 },
    ammoThreshold = config.red.ground.missileSystemTypes.sam.ammoThreshold,
    transloader = "Ammo Sec, 94807 Unit, PLAAF",
    dbid = constants.PLATFORMS.S300,
    missileSystem = "S-300",
  },
  ["94908 Unit, PLAAF"] = {
    name = "94908 Unit, PLAAF",
    msg = "Radio source, Bty",
    state = constants.MISSILE_UNIT_POSTURE.STATIC,
    operationalArea = constants.OPERATIONAL_AREAS.OJM,
    weaponDBID = { constants.WEAPONS.SA20, constants.WEAPONS.SA16 },
    ammoThreshold = config.red.ground.missileSystemTypes.sam.ammoThreshold,
    transloader = "Ammo Sec, 94908 Unit, PLAAF",
    dbid = constants.PLATFORMS.S300,
    missileSystem = "S-300",
  },
  ["94967 Unit, PLAAF"] = {
    name = "94967 Unit, PLAAF",
    msg = "Radio source, Bty",
    state = constants.MISSILE_UNIT_POSTURE.STATIC,
    operationalArea = constants.OPERATIONAL_AREAS.LPU,
    weaponDBID = { constants.WEAPONS.SA20, constants.WEAPONS.SA16 },
    ammoThreshold = config.red.ground.missileSystemTypes.sam.ammoThreshold,
    transloader = "Ammo Sec, 94967 Unit, PLAAF",
    dbid = constants.PLATFORMS.S300,
    missileSystem = "S-300",
  },
  ["95324 Unit, PLAAF"] = {
    name = "95324 Unit, PLAAF",
    msg = "Radio source, Bty",
    state = constants.MISSILE_UNIT_POSTURE.STATIC,
    operationalArea = constants.OPERATIONAL_AREAS.KRO,
    weaponDBID = { constants.WEAPONS.SA20, constants.WEAPONS.SA16 },
    ammoThreshold = config.red.ground.missileSystemTypes.sam.ammoThreshold,
    transloader = "Ammo Sec, 95324 Unit, PLAAF",
    dbid = constants.PLATFORMS.S300,
    missileSystem = "S-300",
  },
}


-- ============================================================================
-- Reconnaissance (China)
-- ============================================================================

config.red.recon = {}
config.red.recon.observationWindowSec = 30 * 60
-- Active FSEMs older than this are retired by FsemBuilder so their launchers
-- return to the assignable pool. Aligned with observationWindowSec (competing
-- operations wait at most 30 min) and c.ground.srbm.contactAge (older targeting
-- data is stale anyway); production templates deploy well inside this window.
config.red.recon.fsemStaleAfterSec = 30 * 60
config.red.recon.templates = {
  BZK005_RECON_1 = {
    templateId = "BZK005_RECON_1",
    type = "UAV",
    reconObjectiveId = "C2_NORTH_TARGETING",
    baseGUID = constants.BASES.LONGTIAN_AAB,
    unitDBID = constants.PLATFORMS.BZK005,
    course = constants.COURSES.BZK005_1,
    speed = 115,
    isTracking = false
  },
  BZK005_RECON_2 = {
    templateId = "BZK005_RECON_2",
    type = "UAV",
    baseGUID = constants.BASES.SHANTOU_WAISHA_AB,
    unitDBID = constants.PLATFORMS.BZK005,
    course = constants.COURSES.BZK005_2,
    speed = 115,
    isTracking = false
  },
  WZ8_RECON_ISLAND = {
    templateId = "WZ8_RECON_ISLAND",
    type = "UAV",
    reconObjectiveId = "TAIWAN_STRAIT_STRIKE_TARGETING",
    baseGUID = constants.BASES.LIUAN_AB,
    unitDBID = constants.PLATFORMS.H6N,
    course = constants.COURSES.H6N,
    speed = 450,
    -- The H-6N launches, then launchWZ8.lua hands the entry over to the WZ-8 it releases.
    -- speed above stays the H-6N cruise used for flight-time estimation; this is what the
    -- WZ-8 is told to fly while shadowing a contact.
    trackingSpeed = 3300,
    isTracking = true
  },
  WZ7_RECON_1 = {
    templateId = "WZ7_RECON_1",
    type = "UAV",
    baseGUID = constants.BASES.LONGTIAN_AAB,
    unitDBID = constants.PLATFORMS.WZ7,
    course = constants.COURSES.BZK005_1,
    speed = 450,
    isTracking = false
  },
  TB001_RECON_1 = {
    templateId = "TB001_RECON_1",
    type = "UAV",
    baseGUID = constants.BASES.LONGTIAN_AAB,
    unitDBID = constants.PLATFORMS.TB001,
    course = constants.COURSES.BZK005_1,
    speed = 135,
    isTracking = false
  },
  GJ11_RECON = {
    templateId = "GJ11_RECON",
    type = "UAV",
    reconObjectiveId = "LANDING_SUPPORT_NORTH",
    baseGUID = "Type 076",
    unitDBID = constants.PLATFORMS.GJ11,
    course = constants.COURSES.GJ11,
    speed = 600,
    isTracking = false
  }
}
config.red.recon.strikeMappings = {
  C2_NORTH_TARGETING = {
    { name = "GND/STRIKE/C2/N/1", type = "ground", }
  },
  LANDING_SUPPORT_NORTH = {
    { name = "AIR/CAS/TROOPS/N/1", type = "air", },
    { name = "GND/STRIKE/C2/N/1",  type = "ground", },
  },
  TAIWAN_STRAIT_STRIKE_TARGETING = {
    { name = "GND/ASUW/SHIP/E/1",      type = "ground" },
    { name = "GND/ASUW/SHIP/N/1",      type = "ground" },
    { name = "AIR/ASUW/SHIP/N/1",      type = "air" },
    { name = "AIR/STRIKE/AB/E/1",      type = "air",   requiresLACM = true },
    { name = "AIR/STRIKE/AB/W/1",      type = "air" },
    { name = "GND/STRIKE/INFRA/ALL/1", type = "ground" },
  },
  FIXED_SITE_TARGETING = {
    { name = "AIR/STRIKE/AB/W/1",        type = "air" },
    { name = "AIR/STRIKE/AB/E/1",        type = "air",   requiresLACM = true },
    { name = "GND/STRIKE/HELIPAD/ALL/1", type = "ground" },
    { name = "GND/STRIKE/INFRA/ALL/1",   type = "ground" },
  },
  C2_EMITTER_TARGETING = {
    { name = "GND/STRIKE/C2/N/1", type = "ground" },
    { name = "GND/STRIKE/C2/C/1", type = "ground" }
  }
}
config.red.recon.frontlineRedirect = {
  enabled = true,
  attritionThresholdPct = 50,
  frontlineBaseNames = {
    "Shantou Waisha AB (PLAAF)",
    "Huian AAB",
    "Zhangzhou-Longxi AB (PLAAF)",
    "Zhangpu AAB",
    "Longtian AAB"
  },
  mappings = {
    { fromPrefix = "AIR/STRIKE/AB/W/", toPrefix = "AIR/STRIKE/AB/W/AAR/", type = "air" },
  },
}
config.red.recon.queue = {
  -- A UAV may be authored here instead of going through Recon.addEntry, in which case it
  -- must carry its own takeoffTime and endTime. Run-state fields (hasLaunched, isFinished,
  -- unitGUID, trackingTargetGUID) are filled in by initQueue, not listed here.
  -- {
  --   type = "UAV",
  --   templateId = "H6N_RECON_ISLAND",
  --   baseGUID = constants.BASES.LIUAN_AB,
  --   unitDBID = constants.PLATFORMS.H6N,
  --   course = constants.COURSES.H6N,
  --   speed = 450,
  --   takeoffTime = "2027-06-09 01:00:00",
  --   endTime = "2027-06-09 02:00:00",
  -- },
  {
    type = "satellite",
    reconObjectiveId = "FIXED_SITE_TARGETING",
    endTime = "2027-06-09 01:00:00",
    -- endTime = "2027-06-09 04:40:00",
  },
  {
    type = "SIGINT",
    reconObjectiveId = "C2_EMITTER_TARGETING",
    endTime = "2027-06-09 01:30:00"
  },
  {
    type = "satellite",
    reconObjectiveId = "FIXED_SITE_TARGETING",
    -- endTime = "2027-06-09 01:00:00",
    endTime = "2027-06-09 05:44:00",
  },
  {
    type = "satellite",
    reconObjectiveId = "FIXED_SITE_TARGETING",
    -- endTime = "2027-06-09 01:30:00",
    endTime = "2027-06-09 08:04:00",
  },
  {
    type = "satellite",
    reconObjectiveId = "FIXED_SITE_TARGETING",
    endTime = "2027-06-09 11:25:00",
  },
}
config.red.recon.isTesting = true


-- ============================================================================
-- Aircraft Deployment (China)
-- ============================================================================

config.red.air = {}
-- Fraction of a role's requested aircraft a base must be able to supply before the
-- package is dispatched at all. Below it the package is skipped; at or above it the
-- package launches understrength, since a half-strength strike beats none.
config.red.air.minimumStrengthRatio = 0.5
config.red.air.strikeInterval = 60 * 60
config.red.air.timing = {
  assignmentSafetyMargin = 5 * 60,
  flightTimeSafetyMargin = 5 * 60,
  supportLeadTime = {
    escort = 15 * 60,
    wildWeasel = 15 * 60,
    jammer = 15 * 60,
  },
  tankerSetupTime = 15 * 60,
  tankerUnresolvedArrivalLeadTime = 30 * 60,
  unresolvedFlightTime = {
    striker = 40 * 60,
    support = 20 * 60,
  },
  missionDuration = {
    standard = 40 * 60,
    tanker = 120 * 60,
  },
  cruiseSpeed = {
    combatAircraft = 450,
    tanker = 250,
  },
}
config.red.air.deployedACs = {
  {
    name = "Huizhou Pingtan AB (PLAAF)",
    baseGUID = constants.BASES.HUIZHOU_PINGTAN_AB,
    embarkedUnits = {
      {
        side = constants.SIDES.RED,
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
        side = constants.SIDES.RED,
        type = "Air",
        dbid = constants.PLATFORMS.J16,
        platformName = "J-16",
        name = "7th Air Bde",
        loadouts = {
          { name = "AKD-88 Strike", loadoutId = constants.LOADOUTS.J16_AKD88, num = 24 },
          { name = "PL-15 AAM",     loadoutId = constants.LOADOUTS.J16_PL15,  num = 12, missionName = "CAP/W/3" },
        }
      },
      {
        side = constants.SIDES.RED,
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
      { name = "PL-15 AAM",     loadoutId = constants.LOADOUTS.J16_PL15,  num = 12 },
      { name = "YJ-91 ARM",     loadoutId = constants.LOADOUTS.J16_YJ91,  num = 12 },
    }
  },
  {
    name = "Zhangpu AAB",
    baseGUID = constants.BASES.ZHANGPU_AAB,
    embarkedUnits = {
      -- {
      --   side = constants.SIDES.RED,
      --   type = "Air",
      --   dbid = constants.PLATFORMS.SU30,
      --   platformName = "Su-30",
      --   name = "54th Air Bde",
      --   loadouts = {
      --     { name = "KAB-1500 Strike", loadoutId = constants.LOADOUTS.SU30_KAB1500, num = 12 },
      --   }
      -- },
      {
        side = constants.SIDES.RED,
        type = "Air",
        dbid = constants.PLATFORMS.J16D,
        platformName = "J-16D",
        name = "40th Air Bde",
        loadouts = {
          { name = "Electronic Warfare", loadoutId = constants.LOADOUTS.J16D_OECM, num = 4 },
        }
      },
      {
        side = constants.SIDES.RED,
        type = "Air",
        dbid = constants.PLATFORMS.IL76,
        platformName = "Il-76",
        name = "39th Air Reg",
        loadouts = {
          { name = "Transport", loadoutId = constants.LOADOUTS.IL76_TRANSPORT, num = 3 },
        }
      },
      {
        side = constants.SIDES.RED,
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
      -- { name = "KAB-1500 Strike",    loadoutId = constants.LOADOUTS.SU30_KAB1500, num = 12 }, --KAB-1500 X 2
      { name = "Electronic Warfare", loadoutId = constants.LOADOUTS.J16D_OECM, num = 4 },
    }
  },
  {
    name = "Zhangzhou-Longxi AB (PLAAF)",
    baseGUID = constants.BASES.ZHANGZHOU_LONGXI_AB,
    embarkedUnits = {
      {
        side = constants.SIDES.RED,
        type = "Air",
        dbid = constants.PLATFORMS.SU30,
        platformName = "Su-30",
        name = "54th Air Bde",
        loadouts = {
          { name = "YJ-91 ARM", loadoutId = constants.LOADOUTS.SU30_YJ91, num = 24 },
        }
      },
      {
        side = constants.SIDES.RED,
        type = "Air",
        dbid = constants.PLATFORMS.J16,
        platformName = "J-16",
        name = "83rd Air Bde",
        loadouts = {
          { name = "PL-15 AAM", loadoutId = constants.LOADOUTS.J16_PL15, num = 12, missionName = "CAP/W/2" },
        }
      },
    },
    loadouts = {
      { name = "YJ-91 ARM",       loadoutId = constants.LOADOUTS.SU30_YJ91,    num = 24 }, --YJ-91 X 2
      { name = "PL-15 AAM",       loadoutId = constants.LOADOUTS.J16_PL15,     num = 12 },
      { name = "KAB-1500 Strike", loadoutId = constants.LOADOUTS.SU30_KAB1500, num = 24 }, --KAB-1500 X 2
    }
  },
  {
    name = "Huian AAB",
    baseGUID = constants.BASES.HUIAN_AAB,
    embarkedUnits = {
      {
        side = constants.SIDES.RED,
        type = "Air",
        dbid = constants.PLATFORMS.J16,
        platformName = "J-16",
        name = "83rd Air Bde",
        loadouts = {
          { name = "AKD-88 Strike", loadoutId = constants.LOADOUTS.J16_AKD88, num = 12 },
        }
      },
      {
        side = constants.SIDES.RED,
        type = "Air",
        dbid = constants.PLATFORMS.J20,
        platformName = "J-20",
        name = "41st Air Bde",
        loadouts = {
          { name = "PL-15 AAM", loadoutId = constants.LOADOUTS.J20_PL15, num = 12 },
          { name = "PL-15 AAM", loadoutId = constants.LOADOUTS.J20_PL15, num = 12, missionName = "CAP/W/1" },
        }
      },
    },
    loadouts = {
      { name = "PL-15 AAM",     loadoutId = constants.LOADOUTS.J20_PL15,  num = 24 }, --PL-15 X 4
      { name = "AKD-88 Strike", loadoutId = constants.LOADOUTS.J16_AKD88, num = 12 }, --AKD-88 X 2
      { name = "YJ-91 ARM",     loadoutId = constants.LOADOUTS.J16_YJ91,  num = 12 }, --YJ-91 X 2
    }
  },
  {
    name = "Longtian AAB",
    baseGUID = constants.BASES.LONGTIAN_AAB,
    embarkedUnits = {
      {
        side = constants.SIDES.RED,
        type = "Air",
        dbid = constants.PLATFORMS.BZK005,
        platformName = "BZK-005",
        name = "62nd Det, PLARF UAV Reg",
        loadouts = {
          { name = "Reconnaissance", loadoutId = constants.LOADOUTS.BZK005_RECON, num = 6 },
        }
      },
      {
        side = constants.SIDES.RED,
        type = "Air",
        dbid = constants.PLATFORMS.SU30,
        platformName = "Su-30",
        name = "54th Air Bde",
        loadouts = {
          { name = "YJ-91 ARM", loadoutId = constants.LOADOUTS.SU30_YJ91, num = 16 },
        }
      }
    },
    loadouts = {
      { name = "YJ-91 ARM",       loadoutId = constants.LOADOUTS.SU30_YJ91,    num = 16 }, --YJ-91 X 2
      { name = "KAB-1500 Strike", loadoutId = constants.LOADOUTS.SU30_KAB1500, num = 16 }, --KAB-1500 X 2
    }
  },
  {
    name = "Xingning AB (PLAAF)",
    baseGUID = constants.BASES.XINGNING_AB,
    embarkedUnits = {
      {
        side = constants.SIDES.RED,
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
      -- {
      --   side = constants.SIDES.RED,
      --   type = "Air",
      --   dbid = constants.PLATFORMS.SU30,
      --   platformName = "Su-30",
      --   name = "54th Air Bde",
      --   loadouts = {
      --     { name = "YJ-91 ARM", loadoutId = constants.LOADOUTS.SU30_YJ91, num = 8 },
      --   }
      -- },
      {
        side = constants.SIDES.RED,
        type = "Air",
        dbid = constants.PLATFORMS.J16,
        platformName = "J-16",
        name = "40th Air Bde",
        loadouts = {
          { name = "YJ-83 Anti-Ship", loadoutId = constants.LOADOUTS.J16_YJ83, num = 8 },
        }
      },
      {
        side = constants.SIDES.RED,
        type = "Air",
        dbid = constants.PLATFORMS.KJ500,
        platformName = "KJ-500",
        name = "75th Air Reg",
        loadouts = {
          { name = "AEW", loadoutId = constants.LOADOUTS.KJ500_AEW, num = 3, missionName = "AEW/N" },
        }
      },
      {
        side = constants.SIDES.RED,
        type = "Air",
        dbid = constants.PLATFORMS.HY6U_BADGER,
        platformName = "HY-6U Badger",
        name = "23rd Air Reg",
        loadouts = {
          { name = "Aerial Refueling", loadoutId = constants.LOADOUTS.HY6U_AAR, num = 24, },
        }
      },
      {
        side = constants.SIDES.RED,
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
      -- { name = "YJ-91 ARM",       loadoutId = constants.LOADOUTS.SU30_YJ91,     num = 8 }, --YJ-91 X 2
      { name = "YJ-83 Anti-Ship", loadoutId = constants.LOADOUTS.J16_YJ83,      num = 8 }, --YJ-83 X 2
      { name = "CS-BBC-5 Strike", loadoutId = constants.LOADOUTS.J10C_CS_BBC_5, num = 8 }, --CS-BBC-5 X 2
    }
  },
  {
    name = "Anqing AB (PLAAF)",
    baseGUID = constants.BASES.ANQING_AB,
    embarkedUnits = {
      {
        side = constants.SIDES.RED,
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
        side = constants.SIDES.RED,
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
        side = constants.SIDES.RED,
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
        side = constants.SIDES.RED,
        type = "Air",
        dbid = constants.PLATFORMS.SU30,
        platformName = "Su-30",
        name = "94th Air Bde",
        loadouts = {
          { name = "YJ-91 ARM", loadoutId = constants.LOADOUTS.SU30_YJ91, num = 36 },
        }
      }
    },
    loadouts = {
      { name = "YJ-91 ARM",       loadoutId = constants.LOADOUTS.SU30_YJ91,    num = 36 }, --YJ-91 X 4
      { name = "KAB-1500 Strike", loadoutId = constants.LOADOUTS.SU30_KAB1500, num = 36 }, --KAB-1500 X 2
    }
  },
  {
    name = "Nanchang Xiangtang AB (PLAAF)",
    baseGUID = constants.BASES.XIAHGTANG_AB,
    embarkedUnits = {
      {
        side = constants.SIDES.RED,
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
  {
    name = "Jiaxing AB (PLAAF)",
    baseGUID = constants.BASES.JIAXING_AB,
    embarkedUnits = {
      {
        side = constants.SIDES.RED,
        type = "Air",
        dbid = constants.PLATFORMS.J16,
        platformName = "J-16",
        name = "78th Air Bde",
        loadouts = {
          { name = "AKD-88 Strike", loadoutId = constants.LOADOUTS.J16_AKD88, num = 36 },
        }
      }
    },
    loadouts = {
      { name = "AKD-88 Strike", loadoutId = constants.LOADOUTS.J16_AKD88, num = 36 }, --AKD-88 X 4
      { name = "YJ-91 ARM",     loadoutId = constants.LOADOUTS.J16_YJ91,  num = 36 }, --YJ-91 X 2
    }
  },
  {
    name = "Leiyang AB (PLAAF)",
    baseGUID = constants.BASES.LEIYANG_AB,
    embarkedUnits = {
      {
        side = constants.SIDES.RED,
        type = "Air",
        dbid = constants.PLATFORMS.HY6U_BADGER,
        platformName = "HY-6U Badger",
        name = "23rd Air Reg",
        loadouts = {
          { name = "Aerial Refueling", loadoutId = constants.LOADOUTS.HY6U_AAR, num = 24, },
        }
      }
    },
  },
  {
    name = "Jiujiang Lushan AB (PLAAF)",
    baseGUID = constants.BASES.LUSHAN_AB,
    embarkedUnits = {
      {
        side = constants.SIDES.RED,
        type = "Air",
        dbid = constants.PLATFORMS.KJ500,
        platformName = "KJ-500",
        name = "75th Air Reg",
        loadouts = {
          { name = "AEW", loadoutId = constants.LOADOUTS.KJ500_AEW, num = 3 },
        }
      }
    },
  },
  -- {
  --   name = "Wuyishan AB",
  --   baseGUID = constants.BASES.WUYISHAN_AB,
  --   embarkedUnits = {
  --     {
  --       side = constants.SIDES.RED,
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
  -- {
  --   name = "Rugao AB (PLAAF)",
  --   baseGUID = constants.BASES.RUGAO_AB,
  --   embarkedUnits = {
  --     {
  --       side = constants.SIDES.RED,
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
}


-- ============================================================================
-- Amphibious Operations (China)
-- ============================================================================

-- ZBD-05 * 28 * 4
-- ZTD-05 * 28 * 4
-- PLL-05 * 24
-- PGZ-09 * 6
-- PGZ-95 * 4
-- PLZ-96 * 27
-- SA-15 * 2

-- MC * 32
-- HMMWV * 21
-- ZDB-03 * 21

-- ZBD-04 * 28 * 4
-- ZTZ-96A * 28 * 4
-- PLL-05 * 36
-- PGZ-95 * 9
-- PGZ-09 * 3
-- PLZ-07/PLZ-96 * 27
-- SA-15 * 1
-- M977 * 4

config.red.amphibOps = {}
-- Live-test shortcuts; leave enabled = false for a real run
config.red.amphibOps.debug = {
  enabled = true,
  startStage = constants.AMPHIBIOUS_PHASES.BOAT_ASSAULT, -- phases before this are fast-forwarded (nil = all of them)
  teleportLanding = true,                                     -- hovercraft and ACVs jump to their parking slot
}
config.red.amphibOps.periodSec = 5 * 60
config.red.amphibOps.adminOffloading = {
  roroBatchSize = 20,          -- RORO 每次最多卸下的車輛數
  bargeRoroPairingRangeNm = 1, -- 駁船與 RORO 距離小於此值才算同一組
}
config.red.amphibOps.fireSupport = {
  srbmHoldAmmoPct = 50,    -- SRBM 總彈量 % 低於此值時，偵察驅動的 SRBM 打擊暫停，直到所有區抵達集結水域
  airlandingShotQty = 440, -- SAG 壓制空/機降區時，全部目標合計的射擊彈數
}
config.red.amphibOps.cargo = {
  type075 = {
    { type = 2, num = 16, dbid = constants.PLATFORMS.PLL05 }, -- PLL-05
    { type = 2, num = 11, dbid = constants.PLATFORMS.PLZ96 }, -- PLZ-96
    { type = 3, num = 3,  dbid = constants.PLATFORMS.PGZ09 }, -- PGZ-09 (2x 35mm/90 PGZ-09 SPAAG)
    { type = 3, num = 1,  dbid = constants.PLATFORMS.PGZ95 }, -- PGZ-95 (2x 25mm Quad PGZ04A PGZ95 Type 95 SPAAG/SAM)
    { type = 3, num = 50, dbid = constants.PLATFORMS.HMMWV }, -- HMMWV
    { type = 3, num = 41, dbid = constants.PLATFORMS.MC },    -- MC (4x Infantry Section [7.62mm MG/Unguided Infantry Anti Tank Weapon])
  },
  type071 = {
    { type = 2, num = 5,  dbid = constants.PLATFORMS.PLL05 }, -- PLL-05
    { type = 2, num = 10, dbid = constants.PLATFORMS.PLZ96 }, -- PLZ-96
    { type = 3, num = 2,  dbid = constants.PLATFORMS.PGZ09 }, -- PGZ-09 (2x 35mm/90 PGZ-09 SPAAG)
    { type = 3, num = 2,  dbid = constants.PLATFORMS.PGZ95 }, -- PGZ-95 (2x 25mm Quad PGZ04A PGZ95 Type 95 SPAAG/SAM)
    { type = 3, num = 1,  dbid = constants.PLATFORMS.SA15 },  -- SA-15 (2x SA-15e Gauntlet [9A331] TELAR)
    { type = 3, num = 22, dbid = constants.PLATFORMS.MC }     -- MC (4x Infantry Section [7.62mm MG/Unguided Infantry Anti Tank Weapon])
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
  roro = {
    { type = 2, num = 42, dbid = constants.PLATFORMS.ZBD04 },  -- ZBD-04
    { type = 2, num = 42, dbid = constants.PLATFORMS.ZTZ96A }, -- ZTZ-96A
    { type = 2, num = 14, dbid = constants.PLATFORMS.PLL05 },  -- PLL-05
    { type = 3, num = 3,  dbid = constants.PLATFORMS.PGZ95 },  -- PGZ-95
    { type = 3, num = 1,  dbid = constants.PLATFORMS.PGZ09 },  -- PGZ-09
    { type = 2, num = 10, dbid = constants.PLATFORMS.PLZ96 },  -- PLZ-07/PLZ-96
    { type = 3, num = 1,  dbid = constants.PLATFORMS.SA15 },   -- SA-15
    { type = 2, num = 2,  dbid = constants.PLATFORMS.M977 },   -- M977
  }
}
-- Ships created for each fleet group. cargo is the manifest loaded aboard.
-- An embarked unit without a name takes the zone's fleet name.
config.red.amphibOps.ships = {
  type075 = {
    dbid = constants.PLATFORMS.TYPE_075,
    name = "Type 075",
    cargo = config.red.amphibOps.cargo.type075,
    embarkedUnits = {
      {
        side = constants.SIDES.RED,
        type = constants.UNIT_TYPES.AIRCRAFT,
        dbid = constants.PLATFORMS.Z18,
        loadouts = {
          { loadoutId = constants.LOADOUTS.Z18_TRANSPORT_1, num = 6 },
          { loadoutId = constants.LOADOUTS.Z18_TRANSPORT_2, num = 6 }
        }
      },
      {
        side = constants.SIDES.RED,
        type = constants.UNIT_TYPES.AIRCRAFT,
        dbid = constants.PLATFORMS.Z10,
        loadouts = { { loadoutId = constants.LOADOUTS.Z10_ATTACK, num = 13 } }
      },
      {
        side = constants.SIDES.RED,
        type = constants.UNIT_TYPES.SHIP,
        name = "Warbird",
        dbid = constants.PLATFORMS.TYPE_726A,
        loadouts = { { loadoutId = 0, num = 3 } }
      }
    }
  },
  type071 = {
    dbid = constants.PLATFORMS.TYPE_071,
    name = "Type 071",
    cargo = config.red.amphibOps.cargo.type071,
    embarkedUnits = {
      {
        side = constants.SIDES.RED,
        type = constants.UNIT_TYPES.AIRCRAFT,
        dbid = constants.PLATFORMS.Z18,
        loadouts = { { loadoutId = constants.LOADOUTS.Z18_TRANSPORT_1, num = 4 } }
      },
      {
        side = constants.SIDES.RED,
        type = constants.UNIT_TYPES.SHIP,
        name = "Warbird",
        dbid = constants.PLATFORMS.TYPE_726A,
        loadouts = { { loadoutId = 0, num = 4 } }
      }
    }
  },
  type076 = {
    dbid = constants.PLATFORMS.TYPE_076,
    name = "Type 076",
    cargo = config.red.amphibOps.cargo.type075,
    embarkedUnits = {
      {
        side = constants.SIDES.RED,
        type = constants.UNIT_TYPES.AIRCRAFT,
        dbid = constants.PLATFORMS.Z18,
        loadouts = {
          { loadoutId = constants.LOADOUTS.Z18_TRANSPORT_1, num = 6 },
          { loadoutId = constants.LOADOUTS.Z18_TRANSPORT_2, num = 6 }
        }
      },
      {
        side = constants.SIDES.RED,
        type = constants.UNIT_TYPES.AIRCRAFT,
        dbid = constants.PLATFORMS.Z10,
        loadouts = { { loadoutId = constants.LOADOUTS.Z10_ATTACK, num = 13 } }
      },
      {
        side = constants.SIDES.RED,
        type = constants.UNIT_TYPES.AIRCRAFT,
        dbid = constants.PLATFORMS.GJ11,
        loadouts = { { loadoutId = constants.LOADOUTS.GJ11_RECON, num = 8 } }
      },
      {
        side = constants.SIDES.RED,
        type = constants.UNIT_TYPES.SHIP,
        name = "Warbird",
        dbid = constants.PLATFORMS.TYPE_726A,
        loadouts = { { loadoutId = 0, num = 3 } }
      }
    }
  },
  barge = { dbid = constants.PLATFORMS.BARGE, name = "Barge" },
  roro = { dbid = constants.PLATFORMS.FERRY, name = "RORO", cargo = config.red.amphibOps.cargo.roro },
  type072a = {
    dbid = constants.PLATFORMS.TYPE_072A,
    name = "Type 072A",
    cargo = config.red.amphibOps.cargo.type072a,
    embarkedUnits = {
      {
        side = constants.SIDES.RED,
        type = constants.UNIT_TYPES.SHIP,
        name = "Assault Boat",
        dbid = constants.PLATFORMS.ASSAULT_BOAT,
        loadouts = { { loadoutId = 0, num = 2 } }
      }
    }
  },
  type072iii = {
    dbid = constants.PLATFORMS.TYPE_072III,
    name = "Type 072III",
    cargo = config.red.amphibOps.cargo.type072iii,
    embarkedUnits = {
      {
        side = constants.SIDES.RED,
        type = constants.UNIT_TYPES.SHIP,
        name = "Assault Boat",
        dbid = constants.PLATFORMS.ASSAULT_BOAT,
        loadouts = { { loadoutId = 0, num = 2 } }
      }
    }
  },
  ferry = { dbid = constants.PLATFORMS.FERRY, name = "Ferry", cargo = config.red.amphibOps.cargo.ferry },
  type073a = { dbid = constants.PLATFORMS.TYPE_073A, name = "Type 073A", cargo = config.red.amphibOps.cargo.type073a },
  type082 = { dbid = constants.PLATFORMS.TYPE_082, name = "Type 082" },
}
config.red.amphibOps.transferCargo = {
  boat = {
    { type = 2, num = 1, dbid = constants.PLATFORMS.ZBD05 }, -- ZBD-05
    { type = 2, num = 1, dbid = constants.PLATFORMS.ZTD05 }, -- ZTD-05
  },
  assaultLandingGroup = {
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
-- Ship layout spacing and craft speeds shared by every zone
config.red.amphibOps.formation = {
  deployLineSetbackNm = 13,
  horizontalDistanceNm = 0.4,
  verticalDistanceNm = 0.4,
  transitDistanceNm = 13,
  acvSpacingNm = 0.05,   -- 兩棲車放行、RORO 卸車時的橫向間距
  rowBearingOffset = 90, -- ship rows run this many degrees off the zone heading
  shipSpeed = 14,
  hovercraftSpeed = 40,
  sweeperSpeed = 25,
  assaultBoatSpeed = 30,
}
-- Lane layout and routing shared by Type 082, assault boats, ACVs and hovercraft (docs/landingOps/assaultTimeline.md)
config.red.amphibOps.route = {
  deployLineNm = 12,                          -- 登陸艦艇展開線，距岸
  launchLineNm = 3,                           -- 泛水出發線，距岸
  assaultLineNm = 2,                          -- 衝擊發起線，距岸
  launchStationNearNm = 2,                    -- 登陸艦就位帶近岸界，距岸
  launchStationFarNm = 4,                     -- 登陸艦就位帶外海界，距岸
  waterLaneSpacingM = 750,                    -- 相鄰水際通道間距（備援；艦間空隙排不出通道時用，教範 500–1000 m）
  waterLaneMinSpacingM = 500,                 -- 水際通道最小間距，也是可放通道的最小艦間空隙（教範 500–1000 m）
  waterLaneMaxSpacingM = 1000,                -- 水際通道最大間距（教範 500–1000 m）
  beachLaneOffsetsM = { -180, -60, 60, 180 }, -- 灘際通道相對水際通道的橫向偏移
  shoreStandoffM = 100,                       -- S_lane 離岸距離
  inlandMarginM = 100,                        -- E_lane 超出障礙範圍的距離
  columnSpacingM = 100,                       -- 排隊入口點間距（往外海退）
  queueDepth = 5,                             -- 排隊入口點數量
  queueSpacingM = 50,                         -- 通道內停車位間距
  laneTieNm = 0.5,                            -- 距離差在此內視為平手，改選負載少的通道
  laneTieM = 100,                             -- 側邊釋放的單位選通道時，橫向距離差在此內視為平手
  arrivalNm = 0.1,                            -- 離最後航點多近算到達
}
config.red.amphibOps.mineClearing = {
  areaMarginM = 60, -- 掃雷任務區域比最外側灘際通道再寬多少
  cellSizeM = 300,  -- 快轉掃雷時判斷水雷在不在通道內的方塊邊長
}
config.red.amphibOps.obstacle = {
  cellSizeM = 50,
  clearSec = 20 * 60,
}
config.red.amphibOps.acvWave = {
  launchBatchSize = 5,        -- 每次放行的兩棲車數量
  lossRatio = 0.3,            -- 存活降到上限的 (1 - lossRatio) 以下就補下一波
  holdSec = 30 * 60,          -- 暫停超過此秒數就補下一波
  hovercraftWaitSec = 60 * 60, -- 氣墊船等第一波車波放滿的上限秒數，逾時直接放行
}
-- Helicopter waves and fixed-wing airlift batches into the airlanding zones
config.red.amphibOps.heliWave = {
  waveTimeoutSec = 30 * 60,  -- 一波（批）放飛後超過此秒數，還在空中的視為結束
  cargoReloadSec = 2 * 3600, -- 空/機降任務開始後，每隔多久補運一次尚未運完的貨物
  flightPath = {             -- 左右翼航線，直升機與 airlift 共用
    wingOffsetM = 8000,      -- 左右翼離通道中心線的橫向距離
    inlandEntryM = 3000,     -- 進內陸多深後轉向降落點
    landingSpreadM = 500,    -- 左右翼降落點離降落區中心的橫向偏移
  },
  transport = {              -- 運輸直升機（Z-18）
    waveSize = 8,            -- 每波架數（左右翼各半）
    cruiseSpeedKt = 130,     -- 倒推放飛時間用的巡航速度
    cruiseAltitudeM = 304,   -- 放飛後的巡航高度（公尺）
    arrivalNm = 0.5,         -- 離降落點多近算到達
  },
  attack = {                 -- 攻擊直升機（Z-10）
    count = 4,               -- 每區總數（已進 CAS 的加飛往中的），下一波補到此數
    casAssignNm = 3,         -- 離降落點多近就指派進 CAS 任務
  },
  airlift = {                -- 固定翼運輸機（IL-76），數值暫定，待遊戲內驗證
    batchSize = 3,           -- 每批架數
    delaySec = 5 * 60,       -- 比衝鋒舟到岸晚多久到降落點
    cruiseSpeedKt = 400,     -- 倒推放飛時間用的巡航速度
    cruiseAltitudeM = 1500,  -- 放飛後的巡航高度（公尺）
    arrivalNm = 3,           -- 離降落點多近算到達
  },
}
config.red.amphibOps.zones = {
  {
    name = "Taoyuan",
    heading = 150, -- approach bearing toward the shore; lane, LST, ACV and SAG bearings derive from it
    fleet = {
      names = { "Air Assault Bn", "Combined Arms Bn", "5th Landing Ship Div" },
      stagingArea = constants.AREAS.AREA_OF_OPS_D,
      groups = {
        {
          from = {
            heading = 220, -- departs from the north
            startingPoint = constants.AREAS.STARTING_POINT_075_TAOYUAN,
          },
          to = {
            startingPoint = constants.AREAS.DESTINATION_075_TAOYUAN,
          },
          shipCounts = {
            type075 = 2,
            type071 = 4,
            type076 = 1,
            type072iii = 7,
            type072a = 8,
            type073a = 7,
            ferry = 4,
            roro = 3,
            barge = 1,
            type082 = 4
          },
        },
      },
    },
    sags = {
      {
        groupName = "SAG 173",
        unitMap = {
          type054a = { dbid = constants.PLATFORMS.TYPE_054A, },
          type052d = { dbid = constants.PLATFORMS.TYPE_052D, }
        },
        from = {
          pos = { latitude = "N 26.54.18", longitude = "E 121.31.38", },
          heading = 225
        },
        to = {
          holdingArea = {
            { latitude = "N 25.17.39", longitude = "E 120.56.04", desiredSpeed = 14, },
            { latitude = "N 25.17.32", longitude = "E 120.56.07", desiredSpeed = 14, },
          },
          amphibiousVehicleStagingArea = {
            { latitude = "N 25.06.19", longitude = "E 121.04.15", desiredSpeed = 14, },
          },
        },
        area = constants.AREAS.AIRLANDING_TAOYUAN
      },
      {
        groupName = "SAG 155",
        unitMap = {
          type054a = { dbid = constants.PLATFORMS.TYPE_054A, },
          type052d = { dbid = constants.PLATFORMS.TYPE_052D, }
        },
        from = {
          pos = { latitude = "N 26.13.13", longitude = "E 120.59.55", },
          heading = 225
        },
        to = {
          holdingArea = {
            { latitude = "N 25.33.23", longitude = "E 120.54.45", desiredSpeed = 14, },
            { latitude = "N 25.21.00", longitude = "E 121.04.12", desiredSpeed = 14, },
          },
          amphibiousVehicleStagingArea = {
            { latitude = "N 25.08.29", longitude = "E 121.10.20", desiredSpeed = 14, },
          },
        },
        area = constants.AREAS.AIRLANDING_TAOYUAN
      },
    },
    movement = {
      baseGUID = constants.BASES.PINGTAN_PORT,
      arrivalThreshold = 15,
      holdingAreas = {
        mothership = constants.AREAS.MOTHERSHIP_AREA_TAOYUAN,
        deployLine = constants.AREAS.DEPLOY_LINE_AREA_TAOYUAN,
      },
    },
    air = {
      contactThreshold = 3,
      reconTemplate = "GJ11_RECON",
      transportHelicopter = {
        dbid = constants.PLATFORMS.Z18,
        zone = constants.AREAS.AIRLANDING_TAOYUAN,
        transferManifest = {
          type075 = {
            {
              loadoutId = constants.LOADOUTS.Z18_TRANSPORT_1,
              cargoItems = { config.red.amphibOps.transferCargo.airAssaultGroup1 }
            },
            {
              loadoutId = constants.LOADOUTS.Z18_TRANSPORT_2,
              cargoItems = { config.red.amphibOps.transferCargo.airAssaultGroup2 }
            },
          },
          type071 = {
            {
              loadoutId = constants.LOADOUTS.Z18_TRANSPORT_1,
              cargoItems = { config.red.amphibOps.transferCargo.airAssaultGroup1 }
            },
          }
        },
      },
      attackHelicopter = {
        dbid = constants.PLATFORMS.Z10,
        zone = constants.AREAS.CAS_E,
      },
    },
    landing = {
      hovercraft = {
        dbid = constants.PLATFORMS.TYPE_726A,
        zone = constants.AREAS.LANDING_TAOYUAN,
        transferManifest = {
          type075 = {
            {
              loadoutId = 0,
              cargoItems = {
                config.red.amphibOps.transferCargo.assaultLandingGroup,
                config.red.amphibOps.transferCargo.deepAssaultGroup1,
                config.red.amphibOps.transferCargo.deepAssaultGroup2,
              }
            },
          },
          type071 = {
            {
              loadoutId = 0,
              cargoItems = {
                config.red.amphibOps.transferCargo.assaultLandingGroup,
                config.red.amphibOps.transferCargo.deepAssaultGroup1,
                config.red.amphibOps.transferCargo.deepAssaultGroup2,
                config.red.amphibOps.transferCargo.deepAssaultGroup3,
              }
            },
          }
        },
      },
      lst = {
        speed = config.red.amphibOps.formation.shipSpeed,
        distance = config.red.amphibOps.formation.transitDistanceNm
      },
      acv = {
        destination = {
          { latitude = "N 25.04.52", longitude = "E 121.10.05", },
          { latitude = "N 25.04.44", longitude = "E 121.13.54", },
        },
        capacity = { zbd05 = 112, ztd05 = 112 }, -- 每區同時存活上限（旅級規模）
        area = constants.AREAS.AMPH_VEH_STAGING_AREA_TAOYUAN
      },
      beachheadVehicles = 168, -- 區內 ZBD-05 + ZTD-05 合計達此數量才算灘頭穩固、開始行政下卸（旅級約 3/4）
      laneCenter = constants.AREAS.LANE_CENTER_TAOYUAN,
      obstacleArea = constants.AREAS.OBSTACLE_TAOYUAN,
      minefield = { area = constants.AREAS.MINEFIELD_TAOYUAN, number = 500, delay = 0 }, -- 藍方近海雷區；delay 為 CMO 布設延遲
      offloadArea = constants.AREAS.OFFLOAD_AREA_TAOYUAN,
      sweeper = {
        missionName = "MINECLEARING/TOA/1/1",
        settings = {},
      },
    },
  },
  {
    name = "Sishu",
    heading = 73, -- approach bearing toward the shore; lane, LST, ACV and SAG bearings derive from it
    fleet = {
      names = { "Air Assault Bn", "Combined Arms Bn", "5th Landing Ship Div" },
      stagingArea = constants.AREAS.AREA_OF_OPS_F,
      groups = {
        {
          from = {
            heading = 73,
            startingPoint = constants.AREAS.STARTING_POINT_075_SISHU,
          },
          to = {
            startingPoint = constants.AREAS.DESTINATION_075_SISHU,
          },
          shipCounts = {
            type075 = 1,
            type071 = 3,
            type076 = 0,
            type072iii = 2,
            type072a = 4,
            type073a = 2,
            ferry = 4,
            roro = 3,
            barge = 1,
            type082 = 4
          },
        },
      },
    },
    sags = {
      {
        groupName = "SAG 154",
        unitMap = {
          type054a = { dbid = constants.PLATFORMS.TYPE_054A, },
          type052d = { dbid = constants.PLATFORMS.TYPE_052D, }
        },
        from = {
          pos = { latitude = "N 22.32.59", longitude = "E 118.04.52", },
          heading = 73,
        },
        to = {
          holdingArea = {
            { latitude = "N 22.49.20", longitude = "E 119.55.57", desiredSpeed = 14, },
          },
          amphibiousVehicleStagingArea = {
            { latitude = "N 22.53.16", longitude = "E 120.07.39", desiredSpeed = 14, },
          },
        },
        area = constants.AREAS.AIRLANDING_CHANGLONG,
      },
      {
        groupName = "SAG 175",
        unitMap = {
          type054a = { dbid = constants.PLATFORMS.TYPE_054A, },
          type052d = { dbid = constants.PLATFORMS.TYPE_052D, }
        },
        from = {
          pos = { latitude = "N 22.44.28", longitude = "E 118.01.16", },
          heading = 73,
        },
        to = {
          holdingArea = {
            { latitude = "N 22.55.20", longitude = "E 119.52.25", desiredSpeed = 14, },
          },
          amphibiousVehicleStagingArea = {
            { latitude = "N 22.58.52", longitude = "E 120.05.48", desiredSpeed = 14, },
          },
        },
        area = constants.AREAS.AIRLANDING_CHANGLONG,
      },
    },
    movement = {
      baseGUID = constants.BASES.KWANG_CHOW_WAN_NB,
      arrivalThreshold = 10,
      holdingAreas = {
        mothership = constants.AREAS.MOTHERSHIP_AREA_SISHU,
        deployLine = constants.AREAS.DEPLOY_LINE_AREA_SISHU,
      },
    },
    air = {
      contactThreshold = 3,
      transportHelicopter = {
        dbid = constants.PLATFORMS.Z18,
        zone = constants.AREAS.AIRLANDING_CHANGLONG,
        transferManifest = {
          type075 = {
            {
              loadoutId = constants.LOADOUTS.Z18_TRANSPORT_1,
              cargoItems = { config.red.amphibOps.transferCargo.airAssaultGroup1 }
            },
            {
              loadoutId = constants.LOADOUTS.Z18_TRANSPORT_2,
              cargoItems = { config.red.amphibOps.transferCargo.airAssaultGroup2 }
            },
          },
          type071 = {
            {
              loadoutId = constants.LOADOUTS.Z18_TRANSPORT_1,
              cargoItems = { config.red.amphibOps.transferCargo.airAssaultGroup1 }
            },
          }
        },
      },
      attackHelicopter = {
        dbid = constants.PLATFORMS.Z10,
        zone = constants.AREAS.CAS_S,
      },
    },
    landing = {
      hovercraft = {
        dbid = constants.PLATFORMS.TYPE_726A,
        zone = constants.AREAS.LANDING_SISHU,
        transferManifest = {
          type075 = {
            {
              loadoutId = 0,
              cargoItems = {
                config.red.amphibOps.transferCargo.assaultLandingGroup,
                config.red.amphibOps.transferCargo.deepAssaultGroup1,
                config.red.amphibOps.transferCargo.deepAssaultGroup2,
              }
            },
          },
          type071 = {
            {
              loadoutId = 0,
              cargoItems = {
                config.red.amphibOps.transferCargo.assaultLandingGroup,
                config.red.amphibOps.transferCargo.deepAssaultGroup1,
                config.red.amphibOps.transferCargo.deepAssaultGroup2,
                config.red.amphibOps.transferCargo.deepAssaultGroup3
              }
            },
          }
        },
      },
      lst = {
        speed = config.red.amphibOps.formation.shipSpeed,
        distance = config.red.amphibOps.formation.transitDistanceNm
      },
      acv = {
        destination = {
          { latitude = "N 22.56.39", longitude = "E 120.10.37", },
          { latitude = "N 22.57.14", longitude = "E 120.12.09", },
        },
        capacity = { zbd05 = 112, ztd05 = 112 }, -- 每區同時存活上限（旅級規模）
        area = constants.AREAS.AMPH_VEH_STAGING_AREA_SHISHU
      },
      beachheadVehicles = 168, -- 區內 ZBD-05 + ZTD-05 合計達此數量才算灘頭穩固、開始行政下卸（旅級約 3/4）
      laneCenter = constants.AREAS.LANE_CENTER_SISHU,
      obstacleArea = constants.AREAS.OBSTACLE_SISHU,
      minefield = { area = constants.AREAS.MINEFIELD_SISHU, number = 500, delay = 0 }, -- 藍方近海雷區；delay 為 CMO 布設延遲
      offloadArea = constants.AREAS.OFFLOAD_AREA_SISHU,
      sweeper = {
        missionName = "MINECLEARING/SISHU/1/1",
        settings = {},
      },
    },
  },
  {
    name = "Penghu",
    heading = 82, -- approach bearing toward the shore; lane, LST, ACV and SAG bearings derive from it
    fleet = {
      names = { "Air Assault Bn", "Combined Arms Bn", "5th Landing Ship Div" },
      stagingArea = constants.AREAS.AREA_OF_OPS_E,
      groups = {
        {
          from = {
            heading = 82,
            startingPoint = constants.AREAS.STARTING_POINT_075_PENGHU,
          },
          to = {
            startingPoint = constants.AREAS.DESTINATION_075_PENGHU,
          },
          shipCounts = {
            type075 = 1,
            type071 = 1,
            type076 = 0,
            type072iii = 2,
            type072a = 3,
            type073a = 1,
            ferry = 0,
            roro = 0,
            barge = 0,
            type082 = 1
          },
        },
      },
    },
    sags = {
      {
        groupName = "SAG 167",
        unitMap = {
          type054a = { dbid = constants.PLATFORMS.TYPE_054A, },
          type052d = { dbid = constants.PLATFORMS.TYPE_052D, }
        },
        from = {
          pos = { latitude = "N 23.29.19", longitude = "E 118.04.37", },
          heading = 82,
        },
        to = {
          holdingArea = {
            { latitude = "N 23.32.46", longitude = "E 119.16.11", desiredSpeed = 14, },
          },
          amphibiousVehicleStagingArea = {
            { latitude = "N 23.32.34", longitude = "E 119.29.14", desiredSpeed = 14, },
          },
        },
        area = constants.AREAS.AIRLANDING_PENGHU,
      },
    },
    movement = {
      baseGUID = constants.BASES.KWANG_CHOW_WAN_NB,
      arrivalThreshold = 5,
      holdingAreas = {
        mothership = constants.AREAS.MOTHERSHIP_AREA_PENGHU,
        deployLine = constants.AREAS.DEPLOY_LINE_AREA_PENGHU,
      },
    },
    air = {
      contactThreshold = 3,
      transportAircraft = {
        name = "Zhangpu AAB",
        guid = constants.BASES.ZHANGPU_AAB,
        dbid = constants.PLATFORMS.IL76,
        cargoItemsForTransfer = {
          {
            loadoutId = constants.LOADOUTS.IL76_TRANSPORT,
            cargoItems = { config.red.amphibOps.transferCargo.airAssaultGroup3 }
          },
        }
      },
      transportHelicopter = {
        dbid = constants.PLATFORMS.Z18,
        zone = constants.AREAS.AIRLANDING_PENGHU,
        transferManifest = {
          type075 = {
            {
              loadoutId = constants.LOADOUTS.Z18_TRANSPORT_1,
              cargoItems = { config.red.amphibOps.transferCargo.airAssaultGroup1 }
            },
            {
              loadoutId = constants.LOADOUTS.Z18_TRANSPORT_2,
              cargoItems = { config.red.amphibOps.transferCargo.airAssaultGroup2 }
            },
          },
          type071 = {
            {
              loadoutId = constants.LOADOUTS.Z18_TRANSPORT_1,
              cargoItems = { config.red.amphibOps.transferCargo.airAssaultGroup1 }
            },
          }
        },
      },
      attackHelicopter = {
        dbid = constants.PLATFORMS.Z10,
        zone = constants.AREAS.CAS_PENGHU,
      },
    },
    landing = {
      hovercraft = {
        dbid = constants.PLATFORMS.TYPE_726A,
        zone = constants.AREAS.LANDING_PENGHU,
        transferManifest = {
          type075 = {
            {
              loadoutId = 0,
              cargoItems = {
                config.red.amphibOps.transferCargo.assaultLandingGroup,
                config.red.amphibOps.transferCargo.deepAssaultGroup1,
                config.red.amphibOps.transferCargo.deepAssaultGroup2,
              }
            },
          },
          type071 = {
            {
              loadoutId = 0,
              cargoItems = {
                config.red.amphibOps.transferCargo.assaultLandingGroup,
                config.red.amphibOps.transferCargo.deepAssaultGroup1,
                config.red.amphibOps.transferCargo.deepAssaultGroup2,
                config.red.amphibOps.transferCargo.deepAssaultGroup3
              }
            },
          }
        },
      },
      lst = {
        speed = config.red.amphibOps.formation.shipSpeed,
        distance = config.red.amphibOps.formation.transitDistanceNm
      },
      acv = {
        destination = {
          { latitude = "N 23.31.00", longitude = "E 119.33.54", },
          { latitude = "N 23.31.35", longitude = "E 119.35.36", },
          { latitude = "N 23.34.09", longitude = "E 119.37.41", },
        },
        capacity = { zbd05 = 28, ztd05 = 28 }, -- 每區同時存活上限（營級，旅的 1/4）
        area = constants.AREAS.AMPH_VEH_STAGING_AREA_PENGHU
      },
      beachheadVehicles = 42, -- 區內 ZBD-05 + ZTD-05 合計達此數量才算灘頭穩固、開始行政下卸（營級）
      laneCenter = constants.AREAS.LANE_CENTER_PENGHU,
      obstacleArea = constants.AREAS.OBSTACLE_PENGHU,
      minefield = { area = constants.AREAS.MINEFIELD_PENGHU, number = 100, delay = 0 }, -- 藍方近海雷區；delay 為 CMO 布設延遲
      offloadArea = constants.AREAS.OFFLOAD_AREA_PENGHU,
      sweeper = {
        missionName = "MINECLEARING/PENGHU/1/1",
        settings = {},
      },
    },
  },
}


-- ============================================================================
-- Land Attack Cruise Missiles - Surface Launch (China)
-- ============================================================================

config.red.surface = {}
config.red.surface.lacm = {}
config.red.surface.lacm.weaponDBID = constants.WEAPONS.YJ21
config.red.surface.lacm.csg = {
  groupName = "CSG",
  unitMap = {
    type002 = {
      dbid = constants.PLATFORMS.TYPE_002,
      embarkedUnits = {
        {
          side = constants.SIDES.RED,
          type = "Air",
          dbid = constants.PLATFORMS.J15,
          platformName = "J-15",
          name = "2nd Carrier Air Wing",
          loadouts = {
            { loadoutId = constants.LOADOUTS.J15_YJ91,    num = 8 },
            { loadoutId = constants.LOADOUTS.J15_LS6_500, num = 12 },
            { loadoutId = constants.LOADOUTS.J15_PL15,    num = 12, missionName = "CAP/CSG" },
          }
        },
        {
          side = constants.SIDES.RED,
          type = "Air",
          dbid = constants.PLATFORMS.Z18F_SEA_EAGLE,
          platformName = "Z-18F Sea Eagle",
          name = "10th Naval Air Bde",
          loadouts = {
            { loadoutId = constants.LOADOUTS.Z18F_CARRIER_ASW, num = 6, missionName = "ASW/CSG" },
          }
        },
        {
          side = constants.SIDES.RED,
          type = "Air",
          dbid = constants.PLATFORMS.Z18J,
          platformName = "Z-18J",
          name = "10th Naval Air Bde",
          loadouts = {
            { loadoutId = constants.LOADOUTS.Z18J_AEW, num = 3, missionName = "AEW/CSG" },
          }
        },
        {
          side = constants.SIDES.RED,
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
        { loadoutId = constants.LOADOUTS.J15_PL15,    num = 12, },
      }
    },
    type055 = {
      dbid = constants.PLATFORMS.TYPE_055,
      embarkedUnits = {
        {
          side = constants.SIDES.RED,
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
          side = constants.SIDES.RED,
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
          side = constants.SIDES.RED,
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
    pos = { latitude = "N 21.09.59", longitude = "E 120.48.05", },
    heading = 83
  },
  to = {
    area = {
      { latitude = "N 21.14.11", longitude = "E 121.34.36", },
      { latitude = "N 21.32.59", longitude = "E 122.12.58", },
    },
    -- heading = CONFIG.red.PHIBOP.shipInfo.heading.west.vertical,
  },
}
config.red.surface.lacm.targetlist = {
  "6Z8LM5-0HMIJ7B89BC71",
  "6Z8LM5-0HMIJ7B89BC73",
  "6Z8LM5-0HMIJ7B89BC6V",
}


-- ============================================================================
-- Submarine-Launched Cruise Missiles (China)
-- ============================================================================

config.red.subSurface = {}
config.red.subSurface.slcm = {}
config.red.subSurface.slcm.weaponDBID = constants.WEAPONS.CJ10_SLCM
config.red.subSurface.slcm.submarines = {
  ["407"] = {
    name = "407",
    course = {
      { latitude = "N 25.07.57", longitude = "E 122.46.06", presetDepth = 3 },
      { latitude = "N 24.33.33", longitude = "E 122.05.57", presetDepth = 3 },
      { latitude = "N 24.30.54", longitude = "E 122.48.02", presetDepth = 3 },
    },
    from = {
      pos = { latitude = "N 25.05.32", longitude = "E 122.11.39" },
      heading = 180
    },
    weaponDBID = config.red.subSurface.slcm.weaponDBID
  },
  ["408"] = {
    name = "408",
    course = {
      { latitude = "N 25.11.06", longitude = "E 122.42.15", presetDepth = 3 },
      { latitude = "N 24.33.33", longitude = "E 122.08.38", presetDepth = 3 },
      { latitude = "N 25.09.37", longitude = "E 122.06.45", presetDepth = 3 },
    },
    from = {
      pos = { latitude = "N 24.32.30", longitude = "E 122.47.45", },
      heading = 270
    },
    weaponDBID = config.red.subSurface.slcm.weaponDBID
  },
  ["409"] = {
    name = "409",
    course = {
      { latitude = 23.1405738004732, longitude = 122.453896349795, presetDepth = 3 },
      { latitude = 24.3097078500905, longitude = 122.142301456749, presetDepth = 3 },
      { latitude = 23.3573584800694, longitude = 121.777514450334, presetDepth = 3 }
    },
    from = {
      pos = { latitude = "N 23.29.41", longitude = "E 122.39.12", },
      heading = 180
    },
    weaponDBID = config.red.subSurface.slcm.weaponDBID
  },
  ["410"] = {
    name = "410",
    course = {
      { latitude = 24.2344610141018, longitude = 122.681795983267, presetDepth = 3 },
      { latitude = 23.4458260682078, longitude = 121.855392759008, presetDepth = 3 },
      { latitude = 24.280771111992,  longitude = 121.981212557257, presetDepth = 3 }
    },
    from = {
      pos = { latitude = "N 22.41.17", longitude = "E 122.01.36", },
      heading = 30
    },
    weaponDBID = config.red.subSurface.slcm.weaponDBID
  },
}
config.red.subSurface.slcm.targetlist = {
  "6Z8LM5-0HMIJ7B89BCF3",
  "6Z8LM5-0HMIJ7B89BCF4",
  "6Z8LM5-0HMIJ7B89BCF5",
}
config.red.subSurface.slcm.randomRadiusNm = 20


-- ============================================================================
-- Runway Repair (China / Taiwan)
-- ============================================================================

config.red.repairRunway = {
  percentagePerHour = 3,
  runwayDBIDs = { 55, 43, 757, 1422, 1424, 1423, 1421 },
}

config.blue.repairRunway = {
  percentagePerHour = 3,
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

config.red.fireSupportTaskTemplates = {
  GND_STRIKE_INFRA_ALL_1 = {
    {
      name = "RADAR",
      missileSystemType = "SRBM",
      launcherNames = {
        "614th Bde, PLARF",
        "613rd Bde, PLARF"
      },
      target = {
        list = {},
        objs = {
          { baseName = nil, subTypes = { "Radar", "Hengshan ROC command", "Sky Bow" } },
        },
        areas = {},
        filterNames = nil,
        contactAge = config.red.ground.missileSystemTypes.srbm.contactAge,
        minTargetCount = 4,
        ammoPerTarget = 3
      },
    },
    {
      name = "RUNWAY",
      missileSystemType = "SRBM",
      launcherNames = {
        "636th Bde, PLARF",
        "617th Bde, PLARF"
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
        contactAge = config.red.ground.missileSystemTypes.srbm.contactAge,
        minTargetCount = 4,
        ammoPerTarget = 4
      },
    },
    {
      name = "PORT",
      missileSystemType = "SRBM",
      launcherNames = {
        "615th Bde, PLARF"
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
        contactAge = config.red.ground.missileSystemTypes.srbm.contactAge,
        minTargetCount = 4,
        ammoPerTarget = 2
      },
    },
    {
      name = "SHELTER",
      missileSystemType = "SRBM",
      launcherNames = {
        "616th Bde, PLARF"
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
        contactAge = config.red.ground.missileSystemTypes.srbm.contactAge,
        minTargetCount = 4,
        ammoPerTarget = 2
      },
    },
  },
  GND_STRIKE_INFRA_ALL_2 = {
    {
      name = "RADAR",
      missileSystemType = "SRBM",
      launcherNames = {
        "614th Bde, PLARF",
        "613rd Bde, PLARF"
      },
      target = {
        list = {},
        objs = {
          { baseName = nil, subTypes = { "Radar", "Hengshan ROC command", "Sky Bow" } },
        },
        areas = {},
        filterNames = nil,
        contactAge = config.red.ground.missileSystemTypes.srbm.contactAge,
        minTargetCount = 1,
        ammoPerTarget = 3
      },
    },
    {
      name = "RUNWAY",
      missileSystemType = "SRBM",
      launcherNames = {
        "636th Bde, PLARF",
        "617th Bde, PLARF"
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
        contactAge = config.red.ground.missileSystemTypes.srbm.contactAge,
        minTargetCount = 1,
        ammoPerTarget = 4
      },
    },
    {
      name = "PORT",
      missileSystemType = "SRBM",
      launcherNames = {
        "615th Bde, PLARF"
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
        contactAge = config.red.ground.missileSystemTypes.srbm.contactAge,
        minTargetCount = 1,
        ammoPerTarget = 2
      },
    },
    {
      name = "SHELTER",
      missileSystemType = "SRBM",
      launcherNames = {
        "616th Bde, PLARF"
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
        contactAge = config.red.ground.missileSystemTypes.srbm.contactAge,
        minTargetCount = 1,
        ammoPerTarget = 2
      },
    },
  },
  GND_ASUW_SHIP_E_1 = {
    {
      name = "ANTISHIP",
      missileSystemType = "MRBM",
      launcherNames = {
        "624th Bde, PLARF"
      },
      target = {
        list = {},
        objs = {},
        areas = { constants.AREAS.AREA_OF_OPS_PACIFIC },
        filterNames = { "findNavalTargets" },
        contactAge = config.red.ground.missileSystemTypes.mrbm.contactAge,
        minTargetCount = 1,
        ammoPerTarget = 6
      },
    }
  },
  GND_ASUW_SHIP_N_1 = {
    {
      name = "ANTISHIP",
      missileSystemType = "ASCM",
      launcherNames = {
        "1st Pili Reg"
      },
      target = {
        list = {},
        objs = {},
        areas = { constants.AREAS.AREA_OF_OPS_D },
        filterNames = { "findNavalTargets" },
        contactAge = config.red.ground.missileSystemTypes.ascm.contactAge,
        minTargetCount = 1,
        ammoPerTarget = 2
      },
    }
  },
  GND_STRIKE_C2_N_1 = {
    {
      name = "PINGTAN",
      missileSystemType = "MLRS",
      launcherNames = {
        "1st Bn, 1st Rockets Arty Bde"
      },
      target = {
        list = {},
        objs = {},
        areas = { constants.AREAS.AREA_OF_OPS_NORTH },
        filterNames = { "evaluateEmissions", "findRadioDirection" },
        contactAge = config.red.ground.missileSystemTypes.mlrs.contactAge,
        minTargetCount = 1,
        ammoPerTarget = 8
      },
    },
  },
  GND_STRIKE_C2_C_1 = {
    {
      name = "CHINCHEW",
      missileSystemType = "MLRS",
      launcherNames = {
        "6th Bn, 73rd Arty Bde"
      },
      target = {
        list = {},
        objs = {},
        areas = { constants.AREAS.AREA_OF_OPS_CENTER },
        filterNames = { "evaluateEmissions", "findRadioDirection" },
        contactAge = config.red.ground.missileSystemTypes.mlrs.contactAge,
        minTargetCount = 1,
        ammoPerTarget = 8
      },
    },
  },
  GND_STRIKE_HELIPAD_ALL_1 = {
    {
      name = "HELIPAD",
      missileSystemType = "GLCM",
      launcherNames = {
        "635th Bde, PLARF"
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
        contactAge = config.red.ground.missileSystemTypes.glcm.contactAge,
        minTargetCount = 1,
        ammoPerTarget = 4
      },
    },
  },
}


-- ============================================================================
-- Air Package Templates (China)
-- ============================================================================

config.red.packageTemplates = {
  AIR_STRIKE_AB_W_1 = {
    {
      timeToReady = config.aircraftReadySec,
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
            ProsecutionZone = constants.AREAS.TARGET_AREA_SOUTH_PROSECUTION,
            PatrolZone = constants.AREAS.TARGET_AREA_SOUTH_PATROL
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
            ProsecutionZone = constants.AREAS.TARGET_AREA_SOUTH_PROSECUTION,
            PatrolZone = constants.AREAS.TARGET_AREA_SOUTH_PATROL
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
          opts = { Zone = constants.AREAS.TARGET_AREA_SOUTH_PATROL }
        },
        emcon = "Radar=Passive;OECM=Active"
      },
      tanker = nil,
      reconUAV = config.red.recon.templates.BZK005_RECON_1,
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
      timeToReady = config.aircraftReadySec,
      striker = {
        baseGUID = constants.BASES.SHANTOU_WAISHA_AB,
        weaponDBID = constants.WEAPONS.AKD88,
        unitDBID = constants.PLATFORMS.J16,
        unitCount = 12,
        loadoutID = constants.LOADOUTS.J16_AKD88,
        startTime = nil,
        missionCreationParams = { name = "STRIKE/AB/C/1", type = "strike", opts = { type = "land" } },
        emcon = "Radar=Passive;OECM=Active"
      },
      escort = {
        baseGUID = constants.BASES.HUIAN_AAB,
        weaponDBID = constants.WEAPONS.PL15,
        unitDBID = constants.PLATFORMS.J20,
        unitCount = 8,
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
            ProsecutionZone = constants.AREAS.TARGET_AREA_CENTER_PROSECUTION,
            PatrolZone = constants.AREAS.TARGET_AREA_CENTER_PATROL
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
          name = "SEAD/AB/C/1",
          type = "patrol",
          opts = {
            type = "sead",
            OneThirdRule = false,
            FlightSize = 4,
            CheckOPAREA = false,
            CheckWWR = false,
            ProsecutionZone = constants.AREAS.TARGET_AREA_CENTER_PROSECUTION,
            PatrolZone = constants.AREAS.TARGET_AREA_CENTER_PATROL
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
          name = "JAMMING/AB/C/1",
          type = "support",
          opts = { Zone = constants.AREAS.TARGET_AREA_CENTER_PATROL }
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
      timeToReady = config.aircraftReadySec,
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
            ProsecutionZone = constants.AREAS.TARGET_AREA_NORTH_PROSECUTION,
            PatrolZone = constants.AREAS.TARGET_AREA_NORTH_PATROL
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
            ProsecutionZone = constants.AREAS.TARGET_AREA_NORTH_PROSECUTION,
            PatrolZone = constants.AREAS.TARGET_AREA_NORTH_PATROL
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
          opts = { Zone = constants.AREAS.TARGET_AREA_NORTH_PATROL }
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
  AIR_STRIKE_AB_W_2 = {
    {
      timeToReady = config.aircraftReadySec,
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
        filterNames = {},
        contactAge = 60 * 60,
        minTargetCount = 1
      },
    },
    {
      timeToReady = config.aircraftReadySec,
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
        filterNames = {},
        contactAge = 60 * 60,
        minTargetCount = 1
      },
    }
  },
  AIR_STRIKE_AB_W_3 = {
    {
      timeToReady = config.aircraftReadySec,
      striker = {
        baseGUID = constants.BASES.ZHANGZHOU_LONGXI_AB,
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
            ProsecutionZone = constants.AREAS.TARGET_AREA_SOUTH_PROSECUTION,
            PatrolZone = constants.AREAS.TARGET_AREA_SOUTH_PATROL
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
            ProsecutionZone = constants.AREAS.TARGET_AREA_SOUTH_PROSECUTION,
            PatrolZone = constants.AREAS.TARGET_AREA_SOUTH_PATROL
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
          opts = { Zone = constants.AREAS.TARGET_AREA_SOUTH_PATROL }
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
        filterNames = {},
        contactAge = 60 * 60,
        minTargetCount = 1
      },
    },
    {
      timeToReady = config.aircraftReadySec,
      striker = {
        baseGUID = constants.BASES.ZHANGZHOU_LONGXI_AB,
        weaponDBID = constants.WEAPONS.KAB1500,
        unitDBID = constants.PLATFORMS.SU30,
        unitCount = 12,
        loadoutID = constants.LOADOUTS.SU30_KAB1500,
        -- startTime = "2027-06-09 05:40:00",
        missionCreationParams = { name = "STRIKE/AB/C/3", type = "strike", opts = { type = "land" } },
        emcon = "Radar=Passive;OECM=Active"
      },
      escort = {
        baseGUID = constants.BASES.HUIAN_AAB,
        weaponDBID = constants.WEAPONS.PL15,
        unitDBID = constants.PLATFORMS.J20,
        unitCount = 8,
        loadoutID = constants.LOADOUTS.J20_PL15,
        missionCreationParams = {
          name = "SWEEP/AB/C/3",
          type = "patrol",
          opts = {
            type = "aaw",
            OneThirdRule = false,
            FlightSize = 4,
            CheckOPAREA = false,
            CheckWWR = false,
            ProsecutionZone = constants.AREAS.TARGET_AREA_CENTER_PROSECUTION,
            PatrolZone = constants.AREAS.TARGET_AREA_CENTER_PATROL
          }
        },
        emcon = "Radar=Passive;OECM=Active"
      },
      wildWeasel = {
        baseGUID = constants.BASES.SHANTOU_WAISHA_AB,
        weaponDBID = constants.WEAPONS.YJ91_ASM,
        unitDBID = constants.PLATFORMS.J16,
        unitCount = 8,
        loadoutID = constants.LOADOUTS.J16_YJ91,
        missionCreationParams = {
          name = "SEAD/AB/C/3",
          type = "patrol",
          opts = {
            type = "sead",
            OneThirdRule = false,
            FlightSize = 4,
            CheckOPAREA = false,
            CheckWWR = false,
            ProsecutionZone = constants.AREAS.TARGET_AREA_CENTER_PROSECUTION,
            PatrolZone = constants.AREAS.TARGET_AREA_CENTER_PATROL
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
          name = "JAMMING/AB/C/3",
          type = "support",
          opts = { Zone = constants.AREAS.TARGET_AREA_CENTER_PATROL }
        },
        emcon = "Radar=Passive;OECM=Active"
      },
      tanker = nil,
      reconUAV = nil,
      target = {
        list = {},
        objs = {
          { baseName = "Ching Chuang Kang AB", subTypes = { "Ammo Bunker" } },
          { baseName = "Chiayi AB",            subTypes = { "Ammo Bunker" } },
        },
        areas = { constants.AREAS.AREA_OF_OPS_CENTER },
        filterNames = {},
        contactAge = 60 * 60,
        minTargetCount = 1
      },
    },
    {
      timeToReady = config.aircraftReadySec,
      striker = {
        baseGUID = constants.BASES.LONGTIAN_AAB,
        weaponDBID = constants.WEAPONS.KAB1500,
        unitDBID = constants.PLATFORMS.SU30,
        unitCount = 8,
        loadoutID = constants.LOADOUTS.SU30_KAB1500,
        -- startTime = "2027-06-09 05:40:00",
        missionCreationParams = { name = "STRIKE/AB/N/3", type = "strike", opts = { type = "land" } },
        emcon = "Radar=Passive;OECM=Active"
      },
      escort = {
        baseGUID = constants.BASES.HUIAN_AAB,
        weaponDBID = constants.WEAPONS.PL15,
        unitDBID = constants.PLATFORMS.J20,
        unitCount = 8,
        loadoutID = constants.LOADOUTS.J20_PL15,
        missionCreationParams = {
          name = "SWEEP/AB/N/3",
          type = "patrol",
          opts = {
            type = "aaw",
            OneThirdRule = false,
            FlightSize = 4,
            CheckOPAREA = false,
            CheckWWR = false,
            ProsecutionZone = constants.AREAS.TARGET_AREA_NORTH_PROSECUTION,
            PatrolZone = constants.AREAS.TARGET_AREA_NORTH_PATROL
          }
        },
        emcon = "Radar=Passive;OECM=Active"
      },
      wildWeasel = {
        baseGUID = constants.BASES.HUIAN_AAB,
        weaponDBID = constants.WEAPONS.YJ91_ASM,
        unitDBID = constants.PLATFORMS.J16,
        unitCount = 8,
        loadoutID = constants.LOADOUTS.J16_YJ91,
        missionCreationParams = {
          name = "SEAD/AB/N/3",
          type = "patrol",
          opts = {
            type = "sead",
            OneThirdRule = false,
            FlightSize = 4,
            CheckOPAREA = false,
            CheckWWR = false,
            ProsecutionZone = constants.AREAS.TARGET_AREA_NORTH_PROSECUTION,
            PatrolZone = constants.AREAS.TARGET_AREA_NORTH_PATROL
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
          name = "JAMMING/AB/N/3",
          type = "support",
          opts = { Zone = constants.AREAS.TARGET_AREA_NORTH_PATROL }
        },
        emcon = "Radar=Passive;OECM=Active"
      },
      tanker = nil,
      reconUAV = nil,
      target = {
        list = {},
        objs = {
          { baseName = "Hsinchu AB", subTypes = { "Ammo Bunker" } },
        },
        areas = { constants.AREAS.AREA_OF_OPS_NORTH },
        filterNames = {},
        contactAge = 60 * 60,
        minTargetCount = 1
      },
    },
  },
  AIR_STRIKE_AB_W_AAR_1 = {
    {
      timeToReady = config.aircraftReadySec,
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
            ProsecutionZone = constants.AREAS.TARGET_AREA_NORTH_PROSECUTION,
            PatrolZone = constants.AREAS.TARGET_AREA_NORTH_PATROL,
            TankerUsage = 1,
            TankerMissionList = { "AAR/N/SWEEP/1" },
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
            ProsecutionZone = constants.AREAS.TARGET_AREA_NORTH_PROSECUTION,
            PatrolZone = constants.AREAS.TARGET_AREA_NORTH_PATROL,
            TankerUsage = 1,
            TankerMissionList = { "AAR/N/SEAD/1" },
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
            Zone = constants.AREAS.TARGET_AREA_NORTH_PATROL,
            TankerUsage = 1,
            TankerMissionList = { "AAR/N/JAMMING/1" },
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
        baseGUIDCandidates = { constants.BASES.LEIYANG_AB },
        unitDBID = constants.PLATFORMS.HY6U_BADGER,
        weaponDBID = 0,
        unitCount = 6,
        loadoutID = nil,
        missionCreationParams = {
          {
            name = "AAR/N/SWEEP/1",
            type = "support",
            opts = {
              OneThirdRule = false,
              FlightSize = 2,
              Zone = constants.AREAS.AAR_PATROL_2
            }
          },
          {
            name = "AAR/N/JAMMING/1",
            type = "support",
            opts = {
              OneThirdRule = false,
              FlightSize = 2,
              Zone = constants.AREAS.AAR_PATROL_3
            }
          },
          {
            name = "AAR/N/SEAD/1",
            type = "support",
            opts = {
              OneThirdRule = false,
              FlightSize = 2,
              Zone = constants.AREAS.AAR_PATROL_1
            }
          },
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
      timeToReady = config.aircraftReadySec,
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
            TankerUsage = 1,
            TankerMissionList = { "AAR/C/STRIKE/1", "AAR/C/SWEEP/1", "AAR/C/SEAD/1" },
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
            ProsecutionZone = constants.AREAS.TARGET_AREA_CENTER_PROSECUTION,
            PatrolZone = constants.AREAS.TARGET_AREA_CENTER_PATROL,
            TankerUsage = 1,
            TankerMissionList = { "AAR/C/SWEEP/1" },
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
            ProsecutionZone = constants.AREAS.TARGET_AREA_CENTER_PROSECUTION,
            PatrolZone = constants.AREAS.TARGET_AREA_CENTER_PATROL,
            TankerUsage = 1,
            TankerMissionList = { "AAR/C/SEAD/1" },
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
            Zone = constants.AREAS.TARGET_AREA_CENTER_PATROL,
            TankerUsage = 1,
            TankerMissionList = { "AAR/C/JAMMING/1" },
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
        baseGUIDCandidates = { constants.BASES.LEIYANG_AB },
        unitDBID = constants.PLATFORMS.HY6U_BADGER,
        weaponDBID = 0,
        unitCount = 8,
        loadoutID = nil,
        missionCreationParams = {
          {
            name = "AAR/C/STRIKE/1",
            type = "support",
            opts = {
              OneThirdRule = false,
              FlightSize = 2,
              Zone = constants.AREAS.AAR_PATROL_2
            }
          },
          {
            name = "AAR/C/SWEEP/1",
            type = "support",
            opts = {
              OneThirdRule = false,
              FlightSize = 2,
              Zone = constants.AREAS.AAR_PATROL_3
            }
          },
          {
            name = "AAR/C/JAMMING/1",
            type = "support",
            opts = {
              OneThirdRule = false,
              FlightSize = 2,
              Zone = constants.AREAS.AAR_PATROL_4
            }
          },
          {
            name = "AAR/C/SEAD/1",
            type = "support",
            opts = {
              OneThirdRule = false,
              FlightSize = 2,
              Zone = constants.AREAS.AAR_PATROL_1
            }
          },
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
      timeToReady = config.aircraftReadySec,
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
            TankerUsage = 1,
            TankerMissionList = { "AAR/S/STRIKE/1", "AAR/S/SWEEP/1", "AAR/S/SEAD/1" },
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
            ProsecutionZone = constants.AREAS.TARGET_AREA_SOUTH_PROSECUTION,
            PatrolZone = constants.AREAS.TARGET_AREA_SOUTH_PATROL,
            TankerUsage = 1,
            TankerMissionList = { "AAR/S/SWEEP/1" },
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
            ProsecutionZone = constants.AREAS.TARGET_AREA_SOUTH_PROSECUTION,
            PatrolZone = constants.AREAS.TARGET_AREA_SOUTH_PATROL,
            TankerUsage = 1,
            TankerMissionList = { "AAR/S/SEAD/1" },
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
          name = "JAMMING/AB/S/1",
          type = "support",
          opts = {
            Zone = constants.AREAS.TARGET_AREA_SOUTH_PATROL,
            TankerUsage = 1,
            TankerMissionList = { "AAR/S/JAMMING/1" },
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
        baseGUIDCandidates = { constants.BASES.LEIYANG_AB },
        unitDBID = constants.PLATFORMS.HY6U_BADGER,
        weaponDBID = 0,
        unitCount = 8,
        loadoutID = nil,
        missionCreationParams = {
          {
            name = "AAR/S/STRIKE/1",
            type = "support",
            opts = {
              OneThirdRule = false,
              FlightSize = 2,
              Zone = constants.AREAS.AAR_PATROL_2
            }
          },
          {
            name = "AAR/S/SWEEP/1",
            type = "support",
            opts = {
              OneThirdRule = false,
              FlightSize = 2,
              Zone = constants.AREAS.AAR_PATROL_3
            }
          },
          {
            name = "AAR/S/SEAD/1",
            type = "support",
            opts = {
              OneThirdRule = false,
              FlightSize = 2,
              Zone = constants.AREAS.AAR_PATROL_1
            }
          },
          {
            name = "AAR/S/JAMMING/1",
            type = "support",
            opts = {
              OneThirdRule = false,
              FlightSize = 2,
              Zone = constants.AREAS.AAR_PATROL_5
            }
          },
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
  AIR_STRIKE_AB_W_AAR_3 = {
    {
      timeToReady = config.aircraftReadySec,
      striker = {
        baseGUID = constants.BASES.TAIZHOU_AB,
        weaponDBID = constants.WEAPONS.KAB1500,
        unitDBID = constants.PLATFORMS.SU30,
        unitCount = 12,
        loadoutID = constants.LOADOUTS.SU30_KAB1500,
        startTime = nil,
        missionCreationParams = {
          name = "STRIKE/AB/N/3",
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
          name = "SWEEP/AB/N/3",
          type = "patrol",
          opts = {
            type = "aaw",
            OneThirdRule = false,
            FlightSize = 4,
            CheckOPAREA = false,
            CheckWWR = false,
            ProsecutionZone = constants.AREAS.TARGET_AREA_NORTH_PROSECUTION,
            PatrolZone = constants.AREAS.TARGET_AREA_NORTH_PATROL,
            TankerUsage = 1,
            TankerMissionList = { "AAR/N/SWEEP/3" },
            FuelQtyToStartLookingForTanker_airborne = 85,
            MaxReceiversInQueuePerTanker_airborne = 1,
            LaunchMissionWithoutTankersInPlace = true,
            TankerMaxDistance_airborne = 50
          }
        },
        emcon = "Radar=Passive;OECM=Active"
      },
      wildWeasel = {
        baseGUID = constants.BASES.JIAXING_AB,
        weaponDBID = constants.WEAPONS.YJ91_ASM,
        unitDBID = constants.PLATFORMS.J16,
        unitCount = 4,
        loadoutID = constants.LOADOUTS.J16_YJ91,
        missionCreationParams = {
          name = "SEAD/AB/N/3",
          type = "patrol",
          opts = {
            type = "sead",
            OneThirdRule = false,
            FlightSize = 4,
            CheckOPAREA = false,
            CheckWWR = false,
            ProsecutionZone = constants.AREAS.TARGET_AREA_NORTH_PROSECUTION,
            PatrolZone = constants.AREAS.TARGET_AREA_NORTH_PATROL,
            TankerUsage = 1,
            TankerMissionList = { "AAR/N/SEAD/3" },
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
          name = "JAMMING/AB/N/3",
          type = "support",
          opts = {
            Zone = constants.AREAS.TARGET_AREA_NORTH_PATROL,
            TankerUsage = 1,
            TankerMissionList = { "AAR/N/JAMMING/3" },
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
        baseGUIDCandidates = { constants.BASES.LEIYANG_AB },
        unitDBID = constants.PLATFORMS.HY6U_BADGER,
        weaponDBID = 0,
        unitCount = 8,
        loadoutID = nil,
        missionCreationParams = {
          {
            name = "AAR/N/SWEEP/3",
            type = "support",
            opts = {
              OneThirdRule = false,
              FlightSize = 2,
              Zone = constants.AREAS.AAR_PATROL_2
            }
          },
          {
            name = "AAR/N/JAMMING/3",
            type = "support",
            opts = {
              OneThirdRule = false,
              FlightSize = 2,
              Zone = constants.AREAS.AAR_PATROL_3
            }
          },
          {
            name = "AAR/N/SEAD/3",
            type = "support",
            opts = {
              OneThirdRule = false,
              FlightSize = 2,
              Zone = constants.AREAS.AAR_PATROL_1
            }
          },
        },
        emcon = "Radar=Passive;OECM=Passive"
      },
      reconUAV = nil,
      target = {
        list = {},
        objs = {
          { baseName = "Hsinchu AB", subTypes = { "Ammo Bunker" } }
        },
        areas = { constants.AREAS.AREA_OF_OPS_NORTH },
        filterNames = {},
        contactAge = 60 * 60,
        minTargetCount = 1
      },
    },
    {
      timeToReady = config.aircraftReadySec,
      striker = {
        baseGUID = constants.BASES.TAIZHOU_AB,
        weaponDBID = constants.WEAPONS.KAB1500,
        unitDBID = constants.PLATFORMS.SU30,
        unitCount = 12,
        loadoutID = constants.LOADOUTS.SU30_KAB1500,
        startTime = nil,
        missionCreationParams = {
          name = "STRIKE/AB/C/3",
          type = "strike",
          opts = {
            type = "land",
            TankerUsage = 1,
            TankerMissionList = { "AAR/C/STRIKE/3" },
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
          name = "SWEEP/AB/C/3",
          type = "patrol",
          opts = {
            type = "aaw",
            OneThirdRule = false,
            FlightSize = 4,
            CheckOPAREA = false,
            CheckWWR = false,
            ProsecutionZone = constants.AREAS.TARGET_AREA_CENTER_PROSECUTION,
            PatrolZone = constants.AREAS.TARGET_AREA_CENTER_PATROL,
            TankerUsage = 1,
            TankerMissionList = { "AAR/C/SWEEP/3" },
            FuelQtyToStartLookingForTanker_airborne = 85,
            MaxReceiversInQueuePerTanker_airborne = 1,
            LaunchMissionWithoutTankersInPlace = true,
            TankerMaxDistance_airborne = 50
          }
        },
        emcon = "Radar=Passive;OECM=Active"
      },
      wildWeasel = {
        baseGUID = constants.BASES.JIAXING_AB,
        weaponDBID = constants.WEAPONS.YJ91_ASM,
        unitDBID = constants.PLATFORMS.J16,
        unitCount = 4,
        loadoutID = constants.LOADOUTS.J16_YJ91,
        missionCreationParams = {
          name = "SEAD/AB/C/3",
          type = "patrol",
          opts = {
            type = "sead",
            OneThirdRule = false,
            FlightSize = 4,
            CheckOPAREA = false,
            CheckWWR = false,
            ProsecutionZone = constants.AREAS.TARGET_AREA_CENTER_PROSECUTION,
            PatrolZone = constants.AREAS.TARGET_AREA_CENTER_PATROL,
            TankerUsage = 1,
            TankerMissionList = { "AAR/C/SEAD/3" },
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
          name = "JAMMING/AB/C/3",
          type = "support",
          opts = {
            Zone = constants.AREAS.TARGET_AREA_CENTER_PATROL,
            TankerUsage = 1,
            TankerMissionList = { "AAR/C/JAMMING/3" },
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
        baseGUIDCandidates = { constants.BASES.LEIYANG_AB },
        unitDBID = constants.PLATFORMS.HY6U_BADGER,
        weaponDBID = 0,
        unitCount = 8,
        loadoutID = nil,
        missionCreationParams = {
          {
            name = "AAR/C/SEAD/3",
            type = "support",
            opts = {
              OneThirdRule = false,
              FlightSize = 2,
              Zone = constants.AREAS.AAR_PATROL_3
            }
          },
          {
            name = "AAR/C/SWEEP/3",
            type = "support",
            opts = {
              OneThirdRule = false,
              FlightSize = 2,
              Zone = constants.AREAS.AAR_PATROL_3
            }
          },
          {
            name = "AAR/C/JAMMING/3",
            type = "support",
            opts = {
              OneThirdRule = false,
              FlightSize = 2,
              Zone = constants.AREAS.AAR_PATROL_4
            }
          },
          {
            name = "AAR/C/STRIKE/3",
            type = "support",
            opts = {
              OneThirdRule = false,
              FlightSize = 2,
              Zone = constants.AREAS.AAR_PATROL_1
            }
          },
        },
        emcon = "Radar=Passive;OECM=Passive"
      },
      reconUAV = nil,
      target = {
        list = {},
        objs = {
          { baseName = "Ching Chuang Kang AB", subTypes = { "Ammo Bunker" } },
          { baseName = "Chiayi AB",            subTypes = { "Ammo Bunker" } }
        },
        areas = { constants.AREAS.AREA_OF_OPS_CENTER },
        filterNames = {},
        contactAge = 60 * 60,
        minTargetCount = 1
      },
    },
    {
      timeToReady = config.aircraftReadySec,
      striker = {
        baseGUID = constants.BASES.TAIZHOU_AB,
        weaponDBID = constants.WEAPONS.KAB1500,
        unitDBID = constants.PLATFORMS.SU30,
        unitCount = 12,
        loadoutID = constants.LOADOUTS.SU30_KAB1500,
        startTime = nil,
        missionCreationParams = {
          name = "STRIKE/AB/S/3",
          type = "strike",
          opts = {
            type = "land",
            TankerUsage = 1,
            TankerMissionList = { "AAR/S/STRIKE/3" },
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
          name = "SWEEP/AB/S/3",
          type = "patrol",
          opts = {
            type = "aaw",
            OneThirdRule = false,
            FlightSize = 4,
            CheckOPAREA = false,
            CheckWWR = false,
            ProsecutionZone = constants.AREAS.TARGET_AREA_SOUTH_PROSECUTION,
            PatrolZone = constants.AREAS.TARGET_AREA_SOUTH_PATROL,
            TankerUsage = 1,
            TankerMissionList = { "AAR/S/SWEEP/3" },
            FuelQtyToStartLookingForTanker_airborne = 85,
            MaxReceiversInQueuePerTanker_airborne = 1,
            LaunchMissionWithoutTankersInPlace = true,
            TankerMaxDistance_airborne = 50
          }
        },
        emcon = "Radar=Passive;OECM=Active"
      },
      wildWeasel = {
        baseGUID = constants.BASES.JIAXING_AB,
        weaponDBID = constants.WEAPONS.YJ91_ASM,
        unitDBID = constants.PLATFORMS.J16,
        unitCount = 4,
        loadoutID = constants.LOADOUTS.J16_YJ91,
        missionCreationParams = {
          name = "SEAD/AB/S/3",
          type = "patrol",
          opts = {
            type = "sead",
            OneThirdRule = false,
            FlightSize = 4,
            CheckOPAREA = false,
            CheckWWR = false,
            ProsecutionZone = constants.AREAS.TARGET_AREA_SOUTH_PROSECUTION,
            PatrolZone = constants.AREAS.TARGET_AREA_SOUTH_PATROL,
            TankerUsage = 1,
            TankerMissionList = { "AAR/S/SEAD/3" },
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
          name = "JAMMING/AB/S/3",
          type = "support",
          opts = {
            Zone = constants.AREAS.TARGET_AREA_SOUTH_PATROL,
            TankerUsage = 1,
            TankerMissionList = { "AAR/S/JAMMING/3" },
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
        baseGUIDCandidates = { constants.BASES.LEIYANG_AB },
        unitDBID = constants.PLATFORMS.HY6U_BADGER,
        weaponDBID = 0,
        unitCount = 8,
        loadoutID = nil,
        missionCreationParams = {
          {
            name = "AAR/S/SEAD/3",
            type = "support",
            opts = {
              OneThirdRule = false,
              FlightSize = 2,
              Zone = constants.AREAS.AAR_PATROL_2
            }
          },
          {
            name = "AAR/S/SWEEP/3",
            type = "support",
            opts = {
              OneThirdRule = false,
              FlightSize = 2,
              Zone = constants.AREAS.AAR_PATROL_3
            }
          },
          {
            name = "AAR/S/STRIKE/3",
            type = "support",
            opts = {
              OneThirdRule = false,
              FlightSize = 2,
              Zone = constants.AREAS.AAR_PATROL_1
            }
          },
          {
            name = "AAR/S/JAMMING/3",
            type = "support",
            opts = {
              OneThirdRule = false,
              FlightSize = 2,
              Zone = constants.AREAS.AAR_PATROL_5
            }
          },
        },
        emcon = "Radar=Passive;OECM=Passive"
      },
      reconUAV = nil,
      target = {
        list = {},
        objs = {
          { baseName = "Pingtung South AB", subTypes = { "Ammo Bunker" } },
          { baseName = "Tainan AB",         subTypes = { "Ammo Bunker" } },
          { baseName = "Magong AB",         subTypes = { "Ammo Bunker" } }
        },
        areas = { constants.AREAS.AREA_OF_OPS_SOUTH },
        filterNames = {},
        contactAge = 60 * 60,
        minTargetCount = 1
      },
    }
  },
  AIR_INTERCEPT_AIR_E_1 = {
    {
      timeToReady = config.aircraftReadySec,
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
            Zone = constants.AREAS.AAR_PATROL_3
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
  AIR_STRIKE_AB_E_1 = {
    {
      timeToReady = config.aircraftReadySec,
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
      --       ProsecutionZone = constants.AREASs.TARGET_AREA_JHI_PROSECUTION,
      --       PatrolZone = constants.AREASs.TARGET_AREA_JHI_PATROL
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
            ProsecutionZone = constants.AREAS.TARGET_AREA_JHI_PROSECUTION,
            PatrolZone = constants.AREAS.TARGET_AREA_JHI_PATROL
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
          opts = { Zone = constants.AREAS.TARGET_AREA_JHI_PATROL }
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
      timeToReady = config.aircraftReadySec,
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
      --       ProsecutionZone = constants.AREASs.TARGET_AREA_JIASHAN_PROSECUTION,
      --       PatrolZone = constants.AREASs.TARGET_AREA_JIASHAN_PATROL
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
            ProsecutionZone = constants.AREAS.TARGET_AREA_JIASHAN_PROSECUTION,
            PatrolZone = constants.AREAS.TARGET_AREA_JIASHAN_PATROL
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
          opts = { Zone = constants.AREAS.TARGET_AREA_JIASHAN_PATROL }
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
  AIR_ASUW_SHIP_N_1 = {
    {
      timeToReady = config.aircraftReadySec,
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
        baseGUID = constants.BASES.LONGTIAN_AAB,
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
            Zone = constants.AREAS.AREA_OF_OPS_D
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
  AIR_CAS_TROOPS_N_1 = {
    {
      timeToReady = config.aircraftReadySec,
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
config.red.packageTemplates.AIR_STRIKE_AB_W_AAR_2 = config.red.packageTemplates.AIR_STRIKE_AB_W_2


-- ============================================================================
-- GPS Jamming (Taiwan)
-- ============================================================================

config.blue.gnssJamming = {}
config.blue.gnssJamming.randomRadiusNm = 20 -- random radius
config.blue.gnssJamming.radiusNm = 11
config.blue.gnssJamming.gnssGuidedWeapons = {
  { dbid = constants.WEAPONS.FD280,    jammingResistance = 50 },
  { dbid = constants.WEAPONS.CJ10A,    jammingResistance = 50 },
  { dbid = constants.WEAPONS.AKD88,    jammingResistance = 50 },
  { dbid = constants.WEAPONS.LS_6_500, jammingResistance = 50 },
  { dbid = constants.WEAPONS.CS_BBC_5, jammingResistance = 50 },
}
config.blue.gnssJamming.jammers = {
  ["Comms & Info Coy, 584th Mech Bde"] = {
    zoneName = "(Taiwan) Jamming Zone/1",
    name = "Comms & Info Coy, 584th Mech Bde",
    pos = nil,
    randomRadiusNm = config.blue.gnssJamming.randomRadiusNm,
    radiusNm = config.blue.gnssJamming.radiusNm
  },
  ["Comms & Info Coy, 269th Mech Bde"] = {
    zoneName = "(Taiwan) Jamming Zone/2",
    name = "Comms & Info Coy, 269th Mech Bde",
    pos = nil,
    randomRadiusNm = config.blue.gnssJamming.randomRadiusNm,
    radiusNm = config.blue.gnssJamming.radiusNm
  },
}


-- ============================================================================
-- Ground policy (Taiwan)
-- ============================================================================

config.blue.ground = {}
config.blue.ground.policy = {
  isAuto = false,
  hideOnEnterHA = false,
  hideTransloaderOnRLNoMeeting = false
}
config.blue.ground.missileSystemTypes = {}

-- ============================================================================
-- MLRS (Taiwan)
-- ============================================================================

config.blue.ground.missileSystemTypes.mlrs = {}
config.blue.ground.missileSystemTypes.mlrs.weaponCountDefault = 144
config.blue.ground.missileSystemTypes.mlrs.ammoThreshold = 25
config.blue.ground.missileSystemTypes.mlrs.reloadTime = 30 * 60
config.blue.ground.missileSystemTypes.mlrs.stowTime = 5 * 60
config.blue.ground.missileSystemTypes.mlrs.canisterStocks = {
  ["Ammo Revetment, Rocket Arty Coy, 21st Arty Command"] = {
    name = "Ammo Revetment, Rocket Arty Coy, 21st Arty Command",
    weaponCountCurrent = config.blue.ground.missileSystemTypes.mlrs.weaponCountDefault,
    weaponCountDefault = config.blue.ground.missileSystemTypes.mlrs.weaponCountDefault,
  },
}
config.blue.ground.missileSystemTypes.mlrs.transloaders = {
  ["Ammo Sec, Rocket Arty Coy, 21st Arty Command"] = {
    name = "Ammo Sec, Rocket Arty Coy, 21st Arty Command",
    weaponCountCurrent = config.blue.ground.missileSystemTypes.mlrs.weaponCountDefault,
    weaponCountDefault = config.blue.ground.missileSystemTypes.mlrs.weaponCountDefault,
    unitCount = 2,
    operationalArea = constants.OPERATIONAL_AREAS.NVD,
    state = constants.MISSILE_UNIT_POSTURE.STATIC,
    canisterStock = "Ammo Revetment, Rocket Arty Coy, 21st Arty Command",
    launcher = "Rocket Arty Coy, 21st Arty Command"
  },
}
config.blue.ground.missileSystemTypes.mlrs.launchers = {
  ["Rocket Arty Coy, 21st Arty Command"] = {
    name = "Rocket Arty Coy, 21st Arty Command",
    msg = "Radio source, Bty",
    state = constants.MISSILE_UNIT_POSTURE.HIDE,
    operationalArea = constants.OPERATIONAL_AREAS.NVD,
    weaponDBID = constants.WEAPONS.MK45_AMLRS,
    ammoThreshold = config.blue.ground.missileSystemTypes.mlrs.ammoThreshold,
    transloader = "Ammo Sec, Rocket Arty Coy, 21st Arty Command",
    dbid = constants.PLATFORMS.LT2000,
    missileSystem = "LT-2000",
  },
}


-- ============================================================================
-- SRBM (Taiwan)
-- ============================================================================

config.blue.ground.missileSystemTypes.srbm = {}
config.blue.ground.missileSystemTypes.srbm.weaponCountDefault = 27
config.blue.ground.missileSystemTypes.srbm.ammoThreshold = 25
config.blue.ground.missileSystemTypes.srbm.reloadTime = 10 * 60
config.blue.ground.missileSystemTypes.srbm.stowTime = 5 * 60
config.blue.ground.missileSystemTypes.srbm.canisterStocks = {
  ["Ammo Revetment, Rocket Arty Coy, 58th Arty Command"] = {
    name = "Ammo Revetment, Rocket Arty Coy, 58th Arty Command",
    weaponCountCurrent = config.blue.ground.missileSystemTypes.srbm.weaponCountDefault,
    weaponCountDefault = config.blue.ground.missileSystemTypes.srbm.weaponCountDefault,
  },
}
config.blue.ground.missileSystemTypes.srbm.transloaders = {
  ["Ammo Sec, Rocket Arty Coy, 58th Arty Command"] = {
    name = "Ammo Sec, Rocket Arty Coy, 58th Arty Command",
    weaponCountCurrent = config.blue.ground.missileSystemTypes.srbm.weaponCountDefault,
    weaponCountDefault = config.blue.ground.missileSystemTypes.srbm.weaponCountDefault,
    unitCount = 3,
    operationalArea = constants.OPERATIONAL_AREAS.LPK,
    state = constants.MISSILE_UNIT_POSTURE.STATIC,
    canisterStock = "Ammo Revetment, Rocket Arty Coy, 58th Arty Command",
    launcher = "Rocket Arty Coy, 58th Arty Command"
  },
}
config.blue.ground.missileSystemTypes.srbm.launchers = {
  ["Rocket Arty Coy, 58th Arty Command"] = {
    name = "Rocket Arty Coy, 58th Arty Command",
    msg = "Radio source, Bty",
    state = constants.MISSILE_UNIT_POSTURE.HIDE,
    operationalArea = constants.OPERATIONAL_AREAS.LPK,
    weaponDBID = constants.WEAPONS.ATACMS,
    ammoThreshold = config.blue.ground.missileSystemTypes.srbm.ammoThreshold,
    transloader = "Ammo Sec, Rocket Arty Coy, 58th Arty Command",
    dbid = constants.PLATFORMS.HIMARS,
    missileSystem = "HIMARS",
  },
}


-- ============================================================================
-- GLCM (Taiwan)
-- ============================================================================

config.blue.ground.missileSystemTypes.glcm = {}
config.blue.ground.missileSystemTypes.glcm.weaponCountDefault = 48
config.blue.ground.missileSystemTypes.glcm.ammoThreshold = 25
config.blue.ground.missileSystemTypes.glcm.reloadTime = 45 * 60
config.blue.ground.missileSystemTypes.glcm.stowTime = 5 * 60
config.blue.ground.missileSystemTypes.glcm.canisterStocks = {
  ["Ammo Revetment, 641st Bn, 791st AFAD & Arty Bde"] = {
    name = "Ammo Revetment, 641st Bn, 791st AFAD & Arty Bde",
    weaponCountCurrent = config.blue.ground.missileSystemTypes.glcm.weaponCountDefault * 2,
    weaponCountDefault = config.blue.ground.missileSystemTypes.glcm.weaponCountDefault * 2,
  },
  ["Ammo Revetment, 642nd Bn, 791st AFAD & Arty Bde"] = {
    name = "Ammo Revetment, 642nd Bn, 791st AFAD & Arty Bde",
    weaponCountCurrent = config.blue.ground.missileSystemTypes.glcm.weaponCountDefault * 2,
    weaponCountDefault = config.blue.ground.missileSystemTypes.glcm.weaponCountDefault * 2,
  },
}
config.blue.ground.missileSystemTypes.glcm.transloaders = {
  ["Ammo Sec, 641st Bn, 791st AFAD & Arty Bde"] = {
    name = "Ammo Sec, 641st Bn, 791st AFAD & Arty Bde",
    weaponCountCurrent = config.blue.ground.missileSystemTypes.glcm.weaponCountDefault,
    weaponCountDefault = config.blue.ground.missileSystemTypes.glcm.weaponCountDefault,
    unitCount = 3,
    operationalArea = constants.OPERATIONAL_AREAS.SET,
    state = constants.MISSILE_UNIT_POSTURE.STATIC,
    canisterStock = "Ammo Revetment, 641st Bn, 791st AFAD & Arty Bde",
    launcher = "641st Bn, 791st AFAD & Arty Bde"
  },
  ["Ammo Sec, 642nd Bn, 791st AFAD & Arty Bde"] = {
    name = "Ammo Sec, 642nd Bn, 791st AFAD & Arty Bde",
    weaponCountCurrent = config.blue.ground.missileSystemTypes.glcm.weaponCountDefault,
    weaponCountDefault = config.blue.ground.missileSystemTypes.glcm.weaponCountDefault,
    unitCount = 3,
    operationalArea = constants.OPERATIONAL_AREAS.AMG,
    state = constants.MISSILE_UNIT_POSTURE.STATIC,
    canisterStock = "Ammo Revetment, 642nd Bn, 791st AFAD & Arty Bde",
    launcher = "642nd Bn, 791st AFAD & Arty Bde"
  },
}
config.blue.ground.missileSystemTypes.glcm.launchers = {
  ["641st Bn, 791st AFAD & Arty Bde"] = {
    name = "641st Bn, 791st AFAD & Arty Bde",
    msg = "Radio source, Bty",
    state = constants.MISSILE_UNIT_POSTURE.HIDE,
    operationalArea = constants.OPERATIONAL_AREAS.SET,
    weaponDBID = constants.WEAPONS.HF2E,
    ammoThreshold = config.blue.ground.missileSystemTypes.glcm.ammoThreshold,
    transloader = "Ammo Sec, 641st Bn, 791st AFAD & Arty Bde",
    dbid = constants.PLATFORMS.CUSTOMED_SSM,
    missileSystem = "HF-2E",
    mountDescriptors = constants.MOUNT_DESCRIPTORS.HF2E,
  },
  ["642nd Bn, 791st AFAD & Arty Bde"] = {
    name = "642nd Bn, 791st AFAD & Arty Bde",
    msg = "Radio source, Bty",
    state = constants.MISSILE_UNIT_POSTURE.HIDE,
    operationalArea = constants.OPERATIONAL_AREAS.AMG,
    weaponDBID = constants.WEAPONS.HF2E,
    ammoThreshold = config.blue.ground.missileSystemTypes.glcm.ammoThreshold,
    transloader = "Ammo Sec, 642nd Bn, 791st AFAD & Arty Bde",
    dbid = constants.PLATFORMS.CUSTOMED_SSM,
    missileSystem = "HF-2E",
    mountDescriptors = constants.MOUNT_DESCRIPTORS.HF2E,
  },
}


-- ============================================================================
-- ASCM (Taiwan)
-- ============================================================================

config.blue.ground.missileSystemTypes.ascm = {}
config.blue.ground.missileSystemTypes.ascm.weaponCountDefault = 16
config.blue.ground.missileSystemTypes.ascm.ammoThreshold = 25
-- config.blue.ground.missileSystemTypes.ascm.reloadTime = 45 * 60
config.blue.ground.missileSystemTypes.ascm.reloadTime = 5 * 60
config.blue.ground.missileSystemTypes.ascm.stowTime = 5 * 60
config.blue.ground.missileSystemTypes.ascm.canisterStocks = {
  ["Ammo Revetment, 1st Hai Feng Shore-based ASM MOB Sqn"] = {
    name = "Ammo Revetment, 1st Hai Feng Shore-based ASM MOB Sqn",
    weaponCountCurrent = config.blue.ground.missileSystemTypes.ascm.weaponCountDefault * 2,
    weaponCountDefault = config.blue.ground.missileSystemTypes.ascm.weaponCountDefault * 2,
  },
  ["Ammo Revetment, 2nd Hai Feng Shore-based ASM MOB Sqn"] = {
    name = "Ammo Revetment, 2nd Hai Feng Shore-based ASM MOB Sqn",
    weaponCountCurrent = config.blue.ground.missileSystemTypes.ascm.weaponCountDefault * 2,
    weaponCountDefault = config.blue.ground.missileSystemTypes.ascm.weaponCountDefault * 2,
  },
  ["Ammo Revetment, 3rd Hai Feng Shore-based ASM MOB Sqn"] = {
    name = "Ammo Revetment, 3rd Hai Feng Shore-based ASM MOB Sqn",
    weaponCountCurrent = config.blue.ground.missileSystemTypes.ascm.weaponCountDefault * 2,
    weaponCountDefault = config.blue.ground.missileSystemTypes.ascm.weaponCountDefault * 2,
  },
  ["Ammo Revetment, 4th Hai Feng Shore-based ASM MOB Sqn"] = {
    name = "Ammo Revetment, 4th Hai Feng Shore-based ASM MOB Sqn",
    weaponCountCurrent = config.blue.ground.missileSystemTypes.ascm.weaponCountDefault * 2,
    weaponCountDefault = config.blue.ground.missileSystemTypes.ascm.weaponCountDefault * 2,
  },
  ["Ammo Revetment, 5th Hai Feng Shore-based ASM MOB Sqn"] = {
    name = "Ammo Revetment, 5th Hai Feng Shore-based ASM MOB Sqn",
    weaponCountCurrent = config.blue.ground.missileSystemTypes.ascm.weaponCountDefault * 2,
    weaponCountDefault = config.blue.ground.missileSystemTypes.ascm.weaponCountDefault * 2,
  },
  ["Ammo Revetment, 6th Hai Feng Shore-based ASM MOB Sqn"] = {
    name = "Ammo Revetment, 6th Hai Feng Shore-based ASM MOB Sqn",
    weaponCountCurrent = config.blue.ground.missileSystemTypes.ascm.weaponCountDefault * 2,
    weaponCountDefault = config.blue.ground.missileSystemTypes.ascm.weaponCountDefault * 2,
  },
}
config.blue.ground.missileSystemTypes.ascm.transloaders = {
  ["Ammo Sec, 1st Hai Feng Shore-based ASM MOB Sqn"] = {
    name = "Ammo Sec, 1st Hai Feng Shore-based ASM MOB Sqn",
    weaponCountCurrent = config.blue.ground.missileSystemTypes.ascm.weaponCountDefault,
    weaponCountDefault = config.blue.ground.missileSystemTypes.ascm.weaponCountDefault,
    unitCount = 2,
    operationalArea = constants.OPERATIONAL_AREAS.FZM,
    state = constants.MISSILE_UNIT_POSTURE.STATIC,
    canisterStock = "Ammo Revetment, 1st Hai Feng Shore-based ASM MOB Sqn",
    launcher = "1st Hai Feng Shore-based ASM MOB Sqn"
  },
  ["Ammo Sec, 2nd Hai Feng Shore-based ASM MOB Sqn"] = {
    name = "Ammo Sec, 2nd Hai Feng Shore-based ASM MOB Sqn",
    weaponCountCurrent = config.blue.ground.missileSystemTypes.ascm.weaponCountDefault,
    weaponCountDefault = config.blue.ground.missileSystemTypes.ascm.weaponCountDefault,
    unitCount = 2,
    operationalArea = constants.OPERATIONAL_AREAS.DLF,
    state = constants.MISSILE_UNIT_POSTURE.STATIC,
    canisterStock = "Ammo Revetment, 2nd Hai Feng Shore-based ASM MOB Sqn",
    launcher = "2nd Hai Feng Shore-based ASM MOB Sqn"
  },
  ["Ammo Sec, 3rd Hai Feng Shore-based ASM MOB Sqn"] = {
    name = "Ammo Sec, 3rd Hai Feng Shore-based ASM MOB Sqn",
    weaponCountCurrent = config.blue.ground.missileSystemTypes.ascm.weaponCountDefault,
    weaponCountDefault = config.blue.ground.missileSystemTypes.ascm.weaponCountDefault,
    unitCount = 2,
    operationalArea = constants.OPERATIONAL_AREAS.TGO,
    state = constants.MISSILE_UNIT_POSTURE.STATIC,
    canisterStock = "Ammo Revetment, 3rd Hai Feng Shore-based ASM MOB Sqn",
    launcher = "3rd Hai Feng Shore-based ASM MOB Sqn"
  },
  ["Ammo Sec, 4th Hai Feng Shore-based ASM MOB Sqn"] = {
    name = "Ammo Sec, 4th Hai Feng Shore-based ASM MOB Sqn",
    weaponCountCurrent = config.blue.ground.missileSystemTypes.ascm.weaponCountDefault,
    weaponCountDefault = config.blue.ground.missileSystemTypes.ascm.weaponCountDefault,
    unitCount = 2,
    operationalArea = constants.OPERATIONAL_AREAS.BPM,
    state = constants.MISSILE_UNIT_POSTURE.STATIC,
    canisterStock = "Ammo Revetment, 4th Hai Feng Shore-based ASM MOB Sqn",
    launcher = "4th Hai Feng Shore-based ASM MOB Sqn"
  },
  ["Ammo Sec, 5th Hai Feng Shore-based ASM MOB Sqn"] = {
    name = "Ammo Sec, 5th Hai Feng Shore-based ASM MOB Sqn",
    weaponCountCurrent = config.blue.ground.missileSystemTypes.ascm.weaponCountDefault,
    weaponCountDefault = config.blue.ground.missileSystemTypes.ascm.weaponCountDefault,
    unitCount = 2,
    operationalArea = constants.OPERATIONAL_AREAS.PDN,
    state = constants.MISSILE_UNIT_POSTURE.STATIC,
    canisterStock = "Ammo Revetment, 5th Hai Feng Shore-based ASM MOB Sqn",
    launcher = "5th Hai Feng Shore-based ASM MOB Sqn"
  },
  ["Ammo Sec, 6th Hai Feng Shore-based ASM MOB Sqn"] = {
    name = "Ammo Sec, 6th Hai Feng Shore-based ASM MOB Sqn",
    weaponCountCurrent = config.blue.ground.missileSystemTypes.ascm.weaponCountDefault,
    weaponCountDefault = config.blue.ground.missileSystemTypes.ascm.weaponCountDefault,
    unitCount = 2,
    operationalArea = constants.OPERATIONAL_AREAS.SKB,
    state = constants.MISSILE_UNIT_POSTURE.STATIC,
    canisterStock = "Ammo Revetment, 6th Hai Feng Shore-based ASM MOB Sqn",
    launcher = "6th Hai Feng Shore-based ASM MOB Sqn"
  },
}
config.blue.ground.missileSystemTypes.ascm.launchers = {
  ["1st Hai Feng Shore-based ASM MOB Sqn"] = {
    name = "1st Hai Feng Shore-based ASM MOB Sqn",
    msg = "Radio source, Bty",
    state = constants.MISSILE_UNIT_POSTURE.HIDE,
    operationalArea = constants.OPERATIONAL_AREAS.FZM,
    weaponDBID = constants.WEAPONS.HF3,
    ammoThreshold = config.blue.ground.missileSystemTypes.ascm.ammoThreshold,
    transloader = "Ammo Sec, 1st Hai Feng Shore-based ASM MOB Sqn",
    dbid = constants.PLATFORMS.HF3,
    missileSystem = "HF-3",
  },
  ["2nd Hai Feng Shore-based ASM MOB Sqn"] = {
    name = "2nd Hai Feng Shore-based ASM MOB Sqn",
    msg = "Radio source, Bty",
    state = constants.MISSILE_UNIT_POSTURE.HIDE,
    operationalArea = constants.OPERATIONAL_AREAS.DLF,
    weaponDBID = constants.WEAPONS.HF3,
    ammoThreshold = config.blue.ground.missileSystemTypes.ascm.ammoThreshold,
    transloader = "Ammo Sec, 2nd Hai Feng Shore-based ASM MOB Sqn",
    dbid = constants.PLATFORMS.HF3,
    missileSystem = "HF-3",
  },
  ["3rd Hai Feng Shore-based ASM MOB Sqn"] = {
    name = "3rd Hai Feng Shore-based ASM MOB Sqn",
    msg = "Radio source, Bty",
    state = constants.MISSILE_UNIT_POSTURE.HIDE,
    operationalArea = constants.OPERATIONAL_AREAS.TGO,
    weaponDBID = constants.WEAPONS.HF3,
    ammoThreshold = config.blue.ground.missileSystemTypes.ascm.ammoThreshold,
    transloader = "Ammo Sec, 3rd Hai Feng Shore-based ASM MOB Sqn",
    dbid = constants.PLATFORMS.HF3,
    missileSystem = "HF-3",
  },
  ["4th Hai Feng Shore-based ASM MOB Sqn"] = {
    name = "4th Hai Feng Shore-based ASM MOB Sqn",
    msg = "Radio source, Bty",
    state = constants.MISSILE_UNIT_POSTURE.HIDE,
    operationalArea = constants.OPERATIONAL_AREAS.BPM,
    weaponDBID = constants.WEAPONS.HF3,
    ammoThreshold = config.blue.ground.missileSystemTypes.ascm.ammoThreshold,
    transloader = "Ammo Sec, 4th Hai Feng Shore-based ASM MOB Sqn",
    dbid = constants.PLATFORMS.HF3,
    missileSystem = "HF-3",
  },
  ["5th Hai Feng Shore-based ASM MOB Sqn"] = {
    name = "5th Hai Feng Shore-based ASM MOB Sqn",
    msg = "Radio source, Bty",
    state = constants.MISSILE_UNIT_POSTURE.HIDE,
    operationalArea = constants.OPERATIONAL_AREAS.PDN,
    weaponDBID = constants.WEAPONS.HF3,
    ammoThreshold = config.blue.ground.missileSystemTypes.ascm.ammoThreshold,
    transloader = "Ammo Sec, 5th Hai Feng Shore-based ASM MOB Sqn",
    dbid = constants.PLATFORMS.HF3,
    missileSystem = "HF-3",
  },
  ["6th Hai Feng Shore-based ASM MOB Sqn"] = {
    name = "6th Hai Feng Shore-based ASM MOB Sqn",
    msg = "Radio source, Bty",
    state = constants.MISSILE_UNIT_POSTURE.HIDE,
    operationalArea = constants.OPERATIONAL_AREAS.SKB,
    weaponDBID = constants.WEAPONS.HF3,
    ammoThreshold = config.blue.ground.missileSystemTypes.ascm.ammoThreshold,
    transloader = "Ammo Sec, 6th Hai Feng Shore-based ASM MOB Sqn",
    dbid = constants.PLATFORMS.HF3,
    missileSystem = "HF-3",
  },
}


-- ============================================================================
-- SAM (Taiwan)
-- ============================================================================

config.blue.ground.missileSystemTypes.sam = {}
config.blue.ground.missileSystemTypes.sam.weaponCountDefault = 54
config.blue.ground.missileSystemTypes.sam.ammoThreshold = 50
config.blue.ground.missileSystemTypes.sam.reloadTime = 5 * 60
config.blue.ground.missileSystemTypes.sam.stowTime = 5 * 60
config.blue.ground.missileSystemTypes.sam.canisterStocks = {
  ["Ammo Revetment, 1st Coy, 613rd Bn, 792nd AFAD & Arty Bde"] = {
    name = "Ammo Revetment, 1st Coy, 613rd Bn, 792nd AFAD & Arty Bde",
    weaponCountCurrent = 96,
    weaponCountDefault = 96,
  },
  ["Ammo Revetment, 1st Coy, 614th Bn, 793rd AFAD & Arty Bde"] = {
    name = "Ammo Revetment, 1st Coy, 614th Bn, 793rd AFAD & Arty Bde",
    weaponCountCurrent = 96,
    weaponCountDefault = 96,
  },
  ["Ammo Revetment, 1st Coy, 631st Bn, 793rd AFAD & Arty Bde"] = {
    name = "Ammo Revetment, 1st Coy, 631st Bn, 793rd AFAD & Arty Bde",
    weaponCountCurrent = config.blue.ground.missileSystemTypes.sam.weaponCountDefault * 2,
    weaponCountDefault = config.blue.ground.missileSystemTypes.sam.weaponCountDefault * 2,
  },
  ["Ammo Revetment, 1st Coy, 632nd Bn, 794th AFAD & Arty Bde"] = {
    name = "Ammo Revetment, 1st Coy, 632nd Bn, 794th AFAD & Arty Bde",
    weaponCountCurrent = config.blue.ground.missileSystemTypes.sam.weaponCountDefault * 2,
    weaponCountDefault = config.blue.ground.missileSystemTypes.sam.weaponCountDefault * 2,
  },
  ["Ammo Revetment, 1st Coy, 633rd Bn, 795th AFAD & Arty Bde"] = {
    name = "Ammo Revetment, 1st Coy, 633rd Bn, 795th AFAD & Arty Bde",
    weaponCountCurrent = config.blue.ground.missileSystemTypes.sam.weaponCountDefault * 2,
    weaponCountDefault = config.blue.ground.missileSystemTypes.sam.weaponCountDefault * 2,
  },
  ["Ammo Revetment, 2nd Coy, 613rd Bn, 792nd AFAD & Arty Bde"] = {
    name = "Ammo Revetment, 2nd Coy, 613rd Bn, 792nd AFAD & Arty Bde",
    weaponCountCurrent = 96,
    weaponCountDefault = 96,
  },
  ["Ammo Revetment, 2nd Coy, 614th Bn, 793rd AFAD & Arty Bde"] = {
    name = "Ammo Revetment, 2nd Coy, 614th Bn, 793rd AFAD & Arty Bde",
    weaponCountCurrent = 96,
    weaponCountDefault = 96,
  },
  ["Ammo Revetment, 2nd Coy, 631st Bn, 793rd AFAD & Arty Bde"] = {
    name = "Ammo Revetment, 2nd Coy, 631st Bn, 793rd AFAD & Arty Bde",
    weaponCountCurrent = config.blue.ground.missileSystemTypes.sam.weaponCountDefault * 2,
    weaponCountDefault = config.blue.ground.missileSystemTypes.sam.weaponCountDefault * 2,
  },
  ["Ammo Revetment, 2nd Coy, 632nd Bn, 794th AFAD & Arty Bde"] = {
    name = "Ammo Revetment, 2nd Coy, 632nd Bn, 794th AFAD & Arty Bde",
    weaponCountCurrent = config.blue.ground.missileSystemTypes.sam.weaponCountDefault * 2,
    weaponCountDefault = config.blue.ground.missileSystemTypes.sam.weaponCountDefault * 2,
  },
  ["Ammo Revetment, 2nd Coy, 633rd Bn, 795th AFAD & Arty Bde"] = {
    name = "Ammo Revetment, 2nd Coy, 633rd Bn, 795th AFAD & Arty Bde",
    weaponCountCurrent = config.blue.ground.missileSystemTypes.sam.weaponCountDefault * 2,
    weaponCountDefault = config.blue.ground.missileSystemTypes.sam.weaponCountDefault * 2,
  },
  ["Ammo Revetment, 3rd Coy, 613rd Bn, 792nd AFAD & Arty Bde"] = {
    name = "Ammo Revetment, 3rd Coy, 613rd Bn, 792nd AFAD & Arty Bde",
    weaponCountCurrent = 96,
    weaponCountDefault = 96,
  },
  ["Ammo Revetment, 3rd Coy, 614th Bn, 793rd AFAD & Arty Bde"] = {
    name = "Ammo Revetment, 3rd Coy, 614th Bn, 793rd AFAD & Arty Bde",
    weaponCountCurrent = 96,
    weaponCountDefault = 96,
  },
  ["Ammo Revetment, 3rd Coy, 631st Bn, 793rd AFAD & Arty Bde"] = {
    name = "Ammo Revetment, 3rd Coy, 631st Bn, 793rd AFAD & Arty Bde",
    weaponCountCurrent = config.blue.ground.missileSystemTypes.sam.weaponCountDefault * 2,
    weaponCountDefault = config.blue.ground.missileSystemTypes.sam.weaponCountDefault * 2,
  },
  ["Ammo Revetment, 3rd Coy, 632nd Bn, 794th AFAD & Arty Bde"] = {
    name = "Ammo Revetment, 3rd Coy, 632nd Bn, 794th AFAD & Arty Bde",
    weaponCountCurrent = config.blue.ground.missileSystemTypes.sam.weaponCountDefault * 2,
    weaponCountDefault = config.blue.ground.missileSystemTypes.sam.weaponCountDefault * 2,
  },
  ["Ammo Revetment, 3rd Coy, 633rd Bn, 795th AFAD & Arty Bde"] = {
    name = "Ammo Revetment, 3rd Coy, 633rd Bn, 795th AFAD & Arty Bde",
    weaponCountCurrent = config.blue.ground.missileSystemTypes.sam.weaponCountDefault * 2,
    weaponCountDefault = config.blue.ground.missileSystemTypes.sam.weaponCountDefault * 2,
  },
}
config.blue.ground.missileSystemTypes.sam.transloaders = {
  ["Ammo Sec, 1st Coy, 613rd Bn, 792nd AFAD & Arty Bde"] = {
    name = "Ammo Sec, 1st Coy, 613rd Bn, 792nd AFAD & Arty Bde",
    weaponCountCurrent = 48,
    weaponCountDefault = 48,
    unitCount = 1,
    operationalArea = constants.OPERATIONAL_AREAS.IKJ,
    state = constants.MISSILE_UNIT_POSTURE.STATIC,
    canisterStock = "Ammo Revetment, 1st Coy, 613rd Bn, 792nd AFAD & Arty Bde",
    launcher = "1st Coy, 613rd Bn, 792nd AFAD & Arty Bde"
  },
  ["Ammo Sec, 1st Coy, 614th Bn, 793rd AFAD & Arty Bde"] = {
    name = "Ammo Sec, 1st Coy, 614th Bn, 793rd AFAD & Arty Bde",
    weaponCountCurrent = 48,
    weaponCountDefault = 48,
    unitCount = 1,
    operationalArea = constants.OPERATIONAL_AREAS.UVY,
    state = constants.MISSILE_UNIT_POSTURE.STATIC,
    canisterStock = "Ammo Revetment, 1st Coy, 614th Bn, 793rd AFAD & Arty Bde",
    launcher = "1st Coy, 614th Bn, 793rd AFAD & Arty Bde"
  },
  ["Ammo Sec, 1st Coy, 631st Bn, 793rd AFAD & Arty Bde"] = {
    name = "Ammo Sec, 1st Coy, 631st Bn, 793rd AFAD & Arty Bde",
    weaponCountCurrent = config.blue.ground.missileSystemTypes.sam.weaponCountDefault,
    weaponCountDefault = config.blue.ground.missileSystemTypes.sam.weaponCountDefault,
    unitCount = 1,
    operationalArea = constants.OPERATIONAL_AREAS.QPF,
    state = constants.MISSILE_UNIT_POSTURE.STATIC,
    canisterStock = "Ammo Revetment, 1st Coy, 631st Bn, 793rd AFAD & Arty Bde",
    launcher = "1st Coy, 631st Bn, 793rd AFAD & Arty Bde"
  },
  ["Ammo Sec, 1st Coy, 632nd Bn, 794th AFAD & Arty Bde"] = {
    name = "Ammo Sec, 1st Coy, 632nd Bn, 794th AFAD & Arty Bde",
    weaponCountCurrent = config.blue.ground.missileSystemTypes.sam.weaponCountDefault,
    weaponCountDefault = config.blue.ground.missileSystemTypes.sam.weaponCountDefault,
    unitCount = 1,
    operationalArea = constants.OPERATIONAL_AREAS.NUJ,
    state = constants.MISSILE_UNIT_POSTURE.STATIC,
    canisterStock = "Ammo Revetment, 1st Coy, 632nd Bn, 794th AFAD & Arty Bde",
    launcher = "1st Coy, 632nd Bn, 794th AFAD & Arty Bde"
  },
  ["Ammo Sec, 1st Coy, 633rd Bn, 795th AFAD & Arty Bde"] = {
    name = "Ammo Sec, 1st Coy, 633rd Bn, 795th AFAD & Arty Bde",
    weaponCountCurrent = config.blue.ground.missileSystemTypes.sam.weaponCountDefault,
    weaponCountDefault = config.blue.ground.missileSystemTypes.sam.weaponCountDefault,
    unitCount = 1,
    operationalArea = constants.OPERATIONAL_AREAS.QTZ,
    state = constants.MISSILE_UNIT_POSTURE.STATIC,
    canisterStock = "Ammo Revetment, 1st Coy, 633rd Bn, 795th AFAD & Arty Bde",
    launcher = "1st Coy, 633rd Bn, 795th AFAD & Arty Bde"
  },
  ["Ammo Sec, 2nd Coy, 613rd Bn, 792nd AFAD & Arty Bde"] = {
    name = "Ammo Sec, 2nd Coy, 613rd Bn, 792nd AFAD & Arty Bde",
    weaponCountCurrent = 48,
    weaponCountDefault = 48,
    unitCount = 1,
    operationalArea = constants.OPERATIONAL_AREAS.MAK,
    state = constants.MISSILE_UNIT_POSTURE.STATIC,
    canisterStock = "Ammo Revetment, 2nd Coy, 613rd Bn, 792nd AFAD & Arty Bde",
    launcher = "2nd Coy, 613rd Bn, 792nd AFAD & Arty Bde"
  },
  ["Ammo Sec, 2nd Coy, 614th Bn, 793rd AFAD & Arty Bde"] = {
    name = "Ammo Sec, 2nd Coy, 614th Bn, 793rd AFAD & Arty Bde",
    weaponCountCurrent = 48,
    weaponCountDefault = 48,
    unitCount = 1,
    operationalArea = constants.OPERATIONAL_AREAS.FMK,
    state = constants.MISSILE_UNIT_POSTURE.STATIC,
    canisterStock = "Ammo Revetment, 2nd Coy, 614th Bn, 793rd AFAD & Arty Bde",
    launcher = "2nd Coy, 614th Bn, 793rd AFAD & Arty Bde"
  },
  ["Ammo Sec, 2nd Coy, 631st Bn, 793rd AFAD & Arty Bde"] = {
    name = "Ammo Sec, 2nd Coy, 631st Bn, 793rd AFAD & Arty Bde",
    weaponCountCurrent = config.blue.ground.missileSystemTypes.sam.weaponCountDefault,
    weaponCountDefault = config.blue.ground.missileSystemTypes.sam.weaponCountDefault,
    unitCount = 1,
    operationalArea = constants.OPERATIONAL_AREAS.XDY,
    state = constants.MISSILE_UNIT_POSTURE.STATIC,
    canisterStock = "Ammo Revetment, 2nd Coy, 631st Bn, 793rd AFAD & Arty Bde",
    launcher = "2nd Coy, 631st Bn, 793rd AFAD & Arty Bde"
  },
  ["Ammo Sec, 2nd Coy, 632nd Bn, 794th AFAD & Arty Bde"] = {
    name = "Ammo Sec, 2nd Coy, 632nd Bn, 794th AFAD & Arty Bde",
    weaponCountCurrent = config.blue.ground.missileSystemTypes.sam.weaponCountDefault,
    weaponCountDefault = config.blue.ground.missileSystemTypes.sam.weaponCountDefault,
    unitCount = 1,
    operationalArea = constants.OPERATIONAL_AREAS.DJA,
    state = constants.MISSILE_UNIT_POSTURE.STATIC,
    canisterStock = "Ammo Revetment, 2nd Coy, 632nd Bn, 794th AFAD & Arty Bde",
    launcher = "2nd Coy, 632nd Bn, 794th AFAD & Arty Bde"
  },
  ["Ammo Sec, 2nd Coy, 633rd Bn, 795th AFAD & Arty Bde"] = {
    name = "Ammo Sec, 2nd Coy, 633rd Bn, 795th AFAD & Arty Bde",
    weaponCountCurrent = config.blue.ground.missileSystemTypes.sam.weaponCountDefault,
    weaponCountDefault = config.blue.ground.missileSystemTypes.sam.weaponCountDefault,
    unitCount = 1,
    operationalArea = constants.OPERATIONAL_AREAS.GRV,
    state = constants.MISSILE_UNIT_POSTURE.STATIC,
    canisterStock = "Ammo Revetment, 2nd Coy, 633rd Bn, 795th AFAD & Arty Bde",
    launcher = "2nd Coy, 633rd Bn, 795th AFAD & Arty Bde"
  },
  ["Ammo Sec, 3rd Coy, 613rd Bn, 792nd AFAD & Arty Bde"] = {
    name = "Ammo Sec, 3rd Coy, 613rd Bn, 792nd AFAD & Arty Bde",
    weaponCountCurrent = 48,
    weaponCountDefault = 48,
    unitCount = 1,
    operationalArea = constants.OPERATIONAL_AREAS.PXV,
    state = constants.MISSILE_UNIT_POSTURE.STATIC,
    canisterStock = "Ammo Revetment, 3rd Coy, 613rd Bn, 792nd AFAD & Arty Bde",
    launcher = "3rd Coy, 613rd Bn, 792nd AFAD & Arty Bde"
  },
  ["Ammo Sec, 3rd Coy, 614th Bn, 793rd AFAD & Arty Bde"] = {
    name = "Ammo Sec, 3rd Coy, 614th Bn, 793rd AFAD & Arty Bde",
    weaponCountCurrent = 48,
    weaponCountDefault = 48,
    unitCount = 1,
    operationalArea = constants.OPERATIONAL_AREAS.IDW,
    state = constants.MISSILE_UNIT_POSTURE.STATIC,
    canisterStock = "Ammo Revetment, 3rd Coy, 614th Bn, 793rd AFAD & Arty Bde",
    launcher = "3rd Coy, 614th Bn, 793rd AFAD & Arty Bde"
  },
  ["Ammo Sec, 3rd Coy, 631st Bn, 793rd AFAD & Arty Bde"] = {
    name = "Ammo Sec, 3rd Coy, 631st Bn, 793rd AFAD & Arty Bde",
    weaponCountCurrent = config.blue.ground.missileSystemTypes.sam.weaponCountDefault,
    weaponCountDefault = config.blue.ground.missileSystemTypes.sam.weaponCountDefault,
    unitCount = 1,
    operationalArea = constants.OPERATIONAL_AREAS.CSC,
    state = constants.MISSILE_UNIT_POSTURE.STATIC,
    canisterStock = "Ammo Revetment, 3rd Coy, 631st Bn, 793rd AFAD & Arty Bde",
    launcher = "3rd Coy, 631st Bn, 793rd AFAD & Arty Bde"
  },
  ["Ammo Sec, 3rd Coy, 632nd Bn, 794th AFAD & Arty Bde"] = {
    name = "Ammo Sec, 3rd Coy, 632nd Bn, 794th AFAD & Arty Bde",
    weaponCountCurrent = config.blue.ground.missileSystemTypes.sam.weaponCountDefault,
    weaponCountDefault = config.blue.ground.missileSystemTypes.sam.weaponCountDefault,
    unitCount = 1,
    operationalArea = constants.OPERATIONAL_AREAS.RHM,
    state = constants.MISSILE_UNIT_POSTURE.STATIC,
    canisterStock = "Ammo Revetment, 3rd Coy, 632nd Bn, 794th AFAD & Arty Bde",
    launcher = "3rd Coy, 632nd Bn, 794th AFAD & Arty Bde"
  },
  ["Ammo Sec, 3rd Coy, 633rd Bn, 795th AFAD & Arty Bde"] = {
    name = "Ammo Sec, 3rd Coy, 633rd Bn, 795th AFAD & Arty Bde",
    weaponCountCurrent = config.blue.ground.missileSystemTypes.sam.weaponCountDefault,
    weaponCountDefault = config.blue.ground.missileSystemTypes.sam.weaponCountDefault,
    unitCount = 1,
    operationalArea = constants.OPERATIONAL_AREAS.UYO,
    state = constants.MISSILE_UNIT_POSTURE.STATIC,
    canisterStock = "Ammo Revetment, 3rd Coy, 633rd Bn, 795th AFAD & Arty Bde",
    launcher = "3rd Coy, 633rd Bn, 795th AFAD & Arty Bde"
  },
}
config.blue.ground.missileSystemTypes.sam.launchers = {
  ["1st Coy, 613rd Bn, 792nd AFAD & Arty Bde"] = {
    name = "1st Coy, 613rd Bn, 792nd AFAD & Arty Bde",
    state = constants.MISSILE_UNIT_POSTURE.STATIC,
    operationalArea = constants.OPERATIONAL_AREAS.IKJ,
    weaponDBID = constants.WEAPONS.TK3,
    ammoThreshold = config.blue.ground.missileSystemTypes.sam.ammoThreshold,
    transloader = "Ammo Sec, 1st Coy, 613rd Bn, 792nd AFAD & Arty Bde",
    dbid = constants.PLATFORMS.CUSTOMED_SAM,
    missileSystem = "TK-3",
    mountDescriptors = constants.MOUNT_DESCRIPTORS.CUSTOMED_TK3,
  },
  ["1st Coy, 614th Bn, 793rd AFAD & Arty Bde"] = {
    name = "1st Coy, 614th Bn, 793rd AFAD & Arty Bde",
    state = constants.MISSILE_UNIT_POSTURE.STATIC,
    operationalArea = constants.OPERATIONAL_AREAS.UVY,
    weaponDBID = constants.WEAPONS.TK3,
    ammoThreshold = config.blue.ground.missileSystemTypes.sam.ammoThreshold,
    transloader = "Ammo Sec, 1st Coy, 614th Bn, 793rd AFAD & Arty Bde",
    dbid = constants.PLATFORMS.CUSTOMED_SAM,
    missileSystem = "TK-3",
    mountDescriptors = constants.MOUNT_DESCRIPTORS.CUSTOMED_TK3,
  },
  ["1st Coy, 631st Bn, 793rd AFAD & Arty Bde"] = {
    name = "1st Coy, 631st Bn, 793rd AFAD & Arty Bde",
    state = constants.MISSILE_UNIT_POSTURE.STATIC,
    operationalArea = constants.OPERATIONAL_AREAS.QPF,
    weaponDBID = { constants.WEAPONS.MIM104F_PAC3, constants.WEAPONS.MIM104F_PAC2 },
    ammoThreshold = config.blue.ground.missileSystemTypes.sam.ammoThreshold,
    transloader = "Ammo Sec, 1st Coy, 631st Bn, 793rd AFAD & Arty Bde",
    dbid = constants.PLATFORMS.PAC3,
    missileSystem = "PAC-3",
  },
  ["1st Coy, 632nd Bn, 794th AFAD & Arty Bde"] = {
    name = "1st Coy, 632nd Bn, 794th AFAD & Arty Bde",
    state = constants.MISSILE_UNIT_POSTURE.STATIC,
    operationalArea = constants.OPERATIONAL_AREAS.NUJ,
    weaponDBID = { constants.WEAPONS.MIM104F_PAC3, constants.WEAPONS.MIM104F_PAC2 },
    ammoThreshold = config.blue.ground.missileSystemTypes.sam.ammoThreshold,
    transloader = "Ammo Sec, 1st Coy, 632nd Bn, 794th AFAD & Arty Bde",
    dbid = constants.PLATFORMS.PAC3,
    missileSystem = "PAC-3",
  },
  ["1st Coy, 633rd Bn, 795th AFAD & Arty Bde"] = {
    name = "1st Coy, 633rd Bn, 795th AFAD & Arty Bde",
    state = constants.MISSILE_UNIT_POSTURE.STATIC,
    operationalArea = constants.OPERATIONAL_AREAS.QTZ,
    weaponDBID = { constants.WEAPONS.MIM104F_PAC3, constants.WEAPONS.MIM104F_PAC2 },
    ammoThreshold = config.blue.ground.missileSystemTypes.sam.ammoThreshold,
    transloader = "Ammo Sec, 1st Coy, 633rd Bn, 795th AFAD & Arty Bde",
    dbid = constants.PLATFORMS.PAC3,
    missileSystem = "PAC-3",
  },
  ["2nd Coy, 613rd Bn, 792nd AFAD & Arty Bde"] = {
    name = "2nd Coy, 613rd Bn, 792nd AFAD & Arty Bde",
    state = constants.MISSILE_UNIT_POSTURE.STATIC,
    operationalArea = constants.OPERATIONAL_AREAS.MAK,
    weaponDBID = constants.WEAPONS.TK3,
    ammoThreshold = config.blue.ground.missileSystemTypes.sam.ammoThreshold,
    transloader = "Ammo Sec, 2nd Coy, 613rd Bn, 792nd AFAD & Arty Bde",
    dbid = constants.PLATFORMS.CUSTOMED_SAM,
    missileSystem = "TK-3",
    mountDescriptors = constants.MOUNT_DESCRIPTORS.CUSTOMED_TK3,
  },
  ["2nd Coy, 614th Bn, 793rd AFAD & Arty Bde"] = {
    name = "2nd Coy, 614th Bn, 793rd AFAD & Arty Bde",
    state = constants.MISSILE_UNIT_POSTURE.STATIC,
    operationalArea = constants.OPERATIONAL_AREAS.FMK,
    weaponDBID = constants.WEAPONS.TK3,
    ammoThreshold = config.blue.ground.missileSystemTypes.sam.ammoThreshold,
    transloader = "Ammo Sec, 2nd Coy, 614th Bn, 793rd AFAD & Arty Bde",
    dbid = constants.PLATFORMS.CUSTOMED_SAM,
    missileSystem = "TK-3",
    mountDescriptors = constants.MOUNT_DESCRIPTORS.CUSTOMED_TK3,
  },
  ["2nd Coy, 631st Bn, 793rd AFAD & Arty Bde"] = {
    name = "2nd Coy, 631st Bn, 793rd AFAD & Arty Bde",
    state = constants.MISSILE_UNIT_POSTURE.STATIC,
    operationalArea = constants.OPERATIONAL_AREAS.XDY,
    weaponDBID = { constants.WEAPONS.MIM104F_PAC3, constants.WEAPONS.MIM104F_PAC2 },
    ammoThreshold = config.blue.ground.missileSystemTypes.sam.ammoThreshold,
    transloader = "Ammo Sec, 2nd Coy, 631st Bn, 793rd AFAD & Arty Bde",
    dbid = constants.PLATFORMS.PAC3,
    missileSystem = "PAC-3",
  },
  ["2nd Coy, 632nd Bn, 794th AFAD & Arty Bde"] = {
    name = "2nd Coy, 632nd Bn, 794th AFAD & Arty Bde",
    state = constants.MISSILE_UNIT_POSTURE.STATIC,
    operationalArea = constants.OPERATIONAL_AREAS.DJA,
    weaponDBID = { constants.WEAPONS.MIM104F_PAC3, constants.WEAPONS.MIM104F_PAC2 },
    ammoThreshold = config.blue.ground.missileSystemTypes.sam.ammoThreshold,
    transloader = "Ammo Sec, 2nd Coy, 632nd Bn, 794th AFAD & Arty Bde",
    dbid = constants.PLATFORMS.PAC3,
    missileSystem = "PAC-3",
  },
  ["2nd Coy, 633rd Bn, 795th AFAD & Arty Bde"] = {
    name = "2nd Coy, 633rd Bn, 795th AFAD & Arty Bde",
    state = constants.MISSILE_UNIT_POSTURE.STATIC,
    operationalArea = constants.OPERATIONAL_AREAS.GRV,
    weaponDBID = { constants.WEAPONS.MIM104F_PAC3, constants.WEAPONS.MIM104F_PAC2 },
    ammoThreshold = config.blue.ground.missileSystemTypes.sam.ammoThreshold,
    transloader = "Ammo Sec, 2nd Coy, 633rd Bn, 795th AFAD & Arty Bde",
    dbid = constants.PLATFORMS.PAC3,
    missileSystem = "PAC-3",
  },
  ["3rd Coy, 613rd Bn, 792nd AFAD & Arty Bde"] = {
    name = "3rd Coy, 613rd Bn, 792nd AFAD & Arty Bde",
    state = constants.MISSILE_UNIT_POSTURE.STATIC,
    operationalArea = constants.OPERATIONAL_AREAS.PXV,
    weaponDBID = constants.WEAPONS.TK3,
    ammoThreshold = config.blue.ground.missileSystemTypes.sam.ammoThreshold,
    transloader = "Ammo Sec, 3rd Coy, 613rd Bn, 792nd AFAD & Arty Bde",
    dbid = constants.PLATFORMS.CUSTOMED_SAM,
    missileSystem = "TK-3",
    mountDescriptors = constants.MOUNT_DESCRIPTORS.CUSTOMED_TK3,
  },
  ["3rd Coy, 614th Bn, 793rd AFAD & Arty Bde"] = {
    name = "3rd Coy, 614th Bn, 793rd AFAD & Arty Bde",
    state = constants.MISSILE_UNIT_POSTURE.STATIC,
    operationalArea = constants.OPERATIONAL_AREAS.IDW,
    weaponDBID = constants.WEAPONS.TK3,
    ammoThreshold = config.blue.ground.missileSystemTypes.sam.ammoThreshold,
    transloader = "Ammo Sec, 3rd Coy, 614th Bn, 793rd AFAD & Arty Bde",
    dbid = constants.PLATFORMS.CUSTOMED_SAM,
    missileSystem = "TK-3",
    mountDescriptors = constants.MOUNT_DESCRIPTORS.CUSTOMED_TK3,
  },
  ["3rd Coy, 631st Bn, 793rd AFAD & Arty Bde"] = {
    name = "3rd Coy, 631st Bn, 793rd AFAD & Arty Bde",
    state = constants.MISSILE_UNIT_POSTURE.STATIC,
    operationalArea = constants.OPERATIONAL_AREAS.CSC,
    weaponDBID = { constants.WEAPONS.MIM104F_PAC3, constants.WEAPONS.MIM104F_PAC2 },
    ammoThreshold = config.blue.ground.missileSystemTypes.sam.ammoThreshold,
    transloader = "Ammo Sec, 3rd Coy, 631st Bn, 793rd AFAD & Arty Bde",
    dbid = constants.PLATFORMS.PAC3,
    missileSystem = "PAC-3",
  },
  ["3rd Coy, 632nd Bn, 794th AFAD & Arty Bde"] = {
    name = "3rd Coy, 632nd Bn, 794th AFAD & Arty Bde",
    state = constants.MISSILE_UNIT_POSTURE.STATIC,
    operationalArea = constants.OPERATIONAL_AREAS.RHM,
    weaponDBID = { constants.WEAPONS.MIM104F_PAC3, constants.WEAPONS.MIM104F_PAC2 },
    ammoThreshold = config.blue.ground.missileSystemTypes.sam.ammoThreshold,
    transloader = "Ammo Sec, 3rd Coy, 632nd Bn, 794th AFAD & Arty Bde",
    dbid = constants.PLATFORMS.PAC3,
    missileSystem = "PAC-3",
  },
  ["3rd Coy, 633rd Bn, 795th AFAD & Arty Bde"] = {
    name = "3rd Coy, 633rd Bn, 795th AFAD & Arty Bde",
    state = constants.MISSILE_UNIT_POSTURE.STATIC,
    operationalArea = constants.OPERATIONAL_AREAS.UYO,
    weaponDBID = { constants.WEAPONS.MIM104F_PAC3, constants.WEAPONS.MIM104F_PAC2 },
    ammoThreshold = config.blue.ground.missileSystemTypes.sam.ammoThreshold,
    transloader = "Ammo Sec, 3rd Coy, 633rd Bn, 795th AFAD & Arty Bde",
    dbid = constants.PLATFORMS.PAC3,
    missileSystem = "PAC-3",
  },
}


-- ============================================================================
-- IADS (Taiwan)
-- ============================================================================

config.blue.iads = {}
config.blue.iads.rocc = {
  {
    name = "ROCC/North",
    areas = { constants.AREAS.THEATER_OF_OPS_3RD, },
  },
  {
    name = "ROCC/East",
    areas = { constants.AREAS.THEATER_OF_OPS_2ND, constants.AREAS.THEATER_OF_OPS_5TH, },
  },
  {
    name = "ROCC/South",
    areas = { constants.AREAS.THEATER_OF_OPS_4TH, },
  },
}
config.blue.iads.taaoc = {
  {
    name = "TAAOC/3rd OPAREA",
    areas = { constants.AREAS.THEATER_OF_OPS_3RD, },
  },
  {
    name = "TAAOC/5th OPAREA",
    areas = { constants.AREAS.THEATER_OF_OPS_5TH, },
  },
  {
    name = "TAAOC/4th OPAREA",
    areas = { constants.AREAS.THEATER_OF_OPS_4TH, },
  },
  {
    name = "TAAOC/2nd OPAREA",
    areas = { constants.AREAS.THEATER_OF_OPS_2ND, },
  },
}


-- ============================================================================
-- Aircraft Settings (Taiwan)
-- ============================================================================

config.blue.air = {}
config.blue.air.weaponCount = 8
config.blue.air.deployedACs = {
  {
    name = "Ching Chuang Kang AB",
    baseGUID = constants.BASES.CHING_CHUANG_KANG_AB,
    embarkedUnits = {
      {
        side = constants.SIDES.BLUE,
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
      { name = "Wan Chien", loadoutId = constants.LOADOUTS.IDF_WAN_CHIEN, num = config.blue.air.weaponCount }, --Wan Chien X 2
    }
  },
  {
    name = "Chiayi AB",
    baseGUID = constants.BASES.CHIAYI_AB,
    embarkedUnits = {
      {
        side = constants.SIDES.BLUE,
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
      { name = "AMRAAM",  loadoutId = constants.LOADOUTS.F16V_BLK20_AMRAAM,  num = config.blue.air.weaponCount }, --AMRAAM X 4
      { name = "Harpoon", loadoutId = constants.LOADOUTS.F16V_BLK20_HARPOON, num = config.blue.air.weaponCount }, --Harpoon X 2
      { name = "GBU",     loadoutId = constants.LOADOUTS.F16V_BLK20_GBU,     num = config.blue.air.weaponCount }, --GBU X 2
    }
  },
  {
    name = "Tainan AB",
    baseGUID = constants.BASES.TAINAN_AB,
    embarkedUnits = {
      {
        side = constants.SIDES.BLUE,
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
      { name = "Wan Chien", loadoutId = constants.LOADOUTS.IDF_WAN_CHIEN, num = config.blue.air.weaponCount }, --Wan Chien X 2
    }
  },
  {
    name = "Magong AB",
    baseGUID = constants.BASES.MAGONG_AB,
    embarkedUnits = {
      {
        side = constants.SIDES.BLUE,
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
      { name = "Wan Chien", loadoutId = constants.LOADOUTS.IDF_WAN_CHIEN, num = config.blue.air.weaponCount }, --Wan Chien X 2
    }
  },
  {
    name = "Guiren AAB",
    baseGUID = constants.BASES.GUIREN_AAB,
    embarkedUnits = {
      {
        side = constants.SIDES.BLUE,
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
      { name = "Hellfire", loadoutId = constants.LOADOUTS.AH1W_HELLFIRE, num = config.blue.air.weaponCount }, --Hellfire X 8
    }
  },
  {
    name = "Pingtung North AB",
    baseGUID = constants.BASES.PINGTUNG_NORTH_AB,
    embarkedUnits = {
      {
        side = constants.SIDES.BLUE,
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
        side = constants.SIDES.BLUE,
        type = "Air",
        dbid = constants.PLATFORMS.P3C,
        platformName = "P-3C",
        name = "6th Mixed Wing",
        loadouts = {
          { name = "ASW Patrol", loadoutId = constants.LOADOUTS.P3C_ASW, num = 3, missionName = "ASW/E" },
        }
      },
      {
        side = constants.SIDES.BLUE,
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
        side = constants.SIDES.BLUE,
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
      { name = "SLAM-ER", loadoutId = constants.LOADOUTS.F16V_BLK70_SLAM_ER, num = config.blue.air.weaponCount }, --SLAMER X 2
      { name = "JDAM",    loadoutId = constants.LOADOUTS.F16V_BLK70_JDAM,    num = config.blue.air.weaponCount }, --JDAM X 4
      { name = "HARM",    loadoutId = constants.LOADOUTS.F16V_BLK70_HARM,    num = config.blue.air.weaponCount }, --HARM X 2
      { name = "JSOW",    loadoutId = constants.LOADOUTS.F16V_BLK70_JSOW,    num = config.blue.air.weaponCount }, --JSOW X 4
    }
  },
  {
    name = "Jiashan AB",
    baseGUID = constants.BASES.JIASHAN_AB,
    embarkedUnits = {
      {
        side = constants.SIDES.BLUE,
        type = "Air",
        dbid = constants.PLATFORMS.MQ9B,
        platformName = "MQ-9B",
        name = "5th Tactical Mixed Wing",
        loadouts = {
          { name = "Reconnaissance", loadoutId = constants.LOADOUTS.MQ9B_RECON, num = 3, missionName = "AEW/S" },
        }
      },
      {
        side = constants.SIDES.BLUE,
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
      { name = "AMRAAM",  loadoutId = constants.LOADOUTS.F16V_BLK20_AMRAAM,  num = config.blue.air.weaponCount }, --AMRAAM X 4
      { name = "Harpoon", loadoutId = constants.LOADOUTS.F16V_BLK20_HARPOON, num = config.blue.air.weaponCount }, --Harpoon X 2
      { name = "GBU",     loadoutId = constants.LOADOUTS.F16V_BLK20_GBU,     num = config.blue.air.weaponCount }, --GBU X 2
    }
  },
  {
    name = "Hsinchu AB",
    baseGUID = constants.BASES.HSINCHU_AB,
    embarkedUnits = {
      {
        side = constants.SIDES.BLUE,
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
      { name = "MICA AAM", loadoutId = constants.LOADOUTS.MIRAGE2000_MICA, num = config.blue.air.weaponCount }, --MICA X 4

    }
  },
  {
    name = "Longtan AAB",
    baseGUID = constants.BASES.LONGTAN_AAB,
    embarkedUnits = {
      {
        side = constants.SIDES.BLUE,
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
      { name = "Hellfire", loadoutId = constants.LOADOUTS.AH64E_HELLFIRE, num = config.blue.air.weaponCount }, --Hellfire X 16
    }
  },
  {
    name = "Taoyuan International Airport",
    baseGUID = constants.BASES.TAOYUAN_AIRPORT,
    embarkedUnits = {
      {
        side = constants.SIDES.BLUE,
        type = "Air",
        dbid = constants.PLATFORMS.CHUNG_SHYANG_II,
        platformName = "Chung Shyang II",
        name = "1st Maritime Tactical Recon Sqn",
        loadouts = {
          { name = "Reconnaissance", loadoutId = constants.LOADOUTS.CHUNG_SHYANG_II_RECON, num = 3 },
        }
      }
    }
  },
  {
    name = "Rende Emergency Highway Strip",
    baseGUID = constants.BASES.RENDE_STRIP,
    loadouts = {
      { name = "Wan Chien", loadoutId = constants.LOADOUTS.IDF_WAN_CHIEN, num = config.blue.air.weaponCount }, --Wan Chien X 2
    }
  },
  {
    name = "Madou Emergency Highway Strip",
    baseGUID = constants.BASES.MADOU_STRIP,
    loadouts = {
      { name = "AMRAAM",  loadoutId = constants.LOADOUTS.F16V_BLK20_AMRAAM,  num = config.blue.air.weaponCount }, --AMRAAM X 4
      { name = "Harpoon", loadoutId = constants.LOADOUTS.F16V_BLK20_HARPOON, num = config.blue.air.weaponCount }, --Harpoon X 2
      { name = "GBU",     loadoutId = constants.LOADOUTS.F16V_BLK20_GBU,     num = config.blue.air.weaponCount }, --GBU X 2
    }
  },
  {
    name = "Minxiong Emergency Highway Strip",
    baseGUID = constants.BASES.MINXIONG_STRIP,
    loadouts = {
      { name = "AMRAAM",  loadoutId = constants.LOADOUTS.F16V_BLK20_AMRAAM,  num = config.blue.air.weaponCount }, --AMRAAM X 4
      { name = "Harpoon", loadoutId = constants.LOADOUTS.F16V_BLK20_HARPOON, num = config.blue.air.weaponCount }, --Harpoon X 2
      { name = "GBU",     loadoutId = constants.LOADOUTS.F16V_BLK20_GBU,     num = config.blue.air.weaponCount }, --GBU X 2
    }
  },
  {
    name = "Tainan Field Airdrome",
    baseGUID = constants.BASES.TAINAN_FIELD_AIRDROME,
    loadouts = {
      { name = "Hellfire", loadoutId = constants.LOADOUTS.AH1W_HELLFIRE, num = config.blue.air.weaponCount }, --Hellfire X 8
    }
  },
  {
    name = "Hsinchu Field Airdrome ",
    baseGUID = constants.BASES.HSINCHU_FIELD_AIRDROME,
    loadouts = {
      { name = "Hellfire", loadoutId = constants.LOADOUTS.AH64E_HELLFIRE, num = config.blue.air.weaponCount }, --Hellfire X 16
    }
  },
}

config.blue.surface = {}
config.blue.surface.sags = {
  ["264th Sqn"] = {
    groupName = "264th Sqn",
    unitMap = {
      kidd = {
        dbid = constants.PLATFORMS.KIDD,
        embarkedUnits = {
          {
            side = constants.SIDES.BLUE,
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
            side = constants.SIDES.BLUE,
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
      pos = { latitude = "N 24.28.47", longitude = "E 122.25.49", },
      heading = 0
    },
  },
}
config.blue.surface.deployedShips = {
  {
    name = "Port of Keelung",
    baseGUID = constants.BASES.PORT_OF_KEELUNG,
    embarkedUnits = {
      {
        side = constants.SIDES.BLUE,
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

config.ally.sigint = {}
config.ally.sigint.maxCount = config.red.sigint.maxCount
config.ally.sigint.maxRangeNm = config.red.sigint.maxRangeNm
-- Detection parameters (shared with China)
config.ally.sigint.detectionThreshold = config.red.sigint.detectionThreshold
config.ally.sigint.maxDetectionRangeNm = config.red.sigint.maxDetectionRangeNm
-- Detection formula constants (shared with China)
config.ally.sigint.formulaConstants = config.red.sigint.formulaConstants
-- Default display configuration (shared with China)
config.ally.sigint.defaultDisplay = config.red.sigint.defaultDisplay
-- Area and performance parameters (shared with China)
config.ally.sigint.minPolygonPoints = config.red.sigint.minPolygonPoints
config.ally.sigint.detectionSkipProbability = config.red.sigint.detectionSkipProbability


-- ============================================================================
-- Scoring Configuration
-- ============================================================================

config.score.destroyingAircraftOnTheGround = 5
config.score.destroyingAmmo = 100
config.score.destroyingAmmoTruck = 20
config.score.lhd = 10
config.score.lst = 10
config.score.ddg = 10
config.score.cv = 100
config.score.ifv = -5
config.score.infantry = -3
config.score.sub = 15
config.score.uav = 20
config.score.tel = 20
config.score.weaponDBID = constants.WEAPONS.MK48_TORPEDO
config.score.attackBeforeTheHHour = -1000
config.score.undergroundShelterIsDestroyed = -200
config.score.destroyingCivilianFacility = -100

return config
