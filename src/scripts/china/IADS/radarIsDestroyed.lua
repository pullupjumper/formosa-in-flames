local Logger = require("src.utils.logger")
local CONFIG = require("src.core.constants")

local GameApi = require("src.utils.gameApi")
local unit = GameApi.ScenEdit_UnitX()
local units = GameApi.VP_GetSide({ side = 'China' }).units
local temp = { unit = nil, distance = CONFIG.radarDistance }

if unit == nil then
  GameApi.ScenEdit_SpecialMessage('China', 'unit == nil')
  return
end

local latitude = unit.latitude
local longitude = unit.longitude

for _, value in ipairs(units) do
  local u = GameApi.ScenEdit_GetUnit(value.guid)
  if u == nil then goto continue end
  local distance = GameApi.Tool_Range({ latitude = latitude, longitude = longitude }, u.guid)

  if (u.dbid == CONFIG.platformDBID16 or u.dbid == CONFIG.platformDBID17) then
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

    if u.dbid == CONFIG.platformDBID18
        or u.dbid == CONFIG.platformDBID19
        or u.dbid == CONFIG.platformDBID20
        or u.dbid == CONFIG.platformDBID21 then
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
