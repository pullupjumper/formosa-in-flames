local gKH = require("src.core.gKH_State_Standalone")
local Logger = require("src.utils.logger")
local GameUtils = require("src.utils.gameUtils")
local constants = require("src.core.constants")

---Sole owner of the SaveData key: every load is paired with its save here,
---so event scripts cannot forget to persist what they mutated.
local PersistentState = {}

local SAVE_KEY = "SaveData"

local SYSTEMS = constants.MISSILE_SYSTEM_TYPES

---Enemy unit groups each SIGINT collector listens to, in collection order
local SIGINT_TARGETS = {
  [constants.SIDES.RED] = {
    side = constants.SIDES.BLUE,
    systems = { SYSTEMS.SRBM, SYSTEMS.GLCM, SYSTEMS.MLRS, SYSTEMS.ASCM },
    iadsNodes = { "rocc", "taaoc" },
  },
  [constants.SIDES.ALLY] = {
    side = constants.SIDES.RED,
    systems = { SYSTEMS.MLRS, SYSTEMS.SRBM, SYSTEMS.GLCM },
    iadsNodes = { "c2" },
  },
}

---@return SBJ__SaveData|nil
local function load()
  local state = gKH.State.LoadTableFromKey(SAVE_KEY)
  if state == nil then
    Logger.error("saveData is nil")
  end
  return state
end

---Load state, run fn against it, then save it back
---@param fn fun(state: SBJ__SaveData)
---@return boolean ran False when no saved state exists (fn not called)
function PersistentState.update(fn)
  local state = load()
  if state == nil then
    return false
  end

  fn(state)
  gKH.State.SaveTableToKey(state, SAVE_KEY)
  return true
end

---Overwrite the stored state with defaults, discarding any saved progress
---@param defaults SBJ__SaveData
function PersistentState.reset(defaults)
  gKH.State.SaveTableToKey(defaults, SAVE_KEY)
end

---Whether the side's one-time play-mode deployment was already submitted
---@param state SBJ__SaveData
---@param sideName string
---@return boolean
function PersistentState.deploymentLocked(state, sideName)
  return state[GameUtils.getCachedSideConfig(sideName).field].deploymentLocked == true
end

---Mark the side's deployment as submitted so the control panel refuses another one
---@param state SBJ__SaveData
---@param sideName string
function PersistentState.lockDeployment(state, sideName)
  state[GameUtils.getCachedSideConfig(sideName).field].deploymentLocked = true
end

---China fixed-target list built at init by the strike planner
---@param state SBJ__SaveData
---@return SBJ__TargetEntry[]
function PersistentState.targetlist(state)
  return state.red.targetlist
end

---China recon slice
---@param state SBJ__SaveData
---@return SBJ__ReconContext
function PersistentState.recon(state)
  return state.red.recon
end

---China CSG land-attack cruise missile slice
---@param state SBJ__SaveData
---@return SBJ__LACMContext
function PersistentState.lacm(state)
  return state.red.surface.lacm
end

---Runway repair slice for a side
---@param state SBJ__SaveData
---@param sideName string
---@return SBJ__RunwayRepairmentContext
function PersistentState.runwayRepair(state, sideName)
  return state[GameUtils.getCachedSideConfig(sideName).field].repairRunway
end

---Aircraft slice (AC and AEW) for a side
---@param state SBJ__SaveData
---@param sideName string
---@return SBJ__AircraftSliceContext
function PersistentState.aircraft(state, sideName)
  return state[GameUtils.getCachedSideConfig(sideName).field].air
end

---Ground force (missile system) slice for a side
---@param state SBJ__SaveData
---@param sideName string
---@return SBJ__GroundContext|SBJ__StrikingGroundContext
function PersistentState.ground(state, sideName)
  return state[GameUtils.getCachedSideConfig(sideName).field].ground
end

---SIGINT slice for a collecting side
---@param state SBJ__SaveData
---@param sideName string
---@return SBJ__SIGINTContext
function PersistentState.sigint(state, sideName)
  return state[GameUtils.getCachedSideConfig(sideName).field].sigint
end

---Enemy unit context groups a SIGINT collector monitors
---@param state SBJ__SaveData
---@param collectorSide string
---@return table<string, SBJ__FiringUnitContext|SBJ__C2Context>[]
function PersistentState.sigintEmitters(state, collectorSide)
  local targets = SIGINT_TARGETS[collectorSide]
  local enemy = state[GameUtils.getCachedSideConfig(targets.side).field]
  local groups = {}

  for _, system in ipairs(targets.systems) do
    table.insert(groups, enemy.ground.missileSystemTypes[system].firingUnits)
  end
  for _, node in ipairs(targets.iadsNodes) do
    table.insert(groups, enemy.iads[node])
  end

  return groups
end

---IADS slice for a side
---@param state SBJ__SaveData
---@param sideName string
---@return SBJ__IADSContext
function PersistentState.iads(state, sideName)
  return state[GameUtils.getCachedSideConfig(sideName).field].iads
end

---Slices China comms jamming reads and mutates: own jammers, Taiwan IADS and aircraft
---@param state SBJ__SaveData
---@return SBJ__CommsJammingState
function PersistentState.commsJamming(state)
  local blueAircraft = PersistentState.aircraft(state, constants.SIDES.BLUE)
  return {
    enabled = state.red.commsJamming.enabled,
    jammers = state.red.commsJamming.jammers,
    iads = PersistentState.iads(state, constants.SIDES.BLUE),
    aircraft = blueAircraft.ac,
    aew = blueAircraft.aew,
  }
end

---Slices landing operations read and mutate: China amphibious state, recon, and ground forces
---@param state SBJ__SaveData
---@return SBJ__LandingOpsState
function PersistentState.landingOps(state)
  return {
    amphibOps = state.red.amphibOps,
    recon = PersistentState.recon(state),
    ground = PersistentState.ground(state, constants.SIDES.RED),
  }
end

---Slices the red side strike planner reads and mutates: targets, recon, dynamic operations,
---ATO, FSP, cruise missile salvos, and the landing ops fire-support hold
---@param state SBJ__SaveData
---@return SBJ__StrikePlannerState
function PersistentState.strikePlanner(state)
  local red = state.red
  return {
    targetlist = PersistentState.targetlist(state),
    transmissions = PersistentState.sigint(state, constants.SIDES.RED).transmissions,
    recon = PersistentState.recon(state),
    dynamicOperations = red.dynamicOperations,
    air = red.air,
    ground = PersistentState.ground(state, constants.SIDES.RED),
    lacm = PersistentState.lacm(state),
    slcm = red.subSurface.slcm,
    fireSupportOnHold = red.amphibOps.fireSupportOnHold == true,
  }
end

---Load state and run fn against it without saving; mutations are discarded
---@param fn fun(state: SBJ__SaveData)
---@return boolean ran False when no saved state exists (fn not called)
function PersistentState.read(fn)
  local state = load()
  if state == nil then
    return false
  end

  fn(state)
  return true
end

return PersistentState
