local UnitGenerator = require("src.modules.unitGenerator")
local config = require("src.core.config")
local constants = require("src.core.constants")

UnitGenerator.createSAGs(config.c.amphibOps.sag, constants.SIDES.CHINA)
