local GameApi = require("src.utils.gameApi")
local LogFormat = require("src.utils.logFormat")
local constants = require("src.core.constants")
local GameUtils = require("src.utils.gameUtils")
local Shared = require("src.modules.missileSystem.shared")

local Deployment = {}

---Check whether a helper's rows contain a failure
---Derived from the rows themselves so a separate flag can never drift from them.
---@param entries SBJ__LogResult[] Rows produced by a deployment helper
---@return boolean # True when at least one row is tagged FAIL
local function containsFailure(entries)
  for _, entry in ipairs(entries) do
    if entry.tag == "FAIL" then
      return true
    end
  end

  return false
end

---Remove missile systems from the game
---@param systemName string Missile system name
---@param role string Unit role
---@param descriptor SBJ__FiringUnitDescriptor Firing unit descriptor with removal info
---@param sideName string Side name for unit deletion
---@return SBJ__LogResult[] # Failure log rows
local function removeMissileSystem(systemName, role, descriptor, sideName)
  local unit = GameApi.ScenEdit_GetUnit(descriptor.name, sideName)
  local entries = {}

  if unit == nil then
    return entries
  end

  local guids = unit.group and unit.group.unitlist or { unit.guid }

  for _, guid in ipairs(guids) do
    local deleted = GameApi.ScenEdit_DeleteUnit({ side = sideName, guid = guid })
    if not deleted then
      table.insert(entries, {
        tag = "FAIL",
        fields = {
          system = systemName,
          role = role,
          unit = descriptor.name,
          guid = guid,
          reason = "delete_unit_failed"
        }
      })
    end
  end

  return entries
end

---Remove unwanted weapons and redistribute ammo for desired weapon types
---@param addedUnit CMO__Unit Unit to clean up weapons for
---@param weaponDBIDs number[] Desired weapon DBIDs to keep
---@param sideName string Side name
---@param systemName string Missile system name
---@param role string Unit role
---@return SBJ__LogResult[] # Failure log rows
local function cleanupAndRedistributeWeapons(addedUnit, weaponDBIDs, sideName, systemName, role)
  local entries = {}
  local context = { system = systemName, role = role, unit = addedUnit.name, guid = addedUnit.guid }
  local cleared = GameApi.ScenEdit_ClearAllMagazines({ side = sideName, guid = addedUnit.guid })
  if not cleared then
    table.insert(entries, {
      tag = "FAIL",
      fields = LogFormat.merge(context, { reason = "clear_magazines_failed" })
    })
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
      table.insert(entries, {
        tag = "FAIL",
        fields = LogFormat.merge(context, {
          weapon = wpnDbid,
          count = count,
          reason = "remove_reload_failed"
        })
      })
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
      table.insert(entries, {
        tag = "FAIL",
        fields = LogFormat.merge(context, {
          weapon = weaponDBIDs[1],
          count = totalRemovedCount,
          reason = "add_reload_failed"
        })
      })
    end
  end

  return entries
end

---Create firing units according to configuration
---@param systemName string Missile system name
---@param systemCfg SBJ__MissileSystemConfig Weapon system configuration
---@param descriptor SBJ__FiringUnitDescriptor Firing unit descriptor
---@param sideName string Side name for unit creation
---@param isSam boolean True if it is SAM
---@return integer created Number of units successfully created
---@return integer expected Total number of units expected to create
---@return SBJ__LogResult[] entries Failure log rows, including configuration rejections
local function addFiringUnit(systemName, systemCfg, descriptor, sideName, isSam)
  local context = {
    system = systemName,
    role = "firing",
    unit = descriptor.name,
    area = descriptor.operationalArea.name
  }

  if not descriptor.operationalArea.HA or #descriptor.operationalArea.HA == 0 then
    return 0, 0, { { tag = "FAIL", fields = LogFormat.merge(context, { reason = "no_ha_defined" }) } }
  end

  local haPosition = descriptor.operationalArea.HA[1]
  if not haPosition.course or #haPosition.course == 0 then
    return 0, 0, { { tag = "FAIL", fields = LogFormat.merge(context, { reason = "no_course_defined" }) } }
  end

  local fpPositions = descriptor.operationalArea.FP
  if isSam and (not fpPositions or #fpPositions == 0) then
    return 0, 0, { { tag = "FAIL", fields = LogFormat.merge(context, { reason = "no_fp_defined" }) } }
  end

  local resupplyDescriptor = systemCfg.resupplyUnits[descriptor.resupplyUnit]
  if not resupplyDescriptor then
    return 0, 0, { { tag = "FAIL", fields = LogFormat.merge(context, { reason = "no_resupply_unit_defined" }) } }
  end

  local expected = resupplyDescriptor.unitCount
  local size = #haPosition.course
  local unitType = GameUtils.extractUnitType(descriptor.name)
  local created = 0
  local entries = {}

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
              table.insert(entries, {
                tag = "FAIL",
                fields = {
                  system = systemName,
                  role = "firing",
                  unit = name,
                  guid = addedUnit.guid,
                  mount = desc.dbid,
                  reason = "add_mount_failed"
                }
              })
            end
          end
        end
      end

      local cleanupEntries = cleanupAndRedistributeWeapons(
        addedUnit,
        Shared.normalizeWeaponDBIDs(descriptor.weaponDBID),
        sideName,
        systemName,
        "firing"
      )
      for _, cleanupEntry in ipairs(cleanupEntries) do
        table.insert(entries, cleanupEntry)
      end
      created = created + 1
    else
      table.insert(entries, {
        tag = "FAIL",
        fields = {
          system = systemName,
          role = "firing",
          unit = name,
          reason = "add_unit_failed"
        }
      })
    end
  end

  return created, expected, entries
end

---Create resupply units according to configuration
---@param systemName string Missile system name
---@param descriptor SBJ__ResupplyUnitDescriptor Resupply unit descriptor
---@param sideName string Side name for unit creation
---@return integer created Number of units successfully created
---@return integer expected Total number of units expected to create
---@return SBJ__LogResult[] entries Failure log rows, including configuration rejections
local function addResupplyUnit(systemName, descriptor, sideName)
  if not descriptor.operationalArea.RL or #descriptor.operationalArea.RL == 0 then
    return 0, 0, { { tag = "FAIL", fields = {
      system = systemName,
      role = "resupply",
      unit = descriptor.name,
      area = descriptor.operationalArea.name,
      reason = "no_rl_defined"
    } } }
  end

  local expected = descriptor.unitCount
  local size = #descriptor.operationalArea.RL[1].course
  local unitType = GameUtils.extractUnitType(descriptor.name)
  local restStr = descriptor.name:match("Ammo Sec(.*)") or (", " .. descriptor.name)
  local created = 0
  local entries = {}

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
      table.insert(entries, {
        tag = "FAIL",
        fields = {
          system = systemName,
          role = "resupply",
          unit = name,
          reason = "add_unit_failed"
        }
      })
    end
  end

  return created, expected, entries
end

---Create ammunition depot unit according to configuration
---@param systemName string Missile system name
---@param systemCfg SBJ__MissileSystemConfig Weapon system configuration
---@param descriptor SBJ__AmmunitionUnitDescriptor Ammunition unit descriptor
---@param sideName string Side name for unit creation
---@return boolean success Whether unit was successfully created
---@return SBJ__LogResult[] entries Failure log rows
local function addAmmunition(systemName, systemCfg, descriptor, sideName)
  local context = { system = systemName, role = "ammo", unit = descriptor.name }
  local restStr = descriptor.name:gsub("^Ammo Revetment, ", "")
  local name = restStr
  local resupplyUnitDescriptor = systemCfg.resupplyUnits[name]

  if not resupplyUnitDescriptor then
    name = "Ammo Sec, " .. name
  end

  resupplyUnitDescriptor = systemCfg.resupplyUnits[name]

  if resupplyUnitDescriptor then
    if not resupplyUnitDescriptor.operationalArea.AHA or #resupplyUnitDescriptor.operationalArea.AHA == 0 then
      return false, { { tag = "FAIL", fields = LogFormat.merge(context, {
        area = resupplyUnitDescriptor.operationalArea.name,
        reason = "no_aha_defined"
      }) } }
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
      return true, {}
    end

    return false, { { tag = "FAIL", fields = LogFormat.merge(context, {
      area = resupplyUnitDescriptor.operationalArea.name,
      reason = "add_unit_failed"
    }) } }
  end

  return false, { { tag = "FAIL", fields = LogFormat.merge(context, { reason = "no_matching_resupply_unit" }) } }
end

---Add missile system units to the game
---@param groundForceCfg SBJ__GroundForceConfig Ground force context
---@param sideName string Side name
function Deployment.addMissileSystems(groundForceCfg, sideName)
  -- systemHasFailure is derived from the rows each helper produced, so it cannot
  -- drift from them. It only picks the tag of the per-system summary row; the
  -- report already routes the individual FAIL rows to the error sink.
  local report = LogFormat.report(constants.TAGS.MISSILE_SYSTEM, "side=" .. sideName, "Add missile systems")

  for systemName, systemCfg in pairs(groundForceCfg) do
    ---@cast systemCfg SBJ__MissileSystemConfig
    local isSam = systemName == "sam"
    local systemHasFailure = false
    local fuTotal, fuExpected = 0, 0
    for _, descriptor in pairs(systemCfg.firingUnits) do
      local removeEntries = removeMissileSystem(systemName, "firing", descriptor, sideName)
      report.addAll(removeEntries)
      systemHasFailure = systemHasFailure or containsFailure(removeEntries)

      local created, expected, detailEntries = addFiringUnit(systemName, systemCfg, descriptor, sideName, isSam)
      fuTotal = fuTotal + created
      fuExpected = fuExpected + expected
      report.addAll(detailEntries)
      systemHasFailure = systemHasFailure or containsFailure(detailEntries)
    end

    local ruTotal, ruExpected = 0, 0
    for _, descriptor in pairs(systemCfg.resupplyUnits) do
      local removeEntries = removeMissileSystem(systemName, "resupply", descriptor, sideName)
      report.addAll(removeEntries)
      systemHasFailure = systemHasFailure or containsFailure(removeEntries)

      local created, expected, detailEntries = addResupplyUnit(systemName, descriptor, sideName)
      ruTotal = ruTotal + created
      ruExpected = ruExpected + expected
      report.addAll(detailEntries)
      systemHasFailure = systemHasFailure or containsFailure(detailEntries)
    end

    local ammoOk, ammoTotal = 0, 0
    for _, descriptor in pairs(systemCfg.ammunitions) do
      local removeEntries = removeMissileSystem(systemName, "ammo", descriptor, sideName)
      report.addAll(removeEntries)
      systemHasFailure = systemHasFailure or containsFailure(removeEntries)

      local success, ammoEntries = addAmmunition(systemName, systemCfg, descriptor, sideName)
      ammoTotal = ammoTotal + 1
      if success then ammoOk = ammoOk + 1 end
      report.addAll(ammoEntries)
      systemHasFailure = systemHasFailure or containsFailure(ammoEntries)
    end

    if fuTotal < fuExpected or ruTotal < ruExpected or ammoOk < ammoTotal then
      systemHasFailure = true
    end

    report.add(systemHasFailure and "FAIL" or "OK", {
      system = systemName,
      firing = fuTotal .. "/" .. fuExpected,
      resupply = ruTotal .. "/" .. ruExpected,
      ammo = ammoOk .. "/" .. ammoTotal
    })
  end

  report.emit()
end

return Deployment
