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

if config.isSaved then
  MissileSystem.seedGroundForceState(config, saveData, constants.SIDES.ENEMY)
  MissileSystem.seedGroundForceState(config, saveData, constants.SIDES.PLAYER)
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
    "scripts\\taiwan\\activateAntiShipMission.lua",
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
    { path = "src\\scripts\\china\\specialActions\\addACs.lua",                  actionName = "Add aircraft" },
    { path = "src\\scripts\\china\\specialActions\\addC2Facilities.lua",         actionName = "Add C2 facilities" },
    { path = "src\\scripts\\china\\specialActions\\addCSG.lua",                  actionName = "Add CSG" },
    { path = "src\\scripts\\china\\specialActions\\addGnssJammers.lua",          actionName = "Add GNSS jammers" },
    { path = "src\\scripts\\china\\specialActions\\addLandingShips.lua",         actionName = "Add landing ships" },
    { path = "src\\scripts\\china\\specialActions\\addSAGs.lua",                 actionName = "Add SAGs" },
    { path = "src\\scripts\\china\\specialActions\\addSubmarines.lua",           actionName = "Add submarines" },
    { path = "src\\scripts\\china\\specialActions\\unitStatusMenu.lua",          actionName = "Unit status menu" },
    { path = "src\\scripts\\china\\specialActions\\addMissileSystems.lua",       actionName = "Add missile systems" },
    { path = "src\\scripts\\china\\specialActions\\setupMenu.lua",               actionName = "Setup menu" },
    { path = "src\\scripts\\taiwan\\specialActions\\addACs.lua",                 actionName = "Add aircraft" },
    { path = "src\\scripts\\taiwan\\specialActions\\addDeployedShipsAtPort.lua", actionName = "Add deployed ships at port" },
    { path = "src\\scripts\\taiwan\\specialActions\\addSAGs.lua",                actionName = "Add SAGs" },
    { path = "src\\scripts\\taiwan\\specialActions\\wcsSettingMenu.lua",         actionName = "WCS setting menu" },
    { path = "src\\scripts\\taiwan\\specialActions\\unitStatusMenu.lua",         actionName = "Unit status menu" },
    { path = "src\\scripts\\taiwan\\specialActions\\setupMenu.lua",              actionName = "Setup menu" },
    { path = "src\\scripts\\taiwan\\specialActions\\addMissileSystems.lua",      actionName = "Add missile systems" },
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

-- isDevMode decides whether the one-time init below is persisted
local runInit = config.isDevMode and PersistentState.update or PersistentState.read

runInit(function(state)
  if #PersistentState.targetlist(state) > 0 then
    return
  end

  initEventActions()
  initSpecialActions()
  LandingOps.init(config, state)
  CommsJamming.init(config, state)
  StrikePlanner.init(config, state)
  RunwayRepairment.init(config, state)

  IntegratedAirDefenseSystem.initSide(config, state, constants.SIDES.PLAYER)
  IntegratedAirDefenseSystem.initSide(config, state, constants.SIDES.ENEMY)

  Sigint.initSide(config, state, "US")
  Sigint.initSide(config, state, constants.SIDES.ENEMY)

  MissileSystem.initSide(config, state, constants.SIDES.ENEMY)
  MissileSystem.initSide(config, state, constants.SIDES.PLAYER)

  if config.isDevMode then
    Logger.log(constants.TAGS.INIT, "Init data and save.")
  else
    Logger.log(constants.TAGS.INIT, "Does not init data.")
  end
end)

-- the following forces have been placed under your command:
-- 4. Surface Action Group
-- 1x Type 051C Luzhou Destroyer
-- 2x Type 051 Mod 4 Luda I Destroyers
-- 2x Type 052 Luhu Destroyers
