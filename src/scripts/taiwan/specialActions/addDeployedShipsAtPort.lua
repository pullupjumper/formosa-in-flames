local UnitGenerator = require("src.modules.unitGenerator")
local config = require("src.core.config")
local constants = require("src.core.constants")

UnitGenerator.addDeployedShipsAtPort(constants.SIDES.PLAYER, config.t.surface.deployedShips)
