---@diagnostic disable: need-check-nil, assign-type-mismatch, cast-local-type, param-type-mismatch
-- LandingOps DebugFlow Unit Tests
local DebugFlow = require("src.modules.landingOps.debugFlow")
local GameApi = require("src.utils.gameApi")
local constants = require("src.core.constants")
local StubTracker = require("spec.support.stubTracker")

describe("DebugFlow", function()

  local trackStub = StubTracker.track

  before_each(function()
  end)

  after_each(function()
    StubTracker.revertAll()
  end)

  ---@param debug table|nil
  ---@return SBJ__AmphibOpsConfig
  local function buildAmphibOps(debug)
    local amphibOps = { debug = debug }
    return amphibOps
  end

  describe("isFastForward", function()
    it("should fast-forward the phases before the start stage", function()
      local amphibOps = buildAmphibOps({
        enabled = true,
        startStage = constants.AMPHIBIOUS_PHASES.BOAT_ASSAULT,
      })

      assert.is_true(DebugFlow.isFastForward(amphibOps, constants.AMPHIBIOUS_PHASES.MINE_CLEARING))
    end)

    it("should fast-forward every phase when no start stage is set", function()
      local amphibOps = buildAmphibOps({ enabled = true })

      assert.is_true(DebugFlow.isFastForward(amphibOps, constants.AMPHIBIOUS_PHASES.COMPLETED))
    end)

    it("should not fast-forward the start stage itself", function()
      local amphibOps = buildAmphibOps({
        enabled = true,
        startStage = constants.AMPHIBIOUS_PHASES.BOAT_ASSAULT,
      })

      assert.is_false(DebugFlow.isFastForward(amphibOps, constants.AMPHIBIOUS_PHASES.BOAT_ASSAULT))
    end)

    it("should not fast-forward the phases after the start stage", function()
      local amphibOps = buildAmphibOps({
        enabled = true,
        startStage = constants.AMPHIBIOUS_PHASES.BOAT_ASSAULT,
      })

      assert.is_false(DebugFlow.isFastForward(amphibOps, constants.AMPHIBIOUS_PHASES.ASSAULT_LANDING))
    end)

    it("should not fast-forward anything when debug is disabled", function()
      local amphibOps = buildAmphibOps({ enabled = false })

      assert.is_false(DebugFlow.isFastForward(amphibOps, constants.AMPHIBIOUS_PHASES.MINE_CLEARING))
    end)

    it("should not fast-forward anything when debug is missing", function()
      local amphibOps = buildAmphibOps(nil)

      assert.is_false(DebugFlow.isFastForward(amphibOps, constants.AMPHIBIOUS_PHASES.MINE_CLEARING))
    end)
  end)

  describe("isLandingTeleport", function()
    it("should be true when debug is enabled and landing teleport is on", function()
      local amphibOps = buildAmphibOps({ enabled = true, teleportLanding = true })

      assert.is_true(DebugFlow.isLandingTeleport(amphibOps))
    end)

    it("should be false when landing teleport is off", function()
      local amphibOps = buildAmphibOps({ enabled = true, teleportLanding = false })

      assert.is_false(DebugFlow.isLandingTeleport(amphibOps))
    end)

    it("should be false when debug is disabled", function()
      local amphibOps = buildAmphibOps({ enabled = false, teleportLanding = true })

      assert.is_false(DebugFlow.isLandingTeleport(amphibOps))
    end)

    it("should be false, not nil, when the enabled flag is unset", function()
      local amphibOps = buildAmphibOps({ teleportLanding = true })

      assert.is_false(DebugFlow.isLandingTeleport(amphibOps))
    end)

    it("should be false when debug is missing", function()
      local amphibOps = buildAmphibOps(nil)

      assert.is_false(DebugFlow.isLandingTeleport(amphibOps))
    end)
  end)

  describe("teleport", function()
    it("should move the unit to the given location", function()
      local setUnitStub = trackStub(stub(GameApi, "ScenEdit_SetUnit"))

      DebugFlow.teleport("SHIP-1", { latitude = 24.5, longitude = 120.25 })

      assert.stub(setUnitStub).was.called_with({ guid = "SHIP-1", latitude = 24.5, longitude = 120.25 })
    end)
  end)
end)
