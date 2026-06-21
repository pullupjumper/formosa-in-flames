local GameApi = require("src.utils.gameApi")
local Logger = require("src.utils.logger")
local LogFormat = require("src.utils.logFormat")
local constants = require("src.core.constants")
local GameUtils = require("src.utils.gameUtils")
local Shared = require("src.modules.missileSystem.shared")

local Deployment = {}

---Append log entries from one list into another
---@param destination string[] Destination entry list
---@param source string[]|nil Source entry list
local function appendEntries(destination, source)
  if not source then return end

  for _, entry in ipairs(source) do
    table.insert(destination, entry)
  end
end

---Remove missile systems from the game
---@param systemName string Missile system name
---@param role string Unit role
---@param descriptor SBJ__FiringUnitDescriptor Firing unit descriptor with removal info
---@param sideName string Side name for unit deletion
---@return string[] entries Failure log entries
---@return boolean hasFailure Whether any delete operation failed
local function removeMissileSystem(systemName, role, descriptor, sideName)
  local unit = GameApi.ScenEdit_GetUnit(descriptor.name, sideName)
  local entries = {}
  local hasFailure = false

  if unit == nil then
    return entries, hasFailure
  end

  if unit.group and unit.group.unitlist then
    for _, guid in ipairs(unit.group.unitlist) do
      local deleted = GameApi.ScenEdit_DeleteUnit({ side = sideName, guid = guid })
      if not deleted then
        hasFailure = true
        table.insert(entries, LogFormat.entry("FAIL", string.format(
          "system=%s role=%s unit=%q guid=%s reason=delete_unit_failed",
          LogFormat.value(systemName),
          LogFormat.value(role),
          LogFormat.readable(descriptor.name),
          LogFormat.value(guid)
        )))
      end
    end
  else
    local deleted = GameApi.ScenEdit_DeleteUnit({ side = sideName, guid = unit.guid })
    if not deleted then
      hasFailure = true
      table.insert(entries, LogFormat.entry("FAIL", string.format(
        "system=%s role=%s unit=%q guid=%s reason=delete_unit_failed",
        LogFormat.value(systemName),
        LogFormat.value(role),
        LogFormat.readable(descriptor.name),
        LogFormat.value(unit.guid)
      )))
    end
  end

  return entries, hasFailure
end

---Remove unwanted weapons and redistribute ammo for desired weapon types
---@param addedUnit CMO__Unit Unit to clean up weapons for
---@param weaponDBIDs number[] Desired weapon DBIDs to keep
---@param sideName string Side name
---@param systemName string Missile system name
---@param role string Unit role
---@return string[] entries Failure log entries
---@return boolean hasFailure Whether any cleanup operation failed
local function cleanupAndRedistributeWeapons(addedUnit, weaponDBIDs, sideName, systemName, role)
  local entries = {}
  local hasFailure = false
  local cleared = GameApi.ScenEdit_ClearAllMagazines({ side = sideName, guid = addedUnit.guid })
  if not cleared then
    hasFailure = true
    table.insert(entries, LogFormat.entry("FAIL", string.format(
      "system=%s role=%s unit=%q guid=%s reason=clear_magazines_failed",
      LogFormat.value(systemName),
      LogFormat.value(role),
      LogFormat.readable(addedUnit.name),
      LogFormat.value(addedUnit.guid)
    )))
  end

  local weaponDBIDSet = {}
  for _, id in ipairs(weaponDBIDs) do weaponDBIDSet[id] = true end

  local removals = {}
  for _, mount in ipairs(addedUnit.mounts or {}) do
    if #mount.mount_weapons > 1 then
      for _, wpn in ipairs(mount.mount_weapons) do
        if wpn.wpn_current > 0 and not weaponDBIDSet[wpn.wpn_dbid] then
          removals[wpn.wpn_dbid] = (removals[wpn.wpn_dbid] or 0) + wpn.wpn_current
        end
      end
    end
  end

  local totalRemovedCount = 0
  for wpnDbid, count in pairs(removals) do
    local removed = GameApi.ScenEdit_AddReloadsToUnit({
      side = sideName,
      guid = addedUnit.guid,
      wpn_dbid = wpnDbid,
      number = count,
      remove = true
    })
    if not removed then
      hasFailure = true
      table.insert(entries, LogFormat.entry("FAIL", string.format(
        "system=%s role=%s unit=%q guid=%s weapon=%s count=%d reason=remove_reload_failed",
        LogFormat.value(systemName),
        LogFormat.value(role),
        LogFormat.readable(addedUnit.name),
        LogFormat.value(addedUnit.guid),
        LogFormat.value(wpnDbid),
        count
      )))
    end
    totalRemovedCount = totalRemovedCount + count
  end

  if totalRemovedCount > 0 and #weaponDBIDs == 1 then
    local added = GameApi.ScenEdit_AddReloadsToUnit({
      side = sideName,
      guid = addedUnit.guid,
      wpn_dbid = weaponDBIDs[1],
      number = totalRemovedCount,
    })
    if not added then
      hasFailure = true
      table.insert(entries, LogFormat.entry("FAIL", string.format(
        "system=%s role=%s unit=%q guid=%s weapon=%s count=%d reason=add_reload_failed",
        LogFormat.value(systemName),
        LogFormat.value(role),
        LogFormat.readable(addedUnit.name),
        LogFormat.value(addedUnit.guid),
        LogFormat.value(weaponDBIDs[1]),
        totalRemovedCount
      )))
    end
  end

  return entries, hasFailure
end

---Create firing units according to configuration
---@param systemName string Missile system name
---@param systemCfg SBJ__MissileSystemConfig Weapon system configuration
---@param descriptor SBJ__FiringUnitDescriptor Firing unit descriptor
---@param sideName string Side name for unit creation
---@param isSam boolean True if it is SAM
---@return integer created Number of units successfully created
---@return integer expected Total number of units expected to create
---@return string? errorMsg Error message if validation failed
---@return string[] entries Failure log entries
---@return boolean hasFailure Whether any unit creation sub-operation failed
local function addFiringUnit(systemName, systemCfg, descriptor, sideName, isSam)
  if not descriptor.operationalArea.HA or #descriptor.operationalArea.HA == 0 then
    return 0, 0, string.format("No HA defined for firing unit '%s' (OPAREA: %s), cannot add unit",
      descriptor.name, descriptor.operationalArea.name), {}, false
  end

  local haPosition = descriptor.operationalArea.HA[1]
  if not haPosition.course or #haPosition.course == 0 then
    return 0, 0, string.format("No course defined for HA[1] in '%s' (OPAREA: %s), cannot add unit",
      descriptor.name, descriptor.operationalArea.name), {}, false
  end

  local fpPositions = descriptor.operationalArea.FP
  if isSam and (not fpPositions or #fpPositions == 0) then
    return 0, 0, string.format("No FP defined for SAM firing unit '%s' (OPAREA: %s), cannot add unit",
      descriptor.name, descriptor.operationalArea.name), {}, false
  end

  local resupplyDescriptor = systemCfg.resupplyUnits[descriptor.resupplyUnit]
  if not resupplyDescriptor then
    return 0, 0, string.format("No resupply unit '%s' defined for firing unit '%s'",
      tostring(descriptor.resupplyUnit), descriptor.name), {}, false
  end

  local expected = resupplyDescriptor.unitCount
  local size = #haPosition.course
  local unitType = GameUtils.extractUnitType(descriptor.name)
  local created = 0
  local entries = {}
  local hasFailure = false

  for i = 1, expected do
    local name
    if expected == 1 then
      name = descriptor.name
    else
      name = GameUtils.formatOrdinalUnitName(i, unitType or "", ", " .. descriptor.name)
    end

    local lat, lon
    if isSam then
      local fp = fpPositions[math.random(#fpPositions)]
      local fpSize = #fp.course
      lat = fp.course[fpSize].latitude
      lon = fp.course[fpSize].longitude
    else
      lat = haPosition.course[size].latitude
      lon = haPosition.course[size].longitude
    end

    local addedUnit = GameApi.ScenEdit_AddUnit({
      side = sideName,
      unitname = name,
      dbid = descriptor.dbid,
      type = constants.UNIT_TYPES.FACILITY,
      group = expected > 1 and descriptor.name or nil,
      latitude = lat,
      longitude = lon
    })

    if addedUnit then
      if descriptor.mountDescriptors then
        for _, desc in ipairs(descriptor.mountDescriptors) do
          for j = 1, desc.mountCount do
            local updated = GameApi.ScenEdit_UpdateUnit({
              guid = addedUnit.guid,
              mode = "add_mount",
              dbid = desc.dbid,
              arc_mount = constants.SENSOR_ARCS
            })
            if not updated then
              hasFailure = true
              table.insert(entries, LogFormat.entry("FAIL", string.format(
                "system=%s role=firing unit=%q guid=%s mount=%s reason=add_mount_failed",
                LogFormat.value(systemName),
                LogFormat.readable(name),
                LogFormat.value(addedUnit.guid),
                LogFormat.value(desc.dbid)
              )))
            end
          end
        end
      end

      local cleanupEntries, cleanupFailed = cleanupAndRedistributeWeapons(
        addedUnit, Shared.normalizeWeaponDBIDs(descriptor.weaponDBID), sideName, systemName, "firing")
      appendEntries(entries, cleanupEntries)
      hasFailure = hasFailure or cleanupFailed
      created = created + 1
    else
      hasFailure = true
      table.insert(entries, LogFormat.entry("FAIL", string.format(
        "system=%s role=firing unit=%q reason=add_unit_failed",
        LogFormat.value(systemName),
        LogFormat.readable(name)
      )))
    end
  end

  return created, expected, nil, entries, hasFailure
end

---Create resupply units according to configuration
---@param systemName string Missile system name
---@param descriptor SBJ__ResupplyUnitDescriptor Resupply unit descriptor
---@param sideName string Side name for unit creation
---@return integer created Number of units successfully created
---@return integer expected Total number of units expected to create
---@return string? errorMsg Error message if validation failed
---@return string[] entries Failure log entries
---@return boolean hasFailure Whether any unit creation sub-operation failed
local function addResupplyUnit(systemName, descriptor, sideName)
  if not descriptor.operationalArea.RL or #descriptor.operationalArea.RL == 0 then
    return 0, 0, string.format("No RL defined for resupply unit '%s' (OPAREA: %s), cannot add unit",
      descriptor.name, descriptor.operationalArea.name), {}, false
  end

  local expected = descriptor.unitCount
  local size = #descriptor.operationalArea.RL[1].course
  local unitType = GameUtils.extractUnitType(descriptor.name)
  local restStr = descriptor.name:match("Ammo Sec(.*)") or (", " .. descriptor.name)
  local created = 0
  local entries = {}
  local hasFailure = false

  for i = 1, expected do
    local name

    if expected == 1 then
      name = descriptor.name
    else
      name = "Ammo Sec, " .. GameUtils.formatOrdinalUnitName(i, unitType or "", restStr)
    end

    local result = GameApi.ScenEdit_AddUnit({
      side = sideName,
      unitname = name,
      dbid = constants.PLATFORMS.AMMO_TRUCK,
      type = constants.UNIT_TYPES.FACILITY,
      group = expected > 1 and descriptor.name or nil,
      latitude = descriptor.operationalArea.RL[1].course[size].latitude,
      longitude = descriptor.operationalArea.RL[1].course[size].longitude
    })

    if result then
      created = created + 1
    else
      hasFailure = true
      table.insert(entries, LogFormat.entry("FAIL", string.format(
        "system=%s role=resupply unit=%q reason=add_unit_failed",
        LogFormat.value(systemName),
        LogFormat.readable(name)
      )))
    end
  end

  return created, expected, nil, entries, hasFailure
end

---Create ammunition depot unit according to configuration
---@param systemCfg SBJ__MissileSystemConfig Weapon system configuration
---@param descriptor SBJ__AmmunitionUnitDescriptor Ammunition unit descriptor
---@param sideName string Side name for unit creation
---@return boolean success Whether unit was successfully created
---@return string? errorMsg Error message if failed
local function addAmmunition(systemCfg, descriptor, sideName)
  local restStr = descriptor.name:gsub("^Ammo Revetment, ", "")
  local name = restStr
  local resupplyUnitDescriptor = systemCfg.resupplyUnits[name]

  if not resupplyUnitDescriptor then
    name = "Ammo Sec, " .. name
  end

  resupplyUnitDescriptor = systemCfg.resupplyUnits[name]

  if resupplyUnitDescriptor then
    if not resupplyUnitDescriptor.operationalArea.AHA or #resupplyUnitDescriptor.operationalArea.AHA == 0 then
      return false, string.format("No AHA defined for ammo unit '%s' (OPAREA: %s), cannot add unit",
        descriptor.name, resupplyUnitDescriptor.operationalArea.name)
    end

    local size = #resupplyUnitDescriptor.operationalArea.AHA[1].course
    local addedUnit = GameApi.ScenEdit_AddUnit({
      side = sideName,
      unitname = descriptor.name,
      dbid = constants.PLATFORMS.AMMO,
      type = constants.UNIT_TYPES.FACILITY,
      latitude = resupplyUnitDescriptor.operationalArea.AHA[1].course[size].latitude,
      longitude = resupplyUnitDescriptor.operationalArea.AHA[1].course[size].longitude
    })
    if addedUnit then
      addedUnit.autodetectable = false
      return true, nil
    end
    return false, string.format("Failed to add ammo unit '%s'", descriptor.name)
  end

  return false, string.format("No matching resupply unit for ammo unit '%s'", descriptor.name)
end

---Add missile system units to the game
---@param groundForceCfg SBJ__GroundForceConfig Ground force context
---@param sideName string Side name
function Deployment.addMissileSystems(groundForceCfg, sideName)
  local logEntries = {}
  local hasFailure = false

  for systemName, systemCfg in pairs(groundForceCfg) do
    ---@cast systemCfg SBJ__MissileSystemConfig
    local isSam = systemName == "sam"
    local systemHasFailure = false
    local fuTotal, fuExpected = 0, 0
    for _, descriptor in pairs(systemCfg.firingUnits) do
      local removeEntries, removeFailed = removeMissileSystem(systemName, "firing", descriptor, sideName)
      appendEntries(logEntries, removeEntries)
      hasFailure = hasFailure or removeFailed
      systemHasFailure = systemHasFailure or removeFailed

      local created, expected, errorMsg, detailEntries, detailFailed =
          addFiringUnit(systemName, systemCfg, descriptor, sideName, isSam)
      fuTotal = fuTotal + created
      fuExpected = fuExpected + expected
      appendEntries(logEntries, detailEntries)
      hasFailure = hasFailure or detailFailed
      systemHasFailure = systemHasFailure or detailFailed
      if errorMsg then
        hasFailure = true
        systemHasFailure = true
        table.insert(logEntries, LogFormat.entry("FAIL", string.format(
          "system=%s role=firing unit=%q reason=invalid_configuration detail=%q",
          LogFormat.value(systemName),
          LogFormat.readable(descriptor.name),
          LogFormat.readable(errorMsg)
        )))
      end
    end

    local ruTotal, ruExpected = 0, 0
    for _, descriptor in pairs(systemCfg.resupplyUnits) do
      local removeEntries, removeFailed = removeMissileSystem(systemName, "resupply", descriptor, sideName)
      appendEntries(logEntries, removeEntries)
      hasFailure = hasFailure or removeFailed
      systemHasFailure = systemHasFailure or removeFailed

      local created, expected, errorMsg, detailEntries, detailFailed = addResupplyUnit(systemName, descriptor, sideName)
      ruTotal = ruTotal + created
      ruExpected = ruExpected + expected
      appendEntries(logEntries, detailEntries)
      hasFailure = hasFailure or detailFailed
      systemHasFailure = systemHasFailure or detailFailed
      if errorMsg then
        hasFailure = true
        systemHasFailure = true
        table.insert(logEntries, LogFormat.entry("FAIL", string.format(
          "system=%s role=resupply unit=%q reason=invalid_configuration detail=%q",
          LogFormat.value(systemName),
          LogFormat.readable(descriptor.name),
          LogFormat.readable(errorMsg)
        )))
      end
    end

    local ammoOk, ammoTotal = 0, 0
    for _, descriptor in pairs(systemCfg.ammunitions) do
      local removeEntries, removeFailed = removeMissileSystem(systemName, "ammo", descriptor, sideName)
      appendEntries(logEntries, removeEntries)
      hasFailure = hasFailure or removeFailed
      systemHasFailure = systemHasFailure or removeFailed

      local success, errorMsg = addAmmunition(systemCfg, descriptor, sideName)
      ammoTotal = ammoTotal + 1
      if success then ammoOk = ammoOk + 1 end
      if errorMsg then
        hasFailure = true
        systemHasFailure = true
        table.insert(logEntries, LogFormat.entry("FAIL", string.format(
          "system=%s role=ammo unit=%q reason=invalid_configuration detail=%q",
          LogFormat.value(systemName),
          LogFormat.readable(descriptor.name),
          LogFormat.readable(errorMsg)
        )))
      end
    end

    if fuTotal < fuExpected or ruTotal < ruExpected or ammoOk < ammoTotal then
      hasFailure = true
      systemHasFailure = true
    end

    table.insert(logEntries, LogFormat.entry(systemHasFailure and "FAIL" or "OK", string.format(
      "system=%s firing=%d/%d resupply=%d/%d ammo=%d/%d",
      LogFormat.value(systemName),
      fuTotal,
      fuExpected,
      ruTotal,
      ruExpected,
      ammoOk,
      ammoTotal
    )))
  end

  if #logEntries > 0 then
    local summary = LogFormat.summary("side", sideName, "Add missile systems", logEntries)
    if hasFailure then
      Logger.error(summary)
    else
      Logger.log(constants.TAGS.MISSILE_SYSTEM, summary)
    end
  end
end

return Deployment
