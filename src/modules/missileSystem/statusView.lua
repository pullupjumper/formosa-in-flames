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
---@param state missileSystemState
---@return string # STATIC/REPOSITIONING/HIDE/RELOAD, or UNKNOWN
local function formatState(state)
  return STATE_LABELS[state] or "UNKNOWN"
end

---Calculate minutes elapsed since a reload started
---@param reloadStartTime number|nil Reload start time in seconds, nil when not reloading
---@param currentTime number
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
---@param groundState SBJ__GroundState
---@param missileSystemConfigMap table<string,SBJ__MissileSystemConfig>
---@param currentTime number
---@return SBJ__BatteryStatus[] # One status per battery
function StatusView.buildBatteryStatuses(groundState, missileSystemConfigMap, currentTime)
  local statuses = {}

  for missileSystemType, missileSystemState in pairs(groundState.missileSystemTypes) do
    local firingUnitStates = missileSystemState.firingUnits

    if firingUnitStates then
      for _, firingUnitState in pairs(firingUnitStates) do
        local resupplyUnitState = missileSystemState.resupplyUnits[firingUnitState.resupplyUnit]

        table.insert(statuses, {
          name = firingUnitState.name,
          missileSystemType = missileSystemType,
          firingUnitState = formatState(firingUnitState.state),
          resupplyUnitState = formatState(resupplyUnitState.state),
          missilesInAmmoVehicles = resupplyUnitState.weaponCountCurrent,
          missilesInTransloaderDefault = resupplyUnitState.weaponCountDefault,
          missilesInAHA = missileSystemState.ammunitions[resupplyUnitState.ammunition].weaponCountCurrent,
          missilesInAHADefault = missileSystemState.ammunitions[resupplyUnitState.ammunition].weaponCountDefault,
          firingUnitReloadTime = calculateReloadMinutes(firingUnitState.reloadStartTime, currentTime),
          resupplyUnitReloadTime = calculateReloadMinutes(resupplyUnitState.reloadStartTime, currentTime),
          defaultReloadTime = missileSystemConfigMap[missileSystemType].reloadTime / 60
        })
      end
    end
  end

  return statuses
end

return StatusView
