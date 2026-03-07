local gKH = require("src.core.gKH_State_Standalone")
local Logger = require("src.utils.logger")
local GameApi = require("src.utils.gameApi")
local MissileSystem = require("src.modules.missileSystem")
local constants = require("src.core.constants")
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
local positionType
local missileSystems = { "srbm", "mrbm", "mlrs", "glcm", "ascm" }

for _, trigger in ipairs(event.triggers) do
  if trigger["UnitEntersArea"] then
    positionType = string.match(trigger["UnitEntersArea"].Description, "(FP)") or
        string.match(trigger["UnitEntersArea"].Description, "(AHA)") or
        string.match(trigger["UnitEntersArea"].Description, "(HA)") or
        string.match(trigger["UnitEntersArea"].Description, "(RL)")
  end
end

if positionType == constants.POSITION_TYPES.FIRING_POINT then
  for _, missileSystem in ipairs(missileSystems) do
    ---@type SBJ__MissileSystemContext|nil
    local missileSystemCtx = saveData.c.ground[missileSystem]

    if missileSystemCtx and missileSystemCtx.enabled then
      if MissileSystem.isRepositioning(missileSystemCtx.firingUnits[unit.name], true) then
        MissileSystem.setWCSToFree(missileSystemCtx.firingUnits[unit.name], unit, true)
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

  for _, missileSystem in ipairs(missileSystems) do
    ---@type SBJ__MissileSystemContext|nil
    local missileSystemCtx = saveData.c.ground[missileSystem]

    if missileSystemCtx and missileSystemCtx.enabled then
      -- if MissileSystem.isRepositioning(missileSystemCtx.firingUnits[unit.name], true) then
      --   MissileSystem.setStateToHIDE(missileSystemCtx.firingUnits[unit.name], unit, true)
      --   MissileSystem.hideUnit(missileSystemCtx.firingUnits[unit.name], unit)
      -- end
      local firingUnitCtx = missileSystemCtx.firingUnits[unit.name]

      if firingUnitCtx then
        MissileSystem.setStateToHIDE(firingUnitCtx, unit, true)
        MissileSystem.hideUnit(firingUnitCtx, unit)
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

  for _, missileSystem in ipairs(missileSystems) do
    ---@type SBJ__MissileSystemContext|nil
    local missileSystemCtx = saveData.c.ground[missileSystem]

    if not missileSystemCtx or not missileSystemCtx.enabled then
      goto continue
    end

    local hasMet, context = MissileSystem.hasMetResupplyUnit(missileSystemCtx, unit, true)
    local firingUnitCtx = missileSystemCtx.firingUnits[unit.name]

    if firingUnitCtx and hasMet and context then
      MissileSystem.setReloadStartTime(context, unit, true)
    else
      MissileSystem.setStateToStatic(missileSystemCtx, unit, true)
      local resupplyUnitCtx = missileSystemCtx.resupplyUnits[unit.name]

      if not resupplyUnitCtx then
        goto continue
      end

      firingUnitCtx = missileSystemCtx.firingUnits[resupplyUnitCtx.firingUnit]
      local firingUnit = GameApi.ScenEdit_GetUnit(firingUnitCtx.name, constants.SIDES.ENEMY)

      if firingUnit and not MissileSystem.isLowAmmo(firingUnit, firingUnitCtx.ammoThreshold, firingUnitCtx.weaponDBID) then
        MissileSystem.hideUnit(resupplyUnitCtx, unit)
      end
    end

    ::continue::
  end
elseif positionType == constants.POSITION_TYPES.AMMO_HOLDING_AREA then
  if contacts then
    for _, contact in ipairs(contacts) do
      if unit.guid == contact.actualunitid then
        contact:DropContact()
      end
    end
  end

  for _, missileSystem in ipairs(missileSystems) do
    ---@type SBJ__MissileSystemContext|nil
    local missileSystemCtx = saveData.c.ground[missileSystem]
    if missileSystemCtx and missileSystemCtx.enabled then
      local hasMet, resupplyUnit = MissileSystem.hasMetAmmoDepot(missileSystemCtx, unit, true)
      local resupplyUnitCtx = missileSystemCtx.resupplyUnits[unit.name]

      if resupplyUnitCtx and hasMet and resupplyUnit then
        MissileSystem.setReloadStartTime(resupplyUnit, unit, true)
      else
        MissileSystem.setStateToStatic(missileSystemCtx, unit, true)
      end
    end
  end
end

gKH.State.SaveTableToKey(saveData, "SaveData")
