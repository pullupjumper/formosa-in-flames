---@diagnostic disable: need-check-nil, assign-type-mismatch, cast-local-type, param-type-mismatch, inject-field, missing-fields
-- LandingOps TrackedUnits Unit Tests
local TrackedUnits = require("src.modules.landingOps.trackedUnits")
local GameApi = require("src.utils.gameApi")
local StubTracker = require("spec.support.stubTracker")

describe("TrackedUnits", function()
  local trackStub = StubTracker.track

  after_each(function()
    StubTracker.revertAll()
  end)

  ---Build a zone state where one GUID sits in every record that can hold it
  ---@param guid string
  ---@return SBJ__ZoneState
  local function buildZoneStateHolding(guid)
    return {
      acvGuids = { zbd05 = { "ACV-KEEP", guid } },
      boats = { [guid] = { status = "arrived" }, ["BOAT-KEEP"] = { status = "arrived" } },
      hovercraft = { [guid] = { phase = "enroute" } },
      minesweepers = { [guid] = { isDone = false } },
      heliWave = {
        transport = { currentWave = { [guid] = {} } },
        attackHelis = { [guid] = {} },
        airlift = { currentWave = { [guid] = {} } },
      },
      laneSlots = { ["W1-B1"] = { guid, "ACV-KEEP" } },
    }
  end

  ---@param zoneState SBJ__ZoneState
  ---@param guid string
  local function assertRemovedEverywhere(zoneState, guid)
    assert.are.same({ "ACV-KEEP" }, zoneState.acvGuids.zbd05)
    assert.is_nil(zoneState.boats[guid])
    assert.is_not_nil(zoneState.boats["BOAT-KEEP"])
    assert.is_nil(zoneState.hovercraft[guid])
    assert.is_nil(zoneState.minesweepers[guid])
    assert.is_nil(zoneState.heliWave.transport.currentWave[guid])
    assert.is_nil(zoneState.heliWave.attackHelis[guid])
    assert.is_nil(zoneState.heliWave.airlift.currentWave[guid])
    assert.are.same({ false, "ACV-KEEP" }, zoneState.laneSlots["W1-B1"])
  end

  describe("remove", function()
    it("should remove a unit from every record of the zone", function()
      local zoneState = buildZoneStateHolding("X-1")

      assert.is_true(TrackedUnits.remove(zoneState, "X-1"))

      assertRemovedEverywhere(zoneState, "X-1")
    end)

    it("should return false when no record holds the unit", function()
      assert.is_false(TrackedUnits.remove(buildZoneStateHolding("X-1"), "NOPE"))
    end)

    it("should return false for a zone with no records yet", function()
      assert.is_false(TrackedUnits.remove({}, "X-1"))
    end)
  end)

  describe("findUnit", function()
    it("should return a unit that is still found and keep its records", function()
      local unit = { guid = "X-1" }
      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(unit))
      local zoneState = buildZoneStateHolding("X-1")

      assert.are.equal(unit, TrackedUnits.findUnit(zoneState, "X-1"))
      assert.is_not_nil(zoneState.boats["X-1"])
    end)

    it("should remove a unit that is no longer found from every record, so it is looked up only once", function()
      local getUnit = trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(nil))
      local zoneState = buildZoneStateHolding("X-1")

      assert.is_nil(TrackedUnits.findUnit(zoneState, "X-1"))

      assertRemovedEverywhere(zoneState, "X-1")
      assert.stub(getUnit).was.called(1)
    end)
  end)

  describe("removeMissing", function()
    it("should keep a unit that is still found and return false", function()
      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns({ guid = "X-1" }))
      local zoneState = buildZoneStateHolding("X-1")

      assert.is_false(TrackedUnits.removeMissing(zoneState, "X-1"))
      assert.is_not_nil(zoneState.boats["X-1"])
    end)

    it("should remove a unit that is no longer found and return true", function()
      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(nil))
      local zoneState = buildZoneStateHolding("X-1")

      assert.is_true(TrackedUnits.removeMissing(zoneState, "X-1"))
      assertRemovedEverywhere(zoneState, "X-1")
    end)
  end)
end)
