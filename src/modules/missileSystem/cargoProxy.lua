local GameApi = require("src.utils.gameApi")
local LogFormat = require("src.utils.logFormat")
local constants = require("src.core.constants")
local Shared = require("src.modules.missileSystem.shared")

local CargoProxy = {}

local CARGO_ENTRY = {
  TYPE = 3,
  QUANTITY = 1,
}

local WEAPON_CLEAR_AMOUNT = 999

---Normalize weapon DBID input to a set for fast lookup
---@param weaponDBID number|number[]|nil
---@return table<number, boolean> # Set of weapon DBIDs
local function normalizeWeaponDBIDs(weaponDBID)
  if not weaponDBID then return {} end
  local weaponDBIDSet = {}
  if type(weaponDBID) == "table" then
    for _, id in pairs(weaponDBID) do weaponDBIDSet[id] = true end
  else
    weaponDBIDSet[weaponDBID] = true
  end
  return weaponDBIDSet
end

---Create a cargo proxy unit on a base ship for a given unit DBID
---@param base CMO__Unit
---@param unitDbid number
---@param idx integer
---@param sideName string
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
---@param cargo CMO__Unit
---@param sideName string
local function removeCargoProxyMounts(cargo, sideName)
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
---@param sourceUnit CMO__Unit
---@param cargo CMO__Unit
---@param weaponDBIDSet table<number, boolean>
---@return table<number, number> # Weapon DBID to current count mapping
local function countWeaponsAndCloneMounts(sourceUnit, cargo, weaponDBIDSet)
  local weaponCountMap = {}

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
          weaponCountMap[wpn.wpn_dbid] = (weaponCountMap[wpn.wpn_dbid] or 0) + wpn.wpn_current
        end
      end
    end
  end

  return weaponCountMap
end

---Synchronize weapon reload counts on a cargo proxy unit
---Clears all tracked weapon reloads then sets them to actual counts
---@param cargo CMO__Unit
---@param sideName string
---@param weaponCountMap table<number, number>
local function updateWeaponReloads(cargo, sideName, weaponCountMap)
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

  for wpnDBID, count in pairs(weaponCountMap) do
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
---@param base CMO__Unit
---@param sourceUnit CMO__Unit
---@param idx integer
---@param loadCtx SBJ__CargoLoadContext
---@return SBJ__LogResult # Deferred log result describing the outcome
local function normalizeGroupMember(base, sourceUnit, idx, loadCtx)
  local weaponDBIDSet, sideName = loadCtx.weaponDBIDSet, loadCtx.sideName
  local cargo = createCargoProxy(base, sourceUnit.dbid, idx, sideName)
  if not cargo then
    return {
      tag = "FAIL",
      fields = {
        unit = sourceUnit.name or sourceUnit.guid,
        index = idx,
        reason = "cargo_proxy_creation_failed"
      }
    }
  end

  removeCargoProxyMounts(cargo, sideName)
  local weaponCountMap = countWeaponsAndCloneMounts(sourceUnit, cargo, weaponDBIDSet)
  updateWeaponReloads(cargo, sideName, weaponCountMap)

  if sourceUnit.group then
    cargo.group = sourceUnit.group.name
  end
  cargo.name = sourceUnit.name

  GameApi.ScenEdit_DeleteUnit({ guid = sourceUnit.guid })

  return { tag = "OK", fields = { unit = sourceUnit.name or sourceUnit.guid, index = idx } }
end

---Simulate loading ground units onto a ship by creating cargo proxies
---Resolves unit group, clones weapon loadouts to cargo proxies, and removes originals
---@param base CMO__Unit
---@param unitName string Launcher or transloader name
---@param weaponDBID number|number[]|nil Weapons whose counts carry over; nil for a transloader
---@param sideName string
function CargoProxy.loadCargo(base, unitName, weaponDBID, sideName)
  local actualUnit = GameApi.ScenEdit_GetUnit(unitName, sideName)
  if not actualUnit then return end

  local group = Shared.getGroupUnits(actualUnit)
  local loadCtx = { weaponDBIDSet = normalizeWeaponDBIDs(weaponDBID), sideName = sideName }
  local report = LogFormat.report(
    constants.TAGS.MISSILE_SYSTEM, "ship=" .. (base.name or base.guid), "Load cargo")

  for idx, guid in ipairs(group) do
    local unit = GameApi.ScenEdit_GetUnit(guid)

    if not unit then
      report.add("SKIP", { guid = guid, index = idx, reason = "unit_not_found" })
    else
      local result = normalizeGroupMember(base, unit, idx, loadCtx)
      report.add(result.tag, result.fields)
    end
  end

  report.emit()
end

return CargoProxy
