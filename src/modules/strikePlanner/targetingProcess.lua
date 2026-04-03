local GameApi = require("src.utils.gameApi")
local Utils = require("src.utils.utils")
local Logger = require("src.utils.logger")
local Recon = require("src.modules.strikePlanner.recon")
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
    getTarget = function(opts, targetGUIDs)
      for _, contact in ipairs(opts.contacts) do
        if contact.guid == targetGUIDs[1] then
          return contact
        end
      end
      return nil
    end,
  },
  findRadioDirection = {
    platformDBID = constants.PLATFORMS.BZK005,
    getTarget = function(opts, targetGUIDs)
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

---Initialize location map for bases or ports from contacts
---@param contacts CMO__Contact[] Array of contacts
---@param locationNames string[] Array of location names to find
---@return table<string, CMO__Location> # Map of location names to coordinates
local function initializeLocationMap(contacts, locationNames)
  local locations = {}

  for _, name in ipairs(locationNames) do
    locations[name] = nil
  end

  for _, contact in ipairs(contacts) do
    for _, name in ipairs(locationNames) do
      if string.find(contact.type_description, name) then
        locations[name] = { latitude = contact.latitude, longitude = contact.longitude }
        break
      end
    end
  end

  return locations
end

---Match contact against airfield-related patterns
---@param description string Contact type description
---@param baseLocations table<string, CMO__Location> Map of base locations
---@param guid string Contact GUID
---@param threshold number Distance threshold in nautical miles
---@param patterns SBJ__AirfieldPatterns Airfield pattern configuration
---@return SBJ__TargetEntry|nil # Target entry or nil if no match
local function matchAirfieldTarget(description, baseLocations, guid, threshold, patterns)
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

  for baseName, location in pairs(baseLocations) do
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
---@param portLocations table<string, CMO__Location> Map of port locations
---@param guid string Contact GUID
---@param threshold number Distance threshold in nautical miles
---@param patterns SBJ__PortPatterns Port pattern configuration
---@return SBJ__TargetEntry|nil # Target entry or nil if no match
local function matchPortTarget(description, portLocations, guid, threshold, patterns)
  if string.find(description, patterns.pierPattern) then
    for portName, location in pairs(portLocations) do
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
---@param patterns SBJ__TargetCategoryPatterns Target category patterns configuration
---@return SBJ__TargetEntry|nil # Target entry or nil if no match
local function matchStandaloneTarget(description, guid, patterns)
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
---Results are directly assigned to saveData.c.targetlist
---@param sideName string Side name to get contacts from (e.g., 'China')
---@param scanConfig SBJ__TargetScanningConfig Target scanning configuration with distanceThreshold, taiwanAirBases, taiwanPorts, and targetCategories
---@param saveData SBJ__SaveData Persistent save data
function TargetingProcess.scanTargets(sideName, scanConfig, saveData)
  local contacts = GameApi.ScenEdit_GetContacts(sideName)

  if not contacts then
    Logger.warn(string.format("Failed to get %s contacts", sideName))
    saveData.c.targetlist = {}
    return
  end

  local threshold = scanConfig.distanceThreshold

  -- Initialize location maps for bases and ports
  local baseLocations = initializeLocationMap(contacts, scanConfig.taiwanAirBases)
  local portLocations = initializeLocationMap(contacts, scanConfig.taiwanPorts)
  local targetlist = {}
  ---@cast targetlist SBJ__TargetEntry[]

  -- Single pass through contacts to categorize all targets
  for _, contact in ipairs(contacts) do
    local target = nil

    -- Try matching airfield targets
    target = matchAirfieldTarget(contact.type_description, baseLocations, contact.guid, threshold,
      scanConfig.targetCategories.airfield)
    if target then
      table.insert(targetlist, target)
      goto continue
    end

    -- Try matching port targets
    target = matchPortTarget(contact.type_description, portLocations, contact.guid, threshold,
      scanConfig.targetCategories.port)
    if target then
      table.insert(targetlist, target)
      goto continue
    end

    -- Try matching standalone targets (Radar, SAM, ASM, C2)
    target = matchStandaloneTarget(contact.type_description, contact.guid, scanConfig.targetCategories)
    if target then
      table.insert(targetlist, target)
    end

    ::continue::
  end

  saveData.c.targetlist = targetlist
  Logger.log(constants.TAGS.TARGETING_PROCESS, string.format("Scanned %d targets for %s", #targetlist, sideName))
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
---Marks matched contacts with hostile posture
---@param opts SBJ__FilterParams Filter parameters containing contacts and task information
---@return string[] # Array of ground unit GUIDs found in target areas
local function findGroundTargets(opts)
  return filterContactsInAreas(opts.contacts, opts.task.target.areas, function(contact)
    if contact.typed ~= constants.CONTACT_TYPES.FACILITY_MOBILE then
      return false
    end
    contact.posture = "H"
    return true
  end)
end

---Find airborne early warning aircraft (P-3C, E-2K) within specified areas
---@param opts SBJ__FilterParams Filter parameters with contacts, task, and config
---@return string[] # Array of airborne early warning aircraft GUIDs
local function findAirborne(opts)
  return filterContactsInAreas(opts.contacts, opts.task.target.areas, function(contact)
    if not contact.emissions or not contact.emissions[1] then
      return false
    end
    return AEW_SENSOR_DBIDS[contact.emissions[1].sensor_dbid] ~= nil
        and contact.typed == constants.CONTACT_TYPES.AIR
  end)
end

---Analyze radar emissions to identify SAM systems
---Detects Taiwanese SAM radar emissions (TK-3, TK-2, PAC-3, TC-2) within contact age limit
---@param opts SBJ__FilterParams Filter parameters with contacts, task, and sensor configuration
---@return string[] # Array of SAM system GUIDs with active radar emissions
local function analyzeEmissions(opts)
  local contactAge = opts.task.target.contactAge
  return filterContactsInAreas(opts.contacts, opts.task.target.areas, function(contact)
    if not contact.emissions or not contact.emissions[1] then
      return false
    end
    return SAM_SENSOR_DBIDS[contact.emissions[1].sensor_dbid] ~= nil
        and contact.lastDetections ~= nil
        and contact.lastDetections[1].age <= contactAge
  end)
end

---Find Command and Control (C2) facilities
---Identifies ROCC and TAAOC command centers within target areas
---@param opts SBJ__FilterParams Filter parameters containing contacts and task information
---@return string[] # Array of C2 facility GUIDs (ROCC/TAAOC)
local function findC2(opts)
  return filterContactsInAreas(opts.contacts, opts.task.target.areas, function(contact)
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
---@param opts SBJ__FilterParams Filter parameters with contacts and task
---@return string[] # Array of naval target GUIDs
local function findNavalTargets(opts)
  local contacts = opts.contacts
  local task = opts.task
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
---@param saveData SBJ__SaveData Persistent save data containing SIGINT transmission records
---@param contacts string[] Array of contact GUIDs to evaluate
---@return string[] # Array of contact GUIDs near radio sources
local function filterTargetsWithinRangeOfRadioSource(config, saveData, contacts)
  local targets = {}

  for _, guid in ipairs(contacts) do
    local contact = GameApi.ScenEdit_GetContact(constants.SIDES.ENEMY, guid)

    if contact then
      for _, tm in pairs(saveData.c.sigint.transmissions) do
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
---@param opts SBJ__FilterParams Filter parameters with contacts, task, config, and saveData
---@return string[] # Array of target GUIDs near radio sources
local function findRadioDirection(opts)
  local contacts = opts.contacts
  local saveData = opts.saveData
  local task = opts.task
  local config = opts.config
  local targets = {}
  local mobileTargets = findGroundTargets({ contacts = contacts, task = task })
  local c2Targets = findC2({ contacts = contacts, task = task })

  if not config or not saveData then
    return {}
  end

  Utils.insertList(targets, mobileTargets)
  Utils.insertList(targets, c2Targets)
  local radioSource = filterTargetsWithinRangeOfRadioSource(config, saveData, targets)
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
local function assessTargetsDamage(task, isFirstWave)
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
---@param queryParams SBJ__TargetQueryParam[] Array of query parameters with baseName (optional) and subTypes (array)
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

---Trigger reconnaissance tracking for a filter's results
---@param opts SBJ__FilterParams Filter options with contacts and saveData
---@param filterName string Name of the filter that produced targets
---@param targetGUIDs string[] Array of target GUIDs from the filter
local function triggerReconTracking(opts, filterName, targetGUIDs)
  local trackingConfig = RECON_TRACKING_CONFIG[filterName]
  if not trackingConfig or not opts.saveData then
    return
  end

  local side = GameApi.VP_GetSide({ side = constants.SIDES.ENEMY })
  if not side then return end

  local filteredUnits = side:unitsBy(constants.UNIT_TYPES.AIRCRAFT)
  if not filteredUnits then return end

  local target = trackingConfig.getTarget(opts, targetGUIDs)
  if not target then return end

  Recon.trackTarget(opts.saveData.c.recon, filteredUnits, trackingConfig.platformDBID, target)
end

---@package
---Internal functions exposed for unit testing and stubbable dispatch
TargetingProcess._internal = {
  findInfantry = findGroundTargets,
  findAirborne = findAirborne,
  analyzeEmissions = analyzeEmissions,
  findMobileTargets = findGroundTargets,
  findNavalTargets = findNavalTargets,
  findC2 = findC2,
  findRadioDirection = findRadioDirection,
  evaluateTarget = evaluateTarget,
  assessTargetsDamage = assessTargetsDamage,
  triggerReconTracking = triggerReconTracking,
}

---Build filter options for dynamic target filtering
---@param config SBJ__Config Global configuration table
---@param saveData SBJ__SaveData Persistent save data
---@param contacts CMO__Contact[] Available sensor contacts
---@param targetConfig SBJ__TargetTemplate Target configuration with filterNames, areas, contactAge, minTargetCount
---@return SBJ__FilterParams # Filter options for filter functions
local function buildFilterOptions(config, saveData, contacts, targetConfig)
  ---@type SBJ__FilterParams
  local opts = {
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
    saveData = saveData,
  }

  return opts
end

---Process dynamic targets using filter functions
---@param config SBJ__Config Global configuration table
---@param saveData SBJ__SaveData Persistent save data
---@param contacts CMO__Contact[] Available sensor contacts
---@param targetConfig SBJ__TargetTemplate Target configuration with filterNames
---@return string[] # Array of target GUIDs matching the filter criteria
local function processDynamicTargets(config, saveData, contacts, targetConfig)
  local filterNames = targetConfig.filterNames
  if not filterNames or #filterNames == 0 then
    return {}
  end

  local strikeTargets = {}
  local filterOpts = buildFilterOptions(config, saveData, contacts, targetConfig)

  for _, filterName in ipairs(filterNames) do
    ---@type fun(opts: SBJ__FilterParams): string[]|nil
    local targetingFunction = TargetingProcess._internal[filterName]
    if targetingFunction then
      local targets = targetingFunction(filterOpts)
      if targets and #targets > 0 then
        triggerReconTracking(filterOpts, filterName, targets)
        Utils.insertList(strikeTargets, targets)
      end
    else
      Logger.warn(string.format("Unknown target filtering function: %s", filterName))
    end
  end

  return strikeTargets
end

---Process fixed targets using BDA assessment
---@param saveData SBJ__SaveData Persistent save data containing target list
---@param targetConfig SBJ__TargetTemplate Target configuration with objs, contactAge, minTargetCount
---@param isFirstWave boolean Whether this is the first wave
---@return string[] # Array of target GUIDs that passed BDA assessment
local function processFixedTargets(saveData, targetConfig, isFirstWave)
  if not targetConfig.objs then
    return {}
  end

  local filteredTargets = TargetingProcess.filterTargetsByTypeAndBase(
    saveData.c.targetlist,
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
  return assessTargetsDamage(task, isFirstWave) or {}
end

-- ============================================================================
-- Public API
-- ============================================================================

---Process targets by routing to dynamic or fixed target processing
---@param config SBJ__Config Global configuration table
---@param saveData SBJ__SaveData Persistent save data
---@param contacts CMO__Contact[] Available sensor contacts
---@param targetConfig SBJ__TargetTemplate Target configuration (from taskTemplate.target or packageData.target)
---@param isFirstWave boolean Whether this is the first wave
---@return string[] # Array of target GUIDs
function TargetingProcess.processTargets(config, saveData, contacts, targetConfig, isFirstWave)
  if not targetConfig then
    return {}
  end

  if type(targetConfig.filterNames) == "table" and #targetConfig.filterNames > 0 then
    return processDynamicTargets(config, saveData, contacts, targetConfig)
  end

  return processFixedTargets(saveData, targetConfig, isFirstWave)
end

return TargetingProcess
