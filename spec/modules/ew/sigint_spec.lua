---@diagnostic disable: need-check-nil, assign-type-mismatch, cast-local-type, param-type-mismatch, inject-field
-- Sigint Unit Tests
local Sigint = require("src.modules.ew.sigint")
local GameApi = require("src.utils.gameApi")
local GameUtils = require("src.utils.gameUtils")
local config = require("src.core.config")
local Logger = require("src.utils.logger")
local constants = require("src.core.constants")
local PersistentState = require("src.core.persistentState")

describe("Sigint", function()
  ---@type luassert.spy[]
  local activeStubs
  ---@type luassert.spy
  local warnStub
  ---@type luassert.spy
  local errorStub
  ---Track and register test stub for automatic cleanup.
  ---@param s any
  ---@return luassert.spy
  local function trackStub(s)
    table.insert(activeStubs, s)
    return s
  end

  before_each(function()
    activeStubs = {}
    trackStub(stub(Logger, "log"))
    warnStub = trackStub(stub(Logger, "warn"))
    errorStub = trackStub(stub(Logger, "error"))
  end)

  after_each(function()
    for _, s in ipairs(activeStubs) do
      s:revert()
    end
    activeStubs = {}
  end)

  -- ============================================================================
  -- Shared mock data builders
  -- ============================================================================

  ---Create a unit with sensible defaults
  ---@param overrides? table
  ---@return table
  local function makeUnit(overrides)
    local unit = {
      guid = "UNIT-001",
      name = "Test Unit",
      dbid = 1000,
      latitude = 25.0,
      longitude = 121.0,
      speed = 30,
      condition = "Airborne",
      type = "Aircraft",
      course = { { latitude = 24.0, longitude = 120.0 } },
      group = nil,
      OODA = { evasion = 10, targeting = 10, detection = 10 },
    }
    if overrides then
      for k, v in pairs(overrides) do unit[k] = v end
    end
    return unit
  end

  ---Create a firing unit state with sensible defaults
  ---@param overrides? table
  ---@return table
  local function makeFiringUnitState(overrides)
    local ctx = {
      guid = "FU-001",
      name = "TEL Battery Alpha",
      msg = "TEL Alpha detected",
      weaponDBID = 3177,
      dbid = 1000,
      operationalArea = {
        RL = { { area = { "RP-001", "RP-002", "RP-003", "RP-004" } } },
        FP = {},
        HA = {},
        ATP = {},
      },
    }
    if overrides then
      for k, v in pairs(overrides) do ctx[k] = v end
    end
    return ctx
  end

  ---Create a C2 unit state with sensible defaults
  ---@param overrides? table
  ---@return table
  local function makeC2State(overrides)
    local ctx = {
      guid = "C2-001",
      name = "ROCC Alpha",
      msg = "C2 node detected",
      areas = { { "RP-001", "RP-002" } },
      sam = {},
    }
    if overrides then
      for k, v in pairs(overrides) do ctx[k] = v end
    end
    return ctx
  end

  ---Create a sigint state with sensible defaults
  ---@param overrides? table
  ---@return table
  local function makeSigintState(overrides)
    local ctx = {
      transmissions = {},
      reconAircraft = {
        ["RECON-001"] = {
          guid = "RECON-001",
          OODA = { evasion = 10, targeting = 10, detection = 10 },
          commsLevel = 40,
          commsBase = 40,
          commsThreshold = 30,
          outofcomms = 0,
        },
      },
      enabled = true,
    }
    if overrides then
      for k, v in pairs(overrides) do ctx[k] = v end
    end
    return ctx
  end

  ---Create a config object with sensible defaults
  ---@param overrides? table
  ---@return table
  local function makeConfig(overrides)
    local cfg = {
      red = {
        iads = {
          c2FacilityDBIDs = { 3730, 177 },
        },
      },
    }
    if overrides then
      for k, v in pairs(overrides) do cfg[k] = v end
    end
    return cfg
  end

  ---Create a sigint config with sensible defaults
  ---@param overrides? table
  ---@return table
  local function makeSigintConfig(overrides)
    local cfg = {
      detectionThreshold = 60,
      maxDetectionRangeNm = { 300, 340 },
      detectionSkipProbability = -1,
      maxCount = 3,
      formulaConstants = {
        decayRate = -1 / 450,
        power = 0.8,
      },
    }
    if overrides then
      for k, v in pairs(overrides) do cfg[k] = v end
    end
    return cfg
  end

  -- ============================================================================
  -- Sigint.processSide
  -- ============================================================================

  describe("processSide", function()
    local cfg
    local sigintState
    local saveData

    -- ------------------------------------------------------------------------
    -- Shared builders
    -- ------------------------------------------------------------------------

    ---Create an existing transmission record with sensible defaults
    ---@param overrides? table
    ---@return table
    local function makeTransmission(overrides)
      local transmission = {
        name = "ROCC Alpha",
        guid = "C2-001",
        msg = "ROCC detected",
        type = "C2",
        latitude = 25.0,
        longitude = 121.0,
        contacts = {},
        currentDetectionLevel = 0,
        autodetectable = false,
        firstDetected = 1000,
        lastDetected = 1000,
        detectionCount = 0,
        confidence = 0.5,
      }
      if overrides then
        for k, v in pairs(overrides) do transmission[k] = v end
      end
      return transmission
    end

    ---Resolve units by guid or name; RECON-001 is the collecting aircraft
    ---@param units table[] Target units
    ---@param reconCondition? string Recon aircraft condition (default Airborne)
    ---@return luassert.spy
    local function stubUnits(units, reconCondition)
      local byKey = {
        ["RECON-001"] = makeUnit({ guid = "RECON-001", name = "RC-135V", condition = reconCondition or "Airborne" }),
      }
      for _, u in ipairs(units) do
        byKey[u.guid] = u
        byKey[u.name] = u
      end
      return trackStub(stub(GameApi, "ScenEdit_GetUnit")).invokes(function(guidOrName)
        return byKey[guidOrName]
      end)
    end

    ---math.random() returns 0 (never skip, always pass the roll); math.random(a, b) returns a
    local function stubLowRandom()
      trackStub(stub(math, "random")).invokes(function(a, b)
        if a == nil and b == nil then return 0.0 end
        if a and b then return a end
        return 0
      end)
    end

    ---Stub the recon-to-target range and the clock
    ---@param distance number|fun(enemyGuid: string): number
    local function stubRange(distance)
      local rangeStub = trackStub(stub(GameApi, "Tool_Range"))
      if type(distance) == "function" then
        rangeStub.invokes(distance)
      else
        rangeStub.returns(distance)
      end
      trackStub(stub(GameApi, "ScenEdit_CurrentTime")).returns(1000)
    end

    ---Stub the triangulated fix position and the map notification
    ---@param pos? table
    ---@return luassert.spy barkStub
    local function stubFix(pos)
      trackStub(stub(GameApi, "World_GetPointFromBearing")).returns(pos or { latitude = 25.01, longitude = 121.01 })
      return trackStub(stub(GameApi, "ScenEdit_CreateBarkNotification_Geo"))
    end

    ---Run China's SIGINT collection over one emitter group
    ---@param unitStates table
    ---@return luassert.spy emittersStub
    local function runRed(unitStates)
      local emittersStub = trackStub(stub(PersistentState, "sigintEmitters")).returns({ unitStates })
      Sigint.processSide(cfg, saveData, "China")
      return emittersStub
    end

    before_each(function()
      cfg = makeConfig()
      cfg.red.sigint = makeSigintConfig()
      sigintState = makeSigintState()
      saveData = { red = { sigint = sigintState } }

      trackStub(stub(GameUtils, "getCachedSideConfig")).returns({
        field = "red",
        enemySide = "Taiwan",
      })
    end)

    -- ------------------------------------------------------------------------
    -- Side gating
    -- ------------------------------------------------------------------------

    describe("side gating", function()
      -- Positive: an enabled side collects the emitters of its own save data
      it("should collect the side's emitters when SIGINT is enabled", function()
        stubUnits({})

        local emittersStub = runRed({})

        assert.stub(emittersStub).was.called_with(saveData, "China")
      end)

      -- Negative: a disabled side does nothing
      it("should skip collection when SIGINT is disabled", function()
        sigintState.enabled = false

        local emittersStub = runRed({})

        assert.stub(emittersStub).was_not.called()
      end)
    end)

    -- ------------------------------------------------------------------------
    -- Emission and detection
    -- ------------------------------------------------------------------------

    describe("emission and detection", function()
      -- Positive: should detect C2 platform unit (always emitting)
      it("should record a C2 platform unit at the triangulated fix", function()
        stubUnits({ makeUnit({ guid = "C2-UNIT-001", dbid = constants.PLATFORMS.C2 }) })
        stubRange(50)
        stubFix({ latitude = 25.01, longitude = 121.01 })
        stubLowRandom()

        runRed({ ["C2-UNIT-001"] = makeC2State({ guid = "C2-UNIT-001" }) })

        local transmission = sigintState.transmissions["C2-UNIT-001"]
        assert.are.equal(25.01, transmission.latitude)
        assert.are.equal(121.01, transmission.longitude)
      end)

      -- Positive: should detect bunker sector control station (always emitting)
      it("should record a bunker sector control station that is always emitting", function()
        stubUnits({ makeUnit({ guid = "BUNKER-001", dbid = constants.PLATFORMS.BUNKER_SECTOR_CONTROL_STATION }) })
        stubRange(40)
        stubFix()
        stubLowRandom()

        runRed({ ["BUNKER-001"] = makeC2State({ guid = "BUNKER-001", name = "TAAOC Bravo" }) })

        assert.is_not_nil(sigintState.transmissions["BUNKER-001"])
      end)

      -- Positive: should detect C2 facility unit defined in c2FacilityDBIDs
      it("should record a C2 facility unit defined in iads c2FacilityDBIDs", function()
        stubUnits({ makeUnit({ guid = "C2F-001", dbid = 3730 }) })
        stubRange(30)
        stubFix()
        stubLowRandom()

        runRed({ ["C2F-001"] = makeC2State({ guid = "C2F-001", name = "ROCC Bravo" }) })

        assert.is_not_nil(sigintState.transmissions["C2F-001"])
      end)

      -- Positive: should detect mobile unit that is leaving restricted area
      it("should record a mobile unit that is leaving its restricted launch area", function()
        stubUnits({ makeUnit({ guid = "TEL-001", name = "TEL Battery Alpha" }) })
        trackStub(stub(GameUtils, "isInArea")).returns(false)
        stubRange(50)
        stubFix()
        stubLowRandom()

        runRed({ ["TEL-001"] = makeFiringUnitState({ guid = "TEL-001", name = "TEL Battery Alpha" }) })

        assert.is_not_nil(sigintState.transmissions["TEL-001"])
      end)

      -- Positive: firing units are resolved by name on the enemy side
      it("should look up firing unit by name and enemy side when weaponDBID is present", function()
        local getUnitStub = stubUnits({ makeUnit({ guid = "FU-LOOKUP-001", name = "TEL Lookup" }) })
        trackStub(stub(GameUtils, "isInArea")).returns(false)
        stubRange(50)
        stubFix()
        stubLowRandom()

        runRed({ ["FU-LOOKUP-001"] = makeFiringUnitState({ guid = "FU-LOOKUP-001", name = "TEL Lookup" }) })

        assert.stub(getUnitStub).was.called_with("TEL Lookup", "Taiwan")
      end)

      -- Positive: a detection is announced on the map with the state message
      it("should show a map notification at the fix with the unit's message", function()
        stubUnits({ makeUnit({ guid = "C2-SHOW-001", dbid = constants.PLATFORMS.C2 }) })
        stubRange(50)
        local barkStub = stubFix({ latitude = 25.6, longitude = 121.6 })
        stubLowRandom()

        runRed({ ["C2-SHOW-001"] = makeC2State({ guid = "C2-SHOW-001", msg = "ROCC detected" }) })

        assert.stub(barkStub).was.called_with(121.6, 25.6, "ROCC detected", 255, 255, 255, true, true, 4, 16)
      end)

      -- Negative: should not detect mobile unit with no course
      it("should not record a mobile unit with no course set", function()
        stubUnits({ makeUnit({ guid = "TEL-002", name = "TEL Battery Bravo", speed = 0, course = {} }) })
        stubRange(50)
        stubLowRandom()

        runRed({ ["TEL-002"] = makeFiringUnitState({ guid = "TEL-002", name = "TEL Battery Bravo" }) })

        assert.is_nil(sigintState.transmissions["TEL-002"])
      end)

      -- Negative: should not detect mobile unit with speed 0
      it("should not record a mobile unit with zero speed", function()
        stubUnits({ makeUnit({ guid = "TEL-STOP-001", name = "TEL Stopped", speed = 0 }) })
        stubRange(50)
        stubLowRandom()

        runRed({ ["TEL-STOP-001"] = makeFiringUnitState({ guid = "TEL-STOP-001", name = "TEL Stopped" }) })

        assert.is_nil(sigintState.transmissions["TEL-STOP-001"])
      end)

      -- Negative: should not detect mobile unit with no RL area defined
      it("should not record a mobile unit with no RL area defined", function()
        stubUnits({ makeUnit({ guid = "TEL-NORL-001", name = "TEL NoRL" }) })
        stubRange(50)
        stubLowRandom()

        runRed({
          ["TEL-NORL-001"] = makeFiringUnitState({
            guid = "TEL-NORL-001",
            name = "TEL NoRL",
            operationalArea = { RL = { { area = {} } }, FP = {}, HA = {}, ATP = {} },
          }),
        })

        assert.is_nil(sigintState.transmissions["TEL-NORL-001"])
      end)

      -- Negative: should not detect mobile unit that is within restricted area
      it("should not record a mobile unit that stays within its restricted area", function()
        stubUnits({ makeUnit({ guid = "TEL-003", name = "TEL Battery Charlie" }) })
        trackStub(stub(GameUtils, "isInArea")).returns(true)
        stubRange(50)
        stubLowRandom()

        runRed({ ["TEL-003"] = makeFiringUnitState({ guid = "TEL-003", name = "TEL Battery Charlie" }) })

        assert.is_nil(sigintState.transmissions["TEL-003"])
      end)

      -- Negative: should skip unit when actual unit is not found
      it("should not range or record a unit that cannot be found", function()
        stubUnits({})
        local rangeStub = trackStub(stub(GameApi, "Tool_Range"))
        stubLowRandom()

        runRed({ ["MISSING-001"] = makeFiringUnitState({ guid = "MISSING-001", name = "Missing Unit" }) })

        assert.stub(rangeStub).was_not.called()
        assert.are.same({}, sigintState.transmissions)
      end)

      -- Negative: should not detect when recon aircraft is not airborne
      it("should not record when the recon aircraft is not airborne", function()
        stubUnits({ makeUnit({ guid = "C2-UNIT-002", dbid = constants.PLATFORMS.C2 }) }, "On Ground")
        trackStub(stub(GameApi, "ScenEdit_CurrentTime")).returns(1000)
        stubLowRandom()

        runRed({ ["C2-UNIT-002"] = makeC2State({ guid = "C2-UNIT-002" }) })

        assert.is_nil(sigintState.transmissions["C2-UNIT-002"])
      end)
    end)

    -- ------------------------------------------------------------------------
    -- Detection probability
    -- ------------------------------------------------------------------------

    describe("detection probability", function()
      ---Run one always-emitting C2 target at the given distance and return its recorded confidence
      ---@param distance number
      ---@return number|nil confidence Nil when the target was not detected
      local function detectC2At(distance)
        stubUnits({ makeUnit({ guid = "C2-PROB-001", dbid = constants.PLATFORMS.C2 }) })
        stubRange(distance)
        stubFix()
        stubLowRandom()

        runRed({ ["C2-PROB-001"] = makeC2State({ guid = "C2-PROB-001" }) })

        local transmission = sigintState.transmissions["C2-PROB-001"]
        return transmission and transmission.confidence
      end

      -- Positive: certain detection inside the threshold
      it("should detect with confidence 1.0 when distance is within detection threshold", function()
        assert.are.equal(1.0, detectC2At(30))
      end)

      -- Positive: exponential decay between threshold and max range
      it("should detect with decayed confidence for mid-range distance", function()
        cfg.red.sigint.maxDetectionRangeNm = { 500, 500 }

        assert.are.equal(math.exp((-1 / 450) * (150 ^ 0.8)), detectC2At(150))
      end)

      -- Positive: farther targets get lower confidence
      it("should give a farther target lower confidence than a closer one", function()
        cfg.red.sigint.maxDetectionRangeNm = { 500, 500 }
        stubUnits({
          makeUnit({ guid = "C2-NEAR", dbid = constants.PLATFORMS.C2 }),
          makeUnit({ guid = "C2-FAR", dbid = constants.PLATFORMS.C2 }),
        })
        stubRange(function(enemyGuid) return enemyGuid == "C2-NEAR" and 100 or 250 end)
        stubFix()
        stubLowRandom()

        runRed({
          ["C2-NEAR"] = makeC2State({ guid = "C2-NEAR" }),
          ["C2-FAR"] = makeC2State({ guid = "C2-FAR" }),
        })

        assert.is_true(sigintState.transmissions["C2-NEAR"].confidence > sigintState.transmissions["C2-FAR"].confidence)
      end)

      -- Positive: missing thresholds fall back to the built-in defaults
      it("should use default threshold when SIGINT config omits it", function()
        cfg.red.sigint = { maxCount = 3, detectionSkipProbability = -1 }

        assert.are.equal(1.0, detectC2At(30))
      end)

      -- Negative: no detection beyond max range
      it("should not detect when distance exceeds max detection range", function()
        cfg.red.sigint.maxDetectionRangeNm = { 100, 100 }

        assert.is_nil(detectC2At(200))
      end)

      -- Boundary: threshold distance is still certain
      it("should detect with confidence 1.0 when distance equals detection threshold", function()
        assert.are.equal(1.0, detectC2At(60))
      end)

      -- Boundary: zero distance is certain
      it("should detect with confidence 1.0 when distance is zero", function()
        assert.are.equal(1.0, detectC2At(0))
      end)

      -- Boundary: max range itself is out of reach
      it("should not detect when distance equals max detection range", function()
        cfg.red.sigint.maxDetectionRangeNm = { 200, 200 }

        assert.is_nil(detectC2At(200))
      end)
    end)

    -- ------------------------------------------------------------------------
    -- Transmission records
    -- ------------------------------------------------------------------------

    describe("transmission records", function()
      ---Stub a detectable C2 unit and a hit, returning the ScenEdit_SetUnit stub
      ---@param unit table
      ---@return luassert.spy setUnitStub
      local function stubC2Hit(unit)
        stubUnits({ unit })
        stubRange(50)
        stubFix()
        stubLowRandom()
        return trackStub(stub(GameApi, "ScenEdit_SetUnit"))
      end

      -- Positive: should create transmission record on first detection
      it("should create transmission record on first detection", function()
        stubC2Hit(makeUnit({ guid = "C2-REC-001", dbid = constants.PLATFORMS.C2 }))

        runRed({ ["C2-REC-001"] = makeC2State({ guid = "C2-REC-001", name = "ROCC Test" }) })

        local transmission = sigintState.transmissions["C2-REC-001"]
        assert.are.equal("ROCC Test", transmission.name)
        assert.are.equal("C2", transmission.type)
        assert.are.equal(1, transmission.currentDetectionLevel)
        assert.are.equal(1, transmission.detectionCount)
      end)

      -- Positive: should increment detection level on repeated detection
      it("should increment detection level on repeated detection", function()
        stubC2Hit(makeUnit({ guid = "C2-INC-001", dbid = constants.PLATFORMS.C2 }))
        sigintState.transmissions["C2-INC-001"] = makeTransmission({
          guid = "C2-INC-001", currentDetectionLevel = 2, detectionCount = 2,
        })

        runRed({ ["C2-INC-001"] = makeC2State({ guid = "C2-INC-001" }) })

        local transmission = sigintState.transmissions["C2-INC-001"]
        assert.are.equal(3, transmission.currentDetectionLevel)
        assert.are.equal(3, transmission.detectionCount)
      end)

      -- Positive: should set autodetectable when detection level exceeds maxCount
      it("should set autodetectable when detection level exceeds maxCount", function()
        local setUnitStub = stubC2Hit(makeUnit({ guid = "C2-AUTO-001", dbid = constants.PLATFORMS.C2 }))
        sigintState.transmissions["C2-AUTO-001"] = makeTransmission({
          guid = "C2-AUTO-001", currentDetectionLevel = 3, detectionCount = 3,
        })

        runRed({ ["C2-AUTO-001"] = makeC2State({ guid = "C2-AUTO-001" }) })

        assert.is_true(sigintState.transmissions["C2-AUTO-001"].autodetectable)
        assert.stub(setUnitStub).was.called_with({ guid = "C2-AUTO-001", autodetectable = true })
      end)

      -- Positive: should update group members' autodetectable when unit has group
      it("should update group members autodetectable state when unit has group", function()
        local setUnitStub = stubC2Hit(makeUnit({
          guid = "C2-GRP-001",
          dbid = constants.PLATFORMS.C2,
          group = { unitlist = { "MEMBER-A", "MEMBER-B" } },
        }))
        sigintState.transmissions["C2-GRP-001"] = makeTransmission({
          guid = "C2-GRP-001", currentDetectionLevel = 3, detectionCount = 3,
        })

        runRed({ ["C2-GRP-001"] = makeC2State({ guid = "C2-GRP-001" }) })

        assert.stub(setUnitStub).was.called(2)
        assert.stub(setUnitStub).was.called_with({ guid = "MEMBER-A", autodetectable = true })
        assert.stub(setUnitStub).was.called_with({ guid = "MEMBER-B", autodetectable = true })
      end)

      -- Positive: TAAOC names are C2 nodes
      it("should classify TAAOC unit as C2 type in transmission record", function()
        stubC2Hit(makeUnit({ guid = "TAAOC-001", dbid = constants.PLATFORMS.BUNKER_SECTOR_CONTROL_STATION }))

        runRed({ ["TAAOC-001"] = makeC2State({ guid = "TAAOC-001", name = "TAAOC Echo" }) })

        assert.are.equal("C2", sigintState.transmissions["TAAOC-001"].type)
      end)

      -- Positive: everything else is a mobile emitter
      it("should classify non-C2 unit as mobile type in transmission record", function()
        stubUnits({ makeUnit({ guid = "MOB-TYPE-001", name = "TEL Mobile Type" }) })
        trackStub(stub(GameUtils, "isInArea")).returns(false)
        stubRange(50)
        stubFix()
        stubLowRandom()

        runRed({ ["MOB-TYPE-001"] = makeFiringUnitState({ guid = "MOB-TYPE-001", name = "TEL Mobile Type" }) })

        assert.are.equal("mobile", sigintState.transmissions["MOB-TYPE-001"].type)
      end)

      -- Positive: should decrement detection level when unit is not detected
      it("should decrement detection level when unit is not detected", function()
        stubUnits({ makeUnit({ guid = "C2-DEC-001", dbid = constants.PLATFORMS.C2 }) })
        trackStub(stub(GameApi, "ScenEdit_CurrentTime")).returns(1000)
        stubLowRandom()
        sigintState.transmissions["C2-DEC-001"] = makeTransmission({ guid = "C2-DEC-001", currentDetectionLevel = 3 })
        -- No recon aircraft means no detection is possible
        sigintState.reconAircraft = {}

        runRed({ ["C2-DEC-001"] = makeC2State({ guid = "C2-DEC-001" }) })

        assert.are.equal(2, sigintState.transmissions["C2-DEC-001"].currentDetectionLevel)
      end)

      -- Positive: should reset autodetectable to false when undetected and was autodetectable
      it("should reset autodetectable to false when undetected", function()
        stubUnits({ makeUnit({ guid = "C2-RESET-001", dbid = constants.PLATFORMS.C2 }) })
        trackStub(stub(GameApi, "ScenEdit_CurrentTime")).returns(1000)
        stubLowRandom()
        local setUnitStub = trackStub(stub(GameApi, "ScenEdit_SetUnit"))
        sigintState.transmissions["C2-RESET-001"] = makeTransmission({
          guid = "C2-RESET-001", currentDetectionLevel = 4, autodetectable = true,
        })
        sigintState.reconAircraft = {}

        runRed({ ["C2-RESET-001"] = makeC2State({ guid = "C2-RESET-001" }) })

        assert.is_false(sigintState.transmissions["C2-RESET-001"].autodetectable)
        assert.stub(setUnitStub).was.called_with({ guid = "C2-RESET-001", autodetectable = false })
      end)
    end)
  end)

  -- ============================================================================
  -- Sigint.initSide
  -- ============================================================================

  describe("initSide", function()
    ---Save data whose given side holds the SIGINT state under test
    ---@param sideName string Collecting side name
    ---@param sigintState table SIGINT state for that side
    ---@return table
    local function makeSaveData(sideName, sigintState)
      local saveData = {}
      saveData[GameUtils.getCachedSideConfig(sideName).field] = { sigint = sigintState }
      return saveData
    end

    -- Positive: should register RC-135V aircraft as recon aircraft
    it("should register RC-135V aircraft as recon aircraft", function()
      local sigintState = makeSigintState({ reconAircraft = {} })
      local rc135v = makeUnit({
        guid = "RC135-001",
        name = "RC-135V Rivet Joint",
        dbid = constants.PLATFORMS.RC135V,
        type = "Aircraft",
      })

      local mockSide = {
        unitsBy = function(_, unitType)
          return { { guid = "RC135-001" } }
        end,
      }

      trackStub(stub(GameApi, "VP_GetSide")).returns(mockSide)
      trackStub(stub(GameApi, "ScenEdit_GetUnit")).invokes(function(guid)
        if guid == "RC135-001" then return rc135v end
        return nil
      end)

      local count = Sigint.initSide(config, makeSaveData("US", sigintState), "US")
      assert.are.equal(1, count)
      assert.is_not_nil(sigintState.reconAircraft["RC135-001"])
      assert.are.equal("RC135-001", sigintState.reconAircraft["RC135-001"].guid)
      assert.are.equal(40, sigintState.reconAircraft["RC135-001"].commsLevel)
    end)

    -- Positive: should register Y-9DZ aircraft as recon aircraft
    it("should register Y-9DZ aircraft as recon aircraft", function()
      local sigintState = makeSigintState({ reconAircraft = {} })
      local y9dz = makeUnit({
        guid = "Y9DZ-001",
        name = "Y-9DZ",
        dbid = constants.PLATFORMS.Y9DZ,
        type = "Aircraft",
      })

      local mockSide = {
        unitsBy = function(_, unitType)
          return { { guid = "Y9DZ-001" } }
        end,
      }

      trackStub(stub(GameApi, "VP_GetSide")).returns(mockSide)
      trackStub(stub(GameApi, "ScenEdit_GetUnit")).invokes(function(guid)
        if guid == "Y9DZ-001" then return y9dz end
        return nil
      end)

      local count = Sigint.initSide(config, makeSaveData("China", sigintState), "China")
      assert.are.equal(1, count)
      assert.is_not_nil(sigintState.reconAircraft["Y9DZ-001"])
    end)

    -- Positive: should register multiple recon aircraft
    it("should register multiple recon aircraft of different types", function()
      local sigintState = makeSigintState({ reconAircraft = {} })
      local rc135v = makeUnit({
        guid = "RC135-002",
        name = "RC-135V",
        dbid = constants.PLATFORMS.RC135V,
        type = "Aircraft",
      })
      local y9dz = makeUnit({
        guid = "Y9DZ-002",
        name = "Y-9DZ",
        dbid = constants.PLATFORMS.Y9DZ,
        type = "Aircraft",
      })

      local mockSide = {
        unitsBy = function(_, unitType)
          return { { guid = "RC135-002" }, { guid = "Y9DZ-002" } }
        end,
      }

      trackStub(stub(GameApi, "VP_GetSide")).returns(mockSide)
      trackStub(stub(GameApi, "ScenEdit_GetUnit")).invokes(function(guid)
        if guid == "RC135-002" then return rc135v end
        if guid == "Y9DZ-002" then return y9dz end
        return nil
      end)

      local count = Sigint.initSide(config, makeSaveData("China", sigintState), "China")
      assert.are.equal(2, count)
      assert.is_not_nil(sigintState.reconAircraft["RC135-002"])
      assert.is_not_nil(sigintState.reconAircraft["Y9DZ-002"])
    end)

    -- Negative: should not register non-recon aircraft
    it("should not register non-recon aircraft", function()
      local sigintState = makeSigintState({ reconAircraft = {} })
      local fighter = makeUnit({
        guid = "J20-001",
        name = "J-20",
        dbid = constants.PLATFORMS.J20,
        type = "Aircraft",
      })

      local mockSide = {
        unitsBy = function(_, unitType)
          return { { guid = "J20-001" } }
        end,
      }

      trackStub(stub(GameApi, "VP_GetSide")).returns(mockSide)
      trackStub(stub(GameApi, "ScenEdit_GetUnit")).invokes(function(guid)
        if guid == "J20-001" then return fighter end
        return nil
      end)

      local count = Sigint.initSide(config, makeSaveData("China", sigintState), "China")
      assert.are.equal(0, count)
      assert.is_nil(sigintState.reconAircraft["J20-001"])
    end)

    -- Negative: should not register non-Aircraft type units
    it("should not register units that are not Aircraft type", function()
      local sigintState = makeSigintState({ reconAircraft = {} })
      local facility = makeUnit({
        guid = "FAC-001",
        name = "RC-135V Facility",
        dbid = constants.PLATFORMS.RC135V,
        type = "Facility",
      })

      local mockSide = {
        unitsBy = function(_, unitType)
          return { { guid = "FAC-001" } }
        end,
      }

      trackStub(stub(GameApi, "VP_GetSide")).returns(mockSide)
      trackStub(stub(GameApi, "ScenEdit_GetUnit")).invokes(function(guid)
        if guid == "FAC-001" then return facility end
        return nil
      end)

      local count = Sigint.initSide(config, makeSaveData("US", sigintState), "US")
      assert.are.equal(0, count)
    end)

    -- Negative: should return 0 when no aircraft found for side
    it("should return 0 and warn when no aircraft found for side", function()
      local sigintState = makeSigintState({ reconAircraft = {} })

      local mockSide = {
        unitsBy = function(_, unitType)
          return nil
        end,
      }

      trackStub(stub(GameApi, "VP_GetSide")).returns(mockSide)

      local count = Sigint.initSide(config, makeSaveData("US", sigintState), "US")
      assert.are.equal(0, count)
      assert.stub(warnStub).was.called(1)
    end)

    -- Negative: should skip unit when ScenEdit_GetUnit returns nil
    it("should skip unit when ScenEdit_GetUnit returns nil", function()
      local sigintState = makeSigintState({ reconAircraft = {} })

      local mockSide = {
        unitsBy = function(_, unitType)
          return { { guid = "GHOST-001" } }
        end,
      }

      trackStub(stub(GameApi, "VP_GetSide")).returns(mockSide)
      trackStub(stub(GameApi, "ScenEdit_GetUnit")).returns(nil)

      local count = Sigint.initSide(config, makeSaveData("US", sigintState), "US")
      assert.are.equal(0, count)
    end)

    -- Positive: should initialize OODA from unit
    it("should store OODA data from unit in recon aircraft context", function()
      local sigintState = makeSigintState({ reconAircraft = {} })
      local oodaData = { evasion = 5, targeting = 15, detection = 20 }
      local rc135v = makeUnit({
        guid = "RC135-OODA",
        name = "RC-135V",
        dbid = constants.PLATFORMS.RC135V,
        type = "Aircraft",
        OODA = oodaData,
      })

      local mockSide = {
        unitsBy = function(_, unitType)
          return { { guid = "RC135-OODA" } }
        end,
      }

      trackStub(stub(GameApi, "VP_GetSide")).returns(mockSide)
      trackStub(stub(GameApi, "ScenEdit_GetUnit")).invokes(function(guid)
        if guid == "RC135-OODA" then return rc135v end
        return nil
      end)

      Sigint.initSide(config, makeSaveData("US", sigintState), "US")
      assert.are.same(oodaData, sigintState.reconAircraft["RC135-OODA"].OODA)
    end)
  end)
end)
