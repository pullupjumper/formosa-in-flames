local GameApi = require("src.utils.gameApi")
local Logger = require("src.utils.logger")
local constants = require("src.core.constants")
local GameUtils = require("src.utils.gameUtils")
local Shared = require("src.modules.missileSystem.shared")

local Deployment = {}

---Remove missile systems from the game
---@param descriptor SBJ__FiringUnitDescriptor Firing unit descriptor with removal info
---@param sideName string Side name for unit deletion
---@return boolean # Whether unit was successfully removed
local function removeMissileSystem(descriptor, sideName)
  local unit = GameApi.ScenEdit_GetUnit(descriptor.name, sideName)

  if unit then
    if unit.group and unit.group.unitlist then
      for _, guid in ipairs(unit.group.unitlist) do
        GameApi.ScenEdit_DeleteUnit({ side = sideName, guid = guid })
      end
    else
      GameApi.ScenEdit_DeleteUnit({ side = sideName, guid = unit.guid })
    end

    return true
  end

  return false
end

---Remove unwanted weapons and redistribute ammo for desired weapon types
---@param addedUnit CMO__Unit Unit to clean up weapons for
---@param weaponDBIDs number[] Desired weapon DBIDs to keep
---@param sideName string Side name
local function cleanupAndRedistributeWeapons(addedUnit, weaponDBIDs, sideName)
  GameApi.ScenEdit_ClearAllMagazines({ side = sideName, guid = addedUnit.guid })

  local weaponDBIDSet = {}
  for _, id in ipairs(weaponDBIDs) do weaponDBIDSet[id] = true end

  local removals = {}
  for _, mount in ipairs(addedUnit.mounts) do
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
    GameApi.ScenEdit_AddReloadsToUnit({
      side = sideName,
      guid = addedUnit.guid,
      wpn_dbid = wpnDbid,
      number = count,
      remove = true
    })
    totalRemovedCount = totalRemovedCount + count
  end

  if totalRemovedCount > 0 and #weaponDBIDs == 1 then
    GameApi.ScenEdit_AddReloadsToUnit({
      side = sideName,
      guid = addedUnit.guid,
      wpn_dbid = weaponDBIDs[1],
      number = totalRemovedCount,
    })
  end
end

---Create firing units according to configuration
---@param systemCfg SBJ__MissileSystemConfig Weapon system configuration
---@param descriptor SBJ__FiringUnitDescriptor Firing unit descriptor
---@param sideName string Side name for unit creation
---@param isSam boolean True if it is SAM
---@return integer created Number of units successfully created
---@return integer expected Total number of units expected to create
---@return string? errorMsg Error message if validation failed
local function addFiringUnit(systemCfg, descriptor, sideName, isSam)
  if not descriptor.operationalArea.HA or #descriptor.operationalArea.HA == 0 then
    return 0, 0, string.format("No HA defined for firing unit '%s' (OPAREA: %s), cannot add unit",
      descriptor.name, descriptor.operationalArea.name)
  end

  local haPosition = descriptor.operationalArea.HA[1]
  if not haPosition.course or #haPosition.course == 0 then
    return 0, 0, string.format("No course defined for HA[1] in '%s' (OPAREA: %s), cannot add unit",
      descriptor.name, descriptor.operationalArea.name)
  end

  local fpPositions = descriptor.operationalArea.FP
  if isSam and (not fpPositions or #fpPositions == 0) then
    return 0, 0, string.format("No FP defined for SAM firing unit '%s' (OPAREA: %s), cannot add unit",
      descriptor.name, descriptor.operationalArea.name)
  end

  local expected = systemCfg.resupplyUnits[descriptor.resupplyUnit].unitCount
  local size = #haPosition.course
  local unitType = GameUtils.extractUnitType(descriptor.name)
  local created = 0

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
            GameApi.ScenEdit_UpdateUnit({
              guid = addedUnit.guid,
              mode = "add_mount",
              dbid = desc.dbid,
              arc_mount = constants.SENSOR_ARCS
            })
          end
        end
      end

      cleanupAndRedistributeWeapons(addedUnit, Shared.normalizeWeaponDBIDs(descriptor.weaponDBID), sideName)
      created = created + 1
    end
  end

  return created, expected, nil
end

---Create resupply units according to configuration
---@param descriptor SBJ__ResupplyUnitDescriptor Resupply unit descriptor
---@param sideName string Side name for unit creation
---@return integer created Number of units successfully created
---@return integer expected Total number of units expected to create
---@return string? errorMsg Error message if validation failed
local function addResupplyUnit(descriptor, sideName)
  if not descriptor.operationalArea.RL or #descriptor.operationalArea.RL == 0 then
    return 0, 0, string.format("No RL defined for resupply unit '%s' (OPAREA: %s), cannot add unit",
      descriptor.name, descriptor.operationalArea.name)
  end

  local expected = descriptor.unitCount
  local size = #descriptor.operationalArea.RL[1].course
  local unitType = GameUtils.extractUnitType(descriptor.name)
  local restStr = descriptor.name:match("Ammo Sec(.*)") or (", " .. descriptor.name)
  local created = 0

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
    end
  end

  return created, expected, nil
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
    end
    return true, nil
  end

  return false, nil
end

---Add missile system units to the game
---@param groundForceCfg SBJ__GroundForceConfig Ground force context
---@param sideName string Side name
function Deployment.addMissileSystems(groundForceCfg, sideName)
  local okLines, failLines = {}, {}

  for systemName, systemCfg in pairs(groundForceCfg) do
    ---@cast systemCfg SBJ__MissileSystemConfig
    local isSam = systemName == "sam"
    local fuTotal, fuExpected = 0, 0
    for _, descriptor in pairs(systemCfg.firingUnits) do
      removeMissileSystem(descriptor, sideName)
      local created, expected, errorMsg = addFiringUnit(systemCfg, descriptor, sideName, isSam)
      fuTotal = fuTotal + created
      fuExpected = fuExpected + expected
      if errorMsg then table.insert(failLines, "  [FAIL] " .. errorMsg) end
    end

    local ruTotal, ruExpected = 0, 0
    for _, descriptor in pairs(systemCfg.resupplyUnits) do
      removeMissileSystem(descriptor, sideName)
      local created, expected, errorMsg = addResupplyUnit(descriptor, sideName)
      ruTotal = ruTotal + created
      ruExpected = ruExpected + expected
      if errorMsg then table.insert(failLines, "  [FAIL] " .. errorMsg) end
    end

    local ammoOk, ammoTotal = 0, 0
    for _, descriptor in pairs(systemCfg.ammunitions) do
      removeMissileSystem(descriptor, sideName)
      local success, errorMsg = addAmmunition(systemCfg, descriptor, sideName)
      ammoTotal = ammoTotal + 1
      if success then ammoOk = ammoOk + 1 end
      if errorMsg then table.insert(failLines, "  [FAIL] " .. errorMsg) end
    end

    table.insert(okLines, string.format("  [OK] %s: %d/%d firing, %d/%d resupply, %d/%d ammo",
      systemName, fuTotal, fuExpected, ruTotal, ruExpected, ammoOk, ammoTotal))
  end

  if #okLines > 0 then
    Logger.log(constants.TAGS.MISSILE_SYSTEM, "Unit creation summary:\n" .. table.concat(okLines, "\n"))
  end
  if #failLines > 0 then
    Logger.error(constants.TAGS.MISSILE_SYSTEM .. ": Unit creation failures:\n" .. table.concat(failLines, "\n"))
  end
end

return Deployment
