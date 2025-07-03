local GameApi = require("src.utils.gameApi")
local Logger = require("src.utils.logger")
local Utils = require("src.utils.utils")
local AssignMission = require("src.modules.assignMission")

local AmphibiousLogistics = {}


---@param fromUnit CMO__Unit
---@param toUnit CMO__Unit
---@param cargoItem CargoItem
function AmphibiousLogistics.UpdateCargo(fromUnit, toUnit, cargoItem)
  local cargoGuidList = {}
  local count = 0

  if fromUnit == nil or fromUnit.cargo[1].cargo == nil then
    return
  end

  for k, v in ipairs(fromUnit.cargo[1].cargo) do
    if v.dbid == cargoItem.dbid then
      table.insert(cargoGuidList, v.guid)
      count = count + 1
    end

    if count == cargoItem.num then
      break
    end
  end

  for k, v in ipairs(cargoGuidList) do
    fromUnit:deleteUnitCargo(v)
  end

  for i = 1, cargoItem.num, 1 do
    toUnit:createUnitCargo(cargoItem.type, cargoItem.dbid)
  end
end

---@param fromUnit CMO__Unit
---@param cargoItem CargoItem
function AmphibiousLogistics.DeleteCargo(fromUnit, cargoItem)
  local cargoGuidList = {}
  local count = 0
  local resultCount = 0

  -- if fromUnit == nil or (fromUnit.cargo[1].cargo == nil) then
  --     return
  -- end

  if fromUnit == nil or
      fromUnit.cargo == nil or
      cargoItem.num == 0 or
      (fromUnit.cargo and fromUnit.cargo[1] == nil) then
    return 0
  end

  for k, v in ipairs(fromUnit.cargo[1].cargo) do
    if v.dbid == cargoItem.dbid then
      table.insert(cargoGuidList, v.guid)
      count = count + 1
    end

    if count == cargoItem.num then
      break
    end
  end

  for k, v in ipairs(cargoGuidList) do
    local result = fromUnit:deleteUnitCargo(v)

    if result then
      resultCount = resultCount + 1
    end
  end

  return resultCount
end

---@param fromUnit string
---@param platformType string
---@param platformDBid number
---@param loadoutDBID number
---@param cargoItems table<number, CargoItem>
function AmphibiousLogistics.TransferCargo(fromUnit, platformType, platformDBid, loadoutDBID, cargoItems)
  local base, err = Utils.SafeCall("GameApi.ScenEdit_GetUnit", GameApi.ScenEdit_GetUnit, fromUnit)

  if not base then
    Logger.error("Failed to get base unit '" .. fromUnit .. "': " .. err)
    return
  end

  local platforms = base.embarkedUnits[platformType]
  local baseContainingCargo = base

  if platforms ~= nil then
    local count = Utils.GetCount(cargoItems)

    for k, v in ipairs(platforms) do
      local unit, err = Utils.SafeCall("GameApi.ScenEdit_GetUnit", GameApi.ScenEdit_GetUnit, v)

      if not unit then
        Logger.error("Failed to get unit '" .. v .. "': " .. err)
        return
      end

      if platformType == 'Aircraft' then
        if unit ~= nil and unit.dbid == platformDBid and unit.loadoutdbid == loadoutDBID then
          if count > 1 then
            for _, item in ipairs(cargoItems[k]) do
              AmphibiousLogistics.UpdateCargo(baseContainingCargo, unit, item)
            end
          else
            for _, item in ipairs(cargoItems[1]) do
              AmphibiousLogistics.UpdateCargo(baseContainingCargo, unit, item)
            end
          end
        end
      else
        if unit ~= nil and unit.dbid == platformDBid then
          if count > 1 then
            for _, item in ipairs(cargoItems[k]) do
              AmphibiousLogistics.UpdateCargo(baseContainingCargo, unit, item)
            end
          else
            for _, item in ipairs(cargoItems[1]) do
              AmphibiousLogistics.UpdateCargo(baseContainingCargo, unit, item)
            end
          end
        end
      end
    end
  end
end

---@param CONFIG SBJ__CONFIG
---@param units CMO__SideUnit
---@return table<string, table>
function AmphibiousLogistics.GetUnitsInAnchorageArea(CONFIG, units)
  local operationalZones = CONFIG.c.PHIBOP.operationalZones
  local unitsInAnchorageArea = {}
  local isUnitMoving = false

  for _, item in ipairs(units) do
    local unit, err = Utils.SafeCall("GameApi.ScenEdit_GetUnit", GameApi.ScenEdit_GetUnit, item.guid)

    if not unit then
      Logger.error("Failed to get unit '" .. item.guid .. "': " .. err)
      goto continue_filter -- 跳過當前單位
    end

    if (unit and unit.dbid == CONFIG.platformDBID6
          or unit.dbid == CONFIG.platformDBID7
          or unit.dbid == CONFIG.platformDBID8
          or unit.dbid == CONFIG.platformDBID9
          or unit.dbid == CONFIG.platformDBID10
          or unit.dbid == CONFIG.platformDBID32
          or unit.dbid == CONFIG.platformDBID54
          or unit.dbid == CONFIG.platformDBID56
          or unit.dbid == CONFIG.platformDBID72) then
      if unit.unitstate ~= 'Unassigned' then
        isUnitMoving = true
        break
      end

      for _, zone in ipairs(operationalZones) do
        if unit:inArea(zone.anchorageArea) or unit:inArea(zone.LSTAnchorageArea) then
          table.insert(unitsInAnchorageArea, unit)
        end
      end
    end

    ::continue_filter::
  end

  return { units = unitsInAnchorageArea, isUnitMoving = isUnitMoving }
end

---@param platformType string The type of platform to filter (e.g., 'tansportHelicopter', 'boat')
---@param zone SBJ__OperationalZone
---@param missionName string
---@return boolean
function AmphibiousLogistics._handleCargoMission(platformType, zone, missionName)
  local m, err = Utils.SafeCall(
    "GameApi.ScenEdit_AddMission",
    GameApi.ScenEdit_AddMission,
    "China",
    missionName,
    "Cargo",
    { zone = zone[platformType].zone }
  )

  if not m then
    Logger.error("Failed to add mission '" .. missionName .. "': " .. err)
    return false
  end

  local m, err = Utils.SafeCall(
    "GameApi.ScenEdit_SetMission",
    GameApi.ScenEdit_SetMission,
    "China",
    missionName,
    zone[platformType].settings
  )

  if not m then
    Logger.error("Failed to set mission '" .. missionName .. "': " .. err)
    return false
  end

  local m, err = Utils.SafeCall(
    "GameApi.ScenEdit_SetDoctrine",
    GameApi.ScenEdit_SetDoctrine,
    { side = "China", mission = missionName },
    { automatic_evasion = false }
  )

  if not m then
    Logger.error("Failed to set doctrine for mission '" .. missionName .. "': " .. err)
    return false
  end

  return true
end

---@param CONFIG SBJ__CONFIG
---@return boolean
function AmphibiousLogistics.CreateCargoMissions(CONFIG)
  local operationalZones = CONFIG.c.PHIBOP.operationalZones

  for _, zone in ipairs(operationalZones) do
    for _, mission in ipairs(zone.boat.missions) do
      local result = AmphibiousLogistics._handleCargoMission("boat", zone, mission.name)

      if not result then
        return false
      end
    end

    for _, mission in ipairs(zone.tansportHelicopter.missions) do
      local result = AmphibiousLogistics._handleCargoMission("tansportHelicopter", zone, mission.name)

      if not result then
        return false
      end
    end
  end

  return true
end

---@param CONFIG SBJ__CONFIG
---@param unitsInAnchorageArea table<integer, CMO__Unit>
---@return boolean
function AmphibiousLogistics.TransferAndAssign(CONFIG, unitsInAnchorageArea)
  local operationalZones = CONFIG.c.PHIBOP.operationalZones

  for _, zone in ipairs(operationalZones) do
    for _, u in ipairs(unitsInAnchorageArea) do
      if (u.dbid == CONFIG.platformDBID6 or u.dbid == CONFIG.platformDBID54) and
          u:inArea(zone.anchorageArea) then
        AmphibiousLogistics.TransferCargo(
          u.guid,
          'Boats',
          zone.boat.dbid,
          zone.boat.cargoItemsForTransfer.type075[1].loadoutId,
          zone.boat.cargoItemsForTransfer.type075[1].cargoItems
        )
        AmphibiousLogistics.TransferCargo(
          u.guid,
          'Aircraft',
          zone.tansportHelicopter.dbid,
          zone.tansportHelicopter.cargoItemsForTransfer.type075[1].loadoutId,
          zone.tansportHelicopter.cargoItemsForTransfer.type075[1].cargoItems
        )
        AmphibiousLogistics.TransferCargo(
          u.guid,
          'Aircraft',
          zone.tansportHelicopter.dbid,
          zone.tansportHelicopter.cargoItemsForTransfer.type075[2].loadoutId,
          zone.tansportHelicopter.cargoItemsForTransfer.type075[2].cargoItems
        )
        AssignMission.AssignEmbarkedUnitsToMissions(
          u.guid,
          'Boats',
          zone.boat.dbid,
          zone.boat.missions
        )
        AssignMission.AssignEmbarkedUnitsToMissions(
          u.guid,
          'Aircraft',
          zone.tansportHelicopter.dbid,
          zone.tansportHelicopter.missions
        )
        AssignMission.AssignEmbarkedUnitsToMissions(
          u.guid,
          'Aircraft',
          zone.attackHelicopter.dbid,
          zone.attackHelicopter.missions
        )

        if zone.reconUAV then
          AssignMission.AssignEmbarkedUnitsToMissions(
            u.guid,
            'Aircraft',
            zone.reconUAV.dbid,
            zone.reconUAV.missions
          )
        end
      end

      if u.dbid == CONFIG.platformDBID7 and u:inArea(zone.anchorageArea) then
        AmphibiousLogistics.TransferCargo(
          u.guid,
          'Boats',
          zone.boat.dbid,
          zone.boat.cargoItemsForTransfer.type071[1].loadoutId,
          zone.boat.cargoItemsForTransfer.type071[1].cargoItems
        )
        AmphibiousLogistics.TransferCargo(
          u.guid,
          'Aircraft',
          zone.tansportHelicopter.dbid,
          zone.tansportHelicopter.cargoItemsForTransfer.type071[1].loadoutId,
          zone.tansportHelicopter.cargoItemsForTransfer.type071[1].cargoItems
        )
        AssignMission.AssignEmbarkedUnitsToMissions(
          u.guid,
          'Boats',
          zone.boat.dbid,
          zone.boat.missions
        )
        AssignMission.AssignEmbarkedUnitsToMissions(
          u.guid,
          'Aircraft',
          zone.tansportHelicopter.dbid,
          zone.tansportHelicopter.missions
        )
      end
    end
  end

  for _, item in ipairs(CONFIG.c.PHIBOP.transportAircraft) do
    AmphibiousLogistics.TransferCargo(
      item.guid,
      'Aircraft',
      item.dbid,
      item.cargoItemsForTransfer[1].loadoutId,
      item.cargoItemsForTransfer[1].cargoItems
    )
    AssignMission.AssignEmbarkedUnitsToMissions(
      item.guid,
      'Aircraft',
      item.dbid,
      item.missions
    )
  end

  return true
end

---comment
---@param CONFIG SBJ__CONFIG
---@param units CMO__SideUnit
---@return boolean
function AmphibiousLogistics.RetransferCargos(CONFIG, units)
  local operationalZones = CONFIG.c.PHIBOP.operationalZones

  for _, zone in ipairs(operationalZones) do
    for _, item in ipairs(units) do
      local unit, err = Utils.SafeCall("GameApi.ScenEdit_GetUnit", GameApi.ScenEdit_GetUnit, item.guid)

      if not unit then
        Logger.error("Failed to get unit '" .. item.name .. "': " .. err)
        return false
      end

      if unit and (unit.dbid == CONFIG.platformDBID6 or unit.dbid == CONFIG.platformDBID54) then
        AmphibiousLogistics.TransferCargo(
          unit.guid,
          'Boats',
          zone.boat.dbid,
          zone.boat.cargoItemsForTransfer.type075[1].loadoutId,
          zone.boat.cargoItemsForTransfer.type075[1].cargoItems
        )
        AmphibiousLogistics.TransferCargo(
          unit.guid,
          'Aircraft',
          zone.tansportHelicopter.dbid,
          zone.tansportHelicopter.cargoItemsForTransfer.type075[1].loadoutId,
          zone.tansportHelicopter.cargoItemsForTransfer.type075[1].cargoItems
        )
        AmphibiousLogistics.TransferCargo(
          unit.guid,
          'Aircraft',
          zone.tansportHelicopter.dbid,
          zone.tansportHelicopter.cargoItemsForTransfer.type075[2].loadoutId,
          zone.tansportHelicopter.cargoItemsForTransfer.type075[2].cargoItems
        )
      end

      if unit and unit.dbid == CONFIG.platformDBID7 then
        AmphibiousLogistics.TransferCargo(
          unit.guid,
          'Boats',
          zone.boat.dbid,
          zone.boat.cargoItemsForTransfer.type071[1].loadoutId,
          zone.boat.cargoItemsForTransfer.type071[1].cargoItems
        )
        AmphibiousLogistics.TransferCargo(
          unit.guid,
          'Aircraft',
          zone.tansportHelicopter.dbid,
          zone.tansportHelicopter.cargoItemsForTransfer.type071[1].loadoutId,
          zone.tansportHelicopter.cargoItemsForTransfer.type071[1].cargoItems
        )
      end
    end
  end

  return true
end

return AmphibiousLogistics
