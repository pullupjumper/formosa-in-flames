local Utils = require("src.utils.utils")
local GameApi = require("src.utils.gameApi")
local Logger = require("src.utils.logger")

local Launcher = {}


---@class SBJ__SetUnitPropertiesParams
---@field unit CMO__Unit Unit object (required)
---@field throttle string? Throttle setting (default: 'Stop')
---@field speed number? Speed (default: 0)
---@field course CMO__TableOfWaypoints? Waypoints (optional)
---@field holdPosition boolean? Whether to hold position (default: true)
---@field wcs number? Weapon control status: 1=Free, 2=Hold (optional)
---@field formation table? Formation settings (optional)

-- Module constants
local CONSTANTS = {
  REPOSITION_SPEED = 30,                -- Speed (km/h) when moving between positions
  MANUAL_RELOAD_DELAY_MULTIPLIER = 100, -- Time multiplier for manual reload mode
  -- Weapon Control Status
  WCS = {
    FREE = 1, -- Free fire
    HOLD = 2, -- Hold fire
  }
}

-- Private functions

---Find the area where the unit is located
---@param unit CMO__Unit Unit object
---@param OPAREAs table<string, SBJ__OPAREA> Position information table
---@return string[]|nil Area name or nil
local function findUnitArea(unit, OPAREAs)
  for _, OPAREA in pairs(OPAREAs) do
    for _, pos in ipairs(OPAREA.RL) do
      if unit:inArea(pos.area) then
        return pos.area
      end
    end
  end

  return nil
end


---Check if battery reload conditions are met
---@param batteryCtx SBJ__BatteryContext Artillery battery object
---@param wsContext SBJ__WeaponSystemContext Weapon system context
---@param metResult {isMet: boolean} Result of ammo truck meeting check
---@param battery CMO__Unit Unit group
---@param weaponDBID number Weapon database ID
---@return boolean Whether reload conditions are met
local function isReadyToReloadBattery(batteryCtx, wsContext, metResult, battery, weaponDBID)
  if batteryCtx.reloadStartTime == nil then
    return false
  end

  local elapsedTime = GameApi.ScenEdit_CurrentTime() - batteryCtx.reloadStartTime

  return elapsedTime >= wsContext.reloadTime and
      metResult.isMet and
      Launcher.isLowAmmo(battery, batteryCtx.ammoThreshold, weaponDBID)
end


---Check if ammunition section reload conditions are met
---@param sectionCtx SBJ__AmmunitionSectionContext Ammunition section object
---@param wsContext SBJ__WeaponSystemContext Weapon system context
---@param metResult {isMet: boolean} Result of ammo depot meeting check
---@return boolean Whether reload conditions are met
local function isReadyToReloadSection(sectionCtx, wsContext, metResult)
  if sectionCtx.reloadStartTime == nil then
    return false
  end

  local elapsedTime = GameApi.ScenEdit_CurrentTime() - sectionCtx.reloadStartTime

  return elapsedTime >= wsContext.reloadTime and
      sectionCtx.wpnCurrent == 0 and
      metResult.isMet
end


-- Private helper functions

---Set unit movement and weapon control status using table parameters
---@param params SBJ__SetUnitPropertiesParams
local function setUnitProperties(params)
  local unit = params.unit
  if not unit then return end

  local unitSetParams = {
    guid = unit.guid,
    manualthrottle = params.throttle or 'Stop',
    manualSpeed = params.speed or 0,
    holdposition = params.holdPosition ~= nil and params.holdPosition or true
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
---@param positions table Position array
---@param positionType string Position type ('RL'/'HA'/'AHA'/'FP', for error messages)
---@param wcs number? Weapon control status (optional)
---@param useLastCourse boolean? Whether to use the last waypoint in course (default: false)
---@return boolean Success status
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
  if useLastCourse and type(course) == 'table' and #course > 0 then
    course = course[#course]
  end

  for _, guid in ipairs(battery.group.unitlist) do
    local unit = GameApi.ScenEdit_GetUnit(guid)
    setUnitProperties({
      unit = unit,
      throttle = 'Flank',
      speed = CONSTANTS.REPOSITION_SPEED,
      course = course,
      holdPosition = false,
      wcs = wcs
    })
  end

  return true
end


---Command artillery battery to move to reload point (RL)
---@param config SBJ__CONFIG
---@param batteryCtx SBJ__BatteryContext Artillery battery object
---@param battery CMO__Unit Unit group
local function moveToReloadPoint(config, batteryCtx, battery)
  batteryCtx.state = config.batteryState.REPOSITIONING
  moveUnitToPosition(batteryCtx.name, battery, batteryCtx.OPAREA.RL, 'RL', CONSTANTS.WCS.HOLD)
end

---Command artillery battery to move to hide area (HA)
---@param config SBJ__CONFIG
---@param batteryCtx SBJ__BatteryContext Artillery battery object
---@param battery CMO__Unit Unit group
local function moveToHideArea(config, batteryCtx, battery)
  -- Check if HA exists (some OPAREAs may not have HA)
  if not batteryCtx.OPAREA.HA then
    Logger.log("launcher: No HA defined for battery " .. batteryCtx.name .. ", skipping hide movement")
    return
  end

  batteryCtx.state = config.batteryState.REPOSITIONING
  moveUnitToPosition(batteryCtx.name, battery, batteryCtx.OPAREA.HA, 'HA', CONSTANTS.WCS.HOLD)
end

---Command ammunition section to move to ammunition storage area (AHA)
---@param config SBJ__CONFIG
---@param sectionCtx SBJ__AmmunitionSectionContext Ammunition section object
---@param section CMO__Unit Unit group
local function moveToAmmoHoldingArea(config, sectionCtx, section)
  sectionCtx.state = config.batteryState.REPOSITIONING
  moveUnitToPosition(sectionCtx.name, section, sectionCtx.OPAREA.AHA, 'AHA')
end

---Transfer ammunition from ammunition depot to ammunition section
---@param sectionCtx SBJ__AmmunitionSectionContext Ammunition section object
---@param ammunitionCtx SBJ__AmmunitionContext Ammunition depot object
local function transferAmmunition(sectionCtx, ammunitionCtx)
  if ammunitionCtx.wpnCurrent > 0 and sectionCtx.wpnCurrent < sectionCtx.wpnDefault then
    if ammunitionCtx.wpnCurrent >= sectionCtx.wpnDefault then
      sectionCtx.wpnCurrent = sectionCtx.wpnCurrent + sectionCtx.wpnDefault
      ammunitionCtx.wpnCurrent = ammunitionCtx.wpnCurrent - sectionCtx.wpnDefault
    else
      sectionCtx.wpnCurrent = sectionCtx.wpnCurrent + ammunitionCtx.wpnCurrent
      ammunitionCtx.wpnCurrent = 0
    end
  end

  sectionCtx.reloadStartTime = nil
end

---Command ammunition section to move to reload point (RL)
---@param config SBJ__CONFIG
---@param sectionCtx SBJ__AmmunitionSectionContext Ammunition section object
---@param section CMO__Unit Unit group
local function moveAmmoSectionToReloadPoint(config, sectionCtx, section)
  sectionCtx.state = config.batteryState.REPOSITIONING
  moveUnitToPosition(sectionCtx.name, section, sectionCtx.OPAREA.RL, 'RL', nil, true)
end

---Handle automatic artillery battery repositioning logic
---@param config SBJ__CONFIG
---@param wsContext SBJ__WeaponSystemContext
---@param batteryCtx SBJ__BatteryContext
---@param battery CMO__Unit
---@param isAuto boolean
local function handleAutomaticBatteryRepositioning(config, wsContext, batteryCtx, battery, isAuto)
  if batteryCtx.state == config.batteryState.STATIC then
    if Launcher.isLowAmmo(battery, batteryCtx.ammoThreshold, batteryCtx.weaponDBID) then
      moveToReloadPoint(config, batteryCtx, battery)
    end
  end

  if batteryCtx.state == config.batteryState.RELOAD then
    if batteryCtx.reloadStartTime == nil then
      batteryCtx.reloadStartTime = GameApi.ScenEdit_CurrentTime() - wsContext.reloadTime
    end

    local result = Launcher.isMetWithAmmoTrucks(config, wsContext, battery, isAuto)
    local isReadyToReload = isReadyToReloadBattery(batteryCtx, wsContext, result, battery, batteryCtx.weaponDBID)

    if isReadyToReload then
      Launcher.reload(batteryCtx, wsContext.ammunitionSections[batteryCtx.ammunitionSection], batteryCtx.weaponDBID)
      moveToHideArea(config, batteryCtx, battery)
    end
  end
end

---Handle manual artillery battery reload logic
---@param config SBJ__CONFIG
---@param wsContext SBJ__WeaponSystemContext
---@param batteryCtx SBJ__BatteryContext
---@param battery CMO__Unit
---@param isAuto boolean
local function handleManualBatteryReload(config, wsContext, batteryCtx, battery, isAuto)
  if batteryCtx.reloadStartTime == nil then
    -- In manual mode, set a far future time to prevent automatic completion
    batteryCtx.reloadStartTime = GameApi.ScenEdit_CurrentTime() +
        wsContext.reloadTime * CONSTANTS.MANUAL_RELOAD_DELAY_MULTIPLIER
  end

  local result = Launcher.isMetWithAmmoTrucks(config, wsContext, battery, isAuto)
  local isReadyToReload = isReadyToReloadBattery(batteryCtx, wsContext, result, battery, batteryCtx.weaponDBID)

  if isReadyToReload then
    Launcher.reload(batteryCtx, wsContext.ammunitionSections[batteryCtx.ammunitionSection], batteryCtx.weaponDBID)

    if config.isDevMode then
      GameApi.ScenEdit_MsgBox('Missile reload is finished/' .. batteryCtx.name, 1)
    end
  end
end

---Handle automatic ammunition section repositioning logic
---@param config SBJ__CONFIG
---@param wsContext SBJ__WeaponSystemContext
---@param sectionCtx SBJ__AmmunitionSectionContext
---@param section CMO__Unit
---@param isAuto boolean
local function handleAutomaticSectionRepositioning(config, wsContext, sectionCtx, section, isAuto)
  if sectionCtx.state == config.batteryState.STATIC then
    -- Check if unit is in any RL area
    local isInRLArea = false
    for _, pos in ipairs(sectionCtx.OPAREA.RL) do
      if section:inArea(pos.area) then
        isInRLArea = true
        break
      end
    end

    if sectionCtx.wpnCurrent == 0 and isInRLArea then
      moveToAmmoHoldingArea(config, sectionCtx, section)
    end
  end

  if sectionCtx.state == config.batteryState.RELOAD then
    local result = Launcher.isMetWithAmmo(config, wsContext, section, isAuto)
    local isReadyToReload = isReadyToReloadSection(sectionCtx, wsContext, result)

    if isReadyToReload then
      transferAmmunition(sectionCtx, wsContext.ammunitions[sectionCtx.ammunition])
      moveAmmoSectionToReloadPoint(config, sectionCtx, section)

      if config.isDevMode then
        GameApi.ScenEdit_MsgBox('Ammo transload is finished/' .. sectionCtx.name, 1)
      end
    end
  end
end

---Handle manual ammunition section reload logic
---@param config SBJ__CONFIG
---@param wsContext SBJ__WeaponSystemContext
---@param sectionCtx SBJ__AmmunitionSectionContext
---@param section CMO__Unit
---@param isAuto boolean
local function handleManualSectionReload(config, wsContext, sectionCtx, section, isAuto)
  if sectionCtx.reloadStartTime == nil then
    -- In manual mode, set a far future time to prevent automatic completion
    sectionCtx.reloadStartTime = GameApi.ScenEdit_CurrentTime() +
        wsContext.reloadTime * CONSTANTS.MANUAL_RELOAD_DELAY_MULTIPLIER
  end

  local result = Launcher.isMetWithAmmo(config, wsContext, section, isAuto)
  local isReadyToReload = isReadyToReloadSection(sectionCtx, wsContext, result)

  if isReadyToReload then
    transferAmmunition(sectionCtx, wsContext.ammunitions[sectionCtx.ammunition])

    if config.isDevMode then
      GameApi.ScenEdit_MsgBox('Ammo transload is finished/' .. sectionCtx.name, 1)
    end
  end
end

---Handle status and actions of all ammunition sections
---@param config SBJ__CONFIG
---@param wsContext SBJ__WeaponSystemContext
---@param isAuto boolean
local function processAmmunitionSections(config, wsContext, isAuto)
  for _, sectionCtx in pairs(wsContext.ammunitionSections) do
    local section = GameApi.ScenEdit_GetUnit(sectionCtx.guid)

    if section then
      if isAuto then
        handleAutomaticSectionRepositioning(config, wsContext, sectionCtx, section, isAuto)
      else
        handleManualSectionReload(config, wsContext, sectionCtx, section, isAuto)
      end
    end
  end
end

---Handle status and actions of all artillery batteries
---@param config SBJ__CONFIG
---@param wsContext SBJ__WeaponSystemContext
---@param isAuto boolean
local function processBatteries(config, wsContext, isAuto)
  for _, batteryCtx in pairs(wsContext.batteries) do
    local battery = GameApi.ScenEdit_GetUnit(batteryCtx.guid)

    if battery then
      if isAuto then
        handleAutomaticBatteryRepositioning(config, wsContext, batteryCtx, battery, isAuto)
      else
        handleManualBatteryReload(config, wsContext, batteryCtx, battery, isAuto)
      end
    end
  end
end

-- Public functions

---Calculate ammunition statistics for a unit
---@param unit CMO__Unit|nil Unit object
---@param weaponDBID number Weapon database ID
---@return number currentAmmo Current ammunition count
---@return number maxAmmo Maximum ammunition capacity
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
---@param sectionCtx SBJ__AmmunitionSectionContext Ammunition section context
---@return number Total ammunition consumed
local function reloadUnit(unit, weaponDBID, sectionCtx)
  if not unit then
    return 0
  end

  local currentAmmo, maxAmmo = calculateAmmoStats(unit, weaponDBID)
  local required = maxAmmo - currentAmmo

  if required > 0 and sectionCtx.wpnCurrent > 0 then
    local ammoToLoad = math.min(required, sectionCtx.wpnCurrent)

    GameApi.ScenEdit_AddReloadsToUnit({
      guid = unit.guid,
      wpn_dbid = weaponDBID,
      number = ammoToLoad
    })

    sectionCtx.wpnCurrent = sectionCtx.wpnCurrent - ammoToLoad
    return ammoToLoad
  end

  return 0
end


---Execute reload for artillery battery
---@param batteryCtx SBJ__BatteryContext Artillery battery object
---@param ammunitionSectionCtx SBJ__AmmunitionSectionContext Ammunition section object
---@param weaponDBID number Weapon database ID
function Launcher.reload(batteryCtx, ammunitionSectionCtx, weaponDBID)
  local battery = GameApi.ScenEdit_GetUnit(batteryCtx.guid)
  if not battery then return end

  for _, guid in ipairs(battery.group.unitlist) do
    local unit = GameApi.ScenEdit_GetUnit(guid)
    reloadUnit(unit, weaponDBID, ammunitionSectionCtx)
  end

  batteryCtx.reloadStartTime = nil
end

---Set artillery battery reload start time
---@param config SBJ__CONFIG
---@param batteryCtx SBJ__BatteryContext Artillery battery object
---@param battery CMO__Unit Unit group
---@param isAuto boolean Whether in automatic mode
function Launcher.setReloadStartTime(config, batteryCtx, battery, isAuto)
  batteryCtx.state = config.batteryState.RELOAD
  batteryCtx.reloadStartTime = GameApi.ScenEdit_CurrentTime()

  for _, guid in ipairs(battery.group.unitlist) do
    local u = GameApi.ScenEdit_GetUnit(guid)

    if u and isAuto then
      setUnitProperties({
        unit = u,
        holdPosition = true,
        formation = { spacing = 0, transpose = true }
      })
    end
  end
end

---Set artillery battery weapon control status to free fire
---@param config SBJ__CONFIG
---@param batteryCtx SBJ__BatteryContext Artillery battery object
---@param battery CMO__Unit Unit group
function Launcher.setWCSToFree(config, batteryCtx, battery)
  batteryCtx.state = config.batteryState.STATIC

  for _, guid in ipairs(battery.group.unitlist) do
    local u = GameApi.ScenEdit_GetUnit(guid)

    if u then
      setUnitProperties({
        unit = u,
        holdPosition = true,
        wcs = CONSTANTS.WCS.FREE, -- Free fire
        formation = { spacing = 0, transpose = true }
      })
    end
  end
end

---Set artillery battery status to hide
---@param config SBJ__CONFIG
---@param batteryCtx SBJ__BatteryContext Artillery battery object
---@param battery CMO__Unit Unit group
function Launcher.setStateToHIDE(config, batteryCtx, battery)
  batteryCtx.state = config.batteryState.HIDE

  for _, guid in ipairs(battery.group.unitlist) do
    local u = GameApi.ScenEdit_GetUnit(guid)

    if u then
      setUnitProperties({
        unit = u,
        holdPosition = true,
        wcs = CONSTANTS.WCS.HOLD, -- Hold fire while hiding
        formation = { spacing = 0, transpose = true }
      })
    end
  end
end

---Check if unit/group ammunition is below specified percentage
---@param battery CMO__Unit Unit or group object
---@param percentage number Percentage threshold
---@param weaponDBID number Weapon database ID
---@return boolean Whether it is low ammunition
function Launcher.isLowAmmo(battery, percentage, weaponDBID)
  local totalCurrent = 0
  local totalMax = 0

  -- Process single unit or all units in group
  local units = battery.group and battery.group.unitlist or { battery.guid }
  for _, guid in ipairs(units) do
    local unit = GameApi.ScenEdit_GetUnit(guid)
    local currentAmmo, maxAmmo = calculateAmmoStats(unit, weaponDBID)
    totalCurrent = totalCurrent + currentAmmo
    totalMax = totalMax + maxAmmo
  end

  if totalMax == 0 then return false end
  return (totalCurrent / totalMax * 100) <= percentage
end

---Command artillery battery to move to firing point (FP)
---@param config SBJ__CONFIG
---@param batteryCtx SBJ__BatteryContext Artillery battery object
---@param battery CMO__Unit Unit group
function Launcher.moveToFiringPoint(config, batteryCtx, battery)
  batteryCtx.state = config.batteryState.REPOSITIONING
  moveUnitToPosition(batteryCtx.name, battery, batteryCtx.OPAREA.FP, 'FP')
end

---Check if two types of units have met in the same area
---@param targetCtx SBJ__BatteryContext|SBJ__AmmunitionSectionContext Target unit context (battery or section)
---@param targetGuid string Target unit GUID to match
---@param counterpartList SBJ__BatteryContext[]|SBJ__AmmunitionSectionContext[] List of counterpart units to check
---@param unit CMO__Unit Original unit for area checking
---@param OPAREAs table<string, SBJ__OPAREA> OPAREA configuration
---@param config SBJ__CONFIG Configuration
---@param isAuto boolean Whether in automatic mode
---@return boolean isMet Whether units have met
---@return table|nil context The matched context if met
local function checkMeetingInArea(targetCtx, targetGuid, counterpartList, unit, OPAREAs, config, isAuto)
  local isStateValid = true

  if isAuto then
    local repoState = config.batteryState.REPOSITIONING
    local reloadState = config.batteryState.RELOAD
    isStateValid = (targetCtx.state == repoState or targetCtx.state == reloadState)
  end

  if targetCtx.guid == targetGuid and isStateValid then
    local area = findUnitArea(unit, OPAREAs)
    if not area then return false, nil end

    for _, counterpartCtx in pairs(counterpartList) do
      local counterpart = GameApi.ScenEdit_GetUnit(counterpartCtx.guid)
      if counterpart and counterpart:inArea(area) then
        return true, targetCtx
      end
    end
  end

  return false, nil
end


---Check if artillery battery has met with ammunition trucks
---@param config SBJ__CONFIG
---@param wsContext SBJ__WeaponSystemContext
---@param unit CMO__Unit
---@param isAuto boolean
---@return {isMet: boolean, battery: SBJ__BatteryContext|nil}
function Launcher.isMetWithAmmoTrucks(config, wsContext, unit, isAuto)
  if not unit.group then return { isMet = false, battery = nil } end
  local battery = GameApi.ScenEdit_GetUnit(unit.group.guid)
  if not battery then return { isMet = false, battery = nil } end

  -- Determine unit type by checking which collection contains this GUID
  local isAmmunitionSection = wsContext.ammunitionSections[battery.guid] ~= nil

  if isAmmunitionSection then
    -- Case: Ammunition section looking for batteries
    for _, sectionCtx in pairs(wsContext.ammunitionSections) do
      local isMet, ctx = checkMeetingInArea(
        sectionCtx, battery.guid, wsContext.batteries, unit, wsContext.OPAREAs, config, isAuto
      )
      if isMet then
        return { isMet = true, battery = ctx }
      end
    end
  else
    -- Case: Battery looking for ammunition sections
    for _, batteryCtx in pairs(wsContext.batteries) do
      local isMet, ctx = checkMeetingInArea(
        batteryCtx, battery.guid, wsContext.ammunitionSections, unit, wsContext.OPAREAs, config, isAuto
      )
      if isMet then
        return { isMet = true, battery = ctx }
      end
    end
  end

  return { isMet = false, battery = nil }
end

---Check if ammunition section has met with ammunition depot
---@param config SBJ__CONFIG
---@param wsContext SBJ__WeaponSystemContext
---@param unit CMO__Unit
---@param isAuto boolean
---@return {isMet: boolean, battery: SBJ__AmmunitionSectionContext|nil}
function Launcher.isMetWithAmmo(config, wsContext, unit, isAuto)
  if not unit.group then return { isMet = false, battery = nil } end
  local section = GameApi.ScenEdit_GetUnit(unit.group.guid)
  if not section then return { isMet = false, battery = nil } end

  for _, sectionCtx in pairs(wsContext.ammunitionSections) do
    local isStateValid = true

    if isAuto then
      local repoState = config.batteryState.REPOSITIONING
      local reloadState = config.batteryState.RELOAD
      isStateValid = (sectionCtx.state == repoState or sectionCtx.state == reloadState)
    end

    if sectionCtx.guid == section.guid and isStateValid then
      local ammo = GameApi.ScenEdit_GetUnit(sectionCtx.ammunition)

      for _, OPAREA in pairs(wsContext.OPAREAs) do
        -- Check all AHA areas in the array
        for _, pos in ipairs(OPAREA.AHA) do
          local isInSameArea = unit:inArea(pos.area) and (ammo and ammo:inArea(pos.area))

          if isInSameArea then
            return { isMet = true, battery = sectionCtx }
          end
        end
      end
    end
  end

  return { isMet = false, battery = nil }
end

---Check status of all artillery batteries and ammunition sections, and trigger corresponding actions
---@param config SBJ__CONFIG
---@param wsContext SBJ__WeaponSystemContext
---@param isAuto boolean
function Launcher.checkBatteryState(config, wsContext, isAuto)
  processBatteries(config, wsContext, isAuto)
  processAmmunitionSections(config, wsContext, isAuto)
end

---Handle logic when ammunition section unit is destroyed
---@param unit CMO__Unit Destroyed unit
---@param wsContext SBJ__WeaponSystemContext
function Launcher.destroyAmmoSecHandler(unit, wsContext)
  -- Determine unit type by checking if it has a group (type-safe approach)
  -- Ammunition depots are single units (no group), ammunition sections are groups
  local isAmmunitionDepot = (unit.group == nil)

  if isAmmunitionDepot then
    -- Handle ammunition depot destruction
    local ammoCtx = wsContext.ammunitions[unit.guid]

    if ammoCtx and ammoCtx.wpnCurrent > 0 then
      ammoCtx.wpnCurrent = 0
    end
  else
    -- Handle ammunition section unit destruction (part of a group)
    local ammoSecCtx = wsContext.ammunitionSections[unit.group.guid]

    if ammoSecCtx and ammoSecCtx.wpnCurrent > 0 then
      -- Reduce ammunition proportionally when one unit in the section is destroyed
      local ammoPerUnit = ammoSecCtx.wpnDefault / ammoSecCtx.unitCount

      if (ammoSecCtx.wpnCurrent - ammoPerUnit) < 0 then
        ammoSecCtx.wpnCurrent = 0
      else
        ammoSecCtx.wpnCurrent = ammoSecCtx.wpnCurrent - ammoPerUnit
      end
    end
  end
end

return Launcher
