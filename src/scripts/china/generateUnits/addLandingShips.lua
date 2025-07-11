local UnitGenerator = require('src.modules.unitGenerator')
local config = require('src.core.constants')
local GameApi = require("src.utils.gameApi")

-- 移除現有登陸艦
UnitGenerator.removeLandingShips(config)

-- 添加新的登陸艦
UnitGenerator.addLandingShips(config)
