local GameApi = require("src.utils.gameApi")

---Own the rule for units that landingOps tracks and that are destroyed: remove the GUID from every record of the zone.
---The kill event calls remove. Each poll looks units up through findUnit, so a unit that the event missed
---is removed at the first failed lookup and is not looked up again.
local TrackedUnits = {}

---Remove a GUID from every key-indexed record
---@param unitMaps table<string, any>[]
---@param guid string
---@return boolean # True if a record held the GUID
local function removeFromMaps(unitMaps, guid)
  local isRemoved = false
  for _, unitMap in ipairs(unitMaps) do
    if unitMap[guid] then
      unitMap[guid] = nil
      isRemoved = true
    end
  end
  return isRemoved
end

---Remove a GUID from the launched ACVs of every type
---@param acvGuidMap table<string, string[]>
---@param guid string
---@return boolean # True if an ACV list held the GUID
local function removeACV(acvGuidMap, guid)
  for _, guids in pairs(acvGuidMap) do
    for i = #guids, 1, -1 do
      if guids[i] == guid then
        table.remove(guids, i)
        return true
      end
    end
  end
  return false
end

---Free every parking slot that a GUID holds. Write false, not nil, to keep each slot table a dense array
---@param laneSlots SBJ__LaneSlotsState
---@param guid string
---@return boolean # True if the GUID held a slot
local function removeSlotHolder(laneSlots, guid)
  local isRemoved = false
  for _, slotMap in pairs(laneSlots) do
    for slot, holder in ipairs(slotMap) do
      if holder == guid then
        slotMap[slot] = false
        isRemoved = true
      end
    end
  end
  return isRemoved
end

---Remove a destroyed unit from every record of the zone. One unit can sit in two records,
---for example an assault boat and the parking slot it holds
---@param zoneState SBJ__ZoneState
---@param guid string
---@return boolean # True if a record held the unit and it is now removed
function TrackedUnits.remove(zoneState, guid)
  local heliWave = zoneState.heliWave or {}
  local isMapRemoved = removeFromMaps({
    zoneState.boats or {},
    zoneState.hovercraft or {},
    zoneState.minesweepers or {},
    heliWave.units or {},
    heliWave.attackers or {},
    heliWave.airlift and heliWave.airlift.units or {},
  }, guid)
  local isACVRemoved = removeACV(zoneState.acvGuids or {}, guid)
  local isSlotRemoved = removeSlotHolder(zoneState.laneSlots or {}, guid)
  return isMapRemoved or isACVRemoved or isSlotRemoved
end

---Remove a tracked unit from every record of the zone when it is no longer found
---@param zoneState SBJ__ZoneState
---@param guid string
---@return boolean # True if the unit is no longer found and is now removed
function TrackedUnits.removeMissing(zoneState, guid)
  return TrackedUnits.findUnit(zoneState, guid) == nil
end

---Find a tracked unit. A unit that is no longer found is removed from every record of the zone
---@param zoneState SBJ__ZoneState
---@param guid string
---@return CMO__Unit|nil # nil when the unit is no longer found
function TrackedUnits.findUnit(zoneState, guid)
  local unit = GameApi.ScenEdit_GetUnit(guid)
  if not unit then
    TrackedUnits.remove(zoneState, guid)
  end
  return unit
end

return TrackedUnits
