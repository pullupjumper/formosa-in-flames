local GameApi = require("src.utils.gameApi")
local Logger = require("src.utils.logger")
local constants = require("src.core.constants")

local CommsJamming = {}


-- ============================================================================
-- Enumerations & Constants
-- ============================================================================

local DISTANCE_CATEGORY = {
  CLOSE   = "close",
  MEDIUM  = "medium",
  FAR     = "far",
  DISTANT = "distant",
}

local COMMS_JAMMING_RESULT = {
  JAMMED   = "jammed",
  RESISTED = "resisted",
  COOLDOWN = "cooldown",
  RECOVERY = "recovery",
  SKIPPED  = "skipped",
}

local COMMS_JAMMING_MODE = {
  OMNIDIRECTIONAL = "omnidirectional",
  DIRECTIONAL     = "directional",
}

local EW_PLATFORM_DBIDS = {
  [constants.PLATFORMS.Y9]   = true,
  [constants.PLATFORMS.J15D] = true,
  [constants.PLATFORMS.J16D] = true,
}

local COMMS_RESULT_TAGS = {
  [COMMS_JAMMING_RESULT.JAMMED]   = "[OK]",
  [COMMS_JAMMING_RESULT.RESISTED] = "[RESIST]",
  [COMMS_JAMMING_RESULT.COOLDOWN] = "[CD]",
  [COMMS_JAMMING_RESULT.RECOVERY] = "[RCV]",
  [COMMS_JAMMING_RESULT.SKIPPED]  = "[SKIP]",
}

local omnidirectionalJammingWithDistance
local directionalJammingWithDistance

local jammingStrategies = {
  [COMMS_JAMMING_MODE.OMNIDIRECTIONAL] = function(config, entry, jammer)
    return omnidirectionalJammingWithDistance(config, entry, jammer)
  end,
  [COMMS_JAMMING_MODE.DIRECTIONAL] = function(config, entry, jammer)
    return directionalJammingWithDistance(config, entry, jammer)
  end,
}

local COMMS_JAMMING_LOG_TAG = "commsJamming"

-- ============================================================================
-- Signal Level Calculation
-- ============================================================================

---Get distance-based modifier category
---@param commsJammingConfig SBJ__CommsJammingConfig Configuration containing communication jamming parameters
---@param distance number Distance in nautical miles
---@return string|nil # Distance category ('close', 'medium', 'far', 'distant') or nil if out of range
local function getDistanceCategory(commsJammingConfig, distance)
  local thresholds = commsJammingConfig.distanceThresholds

  if distance < thresholds.close then
    return DISTANCE_CATEGORY.CLOSE
  elseif distance < thresholds.medium then
    return DISTANCE_CATEGORY.MEDIUM
  elseif distance < thresholds.far then
    return DISTANCE_CATEGORY.FAR
  elseif distance < thresholds.distant then
    return DISTANCE_CATEGORY.DISTANT
  end

  return nil
end


---Calculate jammer impact on communication modifier
---@param commsJammingConfig SBJ__CommsJammingConfig Configuration containing jamming parameters
---@param jammers table<string, SBJ__AircraftContext> Jammer contexts from saveData
---@param affectedUnitGUID string GUID of the affected unit
---@return number # Jammer impact on communication modifier
local function calculateJammerImpact(commsJammingConfig, jammers, affectedUnitGUID)
  local impact = 0

  for _, jammerCtx in pairs(jammers) do
    local actualJammer = GameApi.ScenEdit_GetUnit(jammerCtx.guid)

    if actualJammer and actualJammer.condition == constants.UNIT_CONDITIONS.AIRBORNE and actualJammer.jammer then
      impact = commsJammingConfig.baseJammingPower +
          GameApi.Tool_Range(affectedUnitGUID, actualJammer.guid) ^ commsJammingConfig.distanceExponent + impact
    end
  end

  return impact
end


---Calculate AEW support contribution to communication modifier
---@param commsJammingConfig SBJ__CommsJammingConfig Configuration containing AEW support parameters
---@param aewContexts table<string, SBJ__AircraftContext> AEW aircraft contexts
---@param affectedUnitGUID string GUID of the affected unit
---@return number # AEW support contribution
local function calculateAEWSupport(commsJammingConfig, aewContexts, affectedUnitGUID)
  local support = 0

  for _, AEWCtx in pairs(aewContexts) do
    local actualAEW = GameApi.ScenEdit_GetUnit(AEWCtx.guid)

    if actualAEW and actualAEW.condition == constants.UNIT_CONDITIONS.AIRBORNE then
      local distance = GameApi.Tool_Range(affectedUnitGUID, actualAEW.guid)
      local category = getDistanceCategory(commsJammingConfig, distance)

      if category then
        support = support + commsJammingConfig.aewSupport[category] + math.random(
          commsJammingConfig.randomVariance[category].min, commsJammingConfig.randomVariance[category].max
        )
      end
    end
  end

  return support
end


---Calculate ROCC support contribution to communication modifier
---Only the first valid ROCC is used for calculation
---@param commsJammingConfig SBJ__CommsJammingConfig Configuration containing ROCC support parameters
---@param roccContexts table<string, SBJ__C2Context> ROCC C2 contexts
---@param affectedUnitGUID string GUID of the affected unit
---@return number # ROCC support contribution
local function calculateROCCSupport(commsJammingConfig, roccContexts, affectedUnitGUID)
  for _, C2Ctx in pairs(roccContexts) do
    local actualROCC = GameApi.ScenEdit_GetUnit(C2Ctx.guid)

    if actualROCC then
      local distance = GameApi.Tool_Range(affectedUnitGUID, actualROCC.guid)
      local category = getDistanceCategory(commsJammingConfig, distance)

      if category then
        return commsJammingConfig.aewSupport[category] + math.random(
          commsJammingConfig.randomVariance[category].min, commsJammingConfig.randomVariance[category].max
        )
      end
      break
    end
  end

  return 0
end


---Calculate communication modifier for affected unit based on jammers and support systems
---@param commsJammingConfig SBJ__CommsJammingConfig Configuration containing communication jamming parameters
---@param saveData SBJ__SaveData Save data containing jammer, AEW, and C2 unit contexts
---@param affectedUnitGUID string GUID of the unit whose communication level is being calculated
---@return integer # The calculated communication modifier
local function getCommsLevel(commsJammingConfig, saveData, affectedUnitGUID)
  local commModifier = commsJammingConfig.initialComms
      + calculateJammerImpact(commsJammingConfig, saveData.c.commsJamming.jammers, affectedUnitGUID)
      + calculateAEWSupport(commsJammingConfig, saveData.t.air.landBased.AEW, affectedUnitGUID)
      + calculateROCCSupport(commsJammingConfig, saveData.t.iads.rocc, affectedUnitGUID)

  return math.floor(commModifier)
end


-- ============================================================================
-- Jamming State Machine
-- ============================================================================

---Check if a number is a valid (non-NaN) number
---@param n number The number to check
---@return boolean # True if the number is valid
local function isValidNumber(n)
  return n == n
end


---Calculate omnidirectional jamming effectiveness based on distance
---@param commsJammingConfig SBJ__CommsJammingConfig Configuration containing effectiveness formula
---@param distance number Distance between jammer and target in nautical miles
---@return number|nil # Effectiveness value (0-1) or nil if out of effective range
local function calculateOmnidirectionalEffectiveness(commsJammingConfig, distance)
  local ratio = distance ^ commsJammingConfig.effectivenessFormula.base /
      commsJammingConfig.range ^ commsJammingConfig.effectivenessFormula.range

  if ratio >= 1 then
    return nil
  end

  local effectiveness = math.sqrt(1 - ratio)
  if not isValidNumber(effectiveness) then
    return nil
  end

  return effectiveness
end


---Calculate directional jamming effectiveness based on bearing alignment
---@param jammer CMO__Unit The jamming aircraft unit
---@param targetGUID string GUID of the target unit
---@param distance number Distance between jammer and target
---@return boolean # Whether directional jamming is effective
local function calculateDirectionalEffectiveness(jammer, targetGUID, distance)
  local bearing = GameApi.Tool_Bearing(jammer.guid, targetGUID)
  local heading = jammer.heading
  local orientation = math.abs(bearing - heading)

  return distance < math.random(75, 100) and orientation < math.random(12, 18)
end


---Apply jamming state transition to an affected unit
---Handles: successful jamming, resistance, cooldown transition, and cooldown recovery
---@param commsJammingConfig SBJ__CommsJammingConfig Configuration containing jamming time parameters
---@param affectedUnitCtx SBJ__RadarContext The radar/SAM unit context
---@param shouldJam boolean Whether the jamming attempt should succeed
---@return string # JAMMING_RESULT enum value
local function applyJammingStateTransition(commsJammingConfig, affectedUnitCtx, shouldJam)
  if affectedUnitCtx.isOutOfComms ~= false then
    return COMMS_JAMMING_RESULT.SKIPPED
  end

  if affectedUnitCtx.outofcomms < 0 then
    GameApi.ScenEdit_SetUnit({ guid = affectedUnitCtx.guid, outofcomms = false })
    affectedUnitCtx.isOutOfComms = false
    affectedUnitCtx.outofcomms = affectedUnitCtx.outofcomms + 1
    return COMMS_JAMMING_RESULT.RECOVERY
  end

  local jammingThreshold = math.random(commsJammingConfig.jammingTime.min, commsJammingConfig.jammingTime.max)

  if affectedUnitCtx.outofcomms < jammingThreshold and affectedUnitCtx.outofcomms >= 0 then
    if shouldJam then
      GameApi.ScenEdit_SetUnit({ guid = affectedUnitCtx.guid, outofcomms = true })
      affectedUnitCtx.outofcomms = affectedUnitCtx.outofcomms + 1
      affectedUnitCtx.isOutOfComms = true
      return COMMS_JAMMING_RESULT.JAMMED
    else
      GameApi.ScenEdit_SetUnit({ guid = affectedUnitCtx.guid, outofcomms = false })
      affectedUnitCtx.outofcomms = 0
      affectedUnitCtx.isOutOfComms = false
      return COMMS_JAMMING_RESULT.RESISTED
    end
  end

  GameApi.ScenEdit_SetUnit({ guid = affectedUnitCtx.guid, outofcomms = false })
  affectedUnitCtx.isOutOfComms = false
  affectedUnitCtx.outofcomms = math.random(commsJammingConfig.cooldownTime.min, commsJammingConfig.cooldownTime.max)
  return COMMS_JAMMING_RESULT.COOLDOWN
end


---Apply omnidirectional communication jamming effects to a unit with pre-calculated distance
---@param commsJammingConfig SBJ__CommsJammingConfig Configuration containing jamming parameters
---@param entry { unitCtx: SBJ__RadarContext, distance: number } Target unit context with pre-calculated distance
---@param jammer CMO__Unit The jamming aircraft unit
---@return string # JAMMING_RESULT enum value
omnidirectionalJammingWithDistance = function(commsJammingConfig, entry, jammer)
  local effectiveness = calculateOmnidirectionalEffectiveness(commsJammingConfig, entry.distance)
  local shouldJam = effectiveness ~= nil and effectiveness > (math.random() / 2)

  return applyJammingStateTransition(commsJammingConfig, entry.unitCtx, shouldJam)
end


---Apply directional communication jamming effects to a unit with pre-calculated distance
---@param commsJammingConfig SBJ__CommsJammingConfig Configuration containing jamming parameters
---@param entry { unitCtx: SBJ__RadarContext, distance: number } Target unit context with pre-calculated distance
---@param jammer CMO__Unit The jamming aircraft unit
---@return string # JAMMING_RESULT enum value
directionalJammingWithDistance = function(commsJammingConfig, entry, jammer)
  local shouldJam = calculateDirectionalEffectiveness(jammer, entry.unitCtx.guid, entry.distance)

  return applyJammingStateTransition(commsJammingConfig, entry.unitCtx, shouldJam)
end


-- ============================================================================
-- Communication Recovery
-- ============================================================================

---Recover communications for a jammed unit based on recovery time configuration
---@param commsJammingConfig SBJ__CommsJammingConfig Configuration containing recovery time parameters
---@param affectedUnitCtx SBJ__RadarContext The radar/SAM unit context to recover communications for
local function recoverComms(commsJammingConfig, affectedUnitCtx)
  if affectedUnitCtx.isOutOfComms then
    if affectedUnitCtx.outofcomms <= math.random(commsJammingConfig.recoveryTime.min, commsJammingConfig.recoveryTime.max) then
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


-- ============================================================================
-- Target Collection
-- ============================================================================

---Find all airborne communication jammers from the jammer context table
---@param jammers table<string, SBJ__AircraftContext> Map of jammer GUIDs to aircraft contexts from saveData
---@return CMO__Unit[] # List of active airborne jammer units with active jamming capabilities
local function findJammers(jammers)
  local airborneJammers = {}

  for _, jammer in pairs(jammers) do
    local actualJammer = GameApi.ScenEdit_GetUnit(jammer.guid)

    if actualJammer and actualJammer.condition == constants.UNIT_CONDITIONS.AIRBORNE and actualJammer.jammer then
      table.insert(airborneJammers, actualJammer)
    end
  end

  return airborneJammers
end


---Collect all SAM and radar units from IADS systems for jamming operations
---@param iadsContext SBJ__IADSContext IADS context containing ROCC and TAAOC command structures with their managed units
---@return table<string, SBJ__RadarContext> unitCtxs Map of unit GUIDs to radar/SAM unit contexts for jamming targets
---@return integer unitCount Total number of collected units
local function findSAMAndRadar(iadsContext)
  local unitTemp = {}
  local unitCount = 0

  for _, c2Ctx in pairs(iadsContext.rocc) do
    for _, ctx in pairs(c2Ctx.sam) do
      unitTemp[ctx.guid] = ctx
      unitCount = unitCount + 1
    end
    for _, ctx in pairs(c2Ctx.radar) do
      unitTemp[ctx.guid] = ctx
      unitCount = unitCount + 1
    end
  end

  for _, c2Ctx in pairs(iadsContext.taaoc) do
    for _, ctx in pairs(c2Ctx.sam) do
      unitTemp[ctx.guid] = ctx
      unitCount = unitCount + 1
    end
  end

  return unitTemp, unitCount
end


-- ============================================================================
-- Jamming Orchestration
-- ============================================================================

---Recover communications for all tracked units
---@param commsJammingConfig SBJ__CommsJammingConfig Configuration containing recovery time parameters
---@param unitCtxs table<string, SBJ__RadarContext> Map of unit GUIDs to radar/SAM contexts
local function recoverAllComms(commsJammingConfig, unitCtxs)
  for _, ctx in pairs(unitCtxs) do
    recoverComms(commsJammingConfig, ctx)
  end
end


---Process jamming cycle for all jammers against all targets
---@param commsJammingConfig SBJ__CommsJammingConfig Configuration containing jamming parameters
---@param jammers CMO__Unit[] List of active jammer units
---@param unitCtxs table<string, SBJ__RadarContext> Map of unit GUIDs to radar/SAM contexts
---@return integer totalAttempts Total jamming attempts made
---@return integer totalJammed Total units processed
---@return string[] reportLines Per-jammer result lines for batch logging
local function processJammingCycle(commsJammingConfig, jammers, unitCtxs)
  local totalJammedUnits = 0
  local totalAttempts = 0
  local reportLines = {}
  local jammingFn = jammingStrategies[commsJammingConfig.mode]

  for _, jammer in ipairs(jammers) do
    local unitsWithDistance = {}
    for _, unitCtx in pairs(unitCtxs) do
      local distance = GameApi.Tool_Range(jammer.guid, unitCtx.guid)

      if distance then
        table.insert(unitsWithDistance, { unitCtx = unitCtx, distance = distance })
      end
    end

    table.sort(unitsWithDistance, function(a, b)
      return a.distance < b.distance
    end)

    local count = 0
    local entries = {}
    for _, entry in ipairs(unitsWithDistance) do
      if count >= commsJammingConfig.limit then
        break
      end

      local result = jammingFn(commsJammingConfig, entry, jammer)
      table.insert(entries,
        "    " .. COMMS_RESULT_TAGS[result] .. " " .. entry.unitCtx.name .. " (" .. math.floor(entry.distance) .. "nm)")
      count = count + 1
    end

    totalJammedUnits = totalJammedUnits + count
    totalAttempts = totalAttempts + count
    if #entries > 0 then
      table.insert(reportLines, "  " .. jammer.name .. ":")
      for _, e in ipairs(entries) do
        table.insert(reportLines, e)
      end
    end
  end

  return totalAttempts, totalJammedUnits, reportLines
end


---Process aircraft communications quality and trigger RTB for degraded aircraft
---@param commsJammingConfig SBJ__CommsJammingConfig Configuration containing communication parameters
---@param saveData SBJ__SaveData Save data containing aircraft contexts
---@return integer processed Total aircraft processed
---@return integer rtbCount Total aircraft ordered RTB
---@return string[] reportLines RTB detail lines for batch logging
local function processAircraftComms(commsJammingConfig, saveData)
  local aircraftProcessed = 0
  local aircraftRTB = 0
  local reportLines = {}

  for _, aircraftCtx in pairs(saveData.t.air.landBased.AC) do
    local actualAircraft = GameApi.ScenEdit_GetUnit(aircraftCtx.guid)

    if actualAircraft and actualAircraft.condition == constants.UNIT_CONDITIONS.AIRBORNE then
      aircraftProcessed = aircraftProcessed + 1
      aircraftCtx.commsLevel = aircraftCtx.commsBase + getCommsLevel(commsJammingConfig, saveData, actualAircraft.guid)

      if aircraftCtx.commsLevel < aircraftCtx.commsThreshold then
        GameApi.ScenEdit_SetUnit({ guid = aircraftCtx.guid, outofcomms = true, RTB = true })
        aircraftRTB = aircraftRTB + 1
        table.insert(reportLines, "    [RTB] " .. actualAircraft.name ..
          " (level: " .. aircraftCtx.commsLevel .. " < " .. aircraftCtx.commsThreshold .. ")")
      end
    end
  end

  return aircraftProcessed, aircraftRTB, reportLines
end


-- ============================================================================
-- Public API
-- ============================================================================

---Handle communication jamming operations for all active jammers and affected units
---Processes jamming effects on SAM/radar systems and monitors aircraft communication quality
---@param commsJammingConfig SBJ__CommsJammingConfig Configuration containing jamming parameters, thresholds, and effectiveness formulas
---@param saveData SBJ__SaveData Save data containing jammer contexts, target unit contexts, and IADS structure
function CommsJamming.handleCommsJamming(commsJammingConfig, saveData)
  local jammers = findJammers(saveData.c.commsJamming.jammers)
  local unitCtxs, targetCount = findSAMAndRadar(saveData.t.iads)

  recoverAllComms(commsJammingConfig, unitCtxs)
  local totalAttempts, totalJammed, jammingLines = processJammingCycle(commsJammingConfig, jammers, unitCtxs)
  local aircraftProcessed, aircraftRTB, rtbLines = processAircraftComms(commsJammingConfig, saveData)

  local reportLines = {
    string.format("CommsJamming: %d jammers, %d targets, %d aircraft",
      #jammers, targetCount, aircraftProcessed)
  }

  for _, line in ipairs(jammingLines) do
    table.insert(reportLines, line)
  end

  if #rtbLines > 0 then
    table.insert(reportLines, "  Aircraft:")
    for _, line in ipairs(rtbLines) do
      table.insert(reportLines, line)
    end
  end

  table.insert(reportLines, string.format("  Summary: %d/%d jamming processed, %d/%d aircraft RTB",
    totalJammed, totalAttempts, aircraftRTB, aircraftProcessed))

  Logger.log(COMMS_JAMMING_LOG_TAG, table.concat(reportLines, "\n"))
end

---Initialize communications jammer contexts for the specified side
---Scans all aircraft on the side and creates contexts for electronic warfare aircraft
---@param commsJammingCtx SBJ__CommsJammingContext Jamming context where jammer contexts will be stored
---@param sideName string The side name to scan for jammers (e.g., 'China', 'Taiwan')
---@param aircraftDefaults SBJ__AircraftCommsDefaults Aircraft communications default values
function CommsJamming.initCommsJammersContext(commsJammingCtx, sideName, aircraftDefaults)
  local filteredUnits = GameApi.VP_GetSide({ side = sideName }):unitsBy(constants.UNIT_TYPES.AIRCRAFT)

  if not filteredUnits then
    return
  end

  for _, u in ipairs(filteredUnits) do
    local actualUnit = GameApi.ScenEdit_GetUnit(u.guid)

    if actualUnit and EW_PLATFORM_DBIDS[actualUnit.dbid] then
      commsJammingCtx.jammers[actualUnit.guid] = {
        guid = actualUnit.guid,
        OODA = actualUnit.OODA,
        commsLevel = aircraftDefaults.commsLevel,
        commsBase = aircraftDefaults.commsBase,
        commsThreshold = aircraftDefaults.commsThreshold,
        outofcomms = aircraftDefaults.outOfComms,
      }
    end
  end
end

return CommsJamming
