-- RunwayRepairment Unit Tests
local RunwayRepairment = require("src.modules.runwayRepairment")
local TargetingProcess = require("src.modules.strikePlanner.targetingProcess")
local GameApi = require("src.utils.gameApi")
local constants = require("src.core.constants")

describe("RunwayRepairment", function()
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

  ---Create a runway repair config
  ---@return table
  local function makeConfig()
    return {
      repairRunway = {
        airBases = { "Hsinchu" },
        runwaySubTypes = { "Runway" },
        runwayDBIDs = { 101 },
        percentagePerHour = 12,
      },
    }
  end

  ---Create save data holding the target list and both sides' runway repair contexts
  ---@param overrides {targetlist?: table[], chinaRepair?: table, taiwanRepair?: table}|nil
  ---@return table
  local function makeSaveData(overrides)
    overrides = overrides or {}
    return {
      c = {
        targetlist = overrides.targetlist or {},
        repairRunway = overrides.chinaRepair or { enabled = false, runways = {} },
      },
      t = { repairRunway = overrides.taiwanRepair or { enabled = false, runways = {} } },
    }
  end

  ---Create a side mock whose facility list is fixed
  ---@param units table[]|nil
  ---@return table
  local function makeSideMock(units)
    return {
      unitsBy = function()
        return units
      end,
    }
  end

  -- ============================================================================
  -- initRunways
  -- ============================================================================

  describe("initRunways", function()
    -- Positive: Taiwan runways come from the target list, China runways from matching facilities
    it("should fill each side's runway list from its own source", function()
      local targetlist = { { guid = "contact-1" } }
      local saveData = makeSaveData({ targetlist = targetlist })
      local filterStub = trackStub(stub(TargetingProcess, "filterTargetsByTypeAndBase").returns({ "contact-1" }))
      trackStub(stub(GameApi, "ScenEdit_GetContact").returns({ actualunitid = "tw-runway-1" }))
      trackStub(stub(GameApi, "VP_GetSide").returns(makeSideMock({ { guid = "fac-1" }, { guid = "fac-2" } })))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
        return { guid = guid, dbid = guid == "fac-1" and 101 or 999 }
      end))

      RunwayRepairment.initRunways(makeConfig(), saveData)

      assert.stub(filterStub).was.called_with(targetlist, { { baseName = "Hsinchu", subTypes = { "Runway" } } })
      assert.are.same({ { guid = "tw-runway-1" } }, saveData.t.repairRunway.runways)
      assert.are.same({ { guid = "fac-1" } }, saveData.c.repairRunway.runways)
    end)

    -- Edge: no facilities still keeps the Taiwan runways already found
    it("should leave China runways empty when no facilities are found", function()
      local saveData = makeSaveData()
      trackStub(stub(TargetingProcess, "filterTargetsByTypeAndBase").returns({ "contact-1" }))
      trackStub(stub(GameApi, "ScenEdit_GetContact").returns({ actualunitid = "tw-runway-1" }))
      trackStub(stub(GameApi, "VP_GetSide").returns(makeSideMock(nil)))

      RunwayRepairment.initRunways(makeConfig(), saveData)

      assert.are.equal(1, #saveData.t.repairRunway.runways)
      assert.are.same({}, saveData.c.repairRunway.runways)
    end)
  end)

  -- ============================================================================
  -- processRunwayDamage
  -- ============================================================================

  describe("processRunwayDamage", function()
    -- Positive: the damaged runway starts its repair clock and its own side's repair turns on
    it("should enable repair and stamp the damaged runway's start time on the runway's side", function()
      local saveData = makeSaveData({
        taiwanRepair = { enabled = false, runways = { { guid = "rw-1" }, { guid = "rw-2" } } },
      })
      local unit = { guid = "rw-1", side = constants.SIDES.PLAYER }
      trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(3600))

      RunwayRepairment.processRunwayDamage(saveData, unit)

      assert.is_true(saveData.t.repairRunway.enabled)
      assert.is_false(saveData.c.repairRunway.enabled)
      assert.are.equal(3600, saveData.t.repairRunway.runways[1].startTime)
      assert.is_nil(saveData.t.repairRunway.runways[2].startTime)
    end)

    -- Negative: a runway already under repair keeps its original start time
    it("should not restart the clock of a runway already under repair", function()
      local saveData = makeSaveData({ chinaRepair = { enabled = true, runways = { { guid = "rw-1", startTime = 100 } } } })
      local unit = { guid = "rw-1", side = constants.SIDES.ENEMY }
      trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(3600))

      RunwayRepairment.processRunwayDamage(saveData, unit)

      assert.are.equal(100, saveData.c.repairRunway.runways[1].startTime)
    end)
  end)

  -- ============================================================================
  -- repairSide
  -- ============================================================================

  describe("repairSide", function()
    -- Positive: only the side's runways with a start time get repaired, by percentagePerHour per 5-minute tick
    it("should repair only the side's runways whose repair has started", function()
      local damageStub = trackStub(stub(GameApi, "ScenEdit_SetUnitDamage"))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
        return { guid = guid, damage = { startdp = 1000 } }
      end))

      local saveData = makeSaveData({
        chinaRepair = { runways = { { guid = "rw-1", startTime = 0 }, { guid = "rw-2" } } },
        taiwanRepair = { runways = { { guid = "tw-rw", startTime = 0 } } },
      })

      RunwayRepairment.repairSide(makeConfig(), saveData, constants.SIDES.ENEMY)

      assert.stub(damageStub).was.called(1)
      assert.stub(damageStub).was.called_with({ guid = "rw-1", dp = -10, fires = "NoFire" })
    end)
  end)
end)
