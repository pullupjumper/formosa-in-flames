local GnssJamming = require("src.modules.ew.gnssJamming")
local config = require("src.core.config")
local constants = require("src.core.constants")

GnssJamming.deploySide(config, constants.SIDES.ENEMY)
