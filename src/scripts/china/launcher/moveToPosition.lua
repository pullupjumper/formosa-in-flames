local gKH = require("src.core.gKH_State_Standalone")
local Logger = require("src.utils.logger")
local config = require("src.core.config")
local GameApi = require("src.utils.gameApi")
local Launcher = require("src.modules.launcher")
local unit = GameApi.ScenEdit_UnitX()
local event = GameApi.ScenEdit_EventX()
---@type SBJ__SaveData|nil
local saveData = gKH.State.LoadTableFromKey("SaveData")

if saveData == nil then
  Logger.error("saveData is nil")
  return
end

if not event then
  Logger.error("event is nil")
  return
end

if not unit then
  Logger.error("unit is nil")
  return
end

local contacts = GameApi.ScenEdit_GetContacts(unit.side)
local positionType = ""
local wpnSystems = { "srbm", "mrbm", "mlrs", "glcm", "ascm" }

for _, trigger in ipairs(event.triggers) do
  if trigger["UnitEntersArea"] then
    positionType = string.match(trigger["UnitEntersArea"].Description, "(FP)") or
        string.match(trigger["UnitEntersArea"].Description, "(AHA)") or
        string.match(trigger["UnitEntersArea"].Description, "(HA)") or
        string.match(trigger["UnitEntersArea"].Description, "(RL)")
  end
end

if positionType == "FP" then
  for _, wpnSystem in ipairs(wpnSystems) do
    ---@type SBJ__MissileSystemContext|nil
    local wpnSystemCtx = saveData.c.ground[wpnSystem]

    if wpnSystemCtx and wpnSystemCtx.enabled then
      for _, firingUnitCtx in pairs(wpnSystemCtx.firingUnits) do
        if unit then
          if firingUnitCtx.name == unit.name and firingUnitCtx.state == config.batteryState.REPOSITIONING then
            Launcher.setWCSToFree(config, firingUnitCtx, unit)
          end
        end
      end
    end
  end
elseif positionType == "HA" then
  if contacts then
    for _, contact in ipairs(contacts) do
      if unit and unit.guid == contact.actualunitid then
        contact:DropContact()
      end
    end
  end

  for _, wpnSystem in ipairs(wpnSystems) do
    ---@type SBJ__MissileSystemContext|nil
    local wpnSystemCtx = saveData.c.ground[wpnSystem]

    if wpnSystemCtx and wpnSystemCtx.enabled then
      for _, firingUnitCtx in pairs(wpnSystemCtx.firingUnits) do
        if unit then
          if firingUnitCtx.name == unit.name and firingUnitCtx.state == config.batteryState.REPOSITIONING then
            Launcher.setStateToHIDE(config, firingUnitCtx, unit)
          end
        end
      end
    end
  end
elseif positionType == "RL" then
  if contacts then
    for _, contact in ipairs(contacts) do
      if unit and unit.guid == contact.actualunitid then
        contact:DropContact()
      end
    end
  end

  for _, wpnSystem in ipairs(wpnSystems) do
    ---@type SBJ__MissileSystemContext|nil
    local wpnSystemCtx = saveData.c.ground[wpnSystem]

    if wpnSystemCtx and wpnSystemCtx.enabled then
      local result = Launcher.isMetWithResupplyUnits(config, wpnSystemCtx, unit, true)

      if result.isMet then
        Launcher.setReloadStartTime(config, result.firingUnit, unit, true)
      end
    end
  end
elseif positionType == "AHA" then
  if contacts then
    for _, contact in ipairs(contacts) do
      if unit and unit.guid == contact.actualunitid then
        contact:DropContact()
      end
    end
  end

  for _, wpnSystem in ipairs(wpnSystems) do
    ---@type SBJ__MissileSystemContext|nil
    local wpnSystemCtx = saveData.c.ground[wpnSystem]
    if wpnSystemCtx and wpnSystemCtx.enabled then
      local result = Launcher.isMetWithAmmoDepot(config, wpnSystemCtx, unit, true)

      if result.isMet then
        Launcher.setReloadStartTime(config, result.resupplyUnit, unit, true)
      end
    end
  end
end

gKH.State.SaveTableToKey(saveData, "SaveData")
