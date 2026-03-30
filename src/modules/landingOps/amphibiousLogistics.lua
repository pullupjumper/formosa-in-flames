local GameApi = require("src.utils.gameApi")
local AssignMission = require("src.modules.assignMission")
local constants = require("src.core.constants")
local Logger = require("src.utils.logger")

local AmphibiousLogistics = {}

-- ============================================================================
-- Enumerations and Constants
-- ============================================================================

local MISSION_TYPE = {
  CARGO = "Cargo",
}

local AMPHIB_LOGISTICS_TAG = "amphibiousLogistics"

local CARGO_ENTRY = {
  TYPE = 3,
  QUANTITY = 1,
}

local WEAPON_CLEAR_AMOUNT = 999

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
-- Unit-to-Cargo Conversion
-- ============================================================================

---Normalize weapon DBID input to a set for fast lookup
---@param weaponDBID number|number[]|nil Weapon DBID(s) to normalize
---@return table<number, boolean> # Set of weapon DBIDs
local function normalizeWeaponDBIDs(weaponDBID)
  if not weaponDBID then return {} end
  local set = {}
  if type(weaponDBID) == "table" then
    for _, id in pairs(weaponDBID) do set[id] = true end
  else
    set[weaponDBID] = true
  end
  return set
end

---Create a cargo proxy unit on a base ship for a given unit DBID
---@param base CMO__Unit Base ship to load cargo onto
---@param unitDbid number Database ID of the unit to add as cargo
---@param idx integer Index position in the cargo list
---@param sideName string Side name
---@return CMO__Unit|nil # Cargo proxy unit, or nil if creation failed
local function createCargoProxy(base, unitDbid, idx, sideName)
  GameApi.ScenEdit_UpdateUnitCargo({
    guid = base.guid,
    mode = "add_cargo",
    cargo = { { CARGO_ENTRY.QUANTITY, unitDbid, CARGO_ENTRY.TYPE } }
  })

  if not base.cargo or not base.cargo[1] or not base.cargo[1].cargo then
    return nil
  end

  local cargoEntry = base.cargo[1].cargo[idx]
  if not cargoEntry then return nil end

  return GameApi.ScenEdit_GetUnit(cargoEntry.guid, sideName)
end

---Clear all magazines and remove all mounts from a cargo proxy unit
---@param cargo CMO__Unit Cargo proxy unit to strip
---@param sideName string Side name
local function stripCargoProxyMounts(cargo, sideName)
  GameApi.ScenEdit_ClearAllMagazines({ side = sideName, guid = cargo.guid })

  for _, mount in ipairs(cargo.mounts) do
    GameApi.ScenEdit_UpdateUnit({
      guid = cargo.guid,
      mode = "remove_mount",
      dbid = mount.mount_dbid,
      mountid = mount.mount_guid
    })
  end
end

---Clone mount points from source unit to cargo proxy and tally tracked weapons
---@param sourceUnit CMO__Unit Source unit with mounts to clone
---@param cargo CMO__Unit Cargo proxy unit to receive mounts
---@param weaponDBIDSet table<number, boolean> Set of weapon DBIDs to track
---@return table<number, number> # Weapon DBID to current count mapping
local function cloneMountsAndTallyWeapons(sourceUnit, cargo, weaponDBIDSet)
  local weaponCounts = {}

  for _, mount in ipairs(sourceUnit.mounts) do
    GameApi.ScenEdit_UpdateUnit({
      guid = cargo.guid,
      mode = "add_mount",
      dbid = mount.mount_dbid,
      arc_mount = constants.SENSOR_ARCS
    })

    if #mount.mount_weapons > 0 and next(weaponDBIDSet) then
      for _, wpn in ipairs(mount.mount_weapons) do
        if weaponDBIDSet[wpn.wpn_dbid] then
          weaponCounts[wpn.wpn_dbid] = (weaponCounts[wpn.wpn_dbid] or 0) + wpn.wpn_current
        end
      end
    end
  end

  return weaponCounts
end

---Synchronize weapon reload counts on a cargo proxy unit
---Clears all tracked weapon reloads then sets them to actual counts
---@param cargo CMO__Unit Cargo proxy unit
---@param sideName string Side name
---@param weaponCounts table<number, number> Actual weapon counts (DBID to count)
local function syncWeaponReloads(cargo, sideName, weaponCounts)
  for _, mount in ipairs(cargo.mounts) do
    for _, wpn in ipairs(mount.mount_weapons) do
      if wpn.wpn_default > 0 then
        GameApi.ScenEdit_AddReloadsToUnit({
          side = sideName,
          guid = cargo.guid,
          wpn_dbid = wpn.wpn_dbid,
          number = WEAPON_CLEAR_AMOUNT,
          remove = true
        })
      end
    end
  end

  for wpnDBID, count in pairs(weaponCounts) do
    GameApi.ScenEdit_AddReloadsToUnit({
      side = sideName,
      guid = cargo.guid,
      wpn_dbid = wpnDBID,
      number = count
    })
  end
end

---Convert a single group member unit to a cargo proxy on a base ship
---Creates cargo proxy, resets loadout, clones mounts and weapons, then removes original
---@param base CMO__Unit Base ship to load cargo onto
---@param sourceUnit CMO__Unit Source unit to convert
---@param idx integer Index in group unit list
---@param weaponDBIDSet table<number, boolean> Set of weapon DBIDs to track
---@param sideName string Side name
---@return string tag "OK" or "FAIL"
---@return string msg Description of the result
local function convertGroupMember(base, sourceUnit, idx, weaponDBIDSet, sideName)
  local cargo = createCargoProxy(base, sourceUnit.dbid, idx, sideName)
  if not cargo then
    return "FAIL", string.format("%s: cargo proxy creation failed", sourceUnit.name or sourceUnit.guid)
  end

  stripCargoProxyMounts(cargo, sideName)
  local weaponCounts = cloneMountsAndTallyWeapons(sourceUnit, cargo, weaponDBIDSet)
  syncWeaponReloads(cargo, sideName, weaponCounts)

  if sourceUnit.group then
    cargo.group = sourceUnit.group.name
  end
  cargo.name = sourceUnit.name

  GameApi.ScenEdit_DeleteUnit({ guid = sourceUnit.guid })

  return "OK", sourceUnit.name or sourceUnit.guid
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
  local m = GameApi.ScenEdit_AddMission(constants.SIDES.ENEMY, missionName, MISSION_TYPE.CARGO,
    { zone = descriptor.zone })
  if not m then return false end

  m = GameApi.ScenEdit_SetMission(constants.SIDES.ENEMY, missionName, descriptor.settings)
  if not m then return false end

  m = GameApi.ScenEdit_SetDoctrine({ side = constants.SIDES.ENEMY, mission = missionName }, { automatic_evasion = false })
  if not m then return false end

  return true
end

-- ============================================================================
-- Public API
-- ============================================================================

---Get units in anchorage area and check their movement status
---Filters amphibious ships (LHD/LPD/LST) and determines if all are ready for cargo operations
---@param zone SBJ__OperationalZoneDescriptor Operational zone descriptor
---@param filteredUnits CMO__SideUnit Unit list from the side (filtered for ships)
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

      if unit:inArea(zone.anchorageArea) or unit:inArea(zone.lstAnchorageArea) then
        table.insert(unitsInAnchorageArea, unit)
      end
    end
  end

  return { units = unitsInAnchorageArea, isUnitMoving = isUnitMoving }
end

---Create cargo transport missions for an operational zone
---Sets up ferry missions for landing craft and transport helicopters with configured doctrine
---@param zone SBJ__OperationalZoneDescriptor Operational zone descriptor
---@return boolean # True if all cargo missions were successfully created
function AmphibiousLogistics.createCargoMissions(zone)
  local logEntries = {}

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

  if #logEntries > 0 then
    Logger.log(AMPHIB_LOGISTICS_TAG, string.format(
      "[%s] Created cargo missions: %d entries\n%s",
      zone.name, #logEntries, table.concat(logEntries, "\n")
    ))
  end

  return true
end

---Transfer cargo to embarked units and assign them to missions
---Handles Type 075/076 LHDs, Type 071 LPDs, and transport aircraft from other bases
---@param zone SBJ__OperationalZoneDescriptor Operational zone descriptor
---@param unitsInAnchorageArea CMO__Unit[] Ships in anchorage area
---@return boolean # True if all transfers and assignments completed successfully
function AmphibiousLogistics.transferAndAssign(zone, unitsInAnchorageArea)
  local logEntries = {}

  for _, u in ipairs(unitsInAnchorageArea) do
    if u:inArea(zone.anchorageArea) then
      processShipTransfers(u.guid, u.dbid, zone)
      processShipAssignments(u.guid, u.dbid, zone)
      table.insert(logEntries, string.format("  [OK] %s (DBID:%d)", u.name or u.guid, u.dbid))
    end
  end

  if #logEntries > 0 then
    Logger.log(AMPHIB_LOGISTICS_TAG, string.format(
      "[%s] Transfer and assign: %d entries\n%s",
      zone.name, #logEntries, table.concat(logEntries, "\n")
    ))
  end

  return true
end

---Transfer cargo and assign missions for land-based transport aircraft
---@param transportAircraft SBJ__TransportAircraftDescriptor[] Transport aircraft configuration
---@return boolean # True if all transfers and assignments completed successfully
function AmphibiousLogistics.transferAndAssignTransportAircraft(transportAircraft)
  local logEntries = {}

  for _, item in ipairs(transportAircraft) do
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
      "Transfer and assign transport aircraft: %d entries\n%s",
      #logEntries, table.concat(logEntries, "\n")
    ))
  end

  return true
end

---Simulate loading ground units onto a ship by creating cargo proxies
---Resolves unit group, clones weapon loadouts to cargo proxies, and removes originals
---@param base CMO__Unit Base ship to load cargo onto
---@param unitCtx SBJ__FiringUnitContext|SBJ__ResupplyUnitContext Unit context with name and optional weapon DBID
---@param sideName string Side name
function AmphibiousLogistics.loadCargo(base, unitCtx, sideName)
  local actualUnit = GameApi.ScenEdit_GetUnit(unitCtx.name, sideName)
  if not actualUnit then return end

  local group = actualUnit.group and actualUnit.group.unitlist or { actualUnit.guid }
  local weaponDBIDSet = normalizeWeaponDBIDs(unitCtx.weaponDBID)
  local logEntries = {}

  for idx, guid in ipairs(group) do
    local unit = GameApi.ScenEdit_GetUnit(guid)
    if not unit then
      table.insert(logEntries, string.format("  [SKIP] #%d %s: unit not found", idx, guid))
    else
      local tag, msg = convertGroupMember(base, unit, idx, weaponDBIDSet, sideName)
      table.insert(logEntries, string.format("  [%s] #%d %s", tag, idx, msg))
    end
  end

  if #logEntries > 0 then
    Logger.log(AMPHIB_LOGISTICS_TAG, string.format(
      "Load cargo onto %s: %d members\n%s",
      base.name or base.guid, #group, table.concat(logEntries, "\n")
    ))
  end
end

---Re-transfer cargo to embarked units for second wave operations
---Reloads transport helicopters and landing craft on Type 075/076 and Type 071 ships
---@param zone SBJ__OperationalZoneDescriptor Operational zone descriptor
---@param units CMO__SideUnit[] Unit list from the side (filtered for ships)
---@return boolean # True if all cargo was successfully re-transferred
function AmphibiousLogistics.retransferCargos(zone, units)
  local logEntries = {}

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

  if #logEntries > 0 then
    Logger.log(AMPHIB_LOGISTICS_TAG, string.format(
      "[%s] Retransfer cargos: %d entries\n%s",
      zone.name, #logEntries, table.concat(logEntries, "\n")
    ))
  end

  return true
end

return AmphibiousLogistics
