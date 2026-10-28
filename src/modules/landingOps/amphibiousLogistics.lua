local constants = require("src.core.constants")
local GameApi = require("src.utils.gameApi")
local LogFormat = require("src.utils.logFormat")
local AssignMission = require("src.modules.assignMission")

local AmphibiousLogistics = {}

-- ============================================================================
-- Constants
-- ============================================================================

---Zone group holding each mission platform descriptor
---@type table<string, "landing"|"air">
local PLATFORM_GROUPS = { hovercraft = "landing", transportHelicopter = "air", attackHelicopter = "air" }

---Get a mission platform descriptor of a zone by its config key
---@param zone SBJ__OperationalZoneDescriptor
---@param platformKey string Platform config key (e.g., "hovercraft", "transportHelicopter")
---@return SBJ__HovercraftMissionDescriptor|SBJ__TransportHelicopterDescriptor|SBJ__AttackHelicopterDescriptor
local function getPlatformDescriptor(zone, platformKey)
  return zone[PLATFORM_GROUPS[platformKey]][platformKey]
end

---@type table<number, boolean>
local AMPHIBIOUS_SHIP_DBIDS = {
  [constants.PLATFORMS.TYPE_075]    = true,
  [constants.PLATFORMS.TYPE_071]    = true,
  [constants.PLATFORMS.TYPE_072III] = true,
  [constants.PLATFORMS.TYPE_072A]   = true,
  [constants.PLATFORMS.TYPE_073A]   = true,
  [constants.PLATFORMS.TYPE_072A_2] = true,
  [constants.PLATFORMS.TYPE_076]    = true,
  [constants.PLATFORMS.FERRY]       = true,
  [constants.PLATFORMS.BARGE]       = true,
  [constants.PLATFORMS.TYPE_082]    = true
}

---@type SBJ__ShipTransferRule[]
local SHIP_TRANSFER_RULES = {
  {
    dbids = { constants.PLATFORMS.TYPE_075, constants.PLATFORMS.TYPE_076 },
    manifestKey = "type075",
    transfers = {
      { platform = constants.PLATFORM_TYPES.BOATS,    configKey = "hovercraft",  loadoutIdx = 1 },
      { platform = constants.PLATFORM_TYPES.AIRCRAFT, configKey = "transportHelicopter", loadoutIdx = 1 },
      { platform = constants.PLATFORM_TYPES.AIRCRAFT, configKey = "transportHelicopter", loadoutIdx = 2 },
    },
    -- Hovercraft (BOATS) are routed through the lanes by hovercraft.lua; helicopters by heliWave.lua. Neither takes a mission
  },
  {
    dbids = { constants.PLATFORMS.TYPE_071 },
    manifestKey = "type071",
    transfers = {
      { platform = constants.PLATFORM_TYPES.BOATS,    configKey = "hovercraft",  loadoutIdx = 1 },
      { platform = constants.PLATFORM_TYPES.AIRCRAFT, configKey = "transportHelicopter", loadoutIdx = 1 },
    },
  },
}

-- ============================================================================
-- Cargo Operations
-- ============================================================================

---Find the GUIDs of cargo elements that match a DBID, up to the requested quantity
---@param cargos CMO__Cargo[]
---@param dbid number
---@param maxCount number
---@return string[] # Array of matching cargo GUIDs
local function findMatchingCargos(cargos, dbid, maxCount)
  local guids = {}
  for _, element in ipairs(cargos) do
    if element.dbid == dbid then
      table.insert(guids, element.guid)
      if #guids == maxCount then break end
    end
  end
  return guids
end

---Transfer cargo from a source unit to a destination unit.
---Delete the matching cargo from the source and create the same quantity on the destination.
---@param fromUnit CMO__Unit|nil
---@param toUnit CMO__Unit
---@param cargoItem SBJ__CargoDescriptor
local function transferCargoItem(fromUnit, toUnit, cargoItem)
  if not fromUnit or
      not fromUnit.cargo or
      not fromUnit.cargo[1] or
      not fromUnit.cargo[1].cargo then
    return
  end

  local guids = findMatchingCargos(fromUnit.cargo[1].cargo, cargoItem.dbid, cargoItem.num)
  for _, guid in ipairs(guids) do
    fromUnit:deleteUnitCargo(guid)
  end
  for _ = 1, #guids do
    toUnit:createUnitCargo(cargoItem.type, cargoItem.dbid)
  end
end

---Remove the specified cargo from a unit.
---Return the number of items actually removed. This can be less than requested.
---@param fromUnit CMO__Unit|nil
---@param cargoItem SBJ__CargoDescriptor
---@return integer # Number of cargo items actually deleted
function AmphibiousLogistics.removeCargo(fromUnit, cargoItem)
  if not fromUnit or
      not fromUnit.cargo or
      cargoItem.num == 0 or
      not fromUnit.cargo[1] then
    return 0
  end

  local guids = findMatchingCargos(fromUnit.cargo[1].cargo, cargoItem.dbid, cargoItem.num)
  local resultCount = 0
  for _, guid in ipairs(guids) do
    if fromUnit:deleteUnitCargo(guid) then
      resultCount = resultCount + 1
    end
  end
  return resultCount
end

-- ============================================================================
-- Platform Matching
-- ============================================================================

---Check if an embarked unit matches the target platform specification
---@param unit CMO__Unit
---@param platformType string
---@param platformDBID number
---@param loadoutDBID number Target loadout (only checked for Aircraft)
---@return boolean # True if unit matches
local function isPlatformMatch(unit, platformType, platformDBID, loadoutDBID)
  if unit.dbid ~= platformDBID then
    return false
  end
  if platformType == constants.PLATFORM_TYPES.AIRCRAFT then
    return unit.loadoutdbid == loadoutDBID
  end
  return true
end

---Transfer cargo from a base to multiple embarked units that match the platform specification.
---Give cargo to embarked platforms that match the DBID and loadout. Support per-unit and shared cargo lists.
---@param fromUnit string
---@param params SBJ__TransferCargoParams
---@param cargoItems table<integer, SBJ__CargoDescriptor[]> Cargo items to transfer (single list or per-unit)
local function transferCargo(fromUnit, params, cargoItems)
  local platformType, platformDBID = params.platformType, params.platformDBID
  local loadoutDBID = params.loadoutDBID
  local base = GameApi.ScenEdit_GetUnit(fromUnit)
  if not base then return end

  local platforms = base.embarkedUnits[platformType]
  if not platforms then return end

  for idx, guid in ipairs(platforms) do
    local unit = GameApi.ScenEdit_GetUnit(guid)
    if unit and isPlatformMatch(unit, platformType, platformDBID, loadoutDBID) then
      local items = cargoItems[idx] or cargoItems[1]
      for _, item in ipairs(items) do
        transferCargoItem(base, unit, item)
      end
    end
  end
end

-- ============================================================================
-- Ship Type Dispatch
-- ============================================================================

---Find matching transfer rule for a ship DBID
---@param shipDbid number
---@return SBJ__ShipTransferRule|nil # Matching rule or nil
local function findTransferRule(shipDbid)
  for _, rule in ipairs(SHIP_TRANSFER_RULES) do
    for _, dbid in ipairs(rule.dbids) do
      if shipDbid == dbid then return rule end
    end
  end
  return nil
end

---Process the cargo transfers of a single ship with its matching rule
---@param shipGuid string
---@param shipDbid number
---@param zone SBJ__OperationalZoneDescriptor
local function processShipTransfers(shipGuid, shipDbid, zone)
  local rule = findTransferRule(shipDbid)
  if not rule then return end

  for _, transfer in ipairs(rule.transfers) do
    local cfg = getPlatformDescriptor(zone, transfer.configKey)
    local manifest = cfg.transferManifest[rule.manifestKey][transfer.loadoutIdx]
    transferCargo(
      shipGuid,
      { platformType = transfer.platform, platformDBID = cfg.dbid, loadoutDBID = manifest.loadoutId },
      manifest.cargoItems
    )
  end
end

-- ============================================================================
-- Public API
-- ============================================================================

---Get the units in the holding areas and check their movement status.
---Filter the amphibious ships (LHD/LPD/LST) and check if all are ready for cargo operations.
---@param zone SBJ__OperationalZoneDescriptor
---@param filteredUnits CMO__SideUnit
---@return { units: CMO__Unit[], isUnitMoving: boolean } # Units in holding areas and movement status
function AmphibiousLogistics.getUnitsInHoldingAreas(zone, filteredUnits)
  local unitsInHoldingAreas = {}
  local isUnitMoving = false

  for _, u in ipairs(filteredUnits) do
    local unit = GameApi.ScenEdit_GetUnit(u.guid)

    if unit and AMPHIBIOUS_SHIP_DBIDS[unit.dbid] then
      local isInHoldingArea = unit:inArea(zone.movement.holdingAreas.mothership)
          or unit:inArea(zone.movement.holdingAreas.deployLine)

      -- filteredUnits spans every zone. Only the ships of this zone can delay its arrival
      if isInHoldingArea or unit:inArea(zone.fleet.stagingArea) then
        if unit.unitstate ~= "Unassigned" then
          isUnitMoving = true
          break
        end

        if isInHoldingArea then
          table.insert(unitsInHoldingAreas, unit)
        end
      end
    end
  end

  return { units = unitsInHoldingAreas, isUnitMoving = isUnitMoving }
end

---Transfer cargo to the embarked units of Type 075/076 LHDs and Type 071 LPDs.
---@param zone SBJ__OperationalZoneDescriptor
---@param unitsInHoldingAreas CMO__Unit[]
---@return boolean # True if all transfers completed
function AmphibiousLogistics.transferAndAssign(zone, unitsInHoldingAreas)
  local report = LogFormat.report(
    constants.TAGS.AMPHIBIOUS_LOGISTICS, "zone=" .. zone.name, "Transfer and assign")

  for _, u in ipairs(unitsInHoldingAreas) do
    if u:inArea(zone.movement.holdingAreas.mothership) then
      processShipTransfers(u.guid, u.dbid, zone)
      report.add("OK", { ship = u.name or u.guid, dbid = u.dbid })
    end
  end

  report.emit()

  return true
end

---Transfer cargo and assign missions for a zone's land-based transport aircraft
---@param transportAircraft SBJ__TransportAircraftDescriptor
---@return boolean # True if all transfers completed
function AmphibiousLogistics.transferAndAssignTransportAircraft(transportAircraft)
  local report = LogFormat.report(
    constants.TAGS.AMPHIBIOUS_LOGISTICS, "transportAircraft", "Transfer and assign")

  transferCargo(
    transportAircraft.guid,
    {
      platformType = constants.PLATFORM_TYPES.AIRCRAFT,
      platformDBID = transportAircraft.dbid,
      loadoutDBID = transportAircraft.cargoItemsForTransfer[1].loadoutId
    },
    transportAircraft.cargoItemsForTransfer[1].cargoItems
  )
  AssignMission.assignEmbarkedUnitsToMissions(
    transportAircraft.guid,
    constants.PLATFORM_TYPES.AIRCRAFT,
    transportAircraft.dbid,
    transportAircraft.missions
  )
  report.add("OK", { aircraft = transportAircraft.name or transportAircraft.guid, dbid = transportAircraft.dbid })

  report.emit()

  return true
end

---Transfer the remaining cargo to embarked units for admin offloading.
---Reload transport helicopters and landing craft on Type 075/076 and Type 071 ships.
---@param zone SBJ__OperationalZoneDescriptor
---@param units CMO__SideUnit[]
---@return boolean # True if all remaining cargo was transferred
function AmphibiousLogistics.transferRemainingCargos(zone, units)
  local report = LogFormat.report(
    constants.TAGS.AMPHIBIOUS_LOGISTICS, "zone=" .. zone.name, "Transfer remaining cargos")

  for _, u in ipairs(units) do
    local unit = GameApi.ScenEdit_GetUnit(u.guid)

    if not unit then
      report.add("SKIP", { guid = u.guid, reason = "unit_not_found" })
    else
      processShipTransfers(unit.guid, unit.dbid, zone)
      report.add("OK", { ship = unit.name or unit.guid, dbid = unit.dbid })
    end
  end

  report.emit()

  return true
end

return AmphibiousLogistics
