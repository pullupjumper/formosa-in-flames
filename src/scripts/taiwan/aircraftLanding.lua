local config = require("src.core.config")
local GameApi = require("src.utils.gameApi")
local unit = GameApi.ScenEdit_UnitX()

if unit then
  unit.readytime = config.readyTime
end
