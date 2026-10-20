local GameApi = require("src.utils.gameApi")

---Limit each zone's living ACVs to the brigade size per type. Release the ACVs in waves.
---Record launched GUIDs at once, so ships that trigger in the same tick share the quota.
local AcvWave = {}

---Remove destroyed ACV GUIDs and return the number of ACVs that remain
---@param guids string[]
---@return integer
local function removeDestroyed(guids)
  for i = #guids, 1, -1 do
    if not GameApi.ScenEdit_GetUnit(guids[i]) then
      table.remove(guids, i)
    end
  end
  return #guids
end

---Calculate the remaining quota for one ACV type. The quota pauses at zero and resumes on losses or timeout
---@param zoneState SBJ__ZoneState
---@param key string ACV type key (zbd05, ztd05)
---@param config SBJ__AcvZoneWaveConfig
---@param currentTime number
---@return integer
local function calculateTypeQuota(zoneState, key, config, currentTime)
  local capacity = config.capacity[key] or 0
  zoneState.acvGuids[key] = zoneState.acvGuids[key] or {}
  local alive = removeDestroyed(zoneState.acvGuids[key])
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

---Build the wave config of one zone: the shared wave tuning plus the zone's own alive cap per type
---@param tuning SBJ__AcvWaveConfig
---@param zone SBJ__OperationalZoneDescriptor
---@return SBJ__AcvZoneWaveConfig
function AcvWave.buildZoneWaveConfig(tuning, zone)
  return {
    capacity = zone.landing.acv.capacity,
    lossRatio = tuning.lossRatio,
    holdSec = tuning.holdSec,
    hovercraftWaitSec = tuning.hovercraftWaitSec,
  }
end

---Get the remaining ACV quota per type for this zone at the current time
---@param zoneState SBJ__ZoneState
---@param config SBJ__AcvZoneWaveConfig
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

---Check if the first ACV wave is full. This lets hovercraft go.
---The wave is full when every type filled to capacity or the wait timed out.
---The wait starts at the first call. The result stays true after it becomes true.
---@param zoneState SBJ__ZoneState
---@param config SBJ__AcvZoneWaveConfig
---@param currentTime number
---@return boolean # True once the first wave filled every type or the wait timed out
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
    if removeDestroyed(guids) < capacity then
      return false
    end
  end

  zoneState.acvFirstWaveFull = true
  return true
end

---Add a launched ACV so it counts against the quota
---@param zoneState SBJ__ZoneState
---@param key string ACV type key
---@param guid string
function AcvWave.addACV(zoneState, key, guid)
  zoneState.acvGuids = zoneState.acvGuids or {}
  zoneState.acvGuids[key] = zoneState.acvGuids[key] or {}
  table.insert(zoneState.acvGuids[key], guid)
end

return AcvWave
