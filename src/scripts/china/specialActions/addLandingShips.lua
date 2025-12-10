local UnitGenerator = require("src.modules.unitGenerator")
local config = require("src.core.config")

-- Remove existing landing ships
UnitGenerator.removeLandingShips()

-- Add new landing ships
UnitGenerator.addLandingShips(config.c.PHIBOP)
