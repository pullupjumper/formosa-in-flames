local GameApi = require("src.utils.gameApi")
local constants = require("src.core.constants")

---Live-test shortcuts for the amphibious flow (config.red.amphibOps.debug).
---Phases before debug.startStage are fast-forwarded: ships teleport and timed waits are skipped,
---so every earlier phase still runs and leaves the state the later phases need.
local DebugFlow = {}

---Whether the given phase should be fast-forwarded
---@param amphibOps SBJ__AmphibOpsConfig
---@param phase string One of constants.AMPHIBIOUS_PHASES
---@return boolean # False when debug is off; true for every phase when startStage is unset
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

---Whether hovercraft and ACVs teleport to their parking slot instead of sailing
---@param amphibOps SBJ__AmphibOpsConfig
---@return boolean
function DebugFlow.isLandingTeleport(amphibOps)
  local debug = amphibOps.debug
  return debug ~= nil and debug.enabled and debug.teleportLanding == true
end

---Move a unit straight to a location
---@param guid string
---@param location CMO__Location
function DebugFlow.teleport(guid, location)
  GameApi.ScenEdit_SetUnit({ guid = guid, latitude = location.latitude, longitude = location.longitude })
end

return DebugFlow
