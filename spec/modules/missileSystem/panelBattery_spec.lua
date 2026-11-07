---@diagnostic disable: need-check-nil, assign-type-mismatch, cast-local-type, param-type-mismatch, inject-field
-- MissileSystem PanelBattery Unit Tests
local PanelBattery = require("src.modules.missileSystem.panelBattery")
local GameApi = require("src.utils.gameApi")
local Utils = require("src.utils.utils")
local constants = require("src.core.constants")
local GameUtils = require("src.utils.gameUtils")

describe("MissileSystem PanelBattery", function()
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

  ---Create a control panel battery placement with two fire points
  ---@param overrides? table
  ---@return table
  local function makePlacement(overrides)
    local placement = {
      tacticalAreas = {
        uShapeVertices = { "U" },
        shelterPoints = { "S" },
        RL = { { "RL" } },
        ATP = { { "ATP" } },
        HA = { { "HA" } },
        FP = { { "FP1" }, { "FP2" } }
      },
      paths = {
        FP = { makePath(1), makePath(2) },
        RL = { makePath(3) },
        ATP = { makePath(4) },
        HA = { makePath(5) },
        SHRL = { makePath(6) }
      }
    }
    if overrides then
      for k, v in pairs(overrides) do placement[k] = v end
    end
    return placement
  end

  ---A one-waypoint course
  ---@param latitude number Distinguishes courses in assertions
  ---@return CMO__Location[]
  local function course(latitude)
    return { { latitude = latitude, longitude = 121 } }
  end

  ---An operational area as config stores it: zones are reference point names, one course per zone
  ---@param overrides? table
  ---@return table
  local function makeOperationalArea(overrides)
    local operationalArea = {
      FP = { { course = course(1), area = { "rp-fp" } }, { course = course(2), area = { "rp-missing" } } },
      RL = { { course = course(3), area = { "rp-rl" } } },
      ATP = { { course = course(4), area = { "rp-atp" } } },
      HA = { { course = course(5), area = { "rp-1" } } },
      mask = { area = { "rp-mask" } },
      shelterPoints = { { latitude = 9, longitude = 9 } }
    }
    if overrides then
      for k, v in pairs(overrides) do operationalArea[k] = v end
    end
    return operationalArea
  end

  ---Create a ground force config with one SRBM battery
  ---@param overrides? table Fields merged into the launcher's operational area
  ---@return table
  local function makeMissileSystemConfigMap(overrides)
    return {
      srbm = {
        reloadTime = 60,
        transloaders = { ["RS-1"] = { name = "RS-1", canisterStock = "ATP-1", weaponCountDefault = 8 } },
        canisterStocks = { ["ATP-1"] = { name = "ATP-1", weaponCountDefault = 24 } },
        launchers = {
          ["FU-1"] = {
            name = "FU-1",
            missileSystem = "HF-3",
            transloader = "RS-1",
            operationalArea = makeOperationalArea(overrides)
          }
        }
      }
    }
  end

  ---Vertices each reference point name resolves to; names not listed resolve to nothing
  local VERTICES = {
    ["rp-1"] = { latitude = 25.5, longitude = 121.5 },
    ["rp-2"] = { latitude = 26, longitude = 122 },
    ["rp-fp"] = { latitude = 25, longitude = 121 },
    ["rp-rl"] = { latitude = 23, longitude = 121 },
    ["rp-atp"] = { latitude = 22, longitude = 121 },
    ["rp-mask"] = { latitude = 24, longitude = 120 },
  }

  before_each(function()
    trackStub(stub(GameApi, "ScenEdit_GetReferencePoints").invokes(function(selector)
      local vertex = VERTICES[selector.area[1]]
      return vertex and { { latitude = tostring(vertex.latitude), longitude = tostring(vertex.longitude) } } or nil
    end))
  end)

  -- ============================================================================
  -- buildOperationalArea
  -- ============================================================================

  describe("buildOperationalArea", function()
    -- Positive: every position takes the zone at its own index, and a shelter loop ends in the reload zone
    it("should turn every path into a fast course paired with its zone", function()
      trackStub(stub(Utils, "buildRandomText").returns("ABC"))

      local operationalArea = PanelBattery.buildOperationalArea(makePlacement())

      assert.are.same({
        FP = {
          { course = fastCourse(1), area = { "FP1" } },
          { course = fastCourse(2), area = { "FP2" } }
        },
        RL = { { course = fastCourse(3), area = { "RL" } } },
        ATP = { { course = fastCourse(4), area = { "ATP" } } },
        HA = { { course = fastCourse(5), area = { "HA" } } },
        SHRL = { { course = fastCourse(6), area = { "RL" } } },
        uShapeVertices = { "U" },
        shelterPoints = { "S" },
        name = "#ABC"
      }, operationalArea)
    end)

    -- Positive: each position type holds as many positions as the placement has paths
    it("should build one position per path of every type", function()
      trackStub(stub(Utils, "buildRandomText").returns("ABC"))
      local placement = makePlacement()
      placement.tacticalAreas.RL = { { "RL1" }, { "RL2" } }
      placement.paths.RL = { makePath(3), makePath(7) }
      placement.paths.SHRL = { makePath(6), makePath(8) }

      local operationalArea = PanelBattery.buildOperationalArea(placement)

      assert.are.same({
        { course = fastCourse(3), area = { "RL1" } },
        { course = fastCourse(7), area = { "RL2" } }
      }, operationalArea.RL)
      assert.are.same({
        { course = fastCourse(6), area = { "RL1" } },
        { course = fastCourse(8), area = { "RL2" } }
      }, operationalArea.SHRL)
    end)

    -- Boundary: no shelter loop leaves SHRL out, so transloaders leave their shelter along RL
    it("should leave SHRL out when the placement has no shelter loop", function()
      local placement = makePlacement()
      placement.paths.SHRL = {}

      assert.is_nil(PanelBattery.buildOperationalArea(placement).SHRL)
    end)

    -- Positive: each call gets its own random 3-letter area name
    it("should name each area with a fresh random 3-letter suffix", function()
      local buildRandomTextStub = trackStub(stub(Utils, "buildRandomText").returns("AAA"))

      PanelBattery.buildOperationalArea(makePlacement())
      PanelBattery.buildOperationalArea(makePlacement())

      assert.stub(buildRandomTextStub).was.called(2)
      assert.stub(buildRandomTextStub).was.called_with(3)
    end)
  end)

  -- ============================================================================
  -- buildPlacement
  -- ============================================================================

  describe("buildPlacement", function()
    -- Positive: each stored course is drawn as the map path it came from
    it("should stitch the HA and ATP paths onto the reload course and keep the RL course as it is", function()
      local placement = PanelBattery.buildPlacement("Taiwan", makeOperationalArea())

      assert.are.same({
        FP = { { waypoints = course(1) }, { waypoints = course(2) } },
        HA = { { waypoints = { course(3)[1], course(5)[1] } } },
        ATP = { { waypoints = { course(3)[1], course(4)[1] } } },
        RL = { { waypoints = course(3) } },
        SHRL = {}
      }, placement.paths)
    end)

    -- Positive: zone and mask names become the vertices the map draws, centered on the U-shape
    it("should resolve zones to vertices and center the placement on the U-shape", function()
      local placement = PanelBattery.buildPlacement("Taiwan", makeOperationalArea())

      assert.are.same({
        uShapeVertices = { VERTICES["rp-mask"] },
        FP = { { VERTICES["rp-fp"] }, {} },
        HA = { { VERTICES["rp-1"] } },
        ATP = { { VERTICES["rp-atp"] } },
        RL = { { VERTICES["rp-rl"] } },
        shelterPoints = { { latitude = 9, longitude = 9 } }
      }, placement.tacticalAreas)
      assert.are.same(VERTICES["rp-mask"], placement.center)
      assert.are.equal(0, placement.openingAngle)
    end)

    -- Positive: a shelter loop is drawn from its own course
    it("should draw the shelter loop course when the area has one", function()
      local placement = PanelBattery.buildPlacement(
        "Taiwan", makeOperationalArea({ SHRL = { { course = course(6), area = { "rp-rl" } } } }))

      assert.are.same({ { waypoints = course(6) } }, placement.paths.SHRL)
    end)

    -- Boundary: a mask whose reference points are gone falls back to the stored U-shape
    it("should fall back to the stored U-shape when the mask does not resolve", function()
      local stored = { { latitude = 1, longitude = 2 }, { latitude = 3, longitude = 4 } }
      local placement = PanelBattery.buildPlacement(
        "Taiwan", makeOperationalArea({ mask = { area = { "rp-missing" } }, uShapeVertices = stored }))

      assert.are.same(stored, placement.tacticalAreas.uShapeVertices)
      assert.are.same({ latitude = 2, longitude = 3 }, placement.center)
    end)

    -- Positive: a placement the panel sends back is drawn again where the player left it
    it("should undo buildOperationalArea for a submitted placement", function()
      trackStub(stub(GameUtils, "findAreaLocations").invokes(function(_, area) return area or {} end))
      local function point(latitude) return { latitude = latitude, longitude = 121 } end
      local tacticalAreas = {
        uShapeVertices = { point(10), point(12) },
        shelterPoints = { point(13) },
        RL = { { point(14) } },
        ATP = { { point(15) } },
        HA = { { point(16) } },
        FP = { { point(17) } }
      }
      -- What the panel sends: HA, ATP and RL with their leading reload waypoint trimmed
      local submitted = makePlacement({
        tacticalAreas = tacticalAreas,
        paths = {
          FP = { { waypoints = { point(1), point(2) } } },
          RL = { { waypoints = { point(3) } } },
          ATP = { { waypoints = { point(4) } } },
          HA = { { waypoints = { point(5) } } },
          SHRL = { { waypoints = { point(6) } } }
        }
      })
      local operationalArea = PanelBattery.buildOperationalArea(submitted)
      operationalArea.mask = { area = tacticalAreas.uShapeVertices }

      local placement = PanelBattery.buildPlacement("Taiwan", operationalArea)

      ---@param waypoints CMO__Location[]
      ---@return number[]
      local function latitudes(waypoints)
        local result = {}
        for _, waypoint in ipairs(waypoints) do table.insert(result, waypoint.latitude) end
        return result
      end
      assert.are.same(tacticalAreas, placement.tacticalAreas)
      assert.are.same({ 1, 2 }, latitudes(placement.paths.FP[1].waypoints))
      assert.are.same({ 3, 5 }, latitudes(placement.paths.HA[1].waypoints))
      assert.are.same({ 3, 4 }, latitudes(placement.paths.ATP[1].waypoints))
      assert.are.same({ 3 }, latitudes(placement.paths.RL[1].waypoints))
      assert.are.same({ 6 }, latitudes(placement.paths.SHRL[1].waypoints))
      assert.are.same(point(11), placement.center)
    end)
  end)

  -- ============================================================================
  -- buildPanelBatteries
  -- ============================================================================

  describe("buildPanelBatteries", function()
    local queryDbStub

    ---Ground state with nothing saved yet, so every battery comes from config
    ---@return SBJ__GroundState
    local function emptyGroundState()
      return { enabled = true, missileSystemTypes = {} }
    end

    ---Ground state holding FU-1's battery, deployed at a redeployed area
    ---@param launcherOverrides? table Fields merged into FU-1's state
    ---@param transloaderOverrides? table Fields merged into RS-1's state
    ---@return table
    local function deployedGroundState(launcherOverrides, transloaderOverrides)
      local launcherState = {
        name = "FU-1",
        state = constants.MISSILE_UNIT_POSTURE.HIDE,
        operationalArea = makeOperationalArea({ name = "#ABC", HA = { { course = course(7), area = { "rp-2" } } } })
      }
      local transloaderState = { name = "RS-1", state = constants.MISSILE_UNIT_POSTURE.STATIC, weaponCountCurrent = 4 }
      for k, v in pairs(launcherOverrides or {}) do launcherState[k] = v end
      for k, v in pairs(transloaderOverrides or {}) do transloaderState[k] = v end
      return {
        enabled = true,
        missileSystemTypes = {
          srbm = {
            launchers = { ["FU-1"] = launcherState },
            transloaders = { ["RS-1"] = transloaderState },
            canisterStocks = { ["ATP-1"] = { name = "ATP-1", weaponCountCurrent = 12 } }
          }
        }
      }
    end

    ---FU-1's status at a game time
    ---@param groundState table
    ---@param currentTime number
    ---@param configMap? table Defaults to makeMissileSystemConfigMap()
    ---@return table
    local function statusAt(groundState, currentTime, configMap)
      return PanelBattery.buildPanelBatteries(configMap or makeMissileSystemConfigMap(), groundState, "Taiwan", currentTime)[1]
          .status
    end

    before_each(function()
      queryDbStub = trackStub(stub(GameApi, "ScenEdit_QueryDB").returns({ ranges = { land = { max = 150 } } }))
    end)

    -- Positive: one battery per launcher, with what the panel lists and draws
    it("should list each launcher with its system, range and placement", function()
      local batteries = PanelBattery.buildPanelBatteries(makeMissileSystemConfigMap(), emptyGroundState(), "Taiwan", 0)

      assert.are.equal(1, #batteries)
      assert.are.equal("FU-1", batteries[1].name)
      assert.are.equal("HF-3", batteries[1].missileSystem)
      assert.are.equal("srbm", batteries[1].missileSystemType)
      assert.are.equal(150, batteries[1].weaponRange)
      assert.are.same({ VERTICES["rp-1"] }, batteries[1].placement.tacticalAreas.HA[1])
    end)

    -- Negative: a battery never deployed has no status to show
    it("should leave out the status before the battery's first deploy", function()
      local batteries = PanelBattery.buildPanelBatteries(makeMissileSystemConfigMap(), emptyGroundState(), "Taiwan", 0)

      assert.is_nil(batteries[1].status)
    end)

    -- Negative: an unknown weapon must not break the panel
    it("should set weaponRange to 0 when the weapon is not in the database", function()
      queryDbStub:revert()
      trackStub(stub(GameApi, "ScenEdit_QueryDB").returns(nil))

      local batteries = PanelBattery.buildPanelBatteries(makeMissileSystemConfigMap(), emptyGroundState(), "Taiwan", 0)

      assert.are.equal(0, batteries[1].weaponRange)
    end)

    -- Positive: after a save/load the config is the template again, but the panel must show the player's placement
    it("should place a deployed battery at its saved area", function()
      local batteries = PanelBattery.buildPanelBatteries(makeMissileSystemConfigMap(), deployedGroundState(),
        "Taiwan", 0)

      assert.are.same({ VERTICES["rp-2"] }, batteries[1].placement.tacticalAreas.HA[1])
    end)

    -- Positive: the launcher, its paired transloader and canister stock in one status
    it("should carry a deployed battery's status", function()
      local groundState = deployedGroundState({ state = constants.MISSILE_UNIT_POSTURE.RELOAD, reloadStartTime = 1000 })

      assert.are.same({
        launcherPosture = "RELOAD",
        transloaderPosture = "STATIC",
        transloaderMissiles = 4,
        transloaderMissilesDefault = 8,
        canisterMissiles = 12,
        canisterMissilesDefault = 24,
        launcherReloadMinutes = 2,
        transloaderReloadMinutes = 0,
        reloadMinutesDefault = 1
      }, statusAt(groundState, 1120))
    end)

    -- Positive: default counts come from config, so a config change reaches an old save
    it("should report the config default ammo counts of the transloader and its canister stock", function()
      local configMap = makeMissileSystemConfigMap()
      configMap.srbm.transloaders["RS-1"].weaponCountDefault = 10
      configMap.srbm.canisterStocks["ATP-1"].weaponCountDefault = 30

      local status = statusAt(deployedGroundState(nil, { weaponCountDefault = 8 }), 0, configMap)

      assert.are.equal(10, status.transloaderMissilesDefault)
      assert.are.equal(30, status.canisterMissilesDefault)
    end)

    -- Negative: a system with saved state but no state for this launcher has not deployed it yet
    it("should leave out the status when the launcher has no saved state", function()
      local groundState = deployedGroundState()
      groundState.missileSystemTypes.srbm.launchers = {}

      assert.is_nil(statusAt(groundState, 0))
    end)

    -- Positive: every known posture has its own label
    it("should label every known posture", function()
      local labels = {
        [constants.MISSILE_UNIT_POSTURE.STATIC] = "STATIC",
        [constants.MISSILE_UNIT_POSTURE.REPOSITIONING] = "REPOSITIONING",
        [constants.MISSILE_UNIT_POSTURE.HIDE] = "HIDE",
        [constants.MISSILE_UNIT_POSTURE.RELOAD] = "RELOAD",
      }

      for state, label in pairs(labels) do
        local status = statusAt(deployedGroundState({ state = state }, { state = state }), 0)
        assert.are.equal(label, status.launcherPosture)
        assert.are.equal(label, status.transloaderPosture)
      end
    end)

    -- Negative: an unexpected posture still renders
    it("should label an unknown posture as UNKNOWN", function()
      assert.are.equal("UNKNOWN", statusAt(deployedGroundState({ state = -99 }), 0).launcherPosture)
    end)

    -- Boundary: 40 s is 0.666... minutes, which must round up rather than truncate
    it("should round elapsed reload minutes to 2 decimals", function()
      assert.are.equal(0.67, statusAt(deployedGroundState({ reloadStartTime = 1000 }), 1040).launcherReloadMinutes)
    end)

    -- Boundary: a start time after now must not show a negative countdown
    it("should clamp a reload that starts in the future to 0", function()
      local status = statusAt(deployedGroundState({ reloadStartTime = 2000 }, { reloadStartTime = 3000 }), 1000)

      assert.are.equal(0, status.launcherReloadMinutes)
      assert.are.equal(0, status.transloaderReloadMinutes)
    end)

    -- Negative: the config and saved state must survive for the next redeploy
    it("should leave the config and saved state untouched", function()
      local missileSystemConfigMap = makeMissileSystemConfigMap()
      local groundState = deployedGroundState()

      PanelBattery.buildPanelBatteries(missileSystemConfigMap, groundState, "Taiwan", 0)

      assert.are.same(makeMissileSystemConfigMap(), missileSystemConfigMap)
      assert.are.same(deployedGroundState(), groundState)
    end)
  end)
end)
