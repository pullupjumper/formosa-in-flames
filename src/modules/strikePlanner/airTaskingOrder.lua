-- /src/modules/strikePlanner/airTaskingOrder.lua
-- Air Tasking Order logic with integrated strike package processing.
-- Handles the complete lifecycle of ATO waves and strike packages.

local Utils = require("src.utils.utils")
local GameApi = require("src.utils.gameApi")
local Logger = require("src.utils.logger")
local GameUtils = require("src.utils.gameUtils")
local AssignMission = require("src.modules.assignMission")

local AirTaskingOrder = {}

local ADVANCE_SECONDS = 300

--------------------------------------------------------------------------------
-- Strike Package Processing Functions (integrated from strikePackageProcessor)
--------------------------------------------------------------------------------

--- Calculate the start time for weapon loading
---@param packageData SBJ__Package
---@return number|nil loadoutStartTime timestamp
local function calculateLoadoutStartTime(packageData)
  local earliestStartTime = nil
  local roles = { "striker", "escort", "wildWeasel", "jammer" }

  -- Find the earliest start time among all flight groups
  for _, role in ipairs(roles) do
    if packageData[role] and packageData[role].startTime then
      local startTimeTimestamp = Utils.parseDatetimeToTimestamp(packageData[role].startTime)
      if not earliestStartTime or startTimeTimestamp < earliestStartTime then
        earliestStartTime = startTimeTimestamp
      end
    end
  end

  if not earliestStartTime then
    return nil
  end

  -- Get the package-level timeToReady
  local timeToReady = packageData.timeToReady or (9 * 60)
  local loadoutStartTime = earliestStartTime - timeToReady

  return loadoutStartTime
end

--- Check if it's time to start weapon loading
---@param packageData SBJ__Package
---@return boolean
local function isTimeToStartLoadout(packageData)
  -- Get the package-level loadoutStatus
  local loadoutStatus = packageData.loadoutStatus
  if not loadoutStatus then
    Logger.error("loadoutStatus not found in package data")
    return false
  end

  -- Calculate loadout start time
  if not loadoutStatus.loadoutStartTime then
    loadoutStatus.loadoutStartTime = calculateLoadoutStartTime(packageData)
  end

  if not loadoutStatus.loadoutStartTime then
    return false -- Cannot calculate start time
  end

  -- Convert timestamp back to string format for GameUtils.isAfterStartTime() use
  ---@type string
  local loadoutStartTimeStr = os.date("!%Y-%m-%d %H:%M:%S", loadoutStatus.loadoutStartTime)
  return GameUtils.isAfterStartTime(loadoutStartTimeStr, ADVANCE_SECONDS)
end

--- Set weapon loadouts for all flight groups in the package
---@param packageData SBJ__Package
local function initiateLoadoutForPackage(packageData)
  local roles = { "striker", "escort", "wildWeasel", "jammer" }
  local timeToReady = packageData.timeToReady or (9 * 60)

  Logger.log("Starting loadout for package: " .. packageData.striker.missionParams.name)

  for _, role in ipairs(roles) do
    if packageData[role] and packageData[role].loadoutID then
      local roleData = packageData[role]
      local loadoutID = roleData.loadoutID
      local unitCount = roleData.unitCount
      local targetUnitDBID = roleData.unitDBID

      -- If no unitDBID is specified, skip this role
      if not targetUnitDBID then
        Logger.log("No unitDBID specified for role: " .. role .. ", skipping loadout setup")
        goto continue
      end

      -- Get the base
      local base = GameApi.ScenEdit_GetUnit(roleData.baseGUID)
      if base and #base.embarkedUnits['Aircraft'] > 0 then
        local unitsProcessed = 0

        -- Only set loadout for aircraft matching unitDBID
        for _, unitGUID in ipairs(base.embarkedUnits['Aircraft']) do
          if unitsProcessed >= unitCount then
            break -- Processed sufficient number of units
          end

          local unit = GameApi.ScenEdit_GetUnit(unitGUID)
          if unit then
            -- Only process aircraft matching the specified unitDBID
            if unit.dbid == targetUnitDBID then
              local result = GameApi.ScenEdit_SetLoadout({
                unitname = unit.name,
                LoadoutID = loadoutID,
                TimeToReady_Minutes = timeToReady / 60
              })

              if result then
                unitsProcessed = unitsProcessed + 1
                Logger.log(string.format(
                  "Setting loadout for %s (DBID:%d, %s %d/%d) with ID %d, ready in %d seconds",
                  unit.name, unit.dbid, role, unitsProcessed, unitCount, loadoutID, timeToReady
                ))
              else
                Logger.error("Failed to set loadout for " .. unit.name)
              end
            end
            -- If unit.dbid != targetUnitDBID, skip this unit without any action
          end
        end

        Logger.log(string.format(
          "Completed loadout setup for %s: %d/%d units processed (target DBID: %d)",
          role, unitsProcessed, unitCount, targetUnitDBID
        ))

        -- If insufficient aircraft of matching type found, log warning
        if unitsProcessed < unitCount then
          Logger.log(string.format(
            "loging: Only found %d aircraft with DBID %d for %s role, need %d",
            unitsProcessed, targetUnitDBID, role, unitCount
          ))
        end
      end

      ::continue::
    end
  end

  -- Update status - using existing time function
  local currentTime = GameApi.ScenEdit_CurrentTime()
  local loadoutStatus = packageData.loadoutStatus
  loadoutStatus.isLoadoutInitiated = true
  loadoutStatus.loadoutInitiatedTime = currentTime
  loadoutStatus.expectedReadyTime = currentTime + timeToReady

  local expectedReadyTimeStr = os.date("!%Y-%m-%d %H:%M:%S", loadoutStatus.expectedReadyTime)
  Logger.log("All loadouts initiated, expected ready at: " .. expectedReadyTimeStr)
end

--- Check if weapon loading is complete
---@param packageData SBJ__Package
---@return boolean
local function isLoadoutReady(packageData)
  local loadoutStatus = packageData.loadoutStatus
  if not loadoutStatus then
    Logger.error("loadoutStatus not found in package data")
    return false
  end

  -- If loadout is ready
  if loadoutStatus.isLoadoutInitiated and loadoutStatus.expectedReadyTime then
    ---@type string
    local expectedReadyTimeStr = os.date("!%Y-%m-%d %H:%M:%S", loadoutStatus.expectedReadyTime)
    return GameUtils.isAfterStartTime(expectedReadyTimeStr)
  end

  -- If loadout process hasn't started yet, start now
  if not loadoutStatus.isLoadoutInitiated then
    initiateLoadoutForPackage(packageData)
    return false -- First time setup, need to wait
  end

  -- Currently waiting
  return false
end

--- Find the earliest departing flight group
---@param packageData SBJ__Package
---@return table|nil earliestRole
local function findEarliestRole(packageData)
  local earliestRole = nil
  local earliestTime = nil
  local roles = { "striker", "escort", "wildWeasel", "jammer" }

  for _, role in ipairs(roles) do
    if packageData[role] and packageData[role].startTime then
      local startTime = Utils.parseDatetimeToTimestamp(packageData[role].startTime)
      if not earliestTime or startTime < earliestTime then
        earliestTime = startTime
        earliestRole = packageData[role]
      end
    end
  end

  return earliestRole
end

--- Creates a mission for a specific role if it doesn't exist.
---@param packageData SBJ__Package
---@param role string
---@return boolean
local function createMission(packageData, role)
  local mission = GameApi.ScenEdit_GetMission("China", packageData[role].missionParams.name)

  if not mission then
    Logger.log("Mission not found, creating: " .. packageData[role].missionParams.name)

    mission = GameUtils.createMission(
      "China",
      packageData[role].missionParams.name,
      packageData[role].missionParams.type,
      packageData[role].missionParams.opts,
      packageData[role].emcon
    )

    if mission and packageData[role].endTime then
      mission['OnDeactivateDelete'] = true
      mission['OnDeactivateRTB'] = true

      -- if role == 'striker' and packageData[role].startTime then
      --   mission['TakeOffTime'] = packageData[role].startTime
      -- end
      if packageData[role].startTime then
        mission['TakeOffTime'] = packageData[role].startTime
      end

      mission['endtime'] = packageData[role].endTime

      if packageData[role].timeOnStation then
        mission['TimeOnTargetStation'] = packageData[role].timeOnStation
      end
    end
  end

  return mission ~= nil
end

--- Assigns all units in the package to their respective missions.
---@param packageData SBJ__Package
---@return boolean Returns true if the primary striker units were assigned.
local function assignUnits(packageData)
  local roles = { "striker", "escort", "wildWeasel", "jammer", "tanker" }
  local strikerAssigned = false

  for _, role in ipairs(roles) do
    if packageData[role] then
      local result = AssignMission.assignEmbarkedUnitToStrikeMission(
        packageData[role].baseGUID,
        packageData[role].unitCount,
        packageData[role].weaponDBID,
        packageData[role].unitDBID, -- Handles jammer case where weaponDBID is 0
        packageData[role].missionParams.name,
        false
      )
      if role ~= 'tanker' and role ~= 'striker' then
        GameApi.ScenEdit_CreateMissionFlightPlan('China', packageData[role].missionParams.name, {})
      end

      if role == "striker" and result and #result > 0 then
        strikerAssigned = true
      end
    end
  end

  return strikerAssigned
end

--- Processes a single strike package through its complete lifecycle
---@param config SBJ__CONFIG The config table from configData
---@param saveData SBJ__SaveData The save data table
---@param packageData SBJ__Package The pure data table from saveData
---@return boolean hasLaunched
local function processPackage(config, saveData, packageData)
  -- 1. Check if weapon loading start time has been reached
  if not isTimeToStartLoadout(packageData) then
    return false -- Not yet time to start loading
  end

  -- 2. Check if weapon loading is complete
  if not isLoadoutReady(packageData) then
    return false -- Currently loading weapons or waiting for completion
  end

  -- 3. Check if earliest flight group has reached departure time
  local earliestRole = findEarliestRole(packageData)
  if not (earliestRole and GameUtils.isAfterStartTime(earliestRole.startTime, ADVANCE_SECONDS)) then
    return false -- Earliest flight group hasn't reached departure time yet
  end

  -- 4. Create all missions - strike mission is critical
  local roles = { "tanker", "striker", "escort", "wildWeasel", "jammer", }

  for _, role in ipairs(roles) do
    if packageData[role] then
      local missionCreated = createMission(packageData, role)

      if role == 'striker' and not missionCreated then
        Logger.error("Critical failure: Could not create striker mission. Aborting package.")
        return false -- If primary mission creation fails, abort entire process
      end
    end
  end

  Logger.log("All missions for package " .. packageData.striker.missionParams.name .. " created or verified.")

  if packageData.reconUAV then
    if not packageData.reconUAV.takeoffTime then
      local takeoffTime = 0
      local missionStartTime = 0

      if packageData.reconUAV.unitDBID == config.platform.BZK005 then
        if packageData.reconUAV.missionName == 'RECON/1' then
          takeoffTime = Utils.parseDatetimeToTimestamp(packageData.striker.endTime) +
              config.c.ground.srbm.reloadTime - config.c.recon.flightTime.BZK005_RECON_1
          missionStartTime = takeoffTime + config.c.recon.flightTime.BZK005_RECON_1
        elseif packageData.reconUAV.missionName == 'RECON/2' then
          takeoffTime = Utils.parseDatetimeToTimestamp(packageData.striker.endTime) +
              config.c.ground.srbm.reloadTime - config.c.recon.flightTime.BZK005_RECON_2
          missionStartTime = takeoffTime + config.c.recon.flightTime.BZK005_RECON_2
        end
        -- takeoffTime = Utils.parseDatetimeToTimestamp(packageData.striker.endTime) + config.c.ground.srbm
        --     .reloadTime - 10 * 60
        -- local missionStartTime = takeoffTime + 30 * 60
        packageData.reconUAV.takeoffTime = os.date("!%Y-%m-%d %H:%M:%S", takeoffTime)
        packageData.reconUAV.missionStartTime = os.date("!%Y-%m-%d %H:%M:%S", missionStartTime)
        Logger.log("Recon UAV takeoff time set to: " .. packageData.reconUAV.takeoffTime)
        Logger.log("Recon UAV mission start time set to: " .. packageData.reconUAV.missionStartTime)
      end

      if packageData.reconUAV.unitDBID == config.platform.H6N then
        -- local takeoffTime = Utils.parseDatetimeToTimestamp(packageData.striker.endTime) - 30 * 60
        takeoffTime = Utils.parseDatetimeToTimestamp(packageData.striker.endTime) +
            config.c.ground.srbm.reloadTime - config.c.recon.flightTime.H6N_RECON
        packageData.reconUAV.takeoffTime = os.date("!%Y-%m-%d %H:%M:%S", takeoffTime)
        Logger.log("Recon UAV takeoff time set to: " .. packageData.reconUAV.takeoffTime)
      end
    end

    local copyReconUAV = Utils.deepCopy(packageData.reconUAV)
    copyReconUAV.hasLaunched = false
    table.insert(saveData.c.recon.queue, copyReconUAV)
    Logger.log("Recon UAV added to queue.")
  end

  -- 5. Find targets
  -- local evaluatedTargetlist = findTargets(packageData, config, saveData, contacts, isFirstWave)
  local evaluatedTargetlist = packageData.target.list
  Logger.log(packageData.striker.missionParams.name .. " found " .. #evaluatedTargetlist .. " targets.")

  if #evaluatedTargetlist < packageData.target.minTargetCount then
    Logger.log("Not enough targets found for " ..
      packageData.striker.missionParams.name .. ". Need " .. packageData.target.minTargetCount)
    return false
  end

  -- 6. Assign targets to strike mission
  local targetsAssigned = GameApi.ScenEdit_AssignUnitAsTarget(
    evaluatedTargetlist,
    packageData.striker.missionParams.name
  )

  if not targetsAssigned then
    return false
  end

  Logger.log("Targets assigned to mission " .. packageData.striker.missionParams.name)

  -- 7. Assign units to all missions
  if assignUnits(packageData) then
    Logger.log(packageData.striker.missionParams.name ..
      " status -> LAUNCHED. All loadouts ready, package has been launched.")
    return true -- Success
  else
    Logger.error(packageData.striker.missionParams.name .. " failed to assign striker units.")
    return false
  end
end

--------------------------------------------------------------------------------
-- Wave Management Functions
--------------------------------------------------------------------------------

--- Checks if all packages in a wave have been launched.
---@param waveData table
---@return boolean
local function isWaveFinished(waveData)
  for _, packageData in ipairs(waveData.packages) do
    if not packageData.hasLaunched then
      return false -- At least one package has not been launched
    end
  end
  return true
end

--- The main entry point for air strikes.
--- It iterates through waves and packages, handing off the processing to the processor.
---@param config SBJ__CONFIG
---@param saveData SBJ__SaveData
function AirTaskingOrder.airStrike(config, saveData)
  if not saveData or not saveData.c or not saveData.c.air or not saveData.c.air.ATO then
    -- Guard against missing data
    return
  end

  for _, waveData in pairs(saveData.c.air.ATO) do
    if waveData.isActivated and not waveData.hasLaunched then
      for _, packageData in ipairs(waveData.packages) do
        if not packageData.hasLaunched then
          -- Process the entire sequence for a package in one go.
          -- Returns true if the package was successfully launched.
          local launched = processPackage(config, saveData, packageData)
          if launched then
            packageData.hasLaunched = true
            -- As per original logic, break after one successful launch to process
            -- the next package in the next 5-minute tick.
            break
          end
        end
      end

      -- After processing, check if the entire wave is now finished.
      if isWaveFinished(waveData) then
        waveData.hasLaunched = true
      end
    end
  end
end

return AirTaskingOrder
