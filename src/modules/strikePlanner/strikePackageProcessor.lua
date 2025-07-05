-- /src/modules/strikePlanner/StrikePackageProcessor.lua
-- This is a procedural processor module. It takes packageData and processes it
-- in a single, sequential flow.

local Utils = require("src.utils.utils")
local GameApi = require("src.utils.gameApi")
local Logger = require("src.utils.logger")
local GameUtils = require("src.utils.gameUtils")
local TargetingProcess = require("src.modules.strikePlanner.targetingProcess")
local AssignMission = require("src.modules.assignMission")

local StrikePackageProcessor = {}

--------------------------------------------------------------------------------
-- Private Helper Functions
--------------------------------------------------------------------------------

--- Creates a mission for a specific role if it doesn't exist.
---@param packageData SBJ__Package
---@param role string
---@return boolean
function StrikePackageProcessor._createMission(packageData, role)
  local mission = GameApi.ScenEdit_GetMission("China", packageData[role].missionParams.name)

  if not mission then
    Logger.log("Mission not found, creating: " .. packageData[role].missionParams.name)

    mission = GameUtils.CreateMission(
      "China",
      packageData[role].missionParams.name,
      packageData[role].missionParams.type,
      packageData[role].missionParams.opts,
      packageData[role].emcon
    )

    if mission and packageData[role].endTime then
      mission['OnDeactivateDelete'] = true
      mission['OnDeactivateRTB'] = true
      mission['TakeOffTime'] = packageData[role].startTime
      mission['endtime'] = packageData[role].endTime
    end
  end

  return mission ~= nil
end

--- Assigns all units in the package to their respective missions.
---@param packageData SBJ__Package
---@return boolean Returns true if the primary striker units were assigned.
function StrikePackageProcessor._assignUnits(packageData)
  local roles = { "striker", "escort", "wildWeasel", "jammer" }
  local strikerAssigned = false

  for _, role in ipairs(roles) do
    if packageData[role] then
      local result = AssignMission.AssignEmbarkedUnitToStrikeMission(
        packageData[role].baseGUID,
        packageData[role].unitCount,
        packageData[role].weaponDBID,
        packageData[role].unitDBID, -- Handles jammer case where weaponDBID is 0
        packageData[role].missionParams.name,
        false
      )
      if role == "striker" and result and #result > 0 then
        strikerAssigned = true
      end
    end
  end

  return strikerAssigned
end

--- Finds and evaluates potential targets for the package.
---@param packageData SBJ__Package
---@param CONFIG SBJ__CONFIG
---@param saveData SBJ__SaveData
---@param contacts CMO__Contact[]
---@param isFirstWave boolean
---@return string[]
function StrikePackageProcessor._findTargets(packageData, CONFIG, saveData, contacts, isFirstWave)
  local evaluatedTargetlist = {}

  -- Assess fixed targets (from mission plan)
  if packageData.striker.missionParams.opts.type == "land" then
    evaluatedTargetlist = TargetingProcess.AssessTargetsDamage(packageData, isFirstWave)
  end

  -- Find dynamic targets (based on filters)
  if type(packageData.target.filterNames) == 'table' and #packageData.target.filterNames > 0 then
    for _, name in ipairs(packageData.target.filterNames) do
      if TargetingProcess[name] then
        local filteredTargets = TargetingProcess[name]({
          CONFIG = CONFIG,
          saveData = saveData,
          contacts = contacts,
          task = packageData -- Pass packageData as 'task' for compatibility
        })
        Utils.InsertList(evaluatedTargetlist, filteredTargets)
      else
        Logger.error("TargetingProcess filter not found: " .. name)
      end
    end
  end

  return evaluatedTargetlist
end

--------------------------------------------------------------------------------
-- Public Interface
--------------------------------------------------------------------------------

--- This is the main entry point. It takes a packageData table and executes
--- the entire launch sequence for it.
---@param packageData SBJ__Package The pure data table from saveData
---@param CONFIG SBJ__CONFIG
---@param saveData SBJ__SaveData
---@param contacts CMO__Contact[]
---@param isFirstWave boolean
---@return boolean hasLaunched
function StrikePackageProcessor.Process(packageData, CONFIG, saveData, contacts, isFirstWave)
  -- 1. Check if it's time to start
  if not (packageData.escort and GameUtils.IsAfterStartTime(packageData.escort.startTime)) then
    return false
  end

  -- 2. Create all missions for the package. The striker mission is critical.
  local roles = { "striker", "escort", "wildWeasel", "jammer" }
  for _, role in ipairs(roles) do
    if packageData[role] then
      local missionCreated = StrikePackageProcessor._createMission(packageData, role)
      if role == 'striker' and not missionCreated then
        Logger.error("Critical failure: Could not create striker mission. Aborting package.")
        return false -- Abort the entire process if the main mission fails
      end
    end
  end
  Logger.log("All missions for package " .. packageData.striker.missionParams.name .. " created or verified.")

  -- 3. Find targets
  local evaluatedTargetlist = StrikePackageProcessor._findTargets(packageData, CONFIG, saveData, contacts, isFirstWave)
  Logger.log(packageData.striker.missionParams.name .. " found " .. #evaluatedTargetlist .. " targets.")

  if #evaluatedTargetlist < packageData.target.minTargetCount then
    Logger.log("Not enough targets found for " ..
      packageData.striker.missionParams.name .. ". Need " .. packageData.target.minTargetCount)
    return false
  end

  -- 4. Assign targets to the striker mission
  local targetsAssigned = GameApi.ScenEdit_AssignUnitAsTarget(
    evaluatedTargetlist,
    packageData.striker.missionParams.name
  )
  if not targetsAssigned then
    return false
  end
  Logger.log("Targets assigned to mission " .. packageData.striker.missionParams.name)

  -- 5. Assign units to all missions
  if StrikePackageProcessor._assignUnits(packageData) then
    Logger.log(packageData.striker.missionParams.name .. " status -> LAUNCHED. Package has been launched.")
    return true -- Success
  else
    Logger.error(packageData.striker.missionParams.name .. " failed to assign striker units.")
    return false
  end
end

return StrikePackageProcessor
