-- Tool_ResetMessageLog([Optional: Print First])

local CONFIG = gKH.State.LoadTableFromKey("CONFIG")

if CONFIG == nil then
    ScenEdit_SpecialMessage('China', 'CONFIG == nil')
    return
end

gKH.State.SaveTableToKey(CONFIG, "CONFIG")


local unitsFromChina = VP_GetSide({ Side = "China" }).units
for index, u in ipairs(unitsFromChina) do
    local unit = SE_GetUnit({ guid = u.guid })
    local count = 0
    for index, sensor in ipairs(unit.sensors) do
        if sensor['sensor_dbid'] == 0 then
            count = count + 1
        end
    end

    count = count - 1
    print(count)
    for index, sensor in ipairs(unit.sensors) do
        if count >= 1 and sensor['sensor_dbid'] == 0 then
            ScenEdit_UpdateUnit({
                guid = unit.guid,
                dbid = 0,
                mode = 'remove_sensor',
                sensorId = sensor['sensor_guid']
            })
            count = count - 1
        end
    end
end
