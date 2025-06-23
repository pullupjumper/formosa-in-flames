GameApi = require("src.utils.gameApi")
Logger = require("src.utils.logger")
SafeCall = require("src.utils.utils").SafeCall
AssignEmbarkedUnitsToMissions = require("src.modules.assignMission").AssignEmbarkedUnitsToMissions
TransferCargo = require("src.modules.landingOps.landingOps").TransferCargo

---@param CONFIG SBJ__CONFIG
---@param units CMO__SideUnit
---@return table<string, table>
function GetUnitsInAnchorageArea(CONFIG, units)
  local operationalZones = CONFIG.c.PHIBOP.operationalZones
  local unitsInAnchorageArea = {}
  local isUnitMoving = false

  for _, item in ipairs(units) do
    local unit, err = SafeCall("GameApi.ScenEdit_GetUnit", GameApi.ScenEdit_GetUnit, item.guid)

    if not unit then
      Logger.error("Failed to get unit '" .. item.guid .. "': " .. err)
      goto continue_filter -- 跳過當前單位
    end
    -- local unit = SE_GetUnit({ guid = item.guid })

    if (unit.dbid == CONFIG.platformDBID6
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

---@param platformType string
---@param zone {boat: {zone:CMO__ReferencePoint[], settings:table, cargoItemsForTransfer:table}, tansportHelicopter: {zone:CMO__ReferencePoint[], settings:table, cargoItemsForTransfer:table}}
---@param missionName string
---@return boolean
function _handleCargoMission(platformType, zone, missionName)
  local m, err = SafeCall(
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

  local m, err = SafeCall(
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

  local m, err = SafeCall(
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
function CreateCargoMissions(CONFIG)
  local operationalZones = CONFIG.c.PHIBOP.operationalZones

  for _, zone in ipairs(operationalZones) do
    for _, mission in ipairs(zone.boat.missions) do
      local result = _handleCargoMission("boat", zone, mission.name)

      if not result then
        return false
      end
    end

    for _, mission in ipairs(zone.tansportHelicopter.missions) do
      local result = _handleCargoMission("tansportHelicopter", zone, mission.name)

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
function TransferAndAssign(CONFIG, unitsInAnchorageArea)
  local operationalZones = CONFIG.c.PHIBOP.operationalZones

  for _, zone in ipairs(operationalZones) do
    for _, u in ipairs(unitsInAnchorageArea) do
      if (u.dbid == CONFIG.platformDBID6 or u.dbid == CONFIG.platformDBID54) and
          u:inArea(zone.anchorageArea) then
        TransferCargo(
          u.guid,
          'Boats',
          zone.boat.dbid,
          zone.boat.cargoItemsForTransfer.type075[1].loadoutId,
          zone.boat.cargoItemsForTransfer.type075[1].cargoItems
        )
        TransferCargo(
          u.guid,
          'Aircraft',
          zone.tansportHelicopter.dbid,
          zone.tansportHelicopter.cargoItemsForTransfer.type075[1].loadoutId,
          zone.tansportHelicopter.cargoItemsForTransfer.type075[1].cargoItems
        )
        TransferCargo(
          u.guid,
          'Aircraft',
          zone.tansportHelicopter.dbid,
          zone.tansportHelicopter.cargoItemsForTransfer.type075[2].loadoutId,
          zone.tansportHelicopter.cargoItemsForTransfer.type075[2].cargoItems
        )
        AssignEmbarkedUnitsToMissions(
          u.guid,
          'Boats',
          zone.boat.dbid,
          zone.boat.missions
        )
        AssignEmbarkedUnitsToMissions(
          u.guid,
          'Aircraft',
          zone.tansportHelicopter.dbid,
          zone.tansportHelicopter.missions
        )
        AssignEmbarkedUnitsToMissions(
          u.guid,
          'Aircraft',
          zone.attackHelicopter.dbid,
          zone.attackHelicopter.missions
        )

        if zone.reconUAV then
          AssignEmbarkedUnitsToMissions(
            u.guid,
            'Aircraft',
            zone.reconUAV.dbid,
            zone.reconUAV.missions
          )
        end
      end

      if u.dbid == CONFIG.platformDBID7 and u:inArea(zone.anchorageArea) then
        TransferCargo(
          u.guid,
          'Boats',
          zone.boat.dbid,
          zone.boat.cargoItemsForTransfer.type071[1].loadoutId,
          zone.boat.cargoItemsForTransfer.type071[1].cargoItems
        )
        TransferCargo(
          u.guid,
          'Aircraft',
          zone.tansportHelicopter.dbid,
          zone.tansportHelicopter.cargoItemsForTransfer.type071[1].loadoutId,
          zone.tansportHelicopter.cargoItemsForTransfer.type071[1].cargoItems
        )
        AssignEmbarkedUnitsToMissions(
          u.guid,
          'Boats',
          zone.boat.dbid,
          zone.boat.missions
        )
        AssignEmbarkedUnitsToMissions(
          u.guid,
          'Aircraft',
          zone.tansportHelicopter.dbid,
          zone.tansportHelicopter.missions
        )
      end
    end
  end

  for _, item in ipairs(CONFIG.c.PHIBOP.transportAircraft) do
    TransferCargo(
      item.guid,
      'Aircraft',
      item.dbid,
      item.cargoItemsForTransfer[1].loadoutId,
      item.cargoItemsForTransfer[1].cargoItems
    )
    AssignEmbarkedUnitsToMissions(
      item.guid,
      'Aircraft',
      item.dbid,
      item.missions
    )
  end

  return true
end

return {
  _handleCargoMission = _handleCargoMission,
  GetUnitsInAnchorageArea = GetUnitsInAnchorageArea,
  CreateCargoMissions = CreateCargoMissions,
  TransferAndAssign = TransferAndAssign,
}
