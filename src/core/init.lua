local ShipMovement = require("src.modules.landingOps.shipMovement")
local Logger = require("src.utils.logger")
local config = require("src.core.config")
local saveData = require("src.core.saveData")
local TargetingProcess = require("src.modules.strikePlanner.targetingProcess")
local UnitGenerator = require("src.modules.unitGenerator")
local IADS = require("src.modules.IADS")
local CommsJamming = require("src.modules.EW.commsJamming")
local SIGINT = require("src.modules.EW.sigint")
local Launcher = require("src.modules.launcher")
local RunwayRepairment = require("src.modules.runwayRepairment")
local GameApi = require("src.utils.gameApi")

if config.isSaved then
  gKH.State.SaveTableToKey(saveData, "SaveData")
end
---@type SBJ__SaveData|nil
local saveData = gKH.State.LoadTableFromKey("SaveData")

local function initEventActions()
  local actionNames = {
    "scripts\\china\\amphibiousOps\\landingCheck.lua",
    "scripts\\china\\amphibiousOps\\launchACV.lua",
    "scripts\\china\\amphibiousOps\\neutralizeAirlandingZone.lua",
    "scripts\\china\\amphibiousOps\\offloadVehicles.lua",
    "scripts\\china\\EW\\collectSIGINT.lua",
    "scripts\\china\\EW\\commsJamming.lua",
    "scripts\\china\\launcher\\moveToPosition.lua",
    "scripts\\china\\launcher\\scheduledReloadHideCheck.lua",
    "scripts\\china\\aircraftLanding.lua",
    "scripts\\china\\CSGEnterArea.lua",
    "scripts\\china\\H6NLaunchWZ8.lua",
    "scripts\\china\\scheduledStrikePlanner.lua",
    "scripts\\score\\destroyUnits.lua",
    "scripts\\score\\successfulLanding.lua",
    "scripts\\score\\taiwaneseAssetIsDestroy.lua",
    "scripts\\taiwan\\launcher\\moveToPosition.lua",
    "scripts\\taiwan\\launcher\\scheduledReloadHideCheck.lua",
    "scripts\\taiwan\\activiateANTISHIPMission.lua",
    "scripts\\taiwan\\aircraftLanding.lua",
    "scripts\\us\\collectSIGINT.lua",
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
    { path = "src\\scripts\\china\\specialActions\\addGPSJammers.lua",           actionName = "Add GPS jammers" },
    { path = "src\\scripts\\china\\specialActions\\addLandingShips.lua",         actionName = "Add landing ships" },
    { path = "src\\scripts\\china\\specialActions\\addSAGs.lua",                 actionName = "Add SAGs" },
    { path = "src\\scripts\\china\\specialActions\\addSubmarines.lua",           actionName = "Add submarines" },
    { path = "src\\scripts\\china\\specialActions\\unitStatusMenu.lua",          actionName = "Unit status menu" },
    { path = "src\\scripts\\china\\specialActions\\addLaunchers.lua",            actionName = "Add launchers" },
    { path = "src\\scripts\\taiwan\\specialActions\\addACs.lua",                 actionName = "Add aircraft" },
    { path = "src\\scripts\\taiwan\\specialActions\\addDeployedShipsAtPort.lua", actionName = "Add deployed ships at port" },
    { path = "src\\scripts\\taiwan\\specialActions\\addSAGs.lua",                actionName = "Add SAGs" },
    { path = "src\\scripts\\taiwan\\specialActions\\WCSSettingMenu.lua",         actionName = "WCS setting menu" },
    { path = "src\\scripts\\taiwan\\specialActions\\unitStatusMenu.lua",         actionName = "Unit status menu" },
    { path = "src\\scripts\\taiwan\\specialActions\\setupMenu.lua",              actionName = "Setup menu" },
    { path = "src\\scripts\\taiwan\\specialActions\\addLaunchers.lua",           actionName = "Add launchers" },
  }

  for _, action in ipairs(actions) do
    local sideName = string.match(action.path, "scripts\\([^\\]+)\\")
    GameApi.ScenEdit_SetSpecialAction({
      mode = "update", ActionNameOrID = action.actionName, side = sideName, ScriptText = [[]]
    })
  end
end

if saveData ~= nil and #saveData.c.targetlist <= 0 then
  initEventActions()
  initSpecialActions()
  ShipMovement.calculateDestination(config.c.PHIBOP, saveData)
  UnitGenerator.initAircraftContexts(saveData.t.air.landBased)
  TargetingProcess.scanTargets("China", config.targetScanning, saveData)
  RunwayRepairment.initRunways(config, saveData)

  if saveData.t.IADS.isActivated then
    IADS.initC2Contexts(saveData.t.IADS)
  end

  if saveData.c.IADS.isActivated then
    IADS.initC2FacilitiesContext(config.c.IADS, saveData.c.IADS)
  end

  if saveData.c.commsJamming.isActivated then
    CommsJamming.initCommsJammersContext(saveData, "China")
  end

  if saveData.u.SIGINT.isActivated then
    SIGINT.initReconAircraftContexts(saveData.u.SIGINT, "US")
    SIGINT.initReconAircraftContexts(saveData.c.SIGINT, "China")
  end

  if saveData.c.ground.isActivated then
    local systems = { "srbm", "mrbm", "mlrs", "glcm" }
    Launcher.initLauncherContexts(config.c.ground, saveData.c.ground, systems)
  end

  if saveData.t.ground.isActivated then
    local systems = { "srbm", "ascm", "mlrs", "glcm" }
    Launcher.initLauncherContexts(config.t.ground, saveData.t.ground, systems)
  end

  if config.isDevMode then
    gKH.State.SaveTableToKey(saveData, "SaveData")
    Logger.log("init", "Init data and save.")
  else
    Logger.log("init", "Does not init data.")
  end
end

-- the following forces have been placed under your command:
-- 4. Surface Action Group
-- 1x Type 051C Luzhou Destroyer
-- 2x Type 051 Mod 4 Luda I Destroyers
-- 2x Type 052 Luhu Destroyers
