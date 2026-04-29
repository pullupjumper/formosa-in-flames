local IntegratedAirDefenseSystem = require("src.modules.integratedAirDefenseSystem")
local GameApi = require("src.utils.gameApi")
local GameUtils = require("src.utils.gameUtils")
local Logger = require("src.utils.logger")
local constants = require("src.core.constants")

describe("IntegratedAirDefenseSystem", function()
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
      name = "Unit One",
      dbid = 1001,
      OODA = 300,
      latitude = 0,
      longitude = 0,
      inArea = function()
        return false
      end,
    }

    if overrides then
      for k, v in pairs(overrides) do
        unit[k] = v
      end
    end

    return unit
  end

  ---Create a mock C2 descriptor.
  ---@param overrides? table
  ---@return table
  local function makeDescriptor(overrides)
    local descriptor = {
      name = "ROCC-1",
      areas = { "AREA-1" },
    }

    if overrides then
      for k, v in pairs(overrides) do
        descriptor[k] = v
      end
    end

    return descriptor
  end

  -- ============================================================================
  -- processC2Disruption
  -- ============================================================================

  describe("processC2Disruption", function()
    -- Positive: disables radar and sam units under destroyed c2
    it("should disable linked units and remove c2 context", function()
      local radar = makeUnit({ guid = "RAD-1" })
      local sam = makeUnit({ guid = "SAM-1" })
      local c2 = makeUnit({ guid = "C2-1", name = "C2 Node" })
      local iadsContext = {
        c2 = {
          ["C2-1"] = {
            radar = { ["RAD-1"] = { guid = "RAD-1", isOutOfComms = false } },
            sam = { ["SAM-1"] = { guid = "SAM-1", isOutOfComms = false } },
          },
        },
      }

      trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
        if guid == "RAD-1" then return radar end
        if guid == "SAM-1" then return sam end
        return nil
      end))
      local stubSetUnit = trackStub(stub(GameApi, "ScenEdit_SetUnit").returns(true))

      IntegratedAirDefenseSystem.processC2Disruption(iadsContext, c2)

      assert.is_nil(iadsContext.c2["C2-1"])
      assert.stub(stubSetUnit).was.called(2)
      assert.stub(stubSetUnit).was.called_with({ guid = "RAD-1", outofcomms = true })
      assert.stub(stubSetUnit).was.called_with({ guid = "SAM-1", outofcomms = true })
    end)

    -- Negative: no-op when guid not found in any context
    it("should not disable any unit when c2 guid is not tracked", function()
      local c2 = makeUnit({ guid = "C2-MISSING" })
      local iadsContext = { c2 = {}, rocc = {}, taaoc = {} }
      local stubSetUnit = trackStub(stub(GameApi, "ScenEdit_SetUnit"))

      IntegratedAirDefenseSystem.processC2Disruption(iadsContext, c2)

      assert.stub(stubSetUnit).was_not.called()
    end)
  end)

  -- ============================================================================
  -- removeDestroyedUnitContextFromIADS
  -- ============================================================================

  describe("removeDestroyedUnitContextFromIADS", function()
    -- Positive: removes destroyed sam from matching c2 context
    it("should remove destroyed unit from matched c2 bucket", function()
      local destroyed = makeUnit({ guid = "SAM-9", name = "SAM-9", inArea = function(_, area) return area == "A-1" end })
      local c2TypeContext = {
        ["C2-A"] = {
          guid = "C2-A",
          areas = { "A-1" },
          sam = { ["SAM-9"] = { guid = "SAM-9" } },
          radar = {},
        },
      }

      IntegratedAirDefenseSystem.removeDestroyedUnitContextFromIADS(c2TypeContext, "sam", destroyed)

      assert.is_nil(c2TypeContext["C2-A"].sam["SAM-9"])
    end)

    -- Boundary: keeps data when unit is outside all areas
    it("should keep context unchanged when destroyed unit is outside areas", function()
      local destroyed = makeUnit({ guid = "RAD-2", inArea = function() return false end })
      local c2TypeContext = {
        ["C2-A"] = {
          guid = "C2-A",
          areas = { "A-1" },
          sam = {},
          radar = { ["RAD-2"] = { guid = "RAD-2" } },
        },
      }

      IntegratedAirDefenseSystem.removeDestroyedUnitContextFromIADS(c2TypeContext, "radar", destroyed)

      assert.are.equal("RAD-2", c2TypeContext["C2-A"].radar["RAD-2"].guid)
    end)
  end)

  -- ============================================================================
  -- activateNearestRadar
  -- ============================================================================

  describe("activateNearestRadar", function()
    -- Positive: prefers dedicated radar over sam radar even if both valid
    it("should activate nearest dedicated radar first", function()
      local destroyed = makeUnit({ latitude = 10, longitude = 20 })
      local sideUnits = { { guid = "RAD-A" }, { guid = "SAM-A" } }
      local radarA = makeUnit({
        guid = "RAD-A",
        name = "JY-26",
        dbid = constants.PLATFORMS.JY26,
      })
      local samA = makeUnit({
        guid = "SAM-A",
        name = "HQ-22",
        dbid = constants.PLATFORMS.HQ22,
      })
      local cfg = { radarDistance = 100 }

      trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
        if guid == "RAD-A" then return radarA end
        if guid == "SAM-A" then return samA end
        return nil
      end))
      trackStub(stub(GameApi, "Tool_Range").invokes(function(_, guid)
        if guid == "RAD-A" then return 30 end
        if guid == "SAM-A" then return 10 end
        return 999
      end))
      local stubSetEmcon = trackStub(stub(GameApi, "ScenEdit_SetEMCON").returns(true))

      IntegratedAirDefenseSystem.activateNearestRadar(cfg, sideUnits, destroyed)

      assert.stub(stubSetEmcon).was.called_with("Unit", "RAD-A", "Radar=Active")
    end)

    -- Negative: does not activate when no candidate is in threshold
    it("should not activate any radar when all candidates are out of range", function()
      local destroyed = makeUnit({ latitude = 10, longitude = 20 })
      local sideUnits = { { guid = "RAD-A" } }
      local radarA = makeUnit({ guid = "RAD-A", dbid = constants.PLATFORMS.JY26 })
      local cfg = { radarDistance = 100 }

      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(radarA))
      trackStub(stub(GameApi, "Tool_Range").returns(150))
      local stubSetEmcon = trackStub(stub(GameApi, "ScenEdit_SetEMCON"))

      IntegratedAirDefenseSystem.activateNearestRadar(cfg, sideUnits, destroyed)

      assert.stub(stubSetEmcon).was_not.called()
    end)
  end)

  -- ============================================================================
  -- addC2Facilities
  -- ============================================================================

  describe("addC2Facilities", function()
    -- Positive: returns true when all deployments are created
    it("should return true when random units are created for all deployments", function()
      local cfg = {
        c2Deployments = {
          { position = { latitude = 1, longitude = 2 } },
          { position = { latitude = 3, longitude = 4 } },
        },
        c2FacilityDBIDs = { 1, 2 },
        randomRadius = 5,
      }
      local stubCreate = trackStub(stub(GameUtils, "createRandomUnits").returns({ { guid = "F1" } }))

      local ok = IntegratedAirDefenseSystem.addC2Facilities(cfg)

      assert.is_true(ok)
      assert.stub(stubCreate).was.called(2)
    end)

    -- Negative: returns false when any deployment returns empty units
    it("should return false when random unit creation fails", function()
      local cfg = {
        c2Deployments = { { position = { latitude = 1, longitude = 2 } } },
        c2FacilityDBIDs = { 1 },
        randomRadius = 5,
      }
      trackStub(stub(GameUtils, "createRandomUnits").returns({}))

      local ok = IntegratedAirDefenseSystem.addC2Facilities(cfg)

      assert.is_false(ok)
    end)
  end)

  -- ============================================================================
  -- initC2FacilitiesContext
  -- ============================================================================

  describe("initC2FacilitiesContext", function()
    -- Positive: creates c2 context and associates radar and sam entries
    it("should initialize c2 context with matched facilities and assets", function()
      local areaA = "A-1"
      local chosenC2 = makeUnit({
        guid = "C2-FAC-1",
        name = "C2 Facility",
        dbid = 9001,
        inArea = function(_, area) return area == areaA end,
      })
      local sam = makeUnit({
        guid = "SAM-1",
        name = "SAM-1",
        dbid = constants.PLATFORMS.HQ22,
        inArea = function(_, area) return area == areaA end,
      })
      local radar = makeUnit({
        guid = "RAD-1",
        name = "RAD-1",
        dbid = constants.PLATFORMS.JY26,
        inArea = function(_, area) return area == areaA end,
      })

      local filtered = { { guid = "C2-FAC-1" }, { guid = "SAM-1" }, { guid = "RAD-1" } }
      local sideObj = { unitsBy = function() return filtered end }

      trackStub(stub(GameApi, "VP_GetSide").returns(sideObj))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
        if guid == "C2-FAC-1" then return chosenC2 end
        if guid == "SAM-1" then return sam end
        if guid == "RAD-1" then return radar end
        return nil
      end))
      trackStub(stub(math, "random").returns(1))

      local iadsConfig = {
        c2Deployments = { { name = "Sector A", areas = { areaA } } },
        c2FacilityDBIDs = { 9001 },
      }
      local iadsContext = {}

      local ok = IntegratedAirDefenseSystem.initC2FacilitiesContext(iadsConfig, iadsContext)

      assert.is_true(ok)
      assert.are.equal("C2 Facility/Sector A", iadsContext.c2["C2-FAC-1"].name)
      assert.are.equal("SAM-1", iadsContext.c2["C2-FAC-1"].sam["SAM-1"].name)
      assert.are.equal("RAD-1", iadsContext.c2["C2-FAC-1"].radar["RAD-1"].name)
    end)

    -- Negative: returns false when side units cannot be loaded
    it("should return false when facility list is unavailable", function()
      local sideObj = { unitsBy = function() return nil end }
      local iadsCfg = { c2Deployments = {}, c2FacilityDBIDs = {} }
      local iadsContext = {}
      trackStub(stub(GameApi, "VP_GetSide").returns(sideObj))

      local ok = IntegratedAirDefenseSystem.initC2FacilitiesContext(iadsCfg, iadsContext)

      assert.is_false(ok)
    end)
  end)

  -- ============================================================================
  -- initIADSContexts
  -- ============================================================================

  describe("initIADSContexts", function()
    -- Positive: initializes rocc and taaoc contexts with matching systems
    it("should populate rocc radar sam and taaoc sam entries", function()
      local areaA = "A-1"
      local roccNode = makeUnit({ guid = "ROCC-1", name = "ROCC 1" })
      local taaocNode = makeUnit({ guid = "TAAOC-1", name = "TAAOC 1" })
      local roccSam = makeUnit({
        guid = "PAC3-1",
        name = "PAC3",
        dbid = constants.PLATFORMS.PAC3,
        inArea = function(_, area) return area == areaA end,
      })
      local roccRadar = makeUnit({
        guid = "FPS-1",
        name = "FPS117",
        dbid = constants.PLATFORMS.FPS117,
        inArea = function(_, area) return area == areaA end,
      })
      local taaocSam = makeUnit({
        guid = "TC2-1",
        name = "TC2",
        dbid = constants.PLATFORMS.TC2,
        inArea = function(_, area) return area == areaA end,
      })

      local filtered = { { guid = "PAC3-1" }, { guid = "FPS-1" }, { guid = "TC2-1" } }
      local sideObj = { unitsBy = function() return filtered end }

      trackStub(stub(GameApi, "VP_GetSide").returns(sideObj))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(a, b)
        if b == constants.SIDES.PLAYER then
          if a == "ROCC-Node" then return roccNode end
          if a == "TAAOC-Node" then return taaocNode end
        end
        if a == "PAC3-1" then return roccSam end
        if a == "FPS-1" then return roccRadar end
        if a == "TC2-1" then return taaocSam end
        return nil
      end))

      local cfg = {
        rocc = { makeDescriptor({ name = "ROCC-Node", areas = { areaA } }) },
        taaoc = { makeDescriptor({ name = "TAAOC-Node", areas = { areaA } }) },
      }
      local iadsContext = { rocc = {}, taaoc = {} }

      IntegratedAirDefenseSystem.initIADSContexts(cfg, iadsContext)

      assert.are.equal("PAC3", iadsContext.rocc["ROCC-1"].sam["PAC3-1"].name)
      assert.are.equal("FPS117", iadsContext.rocc["ROCC-1"].radar["FPS-1"].name)
      assert.are.equal("TC2", iadsContext.taaoc["TAAOC-1"].sam["TC2-1"].name)
      assert.is_nil(iadsContext.taaoc["TAAOC-1"].radar)
    end)

    -- Negative: returns immediately when player side has no facilities
    it("should keep context unchanged when no facility units are found", function()
      local sideObj = { unitsBy = function() return nil end }
      local iadsCfg = { rocc = {}, taaoc = {} }
      trackStub(stub(GameApi, "VP_GetSide").returns(sideObj))

      local iadsContext = { rocc = {}, taaoc = {} }
      IntegratedAirDefenseSystem.initIADSContexts(iadsCfg, iadsContext)

      assert.is_nil(next(iadsContext.rocc))
      assert.is_nil(next(iadsContext.taaoc))
    end)
  end)

  -- ============================================================================
  -- removeC2Facilities
  -- ============================================================================

  describe("removeC2Facilities", function()
    -- Positive: deletes units matching configured c2 dbids
    it("should remove facilities that match c2 facility dbids", function()
      local f1 = makeUnit({ guid = "F-1", dbid = 9001 })
      local f2 = makeUnit({ guid = "F-2", dbid = 7777 })
      local filtered = { { guid = "F-1" }, { guid = "F-2" } }
      local sideObj = { unitsBy = function() return filtered end }
      local cfg = { c2FacilityDBIDs = { 9001 } }

      trackStub(stub(GameApi, "VP_GetSide").returns(sideObj))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
        if guid == "F-1" then return f1 end
        if guid == "F-2" then return f2 end
        return nil
      end))
      local stubDelete = trackStub(stub(GameApi, "ScenEdit_DeleteUnit").returns(true))

      local ok = IntegratedAirDefenseSystem.removeC2Facilities(cfg)

      assert.is_true(ok)
      assert.stub(stubDelete).was.called(1)
      assert.stub(stubDelete).was.called_with({ side = constants.SIDES.ENEMY, guid = "F-1" })
    end)

    -- Negative: returns false when facility list is unavailable
    it("should return false when side query returns nil", function()
      local sideObj = { unitsBy = function() return nil end }
      local cfg = { c2FacilityDBIDs = { 9001 } }
      trackStub(stub(GameApi, "VP_GetSide").returns(sideObj))

      local ok = IntegratedAirDefenseSystem.removeC2Facilities(cfg)

      assert.is_false(ok)
    end)
  end)
end)
