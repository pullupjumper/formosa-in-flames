local UnitGenerator = require('src.modules.unitGenerator')
local config = require('src.core.config')

UnitGenerator.addAircraft(config.c.air.landBased.deployedACs)
