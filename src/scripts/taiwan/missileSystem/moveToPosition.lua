local gKH = require("src.core.gKH_State_Standalone")
local Logger = require("src.utils.logger")
local GameApi = require("src.utils.gameApi")
local MissileSystem = require("src.modules.missileSystem.init")
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

MissileSystem.handleMoveToPositionEvent({
  groundCtx = saveData.t.ground,
  unit = unit,
  event = event,
  isAuto = false,
  contacts = GameApi.ScenEdit_GetContacts(unit.side),
  behavior = {
    hideOnEnterHA = false,
    hideResupplyOnRLNoMeeting = false,
    firingUnitLookupSide = unit.side
  }
})

gKH.State.SaveTableToKey(saveData, "SaveData")
