local GameUtils = require("src.utils.gameUtils")
local GameApi = require("src.utils.gameApi")
local Utils = require("src.utils.utils")
local Logger = require("src.utils.logger")
local DynamicOperationsUtils = require("src.modules.strikePlanner.dynamicOperationsUtils")
local constants = require("src.core.constants")

local Recon = {}

---Launch units from a base with specified parameters
---@param baseGUID string The base GUID to launch units from
---@param course CMO__TableOfWaypoints The course waypoints for launched units
---@param unitCount number The number of units to launch
---@param unitDBID number The unit database ID to filter by
---@param unitType string The unit type to launch (e.g., 'Aircraft' or 'Boats')
---@return string[]|nil # Returns array of launched unit GUIDs, or nil if no units launched
function Recon.launchUnits(baseGUID, course, unitCount, unitDBID, unitType)
  local base = GameApi.ScenEdit_GetUnit(baseGUID)

  if not base then
    base = GameApi.ScenEdit_GetUnit(baseGUID, 'China')
  end

  if not base then
    return
  end

  local count = 0
  local temp = {}
  if #base.embarkedUnits[unitType] == 0 then
    return
  end

  for _, guid in ipairs(base.embarkedUnits[unitType]) do
    local actualUnit = GameApi.ScenEdit_GetUnit(guid)

    if actualUnit and actualUnit.dbid == unitDBID and actualUnit.readytime_v == 0 and count < unitCount then
      GameApi.ScenEdit_SetDoctrine({ guid = actualUnit.guid, }, { automatic_evasion = false })
      actualUnit:Launch(true)
      actualUnit.course = course
      count = count + 1
      table.insert(temp, actualUnit.guid)
    end

    if count >= unitCount then
      break
    end
  end

  return temp
end

---Launch WZ-8 reconnaissance drone from H-6N bomber
---@param h6n CMO__Unit The H-6N bomber unit to launch from
---@param course CMO__TableOfWaypoints The reconnaissance course for WZ-8
---@return CMO__Unit|nil # Returns the WZ-8 unit if successfully launched, nil otherwise
function Recon.launchWZ8(h6n, course)
  local wz8 = GameApi.ScenEdit_AddUnit({
    side = 'China',
    type = 'Aircraft',
    name = 'WZ-8',
    dbid = constants.PLATFORMS.WZ8,
    latitude = h6n.latitude,
    longitude = h6n.longitude,
    loadoutid = 32885,
    altitude = 20574,
    heading = 180,
    speed = 3300
  })

  if not wz8 then
    return
  end

  local arcT = { 'PB1', 'PB2', 'SB1', 'SB2', 'SMF1', 'PMF2' }
  local updatedUnit = GameApi.ScenEdit_UpdateUnit({
    guid = wz8.guid,
    mode = 'add_sensor',
    dbid = 4576,
    arc_detect = arcT,
    arc_track = arcT
  })

  if not updatedUnit then
    return
  end

  local result = GameApi.ScenEdit_SetEMCON("Unit", wz8.guid, "Radar=Active")

  if not result then
    return
  end

  wz8.course = course
  h6n:RTB(true)
  return wz8
end

---Handle reconnaissance launch phase
---@param entry SBJ__ReconQueueEntry Queue entry to process
---@return boolean # Whether unit was successfully launched
local function handleReconLaunch(entry)
  if entry.hasLaunched or not GameUtils.isAfterStartTime(entry.takeoffTime) then
    return false
  end

  local units = Recon.launchUnits(entry.baseGUID, entry.course, entry.unitCount, entry.unitDBID, 'Aircraft')

  if units and #units > 0 then
    entry.unitGUID = units[1]
    entry.hasLaunched = true
    Logger.log("recon", string.format("Launched recon unit %s from base %s", units[1], entry.baseGUID))
    return true
  else
    Logger.log("recon", string.format("Failed to launch recon unit from base %s", entry.baseGUID))
    return false
  end
end

---Handle reconnaissance tracking mode - continuously update course to track moving target
---@param entry SBJ__ReconQueueEntry Queue entry
---@param actualUnit CMO__Unit The reconnaissance unit
---@return boolean # Whether tracking was successfully updated
local function handleReconTracking(entry, actualUnit)
  -- Check if tracking target is assigned
  if not entry.trackingTargetGUID then
    Logger.log("recon", string.format("No tracking assignment found for unit: %s", actualUnit.guid))
    return false
  end

  -- Validate entry has speed configured
  if not entry.speed then
    Logger.log("recon", string.format("No speed configured for unit: %s", actualUnit.guid))
    return false
  end

  local target = GameApi.ScenEdit_GetContact('China', entry.trackingTargetGUID)

  if not target then
    Logger.log("recon", string.format("Tracking target lost: %s", entry.trackingTargetGUID))
    return false
  end

  -- Update course to target position (continuous tracking for missile guidance)
  actualUnit.course = { {
    latitude = target.latitude,
    longitude = target.longitude,
    desiredSpeed = entry.speed,
    presetThrottle = 'Military'
  } }

  return true
end

---Handle reconnaissance return to base
---@param actualUnit CMO__Unit The reconnaissance unit
local function handleReconRTB(actualUnit)
  actualUnit:RTB(true)
  Logger.log("recon", string.format("Unit %s returning to base", actualUnit.name))
end

---Get platform-specific operations for BZK-005 (C2 strike) and WZ-8 (anti-ship/airbase strike)
---Each UAV platform triggers different specialized operations based on successful reconnaissance
---@param config SBJ__Config Configuration data
---@param reconSchedule SBJ__ReconScheduleEntry[] Reconnaissance schedule
---@param entry SBJ__ReconQueueEntry Queue entry with completed reconnaissance data
---@param LACMContext SBJ__LACMContext LACM context data
---@return SBJ__Operation[] # Array of special operations to add
local function getPlatformSpecialOperations(config, reconSchedule, entry, LACMContext)
  local operations = {}

  -- Each entry has only one unitDBID, check which platform it is
  if entry.unitDBID == constants.PLATFORMS.BZK005 then
    -- BZK-005 reconnaissance: Schedule C2 (Command & Control) strike operations
    if not DynamicOperationsUtils.hasOperation(reconSchedule, "C2/1", "ground") then
      table.insert(operations, {
        type = "ground",
        executed = false,
        template = {
          name = "C2/1",
          strikeInterval = 0,
          isFirstWave = false,
          FSTs = config.c.FSTTemplate.STRIKE_C2_1
        }
      })

      return operations
    end

    local existing, operation = DynamicOperationsUtils.hasOperation(reconSchedule, "C2/", "ground")
    if existing and operation then
      local nextOperation = DynamicOperationsUtils.generateNextOperation(operation, config)
      table.insert(operations, nextOperation)
    end
  elseif entry.unitDBID == constants.PLATFORMS.GJ11 then
    -- GJ-11 reconnaissance: Schedule CAS operations
    if not DynamicOperationsUtils.hasOperation(reconSchedule, "CAS/N/1", "air") then
      table.insert(operations, {
        type = "air",
        executed = false,
        template = {
          name = "CAS/N/1",
          strikeInterval = 0,
          isFirstWave = false,
          packages = config.c.packageTemplate.CAS_N_1
        }
      })

      return operations
    end

    local existing, operation = DynamicOperationsUtils.hasOperation(reconSchedule, "CAS/N/", "air")
    if existing and operation then
      local nextOperation = DynamicOperationsUtils.generateNextOperation(operation, config)
      table.insert(operations, nextOperation)
    end
  elseif entry.unitDBID == constants.PLATFORMS.H6N then
    -- WZ-8 reconnaissance (launched from H-6N): Schedule anti-ship strike operations
    if not DynamicOperationsUtils.hasOperation(reconSchedule, "ANTISHIP/1", "ground") then
      table.insert(operations, {
        type = "ground",
        executed = false,
        template = {
          name = "ANTISHIP/1",
          strikeInterval = 0,
          isFirstWave = false,
          FSTs = config.c.FSTTemplate.ANTISHIP_1
        }
      })

      return operations
    end

    if not DynamicOperationsUtils.hasOperation(reconSchedule, "ASUW/N/1 ", "air") then
      table.insert(operations, {
        type = "air",
        executed = false,
        template = {
          name = "ASUW/N/1",
          strikeInterval = 0,
          isFirstWave = false,
          packages = config.c.packageTemplate.ASUW_N_1
        }
      })

      return operations
    end

    -- If LACM operations activated: Schedule airbase strike operations
    if LACMContext.isActivated and not DynamicOperationsUtils.hasOperation(reconSchedule, "STRIKE/AB/E/1", "air") then
      table.insert(operations, {
        type = "air",
        executed = false,
        template = {
          name = "STRIKE/AB/E/1",
          strikeInterval = 0,
          isFirstWave = false,
          packages = config.c.packageTemplate.STRIKE_AB_E_1
        }
      })

      return operations
    end

    local existing, operation = DynamicOperationsUtils.hasOperation(reconSchedule, "STRIKE/AB/W/", "air")
    if existing and operation then
      local nextOperation = DynamicOperationsUtils.generateNextOperation(operation, config)
      table.insert(operations, nextOperation)
    end

    local strikeInfrastructureOpExisting, strikeInfrastructureOp = DynamicOperationsUtils.hasOperation(
      reconSchedule, "STRIKE/INFRASTRUCTURE/", "ground"
    )
    if strikeInfrastructureOpExisting and strikeInfrastructureOp then
      local nextOperation = DynamicOperationsUtils.generateNextOperation(strikeInfrastructureOp, config)
      table.insert(operations, nextOperation)
    end

    local strikeHelipadOpExisting, strikeHelipadOp = DynamicOperationsUtils.hasOperation(
      reconSchedule, "STRIKE/HELIPAD/", "ground"
    )
    if strikeHelipadOpExisting and strikeHelipadOp then
      local nextOperation = DynamicOperationsUtils.generateNextOperation(strikeHelipadOp, config)
      table.insert(operations, nextOperation)
    end

    local asuWOpExisting, asuWOp = DynamicOperationsUtils.hasOperation(reconSchedule, "ASUW/N/", "air")
    if asuWOpExisting and asuWOp then
      local nextOperation = DynamicOperationsUtils.generateNextOperation(asuWOp, config)
      table.insert(operations, nextOperation)
    end

    local antiShipOpExisting, antiShipOp = DynamicOperationsUtils.hasOperation(reconSchedule, "ANTISHIP/", "ground")
    if antiShipOpExisting and antiShipOp then
      local nextOperation = DynamicOperationsUtils.generateNextOperation(antiShipOp, config)
      table.insert(operations, nextOperation)
    end

    local strikeEastExisting, strikeEastOp = DynamicOperationsUtils.hasOperation(reconSchedule, "STRIKE/AB/E/", "air")
    if LACMContext.isActivated and strikeEastExisting and strikeEastOp then
      local nextOperation = DynamicOperationsUtils.generateNextOperation(strikeEastOp, config)
      table.insert(operations, nextOperation)
    end
  end

  return operations
end

---Schedule dynamic operations for next wave based on completed reconnaissance and platform-specific operations
---Only called when UAV completes successfully (reached endTime with complete intelligence)
---@param config SBJ__Config Configuration data
---@param reconSchedule SBJ__ReconScheduleEntry[] Reconnaissance schedule
---@param entry SBJ__ReconQueueEntry Queue entry with completed reconnaissance data
---@param LACMContext SBJ__LACMContext LACM context data
local function scheduleDynamicReconOperations(config, reconSchedule, entry, LACMContext)
  local result = DynamicOperationsUtils.getLastExecutedOperationsAndNextTime(reconSchedule)

  -- Check if there are operations to schedule and next recon time exists
  if not result.nextReconTime or (#result.air == 0 and #result.ground == 0) then
    return
  end

  local nextReconTime = Utils.parseDatetimeToTimestamp(result.nextReconTime)
  local endTime = Utils.parseDatetimeToTimestamp(entry.endTime)

  -- Only schedule if current recon completed before next scheduled recon
  -- This ensures next wave operations are inserted in the correct time slot
  if endTime >= nextReconTime then
    return
  end

  -- Generate next wave operations
  local operations = {}

  -- for _, operation in ipairs(result.air) do
  --   local newOperation = DynamicOperationsUtils.generateNextOperation(operation, config)
  --   table.insert(operations, newOperation)
  -- end

  -- for _, operation in ipairs(result.ground) do
  --   local newOperation = DynamicOperationsUtils.generateNextOperation(operation, config)
  --   table.insert(operations, newOperation)
  -- end

  -- Add platform-specific operations
  local specialOps = getPlatformSpecialOperations(config, reconSchedule, entry, LACMContext)
  for _, op in ipairs(specialOps) do
    table.insert(operations, op)
  end

  -- Add to reconnaissance schedule if there are operations
  if #operations > 0 then
    table.insert(reconSchedule, {
      time = entry.endTime,
      type = "UAV",
      delay = 0,
      executed = false,
      operations = operations
    })

    Logger.log("recon", string.format("Scheduled %d dynamic operations for recon at %s", #operations, entry.endTime))
  end
end

---Finish reconnaissance mission and conditionally schedule next operations
---Only schedules next wave operations if mission completed successfully (reached endTime with valid intelligence)
---@param config SBJ__Config Configuration data
---@param reconSchedule SBJ__ReconScheduleEntry[] Reconnaissance schedule
---@param entry SBJ__ReconQueueEntry Queue entry
---@param LACMContext SBJ__LACMContext LACM context data
---@param success boolean Mission success status:
---  - true: UAV completed full reconnaissance duration (reached endTime), schedule next operations
---  - false: Mission failed (UAV destroyed before endTime), skip scheduling due to incomplete intelligence
local function finishReconMission(config, reconSchedule, entry, LACMContext, success)
  -- Prevent double execution
  if entry.isFinished then
    return
  end

  entry.isFinished = true

  if success then
    -- Mission successful: UAV survived until endTime and completed reconnaissance duration
    -- Intelligence data is complete and reliable, safe to schedule next wave operations
    scheduleDynamicReconOperations(config, reconSchedule, entry, LACMContext)
    Logger.log("recon", string.format("Recon mission completed successfully, scheduling next operations"))
  else
    -- Mission failed: UAV destroyed or lost before completing reconnaissance duration
    -- Intelligence data is incomplete, do not schedule operations based on insufficient data
    Logger.log("recon", string.format("Recon mission failed, skipping next wave scheduling"))
  end
end

---Process reconnaissance queue managing UAV launch, flight monitoring, and mission completion
---Success requires UAV to complete course and reach endTime; failure if destroyed before endTime
---@param config SBJ__Config Configuration data for platform DBIDs
---@param reconContext SBJ__ReconContext Reconnaissance context containing queue and temp tracking data
---@param reconSchedule SBJ__ReconScheduleEntry[] Reconnaissance schedule containing assigned missions
---@param LACMContext SBJ__LACMContext LACM context data
function Recon.handleReconQueue(config, reconContext, reconSchedule, LACMContext)
  -- Input validation
  if not reconContext or not reconContext.queue then
    return
  end

  for _, entry in ipairs(reconContext.queue) do
    -- Phase 1: Launch reconnaissance units when time comes
    if not entry.hasLaunched then
      handleReconLaunch(entry)
      goto continue
    end

    -- Phase 2: In-flight management (monitor UAV status, verify endTime, handle mission completion)
    if entry.hasLaunched and not entry.isFinished then
      local actualUnit = GameApi.ScenEdit_GetUnit(entry.unitGUID)
      local isEndTimeReached = GameUtils.isAfterStartTime(entry.endTime)

      -- Check if UAV was destroyed
      if not actualUnit then
        Logger.log("recon", string.format("Recon unit destroyed or missing: %s", tostring(entry.unitGUID)))
        -- Mission success depends on whether endTime was reached (intelligence collection completed)
        finishReconMission(config, reconSchedule, entry, LACMContext, isEndTimeReached)
        goto continue
      end

      -- UAV exists: check if still flying course
      if #actualUnit.course > 0 then
        goto continue
      end

      -- Course completed: check if endTime reached
      if not isEndTimeReached then
        -- Course complete but endTime not reached: loiter and wait for full reconnaissance duration
        Logger.log("recon", string.format("UAV %s completed course but waiting for endTime: %s",
          actualUnit.name, entry.endTime))
        goto continue
      end

      -- Both course and endTime completed: process mission completion
      if entry.isTracking and entry.trackingTargetGUID then
        -- Tracking mode: continue tracking target
        local success = handleReconTracking(entry, actualUnit)
        if not success then
          Logger.log("recon", string.format("Tracking failed for unit %s, but recon completed", actualUnit.name))
          finishReconMission(config, reconSchedule, entry, LACMContext, true)
        end
      else
        -- Normal reconnaissance: mission complete
        finishReconMission(config, reconSchedule, entry, LACMContext, true)
      end
    end

    ::continue::
  end
end

---Assign UAV to track a specific target contact
---Finds available UAV of specified type and assigns it to continuously track the target
---@param reconContext SBJ__ReconContext Reconnaissance context for tracking UAV assignments
---@param units CMO__SideUnit Side units collection to search for available UAVs
---@param UAVDBID number UAV platform database ID to filter by
---@param target CMO__Contact Target contact to track
---@return boolean # True if UAV was assigned to track target, false otherwise
function Recon.trackTarget(reconContext, units, UAVDBID, target)
  local UAV = nil

  -- Check if any UAV in queue is already tracking this target
  for _, entry in ipairs(reconContext.queue) do
    if entry.trackingTargetGUID == target.guid and entry.unitGUID then
      local unit = GameApi.ScenEdit_GetUnit(entry.unitGUID)
      if unit then
        return true
      end
    end
  end

  -- Find closest available UAV
  local minDistance = 1000
  for _, u in ipairs(units) do
    local actualUnit = GameApi.ScenEdit_GetUnit(u.guid)

    if actualUnit and actualUnit.dbid == UAVDBID and actualUnit.condition == 'Airborne' then
      local distance = GameApi.Tool_Range(
        { latitude = actualUnit.latitude, longitude = actualUnit.longitude }, target.guid
      )

      if distance and distance < minDistance then
        minDistance = distance
        UAV = actualUnit
      end
    end
  end

  if not UAV then
    return false
  end

  -- Find queue entry for this UAV
  local queueEntry = nil
  for _, entry in ipairs(reconContext.queue) do
    if entry.unitGUID == UAV.guid then
      queueEntry = entry
      break
    end
  end

  -- If not in queue, this UAV is not managed by reconnaissance system
  if not queueEntry then
    Logger.log("recon",
      string.format("UAV %s (GUID: %s) is not in reconnaissance queue. Cannot assign tracking mission.",
        UAV.name, UAV.guid))
    return false
  end

  -- Update existing entry and reactivate it for tracking mission
  queueEntry.isTracking = true
  queueEntry.trackingTargetGUID = target.guid
  queueEntry.isFinished = false -- Reactivate entry for tracking mission

  Logger.log("recon", string.format("Assigned UAV %s to track target %s", UAV.name, target.guid))
  return true
end

return Recon
