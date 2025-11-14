local TargetingProcess = require("src.modules.strikePlanner.targetingProcess")
local GameApi = require("src.utils.gameApi")
local Utils = require("src.utils.utils")
local Logger = require("src.utils.logger")
local Launcher = require("src.modules.launcher")
local DynamicOperationsUtils = require("src.modules.strikePlanner.dynamicOperationsUtils")

local DynamicFireSupportPlan = {}

-- Local helper functions (private)

---Process individual FST template, perform target filtering and BDA assessment
--- Routes to dynamic or fixed target processing, applies filters and damage assessment
---@param config SBJ__CONFIG Global configuration table
---@param saveData SBJ__SaveData Persistent save data containing target list
---@param contacts CMO__Contact[] Available sensor contacts from the game
---@param FSTTemplate SBJ__FSTTemplate Fire Support Task template with target criteria
---@param isFirstWave boolean Whether this is the first wave (affects BDA assessment)
---@return CMO__Contact[] # Array of strike targets that passed filtering and assessment
local function processFST(config, saveData, contacts, FSTTemplate, isFirstWave)
  -- Choose different assessment methods based on target type
  local strikeTargets = {}

  if FSTTemplate.target.filterNames then
    -- For targets requiring dynamic filtering (e.g., radar, air defense systems), use passed contacts
    Logger.log("dynamicOperations",
      "Using dynamic target filtering, filters: " .. table.concat(FSTTemplate.target.filterNames, ", "))
    local shouldTrack = FSTTemplate.target.filterNames[1] == "findNavalTargets" or
        FSTTemplate.target.filterNames[1] == "findRadioDirection"

    local filterOpts = {
      contacts = contacts,
      task = {
        target = {
          areas = FSTTemplate.target.areas,
          contactAge = FSTTemplate.target.contactAge
        }
      },
      config = config,
      saveData = saveData,
      shouldTrack = shouldTrack
    }

    -- Call corresponding function in TargetingProcess
    for _, filterName in ipairs(FSTTemplate.target.filterNames) do
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

    if FSTTemplate.target.objs then
      filteredTargets = TargetingProcess.filterTargetsByTypeAndBase(
        saveData.c.targetlist,
        FSTTemplate.target.objs
      )
    end

    if filteredTargets and #filteredTargets > 0 then
      Logger.log("dynamicOperations", "Filtered " .. #filteredTargets .. " candidate targets")

      -- Perform BDA assessment
      local task = { target = { list = filteredTargets, contactAge = FSTTemplate.target.contactAge } }
      strikeTargets = TargetingProcess.assessTargetsDamage(task, isFirstWave)
    end
  end

  return strikeTargets or {}
end

---Collect all currently assigned battery GUIDs from active FSEMs
--- Scans all active FSEMs to identify batteries already assigned to prevent double allocation
---@param saveData SBJ__SaveData Persistent save data containing FSP (Fire Support Plan) information
---@return table<string, boolean> # Map of battery GUID to true (assigned status)
local function collectAssignedFiringUnits(saveData)
  local assignedFiringUnits = {}

  if not saveData.c.ground.FSP then
    return assignedFiringUnits
  end

  for _, FSEM in pairs(saveData.c.ground.FSP) do
    if not FSEM.isFinished and FSEM.isActivated and FSEM.FSTs then
      for _, FST in ipairs(FSEM.FSTs) do
        if not FST.isFinished and FST.firingUnits then
          for _, firingUnit in ipairs(FST.firingUnits) do
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
--- Checks if firing unit exists, is in HIDE state, and has sufficient ammunition
---@param config SBJ__CONFIG Global configuration table with firing unit state definitions
---@param saveData SBJ__SaveData Persistent save data containing firing unit contexts
---@param firingUnitGUID string The GUID of the battery/firing unit to validate
---@param wpnSystem string Weapon system name (e.g., "SRBM", "LACM") used to locate battery data
---@return boolean # true if firing unit is ready for use (exists, in HIDE state, has ammo)
---@return string|nil # Error reason if firing unit is not valid, nil on success
local function validateFiringUnitStatus(config, saveData, firingUnitGUID, wpnSystem)
  -- Check if unit exists in game
  local actualUnit = GameApi.ScenEdit_GetUnit(firingUnitGUID)
  if not actualUnit then
    return false, "Cannot find actual unit: " .. firingUnitGUID
  end

  -- Get battery data from weapon system
  local weaponSystemLower = string.lower(wpnSystem)
  local firingUnitCtx = saveData.c.ground[weaponSystemLower] and
      saveData.c.ground[weaponSystemLower].firingUnits and
      saveData.c.ground[weaponSystemLower].firingUnits[firingUnitGUID]

  if not firingUnitCtx then
    return false, "Cannot find battery data: " .. firingUnitGUID
  end

  -- Check operational status
  local isInGoodState = firingUnitCtx.state == config.batteryState.HIDE
  local hasAmmo = not Launcher.isLowAmmo(actualUnit, firingUnitCtx.ammoThreshold, firingUnitCtx.weaponDBID)

  if not isInGoodState or not hasAmmo then
    return false, "Firing Unit in poor condition or low ammunition"
  end

  return true, nil
end

---Check if firing units specified in template are available
--- Filters battery list to only include unassigned batteries with valid status and ammunition
---@param config SBJ__CONFIG Global configuration table with battery state definitions
---@param saveData SBJ__SaveData Persistent save data containing FSP and firing unit information
---@param firingUnitCtxs SBJ__FiringUnitContext[] Array of battery contexts from FST template
---@param wpnSystem string Weapon system name (e.g., "SRBM", "LACM") for validation
---@return SBJ__FiringUnitContext[] # Array of available batteries ready for assignment
local function checkFiringUnitAvailability(config, saveData, firingUnitCtxs, wpnSystem)
  local availableFiringUnitCtxs = {}
  local assignedFiringUnitCtxs = collectAssignedFiringUnits(saveData)

  -- Check each specified battery in template
  for _, firingUnitCtx in ipairs(firingUnitCtxs) do
    local firingUnitGUID = firingUnitCtx.guid

    -- Check if already assigned to another FST
    if assignedFiringUnitCtxs[firingUnitGUID] then
      Logger.log("dynamicOperations", firingUnitCtx.name .. " already assigned to other FST")
    else
      -- Validate battery status and readiness
      local isValid, reason = validateFiringUnitStatus(config, saveData, firingUnitGUID, wpnSystem)

      if isValid then
        table.insert(availableFiringUnitCtxs, firingUnitCtx)
      else
        if reason:find("Cannot find") then
          Logger.error(reason)
        else
          Logger.log("dynamicOperations", "Battery " .. firingUnitCtx.name .. " - " .. reason)
        end
      end
    end
  end

  Logger.log("dynamicOperations",
    "Check completed, available firing units: " .. #availableFiringUnitCtxs .. "/" .. #firingUnitCtxs)
  return availableFiringUnitCtxs
end

---Insert new FSEM into existing FSP sequence
--- Adds FSEM to the Fire Support Plan and registers it as a generated operation
---@param saveData SBJ__SaveData Persistent save data with FSP structure
---@param newFSEM SBJ__FireSupportExecutionMatrix Complete FSEM with FSTs ready for execution
---@return boolean # true if FSEM was successfully inserted and registered
local function insertFSEM(saveData, newFSEM)
  -- Add new FSEM to the end of FSP sequence
  saveData.c.ground.FSP[newFSEM.name] = newFSEM

  -- Register the generated operation name
  DynamicOperationsUtils.registerGeneratedOperation("ground", newFSEM.name, saveData)

  Logger.log("dynamicOperations",
    "Successfully inserted dynamic FSEM: " .. newFSEM.name .. ", FST count: " .. #newFSEM.FSTs)
  return true
end

---Create actual FSEM from template and evaluation results
--- Constructs executable FSEM with FSTs, validates firing units, and inserts into FSP
---@param config SBJ__CONFIG Global configuration table
---@param saveData SBJ__SaveData Persistent save data for FSP insertion
---@param FSEMTemplate SBJ__FSEMTemplate Template defining FSEM structure and FST configurations
---@param evaluatedTargets table<string, CMO__Contact[]> Map of FST name to evaluated target arrays
---@param reconType string Reconnaissance type identifier used for FSEM naming
---@return boolean # true if FSEM was successfully created and inserted, false if no valid FSTs
local function createFSEMFromTemplate(config, saveData, FSEMTemplate, evaluatedTargets, reconType)
  -- Calculate FSEM execution time
  local currentTime = GameApi.ScenEdit_CurrentTime()
  local FSEMStartTime = currentTime

  -- Generate unique FSEM name based on template name
  local FSEMName = DynamicOperationsUtils.generateUniqueGroundOperationName(
    FSEMTemplate.name:match("([^/]+)") or FSEMTemplate.name, reconType, saveData
  )

  -- Create new FSEM structure
  ---@type SBJ__FireSupportExecutionMatrix
  local newFSEM = {
    name = FSEMName,
    isActivated = true,
    isFinished = false,
    isFirstWave = FSEMTemplate.isFirstWave,
    allFiringUnitsInPosition = false,
    FSTs = {}
  }

  local FSTIndex = 0

  -- Create actual FST for each valid target FST
  for _, FSTTemplate in ipairs(FSEMTemplate.FSTs) do
    local targets = evaluatedTargets[FSTTemplate.name]

    if targets and #targets >= FSTTemplate.target.minTargetCount then
      FSTIndex = FSTIndex + 1

      -- Check if firing units specified in template are available
      local availableFiringUnits = checkFiringUnitAvailability(
        config, saveData, FSTTemplate.firingUnits, FSTTemplate.wpnSystem
      )

      if availableFiringUnits and #availableFiringUnits > 0 then
        ---@type SBJ__FireSupportTask
        local FST = {
          name = FSTTemplate.name,
          wpnSystem = FSTTemplate.wpnSystem,
          firingUnits = availableFiringUnits,
          startTime = os.date("!%Y-%m-%d %H:%M:%S", FSEMStartTime + (FSTIndex * FSEMTemplate.strikeInterval)),
          isFinished = false,
          target = {
            list = targets,
            objs = FSTTemplate.target.objs or {},
            areas = FSTTemplate.target.areas or {},
            filterNames = FSTTemplate.target.filterNames,
            contactAge = FSTTemplate.target.contactAge,
            minTargetCount = FSTTemplate.target.minTargetCount,
            ammoPerTarget = FSTTemplate.target.ammoPerTarget
          }
        }

        table.insert(newFSEM.FSTs, FST)
        Logger.log("dynamicOperations", "Created FST: " .. FSTTemplate.name .. ", target count: " ..
          #targets .. ", fire unit count: " .. #availableFiringUnits)
      else
        Logger.error("Specified fire units for FST " .. FSTTemplate.name .. " are unavailable or already assigned")
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
--- Processes all FSTs in template, evaluates targets, and creates FSEM if valid targets exist
---@param config SBJ__CONFIG Global configuration table
---@param saveData SBJ__SaveData Persistent save data
---@param contacts CMO__Contact[] Available sensor contacts from the game
---@param reconEntry SBJ__ReconScheduleEntry Reconnaissance schedule entry triggering this operation
---@param operation SBJ__Operation Ground operation containing FSEM template
---@return boolean # true if FSEM was successfully created from reconnaissance results
local function processReconSchedule(config, saveData, contacts, reconEntry, operation)
  if not operation.template or not operation.template.FSTs then
    Logger.error("Ground operation missing FSEM template")
    return false
  end


  -- Create deep copy to avoid modifying original template
  local copyFSTs = Utils.deepCopy(operation.template.FSTs)

  -- Create actual FSEM from template
  local evaluatedTargets = {}
  local hasValidTargets = false

  -- Process FST templates one by one
  for _, FSTTemplate in ipairs(copyFSTs) do
    local FSTTargets = processFST(config, saveData, contacts, FSTTemplate, operation.template.isFirstWave)

    if FSTTargets and #FSTTargets >= FSTTemplate.target.minTargetCount then
      evaluatedTargets[FSTTemplate.name] = FSTTargets
      hasValidTargets = true
      Logger.log("dynamicOperations", "FST " .. FSTTemplate.name .. " found " .. #FSTTargets .. " targets")
    else
      Logger.log("dynamicOperations", "FST " .. FSTTemplate.name .. " insufficient targets (required: " ..
        FSTTemplate.target.minTargetCount .. ", found: " ..
        (FSTTargets and #FSTTargets or 0) .. ")")
    end
  end

  -- If valid targets exist, create and insert FSEM
  if hasValidTargets then
    -- Create a copy of fsemTemplate with the copied FSTs
    ---@type SBJ__FSEMTemplate
    local modifiedTemplate = Utils.deepCopy(operation.template)
    modifiedTemplate.FSTs = copyFSTs

    return createFSEMFromTemplate(
      config, saveData, modifiedTemplate, evaluatedTargets, reconEntry.type
    )
  else
    Logger.log("dynamicOperations", "Insufficient targets for follow-up strikes, skipping FSEM creation")
    return false
  end
end

-- Public functions (exported)

---Main execution function, process reconnaissance schedule and dynamically create FSEM
--- Entry point for dynamic Fire Support Plan system, validates configuration and processes ground operations
---@param config SBJ__CONFIG Global configuration with battery and weapon system parameters
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
      local success = processReconSchedule(
        config, saveData, contacts, reconEntry, operation
      )

      if success then
        DynamicOperationsUtils.markOperationExecuted(reconEntry, operation, true)
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
