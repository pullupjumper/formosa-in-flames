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
local isDestroyed = false

for _, component in ipairs(unit.components) do
	if (component['comp_dbid'] == config.sensor.S300_TOMBSTONE
				or component['comp_dbid'] == config.sensor.S400_GRAVE_STONE
				or component['comp_dbid'] == config.sensor.HQ12_H200
				or component['comp_dbid'] == config.sensor.HQ22_H200_IMPROVED
				or component['comp_dbid'] == config.sensor.S300_CHEESE_BOARD
				or component['comp_dbid'] == config.sensor.S400_CHEESE_BOARD)
			and component['comp_status'] == 'Destroyed' then
		Logger.log(unit.name ..
			'\'s radar is damaged - comp_dbid/' ..
			tostring(component['comp_dbid']) .. ', comp_status/' .. tostring(component['comp_status']))
		isDestroyed = true
	end
end

if isDestroyed then
	for _, value in ipairs(units) do
		local u = GameApi.ScenEdit_GetUnit(value.guid)
		if u == nil then goto continue end
		local distance = GameApi.Tool_Range({ latitude = latitude, longitude = longitude }, u.guid)

		if u.dbid == config.platform.HQ_22
				or u.dbid == config.platform.S_300
				or u.dbid == config.platform.S_400
				or u.dbid == config.platform.HQ_12 then
			for i, component in ipairs(u.components) do
				if (component['comp_dbid'] == config.sensor.S300_TOMBSTONE
							or component['comp_dbid'] == config.sensor.S400_GRAVE_STONE
							or component['comp_dbid'] == config.sensor.HQ12_H200
							or component['comp_dbid'] == config.sensor.HQ22_H200_IMPROVED
							or component['comp_dbid'] == config.sensor.S300_CHEESE_BOARD
							or component['comp_dbid'] == config.sensor.S400_CHEESE_BOARD)
						and component['comp_status'] ~= 'Destroyed' then
					if distance < temp.distance and unit.guid ~= u.guid then
						temp.unit = u
						temp.distance = distance
					end
				end
			end
		end

		::continue::
	end
end

if temp.unit ~= nil then
	GameApi.ScenEdit_SetEMCON('Unit', temp.unit.guid, 'Radar=Active')
	Logger.log(tostring(temp.unit.name) .. '\'s radar is activated')
end
