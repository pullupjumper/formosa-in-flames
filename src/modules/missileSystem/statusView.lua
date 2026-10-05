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

---Build one status per battery (a firing unit plus its paired resupply unit)
---@param groundCtx SBJ__GroundContext Side ground force runtime context
---@param missileSystemConfigMap table<string,SBJ__MissileSystemConfig> Side ground force configuration
---@param currentTime number Current scenario time in seconds
---@return SBJ__BatteryStatus[] # One status per battery
function StatusView.buildBatteryStatuses(groundCtx, missileSystemConfigMap, currentTime)
  local statuses = {}

  for missileSystemType, missileSystemCtx in pairs(groundCtx.missileSystemTypes) do
    local firingUnitCtxs = missileSystemCtx.firingUnits

    if firingUnitCtxs then
      for _, firingUnitCtx in pairs(firingUnitCtxs) do
        local resupplyUnitCtx = missileSystemCtx.resupplyUnits[firingUnitCtx.resupplyUnit]

        table.insert(statuses, {
          name = firingUnitCtx.name,
          missileSystemType = missileSystemType,
          firingUnitState = formatState(firingUnitCtx.state),
          resupplyUnitState = formatState(resupplyUnitCtx.state),
          missilesInAmmoVehicles = resupplyUnitCtx.weaponCountCurrent,
          missilesInAHA = missileSystemCtx.ammunitions[resupplyUnitCtx.ammunition].weaponCountCurrent,
          firingUnitReloadTime = calculateReloadMinutes(firingUnitCtx.reloadStartTime, currentTime),
          resupplyUnitReloadTime = calculateReloadMinutes(resupplyUnitCtx.reloadStartTime, currentTime),
          defaultReloadTime = missileSystemConfigMap[missileSystemType].reloadTime / 60
        })
      end
    end
  end

  return statuses
end

return StatusView
