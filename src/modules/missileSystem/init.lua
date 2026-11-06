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
local Shared = require("src.modules.missileSystem.shared")
local Transitions = require("src.modules.missileSystem.transitions")
local PositionZones = require("src.modules.missileSystem.positionZones")
local Deployment = require("src.modules.missileSystem.deployment")
local GroundStateStore = require("src.modules.missileSystem.groundStateStore")
local PanelBattery = require("src.modules.missileSystem.panelBattery")

local MissileSystem = {}

---Position types whose zones and triggers are rebuilt when batteries are redeployed
local REDEPLOY_POSITION_TYPES = {
  constants.POSITION_TYPES.RELOAD_POINT,
  constants.POSITION_TYPES.FIRING_POINT,
  constants.POSITION_TYPES.HIDE_AREA,
  constants.POSITION_TYPES.AMMUNITION_TRANSFER_POINT
}

---Steps of a fire support plan dispatch keyed by Rules.STEP
---@type table<string, fun(firingUnitState: SBJ__FiringUnitState, firingUnit: CMO__Unit): SBJ__LogResult|nil>
local SEND_TO_FIRING_POINT_STEPS = {
  [Rules.STEP.UNHIDE] = function(firingUnitState, firingUnit)
    Concealment.moveFromHideArea(firingUnitState, firingUnit)
  end,
  [Rules.STEP.MOVE_TO_FIRING_POINT] = function(firingUnitState, firingUnit)
    return Transitions.depart(firingUnitState, firingUnit, Movement.ORDER.FIRING_POINT)
  end,
}

---@param config SBJ__Config
---@param sideName string
---@return table<string, SBJ__MissileSystemConfig>
local function getMissileSystemTypes(config, sideName)
  return config[GameUtils.getCachedSideConfig(sideName).field].ground.missileSystemTypes
end

---Find a firing unit config descriptor by missile system and unit name
---@param config SBJ__Config
---@param sideName string
---@param missileSystemType string Missile system name in any case (e.g., "SRBM", "srbm")
---@param firingUnitName string
---@return SBJ__FiringUnitDescriptor|nil # Nil when config has no such system or firing unit
local function findFiringUnitDescriptor(config, sideName, missileSystemType, firingUnitName)
  local systemConfig = getMissileSystemTypes(config, sideName)[string.lower(missileSystemType)]
  return systemConfig and systemConfig.firingUnits[firingUnitName]
end

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
---@param config SBJ__Config
---@param groundState SBJ__GroundState
---@param sideName string Side that owns the firing unit
---@param missileSystemType string Missile system name in any case (e.g., "SRBM", "srbm")
---@param firingUnitName string
---@return boolean inPosition Whether the unit is at its firing point
---@return boolean isMissing Whether the unit no longer exists in game, in config or in runtime state
function MissileSystem.sendToFiringPoint(config, groundState, sideName, missileSystemType, firingUnitName)
  local firingUnit = GameApi.ScenEdit_GetUnit(firingUnitName)
  local firingUnitState = findFiringUnitState(groundState, missileSystemType, firingUnitName)
  local firingUnitDescriptor = findFiringUnitDescriptor(config, sideName, missileSystemType, firingUnitName)
  if not firingUnit or not firingUnitState or not firingUnitDescriptor then
    return false, true
  end

  local function isLowAmmo()
    return Ammo.isLowAmmo(firingUnit, firingUnitDescriptor.ammoThreshold, firingUnitDescriptor.weaponDBID)
  end

  local steps = Rules.evaluateSendToFiringPoint(firingUnitState, isLowAmmo)
  for _, row in ipairs(Shared.processSteps(steps, SEND_TO_FIRING_POINT_STEPS, firingUnitState, firingUnit)) do
    -- A single dispatch, not a report, so only a failure is written.
    if row.tag == "FAIL" then
      Logger.error(LogFormat.line("FAIL", LogFormat.merge({ module = constants.TAGS.MISSILE_SYSTEM }, row.fields)))
    end
  end

  return Rules.isInPosition(firingUnitState), false
end

---Calculate ammunition inventory across firing/resupply/canister stock for a missile system
---@param config SBJ__Config
---@param groundState SBJ__GroundState
---@param missileSystemType string Missile system type (constants.MISSILE_SYSTEM_TYPES)
---@param sideName string
---@return SBJ__AmmoInventoryResult|nil # Inventory report with subtotals and percentages, nil when the system is absent
function MissileSystem.getAmmoInventory(config, groundState, missileSystemType, sideName)
  local systemState = groundState.missileSystemTypes[missileSystemType]
  local systemConfig = getMissileSystemTypes(config, sideName)[missileSystemType]
  if not systemState or not systemConfig then
    return nil
  end

  return Ammo.getInventory(systemConfig, systemState, sideName)
end

---Evaluate whether a firing unit can take a fire support task, and why not
---@param config SBJ__Config
---@param groundState SBJ__GroundState
---@param sideName string Side that owns the firing unit
---@param missileSystemType string Missile system name in any case (e.g., "SRBM", "srbm")
---@param firingUnitName string
---@param getUnit fun(name: string): CMO__Unit|nil Called only when the unit has a runtime state and a config descriptor
---@return missileSystemReadiness
function MissileSystem.evaluateReadiness(config, groundState, sideName, missileSystemType, firingUnitName, getUnit)
  local readiness = constants.MISSILE_SYSTEM_READINESS
  local firingUnitState = findFiringUnitState(groundState, missileSystemType, firingUnitName)
  local firingUnitDescriptor = findFiringUnitDescriptor(config, sideName, missileSystemType, firingUnitName)
  if not firingUnitState or not firingUnitDescriptor then
    return readiness.NO_STATE
  end

  local firingUnit = getUnit(firingUnitName)
  if not firingUnit then
    return readiness.UNIT_NOT_FOUND
  end

  return Rules.evaluateReadiness(firingUnitState, function()
    return Ammo.isLowAmmo(firingUnit, firingUnitDescriptor.ammoThreshold, firingUnitDescriptor.weaponDBID)
  end)
end

---Find the states of a fire task's firing units that leave their position once the task ends
---SAM stays on station to guard the airspace, so it has none.
---@param groundState SBJ__GroundState
---@param missileSystemType string|nil Missile system name in any case (e.g., "SRBM", "srbm")
---@param firingUnits SBJ__FiringUnit[]|nil
---@return SBJ__FiringUnitState[]
local function findLeavingFiringUnitStates(groundState, missileSystemType, firingUnits)
  local firingUnitStates = {}
  if not missileSystemType or not firingUnits or Rules.staysDeployed(missileSystemType) then
    return firingUnitStates
  end

  for _, firingUnit in ipairs(firingUnits) do
    local firingUnitState = findFiringUnitState(groundState, missileSystemType, firingUnit.name)
    if firingUnitState then
      table.insert(firingUnitStates, firingUnitState)
    end
  end

  return firingUnitStates
end

---End a fire task that fired: its firing units stow, then the reload cycle sends them back
---A countdown already running is kept.
---@param groundState SBJ__GroundState
---@param missileSystemType string|nil Missile system name in any case (e.g., "SRBM", "srbm")
---@param firingUnits SBJ__FiringUnit[]|nil
function MissileSystem.completeFireTask(groundState, missileSystemType, firingUnits)
  for _, firingUnitState in ipairs(findLeavingFiringUnitStates(groundState, missileSystemType, firingUnits)) do
    Transitions.beginStow(firingUnitState)
  end
end

---End a fire task that never fired: only firing units already out of their hide area stow
---A countdown already running is kept.
---@param groundState SBJ__GroundState
---@param missileSystemType string|nil Missile system name in any case (e.g., "SRBM", "srbm")
---@param firingUnits SBJ__FiringUnit[]|nil
function MissileSystem.abortFireTask(groundState, missileSystemType, firingUnits)
  for _, firingUnitState in ipairs(findLeavingFiringUnitStates(groundState, missileSystemType, firingUnits)) do
    if Rules.isDeployed(firingUnitState) then
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

  GroundStateStore.forEachEnabledSystem(groundState, function(systemState, missileSystemType)
    local runCtx = { systemConfig = missileSystemConfigMap[missileSystemType], isAuto = isAuto }
    for _, result in ipairs(Cycle.process(systemState, runCtx, sideName)) do
      result.fields.system = missileSystemType
      report.add(result.tag, result.fields)
    end
  end)

  report.emit({ mode = isAuto and "auto" or "manual" })
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

---Deduct ammunition when a canister stock or resupply vehicle of any missile system is destroyed
---@param config SBJ__Config
---@param saveData SBJ__SaveData
---@param unit CMO__Unit
---@return boolean processed Whether the unit belonged to a missile system and ammo was adjusted
function MissileSystem.processSupplyAssetDestruction(config, saveData, unit)
  local groundState = PersistentState.ground(saveData, unit.side)
  local missileSystemConfigMap = getMissileSystemTypes(config, unit.side)

  for missileSystemType, systemState in pairs(groundState.missileSystemTypes) do
    local success, result = GroundStateStore.processSupplyAssetDestruction(
      unit, missileSystemConfigMap[missileSystemType], systemState
    )

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

---Move batteries to the operational areas submitted by the control panel, then rebuild their zones, units and state
---Only the moved batteries are rebuilt; every other battery keeps its units and runtime state. Config is
---only read. The area a battery leaves comes from its state, so a move after a save/load removes the
---zones the battery really has.
---@param config SBJ__Config
---@param saveData SBJ__SaveData
---@param sideName string
---@param redeployments SBJ__PlacedBattery[]
function MissileSystem.redeployFromControlPanel(config, saveData, sideName, redeployments)
  local missileSystemConfigMap = getMissileSystemTypes(config, sideName)
  local groundState = PersistentState.ground(saveData, sideName)
  local batteries, operationalAreas, operationalAreasToRemove = {}, {}, {}

  for _, redeployment in ipairs(redeployments) do
    local battery = Deployment.resolveBattery(missileSystemConfigMap, redeployment.missileSystemType,
      redeployment.name, PanelBattery.buildOperationalArea(redeployment.placement))
    if battery then
      table.insert(batteries, battery)
      table.insert(operationalAreas, battery.operationalArea)
      table.insert(operationalAreasToRemove,
        GroundStateStore.resolveOperationalArea(groundState, battery.missileSystemType, battery.firing))
    end
  end

  -- PositionZones writes the mask onto the new areas, which resetBatteryStates then copies into state
  PositionZones.rebuild(operationalAreas, operationalAreasToRemove, REDEPLOY_POSITION_TYPES, sideName)
  Deployment.deployBatteries(sideName, batteries)
  GroundStateStore.resetBatteryStates(groundState, batteries)
end

---Build a side's batteries for the control panel, placed where the save says they are
---@param config SBJ__Config
---@param saveData SBJ__SaveData
---@param sideName string
---@return SBJ__PanelBattery[]
function MissileSystem.buildPanelBatteries(config, saveData, sideName)
  return PanelBattery.buildPanelBatteries(
    getMissileSystemTypes(config, sideName),
    PersistentState.ground(saveData, sideName),
    sideName,
    GameApi.ScenEdit_CurrentTime()
  )
end

---Add a side's missile system units and build their runtime states from config
---@param config SBJ__Config
---@param saveData SBJ__SaveData
---@param sideName string
function MissileSystem.deploySide(config, saveData, sideName)
  local batteries = Deployment.resolveBatteries(getMissileSystemTypes(config, sideName))

  Deployment.deployBatteries(sideName, batteries)
  GroundStateStore.resetBatteryStates(PersistentState.ground(saveData, sideName), batteries)
end

---List the firing units of some missile systems as SIGINT emitters, in the order the systems are given
---A firing unit without a runtime state or a config descriptor is left out.
---@param config SBJ__Config
---@param saveData SBJ__SaveData
---@param sideName string Side that owns the firing units
---@param missileSystemTypes string[] Missile system type keys (constants.MISSILE_SYSTEM_TYPES)
---@return SBJ__SigintEmitter[]
function MissileSystem.listSigintEmitters(config, saveData, sideName, missileSystemTypes)
  local missileSystemConfigMap = getMissileSystemTypes(config, sideName)
  local groundState = PersistentState.ground(saveData, sideName)
  local emitters = {}

  for _, missileSystemType in ipairs(missileSystemTypes) do
    local descriptorMap = missileSystemConfigMap[missileSystemType].firingUnits
    for name, firingUnitState in pairs(groundState.missileSystemTypes[missileSystemType].firingUnits) do
      local descriptor = descriptorMap[name]
      if descriptor then
        table.insert(emitters, { name = name, msg = descriptor.msg, operationalArea = firingUnitState.operationalArea })
      end
    end
  end

  return emitters
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

  GroundStateStore.resetBatteryStates(groundState, Deployment.resolveBatteries(getMissileSystemTypes(config, sideName)))
end

---Handle a UnitEntersArea event for the triggering unit's side, with its policy taken from config
---@param config SBJ__Config
---@param saveData SBJ__SaveData
---@param unit CMO__Unit
---@param event CMO__Event
function MissileSystem.processUnitEntersArea(config, saveData, unit, event)
  local policy = config[GameUtils.getCachedSideConfig(unit.side).field].ground.policy

  Arrival.processMoveToPositionEvent({
    missileSystemConfigMap = getMissileSystemTypes(config, unit.side),
    groundState = PersistentState.ground(saveData, unit.side),
    unit = unit,
    event = event,
    contacts = GameApi.ScenEdit_GetContacts(unit.side),
    moveCtx = {
      isAuto = policy.isAuto,
      hideOnEnterHA = policy.hideOnEnterHA,
      hideResupplyOnRLNoMeeting = policy.hideResupplyOnRLNoMeeting
    }
  })
end

return MissileSystem
