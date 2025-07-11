local GameUtils = require("src.utils.gameUtils")
local config = require("src.core.constants")
local GameApi = require("src.utils.gameApi")
local unit = GameApi.ScenEdit_UnitX()
local units = GameApi.VP_GetSide({ side = 'China' }).units
local temp = { unit = nil, distance = config.radarDistance }

if unit == nil then
	GameApi.ScenEdit_SpecialMessage('China', 'unit == nil')
	return
end

-- if unit.dbid == CONFIG.platformDBID25 then
--     for _, component in ipairs(unit.components) do
--         if component['comp_dbid'] == CONFIG.sensorDBID13
--             and component['comp_status'] == 'Destroyed' then
--             GameUtils.PrintBox(
--                 'China',
--                 unit.name .. '\'s jammer is destroyed',
--                 'comp_dbid/' .. tostring(component['comp_dbid']),
--                 'comp_status/' .. tostring(component['comp_status'])
--             )

--             for _, value in ipairs(CONFIG.c.GPSJamming.jammers) do
--                 if unit.guid == value.guid then
--                     local event = ScenEdit_GetEvent(value.eventName)

--                     if event then
--                         event.isActive = false
--                         ScenEdit_SpecialMessage('China', tostring(event.eventName) .. ' is deactivated')
--                     end
--                 end
--             end
--         end
--     end
-- end

local latitude = unit.latitude
local longitude = unit.longitude
local isDestroyed = false

for _, component in ipairs(unit.components) do
	if (component['comp_dbid'] == config.sensorDBID1
				or component['comp_dbid'] == config.sensorDBID2
				or component['comp_dbid'] == config.sensorDBID3
				or component['comp_dbid'] == config.sensorDBID4
				or component['comp_dbid'] == config.sensorDBID5
				or component['comp_dbid'] == config.sensorDBID6)
			and component['comp_status'] == 'Destroyed' then
		GameUtils.printBox(
			'China',
			unit.name .. '\'s radar is damaged',
			'comp_dbid/' .. tostring(component['comp_dbid']),
			'comp_status/' .. tostring(component['comp_status'])
		)
		isDestroyed = true
	end
end

if isDestroyed then
	for _, value in ipairs(units) do
		local u = GameApi.ScenEdit_GetUnit(value.guid)
		if u == nil then goto continue end
		local distance = GameApi.Tool_Range({ latitude = latitude, longitude = longitude }, u.guid)

		if u.dbid == config.platformDBID18
				or u.dbid == config.platformDBID19
				or u.dbid == config.platformDBID20
				or u.dbid == config.platformDBID21 then
			for i, component in ipairs(u.components) do
				if (component['comp_dbid'] == config.sensorDBID1
							or component['comp_dbid'] == config.sensorDBID2
							or component['comp_dbid'] == config.sensorDBID3
							or component['comp_dbid'] == config.sensorDBID4
							or component['comp_dbid'] == config.sensorDBID5
							or component['comp_dbid'] == config.sensorDBID6)
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
	GameUtils.printBox('China', tostring(temp.unit.name) .. '\'s radar is activated')
end
