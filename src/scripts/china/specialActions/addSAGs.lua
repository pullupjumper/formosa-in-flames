local UnitGenerator = require("src.modules.unitGenerator")
local config = require("src.core.config")
local constants = require("src.core.constants")

UnitGenerator.createSAGs(constants.SIDES.RED, config.red.amphibOps.sags)
