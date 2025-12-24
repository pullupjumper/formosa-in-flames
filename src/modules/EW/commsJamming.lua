local GameApi = require("src.utils.gameApi")
local Logger = require("src.utils.logger")
local Utils = require("src.utils.utils")
local constants = require("src.core.constants")

local CommsJamming = {}


---Get distance-based modifier category
---@param config SBJ__Config Configuration containing communication jamming parameters
---@param distance number Distance in nautical miles
---@return string|nil # Distance category ('close', 'medium', 'far', 'distant') or nil if out of range
local function getDistanceCategory(config, distance)
  local thresholds = config.c.commsJamming.distanceThresholds

  if distance < thresholds.close then
    return "close"
  elseif distance < thresholds.medium then
    return "medium"
  elseif distance < thresholds.far then
    return "far"
  elseif distance < thresholds.distant then
    return "distant"
  end

  return nil
end


---Calculate communication modifier for affected unit based on jammers and support systems
---@param config SBJ__Config Configuration containing communication jamming parameters
---@param saveData SBJ__SaveData Save data containing jammer, AEW, and C2 unit contexts
---@param affectedUnitGUID string GUID of the unit whose communication level is being calculated
---@return integer # The calculated communication modifier
local function getCommsLevel(config, saveData, affectedUnitGUID)
  local commModifier = config.c.commsJamming.initialComms

  for _, jammerCtx in pairs(saveData.c.commsJamming.jammers) do
    local actualJammer = GameApi.ScenEdit_GetUnit(jammerCtx.guid)

    if actualJammer and actualJammer.condition == "Airborne" and actualJammer.jammer then
      commModifier = config.c.commsJamming.baseJammingPower +
          GameApi.Tool_Range(affectedUnitGUID, actualJammer.guid) ^ config.c.commsJamming.distanceExponent +
          commModifier
    end
  end

  for _, AEWCtx in pairs(saveData.t.air.landBased.AEW) do
    local actualAEW = GameApi.ScenEdit_GetUnit(AEWCtx.guid)

    if actualAEW and actualAEW.condition == "Airborne" then
      local distance = GameApi.Tool_Range(affectedUnitGUID, actualAEW.guid)
      local category = getDistanceCategory(config, distance)

      if category then
        commModifier = commModifier + config.c.commsJamming.aewSupport[category] + math.random(
          config.c.commsJamming.randomVariance[category].min,
          config.c.commsJamming.randomVariance[category].max
        )
      end
    end
  end

  for _, C2Ctx in pairs(saveData.t.IADS.ROCC) do
    local actualROCC = GameApi.ScenEdit_GetUnit(C2Ctx.guid)

    if actualROCC then
      local distance = GameApi.Tool_Range(affectedUnitGUID, actualROCC.guid)
      local category = getDistanceCategory(config, distance)

      if category then
        commModifier = commModifier + config.c.commsJamming.aewSupport[category] + math.random(
          config.c.commsJamming.randomVariance[category].min,
          config.c.commsJamming.randomVariance[category].max
        )
      end
      break
    end
  end

  -- Log significant communication level changes (debugging aid)
  if commModifier < -200 then
    Logger.log("commsJamming", "CommsJamming: Severe comm degradation detected for " ..
      affectedUnitGUID .. " (level: " .. commModifier .. ")")
  elseif commModifier > 300 then
    Logger.log("commsJamming", "CommsJamming: Strong comm enhancement detected for " ..
      affectedUnitGUID .. " (level: " .. commModifier .. ")")
  end

  return math.floor(commModifier)
end

---Recover communications for a jammed unit based on recovery time configuration
---@param config SBJ__Config Configuration containing recovery time parameters
---@param affectedUnitCtx SBJ__RadarContext The radar/SAM unit context to recover communications for
local function recoverComms(config, affectedUnitCtx)
  if affectedUnitCtx.isOutOfComms then
    if affectedUnitCtx.outofcomms <= math.random(config.c.commsJamming.recoveryTime.min, config.c.commsJamming.recoveryTime.max) then
      GameApi.ScenEdit_SetUnit({ guid = affectedUnitCtx.guid, outofcomms = true })
      affectedUnitCtx.outofcomms = affectedUnitCtx.outofcomms + 1
    else
      GameApi.ScenEdit_SetUnit({ guid = affectedUnitCtx.guid, outofcomms = false })
      affectedUnitCtx.outofcomms = 0
      affectedUnitCtx.isOutOfComms = false
    end
  elseif affectedUnitCtx.isOutOfComms == false then
    local actualAffectedUnit = GameApi.ScenEdit_GetUnit(affectedUnitCtx.guid)

    if actualAffectedUnit and actualAffectedUnit.outOfComms then
      GameApi.ScenEdit_SetUnit({ guid = affectedUnitCtx.guid, outofcomms = false })
      affectedUnitCtx.outofcomms = 0
    end
  end
end


---Apply communication jamming effects to a unit with pre-calculated distance
---@param config SBJ__Config Configuration containing jamming parameters (range, effectiveness, timing)
---@param affectedUnitCtx SBJ__RadarContext The radar/SAM unit context being jammed
---@param jammer CMO__Unit The jamming aircraft unit
---@param distance number Pre-calculated distance between jammer and target unit in nautical miles
---@return boolean # Whether jamming was successfully applied
local function omnidirectionalJammingWithDistance(config, affectedUnitCtx, jammer, distance)
  if affectedUnitCtx.isOutOfComms == false then
    if affectedUnitCtx.outofcomms < math.random(config.c.commsJamming.jammingTime.min, config.c.commsJamming.jammingTime.max) and affectedUnitCtx.outofcomms >= 0 then
      local effectiveness = 1 * math.sqrt(
        1 - (distance ^ config.c.commsJamming.effectivenessFormula.base /
          config.c.commsJamming.range ^ config.c.commsJamming.effectivenessFormula.range)
      )

      if effectiveness == effectiveness and effectiveness > (math.random() / 2) then
        GameApi.ScenEdit_SetUnit({ guid = affectedUnitCtx.guid, outofcomms = true })
        affectedUnitCtx.outofcomms = affectedUnitCtx.outofcomms + 1
        affectedUnitCtx.isOutOfComms = true
        Logger.log("commsJamming",
          "Unit " .. affectedUnitCtx.guid .. " successfully jammed by " ..
          jammer.guid .. " (distance: " .. math.floor(distance) ..
          "nm, effectiveness: " .. string.format("%.2f", effectiveness) .. ")"
        )
        return true
      else
        GameApi.ScenEdit_SetUnit({ guid = affectedUnitCtx.guid, outofcomms = false })
        affectedUnitCtx.outofcomms = 0
        affectedUnitCtx.isOutOfComms = false
        Logger.log("commsJamming",
          "Unit " .. affectedUnitCtx.guid .. " jamming attempt failed (distance: " ..
          math.floor(distance) .. "nm, effectiveness: " .. string.format("%.2f", effectiveness) .. ")"
        )
        return true
      end
    elseif affectedUnitCtx.outofcomms < 0 then
      GameApi.ScenEdit_SetUnit({ guid = affectedUnitCtx.guid, outofcomms = false })
      affectedUnitCtx.isOutOfComms = false
      affectedUnitCtx.outofcomms = affectedUnitCtx.outofcomms + 1
    else
      GameApi.ScenEdit_SetUnit({ guid = affectedUnitCtx.guid, outofcomms = false })
      affectedUnitCtx.isOutOfComms = false
      affectedUnitCtx.outofcomms = math.random(
        config.c.commsJamming.cooldownTime.min, config.c.commsJamming.cooldownTime.max
      )
    end
  end

  return false
end

---Apply directional communication jamming effects to a unit with pre-calculated distance
---@param config SBJ__Config Configuration containing jamming parameters (range, effectiveness, timing)
---@param affectedUnitCtx SBJ__RadarContext The radar/SAM unit context being jammed
---@param jammer CMO__Unit The jamming aircraft unit
---@param distance number Pre-calculated distance between jammer and target unit in nautical miles
---@return boolean # Whether jamming was successfully applied
local function directionalJammingWithDistance(config, affectedUnitCtx, jammer, distance)
  if affectedUnitCtx.isOutOfComms == false then
    if affectedUnitCtx.outofcomms < math.random(config.c.commsJamming.jammingTime.min, config.c.commsJamming.jammingTime.max) and affectedUnitCtx.outofcomms >= 0 then
      local bearing = GameApi.Tool_Bearing(jammer.guid, affectedUnitCtx.guid)
      local heading = jammer.heading
      local orientation = math.abs(bearing - heading)

      if distance < math.random(75, 100) and orientation < math.random(12, 18) then
        GameApi.ScenEdit_SetUnit({ guid = affectedUnitCtx.guid, outofcomms = true })
        affectedUnitCtx.outofcomms = affectedUnitCtx.outofcomms + 1
        affectedUnitCtx.isOutOfComms = true
        Logger.log("commsJamming",
          "Unit " .. affectedUnitCtx.guid .. " successfully jammed by " ..
          jammer.guid .. " (distance: " .. math.floor(distance) .. "nm" .. ")"
        )
        return true
      else
        GameApi.ScenEdit_SetUnit({ guid = affectedUnitCtx.guid, outofcomms = false })
        affectedUnitCtx.outofcomms = 0
        affectedUnitCtx.isOutOfComms = false
        Logger.log("commsJamming",
          "Unit " .. affectedUnitCtx.guid .. " jamming attempt failed (distance: " ..
          math.floor(distance) .. "nm" .. ")"
        )
        return true
      end
    elseif affectedUnitCtx.outofcomms < 0 then
      GameApi.ScenEdit_SetUnit({ guid = affectedUnitCtx.guid, outofcomms = false })
      affectedUnitCtx.isOutOfComms = false
      affectedUnitCtx.outofcomms = affectedUnitCtx.outofcomms + 1
    else
      GameApi.ScenEdit_SetUnit({ guid = affectedUnitCtx.guid, outofcomms = false })
      affectedUnitCtx.isOutOfComms = false
      affectedUnitCtx.outofcomms = math.random(
        config.c.commsJamming.cooldownTime.min, config.c.commsJamming.cooldownTime.max
      )
    end
  end

  return false
end

---Find all airborne communication jammers from the jammer context table
---@param jammers table<string, SBJ__AircraftContext> Map of jammer GUIDs to aircraft contexts from saveData
---@return CMO__Unit[] # List of active airborne jammer units with active jamming capabilities
local function findJammers(jammers)
  local airborneJammers = {}

  for _, jammer in pairs(jammers) do
    local actualJammer = GameApi.ScenEdit_GetUnit(jammer.guid)

    if actualJammer and actualJammer.condition == "Airborne" and actualJammer.jammer then
      table.insert(airborneJammers, actualJammer)
    end
  end

  Logger.log("commsJamming", "CommsJamming: Found " .. #airborneJammers .. " active communication jammers")
  return airborneJammers
end

---Collect all SAM and radar units from IADS systems for jamming operations
---@param IADSContext SBJ__IADSContext IADS context containing ROCC and TAAOC command structures with their managed units
---@return table<string, SBJ__RadarContext> # Map of unit GUIDs to radar/SAM unit contexts for jamming targets
local function findSAMAndRadar(IADSContext)
  local unitTemp = {}
  local unitCount = 0

  for _, C2Ctx in pairs(IADSContext.ROCC) do
    for _, ctx in pairs(C2Ctx.SAM) do
      unitTemp[ctx.guid] = ctx
      unitCount = unitCount + 1
    end
    for _, ctx in pairs(C2Ctx.radar) do
      unitTemp[ctx.guid] = ctx
      unitCount = unitCount + 1
    end
  end

  for _, C2Ctx in pairs(IADSContext.TAAOC) do
    for _, ctx in pairs(C2Ctx.SAM) do
      unitTemp[ctx.guid] = ctx
      unitCount = unitCount + 1
    end
  end

  Logger.log("commsJamming", "CommsJamming: Found " .. unitCount .. " potential SAM/Radar targets")
  return unitTemp
end


---Handle communication jamming operations for all active jammers and affected units
---Processes jamming effects on SAM/radar systems and monitors aircraft communication quality
---Updates unit communication states and triggers RTB for aircraft with degraded communications
---@param config SBJ__Config Configuration containing jamming parameters, thresholds, and effectiveness formulas
---@param saveData SBJ__SaveData Save data containing jammer contexts, target unit contexts, and IADS structure
function CommsJamming.handleCommsJamming(config, saveData)
  local jammers = findJammers(saveData.c.commsJamming.jammers)
  local unitCtxs = findSAMAndRadar(saveData.t.IADS)

  for _, ctx in pairs(unitCtxs) do
    recoverComms(config, ctx)
  end

  local totalJammedUnits = 0
  local totalAttempts = 0

  Logger.log("commsJamming",
    "CommsJamming: Processing " .. #jammers .. " jammers against " ..
    Utils.getCount(unitCtxs) .. " potential targets"
  )

  -- Apply jamming effects with distance caching
  for _, jammer in ipairs(jammers) do
    -- Calculate all distances once and sort units by distance
    local unitsWithDistance = {}
    for _, unitCtx in pairs(unitCtxs) do
      local distance = GameApi.Tool_Range(jammer.guid, unitCtx.guid)

      if distance then
        table.insert(unitsWithDistance, { unitCtx = unitCtx, distance = distance })
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
      local result = omnidirectionalJammingWithDistance(config, entry.unitCtx, jammer, entry.distance)
      -- local result = directionalJammingWithDistance(config, entry.unitCtx, jammer, entry.distance)
      count = count + 1

      -- if result then
      --   count = count + 1
      -- end
    end

    totalJammedUnits = totalJammedUnits + count
    totalAttempts = totalAttempts + jammerAttempts
    Logger.log("commsJamming", "CommsJamming: Jammer " ..
      jammer.guid .. " processed " .. jammerAttempts .. " attempts, affected " .. count .. " units")
  end

  -- Handle aircraft communication quality
  local aircraftProcessed = 0
  local aircraftRTB = 0

  for _, aircraftCtx in pairs(saveData.t.air.landBased.AC) do
    local actualAircraft = GameApi.ScenEdit_GetUnit(aircraftCtx.guid)

    if actualAircraft and actualAircraft.condition == "Airborne" then
      aircraftProcessed = aircraftProcessed + 1
      local oldCommLevel = aircraftCtx.commsLevel or 0
      aircraftCtx.commsLevel = aircraftCtx.commsBase + getCommsLevel(config, saveData, actualAircraft.guid)

      if aircraftCtx.commsLevel < aircraftCtx.commsThreshold then
        GameApi.ScenEdit_SetUnit({ guid = aircraftCtx.guid, outofcomms = true, RTB = true })
        aircraftRTB = aircraftRTB + 1
        Logger.log("commsJamming", "Aircraft " .. aircraftCtx.guid ..
          " ordered RTB due to comm degradation (level: " ..
          aircraftCtx.commsLevel .. " < threshold: " .. aircraftCtx.commsThreshold .. ")")
      elseif math.abs(aircraftCtx.commsLevel - oldCommLevel) > 50 then
        Logger.log("commsJamming", "Aircraft " ..
          aircraftCtx.guid .. " comm level changed: " .. oldCommLevel .. " -> " .. aircraftCtx.commsLevel)
      end
    end
  end

  Logger.log("commsJamming",
    "CommsJamming: Summary - " .. totalJammedUnits .. "/" .. totalAttempts ..
    " jamming attempts successful, " .. aircraftRTB .. "/" .. aircraftProcessed .. " aircraft ordered RTB"
  )
end

---Initialize communications jammer contexts for the specified side
---Scans all aircraft on the side and creates contexts for Y-9, J-15D, and J-16D electronic warfare aircraft
---Contexts include OODA, communication levels, thresholds, and jamming state tracking
---@param saveData SBJ__SaveData Save data where jammer contexts will be stored in c.commsJamming.jammers
---@param sideName string The side name to scan for jammers (e.g., 'China', 'Taiwan')
function CommsJamming.initCommsJammersContext(saveData, sideName)
  ---@type CMO__SideUnit[]
  local filteredUnits = GameApi.VP_GetSide({ side = sideName }):unitsBy(constants.UNIT_TYPES.AIRCRAFT)

  if not filteredUnits then
    return
  end

  for _, u in ipairs(filteredUnits) do
    local actualUnit = GameApi.ScenEdit_GetUnit(u.guid)

    if actualUnit and (actualUnit.dbid == constants.PLATFORMS.Y9 or
          actualUnit.dbid == constants.PLATFORMS.J15D or
          actualUnit.dbid == constants.PLATFORMS.J16D) then
      saveData.c.commsJamming.jammers[actualUnit.guid] = {
        guid = actualUnit.guid,
        OODA = actualUnit.OODA,
        commsLevel = 40,
        commsBase = 40,
        commsThreshold = 30,
        outofcomms = 0,
      }
    end
  end
end

return CommsJamming
