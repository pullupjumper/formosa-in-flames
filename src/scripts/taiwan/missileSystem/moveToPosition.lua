local gKH = require("src.core.gKH_State_Standalone")
local Logger = require("src.utils.logger")
local GameApi = require("src.utils.gameApi")
local MissileSystem = require("src.modules.missileSystem")
local unit = GameApi.ScenEdit_UnitX()
local event = GameApi.ScenEdit_EventX()
local contacts = GameApi.ScenEdit_GetContacts("Taiwan")
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

local positionType = ""
local missileSystems = { "srbm", "mrbm", "mlrs", "glcm", "ascm", "sam" }

for _, trigger in ipairs(event.triggers) do
  if trigger["UnitEntersArea"] then
    positionType = string.match(trigger["UnitEntersArea"].Description, "(FP)") or
        string.match(trigger["UnitEntersArea"].Description, "(AHA)") or
        string.match(trigger["UnitEntersArea"].Description, "(HA)") or
        string.match(trigger["UnitEntersArea"].Description, "(RL)")
  end
end

if positionType == "FP" then
  for _, missileSystem in ipairs(missileSystems) do
    ---@type SBJ__MissileSystemContext|nil
    local missileSystemCtx = saveData.t.ground[missileSystem]

    if missileSystemCtx and missileSystemCtx.enabled then
      if MissileSystem.isRepositioning(missileSystemCtx.firingUnits[unit.name], false) then
        MissileSystem.setWCSToFree(missileSystemCtx.firingUnits[unit.name], unit, false)
      end
    end
  end
elseif positionType == "HA" then
  if contacts then
    for _, contact in ipairs(contacts) do
      if unit.guid == contact.actualunitid then
        contact:DropContact()
      end
    end
  end

  for _, missileSystem in ipairs(missileSystems) do
    ---@type SBJ__MissileSystemContext|nil
    local missileSystemCtx = saveData.t.ground[missileSystem]

    if missileSystemCtx and missileSystemCtx.enabled then
      if MissileSystem.isRepositioning(missileSystemCtx.firingUnits[unit.name], false) then
        MissileSystem.setStateToHIDE(missileSystemCtx.firingUnits[unit.name], unit, false)
      end
    end
  end
elseif positionType == "RL" then
  if contacts then
    for _, contact in ipairs(contacts) do
      if unit.guid == contact.actualunitid then
        contact:DropContact()
      end
    end
  end

  for _, missileSystem in ipairs(missileSystems) do
    ---@type SBJ__MissileSystemContext|nil
    local missileSystemCtx = saveData.t.ground[missileSystem]

    if missileSystemCtx and missileSystemCtx.enabled then
      local isMet, context = MissileSystem.isMetWithResupplyUnits(missileSystemCtx, unit, false)

      if isMet and context then
        MissileSystem.setReloadStartTime(context, unit, false)
      else
        MissileSystem.setStateToStatic(missileSystemCtx, unit, false)
      end
    end
  end
elseif positionType == "AHA" then
  if contacts then
    for _, contact in ipairs(contacts) do
      if unit.guid == contact.actualunitid then
        contact:DropContact()
      end
    end
  end

  for _, missileSystem in ipairs(missileSystems) do
    ---@type SBJ__MissileSystemContext|nil
    local missileSystemCtx = saveData.t.ground[missileSystem]

    if missileSystemCtx and missileSystemCtx.enabled then
      local isMet, resupplyUnit = MissileSystem.isMetWithAmmoDepot(missileSystemCtx, unit, false)

      if isMet and resupplyUnit then
        MissileSystem.setReloadStartTime(resupplyUnit, unit, false)
      else
        MissileSystem.setStateToStatic(missileSystemCtx, unit, false)
      end
    end
  end
end

gKH.State.SaveTableToKey(saveData, "SaveData")
