local GameApi = require("src.utils.gameApi")
local Logger = require("src.utils.logger")
local Utils = require("src.utils.utils")

local CommsJamming = {}


---Calculate communication modifier for affected unit based on jammers and support systems
---@param config SBJ__CONFIG
---@param saveData SBJ__SaveData
---@param affectedUnitGUID string
---@return integer commModifier The calculated communication modifier
local function getCommsLevel(config, saveData, affectedUnitGUID)
  local commModifier = config.c.commsJamming.initialComms

  for _, jammer in pairs(saveData.c.commsJamming.jammers) do
    local actualJammer = GameApi.ScenEdit_GetUnit(jammer.guid)

    if actualJammer and actualJammer.condition == 'Airborne' and actualJammer.jammer then
      commModifier = config.c.commsJamming.baseJammingPower +
          GameApi.Tool_Range(affectedUnitGUID, actualJammer.guid) ^ config.c.commsJamming.distanceExponent +
          commModifier
    end
  end

  for _, AEW in pairs(saveData.t.air.landBased.AEW) do
    local actualAEW = GameApi.ScenEdit_GetUnit(AEW.guid)

    if actualAEW and actualAEW.condition == 'Airborne' then
      local distance = GameApi.Tool_Range(affectedUnitGUID, actualAEW.guid)
      if distance < 100 then
        commModifier = commModifier + config.c.commsJamming.aewSupport.close + math.random(
          config.c.commsJamming.randomVariance.close.min, config.c.commsJamming.randomVariance.close.max
        )
      elseif distance < 200 then
        commModifier = commModifier + config.c.commsJamming.aewSupport.medium + math.random(
          config.c.commsJamming.randomVariance.medium.min, config.c.commsJamming.randomVariance.medium.max
        )
      elseif distance < 300 then
        commModifier = commModifier + config.c.commsJamming.aewSupport.far + math.random(
          config.c.commsJamming.randomVariance.far.min, config.c.commsJamming.randomVariance.far.max
        )
      elseif distance < 400 then
        commModifier = commModifier + config.c.commsJamming.aewSupport.distant + math.random(
          config.c.commsJamming.randomVariance.distant.min, config.c.commsJamming.randomVariance.distant.max
        )
      end
    end
  end

  for ROCCGuid, value in pairs(saveData.t.IADS.ROCC) do
    local ROCC = GameApi.ScenEdit_GetUnit(ROCCGuid)

    if ROCC then
      local distance = GameApi.Tool_Range(affectedUnitGUID, ROCC.guid)
      if distance < 100 then
        commModifier = commModifier + config.c.commsJamming.aewSupport.close + math.random(
          config.c.commsJamming.randomVariance.close.min, config.c.commsJamming.randomVariance.close.max
        )
      elseif distance < 200 then
        commModifier = commModifier + config.c.commsJamming.aewSupport.medium + math.random(
          config.c.commsJamming.randomVariance.medium.min, config.c.commsJamming.randomVariance.medium.max
        )
      elseif distance < 300 then
        commModifier = commModifier + config.c.commsJamming.aewSupport.far + math.random(
          config.c.commsJamming.randomVariance.far.min, config.c.commsJamming.randomVariance.far.max
        )
      elseif distance < 400 then
        commModifier = commModifier + config.c.commsJamming.aewSupport.distant + math.random(
          config.c.commsJamming.randomVariance.distant.min, config.c.commsJamming.randomVariance.distant.max
        )
      end
      break
    end
  end

  -- Log significant communication level changes (debugging aid)
  if commModifier < -200 then
    Logger.log("CommsJamming: Severe comm degradation detected for " ..
      affectedUnitGUID .. " (level: " .. commModifier .. ")")
  elseif commModifier > 300 then
    Logger.log("CommsJamming: Strong comm enhancement detected for " ..
      affectedUnitGUID .. " (level: " .. commModifier .. ")")
  end

  return math.floor(commModifier)
end

---@param config SBJ__CONFIG
---@param affectedUnitData table
local function recoverComms(config, affectedUnitData)
  if affectedUnitData.isOutOfComms then
    if affectedUnitData.outofcomms <= math.random(config.c.commsJamming.recoveryTime.min, config.c.commsJamming.recoveryTime.max) then
      GameApi.ScenEdit_SetUnit({ guid = affectedUnitData.guid, outofcomms = true })
      affectedUnitData.outofcomms = affectedUnitData.outofcomms + 1
    else
      GameApi.ScenEdit_SetUnit({ guid = affectedUnitData.guid, outofcomms = false })
      affectedUnitData.outofcomms = 0
      affectedUnitData.isOutOfComms = false
    end
  elseif affectedUnitData.isOutOfComms == false then
    local actualAffectedUnit = GameApi.ScenEdit_GetUnit(affectedUnitData.guid)

    if actualAffectedUnit and actualAffectedUnit.outOfComms then
      GameApi.ScenEdit_SetUnit({ guid = affectedUnitData.guid, outofcomms = false })
      affectedUnitData.outofcomms = 0
    end
  end
end


---Apply communication jamming effects to a unit with pre-calculated distance
---@param config SBJ__CONFIG
---@param affectedUnit table The unit being jammed
---@param jammer table The jamming unit
---@param distance number Pre-calculated distance between jammer and unit
---@return boolean success Whether jamming was successfully applied
local function commsJammingWithDistance(config, affectedUnit, jammer, distance)
  if jammer and jammer.condition == 'Airborne' and jammer.jammer then
    if affectedUnit.isOutOfComms == false then
      if affectedUnit.outofcomms < math.random(config.c.commsJamming.jammingTime.min, config.c.commsJamming.jammingTime.max) and affectedUnit.outofcomms >= 0 then
        local effectiveness = 1 * math.sqrt(
          1 - (distance ^ config.c.commsJamming.effectivenessFormula.base /
            config.c.commsJamming.range ^ config.c.commsJamming.effectivenessFormula.range)
        )

        if effectiveness == effectiveness and effectiveness > (math.random() / 2) then
          GameApi.ScenEdit_SetUnit({ guid = affectedUnit.guid, outofcomms = true })
          affectedUnit.outofcomms = affectedUnit.outofcomms + 1
          affectedUnit.isOutOfComms = true
          Logger.log(
            "CommsJamming: Unit " .. affectedUnit.guid .. " successfully jammed by " ..
            jammer.guid .. " (distance: " .. math.floor(distance) ..
            "nm, effectiveness: " .. string.format("%.2f", effectiveness) .. ")"
          )
          return true
        else
          GameApi.ScenEdit_SetUnit({ guid = affectedUnit.guid, outofcomms = false })
          affectedUnit.outofcomms = 0
          affectedUnit.isOutOfComms = false
          Logger.log(
            "CommsJamming: Unit " .. affectedUnit.guid .. " jamming attempt failed (distance: " ..
            math.floor(distance) .. "nm, effectiveness: " .. string.format("%.2f", effectiveness) .. ")"
          )
          return true
        end
      elseif affectedUnit.outofcomms < 0 then
        GameApi.ScenEdit_SetUnit({ guid = affectedUnit.guid, outofcomms = false })
        affectedUnit.isOutOfComms = false
        affectedUnit.outofcomms = affectedUnit.outofcomms + 1
      else
        GameApi.ScenEdit_SetUnit({ guid = affectedUnit.guid, outofcomms = false })
        affectedUnit.isOutOfComms = false
        affectedUnit.outofcomms = math.random(
          config.c.commsJamming.cooldownTime.min, config.c.commsJamming.cooldownTime.max
        )
      end
    end
  end

  return false
end

---Find all airborne communication jammers
---@param saveData SBJ__SaveData
---@return table[] airborneJammers List of active airborne jammers
local function findJammers(saveData)
  local airborneJammers = {}

  for _, jammer in pairs(saveData.c.commsJamming.jammers) do
    local actualJammer = GameApi.ScenEdit_GetUnit(jammer.guid)

    if actualJammer and actualJammer.condition == 'Airborne' and actualJammer.jammer then
      table.insert(airborneJammers, actualJammer)
    end
  end

  Logger.log("CommsJamming: Found " .. #airborneJammers .. " active communication jammers")
  return airborneJammers
end

---Collect all SAM and radar units from IADS systems
---@param saveData SBJ__SaveData
---@return table<string, table> unitTable Map of unit GUIDs to unit objects
local function findSAMAndRadar(saveData)
  local unitTemp = {}
  local unitCount = 0

  for key, item in pairs(saveData.t.IADS.ROCC) do
    for _, data in pairs(item.SAM) do
      unitTemp[data.guid] = data
      unitCount = unitCount + 1
    end
    for _, value in pairs(item.radar) do
      unitTemp[value.guid] = value
      unitCount = unitCount + 1
    end
  end

  for key, item in pairs(saveData.t.IADS.TAAOC) do
    for _, data in pairs(item.SAM) do
      unitTemp[data.guid] = data
      unitCount = unitCount + 1
    end
  end

  Logger.log("CommsJamming: Found " .. unitCount .. " potential SAM/Radar targets")
  return unitTemp
end


---Handle communication jamming for all affected units
---@param config SBJ__CONFIG
---@param saveData SBJ__SaveData
function CommsJamming.handleCommsJamming(config, saveData)
  local jammers = findJammers(saveData)
  local units = findSAMAndRadar(saveData)

  for _, unitData in pairs(units) do
    recoverComms(config, unitData)
  end

  local totalJammedUnits = 0
  local totalAttempts = 0

  Logger.log(
    "CommsJamming: Processing " .. #jammers .. " jammers against " ..
    Utils.getCount(units) .. " potential targets"
  )

  -- Apply jamming effects with distance caching
  for _, jammer in ipairs(jammers) do
    -- Calculate all distances once and sort units by distance
    local unitsWithDistance = {}
    for _, unit in pairs(units) do
      local distance = GameApi.Tool_Range(jammer.guid, unit.guid)

      if distance then
        table.insert(unitsWithDistance, { unit = unit, distance = distance })
      end
    end

    -- Sort by distance (nearest first)
    table.sort(unitsWithDistance, function(a, b)
      return a.distance < b.distance
    end)

    -- Apply jamming effects up to limit
    local count = 0
    local jammerAttempts = 0
    for _, entry in ipairs(unitsWithDistance) do
      if count >= config.c.commsJamming.limit then
        break
      end

      jammerAttempts = jammerAttempts + 1
      local result = commsJammingWithDistance(config, entry.unit, jammer, entry.distance)
      if result then
        count = count + 1
      end
    end

    totalJammedUnits = totalJammedUnits + count
    totalAttempts = totalAttempts + jammerAttempts
    Logger.log("CommsJamming: Jammer " ..
      jammer.guid .. " processed " .. jammerAttempts .. " attempts, affected " .. count .. " units")
  end

  -- Handle aircraft communication quality
  local aircraftProcessed = 0
  local aircraftRTB = 0

  for _, AC in pairs(saveData.t.air.landBased.AC) do
    local actualAC = GameApi.ScenEdit_GetUnit(AC.guid)

    if actualAC and actualAC.condition == 'Airborne' then
      aircraftProcessed = aircraftProcessed + 1
      local oldCommLevel = AC.commsLevel or 0
      AC.commsLevel = AC.commsBase + getCommsLevel(config, saveData, actualAC.guid)

      if AC.commsLevel < AC.commsThreshold then
        GameApi.ScenEdit_SetUnit({ guid = AC.guid, outofcomms = true, RTB = true })
        aircraftRTB = aircraftRTB + 1
        Logger.log("CommsJamming: Aircraft " .. AC.guid ..
          " ordered RTB due to comm degradation (level: " ..
          AC.commsLevel .. " < threshold: " .. AC.commsThreshold .. ")")
      elseif math.abs(AC.commsLevel - oldCommLevel) > 50 then
        Logger.log("CommsJamming: Aircraft " ..
          AC.guid .. " comm level changed: " .. oldCommLevel .. " -> " .. AC.commsLevel)
      end
    end
  end

  Logger.log(
    "CommsJamming: Summary - " .. totalJammedUnits .. "/" .. totalAttempts ..
    " jamming attempts successful, " .. aircraftRTB .. "/" .. aircraftProcessed .. " aircraft ordered RTB"
  )
end

return CommsJamming
