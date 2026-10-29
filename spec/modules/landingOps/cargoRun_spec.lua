---@diagnostic disable: need-check-nil, assign-type-mismatch, cast-local-type, param-type-mismatch, inject-field, missing-fields
-- LandingOps CargoRun Unit Tests
local CargoRun = require("src.modules.landingOps.cargoRun")
local GameApi = require("src.utils.gameApi")
local constants = require("src.core.constants")
local StubTracker = require("spec.support.stubTracker")

describe("CargoRun", function()
  local trackStub = StubTracker.track
  local DBID = 1001
  local DROP_POINT = { latitude = 25.0, longitude = 121.0 }

  after_each(function()
    StubTracker.revertAll()
  end)

  ---@param guid string
  ---@param overrides? table
  ---@return table
  local function buildTransport(guid, overrides)
    local unit = {
      guid = guid,
      dbid = DBID,
      readytime_v = 0,
      cargo = { { cargo = { { guid = "C-" .. guid } } } },
      calls = {},
    }
    function unit:RTB(isReturning) table.insert(self.calls, "RTB:" .. tostring(isReturning)) end
    for key, value in pairs(overrides or {}) do
      unit[key] = value
    end
    return unit
  end

  ---@param units table[]
  local function stubUnits(units)
    local byGuid = {}
    for _, unit in ipairs(units) do
      byGuid[unit.guid] = unit
    end
    trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid) return byGuid[guid] end))
  end

  describe("findReady", function()
    it("should return only ready, loaded transports of the DBID", function()
      local units = {
        buildTransport("OK"),
        buildTransport("WRONG-DBID", { dbid = 2002 }),
        buildTransport("NOT-READY", { readytime_v = 60 }),
        buildTransport("EMPTY", { cargo = { { cargo = {} } } }),
        buildTransport("NO-CARGO"),
      }
      units[5].cargo = nil
      stubUnits(units)
      local host = { embarkedUnits = { [constants.PLATFORM_TYPES.AIRCRAFT] = { "OK", "WRONG-DBID", "NOT-READY", "EMPTY", "NO-CARGO", "GONE" } } }

      local ready = CargoRun.findReady(host, constants.PLATFORM_TYPES.AIRCRAFT, DBID)

      assert.are.equal(1, #ready)
      assert.are.equal("OK", ready[1].guid)
    end)

    it("should leave out GUIDs in the skip map", function()
      stubUnits({ buildTransport("A"), buildTransport("B") })
      local host = { embarkedUnits = { [constants.PLATFORM_TYPES.BOATS] = { "A", "B" } } }

      local ready = CargoRun.findReady(host, constants.PLATFORM_TYPES.BOATS, DBID, { A = {} })

      assert.are.equal(1, #ready)
      assert.are.equal("B", ready[1].guid)
    end)

    it("should return an empty list when the host has nothing embarked", function()
      assert.are.same({}, CargoRun.findReady({}, constants.PLATFORM_TYPES.BOATS, DBID))
    end)
  end)

  describe("step", function()
    it("should unload at the drop point", function()
      local unit = buildTransport("T-1")
      local run = { phase = CargoRun.PHASE.ENROUTE }
      trackStub(stub(GameApi, "Tool_Range").returns(0.05))
      local unloadStub = trackStub(stub(GameApi, "ScenEdit_UnloadCargo"))

      CargoRun.step(unit, run, DROP_POINT, 0.1)

      assert.stub(unloadStub).was.called_with("T-1")
      assert.are.equal(CargoRun.PHASE.UNLOADING, run.phase)
    end)

    it("should keep going while away from the drop point", function()
      local run = { phase = CargoRun.PHASE.ENROUTE }
      trackStub(stub(GameApi, "Tool_Range").returns(5))
      local unloadStub = trackStub(stub(GameApi, "ScenEdit_UnloadCargo"))

      CargoRun.step(buildTransport("T-1"), run, DROP_POINT, 0.1)

      assert.stub(unloadStub).was.not_called()
      assert.are.equal(CargoRun.PHASE.ENROUTE, run.phase)
    end)

    it("should keep going when the range is unknown", function()
      local run = { phase = CargoRun.PHASE.ENROUTE }
      trackStub(stub(GameApi, "Tool_Range").returns(nil))

      CargoRun.step(buildTransport("T-1"), run, DROP_POINT, 0.1)

      assert.are.equal(CargoRun.PHASE.ENROUTE, run.phase)
    end)

    it("should head home once the cargo is out", function()
      local unit = buildTransport("T-1", { condition = constants.UNIT_CONDITIONS.UNDERWAY })
      unit.cargo = nil
      local run = { phase = CargoRun.PHASE.UNLOADING }

      CargoRun.step(unit, run, DROP_POINT, 0.1)

      assert.are.same({ "RTB:true" }, unit.calls)
      assert.are.equal(CargoRun.PHASE.RETURNING, run.phase)
    end)

    it("should wait while still transferring cargo", function()
      local unit = buildTransport("T-1", { condition = constants.UNIT_CONDITIONS.TRANSFERRING_CARGO })
      unit.cargo = nil
      local run = { phase = CargoRun.PHASE.UNLOADING }

      CargoRun.step(unit, run, DROP_POINT, 0.1)

      assert.are.same({}, unit.calls)
      assert.are.equal(CargoRun.PHASE.UNLOADING, run.phase)
    end)

    it("should wait while the cargo is still aboard", function()
      local unit = buildTransport("T-1", { condition = constants.UNIT_CONDITIONS.UNDERWAY })
      local run = { phase = CargoRun.PHASE.UNLOADING }

      CargoRun.step(unit, run, DROP_POINT, 0.1)

      assert.are.same({}, unit.calls)
      assert.are.equal(CargoRun.PHASE.UNLOADING, run.phase)
    end)

    it("should do nothing once returning", function()
      local unit = buildTransport("T-1")
      local run = { phase = CargoRun.PHASE.RETURNING }
      local rangeStub = trackStub(stub(GameApi, "Tool_Range"))

      CargoRun.step(unit, run, DROP_POINT, 0.1)

      assert.stub(rangeStub).was.not_called()
      assert.are.same({}, unit.calls)
    end)
  end)
end)
