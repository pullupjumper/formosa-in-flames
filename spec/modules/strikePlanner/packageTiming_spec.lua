-- PackageTiming Unit Tests
local PackageTiming = require("src.modules.strikePlanner.packageTiming")
local Utils = require("src.utils.utils")
local GameApi = require("src.utils.gameApi")
local TankerMission = require("src.modules.strikePlanner.tankerMission")
local BaseConfig = require("src.core.config")

describe("PackageTiming", function()
  ---@type luassert.spy[]
  local activeStubs

  ---Track and register a test stub for automatic cleanup.
  ---@param s any
  ---@return luassert.spy
  local function trackStub(s)
    table.insert(activeStubs, s)
    return s
  end

  ---Revert every tracked stub so real implementations back subsequent calls.
  local function revertAll()
    for _, s in ipairs(activeStubs) do
      s:revert()
    end
    activeStubs = {}
  end

  -- ============================================================================
  -- Shared Constants
  -- ============================================================================

  -- Numeric anchor the datetime stub maps every schedule string to.
  local ANCHOR = 1770000000
  -- Placeholder datetime string; its literal value is irrelevant under the stub.
  local ANCHOR_STR = "2026-02-14 00:00:00"
  local TIMING = BaseConfig.c.air.timing

  -- ============================================================================
  -- Shared Mock Data Builders
  -- ============================================================================

  ---Create a striker deployment descriptor with defaults; overrides replace fields.
  local function makeStriker(overrides)
    local striker = { baseGUID = "BASE-1", unitCount = 2, unitDBID = 100, weaponDBID = 200 }
    if overrides then
      for k, v in pairs(overrides) do striker[k] = v end
    end
    return striker
  end

  ---Create a package template with a striker and a single target; overrides replace top-level fields.
  local function makePackage(overrides)
    local pkg = {
      timeToReady = 0,
      striker = makeStriker(),
      target = { list = { "TGT-1" } }
    }
    if overrides then
      for k, v in pairs(overrides) do pkg[k] = v end
    end
    return pkg
  end

  ---Create the typed config expected by createPackageWithTiming.
  ---@return SBJ__Config
  local function makeConfig()
    return Utils.deepCopy(BaseConfig) --[[@as SBJ__Config]]
  end

  ---Stub every GameApi/Utils/TankerMission dependency the timing chain touches.
  ---@param opts table|nil currentTime, anchor, range, weapon, point, tankerMissions overrides
  local function stubDependencies(opts)
    opts = opts or {}
    trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(opts.currentTime or 1000))
    trackStub(stub(GameApi, "Tool_Range").returns(opts.range or 450))
    trackStub(stub(GameApi, "ScenEdit_QueryDB").returns(
      opts.weapon == nil and { ranges = { land = { max = 50 } } } or opts.weapon or nil
    ))
    trackStub(stub(GameApi, "ScenEdit_GetReferencePoint").returns(
      opts.point or { latitude = 25.0, longitude = 121.0 }
    ))
    trackStub(stub(TankerMission, "normalizeCreationParams").returns(opts.tankerMissions or {}))
    trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(opts.anchor or ANCHOR))
  end

  before_each(function()
    activeStubs = {}
  end)

  after_each(function()
    revertAll()
  end)

  -- ============================================================================
  -- createPackageWithTiming: Package Assembly
  -- ============================================================================

  -- Positive: loadout status and launch flag are reset on the built package
  it("should reset loadout status and launch flag on the returned package", function()
    stubDependencies()
    local pkg = makePackage()

    local result = PackageTiming.createPackageWithTiming(makeConfig(), pkg, nil, 0)

    assert.are.equal(pkg, result)
    assert.is_false(result.hasLaunched)
    assert.is_false(result.loadoutStatus.isLoadoutInitiated)
    assert.is_nil(result.loadoutStatus.loadoutInitiatedTime)
    assert.is_nil(result.loadoutStatus.expectedReadyTime)
    assert.is_nil(result.loadoutStatus.loadoutStartTime)
  end)

  -- ============================================================================
  -- createPackageWithTiming: Flight Time Resolution
  -- ============================================================================

  -- Positive: resolved striker flight time derives from weapon-adjusted range
  it("should offset striker takeoff by the range-derived flight time", function()
    stubDependencies({ currentTime = 1000, anchor = ANCHOR, range = 450 })
    local pkg = makePackage({ striker = makeStriker({ timeOnStation = ANCHOR_STR }) })

    PackageTiming.createPackageWithTiming(makeConfig(), pkg, nil, 0)
    revertAll()

    local timeOnStation = Utils.parseDatetimeToTimestamp(pkg.striker.timeOnStation)
    local startTime = Utils.parseDatetimeToTimestamp(pkg.striker.startTime)
    -- distance = 450nm range - 50nm weapon = 400nm; 400/450*3600 = 3200s, +safety margin
    local expectedFlightTime = math.ceil((400 / TIMING.cruiseSpeed.combatAircraft) * 3600)
      + TIMING.flightTimeSafetyMargin
    assert.are.equal(expectedFlightTime, timeOnStation - startTime)
  end)

  -- Negative: unavailable weapon range falls back to the configured flight time
  it("should fall back to unresolved striker flight time when weapon range is missing", function()
    stubDependencies({ currentTime = 1000, anchor = ANCHOR, weapon = false })
    local pkg = makePackage({ striker = makeStriker({ timeOnStation = ANCHOR_STR }) })

    PackageTiming.createPackageWithTiming(makeConfig(), pkg, nil, 0)
    revertAll()

    local timeOnStation = Utils.parseDatetimeToTimestamp(pkg.striker.timeOnStation)
    local startTime = Utils.parseDatetimeToTimestamp(pkg.striker.startTime)
    local expectedFlightTime = TIMING.unresolvedFlightTime.striker + TIMING.flightTimeSafetyMargin
    assert.are.equal(expectedFlightTime, timeOnStation - startTime)
  end)

  -- ============================================================================
  -- createPackageWithTiming: Role Timing Anchoring
  -- ============================================================================

  -- Positive: striker on-station anchor yields the standard mission duration window
  it("should span the standard mission duration from striker on-station to end", function()
    stubDependencies({ currentTime = 1000, anchor = ANCHOR })
    local pkg = makePackage({ striker = makeStriker({ timeOnStation = ANCHOR_STR }) })

    PackageTiming.createPackageWithTiming(makeConfig(), pkg, nil, 0)
    revertAll()

    local timeOnStation = Utils.parseDatetimeToTimestamp(pkg.striker.timeOnStation)
    local endTime = Utils.parseDatetimeToTimestamp(pkg.striker.endTime)
    assert.are.equal(ANCHOR, timeOnStation)
    assert.are.equal(TIMING.missionDuration.standard, endTime - timeOnStation)
  end)

  -- Positive: support roles lead the striker by their configured lead time
  it("should place escort on-station ahead of the striker by the escort lead time", function()
    stubDependencies({ currentTime = 1000, anchor = ANCHOR })
    local pkg = makePackage({
      striker = makeStriker({ timeOnStation = ANCHOR_STR }),
      escort = {
        baseGUID = "BASE-2",
        unitCount = 2,
        unitDBID = 101,
        missionCreationParams = { opts = { PatrolZone = { "RP-ESCORT-1" } } }
      }
    })

    PackageTiming.createPackageWithTiming(makeConfig(), pkg, nil, 0)
    revertAll()

    local strikerTimeOnStation = Utils.parseDatetimeToTimestamp(pkg.striker.timeOnStation)
    local escortTimeOnStation = Utils.parseDatetimeToTimestamp(pkg.escort.timeOnStation)
    assert.are.equal(TIMING.supportLeadTime.escort, strikerTimeOnStation - escortTimeOnStation)
  end)

  -- Boundary: takeoff-time anchoring clears on-station and keeps the duration window
  it("should clear on-station when a role is anchored by takeoff time", function()
    stubDependencies({ currentTime = 1000, anchor = ANCHOR })
    local pkg = makePackage({ striker = makeStriker({ startTime = ANCHOR_STR }) })

    PackageTiming.createPackageWithTiming(makeConfig(), pkg, nil, 0)

    assert.is_nil(pkg.striker.timeOnStation)
    revertAll()

    local startTime = Utils.parseDatetimeToTimestamp(pkg.striker.startTime)
    local endTime = Utils.parseDatetimeToTimestamp(pkg.striker.endTime)
    assert.are.equal(ANCHOR, startTime)
    assert.are.equal(TIMING.missionDuration.standard, endTime - startTime)
  end)

  -- ============================================================================
  -- createPackageWithTiming: Schedule Shifting
  -- ============================================================================

  -- Boundary: readiness shift delays takeoff to the earliest allowed time
  it("should delay takeoff to honor readiness and assignment safety margins", function()
    local timeToReady = 3600
    stubDependencies({ currentTime = ANCHOR, anchor = ANCHOR })
    local pkg = makePackage({
      timeToReady = timeToReady,
      striker = makeStriker({ timeOnStation = ANCHOR_STR })
    })

    PackageTiming.createPackageWithTiming(makeConfig(), pkg, nil, 0)
    revertAll()

    local startTime = Utils.parseDatetimeToTimestamp(pkg.striker.startTime)
    assert.are.equal(ANCHOR + timeToReady + TIMING.assignmentSafetyMargin, startTime)
  end)

  -- Positive: sequential packages are separated by the strike interval
  it("should separate consecutive packages by the strike interval", function()
    local strikeInterval = 600
    stubDependencies({ currentTime = 1000, anchor = ANCHOR })
    local config = makeConfig()

    local firstPackage = PackageTiming.createPackageWithTiming(
      config, makePackage({ striker = makeStriker({ timeOnStation = ANCHOR_STR }) }), nil, strikeInterval
    )
    local secondPackage = PackageTiming.createPackageWithTiming(
      config, makePackage({ striker = makeStriker({ timeOnStation = ANCHOR_STR }) }), firstPackage, strikeInterval
    )
    revertAll()

    local firstTimeOnTarget = Utils.parseDatetimeToTimestamp(firstPackage.striker.timeOnStation)
    local secondTimeOnTarget = Utils.parseDatetimeToTimestamp(secondPackage.striker.timeOnStation)
    assert.are.equal(strikeInterval, secondTimeOnTarget - firstTimeOnTarget)
  end)

  -- ============================================================================
  -- createPackageWithTiming: Tanker Coordination
  -- ============================================================================

  -- Positive: a tanker package extends the striker window to the tanker duration
  it("should apply tanker mission duration to the striker when a tanker is present", function()
    stubDependencies({ currentTime = 1000, anchor = ANCHOR })
    local pkg = makePackage({
      striker = makeStriker({ timeOnStation = ANCHOR_STR }),
      tanker = { baseGUID = "TANKER-1", unitCount = 2, missionCreationParams = {} }
    })

    PackageTiming.createPackageWithTiming(makeConfig(), pkg, nil, 0)
    revertAll()

    local strikerTimeOnStation = Utils.parseDatetimeToTimestamp(pkg.striker.timeOnStation)
    local strikerEndTime = Utils.parseDatetimeToTimestamp(pkg.striker.endTime)
    assert.are.equal(TIMING.missionDuration.tanker, strikerEndTime - strikerTimeOnStation)
  end)

  -- Negative: without receiver references the tanker uses the unresolved arrival lead time
  it("should anchor tanker on-station by the unresolved arrival lead time without receivers", function()
    stubDependencies({ currentTime = 1000, anchor = ANCHOR })
    local pkg = makePackage({
      striker = makeStriker({ timeOnStation = ANCHOR_STR }),
      tanker = { baseGUID = "TANKER-1", unitCount = 2, missionCreationParams = {} }
    })

    PackageTiming.createPackageWithTiming(makeConfig(), pkg, nil, 0)
    revertAll()

    local strikerTimeOnStation = Utils.parseDatetimeToTimestamp(pkg.striker.timeOnStation)
    local tankerTimeOnStation = Utils.parseDatetimeToTimestamp(pkg.tanker.timeOnStation)
    assert.are.equal(TIMING.tankerUnresolvedArrivalLeadTime, strikerTimeOnStation - tankerTimeOnStation)
  end)

  -- Positive: the tanker times to the farthest referenced receiver arrival zone
  it("should time the tanker to the farthest referenced receiver arrival zone", function()
    local baseTimestamp = ANCHOR
    -- Real TankerMission.normalizeCreationParams resolves the multi-mission list here.
    trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(baseTimestamp))
    trackStub(stub(GameApi, "ScenEdit_GetReferencePoint").invokes(function(params)
      if params.name == "RP-FAR" then
        return { latitude = 2, longitude = 121 }
      end
      return { latitude = 1, longitude = 121 }
    end))
    trackStub(stub(GameApi, "Tool_Range").invokes(function(from, destination)
      if from == "BASE-2" then
        return destination.latitude == 2 and 200 or 100
      end
      return 200
    end))
    trackStub(stub(GameApi, "ScenEdit_QueryDB").returns({ ranges = { land = { max = 50 } } }))

    local pkg = {
      timeToReady = 5,
      striker = {
        baseGUID = "BASE-1",
        unitCount = 1,
        unitDBID = 100,
        weaponDBID = 200,
        missionCreationParams = { opts = { TankerMissionList = { "AAR-FAR" } } }
      },
      tanker = {
        baseGUID = "BASE-2",
        unitCount = 2,
        unitDBID = 102,
        weaponDBID = 0,
        missionCreationParams = {
          { name = "AAR-NEAR", type = "support", opts = { Zone = { "RP-NEAR" } } },
          { name = "AAR-FAR", type = "support", opts = { Zone = { "RP-FAR" } } }
        }
      },
      target = { list = { "TGT-1" } }
    }

    PackageTiming.createPackageWithTiming(makeConfig(), pkg, nil, 0)
    revertAll()

    local tankerStartTime = Utils.parseDatetimeToTimestamp(pkg.tanker.startTime)
    local tankerTimeOnStation = Utils.parseDatetimeToTimestamp(pkg.tanker.timeOnStation)
    local strikerStartTime = Utils.parseDatetimeToTimestamp(pkg.striker.startTime)
    local tankerFlightTime = math.ceil((200 / TIMING.cruiseSpeed.tanker) * 3600) + TIMING.flightTimeSafetyMargin
    local receiverTransitTime = math.ceil((200 / TIMING.cruiseSpeed.combatAircraft) * 3600)
      + TIMING.flightTimeSafetyMargin
    -- Earliest takeoff honors readiness (timeToReady 5 + assignmentSafetyMargin 300).
    assert.are.equal(baseTimestamp + 305, tankerStartTime)
    assert.are.equal(tankerFlightTime, tankerTimeOnStation - tankerStartTime)
    assert.are.equal(
      TIMING.tankerSetupTime,
      strikerStartTime + receiverTransitTime - tankerTimeOnStation
    )
  end)

  -- ============================================================================
  -- createPackageWithTiming: Takeoff-Anchored Sequencing
  -- ============================================================================

  -- Positive: interval spacing accounts for a takeoff-anchored previous package's flight time
  it("should derive interval spacing from a takeoff-anchored previous package flight time", function()
    local baseTimestamp = ANCHOR
    local firstTakeoff = baseTimestamp + 10000
    local strikeInterval = 10 * 60
    local config = makeConfig()
    config.c.air.timing.cruiseSpeed.combatAircraft = 300
    config.c.air.timing.flightTimeSafetyMargin = 2 * 60

    -- Real datetime parsing round-trips the takeoff anchor string set below.
    trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(baseTimestamp))
    trackStub(stub(GameApi, "Tool_Range").invokes(function(baseGUID)
      return baseGUID == "BASE-1" and 200 or 400
    end))
    trackStub(stub(GameApi, "ScenEdit_QueryDB").returns({ ranges = { land = { max = 50 } } }))

    local firstPackage = PackageTiming.createPackageWithTiming(
      config,
      makePackage({
        striker = makeStriker({ baseGUID = "BASE-1", startTime = os.date("!%Y-%m-%d %H:%M:%S", firstTakeoff) })
      }),
      nil,
      strikeInterval
    )
    local secondPackage = PackageTiming.createPackageWithTiming(
      config,
      makePackage({ striker = makeStriker({ baseGUID = "BASE-2" }) }),
      firstPackage,
      strikeInterval
    )
    revertAll()

    assert.is_nil(firstPackage.striker.timeOnStation)
    local firstTakeoffTime = Utils.parseDatetimeToTimestamp(firstPackage.striker.startTime)
    local secondTimeOnTarget = Utils.parseDatetimeToTimestamp(secondPackage.striker.timeOnStation)
    -- Previous striker flew BASE-1 (200nm range - 50nm weapon = 150nm) at 300kn + safety margin.
    local previousFlightTime = math.ceil((150 / config.c.air.timing.cruiseSpeed.combatAircraft) * 3600)
      + config.c.air.timing.flightTimeSafetyMargin
    assert.are.equal(previousFlightTime + strikeInterval, secondTimeOnTarget - firstTakeoffTime)
  end)

  -- ============================================================================
  -- createPackageWithTiming: Output Formatting
  -- ============================================================================

  -- Positive: applied role timings use the configured UTC date format
  it("should format applied role timings with the UTC date format", function()
    trackStub(stub(os, "date").invokes(function(format, timestamp)
      return string.format("%s:%s", format, tostring(timestamp))
    end))
    stubDependencies({ currentTime = 1000, anchor = ANCHOR })
    local pkg = makePackage({ striker = makeStriker({ timeOnStation = ANCHOR_STR }) })

    PackageTiming.createPackageWithTiming(makeConfig(), pkg, nil, 0)

    -- constants.DATE_FORMAT is "!%Y-%m-%d %H:%M:%S"; the leading "!" selects UTC.
    assert.are.equal("!", pkg.striker.startTime:sub(1, 1))
    assert.are.equal("!", pkg.striker.endTime:sub(1, 1))
  end)
end)
