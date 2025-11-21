local GameApi = require("src.utils.gameApi")
local Utils = require("src.utils.utils")
local AssignMission = require("src.modules.assignMission")

local AmphibiousLogistics = {}


--- Transfer cargo from one unit to another
--- Deletes specified cargo items from source unit and creates them on destination unit
--- Used for loading embarked aircraft and boats with troops and equipment
---@param fromUnit CMO__Unit Source unit (typically the mother ship)
---@param toUnit CMO__Unit Destination unit (aircraft or boat to receive cargo)
---@param cargoItem SBJ__CargoDescriptor Cargo specification (type, DBID, quantity)
function AmphibiousLogistics.updateCargo(fromUnit, toUnit, cargoItem)
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

--- Delete specified cargo from a unit
--- Removes cargo items matching the specified DBID from the unit's inventory
--- Returns the actual number of items deleted (may be less than requested)
---@param fromUnit CMO__Unit Unit to remove cargo from
---@param cargoItem SBJ__CargoDescriptor Cargo specification (type, DBID, quantity)
---@return number Number of cargo items actually deleted
function AmphibiousLogistics.deleteCargo(fromUnit, cargoItem)
  local cargoGuidList = {}
  local count = 0
  local resultCount = 0

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

--- Transfer cargo from base to multiple embarked units
--- Distributes cargo items to all embarked platforms of a specific type matching DBID/loadout
--- For aircraft, also filters by loadout ID to ensure correct weapon configuration
--- Supports both single cargo list (all units get same cargo) and per-unit cargo lists
---@param fromUnit string GUID of the base unit containing embarked platforms
---@param platformType string Type of embarked unit ('Aircraft' or 'Boats')
---@param platformDBid number Database ID of the platform to receive cargo
---@param loadoutDBID number Loadout ID for aircraft filtering (ignored for boats)
---@param cargoItems SBJ__CargoDescriptor[] Cargo items to transfer (single list or per-unit)
function AmphibiousLogistics.transferCargo(fromUnit, platformType, platformDBid, loadoutDBID, cargoItems)
  local base = GameApi.ScenEdit_GetUnit(fromUnit)

  if not base then
    return
  end

  local platforms = base.embarkedUnits[platformType]
  local baseContainingCargo = base

  if platforms ~= nil then
    local count = Utils.getCount(cargoItems)

    for k, v in ipairs(platforms) do
      local unit = GameApi.ScenEdit_GetUnit(v)

      if unit then
        if platformType == 'Aircraft' then
          if unit.dbid == platformDBid and unit.loadoutdbid == loadoutDBID then
            if count > 1 then
              for _, item in ipairs(cargoItems[k]) do
                AmphibiousLogistics.updateCargo(baseContainingCargo, unit, item)
              end
            else
              for _, item in ipairs(cargoItems[1]) do
                AmphibiousLogistics.updateCargo(baseContainingCargo, unit, item)
              end
            end
          end
        else
          if unit.dbid == platformDBid then
            if count > 1 then
              for _, item in ipairs(cargoItems[k]) do
                AmphibiousLogistics.updateCargo(baseContainingCargo, unit, item)
              end
            else
              for _, item in ipairs(cargoItems[1]) do
                AmphibiousLogistics.updateCargo(baseContainingCargo, unit, item)
              end
            end
          end
        end
      end
    end
  end
end

--- Get units in anchorage area and check their movement status
--- Filters amphibious ships (LHD, LPD, LST) and checks if any are still moving
--- Used to determine when all ships have arrived and are ready for cargo operations
---@param config SBJ__CONFIG Global configuration for platform DBIDs
---@param amphibOpsConfig SBJ__AmphibOpsConfig Amphibious operation configuration
---@param units CMO__SideUnit Unit list from the side (filtered for ships)
---@return { units: CMO__Unit[], isUnitMoving: boolean } Units in anchorage and movement status
function AmphibiousLogistics.getUnitsInAnchorageArea(config, amphibOpsConfig, units)
  local operationalZones = amphibOpsConfig.operationalZones
  local unitsInAnchorageArea = {}
  local isUnitMoving = false

  for _, item in ipairs(units) do
    local unit = GameApi.ScenEdit_GetUnit(item.guid)

    if unit and (unit.dbid == config.platform.TYPE_075
          or unit.dbid == config.platform.TYPE_071
          or unit.dbid == config.platform.TYPE_072III
          or unit.dbid == config.platform.TYPE_072A
          or unit.dbid == config.platform.TYPE_073A
          or unit.dbid == config.platform.TYPE_072A_2
          or unit.dbid == config.platform.TYPE_076
          or unit.dbid == config.platform.FERRY
          or unit.dbid == config.platform.BARGE) then
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
  end

  return { units = unitsInAnchorageArea, isUnitMoving = isUnitMoving }
end

--- Create a cargo transport mission for a specific platform type
--- Sets up the mission zone, configuration, and doctrine
--- Disables automatic evasion to ensure units complete cargo delivery
---@param platformType string The type of platform to filter (e.g., 'tansportHelicopter', 'boat')
---@param zone SBJ__OperationZoneDescriptor Operation zone descriptor with mission settings
---@param missionName string Name for the cargo mission
---@return boolean True if mission was successfully created and configured
local function handleCargoMission(platformType, zone, missionName)
  local m = GameApi.ScenEdit_AddMission("China", missionName, "Cargo", { zone = zone[platformType].zone })

  if not m then
    return false
  end

  m = GameApi.ScenEdit_SetMission("China", missionName, zone[platformType].settings)

  if not m then
    return false
  end

  m = GameApi.ScenEdit_SetDoctrine({ side = "China", mission = missionName }, { automatic_evasion = false })

  if not m then
    return false
  end

  return true
end

--- Create cargo transport missions for all operational zones
--- Sets up ferry missions for landing craft and transport helicopters
--- Configures mission zones, settings, and doctrine (no automatic evasion)
---@param amphibOpsConfig SBJ__AmphibOpsConfig Amphibious operation configuration
---@return boolean True if all cargo missions were successfully created
function AmphibiousLogistics.createCargoMissions(amphibOpsConfig)
  local operationalZones = amphibOpsConfig.operationalZones

  for _, zone in ipairs(operationalZones) do
    for _, mission in ipairs(zone.boat.missions) do
      local result = handleCargoMission("boat", zone, mission.name)

      if not result then
        return false
      end
    end

    for _, mission in ipairs(zone.tansportHelicopter.missions) do
      local result = handleCargoMission("tansportHelicopter", zone, mission.name)

      if not result then
        return false
      end
    end
  end

  return true
end

--- Transfer cargo to embarked units and assign them to missions
--- Handles Type 075/076 LHDs (boats + transport/attack helicopters + recon UAVs)
--- Handles Type 071 LPDs (boats + transport helicopters)
--- Also processes transport aircraft from other bases
---@param config SBJ__CONFIG Global configuration for platform DBIDs
---@param amphibOpsConfig SBJ__AmphibOpsConfig Amphibious operation configuration
---@param unitsInAnchorageArea CMO__Unit[] Ships in anchorage area
---@return boolean True if all transfers and assignments completed successfully
function AmphibiousLogistics.transferAndAssign(config, amphibOpsConfig, unitsInAnchorageArea)
  local operationalZones = amphibOpsConfig.operationalZones

  for _, zone in ipairs(operationalZones) do
    for _, u in ipairs(unitsInAnchorageArea) do
      if (u.dbid == config.platform.TYPE_075 or u.dbid == config.platform.TYPE_076) and
          u:inArea(zone.anchorageArea) then
        AmphibiousLogistics.transferCargo(
          u.guid,
          'Boats',
          zone.boat.dbid,
          zone.boat.cargoItemsForTransfer.type075[1].loadoutId,
          zone.boat.cargoItemsForTransfer.type075[1].cargoItems
        )
        AmphibiousLogistics.transferCargo(
          u.guid,
          'Aircraft',
          zone.tansportHelicopter.dbid,
          zone.tansportHelicopter.cargoItemsForTransfer.type075[1].loadoutId,
          zone.tansportHelicopter.cargoItemsForTransfer.type075[1].cargoItems
        )
        AmphibiousLogistics.transferCargo(
          u.guid,
          'Aircraft',
          zone.tansportHelicopter.dbid,
          zone.tansportHelicopter.cargoItemsForTransfer.type075[2].loadoutId,
          zone.tansportHelicopter.cargoItemsForTransfer.type075[2].cargoItems
        )
        AssignMission.assignEmbarkedUnitsToMissions(
          u.guid,
          'Boats',
          zone.boat.dbid,
          zone.boat.missions
        )
        AssignMission.assignEmbarkedUnitsToMissions(
          u.guid,
          'Aircraft',
          zone.tansportHelicopter.dbid,
          zone.tansportHelicopter.missions
        )
        AssignMission.assignEmbarkedUnitsToMissions(
          u.guid,
          'Aircraft',
          zone.attackHelicopter.dbid,
          zone.attackHelicopter.missions
        )

        -- if zone.reconUAV then
        --   AssignMission.assignEmbarkedUnitsToMissions(
        --     u.guid,
        --     'Aircraft',
        --     zone.reconUAV.dbid,
        --     zone.reconUAV.missions
        --   )
        -- end
      end

      if u.dbid == config.platform.TYPE_071 and u:inArea(zone.anchorageArea) then
        AmphibiousLogistics.transferCargo(
          u.guid,
          'Boats',
          zone.boat.dbid,
          zone.boat.cargoItemsForTransfer.type071[1].loadoutId,
          zone.boat.cargoItemsForTransfer.type071[1].cargoItems
        )
        AmphibiousLogistics.transferCargo(
          u.guid,
          'Aircraft',
          zone.tansportHelicopter.dbid,
          zone.tansportHelicopter.cargoItemsForTransfer.type071[1].loadoutId,
          zone.tansportHelicopter.cargoItemsForTransfer.type071[1].cargoItems
        )
        AssignMission.assignEmbarkedUnitsToMissions(
          u.guid,
          'Boats',
          zone.boat.dbid,
          zone.boat.missions
        )
        AssignMission.assignEmbarkedUnitsToMissions(
          u.guid,
          'Aircraft',
          zone.tansportHelicopter.dbid,
          zone.tansportHelicopter.missions
        )
      end
    end
  end

  for _, item in ipairs(amphibOpsConfig.transportAircraft) do
    AmphibiousLogistics.transferCargo(
      item.guid,
      'Aircraft',
      item.dbid,
      item.cargoItemsForTransfer[1].loadoutId,
      item.cargoItemsForTransfer[1].cargoItems
    )
    AssignMission.assignEmbarkedUnitsToMissions(
      item.guid,
      'Aircraft',
      item.dbid,
      item.missions
    )
  end

  return true
end

--- Re-transfer cargo to embarked units for second wave operations
--- Reloads transport helicopters and landing craft on Type 075/076 and Type 071 ships
--- Used when returning units need fresh cargo for subsequent landing waves
---@param config SBJ__CONFIG Global configuration for platform DBIDs
---@param amphibOpsConfig SBJ__AmphibOpsConfig Amphibious operation configuration
---@param units CMO__SideUnit[] Unit list from the side (filtered for ships)
---@return boolean True if all cargo was successfully re-transferred
function AmphibiousLogistics.retransferCargos(config, amphibOpsConfig, units)
  local operationalZones = amphibOpsConfig.operationalZones

  for _, zone in ipairs(operationalZones) do
    for _, item in ipairs(units) do
      local unit = GameApi.ScenEdit_GetUnit(item.guid)

      if not unit then
        return false
      end

      if unit and (unit.dbid == config.platform.TYPE_075 or unit.dbid == config.platform.TYPE_076) then
        AmphibiousLogistics.transferCargo(
          unit.guid,
          'Boats',
          zone.boat.dbid,
          zone.boat.cargoItemsForTransfer.type075[1].loadoutId,
          zone.boat.cargoItemsForTransfer.type075[1].cargoItems
        )
        AmphibiousLogistics.transferCargo(
          unit.guid,
          'Aircraft',
          zone.tansportHelicopter.dbid,
          zone.tansportHelicopter.cargoItemsForTransfer.type075[1].loadoutId,
          zone.tansportHelicopter.cargoItemsForTransfer.type075[1].cargoItems
        )
        AmphibiousLogistics.transferCargo(
          unit.guid,
          'Aircraft',
          zone.tansportHelicopter.dbid,
          zone.tansportHelicopter.cargoItemsForTransfer.type075[2].loadoutId,
          zone.tansportHelicopter.cargoItemsForTransfer.type075[2].cargoItems
        )
      end

      if unit and unit.dbid == config.platform.TYPE_071 then
        AmphibiousLogistics.transferCargo(
          unit.guid,
          'Boats',
          zone.boat.dbid,
          zone.boat.cargoItemsForTransfer.type071[1].loadoutId,
          zone.boat.cargoItemsForTransfer.type071[1].cargoItems
        )
        AmphibiousLogistics.transferCargo(
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
