local GameApi = require("src.utils.gameApi")
local AssignMission = require("src.modules.assignMission")
local LogFormat = require("src.utils.logFormat")
local constants = require("src.core.constants")

local AmphibiousLogistics = {}

-- ============================================================================
-- Enumerations and Constants
-- ============================================================================

local MISSION_TYPE = {
  CARGO = "Cargo",
}


---Zone config keys whose missions are created as cargo transport missions.
---@type string[]
local CARGO_MISSION_PLATFORMS = { "boat", "transportHelicopter" }

---Zone group holding each mission platform descriptor
---@type table<string, "landing"|"air">
local PLATFORM_GROUPS = { boat = "landing", transportHelicopter = "air", attackHelicopter = "air" }

---Look up a mission platform descriptor of a zone by its config key
---@param zone SBJ__OperationalZoneDescriptor
---@param platformKey string Platform config key (e.g., "boat", "transportHelicopter")
---@return SBJ__BoatMissionDescriptor|SBJ__TransportHelicopterDescriptor|SBJ__AttackHelicopterDescriptor
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
    -- Hovercraft (BOATS) are loaded here but assigned only after routing through the lanes (hovercraft.lua)
    assignments = {
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
      { platform = constants.PLATFORM_TYPES.AIRCRAFT, configKey = "transportHelicopter" },
    },
  },
}

-- ============================================================================
-- Cargo Operations
-- ============================================================================

---Collect GUIDs of cargo elements matching a specific DBID up to requested quantity
---@param cargos CMO__Cargo[]
---@param dbid number
---@param maxCount number
---@return string[] # Array of matching cargo GUIDs
local function collectMatchingCargos(cargos, dbid, maxCount)
  local guids = {}
  for _, element in ipairs(cargos) do
    if element.dbid == dbid then
      table.insert(guids, element.guid)
      if #guids == maxCount then break end
    end
  end
  return guids
end

---Transfer cargo from source unit to destination unit
---Deletes matching cargo from source and creates matching quantity on destination
---@param fromUnit CMO__Unit|nil
---@param toUnit CMO__Unit
---@param cargoItem SBJ__CargoDescriptor
local function updateCargo(fromUnit, toUnit, cargoItem)
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
---@param fromUnit CMO__Unit|nil
---@param cargoItem SBJ__CargoDescriptor
---@return integer # Number of cargo items actually deleted
function AmphibiousLogistics.removeCargo(fromUnit, cargoItem)
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

---Transfer cargo from base to multiple embarked units matching platform spec
---Distributes cargo to embarked platforms matching DBID/loadout, supports per-unit or shared cargo lists
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
        updateCargo(base, unit, item)
      end
    end
  end
end

-- ============================================================================
-- Ship Type Dispatch
-- ============================================================================

---Find matching transfer spec for a ship DBID
---@param shipDbid number
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
---@param shipGuid string
---@param shipDbid number
---@param zone SBJ__OperationalZoneDescriptor
local function processShipTransfers(shipGuid, shipDbid, zone)
  local spec = findTransferSpec(shipDbid)
  if not spec then return end

  for _, transfer in ipairs(spec.transfers) do
    local cfg = getPlatformDescriptor(zone, transfer.configKey)
    local manifest = cfg.transferManifest[spec.manifestKey][transfer.loadoutIdx]
    transferCargo(
      shipGuid,
      { platformType = transfer.platform, platformDBID = cfg.dbid, loadoutDBID = manifest.loadoutId },
      manifest.cargoItems
    )
  end
end

---Execute mission assignments for a single ship based on matching spec
---@param shipGuid string
---@param shipDbid number
---@param zone SBJ__OperationalZoneDescriptor
local function processShipAssignments(shipGuid, shipDbid, zone)
  local spec = findTransferSpec(shipDbid)
  if not spec then return end

  for _, assignment in ipairs(spec.assignments) do
    local cfg = getPlatformDescriptor(zone, assignment.configKey)
    AssignMission.assignEmbarkedUnitsToMissions(shipGuid, assignment.platform, cfg.dbid, cfg.missions)
  end
end

-- ============================================================================
-- Cargo Mission Creation
-- ============================================================================

---Create a cargo transport mission with configured doctrine
---@param platformType string Platform config key (e.g., "boat", "transportHelicopter")
---@param zone SBJ__OperationalZoneDescriptor
---@param missionName string
---@return boolean success True if mission was successfully created and configured
---@return SBJ__LogResult result Deferred log result describing the outcome
local function createSingleCargoMission(platformType, zone, missionName)
  local descriptor = getPlatformDescriptor(zone, platformType)
  local reason

  if not GameApi.ScenEdit_AddMission(
        constants.SIDES.RED, missionName, MISSION_TYPE.CARGO, { zone = descriptor.zone }) then
    reason = "add_mission_failed"
  elseif not GameApi.ScenEdit_SetMission(constants.SIDES.RED, missionName, descriptor.settings) then
    reason = "set_mission_failed"
  elseif not GameApi.ScenEdit_SetDoctrine(
        { side = constants.SIDES.RED, mission = missionName }, { automatic_evasion = false }) then
    reason = "set_doctrine_failed"
  end

  if reason then
    return false, { tag = "FAIL", fields = { platform = platformType, mission = missionName, reason = reason } }
  end

  return true, { tag = "OK", fields = { platform = platformType, mission = missionName } }
end

---Create every cargo mission configured for a zone, stopping at the first failure
---@param zone SBJ__OperationalZoneDescriptor
---@return boolean success True when every mission was created
---@return SBJ__LogResult[] results Deferred log results in emission order
local function createZoneCargoMissions(zone)
  local results = {}

  for _, platformType in ipairs(CARGO_MISSION_PLATFORMS) do
    for _, mission in ipairs(getPlatformDescriptor(zone, platformType).missions) do
      local created, result = createSingleCargoMission(platformType, zone, mission.name)
      table.insert(results, result)

      if not created then
        return false, results
      end
    end
  end

  return true, results
end

-- ============================================================================
-- Public API
-- ============================================================================

---Get units in anchorage area and check their movement status
---Filters amphibious ships (LHD/LPD/LST) and determines if all are ready for cargo operations
---@param zone SBJ__OperationalZoneDescriptor
---@param filteredUnits CMO__SideUnit
---@return { units: CMO__Unit[], isUnitMoving: boolean } # Units in anchorage and movement status
function AmphibiousLogistics.getUnitsInAnchorageArea(zone, filteredUnits)
  local unitsInAnchorageArea = {}
  local isUnitMoving = false

  for _, u in ipairs(filteredUnits) do
    local unit = GameApi.ScenEdit_GetUnit(u.guid)

    if unit and AMPHIBIOUS_SHIP_DBIDS[unit.dbid] then
      if unit.unitstate ~= "Unassigned" then
        isUnitMoving = true
        break
      end

      if unit:inArea(zone.anchorage.area) or unit:inArea(zone.anchorage.lstArea) then
        table.insert(unitsInAnchorageArea, unit)
      end
    end
  end

  return { units = unitsInAnchorageArea, isUnitMoving = isUnitMoving }
end

---Create cargo transport missions for an operational zone
---Sets up ferry missions for landing craft and transport helicopters with configured doctrine
---@param zone SBJ__OperationalZoneDescriptor
---@return boolean # True if all cargo missions were successfully created
function AmphibiousLogistics.createCargoMissions(zone)
  local success, results = createZoneCargoMissions(zone)

  local report = LogFormat.report(
    constants.TAGS.AMPHIBIOUS_LOGISTICS, "zone=" .. zone.name, "Create cargo missions")
  report.addAll(results)
  report.emit()

  return success
end

---Transfer cargo to embarked units and assign them to missions
---Handles Type 075/076 LHDs, Type 071 LPDs, and transport aircraft from other bases
---@param zone SBJ__OperationalZoneDescriptor
---@param unitsInAnchorageArea CMO__Unit[]
---@return boolean # True if all transfers and assignments completed successfully
function AmphibiousLogistics.transferAndAssign(zone, unitsInAnchorageArea)
  local report = LogFormat.report(
    constants.TAGS.AMPHIBIOUS_LOGISTICS, "zone=" .. zone.name, "Transfer and assign")

  for _, u in ipairs(unitsInAnchorageArea) do
    if u:inArea(zone.anchorage.area) then
      processShipTransfers(u.guid, u.dbid, zone)
      processShipAssignments(u.guid, u.dbid, zone)
      report.add("OK", { ship = u.name or u.guid, dbid = u.dbid })
    end
  end

  report.emit()

  return true
end

---Transfer cargo and assign missions for land-based transport aircraft
---@param transportAircraft SBJ__TransportAircraftDescriptor[]
---@return boolean # True if all transfers and assignments completed successfully
function AmphibiousLogistics.transferAndAssignTransportAircraft(transportAircraft)
  local report = LogFormat.report(
    constants.TAGS.AMPHIBIOUS_LOGISTICS, "transportAircraft", "Transfer and assign")

  for _, item in ipairs(transportAircraft) do
    transferCargo(
      item.guid,
      {
        platformType = constants.PLATFORM_TYPES.AIRCRAFT,
        platformDBID = item.dbid,
        loadoutDBID = item.cargoItemsForTransfer[1].loadoutId
      },
      item.cargoItemsForTransfer[1].cargoItems
    )
    AssignMission.assignEmbarkedUnitsToMissions(
      item.guid,
      constants.PLATFORM_TYPES.AIRCRAFT,
      item.dbid,
      item.missions
    )
    report.add("OK", { aircraft = item.name or item.guid, dbid = item.dbid })
  end

  report.emit()

  return true
end

---Re-transfer cargo to embarked units for second wave operations
---Reloads transport helicopters and landing craft on Type 075/076 and Type 071 ships
---@param zone SBJ__OperationalZoneDescriptor
---@param units CMO__SideUnit[]
---@return boolean # True if all cargo was successfully re-transferred
function AmphibiousLogistics.retransferCargos(zone, units)
  local report = LogFormat.report(
    constants.TAGS.AMPHIBIOUS_LOGISTICS, "zone=" .. zone.name, "Retransfer cargos")

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
