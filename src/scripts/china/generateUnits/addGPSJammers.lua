local UnitGenerator = require('src.modules.unitGenerator')
local config = require('src.core.constants')
local Logger = require("src.utils.logger")

UnitGenerator.removeJammingZones(config)
UnitGenerator.addGPSJammingZones(config)

Logger.log("Successfully added GPS jammers")
