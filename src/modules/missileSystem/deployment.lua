local GameApi = require("src.utils.gameApi")
local LogFormat = require("src.utils.logFormat")
local constants = require("src.core.constants")
local GameUtils = require("src.utils.gameUtils")
local Shared = require("src.modules.missileSystem.shared")
local Rules = require("src.modules.missileSystem.rules")

local Deployment = {}

---Position the last waypoint of a course leads to
---@param position SBJ__Position
---@return CMO__Location
local function buildCourseEnd(position)
  local point = position.course[#position.course]
  return { latitude = point.latitude, longitude = point.longitude }
end

---Remove a role's unit, or every member of its group, from the game
---@param context table<string, any> Role log context: system, role, unit, area
---@param sideName string
---@return SBJ__LogResult[] # Failure log rows
local function removeRoleUnits(context, sideName)
  local unit = GameApi.ScenEdit_GetUnit(context.unit, sideName)
  local entries = {}

  if unit == nil then
    return entries
  end

  for _, guid in ipairs(Shared.getGroupUnits(unit)) do
    local deleted = GameApi.ScenEdit_DeleteUnit({ side = sideName, guid = guid })
    if not deleted then
      table.insert(entries, {
        tag = "FAIL",
        fields = LogFormat.merge(context, { guid = guid, reason = "delete_unit_failed" })
      })
    end
  end

  return entries
end

---Remove unwanted weapons and redistribute ammo for desired weapon types
---@param addedUnit CMO__Unit
---@param weaponDBIDs number[]
---@param sideName string
---@param context table<string, any> Member log context
---@return SBJ__LogResult[] # Failure log rows
local function removeAndRedistributeWeapons(addedUnit, weaponDBIDs, sideName, context)
  local entries = {}
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

---Fit a firing vehicle's configured mounts and keep only its configured weapons
---@param battery SBJ__Battery
---@param addedUnit CMO__Unit
---@param sideName string
---@param context table<string, any> Member log context, with guid
---@return SBJ__LogResult[] # Failure log rows
local function setArmament(battery, addedUnit, sideName, context)
  local entries = {}

  for _, desc in ipairs(battery.firing.mountDescriptors or {}) do
    for _ = 1, desc.mountCount do
      local updated = GameApi.ScenEdit_UpdateUnit({
        guid = addedUnit.guid,
        mode = "add_mount",
        dbid = desc.dbid,
        arc_mount = constants.SENSOR_ARCS
      })
      if not updated then
        table.insert(entries, {
          tag = "FAIL",
          fields = LogFormat.merge(context, { mount = desc.dbid, reason = "add_mount_failed" })
        })
      end
    end
  end

  for _, entry in ipairs(removeAndRedistributeWeapons(
    addedUnit, Shared.normalizeWeaponDBIDs(battery.firing.weaponDBID), sideName, context
  )) do
    table.insert(entries, entry)
  end

  return entries
end

---What differs between the three units of a battery. Everything else is the one path in deployRole.
---@class SBJ__BatteryRole
---@field role "firing"|"resupply"|"ammo" Log `role` field and summary column
---@field resolveDescriptor fun(battery: SBJ__Battery): SBJ__UnitBase
---@field dbid? number Fixed platform; nil uses the firing unit's dbid
---@field isGroup boolean Builds battery.unitCount vehicles grouped under the descriptor name; otherwise one
---@field findRejection fun(area: SBJ__OperationalArea, isDeployed: boolean): string|nil Reason the area cannot hold this role
---@field buildSpawnPosition fun(area: SBJ__OperationalArea, isDeployed: boolean): CMO__Location Called per vehicle
---@field setUp? fun(battery: SBJ__Battery, addedUnit: CMO__Unit, sideName: string, context: table): SBJ__LogResult[]

---The units of one battery, in build and summary order
---@type SBJ__BatteryRole[]
local BATTERY_ROLES = {
  {
    role = "firing",
    resolveDescriptor = function(battery) return battery.firing end,
    isGroup = true,
    findRejection = function(area, isDeployed)
      if not area.HA or #area.HA == 0 then
        return "no_ha_defined"
      end
      if not area.HA[1].course or #area.HA[1].course == 0 then
        return "no_course_defined"
      end
      if isDeployed and (not area.FP or #area.FP == 0) then
        return "no_fp_defined"
      end
      return nil
    end,
    -- A system that stays deployed starts at a random firing point; the others start hidden
    buildSpawnPosition = function(area, isDeployed)
      if isDeployed then
        return buildCourseEnd(area.FP[math.random(#area.FP)])
      end
      return buildCourseEnd(area.HA[1])
    end,
    setUp = setArmament,
  },
  {
    role = "resupply",
    resolveDescriptor = function(battery) return battery.resupply end,
    dbid = constants.PLATFORMS.AMMO_TRUCK,
    isGroup = true,
    findRejection = function(area)
      if not area.RL or #area.RL == 0 then
        return "no_rl_defined"
      end
      return nil
    end,
    buildSpawnPosition = function(area) return buildCourseEnd(area.RL[1]) end,
  },
  {
    role = "ammo",
    resolveDescriptor = function(battery) return battery.depot end,
    dbid = constants.PLATFORMS.AMMO,
    isGroup = false,
    findRejection = function(area)
      if not area.AHA or #area.AHA == 0 then
        return "no_aha_defined"
      end
      return nil
    end,
    buildSpawnPosition = function(area) return buildCourseEnd(area.AHA[1]) end,
    setUp = function(_, addedUnit)
      addedUnit.autodetectable = false
      return {}
    end,
  },
}

---Format the name of one vehicle in a group
---Every descriptor name ends with ", <firing unit name>" (spec/core/missileSystemConfig_spec.lua), so the
---ordinal goes in front of the firing unit name: "Ammo Sec, 1st Bn, X" -> "Ammo Sec, 2nd Coy, 1st Bn, X".
---@param battery SBJ__Battery
---@param descriptorName string
---@param index integer 1-based vehicle index
---@return string
local function formatMemberName(battery, descriptorName, index)
  local firingName = battery.firing.name
  local prefix = descriptorName:sub(1, #descriptorName - #firingName)
  local unitType = GameUtils.resolveUnitType(firingName) or ""
  return prefix .. GameUtils.formatOrdinalUnitName(index, unitType, ", " .. firingName)
end

---Replace one role of one battery in the game: remove its old units, then build every vehicle
---@param battery SBJ__Battery
---@param batteryRole SBJ__BatteryRole
---@param sideName string
---@return integer created Vehicles built
---@return integer expected Vehicles planned, also when the area is rejected
---@return SBJ__LogResult[] entries Failure log rows; every vehicle not built has one
local function deployRole(battery, batteryRole, sideName)
  local descriptor = batteryRole.resolveDescriptor(battery)
  local area = battery.operationalArea
  local isDeployed = Rules.staysDeployed(battery.missileSystemType)
  local expected = batteryRole.isGroup and battery.unitCount or 1
  local context = {
    system = battery.missileSystemType,
    role = batteryRole.role,
    unit = descriptor.name,
    area = area.name
  }
  local entries = removeRoleUnits(context, sideName)

  local reason = batteryRole.findRejection(area, isDeployed)
  if reason then
    table.insert(entries, { tag = "FAIL", fields = LogFormat.merge(context, { reason = reason }) })
    return 0, expected, entries
  end

  local created = 0
  for i = 1, expected do
    local name = expected == 1 and descriptor.name or formatMemberName(battery, descriptor.name, i)
    local position = batteryRole.buildSpawnPosition(area, isDeployed)
    local addedUnit = GameApi.ScenEdit_AddUnit({
      side = sideName,
      unitname = name,
      dbid = batteryRole.dbid or battery.firing.dbid,
      type = constants.UNIT_TYPES.FACILITY,
      group = expected > 1 and descriptor.name or nil,
      latitude = position.latitude,
      longitude = position.longitude
    })

    if addedUnit then
      created = created + 1
      if batteryRole.setUp then
        local memberContext = LogFormat.merge(context, { unit = name, guid = addedUnit.guid })
        for _, entry in ipairs(batteryRole.setUp(battery, addedUnit, sideName, memberContext)) do
          table.insert(entries, entry)
        end
      end
    else
      table.insert(entries, {
        tag = "FAIL",
        fields = LogFormat.merge(context, { unit = name, reason = "add_unit_failed" })
      })
    end
  end

  return created, expected, entries
end

---Join a layout's firing unit to its resupply unit and depot by config links
---@param missileSystemConfigMap table<string, SBJ__MissileSystemConfig>
---@param layout SBJ__MissileSystemLayout
---@return SBJ__Battery|nil # nil when the layout names an unknown system or firing unit
function Deployment.resolveBattery(missileSystemConfigMap, layout)
  local systemConfig = missileSystemConfigMap[layout.missileSystemType]
  local firing = systemConfig and systemConfig.firingUnits[layout.unitname]
  if not firing then
    return nil
  end

  local resupply = systemConfig.resupplyUnits[firing.resupplyUnit]
  return {
    missileSystemType = layout.missileSystemType,
    firing = firing,
    resupply = resupply,
    depot = systemConfig.ammunitions[resupply.ammunition],
    unitCount = resupply.unitCount,
    operationalArea = layout.operationalArea
  }
end

---Every configured battery at its config operational area
---@param missileSystemConfigMap table<string, SBJ__MissileSystemConfig>
---@return SBJ__Battery[]
function Deployment.resolveBatteries(missileSystemConfigMap)
  local batteries = {}

  for missileSystemType, systemConfig in pairs(missileSystemConfigMap) do
    for _, firing in pairs(systemConfig.firingUnits) do
      table.insert(batteries, Deployment.resolveBattery(missileSystemConfigMap, {
        missileSystemType = missileSystemType,
        unitname = firing.name,
        operationalArea = firing.operationalArea
      }))
    end
  end

  return batteries
end

---Replace the batteries' units in the game, each at its battery's operational area
---Logs one report: the failure rows, then one summary row per missile system, FAIL when any of its rows failed.
---@param sideName string
---@param batteries SBJ__Battery[]
function Deployment.deployBatteries(sideName, batteries)
  local report = LogFormat.report(constants.TAGS.MISSILE_SYSTEM, "side=" .. sideName, "Add missile systems")
  local systemTypes = {}
  ---@type table<string, {counts: table<string, {created: integer, expected: integer}>, entries: SBJ__LogResult[]}>
  local summaryMap = {}

  for _, battery in ipairs(batteries) do
    local summary = summaryMap[battery.missileSystemType]
    if not summary then
      summary = { counts = {}, entries = {} }
      for _, batteryRole in ipairs(BATTERY_ROLES) do
        summary.counts[batteryRole.role] = { created = 0, expected = 0 }
      end
      summaryMap[battery.missileSystemType] = summary
      table.insert(systemTypes, battery.missileSystemType)
    end

    for _, batteryRole in ipairs(BATTERY_ROLES) do
      local created, expected, entries = deployRole(battery, batteryRole, sideName)
      local count = summary.counts[batteryRole.role]
      count.created = count.created + created
      count.expected = count.expected + expected
      for _, entry in ipairs(entries) do
        table.insert(summary.entries, entry)
      end
    end
  end

  for _, missileSystemType in ipairs(systemTypes) do
    local summary = summaryMap[missileSystemType]
    local fields = { system = missileSystemType }
    for _, batteryRole in ipairs(BATTERY_ROLES) do
      local count = summary.counts[batteryRole.role]
      fields[batteryRole.role] = count.created .. "/" .. count.expected
    end
    report.addAll(summary.entries)
    report.add(LogFormat.hasFailure(summary.entries) and "FAIL" or "OK", fields)
  end

  report.emit()
end

return Deployment
