local constants = require("src.core.constants")
---@diagnostic disable: missing-fields
---@class SBJ__SaveData
local saveData = {}
saveData.red = {}
saveData.red.targetlist = {}
saveData.red.deploymentLocked = false
saveData.blue = {}
saveData.blue.deploymentLocked = false
saveData.ally = {}


-- ============================================================================
-- SIGINT (China)
-- ============================================================================

saveData.red.sigint = {}
saveData.red.sigint.enabled = true
saveData.red.sigint.reconAircraft = {}
saveData.red.sigint.transmissions = {}


-- ============================================================================
-- IADS (China)
-- ============================================================================

saveData.red.iads = {}
saveData.red.iads.enabled = true
saveData.red.iads.c2 = {}


-- ============================================================================
-- Communications Jamming (China)
-- ============================================================================

saveData.red.commsJamming = {}
saveData.red.commsJamming.enabled = true
saveData.red.commsJamming.jammers = {}


-- ============================================================================
-- GPS Jamming (China)
-- ============================================================================

saveData.red.gnssJamming = {}
saveData.red.gnssJamming.enabled = true
saveData.red.gnssJamming.jammers = {}


-- ============================================================================
-- Ground Forces (China)
-- Per-system missile state is seeded by MissileSystem.ensureGroundState
-- ============================================================================

saveData.red.ground = {}
saveData.red.ground.missileSystemTypes = {}


-- ============================================================================
-- Reconnaissance (China)
-- ============================================================================

saveData.red.recon = {}
saveData.red.recon.enabled = true
saveData.red.recon.queue = {}
saveData.red.recon.frontlineRedirected = false

-- ============================================================================
-- Fire Support Plan (China)
-- ============================================================================

saveData.red.ground.enabled = true
saveData.red.ground.fireSupportPlan = {}


-- ============================================================================
-- Air Tasking Order (China)
-- ============================================================================

saveData.red.air = {}
saveData.red.air.enabled = true
saveData.red.air.airTaskingOrder = {}


-- ============================================================================
-- Amphibious Operations (China)
-- ============================================================================

saveData.red.amphibOps = {}
saveData.red.amphibOps.zoneStates = {
  Taoyuan = { phase = constants.AMPHIBIOUS_PHASES.MOVING },
  Sishu   = { phase = constants.AMPHIBIOUS_PHASES.MOVING },
  Penghu  = { phase = constants.AMPHIBIOUS_PHASES.MOVING },
}
saveData.red.amphibOps.calculationResult = {}
saveData.red.amphibOps.barges = {}


-- ============================================================================
-- Land Attack Cruise Missiles - Surface Launch (China)
-- ============================================================================

saveData.red.surface = {}
saveData.red.surface.lacm = {}
saveData.red.surface.lacm.enabled = false
saveData.red.surface.lacm.hasLaunched = false


-- ============================================================================
-- Submarine-Launched Cruise Missiles (China)
-- ============================================================================

saveData.red.subSurface = {}
saveData.red.subSurface.slcm = {}
saveData.red.subSurface.slcm.enabled = true


-- ============================================================================
-- Runway Repair (China)
-- ============================================================================

saveData.red.repairRunway = {}
saveData.red.repairRunway.enabled = false
saveData.red.repairRunway.runways = {}


-- ============================================================================
-- Ground Forces (Taiwan)
-- Per-system missile state is seeded by MissileSystem.ensureGroundState
-- ============================================================================

saveData.blue.ground = {}
saveData.blue.ground.enabled = true
saveData.blue.ground.missileSystemTypes = {}
saveData.blue.ground.missileSystemTypes.ascm = {}
saveData.blue.ground.missileSystemTypes.ascm.test = {
  isAntishipMissionActivated = false,
  nai1 = constants.AREAS.groundAscmTestNai1,
  nai2 = constants.AREAS.groundAscmTestNai2,
  shipNumInNai1 = 4,
  helicopterNumInNai2 = 4
}


-- ============================================================================
-- Runway Repair (Taiwan)
-- ============================================================================

saveData.blue.repairRunway = {}
saveData.blue.repairRunway.enabled = false
saveData.blue.repairRunway.runways = {}


-- ============================================================================
-- IADS (Taiwan)
-- ============================================================================

saveData.blue.iads = {}
saveData.blue.iads.enabled = true
saveData.blue.iads.rocc = {}
saveData.blue.iads.taaoc = {}


-- ============================================================================
-- Aircraft (Taiwan)
-- ============================================================================

saveData.blue.air = {}
saveData.blue.air.aew = {}
saveData.blue.air.ac = {}


-- ============================================================================
-- GPS Jamming (Taiwan)
-- ============================================================================

saveData.blue.gnssJamming = {}
saveData.blue.gnssJamming.enabled = true
saveData.blue.gnssJamming.jammers = {}


-- ============================================================================
-- SIGINT (US)
-- ============================================================================

saveData.ally.sigint = {}
saveData.ally.sigint.enabled = true
saveData.ally.sigint.reconAircraft = {}
saveData.ally.sigint.transmissions = {}


-- ============================================================================
-- Dynamic Operations (China)
-- ============================================================================

saveData.red.dynamicOperations = {}
saveData.red.dynamicOperations.enabled = true
saveData.red.dynamicOperations.generatedOperations = {
  air = {},   -- Track generated air operations
  ground = {} -- Track generated ground operations
}
saveData.red.dynamicOperations.reconTriggeredOperationBatches = {}

return saveData
