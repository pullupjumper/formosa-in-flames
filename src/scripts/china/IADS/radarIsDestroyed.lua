local Logger = require("src.utils.logger")
local config = require("src.core.constants")

local GameApi = require("src.utils.gameApi")
local unit = GameApi.ScenEdit_UnitX()
local units = GameApi.VP_GetSide({ side = 'China' }).units
local temp = { unit = nil, distance = config.radarDistance }

if unit == nil then
  Logger.error('unit == nil')
  return
end

local latitude = unit.latitude
local longitude = unit.longitude

for _, value in ipairs(units) do
  local u = GameApi.ScenEdit_GetUnit(value.guid)
  if u == nil then goto continue end
  local distance = GameApi.Tool_Range({ latitude = latitude, longitude = longitude }, u.guid)

  if (u.dbid == config.platformDBID16 or u.dbid == config.platformDBID17) then
    if distance < temp.distance then
      temp.unit = u
      temp.distance = distance
    end
  end

  ::continue::
end

if temp.unit == nil then
  for _, value in ipairs(units) do
    local u = GameApi.ScenEdit_GetUnit(value.guid)
    if u == nil then goto continue end

    local distance = GameApi.Tool_Range({ latitude = latitude, longitude = longitude }, u.guid)

    if u.dbid == config.platformDBID18
        or u.dbid == config.platformDBID19
        or u.dbid == config.platformDBID20
        or u.dbid == config.platformDBID21 then
      if distance < temp.distance then
        temp.unit = u
        temp.distance = distance
      end
    end

    ::continue::
  end
end

if temp.unit ~= nil then
  GameApi.ScenEdit_SetEMCON('Unit', temp.unit.guid, 'Radar=Active')
  Logger.log(tostring(temp.unit.name) .. '\'s radar is activated.')
end
