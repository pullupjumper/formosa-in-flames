local constants = require("src.core.constants")

local FireSupportGate = {}

---Phases in which the fleet has arrived at the staging waters
---@type table<string, true>
local ARRIVED_PHASES = {
  [constants.AMPHIBIOUS_PHASES.WAITING_ASSAULT]          = true,
  [constants.AMPHIBIOUS_PHASES.MINE_CLEARING]            = true,
  [constants.AMPHIBIOUS_PHASES.BOAT_ASSAULT]             = true,
  [constants.AMPHIBIOUS_PHASES.OBSTACLE_CLEARING]        = true,
  [constants.AMPHIBIOUS_PHASES.ASSAULT_LANDING]          = true,
  [constants.AMPHIBIOUS_PHASES.WAITING_ADMIN_OFFLOADING] = true,
  [constants.AMPHIBIOUS_PHASES.COMPLETED]                = true,
}

---Check whether all configured operational zones have reached staging waters
---@param config SBJ__Config
---@param amphibOps SBJ__AmphibOpsState
---@return boolean # True when every zone's phase is at WAITING_ASSAULT or beyond
local function hasAllZonesArrived(config, amphibOps)
  for _, zone in ipairs(config.red.amphibOps.zones) do
    local zoneState = amphibOps.zoneStates[zone.name]
    if not zoneState or not ARRIVED_PHASES[zoneState.phase] then
      return false
    end
  end
  return true
end

---Evaluate the fire support gate from the SRBM ammo level and the fleet arrival status.
---The hold starts when ammo drops below the threshold while at least one zone has not arrived.
---The hold ends when every zone reaches WAITING_ASSAULT or later. The phase machine only moves forward,
---so the hold stays released.
---@param config SBJ__Config
---@param landingState SBJ__LandingOpsState
---@param getAmmoInventory fun(config: SBJ__Config, ground: SBJ__GroundState, sideName: string, missileType: string): SBJ__AmmoInventoryResult|nil # Only called while the gate can still change
---@return SBJ__LogResult|nil # Set when the gate switched between hold and resume
function FireSupportGate.evaluate(config, landingState, getAmmoInventory)
  local amphib = landingState.amphibOps
  local arrived = hasAllZonesArrived(config, amphib)

  if amphib.fireSupportOnHold and arrived then
    amphib.fireSupportOnHold = false
    return { tag = "RESUME", fields = { scope = "fireSupportGate", reason = "all_zones_at_staging_waters" } }
  end

  if amphib.fireSupportOnHold or arrived then
    return nil
  end

  local report = landingState.ground and getAmmoInventory(
    config,
    landingState.ground,
    constants.SIDES.RED,
    constants.MISSILE_SYSTEM_TYPES.SRBM
  )
  if not report then return nil end

  if report.total.percentage < config.red.amphibOps.fireSupport.srbmHoldAmmoPct then
    amphib.fireSupportOnHold = true
    return {
      tag = "HOLD",
      fields = {
        scope = "fireSupportGate",
        reason = "srbm_low",
        total = report.total.percentage,
        threshold = config.red.amphibOps.fireSupport.srbmHoldAmmoPct,
        launcher = report.launcher.percentage,
        transloader = report.transloader.percentage,
        canisterStock = report.canisterStock.percentage
      }
    }
  end

  return nil
end

return FireSupportGate
