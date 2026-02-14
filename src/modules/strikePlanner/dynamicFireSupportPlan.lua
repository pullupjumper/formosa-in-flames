local TargetingProcess = require("src.modules.strikePlanner.targetingProcess")
local GameApi = require("src.utils.gameApi")
local Utils = require("src.utils.utils")
local Logger = require("src.utils.logger")
local MissileSystem = require("src.modules.missileSystem")
local DynamicOperationsUtils = require("src.modules.strikePlanner.dynamicOperationsUtils")
local constants = require("src.core.constants")

local DynamicFireSupportPlan = {}

---Process individual FST template, perform target filtering and BDA assessment
---Routes to dynamic or fixed target processing, applies filters and damage assessment
---@param config SBJ__Config Global configuration table
---@param saveData SBJ__SaveData Persistent save data containing target list
---@param contacts CMO__Contact[] Available sensor contacts from the game
---@param taskTemplate SBJ__FireSupportTaskTemplate Fire Support Task template with target criteria
---@param isFirstWave boolean Whether this is the first wave (affects BDA assessment)
---@return string[] # Array of target GUIDs that passed filtering and assessment
local function processFireSupportTask(config, saveData, contacts, taskTemplate, isFirstWave)
  -- Choose different assessment methods based on target type
  local strikeTargets = {}

  if taskTemplate.target.filterNames then
    -- For targets requiring dynamic filtering (e.g., radar, air defense systems), use passed contacts
    Logger.log("dynamicOperations",
      "Using dynamic target filtering, filters: " .. table.concat(taskTemplate.target.filterNames, ", "))
    local shouldTrack = taskTemplate.target.filterNames[1] == "findNavalTargets" or
        taskTemplate.target.filterNames[1] == "findRadioDirection"

    local filterOpts = {
      contacts = contacts,
      task = {
        target = {
          areas = taskTemplate.target.areas,
          contactAge = taskTemplate.target.contactAge
        }
      },
      config = config,
      saveData = saveData,
      shouldTrack = shouldTrack
    }

    -- Call corresponding function in TargetingProcess
    for _, filterName in ipairs(taskTemplate.target.filterNames) do
      ---@type fun(opts: SBJ__FilterParams): string[]|nil
      local targetingFunction = TargetingProcess[filterName]

      if targetingFunction then
        local targets = targetingFunction(filterOpts)

        if targets and #targets > 0 then
          Utils.insertList(strikeTargets, targets)
          Logger.log("dynamicOperations", "Filter " .. filterName .. " found " .. #targets .. " targets")
        end
      else
        Logger.error("Unknown target filtering function: " .. filterName)
      end
    end
  else
    -- For fixed target lists (e.g., airport facilities), use assessTargetsDamage
    Logger.log("dynamicOperations", "Using fixed target list for BDA assessment")

    -- First filter targets that meet criteria
    local filteredTargets = {}

    if taskTemplate.target.objs then
      filteredTargets = TargetingProcess.filterTargetsByTypeAndBase(
        saveData.c.targetlist,
        taskTemplate.target.objs
      )
    end

    if filteredTargets and #filteredTargets > 0 then
      Logger.log("dynamicOperations", "Filtered " .. #filteredTargets .. " candidate targets")

      -- Perform BDA assessment
      ---@type SBJ__Task
      local task = { target = { list = filteredTargets, contactAge = taskTemplate.target.contactAge } }
      strikeTargets = TargetingProcess.assessTargetsDamage(task, isFirstWave)
    end
  end

  return strikeTargets or {}
end

---Collect all currently assigned battery GUIDs from active FSEMs
---Scans all active FSEMs to identify batteries already assigned to prevent double allocation
---@param saveData SBJ__SaveData Persistent save data containing FSP (Fire Support Plan) information
---@return table<string, boolean> # Map of battery GUID to true (assigned status)
local function collectAssignedFiringUnits(saveData)
  local assignedFiringUnits = {}

  if not saveData.c.ground.fireSupportPlan then
    return assignedFiringUnits
  end

  for _, matrix in pairs(saveData.c.ground.fireSupportPlan) do
    if not matrix.isFinished and matrix.isActivated and matrix.fireSupportTasks then
      for _, task in ipairs(matrix.fireSupportTasks) do
        if not task.isFinished and task.firingUnits then
          for _, firingUnit in ipairs(task.firingUnits) do
            local firingUnitGUID = type(firingUnit) == "table" and firingUnit.guid or firingUnit
            assignedFiringUnits[firingUnitGUID] = true
          end
        end
      end
    end
  end

  return assignedFiringUnits
end

---Validate individual firing unit status and readiness
---Checks if firing unit exists, is in HIDE state, and has sufficient ammunition
---@param saveData SBJ__SaveData Persistent save data containing firing unit contexts
---@param firingUnitName string The name of the battery/firing unit to validate
---@param missileSystem string Missile system name (e.g., "SRBM", "LACM") used to locate battery data
---@return boolean success true if firing unit is ready for use (exists, in HIDE state, has ammo)
---@return string|nil errorReason Error reason if firing unit is not valid, nil on success
local function validateFiringUnitStatus(saveData, firingUnitName, missileSystem)
  -- Check if unit exists in game
  local actualUnit = GameApi.ScenEdit_GetUnit(firingUnitName)
  if not actualUnit then
    return false, "Cannot find actual unit: " .. firingUnitName
  end

  -- Get battery data from weapon system
  local missileSystemLower = string.lower(missileSystem)
  local firingUnitCtx = saveData.c.ground[missileSystemLower] and
      saveData.c.ground[missileSystemLower].firingUnits and
      saveData.c.ground[missileSystemLower].firingUnits[firingUnitName]

  if not firingUnitCtx then
    return false, "Cannot find battery data: " .. firingUnitName
  end

  -- Check operational status
  local isInGoodState = firingUnitCtx.state == constants.MISSILE_SYSTEM_STATE.HIDE
  local hasAmmo = not MissileSystem.isLowAmmo(actualUnit, firingUnitCtx.ammoThreshold, firingUnitCtx.weaponDBID)

  if not isInGoodState or not hasAmmo then
    return false, "Firing Unit in poor condition or low ammunition"
  end

  return true, nil
end

---Check if firing units specified in template are available
---Filters battery list to only include unassigned batteries with valid status and ammunition
---@param saveData SBJ__SaveData Persistent save data containing FSP and firing unit information
---@param firingUnits SBJ__FiringUnit[] Array of firing unit contexts specified in FST template
---@param missileSystem string Missile system name (e.g., "SRBM", "LACM") for validation
---@return SBJ__FiringUnitContext[] # Array of available batteries ready for assignment
local function checkFiringUnitAvailability(saveData, firingUnits, missileSystem)
  local availableFiringUnitCtxs = {}
  local assignedFiringUnitCtxs = collectAssignedFiringUnits(saveData)

  -- Check each specified battery in template
  for _, firingUnit in ipairs(firingUnits) do
    -- Check if already assigned to another FST
    if assignedFiringUnitCtxs[firingUnit.name] then
      Logger.log("dynamicOperations", firingUnit.name .. " already assigned to other FST")
    else
      -- Validate battery status and readiness
      local isValid, reason = validateFiringUnitStatus(saveData, firingUnit.name, missileSystem)

      if isValid then
        table.insert(availableFiringUnitCtxs, firingUnit)
      else
        if reason and reason:find("Cannot find") then
          Logger.error(reason)
        else
          Logger.log("dynamicOperations", "Battery " .. firingUnit.name .. " - " .. reason)
        end
      end
    end
  end

  Logger.log("dynamicOperations",
    "Check completed, available firing units: " .. #availableFiringUnitCtxs .. "/" .. #firingUnits)
  return availableFiringUnitCtxs
end

---Insert new FSEM into existing FSP sequence
---Adds FSEM to the Fire Support Plan and registers it as a generated operation
---@param saveData SBJ__SaveData Persistent save data with FSP structure
---@param newMatrix SBJ__FireSupportExecutionMatrix Complete FSEM with FSTs ready for execution
---@return boolean # true if FSEM was successfully inserted and registered
local function insertMatrix(saveData, newMatrix)
  -- Add new FSEM to the end of FSP sequence
  saveData.c.ground.fireSupportPlan[newMatrix.name] = newMatrix

  -- Register the generated operation name
  DynamicOperationsUtils.registerGeneratedOperation("ground", newMatrix.name, saveData)

  Logger.log("dynamicOperations",
    "Successfully inserted dynamic FSEM: " .. newMatrix.name .. ", FST count: " .. #newMatrix.fireSupportTasks)
  return true
end

---Create actual FSEM from template and evaluation results
---Constructs executable FSEM with FSTs, validates firing units, and inserts into FSP
---@param saveData SBJ__SaveData Persistent save data for FSP insertion
---@param matrixTemplate SBJ__FireSupportExecutionMatrixTemplate Template defining FSEM structure and FST configurations
---@param evaluatedTargets table<string, CMO__Contact[]> Map of FST name to evaluated target arrays
---@param reconType string Reconnaissance type identifier used for FSEM naming
---@return boolean # true if FSEM was successfully created and inserted, false if no valid FSTs
local function createFSEMFromTemplate(saveData, matrixTemplate, evaluatedTargets, reconType)
  -- Calculate FSEM execution time
  local currentTime = GameApi.ScenEdit_CurrentTime()
  local matrixStartTime = currentTime

  -- Generate unique FSEM name based on template name
  local matrixName = DynamicOperationsUtils.generateUniqueGroundOperationName(
    matrixTemplate.name:match("([^/]+)") or matrixTemplate.name, reconType, saveData
  )

  -- Create new FSEM structure
  ---@type SBJ__FireSupportExecutionMatrix
  local newMatrix = {
    name = matrixName,
    isActivated = true,
    isFinished = false,
    isFirstWave = matrixTemplate.isFirstWave,
    allFiringUnitsInPosition = false,
    fireSupportTasks = {},
    strikeInterval = 0
  }

  local taskIndex = 0

  -- Create actual FST for each valid target FST
  for _, taskTemplate in ipairs(matrixTemplate.fireSupportTasks) do
    local targets = evaluatedTargets[taskTemplate.name]

    if targets and #targets >= taskTemplate.target.minTargetCount then
      taskIndex = taskIndex + 1

      -- Check if firing units specified in template are available
      local availableFiringUnits = checkFiringUnitAvailability(
        saveData, taskTemplate.firingUnits, taskTemplate.missileSystem
      )

      if availableFiringUnits and #availableFiringUnits > 0 then
        local startTime = os.date("!%Y-%m-%d %H:%M:%S", matrixStartTime + (taskIndex * matrixTemplate.strikeInterval)) --[[@as string]]
        ---@type SBJ__FireSupportTask
        local task = {
          name = taskTemplate.name,
          missileSystem = taskTemplate.missileSystem,
          firingUnits = availableFiringUnits,
          startTime = startTime,
          isFinished = false,
          target = {
            list = targets,
            objs = taskTemplate.target.objs or {},
            areas = taskTemplate.target.areas or {},
            filterNames = taskTemplate.target.filterNames,
            contactAge = taskTemplate.target.contactAge,
            minTargetCount = taskTemplate.target.minTargetCount,
            ammoPerTarget = taskTemplate.target.ammoPerTarget
          }
        }

        table.insert(newMatrix.fireSupportTasks, task)
        Logger.log("dynamicOperations", "Created FST: " .. taskTemplate.name .. ", target count: " ..
          #targets .. ", fire unit count: " .. #availableFiringUnits)
      else
        Logger.error("Specified fire units for FST " .. taskTemplate.name .. " are unavailable or already assigned")
      end
    end
  end

  -- If FSTs were successfully created, insert into FSP
  if #newMatrix.fireSupportTasks > 0 then
    return insertMatrix(saveData, newMatrix)
  else
    Logger.error("Unable to create valid FSEM")
    return false
  end
end

---Process reconnaissance schedule entry, get FSEM template and execute evaluation
---Processes all FSTs in template, evaluates targets, and creates FSEM if valid targets exist
---@param config SBJ__Config Global configuration table
---@param saveData SBJ__SaveData Persistent save data
---@param contacts CMO__Contact[] Available sensor contacts from the game
---@param reconEntry SBJ__ReconScheduleEntry Reconnaissance schedule entry triggering this operation
---@param operation SBJ__Operation Ground operation containing FSEM template
---@return boolean # true if FSEM was successfully created from reconnaissance results
local function processReconSchedule(config, saveData, contacts, reconEntry, operation)
  if not operation.template or not operation.template.fireSupportTasks then
    Logger.error("Ground operation missing FSEM template")
    return false
  end

  -- Create deep copy to avoid modifying original template
  local copyTasks = Utils.deepCopy(operation.template.fireSupportTasks)

  -- Create actual FSEM from template
  local evaluatedTargets = {}
  local hasValidTargets = false

  -- Process FST templates one by one
  for _, taskTemplate in ipairs(copyTasks) do
    local taskTargets = processFireSupportTask(config, saveData, contacts, taskTemplate, operation.template.isFirstWave)

    if taskTargets and #taskTargets >= taskTemplate.target.minTargetCount then
      evaluatedTargets[taskTemplate.name] = taskTargets
      hasValidTargets = true
      Logger.log("dynamicOperations", "FST " .. taskTemplate.name .. " found " .. #taskTargets .. " targets")
    else
      Logger.log("dynamicOperations", "FST " .. taskTemplate.name .. " insufficient targets (required: " ..
        taskTemplate.target.minTargetCount .. ", found: " ..
        (taskTargets and #taskTargets or 0) .. ")")
    end
  end

  -- If valid targets exist, create and insert FSEM
  if hasValidTargets then
    -- Create a copy of fsemTemplate with the copied FSTs
    local modifiedTemplate = Utils.deepCopy(operation.template)
    modifiedTemplate.fireSupportTasks = copyTasks

    return createFSEMFromTemplate(
      saveData, modifiedTemplate, evaluatedTargets, reconEntry.type
    )
  else
    Logger.log("dynamicOperations", "Insufficient targets for follow-up strikes, skipping FSEM creation")
    return false
  end
end

---Main execution function, process reconnaissance schedule and dynamically create FSEM
---Entry point for dynamic Fire Support Plan system, validates configuration and processes ground operations
---@param config SBJ__Config Global configuration with battery and weapon system parameters
---@param saveData SBJ__SaveData Persistent save data with dynamic operations and FSP structure
---@param contacts CMO__Contact[] Sensor contacts from event script for target filtering
---@return boolean # true if any ground operation was processed and executed, false if disabled or none ready
function DynamicFireSupportPlan.execute(config, saveData, contacts)
  -- Check if dynamic operations feature is enabled
  if not saveData.c.dynamicOperations or not saveData.c.dynamicOperations.enabled then
    return false
  end

  local currentTime = GameApi.ScenEdit_CurrentTime()
  local hasExecutedAny = false

  -- Filter ground operations that need processing
  local groundOperations = DynamicOperationsUtils.filterOperationsByType(
    saveData.c.dynamicOperations.reconSchedule, "ground"
  )

  if #groundOperations == 0 then
    return false
  end

  -- Process each ground operation
  for _, item in ipairs(groundOperations) do
    local reconEntry = item.reconEntry
    local operation = item.operation

    local reconTime = Utils.parseDatetimeToTimestamp(reconEntry.time)
    local triggerTime = reconTime + reconEntry.delay

    -- Check if trigger time is reached (reconnaissance completed + delay)
    if currentTime >= triggerTime then
      Logger.log("dynamicOperations", "Starting ground reconnaissance schedule processing: " ..
        reconEntry.time .. " (type: " .. reconEntry.type .. ")")

      -- Process this reconnaissance schedule entry
      local success = processReconSchedule(config, saveData, contacts, reconEntry, operation)
      DynamicOperationsUtils.markOperationExecuted(reconEntry, operation, true)

      if success then
        hasExecutedAny = true
        Logger.log("dynamicOperations", "Successfully executed dynamic FSP, reconnaissance time: " .. reconEntry.time)
      else
        Logger.error("Failed to execute dynamic FSP, reconnaissance time: " .. reconEntry.time)
      end
    end
  end

  return hasExecutedAny
end

return DynamicFireSupportPlan
