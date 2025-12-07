local ShipMovement = require("src.modules.landingOps.shipMovement")
local Logger = require("src.utils.logger")
local config = require("src.core.constants")
local saveData = require("src.core.saveData")
local TargetingProcess = require("src.modules.strikePlanner.targetingProcess")
local UnitGenerator = require("src.modules.unitGenerator")
local IADS = require("src.modules.IADS")
local CommsJamming = require("src.modules.EW.commsJamming")
local SIGINT = require("src.modules.EW.sigint")
local RunwayRepairment = require("src.modules.runwayRepairment")
local GameApi = require("src.utils.gameApi")

if config.isSaved then
  gKH.State.SaveTableToKey(saveData, "SaveData")
end
---@type SBJ__SaveData
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
    GameApi.ScenEdit_SetAction({ mode = 'update', type = 'LuaScript', name = name, ScriptText = [[]] })
  end
end

if saveData ~= nil and #saveData.c.targetlist <= 0 then
  initEventActions()
  ShipMovement.calculateDestination(config.c.PHIBOP, saveData)
  UnitGenerator.initAircraftContexts(config, saveData.t.air.landBased)
  TargetingProcess.scanTargets('China', config.targetScanning, saveData)
  RunwayRepairment.initRunways(config, saveData)

  if saveData.t.IADS.isActivated then
    IADS.initC2Contexts(config, saveData.t.IADS)
  end

  if saveData.c.IADS.isActivated then
    IADS.initC2FacilitiesContext(config, config.c.IADS, saveData.c.IADS)
  end

  if saveData.c.commsJamming.isActivated then
    CommsJamming.initCommsJammersContext(config, saveData, 'China')
  end

  if saveData.u.SIGINT.isActivated then
    SIGINT.initReconAircraftContexts(config, saveData.u.SIGINT, 'US')
    SIGINT.initReconAircraftContexts(config, saveData.c.SIGINT, 'China')
  end

  if config.isDevMode then
    gKH.State.SaveTableToKey(saveData, "SaveData")
    Logger.log("init", 'Init data and save.')
  else
    Logger.log("init", 'Does not init data.')
  end
end

-- the following forces have been placed under your command:
-- 4. Surface Action Group
-- 1x Type 051C Luzhou Destroyer
-- 2x Type 051 Mod 4 Luda I Destroyers
-- 2x Type 052 Luhu Destroyers
