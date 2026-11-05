local constants = require("src.core.constants")

---Names of the zones and arrival triggers built for an operational area.
---Redeploy finds what to remove by these names, so the scenario's own zones must follow them too.
local Triggers = {}

---Position types whose triggers drive arrival handling
local ARRIVAL_POSITION_TYPES = {
  [constants.POSITION_TYPES.FIRING_POINT] = true,
  [constants.POSITION_TYPES.HIDE_AREA] = true,
  [constants.POSITION_TYPES.RELOAD_POINT] = true,
  [constants.POSITION_TYPES.AMMO_HOLDING_AREA] = true,
}

---Build the CMO event name that collects a side's arrival triggers for one position type.
---Must match the event already defined in the scenario.
---@param sideName string
---@param positionType string
---@return string
function Triggers.formatEventName(sideName, positionType)
  return string.format("(%s) Arrive in %s", sideName, positionType)
end

---Build the description of one position's unit-enters-area trigger
---@param sideName string
---@param positionType string
---@param index integer
---@param areaName string
---@return string
function Triggers.formatTriggerName(sideName, positionType, index, areaName)
  return string.format("%s - %d - %s", Triggers.formatEventName(sideName, positionType), index, areaName)
end

---Build the description of one position's zone
---@param positionType string
---@param index integer
---@param areaName string
---@return string
function Triggers.formatZoneName(positionType, index, areaName)
  return string.format("%s/%d/%s", positionType, index, areaName)
end

---Build the description of an operational area's mask zone
---@param areaName string
---@return string
function Triggers.formatMaskZoneName(areaName)
  return constants.POSITION_TYPES.MASK .. "/" .. areaName
end

---Read the position type back from a trigger description built by formatTriggerName
---@param description string|nil
---@return string|nil # Position type token (FP/HA/RL/AHA), nil when not an arrival trigger
function Triggers.parsePositionType(description)
  local positionType = description and string.match(description, "Arrive in (%u+) ")
  if positionType and ARRIVAL_POSITION_TYPES[positionType] then
    return positionType
  end
  return nil
end

return Triggers
