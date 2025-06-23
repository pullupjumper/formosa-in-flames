---@param num number
---@param list table<number, CMO__Unit>
function IsDestroyedOrRTB(list, num)
  local times = 0

  for index, value in ipairs(list) do
    local unit = SE_GetUnit({ guid = value.unit })

    if unit and #unit.course == 0 then
      unit:RTB(true)
    end

    if unit == nil or (unit.unitstate == 'RTB_Manual' or unit.unitstate == 'RTB') then
      times = times + 1
    end

    if times >= num then
      return true
    end
  end

  return false
end

---@param baseGUID string
---@param course CMO__TableOfWaypoints
---@param num number
---@param unitDBID number
---@param unitType string @ Aircraft or Boats
function LaunchUnits(baseGUID, course, num, unitDBID, unitType)
  local base = ScenEdit_GetUnit({ guid = baseGUID })
  local count = 0
  local temp = {}
  if base == nil or base.embarkedUnits[unitType] == nil then return end

  for k, v in ipairs(base.embarkedUnits[unitType]) do
    local unit = ScenEdit_GetUnit({ guid = v })
    if unit == nil then goto continue end

    if unit.dbid == unitDBID and unit.readytime_v == 0 and count < num then
      unit:Launch(true)
      unit.course = course
      -- ScenEdit_SetUnit({ guid = unit.guid, course = course })
      count = count + 1
      -- table.insert(temp, { unit = unit.guid, hasLaunched = false })
      table.insert(temp, unit.guid)
    end

    if count >= num then break end
    ::continue::
  end

  return temp
end

---@param h6n CMO__Unit
---@param course CMO__TableOfWaypoints
---@param contact CMO__Contact|nil
function LaunchWZ8(h6n, course, contact)
  local wz8 = ScenEdit_AddUnit({
    side = 'China',
    type = 'Aircraft',
    name = 'WZ-8',
    dbid = 6642,
    LATITUDE = h6n.latitude,
    LONGITUDE = h6n.longitude,
    loadoutid = 32885,
    altitude = 20574,
    heading = 180,
    speed = 3300
  })

  if wz8 == nil then
    ScenEdit_MsgBox('wz8 is nil', 1)
    return
  end

  local arcT = { 'PB1', 'PB2', 'SB1', 'SB2', 'SMF1', 'PMF2' };
  ScenEdit_UpdateUnit({ guid = wz8.guid, mode = 'add_sensor', dbid = 4576, arc_detect = arcT, arc_track = arcT })
  ScenEdit_SetEMCON('Unit', wz8.guid, 'Radar=Active')

  if course == nil and contact ~= nil then
    ScenEdit_SetDoctrine(
      { guid = wz8.guid },
      { weapon_control_status_air = 1, fuel_state_rtb = 0, withdraw_on_fuel = 0, automatic_evasion = 0 }
    )

    local distance = Tool_Range(h6n.guid, contact.guid)
    local shortDistance = distance / 2
    local bearing = Tool_Bearing(h6n.guid, contact.guid)
    local initialPosition = World_GetPointFromBearing({
      latitude = h6n.latitude,
      longitude = h6n.longitude,
      distance = shortDistance,
      bearing = bearing
    })
    local finalPosition = World_GetPointFromBearing({
      latitude = h6n.latitude,
      longitude = h6n.longitude,
      distance = distance,
      bearing = bearing
    })
    course = {
      { lat = 'N 27.04.39', lon = 'E 122.14.20', desiredAltitude = 30480, desiredSpeed = 3300 },
      { lat = 'N 24.57.09', lon = 'E 121.31.35', desiredAltitude = 30480, desiredSpeed = 3300 },
    }

    course[1].lat = initialPosition.latitude
    course[1].lon = initialPosition.longitude
    course[2].lat = finalPosition.latitude
    course[2].lon = finalPosition.longitude
  end

  wz8.course = course
  h6n:RTB(true)
  return wz8
end

local function shouldTakeoffBeforeStrike(q)
  return (not q.hasLaunched) and q.takeoffTime ~= nil and q.missionStartTime ~= nil
end

local function shouldTakeoffAfterStrike(q)
  return (not q.hasLaunched) and q.missionStartTime ~= nil
end

local function isH6N(q)
  return not q.hasLaunched and q.unitDBID == CONFIG.platformDBID76
end

local function shouldEnterTargetArea(q)
  return q.hasLaunched and not q.isFinished and q.takeoffTime ~= nil and q.missionStartTime ~= nil
end

local function shouldRTB(q)
  return q.hasLaunched and not q.isFinished
end

function HandleReconQueue(saveData)
  for _, q in ipairs(saveData.c.recon.queue) do
    if shouldTakeoffBeforeStrike(q) and IsAfterStartTime(q.takeoffTime) then
      local units = LaunchUnits(q.baseGUID, q.course, q.num, q.unitDBID, 'Aircraft')

      if units and #units > 0 then
        q.unitGUID = units[1]
        q.hasLaunched = true
      end
    elseif shouldTakeoffAfterStrike(q) and IsAfterStartTime(q.missionStartTime) then
      local units = AssignEmbarkedUnitToStrikeMission(q.baseGUID, q.num, 0, q.unitDBID, q.missionName, false)

      if units and #units > 0 then
        q.unitGUID = units[1]
        q.hasLaunched = true
        q.isFinished = true
      end
    elseif isH6N(q) and IsAfterStartTime(q.takeoffTime) then
      local units = LaunchUnits(q.baseGUID, q.course, q.num, q.unitDBID, 'Aircraft')

      if units and #units > 0 then
        q.unitGUID = units[1]
        q.hasLaunched = true
      end
    end

    if shouldEnterTargetArea(q) and IsAfterStartTime(q.missionStartTime) then
      local unit = SE_GetUnit({ guid = q.unitGUID })

      if unit then
        ScenEdit_AssignUnitToMission(unit.guid, q.missionName)
        q.isFinished = true
      end
    elseif shouldRTB(q) then
      local unit = SE_GetUnit({ guid = q.unitGUID })

      if unit and #unit.course == 0 and unit.dbid == CONFIG.platformDBID12 and not q.isTracking then
        unit:RTB(true)
        q.isFinished = true
      end
    end
  end
end

function TrackTarget(saveData, units, UAVDBID, target)
  local UAV = nil
  local speed = 115
  local type = 'BZK005'

  if UAVDBID == CONFIG.platformDBID12 then
    speed = 3300
    type = 'WZ8'
  end

  for guid, value in pairs(saveData.c.recon.temp[type]) do
    if value.targetGUID == target.guid then
      local unit = SE_GetUnit({ guid = guid })
      if unit then return true end
    end
  end

  if UAV == nil then
    local d = 1000

    for _, value in ipairs(units) do
      local unit = SE_GetUnit({ guid = value.guid })

      if unit and unit.dbid == UAVDBID and unit.condition == 'Airborne' then
        local distance = Tool_Range({ latitude = unit.latitude, longitude = unit.longitude }, target.guid)
        if distance < d then
          d = distance
          UAV = unit
        end
      end
    end
  end

  if UAV and #UAV.course == 0 then
    if UAV.mission then UAV.mission = '' end

    UAV.course = { {
      latitude = target.latitude,
      longitude = target.longitude,
      desiredSpeed = speed,
      presetThrottle = 'Military'
    } }

    saveData.c.recon.temp[type][UAV.guid] = { guid = UAV.guid, targetGUID = target.guid }
    return true
  end

  return false
end

return {
  LaunchWZ8 = LaunchWZ8,
  AssignEmbarkedUnitToStrikeMission = AssignEmbarkedUnitToStrikeMission,
  HandleReconQueue = HandleReconQueue,
  TrackTarget = TrackTarget
}
