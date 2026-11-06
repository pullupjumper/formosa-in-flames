local constants = require("src.core.constants")

local StatusView = {}

---Display labels for missile system states
local STATE_LABELS = {
  [constants.MISSILE_UNIT_POSTURE.STATIC] = "STATIC",
  [constants.MISSILE_UNIT_POSTURE.REPOSITIONING] = "REPOSITIONING",
  [constants.MISSILE_UNIT_POSTURE.HIDE] = "HIDE",
  [constants.MISSILE_UNIT_POSTURE.RELOAD] = "RELOAD",
}

---Convert a missile system state enum to its display label
---@param state missileUnitPosture
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
    local systemConfig = missileSystemConfigMap[missileSystemType]
    local firingUnitStates = missileSystemState.firingUnits

    if firingUnitStates then
      for name, firingUnitState in pairs(firingUnitStates) do
        local firingUnitDescriptor = systemConfig.firingUnits[name]
        if firingUnitDescriptor then
          -- Config pairs every firing unit with a resupply unit and its canister stock, and every
          -- deploy sets the states of all three
          local resupplyUnitDescriptor = systemConfig.resupplyUnits[firingUnitDescriptor.resupplyUnit]
          local canisterStockDescriptor = systemConfig.canisterStocks[resupplyUnitDescriptor.canisterStock]
          local resupplyUnitState = missileSystemState.resupplyUnits[resupplyUnitDescriptor.name]
          local canisterStockState = missileSystemState.canisterStocks[canisterStockDescriptor.name]

          table.insert(statuses, {
            name = firingUnitState.name,
            missileSystemType = missileSystemType,
            firingPosture = formatState(firingUnitState.state),
            resupplyPosture = formatState(resupplyUnitState.state),
            resupplyMissiles = resupplyUnitState.weaponCountCurrent,
            resupplyMissilesDefault = resupplyUnitDescriptor.weaponCountDefault,
            canisterMissiles = canisterStockState.weaponCountCurrent,
            canisterMissilesDefault = canisterStockDescriptor.weaponCountDefault,
            firingReloadMinutes = calculateReloadMinutes(firingUnitState.reloadStartTime, currentTime),
            resupplyReloadMinutes = calculateReloadMinutes(resupplyUnitState.reloadStartTime, currentTime),
            reloadMinutesDefault = systemConfig.reloadTime / 60
          })
        end
      end
    end
  end

  return statuses
end

return StatusView
