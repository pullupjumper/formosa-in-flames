local GameApi = require("src.utils.gameApi")
local ShipMovement = require("src.modules.landingOps.shipMovement")
local Coordinator = require("src.modules.landingOps.coordinator")
local AmphibiousAssault = require("src.modules.landingOps.amphibiousAssault")
local LogFormat = require("src.utils.logFormat")
local SecondWaveUnloading = require("src.modules.landingOps.secondWaveUnloading")
local AttackManager = require("src.modules.attackManager")
local Utils = require("src.utils.utils")
local constants = require("src.core.constants")
local Logger = require("src.utils.logger")
local PersistentState = require("src.core.persistentState")

local LandingOps = {}

---Initialize landing operations runtime data
---@param config SBJ__Config
---@param saveData SBJ__SaveData
function LandingOps.init(config, saveData)
  ShipMovement.calculateDestination(config.red.amphibOps, PersistentState.landingOps(saveData).amphibOps.calculationResult)
end

---Process all landing operation phases for the current event tick
---@param config SBJ__Config
---@param saveData SBJ__SaveData
function LandingOps.process(config, saveData)
  local contacts = GameApi.ScenEdit_GetContacts(constants.SIDES.RED)
  if not contacts then
    Logger.error("contacts is nil")
    return
  end

  local filteredShips = GameApi.VP_GetSide({ side = constants.SIDES.RED }):unitsBy(constants.UNIT_TYPES.SHIP)
  if not filteredShips then
    Logger.error("filteredShips is nil")
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

---Launch amphibious combat vehicles for a ship when it is in a valid zone
---@param config SBJ__Config
---@param ship CMO__Unit
---@return boolean # Whether the launch workflow was handled successfully
function LandingOps.launchACV(config, ship)
  if not AmphibiousAssault.isFerryOrLST(ship) then
    return false
  end

  local zone = AmphibiousAssault.getShipZone(config.red.amphibOps, ship)
  if not zone then
    return false
  end

  local count = AmphibiousAssault.launchACV({
    ship = ship,
    num = 5,
    bearing = zone.acv.bearing + 90,
    distance = zone.acv.distance,
    speed = zone.acv.speed,
    destination = zone.acv.destination
  })

  if count == 0 then
    local result = GameApi.ScenEdit_HostUnitToParent({
      HostedUnitNameOrID = ship.guid,
      SelectedBaseNameOrID = zone.baseGUID
    })

    if not result then
      return false
    end

    ship:RTB(true)
  end

  return true
end

---Handle vehicle offloading workflow for barge and RORO event units
---@param config SBJ__Config
---@param saveData SBJ__SaveData
---@param ship CMO__Unit
---@return boolean # Whether the offload workflow was handled successfully
function LandingOps.offloadVehicles(config, saveData, ship)
  local barges = PersistentState.landingOps(saveData).amphibOps.barges

  if ship.name == "Barge" and not SecondWaveUnloading.hasExtendedBridge(barges, ship) then
    ship.course = nil
    ship.manualSpeed = 0
    ship.holdposition = true

    local bridge = GameApi.ScenEdit_AddUnit({
      side = constants.SIDES.RED,
      type = constants.UNIT_TYPES.FACILITY,
      latitude = ship.latitude,
      longitude = ship.longitude,
      dbid = constants.PLATFORMS.BRIDGE,
      unitname = "bridge",
    })

    if not bridge then
      return false
    end

    barges[ship.guid].bridgeGUID = bridge.guid
  end

  if ship.name == "Barge" and not SecondWaveUnloading.isBridgeDestroyed(barges, ship) then
    for _, guid in ipairs(barges[ship.guid].roros) do
      local roro = GameApi.ScenEdit_GetUnit(guid)

      if roro then
        local zone = SecondWaveUnloading.getBargeROROZone(config.red.amphibOps, ship, roro)

        if zone then
          SecondWaveUnloading.offloadVehicles({
            ship = roro,
            num = 20,
            bearing = zone.acv.bearing + 90,
            distance = zone.acv.distance,
            firstDistance = 1
          })
        end
      end
    end
  end

  if ship.name == "RORO" then
    ship.course = nil
    ship.manualSpeed = 0
    ship.holdposition = true
  end

  return true
end

---Neutralize airlanding zone contacts with SAG surface fire support
---@param config SBJ__Config
---@param ship CMO__Unit
---@return boolean # Whether the neutralization workflow was handled successfully
function LandingOps.neutralizeAirlandingZone(config, ship)
  if not ship.group or ship.dbid ~= constants.PLATFORMS.TYPE_052D then
    return false
  end

  local sagConfig = config.red.amphibOps.sags[ship.group.name]
  if not sagConfig then
    return false
  end

  local contacts = GameApi.ScenEdit_GetContacts(constants.SIDES.RED)
  if not contacts then
    return false
  end

  local filteredContacts = {}

  for _, contact in ipairs(contacts) do
    if contact:inArea(sagConfig.area) and contact.typed == constants.CONTACT_TYPES.FACILITY_MOBILE then
      table.insert(filteredContacts, contact.guid)
    end
  end

  if Utils.getCount(filteredContacts) <= 0 then
    return false
  end

  GameApi.ScenEdit_SetDoctrine(
    { side = ship.side, unitname = ship.group.name },
    { weapon_control_status_land = constants.WCS.FREE }
  )

  AttackManager.attackContacts({
    contacts = filteredContacts,
    qty = math.floor(440 / Utils.getCount(filteredContacts)),
    firingUnits = { ship },
    weaponDBID = constants.WEAPONS.HPJ_38,
  })

  return true
end

---Count landed China units by type in each operational zone's CAS area
---@param config SBJ__Config
---@return table<string, table<string, number>> # Unit counts keyed by zone name, then by unit type label
function LandingOps.countUnitsInEachArea(config)
  return AmphibiousAssault.countUnitsInEachArea(config)
end

return LandingOps
