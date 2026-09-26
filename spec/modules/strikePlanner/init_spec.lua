-- StrikePlanner Init Unit Tests
local StrikePlanner = require("src.modules.strikePlanner.init")
local GameApi = require("src.utils.gameApi")
local GameUtils = require("src.utils.gameUtils")
local AirTaskingOrder = require("src.modules.strikePlanner.airTaskingOrder")
local AtoBuilder = require("src.modules.strikePlanner.atoBuilder")
local FsemBuilder = require("src.modules.strikePlanner.fsemBuilder")
local FireSupportPlan = require("src.modules.strikePlanner.fireSupportPlan")
local Recon = require("src.modules.strikePlanner.recon")
local TargetingProcess = require("src.modules.strikePlanner.targetingProcess")
local AttackManager = require("src.modules.attackManager")
local constants = require("src.core.constants")

describe("StrikePlanner", function()
  ---@type luassert.spy[]
  local activeStubs

  ---Track and register test stub for automatic cleanup.
  ---@param s any
  ---@return luassert.spy
  local function trackStub(s)
    table.insert(activeStubs, s)
    return s
  end

  before_each(function()
    activeStubs = {}
  end)

  after_each(function()
    for i = #activeStubs, 1, -1 do
      activeStubs[i]:revert()
    end
    activeStubs = {}
  end)

  -- ============================================================================
  -- Shared mock data builders
  -- ============================================================================

  ---Build a config fixture covering every slice the strike planner reads.
  ---@return table
  local function makeConfig()
    return {
      targetScanning = { scan = true },
      c = {
        recon = {
          queue = {},
          template = { WZ8_RECON_ISLAND = { id = "WZ8_RECON_ISLAND" } },
        },
        triggers = {
          launchLACM = { startTime = "LACM_START" },
          launchSLCM = { startTime = "SLCM_START" },
        },
        surface = { lacm = { weaponDBID = 101, targetlist = { "LACM-TGT" } } },
        subSurface = {
          slcm = {
            weaponDBID = 202,
            targetlist = { "SLCM-TGT" },
            submarines = { { name = "SUB-1" } },
          },
        },
      },
    }
  end

  ---Build a saveData fixture with every strike planner phase disabled.
  ---@param overrides? { dynamicOperations?: boolean, recon?: boolean, lacm?: boolean, slcm?: boolean, ground?: boolean, air?: boolean }
  ---@return table
  local function makeSaveData(overrides)
    overrides = overrides or {}
    return {
      c = {
        dynamicOperations = { enabled = overrides.dynamicOperations == true, reconTriggeredOperationBatches = {} },
        recon = { enabled = overrides.recon == true, queue = {} },
        surface = { lacm = { enabled = overrides.lacm == true, hasLaunched = false } },
        subSurface = { slcm = { enabled = overrides.slcm == true } },
        amphibOps = { fireSupportOnHold = nil },
        ground = { enabled = overrides.ground == true },
        air = { enabled = overrides.air == true },
      },
    }
  end

  ---Build a submarine unit sitting at a fixed position with one waypoint ahead.
  ---@return table
  local function makeSubmarine()
    return { latitude = 24.0, longitude = 120.0, course = { { latitude = 24.5, longitude = 120.5 } } }
  end

  ---Stub GameApi.ScenEdit_GetUnit with a selector -> unit map.
  ---@param map table<string, table|nil>
  local function stubGetUnit(map)
    trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(selector)
      return map[selector]
    end))
  end

  ---Stub the CSG with one Type 055 and one other ship.
  local function stubCsg()
    stubGetUnit({
      CSG = { group = { unitlist = { "SHIP-055", "SHIP-OTHER" } } },
      ["SHIP-055"] = { guid = "SHIP-055", dbid = constants.PLATFORMS.TYPE_055 },
      ["SHIP-OTHER"] = { guid = "SHIP-OTHER", dbid = -1 },
    })
  end

  ---Stub GameUtils.isAfterStartTime so only the listed start times have passed.
  ---@param passed table<string, boolean>
  local function stubStartTimesPassed(passed)
    trackStub(stub(GameUtils, "isAfterStartTime").invokes(function(startTime)
      return passed[startTime] == true
    end))
  end

  -- ============================================================================
  -- init
  -- ============================================================================

  describe("init", function()
    ---@type luassert.spy
    local findTargetsStub
    ---@type luassert.spy
    local initQueueStub

    before_each(function()
      findTargetsStub = trackStub(stub(TargetingProcess, "findTargets"))
      initQueueStub = trackStub(stub(Recon, "initQueue"))
    end)

    -- Positive: the target list is built regardless of recon state.
    it("should build the target list against the enemy side", function()
      local config = makeConfig()
      local saveData = makeSaveData()

      StrikePlanner.init(config, saveData)

      assert.stub(findTargetsStub).was.called_with(constants.SIDES.ENEMY, config.targetScanning, saveData)
    end)

    -- Positive: recon enabled seeds the queue from the recon config slice.
    it("should build the recon queue when recon is enabled", function()
      local config = makeConfig()
      local saveData = makeSaveData({ recon = true })

      StrikePlanner.init(config, saveData)

      assert.stub(initQueueStub).was.called_with(config.c.recon, saveData.c.recon)
    end)

    -- Negative: recon disabled leaves the queue untouched.
    it("should skip the recon queue when recon is disabled", function()
      StrikePlanner.init(makeConfig(), makeSaveData())

      assert.stub(initQueueStub).was_not.called()
    end)
  end)

  -- ============================================================================
  -- process
  -- ============================================================================

  describe("process", function()
    -- ============================================================================
    -- Dynamic operations
    -- ============================================================================

    describe("dynamic operations", function()
      ---@type luassert.spy
      local fsemBuildStub
      ---@type luassert.spy
      local atoBuildStub

      before_each(function()
        fsemBuildStub = trackStub(stub(FsemBuilder, "build"))
        atoBuildStub = trackStub(stub(AtoBuilder, "build"))
      end)

      -- Positive: both builders see the same contacts.
      it("should pass contacts to both builders", function()
        local config = makeConfig()
        local saveData = makeSaveData({ dynamicOperations = true })
        local contacts = { { guid = "C-1" } }

        StrikePlanner.process(config, saveData, contacts)

        assert.stub(fsemBuildStub).was.called_with(config, saveData, contacts)
        assert.stub(atoBuildStub).was.called_with(config, saveData, contacts)
      end)

      -- Negative: disabled dynamic operations build nothing.
      it("should skip both builders when dynamic operations are disabled", function()
        StrikePlanner.process(makeConfig(), makeSaveData(), {})

        assert.stub(fsemBuildStub).was_not.called()
        assert.stub(atoBuildStub).was_not.called()
      end)
    end)

    -- ============================================================================
    -- Recon
    -- ============================================================================

    describe("recon", function()
      ---@type luassert.spy
      local processQueueStub
      ---@type luassert.spy
      local addEntryStub

      before_each(function()
        processQueueStub = trackStub(stub(Recon, "processQueue"))
        addEntryStub = trackStub(stub(Recon, "addEntry"))
      end)

      -- Positive: the context carries every saveData slice recon needs.
      it("should hand recon a processing context built from saveData slices", function()
        trackStub(stub(math, "random").returns(0))
        local config = makeConfig()
        local saveData = makeSaveData({ recon = true })
        saveData.c.amphibOps.fireSupportOnHold = true

        StrikePlanner.process(config, saveData, {})

        assert.stub(processQueueStub).was.called_with({
          config = config,
          reconCtx = saveData.c.recon,
          reconTriggeredOperationBatches = saveData.c.dynamicOperations.reconTriggeredOperationBatches,
          lacmCtx = saveData.c.surface.lacm,
          fireSupportOnHold = true,
        })
      end)

      -- Positive: a passing roll queues the extra WZ-8 island sortie.
      it("should schedule the extra WZ-8 sortie when the roll passes", function()
        trackStub(stub(math, "random").returns(0.9))
        local config = makeConfig()
        local saveData = makeSaveData({ recon = true })

        StrikePlanner.process(config, saveData, {})

        assert.stub(addEntryStub).was.called_with(saveData.c.recon, config.c.recon.template.WZ8_RECON_ISLAND)
      end)

      -- Negative: a failing roll queues nothing extra.
      it("should not schedule the extra WZ-8 sortie when the roll fails", function()
        trackStub(stub(math, "random").returns(0.1))

        StrikePlanner.process(makeConfig(), makeSaveData({ recon = true }), {})

        assert.stub(addEntryStub).was_not.called()
      end)

      -- Negative: disabled recon neither advances the queue nor rolls a sortie.
      it("should skip recon entirely when recon is disabled", function()
        StrikePlanner.process(makeConfig(), makeSaveData(), {})

        assert.stub(processQueueStub).was_not.called()
      end)

      -- Boundary: a roll exactly at the chance does not pass.
      it("should not schedule the extra WZ-8 sortie when the roll equals the chance", function()
        trackStub(stub(math, "random").returns(0.5))

        StrikePlanner.process(makeConfig(), makeSaveData({ recon = true }), {})

        assert.stub(addEntryStub).was_not.called()
      end)

      -- Boundary: an unset hold flag reaches recon as an explicit false.
      it("should report fire support as not on hold when the flag is unset", function()
        trackStub(stub(math, "random").returns(0))
        local config = makeConfig()
        local saveData = makeSaveData({ recon = true })

        StrikePlanner.process(config, saveData, {})

        assert.are.equal(false, processQueueStub.calls[1].vals[1].fireSupportOnHold)
      end)
    end)

    -- ============================================================================
    -- LACM salvo
    -- ============================================================================

    describe("LACM salvo", function()
      ---@type luassert.spy
      local attackContactsStub

      before_each(function()
        attackContactsStub = trackStub(stub(AttackManager, "attackContacts"))
      end)

      -- Positive: only Type 055s in the CSG are firing units.
      it("should fire the salvo from Type 055s only", function()
        stubCsg()
        stubStartTimesPassed({ LACM_START = true })
        local config = makeConfig()

        StrikePlanner.process(config, makeSaveData({ lacm = true }), {})

        assert.stub(attackContactsStub).was.called_with({
          contacts = config.c.surface.lacm.targetlist,
          qty = 5,
          firingUnits = { { guid = "SHIP-055", weaponDBID = 101 } },
          weaponDBID = 101,
        })
      end)

      -- Positive: firing marks the salvo as launched.
      it("should mark the salvo as launched after firing", function()
        stubCsg()
        stubStartTimesPassed({ LACM_START = true })
        local saveData = makeSaveData({ lacm = true })

        StrikePlanner.process(makeConfig(), saveData, {})

        assert.is_true(saveData.c.surface.lacm.hasLaunched)
      end)

      -- Negative: enabled stays sticky, so hasLaunched alone keeps the salvo one-shot.
      it("should not fire again once the salvo has launched", function()
        stubCsg()
        stubStartTimesPassed({ LACM_START = true })
        local saveData = makeSaveData({ lacm = true })
        saveData.c.surface.lacm.hasLaunched = true

        StrikePlanner.process(makeConfig(), saveData, {})

        assert.stub(attackContactsStub).was_not.called()
      end)

      -- Negative: the salvo waits for its own start time.
      it("should hold the salvo before its start time", function()
        stubStartTimesPassed({})

        StrikePlanner.process(makeConfig(), makeSaveData({ lacm = true }), {})

        assert.stub(attackContactsStub).was_not.called()
      end)

      -- Boundary: a CSG member that no longer resolves is skipped, not fatal.
      it("should skip CSG members that no longer exist", function()
        stubGetUnit({
          CSG = { group = { unitlist = { "SHIP-GONE", "SHIP-055" } } },
          ["SHIP-055"] = { guid = "SHIP-055", dbid = constants.PLATFORMS.TYPE_055 },
        })
        stubStartTimesPassed({ LACM_START = true })

        StrikePlanner.process(makeConfig(), makeSaveData({ lacm = true }), {})

        local firingUnits = attackContactsStub.calls[1].vals[1].firingUnits
        assert.are.same({ { guid = "SHIP-055", weaponDBID = 101 } }, firingUnits)
      end)
    end)

    -- ============================================================================
    -- SLCM salvo
    -- ============================================================================

    describe("SLCM salvo", function()
      ---@type luassert.spy
      local attackContactsStub

      before_each(function()
        attackContactsStub = trackStub(stub(AttackManager, "attackContacts"))
      end)

      -- Positive: every course point, including the current position, is set to launch depth.
      it("should set the submarine course to launch depth", function()
        local submarine = makeSubmarine()
        stubGetUnit({ ["SUB-1"] = submarine })
        stubStartTimesPassed({ SLCM_START = true })

        StrikePlanner.process(makeConfig(), makeSaveData({ slcm = true }), {})

        assert.are.same({
          { latitude = 24.0, longitude = 120.0, presetDepth = 2 },
          { latitude = 24.5, longitude = 120.5, presetDepth = 2 },
        }, submarine.course)
      end)

      -- Positive: the salvo fires from the configured submarines.
      it("should fire the salvo from the configured submarines", function()
        stubGetUnit({ ["SUB-1"] = makeSubmarine() })
        stubStartTimesPassed({ SLCM_START = true })
        local config = makeConfig()

        StrikePlanner.process(config, makeSaveData({ slcm = true }), {})

        assert.stub(attackContactsStub).was.called_with({
          contacts = config.c.subSurface.slcm.targetlist,
          qty = 8,
          firingUnits = config.c.subSurface.slcm.submarines,
          weaponDBID = 202,
        })
      end)

      -- Positive: firing disables SLCM so the salvo stays one-shot.
      it("should disable SLCM after firing", function()
        stubGetUnit({ ["SUB-1"] = makeSubmarine() })
        stubStartTimesPassed({ SLCM_START = true })
        local saveData = makeSaveData({ slcm = true })

        StrikePlanner.process(makeConfig(), saveData, {})

        assert.is_false(saveData.c.subSurface.slcm.enabled)
      end)

      -- Negative: the salvo waits for its own start time, independent of LACM.
      it("should hold the salvo before its start time", function()
        stubStartTimesPassed({ LACM_START = true })

        StrikePlanner.process(makeConfig(), makeSaveData({ slcm = true }), {})

        assert.stub(attackContactsStub).was_not.called()
      end)

      -- Boundary: a missing submarine does not block the salvo order.
      it("should still fire when a configured submarine no longer exists", function()
        stubGetUnit({})
        stubStartTimesPassed({ SLCM_START = true })

        StrikePlanner.process(makeConfig(), makeSaveData({ slcm = true }), {})

        assert.stub(attackContactsStub).was.called(1)
      end)
    end)

    -- ============================================================================
    -- Active plans
    -- ============================================================================

    describe("active plans", function()
      ---@type luassert.spy
      local fireSupportProcessStub
      ---@type luassert.spy
      local atoProcessStub

      before_each(function()
        fireSupportProcessStub = trackStub(stub(FireSupportPlan, "process"))
        atoProcessStub = trackStub(stub(AirTaskingOrder, "process"))
      end)

      -- Positive: ground enabled advances fire support plans.
      it("should advance fire support plans when ground is enabled", function()
        local saveData = makeSaveData({ ground = true })

        StrikePlanner.process(makeConfig(), saveData, {})

        assert.stub(fireSupportProcessStub).was.called_with(saveData)
      end)

      -- Positive: air enabled advances ATO waves.
      it("should advance ATO waves when air is enabled", function()
        local config = makeConfig()
        local saveData = makeSaveData({ air = true })

        StrikePlanner.process(config, saveData, {})

        assert.stub(atoProcessStub).was.called_with(config, saveData)
      end)

      -- Negative: ground disabled leaves fire support plans alone.
      it("should skip fire support plans when ground is disabled", function()
        StrikePlanner.process(makeConfig(), makeSaveData({ air = true }), {})

        assert.stub(fireSupportProcessStub).was_not.called()
      end)

      -- Negative: air disabled leaves ATO waves alone.
      it("should skip ATO waves when air is disabled", function()
        StrikePlanner.process(makeConfig(), makeSaveData({ ground = true }), {})

        assert.stub(atoProcessStub).was_not.called()
      end)
    end)

    -- ============================================================================
    -- Phase order
    -- ============================================================================

    describe("phase order", function()
      -- Positive: plans inserted this tick must exist before recon and execution see them.
      it("should run builders, recon, salvos, then active plans in order", function()
        local order = {}
        local function record(label)
          return function() table.insert(order, label) end
        end
        trackStub(stub(FsemBuilder, "build").invokes(record("fsem")))
        trackStub(stub(AtoBuilder, "build").invokes(record("ato")))
        trackStub(stub(Recon, "processQueue").invokes(record("recon")))
        trackStub(stub(Recon, "addEntry").invokes(record("wz8")))
        trackStub(stub(AttackManager, "attackContacts").invokes(function(args)
          table.insert(order, args.weaponDBID == 101 and "lacm" or "slcm")
        end))
        trackStub(stub(FireSupportPlan, "process").invokes(record("fsp")))
        trackStub(stub(AirTaskingOrder, "process").invokes(record("atoWaves")))
        trackStub(stub(math, "random").returns(0.9))
        stubCsg()
        stubStartTimesPassed({ LACM_START = true, SLCM_START = true })
        local saveData = makeSaveData({
          dynamicOperations = true, recon = true, lacm = true, slcm = true, ground = true, air = true,
        })

        StrikePlanner.process(makeConfig(), saveData, {})

        assert.are.same({ "fsem", "ato", "recon", "wz8", "lacm", "slcm", "fsp", "atoWaves" }, order)
      end)
    end)
  end)
end)
