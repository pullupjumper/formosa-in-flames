-- PersistentState Unit Tests
local PersistentState = require("src.core.persistentState")
local gKH = require("src.core.gKH_State_Standalone")
local Logger = require("src.utils.logger")
local constants = require("src.core.constants")

describe("PersistentState", function()
  ---@type luassert.spy[]
  local activeStubs
  ---@type luassert.spy
  local loadStub
  ---@type luassert.spy
  local saveStub
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
    errorStub = trackStub(stub(Logger, "error"))
    loadStub = trackStub(stub(gKH.State, "LoadTableFromKey"))
    saveStub = trackStub(stub(gKH.State, "SaveTableToKey"))
  end)

  after_each(function()
    for _, s in ipairs(activeStubs) do
      s:revert()
    end
    activeStubs = {}
  end)

  -- ============================================================================
  -- update
  -- ============================================================================

  describe("update", function()
    -- Positive: the table fn mutated is the one written back under the same key
    it("should save the mutated state back to the SaveData key", function()
      local state = { red = { counter = 1 } }
      loadStub.returns(state)

      local ran = PersistentState.update(function(s)
        s.red.counter = 2
      end)

      assert.is_true(ran)
      assert.are.equal(2, state.red.counter)
      assert.stub(loadStub).was.called_with("SaveData")
      assert.stub(saveStub).was.called_with(state, "SaveData")
    end)

    -- Negative: nothing saved means nothing to run against; must not overwrite the key
    it("should skip fn and save when no state is stored", function()
      loadStub.returns(nil)
      local fn = spy.new(function() end)

      local ran = PersistentState.update(fn)

      assert.is_false(ran)
      assert.spy(fn).was_not.called()
      assert.stub(saveStub).was_not.called()
      assert.stub(errorStub).was.called()
    end)

    -- Boundary: a failing fn must not persist a half-applied mutation
    it("should not save when fn raises", function()
      loadStub.returns({})

      assert.has_error(function()
        PersistentState.update(function() error("boom") end)
      end)

      assert.stub(saveStub).was_not.called()
    end)
  end)

  -- ============================================================================
  -- reset
  -- ============================================================================

  describe("reset", function()
    -- Positive: defaults replace whatever is stored, without loading first
    it("should write defaults to the SaveData key", function()
      local defaults = { red = { targetlist = {} } }

      PersistentState.reset(defaults)

      assert.stub(saveStub).was.called_with(defaults, "SaveData")
      assert.stub(loadStub).was_not.called()
    end)
  end)

  -- ============================================================================
  -- ground
  -- ============================================================================

  describe("ground", function()
    -- Positive: each side resolves to its own ground slice, not the other side's
    it("should return the ground slice for the given side", function()
      local redGround, blueGround = {}, {}
      local state = { red = { ground = redGround }, blue = { ground = blueGround } }

      assert.are.equal(redGround, PersistentState.ground(state, constants.SIDES.RED))
      assert.are.equal(blueGround, PersistentState.ground(state, constants.SIDES.BLUE))
    end)
  end)

  -- ============================================================================
  -- sigint / sigintEmitters
  -- ============================================================================

  describe("sigint", function()
    -- Shared builder: one distinct table per emitter group so identity checks are meaningful
    local function makeSigintState()
      local function ground(...)
        local g = {}
        for _, system in ipairs({ ... }) do
          g[system] = { firingUnits = { name = system } }
        end
        return { missileSystemTypes = g }
      end
      return {
        red = {
          sigint = { name = "china sigint" },
          ground = ground("mlrs", "srbm", "glcm", "mrbm", "ascm", "sam"),
          iads = { c2 = {} },
        },
        blue = {
          ground = ground("mlrs", "srbm", "glcm", "ascm", "sam"),
          iads = { rocc = {}, taaoc = {} },
        },
        ally = { sigint = { name = "us sigint" } },
      }
    end

    -- Positive: China and US collectors resolve to their own SIGINT slices
    it("should return the SIGINT slice of the collecting side", function()
      local state = makeSigintState()

      assert.are.equal(state.red.sigint, PersistentState.sigint(state, constants.SIDES.RED))
      assert.are.equal(state.ally.sigint, PersistentState.sigint(state, "US"))
    end)

    -- Positive: China listens to Taiwan's four TEL systems plus ROCC and TAAOC, in collection order
    it("should list Taiwan emitters for the China collector", function()
      local state = makeSigintState()

      assert.are.same({
        state.blue.ground.missileSystemTypes.srbm.firingUnits,
        state.blue.ground.missileSystemTypes.glcm.firingUnits,
        state.blue.ground.missileSystemTypes.mlrs.firingUnits,
        state.blue.ground.missileSystemTypes.ascm.firingUnits,
        state.blue.iads.rocc,
        state.blue.iads.taaoc,
      }, PersistentState.sigintEmitters(state, constants.SIDES.RED))
    end)

    -- Positive: US listens to China's MLRS/SRBM/GLCM and C2 only
    it("should list China emitters for the US collector", function()
      local state = makeSigintState()

      assert.are.same({
        state.red.ground.missileSystemTypes.mlrs.firingUnits,
        state.red.ground.missileSystemTypes.srbm.firingUnits,
        state.red.ground.missileSystemTypes.glcm.firingUnits,
        state.red.iads.c2,
      }, PersistentState.sigintEmitters(state, "US"))
    end)
  end)

  -- ============================================================================
  -- targetlist / recon / lacm
  -- ============================================================================

  describe("China-only slices", function()
    -- Positive: each accessor returns the live China table, not a copy
    it("should return China targetlist, recon, and LACM by reference", function()
      local state = { red = { targetlist = {}, recon = {}, surface = { lacm = {} } } }

      assert.are.equal(state.red.targetlist, PersistentState.targetlist(state))
      assert.are.equal(state.red.recon, PersistentState.recon(state))
      assert.are.equal(state.red.surface.lacm, PersistentState.lacm(state))
    end)
  end)

  -- ============================================================================
  -- runwayRepair / aircraft
  -- ============================================================================

  describe("runwayRepair", function()
    -- Positive: each side resolves to its own runway repair slice
    it("should return the runway repair slice for the given side", function()
      local state = { red = { repairRunway = { runways = {} } }, blue = { repairRunway = { runways = {} } } }

      assert.are.equal(state.red.repairRunway, PersistentState.runwayRepair(state, constants.SIDES.RED))
      assert.are.equal(state.blue.repairRunway, PersistentState.runwayRepair(state, constants.SIDES.BLUE))
    end)
  end)

  describe("aircraft", function()
    -- Positive: each side resolves to its own land-based aircraft slice
    it("should return the aircraft slice for the given side", function()
      local state = { red = { air = {} }, blue = { air = { ac = {}, aew = {} } } }

      assert.are.equal(state.red.air, PersistentState.aircraft(state, constants.SIDES.RED))
      assert.are.equal(state.blue.air, PersistentState.aircraft(state, constants.SIDES.BLUE))
    end)
  end)

  -- ============================================================================
  -- iads
  -- ============================================================================

  describe("iads", function()
    -- Positive: each side resolves to its own IADS slice, not the other side's
    it("should return the IADS slice for the given side", function()
      local redIads, blueIads = { c2 = {} }, { rocc = {}, taaoc = {} }
      local state = { red = { iads = redIads }, blue = { iads = blueIads } }

      assert.are.equal(redIads, PersistentState.iads(state, constants.SIDES.RED))
      assert.are.equal(blueIads, PersistentState.iads(state, constants.SIDES.BLUE))
    end)
  end)

  -- ============================================================================
  -- commsJamming
  -- ============================================================================

  describe("commsJamming", function()
    -- Positive: slices are the live tables, so jamming mutations land in saved state
    it("should expose China jammers and Taiwan IADS/aircraft by reference", function()
      local state = {
        red = { commsJamming = { enabled = true, jammers = {} } },
        blue = { iads = {}, air = { ac = {}, aew = {} } },
      }

      local jammingState = PersistentState.commsJamming(state)

      assert.are.equal(state.red.commsJamming.jammers, jammingState.jammers)
      assert.are.equal(state.blue.iads, jammingState.iads)
      assert.are.equal(state.blue.air.ac, jammingState.aircraft)
      assert.are.equal(state.blue.air.aew, jammingState.aew)
      assert.is_true(jammingState.enabled)
    end)
  end)

  -- ============================================================================
  -- landingOps
  -- ============================================================================

  describe("landingOps", function()
    -- Positive: slices are the live China tables, so landing mutations land in saved state
    it("should expose China amphibious, recon, and ground slices by reference", function()
      local state = {
        red = { amphibOps = {}, recon = {}, ground = {} },
        blue = { ground = {} },
      }

      local landingState = PersistentState.landingOps(state)

      assert.are.equal(state.red.amphibOps, landingState.amphibOps)
      assert.are.equal(state.red.recon, landingState.recon)
      assert.are.equal(state.red.ground, landingState.ground)
    end)
  end)

  -- ============================================================================
  -- strikePlanner
  -- ============================================================================

  describe("strikePlanner", function()
    local function makeRedState(fireSupportOnHold)
      return {
        red = {
          targetlist = {},
          sigint = { transmissions = {} },
          recon = {},
          dynamicOperations = {},
          air = {},
          ground = {},
          surface = { lacm = {} },
          subSurface = { slcm = {} },
          amphibOps = { fireSupportOnHold = fireSupportOnHold },
        },
        blue = { ground = {} },
      }
    end

    -- Positive: slices are the live China tables, so planner mutations land in saved state
    it("should expose China planner slices by reference", function()
      local state = makeRedState(true)

      local plannerState = PersistentState.strikePlanner(state)

      assert.are.equal(state.red.targetlist, plannerState.targetlist)
      assert.are.equal(state.red.sigint.transmissions, plannerState.transmissions)
      assert.are.equal(state.red.recon, plannerState.recon)
      assert.are.equal(state.red.dynamicOperations, plannerState.dynamicOperations)
      assert.are.equal(state.red.air, plannerState.air)
      assert.are.equal(state.red.ground, plannerState.ground)
      assert.are.equal(state.red.surface.lacm, plannerState.lacm)
      assert.are.equal(state.red.subSurface.slcm, plannerState.slcm)
      assert.is_true(plannerState.fireSupportOnHold)
    end)

    -- Edge: an unset landing ops hold reads as false, not nil
    it("should report fireSupportOnHold as false when landing ops never set it", function()
      local plannerState = PersistentState.strikePlanner(makeRedState(nil))

      assert.is_false(plannerState.fireSupportOnHold)
    end)
  end)

  -- ============================================================================
  -- read
  -- ============================================================================

  describe("read", function()
    -- Positive: fn sees the loaded state and nothing is written
    it("should run fn with the loaded state without saving", function()
      local state = { red = {} }
      loadStub.returns(state)
      local fn = spy.new(function() end)

      local ran = PersistentState.read(fn)

      assert.is_true(ran)
      assert.spy(fn).was.called_with(state)
      assert.stub(saveStub).was_not.called()
    end)

    -- Negative: no stored state means fn is skipped
    it("should skip fn when no state is stored", function()
      loadStub.returns(nil)
      local fn = spy.new(function() end)

      local ran = PersistentState.read(fn)

      assert.is_false(ran)
      assert.spy(fn).was_not.called()
      assert.stub(errorStub).was.called()
    end)
  end)
end)
