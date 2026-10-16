local GameApi = require("src.utils.gameApi")

---Limits each zone's living ACVs to brigade size per type and releases them in waves.
---Launched GUIDs are recorded immediately, so ships triggering in the same tick share the quota.
local AcvWave = {}

-- ============================================================================
-- Helpers
-- ============================================================================

---Drop GUIDs of destroyed ACVs and return how many remain
---@param guids string[]
---@return integer
local function pruneDestroyed(guids)
  for i = #guids, 1, -1 do
    if not GameApi.ScenEdit_GetUnit(guids[i]) then
      table.remove(guids, i)
    end
  end
  return #guids
end

---Remaining quota for one ACV type, pausing when it hits zero and resuming on losses or timeout
---@param zoneState SBJ__ZoneState
---@param key string ACV type key (zbd05, ztd05)
---@param config SBJ__AcvWaveConfig
---@param currentTime number
---@return integer
local function calculateTypeQuota(zoneState, key, config, currentTime)
  local capacity = config.capacity[key] or 0
  zoneState.acvGuids[key] = zoneState.acvGuids[key] or {}
  local alive = pruneDestroyed(zoneState.acvGuids[key])
  local pausedAt = zoneState.acvPausedAt[key]

  if pausedAt then
    local hasLosses = alive < capacity * (1 - config.lossRatio)
    local hasTimedOut = currentTime - pausedAt >= config.holdSec
    if not hasLosses and not hasTimedOut then
      return 0
    end
    zoneState.acvPausedAt[key] = nil
  end

  local quota = math.max(capacity - alive, 0)
  if quota == 0 then
    zoneState.acvPausedAt[key] = currentTime
  end
  return quota
end

-- ============================================================================
-- Public API
-- ============================================================================

---Remaining ACV quota per type for this zone at the current time
---@param zoneState SBJ__ZoneState
---@param config SBJ__AcvWaveConfig
---@param currentTime number
---@return table<string, integer> # Quota keyed by ACV type key
function AcvWave.getQuota(zoneState, config, currentTime)
  zoneState.acvGuids = zoneState.acvGuids or {}
  zoneState.acvPausedAt = zoneState.acvPausedAt or {}

  local quota = {}
  for key in pairs(config.capacity) do
    quota[key] = calculateTypeQuota(zoneState, key, config, currentTime)
  end
  return quota
end

---Whether hovercraft may go: the first ACV wave filled every type to capacity, or the wait timed out
---The wait starts at the first call. Latched once true.
---@param zoneState SBJ__ZoneState
---@param config SBJ__AcvWaveConfig
---@param currentTime number
---@return boolean
function AcvWave.isFirstWaveFull(zoneState, config, currentTime)
  if zoneState.acvFirstWaveFull then
    return true
  end

  zoneState.acvWaitStartedAt = zoneState.acvWaitStartedAt or currentTime
  if currentTime - zoneState.acvWaitStartedAt >= config.hovercraftWaitSec then
    zoneState.acvFirstWaveFull = true
    return true
  end

  zoneState.acvGuids = zoneState.acvGuids or {}
  for key, capacity in pairs(config.capacity) do
    local guids = zoneState.acvGuids[key] or {}
    if pruneDestroyed(guids) < capacity then
      return false
    end
  end

  zoneState.acvFirstWaveFull = true
  return true
end

---Record a launched ACV so it counts against the quota
---@param zoneState SBJ__ZoneState
---@param key string ACV type key
---@param guid string
function AcvWave.addACV(zoneState, key, guid)
  zoneState.acvGuids = zoneState.acvGuids or {}
  zoneState.acvGuids[key] = zoneState.acvGuids[key] or {}
  table.insert(zoneState.acvGuids[key], guid)
end

return AcvWave
