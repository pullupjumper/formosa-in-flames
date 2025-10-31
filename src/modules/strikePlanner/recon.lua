local GameUtils = require("src.utils.gameUtils")
local GameApi = require("src.utils.gameApi")
local AssignMission = require("src.modules.assignMission")

local Recon = {}

---Launch units from a base with specified parameters
---@param baseGUID string The base GUID to launch units from
---@param course CMO__TableOfWaypoints The course waypoints for launched units
---@param unitCount number The number of units to launch
---@param unitDBID number The unit database ID to filter by
---@param unitType string The unit type to launch (e.g., 'Aircraft' or 'Boats')
---@return string[]|nil Returns array of launched unit GUIDs, or nil if no units launched
function Recon.launchUnits(baseGUID, course, unitCount, unitDBID, unitType)
  local base = GameApi.ScenEdit_GetUnit(baseGUID)

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
---@param config SBJ__CONFIG Configuration data for platform DBIDs
---@param h6n CMO__Unit The H-6N bomber unit to launch from
---@param course CMO__TableOfWaypoints The reconnaissance course for WZ-8
---@return CMO__Unit|nil Returns the WZ-8 unit if successfully launched, nil otherwise
function Recon.launchWZ8(config, h6n, course)
  local wz8 = GameApi.ScenEdit_AddUnit({
    side = 'China',
    type = 'Aircraft',
    name = 'WZ-8',
    dbid = config.platform.WZ8,
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

---Check if reconnaissance should takeoff before strike mission starts
---@param entry SBJ__ReconQueueEntry Reconnaissance queue entry to check
---@return boolean True if should takeoff before strike, false otherwise
local function shouldTakeoffBeforeStrike(entry)
  return (not entry.hasLaunched) and entry.takeoffTime ~= nil and entry.missionStartTime ~= nil
end

---Check if reconnaissance should takeoff after strike mission starts
---@param entry SBJ__ReconQueueEntry Reconnaissance queue entry to check
---@return boolean True if should takeoff after strike, false otherwise
local function shouldTakeoffAfterStrike(entry)
  return (not entry.hasLaunched) and entry.missionStartTime ~= nil
end

---Check if the reconnaissance queue entry is for H-6N bomber
---@param config SBJ__CONFIG Configuration data for platform DBIDs
---@param entry SBJ__ReconQueueEntry Reconnaissance queue entry to check
---@return boolean True if unit is H-6N and hasn't launched, false otherwise
local function isH6N(config, entry)
  return not entry.hasLaunched and entry.unitDBID == config.platform.H6N
end

---Check if reconnaissance unit should enter target area
---@param entry SBJ__ReconQueueEntry Reconnaissance queue entry to check
---@return boolean True if should enter target area, false otherwise
local function shouldEnterTargetArea(entry)
  return entry.hasLaunched and not entry.isFinished and entry.takeoffTime ~= nil and entry.missionStartTime ~= nil
end

---Check if reconnaissance unit should return to base
---@param entry SBJ__ReconQueueEntry Reconnaissance queue entry to check
---@return boolean True if should RTB, false otherwise
local function shouldRTB(entry)
  return entry.hasLaunched and not entry.isFinished
end

---Process reconnaissance queue and manage reconnaissance mission lifecycle
---Handles takeoff timing, mission assignment, and RTB for all queued reconnaissance missions
---@param config SBJ__CONFIG Configuration data for platform DBIDs
---@param reconContext SBJ__ReconContext Reconnaissance context containing queue and temp tracking data
function Recon.handleReconQueue(config, reconContext)
  for _, entry in ipairs(reconContext.queue) do
    if shouldTakeoffBeforeStrike(entry) and GameUtils.isAfterStartTime(entry.takeoffTime) then
      local units = Recon.launchUnits(entry.baseGUID, entry.course, entry.unitCount, entry.unitDBID, 'Aircraft')

      if units and #units > 0 then
        entry.unitGUID = units[1]
        entry.hasLaunched = true
      end
    elseif shouldTakeoffAfterStrike(entry) and GameUtils.isAfterStartTime(entry.missionStartTime) then
      local units = AssignMission.assignEmbarkedUnitToStrikeMission(
        entry.baseGUID, entry.unitCount, 0, entry.unitDBID, entry.missionName, false
      )

      if units and #units > 0 then
        entry.unitGUID = units[1]
        entry.hasLaunched = true
        entry.isFinished = true
      end
    elseif isH6N(config, entry) and GameUtils.isAfterStartTime(entry.takeoffTime) then
      local units = Recon.launchUnits(entry.baseGUID, entry.course, entry.unitCount, entry.unitDBID, 'Aircraft')

      if units and #units > 0 then
        entry.unitGUID = units[1]
        entry.hasLaunched = true
      end
    end

    if shouldEnterTargetArea(entry) and GameUtils.isAfterStartTime(entry.missionStartTime) then
      local actualUnit = GameApi.ScenEdit_GetUnit(entry.unitGUID)

      if actualUnit then
        local result = GameApi.ScenEdit_AssignUnitToMission(actualUnit.guid, entry.missionName)

        if result then
          entry.isFinished = true
        end
      end
    elseif shouldRTB(entry) then
      local actualUnit = GameApi.ScenEdit_GetUnit(entry.unitGUID)

      if actualUnit and #actualUnit.course == 0 and actualUnit.dbid == config.platform.WZ8 and not entry.isTracking then
        actualUnit:RTB(true)
        entry.isFinished = true
      end

      if actualUnit and #actualUnit.course == 0 and actualUnit.dbid == config.platform.WZ8 and entry.isTracking then
        local targetGUID = reconContext.temp['WZ8'][actualUnit.guid].targetGUID
        local target = GameApi.ScenEdit_GetContact('China', targetGUID)

        if target then
          actualUnit.course = { {
            latitude = target.latitude,
            longitude = target.longitude,
            desiredSpeed = 3300,
            presetThrottle = 'Military'
          } }
        end
      end
    end
  end
end

---Assign UAV to track a specific target contact
---Finds available UAV of specified type and assigns it to continuously track the target
---@param config SBJ__CONFIG Configuration data for platform DBIDs
---@param reconContext SBJ__ReconContext Reconnaissance context for tracking UAV assignments
---@param units CMO__SideUnit Side units collection to search for available UAVs
---@param UAVDBID number UAV platform database ID to filter by
---@param target CMO__Contact Target contact to track
---@return boolean True if UAV was assigned to track target, false otherwise
function Recon.trackTarget(config, reconContext, units, UAVDBID, target)
  local UAV = nil
  local speed = 115
  local type = 'BZK005'

  if UAVDBID == config.platform.WZ8 then
    speed = 3300
    type = 'WZ8'
  end

  for guid, entry in pairs(reconContext.temp[type]) do
    if entry.targetGUID == target.guid then
      local unit = GameApi.ScenEdit_GetUnit(guid)
      if unit then return true end
    end
  end

  if UAV == nil then
    local d = 1000

    for _, u in ipairs(units) do
      local actualUnit = GameApi.ScenEdit_GetUnit(u.guid)

      if actualUnit and actualUnit.dbid == UAVDBID and actualUnit.condition == 'Airborne' then
        local distance = GameApi.Tool_Range(
          { latitude = actualUnit.latitude, longitude = actualUnit.longitude }, target.guid
        )

        if distance and distance < d then
          d = distance
          UAV = actualUnit
        end
      end
    end
  end

  if UAV then
    if UAV.mission then UAV.mission = '' end
    reconContext.temp[type][UAV.guid] = { guid = UAV.guid, targetGUID = target.guid }
    return true
  end

  return false
end

return Recon
