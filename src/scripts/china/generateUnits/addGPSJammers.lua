local UnitGenerator = require('src.modules.unitGenerator')
local CONFIG = require('src.core.constants')
local Logger = require("src.utils.logger")

UnitGenerator.removeJammingZones(CONFIG)
UnitGenerator.addGPSJammingZones(CONFIG)

Logger.log("Successfully added GPS jammers")
