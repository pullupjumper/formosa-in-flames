local LandingOps = require("src.modules.landingOps.init")
local GameApi = require("src.utils.gameApi")
local config = require("src.core.config")
local constants = require("src.core.constants")
local ship = GameApi.ScenEdit_UnitX()
local contacts = GameApi.ScenEdit_GetContacts(constants.SIDES.ENEMY)

if not contacts then
  return
end

if not ship then
  return
end

LandingOps.neutralizeAirlandingZone(config.c.amphibOps, ship, contacts)
