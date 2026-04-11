-- MissileSystem Concealment Unit Tests
---@diagnostic disable: undefined-field
local stub = require("luassert.stub")
local Concealment = require("src.modules.missileSystem.concealment")
local GameApi = require("src.utils.gameApi")
local AmphibiousLogistics = require("src.modules.landingOps.amphibiousLogistics")
local Logger = require("src.utils.logger")

describe("MissileSystem Concealment", function()
  local activeStubs
  local function trackStub(obj, method)
    local s = stub(obj, method)
    table.insert(activeStubs, s)
    return s
  end

  local function makeHideUnitCtx()
    return {
      name = "TEL Alpha",
      operationalArea = {
        name = "OPAREA-1",
        mask = { area = { "MASK-001", "MASK-002", "MASK-003", "MASK-004" } }
      }
    }
  end

  local function makeMockSide(filteredUnits)
    return {
      unitsInArea = function()
        return filteredUnits
      end
    }
  end

  before_each(function()
    activeStubs = {}
    table.insert(activeStubs, stub(Logger, "log"))
    table.insert(activeStubs, stub(Logger, "error"))
  end)

  after_each(function()
    for i = #activeStubs, 1, -1 do
      activeStubs[i]:revert()
    end
    activeStubs = {}
  end)

  -- ============================================================================
  -- hideUnit
  -- ============================================================================

  describe("hideUnit", function()
    -- Negative: returns false when no buildings are found
    it("should return false when no buildings found in mask area", function()
      local unitCtx = makeHideUnitCtx()
      local unit = { guid = "U1", side = "China" }

      trackStub(GameApi, "VP_GetSide").returns(makeMockSide(nil))

      local success, errorMsg = Concealment.hideUnit(unitCtx, unit)

      assert.is_false(success)
      assert.are.equal("No buildings found in mask area", errorMsg)
    end)

    -- Negative: returns false when buildings cannot be retrieved
    it("should return false when no buildings can be retrieved", function()
      local unitCtx = makeHideUnitCtx()
      local unit = { guid = "U1", side = "China" }

      trackStub(GameApi, "VP_GetSide").returns(makeMockSide({ { guid = "B1" } }))
      trackStub(GameApi, "ScenEdit_GetUnit").returns(nil)

      local success, errorMsg = Concealment.hideUnit(unitCtx, unit)

      assert.is_false(success)
      assert.is_truthy(errorMsg:match("No available building"))
    end)

    -- Negative: returns false when all buildings are occupied
    it("should return false when all buildings are occupied", function()
      local unitCtx = makeHideUnitCtx()
      local unit = { guid = "U1", side = "China" }
      local mockBuilding = {
        guid = "B1",
        cargo = { { cargo = { { guid = "OTHER" } } } }
      }

      trackStub(GameApi, "VP_GetSide").returns(makeMockSide({ { guid = "B1" } }))
      trackStub(GameApi, "ScenEdit_GetUnit").returns(mockBuilding)

      local success, errorMsg = Concealment.hideUnit(unitCtx, unit)

      assert.is_false(success)
      assert.is_truthy(errorMsg:match("No available building"))
    end)

    -- Positive: loads cargo when building exists
    it("should call loadCargo when building exists and return true", function()
      local unitCtx = makeHideUnitCtx()
      local unit = { guid = "U1", side = "China" }
      local mockBuilding = { guid = "B1", name = "Building 1" }

      trackStub(GameApi, "VP_GetSide").returns(makeMockSide({ { guid = "B1" } }))
      trackStub(GameApi, "ScenEdit_GetUnit").returns(mockBuilding)
      trackStub(math, "random").returns(1)
      local stubLoadCargo = trackStub(AmphibiousLogistics, "loadCargo")

      local success, errorMsg = Concealment.hideUnit(unitCtx, unit)

      assert.is_true(success)
      assert.is_nil(errorMsg)
      assert.stub(stubLoadCargo).was.called(1)
      assert.are.same(mockBuilding, stubLoadCargo.calls[1].vals[1])
      assert.are.same(unitCtx, stubLoadCargo.calls[1].vals[2])
      assert.are.equal("China", stubLoadCargo.calls[1].vals[3])
    end)

    -- Positive: selects a random building from the list
    it("should select a random building from the list", function()
      local unitCtx = makeHideUnitCtx()
      local unit = { guid = "U1", side = "China" }
      local mockBuilding2 = { guid = "B2", name = "Building 2" }

      trackStub(GameApi, "VP_GetSide").returns(makeMockSide({
        { guid = "B1" }, { guid = "B2" }, { guid = "B3" }
      }))
      trackStub(GameApi, "ScenEdit_GetUnit").returns(mockBuilding2)
      trackStub(math, "random").returns(2)
      local stubLoadCargo = trackStub(AmphibiousLogistics, "loadCargo")

      Concealment.hideUnit(unitCtx, unit)

      assert.stub(stubLoadCargo).was.called(1)
      assert.are.same(mockBuilding2, stubLoadCargo.calls[1].vals[1])
    end)
  end)

  -- ============================================================================
  -- moveFromHideArea
  -- ============================================================================

  describe("moveFromHideArea", function()
    -- Negative: returns false when no buildings are found
    it("should return false when no buildings found in mask area", function()
      local unitCtx = makeHideUnitCtx()
      local unit = { guid = "U1", side = "China" }

      trackStub(GameApi, "VP_GetSide").returns(makeMockSide(nil))

      local success, errorMsg = Concealment.moveFromHideArea(unitCtx, unit)

      assert.is_false(success)
      assert.are.equal("No buildings found in mask area", errorMsg)
    end)

    -- Positive: unloads cargo when unit is found in building
    it("should unload cargo when unit is found in building", function()
      local unitCtx = makeHideUnitCtx()
      local unit = { guid = "U1", side = "China" }
      local mockBuilding = {
        guid = "B1",
        cargo = { { cargo = { { guid = "U1" } } } }
      }

      trackStub(GameApi, "VP_GetSide").returns(makeMockSide({ { guid = "B1" } }))
      trackStub(GameApi, "ScenEdit_GetUnit").returns(mockBuilding)
      local stubUnload = trackStub(GameApi, "ScenEdit_UnloadCargo")

      local success = Concealment.moveFromHideArea(unitCtx, unit)

      assert.is_true(success)
      assert.stub(stubUnload).was.called(1)
      assert.are.equal("B1", stubUnload.calls[1].vals[1])
    end)

    -- Negative: does not unload when unit is not in building cargo
    it("should not unload when unit is not in building cargo", function()
      local unitCtx = makeHideUnitCtx()
      local unit = { guid = "U1", side = "China" }
      local mockBuilding = {
        guid = "B1",
        cargo = { { cargo = { { guid = "OTHER" } } } }
      }

      trackStub(GameApi, "VP_GetSide").returns(makeMockSide({ { guid = "B1" } }))
      trackStub(GameApi, "ScenEdit_GetUnit").returns(mockBuilding)
      local stubUnload = trackStub(GameApi, "ScenEdit_UnloadCargo")

      local success = Concealment.moveFromHideArea(unitCtx, unit)

      assert.is_true(success)
      assert.stub(stubUnload).was_not.called()
    end)

    -- Positive: unloads all group units from buildings
    it("should unload all group units from buildings", function()
      local unitCtx = makeHideUnitCtx()
      local unit = { guid = "G1", side = "China", group = { unitlist = { "U1", "U2" } } }

      local mockBuilding1 = {
        guid = "B1",
        cargo = { { cargo = { { guid = "U1" } } } }
      }
      local mockBuilding2 = {
        guid = "B2",
        cargo = { { cargo = { { guid = "U2" } } } }
      }

      trackStub(GameApi, "VP_GetSide").returns(makeMockSide({ { guid = "B1" }, { guid = "B2" } }))
      trackStub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
        if guid == "B1" then return mockBuilding1 end
        if guid == "B2" then return mockBuilding2 end
        return nil
      end)
      local stubUnload = trackStub(GameApi, "ScenEdit_UnloadCargo")

      local success = Concealment.moveFromHideArea(unitCtx, unit)

      assert.is_true(success)
      assert.stub(stubUnload).was.called(2)
      assert.are.equal("B1", stubUnload.calls[1].vals[1])
      assert.are.equal("B2", stubUnload.calls[2].vals[1])
    end)

    -- Boundary: skips buildings that cannot be retrieved
    it("should skip buildings that cannot be retrieved", function()
      local unitCtx = makeHideUnitCtx()
      local unit = { guid = "U1", side = "China" }

      trackStub(GameApi, "VP_GetSide").returns(makeMockSide({ { guid = "B1" }, { guid = "B2" } }))
      trackStub(GameApi, "ScenEdit_GetUnit").returns(nil)
      local stubUnload = trackStub(GameApi, "ScenEdit_UnloadCargo")

      local success = Concealment.moveFromHideArea(unitCtx, unit)

      assert.is_true(success)
      assert.stub(stubUnload).was_not.called()
    end)
  end)
end)
