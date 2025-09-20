--- Integrated Air Defense System (IADS) module
--- Manages communication disruption and radar activation logic when C2 nodes are destroyed
local GameApi = require("src.utils.gameApi")
local Logger = require("src.utils.logger")

local IADS = {}

--- Sets units of specified type to out-of-communications state
--- @param saveData SBJ__SaveData Game save data table
--- @param side string Side abbreviation ('c' or 't')
--- @param C2Type string Command and control type ('C2', 'ROCC', 'TAAOC')
--- @param type string Unit type ('radar' or 'SAM')
--- @param C2 CMO__Unit Destroyed command and control node
local function setToOutOfComms(saveData, side, C2Type, type, C2)
  for _, data in pairs(saveData[side].IADS[C2Type][C2.guid][type]) do
    local actualUnit = GameApi.ScenEdit_GetUnit(data.guid)

    if actualUnit == nil then goto continue end
    GameApi.ScenEdit_SetUnit({ guid = data.guid, outofcomms = true })
    data.isOutOfComms = true

    ::continue::
  end
end

--- Gets corresponding data fields based on side name
--- @param side string Side name ('China' or other)
--- @return string _side Side abbreviation ('c' or 't')
--- @return string C2Type Command and control type ('C2' or 'ROCC')
local function getFieldBySide(side)
  local _side, C2Type

  if side == 'China' then
    _side = 'c'
    C2Type = 'C2'
  else
    _side = 't'
    C2Type = 'ROCC'
  end

  return _side, C2Type
end

--- Disrupts command and control communications
--- When a C2 node is destroyed, sets radars and SAMs under its control to out-of-comms state
--- @param saveData SBJ__SaveData Game save data table
--- @param side string Side name
--- @param C2 CMO__Unit Destroyed command and control node
function IADS.disruptC2Communications(saveData, side, C2)
  local _side, C2Type = getFieldBySide(side)

  -- Handle main command and control node
  if saveData[_side].IADS[C2Type][C2.guid] then
    setToOutOfComms(saveData, _side, C2Type, 'radar', C2)
    setToOutOfComms(saveData, _side, C2Type, 'SAM', C2)
    saveData[_side].IADS[C2Type][C2.guid] = nil
    Logger.log(C2.name .. '\'s C2 is destroyed')
  end

  -- Additional handling for Taiwan's Tactical Air Operations Center (TAAOC)
  if _side == 't' then
    if saveData[_side].IADS.TAAOC[C2.guid] then
      setToOutOfComms(saveData, _side, 'TAAOC', 'SAM', C2)
      saveData[_side].IADS.TAAOC[C2.guid] = nil
      Logger.log(C2.name .. '\'s TAAOC is destroyed')
    end
  end
end

--- Clears data for destroyed units
--- Removes destroyed radars or SAMs from air defense system data
--- @param saveData SBJ__SaveData Game save data table
--- @param side string Side name
--- @param C2Type string Command and control type ('C2' or 'ROCC' or 'TAAOC')
--- @param type string Unit type ('radar' or 'SAM')
--- @param destroyedUnit CMO__Unit Destroyed unit
function IADS.clearUnitData(saveData, side, C2Type, type, destroyedUnit)
  local _side = getFieldBySide(side)

  -- Iterate through all C2 nodes to check if destroyed unit is within their coverage areas
  for _, item in pairs(saveData[_side].IADS[C2Type]) do
    for key, area in pairs(item.areas) do
      if destroyedUnit:inArea(area) and saveData[_side].IADS[C2Type][item.guid] then
        saveData[_side].IADS[C2Type][item.guid][type][destroyedUnit.guid] = nil
        Logger.log(destroyedUnit.name .. '\'s ' .. type .. ' is destroyed')
      end
    end
  end
end

--- Activates backup radar
--- When a radar is destroyed, automatically activates the nearest backup radar to maintain air defense coverage
--- @param config SBJ__CONFIG Configuration parameters
--- @param units CMO__Unit[] Available units list
--- @param destroyedRadar CMO__Unit Destroyed radar
function IADS.activateNearestRadar(config, units, destroyedRadar)
  local temp = { unit = nil, distance = config.radarDistance }

  local latitude = destroyedRadar.latitude
  local longitude = destroyedRadar.longitude

  -- First priority: Search for dedicated radars (JY-26, YLC-8B)
  for _, value in ipairs(units) do
    local u = GameApi.ScenEdit_GetUnit(value.guid)
    if u == nil then goto continue end
    local distance = GameApi.Tool_Range({ latitude = latitude, longitude = longitude }, u.guid)

    if (u.dbid == config.platform.JY26 or u.dbid == config.platform.YLC8B) then
      if distance < temp.distance then
        temp.unit = u
        temp.distance = distance
      end
    end

    ::continue::
  end

  -- Second priority: If no dedicated radars, search for SAM system radars
  if temp.unit == nil then
    for _, value in ipairs(units) do
      local u = GameApi.ScenEdit_GetUnit(value.guid)
      if u == nil then goto continue end

      local distance = GameApi.Tool_Range({ latitude = latitude, longitude = longitude }, u.guid)

      if u.dbid == config.platform.HQ22
          or u.dbid == config.platform.S300
          or u.dbid == config.platform.S400
          or u.dbid == config.platform.HQ12 then
        if distance < temp.distance then
          temp.unit = u
          temp.distance = distance
        end
      end

      ::continue::
    end
  end

  -- Activate the nearest radar found
  if temp.unit ~= nil then
    GameApi.ScenEdit_SetEMCON('Unit', temp.unit.guid, 'Radar=Active')
    Logger.log(tostring(temp.unit.name) .. '\'s radar is activated.')
  end
end

return IADS
