local CONFIG = gKH.State.LoadTableFromKey("CONFIG")

if CONFIG == nil then
    ScenEdit_SpecialMessage('Taiwan', 'CONFIG == nil')
    return
end

local elapsedTime = 0

if CONFIG.t.ground.mlrs.const.erectingTime then
    elapsedTime = ScenEdit_CurrentTime() - CONFIG.t.ground.mlrs.const.erectingTime
end

if elapsedTime >= CONFIG.t.ground.mlrs.const.erectingTimeSpan * 2 then
    local unit = SE_GetUnit({ guid = CONFIG.t.ground.mlrs.batteries['X58F5H-0HMU9T3M6UVQP'].guid })

    if unit then
        unit.course = CONFIG.t.ground.mlrs.batteries['X58F5H-0HMU9T3M6UVQP'].position.assemblyArea.course
        CONFIG.t.ground.mlrs.const.erectingTime = nil
    end
end

gKH.State.SaveTableToKey(CONFIG, "CONFIG")
