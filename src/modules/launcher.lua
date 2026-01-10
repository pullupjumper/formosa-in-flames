local Utils = require("src.utils.utils")
local GameApi = require("src.utils.gameApi")
local Logger = require("src.utils.logger")
local constants = require("src.core.constants")
local GameUtils = require("src.utils.gameUtils")

local Launcher = {}


-- Module constants
local BATTERY_CONSTANTS = {
  REPOSITION_SPEED = 30,                -- Speed (km/h) when moving between positions
  MANUAL_RELOAD_DELAY_MULTIPLIER = 100, -- Time multiplier for manual reload mode
}

---Find the area where the unit is located
---@param unit CMO__Unit Unit object
---@param operationalAreas table<string, SBJ__OperationalArea> Position information table
---@return string[]|nil # Area name or nil
local function findUnitArea(unit, operationalAreas)
  for _, operationalArea in pairs(operationalAreas) do
    for _, pos in ipairs(operationalArea.RL) do
      if unit:inArea(pos.area) then
        return pos.area
      end
    end
  end

  return nil
end

---Check if firing unit reload conditions are met
---@param firingUnitCtx SBJ__FiringUnitContext Firing unit context
---@param wsCtx SBJ__WeaponSystemContext Weapon system context
---@param metResult {isMet: boolean} Result of resupply unit meeting check
---@param firingUnit CMO__Unit Firing unit group
---@param weaponDBID number Weapon database ID
---@return boolean # Whether reload conditions are met
local function isReadyToReloadFiringUnit(firingUnitCtx, wsCtx, metResult, firingUnit, weaponDBID)
  if firingUnitCtx.reloadStartTime == nil then
    return false
  end

  local elapsedTime = GameApi.ScenEdit_CurrentTime() - firingUnitCtx.reloadStartTime

  return elapsedTime >= wsCtx.reloadTime and
      metResult.isMet and
      Launcher.isLowAmmo(firingUnit, firingUnitCtx.ammoThreshold, weaponDBID)
end

---Check if resupply unit reload conditions are met
---@param resupplyUnitCtx SBJ__ResupplyUnitContext Resupply unit context
---@param wsCtx SBJ__WeaponSystemContext Weapon system context
---@param metResult {isMet: boolean} Result of ammunition depot meeting check
---@return boolean # Whether reload conditions are met
local function isReadyToReloadResupplyUnit(resupplyUnitCtx, wsCtx, metResult)
  if resupplyUnitCtx.reloadStartTime == nil then
    return false
  end

  local elapsedTime = GameApi.ScenEdit_CurrentTime() - resupplyUnitCtx.reloadStartTime

  return elapsedTime >= wsCtx.reloadTime and
      resupplyUnitCtx.wpnCurrent == 0 and
      metResult.isMet
end

---Set unit movement and weapon control status using table parameters
---@param params SBJ__SetUnitPropertiesParams
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
    Logger.error(string.format("launcher: No %s positions available for %s", positionType, unitName))
    return false
  end

  local posIdx = math.random(posCount)
  local position = positions[posIdx]

  if not position or not position.course then
    Logger.error(string.format("launcher: Invalid %s position data at index %d for %s",
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
    Logger.log("launcher", "launcher: No HA defined for firing unit " .. firingUnitCtx.name .. ", skipping hide movement")
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
---@param wsCtx SBJ__WeaponSystemContext Weapon system context
---@param firingUnitCtx SBJ__FiringUnitContext Firing unit context
---@param firingUnit CMO__Unit Firing unit group
---@param isAuto boolean Whether in automatic mode
---@param sideName string Side name
local function handleAutomaticFiringUnitRepositioning(config, wsCtx, firingUnitCtx, firingUnit, isAuto, sideName)
  if firingUnitCtx.state == config.batteryState.STATIC then
    if Launcher.isLowAmmo(firingUnit, firingUnitCtx.ammoThreshold, firingUnitCtx.weaponDBID) then
      moveToReloadPoint(config, firingUnitCtx, firingUnit)
    end
  end

  if firingUnitCtx.state == config.batteryState.RELOAD then
    if firingUnitCtx.reloadStartTime == nil then
      firingUnitCtx.reloadStartTime = GameApi.ScenEdit_CurrentTime() - wsCtx.reloadTime
    end

    local result = Launcher.isMetWithResupplyUnits(config, wsCtx, firingUnit, isAuto)
    local isReadyToReload = isReadyToReloadFiringUnit(firingUnitCtx, wsCtx, result, firingUnit, firingUnitCtx.weaponDBID)
    local resupplyUnitCtx = wsCtx.resupplyUnits[firingUnitCtx.resupplyUnit]

    if isReadyToReload then
      Launcher.reload(firingUnitCtx, resupplyUnitCtx, firingUnitCtx.weaponDBID, sideName)
      moveToHideArea(config, firingUnitCtx, firingUnit)
    end
  end
end

---Handle manual firing unit reload logic
---@param config SBJ__Config Configuration object
---@param wsCtx SBJ__WeaponSystemContext Weapon system context
---@param firingUnitCtx SBJ__FiringUnitContext Firing unit context
---@param firingUnit CMO__Unit Firing unit group
---@param isAuto boolean Whether in automatic mode
---@param sideName string Side name
local function handleManualFiringUnitReload(config, wsCtx, firingUnitCtx, firingUnit, isAuto, sideName)
  if firingUnitCtx.reloadStartTime == nil then
    -- In manual mode, set a far future time to prevent automatic completion
    firingUnitCtx.reloadStartTime = GameApi.ScenEdit_CurrentTime() +
        wsCtx.reloadTime * BATTERY_CONSTANTS.MANUAL_RELOAD_DELAY_MULTIPLIER
  end

  local result = Launcher.isMetWithResupplyUnits(config, wsCtx, firingUnit, isAuto)
  local isReadyToReload = isReadyToReloadFiringUnit(firingUnitCtx, wsCtx, result, firingUnit, firingUnitCtx.weaponDBID)
  local resupplyUnitCtx = wsCtx.resupplyUnits[firingUnitCtx.resupplyUnit]

  if isReadyToReload then
    Launcher.reload(firingUnitCtx, resupplyUnitCtx, firingUnitCtx.weaponDBID, sideName)

    if config.isDevMode then
      GameApi.ScenEdit_MsgBox("Missile reload is finished/" .. firingUnitCtx.name, 1)
    end
  end
end

---Handle automatic resupply unit repositioning logic
---@param config SBJ__Config Configuration object
---@param wsCtx SBJ__WeaponSystemContext Weapon system context
---@param resupplyUnitCtx SBJ__ResupplyUnitContext Resupply unit context
---@param resupplyUnit CMO__Unit Resupply unit group
---@param isAuto boolean Whether in automatic mode
local function handleAutomaticResupplyUnitRepositioning(config, wsCtx, resupplyUnitCtx, resupplyUnit, isAuto)
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
    local result = Launcher.isMetWithAmmoDepot(config, wsCtx, resupplyUnit, isAuto)
    local isReadyToReload = isReadyToReloadResupplyUnit(resupplyUnitCtx, wsCtx, result)
    local ammoDepotCtx = wsCtx.ammunitions[resupplyUnitCtx.ammunition]

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
---@param wsCtx SBJ__WeaponSystemContext Weapon system context
---@param resupplyUnitCtx SBJ__ResupplyUnitContext Resupply unit context
---@param resupplyUnit CMO__Unit Resupply unit group
---@param isAuto boolean Whether in automatic mode
local function handleManualResupplyUnitReload(config, wsCtx, resupplyUnitCtx, resupplyUnit, isAuto)
  if resupplyUnitCtx.reloadStartTime == nil then
    -- In manual mode, set a far future time to prevent automatic completion
    resupplyUnitCtx.reloadStartTime = GameApi.ScenEdit_CurrentTime() +
        wsCtx.reloadTime * BATTERY_CONSTANTS.MANUAL_RELOAD_DELAY_MULTIPLIER
  end

  local result = Launcher.isMetWithAmmoDepot(config, wsCtx, resupplyUnit, isAuto)
  local isReadyToReload = isReadyToReloadResupplyUnit(resupplyUnitCtx, wsCtx, result)
  local ammoDepotCtx = wsCtx.ammunitions[resupplyUnitCtx.ammunition]

  if isReadyToReload then
    transferAmmunition(resupplyUnitCtx, ammoDepotCtx)

    if config.isDevMode then
      GameApi.ScenEdit_MsgBox("Ammo transload is finished/" .. resupplyUnitCtx.name, 1)
    end
  end
end

---Handle status and actions of all resupply units
---@param config SBJ__Config Configuration object
---@param wsContext SBJ__WeaponSystemContext Weapon system context
---@param isAuto boolean Whether in automatic mode
---@param sideName string Side name
local function processResupplyUnits(config, wsContext, isAuto, sideName)
  for _, resupplyUnitCtx in pairs(wsContext.resupplyUnits) do
    local resupplyUnit = GameApi.ScenEdit_GetUnit(resupplyUnitCtx.name, sideName)

    if resupplyUnit then
      if isAuto then
        handleAutomaticResupplyUnitRepositioning(config, wsContext, resupplyUnitCtx, resupplyUnit, isAuto)
      else
        handleManualResupplyUnitReload(config, wsContext, resupplyUnitCtx, resupplyUnit, isAuto)
      end
    end
  end
end

---Handle status and actions of all firing units
---@param config SBJ__Config Configuration object
---@param wsCtx SBJ__WeaponSystemContext Weapon system context
---@param isAuto boolean Whether in automatic mode
---@param sideName string Side name
local function processFiringUnits(config, wsCtx, isAuto, sideName)
  for _, firingUnitCtx in pairs(wsCtx.firingUnits) do
    local firingUnit = GameApi.ScenEdit_GetUnit(firingUnitCtx.name, sideName)

    if firingUnit then
      if isAuto then
        handleAutomaticFiringUnitRepositioning(config, wsCtx, firingUnitCtx, firingUnit, isAuto, sideName)
      else
        handleManualFiringUnitReload(config, wsCtx, firingUnitCtx, firingUnit, isAuto, sideName)
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
function Launcher.reload(firingUnitCtx, resupplyUnitCtx, weaponDBID, sideName)
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
function Launcher.setReloadStartTime(config, firingUnitCtx, firingUnit, isAuto)
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
function Launcher.setWCSToFree(config, firingUnitCtx, firingUnit)
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
function Launcher.setStateToHIDE(config, firingUnitCtx, firingUnit)
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
function Launcher.isLowAmmo(firingUnit, percentage, weaponDBID)
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
function Launcher.moveToFiringPoint(config, firingUnitCtx, firingUnit)
  firingUnitCtx.state = config.batteryState.REPOSITIONING
  moveUnitToPosition(firingUnitCtx.name, firingUnit, firingUnitCtx.operationalArea.FP, "FP")
end

---Check if two types of units have met in the same area
---@param targetCtx SBJ__FiringUnitContext|SBJ__ResupplyUnitContext Target unit context (firing unit or resupply unit)
---@param targetName string Target unit name to match
---@param counterpartList SBJ__FiringUnitContext[]|SBJ__ResupplyUnitContext[] List of counterpart units to check
---@param unit CMO__Unit Original unit for area checking
---@param operationalAreas table<string, SBJ__OperationalArea> OPAREA configuration
---@param config SBJ__Config Configuration
---@param isAuto boolean Whether in automatic mode
---@return boolean isMet Whether units have met
---@return SBJ__FiringUnitContext|SBJ__ResupplyUnitContext|nil context The matched context if met
local function checkMeetingInArea(targetCtx, targetName, counterpartList, unit, operationalAreas, config, isAuto)
  local isStateValid = true

  if isAuto then
    local repoState = config.batteryState.REPOSITIONING
    local reloadState = config.batteryState.RELOAD
    isStateValid = (targetCtx.state == repoState or targetCtx.state == reloadState)
  end

  if targetCtx.name == targetName and isStateValid then
    local area = findUnitArea(unit, operationalAreas)
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
---@param wsCtx SBJ__WeaponSystemContext Weapon system context
---@param unit CMO__Unit Unit to check
---@param isAuto boolean Whether in automatic mode
---@return {isMet: boolean, firingUnit: SBJ__FiringUnitContext|SBJ__ResupplyUnitContext|nil} # Meeting status with resupply unit context
function Launcher.isMetWithResupplyUnits(config, wsCtx, unit, isAuto)
  if not unit.group then return { isMet = false, firingUnit = nil } end
  local unitGroup = GameApi.ScenEdit_GetUnit(unit.group.guid)
  if not unitGroup then return { isMet = false, firingUnit = nil } end

  -- Determine unit type by checking which collection contains this GUID
  local isResupplyUnit = wsCtx.resupplyUnits[unitGroup.name] ~= nil

  if isResupplyUnit then
    -- Case: Resupply unit looking for firing units
    for _, resupplyUnitCtx in pairs(wsCtx.resupplyUnits) do
      local isMet, ctx = checkMeetingInArea(
        resupplyUnitCtx, unitGroup.name, wsCtx.firingUnits, unit, wsCtx.operationalAreas, config, isAuto
      )
      if isMet then
        return { isMet = true, firingUnit = ctx }
      end
    end
  else
    -- Case: Firing unit looking for resupply units
    for _, firingUnitCtx in pairs(wsCtx.firingUnits) do
      local isMet, ctx = checkMeetingInArea(
        firingUnitCtx, unitGroup.name, wsCtx.resupplyUnits, unit, wsCtx.operationalAreas, config, isAuto
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
---@param wsCtx SBJ__WeaponSystemContext Weapon system context
---@param unit CMO__Unit Unit to check
---@param isAuto boolean Whether in automatic mode
---@return {isMet: boolean, resupplyUnit: SBJ__ResupplyUnitContext|nil} # Meeting status with ammo depot context
function Launcher.isMetWithAmmoDepot(config, wsCtx, unit, isAuto)
  if not unit.group then return { isMet = false, resupplyUnit = nil } end
  local resupplyUnit = GameApi.ScenEdit_GetUnit(unit.group.guid)
  if not resupplyUnit then return { isMet = false, resupplyUnit = nil } end

  for _, resupplyUnitCtx in pairs(wsCtx.resupplyUnits) do
    local isStateValid = true

    if isAuto then
      local repoState = config.batteryState.REPOSITIONING
      local reloadState = config.batteryState.RELOAD
      isStateValid = (resupplyUnitCtx.state == repoState or resupplyUnitCtx.state == reloadState)
    end

    if resupplyUnitCtx.name == resupplyUnit.name and isStateValid then
      local ammoDepot = GameApi.ScenEdit_GetUnit(resupplyUnitCtx.ammunition, unit.side)

      for _, operationalArea in pairs(wsCtx.operationalAreas) do
        -- Check all AHA areas in the array
        for _, pos in ipairs(operationalArea.AHA) do
          local isInSameArea = unit:inArea(pos.area) and (ammoDepot and ammoDepot:inArea(pos.area))

          if isInSameArea then
            return { isMet = true, resupplyUnit = resupplyUnitCtx }
          end
        end
      end
    end
  end

  return { isMet = false, resupplyUnit = nil }
end

---Check status of all firing units and resupply units, and trigger corresponding actions
---@param config SBJ__Config Configuration object
---@param wsCtx SBJ__WeaponSystemContext Weapon system context
---@param isAuto boolean Whether in automatic mode
---@param sideName string Side name
function Launcher.checkBatteryState(config, wsCtx, isAuto, sideName)
  processFiringUnits(config, wsCtx, isAuto, sideName)
  processResupplyUnits(config, wsCtx, isAuto, sideName)
end

---Handle logic when resupply unit is destroyed
---@param unit CMO__Unit Destroyed unit
---@param wsCtx SBJ__WeaponSystemContext Weapon system context
function Launcher.handleSupplyAssetDestruction(unit, wsCtx)
  -- Determine unit type by checking if it has a group (type-safe approach)
  -- Ammunition depots are single units (no group), resupply units are groups
  local isAmmunitionDepot = (unit.group == nil)

  if isAmmunitionDepot then
    -- Handle ammunition depot destruction
    local ammoDepotCtx = wsCtx.ammunitions[unit.name]

    if ammoDepotCtx and ammoDepotCtx.wpnCurrent > 0 then
      ammoDepotCtx.wpnCurrent = 0
    end
  else
    -- Handle resupply unit destruction (part of a group)
    local resupplyUnitCtx = wsCtx.resupplyUnits[unit.group.name]

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

---Add launchers to the game
---@param groundForceCtx SBJ__GroundForceContext Ground force context
---@param wpnSystems string[] Weapon systems
---@param sideName string Side name
function Launcher.addLaunchers(groundForceCtx, wpnSystems, sideName)
  for _, wpnSystem in pairs(wpnSystems) do
    ---@type SBJ__WeaponSystemContext|nil
    local wpnCtx = groundForceCtx[wpnSystem]

    if wpnCtx then
      for _, firingUnitCtx in pairs(wpnCtx.firingUnits) do
        local unit = GameApi.ScenEdit_GetUnit(firingUnitCtx.name, sideName)

        if unit then
          if unit.group and unit.group.unitlist then
            for _, guid in ipairs(unit.group.unitlist) do
              GameApi.ScenEdit_DeleteUnit({ side = sideName, guid = guid })
            end
          end
        end

        local count = wpnCtx.resupplyUnits[firingUnitCtx.resupplyUnit].unitCount
        local len = #firingUnitCtx.operationalArea.HA[1].course
        local type = GameUtils.extractUnitType(firingUnitCtx.name)

        for i = 1, count do
          local name = GameUtils.formatOrdinalUnitName(i, type or "", ", " .. firingUnitCtx.name)
          local addedUnit = GameApi.ScenEdit_AddUnit({
            side = sideName,
            unitname = name,
            dbid = firingUnitCtx.dbid,
            type = "Facility",
            group = firingUnitCtx.name,
            latitude = firingUnitCtx.operationalArea.HA[1].course[len].latitude,
            longitude = firingUnitCtx.operationalArea.HA[1].course[len].longitude
          })

          if addedUnit then
            GameApi.ScenEdit_ClearAllMagazines({ side = sideName, guid = addedUnit.guid })
            local totalRemovedWpnCount = 0
            local removedWpnDBID

            for _, mount in ipairs(addedUnit.mounts) do
              for _, wpn in ipairs(mount.mount_weapons) do
                if wpn.wpn_current > 0 and wpn.wpn_dbid ~= firingUnitCtx.weaponDBID then
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
                wpn_dbid = firingUnitCtx.weaponDBID,
                number = totalRemovedWpnCount,
              })
            end
          end
        end
      end

      for _, resupplyUnitCtx in pairs(wpnCtx.resupplyUnits) do
        local ammoTrucks = GameApi.ScenEdit_GetUnit(resupplyUnitCtx.name, sideName)

        if ammoTrucks then
          if ammoTrucks.group and ammoTrucks.group.unitlist then
            for _, guid in ipairs(ammoTrucks.group.unitlist) do
              GameApi.ScenEdit_DeleteUnit({ side = sideName, guid = guid })
            end
          end
        end

        local count = resupplyUnitCtx.unitCount
        local len = #resupplyUnitCtx.operationalArea.RL[1].course
        local type = GameUtils.extractUnitType(resupplyUnitCtx.name)
        local restStr = resupplyUnitCtx.name:match("Ammo Sec(.*)") or (", " .. resupplyUnitCtx.name)

        for i = 1, count do
          local name = GameUtils.formatOrdinalUnitName(i, type or "", restStr)
          GameApi.ScenEdit_AddUnit({
            side = sideName,
            unitname = "Ammo Sec, " .. name,
            dbid = constants.PLATFORMS.AMMO_TRUCK,
            type = "Facility",
            group = resupplyUnitCtx.name,
            latitude = resupplyUnitCtx.operationalArea.RL[1].course[len].latitude,
            longitude = resupplyUnitCtx.operationalArea.RL[1].course[len].longitude
          })
        end
      end
    end
  end
end

return Launcher
