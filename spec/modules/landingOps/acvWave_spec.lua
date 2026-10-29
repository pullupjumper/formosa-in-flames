---@diagnostic disable: need-check-nil, assign-type-mismatch, cast-local-type, param-type-mismatch, inject-field, missing-fields
-- LandingOps AcvWave Unit Tests
local AcvWave = require("src.modules.landingOps.acvWave")
local GameApi = require("src.utils.gameApi")
local Logger = require("src.utils.logger")
local RoutePlanner = require("src.modules.landingOps.routePlanner")
local constants = require("src.core.constants")
local StubTracker = require("spec.support.stubTracker")

describe("AcvWave", function()
  ---@type table<string, true>
  local aliveSet
  local trackStub = StubTracker.track

  before_each(function()
    aliveSet = {}
    trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
      return aliveSet[guid] and { guid = guid } or nil
    end))
  end)

  after_each(function()
    StubTracker.revertAll()
  end)

  local CONFIG = { capacity = { zbd05 = 4, ztd05 = 4 }, lossRatio = 0.5, holdSec = 600, hovercraftWaitSec = 1000 }

  ---@param zoneState table
  ---@param key string
  ---@param count integer
  local function launch(zoneState, key, count)
    for i = 1, count do
      local guid = key .. "-" .. i .. "-" .. #(zoneState.acvGuids and zoneState.acvGuids[key] or {})
      aliveSet[guid] = true
      AcvWave.addACV(zoneState, key, guid)
    end
  end

  it("should give each ACV type its own full capacity at first", function()
    local zoneState = {}

    assert.are.same({ zbd05 = 4, ztd05 = 4 }, AcvWave.getQuota(zoneState, CONFIG, 0))
  end)

  it("should round a fractional capacity down to a whole quota", function()
    local zoneState = {}
    local config = { capacity = { zbd05 = 112 / 3 }, lossRatio = 0.5, holdSec = 600, hovercraftWaitSec = 1000 }
    launch(zoneState, "zbd05", 3)

    assert.are.same({ zbd05 = 34 }, AcvWave.getQuota(zoneState, config, 0))
  end)

  it("should reduce the quota by ACVs already launched this tick", function()
    local zoneState = {}
    launch(zoneState, "zbd05", 3)

    assert.are.same({ zbd05 = 1, ztd05 = 4 }, AcvWave.getQuota(zoneState, CONFIG, 0))
  end)

  it("should pause a type that reached capacity and keep the other open", function()
    local zoneState = {}
    launch(zoneState, "zbd05", 4)

    local quota = AcvWave.getQuota(zoneState, CONFIG, 100)

    assert.are.equal(0, quota.zbd05)
    assert.are.equal(4, quota.ztd05)
    assert.are.equal(100, zoneState.acvPausedAt.zbd05)
  end)

  it("should stay paused when losses are below lossRatio and hold time has not passed", function()
    local zoneState = {}
    launch(zoneState, "zbd05", 4)
    AcvWave.getQuota(zoneState, CONFIG, 100)
    aliveSet[zoneState.acvGuids.zbd05[1]] = nil -- 3 of 4 alive, threshold is 2

    assert.are.equal(0, AcvWave.getQuota(zoneState, CONFIG, 200).zbd05)
  end)

  it("should resume and refill to capacity when alive drops below (1 - lossRatio)", function()
    local zoneState = {}
    launch(zoneState, "zbd05", 4)
    AcvWave.getQuota(zoneState, CONFIG, 100)
    aliveSet[zoneState.acvGuids.zbd05[1]] = nil
    aliveSet[zoneState.acvGuids.zbd05[2]] = nil
    aliveSet[zoneState.acvGuids.zbd05[3]] = nil -- 1 of 4 alive

    local quota = AcvWave.getQuota(zoneState, CONFIG, 200)

    assert.are.equal(3, quota.zbd05)
    assert.is_nil(zoneState.acvPausedAt.zbd05)
    assert.are.equal(1, #zoneState.acvGuids.zbd05)
  end)

  it("should resume after holdSec even without heavy losses", function()
    local zoneState = {}
    launch(zoneState, "zbd05", 4)
    AcvWave.getQuota(zoneState, CONFIG, 100)
    aliveSet[zoneState.acvGuids.zbd05[1]] = nil

    assert.are.equal(1, AcvWave.getQuota(zoneState, CONFIG, 700).zbd05)
  end)

  it("should resume exactly when holdSec has passed, not one second earlier", function()
    local zoneState = {}
    launch(zoneState, "zbd05", 4)
    AcvWave.getQuota(zoneState, CONFIG, 100)
    aliveSet[zoneState.acvGuids.zbd05[1]] = nil

    assert.are.equal(0, AcvWave.getQuota(zoneState, CONFIG, 699).zbd05)
    assert.are.equal(1, AcvWave.getQuota(zoneState, CONFIG, 700).zbd05)
  end)

  it("should free the parking slot of an ACV that is no longer found", function()
    local zoneState = { laneSlots = { ["W1-B1"] = { "ACV-DEAD" } } }
    AcvWave.addACV(zoneState, "zbd05", "ACV-DEAD")

    AcvWave.getQuota(zoneState, CONFIG, 0)

    assert.are.same({ false }, zoneState.laneSlots["W1-B1"])
  end)

  describe("buildZoneWaveConfig", function()
    it("should take the cap from the zone and keep the shared tuning", function()
      local tuning = { lossRatio = 0.5, holdSec = 600 }
      local zone = { landing = { acv = { capacity = { zbd05 = 28, ztd05 = 28 } } } }

      local config = AcvWave.buildZoneWaveConfig(tuning, zone)

      assert.are.same({ zbd05 = 28, ztd05 = 28 }, config.capacity)
      assert.are.equal(0.5, config.lossRatio)
      assert.is_nil(tuning.capacity)
    end)
  end)

  describe("isFirstWaveFull", function()
    it("should be false until every type reaches capacity", function()
      local zoneState = {}
      launch(zoneState, "zbd05", 4)
      launch(zoneState, "ztd05", 3)

      assert.is_false(AcvWave.isFirstWaveFull(zoneState, CONFIG, 0))
    end)

    it("should release after the wait times out", function()
      local zoneState = {}
      launch(zoneState, "zbd05", 1)

      assert.is_false(AcvWave.isFirstWaveFull(zoneState, CONFIG, 0))
      assert.is_false(AcvWave.isFirstWaveFull(zoneState, CONFIG, 999))
      assert.is_true(AcvWave.isFirstWaveFull(zoneState, CONFIG, 1000))
    end)

    it("should latch true even after losses", function()
      local zoneState = {}
      launch(zoneState, "zbd05", 4)
      launch(zoneState, "ztd05", 4)
      assert.is_true(AcvWave.isFirstWaveFull(zoneState, CONFIG, 0))

      aliveSet[zoneState.acvGuids.zbd05[1]] = nil
      assert.is_true(AcvWave.isFirstWaveFull(zoneState, CONFIG, 0))
    end)
  end)

  describe("release", function()
    local DESTINATION = { { latitude = 25.0, longitude = 121.0 } }
    local logStub, errorStub, stubGetPoint, stubAddUnit, stubSetDoctrine, stubReserveCourse

    before_each(function()
      logStub = trackStub(stub(Logger, "log"))
      errorStub = trackStub(stub(Logger, "error"))
      trackStub(stub(Logger, "warn"))
      trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(1000))
      stubReserveCourse = trackStub(stub(RoutePlanner, "reserveCourse"))
      stubGetPoint = trackStub(stub(GameApi, "World_GetPointFromBearing"))
      stubAddUnit = trackStub(stub(GameApi, "ScenEdit_AddUnit"))
      stubSetDoctrine = trackStub(stub(GameApi, "ScenEdit_SetDoctrine"))
    end)

    ---Create a ship carrying the given number of ZBD and ZTD vehicles
    ---@param zbd integer
    ---@param ztd integer
    ---@return table ship
    ---@return string[] deleted GUIDs removed from the ship cargo
    local function buildCargoShip(zbd, ztd)
      local cargo, deleted = {}, {}
      for i = 1, zbd do table.insert(cargo, { guid = "CARGO-ZBD-" .. i, dbid = 241 }) end
      for i = 1, ztd do table.insert(cargo, { guid = "CARGO-ZTD-" .. i, dbid = 240 }) end
      local ship = { guid = "SHIP-001", name = "TestShip", latitude = 25.0, longitude = 121.0, IsDestroyed = false,
        cargo = { [1] = { cargo = cargo } } }
      ship.deleteUnitCargo = function(_, guid)
        table.insert(deleted, guid)
        return true
      end
      return ship, deleted
    end

    ---Release a batch from a ship in a zone whose cap per type equals quota.
    ---Every lane course request returns course; no course means no lane has room
    ---@param params {ship: table|nil, quota: table<string, integer>, num: integer, course?: table}
    ---@return table|nil result
    ---@return table zoneState
    local function release(params)
      stubReserveCourse.returns(params.course and { course = params.course } or nil)
      local zone = {
        name = "ZoneAlpha",
        heading = 90,
        landing = { acv = { distance = 0.5, capacity = params.quota, destination = DESTINATION } },
      }
      local zoneState = {}
      local amphibOps = { acvLaunchBatchSize = params.num, tuning = { acvWave = { lossRatio = 0.5, holdSec = 600 }, route = {} } }
      return AcvWave.release(amphibOps, zone, zoneState, params.ship), zoneState
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

    it("should launch both ZBD and ZTD vehicles and return total count", function()
      local locations = {
        { latitude = 25.1, longitude = 121.1 },
        { latitude = 25.2, longitude = 121.2 },
        { latitude = 25.3, longitude = 121.3 },
        { latitude = 25.4, longitude = 121.4 },
      }
      placeAt(locations)
      stubAddUnit.returns({ guid = "NEW-UNIT" })
      stubSetDoctrine.returns(true)

      local ship = buildCargoShip(2, 2)
      local params = {
        ship = ship,
        quota = { zbd05 = 99, ztd05 = 99 },
        course = { { latitude = 25.0, longitude = 121.0 } },
        num = 4,
      }

      local count = release(params).count

      assert.are.equal(4, count)
      assert.stub(stubAddUnit).was.called(4)
      assert.stub(stubSetDoctrine).was.called(4)
      assert.stub(logStub).was.called()
    end)

    it("should launch only ZTD vehicles when ZBD cargo is zero", function()
      local locations = {
        { latitude = 25.1, longitude = 121.1 },
        { latitude = 25.2, longitude = 121.2 },
      }
      placeAt(locations)
      stubAddUnit.returns({ guid = "NEW-UNIT" })
      stubSetDoctrine.returns(true)

      local ship = buildCargoShip(0, 2)
      local params = {
        ship = ship,
        quota = { zbd05 = 99, ztd05 = 99 },
        course = { { latitude = 25.0, longitude = 121.0 } },
        num = 2,
      }

      local count = release(params).count

      assert.are.equal(2, count)
    end)

    it("should launch only ZBD vehicles when ZTD cargo request is zero", function()
      local locations = {
        { latitude = 25.1, longitude = 121.1 },
        { latitude = 25.2, longitude = 121.2 },
      }
      placeAt(locations)
      stubAddUnit.returns({ guid = "NEW-UNIT" })
      stubSetDoctrine.returns(true)

      local ship = buildCargoShip(2, 0)
      local params = {
        ship = ship,
        quota = { zbd05 = 99, ztd05 = 99 },
        course = { { latitude = 25.0, longitude = 121.0 } },
        num = 2,
      }

      local count = release(params).count

      assert.are.equal(2, count)
    end)

    it("should set throttle to Full and assign destination course", function()
      local locations = { { latitude = 25.1, longitude = 121.1 } }
      placeAt(locations)
      local addedUnit = { guid = "NEW-UNIT", throttle = nil, course = nil }
      stubAddUnit.returns(addedUnit)
      stubSetDoctrine.returns(true)

      local destination = { { latitude = 25.0, longitude = 121.0 } }
      local ship = buildCargoShip(0, 1)
      local params = {
        ship = ship,
        quota = { zbd05 = 99, ztd05 = 99 },
        course = destination,
        num = 1,
      }

      release(params)

      assert.are.equal("Full", addedUnit.throttle)
      assert.are.same(destination, addedUnit.course)
    end)

    it("should return nil when ship is nil", function()
      local params = {
        ship = nil,
        quota = { zbd05 = 99, ztd05 = 99 },
        num = 2,
      }

      local result = release(params)

      assert.is_nil(result)
    end)

    it("should return nil when ship is destroyed", function()
      local ship = buildCargoShip(2, 2)
      ship.IsDestroyed = true
      local params = {
        ship = ship,
        quota = { zbd05 = 99, ztd05 = 99 },
        num = 2,
      }

      local result = release(params)

      assert.is_nil(result)
    end)

    it("should return nil when adding ZTD unit fails", function()
      local locations = { { latitude = 25.1, longitude = 121.1 } }
      placeAt(locations)
      stubAddUnit.returns(nil)

      local ship = buildCargoShip(0, 1)
      local params = {
        ship = ship,
        quota = { zbd05 = 99, ztd05 = 99 },
        course = { { latitude = 25.0, longitude = 121.0 } },
        num = 1,
      }

      local result = release(params)

      assert.is_nil(result.count)
      assert.stub(errorStub).was.called(1)
      assert.truthy(string.find(errorStub.calls[1].vals[1], "unit=ZTD%-05 reason=add_unit_failed"))
    end)

    it("should return nil when setting doctrine fails for ZTD unit", function()
      local locations = { { latitude = 25.1, longitude = 121.1 } }
      placeAt(locations)
      stubAddUnit.returns({ guid = "NEW-UNIT" })
      stubSetDoctrine.returns(nil)

      local ship = buildCargoShip(0, 1)
      local params = {
        ship = ship,
        quota = { zbd05 = 99, ztd05 = 99 },
        course = { { latitude = 25.0, longitude = 121.0 } },
        num = 1,
      }

      local result = release(params)

      assert.is_nil(result.count)
      assert.stub(errorStub).was.called(1)
      assert.truthy(string.find(errorStub.calls[1].vals[1], "unit=ZTD%-05 reason=set_doctrine_failed"))
    end)

    it("should return nil when adding ZBD unit fails", function()
      local locations = {
        { latitude = 25.1, longitude = 121.1 },
        { latitude = 25.2, longitude = 121.2 },
      }
      placeAt(locations)
      -- Only ZBD is carried; AddUnit fails for it
      stubAddUnit.returns(nil)

      local ship = buildCargoShip(1, 0)
      local params = {
        ship = ship,
        quota = { zbd05 = 99, ztd05 = 99 },
        course = { { latitude = 25.0, longitude = 121.0 } },
        num = 1,
      }

      local result = release(params)

      assert.is_nil(result.count)
      assert.stub(errorStub).was.called(1)
      assert.truthy(string.find(errorStub.calls[1].vals[1], "unit=ZBD%-05 reason=add_unit_failed"))
    end)

    it("should return nil when setting doctrine fails for ZBD unit", function()
      local locations = {
        { latitude = 25.1, longitude = 121.1 },
        { latitude = 25.2, longitude = 121.2 },
      }
      placeAt(locations)
      stubAddUnit.returns({ guid = "NEW-UNIT" })
      stubSetDoctrine.returns(nil)

      local ship = buildCargoShip(1, 0)
      local params = {
        ship = ship,
        quota = { zbd05 = 99, ztd05 = 99 },
        course = { { latitude = 25.0, longitude = 121.0 } },
        num = 1,
      }

      local result = release(params)

      assert.is_nil(result.count)
      assert.stub(errorStub).was.called(1)
      assert.truthy(string.find(errorStub.calls[1].vals[1], "unit=ZBD%-05 reason=set_doctrine_failed"))
    end)

    it("should return zero when no cargo is available for deletion", function()
      local locations = {}
      placeAt(locations)

      local ship = buildCargoShip(0, 0)
      local params = {
        ship = ship,
        quota = { zbd05 = 99, ztd05 = 99 },
        course = { { latitude = 25.0, longitude = 121.0 } },
        num = 2,
      }

      local count = release(params).count

      assert.are.equal(0, count)
      assert.stub(stubAddUnit).was_not.called()
    end)

    -- An empty ship reports isEmpty so the caller can send it home
    it("should report isEmpty when the ship carries no ZBD or ZTD", function()
      local ship, deleted = buildCargoShip(0, 0)
      table.insert(ship.cargo[1].cargo, { guid = "MC-1", dbid = constants.PLATFORMS.MC })

      local result = release({
        ship = ship,
        num = 5,
        quota = { zbd05 = 99, ztd05 = 99 },
        course = {},
      })

      assert.are.same({ count = 0, isEmpty = true, isPaused = false }, result)
      assert.are.same({}, deleted)
    end)

    it("should report isPaused and keep cargo when the quota allows none of it", function()
      local ship, deleted = buildCargoShip(2, 2)

      local result = release({
        ship = ship,
        num = 5,
        quota = { zbd05 = 0, ztd05 = 0 },
        course = {},
      })

      assert.are.same({ count = 0, isEmpty = false, isPaused = true }, result)
      assert.are.same({}, deleted)
    end)

    it("should request at most each type's quota from cargo", function()
      placeAt({ { latitude = 25.1, longitude = 121.1 }, { latitude = 25.2, longitude = 121.2 } })
      stubAddUnit.returns({ guid = "NEW-UNIT" })
      stubSetDoctrine.returns(true)
      local ship, deleted = buildCargoShip(2, 2)

      local result = release({
        ship = ship,
        num = 5,
        quota = { zbd05 = 1, ztd05 = 1 },
        course = {},
      })

      assert.are.equal(2, result.count)
      assert.are.same({ "CARGO-ZBD-1", "CARGO-ZTD-1" }, deleted)
    end)

    it("should plan each spawned ACV's lane course and count it against its type", function()
      placeAt({ { latitude = 25.1, longitude = 121.1 } })
      local addedUnit = { guid = "NEW-UNIT", latitude = 25.1, longitude = 121.1 }
      stubAddUnit.returns(addedUnit)
      stubSetDoctrine.returns(true)
      local route = { { latitude = 25.5, longitude = 121.5 } }

      local _, zoneState = release({ ship = buildCargoShip(1, 0), num = 1, quota = { zbd05 = 5, ztd05 = 5 }, course = route })

      assert.stub(stubReserveCourse).was.called_with(zoneState, {
        guid = "NEW-UNIT",
        launchPos = { latitude = 25.1, longitude = 121.1 },
        routeConfig = {},
      })
      assert.are.same({ "NEW-UNIT" }, zoneState.acvGuids.zbd05)
      assert.are.same(route, addedUnit.course)
    end)

    it("should fall back to the zone destination when no lane has room", function()
      placeAt({ { latitude = 25.1, longitude = 121.1 } })
      local addedUnit = { guid = "NEW-UNIT" }
      stubAddUnit.returns(addedUnit)
      stubSetDoctrine.returns(true)

      local _, zoneState = release({ ship = buildCargoShip(1, 0), num = 1, quota = { zbd05 = 5, ztd05 = 5 } })

      assert.are.same(DESTINATION, addedUnit.course)
      assert.are.same({ "NEW-UNIT" }, zoneState.acvGuids.zbd05)
    end)
  end)
end)
