local CONFIG = gKH.State.LoadTableFromKey("CONFIG")

if CONFIG == nil then
    ScenEdit_SpecialMessage('China', 'CONFIG == nil')
    return
end

-- ScenEdit_GetMission('China', 'SEAD EAST').isactive = true
ScenEdit_GetMission('China', 'CAP/E').isactive = true
ScenEdit_GetMission('China', 'ASW/CSG').isactive = false
ScenEdit_GetMission('China', 'ASW/PATROL AC').isactive = false

-- CONFIG.c.aircraft.landStrike.isStrikeActivated = true

gKH.State.SaveTableToKey(CONFIG, "CONFIG")
