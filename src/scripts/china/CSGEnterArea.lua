local GameApi = require("src.utils.gameApi")

-- GameApi.ScenEdit_GetMission('China', 'SEAD EAST').isactive = true
GameApi.ScenEdit_GetMission('China', 'CAP/E').isactive = true
GameApi.ScenEdit_GetMission('China', 'ASW/CSG').isactive = false
GameApi.ScenEdit_GetMission('China', 'ASW/PATROL AC').isactive = false

-- CONFIG.c.aircraft.landStrike.isStrikeActivated = true
