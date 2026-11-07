local GameApi = require("src.utils.gameApi")
local LogFormat = require("src.utils.logFormat")
local constants = require("src.core.constants")
local GameUtils = require("src.utils.gameUtils")
local Triggers = require("src.modules.missileSystem.triggers")
local Concealment = require("src.modules.missileSystem.concealment")

local PositionZones = {}

local ZONE_COLORS = {
  [constants.POSITION_TYPES.RELOAD_POINT] = "4dd9822b",
  [constants.POSITION_TYPES.HIDE_AREA] = "4d137cbd",
  [constants.POSITION_TYPES.AMMUNITION_TRANSFER_POINT] = "4d0f9960",
  [constants.POSITION_TYPES.MASK] = "4dff6b6b",
}
local DEFAULT_ZONE_COLOR = "4d8b5cf6"

---Collect the names of every zone and arrival trigger built for the given areas
---@param operationalAreas SBJ__OperationalArea[]
---@param positionTypes string[]
---@param sideName string
---@return table<string, true> zoneNames
---@return table<string, table<string, true>> triggerNamesByEvent Trigger names keyed by event name
local function buildNames(operationalAreas, positionTypes, sideName)
  local zoneNames, triggerNamesByEvent = {}, {}

  for _, positionType in ipairs(positionTypes) do
    triggerNamesByEvent[Triggers.formatEventName(sideName, positionType)] = {}
  end

  for _, operationalArea in ipairs(operationalAreas) do
    zoneNames[Triggers.formatMaskZoneName(operationalArea.name)] = true

    for _, positionType in ipairs(positionTypes) do
      local triggerNames = triggerNamesByEvent[Triggers.formatEventName(sideName, positionType)]
      for index in ipairs(operationalArea[positionType] or {}) do
        zoneNames[Triggers.formatZoneName(positionType, index, operationalArea.name)] = true
        triggerNames[Triggers.formatTriggerName(sideName, positionType, index, operationalArea.name)] = true
      end
    end
  end

  return zoneNames, triggerNamesByEvent
end

---Remove the side's standard zones whose names are listed, with their reference points
---@param zoneNames table<string, true>
---@param sideName string
---@return integer removedCount
---@return boolean allSuccessful
local function removeZones(zoneNames, sideName)
  local removedCount = 0
  local allSuccessful = true
  local side = GameApi.VP_GetSide({ side = sideName })

  for _, entry in ipairs(side.standardzones or {}) do
    if zoneNames[entry.description] then
      local zone = side:getstandardzone(entry.description)
      local rpsRemoved = zone ~= nil and GameUtils.removeRPs(sideName, zone)
      local zoneRemoved = GameApi.ScenEdit_RemoveZone(sideName, constants.ZONE_TYPES.STANDARD,
        { description = entry.description })

      if rpsRemoved and zoneRemoved then
        removedCount = removedCount + 1
      else
        allSuccessful = false
      end
    end
  end

  return removedCount, allSuccessful
end

---Remove the listed unit-enters-area triggers from their events
---@param triggerNamesByEvent table<string, table<string, true>>
---@return integer removedCount
---@return boolean allSuccessful False when an event is missing or a removal fails
local function removeEventTriggers(triggerNamesByEvent)
  local removedCount = 0
  local allSuccessful = true

  for eventName, triggerNames in pairs(triggerNamesByEvent) do
    local event = GameApi.ScenEdit_GetEvent(eventName)

    if not event then
      allSuccessful = false
    else
      for _, trigger in ipairs(event.triggers) do
        local description = trigger.UnitEntersArea and trigger.UnitEntersArea.Description
        if description and triggerNames[description] then
          local eventTriggerResult = GameApi.ScenEdit_SetEventTrigger(eventName, {
            mode = "remove",
            description = description,
            name = eventName
          })
          local triggerResult = GameApi.ScenEdit_SetTrigger({ Description = description, Mode = "remove" })

          if eventTriggerResult and triggerResult then
            removedCount = removedCount + 1
          else
            allSuccessful = false
          end
        end
      end
    end
  end

  return removedCount, allSuccessful
end

---Add a position's zone and its unit-enters-area trigger
---@param params SBJ__AddTriggerParams
---@return boolean success Whether trigger was successfully added
---@return string? reason Failure reason if trigger creation failed
local function addPositionTrigger(params)
  local zone = GameApi.ScenEdit_AddZone(params.sideName, constants.ZONE_TYPES.STANDARD, {
    area = params.position.area,
    description = Triggers.formatZoneName(params.positionType, params.index, params.operationalArea.name)
  })

  if not zone then
    return false, "add_zone_failed"
  end

  local triggerName = Triggers.formatTriggerName(
    params.sideName,
    params.positionType,
    params.index,
    params.operationalArea.name
  )
  zone.areacolor = ZONE_COLORS[params.positionType] or DEFAULT_ZONE_COLOR
  params.position.area = GameUtils.normalizeToRPArray(zone)
  local triggerResult = GameApi.ScenEdit_SetTrigger({
    Description = triggerName,
    Mode = "add",
    type = "UnitEntersArea",
    TargetFilter = { TargetSide = params.sideName },
    Area = params.position.area,
    ExitArea = false
  })
  local eventTriggerResult = GameApi.ScenEdit_SetEventTrigger(
    Triggers.formatEventName(params.sideName, params.positionType),
    { mode = "add", name = triggerName }
  )

  if triggerResult and eventTriggerResult then
    return true, nil
  end
  if not triggerResult and not eventTriggerResult then
    return false, "set_trigger_and_event_trigger_failed"
  end
  if not triggerResult then
    return false, "set_trigger_failed"
  end
  return false, "set_event_trigger_failed"
end

---Add the mask zone built from the area's U-shape and store its reference points as the area's mask
---@param sideName string
---@param operationalArea SBJ__OperationalArea
---@return boolean # Whether the zone was created
local function addMaskZone(sideName, operationalArea)
  local zone = GameApi.ScenEdit_AddZone(sideName, constants.ZONE_TYPES.STANDARD, {
    description = Triggers.formatMaskZoneName(operationalArea.name),
    area = operationalArea.uShapeVertices,
  })

  if not zone then return false end

  operationalArea.mask = { area = GameUtils.normalizeToRPArray(zone) }
  zone.areacolor = ZONE_COLORS[constants.POSITION_TYPES.MASK]
  return true
end

---Add every position trigger of an operational area
---@param operationalArea SBJ__OperationalArea
---@param positionTypes string[]
---@param sideName string
---@return integer created Number of triggers created
---@return integer failed Number of triggers failed
---@return SBJ__LogResult[] failResults Failure detail rows
local function addPositionTriggers(operationalArea, positionTypes, sideName)
  local created, failed = 0, 0
  local failMessages = {}

  for _, positionType in ipairs(positionTypes) do
    for index, position in ipairs(operationalArea[positionType]) do
      ---@cast position SBJ__Position
      local success, reason = addPositionTrigger({
        positionType = positionType,
        position = position,
        index = index,
        operationalArea = operationalArea,
        sideName = sideName
      })
      if success then
        created = created + 1
      else
        failed = failed + 1
        table.insert(failMessages, {
          tag = "FAIL",
          fields = {
            area = operationalArea.name,
            kind = "trigger",
            position = positionType,
            index = index,
            reason = reason or "add_trigger_failed"
          }
        })
      end
    end
  end

  return created, failed, failMessages
end

---Parts built once per operational area besides its position triggers
local AREA_PARTS = {
  { kind = "mask", build = addMaskZone, reason = "add_zone_failed" },
  { kind = "bunker", build = Concealment.addBunkers, reason = "add_bunker_failed" },
}

---Remove the zones, triggers and bunkers of the areas being left, then build them for the new areas
---@param sideName string
---@param operationalAreas SBJ__OperationalArea[]
---@param operationalAreasToRemove SBJ__OperationalArea[]
---@param positionTypes string[]
function PositionZones.update(sideName, operationalAreas, operationalAreasToRemove, positionTypes)
  local zoneNames, triggerNamesByEvent = buildNames(operationalAreasToRemove, positionTypes, sideName)
  Concealment.removeBunkers(operationalAreasToRemove, sideName)
  local removedTriggerCount, triggerCleanupSuccessful = removeEventTriggers(triggerNamesByEvent)
  local removedZoneCount, zoneCleanupSuccessful = removeZones(zoneNames, sideName)

  local tally = { trigger = { created = 0, failed = 0 } }
  for _, part in ipairs(AREA_PARTS) do
    tally[part.kind] = { created = 0, failed = 0 }
  end
  local initLogEntries = {}

  for _, operationalArea in ipairs(operationalAreas) do
    local created, failed, failMessages = addPositionTriggers(operationalArea, positionTypes, sideName)
    tally.trigger.created = tally.trigger.created + created
    tally.trigger.failed = tally.trigger.failed + failed
    table.insert(initLogEntries, {
      tag = failed > 0 and "FAIL" or "OK",
      fields = { area = operationalArea.name, kind = "trigger", created = created, expected = created + failed }
    })
    for _, msg in ipairs(failMessages) do
      table.insert(initLogEntries, msg)
    end

    for _, part in ipairs(AREA_PARTS) do
      local count = tally[part.kind]
      if part.build(sideName, operationalArea) then
        count.created = count.created + 1
        table.insert(initLogEntries, {
          tag = "OK",
          fields = { area = operationalArea.name, kind = part.kind, created = 1, expected = 1 }
        })
      else
        count.failed = count.failed + 1
        table.insert(initLogEntries, {
          tag = "FAIL",
          fields = { area = operationalArea.name, kind = part.kind, created = 0, expected = 1, reason = part.reason }
        })
      end
    end
  end

  -- Both rows carry their own tag, so the report routes an incomplete cleanup to
  -- the error sink without a separate module-wide flag.
  local cleanupReport = LogFormat.report(
    constants.TAGS.MISSILE_SYSTEM,
    "side=" .. sideName,
    "Cleanup missile system triggers/zones"
  )
  cleanupReport.add(triggerCleanupSuccessful and "OK" or "FAIL", {
    kind = "trigger",
    removed = removedTriggerCount,
    reason = triggerCleanupSuccessful and "none" or "cleanup_incomplete"
  })
  cleanupReport.add(zoneCleanupSuccessful and "OK" or "FAIL", {
    kind = "zone",
    removed = removedZoneCount,
    reason = zoneCleanupSuccessful and "none" or "cleanup_incomplete"
  })
  cleanupReport.emit()

  local summary = {}
  for kind, count in pairs(tally) do
    summary[kind .. "s"] = count.created .. "/" .. (count.created + count.failed)
  end
  local initReport = LogFormat.report(constants.TAGS.MISSILE_SYSTEM, "side=" .. sideName, "Initialize missile system")
  initReport.addAll(initLogEntries)
  initReport.emit(summary)
end

return PositionZones
