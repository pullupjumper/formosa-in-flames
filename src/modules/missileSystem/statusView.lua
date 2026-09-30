local constants = require("src.core.constants")

local StatusView = {}

---Display labels for missile system states
local STATE_LABELS = {
  [constants.MISSILE_SYSTEM_STATE.STATIC] = "STATIC",
  [constants.MISSILE_SYSTEM_STATE.REPOSITIONING] = "REPOSITIONING",
  [constants.MISSILE_SYSTEM_STATE.HIDE] = "HIDE",
  [constants.MISSILE_SYSTEM_STATE.RELOAD] = "RELOAD",
}

---Convert a missile system state enum to its display label
---@param state missileSystemState Missile system state enum value
---@return string # STATIC/REPOSITIONING/HIDE/RELOAD, or UNKNOWN
local function formatState(state)
  return STATE_LABELS[state] or "UNKNOWN"
end

---Calculate minutes elapsed since a reload started
---@param reloadStartTime number|nil Reload start time in seconds, nil when not reloading
---@param currentTime number Current scenario time in seconds
---@return number # Elapsed minutes rounded to 2 decimal places, never negative; 0 when not reloading
local function calculateReloadMinutes(reloadStartTime, currentTime)
  if reloadStartTime == nil then
    return 0
  end

  local minutes = math.floor(((currentTime - reloadStartTime) / 60) * 100 + 0.5) / 100
  if minutes < 0 then
    return 0
  end

  return minutes
end

---Build battery status rows grouped by resupply unit name
---@param groundCtx SBJ__GroundForceContext Side ground force runtime context
---@param missileSystemTypeConfig SBJ__MissileSystemTypeConfig Side ground force configuration
---@param systemTypes string[] Missile system types to include (constants.MISSILE_SYSTEM_TYPES values)
---@param currentTime number Current scenario time in seconds
---@return table<string, SBJ__BatteryStatusRow[]> # Firing unit rows keyed by their resupply unit name
function StatusView.buildBatteryStatusRows(groundCtx, missileSystemTypeConfig, systemTypes, currentTime)
  local rows = {}

  for _, missileSystem in ipairs(systemTypes) do
    local resupplyUnitCtxs = groundCtx[missileSystem] and groundCtx[missileSystem].resupplyUnits

    if resupplyUnitCtxs then
      for key, _ in pairs(resupplyUnitCtxs) do
        rows[key] = {}
      end
    end
  end

  for _, missileSystem in ipairs(systemTypes) do
    local missileSystemCtx = groundCtx[missileSystem]
    local firingUnitCtxs = missileSystemCtx and missileSystemCtx.firingUnits

    if missileSystemCtx and firingUnitCtxs then
      for _, firingUnitCtx in pairs(firingUnitCtxs) do
        local resupplyUnitCtx = missileSystemCtx.resupplyUnits[firingUnitCtx.resupplyUnit]

        table.insert(rows[firingUnitCtx.resupplyUnit], {
          name = firingUnitCtx.name,
          missileSystem = missileSystem,
          firingUnitState = formatState(firingUnitCtx.state),
          resupplyUnitState = formatState(resupplyUnitCtx.state),
          missilesInAmmoVehicles = resupplyUnitCtx.wpnCurrent,
          missilesInAHA = missileSystemCtx.ammunitions[resupplyUnitCtx.ammunition].wpnCurrent,
          firingUnitReloadTime = calculateReloadMinutes(firingUnitCtx.reloadStartTime, currentTime),
          resupplyUnitReloadTime = calculateReloadMinutes(resupplyUnitCtx.reloadStartTime, currentTime),
          defaultReloadTime = missileSystemTypeConfig[missileSystem].reloadTime / 60
        })
      end
    end
  end

  return rows
end

return StatusView
