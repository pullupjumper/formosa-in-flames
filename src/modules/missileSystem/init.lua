local Logger = require("src.utils.logger")
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
    Logger.error(constants.TAGS.MISSILE_SYSTEM .. ": [FAIL] " .. errorMsg)
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

---Check status of all missile systems and trigger corresponding actions
---@param groundCtx SBJ__GroundForceContext Ground force contexts keyed by missile system type
---@param isAuto boolean Whether in automatic mode
---@param sideName string Side name
function MissileSystem.checkMissileSystemState(groundCtx, isAuto, sideName)
  local allResults = {}

  for _, missileSystem in pairs(constants.MISSILE_SYSTEM_TYPES) do
    local systemCtx = groundCtx[missileSystem]
    if systemCtx and systemCtx.enabled then
      local systemResults = Cycle.process(systemCtx, isAuto, sideName)
      for _, result in ipairs(systemResults) do
        table.insert(allResults, {
          system = missileSystem,
          tag = result.tag,
          action = result.action,
          unitName = result.unitName
        })
      end
    end
  end

  if #allResults > 0 then
    local lines = {}
    for _, r in ipairs(allResults) do
      table.insert(lines, string.format("  [%s] (%s) %s: %s", r.tag, r.system, r.action, r.unitName))
    end
    Logger.log(constants.TAGS.MISSILE_SYSTEM, string.format(
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
  return Context.handleSupplyAssetDestruction(unit, systemCtx)
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
---@param callback fun(systemCtx: SBJ__MissileSystemContext) Callback invoked for each enabled system context
local function forEachEnabledSystem(groundCtx, callback)
  for _, missileSystem in pairs(constants.MISSILE_SYSTEM_TYPES) do
    local systemCtx = groundCtx[missileSystem]
    if systemCtx and systemCtx.enabled then
      callback(systemCtx)
    end
  end
end

---Handle entering firing point logic for a single missile system context
---@param systemCtx SBJ__MissileSystemContext Missile system context
---@param unit CMO__Unit Triggered unit
---@param isAuto boolean Whether the action is in automatic mode
local function handleFiringPoint(systemCtx, unit, isAuto)
  local firingUnitCtx = systemCtx.firingUnits[unit.name]
  if Movement.isRepositioning(firingUnitCtx, isAuto) then
    Movement.setWCSToFree(firingUnitCtx, unit, isAuto)
  end
end

---Handle entering hide area logic for a single missile system context
---@param systemCtx SBJ__MissileSystemContext Missile system context
---@param unit CMO__Unit Triggered unit
---@param isAuto boolean Whether the action is in automatic mode
---@param behavior SBJ__MoveToPositionBehavior Side-specific behavior configuration
local function handleHideArea(systemCtx, unit, isAuto, behavior)
  local firingUnitCtx = systemCtx.firingUnits[unit.name]
  if not firingUnitCtx then
    return
  end

  if behavior.hideOnEnterHA and not Ammo.isLowAmmo(unit, firingUnitCtx.ammoThreshold, firingUnitCtx.weaponDBID) then
    Movement.setStateToHide(firingUnitCtx, unit, isAuto)
    Concealment.hideUnit(firingUnitCtx, unit)
  end
end

---Handle reload-point fallback when no meeting occurs
---@param systemCtx SBJ__MissileSystemContext Missile system context
---@param unit CMO__Unit Triggered unit
---@param isAuto boolean Whether the action is in automatic mode
---@param behavior SBJ__MoveToPositionBehavior Side-specific behavior configuration
local function handleReloadPointNoMeeting(systemCtx, unit, isAuto, behavior)
  Movement.setStateToStatic(systemCtx, unit, isAuto)
  if not behavior.hideResupplyOnRLNoMeeting then
    return
  end

  local resupplyUnitCtx = systemCtx.resupplyUnits[unit.name]
  if not resupplyUnitCtx then
    return
  end

  local firingUnitCtx = systemCtx.firingUnits[resupplyUnitCtx.firingUnit]
  if not firingUnitCtx then
    return
  end

  local firingUnit = GameApi.ScenEdit_GetUnit(firingUnitCtx.name, behavior.firingUnitLookupSide)
  if firingUnit and not Ammo.isLowAmmo(firingUnit, firingUnitCtx.ammoThreshold, firingUnitCtx.weaponDBID) then
    Concealment.hideUnit(resupplyUnitCtx, unit)
  end
end

---Handle entering reload point logic for a single missile system context
---@param systemCtx SBJ__MissileSystemContext Missile system context
---@param unit CMO__Unit Triggered unit
---@param isAuto boolean Whether the action is in automatic mode
---@param behavior SBJ__MoveToPositionBehavior Side-specific behavior configuration
local function handleReloadPoint(systemCtx, unit, isAuto, behavior)
  local hasMet, context = Meeting.hasMetResupplyUnit(systemCtx, unit, isAuto)
  local firingUnitCtx = systemCtx.firingUnits[unit.name]

  if firingUnitCtx and hasMet and context then
    Movement.setReloadStartTime(context, unit, isAuto)
    return
  end

  handleReloadPointNoMeeting(systemCtx, unit, isAuto, behavior)
end

---Handle entering ammo holding area logic for a single missile system context
---@param systemCtx SBJ__MissileSystemContext Missile system context
---@param unit CMO__Unit Triggered unit
---@param isAuto boolean Whether the action is in automatic mode
local function handleAmmoHoldingArea(systemCtx, unit, isAuto)
  local hasMet, resupplyUnit = Meeting.hasMetAmmoDepot(systemCtx, unit, isAuto)
  local resupplyUnitCtx = systemCtx.resupplyUnits[unit.name]

  if resupplyUnitCtx and hasMet and resupplyUnit then
    Movement.setReloadStartTime(resupplyUnit, unit, isAuto)
    return
  end

  Movement.setStateToStatic(systemCtx, unit, isAuto)
end

---Handle missile system UnitEntersArea flow for FP/HA/RL/AHA positions
---@param opts SBJ__MoveToPositionEventOpts Unit-enter-area event handling options
function MissileSystem.handleMoveToPositionEvent(opts)
  local unit = opts.unit
  local groundCtx = opts.groundCtx
  local isAuto = opts.isAuto
  local behavior = resolveBehavior(opts.behavior, unit.side)
  local positionType = extractPositionType(opts.event)

  if not positionType then
    return
  end

  if positionType ~= constants.POSITION_TYPES.FIRING_POINT then
    dropUnitContact(unit, opts.contacts)
  end

  if positionType == constants.POSITION_TYPES.FIRING_POINT then
    forEachEnabledSystem(groundCtx, function(systemCtx)
      handleFiringPoint(systemCtx, unit, isAuto)
    end)
  elseif positionType == constants.POSITION_TYPES.HIDE_AREA then
    forEachEnabledSystem(groundCtx, function(systemCtx)
      handleHideArea(systemCtx, unit, isAuto, behavior)
    end)
  elseif positionType == constants.POSITION_TYPES.RELOAD_POINT then
    forEachEnabledSystem(groundCtx, function(systemCtx)
      handleReloadPoint(systemCtx, unit, isAuto, behavior)
    end)
  elseif positionType == constants.POSITION_TYPES.AMMO_HOLDING_AREA then
    forEachEnabledSystem(groundCtx, function(systemCtx)
      handleAmmoHoldingArea(systemCtx, unit, isAuto)
    end)
  end
end

return MissileSystem
