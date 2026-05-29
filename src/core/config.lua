local constants = require("src.core.constants")
---@diagnostic disable: missing-fields
---@class SBJ__Config
local config = {}
config.isDevMode = true
config.isSaved = true
config.difficulty = "normal"

-- Logging configuration
config.logging = {
  modules = {
    [constants.TAGS.GROUND] = { verbose = true },
    [constants.TAGS.AIR] = { verbose = true },
    [constants.TAGS.SECOND_WAVE_UNLOADING] = { verbose = true },
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
config.c = {}
config.t = {}
config.u = {}
config.s = {}

config.targetScanning = {
  distanceThreshold = 1.5, -- nautical miles
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


-- ============================================================================
-- Setup Start Time
-- ============================================================================

config.c.triggers = {
  amphibiousOps = { startTime = "2027-06-09 02:40:00" },
  -- amphibiousOps = { startTime = "2027-06-09 2:15:00" },
  launchLACM = { startTime = "2027-06-09 06:00:00" },
  launchSLCM = { startTime = "2027-06-09 06:30:00" },
  -- launchSLCM = { startTime = "2027-06-09 01:00:00" },
}


-- ============================================================================
-- SIGINT (China)
-- ============================================================================

config.c.sigint = {}
config.c.sigint.maxCount = 6
-- config.c.sigint.maxCount = 1
config.c.sigint.maxRange = 2.5

-- Detection parameters
config.c.sigint.detectionThreshold = 60
config.c.sigint.maxDetectionRange = { 300, 340 }

-- Detection formula constants
config.c.sigint.formulaConstants = {
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
config.c.sigint.defaultDisplay = {
  r = 255,
  g = 255,
  b = 255,
  lifeTime = 4,
  fontSize = 16
}

-- Area and performance parameters
config.c.sigint.minPolygonPoints = 3
config.c.sigint.detectionSkipProbability = 0.3


-- ============================================================================
-- IADS (China)
-- ============================================================================

config.c.iads = {}
config.c.iads.ratio = { C2 = 1.5, }
config.c.iads.c2FacilityDBIDs = { 319, 318, 115, 113 }
config.c.iads.randomRadius = 10
config.c.iads.c2Deployments = {
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
config.c.commsJamming.mode = "omnidirectional"
config.c.commsJamming.aircraftDefaults = {
  commsLevel = 40,
  commsBase = 40,
  commsThreshold = 30,
  outOfComms = 0,
}


-- ============================================================================
-- GPS Jamming (China)
-- ============================================================================

config.c.gnssJamming = {}
config.c.gnssJamming.randomRadius = 20 -- random radius
config.c.gnssJamming.radius = 14
config.c.gnssJamming.gnssGuidedWeapons = {
  { dbid = constants.WEAPONS.JDAM,       jammingResistance = 50 },
  { dbid = constants.WEAPONS.WAN_CHIEN,  jammingResistance = 50 },
  { dbid = constants.WEAPONS.HARPOON_II, jammingResistance = 50 },
  { dbid = constants.WEAPONS.JSOW,       jammingResistance = 50 },
  { dbid = constants.WEAPONS.SLAMER,     jammingResistance = 50 },
}
config.c.gnssJamming.jammers = {
  ["1st Bn, 1st ECM Bde"] = {
    zoneName = "JAMMING ZONE/1",
    name = "1st Bn, 1st ECM Bde",
    point = { latitude = "N 25.28.17", longitude = "E 119.35.17" },
    randomRadius = config.c.gnssJamming.randomRadius,
    radius = config.c.gnssJamming.radius
  },
  ["2nd Bn, 1st ECM Bde"] = {
    zoneName = "JAMMING ZONE/2",
    name = "2nd Bn, 1st ECM Bde",
    point = { latitude = "N 24.43.49", longitude = "E 118.29.41" },
    randomRadius = config.c.gnssJamming.randomRadius,
    radius = config.c.gnssJamming.radius
  },
}


-- ============================================================================
-- MLRS (China)
-- ============================================================================

config.c.ground = {}
config.c.ground.mlrs = {}
config.c.ground.mlrs.wpnDefault = 96
config.c.ground.mlrs.ammoThreshold = 55
config.c.ground.mlrs.contactAge = 30 * 60
config.c.ground.mlrs.reloadTime = 30 * 60
config.c.ground.mlrs.stowTime = 5 * 60
config.c.ground.mlrs.ammunitions = {
  ["Ammo Revetment, 1st Bn, 1st Rockets Arty Bde"] = {
    guid = "",
    name = "Ammo Revetment, 1st Bn, 1st Rockets Arty Bde",
    wpnCurrent = config.c.ground.mlrs.wpnDefault * 2,
    wpnDefault = config.c.ground.mlrs.wpnDefault * 2,
  },
  ["Ammo Revetment, 6th Bn, 73rd Arty Bde"] = {
    guid = "",
    name = "Ammo Revetment, 6th Bn, 73rd Arty Bde",
    wpnCurrent = config.c.ground.mlrs.wpnDefault * 2,
    wpnDefault = config.c.ground.mlrs.wpnDefault * 2,
  },
}
config.c.ground.mlrs.resupplyUnits = {
  ["Ammo Sec, 1st Bn, 1st Rockets Arty Bde"] = {
    guid = "",
    name = "Ammo Sec, 1st Bn, 1st Rockets Arty Bde",
    wpnCurrent = config.c.ground.mlrs.wpnDefault,
    wpnDefault = config.c.ground.mlrs.wpnDefault,
    unitCount = 2,
    operationalArea = constants.OPERATIONAL_AREAS.JUK,
    state = constants.MISSILE_SYSTEM_STATE.STATIC,
    ammunition = "Ammo Revetment, 1st Bn, 1st Rockets Arty Bde",
    firingUnit = "1st Bn, 1st Rockets Arty Bde"
  },
  ["Ammo Sec, 6th Bn, 73rd Arty Bde"] = {
    guid = "",
    name = "Ammo Sec, 6th Bn, 73rd Arty Bde",
    wpnCurrent = config.c.ground.mlrs.wpnDefault,
    wpnDefault = config.c.ground.mlrs.wpnDefault,
    unitCount = 2,
    operationalArea = constants.OPERATIONAL_AREAS.YMC,
    state = constants.MISSILE_SYSTEM_STATE.STATIC,
    ammunition = "Ammo Revetment, 6th Bn, 73rd Arty Bde",
    firingUnit = "6th Bn, 73rd Arty Bde"
  },
}
config.c.ground.mlrs.firingUnits = {
  ["1st Bn, 1st Rockets Arty Bde"] = {
    guid = "",
    name = "1st Bn, 1st Rockets Arty Bde",
    msg = "Radio source, Bty",
    state = constants.MISSILE_SYSTEM_STATE.HIDE,
    operationalArea = constants.OPERATIONAL_AREAS.JUK,
    weaponDBID = constants.WEAPONS.FD280,
    ammoThreshold = config.c.ground.mlrs.ammoThreshold,
    resupplyUnit = "Ammo Sec, 1st Bn, 1st Rockets Arty Bde",
    dbid = constants.PLATFORMS.PHL16,
  },
  ["6th Bn, 73rd Arty Bde"] = {
    guid = "",
    name = "6th Bn, 73rd Arty Bde",
    msg = "Radio source, Bty",
    state = constants.MISSILE_SYSTEM_STATE.HIDE,
    operationalArea = constants.OPERATIONAL_AREAS.YMC,
    weaponDBID = constants.WEAPONS.FD280,
    ammoThreshold = config.c.ground.mlrs.ammoThreshold,
    resupplyUnit = "Ammo Sec, 6th Bn, 73rd Arty Bde",
    dbid = constants.PLATFORMS.PHL16,
  },
}

-- ============================================================================
-- GLCM (China)
-- ============================================================================

config.c.ground.glcm = {}
config.c.ground.glcm.wpnDefault = 120
config.c.ground.glcm.ammoThreshold = 55
config.c.ground.glcm.contactAge = 30 * 60
config.c.ground.glcm.reloadTime = 45 * 60
config.c.ground.glcm.stowTime = 5 * 60
config.c.ground.glcm.ammunitions = {
  ["Ammo Revetment, 635th Bde, PLARF"] = {
    guid = "",
    name = "Ammo Revetment, 635th Bde, PLARF",
    wpnCurrent = config.c.ground.glcm.wpnDefault / 2,
    wpnDefault = config.c.ground.glcm.wpnDefault / 2,
  },
}
config.c.ground.glcm.resupplyUnits = {
  ["Ammo Sec, 635th Bde, PLARF"] = {
    guid = "",
    name = "Ammo Sec, 635th Bde, PLARF",
    wpnCurrent = config.c.ground.glcm.wpnDefault / 2,
    wpnDefault = config.c.ground.glcm.wpnDefault / 2,
    unitCount = 5,
    operationalArea = constants.OPERATIONAL_AREAS.TXI,
    state = constants.MISSILE_SYSTEM_STATE.STATIC,
    ammunition = "Ammo Revetment, 635th Bde, PLARF",
    firingUnit = "635th Bde, PLARF"
  },
}
config.c.ground.glcm.firingUnits = {
  ["635th Bde, PLARF"] = {
    guid = "",
    name = "635th Bde, PLARF",
    msg = "Radio source, Bty",
    state = constants.MISSILE_SYSTEM_STATE.HIDE,
    operationalArea = constants.OPERATIONAL_AREAS.TXI,
    weaponDBID = constants.WEAPONS.CJ10A,
    ammoThreshold = config.c.ground.glcm.ammoThreshold,
    resupplyUnit = "Ammo Sec, 635th Bde, PLARF",
    dbid = constants.PLATFORMS.CUSTOMED_SSM,
    mountDescriptors = constants.MOUNT_DESCRIPTORS.CH_SSC_9,
  },
}

-- ============================================================================
-- SRBM (China)
-- ============================================================================

config.c.ground.srbm = {}
config.c.ground.srbm.wpnDefault = 36
config.c.ground.srbm.ammoThreshold = 55
config.c.ground.srbm.contactAge = 30 * 60
config.c.ground.srbm.reloadTime = 5 * 60
config.c.ground.srbm.stowTime = 5 * 60
config.c.ground.srbm.ammunitions = {
  ["Ammo Revetment, 613rd Bde, PLARF"] = {
    guid = "",
    name = "Ammo Revetment, 613rd Bde, PLARF",
    wpnCurrent = config.c.ground.srbm.wpnDefault * 2,
    wpnDefault = config.c.ground.srbm.wpnDefault * 2,
  },
  ["Ammo Revetment, 614th Bde, PLARF"] = {
    guid = "",
    name = "Ammo Revetment, 614th Bde, PLARF",
    wpnCurrent = config.c.ground.srbm.wpnDefault * 2,
    wpnDefault = config.c.ground.srbm.wpnDefault * 2,
  },
  ["Ammo Revetment, 615th Bde, PLARF"] = {
    guid = "",
    name = "Ammo Revetment, 615th Bde, PLARF",
    wpnCurrent = config.c.ground.srbm.wpnDefault * 2,
    wpnDefault = config.c.ground.srbm.wpnDefault * 2,
  },
  ["Ammo Revetment, 616th Bde, PLARF"] = {
    guid = "",
    name = "Ammo Revetment, 616th Bde, PLARF",
    wpnCurrent = config.c.ground.srbm.wpnDefault * 2,
    wpnDefault = config.c.ground.srbm.wpnDefault * 2,
  },
  ["Ammo Revetment, 617th Bde, PLARF"] = {
    guid = "",
    name = "Ammo Revetment, 617th Bde, PLARF",
    wpnCurrent = config.c.ground.srbm.wpnDefault * 2,
    wpnDefault = config.c.ground.srbm.wpnDefault * 2,
  },
  ["Ammo Revetment, 636th Bde, PLARF"] = {
    guid = "",
    name = "Ammo Revetment, 636th Bde, PLARF",
    wpnCurrent = config.c.ground.srbm.wpnDefault * 2,
    wpnDefault = config.c.ground.srbm.wpnDefault * 2,
  },
}
config.c.ground.srbm.resupplyUnits = {
  ["Ammo Sec, 613rd Bde, PLARF"] = {
    guid = "",
    name = "Ammo Sec, 613rd Bde, PLARF",
    wpnCurrent = config.c.ground.srbm.wpnDefault,
    wpnDefault = config.c.ground.srbm.wpnDefault,
    unitCount = 6,
    operationalArea = constants.OPERATIONAL_AREAS.XZL,
    state = constants.MISSILE_SYSTEM_STATE.STATIC,
    ammunition = "Ammo Revetment, 613rd Bde, PLARF",
    firingUnit = "613rd Bde, PLARF"
  },
  ["Ammo Sec, 614th Bde, PLARF"] = {
    guid = "",
    name = "Ammo Sec, 614th Bde, PLARF",
    wpnCurrent = config.c.ground.srbm.wpnDefault,
    wpnDefault = config.c.ground.srbm.wpnDefault,
    unitCount = 6,
    operationalArea = constants.OPERATIONAL_AREAS.GSU,
    state = constants.MISSILE_SYSTEM_STATE.STATIC,
    ammunition = "Ammo Revetment, 614th Bde, PLARF",
    firingUnit = "614th Bde, PLARF"
  },
  ["Ammo Sec, 615th Bde, PLARF"] = {
    guid = "",
    name = "Ammo Sec, 615th Bde, PLARF",
    wpnCurrent = config.c.ground.srbm.wpnDefault,
    wpnDefault = config.c.ground.srbm.wpnDefault,
    unitCount = 6,
    operationalArea = constants.OPERATIONAL_AREAS.HUZ,
    state = constants.MISSILE_SYSTEM_STATE.STATIC,
    ammunition = "Ammo Revetment, 615th Bde, PLARF",
    firingUnit = "615th Bde, PLARF"
  },
  ["Ammo Sec, 616th Bde, PLARF"] = {
    guid = "",
    name = "Ammo Sec, 616th Bde, PLARF",
    wpnCurrent = config.c.ground.srbm.wpnDefault,
    wpnDefault = config.c.ground.srbm.wpnDefault,
    unitCount = 6,
    operationalArea = constants.OPERATIONAL_AREAS.IDP,
    state = constants.MISSILE_SYSTEM_STATE.STATIC,
    ammunition = "Ammo Revetment, 616th Bde, PLARF",
    firingUnit = "616th Bde, PLARF"
  },
  ["Ammo Sec, 617th Bde, PLARF"] = {
    guid = "",
    name = "Ammo Sec, 617th Bde, PLARF",
    wpnCurrent = config.c.ground.srbm.wpnDefault,
    wpnDefault = config.c.ground.srbm.wpnDefault,
    unitCount = 9,
    operationalArea = constants.OPERATIONAL_AREAS.GMJ,
    state = constants.MISSILE_SYSTEM_STATE.STATIC,
    ammunition = "Ammo Revetment, 617th Bde, PLARF",
    firingUnit = "617th Bde, PLARF"
  },
  ["Ammo Sec, 636th Bde, PLARF"] = {
    guid = "",
    name = "Ammo Sec, 636th Bde, PLARF",
    wpnCurrent = config.c.ground.srbm.wpnDefault,
    wpnDefault = config.c.ground.srbm.wpnDefault,
    unitCount = 9,
    operationalArea = constants.OPERATIONAL_AREAS.HMJ,
    state = constants.MISSILE_SYSTEM_STATE.STATIC,
    ammunition = "Ammo Revetment, 636th Bde, PLARF",
    firingUnit = "636th Bde, PLARF"
  },
}
config.c.ground.srbm.firingUnits = {
  ["613rd Bde, PLARF"] = {
    guid = "",
    name = "613rd Bde, PLARF",
    msg = "Radio source, Bty",
    state = constants.MISSILE_SYSTEM_STATE.HIDE,
    operationalArea = constants.OPERATIONAL_AREAS.XZL,
    weaponDBID = constants.WEAPONS.DF15B,
    ammoThreshold = config.c.ground.srbm.ammoThreshold,
    resupplyUnit = "Ammo Sec, 613rd Bde, PLARF",
    dbid = constants.PLATFORMS.CUSTOMED_SSM,
    mountDescriptors = constants.MOUNT_DESCRIPTORS.CSS6_MOD3,
  },
  ["614th Bde, PLARF"] = {
    guid = "",
    name = "614th Bde, PLARF",
    msg = "Radio source, Bty",
    state = constants.MISSILE_SYSTEM_STATE.HIDE,
    operationalArea = constants.OPERATIONAL_AREAS.GSU,
    weaponDBID = constants.WEAPONS.DF11A,
    ammoThreshold = config.c.ground.srbm.ammoThreshold,
    resupplyUnit = "Ammo Sec, 614th Bde, PLARF",
    dbid = constants.PLATFORMS.CUSTOMED_SSM,
    mountDescriptors = constants.MOUNT_DESCRIPTORS.CSS7_MOD2,
  },
  ["615th Bde, PLARF"] = {
    guid = "",
    name = "615th Bde, PLARF",
    msg = "Radio source, Bty",
    state = constants.MISSILE_SYSTEM_STATE.HIDE,
    operationalArea = constants.OPERATIONAL_AREAS.HUZ,
    weaponDBID = constants.WEAPONS.DF11A,
    ammoThreshold = config.c.ground.srbm.ammoThreshold,
    resupplyUnit = "Ammo Sec, 615th Bde, PLARF",
    dbid = constants.PLATFORMS.CUSTOMED_SSM,
    mountDescriptors = constants.MOUNT_DESCRIPTORS.CSS7_MOD2,
  },
  ["616th Bde, PLARF"] = {
    guid = "",
    name = "616th Bde, PLARF",
    msg = "Radio source, Bty",
    state = constants.MISSILE_SYSTEM_STATE.HIDE,
    operationalArea = constants.OPERATIONAL_AREAS.IDP,
    weaponDBID = constants.WEAPONS.DF15C,
    ammoThreshold = config.c.ground.srbm.ammoThreshold,
    resupplyUnit = "Ammo Sec, 616th Bde, PLARF",
    dbid = constants.PLATFORMS.CUSTOMED_SSM,
    mountDescriptors = constants.MOUNT_DESCRIPTORS.CSS6_MOD2,
  },
  ["617th Bde, PLARF"] = {
    guid = "",
    name = "617th Bde, PLARF",
    msg = "Radio source, Bty",
    state = constants.MISSILE_SYSTEM_STATE.HIDE,
    operationalArea = constants.OPERATIONAL_AREAS.GMJ,
    weaponDBID = constants.WEAPONS.DF16A,
    ammoThreshold = config.c.ground.srbm.ammoThreshold,
    resupplyUnit = "Ammo Sec, 617th Bde, PLARF",
    dbid = constants.PLATFORMS.CUSTOMED_SSM,
    mountDescriptors = constants.MOUNT_DESCRIPTORS.CSS11_MOD1,
  },
  ["636th Bde, PLARF"] = {
    guid = "",
    name = "636th Bde, PLARF",
    msg = "Radio source, Bty",
    state = constants.MISSILE_SYSTEM_STATE.HIDE,
    operationalArea = constants.OPERATIONAL_AREAS.HMJ,
    weaponDBID = constants.WEAPONS.DF16A,
    ammoThreshold = config.c.ground.srbm.ammoThreshold,
    resupplyUnit = "Ammo Sec, 636th Bde, PLARF",
    dbid = constants.PLATFORMS.CUSTOMED_SSM,
    mountDescriptors = constants.MOUNT_DESCRIPTORS.CSS11_MOD1,
  },
}

-- ============================================================================
-- MRBM (China)
-- ============================================================================

config.c.ground.mrbm = {}
config.c.ground.mrbm.wpnDefault = 24
config.c.ground.mrbm.ammoThreshold = 55
config.c.ground.mrbm.contactAge = 30 * 60
config.c.ground.mrbm.reloadTime = 5 * 60
config.c.ground.mrbm.stowTime = 5 * 60
config.c.ground.mrbm.ammunitions = {
  ["Ammo Revetment, 624th Bde, PLARF"] = {
    guid = "",
    name = "Ammo Revetment, 624th Bde, PLARF",
    wpnCurrent = config.c.ground.mrbm.wpnDefault * 2,
    wpnDefault = config.c.ground.mrbm.wpnDefault * 2,
  },
}
config.c.ground.mrbm.resupplyUnits = {
  ["Ammo Sec, 624th Bde, PLARF"] = {
    guid = "",
    name = "Ammo Sec, 624th Bde, PLARF",
    wpnCurrent = config.c.ground.mrbm.wpnDefault,
    wpnDefault = config.c.ground.mrbm.wpnDefault,
    unitCount = 6,
    operationalArea = constants.OPERATIONAL_AREAS.ZWQ,
    state = constants.MISSILE_SYSTEM_STATE.STATIC,
    ammunition = "Ammo Revetment, 624th Bde, PLARF",
    firingUnit = "624th Bde, PLARF"
  },
}
config.c.ground.mrbm.firingUnits = {
  ["624th Bde, PLARF"] = {
    guid = "",
    name = "624th Bde, PLARF",
    msg = "Radio source, Bty",
    state = constants.MISSILE_SYSTEM_STATE.HIDE,
    operationalArea = constants.OPERATIONAL_AREAS.ZWQ,
    weaponDBID = constants.WEAPONS.DF21D,
    ammoThreshold = config.c.ground.mrbm.ammoThreshold,
    resupplyUnit = "Ammo Sec, 624th Bde, PLARF",
    dbid = constants.PLATFORMS.CUSTOMED_SSM,
    mountDescriptors = constants.MOUNT_DESCRIPTORS.CSS5_MOD5,
  },
}

-- ============================================================================
-- ASCM (China)
-- ============================================================================

config.c.ground.ascm = {}
config.c.ground.ascm.wpnDefault = 12
config.c.ground.ascm.ammoThreshold = 55
config.c.ground.ascm.contactAge = 30 * 60
config.c.ground.ascm.reloadTime = 5 * 60
config.c.ground.ascm.stowTime = 5 * 60
config.c.ground.ascm.ammunitions = {
  ["Ammo Revetment, 1st Pili Reg"] = {
    guid = "",
    name = "Ammo Revetment, 1st Pili Reg",
    wpnCurrent = config.c.ground.ascm.wpnDefault * 2,
    wpnDefault = config.c.ground.ascm.wpnDefault * 2,
  },
}
config.c.ground.ascm.resupplyUnits = {
  ["Ammo Sec, 1st Pili Reg"] = {
    guid = "",
    name = "Ammo Sec, 1st Pili Reg",
    wpnCurrent = config.c.ground.ascm.wpnDefault,
    wpnDefault = config.c.ground.ascm.wpnDefault,
    unitCount = 1,
    operationalArea = constants.OPERATIONAL_AREAS.RCU,
    state = constants.MISSILE_SYSTEM_STATE.STATIC,
    ammunition = "Ammo Revetment, 1st Pili Reg",
    firingUnit = "1st Pili Reg"
  },
}
config.c.ground.ascm.firingUnits = {
  ["1st Pili Reg"] = {
    guid = "",
    name = "1st Pili Reg",
    msg = "Radio source, Bty",
    state = constants.MISSILE_SYSTEM_STATE.HIDE,
    operationalArea = constants.OPERATIONAL_AREAS.RCU,
    weaponDBID = constants.WEAPONS.YJ12,
    ammoThreshold = config.c.ground.ascm.ammoThreshold,
    resupplyUnit = "Ammo Sec, 1st Pili Reg",
    dbid = constants.PLATFORMS.CUSTOMED_SSM,
    mountDescriptors = constants.MOUNT_DESCRIPTORS.YJ12,
  },
}

-- ============================================================================
-- SAM (China)
-- ============================================================================

config.c.ground.sam = {}
config.c.ground.sam.wpnDefault = 16
config.c.ground.sam.ammoThreshold = 55
config.c.ground.sam.contactAge = 15 * 60
config.c.ground.sam.reloadTime = 5 * 60
config.c.ground.sam.stowTime = 5 * 60
config.c.ground.sam.ammunitions = {
  ["Ammo Revetment, 94695 Unit, PLAAF"] = {
    guid = "",
    name = "Ammo Revetment, 94695 Unit, PLAAF",
    wpnCurrent = config.c.ground.sam.wpnDefault * 2,
    wpnDefault = config.c.ground.sam.wpnDefault * 2,
  },
  ["Ammo Revetment, 94759 Unit, PLAAF"] = {
    guid = "",
    name = "Ammo Revetment, 94759 Unit, PLAAF",
    wpnCurrent = config.c.ground.sam.wpnDefault * 2,
    wpnDefault = config.c.ground.sam.wpnDefault * 2,
  },
  ["Ammo Revetment, 94777 Unit, PLAAF"] = {
    guid = "",
    name = "Ammo Revetment, 94777 Unit, PLAAF",
    wpnCurrent = config.c.ground.sam.wpnDefault * 2,
    wpnDefault = config.c.ground.sam.wpnDefault * 2,
  },
  ["Ammo Revetment, 94908 Unit, PLAAF"] = {
    guid = "",
    name = "Ammo Revetment, 94908 Unit, PLAAF",
    wpnCurrent = config.c.ground.sam.wpnDefault * 2,
    wpnDefault = config.c.ground.sam.wpnDefault * 2,
  },
  ["Ammo Revetment, 94967 Unit, PLAAF"] = {
    guid = "",
    name = "Ammo Revetment, 94967 Unit, PLAAF",
    wpnCurrent = config.c.ground.sam.wpnDefault * 2,
    wpnDefault = config.c.ground.sam.wpnDefault * 2,
  },
  ["Ammo Revetment, 95324 Unit, PLAAF"] = {
    guid = "",
    name = "Ammo Revetment, 95324 Unit, PLAAF",
    wpnCurrent = config.c.ground.sam.wpnDefault * 2,
    wpnDefault = config.c.ground.sam.wpnDefault * 2,
  },
}
config.c.ground.sam.resupplyUnits = {
  ["Ammo Sec, 94695 Unit, PLAAF"] = {
    guid = "",
    name = "Ammo Sec, 94695 Unit, PLAAF",
    wpnCurrent = config.c.ground.sam.wpnDefault,
    wpnDefault = config.c.ground.sam.wpnDefault,
    unitCount = 1,
    operationalArea = constants.OPERATIONAL_AREAS.QXV,
    state = constants.MISSILE_SYSTEM_STATE.STATIC,
    ammunition = "Ammo Revetment, 94695 Unit, PLAAF",
    firingUnit = "94695 Unit, PLAAF"
  },
  ["Ammo Sec, 94759 Unit, PLAAF"] = {
    guid = "",
    name = "Ammo Sec, 94759 Unit, PLAAF",
    wpnCurrent = config.c.ground.sam.wpnDefault,
    wpnDefault = config.c.ground.sam.wpnDefault,
    unitCount = 1,
    operationalArea = constants.OPERATIONAL_AREAS.URF,
    state = constants.MISSILE_SYSTEM_STATE.STATIC,
    ammunition = "Ammo Revetment, 94759 Unit, PLAAF",
    firingUnit = "94759 Unit, PLAAF"
  },
  ["Ammo Sec, 94777 Unit, PLAAF"] = {
    guid = "",
    name = "Ammo Sec, 94777 Unit, PLAAF",
    wpnCurrent = config.c.ground.sam.wpnDefault,
    wpnDefault = config.c.ground.sam.wpnDefault,
    unitCount = 1,
    operationalArea = constants.OPERATIONAL_AREAS.EAJ,
    state = constants.MISSILE_SYSTEM_STATE.STATIC,
    ammunition = "Ammo Revetment, 94777 Unit, PLAAF",
    firingUnit = "94777 Unit, PLAAF"
  },
  ["Ammo Sec, 94908 Unit, PLAAF"] = {
    guid = "",
    name = "Ammo Sec, 94908 Unit, PLAAF",
    wpnCurrent = config.c.ground.sam.wpnDefault,
    wpnDefault = config.c.ground.sam.wpnDefault,
    unitCount = 1,
    operationalArea = constants.OPERATIONAL_AREAS.OJM,
    state = constants.MISSILE_SYSTEM_STATE.STATIC,
    ammunition = "Ammo Revetment, 94908 Unit, PLAAF",
    firingUnit = "94908 Unit, PLAAF"
  },
  ["Ammo Sec, 94967 Unit, PLAAF"] = {
    guid = "",
    name = "Ammo Sec, 94967 Unit, PLAAF",
    wpnCurrent = config.c.ground.sam.wpnDefault,
    wpnDefault = config.c.ground.sam.wpnDefault,
    unitCount = 1,
    operationalArea = constants.OPERATIONAL_AREAS.LPU,
    state = constants.MISSILE_SYSTEM_STATE.STATIC,
    ammunition = "Ammo Revetment, 94967 Unit, PLAAF",
    firingUnit = "94967 Unit, PLAAF"
  },
  ["Ammo Sec, 95324 Unit, PLAAF"] = {
    guid = "",
    name = "Ammo Sec, 95324 Unit, PLAAF",
    wpnCurrent = config.c.ground.sam.wpnDefault,
    wpnDefault = config.c.ground.sam.wpnDefault,
    unitCount = 1,
    operationalArea = constants.OPERATIONAL_AREAS.KRO,
    state = constants.MISSILE_SYSTEM_STATE.STATIC,
    ammunition = "Ammo Revetment, 95324 Unit, PLAAF",
    firingUnit = "95324 Unit, PLAAF"
  },
}
config.c.ground.sam.firingUnits = {
  ["94695 Unit, PLAAF"] = {
    guid = "",
    name = "94695 Unit, PLAAF",
    msg = "Radio source, Bty",
    state = constants.MISSILE_SYSTEM_STATE.STATIC,
    operationalArea = constants.OPERATIONAL_AREAS.QXV,
    weaponDBID = { constants.WEAPONS.SA20, constants.WEAPONS.SA16 },
    ammoThreshold = config.c.ground.sam.ammoThreshold,
    resupplyUnit = "Ammo Sec, 94695 Unit, PLAAF",
    dbid = constants.PLATFORMS.S300,
  },
  ["94759 Unit, PLAAF"] = {
    guid = "",
    name = "94759 Unit, PLAAF",
    msg = "Radio source, Bty",
    state = constants.MISSILE_SYSTEM_STATE.STATIC,
    operationalArea = constants.OPERATIONAL_AREAS.URF,
    weaponDBID = { constants.WEAPONS.SA20, constants.WEAPONS.SA16 },
    ammoThreshold = config.c.ground.sam.ammoThreshold,
    resupplyUnit = "Ammo Sec, 94759 Unit, PLAAF",
    dbid = constants.PLATFORMS.S300,
  },
  ["94777 Unit, PLAAF"] = {
    guid = "",
    name = "94777 Unit, PLAAF",
    msg = "Radio source, Bty",
    state = constants.MISSILE_SYSTEM_STATE.STATIC,
    operationalArea = constants.OPERATIONAL_AREAS.EAJ,
    weaponDBID = { constants.WEAPONS.SA20, constants.WEAPONS.SA16 },
    ammoThreshold = config.c.ground.sam.ammoThreshold,
    resupplyUnit = "Ammo Sec, 94777 Unit, PLAAF",
    dbid = constants.PLATFORMS.S300,
  },
  ["94908 Unit, PLAAF"] = {
    guid = "",
    name = "94908 Unit, PLAAF",
    msg = "Radio source, Bty",
    state = constants.MISSILE_SYSTEM_STATE.STATIC,
    operationalArea = constants.OPERATIONAL_AREAS.OJM,
    weaponDBID = { constants.WEAPONS.SA20, constants.WEAPONS.SA16 },
    ammoThreshold = config.c.ground.sam.ammoThreshold,
    resupplyUnit = "Ammo Sec, 94908 Unit, PLAAF",
    dbid = constants.PLATFORMS.S300,
  },
  ["94967 Unit, PLAAF"] = {
    guid = "",
    name = "94967 Unit, PLAAF",
    msg = "Radio source, Bty",
    state = constants.MISSILE_SYSTEM_STATE.STATIC,
    operationalArea = constants.OPERATIONAL_AREAS.LPU,
    weaponDBID = { constants.WEAPONS.SA20, constants.WEAPONS.SA16 },
    ammoThreshold = config.c.ground.sam.ammoThreshold,
    resupplyUnit = "Ammo Sec, 94967 Unit, PLAAF",
    dbid = constants.PLATFORMS.S300,
  },
  ["95324 Unit, PLAAF"] = {
    guid = "",
    name = "95324 Unit, PLAAF",
    msg = "Radio source, Bty",
    state = constants.MISSILE_SYSTEM_STATE.STATIC,
    operationalArea = constants.OPERATIONAL_AREAS.KRO,
    weaponDBID = { constants.WEAPONS.SA20, constants.WEAPONS.SA16 },
    ammoThreshold = config.c.ground.sam.ammoThreshold,
    resupplyUnit = "Ammo Sec, 95324 Unit, PLAAF",
    dbid = constants.PLATFORMS.S300,
  },
}

-- ============================================================================
-- Reconnaissance (China)
-- ============================================================================

config.c.recon = {}
config.c.recon.observationWindowSec = 30 * 60
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
    [constants.PLATFORMS.BZK005] = {
      { name = "STRIKE/C2/N/1", type = "ground", }
    },
    [constants.PLATFORMS.GJ11] = {
      { name = "CAS/N/1",       type = "air", },
      { name = "STRIKE/C2/N/1", type = "ground", },
    },
    [constants.PLATFORMS.H6N] = {
      { name = "ANTISHIP/E/1",            type = "ground" },
      { name = "ANTISHIP/N/1",            type = "ground" },
      { name = "ASUW/N/1",                type = "air" },
      { name = "STRIKE/AB/E/1",           type = "air" },
      { name = "STRIKE/AB/W/1",           type = "air" },
      { name = "STRIKE/INFRASTRUCTURE/1", type = "ground" },
    },
  },
  satellite = {
    EOS = {
      { name = "STRIKE/AB/W/AAR/3",       type = "air" },
      { name = "STRIKE/AB/E/1",           type = "air" },
      { name = "STRIKE/HELIPAD/1",        type = "ground" },
      { name = "STRIKE/INFRASTRUCTURE/1", type = "ground" },
    }
  },
  SIGINT = {
    ELINT = {
      { name = "STRIKE/C2/N/1", type = "ground" },
      { name = "STRIKE/C2/C/1", type = "ground" }
    }
  }
}
config.c.recon.frontlineRedirect = {
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
    { fromPrefix = "STRIKE/AB/W/", toPrefix = "STRIKE/AB/W/AAR/", type = "air" },
  },
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
    platformKey = "EOS",
    endTime = "2027-06-09 01:00:00",
    -- endTime = "2027-06-09 04:40:00",
  },
  {
    type = "SIGINT",
    platformKey = "ELINT",
    endTime = "2027-06-09 01:30:00"
  },
  {
    type = "satellite",
    platformKey = "EOS",
    -- endTime = "2027-06-09 01:00:00",
    endTime = "2027-06-09 05:44:00",
  },
  {
    type = "satellite",
    platformKey = "EOS",
    -- endTime = "2027-06-09 01:30:00",
    endTime = "2027-06-09 08:04:00",
  },
  {
    type = "satellite",
    platformKey = "EOS",
    endTime = "2027-06-09 11:25:00",
  },
}
config.c.recon.isTesting = true


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
        side = constants.SIDES.ENEMY,
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
        side = constants.SIDES.ENEMY,
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
        side = constants.SIDES.ENEMY,
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
      {
        side = constants.SIDES.ENEMY,
        type = "Air",
        dbid = constants.PLATFORMS.SU30,
        platformName = "Su-30",
        name = "804th Air Bde",
        loadouts = {
          { name = "KAB-1500 Strike", loadoutId = constants.LOADOUTS.SU30_KAB1500, num = 12 },
        }
      },
      {
        side = constants.SIDES.ENEMY,
        type = "Air",
        dbid = constants.PLATFORMS.J16D,
        platformName = "J-16D",
        name = "40th Air Bde",
        loadouts = {
          { name = "Electronic Warfare", loadoutId = constants.LOADOUTS.J16D_OECM, num = 4 },
        }
      },
      {
        side = constants.SIDES.ENEMY,
        type = "Air",
        dbid = constants.PLATFORMS.IL76,
        platformName = "Il-76",
        name = "39th Air Reg",
        loadouts = {
          { name = "Transport", loadoutId = constants.LOADOUTS.IL76_TRANSPORT, num = 3 },
        }
      },
      {
        side = constants.SIDES.ENEMY,
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
        side = constants.SIDES.ENEMY,
        type = "Air",
        dbid = constants.PLATFORMS.SU30,
        platformName = "Su-30",
        name = "804th Air Bde",
        loadouts = {
          { name = "YJ-91 ARM", loadoutId = constants.LOADOUTS.SU30_YJ91, num = 24 },
        }
      },
      {
        side = constants.SIDES.ENEMY,
        type = "Air",
        dbid = constants.PLATFORMS.J16,
        platformName = "J-16",
        name = "40th Air Bde",
        loadouts = {
          { name = "PL-15 AAM", loadoutId = constants.LOADOUTS.J16_PL15, num = 12, missionName = "CAP/W/2" },
        }
      },
    },
    loadouts = {
      { name = "YJ-91 ARM",       loadoutId = constants.LOADOUTS.SU30_YJ91,    num = 24 }, --YJ-91 X 2
      { name = "PL-15 AAM",       loadoutId = constants.LOADOUTS.J16_PL15,     num = 12 },
      { name = "KAB-1500 Strike", loadoutId = constants.LOADOUTS.SU30_KAB1500, num = 12 }, --KAB-1500 X 2
    }
  },
  {
    name = "Huian AAB",
    baseGUID = constants.BASES.HUIAN_AAB,
    embarkedUnits = {
      {
        side = constants.SIDES.ENEMY,
        type = "Air",
        dbid = constants.PLATFORMS.J16,
        platformName = "J-16",
        name = "40th Air Bde",
        loadouts = {
          { name = "AKD-88 Strike", loadoutId = constants.LOADOUTS.J16_AKD88, num = 12 },
        }
      },
      {
        side = constants.SIDES.ENEMY,
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
        side = constants.SIDES.ENEMY,
        type = "Air",
        dbid = constants.PLATFORMS.BZK005,
        platformName = "BZK-005",
        name = "62nd Det, PLARF UAV Reg",
        loadouts = {
          { name = "Reconnaissance", loadoutId = constants.LOADOUTS.BZK005_RECON, num = 6 },
        }
      },
      {
        side = constants.SIDES.ENEMY,
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
      { name = "YJ-91 ARM",       loadoutId = constants.LOADOUTS.SU30_YJ91,    num = 8 }, --YJ-91 X 2
      { name = "KAB-1500 Strike", loadoutId = constants.LOADOUTS.SU30_KAB1500, num = 8 }, --KAB-1500 X 2
    }
  },
  {
    name = "Xingning AB (PLAAF)",
    baseGUID = constants.BASES.XINGNING_AB,
    embarkedUnits = {
      {
        side = constants.SIDES.ENEMY,
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
        side = constants.SIDES.ENEMY,
        type = "Air",
        dbid = constants.PLATFORMS.SU30,
        platformName = "Su-30",
        name = "804th Air Bde",
        loadouts = {
          { name = "YJ-91 ARM", loadoutId = constants.LOADOUTS.SU30_YJ91, num = 8 },
        }
      },
      {
        side = constants.SIDES.ENEMY,
        type = "Air",
        dbid = constants.PLATFORMS.J16,
        platformName = "J-16",
        name = "40th Air Bde",
        loadouts = {
          { name = "YJ-83 Anti-Ship", loadoutId = constants.LOADOUTS.J16_YJ83, num = 8 },
        }
      },
      {
        side = constants.SIDES.ENEMY,
        type = "Air",
        dbid = constants.PLATFORMS.KJ500,
        platformName = "KJ-500",
        name = "75th Air Reg",
        loadouts = {
          { name = "AEW", loadoutId = constants.LOADOUTS.KJ500_AEW, num = 3, missionName = "AEW/N" },
        }
      },
      {
        side = constants.SIDES.ENEMY,
        type = "Air",
        dbid = constants.PLATFORMS.HY6U_BADGER,
        platformName = "HY-6U Badger",
        name = "23rd Air Reg",
        loadouts = {
          { name = "Aerial Refueling", loadoutId = constants.LOADOUTS.HY6U_AAR, num = 8, },
        }
      },
      {
        side = constants.SIDES.ENEMY,
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
        side = constants.SIDES.ENEMY,
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
        side = constants.SIDES.ENEMY,
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
        side = constants.SIDES.ENEMY,
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
        side = constants.SIDES.ENEMY,
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
      { name = "YJ-91 ARM",       loadoutId = constants.LOADOUTS.SU30_YJ91,    num = 12 }, --YJ-91 X 4
      { name = "KAB-1500 Strike", loadoutId = constants.LOADOUTS.SU30_KAB1500, num = 36 }, --KAB-1500 X 2
    }
  },
  -- {
  --   name = "Rugao AB (PLAAF)",
  --   baseGUID = constants.BASES.RUGAO_AB,
  --   embarkedUnits = {
  --     {
  --       side = constants.SIDES.ENEMY,
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
        side = constants.SIDES.ENEMY,
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
  --       side = constants.SIDES.ENEMY,
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
        side = constants.SIDES.ENEMY,
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
      { name = "YJ-91 ARM",     loadoutId = constants.LOADOUTS.J16_YJ91,  num = 12 }, --YJ-91 X 2
    }
  },
  {
    name = "Leiyang AB (PLAAF)",
    baseGUID = constants.BASES.LEIYANG_AB,
    embarkedUnits = {
      {
        side = constants.SIDES.ENEMY,
        type = "Air",
        dbid = constants.PLATFORMS.HY6U_BADGER,
        platformName = "HY-6U Badger",
        name = "23rd Air Reg",
        loadouts = {
          { name = "Aerial Refueling", loadoutId = constants.LOADOUTS.HY6U_AAR, num = 8, },
        }
      }
    },
  },
  {
    name = "Jiujiang Lushan AB (PLAAF)",
    baseGUID = constants.BASES.LUSHAN_AB,
    embarkedUnits = {
      {
        side = constants.SIDES.ENEMY,
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
}


-- ============================================================================
-- Amphibious Operations (China)
-- ============================================================================

config.c.amphibOps = {}
config.c.amphibOps.isTesting = true
config.c.amphibOps.periodOfTime = 5 * 60
config.c.amphibOps.fireSupportHoldThreshold = 50 -- SRBM total-ammo % below which recon-driven SRBM strikes are held until all zones arrive at staging
config.c.amphibOps.cargoList = {
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
config.c.amphibOps.cargoListForTransfer = {
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
config.c.amphibOps.missionStartime = {
  transportHelicopter = { 42 * 60, 72 * 60, 92 * 60, 112 * 60 },
  attackHelicopter = { 40 * 60, },
  boat = { 41 * 60, 61 * 60, },
  reconUAV = { 0 }
}
config.c.amphibOps.formationSettings = {
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
  acvSpeed = 8,
  acvTransitDistance = 5,
  acvHorizontalDistance = 0.05,
}
config.c.amphibOps.operations = {
  {
    name = "Taoyuan",
    sagNames = { "SAG 173", "SAG 155" },
    names = { "Air Assault Bn", "Combined Arms Bn", "5th Landing Ship Div" },
    from = {
      areas = { {
        startingPoints = { type075 = constants.AREAS.STARTING_POINT_075_TAOYUAN },
        heading = config.c.amphibOps.formationSettings.heading.north,
        shipCounts = {
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
      } },
      stagingArea = constants.AREAS.AREA_OF_OPS_D,
    },
    to = {
      areas = { {
        startingPoints = {
          type075 = constants.AREAS.DESTINATION_075_TAOYUAN,
          type071 = constants.AREAS.DESTINATION_071_TAOYUAN,
        },
        heading = config.c.amphibOps.formationSettings.heading.west,
        shipCounts = {
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
      }, }
    },
    airLandingZone = constants.AREAS.AIRLANDING_TAOYUAN,
    contactThreshold = 3
  },
  {
    name = "Sishu",
    sagNames = { "SAG 154", "SAG 175" },
    names = { "Air Assault Bn", "Combined Arms Bn", "5th Landing Ship Div" },
    from = {
      areas = { {
        startingPoints = { type075 = constants.AREAS.STARTING_POINT_075_SISHU },
        heading = config.c.amphibOps.formationSettings.heading.sishu,
        shipCounts = {
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
      } },
      stagingArea = constants.AREAS.AREA_OF_OPS_F,
    },
    to = {
      areas = { {
        startingPoints = {
          type075 = constants.AREAS.DESTINATION_075_SISHU,
          type071 = constants.AREAS.DESTINATION_071_SISHU,
        },
        heading = config.c.amphibOps.formationSettings.heading.sishu,
        shipCounts = {
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
      }, }
    },
    airLandingZone = constants.AREAS.AIRLANDING_TAOYUAN,
    contactThreshold = 3
  },
  {
    name = "Penghu",
    sagNames = { "SAG 167" },
    names = { "Air Assault Bn", "Combined Arms Bn", "5th Landing Ship Div" },
    from = {
      areas = { {
        startingPoints = { type075 = constants.AREAS.STARTING_POINT_075_PENGHU },
        heading = config.c.amphibOps.formationSettings.heading.penghu,
        shipCounts = {
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
      } },
      stagingArea = constants.AREAS.AREA_OF_OPS_E,
    },
    to = {
      areas = { {
        startingPoints = {
          type075 = constants.AREAS.DESTINATION_075_PENGHU,
          type071 = constants.AREAS.DESTINATION_071_PENGHU,
        },
        heading = config.c.amphibOps.formationSettings.heading.penghu,
        shipCounts = {
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
      }, }
    },
    airLandingZone = constants.AREAS.AIRLANDING_TAOYUAN,
    contactThreshold = 3
  },
}
config.c.amphibOps.operationalZones = {
  {
    name = "Taoyuan",
    arrivalThreshold = 15,
    baseGUID = constants.BASES.PINGTAN_PORT,
    anchorageArea = constants.AREAS.ANCH_AREA_TAOYUAN,
    lstAnchorageArea = constants.AREAS.LST_ANCH_AREA_TAOYUAN,
    casArea = constants.AREAS.CAS_E,
    offloadArea = constants.AREAS.OFFLOAD_AREA_TAOYUAN,
    boat = {
      dbid = constants.PLATFORMS.TYPE_726A,
      missions = {
        {
          name = "LANDING/TAO/1/1",
          loadoutId = 0,
          unitCount = 1,
          startTime = config.c.amphibOps.missionStartime.boat[1],
        },
        {
          name = "LANDING/TAO/1/2",
          loadoutId = 0,
          unitCount = 3,
          startTime = config.c.amphibOps.missionStartime.boat[2],
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
              config.c.amphibOps.cargoListForTransfer.assultLandingGroup,
              config.c.amphibOps.cargoListForTransfer.deepAssaultGroup1,
              config.c.amphibOps.cargoListForTransfer.deepAssaultGroup2,
            }
          },
        },
        type071 = {
          {
            loadoutId = 0,
            cargoItems = {
              config.c.amphibOps.cargoListForTransfer.assultLandingGroup,
              config.c.amphibOps.cargoListForTransfer.deepAssaultGroup1,
              config.c.amphibOps.cargoListForTransfer.deepAssaultGroup2,
              config.c.amphibOps.cargoListForTransfer.deepAssaultGroup3,
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
          startTime = config.c.amphibOps.missionStartime.transportHelicopter[1],
        },
        {
          name = "AIRLANDING/TAO/1/2",
          loadoutId = constants.LOADOUTS.Z18_TRANSPORT_1,
          unitCount = 3,
          startTime = config.c.amphibOps.missionStartime.transportHelicopter[2],
        },
        {
          name = "AIRLANDING/TAO/2/1",
          loadoutId = constants.LOADOUTS.Z18_TRANSPORT_2,
          unitCount = 3,
          startTime = config.c.amphibOps.missionStartime.transportHelicopter[3],
        },
        {
          name = "AIRLANDING/TAO/2/2",
          loadoutId = constants.LOADOUTS.Z18_TRANSPORT_2,
          unitCount = 3,
          startTime = config.c.amphibOps.missionStartime.transportHelicopter[4],
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
            cargoItems = { config.c.amphibOps.cargoListForTransfer.airAssaultGroup1 }
          },
          {
            loadoutId = constants.LOADOUTS.Z18_TRANSPORT_2,
            cargoItems = { config.c.amphibOps.cargoListForTransfer.airAssaultGroup2 }
          },
        },
        type071 = {
          {
            loadoutId = constants.LOADOUTS.Z18_TRANSPORT_1,
            cargoItems = { config.c.amphibOps.cargoListForTransfer.airAssaultGroup1 }
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
          startTime = config.c.amphibOps.missionStartime.attackHelicopter[1],
        },
      }
    },
    lstSettings = {
      speed = config.c.amphibOps.formationSettings.shipSpeed,
      course = {
        bearing = config.c.amphibOps.formationSettings.heading.west.vertical,
        distance = config.c.amphibOps.formationSettings.transitDistance
      }
    },
    acv = {
      bearing = config.c.amphibOps.formationSettings.heading.west.horizontal,
      distance = config.c.amphibOps.formationSettings.acvHorizontalDistance,
      speed = config.c.amphibOps.formationSettings.acvSpeed,
      destination = config.c.amphibOps.formationSettings.heading.west.destination,
      area = constants.AREAS.AMPH_VEH_STAGING_AREA_TAOYUAN
    },
  },
  {
    name = "Sishu",
    arrivalThreshold = 10,
    baseGUID = constants.BASES.KWANG_CHOW_WAN_NB,
    anchorageArea = constants.AREAS.ANCH_AREA_SISHU,
    lstAnchorageArea = constants.AREAS.LST_ANCH_AREA_SISHU,
    casArea = constants.AREAS.CAS_S,
    offloadArea = constants.AREAS.OFFLOAD_AREA_SISHU,
    boat = {
      dbid = constants.PLATFORMS.TYPE_726A,
      missions = {
        {
          name = "LANDING/SISHU/1/1",
          loadoutId = 0,
          unitCount = 1,
          startTime = config.c.amphibOps.missionStartime.boat[1],
        },
        {
          name = "LANDING/SISHU/1/2",
          loadoutId = 0,
          unitCount = 3,
          startTime = config.c.amphibOps.missionStartime.boat[2],
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
              config.c.amphibOps.cargoListForTransfer.assultLandingGroup,
              config.c.amphibOps.cargoListForTransfer.deepAssaultGroup1,
              config.c.amphibOps.cargoListForTransfer.deepAssaultGroup2,
            }
          },
        },
        type071 = {
          {
            loadoutId = 0,
            cargoItems = {
              config.c.amphibOps.cargoListForTransfer.assultLandingGroup,
              config.c.amphibOps.cargoListForTransfer.deepAssaultGroup1,
              config.c.amphibOps.cargoListForTransfer.deepAssaultGroup2,
              config.c.amphibOps.cargoListForTransfer.deepAssaultGroup3
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
          startTime = config.c.amphibOps.missionStartime.transportHelicopter[1],
        },
        {
          name = "AIRLANDING/CHANGLONG/1/2",
          loadoutId = constants.LOADOUTS.Z18_TRANSPORT_1,
          unitCount = 3,
          startTime = config.c.amphibOps.missionStartime.transportHelicopter[2],
        },
        {
          name = "AIRLANDING/CHANGLONG/2/1",
          loadoutId = constants.LOADOUTS.Z18_TRANSPORT_2,
          unitCount = 3,
          startTime = config.c.amphibOps.missionStartime.transportHelicopter[3],
        },
        {
          name = "AIRLANDING/CHANGLONG/2/2",
          loadoutId = constants.LOADOUTS.Z18_TRANSPORT_2,
          unitCount = 3,
          startTime = config.c.amphibOps.missionStartime.transportHelicopter[4],
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
            cargoItems = { config.c.amphibOps.cargoListForTransfer.airAssaultGroup1 }
          },
          {
            loadoutId = constants.LOADOUTS.Z18_TRANSPORT_2,
            cargoItems = { config.c.amphibOps.cargoListForTransfer.airAssaultGroup2 }
          },
        },
        type071 = {
          {
            loadoutId = constants.LOADOUTS.Z18_TRANSPORT_1,
            cargoItems = { config.c.amphibOps.cargoListForTransfer.airAssaultGroup1 }
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
          startTime = config.c.amphibOps.missionStartime.attackHelicopter[1],
        },
      }
    },
    lstSettings = {
      speed = config.c.amphibOps.formationSettings.shipSpeed,
      course = {
        bearing = config.c.amphibOps.formationSettings.heading.sishu.vertical,
        distance = config.c.amphibOps.formationSettings.transitDistance
      }
    },
    acv = {
      bearing = config.c.amphibOps.formationSettings.heading.sishu.horizontal,
      distance = config.c.amphibOps.formationSettings.acvHorizontalDistance,
      speed = config.c.amphibOps.formationSettings.acvSpeed,
      destination = config.c.amphibOps.formationSettings.heading.sishu.destination,
      area = constants.AREAS.AMPH_VEH_STAGING_AREA_SHISHU
    }
  },
  {
    name = "Penghu",
    arrivalThreshold = 5,
    baseGUID = constants.BASES.KWANG_CHOW_WAN_NB,
    anchorageArea = constants.AREAS.ANCH_AREA_PENGHU,
    lstAnchorageArea = constants.AREAS.LST_ANCH_AREA_PENGHU,
    casArea = constants.AREAS.CAS_PENGHU,
    offloadArea = constants.AREAS.OFFLOAD_AREA_PENGHU,
    boat = {
      dbid = constants.PLATFORMS.TYPE_726A,
      missions = {
        {
          name = "LANDING/PENGHU/1/1",
          loadoutId = 0,
          unitCount = 1,
          startTime = config.c.amphibOps.missionStartime.boat[1],
        },
        {
          name = "LANDING/PENGHU/1/2",
          loadoutId = 0,
          unitCount = 3,
          startTime = config.c.amphibOps.missionStartime.boat[2],
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
              config.c.amphibOps.cargoListForTransfer.assultLandingGroup,
              config.c.amphibOps.cargoListForTransfer.deepAssaultGroup1,
              config.c.amphibOps.cargoListForTransfer.deepAssaultGroup2,
            }
          },
        },
        type071 = {
          {
            loadoutId = 0,
            cargoItems = {
              config.c.amphibOps.cargoListForTransfer.assultLandingGroup,
              config.c.amphibOps.cargoListForTransfer.deepAssaultGroup1,
              config.c.amphibOps.cargoListForTransfer.deepAssaultGroup2,
              config.c.amphibOps.cargoListForTransfer.deepAssaultGroup3
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
          startTime = config.c.amphibOps.missionStartime.transportHelicopter[1],
        },
        {
          name = "AIRLANDING/PENGHU/1/2",
          loadoutId = constants.LOADOUTS.Z18_TRANSPORT_1,
          unitCount = 3,
          startTime = config.c.amphibOps.missionStartime.transportHelicopter[2],
        },
        {
          name = "AIRLANDING/PENGHU/2/1",
          loadoutId = constants.LOADOUTS.Z18_TRANSPORT_2,
          unitCount = 3,
          startTime = config.c.amphibOps.missionStartime.transportHelicopter[3],
        },
        {
          name = "AIRLANDING/PENGHU/2/2",
          loadoutId = constants.LOADOUTS.Z18_TRANSPORT_2,
          unitCount = 3,
          startTime = config.c.amphibOps.missionStartime.transportHelicopter[4],
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
            cargoItems = { config.c.amphibOps.cargoListForTransfer.airAssaultGroup1 }
          },
          {
            loadoutId = constants.LOADOUTS.Z18_TRANSPORT_2,
            cargoItems = { config.c.amphibOps.cargoListForTransfer.airAssaultGroup2 }
          },
        },
        type071 = {
          {
            loadoutId = constants.LOADOUTS.Z18_TRANSPORT_1,
            cargoItems = { config.c.amphibOps.cargoListForTransfer.airAssaultGroup1 }
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
          startTime = config.c.amphibOps.missionStartime.attackHelicopter[1],
        },
      }
    },
    lstSettings = {
      speed = config.c.amphibOps.formationSettings.shipSpeed,
      course = {
        bearing = config.c.amphibOps.formationSettings.heading.penghu.vertical,
        distance = config.c.amphibOps.formationSettings.transitDistance
      }
    },
    acv = {
      bearing = config.c.amphibOps.formationSettings.heading.penghu.horizontal,
      distance = config.c.amphibOps.formationSettings.acvHorizontalDistance,
      speed = config.c.amphibOps.formationSettings.acvSpeed,
      destination = config.c.amphibOps.formationSettings.heading.penghu.destination,
      area = constants.AREAS.AMPH_VEH_STAGING_AREA_PENGHU
    }
  },
}
config.c.amphibOps.transportAircraft = {
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
        cargoItems = { config.c.amphibOps.cargoListForTransfer.airAssaultGroup3 }
      },
    }
  },
}
config.c.amphibOps.sag = {
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
      heading = config.c.amphibOps.formationSettings.heading.west.vertical,
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
      heading = config.c.amphibOps.formationSettings.heading.west.vertical,
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
      heading = config.c.amphibOps.formationSettings.heading.penghu.vertical,
    },
    to = {
      anchorageArea = {
        { latitude = "N 23.32.46", longitude = "E 119.16.11", desiredSpeed = 14, },
      },
      amphibiousVehicleStagingArea = {
        { latitude = "N 23.32.34", longitude = "E 119.29.14", desiredSpeed = 14, },
      },
      heading = config.c.amphibOps.formationSettings.heading.penghu.vertical,
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
      heading = config.c.amphibOps.formationSettings.heading.sishu.vertical,
    },
    to = {
      anchorageArea = {
        { latitude = "N 22.49.20", longitude = "E 119.55.57", desiredSpeed = 14, },
      },
      amphibiousVehicleStagingArea = {
        { latitude = "N 22.53.16", longitude = "E 120.07.39", desiredSpeed = 14, },
      },
      heading = config.c.amphibOps.formationSettings.heading.sishu.vertical,
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
      heading = config.c.amphibOps.formationSettings.heading.sishu.vertical,
    },
    to = {
      anchorageArea = {
        { latitude = "N 22.55.20", longitude = "E 119.52.25", desiredSpeed = 14, },
      },
      amphibiousVehicleStagingArea = {
        { latitude = "N 22.58.52", longitude = "E 120.05.48", desiredSpeed = 14, },
      },
      heading = config.c.amphibOps.formationSettings.heading.sishu.vertical,
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
          side = constants.SIDES.ENEMY,
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
          side = constants.SIDES.ENEMY,
          type = "Air",
          dbid = constants.PLATFORMS.Z18F_SEA_EAGLE,
          platformName = "Z-18F Sea Eagle",
          name = "10th Naval Air Bde",
          loadouts = {
            { loadoutId = constants.LOADOUTS.Z18F_CARRIER_ASW, num = 6, missionName = "ASW/CSG" },
          }
        },
        {
          side = constants.SIDES.ENEMY,
          type = "Air",
          dbid = constants.PLATFORMS.Z18J,
          platformName = "Z-18J",
          name = "10th Naval Air Bde",
          loadouts = {
            { loadoutId = constants.LOADOUTS.Z18J_AEW, num = 3, missionName = "AEW/CSG" },
          }
        },
        {
          side = constants.SIDES.ENEMY,
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
          side = constants.SIDES.ENEMY,
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
          side = constants.SIDES.ENEMY,
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
          side = constants.SIDES.ENEMY,
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

config.c.fireSupportTaskTemplates = {
  STRIKE_INFRASTRUCTURE_1 = {
    {
      name = "RADAR",
      missileSystem = "SRBM",
      firingUnits = {
        { name = "614th Bde, PLARF", weaponDBID = constants.WEAPONS.DF11A },
        { name = "613rd Bde, PLARF", weaponDBID = constants.WEAPONS.DF15B }
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
      missileSystem = "SRBM",
      firingUnits = {
        { name = "636th Bde, PLARF", weaponDBID = constants.WEAPONS.DF16A },
        { name = "617th Bde, PLARF", weaponDBID = constants.WEAPONS.DF16A }
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
      missileSystem = "SRBM",
      firingUnits = {
        { name = "615th Bde, PLARF", weaponDBID = constants.WEAPONS.DF11A }
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
      missileSystem = "SRBM",
      firingUnits = {
        { name = "616th Bde, PLARF", weaponDBID = constants.WEAPONS.DF15C }
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
      missileSystem = "SRBM",
      firingUnits = {
        { name = "614th Bde, PLARF", weaponDBID = constants.WEAPONS.DF11A },
        { name = "613rd Bde, PLARF", weaponDBID = constants.WEAPONS.DF15B }
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
      missileSystem = "SRBM",
      firingUnits = {
        { name = "636th Bde, PLARF", weaponDBID = constants.WEAPONS.DF16A },
        { name = "617th Bde, PLARF", weaponDBID = constants.WEAPONS.DF16A }
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
      missileSystem = "SRBM",
      firingUnits = {
        { name = "615th Bde, PLARF", weaponDBID = constants.WEAPONS.DF11A }
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
      missileSystem = "SRBM",
      firingUnits = {
        { name = "616th Bde, PLARF", weaponDBID = constants.WEAPONS.DF15C }
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
  ANTISHIP_E_1 = {
    {
      name = "ANTISHIP",
      missileSystem = "MRBM",
      firingUnits = {
        { name = "624th Bde, PLARF", weaponDBID = constants.WEAPONS.DF21D }
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
  ANTISHIP_N_1 = {
    {
      name = "ANTISHIP",
      missileSystem = "ASCM",
      firingUnits = {
        { name = "1st Pili Reg", weaponDBID = constants.WEAPONS.YJ12 }
      },
      target = {
        list = {},
        objs = {},
        areas = { constants.AREAS.AREA_OF_OPS_D },
        filterNames = { "findNavalTargets" },
        contactAge = config.c.ground.ascm.contactAge,
        minTargetCount = 1,
        ammoPerTarget = 2
      },
    }
  },
  STRIKE_C2_N_1 = {
    {
      name = "PINGTAN",
      missileSystem = "MLRS",
      firingUnits = {
        { name = "1st Bn, 1st Rockets Arty Bde", weaponDBID = constants.WEAPONS.FD280 }
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
  },
  STRIKE_C2_C_1 = {
    {
      name = "CHINCHEW",
      missileSystem = "MLRS",
      firingUnits = {
        { name = "6th Bn, 73rd Arty Bde", weaponDBID = constants.WEAPONS.FD280 }
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
      missileSystem = "GLCM",
      firingUnits = {
        { name = "635th Bde, PLARF", weaponDBID = constants.WEAPONS.CJ10A }
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

config.c.packageTemplates = {
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
          name = "SEAD/AB/C/1",
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
          name = "JAMMING/AB/C/1",
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
        filterNames = {},
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
        filterNames = {},
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
        filterNames = {},
        contactAge = 60 * 60,
        minTargetCount = 1
      },
    },
    {
      timeToReady = config.readytime,
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
            prosecutionZone = constants.AREAS.TARGET_AREA_CENTER_PROSECUTION,
            patrolZone = constants.AREAS.TARGET_AREA_CENTER_PATROL
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
          name = "JAMMING/AB/C/3",
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
      timeToReady = config.readytime,
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
            prosecutionZone = constants.AREAS.TARGET_AREA_NORTH_PROSECUTION,
            patrolZone = constants.AREAS.TARGET_AREA_NORTH_PATROL
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
          name = "JAMMING/AB/N/3",
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
          { baseName = "Hsinchu AB", subTypes = { "Ammo Bunker" } },
        },
        areas = { constants.AREAS.AREA_OF_OPS_NORTH },
        filterNames = {},
        contactAge = 60 * 60,
        minTargetCount = 1
      },
    },
  },
  STRIKE_AB_W_AAR_1 = {
    -- {
    --   timeToReady = config.readytime,
    --   striker = {
    --     baseGUID = constants.BASES.JIAXING_AB,
    --     weaponDBID = constants.WEAPONS.AKD88,
    --     unitDBID = constants.PLATFORMS.J16,
    --     unitCount = 12,
    --     loadoutID = constants.LOADOUTS.J16_AKD88,
    --     startTime = nil,
    --     missionCreationParams = {
    --       name = "STRIKE/AB/N/1",
    --       type = "strike",
    --       opts = {
    --         type = "land",
    --         -- TankerUsage = 1,
    --         -- TankerMissionList = { "AAR/E" },
    --         -- FuelQtyToStartLookingForTanker_airborne = 85,
    --         -- MaxReceiversInQueuePerTanker_airborne = 1,
    --         -- LaunchMissionWithoutTankersInPlace = true,
    --         -- TankerMaxDistance_airborne = 50
    --       }
    --     },
    --     emcon = "Radar=Passive;OECM=Active"
    --   },
    --   escort = {
    --     baseGUID = constants.BASES.WUHU_AB,
    --     weaponDBID = constants.WEAPONS.PL15,
    --     unitDBID = constants.PLATFORMS.J20,
    --     unitCount = 4,
    --     loadoutID = constants.LOADOUTS.J20_PL15,
    --     missionCreationParams = {
    --       name = "SWEEP/AB/N/1",
    --       type = "patrol",
    --       opts = {
    --         type = "aaw",
    --         OneThirdRule = false,
    --         FlightSize = 4,
    --         CheckOPAREA = false,
    --         CheckWWR = false,
    --         prosecutionZone = constants.AREAS.TARGET_AREA_NORTH_PROSECUTION,
    --         patrolZone = constants.AREAS.TARGET_AREA_NORTH_PATROL,
    --         TankerUsage = 1,
    --         TankerMissionList = { "AAR/E" },
    --         FuelQtyToStartLookingForTanker_airborne = 85,
    --         MaxReceiversInQueuePerTanker_airborne = 1,
    --         LaunchMissionWithoutTankersInPlace = true,
    --         TankerMaxDistance_airborne = 50
    --       }
    --     },
    --     emcon = "Radar=Passive;OECM=Active"
    --   },
    --   wildWeasel = {
    --     baseGUID = constants.BASES.TAIZHOU_AB,
    --     weaponDBID = constants.WEAPONS.YJ91_ARM,
    --     unitDBID = constants.PLATFORMS.SU30,
    --     unitCount = 4,
    --     loadoutID = constants.LOADOUTS.SU30_YJ91,
    --     missionCreationParams = {
    --       name = "SEAD/AB/N/1",
    --       type = "patrol",
    --       opts = {
    --         type = "sead",
    --         OneThirdRule = false,
    --         FlightSize = 4,
    --         CheckOPAREA = false,
    --         CheckWWR = false,
    --         prosecutionZone = constants.AREAS.TARGET_AREA_NORTH_PROSECUTION,
    --         patrolZone = constants.AREAS.TARGET_AREA_NORTH_PATROL,
    --         TankerUsage = 1,
    --         TankerMissionList = { "AAR/E" },
    --         FuelQtyToStartLookingForTanker_airborne = 85,
    --         MaxReceiversInQueuePerTanker_airborne = 1,
    --         LaunchMissionWithoutTankersInPlace = true,
    --         TankerMaxDistance_airborne = 50
    --       }
    --     },
    --     emcon = "Radar=Passive;OECM=Active"
    --   },
    --   jammer = {
    --     baseGUID = constants.BASES.XIAHGTANG_AB,
    --     unitDBID = constants.PLATFORMS.J16D,
    --     weaponDBID = 0,
    --     unitCount = 1,
    --     loadoutID = nil,
    --     missionCreationParams = {
    --       name = "JAMMING/AB/N/1",
    --       type = "support",
    --       opts = {
    --         zone = constants.AREAS.TARGET_AREA_NORTH_PATROL,
    --         TankerUsage = 1,
    --         TankerMissionList = { "AAR/E" },
    --         FuelQtyToStartLookingForTanker_airborne = 85,
    --         MaxReceiversInQueuePerTanker_airborne = 1,
    --         LaunchMissionWithoutTankersInPlace = true,
    --         TankerMaxDistance_airborne = 50
    --       }
    --     },
    --     emcon = "Radar=Passive;OECM=Active"
    --   },
    --   tanker = {
    --     baseGUID = constants.BASES.SHUIMEN_AAB,
    --     unitDBID = constants.PLATFORMS.HY6U_BADGER,
    --     weaponDBID = 0,
    --     unitCount = 8,
    --     loadoutID = nil,
    --     missionCreationParams = {
    --       name = "AAR/E",
    --       type = "support",
    --       opts = {
    --         OneThirdRule = false,
    --         FlightSize = 2,
    --         zone = constants.AREAS.AAR_PATROL_2
    --       }
    --     },
    --     emcon = "Radar=Passive;OECM=Passive"
    --   },
    --   reconUAV = nil,
    --   target = {
    --     list = {},
    --     objs = {
    --       { baseName = "Hsinchu AB", subTypes = { "Shelter", "Helipad", "Ammo Bunker" } }
    --     },
    --     areas = { constants.AREAS.AREA_OF_OPS_NORTH },
    --     filterNames = {},
    --     contactAge = 60 * 60,
    --     minTargetCount = 1
    --   },
    -- },
    -- {
    --   timeToReady = config.readytime,
    --   striker = {
    --     baseGUID = constants.BASES.JIAXING_AB,
    --     weaponDBID = constants.WEAPONS.AKD88,
    --     unitDBID = constants.PLATFORMS.J16,
    --     unitCount = 12,
    --     loadoutID = constants.LOADOUTS.J16_AKD88,
    --     startTime = nil,
    --     missionCreationParams = {
    --       name = "STRIKE/AB/C/1",
    --       type = "strike",
    --       opts = {
    --         type = "land",
    --         TankerMissionList = { "AAR/C" },
    --         FuelQtyToStartLookingForTanker_airborne = 85,
    --         MaxReceiversInQueuePerTanker_airborne = 1,
    --         LaunchMissionWithoutTankersInPlace = true,
    --         TankerMaxDistance_airborne = 50
    --       }
    --     },
    --     emcon = "Radar=Passive;OECM=Active"
    --   },
    --   escort = {
    --     baseGUID = constants.BASES.WUHU_AB,
    --     weaponDBID = constants.WEAPONS.PL15,
    --     unitDBID = constants.PLATFORMS.J20,
    --     unitCount = 4,
    --     loadoutID = constants.LOADOUTS.J20_PL15,
    --     missionCreationParams = {
    --       name = "SWEEP/AB/C/1",
    --       type = "patrol",
    --       opts = {
    --         type = "aaw",
    --         OneThirdRule = false,
    --         FlightSize = 4,
    --         CheckOPAREA = false,
    --         CheckWWR = false,
    --         prosecutionZone = constants.AREAS.TARGET_AREA_CENTER_PROSECUTION,
    --         patrolZone = constants.AREAS.TARGET_AREA_CENTER_PATROL,
    --         TankerUsage = 1,
    --         TankerMissionList = { "AAR/C" },
    --         FuelQtyToStartLookingForTanker_airborne = 85,
    --         MaxReceiversInQueuePerTanker_airborne = 1,
    --         LaunchMissionWithoutTankersInPlace = true,
    --         TankerMaxDistance_airborne = 50
    --       }
    --     },
    --     emcon = "Radar=Passive;OECM=Active"
    --   },
    --   wildWeasel = {
    --     baseGUID = constants.BASES.TAIZHOU_AB,
    --     weaponDBID = constants.WEAPONS.YJ91_ARM,
    --     unitDBID = constants.PLATFORMS.SU30,
    --     unitCount = 4,
    --     loadoutID = constants.LOADOUTS.SU30_YJ91,
    --     missionCreationParams = {
    --       name = "SEAD/AB/C/1",
    --       type = "patrol",
    --       opts = {
    --         type = "sead",
    --         OneThirdRule = false,
    --         FlightSize = 4,
    --         CheckOPAREA = false,
    --         CheckWWR = false,
    --         prosecutionZone = constants.AREAS.TARGET_AREA_CENTER_PROSECUTION,
    --         patrolZone = constants.AREAS.TARGET_AREA_CENTER_PATROL,
    --         TankerUsage = 1,
    --         TankerMissionList = { "AAR/C" },
    --         FuelQtyToStartLookingForTanker_airborne = 85,
    --         MaxReceiversInQueuePerTanker_airborne = 1,
    --         LaunchMissionWithoutTankersInPlace = true,
    --         TankerMaxDistance_airborne = 60
    --       }
    --     },
    --     emcon = "Radar=Passive;OECM=Active"
    --   },
    --   jammer = {
    --     baseGUID = constants.BASES.XIAHGTANG_AB,
    --     unitDBID = constants.PLATFORMS.J16D,
    --     weaponDBID = 0,
    --     unitCount = 1,
    --     loadoutID = nil,
    --     missionCreationParams = {
    --       name = "JAMMING/AB/C/1",
    --       type = "support",
    --       opts = {
    --         zone = constants.AREAS.TARGET_AREA_CENTER_PATROL,
    --         TankerUsage = 1,
    --         TankerMissionList = { "AAR/C" },
    --         FuelQtyToStartLookingForTanker_airborne = 85,
    --         MaxReceiversInQueuePerTanker_airborne = 1,
    --         LaunchMissionWithoutTankersInPlace = true,
    --         TankerMaxDistance_airborne = 70
    --       }
    --     },
    --     emcon = "Radar=Passive;OECM=Active"
    --   },
    --   tanker = {
    --     baseGUID = constants.BASES.SHUIMEN_AAB,
    --     baseGUIDCandidates = { constants.BASES.LEIYANG_AB },
    --     unitDBID = constants.PLATFORMS.HY6U_BADGER,
    --     weaponDBID = 0,
    --     unitCount = 8,
    --     loadoutID = nil,
    --     missionCreationParams = {
    --       name = "AAR/C",
    --       type = "support",
    --       opts = {
    --         OneThirdRule = false,
    --         FlightSize = 4,
    --         zone = constants.AREAS.AAR_PATROL
    --       }
    --     },
    --     emcon = "Radar=Passive;OECM=Passive"
    --   },
    --   reconUAV = nil,
    --   target = {
    --     list = {},
    --     objs = {
    --       { baseName = "Ching Chuang Kang AB", subTypes = { "Shelter", "Ammo Bunker" } },
    --       { baseName = "Chiayi AB",            subTypes = { "Shelter", "Ammo Bunker" } }
    --     },
    --     areas = { constants.AREAS.AREA_OF_OPS_CENTER },
    --     filterNames = {},
    --     contactAge = 60 * 60,
    --     minTargetCount = 1
    --   },
    -- },
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
        baseGUIDCandidates = { constants.BASES.LEIYANG_AB },
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
  STRIKE_AB_W_AAR_3 = {
    -- {
    --   timeToReady = config.readytime,
    --   striker = {
    --     baseGUID = constants.BASES.TAIZHOU_AB,
    --     weaponDBID = constants.WEAPONS.KAB1500,
    --     unitDBID = constants.PLATFORMS.SU30,
    --     unitCount = 12,
    --     loadoutID = constants.LOADOUTS.SU30_KAB1500,
    --     startTime = nil,
    --     missionCreationParams = {
    --       name = "STRIKE/AB/N/3",
    --       type = "strike",
    --       opts = {
    --         type = "land",
    --         -- TankerUsage = 1,
    --         -- TankerMissionList = { "AAR/E" },
    --         -- FuelQtyToStartLookingForTanker_airborne = 85,
    --         -- MaxReceiversInQueuePerTanker_airborne = 1,
    --         -- LaunchMissionWithoutTankersInPlace = true,
    --         -- TankerMaxDistance_airborne = 50
    --       }
    --     },
    --     emcon = "Radar=Passive;OECM=Active"
    --   },
    --   escort = {
    --     baseGUID = constants.BASES.WUHU_AB,
    --     weaponDBID = constants.WEAPONS.PL15,
    --     unitDBID = constants.PLATFORMS.J20,
    --     unitCount = 4,
    --     loadoutID = constants.LOADOUTS.J20_PL15,
    --     missionCreationParams = {
    --       name = "SWEEP/AB/N/3",
    --       type = "patrol",
    --       opts = {
    --         type = "aaw",
    --         OneThirdRule = false,
    --         FlightSize = 4,
    --         CheckOPAREA = false,
    --         CheckWWR = false,
    --         prosecutionZone = constants.AREAS.TARGET_AREA_NORTH_PROSECUTION,
    --         patrolZone = constants.AREAS.TARGET_AREA_NORTH_PATROL,
    --         TankerUsage = 1,
    --         TankerMissionList = { "AAR/E" },
    --         FuelQtyToStartLookingForTanker_airborne = 85,
    --         MaxReceiversInQueuePerTanker_airborne = 1,
    --         LaunchMissionWithoutTankersInPlace = true,
    --         TankerMaxDistance_airborne = 50
    --       }
    --     },
    --     emcon = "Radar=Passive;OECM=Active"
    --   },
    --   wildWeasel = {
    --     baseGUID = constants.BASES.JIAXING_AB,
    --     weaponDBID = constants.WEAPONS.YJ91_ASM,
    --     unitDBID = constants.PLATFORMS.J16,
    --     unitCount = 4,
    --     loadoutID = constants.LOADOUTS.J16_YJ91,
    --     missionCreationParams = {
    --       name = "SEAD/AB/N/3",
    --       type = "patrol",
    --       opts = {
    --         type = "sead",
    --         OneThirdRule = false,
    --         FlightSize = 4,
    --         CheckOPAREA = false,
    --         CheckWWR = false,
    --         prosecutionZone = constants.AREAS.TARGET_AREA_NORTH_PROSECUTION,
    --         patrolZone = constants.AREAS.TARGET_AREA_NORTH_PATROL,
    --         TankerUsage = 1,
    --         TankerMissionList = { "AAR/E" },
    --         FuelQtyToStartLookingForTanker_airborne = 85,
    --         MaxReceiversInQueuePerTanker_airborne = 1,
    --         LaunchMissionWithoutTankersInPlace = true,
    --         TankerMaxDistance_airborne = 50
    --       }
    --     },
    --     emcon = "Radar=Passive;OECM=Active"
    --   },
    --   jammer = {
    --     baseGUID = constants.BASES.XIAHGTANG_AB,
    --     unitDBID = constants.PLATFORMS.J16D,
    --     weaponDBID = 0,
    --     unitCount = 1,
    --     loadoutID = nil,
    --     missionCreationParams = {
    --       name = "JAMMING/AB/N/3",
    --       type = "support",
    --       opts = {
    --         zone = constants.AREAS.TARGET_AREA_NORTH_PATROL,
    --         TankerUsage = 1,
    --         TankerMissionList = { "AAR/E" },
    --         FuelQtyToStartLookingForTanker_airborne = 85,
    --         MaxReceiversInQueuePerTanker_airborne = 1,
    --         LaunchMissionWithoutTankersInPlace = true,
    --         TankerMaxDistance_airborne = 50
    --       }
    --     },
    --     emcon = "Radar=Passive;OECM=Active"
    --   },
    --   tanker = {
    --     baseGUID = constants.BASES.SHUIMEN_AAB,
    --     baseGUIDCandidates = { constants.BASES.LEIYANG_AB },
    --     unitDBID = constants.PLATFORMS.HY6U_BADGER,
    --     weaponDBID = 0,
    --     unitCount = 8,
    --     loadoutID = nil,
    --     missionCreationParams = {
    --       name = "AAR/E",
    --       type = "support",
    --       opts = {
    --         OneThirdRule = false,
    --         FlightSize = 2,
    --         zone = constants.AREAS.AAR_PATROL_2
    --       }
    --     },
    --     emcon = "Radar=Passive;OECM=Passive"
    --   },
    --   reconUAV = nil,
    --   target = {
    --     list = {},
    --     objs = {
    --       { baseName = "Hsinchu AB", subTypes = { "Ammo Bunker" } }
    --     },
    --     areas = { constants.AREAS.AREA_OF_OPS_NORTH },
    --     filterNames = {},
    --     contactAge = 60 * 60,
    --     minTargetCount = 1
    --   },
    -- },
    -- {
    --   timeToReady = config.readytime,
    --   striker = {
    --     baseGUID = constants.BASES.TAIZHOU_AB,
    --     weaponDBID = constants.WEAPONS.KAB1500,
    --     unitDBID = constants.PLATFORMS.SU30,
    --     unitCount = 12,
    --     loadoutID = constants.LOADOUTS.SU30_KAB1500,
    --     startTime = nil,
    --     missionCreationParams = {
    --       name = "STRIKE/AB/C/3",
    --       type = "strike",
    --       opts = {
    --         type = "land",
    --         TankerMissionList = { "AAR/C" },
    --         FuelQtyToStartLookingForTanker_airborne = 85,
    --         MaxReceiversInQueuePerTanker_airborne = 1,
    --         LaunchMissionWithoutTankersInPlace = true,
    --         TankerMaxDistance_airborne = 50
    --       }
    --     },
    --     emcon = "Radar=Passive;OECM=Active"
    --   },
    --   escort = {
    --     baseGUID = constants.BASES.WUHU_AB,
    --     weaponDBID = constants.WEAPONS.PL15,
    --     unitDBID = constants.PLATFORMS.J20,
    --     unitCount = 4,
    --     loadoutID = constants.LOADOUTS.J20_PL15,
    --     missionCreationParams = {
    --       name = "SWEEP/AB/C/3",
    --       type = "patrol",
    --       opts = {
    --         type = "aaw",
    --         OneThirdRule = false,
    --         FlightSize = 4,
    --         CheckOPAREA = false,
    --         CheckWWR = false,
    --         prosecutionZone = constants.AREAS.TARGET_AREA_CENTER_PROSECUTION,
    --         patrolZone = constants.AREAS.TARGET_AREA_CENTER_PATROL,
    --         TankerUsage = 1,
    --         TankerMissionList = { "AAR/C" },
    --         FuelQtyToStartLookingForTanker_airborne = 85,
    --         MaxReceiversInQueuePerTanker_airborne = 1,
    --         LaunchMissionWithoutTankersInPlace = true,
    --         TankerMaxDistance_airborne = 50
    --       }
    --     },
    --     emcon = "Radar=Passive;OECM=Active"
    --   },
    --   wildWeasel = {
    --     baseGUID = constants.BASES.JIAXING_AB,
    --     weaponDBID = constants.WEAPONS.YJ91_ASM,
    --     unitDBID = constants.PLATFORMS.J16,
    --     unitCount = 4,
    --     loadoutID = constants.LOADOUTS.J16_YJ91,
    --     missionCreationParams = {
    --       name = "SEAD/AB/C/3",
    --       type = "patrol",
    --       opts = {
    --         type = "sead",
    --         OneThirdRule = false,
    --         FlightSize = 4,
    --         CheckOPAREA = false,
    --         CheckWWR = false,
    --         prosecutionZone = constants.AREAS.TARGET_AREA_CENTER_PROSECUTION,
    --         patrolZone = constants.AREAS.TARGET_AREA_CENTER_PATROL,
    --         TankerUsage = 1,
    --         TankerMissionList = { "AAR/C" },
    --         FuelQtyToStartLookingForTanker_airborne = 85,
    --         MaxReceiversInQueuePerTanker_airborne = 1,
    --         LaunchMissionWithoutTankersInPlace = true,
    --         TankerMaxDistance_airborne = 60
    --       }
    --     },
    --     emcon = "Radar=Passive;OECM=Active"
    --   },
    --   jammer = {
    --     baseGUID = constants.BASES.XIAHGTANG_AB,
    --     unitDBID = constants.PLATFORMS.J16D,
    --     weaponDBID = 0,
    --     unitCount = 1,
    --     loadoutID = nil,
    --     missionCreationParams = {
    --       name = "JAMMING/AB/C/3",
    --       type = "support",
    --       opts = {
    --         zone = constants.AREAS.TARGET_AREA_CENTER_PATROL,
    --         TankerUsage = 1,
    --         TankerMissionList = { "AAR/C" },
    --         FuelQtyToStartLookingForTanker_airborne = 85,
    --         MaxReceiversInQueuePerTanker_airborne = 1,
    --         LaunchMissionWithoutTankersInPlace = true,
    --         TankerMaxDistance_airborne = 70
    --       }
    --     },
    --     emcon = "Radar=Passive;OECM=Active"
    --   },
    --   tanker = {
    --     baseGUID = constants.BASES.SHUIMEN_AAB,
    --     baseGUIDCandidates = { constants.BASES.LEIYANG_AB },
    --     unitDBID = constants.PLATFORMS.HY6U_BADGER,
    --     weaponDBID = 0,
    --     unitCount = 8,
    --     loadoutID = nil,
    --     missionCreationParams = {
    --       name = "AAR/C",
    --       type = "support",
    --       opts = {
    --         OneThirdRule = false,
    --         FlightSize = 4,
    --         zone = constants.AREAS.AAR_PATROL
    --       }
    --     },
    --     emcon = "Radar=Passive;OECM=Passive"
    --   },
    --   reconUAV = nil,
    --   target = {
    --     list = {},
    --     objs = {
    --       { baseName = "Ching Chuang Kang AB", subTypes = { "Ammo Bunker" } },
    --       { baseName = "Chiayi AB",            subTypes = { "Ammo Bunker" } }
    --     },
    --     areas = { constants.AREAS.AREA_OF_OPS_CENTER },
    --     filterNames = {},
    --     contactAge = 60 * 60,
    --     minTargetCount = 1
    --   },
    -- },
    {
      timeToReady = config.readytime,
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
          name = "SWEEP/AB/S/3",
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
          name = "JAMMING/AB/S/3",
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
        baseGUIDCandidates = { constants.BASES.LEIYANG_AB },
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
config.c.packageTemplates.STRIKE_AB_W_AAR_2 = config.c.packageTemplates.STRIKE_AB_W_2


-- ============================================================================
-- GPS Jamming (Taiwan)
-- ============================================================================

config.t.gnssJamming = {}
config.t.gnssJamming.randomRadius = 20 -- random radius
config.t.gnssJamming.radius = 11
config.t.gnssJamming.gnssGuidedWeapons = {
  { dbid = constants.WEAPONS.FD280,    jammingResistance = 50 },
  { dbid = constants.WEAPONS.CJ10A,    jammingResistance = 50 },
  { dbid = constants.WEAPONS.AKD88,    jammingResistance = 50 },
  { dbid = constants.WEAPONS.LS_6_500, jammingResistance = 50 },
  { dbid = constants.WEAPONS.CS_BBC_5, jammingResistance = 50 },
}
config.t.gnssJamming.jammers = {
  ["Comms & Info Coy, 584th Mech Bde"] = {
    zoneName = "(Taiwan) Jamming Zone/1",
    name = "Comms & Info Coy, 584th Mech Bde",
    point = nil,
    randomRadius = config.t.gnssJamming.randomRadius,
    radius = config.t.gnssJamming.radius
  },
  ["Comms & Info Coy, 269th Mech Bde"] = {
    zoneName = "(Taiwan) Jamming Zone/2",
    name = "Comms & Info Coy, 269th Mech Bde",
    point = nil,
    randomRadius = config.t.gnssJamming.randomRadius,
    radius = config.t.gnssJamming.radius
  },
}


-- ============================================================================
-- MLRS (Taiwan)
-- ============================================================================

config.t.ground = {}
config.t.ground.mlrs = {}
config.t.ground.mlrs.wpnDefault = 144
config.t.ground.mlrs.ammoThreshold = 25
config.t.ground.mlrs.reloadTime = 30 * 60
config.t.ground.mlrs.stowTime = 5 * 60
config.t.ground.mlrs.ammunitions = {
  ["Ammo Revetment, Rocket Arty Coy, 21st Arty Command"] = {
    guid = "",
    name = "Ammo Revetment, Rocket Arty Coy, 21st Arty Command",
    wpnCurrent = config.t.ground.mlrs.wpnDefault,
    wpnDefault = config.t.ground.mlrs.wpnDefault,
  },
}
config.t.ground.mlrs.resupplyUnits = {
  ["Ammo Sec, Rocket Arty Coy, 21st Arty Command"] = {
    guid = "",
    name = "Ammo Sec, Rocket Arty Coy, 21st Arty Command",
    wpnCurrent = config.t.ground.mlrs.wpnDefault,
    wpnDefault = config.t.ground.mlrs.wpnDefault,
    unitCount = 2,
    operationalArea = constants.OPERATIONAL_AREAS.NVD,
    state = constants.MISSILE_SYSTEM_STATE.STATIC,
    ammunition = "Ammo Revetment, Rocket Arty Coy, 21st Arty Command",
    firingUnit = "Rocket Arty Coy, 21st Arty Command"
  },
}
config.t.ground.mlrs.firingUnits = {
  ["Rocket Arty Coy, 21st Arty Command"] = {
    guid = "",
    name = "Rocket Arty Coy, 21st Arty Command",
    msg = "Radio source, Bty",
    state = constants.MISSILE_SYSTEM_STATE.HIDE,
    operationalArea = constants.OPERATIONAL_AREAS.NVD,
    weaponDBID = constants.WEAPONS.MK45_AMLRS,
    ammoThreshold = config.t.ground.mlrs.ammoThreshold,
    resupplyUnit = "Ammo Sec, Rocket Arty Coy, 21st Arty Command",
    dbid = constants.PLATFORMS.LT2000,
  },
}

-- ============================================================================
-- SRBM (Taiwan)
-- ============================================================================

config.t.ground.srbm = {}
config.t.ground.srbm.wpnDefault = 27
config.t.ground.srbm.ammoThreshold = 25
config.t.ground.srbm.reloadTime = 10 * 60
config.t.ground.srbm.stowTime = 5 * 60
config.t.ground.srbm.ammunitions = {
  ["Ammo Revetment, Rocket Arty Coy, 58th Arty Command"] = {
    guid = "",
    name = "Ammo Revetment, Rocket Arty Coy, 58th Arty Command",
    wpnCurrent = config.t.ground.srbm.wpnDefault,
    wpnDefault = config.t.ground.srbm.wpnDefault,
  },
}
config.t.ground.srbm.resupplyUnits = {
  ["Ammo Sec, Rocket Arty Coy, 58th Arty Command"] = {
    guid = "",
    name = "Ammo Sec, Rocket Arty Coy, 58th Arty Command",
    wpnCurrent = config.t.ground.srbm.wpnDefault,
    wpnDefault = config.t.ground.srbm.wpnDefault,
    unitCount = 3,
    operationalArea = constants.OPERATIONAL_AREAS.LPK,
    state = constants.MISSILE_SYSTEM_STATE.STATIC,
    ammunition = "Ammo Revetment, Rocket Arty Coy, 58th Arty Command",
    firingUnit = "Rocket Arty Coy, 58th Arty Command"
  },
}
config.t.ground.srbm.firingUnits = {
  ["Rocket Arty Coy, 58th Arty Command"] = {
    guid = "",
    name = "Rocket Arty Coy, 58th Arty Command",
    msg = "Radio source, Bty",
    state = constants.MISSILE_SYSTEM_STATE.HIDE,
    operationalArea = constants.OPERATIONAL_AREAS.LPK,
    weaponDBID = constants.WEAPONS.ATACMS,
    ammoThreshold = config.t.ground.srbm.ammoThreshold,
    resupplyUnit = "Ammo Sec, Rocket Arty Coy, 58th Arty Command",
    dbid = constants.PLATFORMS.HIMARS,
  },
}


-- ============================================================================
-- GLCM (Taiwan)
-- ============================================================================

config.t.ground.glcm = {}
config.t.ground.glcm.wpnDefault = 48
config.t.ground.glcm.ammoThreshold = 25
config.t.ground.glcm.reloadTime = 45 * 60
config.t.ground.glcm.stowTime = 5 * 60
config.t.ground.glcm.ammunitions = {
  ["Ammo Revetment, 641st Bn, 791st AFAD & Arty Bde"] = {
    guid = "",
    name = "Ammo Revetment, 641st Bn, 791st AFAD & Arty Bde",
    wpnCurrent = config.t.ground.glcm.wpnDefault * 2,
    wpnDefault = config.t.ground.glcm.wpnDefault * 2,
  },
  ["Ammo Revetment, 642nd Bn, 791st AFAD & Arty Bde"] = {
    guid = "",
    name = "Ammo Revetment, 642nd Bn, 791st AFAD & Arty Bde",
    wpnCurrent = config.t.ground.glcm.wpnDefault * 2,
    wpnDefault = config.t.ground.glcm.wpnDefault * 2,
  },
}
config.t.ground.glcm.resupplyUnits = {
  ["Ammo Sec, 641st Bn, 791st AFAD & Arty Bde"] = {
    guid = "",
    name = "Ammo Sec, 641st Bn, 791st AFAD & Arty Bde",
    wpnCurrent = config.t.ground.glcm.wpnDefault,
    wpnDefault = config.t.ground.glcm.wpnDefault,
    unitCount = 3,
    operationalArea = constants.OPERATIONAL_AREAS.SET,
    state = constants.MISSILE_SYSTEM_STATE.STATIC,
    ammunition = "Ammo Revetment, 641st Bn, 791st AFAD & Arty Bde",
    firingUnit = "641st Bn, 791st AFAD & Arty Bde"
  },
  ["Ammo Sec, 642nd Bn, 791st AFAD & Arty Bde"] = {
    guid = "",
    name = "Ammo Sec, 642nd Bn, 791st AFAD & Arty Bde",
    wpnCurrent = config.t.ground.glcm.wpnDefault,
    wpnDefault = config.t.ground.glcm.wpnDefault,
    unitCount = 3,
    operationalArea = constants.OPERATIONAL_AREAS.AMG,
    state = constants.MISSILE_SYSTEM_STATE.STATIC,
    ammunition = "Ammo Revetment, 642nd Bn, 791st AFAD & Arty Bde",
    firingUnit = "642nd Bn, 791st AFAD & Arty Bde"
  },
}
config.t.ground.glcm.firingUnits = {
  ["641st Bn, 791st AFAD & Arty Bde"] = {
    guid = "",
    name = "641st Bn, 791st AFAD & Arty Bde",
    msg = "Radio source, Bty",
    state = constants.MISSILE_SYSTEM_STATE.HIDE,
    operationalArea = constants.OPERATIONAL_AREAS.SET,
    weaponDBID = constants.WEAPONS.HF2E,
    ammoThreshold = config.t.ground.glcm.ammoThreshold,
    resupplyUnit = "Ammo Sec, 641st Bn, 791st AFAD & Arty Bde",
    dbid = constants.PLATFORMS.CUSTOMED_SSM,
    mountDescriptors = constants.MOUNT_DESCRIPTORS.HF2E,
  },
  ["642nd Bn, 791st AFAD & Arty Bde"] = {
    guid = "",
    name = "642nd Bn, 791st AFAD & Arty Bde",
    msg = "Radio source, Bty",
    state = constants.MISSILE_SYSTEM_STATE.HIDE,
    operationalArea = constants.OPERATIONAL_AREAS.AMG,
    weaponDBID = constants.WEAPONS.HF2E,
    ammoThreshold = config.t.ground.glcm.ammoThreshold,
    resupplyUnit = "Ammo Sec, 642nd Bn, 791st AFAD & Arty Bde",
    dbid = constants.PLATFORMS.CUSTOMED_SSM,
    mountDescriptors = constants.MOUNT_DESCRIPTORS.HF2E,
  },
}

-- ============================================================================
-- ASCM (Taiwan)
-- ============================================================================

config.t.ground.ascm = {}
config.t.ground.ascm.wpnDefault = 16
config.t.ground.ascm.ammoThreshold = 25
-- config.t.ground.ascm.reloadTime = 45 * 60
config.t.ground.ascm.reloadTime = 5 * 60
config.t.ground.ascm.stowTime = 5 * 60
config.t.ground.ascm.ammunitions = {
  ["Ammo Revetment, 1st Hai Feng Shore-based ASM MOB Sqn"] = {
    guid = "",
    name = "Ammo Revetment, 1st Hai Feng Shore-based ASM MOB Sqn",
    wpnCurrent = config.t.ground.ascm.wpnDefault * 2,
    wpnDefault = config.t.ground.ascm.wpnDefault * 2,
  },
  ["Ammo Revetment, 2nd Hai Feng Shore-based ASM MOB Sqn"] = {
    guid = "",
    name = "Ammo Revetment, 2nd Hai Feng Shore-based ASM MOB Sqn",
    wpnCurrent = config.t.ground.ascm.wpnDefault * 2,
    wpnDefault = config.t.ground.ascm.wpnDefault * 2,
  },
  ["Ammo Revetment, 3rd Hai Feng Shore-based ASM MOB Sqn"] = {
    guid = "",
    name = "Ammo Revetment, 3rd Hai Feng Shore-based ASM MOB Sqn",
    wpnCurrent = config.t.ground.ascm.wpnDefault * 2,
    wpnDefault = config.t.ground.ascm.wpnDefault * 2,
  },
  ["Ammo Revetment, 4th Hai Feng Shore-based ASM MOB Sqn"] = {
    guid = "",
    name = "Ammo Revetment, 4th Hai Feng Shore-based ASM MOB Sqn",
    wpnCurrent = config.t.ground.ascm.wpnDefault * 2,
    wpnDefault = config.t.ground.ascm.wpnDefault * 2,
  },
  ["Ammo Revetment, 5th Hai Feng Shore-based ASM MOB Sqn"] = {
    guid = "",
    name = "Ammo Revetment, 5th Hai Feng Shore-based ASM MOB Sqn",
    wpnCurrent = config.t.ground.ascm.wpnDefault * 2,
    wpnDefault = config.t.ground.ascm.wpnDefault * 2,
  },
  ["Ammo Revetment, 6th Hai Feng Shore-based ASM MOB Sqn"] = {
    guid = "",
    name = "Ammo Revetment, 6th Hai Feng Shore-based ASM MOB Sqn",
    wpnCurrent = config.t.ground.ascm.wpnDefault * 2,
    wpnDefault = config.t.ground.ascm.wpnDefault * 2,
  },
}
config.t.ground.ascm.resupplyUnits = {
  ["Ammo Sec, 1st Hai Feng Shore-based ASM MOB Sqn"] = {
    guid = "",
    name = "Ammo Sec, 1st Hai Feng Shore-based ASM MOB Sqn",
    wpnCurrent = config.t.ground.ascm.wpnDefault,
    wpnDefault = config.t.ground.ascm.wpnDefault,
    unitCount = 2,
    operationalArea = constants.OPERATIONAL_AREAS.FZM,
    state = constants.MISSILE_SYSTEM_STATE.STATIC,
    ammunition = "Ammo Revetment, 1st Hai Feng Shore-based ASM MOB Sqn",
    firingUnit = "1st Hai Feng Shore-based ASM MOB Sqn"
  },
  ["Ammo Sec, 2nd Hai Feng Shore-based ASM MOB Sqn"] = {
    guid = "",
    name = "Ammo Sec, 2nd Hai Feng Shore-based ASM MOB Sqn",
    wpnCurrent = config.t.ground.ascm.wpnDefault,
    wpnDefault = config.t.ground.ascm.wpnDefault,
    unitCount = 2,
    operationalArea = constants.OPERATIONAL_AREAS.DLF,
    state = constants.MISSILE_SYSTEM_STATE.STATIC,
    ammunition = "Ammo Revetment, 2nd Hai Feng Shore-based ASM MOB Sqn",
    firingUnit = "2nd Hai Feng Shore-based ASM MOB Sqn"
  },
  ["Ammo Sec, 3rd Hai Feng Shore-based ASM MOB Sqn"] = {
    guid = "",
    name = "Ammo Sec, 3rd Hai Feng Shore-based ASM MOB Sqn",
    wpnCurrent = config.t.ground.ascm.wpnDefault,
    wpnDefault = config.t.ground.ascm.wpnDefault,
    unitCount = 2,
    operationalArea = constants.OPERATIONAL_AREAS.TGO,
    state = constants.MISSILE_SYSTEM_STATE.STATIC,
    ammunition = "Ammo Revetment, 3rd Hai Feng Shore-based ASM MOB Sqn",
    firingUnit = "3rd Hai Feng Shore-based ASM MOB Sqn"
  },
  ["Ammo Sec, 4th Hai Feng Shore-based ASM MOB Sqn"] = {
    guid = "",
    name = "Ammo Sec, 4th Hai Feng Shore-based ASM MOB Sqn",
    wpnCurrent = config.t.ground.ascm.wpnDefault,
    wpnDefault = config.t.ground.ascm.wpnDefault,
    unitCount = 2,
    operationalArea = constants.OPERATIONAL_AREAS.BPM,
    state = constants.MISSILE_SYSTEM_STATE.STATIC,
    ammunition = "Ammo Revetment, 4th Hai Feng Shore-based ASM MOB Sqn",
    firingUnit = "4th Hai Feng Shore-based ASM MOB Sqn"
  },
  ["Ammo Sec, 5th Hai Feng Shore-based ASM MOB Sqn"] = {
    guid = "",
    name = "Ammo Sec, 5th Hai Feng Shore-based ASM MOB Sqn",
    wpnCurrent = config.t.ground.ascm.wpnDefault,
    wpnDefault = config.t.ground.ascm.wpnDefault,
    unitCount = 2,
    operationalArea = constants.OPERATIONAL_AREAS.PDN,
    state = constants.MISSILE_SYSTEM_STATE.STATIC,
    ammunition = "Ammo Revetment, 5th Hai Feng Shore-based ASM MOB Sqn",
    firingUnit = "5th Hai Feng Shore-based ASM MOB Sqn"
  },
  ["Ammo Sec, 6th Hai Feng Shore-based ASM MOB Sqn"] = {
    guid = "",
    name = "Ammo Sec, 6th Hai Feng Shore-based ASM MOB Sqn",
    wpnCurrent = config.t.ground.ascm.wpnDefault,
    wpnDefault = config.t.ground.ascm.wpnDefault,
    unitCount = 2,
    operationalArea = constants.OPERATIONAL_AREAS.SKB,
    state = constants.MISSILE_SYSTEM_STATE.STATIC,
    ammunition = "Ammo Revetment, 6th Hai Feng Shore-based ASM MOB Sqn",
    firingUnit = "6th Hai Feng Shore-based ASM MOB Sqn"
  },
}
config.t.ground.ascm.firingUnits = {
  ["1st Hai Feng Shore-based ASM MOB Sqn"] = {
    guid = "",
    name = "1st Hai Feng Shore-based ASM MOB Sqn",
    msg = "Radio source, Bty",
    state = constants.MISSILE_SYSTEM_STATE.HIDE,
    operationalArea = constants.OPERATIONAL_AREAS.FZM,
    weaponDBID = constants.WEAPONS.HF3,
    ammoThreshold = config.t.ground.ascm.ammoThreshold,
    resupplyUnit = "Ammo Sec, 1st Hai Feng Shore-based ASM MOB Sqn",
    dbid = constants.PLATFORMS.HF3,
  },
  ["2nd Hai Feng Shore-based ASM MOB Sqn"] = {
    guid = "",
    name = "2nd Hai Feng Shore-based ASM MOB Sqn",
    msg = "Radio source, Bty",
    state = constants.MISSILE_SYSTEM_STATE.HIDE,
    operationalArea = constants.OPERATIONAL_AREAS.DLF,
    weaponDBID = constants.WEAPONS.HF3,
    ammoThreshold = config.t.ground.ascm.ammoThreshold,
    resupplyUnit = "Ammo Sec, 2nd Hai Feng Shore-based ASM MOB Sqn",
    dbid = constants.PLATFORMS.HF3,
  },
  ["3rd Hai Feng Shore-based ASM MOB Sqn"] = {
    guid = "",
    name = "3rd Hai Feng Shore-based ASM MOB Sqn",
    msg = "Radio source, Bty",
    state = constants.MISSILE_SYSTEM_STATE.HIDE,
    operationalArea = constants.OPERATIONAL_AREAS.TGO,
    weaponDBID = constants.WEAPONS.HF3,
    ammoThreshold = config.t.ground.ascm.ammoThreshold,
    resupplyUnit = "Ammo Sec, 3rd Hai Feng Shore-based ASM MOB Sqn",
    dbid = constants.PLATFORMS.HF3,
  },
  ["4th Hai Feng Shore-based ASM MOB Sqn"] = {
    guid = "",
    name = "4th Hai Feng Shore-based ASM MOB Sqn",
    msg = "Radio source, Bty",
    state = constants.MISSILE_SYSTEM_STATE.HIDE,
    operationalArea = constants.OPERATIONAL_AREAS.BPM,
    weaponDBID = constants.WEAPONS.HF3,
    ammoThreshold = config.t.ground.ascm.ammoThreshold,
    resupplyUnit = "Ammo Sec, 4th Hai Feng Shore-based ASM MOB Sqn",
    dbid = constants.PLATFORMS.HF3,
  },
  ["5th Hai Feng Shore-based ASM MOB Sqn"] = {
    guid = "",
    name = "5th Hai Feng Shore-based ASM MOB Sqn",
    msg = "Radio source, Bty",
    state = constants.MISSILE_SYSTEM_STATE.HIDE,
    operationalArea = constants.OPERATIONAL_AREAS.PDN,
    weaponDBID = constants.WEAPONS.HF3,
    ammoThreshold = config.t.ground.ascm.ammoThreshold,
    resupplyUnit = "Ammo Sec, 5th Hai Feng Shore-based ASM MOB Sqn",
    dbid = constants.PLATFORMS.HF3,
  },
  ["6th Hai Feng Shore-based ASM MOB Sqn"] = {
    guid = "",
    name = "6th Hai Feng Shore-based ASM MOB Sqn",
    msg = "Radio source, Bty",
    state = constants.MISSILE_SYSTEM_STATE.HIDE,
    operationalArea = constants.OPERATIONAL_AREAS.SKB,
    weaponDBID = constants.WEAPONS.HF3,
    ammoThreshold = config.t.ground.ascm.ammoThreshold,
    resupplyUnit = "Ammo Sec, 6th Hai Feng Shore-based ASM MOB Sqn",
    dbid = constants.PLATFORMS.HF3,
  },
}

-- ============================================================================
-- SAM (Taiwan)
-- ============================================================================

config.t.ground.sam = {}
config.t.ground.sam.wpnDefault = 54
config.t.ground.sam.ammoThreshold = 50
config.t.ground.sam.reloadTime = 5 * 60
config.t.ground.sam.stowTime = 5 * 60
config.t.ground.sam.ammunitions = {
  ["Ammo Revetment, 1st Coy, 613rd Bn, 792nd AFAD & Arty Bde"] = {
    guid = "",
    name = "Ammo Revetment, 1st Coy, 613rd Bn, 792nd AFAD & Arty Bde",
    wpnCurrent = 96,
    wpnDefault = 96,
  },
  ["Ammo Revetment, 1st Coy, 614th Bn, 793rd AFAD & Arty Bde"] = {
    guid = "",
    name = "Ammo Revetment, 1st Coy, 614th Bn, 793rd AFAD & Arty Bde",
    wpnCurrent = 96,
    wpnDefault = 96,
  },
  ["Ammo Revetment, 1st Coy, 631st Bn, 793rd AFAD & Arty Bde"] = {
    guid = "",
    name = "Ammo Revetment, 1st Coy, 631st Bn, 793rd AFAD & Arty Bde",
    wpnCurrent = config.t.ground.sam.wpnDefault * 2,
    wpnDefault = config.t.ground.sam.wpnDefault * 2,
  },
  ["Ammo Revetment, 1st Coy, 632nd Bn, 794th AFAD & Arty Bde"] = {
    guid = "",
    name = "Ammo Revetment, 1st Coy, 632nd Bn, 794th AFAD & Arty Bde",
    wpnCurrent = config.t.ground.sam.wpnDefault * 2,
    wpnDefault = config.t.ground.sam.wpnDefault * 2,
  },
  ["Ammo Revetment, 1st Coy, 633rd Bn, 795th AFAD & Arty Bde"] = {
    guid = "",
    name = "Ammo Revetment, 1st Coy, 633rd Bn, 795th AFAD & Arty Bde",
    wpnCurrent = config.t.ground.sam.wpnDefault * 2,
    wpnDefault = config.t.ground.sam.wpnDefault * 2,
  },
  ["Ammo Revetment, 2nd Coy, 613rd Bn, 792nd AFAD & Arty Bde"] = {
    guid = "",
    name = "Ammo Revetment, 2nd Coy, 613rd Bn, 792nd AFAD & Arty Bde",
    wpnCurrent = 96,
    wpnDefault = 96,
  },
  ["Ammo Revetment, 2nd Coy, 614th Bn, 793rd AFAD & Arty Bde"] = {
    guid = "",
    name = "Ammo Revetment, 2nd Coy, 614th Bn, 793rd AFAD & Arty Bde",
    wpnCurrent = 96,
    wpnDefault = 96,
  },
  ["Ammo Revetment, 2nd Coy, 631st Bn, 793rd AFAD & Arty Bde"] = {
    guid = "",
    name = "Ammo Revetment, 2nd Coy, 631st Bn, 793rd AFAD & Arty Bde",
    wpnCurrent = config.t.ground.sam.wpnDefault * 2,
    wpnDefault = config.t.ground.sam.wpnDefault * 2,
  },
  ["Ammo Revetment, 2nd Coy, 632nd Bn, 794th AFAD & Arty Bde"] = {
    guid = "",
    name = "Ammo Revetment, 2nd Coy, 632nd Bn, 794th AFAD & Arty Bde",
    wpnCurrent = config.t.ground.sam.wpnDefault * 2,
    wpnDefault = config.t.ground.sam.wpnDefault * 2,
  },
  ["Ammo Revetment, 2nd Coy, 633rd Bn, 795th AFAD & Arty Bde"] = {
    guid = "",
    name = "Ammo Revetment, 2nd Coy, 633rd Bn, 795th AFAD & Arty Bde",
    wpnCurrent = config.t.ground.sam.wpnDefault * 2,
    wpnDefault = config.t.ground.sam.wpnDefault * 2,
  },
  ["Ammo Revetment, 3rd Coy, 613rd Bn, 792nd AFAD & Arty Bde"] = {
    guid = "",
    name = "Ammo Revetment, 3rd Coy, 613rd Bn, 792nd AFAD & Arty Bde",
    wpnCurrent = 96,
    wpnDefault = 96,
  },
  ["Ammo Revetment, 3rd Coy, 614th Bn, 793rd AFAD & Arty Bde"] = {
    guid = "",
    name = "Ammo Revetment, 3rd Coy, 614th Bn, 793rd AFAD & Arty Bde",
    wpnCurrent = 96,
    wpnDefault = 96,
  },
  ["Ammo Revetment, 3rd Coy, 631st Bn, 793rd AFAD & Arty Bde"] = {
    guid = "",
    name = "Ammo Revetment, 3rd Coy, 631st Bn, 793rd AFAD & Arty Bde",
    wpnCurrent = config.t.ground.sam.wpnDefault * 2,
    wpnDefault = config.t.ground.sam.wpnDefault * 2,
  },
  ["Ammo Revetment, 3rd Coy, 632nd Bn, 794th AFAD & Arty Bde"] = {
    guid = "",
    name = "Ammo Revetment, 3rd Coy, 632nd Bn, 794th AFAD & Arty Bde",
    wpnCurrent = config.t.ground.sam.wpnDefault * 2,
    wpnDefault = config.t.ground.sam.wpnDefault * 2,
  },
  ["Ammo Revetment, 3rd Coy, 633rd Bn, 795th AFAD & Arty Bde"] = {
    guid = "",
    name = "Ammo Revetment, 3rd Coy, 633rd Bn, 795th AFAD & Arty Bde",
    wpnCurrent = config.t.ground.sam.wpnDefault * 2,
    wpnDefault = config.t.ground.sam.wpnDefault * 2,
  },
}
config.t.ground.sam.resupplyUnits = {
  ["Ammo Sec, 1st Coy, 613rd Bn, 792nd AFAD & Arty Bde"] = {
    guid = "",
    name = "Ammo Sec, 1st Coy, 613rd Bn, 792nd AFAD & Arty Bde",
    wpnCurrent = 48,
    wpnDefault = 48,
    unitCount = 1,
    operationalArea = constants.OPERATIONAL_AREAS.IKJ,
    state = constants.MISSILE_SYSTEM_STATE.STATIC,
    ammunition = "Ammo Revetment, 1st Coy, 613rd Bn, 792nd AFAD & Arty Bde",
    firingUnit = "1st Coy, 613rd Bn, 792nd AFAD & Arty Bde"
  },
  ["Ammo Sec, 1st Coy, 614th Bn, 793rd AFAD & Arty Bde"] = {
    guid = "",
    name = "Ammo Sec, 1st Coy, 614th Bn, 793rd AFAD & Arty Bde",
    wpnCurrent = 48,
    wpnDefault = 48,
    unitCount = 1,
    operationalArea = constants.OPERATIONAL_AREAS.UVY,
    state = constants.MISSILE_SYSTEM_STATE.STATIC,
    ammunition = "Ammo Revetment, 1st Coy, 614th Bn, 793rd AFAD & Arty Bde",
    firingUnit = "1st Coy, 614th Bn, 793rd AFAD & Arty Bde"
  },
  ["Ammo Sec, 1st Coy, 631st Bn, 793rd AFAD & Arty Bde"] = {
    guid = "",
    name = "Ammo Sec, 1st Coy, 631st Bn, 793rd AFAD & Arty Bde",
    wpnCurrent = config.t.ground.sam.wpnDefault,
    wpnDefault = config.t.ground.sam.wpnDefault,
    unitCount = 1,
    operationalArea = constants.OPERATIONAL_AREAS.QPF,
    state = constants.MISSILE_SYSTEM_STATE.STATIC,
    ammunition = "Ammo Revetment, 2nd Coy, 631st Bn, 793rd AFAD & Arty Bde",
    firingUnit = "1st Coy, 631st Bn, 793rd AFAD & Arty Bde"
  },
  ["Ammo Sec, 1st Coy, 632nd Bn, 794th AFAD & Arty Bde"] = {
    guid = "",
    name = "Ammo Sec, 1st Coy, 632nd Bn, 794th AFAD & Arty Bde",
    wpnCurrent = config.t.ground.sam.wpnDefault,
    wpnDefault = config.t.ground.sam.wpnDefault,
    unitCount = 1,
    operationalArea = constants.OPERATIONAL_AREAS.NUJ,
    state = constants.MISSILE_SYSTEM_STATE.STATIC,
    ammunition = "Ammo Revetment, 1st Coy, 632nd Bn, 794th AFAD & Arty Bde",
    firingUnit = "1st Coy, 632nd Bn, 794th AFAD & Arty Bde"
  },
  ["Ammo Sec, 1st Coy, 633rd Bn, 795th AFAD & Arty Bde"] = {
    guid = "",
    name = "Ammo Sec, 1st Coy, 633rd Bn, 795th AFAD & Arty Bde",
    wpnCurrent = config.t.ground.sam.wpnDefault,
    wpnDefault = config.t.ground.sam.wpnDefault,
    unitCount = 1,
    operationalArea = constants.OPERATIONAL_AREAS.QTZ,
    state = constants.MISSILE_SYSTEM_STATE.STATIC,
    ammunition = "Ammo Revetment, 1st Coy, 633rd Bn, 795th AFAD & Arty Bde",
    firingUnit = "1st Coy, 633rd Bn, 795th AFAD & Arty Bde"
  },
  ["Ammo Sec, 2nd Coy, 613rd Bn, 792nd AFAD & Arty Bde"] = {
    guid = "",
    name = "Ammo Sec, 2nd Coy, 613rd Bn, 792nd AFAD & Arty Bde",
    wpnCurrent = 48,
    wpnDefault = 48,
    unitCount = 1,
    operationalArea = constants.OPERATIONAL_AREAS.MAK,
    state = constants.MISSILE_SYSTEM_STATE.STATIC,
    ammunition = "Ammo Revetment, 2nd Coy, 613rd Bn, 792nd AFAD & Arty Bde",
    firingUnit = "2nd Coy, 613rd Bn, 792nd AFAD & Arty Bde"
  },
  ["Ammo Sec, 2nd Coy, 614th Bn, 793rd AFAD & Arty Bde"] = {
    guid = "",
    name = "Ammo Sec, 2nd Coy, 614th Bn, 793rd AFAD & Arty Bde",
    wpnCurrent = 48,
    wpnDefault = 48,
    unitCount = 1,
    operationalArea = constants.OPERATIONAL_AREAS.FMK,
    state = constants.MISSILE_SYSTEM_STATE.STATIC,
    ammunition = "Ammo Revetment, 2nd Coy, 614th Bn, 793rd AFAD & Arty Bde",
    firingUnit = "2nd Coy, 614th Bn, 793rd AFAD & Arty Bde"
  },
  ["Ammo Sec, 2nd Coy, 631st Bn, 793rd AFAD & Arty Bde"] = {
    guid = "",
    name = "Ammo Sec, 2nd Coy, 631st Bn, 793rd AFAD & Arty Bde",
    wpnCurrent = config.t.ground.sam.wpnDefault,
    wpnDefault = config.t.ground.sam.wpnDefault,
    unitCount = 1,
    operationalArea = constants.OPERATIONAL_AREAS.XDY,
    state = constants.MISSILE_SYSTEM_STATE.STATIC,
    ammunition = "Ammo Revetment, 2nd Coy, 631st Bn, 793rd AFAD & Arty Bde",
    firingUnit = "2nd Coy, 631st Bn, 793rd AFAD & Arty Bde"
  },
  ["Ammo Sec, 2nd Coy, 632nd Bn, 794th AFAD & Arty Bde"] = {
    guid = "",
    name = "Ammo Sec, 2nd Coy, 632nd Bn, 794th AFAD & Arty Bde",
    wpnCurrent = config.t.ground.sam.wpnDefault,
    wpnDefault = config.t.ground.sam.wpnDefault,
    unitCount = 1,
    operationalArea = constants.OPERATIONAL_AREAS.DJA,
    state = constants.MISSILE_SYSTEM_STATE.STATIC,
    ammunition = "Ammo Revetment, 2nd Coy, 632nd Bn, 794th AFAD & Arty Bde",
    firingUnit = "2nd Coy, 632nd Bn, 794th AFAD & Arty Bde"
  },
  ["Ammo Sec, 2nd Coy, 633rd Bn, 795th AFAD & Arty Bde"] = {
    guid = "",
    name = "Ammo Sec, 2nd Coy, 633rd Bn, 795th AFAD & Arty Bde",
    wpnCurrent = config.t.ground.sam.wpnDefault,
    wpnDefault = config.t.ground.sam.wpnDefault,
    unitCount = 1,
    operationalArea = constants.OPERATIONAL_AREAS.GRV,
    state = constants.MISSILE_SYSTEM_STATE.STATIC,
    ammunition = "Ammo Revetment, 2nd Coy, 633rd Bn, 795th AFAD & Arty Bde",
    firingUnit = "2nd Coy, 633rd Bn, 795th AFAD & Arty Bde"
  },
  ["Ammo Sec, 3rd Coy, 613rd Bn, 792nd AFAD & Arty Bde"] = {
    guid = "",
    name = "Ammo Sec, 3rd Coy, 613rd Bn, 792nd AFAD & Arty Bde",
    wpnCurrent = 48,
    wpnDefault = 48,
    unitCount = 1,
    operationalArea = constants.OPERATIONAL_AREAS.PXV,
    state = constants.MISSILE_SYSTEM_STATE.STATIC,
    ammunition = "Ammo Revetment, 3rd Coy, 613rd Bn, 792nd AFAD & Arty Bde",
    firingUnit = "3rd Coy, 613rd Bn, 792nd AFAD & Arty Bde"
  },
  ["Ammo Sec, 3rd Coy, 614th Bn, 793rd AFAD & Arty Bde"] = {
    guid = "",
    name = "Ammo Sec, 3rd Coy, 614th Bn, 793rd AFAD & Arty Bde",
    wpnCurrent = 48,
    wpnDefault = 48,
    unitCount = 1,
    operationalArea = constants.OPERATIONAL_AREAS.IDW,
    state = constants.MISSILE_SYSTEM_STATE.STATIC,
    ammunition = "Ammo Revetment, 3rd Coy, 614th Bn, 793rd AFAD & Arty Bde",
    firingUnit = "3rd Coy, 614th Bn, 793rd AFAD & Arty Bde"
  },
  ["Ammo Sec, 3rd Coy, 631st Bn, 793rd AFAD & Arty Bde"] = {
    guid = "",
    name = "Ammo Sec, 3rd Coy, 631st Bn, 793rd AFAD & Arty Bde",
    wpnCurrent = config.t.ground.sam.wpnDefault,
    wpnDefault = config.t.ground.sam.wpnDefault,
    unitCount = 1,
    operationalArea = constants.OPERATIONAL_AREAS.CSC,
    state = constants.MISSILE_SYSTEM_STATE.STATIC,
    ammunition = "Ammo Revetment, 3rd Coy, 631st Bn, 793rd AFAD & Arty Bde",
    firingUnit = "3rd Coy, 631st Bn, 793rd AFAD & Arty Bde"
  },
  ["Ammo Sec, 3rd Coy, 632nd Bn, 794th AFAD & Arty Bde"] = {
    guid = "",
    name = "Ammo Sec, 3rd Coy, 632nd Bn, 794th AFAD & Arty Bde",
    wpnCurrent = config.t.ground.sam.wpnDefault,
    wpnDefault = config.t.ground.sam.wpnDefault,
    unitCount = 1,
    operationalArea = constants.OPERATIONAL_AREAS.RHM,
    state = constants.MISSILE_SYSTEM_STATE.STATIC,
    ammunition = "Ammo Revetment, 3rd Coy, 632nd Bn, 794th AFAD & Arty Bde",
    firingUnit = "3rd Coy, 632nd Bn, 794th AFAD & Arty Bde"
  },
  ["Ammo Sec, 3rd Coy, 633rd Bn, 795th AFAD & Arty Bde"] = {
    guid = "",
    name = "Ammo Sec, 3rd Coy, 633rd Bn, 795th AFAD & Arty Bde",
    wpnCurrent = config.t.ground.sam.wpnDefault,
    wpnDefault = config.t.ground.sam.wpnDefault,
    unitCount = 1,
    operationalArea = constants.OPERATIONAL_AREAS.UYO,
    state = constants.MISSILE_SYSTEM_STATE.STATIC,
    ammunition = "Ammo Revetment, 3rd Coy, 633rd Bn, 795th AFAD & Arty Bde",
    firingUnit = "3rd Coy, 633rd Bn, 795th AFAD & Arty Bde"
  },
}
config.t.ground.sam.firingUnits = {
  ["1st Coy, 613rd Bn, 792nd AFAD & Arty Bde"] = {
    guid = "",
    name = "1st Coy, 613rd Bn, 792nd AFAD & Arty Bde",
    state = constants.MISSILE_SYSTEM_STATE.STATIC,
    operationalArea = constants.OPERATIONAL_AREAS.IKJ,
    weaponDBID = constants.WEAPONS.TK3,
    ammoThreshold = config.t.ground.sam.ammoThreshold,
    resupplyUnit = "Ammo Sec, 1st Coy, 613rd Bn, 792nd AFAD & Arty Bde",
    dbid = constants.PLATFORMS.CUSTOMED_SAM,
    mountDescriptors = constants.MOUNT_DESCRIPTORS.CUSTOMED_TK3,
  },
  ["1st Coy, 614th Bn, 793rd AFAD & Arty Bde"] = {
    guid = "",
    name = "1st Coy, 614th Bn, 793rd AFAD & Arty Bde",
    state = constants.MISSILE_SYSTEM_STATE.STATIC,
    operationalArea = constants.OPERATIONAL_AREAS.UVY,
    weaponDBID = constants.WEAPONS.TK3,
    ammoThreshold = config.t.ground.sam.ammoThreshold,
    resupplyUnit = "Ammo Sec, 1st Coy, 614th Bn, 793rd AFAD & Arty Bde",
    dbid = constants.PLATFORMS.CUSTOMED_SAM,
    mountDescriptors = constants.MOUNT_DESCRIPTORS.CUSTOMED_TK3,
  },
  ["1st Coy, 631st Bn, 793rd AFAD & Arty Bde"] = {
    guid = "",
    name = "1st Coy, 631st Bn, 793rd AFAD & Arty Bde",
    state = constants.MISSILE_SYSTEM_STATE.STATIC,
    operationalArea = constants.OPERATIONAL_AREAS.QPF,
    weaponDBID = { constants.WEAPONS.MIM104F_PAC3, constants.WEAPONS.MIM104F_PAC2 },
    ammoThreshold = config.t.ground.sam.ammoThreshold,
    resupplyUnit = "Ammo Sec, 1st Coy, 631st Bn, 793rd AFAD & Arty Bde",
    dbid = constants.PLATFORMS.PAC3,
  },
  ["1st Coy, 632nd Bn, 794th AFAD & Arty Bde"] = {
    guid = "",
    name = "1st Coy, 632nd Bn, 794th AFAD & Arty Bde",
    state = constants.MISSILE_SYSTEM_STATE.STATIC,
    operationalArea = constants.OPERATIONAL_AREAS.NUJ,
    weaponDBID = { constants.WEAPONS.MIM104F_PAC3, constants.WEAPONS.MIM104F_PAC2 },
    ammoThreshold = config.t.ground.sam.ammoThreshold,
    resupplyUnit = "Ammo Sec, 1st Coy, 632nd Bn, 794th AFAD & Arty Bde",
    dbid = constants.PLATFORMS.PAC3,
  },
  ["1st Coy, 633rd Bn, 795th AFAD & Arty Bde"] = {
    guid = "",
    name = "1st Coy, 633rd Bn, 795th AFAD & Arty Bde",
    state = constants.MISSILE_SYSTEM_STATE.STATIC,
    operationalArea = constants.OPERATIONAL_AREAS.QTZ,
    weaponDBID = { constants.WEAPONS.MIM104F_PAC3, constants.WEAPONS.MIM104F_PAC2 },
    ammoThreshold = config.t.ground.sam.ammoThreshold,
    resupplyUnit = "Ammo Sec, 1st Coy, 633rd Bn, 795th AFAD & Arty Bde",
    dbid = constants.PLATFORMS.PAC3,
  },
  ["2nd Coy, 613rd Bn, 792nd AFAD & Arty Bde"] = {
    guid = "",
    name = "2nd Coy, 613rd Bn, 792nd AFAD & Arty Bde",
    state = constants.MISSILE_SYSTEM_STATE.STATIC,
    operationalArea = constants.OPERATIONAL_AREAS.MAK,
    weaponDBID = constants.WEAPONS.TK3,
    ammoThreshold = config.t.ground.sam.ammoThreshold,
    resupplyUnit = "Ammo Sec, 2nd Coy, 613rd Bn, 792nd AFAD & Arty Bde",
    dbid = constants.PLATFORMS.CUSTOMED_SAM,
    mountDescriptors = constants.MOUNT_DESCRIPTORS.CUSTOMED_TK3,
  },
  ["2nd Coy, 614th Bn, 793rd AFAD & Arty Bde"] = {
    guid = "",
    name = "2nd Coy, 614th Bn, 793rd AFAD & Arty Bde",
    state = constants.MISSILE_SYSTEM_STATE.STATIC,
    operationalArea = constants.OPERATIONAL_AREAS.FMK,
    weaponDBID = constants.WEAPONS.TK3,
    ammoThreshold = config.t.ground.sam.ammoThreshold,
    resupplyUnit = "Ammo Sec, 2nd Coy, 614th Bn, 793rd AFAD & Arty Bde",
    dbid = constants.PLATFORMS.CUSTOMED_SAM,
    mountDescriptors = constants.MOUNT_DESCRIPTORS.CUSTOMED_TK3,
  },
  ["2nd Coy, 631st Bn, 793rd AFAD & Arty Bde"] = {
    guid = "",
    name = "2nd Coy, 631st Bn, 793rd AFAD & Arty Bde",
    state = constants.MISSILE_SYSTEM_STATE.STATIC,
    operationalArea = constants.OPERATIONAL_AREAS.XDY,
    weaponDBID = { constants.WEAPONS.MIM104F_PAC3, constants.WEAPONS.MIM104F_PAC2 },
    ammoThreshold = config.t.ground.sam.ammoThreshold,
    resupplyUnit = "Ammo Sec, 2nd Coy, 631st Bn, 793rd AFAD & Arty Bde",
    dbid = constants.PLATFORMS.PAC3,
  },
  ["2nd Coy, 632nd Bn, 794th AFAD & Arty Bde"] = {
    guid = "",
    name = "2nd Coy, 632nd Bn, 794th AFAD & Arty Bde",
    state = constants.MISSILE_SYSTEM_STATE.STATIC,
    operationalArea = constants.OPERATIONAL_AREAS.DJA,
    weaponDBID = { constants.WEAPONS.MIM104F_PAC3, constants.WEAPONS.MIM104F_PAC2 },
    ammoThreshold = config.t.ground.sam.ammoThreshold,
    resupplyUnit = "Ammo Sec, 2nd Coy, 632nd Bn, 794th AFAD & Arty Bde",
    dbid = constants.PLATFORMS.PAC3,
  },
  ["2nd Coy, 633rd Bn, 795th AFAD & Arty Bde"] = {
    guid = "",
    name = "2nd Coy, 633rd Bn, 795th AFAD & Arty Bde",
    state = constants.MISSILE_SYSTEM_STATE.STATIC,
    operationalArea = constants.OPERATIONAL_AREAS.GRV,
    weaponDBID = { constants.WEAPONS.MIM104F_PAC3, constants.WEAPONS.MIM104F_PAC2 },
    ammoThreshold = config.t.ground.sam.ammoThreshold,
    resupplyUnit = "Ammo Sec, 2nd Coy, 633rd Bn, 795th AFAD & Arty Bde",
    dbid = constants.PLATFORMS.PAC3,
  },
  ["3rd Coy, 613rd Bn, 792nd AFAD & Arty Bde"] = {
    guid = "",
    name = "3rd Coy, 613rd Bn, 792nd AFAD & Arty Bde",
    state = constants.MISSILE_SYSTEM_STATE.STATIC,
    operationalArea = constants.OPERATIONAL_AREAS.PXV,
    weaponDBID = constants.WEAPONS.TK3,
    ammoThreshold = config.t.ground.sam.ammoThreshold,
    resupplyUnit = "Ammo Sec, 3rd Coy, 613rd Bn, 792nd AFAD & Arty Bde",
    dbid = constants.PLATFORMS.CUSTOMED_SAM,
    mountDescriptors = constants.MOUNT_DESCRIPTORS.CUSTOMED_TK3,
  },
  ["3rd Coy, 614th Bn, 793rd AFAD & Arty Bde"] = {
    guid = "",
    name = "3rd Coy, 614th Bn, 793rd AFAD & Arty Bde",
    state = constants.MISSILE_SYSTEM_STATE.STATIC,
    operationalArea = constants.OPERATIONAL_AREAS.IDW,
    weaponDBID = constants.WEAPONS.TK3,
    ammoThreshold = config.t.ground.sam.ammoThreshold,
    resupplyUnit = "Ammo Sec, 3rd Coy, 614th Bn, 793rd AFAD & Arty Bde",
    dbid = constants.PLATFORMS.CUSTOMED_SAM,
    mountDescriptors = constants.MOUNT_DESCRIPTORS.CUSTOMED_TK3,
  },
  ["3rd Coy, 631st Bn, 793rd AFAD & Arty Bde"] = {
    guid = "",
    name = "3rd Coy, 631st Bn, 793rd AFAD & Arty Bde",
    state = constants.MISSILE_SYSTEM_STATE.STATIC,
    operationalArea = constants.OPERATIONAL_AREAS.CSC,
    weaponDBID = { constants.WEAPONS.MIM104F_PAC3, constants.WEAPONS.MIM104F_PAC2 },
    ammoThreshold = config.t.ground.sam.ammoThreshold,
    resupplyUnit = "Ammo Sec, 3rd Coy, 631st Bn, 793rd AFAD & Arty Bde",
    dbid = constants.PLATFORMS.PAC3,
  },
  ["3rd Coy, 632nd Bn, 794th AFAD & Arty Bde"] = {
    guid = "",
    name = "3rd Coy, 632nd Bn, 794th AFAD & Arty Bde",
    state = constants.MISSILE_SYSTEM_STATE.STATIC,
    operationalArea = constants.OPERATIONAL_AREAS.RHM,
    weaponDBID = { constants.WEAPONS.MIM104F_PAC3, constants.WEAPONS.MIM104F_PAC2 },
    ammoThreshold = config.t.ground.sam.ammoThreshold,
    resupplyUnit = "Ammo Sec, 3rd Coy, 632nd Bn, 794th AFAD & Arty Bde",
    dbid = constants.PLATFORMS.PAC3,
  },
  ["3rd Coy, 633rd Bn, 795th AFAD & Arty Bde"] = {
    guid = "",
    name = "3rd Coy, 633rd Bn, 795th AFAD & Arty Bde",
    state = constants.MISSILE_SYSTEM_STATE.STATIC,
    operationalArea = constants.OPERATIONAL_AREAS.UYO,
    weaponDBID = { constants.WEAPONS.MIM104F_PAC3, constants.WEAPONS.MIM104F_PAC2 },
    ammoThreshold = config.t.ground.sam.ammoThreshold,
    resupplyUnit = "Ammo Sec, 3rd Coy, 633rd Bn, 795th AFAD & Arty Bde",
    dbid = constants.PLATFORMS.PAC3,
  },
}

-- ============================================================================
-- IADS (Taiwan)
-- ============================================================================

config.t.iads = {}
config.t.iads.ratio = { ROCC = 1.5, TAAOC = 1.5 }
config.t.iads.rocc = {
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
config.t.iads.taaoc = {
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

config.t.air = {}
config.t.air.landBased = {}
config.t.air.landBased.wpnNum = 8
config.t.air.landBased.deployedACs = {
  {
    name = "Ching Chuang Kang AB",
    baseGUID = constants.BASES.CHING_CHUANG_KANG_AB,
    embarkedUnits = {
      {
        side = constants.SIDES.PLAYER,
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
        side = constants.SIDES.PLAYER,
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
        side = constants.SIDES.PLAYER,
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
        side = constants.SIDES.PLAYER,
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
        side = constants.SIDES.PLAYER,
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
        side = constants.SIDES.PLAYER,
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
        side = constants.SIDES.PLAYER,
        type = "Air",
        dbid = constants.PLATFORMS.P3C,
        platformName = "P-3C",
        name = "6th Mixed Wing",
        loadouts = {
          { name = "ASW Patrol", loadoutId = constants.LOADOUTS.P3C_ASW, num = 3, missionName = "ASW/E" },
        }
      },
      {
        side = constants.SIDES.PLAYER,
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
        side = constants.SIDES.PLAYER,
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
        side = constants.SIDES.PLAYER,
        type = "Air",
        dbid = constants.PLATFORMS.MQ9B,
        platformName = "MQ-9B",
        name = "5th Tactical Mixed Wing",
        loadouts = {
          { name = "Reconnaissance", loadoutId = constants.LOADOUTS.MQ9B_RECON, num = 3, missionName = "AEW/S" },
        }
      },
      {
        side = constants.SIDES.PLAYER,
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
        side = constants.SIDES.PLAYER,
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
        side = constants.SIDES.PLAYER,
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
        side = constants.SIDES.PLAYER,
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
            side = constants.SIDES.PLAYER,
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
            side = constants.SIDES.PLAYER,
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
        side = constants.SIDES.PLAYER,
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

config.u.sigint = {}
config.u.sigint.maxCount = config.c.sigint.maxCount
config.u.sigint.maxRange = config.c.sigint.maxRange

-- Detection parameters (shared with China)
config.u.sigint.detectionThreshold = config.c.sigint.detectionThreshold
config.u.sigint.maxDetectionRange = config.c.sigint.maxDetectionRange

-- Detection formula constants (shared with China)
config.u.sigint.formulaConstants = config.c.sigint.formulaConstants

-- Default display configuration (shared with China)
config.u.sigint.defaultDisplay = config.c.sigint.defaultDisplay

-- Area and performance parameters (shared with China)
config.u.sigint.minPolygonPoints = config.c.sigint.minPolygonPoints
config.u.sigint.detectionSkipProbability = config.c.sigint.detectionSkipProbability


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
