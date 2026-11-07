local GameApi = require("src.utils.gameApi")
local Ammo = require("src.modules.missileSystem.ammo")
local GroundStateStore = require("src.modules.missileSystem.groundStateStore")

---Finds where battery units stand and which partner they can meet. Decides nothing: Rules does.
local Meeting = {}

---Find the RL zone of an operational area that a unit stands in
---@param unit CMO__Unit
---@param operationalArea SBJ__OperationalArea
---@return string[]|nil # Zone reference points, nil when the unit is in no RL zone
function Meeting.findReloadArea(unit, operationalArea)
  for _, pos in ipairs(operationalArea.RL) do
    if unit:inArea(pos.area) then
      return pos.area
    end
  end

  return nil
end

---Resolve the CMO unit for a state, reusing the triggering unit when names match
---@param unitState SBJ__LauncherState|SBJ__TransloaderState
---@param triggeringUnit CMO__Unit
---@return CMO__Unit|nil # CMO unit or nil if lookup fails
local function resolveCmoUnit(unitState, triggeringUnit)
  if unitState.name == triggeringUnit.name then
    return triggeringUnit
  end
  return GameApi.ScenEdit_GetUnit(unitState.name, triggeringUnit.side)
end

---Resolve the launcher and transloader paired with a unit, both states and both CMO units
---@param systemConfig SBJ__MissileSystemConfig
---@param systemState SBJ__MissileSystemState
---@param unit CMO__Unit Launcher or transloader; reused for its own end, the other end is looked up on its side
---@return SBJ__ReloadPair|nil # Nil when either state or either CMO unit is missing
function Meeting.resolveReloadPair(systemConfig, systemState, unit)
  local launcherState, transloaderState = GroundStateStore.resolvePair(systemConfig, systemState, unit.name)
  if not launcherState or not transloaderState then
    return nil
  end
  local launcherDescriptor = systemConfig.launchers[launcherState.name]

  local launcher = resolveCmoUnit(launcherState, unit)
  local transloader = resolveCmoUnit(transloaderState, unit)
  if not launcher or not transloader then
    return nil
  end

  local reload
  return {
    launcherState = launcherState,
    launcher = launcher,
    transloaderState = transloaderState,
    transloader = transloader,
    isTriggeredByLauncher = unit.name == launcherState.name,
    isLauncherLowAmmo = function()
      return Ammo.isLowAmmo(launcher, launcherDescriptor.ammoThreshold, launcherDescriptor.weaponDBID)
    end,
    isInSameReloadArea = function()
      local area = Meeting.findReloadArea(launcher, launcherState.operationalArea)
      return area ~= nil and transloader:inArea(area)
    end,
    buildReload = function()
      reload = reload or Ammo.buildReload(launcher, launcherDescriptor.weaponDBID, transloaderState.weaponCountCurrent)
      return reload
    end,
  }
end

---Whether a transloader and its canister stock stand in one ATP zone
---@param transloaderDescriptor SBJ__TransloaderDescriptor
---@param transloaderState SBJ__TransloaderState
---@param transloader CMO__Unit
---@return boolean # False also when the canister stock is not in the game
function Meeting.isInSameAmmunitionTransferPoint(transloaderDescriptor, transloaderState, transloader)
  local canisterStock = GameApi.ScenEdit_GetUnit(transloaderDescriptor.canisterStock, transloader.side)
  if not canisterStock then
    return false
  end

  for _, pos in ipairs(transloaderState.operationalArea.ATP) do
    if transloader:inArea(pos.area) and canisterStock:inArea(pos.area) then
      return true
    end
  end

  return false
end

return Meeting
