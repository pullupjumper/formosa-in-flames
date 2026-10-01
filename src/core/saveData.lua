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
-- Ground Forces (China)
-- Per-system missile state is seeded by MissileSystem.ensureGroundState
-- ============================================================================

saveData.c.ground = {}
saveData.c.ground.missileSystemTypes = {}


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
saveData.c.air.enabled = true
saveData.c.air.airTaskingOrder = {}


-- ============================================================================
-- Amphibious Operations (China)
-- ============================================================================

saveData.c.amphibOps = {}
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
saveData.c.surface.lacm.hasLaunched = false


-- ============================================================================
-- Submarine-Launched Cruise Missiles (China)
-- ============================================================================

saveData.c.subSurface = {}
saveData.c.subSurface.slcm = {}
saveData.c.subSurface.slcm.enabled = true


-- ============================================================================
-- Runway Repair (China)
-- ============================================================================

saveData.c.repairRunway = {}
saveData.c.repairRunway.enabled = false
saveData.c.repairRunway.runways = {}


-- ============================================================================
-- Ground Forces (Taiwan)
-- Per-system missile state is seeded by MissileSystem.ensureGroundState
-- ============================================================================

saveData.t.ground = {}
saveData.t.ground.enabled = true
saveData.t.ground.missileSystemTypes = {}
saveData.t.ground.missileSystemTypes.ascm = {}
saveData.t.ground.missileSystemTypes.ascm.test = {
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

saveData.t.iads = {}
saveData.t.iads.enabled = true
saveData.t.iads.rocc = {}
saveData.t.iads.taaoc = {}


-- ============================================================================
-- Aircraft (Taiwan)
-- ============================================================================

saveData.t.air = {}
saveData.t.air.aew = {}
saveData.t.air.ac = {}


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
saveData.u.sigint.reconAircraft = {}
saveData.u.sigint.transmissions = {}


-- ============================================================================
-- Dynamic Operations (China)
-- ============================================================================

saveData.c.dynamicOperations = {}
saveData.c.dynamicOperations.enabled = true
saveData.c.dynamicOperations.generatedOperations = {
  air = {},   -- Track generated air operations
  ground = {} -- Track generated ground operations
}
saveData.c.dynamicOperations.reconTriggeredOperationBatches = {}

return saveData
