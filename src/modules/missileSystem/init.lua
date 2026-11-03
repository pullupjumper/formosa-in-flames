local Logger = require("src.utils.logger")
local LogFormat = require("src.utils.logFormat")
local constants = require("src.core.constants")
local PersistentState = require("src.core.persistentState")
local GameApi = require("src.utils.gameApi")
local GameUtils = require("src.utils.gameUtils")
local Ammo = require("src.modules.missileSystem.ammo")
local Arrival = require("src.modules.missileSystem.arrival")
local Movement = require("src.modules.missileSystem.movement")
local Concealment = require("src.modules.missileSystem.concealment")
local Cycle = require("src.modules.missileSystem.cycle")
local Rules = require("src.modules.missileSystem.rules")
local Transitions = require("src.modules.missileSystem.transitions")
local Triggers = require("src.modules.missileSystem.triggers")
local Deployment = require("src.modules.missileSystem.deployment")
local GroundStateStore = require("src.modules.missileSystem.groundStateStore")
local StatusView = require("src.modules.missileSystem.statusView")
local ControlPanelLayout = require("src.modules.missileSystem.controlPanelLayout")

local MissileSystem = {}

---Position types whose zones and triggers are rebuilt when batteries are redeployed
local REDEPLOY_POSITION_TYPES = {
  constants.POSITION_TYPES.RELOAD_POINT,
  constants.POSITION_TYPES.FIRING_POINT,
  constants.POSITION_TYPES.HIDE_AREA,
  constants.POSITION_TYPES.AMMO_HOLDING_AREA
}

---Command firing unit to move to firing point (FP), logging any failure
---@param firingUnitState SBJ__FiringUnitState
---@param firingUnit CMO__Unit
local function startMoveToFiringPoint(firingUnitState, firingUnit)
  local success, errorFields = Transitions.depart(firingUnitState, Movement.moveToFiringPoint(firingUnitState, firingUnit))
  if not success and errorFields then
    Logger.error(LogFormat.line("FAIL", LogFormat.merge({
      module = constants.TAGS.MISSILE_SYSTEM,
      action = "move_to_firing_point",
      unit = firingUnitState.name or firingUnit.name
    }, errorFields)))
  end
end

---Steps of a fire support plan dispatch keyed by Rules.STEP
---@type table<string, fun(firingUnitState: SBJ__FiringUnitState, firingUnit: CMO__Unit)>
local SEND_TO_FIRING_POINT_STEPS = {
  [Rules.STEP.UNHIDE] = function(firingUnitState, firingUnit)
    Concealment.moveFromHideArea(firingUnitState, firingUnit)
  end,
  [Rules.STEP.MOVE_TO_FIRING_POINT] = startMoveToFiringPoint,
}

---Find a firing unit runtime state by missile system and unit name
---@param groundState SBJ__GroundState
---@param missileSystemType string Missile system name in any case (e.g., "SRBM", "srbm")
---@param firingUnitName string
---@return SBJ__FiringUnitState|nil # Firing unit runtime state, or nil when missing
local function findFiringUnitState(groundState, missileSystemType, firingUnitName)
  local systemState = groundState.missileSystemTypes[string.lower(missileSystemType)] --[[@as SBJ__MissileSystemState?]]
  return systemState and systemState.firingUnits and systemState.firingUnits[firingUnitName]
end

---Send a firing unit from its hide area to its firing point when it is ready
---A unit is ready when it is hiding with enough ammunition; units already out are left alone.
---@param groundState SBJ__GroundState
---@param missileSystemType string Missile system name in any case (e.g., "SRBM", "srbm")
---@param firingUnitName string
---@return boolean inPosition Whether the unit is at its firing point
---@return boolean isMissing Whether the unit no longer exists in game or has no runtime state
function MissileSystem.sendToFiringPoint(groundState, missileSystemType, firingUnitName)
  local firingUnit = GameApi.ScenEdit_GetUnit(firingUnitName)
  local firingUnitState = findFiringUnitState(groundState, missileSystemType, firingUnitName)
  if not firingUnit or not firingUnitState then
    return false, true
  end

  local function isLowAmmo()
    return Ammo.isLowAmmo(firingUnit, firingUnitState.ammoThreshold, firingUnitState.weaponDBID)
  end

  for _, step in ipairs(Rules.evaluateSendToFiringPoint(firingUnitState, isLowAmmo)) do
    SEND_TO_FIRING_POINT_STEPS[step](firingUnitState, firingUnit)
  end

  return Rules.isInPosition(firingUnitState), false
end

---Calculate ammunition inventory across firing/resupply/ammo for a missile system
---@param groundState SBJ__GroundState
---@param missileSystemType string Missile system type (constants.MISSILE_SYSTEM_TYPES)
---@param sideName string
---@return SBJ__AmmoInventoryResult|nil # Inventory report with subtotals and percentages, nil when the system is absent
function MissileSystem.getAmmoInventory(groundState, missileSystemType, sideName)
  local systemState = groundState.missileSystemTypes[missileSystemType]
  if not systemState then
    return nil
  end

  return Ammo.getInventory(systemState, sideName)
end

---Evaluate whether a firing unit can take a fire support task, and why not
---@param groundState SBJ__GroundState
---@param missileSystemType string Missile system name in any case (e.g., "SRBM", "srbm")
---@param firingUnitName string
---@param getUnit fun(name: string): CMO__Unit|nil Called only when the unit has a runtime state
---@return missileSystemReadiness
function MissileSystem.evaluateReadiness(groundState, missileSystemType, firingUnitName, getUnit)
  local readiness = constants.MISSILE_SYSTEM_READINESS
  local firingUnitState = findFiringUnitState(groundState, missileSystemType, firingUnitName)
  if not firingUnitState then
    return readiness.NO_STATE
  end

  local firingUnit = getUnit(firingUnitName)
  if not firingUnit then
    return readiness.UNIT_NOT_FOUND
  end

  return Rules.evaluateReadiness(firingUnitState, function()
    return Ammo.isLowAmmo(firingUnit, firingUnitState.ammoThreshold, firingUnitState.weaponDBID)
  end)
end

---Start the stow countdown so the reload cycle sends the firing units back
---SAM never stows, and a countdown already running is kept.
---@param groundState SBJ__GroundState
---@param missileSystemType string|nil Missile system name in any case (e.g., "SRBM", "srbm")
---@param firingUnits SBJ__FiringUnit[]|nil
---@param opts {onlyDeployed: boolean}|nil onlyDeployed skips units still in their hide area or reloading
function MissileSystem.startStow(groundState, missileSystemType, firingUnits, opts)
  if not missileSystemType or not firingUnits or Rules.staysDeployed(missileSystemType) then
    return
  end

  for _, firingUnit in ipairs(firingUnits) do
    local firingUnitState = findFiringUnitState(groundState, missileSystemType, firingUnit.name)

    if firingUnitState and Rules.shouldStow(firingUnitState, opts) then
      Transitions.beginStow(firingUnitState)
    end
  end
end

---Check status of all missile systems and trigger corresponding actions
---@param groundState SBJ__GroundState
---@param missileSystemConfigMap table<string, SBJ__MissileSystemConfig>
---@param isAuto boolean
---@param sideName string
local function process(groundState, missileSystemConfigMap, isAuto, sideName)
  local report = LogFormat.report(constants.TAGS.MISSILE_SYSTEM, "side=" .. sideName, "Reload cycle")

  for missileSystemType, systemState in pairs(groundState.missileSystemTypes) do
    if systemState.enabled then
      for _, result in ipairs(Cycle.process(systemState, { systemConfig = missileSystemConfigMap[missileSystemType], isAuto = isAuto }, sideName)) do
        result.fields.system = missileSystemType
        report.add(result.tag, result.fields)
      end
    end
  end

  report.emit({ mode = isAuto and "auto" or "manual" })
end

---@param config SBJ__Config
---@param sideName string
---@return table<string, SBJ__MissileSystemConfig>
local function getMissileSystemTypes(config, sideName)
  return config[GameUtils.getCachedSideConfig(sideName).field].ground.missileSystemTypes
end

---Run one reload/hide cycle for a side, with its policy taken from config
---@param config SBJ__Config
---@param saveData SBJ__SaveData
---@param sideName string
function MissileSystem.processSide(config, saveData, sideName)
  local sideConfig = config[GameUtils.getCachedSideConfig(sideName).field]

  process(
    PersistentState.ground(saveData, sideName),
    sideConfig.ground.missileSystemTypes,
    sideConfig.ground.policy.isAuto,
    sideName
  )
end

---Deduct ammunition when an ammo depot or resupply vehicle of any missile system is destroyed
---@param saveData SBJ__SaveData
---@param unit CMO__Unit
---@return boolean processed Whether the unit belonged to a missile system and ammo was adjusted
function MissileSystem.processSupplyAssetDestruction(saveData, unit)
  local groundState = PersistentState.ground(saveData, unit.side)

  for _, systemState in pairs(groundState.missileSystemTypes) do
    local success, result = GroundStateStore.processSupplyAssetDestruction(unit, systemState)

    -- A destroyed unit belongs to at most one system, so the first match ends the search.
    if success and result then
      Logger.log(constants.TAGS.MISSILE_SYSTEM, LogFormat.line(result.tag, {
        system = result.system,
        action = "supply_asset_destroyed",
        role = result.role,
        unit = result.unitName,
        context = result.contextName,
        ammoBefore = result.ammoBefore,
        ammoAfter = result.ammoAfter,
        delta = result.delta
      }))
      return true
    end
  end

  return false
end

---Move batteries to player-chosen operational areas, then rebuild their zones, units and state
---@param missileSystemConfigMap table<string, SBJ__MissileSystemConfig>
---@param groundState SBJ__GroundState
---@param sideName string
---@param layouts SBJ__MissileSystemLayout[]
local function redeploy(missileSystemConfigMap, groundState, sideName, layouts)
  local operationalAreas, operationalAreasToRemove = Deployment.updateLayouts(missileSystemConfigMap, layouts)

  Triggers.initEventTriggers(operationalAreas, operationalAreasToRemove, REDEPLOY_POSITION_TYPES, sideName)
  local rebuiltFiringUnits = {}
  for _, layout in ipairs(layouts) do
    rebuiltFiringUnits[layout.unitname] = true
  end
  Deployment.addMissileSystems(missileSystemConfigMap, sideName, rebuiltFiringUnits)
  GroundStateStore.initMissileSystemStates(missileSystemConfigMap, groundState)
end

---Redeploy a side's batteries to the placements submitted by the control panel
---@param config SBJ__Config
---@param saveData SBJ__SaveData
---@param sideName string
---@param entries SBJ__MissileSystemResult[]
function MissileSystem.redeployFromControlPanel(config, saveData, sideName, entries)
  redeploy(
    getMissileSystemTypes(config, sideName),
    PersistentState.ground(saveData, sideName),
    sideName,
    ControlPanelLayout.buildLayouts(entries)
  )
end

---Build a side's missile system rows for the control panel
---@param config SBJ__Config
---@param sideName string
---@return table<string, SBJ__MissileSystemConfig> # Config copies with zone vertices, keyed by system type
function MissileSystem.buildDeploymentSystems(config, sideName)
  return ControlPanelLayout.buildDeploymentSystems(
    getMissileSystemTypes(config, sideName),
    sideName
  )
end

---Add a side's missile system units and build their runtime states from config
---@param config SBJ__Config
---@param saveData SBJ__SaveData
---@param sideName string
function MissileSystem.deploySide(config, saveData, sideName)
  local missileSystemConfigMap = getMissileSystemTypes(config, sideName)

  Deployment.addMissileSystems(missileSystemConfigMap, sideName)
  GroundStateStore.initMissileSystemStates(missileSystemConfigMap, PersistentState.ground(saveData, sideName))
end

---Build a side's battery statuses for the control panel, one per battery (firing unit plus its paired resupply unit)
---@param config SBJ__Config
---@param saveData SBJ__SaveData
---@param sideName string
---@return SBJ__BatteryStatus[] # One status per battery
function MissileSystem.buildBatteryStatuses(config, saveData, sideName)
  return StatusView.buildBatteryStatuses(
    PersistentState.ground(saveData, sideName),
    getMissileSystemTypes(config, sideName),
    GameApi.ScenEdit_CurrentTime()
  )
end

---Seed a side's default per-system state (name, enabled, empty unit maps) from configuration
---@param config SBJ__Config
---@param saveData SBJ__SaveData
---@param sideName string
function MissileSystem.ensureGroundState(config, saveData, sideName)
  GroundStateStore.ensureGroundState(
    getMissileSystemTypes(config, sideName),
    PersistentState.ground(saveData, sideName)
  )
end

---Initialize a side's missile system runtime states from configuration when its ground forces are enabled
---@param config SBJ__Config
---@param saveData SBJ__SaveData
---@param sideName string
function MissileSystem.initSide(config, saveData, sideName)
  local groundState = PersistentState.ground(saveData, sideName)
  if not groundState.enabled then
    return
  end

  GroundStateStore.initMissileSystemStates(getMissileSystemTypes(config, sideName), groundState)
end

---Handle a UnitEntersArea event for the triggering unit's side, with its policy taken from config
---@param config SBJ__Config
---@param saveData SBJ__SaveData
---@param unit CMO__Unit
---@param event CMO__Event
function MissileSystem.processUnitEntersArea(config, saveData, unit, event)
  local policy = config[GameUtils.getCachedSideConfig(unit.side).field].ground.policy

  Arrival.processMoveToPositionEvent({
    groundState = PersistentState.ground(saveData, unit.side),
    unit = unit,
    event = event,
    contacts = GameApi.ScenEdit_GetContacts(unit.side),
    moveCtx = {
      isAuto = policy.isAuto,
      hideOnEnterHA = policy.hideOnEnterHA,
      hideResupplyOnRLNoMeeting = policy.hideResupplyOnRLNoMeeting,
      firingUnitLookupSide = unit.side
    }
  })
end

return MissileSystem
