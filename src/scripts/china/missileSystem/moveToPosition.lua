local PersistentState = require("src.core.persistentState")
local Logger = require("src.utils.logger")
local GameApi = require("src.utils.gameApi")
local MissileSystem = require("src.modules.missileSystem.init")
local constants = require("src.core.constants")
local unit = GameApi.ScenEdit_UnitX()
local event = GameApi.ScenEdit_EventX()

if not event then
  Logger.error("event is nil")
  return
end

if not unit then
  Logger.error("unit is nil")
  return
end

PersistentState.update(function(saveData)
  MissileSystem.processMoveToPositionEvent({
    groundCtx = PersistentState.groundForces(saveData, constants.SIDES.ENEMY),
    unit = unit,
    event = event,
    isAuto = true,
    contacts = GameApi.ScenEdit_GetContacts(unit.side),
    behavior = {
      hideOnEnterHA = true,
      hideResupplyOnRLNoMeeting = true,
      firingUnitLookupSide = unit.side
    }
  })
end)
