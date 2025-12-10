local gKH = require("src.core.gKH_State_Standalone")
local Logger = require("src.utils.logger")
local config = require("src.core.config")
local GameApi = require("src.utils.gameApi")
local Launcher = require("src.modules.launcher")
local unit = GameApi.ScenEdit_UnitX()
local event = GameApi.ScenEdit_EventX()
local contacts = GameApi.ScenEdit_GetContacts("Taiwan")
---@type SBJ__SaveData
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

elseif positionType == "HA" then
  if contacts then
    for _, contact in ipairs(contacts) do
      if unit and unit.guid == contact.actualunitid then
        contact:DropContact()
      end
    end
  end

  for _, wpnSystem in ipairs(wpnSystems) do
    if saveData.t.ground[wpnSystem] and saveData.t.ground[wpnSystem].isActivated then
      for _, firingUnitCtx in pairs(saveData.t.ground[wpnSystem].firingUnits) do
        if unit then
          if firingUnitCtx.guid == unit.guid and firingUnitCtx.state == config.batteryState.REPOSITIONING then
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
    if saveData.t.ground[wpnSystem] and saveData.t.ground[wpnSystem].isActivated then
      local result = Launcher.isMetWithResupplyUnits(config, saveData.t.ground[wpnSystem], unit, false)

      if result.isMet then
        Launcher.setReloadStartTime(config, result.firingUnit, unit, false)
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
    if saveData.t.ground[wpnSystem] and saveData.t.ground[wpnSystem].isActivated then
      local result = Launcher.isMetWithAmmoDepot(config, saveData.t.ground[wpnSystem], unit, false)

      if result.isMet then
        Launcher.setReloadStartTime(config, result.resupplyUnit, unit, false)
      end
    end
  end
end

gKH.State.SaveTableToKey(saveData, "SaveData")
