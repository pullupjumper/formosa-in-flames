local gKH = require('src.core.gKH_State_Standalone')
local SecondWaveUnloading = require('src.modules.landingOps.secondWaveUnloading')
local GameApi = require("src.utils.gameApi")
local Logger = require("src.utils.logger")
local Utils = require("src.utils.utils")
local CONFIG = require("src.core.constants")

local saveData = gKH.State.LoadTableFromKey("SaveData")

if saveData == nil then
  Logger.log("saveData is nil")
  return
end

local ship, err = Utils.SafeCall("GameApi.ScenEdit_UnitX", GameApi.ScenEdit_UnitX)

if not ship then
  Logger.error("Error in ScenEdit_UnitX: " .. err)
  return
end


if ship.name == 'Barge' and not SecondWaveUnloading.HasExtendedBridge(saveData, ship) then
  ship.course = nil
  ship.manualSpeed = 0
  ship.holdposition = true

  local bridge, err = Utils.SafeCall("GameApi.ScenEdit_AddUnit", GameApi.ScenEdit_AddUnit, {
    side      = 'China',
    type      = 'Facility',
    latitude  = ship.latitude,
    longitude = ship.longitude,
    dbid      = CONFIG.platformDBID71,
    unitname  = 'bridge',
  })

  if not bridge then
    Logger.error("Error in ScenEdit_AddUnit: " .. err)
    return
  end

  saveData.c.PHIBOP.barges[ship.guid].bridgeGUID = bridge.guid
end

if ship.name == 'Barge' and not SecondWaveUnloading.IsBridgeDestroyed(saveData, ship) then
  for _, guid in ipairs(saveData.c.PHIBOP.barges[ship.guid].roros) do
    local roro, err = Utils.SafeCall("GameApi.ScenEdit_GetUnit", GameApi.ScenEdit_GetUnit, guid)

    if not roro then
      Logger.error("Failed to get unit '" .. guid .. "': " .. err)
      goto continue
    end

    local zone = SecondWaveUnloading.GetBargeROROZone(CONFIG, ship, roro)

    if zone then
      SecondWaveUnloading.OffloadVehicles({
        ship = roro,
        num = 20,
        bearing = zone.ACV.bearing + 90,
        distance = zone.ACV.distance,
        firstDistance = 1
      })
    end

    ::continue::
  end
end

if ship.name == 'RORO' then
  ship.course = nil
  ship.manualSpeed = 0
  ship.holdposition = true
end

gKH.State.SaveTableToKey(saveData, "SaveData")
