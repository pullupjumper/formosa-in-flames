local GameApi = require("src.utils.gameApi")
local Utils = require("src.utils.utils")
local Logger = require("src.utils.logger")
local Recon = require("src.modules.strikePlanner.recon")
local constants = require("src.core.constants")

local TargetingProcess = {}

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
  -- Check runway and taxiway patterns
  if string.match(description, patterns.runwayPattern) or
      string.find(description, patterns.taxiwayPattern) then
    for baseName, location in pairs(baseLocations) do
      if isNearby(location, guid, threshold) then
        return {
          name = baseName .. '/' .. description,
          guid = guid,
          category = 'Airfield',
          subType = description,
        }
      end
    end
  end

  -- Check shelter, hangar, tarmac, and helipad patterns
  if string.find(description, patterns.shelterPattern) or
      string.find(description, patterns.hangarPattern) or
      string.find(description, patterns.tarmacPattern) or
      string.find(description, patterns.helipadPattern) then
    for baseName, location in pairs(baseLocations) do
      if isNearby(location, guid, threshold) then
        return {
          name = baseName .. '/' .. description,
          guid = guid,
          category = 'Airfield',
          subType = description,
        }
      end
    end
  end

  -- Check ammo bunker and revetment patterns
  if string.find(description, patterns.ammoBunkerPattern) or
      string.find(description, patterns.ammoRevetmentPattern) then
    for baseName, location in pairs(baseLocations) do
      if isNearby(location, guid, threshold) then
        return {
          name = baseName .. '/' .. description,
          guid = guid,
          category = 'Airfield',
          subType = description,
        }
      end
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
          name = portName .. '/' .. description,
          guid = guid,
          category = 'Port',
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
  if string.find(description, patterns.radar.radarPattern) then
    return {
      name = description,
      guid = guid,
      category = 'ISR',
      subType = description,
    }
  end

  if string.find(description, patterns.sam.skyBowPattern) then
    return {
      name = description,
      guid = guid,
      category = 'SAM',
      subType = description,
    }
  end

  if string.find(description, patterns.asm.asmPattern) then
    return {
      name = description,
      guid = guid,
      category = 'ASM',
      subType = description,
    }
  end

  if string.find(description, patterns.c2.hengshanPattern) then
    return {
      name = description,
      guid = guid,
      category = 'C2',
      subType = description,
    }
  end

  return nil
end

---Scan and categorize contacts into a target list
---Performs single-pass scanning of contacts to identify and categorize targets
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
  Logger.log("targetingProcess", string.format("Scanned %d targets for %s", #targetlist, sideName))
end

---Find infantry units within specified areas
---Filters contacts to identify ground infantry units (typed == 8) in target areas
---@param opts SBJ__FilterParams Filter parameters containing contacts and task information
---@return string[] # Array of infantry unit GUIDs found in target areas
function TargetingProcess.findInfantry(opts)
  local contacts = opts.contacts
  local task = opts.task
  local targets = {}

  for _, area in ipairs(task.target.areas) do
    for _, contact in ipairs(contacts) do
      if contact.typed == 8 and contact:inArea(area) then
        contact.posture = 3
        table.insert(targets, contact.guid)
      end
    end
  end

  return targets
end

---Find airborne early warning aircraft (P-3C, E-2K) within specified areas
---Identifies aircraft contacts with specific radar emissions (SEAVUE or APS-145)
---@param opts SBJ__FilterParams Filter parameters with contacts, task, and config
---@return string[] # Array of airborne early warning aircraft GUIDs
function TargetingProcess.findAirborne(opts)
  local contacts = opts.contacts
  local task = opts.task
  local config = opts.config
  local targets = {}

  for _, area in ipairs(task.target.areas) do
    for _, contact in ipairs(contacts) do
      if contact.emissions and contact.emissions[1] then
        local emission = contact.emissions[1]['sensor_dbid']
        if (emission == constants.SENSORS.P3C_SEAVUE or emission == constants.SENSORS.E2K_APS145) and
            contact.typed == 0 and
            contact:inArea(area) then
          table.insert(targets, contact.guid)
        end
      end
    end
  end

  return targets
end

---Analyze radar emissions to identify SAM systems
---Detects Taiwanese SAM radar emissions (TK-3, TK-2, PAC-3, TC-2) within contact age limit
---@param opts SBJ__FilterParams Filter parameters with contacts, task, and sensor configuration
---@return string[] # Array of SAM system GUIDs with active radar emissions
function TargetingProcess.analyzeEmissions(opts)
  local contacts = opts.contacts
  local task = opts.task
  local config = opts.config
  local SAMTargets = {}

  for _, area in ipairs(task.target.areas) do
    for _, contact in ipairs(contacts) do
      local isSensor = contact.emissions and
          (contact.emissions[1]['sensor_dbid'] == constants.SENSORS.TK3_LONG_MOUNTAIN or
            contact.emissions[1]['sensor_dbid'] == constants.SENSORS.TK3_LONG_WHITE_2 or
            contact.emissions[1]['sensor_dbid'] == constants.SENSORS.TK2_CS_MPG25 or
            contact.emissions[1]['sensor_dbid'] == constants.SENSORS.PAC3_MPQ65 or
            contact.emissions[1]['sensor_dbid'] == constants.SENSORS.TC2_CS_MPQ90)
      local isAgeLessThan = contact.lastDetections and contact.lastDetections[1].age <= task.target.contactAge
      local isSAM = isSensor and isAgeLessThan
      if contact:inArea(area) and isSAM then table.insert(SAMTargets, contact.guid) end
    end
  end

  return SAMTargets
end

---Check if target is within range of a radio transmission source
---Validates distance to radio source and transmission strength
---@param config SBJ__Config Global configuration with SIGINT range and count thresholds
---@param distance number Distance in nautical miles to radio source
---@param transmission SBJ__RadioTransmissionContext Transmission data with current detection level (count) and other properties
---@return boolean # true if target is within max range and transmission exceeds count threshold
local function isWithinRange(config, distance, transmission)
  return distance <= config.c.SIGINT.maxRange and transmission.currentDetectionLevel > config.c.SIGINT.maxCount
end

---Find mobile ground targets (vehicles) within specified areas
---Identifies ground mobile units (typed == 8) in target areas
---@param opts SBJ__FilterParams Filter parameters containing contacts and task information
---@return string[] # Array of mobile ground unit GUIDs
function TargetingProcess.findMobileTargets(opts)
  local contacts = opts.contacts
  local task = opts.task
  local targets = {}

  for _, area in ipairs(task.target.areas) do
    for _, contact in ipairs(contacts) do
      if (contact.typed == 8) and contact:inArea(area) then
        contact.posture = 3
        table.insert(targets, contact.guid)
      end
    end
  end

  return targets
end

---Filter targets that are within range of SIGINT-detected radio sources
---Cross-references contacts with SIGINT transmissions, triggers reconnaissance for mobile sources
---@param config SBJ__Config Global configuration with SIGINT parameters and platform definitions
---@param saveData SBJ__SaveData Persistent save data containing SIGINT transmission records
---@param contacts string[] Array of contact GUIDs to evaluate
---@return string[]|nil # Array of contact GUIDs near radio sources, or nil if no aircraft available
local function filterTargetsWithinRangeOfRadioSource(config, saveData, contacts)
  local targets = {}
  local isTracking = false
  local filteredUnits = GameApi.VP_GetSide({ side = 'China' }):unitsBy(constants.UNIT_TYPES.AIRCRAFT)

  if not filteredUnits then
    return
  end

  for _, guid in ipairs(contacts) do
    local contact = GameApi.ScenEdit_GetContact('China', guid)

    if contact then
      for _, tm in pairs(saveData.c.SIGINT.transmissions) do
        local distance = GameApi.Tool_Range({ latitude = tm.latitude, longitude = tm.longitude }, guid)

        if distance and isWithinRange(config, distance, tm) then
          table.insert(targets, guid)

          if not isTracking and tm.type == 'mobile' then
            isTracking = Recon.trackTarget(saveData.c.recon, filteredUnits, constants.PLATFORMS.BZK005, contact)
          end
        end
      end
    end
  end

  return targets
end

---Find targets by radio direction (SIGINT-based targeting)
---Combines mobile targets and C2 units, filters by proximity to radio transmissions
---@param opts SBJ__FilterParams Filter parameters with contacts, task, config, and saveData
---@return string[]|nil # Array of target GUIDs near radio sources, or nil if unavailable
function TargetingProcess.findRadioDirection(opts)
  local contacts = opts.contacts
  local saveData = opts.saveData
  local task = opts.task
  local config = opts.config
  local targets = {}
  local mobileTargets = TargetingProcess.findMobileTargets({ contacts = contacts, task = task })
  local c2Targets = TargetingProcess.findC2({ contacts = contacts, task = task })
  Utils.insertList(targets, mobileTargets)
  Utils.insertList(targets, c2Targets)
  local radioSource = filterTargetsWithinRangeOfRadioSource(config, saveData, targets)
  return radioSource
end

---Find naval targets (ships) within specified areas
---Identifies naval contacts within contact age limit, triggers WZ-8 reconnaissance tracking
---@param opts SBJ__FilterParams Filter parameters with contacts, task, config, saveData, and optional shouldTrack flag
---@return string[]|nil # Array of naval target GUIDs, or nil if no reconnaissance aircraft available
function TargetingProcess.findNavalTargets(opts)
  local shouldTrack = opts.shouldTrack or false
  local contacts = opts.contacts
  local saveData = opts.saveData
  local task = opts.task
  local config = opts.config
  local navalTargets = {}
  local hasTracked = false
  local filteredUnits = GameApi.VP_GetSide({ side = 'China' }):unitsBy(constants.UNIT_TYPES.AIRCRAFT)

  if not filteredUnits then
    return
  end

  for _, area in ipairs(task.target.areas) do
    for _, contact in ipairs(contacts) do
      if contact.typed == 2 and
          contact:inArea(area) and
          contact.lastDetections and
          contact.lastDetections[1].age <= task.target.contactAge then
        table.insert(navalTargets, contact.guid)

        if not hasTracked then
          hasTracked = Recon.trackTarget(saveData.c.recon, filteredUnits, constants.PLATFORMS.WZ8, contact)
          Logger.log("recon", "hasTracked: " .. tostring(hasTracked))
        end
      end
    end
  end

  return navalTargets
end

---Find Command and Control (C2) facilities
---Identifies ROCC and TAAOC command centers within target areas
---@param opts SBJ__FilterParams Filter parameters containing contacts and task information
---@return string[] # Array of C2 facility GUIDs (ROCC/TAAOC)
function TargetingProcess.findC2(opts)
  local contacts = opts.contacts
  local task = opts.task
  local targets = {}

  for _, area in ipairs(task.target.areas) do
    for _, contact in ipairs(contacts) do
      if (string.find(contact.type_description, 'ROCC') ~= nil or
            string.find(contact.type_description, 'TAAOC') ~= nil) and
          contact:inArea(area) then
        table.insert(targets, contact.guid)
      end
    end
  end

  return targets
end

---Evaluate if a target is valid for strike based on damage and detection status
---Checks BDA (Battle Damage Assessment), contact age, and special helipad conditions
---@param target CMO__Contact Contact object to evaluate
---@param contactAge number Maximum acceptable contact age in seconds
---@param isFirstWave boolean If true, accepts all targets; if false, applies BDA filtering
---@return boolean # true if target is valid for strike (not heavily damaged, recent detection, or first wave)
function TargetingProcess.evaluateTarget(target, contactAge, isFirstWave)
  local actualUnit = GameApi.ScenEdit_GetUnit(target.actualunitid)

  if not actualUnit then
    return false
  end

  local isHelipad = string.find(target.type_description, 'Helipad') ~= nil
  local BDA = target.BDA
  local detections = target.lastDetections
  local hasEvaluated = BDA and not (BDA['STRUCTURAL'] == 'Heavy damage') and
      (detections and detections[1].age <= contactAge) and
      not isHelipad
  local isHelipadEmbarkedWithHelicopter = isHelipad and #actualUnit.embarkedUnits['Aircraft'] > 0
  return hasEvaluated or isHelipadEmbarkedWithHelicopter or isFirstWave
end

---Assess target damage status (Battle Damage Assessment)
---Filters target list based on BDA, excluding heavily damaged targets (unless first wave)
---@param task SBJ__Task Task containing target list and contact age parameters
---@param isFirstWave boolean If true, includes all targets; if false, filters by damage status
---@return string[] # Array of target GUIDs that passed BDA evaluation
function TargetingProcess.assessTargetsDamage(task, isFirstWave)
  local evaluatedTargetlist = {}

  if type(task.target.list) ~= 'table' or #task.target.list == 0 then
    return evaluatedTargetlist
  end

  for _, guid in ipairs(task.target.list) do
    local actualTarget = GameApi.ScenEdit_GetContact('China', guid)

    if actualTarget and TargetingProcess.evaluateTarget(actualTarget, task.target.contactAge, isFirstWave) then
      table.insert(evaluatedTargetlist, actualTarget.guid)
    end
  end

  return evaluatedTargetlist
end

---Filter targets by type and base name
---Filters target list based on base name pattern and facility sub-types
---@param targetlist string[] Array of target objects with name, subType, and guid properties
---@param queryParams SBJ__TargetQueryParam[] Array of query parameters with baseName (optional) and subTypes (array)
---@return string[] # Array of target GUIDs matching query criteria
function TargetingProcess.filterTargetsByTypeAndBase(targetlist, queryParams)
  local selectedTargetlist = {}

  for _, item in ipairs(targetlist) do
    for _, param in ipairs(queryParams) do
      local isNameMatched = false
      local isSubTypeMatched = false

      if not param.baseName then
        isNameMatched = true
      end

      if param.baseName then
        if string.find(item.name, param.baseName) ~= nil then
          isNameMatched = true
        end
      end

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

return TargetingProcess
