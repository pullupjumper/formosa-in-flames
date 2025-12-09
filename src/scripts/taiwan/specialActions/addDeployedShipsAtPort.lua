local UnitGenerator = require('src.modules.unitGenerator')
local config = require('src.core.config')

UnitGenerator.addDeployedShipsAtPort(config.t.surface.deployedShips, 'Taiwan')
