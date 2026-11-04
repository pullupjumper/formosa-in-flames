---@diagnostic disable: need-check-nil, assign-type-mismatch, cast-local-type, param-type-mismatch, inject-field
-- MissileSystem ControlPanelLayout Unit Tests
local ControlPanelLayout = require("src.modules.missileSystem.controlPanelLayout")
local GameApi = require("src.utils.gameApi")
local Utils = require("src.utils.utils")
local constants = require("src.core.constants")

describe("MissileSystem ControlPanelLayout", function()
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

  ---Create a one-waypoint control panel path
  ---@param latitude number Distinguishes paths in assertions
  ---@return table
  local function makePath(latitude)
    return { waypoints = { { latitude = latitude, longitude = 121 } } }
  end

  ---Expected course for a makePath path
  ---@param latitude number
  ---@return table
  local function fastCourse(latitude)
    return {
      { latitude = latitude, longitude = 121, desiredSpeed = constants.SPEEDS.FAST, presetThrottle = constants.THROTTLES.FLANK }
    }
  end

  ---Create a control panel battery entry with two fire points
  ---@param overrides? table
  ---@return table
  local function makeEntry(overrides)
    local entry = {
      unitname = "FU-1",
      missileSystemType = "srbm",
      tacticalAreas = {
        uShapeVertices = { "U" },
        shelterPoints = { "S" },
        reloadArea = { "RL" },
        ammoArea = { "AHA" },
        hideArea = { "HA" },
        firePoints = { { "FP1" }, { "FP2" } }
      },
      paths = {
        FP = { makePath(1), makePath(2) },
        RL = { makePath(3), makePath(99) },
        AHA = makePath(4),
        HA = makePath(5),
        SHRL = makePath(6)
      }
    }
    if overrides then
      for k, v in pairs(overrides) do entry[k] = v end
    end
    return entry
  end

  ---Create a ground force config with one SRBM firing unit
  ---@param overrides? table Fields merged into the firing unit's operational area
  ---@return table
  local function makeMissileSystemConfigMap(overrides)
    local operationalArea = {
      HA = { { area = { "rp-1" } } },
      FP = { { area = { "rp-missing" } }, { course = {} } },
      mask = { area = { "rp-mask" } }
    }
    if overrides then
      for k, v in pairs(overrides) do operationalArea[k] = v end
    end
    return {
      srbm = {
        reloadTime = 60,
        resupplyUnits = { rs = {} },
        ammunitions = { aha = {} },
        firingUnits = { fu = { name = "FU-1", operationalArea = operationalArea } }
      }
    }
  end

  -- ============================================================================
  -- buildLayouts
  -- ============================================================================

  describe("buildLayouts", function()
    -- Positive: only the first RL path is used, and SHRL shares the reload zone
    it("should turn every path into a fast course paired with its zone", function()
      trackStub(stub(Utils, "buildRandomText").returns("ABC"))

      local layouts = ControlPanelLayout.buildLayouts({ makeEntry() })

      assert.are.same({
        {
          missileSystemType = "srbm",
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

    -- Positive: each entry gets its own random 3-letter area name
    it("should build one named layout per entry", function()
      local buildRandomTextStub = trackStub(stub(Utils, "buildRandomText").returns("AAA"))

      local layouts = ControlPanelLayout.buildLayouts({ makeEntry(), makeEntry({ unitname = "FU-2" }) })

      assert.are.equal(2, #layouts)
      assert.are.equal("FU-2", layouts[2].unitname)
      assert.stub(buildRandomTextStub).was.called_with(3)
    end)

    -- Boundary: nothing submitted means nothing to redeploy
    it("should return no layouts for no entries", function()
      assert.are.same({}, ControlPanelLayout.buildLayouts({}))
    end)
  end)

  -- ============================================================================
  -- buildDeploymentSystems
  -- ============================================================================

  describe("buildDeploymentSystems", function()
    local queryDbStub

    ---Ground state with nothing saved yet, so every row comes from config
    ---@return SBJ__GroundState
    local function emptyGroundState()
      return { enabled = true, missileSystemTypes = {} }
    end

    before_each(function()
      queryDbStub = trackStub(stub(GameApi, "ScenEdit_QueryDB").returns({ ranges = { land = { max = 150 } } }))
      trackStub(stub(GameApi, "ScenEdit_GetReferencePoints").invokes(function(selector)
        if selector.area[1] == "rp-1" then
          return { { latitude = "25.5", longitude = "121.5" } }
        end
        if selector.area[1] == "rp-mask" then
          return { { latitude = "24", longitude = "120" } }
        end
        return nil
      end))
    end)

    -- Positive: the control panel only needs firing units
    it("should drop resupply units and ammunitions from the copy", function()
      local rows = ControlPanelLayout.buildDeploymentSystems(makeMissileSystemConfigMap(), emptyGroundState(), "Taiwan")

      assert.is_nil(rows.srbm.resupplyUnits)
      assert.is_nil(rows.srbm.ammunitions)
      assert.are.equal(60, rows.srbm.reloadTime)
    end)

    -- Positive: the map draws the weapon's range circle from this
    it("should set weaponRange from the weapon database", function()
      local rows = ControlPanelLayout.buildDeploymentSystems(makeMissileSystemConfigMap(), emptyGroundState(), "Taiwan")

      assert.are.equal(150, rows.srbm.firingUnits.fu.weaponRange)
    end)

    -- Negative: an unknown weapon must not break the panel
    it("should set weaponRange to 0 when the weapon is not in the database", function()
      queryDbStub:revert()
      trackStub(stub(GameApi, "ScenEdit_QueryDB").returns(nil))

      local rows = ControlPanelLayout.buildDeploymentSystems(makeMissileSystemConfigMap(), emptyGroundState(), "Taiwan")

      assert.are.equal(0, rows.srbm.firingUnits.fu.weaponRange)
    end)

    -- Positive: zone names become numeric vertices the menu can draw
    it("should resolve zone and mask names to numeric vertices", function()
      local rows = ControlPanelLayout.buildDeploymentSystems(makeMissileSystemConfigMap(), emptyGroundState(), "Taiwan")
      local operationalArea = rows.srbm.firingUnits.fu.operationalArea

      assert.are.same({ { latitude = 25.5, longitude = 121.5 } }, operationalArea.HA[1].area)
      assert.are.same({ { latitude = 24, longitude = 120 } }, operationalArea.uShapeVertices)
    end)

    -- Negative: the caller's config must survive for the next redeploy
    it("should leave the source config untouched", function()
      local missileSystemConfigMap = makeMissileSystemConfigMap()

      ControlPanelLayout.buildDeploymentSystems(missileSystemConfigMap, emptyGroundState(), "Taiwan")

      assert.are.same({ "rp-1" }, missileSystemConfigMap.srbm.firingUnits.fu.operationalArea.HA[1].area)
      assert.is_not_nil(missileSystemConfigMap.srbm.resupplyUnits)
    end)

    -- Boundary: reference points that no longer exist keep their names
    it("should keep zone names that resolve to no vertices", function()
      local rows = ControlPanelLayout.buildDeploymentSystems(makeMissileSystemConfigMap(), emptyGroundState(), "Taiwan")

      assert.are.same({ "rp-missing" }, rows.srbm.firingUnits.fu.operationalArea.FP[1].area)
    end)

    ---Ground state holding one saved firing unit placed at a redeployed area
    ---@return table
    local function groundStateWithSavedArea()
      return {
        enabled = true,
        missileSystemTypes = {
          srbm = {
            firingUnits = {
              ["FU-1"] = {
                name = "FU-1",
                operationalArea = { name = "#ABC", HA = { { area = { "rp-1" } } }, mask = { area = { "rp-mask" } } }
              }
            }
          }
        }
      }
    end

    -- Positive: after a save/load the config is the template again, but the panel must show the player's placement
    it("should draw a firing unit at its saved operational area", function()
      local rows = ControlPanelLayout.buildDeploymentSystems(makeMissileSystemConfigMap(), groundStateWithSavedArea(),
        "Taiwan")
      local operationalArea = rows.srbm.firingUnits.fu.operationalArea

      assert.are.equal("#ABC", operationalArea.name)
      assert.is_nil(operationalArea.FP)
      assert.are.same({ { latitude = 25.5, longitude = 121.5 } }, operationalArea.HA[1].area)
    end)

    -- Negative: resolving vertices must not rewrite the saved state
    it("should leave the saved operational area untouched", function()
      local groundState = groundStateWithSavedArea()

      ControlPanelLayout.buildDeploymentSystems(makeMissileSystemConfigMap(), groundState, "Taiwan")

      assert.are.same({ "rp-1" }, groundState.missileSystemTypes.srbm.firingUnits["FU-1"].operationalArea.HA[1].area)
    end)

    -- Boundary: an unresolved mask leaves no U-shape rather than an empty one
    it("should not set U-shape vertices when the mask does not resolve", function()
      local rows = ControlPanelLayout.buildDeploymentSystems(
        makeMissileSystemConfigMap({ mask = { area = { "rp-missing" } } }), emptyGroundState(), "Taiwan")

      assert.is_nil(rows.srbm.firingUnits.fu.operationalArea.uShapeVertices)
    end)
  end)
end)
