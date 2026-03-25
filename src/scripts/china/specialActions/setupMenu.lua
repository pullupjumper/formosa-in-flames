local UnitStatusUI = require("src.modules.unitStatusUI")
local config = require("src.core.config")
local constants = require("src.core.constants")

UnitStatusUI.createSetupMenu(config, constants.SIDES.ENEMY)
