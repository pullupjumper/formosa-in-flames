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

---@param config SBJ__Config
---@param sideName string
---@return table<string, SBJ__MissileSystemConfig>
local function getMissileSystemTypes(config, sideName)
  return config[GameUtils.getCachedSideConfig(sideName).field].ground.missileSystemTypes
end

---Find a launcher config descriptor by missile system and unit name
---@param config SBJ__Config
---@param sideName string
---@param missileSystemType string Missile system name in any case (e.g., "SRBM", "srbm")
---@param launcherName string
---@return SBJ__LauncherDescriptor|nil # Nil when config has no such system or launcher
local function findLauncherDescriptor(config, sideName, missileSystemType, launcherName)
  local systemConfig = getMissileSystemTypes(config, sideName)[string.lower(missileSystemType)]
  return systemConfig and systemConfig.launchers[launcherName]
end

---Find a launcher runtime state by missile system and unit name
---@param groundState SBJ__GroundState
---@param missileSystemType string Missile system name in any case (e.g., "SRBM", "srbm")
---@param launcherName string
---@return SBJ__LauncherState|nil # Launcher runtime state, or nil when missing
local function findLauncherState(groundState, missileSystemType, launcherName)
  local systemState = groundState.missileSystemTypes[string.lower(missileSystemType)] --[[@as SBJ__MissileSystemState?]]
  return systemState and systemState.launchers and systemState.launchers[launcherName]
end

---Send a launcher from its hide area to its firing point when it is ready
---A unit is ready when it is hiding with enough ammunition; units already out are left alone.
---@param config SBJ__Config
---@param groundState SBJ__GroundState
---@param sideName string Side that owns the launcher
---@param params SBJ__LauncherParams
---@return boolean inPosition Whether the unit is at its firing point
---@return boolean isMissing Whether the unit no longer exists in game, in config or in runtime state
function MissileSystem.sendToFiringPoint(config, groundState, sideName, params)
  local missileSystemType, launcherName = params.missileSystemType, params.launcherName
  local launcher = GameApi.ScenEdit_GetUnit(launcherName)
  local launcherState = findLauncherState(groundState, missileSystemType, launcherName)
  local launcherDescriptor = findLauncherDescriptor(config, sideName, missileSystemType, launcherName)
  if not launcher or not launcherState or not launcherDescriptor then
    return false, true
  end

  local function isLowAmmo()
    return Ammo.isLowAmmo(launcher, launcherDescriptor.ammoThreshold, launcherDescriptor.weaponDBID)
  end

  if Rules.canSendToFiringPoint(launcherState, isLowAmmo) then
    -- A single dispatch, not a report, so each failure is written on its own line.
    local isUnhidden, errorFields = Concealment.moveFromHideArea(launcherState, launcher)
    if not isUnhidden then
      Logger.warn(LogFormat.line("WARN", LogFormat.merge(
        { module = constants.TAGS.MISSILE_SYSTEM, unit = launcherName, action = "unload_from_hide_area" }, errorFields)))
    end

    local departure = Transitions.startMove(launcherState, launcher, Movement.ORDER.FIRING_POINT)
    if departure.tag == "FAIL" then
      Logger.error(LogFormat.line("FAIL", LogFormat.merge({ module = constants.TAGS.MISSILE_SYSTEM }, departure.fields)))
    end
  end

  return Rules.isInPosition(launcherState), false
end

---Calculate ammunition inventory across launcher/transloader/canister stock for a missile system
---@param config SBJ__Config
---@param groundState SBJ__GroundState
---@param sideName string
---@param missileSystemType string Missile system type (constants.MISSILE_SYSTEM_TYPES)
---@return SBJ__AmmoInventoryResult|nil # Inventory report with subtotals and percentages, nil when the system is absent
function MissileSystem.getAmmoInventory(config, groundState, sideName, missileSystemType)
  local systemState = groundState.missileSystemTypes[missileSystemType]
  local systemConfig = getMissileSystemTypes(config, sideName)[missileSystemType]
  if not systemState or not systemConfig then
    return nil
  end

  return Ammo.getInventory(systemConfig, systemState, sideName)
end

---Evaluate whether a launcher can take a fire support task, and why not
---@param config SBJ__Config
---@param groundState SBJ__GroundState
---@param sideName string Side that owns the launcher
---@param params SBJ__EvaluateReadinessParams
---@return missileSystemReadiness
function MissileSystem.evaluateReadiness(config, groundState, sideName, params)
  local missileSystemType, launcherName = params.missileSystemType, params.launcherName
  local readiness = constants.MISSILE_SYSTEM_READINESS
  local launcherState = findLauncherState(groundState, missileSystemType, launcherName)
  local launcherDescriptor = findLauncherDescriptor(config, sideName, missileSystemType, launcherName)
  if not launcherState or not launcherDescriptor then
    return readiness.NO_STATE
  end

  local launcher = params.getUnit(launcherName)
  if not launcher then
    return readiness.UNIT_NOT_FOUND
  end

  return Rules.evaluateReadiness(launcherState, function()
    return Ammo.isLowAmmo(launcher, launcherDescriptor.ammoThreshold, launcherDescriptor.weaponDBID)
  end)
end

---Pair each named launcher with the weapon its config fires
---A name with no config entry is left out.
---@param config SBJ__Config
---@param sideName string
---@param missileSystemType string Missile system name in any case (e.g., "SRBM", "srbm")
---@param launcherNames string[]
---@return SBJ__AttackingUnit[]
function MissileSystem.buildAttackingUnits(config, sideName, missileSystemType, launcherNames)
  local attackingUnits = {}

  for _, launcherName in ipairs(launcherNames) do
    local descriptor = findLauncherDescriptor(config, sideName, missileSystemType, launcherName)
    if descriptor then
      table.insert(attackingUnits, { name = launcherName, weaponDBID = descriptor.weaponDBID --[[@as number]] })
    end
  end

  return attackingUnits
end

---Find the states of a fire task's launchers that leave their position once the task ends
---SAM stays on station to guard the airspace, so it has none.
---@param groundState SBJ__GroundState
---@param missileSystemType string|nil Missile system name in any case (e.g., "SRBM", "srbm")
---@param launcherNames string[]|nil
---@return SBJ__LauncherState[]
local function findLeavingLauncherStates(groundState, missileSystemType, launcherNames)
  local launcherStates = {}
  if not missileSystemType or not launcherNames or Rules.shouldStayDeployed(missileSystemType) then
    return launcherStates
  end

  for _, launcherName in ipairs(launcherNames) do
    local launcherState = findLauncherState(groundState, missileSystemType, launcherName)
    if launcherState then
      table.insert(launcherStates, launcherState)
    end
  end

  return launcherStates
end

---End a fire task that fired: its launchers stow, then the reload cycle sends them back
---A countdown already running is kept.
---@param groundState SBJ__GroundState
---@param missileSystemType string|nil Missile system name in any case (e.g., "SRBM", "srbm")
---@param launcherNames string[]|nil
function MissileSystem.completeFireTask(groundState, missileSystemType, launcherNames)
  for _, launcherState in ipairs(findLeavingLauncherStates(groundState, missileSystemType, launcherNames)) do
    Transitions.startStow(launcherState)
  end
end

---End a fire task that never fired: only launchers already out of their hide area stow
---A countdown already running is kept.
---@param groundState SBJ__GroundState
---@param missileSystemType string|nil Missile system name in any case (e.g., "SRBM", "srbm")
---@param launcherNames string[]|nil
function MissileSystem.abortFireTask(groundState, missileSystemType, launcherNames)
  for _, launcherState in ipairs(findLeavingLauncherStates(groundState, missileSystemType, launcherNames)) do
    if Rules.isDeployed(launcherState) then
      Transitions.startStow(launcherState)
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

---Deduct ammunition when a canister stock or transloader vehicle of any missile system is destroyed
---@param config SBJ__Config
---@param saveData SBJ__SaveData
---@param unit CMO__Unit
---@return boolean processed Whether the unit belonged to a missile system and ammo was adjusted
function MissileSystem.processSupplyAssetDestruction(config, saveData, unit)
  local groundState = PersistentState.ground(saveData, unit.side)
  local missileSystemConfigMap = getMissileSystemTypes(config, unit.side)

  for missileSystemType, systemState in pairs(groundState.missileSystemTypes) do
    local success, result = GroundStateStore.updateSupplyAssetAmmo(
      unit, missileSystemConfigMap[missileSystemType], systemState
    )

    -- A destroyed unit belongs to at most one system, so the first match ends the search.
    if success and result then
      Logger.log(constants.TAGS.MISSILE_SYSTEM, LogFormat.line(result.tag, {
        system = result.system,
        action = "supply_asset_destroyed",
        role = result.role,
        unit = result.unitName,
        unitState = result.unitStateName,
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
function MissileSystem.deployFromControlPanel(config, saveData, sideName, redeployments)
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
        GroundStateStore.resolveOperationalArea(groundState, battery.missileSystemType, battery.launcher))
    end
  end

  -- PositionZones writes the mask onto the new areas, which resetBatteryStates then copies into state
  PositionZones.update(sideName, operationalAreas, operationalAreasToRemove, REDEPLOY_POSITION_TYPES)
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
---Each battery goes where it stands now: a battery the control panel moved has no zones left at its config
---area, so it is added at its saved area and only a never-deployed battery uses its config area.
---@param config SBJ__Config
---@param saveData SBJ__SaveData
---@param sideName string
function MissileSystem.deploySide(config, saveData, sideName)
  local groundState = PersistentState.ground(saveData, sideName)
  local batteries = Deployment.resolveBatteries(getMissileSystemTypes(config, sideName))

  for _, battery in ipairs(batteries) do
    battery.operationalArea = GroundStateStore.resolveOperationalArea(
      groundState, battery.missileSystemType, battery.launcher
    )
  end

  Deployment.deployBatteries(sideName, batteries)
  GroundStateStore.resetBatteryStates(groundState, batteries)
end

---List the launchers of some missile systems as SIGINT emitters, in the order the systems are given
---A launcher without a runtime state or a config descriptor is left out.
---@param config SBJ__Config
---@param saveData SBJ__SaveData
---@param sideName string Side that owns the launchers
---@param missileSystemTypes string[] Missile system type keys (constants.MISSILE_SYSTEM_TYPES)
---@return SBJ__SigintEmitter[]
function MissileSystem.buildSigintEmitters(config, saveData, sideName, missileSystemTypes)
  local missileSystemConfigMap = getMissileSystemTypes(config, sideName)
  local groundState = PersistentState.ground(saveData, sideName)
  local emitters = {}

  for _, missileSystemType in ipairs(missileSystemTypes) do
    local descriptorMap = missileSystemConfigMap[missileSystemType].launchers
    for name, launcherState in pairs(groundState.missileSystemTypes[missileSystemType].launchers) do
      local descriptor = descriptorMap[name]
      if descriptor then
        table.insert(emitters, { name = name, msg = descriptor.msg, operationalArea = launcherState.operationalArea })
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
function MissileSystem.processArrival(config, saveData, unit, event)
  local policy = config[GameUtils.getCachedSideConfig(unit.side).field].ground.policy

  Arrival.process({
    missileSystemConfigMap = getMissileSystemTypes(config, unit.side),
    groundState = PersistentState.ground(saveData, unit.side),
    unit = unit,
    event = event,
    contacts = GameApi.ScenEdit_GetContacts(unit.side),
    runCtx = {
      isAuto = policy.isAuto,
      hideOnEnterHA = policy.hideOnEnterHA,
      hideTransloaderOnRLNoMeeting = policy.hideTransloaderOnRLNoMeeting
    }
  })
end

return MissileSystem
