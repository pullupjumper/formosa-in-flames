local constants = require("src.core.constants")
local GameApi = require("src.utils.gameApi")

---Provide live-test shortcuts for the amphibious flow (config.red.amphibOps.debug).
---Fast-forward the phases before debug.startStage: ships teleport and timed waits are skipped.
---Every earlier phase still runs, so the later phases get the state they need.
local DebugFlow = {}

---Check if the given phase must be fast-forwarded
---@param amphibOps SBJ__AmphibOpsConfig
---@param phase string One of constants.AMPHIBIOUS_PHASES
---@return boolean # True if the phase must be fast-forwarded. False when debug is off; true for every phase when startStage is unset
function DebugFlow.isFastForward(amphibOps, phase)
  local debug = amphibOps.debug
  if not debug or not debug.enabled then
    return false
  end
  if not debug.startStage then
    return true
  end
  return constants.AMPHIBIOUS_PHASE_ORDER[phase] < constants.AMPHIBIOUS_PHASE_ORDER[debug.startStage]
end

---Check if hovercraft and ACVs teleport to their parking slot instead of sailing
---@param amphibOps SBJ__AmphibOpsConfig
---@return boolean # True if hovercraft and ACVs teleport to their parking slot
function DebugFlow.isLandingTeleport(amphibOps)
  local debug = amphibOps.debug
  return debug ~= nil and debug.enabled == true and debug.teleportLanding == true
end

---Teleport a unit to a location
---@param guid string
---@param location CMO__Location
function DebugFlow.teleport(guid, location)
  GameApi.ScenEdit_SetUnit({ guid = guid, latitude = location.latitude, longitude = location.longitude })
end

return DebugFlow
