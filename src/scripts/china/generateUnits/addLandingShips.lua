local UnitGenerator = require('src.modules.unitGenerator')
local config = require('src.core.constants')
local GameApi = require("src.utils.gameApi")

-- Remove existing landing ships
UnitGenerator.removeLandingShips(config)

-- Add new landing ships
UnitGenerator.addLandingShips(config)
