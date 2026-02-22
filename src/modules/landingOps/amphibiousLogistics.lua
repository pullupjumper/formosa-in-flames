local GameApi = require("src.utils.gameApi")
local AssignMission = require("src.modules.assignMission")
local constants = require("src.core.constants")
local Logger = require("src.utils.logger")

local AmphibiousLogistics = {}

-- ============================================================================
-- Enumerations and Constants
-- ============================================================================

local SIDE_NAME = "China"

local MISSION_TYPE = {
  CARGO = "Cargo",
}

local AMPHIB_LOGISTICS_TAG = "amphibiousLogistics"

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
}

---@type {dbids: number[], manifestKey: string, transfers: {platform: string, configKey: string, loadoutIdx: integer}[], assignments: {platform: string, configKey: string}[]}[]
local SHIP_TRANSFER_SPECS = {
  {
    dbids = { constants.PLATFORMS.TYPE_075, constants.PLATFORMS.TYPE_076 },
    manifestKey = "type075",
    transfers = {
      { platform = constants.PLATFORM_TYPES.BOATS,    configKey = "boat",                loadoutIdx = 1 },
      { platform = constants.PLATFORM_TYPES.AIRCRAFT, configKey = "transportHelicopter", loadoutIdx = 1 },
      { platform = constants.PLATFORM_TYPES.AIRCRAFT, configKey = "transportHelicopter", loadoutIdx = 2 },
    },
    assignments = {
      { platform = constants.PLATFORM_TYPES.BOATS,    configKey = "boat" },
      { platform = constants.PLATFORM_TYPES.AIRCRAFT, configKey = "transportHelicopter" },
      { platform = constants.PLATFORM_TYPES.AIRCRAFT, configKey = "attackHelicopter" },
    },
  },
  {
    dbids = { constants.PLATFORMS.TYPE_071 },
    manifestKey = "type071",
    transfers = {
      { platform = constants.PLATFORM_TYPES.BOATS,    configKey = "boat",                loadoutIdx = 1 },
      { platform = constants.PLATFORM_TYPES.AIRCRAFT, configKey = "transportHelicopter", loadoutIdx = 1 },
    },
    assignments = {
      { platform = constants.PLATFORM_TYPES.BOATS,    configKey = "boat" },
      { platform = constants.PLATFORM_TYPES.AIRCRAFT, configKey = "transportHelicopter" },
    },
  },
}

-- ============================================================================
-- Cargo Operations
-- ============================================================================

---Collect GUIDs of cargo elements matching a specific DBID up to requested quantity
---@param cargoList CMO__Cargo[] Cargo element array from unit
---@param dbid number Target cargo DBID
---@param maxCount number Maximum items to collect
---@return string[] # Array of matching cargo GUIDs
local function collectMatchingCargos(cargoList, dbid, maxCount)
  local guids = {}
  for _, element in ipairs(cargoList) do
    if element.dbid == dbid then
      table.insert(guids, element.guid)
      if #guids == maxCount then break end
    end
  end
  return guids
end

---Transfer cargo from source unit to destination unit
---Deletes matching cargo from source and creates matching quantity on destination
---@param fromUnit CMO__Unit Source unit (typically the mother ship)
---@param toUnit CMO__Unit Destination unit (aircraft or boat to receive cargo)
---@param cargoItem SBJ__CargoDescriptor Cargo specification (type, DBID, quantity)
function AmphibiousLogistics.updateCargo(fromUnit, toUnit, cargoItem)
  if fromUnit == nil or
      fromUnit.cargo == nil or
      fromUnit.cargo[1] == nil or
      fromUnit.cargo[1].cargo == nil then
    return
  end

  local guids = collectMatchingCargos(fromUnit.cargo[1].cargo, cargoItem.dbid, cargoItem.num)
  for _, guid in ipairs(guids) do
    fromUnit:deleteUnitCargo(guid)
  end
  for _ = 1, #guids do
    toUnit:createUnitCargo(cargoItem.type, cargoItem.dbid)
  end
end

---Delete specified cargo from a unit
---Returns the actual number of items deleted (may be less than requested)
---@param fromUnit CMO__Unit Unit to remove cargo from
---@param cargoItem SBJ__CargoDescriptor Cargo specification (type, DBID, quantity)
---@return integer # Number of cargo items actually deleted
function AmphibiousLogistics.deleteCargo(fromUnit, cargoItem)
  if fromUnit == nil or
      fromUnit.cargo == nil or
      cargoItem.num == 0 or
      (fromUnit.cargo and fromUnit.cargo[1] == nil) then
    return 0
  end

  local guids = collectMatchingCargos(fromUnit.cargo[1].cargo, cargoItem.dbid, cargoItem.num)
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
---@param unit CMO__Unit Embarked unit to check
---@param platformType string Platform type (Aircraft or Boats)
---@param platformDBID number Target DBID
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

---Transfer cargo from base to multiple embarked units matching platform spec
---Distributes cargo to embarked platforms matching DBID/loadout, supports per-unit or shared cargo lists
---@param fromUnit string GUID of the base unit containing embarked platforms
---@param platformType string Type of embarked unit ('Aircraft' or 'Boats')
---@param platformDBID number Database ID of the platform to receive cargo
---@param loadoutDBID number Loadout ID for aircraft filtering (ignored for boats)
---@param cargoItems table<integer, SBJ__CargoDescriptor[]> Cargo items to transfer (single list or per-unit)
function AmphibiousLogistics.transferCargo(fromUnit, platformType, platformDBID, loadoutDBID, cargoItems)
  local base = GameApi.ScenEdit_GetUnit(fromUnit)
  if not base then return end

  local platforms = base.embarkedUnits[platformType]
  if not platforms then return end

  for idx, guid in ipairs(platforms) do
    local unit = GameApi.ScenEdit_GetUnit(guid)
    if unit and isPlatformMatch(unit, platformType, platformDBID, loadoutDBID) then
      local items = cargoItems[idx] or cargoItems[1]
      for _, item in ipairs(items) do
        AmphibiousLogistics.updateCargo(base, unit, item)
      end
    end
  end
end

-- ============================================================================
-- Ship Type Dispatch
-- ============================================================================

---Find matching transfer spec for a ship DBID
---@param shipDbid number Ship platform DBID
---@return {dbids: number[], manifestKey: string, transfers: {platform: string, configKey: string, loadoutIdx: integer}[], assignments: {platform: string, configKey: string}[]}|nil # Matching spec or nil
local function findTransferSpec(shipDbid)
  for _, spec in ipairs(SHIP_TRANSFER_SPECS) do
    for _, dbid in ipairs(spec.dbids) do
      if shipDbid == dbid then return spec end
    end
  end
  return nil
end

---Execute cargo transfers for a single ship based on matching spec
---@param shipGuid string Ship GUID
---@param shipDbid number Ship DBID
---@param zone SBJ__OperationalZoneDescriptor Operational zone config
local function processShipTransfers(shipGuid, shipDbid, zone)
  local spec = findTransferSpec(shipDbid)
  if not spec then return end

  for _, transfer in ipairs(spec.transfers) do
    local cfg = zone[transfer.configKey]
    local manifest = cfg.transferManifest[spec.manifestKey][transfer.loadoutIdx]
    AmphibiousLogistics.transferCargo(shipGuid, transfer.platform, cfg.dbid, manifest.loadoutId, manifest.cargoItems)
  end
end

---Execute mission assignments for a single ship based on matching spec
---@param shipGuid string Ship GUID
---@param shipDbid number Ship DBID
---@param zone SBJ__OperationalZoneDescriptor Operational zone config
local function processShipAssignments(shipGuid, shipDbid, zone)
  local spec = findTransferSpec(shipDbid)
  if not spec then return end

  for _, assignment in ipairs(spec.assignments) do
    local cfg = zone[assignment.configKey]
    AssignMission.assignEmbarkedUnitsToMissions(shipGuid, assignment.platform, cfg.dbid, cfg.missions)
  end
end

-- ============================================================================
-- Cargo Mission Creation
-- ============================================================================

---Create a cargo transport mission with configured doctrine
---@param platformType string Platform config key (e.g., "boat", "transportHelicopter")
---@param zone SBJ__OperationalZoneDescriptor Operation zone descriptor
---@param missionName string Name for the cargo mission
---@return boolean # True if mission was successfully created and configured
local function createSingleCargoMission(platformType, zone, missionName)
  local descriptor = zone[platformType]
  local m = GameApi.ScenEdit_AddMission(SIDE_NAME, missionName, MISSION_TYPE.CARGO, { zone = descriptor.zone })
  if not m then return false end

  m = GameApi.ScenEdit_SetMission(SIDE_NAME, missionName, descriptor.settings)
  if not m then return false end

  m = GameApi.ScenEdit_SetDoctrine({ side = SIDE_NAME, mission = missionName }, { automatic_evasion = false })
  if not m then return false end

  return true
end

-- ============================================================================
-- Public API
-- ============================================================================

---Get units in anchorage area and check their movement status
---Filters amphibious ships (LHD/LPD/LST) and determines if all are ready for cargo operations
---@param amphibOpsConfig SBJ__AmphibOpsConfig Amphibious operation configuration
---@param filteredUnits CMO__SideUnit Unit list from the side (filtered for ships)
---@return { units: CMO__Unit[], isUnitMoving: boolean } # Units in anchorage and movement status
function AmphibiousLogistics.getUnitsInAnchorageArea(amphibOpsConfig, filteredUnits)
  local operationalZones = amphibOpsConfig.operationalZones
  local unitsInAnchorageArea = {}
  local isUnitMoving = false

  for _, u in ipairs(filteredUnits) do
    local unit = GameApi.ScenEdit_GetUnit(u.guid)

    if unit and AMPHIBIOUS_SHIP_DBIDS[unit.dbid] then
      if unit.unitstate ~= "Unassigned" then
        isUnitMoving = true
        break
      end

      for _, zone in ipairs(operationalZones) do
        if unit:inArea(zone.anchorageArea) or unit:inArea(zone.lstAnchorageArea) then
          table.insert(unitsInAnchorageArea, unit)
        end
      end
    end
  end

  return { units = unitsInAnchorageArea, isUnitMoving = isUnitMoving }
end

---Create cargo transport missions for all operational zones
---Sets up ferry missions for landing craft and transport helicopters with configured doctrine
---@param amphibOpsConfig SBJ__AmphibOpsConfig Amphibious operation configuration
---@return boolean # True if all cargo missions were successfully created
function AmphibiousLogistics.createCargoMissions(amphibOpsConfig)
  local operationalZones = amphibOpsConfig.operationalZones
  local logEntries = {}

  for _, zone in ipairs(operationalZones) do
    for _, mission in ipairs(zone.boat.missions) do
      local result = createSingleCargoMission("boat", zone, mission.name)
      if not result then return false end
      table.insert(logEntries, string.format("  [OK] %s", mission.name))
    end

    for _, mission in ipairs(zone.transportHelicopter.missions) do
      local result = createSingleCargoMission("transportHelicopter", zone, mission.name)
      if not result then return false end
      table.insert(logEntries, string.format("  [OK] %s", mission.name))
    end
  end

  if #logEntries > 0 then
    Logger.log(AMPHIB_LOGISTICS_TAG, string.format(
      "Created %d cargo missions\n%s",
      #logEntries, table.concat(logEntries, "\n")
    ))
  end

  return true
end

---Transfer cargo to embarked units and assign them to missions
---Handles Type 075/076 LHDs, Type 071 LPDs, and transport aircraft from other bases
---@param amphibOpsConfig SBJ__AmphibOpsConfig Amphibious operation configuration
---@param unitsInAnchorageArea CMO__Unit[] Ships in anchorage area
---@return boolean # True if all transfers and assignments completed successfully
function AmphibiousLogistics.transferAndAssign(amphibOpsConfig, unitsInAnchorageArea)
  local operationalZones = amphibOpsConfig.operationalZones
  local logEntries = {}

  for _, zone in ipairs(operationalZones) do
    for _, u in ipairs(unitsInAnchorageArea) do
      if u:inArea(zone.anchorageArea) then
        processShipTransfers(u.guid, u.dbid, zone)
        processShipAssignments(u.guid, u.dbid, zone)
        table.insert(logEntries, string.format("  [OK] %s (DBID:%d)", u.name or u.guid, u.dbid))
      end
    end
  end

  for _, item in ipairs(amphibOpsConfig.transportAircraft) do
    AmphibiousLogistics.transferCargo(
      item.guid,
      constants.PLATFORM_TYPES.AIRCRAFT,
      item.dbid,
      item.cargoItemsForTransfer[1].loadoutId,
      item.cargoItemsForTransfer[1].cargoItems
    )
    AssignMission.assignEmbarkedUnitsToMissions(
      item.guid,
      constants.PLATFORM_TYPES.AIRCRAFT,
      item.dbid,
      item.missions
    )
    table.insert(logEntries, string.format("  [OK] Transport aircraft %s", item.name or item.guid))
  end

  if #logEntries > 0 then
    Logger.log(AMPHIB_LOGISTICS_TAG, string.format(
      "Transfer and assign: %d entries\n%s",
      #logEntries, table.concat(logEntries, "\n")
    ))
  end

  return true
end

---Re-transfer cargo to embarked units for second wave operations
---Reloads transport helicopters and landing craft on Type 075/076 and Type 071 ships
---@param amphibOpsConfig SBJ__AmphibOpsConfig Amphibious operation configuration
---@param units CMO__SideUnit[] Unit list from the side (filtered for ships)
---@return boolean # True if all cargo was successfully re-transferred
function AmphibiousLogistics.retransferCargos(amphibOpsConfig, units)
  local operationalZones = amphibOpsConfig.operationalZones
  local logEntries = {}

  for _, zone in ipairs(operationalZones) do
    for _, u in ipairs(units) do
      local unit = GameApi.ScenEdit_GetUnit(u.guid)

      if not unit then
        table.insert(logEntries, string.format("  [SKIP] %s: unit not found", u.guid))
        goto continue
      end

      processShipTransfers(unit.guid, unit.dbid, zone)
      table.insert(logEntries, string.format("  [OK] %s (DBID:%d)", unit.name or unit.guid, unit.dbid))

      ::continue::
    end
  end

  if #logEntries > 0 then
    Logger.log(AMPHIB_LOGISTICS_TAG, string.format(
      "Retransfer cargos: %d entries\n%s",
      #logEntries, table.concat(logEntries, "\n")
    ))
  end

  return true
end

return AmphibiousLogistics
