local GnssJamming = require("src.modules.ew.gnssJamming")
local config = require("src.core.config")
local constants = require("src.core.constants")

GnssJamming.removeJammers(config.c.gnssJamming.jammers, constants.SIDES.ENEMY)
GnssJamming.addGnssJammers(config.c.gnssJamming.jammers, constants.SIDES.ENEMY)
