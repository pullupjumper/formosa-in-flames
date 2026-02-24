-- SecondWaveUnloading Unit Tests
---@diagnostic disable: undefined-field
local SecondWaveUnloading = require("src.modules.landingOps.secondWaveUnloading")
local Utils = require("src.utils.utils")
local GameApi = require("src.utils.gameApi")
local GameUtils = require("src.utils.gameUtils")
local Logger = require("src.utils.logger")

describe("SecondWaveUnloading", function()
  local activeStubs

  local function trackStub(s)
    table.insert(activeStubs, s)
    return s
  end

  before_each(function()
    activeStubs = {}
    trackStub(stub(Logger, "log"))
    trackStub(stub(Logger, "warn"))
    trackStub(stub(Logger, "error"))
  end)

  after_each(function()
    for _, s in ipairs(activeStubs) do
      s:revert()
    end
    activeStubs = {}
  end)

  -- ============================================================================
  -- Shared mock data builders
  -- ============================================================================

  ---Create an operational zone descriptor
  ---@param overrides? table
  ---@return table
  local function makeZone(overrides)
    local z = {
      name = "ZoneAlpha",
      lstAnchorageArea = { "RP-LST-1", "RP-LST-2" },
      offloadArea = { "RP-OFF-1", "RP-OFF-2", "RP-OFF-3", "RP-OFF-4" },
      lstSettings = {
        speed = 10,
        course = { bearing = 270, distance = 5 },
      },
      acv = {
        area = { "RP-ACV-1", "RP-ACV-2" },
        bearing = 90,
        distance = 0.5,
        speed = 20,
        destination = { { latitude = 25.0, longitude = 121.0 } },
      },
    }
    if overrides then
      for k, v in pairs(overrides) do z[k] = v end
    end
    return z
  end

  ---Create an amphibOpsConfig
  ---@param overrides? table
  ---@return table
  local function makeAmphibOpsConfig(overrides)
    local cfg = {
      operationalZones = { makeZone() },
    }
    if overrides then
      for k, v in pairs(overrides) do cfg[k] = v end
    end
    return cfg
  end

  ---Create a saveData structure for second wave operations
  ---@param overrides? table
  ---@return table
  local function makeSaveData(overrides)
    local sd = {
      c = {
        amphibOps = {
          barges = {},
        },
      },
    }
    if overrides then
      for k, v in pairs(overrides) do sd[k] = v end
    end
    return sd
  end

  ---Create a ship unit with sensible defaults
  ---@param overrides? table
  ---@return table
  local function makeUnit(overrides)
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
  local function makeCargoItem(overrides)
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
  local function makeSideUnit(overrides)
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
  local function makeOffloadParams(overrides)
    local p = {
      ship = makeUnit({
        cargo = {
          [1] = {
            cargo = {
              makeCargoItem({ guid = "C-1", name = "Vehicle-1" }),
              makeCargoItem({ guid = "C-2", name = "Vehicle-2" }),
              makeCargoItem({ guid = "C-3", name = "Vehicle-3" }),
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
      for k, v in pairs(overrides) do p[k] = v end
    end
    return p
  end

  -- ============================================================================
  -- startSecondWaveUnloading
  -- ============================================================================

  describe("startSecondWaveUnloading", function()
    local stubGetUnit, stubGetRefPoints, stubCalcCenter, stubToolRange, stubToolBearing
    local stubGetPointFromBearing

    before_each(function()
      stubGetUnit = trackStub(stub(GameApi, "ScenEdit_GetUnit"))
      stubGetRefPoints = trackStub(stub(GameApi, "ScenEdit_GetReferencePoints"))
      stubCalcCenter = trackStub(stub(Utils, "calculateSphericalCenter"))
      stubToolRange = trackStub(stub(GameApi, "Tool_Range"))
      stubToolBearing = trackStub(stub(GameApi, "Tool_Bearing"))
      stubGetPointFromBearing = trackStub(stub(GameApi, "World_GetPointFromBearing"))
    end)

    -- Positive: processes barges and sets course to offload area
    it("should set barge course and speed toward offload area", function()
      local zone = makeZone()
      local saveData = makeSaveData()

      local bargeUnit = makeUnit({
        guid = "BARGE-001",
        name = "Barge",
        type = "Ship",
        latitude = 24.5,
        longitude = 120.5,
        inArea = function(_, area) return area == zone.lstAnchorageArea end,
      })

      stubGetUnit.invokes(function(guid)
        if guid == "BARGE-001" then return bargeUnit end
        return nil
      end)

      local centerPoint = { latitude = 25.0, longitude = 121.0 }
      stubGetRefPoints.returns({
        { latitude = 25.1, longitude = 121.1 },
        { latitude = 25.1, longitude = 120.9 },
        { latitude = 24.9, longitude = 120.9 },
        { latitude = 24.9, longitude = 121.1 },
      })
      stubCalcCenter.returns(centerPoint)
      stubToolRange.returns(5.0)
      stubToolBearing.returns(300)
      local destination = { latitude = 24.8, longitude = 120.8 }
      stubGetPointFromBearing.returns(destination)

      local filteredUnits = { makeSideUnit({ guid = "BARGE-001" }) }
      local result = SecondWaveUnloading.startSecondWaveUnloading(zone, saveData, filteredUnits)

      assert.is_true(result)
      assert.are.same({ destination }, bargeUnit.course)
      assert.are.equal(zone.lstSettings.speed, bargeUnit.manualSpeed)
      assert.stub(Logger.log).was.called(1)
    end)

    -- Positive: registers barge in saveData with empty roros list
    it("should register barge in saveData with empty roros array", function()
      local zone = makeZone()
      local saveData = makeSaveData()

      local bargeUnit = makeUnit({
        guid = "BARGE-001",
        name = "Barge",
        type = "Ship",
        latitude = 24.5,
        longitude = 120.5,
        inArea = function(_, area) return area == zone.lstAnchorageArea end,
      })

      stubGetUnit.returns(bargeUnit)
      stubGetRefPoints.returns({
        { latitude = 25.1, longitude = 121.1 },
        { latitude = 25.1, longitude = 120.9 },
        { latitude = 24.9, longitude = 120.9 },
        { latitude = 24.9, longitude = 121.1 },
      })
      stubCalcCenter.returns({ latitude = 25.0, longitude = 121.0 })
      stubToolRange.returns(5.0)
      stubToolBearing.returns(300)
      stubGetPointFromBearing.returns({ latitude = 24.8, longitude = 120.8 })

      SecondWaveUnloading.startSecondWaveUnloading(
        zone, saveData, { makeSideUnit({ guid = "BARGE-001" }) }
      )

      assert.is_not_nil(saveData.c.amphibOps.barges["BARGE-001"])
      assert.are.equal("BARGE-001", saveData.c.amphibOps.barges["BARGE-001"].guid)
      assert.are.same({}, saveData.c.amphibOps.barges["BARGE-001"].roros)
      assert.stub(Logger.log).was.called(1)
    end)

    -- Positive: pairs RORO ships with barges in same zone
    it("should pair RORO with barge and set RORO course", function()
      local zone = makeZone()
      local saveData = makeSaveData()

      local bargeUnit = makeUnit({
        guid = "BARGE-001",
        name = "Barge",
        type = "Ship",
        latitude = 24.5,
        longitude = 120.5,
        inArea = function(_, area) return area == zone.lstAnchorageArea end,
      })

      local roroUnit = makeUnit({
        guid = "RORO-001",
        name = "RORO",
        type = "Ship",
        latitude = 24.6,
        longitude = 120.6,
        inArea = function(_, area) return area == zone.lstAnchorageArea end,
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
      stubCalcCenter.returns({ latitude = 25.0, longitude = 121.0 })
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
        makeSideUnit({ guid = "BARGE-001" }),
        makeSideUnit({ guid = "RORO-001" }),
      }

      SecondWaveUnloading.startSecondWaveUnloading(zone, saveData, filteredUnits)

      -- RORO should be registered under the barge's roros list
      assert.are.same({ "RORO-001" }, saveData.c.amphibOps.barges["BARGE-001"].roros)
      -- RORO course: first waypoint is approach, second is barge destination
      assert.are.same({ roroDest, bargeDest }, roroUnit.course)
      assert.are.equal(zone.lstSettings.speed, roroUnit.manualSpeed)
      assert.stub(Logger.log).was.called(1)
    end)

    -- Negative: skips units that cannot be resolved
    it("should skip units when ScenEdit_GetUnit returns nil", function()
      local zone = makeZone()
      local saveData = makeSaveData()

      stubGetUnit.returns(nil)

      local filteredUnits = { makeSideUnit({ guid = "MISSING-001" }) }
      local result = SecondWaveUnloading.startSecondWaveUnloading(zone, saveData, filteredUnits)

      assert.is_true(result)
      assert.are.same({}, saveData.c.amphibOps.barges)
      assert.stub(Logger.log).was_not.called()
    end)

    -- Negative: skips barge when reference points unavailable
    it("should skip barge when offload area reference points return nil", function()
      local zone = makeZone()
      local saveData = makeSaveData()

      local bargeUnit = makeUnit({
        guid = "BARGE-001",
        name = "Barge",
        type = "Ship",
        inArea = function(_, area) return area == zone.lstAnchorageArea end,
      })

      stubGetUnit.returns(bargeUnit)
      stubGetRefPoints.returns(nil)

      local result = SecondWaveUnloading.startSecondWaveUnloading(
        zone, saveData, { makeSideUnit({ guid = "BARGE-001" }) }
      )

      assert.is_true(result)
      assert.are.same({}, saveData.c.amphibOps.barges)
      assert.stub(Logger.log).was.called(1)
    end)

    -- Negative: skips barge when spherical center calculation fails
    it("should skip barge when center point calculation returns nil", function()
      local zone = makeZone()
      local saveData = makeSaveData()

      local bargeUnit = makeUnit({
        guid = "BARGE-001",
        name = "Barge",
        type = "Ship",
        inArea = function(_, area) return area == zone.lstAnchorageArea end,
      })

      stubGetUnit.returns(bargeUnit)
      stubGetRefPoints.returns({
        { latitude = 25.1, longitude = 121.1 },
        { latitude = 25.1, longitude = 120.9 },
        { latitude = 24.9, longitude = 120.9 },
        { latitude = 24.9, longitude = 121.1 },
      })
      stubCalcCenter.returns(nil)

      SecondWaveUnloading.startSecondWaveUnloading(
        zone, saveData, { makeSideUnit({ guid = "BARGE-001" }) }
      )

      assert.are.same({}, saveData.c.amphibOps.barges)
      assert.stub(Logger.log).was.called(1)
    end)

    -- Negative: skips barge when Tool_Range returns nil
    it("should skip barge when Tool_Range returns nil", function()
      local zone = makeZone()
      local saveData = makeSaveData()

      local bargeUnit = makeUnit({
        guid = "BARGE-001",
        name = "Barge",
        type = "Ship",
        inArea = function(_, area) return area == zone.lstAnchorageArea end,
      })

      stubGetUnit.returns(bargeUnit)
      stubGetRefPoints.returns({
        { latitude = 25.1, longitude = 121.1 },
        { latitude = 25.1, longitude = 120.9 },
        { latitude = 24.9, longitude = 120.9 },
        { latitude = 24.9, longitude = 121.1 },
      })
      stubCalcCenter.returns({ latitude = 25.0, longitude = 121.0 })
      stubToolRange.returns(nil)

      SecondWaveUnloading.startSecondWaveUnloading(
        zone, saveData, { makeSideUnit({ guid = "BARGE-001" }) }
      )

      assert.are.same({}, saveData.c.amphibOps.barges)
      assert.stub(Logger.log).was.called(1)
    end)

    -- Negative: skips barge when Tool_Bearing returns nil
    it("should skip barge when Tool_Bearing returns nil", function()
      local zone = makeZone()
      local saveData = makeSaveData()

      local bargeUnit = makeUnit({
        guid = "BARGE-001",
        name = "Barge",
        type = "Ship",
        inArea = function(_, area) return area == zone.lstAnchorageArea end,
      })

      stubGetUnit.returns(bargeUnit)
      stubGetRefPoints.returns({
        { latitude = 25.1, longitude = 121.1 },
        { latitude = 25.1, longitude = 120.9 },
        { latitude = 24.9, longitude = 120.9 },
        { latitude = 24.9, longitude = 121.1 },
      })
      stubCalcCenter.returns({ latitude = 25.0, longitude = 121.0 })
      stubToolRange.returns(5.0)
      stubToolBearing.returns(nil)

      SecondWaveUnloading.startSecondWaveUnloading(
        zone, saveData, { makeSideUnit({ guid = "BARGE-001" }) }
      )

      assert.are.same({}, saveData.c.amphibOps.barges)
      assert.stub(Logger.log).was.called(1)
    end)

    -- Negative: skips barge when World_GetPointFromBearing returns nil
    it("should skip barge when destination calculation returns nil", function()
      local zone = makeZone()
      local saveData = makeSaveData()

      local bargeUnit = makeUnit({
        guid = "BARGE-001",
        name = "Barge",
        type = "Ship",
        inArea = function(_, area) return area == zone.lstAnchorageArea end,
      })

      stubGetUnit.returns(bargeUnit)
      stubGetRefPoints.returns({
        { latitude = 25.1, longitude = 121.1 },
        { latitude = 25.1, longitude = 120.9 },
        { latitude = 24.9, longitude = 120.9 },
        { latitude = 24.9, longitude = 121.1 },
      })
      stubCalcCenter.returns({ latitude = 25.0, longitude = 121.0 })
      stubToolRange.returns(5.0)
      stubToolBearing.returns(300)
      stubGetPointFromBearing.returns(nil)

      SecondWaveUnloading.startSecondWaveUnloading(
        zone, saveData, { makeSideUnit({ guid = "BARGE-001" }) }
      )

      assert.are.same({}, saveData.c.amphibOps.barges)
      assert.stub(Logger.log).was.called(1)
    end)

    -- Negative: does not set RORO course when RORO destination calculation fails
    it("should not set RORO course when World_GetPointFromBearing fails for RORO", function()
      local zone = makeZone()
      local saveData = makeSaveData()

      local bargeUnit = makeUnit({
        guid = "BARGE-001",
        name = "Barge",
        type = "Ship",
        latitude = 24.5,
        longitude = 120.5,
        inArea = function(_, area) return area == zone.lstAnchorageArea end,
      })

      local roroUnit = makeUnit({
        guid = "RORO-001",
        name = "RORO",
        type = "Ship",
        latitude = 24.6,
        longitude = 120.6,
        inArea = function(_, area) return area == zone.lstAnchorageArea end,
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
      stubCalcCenter.returns({ latitude = 25.0, longitude = 121.0 })
      stubToolRange.returns(5.0)
      stubToolBearing.returns(300)

      -- Barge gets valid destination, RORO gets nil
      stubGetPointFromBearing.invokes(function(params)
        if params.latitude == bargeUnit.latitude then
          return bargeDest
        end
        return nil
      end)

      SecondWaveUnloading.startSecondWaveUnloading(
        zone, saveData,
        { makeSideUnit({ guid = "BARGE-001" }), makeSideUnit({ guid = "RORO-001" }) }
      )

      -- RORO still registered under barge, but course not updated
      assert.are.same({ "RORO-001" }, saveData.c.amphibOps.barges["BARGE-001"].roros)
      assert.are.same({}, roroUnit.course)
      assert.are.equal(0, roroUnit.manualSpeed)
      assert.stub(Logger.log).was.called(1)
    end)

    -- Boundary: ignores non-Barge/non-RORO ships
    it("should ignore units that are not Barge or RORO", function()
      local zone = makeZone()
      local saveData = makeSaveData()

      local otherUnit = makeUnit({
        guid = "LST-001",
        name = "LST",
        type = "Ship",
        inArea = function(_, area) return area == zone.lstAnchorageArea end,
      })

      stubGetUnit.returns(otherUnit)

      SecondWaveUnloading.startSecondWaveUnloading(
        zone, saveData, { makeSideUnit({ guid = "LST-001" }) }
      )

      assert.are.same({}, saveData.c.amphibOps.barges)
      assert.stub(Logger.log).was_not.called()
    end)

    -- Boundary: ignores barge not in zone's anchorage area
    it("should ignore barge that is not in lstAnchorageArea", function()
      local zone = makeZone()
      local saveData = makeSaveData()

      local bargeUnit = makeUnit({
        guid = "BARGE-001",
        name = "Barge",
        type = "Ship",
        inArea = function() return false end,
      })

      stubGetUnit.returns(bargeUnit)

      SecondWaveUnloading.startSecondWaveUnloading(
        zone, saveData, { makeSideUnit({ guid = "BARGE-001" }) }
      )

      assert.are.same({}, saveData.c.amphibOps.barges)
      assert.stub(Logger.log).was_not.called()
    end)

    -- Boundary: handles empty filteredUnits array
    it("should return true when filteredUnits is empty", function()
      local zone = makeZone()
      local saveData = makeSaveData()

      local result = SecondWaveUnloading.startSecondWaveUnloading(zone, saveData, {})

      assert.is_true(result)
      assert.are.same({}, saveData.c.amphibOps.barges)
      assert.stub(Logger.log).was_not.called()
    end)

    -- Boundary: caller invokes once per zone; each call processes its own barges
    it("should process barges for each zone when called separately per zone", function()
      local zone1 = makeZone({ name = "Zone1", lstAnchorageArea = { "AREA-Z1" } })
      local zone2 = makeZone({ name = "Zone2", lstAnchorageArea = { "AREA-Z2" } })
      local saveData = makeSaveData()

      local barge1 = makeUnit({
        guid = "BARGE-Z1",
        name = "Barge",
        type = "Ship",
        latitude = 24.5,
        longitude = 120.5,
        inArea = function(_, area) return area == zone1.lstAnchorageArea end,
      })

      local barge2 = makeUnit({
        guid = "BARGE-Z2",
        name = "Barge",
        type = "Ship",
        latitude = 23.5,
        longitude = 119.5,
        inArea = function(_, area) return area == zone2.lstAnchorageArea end,
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
      stubCalcCenter.returns({ latitude = 25.0, longitude = 121.0 })
      stubToolRange.returns(5.0)
      stubToolBearing.returns(300)
      stubGetPointFromBearing.returns({ latitude = 24.8, longitude = 120.8 })

      local allUnits = {
        makeSideUnit({ guid = "BARGE-Z1" }),
        makeSideUnit({ guid = "BARGE-Z2" }),
      }

      SecondWaveUnloading.startSecondWaveUnloading(zone1, saveData, allUnits)
      SecondWaveUnloading.startSecondWaveUnloading(zone2, saveData, allUnits)

      assert.is_not_nil(saveData.c.amphibOps.barges["BARGE-Z1"])
      assert.is_not_nil(saveData.c.amphibOps.barges["BARGE-Z2"])
      assert.stub(Logger.log).was.called(2)
    end)
  end)

  -- ============================================================================
  -- offloadVehicles
  -- ============================================================================

  describe("offloadVehicles", function()
    local stubGenerateLocations, stubAddUnit

    before_each(function()
      stubGenerateLocations = trackStub(stub(GameUtils, "generateLocations"))
      stubAddUnit = trackStub(stub(GameApi, "ScenEdit_AddUnit"))
    end)

    -- Positive: offloads correct number of vehicles as Facility type
    it("should offload vehicles and return count of successfully created units", function()
      local params = makeOffloadParams()
      local deleteStub = trackStub(stub(params.ship, "deleteUnitCargo"))

      stubGenerateLocations.returns({
        { latitude = 25.1, longitude = 121.1 },
        { latitude = 25.2, longitude = 121.2 },
      })
      stubAddUnit.returns({ guid = "CREATED-001" })

      local result = SecondWaveUnloading.offloadVehicles(params)

      assert.are.equal(2, result)
      assert.stub(deleteStub).was.called(2)
      assert.stub(stubAddUnit).was.called(2)
      assert.stub(Logger.log).was.called(1)
    end)

    -- Positive: uses "Ground unit" type when cargo item type is 2
    it("should create Ground unit when cargo item type is 2", function()
      local params = makeOffloadParams({
        num = 1,
        ship = makeUnit({
          cargo = {
            [1] = {
              cargo = {
                makeCargoItem({ guid = "C-1", name = "GroundUnit-1", Type = 2 }),
              },
            },
          },
        }),
      })
      trackStub(stub(params.ship, "deleteUnitCargo"))

      stubGenerateLocations.returns({
        { latitude = 25.1, longitude = 121.1 },
      })
      stubAddUnit.returns({ guid = "CREATED-001" })

      SecondWaveUnloading.offloadVehicles(params)

      assert.stub(stubAddUnit).was.called_with({
        side = "China",
        type = "Ground unit",
        latitude = 25.1,
        longitude = 121.1,
        dbid = 3001,
        unitname = "GroundUnit-1",
      })
      assert.stub(Logger.log).was.called(1)
    end)

    -- Positive: uses "Facility" type when cargo item type is not 2
    it("should create Facility when cargo item type is not 2", function()
      local params = makeOffloadParams({
        num = 1,
        ship = makeUnit({
          cargo = {
            [1] = {
              cargo = {
                makeCargoItem({ guid = "C-1", name = "Facility-1", Type = 1 }),
              },
            },
          },
        }),
      })
      trackStub(stub(params.ship, "deleteUnitCargo"))

      stubGenerateLocations.returns({
        { latitude = 25.1, longitude = 121.1 },
      })
      stubAddUnit.returns({ guid = "CREATED-001" })

      SecondWaveUnloading.offloadVehicles(params)

      assert.stub(stubAddUnit).was.called_with({
        side = "China",
        type = "Facility",
        latitude = 25.1,
        longitude = 121.1,
        dbid = 3001,
        unitname = "Facility-1",
      })
      assert.stub(Logger.log).was.called(1)
    end)

    -- Positive: passes correct parameters to generateLocations
    it("should pass ship location and spacing parameters to generateLocations", function()
      local params = makeOffloadParams()
      trackStub(stub(params.ship, "deleteUnitCargo"))

      stubGenerateLocations.returns({
        { latitude = 25.1, longitude = 121.1 },
        { latitude = 25.2, longitude = 121.2 },
      })
      stubAddUnit.returns({ guid = "CREATED-001" })

      SecondWaveUnloading.offloadVehicles(params)

      assert.stub(stubGenerateLocations).was.called_with({
        initialLocation = { latitude = params.ship.latitude, longitude = params.ship.longitude },
        num = 2,
        bearing = 90,
        distance = 0.5,
        firstDistance = 0.3,
      })
      assert.stub(Logger.log).was.called(1)
    end)

    -- Negative: returns nil when ship is nil
    it("should return nil when ship is nil", function()
      local params = makeOffloadParams()
      params.ship = nil

      local result = SecondWaveUnloading.offloadVehicles(params)

      assert.is_nil(result)
      assert.stub(stubGenerateLocations).was_not.called()
      assert.stub(Logger.log).was_not.called()
    end)

    -- Negative: returns nil when ship is destroyed
    it("should return nil when ship is destroyed", function()
      local params = makeOffloadParams()
      params.ship.IsDestroyed = true

      local result = SecondWaveUnloading.offloadVehicles(params)

      assert.is_nil(result)
      assert.stub(stubGenerateLocations).was_not.called()
      assert.stub(Logger.log).was_not.called()
    end)

    -- Negative: returns nil when ScenEdit_AddUnit fails mid-offload
    it("should return nil when unit creation fails", function()
      local params = makeOffloadParams()
      trackStub(stub(params.ship, "deleteUnitCargo"))

      stubGenerateLocations.returns({
        { latitude = 25.1, longitude = 121.1 },
        { latitude = 25.2, longitude = 121.2 },
      })
      stubAddUnit.invokes(function(unitParams)
        if unitParams.unitname == "Vehicle-1" then
          return { guid = "CREATED-001" }
        end
        return nil
      end)

      local result = SecondWaveUnloading.offloadVehicles(params)

      assert.is_nil(result)
      assert.stub(Logger.log).was.called(1)
    end)

    -- Boundary: limits cargo to params.num even when more cargo exists
    it("should only offload up to params.num items from cargo", function()
      local params = makeOffloadParams({ num = 1 })
      trackStub(stub(params.ship, "deleteUnitCargo"))

      stubGenerateLocations.returns({
        { latitude = 25.1, longitude = 121.1 },
      })
      stubAddUnit.returns({ guid = "CREATED-001" })

      local result = SecondWaveUnloading.offloadVehicles(params)

      assert.are.equal(1, result)
      assert.stub(stubAddUnit).was.called(1)
      assert.stub(Logger.log).was.called(1)
    end)
  end)

  -- ============================================================================
  -- isBridgeDestroyed
  -- ============================================================================

  describe("isBridgeDestroyed", function()
    local stubGetUnit

    before_each(function()
      stubGetUnit = trackStub(stub(GameApi, "ScenEdit_GetUnit"))
    end)

    -- Positive: returns true when bridge GUID exists but unit is destroyed
    it("should return true when bridge exists in saveData but unit cannot be found", function()
      local saveData = makeSaveData()
      saveData.c.amphibOps.barges["BARGE-001"] = {
        guid = "BARGE-001",
        bridgeGUID = "BRIDGE-001",
        roros = {},
      }
      local ship = makeUnit({ guid = "BARGE-001" })

      stubGetUnit.returns(nil)

      local result = SecondWaveUnloading.isBridgeDestroyed(saveData, ship)

      assert.is_true(result)
      assert.stub(Logger.log).was_not.called()
    end)

    -- Positive: returns false when bridge exists and is alive
    it("should return false when bridge unit still exists", function()
      local saveData = makeSaveData()
      saveData.c.amphibOps.barges["BARGE-001"] = {
        guid = "BARGE-001",
        bridgeGUID = "BRIDGE-001",
        roros = {},
      }
      local ship = makeUnit({ guid = "BARGE-001" })

      stubGetUnit.returns({ guid = "BRIDGE-001" })

      local result = SecondWaveUnloading.isBridgeDestroyed(saveData, ship)

      assert.is_false(result)
    end)

    -- Negative: returns true when barge has no entry in saveData
    it("should return true when barge is not registered in saveData", function()
      local saveData = makeSaveData()
      local ship = makeUnit({ guid = "UNKNOWN-001" })

      local result = SecondWaveUnloading.isBridgeDestroyed(saveData, ship)

      assert.is_true(result)
    end)

    -- Negative: returns true when barge exists but has no bridgeGUID
    it("should return true when barge has no bridgeGUID", function()
      local saveData = makeSaveData()
      saveData.c.amphibOps.barges["BARGE-001"] = {
        guid = "BARGE-001",
        roros = {},
      }
      local ship = makeUnit({ guid = "BARGE-001" })

      local result = SecondWaveUnloading.isBridgeDestroyed(saveData, ship)

      assert.is_true(result)
    end)
  end)

  -- ============================================================================
  -- hasExtendedBridge
  -- ============================================================================

  describe("hasExtendedBridge", function()
    -- Positive: returns true when bridgeGUID is set
    it("should return true when barge has bridgeGUID in saveData", function()
      local saveData = makeSaveData()
      saveData.c.amphibOps.barges["BARGE-001"] = {
        guid = "BARGE-001",
        bridgeGUID = "BRIDGE-001",
        roros = {},
      }
      local ship = makeUnit({ guid = "BARGE-001" })

      local result = SecondWaveUnloading.hasExtendedBridge(saveData, ship)

      assert.is_true(result)
    end)

    -- Negative: returns false when bridgeGUID is nil
    it("should return false when barge has no bridgeGUID", function()
      local saveData = makeSaveData()
      saveData.c.amphibOps.barges["BARGE-001"] = {
        guid = "BARGE-001",
        roros = {},
      }
      local ship = makeUnit({ guid = "BARGE-001" })

      local result = SecondWaveUnloading.hasExtendedBridge(saveData, ship)

      assert.is_false(result)
    end)
  end)

  -- ============================================================================
  -- getBargeROROZone
  -- ============================================================================

  describe("getBargeROROZone", function()
    local stubToolRange

    before_each(function()
      stubToolRange = trackStub(stub(GameApi, "Tool_Range"))
    end)

    -- Positive: returns zone when both units are in same ACV area and within 1nm
    it("should return zone when barge and RORO are in same ACV area within 1nm", function()
      local zone = makeZone()
      local config = makeAmphibOpsConfig({ operationalZones = { zone } })

      local barge = makeUnit({
        guid = "BARGE-001",
        inArea = function(_, area) return area == zone.acv.area end,
      })
      local roro = makeUnit({
        guid = "RORO-001",
        inArea = function(_, area) return area == zone.acv.area end,
      })

      stubToolRange.returns(0.5)

      local result = SecondWaveUnloading.getBargeROROZone(config, barge, roro)

      assert.is_not_nil(result)
      assert.are.equal("ZoneAlpha", result.name)
    end)

    -- Negative: returns nil when distance is 1nm or greater
    it("should return nil when units are 1nm or more apart", function()
      local zone = makeZone()
      local config = makeAmphibOpsConfig({ operationalZones = { zone } })

      local barge = makeUnit({
        guid = "BARGE-001",
        inArea = function(_, area) return area == zone.acv.area end,
      })
      local roro = makeUnit({
        guid = "RORO-001",
        inArea = function(_, area) return area == zone.acv.area end,
      })

      stubToolRange.returns(1.0)

      local result = SecondWaveUnloading.getBargeROROZone(config, barge, roro)

      assert.is_nil(result)
    end)

    -- Negative: returns nil when Tool_Range returns nil
    it("should return nil when Tool_Range returns nil", function()
      local zone = makeZone()
      local config = makeAmphibOpsConfig({ operationalZones = { zone } })

      local barge = makeUnit({
        guid = "BARGE-001",
        inArea = function(_, area) return area == zone.acv.area end,
      })
      local roro = makeUnit({
        guid = "RORO-001",
        inArea = function(_, area) return area == zone.acv.area end,
      })

      stubToolRange.returns(nil)

      local result = SecondWaveUnloading.getBargeROROZone(config, barge, roro)

      assert.is_nil(result)
    end)

    -- Negative: returns nil when RORO is not in ACV area
    it("should return nil when RORO is not in the ACV area", function()
      local zone = makeZone()
      local config = makeAmphibOpsConfig({ operationalZones = { zone } })

      local barge = makeUnit({
        guid = "BARGE-001",
        inArea = function(_, area) return area == zone.acv.area end,
      })
      local roro = makeUnit({
        guid = "RORO-001",
        inArea = function() return false end,
      })

      stubToolRange.returns(0.5)

      local result = SecondWaveUnloading.getBargeROROZone(config, barge, roro)

      assert.is_nil(result)
    end)

    -- Negative: returns nil when barge is not in ACV area
    it("should return nil when barge is not in the ACV area", function()
      local zone = makeZone()
      local config = makeAmphibOpsConfig({ operationalZones = { zone } })

      local barge = makeUnit({
        guid = "BARGE-001",
        inArea = function() return false end,
      })
      local roro = makeUnit({
        guid = "RORO-001",
        inArea = function(_, area) return area == zone.acv.area end,
      })

      stubToolRange.returns(0.5)

      local result = SecondWaveUnloading.getBargeROROZone(config, barge, roro)

      assert.is_nil(result)
    end)

    -- Boundary: returns first matching zone when multiple zones exist
    it("should return first matching zone from multiple operational zones", function()
      local zone1 = makeZone({ name = "Zone1", acv = { area = { "AREA-1" } } })
      local zone2 = makeZone({ name = "Zone2", acv = { area = { "AREA-2" } } })
      local config = makeAmphibOpsConfig({ operationalZones = { zone1, zone2 } })

      local barge = makeUnit({
        guid = "BARGE-001",
        inArea = function(_, area) return area == zone2.acv.area end,
      })
      local roro = makeUnit({
        guid = "RORO-001",
        inArea = function(_, area) return area == zone2.acv.area end,
      })

      stubToolRange.returns(0.3)

      local result = SecondWaveUnloading.getBargeROROZone(config, barge, roro)

      assert.is_not_nil(result)
      assert.are.equal("Zone2", result.name)
    end)

    -- Boundary: returns nil when no operational zones exist
    it("should return nil when operationalZones is empty", function()
      local config = makeAmphibOpsConfig({ operationalZones = {} })
      local barge = makeUnit({ guid = "BARGE-001" })
      local roro = makeUnit({ guid = "RORO-001" })

      local result = SecondWaveUnloading.getBargeROROZone(config, barge, roro)

      assert.is_nil(result)
    end)
  end)
end)
