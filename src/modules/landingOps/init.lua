local constants = require("src.core.constants")
local PersistentState = require("src.core.persistentState")
local GameApi = require("src.utils.gameApi")
local LogFormat = require("src.utils.logFormat")
local Logger = require("src.utils.logger")
local AdminOffloading = require("src.modules.landingOps.adminOffloading")
local AmphibiousAssault = require("src.modules.landingOps.amphibiousAssault")
local Coordinator = require("src.modules.landingOps.coordinator")
local DirectFirePrep = require("src.modules.landingOps.directFirePrep")
local ShipMovement = require("src.modules.landingOps.shipMovement")
local TrackedUnits = require("src.modules.landingOps.trackedUnits")

local LandingOps = {}

-- ============================================================================
-- Public API
-- ============================================================================

---Initialize landing operations runtime data
---@param config SBJ__Config
---@param saveData SBJ__SaveData
function LandingOps.init(config, saveData)
  local amphibOps = config.red.amphibOps
  ShipMovement.buildHoldingPositions(
    amphibOps.zones,
    amphibOps.formation,
    PersistentState.landingOps(saveData).amphibOps.calculationResult
  )
end

---Process all landing operation phases for the current event tick
---@param config SBJ__Config
---@param saveData SBJ__SaveData
function LandingOps.process(config, saveData)
  local contacts = GameApi.ScenEdit_GetContacts(constants.SIDES.RED)
  if not contacts then
    Logger.error(LogFormat.line("ERROR", { scope = "landingOps", reason = "contacts_missing" }))
    return
  end

  local filteredShips = GameApi.VP_GetSide({ side = constants.SIDES.RED }):unitsBy(constants.UNIT_TYPES.SHIP)
  if not filteredShips then
    Logger.error(LogFormat.line("ERROR", { scope = "landingOps", reason = "ships_missing" }))
    return
  end

  local startTime = os.clock()

  Coordinator.process(config, PersistentState.landingOps(saveData), {
    contacts = contacts,
    currentTime = GameApi.ScenEdit_CurrentTime(),
    filteredShips = filteredShips
  })

  local endTime = os.clock()
  Logger.log(constants.TAGS.SHIP_MOVEMENT, LogFormat.line("OK", {
    scope = "landingOpsProcess",
    elapsedSec = string.format("%.4f", endTime - startTime)
  }))
end

---Launch amphibious combat vehicles for a ship after its zone reaches the assault landing
---@param config SBJ__Config
---@param saveData SBJ__SaveData
---@param ship CMO__Unit
---@return boolean # True if the launch workflow was handled
function LandingOps.launchACV(config, saveData, ship)
  return AmphibiousAssault.launchACV(
    config.red.amphibOps, PersistentState.landingOps(saveData).amphibOps.zoneStates, ship)
end

---Offload vehicles in the workflow for barge and RORO event units
---@param config SBJ__Config
---@param saveData SBJ__SaveData
---@param ship CMO__Unit
---@return boolean # True if the offload workflow was handled
function LandingOps.offloadVehicles(config, saveData, ship)
  return AdminOffloading.handleShipArrival(
    config.red.amphibOps, PersistentState.landingOps(saveData).amphibOps.barges, ship)
end

---Attack airlanding zone contacts with SAG surface fire support
---@param config SBJ__Config
---@param saveData SBJ__SaveData
---@param ship CMO__Unit
---@return boolean # True if the attack workflow was handled
function LandingOps.attackAirlandingZone(config, saveData, ship)
  return DirectFirePrep.attackAirlandingZone(
    config.red.amphibOps,
    PersistentState.landingOps(saveData).amphibOps.zoneStates,
    ship
  )
end

---Remove a destroyed unit from the landing records of every zone. Units that landingOps does not record are ignored
---@param saveData SBJ__SaveData
---@param guid string
---@return boolean # True if a record held the unit and it is now removed
function LandingOps.removeDestroyedUnit(saveData, guid)
  local isRemoved = false
  for _, zoneState in pairs(PersistentState.landingOps(saveData).amphibOps.zoneStates) do
    isRemoved = TrackedUnits.remove(zoneState, guid) or isRemoved
  end
  return isRemoved
end

---Count landed China units by type in each operational zone's CAS area
---@param config SBJ__Config
---@return SBJ__LandingUnitCountSet # Unit counts keyed by zone name, then by unit type label
function LandingOps.countUnitsInEachArea(config)
  return AmphibiousAssault.countUnitsInEachArea(config.red.amphibOps.zones)
end

return LandingOps
