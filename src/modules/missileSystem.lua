local Utils = require("src.utils.utils")
local GameApi = require("src.utils.gameApi")
local Logger = require("src.utils.logger")
local constants = require("src.core.constants")
local GameUtils = require("src.utils.gameUtils")

local MissileSystem = {}


-- Module constants
local BATTERY_CONSTANTS = {
  REPOSITION_SPEED = 30,                -- Speed (km/h) when moving between positions
  MANUAL_RELOAD_DELAY_MULTIPLIER = 100, -- Time multiplier for manual reload mode
}

---Find the area where the unit is located
---@param unit CMO__Unit Unit object
---@param operationalArea SBJ__OperationalArea Position information table
---@return string[]|nil # Area name or nil
local function findUnitArea(unit, operationalArea)
  for _, pos in ipairs(operationalArea.RL) do
    if unit:inArea(pos.area) then
      return pos.area
    end
  end

  return nil
end

---Check if firing unit reload conditions are met
---@param firingUnitCtx SBJ__FiringUnitContext Firing unit context
---@param systemCtx SBJ__MissileSystemContext Weapon system context
---@param metResult {isMet: boolean} Result of resupply unit meeting check
---@param firingUnit CMO__Unit Firing unit group
---@param weaponDBID number Weapon database ID
---@return boolean # Whether reload conditions are met
local function isReadyToReloadFiringUnit(firingUnitCtx, systemCtx, metResult, firingUnit, weaponDBID)
  if firingUnitCtx.reloadStartTime == nil then
    return false
  end

  local elapsedTime = GameApi.ScenEdit_CurrentTime() - firingUnitCtx.reloadStartTime

  return elapsedTime >= systemCtx.reloadTime and
      metResult.isMet and
      MissileSystem.isLowAmmo(firingUnit, firingUnitCtx.ammoThreshold, weaponDBID)
end

---Check if resupply unit reload conditions are met
---@param resupplyUnitCtx SBJ__ResupplyUnitContext Resupply unit context
---@param systemCtx SBJ__MissileSystemContext Weapon system context
---@param metResult {isMet: boolean} Result of ammunition depot meeting check
---@return boolean # Whether reload conditions are met
local function isReadyToReloadResupplyUnit(resupplyUnitCtx, systemCtx, metResult)
  if resupplyUnitCtx.reloadStartTime == nil then
    return false
  end

  local elapsedTime = GameApi.ScenEdit_CurrentTime() - resupplyUnitCtx.reloadStartTime

  return elapsedTime >= systemCtx.reloadTime and
      resupplyUnitCtx.wpnCurrent == 0 and
      metResult.isMet
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
    GameApi.ScenEdit_SetDoctrine(
      { side = unit.side, guid = unit.guid },
      { weapon_control_status_land = params.wcs }
    )
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
---@param wcs integer? Weapon control status (optional)
---@param useLastCourse boolean? Whether to use the last waypoint in course (default: false)
---@return boolean # Success status
local function moveUnitToPosition(unitName, battery, positions, positionType, wcs, useLastCourse)
  local posCount = Utils.getCount(positions)
  if posCount == 0 then
    Logger.error(string.format("missileSystem: No %s positions available for %s", positionType, unitName))
    return false
  end

  local posIdx = math.random(posCount)
  local position = positions[posIdx]

  if not position or not position.course then
    Logger.error(string.format("missileSystem: Invalid %s position data at index %d for %s",
      positionType, posIdx, unitName))
    return false
  end

  -- Use last waypoint if requested and course is an array
  local course = position.course
  if useLastCourse and type(course) == "table" and #course > 0 then
    course = { course[#course] }
  end

  for _, guid in ipairs(battery.group.unitlist) do
    local unit = GameApi.ScenEdit_GetUnit(guid)

    if unit then
      setUnitProperties({
        unit = unit,
        throttle = "Flank",
        speed = BATTERY_CONSTANTS.REPOSITION_SPEED,
        course = course,
        holdPosition = false,
        wcs = wcs
      })
    end
  end

  return true
end

---Command firing unit to move to reload point (RL)
---@param config SBJ__Config Configuration object
---@param firingUnitCtx SBJ__FiringUnitContext Firing unit context
---@param firingUnit CMO__Unit Firing unit group
local function moveToReloadPoint(config, firingUnitCtx, firingUnit)
  firingUnitCtx.state = config.batteryState.REPOSITIONING
  moveUnitToPosition(
    firingUnitCtx.name,
    firingUnit,
    firingUnitCtx.operationalArea.RL,
    "RL",
    constants.WCS.HOLD
  )
end

---Command firing unit to move to hide area (HA)
---@param config SBJ__Config Configuration object
---@param firingUnitCtx SBJ__FiringUnitContext Firing unit context
---@param firingUnit CMO__Unit Firing unit group
local function moveToHideArea(config, firingUnitCtx, firingUnit)
  -- Check if HA exists (some OPAREAs may not have HA)
  if not firingUnitCtx.operationalArea.HA then
    Logger.log("missileSystem",
      "missileSystem: No HA defined for firing unit " .. firingUnitCtx.name .. ", skipping hide movement")
    return
  end

  firingUnitCtx.state = config.batteryState.REPOSITIONING
  moveUnitToPosition(
    firingUnitCtx.name,
    firingUnit,
    firingUnitCtx.operationalArea.HA,
    "HA",
    constants.WCS.HOLD
  )
end

---Command resupply unit to move to ammunition holding area (AHA)
---@param config SBJ__Config Configuration object
---@param resupplyUnitCtx SBJ__ResupplyUnitContext Resupply unit context
---@param resupplyUnit CMO__Unit Resupply unit group
local function moveToAmmoHoldingArea(config, resupplyUnitCtx, resupplyUnit)
  resupplyUnitCtx.state = config.batteryState.REPOSITIONING
  moveUnitToPosition(resupplyUnitCtx.name, resupplyUnit, resupplyUnitCtx.operationalArea.AHA, "AHA")
end

---Transfer ammunition from ammunition depot to resupply unit
---@param resupplyUnitCtx SBJ__ResupplyUnitContext Resupply unit context
---@param ammoDepotCtx SBJ__AmmunitionContext Ammunition depot context
local function transferAmmunition(resupplyUnitCtx, ammoDepotCtx)
  if ammoDepotCtx.wpnCurrent > 0 and resupplyUnitCtx.wpnCurrent < resupplyUnitCtx.wpnDefault then
    if ammoDepotCtx.wpnCurrent >= resupplyUnitCtx.wpnDefault then
      resupplyUnitCtx.wpnCurrent = resupplyUnitCtx.wpnCurrent + resupplyUnitCtx.wpnDefault
      ammoDepotCtx.wpnCurrent = ammoDepotCtx.wpnCurrent - resupplyUnitCtx.wpnDefault
    else
      resupplyUnitCtx.wpnCurrent = resupplyUnitCtx.wpnCurrent + ammoDepotCtx.wpnCurrent
      ammoDepotCtx.wpnCurrent = 0
    end
  end

  resupplyUnitCtx.reloadStartTime = nil
end

---Command resupply unit to move to reload point (RL)
---@param config SBJ__Config Configuration object
---@param resupplyUnitCtx SBJ__ResupplyUnitContext Resupply unit context
---@param resupplyUnit CMO__Unit Resupply unit group
local function moveResupplyUnitToReloadPoint(config, resupplyUnitCtx, resupplyUnit)
  resupplyUnitCtx.state = config.batteryState.REPOSITIONING
  moveUnitToPosition(resupplyUnitCtx.name, resupplyUnit, resupplyUnitCtx.operationalArea.RL, "RL", nil, true)
end

---Handle automatic firing unit repositioning logic
---@param config SBJ__Config Configuration object
---@param systemCtx SBJ__MissileSystemContext Weapon system context
---@param firingUnitCtx SBJ__FiringUnitContext Firing unit context
---@param firingUnit CMO__Unit Firing unit group
---@param isAuto boolean Whether in automatic mode
---@param sideName string Side name
local function handleAutomaticFiringUnitRepositioning(config, systemCtx, firingUnitCtx, firingUnit, isAuto, sideName)
  if firingUnitCtx.state == config.batteryState.STATIC then
    if MissileSystem.isLowAmmo(firingUnit, firingUnitCtx.ammoThreshold, firingUnitCtx.weaponDBID) then
      moveToReloadPoint(config, firingUnitCtx, firingUnit)
    end
  end

  if firingUnitCtx.state == config.batteryState.RELOAD then
    if firingUnitCtx.reloadStartTime == nil then
      firingUnitCtx.reloadStartTime = GameApi.ScenEdit_CurrentTime() - systemCtx.reloadTime
    end

    local result = MissileSystem.isMetWithResupplyUnits(config, systemCtx, firingUnit, isAuto)
    local isReadyToReload = isReadyToReloadFiringUnit(firingUnitCtx, systemCtx, result, firingUnit,
      firingUnitCtx.weaponDBID)
    local resupplyUnitCtx = systemCtx.resupplyUnits[firingUnitCtx.resupplyUnit]

    if isReadyToReload then
      MissileSystem.reload(firingUnitCtx, resupplyUnitCtx, firingUnitCtx.weaponDBID, sideName)
      moveToHideArea(config, firingUnitCtx, firingUnit)
    end
  end
end

---Handle manual firing unit reload logic
---@param config SBJ__Config Configuration object
---@param systemCtx SBJ__MissileSystemContext Weapon system context
---@param firingUnitCtx SBJ__FiringUnitContext Firing unit context
---@param firingUnit CMO__Unit Firing unit group
---@param isAuto boolean Whether in automatic mode
---@param sideName string Side name
local function handleManualFiringUnitReload(config, systemCtx, firingUnitCtx, firingUnit, isAuto, sideName)
  if firingUnitCtx.reloadStartTime == nil then
    -- In manual mode, set a far future time to prevent automatic completion
    firingUnitCtx.reloadStartTime = GameApi.ScenEdit_CurrentTime() +
        systemCtx.reloadTime * BATTERY_CONSTANTS.MANUAL_RELOAD_DELAY_MULTIPLIER
  end

  local result = MissileSystem.isMetWithResupplyUnits(config, systemCtx, firingUnit, isAuto)
  local isReadyToReload = isReadyToReloadFiringUnit(firingUnitCtx, systemCtx, result, firingUnit,
    firingUnitCtx.weaponDBID)
  local resupplyUnitCtx = systemCtx.resupplyUnits[firingUnitCtx.resupplyUnit]

  if isReadyToReload then
    MissileSystem.reload(firingUnitCtx, resupplyUnitCtx, firingUnitCtx.weaponDBID, sideName)

    if config.isDevMode then
      GameApi.ScenEdit_MsgBox("Missile reload is finished/" .. firingUnitCtx.name, 1)
    end
  end
end

---Handle automatic resupply unit repositioning logic
---@param config SBJ__Config Configuration object
---@param systemCtx SBJ__MissileSystemContext Weapon system context
---@param resupplyUnitCtx SBJ__ResupplyUnitContext Resupply unit context
---@param resupplyUnit CMO__Unit Resupply unit group
---@param isAuto boolean Whether in automatic mode
local function handleAutomaticResupplyUnitRepositioning(config, systemCtx, resupplyUnitCtx, resupplyUnit, isAuto)
  if resupplyUnitCtx.state == config.batteryState.STATIC then
    -- Check if unit is in any RL area
    local isInRLArea = false
    for _, pos in ipairs(resupplyUnitCtx.operationalArea.RL) do
      if resupplyUnit:inArea(pos.area) then
        isInRLArea = true
        break
      end
    end

    if resupplyUnitCtx.wpnCurrent == 0 and isInRLArea then
      moveToAmmoHoldingArea(config, resupplyUnitCtx, resupplyUnit)
    end
  end

  if resupplyUnitCtx.state == config.batteryState.RELOAD then
    local result = MissileSystem.isMetWithAmmoDepot(config, systemCtx, resupplyUnit, isAuto)
    local isReadyToReload = isReadyToReloadResupplyUnit(resupplyUnitCtx, systemCtx, result)
    local ammoDepotCtx = systemCtx.ammunitions[resupplyUnitCtx.ammunition]

    if isReadyToReload then
      transferAmmunition(resupplyUnitCtx, ammoDepotCtx)
      moveResupplyUnitToReloadPoint(config, resupplyUnitCtx, resupplyUnit)

      if config.isDevMode then
        GameApi.ScenEdit_MsgBox("Ammo transload is finished/" .. resupplyUnitCtx.name, 1)
      end
    end
  end
end

---Handle manual resupply unit reload logic
---@param config SBJ__Config Configuration object
---@param systemCtx SBJ__MissileSystemContext Weapon system context
---@param resupplyUnitCtx SBJ__ResupplyUnitContext Resupply unit context
---@param resupplyUnit CMO__Unit Resupply unit group
---@param isAuto boolean Whether in automatic mode
local function handleManualResupplyUnitReload(config, systemCtx, resupplyUnitCtx, resupplyUnit, isAuto)
  if resupplyUnitCtx.reloadStartTime == nil then
    -- In manual mode, set a far future time to prevent automatic completion
    resupplyUnitCtx.reloadStartTime = GameApi.ScenEdit_CurrentTime() +
        systemCtx.reloadTime * BATTERY_CONSTANTS.MANUAL_RELOAD_DELAY_MULTIPLIER
  end

  local result = MissileSystem.isMetWithAmmoDepot(config, systemCtx, resupplyUnit, isAuto)
  local isReadyToReload = isReadyToReloadResupplyUnit(resupplyUnitCtx, systemCtx, result)
  local ammoDepotCtx = systemCtx.ammunitions[resupplyUnitCtx.ammunition]

  if isReadyToReload then
    transferAmmunition(resupplyUnitCtx, ammoDepotCtx)

    if config.isDevMode then
      GameApi.ScenEdit_MsgBox("Ammo transload is finished/" .. resupplyUnitCtx.name, 1)
    end
  end
end

---Handle status and actions of all resupply units
---@param config SBJ__Config Configuration object
---@param msContext SBJ__MissileSystemContext Weapon system context
---@param isAuto boolean Whether in automatic mode
---@param sideName string Side name
local function processResupplyUnits(config, msContext, isAuto, sideName)
  for _, resupplyUnitCtx in pairs(msContext.resupplyUnits) do
    local resupplyUnit = GameApi.ScenEdit_GetUnit(resupplyUnitCtx.name, sideName)

    if resupplyUnit then
      if isAuto then
        handleAutomaticResupplyUnitRepositioning(config, msContext, resupplyUnitCtx, resupplyUnit, isAuto)
      else
        handleManualResupplyUnitReload(config, msContext, resupplyUnitCtx, resupplyUnit, isAuto)
      end
    end
  end
end

---Handle status and actions of all firing units
---@param config SBJ__Config Configuration object
---@param systemCtx SBJ__MissileSystemContext Weapon system context
---@param isAuto boolean Whether in automatic mode
---@param sideName string Side name
local function processFiringUnits(config, systemCtx, isAuto, sideName)
  for _, firingUnitCtx in pairs(systemCtx.firingUnits) do
    local firingUnit = GameApi.ScenEdit_GetUnit(firingUnitCtx.name, sideName)

    if firingUnit then
      if isAuto then
        handleAutomaticFiringUnitRepositioning(config, systemCtx, firingUnitCtx, firingUnit, isAuto, sideName)
      else
        handleManualFiringUnitReload(config, systemCtx, firingUnitCtx, firingUnit, isAuto, sideName)
      end
    end
  end
end

---Calculate ammunition statistics for a unit
---@param unit CMO__Unit|nil Unit object
---@param weaponDBID number Weapon database ID
---@return integer currentAmmo Current ammunition count
---@return integer maxAmmo Maximum ammunition capacity
local function calculateAmmoStats(unit, weaponDBID)
  local totalCurrent = 0
  local totalMax = 0

  if not unit or not unit.mounts then
    return totalCurrent, totalMax
  end

  for _, mount in ipairs(unit.mounts) do
    for _, wpn in ipairs(mount.mount_weapons) do
      if wpn.wpn_dbid == weaponDBID then
        totalCurrent = totalCurrent + wpn.wpn_current
        totalMax = totalMax + wpn.wpn_maxcap
      end
    end
  end

  return totalCurrent, totalMax
end


---Reload ammunition for a single unit
---@param unit CMO__Unit|nil Unit object
---@param weaponDBID number Weapon database ID
---@param resupplyUnitCtx SBJ__ResupplyUnitContext Resupply unit context
---@return integer # Total ammunition consumed
local function reloadUnit(unit, weaponDBID, resupplyUnitCtx)
  if not unit then
    return 0
  end

  local currentAmmo, maxAmmo = calculateAmmoStats(unit, weaponDBID)
  local required = maxAmmo - currentAmmo

  if required > 0 and resupplyUnitCtx.wpnCurrent > 0 then
    local ammoToLoad = math.min(required, resupplyUnitCtx.wpnCurrent)

    GameApi.ScenEdit_AddReloadsToUnit({
      guid = unit.guid,
      side = unit.side,
      wpn_dbid = weaponDBID,
      number = ammoToLoad
    })

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
function MissileSystem.reload(firingUnitCtx, resupplyUnitCtx, weaponDBID, sideName)
  local firingUnit = GameApi.ScenEdit_GetUnit(firingUnitCtx.name, sideName)
  if not firingUnit then return end

  for _, guid in ipairs(firingUnit.group.unitlist) do
    local unit = GameApi.ScenEdit_GetUnit(guid)
    reloadUnit(unit, weaponDBID, resupplyUnitCtx)
  end

  firingUnitCtx.reloadStartTime = nil
end

---Set firing unit reload start time
---@param config SBJ__Config Configuration object
---@param firingUnitCtx SBJ__FiringUnitContext Firing unit context
---@param firingUnit CMO__Unit Firing unit group
---@param isAuto boolean Whether in automatic mode
function MissileSystem.setReloadStartTime(config, firingUnitCtx, firingUnit, isAuto)
  firingUnitCtx.state = config.batteryState.RELOAD
  firingUnitCtx.reloadStartTime = GameApi.ScenEdit_CurrentTime()

  for _, guid in ipairs(firingUnit.group.unitlist) do
    local u = GameApi.ScenEdit_GetUnit(guid)

    if u and isAuto then
      setUnitProperties({
        unit = u,
        holdPosition = true,
        formation = { spacing = 0, transpose = true },
      })
    end
  end
end

---Set firing unit weapon control status to free fire
---@param config SBJ__Config Configuration object
---@param firingUnitCtx SBJ__FiringUnitContext Firing unit context
---@param firingUnit CMO__Unit Firing unit group
function MissileSystem.setWCSToFree(config, firingUnitCtx, firingUnit)
  firingUnitCtx.state = config.batteryState.STATIC

  for _, guid in ipairs(firingUnit.group.unitlist) do
    local u = GameApi.ScenEdit_GetUnit(guid)

    if u then
      setUnitProperties({
        unit = u,
        holdPosition = true,
        wcs = constants.WCS.FREE, -- Free fire
        formation = { spacing = 0, transpose = true }
      })
    end
  end
end

---Set firing unit status to hide
---@param config SBJ__Config Configuration object
---@param firingUnitCtx SBJ__FiringUnitContext Firing unit context
---@param firingUnit CMO__Unit Firing unit group
function MissileSystem.setStateToHIDE(config, firingUnitCtx, firingUnit)
  firingUnitCtx.state = config.batteryState.HIDE

  for _, guid in ipairs(firingUnit.group.unitlist) do
    local u = GameApi.ScenEdit_GetUnit(guid)

    if u then
      setUnitProperties({
        unit = u,
        holdPosition = true,
        wcs = constants.WCS.HOLD, -- Hold fire while hiding
        formation = { spacing = 0, transpose = true }
      })
    end
  end
end

---Check if unit/group ammunition is below specified percentage
---@param firingUnit CMO__Unit Unit or group object
---@param percentage number Percentage threshold
---@param weaponDBID number Weapon database ID
---@return boolean # Whether it is low ammunition
function MissileSystem.isLowAmmo(firingUnit, percentage, weaponDBID)
  local totalCurrent = 0
  local totalMax = 0

  -- Process single unit or all units in group
  local units = firingUnit.group and firingUnit.group.unitlist or { firingUnit.guid }
  for _, guid in ipairs(units) do
    local unit = GameApi.ScenEdit_GetUnit(guid)
    local currentAmmo, maxAmmo = calculateAmmoStats(unit, weaponDBID)
    totalCurrent = totalCurrent + currentAmmo
    totalMax = totalMax + maxAmmo
  end

  if totalMax == 0 then
    return false
  end
  return (totalCurrent / totalMax * 100) <= percentage
end

---Command firing unit to move to firing point (FP)
---@param config SBJ__Config Configuration object
---@param firingUnitCtx SBJ__FiringUnitContext Firing unit context
---@param firingUnit CMO__Unit Firing unit group
function MissileSystem.moveToFiringPoint(config, firingUnitCtx, firingUnit)
  firingUnitCtx.state = config.batteryState.REPOSITIONING
  moveUnitToPosition(firingUnitCtx.name, firingUnit, firingUnitCtx.operationalArea.FP, "FP")
end

---Check if two types of units have met in the same area
---@param targetCtx SBJ__FiringUnitContext|SBJ__ResupplyUnitContext Target unit context (firing unit or resupply unit)
---@param targetName string Target unit name to match
---@param counterpartList SBJ__FiringUnitContext[]|SBJ__ResupplyUnitContext[] List of counterpart units to check
---@param unit CMO__Unit Original unit for area checking
---@param config SBJ__Config Configuration
---@param isAuto boolean Whether in automatic mode
---@return boolean isMet Whether units have met
---@return SBJ__FiringUnitContext|SBJ__ResupplyUnitContext|nil context The matched context if met
local function checkMeetingInArea(targetCtx, targetName, counterpartList, unit, config, isAuto)
  local isStateValid = true

  if isAuto then
    local repoState = config.batteryState.REPOSITIONING
    local reloadState = config.batteryState.RELOAD
    isStateValid = (targetCtx.state == repoState or targetCtx.state == reloadState)
  end

  if targetCtx.name == targetName and isStateValid then
    -- local area = findUnitArea(unit, operationalAreas)
    local area = findUnitArea(unit, targetCtx.operationalArea)
    if not area then return false, nil end

    for _, counterpartCtx in pairs(counterpartList) do
      local counterpart = GameApi.ScenEdit_GetUnit(counterpartCtx.name, unit.side)
      if counterpart and counterpart:inArea(area) then
        return true, targetCtx
      end
    end
  end

  return false, nil
end

---Check if firing unit has met with resupply units
---@param config SBJ__Config Configuration object
---@param systemCtx SBJ__MissileSystemContext Weapon system context
---@param unit CMO__Unit Unit to check
---@param isAuto boolean Whether in automatic mode
---@return {isMet: boolean, firingUnit: SBJ__FiringUnitContext|SBJ__ResupplyUnitContext|nil} # Meeting status with resupply unit context
function MissileSystem.isMetWithResupplyUnits(config, systemCtx, unit, isAuto)
  if not unit.group then return { isMet = false, firingUnit = nil } end
  local unitGroup = GameApi.ScenEdit_GetUnit(unit.group.guid)
  if not unitGroup then return { isMet = false, firingUnit = nil } end

  -- Determine unit type by checking which collection contains this GUID
  local isResupplyUnit = systemCtx.resupplyUnits[unitGroup.name] ~= nil

  if isResupplyUnit then
    -- Case: Resupply unit looking for firing units
    for _, resupplyUnitCtx in pairs(systemCtx.resupplyUnits) do
      local isMet, ctx = checkMeetingInArea(
        resupplyUnitCtx, unitGroup.name, systemCtx.firingUnits, unit, config, isAuto
      )
      if isMet then
        return { isMet = true, firingUnit = ctx }
      end
    end
  else
    -- Case: Firing unit looking for resupply units
    for _, firingUnitCtx in pairs(systemCtx.firingUnits) do
      local isMet, ctx = checkMeetingInArea(
        firingUnitCtx, unitGroup.name, systemCtx.resupplyUnits, unit, config, isAuto
      )
      if isMet then
        return { isMet = true, firingUnit = ctx }
      end
    end
  end

  return { isMet = false, firingUnit = nil }
end

---Check if resupply unit has met with ammunition depot
---@param config SBJ__Config Configuration object
---@param systemCtx SBJ__MissileSystemContext Weapon system context
---@param unit CMO__Unit Unit to check
---@param isAuto boolean Whether in automatic mode
---@return {isMet: boolean, resupplyUnit: SBJ__ResupplyUnitContext|nil} # Meeting status with ammo depot context
function MissileSystem.isMetWithAmmoDepot(config, systemCtx, unit, isAuto)
  if not unit.group then return { isMet = false, resupplyUnit = nil } end
  local resupplyUnit = GameApi.ScenEdit_GetUnit(unit.group.guid)
  if not resupplyUnit then return { isMet = false, resupplyUnit = nil } end

  for _, resupplyUnitCtx in pairs(systemCtx.resupplyUnits) do
    local isStateValid = true

    if isAuto then
      local repoState = config.batteryState.REPOSITIONING
      local reloadState = config.batteryState.RELOAD
      isStateValid = (resupplyUnitCtx.state == repoState or resupplyUnitCtx.state == reloadState)
    end

    if resupplyUnitCtx.name == resupplyUnit.name and isStateValid then
      local ammoDepot = GameApi.ScenEdit_GetUnit(resupplyUnitCtx.ammunition, unit.side)

      for _, pos in ipairs(resupplyUnitCtx.operationalArea.AHA) do
        local isInSameArea = unit:inArea(pos.area) and (ammoDepot and ammoDepot:inArea(pos.area))
        if isInSameArea then return { isMet = true, resupplyUnit = resupplyUnitCtx } end
      end
    end
  end

  return { isMet = false, resupplyUnit = nil }
end

---Check status of all firing units and resupply units, and trigger corresponding actions
---@param config SBJ__Config Configuration object
---@param systemCtx SBJ__MissileSystemContext Weapon system context
---@param isAuto boolean Whether in automatic mode
---@param sideName string Side name
function MissileSystem.checkBatteryState(config, systemCtx, isAuto, sideName)
  processFiringUnits(config, systemCtx, isAuto, sideName)
  processResupplyUnits(config, systemCtx, isAuto, sideName)
end

---Handle logic when resupply unit is destroyed
---@param unit CMO__Unit Destroyed unit
---@param systemCtx SBJ__MissileSystemContext Weapon system context
function MissileSystem.handleSupplyAssetDestruction(unit, systemCtx)
  -- Determine unit type by checking if it has a group (type-safe approach)
  -- Ammunition depots are single units (no group), resupply units are groups
  local isAmmunitionDepot = (unit.group == nil)

  if isAmmunitionDepot then
    -- Handle ammunition depot destruction
    local ammoDepotCtx = systemCtx.ammunitions[unit.name]

    if ammoDepotCtx and ammoDepotCtx.wpnCurrent > 0 then
      ammoDepotCtx.wpnCurrent = 0
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
    end
  end
end

---Remove all reference points from a zone
---@param zone CMO__Zone Zone object containing reference points
---@param sideName string Side name for deletion context
---@return boolean # Whether all reference points were successfully removed
local function removeRPs(zone, sideName)
  local rps = GameUtils.convertToRPArray(zone)
  for _, rp in ipairs(rps) do
    local result = GameApi.ScenEdit_DeleteReferencePoint({ side = sideName, name = rp })
    if not result then
      return false
    end
  end
  return true
end

---Remove all zones matching specified position types
---@param positionTypes string[] Array of position type identifiers (e.g., "RL", "HA", "FP")
---@param sideName string Side name for deletion context
local function removeZones(positionTypes, sideName)
  local natureSideName = "Nature"
  local sideObj = GameApi.VP_GetSide({ side = sideName })
  local natureSideObj = GameApi.VP_GetSide({ side = natureSideName })

  for _, z in ipairs(natureSideObj.customenvironmentzones) do
    for _, positionType in ipairs(positionTypes) do
      if string.find(z.description, "^" .. positionType .. "/") then
        local zone = natureSideObj:getcustomenvironmentzone(z.description)

        if zone then
          removeRPs(zone, sideName)
          GameApi.ScenEdit_RemoveZone(natureSideName, constants.ZONE_TYPES.CUSTOM_ENVIRONMENT,
            { description = z.description })
        end
      end
    end

    if string.find(z.description, "^" .. "MASK" .. "/") then
      local zone = natureSideObj:getcustomenvironmentzone(z.description)

      if zone then
        removeRPs(zone, sideName)
        removeRPs(zone, natureSideName)
        GameApi.ScenEdit_RemoveZone(natureSideName, constants.ZONE_TYPES.CUSTOM_ENVIRONMENT,
          { description = z.description })
      end
    end
  end

  for _, z in ipairs(sideObj.standardzones) do
    for _, positionType in ipairs(positionTypes) do
      if string.find(z.description, "^" .. positionType .. "/") then
        local zone = sideObj:getstandardzone(z.description)

        if zone then
          removeRPs(zone, sideName)
          GameApi.ScenEdit_RemoveZone(sideName, constants.ZONE_TYPES.STANDARD, { description = z.description })
        end
      end
    end
  end
end

---Remove event triggers matching specified position types
---@param positionTypes string[] Array of position type identifiers
---@param eventNamePrefix string Event name prefix for matching
---@return boolean # Whether all triggers were successfully removed
local function removeEventTriggers(positionTypes, eventNamePrefix)
  for _, positionType in ipairs(positionTypes) do
    local eventName = eventNamePrefix .. positionType
    local event = GameApi.ScenEdit_GetEvent(eventName)

    if event then
      for _, trigger in ipairs(event.triggers) do
        if trigger["UnitEntersArea"] and string.match(trigger["UnitEntersArea"].Description, "(" .. positionType .. ")") then
          GameApi.ScenEdit_SetEventTrigger(eventName, {
            mode = "remove", description = trigger["UnitEntersArea"].Description, name = eventName
          })
          GameApi.ScenEdit_SetTrigger({ Description = trigger["UnitEntersArea"].Description, Mode = "remove" })
        end
      end
    end
  end

  return true
end

---Get area color code based on position type
---@param positionType string Position type identifier (RL/HA/AHA/MASK/FP)
---@return string # Hexadecimal color code
local function getOperationalAreaColor(positionType)
  local color = "4d8b5cf6"

  if positionType == "RL" then
    color = "4dd9822b"
  end

  if positionType == "HA" then
    color = "4d137cbd"
  end

  if positionType == "AHA" then
    color = "4d0f9960"
  end

  if positionType == "MASK" then
    color = "4dff6b6b"
  end

  return color
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
  local zone = GameApi.ScenEdit_AddZone(
    sideName,
    constants.ZONE_TYPES.STANDARD,
    { area = position.area, description = zoneName }
  )

  if zone then
    local eventName = "(" .. sideName .. ") Arrive in " .. positionType
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

---Add custom environment zone for terrain masking
---@param operationalArea SBJ__OperationalArea Operational area configuration
---@param sideName string Side name for zone ownership
---@return boolean # Whether zone was successfully created
local function addCustomEnvironmentZone(operationalArea, sideName)
  local zone = GameApi.ScenEdit_AddZone(sideName, constants.ZONE_TYPES.CUSTOM_ENVIRONMENT, {
    description = "MASK/" .. operationalArea.name,
    area = operationalArea.uShapeVertices,
    sideName = sideName
  })

  if zone then
    zone.areacolor = getOperationalAreaColor("MASK")
    zone.landcoverheight = 1000
    zone.landcovertype = 254
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
  local eventNamePrefix = "(" .. sideName .. ") Arrive in "
  removeZones(positionTypes, sideName)
  removeEventTriggers(positionTypes, eventNamePrefix)

  for _, operationalArea in ipairs(operationalAreas) do
    for _, positionType in ipairs(positionTypes) do
      for index, position in ipairs(operationalArea[positionType]) do
        ---@cast position SBJ__Position
        addTriggerToEvent(positionType, position, index, operationalArea, sideCfg.enemySide, sideName)
      end
    end

    addCustomEnvironmentZone(operationalArea, sideName)
  end
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
---@return boolean # Whether units were successfully created
local function addFiringUnit(systemCfg, descriptor, sideName)
  local count = systemCfg.resupplyUnits[descriptor.resupplyUnit].unitCount
  local len = #descriptor.operationalArea.HA[1].course
  local type = GameUtils.extractUnitType(descriptor.name)
  local success = false

  for i = 1, count do
    local name = GameUtils.formatOrdinalUnitName(i, type or "", ", " .. descriptor.name)
    local addedUnit = GameApi.ScenEdit_AddUnit({
      side = sideName,
      unitname = name,
      dbid = descriptor.dbid,
      type = "Facility",
      group = descriptor.name,
      latitude = descriptor.operationalArea.HA[1].course[len].latitude,
      longitude = descriptor.operationalArea.HA[1].course[len].longitude
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

      success = true
    end
  end

  return success
end

---Create resupply units according to configuration
---@param descriptor SBJ__ResupplyUnitDescriptor Resupply unit descriptor
---@param sideName string Side name for unit creation
---@return boolean # Whether units were successfully created
local function addResupplyUnit(descriptor, sideName)
  local count = descriptor.unitCount
  local len = #descriptor.operationalArea.RL[1].course
  local type = GameUtils.extractUnitType(descriptor.name)
  local restStr = descriptor.name:match("Ammo Sec(.*)") or (", " .. descriptor.name)
  local success = true

  for i = 1, count do
    local name = GameUtils.formatOrdinalUnitName(i, type or "", restStr)
    local result = GameApi.ScenEdit_AddUnit({
      side = sideName,
      unitname = "Ammo Sec, " .. name,
      dbid = constants.PLATFORMS.AMMO_TRUCK,
      type = "Facility",
      group = descriptor.name,
      latitude = descriptor.operationalArea.RL[1].course[len].latitude,
      longitude = descriptor.operationalArea.RL[1].course[len].longitude
    })

    if not result then
      success = false
    end
  end

  return success
end

---Create ammunition depot unit according to configuration
---@param systemCfg SBJ__MissileSystemConfig Weapon system configuration
---@param descriptor SBJ__AmmunitionUnitDescriptor Ammunition unit descriptor
---@param sideName string Side name for unit creation
---@return boolean # Whether unit was successfully created
local function addAmmunition(systemCfg, descriptor, sideName)
  local restStr = descriptor.name:gsub("^Ammo Revetment, ", "")
  local name = restStr
  local resupplyUnitdescriptor = systemCfg.resupplyUnits[name]

  if not resupplyUnitdescriptor then
    name = "Ammo Sec, " .. name
  end

  resupplyUnitdescriptor = systemCfg.resupplyUnits[name]

  if resupplyUnitdescriptor then
    local len = #resupplyUnitdescriptor.operationalArea.AHA[1].course
    GameApi.ScenEdit_AddUnit({
      side = sideName,
      unitname = descriptor.name,
      dbid = constants.PLATFORMS.AMMO,
      type = "Facility",
      latitude = resupplyUnitdescriptor.operationalArea.AHA[1].course[len].latitude,
      longitude = resupplyUnitdescriptor.operationalArea.AHA[1].course[len].longitude
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
