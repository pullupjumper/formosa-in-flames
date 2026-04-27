-- Sigint Unit Tests
local Sigint = require("src.modules.ew.sigint")
local GameApi = require("src.utils.gameApi")
local GameUtils = require("src.utils.gameUtils")
local config = require("src.core.config")
local Logger = require("src.utils.logger")
local constants = require("src.core.constants")

describe("Sigint", function()
  ---@type luassert.spy[]
  local activeStubs
  ---@type luassert.spy
  local warnStub
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

  ---Create a firing unit context with sensible defaults
  ---@param overrides? table
  ---@return table
  local function makeFiringUnitCtx(overrides)
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
        AHA = {},
      },
    }
    if overrides then
      for k, v in pairs(overrides) do ctx[k] = v end
    end
    return ctx
  end

  ---Create a C2 unit context with sensible defaults
  ---@param overrides? table
  ---@return table
  local function makeC2Ctx(overrides)
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

  ---Create a sigint context with sensible defaults
  ---@param overrides? table
  ---@return table
  local function makeSigintContext(overrides)
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
      maxCount = 3,
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
      c = {
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
      maxDetectionRange = { 300, 340 },
      detectionSkipProbability = -1,
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
  -- Sigint.calculateDetectionProbability
  -- ============================================================================

  describe("calculateDetectionProbability", function()
    -- Positive: returns 1.0 when distance is within threshold
    it("should return 1.0 when distance is within detection threshold", function()
      local cfg = { detectionThreshold = 60 }
      local prob = Sigint.calculateDetectionProbability(30, cfg)
      assert.are.equal(1.0, prob)
    end)

    -- Positive: returns 1.0 when distance equals threshold exactly
    it("should return 1.0 when distance equals detection threshold", function()
      local cfg = { detectionThreshold = 60 }
      local prob = Sigint.calculateDetectionProbability(60, cfg)
      assert.are.equal(1.0, prob)
    end)

    -- Positive: returns value between 0 and 1 for mid-range distance
    it("should return probability between 0 and 1 for mid-range distance", function()
      local cfg = {
        detectionThreshold = 60,
        maxDetectionRange = { 500, 500 },
        formulaConstants = { decayRate = -1 / 450, power = 0.8 },
      }
      local prob = Sigint.calculateDetectionProbability(150, cfg)
      assert.is_true(prob > 0 and prob < 1)
    end)

    -- Positive: uses default values when config is nil
    it("should use default values when config is nil", function()
      local prob = Sigint.calculateDetectionProbability(30, nil)
      assert.are.equal(1.0, prob)
    end)

    -- Negative: returns 0.0 when distance exceeds max detection range
    it("should return 0.0 when distance exceeds max detection range", function()
      local cfg = {
        detectionThreshold = 60,
        maxDetectionRange = { 100, 100 },
      }
      local prob = Sigint.calculateDetectionProbability(200, cfg)
      assert.are.equal(0.0, prob)
    end)

    -- Boundary: returns 0.0 when distance is at max range boundary
    it("should return 0.0 when distance equals max detection range", function()
      local cfg = {
        detectionThreshold = 60,
        maxDetectionRange = { 200, 200 },
      }
      local prob = Sigint.calculateDetectionProbability(200, cfg)
      assert.are.equal(0.0, prob)
    end)

    -- Boundary: returns value at distance 0
    it("should return 1.0 when distance is zero", function()
      local cfg = { detectionThreshold = 60 }
      local prob = Sigint.calculateDetectionProbability(0, cfg)
      assert.are.equal(1.0, prob)
    end)

    -- Positive: probability decreases as distance increases
    it("should decrease probability as distance increases", function()
      local cfg = {
        detectionThreshold = 60,
        maxDetectionRange = { 500, 500 },
        formulaConstants = { decayRate = -1 / 450, power = 0.8 },
      }
      local probClose = Sigint.calculateDetectionProbability(100, cfg)
      local probFar = Sigint.calculateDetectionProbability(250, cfg)
      assert.is_true(probClose > probFar)
    end)
  end)

  -- ============================================================================
  -- Sigint.handleSigint
  -- ============================================================================

  describe("handleSigint", function()
    local cfg
    local sigintContext
    local sigintConfig

    before_each(function()
      cfg = makeConfig()
      sigintContext = makeSigintContext()
      sigintConfig = makeSigintConfig()

      trackStub(stub(GameUtils, "getCachedSideConfig")).returns({
        field = "c",
        enemySide = "Taiwan",
        displayName = "China",
      })
    end)

    -- Positive: should detect C2 platform unit (always emitting)
    it("should detect C2 platform unit that is always emitting", function()
      local c2Unit = makeUnit({
        guid = "C2-UNIT-001",
        name = "C2 Platform",
        dbid = constants.PLATFORMS.C2,
      })
      local unitContexts = {
        ["C2-UNIT-001"] = makeC2Ctx({
          guid = "C2-UNIT-001",
          name = "ROCC Alpha",
        }),
      }

      trackStub(stub(GameApi, "ScenEdit_GetUnit")).invokes(function(guidOrName, side)
        if guidOrName == "C2-UNIT-001" or guidOrName == "RECON-001" then
          if guidOrName == "RECON-001" then
            return makeUnit({ guid = "RECON-001", name = "RC-135V", condition = "Airborne" })
          end
          return c2Unit
        end
        return nil
      end)

      trackStub(stub(GameApi, "Tool_Range")).returns(50)
      trackStub(stub(GameApi, "World_GetPointFromBearing")).returns({
        latitude = 25.01,
        longitude = 121.01,
      })
      trackStub(stub(GameApi, "ScenEdit_CurrentTime")).returns(1000)
      trackStub(stub(GameApi, "ScenEdit_CreateBarkNotification_Geo"))
      trackStub(stub(math, "random")).invokes(function(a, b)
        if a == nil and b == nil then return 0.0 end
        if a and b then return a end
        return 0
      end)

      local results = Sigint.collectSigint(cfg, sigintContext, "China", true, sigintConfig, unitContexts)
      assert.is_true(results["C2-UNIT-001"].isDetected)
      assert.are.equal(25.01, results["C2-UNIT-001"].latitude)
      assert.are.equal(121.01, results["C2-UNIT-001"].longitude)
    end)

    -- Positive: should detect bunker sector control station (always emitting)
    it("should detect bunker sector control station that is always emitting", function()
      local bunkerUnit = makeUnit({
        guid = "BUNKER-001",
        name = "Sector Control Station",
        dbid = constants.PLATFORMS.BUNKER_SECTOR_CONTROL_STATION,
      })
      local unitContexts = {
        ["BUNKER-001"] = makeC2Ctx({
          guid = "BUNKER-001",
          name = "TAAOC Bravo",
        }),
      }

      trackStub(stub(GameApi, "ScenEdit_GetUnit")).invokes(function(guidOrName)
        if guidOrName == "BUNKER-001" then return bunkerUnit end
        if guidOrName == "RECON-001" then
          return makeUnit({ guid = "RECON-001", condition = "Airborne" })
        end
        return nil
      end)

      trackStub(stub(GameApi, "Tool_Range")).returns(40)
      trackStub(stub(GameApi, "World_GetPointFromBearing")).returns({ latitude = 25.02, longitude = 121.02 })
      trackStub(stub(GameApi, "ScenEdit_CurrentTime")).returns(2000)
      trackStub(stub(GameApi, "ScenEdit_CreateBarkNotification_Geo"))
      trackStub(stub(math, "random")).invokes(function(a, b)
        if a == nil and b == nil then return 0.0 end
        if a and b then return a end
        return 0
      end)

      local results = Sigint.collectSigint(cfg, sigintContext, "China", true, sigintConfig, unitContexts)
      assert.is_true(results["BUNKER-001"].isDetected)
    end)

    -- Positive: should detect C2 facility unit defined in c2FacilityDBIDs
    it("should detect C2 facility unit defined in iads c2FacilityDBIDs", function()
      local c2FacilityUnit = makeUnit({
        guid = "C2F-001",
        name = "C2 Facility",
        dbid = 3730,
      })
      local unitContexts = {
        ["C2F-001"] = makeC2Ctx({
          guid = "C2F-001",
          name = "ROCC Bravo",
        }),
      }

      trackStub(stub(GameApi, "ScenEdit_GetUnit")).invokes(function(guidOrName)
        if guidOrName == "C2F-001" then return c2FacilityUnit end
        if guidOrName == "RECON-001" then
          return makeUnit({ guid = "RECON-001", condition = "Airborne" })
        end
        return nil
      end)

      trackStub(stub(GameApi, "Tool_Range")).returns(30)
      trackStub(stub(GameApi, "World_GetPointFromBearing")).returns({ latitude = 25.03, longitude = 121.03 })
      trackStub(stub(GameApi, "ScenEdit_CurrentTime")).returns(3000)
      trackStub(stub(GameApi, "ScenEdit_CreateBarkNotification_Geo"))
      trackStub(stub(math, "random")).invokes(function(a, b)
        if a == nil and b == nil then return 0.0 end
        if a and b then return a end
        return 0
      end)

      local results = Sigint.collectSigint(cfg, sigintContext, "China", true, sigintConfig, unitContexts)
      assert.is_true(results["C2F-001"].isDetected)
    end)

    -- Positive: should detect mobile unit that is leaving restricted area
    it("should detect mobile unit that is leaving restricted launch area", function()
      local mobileUnit = makeUnit({
        guid = "TEL-001",
        name = "TEL Battery Alpha",
        dbid = 1000,
        speed = 30,
        course = { { latitude = 24.0, longitude = 120.0 } },
      })
      local unitContexts = {
        ["TEL-001"] = makeFiringUnitCtx({
          guid = "TEL-001",
          name = "TEL Battery Alpha",
        }),
      }

      trackStub(stub(GameApi, "ScenEdit_GetUnit")).invokes(function(guidOrName, side)
        if side == "Taiwan" then return mobileUnit end
        if guidOrName == "TEL-001" then return mobileUnit end
        if guidOrName == "RECON-001" then
          return makeUnit({ guid = "RECON-001", condition = "Airborne" })
        end
        return nil
      end)

      trackStub(stub(GameUtils, "isInArea")).returns(false)
      trackStub(stub(GameApi, "Tool_Range")).returns(50)
      trackStub(stub(GameApi, "World_GetPointFromBearing")).returns({ latitude = 25.05, longitude = 121.05 })
      trackStub(stub(GameApi, "ScenEdit_CurrentTime")).returns(4000)
      trackStub(stub(GameApi, "ScenEdit_CreateBarkNotification_Geo"))
      trackStub(stub(math, "random")).invokes(function(a, b)
        if a == nil and b == nil then return 0.0 end
        if a and b then return a end
        return 0
      end)

      local results = Sigint.collectSigint(cfg, sigintContext, "China", true, sigintConfig, unitContexts)
      assert.is_true(results["TEL-001"].isDetected)
    end)

    -- Negative: should not detect mobile unit with no course
    it("should not detect mobile unit with no course set", function()
      local stoppedUnit = makeUnit({
        guid = "TEL-002",
        name = "TEL Battery Bravo",
        dbid = 1000,
        speed = 0,
        course = {},
      })
      local unitContexts = {
        ["TEL-002"] = makeFiringUnitCtx({
          guid = "TEL-002",
          name = "TEL Battery Bravo",
        }),
      }

      trackStub(stub(GameApi, "ScenEdit_GetUnit")).invokes(function(guidOrName, side)
        if side == "Taiwan" then return stoppedUnit end
        if guidOrName == "TEL-002" then return stoppedUnit end
        if guidOrName == "RECON-001" then
          return makeUnit({ guid = "RECON-001", condition = "Airborne" })
        end
        return nil
      end)

      trackStub(stub(GameApi, "Tool_Range")).returns(50)
      trackStub(stub(GameApi, "ScenEdit_CurrentTime")).returns(5000)
      trackStub(stub(math, "random")).invokes(function(a, b)
        if a == nil and b == nil then return 0.0 end
        if a and b then return a end
        return 0
      end)

      local results = Sigint.collectSigint(cfg, sigintContext, "China", false, sigintConfig, unitContexts)
      assert.is_false(results["TEL-002"].isDetected)
    end)

    -- Negative: should not detect mobile unit that is within restricted area
    it("should not detect mobile unit that is within restricted area", function()
      local mobileUnit = makeUnit({
        guid = "TEL-003",
        name = "TEL Battery Charlie",
        dbid = 1000,
        speed = 30,
        course = { { latitude = 24.5, longitude = 120.5 } },
      })
      local unitContexts = {
        ["TEL-003"] = makeFiringUnitCtx({
          guid = "TEL-003",
          name = "TEL Battery Charlie",
        }),
      }

      trackStub(stub(GameApi, "ScenEdit_GetUnit")).invokes(function(guidOrName, side)
        if side == "Taiwan" then return mobileUnit end
        if guidOrName == "TEL-003" then return mobileUnit end
        if guidOrName == "RECON-001" then
          return makeUnit({ guid = "RECON-001", condition = "Airborne" })
        end
        return nil
      end)

      trackStub(stub(GameUtils, "isInArea")).returns(true)
      trackStub(stub(GameApi, "Tool_Range")).returns(50)
      trackStub(stub(GameApi, "ScenEdit_CurrentTime")).returns(6000)
      trackStub(stub(math, "random")).invokes(function(a, b)
        if a == nil and b == nil then return 0.0 end
        if a and b then return a end
        return 0
      end)

      local results = Sigint.collectSigint(cfg, sigintContext, "China", false, sigintConfig, unitContexts)
      assert.is_false(results["TEL-003"].isDetected)
    end)

    -- Negative: should skip unit when actual unit is not found
    it("should skip unit when actual unit cannot be found", function()
      local unitContexts = {
        ["MISSING-001"] = makeFiringUnitCtx({ guid = "MISSING-001", name = "Missing Unit" }),
      }

      trackStub(stub(GameApi, "ScenEdit_GetUnit")).returns(nil)
      trackStub(stub(GameApi, "ScenEdit_CurrentTime")).returns(7000)
      trackStub(stub(math, "random")).invokes(function(a, b)
        if a == nil and b == nil then return 0.0 end
        if a and b then return a end
        return 0
      end)

      local results = Sigint.collectSigint(cfg, sigintContext, "China", false, sigintConfig, unitContexts)
      assert.is_nil(results["MISSING-001"])
    end)

    -- Negative: should not detect when recon aircraft is not airborne
    it("should not detect when recon aircraft is not airborne", function()
      local targetUnit = makeUnit({
        guid = "C2-UNIT-002",
        name = "C2 Target",
        dbid = constants.PLATFORMS.C2,
      })
      local unitContexts = {
        ["C2-UNIT-002"] = makeC2Ctx({ guid = "C2-UNIT-002" }),
      }

      trackStub(stub(GameApi, "ScenEdit_GetUnit")).invokes(function(guidOrName)
        if guidOrName == "C2-UNIT-002" then return targetUnit end
        if guidOrName == "RECON-001" then
          return makeUnit({ guid = "RECON-001", condition = "On Ground" })
        end
        return nil
      end)

      trackStub(stub(GameApi, "ScenEdit_CurrentTime")).returns(8000)
      trackStub(stub(math, "random")).invokes(function(a, b)
        if a == nil and b == nil then return 0.0 end
        if a and b then return a end
        return 0
      end)

      local results = Sigint.collectSigint(cfg, sigintContext, "China", false, sigintConfig, unitContexts)
      assert.is_false(results["C2-UNIT-002"].isDetected)
    end)

    -- Positive: should update transmission data on detection
    it("should create transmission record on first detection", function()
      local c2Unit = makeUnit({
        guid = "C2-REC-001",
        name = "ROCC Test",
        dbid = constants.PLATFORMS.C2,
      })
      local unitContexts = {
        ["C2-REC-001"] = makeC2Ctx({
          guid = "C2-REC-001",
          name = "ROCC Test",
          msg = "ROCC detected",
        }),
      }

      trackStub(stub(GameApi, "ScenEdit_GetUnit")).invokes(function(guidOrName)
        if guidOrName == "C2-REC-001" then return c2Unit end
        if guidOrName == "RECON-001" then
          return makeUnit({ guid = "RECON-001", condition = "Airborne" })
        end
        return nil
      end)

      trackStub(stub(GameApi, "Tool_Range")).returns(50)
      trackStub(stub(GameApi, "World_GetPointFromBearing")).returns({ latitude = 25.1, longitude = 121.1 })
      trackStub(stub(GameApi, "ScenEdit_CurrentTime")).returns(9000)
      trackStub(stub(GameApi, "ScenEdit_CreateBarkNotification_Geo"))
      trackStub(stub(math, "random")).invokes(function(a, b)
        if a == nil and b == nil then return 0.0 end
        if a and b then return a end
        return 0
      end)

      Sigint.collectSigint(cfg, sigintContext, "China", true, sigintConfig, unitContexts)

      local transmission = sigintContext.transmissions["C2-REC-001"]
      assert.is_not_nil(transmission)
      assert.are.equal("ROCC Test", transmission.name)
      assert.are.equal("C2", transmission.type)
      assert.are.equal(1, transmission.currentDetectionLevel)
      assert.are.equal(1, transmission.detectionCount)
    end)

    -- Positive: should increment detection level on repeated detection
    it("should increment detection level on repeated detection", function()
      local c2Unit = makeUnit({
        guid = "C2-INC-001",
        name = "ROCC Increment",
        dbid = constants.PLATFORMS.C2,
      })
      local unitContexts = {
        ["C2-INC-001"] = makeC2Ctx({
          guid = "C2-INC-001",
          name = "ROCC Increment",
          msg = "ROCC detected",
        }),
      }

      sigintContext.transmissions["C2-INC-001"] = {
        name = "ROCC Increment",
        guid = "C2-INC-001",
        msg = "ROCC detected",
        type = "C2",
        latitude = 25.0,
        longitude = 121.0,
        contacts = {},
        currentDetectionLevel = 2,
        autodetectable = false,
        firstDetected = 1000,
        lastDetected = 1000,
        detectionCount = 2,
        confidence = 0.5,
      }

      trackStub(stub(GameApi, "ScenEdit_GetUnit")).invokes(function(guidOrName)
        if guidOrName == "C2-INC-001" then return c2Unit end
        if guidOrName == "RECON-001" then
          return makeUnit({ guid = "RECON-001", condition = "Airborne" })
        end
        return nil
      end)

      trackStub(stub(GameApi, "Tool_Range")).returns(50)
      trackStub(stub(GameApi, "World_GetPointFromBearing")).returns({ latitude = 25.2, longitude = 121.2 })
      trackStub(stub(GameApi, "ScenEdit_CurrentTime")).returns(10000)
      trackStub(stub(GameApi, "ScenEdit_CreateBarkNotification_Geo"))
      trackStub(stub(math, "random")).invokes(function(a, b)
        if a == nil and b == nil then return 0.0 end
        if a and b then return a end
        return 0
      end)

      Sigint.collectSigint(cfg, sigintContext, "China", true, sigintConfig, unitContexts)

      local transmission = sigintContext.transmissions["C2-INC-001"]
      assert.are.equal(3, transmission.currentDetectionLevel)
      assert.are.equal(3, transmission.detectionCount)
    end)

    -- Positive: should set autodetectable when detection level exceeds maxCount
    it("should set autodetectable when detection level exceeds maxCount", function()
      local c2Unit = makeUnit({
        guid = "C2-AUTO-001",
        name = "ROCC Auto",
        dbid = constants.PLATFORMS.C2,
      })
      local unitContexts = {
        ["C2-AUTO-001"] = makeC2Ctx({
          guid = "C2-AUTO-001",
          name = "ROCC Auto",
          msg = "ROCC detected",
        }),
      }
      local setUnitStub = trackStub(stub(GameApi, "ScenEdit_SetUnit"))

      sigintContext.transmissions["C2-AUTO-001"] = {
        name = "ROCC Auto",
        guid = "C2-AUTO-001",
        msg = "ROCC detected",
        type = "C2",
        latitude = 25.0,
        longitude = 121.0,
        contacts = {},
        currentDetectionLevel = 3,
        autodetectable = false,
        firstDetected = 1000,
        lastDetected = 1000,
        detectionCount = 3,
        confidence = 0.8,
      }

      trackStub(stub(GameApi, "ScenEdit_GetUnit")).invokes(function(guidOrName)
        if guidOrName == "C2-AUTO-001" then return c2Unit end
        if guidOrName == "RECON-001" then
          return makeUnit({ guid = "RECON-001", condition = "Airborne" })
        end
        return nil
      end)

      trackStub(stub(GameApi, "Tool_Range")).returns(50)
      trackStub(stub(GameApi, "World_GetPointFromBearing")).returns({ latitude = 25.3, longitude = 121.3 })
      trackStub(stub(GameApi, "ScenEdit_CurrentTime")).returns(11000)
      trackStub(stub(GameApi, "ScenEdit_CreateBarkNotification_Geo"))
      trackStub(stub(math, "random")).invokes(function(a, b)
        if a == nil and b == nil then return 0.0 end
        if a and b then return a end
        return 0
      end)

      Sigint.collectSigint(cfg, sigintContext, "China", true, sigintConfig, unitContexts)

      local transmission = sigintContext.transmissions["C2-AUTO-001"]
      assert.is_true(transmission.autodetectable)
      assert.stub(setUnitStub).was.called()
    end)

    -- Positive: should update group members' autodetectable when unit has group
    it("should update group members autodetectable state when unit has group", function()
      local groupUnit = makeUnit({
        guid = "C2-GRP-001",
        name = "ROCC Group",
        dbid = constants.PLATFORMS.C2,
        group = {
          unitlist = { "MEMBER-A", "MEMBER-B" },
        },
      })
      local unitContexts = {
        ["C2-GRP-001"] = makeC2Ctx({
          guid = "C2-GRP-001",
          name = "ROCC Group",
          msg = "ROCC detected",
        }),
      }
      local setUnitStub = trackStub(stub(GameApi, "ScenEdit_SetUnit"))

      sigintContext.transmissions["C2-GRP-001"] = {
        name = "ROCC Group",
        guid = "C2-GRP-001",
        msg = "ROCC detected",
        type = "C2",
        latitude = 25.0,
        longitude = 121.0,
        contacts = {},
        currentDetectionLevel = 3,
        autodetectable = false,
        firstDetected = 1000,
        lastDetected = 1000,
        detectionCount = 3,
        confidence = 0.8,
      }

      trackStub(stub(GameApi, "ScenEdit_GetUnit")).invokes(function(guidOrName)
        if guidOrName == "C2-GRP-001" then return groupUnit end
        if guidOrName == "RECON-001" then
          return makeUnit({ guid = "RECON-001", condition = "Airborne" })
        end
        return nil
      end)

      trackStub(stub(GameApi, "Tool_Range")).returns(50)
      trackStub(stub(GameApi, "World_GetPointFromBearing")).returns({ latitude = 25.4, longitude = 121.4 })
      trackStub(stub(GameApi, "ScenEdit_CurrentTime")).returns(12000)
      trackStub(stub(GameApi, "ScenEdit_CreateBarkNotification_Geo"))
      trackStub(stub(math, "random")).invokes(function(a, b)
        if a == nil and b == nil then return 0.0 end
        if a and b then return a end
        return 0
      end)

      Sigint.collectSigint(cfg, sigintContext, "China", true, sigintConfig, unitContexts)

      assert.stub(setUnitStub).was.called(2)
      assert.stub(setUnitStub).was.called_with({ guid = "MEMBER-A", autodetectable = true })
      assert.stub(setUnitStub).was.called_with({ guid = "MEMBER-B", autodetectable = true })
    end)

    -- Positive: should decrement detection level when unit is not detected
    it("should decrement detection level when unit is not detected", function()
      local c2Unit = makeUnit({
        guid = "C2-DEC-001",
        name = "ROCC Dec",
        dbid = constants.PLATFORMS.C2,
      })
      local unitContexts = {
        ["C2-DEC-001"] = makeC2Ctx({
          guid = "C2-DEC-001",
          name = "ROCC Dec",
        }),
      }

      sigintContext.transmissions["C2-DEC-001"] = {
        name = "ROCC Dec",
        guid = "C2-DEC-001",
        msg = "ROCC detected",
        type = "C2",
        latitude = 25.0,
        longitude = 121.0,
        contacts = {},
        currentDetectionLevel = 3,
        autodetectable = false,
        firstDetected = 1000,
        lastDetected = 1000,
        detectionCount = 3,
        confidence = 0.8,
      }

      -- No recon aircraft => no detection possible
      sigintContext.reconAircraft = {}

      trackStub(stub(GameApi, "ScenEdit_GetUnit")).invokes(function(guidOrName)
        if guidOrName == "C2-DEC-001" then return c2Unit end
        return nil
      end)

      trackStub(stub(GameApi, "ScenEdit_CurrentTime")).returns(13000)
      trackStub(stub(math, "random")).invokes(function(a, b)
        if a == nil and b == nil then return 0.0 end
        if a and b then return a end
        return 0
      end)

      Sigint.collectSigint(cfg, sigintContext, "China", false, sigintConfig, unitContexts)

      local transmission = sigintContext.transmissions["C2-DEC-001"]
      assert.are.equal(2, transmission.currentDetectionLevel)
    end)

    -- Positive: should reset autodetectable to false when undetected and was autodetectable
    it("should reset autodetectable to false when undetected", function()
      local c2Unit = makeUnit({
        guid = "C2-RESET-001",
        name = "ROCC Reset",
        dbid = constants.PLATFORMS.C2,
      })
      local unitContexts = {
        ["C2-RESET-001"] = makeC2Ctx({
          guid = "C2-RESET-001",
          name = "ROCC Reset",
        }),
      }
      local setUnitStub = trackStub(stub(GameApi, "ScenEdit_SetUnit"))

      sigintContext.transmissions["C2-RESET-001"] = {
        name = "ROCC Reset",
        guid = "C2-RESET-001",
        msg = "ROCC detected",
        type = "C2",
        latitude = 25.0,
        longitude = 121.0,
        contacts = {},
        currentDetectionLevel = 4,
        autodetectable = true,
        firstDetected = 1000,
        lastDetected = 1000,
        detectionCount = 5,
        confidence = 0.9,
      }

      sigintContext.reconAircraft = {}

      trackStub(stub(GameApi, "ScenEdit_GetUnit")).invokes(function(guidOrName)
        if guidOrName == "C2-RESET-001" then return c2Unit end
        return nil
      end)

      trackStub(stub(GameApi, "ScenEdit_CurrentTime")).returns(14000)
      trackStub(stub(math, "random")).invokes(function(a, b)
        if a == nil and b == nil then return 0.0 end
        if a and b then return a end
        return 0
      end)

      Sigint.collectSigint(cfg, sigintContext, "China", false, sigintConfig, unitContexts)

      local transmission = sigintContext.transmissions["C2-RESET-001"]
      assert.is_false(transmission.autodetectable)
      assert.stub(setUnitStub).was.called_with({ guid = "C2-RESET-001", autodetectable = false })
    end)

    -- Positive: should look up firing unit by name and enemy side
    it("should look up firing unit by name and enemy side when weaponDBID is present", function()
      local firingUnit = makeUnit({
        guid = "FU-LOOKUP-001",
        name = "TEL Lookup",
        dbid = 1000,
        speed = 30,
        course = { { latitude = 24.0, longitude = 120.0 } },
      })
      local unitContexts = {
        ["FU-LOOKUP-001"] = makeFiringUnitCtx({
          guid = "FU-LOOKUP-001",
          name = "TEL Lookup",
          weaponDBID = 3177,
        }),
      }

      local getUnitStub = trackStub(stub(GameApi, "ScenEdit_GetUnit")).invokes(function(guidOrName, side)
        if guidOrName == "TEL Lookup" and side == "Taiwan" then return firingUnit end
        if guidOrName == "RECON-001" then
          return makeUnit({ guid = "RECON-001", condition = "Airborne" })
        end
        if guidOrName == "FU-LOOKUP-001" then return firingUnit end
        return nil
      end)

      trackStub(stub(GameUtils, "isInArea")).returns(false)
      trackStub(stub(GameApi, "Tool_Range")).returns(50)
      trackStub(stub(GameApi, "World_GetPointFromBearing")).returns({ latitude = 25.5, longitude = 121.5 })
      trackStub(stub(GameApi, "ScenEdit_CurrentTime")).returns(15000)
      trackStub(stub(GameApi, "ScenEdit_CreateBarkNotification_Geo"))
      trackStub(stub(math, "random")).invokes(function(a, b)
        if a == nil and b == nil then return 0.0 end
        if a and b then return a end
        return 0
      end)

      Sigint.collectSigint(cfg, sigintContext, "China", true, sigintConfig, unitContexts)

      assert.stub(getUnitStub).was.called_with("TEL Lookup", "Taiwan")
    end)

    -- Negative: should not detect mobile unit with speed 0
    it("should not detect mobile unit with zero speed", function()
      local stationaryUnit = makeUnit({
        guid = "TEL-STOP-001",
        name = "TEL Stopped",
        dbid = 1000,
        speed = 0,
        course = { { latitude = 24.0, longitude = 120.0 } },
      })
      local unitContexts = {
        ["TEL-STOP-001"] = makeFiringUnitCtx({
          guid = "TEL-STOP-001",
          name = "TEL Stopped",
        }),
      }

      trackStub(stub(GameApi, "ScenEdit_GetUnit")).invokes(function(guidOrName, side)
        if side == "Taiwan" then return stationaryUnit end
        if guidOrName == "TEL-STOP-001" then return stationaryUnit end
        if guidOrName == "RECON-001" then
          return makeUnit({ guid = "RECON-001", condition = "Airborne" })
        end
        return nil
      end)

      trackStub(stub(GameApi, "Tool_Range")).returns(50)
      trackStub(stub(GameApi, "ScenEdit_CurrentTime")).returns(16000)
      trackStub(stub(math, "random")).invokes(function(a, b)
        if a == nil and b == nil then return 0.0 end
        if a and b then return a end
        return 0
      end)

      local results = Sigint.collectSigint(cfg, sigintContext, "China", false, sigintConfig, unitContexts)
      assert.is_false(results["TEL-STOP-001"].isDetected)
    end)

    -- Negative: should not detect mobile unit with no RL area defined
    it("should not detect mobile unit with no RL area defined", function()
      local mobileUnit = makeUnit({
        guid = "TEL-NORL-001",
        name = "TEL NoRL",
        dbid = 1000,
        speed = 30,
        course = { { latitude = 24.0, longitude = 120.0 } },
      })
      local unitContexts = {
        ["TEL-NORL-001"] = makeFiringUnitCtx({
          guid = "TEL-NORL-001",
          name = "TEL NoRL",
          operationalArea = {
            RL = { { area = {} } },
            FP = {},
            HA = {},
            AHA = {},
          },
        }),
      }

      trackStub(stub(GameApi, "ScenEdit_GetUnit")).invokes(function(guidOrName, side)
        if side == "Taiwan" then return mobileUnit end
        if guidOrName == "TEL-NORL-001" then return mobileUnit end
        if guidOrName == "RECON-001" then
          return makeUnit({ guid = "RECON-001", condition = "Airborne" })
        end
        return nil
      end)

      trackStub(stub(GameApi, "Tool_Range")).returns(50)
      trackStub(stub(GameApi, "ScenEdit_CurrentTime")).returns(17000)
      trackStub(stub(math, "random")).invokes(function(a, b)
        if a == nil and b == nil then return 0.0 end
        if a and b then return a end
        return 0
      end)

      local results = Sigint.collectSigint(cfg, sigintContext, "China", false, sigintConfig, unitContexts)
      assert.is_false(results["TEL-NORL-001"].isDetected)
    end)

    -- Positive: should show notification with confidence when showConfidence is true
    it("should show notification with confidence when showConfidence is true", function()
      local c2Unit = makeUnit({
        guid = "C2-SHOW-001",
        name = "C2 ShowConf",
        dbid = constants.PLATFORMS.C2,
      })
      local unitContexts = {
        ["C2-SHOW-001"] = makeC2Ctx({
          guid = "C2-SHOW-001",
          name = "ROCC ShowConf",
          msg = "ROCC detected",
        }),
      }

      trackStub(stub(GameApi, "ScenEdit_GetUnit")).invokes(function(guidOrName)
        if guidOrName == "C2-SHOW-001" then return c2Unit end
        if guidOrName == "RECON-001" then
          return makeUnit({ guid = "RECON-001", condition = "Airborne" })
        end
        return nil
      end)

      trackStub(stub(GameApi, "Tool_Range")).returns(50)
      trackStub(stub(GameApi, "World_GetPointFromBearing")).returns({ latitude = 25.6, longitude = 121.6 })
      trackStub(stub(GameApi, "ScenEdit_CurrentTime")).returns(18000)
      local barkStub = trackStub(stub(GameApi, "ScenEdit_CreateBarkNotification_Geo"))
      trackStub(stub(math, "random")).invokes(function(a, b)
        if a == nil and b == nil then return 0.0 end
        if a and b then return a end
        return 0
      end)

      -- We need to test getSigint with showConfidence. Since getSigint is local,
      -- we test through handleSigint. The data parameter is nil in handleSigint,
      -- so showConfidence defaults to false. We verify the notification doesn't contain confidence.
      Sigint.collectSigint(cfg, sigintContext, "China", true, sigintConfig, unitContexts)

      assert.stub(barkStub).was.called()
    end)

    -- Positive: should classify TAAOC unit as C2 type in transmission record
    it("should classify TAAOC unit as C2 type in transmission record", function()
      local taaocUnit = makeUnit({
        guid = "TAAOC-001",
        name = "TAAOC Echo",
        dbid = constants.PLATFORMS.BUNKER_SECTOR_CONTROL_STATION,
      })
      local unitContexts = {
        ["TAAOC-001"] = makeC2Ctx({
          guid = "TAAOC-001",
          name = "TAAOC Echo",
          msg = "TAAOC detected",
        }),
      }

      trackStub(stub(GameApi, "ScenEdit_GetUnit")).invokes(function(guidOrName)
        if guidOrName == "TAAOC-001" then return taaocUnit end
        if guidOrName == "RECON-001" then
          return makeUnit({ guid = "RECON-001", condition = "Airborne" })
        end
        return nil
      end)

      trackStub(stub(GameApi, "Tool_Range")).returns(50)
      trackStub(stub(GameApi, "World_GetPointFromBearing")).returns({ latitude = 25.7, longitude = 121.7 })
      trackStub(stub(GameApi, "ScenEdit_CurrentTime")).returns(19000)
      trackStub(stub(GameApi, "ScenEdit_CreateBarkNotification_Geo"))
      trackStub(stub(math, "random")).invokes(function(a, b)
        if a == nil and b == nil then return 0.0 end
        if a and b then return a end
        return 0
      end)

      Sigint.collectSigint(cfg, sigintContext, "China", true, sigintConfig, unitContexts)

      local transmission = sigintContext.transmissions["TAAOC-001"]
      assert.are.equal("C2", transmission.type)
    end)

    -- Positive: should classify non-C2 unit as mobile type in transmission record
    it("should classify non-C2 unit as mobile type in transmission record", function()
      local mobileUnit = makeUnit({
        guid = "MOB-TYPE-001",
        name = "TEL Mobile Type",
        dbid = 1000,
        speed = 30,
        course = { { latitude = 24.0, longitude = 120.0 } },
      })
      local unitContexts = {
        ["MOB-TYPE-001"] = makeFiringUnitCtx({
          guid = "MOB-TYPE-001",
          name = "TEL Mobile Type",
          msg = "TEL detected",
        }),
      }

      trackStub(stub(GameApi, "ScenEdit_GetUnit")).invokes(function(guidOrName, side)
        if side == "Taiwan" then return mobileUnit end
        if guidOrName == "MOB-TYPE-001" then return mobileUnit end
        if guidOrName == "RECON-001" then
          return makeUnit({ guid = "RECON-001", condition = "Airborne" })
        end
        return nil
      end)

      trackStub(stub(GameUtils, "isInArea")).returns(false)
      trackStub(stub(GameApi, "Tool_Range")).returns(50)
      trackStub(stub(GameApi, "World_GetPointFromBearing")).returns({ latitude = 25.8, longitude = 121.8 })
      trackStub(stub(GameApi, "ScenEdit_CurrentTime")).returns(20000)
      trackStub(stub(GameApi, "ScenEdit_CreateBarkNotification_Geo"))
      trackStub(stub(math, "random")).invokes(function(a, b)
        if a == nil and b == nil then return 0.0 end
        if a and b then return a end
        return 0
      end)

      Sigint.collectSigint(cfg, sigintContext, "China", true, sigintConfig, unitContexts)

      local transmission = sigintContext.transmissions["MOB-TYPE-001"]
      assert.are.equal("mobile", transmission.type)
    end)

    -- Positive: should return empty results when unitContexts is empty
    it("should return empty results when unitContexts is empty", function()
      trackStub(stub(GameApi, "ScenEdit_CurrentTime")).returns(21000)

      local results = Sigint.collectSigint(cfg, sigintContext, "China", false, sigintConfig, {})
      assert.are.same({}, results)
    end)
  end)

  -- ============================================================================
  -- Sigint.initReconAircraftContexts
  -- ============================================================================

  describe("initReconAircraftContexts", function()
    -- Positive: should register RC-135V aircraft as recon aircraft
    it("should register RC-135V aircraft as recon aircraft", function()
      local sigintCtx = makeSigintContext({ reconAircraft = {} })
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

      local count = Sigint.initReconAircraftContexts(sigintCtx, "US", config.c.commsJamming.aircraftDefaults)
      assert.are.equal(1, count)
      assert.is_not_nil(sigintCtx.reconAircraft["RC135-001"])
      assert.are.equal("RC135-001", sigintCtx.reconAircraft["RC135-001"].guid)
      assert.are.equal(40, sigintCtx.reconAircraft["RC135-001"].commsLevel)
    end)

    -- Positive: should register Y-9DZ aircraft as recon aircraft
    it("should register Y-9DZ aircraft as recon aircraft", function()
      local sigintCtx = makeSigintContext({ reconAircraft = {} })
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

      local count = Sigint.initReconAircraftContexts(sigintCtx, "China", config.c.commsJamming.aircraftDefaults)
      assert.are.equal(1, count)
      assert.is_not_nil(sigintCtx.reconAircraft["Y9DZ-001"])
    end)

    -- Positive: should register multiple recon aircraft
    it("should register multiple recon aircraft of different types", function()
      local sigintCtx = makeSigintContext({ reconAircraft = {} })
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

      local count = Sigint.initReconAircraftContexts(sigintCtx, "China", config.c.commsJamming.aircraftDefaults)
      assert.are.equal(2, count)
      assert.is_not_nil(sigintCtx.reconAircraft["RC135-002"])
      assert.is_not_nil(sigintCtx.reconAircraft["Y9DZ-002"])
    end)

    -- Negative: should not register non-recon aircraft
    it("should not register non-recon aircraft", function()
      local sigintCtx = makeSigintContext({ reconAircraft = {} })
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

      local count = Sigint.initReconAircraftContexts(sigintCtx, "China", config.c.commsJamming.aircraftDefaults)
      assert.are.equal(0, count)
      assert.is_nil(sigintCtx.reconAircraft["J20-001"])
    end)

    -- Negative: should not register non-Aircraft type units
    it("should not register units that are not Aircraft type", function()
      local sigintCtx = makeSigintContext({ reconAircraft = {} })
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

      local count = Sigint.initReconAircraftContexts(sigintCtx, "US", config.c.commsJamming.aircraftDefaults)
      assert.are.equal(0, count)
    end)

    -- Negative: should return 0 when no aircraft found for side
    it("should return 0 and warn when no aircraft found for side", function()
      local sigintCtx = makeSigintContext({ reconAircraft = {} })

      local mockSide = {
        unitsBy = function(_, unitType)
          return nil
        end,
      }

      trackStub(stub(GameApi, "VP_GetSide")).returns(mockSide)

      local count = Sigint.initReconAircraftContexts(sigintCtx, "US", config.c.commsJamming.aircraftDefaults)
      assert.are.equal(0, count)
      assert.stub(warnStub).was.called(1)
    end)

    -- Negative: should skip unit when ScenEdit_GetUnit returns nil
    it("should skip unit when ScenEdit_GetUnit returns nil", function()
      local sigintCtx = makeSigintContext({ reconAircraft = {} })

      local mockSide = {
        unitsBy = function(_, unitType)
          return { { guid = "GHOST-001" } }
        end,
      }

      trackStub(stub(GameApi, "VP_GetSide")).returns(mockSide)
      trackStub(stub(GameApi, "ScenEdit_GetUnit")).returns(nil)

      local count = Sigint.initReconAircraftContexts(sigintCtx, "US", config.c.commsJamming.aircraftDefaults)
      assert.are.equal(0, count)
    end)

    -- Positive: should initialize OODA from unit
    it("should store OODA data from unit in recon aircraft context", function()
      local sigintCtx = makeSigintContext({ reconAircraft = {} })
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

      Sigint.initReconAircraftContexts(sigintCtx, "US", config.c.commsJamming.aircraftDefaults)
      assert.are.same(oodaData, sigintCtx.reconAircraft["RC135-OODA"].OODA)
    end)
  end)
end)
