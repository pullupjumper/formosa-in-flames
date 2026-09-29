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
      local state = { c = { counter = 1 } }
      loadStub.returns(state)

      local ran = PersistentState.update(function(s)
        s.c.counter = 2
      end)

      assert.is_true(ran)
      assert.are.equal(2, state.c.counter)
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
      local defaults = { c = { targetlist = {} } }

      PersistentState.reset(defaults)

      assert.stub(saveStub).was.called_with(defaults, "SaveData")
      assert.stub(loadStub).was_not.called()
    end)
  end)

  -- ============================================================================
  -- groundForces
  -- ============================================================================

  describe("groundForces", function()
    -- Positive: each side resolves to its own ground slice, not the other side's
    it("should return the ground slice for the given side", function()
      local chinaGround, taiwanGround = {}, {}
      local state = { c = { ground = chinaGround }, t = { ground = taiwanGround } }

      assert.are.equal(chinaGround, PersistentState.groundForces(state, constants.SIDES.ENEMY))
      assert.are.equal(taiwanGround, PersistentState.groundForces(state, constants.SIDES.PLAYER))
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
        return g
      end
      return {
        c = {
          sigint = { name = "china sigint" },
          ground = ground("mlrs", "srbm", "glcm", "mrbm", "ascm", "sam"),
          iads = { c2 = {} },
        },
        t = {
          ground = ground("mlrs", "srbm", "glcm", "ascm", "sam"),
          iads = { rocc = {}, taaoc = {} },
        },
        u = { sigint = { name = "us sigint" } },
      }
    end

    -- Positive: China and US collectors resolve to their own SIGINT slices
    it("should return the SIGINT slice of the collecting side", function()
      local state = makeSigintState()

      assert.are.equal(state.c.sigint, PersistentState.sigint(state, constants.SIDES.ENEMY))
      assert.are.equal(state.u.sigint, PersistentState.sigint(state, "US"))
    end)

    -- Positive: China listens to Taiwan's four TEL systems plus ROCC and TAAOC, in collection order
    it("should list Taiwan emitters for the China collector", function()
      local state = makeSigintState()

      assert.are.same({
        state.t.ground.srbm.firingUnits,
        state.t.ground.glcm.firingUnits,
        state.t.ground.mlrs.firingUnits,
        state.t.ground.ascm.firingUnits,
        state.t.iads.rocc,
        state.t.iads.taaoc,
      }, PersistentState.sigintEmitters(state, constants.SIDES.ENEMY))
    end)

    -- Positive: US listens to China's MLRS/SRBM/GLCM and C2 only
    it("should list China emitters for the US collector", function()
      local state = makeSigintState()

      assert.are.same({
        state.c.ground.mlrs.firingUnits,
        state.c.ground.srbm.firingUnits,
        state.c.ground.glcm.firingUnits,
        state.c.iads.c2,
      }, PersistentState.sigintEmitters(state, "US"))
    end)
  end)

  -- ============================================================================
  -- targetlist / recon / lacm
  -- ============================================================================

  describe("China-only slices", function()
    -- Positive: each accessor returns the live China table, not a copy
    it("should return China targetlist, recon, and LACM by reference", function()
      local state = { c = { targetlist = {}, recon = {}, surface = { lacm = {} } } }

      assert.are.equal(state.c.targetlist, PersistentState.targetlist(state))
      assert.are.equal(state.c.recon, PersistentState.recon(state))
      assert.are.equal(state.c.surface.lacm, PersistentState.lacm(state))
    end)
  end)

  -- ============================================================================
  -- runwayRepair / landBasedAircraft
  -- ============================================================================

  describe("runwayRepair", function()
    -- Positive: each side resolves to its own runway repair slice
    it("should return the runway repair slice for the given side", function()
      local state = { c = { repairRunway = { runways = {} } }, t = { repairRunway = { runways = {} } } }

      assert.are.equal(state.c.repairRunway, PersistentState.runwayRepair(state, constants.SIDES.ENEMY))
      assert.are.equal(state.t.repairRunway, PersistentState.runwayRepair(state, constants.SIDES.PLAYER))
    end)
  end)

  describe("landBasedAircraft", function()
    -- Positive: each side resolves to its own land-based aircraft slice
    it("should return the land-based aircraft slice for the given side", function()
      local state = { c = { air = { landBased = {} } }, t = { air = { landBased = { AC = {}, AEW = {} } } } }

      assert.are.equal(state.c.air.landBased, PersistentState.landBasedAircraft(state, constants.SIDES.ENEMY))
      assert.are.equal(state.t.air.landBased, PersistentState.landBasedAircraft(state, constants.SIDES.PLAYER))
    end)
  end)

  -- ============================================================================
  -- iads
  -- ============================================================================

  describe("iads", function()
    -- Positive: each side resolves to its own IADS slice, not the other side's
    it("should return the IADS slice for the given side", function()
      local chinaIads, taiwanIads = { c2 = {} }, { rocc = {}, taaoc = {} }
      local state = { c = { iads = chinaIads }, t = { iads = taiwanIads } }

      assert.are.equal(chinaIads, PersistentState.iads(state, constants.SIDES.ENEMY))
      assert.are.equal(taiwanIads, PersistentState.iads(state, constants.SIDES.PLAYER))
    end)
  end)

  -- ============================================================================
  -- commsJamming
  -- ============================================================================

  describe("commsJamming", function()
    -- Positive: slices are the live tables, so jamming mutations land in saved state
    it("should expose China jammers and Taiwan IADS/aircraft by reference", function()
      local state = {
        c = { commsJamming = { enabled = true, jammers = {} } },
        t = { iads = {}, air = { landBased = { AC = {}, AEW = {} } } },
      }

      local jammingState = PersistentState.commsJamming(state)

      assert.are.equal(state.c.commsJamming.jammers, jammingState.jammers)
      assert.are.equal(state.t.iads, jammingState.iads)
      assert.are.equal(state.t.air.landBased.AC, jammingState.aircraft)
      assert.are.equal(state.t.air.landBased.AEW, jammingState.aew)
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
        c = { amphibOps = {}, recon = {}, ground = {} },
        t = { ground = {} },
      }

      local landingState = PersistentState.landingOps(state)

      assert.are.equal(state.c.amphibOps, landingState.amphibOps)
      assert.are.equal(state.c.recon, landingState.recon)
      assert.are.equal(state.c.ground, landingState.ground)
    end)
  end)

  -- ============================================================================
  -- strikePlanner
  -- ============================================================================

  describe("strikePlanner", function()
    local function makeChinaState(fireSupportOnHold)
      return {
        c = {
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
        t = { ground = {} },
      }
    end

    -- Positive: slices are the live China tables, so planner mutations land in saved state
    it("should expose China planner slices by reference", function()
      local state = makeChinaState(true)

      local plannerState = PersistentState.strikePlanner(state)

      assert.are.equal(state.c.targetlist, plannerState.targetlist)
      assert.are.equal(state.c.sigint.transmissions, plannerState.transmissions)
      assert.are.equal(state.c.recon, plannerState.recon)
      assert.are.equal(state.c.dynamicOperations, plannerState.dynamicOperations)
      assert.are.equal(state.c.air, plannerState.air)
      assert.are.equal(state.c.ground, plannerState.ground)
      assert.are.equal(state.c.surface.lacm, plannerState.lacm)
      assert.are.equal(state.c.subSurface.slcm, plannerState.slcm)
      assert.is_true(plannerState.fireSupportOnHold)
    end)

    -- Edge: an unset landing ops hold reads as false, not nil
    it("should report fireSupportOnHold as false when landing ops never set it", function()
      local plannerState = PersistentState.strikePlanner(makeChinaState(nil))

      assert.is_false(plannerState.fireSupportOnHold)
    end)
  end)

  -- ============================================================================
  -- read
  -- ============================================================================

  describe("read", function()
    -- Positive: fn sees the loaded state and nothing is written
    it("should run fn with the loaded state without saving", function()
      local state = { c = {} }
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
