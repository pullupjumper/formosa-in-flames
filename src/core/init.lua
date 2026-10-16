local LandingOps = require("src.modules.landingOps.init")
local Logger = require("src.utils.logger")
local config = require("src.core.config")
local saveData = require("src.core.saveData")
local constants = require("src.core.constants")
local StrikePlanner = require("src.modules.strikePlanner.init")
local IntegratedAirDefenseSystem = require("src.modules.integratedAirDefenseSystem")
local CommsJamming = require("src.modules.ew.commsJamming")
local Sigint = require("src.modules.ew.sigint")
local MissileSystem = require("src.modules.missileSystem.init")
local RunwayRepairment = require("src.modules.runwayRepairment")
local GameApi = require("src.utils.gameApi")
local PersistentState = require("src.core.persistentState")

if config.isEditMode then
  MissileSystem.ensureGroundState(config, saveData, constants.SIDES.RED)
  MissileSystem.ensureGroundState(config, saveData, constants.SIDES.BLUE)
  PersistentState.reset(saveData)
end

local function initEventActions()
  local actionNames = {
    "scripts\\china\\amphibiousOps\\landingCheck.lua",
    "scripts\\china\\amphibiousOps\\launchACV.lua",
    "scripts\\china\\amphibiousOps\\neutralizeAirlandingZone.lua",
    "scripts\\china\\amphibiousOps\\offloadVehicles.lua",
    "scripts\\china\\ew\\commsJamming.lua",
    "scripts\\china\\aircraftLanding.lua",
    "scripts\\china\\csgEnterArea.lua",
    "scripts\\china\\launchWZ8.lua",
    "scripts\\china\\scheduledStrikePlanner.lua",
    "scripts\\china\\aircraftAirborne.lua",
    "scripts\\score\\destroyUnits.lua",
    "scripts\\score\\successfulLanding.lua",
    "scripts\\score\\taiwaneseAssetIsDestroy.lua",
    "scripts\\moveToPosition.lua",
    "scripts\\scheduledReloadHideCheck.lua",
    "scripts\\taiwan\\aircraftLanding.lua",
    "scripts\\collectSigint.lua",
    "scripts\\runwayIsDamaged.lua",
    "scripts\\scheduledRunwayRepairment.lua",
  }

  for _, name in ipairs(actionNames) do
    GameApi.ScenEdit_SetAction({ mode = "update", type = "LuaScript", name = name, ScriptText = [[]] })
  end
end

local function initSpecialActions()
  local actions = {
    { path = "src\\scripts\\china\\specialActions\\controlPanel.lua",  actionName = "Control panel" },
    { path = "src\\scripts\\taiwan\\specialActions\\controlPanel.lua", actionName = "Control panel" },
  }

  for _, action in ipairs(actions) do
    local sideName = string.match(action.path, "scripts\\([^\\]+)\\")
    local actionEntry = GameApi.ScenEdit_GetSpecialAction({ side = sideName, ActionNameOrID = action.actionName })

    if not actionEntry then
      GameApi.ScenEdit_AddSpecialAction({
        IsRepeatable = true, ActionNameOrID = action.actionName, side = sideName, ScriptText = [[]]
      })
    else
      GameApi.ScenEdit_SetSpecialAction({
        mode = "update", ActionNameOrID = action.actionName, side = sideName, ScriptText = [[]]
      })
    end
  end
end

PersistentState.update(function(state)
  if #PersistentState.targetlist(state) > 0 then
    return
  end

  initEventActions()
  initSpecialActions()
  LandingOps.init(config, state)
  CommsJamming.init(config, state)
  StrikePlanner.init(config, state)
  RunwayRepairment.init(config, state)

  IntegratedAirDefenseSystem.initSide(config, state, constants.SIDES.BLUE)
  IntegratedAirDefenseSystem.initSide(config, state, constants.SIDES.RED)

  Sigint.initSide(config, state, constants.SIDES.ALLY)
  Sigint.initSide(config, state, constants.SIDES.RED)

  MissileSystem.initSide(config, state, constants.SIDES.RED)
  MissileSystem.initSide(config, state, constants.SIDES.BLUE)

  Logger.log(constants.TAGS.INIT, "Init data and save.")
end)

-- the following forces have been placed under your command:
-- 4. Surface Action Group
-- 1x Type 051C Luzhou Destroyer
-- 2x Type 051 Mod 4 Luda I Destroyers
-- 2x Type 052 Luhu Destroyers
