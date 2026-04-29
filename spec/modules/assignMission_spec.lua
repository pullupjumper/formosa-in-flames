local AssignMission = require("src.modules.assignMission")
local GameApi = require("src.utils.gameApi")
local Logger = require("src.utils.logger")

describe("AssignMission", function()
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
    trackStub(stub(Logger, "log"))
    trackStub(stub(Logger, "error"))
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

  ---Create a mock unit.
  ---@param overrides? table
  ---@return table
  local function makeUnit(overrides)
    local unit = {
      guid = "UNIT-1",
      dbid = 1001,
      mission = nil,
      loadoutdbid = 501,
      readytime_v = 0,
      manualSpeed = "ON",
    }

    if overrides then
      for k, v in pairs(overrides) do
        unit[k] = v
      end
    end

    return unit
  end

  ---Create a mock mission descriptor.
  ---@param overrides? table
  ---@return table
  local function makeMission(overrides)
    local mission = {
      name = "MISSION-1",
      unitCount = 1,
      loadoutId = 0,
    }

    if overrides then
      for k, v in pairs(overrides) do
        mission[k] = v
      end
    end

    return mission
  end

  ---Create a mock base unit with embarked units.
  ---@param overrides? table
  ---@return table
  local function makeBaseUnit(overrides)
    local baseUnit = {
      guid = "BASE-1",
      side = "Blue",
      embarkedUnits = {
        Aircraft = {},
        Boat = {},
      },
    }

    if overrides then
      for k, v in pairs(overrides) do
        baseUnit[k] = v
      end
    end

    return baseUnit
  end

  -- ============================================================================
  -- assignEmbarkedUnitsToMissions
  -- ============================================================================

  describe("assignEmbarkedUnitsToMissions", function()
    -- Negative: exits when source unit does not exist
    it("should return early when source unit cannot be found", function()
      local stubGetUnit = trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(nil))
      local stubAssign = trackStub(stub(GameApi, "ScenEdit_AssignUnitToMission").returns(true))

      AssignMission.assignEmbarkedUnitsToMissions("BASE-X", "Aircraft", 1001, { makeMission() })

      assert.stub(stubGetUnit).was.called_with("BASE-X")
      assert.stub(stubAssign).was_not.called()
    end)

    -- Positive: assigns only matching and eligible units up to mission unit count
    it("should assign matching embarked units up to mission unitCount", function()
      local base = makeBaseUnit({
        embarkedUnits = {
          Aircraft = { "AC-1", "AC-2", "AC-3" },
          Boat = {},
        },
      })
      local ac1 = makeUnit({ guid = "AC-1", dbid = 2001, mission = nil, loadoutdbid = 900 })
      local ac2 = makeUnit({ guid = "AC-2", dbid = 2001, mission = "EXISTING", loadoutdbid = 900 })
      local ac3 = makeUnit({ guid = "AC-3", dbid = 9999, mission = nil, loadoutdbid = 900 })

      trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(id)
        if id == "BASE-1" then return base end
        if id == "AC-1" then return ac1 end
        if id == "AC-2" then return ac2 end
        if id == "AC-3" then return ac3 end
        return nil
      end))
      local stubAssign = trackStub(stub(GameApi, "ScenEdit_AssignUnitToMission").returns(true))

      AssignMission.assignEmbarkedUnitsToMissions("BASE-1", "Aircraft", 2001, {
        makeMission({ name = "CAP-1", unitCount = 2, loadoutId = 900 }),
      })

      assert.are.equal("OFF", ac1.manualSpeed)
      assert.are.equal("OFF", ac2.manualSpeed)
      assert.stub(stubAssign).was.called(1)
      assert.stub(stubAssign).was.called_with("AC-1", "CAP-1", false)
    end)

    -- Boundary: continues selecting units when previous assignment fails
    it("should continue assigning when previous assignment call fails", function()
      local base = makeBaseUnit({
        embarkedUnits = {
          Aircraft = { "AC-1", "AC-2" },
          Boat = {},
        },
      })
      local ac1 = makeUnit({ guid = "AC-1", dbid = 2001, mission = nil })
      local ac2 = makeUnit({ guid = "AC-2", dbid = 2001, mission = nil })

      trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(id)
        if id == "BASE-1" then return base end
        if id == "AC-1" then return ac1 end
        if id == "AC-2" then return ac2 end
        return nil
      end))
      local stubAssign = trackStub(stub(GameApi, "ScenEdit_AssignUnitToMission").invokes(function(guid)
        return guid == "AC-2"
      end))

      AssignMission.assignEmbarkedUnitsToMissions("BASE-1", "Aircraft", 2001, {
        makeMission({ name = "CAP-2", unitCount = 1, loadoutId = 0 }),
      })

      assert.stub(stubAssign).was.called(2)
      assert.stub(stubAssign).was.called_with("AC-1", "CAP-2", false)
      assert.stub(stubAssign).was.called_with("AC-2", "CAP-2", false)
    end)
  end)

  -- ============================================================================
  -- assignEmbarkedUnitToStrikeMission
  -- ============================================================================

  describe("assignEmbarkedUnitToStrikeMission", function()
    -- Negative: returns nil when mission cannot be found
    it("should return nil when strike mission does not exist", function()
      local base = makeBaseUnit({ embarkedUnits = { Aircraft = { "AC-1" }, Boat = {} } })
      local stubGetUnit = trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(base))
      local stubGetMission = trackStub(stub(GameApi, "ScenEdit_GetMission").returns(nil))

      local result = AssignMission.assignEmbarkedUnitToStrikeMission("BASE-1", 1, 5001, nil, "STRIKE-1", false)

      assert.is_nil(result)
      assert.stub(stubGetUnit).was.called_with("BASE-1")
      assert.stub(stubGetMission).was.called_with("Blue", "STRIKE-1")
    end)

    -- Positive: assigns eligible aircraft and reactivates mission after assignment
    it("should assign eligible aircraft and return assigned guid list", function()
      local base = makeBaseUnit({ embarkedUnits = { Aircraft = { "AC-1", "AC-2", "AC-3" }, Boat = {} } })
      local mission = { isactive = true }
      local ac1 = makeUnit({ guid = "AC-1", dbid = 3001, mission = nil, readytime_v = 0 })
      local ac2 = makeUnit({ guid = "AC-2", dbid = 3002, mission = "EXISTING", readytime_v = 0 })
      local ac3 = makeUnit({ guid = "AC-3", dbid = 3003, mission = nil, readytime_v = 10 })

      trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(id)
        if id == "BASE-1" then return base end
        if id == "AC-1" then return ac1 end
        if id == "AC-2" then return ac2 end
        if id == "AC-3" then return ac3 end
        return nil
      end))
      trackStub(stub(GameApi, "ScenEdit_GetMission").returns(mission))
      trackStub(stub(GameApi, "ScenEdit_GetLoadout").invokes(function(guid)
        if guid == "AC-1" then
          return { weapons = { { wpn_dbid = 5001, wpn_current = 2 } } }
        end
        return { weapons = {} }
      end))
      local stubAssign = trackStub(stub(GameApi, "ScenEdit_AssignUnitToMission").returns(true))

      local result = AssignMission.assignEmbarkedUnitToStrikeMission("BASE-1", 2, 5001, nil, "STRIKE-1", true)

      assert.are.same({ "AC-1" }, result)
      assert.is_true(mission.isactive)
      assert.stub(stubAssign).was.called(1)
      assert.stub(stubAssign).was.called_with("AC-1", "STRIKE-1", true)
    end)

    -- Boundary: allows assignment by unitDBID when matching weapon count is zero
    it("should allow unit assignment when unit dbid matches even without weapon count", function()
      local base = makeBaseUnit({ embarkedUnits = { Aircraft = { "AC-1" }, Boat = {} } })
      local mission = { isactive = true }
      local ac1 = makeUnit({ guid = "AC-1", dbid = 7001, mission = nil, readytime_v = 0 })

      trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(id)
        if id == "BASE-1" then return base end
        if id == "AC-1" then return ac1 end
        return nil
      end))
      trackStub(stub(GameApi, "ScenEdit_GetMission").returns(mission))
      trackStub(stub(GameApi, "ScenEdit_GetLoadout").returns({ weapons = { { wpn_dbid = 9999, wpn_current = 4 } } }))
      local stubAssign = trackStub(stub(GameApi, "ScenEdit_AssignUnitToMission").returns(true))

      local result = AssignMission.assignEmbarkedUnitToStrikeMission("BASE-1", 1, 5001, 7001, "STRIKE-2", false)

      assert.are.same({ "AC-1" }, result)
      assert.stub(stubAssign).was.called_with("AC-1", "STRIKE-2", false)
    end)
  end)
end)
