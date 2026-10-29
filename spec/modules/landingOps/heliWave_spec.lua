---@diagnostic disable: need-check-nil, assign-type-mismatch, cast-local-type, param-type-mismatch, inject-field
-- LandingOps HeliWave Unit Tests
local HeliWave = require("src.modules.landingOps.heliWave")
local TrackedUnits = require("src.modules.landingOps.trackedUnits")
local LaneGeometry = require("src.modules.landingOps.laneGeometry")
local GameApi = require("src.utils.gameApi")
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

  local TRANSPORT_DBID, ATTACK_DBID, AIRLIFT_DBID = 1001, 1002, 1003
  local FRAME = { origin = { latitude = 25.0, longitude = 121.0 }, bearing = 150 }
  local ARRIVED, FAR = 0.1, 50

  ---@type table<string, table>
  local units
  ---@type table<string, number>
  local ranges
  -- Scenario clock readings: before and after every wave launch time
  local BEFORE_LAUNCH, AFTER_LAUNCH = 0, 4102444800
  local stubGetUnit, stubUnload, stubCurrentTime, stubAddMission, stubAssign

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

  ---Add `transportCount` loaded transports and `attackCount` attack helicopters on one mothership.
  ---A later call with another prefix replaces the helicopters aboard, as if the earlier ones had flown off.
  ---@param transportCount integer
  ---@param attackCount integer
  ---@param prefix? string Prefix of the GUIDs, to tell fleets apart
  ---@return string[] transportGuids
  ---@return string[] attackGuids
  local function addFleet(transportCount, attackCount, prefix)
    prefix = prefix or ""
    local embarked, transportGuids, attackGuids = {}, {}, {}
    for i = 1, transportCount do
      local guid = prefix .. "T" .. i
      addHeli(guid, true)
      table.insert(embarked, guid)
      table.insert(transportGuids, guid)
    end
    for i = 1, attackCount do
      local guid = prefix .. "A" .. i
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
          waveSize = 8,
          escortSize = 4,
          waveTimeoutSec = 1800,
          arrivalNm = 0.5,
          casAssignNm = 3,
          cruiseSpeedKt = 130,
          cruiseAltitudeM = 304,
          wingOffsetM = 8000,
          inlandEntryM = 3000,
          landingSpreadM = 500,
          airlift = {
            size = 3,
            delaySec = 600,
            cruiseSpeedKt = 400,
            cruiseAltitudeM = 3000,
            arrivalNm = 1,
          },
        },
      },
    }
    for k, v in pairs(overrides or {}) do
      amphibOps.tuning.heliWave[k] = v
    end
    return amphibOps
  end

  ---@return SBJ__OperationalZoneDescriptor
  local function buildZone()
    return {
      name = "Taoyuan",
      movement = { holdingAreas = { mothership = { "RP-M" } } },
      air = {
        transportHelicopter = { dbid = TRANSPORT_DBID, zone = { "RP-L" } },
        attackHelicopter = { dbid = ATTACK_DBID, zone = { "RP-CAS" } },
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

  ---A zone with a land-based transport aircraft group on top of the helicopters
  ---@return SBJ__OperationalZoneDescriptor
  local function buildAirliftZone()
    local zone = buildZone()
    zone.air.transportAircraft = { name = "TBASE", guid = "TBASE", dbid = AIRLIFT_DBID, cargoItemsForTransfer = {} }
    return zone
  end

  -- 100 km seaward of the lane origin
  local TRANSPORT_BASE_POS = LaneGeometry.buildPoint(FRAME, -100000, 0)

  ---Add the transport aircraft base (their home airfield) with loaded aircraft aboard. A later call replaces the aircraft aboard
  ---@param count integer
  ---@param prefix? string Prefix of the GUIDs, to tell batches apart
  ---@return string[] guids
  local function addTransportBase(count, prefix)
    prefix = prefix or ""
    local guids = {}
    for i = 1, count do
      local guid = prefix .. "AIRLIFT" .. i
      addUnit(guid, { dbid = AIRLIFT_DBID, cargo = { { cargo = { { dbid = 1 } } } } })
      table.insert(guids, guid)
    end
    addUnit("TBASE", {
      latitude = TRANSPORT_BASE_POS.latitude,
      longitude = TRANSPORT_BASE_POS.longitude,
      embarkedUnits = { [constants.PLATFORM_TYPES.AIRCRAFT] = guids },
    })
    return guids
  end

  local SHIPS = { { guid = "SHIP-1" } }

  ---@param currentTime number
  ---@return SBJ__LandingTickContext
  local function buildCtx(currentTime)
    return { config = { red = { amphibOps = buildAmphibOps() } }, filteredShips = SHIPS, currentTime = currentTime }
  end

  ---Count the launched helicopters by role and wing, read from the courses they were given
  ---@return table<string, integer>
  local function countLaunched()
    local counts = {}
    for _, unit in pairs(units) do
      if unit.course then
        local _, lateral = LaneGeometry.projectPoint(FRAME, unit.course[1])
        local key = (unit.dbid == TRANSPORT_DBID and "transport" or "attack") ..
            "/" .. (lateral < 0 and "left" or "right")
        counts[key] = (counts[key] or 0) + 1
      end
    end
    return counts
  end

  ---Schedule the first wave and run one tick that launches it
  ---@return SBJ__ZoneState
  local function buildLaunchedZoneState()
    local zoneState = buildZoneState()
    HeliWave.schedule(buildCtx(1000), buildZone(), zoneState)
    HeliWave.update(buildCtx(1000), buildZone(), zoneState)
    return zoneState
  end

  ---Schedule an airlift zone and run one tick that launches the first batch
  ---@return SBJ__ZoneState
  local function buildLaunchedAirliftZoneState()
    local zoneState = buildZoneState()
    HeliWave.schedule(buildCtx(1000), buildAirliftZone(), zoneState)
    HeliWave.update(buildCtx(1000), buildAirliftZone(), zoneState)
    return zoneState
  end

  ---Destroy helicopters: the game no longer finds them
  ---@param guids string[]
  local function destroyAll(guids)
    for _, guid in ipairs(guids) do
      units[guid] = nil
    end
  end

  before_each(function()
    activeStubs = {}
    units, ranges = {}, {}
    trackStub(stub(Logger, "log"))
    trackStub(stub(Logger, "warn"))
    trackStub(stub(Logger, "error"))
    stubGetUnit = trackStub(stub(GameApi, "ScenEdit_GetUnit", function(guid) return units[guid] end))
    trackStub(stub(GameApi, "Tool_Range", function(guid) return ranges[guid] or FAR end))
    stubUnload = trackStub(stub(GameApi, "ScenEdit_UnloadCargo"))
    stubAddMission = trackStub(stub(GameApi, "ScenEdit_AddMission", function() return {} end))
    stubAssign = trackStub(stub(GameApi, "ScenEdit_AssignUnitToMission").returns(true))
    stubCurrentTime = trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(AFTER_LAUNCH))
    trackStub(stub(GameApi, "ScenEdit_GetReferencePoints").returns({
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

  describe("schedule", function()
    it("should plan the first wave before the boats reach the shore", function()
      addFleet(8, 4)
      local carrierPos = LaneGeometry.buildPoint(FRAME, -20 * 1852, 0)
      addUnit("CARRIER", { latitude = carrierPos.latitude, longitude = carrierPos.longitude })
      local zoneState = buildZoneState({ boats = { B1 = { shipGuid = "CARRIER" } } })

      HeliWave.schedule(buildCtx(1000), buildZone(), zoneState)

      -- By hand: the carrier sails 16 nm at 14 kt (1.14 h), its boats run 3.95 nm at 30 kt (0.13 h),
      -- so they reach the shore at about 1000 + 4588 = 5588 s. The helicopters must leave after now and before that.
      local launchAt = zoneState.heliWave.launchAt
      assert.is_true(launchAt > 1000)
      assert.is_true(launchAt < 5588)
    end)

    it("should create one CAS mission over the zone's CAS area", function()
      addFleet(8, 4)

      HeliWave.schedule(buildCtx(1000), buildZone(), buildZoneState())

      assert.stub(stubAddMission).was.called(1)
      assert.stub(stubAddMission).was.called_with(
        constants.SIDES.RED, "CAS/HELI/TAOYUAN", "patrol", { type = "land", zone = { "RP-CAS" } })
    end)

    it("should launch right away when no boat is paired", function()
      addFleet(8, 4)
      local zoneState = buildZoneState()

      HeliWave.schedule(buildCtx(1000), buildZone(), zoneState)

      assert.are.equal(1000, zoneState.heliWave.launchAt)
    end)
  end)

  describe("update launch", function()
    it("should do nothing before the wave plan exists", function()
      addFleet(8, 4)
      local zoneState = buildZoneState()

      HeliWave.update(buildCtx(1000), buildZone(), zoneState)

      assert.is_nil(zoneState.heliWave)
      assert.spy(units.T1.Launch).was_not.called()
    end)

    it("should not launch before the planned launch time, then launch once it is reached", function()
      addFleet(8, 4)
      local zoneState = buildZoneState()
      HeliWave.schedule(buildCtx(1000), buildZone(), zoneState)
      stubCurrentTime.returns(BEFORE_LAUNCH)

      HeliWave.update(buildCtx(1000), buildZone(), zoneState)
      assert.spy(units.T1.Launch).was_not.called()

      stubCurrentTime.returns(AFTER_LAUNCH)
      HeliWave.update(buildCtx(1010), buildZone(), zoneState)
      assert.spy(units.T1.Launch).was.called(1)
    end)

    it("should launch 8 transports and 4 escorts split across both wings", function()
      addFleet(10, 6)

      buildLaunchedZoneState()

      assert.same({
        ["transport/left"] = 4,
        ["transport/right"] = 4,
        ["attack/left"] = 2,
        ["attack/right"] = 2,
      }, countLaunched())
    end)

    it("should launch fewer helicopters when fewer are available", function()
      addFleet(3, 1)

      buildLaunchedZoneState()

      assert.same({
        ["transport/left"] = 2, ["transport/right"] = 1, ["attack/left"] = 1,
      }, countLaunched())
    end)

    it("should give each wing its own course that ends beside the landing point", function()
      addFleet(2, 0)

      buildLaunchedZoneState()

      -- The landing point is 5500 m along the lane, the wing spread is 500 m to each side
      local leftCourse, rightCourse = units.T1.course, units.T2.course
      if select(2, LaneGeometry.projectPoint(FRAME, leftCourse[1])) > 0 then
        leftCourse, rightCourse = rightCourse, leftCourse
      end
      assert.are.equal(3, #leftCourse)
      local leftAlong, leftLateral = LaneGeometry.projectPoint(FRAME, leftCourse[3])
      local rightAlong, rightLateral = LaneGeometry.projectPoint(FRAME, rightCourse[3])
      assert.is_near(5500, leftAlong, 5)
      assert.is_near(5500, rightAlong, 5)
      assert.is_near(-500, leftLateral, 5)
      assert.is_near(500, rightLateral, 5)
      assert.spy(units.T1.Launch).was.called_with(match.is_table(), true)
    end)

    it("should skip transports without cargo and wait for a loaded one", function()
      addFleet(2, 2)
      units.T1.cargo = { { cargo = {} } }
      units.T2.cargo = { { cargo = {} } }

      buildLaunchedZoneState()

      assert.spy(units.A1.Launch).was_not.called()
    end)

    it("should skip helicopters that are not ready", function()
      addFleet(2, 0)
      units.T1.readytime_v = 600

      buildLaunchedZoneState()

      assert.same({ ["transport/left"] = 1 }, countLaunched())
    end)
  end)

  describe("update progress", function()
    it("should unload only the transport that reaches its landing point", function()
      addFleet(2, 0)
      local zoneState = buildLaunchedZoneState()
      ranges.T1 = ARRIVED

      HeliWave.update(buildCtx(1010), buildZone(), zoneState)

      assert.stub(stubUnload).was.called(1)
      assert.stub(stubUnload).was.called_with("T1")
      assert.spy(units.T1.RTB).was_not.called()
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
      units.T1.cargo = nil
      HeliWave.update(buildCtx(1030), buildZone(), zoneState)
      assert.spy(units.T1.RTB).was.called(1)
      assert.spy(units.T1.RTB).was.called_with(match.is_table(), true)
    end)

    it("should assign an attack helicopter to the CAS mission within the threshold, and not before", function()
      addFleet(1, 2)
      local zoneState = buildLaunchedZoneState()
      ranges.A1 = 3.5

      HeliWave.update(buildCtx(1010), buildZone(), zoneState)
      assert.stub(stubAssign).was_not.called()

      ranges.A1 = 2.5
      HeliWave.update(buildCtx(1020), buildZone(), zoneState)
      assert.stub(stubAssign).was.called(1)
      assert.stub(stubAssign).was.called_with("A1", "CAS/HELI/TAOYUAN")
      HeliWave.update(buildCtx(1030), buildZone(), zoneState)
      assert.stub(stubAssign).was.called(1)
    end)

    it("should never send an assigned attack helicopter home, even after the transports are done", function()
      addFleet(1, 1)
      local zoneState = buildLaunchedZoneState()
      ranges.A1, ranges.T1 = 2, ARRIVED
      HeliWave.update(buildCtx(1010), buildZone(), zoneState)

      units.T1.condition = constants.UNIT_CONDITIONS.UNDERWAY
      units.T1.cargo = nil
      HeliWave.update(buildCtx(1020), buildZone(), zoneState)

      assert.spy(units.T1.RTB).was.called(1)
      assert.spy(units.A1.RTB).was_not.called()
    end)

    it("should still assign an attack helicopter after the transports are done", function()
      addFleet(1, 1)
      local zoneState = buildLaunchedZoneState()
      destroyAll({ "T1" })
      HeliWave.update(buildCtx(1010), buildZone(), zoneState)
      ranges.A1 = 2

      HeliWave.update(buildCtx(1020), buildZone(), zoneState)

      assert.spy(units.A1.RTB).was_not.called()
      assert.stub(stubAssign).was.called_with("A1", "CAS/HELI/TAOYUAN")
    end)

    it("should treat a destroyed transport as done", function()
      addFleet(1, 1)
      local zoneState = buildLaunchedZoneState()
      addFleet(1, 0, "R")
      destroyAll({ "T1" })

      HeliWave.update(buildCtx(1010), buildZone(), zoneState)

      assert.spy(units.RT1.Launch).was.called(1)
    end)

    it("should look up a transport or attack helicopter that is no longer found only once", function()
      addFleet(2, 1)
      local zoneState = buildLaunchedZoneState()
      destroyAll({ "T1", "A1" })
      stubGetUnit:clear()

      HeliWave.update(buildCtx(1010), buildZone(), zoneState)
      HeliWave.update(buildCtx(1020), buildZone(), zoneState)

      assert.stub(stubGetUnit).was.called_with("T1")
      assert.stub(stubGetUnit).was.called_with("A1")
      local lookups = { T1 = 0, A1 = 0 }
      for _, call in ipairs(stubGetUnit.calls) do
        local guid = call.vals[1]
        if lookups[guid] then lookups[guid] = lookups[guid] + 1 end
      end
      assert.are.same({ T1 = 1, A1 = 1 }, lookups)
    end)
  end)

  describe("update next wave", function()
    it("should not launch the next wave while a helicopter is still out", function()
      local firstWave = addFleet(2, 0)
      local zoneState = buildLaunchedZoneState()
      addFleet(2, 0, "R")
      destroyAll({ firstWave[1] })

      HeliWave.update(buildCtx(1500), buildZone(), zoneState)

      assert.spy(units.RT1.Launch).was_not.called()
    end)

    it("should launch the next wave once every helicopter is homebound or destroyed", function()
      local firstWave = addFleet(2, 0)
      local zoneState = buildLaunchedZoneState()
      addFleet(2, 0, "R")
      destroyAll(firstWave)

      HeliWave.update(buildCtx(1500), buildZone(), zoneState)

      assert.spy(units.RT1.Launch).was.called(1)
    end)

    it("should recall the wave and launch the next one after the timeout", function()
      addFleet(2, 2)
      local zoneState = buildLaunchedZoneState()
      local firstWave = { units.T1, units.T2 }
      addFleet(1, 0, "R")

      HeliWave.update(buildCtx(1000 + 1799), buildZone(), zoneState)
      assert.spy(firstWave[1].RTB).was_not.called()

      HeliWave.update(buildCtx(1000 + 1800), buildZone(), zoneState)
      for _, heli in ipairs(firstWave) do
        assert.spy(heli.RTB).was.called(1)
      end
      assert.spy(units.RT1.Launch).was.called(1)
    end)

    it("should not let an unassigned attack helicopter hold back the next wave", function()
      addFleet(2, 1)
      local zoneState = buildLaunchedZoneState()
      addFleet(1, 0, "R")
      destroyAll({ "T1", "T2" })

      HeliWave.update(buildCtx(1500), buildZone(), zoneState)

      assert.spy(units.RT1.Launch).was.called(1)
    end)

    it("should top the attack helicopters up to four across waves, and stop at four", function()
      addFleet(2, 3)
      local zoneState = buildLaunchedZoneState()
      assert.same({ ["attack/left"] = 2, ["attack/right"] = 1, ["transport/left"] = 1, ["transport/right"] = 1 },
        countLaunched())
      destroyAll({ "T1", "T2", "A1" })
      TrackedUnits.remove(zoneState, "A1")
      addFleet(2, 5, "R")

      HeliWave.update(buildCtx(1500), buildZone(), zoneState)

      -- 2 attackers still alive, so only 2 more are launched
      local launched = 0
      for guid, unit in pairs(units) do
        if guid:sub(1, 2) == "RA" and unit.course then launched = launched + 1 end
      end
      assert.are.equal(2, launched)
    end)

    it("should launch no attack helicopter when four are already counted", function()
      addFleet(2, 4)
      local zoneState = buildLaunchedZoneState()
      destroyAll({ "T1", "T2" })
      addFleet(2, 4, "R")

      HeliWave.update(buildCtx(1500), buildZone(), zoneState)

      assert.spy(units.RT1.Launch).was.called(1)
      assert.spy(units.RA1.Launch).was_not.called()
    end)
  end)

  describe("after TrackedUnits.remove", function()
    it("should drop the attack helicopter record so it no longer counts", function()
      addFleet(2, 2)
      local zoneState = buildLaunchedZoneState()
      assert.is_not_nil(zoneState.heliWave.attackers.A1)

      assert.is_true(TrackedUnits.remove(zoneState, "A1"))

      assert.is_nil(zoneState.heliWave.attackers.A1)
      assert.is_not_nil(zoneState.heliWave.attackers.A2)
      assert.is_not_nil(zoneState.heliWave.units.T1)
    end)

    it("should end the wave like a kill and stop querying a removed transport helicopter", function()
      addFleet(2, 0)
      local zoneState = buildLaunchedZoneState()
      destroyAll({ "T1", "T2" })
      addFleet(1, 0, "R")

      assert.is_true(TrackedUnits.remove(zoneState, "T1"))
      assert.is_true(TrackedUnits.remove(zoneState, "T2"))
      assert.is_nil(zoneState.heliWave.units.T1)
      ---@diagnostic disable-next-line: undefined-field
      stubGetUnit:clear()
      HeliWave.update(buildCtx(1500), buildZone(), zoneState)

      assert.spy(units.RT1.Launch).was.called(1)
      assert.spy(stubGetUnit).was_not.called_with("T1")
    end)

    it("should end the batch like a kill and stop querying a removed transport aircraft", function()
      addFleet(2, 0)
      addTransportBase(1)
      local zoneState = buildLaunchedAirliftZoneState()
      destroyAll({ "AIRLIFT1" })
      addTransportBase(1, "B2")

      assert.is_true(TrackedUnits.remove(zoneState, "AIRLIFT1"))
      assert.is_nil(zoneState.heliWave.airlift.units.AIRLIFT1)
      assert.is_not_nil(zoneState.heliWave.units.T1)
      ---@diagnostic disable-next-line: undefined-field
      stubGetUnit:clear()
      HeliWave.update(buildCtx(1500), buildAirliftZone(), zoneState)

      assert.spy(units.B2AIRLIFT1.Launch).was.called(1)
      assert.spy(stubGetUnit).was_not.called_with("AIRLIFT1")
    end)

    it("should return false for a GUID with no record, or a zone without a wave plan", function()
      addFleet(2, 0)
      local zoneState = buildLaunchedZoneState()

      assert.is_false(TrackedUnits.remove(zoneState, "NOPE"))
      assert.is_false(TrackedUnits.remove(buildZoneState(), "A1"))
    end)
  end)

  describe("airlift", function()
    ---Lateral side of a course: negative = left wing
    local function lateralOf(unit)
      local _, lateral = LaneGeometry.projectPoint(FRAME, unit.course[1])
      return lateral
    end

    describe("schedule", function()
      it("should plan the batch to arrive delaySec after the boats, minus its own flight time", function()
        addFleet(8, 4)
        addTransportBase(3)
        local zoneState = buildZoneState()

        HeliWave.schedule(buildCtx(1000), buildAirliftZone(), zoneState)

        -- By hand, no boat paired: the boats run in 3.95 nm at 30 kt (474 s), so T = 1474. Left wing: 103310 m to the turn point (3000 m inland, 8000 m left),
        -- then 7906 m to the landing point (5500 m, 500 m left) = 111216 m = 60.05 nm = 540 s at 400 kt.
        -- Launch = 1474 + 600 - 540 = 1534.
        assert.is_near(1534, zoneState.heliWave.airlift.launchAt, 3)
        assert.are.equal(0, zoneState.heliWave.airlift.waveIndex)
      end)

      it("should launch at once when the flight is longer than the delay", function()
        addTransportBase(3)
        local zoneState = buildZoneState()
        local ctx = buildCtx(1000)
        ctx.config.red.amphibOps.tuning.heliWave.airlift.delaySec = 0

        HeliWave.schedule(ctx, buildAirliftZone(), zoneState)

        assert.are.equal(1000, zoneState.heliWave.airlift.launchAt)
      end)

      it("should not plan an airlift when the zone has no transport aircraft", function()
        addTransportBase(3)
        local zoneState = buildZoneState()

        HeliWave.schedule(buildCtx(1000), buildZone(), zoneState)

        assert.is_nil(zoneState.heliWave.airlift)
      end)
    end)

    describe("launch", function()
      it("should wait for its launch time", function()
        local aircraft = addTransportBase(3)
        local zoneState = buildZoneState()
        HeliWave.schedule(buildCtx(1000), buildAirliftZone(), zoneState)
        stubCurrentTime.returns(BEFORE_LAUNCH)

        HeliWave.update(buildCtx(1000), buildAirliftZone(), zoneState)
        assert.spy(units[aircraft[1]].Launch).was_not.called()

        stubCurrentTime.returns(AFTER_LAUNCH)
        HeliWave.update(buildCtx(1010), buildAirliftZone(), zoneState)
        assert.spy(units[aircraft[1]].Launch).was.called(1)
      end)

      it("should launch at most size ready, loaded aircraft, split across both wings", function()
        addTransportBase(6)
        units.AIRLIFT1.readytime_v = 600
        units.AIRLIFT2.cargo = { { cargo = {} } }

        buildLaunchedAirliftZoneState()

        local flown = {}
        for guid, unit in pairs(units) do
          if unit.dbid == AIRLIFT_DBID and unit.course then
            table.insert(flown, guid)
          end
        end
        assert.are.equal(3, #flown)
        assert.is_nil(units.AIRLIFT1.course)
        assert.is_nil(units.AIRLIFT2.course)
        local lefts = 0
        for _, guid in ipairs(flown) do
          lefts = lefts + (lateralOf(units[guid]) < 0 and 1 or 0)
        end
        assert.is_true(lefts == 1 or lefts == 2)
      end)

      it("should send each aircraft on the two inland points, without a sideways leg", function()
        addTransportBase(2)

        buildLaunchedAirliftZoneState()

        local course = units.AIRLIFT1.course
        assert.are.equal(2, #course)
        local turnAlong, turnLateral = LaneGeometry.projectPoint(FRAME, course[1])
        local landAlong = LaneGeometry.projectPoint(FRAME, course[2])
        assert.is_near(3000, turnAlong, 5)
        assert.is_near(8000, math.abs(turnLateral), 5)
        assert.is_near(5500, landAlong, 5)
        assert.are.equal(3000, course[1].desiredAltitude)
        assert.spy(units.AIRLIFT1.Launch).was.called_with(match.is_table(), true)
        assert.are.equal(constants.THROTTLES.MILITARY, units.AIRLIFT1.throttle)
      end)

      it("should skip aircraft of another type", function()
        addTransportBase(1)
        addUnit("OTHER", { dbid = 9999, cargo = { { cargo = { { dbid = 1 } } } } })
        table.insert(units.TBASE.embarkedUnits[constants.PLATFORM_TYPES.AIRCRAFT], "OTHER")

        buildLaunchedAirliftZoneState()

        assert.is_nil(units.OTHER.course)
      end)

      it("should wait for the next tick when no aircraft is loaded", function()
        local aircraft = addTransportBase(1)
        units[aircraft[1]].cargo = { { cargo = {} } }
        local zoneState = buildLaunchedAirliftZoneState()
        assert.are.equal(0, zoneState.heliWave.airlift.waveIndex)

        units[aircraft[1]].cargo = { { cargo = { { dbid = 1 } } } }
        HeliWave.update(buildCtx(1010), buildAirliftZone(), zoneState)

        assert.are.equal(1, zoneState.heliWave.airlift.waveIndex)
        assert.spy(units[aircraft[1]].Launch).was.called(1)
      end)

      it("should not be held back by the helicopters, nor hold them back", function()
        local firstHelis = addFleet(2, 0)
        addTransportBase(1)
        local zoneState = buildLaunchedAirliftZoneState()
        assert.spy(units.T1.Launch).was.called(1)
        assert.spy(units.AIRLIFT1.Launch).was.called(1)

        -- The helicopters finish while the airlift is still out: the next helicopter wave goes
        addFleet(1, 0, "R")
        destroyAll(firstHelis)
        HeliWave.update(buildCtx(1500), buildAirliftZone(), zoneState)
        assert.spy(units.RT1.Launch).was.called(1)

        -- The airlift finishes while the next helicopters are still out: the next batch goes
        addTransportBase(1, "B2")
        destroyAll({ "AIRLIFT1" })
        HeliWave.update(buildCtx(1600), buildAirliftZone(), zoneState)
        assert.spy(units.B2AIRLIFT1.Launch).was.called(1)
        assert.spy(units.RT1.RTB).was_not.called()
      end)
    end)

    describe("progress", function()
      it("should unload on arrival, and go home only once unloaded", function()
        addTransportBase(2)
        local zoneState = buildLaunchedAirliftZoneState()
        ranges.AIRLIFT1 = ARRIVED

        HeliWave.update(buildCtx(1010), buildAirliftZone(), zoneState)
        assert.stub(stubUnload).was.called(1)
        assert.stub(stubUnload).was.called_with("AIRLIFT1")

        units.AIRLIFT1.condition = constants.UNIT_CONDITIONS.TRANSFERRING_CARGO
        HeliWave.update(buildCtx(1020), buildAirliftZone(), zoneState)
        assert.spy(units.AIRLIFT1.RTB).was_not.called()

        units.AIRLIFT1.condition = constants.UNIT_CONDITIONS.UNDERWAY
        units.AIRLIFT1.cargo = nil
        HeliWave.update(buildCtx(1030), buildAirliftZone(), zoneState)
        assert.spy(units.AIRLIFT1.RTB).was.called(1)
        assert.spy(units.AIRLIFT2.RTB).was_not.called()
      end)

      it("should use the airlift arrival distance, not the helicopter one", function()
        addTransportBase(1)
        local zoneState = buildLaunchedAirliftZoneState()
        ranges.AIRLIFT1 = 0.8

        HeliWave.update(buildCtx(1010), buildAirliftZone(), zoneState)

        assert.stub(stubUnload).was.called_with("AIRLIFT1")
      end)
    end)

    describe("next batch", function()
      it("should hold the next batch while an aircraft is still out", function()
        addTransportBase(2)
        local zoneState = buildLaunchedAirliftZoneState()
        addTransportBase(1, "B2")
        destroyAll({ "AIRLIFT1" })

        HeliWave.update(buildCtx(1500), buildAirliftZone(), zoneState)

        assert.spy(units.B2AIRLIFT1.Launch).was_not.called()
      end)

      it("should launch the next batch once every aircraft is destroyed or homebound", function()
        addTransportBase(2)
        local zoneState = buildLaunchedAirliftZoneState()
        ranges.AIRLIFT1 = ARRIVED
        HeliWave.update(buildCtx(1010), buildAirliftZone(), zoneState)
        units.AIRLIFT1.condition = constants.UNIT_CONDITIONS.UNDERWAY
        units.AIRLIFT1.cargo = nil
        HeliWave.update(buildCtx(1020), buildAirliftZone(), zoneState)
        addTransportBase(1, "B2")
        destroyAll({ "AIRLIFT2" })

        HeliWave.update(buildCtx(1030), buildAirliftZone(), zoneState)

        assert.spy(units.B2AIRLIFT1.Launch).was.called(1)
        assert.are.equal(2, zoneState.heliWave.airlift.waveIndex)
      end)

      it("should recall the batch and launch the next one after the timeout", function()
        addTransportBase(2)
        local zoneState = buildLaunchedAirliftZoneState()
        local first = { units.AIRLIFT1, units.AIRLIFT2 }
        addTransportBase(1, "B2")

        HeliWave.update(buildCtx(1000 + 1799), buildAirliftZone(), zoneState)
        assert.spy(first[1].RTB).was_not.called()

        HeliWave.update(buildCtx(1000 + 1800), buildAirliftZone(), zoneState)
        for _, aircraft in ipairs(first) do
          assert.spy(aircraft.RTB).was.called(1)
        end
        assert.spy(units.B2AIRLIFT1.Launch).was.called(1)
      end)
    end)
  end)
end)
