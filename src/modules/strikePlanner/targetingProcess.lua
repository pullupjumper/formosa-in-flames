local GameApi = require("src.utils.gameApi")
local Utils = require("src.utils.utils")
local Logger = require("src.utils.logger")
local LogFormat = require("src.utils.logFormat")
local constants = require("src.core.constants")

local TargetingProcess = {}

-- ============================================================================
-- Enumerations & Lookup Tables
-- ============================================================================

---Target category labels for targetlist entries
local TARGET_CATEGORY = {
  AIRFIELD = "Airfield",
  PORT = "Port",
  ISR = "ISR",
  SAM = "SAM",
  ASM = "ASM",
  C2 = "C2",
}

---SAM radar sensor DBID lookup (TK-3, TK-2, PAC-3, TC-2)
local SAM_SENSOR_DBIDS = {
  [constants.SENSORS.TK3_LONG_MOUNTAIN] = true,
  [constants.SENSORS.TK3_LONG_WHITE_2] = true,
  [constants.SENSORS.TK2_CS_MPG25] = true,
  [constants.SENSORS.PAC3_MPQ65] = true,
  [constants.SENSORS.TC2_CS_MPQ90] = true,
  [constants.SENSORS.TPS_43F] = true,
}

---Airborne early warning sensor DBID lookup (P-3C SEAVUE, E-2K APS-145)
local AEW_SENSOR_DBIDS = {
  [constants.SENSORS.P3C_SEAVUE] = true,
  [constants.SENSORS.E2K_APS145] = true,
}

---C2 facility name patterns
local C2_PATTERNS = { "ROCC", "TAAOC" }

---Battle Damage Assessment structural status
local BDA_STATUS = {
  HEAVY_DAMAGE = "Heavy damage",
}

---Standalone target matching rules: { patternKey, subKey, category }
local STANDALONE_TARGET_RULES = {
  { patternKey = "radar", subKey = "radarPattern",    category = TARGET_CATEGORY.ISR },
  { patternKey = "sam",   subKey = "skyBowPattern",   category = TARGET_CATEGORY.SAM },
  { patternKey = "asm",   subKey = "asmPattern",      category = TARGET_CATEGORY.ASM },
  { patternKey = "c2",    subKey = "hengshanPattern", category = TARGET_CATEGORY.C2 },
}

---Reconnaissance tracking configuration per filter
---Maps filter names to their reconnaissance platform and target resolution logic
local RECON_TRACKING_CONFIG = {
  findNavalTargets = {
    platformDBID = constants.PLATFORMS.WZ8,
    getTarget = function(params, targetGUIDs)
      for _, contact in ipairs(params.contacts) do
        if contact.guid == targetGUIDs[1] then
          return contact
        end
      end
      return nil
    end,
  },
  findRadioDirection = {
    platformDBID = constants.PLATFORMS.BZK005,
    getTarget = function(params, targetGUIDs)
      return GameApi.ScenEdit_GetContact(constants.SIDES.ENEMY, targetGUIDs[1])
    end,
  },
}

-- ============================================================================
-- Contact Type Matching
-- ============================================================================

---Check if location is within threshold distance from contact
---@param location CMO__Location|nil Base location coordinates
---@param guid string Contact GUID
---@param threshold number Distance threshold in nautical miles
---@return boolean # True if within threshold, false otherwise
local function isNearby(location, guid, threshold)
  if not location then
    return false
  end

  local distance = GameApi.Tool_Range(location, guid)
  if not distance then
    return false
  end

  return distance <= threshold
end

---Empty an array in place so holders of the same table see the change
---@param list any[] Array to clear
local function clearList(list)
  for i = #list, 1, -1 do
    list[i] = nil
  end
end

---Initialize location map for bases or ports from contacts
---@param contacts CMO__Contact[] Array of contacts
---@param locationNames string[] Array of location names to find
---@return table<string, CMO__Location> # Map of location names to coordinates
local function buildLocationMap(contacts, locationNames)
  local locationMap = {}

  for _, name in ipairs(locationNames) do
    locationMap[name] = nil
  end

  for _, contact in ipairs(contacts) do
    for _, name in ipairs(locationNames) do
      if string.find(contact.type_description, name) then
        locationMap[name] = { latitude = contact.latitude, longitude = contact.longitude }
        break
      end
    end
  end

  return locationMap
end

---Match contact against airfield-related patterns
---@param description string Contact type description
---@param baseLocationMap table<string, CMO__Location> Map of base locations
---@param guid string Contact GUID
---@param threshold number Distance threshold in nautical miles
---@param patterns SBJ__AirfieldPatternConfig Airfield pattern configuration
---@return SBJ__TargetEntry|nil # Target entry or nil if no match
local function findAirfieldTarget(description, baseLocationMap, guid, threshold, patterns)
  local isAirfieldFacility =
      string.find(description, patterns.runwayPattern) or
      string.find(description, patterns.taxiwayPattern) or
      string.find(description, patterns.shelterPattern) or
      string.find(description, patterns.hangarPattern) or
      string.find(description, patterns.tarmacPattern) or
      string.find(description, patterns.helipadPattern) or
      string.find(description, patterns.ammoBunkerPattern) or
      string.find(description, patterns.ammoRevetmentPattern)

  if not isAirfieldFacility then
    return nil
  end

  for baseName, location in pairs(baseLocationMap) do
    if isNearby(location, guid, threshold) then
      return {
        name = baseName .. "/" .. description,
        guid = guid,
        category = TARGET_CATEGORY.AIRFIELD,
        subType = description,
      }
    end
  end

  return nil
end

---Match contact against port-related patterns
---@param description string Contact type description
---@param portLocationMap table<string, CMO__Location> Map of port locations
---@param guid string Contact GUID
---@param threshold number Distance threshold in nautical miles
---@param patterns SBJ__PortPatternConfig Port pattern configuration
---@return SBJ__TargetEntry|nil # Target entry or nil if no match
local function findPortTarget(description, portLocationMap, guid, threshold, patterns)
  if string.find(description, patterns.pierPattern) then
    for portName, location in pairs(portLocationMap) do
      if isNearby(location, guid, threshold) then
        return {
          name = portName .. "/" .. description,
          guid = guid,
          category = TARGET_CATEGORY.PORT,
          subType = description,
        }
      end
    end
  end

  return nil
end

---Match contact against standalone target patterns (Radar, SAM, ASM, C2)
---@param description string Contact type description
---@param guid string Contact GUID
---@param patterns SBJ__TargetCategoryPatternConfig Target category patterns configuration
---@return SBJ__TargetEntry|nil # Target entry or nil if no match
local function findStandaloneTarget(description, guid, patterns)
  for _, rule in ipairs(STANDALONE_TARGET_RULES) do
    if string.find(description, patterns[rule.patternKey][rule.subKey]) then
      return {
        name = description,
        guid = guid,
        category = rule.category,
        subType = description,
      }
    end
  end
  return nil
end

-- ============================================================================
-- Target Scanning
-- ============================================================================

---Scan and categorize contacts into a target list
---Results replace the contents of targetlist in place so the persisted table stays the same
---@param sideName string Side name to get contacts from (e.g., 'China')
---@param scanConfig SBJ__TargetScanningConfig Target scanning configuration with distanceThreshold, taiwanAirBases, taiwanPorts, and targetCategories
---@param targetlist SBJ__TargetEntry[] Persisted target list, cleared and refilled
function TargetingProcess.findTargets(sideName, scanConfig, targetlist)
  local contacts = GameApi.ScenEdit_GetContacts(sideName)

  if not contacts then
    Logger.warn(LogFormat.line("WARN", { side = sideName, reason = "contacts_unavailable" }))
    clearList(targetlist)
    return
  end

  local threshold = scanConfig.distanceThreshold

  -- Initialize location maps for bases and ports
  local baseLocationMap = buildLocationMap(contacts, scanConfig.taiwanAirBases)
  local portLocationMap = buildLocationMap(contacts, scanConfig.taiwanPorts)
  clearList(targetlist)

  -- Single pass through contacts to categorize all targets
  for _, contact in ipairs(contacts) do
    local target = nil

    -- Try matching airfield targets
    target = findAirfieldTarget(contact.type_description, baseLocationMap, contact.guid, threshold,
      scanConfig.targetCategories.airfield)
    if target then
      table.insert(targetlist, target)
      goto continue
    end

    -- Try matching port targets
    target = findPortTarget(contact.type_description, portLocationMap, contact.guid, threshold,
      scanConfig.targetCategories.port)
    if target then
      table.insert(targetlist, target)
      goto continue
    end

    -- Try matching standalone targets (Radar, SAM, ASM, C2)
    target = findStandaloneTarget(contact.type_description, contact.guid, scanConfig.targetCategories)
    if target then
      table.insert(targetlist, target)
    end

    ::continue::
  end

  Logger.log(constants.TAGS.TARGETING_PROCESS, LogFormat.line("OK", {
    side = sideName,
    action = "scan_targets",
    contacts = #contacts,
    targets = #targetlist
  }))
end

-- ============================================================================
-- Contact Filtering
-- ============================================================================

---Filter contacts matching predicate within target areas
---@param contacts CMO__Contact[] Contacts to filter
---@param areas string[][] Target area definitions
---@param predicate fun(contact: CMO__Contact): boolean Matching predicate (may have side effects)
---@return string[] # GUIDs of matching contacts
local function filterContactsInAreas(contacts, areas, predicate)
  local results = {}
  for _, area in ipairs(areas) do
    for _, contact in ipairs(contacts) do
      if predicate(contact) and contact:inArea(area) then
        table.insert(results, contact.guid)
      end
    end
  end
  return results
end

---Find ground targets (infantry or mobile vehicles) within specified areas
---Marks matched contacts with hostile posture; filters out contacts older than contactAge
---@param params SBJ__FilterParams Filter parameters containing contacts and task information
---@return string[] # Array of ground unit GUIDs found in target areas
local function findGroundTargets(params)
  local contactAge = params.task.target.contactAge
  return filterContactsInAreas(params.contacts, params.task.target.areas, function(contact)
    if contact.typed ~= constants.CONTACT_TYPES.FACILITY_MOBILE then
      return false
    end
    contact.posture = "H"
    return contact.lastDetections ~= nil
        and contact.lastDetections[1].age <= contactAge
  end)
end

---Find airborne early warning aircraft (P-3C, E-2K) within specified areas
---@param params SBJ__FilterParams Filter parameters with contacts, task, and config
---@return string[] # Array of airborne early warning aircraft GUIDs
local function findAirborne(params)
  local contactAge = params.task.target.contactAge
  return filterContactsInAreas(params.contacts, params.task.target.areas, function(contact)
    if not contact.emissions or not contact.emissions[1] then
      return false
    end
    return AEW_SENSOR_DBIDS[contact.emissions[1].sensor_dbid] ~= nil
        and contact.typed == constants.CONTACT_TYPES.AIR
        and contact.lastDetections ~= nil
        and contact.lastDetections[1].age <= contactAge
  end)
end

---Analyze radar emissions to identify SAM systems
---Detects Taiwanese SAM radar emissions (TK-3, TK-2, PAC-3, TC-2) within contact age limit
---@param params SBJ__FilterParams Filter parameters with contacts, task, and sensor configuration
---@return string[] # Array of SAM system GUIDs with active radar emissions
local function evaluateEmissions(params)
  local contactAge = params.task.target.contactAge
  return filterContactsInAreas(params.contacts, params.task.target.areas, function(contact)
    if not contact.emissions or not contact.emissions[1] then
      return false
    end
    return SAM_SENSOR_DBIDS[contact.emissions[1].sensor_dbid] ~= nil
        and contact.lastDetections ~= nil
        and contact.lastDetections[1].age <= contactAge
  end)
end

---Find Command and Control (C2) facilities
---Identifies ROCC and TAAOC command centers within target areas, filtered by contactAge
---@param params SBJ__FilterParams Filter parameters containing contacts and task information
---@return string[] # Array of C2 facility GUIDs (ROCC/TAAOC)
local function findC2(params)
  local contactAge = params.task.target.contactAge
  return filterContactsInAreas(params.contacts, params.task.target.areas, function(contact)
    if not contact.lastDetections or contact.lastDetections[1].age > contactAge then
      return false
    end
    for _, pattern in ipairs(C2_PATTERNS) do
      if string.find(contact.type_description, pattern) then
        return true
      end
    end
    return false
  end)
end

---Find naval targets (ships) within specified areas
---Identifies naval contacts within contact age limit
---@param params SBJ__FilterParams Filter parameters with contacts and task
---@return string[] # Array of naval target GUIDs
local function findNavalTargets(params)
  local contacts = params.contacts
  local task = params.task
  local contactAge = task.target.contactAge

  return filterContactsInAreas(contacts, task.target.areas, function(contact)
    return contact.typed == constants.CONTACT_TYPES.SURFACE
        and contact.lastDetections ~= nil
        and contact.lastDetections[1].age <= contactAge
  end)
end

---Check if target is within range of a radio transmission source
---@param config SBJ__Config Global configuration with SIGINT range and count thresholds
---@param distance number Distance in nautical miles to radio source
---@param transmission SBJ__RadioTransmissionContext Transmission data with current detection level (count) and other properties
---@return boolean # true if target is within max range and transmission exceeds count threshold
local function isWithinRange(config, distance, transmission)
  return distance <= config.c.sigint.maxRange and transmission.currentDetectionLevel > config.c.sigint.maxCount
end

---Filter targets that are within range of SIGINT-detected radio sources
---Cross-references contacts with SIGINT transmissions
---@param config SBJ__Config Global configuration with SIGINT parameters
---@param transmissions table<string, SBJ__RadioTransmissionContext> SIGINT transmission records
---@param contacts string[] Array of contact GUIDs to evaluate
---@return string[] # Array of contact GUIDs near radio sources
local function filterTargetsWithinRangeOfRadioSource(config, transmissions, contacts)
  local targets = {}

  for _, guid in ipairs(contacts) do
    local contact = GameApi.ScenEdit_GetContact(constants.SIDES.ENEMY, guid)

    if contact then
      for _, tm in pairs(transmissions) do
        local distance = GameApi.Tool_Range({ latitude = tm.latitude, longitude = tm.longitude }, guid)

        if distance and isWithinRange(config, distance, tm) then
          table.insert(targets, guid)
        end
      end
    end
  end

  return targets
end

---Find targets by radio direction (SIGINT-based targeting)
---Combines mobile targets and C2 units, filters by proximity to radio transmissions
---@param params SBJ__FilterParams Filter parameters with contacts, task, config, and transmissions
---@return string[] # Array of target GUIDs near radio sources
local function findRadioDirection(params)
  local contacts = params.contacts
  local transmissions = params.transmissions
  local task = params.task
  local config = params.config
  local targets = {}
  local mobileTargets = findGroundTargets({ contacts = contacts, task = task })
  local c2Targets = findC2({ contacts = contacts, task = task })

  if not config or not transmissions then
    return {}
  end

  Utils.addAll(targets, mobileTargets)
  Utils.addAll(targets, c2Targets)
  local radioSource = filterTargetsWithinRangeOfRadioSource(config, transmissions, targets)
  return radioSource
end

-- ============================================================================
-- Battle Damage Assessment
-- ============================================================================

---Evaluate if a target is valid for strike based on damage and detection status
---Checks BDA (Battle Damage Assessment), contact age, and special helipad conditions
---@param target CMO__Contact Contact object to evaluate
---@param contactAge number Maximum acceptable contact age in seconds
---@param isFirstWave boolean If true, accepts all targets; if false, applies BDA filtering
---@return boolean # True if target is valid for strike
local function evaluateTarget(target, contactAge, isFirstWave)
  local actualUnit = GameApi.ScenEdit_GetUnit(target.actualunitid)
  if not actualUnit then
    return false
  end

  if isFirstWave then
    return true
  end

  local isHelipad = string.find(target.type_description, "Helipad") ~= nil
  if isHelipad then
    return #actualUnit.embarkedUnits.Aircraft > 0
  end

  local BDA = target.BDA
  if not BDA or BDA.STRUCTURAL == BDA_STATUS.HEAVY_DAMAGE then
    return false
  end

  local detections = target.lastDetections
  if not detections or detections[1].age > contactAge then
    return false
  end

  return true
end

---Assess target damage status (Battle Damage Assessment)
---Filters target list based on BDA, excluding heavily damaged targets (unless first wave)
---@param task SBJ__Task Task containing target list and contact age parameters
---@param isFirstWave boolean If true, includes all targets; if false, filters by damage status
---@return string[] # Array of target GUIDs that passed BDA evaluation
local function evaluateTargetsDamage(task, isFirstWave)
  local evaluatedTargetlist = {}

  if type(task.target.list) ~= "table" or #task.target.list == 0 then
    return evaluatedTargetlist
  end

  for _, guid in ipairs(task.target.list) do
    local actualTarget = GameApi.ScenEdit_GetContact(constants.SIDES.ENEMY, guid)

    if actualTarget and evaluateTarget(actualTarget, task.target.contactAge, isFirstWave) then
      table.insert(evaluatedTargetlist, actualTarget.guid)
    end
  end

  return evaluatedTargetlist
end

-- ============================================================================
-- Target Query
-- ============================================================================

---Filter targets by type and base name
---@param targetlist SBJ__TargetEntry[] Array of target objects with name, subType, and guid properties
---@param queryParams SBJ__TargetQueryEntry[] Array of query parameters with baseName (optional) and subTypes (array)
---@return string[] # Array of target GUIDs matching query criteria
function TargetingProcess.filterTargetsByTypeAndBase(targetlist, queryParams)
  local selectedTargetlist = {}

  for _, item in ipairs(targetlist) do
    for _, param in ipairs(queryParams) do
      local isNameMatched = not param.baseName or string.find(item.name, param.baseName) ~= nil
      local isSubTypeMatched = false

      for _, subType in ipairs(param.subTypes) do
        if string.find(item.subType, subType) ~= nil then
          isSubTypeMatched = true
          break
        end
      end

      if isNameMatched and isSubTypeMatched then
        table.insert(selectedTargetlist, item.guid)
      end
    end
  end

  return selectedTargetlist
end

-- ============================================================================
-- Dynamic Target Processing
-- ============================================================================

---Dynamic target filters keyed by the names used in targetConfig.filterNames
---@type table<string, fun(params: SBJ__FilterParams): string[]|nil>
local FILTERS = {
  findInfantry = findGroundTargets,
  findAirborne = findAirborne,
  evaluateEmissions = evaluateEmissions,
  findMobileTargets = findGroundTargets,
  findNavalTargets = findNavalTargets,
  findC2 = findC2,
  findRadioDirection = findRadioDirection,
}

---Build the recon tracking request a filter's results call for
---Only resolves the target; whether a UAV is actually sent is up to Recon.trackTargets.
---@param params SBJ__FilterParams Filter parameters with contacts
---@param filterName string Name of the filter that produced targets
---@param targetGUIDs string[] Array of target GUIDs from the filter
---@return SBJ__TrackingRequestEntry|nil # Request for the lead target, nil when the filter needs no tracking
local function buildTrackingRequest(params, filterName, targetGUIDs)
  local trackingConfig = RECON_TRACKING_CONFIG[filterName]
  if not trackingConfig then
    return nil
  end

  local target = trackingConfig.getTarget(params, targetGUIDs)
  if not target then
    return nil
  end

  return { platformDBID = trackingConfig.platformDBID, target = target }
end

---Build filter parameters for dynamic target filtering
---@param config SBJ__Config Global configuration table
---@param plannerState SBJ__StrikePlannerState Strike planner state slices
---@param contacts CMO__Contact[] Available sensor contacts
---@param targetConfig SBJ__TargetTemplate Target configuration with filterNames, areas, contactAge, minTargetCount
---@return SBJ__FilterParams # Filter parameters for filter functions
local function buildFilterParams(config, plannerState, contacts, targetConfig)
  ---@type SBJ__FilterParams
  local params = {
    contacts = contacts,
    task = {
      target = {
        list = {},
        areas = targetConfig.areas,
        contactAge = targetConfig.contactAge,
        minTargetCount = targetConfig.minTargetCount or 1
      }
    },
    config = config,
    transmissions = plannerState.transmissions,
  }

  return params
end

---Process dynamic targets using filter functions
---@param config SBJ__Config Global configuration table
---@param plannerState SBJ__StrikePlannerState Strike planner state slices
---@param contacts CMO__Contact[] Available sensor contacts
---@param targetConfig SBJ__TargetTemplate Target configuration with filterNames
---@return string[] strikeTargets Array of target GUIDs matching the filter criteria
---@return SBJ__TrackingRequestEntry[] trackingRequests Recon tracking the results call for
local function processDynamicTargets(config, plannerState, contacts, targetConfig)
  local filterNames = targetConfig.filterNames
  if not filterNames or #filterNames == 0 then
    return {}, {}
  end

  local strikeTargets = {}
  local trackingRequests = {}
  local filterParams = buildFilterParams(config, plannerState, contacts, targetConfig)

  for _, filterName in ipairs(filterNames) do
    local targetingFunction = FILTERS[filterName]
    if targetingFunction then
      local targets = targetingFunction(filterParams)
      if targets and #targets > 0 then
        local request = buildTrackingRequest(filterParams, filterName, targets)
        if request then
          table.insert(trackingRequests, request)
        end
        Utils.addAll(strikeTargets, targets)
      end
    else
      Logger.warn(LogFormat.line("WARN", { filter = filterName, reason = "unknown_target_filter" }))
    end
  end

  return strikeTargets, trackingRequests
end

---Process fixed targets using BDA assessment
---@param plannerState SBJ__StrikePlannerState Strike planner state slices
---@param targetConfig SBJ__TargetTemplate Target configuration with objs, contactAge, minTargetCount
---@param isFirstWave boolean Whether this is the first wave
---@return string[] # Array of target GUIDs that passed BDA assessment
local function processFixedTargets(plannerState, targetConfig, isFirstWave)
  if not targetConfig.objs then
    return {}
  end

  local filteredTargets = TargetingProcess.filterTargetsByTypeAndBase(
    plannerState.targetlist,
    targetConfig.objs
  )
  if not filteredTargets or #filteredTargets == 0 then
    return {}
  end

  ---@type SBJ__Task
  local task = {
    target = {
      list = filteredTargets,
      contactAge = targetConfig.contactAge,
      minTargetCount = targetConfig.minTargetCount
    }
  }
  return evaluateTargetsDamage(task, isFirstWave) or {}
end

-- ============================================================================
-- Public API
-- ============================================================================

---Process targets by routing to dynamic or fixed target processing
---Never touches the recon queue; the caller hands trackingRequests to Recon.trackTargets.
---@param config SBJ__Config Global configuration table
---@param plannerState SBJ__StrikePlannerState Strike planner state slices
---@param contacts CMO__Contact[] Available sensor contacts
---@param targetConfig SBJ__TargetTemplate Target configuration (from taskTemplate.target or packageData.target)
---@param isFirstWave boolean Whether this is the first wave
---@return string[] targets Array of target GUIDs
---@return SBJ__TrackingRequestEntry[] trackingRequests Recon tracking the targets call for; always empty for fixed targets
function TargetingProcess.processTargets(config, plannerState, contacts, targetConfig, isFirstWave)
  if not targetConfig then
    return {}, {}
  end

  if type(targetConfig.filterNames) == "table" and #targetConfig.filterNames > 0 then
    return processDynamicTargets(config, plannerState, contacts, targetConfig)
  end

  return processFixedTargets(plannerState, targetConfig, isFirstWave), {}
end

return TargetingProcess
