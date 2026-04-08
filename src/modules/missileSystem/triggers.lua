local GameApi = require("src.utils.gameApi")
local Logger = require("src.utils.logger")
local constants = require("src.core.constants")
local GameUtils = require("src.utils.gameUtils")

local Triggers = {}

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
local function buildEventAndTriggerNames(sideName, positionTypes)
  local eventNames = {}
  for _, posType in ipairs(positionTypes) do
    table.insert(eventNames, string.format("(%s) Arrive in %s", sideName, posType))
  end
  return eventNames
end

---Check whether candidate area matches expected RP area
---@param candidate CMO__Zone|CMO__TriggerResult|nil Zone or trigger object containing an area field
---@param expectedArea string[]|nil Expected reference point names to compare against
---@return boolean # True if candidate area matches expected area
local function hasSameArea(candidate, expectedArea)
  return candidate ~= nil
      and expectedArea ~= nil
      and GameUtils.isSameRPArray(GameUtils.convertToRPArray(candidate), expectedArea)
end

---Collect zones whose areas match any position or mask area
---@param operationalAreasToRemove SBJ__OperationalArea[] Operational areas providing position and mask areas to match
---@param posTypes string[] Position type keys used to look up positions in each operational area
---@param zoneEntries { guid: string, name: string, description: string }[] Available zone entry descriptors to inspect
---@param getZone fun(description: string): CMO__Zone|nil Function used to resolve a zone object from its description
---@return CMO__Zone[] # Zones matched for removal
local function collectZonesToRemove(operationalAreasToRemove, posTypes, zoneEntries, getZone)
  local zonesToRemove = {}

  for _, operationalAreaToRemove in ipairs(operationalAreasToRemove) do
    for _, posType in ipairs(posTypes) do
      for _, position in ipairs(operationalAreaToRemove[posType] or {}) do
        ---@cast position SBJ__Position
        for _, z in ipairs(zoneEntries) do
          local zone = getZone(z.description)

          if hasSameArea(zone, position.area) then
            table.insert(zonesToRemove, zone)
          end
        end
      end
    end

    if operationalAreaToRemove.mask and operationalAreaToRemove.mask.area then
      for _, z in ipairs(zoneEntries) do
        local zone = getZone(z.description)

        if hasSameArea(zone, operationalAreaToRemove.mask.area) then
          table.insert(zonesToRemove, zone)
        end
      end
    end
  end

  return zonesToRemove
end

---Collect triggers whose areas match any position area
---@param event CMO__Event Event object containing triggers to inspect
---@param operationalAreasToRemove SBJ__OperationalArea[] Operational areas providing reference position areas
---@param posTypes string[] Position type keys used to look up positions in each operational area
---@param triggerType string Trigger type key to inspect on each event trigger
---@return table[] # Triggers matched for removal
local function collectTriggersToRemove(event, operationalAreasToRemove, posTypes, triggerType)
  local triggersToRemove = {}

  for _, operationalAreaToRemove in ipairs(operationalAreasToRemove) do
    for _, posType in ipairs(posTypes) do
      for _, position in ipairs(operationalAreaToRemove[posType] or {}) do
        ---@cast position SBJ__Position
        for _, trigger in ipairs(event.triggers) do
          if trigger[triggerType] and trigger[triggerType].Area then
            if hasSameArea(trigger[triggerType], position.area) then
              table.insert(triggersToRemove, trigger)
            end
          end
        end
      end
    end
  end

  return triggersToRemove
end

---Remove zones matching specified operational area position keys
---@param posTypes string[] Position type keys used to locate areas within operational areas
---@param operationalAreasToRemove SBJ__OperationalArea[] Operational areas whose position and mask areas should be removed
---@param zoneType integer Zone type to remove (`STANDARD` or `CUSTOM_ENVIRONMENT`)
---@param sideName string Side name used to resolve or delete side-owned zones
---@return integer # Number of zones successfully removed
---@return boolean # True if all removals succeeded, false if any removal failed
local function removeZones(posTypes, operationalAreasToRemove, zoneType, sideName)
  local removedCount = 0
  local allSuccessful = true

  if zoneType == constants.ZONE_TYPES.STANDARD then
    local sideObj = GameApi.VP_GetSide({ side = sideName })

    if not sideObj then
      return 0, false
    end

    local zonesToRemove = collectZonesToRemove(
      operationalAreasToRemove,
      posTypes,
      sideObj.standardzones or {},
      function(description)
        return sideObj:getstandardzone(description)
      end
    )

    for _, zone in ipairs(zonesToRemove) do
      local rpsRemoved = GameUtils.removeRPs(zone, sideName)
      local zoneRemoved = GameApi.ScenEdit_RemoveZone(sideName, constants.ZONE_TYPES.STANDARD, {
        description = zone.description
      })

      if rpsRemoved and zoneRemoved then
        removedCount = removedCount + 1
      else
        allSuccessful = false
      end
    end
  elseif zoneType == constants.ZONE_TYPES.CUSTOM_ENVIRONMENT then
    local natureSideName = "Nature"
    local natureSideObj = GameApi.VP_GetSide({ side = natureSideName })

    if not natureSideObj then
      return 0, false
    end

    local zonesToRemove = collectZonesToRemove(
      operationalAreasToRemove,
      posTypes,
      natureSideObj.customenvironmentzones or {},
      function(description)
        return natureSideObj:getcustomenvironmentzone(description)
      end
    )

    for _, zone in ipairs(zonesToRemove) do
      local rpsRemoved = GameUtils.removeRPs(zone, natureSideName)
      local zoneRemoved = GameApi.ScenEdit_RemoveZone(natureSideName, constants.ZONE_TYPES.CUSTOM_ENVIRONMENT, {
        description = zone.description
      })

      if rpsRemoved and zoneRemoved then
        removedCount = removedCount + 1
      else
        allSuccessful = false
      end
    end
  end

  return removedCount, allSuccessful
end

---Remove event triggers whose areas match specified operational area position keys
---@param eventNames string[] Array of event names to search for triggers
---@param posTypes string[] Position type keys used to locate areas within operational areas
---@param operationalAreasToRemove SBJ__OperationalArea[] Operational areas whose position areas should be removed
---@param triggerType string Trigger type key to filter by (for example `UnitEntersArea`)
---@return integer # Total number of triggers successfully removed
---@return boolean # True if all removals succeeded, false if any removal failed
local function removeEventTriggers(eventNames, posTypes, operationalAreasToRemove, triggerType)
  local removedCount = 0
  local allSuccessful = true

  for _, eventName in ipairs(eventNames) do
    local event = GameApi.ScenEdit_GetEvent(eventName)

    if not event then
      allSuccessful = false
    else
      local triggersToRemove = collectTriggersToRemove(event, operationalAreasToRemove, posTypes, triggerType)

      for _, trigger in ipairs(triggersToRemove) do
        local triggerDesc = trigger[triggerType].Description

        local eventTriggerResult = GameApi.ScenEdit_SetEventTrigger(eventName, {
          mode = "remove",
          description = triggerDesc,
          name = eventName
        })

        local triggerResult = GameApi.ScenEdit_SetTrigger({
          Description = triggerDesc,
          Mode = "remove"
        })

        if eventTriggerResult and triggerResult then
          removedCount = removedCount + 1
        else
          allSuccessful = false
        end
      end
    end
  end

  return removedCount, allSuccessful
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
---@param operationalAreasToRemove SBJ__OperationalArea[] Operational areas to remove triggers for
---@param sideName string Side name for cleanup operations
---@return integer removedTriggerCount Number of removed triggers
---@return boolean triggerCleanupSuccessful Whether trigger cleanup fully succeeded
---@return integer removedZoneCount Number of removed zones
---@return boolean zoneCleanupSuccessful Whether zone cleanup fully succeeded
local function cleanupExistingTriggersAndZones(posTypes, operationalAreasToRemove, sideName)
  local eventNames = buildEventAndTriggerNames(sideName, posTypes)
  local removedTriggerCount, triggerCleanupSuccessful =
      removeEventTriggers(eventNames, posTypes, operationalAreasToRemove, "UnitEntersArea")
  local removedZoneCount, zoneCleanupSuccessful = removeZones(posTypes, operationalAreasToRemove,
    constants.ZONE_TYPES.STANDARD, sideName)

  return removedTriggerCount, triggerCleanupSuccessful, removedZoneCount, zoneCleanupSuccessful
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
---@param operationalAreasToRemove SBJ__OperationalArea[] Operational areas to remove triggers for
---@param positionTypes string[] Position type identifiers (RL/HA/AHA/FP)
---@param sideName string Side name for zone/trigger ownership
function Triggers.initEventTriggers(operationalAreas, operationalAreasToRemove, positionTypes, sideName)
  local sideCfg = GameUtils.getCachedSideConfig(sideName)

  local removedTriggerCount, triggerCleanupSuccessful, removedZoneCount, zoneCleanupSuccessful =
      cleanupExistingTriggersAndZones(positionTypes, operationalAreasToRemove, sideName)

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
    "Cleanup for %s missile system: removed %d triggers (allSuccessful: %s), removed %d zones (allSuccessful: %s)",
    sideName,
    removedTriggerCount,
    tostring(triggerCleanupSuccessful),
    removedZoneCount,
    tostring(zoneCleanupSuccessful)
  ))

  Logger.log(constants.TAGS.MISSILE_SYSTEM, string.format(
    "Initialized %s missile system: %d/%d triggers created, %d/%d mask zones created",
    sideName, totalCreated, totalCreated + totalFailed,
    maskCreated, maskCreated + maskFailed
  ))

  if #allFailMessages > 0 then
    Logger.error(constants.TAGS.MISSILE_SYSTEM ..
      ": Trigger/zone creation failures:\n" .. table.concat(allFailMessages, "\n"))
  end
end

return Triggers
