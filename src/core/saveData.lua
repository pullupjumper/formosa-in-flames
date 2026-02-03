local config = require("src.core.config")
local constants = require("src.core.constants")

---@class SBJ__SaveData
local saveData = {}
saveData.c = {}
saveData.c.targetlist = {}
saveData.t = {}
saveData.u = {}


-- ============================================================================
-- SIGINT (China)
-- ============================================================================

saveData.c.SIGINT = {}
saveData.c.SIGINT.enabled = true
saveData.c.SIGINT.maxCount = config.c.SIGINT.maxCount
saveData.c.SIGINT.RA = {}
saveData.c.SIGINT.transmissions = {}


-- ============================================================================
-- IADS (China)
-- ============================================================================

saveData.c.IADS = {}
saveData.c.IADS.enabled = true
saveData.c.IADS.C2 = {}


-- ============================================================================
-- Communications Jamming (China)
-- ============================================================================

saveData.c.commsJamming = {}
saveData.c.commsJamming.enabled = true
saveData.c.commsJamming.jammers = {}


-- ============================================================================
-- GPS Jamming (China)
-- ============================================================================

saveData.c.GPSJamming = {}
saveData.c.GPSJamming.enabled = true
saveData.c.GPSJamming.jammers = {}


-- ============================================================================
-- MLRS (China)
-- ============================================================================

saveData.c.ground = {}
saveData.c.ground.mlrs = {}
saveData.c.ground.mlrs.enabled = true
saveData.c.ground.mlrs.reloadTime = config.c.ground.mlrs.reloadTime
saveData.c.ground.mlrs.ammunitions = {}
saveData.c.ground.mlrs.resupplyUnits = {}
saveData.c.ground.mlrs.firingUnits = {}


-- ============================================================================
-- GLCM (China)
-- ============================================================================

saveData.c.ground.glcm = {}
saveData.c.ground.glcm.enabled = true
saveData.c.ground.glcm.reloadTime = config.c.ground.glcm.reloadTime
saveData.c.ground.glcm.ammunitions = {}
saveData.c.ground.glcm.resupplyUnits = {}
saveData.c.ground.glcm.firingUnits = {}


-- ============================================================================
-- SRBM (China)
-- ============================================================================

saveData.c.ground.srbm = {}
saveData.c.ground.srbm.enabled = true
saveData.c.ground.srbm.reloadTime = config.c.ground.srbm.reloadTime
saveData.c.ground.srbm.ammunitions = {}
saveData.c.ground.srbm.resupplyUnits = {}
saveData.c.ground.srbm.firingUnits = {}


-- ============================================================================
-- MRBM (China)
-- ============================================================================

saveData.c.ground.mrbm = {}
saveData.c.ground.mrbm.enabled = true
saveData.c.ground.mrbm.reloadTime = config.c.ground.mrbm.reloadTime
saveData.c.ground.mrbm.ammunitions = {}
saveData.c.ground.mrbm.resupplyUnits = {}
saveData.c.ground.mrbm.firingUnits = {}


-- ============================================================================
-- ASCM (China)
-- ============================================================================

saveData.c.ground.ascm = {}
saveData.c.ground.ascm.enabled = true
saveData.c.ground.ascm.reloadTime = config.c.ground.ascm.reloadTime
saveData.c.ground.ascm.ammunitions = {}
saveData.c.ground.ascm.resupplyUnits = {}
saveData.c.ground.ascm.firingUnits = {}


-- ============================================================================
-- Reconnaissance (China)
-- ============================================================================

saveData.c.recon = {}
saveData.c.recon.enabled = true
saveData.c.recon.queue = {}

-- ============================================================================
-- Fire Support Plan (China)
-- ============================================================================

saveData.c.ground.enabled = true
saveData.c.ground.FSP = {}


-- ============================================================================
-- Air Tasking Order (China)
-- ============================================================================

saveData.c.air = {}
saveData.c.air.landBased = {}
saveData.c.air.shipBased = {}
saveData.c.air.enabled = true
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
saveData.c.PHIBOP.calculationResult = {}
saveData.c.PHIBOP.barges = {}


-- ============================================================================
-- Land Attack Cruise Missiles - Surface Launch (China)
-- ============================================================================

saveData.c.surface = {}
saveData.c.surface.lacm = {}
saveData.c.surface.lacm.enabled = false
saveData.c.surface.lacm.startTime = config.c.triggers.launchLACM.startTime


-- ============================================================================
-- Submarine-Launched Cruise Missiles (China)
-- ============================================================================

saveData.c.subSurface = {}
saveData.c.subSurface.slcm = {}
saveData.c.subSurface.slcm.enabled = true
saveData.c.subSurface.slcm.startTime = config.c.triggers.launchSLCM.startTime


-- ============================================================================
-- Runway Repair (China)
-- ============================================================================

saveData.c.repairRunway = {}
saveData.c.repairRunway.enabled = false
saveData.c.repairRunway.runways = {}


-- ============================================================================
-- Ground Forces (Taiwan)
-- ============================================================================

saveData.t.ground = {}
saveData.t.ground.enabled = true


-- ============================================================================
-- MLRS (Taiwan)
-- ============================================================================

saveData.t.ground.mlrs = {}
saveData.t.ground.mlrs.enabled = true
saveData.t.ground.mlrs.reloadTime = config.t.ground.mlrs.reloadTime
saveData.t.ground.mlrs.ammunitions = {}
saveData.t.ground.mlrs.resupplyUnits = {}
saveData.t.ground.mlrs.firingUnits = {}


-- ============================================================================
-- SRBM (Taiwan)
-- ============================================================================

saveData.t.ground.srbm = {}
saveData.t.ground.srbm.enabled = true
saveData.t.ground.srbm.reloadTime = config.t.ground.srbm.reloadTime
saveData.t.ground.srbm.ammunitions = {}
saveData.t.ground.srbm.resupplyUnits = {}
saveData.t.ground.srbm.firingUnits = {}



-- ============================================================================
-- GLCM (Taiwan)
-- ============================================================================

saveData.t.ground.glcm = {}
saveData.t.ground.glcm.enabled = true
saveData.t.ground.glcm.reloadTime = config.t.ground.glcm.reloadTime
saveData.t.ground.glcm.ammunitions = {}
saveData.t.ground.glcm.resupplyUnits = {}
saveData.t.ground.glcm.firingUnits = {}




-- ============================================================================
-- ASCM (Taiwan)
-- ============================================================================

saveData.t.ground.ascm = {}
saveData.t.ground.ascm.enabled = true
saveData.t.ground.ascm.reloadTime = config.t.ground.ascm.reloadTime
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
saveData.t.repairRunway.enabled = false
saveData.t.repairRunway.runways = {}


-- ============================================================================
-- IADS (Taiwan)
-- ============================================================================

saveData.t.IADS = {}
saveData.t.IADS.enabled = true
saveData.t.IADS.ROCC = {}
saveData.t.IADS.TAAOC = {}

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
saveData.t.GPSJamming.enabled = true
saveData.t.GPSJamming.jammers = {}


-- ============================================================================
-- SIGINT (US)
-- ============================================================================

saveData.u.SIGINT = {}
saveData.u.SIGINT.enabled = true
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
saveData.c.dynamicOperations.reconSchedule = {}

return saveData
