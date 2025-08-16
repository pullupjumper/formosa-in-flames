local TargetingProcess = require("src.modules.strikePlanner.targetingProcess")
local GameApi = require("src.utils.gameApi")
local Utils = require("src.utils.utils")
local Logger = require("src.utils.logger")
local Launcher = require("src.modules.launcher")

---@class DynamicFireSupportPlan
local DynamicFireSupportPlan = {}

-- Local helper functions (private)

---Process individual FST template, perform target filtering and BDA assessment
---@param config SBJ__CONFIG
---@param saveData SBJ__SaveData
---@param contacts CMO__Contact[]
---@param fstTemplate SBJ__FstTemplate
---@param isFirstWave boolean
---@return CMO__Contact[] strikeTargets
local function processFST(config, saveData, contacts, fstTemplate, isFirstWave)
  -- Choose different assessment methods based on target type
  local strikeTargets = {}

  if fstTemplate.target.filterNames then
    -- For targets requiring dynamic filtering (e.g., radar, air defense systems), use passed contacts
    Logger.log("Using dynamic target filtering, filters: " .. table.concat(fstTemplate.target.filterNames, ", "))
    local shouldTrack = fstTemplate.target.filterNames[1] == "findNavalTargets" or
        fstTemplate.target.filterNames[1] == "findRadioDirection"

    local filterOpts = {
      contacts = contacts,
      task = {
        target = {
          areas = fstTemplate.target.areas,
          contactAge = fstTemplate.target.contactAge
        }
      },
      config = config,
      saveData = saveData,
      shouldTrack = shouldTrack
    }

    -- Call corresponding function in TargetingProcess
    for _, filterName in ipairs(fstTemplate.target.filterNames) do
      local targetingFunction = TargetingProcess[filterName]

      if targetingFunction then
        local targets = targetingFunction(filterOpts)

        if targets and #targets > 0 then
          Utils.insertList(strikeTargets, targets)
          Logger.log("Filter " .. filterName .. " found " .. #targets .. " targets")
        end
      else
        Logger.error("Unknown target filtering function: " .. filterName)
      end
    end
  else
    -- For fixed target lists (e.g., airport facilities), use assessTargetsDamage
    Logger.log("Using fixed target list for BDA assessment")

    -- First filter targets that meet criteria
    local filteredTargets = {}

    if fstTemplate.target.objs then
      filteredTargets = TargetingProcess.selectTargetsByQueryParams({
        targetlist = saveData.c.targetlist,
        queryParams = fstTemplate.target.objs
      })
    end

    if filteredTargets and #filteredTargets > 0 then
      Logger.log("Filtered " .. #filteredTargets .. " candidate targets")

      -- Perform BDA assessment
      local task = { target = { list = filteredTargets, contactAge = fstTemplate.target.contactAge } }
      strikeTargets = TargetingProcess.assessTargetsDamage(task, isFirstWave)
    end
  end

  return strikeTargets or {}
end

---Collect all currently assigned battery GUIDs from active FSEMs
---@param saveData SBJ__SaveData
---@return table<string, boolean> assignedBatteries Map of battery GUID to assignment status
local function collectAssignedBatteries(saveData)
  local assignedBatteries = {}

  if not saveData.c.ground.FSP then
    return assignedBatteries
  end

  for _, FSEM in pairs(saveData.c.ground.FSP) do
    if not FSEM.isFinished and FSEM.isActivated and FSEM.FSTs then
      for _, FST in ipairs(FSEM.FSTs) do
        if not FST.isFinished and FST.batteries then
          for _, battery in ipairs(FST.batteries) do
            local batteryGuid = type(battery) == "table" and battery.guid or battery
            assignedBatteries[batteryGuid] = true
          end
        end
      end
    end
  end

  return assignedBatteries
end

---Validate individual battery status and readiness
---@param config SBJ__CONFIG
---@param saveData SBJ__SaveData
---@param batteryGuid string
---@param wpnSystem string
---@return boolean isValid Whether battery is ready for use
---@return string|nil reason Reason if battery is not valid
local function validateBatteryStatus(config, saveData, batteryGuid, wpnSystem)
  -- Check if unit exists in game
  local actualUnit = GameApi.ScenEdit_GetUnit(batteryGuid)
  if not actualUnit then
    return false, "Cannot find actual unit: " .. batteryGuid
  end

  -- Get battery data from weapon system
  local weaponSystemLower = string.lower(wpnSystem)
  local batteryData = saveData.c.ground[weaponSystemLower] and
      saveData.c.ground[weaponSystemLower].batteries and
      saveData.c.ground[weaponSystemLower].batteries[batteryGuid]

  if not batteryData then
    return false, "Cannot find battery data: " .. batteryGuid
  end

  -- Check operational status
  local isInGoodState = batteryData.state == config.batteryState.HIDE
  local hasAmmo = not Launcher.isLowAmmo(actualUnit, batteryData.ammoThreshold, batteryData.weaponDBID)

  if not isInGoodState or not hasAmmo then
    return false, "Battery in poor condition or low ammunition"
  end

  return true, nil
end

---Check if batteries specified in template are available
---@param config SBJ__CONFIG
---@param saveData SBJ__SaveData
---@param templateBatteries SBJ__Battery[]
---@param wpnSystem string
---@return SBJ__Battery[] availableBatteries
local function checkBatteryAvailability(config, saveData, templateBatteries, wpnSystem)
  local availableBatteries = {}
  local assignedBatteries = collectAssignedBatteries(saveData)

  -- Check each specified battery in template
  for _, templateBattery in ipairs(templateBatteries) do
    local batteryGuid = templateBattery.guid

    -- Check if already assigned to another FST
    if assignedBatteries[batteryGuid] then
      Logger.log("Battery " .. templateBattery.name .. " already assigned to other FST")
    else
      -- Validate battery status and readiness
      local isValid, reason = validateBatteryStatus(config, saveData, batteryGuid, wpnSystem)

      if isValid then
        table.insert(availableBatteries, templateBattery)
      else
        if reason:find("Cannot find") then
          Logger.error(reason)
        else
          Logger.log("Battery " .. templateBattery.name .. " - " .. reason)
        end
      end
    end
  end

  Logger.log("Check completed, available batteries: " .. #availableBatteries .. "/" .. #templateBatteries)
  return availableBatteries
end

---Insert new FSEM into existing FSP sequence
---@param saveData SBJ__SaveData
---@param newFSEM SBJ__FireSupportExecutionMatrix
---@return boolean success
local function insertFSEM(saveData, newFSEM)
  -- Add new FSEM to the end of FSP sequence
  saveData.c.ground.FSP[newFSEM.name] = newFSEM

  Logger.log("Successfully inserted dynamic FSEM: " .. newFSEM.name .. ", FST count: " .. #newFSEM.FSTs)
  return true
end

---Create actual FSEM from template and evaluation results
---@param config SBJ__CONFIG
---@param saveData SBJ__SaveData
---@param fsemTemplate SBJ__FsemTemplate
---@param evaluatedTargets table<string, CMO__Contact[]>
---@return boolean success
local function createFSEMFromTemplate(config, saveData, fsemTemplate, evaluatedTargets)
  -- Calculate FSEM execution time
  local currentTime = GameApi.ScenEdit_CurrentTime()
  local fsemStartTime = currentTime

  -- Create new FSEM structure
  local newFSEM = {
    name = fsemTemplate.name,
    isActivated = true,
    isFinished = false,
    isFirstWave = fsemTemplate.isFirstWave,
    allBatteriesInPosition = false,
    FSTs = {}
  }

  local fstIndex = 0

  -- Create actual FST for each valid target FST
  for _, fstTemplate in ipairs(fsemTemplate.FSTs) do
    local targets = evaluatedTargets[fstTemplate.name]

    if targets and #targets >= fstTemplate.target.minTargetCount then
      fstIndex = fstIndex + 1

      -- Check if batteries specified in template are available
      local availableBatteries = checkBatteryAvailability(
        config, saveData, fstTemplate.batteries, fstTemplate.wpnSystem
      )

      if availableBatteries and #availableBatteries > 0 then
        local fst = {
          name = fstTemplate.name,
          wpnSystem = fstTemplate.wpnSystem,
          batteries = availableBatteries,
          startTime = os.date("!%Y-%m-%d %H:%M:%S", fsemStartTime + (fstIndex * fsemTemplate.strikeInterval)),
          isFinished = false,
          target = {
            list = targets,
            objs = fstTemplate.target.objs or {},
            areas = fstTemplate.target.areas or {},
            filterNames = fstTemplate.target.filterNames,
            contactAge = fstTemplate.target.contactAge,
            minTargetCount = fstTemplate.target.minTargetCount,
            ammoPerTarget = fstTemplate.target.ammoPerTarget
          }
        }

        table.insert(newFSEM.FSTs, fst)
        Logger.log("Created FST: " .. fstTemplate.name .. ", target count: " ..
          #targets .. ", fire unit count: " .. #availableBatteries)
      else
        Logger.error("Specified fire units for FST " .. fstTemplate.name .. " are unavailable or already assigned")
      end
    end
  end

  -- If FSTs were successfully created, insert into FSP
  if #newFSEM.FSTs > 0 then
    return insertFSEM(saveData, newFSEM)
  else
    Logger.error("Unable to create valid FSEM")
    return false
  end
end

---Process reconnaissance schedule entry, get FSEM template and execute evaluation
---@param config SBJ__CONFIG
---@param saveData SBJ__SaveData
---@param contacts CMO__Contact[]
---@param reconEntry SBJ__ReconScheduleEntry
---@return boolean success
local function processReconSchedule(config, saveData, contacts, reconEntry)
  if not reconEntry.fsemTemplate or not reconEntry.fsemTemplate.FSTs then
    Logger.error("Reconnaissance schedule entry missing FSEM template")
    return false
  end

  -- Create actual FSEM from template
  local evaluatedTargets = {}
  local hasValidTargets = false

  -- Process FST templates one by one
  for _, fstTemplate in ipairs(reconEntry.fsemTemplate.FSTs) do
    local fstTargets = processFST(config, saveData, contacts, fstTemplate, reconEntry.fsemTemplate.isFirstWave)

    if fstTargets and #fstTargets >= fstTemplate.target.minTargetCount then
      evaluatedTargets[fstTemplate.name] = fstTargets
      hasValidTargets = true
      Logger.log("FST " .. fstTemplate.name .. " found " .. #fstTargets .. " targets")
    else
      Logger.log("FST " .. fstTemplate.name .. " insufficient targets (required: " ..
        fstTemplate.target.minTargetCount .. ", found: " ..
        (fstTargets and #fstTargets or 0) .. ")")
    end
  end

  -- If valid targets exist, create and insert FSEM
  if hasValidTargets then
    return createFSEMFromTemplate(
      config, saveData, reconEntry.fsemTemplate, evaluatedTargets
    )
  else
    Logger.log("Insufficient targets for follow-up strikes, skipping FSEM creation")
    return false
  end
end

-- Public functions (exported)

---Main execution function, process reconnaissance schedule and dynamically create FSEM
---@param config SBJ__CONFIG Configuration parameters
---@param saveData SBJ__SaveData Game state data
---@param contacts CMO__Contact[] Contact data passed from event script
---@return boolean success Whether execution was successful
function DynamicFireSupportPlan.execute(config, saveData, contacts)
  -- Check if dynamic FSP feature is enabled
  if not saveData.c.ground.dynamicFSP or not saveData.c.ground.dynamicFSP.enabled then
    return false
  end

  local currentTime = GameApi.ScenEdit_CurrentTime()
  local hasExecutedAny = false

  -- Process each entry in reconnaissance schedule
  for _, reconEntry in ipairs(saveData.c.ground.dynamicFSP.reconSchedule) do
    -- Check if already executed
    if not reconEntry.executed then
      local reconTime = Utils.parseDatetimeToTimestamp(reconEntry.time)
      local triggerTime = reconTime + reconEntry.delay

      -- Check if trigger time is reached (reconnaissance completed + delay)
      if currentTime >= triggerTime then
        Logger.log("Starting reconnaissance schedule processing: " ..
          reconEntry.time .. " (type: " .. reconEntry.type .. ")")

        -- Process this reconnaissance schedule entry
        local success = processReconSchedule(
          config, saveData, contacts, reconEntry
        )

        if success then
          -- Mark as executed to avoid repeated execution
          reconEntry.executed = true
          hasExecutedAny = true
          Logger.log("Successfully executed dynamic FSP, reconnaissance time: " .. reconEntry.time)
        else
          Logger.error("Failed to execute dynamic FSP, reconnaissance time: " .. reconEntry.time)
        end
      end
    end
  end

  return hasExecutedAny
end

return DynamicFireSupportPlan
