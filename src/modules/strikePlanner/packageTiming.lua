local GameApi = require("src.utils.gameApi")
local Utils = require("src.utils.utils")
local TankerMission = require("src.modules.strikePlanner.tankerMission")
local constants = require("src.core.constants")

local PackageTiming = {}

local PACKAGE_ROLES = { "striker", "escort", "wildWeasel", "jammer", "tanker" }
local TANKER_RECEIVER_ROLES = { "striker", "escort", "wildWeasel", "jammer" }

-- ============================================================================
-- Flight Time Calculation
-- ============================================================================

---Get the operational reference point for one mission zone
---Reads patrolZone first and falls back to zone
---@param missionCreationParams SBJ__MissionCreationParams Mission creation parameters
---@return CMO__Location|nil # Zone reference point coordinates or nil if unavailable
local function getMissionZonePoint(missionCreationParams)
  local opts = missionCreationParams and missionCreationParams.opts
  if not opts then
    return nil
  end

  local zone = opts.PatrolZone or opts.Zone
  if not zone or #zone == 0 then
    return nil
  end

  local point = GameApi.ScenEdit_GetReferencePoint({ side = constants.SIDES.ENEMY, name = zone[1] })
  if not point then
    return nil
  end

  return { latitude = point.latitude, longitude = point.longitude }
end

---Get normalized mission parameters for one role
---@param roleData SBJ__MissionDeploymentDescriptor Role deployment descriptor
---@param role string Role name
---@return SBJ__MissionCreationParams[] # Mission parameter array
local function getRoleMissionCreationParams(roleData, role)
  if role == "tanker" then
    local result = TankerMission.normalizeCreationParams(roleData.missionCreationParams)
    return result
  end

  if not roleData.missionCreationParams then
    return {}
  end

  return { roleData.missionCreationParams }
end

---Calculate flight time in seconds from distance in nautical miles
---@param distance number Distance in nautical miles
---@param role? string Role name; "tanker" uses tanker cruise speed, others use fighter speed
---@param timingConfig SBJ__AirTimingConfig Air timing configuration
---@return integer # Flight time in seconds, rounded up
local function calculateFlightTimeFromDistance(distance, role, timingConfig)
  local speed = role == "tanker" and
      timingConfig.cruiseSpeed.tanker or
      timingConfig.cruiseSpeed.combatAircraft
  return math.ceil((distance / speed) * 3600)
end

---Estimate the longest flight time from a support role's base to its operational zones
---@param packageData SBJ__PackageTemplate Package configuration containing role data
---@param role string Role name ("escort", "wildWeasel", "jammer", "tanker")
---@param timingConfig SBJ__AirTimingConfig Air timing configuration
---@return integer|nil # Flight time in seconds, or nil if role/base/zone/distance unavailable
local function estimateSupportRoleFlightTime(packageData, role, timingConfig)
  ---@type SBJ__MissionDeploymentDescriptor|nil
  local roleData = packageData[role]
  if not roleData or not roleData.baseGUID then
    return nil
  end

  local maxFlightTime = nil
  local missionParamsList = getRoleMissionCreationParams(roleData, role)

  for _, missionCreationParams in ipairs(missionParamsList) do
    local targetPoint = getMissionZonePoint(missionCreationParams)

    if targetPoint then
      local distance = GameApi.Tool_Range(roleData.baseGUID, targetPoint)

      if distance and distance > 0 then
        local flightTime = calculateFlightTimeFromDistance(distance, role, timingConfig)
        if not maxFlightTime or flightTime > maxFlightTime then
          maxFlightTime = flightTime
        end
      end
    end
  end

  return maxFlightTime
end

---Estimate striker flight time to the weapon release point
---@param packageData SBJ__PackageTemplate Package data containing striker baseGUID, weaponDBID, and target list
---@param timingConfig SBJ__AirTimingConfig Air timing configuration
---@return integer|nil # Flight time in seconds, or nil when required range data is unavailable
local function estimateStrikerFlightTime(packageData, timingConfig)
  if not packageData.striker or not packageData.striker.baseGUID or
      not packageData.striker.weaponDBID or
      not packageData.target or not packageData.target.list or #packageData.target.list == 0 then
    return nil
  end

  local weaponInfo = GameApi.ScenEdit_QueryDB("weapon", packageData.striker.weaponDBID)
  local weaponRange = tonumber(weaponInfo and weaponInfo.ranges and weaponInfo.ranges.land and weaponInfo.ranges.land
    .max)

  if not weaponRange then
    return nil
  end

  local targetRange = tonumber(GameApi.Tool_Range(packageData.striker.baseGUID, packageData.target.list[1]))

  if not targetRange then
    return nil
  end

  local distance = targetRange - weaponRange

  if not distance or distance <= 0 then
    return nil
  end

  return calculateFlightTimeFromDistance(distance, nil, timingConfig)
end

-- ============================================================================
-- Package Timing
-- ============================================================================

---Add the configured safety margin to one flight-time estimate
---@param flightTime number Estimated flight time in seconds
---@param timingConfig SBJ__AirTimingConfig Air timing configuration
---@return number # Conservative flight time in seconds
local function addFlightTimeSafetyMargin(flightTime, timingConfig)
  return flightTime + (timingConfig.flightTimeSafetyMargin or 0)
end

---Resolve conservative flight time for one package role
---@param packageData SBJ__PackageTemplate Package containing role and target data
---@param role string Package role name
---@param timingConfig SBJ__AirTimingConfig Air timing configuration
---@return number # Conservative flight time in seconds
local function resolveRoleFlightTime(packageData, role, timingConfig)
  local estimatedFlightTime
  local fallbackFlightTime
  if role == "striker" then
    estimatedFlightTime = estimateStrikerFlightTime(packageData, timingConfig)
    fallbackFlightTime = timingConfig.unresolvedFlightTime.striker
  else
    estimatedFlightTime = estimateSupportRoleFlightTime(packageData, role, timingConfig)
    fallbackFlightTime = timingConfig.unresolvedFlightTime.support
  end

  return addFlightTimeSafetyMargin(estimatedFlightTime or fallbackFlightTime, timingConfig)
end

---Find one tanker mission configuration by mission name
---@param packageData SBJ__PackageTemplate Package containing tanker configuration
---@param missionName string Tanker mission name
---@return SBJ__MissionCreationParams|nil # Matching tanker mission parameters
local function findTankerMissionParams(packageData, missionName)
  if not packageData.tanker then
    return nil
  end

  local missionParamsList = getRoleMissionCreationParams(packageData.tanker, "tanker")
  for _, missionParams in ipairs(missionParamsList) do
    if missionParams.name == missionName then
      return missionParams
    end
  end

  return nil
end

---Select the earlier of the current and candidate arrival timestamps
---@param currentArrival number|nil Current earliest arrival timestamp
---@param candidateArrival number|nil Candidate arrival timestamp
---@return number|nil # Earlier arrival timestamp, or nil when both are unavailable
local function selectEarlierArrival(currentArrival, candidateArrival)
  if candidateArrival and (not currentArrival or candidateArrival < currentArrival) then
    return candidateArrival
  end

  return currentArrival
end

---Calculate one receiver's arrival at a named tanker mission zone
---@param packageData SBJ__PackageTemplate Package containing tanker mission configuration
---@param receiver SBJ__MissionDeploymentDescriptor Receiver role deployment descriptor
---@param receiverTiming SBJ__RoleTiming Calculated receiver timing
---@param role string Receiver role name
---@param tankerMissionName string Referenced tanker mission name
---@param timingConfig SBJ__AirTimingConfig Air timing configuration
---@return number|nil # Receiver arrival timestamp, or nil when range data is unavailable
local function calculateReceiverArrivalAtTankerMission(
    packageData,
    receiver,
    receiverTiming,
    role,
    tankerMissionName,
    timingConfig)
  local tankerMissionParams = findTankerMissionParams(packageData, tankerMissionName)
  local tankerZonePoint = tankerMissionParams and getMissionZonePoint(tankerMissionParams)
  if not tankerZonePoint then
    return nil
  end

  local distance = GameApi.Tool_Range(receiver.baseGUID, tankerZonePoint)
  if not distance or distance <= 0 then
    return nil
  end

  local transitTime = calculateFlightTimeFromDistance(distance, role, timingConfig)
  return receiverTiming.startTime + addFlightTimeSafetyMargin(transitTime, timingConfig)
end

---Calculate the earliest arrival for one receiver role across referenced tanker missions
---@param packageData SBJ__PackageTemplate Package containing receiver and tanker missions
---@param roleTimings table<string, SBJ__RoleTiming> Calculated non-tanker role timings
---@param role string Receiver role name
---@param timingConfig SBJ__AirTimingConfig Air timing configuration
---@return number|nil # Earliest receiver arrival timestamp, or nil when unresolved
local function calculateEarliestRoleReceiverArrival(packageData, roleTimings, role, timingConfig)
  ---@type SBJ__MissionDeploymentDescriptor|nil
  local receiver = packageData[role]
  local receiverTiming = roleTimings[role]
  local opts = receiver and receiver.missionCreationParams and receiver.missionCreationParams.opts
  if not receiver or not receiverTiming or not opts or not opts.TankerMissionList then
    return nil
  end

  local earliestArrival = nil
  for _, tankerMissionName in ipairs(opts.TankerMissionList) do
    local arrivalTime = calculateReceiverArrivalAtTankerMission(
      packageData,
      receiver,
      receiverTiming,
      role,
      tankerMissionName,
      timingConfig
    )
    earliestArrival = selectEarlierArrival(earliestArrival, arrivalTime)
  end

  return earliestArrival
end

---Calculate the earliest receiver arrival at any configured tanker zone
---@param packageData SBJ__PackageTemplate Package containing receiver and tanker missions
---@param roleTimings table<string, SBJ__RoleTiming> Calculated non-tanker role timings
---@param timingConfig SBJ__AirTimingConfig Air timing configuration
---@return number|nil # Earliest receiver arrival timestamp, or nil when unresolved
local function calculateEarliestReceiverArrival(packageData, roleTimings, timingConfig)
  local earliestArrival = nil

  for _, role in ipairs(TANKER_RECEIVER_ROLES) do
    local arrivalTime = calculateEarliestRoleReceiverArrival(packageData, roleTimings, role, timingConfig)
    earliestArrival = selectEarlierArrival(earliestArrival, arrivalTime)
  end

  return earliestArrival
end

---Build one role timing from its planned on-station time
---@param roleData SBJ__MissionDeploymentDescriptor Role deployment descriptor
---@param plannedTimeOnStation number Planned on-station timestamp
---@param flightTime number Conservative flight time in seconds
---@param duration number Mission duration in seconds
---@return SBJ__RoleTiming # Calculated role timing
local function buildRoleTiming(roleData, plannedTimeOnStation, flightTime, duration)
  local usesTakeoffTime = roleData.startTime ~= nil and roleData.timeOnStation == nil
  local startTime = usesTakeoffTime and
      Utils.parseDatetimeToTimestamp(roleData.startTime) or
      plannedTimeOnStation - flightTime
  local timeOnStation = nil
  if not usesTakeoffTime then
    timeOnStation = plannedTimeOnStation
  end

  return {
    startTime = startTime,
    timeOnStation = timeOnStation,
    endTime = (usesTakeoffTime and startTime or plannedTimeOnStation) + duration
  }
end

---Build role timings relative to one striker TOT anchor
---@param packageData SBJ__PackageTemplate Package configuration
---@param strikerTimeOnTarget number Striker TOT timestamp
---@param timingConfig SBJ__AirTimingConfig Air timing configuration
---@return table<string, SBJ__RoleTiming> # Role timings indexed by role name
local function buildRoleTimings(packageData, strikerTimeOnTarget, timingConfig)
  local roleTimings = {}
  local strikerDuration = packageData.tanker and
      timingConfig.missionDuration.tanker or
      timingConfig.missionDuration.standard

  roleTimings.striker = buildRoleTiming(
    packageData.striker,
    strikerTimeOnTarget,
    resolveRoleFlightTime(packageData, "striker", timingConfig),
    strikerDuration
  )

  for _, role in ipairs({ "escort", "wildWeasel", "jammer" }) do
    ---@type SBJ__MissionDeploymentDescriptor|nil
    local roleData = packageData[role]
    if roleData then
      local leadTime = timingConfig.supportLeadTime[role] or 0
      local timeOnStation = strikerTimeOnTarget - leadTime
      roleTimings[role] = buildRoleTiming(
        roleData,
        timeOnStation,
        resolveRoleFlightTime(packageData, role, timingConfig),
        timingConfig.missionDuration.standard
      )
    end
  end

  if packageData.tanker then
    local earliestReceiverArrival = calculateEarliestReceiverArrival(packageData, roleTimings, timingConfig)
    local timeOnStation = earliestReceiverArrival and
        earliestReceiverArrival - timingConfig.tankerSetupTime or
        strikerTimeOnTarget - timingConfig.tankerUnresolvedArrivalLeadTime
    roleTimings.tanker = buildRoleTiming(
      packageData.tanker,
      timeOnStation,
      resolveRoleFlightTime(packageData, "tanker", timingConfig),
      timingConfig.missionDuration.tanker
    )
  end

  return roleTimings
end

---Shift all calculated package timings by one delta
---@param roleTimings table<string, SBJ__RoleTiming> Role timings indexed by role name
---@param delta number Shift amount in seconds
local function shiftRoleTimings(roleTimings, delta)
  if delta <= 0 then
    return
  end

  for _, timing in pairs(roleTimings) do
    timing.startTime = timing.startTime + delta
    timing.endTime = timing.endTime + delta
    if timing.timeOnStation then
      timing.timeOnStation = timing.timeOnStation + delta
    end
  end
end

---Get the earliest planned takeoff from calculated role timings
---@param roleTimings table<string, SBJ__RoleTiming> Role timings indexed by role name
---@return number # Earliest planned takeoff timestamp
local function getEarliestTakeoff(roleTimings)
  local earliestTakeoff = nil
  for _, timing in pairs(roleTimings) do
    if not earliestTakeoff or timing.startTime < earliestTakeoff then
      earliestTakeoff = timing.startTime
    end
  end

  return earliestTakeoff or GameApi.ScenEdit_CurrentTime()
end

---Infer the striker TOT represented by one package schedule
---@param packageData SBJ__PackageTemplate Package configuration
---@param timingConfig SBJ__AirTimingConfig Air timing configuration
---@return number|nil # Striker TOT timestamp, or nil when no schedule exists
local function inferStrikerTimeOnTarget(packageData, timingConfig)
  if packageData.striker.timeOnStation then
    return Utils.parseDatetimeToTimestamp(packageData.striker.timeOnStation)
  end

  if packageData.striker.startTime then
    return Utils.parseDatetimeToTimestamp(packageData.striker.startTime) +
        resolveRoleFlightTime(packageData, "striker", timingConfig)
  end

  return nil
end

---Resolve the striker TOT anchor implied by one package's scheduling mode
---@param packageData SBJ__PackageTemplate Package configuration
---@param timingConfig SBJ__AirTimingConfig Air timing configuration
---@return number # Striker TOT anchor timestamp
local function resolveStrikerTimeOnTargetAnchor(packageData, timingConfig)
  return inferStrikerTimeOnTarget(packageData, timingConfig) or GameApi.ScenEdit_CurrentTime()
end

---Format and apply calculated role timing to a package descriptor
---@param roleData SBJ__MissionDeploymentDescriptor Mission role to update
---@param timing SBJ__RoleTiming Calculated role timing
local function applyRoleTiming(roleData, timing)
  roleData.startTime = os.date(constants.DATE_FORMAT, timing.startTime) --[[@as string]]
  if timing.timeOnStation then
    roleData.timeOnStation = os.date(constants.DATE_FORMAT, timing.timeOnStation) --[[@as string]]
  else
    roleData.timeOnStation = nil
  end
  roleData.endTime = os.date(constants.DATE_FORMAT, timing.endTime) --[[@as string]]
end

---Create a single package with proper timing
---Converts package template to executable package with calculated timings for all roles
---@param config SBJ__Config Global configuration
---@param packageData SBJ__PackageTemplate Package template configuration
---@param previousPackage SBJ__Package|nil Previous executable package for sequential timing, nil for first valid package
---@param strikeInterval integer Time interval in seconds between consecutive strikes
---@return SBJ__Package # Executable package with complete timing and loadout status
function PackageTiming.createPackageWithTiming(config, packageData, previousPackage, strikeInterval)
  local timingConfig = config.c.air.timing
  local strikerTimeOnTarget = resolveStrikerTimeOnTargetAnchor(packageData, timingConfig)
  local roleTimings = buildRoleTimings(packageData, strikerTimeOnTarget, timingConfig)
  local earliestAllowedTakeoff = GameApi.ScenEdit_CurrentTime() +
      packageData.timeToReady + timingConfig.assignmentSafetyMargin
  local readinessShift = earliestAllowedTakeoff - getEarliestTakeoff(roleTimings)
  local intervalShift = 0

  if previousPackage then
    local previousTimeOnTarget = inferStrikerTimeOnTarget(previousPackage, timingConfig)
    if previousTimeOnTarget then
      intervalShift = previousTimeOnTarget + strikeInterval - strikerTimeOnTarget
    end
  end

  local scheduleShift = math.max(0, readinessShift, intervalShift)
  shiftRoleTimings(roleTimings, scheduleShift)

  for _, role in ipairs(PACKAGE_ROLES) do
    local roleData = packageData[role]
    if roleData and roleTimings[role] then
      applyRoleTiming(roleData, roleTimings[role])
    end
  end

  ---@cast packageData SBJ__Package
  packageData.loadoutStatus = {
    isLoadoutInitiated = false,
    loadoutInitiatedTime = nil,
    expectedReadyTime = nil,
    loadoutStartTime = nil
  }
  packageData.hasLaunched = false

  return packageData
end

return PackageTiming
