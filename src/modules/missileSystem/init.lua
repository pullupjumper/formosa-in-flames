local Logger = require("src.utils.logger")
local LogFormat = require("src.utils.logFormat")
local constants = require("src.core.constants")
local GameApi = require("src.utils.gameApi")
local Ammo = require("src.modules.missileSystem.ammo")
local Meeting = require("src.modules.missileSystem.meeting")
local Movement = require("src.modules.missileSystem.movement")
local Concealment = require("src.modules.missileSystem.concealment")
local Cycle = require("src.modules.missileSystem.cycle")
local Triggers = require("src.modules.missileSystem.triggers")
local Deployment = require("src.modules.missileSystem.deployment")
local Context = require("src.modules.missileSystem.context")

local MissileSystem = {}

---Format free-text detail for log output
---@param value any Value to format
---@return string # Quoted detail field
local function detailField(value)
  return string.format("detail=%q", LogFormat.readable(value))
end

---Format reload cycle result fields for log output
---@param result SBJ__ReloadCycleResult Result from cycle processing
---@param system string Missile system name
---@return string # Key=value log message
local function formatCycleResult(result, system)
  local message = string.format(
    "system=%s unit=%q action=%s",
    LogFormat.value(system),
    LogFormat.readable(result.unitName),
    LogFormat.token(result.action)
  )

  if result.reason then
    message = message .. " reason=" .. LogFormat.token(result.reason)
  end

  if result.detail then
    message = message .. " " .. result.detail
  end

  return message
end

---Format supply asset destruction result for log output
---@param result SBJ__SupplyAssetDestructionResult Destruction result
---@return string # Key=value log message
local function formatSupplyAssetDestructionResult(result)
  return string.format(
    "action=supply_asset_destroyed role=%s unit=%q context=%q ammoBefore=%d ammoAfter=%d delta=%d",
    LogFormat.value(result.role),
    LogFormat.readable(result.unitName),
    LogFormat.readable(result.contextName),
    result.ammoBefore,
    result.ammoAfter,
    result.delta
  )
end

---Build a structured UnitEntersArea functional result
---@param tag string Result tag
---@param system string Missile system name
---@param unitName string Unit name
---@param positionType string Position type token
---@param action string Functional action
---@param reason? string Reason for non-OK outcomes
---@param detail? string Additional key=value detail fields
---@return SBJ__PositionEventResult # Structured result
local function buildPositionEventResult(tag, system, unitName, positionType, action, reason, detail)
  return {
    tag = tag,
    system = system,
    unitName = unitName,
    positionType = positionType,
    action = action,
    reason = reason,
    detail = detail
  }
end

---Append one position-event result when present
---@param results SBJ__PositionEventResult[] Result list
---@param result SBJ__PositionEventResult|nil Result to append
local function appendPositionEventResult(results, result)
  if result then
    table.insert(results, result)
  end
end

---Format position-event result fields for log output
---@param result SBJ__PositionEventResult Result from UnitEntersArea processing
---@return string # Key=value log message
local function formatPositionEventResult(result)
  local message = string.format(
    "system=%s unit=%q position=%s action=%s",
    LogFormat.value(result.system),
    LogFormat.readable(result.unitName),
    LogFormat.value(result.positionType),
    LogFormat.value(result.action)
  )

  if result.reason then
    message = message .. " reason=" .. LogFormat.token(result.reason)
  end

  if result.detail then
    message = message .. " " .. result.detail
  end

  return message
end

---Extract position type token from UnitEntersArea trigger description
---@param event CMO__Event|nil Scenario event object
---@return string|nil # Position type token (FP/AHA/HA/RL)
local function extractPositionType(event)
  if not event or not event.triggers then
    return nil
  end

  for _, trigger in ipairs(event.triggers) do
    local entersArea = trigger["UnitEntersArea"]
    if entersArea and entersArea.Description then
      local positionType = string.match(entersArea.Description, "Arrive in (FP) ") or
          string.match(entersArea.Description, "Arrive in (AHA) ") or
          string.match(entersArea.Description, "Arrive in (HA) ") or
          string.match(entersArea.Description, "Arrive in (RL) ")
      if positionType then
        return positionType
      end
    end
  end

  return nil
end

---Drop contact entries that point to the incoming unit
---@param unit CMO__Unit Unit entering area
---@param contacts CMO__Contact[]|nil Contacts list from ScenEdit_GetContacts
local function dropUnitContact(unit, contacts)
  if not contacts then
    return
  end

  for _, contact in ipairs(contacts) do
    if unit.guid == contact.actualunitid then
      contact:DropContact()
    end
  end
end

---Command firing unit to move to firing point (FP)
---@param firingUnitCtx SBJ__FiringUnitContext Firing unit context
---@param firingUnit CMO__Unit Firing unit group
---@return boolean success Whether the move was successful
function MissileSystem.moveToFiringPoint(firingUnitCtx, firingUnit)
  local success, errorMsg = Movement.moveToFiringPoint(firingUnitCtx, firingUnit)
  if not success and errorMsg then
    Logger.error(LogFormat.event("module", constants.TAGS.MISSILE_SYSTEM, "FAIL", string.format(
      "action=move_to_firing_point unit=%q reason=movement_failed detail=%q",
      LogFormat.readable(firingUnitCtx and firingUnitCtx.name or firingUnit and firingUnit.name),
      LogFormat.readable(errorMsg)
    )))
  end
  return success
end

---Unload firing unit group from hide area buildings
---@param unitCtx SBJ__FiringUnitContext|SBJ__ResupplyUnitContext Unit context with operational area
---@param unit CMO__Unit Firing unit to unload
---@return boolean success Whether unload was performed
---@return string? errorMsg Error message if failed
function MissileSystem.moveFromHideArea(unitCtx, unit)
  return Concealment.moveFromHideArea(unitCtx, unit)
end

---Check if unit/group ammunition is below specified percentage
---@param firingUnit CMO__Unit Unit or group object
---@param percentage number|nil Percentage threshold
---@param weaponDBID number|number[]|nil Weapon database ID(s)
---@return boolean # Whether it is low ammunition
function MissileSystem.isLowAmmo(firingUnit, percentage, weaponDBID)
  return Ammo.isLowAmmo(firingUnit, percentage, weaponDBID)
end

---Calculate ammunition inventory across firing/resupply/ammo for a missile system
---@param systemCtx SBJ__MissileSystemContext Missile system runtime context
---@param sideName string Side name used to resolve firing units in game state
---@return SBJ__AmmoInventoryReport # Inventory report with subtotals and percentages
function MissileSystem.getAmmoInventory(systemCtx, sideName)
  return Ammo.getInventory(systemCtx, sideName)
end

---Check status of all missile systems and trigger corresponding actions
---@param groundCtx SBJ__GroundForceContext Ground force contexts keyed by missile system type
---@param isAuto boolean Whether in automatic mode
---@param sideName string Side name
function MissileSystem.checkMissileSystemState(groundCtx, isAuto, sideName)
  local allResults = {}
  local hasFailure = false

  for _, missileSystem in pairs(constants.MISSILE_SYSTEM_TYPES) do
    local systemCtx = groundCtx[missileSystem]
    if systemCtx and systemCtx.enabled then
      local systemResults = Cycle.process(systemCtx, isAuto, sideName)
      for _, result in ipairs(systemResults) do
        table.insert(allResults, {
          system = missileSystem,
          tag = result.tag,
          action = result.action,
          unitName = result.unitName,
          reason = result.reason,
          detail = result.detail
        })
        if result.tag == "FAIL" or result.tag == "ERROR" then
          hasFailure = true
        end
      end
    end
  end

  if #allResults > 0 then
    local lines = {}
    for _, r in ipairs(allResults) do
      table.insert(lines, LogFormat.entry(r.tag, formatCycleResult(r, r.system)))
    end
    local summary = LogFormat.summary(
      "side",
      sideName,
      string.format("Reload cycle mode=%s", isAuto and "auto" or "manual"),
      lines
    )

    if hasFailure then
      Logger.error(summary)
    else
      Logger.log(constants.TAGS.MISSILE_SYSTEM, summary)
    end
  end
end

---Handle logic when resupply unit is destroyed
---@param unit CMO__Unit Destroyed unit
---@param systemCtx SBJ__MissileSystemContext Weapon system context
---@return boolean success Whether unit was found and processed
---@return SBJ__SupplyAssetDestructionResult|nil result Structured result when ammo was adjusted
function MissileSystem.handleSupplyAssetDestruction(unit, systemCtx)
  local success, result = Context.handleSupplyAssetDestruction(unit, systemCtx)

  if success and result then
    Logger.log(constants.TAGS.MISSILE_SYSTEM, LogFormat.event(
      "system",
      result.system,
      result.tag,
      formatSupplyAssetDestructionResult(result)
    ))
  end

  return success, result
end

---Initialize event triggers and zones for missile system operational areas
---@param operationalAreas SBJ__OperationalArea[] Array of operational area configurations
---@param operationalAreasToRemove SBJ__OperationalArea[] Array of operational areas to remove triggers for
---@param positionTypes string[] Position type identifiers (RL/HA/AHA/FP)
---@param sideName string Side name for zone/trigger ownership
function MissileSystem.initEventTriggers(operationalAreas, operationalAreasToRemove, positionTypes, sideName)
  Triggers.initEventTriggers(operationalAreas, operationalAreasToRemove, positionTypes, sideName)
end

---Add missile system units to the game
---@param groundForceCfg SBJ__GroundForceConfig Ground force context
---@param sideName string Side name
function MissileSystem.addMissileSystems(groundForceCfg, sideName)
  Deployment.addMissileSystems(groundForceCfg, sideName)
end

---Initialize missile system runtime contexts from configuration
---@param groundForceCfg SBJ__GroundForceConfig Ground force configuration
---@param groundForceCtx SBJ__GroundForceContext Ground force runtime context
function MissileSystem.initMissileSystemContexts(groundForceCfg, groundForceCtx)
  Context.initMissileSystemContexts(groundForceCfg, groundForceCtx)
end

---Normalize behavior options with default values
---@param behavior SBJ__MoveToPositionBehavior|nil Optional behavior configuration
---@param unitSide string Unit side name used as default lookup side
---@return SBJ__MoveToPositionBehavior # Resolved behavior object
local function resolveBehavior(behavior, unitSide)
  if behavior then
    return behavior
  end

  return {
    hideOnEnterHA = false,
    hideResupplyOnRLNoMeeting = false,
    firingUnitLookupSide = unitSide
  }
end

---Iterate through enabled missile systems only
---@param groundCtx table<string, SBJ__MissileSystemContext> Missile system contexts keyed by system type
---@param callback fun(systemCtx: SBJ__MissileSystemContext, systemName: string) Callback invoked for each enabled system context
local function forEachEnabledSystem(groundCtx, callback)
  for _, missileSystem in pairs(constants.MISSILE_SYSTEM_TYPES) do
    local systemCtx = groundCtx[missileSystem]
    if systemCtx and systemCtx.enabled then
      callback(systemCtx, missileSystem)
    end
  end
end

---Handle entering firing point logic for a single missile system context
---@param systemName string Missile system name
---@param systemCtx SBJ__MissileSystemContext Missile system context
---@param unit CMO__Unit Triggered unit
---@param isAuto boolean Whether the action is in automatic mode
---@return SBJ__PositionEventResult|nil result Functional result when state changed
local function handleFiringPoint(systemName, systemCtx, unit, isAuto)
  local firingUnitCtx = systemCtx.firingUnits[unit.name]
  if Movement.isRepositioning(firingUnitCtx, isAuto) then
    Movement.setWCSToFree(firingUnitCtx, unit, isAuto)
    return buildPositionEventResult(
      "OK",
      systemName,
      unit.name,
      constants.POSITION_TYPES.FIRING_POINT,
      "firing_ready",
      nil,
      "state=STATIC wcs=FREE"
    )
  end

  return nil
end

---Handle entering hide area logic for a single missile system context
---@param systemName string Missile system name
---@param systemCtx SBJ__MissileSystemContext Missile system context
---@param unit CMO__Unit Triggered unit
---@param isAuto boolean Whether the action is in automatic mode
---@param behavior SBJ__MoveToPositionBehavior Side-specific behavior configuration
---@return SBJ__PositionEventResult|nil result Functional result when hide flow ran
local function handleHideArea(systemName, systemCtx, unit, isAuto, behavior)
  local firingUnitCtx = systemCtx.firingUnits[unit.name]
  if not firingUnitCtx then
    return nil
  end

  if behavior.hideOnEnterHA and not Ammo.isLowAmmo(unit, firingUnitCtx.ammoThreshold, firingUnitCtx.weaponDBID) then
    Movement.setStateToHide(firingUnitCtx, unit, isAuto)
    local success, errorMsg = Concealment.hideUnit(firingUnitCtx, unit)
    if success == false then
      return buildPositionEventResult(
        "WARN",
        systemName,
        unit.name,
        constants.POSITION_TYPES.HIDE_AREA,
        "concealment_failed",
        "hide_failed",
        errorMsg and string.format("state=HIDE %s", detailField(errorMsg)) or "state=HIDE"
      )
    end

    return buildPositionEventResult(
      "OK",
      systemName,
      unit.name,
      constants.POSITION_TYPES.HIDE_AREA,
      "concealed",
      nil,
      "state=HIDE"
    )
  end

  return nil
end

---Handle reload-point fallback when no meeting occurs
---@param systemName string Missile system name
---@param systemCtx SBJ__MissileSystemContext Missile system context
---@param unit CMO__Unit Triggered unit
---@param isAuto boolean Whether the action is in automatic mode
---@param behavior SBJ__MoveToPositionBehavior Side-specific behavior configuration
---@return SBJ__PositionEventResult|nil result Functional result when fallback performed a visible action
local function handleReloadPointNoMeeting(systemName, systemCtx, unit, isAuto, behavior)
  -- Pass false instead of isAuto so a firing unit drifting through RL during repositioning is not halted.
  Movement.setStateToStatic(systemCtx, unit, false)
  if not behavior.hideResupplyOnRLNoMeeting then
    return nil
  end

  local resupplyUnitCtx = systemCtx.resupplyUnits[unit.name]
  if not resupplyUnitCtx then
    return nil
  end

  local firingUnitCtx = systemCtx.firingUnits[resupplyUnitCtx.firingUnit]
  if not firingUnitCtx then
    return nil
  end

  local firingUnit = GameApi.ScenEdit_GetUnit(firingUnitCtx.name, behavior.firingUnitLookupSide)
  if firingUnit and not Ammo.isLowAmmo(firingUnit, firingUnitCtx.ammoThreshold, firingUnitCtx.weaponDBID) then
    local success, errorMsg = Concealment.hideUnit(resupplyUnitCtx, unit)
    if success == false then
      return buildPositionEventResult(
        "WARN",
        systemName,
        unit.name,
        constants.POSITION_TYPES.RELOAD_POINT,
        "resupply_concealment_failed",
        "hide_failed",
        string.format("pairedFiringUnit=%q %s",
          LogFormat.readable(firingUnitCtx.name),
          detailField(errorMsg or "hide_failed")
        )
      )
    end

    return buildPositionEventResult(
      "OK",
      systemName,
      unit.name,
      constants.POSITION_TYPES.RELOAD_POINT,
      "resupply_concealed",
      nil,
      string.format("pairedFiringUnit=%q ammoStatus=sufficient", LogFormat.readable(firingUnitCtx.name))
    )
  end

  return nil
end

---Handle entering reload point logic for a single missile system context
---@param systemName string Missile system name
---@param systemCtx SBJ__MissileSystemContext Missile system context
---@param unit CMO__Unit Triggered unit
---@param isAuto boolean Whether the action is in automatic mode
---@param behavior SBJ__MoveToPositionBehavior Side-specific behavior configuration
---@return SBJ__PositionEventResult|nil result Functional result when reload flow changed state
local function handleReloadPoint(systemName, systemCtx, unit, isAuto, behavior)
  local hasMet, firingUnitCtx = Meeting.hasMetResupplyUnit(systemCtx, unit, isAuto)

  if hasMet and firingUnitCtx then
    local firingUnit = (unit.name == firingUnitCtx.name) and unit or
        GameApi.ScenEdit_GetUnit(firingUnitCtx.name, unit.side)
    if firingUnit then
      Movement.setReloadStartTime(firingUnitCtx, firingUnit, isAuto)
      return buildPositionEventResult(
        "OK",
        systemName,
        firingUnitCtx.name,
        constants.POSITION_TYPES.RELOAD_POINT,
        "reload_started",
        nil,
        string.format("triggerUnit=%q state=RELOAD startedAt=%s",
          LogFormat.readable(unit.name),
          LogFormat.value(firingUnitCtx.reloadStartTime))
      )
    end

    return buildPositionEventResult(
      "WARN",
      systemName,
      firingUnitCtx.name,
      constants.POSITION_TYPES.RELOAD_POINT,
      "reload_not_started",
      "firing_unit_not_found",
      string.format("triggerUnit=%q", LogFormat.readable(unit.name))
    )
  end

  return handleReloadPointNoMeeting(systemName, systemCtx, unit, isAuto, behavior)
end

---Handle entering ammo holding area logic for a single missile system context
---@param systemName string Missile system name
---@param systemCtx SBJ__MissileSystemContext Missile system context
---@param unit CMO__Unit Triggered unit
---@param isAuto boolean Whether the action is in automatic mode
---@return SBJ__PositionEventResult|nil result Functional result when transload flow changed state
local function handleAmmoHoldingArea(systemName, systemCtx, unit, isAuto)
  local hasMet, resupplyUnit = Meeting.hasMetAmmoDepot(systemCtx, unit, isAuto)
  local resupplyUnitCtx = systemCtx.resupplyUnits[unit.name]

  if resupplyUnitCtx and hasMet and resupplyUnit then
    Movement.setReloadStartTime(resupplyUnit, unit, isAuto)
    return buildPositionEventResult(
      "OK",
      systemName,
      resupplyUnit.name,
      constants.POSITION_TYPES.AMMO_HOLDING_AREA,
      "transload_started",
      nil,
      string.format("state=RELOAD startedAt=%s", LogFormat.value(resupplyUnit.reloadStartTime))
    )
  end

  Movement.setStateToStatic(systemCtx, unit, isAuto)
  return nil
end

---Handle missile system UnitEntersArea flow for FP/HA/RL/AHA positions
---@param opts SBJ__MoveToPositionEventOpts Unit-enter-area event handling options
function MissileSystem.handleMoveToPositionEvent(opts)
  local unit = opts.unit
  local groundCtx = opts.groundCtx
  local isAuto = opts.isAuto
  local behavior = resolveBehavior(opts.behavior, unit.side)
  local positionType = extractPositionType(opts.event)
  local results = {}

  if not positionType then
    return
  end

  if positionType ~= constants.POSITION_TYPES.FIRING_POINT then
    dropUnitContact(unit, opts.contacts)
  end

  if positionType == constants.POSITION_TYPES.FIRING_POINT then
    forEachEnabledSystem(groundCtx, function(systemCtx, systemName)
      appendPositionEventResult(results, handleFiringPoint(systemName, systemCtx, unit, isAuto))
    end)
  elseif positionType == constants.POSITION_TYPES.HIDE_AREA then
    forEachEnabledSystem(groundCtx, function(systemCtx, systemName)
      appendPositionEventResult(results, handleHideArea(systemName, systemCtx, unit, isAuto, behavior))
    end)
  elseif positionType == constants.POSITION_TYPES.RELOAD_POINT then
    forEachEnabledSystem(groundCtx, function(systemCtx, systemName)
      appendPositionEventResult(results, handleReloadPoint(systemName, systemCtx, unit, isAuto, behavior))
    end)
  elseif positionType == constants.POSITION_TYPES.AMMO_HOLDING_AREA then
    forEachEnabledSystem(groundCtx, function(systemCtx, systemName)
      appendPositionEventResult(results, handleAmmoHoldingArea(systemName, systemCtx, unit, isAuto))
    end)
  end

  if #results > 0 then
    local entries = {}
    local hasWarning = false
    for _, result in ipairs(results) do
      table.insert(entries, LogFormat.entry(result.tag, formatPositionEventResult(result)))
      if result.tag == "WARN" or result.tag == "FAIL" or result.tag == "ERROR" then
        hasWarning = true
      end
    end

    local summary = LogFormat.summary(
      "side",
      unit.side,
      string.format("Position event mode=%s", isAuto and "auto" or "manual"),
      entries
    )

    if hasWarning then
      Logger.warn(summary)
    else
      Logger.log(constants.TAGS.MISSILE_SYSTEM, summary)
    end
  end
end

return MissileSystem
