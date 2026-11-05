local GameApi = require("src.utils.gameApi")
local constants = require("src.core.constants")
local Shared = require("src.modules.missileSystem.shared")
local CargoProxy = require("src.modules.missileSystem.cargoProxy")

local Concealment = {}

---Check if a unit is already loaded in the building's cargo
---@param building CMO__Unit
---@param unitGUID? string
---@return boolean # Whether the unit is loaded in the building
local function isHideSiteOccupied(building, unitGUID)
  if not building.cargo or not building.cargo[1] or not building.cargo[1].cargo then
    return false
  end

  if unitGUID then
    for _, item in ipairs(building.cargo[1].cargo) do
      if item.guid == unitGUID then
        return true
      end
    end

    return false
  end

  return true
end

---Find buildings within the mask area for TEL concealment
---@param operationalArea SBJ__OperationalArea
---@param sideName string
---@return CMO__SideUnit[]|nil # Array of building units or nil
local function findBuildingsInMaskArea(operationalArea, sideName)
  local side = GameApi.VP_GetSide({ name = sideName })
  if not side or not side.unitsInArea or not operationalArea.mask or not operationalArea.mask.area then
    return nil
  end

  return side:unitsInArea({
    Area = operationalArea.mask.area,
    TargetFilter = {
      TargetType = constants.UNIT_TYPES.FACILITY,
      TargetSubType = constants.FIXED_FACILITY_CATEGORIES.BUILDING_SURFACE,
      SpecificUnitClass = constants.PLATFORMS.BUILDING,
      TargetSide = sideName
    }
  })
end

---Select a random unoccupied building from the list
---@param buildings CMO__SideUnit[]
---@return CMO__Unit|nil # Random building from the list that is not occupied by a hide site
local function getRandomBuilding(buildings)
  local buildingsWithoutOccupied = {}

  for _, item in ipairs(buildings) do
    local building = GameApi.ScenEdit_GetUnit(item.guid)
    if building and not isHideSiteOccupied(building) then
      table.insert(buildingsWithoutOccupied, building)
    end
  end

  if #buildingsWithoutOccupied == 0 then return nil end

  local idx = math.random(#buildingsWithoutOccupied)
  return buildingsWithoutOccupied[idx]
end

---Unload firing unit group from hide area buildings
---@param unitState SBJ__FiringUnitState|SBJ__ResupplyUnitState
---@param unit CMO__Unit
---@return boolean success Whether unload was performed
---@return table<string, any>? errorFields Log fields describing the failure
function Concealment.moveFromHideArea(unitState, unit)
  local group = Shared.getGroupUnits(unit)
  local buildings = findBuildingsInMaskArea(unitState.operationalArea, unit.side)

  if not buildings then
    return false, { reason = "no_buildings_in_mask", area = unitState.operationalArea.name }
  end

  for _, sideUnit in ipairs(buildings) do
    local building = GameApi.ScenEdit_GetUnit(sideUnit.guid)

    if building then
      for _, firingUnitGUID in ipairs(group) do
        if isHideSiteOccupied(building, firingUnitGUID) then
          GameApi.ScenEdit_UnloadCargo(building.guid, { firingUnitGUID })
        end
      end
    end
  end

  return true, nil
end

---Load firing unit into a random building within mask area
---Failure fields omit the unit name because every caller already labels the row
---with the unit it was acting on.
---@param unitState SBJ__FiringUnitState|SBJ__ResupplyUnitState
---@param unit CMO__Unit
---@param weaponDBID number|number[]|nil Firing unit weapons kept in the cargo proxy; nil for a resupply unit
---@return boolean success Whether hide was performed
---@return table<string, any>? errorFields Log fields describing the failure
function Concealment.hideUnit(unitState, unit, weaponDBID)
  local buildings = findBuildingsInMaskArea(unitState.operationalArea, unit.side)

  if not buildings then
    return false, { reason = "no_buildings_in_mask", area = unitState.operationalArea.name }
  end

  local building = getRandomBuilding(buildings)

  if not building then
    return false, { reason = "no_available_building", area = unitState.operationalArea.name }
  end

  CargoProxy.loadCargo(building, unitState.name, weaponDBID, unit.side)
  return true, nil
end

---Add a bunker at each shelter point of an operational area
---@param operationalArea SBJ__OperationalArea
---@param sideName string
---@return boolean # Whether every bunker was added; false when the area has no shelter points
function Concealment.addBunkers(operationalArea, sideName)
  if not operationalArea.shelterPoints then return false end

  for idx, point in ipairs(operationalArea.shelterPoints) do
    local addedUnit = GameApi.ScenEdit_AddUnit({
      side = sideName,
      unitname = "BUNKER/" .. operationalArea.name .. "/" .. tostring(idx),
      dbid = constants.PLATFORMS.BUILDING,
      type = constants.UNIT_TYPES.FACILITY,
      latitude = point.latitude,
      longitude = point.longitude
    })

    if not addedUnit then return false end
  end

  return true
end

---Remove every building inside the mask areas being left
---@param operationalAreas SBJ__OperationalArea[]
---@param sideName string
---@return integer removedCount Number of buildings removed
---@return boolean allSuccessful Whether every building was removed
function Concealment.removeBunkers(operationalAreas, sideName)
  local removedCount = 0
  local allSuccessful = true

  for _, operationalArea in ipairs(operationalAreas) do
    for _, building in ipairs(findBuildingsInMaskArea(operationalArea, sideName) or {}) do
      if GameApi.ScenEdit_DeleteUnit({ guid = building.guid }) then
        removedCount = removedCount + 1
      else
        allSuccessful = false
      end
    end
  end

  return removedCount, allSuccessful
end

return Concealment
