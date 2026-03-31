local gKH = require("src.core.gKH_State_Standalone")
local Logger = require("src.utils.logger")
local GameApi = require("src.utils.gameApi")
local MissileSystem = require("src.modules.missileSystem.init")
local constants = require("src.core.constants")
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
for _, trigger in ipairs(event.triggers) do
  if trigger["UnitEntersArea"] then
    positionType = string.match(trigger["UnitEntersArea"].Description, "(FP)") or
        string.match(trigger["UnitEntersArea"].Description, "(AHA)") or
        string.match(trigger["UnitEntersArea"].Description, "(HA)") or
        string.match(trigger["UnitEntersArea"].Description, "(RL)")
  end
end

if positionType == constants.POSITION_TYPES.FIRING_POINT then
  for _, missileSystem in pairs(constants.MISSILE_SYSTEM_TYPES) do
    ---@type SBJ__MissileSystemContext|nil
    local missileSystemCtx = saveData.t.ground[missileSystem]

    if missileSystemCtx and missileSystemCtx.enabled then
      if MissileSystem.isRepositioning(missileSystemCtx.firingUnits[unit.name], false) then
        MissileSystem.setWCSToFree(missileSystemCtx.firingUnits[unit.name], unit, false)
      end
    end
  end
elseif positionType == constants.POSITION_TYPES.HIDE_AREA then
  if contacts then
    for _, contact in ipairs(contacts) do
      if unit.guid == contact.actualunitid then
        contact:DropContact()
      end
    end
  end

  for _, missileSystem in pairs(constants.MISSILE_SYSTEM_TYPES) do
    ---@type SBJ__MissileSystemContext|nil
    local missileSystemCtx = saveData.t.ground[missileSystem]

    if missileSystemCtx and missileSystemCtx.enabled then
      if MissileSystem.isRepositioning(missileSystemCtx.firingUnits[unit.name], false) then
        MissileSystem.setStateToHIDE(missileSystemCtx.firingUnits[unit.name], unit, false)
      end
    end
  end
elseif positionType == constants.POSITION_TYPES.RELOAD_POINT then
  if contacts then
    for _, contact in ipairs(contacts) do
      if unit.guid == contact.actualunitid then
        contact:DropContact()
      end
    end
  end

  for _, missileSystem in pairs(constants.MISSILE_SYSTEM_TYPES) do
    ---@type SBJ__MissileSystemContext|nil
    local missileSystemCtx = saveData.t.ground[missileSystem]

    if missileSystemCtx and missileSystemCtx.enabled then
      local hasMet, context = MissileSystem.hasMetResupplyUnit(missileSystemCtx, unit, false)
      local firingUnitCtx = missileSystemCtx.firingUnits[unit.name]

      if firingUnitCtx and hasMet and context then
        MissileSystem.setReloadStartTime(context, unit, false)
      else
        MissileSystem.setStateToStatic(missileSystemCtx, unit, false)
      end
    end
  end
elseif positionType == constants.POSITION_TYPES.AMMO_HOLDING_AREA then
  if contacts then
    for _, contact in ipairs(contacts) do
      if unit.guid == contact.actualunitid then
        contact:DropContact()
      end
    end
  end

  for _, missileSystem in pairs(constants.MISSILE_SYSTEM_TYPES) do
    ---@type SBJ__MissileSystemContext|nil
    local missileSystemCtx = saveData.t.ground[missileSystem]

    if missileSystemCtx and missileSystemCtx.enabled then
      local hasMet, resupplyUnit = MissileSystem.hasMetAmmoDepot(missileSystemCtx, unit, false)
      local resupplyUnitCtx = missileSystemCtx.resupplyUnits[unit.name]

      if resupplyUnitCtx and hasMet and resupplyUnit then
        MissileSystem.setReloadStartTime(resupplyUnit, unit, false)
      else
        MissileSystem.setStateToStatic(missileSystemCtx, unit, false)
      end
    end
  end
end

gKH.State.SaveTableToKey(saveData, "SaveData")
