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
          distance = 0.5,
          speed = 20,
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
      bargeRoroPairingRangeNm = 1,
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

  describe("offloadVehicles", function()
    local stubGetPoint, stubAddUnit

    before_each(function()
      stubGetPoint = trackStub(stub(GameApi, "World_GetPointFromBearing"))
      stubAddUnit = trackStub(stub(GameApi, "ScenEdit_AddUnit"))
    end)

    ---Make successive placement requests resolve to the given locations
    ---@param locations table[]
    local function placeAt(locations)
      local calls = 0
      stubGetPoint.invokes(function()
        calls = calls + 1
        return locations[calls]
      end)
    end

    it("should offload vehicles and return count of successfully created units", function()
      local params = buildOffloadParams()
      local deleteStub = trackStub(stub(params.ship, "deleteUnitCargo"))

      placeAt({
        { latitude = 25.1, longitude = 121.1 },
        { latitude = 25.2, longitude = 121.2 },
      })
      stubAddUnit.returns({ guid = "CREATED-001" })

      local result = AdminOffloading.offloadVehicles(params)

      assert.are.equal(2, result)
      assert.stub(deleteStub).was.called(2)
      assert.stub(stubAddUnit).was.called(2)
      assert.stub(logStub).was.called(1)
    end)

    it("should create Ground unit when cargo item type is 2", function()
      local params = buildOffloadParams({
        num = 1,
        ship = buildUnit({
          cargo = {
            [1] = {
              cargo = {
                buildCargoItem({ guid = "C-1", name = "GroundUnit-1", Type = 2 }),
              },
            },
          },
        }),
      })
      trackStub(stub(params.ship, "deleteUnitCargo"))

      placeAt({ { latitude = 25.1, longitude = 121.1 }, })
      stubAddUnit.returns({ guid = "CREATED-001" })

      AdminOffloading.offloadVehicles(params)

      assert.stub(stubAddUnit).was.called_with({
        side = "China",
        type = "Ground unit",
        latitude = 25.1,
        longitude = 121.1,
        dbid = 3001,
        unitname = "GroundUnit-1",
      })
      assert.stub(logStub).was.called(1)
    end)

    it("should create Facility when cargo item type is not 2", function()
      local params = buildOffloadParams({
        num = 1,
        ship = buildUnit({
          cargo = {
            [1] = {
              cargo = {
                buildCargoItem({ guid = "C-1", name = "Facility-1", Type = 1 }),
              },
            },
          },
        }),
      })
      trackStub(stub(params.ship, "deleteUnitCargo"))

      placeAt({
        { latitude = 25.1, longitude = 121.1 },
      })
      stubAddUnit.returns({ guid = "CREATED-001" })

      AdminOffloading.offloadVehicles(params)

      assert.stub(stubAddUnit).was.called_with({
        side = "China",
        type = "Facility",
        latitude = 25.1,
        longitude = 121.1,
        dbid = 3001,
        unitname = "Facility-1",
      })
      assert.stub(logStub).was.called(1)
    end)

    it("should place vehicles along the bearing starting at the first distance from the ship", function()
      local params = buildOffloadParams()
      trackStub(stub(params.ship, "deleteUnitCargo"))

      placeAt({
        { latitude = 25.1, longitude = 121.1 },
        { latitude = 25.2, longitude = 121.2 },
      })
      stubAddUnit.returns({ guid = "CREATED-001" })

      AdminOffloading.offloadVehicles(params)

      assert.are.same({
        latitude = params.ship.latitude,
        longitude = params.ship.longitude,
        bearing = 90,
        distance = 0.3,
      }, stubGetPoint.calls[1].vals[1])
      assert.are.same({
        latitude = 25.1,
        longitude = 121.1,
        bearing = 90,
        distance = 0.5,
      }, stubGetPoint.calls[2].vals[1])
      assert.stub(logStub).was.called(1)
    end)

    it("should return nil when ship is nil", function()
      local params = buildOffloadParams()
      params.ship = nil

      local result = AdminOffloading.offloadVehicles(params)

      assert.is_nil(result)
      assert.stub(stubGetPoint).was_not.called()
      assert.stub(logStub).was_not.called()
    end)

    it("should return nil when ship is destroyed", function()
      local params = buildOffloadParams()
      params.ship.IsDestroyed = true

      local result = AdminOffloading.offloadVehicles(params)

      assert.is_nil(result)
      assert.stub(stubGetPoint).was_not.called()
      assert.stub(logStub).was_not.called()
    end)

    it("should return nil when unit creation fails", function()
      local params = buildOffloadParams()
      trackStub(stub(params.ship, "deleteUnitCargo"))

      placeAt({
        { latitude = 25.1, longitude = 121.1 },
        { latitude = 25.2, longitude = 121.2 },
      })
      stubAddUnit.invokes(function(unitParams)
        if unitParams.unitname == "Vehicle-1" then
          return { guid = "CREATED-001" }
        end
        return nil
      end)

      local result = AdminOffloading.offloadVehicles(params)

      assert.is_nil(result)
      assert.stub(logStub).was.called(1)
      assert.stub(errorStub).was.called(1)
      assert.truthy(string.find(errorStub.calls[1].vals[1], "reason=add_unit_failed"))
    end)

    it("should only offload up to params.num items from cargo", function()
      local params = buildOffloadParams({ num = 1 })
      trackStub(stub(params.ship, "deleteUnitCargo"))

      placeAt({
        { latitude = 25.1, longitude = 121.1 },
      })
      stubAddUnit.returns({ guid = "CREATED-001" })

      local result = AdminOffloading.offloadVehicles(params)

      assert.are.equal(1, result)
      assert.stub(stubAddUnit).was.called(1)
      assert.stub(logStub).was.called(1)
    end)
  end)

  describe("isBridgeDestroyed", function()
    local stubGetUnit

    before_each(function()
      stubGetUnit = trackStub(stub(GameApi, "ScenEdit_GetUnit"))
    end)

    it("should return true when bridge exists in the barge registry but unit cannot be found", function()
      local barges = {
        ["BARGE-001"] = {
          guid = "BARGE-001",
          bridgeGUID = "BRIDGE-001",
          roros = {},
        },
      }
      local ship = buildUnit({ guid = "BARGE-001" })

      stubGetUnit.returns(nil)

      local result = AdminOffloading.isBridgeDestroyed(barges, ship)

      assert.is_true(result)
      assert.stub(logStub).was_not.called()
    end)

    it("should return false when bridge unit still exists", function()
      local barges = {
        ["BARGE-001"] = {
          guid = "BARGE-001",
          bridgeGUID = "BRIDGE-001",
          roros = {},
        },
      }
      local ship = buildUnit({ guid = "BARGE-001" })

      stubGetUnit.returns({ guid = "BRIDGE-001" })

      local result = AdminOffloading.isBridgeDestroyed(barges, ship)

      assert.is_false(result)
    end)

    it("should return true when barge is not registered in the barge registry", function()
      local barges = {}
      local ship = buildUnit({ guid = "UNKNOWN-001" })

      local result = AdminOffloading.isBridgeDestroyed(barges, ship)

      assert.is_true(result)
    end)

    it("should return true when barge has no bridgeGUID", function()
      local barges = {
        ["BARGE-001"] = {
          guid = "BARGE-001",
          roros = {},
        },
      }
      local ship = buildUnit({ guid = "BARGE-001" })

      local result = AdminOffloading.isBridgeDestroyed(barges, ship)

      assert.is_true(result)
    end)
  end)

  describe("hasExtendedBridge", function()
    it("should return true when barge has bridgeGUID in the barge registry", function()
      local barges = {
        ["BARGE-001"] = {
          guid = "BARGE-001",
          bridgeGUID = "BRIDGE-001",
          roros = {},
        },
      }
      local ship = buildUnit({ guid = "BARGE-001" })

      local result = AdminOffloading.hasExtendedBridge(barges, ship)

      assert.is_true(result)
    end)

    it("should return false when barge has no bridgeGUID", function()
      local barges = {
        ["BARGE-001"] = {
          guid = "BARGE-001",
          roros = {},
        },
      }
      local ship = buildUnit({ guid = "BARGE-001" })

      local result = AdminOffloading.hasExtendedBridge(barges, ship)

      assert.is_false(result)
    end)
  end)

  describe("getBargeROROZone", function()
    local stubToolRange

    before_each(function()
      stubToolRange = trackStub(stub(GameApi, "Tool_Range"))
    end)

    it("should return zone when barge and RORO are in same ACV area within 1nm", function()
      local zone = buildZone()
      local config = buildAmphibOpsConfig({ zones = { zone } })

      local barge = buildUnit({
        guid = "BARGE-001",
        inArea = function(_, area) return area == zone.landing.acv.area end,
      })
      local roro = buildUnit({
        guid = "RORO-001",
        inArea = function(_, area) return area == zone.landing.acv.area end,
      })

      stubToolRange.returns(0.5)

      local result = AdminOffloading.getBargeROROZone(config.zones, barge, roro, config.bargeRoroPairingRangeNm)
      assert.are.equal("ZoneAlpha", result.name)
    end)

    it("should return nil when units are 1nm or more apart", function()
      local zone = buildZone()
      local config = buildAmphibOpsConfig({ zones = { zone } })

      local barge = buildUnit({
        guid = "BARGE-001",
        inArea = function(_, area) return area == zone.landing.acv.area end,
      })
      local roro = buildUnit({
        guid = "RORO-001",
        inArea = function(_, area) return area == zone.landing.acv.area end,
      })

      stubToolRange.returns(1.0)

      local result = AdminOffloading.getBargeROROZone(config.zones, barge, roro, config.bargeRoroPairingRangeNm)

      assert.is_nil(result)
    end)

    it("should return nil when Tool_Range returns nil", function()
      local zone = buildZone()
      local config = buildAmphibOpsConfig({ zones = { zone } })

      local barge = buildUnit({
        guid = "BARGE-001",
        inArea = function(_, area) return area == zone.landing.acv.area end,
      })
      local roro = buildUnit({
        guid = "RORO-001",
        inArea = function(_, area) return area == zone.landing.acv.area end,
      })

      stubToolRange.returns(nil)

      local result = AdminOffloading.getBargeROROZone(config.zones, barge, roro, config.bargeRoroPairingRangeNm)

      assert.is_nil(result)
    end)

    it("should return nil when RORO is not in the ACV area", function()
      local zone = buildZone()
      local config = buildAmphibOpsConfig({ zones = { zone } })

      local barge = buildUnit({
        guid = "BARGE-001",
        inArea = function(_, area) return area == zone.landing.acv.area end,
      })
      local roro = buildUnit({
        guid = "RORO-001",
        inArea = function() return false end,
      })

      stubToolRange.returns(0.5)

      local result = AdminOffloading.getBargeROROZone(config.zones, barge, roro, config.bargeRoroPairingRangeNm)

      assert.is_nil(result)
    end)

    it("should return nil when barge is not in the ACV area", function()
      local zone = buildZone()
      local config = buildAmphibOpsConfig({ zones = { zone } })

      local barge = buildUnit({
        guid = "BARGE-001",
        inArea = function() return false end,
      })
      local roro = buildUnit({
        guid = "RORO-001",
        inArea = function(_, area) return area == zone.landing.acv.area end,
      })

      stubToolRange.returns(0.5)

      local result = AdminOffloading.getBargeROROZone(config.zones, barge, roro, config.bargeRoroPairingRangeNm)

      assert.is_nil(result)
    end)

    it("should return first matching zone from multiple operational zones", function()
      local zone1 = buildZone({ name = "Zone1", landing = { acv = { area = { "AREA-1" } } } })
      local zone2 = buildZone({ name = "Zone2", landing = { acv = { area = { "AREA-2" } } } })
      local config = buildAmphibOpsConfig({ zones = { zone1, zone2 } })

      local barge = buildUnit({
        guid = "BARGE-001",
        inArea = function(_, area) return area == zone2.landing.acv.area end,
      })
      local roro = buildUnit({
        guid = "RORO-001",
        inArea = function(_, area) return area == zone2.landing.acv.area end,
      })

      stubToolRange.returns(0.3)

      local result = AdminOffloading.getBargeROROZone(config.zones, barge, roro, config.bargeRoroPairingRangeNm)

      assert.are.equal("Zone2", result.name)
    end)

    it("should return nil when zones is empty", function()
      local config = buildAmphibOpsConfig({ zones = {} })
      local barge = buildUnit({ guid = "BARGE-001" })
      local roro = buildUnit({ guid = "RORO-001" })

      local result = AdminOffloading.getBargeROROZone(config.zones, barge, roro, config.bargeRoroPairingRangeNm)

      assert.is_nil(result)
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

    it("should return false when the bridge cannot be created", function()
      local barge = buildUnit({ guid = "BARGE-001", name = "Barge" })
      local barges = { [barge.guid] = { guid = barge.guid, roros = {} } }
      trackStub(stub(GameApi, "ScenEdit_AddUnit").returns(nil))

      local result = AdminOffloading.handleShipArrival(buildAmphibOpsConfig(), barges, barge)

      assert.is_false(result)
      assert.is_nil(barges[barge.guid].bridgeGUID)
    end)

    it("should offload vehicles for paired RORO units when the barge bridge is active", function()
      local barge = buildUnit({ guid = "BARGE-001", name = "Barge" })
      local roro = buildUnit({ guid = "RORO-001", name = "RORO" })
      local zone = buildZone()
      local barges = { [barge.guid] = { guid = barge.guid, bridgeGUID = "BRIDGE-001", roros = { roro.guid } } }
      local config = buildAmphibOpsConfig({ zones = { zone }, roroOffloadBatchSize = 20 })
      local stubAddUnit = trackStub(stub(GameApi, "ScenEdit_AddUnit"))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
        if guid == "BRIDGE-001" then return { guid = guid } end
        if guid == roro.guid then return roro end
      end))
      local stubGetZone = trackStub(stub(AdminOffloading, "getBargeROROZone").returns(zone))
      local stubOffload = trackStub(stub(AdminOffloading, "offloadVehicles").returns(20))

      local result = AdminOffloading.handleShipArrival(config, barges, barge)

      assert.is_true(result)
      assert.stub(stubAddUnit).was_not.called()
      assert.stub(stubGetZone).was.called_with({ zone }, barge, roro, 1)
      assert.stub(stubOffload).was.called_with({
        ship = roro,
        num = 20,
        bearing = zone.heading,
        distance = zone.landing.acv.distance,
        firstDistance = 1
      })
    end)

    it("should not offload when the barge bridge is destroyed", function()
      local barge = buildUnit({ guid = "BARGE-001", name = "Barge" })
      local barges = { [barge.guid] = { guid = barge.guid, bridgeGUID = "BRIDGE-001", roros = { "RORO-001" } } }
      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(nil))
      local stubOffload = trackStub(stub(AdminOffloading, "offloadVehicles"))

      local result = AdminOffloading.handleShipArrival(buildAmphibOpsConfig(), barges, barge)

      assert.is_true(result)
      assert.stub(stubOffload).was_not.called()
    end)

    it("should stop a RORO ship in place", function()
      local roro = buildUnit({ name = "RORO", course = { { latitude = 25.1, longitude = 121.1 } }, manualSpeed = 12 })

      local result = AdminOffloading.handleShipArrival(buildAmphibOpsConfig(), {}, roro)

      assert.is_true(result)
      assert.is_nil(roro.course)
      assert.are.equal(0, roro.manualSpeed)
      assert.is_true(roro.holdposition)
    end)
  end)
end)
