local constants = require("src.core.constants")
local PersistentState = require("src.core.persistentState")
local GameApi = require("src.utils.gameApi")
local GameUtils = require("src.utils.gameUtils")
local LogFormat = require("src.utils.logFormat")
local Logger = require("src.utils.logger")
local AttackManager = require("src.modules.attackManager")
local AcvWave = require("src.modules.landingOps.acvWave")
local AdminOffloading = require("src.modules.landingOps.adminOffloading")
local AmphibiousAssault = require("src.modules.landingOps.amphibiousAssault")
local Coordinator = require("src.modules.landingOps.coordinator")
local DebugFlow = require("src.modules.landingOps.debugFlow")
local RoutePlanner = require("src.modules.landingOps.routePlanner")
local ShipMovement = require("src.modules.landingOps.shipMovement")

local LandingOps = {}

-- ============================================================================
-- Helpers
-- ============================================================================

---Build the per-ACV course callback. It plans a course through the cleared lanes to a parking slot
---and counts the ACV against the wave quota. It falls back to the zone destination when no lane has room.
---@param amphibOps SBJ__AmphibOpsConfig
---@param zone SBJ__OperationalZoneDescriptor
---@param zoneState SBJ__ZoneState
---@return fun(unit: CMO__Unit, acvKey: string): CMO__Location[]
local function buildACVRouter(amphibOps, zone, zoneState)
  zoneState.queueCounters = zoneState.queueCounters or {}
  zoneState.laneSlots = zoneState.laneSlots or {}
  zoneState.laneSlots.acv = zoneState.laneSlots.acv or {}

  return function(unit, acvKey)
    AcvWave.addACV(zoneState, acvKey, unit.guid)

    local plan = zoneState.lanes and RoutePlanner.buildRoute({
      lanes = zoneState.lanes,
      launchPos = { latitude = unit.latitude, longitude = unit.longitude },
      guid = unit.guid,
      routeConfig = amphibOps.tuning.route,
      queueCounters = zoneState.queueCounters,
      laneSlots = zoneState.laneSlots.acv,
      cells = zoneState.obstacle and zoneState.obstacle.cells,
      isAlive = GameUtils.hasUnit,
    })

    if not plan then
      Logger.warn(LogFormat.line("WARN", { zone = zone.name, unit = unit.guid, reason = "no_cleared_lane_slot" }))
      return zone.landing.acv.destination
    end
    if DebugFlow.isLandingTeleport(amphibOps) then
      DebugFlow.teleport(unit.guid, plan.course[#plan.course])
    end
    return plan.course
  end
end

---Find a SAG descriptor by group name across all zones
---@param zones SBJ__OperationalZoneDescriptor[]
---@param groupName string
---@return SBJ__SAGDescriptor|nil
local function findSAG(zones, groupName)
  for _, zone in ipairs(zones) do
    for _, sag in ipairs(zone.sags) do
      if sag.groupName == groupName then
        return sag
      end
    end
  end

  return nil
end

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

---Launch amphibious combat vehicles for a ship after its zone reaches the assault landing.
---A paused wave leaves the ship waiting at the launch line. An empty ship returns to base.
---@param config SBJ__Config
---@param saveData SBJ__SaveData
---@param ship CMO__Unit
---@return boolean # True if the launch workflow was handled
function LandingOps.launchACV(config, saveData, ship)
  if not AmphibiousAssault.isFerryOrLST(ship) then
    return false
  end

  local amphibOps = config.red.amphibOps

  local zone = AmphibiousAssault.getShipZone(amphibOps.zones, ship)
  if not zone then
    return false
  end

  local zoneState = PersistentState.landingOps(saveData).amphibOps.zoneStates[zone.name]
  if not zoneState or not constants.AMPHIBIOUS_LANDING_PHASES[zoneState.phase] then
    return false
  end

  local result = AmphibiousAssault.launchACV({
    ship = ship,
    num = 5,
    bearing = zone.heading,
    distance = zone.landing.acv.distance,
    quota = AcvWave.getQuota(zoneState, amphibOps.tuning.acvWave, GameApi.ScenEdit_CurrentTime()),
    routeACV = buildACVRouter(amphibOps, zone, zoneState),
  })

  if result and result.isEmpty then
    local hosted = GameApi.ScenEdit_HostUnitToParent({
      HostedUnitNameOrID = ship.guid,
      SelectedBaseNameOrID = zone.movement.baseGUID
    })

    if not hosted then
      return false
    end

    ship:RTB(true)
  end

  return true
end

---Offload vehicles in the workflow for barge and RORO event units
---@param config SBJ__Config
---@param saveData SBJ__SaveData
---@param ship CMO__Unit
---@return boolean # True if the offload workflow was handled
function LandingOps.offloadVehicles(config, saveData, ship)
  local barges = PersistentState.landingOps(saveData).amphibOps.barges

  if ship.name == "Barge" and not AdminOffloading.hasExtendedBridge(barges, ship) then
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

  if ship.name == "Barge" and not AdminOffloading.isBridgeDestroyed(barges, ship) then
    for _, guid in ipairs(barges[ship.guid].roros) do
      local roro = GameApi.ScenEdit_GetUnit(guid)

      if roro then
        local zone = AdminOffloading.getBargeROROZone(
          config.red.amphibOps.zones, ship, roro, config.red.amphibOps.bargeRoroPairingRangeNm)

        if zone then
          AdminOffloading.offloadVehicles({
            ship = roro,
            num = 20,
            bearing = zone.heading,
            distance = zone.landing.acv.distance,
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

---Attack airlanding zone contacts with SAG surface fire support
---@param config SBJ__Config
---@param ship CMO__Unit
---@return boolean # True if the attack workflow was handled
function LandingOps.attackAirlandingZone(config, ship)
  if not ship.group or ship.dbid ~= constants.PLATFORMS.TYPE_052D then
    return false
  end

  local sagConfig = findSAG(config.red.amphibOps.zones, ship.group.name)
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

  if #filteredContacts == 0 then
    return false
  end

  GameApi.ScenEdit_SetDoctrine(
    { side = ship.side, unitname = ship.group.name },
    { weapon_control_status_land = constants.WCS.FREE }
  )

  AttackManager.attackContacts({
    contacts = filteredContacts,
    qty = math.floor(config.red.amphibOps.airlandingFireQty / #filteredContacts),
    firingUnits = { ship },
    weaponDBID = constants.WEAPONS.HPJ_38,
  })

  return true
end

---Count landed China units by type in each operational zone's CAS area
---@param config SBJ__Config
---@return table<string, table<string, number>> # Unit counts keyed by zone name, then by unit type label
function LandingOps.countUnitsInEachArea(config)
  return AmphibiousAssault.countUnitsInEachArea(config.red.amphibOps.zones)
end

return LandingOps
