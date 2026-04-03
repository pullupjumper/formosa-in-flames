local Logger = require("src.utils.logger")
local constants = require("src.core.constants")
local Ammo = require("src.modules.missileSystem.ammo")
local Meeting = require("src.modules.missileSystem.meeting")
local Movement = require("src.modules.missileSystem.movement")
local Concealment = require("src.modules.missileSystem.concealment")
local Cycle = require("src.modules.missileSystem.cycle")
local Triggers = require("src.modules.missileSystem.triggers")
local Deployment = require("src.modules.missileSystem.deployment")
local Context = require("src.modules.missileSystem.context")

local MissileSystem = {}

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

---Set firing unit reload start time
---@param firingUnitCtx SBJ__FiringUnitContext Firing unit context
---@param firingUnit CMO__Unit Firing unit group
---@param isAuto boolean Whether in automatic mode
function MissileSystem.setReloadStartTime(firingUnitCtx, firingUnit, isAuto)
  Movement.setReloadStartTime(firingUnitCtx, firingUnit, isAuto)
end

---Set firing unit weapon control status to free fire
---@param firingUnitCtx SBJ__FiringUnitContext Firing unit context
---@param firingUnit CMO__Unit Firing unit group
---@param isAuto boolean Whether in automatic mode
function MissileSystem.setWCSToFree(firingUnitCtx, firingUnit, isAuto)
  Movement.setWCSToFree(firingUnitCtx, firingUnit, isAuto)
end

---Set firing unit status to hide
---@param firingUnitCtx SBJ__FiringUnitContext Firing unit context
---@param firingUnit CMO__Unit Firing unit group
---@param isAuto boolean Whether the action is automatic
function MissileSystem.setStateToHIDE(firingUnitCtx, firingUnit, isAuto)
  Movement.setStateToHide(firingUnitCtx, firingUnit, isAuto)
end

---Reset unit state to STATIC and clear reload timer
---@param systemCtx SBJ__MissileSystemContext Missile system context
---@param firingUnit CMO__Unit Unit group to reset
---@param isAuto boolean Whether the action is automatic
function MissileSystem.setStateToStatic(systemCtx, firingUnit, isAuto)
  Movement.setStateToStatic(systemCtx, firingUnit, isAuto)
end

---Check if firing unit is currently repositioning
---In auto mode checks state; in manual mode always returns true
---@param firingUnitCtx SBJ__FiringUnitContext|nil Firing unit context
---@param isAuto boolean Whether the action is automatic
---@return boolean # Whether the unit is repositioning
function MissileSystem.isRepositioning(firingUnitCtx, isAuto)
  return Movement.isRepositioning(firingUnitCtx, isAuto)
end

---Unload firing unit group from hide area buildings
---@param unitCtx SBJ__FiringUnitContext|SBJ__ResupplyUnitContext Unit context with operational area
---@param unit CMO__Unit Firing unit to unload
---@return boolean success Whether unload was performed
---@return string? errorMsg Error message if failed
function MissileSystem.moveFromHideArea(unitCtx, unit)
  return Concealment.moveFromHideArea(unitCtx, unit)
end

---Load firing unit into a random building within mask area
---@param unitCtx SBJ__FiringUnitContext|SBJ__ResupplyUnitContext Unit context with operational area
---@param unit CMO__Unit Firing unit to hide
---@return boolean success Whether hide was performed
---@return string? errorMsg Error message if failed
function MissileSystem.hideUnit(unitCtx, unit)
  return Concealment.hideUnit(unitCtx, unit)
end

---Check if unit/group ammunition is below specified percentage
---@param firingUnit CMO__Unit Unit or group object
---@param percentage number|nil Percentage threshold
---@param weaponDBID number|number[]|nil Weapon database ID(s)
---@return boolean # Whether it is low ammunition
function MissileSystem.isLowAmmo(firingUnit, percentage, weaponDBID)
  return Ammo.isLowAmmo(firingUnit, percentage, weaponDBID)
end

---Check if firing unit has met with resupply units
---@param systemCtx SBJ__MissileSystemContext Weapon system context
---@param unit CMO__Unit Unit to check
---@param isAuto boolean Whether in automatic mode
---@return boolean hasMet Whether units have met
---@return SBJ__FiringUnitContext|SBJ__ResupplyUnitContext|nil context The matched context
function MissileSystem.hasMetResupplyUnit(systemCtx, unit, isAuto)
  return Meeting.hasMetResupplyUnit(systemCtx, unit, isAuto)
end

---Check if resupply unit has met with ammunition depot
---@param systemCtx SBJ__MissileSystemContext Weapon system context
---@param unit CMO__Unit Unit to check
---@param isAuto boolean Whether in automatic mode
---@return boolean hasMet Whether units have met
---@return SBJ__ResupplyUnitContext|nil resupplyUnit The matched resupply unit context
function MissileSystem.hasMetAmmoDepot(systemCtx, unit, isAuto)
  return Meeting.hasMetAmmoDepot(systemCtx, unit, isAuto)
end

---Check status of all units and trigger corresponding actions
---@param systemCtx SBJ__MissileSystemContext Missile system context
---@param isAuto boolean Whether in automatic mode
---@param sideName string Side name
function MissileSystem.checkMissileSystemState(systemCtx, isAuto, sideName)
  local allResults = Cycle.process(systemCtx, isAuto, sideName)

  if #allResults > 0 then
    local lines = {}
    for _, r in ipairs(allResults) do
      table.insert(lines, string.format("  [%s] %s: %s", r.tag, r.action, r.unitName))
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
---@param positionTypes string[] Position type identifiers (RL/HA/AHA/FP)
---@param sideName string Side name for zone/trigger ownership
function MissileSystem.initEventTriggers(operationalAreas, positionTypes, sideName)
  Triggers.initEventTriggers(operationalAreas, positionTypes, sideName)
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

return MissileSystem
