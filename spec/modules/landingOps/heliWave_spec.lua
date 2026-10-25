---@diagnostic disable: need-check-nil, assign-type-mismatch, cast-local-type, param-type-mismatch, inject-field
-- LandingOps HeliWave Unit Tests
local HeliWave = require("src.modules.landingOps.heliWave")
local LaneGeometry = require("src.modules.landingOps.laneGeometry")
local GameApi = require("src.utils.gameApi")
local GameUtils = require("src.utils.gameUtils")
local Logger = require("src.utils.logger")
local constants = require("src.core.constants")

describe("HeliWave", function()
  ---@type luassert.spy[]
  local activeStubs
  ---Track and register test stub for automatic cleanup.
  ---@param s any
  ---@return luassert.spy
  local function trackStub(s)
    table.insert(activeStubs, s)
    return s
  end

  local TRANSPORT_DBID, ATTACK_DBID = 1001, 1002
  local FRAME = { origin = { latitude = 25.0, longitude = 121.0 }, bearing = 150 }
  local ARRIVED, FAR = 0.1, 50

  ---@type table<string, table>
  local units
  ---@type table<string, number>
  local ranges
  local stubUnload, stubIsAfter

  ---Register a fake unit that the GetUnit stub can return
  ---@param guid string
  ---@param fields table
  ---@return table
  local function addUnit(guid, fields)
    local unit = {
      guid = guid,
      readytime_v = 0,
      latitude = 25.2,
      longitude = 121.3,
      condition = constants.UNIT_CONDITIONS.AIRBORNE,
      Launch = spy.new(function() end),
      RTB = spy.new(function() end),
    }
    for k, v in pairs(fields) do
      unit[k] = v
    end
    units[guid] = unit
    return unit
  end

  ---Add a loaded transport or an attack helicopter
  ---@param guid string
  ---@param isTransport boolean
  ---@return table
  local function addHeli(guid, isTransport)
    return addUnit(guid, {
      dbid = isTransport and TRANSPORT_DBID or ATTACK_DBID,
      cargo = { { cargo = isTransport and { { dbid = 1 } } or {} } },
    })
  end

  ---Add a mothership that holds the given helicopters
  ---@param helis string[]
  local function addMothership(helis)
    addUnit("SHIP-1", {
      dbid = constants.PLATFORMS.TYPE_075,
      inArea = function() return true end,
      embarkedUnits = { [constants.PLATFORM_TYPES.AIRCRAFT] = helis },
    })
  end

  ---Add `transportCount` loaded transports and `attackCount` attack helicopters on one mothership
  ---@param transportCount integer
  ---@param attackCount integer
  ---@return string[] transportGuids
  ---@return string[] attackGuids
  local function addFleet(transportCount, attackCount)
    local embarked, transportGuids, attackGuids = {}, {}, {}
    for i = 1, transportCount do
      local guid = "T" .. i
      addHeli(guid, true)
      table.insert(embarked, guid)
      table.insert(transportGuids, guid)
    end
    for i = 1, attackCount do
      local guid = "A" .. i
      addHeli(guid, false)
      table.insert(embarked, guid)
      table.insert(attackGuids, guid)
    end
    addMothership(embarked)
    return transportGuids, attackGuids
  end

  ---@param overrides? table
  ---@return SBJ__AmphibOpsConfig
  local function buildAmphibOps(overrides)
    local amphibOps = {
      formation = { shipSpeed = 14 },
      tuning = {
        route = { launchStationFarNm = 4, shoreStandoffM = 100 },
        assaultBoat = { speed = 30 },
        heliWave = {
          waveSize = 8, escortSize = 4, waveTimeoutSec = 1800, arrivalNm = 0.5, cruiseSpeedKt = 130, cruiseAltitudeM = 304,
          wingOffsetM = 8000, inlandEntryM = 3000, landingSpreadM = 500,
        },
      },
    }
    for k, v in pairs(overrides or {}) do
      amphibOps.tuning.heliWave[k] = v
    end
    return amphibOps
  end

  ---@param waveCount? integer
  ---@return SBJ__OperationalZoneDescriptor
  local function buildZone(waveCount)
    local missions = {}
    for i = 1, waveCount or 2 do
      missions[i] = { name = "M" .. i }
    end
    return {
      name = "Taoyuan",
      movement = { holdingAreas = { mothership = { "RP-M" } } },
      air = {
        landingZone = { "RP-L" },
        transportHelicopter = { dbid = TRANSPORT_DBID, missions = missions },
        attackHelicopter = { dbid = ATTACK_DBID },
      },
    }
  end

  ---@param overrides? table
  ---@return SBJ__ZoneState
  local function buildZoneState(overrides)
    local zoneState = {
      phase = constants.AMPHIBIOUS_PHASES.BOAT_ASSAULT,
      lanes = { origin = FRAME.origin, bearing = FRAME.bearing, waterLanes = {} },
    }
    for k, v in pairs(overrides or {}) do
      zoneState[k] = v
    end
    return zoneState
  end

  local SHIPS = { { guid = "SHIP-1" } }

  ---@param currentTime number
  ---@return SBJ__LandingTickContext
  local function buildCtx(currentTime)
    return { config = { red = { amphibOps = buildAmphibOps() } }, filteredShips = SHIPS, currentTime = currentTime }
  end

  ---Count the units of a wave by role and wing
  ---@param state SBJ__HeliWaveState
  ---@return table<string, integer>
  local function countUnits(state)
    local counts = {}
    for _, entry in pairs(state.units) do
      local key = entry.role .. "/" .. entry.wing
      counts[key] = (counts[key] or 0) + 1
    end
    return counts
  end

  ---@return SBJ__ZoneState
  local function buildLaunchedZoneState()
    local zoneState = buildZoneState({
      heliWave = { waveIndex = 0, launchAt = 0, units = {}, isFinished = false },
    })
    HeliWave.update(buildCtx(1000), buildZone(), zoneState)
    return zoneState
  end

  before_each(function()
    activeStubs = {}
    units, ranges = {}, {}
    trackStub(stub(Logger, "log"))
    trackStub(stub(Logger, "warn"))
    trackStub(stub(Logger, "error"))
    trackStub(stub(GameApi, "ScenEdit_GetUnit", function(guid) return units[guid] end))
    trackStub(stub(GameApi, "Tool_Range", function(guid) return ranges[guid] or FAR end))
    stubUnload = trackStub(stub(GameApi, "ScenEdit_UnloadCargo"))
    stubIsAfter = trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
    trackStub(stub(GameUtils, "findAreaLocations").returns({
      LaneGeometry.buildPoint(FRAME, 5000, -200),
      LaneGeometry.buildPoint(FRAME, 6000, 200),
    }))
  end)

  after_each(function()
    for i = #activeStubs, 1, -1 do
      activeStubs[i]:revert()
    end
    activeStubs = {}
  end)

  -- ============================================================================
  -- schedule
  -- ============================================================================

  describe("schedule", function()
    it("should plan the first wave no earlier than now and no later than the boat arrival", function()
      addFleet(8, 4)
      local carrierPos = LaneGeometry.buildPoint(FRAME, -20 * 1852, 0)
      addUnit("CARRIER", { latitude = carrierPos.latitude, longitude = carrierPos.longitude })
      local zoneState = buildZoneState({ boats = { B1 = { shipGuid = "CARRIER" } } })

      HeliWave.schedule(buildCtx(1000), buildZone(), zoneState)

      local sailHours = (20 - 4) / 14
      local runHours = (4 - 100 / 1852) / 30
      local boatArrival = 1000 + (sailHours + runHours) * 3600
      local state = zoneState.heliWave
      assert.are.equal(0, state.waveIndex)
      assert.is_false(state.isFinished)
      assert.same({}, state.units)
      assert.is_true(state.launchAt >= 1000)
      assert.is_true(state.launchAt < boatArrival)
    end)

    it("should launch right away when no boat is paired", function()
      addFleet(8, 4)
      local zoneState = buildZoneState()

      HeliWave.schedule(buildCtx(1000), buildZone(), zoneState)

      assert.are.equal(1000, zoneState.heliWave.launchAt)
    end)
  end)

  -- ============================================================================
  -- update: launch
  -- ============================================================================

  describe("update launch", function()
    it("should do nothing before the wave plan exists", function()
      addFleet(8, 4)
      local zoneState = buildZoneState()

      HeliWave.update(buildCtx(1000), buildZone(), zoneState)

      assert.is_nil(zoneState.heliWave)
      assert.spy(units.T1.Launch).was_not.called()
    end)

    it("should not launch before the planned launch time", function()
      addFleet(8, 4)
      stubIsAfter.returns(false)
      local zoneState = buildZoneState({ heliWave = { waveIndex = 0, launchAt = 5000, units = {}, isFinished = false } })

      HeliWave.update(buildCtx(1000), buildZone(), zoneState)

      assert.are.equal(0, zoneState.heliWave.waveIndex)
      assert.spy(units.T1.Launch).was_not.called()
      assert.stub(stubIsAfter).was.called_with(5000)
    end)

    it("should launch 8 transports and 4 escorts split across both wings", function()
      addFleet(10, 6)
      local zoneState = buildLaunchedZoneState()

      local state = zoneState.heliWave
      assert.are.equal(1, state.waveIndex)
      assert.are.equal(1000, state.waveLaunchedAt)
      assert.same({
        ["transport/left"] = 4, ["transport/right"] = 4,
        ["attack/left"] = 2, ["attack/right"] = 2,
      }, countUnits(state))
    end)

    it("should launch fewer helicopters when fewer are available", function()
      addFleet(3, 1)
      local zoneState = buildLaunchedZoneState()

      assert.same({
        ["transport/left"] = 2, ["transport/right"] = 1, ["attack/left"] = 1,
      }, countUnits(zoneState.heliWave))
    end)

    it("should give each wing its own course that ends on its landing point", function()
      addFleet(2, 0)
      local zoneState = buildLaunchedZoneState()

      local left, right
      for guid, entry in pairs(zoneState.heliWave.units) do
        if entry.wing == "left" then left = { guid = guid, entry = entry } else right = { guid = guid, entry = entry } end
      end
      local leftCourse, rightCourse = units[left.guid].course, units[right.guid].course
      assert.are.equal(3, #leftCourse)
      assert.same(left.entry.landingPoint, leftCourse[3])
      assert.same(right.entry.landingPoint, rightCourse[3])
      local _, leftLateral = LaneGeometry.projectPoint(FRAME, leftCourse[1])
      local _, rightLateral = LaneGeometry.projectPoint(FRAME, rightCourse[1])
      assert.is_true(leftLateral < 0)
      assert.is_true(rightLateral > 0)
      assert.are_not.same(left.entry.landingPoint, right.entry.landingPoint)
      assert.spy(units[left.guid].Launch).was.called(1)
      assert.is_true(units[left.guid].Launch.calls[1].vals[2])
    end)

    it("should skip transports without cargo and wait for a loaded one", function()
      addFleet(2, 2)
      units.T1.cargo = { { cargo = {} } }
      units.T2.cargo = { { cargo = {} } }
      local zoneState = buildZoneState({ heliWave = { waveIndex = 0, launchAt = 0, units = {}, isFinished = false } })

      HeliWave.update(buildCtx(1000), buildZone(), zoneState)

      assert.are.equal(0, zoneState.heliWave.waveIndex)
      assert.spy(units.A1.Launch).was_not.called()
    end)

    it("should skip helicopters that are not ready", function()
      addFleet(2, 0)
      units.T1.readytime_v = 600
      local zoneState = buildLaunchedZoneState()

      assert.same({ ["transport/left"] = 1 }, countUnits(zoneState.heliWave))
    end)
  end)

  -- ============================================================================
  -- update: wave progress
  -- ============================================================================

  describe("update progress", function()
    it("should unload a transport that reaches its landing point and not give it a mission", function()
      addFleet(2, 0)
      local zoneState = buildLaunchedZoneState()
      ranges.T1 = ARRIVED

      HeliWave.update(buildCtx(1010), buildZone(), zoneState)

      assert.stub(stubUnload).was.called(1)
      assert.stub(stubUnload).was.called_with("T1")
      assert.are.equal("unloading", zoneState.heliWave.units.T1.phase)
      assert.are.equal("enroute", zoneState.heliWave.units.T2.phase)
    end)

    it("should send a transport home once it is no longer transferring cargo", function()
      addFleet(2, 0)
      local zoneState = buildLaunchedZoneState()
      ranges.T1 = ARRIVED
      HeliWave.update(buildCtx(1010), buildZone(), zoneState)

      units.T1.condition = constants.UNIT_CONDITIONS.TRANSFERRING_CARGO
      HeliWave.update(buildCtx(1020), buildZone(), zoneState)
      assert.spy(units.T1.RTB).was_not.called()

      units.T1.condition = constants.UNIT_CONDITIONS.UNDERWAY
      HeliWave.update(buildCtx(1030), buildZone(), zoneState)
      assert.spy(units.T1.RTB).was.called(1)
      assert.is_true(units.T1.RTB.calls[1].vals[2])
      assert.are.equal("returning", zoneState.heliWave.units.T1.phase)
    end)

    it("should hold escorts over the landing point until every transport is done", function()
      addFleet(2, 2)
      local zoneState = buildLaunchedZoneState()
      ranges.A1, ranges.A2, ranges.T1 = ARRIVED, ARRIVED, ARRIVED
      HeliWave.update(buildCtx(1010), buildZone(), zoneState)

      assert.are.equal("loitering", zoneState.heliWave.units.A1.phase)
      assert.spy(units.A1.RTB).was_not.called()

      units.T1.condition = constants.UNIT_CONDITIONS.UNDERWAY
      ranges.T2 = ARRIVED
      HeliWave.update(buildCtx(1020), buildZone(), zoneState)
      units.T2.condition = constants.UNIT_CONDITIONS.UNDERWAY
      HeliWave.update(buildCtx(1030), buildZone(), zoneState)
      HeliWave.update(buildCtx(1040), buildZone(), zoneState)

      assert.spy(units.A1.RTB).was.called(1)
      assert.spy(units.A2.RTB).was.called(1)
    end)

    it("should treat a destroyed transport as done", function()
      addFleet(1, 1)
      local zoneState = buildLaunchedZoneState()
      units.T1 = nil

      HeliWave.update(buildCtx(1010), buildZone(), zoneState)

      assert.are.equal("returning", zoneState.heliWave.units.A1.phase)
      assert.spy(units.A1.RTB).was.called(1)
    end)
  end)

  -- ============================================================================
  -- update: next wave
  -- ============================================================================

  describe("update next wave", function()
    ---Finish every helicopter of the current wave
    ---@param zoneState SBJ__ZoneState
    local function finishWave(zoneState)
      for guid, entry in pairs(zoneState.heliWave.units) do
        entry.phase = "returning"
        units[guid] = nil
      end
    end

    it("should not launch the next wave while helicopters are still out", function()
      addFleet(2, 0)
      local zoneState = buildLaunchedZoneState()
      addFleet(2, 0)
      zoneState.heliWave.units.T1.phase = "returning"

      HeliWave.update(buildCtx(1500), buildZone(), zoneState)

      assert.are.equal(1, zoneState.heliWave.waveIndex)
    end)

    it("should launch the next wave once every helicopter is homebound or destroyed", function()
      addFleet(2, 0)
      local zoneState = buildLaunchedZoneState()
      finishWave(zoneState)
      addFleet(2, 0)

      HeliWave.update(buildCtx(1500), buildZone(), zoneState)

      assert.are.equal(2, zoneState.heliWave.waveIndex)
      assert.are.equal(1500, zoneState.heliWave.waveLaunchedAt)
      assert.is_false(zoneState.heliWave.isFinished)
    end)

    it("should recall the wave and launch the next one after the timeout", function()
      addFleet(2, 0)
      local zoneState = buildLaunchedZoneState()
      local oldUnits = { units.T1, units.T2 }
      addFleet(2, 0)
      units.T1, units.T2 = oldUnits[1], oldUnits[2]
      addUnit("T3", { dbid = TRANSPORT_DBID, cargo = { { cargo = { { dbid = 1 } } } } })
      units["SHIP-1"].embarkedUnits[constants.PLATFORM_TYPES.AIRCRAFT] = { "T3" }

      HeliWave.update(buildCtx(1000 + 1800), buildZone(), zoneState)

      assert.spy(oldUnits[1].RTB).was.called(1)
      assert.spy(oldUnits[2].RTB).was.called(1)
      assert.are.equal(2, zoneState.heliWave.waveIndex)
      assert.is_not_nil(zoneState.heliWave.units.T3)
    end)

    it("should finish after the last wave is done and launch nothing more", function()
      addFleet(2, 0)
      local zoneState = buildLaunchedZoneState()
      finishWave(zoneState)
      addFleet(2, 0)
      HeliWave.update(buildCtx(1500), buildZone(), zoneState)
      finishWave(zoneState)
      addFleet(2, 0)

      HeliWave.update(buildCtx(2000), buildZone(), zoneState)

      assert.is_true(zoneState.heliWave.isFinished)
      assert.are.equal(2, zoneState.heliWave.waveIndex)

      HeliWave.update(buildCtx(2500), buildZone(), zoneState)
      assert.are.equal(2, zoneState.heliWave.waveIndex)
    end)
  end)
end)
