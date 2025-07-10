local GameUtils = require("src.utils.gameUtils")
local GameApi = require("src.utils.gameApi")
local AssignMission = require("src.modules.assignMission")
local CONFIG = require("src.core.constants")

local Recon = {}

---@param baseGUID string
---@param course CMO__TableOfWaypoints
---@param unitCount number
---@param unitDBID number
---@param unitType string @ Aircraft or Boats
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
    local unit = GameApi.ScenEdit_GetUnit(guid)

    if unit and unit.dbid == unitDBID and unit.readytime_v == 0 and count < unitCount then
      unit:Launch(true)
      unit.course = course
      count = count + 1
      table.insert(temp, unit.guid)
    end

    if count >= unitCount then
      break
    end
  end

  return temp
end

---@param h6n CMO__Unit
---@param course CMO__TableOfWaypoints
---@return CMO__Unit|nil
function Recon.launchWZ8(h6n, course)
  local wz8 = GameApi.ScenEdit_AddUnit({
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

function Recon.handleReconQueue(saveData)
  for _, q in ipairs(saveData.c.recon.queue) do
    if shouldTakeoffBeforeStrike(q) and GameUtils.isAfterStartTime(q.takeoffTime) then
      local units = Recon.launchUnits(q.baseGUID, q.course, q.unitCount, q.unitDBID, 'Aircraft')

      if units and #units > 0 then
        q.unitGUID = units[1]
        q.hasLaunched = true
      end
    elseif shouldTakeoffAfterStrike(q) and GameUtils.isAfterStartTime(q.missionStartTime) then
      local units = AssignMission.assignEmbarkedUnitToStrikeMission(
        q.baseGUID, q.unitCount, 0, q.unitDBID, q.missionName, false
      )

      if units and #units > 0 then
        q.unitGUID = units[1]
        q.hasLaunched = true
        q.isFinished = true
      end
    elseif isH6N(q) and GameUtils.isAfterStartTime(q.takeoffTime) then
      local units = Recon.launchUnits(q.baseGUID, q.course, q.unitCount, q.unitDBID, 'Aircraft')

      if units and #units > 0 then
        q.unitGUID = units[1]
        q.hasLaunched = true
      end
    end

    if shouldEnterTargetArea(q) and GameUtils.isAfterStartTime(q.missionStartTime) then
      local unit = GameApi.ScenEdit_GetUnit(q.unitGUID)

      if unit then
        local result = GameApi.ScenEdit_AssignUnitToMission(unit.guid, q.missionName)

        if result then
          q.isFinished = true
        end
      end
    elseif shouldRTB(q) then
      local unit = GameApi.ScenEdit_GetUnit(q.unitGUID)

      if unit and #unit.course == 0 and unit.dbid == CONFIG.platformDBID12 and not q.isTracking then
        unit:RTB(true)
        q.isFinished = true
      end
    end
  end
end

---comment
---@param CONFIG SBJ__CONFIG
---@param saveData SBJ__SaveData
---@param units CMO__SideUnit
---@param UAVDBID number
---@param target CMO__Contact
---@return boolean
function Recon.trackTarget(CONFIG, saveData, units, UAVDBID, target)
  local UAV = nil
  local speed = 115
  local type = 'BZK005'

  if UAVDBID == CONFIG.platformDBID12 then
    speed = 3300
    type = 'WZ8'
  end

  for guid, value in pairs(saveData.c.recon.temp[type]) do
    if value.targetGUID == target.guid then
      local unit = GameApi.ScenEdit_GetUnit(guid)

      if unit then
        return true
      end
    end
  end

  if UAV == nil then
    local d = 1000

    for _, value in ipairs(units) do
      local unit = GameApi.ScenEdit_GetUnit(value.guid)

      if unit and unit.dbid == UAVDBID and unit.condition == 'Airborne' then
        local distance = GameApi.Tool_Range(
          { latitude = unit.latitude, longitude = unit.longitude }, target.guid
        )

        if distance and distance < d then
          d = distance
          UAV = unit
        end
      end
    end
  end

  if UAV and #UAV.course == 0 then
    if UAV.mission then
      UAV.mission = ''
    end

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

return Recon
