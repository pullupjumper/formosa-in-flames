-- MissileSystem SetupLayout Unit Tests
local stub = require("luassert.stub")
local SetupLayout = require("src.modules.missileSystem.setupLayout")
local GameApi = require("src.utils.gameApi")
local Utils = require("src.utils.utils")
local constants = require("src.core.constants")

describe("MissileSystem SetupLayout", function()
  ---@type luassert.spy[]
  local activeStubs

  ---Track and register method stub for automatic cleanup.
  ---@param obj table
  ---@param method string
  ---@return luassert.spy
  local function trackStub(obj, method)
    local s = stub(obj, method)
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
  end)

  local function path(lat)
    return { waypoints = { { latitude = lat, longitude = 121 } } }
  end

  local function fastCourse(lat)
    return {
      { latitude = lat, longitude = 121, desiredSpeed = constants.SPEEDS.FAST, presetThrottle = constants.THROTTLES.FLANK }
    }
  end

  local function makeEntry()
    return {
      unitname = "FU-1",
      category = "srbm",
      tacticalAreas = {
        uShapeVertices = { "U" },
        shelterPoints = { "S" },
        reloadArea = { "RL" },
        ammoArea = { "AHA" },
        hideArea = { "HA" },
        firePoints = { { "FP1" }, { "FP2" } }
      },
      paths = {
        FP = { path(1), path(2) },
        RL = { path(3), path(99) },
        AHA = path(4),
        HA = path(5),
        SHRL = path(6)
      }
    }
  end

  describe("buildLayouts", function()
    it("should turn every path into a fast course paired with its zone", function()
      trackStub(Utils, "buildRandomText").returns("ABC")

      local layouts = SetupLayout.buildLayouts({ makeEntry() })

      assert.are.same({
        {
          category = "srbm",
          unitname = "FU-1",
          operationalArea = {
            FP = {
              { course = fastCourse(1), area = { "FP1" } },
              { course = fastCourse(2), area = { "FP2" } }
            },
            RL = { { course = fastCourse(3), area = { "RL" } } },
            AHA = { { course = fastCourse(4), area = { "AHA" } } },
            HA = { { course = fastCourse(5), area = { "HA" } } },
            SHRL = { { course = fastCourse(6), area = { "RL" } } },
            uShapeVertices = { "U" },
            shelterPoints = { "S" },
            name = "#ABC"
          }
        }
      }, layouts)
    end)

    it("should give each layout its own 3-letter area name", function()
      local buildRandomTextStub = trackStub(Utils, "buildRandomText")
      buildRandomTextStub.on_call_with(3).returns("AAA")

      local layouts = SetupLayout.buildLayouts({ makeEntry(), makeEntry() })

      assert.are.equal(2, #layouts)
      assert.stub(buildRandomTextStub).was.called(2)
      assert.stub(buildRandomTextStub).was.called_with(3)
      assert.are.equal("#AAA", layouts[2].operationalArea.name)
    end)
  end)

  describe("buildSetupMenuRows", function()
    local function makeGroundForceCfg()
      return {
        srbm = {
          reloadTime = 60,
          resupplyUnits = { rs = {} },
          ammunitions = { aha = {} },
          firingUnits = {
            fu = {
              name = "FU-1",
              operationalArea = {
                HA = { { area = { "rp-1" } } },
                FP = { { area = { "rp-missing" } }, { course = {} } },
                mask = { area = { "rp-mask" } }
              }
            }
          }
        }
      }
    end

    before_each(function()
      trackStub(GameApi, "ScenEdit_GetReferencePoints").invokes(function(selector)
        if selector.area[1] == "rp-1" then
          return { { latitude = "25.5", longitude = "121.5" } }
        end
        if selector.area[1] == "rp-mask" then
          return { { latitude = "24", longitude = "120" } }
        end
        return nil
      end)
    end)

    it("should drop resupply units and ammunitions from the copy", function()
      local rows = SetupLayout.buildSetupMenuRows(makeGroundForceCfg(), "Taiwan")

      assert.is_nil(rows.srbm.resupplyUnits)
      assert.is_nil(rows.srbm.ammunitions)
      assert.are.equal(60, rows.srbm.reloadTime)
    end)

    it("should resolve zone names to numeric vertices and keep unresolved ones", function()
      local rows = SetupLayout.buildSetupMenuRows(makeGroundForceCfg(), "Taiwan")
      local operationalArea = rows.srbm.firingUnits.fu.operationalArea

      assert.are.same({ { latitude = 25.5, longitude = 121.5 } }, operationalArea.HA[1].area)
      assert.are.same({ "rp-missing" }, operationalArea.FP[1].area)
      assert.are.same({ { latitude = 24, longitude = 120 } }, operationalArea.uShapeVertices)
    end)

    it("should leave the source config untouched", function()
      local groundForceCfg = makeGroundForceCfg()
      SetupLayout.buildSetupMenuRows(groundForceCfg, "Taiwan")

      assert.are.same({ "rp-1" }, groundForceCfg.srbm.firingUnits.fu.operationalArea.HA[1].area)
      assert.is_not_nil(groundForceCfg.srbm.resupplyUnits)
    end)
  end)
end)
