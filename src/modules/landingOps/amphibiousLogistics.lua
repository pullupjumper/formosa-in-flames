local GameApi = require("src.utils.gameApi")
local Utils = require("src.utils.utils")
local AssignMission = require("src.modules.assignMission")
local constants = require("src.core.constants")

local AmphibiousLogistics = {}

---Transfer cargo from one unit to another
---Deletes specified cargo from source unit and creates them on destination unit
---@param fromUnit CMO__Unit Source unit (typically the mother ship)
---@param toUnit CMO__Unit Destination unit (aircraft or boat to receive cargo)
---@param cargoItem SBJ__CargoDescriptor Cargo specification (type, DBID, quantity)
function AmphibiousLogistics.updateCargo(fromUnit, toUnit, cargoItem)
  local filteredCargos = {}
  local count = 0

  if fromUnit == nil or fromUnit.cargo[1].cargo == nil then
    return
  end

  for _, element in ipairs(fromUnit.cargo[1].cargo) do
    if element.dbid == cargoItem.dbid then
      table.insert(filteredCargos, element.GUID)
      count = count + 1
    end

    if count == cargoItem.num then
      break
    end
  end

  for _, guid in ipairs(filteredCargos) do
    fromUnit:deleteUnitCargo(guid)
  end

  for i = 1, cargoItem.num, 1 do
    toUnit:createUnitCargo(cargoItem.type, cargoItem.dbid)
  end
end

---Delete specified cargo from a unit
---Returns the actual number of items deleted (may be less than requested)
---@param fromUnit CMO__Unit Unit to remove cargo from
---@param cargoItem SBJ__CargoDescriptor Cargo specification (type, DBID, quantity)
---@return integer # Number of cargo items actually deleted
function AmphibiousLogistics.deleteCargo(fromUnit, cargoItem)
  local filteredCargos = {}
  local count = 0
  local resultCount = 0

  if fromUnit == nil or
      fromUnit.cargo == nil or
      cargoItem.num == 0 or
      (fromUnit.cargo and fromUnit.cargo[1] == nil) then
    return 0
  end

  for _, element in ipairs(fromUnit.cargo[1].cargo) do
    if element.dbid == cargoItem.dbid then
      table.insert(filteredCargos, element.GUID)
      count = count + 1
    end

    if count == cargoItem.num then
      break
    end
  end

  for _, guid in ipairs(filteredCargos) do
    local result = fromUnit:deleteUnitCargo(guid)

    if result then
      resultCount = resultCount + 1
    end
  end

  return resultCount
end

---Transfer cargo from base to multiple embarked units
---Distributes cargo to embarked platforms matching DBID/loadout, supports per-unit or shared cargo lists
---@param fromUnit string GUID of the base unit containing embarked platforms
---@param platformType string Type of embarked unit ('Aircraft' or 'Boats')
---@param platformDBID number Database ID of the platform to receive cargo
---@param loadoutDBID number Loadout ID for aircraft filtering (ignored for boats)
---@param cargoItems table<integer, SBJ__CargoDescriptor[]> Cargo items to transfer (single list or per-unit)
function AmphibiousLogistics.transferCargo(fromUnit, platformType, platformDBID, loadoutDBID, cargoItems)
  local base = GameApi.ScenEdit_GetUnit(fromUnit)

  if not base then
    return
  end

  local platforms = base.embarkedUnits[platformType]
  local baseContainingCargo = base

  if platforms then
    local count = Utils.getCount(cargoItems)

    for idx, guid in ipairs(platforms) do
      local unit = GameApi.ScenEdit_GetUnit(guid)

      if unit then
        if platformType == "Aircraft" then
          if unit.dbid == platformDBID and unit.loadoutdbid == loadoutDBID then
            if count > 1 then
              for _, item in ipairs(cargoItems[idx]) do
                AmphibiousLogistics.updateCargo(baseContainingCargo, unit, item)
              end
            else
              for _, item in ipairs(cargoItems[1]) do
                AmphibiousLogistics.updateCargo(baseContainingCargo, unit, item)
              end
            end
          end
        else
          if unit.dbid == platformDBID then
            if count > 1 then
              for _, item in ipairs(cargoItems[idx]) do
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

---Get units in anchorage area and check their movement status
---Filters amphibious ships (LHD/LPD/LST) and determines if all are ready for cargo operations
---@param amphibOpsConfig SBJ__AmphibOpsConfig Amphibious operation configuration
---@param filteredUnits CMO__SideUnit Unit list from the side (filtered for ships)
---@return { units: CMO__Unit[], isUnitMoving: boolean } # Units in anchorage and movement status
function AmphibiousLogistics.getUnitsInAnchorageArea(amphibOpsConfig, filteredUnits)
  local operationalZones = amphibOpsConfig.operationalZones
  local unitsInAnchorageArea = {}
  local isUnitMoving = false

  for _, u in ipairs(filteredUnits) do
    local unit = GameApi.ScenEdit_GetUnit(u.guid)

    if unit and (unit.dbid == constants.PLATFORMS.TYPE_075 or
          unit.dbid == constants.PLATFORMS.TYPE_071 or
          unit.dbid == constants.PLATFORMS.TYPE_072III or
          unit.dbid == constants.PLATFORMS.TYPE_072A or
          unit.dbid == constants.PLATFORMS.TYPE_073A or
          unit.dbid == constants.PLATFORMS.TYPE_072A_2 or
          unit.dbid == constants.PLATFORMS.TYPE_076 or
          unit.dbid == constants.PLATFORMS.FERRY or
          unit.dbid == constants.PLATFORMS.BARGE) then
      if unit.unitstate ~= "Unassigned" then
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

---Create a cargo transport mission for a specific platform type
---Sets up mission zone, configuration, and doctrine with automatic evasion disabled
---@param platformType string The type of platform to filter (e.g., 'tansportHelicopter', 'boat')
---@param zone SBJ__OperationalZoneDescriptor Operation zone descriptor with mission settings
---@param missionName string Name for the cargo mission
---@return boolean # True if mission was successfully created and configured
local function handleCargoMission(platformType, zone, missionName)
  ---@type SBJ__BoatMissionDescriptor|SBJ__TransportHelicopterDescriptor
  local descriptor = zone[platformType]
  local m = GameApi.ScenEdit_AddMission("China", missionName, "Cargo", { zone = descriptor.zone })

  if not m then
    return false
  end

  m = GameApi.ScenEdit_SetMission("China", missionName, descriptor.settings)

  if not m then
    return false
  end

  m = GameApi.ScenEdit_SetDoctrine({ side = "China", mission = missionName }, { automatic_evasion = false })

  if not m then
    return false
  end

  return true
end

---Create cargo transport missions for all operational zones
---Sets up ferry missions for landing craft and transport helicopters with configured doctrine
---@param amphibOpsConfig SBJ__AmphibOpsConfig Amphibious operation configuration
---@return boolean # True if all cargo missions were successfully created
function AmphibiousLogistics.createCargoMissions(amphibOpsConfig)
  local operationalZones = amphibOpsConfig.operationalZones

  for _, zone in ipairs(operationalZones) do
    for _, mission in ipairs(zone.boat.missions) do
      local result = handleCargoMission("boat", zone, mission.name)

      if not result then
        return false
      end
    end

    for _, mission in ipairs(zone.transportHelicopter.missions) do
      local result = handleCargoMission("transportHelicopter", zone, mission.name)

      if not result then
        return false
      end
    end
  end

  return true
end

---Transfer cargo to embarked units and assign them to missions
---Handles Type 075/076 LHDs, Type 071 LPDs, and transport aircraft from other bases
---@param amphibOpsConfig SBJ__AmphibOpsConfig Amphibious operation configuration
---@param unitsInAnchorageArea CMO__Unit[] Ships in anchorage area
---@return boolean # True if all transfers and assignments completed successfully
function AmphibiousLogistics.transferAndAssign(amphibOpsConfig, unitsInAnchorageArea)
  local operationalZones = amphibOpsConfig.operationalZones

  for _, zone in ipairs(operationalZones) do
    for _, u in ipairs(unitsInAnchorageArea) do
      if (u.dbid == constants.PLATFORMS.TYPE_075 or u.dbid == constants.PLATFORMS.TYPE_076) and
          u:inArea(zone.anchorageArea) then
        AmphibiousLogistics.transferCargo(
          u.guid,
          "Boats",
          zone.boat.dbid,
          zone.boat.transferManifest.type075[1].loadoutId,
          zone.boat.transferManifest.type075[1].cargoItems
        )
        AmphibiousLogistics.transferCargo(
          u.guid,
          "Aircraft",
          zone.transportHelicopter.dbid,
          zone.transportHelicopter.transferManifest.type075[1].loadoutId,
          zone.transportHelicopter.transferManifest.type075[1].cargoItems
        )
        AmphibiousLogistics.transferCargo(
          u.guid,
          "Aircraft",
          zone.transportHelicopter.dbid,
          zone.transportHelicopter.transferManifest.type075[2].loadoutId,
          zone.transportHelicopter.transferManifest.type075[2].cargoItems
        )
        AssignMission.assignEmbarkedUnitsToMissions(
          u.guid,
          "Boats",
          zone.boat.dbid,
          zone.boat.missions
        )
        AssignMission.assignEmbarkedUnitsToMissions(
          u.guid,
          "Aircraft",
          zone.transportHelicopter.dbid,
          zone.transportHelicopter.missions
        )
        AssignMission.assignEmbarkedUnitsToMissions(
          u.guid,
          "Aircraft",
          zone.attackHelicopter.dbid,
          zone.attackHelicopter.missions
        )
      end

      if u.dbid == constants.PLATFORMS.TYPE_071 and u:inArea(zone.anchorageArea) then
        AmphibiousLogistics.transferCargo(
          u.guid,
          "Boats",
          zone.boat.dbid,
          zone.boat.transferManifest.type071[1].loadoutId,
          zone.boat.transferManifest.type071[1].cargoItems
        )
        AmphibiousLogistics.transferCargo(
          u.guid,
          "Aircraft",
          zone.transportHelicopter.dbid,
          zone.transportHelicopter.transferManifest.type071[1].loadoutId,
          zone.transportHelicopter.transferManifest.type071[1].cargoItems
        )
        AssignMission.assignEmbarkedUnitsToMissions(
          u.guid,
          "Boats",
          zone.boat.dbid,
          zone.boat.missions
        )
        AssignMission.assignEmbarkedUnitsToMissions(
          u.guid,
          "Aircraft",
          zone.transportHelicopter.dbid,
          zone.transportHelicopter.missions
        )
      end
    end
  end

  for _, item in ipairs(amphibOpsConfig.transportAircraft) do
    AmphibiousLogistics.transferCargo(
      item.guid,
      "Aircraft",
      item.dbid,
      item.cargoItemsForTransfer[1].loadoutId,
      item.cargoItemsForTransfer[1].cargoItems
    )
    AssignMission.assignEmbarkedUnitsToMissions(
      item.guid,
      "Aircraft",
      item.dbid,
      item.missions
    )
  end

  return true
end

---Re-transfer cargo to embarked units for second wave operations
---Reloads transport helicopters and landing craft on Type 075/076 and Type 071 ships
---@param amphibOpsConfig SBJ__AmphibOpsConfig Amphibious operation configuration
---@param units CMO__SideUnit[] Unit list from the side (filtered for ships)
---@return boolean # True if all cargo was successfully re-transferred
function AmphibiousLogistics.retransferCargos(amphibOpsConfig, units)
  local operationalZones = amphibOpsConfig.operationalZones

  for _, zone in ipairs(operationalZones) do
    for _, u in ipairs(units) do
      local unit = GameApi.ScenEdit_GetUnit(u.guid)

      if not unit then
        return false
      end

      if unit and (unit.dbid == constants.PLATFORMS.TYPE_075 or unit.dbid == constants.PLATFORMS.TYPE_076) then
        AmphibiousLogistics.transferCargo(
          unit.guid,
          "Boats",
          zone.boat.dbid,
          zone.boat.transferManifest.type075[1].loadoutId,
          zone.boat.transferManifest.type075[1].cargoItems
        )
        AmphibiousLogistics.transferCargo(
          unit.guid,
          "Aircraft",
          zone.transportHelicopter.dbid,
          zone.transportHelicopter.transferManifest.type075[1].loadoutId,
          zone.transportHelicopter.transferManifest.type075[1].cargoItems
        )
        AmphibiousLogistics.transferCargo(
          unit.guid,
          "Aircraft",
          zone.transportHelicopter.dbid,
          zone.transportHelicopter.transferManifest.type075[2].loadoutId,
          zone.transportHelicopter.transferManifest.type075[2].cargoItems
        )
      end

      if unit and unit.dbid == constants.PLATFORMS.TYPE_071 then
        AmphibiousLogistics.transferCargo(
          unit.guid,
          "Boats",
          zone.boat.dbid,
          zone.boat.transferManifest.type071[1].loadoutId,
          zone.boat.transferManifest.type071[1].cargoItems
        )
        AmphibiousLogistics.transferCargo(
          unit.guid,
          "Aircraft",
          zone.transportHelicopter.dbid,
          zone.transportHelicopter.transferManifest.type071[1].loadoutId,
          zone.transportHelicopter.transferManifest.type071[1].cargoItems
        )
      end
    end
  end

  return true
end

return AmphibiousLogistics
