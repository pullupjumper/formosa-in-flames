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
  [constants.SIDES.ENEMY] = {
    side = constants.SIDES.PLAYER,
    systems = { SYSTEMS.SRBM, SYSTEMS.GLCM, SYSTEMS.MLRS, SYSTEMS.ASCM },
    iadsNodes = { "rocc", "taaoc" },
  },
  US = {
    side = constants.SIDES.ENEMY,
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

---China fixed-target list built at init by the strike planner
---@param state SBJ__SaveData
---@return SBJ__TargetEntry[]
function PersistentState.targetlist(state)
  return state.c.targetlist
end

---China recon slice
---@param state SBJ__SaveData
---@return SBJ__ReconContext
function PersistentState.recon(state)
  return state.c.recon
end

---China CSG land-attack cruise missile slice
---@param state SBJ__SaveData
---@return SBJ__LACMContext
function PersistentState.lacm(state)
  return state.c.surface.lacm
end

---Runway repair slice for a side
---@param state SBJ__SaveData
---@param sideName string China or Taiwan
---@return SBJ__RunwayRepairmentContext
function PersistentState.runwayRepair(state, sideName)
  return state[GameUtils.getCachedSideConfig(sideName).field].repairRunway
end

---Land-based aircraft slice for a side
---@param state SBJ__SaveData
---@param sideName string China or Taiwan
---@return SBJ__LandBasedPlatformContext
function PersistentState.landBasedAircraft(state, sideName)
  return state[GameUtils.getCachedSideConfig(sideName).field].air.landBased
end

---Ground force (missile system) slice for a side
---@param state SBJ__SaveData
---@param sideName string China or Taiwan
---@return SBJ__GroundForceContext|SBJ__StrikingGroundForceContext
function PersistentState.groundForces(state, sideName)
  return state[GameUtils.getCachedSideConfig(sideName).field].ground
end

---SIGINT slice for a collecting side
---@param state SBJ__SaveData
---@param sideName string China or US
---@return SBJ__SIGINTContext
function PersistentState.sigint(state, sideName)
  return state[GameUtils.getCachedSideConfig(sideName).field].sigint
end

---Enemy unit context groups a SIGINT collector monitors
---@param state SBJ__SaveData
---@param collectorSide string China or US
---@return table<string, SBJ__FiringUnitContext|SBJ__C2Context>[]
function PersistentState.sigintEmitters(state, collectorSide)
  local targets = SIGINT_TARGETS[collectorSide]
  local enemy = state[GameUtils.getCachedSideConfig(targets.side).field]
  local groups = {}

  for _, system in ipairs(targets.systems) do
    table.insert(groups, enemy.ground[system].firingUnits)
  end
  for _, node in ipairs(targets.iadsNodes) do
    table.insert(groups, enemy.iads[node])
  end

  return groups
end

---IADS slice for a side
---@param state SBJ__SaveData
---@param sideName string China or Taiwan
---@return SBJ__IADSContext
function PersistentState.iads(state, sideName)
  return state[GameUtils.getCachedSideConfig(sideName).field].iads
end

---GNSS jammer contexts for a side, indexed by jammer name
---@param state SBJ__SaveData
---@param sideName string China or Taiwan
---@return table<string, SBJ__GNSSJammerContext>
function PersistentState.gnssJammers(state, sideName)
  return state[GameUtils.getCachedSideConfig(sideName).field].gnssJamming.jammers
end

---Slices China comms jamming reads and mutates: own jammers, Taiwan IADS and aircraft
---@param state SBJ__SaveData
---@return SBJ__CommsJammingState
function PersistentState.commsJamming(state)
  local taiwanAircraft = PersistentState.landBasedAircraft(state, constants.SIDES.PLAYER)
  return {
    enabled = state.c.commsJamming.enabled,
    jammers = state.c.commsJamming.jammers,
    iads = PersistentState.iads(state, constants.SIDES.PLAYER),
    aircraft = taiwanAircraft.AC,
    aew = taiwanAircraft.AEW,
  }
end

---Slices landing operations read and mutate: China amphibious state, recon, and ground forces
---@param state SBJ__SaveData
---@return SBJ__LandingOpsState
function PersistentState.landingOps(state)
  return {
    amphibOps = state.c.amphibOps,
    recon = PersistentState.recon(state),
    ground = PersistentState.groundForces(state, constants.SIDES.ENEMY),
  }
end

---Slices the China strike planner reads and mutates: targets, recon, dynamic operations,
---ATO, FSP, cruise missile salvos, and the landing ops fire-support hold
---@param state SBJ__SaveData
---@return SBJ__StrikePlannerState
function PersistentState.strikePlanner(state)
  local china = state.c
  return {
    targetlist = PersistentState.targetlist(state),
    transmissions = PersistentState.sigint(state, constants.SIDES.ENEMY).transmissions,
    recon = PersistentState.recon(state),
    dynamicOperations = china.dynamicOperations,
    air = china.air,
    ground = PersistentState.groundForces(state, constants.SIDES.ENEMY),
    lacm = PersistentState.lacm(state),
    slcm = china.subSurface.slcm,
    fireSupportOnHold = china.amphibOps.fireSupportOnHold == true,
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
