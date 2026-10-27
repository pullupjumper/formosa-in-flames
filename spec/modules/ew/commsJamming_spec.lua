---@diagnostic disable: need-check-nil, assign-type-mismatch, cast-local-type, param-type-mismatch, inject-field
-- CommsJamming Unit Tests
local CommsJamming = require("src.modules.ew.commsJamming")
local GameApi = require("src.utils.gameApi")
local Utils = require("src.utils.utils")
local config = require("src.core.config")
local Logger = require("src.utils.logger")
local constants = require("src.core.constants")

describe("CommsJamming", function()
  ---@type luassert.spy[]
  local activeStubs
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
    trackStub(stub(Logger, "warn"))
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

  ---Create a commsJamming config with sensible defaults
  ---@param overrides? table
  ---@return table
  local function makeCommsJammingConfig(overrides)
    local cfg = {
      mode = "omnidirectional",
      limit = 4,
      rangeNm = 50,
      initialComms = -20,
      baseJammingPower = -120,
      distanceExponent = 1.04,
      effectivenessFormula = { base = 1.9, range = 1.8 },
      distanceThresholds = {
        close = 100,
        medium = 200,
        far = 300,
        distant = 400,
      },
      aewSupport = {
        close = 400,
        medium = 350,
        far = 250,
        distant = 150,
      },
      recoveryTime = { min = 5, max = 10 },
      jammingTime = { min = 5, max = 10 },
      cooldownTime = { min = -5, max = -1 },
      randomVariance = {
        close = { min = -1, max = 1 },
        medium = { min = -3, max = 3 },
        far = { min = -6, max = 6 },
        distant = { min = -10, max = 10 },
      },
    }
    if overrides then
      for k, v in pairs(overrides) do cfg[k] = v end
    end
    return cfg
  end

  ---Create a jammer aircraft state
  ---@param overrides? table
  ---@return table
  local function makeJammerState(overrides)
    local ctx = {
      guid = "JAMMER-001",
      OODA = {},
      commsLevel = 40,
      commsBase = 40,
      commsThreshold = 30,
      outofcomms = 0,
    }
    if overrides then
      for k, v in pairs(overrides) do ctx[k] = v end
    end
    return ctx
  end

  ---Create a radar/SAM unit state
  ---@param overrides? table
  ---@return table
  local function makeRadarState(overrides)
    local ctx = {
      name = "SAM Unit Alpha",
      guid = "SAM-001",
      OODA = {},
      outofcomms = 0,
      isOutOfComms = false,
    }
    if overrides then
      for k, v in pairs(overrides) do ctx[k] = v end
    end
    return ctx
  end

  ---Create an aircraft state for Taiwan air
  ---@param overrides? table
  ---@return table
  local function makeAircraftState(overrides)
    local ctx = {
      guid = "AC-001",
      OODA = {},
      commsLevel = 100,
      commsBase = 40,
      commsThreshold = 30,
      outofcomms = 0,
    }
    if overrides then
      for k, v in pairs(overrides) do ctx[k] = v end
    end
    return ctx
  end

  ---Create a C2 state (ROCC/TAAOC)
  ---@param overrides? table
  ---@return table
  local function makeC2State(overrides)
    local ctx = {
      msg = "",
      guid = "C2-001",
      areas = {},
      sam = {},
      radar = {},
    }
    if overrides then
      for k, v in pairs(overrides) do ctx[k] = v end
    end
    return ctx
  end

  ---Create a CMO unit mock
  ---@param overrides? table
  ---@return table
  local function makeUnit(overrides)
    local u = {
      guid = "UNIT-001",
      name = "UNIT-001",
      condition = "Airborne",
      jammer = true,
      heading = 0,
      outOfComms = false,
      dbid = 0,
      OODA = {},
    }
    if overrides then
      for k, v in pairs(overrides) do u[k] = v end
    end
    if not overrides or not overrides.name then
      u.name = u.guid
    end
    return u
  end

  ---Create comms jamming state slices with minimal defaults
  ---@param overrides? table
  ---@return table
  local function makeJammingState(overrides)
    overrides = overrides or {}
    return {
      jammers = overrides.jammers or {},
      iads = overrides.iads or {
        rocc = {},
        taaoc = {},
      },
      aircraft = overrides.aircraft or {},
      aew = overrides.aew or {},
    }
  end

  ---Wrap comms jamming slices into the save data shape they are read from
  ---@param jammingState table Slices built by makeJammingState
  ---@param enabled? boolean Whether China comms jamming is enabled, defaults to true
  ---@return table
  local function makeSaveData(jammingState, enabled)
    return {
      red = { commsJamming = { enabled = enabled ~= false, jammers = jammingState.jammers } },
      blue = {
        iads = jammingState.iads,
        air = { ac = jammingState.aircraft, aew = jammingState.aew },
      },
    }
  end

  ---Create a deterministic math.random stub that dispatches by argument signature
  ---@param noArgReturn? number Value returned for math.random() (no args), defaults to 0.1
  ---@return function
  local function makeRandomFn(noArgReturn)
    noArgReturn = noArgReturn or 0.1
    return function(a, b)
      if a == nil and b == nil then return noArgReturn end
      if b then return a end
      return 1
    end
  end

  -- ============================================================================
  -- process
  -- ============================================================================

  describe("process", function()
    local commsJammingConfig

    ---Run one comms jamming tick with the given config section against the given slices
    ---@param jammingConfig table China commsJamming config section
    ---@param jammingState table Slices built by makeJammingState
    local function runCommsJamming(jammingConfig, jammingState)
      local cfg = { red = { commsJamming = jammingConfig } }
      CommsJamming.process(cfg, makeSaveData(jammingState))
    end

    before_each(function()
      commsJammingConfig = makeCommsJammingConfig()
    end)

    -- Negative: a disabled jamming side does nothing at all
    it("should not touch any unit when comms jamming is disabled", function()
      local jammingState = makeJammingState({ jammers = { ["J-001"] = makeJammerState({ guid = "J-001" }) } })
      local cfg = { red = { commsJamming = commsJammingConfig } }

      local getUnitStub = trackStub(stub(GameApi, "ScenEdit_GetUnit"))

      CommsJamming.process(cfg, makeSaveData(jammingState, false))

      assert.stub(getUnitStub).was_not.called()
    end)

    -- ============================================================================
    -- Jammer Discovery
    -- ============================================================================

    describe("jammer discovery", function()
      -- Positive: finds airborne jammers with jammer capability
      it("should process active airborne jammers", function()
        local jammingState = makeJammingState({
          jammers = { ["J-001"] = makeJammerState({ guid = "J-001" }) },
          iads = {
            rocc = {
              ["C2-001"] = makeC2State({
                sam = { ["SAM-001"] = makeRadarState({ guid = "SAM-001" }) },
              }),
            },
            taaoc = {},
          },
        })

        trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
          if guid == "J-001" then
            return makeUnit({ guid = "J-001", condition = "Airborne", jammer = true })
          end
          if guid == "SAM-001" then return makeUnit({ guid = "SAM-001" }) end
          return nil
        end))
        trackStub(stub(GameApi, "Tool_Range").returns(20))
        trackStub(stub(GameApi, "ScenEdit_SetUnit"))
        trackStub(stub(math, "random").invokes(makeRandomFn()))

        runCommsJamming(commsJammingConfig, jammingState)

        -- SAM-001 should have been processed by the jammer
        assert.is_true(jammingState.iads.rocc["C2-001"].sam["SAM-001"].isOutOfComms)
      end)

      -- Negative: non-airborne jammers are skipped
      it("should skip non-airborne jammers", function()
        local samState = makeRadarState({ guid = "SAM-001" })
        local jammingState = makeJammingState({
          jammers = { ["J-001"] = makeJammerState({ guid = "J-001" }) },
          iads = {
            rocc = { ["C2-001"] = makeC2State({ sam = { ["SAM-001"] = samState } }) },
            taaoc = {},
          },
        })

        trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
          if guid == "J-001" then
            return makeUnit({ guid = "J-001", condition = "OnGround", jammer = true })
          end
          if guid == "SAM-001" then return makeUnit({ guid = "SAM-001" }) end
          return nil
        end))
        trackStub(stub(GameApi, "Tool_Range").returns(20))
        trackStub(stub(GameApi, "ScenEdit_SetUnit"))
        trackStub(stub(math, "random").invokes(makeRandomFn()))

        runCommsJamming(commsJammingConfig, jammingState)

        assert.is_false(samState.isOutOfComms)
        assert.are.equal(0, samState.outofcomms)
      end)

      -- Negative: jammers without jammer capability are skipped
      it("should skip jammers without jammer capability", function()
        local samState = makeRadarState({ guid = "SAM-001" })
        local jammingState = makeJammingState({
          jammers = { ["J-001"] = makeJammerState({ guid = "J-001" }) },
          iads = {
            rocc = { ["C2-001"] = makeC2State({ sam = { ["SAM-001"] = samState } }) },
            taaoc = {},
          },
        })

        trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
          if guid == "J-001" then
            return makeUnit({ guid = "J-001", condition = "Airborne", jammer = false })
          end
          if guid == "SAM-001" then return makeUnit({ guid = "SAM-001" }) end
          return nil
        end))
        trackStub(stub(GameApi, "Tool_Range").returns(20))
        trackStub(stub(GameApi, "ScenEdit_SetUnit"))
        trackStub(stub(math, "random").invokes(makeRandomFn()))

        runCommsJamming(commsJammingConfig, jammingState)

        assert.is_false(samState.isOutOfComms)
      end)

      -- Negative: unresolvable jammers are skipped
      it("should skip jammers that cannot be resolved", function()
        local jammingState = makeJammingState({
          jammers = { ["J-MISSING"] = makeJammerState({ guid = "J-MISSING" }) },
        })

        trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(nil))
        trackStub(stub(GameApi, "Tool_Range").returns(20))
        trackStub(stub(GameApi, "ScenEdit_SetUnit"))
        trackStub(stub(math, "random").invokes(makeRandomFn()))

        runCommsJamming(commsJammingConfig, jammingState)
      end)
    end)

    -- ============================================================================
    -- SAM/Radar Target Collection
    -- ============================================================================

    describe("SAM/Radar target collection", function()
      -- Positive: collects SAM and radar from ROCC
      it("should collect SAM and radar from ROCC for jamming", function()
        local samState = makeRadarState({ guid = "SAM-001" })
        local radarState = makeRadarState({ guid = "RADAR-001", name = "Radar Bravo" })
        local jammingState = makeJammingState({
          jammers = { ["J-001"] = makeJammerState({ guid = "J-001" }) },
          iads = {
            rocc = {
              ["C2-001"] = makeC2State({
                sam = { ["SAM-001"] = samState },
                radar = { ["RADAR-001"] = radarState },
              }),
            },
            taaoc = {},
          },
        })

        trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
          if guid == "J-001" then
            return makeUnit({ guid = "J-001", condition = "Airborne", jammer = true })
          end
          if guid == "SAM-001" then return makeUnit({ guid = "SAM-001" }) end
          if guid == "RADAR-001" then return makeUnit({ guid = "RADAR-001" }) end
          return nil
        end))
        trackStub(stub(GameApi, "Tool_Range").returns(20))
        trackStub(stub(GameApi, "ScenEdit_SetUnit"))
        trackStub(stub(math, "random").invokes(makeRandomFn()))

        runCommsJamming(commsJammingConfig, jammingState)

        -- Both should be processed (jammed) since jammer is active
        assert.is_true(samState.isOutOfComms)
        assert.is_true(radarState.isOutOfComms)
      end)

      -- Positive: collects SAM from TAAOC
      it("should collect SAM from TAAOC for jamming", function()
        local samState = makeRadarState({ guid = "TAAOC-SAM-001" })
        local jammingState = makeJammingState({
          jammers = { ["J-001"] = makeJammerState({ guid = "J-001" }) },
          iads = {
            rocc = {},
            taaoc = {
              ["TC-001"] = makeC2State({ sam = { ["TAAOC-SAM-001"] = samState } }),
            },
          },
        })

        trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
          if guid == "J-001" then
            return makeUnit({ guid = "J-001", condition = "Airborne", jammer = true })
          end
          if guid == "TAAOC-SAM-001" then return makeUnit({ guid = "TAAOC-SAM-001" }) end
          return nil
        end))
        trackStub(stub(GameApi, "Tool_Range").returns(20))
        trackStub(stub(GameApi, "ScenEdit_SetUnit"))
        trackStub(stub(math, "random").invokes(makeRandomFn()))

        runCommsJamming(commsJammingConfig, jammingState)

        assert.is_true(samState.isOutOfComms)
      end)
    end)

    -- ============================================================================
    -- Communication Recovery
    -- ============================================================================

    describe("communication recovery", function()
      -- Positive: increments counter during recovery period
      it("should increment outofcomms counter during recovery period", function()
        local samState = makeRadarState({ guid = "SAM-001", isOutOfComms = true, outofcomms = 2 })
        local jammingState = makeJammingState({
          iads = {
            rocc = { ["C2-001"] = makeC2State({ sam = { ["SAM-001"] = samState } }) },
            taaoc = {},
          },
        })

        trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(nil))
        local stubSetUnit = trackStub(stub(GameApi, "ScenEdit_SetUnit"))
        -- math.random(5, 10) -> 5; outofcomms(2) <= 5 -> increment
        trackStub(stub(math, "random").invokes(makeRandomFn()))

        runCommsJamming(commsJammingConfig, jammingState)

        assert.stub(stubSetUnit).was.called()
        assert.are.equal(3, samState.outofcomms)
        assert.is_true(samState.isOutOfComms)
      end)

      -- Positive: recovers comms when recovery time is exceeded
      it("should recover comms when outofcomms exceeds recovery time", function()
        local samState = makeRadarState({ guid = "SAM-001", isOutOfComms = true, outofcomms = 12 })
        local jammingState = makeJammingState({
          iads = {
            rocc = { ["C2-001"] = makeC2State({ sam = { ["SAM-001"] = samState } }) },
            taaoc = {},
          },
        })

        trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(nil))
        local stubSetUnit = trackStub(stub(GameApi, "ScenEdit_SetUnit"))
        -- math.random(5, 10) -> 5; outofcomms(12) > 5 -> recovery
        trackStub(stub(math, "random").invokes(makeRandomFn()))

        runCommsJamming(commsJammingConfig, jammingState)

        assert.stub(stubSetUnit).was.called()
        assert.are.equal(0, samState.outofcomms)
        assert.is_false(samState.isOutOfComms)
      end)

      -- Positive: clears external outOfComms flag for non-jammed unit
      it("should clear external outOfComms state for non-jammed unit", function()
        local samState = makeRadarState({ guid = "SAM-001", isOutOfComms = false, outofcomms = 0 })
        local jammingState = makeJammingState({
          iads = {
            rocc = { ["C2-001"] = makeC2State({ sam = { ["SAM-001"] = samState } }) },
            taaoc = {},
          },
        })

        trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
          if guid == "SAM-001" then
            return makeUnit({ guid = "SAM-001", outOfComms = true })
          end
          return nil
        end))
        local stubSetUnit = trackStub(stub(GameApi, "ScenEdit_SetUnit"))
        trackStub(stub(math, "random").invokes(makeRandomFn()))

        runCommsJamming(commsJammingConfig, jammingState)

        assert.stub(stubSetUnit).was.called()
        assert.are.equal(0, samState.outofcomms)
      end)

      -- Negative: does nothing when actual unit has no outOfComms
      it("should not modify context when actual unit has no outOfComms flag", function()
        local samState = makeRadarState({ guid = "SAM-001", isOutOfComms = false, outofcomms = 0 })
        local jammingState = makeJammingState({
          iads = {
            rocc = { ["C2-001"] = makeC2State({ sam = { ["SAM-001"] = samState } }) },
            taaoc = {},
          },
        })

        trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
          if guid == "SAM-001" then
            return makeUnit({ guid = "SAM-001", outOfComms = false })
          end
          return nil
        end))
        trackStub(stub(GameApi, "ScenEdit_SetUnit"))
        trackStub(stub(math, "random").invokes(makeRandomFn()))

        runCommsJamming(commsJammingConfig, jammingState)

        assert.are.equal(0, samState.outofcomms)
        assert.is_false(samState.isOutOfComms)
      end)
    end)

    -- ============================================================================
    -- Omnidirectional Jamming
    -- ============================================================================

    describe("omnidirectional jamming", function()
      -- Positive: applies jamming when effectiveness exceeds threshold
      it("should successfully jam a unit when effectiveness is sufficient", function()
        local samState = makeRadarState({ guid = "SAM-001", isOutOfComms = false, outofcomms = 0 })
        local jammingState = makeJammingState({
          jammers = { ["J-001"] = makeJammerState({ guid = "J-001" }) },
          iads = {
            rocc = { ["C2-001"] = makeC2State({ sam = { ["SAM-001"] = samState } }) },
            taaoc = {},
          },
        })

        trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
          if guid == "J-001" then
            return makeUnit({ guid = "J-001", condition = "Airborne", jammer = true })
          end
          if guid == "SAM-001" then return makeUnit({ guid = "SAM-001" }) end
          return nil
        end))
        trackStub(stub(GameApi, "Tool_Range").returns(20))
        trackStub(stub(GameApi, "ScenEdit_SetUnit"))
        -- math.random() -> 0.1, so threshold = 0.05; effectiveness at 20nm ≈ 0.89 > 0.05
        trackStub(stub(math, "random").invokes(makeRandomFn()))

        runCommsJamming(commsJammingConfig, jammingState)

        assert.is_true(samState.isOutOfComms)
        assert.are.equal(1, samState.outofcomms)
      end)

      -- Negative: jamming attempt fails when effectiveness is nil (distance exceeds range)
      it("should fail jamming when distance causes nil effectiveness", function()
        local samState = makeRadarState({ guid = "SAM-001", isOutOfComms = false, outofcomms = 0 })
        local jammingState = makeJammingState({
          jammers = { ["J-001"] = makeJammerState({ guid = "J-001" }) },
          iads = {
            rocc = { ["C2-001"] = makeC2State({ sam = { ["SAM-001"] = samState } }) },
            taaoc = {},
          },
        })

        trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
          if guid == "J-001" then
            return makeUnit({ guid = "J-001", condition = "Airborne", jammer = true })
          end
          if guid == "SAM-001" then return makeUnit({ guid = "SAM-001" }) end
          return nil
        end))
        -- distance=100, range=50 -> 100^1.9/50^1.8 > 1 -> effectiveness is nil
        trackStub(stub(GameApi, "Tool_Range").returns(100))
        trackStub(stub(GameApi, "ScenEdit_SetUnit"))
        trackStub(stub(math, "random").invokes(makeRandomFn()))

        runCommsJamming(commsJammingConfig, jammingState)

        -- Jamming fails: unit resets to not jammed
        assert.is_false(samState.isOutOfComms)
        assert.are.equal(0, samState.outofcomms)
      end)

      -- Boundary: respects limit of units a jammer can affect
      it("should respect the jammer unit limit", function()
        local samState1 = makeRadarState({ guid = "SAM-001" })
        local samState2 = makeRadarState({ guid = "SAM-002" })
        local samState3 = makeRadarState({ guid = "SAM-003" })
        local config = makeCommsJammingConfig({ limit = 2 })
        local jammingState = makeJammingState({
          jammers = { ["J-001"] = makeJammerState({ guid = "J-001" }) },
          iads = {
            rocc = {
              ["C2-001"] = makeC2State({
                sam = {
                  ["SAM-001"] = samState1,
                  ["SAM-002"] = samState2,
                  ["SAM-003"] = samState3,
                },
              }),
            },
            taaoc = {},
          },
        })

        trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
          if guid == "J-001" then
            return makeUnit({ guid = "J-001", condition = "Airborne", jammer = true })
          end
          return makeUnit({ guid = guid })
        end))
        trackStub(stub(GameApi, "Tool_Range").invokes(function(a, b)
          if b == "SAM-001" then return 10 end
          if b == "SAM-002" then return 20 end
          if b == "SAM-003" then return 30 end
          return 100
        end))
        trackStub(stub(GameApi, "ScenEdit_SetUnit"))
        trackStub(stub(math, "random").invokes(makeRandomFn()))

        runCommsJamming(config, jammingState)

        -- Only 2 closest units should be processed (limit = 2)
        local processedCount = 0
        for _, ctx in pairs({ samState1, samState2, samState3 }) do
          if ctx.outofcomms ~= 0 or ctx.isOutOfComms ~= false then
            processedCount = processedCount + 1
          end
        end
        assert.are.equal(2, processedCount)
      end)

      -- Negative: skips units when Tool_Range returns nil
      it("should skip units when distance cannot be calculated", function()
        local samState = makeRadarState({ guid = "SAM-001" })
        local jammingState = makeJammingState({
          jammers = { ["J-001"] = makeJammerState({ guid = "J-001" }) },
          iads = {
            rocc = { ["C2-001"] = makeC2State({ sam = { ["SAM-001"] = samState } }) },
            taaoc = {},
          },
        })

        trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
          if guid == "J-001" then
            return makeUnit({ guid = "J-001", condition = "Airborne", jammer = true })
          end
          if guid == "SAM-001" then return makeUnit({ guid = "SAM-001" }) end
          return nil
        end))
        trackStub(stub(GameApi, "Tool_Range").returns(nil))
        trackStub(stub(GameApi, "ScenEdit_SetUnit"))
        trackStub(stub(math, "random").invokes(makeRandomFn()))

        runCommsJamming(commsJammingConfig, jammingState)

        assert.is_false(samState.isOutOfComms)
        assert.are.equal(0, samState.outofcomms)
      end)

      -- Positive: transitions to cooldown when jamming time is exceeded
      it("should transition unit to cooldown when jamming time is exceeded", function()
        -- outofcomms=15 >= jammingTime(min=5) -> cooldown branch
        local samState = makeRadarState({ guid = "SAM-001", isOutOfComms = false, outofcomms = 15 })
        local jammingState = makeJammingState({
          jammers = { ["J-001"] = makeJammerState({ guid = "J-001" }) },
          iads = {
            rocc = { ["C2-001"] = makeC2State({ sam = { ["SAM-001"] = samState } }) },
            taaoc = {},
          },
        })

        trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
          if guid == "J-001" then
            return makeUnit({ guid = "J-001", condition = "Airborne", jammer = true })
          end
          if guid == "SAM-001" then return makeUnit({ guid = "SAM-001" }) end
          return nil
        end))
        trackStub(stub(GameApi, "Tool_Range").returns(20))
        trackStub(stub(GameApi, "ScenEdit_SetUnit"))
        -- math.random(min, max) returns min; cooldownTime min = -5
        trackStub(stub(math, "random").invokes(makeRandomFn()))

        runCommsJamming(commsJammingConfig, jammingState)

        assert.is_false(samState.isOutOfComms)
        assert.are.equal(-5, samState.outofcomms)
      end)

      -- Positive: increments counter during cooldown period (negative outofcomms)
      it("should increment counter during cooldown period", function()
        -- outofcomms=-3 < 0 -> cooldown recovery branch
        local samState = makeRadarState({ guid = "SAM-001", isOutOfComms = false, outofcomms = -3 })
        local jammingState = makeJammingState({
          jammers = { ["J-001"] = makeJammerState({ guid = "J-001" }) },
          iads = {
            rocc = { ["C2-001"] = makeC2State({ sam = { ["SAM-001"] = samState } }) },
            taaoc = {},
          },
        })

        trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
          if guid == "J-001" then
            return makeUnit({ guid = "J-001", condition = "Airborne", jammer = true })
          end
          if guid == "SAM-001" then return makeUnit({ guid = "SAM-001" }) end
          return nil
        end))
        trackStub(stub(GameApi, "Tool_Range").returns(20))
        trackStub(stub(GameApi, "ScenEdit_SetUnit"))
        trackStub(stub(math, "random").invokes(makeRandomFn()))

        runCommsJamming(commsJammingConfig, jammingState)

        assert.is_false(samState.isOutOfComms)
        assert.are.equal(-2, samState.outofcomms)
      end)

      -- Negative: does not apply jamming to already jammed units
      it("should not apply jamming to units already out of comms", function()
        local samState = makeRadarState({ guid = "SAM-001", isOutOfComms = true, outofcomms = 3 })
        local jammingState = makeJammingState({
          jammers = { ["J-001"] = makeJammerState({ guid = "J-001" }) },
          iads = {
            rocc = { ["C2-001"] = makeC2State({ sam = { ["SAM-001"] = samState } }) },
            taaoc = {},
          },
        })

        trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
          if guid == "J-001" then
            return makeUnit({ guid = "J-001", condition = "Airborne", jammer = true })
          end
          return nil
        end))
        trackStub(stub(GameApi, "Tool_Range").returns(20))
        trackStub(stub(GameApi, "ScenEdit_SetUnit"))
        -- Recovery: math.random(5,10)->5, outofcomms(3) <= 5 -> increment (recovery period)
        trackStub(stub(math, "random").invokes(makeRandomFn()))

        runCommsJamming(commsJammingConfig, jammingState)

        -- recoverComms should have incremented but jamming should be skipped
        -- because isOutOfComms is true (set by recoverComms staying in recovery)
        assert.is_true(samState.isOutOfComms)
        assert.are.equal(4, samState.outofcomms)
      end)
    end)

    -- ============================================================================
    -- Directional Jamming
    -- ============================================================================

    describe("directional jamming", function()
      -- Positive: applies directional jamming when bearing is aligned and distance is close
      it("should successfully jam when bearing is aligned and distance is close", function()
        local config = makeCommsJammingConfig({ mode = "directional" })
        local samState = makeRadarState({ guid = "SAM-001", isOutOfComms = false, outofcomms = 0 })
        local jammingState = makeJammingState({
          jammers = { ["J-001"] = makeJammerState({ guid = "J-001" }) },
          iads = {
            rocc = { ["C2-001"] = makeC2State({ sam = { ["SAM-001"] = samState } }) },
            taaoc = {},
          },
        })

        trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
          if guid == "J-001" then
            -- heading=0, bearing will be 5 -> orientation=5 < 12
            return makeUnit({ guid = "J-001", condition = "Airborne", jammer = true, heading = 0 })
          end
          if guid == "SAM-001" then return makeUnit({ guid = "SAM-001" }) end
          return nil
        end))
        -- distance=20 < random(75,100)=75
        trackStub(stub(GameApi, "Tool_Range").returns(20))
        -- bearing from jammer to target = 5
        trackStub(stub(GameApi, "Tool_Bearing").returns(5))
        trackStub(stub(GameApi, "ScenEdit_SetUnit"))
        trackStub(stub(math, "random").invokes(makeRandomFn()))

        runCommsJamming(config, jammingState)

        assert.is_true(samState.isOutOfComms)
        assert.are.equal(1, samState.outofcomms)
      end)

      -- Negative: directional jamming fails when bearing is misaligned
      it("should fail jamming when bearing is misaligned", function()
        local config = makeCommsJammingConfig({ mode = "directional" })
        local samState = makeRadarState({ guid = "SAM-001", isOutOfComms = false, outofcomms = 0 })
        local jammingState = makeJammingState({
          jammers = { ["J-001"] = makeJammerState({ guid = "J-001" }) },
          iads = {
            rocc = { ["C2-001"] = makeC2State({ sam = { ["SAM-001"] = samState } }) },
            taaoc = {},
          },
        })

        trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
          if guid == "J-001" then
            -- heading=0, bearing will be 90 -> orientation=90 > 12
            return makeUnit({ guid = "J-001", condition = "Airborne", jammer = true, heading = 0 })
          end
          if guid == "SAM-001" then return makeUnit({ guid = "SAM-001" }) end
          return nil
        end))
        trackStub(stub(GameApi, "Tool_Range").returns(20))
        -- bearing from jammer to target = 90 -> orientation = |90 - 0| = 90 > 12
        trackStub(stub(GameApi, "Tool_Bearing").returns(90))
        trackStub(stub(GameApi, "ScenEdit_SetUnit"))
        trackStub(stub(math, "random").invokes(makeRandomFn()))

        runCommsJamming(config, jammingState)

        assert.is_false(samState.isOutOfComms)
        assert.are.equal(0, samState.outofcomms)
      end)

      -- Negative: directional jamming fails when distance is too far
      it("should fail jamming when distance exceeds directional range", function()
        local config = makeCommsJammingConfig({ mode = "directional" })
        local samState = makeRadarState({ guid = "SAM-001", isOutOfComms = false, outofcomms = 0 })
        local jammingState = makeJammingState({
          jammers = { ["J-001"] = makeJammerState({ guid = "J-001" }) },
          iads = {
            rocc = { ["C2-001"] = makeC2State({ sam = { ["SAM-001"] = samState } }) },
            taaoc = {},
          },
        })

        trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
          if guid == "J-001" then
            return makeUnit({ guid = "J-001", condition = "Airborne", jammer = true, heading = 0 })
          end
          if guid == "SAM-001" then return makeUnit({ guid = "SAM-001" }) end
          return nil
        end))
        -- distance=80 > random(75,100)=75
        trackStub(stub(GameApi, "Tool_Range").returns(80))
        trackStub(stub(GameApi, "Tool_Bearing").returns(5))
        trackStub(stub(GameApi, "ScenEdit_SetUnit"))
        trackStub(stub(math, "random").invokes(makeRandomFn()))

        runCommsJamming(config, jammingState)

        assert.is_false(samState.isOutOfComms)
        assert.are.equal(0, samState.outofcomms)
      end)

      -- Boundary: mode switch uses correct strategy
      it("should use omnidirectional strategy by default and directional when configured", function()
        -- Same setup: distance=20, bearing=90 (misaligned for directional)
        -- Omnidirectional mode: effectiveness ≈ 0.89 > threshold -> JAMMED
        -- Directional mode: orientation=90 > 12 -> RESISTED
        local samStateOmni = makeRadarState({ guid = "SAM-001", isOutOfComms = false, outofcomms = 0 })
        local jammingStateOmni = makeJammingState({
          jammers = { ["J-001"] = makeJammerState({ guid = "J-001" }) },
          iads = {
            rocc = { ["C2-001"] = makeC2State({ sam = { ["SAM-001"] = samStateOmni } }) },
            taaoc = {},
          },
        })

        trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
          if guid == "J-001" then
            return makeUnit({ guid = "J-001", condition = "Airborne", jammer = true, heading = 0 })
          end
          if guid == "SAM-001" then return makeUnit({ guid = "SAM-001" }) end
          return nil
        end))
        trackStub(stub(GameApi, "Tool_Range").returns(20))
        trackStub(stub(GameApi, "Tool_Bearing").returns(90))
        trackStub(stub(GameApi, "ScenEdit_SetUnit"))
        trackStub(stub(math, "random").invokes(makeRandomFn()))

        -- Omnidirectional: should jam (effectiveness > threshold)
        runCommsJamming(makeCommsJammingConfig({ mode = "omnidirectional" }), jammingStateOmni)
        assert.is_true(samStateOmni.isOutOfComms)

        -- Directional with same setup: bearing misaligned -> should NOT jam
        local samStateDir = makeRadarState({ guid = "SAM-001", isOutOfComms = false, outofcomms = 0 })
        local jammingStateDir = makeJammingState({
          jammers = { ["J-001"] = makeJammerState({ guid = "J-001" }) },
          iads = {
            rocc = { ["C2-001"] = makeC2State({ sam = { ["SAM-001"] = samStateDir } }) },
            taaoc = {},
          },
        })

        runCommsJamming(makeCommsJammingConfig({ mode = "directional" }), jammingStateDir)
        assert.is_false(samStateDir.isOutOfComms)
      end)
    end)

    -- ============================================================================
    -- Aircraft Communication Quality
    -- ============================================================================

    describe("aircraft communication quality", function()
      -- Positive: orders RTB when comms level drops below threshold
      it("should order RTB when comms level drops below threshold", function()
        local aircraftState = makeAircraftState({ guid = "AC-001", commsBase = 40, commsThreshold = 30 })
        local jammingState = makeJammingState({ aircraft = { ["AC-001"] = aircraftState } })

        trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
          if guid == "AC-001" then
            return makeUnit({ guid = "AC-001", condition = "Airborne" })
          end
          return nil
        end))
        trackStub(stub(GameApi, "Tool_Range").returns(50))
        local stubSetUnit = trackStub(stub(GameApi, "ScenEdit_SetUnit"))
        trackStub(stub(math, "random").invokes(makeRandomFn()))

        -- getCommsLevel: initialComms(-20), no jammers/AEW/ROCC -> commModifier = -20
        -- commsLevel = commsBase(40) + (-20) = 20 < threshold(30) -> RTB
        runCommsJamming(commsJammingConfig, jammingState)

        assert.are.equal(20, aircraftState.commsLevel)
        local rtbCalled = false
        for _, call in ipairs(stubSetUnit.calls) do
          local args = call.vals[1]
          if args and args.guid == "AC-001" and args.RTB == true then
            rtbCalled = true
            break
          end
        end
        assert.is_true(rtbCalled)
      end)

      -- Negative: does not order RTB when comms level is above threshold
      it("should not order RTB when comms level is above threshold", function()
        local aircraftState = makeAircraftState({ guid = "AC-001", commsBase = 100, commsThreshold = 30 })
        local jammingState = makeJammingState({ aircraft = { ["AC-001"] = aircraftState } })

        trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
          if guid == "AC-001" then
            return makeUnit({ guid = "AC-001", condition = "Airborne" })
          end
          return nil
        end))
        trackStub(stub(GameApi, "Tool_Range").returns(50))
        local stubSetUnit = trackStub(stub(GameApi, "ScenEdit_SetUnit"))
        trackStub(stub(math, "random").invokes(makeRandomFn()))

        -- commsLevel = 100 + (-20) = 80 > 30 -> no RTB
        runCommsJamming(commsJammingConfig, jammingState)

        assert.are.equal(80, aircraftState.commsLevel)
        for _, call in ipairs(stubSetUnit.calls) do
          local args = call.vals[1]
          if args and args.guid == "AC-001" then
            assert.is_nil(args.RTB)
          end
        end
      end)

      -- Negative: skips non-airborne aircraft
      it("should skip non-airborne aircraft", function()
        local aircraftState = makeAircraftState({ guid = "AC-001", commsLevel = 100 })
        local jammingState = makeJammingState({ aircraft = { ["AC-001"] = aircraftState } })

        trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
          if guid == "AC-001" then
            return makeUnit({ guid = "AC-001", condition = "OnGround" })
          end
          return nil
        end))
        trackStub(stub(GameApi, "Tool_Range").returns(50))
        trackStub(stub(GameApi, "ScenEdit_SetUnit"))
        trackStub(stub(math, "random").invokes(makeRandomFn()))

        runCommsJamming(commsJammingConfig, jammingState)

        -- commsLevel should remain unchanged
        assert.are.equal(100, aircraftState.commsLevel)
      end)

      -- Negative: skips unresolvable aircraft
      it("should skip aircraft that cannot be resolved", function()
        local aircraftState = makeAircraftState({ guid = "AC-MISSING", commsLevel = 100 })
        local jammingState = makeJammingState({ aircraft = { ["AC-MISSING"] = aircraftState } })

        trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(nil))
        trackStub(stub(GameApi, "Tool_Range").returns(50))
        trackStub(stub(GameApi, "ScenEdit_SetUnit"))
        trackStub(stub(math, "random").invokes(makeRandomFn()))

        runCommsJamming(commsJammingConfig, jammingState)

        assert.are.equal(100, aircraftState.commsLevel)
      end)

      -- Positive: includes AEW support in comms level calculation
      it("should factor AEW support into comms level calculation", function()
        local aircraftState = makeAircraftState({ guid = "AC-001", commsBase = 0, commsThreshold = -9999 })
        local aewState = makeAircraftState({ guid = "AEW-001" })
        local jammingState = makeJammingState({
          aircraft = { ["AC-001"] = aircraftState },
          aew = { ["AEW-001"] = aewState },
        })

        trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
          if guid == "AC-001" then
            return makeUnit({ guid = "AC-001", condition = "Airborne" })
          end
          if guid == "AEW-001" then
            return makeUnit({ guid = "AEW-001", condition = "Airborne" })
          end
          return nil
        end))
        -- AEW at 50nm -> "close" category (< 100)
        trackStub(stub(GameApi, "Tool_Range").returns(50))
        trackStub(stub(GameApi, "ScenEdit_SetUnit"))
        -- math.random(min, max) returns min; variance.close.min = -1
        trackStub(stub(math, "random").invokes(makeRandomFn()))

        -- getCommsLevel: initialComms(-20) + aewSupport.close(400) + variance(-1) = 379
        -- commsLevel = commsBase(0) + 379 = 379
        runCommsJamming(commsJammingConfig, jammingState)

        assert.are.equal(379, aircraftState.commsLevel)
      end)

      -- Positive: includes ROCC support in comms level calculation
      it("should factor ROCC support into comms level calculation", function()
        local aircraftState = makeAircraftState({ guid = "AC-001", commsBase = 0, commsThreshold = -9999 })
        local jammingState = makeJammingState({
          aircraft = { ["AC-001"] = aircraftState },
          iads = {
            rocc = {
              ["C2-001"] = makeC2State({ guid = "ROCC-001" }),
            },
            taaoc = {},
          },
        })

        trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
          if guid == "AC-001" then
            return makeUnit({ guid = "AC-001", condition = "Airborne" })
          end
          if guid == "ROCC-001" then
            return makeUnit({ guid = "ROCC-001" })
          end
          return nil
        end))
        -- ROCC at 50nm -> "close" category (< 100)
        trackStub(stub(GameApi, "Tool_Range").returns(50))
        trackStub(stub(GameApi, "ScenEdit_SetUnit"))
        trackStub(stub(math, "random").invokes(makeRandomFn()))

        -- getCommsLevel: initialComms(-20) + aewSupport.close(400) + variance(-1) = 379
        -- commsLevel = commsBase(0) + 379 = 379
        runCommsJamming(commsJammingConfig, jammingState)

        assert.are.equal(379, aircraftState.commsLevel)
      end)

      -- Boundary: only first valid ROCC is processed
      it("should only use the first valid ROCC for comms calculation", function()
        local aircraftState = makeAircraftState({ guid = "AC-001", commsBase = 0, commsThreshold = -9999 })
        local jammingState = makeJammingState({
          aircraft = { ["AC-001"] = aircraftState },
          iads = {
            rocc = {
              ["C2-001"] = makeC2State({ guid = "ROCC-001" }),
              ["C2-002"] = makeC2State({ guid = "ROCC-002" }),
            },
            taaoc = {},
          },
        })

        trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
          if guid == "AC-001" then
            return makeUnit({ guid = "AC-001", condition = "Airborne" })
          end
          if guid == "ROCC-001" then return makeUnit({ guid = "ROCC-001" }) end
          if guid == "ROCC-002" then return makeUnit({ guid = "ROCC-002" }) end
          return nil
        end))
        trackStub(stub(GameApi, "Tool_Range").returns(50))
        trackStub(stub(GameApi, "ScenEdit_SetUnit"))
        trackStub(stub(math, "random").invokes(makeRandomFn()))

        -- getCommsLevel with ROCC has break after first valid: initialComms(-20) + aewSupport.close(400) + variance(-1) = 379
        -- Only one ROCC should contribute, NOT both
        runCommsJamming(commsJammingConfig, jammingState)

        assert.are.equal(379, aircraftState.commsLevel)
      end)

      -- Positive: includes jammer degradation in comms level calculation
      it("should factor active jammers into comms level degradation", function()
        local jammerState = makeJammerState({ guid = "J-001" })
        local aircraftState = makeAircraftState({ guid = "AC-001", commsBase = 200, commsThreshold = -9999 })
        local jammingState = makeJammingState({
          jammers = { ["J-001"] = jammerState },
          aircraft = { ["AC-001"] = aircraftState },
        })

        trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
          if guid == "J-001" then
            return makeUnit({ guid = "J-001", condition = "Airborne", jammer = true })
          end
          if guid == "AC-001" then
            return makeUnit({ guid = "AC-001", condition = "Airborne" })
          end
          return nil
        end))
        trackStub(stub(GameApi, "Tool_Range").returns(30))
        trackStub(stub(GameApi, "ScenEdit_SetUnit"))
        trackStub(stub(math, "random").invokes(makeRandomFn()))

        runCommsJamming(commsJammingConfig, jammingState)

        assert.is_true(aircraftState.commsLevel < 200)
      end)
    end)

    -- ============================================================================
    -- Empty Data Handling
    -- ============================================================================

    describe("empty data handling", function()
      -- Boundary: handles completely empty data without errors
      it("should handle empty jammers and empty targets gracefully", function()
        local jammingState = makeJammingState()

        trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(nil))
        trackStub(stub(GameApi, "Tool_Range").returns(50))
        trackStub(stub(GameApi, "ScenEdit_SetUnit"))
        trackStub(stub(math, "random").invokes(makeRandomFn()))

        runCommsJamming(commsJammingConfig, jammingState)
      end)
    end)
  end)

  -- ============================================================================
  -- init (jammers)
  -- ============================================================================

  describe("init (jammers)", function()
    local function makeSideMock(units)
      return {
        unitsBy = function(_, unitType)
          if unitType == constants.UNIT_TYPES.AIRCRAFT then
            return units
          end
          return {}
        end,
      }
    end

    -- Positive: creates state for Y-9 aircraft
    it("should create context for Y-9 aircraft", function()
      local saveData = makeSaveData(makeJammingState())

      trackStub(stub(GameApi, "VP_GetSide").returns(makeSideMock({ { guid = "Y9-001" } })))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
        if guid == "Y9-001" then
          return makeUnit({ guid = "Y9-001", dbid = constants.PLATFORMS.Y9, OODA = { evasion = 1 } })
        end
        return nil
      end))

      CommsJamming.init(config, saveData)

      assert.is_not_nil(saveData.red.commsJamming.jammers["Y9-001"])
      assert.are.equal("Y9-001", saveData.red.commsJamming.jammers["Y9-001"].guid)
      assert.are.equal(40, saveData.red.commsJamming.jammers["Y9-001"].commsLevel)
      assert.are.equal(40, saveData.red.commsJamming.jammers["Y9-001"].commsBase)
      assert.are.equal(30, saveData.red.commsJamming.jammers["Y9-001"].commsThreshold)
      assert.are.equal(0, saveData.red.commsJamming.jammers["Y9-001"].outofcomms)
    end)

    -- Positive: creates state for J-15D aircraft
    it("should create context for J-15D aircraft", function()
      local saveData = makeSaveData(makeJammingState())

      trackStub(stub(GameApi, "VP_GetSide").returns(makeSideMock({ { guid = "J15D-001" } })))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
        if guid == "J15D-001" then
          return makeUnit({ guid = "J15D-001", dbid = constants.PLATFORMS.J15D, OODA = {} })
        end
        return nil
      end))

      CommsJamming.init(config, saveData)

      assert.is_not_nil(saveData.red.commsJamming.jammers["J15D-001"])
      assert.are.equal("J15D-001", saveData.red.commsJamming.jammers["J15D-001"].guid)
    end)

    -- Positive: creates state for J-16D aircraft
    it("should create context for J-16D aircraft", function()
      local saveData = makeSaveData(makeJammingState())

      trackStub(stub(GameApi, "VP_GetSide").returns(makeSideMock({ { guid = "J16D-001" } })))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
        if guid == "J16D-001" then
          return makeUnit({ guid = "J16D-001", dbid = constants.PLATFORMS.J16D, OODA = {} })
        end
        return nil
      end))

      CommsJamming.init(config, saveData)

      assert.is_not_nil(saveData.red.commsJamming.jammers["J16D-001"])
      assert.are.equal("J16D-001", saveData.red.commsJamming.jammers["J16D-001"].guid)
    end)

    -- Negative: a disabled jamming side registers no jammers
    it("should not scan aircraft when comms jamming is disabled", function()
      local saveData = makeSaveData(makeJammingState(), false)
      local getSideStub = trackStub(stub(GameApi, "VP_GetSide").returns(makeSideMock({})))

      CommsJamming.init(config, saveData)

      assert.stub(getSideStub).was_not.called_with({ side = constants.SIDES.RED })
    end)

    -- Negative: skips non-EW aircraft
    it("should skip aircraft that are not EW platforms", function()
      local saveData = makeSaveData(makeJammingState())

      trackStub(stub(GameApi, "VP_GetSide").returns(makeSideMock({ { guid = "F16-001" } })))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
        if guid == "F16-001" then
          return makeUnit({ guid = "F16-001", dbid = 9999, OODA = {} })
        end
        return nil
      end))

      CommsJamming.init(config, saveData)

      assert.is_nil(saveData.red.commsJamming.jammers["F16-001"])
    end)

    -- Negative: handles nil aircraft list
    it("should handle when VP_GetSide returns no aircraft", function()
      local saveData = makeSaveData(makeJammingState())

      trackStub(stub(GameApi, "VP_GetSide").returns({
        unitsBy = function() return nil end,
      }))

      CommsJamming.init(config, saveData)

      assert.are.equal(0, Utils.getCount(saveData.red.commsJamming.jammers))
    end)

    -- Negative: skips unresolvable units
    it("should skip aircraft that cannot be resolved", function()
      local saveData = makeSaveData(makeJammingState())

      trackStub(stub(GameApi, "VP_GetSide").returns(makeSideMock({ { guid = "GHOST-001" } })))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(nil))

      CommsJamming.init(config, saveData)

      assert.are.equal(0, Utils.getCount(saveData.red.commsJamming.jammers))
    end)

    -- Positive: creates states for multiple EW aircraft types
    it("should create contexts for mixed EW aircraft types", function()
      local saveData = makeSaveData(makeJammingState())

      trackStub(stub(GameApi, "VP_GetSide").returns(makeSideMock({
        { guid = "Y9-001" },
        { guid = "J15D-001" },
        { guid = "J16D-001" },
        { guid = "F16-001" },
      })))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
        if guid == "Y9-001" then
          return makeUnit({ guid = "Y9-001", dbid = constants.PLATFORMS.Y9, OODA = {} })
        end
        if guid == "J15D-001" then
          return makeUnit({ guid = "J15D-001", dbid = constants.PLATFORMS.J15D, OODA = {} })
        end
        if guid == "J16D-001" then
          return makeUnit({ guid = "J16D-001", dbid = constants.PLATFORMS.J16D, OODA = {} })
        end
        if guid == "F16-001" then
          return makeUnit({ guid = "F16-001", dbid = 9999, OODA = {} })
        end
        return nil
      end))

      CommsJamming.init(config, saveData)

      assert.is_not_nil(saveData.red.commsJamming.jammers["Y9-001"])
      assert.is_not_nil(saveData.red.commsJamming.jammers["J15D-001"])
      assert.is_not_nil(saveData.red.commsJamming.jammers["J16D-001"])
      assert.is_nil(saveData.red.commsJamming.jammers["F16-001"])
    end)
  end)

  -- ============================================================================
  -- updateTargetAircraft
  -- ============================================================================

  describe("updateTargetAircraft", function()
    local function makeSideMock(units)
      return {
        unitsBy = function()
          return units
        end,
      }
    end

    -- Positive: E-2K goes to AEW, other aircraft go to AC, both with comms defaults
    it("should split AEW from other aircraft and apply comms defaults", function()
      local saveData = makeSaveData(makeJammingState())
      local defaults = config.red.commsJamming.aircraftDefaults
      local units = {
        ["E2K-1"] = makeUnit({ guid = "E2K-1", type = constants.UNIT_TYPES.AIRCRAFT, dbid = constants.PLATFORMS.E2K }),
        ["F16-1"] = makeUnit({ guid = "F16-1", type = constants.UNIT_TYPES.AIRCRAFT, dbid = 1 }),
      }
      local getSideStub = trackStub(stub(GameApi, "VP_GetSide").returns(makeSideMock({ { guid = "E2K-1" }, { guid = "F16-1" } })))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
        return units[guid]
      end))

      CommsJamming.updateTargetAircraft(config, saveData)

      local aircraftState = saveData.blue.air
      assert.stub(getSideStub).was.called_with({ side = constants.SIDES.BLUE })
      assert.are.equal(1, Utils.getCount(aircraftState.aew))
      assert.are.equal(1, Utils.getCount(aircraftState.ac))
      assert.is_not_nil(aircraftState.aew["E2K-1"])
      assert.is_not_nil(aircraftState.ac["F16-1"])
      assert.are.equal(defaults.commsLevel, aircraftState.ac["F16-1"].commsLevel)
      assert.are.equal(defaults.outOfComms, aircraftState.aew["E2K-1"].outofcomms)
    end)

    -- Edge: stale entries are cleared even when the side has no aircraft
    it("should clear stale entries when no aircraft are found", function()
      local saveData = makeSaveData(makeJammingState({ aircraft = { old = {} }, aew = { old = {} } }))
      trackStub(stub(GameApi, "VP_GetSide").returns(makeSideMock(nil)))

      CommsJamming.updateTargetAircraft(config, saveData)

      assert.are.same({}, saveData.blue.air.aew)
      assert.are.same({}, saveData.blue.air.ac)
    end)
  end)

  -- ============================================================================
  -- removeDestroyedUnit
  -- ============================================================================

  describe("removeDestroyedUnit", function()
    local function makeTrackedState()
      return {
        jammers = { ["Y9-1"] = {}, ["J16D-1"] = {} },
        iads = {},
        aircraft = { ["F16-1"] = {} },
        aew = { ["E2K-1"] = {} },
      }
    end

    -- Positive: a destroyed jammer stops jamming; other entries stay
    it("should remove a destroyed China jammer only", function()
      local jammingState = makeTrackedState()
      local unit = { guid = "Y9-1" }

      CommsJamming.removeDestroyedUnit(makeSaveData(jammingState), unit)

      assert.is_nil(jammingState.jammers["Y9-1"])
      assert.is_not_nil(jammingState.jammers["J16D-1"])
      assert.is_not_nil(jammingState.aircraft["F16-1"])
      assert.is_not_nil(jammingState.aew["E2K-1"])
    end)

    -- Positive: destroyed Taiwan aircraft and AEW both stop being jamming targets
    it("should remove destroyed Taiwan aircraft and AEW", function()
      local jammingState = makeTrackedState()
      local saveData = makeSaveData(jammingState)
      local unit1 = { guid = "F16-1" }
      local unit2 = { guid = "E2K-1" }

      CommsJamming.removeDestroyedUnit(saveData, unit1)
      CommsJamming.removeDestroyedUnit(saveData, unit2)

      assert.are.same({}, jammingState.aircraft)
      assert.are.same({}, jammingState.aew)
      assert.are.equal(2, Utils.getCount(jammingState.jammers))
    end)

    -- Edge: an untracked GUID is a no-op
    it("should leave all maps unchanged for an untracked unit", function()
      local jammingState = makeTrackedState()
      local saveData = makeSaveData(jammingState)
      local unit = { guid = "unknown" }

      CommsJamming.removeDestroyedUnit(saveData, unit)

      assert.are.same(makeTrackedState(), jammingState)
    end)
  end)
end)
