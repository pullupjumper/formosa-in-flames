CONFIG = require("src.core.constants")
local score = ScenEdit_GetScore("Taiwan")
ScenEdit_SetScore("Taiwan", (score + CONFIG.s.ifv), "Landing successfully")
