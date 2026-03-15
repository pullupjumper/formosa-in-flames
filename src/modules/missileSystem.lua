local Utils = require("src.utils.utils")
local GameApi = require("src.utils.gameApi")
local Logger = require("src.utils.logger")
local constants = require("src.core.constants")
local GameUtils = require("src.utils.gameUtils")
local AmphibiousLogistics = require("src.modules.landingOps.amphibiousLogistics")

local MissileSystem = {}

-- ============================================================================
-- Enumerations and Constants
-- ============================================================================

local MISSILE_SYSTEM_TAG = "missileSystem"

---@type table<number, true>
local SAM_DBIDS = {
  [constants.PLATFORMS.PAC3] = true,
  [constants.PLATFORMS.SKY_GUARD] = true,
  [constants.PLATFORMS.TC2] = true,
  [constants.PLATFORMS.CUSTOMED_TK3] = true,
  [constants.PLATFORMS.CUSTOMED_SAM] = true,
  [constants.PLATFORMS.S300] = true,
  [constants.PLATFORMS.S400] = true,
  [constants.PLATFORMS.HQ12] = true,
  [constants.PLATFORMS.HQ22] = true,
}

local ZONE_PATTERNS = {
  "^" .. constants.POSITION_TYPES.FIRING_POINT,
  "^" .. constants.POSITION_TYPES.HIDE_AREA,
  "^" .. constants.POSITION_TYPES.AMMO_HOLDING_AREA,
  "^" .. constants.POSITION_TYPES.RELOAD_POINT,
  "^" .. constants.POSITION_TYPES.MASK
}

local ZONE_COLORS = {
  RELOAD_POINT = "4dd9822b",
  HIDE_AREA = "4d137cbd",
  AMMO_HOLDING_AREA = "4d0f9960",
  MASK = "4dff6b6b",
  DEFAULT = "4d8b5cf6"
}

local MASK_ZONE = {
  LAND_COVER_HEIGHT = 1000,
  LAND_COVER_TYPE = 254,
}

-- ============================================================================
-- Unit Properties and Movement Helpers
-- ============================================================================

---Normalize weaponDBID to always be an array
---@param weaponDBID number|number[] Weapon DBID or array of weapon DBIDs
---@return number[]
local function normalizeWeaponDBIDs(weaponDBID)
  if type(weaponDBID) == "table" then
    return weaponDBID
  end
  return { weaponDBID }
end

---Check if a platform is a SAM system
---@param dbid number Platform database ID
---@return boolean # True if the platform is a SAM system
local function isSAM(dbid)
  return SAM_DBIDS[dbid] == true
end

---Get the list of unit GUIDs from a unit or its group
---@param unit CMO__Unit Unit or group leader
---@return string[] # Array of unit GUIDs
local function getGroupUnits(unit)
  return unit.group and unit.group.unitlist or { unit.guid }
end

---Set unit movement and weapon control status using table parameters
---@param params SBJ__SetUnitPropertiesParams Unit properties configuration table
local function setUnitProperties(params)
  local unit = params.unit
  if not unit then return end

  local unitSetParams = {
    guid = unit.guid,
    manualthrottle = params.throttle or "Stop",
    manualSpeed = params.speed or 0,
    holdposition = params.holdPosition == nil and true or params.holdPosition
  }

  if params.course then
    unitSetParams.course = params.course
  end

  GameApi.ScenEdit_SetUnit(unitSetParams)

  if params.wcs then
    local doctrine = { weapon_control_status_land = params.wcs }

    if isSAM(unit.dbid) then
      doctrine = { weapon_control_status_air = params.wcs }
    end

    GameApi.ScenEdit_SetDoctrine({ side = unit.side, guid = unit.guid }, doctrine)
  end

  if params.formation then
    unit.formation = params.formation
  end
end

---Apply properties to all units in a group
---@param firingUnit CMO__Unit Unit or group leader
---@param propsBuilder fun(unit: CMO__Unit): SBJ__SetUnitPropertiesParams Property builder function
local function applyToGroupUnits(firingUnit, propsBuilder)
  local units = getGroupUnits(firingUnit)
  for _, guid in ipairs(units) do
    local unit = GameApi.ScenEdit_GetUnit(guid)
    if unit then
      setUnitProperties(propsBuilder(unit))
    end
  end
end

---Build auto/manual mode unit properties
---@param unit CMO__Unit Target unit
---@param isAuto boolean Whether in automatic mode
---@param wcs integer Weapon control status
---@return SBJ__SetUnitPropertiesParams # Unit properties for the given mode
local function buildModeProperties(unit, isAuto, wcs)
  return {
    unit = unit,
    holdPosition = isAuto and true or false,
    throttle = isAuto and "Stop" or "OFF",
    speed = isAuto and 0 or "OFF",
    wcs = wcs,
    -- formation = isAuto and { spacing = 0, transpose = true } or nil
  }
end

-- ============================================================================
-- Movement Operations
-- ============================================================================

---Move units to a randomly selected position
---@param opts SBJ__MoveToPositionOpts Movement options
---@return boolean success Whether the move was successful
---@return string? errorMsg Error message if failed
local function moveUnitToPosition(opts)
  local posCount = Utils.getCount(opts.positions)
  if posCount == 0 then
    return false, string.format("No %s positions available for unit '%s' (OPAREA: %s)",
      opts.positionType, opts.unitName, opts.areaName)
  end

  local posIdx = math.random(posCount)
  local position = opts.positions[posIdx]

  if not position or not position.course then
    return false, string.format("Invalid %s position data at index %d for unit '%s' (OPAREA: %s)",
      opts.positionType, posIdx, opts.unitName, opts.areaName)
  end

  local course = position.course
  if opts.useLastCourse and type(course) == "table" and #course > 0 then
    course = { course[#course] }
  end

  applyToGroupUnits(opts.battery, function(unit)
    return {
      unit = unit,
      throttle = constants.THROTTLES.FULL,
      speed = constants.SPEEDS.NORMAL,
      course = course,
      holdPosition = false,
      wcs = opts.wcs
    }
  end)

  return true, nil
end

---Command firing unit to move to reload point (RL)
---@param unitCtx SBJ__FiringUnitContext|SBJ__ResupplyUnitContext Firing unit context
---@param unit CMO__Unit Firing unit group
---@return boolean success
---@return string? errorMsg
local function moveToReloadPoint(unitCtx, unit)
  unitCtx.state = constants.MISSILE_SYSTEM_STATE.REPOSITIONING
  return moveUnitToPosition({
    unitName = unitCtx.name,
    battery = unit,
    positions = unitCtx.operationalArea.RL,
    positionType = constants.POSITION_TYPES.RELOAD_POINT,
    areaName = unitCtx.operationalArea.name,
    wcs = constants.WCS.HOLD
  })
end

---Command firing unit to move to hide area (HA)
---@param firingUnitCtx SBJ__FiringUnitContext Firing unit context
---@param firingUnit CMO__Unit Firing unit group
---@return boolean success
---@return string? errorMsg
local function moveToHideArea(firingUnitCtx, firingUnit)
  if not firingUnitCtx.operationalArea.HA then
    return false, string.format("No HA defined for firing unit '%s' (OPAREA: %s), skipping hide movement",
      firingUnitCtx.name, firingUnitCtx.operationalArea.name)
  end

  firingUnitCtx.state = constants.MISSILE_SYSTEM_STATE.REPOSITIONING
  return moveUnitToPosition({
    unitName = firingUnitCtx.name,
    battery = firingUnit,
    positions = firingUnitCtx.operationalArea.HA,
    positionType = constants.POSITION_TYPES.HIDE_AREA,
    areaName = firingUnitCtx.operationalArea.name,
    wcs = constants.WCS.HOLD
  })
end

---Command resupply unit to move to ammunition holding area (AHA)
---@param resupplyUnitCtx SBJ__ResupplyUnitContext Resupply unit context
---@param resupplyUnit CMO__Unit Resupply unit group
---@return boolean success
---@return string? errorMsg
local function moveToAmmoHoldingArea(resupplyUnitCtx, resupplyUnit)
  resupplyUnitCtx.state = constants.MISSILE_SYSTEM_STATE.REPOSITIONING
  return moveUnitToPosition({
    unitName = resupplyUnitCtx.name,
    battery = resupplyUnit,
    positions = resupplyUnitCtx.operationalArea.AHA,
    positionType = constants.POSITION_TYPES.AMMO_HOLDING_AREA,
    areaName = resupplyUnitCtx.operationalArea.name
  })
end

---Command resupply unit to move to reload point (RL)
---@param resupplyUnitCtx SBJ__ResupplyUnitContext Resupply unit context
---@param resupplyUnit CMO__Unit Resupply unit group
---@return boolean success
---@return string? errorMsg
local function moveResupplyUnitToReloadPoint(resupplyUnitCtx, resupplyUnit)
  resupplyUnitCtx.state = constants.MISSILE_SYSTEM_STATE.REPOSITIONING
  return moveUnitToPosition({
    unitName = resupplyUnitCtx.name,
    battery = resupplyUnit,
    positions = resupplyUnitCtx.operationalArea.RL,
    positionType = constants.POSITION_TYPES.RELOAD_POINT,
    areaName = resupplyUnitCtx.operationalArea.name,
    useLastCourse = true
  })
end

---Check if a unit is already loaded in the building's cargo
---@param building CMO__Unit Building to check for cargo
---@param unitGUID? string GUID of the unit to find in cargo
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
---@param unitCtx SBJ__FiringUnitContext|SBJ__ResupplyUnitContext Unit context with operational area
---@param sideName string Side name
---@return CMO__Unit[]|nil # Array of building units or nil
local function findBuildingsInMaskArea(unitCtx, sideName)
  return GameApi.VP_GetSide({ name = sideName }):unitsInArea({
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

---Command firing unit to move to firing point (FP)
---@param firingUnitCtx SBJ__FiringUnitContext Firing unit context
---@param firingUnit CMO__Unit Firing unit group
---@return boolean success
---@return string? errorMsg
local function moveToFiringPoint(firingUnitCtx, firingUnit)
  firingUnitCtx.state = constants.MISSILE_SYSTEM_STATE.REPOSITIONING
  return moveUnitToPosition({
    unitName = firingUnitCtx.name,
    battery = firingUnit,
    positions = firingUnitCtx.operationalArea.FP,
    positionType = constants.POSITION_TYPES.FIRING_POINT,
    areaName = firingUnitCtx.operationalArea.name
  })
end

-- ============================================================================
-- Ammunition and Reload
-- ============================================================================

---Transfer ammunition from ammunition depot to resupply unit
---@param resupplyUnitCtx SBJ__ResupplyUnitContext Resupply unit context
---@param ammoDepotCtx SBJ__AmmunitionContext Ammunition depot context
local function transferAmmunition(resupplyUnitCtx, ammoDepotCtx)
  if ammoDepotCtx.wpnCurrent > 0 and resupplyUnitCtx.wpnCurrent < resupplyUnitCtx.wpnDefault then
    local deficit = resupplyUnitCtx.wpnDefault - resupplyUnitCtx.wpnCurrent
    local ammoToTransfer = math.min(deficit, ammoDepotCtx.wpnCurrent)
    resupplyUnitCtx.wpnCurrent = resupplyUnitCtx.wpnCurrent + ammoToTransfer
    ammoDepotCtx.wpnCurrent = ammoDepotCtx.wpnCurrent - ammoToTransfer
  end

  resupplyUnitCtx.state = constants.MISSILE_SYSTEM_STATE.STATIC
  resupplyUnitCtx.reloadStartTime = nil
end

---Reload ammunition for a single unit
---@param unit CMO__Unit|nil Unit object
---@param weaponDBID number|number[] Weapon database ID(s)
---@param resupplyUnitCtx SBJ__ResupplyUnitContext Resupply unit context
---@return integer # Total ammunition consumed
local function reloadUnit(unit, weaponDBID, resupplyUnitCtx)
  if not unit then return 0 end
  local weaponDBIDs = normalizeWeaponDBIDs(weaponDBID)
  local totalLoaded = 0

  for _, dbid in ipairs(weaponDBIDs) do
    local wpnInfo = GameUtils.getWeaponInfo(unit, dbid)
    local required = wpnInfo.maxWeapons - wpnInfo.availableWeapons

    if required > 0 and resupplyUnitCtx.wpnCurrent > 0 then
      local ammoToLoad = math.min(required, resupplyUnitCtx.wpnCurrent)
      GameApi.ScenEdit_AddReloadsToUnit({ guid = unit.guid, side = unit.side, wpn_dbid = dbid, number = ammoToLoad })
      resupplyUnitCtx.wpnCurrent = resupplyUnitCtx.wpnCurrent - ammoToLoad
      totalLoaded = totalLoaded + ammoToLoad
    end
  end

  return totalLoaded
end

---Execute reload for firing unit
---@param firingUnitCtx SBJ__FiringUnitContext Firing unit context
---@param resupplyUnitCtx SBJ__ResupplyUnitContext Resupply unit context
---@param weaponDBID number|number[] Weapon database ID(s)
---@param sideName string Side name
---@return integer # Total ammunition loaded
local function reload(firingUnitCtx, resupplyUnitCtx, weaponDBID, sideName)
  local firingUnit = GameApi.ScenEdit_GetUnit(firingUnitCtx.name, sideName)
  if not firingUnit then return 0 end
  local units = getGroupUnits(firingUnit)

  local totalLoaded = 0
  for _, guid in ipairs(units) do
    local unit = GameApi.ScenEdit_GetUnit(guid)
    totalLoaded = totalLoaded + reloadUnit(unit, weaponDBID, resupplyUnitCtx)
  end

  firingUnitCtx.state = constants.MISSILE_SYSTEM_STATE.STATIC
  firingUnitCtx.reloadStartTime = nil
  return totalLoaded
end

-- ============================================================================
-- Area Detection and Meeting
-- ============================================================================

---Find the area where the unit is located
---@param unit CMO__Unit Unit object
---@param operationalArea SBJ__OperationalArea Position information table
---@return string[]|nil # Area reference points or nil
local function findUnitArea(unit, operationalArea)
  for _, pos in ipairs(operationalArea.RL) do
    if unit:inArea(pos.area) then
      return pos.area
    end
  end

  return nil
end

---Check if a unit state is valid for meeting in the given mode
---@param state integer Unit state
---@param isAuto boolean Whether in automatic mode
---@return boolean # Whether the state allows meeting
local function isValidStateForMeeting(state, isAuto)
  if not isAuto then
    return true
  end
  return state == constants.MISSILE_SYSTEM_STATE.REPOSITIONING or state == constants.MISSILE_SYSTEM_STATE.RELOAD
end

---Check if reload is required between a target and its counterpart
---@param targetCtx SBJ__FiringUnitContext|SBJ__ResupplyUnitContext Target unit context
---@param counterpartCtx SBJ__FiringUnitContext|SBJ__ResupplyUnitContext Counterpart unit context
---@param unit CMO__Unit Target unit for ammo check
---@param counterpart CMO__Unit Counterpart unit for ammo check
---@return boolean # Whether reload is required
local function isReloadRequired(targetCtx, counterpartCtx, unit, counterpart)
  local isFiringUnitCtx = targetCtx.weaponDBID ~= nil

  if isFiringUnitCtx then
    return MissileSystem.isLowAmmo(unit, targetCtx.ammoThreshold, targetCtx.weaponDBID) and counterpartCtx.wpnCurrent > 0
  end

  return MissileSystem.isLowAmmo(counterpart, counterpartCtx.ammoThreshold, counterpartCtx.weaponDBID) and
      targetCtx.wpnCurrent > 0
end

---Check if a unit has met with any counterpart in the same reload area
---@param unitCtx SBJ__FiringUnitContext|SBJ__ResupplyUnitContext Unit context to check
---@param unitName string Unit name to match against unitCtx.name
---@param counterpartList table<string, SBJ__FiringUnitContext|SBJ__ResupplyUnitContext> Counterpart units to check
---@param unit CMO__Unit Unit object for area checking
---@param isAuto boolean Whether in automatic mode
---@return boolean hasMet Whether units have met
---@return SBJ__FiringUnitContext|SBJ__ResupplyUnitContext|nil matchedUnitCtx The unit context that was matched
local function checkMeetingInArea(unitCtx, unitName, counterpartList, unit, isAuto)
  if unitCtx.name ~= unitName or not isValidStateForMeeting(unitCtx.state, isAuto) then
    return false, nil
  end

  local area = findUnitArea(unit, unitCtx.operationalArea)
  if not area then return false, nil end

  for _, counterpartCtx in pairs(counterpartList) do
    local counterpart = GameApi.ScenEdit_GetUnit(counterpartCtx.name, unit.side)
    if counterpart and counterpart:inArea(area)
        and isReloadRequired(unitCtx, counterpartCtx, unit, counterpart) then
      return true, unitCtx
    end
  end

  return false, nil
end

---Search for a meeting match between a unit list and counterpart list
---@param unitList table<string, SBJ__FiringUnitContext|SBJ__ResupplyUnitContext> Units to iterate
---@param unitName string Unit name to match
---@param counterpartList table<string, SBJ__FiringUnitContext|SBJ__ResupplyUnitContext> Counterpart units
---@param unit CMO__Unit Unit object for area checking
---@param isAuto boolean Whether in automatic mode
---@return boolean hasMet Whether units have met
---@return SBJ__FiringUnitContext|SBJ__ResupplyUnitContext|nil matchedUnitCtx The matched context
local function findMeetingMatch(unitList, unitName, counterpartList, unit, isAuto)
  for _, unitCtx in pairs(unitList) do
    local hasMet, matchedCtx = checkMeetingInArea(unitCtx, unitName, counterpartList, unit, isAuto)
    if hasMet then return true, matchedCtx end
  end
  return false, nil
end

-- ============================================================================
-- Reload Cycle Orchestration
-- ============================================================================

---Check if firing unit reload conditions are met
---@param firingUnitCtx SBJ__FiringUnitContext Firing unit context
---@param systemCtx SBJ__MissileSystemContext Weapon system context
---@param hasMet boolean Whether firing unit has met with resupply unit
---@param firingUnit CMO__Unit Firing unit group
---@param weaponDBID number|number[] Weapon database ID(s)
---@return boolean # Whether reload conditions are met
local function isReadyToReloadFiringUnit(firingUnitCtx, systemCtx, hasMet, firingUnit, weaponDBID)
  if firingUnitCtx.reloadStartTime == nil then return false end
  local elapsedTime = GameApi.ScenEdit_CurrentTime() - firingUnitCtx.reloadStartTime
  return elapsedTime >= systemCtx.reloadTime and hasMet and
      MissileSystem.isLowAmmo(firingUnit, firingUnitCtx.ammoThreshold, weaponDBID)
end

---Check if resupply unit reload conditions are met
---@param resupplyUnitCtx SBJ__ResupplyUnitContext Resupply unit context
---@param systemCtx SBJ__MissileSystemContext Weapon system context
---@param hasMet boolean Whether resupply unit has met with ammunition depot
---@return boolean # Whether reload conditions are met
local function isReadyToReloadResupplyUnit(resupplyUnitCtx, systemCtx, hasMet)
  if resupplyUnitCtx.reloadStartTime == nil then return false end
  local elapsedTime = GameApi.ScenEdit_CurrentTime() - resupplyUnitCtx.reloadStartTime
  return elapsedTime >= systemCtx.reloadTime and resupplyUnitCtx.wpnCurrent == 0 and hasMet
end

---Trigger reload movement when firing unit is static and low on ammo (auto mode only)
---@param systemCtx SBJ__MissileSystemContext Weapon system context
---@param firingUnitCtx SBJ__FiringUnitContext Firing unit context
---@param firingUnit CMO__Unit Firing unit group
---@param isAuto boolean Whether in automatic mode
local function triggerReloadMovement(systemCtx, firingUnitCtx, firingUnit, isAuto)
  if not isAuto or firingUnitCtx.state ~= constants.MISSILE_SYSTEM_STATE.STATIC then
    return
  end

  if not MissileSystem.isLowAmmo(firingUnit, firingUnitCtx.ammoThreshold, firingUnitCtx.weaponDBID) then
    return
  end

  local resupplyUnitCtx = systemCtx.resupplyUnits[firingUnitCtx.resupplyUnit]
  local resupplyUnit = GameApi.ScenEdit_GetUnit(resupplyUnitCtx.name, firingUnit.side)

  if resupplyUnit then
    MissileSystem.moveFromHideArea(resupplyUnitCtx, resupplyUnit)
    moveToReloadPoint(resupplyUnitCtx, resupplyUnit)
  end

  moveToReloadPoint(firingUnitCtx, firingUnit)
end

---Complete firing unit reload when conditions are met
---@param systemCtx SBJ__MissileSystemContext Weapon system context
---@param firingUnitCtx SBJ__FiringUnitContext Firing unit context
---@param firingUnit CMO__Unit Firing unit group
---@param isAuto boolean Whether in automatic mode
---@return SBJ__ReloadCycleResult|nil result Structured result if reload was completed
local function completeFiringUnitReload(systemCtx, firingUnitCtx, firingUnit, isAuto)
  if firingUnitCtx.state ~= constants.MISSILE_SYSTEM_STATE.RELOAD then
    return nil
  end

  if firingUnitCtx.reloadStartTime == nil then
    firingUnitCtx.reloadStartTime = GameApi.ScenEdit_CurrentTime()
  end

  local hasMet = MissileSystem.hasMetResupplyUnit(systemCtx, firingUnit, isAuto)
  local isReadyToReload = isReadyToReloadFiringUnit(
    firingUnitCtx, systemCtx, hasMet, firingUnit, firingUnitCtx.weaponDBID)

  if not isReadyToReload then
    return nil
  end

  local resupplyUnitCtx = systemCtx.resupplyUnits[firingUnitCtx.resupplyUnit]
  local resupplyUnit = GameApi.ScenEdit_GetUnit(resupplyUnitCtx.name, firingUnit.side)
  reload(firingUnitCtx, resupplyUnitCtx, firingUnitCtx.weaponDBID, firingUnit.side)

  if isAuto then
    if resupplyUnit and resupplyUnitCtx.wpnCurrent > 0 and findUnitArea(resupplyUnit, resupplyUnitCtx.operationalArea) then
      MissileSystem.hideUnit(resupplyUnitCtx, resupplyUnit)
    end
    moveToHideArea(firingUnitCtx, firingUnit)
  end

  return { tag = "OK", unitName = firingUnitCtx.name, action = "Missile reload finished" }
end

---Handle firing unit reload cycle: trigger movement and complete reload
---@param systemCtx SBJ__MissileSystemContext Weapon system context
---@param firingUnitCtx SBJ__FiringUnitContext Firing unit context
---@param firingUnit CMO__Unit Firing unit group
---@param isAuto boolean Whether in automatic mode
---@return SBJ__ReloadCycleResult|nil result Structured result if action was taken
local function handleFiringUnitReloadCycle(systemCtx, firingUnitCtx, firingUnit, isAuto)
  triggerReloadMovement(systemCtx, firingUnitCtx, firingUnit, isAuto)
  return completeFiringUnitReload(systemCtx, firingUnitCtx, firingUnit, isAuto)
end

---Trigger resupply movement when resupply unit is static and out of ammo (auto mode only)
---@param resupplyUnitCtx SBJ__ResupplyUnitContext Resupply unit context
---@param resupplyUnit CMO__Unit Resupply unit group
---@param isAuto boolean Whether in automatic mode
local function triggerResupplyMovement(resupplyUnitCtx, resupplyUnit, isAuto)
  if not isAuto or resupplyUnitCtx.state ~= constants.MISSILE_SYSTEM_STATE.STATIC then
    return
  end

  if resupplyUnitCtx.wpnCurrent == 0 and findUnitArea(resupplyUnit, resupplyUnitCtx.operationalArea) then
    moveToAmmoHoldingArea(resupplyUnitCtx, resupplyUnit)
  end
end

---Complete resupply unit transload when conditions are met
---@param systemCtx SBJ__MissileSystemContext Weapon system context
---@param resupplyUnitCtx SBJ__ResupplyUnitContext Resupply unit context
---@param resupplyUnit CMO__Unit Resupply unit group
---@param isAuto boolean Whether in automatic mode
---@return SBJ__ReloadCycleResult|nil result Structured result if transload was completed
local function completeResupplyUnitTransload(systemCtx, resupplyUnitCtx, resupplyUnit, isAuto)
  if resupplyUnitCtx.state ~= constants.MISSILE_SYSTEM_STATE.RELOAD then
    return nil
  end

  if resupplyUnitCtx.reloadStartTime == nil then
    resupplyUnitCtx.reloadStartTime = GameApi.ScenEdit_CurrentTime()
  end

  local hasMet = MissileSystem.hasMetAmmoDepot(systemCtx, resupplyUnit, isAuto)
  local isReadyToReload = isReadyToReloadResupplyUnit(resupplyUnitCtx, systemCtx, hasMet)

  if not isReadyToReload then
    return nil
  end

  local ammoDepotCtx = systemCtx.ammunitions[resupplyUnitCtx.ammunition]
  transferAmmunition(resupplyUnitCtx, ammoDepotCtx)

  if isAuto then
    moveResupplyUnitToReloadPoint(resupplyUnitCtx, resupplyUnit)
  end

  return { tag = "OK", unitName = resupplyUnitCtx.name, action = "Ammo transload finished" }
end

---Handle resupply unit reload cycle: trigger movement and complete transload
---@param systemCtx SBJ__MissileSystemContext Weapon system context
---@param resupplyUnitCtx SBJ__ResupplyUnitContext Resupply unit context
---@param resupplyUnit CMO__Unit Resupply unit group
---@param isAuto boolean Whether in automatic mode
---@return SBJ__ReloadCycleResult|nil result Structured result if action was taken
local function handleResupplyUnitReloadCycle(systemCtx, resupplyUnitCtx, resupplyUnit, isAuto)
  triggerResupplyMovement(resupplyUnitCtx, resupplyUnit, isAuto)
  return completeResupplyUnitTransload(systemCtx, resupplyUnitCtx, resupplyUnit, isAuto)
end

---Process all firing units and collect structured results
---@param systemCtx SBJ__MissileSystemContext Weapon system context
---@param isAuto boolean Whether in automatic mode
---@param sideName string Side name
---@return SBJ__ReloadCycleResult[] results Collected structured results
local function processFiringUnits(systemCtx, isAuto, sideName)
  local results = {}
  for _, firingUnitCtx in pairs(systemCtx.firingUnits) do
    local firingUnit = GameApi.ScenEdit_GetUnit(firingUnitCtx.name, sideName)

    if firingUnit then
      local result = handleFiringUnitReloadCycle(systemCtx, firingUnitCtx, firingUnit, isAuto)
      if result then table.insert(results, result) end
    end
  end
  return results
end

---Process all resupply units and collect structured results
---@param msContext SBJ__MissileSystemContext Weapon system context
---@param isAuto boolean Whether in automatic mode
---@param sideName string Side name
---@return SBJ__ReloadCycleResult[] results Collected structured results
local function processResupplyUnits(msContext, isAuto, sideName)
  local results = {}
  for _, resupplyUnitCtx in pairs(msContext.resupplyUnits) do
    local resupplyUnit = GameApi.ScenEdit_GetUnit(resupplyUnitCtx.name, sideName)

    if resupplyUnit then
      local result = handleResupplyUnitReloadCycle(msContext, resupplyUnitCtx, resupplyUnit, isAuto)
      if result then table.insert(results, result) end
    end
  end
  return results
end

-- ============================================================================
-- Event Triggers and Zones
-- ============================================================================

---Get area color code based on position type
---@param positionType string Position type identifier (RL/HA/AHA/MASK/FP)
---@return string # Hexadecimal color code
local function getOperationalAreaColor(positionType)
  local colorMap = {
    [constants.POSITION_TYPES.RELOAD_POINT] = ZONE_COLORS.RELOAD_POINT,
    [constants.POSITION_TYPES.HIDE_AREA] = ZONE_COLORS.HIDE_AREA,
    [constants.POSITION_TYPES.AMMO_HOLDING_AREA] = ZONE_COLORS.AMMO_HOLDING_AREA,
    [constants.POSITION_TYPES.MASK] = ZONE_COLORS.MASK,
  }

  return colorMap[positionType] or ZONE_COLORS.DEFAULT
end

---Build event names and trigger prefixes for a side
---@param sideName string Side name
---@param positionTypes string[] Position types
---@return string[] eventNames Array of event names
---@return string[] triggerPrefixes Array of trigger prefix strings
local function buildEventAndTriggerNames(sideName, positionTypes)
  local eventNames, triggerPrefixes = {}, {}
  for _, posType in ipairs(positionTypes) do
    table.insert(eventNames, string.format("(%s) Arrive in %s", sideName, posType))
    table.insert(triggerPrefixes, string.format("(%s)", posType))
  end
  return eventNames, triggerPrefixes
end

---Add a unit-enters-area trigger to the specified event
---@param opts SBJ__AddTriggerOpts Trigger creation options
---@return boolean # Whether trigger was successfully added
local function addTriggerToEvent(opts)
  local triggerName = string.format("(%s) Arrive in %s - %d - %s", opts.sideName, opts.positionType, opts.index,
    opts.operationalArea.name)
  local zoneName = opts.positionType .. "/" .. tostring(opts.index) .. "/" .. opts.operationalArea.name
  local zone = GameApi.ScenEdit_AddZone(opts.sideName, constants.ZONE_TYPES.STANDARD, {
    area = opts.position.area,
    description = zoneName
  })

  if zone then
    local eventName = string.format("(%s) Arrive in %s", opts.sideName, opts.positionType)
    zone.areacolor = getOperationalAreaColor(opts.positionType)
    opts.position.area = GameUtils.convertToRPArray(zone)
    GameApi.ScenEdit_SetTrigger({
      Description = triggerName,
      Mode = "add",
      type = "UnitEntersArea",
      TargetFilter = { TargetSide = opts.sideName },
      Area = opts.position.area,
      ExitArea = false
    })
    GameApi.ScenEdit_SetEventTrigger(eventName, { mode = "add", name = triggerName })
    return true
  end

  return false
end

---Clean up existing zones and event triggers for missile system
---@param posTypes string[] Position types to clean up
---@param sideName string Side name for cleanup operations
local function cleanupExistingTriggersAndZones(posTypes, sideName)
  GameUtils.removeZones(ZONE_PATTERNS, constants.ZONE_TYPES.STANDARD, sideName)
  GameUtils.removeZones(ZONE_PATTERNS, constants.ZONE_TYPES.CUSTOM_ENVIRONMENT, sideName)

  local eventNames, triggerPrefixes = buildEventAndTriggerNames(sideName, posTypes)
  GameUtils.removeEventTriggers(eventNames, triggerPrefixes, "UnitEntersArea")
end

---Add custom environment zone for terrain masking
---@param operationalArea SBJ__OperationalArea Operational area configuration
---@param sideName string Side name for zone ownership
---@return boolean # Whether zone was successfully created
local function addCustomEnvironmentZone(operationalArea, sideName)
  local zone = GameApi.ScenEdit_AddZone(sideName, constants.ZONE_TYPES.CUSTOM_ENVIRONMENT, {
    description = constants.POSITION_TYPES.MASK .. "/" .. operationalArea.name,
    area = operationalArea.uShapeVertices,
    sideName = sideName
  })

  if zone then
    local rps = GameUtils.convertToRPArray(zone)
    local filteredRPs = {}

    for index, rp in ipairs(rps) do
      if index > 3 and index < 8 then
        table.insert(filteredRPs, rp)
      end
    end

    operationalArea.mask = { area = filteredRPs }
    zone.areacolor = getOperationalAreaColor(constants.POSITION_TYPES.MASK)
    zone.landcoverheight = MASK_ZONE.LAND_COVER_HEIGHT
    zone.landcovertype = MASK_ZONE.LAND_COVER_TYPE
    return true
  end
  return false
end

---Create position triggers for an operational area
---@param operationalArea SBJ__OperationalArea Operational area configuration
---@param positionTypes string[] Position types to create
---@param enemySide string Enemy side name
---@param sideName string Owner side name
---@return integer created Number of triggers created
---@return integer failed Number of triggers failed
---@return string[] failMessages Failure detail messages
local function createPositionTriggers(operationalArea, positionTypes, enemySide, sideName)
  local created, failed = 0, 0
  local failMessages = {}

  for _, positionType in ipairs(positionTypes) do
    for index, position in ipairs(operationalArea[positionType]) do
      ---@cast position SBJ__Position
      if addTriggerToEvent({
            positionType = positionType,
            position = position,
            index = index,
            operationalArea = operationalArea,
            enemySide = enemySide,
            sideName = sideName
          }) then
        created = created + 1
      else
        failed = failed + 1
        table.insert(failMessages, string.format("  [FAIL] Trigger %s-%d in %s",
          positionType, index, operationalArea.name))
      end
    end
  end

  return created, failed, failMessages
end

-- ============================================================================
-- Unit Creation and Removal
-- ============================================================================

---Remove missile systems from the game
---@param descriptor SBJ__FiringUnitDescriptor Firing unit descriptor with removal info
---@param sideName string Side name for unit deletion
---@return boolean # Whether unit was successfully removed
local function removeMissileSystem(descriptor, sideName)
  local unit = GameApi.ScenEdit_GetUnit(descriptor.name, sideName)

  if unit then
    if unit.group and unit.group.unitlist then
      for _, guid in ipairs(unit.group.unitlist) do
        GameApi.ScenEdit_DeleteUnit({ side = sideName, guid = guid })
      end
    else
      GameApi.ScenEdit_DeleteUnit({ side = sideName, guid = unit.guid })
    end

    return true
  end

  return false
end

---Remove unwanted weapons and redistribute ammo for desired weapon types
---@param addedUnit CMO__Unit Unit to clean up weapons for
---@param weaponDBIDs number[] Desired weapon DBIDs to keep
---@param sideName string Side name
local function cleanupAndRedistributeWeapons(addedUnit, weaponDBIDs, sideName)
  GameApi.ScenEdit_ClearAllMagazines({ side = sideName, guid = addedUnit.guid })

  local weaponDBIDSet = {}
  for _, id in ipairs(weaponDBIDs) do weaponDBIDSet[id] = true end

  local removals = {}
  for _, mount in ipairs(addedUnit.mounts) do
    if #mount.mount_weapons > 1 then
      for _, wpn in ipairs(mount.mount_weapons) do
        if wpn.wpn_current > 0 and not weaponDBIDSet[wpn.wpn_dbid] then
          removals[wpn.wpn_dbid] = (removals[wpn.wpn_dbid] or 0) + wpn.wpn_current
        end
      end
    end
  end

  local totalRemovedCount = 0
  for wpnDbid, count in pairs(removals) do
    GameApi.ScenEdit_AddReloadsToUnit({
      side = sideName,
      guid = addedUnit.guid,
      wpn_dbid = wpnDbid,
      number = count,
      remove = true
    })
    totalRemovedCount = totalRemovedCount + count
  end

  if totalRemovedCount > 0 and #weaponDBIDs == 1 then
    GameApi.ScenEdit_AddReloadsToUnit({
      side = sideName,
      guid = addedUnit.guid,
      wpn_dbid = weaponDBIDs[1],
      number = totalRemovedCount,
    })
  end
end

---Create firing units according to configuration
---@param systemCfg SBJ__MissileSystemConfig Weapon system configuration
---@param descriptor SBJ__FiringUnitDescriptor Firing unit descriptor
---@param sideName string Side name for unit creation
---@return integer created Number of units successfully created
---@return integer expected Total number of units expected to create
---@return string? errorMsg Error message if validation failed
local function addFiringUnit(systemCfg, descriptor, sideName)
  if not descriptor.operationalArea.HA or #descriptor.operationalArea.HA == 0 then
    return 0, 0, string.format("No HA defined for firing unit '%s' (OPAREA: %s), cannot add unit",
      descriptor.name, descriptor.operationalArea.name)
  end

  local haPosition = descriptor.operationalArea.HA[1]
  if not haPosition.course or #haPosition.course == 0 then
    return 0, 0, string.format("No course defined for HA[1] in '%s' (OPAREA: %s), cannot add unit",
      descriptor.name, descriptor.operationalArea.name)
  end

  local expected = systemCfg.resupplyUnits[descriptor.resupplyUnit].unitCount
  local size = #haPosition.course
  local unitType = GameUtils.extractUnitType(descriptor.name)
  local created = 0

  for i = 1, expected do
    local name
    if expected == 1 then
      name = descriptor.name
    else
      name = GameUtils.formatOrdinalUnitName(i, unitType or "", ", " .. descriptor.name)
    end

    local addedUnit = GameApi.ScenEdit_AddUnit({
      side = sideName,
      unitname = name,
      dbid = descriptor.dbid,
      type = constants.UNIT_TYPES.FACILITY,
      group = expected > 1 and descriptor.name or nil,
      latitude = haPosition.course[size].latitude,
      longitude = haPosition.course[size].longitude
    })

    if addedUnit then
      if descriptor.mountDescriptors then
        for _, desc in ipairs(descriptor.mountDescriptors) do
          for j = 1, desc.mountCount do
            GameApi.ScenEdit_UpdateUnit({
              guid = addedUnit.guid,
              mode = "add_mount",
              dbid = desc.dbid,
              arc_mount = constants.SENSOR_ARCS
            })
          end
        end
      end

      cleanupAndRedistributeWeapons(addedUnit, normalizeWeaponDBIDs(descriptor.weaponDBID), sideName)
      created = created + 1
    end
  end

  return created, expected, nil
end

---Create resupply units according to configuration
---@param descriptor SBJ__ResupplyUnitDescriptor Resupply unit descriptor
---@param sideName string Side name for unit creation
---@return integer created Number of units successfully created
---@return integer expected Total number of units expected to create
---@return string? errorMsg Error message if validation failed
local function addResupplyUnit(descriptor, sideName)
  if not descriptor.operationalArea.RL or #descriptor.operationalArea.RL == 0 then
    return 0, 0, string.format("No RL defined for resupply unit '%s' (OPAREA: %s), cannot add unit",
      descriptor.name, descriptor.operationalArea.name)
  end

  local expected = descriptor.unitCount
  local size = #descriptor.operationalArea.RL[1].course
  local unitType = GameUtils.extractUnitType(descriptor.name)
  local restStr = descriptor.name:match("Ammo Sec(.*)") or (", " .. descriptor.name)
  local created = 0

  for i = 1, expected do
    local name

    if expected == 1 then
      name = descriptor.name
    else
      name = "Ammo Sec, " .. GameUtils.formatOrdinalUnitName(i, unitType or "", restStr)
    end

    local result = GameApi.ScenEdit_AddUnit({
      side = sideName,
      unitname = name,
      dbid = constants.PLATFORMS.AMMO_TRUCK,
      type = constants.UNIT_TYPES.FACILITY,
      group = expected > 1 and descriptor.name or nil,
      latitude = descriptor.operationalArea.RL[1].course[size].latitude,
      longitude = descriptor.operationalArea.RL[1].course[size].longitude
    })

    if result then
      created = created + 1
    end
  end

  return created, expected, nil
end

---Create ammunition depot unit according to configuration
---@param systemCfg SBJ__MissileSystemConfig Weapon system configuration
---@param descriptor SBJ__AmmunitionUnitDescriptor Ammunition unit descriptor
---@param sideName string Side name for unit creation
---@return boolean success Whether unit was successfully created
---@return string? errorMsg Error message if failed
local function addAmmunition(systemCfg, descriptor, sideName)
  local restStr = descriptor.name:gsub("^Ammo Revetment, ", "")
  local name = restStr
  local resupplyUnitDescriptor = systemCfg.resupplyUnits[name]

  if not resupplyUnitDescriptor then
    name = "Ammo Sec, " .. name
  end

  resupplyUnitDescriptor = systemCfg.resupplyUnits[name]

  if resupplyUnitDescriptor then
    if not resupplyUnitDescriptor.operationalArea.AHA or #resupplyUnitDescriptor.operationalArea.AHA == 0 then
      return false, string.format("No AHA defined for ammo unit '%s' (OPAREA: %s), cannot add unit",
        descriptor.name, resupplyUnitDescriptor.operationalArea.name)
    end

    local size = #resupplyUnitDescriptor.operationalArea.AHA[1].course
    local addedUnit = GameApi.ScenEdit_AddUnit({
      side = sideName,
      unitname = descriptor.name,
      dbid = constants.PLATFORMS.AMMO,
      type = constants.UNIT_TYPES.FACILITY,
      latitude = resupplyUnitDescriptor.operationalArea.AHA[1].course[size].latitude,
      longitude = resupplyUnitDescriptor.operationalArea.AHA[1].course[size].longitude
    })
    if addedUnit then
      addedUnit.autodetectable = false
    end
    return true, nil
  end

  return false, nil
end

-- ============================================================================
-- Public API
-- ============================================================================

---Command firing unit to move to firing point (FP)
---@param firingUnitCtx SBJ__FiringUnitContext Firing unit context
---@param firingUnit CMO__Unit Firing unit group
---@return boolean success Whether the move was successful
function MissileSystem.moveToFiringPoint(firingUnitCtx, firingUnit)
  local success, errorMsg = moveToFiringPoint(firingUnitCtx, firingUnit)
  if not success and errorMsg then
    Logger.error(MISSILE_SYSTEM_TAG .. ": [FAIL] " .. errorMsg)
  end
  return success
end

---Set firing unit reload start time
---@param firingUnitCtx SBJ__FiringUnitContext Firing unit context
---@param firingUnit CMO__Unit Firing unit group
---@param isAuto boolean Whether in automatic mode
function MissileSystem.setReloadStartTime(firingUnitCtx, firingUnit, isAuto)
  firingUnitCtx.state = constants.MISSILE_SYSTEM_STATE.RELOAD
  firingUnitCtx.reloadStartTime = GameApi.ScenEdit_CurrentTime()
  applyToGroupUnits(firingUnit, function(unit)
    return buildModeProperties(unit, isAuto, constants.WCS.HOLD)
  end)
end

---Set firing unit weapon control status to free fire
---@param firingUnitCtx SBJ__FiringUnitContext Firing unit context
---@param firingUnit CMO__Unit Firing unit group
---@param isAuto boolean Whether in automatic mode
function MissileSystem.setWCSToFree(firingUnitCtx, firingUnit, isAuto)
  firingUnitCtx.state = constants.MISSILE_SYSTEM_STATE.STATIC
  applyToGroupUnits(firingUnit, function(unit)
    return buildModeProperties(unit, isAuto, constants.WCS.FREE)
  end)
end

---Set firing unit status to hide
---@param firingUnitCtx SBJ__FiringUnitContext Firing unit context
---@param firingUnit CMO__Unit Firing unit group
---@param isAuto boolean Whether the action is automatic
function MissileSystem.setStateToHIDE(firingUnitCtx, firingUnit, isAuto)
  firingUnitCtx.state = constants.MISSILE_SYSTEM_STATE.HIDE
  applyToGroupUnits(firingUnit, function(unit)
    return buildModeProperties(unit, isAuto, constants.WCS.HOLD)
  end)
end

---Reset unit state to STATIC and clear reload timer
---@param systemCtx SBJ__MissileSystemContext Missile system context
---@param firingUnit CMO__Unit Unit group to reset
---@param isAuto boolean Whether the action is automatic
function MissileSystem.setStateToStatic(systemCtx, firingUnit, isAuto)
  local unitCtx = systemCtx.firingUnits[firingUnit.name] or systemCtx.resupplyUnits[firingUnit.name]

  if unitCtx then
    unitCtx.state = constants.MISSILE_SYSTEM_STATE.STATIC
    unitCtx.reloadStartTime = nil
    applyToGroupUnits(firingUnit, function(unit)
      return buildModeProperties(unit, isAuto, constants.WCS.HOLD)
    end)
  end
end

---Check if firing unit is currently repositioning
---In auto mode checks state; in manual mode always returns true
---@param firingUnitCtx SBJ__FiringUnitContext|nil Firing unit context
---@param isAuto boolean Whether the action is automatic
---@return boolean # Whether the unit is repositioning
function MissileSystem.isRepositioning(firingUnitCtx, isAuto)
  if not firingUnitCtx then
    return false
  end

  if isAuto then
    return firingUnitCtx.state == constants.MISSILE_SYSTEM_STATE.REPOSITIONING
  end

  return true
end

---Unload firing unit group from hide area buildings
---@param unitCtx SBJ__FiringUnitContext|SBJ__ResupplyUnitContext Unit context with operational area
---@param unit CMO__Unit Firing unit to unload
---@return boolean success Whether unload was performed
---@return string? errorMsg Error message if failed
function MissileSystem.moveFromHideArea(unitCtx, unit)
  local group = getGroupUnits(unit)
  local buildings = findBuildingsInMaskArea(unitCtx, unit.side)

  if not buildings then
    return false, "No buildings found in mask area"
  end

  for _, u in ipairs(buildings) do
    local building = GameApi.ScenEdit_GetUnit(u.guid)

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
---@param unitCtx SBJ__FiringUnitContext|SBJ__ResupplyUnitContext Unit context with operational area
---@param unit CMO__Unit Firing unit to hide
---@return boolean success Whether hide was performed
---@return string? errorMsg Error message if failed
function MissileSystem.hideUnit(unitCtx, unit)
  local buildings = findBuildingsInMaskArea(unitCtx, unit.side)

  if not buildings then
    return false, "No buildings found in mask area"
  end

  local building = getRandomBuilding(buildings)

  if not building then
    return false, string.format("No available building in mask area for '%s'", unitCtx.name)
  end

  AmphibiousLogistics.loadCargo(building, unitCtx, unit.side)
  return true, nil
end

---Check if unit/group ammunition is below specified percentage
---@param firingUnit CMO__Unit Unit or group object
---@param percentage number|nil Percentage threshold
---@param weaponDBID number|number[]|nil Weapon database ID(s)
---@return boolean # Whether it is low ammunition
function MissileSystem.isLowAmmo(firingUnit, percentage, weaponDBID)
  if not percentage or not weaponDBID then
    return false
  end

  local weaponDBIDs = normalizeWeaponDBIDs(weaponDBID)
  local totalCurrent = 0
  local totalMax = 0

  local units = getGroupUnits(firingUnit)
  for _, guid in ipairs(units) do
    local unit = GameApi.ScenEdit_GetUnit(guid)

    if unit then
      for _, dbid in ipairs(weaponDBIDs) do
        local wpnInfo = GameUtils.getWeaponInfo(unit, dbid)
        totalCurrent = totalCurrent + wpnInfo.availableWeapons
        totalMax = totalMax + wpnInfo.maxWeapons
      end
    end
  end

  if totalMax == 0 then return false end
  return (totalCurrent / totalMax * 100) <= percentage
end

---Check if firing unit has met with resupply units
---@param systemCtx SBJ__MissileSystemContext Weapon system context
---@param unit CMO__Unit Unit to check
---@param isAuto boolean Whether in automatic mode
---@return boolean hasMet Whether units have met
---@return SBJ__FiringUnitContext|SBJ__ResupplyUnitContext|nil context The matched context
function MissileSystem.hasMetResupplyUnit(systemCtx, unit, isAuto)
  local isResupplyUnit = systemCtx.resupplyUnits[unit.name] ~= nil
  local isFiringUnit = systemCtx.firingUnits[unit.name] ~= nil

  if not isFiringUnit and not isResupplyUnit then
    return false, nil
  end

  if isResupplyUnit then
    return findMeetingMatch(systemCtx.resupplyUnits, unit.name, systemCtx.firingUnits, unit, isAuto)
  end

  return findMeetingMatch(systemCtx.firingUnits, unit.name, systemCtx.resupplyUnits, unit, isAuto)
end

---Check if resupply unit has met with ammunition depot
---@param systemCtx SBJ__MissileSystemContext Weapon system context
---@param unit CMO__Unit Unit to check
---@param isAuto boolean Whether in automatic mode
---@return boolean hasMet Whether units have met
---@return SBJ__ResupplyUnitContext|nil resupplyUnit The matched resupply unit context
function MissileSystem.hasMetAmmoDepot(systemCtx, unit, isAuto)
  if not systemCtx.resupplyUnits[unit.name] then
    return false, nil
  end

  for _, resupplyUnitCtx in pairs(systemCtx.resupplyUnits) do
    if resupplyUnitCtx.name == unit.name and isValidStateForMeeting(resupplyUnitCtx.state, isAuto) then
      local ammoDepot = GameApi.ScenEdit_GetUnit(resupplyUnitCtx.ammunition, unit.side)

      for _, pos in ipairs(resupplyUnitCtx.operationalArea.AHA) do
        local isInSameArea = unit:inArea(pos.area) and (ammoDepot and ammoDepot:inArea(pos.area)) and
            resupplyUnitCtx.wpnCurrent == 0
        if isInSameArea then return true, resupplyUnitCtx end
      end
    end
  end

  return false, nil
end

---Check status of all units and trigger corresponding actions
---@param systemCtx SBJ__MissileSystemContext Missile system context
---@param isAuto boolean Whether in automatic mode
---@param sideName string Side name
function MissileSystem.checkMissileSystemState(systemCtx, isAuto, sideName)
  local firingResults = processFiringUnits(systemCtx, isAuto, sideName)
  local resupplyResults = processResupplyUnits(systemCtx, isAuto, sideName)

  local allResults = {}
  for _, r in ipairs(firingResults) do table.insert(allResults, r) end
  for _, r in ipairs(resupplyResults) do table.insert(allResults, r) end

  if #allResults > 0 then
    local lines = {}
    for _, r in ipairs(allResults) do
      table.insert(lines, string.format("  [%s] %s: %s", r.tag, r.action, r.unitName))
    end
    Logger.log(MISSILE_SYSTEM_TAG, string.format(
      "Reload cycle completed: %d events\n%s",
      #allResults, table.concat(lines, "\n")
    ))
  end
end

---Handle logic when resupply unit is destroyed
---@param unit CMO__Unit Destroyed unit
---@param systemCtx SBJ__MissileSystemContext Weapon system context
---@return boolean # Whether unit was found and processed
function MissileSystem.handleSupplyAssetDestruction(unit, systemCtx)
  local ammoDepotCtx = systemCtx.ammunitions[unit.name]

  if ammoDepotCtx and unit.group == nil and ammoDepotCtx.wpnCurrent > 0 then
    ammoDepotCtx.wpnCurrent = 0
    return true
  end

  if not unit.group then
    return false
  end

  local resupplyUnitCtx = systemCtx.resupplyUnits[unit.group.name]

  if resupplyUnitCtx and resupplyUnitCtx.wpnCurrent > 0 then
    local ammoPerUnit = resupplyUnitCtx.wpnDefault / resupplyUnitCtx.unitCount

    if (resupplyUnitCtx.wpnCurrent - ammoPerUnit) < 0 then
      resupplyUnitCtx.wpnCurrent = 0
    else
      resupplyUnitCtx.wpnCurrent = resupplyUnitCtx.wpnCurrent - ammoPerUnit
    end
    return true
  end

  return false
end

---Initialize event triggers and zones for missile system operational areas
---@param operationalAreas SBJ__OperationalArea[] Array of operational area configurations
---@param positionTypes string[] Position type identifiers (RL/HA/AHA/FP)
---@param sideName string Side name for zone/trigger ownership
function MissileSystem.initEventTriggers(operationalAreas, positionTypes, sideName)
  local sideCfg = GameUtils.getCachedSideConfig(sideName)

  cleanupExistingTriggersAndZones(positionTypes, sideName)

  local totalCreated, totalFailed, maskCreated, maskFailed = 0, 0, 0, 0
  local allFailMessages = {}

  for _, operationalArea in ipairs(operationalAreas) do
    local created, failed, failMessages = createPositionTriggers(
      operationalArea, positionTypes, sideCfg.enemySide, sideName)
    totalCreated = totalCreated + created
    totalFailed = totalFailed + failed
    for _, msg in ipairs(failMessages) do
      table.insert(allFailMessages, msg)
    end

    if addCustomEnvironmentZone(operationalArea, sideName) then
      maskCreated = maskCreated + 1
    else
      maskFailed = maskFailed + 1
      table.insert(allFailMessages,
        string.format("  [FAIL] MASK zone for %s", operationalArea.name))
    end
  end

  Logger.log(MISSILE_SYSTEM_TAG, string.format(
    "Initialized %s missile system: %d/%d triggers created, %d/%d mask zones created",
    sideName, totalCreated, totalCreated + totalFailed,
    maskCreated, maskCreated + maskFailed
  ))

  if #allFailMessages > 0 then
    Logger.error(MISSILE_SYSTEM_TAG .. ": Trigger/zone creation failures:\n" .. table.concat(allFailMessages, "\n"))
  end
end

---Add missile system units to the game
---@param groundForceCfg SBJ__GroundForceConfig Ground force context
---@param sideName string Side name
function MissileSystem.addMissileSystems(groundForceCfg, sideName)
  local okLines, failLines = {}, {}

  for systemName, systemCfg in pairs(groundForceCfg) do
    ---@cast systemCfg SBJ__MissileSystemConfig
    local fuTotal, fuExpected = 0, 0
    for _, descriptor in pairs(systemCfg.firingUnits) do
      removeMissileSystem(descriptor, sideName)
      local created, expected, errorMsg = addFiringUnit(systemCfg, descriptor, sideName)
      fuTotal = fuTotal + created
      fuExpected = fuExpected + expected
      if errorMsg then table.insert(failLines, "  [FAIL] " .. errorMsg) end
    end

    local ruTotal, ruExpected = 0, 0
    for _, descriptor in pairs(systemCfg.resupplyUnits) do
      removeMissileSystem(descriptor, sideName)
      local created, expected, errorMsg = addResupplyUnit(descriptor, sideName)
      ruTotal = ruTotal + created
      ruExpected = ruExpected + expected
      if errorMsg then table.insert(failLines, "  [FAIL] " .. errorMsg) end
    end

    local ammoOk, ammoTotal = 0, 0
    for _, descriptor in pairs(systemCfg.ammunitions) do
      removeMissileSystem(descriptor, sideName)
      local success, errorMsg = addAmmunition(systemCfg, descriptor, sideName)
      ammoTotal = ammoTotal + 1
      if success then ammoOk = ammoOk + 1 end
      if errorMsg then table.insert(failLines, "  [FAIL] " .. errorMsg) end
    end

    table.insert(okLines, string.format("  [OK] %s: %d/%d firing, %d/%d resupply, %d/%d ammo",
      systemName, fuTotal, fuExpected, ruTotal, ruExpected, ammoOk, ammoTotal))
  end

  if #okLines > 0 then
    Logger.log(MISSILE_SYSTEM_TAG, "Unit creation summary:\n" .. table.concat(okLines, "\n"))
  end
  if #failLines > 0 then
    Logger.error(MISSILE_SYSTEM_TAG .. ": Unit creation failures:\n" .. table.concat(failLines, "\n"))
  end
end

---Initialize missile system runtime contexts from configuration
---@param groundForceCfg SBJ__GroundForceConfig Ground force configuration
---@param groundForceCtx SBJ__GroundForceContext Ground force runtime context
function MissileSystem.initMissileSystemContexts(groundForceCfg, groundForceCtx)
  for system, systemCfg in pairs(groundForceCfg) do
    ---@cast systemCfg SBJ__MissileSystemConfig
    local firingUnits = Utils.deepCopy(systemCfg.firingUnits)
    for _, descriptor in pairs(firingUnits) do
      ---@type SBJ__FiringUnitContext
      local ctx = descriptor
      ctx.reloadStartTime = nil
      groundForceCtx[system].firingUnits[ctx.name] = ctx
    end

    local resupplyUnits = Utils.deepCopy(systemCfg.resupplyUnits)
    for _, descriptor in pairs(resupplyUnits) do
      ---@type SBJ__ResupplyUnitContext
      local ctx = descriptor
      ctx.reloadStartTime = nil
      groundForceCtx[system].resupplyUnits[ctx.name] = ctx
    end

    local ammunitions = Utils.deepCopy(systemCfg.ammunitions)
    for _, descriptor in pairs(ammunitions) do
      ---@type SBJ__AmmunitionContext
      local ctx = descriptor
      groundForceCtx[system].ammunitions[ctx.name] = ctx
    end
  end
end

return MissileSystem
