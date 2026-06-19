local GameApi = require("src.utils.gameApi")
local ShipMovement = require("src.modules.landingOps.shipMovement")
local Coordinator = require("src.modules.landingOps.coordinator")
local AmphibiousAssault = require("src.modules.landingOps.amphibiousAssault")
local SecondWaveUnloading = require("src.modules.landingOps.secondWaveUnloading")
local AttackManager = require("src.modules.attackManager")
local Utils = require("src.utils.utils")
local constants = require("src.core.constants")
local Logger = require("src.utils.logger")

local LandingOps = {}

---Initialize landing operations runtime data
---@param amphibOpsConfig SBJ__AmphibOpsConfig Amphibious operations configuration
---@param saveData SBJ__SaveData Persistent save data
function LandingOps.init(amphibOpsConfig, saveData)
  ShipMovement.calculateDestination(amphibOpsConfig, saveData.c.amphibOps.calculationResult)
end

---Process all landing operation phases for the current event tick
---@param config SBJ__Config Global configuration table
---@param saveData SBJ__SaveData Persistent save data
---@param contacts CMO__Contact[] Contact list from the game
---@param currentTime number Current scenario time in seconds
---@param filteredShips CMO__SideUnit[] Unit list from the side filtered for ships
function LandingOps.process(config, saveData, contacts, currentTime, filteredShips)
  local start_time = os.clock()

  Coordinator.process(config, saveData, contacts, currentTime, filteredShips)
  local end_time = os.clock()
  Logger.log(constants.TAGS.SHIP_MOVEMENT, string.format("spent: %.4f sec", end_time - start_time))
end

---Launch amphibious combat vehicles for a ship when it is in a valid zone
---@param amphibOpsConfig SBJ__AmphibOpsConfig Amphibious operations configuration
---@param ship CMO__Unit Ship unit from the event context
---@return boolean # Whether the launch workflow was handled successfully
function LandingOps.launchACV(amphibOpsConfig, ship)
  if not AmphibiousAssault.isFerryOrLST(ship) then
    return false
  end

  local zone = AmphibiousAssault.getShipZone(amphibOpsConfig, ship)
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
---@param amphibOpsConfig SBJ__AmphibOpsConfig Amphibious operations configuration
---@param saveData SBJ__SaveData Persistent save data
---@param ship CMO__Unit Ship unit from the event context
---@return boolean # Whether the offload workflow was handled successfully
function LandingOps.offloadVehicles(amphibOpsConfig, saveData, ship)
  if ship.name == "Barge" and not SecondWaveUnloading.hasExtendedBridge(saveData, ship) then
    ship.course = nil
    ship.manualSpeed = 0
    ship.holdposition = true

    local bridge = GameApi.ScenEdit_AddUnit({
      side = constants.SIDES.ENEMY,
      type = constants.UNIT_TYPES.FACILITY,
      latitude = ship.latitude,
      longitude = ship.longitude,
      dbid = constants.PLATFORMS.BRIDGE,
      unitname = "bridge",
    })

    if not bridge then
      return false
    end

    saveData.c.amphibOps.barges[ship.guid].bridgeGUID = bridge.guid
  end

  if ship.name == "Barge" and not SecondWaveUnloading.isBridgeDestroyed(saveData, ship) then
    for _, guid in ipairs(saveData.c.amphibOps.barges[ship.guid].roros) do
      local roro = GameApi.ScenEdit_GetUnit(guid)

      if roro then
        local zone = SecondWaveUnloading.getBargeROROZone(amphibOpsConfig, ship, roro)

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
---@param amphibOpsConfig SBJ__AmphibOpsConfig Amphibious operations configuration
---@param ship CMO__Unit Ship unit from the event context
---@param contacts CMO__Contact[] Contact list from the game
---@return boolean # Whether the neutralization workflow was handled successfully
function LandingOps.neutralizeAirlandingZone(amphibOpsConfig, ship, contacts)
  if not ship.group or ship.dbid ~= constants.PLATFORMS.TYPE_052D then
    return false
  end

  local sagConfig = amphibOpsConfig.sag[ship.group.name]
  if not sagConfig then
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

return LandingOps
