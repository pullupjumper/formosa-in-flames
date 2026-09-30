local config = require("src.core.config")
local GameApi = require("src.utils.gameApi")
local constants = require("src.core.constants")
local unit = GameApi.ScenEdit_UnitX()

if unit then
  if unit.dbid == constants.PLATFORMS.J20 or
      unit.dbid == constants.PLATFORMS.J16 or
      unit.dbid == constants.PLATFORMS.SU30 or
      unit.dbid == constants.PLATFORMS.H6K or
      unit.dbid == constants.PLATFORMS.J35 or
      unit.dbid == constants.PLATFORMS.J10C then
    unit.readytime = config.aircraftReadySec
    unit.mission = ""
  end
end
