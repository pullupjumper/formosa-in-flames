local gKH = require('src.core.gKH_State_Standalone')
local SecondWaveUnloading = require('src.modules.landingOps.secondWaveUnloading')
local GameApi = require("src.utils.gameApi")
local Logger = require("src.utils.logger")
local config = require("src.core.constants")

local saveData = gKH.State.LoadTableFromKey("SaveData")

if saveData == nil then
  Logger.log("saveData is nil")
  return
end

local ship = GameApi.ScenEdit_UnitX()

if not ship then
  return
end


if ship.name == 'Barge' and not SecondWaveUnloading.hasExtendedBridge(saveData, ship) then
  ship.course = nil
  ship.manualSpeed = 0
  ship.holdposition = true

  local bridge = GameApi.ScenEdit_AddUnit({
    side      = 'China',
    type      = 'Facility',
    latitude  = ship.latitude,
    longitude = ship.longitude,
    dbid      = config.platform.BRIDGE,
    unitname  = 'bridge',
  })

  if not bridge then
    return
  end

  saveData.c.PHIBOP.barges[ship.guid].bridgeGUID = bridge.guid
end

if ship.name == 'Barge' and not SecondWaveUnloading.isBridgeDestroyed(saveData, ship) then
  for _, guid in ipairs(saveData.c.PHIBOP.barges[ship.guid].roros) do
    local roro = GameApi.ScenEdit_GetUnit(guid)

    if roro then
      local zone = SecondWaveUnloading.getBargeROROZone(config, ship, roro)

      if zone then
        SecondWaveUnloading.offloadVehicles({
          ship = roro,
          num = 20,
          bearing = zone.ACV.bearing + 90,
          distance = zone.ACV.distance,
          firstDistance = 1
        })
      end
    end
  end
end

if ship.name == 'RORO' then
  ship.course = nil
  ship.manualSpeed = 0
  ship.holdposition = true
end

gKH.State.SaveTableToKey(saveData, "SaveData")
