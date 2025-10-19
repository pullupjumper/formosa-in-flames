local UnitGenerator = require('src.modules.unitGenerator')
local config = require('src.core.constants')

-- Remove existing landing ships
UnitGenerator.removeLandingShips(config)

-- Add new landing ships
UnitGenerator.addLandingShips(config, config.c.PHIBOP)
