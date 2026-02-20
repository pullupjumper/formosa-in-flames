-- CommsJamming Unit Tests
---@diagnostic disable: undefined-field
local CommsJamming = require("src.modules.ew.commsJamming")
local GameApi = require("src.utils.gameApi")
local Utils = require("src.utils.utils")
local Logger = require("src.utils.logger")
local constants = require("src.core.constants")

describe("CommsJamming", function()
  local activeStubs

  local function trackStub(s)
    table.insert(activeStubs, s)
    return s
  end

  before_each(function()
    activeStubs = {}
    trackStub(stub(Logger, "log"))
    trackStub(stub(Logger, "warn"))
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
      range = 50,
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

  ---Create a jammer aircraft context
  ---@param overrides? table
  ---@return table
  local function makeJammerCtx(overrides)
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

  ---Create a radar/SAM unit context
  ---@param overrides? table
  ---@return table
  local function makeRadarCtx(overrides)
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

  ---Create an aircraft context for Taiwan air
  ---@param overrides? table
  ---@return table
  local function makeAircraftCtx(overrides)
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

  ---Create a C2 context (ROCC/TAAOC)
  ---@param overrides? table
  ---@return table
  local function makeC2Ctx(overrides)
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

  ---Create a full saveData structure with minimal defaults
  ---@param overrides? table
  ---@return table
  local function makeSaveData(overrides)
    overrides = overrides or {}
    return {
      c = {
        commsJamming = {
          jammers = overrides.jammers or {},
        },
      },
      t = {
        iads = overrides.iads or {
          rocc = {},
          taaoc = {},
        },
        air = {
          landBased = {
            AC = overrides.aircraft or {},
            AEW = overrides.aew or {},
          },
        },
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
  -- handleCommsJamming
  -- ============================================================================

  describe("handleCommsJamming", function()
    local commsJammingConfig

    before_each(function()
      commsJammingConfig = makeCommsJammingConfig()
    end)

    -- ============================================================================
    -- Jammer Discovery
    -- ============================================================================

    describe("jammer discovery", function()
      -- Positive: finds airborne jammers with jammer capability
      it("should process active airborne jammers", function()
        local saveData = makeSaveData({
          jammers = { ["J-001"] = makeJammerCtx({ guid = "J-001" }) },
          iads = {
            rocc = {
              ["C2-001"] = makeC2Ctx({
                sam = { ["SAM-001"] = makeRadarCtx({ guid = "SAM-001" }) },
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

        CommsJamming.handleCommsJamming(commsJammingConfig, saveData)

        -- SAM-001 should have been processed by the jammer
        assert.is_true(saveData.t.iads.rocc["C2-001"].sam["SAM-001"].isOutOfComms)
      end)

      -- Negative: non-airborne jammers are skipped
      it("should skip non-airborne jammers", function()
        local samCtx = makeRadarCtx({ guid = "SAM-001" })
        local saveData = makeSaveData({
          jammers = { ["J-001"] = makeJammerCtx({ guid = "J-001" }) },
          iads = {
            rocc = { ["C2-001"] = makeC2Ctx({ sam = { ["SAM-001"] = samCtx } }) },
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

        CommsJamming.handleCommsJamming(commsJammingConfig, saveData)

        assert.is_false(samCtx.isOutOfComms)
        assert.are.equal(0, samCtx.outofcomms)
      end)

      -- Negative: jammers without jammer capability are skipped
      it("should skip jammers without jammer capability", function()
        local samCtx = makeRadarCtx({ guid = "SAM-001" })
        local saveData = makeSaveData({
          jammers = { ["J-001"] = makeJammerCtx({ guid = "J-001" }) },
          iads = {
            rocc = { ["C2-001"] = makeC2Ctx({ sam = { ["SAM-001"] = samCtx } }) },
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

        CommsJamming.handleCommsJamming(commsJammingConfig, saveData)

        assert.is_false(samCtx.isOutOfComms)
      end)

      -- Negative: unresolvable jammers are skipped
      it("should skip jammers that cannot be resolved", function()
        local saveData = makeSaveData({
          jammers = { ["J-MISSING"] = makeJammerCtx({ guid = "J-MISSING" }) },
        })

        trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(nil))
        trackStub(stub(GameApi, "Tool_Range").returns(20))
        trackStub(stub(GameApi, "ScenEdit_SetUnit"))
        trackStub(stub(math, "random").invokes(makeRandomFn()))

        CommsJamming.handleCommsJamming(commsJammingConfig, saveData)
      end)
    end)

    -- ============================================================================
    -- SAM/Radar Target Collection
    -- ============================================================================

    describe("SAM/Radar target collection", function()
      -- Positive: collects SAM and radar from ROCC
      it("should collect SAM and radar from ROCC for jamming", function()
        local samCtx = makeRadarCtx({ guid = "SAM-001" })
        local radarCtx = makeRadarCtx({ guid = "RADAR-001", name = "Radar Bravo" })
        local saveData = makeSaveData({
          jammers = { ["J-001"] = makeJammerCtx({ guid = "J-001" }) },
          iads = {
            rocc = {
              ["C2-001"] = makeC2Ctx({
                sam = { ["SAM-001"] = samCtx },
                radar = { ["RADAR-001"] = radarCtx },
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

        CommsJamming.handleCommsJamming(commsJammingConfig, saveData)

        -- Both should be processed (jammed) since jammer is active
        assert.is_true(samCtx.isOutOfComms)
        assert.is_true(radarCtx.isOutOfComms)
      end)

      -- Positive: collects SAM from TAAOC
      it("should collect SAM from TAAOC for jamming", function()
        local samCtx = makeRadarCtx({ guid = "TAAOC-SAM-001" })
        local saveData = makeSaveData({
          jammers = { ["J-001"] = makeJammerCtx({ guid = "J-001" }) },
          iads = {
            rocc = {},
            taaoc = {
              ["TC-001"] = makeC2Ctx({ sam = { ["TAAOC-SAM-001"] = samCtx } }),
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

        CommsJamming.handleCommsJamming(commsJammingConfig, saveData)

        assert.is_true(samCtx.isOutOfComms)
      end)
    end)

    -- ============================================================================
    -- Communication Recovery
    -- ============================================================================

    describe("communication recovery", function()
      -- Positive: increments counter during recovery period
      it("should increment outofcomms counter during recovery period", function()
        local samCtx = makeRadarCtx({ guid = "SAM-001", isOutOfComms = true, outofcomms = 2 })
        local saveData = makeSaveData({
          iads = {
            rocc = { ["C2-001"] = makeC2Ctx({ sam = { ["SAM-001"] = samCtx } }) },
            taaoc = {},
          },
        })

        trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(nil))
        local stubSetUnit = trackStub(stub(GameApi, "ScenEdit_SetUnit"))
        -- math.random(5, 10) → 5; outofcomms(2) <= 5 → increment
        trackStub(stub(math, "random").invokes(makeRandomFn()))

        CommsJamming.handleCommsJamming(commsJammingConfig, saveData)

        assert.stub(stubSetUnit).was.called()
        assert.are.equal(3, samCtx.outofcomms)
        assert.is_true(samCtx.isOutOfComms)
      end)

      -- Positive: recovers comms when recovery time is exceeded
      it("should recover comms when outofcomms exceeds recovery time", function()
        local samCtx = makeRadarCtx({ guid = "SAM-001", isOutOfComms = true, outofcomms = 12 })
        local saveData = makeSaveData({
          iads = {
            rocc = { ["C2-001"] = makeC2Ctx({ sam = { ["SAM-001"] = samCtx } }) },
            taaoc = {},
          },
        })

        trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(nil))
        local stubSetUnit = trackStub(stub(GameApi, "ScenEdit_SetUnit"))
        -- math.random(5, 10) → 5; outofcomms(12) > 5 → recovery
        trackStub(stub(math, "random").invokes(makeRandomFn()))

        CommsJamming.handleCommsJamming(commsJammingConfig, saveData)

        assert.stub(stubSetUnit).was.called()
        assert.are.equal(0, samCtx.outofcomms)
        assert.is_false(samCtx.isOutOfComms)
      end)

      -- Positive: clears external outOfComms flag for non-jammed unit
      it("should clear external outOfComms state for non-jammed unit", function()
        local samCtx = makeRadarCtx({ guid = "SAM-001", isOutOfComms = false, outofcomms = 0 })
        local saveData = makeSaveData({
          iads = {
            rocc = { ["C2-001"] = makeC2Ctx({ sam = { ["SAM-001"] = samCtx } }) },
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

        CommsJamming.handleCommsJamming(commsJammingConfig, saveData)

        assert.stub(stubSetUnit).was.called()
        assert.are.equal(0, samCtx.outofcomms)
      end)

      -- Negative: does nothing when actual unit has no outOfComms
      it("should not modify context when actual unit has no outOfComms flag", function()
        local samCtx = makeRadarCtx({ guid = "SAM-001", isOutOfComms = false, outofcomms = 0 })
        local saveData = makeSaveData({
          iads = {
            rocc = { ["C2-001"] = makeC2Ctx({ sam = { ["SAM-001"] = samCtx } }) },
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

        CommsJamming.handleCommsJamming(commsJammingConfig, saveData)

        assert.are.equal(0, samCtx.outofcomms)
        assert.is_false(samCtx.isOutOfComms)
      end)
    end)

    -- ============================================================================
    -- Omnidirectional Jamming
    -- ============================================================================

    describe("omnidirectional jamming", function()
      -- Positive: applies jamming when effectiveness exceeds threshold
      it("should successfully jam a unit when effectiveness is sufficient", function()
        local samCtx = makeRadarCtx({ guid = "SAM-001", isOutOfComms = false, outofcomms = 0 })
        local saveData = makeSaveData({
          jammers = { ["J-001"] = makeJammerCtx({ guid = "J-001" }) },
          iads = {
            rocc = { ["C2-001"] = makeC2Ctx({ sam = { ["SAM-001"] = samCtx } }) },
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
        -- math.random() → 0.1, so threshold = 0.05; effectiveness at 20nm ≈ 0.89 > 0.05
        trackStub(stub(math, "random").invokes(makeRandomFn()))

        CommsJamming.handleCommsJamming(commsJammingConfig, saveData)

        assert.is_true(samCtx.isOutOfComms)
        assert.are.equal(1, samCtx.outofcomms)
      end)

      -- Negative: jamming attempt fails when effectiveness is nil (distance exceeds range)
      it("should fail jamming when distance causes nil effectiveness", function()
        local samCtx = makeRadarCtx({ guid = "SAM-001", isOutOfComms = false, outofcomms = 0 })
        local saveData = makeSaveData({
          jammers = { ["J-001"] = makeJammerCtx({ guid = "J-001" }) },
          iads = {
            rocc = { ["C2-001"] = makeC2Ctx({ sam = { ["SAM-001"] = samCtx } }) },
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
        -- distance=100, range=50 → 100^1.9/50^1.8 > 1 → effectiveness is nil
        trackStub(stub(GameApi, "Tool_Range").returns(100))
        trackStub(stub(GameApi, "ScenEdit_SetUnit"))
        trackStub(stub(math, "random").invokes(makeRandomFn()))

        CommsJamming.handleCommsJamming(commsJammingConfig, saveData)

        -- Jamming fails: unit resets to not jammed
        assert.is_false(samCtx.isOutOfComms)
        assert.are.equal(0, samCtx.outofcomms)
      end)

      -- Boundary: respects limit of units a jammer can affect
      it("should respect the jammer unit limit", function()
        local samCtx1 = makeRadarCtx({ guid = "SAM-001" })
        local samCtx2 = makeRadarCtx({ guid = "SAM-002" })
        local samCtx3 = makeRadarCtx({ guid = "SAM-003" })
        local config = makeCommsJammingConfig({ limit = 2 })
        local saveData = makeSaveData({
          jammers = { ["J-001"] = makeJammerCtx({ guid = "J-001" }) },
          iads = {
            rocc = {
              ["C2-001"] = makeC2Ctx({
                sam = {
                  ["SAM-001"] = samCtx1,
                  ["SAM-002"] = samCtx2,
                  ["SAM-003"] = samCtx3,
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

        CommsJamming.handleCommsJamming(config, saveData)

        -- Only 2 closest units should be processed (limit = 2)
        local processedCount = 0
        for _, ctx in pairs({ samCtx1, samCtx2, samCtx3 }) do
          if ctx.outofcomms ~= 0 or ctx.isOutOfComms ~= false then
            processedCount = processedCount + 1
          end
        end
        assert.are.equal(2, processedCount)
      end)

      -- Negative: skips units when Tool_Range returns nil
      it("should skip units when distance cannot be calculated", function()
        local samCtx = makeRadarCtx({ guid = "SAM-001" })
        local saveData = makeSaveData({
          jammers = { ["J-001"] = makeJammerCtx({ guid = "J-001" }) },
          iads = {
            rocc = { ["C2-001"] = makeC2Ctx({ sam = { ["SAM-001"] = samCtx } }) },
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

        CommsJamming.handleCommsJamming(commsJammingConfig, saveData)

        assert.is_false(samCtx.isOutOfComms)
        assert.are.equal(0, samCtx.outofcomms)
      end)

      -- Positive: transitions to cooldown when jamming time is exceeded
      it("should transition unit to cooldown when jamming time is exceeded", function()
        -- outofcomms=15 >= jammingTime(min=5) → cooldown branch
        local samCtx = makeRadarCtx({ guid = "SAM-001", isOutOfComms = false, outofcomms = 15 })
        local saveData = makeSaveData({
          jammers = { ["J-001"] = makeJammerCtx({ guid = "J-001" }) },
          iads = {
            rocc = { ["C2-001"] = makeC2Ctx({ sam = { ["SAM-001"] = samCtx } }) },
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

        CommsJamming.handleCommsJamming(commsJammingConfig, saveData)

        assert.is_false(samCtx.isOutOfComms)
        assert.are.equal(-5, samCtx.outofcomms)
      end)

      -- Positive: increments counter during cooldown period (negative outofcomms)
      it("should increment counter during cooldown period", function()
        -- outofcomms=-3 < 0 → cooldown recovery branch
        local samCtx = makeRadarCtx({ guid = "SAM-001", isOutOfComms = false, outofcomms = -3 })
        local saveData = makeSaveData({
          jammers = { ["J-001"] = makeJammerCtx({ guid = "J-001" }) },
          iads = {
            rocc = { ["C2-001"] = makeC2Ctx({ sam = { ["SAM-001"] = samCtx } }) },
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

        CommsJamming.handleCommsJamming(commsJammingConfig, saveData)

        assert.is_false(samCtx.isOutOfComms)
        assert.are.equal(-2, samCtx.outofcomms)
      end)

      -- Negative: does not apply jamming to already jammed units
      it("should not apply jamming to units already out of comms", function()
        local samCtx = makeRadarCtx({ guid = "SAM-001", isOutOfComms = true, outofcomms = 3 })
        local saveData = makeSaveData({
          jammers = { ["J-001"] = makeJammerCtx({ guid = "J-001" }) },
          iads = {
            rocc = { ["C2-001"] = makeC2Ctx({ sam = { ["SAM-001"] = samCtx } }) },
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
        -- Recovery: math.random(5,10)→5, outofcomms(3) <= 5 → increment (recovery period)
        trackStub(stub(math, "random").invokes(makeRandomFn()))

        CommsJamming.handleCommsJamming(commsJammingConfig, saveData)

        -- recoverComms should have incremented but jamming should be skipped
        -- because isOutOfComms is true (set by recoverComms staying in recovery)
        assert.is_true(samCtx.isOutOfComms)
        assert.are.equal(4, samCtx.outofcomms)
      end)
    end)

    -- ============================================================================
    -- Directional Jamming
    -- ============================================================================

    describe("directional jamming", function()
      -- Positive: applies directional jamming when bearing is aligned and distance is close
      it("should successfully jam when bearing is aligned and distance is close", function()
        local config = makeCommsJammingConfig({ mode = "directional" })
        local samCtx = makeRadarCtx({ guid = "SAM-001", isOutOfComms = false, outofcomms = 0 })
        local saveData = makeSaveData({
          jammers = { ["J-001"] = makeJammerCtx({ guid = "J-001" }) },
          iads = {
            rocc = { ["C2-001"] = makeC2Ctx({ sam = { ["SAM-001"] = samCtx } }) },
            taaoc = {},
          },
        })

        trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
          if guid == "J-001" then
            -- heading=0, bearing will be 5 → orientation=5 < 12
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

        CommsJamming.handleCommsJamming(config, saveData)

        assert.is_true(samCtx.isOutOfComms)
        assert.are.equal(1, samCtx.outofcomms)
      end)

      -- Negative: directional jamming fails when bearing is misaligned
      it("should fail jamming when bearing is misaligned", function()
        local config = makeCommsJammingConfig({ mode = "directional" })
        local samCtx = makeRadarCtx({ guid = "SAM-001", isOutOfComms = false, outofcomms = 0 })
        local saveData = makeSaveData({
          jammers = { ["J-001"] = makeJammerCtx({ guid = "J-001" }) },
          iads = {
            rocc = { ["C2-001"] = makeC2Ctx({ sam = { ["SAM-001"] = samCtx } }) },
            taaoc = {},
          },
        })

        trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
          if guid == "J-001" then
            -- heading=0, bearing will be 90 → orientation=90 > 12
            return makeUnit({ guid = "J-001", condition = "Airborne", jammer = true, heading = 0 })
          end
          if guid == "SAM-001" then return makeUnit({ guid = "SAM-001" }) end
          return nil
        end))
        trackStub(stub(GameApi, "Tool_Range").returns(20))
        -- bearing from jammer to target = 90 → orientation = |90 - 0| = 90 > 12
        trackStub(stub(GameApi, "Tool_Bearing").returns(90))
        trackStub(stub(GameApi, "ScenEdit_SetUnit"))
        trackStub(stub(math, "random").invokes(makeRandomFn()))

        CommsJamming.handleCommsJamming(config, saveData)

        assert.is_false(samCtx.isOutOfComms)
        assert.are.equal(0, samCtx.outofcomms)
      end)

      -- Negative: directional jamming fails when distance is too far
      it("should fail jamming when distance exceeds directional range", function()
        local config = makeCommsJammingConfig({ mode = "directional" })
        local samCtx = makeRadarCtx({ guid = "SAM-001", isOutOfComms = false, outofcomms = 0 })
        local saveData = makeSaveData({
          jammers = { ["J-001"] = makeJammerCtx({ guid = "J-001" }) },
          iads = {
            rocc = { ["C2-001"] = makeC2Ctx({ sam = { ["SAM-001"] = samCtx } }) },
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

        CommsJamming.handleCommsJamming(config, saveData)

        assert.is_false(samCtx.isOutOfComms)
        assert.are.equal(0, samCtx.outofcomms)
      end)

      -- Boundary: mode switch uses correct strategy
      it("should use omnidirectional strategy by default and directional when configured", function()
        -- Same setup: distance=20, bearing=90 (misaligned for directional)
        -- Omnidirectional mode: effectiveness ≈ 0.89 > threshold → JAMMED
        -- Directional mode: orientation=90 > 12 → RESISTED
        local samCtxOmni = makeRadarCtx({ guid = "SAM-001", isOutOfComms = false, outofcomms = 0 })
        local saveDataOmni = makeSaveData({
          jammers = { ["J-001"] = makeJammerCtx({ guid = "J-001" }) },
          iads = {
            rocc = { ["C2-001"] = makeC2Ctx({ sam = { ["SAM-001"] = samCtxOmni } }) },
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
        CommsJamming.handleCommsJamming(makeCommsJammingConfig({ mode = "omnidirectional" }), saveDataOmni)
        assert.is_true(samCtxOmni.isOutOfComms)

        -- Directional with same setup: bearing misaligned → should NOT jam
        local samCtxDir = makeRadarCtx({ guid = "SAM-001", isOutOfComms = false, outofcomms = 0 })
        local saveDataDir = makeSaveData({
          jammers = { ["J-001"] = makeJammerCtx({ guid = "J-001" }) },
          iads = {
            rocc = { ["C2-001"] = makeC2Ctx({ sam = { ["SAM-001"] = samCtxDir } }) },
            taaoc = {},
          },
        })

        CommsJamming.handleCommsJamming(makeCommsJammingConfig({ mode = "directional" }), saveDataDir)
        assert.is_false(samCtxDir.isOutOfComms)
      end)
    end)

    -- ============================================================================
    -- Aircraft Communication Quality
    -- ============================================================================

    describe("aircraft communication quality", function()
      -- Positive: orders RTB when comms level drops below threshold
      it("should order RTB when comms level drops below threshold", function()
        local aircraftCtx = makeAircraftCtx({ guid = "AC-001", commsBase = 40, commsThreshold = 30 })
        local saveData = makeSaveData({ aircraft = { ["AC-001"] = aircraftCtx } })

        trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
          if guid == "AC-001" then
            return makeUnit({ guid = "AC-001", condition = "Airborne" })
          end
          return nil
        end))
        trackStub(stub(GameApi, "Tool_Range").returns(50))
        local stubSetUnit = trackStub(stub(GameApi, "ScenEdit_SetUnit"))
        trackStub(stub(math, "random").invokes(makeRandomFn()))

        -- getCommsLevel: initialComms(-20), no jammers/AEW/ROCC → commModifier = -20
        -- commsLevel = commsBase(40) + (-20) = 20 < threshold(30) → RTB
        CommsJamming.handleCommsJamming(commsJammingConfig, saveData)

        assert.are.equal(20, aircraftCtx.commsLevel)
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
        local aircraftCtx = makeAircraftCtx({ guid = "AC-001", commsBase = 100, commsThreshold = 30 })
        local saveData = makeSaveData({ aircraft = { ["AC-001"] = aircraftCtx } })

        trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
          if guid == "AC-001" then
            return makeUnit({ guid = "AC-001", condition = "Airborne" })
          end
          return nil
        end))
        trackStub(stub(GameApi, "Tool_Range").returns(50))
        local stubSetUnit = trackStub(stub(GameApi, "ScenEdit_SetUnit"))
        trackStub(stub(math, "random").invokes(makeRandomFn()))

        -- commsLevel = 100 + (-20) = 80 > 30 → no RTB
        CommsJamming.handleCommsJamming(commsJammingConfig, saveData)

        assert.are.equal(80, aircraftCtx.commsLevel)
        for _, call in ipairs(stubSetUnit.calls) do
          local args = call.vals[1]
          if args and args.guid == "AC-001" then
            assert.is_nil(args.RTB)
          end
        end
      end)

      -- Negative: skips non-airborne aircraft
      it("should skip non-airborne aircraft", function()
        local aircraftCtx = makeAircraftCtx({ guid = "AC-001", commsLevel = 100 })
        local saveData = makeSaveData({ aircraft = { ["AC-001"] = aircraftCtx } })

        trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
          if guid == "AC-001" then
            return makeUnit({ guid = "AC-001", condition = "OnGround" })
          end
          return nil
        end))
        trackStub(stub(GameApi, "Tool_Range").returns(50))
        trackStub(stub(GameApi, "ScenEdit_SetUnit"))
        trackStub(stub(math, "random").invokes(makeRandomFn()))

        CommsJamming.handleCommsJamming(commsJammingConfig, saveData)

        -- commsLevel should remain unchanged
        assert.are.equal(100, aircraftCtx.commsLevel)
      end)

      -- Negative: skips unresolvable aircraft
      it("should skip aircraft that cannot be resolved", function()
        local aircraftCtx = makeAircraftCtx({ guid = "AC-MISSING", commsLevel = 100 })
        local saveData = makeSaveData({ aircraft = { ["AC-MISSING"] = aircraftCtx } })

        trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(nil))
        trackStub(stub(GameApi, "Tool_Range").returns(50))
        trackStub(stub(GameApi, "ScenEdit_SetUnit"))
        trackStub(stub(math, "random").invokes(makeRandomFn()))

        CommsJamming.handleCommsJamming(commsJammingConfig, saveData)

        assert.are.equal(100, aircraftCtx.commsLevel)
      end)

      -- Positive: includes AEW support in comms level calculation
      it("should factor AEW support into comms level calculation", function()
        local aircraftCtx = makeAircraftCtx({ guid = "AC-001", commsBase = 0, commsThreshold = -9999 })
        local aewCtx = makeAircraftCtx({ guid = "AEW-001" })
        local saveData = makeSaveData({
          aircraft = { ["AC-001"] = aircraftCtx },
          aew = { ["AEW-001"] = aewCtx },
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
        -- AEW at 50nm → "close" category (< 100)
        trackStub(stub(GameApi, "Tool_Range").returns(50))
        trackStub(stub(GameApi, "ScenEdit_SetUnit"))
        -- math.random(min, max) returns min; variance.close.min = -1
        trackStub(stub(math, "random").invokes(makeRandomFn()))

        -- getCommsLevel: initialComms(-20) + aewSupport.close(400) + variance(-1) = 379
        -- commsLevel = commsBase(0) + 379 = 379
        CommsJamming.handleCommsJamming(commsJammingConfig, saveData)

        assert.are.equal(379, aircraftCtx.commsLevel)
      end)

      -- Positive: includes ROCC support in comms level calculation
      it("should factor ROCC support into comms level calculation", function()
        local aircraftCtx = makeAircraftCtx({ guid = "AC-001", commsBase = 0, commsThreshold = -9999 })
        local saveData = makeSaveData({
          aircraft = { ["AC-001"] = aircraftCtx },
          iads = {
            rocc = {
              ["C2-001"] = makeC2Ctx({ guid = "ROCC-001" }),
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
        -- ROCC at 50nm → "close" category (< 100)
        trackStub(stub(GameApi, "Tool_Range").returns(50))
        trackStub(stub(GameApi, "ScenEdit_SetUnit"))
        trackStub(stub(math, "random").invokes(makeRandomFn()))

        -- getCommsLevel: initialComms(-20) + aewSupport.close(400) + variance(-1) = 379
        -- commsLevel = commsBase(0) + 379 = 379
        CommsJamming.handleCommsJamming(commsJammingConfig, saveData)

        assert.are.equal(379, aircraftCtx.commsLevel)
      end)

      -- Boundary: only first valid ROCC is processed
      it("should only use the first valid ROCC for comms calculation", function()
        local aircraftCtx = makeAircraftCtx({ guid = "AC-001", commsBase = 0, commsThreshold = -9999 })
        local saveData = makeSaveData({
          aircraft = { ["AC-001"] = aircraftCtx },
          iads = {
            rocc = {
              ["C2-001"] = makeC2Ctx({ guid = "ROCC-001" }),
              ["C2-002"] = makeC2Ctx({ guid = "ROCC-002" }),
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
        CommsJamming.handleCommsJamming(commsJammingConfig, saveData)

        assert.are.equal(379, aircraftCtx.commsLevel)
      end)

      -- Positive: includes jammer degradation in comms level calculation
      it("should factor active jammers into comms level degradation", function()
        local jammerCtx = makeJammerCtx({ guid = "J-001" })
        local aircraftCtx = makeAircraftCtx({ guid = "AC-001", commsBase = 200, commsThreshold = -9999 })
        local saveData = makeSaveData({
          jammers = { ["J-001"] = jammerCtx },
          aircraft = { ["AC-001"] = aircraftCtx },
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

        CommsJamming.handleCommsJamming(commsJammingConfig, saveData)

        assert.is_true(aircraftCtx.commsLevel < 200)
      end)
    end)

    -- ============================================================================
    -- Empty Data Handling
    -- ============================================================================

    describe("empty data handling", function()
      -- Boundary: handles completely empty data without errors
      it("should handle empty jammers and empty targets gracefully", function()
        local saveData = makeSaveData()

        trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(nil))
        trackStub(stub(GameApi, "Tool_Range").returns(50))
        trackStub(stub(GameApi, "ScenEdit_SetUnit"))
        trackStub(stub(math, "random").invokes(makeRandomFn()))

        CommsJamming.handleCommsJamming(commsJammingConfig, saveData)
      end)
    end)
  end)

  -- ============================================================================
  -- initCommsJammersContext
  -- ============================================================================

  describe("initCommsJammersContext", function()
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

    -- Positive: creates context for Y-9 aircraft
    it("should create context for Y-9 aircraft", function()
      local commsJammingCtx = { jammers = {} }

      trackStub(stub(GameApi, "VP_GetSide").returns(makeSideMock({ { guid = "Y9-001" } })))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
        if guid == "Y9-001" then
          return makeUnit({ guid = "Y9-001", dbid = constants.PLATFORMS.Y9, OODA = { evasion = 1 } })
        end
        return nil
      end))

      CommsJamming.initCommsJammersContext(commsJammingCtx, "China")

      assert.is_not_nil(commsJammingCtx.jammers["Y9-001"])
      assert.are.equal("Y9-001", commsJammingCtx.jammers["Y9-001"].guid)
      assert.are.equal(40, commsJammingCtx.jammers["Y9-001"].commsLevel)
      assert.are.equal(40, commsJammingCtx.jammers["Y9-001"].commsBase)
      assert.are.equal(30, commsJammingCtx.jammers["Y9-001"].commsThreshold)
      assert.are.equal(0, commsJammingCtx.jammers["Y9-001"].outofcomms)
    end)

    -- Positive: creates context for J-15D aircraft
    it("should create context for J-15D aircraft", function()
      local commsJammingCtx = { jammers = {} }

      trackStub(stub(GameApi, "VP_GetSide").returns(makeSideMock({ { guid = "J15D-001" } })))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
        if guid == "J15D-001" then
          return makeUnit({ guid = "J15D-001", dbid = constants.PLATFORMS.J15D, OODA = {} })
        end
        return nil
      end))

      CommsJamming.initCommsJammersContext(commsJammingCtx, "China")

      assert.is_not_nil(commsJammingCtx.jammers["J15D-001"])
      assert.are.equal("J15D-001", commsJammingCtx.jammers["J15D-001"].guid)
    end)

    -- Positive: creates context for J-16D aircraft
    it("should create context for J-16D aircraft", function()
      local commsJammingCtx = { jammers = {} }

      trackStub(stub(GameApi, "VP_GetSide").returns(makeSideMock({ { guid = "J16D-001" } })))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
        if guid == "J16D-001" then
          return makeUnit({ guid = "J16D-001", dbid = constants.PLATFORMS.J16D, OODA = {} })
        end
        return nil
      end))

      CommsJamming.initCommsJammersContext(commsJammingCtx, "China")

      assert.is_not_nil(commsJammingCtx.jammers["J16D-001"])
      assert.are.equal("J16D-001", commsJammingCtx.jammers["J16D-001"].guid)
    end)

    -- Negative: skips non-EW aircraft
    it("should skip aircraft that are not EW platforms", function()
      local commsJammingCtx = { jammers = {} }

      trackStub(stub(GameApi, "VP_GetSide").returns(makeSideMock({ { guid = "F16-001" } })))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
        if guid == "F16-001" then
          return makeUnit({ guid = "F16-001", dbid = 9999, OODA = {} })
        end
        return nil
      end))

      CommsJamming.initCommsJammersContext(commsJammingCtx, "China")

      assert.is_nil(commsJammingCtx.jammers["F16-001"])
    end)

    -- Negative: handles nil aircraft list
    it("should handle when VP_GetSide returns no aircraft", function()
      local commsJammingCtx = { jammers = {} }

      trackStub(stub(GameApi, "VP_GetSide").returns({
        unitsBy = function() return nil end,
      }))

      CommsJamming.initCommsJammersContext(commsJammingCtx, "China")

      assert.are.equal(0, Utils.getCount(commsJammingCtx.jammers))
    end)

    -- Negative: skips unresolvable units
    it("should skip aircraft that cannot be resolved", function()
      local commsJammingCtx = { jammers = {} }

      trackStub(stub(GameApi, "VP_GetSide").returns(makeSideMock({ { guid = "GHOST-001" } })))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(nil))

      CommsJamming.initCommsJammersContext(commsJammingCtx, "China")

      assert.are.equal(0, Utils.getCount(commsJammingCtx.jammers))
    end)

    -- Positive: creates contexts for multiple EW aircraft types
    it("should create contexts for mixed EW aircraft types", function()
      local commsJammingCtx = { jammers = {} }

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

      CommsJamming.initCommsJammersContext(commsJammingCtx, "China")

      assert.is_not_nil(commsJammingCtx.jammers["Y9-001"])
      assert.is_not_nil(commsJammingCtx.jammers["J15D-001"])
      assert.is_not_nil(commsJammingCtx.jammers["J16D-001"])
      assert.is_nil(commsJammingCtx.jammers["F16-001"])
    end)
  end)
end)
