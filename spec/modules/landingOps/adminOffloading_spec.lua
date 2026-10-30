---@diagnostic disable: need-check-nil, assign-type-mismatch, cast-local-type, param-type-mismatch, inject-field
-- LandingOps AdminOffloading Unit Tests
local AdminOffloading = require("src.modules.landingOps.adminOffloading")
local GameApi = require("src.utils.gameApi")
local Logger = require("src.utils.logger")
local StubTracker = require("spec.support.stubTracker")

describe("AdminOffloading", function()
  ---@type luassert.spy
  local logStub
  ---@type luassert.spy
  local errorStub
  local trackStub = StubTracker.track

  before_each(function()
    logStub = trackStub(stub(Logger, "log"))
    trackStub(stub(Logger, "warn"))
    errorStub = trackStub(stub(Logger, "error"))
  end)

  after_each(function()
    StubTracker.revertAll()
  end)

  ---Create an operational zone descriptor
  ---@param overrides? table
  ---@return table
  local function buildZone(overrides)
    local zone = {
      name = "ZoneAlpha",
      heading = 270,
      movement = {
        holdingAreas = {
          deployLine = { "RP-LST-1", "RP-LST-2" },
        },
      },
      landing = {
        offloadArea = { "RP-OFF-1", "RP-OFF-2", "RP-OFF-3", "RP-OFF-4" },
        lstSettings = {
          speed = 10,
          distance = 5,
        },
        acv = {
          area = { "RP-ACV-1", "RP-ACV-2" },
          destination = { { latitude = 25.0, longitude = 121.0 } },
        },
      },
    }
    if overrides then
      for k, v in pairs(overrides) do
        if type(zone[k]) == "table" and (k == "movement" or k == "air" or k == "landing" or k == "fleet") then
          for groupKey, groupValue in pairs(v) do zone[k][groupKey] = groupValue end
        else
          zone[k] = v
        end
      end
    end
    return zone
  end

  ---Create an amphibOpsConfig
  ---@param overrides? table
  ---@return table
  local function buildAmphibOpsConfig(overrides)
    local config = {
      zones = { buildZone() },
      adminOffloading = { roroBatchSize = 20, bargeRoroPairingRangeNm = 1 },
      formation = { acvSpacingNm = 0.5 },
    }
    if overrides then
      for k, v in pairs(overrides) do config[k] = v end
    end
    return config
  end

  ---Create a ship unit with sensible defaults
  ---@param overrides? table
  ---@return table
  local function buildUnit(overrides)
    local unit = {
      guid = "SHIP-001",
      name = "TestShip",
      type = "Ship",
      latitude = 25.0,
      longitude = 121.0,
      course = {},
      manualSpeed = 0,
      IsDestroyed = false,
      inArea = function() return false end,
      cargo = {
        [1] = {
          cargo = {},
        },
      },
      deleteUnitCargo = function() return true end,
    }
    if overrides then
      for k, v in pairs(overrides) do unit[k] = v end
    end
    return unit
  end

  ---Create a cargo item for offloading
  ---@param overrides? table
  ---@return table
  local function buildCargoItem(overrides)
    local item = {
      guid = "CARGO-001",
      dbid = 3001,
      name = "Vehicle-1",
      Type = 1,
    }
    if overrides then
      for k, v in pairs(overrides) do item[k] = v end
    end
    return item
  end

  ---Create a side unit entry (as returned in filteredUnits)
  ---@param overrides? table
  ---@return table
  local function buildSideUnit(overrides)
    local su = {
      guid = "SHIP-001",
    }
    if overrides then
      for k, v in pairs(overrides) do su[k] = v end
    end
    return su
  end

  ---Create vehicle offload params
  ---@param overrides? table
  ---@return table
  local function buildOffloadParams(overrides)
    local params = {
      ship = buildUnit({
        cargo = {
          [1] = {
            cargo = {
              buildCargoItem({ guid = "C-1", name = "Vehicle-1" }),
              buildCargoItem({ guid = "C-2", name = "Vehicle-2" }),
              buildCargoItem({ guid = "C-3", name = "Vehicle-3" }),
            },
          },
        },
      }),
      num = 2,
      bearing = 90,
      distance = 0.5,
      firstDistance = 0.3,
    }
    if overrides then
      for k, v in pairs(overrides) do params[k] = v end
    end
    return params
  end

  describe("startAdminOffloading", function()
    local stubGetUnit, stubGetRefPoints, stubToolRange, stubToolBearing
    local stubGetPointFromBearing

    before_each(function()
      stubGetUnit = trackStub(stub(GameApi, "ScenEdit_GetUnit"))
      stubGetRefPoints = trackStub(stub(GameApi, "ScenEdit_GetReferencePoints"))
      stubToolRange = trackStub(stub(GameApi, "Tool_Range"))
      stubToolBearing = trackStub(stub(GameApi, "Tool_Bearing"))
      stubGetPointFromBearing = trackStub(stub(GameApi, "World_GetPointFromBearing"))
    end)

    it("should set barge course and speed toward offload area", function()
      local zone = buildZone()
      local barges = {}

      local bargeUnit = buildUnit({
        guid = "BARGE-001",
        name = "Barge",
        type = "Ship",
        latitude = 24.5,
        longitude = 120.5,
        inArea = function(_, area) return area == zone.movement.holdingAreas.deployLine end,
      })

      stubGetUnit.invokes(function(guid)
        if guid == "BARGE-001" then return bargeUnit end
        return nil
      end)

      stubGetRefPoints.returns({
        { latitude = 25.1, longitude = 121.1 },
        { latitude = 25.1, longitude = 120.9 },
        { latitude = 24.9, longitude = 120.9 },
        { latitude = 24.9, longitude = 121.1 },
      })
      stubToolRange.returns(5.0)
      stubToolBearing.returns(300)
      local destination = { latitude = 24.8, longitude = 120.8 }
      stubGetPointFromBearing.returns(destination)

      local filteredUnits = { buildSideUnit({ guid = "BARGE-001" }) }
      local result = AdminOffloading.startAdminOffloading(zone, barges, filteredUnits)

      assert.is_true(result)
      assert.are.same({ destination }, bargeUnit.course)
      assert.are.equal(zone.landing.lstSettings.speed, bargeUnit.manualSpeed)
      assert.stub(logStub).was.called(1)
    end)

    it("should register barge in the barge registry with empty roros array", function()
      local zone = buildZone()
      local barges = {}

      local bargeUnit = buildUnit({
        guid = "BARGE-001",
        name = "Barge",
        type = "Ship",
        latitude = 24.5,
        longitude = 120.5,
        inArea = function(_, area) return area == zone.movement.holdingAreas.deployLine end,
      })

      stubGetUnit.returns(bargeUnit)
      stubGetRefPoints.returns({
        { latitude = 25.1, longitude = 121.1 },
        { latitude = 25.1, longitude = 120.9 },
        { latitude = 24.9, longitude = 120.9 },
        { latitude = 24.9, longitude = 121.1 },
      })
      stubToolRange.returns(5.0)
      stubToolBearing.returns(300)
      stubGetPointFromBearing.returns({ latitude = 24.8, longitude = 120.8 })

      AdminOffloading.startAdminOffloading(
        zone, barges, { buildSideUnit({ guid = "BARGE-001" }) }
      )

      assert.is_not_nil(barges["BARGE-001"])
      assert.are.equal("BARGE-001", barges["BARGE-001"].guid)
      assert.are.same({}, barges["BARGE-001"].roros)
      assert.stub(logStub).was.called(1)
    end)

    it("should pair RORO with barge and set RORO course", function()
      local zone = buildZone()
      local barges = {}

      local bargeUnit = buildUnit({
        guid = "BARGE-001",
        name = "Barge",
        type = "Ship",
        latitude = 24.5,
        longitude = 120.5,
        inArea = function(_, area) return area == zone.movement.holdingAreas.deployLine end,
      })

      local roroUnit = buildUnit({
        guid = "RORO-001",
        name = "RORO",
        type = "Ship",
        latitude = 24.6,
        longitude = 120.6,
        inArea = function(_, area) return area == zone.movement.holdingAreas.deployLine end,
      })

      stubGetUnit.invokes(function(guid)
        if guid == "BARGE-001" then return bargeUnit end
        if guid == "RORO-001" then return roroUnit end
        return nil
      end)

      local bargeDest = { latitude = 24.8, longitude = 120.8 }
      local roroDest = { latitude = 24.7, longitude = 120.7 }

      stubGetRefPoints.returns({
        { latitude = 25.1, longitude = 121.1 },
        { latitude = 25.1, longitude = 120.9 },
        { latitude = 24.9, longitude = 120.9 },
        { latitude = 24.9, longitude = 121.1 },
      })
      stubToolRange.returns(5.0)
      stubToolBearing.returns(300)

      -- First call for barge, second call for RORO
      stubGetPointFromBearing.invokes(function(params)
        if params.latitude == bargeUnit.latitude then
          return bargeDest
        end
        if params.latitude == roroUnit.latitude then
          return roroDest
        end
        return nil
      end)

      local filteredUnits = {
        buildSideUnit({ guid = "BARGE-001" }),
        buildSideUnit({ guid = "RORO-001" }),
      }

      AdminOffloading.startAdminOffloading(zone, barges, filteredUnits)

      -- RORO should be registered under the barge's roros list
      assert.are.same({ "RORO-001" }, barges["BARGE-001"].roros)
      -- RORO course: first waypoint is approach, second is barge destination
      assert.are.same({ roroDest, bargeDest }, roroUnit.course)
      assert.are.equal(zone.landing.lstSettings.speed, roroUnit.manualSpeed)
      assert.stub(logStub).was.called(1)
    end)

    it("should skip units when ScenEdit_GetUnit returns nil", function()
      local zone = buildZone()
      local barges = {}

      stubGetUnit.returns(nil)

      local filteredUnits = { buildSideUnit({ guid = "MISSING-001" }) }
      local result = AdminOffloading.startAdminOffloading(zone, barges, filteredUnits)

      assert.is_true(result)
      assert.are.same({}, barges)
      assert.stub(logStub).was_not.called()
    end)

    it("should skip barge when offload area reference points return nil", function()
      local zone = buildZone()
      local barges = {}

      local bargeUnit = buildUnit({
        guid = "BARGE-001",
        name = "Barge",
        type = "Ship",
        inArea = function(_, area) return area == zone.movement.holdingAreas.deployLine end,
      })

      stubGetUnit.returns(bargeUnit)
      stubGetRefPoints.returns(nil)

      local result = AdminOffloading.startAdminOffloading(
        zone, barges, { buildSideUnit({ guid = "BARGE-001" }) }
      )

      assert.is_true(result)
      assert.are.same({}, barges)
      assert.stub(logStub).was.called(1)
    end)

    it("should skip barge when center point calculation returns nil", function()
      local zone = buildZone()
      local barges = {}

      local bargeUnit = buildUnit({
        guid = "BARGE-001",
        name = "Barge",
        type = "Ship",
        inArea = function(_, area) return area == zone.movement.holdingAreas.deployLine end,
      })

      stubGetUnit.returns(bargeUnit)
      stubGetRefPoints.returns({
        { latitude = 25.1, longitude = 121.1 },
        { latitude = 25.1, longitude = 120.9 },
        { latitude = 24.9, longitude = 120.9 },
        { latitude = 24.9, longitude = 121.1 },
      })
      stubGetRefPoints.returns({})

      AdminOffloading.startAdminOffloading(
        zone, barges, { buildSideUnit({ guid = "BARGE-001" }) }
      )

      assert.are.same({}, barges)
      assert.stub(logStub).was.called(1)
    end)

    it("should skip barge when Tool_Range returns nil", function()
      local zone = buildZone()
      local barges = {}

      local bargeUnit = buildUnit({
        guid = "BARGE-001",
        name = "Barge",
        type = "Ship",
        inArea = function(_, area) return area == zone.movement.holdingAreas.deployLine end,
      })

      stubGetUnit.returns(bargeUnit)
      stubGetRefPoints.returns({
        { latitude = 25.1, longitude = 121.1 },
        { latitude = 25.1, longitude = 120.9 },
        { latitude = 24.9, longitude = 120.9 },
        { latitude = 24.9, longitude = 121.1 },
      })
      stubToolRange.returns(nil)

      AdminOffloading.startAdminOffloading(
        zone, barges, { buildSideUnit({ guid = "BARGE-001" }) }
      )

      assert.are.same({}, barges)
      assert.stub(logStub).was.called(1)
    end)

    it("should skip barge when Tool_Bearing returns nil", function()
      local zone = buildZone()
      local barges = {}

      local bargeUnit = buildUnit({
        guid = "BARGE-001",
        name = "Barge",
        type = "Ship",
        inArea = function(_, area) return area == zone.movement.holdingAreas.deployLine end,
      })

      stubGetUnit.returns(bargeUnit)
      stubGetRefPoints.returns({
        { latitude = 25.1, longitude = 121.1 },
        { latitude = 25.1, longitude = 120.9 },
        { latitude = 24.9, longitude = 120.9 },
        { latitude = 24.9, longitude = 121.1 },
      })
      stubToolRange.returns(5.0)
      stubToolBearing.returns(nil)

      AdminOffloading.startAdminOffloading(
        zone, barges, { buildSideUnit({ guid = "BARGE-001" }) }
      )

      assert.are.same({}, barges)
      assert.stub(logStub).was.called(1)
    end)

    it("should skip barge when destination calculation returns nil", function()
      local zone = buildZone()
      local barges = {}

      local bargeUnit = buildUnit({
        guid = "BARGE-001",
        name = "Barge",
        type = "Ship",
        inArea = function(_, area) return area == zone.movement.holdingAreas.deployLine end,
      })

      stubGetUnit.returns(bargeUnit)
      stubGetRefPoints.returns({
        { latitude = 25.1, longitude = 121.1 },
        { latitude = 25.1, longitude = 120.9 },
        { latitude = 24.9, longitude = 120.9 },
        { latitude = 24.9, longitude = 121.1 },
      })
      stubToolRange.returns(5.0)
      stubToolBearing.returns(300)
      stubGetPointFromBearing.returns(nil)

      AdminOffloading.startAdminOffloading(
        zone, barges, { buildSideUnit({ guid = "BARGE-001" }) }
      )

      assert.are.same({}, barges)
      assert.stub(logStub).was.called(1)
    end)

    it("should not set RORO course when World_GetPointFromBearing fails for RORO", function()
      local zone = buildZone()
      local barges = {}

      local bargeUnit = buildUnit({
        guid = "BARGE-001",
        name = "Barge",
        type = "Ship",
        latitude = 24.5,
        longitude = 120.5,
        inArea = function(_, area) return area == zone.movement.holdingAreas.deployLine end,
      })

      local roroUnit = buildUnit({
        guid = "RORO-001",
        name = "RORO",
        type = "Ship",
        latitude = 24.6,
        longitude = 120.6,
        inArea = function(_, area) return area == zone.movement.holdingAreas.deployLine end,
      })

      stubGetUnit.invokes(function(guid)
        if guid == "BARGE-001" then return bargeUnit end
        if guid == "RORO-001" then return roroUnit end
        return nil
      end)

      local bargeDest = { latitude = 24.8, longitude = 120.8 }
      stubGetRefPoints.returns({
        { latitude = 25.1, longitude = 121.1 },
        { latitude = 25.1, longitude = 120.9 },
        { latitude = 24.9, longitude = 120.9 },
        { latitude = 24.9, longitude = 121.1 },
      })
      stubToolRange.returns(5.0)
      stubToolBearing.returns(300)

      -- Barge gets valid destination, RORO gets nil
      stubGetPointFromBearing.invokes(function(params)
        if params.latitude == bargeUnit.latitude then
          return bargeDest
        end
        return nil
      end)

      AdminOffloading.startAdminOffloading(
        zone, barges,
        { buildSideUnit({ guid = "BARGE-001" }), buildSideUnit({ guid = "RORO-001" }) }
      )

      -- RORO still registered under barge, but course not updated
      assert.are.same({ "RORO-001" }, barges["BARGE-001"].roros)
      assert.are.same({}, roroUnit.course)
      assert.are.equal(0, roroUnit.manualSpeed)
      assert.stub(logStub).was.called(1)
    end)

    it("should ignore units that are not Barge or RORO", function()
      local zone = buildZone()
      local barges = {}

      local otherUnit = buildUnit({
        guid = "LST-001",
        name = "LST",
        type = "Ship",
        inArea = function(_, area) return area == zone.movement.holdingAreas.deployLine end,
      })

      stubGetUnit.returns(otherUnit)

      AdminOffloading.startAdminOffloading(
        zone, barges, { buildSideUnit({ guid = "LST-001" }) }
      )

      assert.are.same({}, barges)
      assert.stub(logStub).was_not.called()
    end)

    it("should ignore barge that is not in holdingAreas.deployLine", function()
      local zone = buildZone()
      local barges = {}

      local bargeUnit = buildUnit({
        guid = "BARGE-001",
        name = "Barge",
        type = "Ship",
        inArea = function() return false end,
      })

      stubGetUnit.returns(bargeUnit)

      AdminOffloading.startAdminOffloading(
        zone, barges, { buildSideUnit({ guid = "BARGE-001" }) }
      )

      assert.are.same({}, barges)
      assert.stub(logStub).was_not.called()
    end)

    it("should return true when filteredUnits is empty", function()
      local zone = buildZone()
      local barges = {}

      local result = AdminOffloading.startAdminOffloading(zone, barges, {})

      assert.is_true(result)
      assert.are.same({}, barges)
      assert.stub(logStub).was_not.called()
    end)

    -- Caller invokes once per zone; each call processes its own barges
    it("should process barges for each zone when called separately per zone", function()
      local zone1 = buildZone({ name = "Zone1", movement = { holdingAreas = { deployLine = { "AREA-Z1" } } } })
      local zone2 = buildZone({ name = "Zone2", movement = { holdingAreas = { deployLine = { "AREA-Z2" } } } })
      local barges = {}

      local barge1 = buildUnit({
        guid = "BARGE-Z1",
        name = "Barge",
        type = "Ship",
        latitude = 24.5,
        longitude = 120.5,
        inArea = function(_, area) return area == zone1.movement.holdingAreas.deployLine end,
      })

      local barge2 = buildUnit({
        guid = "BARGE-Z2",
        name = "Barge",
        type = "Ship",
        latitude = 23.5,
        longitude = 119.5,
        inArea = function(_, area) return area == zone2.movement.holdingAreas.deployLine end,
      })

      stubGetUnit.invokes(function(guid)
        if guid == "BARGE-Z1" then return barge1 end
        if guid == "BARGE-Z2" then return barge2 end
        return nil
      end)

      stubGetRefPoints.returns({
        { latitude = 25.1, longitude = 121.1 },
        { latitude = 25.1, longitude = 120.9 },
        { latitude = 24.9, longitude = 120.9 },
        { latitude = 24.9, longitude = 121.1 },
      })
      stubToolRange.returns(5.0)
      stubToolBearing.returns(300)
      stubGetPointFromBearing.returns({ latitude = 24.8, longitude = 120.8 })

      local allUnits = {
        buildSideUnit({ guid = "BARGE-Z1" }),
        buildSideUnit({ guid = "BARGE-Z2" }),
      }

      AdminOffloading.startAdminOffloading(zone1, barges, allUnits)
      AdminOffloading.startAdminOffloading(zone2, barges, allUnits)

      assert.is_not_nil(barges["BARGE-Z1"])
      assert.is_not_nil(barges["BARGE-Z2"])
      assert.stub(logStub).was.called(2)
    end)
  end)

  describe("handleShipArrival", function()
    it("should stop the barge and extend a bridge when no bridge exists", function()
      local barge = buildUnit({ guid = "BARGE-001", name = "Barge", course = { { latitude = 25.1, longitude = 121.1 } } })
      local barges = { [barge.guid] = { guid = barge.guid, roros = {} } }
      local stubAddUnit = trackStub(stub(GameApi, "ScenEdit_AddUnit").returns({ guid = "BRIDGE-001" }))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns({ guid = "BRIDGE-001" }))

      local result = AdminOffloading.handleShipArrival(buildAmphibOpsConfig(), barges, barge)

      assert.is_true(result)
      assert.is_nil(barge.course)
      assert.are.equal(0, barge.manualSpeed)
      assert.is_true(barge.holdposition)
      assert.are.equal("BRIDGE-001", barges[barge.guid].bridgeGUID)
      assert.stub(stubAddUnit).was.called(1)
    end)

    it("should return false and create no bridge for a barge missing from the registry", function()
      local barge = buildUnit({ guid = "BARGE-UNKNOWN", name = "Barge" })
      local stubAddUnit = trackStub(stub(GameApi, "ScenEdit_AddUnit").returns({ guid = "BRIDGE-001" }))

      local result = AdminOffloading.handleShipArrival(buildAmphibOpsConfig(), {}, barge)

      assert.is_false(result)
      assert.stub(stubAddUnit).was_not.called()
    end)

    it("should return false when the bridge cannot be created", function()
      local barge = buildUnit({ guid = "BARGE-001", name = "Barge" })
      local barges = { [barge.guid] = { guid = barge.guid, roros = {} } }
      trackStub(stub(GameApi, "ScenEdit_AddUnit").returns(nil))

      local result = AdminOffloading.handleShipArrival(buildAmphibOpsConfig(), barges, barge)

      assert.is_false(result)
      assert.is_nil(barges[barge.guid].bridgeGUID)
    end)

    it("should not create a second bridge when the barge already has one", function()
      local barge = buildUnit({ guid = "BARGE-001", name = "Barge" })
      local barges = { [barge.guid] = { guid = barge.guid, bridgeGUID = "BRIDGE-001", roros = {} } }
      local stubAddUnit = trackStub(stub(GameApi, "ScenEdit_AddUnit"))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns({ guid = "BRIDGE-001" }))

      local result = AdminOffloading.handleShipArrival(buildAmphibOpsConfig(), barges, barge)

      assert.is_true(result)
      assert.stub(stubAddUnit).was_not.called()
    end)

    it("should stop a RORO ship in place", function()
      local roro = buildUnit({ name = "RORO", course = { { latitude = 25.1, longitude = 121.1 } }, manualSpeed = 12 })

      local result = AdminOffloading.handleShipArrival(buildAmphibOpsConfig(), {}, roro)

      assert.is_true(result)
      assert.is_nil(roro.course)
      assert.are.equal(0, roro.manualSpeed)
      assert.is_true(roro.holdposition)
    end)

    describe("with a paired RORO", function()
      local zone, config, barge, roro, barges
      local stubGetPoint, stubAddUnit, stubToolRange, roroLookup, bridgeLookup

      ---Put the barge and RORO inside the zone's ACV area
      local function placeInAcvArea()
        local inAcv = function(_, area) return area == zone.landing.acv.area end
        barge.inArea = inAcv
        roro.inArea = inAcv
      end

      ---Make successive placement requests resolve to the given locations
      ---@param locations table[]
      local function placeAt(locations)
        local calls = 0
        stubGetPoint.invokes(function()
          calls = calls + 1
          return locations[calls]
        end)
      end

      before_each(function()
        zone = buildZone()
        config = buildAmphibOpsConfig({ zones = { zone }, adminOffloading = { roroBatchSize = 2, bargeRoroPairingRangeNm = 1 } })
        barge = buildUnit({ guid = "BARGE-001", name = "Barge" })
        roro = buildUnit({
          guid = "RORO-001",
          name = "RORO",
          cargo = {
            [1] = {
              cargo = {
                buildCargoItem({ guid = "C-1", name = "Vehicle-1" }),
                buildCargoItem({ guid = "C-2", name = "Vehicle-2" }),
                buildCargoItem({ guid = "C-3", name = "Vehicle-3" }),
              },
            },
          },
        })
        barges = { [barge.guid] = { guid = barge.guid, bridgeGUID = "BRIDGE-001", roros = { roro.guid } } }
        placeInAcvArea()

        roroLookup = roro
        bridgeLookup = { guid = "BRIDGE-001" }
        trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
          if guid == "BRIDGE-001" then return bridgeLookup end
          if guid == "RORO-001" then return roroLookup end
        end))
        stubToolRange = trackStub(stub(GameApi, "Tool_Range").returns(0.5))
        stubGetPoint = trackStub(stub(GameApi, "World_GetPointFromBearing"))
        stubAddUnit = trackStub(stub(GameApi, "ScenEdit_AddUnit").returns({ guid = "CREATED-001" }))
        trackStub(stub(roro, "deleteUnitCargo"))
        placeAt({
          { latitude = 25.1, longitude = 121.1 },
          { latitude = 25.2, longitude = 121.2 },
        })
      end)

      it("should offload one batch of vehicles from the RORO", function()
        local result = AdminOffloading.handleShipArrival(config, barges, barge)

        assert.is_true(result)
        assert.stub(roro.deleteUnitCargo).was.called(2)
        assert.stub(stubAddUnit).was.called(2)
        assert.stub(logStub).was.called(1)
      end)

      it("should create a Ground unit when the cargo item type is 2", function()
        roro.cargo[1].cargo = { buildCargoItem({ guid = "C-1", name = "GroundUnit-1", Type = 2 }) }

        AdminOffloading.handleShipArrival(config, barges, barge)

        assert.stub(stubAddUnit).was.called_with({
          side = "China",
          type = "Ground unit",
          latitude = 25.1,
          longitude = 121.1,
          dbid = 3001,
          unitname = "GroundUnit-1",
        })
      end)

      it("should create a Facility when the cargo item type is not 2", function()
        roro.cargo[1].cargo = { buildCargoItem({ guid = "C-1", name = "Facility-1", Type = 1 }) }

        AdminOffloading.handleShipArrival(config, barges, barge)

        assert.stub(stubAddUnit).was.called_with({
          side = "China",
          type = "Facility",
          latitude = 25.1,
          longitude = 121.1,
          dbid = 3001,
          unitname = "Facility-1",
        })
      end)

      it("should place vehicles along the zone heading starting 1 nm from the RORO", function()
        AdminOffloading.handleShipArrival(config, barges, barge)

        assert.are.same({
          latitude = roro.latitude,
          longitude = roro.longitude,
          bearing = zone.heading,
          distance = 1,
        }, stubGetPoint.calls[1].vals[1])
        assert.are.same({
          latitude = 25.1,
          longitude = 121.1,
          bearing = zone.heading,
          distance = config.formation.acvSpacingNm,
        }, stubGetPoint.calls[2].vals[1])
      end)

      it("should offload no more than the batch size", function()
        config.adminOffloading.roroBatchSize = 1

        AdminOffloading.handleShipArrival(config, barges, barge)

        assert.stub(stubAddUnit).was.called(1)
      end)

      it("should log the failure and still handle the arrival when unit creation fails", function()
        stubAddUnit.invokes(function(unitParams)
          if unitParams.unitname == "Vehicle-1" then
            return { guid = "CREATED-001" }
          end
          return nil
        end)

        local result = AdminOffloading.handleShipArrival(config, barges, barge)

        assert.is_true(result)
        assert.stub(logStub).was.called(1)
        assert.stub(errorStub).was.called(1)
        assert.truthy(string.find(errorStub.calls[1].vals[1], "reason=add_unit_failed"))
      end)

      it("should offload nothing when the RORO is missing", function()
        roroLookup = nil

        AdminOffloading.handleShipArrival(config, barges, barge)

        assert.stub(stubAddUnit).was_not.called()
        assert.stub(logStub).was_not.called()
      end)

      it("should offload nothing when the RORO is destroyed", function()
        roro.IsDestroyed = true

        AdminOffloading.handleShipArrival(config, barges, barge)

        assert.stub(stubGetPoint).was_not.called()
        assert.stub(logStub).was_not.called()
      end)

      it("should offload nothing when the barge bridge is destroyed", function()
        bridgeLookup = nil

        local result = AdminOffloading.handleShipArrival(config, barges, barge)

        assert.is_true(result)
        assert.stub(stubAddUnit).was_not.called()
      end)

      it("should offload nothing when the units are as far apart as the pairing range", function()
        stubToolRange.returns(config.adminOffloading.bargeRoroPairingRangeNm)

        AdminOffloading.handleShipArrival(config, barges, barge)

        assert.stub(stubAddUnit).was_not.called()
      end)

      it("should offload nothing when the range is unknown", function()
        stubToolRange.returns(nil)

        AdminOffloading.handleShipArrival(config, barges, barge)

        assert.stub(stubAddUnit).was_not.called()
      end)

      it("should offload nothing when the RORO is not in the ACV area", function()
        roro.inArea = function() return false end

        AdminOffloading.handleShipArrival(config, barges, barge)

        assert.stub(stubAddUnit).was_not.called()
      end)

      it("should offload nothing when the barge is not in the ACV area", function()
        barge.inArea = function() return false end

        AdminOffloading.handleShipArrival(config, barges, barge)

        assert.stub(stubAddUnit).was_not.called()
      end)

      it("should use the first zone whose ACV area holds both units", function()
        local zone1 = buildZone({ name = "Zone1", heading = 90, landing = { acv = { area = { "AREA-1" } } } })
        local zone2 = buildZone({ name = "Zone2", heading = 180, landing = { acv = { area = { "AREA-2" } } } })
        config.zones = { zone1, zone2 }
        local inZone2 = function(_, area) return area == zone2.landing.acv.area end
        barge.inArea = inZone2
        roro.inArea = inZone2

        AdminOffloading.handleShipArrival(config, barges, barge)

        assert.are.equal(180, stubGetPoint.calls[1].vals[1].bearing)
      end)

      it("should offload nothing when there are no zones", function()
        config.zones = {}

        AdminOffloading.handleShipArrival(config, barges, barge)

        assert.stub(stubAddUnit).was_not.called()
      end)
    end)
  end)
end)
