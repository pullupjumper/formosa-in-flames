local GameApi = require("src.utils.gameApi")
local constants = require("src.core.constants")
local Shared = require("src.modules.missileSystem.shared")
local AmphibiousLogistics = require("src.modules.landingOps.amphibiousLogistics")

local Concealment = {}

---Check if a unit is already loaded in the building's cargo
---@param building CMO__Unit Building to check for cargo
---@param unitGUID? string GUID of the unit to find in cargo
---@return boolean # Whether the unit is loaded in the building
function Concealment.isHideSiteOccupied(building, unitGUID)
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
---@param unitCtx SBJ__FiringUnitContext|SBJ__ResupplyUnitContext Unit context with operational area
---@param sideName string Side name
---@return CMO__Unit[]|nil # Array of building units or nil
function Concealment.findBuildingsInMaskArea(unitCtx, sideName)
  local side = GameApi.VP_GetSide({ name = sideName })
  if not side or not side.unitsInArea or not unitCtx.operationalArea.mask or not unitCtx.operationalArea.mask.area then
    return nil
  end

  return side:unitsInArea({
    Area = unitCtx.operationalArea.mask.area,
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
function Concealment.getRandomBuilding(buildings)
  local buildingsWithoutOccupied = {}

  for _, item in ipairs(buildings) do
    local building = GameApi.ScenEdit_GetUnit(item.guid)
    if building and not Concealment.isHideSiteOccupied(building) then
      table.insert(buildingsWithoutOccupied, building)
    end
  end

  if #buildingsWithoutOccupied == 0 then return nil end

  local idx = math.random(#buildingsWithoutOccupied)
  return buildingsWithoutOccupied[idx]
end

---Unload firing unit group from hide area buildings
---@param unitCtx SBJ__FiringUnitContext|SBJ__ResupplyUnitContext Unit context with operational area
---@param unit CMO__Unit Firing unit to unload
---@return boolean success Whether unload was performed
---@return table<string, any>? errorFields Log fields describing the failure
function Concealment.moveFromHideArea(unitCtx, unit)
  local group = Shared.getGroupUnits(unit)
  local buildings = Concealment.findBuildingsInMaskArea(unitCtx, unit.side)

  if not buildings then
    return false, { reason = "no_buildings_in_mask", area = unitCtx.operationalArea.name }
  end

  for _, u in ipairs(buildings) do
    local building = GameApi.ScenEdit_GetUnit(u.guid)

    if building then
      for _, firingUnitGUID in ipairs(group) do
        if Concealment.isHideSiteOccupied(building, firingUnitGUID) then
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
---@param unitCtx SBJ__FiringUnitContext|SBJ__ResupplyUnitContext Unit context with operational area
---@param unit CMO__Unit Firing unit to hide
---@return boolean success Whether hide was performed
---@return table<string, any>? errorFields Log fields describing the failure
function Concealment.hideUnit(unitCtx, unit)
  local buildings = Concealment.findBuildingsInMaskArea(unitCtx, unit.side)

  if not buildings then
    return false, { reason = "no_buildings_in_mask", area = unitCtx.operationalArea.name }
  end

  local building = Concealment.getRandomBuilding(buildings)

  if not building then
    return false, { reason = "no_available_building", area = unitCtx.operationalArea.name }
  end

  AmphibiousLogistics.loadCargo(building, unitCtx, unit.side)
  return true, nil
end

return Concealment
