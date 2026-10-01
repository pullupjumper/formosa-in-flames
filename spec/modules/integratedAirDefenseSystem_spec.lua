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
  -- setSamDoctrine
  -- ============================================================================

  describe("setSamDoctrine", function()
    local setDoctrineStub
    local setEmissionStub
    local candidates = { { guid = "PAC-1" }, { guid = "TC2-1" }, { guid = "GONE" } }

    before_each(function()
      local units = {
        ["PAC-1"] = makeUnit({ guid = "PAC-1", dbid = constants.PLATFORMS.PAC3 }),
        ["TC2-1"] = makeUnit({ guid = "TC2-1", dbid = constants.PLATFORMS.TC2 }),
      }
      trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid) return units[guid] end))
      setDoctrineStub = trackStub(stub(GameApi, "ScenEdit_SetDoctrine"))
      setEmissionStub = trackStub(stub(GameApi, "ScenEdit_SetUnitIntermittentEmissionConfig"))
    end)

    -- Positive: only the chosen SAM type is changed, and it wakes on threat
    it("should set WCS tight and wake emissions for weapons-free SAM types", function()
      IntegratedAirDefenseSystem.setSamDoctrine({ { id = "pac23", weaponsFree = true } }, candidates)

      assert.stub(setDoctrineStub).was.called(1)
      assert.stub(setDoctrineStub).was.called_with({ guid = "PAC-1" },
        { weapon_control_status_air = constants.WCS.TIGHT })
      assert.stub(setEmissionStub).was.called_with("PAC-1", "Green",
        { WakeWhenDetectingThreat = 1, UseEmissionInterval = 1 })
    end)

    -- Positive: weapons hold keeps emissions asleep
    it("should set WCS hold and keep emissions asleep when weapons are not free", function()
      IntegratedAirDefenseSystem.setSamDoctrine({ { id = "tc2", weaponsFree = false } }, candidates)

      assert.stub(setDoctrineStub).was.called_with({ guid = "TC2-1" },
        { weapon_control_status_air = constants.WCS.HOLD })
      assert.stub(setEmissionStub).was.called_with("TC2-1", "Green",
        { WakeWhenDetectingThreat = 0, UseEmissionInterval = 0 })
    end)

    -- Negative: unknown menu ids touch nothing
    it("should ignore unknown SAM menu ids", function()
      IntegratedAirDefenseSystem.setSamDoctrine({ { id = "nope", weaponsFree = true } }, candidates)

      assert.stub(setDoctrineStub).was_not.called()
    end)
  end)

  -- ============================================================================
  -- processC2Disruption
  -- ============================================================================

  describe("processC2Disruption", function()
    -- Positive: disables radar and sam units under the destroyed node on the node's own side
    it("should disable linked units and remove c2 context", function()
      local radar = makeUnit({ guid = "RAD-1" })
      local sam = makeUnit({ guid = "SAM-1" })
      local c2 = makeUnit({ guid = "C2-1", name = "C2 Node", side = constants.SIDES.RED })
      local saveData = {
        red = {
          iads = {
            c2 = {
              ["C2-1"] = {
                radar = { ["RAD-1"] = { guid = "RAD-1", isOutOfComms = false } },
                sam = { ["SAM-1"] = { guid = "SAM-1", isOutOfComms = false } },
              },
            },
          },
        },
      }

      trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
        if guid == "RAD-1" then return radar end
        if guid == "SAM-1" then return sam end
        return nil
      end))
      local stubSetUnit = trackStub(stub(GameApi, "ScenEdit_SetUnit").returns(true))

      IntegratedAirDefenseSystem.processC2Disruption(saveData, c2)

      assert.is_nil(saveData.red.iads.c2["C2-1"])
      assert.stub(stubSetUnit).was.called(2)
      assert.stub(stubSetUnit).was.called_with({ guid = "RAD-1", outofcomms = true })
      assert.stub(stubSetUnit).was.called_with({ guid = "SAM-1", outofcomms = true })
    end)

    -- Negative: no-op when guid not found in any context
    it("should not disable any unit when c2 guid is not tracked", function()
      local c2 = makeUnit({ guid = "C2-MISSING", side = constants.SIDES.BLUE })
      local saveData = { blue = { iads = { c2 = {}, rocc = {}, taaoc = {} } } }
      local stubSetUnit = trackStub(stub(GameApi, "ScenEdit_SetUnit"))

      IntegratedAirDefenseSystem.processC2Disruption(saveData, c2)

      assert.stub(stubSetUnit).was_not.called()
    end)
  end)

  -- ============================================================================
  -- processUnitDestruction
  -- ============================================================================

  describe("processUnitDestruction", function()
    local cfg = { red = { iads = { radarDistanceNm = 100 } } }

    ---Create one C2 node covering area A-1 with the given sam and radar entries
    ---@param overrides? table
    ---@return table
    local function makeC2Node(overrides)
      local node = { guid = "C2-A", areas = { "A-1" }, sam = {}, radar = {} }
      if overrides then
        for k, v in pairs(overrides) do node[k] = v end
      end
      return node
    end

    ---Create a destroyed unit standing inside area A-1
    ---@param overrides table
    ---@return table
    local function makeDestroyedUnit(overrides)
      overrides.inArea = function(_, area) return area == "A-1" end
      return makeUnit(overrides)
    end

    -- Positive: a Taiwan SAM leaves its ROCC node
    it("should stop tracking a destroyed Taiwan SAM under its ROCC node", function()
      local destroyed = makeDestroyedUnit({
        guid = "SAM-9",
        side = constants.SIDES.BLUE,
        dbid = constants.PLATFORMS
            .PAC3
      })
      local saveData = {
        blue = { iads = { rocc = { ["C2-A"] = makeC2Node({ sam = { ["SAM-9"] = { guid = "SAM-9" } } }) }, taaoc = {} } },
      }

      local handled = IntegratedAirDefenseSystem.processUnitDestruction(cfg, saveData, destroyed)

      assert.is_true(handled)
      assert.is_nil(saveData.blue.iads.rocc["C2-A"].sam["SAM-9"])
    end)

    -- Positive: an MRADS leaves its TAAOC node, not the ROCC one
    it("should stop tracking a destroyed MRADS under its TAAOC node", function()
      local destroyed = makeDestroyedUnit({
        guid = "TC2-9",
        side = constants.SIDES.BLUE,
        dbid = constants.PLATFORMS
            .TC2
      })
      local saveData = {
        blue = {
          iads = {
            rocc = { ["C2-A"] = makeC2Node({ sam = { ["TC2-9"] = { guid = "TC2-9" } } }) },
            taaoc = { ["C2-A"] = makeC2Node({ sam = { ["TC2-9"] = { guid = "TC2-9" } } }) },
          },
        },
      }

      IntegratedAirDefenseSystem.processUnitDestruction(cfg, saveData, destroyed)

      assert.is_nil(saveData.blue.iads.taaoc["C2-A"].sam["TC2-9"])
      assert.is_not_nil(saveData.blue.iads.rocc["C2-A"].sam["TC2-9"])
    end)

    -- Positive: a lost China radar leaves its C2 node and wakes the nearest dedicated radar before a closer SAM
    it("should activate nearest dedicated radar first when a China radar is destroyed", function()
      local destroyed = makeDestroyedUnit({
        guid = "RAD-X", side = constants.SIDES.RED, dbid = constants.PLATFORMS.JY26, latitude = 10, longitude = 20,
      })
      local saveData = { red = { iads = { c2 = { ["C2-A"] = makeC2Node({ radar = { ["RAD-X"] = { guid = "RAD-X" } } }) } } } }
      local radarA = makeUnit({ guid = "RAD-A", name = "JY-26", dbid = constants.PLATFORMS.JY26 })
      local samA = makeUnit({ guid = "SAM-A", name = "HQ-22", dbid = constants.PLATFORMS.HQ22 })

      trackStub(stub(GameApi, "VP_GetSide").returns({ unitsBy = function() return { { guid = "RAD-A" }, { guid = "SAM-A" } } end }))
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

      local handled = IntegratedAirDefenseSystem.processUnitDestruction(cfg, saveData, destroyed)

      assert.is_true(handled)
      assert.is_nil(saveData.red.iads.c2["C2-A"].radar["RAD-X"])
      assert.stub(stubSetEmcon).was.called_with("Unit", "RAD-A", "Radar=Active")
    end)

    -- Negative: a lost China SAM wakes nothing when every backup is out of range
    it("should not activate any radar when all candidates are out of range", function()
      local destroyed = makeDestroyedUnit({
        guid = "SAM-X",
        side = constants.SIDES.RED,
        dbid = constants.PLATFORMS
            .HQ22
      })
      local saveData = { red = { iads = { c2 = {} } } }
      local radarA = makeUnit({ guid = "RAD-A", dbid = constants.PLATFORMS.JY26 })

      trackStub(stub(GameApi, "VP_GetSide").returns({ unitsBy = function() return { { guid = "RAD-A" } } end }))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(radarA))
      trackStub(stub(GameApi, "Tool_Range").returns(150))
      local stubSetEmcon = trackStub(stub(GameApi, "ScenEdit_SetEMCON"))

      IntegratedAirDefenseSystem.processUnitDestruction(cfg, saveData, destroyed)

      assert.stub(stubSetEmcon).was_not.called()
    end)

    -- Negative: a unit that is not an IADS radar or SAM is left to the caller
    it("should report a non-IADS unit as not handled", function()
      local destroyed = makeUnit({ side = constants.SIDES.BLUE, dbid = 1001 })
      local saveData = { blue = { iads = { rocc = {}, taaoc = {} } } }

      assert.is_false(IntegratedAirDefenseSystem.processUnitDestruction(cfg, saveData, destroyed))
    end)

    -- Boundary: keeps data when unit is outside all areas
    it("should keep context unchanged when destroyed unit is outside areas", function()
      local destroyed = makeUnit({ guid = "RAD-2", side = constants.SIDES.BLUE, dbid = constants.PLATFORMS.FPS117 })
      local saveData = {
        blue = { iads = { rocc = { ["C2-A"] = makeC2Node({ radar = { ["RAD-2"] = { guid = "RAD-2" } } }) }, taaoc = {} } },
      }

      IntegratedAirDefenseSystem.processUnitDestruction(cfg, saveData, destroyed)

      assert.are.equal("RAD-2", saveData.blue.iads.rocc["C2-A"].radar["RAD-2"].guid)
    end)
  end)

  -- ============================================================================
  -- deployC2Facilities
  -- ============================================================================

  describe("deployC2Facilities", function()
    ---Create a config whose China IADS section has the given overrides
    ---@param overrides? table
    ---@return table
    local function makeConfig(overrides)
      local iads = {
        c2Deployments = {},
        c2FacilityDBIDs = { 9001 },
        randomRadiusNm = 5,
      }
      if overrides then
        for k, v in pairs(overrides) do iads[k] = v end
      end
      return { red = { iads = iads } }
    end

    -- Positive: old facilities go before one new group is created per deployment
    it("should delete facilities matching c2 dbids and create one group per deployment", function()
      local f1 = makeUnit({ guid = "F-1", dbid = 9001 })
      local f2 = makeUnit({ guid = "F-2", dbid = 7777 })
      local config = makeConfig({
        c2Deployments = {
          { name = "Sector A", areas = {}, pos = { latitude = 1, longitude = 2 } },
          { name = "Sector B", areas = {}, pos = { latitude = 3, longitude = 4 } },
        },
      })
      local saveData = { red = { iads = {} } }

      trackStub(stub(GameApi, "VP_GetSide").returns({ unitsBy = function() return { { guid = "F-1" }, { guid = "F-2" } } end }))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
        if guid == "F-1" then return f1 end
        if guid == "F-2" then return f2 end
        return nil
      end))
      local stubDelete = trackStub(stub(GameApi, "ScenEdit_DeleteUnit").returns(true))
      local stubCreate = trackStub(stub(GameUtils, "createRandomUnits").returns({ { guid = "F1" } }))

      IntegratedAirDefenseSystem.deployC2Facilities(config, saveData)

      assert.stub(stubDelete).was.called(1)
      assert.stub(stubDelete).was.called_with({ side = constants.SIDES.RED, guid = "F-1" })
      assert.stub(stubCreate).was.called(2)
    end)

    -- Positive: a random facility in each sector becomes that sector's C2 node, owning the SAMs and radars around it
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
      local saveData = { red = { iads = {} } }

      trackStub(stub(GameApi, "VP_GetSide").returns({ unitsBy = function() return filtered end }))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
        if guid == "C2-FAC-1" then return chosenC2 end
        if guid == "SAM-1" then return sam end
        if guid == "RAD-1" then return radar end
        return nil
      end))
      trackStub(stub(GameApi, "ScenEdit_DeleteUnit"))
      trackStub(stub(GameUtils, "createRandomUnits").returns({ { guid = "C2-FAC-1" } }))
      trackStub(stub(math, "random").returns(1))

      IntegratedAirDefenseSystem.deployC2Facilities(
        makeConfig({ c2Deployments = { { name = "Sector A", areas = { areaA }, pos = {} } } }),
        saveData
      )

      local c2Map = saveData.red.iads.c2
      assert.are.equal("C2 Facility/Sector A", c2Map["C2-FAC-1"].name)
      assert.are.equal("SAM-1", c2Map["C2-FAC-1"].sam["SAM-1"].name)
      assert.are.equal("RAD-1", c2Map["C2-FAC-1"].radar["RAD-1"].name)
    end)

    -- Negative: a failed group stops the remaining deployments
    it("should stop creating facilities after a deployment fails", function()
      local config = makeConfig({
        c2Deployments = {
          { name = "Sector A", areas = {}, pos = { latitude = 1, longitude = 2 } },
          { name = "Sector B", areas = {}, pos = { latitude = 3, longitude = 4 } },
        },
      })
      local saveData = { red = { iads = {} } }

      trackStub(stub(GameApi, "VP_GetSide").returns({ unitsBy = function() return {} end }))
      local stubCreate = trackStub(stub(GameUtils, "createRandomUnits").returns({}))

      IntegratedAirDefenseSystem.deployC2Facilities(config, saveData)

      assert.stub(stubCreate).was.called(1)
    end)

    -- Boundary: without a facility list nothing is deleted and old C2 nodes are dropped
    it("should clear c2 context and delete nothing when facility list is unavailable", function()
      local saveData = { red = { iads = { c2 = { stale = {} } } } }
      trackStub(stub(GameApi, "VP_GetSide").returns({ unitsBy = function() return nil end }))
      local stubDelete = trackStub(stub(GameApi, "ScenEdit_DeleteUnit"))

      IntegratedAirDefenseSystem.deployC2Facilities(makeConfig(), saveData)

      assert.stub(stubDelete).was_not.called()
      assert.are.same({}, saveData.red.iads.c2)
    end)
  end)

  -- ============================================================================
  -- initSide
  -- ============================================================================

  describe("initSide", function()
    -- Positive: Taiwan links SAMs and radars to ROCC and MRADS to TAAOC
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

      trackStub(stub(GameApi, "VP_GetSide").returns({ unitsBy = function() return filtered end }))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(a, b)
        if b == constants.SIDES.BLUE then
          if a == "ROCC-Node" then return roccNode end
          if a == "TAAOC-Node" then return taaocNode end
        end
        if a == "PAC3-1" then return roccSam end
        if a == "FPS-1" then return roccRadar end
        if a == "TC2-1" then return taaocSam end
        return nil
      end))

      local config = {
        blue = {
          iads = {
            rocc = { makeDescriptor({ name = "ROCC-Node", areas = { areaA } }) },
            taaoc = { makeDescriptor({ name = "TAAOC-Node", areas = { areaA } }) },
          },
        },
      }
      local saveData = { blue = { iads = { enabled = true, rocc = {}, taaoc = {} } } }

      IntegratedAirDefenseSystem.initSide(config, saveData, constants.SIDES.BLUE)

      local iadsCtx = saveData.blue.iads
      assert.are.equal("PAC3", iadsCtx.rocc["ROCC-1"].sam["PAC3-1"].name)
      assert.are.equal("FPS117", iadsCtx.rocc["ROCC-1"].radar["FPS-1"].name)
      assert.are.equal("TC2", iadsCtx.taaoc["TAAOC-1"].sam["TC2-1"].name)
      assert.is_nil(iadsCtx.taaoc["TAAOC-1"].radar)
    end)

    -- Positive: China builds C2 nodes rather than ROCC/TAAOC ones
    it("should build China's c2 map from its own IADS config", function()
      local config = { red = { iads = { c2Deployments = {}, c2FacilityDBIDs = {} } } }
      local saveData = { red = { iads = { enabled = true } } }
      trackStub(stub(GameApi, "VP_GetSide").returns({ unitsBy = function() return {} end }))

      IntegratedAirDefenseSystem.initSide(config, saveData, constants.SIDES.RED)

      assert.are.same({}, saveData.red.iads.c2)
    end)

    -- Negative: a disabled IADS is not built at all
    it("should not scan units when the side's IADS is disabled", function()
      local config = { blue = { iads = {} } }
      local saveData = { blue = { iads = { enabled = false } } }
      local getSideStub = trackStub(stub(GameApi, "VP_GetSide"))

      IntegratedAirDefenseSystem.initSide(config, saveData, constants.SIDES.BLUE)

      assert.stub(getSideStub).was_not.called()
    end)

    -- Boundary: returns immediately when player side has no facilities
    it("should keep context unchanged when no facility units are found", function()
      trackStub(stub(GameApi, "VP_GetSide").returns({ unitsBy = function() return nil end }))
      local config = { blue = { iads = { rocc = {}, taaoc = {} } } }
      local saveData = { blue = { iads = { enabled = true, rocc = {}, taaoc = {} } } }

      IntegratedAirDefenseSystem.initSide(config, saveData, constants.SIDES.BLUE)

      assert.is_nil(next(saveData.blue.iads.rocc))
      assert.is_nil(next(saveData.blue.iads.taaoc))
    end)
  end)
end)
