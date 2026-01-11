local config = require("src.core.config")
local constants = require("src.core.constants")

---@class SBJ__SaveData
local saveData = {}
saveData.c = {}
saveData.c.targetlist = {}
saveData.t = {}
saveData.u = {}
saveData.s = {}


-- ============================================================================
-- SIGINT (China)
-- ============================================================================

saveData.c.SIGINT = {}
saveData.c.SIGINT.isActivated = true
saveData.c.SIGINT.maxCount = config.c.SIGINT.maxCount
saveData.c.SIGINT.RA = {}
saveData.c.SIGINT.transmissions = {}


-- ============================================================================
-- IADS (China)
-- ============================================================================

saveData.c.IADS = {}
saveData.c.IADS.isActivated = true
saveData.c.IADS.C2 = {}


-- ============================================================================
-- Communications Jamming (China)
-- ============================================================================

saveData.c.commsJamming = {}
saveData.c.commsJamming.isActivated = true
saveData.c.commsJamming.jammers = {}


-- ============================================================================
-- GPS Jamming (China)
-- ============================================================================

saveData.c.GPSJamming = {}
saveData.c.GPSJamming.isActivated = true
saveData.c.GPSJamming.jammers = {
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

saveData.c.ground = {}
saveData.c.ground.mlrs = {}
saveData.c.ground.mlrs.isActivated = true
saveData.c.ground.mlrs.reloadTime = config.c.ground.mlrs.reloadTime
saveData.c.ground.mlrs.operationalAreas = config.c.ground.mlrs.operationalAreas
saveData.c.ground.mlrs.ammunitions = {}
saveData.c.ground.mlrs.resupplyUnits = {}
saveData.c.ground.mlrs.firingUnits = {}


-- ============================================================================
-- GLCM (China)
-- ============================================================================

saveData.c.ground.glcm = {}
saveData.c.ground.glcm.isActivated = true
saveData.c.ground.glcm.reloadTime = config.c.ground.glcm.reloadTime
saveData.c.ground.glcm.operationalAreas = config.c.ground.glcm.operationalAreas
saveData.c.ground.glcm.ammunitions = {}
saveData.c.ground.glcm.resupplyUnits = {}
saveData.c.ground.glcm.firingUnits = {}


-- ============================================================================
-- SRBM (China)
-- ============================================================================

saveData.c.ground.srbm = {}
saveData.c.ground.srbm.isActivated = true
saveData.c.ground.srbm.reloadTime = config.c.ground.srbm.reloadTime
saveData.c.ground.srbm.operationalAreas = config.c.ground.srbm.operationalAreas
saveData.c.ground.srbm.ammunitions = {}
saveData.c.ground.srbm.resupplyUnits = {}
saveData.c.ground.srbm.firingUnits = {}


-- ============================================================================
-- MRBM (China)
-- ============================================================================

saveData.c.ground.mrbm = {}
saveData.c.ground.mrbm.isActivated = true
saveData.c.ground.mrbm.reloadTime = config.c.ground.mrbm.reloadTime
saveData.c.ground.mrbm.operationalAreas = config.c.ground.mrbm.operationalAreas
saveData.c.ground.mrbm.ammunitions = {}
saveData.c.ground.mrbm.resupplyUnits = {}
saveData.c.ground.mrbm.firingUnits = {}


-- ============================================================================
-- Reconnaissance (China)
-- ============================================================================

saveData.c.recon = {}
saveData.c.recon.isActivated = true
saveData.c.recon.queue = {
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
    hasLaunched = false,
    isTracking = true,
    isFinished = false,
    trackingTargetGUID = nil,
    speed = 450
  },
  {
    type = "satellite",
    endTime = "2027-06-09 01:00:00",
    -- endTime = "2027-06-09 04:40:00",
    isFinished = false,
  },
  {
    type = "satellite",
    -- endTime = "2027-06-09 01:00:00",
    endTime = "2027-06-09 05:44:00",
    isFinished = false,
  },
  {
    type = "satellite",
    -- endTime = "2027-06-09 01:30:00",
    endTime = "2027-06-09 08:04:00",
    isFinished = false,
  },
  {
    type = "satellite",
    endTime = "2027-06-09 11:25:00",
    isFinished = false,
  },
}
saveData.c.recon.reconStrikeMatrix = {
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

-- ============================================================================
-- Fire Support Plan (China)
-- ============================================================================

saveData.c.ground.isActivated = true
saveData.c.ground.FSP = {}


-- ============================================================================
-- Air Tasking Order (China)
-- ============================================================================

saveData.c.air = {}
saveData.c.air.landBased = {}
saveData.c.air.shipBased = {}
saveData.c.air.isActivated = true
saveData.c.air.ATO = {}



-- ============================================================================
-- Amphibious Operations (China)
-- ============================================================================

saveData.c.PHIBOP = {}
saveData.c.PHIBOP.startTime = config.c.triggers.amphibiousOps.startTime
saveData.c.PHIBOP.isTesting = true
saveData.c.PHIBOP.isShipsStartedMoving = true
saveData.c.PHIBOP.isWaitingForShipArrival = false
saveData.c.PHIBOP.amphibiousAssaultStartTime = nil
saveData.c.PHIBOP.isWaitingForAmphibiousAssault = false
saveData.c.PHIBOP.isWaitingForSecondWaveUnloading = false
saveData.c.PHIBOP.airlandingMissionStartTime = nil
saveData.c.PHIBOP.calculationResult = {
  ["Taoyuan"] = {
    name = "Taoyuan",
    result = {
      type075 = { locations = {}, locationIndex = 1, dbid = constants.PLATFORMS.TYPE_075, },
      type071 = { locations = {}, locationIndex = 1, dbid = constants.PLATFORMS.TYPE_071, },
      type076 = { locations = {}, locationIndex = 1, dbid = constants.PLATFORMS.TYPE_076, },
      type072iii = { locations = {}, locationIndex = 1, dbid = constants.PLATFORMS.TYPE_072III, },
      type072a = { locations = {}, locationIndex = 1, dbid = constants.PLATFORMS.TYPE_072A, },
      type073a = { locations = {}, locationIndex = 1, dbid = constants.PLATFORMS.TYPE_073A, },
      type071InLSTArea = { locations = {}, locationIndex = 1, dbid = constants.PLATFORMS.TYPE_071, },
      ferry = { locations = {}, locationIndex = 1, dbid = constants.PLATFORMS.FERRY, },
      roro = { locations = {}, locationIndex = 1, dbid = constants.PLATFORMS.FERRY, },
      barge = { locations = {}, locationIndex = 1, dbid = constants.PLATFORMS.BARGE, },
    }
  },
  ["Penghu"] = {
    name = "Penghu",
    result = {
      type075 = { locations = {}, locationIndex = 1, dbid = constants.PLATFORMS.TYPE_075, },
      type071 = { locations = {}, locationIndex = 1, dbid = constants.PLATFORMS.TYPE_071, },
      type076 = { locations = {}, locationIndex = 1, dbid = constants.PLATFORMS.TYPE_076, },
      type072iii = { locations = {}, locationIndex = 1, dbid = constants.PLATFORMS.TYPE_072III, },
      type072a = { locations = {}, locationIndex = 1, dbid = constants.PLATFORMS.TYPE_072A, },
      type073a = { locations = {}, locationIndex = 1, dbid = constants.PLATFORMS.TYPE_073A, },
      type071InLSTArea = { locations = {}, locationIndex = 1, dbid = constants.PLATFORMS.TYPE_071, },
      ferry = { locations = {}, locationIndex = 1, dbid = constants.PLATFORMS.FERRY, },
      roro = { locations = {}, locationIndex = 1, dbid = constants.PLATFORMS.FERRY, },
      barge = { locations = {}, locationIndex = 1, dbid = constants.PLATFORMS.BARGE, },
    }
  },
  ["Sishu"] = {
    name = "Sishu",
    result = {
      type075 = { locations = {}, locationIndex = 1, dbid = constants.PLATFORMS.TYPE_075, },
      type071 = { locations = {}, locationIndex = 1, dbid = constants.PLATFORMS.TYPE_071, },
      type076 = { locations = {}, locationIndex = 1, dbid = constants.PLATFORMS.TYPE_076, },
      type072iii = { locations = {}, locationIndex = 1, dbid = constants.PLATFORMS.TYPE_072III, },
      type072a = { locations = {}, locationIndex = 1, dbid = constants.PLATFORMS.TYPE_072A, },
      type073a = { locations = {}, locationIndex = 1, dbid = constants.PLATFORMS.TYPE_073A, },
      type071InLSTArea = { locations = {}, locationIndex = 1, dbid = constants.PLATFORMS.TYPE_071, },
      ferry = { locations = {}, locationIndex = 1, dbid = constants.PLATFORMS.FERRY, },
      roro = { locations = {}, locationIndex = 1, dbid = constants.PLATFORMS.FERRY, },
      barge = { locations = {}, locationIndex = 1, dbid = constants.PLATFORMS.BARGE, },
    }
  },
}
saveData.c.PHIBOP.barges = {}


-- ============================================================================
-- Land Attack Cruise Missiles - Surface Launch (China)
-- ============================================================================

saveData.c.surface = {}
saveData.c.surface.lacm = {}
saveData.c.surface.lacm.isActivated = false
saveData.c.surface.lacm.startTime = config.c.triggers.launchLACM.startTime


-- ============================================================================
-- Submarine-Launched Cruise Missiles (China)
-- ============================================================================

saveData.c.subSurface = {}
saveData.c.subSurface.slcm = {}
saveData.c.subSurface.slcm.isActivated = true
saveData.c.subSurface.slcm.startTime = config.c.triggers.launchSLCM.startTime


-- ============================================================================
-- Runway Repair (China)
-- ============================================================================

saveData.c.repairRunway = {}
saveData.c.repairRunway.isActivated = false
saveData.c.repairRunway.runways = {}


-- ============================================================================
-- Ground Forces (Taiwan)
-- ============================================================================

saveData.t.ground = {}
saveData.t.ground.isActivated = true


-- ============================================================================
-- MLRS (Taiwan)
-- ============================================================================

saveData.t.ground.mlrs = {}
saveData.t.ground.mlrs.isActivated = true
saveData.t.ground.mlrs.reloadTime = config.t.ground.mlrs.reloadTime
saveData.t.ground.mlrs.operationalAreas = config.t.ground.mlrs.operationalAreas
saveData.t.ground.mlrs.ammunitions = {}
saveData.t.ground.mlrs.resupplyUnits = {}
saveData.t.ground.mlrs.firingUnits = {}


-- ============================================================================
-- SRBM (Taiwan)
-- ============================================================================

saveData.t.ground.srbm = {}
saveData.t.ground.srbm.isActivated = true
saveData.t.ground.srbm.reloadTime = config.t.ground.srbm.reloadTime
saveData.t.ground.srbm.operationalAreas = config.t.ground.srbm.operationalAreas
saveData.t.ground.srbm.ammunitions = {}
saveData.t.ground.srbm.resupplyUnits = {}
saveData.t.ground.srbm.firingUnits = {}



-- ============================================================================
-- GLCM (Taiwan)
-- ============================================================================

saveData.t.ground.glcm = {}
saveData.t.ground.glcm.isActivated = true
saveData.t.ground.glcm.reloadTime = config.t.ground.glcm.reloadTime
saveData.t.ground.glcm.operationalAreas = config.t.ground.glcm.operationalAreas
saveData.t.ground.glcm.ammunitions = {}
saveData.t.ground.glcm.resupplyUnits = {}
saveData.t.ground.glcm.firingUnits = {}




-- ============================================================================
-- ASCM (Taiwan)
-- ============================================================================

saveData.t.ground.ascm = {}
saveData.t.ground.ascm.isActivated = true
saveData.t.ground.ascm.reloadTime = config.t.ground.ascm.reloadTime
saveData.t.ground.ascm.operationalAreas = config.t.ground.ascm.operationalAreas
saveData.t.ground.ascm.ammunitions = {}
saveData.t.ground.ascm.resupplyUnits = {}
saveData.t.ground.ascm.firingUnits = {}
saveData.t.ground.ascm.test = {
  isAntishipMissionActivated = false,
  nai1 = constants.AREAS.groundAscmTestNai1,
  nai2 = constants.AREAS.groundAscmTestNai2,
  shipNumInNai1 = 4,
  helicopterNumInNai2 = 4
}


-- ============================================================================
-- Runway Repair (Taiwan)
-- ============================================================================

saveData.t.repairRunway = {}
saveData.t.repairRunway.isActivated = false
saveData.t.repairRunway.runways = {}


-- ============================================================================
-- IADS (Taiwan)
-- ============================================================================

saveData.t.IADS = {}
saveData.t.IADS.isActivated = true
saveData.t.IADS.ROCC = {
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
saveData.t.IADS.TAAOC = {
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
-- Aircraft (Taiwan)
-- ============================================================================

saveData.t.air = {}
saveData.t.air.landBased = {}
saveData.t.air.landBased.AEW = {}
saveData.t.air.landBased.AC = {}


-- ============================================================================
-- GPS Jamming (Taiwan)
-- ============================================================================

saveData.t.GPSJamming = {}
saveData.t.GPSJamming.jammers = {
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
-- SIGINT (US)
-- ============================================================================

saveData.u.SIGINT = {}
saveData.u.SIGINT.isActivated = true
saveData.u.SIGINT.maxCount = config.u.SIGINT.maxCount
saveData.u.SIGINT.RA = {}
saveData.u.SIGINT.transmissions = {}


-- ============================================================================
-- Dynamic Operations (China)
-- ============================================================================

saveData.c.dynamicOperations = {}
saveData.c.dynamicOperations.enabled = true
saveData.c.dynamicOperations.lastEvaluationTime = nil
saveData.c.dynamicOperations.generatedOperations = {
  air = {},   -- Track generated air operations
  ground = {} -- Track generated ground operations
}
saveData.c.dynamicOperations.reconSchedule = {
  -- {
  --   -- time = "2027-06-09 02:14:00",
  --   time = "2027-06-09 01:00:00",
  --   type = "satellite",
  --   delay = 0,
  --   executed = false,
  --   operations = {
  --     {
  --       type = "air",
  --       executed = false,
  --       template = {
  --         name = "STRIKE/AB/W/1",
  --         isFirstWave = true,
  --         strikeInterval = 30 * 60,
  --         packages = config.c.packageTemplate.STRIKE_AB_W_1
  --       }
  --     },
  --     -- {
  --     --   type = "air",
  --     --   executed = false,
  --     --   template = {
  --     --     name = "STRIKE/AB/W/AAR/1",
  --     --     isFirstWave = true,
  --     --     strikeInterval = 30 * 60,
  --     --     packages = config.c.packageTemplate.STRIKE_AB_W_AAR_1
  --     --   }
  --     -- },
  --     {
  --       type = "ground",
  --       executed = false,
  --       template = {
  --         name = "STRIKE/INFRASTRUCTURE/1",
  --         strikeInterval = 0,
  --         isFirstWave = true,
  --         FSTs = config.c.FSTTemplate.STRIKE_INFRASTRUCTURE_1
  --       }
  --     },
  --     {
  --       type = "ground",
  --       executed = false,
  --       template = {
  --         name = "STRIKE/HELIPAD/1",
  --         strikeInterval = 0,
  --         isFirstWave = true,
  --         FSTs = config.c.FSTTemplate.STRIKE_HELIPAD_1
  --       }
  --     }
  --   }
  -- },
  -- {
  --   -- time = "2027-06-09 03:00:00",
  --   time = "2027-06-09 02:14:00",
  --   type = "satellite",
  --   delay = 0,
  --   executed = false,
  --   operations = {
  --     {
  --       type = "air",
  --       executed = false,
  --       template = {
  --         name = "STRIKE/AB/W/2",
  --         isFirstWave = false,
  --         strikeInterval = 30 * 60,
  --         packages = config.c.packageTemplate.STRIKE_AB_W_2
  --       }
  --     },
  --     {
  --       type = "ground",
  --       executed = false,
  --       template = {
  --         name = "STRIKE/INFRASTRUCTURE/2",
  --         strikeInterval = 0,
  --         isFirstWave = false,
  --         FSTs = config.c.FSTTemplate.STRIKE_INFRASTRUCTURE_2
  --       }
  --     },
  --     {
  --       type = "ground",
  --       executed = false,
  --       template = {
  --         name = "ANTISHIP/1",
  --         strikeInterval = 0,
  --         isFirstWave = false,
  --         FSTs = config.c.FSTTemplate.ANTISHIP
  --       }
  --     },
  --     {
  --       type = "ground",
  --       executed = false,
  --       template = {
  --         name = "STRIKE/C2/1",
  --         strikeInterval = 0,
  --         isFirstWave = false,
  --         FSTs = config.c.FSTTemplate.STRIKE_C2
  --       }
  --     }
  --   }
  -- },
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
  --         isFirstWave = true,
  --         strikeInterval = 30 * 60,
  --         packages = config.c.packageTemplate.AIR_INTERCEPT_E
  --       }
  --     }
  --   }
  -- },
  -- {
  --   time = "2027-06-09 05:44:00",
  --   type = "satellite",
  --   delay = 0,
  --   executed = false,
  --   operations = {}
  -- },
  -- {
  --   time = "2027-06-09 08:04:00",
  --   type = "satellite",
  --   delay = 0,
  --   executed = false,
  --   operations = {}
  -- },
  -- {
  --   time = "2027-06-09 11:25:00",
  --   type = "satellite",
  --   delay = 0,
  --   executed = false,
  --   operations = {}
  -- }
}

return saveData
