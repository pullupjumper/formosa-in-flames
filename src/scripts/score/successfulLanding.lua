local CONFIG = require("src.core.constants")
local GameApi = require("src.utils.gameApi")
local score = GameApi.ScenEdit_GetScore("Taiwan")
GameApi.ScenEdit_SetScore("Taiwan", (score + CONFIG.s.ifv), "Landing successfully")
