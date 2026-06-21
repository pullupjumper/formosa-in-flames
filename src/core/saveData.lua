local config = require("src.core.config")
local constants = require("src.core.constants")
---@diagnostic disable: missing-fields
---@class SBJ__SaveData
local saveData = {}
saveData.c = {}
saveData.c.targetlist = {}
saveData.t = {}
saveData.u = {}


-- ============================================================================
-- SIGINT (China)
-- ============================================================================

saveData.c.sigint = {}
saveData.c.sigint.enabled = true
saveData.c.sigint.maxCount = config.c.sigint.maxCount
saveData.c.sigint.reconAircraft = {}
saveData.c.sigint.transmissions = {}


-- ============================================================================
-- IADS (China)
-- ============================================================================

saveData.c.iads = {}
saveData.c.iads.enabled = true
saveData.c.iads.c2 = {}


-- ============================================================================
-- Communications Jamming (China)
-- ============================================================================

saveData.c.commsJamming = {}
saveData.c.commsJamming.enabled = true
saveData.c.commsJamming.jammers = {}


-- ============================================================================
-- GPS Jamming (China)
-- ============================================================================

saveData.c.gnssJamming = {}
saveData.c.gnssJamming.enabled = true
saveData.c.gnssJamming.jammers = {}


-- ============================================================================
-- MLRS (China)
-- ============================================================================

saveData.c.ground = {}
saveData.c.ground.mlrs = {}
saveData.c.ground.mlrs.name = "mlrs"
saveData.c.ground.mlrs.enabled = true
saveData.c.ground.mlrs.reloadTime = config.c.ground.mlrs.reloadTime
saveData.c.ground.mlrs.stowTime = config.c.ground.mlrs.stowTime
saveData.c.ground.mlrs.ammunitions = {}
saveData.c.ground.mlrs.resupplyUnits = {}
saveData.c.ground.mlrs.firingUnits = {}


-- ============================================================================
-- GLCM (China)
-- ============================================================================

saveData.c.ground.glcm = {}
saveData.c.ground.glcm.name = "glcm"
saveData.c.ground.glcm.enabled = true
saveData.c.ground.glcm.reloadTime = config.c.ground.glcm.reloadTime
saveData.c.ground.glcm.stowTime = config.c.ground.glcm.stowTime
saveData.c.ground.glcm.ammunitions = {}
saveData.c.ground.glcm.resupplyUnits = {}
saveData.c.ground.glcm.firingUnits = {}


-- ============================================================================
-- SRBM (China)
-- ============================================================================

saveData.c.ground.srbm = {}
saveData.c.ground.srbm.name = "srbm"
saveData.c.ground.srbm.enabled = true
saveData.c.ground.srbm.reloadTime = config.c.ground.srbm.reloadTime
saveData.c.ground.srbm.stowTime = config.c.ground.srbm.stowTime
saveData.c.ground.srbm.ammunitions = {}
saveData.c.ground.srbm.resupplyUnits = {}
saveData.c.ground.srbm.firingUnits = {}


-- ============================================================================
-- MRBM (China)
-- ============================================================================

saveData.c.ground.mrbm = {}
saveData.c.ground.mrbm.name = "mrbm"
saveData.c.ground.mrbm.enabled = true
saveData.c.ground.mrbm.reloadTime = config.c.ground.mrbm.reloadTime
saveData.c.ground.mrbm.stowTime = config.c.ground.mrbm.stowTime
saveData.c.ground.mrbm.ammunitions = {}
saveData.c.ground.mrbm.resupplyUnits = {}
saveData.c.ground.mrbm.firingUnits = {}


-- ============================================================================
-- ASCM (China)
-- ============================================================================

saveData.c.ground.ascm = {}
saveData.c.ground.ascm.name = "ascm"
saveData.c.ground.ascm.enabled = true
saveData.c.ground.ascm.reloadTime = config.c.ground.ascm.reloadTime
saveData.c.ground.ascm.stowTime = config.c.ground.ascm.stowTime
saveData.c.ground.ascm.ammunitions = {}
saveData.c.ground.ascm.resupplyUnits = {}
saveData.c.ground.ascm.firingUnits = {}


-- ============================================================================
-- SAM (China)
-- ============================================================================

saveData.c.ground.sam = {}
saveData.c.ground.sam.name = "sam"
saveData.c.ground.sam.enabled = true
saveData.c.ground.sam.reloadTime = config.c.ground.sam.reloadTime
saveData.c.ground.sam.stowTime = config.c.ground.sam.stowTime
saveData.c.ground.sam.ammunitions = {}
saveData.c.ground.sam.resupplyUnits = {}
saveData.c.ground.sam.firingUnits = {}


-- ============================================================================
-- Reconnaissance (China)
-- ============================================================================

saveData.c.recon = {}
saveData.c.recon.enabled = true
saveData.c.recon.queue = {}
saveData.c.recon.frontlineRedirected = false

-- ============================================================================
-- Fire Support Plan (China)
-- ============================================================================

saveData.c.ground.enabled = true
saveData.c.ground.fireSupportPlan = {}


-- ============================================================================
-- Air Tasking Order (China)
-- ============================================================================

saveData.c.air = {}
saveData.c.air.landBased = {}
saveData.c.air.shipBased = {}
saveData.c.air.enabled = true
saveData.c.air.airTaskingOrder = {}



-- ============================================================================
-- Amphibious Operations (China)
-- ============================================================================

saveData.c.amphibOps = {}
saveData.c.amphibOps.startTime = config.c.triggers.amphibiousOps.startTime
saveData.c.amphibOps.zoneStates = {
  Taoyuan = { phase = constants.AMPHIBIOUS_PHASES.MOVING },
  Sishu   = { phase = constants.AMPHIBIOUS_PHASES.MOVING },
  Penghu  = { phase = constants.AMPHIBIOUS_PHASES.MOVING },
}
saveData.c.amphibOps.calculationResult = {}
saveData.c.amphibOps.barges = {}


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
saveData.t.ground.mlrs.name = "mlrs"
saveData.t.ground.mlrs.enabled = true
saveData.t.ground.mlrs.reloadTime = config.t.ground.mlrs.reloadTime
saveData.t.ground.mlrs.stowTime = config.t.ground.mlrs.stowTime
saveData.t.ground.mlrs.ammunitions = {}
saveData.t.ground.mlrs.resupplyUnits = {}
saveData.t.ground.mlrs.firingUnits = {}


-- ============================================================================
-- SRBM (Taiwan)
-- ============================================================================

saveData.t.ground.srbm = {}
saveData.t.ground.srbm.name = "srbm"
saveData.t.ground.srbm.enabled = true
saveData.t.ground.srbm.reloadTime = config.t.ground.srbm.reloadTime
saveData.t.ground.srbm.stowTime = config.t.ground.srbm.stowTime
saveData.t.ground.srbm.ammunitions = {}
saveData.t.ground.srbm.resupplyUnits = {}
saveData.t.ground.srbm.firingUnits = {}


-- ============================================================================
-- GLCM (Taiwan)
-- ============================================================================

saveData.t.ground.glcm = {}
saveData.t.ground.glcm.name = "glcm"
saveData.t.ground.glcm.enabled = true
saveData.t.ground.glcm.reloadTime = config.t.ground.glcm.reloadTime
saveData.t.ground.glcm.stowTime = config.t.ground.glcm.stowTime
saveData.t.ground.glcm.ammunitions = {}
saveData.t.ground.glcm.resupplyUnits = {}
saveData.t.ground.glcm.firingUnits = {}


-- ============================================================================
-- ASCM (Taiwan)
-- ============================================================================

saveData.t.ground.ascm = {}
saveData.t.ground.ascm.name = "ascm"
saveData.t.ground.ascm.enabled = true
saveData.t.ground.ascm.reloadTime = config.t.ground.ascm.reloadTime
saveData.t.ground.ascm.stowTime = config.t.ground.ascm.stowTime
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


saveData.t.ground.sam = {}
saveData.t.ground.sam.name = "sam"
saveData.t.ground.sam.enabled = true
saveData.t.ground.sam.reloadTime = config.t.ground.sam.reloadTime
saveData.t.ground.sam.stowTime = config.t.ground.sam.stowTime
saveData.t.ground.sam.ammunitions = {}
saveData.t.ground.sam.resupplyUnits = {}
saveData.t.ground.sam.firingUnits = {}


-- ============================================================================
-- Runway Repair (Taiwan)
-- ============================================================================

saveData.t.repairRunway = {}
saveData.t.repairRunway.enabled = false
saveData.t.repairRunway.runways = {}


-- ============================================================================
-- IADS (Taiwan)
-- ============================================================================

saveData.t.iads = {}
saveData.t.iads.enabled = true
saveData.t.iads.rocc = {}
saveData.t.iads.taaoc = {}


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

saveData.t.gnssJamming = {}
saveData.t.gnssJamming.enabled = true
saveData.t.gnssJamming.jammers = {}


-- ============================================================================
-- SIGINT (US)
-- ============================================================================

saveData.u.sigint = {}
saveData.u.sigint.enabled = true
saveData.u.sigint.maxCount = config.u.sigint.maxCount
saveData.u.sigint.reconAircraft = {}
saveData.u.sigint.transmissions = {}


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
saveData.c.dynamicOperations.reconTriggeredOperations = {}

return saveData
