local GameApi = require("src.utils.gameApi")
local Logger = require("src.utils.logger")
local constants = require("src.core.constants")
local GameUtils = require("src.utils.gameUtils")

local Triggers = {}

local ZONE_PATTERNS = {
  "^" .. constants.POSITION_TYPES.FIRING_POINT,
  "^" .. constants.POSITION_TYPES.HIDE_AREA,
  "^" .. constants.POSITION_TYPES.AMMO_HOLDING_AREA,
  "^" .. constants.POSITION_TYPES.RELOAD_POINT,
  "^" .. constants.POSITION_TYPES.MASK
}

local ZONE_COLORS = {
  RELOAD_POINT = "4dd9822b",
  HIDE_AREA = "4d137cbd",
  AMMO_HOLDING_AREA = "4d0f9960",
  MASK = "4dff6b6b",
  DEFAULT = "4d8b5cf6"
}

---Get area color code based on position type
---@param positionType string Position type identifier (RL/HA/AHA/MASK/FP)
---@return string # Hexadecimal color code
local function getOperationalAreaColor(positionType)
  local colorMap = {
    [constants.POSITION_TYPES.RELOAD_POINT] = ZONE_COLORS.RELOAD_POINT,
    [constants.POSITION_TYPES.HIDE_AREA] = ZONE_COLORS.HIDE_AREA,
    [constants.POSITION_TYPES.AMMO_HOLDING_AREA] = ZONE_COLORS.AMMO_HOLDING_AREA,
    [constants.POSITION_TYPES.MASK] = ZONE_COLORS.MASK,
  }

  return colorMap[positionType] or ZONE_COLORS.DEFAULT
end

---Build event names and trigger prefixes for a side
---@param sideName string Side name
---@param positionTypes string[] Position types
---@return string[] eventNames Array of event names
---@return string[] triggerPrefixes Array of trigger prefix strings
local function buildEventAndTriggerNames(sideName, positionTypes)
  local eventNames, triggerPrefixes = {}, {}
  for _, posType in ipairs(positionTypes) do
    table.insert(eventNames, string.format("(%s) Arrive in %s", sideName, posType))
    table.insert(triggerPrefixes, string.format("(%s)", posType))
  end
  return eventNames, triggerPrefixes
end

---Add a unit-enters-area trigger to the specified event
---@param opts SBJ__AddTriggerOpts Trigger creation options
---@return boolean # Whether trigger was successfully added
local function addTriggerToEvent(opts)
  local triggerName = string.format("(%s) Arrive in %s - %d - %s", opts.sideName, opts.positionType, opts.index,
    opts.operationalArea.name)
  local zoneName = opts.positionType .. "/" .. tostring(opts.index) .. "/" .. opts.operationalArea.name
  local zone = GameApi.ScenEdit_AddZone(opts.sideName, constants.ZONE_TYPES.STANDARD, {
    area = opts.position.area,
    description = zoneName
  })

  if zone then
    local eventName = string.format("(%s) Arrive in %s", opts.sideName, opts.positionType)
    zone.areacolor = getOperationalAreaColor(opts.positionType)
    opts.position.area = GameUtils.convertToRPArray(zone)
    GameApi.ScenEdit_SetTrigger({
      Description = triggerName,
      Mode = "add",
      type = "UnitEntersArea",
      TargetFilter = { TargetSide = opts.sideName },
      Area = opts.position.area,
      ExitArea = false
    })
    GameApi.ScenEdit_SetEventTrigger(eventName, { mode = "add", name = triggerName })
    return true
  end

  return false
end

---Clean up existing zones and event triggers for missile system
---@param posTypes string[] Position types to clean up
---@param sideName string Side name for cleanup operations
local function cleanupExistingTriggersAndZones(posTypes, sideName)
  GameUtils.removeZones(ZONE_PATTERNS, constants.ZONE_TYPES.STANDARD, sideName)
  GameUtils.removeZones(ZONE_PATTERNS, constants.ZONE_TYPES.CUSTOM_ENVIRONMENT, sideName)

  local eventNames, triggerPrefixes = buildEventAndTriggerNames(sideName, posTypes)
  GameUtils.removeEventTriggers(eventNames, triggerPrefixes, "UnitEntersArea")
end

---Add custom environment zone for terrain masking
---@param operationalArea SBJ__OperationalArea Operational area configuration
---@param sideName string Side name for zone ownership
---@return boolean # Whether zone was successfully created
local function addCustomEnvironmentZone(operationalArea, sideName)
  local zone = GameApi.ScenEdit_AddZone(sideName, constants.ZONE_TYPES.STANDARD, {
    description = constants.POSITION_TYPES.MASK .. "/" .. operationalArea.name,
    area = operationalArea.uShapeVertices,
    sideName = sideName
  })

  if zone then
    local rps = GameUtils.convertToRPArray(zone)
    operationalArea.mask = { area = rps }
    zone.areacolor = getOperationalAreaColor(constants.POSITION_TYPES.MASK)
    return true
  end
  return false
end

---Create position triggers for an operational area
---@param operationalArea SBJ__OperationalArea Operational area configuration
---@param positionTypes string[] Position types to create
---@param enemySide string Enemy side name
---@param sideName string Owner side name
---@return integer created Number of triggers created
---@return integer failed Number of triggers failed
---@return string[] failMessages Failure detail messages
local function createPositionTriggers(operationalArea, positionTypes, enemySide, sideName)
  local created, failed = 0, 0
  local failMessages = {}

  for _, positionType in ipairs(positionTypes) do
    for index, position in ipairs(operationalArea[positionType]) do
      ---@cast position SBJ__Position
      if addTriggerToEvent({
            positionType = positionType,
            position = position,
            index = index,
            operationalArea = operationalArea,
            enemySide = enemySide,
            sideName = sideName
          }) then
        created = created + 1
      else
        failed = failed + 1
        table.insert(failMessages, string.format("  [FAIL] Trigger %s-%d in %s",
          positionType, index, operationalArea.name))
      end
    end
  end

  return created, failed, failMessages
end

---Initialize event triggers and zones for missile system operational areas
---@param operationalAreas SBJ__OperationalArea[] Array of operational area configurations
---@param positionTypes string[] Position type identifiers (RL/HA/AHA/FP)
---@param sideName string Side name for zone/trigger ownership
function Triggers.initEventTriggers(operationalAreas, positionTypes, sideName)
  local sideCfg = GameUtils.getCachedSideConfig(sideName)

  cleanupExistingTriggersAndZones(positionTypes, sideName)

  local totalCreated, totalFailed, maskCreated, maskFailed = 0, 0, 0, 0
  local allFailMessages = {}

  for _, operationalArea in ipairs(operationalAreas) do
    local created, failed, failMessages = createPositionTriggers(
      operationalArea, positionTypes, sideCfg.enemySide, sideName)
    totalCreated = totalCreated + created
    totalFailed = totalFailed + failed
    for _, msg in ipairs(failMessages) do
      table.insert(allFailMessages, msg)
    end

    if addCustomEnvironmentZone(operationalArea, sideName) then
      maskCreated = maskCreated + 1
    else
      maskFailed = maskFailed + 1
      table.insert(allFailMessages,
        string.format("  [FAIL] MASK zone for %s", operationalArea.name))
    end
  end

  Logger.log(constants.TAGS.MISSILE_SYSTEM, string.format(
    "Initialized %s missile system: %d/%d triggers created, %d/%d mask zones created",
    sideName, totalCreated, totalCreated + totalFailed,
    maskCreated, maskCreated + maskFailed
  ))

  if #allFailMessages > 0 then
    Logger.error(constants.TAGS.MISSILE_SYSTEM .. ": Trigger/zone creation failures:\n" .. table.concat(allFailMessages, "\n"))
  end
end

return Triggers
