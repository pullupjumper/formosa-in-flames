local UnitGenerator = require('src.modules.unitGenerator')
local CONFIG = require('src.core.constants')
local GameApi = require("src.utils.gameApi")

-- 移除現有登陸艦
UnitGenerator.removeLandingShips(CONFIG)

-- 添加新的登陸艦
UnitGenerator.addLandingShips(CONFIG)
