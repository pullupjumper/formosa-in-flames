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

---@type SBJ__SIGINTContext
saveData.c.SIGINT = {}
saveData.c.SIGINT.isActivated = true
saveData.c.SIGINT.maxCount = config.c.SIGINT.maxCount
saveData.c.SIGINT.RA = {}
saveData.c.SIGINT.transmissions = {}


-- ============================================================================
-- IADS (China)
-- ============================================================================

---@type SBJ__IADSContext
saveData.c.IADS = {}
saveData.c.IADS.isActivated = true
saveData.c.IADS.C2 = {}


-- ============================================================================
-- Communications Jamming (China)
-- ============================================================================

---@type SBJ__CommsJammingContext
saveData.c.commsJamming = {}
saveData.c.commsJamming.isActivated = true
saveData.c.commsJamming.jammers = {}


-- ============================================================================
-- GPS Jamming (China)
-- ============================================================================

saveData.c.GPSJamming = {}
saveData.c.GPSJamming.isActivated = true
---@type table<string, SBJ__GPSJammerDescriptor>
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
saveData.c.ground.mlrs.ammunitions = {
  ["IC8B0X-0HN9ASEFCGDKF"] = {
    guid = "IC8B0X-0HN9ASEFCGDKF",
    wpnCurrent = config.c.ground.mlrs.wpnDefault,
    wpnDefault = config.c.ground.mlrs.wpnDefault,
  },
  ["IC8B0X-0HNBRRE2PRT40"] = {
    guid = "IC8B0X-0HNBRRE2PRT40",
    wpnCurrent = config.c.ground.mlrs.wpnDefault,
    wpnDefault = config.c.ground.mlrs.wpnDefault,
  },
}
saveData.c.ground.mlrs.resupplyUnits = {
  ["IC8B0X-0HN7R5QOERV4D"] = {
    guid = "IC8B0X-0HN7R5QOERV4D",
    name = "Ammo Sec, 1st Bn, 1st Rockets Arty Bde",
    wpnCurrent = config.c.ground.mlrs.wpnDefault,
    wpnDefault = config.c.ground.mlrs.wpnDefault,
    unitCount = 3,
    operationalArea = config.c.ground.mlrs.operationalAreas.Pingtan,
    reloadStartTime = nil,
    state = config.batteryState.STATIC,
    ammunition = "IC8B0X-0HN9ASEFCGDKF",
  },
  ["IC8B0X-0HNBRRE2PRRG9"] = {
    guid = "IC8B0X-0HNBRRE2PRRG9",
    name = "Ammo Sec, 6th Bn, 73rd Arty Bde",
    wpnCurrent = config.c.ground.mlrs.wpnDefault,
    wpnDefault = config.c.ground.mlrs.wpnDefault,
    unitCount = 3,
    operationalArea = config.c.ground.mlrs.operationalAreas.Chinchew,
    reloadStartTime = nil,
    state = config.batteryState.STATIC,
    ammunition = "IC8B0X-0HNBRRE2PRT40",
  },
}
saveData.c.ground.mlrs.firingUnits = {
  ["IC8B0X-0HND05GGU36EN"] = {
    name = "1st Bn, 1st Rockets Arty Bde",
    msg = "Radio source, Bty",
    guid = "IC8B0X-0HND05GGU36EN",
    reloadStartTime = nil,
    state = config.batteryState.HIDE,
    operationalArea = config.c.ground.mlrs.operationalAreas.Pingtan,
    weaponDBID = constants.WEAPONS.FD280,
    ammoThreshold = config.c.ground.mlrs.ammoThreshold,
    resupplyUnit = "IC8B0X-0HN7R5QOERV4D",
  },
  ["IC8B0X-0HNBRRE2PRQAL"] = {
    name = "6th Bn, 73rd Arty Bde",
    msg = "Radio source, Bty",
    guid = "IC8B0X-0HNBRRE2PRQAL",
    reloadStartTime = nil,
    state = config.batteryState.HIDE,
    operationalArea = config.c.ground.mlrs.operationalAreas.Chinchew,
    weaponDBID = constants.WEAPONS.FD280,
    ammoThreshold = config.c.ground.mlrs.ammoThreshold,
    resupplyUnit = "IC8B0X-0HNBRRE2PRRG9",
  },
}


-- ============================================================================
-- GLCM (China)
-- ============================================================================

saveData.c.ground.glcm = {}
saveData.c.ground.glcm.isActivated = true
saveData.c.ground.glcm.reloadTime = config.c.ground.glcm.reloadTime
saveData.c.ground.glcm.operationalAreas = config.c.ground.glcm.operationalAreas
saveData.c.ground.glcm.ammunitions = {
  ["IC8B0X-0HN99I5RL5KR9"] = {
    guid = "IC8B0X-0HN99I5RL5KR9",
    wpnCurrent = config.c.ground.glcm.wpnDefault,
    wpnDefault = config.c.ground.glcm.wpnDefault,
  },
}
saveData.c.ground.glcm.resupplyUnits = {
  ["IC8B0X-0HN7R5QOIVG88"] = {
    guid = "IC8B0X-0HN7R5QOIVG88",
    name = "Ammo Sec, 635th Bde, PLARF",
    wpnCurrent = config.c.ground.glcm.wpnDefault,
    wpnDefault = config.c.ground.glcm.wpnDefault,
    unitCount = 8,
    operationalArea = config.c.ground.glcm.operationalAreas.Brigade635,
    reloadStartTime = nil,
    state = config.batteryState.STATIC,
    ammunition = "IC8B0X-0HN99I5RL5KR9",
  },
}
saveData.c.ground.glcm.firingUnits = {
  ["6Z8LM5-0HMN97ERAUODK"] = {
    guid = "6Z8LM5-0HMN97ERAUODK",
    name = "635th Bde, PLARF",
    msg = "Radio source, Bty",
    reloadStartTime = nil,
    state = config.batteryState.HIDE,
    operationalArea = config.c.ground.glcm.operationalAreas.Brigade635,
    weaponDBID = constants.WEAPONS.CJ10,
    ammoThreshold = config.c.ground.glcm.ammoThreshold,
    resupplyUnit = "IC8B0X-0HN7R5QOIVG88",
  },
}


-- ============================================================================
-- SRBM (China)
-- ============================================================================

saveData.c.ground.srbm = {}
saveData.c.ground.srbm.isActivated = true
saveData.c.ground.srbm.reloadTime = config.c.ground.srbm.reloadTime
saveData.c.ground.srbm.operationalAreas = config.c.ground.srbm.operationalAreas
saveData.c.ground.srbm.ammunitions = {
  ["IC8B0X-0HN9ASEFCG848"] = {
    guid = "IC8B0X-0HN9ASEFCG848",
    wpnCurrent = config.c.ground.srbm.wpnDefault * 2,
    wpnDefault = config.c.ground.srbm.wpnDefault * 2,
  },
  ["IC8B0X-0HN9ASEFCG95Q"] = {
    guid = "IC8B0X-0HN9ASEFCG95Q",
    wpnCurrent = config.c.ground.srbm.wpnDefault * 2,
    wpnDefault = config.c.ground.srbm.wpnDefault * 2,
  },
  ["IC8B0X-0HN9ASEFCG8CT"] = {
    guid = "IC8B0X-0HN9ASEFCG8CT",
    wpnCurrent = config.c.ground.srbm.wpnDefault * 2,
    wpnDefault = config.c.ground.srbm.wpnDefault * 2,
  },
  ["IC8B0X-0HN9ASEFCG8OK"] = {
    guid = "IC8B0X-0HN9ASEFCG8OK",
    wpnCurrent = config.c.ground.srbm.wpnDefault * 2,
    wpnDefault = config.c.ground.srbm.wpnDefault * 2,
  },
  ["IC8B0X-0HN9ASEFCG9GA"] = {
    guid = "IC8B0X-0HN9ASEFCG9GA",
    wpnCurrent = config.c.ground.srbm.wpnDefault * 2,
    wpnDefault = config.c.ground.srbm.wpnDefault * 2,
  },
  ["IC8B0X-0HN9ASEFCGA5A"] = {
    guid = "IC8B0X-0HN9ASEFCGA5A",
    wpnCurrent = config.c.ground.srbm.wpnDefault * 2,
    wpnDefault = config.c.ground.srbm.wpnDefault * 2,
  },
}
saveData.c.ground.srbm.resupplyUnits = {
  ["IC8B0X-0HN7R5QOIVL7D"] = {
    guid = "IC8B0X-0HN7R5QOIVL7D",
    name = "Ammo Sec, 615th Bde, PLARF",
    wpnCurrent = config.c.ground.srbm.wpnDefault,
    wpnDefault = config.c.ground.srbm.wpnDefault,
    unitCount = 9,
    operationalArea = config.c.ground.srbm.operationalAreas.Brigade615,
    reloadStartTime = nil,
    state = config.batteryState.STATIC,
    ammunition = "IC8B0X-0HN9ASEFCG848",
  },
  ["IC8B0X-0HN7R5QOIVLSG"] = {
    guid = "IC8B0X-0HN7R5QOIVLSG",
    name = "Ammo Sec, 614th Bde, PLARF",
    wpnCurrent = config.c.ground.srbm.wpnDefault,
    wpnDefault = config.c.ground.srbm.wpnDefault,
    unitCount = 9,
    operationalArea = config.c.ground.srbm.operationalAreas.Brigade614,
    reloadStartTime = nil,
    state = config.batteryState.STATIC,
    ammunition = "IC8B0X-0HN9ASEFCG95Q",
  },
  ["IC8B0X-0HN7R5QOIVMO1"] = {
    guid = "IC8B0X-0HN7R5QOIVMO1",
    name = "Ammo Sec, 636th Bde, PLARF",
    wpnCurrent = config.c.ground.srbm.wpnDefault,
    wpnDefault = config.c.ground.srbm.wpnDefault,
    unitCount = 9,
    operationalArea = config.c.ground.srbm.operationalAreas.Brigade636,
    reloadStartTime = nil,
    state = config.batteryState.STATIC,
    ammunition = "IC8B0X-0HN9ASEFCG8CT",
  },
  ["IC8B0X-0HN7R5QOIVOSN"] = {
    guid = "IC8B0X-0HN7R5QOIVOSN",
    name = "Ammo Sec, 616th Bde, PLARF",
    wpnCurrent = config.c.ground.srbm.wpnDefault,
    wpnDefault = config.c.ground.srbm.wpnDefault,
    unitCount = 9,
    operationalArea = config.c.ground.srbm.operationalAreas.Brigade616,
    reloadStartTime = nil,
    state = config.batteryState.STATIC,
    ammunition = "IC8B0X-0HN9ASEFCG8OK",
  },
  ["IC8B0X-0HN7R5QOIVPNC"] = {
    guid = "IC8B0X-0HN7R5QOIVPNC",
    name = "Ammo Sec, 613rd Bde, PLARF",
    wpnCurrent = config.c.ground.srbm.wpnDefault,
    wpnDefault = config.c.ground.srbm.wpnDefault,
    unitCount = 9,
    operationalArea = config.c.ground.srbm.operationalAreas.Brigade613,
    reloadStartTime = nil,
    state = config.batteryState.STATIC,
    ammunition = "IC8B0X-0HN9ASEFCG9GA",
  },
  ["IC8B0X-0HN7R5QOIVQ6P"] = {
    guid = "IC8B0X-0HN7R5QOIVQ6P",
    name = "Ammo Sec, 617th Bde, PLARF",
    wpnCurrent = config.c.ground.srbm.wpnDefault,
    wpnDefault = config.c.ground.srbm.wpnDefault,
    unitCount = 9,
    operationalArea = config.c.ground.srbm.operationalAreas.Brigade617,
    reloadStartTime = nil,
    state = config.batteryState.STATIC,
    ammunition = "IC8B0X-0HN9ASEFCGA5A",
  },
}
saveData.c.ground.srbm.firingUnits = {
  ["X58F5H-0HN1G2IFLNKG9"] = {
    guid = "X58F5H-0HN1G2IFLNKG9",
    name = "615th Bde, PLARF",
    msg = "Radio source, Bty",
    reloadStartTime = nil,
    state = config.batteryState.HIDE,
    operationalArea = config.c.ground.srbm.operationalAreas.Brigade615,
    weaponDBID = constants.WEAPONS.DF11A,
    ammoThreshold = config.c.ground.srbm.ammoThreshold,
    resupplyUnit = "IC8B0X-0HN7R5QOIVL7D",
  },
  ["X58F5H-0HN1LQGRV8HNQ"] = {
    guid = "X58F5H-0HN1LQGRV8HNQ",
    name = "614th Bde, PLARF",
    msg = "Radio source, Bty",
    reloadStartTime = nil,
    state = config.batteryState.HIDE,
    operationalArea = config.c.ground.srbm.operationalAreas.Brigade614,
    weaponDBID = constants.WEAPONS.DF11A,
    ammoThreshold = config.c.ground.srbm.ammoThreshold,
    resupplyUnit = "IC8B0X-0HN7R5QOIVLSG",
  },
  ["IC8B0X-0HN822OHANPB3"] = {
    guid = "IC8B0X-0HN822OHANPB3",
    name = "636th Bde, PLARF",
    msg = "Radio source, Bty",
    reloadStartTime = nil,
    state = config.batteryState.HIDE,
    operationalArea = config.c.ground.srbm.operationalAreas.Brigade636,
    weaponDBID = constants.WEAPONS.DF16A,
    ammoThreshold = config.c.ground.srbm.ammoThreshold,
    resupplyUnit = "IC8B0X-0HN7R5QOIVMO1",
  },
  ["X58F5H-0HN1G2IFLF6QE"] = {
    guid = "X58F5H-0HN1G2IFLF6QE",
    name = "616th Bde, PLARF",
    msg = "Radio source, Bty",
    reloadStartTime = nil,
    state = config.batteryState.HIDE,
    operationalArea = config.c.ground.srbm.operationalAreas.Brigade616,
    weaponDBID = constants.WEAPONS.DF15C,
    ammoThreshold = config.c.ground.srbm.ammoThreshold,
    resupplyUnit = "IC8B0X-0HN7R5QOIVOSN",
  },
  ["X58F5H-0HN1G2DEBC7O8"] = {
    guid = "X58F5H-0HN1G2DEBC7O8",
    name = "613rd Bde, PLARF",
    msg = "Radio source, Bty",
    reloadStartTime = nil,
    state = config.batteryState.HIDE,
    operationalArea = config.c.ground.srbm.operationalAreas.Brigade613,
    weaponDBID = constants.WEAPONS.DF15B,
    ammoThreshold = config.c.ground.srbm.ammoThreshold,
    resupplyUnit = "IC8B0X-0HN7R5QOIVPNC",
  },
  ["IC8B0X-0HN822OHANRHI"] = {
    guid = "IC8B0X-0HN822OHANRHI",
    name = "617th Bde, PLARF",
    msg = "Radio source, Bty",
    reloadStartTime = nil,
    state = config.batteryState.HIDE,
    operationalArea = config.c.ground.srbm.operationalAreas.Brigade617,
    weaponDBID = constants.WEAPONS.DF16A,
    ammoThreshold = config.c.ground.srbm.ammoThreshold,
    resupplyUnit = "IC8B0X-0HN7R5QOIVQ6P",
  },
}


-- ============================================================================
-- MRBM (China)
-- ============================================================================

saveData.c.ground.mrbm = {}
saveData.c.ground.mrbm.isActivated = true
saveData.c.ground.mrbm.reloadTime = config.c.ground.mrbm.reloadTime
saveData.c.ground.mrbm.operationalAreas = config.c.ground.mrbm.operationalAreas
saveData.c.ground.mrbm.ammunitions = {
  ["IC8B0X-0HNCOR6HG2KK5"] = {
    guid = "IC8B0X-0HNCOR6HG2KK5",
    wpnCurrent = config.c.ground.mrbm.wpnDefault * 2,
    wpnDefault = config.c.ground.mrbm.wpnDefault * 2,
  },
}
saveData.c.ground.mrbm.resupplyUnits = {
  ["IC8B0X-0HNCOR6HG2KF9"] = {
    guid = "IC8B0X-0HNCOR6HG2KF9",
    name = "Ammo Sec, 624th Bde, PLARF",
    wpnCurrent = config.c.ground.mrbm.wpnDefault,
    wpnDefault = config.c.ground.mrbm.wpnDefault,
    unitCount = 6,
    operationalArea = config.c.ground.mrbm.operationalAreas.Brigade624,
    reloadStartTime = nil,
    state = config.batteryState.STATIC,
    ammunition = "IC8B0X-0HNCOR6HG2KK5",
  },
}
saveData.c.ground.mrbm.firingUnits = {
  ["IC8B0X-0HNCOR6HG2JE1"] = {
    guid = "IC8B0X-0HNCOR6HG2JE1",
    name = "624th Bde, PLARF",
    msg = "Radio source, Bty",
    reloadStartTime = nil,
    state = config.batteryState.HIDE,
    operationalArea = config.c.ground.mrbm.operationalAreas.Brigade624,
    weaponDBID = constants.WEAPONS.DF21D,
    ammoThreshold = config.c.ground.mrbm.ammoThreshold,
    resupplyUnit = "IC8B0X-0HNCOR6HG2KF9",
  },
}


-- ============================================================================
-- Reconnaissance (China)
-- ============================================================================

---@type SBJ__ReconContext
saveData.c.recon = {}
saveData.c.recon.isActivated = true
saveData.c.recon.queue = {
  {
    baseGUID = constants.BASES.LIUAN_AB,
    unitDBID = constants.PLATFORMS.H6N,
    unitGUID = nil,
    course = config.c.recon.courses.H6N,
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
}


-- ============================================================================
-- Fire Support Plan (China)
-- ============================================================================

saveData.c.ground.isActivated = true
saveData.c.ground.FSP = {}


-- ============================================================================
-- Air Tasking Order (China)
-- ============================================================================

---@type SBJ__AirOperationsContext
saveData.c.air = {}
saveData.c.air.landBased = {}
saveData.c.air.shipBased = {}
saveData.c.air.isActivated = true
saveData.c.air.ATO = {}



-- ============================================================================
-- Amphibious Operations (China)
-- ============================================================================

---@type SBJ__PHIBOPContext
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
---@type SBJ__LACMContext
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

---@type SBJ__RunwayRepairmentContext
saveData.c.repairRunway = {}
saveData.c.repairRunway.isActivated = false
saveData.c.repairRunway.runways = {}


-- ============================================================================
-- Ground Forces (Taiwan)
-- ============================================================================

---@type SBJ__GroundForceContext
saveData.t.ground = {}
saveData.t.ground.isActivated = true


-- ============================================================================
-- MLRS (Taiwan)
-- ============================================================================

saveData.t.ground.mlrs = {}
saveData.t.ground.mlrs.isActivated = true
saveData.t.ground.mlrs.reloadTime = config.t.ground.mlrs.reloadTime
saveData.t.ground.mlrs.operationalAreas = config.t.ground.mlrs.operationalAreas
saveData.t.ground.mlrs.ammunitions = {
  ["IC8B0X-0HN9B47GHVJ7G"] = {
    guid = "IC8B0X-0HN9B47GHVJ7G",
    wpnCurrent = config.t.ground.mlrs.wpnDefault,
    wpnDefault = config.t.ground.mlrs.wpnDefault,
  }
}
saveData.t.ground.mlrs.resupplyUnits = {
  ["IC8B0X-0HN7RT1I581BB"] = {
    name = "Ammo Sec, Rocket Arty Coy, 21st Arty Command",
    guid = "IC8B0X-0HN7RT1I581BB",
    wpnCurrent = config.t.ground.mlrs.wpnDefault,
    wpnDefault = config.t.ground.mlrs.wpnDefault,
    unitCount = 2,
    operationalArea = config.t.ground.mlrs.operationalAreas.Pingzhen,
    reloadStartTime = nil,
    state = config.batteryState.STATIC,
    ammunition = "IC8B0X-0HN9B47GHVJ7G",
  }
}
saveData.t.ground.mlrs.firingUnits = {
  ["IC8B0X-0HN7RU9I3KV9T"] = {
    name = "Rocket Arty Coy, 21st Arty Command",
    msg = "Radio source, Bty",
    guid = "IC8B0X-0HN7RU9I3KV9T",
    reloadStartTime = nil,
    state = config.batteryState.HIDE,
    operationalArea = config.t.ground.mlrs.operationalAreas.Pingzhen,
    weaponDBID = constants.WEAPONS.MK45_AMLRS,
    ammoThreshold = config.t.ground.mlrs.ammoThreshold,
    resupplyUnit = "IC8B0X-0HN7RT1I581BB",
  },
}


-- ============================================================================
-- SRBM (Taiwan)
-- ============================================================================

saveData.t.ground.srbm = {}
saveData.t.ground.srbm.isActivated = true
saveData.t.ground.srbm.reloadTime = config.t.ground.srbm.reloadTime
saveData.t.ground.srbm.operationalAreas = config.t.ground.srbm.operationalAreas
saveData.t.ground.srbm.ammunitions = {
  ["IC8B0X-0HN9B47GHVJG6"] = {
    guid = "IC8B0X-0HN9B47GHVJG6",
    wpnCurrent = config.t.ground.srbm.wpnDefault,
    wpnDefault = config.t.ground.srbm.wpnDefault,
  }
}
saveData.t.ground.srbm.resupplyUnits = {
  ["IC8B0X-0HN7R5QOIVSFS"] = {
    name = "Ammo Sec, Rocket Arty Coy, 58th Arty Command",
    guid = "IC8B0X-0HN7R5QOIVSFS",
    wpnCurrent = config.t.ground.srbm.wpnDefault,
    wpnDefault = config.t.ground.srbm.wpnDefault,
    unitCount = 2,
    operationalArea = config.t.ground.srbm.operationalAreas.Dadu,
    reloadStartTime = nil,
    state = config.batteryState.STATIC,
    ammunition = "IC8B0X-0HN9B47GHVJG6",
  }
}
saveData.t.ground.srbm.firingUnits = {
  ["IC8B0X-0HN7SOIUF4D47"] = {
    name = "Rocket Arty Coy, 58th Arty Command",
    msg = "Radio source, Bty",
    guid = "IC8B0X-0HN7SOIUF4D47",
    reloadStartTime = nil,
    state = config.batteryState.HIDE,
    operationalArea = config.t.ground.srbm.operationalAreas.Dadu,
    weaponDBID = constants.WEAPONS.ATACMS,
    ammoThreshold = config.t.ground.srbm.ammoThreshold,
    resupplyUnit = "IC8B0X-0HN7R5QOIVSFS",
  },
}



-- ============================================================================
-- GLCM (Taiwan)
-- ============================================================================

saveData.t.ground.glcm = {}
saveData.t.ground.glcm.isActivated = true
saveData.t.ground.glcm.reloadTime = config.t.ground.glcm.reloadTime
saveData.t.ground.glcm.operationalAreas = config.t.ground.glcm.operationalAreas
saveData.t.ground.glcm.ammunitions = {
  ["IC8B0X-0HN9B47GHVKAG"] = {
    guid = "IC8B0X-0HN9B47GHVKAG",
    wpnCurrent = config.t.ground.glcm.wpnDefault * 2,
    wpnDefault = config.t.ground.glcm.wpnDefault * 2,
  },
  ["IC8B0X-0HN9B47GHVL3V"] = {
    guid = "IC8B0X-0HN9B47GHVL3V",
    wpnCurrent = config.t.ground.glcm.wpnDefault * 2,
    wpnDefault = config.t.ground.glcm.wpnDefault * 2,
  }
}
saveData.t.ground.glcm.resupplyUnits = {
  ["IC8B0X-0HN7R5QOIVTHT"] = {
    name = "Ammo Sec, 641st Bn, 791st AFAD & Arty Bde",
    guid = "IC8B0X-0HN7R5QOIVTHT",
    wpnCurrent = config.t.ground.glcm.wpnDefault,
    wpnDefault = config.t.ground.glcm.wpnDefault,
    unitCount = 3,
    operationalArea = config.t.ground.glcm.operationalAreas.Quanxi,
    reloadStartTime = nil,
    state = config.batteryState.STATIC,
    ammunition = "IC8B0X-0HN9B47GHVKAG",
  },
  ["IC8B0X-0HN7R5QOIVUDC"] = {
    name = "Ammo Sec, 642nd Bn, 791st AFAD & Arty Bde",
    guid = "IC8B0X-0HN7R5QOIVUDC",
    wpnCurrent = config.t.ground.glcm.wpnDefault,
    wpnDefault = config.t.ground.glcm.wpnDefault,
    unitCount = 3,
    operationalArea = config.t.ground.glcm.operationalAreas.Neipu,
    reloadStartTime = nil,
    state = config.batteryState.STATIC,
    ammunition = "IC8B0X-0HN9B47GHVL3V",
  },
}
saveData.t.ground.glcm.firingUnits = {
  ["X58F5H-0HN1ESDRTUULO"] = {
    guid = "X58F5H-0HN1ESDRTUULO",
    name = "641st Bn, 791st AFAD & Arty Bde",
    msg = "Radio source, Bty",
    reloadStartTime = nil,
    state = config.batteryState.HIDE,
    operationalArea = config.t.ground.glcm.operationalAreas.Quanxi,
    weaponDBID = constants.WEAPONS.HF2E,
    ammoThreshold = config.t.ground.glcm.ammoThreshold,
    resupplyUnit = "IC8B0X-0HN7R5QOIVTHT",
  },
  ["X58F5H-0HN1ESDRTLGU7"] = {
    guid = "X58F5H-0HN1ESDRTLGU7",
    name = "642nd Bn, 791st AFAD & Arty Bde",
    msg = "Radio source, Bty",
    reloadStartTime = nil,
    state = config.batteryState.HIDE,
    operationalArea = config.t.ground.glcm.operationalAreas.Neipu,
    weaponDBID = constants.WEAPONS.HF2E,
    ammoThreshold = config.t.ground.glcm.ammoThreshold,
    resupplyUnit = "IC8B0X-0HN7R5QOIVUDC",
  }
}




-- ============================================================================
-- ASCM (Taiwan)
-- ============================================================================

saveData.t.ground.ascm = {}
saveData.t.ground.ascm.isActivated = true
saveData.t.ground.ascm.reloadTime = config.t.ground.ascm.reloadTime
saveData.t.ground.ascm.operationalAreas = config.t.ground.ascm.operationalAreas
saveData.t.ground.ascm.ammunitions = {
  ["IC8B0X-0HN9B47GHVLV9"] = {
    guid = "IC8B0X-0HN9B47GHVLV9",
    wpnCurrent = config.t.ground.ascm.wpnDefault * 2,
    wpnDefault = config.t.ground.ascm.wpnDefault * 2,
  },
  ["IC8B0X-0HN9JFGVR06D8"] = {
    guid = "IC8B0X-0HN9JFGVR06D8",
    wpnCurrent = config.t.ground.ascm.wpnDefault * 2,
    wpnDefault = config.t.ground.ascm.wpnDefault * 2,
  },
}
saveData.t.ground.ascm.resupplyUnits = {
  ["IC8B0X-0HN87KFOFSGUB"] = {
    name = "Hai Feng Shore-based ASM SUPP Sqn",
    guid = "IC8B0X-0HN87KFOFSGUB",
    wpnCurrent = config.t.ground.ascm.wpnDefault,
    wpnDefault = config.t.ground.ascm.wpnDefault,
    unitCount = 2,
    operationalArea = config.t.ground.ascm.operationalAreas.Pingzhen,
    reloadStartTime = nil,
    state = config.batteryState.STATIC,
    ammunition = "IC8B0X-0HN9B47GHVLV9",
  },
  ["IC8B0X-0HN9JFGVR07U5"] = {
    name = "Hai Feng Shore-based ASM SUPP Sqn",
    guid = "IC8B0X-0HN9JFGVR07U5",
    wpnCurrent = config.t.ground.ascm.wpnDefault,
    wpnDefault = config.t.ground.ascm.wpnDefault,
    unitCount = 2,
    operationalArea = config.t.ground.ascm.operationalAreas.Dong,
    reloadStartTime = nil,
    state = config.batteryState.STATIC,
    ammunition = "IC8B0X-0HN9JFGVR06D8",
  },
}
saveData.t.ground.ascm.firingUnits = {
  ["IC8B0X-0HN87MOIE9C4U"] = {
    name = "2nd Hai Feng Shore-based ASM MOB Sqn",
    msg = "Radio source, Bty",
    guid = "IC8B0X-0HN87MOIE9C4U",
    reloadStartTime = nil,
    state = config.batteryState.HIDE,
    operationalArea = config.t.ground.ascm.operationalAreas.Luzhu,
    weaponDBID = constants.WEAPONS.HF3,
    ammoThreshold = config.t.ground.ascm.ammoThreshold,
    resupplyUnit = "IC8B0X-0HN87KFOFSGUB",
  },
  ["X58F5H-0HMVEU1FUVOLC"] = {
    name = "4th Hai Feng Shore-based ASM MOB Sqn",
    msg = "Radio source, Bty",
    guid = "X58F5H-0HMVEU1FUVOLC",
    reloadStartTime = nil,
    state = config.batteryState.HIDE,
    operationalArea = config.t.ground.ascm.operationalAreas.Luzhu,
    weaponDBID = constants.WEAPONS.HF3,
    ammoThreshold = config.t.ground.ascm.ammoThreshold,
    resupplyUnit = "IC8B0X-0HN87KFOFSGUB",
  },
  ["X58F5H-0HMVEU1FUVO8I"] = {
    name = "1st Hai Feng Shore-based ASM MOB Sqn",
    msg = "Radio source, Bty",
    guid = "X58F5H-0HMVEU1FUVO8I",
    reloadStartTime = nil,
    state = config.batteryState.HIDE,
    operationalArea = config.t.ground.ascm.operationalAreas.Dong,
    weaponDBID = constants.WEAPONS.HF3,
    ammoThreshold = config.t.ground.ascm.ammoThreshold,
    resupplyUnit = "IC8B0X-0HN9JFGVR07U5",
  },
  ["X58F5H-0HMVEU1FUVO6J"] = {
    name = "3rd Hai Feng Shore-based ASM MOB Sqn",
    msg = "Radio source, Bty",
    guid = "X58F5H-0HMVEU1FUVO6J",
    reloadStartTime = nil,
    state = config.batteryState.HIDE,
    operationalArea = config.t.ground.ascm.operationalAreas.Dong,
    weaponDBID = constants.WEAPONS.HF3,
    ammoThreshold = config.t.ground.ascm.ammoThreshold,
    resupplyUnit = "IC8B0X-0HN9JFGVR07U5",
  },
  ["IC8B0X-0HN8CEO4EUE8B"] = {
    name = "5th Hai Feng Shore-based ASM MOB Sqn",
    msg = "Radio source, Bty",
    guid = "IC8B0X-0HN8CEO4EUE8B",
    reloadStartTime = nil,
    state = config.batteryState.HIDE,
    operationalArea = config.t.ground.ascm.operationalAreas.Luzhu,
    weaponDBID = constants.WEAPONS.HF3,
    ammoThreshold = config.t.ground.ascm.ammoThreshold,
    resupplyUnit = "IC8B0X-0HN87KFOFSGUB",
  },
  ["IC8B0X-0HNHAETCJHDEA"] = {
    name = "6th Hai Feng Shore-based ASM MOB Sqn",
    msg = "Radio source, Bty",
    guid = "IC8B0X-0HNHAETCJHDEA",
    reloadStartTime = nil,
    state = config.batteryState.HIDE,
    operationalArea = config.t.ground.ascm.operationalAreas.Dong,
    weaponDBID = constants.WEAPONS.HF3,
    ammoThreshold = config.t.ground.ascm.ammoThreshold,
    resupplyUnit = "IC8B0X-0HN9JFGVR07U5",
  },
}
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

---@type SBJ__RunwayRepairmentContext
saveData.t.repairRunway = {}
saveData.t.repairRunway.isActivated = false
saveData.t.repairRunway.runways = {}


-- ============================================================================
-- IADS (Taiwan)
-- ============================================================================

---@type SBJ__IADSContext
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
---@type SBJ__LandBasedPlatformContext
saveData.t.air.landBased = {}
---@type table<string, SBJ__LandBasedPlatformContext>
saveData.t.air.landBased.AEW = {}
---@type table<string, SBJ__LandBasedPlatformContext>
saveData.t.air.landBased.AC = {}


-- ============================================================================
-- GPS Jamming (Taiwan)
-- ============================================================================

saveData.t.GPSJamming = {}
---@type table<string, SBJ__GPSJammerDescriptor>
saveData.t.GPSJamming.jammers = {
  ["Comms & Info Coy, 584th Mech Bde"] = {
    zoneName = "(Taiwan) Jamming Zone/1",
    name = "Comms & Info Coy, 584th Mech Bde",
    point = { latitude = nil, longitude = nil },
    randomRadius = config.t.GPSJamming.randomRadius,
    radius = config.t.GPSJamming.radius
  },
  ["Comms & Info Coy, 269th Mech Bde"] = {
    zoneName = "(Taiwan) Jamming Zone/2",
    name = "Comms & Info Coy, 269th Mech Bde",
    point = { latitude = nil, longitude = nil },
    randomRadius = config.t.GPSJamming.randomRadius,
    radius = config.t.GPSJamming.radius
  },
}


-- ============================================================================
-- SIGINT (US)
-- ============================================================================

---@type SBJ__SIGINTContext
saveData.u.SIGINT = {}
saveData.u.SIGINT.isActivated = true
saveData.u.SIGINT.maxCount = config.u.SIGINT.maxCount
saveData.u.SIGINT.RA = {}
saveData.u.SIGINT.transmissions = {}


-- ============================================================================
-- Dynamic Operations (China)
-- ============================================================================

---@type SBJ__DynamicOperationsContext
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
  --         name = "INFRASTRUCTURE/1",
  --         strikeInterval = 0,
  --         isFirstWave = true,
  --         FSTs = config.c.FSTTemplate.STRIKE_INFRASTRUCTURE_1
  --       }
  --     },
  --     {
  --       type = "ground",
  --       executed = false,
  --       template = {
  --         name = "HELIPAD/1",
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
  --         name = "INFRASTRUCTURE/2",
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
  --         name = "C2/1",
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
