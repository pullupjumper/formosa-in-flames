-- DynamicPlan Unit Tests
local DynamicPlan = require("src.modules.strikePlanner.dynamicPlan")
local TargetingProcess = require("src.modules.strikePlanner.targetingProcess")

describe("DynamicPlan", function()
  local activeStubs

  ---Track and register test stub for automatic cleanup.
  ---@param stubObject any
  ---@return luassert.spy
  local function trackStub(stubObject)
    table.insert(activeStubs, stubObject)
    return stubObject
  end

  before_each(function()
    activeStubs = {}
  end)

  after_each(function()
    for _, s in ipairs(activeStubs) do
      s:revert()
    end
    activeStubs = {}
  end)

  ---Create minimal saveData with both plan tables and the name registry
  ---@param overrides? table
  ---@return table
  local function makeSaveData(overrides)
    overrides = overrides or {}
    return {
      c = {
        air = { airTaskingOrder = overrides.airTaskingOrder or {} },
        ground = { fireSupportPlan = overrides.fireSupportPlan or {} },
        dynamicOperations = {
          generatedOperations = overrides.generatedOperations or { air = {}, ground = {} }
        }
      }
    }
  end

  ---Create a target configuration tagged so a processTargets stub can tell entries apart
  ---@param tag string Base name used as the tag
  ---@param minTargetCount integer Required target count
  ---@return table
  local function makeTarget(tag, minTargetCount)
    return { objs = { { baseName = tag } }, contactAge = 300, minTargetCount = minTargetCount }
  end

  ---Stub processTargets to answer per target tag
  ---@param targetsByTag table<string, string[]> Targets returned for each tag
  ---@return luassert.spy
  local function stubTargets(targetsByTag)
    return trackStub(stub(TargetingProcess, "processTargets").invokes(function(_, _, _, targetConfig)
      return targetsByTag[targetConfig.objs[1].baseName] or {}
    end))
  end

  -- ============================================================================
  -- evaluateTargets
  -- ============================================================================

  describe("evaluateTargets", function()
    -- Positive: air templates are walked through their packages
    it("should evaluate each package of an air template and keep the qualified ones", function()
      local template = {
        name = "AIR/STRIKE/AB/W/1",
        isFirstWave = true,
        packages = {
          { target = makeTarget("FIRST", 1) },
          { target = makeTarget("SECOND", 3) },
          { target = makeTarget("THIRD", 1) },
        }
      }
      stubTargets({ FIRST = { "T1" }, SECOND = { "T2", "T3" }, THIRD = { "T4", "T5" } })

      local targetsByIndex, qualifiedCount = DynamicPlan.evaluateTargets({}, makeSaveData(), {}, "air", template)

      assert.are.equal(2, qualifiedCount)
      assert.are.same({ "T1" }, targetsByIndex[1])
      assert.is_nil(targetsByIndex[2])
      assert.are.same({ "T4", "T5" }, targetsByIndex[3])
    end)

    -- Positive: ground templates are walked through their fire support tasks
    it("should evaluate each fire support task of a ground template", function()
      local template = {
        name = "GND/STRIKE/INFRA/ALL/1",
        isFirstWave = false,
        fireSupportTasks = {
          { target = makeTarget("FIRST", 2) },
          { target = makeTarget("SECOND", 1) },
        }
      }
      stubTargets({ FIRST = { "T1" }, SECOND = { "T2" } })

      local targetsByIndex, qualifiedCount = DynamicPlan.evaluateTargets({}, makeSaveData(), {}, "ground", template)

      assert.are.equal(1, qualifiedCount)
      assert.is_nil(targetsByIndex[1])
      assert.are.same({ "T2" }, targetsByIndex[2])
    end)

    -- Positive: the first-wave flag and the entry's own target config reach the targeting process
    it("should pass the entry target config and the template first-wave flag through", function()
      local target = makeTarget("ONLY", 1)
      local template = { name = "AIR/STRIKE/AB/W/2", isFirstWave = false, packages = { { target = target } } }
      local config, saveData, contacts = { c = {} }, makeSaveData(), { "CONTACT" }
      local processTargetsStub = stubTargets({ ONLY = { "T1" } })

      DynamicPlan.evaluateTargets(config, saveData, contacts, "air", template)

      local callArgs = processTargetsStub.calls[1].refs
      assert.are.equal(config, callArgs[1])
      assert.are.equal(saveData, callArgs[2])
      assert.are.equal(contacts, callArgs[3])
      assert.are.equal(target, callArgs[4])
      assert.is_false(callArgs[5])
    end)

    -- Boundary: exactly minTargetCount qualifies, one short does not
    it("should qualify an entry at exactly minTargetCount", function()
      local template = {
        name = "AIR/STRIKE/AB/W/1",
        isFirstWave = true,
        packages = { { target = makeTarget("EXACT", 2) }, { target = makeTarget("SHORT", 2) } }
      }
      stubTargets({ EXACT = { "T1", "T2" }, SHORT = { "T3" } })

      local targetsByIndex, qualifiedCount = DynamicPlan.evaluateTargets({}, makeSaveData(), {}, "air", template)

      assert.are.equal(1, qualifiedCount)
      assert.is_table(targetsByIndex[1])
      assert.is_nil(targetsByIndex[2])
    end)

    -- Boundary: empty template
    it("should return no targets for a template with no entries", function()
      local template = { name = "AIR/STRIKE/AB/W/1", isFirstWave = true, packages = {} }
      stubTargets({})

      local targetsByIndex, qualifiedCount = DynamicPlan.evaluateTargets({}, makeSaveData(), {}, "air", template)

      assert.are.equal(0, qualifiedCount)
      assert.is_nil(next(targetsByIndex))
    end)

    -- Negative: unknown type
    it("should error on an unknown operation type", function()
      assert.has_error(function()
        DynamicPlan.evaluateTargets({}, makeSaveData(), {}, "naval", { packages = {} })
      end)
    end)
  end)

  -- ============================================================================
  -- insert
  -- ============================================================================

  describe("insert", function()
    ---Build a plan entry that records the name it was given
    ---@param planName string
    ---@return table
    local function buildPlan(planName)
      return { name = planName, built = true }
    end

    -- Positive: naming, writing and registering happen in one call
    it("should name, write and register an air wave in one call", function()
      local saveData = makeSaveData()

      local planName = DynamicPlan.insert(saveData, "air", "AIR/STRIKE/AB/W/2", "satellite", buildPlan)

      assert.are.equal("AIR/STRIKE/AB/W/2/DYN-SAT-01", planName)
      assert.are.equal(planName, saveData.c.air.airTaskingOrder[planName].name)
      assert.is_true(saveData.c.air.airTaskingOrder[planName].built)
      assert.is_true(saveData.c.dynamicOperations.generatedOperations.air[planName])
      -- The ground side is untouched
      assert.is_nil(next(saveData.c.ground.fireSupportPlan))
      assert.is_nil(next(saveData.c.dynamicOperations.generatedOperations.ground))
    end)

    -- Positive: ground plans go to the fire support plan and the ground registry
    it("should name, write and register a ground matrix in one call", function()
      local saveData = makeSaveData()

      local planName = DynamicPlan.insert(saveData, "ground", "GND/STRIKE/INFRA/ALL/1", "satellite", buildPlan)

      assert.are.equal("GND/STRIKE/INFRA/ALL/1/DYN-SAT-01", planName)
      assert.are.equal(planName, saveData.c.ground.fireSupportPlan[planName].name)
      assert.is_true(saveData.c.dynamicOperations.generatedOperations.ground[planName])
      assert.is_nil(next(saveData.c.air.airTaskingOrder))
    end)

    -- Positive: the template wave-stage number is preserved as the prefix
    it("should keep the template wave-stage number recoverable from the generated name", function()
      local planName = DynamicPlan.insert(makeSaveData(), "air", "AIR/STRIKE/AB/W/2", "satellite", buildPlan)

      assert.are.equal("2", planName:match("^AIR/STRIKE/AB/W/(%d+)/DYN"))
    end)

    -- Positive: unmapped recon sources pass through as uppercase
    it("should pass through UAV and SIGINT sources as uppercase in the name", function()
      assert.are.equal("AIR/STRIKE/AB/W/2/DYN-UAV-01",
        DynamicPlan.insert(makeSaveData(), "air", "AIR/STRIKE/AB/W/2", "UAV", buildPlan))
      assert.are.equal("GND/STRIKE/INFRA/ALL/1/DYN-SIGINT-01",
        DynamicPlan.insert(makeSaveData(), "ground", "GND/STRIKE/INFRA/ALL/1", "SIGINT", buildPlan))
    end)

    -- Positive: repeated inserts walk the sequence forward
    it("should advance the sequence on each insert of the same template", function()
      local saveData = makeSaveData()

      local first = DynamicPlan.insert(saveData, "air", "AIR/STRIKE/AB/W/2", "satellite", buildPlan)
      local second = DynamicPlan.insert(saveData, "air", "AIR/STRIKE/AB/W/2", "satellite", buildPlan)

      assert.are.equal("AIR/STRIKE/AB/W/2/DYN-SAT-01", first)
      assert.are.equal("AIR/STRIKE/AB/W/2/DYN-SAT-02", second)
      assert.is_table(saveData.c.air.airTaskingOrder[first])
      assert.is_table(saveData.c.air.airTaskingOrder[second])
    end)

    -- Negative: names already in the registry are skipped
    it("should skip names already in the registry", function()
      local saveData = makeSaveData({
        generatedOperations = { air = { ["AIR/STRIKE/AB/W/2/DYN-SAT-01"] = true }, ground = {} }
      })

      local planName = DynamicPlan.insert(saveData, "air", "AIR/STRIKE/AB/W/2", "satellite", buildPlan)

      assert.are.equal("AIR/STRIKE/AB/W/2/DYN-SAT-02", planName)
    end)

    -- Negative: names already in the plan table are skipped, so a static entry is never overwritten
    it("should skip names already in the plan table", function()
      local existing = { name = "existing" }
      local saveData = makeSaveData({ fireSupportPlan = { ["GND/STRIKE/INFRA/ALL/1/DYN-SAT-01"] = existing } })

      local planName = DynamicPlan.insert(saveData, "ground", "GND/STRIKE/INFRA/ALL/1", "satellite", buildPlan)

      assert.are.equal("GND/STRIKE/INFRA/ALL/1/DYN-SAT-02", planName)
      assert.are.equal(existing, saveData.c.ground.fireSupportPlan["GND/STRIKE/INFRA/ALL/1/DYN-SAT-01"])
    end)

    -- Negative: both sources are consulted
    it("should skip names in both the registry and the plan table", function()
      local saveData = makeSaveData({
        generatedOperations = { air = { ["AIR/STRIKE/AB/W/2/DYN-SAT-01"] = true }, ground = {} },
        airTaskingOrder = { ["AIR/STRIKE/AB/W/2/DYN-SAT-02"] = { name = "existing" } }
      })

      local planName = DynamicPlan.insert(saveData, "air", "AIR/STRIKE/AB/W/2", "satellite", buildPlan)

      assert.are.equal("AIR/STRIKE/AB/W/2/DYN-SAT-03", planName)
    end)

    -- Boundary: a save without the registry gets one
    it("should initialize generatedOperations when missing", function()
      local saveData = makeSaveData()
      saveData.c.dynamicOperations.generatedOperations = nil

      local planName = DynamicPlan.insert(saveData, "air", "AIR/STRIKE/AB/W/2", "satellite", buildPlan)

      assert.are.equal("AIR/STRIKE/AB/W/2/DYN-SAT-01", planName)
      assert.is_true(saveData.c.dynamicOperations.generatedOperations.air[planName])
      assert.is_table(saveData.c.dynamicOperations.generatedOperations.ground)
    end)

    -- Positive: buildPlan sees the final name, so the stored entry can carry it
    it("should hand buildPlan the same name it returns", function()
      local receivedName
      local saveData = makeSaveData()

      local planName = DynamicPlan.insert(saveData, "air", "AIR/STRIKE/AB/W/2", "satellite", function(name)
        receivedName = name
        return { name = name }
      end)

      assert.are.equal(planName, receivedName)
    end)

    -- Negative: unknown type
    it("should error on an unknown operation type", function()
      assert.has_error(function()
        DynamicPlan.insert(makeSaveData(), "naval", "SEA/STRIKE/PORT/1", "satellite", buildPlan)
      end)
    end)
  end)
end)
