local constants = require("src.core.constants")
local GameApi = require("src.utils.gameApi")
local GameUtils = require("src.utils.gameUtils")
local LogFormat = require("src.utils.logFormat")
local Logger = require("src.utils.logger")
local AmphibiousLogistics = require("src.modules.landingOps.amphibiousLogistics")
local DebugFlow = require("src.modules.landingOps.debugFlow")
local RoutePlanner = require("src.modules.landingOps.routePlanner")
local TrackedUnits = require("src.modules.landingOps.trackedUnits")

---Everything about the amphibious combat vehicles (ZBD-05, ZTD-05): ship cargo, spawning and lane courses.
---Limit each zone's living ACVs to the brigade size per type. Release the ACVs in waves.
---Record launched GUIDs at once, so ships that trigger in the same tick share the quota.
local AcvWave = {}

---@type {name: string, dbid: number, key: string}[]
local ACV_TYPES = {
  { name = "ZBD-05", dbid = constants.PLATFORMS.ZBD05, key = "zbd05" },
  { name = "ZTD-05", dbid = constants.PLATFORMS.ZTD05, key = "ztd05" },
}

AcvWave.ACV_TYPES = ACV_TYPES

---Remove the ACVs that are no longer found and return the number of ACVs that remain.
---TrackedUnits removes each one from guids and from every other record of the zone
---@param zoneState SBJ__ZoneState
---@param guids string[]
---@return integer
local function removeMissingACVs(zoneState, guids)
  for i = #guids, 1, -1 do
    TrackedUnits.removeMissing(zoneState, guids[i])
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
  local alive = removeMissingACVs(zoneState, zoneState.acvGuids[key])
  local pausedAt = zoneState.acvPausedAt[key]

  if pausedAt then
    local hasLosses = alive < capacity * (1 - config.lossRatio)
    local hasTimedOut = currentTime - pausedAt >= config.holdSec
    if not hasLosses and not hasTimedOut then
      return 0
    end
    zoneState.acvPausedAt[key] = nil
  end

  local quota = math.max(math.floor(capacity - alive), 0)
  if quota == 0 then
    zoneState.acvPausedAt[key] = currentTime
  end
  return quota
end

---Build the wave config of one zone: the shared wave settings plus the zone's own alive cap per type
---@param waveConfig SBJ__AcvWaveConfig
---@param zone SBJ__OperationalZoneDescriptor
---@return SBJ__AcvZoneWaveConfig
function AcvWave.buildZoneWaveConfig(waveConfig, zone)
  return {
    capacity = zone.landing.acv.capacity,
    lossRatio = waveConfig.lossRatio,
    holdSec = waveConfig.holdSec,
    hovercraftWaitSec = waveConfig.hovercraftWaitSec,
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
    if removeMissingACVs(zoneState, guids) < capacity then
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

---Build the per-ACV course callback. It plans a course through the cleared lanes to a parking slot
---and counts the ACV against the wave quota. It falls back to the zone destination when no lane has room.
---@param amphibOps SBJ__AmphibOpsConfig
---@param zone SBJ__OperationalZoneDescriptor
---@param zoneState SBJ__ZoneState
---@return fun(unit: CMO__Unit, acvKey: string): CMO__Location[]|nil
local function buildACVRouter(amphibOps, zone, zoneState)
  return function(unit, acvKey)
    AcvWave.addACV(zoneState, acvKey, unit.guid)

    local plan = RoutePlanner.reserveCourse(zoneState, {
      guid = unit.guid,
      launchPos = { latitude = unit.latitude, longitude = unit.longitude },
      routeConfig = amphibOps.route,
    })

    if not plan then
      Logger.warn(LogFormat.line("WARN", { zone = zone.name, unit = unit.guid, reason = "no_cleared_lane_slot" }))
      return zone.landing.acv.destination
    end

    if DebugFlow.isLandingTeleport(amphibOps) then
      DebugFlow.teleport(unit.guid, plan.course[#plan.course])
      return nil
    end

    return plan.course
  end
end

---Count the cargo items of one DBID aboard a ship
---@param ship CMO__Unit
---@param dbid number
---@return integer
local function countCargo(ship, dbid)
  local cargos = ship.cargo and ship.cargo[1] and ship.cargo[1].cargo or {}
  local count = 0
  for _, element in ipairs(cargos) do
    if element.dbid == dbid then
      count = count + 1
    end
  end
  return count
end

---Remove cargo from a ship by priority for ACV deployment.
---Iterate ACV_TYPES in order. Give each type at most its own quota.
---@param ship CMO__Unit
---@param totalNum number
---@param quota table<string, integer> Remaining quota per ACV type key
---@return SBJ__AcvAllocation[] # Allocation array
local function removeCargoByPriority(ship, totalNum, quota)
  local allocations = {}
  local remaining = totalNum

  for _, acvType in ipairs(ACV_TYPES) do
    if remaining <= 0 then break end
    local num = math.min(remaining, quota[acvType.key] or 0)
    local deleted = AmphibiousLogistics.removeCargo(ship, { type = 2, num = num, dbid = acvType.dbid })
    if deleted > 0 then
      table.insert(allocations, { acvType = acvType, count = deleted })
      remaining = remaining - deleted
    end
  end

  return allocations
end

---Create a single ACV unit at the given location
---@param acvType SBJ__AcvType
---@param location CMO__Location
---@param routeACV fun(unit: CMO__Unit, acvKey: string): CMO__Location[]
---@return SBJ__LogResult # Deferred log result describing the outcome
local function createSingleACV(acvType, location, routeACV)
  local addedUnit = GameApi.ScenEdit_AddUnit({
    side = constants.SIDES.RED,
    type = "Vehicle",
    name = acvType.name,
    dbid = acvType.dbid,
    latitude = location.latitude,
    longitude = location.longitude,
  })

  if not addedUnit then
    return { tag = "FAIL", fields = { unit = acvType.name, reason = "add_unit_failed" } }
  end

  local doctrine = GameApi.ScenEdit_SetDoctrine({ guid = addedUnit.guid }, { automatic_evasion = "no" })

  if not doctrine then
    return { tag = "FAIL", fields = { unit = acvType.name, reason = "set_doctrine_failed" } }
  end

  addedUnit.throttle = "Full"
  addedUnit.course = routeACV(addedUnit, acvType.key)
  return {
    tag = "OK",
    fields = {
      unit = acvType.name,
      lat = string.format("%.4f", location.latitude),
      lon = string.format("%.4f", location.longitude)
    }
  }
end

---Create every allocated ACV. Stop at the first failure
---@param allocations SBJ__AcvAllocation[]
---@param locations CMO__Location[]
---@param routeACV fun(unit: CMO__Unit, acvKey: string): CMO__Location[]
---@return integer|nil count ACVs launched, nil when a spawn failed
---@return SBJ__LogResult[] results Deferred log results in emission order
local function createAllocatedACVs(allocations, locations, routeACV)
  local results = {}
  local index = 0

  for _, allocation in ipairs(allocations) do
    for _ = 1, allocation.count do
      index = index + 1
      local result = createSingleACV(allocation.acvType, locations[index], routeACV)
      table.insert(results, result)

      if result.tag == "FAIL" then
        return nil, results
      end
    end
  end

  return index, results
end

---Create ZBD-05 and ZTD-05 amphibious vehicles abreast of the ship, within the per-type quota
---@param params SBJ__ACVDeploymentParams
---@return SBJ__LaunchACVResult|nil # nil when the ship is missing or destroyed
local function spawnACVs(params)
  local ship = params.ship
  if not ship or ship.IsDestroyed then return end

  local hasCargo, hasQuotaForCargo = false, false
  for _, acvType in ipairs(ACV_TYPES) do
    if countCargo(ship, acvType.dbid) > 0 then
      hasCargo = true
      hasQuotaForCargo = hasQuotaForCargo or (params.quota[acvType.key] or 0) > 0
    end
  end

  if not hasCargo then
    return { count = 0, isEmpty = true, isPaused = false }
  end
  if not hasQuotaForCargo then
    return { count = 0, isEmpty = false, isPaused = true }
  end

  local acvLocations = GameUtils.buildLocations({
    initialLocation = { latitude = ship.latitude, longitude = ship.longitude },
    num = params.num,
    bearing = params.bearing,
    distance = params.distance
  })

  local allocations = removeCargoByPriority(ship, params.num, params.quota)
  local count, results = createAllocatedACVs(allocations, acvLocations, params.routeACV)

  local report = LogFormat.report(
    constants.TAGS.AMPHIBIOUS_ASSAULT, "ship=" .. (ship.name or ship.guid), "Launch ACV")
  report.addAll(results)
  report.emit()

  return { count = count, isEmpty = false, isPaused = false }
end

---Check if a ship still carries any ZBD-05 or ZTD-05
---@param ship CMO__Unit
---@return boolean # True if some ACV cargo is left aboard
function AcvWave.hasCargo(ship)
  for _, acvType in ipairs(ACV_TYPES) do
    if countCargo(ship, acvType.dbid) > 0 then
      return true
    end
  end
  return false
end

---Release one batch of ACVs from a ship within the zone's wave quota.
---Each ACV gets a course through the cleared lanes and counts against the quota at once.
---@param amphibOps SBJ__AmphibOpsConfig
---@param zone SBJ__OperationalZoneDescriptor
---@param zoneState SBJ__ZoneState
---@param ship CMO__Unit
---@return SBJ__LaunchACVResult|nil # nil when the ship is missing or destroyed
function AcvWave.release(amphibOps, zone, zoneState, ship)
  return spawnACVs({
    ship = ship,
    num = amphibOps.acvWave.launchBatchSize,
    bearing = zone.heading,
    distance = amphibOps.formation.acvSpacingNm,
    quota = AcvWave.getQuota(
      zoneState,
      AcvWave.buildZoneWaveConfig(amphibOps.acvWave, zone),
      GameApi.ScenEdit_CurrentTime()
    ),
    routeACV = buildACVRouter(amphibOps, zone, zoneState),
  })
end

return AcvWave
