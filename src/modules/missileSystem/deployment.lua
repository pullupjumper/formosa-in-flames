local GameApi = require("src.utils.gameApi")
local LogFormat = require("src.utils.logFormat")
local constants = require("src.core.constants")
local GameUtils = require("src.utils.gameUtils")
local Shared = require("src.modules.missileSystem.shared")
local Utils = require("src.utils.utils")

local Deployment = {}

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
---@param params {system: string, role: string} Missile system name and unit role stamped on every log row
---@return SBJ__LogResult[] # Failure log rows
local function removeAndRedistributeWeapons(addedUnit, weaponDBIDs, sideName, params)
  local entries = {}
  local context = { system = params.system, role = params.role, unit = addedUnit.name, guid = addedUnit.guid }
  GameApi.ScenEdit_ClearAllMagazines({ side = sideName, guid = addedUnit.guid })

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
---@param systemConfig SBJ__MissileSystemConfig Weapon system configuration
---@param descriptor SBJ__FiringUnitDescriptor Firing unit descriptor
---@param sideName string Side name for unit creation
---@return integer created Number of units successfully created
---@return integer expected Total number of units expected to create
---@return SBJ__LogResult[] entries Failure log rows, including configuration rejections
local function addFiringUnit(systemName, systemConfig, descriptor, sideName)
  local isSam = systemName == "sam"
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

  local resupplyDescriptor = systemConfig.resupplyUnits[descriptor.resupplyUnit]
  if not resupplyDescriptor then
    return 0, 0, { { tag = "FAIL", fields = LogFormat.merge(context, { reason = "no_resupply_unit_defined" }) } }
  end

  local expected = resupplyDescriptor.unitCount
  local size = #haPosition.course
  local unitType = GameUtils.resolveUnitType(descriptor.name)
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

      local cleanupEntries = removeAndRedistributeWeapons(
        addedUnit,
        Shared.normalizeWeaponDBIDs(descriptor.weaponDBID),
        sideName,
        { system = systemName, role = "firing" }
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
    return 0, 0, { {
      tag = "FAIL",
      fields = {
        system = systemName,
        role = "resupply",
        unit = descriptor.name,
        area = descriptor.operationalArea.name,
        reason = "no_rl_defined"
      }
    } }
  end

  local expected = descriptor.unitCount
  local size = #descriptor.operationalArea.RL[1].course
  local unitType = GameUtils.resolveUnitType(descriptor.name)
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
---@param systemConfig SBJ__MissileSystemConfig Weapon system configuration
---@param descriptor SBJ__AmmunitionUnitDescriptor Ammunition unit descriptor
---@param sideName string Side name for unit creation
---@return boolean success Whether unit was successfully created
---@return SBJ__LogResult[] entries Failure log rows
local function addAmmunition(systemName, systemConfig, descriptor, sideName)
  local context = { system = systemName, role = "ammo", unit = descriptor.name }
  local restStr = descriptor.name:gsub("^Ammo Revetment, ", "")
  local name = restStr
  local resupplyUnitDescriptor = systemConfig.resupplyUnits[name]

  if not resupplyUnitDescriptor then
    name = "Ammo Sec, " .. name
  end

  resupplyUnitDescriptor = systemConfig.resupplyUnits[name]

  if resupplyUnitDescriptor then
    if not resupplyUnitDescriptor.operationalArea.AHA or #resupplyUnitDescriptor.operationalArea.AHA == 0 then
      return false, { {
        tag = "FAIL",
        fields = LogFormat.merge(context, {
          area = resupplyUnitDescriptor.operationalArea.name,
          reason = "no_aha_defined"
        })
      } }
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

    return false, { {
      tag = "FAIL",
      fields = LogFormat.merge(context, {
        area = resupplyUnitDescriptor.operationalArea.name,
        reason = "add_unit_failed"
      })
    } }
  end

  return false, { { tag = "FAIL", fields = LogFormat.merge(context, { reason = "no_matching_resupply_unit" }) } }
end

---Add missile system units to the game
---@param missileSystemTypeConfig SBJ__MissileSystemTypeConfig Ground force context
---@param sideName string Side name
function Deployment.addMissileSystems(missileSystemTypeConfig, sideName)
  -- systemHasFailure is derived from the rows each helper produced, so it cannot
  -- drift from them. It only picks the tag of the per-system summary row; the
  -- report already routes the individual FAIL rows to the error sink.
  local report = LogFormat.report(constants.TAGS.MISSILE_SYSTEM, "side=" .. sideName, "Add missile systems")

  for systemName, systemConfig in pairs(missileSystemTypeConfig) do
    ---@cast systemConfig SBJ__MissileSystemConfig
    local systemHasFailure = false
    local fuTotal, fuExpected = 0, 0
    for _, descriptor in pairs(systemConfig.firingUnits) do
      local removeEntries = removeMissileSystem(systemName, "firing", descriptor, sideName)
      report.addAll(removeEntries)
      systemHasFailure = systemHasFailure or LogFormat.hasFailure(removeEntries)

      local created, expected, detailEntries = addFiringUnit(systemName, systemConfig, descriptor, sideName)
      fuTotal = fuTotal + created
      fuExpected = fuExpected + expected
      report.addAll(detailEntries)
      systemHasFailure = systemHasFailure or LogFormat.hasFailure(detailEntries)
    end

    local ruTotal, ruExpected = 0, 0
    for _, descriptor in pairs(systemConfig.resupplyUnits) do
      local removeEntries = removeMissileSystem(systemName, "resupply", descriptor, sideName)
      report.addAll(removeEntries)
      systemHasFailure = systemHasFailure or LogFormat.hasFailure(removeEntries)

      local created, expected, detailEntries = addResupplyUnit(systemName, descriptor, sideName)
      ruTotal = ruTotal + created
      ruExpected = ruExpected + expected
      report.addAll(detailEntries)
      systemHasFailure = systemHasFailure or LogFormat.hasFailure(detailEntries)
    end

    local ammoOk, ammoTotal = 0, 0
    for _, descriptor in pairs(systemConfig.ammunitions) do
      local removeEntries = removeMissileSystem(systemName, "ammo", descriptor, sideName)
      report.addAll(removeEntries)
      systemHasFailure = systemHasFailure or LogFormat.hasFailure(removeEntries)

      local success, ammoEntries = addAmmunition(systemName, systemConfig, descriptor, sideName)
      ammoTotal = ammoTotal + 1
      if success then ammoOk = ammoOk + 1 end
      report.addAll(ammoEntries)
      systemHasFailure = systemHasFailure or LogFormat.hasFailure(ammoEntries)
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

---Point firing and resupply unit descriptors at their new operational areas
---Descriptors are replaced with copies rather than edited in place. Layouts naming an
---unknown system or firing unit are skipped.
---@param missileSystemTypeConfig SBJ__MissileSystemTypeConfig Ground force configuration; mutated
---@param layouts SBJ__MissileSystemLayout[] Player-chosen operational areas
---@return SBJ__OperationalArea[] operationalAreas New areas that need zones and triggers
---@return SBJ__OperationalArea[] operationalAreasToRemove Replaced areas whose zones and triggers must go
function Deployment.updateLayouts(missileSystemTypeConfig, layouts)
  local operationalAreas = {}
  local operationalAreasToRemove = {}

  for _, layout in ipairs(layouts) do
    ---@type SBJ__MissileSystemConfig
    local systemConfig = missileSystemTypeConfig[layout.category]

    if systemConfig and systemConfig.firingUnits[layout.unitname] then
      local firingUnitDescriptor = Utils.deepCopy(systemConfig.firingUnits[layout.unitname])
      local resupplyUnitDescriptor = Utils.deepCopy(systemConfig.resupplyUnits[firingUnitDescriptor.resupplyUnit])
      local ammoDescriptor = Utils.deepCopy(systemConfig.ammunitions[resupplyUnitDescriptor.ammunition])
      table.insert(operationalAreasToRemove, firingUnitDescriptor.operationalArea)
      firingUnitDescriptor.operationalArea = layout.operationalArea
      resupplyUnitDescriptor.operationalArea = layout.operationalArea
      table.insert(operationalAreas, layout.operationalArea)
      systemConfig.firingUnits[firingUnitDescriptor.name] = firingUnitDescriptor
      systemConfig.resupplyUnits[resupplyUnitDescriptor.name] = resupplyUnitDescriptor
      systemConfig.ammunitions[ammoDescriptor.name] = ammoDescriptor
    end
  end

  return operationalAreas, operationalAreasToRemove
end

return Deployment
