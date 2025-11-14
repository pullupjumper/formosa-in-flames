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
---@param packageData SBJ__Package The strike package containing flight group data
---@return number|nil # Unix timestamp for when loadout should start, or nil if cannot be calculated
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
---@param packageData SBJ__Package The strike package to check
---@return boolean # true if current time has reached or passed the loadout start time
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
--- Applies loadouts to aircraft at their bases and updates loadout status tracking
---@param packageData SBJ__Package The strike package containing flight group configurations
local function initiateLoadoutForPackage(packageData)
  local roles = { "striker", "escort", "wildWeasel", "jammer" }
  local timeToReady = packageData.timeToReady or (9 * 60)

  Logger.log("air", "Starting loadout for package: " .. packageData.striker.missionParams.name)

  for _, role in ipairs(roles) do
    if packageData[role] and packageData[role].loadoutID then
      local roleData = packageData[role]
      local loadoutID = roleData.loadoutID
      local unitCount = roleData.unitCount
      local targetUnitDBID = roleData.unitDBID

      -- If no unitDBID is specified, skip this role
      if not targetUnitDBID then
        Logger.log("air", "No unitDBID specified for role: " .. role .. ", skipping loadout setup")
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
                Logger.log("air", string.format(
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

        Logger.log("air", string.format(
          "Completed loadout setup for %s: %d/%d units processed (target DBID: %d)",
          role, unitsProcessed, unitCount, targetUnitDBID
        ))

        -- If insufficient aircraft of matching type found, log warning
        if unitsProcessed < unitCount then
          Logger.log("air", string.format(
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
  Logger.log("air", "All loadouts initiated, expected ready at: " .. expectedReadyTimeStr)
end

--- Check if weapon loading is complete
---@param packageData SBJ__Package The strike package to check
---@return boolean # true if loadout has been initiated and expected ready time has passed
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
---@param packageData SBJ__Package The strike package containing flight groups
---@return SBJ__MissionEntry|nil # The flight group with the earliest start time, or nil if none found
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
---@param packageData SBJ__Package The strike package containing mission parameters
---@param role string The role identifier (e.g., "striker", "escort", "wildWeasel", "jammer", "tanker")
---@return boolean # true if mission exists or was successfully created
local function createMission(packageData, role)
  local mission = GameApi.ScenEdit_GetMission("China", packageData[role].missionParams.name)

  if not mission then
    Logger.log("air", "Mission not found, creating: " .. packageData[role].missionParams.name)

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
---@param packageData SBJ__Package The strike package containing unit assignment data
---@return boolean # true if the primary striker units were successfully assigned
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
--- Handles weapon loading, mission creation, target assignment, and unit launch
---@param config SBJ__CONFIG The global configuration table
---@param saveData SBJ__SaveData The persistent save data containing ATO state
---@param packageData SBJ__Package The strike package data to process
---@return boolean # true if package was successfully launched, false if still in preparation
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

  Logger.log("air", "All missions for package " .. packageData.striker.missionParams.name .. " created or verified.")

  if packageData.reconUAV then
    if not packageData.reconUAV.takeoffTime then
      -- Calculate flight time using speed and course from template
      local distance, flightTime = GameUtils.calculatePathDistanceAndTime(
        packageData.reconUAV.course,
        packageData.reconUAV.speed
      )

      -- Calculate takeoff and end times
      local takeoffTime = Utils.parseDatetimeToTimestamp(packageData.striker.endTime) +
          config.c.ground.srbm.reloadTime - flightTime
      local endTime = takeoffTime + flightTime

      packageData.reconUAV.takeoffTime = os.date("!%Y-%m-%d %H:%M:%S", takeoffTime)
      packageData.reconUAV.endTime = os.date("!%Y-%m-%d %H:%M:%S", endTime)

      Logger.log("air", string.format("Recon UAV takeoff time set to: %s",
        packageData.reconUAV.takeoffTime))
    end

    local copyReconUAV = Utils.deepCopy(packageData.reconUAV)
    copyReconUAV.hasLaunched = false
    copyReconUAV.isFinished = false
    copyReconUAV.trackingTargetGUID = nil
    table.insert(saveData.c.recon.queue, copyReconUAV)
    Logger.log("air", "Recon UAV added to queue.")
  end

  -- 5. Find targets
  local evaluatedTargetlist = packageData.target.list
  Logger.log("air", packageData.striker.missionParams.name .. " found " .. #evaluatedTargetlist .. " targets.")

  if #evaluatedTargetlist < packageData.target.minTargetCount then
    Logger.log("air", "Not enough targets found for " ..
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

  Logger.log("air", "Targets assigned to mission " .. packageData.striker.missionParams.name)

  -- 7. Assign units to all missions
  if assignUnits(packageData) then
    Logger.log("air", packageData.striker.missionParams.name ..
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
---@param waveData SBJ__Wave The wave containing multiple strike packages
---@return boolean # true if all packages in the wave have been launched
local function isWaveFinished(waveData)
  for _, packageData in ipairs(waveData.packages) do
    if not packageData.hasLaunched then
      return false -- At least one package has not been launched
    end
  end
  return true
end

--- The main entry point for air strikes.
--- Iterates through ATO waves and packages, processing each strike package sequentially
---@param config SBJ__CONFIG The global configuration table
---@param saveData SBJ__SaveData The persistent save data containing ATO waves and packages
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
