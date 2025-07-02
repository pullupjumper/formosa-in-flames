GameUtils = require("src.utils.gameUtils")
GameApi = require("src.utils.gameApi")
Utils = require("src.utils.utils")
AssignMission = require("src.modules.assignMission")
Logger = require("src.utils.logger")

Recon = {}

---@param baseGUID string
---@param course CMO__TableOfWaypoints
---@param unitCount number
---@param unitDBID number
---@param unitType string @ Aircraft or Boats
function Recon.LaunchUnits(baseGUID, course, unitCount, unitDBID, unitType)
  local base, err = Utils.SafeCall("GameApi.ScenEdit_GetUnit", GameApi.ScenEdit_GetUnit, baseGUID)

  if not base then
    Logger.error("Failed to get base unit '" .. baseGUID .. "': " .. err)
    return
  end

  local count = 0
  local temp = {}
  if #base.embarkedUnits[unitType] == 0 then return end

  for _, guid in ipairs(base.embarkedUnits[unitType]) do
    local unit, err = Utils.SafeCall("GameApi.ScenEdit_GetUnit", GameApi.ScenEdit_GetUnit, guid)

    if not unit then
      Logger.error("Failed to get unit '" .. guid .. "': " .. err)
      goto continue
    end

    if unit.dbid == unitDBID and unit.readytime_v == 0 and count < unitCount then
      unit:Launch(true)
      unit.course = course
      count = count + 1
      table.insert(temp, unit.guid)
    end

    if count >= unitCount then break end
    ::continue::
  end

  return temp
end

---@param h6n CMO__Unit
---@param course CMO__TableOfWaypoints
---@return CMO__Unit|nil
function Recon.LaunchWZ8(h6n, course)
  local wz8, err = Utils.SafeCall("GameApi.ScenEdit_AddUnit", GameApi.ScenEdit_AddUnit, {
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
    Logger.error("Failed to add WZ-8: " .. err)
    return
  end

  local arcT = { 'PB1', 'PB2', 'SB1', 'SB2', 'SMF1', 'PMF2' }
  local updatedUnit, err = Utils.SafeCall(
    "GameApi.ScenEdit_UpdateUnit",
    GameApi.ScenEdit_UpdateUnit,
    { guid = wz8.guid, mode = 'add_sensor', dbid = 4576, arc_detect = arcT, arc_track = arcT }
  )

  if not updatedUnit then
    Logger.error("Failed to update WZ-8: " .. err)
    return
  end

  local result, err = Utils.SafeCall(
    "GameApi.ScenEdit_SetEMCON",
    GameApi.ScenEdit_SetEMCON,
    "Unit",
    wz8.guid,
    "Radar=Active"
  )

  if result == nil then
    Logger.error("Failed to set EMCON: " .. err)
    return
  end

  wz8.course = course
  h6n:RTB(true)
  return wz8
end

function Recon._shouldTakeoffBeforeStrike(q)
  return (not q.hasLaunched) and q.takeoffTime ~= nil and q.missionStartTime ~= nil
end

function Recon._shouldTakeoffAfterStrike(q)
  return (not q.hasLaunched) and q.missionStartTime ~= nil
end

function Recon._isH6N(q)
  return not q.hasLaunched and q.unitDBID == CONFIG.platformDBID76
end

function Recon._shouldEnterTargetArea(q)
  return q.hasLaunched and not q.isFinished and q.takeoffTime ~= nil and q.missionStartTime ~= nil
end

function Recon._shouldRTB(q)
  return q.hasLaunched and not q.isFinished
end

function Recon.HandleReconQueue(saveData)
  for _, q in ipairs(saveData.c.recon.queue) do
    if Recon._shouldTakeoffBeforeStrike(q) and GameUtils.IsAfterStartTime(q.takeoffTime) then
      local units = Recon.LaunchUnits(q.baseGUID, q.course, q.unitCount, q.unitDBID, 'Aircraft')

      if units and #units > 0 then
        q.unitGUID = units[1]
        q.hasLaunched = true
      end
    elseif Recon._shouldTakeoffAfterStrike(q) and GameUtils.IsAfterStartTime(q.missionStartTime) then
      local units = AssignMission.AssignEmbarkedUnitToStrikeMission(
        q.baseGUID, q.unitCount, 0, q.unitDBID, q.missionName, false
      )

      if units and #units > 0 then
        q.unitGUID = units[1]
        q.hasLaunched = true
        q.isFinished = true
      end
    elseif Recon._isH6N(q) and GameUtils.IsAfterStartTime(q.takeoffTime) then
      local units = Recon.LaunchUnits(q.baseGUID, q.course, q.unitCount, q.unitDBID, 'Aircraft')

      if units and #units > 0 then
        q.unitGUID = units[1]
        q.hasLaunched = true
      end
    end

    if Recon._shouldEnterTargetArea(q) and GameUtils.IsAfterStartTime(q.missionStartTime) then
      local unit, err = Utils.SafeCall("GameApi.ScenEdit_GetUnit", GameApi.ScenEdit_GetUnit, q.unitGUID)

      if not unit then
        Logger.error("Failed to get unit '" .. q.unitGUID .. "': " .. err)
      else
        local result, err = Utils.SafeCall(
          "GameApi.ScenEdit_AssignUnitToMission",
          GameApi.ScenEdit_AssignUnitToMission,
          unit.guid,
          q.missionName
        )

        if not result then
          Logger.error("Failed to assign unit to mission: " .. err)
        else
          q.isFinished = true
        end
      end
    elseif Recon._shouldRTB(q) then
      local unit, err = Utils.SafeCall("GameApi.ScenEdit_GetUnit", GameApi.ScenEdit_GetUnit, q.unitGUID)

      if not unit then
        Logger.error("Failed to get unit '" .. q.unitGUID .. "': " .. err)
      elseif #unit.course == 0 and unit.dbid == CONFIG.platformDBID12 and not q.isTracking then
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
function Recon.TrackTarget(CONFIG, saveData, units, UAVDBID, target)
  local UAV = nil
  local speed = 115
  local type = 'BZK005'

  if UAVDBID == CONFIG.platformDBID12 then
    speed = 3300
    type = 'WZ8'
  end

  for guid, value in pairs(saveData.c.recon.temp[type]) do
    if value.targetGUID == target.guid then
      local unit, err = Utils.SafeCall("GameApi.ScenEdit_GetUnit", GameApi.ScenEdit_GetUnit, guid)

      if not unit then
        Logger.error("Failed to get unit '" .. guid .. "': " .. err)
        goto continue
      end

      return true
    end

    ::continue::
  end

  if UAV == nil then
    local d = 1000

    for _, value in ipairs(units) do
      local unit, err = Utils.SafeCall("GameApi.ScenEdit_GetUnit", GameApi.ScenEdit_GetUnit, value.guid)

      if not unit then
        Logger.error("Failed to get unit '" .. value.guid .. "': " .. err)
        goto continue
      end
      -- local unit = SE_GetUnit({ guid = value.guid })

      if unit and unit.dbid == UAVDBID and unit.condition == 'Airborne' then
        local distance, err = Utils.SafeCall(
          "GameApi.Tool_Range",
          GameApi.Tool_Range,
          { latitude = unit.latitude, longitude = unit.longitude },
          target.guid
        )

        if not distance then
          Logger.error("Failed to calculate range between points: " .. err)
          goto continue
        end

        if distance < d then
          d = distance
          UAV = unit
        end
      end

      ::continue::
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

return Recon
