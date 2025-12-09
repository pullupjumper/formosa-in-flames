local config = require("src.core.config")
local GameApi = require("src.utils.gameApi")
local score = GameApi.ScenEdit_GetScore("Taiwan")
GameApi.ScenEdit_SetScore("Taiwan", (score + config.s.ifv), "Landing successfully")
