local Utils = require("src.utils.utils")
local GameApi = require("src.utils.gameApi")
local Logger = require("src.utils.logger")
local constants = require("src.core.constants")
local GameUtils = require("src.utils.gameUtils")

local MissileSystem = {}


-- Zone name patterns for cleanup (regex patterns)
local ZONE_PATTERNS = {
  "^" .. constants.POSITION_TYPES.FIRING_POINT,
  "^" .. constants.POSITION_TYPES.HIDE_AREA,
  "^" .. constants.POSITION_TYPES.AMMO_HOLDING_AREA,
  "^" .. constants.POSITION_TYPES.RELOAD_POINT,
  "^" .. constants.POSITION_TYPES.MASK
}

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
    GameApi.ScenEdit_SetDoctrine({ side = unit.side, guid = unit.guid }, { weapon_control_status_land = params.wcs })
  end

  if params.formation then
    unit.formation = params.formation
  end
end

---Generic function to move units to specified positions
---@param unitName string Unit name (for error messages)
---@param battery CMO__Unit Unit group
---@param positions SBJ__Position[] Position array
---@param positionType string Position type ('RL'/'HA'/'AHA'/'FP', for error messages)
---@param areaName string Operational area name (for error messages)
---@param wcs integer? Weapon control status (optional)
---@param useLastCourse boolean? Whether to use the last waypoint in course (default: false)
---@return boolean # Success status
local function moveUnitToPosition(unitName, battery, positions, positionType, areaName, wcs, useLastCourse)
  local posCount = Utils.getCount(positions)
  if posCount == 0 then
    Logger.error(string.format("missileSystem: No %s positions available for unit '%s' (OPAREA: %s)",
      positionType, unitName, areaName))
    return false
  end

  local posIdx = math.random(posCount)
  local position = positions[posIdx]

  if not position or not position.course then
    Logger.error(string.format("missileSystem: Invalid %s position data at index %d for unit '%s' (OPAREA: %s)",
      positionType, posIdx, unitName, areaName))
    return false
  end

  -- Use last waypoint if requested and course is an array
  local course = position.course
  if useLastCourse and type(course) == "table" and #course > 0 then
    course = { course[#course] }
  end

  local units = battery.group and battery.group.unitlist or { battery.guid }

  for _, guid in ipairs(units) do
    local unit = GameApi.ScenEdit_GetUnit(guid)

    if unit then
      setUnitProperties({
        unit = unit,
        throttle = constants.THROTTLES.FULL,
        speed = constants.SPEEDS.NORMAL,
        course = course,
        holdPosition = false,
        wcs = wcs
      })
    end
  end

  return true
end

---Command firing unit to move to reload point (RL)
---@param firingUnitCtx SBJ__FiringUnitContext Firing unit context
---@param firingUnit CMO__Unit Firing unit group
local function moveToReloadPoint(firingUnitCtx, firingUnit)
  firingUnitCtx.state = constants.MISSILE_SYSTEM_STATE.REPOSITIONING
  moveUnitToPosition(
    firingUnitCtx.name,
    firingUnit,
    firingUnitCtx.operationalArea.RL,
    constants.POSITION_TYPES.RELOAD_POINT,
    firingUnitCtx.operationalArea.name,
    constants.WCS.HOLD
  )
end

---Command firing unit to move to hide area (HA)
---@param firingUnitCtx SBJ__FiringUnitContext Firing unit context
---@param firingUnit CMO__Unit Firing unit group
local function moveToHideArea(firingUnitCtx, firingUnit)
  -- Check if HA exists (some OPAREAs may not have HA)
  if not firingUnitCtx.operationalArea.HA then
    Logger.log("missileSystem",
      string.format("missileSystem: No HA defined for firing unit '%s' (OPAREA: %s), skipping hide movement",
        firingUnitCtx.name, firingUnitCtx.operationalArea.name))
    return
  end

  firingUnitCtx.state = constants.MISSILE_SYSTEM_STATE.REPOSITIONING
  moveUnitToPosition(
    firingUnitCtx.name,
    firingUnit,
    firingUnitCtx.operationalArea.HA,
    constants.POSITION_TYPES.HIDE_AREA,
    firingUnitCtx.operationalArea.name,
    constants.WCS.HOLD
  )
end

---Command resupply unit to move to ammunition holding area (AHA)
---@param resupplyUnitCtx SBJ__ResupplyUnitContext Resupply unit context
---@param resupplyUnit CMO__Unit Resupply unit group
local function moveToAmmoHoldingArea(resupplyUnitCtx, resupplyUnit)
  resupplyUnitCtx.state = constants.MISSILE_SYSTEM_STATE.REPOSITIONING
  moveUnitToPosition(
    resupplyUnitCtx.name,
    resupplyUnit,
    resupplyUnitCtx.operationalArea.AHA,
    constants.POSITION_TYPES.AMMO_HOLDING_AREA,
    resupplyUnitCtx.operationalArea.name
  )
end

---Command resupply unit to move to reload point (RL)
---@param resupplyUnitCtx SBJ__ResupplyUnitContext Resupply unit context
---@param resupplyUnit CMO__Unit Resupply unit group
local function moveResupplyUnitToReloadPoint(resupplyUnitCtx, resupplyUnit)
  resupplyUnitCtx.state = constants.MISSILE_SYSTEM_STATE.REPOSITIONING
  moveUnitToPosition(
    resupplyUnitCtx.name,
    resupplyUnit,
    resupplyUnitCtx.operationalArea.RL,
    constants.POSITION_TYPES.RELOAD_POINT,
    resupplyUnitCtx.operationalArea.name,
    nil,
    true
  )
end

---Command firing unit to move to firing point (FP)
---@param firingUnitCtx SBJ__FiringUnitContext Firing unit context
---@param firingUnit CMO__Unit Firing unit group
---@return boolean success Whether the move was successful
function MissileSystem.moveToFiringPoint(firingUnitCtx, firingUnit)
  firingUnitCtx.state = constants.MISSILE_SYSTEM_STATE.REPOSITIONING
  return moveUnitToPosition(
    firingUnitCtx.name,
    firingUnit,
    firingUnitCtx.operationalArea.FP,
    constants.POSITION_TYPES.FIRING_POINT,
    firingUnitCtx.operationalArea.name
  )
end

---Transfer ammunition from ammunition depot to resupply unit
---@param resupplyUnitCtx SBJ__ResupplyUnitContext Resupply unit context
---@param ammoDepotCtx SBJ__AmmunitionContext Ammunition depot context
function MissileSystem.transferAmmunition(resupplyUnitCtx, ammoDepotCtx)
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
---@param weaponDBID number Weapon database ID
---@param resupplyUnitCtx SBJ__ResupplyUnitContext Resupply unit context
---@return integer # Total ammunition consumed
local function reloadUnit(unit, weaponDBID, resupplyUnitCtx)
  if not unit then return 0 end
  local wpnInfo = GameUtils.getWeaponInfo(unit, weaponDBID)
  local required = wpnInfo.maxWeapons - wpnInfo.availableWeapons

  if required > 0 and resupplyUnitCtx.wpnCurrent > 0 then
    local ammoToLoad = math.min(required, resupplyUnitCtx.wpnCurrent)
    GameApi.ScenEdit_AddReloadsToUnit({ guid = unit.guid, side = unit.side, wpn_dbid = weaponDBID, number = ammoToLoad })
    resupplyUnitCtx.wpnCurrent = resupplyUnitCtx.wpnCurrent - ammoToLoad
    return ammoToLoad
  end

  return 0
end

---Execute reload for firing unit
---@param firingUnitCtx SBJ__FiringUnitContext Firing unit context
---@param resupplyUnitCtx SBJ__ResupplyUnitContext Resupply unit context
---@param weaponDBID number Weapon database ID
---@param sideName string Side name
---@return integer # Total ammunition loaded
function MissileSystem.reload(firingUnitCtx, resupplyUnitCtx, weaponDBID, sideName)
  local firingUnit = GameApi.ScenEdit_GetUnit(firingUnitCtx.name, sideName)
  if not firingUnit then return 0 end
  local units = firingUnit.group and firingUnit.group.unitlist or { firingUnit.guid }

  local totalLoaded = 0
  for _, guid in ipairs(units) do
    local unit = GameApi.ScenEdit_GetUnit(guid)
    totalLoaded = totalLoaded + reloadUnit(unit, weaponDBID, resupplyUnitCtx)
  end

  firingUnitCtx.state = constants.MISSILE_SYSTEM_STATE.STATIC
  firingUnitCtx.reloadStartTime = nil
  return totalLoaded
end

---Set firing unit reload start time
---@param firingUnitCtx SBJ__FiringUnitContext Firing unit context
---@param firingUnit CMO__Unit Firing unit group
---@param isAuto boolean Whether in automatic mode
function MissileSystem.setReloadStartTime(firingUnitCtx, firingUnit, isAuto)
  firingUnitCtx.state = constants.MISSILE_SYSTEM_STATE.RELOAD
  firingUnitCtx.reloadStartTime = GameApi.ScenEdit_CurrentTime()
  local units = firingUnit.group and firingUnit.group.unitlist or { firingUnit.guid }

  for _, guid in ipairs(units) do
    local unit = GameApi.ScenEdit_GetUnit(guid)

    if unit and isAuto then
      setUnitProperties({ unit = unit, holdPosition = true, formation = { spacing = 0, transpose = true } })
    end
  end
end

---Set firing unit weapon control status to free fire
---@param firingUnitCtx SBJ__FiringUnitContext Firing unit context
---@param firingUnit CMO__Unit Firing unit group
---@param isAuto boolean Whether in automatic mode
function MissileSystem.setWCSToFree(firingUnitCtx, firingUnit, isAuto)
  firingUnitCtx.state = constants.MISSILE_SYSTEM_STATE.STATIC
  local units = firingUnit.group and firingUnit.group.unitlist or { firingUnit.guid }

  for _, guid in ipairs(units) do
    local unit = GameApi.ScenEdit_GetUnit(guid)

    if unit and isAuto then
      setUnitProperties({
        unit = unit,
        holdPosition = true,
        wcs = constants.WCS.FREE, -- Free fire
        formation = { spacing = 0, transpose = true }
      })
    end
  end
end

---Set firing unit status to hide
---@param firingUnitCtx SBJ__FiringUnitContext Firing unit context
---@param firingUnit CMO__Unit Firing unit group
---@param isAuto boolean Whether the action is automatic
function MissileSystem.setStateToHIDE(firingUnitCtx, firingUnit, isAuto)
  firingUnitCtx.state = constants.MISSILE_SYSTEM_STATE.HIDE
  local units = firingUnit.group and firingUnit.group.unitlist or { firingUnit.guid }

  for _, guid in ipairs(units) do
    local unit = GameApi.ScenEdit_GetUnit(guid)

    if unit and isAuto then
      setUnitProperties({
        unit = unit,
        holdPosition = true,
        wcs = constants.WCS.HOLD, -- Hold fire while hiding
        formation = { spacing = 0, transpose = true }
      })
    end
  end
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
    local units = firingUnit.group and firingUnit.group.unitlist or { firingUnit.guid }

    for _, guid in ipairs(units) do
      local unit = GameApi.ScenEdit_GetUnit(guid)

      if unit and isAuto then
        setUnitProperties({
          unit = unit,
          holdPosition = true,
          wcs = constants.WCS.HOLD, -- Hold fire while hiding
          formation = { spacing = 0, transpose = true }
        })
      end
    end
  end
end

---Check if firing unit is currently repositioning
---In auto mode checks state; in manual mode always returns true
---@param firingUnitCtx SBJ__FiringUnitContext Firing unit context
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

---Check if unit/group ammunition is below specified percentage
---@param firingUnit CMO__Unit Unit or group object
---@param percentage number Percentage threshold
---@param weaponDBID number Weapon database ID
---@return boolean # Whether it is low ammunition
function MissileSystem.isLowAmmo(firingUnit, percentage, weaponDBID)
  if not percentage or not weaponDBID then
    return false
  end

  local totalCurrent = 0
  local totalMax = 0

  -- Process single unit or all units in group
  local units = firingUnit.group and firingUnit.group.unitlist or { firingUnit.guid }
  for _, guid in ipairs(units) do
    local unit = GameApi.ScenEdit_GetUnit(guid)

    if unit then
      local wpnInfo = GameUtils.getWeaponInfo(unit, weaponDBID)
      totalCurrent = totalCurrent + wpnInfo.availableWeapons
      totalMax = totalMax + wpnInfo.maxWeapons
    end
  end

  if totalMax == 0 then return false end
  return (totalCurrent / totalMax * 100) <= percentage
end

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

---Check if two types of units have met in the same area
---@param targetCtx SBJ__FiringUnitContext|SBJ__ResupplyUnitContext Target unit context (firing unit or resupply unit)
---@param targetName string Target unit name to match
---@param counterpartList SBJ__FiringUnitContext[]|SBJ__ResupplyUnitContext[] List of counterpart units to check
---@param unit CMO__Unit Original unit for area checking
---@param isAuto boolean Whether in automatic mode
---@return boolean isMet Whether units have met
---@return SBJ__FiringUnitContext|SBJ__ResupplyUnitContext|nil context The matched context if met
local function checkMeetingInArea(targetCtx, targetName, counterpartList, unit, isAuto)
  local isStateValid = true

  if isAuto then
    local repoState = constants.MISSILE_SYSTEM_STATE.REPOSITIONING
    local reloadState = constants.MISSILE_SYSTEM_STATE.RELOAD
    isStateValid = (targetCtx.state == repoState or targetCtx.state == reloadState)
  end

  if targetCtx.name == targetName and isStateValid then
    local area = findUnitArea(unit, targetCtx.operationalArea)
    if not area then return false, nil end

    for _, counterpartCtx in pairs(counterpartList) do
      local counterpart = GameApi.ScenEdit_GetUnit(counterpartCtx.name, unit.side)
      if not counterpart then goto nextCounterpart end
      local isRequiredToReload = false
      local isFiringUnitCtx = targetCtx.weaponDBID ~= nil

      if isFiringUnitCtx then
        isRequiredToReload = MissileSystem.isLowAmmo(unit, targetCtx.ammoThreshold, targetCtx.weaponDBID) and
            counterpartCtx.wpnCurrent > 0
      else
        isRequiredToReload = MissileSystem.isLowAmmo(counterpart, counterpartCtx.ammoThreshold,
          counterpartCtx.weaponDBID) and targetCtx.wpnCurrent > 0
      end

      if counterpart and counterpart:inArea(area) and isRequiredToReload then return true, targetCtx end
      ::nextCounterpart::
    end
  end

  return false, nil
end

---Check if firing unit has met with resupply units
---@param systemCtx SBJ__MissileSystemContext Weapon system context
---@param unit CMO__Unit Unit to check
---@param isAuto boolean Whether in automatic mode
---@return boolean isMet Whether units have met
---@return SBJ__FiringUnitContext|SBJ__ResupplyUnitContext|nil context The matched context if met
function MissileSystem.isMetWithResupplyUnits(systemCtx, unit, isAuto)
  -- if not unit.group then return false, nil end
  -- local unitGroup = GameApi.ScenEdit_GetUnit(unit.group.guid)
  -- if not unitGroup then return false, nil end
  local isResupplyUnit, isFiringUnit = false, false

  if systemCtx.resupplyUnits[unit.name] then
    isResupplyUnit = true
  end

  if systemCtx.firingUnits[unit.name] then
    isFiringUnit = true
  end

  if not isFiringUnit and not isResupplyUnit then
    return false, nil
  end

  -- Determine unit type by checking which collection contains this GUID
  -- local isResupplyUnit = systemCtx.resupplyUnits[unitGroup.name] ~= nil

  if isResupplyUnit then
    -- Case: Resupply unit looking for firing units
    for _, resupplyUnitCtx in pairs(systemCtx.resupplyUnits) do
      -- local isMet, ctx = checkMeetingInArea(resupplyUnitCtx, unitGroup.name, systemCtx.firingUnits, unit, isAuto)
      local isMet, ctx = checkMeetingInArea(resupplyUnitCtx, unit.name, systemCtx.firingUnits, unit, isAuto)

      if isMet then return true, ctx end
    end
  else
    -- Case: Firing unit looking for resupply units
    for _, firingUnitCtx in pairs(systemCtx.firingUnits) do
      -- local isMet, ctx = checkMeetingInArea(firingUnitCtx, unitGroup.name, systemCtx.resupplyUnits, unit, isAuto)
      local isMet, ctx = checkMeetingInArea(firingUnitCtx, unit.name, systemCtx.resupplyUnits, unit, isAuto)
      if isMet then return true, ctx end
    end
  end

  return false, nil
end

---Check if resupply unit has met with ammunition depot
---@param systemCtx SBJ__MissileSystemContext Weapon system context
---@param unit CMO__Unit Unit to check
---@param isAuto boolean Whether in automatic mode
---@return boolean isMet Whether units have met
---@return SBJ__ResupplyUnitContext|nil resupplyUnit The matched resupply unit context if met
function MissileSystem.isMetWithAmmoDepot(systemCtx, unit, isAuto)
  -- if not unit.group then return false, nil end
  -- local resupplyUnit = GameApi.ScenEdit_GetUnit(unit.group.guid)
  -- if not resupplyUnit then return false, nil end
  if not systemCtx.resupplyUnits[unit.name] then
    return false, nil
  end

  for _, resupplyUnitCtx in pairs(systemCtx.resupplyUnits) do
    local isStateValid = true

    if isAuto then
      local repoState = constants.MISSILE_SYSTEM_STATE.REPOSITIONING
      local reloadState = constants.MISSILE_SYSTEM_STATE.RELOAD
      isStateValid = (resupplyUnitCtx.state == repoState or resupplyUnitCtx.state == reloadState)
    end

    -- if resupplyUnitCtx.name == resupplyUnit.name and isStateValid then
    if resupplyUnitCtx.name == unit.name and isStateValid then
      local ammoDepot = GameApi.ScenEdit_GetUnit(resupplyUnitCtx.ammunition, unit.side)

      for _, pos in ipairs(resupplyUnitCtx.operationalArea.AHA) do
        local isInSameArea = unit:inArea(pos.area) and (ammoDepot and ammoDepot:inArea(pos.area))
            and resupplyUnitCtx.wpnCurrent == 0
        if isInSameArea then return true, resupplyUnitCtx end
      end
    end
  end

  return false, nil
end

---Check if firing unit reload conditions are met
---@param firingUnitCtx SBJ__FiringUnitContext Firing unit context
---@param systemCtx SBJ__MissileSystemContext Weapon system context
---@param isMet boolean Whether firing unit has met with resupply unit
---@param firingUnit CMO__Unit Firing unit group
---@param weaponDBID number Weapon database ID
---@return boolean # Whether reload conditions are met
local function isReadyToReloadFiringUnit(firingUnitCtx, systemCtx, isMet, firingUnit, weaponDBID)
  if firingUnitCtx.reloadStartTime == nil then return false end
  local elapsedTime = GameApi.ScenEdit_CurrentTime() - firingUnitCtx.reloadStartTime
  return elapsedTime >= systemCtx.reloadTime and isMet and
      MissileSystem.isLowAmmo(firingUnit, firingUnitCtx.ammoThreshold, weaponDBID)
end

---Check if resupply unit reload conditions are met
---@param resupplyUnitCtx SBJ__ResupplyUnitContext Resupply unit context
---@param systemCtx SBJ__MissileSystemContext Weapon system context
---@param isMet boolean Whether resupply unit has met with ammunition depot
---@return boolean # Whether reload conditions are met
local function isReadyToReloadResupplyUnit(resupplyUnitCtx, systemCtx, isMet)
  if resupplyUnitCtx.reloadStartTime == nil then return false end
  local elapsedTime = GameApi.ScenEdit_CurrentTime() - resupplyUnitCtx.reloadStartTime
  return elapsedTime >= systemCtx.reloadTime and resupplyUnitCtx.wpnCurrent == 0 and isMet
end

---Handle firing unit reload cycle (auto: detect low ammo + reposition; manual: reload only)
---@param systemCtx SBJ__MissileSystemContext Weapon system context
---@param firingUnitCtx SBJ__FiringUnitContext Firing unit context
---@param firingUnit CMO__Unit Firing unit group
---@param isAuto boolean Whether in automatic mode
---@param sideName string Side name
local function handleFiringUnitReloadCycle(systemCtx, firingUnitCtx, firingUnit, isAuto, sideName)
  if isAuto and firingUnitCtx.state == constants.MISSILE_SYSTEM_STATE.STATIC then
    if MissileSystem.isLowAmmo(firingUnit, firingUnitCtx.ammoThreshold, firingUnitCtx.weaponDBID) then
      moveToReloadPoint(firingUnitCtx, firingUnit)
    end
  end

  if firingUnitCtx.state == constants.MISSILE_SYSTEM_STATE.RELOAD then
    if firingUnitCtx.reloadStartTime == nil then
      firingUnitCtx.reloadStartTime = GameApi.ScenEdit_CurrentTime()
    end

    local isMet, _ = MissileSystem.isMetWithResupplyUnits(systemCtx, firingUnit, isAuto)
    local isReadyToReload = isReadyToReloadFiringUnit(firingUnitCtx, systemCtx, isMet, firingUnit,
      firingUnitCtx.weaponDBID)
    local resupplyUnitCtx = systemCtx.resupplyUnits[firingUnitCtx.resupplyUnit]

    if isReadyToReload then
      MissileSystem.reload(firingUnitCtx, resupplyUnitCtx, firingUnitCtx.weaponDBID, sideName)

      if isAuto then
        moveToHideArea(firingUnitCtx, firingUnit)
      else
        Logger.warn("Missile reload is finished/" .. firingUnitCtx.name)
      end
    end
  end
end

---Handle resupply unit reload cycle (auto: detect empty ammo + reposition; manual: reload only)
---@param systemCtx SBJ__MissileSystemContext Weapon system context
---@param resupplyUnitCtx SBJ__ResupplyUnitContext Resupply unit context
---@param resupplyUnit CMO__Unit Resupply unit group
---@param isAuto boolean Whether in automatic mode
local function handleResupplyUnitReloadCycle(systemCtx, resupplyUnitCtx, resupplyUnit, isAuto)
  if isAuto and resupplyUnitCtx.state == constants.MISSILE_SYSTEM_STATE.STATIC then
    if resupplyUnitCtx.wpnCurrent == 0 and findUnitArea(resupplyUnit, resupplyUnitCtx.operationalArea) then
      moveToAmmoHoldingArea(resupplyUnitCtx, resupplyUnit)
    end
  end

  if resupplyUnitCtx.state == constants.MISSILE_SYSTEM_STATE.RELOAD then
    if resupplyUnitCtx.reloadStartTime == nil then
      resupplyUnitCtx.reloadStartTime = GameApi.ScenEdit_CurrentTime()
    end

    local isMet, _ = MissileSystem.isMetWithAmmoDepot(systemCtx, resupplyUnit, isAuto)
    local isReadyToReload = isReadyToReloadResupplyUnit(resupplyUnitCtx, systemCtx, isMet)
    local ammoDepotCtx = systemCtx.ammunitions[resupplyUnitCtx.ammunition]

    if isReadyToReload then
      MissileSystem.transferAmmunition(resupplyUnitCtx, ammoDepotCtx)

      if isAuto then
        moveResupplyUnitToReloadPoint(resupplyUnitCtx, resupplyUnit)
      end

      Logger.warn("Ammo transload is finished/" .. resupplyUnitCtx.name)
    end
  end
end

---Handle status and actions of all resupply units
---@param msContext SBJ__MissileSystemContext Weapon system context
---@param isAuto boolean Whether in automatic mode
---@param sideName string Side name
local function processResupplyUnits(msContext, isAuto, sideName)
  for _, resupplyUnitCtx in pairs(msContext.resupplyUnits) do
    local resupplyUnit = GameApi.ScenEdit_GetUnit(resupplyUnitCtx.name, sideName)

    if resupplyUnit then
      handleResupplyUnitReloadCycle(msContext, resupplyUnitCtx, resupplyUnit, isAuto)
    end
  end
end

---Handle status and actions of all firing units
---@param systemCtx SBJ__MissileSystemContext Weapon system context
---@param isAuto boolean Whether in automatic mode
---@param sideName string Side name
local function processFiringUnits(systemCtx, isAuto, sideName)
  for _, firingUnitCtx in pairs(systemCtx.firingUnits) do
    local firingUnit = GameApi.ScenEdit_GetUnit(firingUnitCtx.name, sideName)

    if firingUnit then
      handleFiringUnitReloadCycle(systemCtx, firingUnitCtx, firingUnit, isAuto, sideName)
    end
  end
end

---Check status of all firing units and resupply units, and trigger corresponding actions
---@param systemCtx SBJ__MissileSystemContext Missile system context
---@param isAuto boolean Whether in automatic mode
---@param sideName string Side name
function MissileSystem.checkMissileSystemState(systemCtx, isAuto, sideName)
  processFiringUnits(systemCtx, isAuto, sideName)
  processResupplyUnits(systemCtx, isAuto, sideName)
end

---Handle logic when resupply unit is destroyed
---@param unit CMO__Unit Destroyed unit
---@param systemCtx SBJ__MissileSystemContext Weapon system context
---@return boolean # Whether unit was found and processed
function MissileSystem.handleSupplyAssetDestruction(unit, systemCtx)
  -- Determine unit type by checking if it has a group (type-safe approach)
  -- Ammunition depots are single units (no group), resupply units are groups
  local isAmmunitionDepot = (unit.group == nil)

  if isAmmunitionDepot then
    -- Handle ammunition depot destruction
    local ammoDepotCtx = systemCtx.ammunitions[unit.name]

    if ammoDepotCtx and ammoDepotCtx.wpnCurrent > 0 then
      ammoDepotCtx.wpnCurrent = 0
      return true
    end
  else
    -- Handle resupply unit destruction (part of a group)
    local resupplyUnitCtx = systemCtx.resupplyUnits[unit.group.name]

    if resupplyUnitCtx and resupplyUnitCtx.wpnCurrent > 0 then
      -- Reduce ammunition proportionally when one unit in the resupply unit is destroyed
      local ammoPerUnit = resupplyUnitCtx.wpnDefault / resupplyUnitCtx.unitCount

      if (resupplyUnitCtx.wpnCurrent - ammoPerUnit) < 0 then
        resupplyUnitCtx.wpnCurrent = 0
      else
        resupplyUnitCtx.wpnCurrent = resupplyUnitCtx.wpnCurrent - ammoPerUnit
      end
      return true
    end
  end

  return false
end

---Get area color code based on position type
---@param positionType string Position type identifier (RL/HA/AHA/MASK/FP)
---@return string # Hexadecimal color code
local function getOperationalAreaColor(positionType)
  local colorMap = {
    [constants.POSITION_TYPES.RELOAD_POINT] = "4dd9822b",
    [constants.POSITION_TYPES.HIDE_AREA] = "4d137cbd",
    [constants.POSITION_TYPES.AMMO_HOLDING_AREA] = "4d0f9960",
    [constants.POSITION_TYPES.MASK] = "4dff6b6b",
  }

  return colorMap[positionType] or "4d8b5cf6"
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
---@param positionType string Position type (RL/HA/FP)
---@param position SBJ__Position Position configuration
---@param index integer Position index within operational area
---@param operationalArea SBJ__OperationalArea Operational area configuration
---@param enemySide string Enemy side name for target filter
---@param sideName string Owner side name
---@return boolean # Whether trigger was successfully added
local function addTriggerToEvent(positionType, position, index, operationalArea, enemySide, sideName)
  local triggerName = string.format("(%s) Arrive in %s - %d - %s", sideName, positionType, index, operationalArea.name)
  local zoneName = positionType .. "/" .. tostring(index) .. "/" .. operationalArea.name
  local zone = GameApi.ScenEdit_AddZone(sideName, constants.ZONE_TYPES.STANDARD, {
    area = position.area,
    description = zoneName
  })

  if zone then
    local eventName = string.format("(%s) Arrive in %s", sideName, positionType)
    zone.areacolor = getOperationalAreaColor(positionType)
    position.area = GameUtils.convertToRPArray(zone)
    GameApi.ScenEdit_SetTrigger({
      Description = triggerName,
      Mode = "add",
      type = "UnitEntersArea",
      TargetFilter = { TargetSide = enemySide },
      Area = position.area,
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
  -- Remove standard zones
  GameUtils.removeZones(ZONE_PATTERNS, constants.ZONE_TYPES.STANDARD, sideName)

  -- Remove custom environment zones
  GameUtils.removeZones(ZONE_PATTERNS, constants.ZONE_TYPES.CUSTOM_ENVIRONMENT, sideName)

  -- Build event names and trigger prefixes dynamically
  local eventNames, triggerPrefixes = buildEventAndTriggerNames(sideName, posTypes)

  -- Remove event triggers
  GameUtils.removeEventTriggers(eventNames, triggerPrefixes, "UnitEntersArea")

  Logger.log("missileSystem",
    string.format("Cleaned up existing triggers and zones for side: %s", sideName))
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
    zone.areacolor = getOperationalAreaColor(constants.POSITION_TYPES.MASK)
    zone.landcoverheight = 1000
    zone.landcovertype = 254
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
local function createPositionTriggers(operationalArea, positionTypes, enemySide, sideName)
  local created, failed = 0, 0

  for _, positionType in ipairs(positionTypes) do
    for index, position in ipairs(operationalArea[positionType]) do
      ---@cast position SBJ__Position
      if addTriggerToEvent(positionType, position, index, operationalArea, enemySide, sideName) then
        created = created + 1
      else
        failed = failed + 1
        Logger.warn(string.format(
          "missileSystem: Failed to create trigger for %s-%d in %s",
          positionType, index, operationalArea.name
        ))
      end
    end
  end

  return created, failed
end

---Initialize event triggers and zones for missile system operational areas
---@param operationalAreas SBJ__OperationalArea[] Array of operational area configurations
---@param positionTypes string[] Position type identifiers (RL/HA/AHA/FP)
---@param sideName string Side name for zone/trigger ownership
function MissileSystem.initEventTriggers(operationalAreas, positionTypes, sideName)
  local sideCfg = GameUtils.getCachedSideConfig(sideName)

  -- Step 1: Cleanup existing triggers and zones
  cleanupExistingTriggersAndZones(positionTypes, sideName)

  -- Step 2: Create new triggers and zones with statistics
  local totalCreated, totalFailed, maskCreated, maskFailed = 0, 0, 0, 0

  for _, operationalArea in ipairs(operationalAreas) do
    -- Create position triggers
    local created, failed = createPositionTriggers(operationalArea, positionTypes, sideCfg.enemySide, sideName)
    totalCreated = totalCreated + created
    totalFailed = totalFailed + failed

    -- Create custom environment zone for terrain masking
    if addCustomEnvironmentZone(operationalArea, sideName) then
      maskCreated = maskCreated + 1
    else
      maskFailed = maskFailed + 1
      Logger.warn(string.format("missileSystem: Failed to create MASK zone for %s", operationalArea.name))
    end
  end

  -- Log summary
  Logger.log("missileSystem", string.format(
    "Initialized %s missile system: %d/%d triggers created, %d/%d mask zones created",
    sideName, totalCreated, totalCreated + totalFailed,
    maskCreated, maskCreated + maskFailed
  ))
end

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

---Create firing units according to configuration
---@param systemCfg SBJ__MissileSystemConfig Weapon system configuration
---@param descriptor SBJ__FiringUnitDescriptor Firing unit descriptor
---@param sideName string Side name for unit creation
---@return integer created Number of units successfully created
---@return integer expected Total number of units expected to create
local function addFiringUnit(systemCfg, descriptor, sideName)
  if not descriptor.operationalArea.HA or #descriptor.operationalArea.HA == 0 then
    Logger.error(string.format("missileSystem: No HA defined for firing unit '%s' (OPAREA: %s), cannot add unit",
      descriptor.name, descriptor.operationalArea.name))
    return 0, 0
  end

  local expected = systemCfg.resupplyUnits[descriptor.resupplyUnit].unitCount
  local size = #descriptor.operationalArea.HA[1].course
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
      type = "Facility",
      group = descriptor.name,
      latitude = descriptor.operationalArea.HA[1].course[size].latitude,
      longitude = descriptor.operationalArea.HA[1].course[size].longitude
    })

    if addedUnit then
      GameApi.ScenEdit_ClearAllMagazines({ side = sideName, guid = addedUnit.guid })
      local totalRemovedWpnCount = 0
      local removedWpnDBID

      for _, mount in ipairs(addedUnit.mounts) do
        for _, wpn in ipairs(mount.mount_weapons) do
          if wpn.wpn_current > 0 and wpn.wpn_dbid ~= descriptor.weaponDBID then
            totalRemovedWpnCount = totalRemovedWpnCount + wpn.wpn_current
            removedWpnDBID = wpn.wpn_dbid
          end
        end
      end

      if totalRemovedWpnCount > 0 and removedWpnDBID ~= nil then
        GameApi.ScenEdit_AddReloadsToUnit({
          side = sideName,
          guid = addedUnit.guid,
          wpn_dbid = removedWpnDBID,
          number = totalRemovedWpnCount,
          remove = true
        })

        GameApi.ScenEdit_AddReloadsToUnit({
          side = sideName,
          guid = addedUnit.guid,
          wpn_dbid = descriptor.weaponDBID,
          number = totalRemovedWpnCount,
        })
      end

      created = created + 1
    end
  end

  return created, expected
end

---Create resupply units according to configuration
---@param descriptor SBJ__ResupplyUnitDescriptor Resupply unit descriptor
---@param sideName string Side name for unit creation
---@return integer created Number of units successfully created
---@return integer expected Total number of units expected to create
local function addResupplyUnit(descriptor, sideName)
  if not descriptor.operationalArea.RL or #descriptor.operationalArea.RL == 0 then
    Logger.error(string.format("missileSystem: No RL defined for firing unit '%s' (OPAREA: %s), cannot add unit",
      descriptor.name, descriptor.operationalArea.name))
    return 0, 0
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
      name = GameUtils.formatOrdinalUnitName(i, unitType or "", restStr)
    end

    local result = GameApi.ScenEdit_AddUnit({
      side = sideName,
      unitname = "Ammo Sec, " .. name,
      dbid = constants.PLATFORMS.AMMO_TRUCK,
      type = "Facility",
      group = descriptor.name,
      latitude = descriptor.operationalArea.RL[1].course[size].latitude,
      longitude = descriptor.operationalArea.RL[1].course[size].longitude
    })

    if result then
      created = created + 1
    end
  end

  return created, expected
end

---Create ammunition depot unit according to configuration
---@param systemCfg SBJ__MissileSystemConfig Weapon system configuration
---@param descriptor SBJ__AmmunitionUnitDescriptor Ammunition unit descriptor
---@param sideName string Side name for unit creation
---@return boolean # Whether unit was successfully created
local function addAmmunition(systemCfg, descriptor, sideName)
  local restStr = descriptor.name:gsub("^Ammo Revetment, ", "")
  local name = restStr
  local resupplyUnitDescriptor = systemCfg.resupplyUnits[name]

  if not resupplyUnitDescriptor then
    name = "Ammo Sec, " .. name
  end

  resupplyUnitDescriptor = systemCfg.resupplyUnits[name]

  if resupplyUnitDescriptor then
    if not #resupplyUnitDescriptor.operationalArea.AHA or #resupplyUnitDescriptor.operationalArea.AHA == 0 then
      Logger.error(string.format("missileSystem: No AHA defined for firing unit '%s' (OPAREA: %s), cannot add unit",
        descriptor.name, resupplyUnitDescriptor.operationalArea.name))
      return false
    end

    local size = #resupplyUnitDescriptor.operationalArea.AHA[1].course
    GameApi.ScenEdit_AddUnit({
      side = sideName,
      unitname = descriptor.name,
      dbid = constants.PLATFORMS.AMMO,
      type = "Facility",
      latitude = resupplyUnitDescriptor.operationalArea.AHA[1].course[size].latitude,
      longitude = resupplyUnitDescriptor.operationalArea.AHA[1].course[size].longitude
    })
    return true
  end

  return false
end

---Add missile system to the game
---@param groundForceCfg SBJ__GroundForceConfig Ground force context
---@param sideName string Side name
function MissileSystem.addMissileSystems(groundForceCfg, sideName)
  for _, systemCfg in pairs(groundForceCfg) do
    ---@cast systemCfg SBJ__MissileSystemConfig
    for _, descriptor in pairs(systemCfg.firingUnits) do
      removeMissileSystem(descriptor, sideName)
      addFiringUnit(systemCfg, descriptor, sideName)
    end

    for _, descriptor in pairs(systemCfg.resupplyUnits) do
      removeMissileSystem(descriptor, sideName)
      addResupplyUnit(descriptor, sideName)
    end

    for _, descriptor in pairs(systemCfg.ammunitions) do
      removeMissileSystem(descriptor, sideName)
      addAmmunition(systemCfg, descriptor, sideName)
    end
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
