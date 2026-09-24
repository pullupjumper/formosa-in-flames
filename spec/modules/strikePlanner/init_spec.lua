-- StrikePlanner Init Unit Tests
local stub = require("luassert.stub")
local StrikePlanner = require("src.modules.strikePlanner.init")
local AirTaskingOrder = require("src.modules.strikePlanner.airTaskingOrder")
local AtoBuilder = require("src.modules.strikePlanner.atoBuilder")
local FsemBuilder = require("src.modules.strikePlanner.fsemBuilder")
local FireSupportPlan = require("src.modules.strikePlanner.fireSupportPlan")
local Recon = require("src.modules.strikePlanner.recon")
local TargetingProcess = require("src.modules.strikePlanner.targetingProcess")
local AttackManager = require("src.modules.attackManager")
local GameApi = require("src.utils.gameApi")
local GameUtils = require("src.utils.gameUtils")
local Logger = require("src.utils.logger")
local constants = require("src.core.constants")

describe("StrikePlanner", function()
  ---@type luassert.spy[]
  local activeStubs
  ---@type string[]
  local calls
  local originalRandom

  ---Track and register method stub for automatic cleanup.
  ---@param obj table
  ---@param method string
  ---@return luassert.spy
  local function trackStub(obj, method)
    local s = stub(obj, method)
    table.insert(activeStubs, s)
    return s
  end

  ---Stub a method and record its label into `calls` when invoked.
  ---@param obj table
  ---@param method string
  ---@param label string
  ---@return luassert.spy
  local function trackOrderedStub(obj, method, label)
    local s = trackStub(obj, method)
    s.invokes(function() table.insert(calls, label) end)
    return s
  end

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

  before_each(function()
    activeStubs = {}
    calls = {}
    originalRandom = math.random
    trackStub(Logger, "log")
    trackStub(Logger, "error")
    trackStub(Logger, "warn")
    trackOrderedStub(FsemBuilder, "build", "fsem")
    trackOrderedStub(AtoBuilder, "build", "ato")
    trackOrderedStub(Recon, "processQueue", "recon")
    trackOrderedStub(Recon, "addEntry", "reconAddEntry")
    trackOrderedStub(AttackManager, "attackContacts", "attack")
    trackOrderedStub(FireSupportPlan, "process", "fsp")
    trackOrderedStub(AirTaskingOrder, "process", "atoWaves")
    trackStub(GameUtils, "isAfterStartTime").returns(true)
    math.random = function() return 0 end
  end)

  after_each(function()
    for i = #activeStubs, 1, -1 do
      activeStubs[i]:revert()
    end
    activeStubs = {}
    math.random = originalRandom
  end)

  -- ============================================================================
  -- init
  -- ============================================================================

  describe("init", function()
    it("builds the target list and the recon queue when recon is enabled", function()
      local findTargetsStub = trackStub(TargetingProcess, "findTargets")
      local initQueueStub = trackStub(Recon, "initQueue")
      local config = makeConfig()
      local saveData = makeSaveData({ recon = true })

      StrikePlanner.init(config, saveData)

      assert.stub(findTargetsStub).was_called_with(constants.SIDES.ENEMY, config.targetScanning, saveData)
      assert.stub(initQueueStub).was_called_with(config.c.recon, saveData.c.recon)
    end)

    it("skips the recon queue when recon is disabled", function()
      trackStub(TargetingProcess, "findTargets")
      local initQueueStub = trackStub(Recon, "initQueue")

      StrikePlanner.init(makeConfig(), makeSaveData())

      assert.stub(initQueueStub).was_not_called()
    end)
  end)

  -- ============================================================================
  -- process
  -- ============================================================================

  describe("process", function()
    ---@type luassert.spy
    local getUnitStub

    before_each(function()
      getUnitStub = trackStub(GameApi, "ScenEdit_GetUnit")
      getUnitStub.invokes(function(selector)
        if selector == "CSG" then
          return { group = { unitlist = { "SHIP-055", "SHIP-OTHER" } } }
        elseif selector == "SHIP-055" then
          return { guid = "SHIP-055", dbid = constants.PLATFORMS.TYPE_055 }
        elseif selector == "SHIP-OTHER" then
          return { guid = "SHIP-OTHER", dbid = -1 }
        elseif selector == "SUB-1" then
          return { latitude = 24.0, longitude = 120.0, course = { { latitude = 24.5, longitude = 120.5 } } }
        end
        return nil
      end)
    end)

    it("runs builders, recon, salvos, then active plans in order", function()
      local saveData = makeSaveData({
        dynamicOperations = true, recon = true, lacm = true, slcm = true, ground = true, air = true,
      })
      math.random = function() return 0.9 end

      StrikePlanner.process(makeConfig(), saveData, {})

      assert.are.same(
        { "fsem", "ato", "recon", "reconAddEntry", "attack", "attack", "fsp", "atoWaves" },
        calls
      )
    end)

    it("does nothing when every phase is disabled", function()
      StrikePlanner.process(makeConfig(), makeSaveData(), {})

      assert.are.same({}, calls)
    end)

    it("passes contacts to both builders", function()
      local config = makeConfig()
      local saveData = makeSaveData({ dynamicOperations = true })
      local contacts = { { guid = "C-1" } }

      StrikePlanner.process(config, saveData, contacts)

      assert.stub(FsemBuilder.build).was_called_with(config, saveData, contacts)
      assert.stub(AtoBuilder.build).was_called_with(config, saveData, contacts)
    end)

    it("hands recon a processing context built from saveData slices", function()
      local config = makeConfig()
      local saveData = makeSaveData({ recon = true })
      saveData.c.amphibOps.fireSupportOnHold = true

      StrikePlanner.process(config, saveData, {})

      assert.stub(Recon.processQueue).was_called_with({
        config = config,
        reconCtx = saveData.c.recon,
        reconTriggeredOperationBatches = saveData.c.dynamicOperations.reconTriggeredOperationBatches,
        lacmCtx = saveData.c.surface.lacm,
        fireSupportOnHold = true,
      })
    end)

    it("schedules the extra WZ-8 sortie only when the roll passes", function()
      local config = makeConfig()
      local saveData = makeSaveData({ recon = true })
      math.random = function() return 0.9 end

      StrikePlanner.process(config, saveData, {})

      assert.stub(Recon.addEntry).was_called_with(saveData.c.recon, config.c.recon.template.WZ8_RECON_ISLAND)

      math.random = function() return 0.1 end
      StrikePlanner.process(config, saveData, {})

      assert.stub(Recon.addEntry).was_called(1)
    end)

    it("fires the LACM salvo from Type 055s only, and only once", function()
      local config = makeConfig()
      local saveData = makeSaveData({ lacm = true })

      StrikePlanner.process(config, saveData, {})
      StrikePlanner.process(config, saveData, {})

      assert.stub(AttackManager.attackContacts).was_called(1)
      assert.stub(AttackManager.attackContacts).was_called_with({
        contacts = config.c.surface.lacm.targetlist,
        qty = 5,
        firingUnits = { { guid = "SHIP-055", weaponDBID = 101 } },
        weaponDBID = 101,
      })
      assert.is_true(saveData.c.surface.lacm.hasLaunched)
      -- enabled stays sticky; hasLaunched is what keeps the salvo one-shot
      assert.is_true(saveData.c.surface.lacm.enabled)
    end)

    it("holds the salvos before their start times", function()
      GameUtils.isAfterStartTime:revert()
      trackStub(GameUtils, "isAfterStartTime").returns(false)
      local saveData = makeSaveData({ lacm = true, slcm = true })

      StrikePlanner.process(makeConfig(), saveData, {})

      assert.stub(AttackManager.attackContacts).was_not_called()
      assert.is_false(saveData.c.surface.lacm.hasLaunched)
      assert.is_true(saveData.c.subSurface.slcm.enabled)
    end)

    it("sets SLCM submarines to launch depth, fires once, and disables SLCM", function()
      local config = makeConfig()
      local saveData = makeSaveData({ slcm = true })
      local submarine = { latitude = 24.0, longitude = 120.0, course = { { latitude = 24.5, longitude = 120.5 } } }
      getUnitStub.invokes(function() return submarine end)

      StrikePlanner.process(config, saveData, {})
      StrikePlanner.process(config, saveData, {})

      assert.are.same({
        { latitude = 24.0, longitude = 120.0, presetDepth = 2 },
        { latitude = 24.5, longitude = 120.5, presetDepth = 2 },
      }, submarine.course)
      assert.stub(AttackManager.attackContacts).was_called(1)
      assert.stub(AttackManager.attackContacts).was_called_with({
        contacts = config.c.subSurface.slcm.targetlist,
        qty = 8,
        firingUnits = config.c.subSurface.slcm.submarines,
        weaponDBID = 202,
      })
      assert.is_false(saveData.c.subSurface.slcm.enabled)
    end)
  end)
end)
