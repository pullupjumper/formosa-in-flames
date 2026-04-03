local UnitGenerator = require("src.modules.unitGenerator")
local config = require("src.core.config")
local constants = require("src.core.constants")

UnitGenerator.createSAGs(config.t.surface.sag, constants.SIDES.PLAYER)
