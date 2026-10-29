---@diagnostic disable: need-check-nil, assign-type-mismatch, cast-local-type, param-type-mismatch, inject-field
-- LandingOps Init Unit Tests
local LandingOps = require("src.modules.landingOps.init")
local GameApi = require("src.utils.gameApi")
local Logger = require("src.utils.logger")
local ShipMovement = require("src.modules.landingOps.shipMovement")
local Coordinator = require("src.modules.landingOps.coordinator")
local AmphibiousAssault = require("src.modules.landingOps.amphibiousAssault")
local AdminOffloading = require("src.modules.landingOps.adminOffloading")
local AttackManager = require("src.modules.attackManager")
local constants = require("src.core.constants")
local StubTracker = require("spec.support.stubTracker")

describe("LandingOps", function()
  ---@type luassert.spy
  local logStub
  ---@type luassert.spy
  local errorStub
  local trackStub = StubTracker.track

  before_each(function()
    logStub = trackStub(stub(Logger, "log"))
    errorStub = trackStub(stub(Logger, "error"))
  end)

  after_each(function()
    StubTracker.revertAll()
  end)

  ---Create a ship unit with sensible defaults
  ---@param overrides? table
  ---@return table
  local function buildShip(overrides)
    local ship = {
      guid = "SHIP-001",
      name = "Ship",
      side = constants.SIDES.RED,
      dbid = constants.PLATFORMS.TYPE_052D,
      group = { name = "SAG Alpha" },
      latitude = 25.0,
      longitude = 121.0,
      course = { { latitude = 25.1, longitude = 121.1 } },
      manualSpeed = 12,
      holdposition = false,
      RTB = function() end,
    }
    if overrides then
      for k, v in pairs(overrides) do
        ship[k] = v
      end
    end
    return ship
  end

  ---Create an amphibious zone descriptor
  ---@param overrides? table
  ---@return table
  local function buildZone(overrides)
    local zone = {
      heading = 180,
      movement = { baseGUID = "BASE-001" },
      landing = {
        acv = {
          distance = 0.5,
          capacity = { zbd05 = 112, ztd05 = 112 },
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

  ---Create a mock contact with sensible defaults
  ---@param overrides? table
  ---@return table
  local function buildContact(overrides)
    local contact = {
      guid = "CONTACT-001",
      typed = constants.CONTACT_TYPES.FACILITY_MOBILE,
      inArea = function() return true end,
    }
    if overrides then
      for k, v in pairs(overrides) do
        contact[k] = v
      end
    end
    return contact
  end

  ---Wrap an amphibious operations config section into the global config shape
  ---@param amphibOpsConfig table
  ---@return table
  local function buildConfig(amphibOpsConfig)
    return { red = { amphibOps = amphibOpsConfig } }
  end

  ---Create save data holding China's amphibious state
  ---@param amphibOps table
  ---@return table
  local function buildSaveData(amphibOps)
    return { red = { amphibOps = amphibOps, recon = {}, ground = {} } }
  end

  describe("init", function()
    -- Delegates destination pre-calculation to ShipMovement
    it("should initialize landing operations by calculating destinations", function()
      local saveData = buildSaveData({ calculationResult = {} })
      local configOverrides = { zones = {}, formation = {} }
      local stubCalc = trackStub(stub(ShipMovement, "buildHoldingPositions"))

      LandingOps.init(buildConfig(configOverrides), saveData)

      assert.stub(stubCalc).was.called_with(configOverrides.zones, configOverrides.formation, saveData.red.amphibOps.calculationResult)
    end)
  end)

  describe("process", function()
    it("should forward landing state, contacts, time and ships to coordinator", function()
      local stubProcess = trackStub(stub(Coordinator, "process"))
      local config = buildConfig({})
      local saveData = buildSaveData({ barges = { ["BARGE-001"] = { roros = {} } } })
      local contacts = { buildContact() }
      local filteredShips = { { guid = "SHIP-001" } }
      trackStub(stub(GameApi, "ScenEdit_GetContacts").returns(contacts))
      trackStub(stub(GameApi, "VP_GetSide").returns({ unitsBy = function() return filteredShips end }))
      trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(100))

      LandingOps.process(config, saveData)

      local args = stubProcess.calls[1].vals
      assert.are.same(config, args[1])
      assert.are.same(saveData.red.amphibOps, args[2].amphibOps)
      assert.are.same(contacts, args[3].contacts)
      assert.are.equal(100, args[3].currentTime)
      assert.are.same(filteredShips, args[3].filteredShips)
    end)

    it("should skip the coordinator when contacts are unavailable", function()
      local stubProcess = trackStub(stub(Coordinator, "process"))
      trackStub(stub(GameApi, "ScenEdit_GetContacts").returns(nil))

      LandingOps.process(buildConfig({}), buildSaveData({}))

      assert.stub(stubProcess).was_not.called()
    end)
  end)

  describe("launchACV", function()
    local ACV_WAVE = { lossRatio = 0.3, holdSec = 1800 }

    ---@param phase string
    ---@return table saveData
    ---@return table zoneState
    local function buildZoneSaveData(phase)
      local zoneState = { phase = phase }
      return buildSaveData({ zoneStates = { ZoneAlpha = zoneState } }), zoneState
    end

    before_each(function()
      trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(1000))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(nil))
    end)

    it("should launch ACVs with quota and a router when the zone is in ASSAULT_LANDING", function()
      local ship = buildShip()
      local zone = buildZone({ name = "ZoneAlpha" })
      local saveData, zoneState = buildZoneSaveData(constants.AMPHIBIOUS_PHASES.ASSAULT_LANDING)
      trackStub(stub(AmphibiousAssault, "isFerryOrLST").returns(true))
      trackStub(stub(AmphibiousAssault, "getShipZone").returns(zone))
      local stubLaunch = trackStub(stub(AmphibiousAssault, "launchACV")
        .returns({ count = 2, isEmpty = false, isPaused = false }))

      local result = LandingOps.launchACV(buildConfig({ acvLaunchBatchSize = 5, tuning = { acvWave = ACV_WAVE, route = {} } }), saveData, ship)

      assert.is_true(result)
      local params = stubLaunch.calls[1].vals[1]
      assert.are.same(ship, params.ship)
      assert.are.equal(5, params.num)
      assert.are.equal(180, params.bearing)
      assert.are.same({ zbd05 = 112, ztd05 = 112 }, params.quota)
      assert.are.equal("function", type(params.routeACV))
      assert.is_not_nil(zoneState.acvGuids)
    end)

    it("should record the ACV and fall back to the zone destination when no lane is available", function()
      local zone = buildZone({ name = "ZoneAlpha" })
      local saveData, zoneState = buildZoneSaveData(constants.AMPHIBIOUS_PHASES.ASSAULT_LANDING)
      trackStub(stub(AmphibiousAssault, "isFerryOrLST").returns(true))
      trackStub(stub(AmphibiousAssault, "getShipZone").returns(zone))
      local course
      trackStub(stub(AmphibiousAssault, "launchACV").invokes(function(params)
        course = params.routeACV({ guid = "ACV-1", latitude = 25.0, longitude = 121.0 }, "zbd05")
        return { count = 1, isEmpty = false, isPaused = false }
      end))
      trackStub(stub(Logger, "warn"))

      LandingOps.launchACV(buildConfig({ tuning = { acvWave = ACV_WAVE, route = {} } }), saveData, buildShip())

      assert.are.same(zone.landing.acv.destination, course)
      assert.are.same({ "ACV-1" }, zoneState.acvGuids.zbd05)
    end)

    it("should not launch before the zone reaches ASSAULT_LANDING", function()
      local zone = buildZone({ name = "ZoneAlpha" })
      local saveData = buildZoneSaveData(constants.AMPHIBIOUS_PHASES.OBSTACLE_CLEARING)
      trackStub(stub(AmphibiousAssault, "isFerryOrLST").returns(true))
      trackStub(stub(AmphibiousAssault, "getShipZone").returns(zone))
      local stubLaunch = trackStub(stub(AmphibiousAssault, "launchACV"))

      local result = LandingOps.launchACV(buildConfig({ tuning = { acvWave = ACV_WAVE, route = {} } }), saveData,
        buildShip())

      assert.is_false(result)
      assert.stub(stubLaunch).was_not.called()
    end)

    it("should return false when ship is not a ferry or LST", function()
      local ship = buildShip()
      local stubIsFerry = trackStub(stub(AmphibiousAssault, "isFerryOrLST").returns(false))
      local stubGetZone = trackStub(stub(AmphibiousAssault, "getShipZone"))

      local result = LandingOps.launchACV(buildConfig({}), buildSaveData({}), ship)

      assert.is_false(result)
      assert.stub(stubIsFerry).was.called_with(ship)
      assert.stub(stubGetZone).was_not.called()
    end)

    it("should host the ship back to base and RTB when the ship is empty", function()
      local wasRTB = false
      local ship = buildShip({
        RTB = function(_, force)
          wasRTB = force
        end,
      })
      local zone = buildZone({ name = "ZoneAlpha" })
      local saveData = buildZoneSaveData(constants.AMPHIBIOUS_PHASES.COMPLETED)
      trackStub(stub(AmphibiousAssault, "isFerryOrLST").returns(true))
      trackStub(stub(AmphibiousAssault, "getShipZone").returns(zone))
      trackStub(stub(AmphibiousAssault, "launchACV").returns({ count = 0, isEmpty = true, isPaused = false }))
      local stubHost = trackStub(stub(GameApi, "ScenEdit_HostUnitToParent").returns(true))

      local result = LandingOps.launchACV(buildConfig({ tuning = { acvWave = ACV_WAVE, route = {} } }), saveData, ship)

      assert.is_true(result)
      assert.is_true(wasRTB)
      assert.stub(stubHost).was.called_with({
        HostedUnitNameOrID = ship.guid,
        SelectedBaseNameOrID = zone.movement.baseGUID
      })
    end)

    it("should not RTB the ship when the wave is paused", function()
      local wasRTB = false
      local ship = buildShip({ RTB = function() wasRTB = true end })
      local zone = buildZone({ name = "ZoneAlpha" })
      local saveData = buildZoneSaveData(constants.AMPHIBIOUS_PHASES.ASSAULT_LANDING)
      trackStub(stub(AmphibiousAssault, "isFerryOrLST").returns(true))
      trackStub(stub(AmphibiousAssault, "getShipZone").returns(zone))
      trackStub(stub(AmphibiousAssault, "launchACV").returns({ count = 0, isEmpty = false, isPaused = true }))
      local stubHost = trackStub(stub(GameApi, "ScenEdit_HostUnitToParent"))

      local result = LandingOps.launchACV(buildConfig({ tuning = { acvWave = ACV_WAVE, route = {} } }), saveData, ship)

      assert.is_true(result)
      assert.is_false(wasRTB)
      assert.stub(stubHost).was_not.called()
    end)
  end)

  describe("offloadVehicles", function()
    it("should forward the amphibious config, barge registry and ship to AdminOffloading", function()
      local ship = buildShip({ name = "Barge" })
      local amphibOpsConfig = { zones = {} }
      local saveData = buildSaveData({ barges = {} })
      local stubHandle = trackStub(stub(AdminOffloading, "handleShipArrival").returns(true))

      local result = LandingOps.offloadVehicles(buildConfig(amphibOpsConfig), saveData, ship)

      assert.is_true(result)
      assert.stub(stubHandle).was.called_with(amphibOpsConfig, saveData.red.amphibOps.barges, ship)
    end)
  end)

  describe("attackAirlandingZone", function()
    it("should attack filtered mobile ground contacts for a valid Type 052D SAG ship", function()
      local ship = buildShip()
      local contacts = {
        buildContact({ guid = "C-1" }),
        buildContact({ guid = "C-2" }),
        buildContact({
          guid = "C-3",
          typed = constants.CONTACT_TYPES.AIR,
        }),
      }
      local configOverrides = {
        airlandingFireQty = 440,
        zones = {
          {
            sags = {
              { groupName = "SAG Alpha", area = { "RP-SAG-1", "RP-SAG-2" } },
            },
          },
        },
      }
      local stubSetDoctrine = trackStub(stub(GameApi, "ScenEdit_SetDoctrine"))
      local stubAttackContacts = trackStub(stub(AttackManager, "attackContacts"))
      trackStub(stub(GameApi, "ScenEdit_GetContacts").returns(contacts))

      local result = LandingOps.attackAirlandingZone(buildConfig(configOverrides), ship)

      assert.is_true(result)
      assert.stub(stubSetDoctrine).was.called_with(
        { side = ship.side, unitname = ship.group.name },
        { weapon_control_status_land = constants.WCS.FREE }
      )
      assert.stub(stubAttackContacts).was.called_with({
        contacts = { "C-1", "C-2" },
        qty = 220,
        firingUnits = { ship },
        weaponDBID = constants.WEAPONS.HPJ_38,
      })
    end)

    it("should return false for ships outside the supported SAG destroyer context", function()
      local ship = buildShip({ dbid = constants.PLATFORMS.TYPE_054A })
      local configOverrides = { zones = {} }

      local stubAttackContacts = trackStub(stub(AttackManager, "attackContacts"))

      local result = LandingOps.attackAirlandingZone(buildConfig(configOverrides), ship)

      assert.is_false(result)
      assert.stub(stubAttackContacts).was_not.called()
    end)

    it("should return false when no mobile ground contacts remain after filtering", function()
      local ship = buildShip()
      local contacts = {
        buildContact({
          guid = "C-1",
          inArea = function() return false end,
        }),
      }
      local configOverrides = {
        zones = {
          {
            sags = {
              { groupName = "SAG Alpha", area = { "RP-SAG-1", "RP-SAG-2" } },
            },
          },
        },
      }
      local stubSetDoctrine = trackStub(stub(GameApi, "ScenEdit_SetDoctrine"))
      trackStub(stub(GameApi, "ScenEdit_GetContacts").returns(contacts))

      local result = LandingOps.attackAirlandingZone(buildConfig(configOverrides), ship)

      assert.is_false(result)
      assert.stub(stubSetDoctrine).was_not.called()
    end)
  end)

  describe("removeDestroyedUnit", function()
    it("should remove the unit from the zone that recorded it", function()
      local zoneStateA = { heliWave = { units = {}, attackers = {} } }
      local zoneStateB = { heliWave = { units = { T1 = {} }, attackers = {} } }
      local saveData = buildSaveData({ zoneStates = { A = zoneStateA, B = zoneStateB } })

      assert.is_true(LandingOps.removeDestroyedUnit(saveData, "T1"))

      assert.is_nil(zoneStateB.heliWave.units.T1)
    end)

    it("should return false when no zone recorded the unit", function()
      local saveData = buildSaveData({ zoneStates = { A = { heliWave = { units = {}, attackers = {} } } } })

      assert.is_false(LandingOps.removeDestroyedUnit(saveData, "NOPE"))
    end)

    it("should remove a destroyed ACV so it no longer counts against the wave quota", function()
      local zoneState = { acvGuids = { zbd05 = { "ACV-1", "ACV-2" } } }
      local saveData = buildSaveData({ zoneStates = { A = zoneState } })

      assert.is_true(LandingOps.removeDestroyedUnit(saveData, "ACV-1"))

      assert.are.same({ "ACV-2" }, zoneState.acvGuids.zbd05)
    end)

    it("should remove a destroyed assault boat", function()
      local zoneState = { boats = { ["BOAT-1"] = { status = "launched" }, ["BOAT-2"] = { status = "launched" } } }
      local saveData = buildSaveData({ zoneStates = { A = zoneState } })

      assert.is_true(LandingOps.removeDestroyedUnit(saveData, "BOAT-1"))

      assert.is_nil(zoneState.boats["BOAT-1"])
      assert.is_not_nil(zoneState.boats["BOAT-2"])
    end)

    it("should remove a destroyed hovercraft", function()
      local zoneState = { hovercraft = { ["LCAC-1"] = { phase = "enroute" } } }
      local saveData = buildSaveData({ zoneStates = { A = zoneState } })

      assert.is_true(LandingOps.removeDestroyedUnit(saveData, "LCAC-1"))

      assert.is_nil(zoneState.hovercraft["LCAC-1"])
    end)

    it("should remove a destroyed minesweeper", function()
      local zoneState = { minesweepers = { ["MCM-1"] = { isDone = false } } }
      local saveData = buildSaveData({ zoneStates = { A = zoneState } })

      assert.is_true(LandingOps.removeDestroyedUnit(saveData, "MCM-1"))

      assert.is_nil(zoneState.minesweepers["MCM-1"])
    end)

    it("should free the parking slot of a destroyed unit at once and keep the slots a dense array", function()
      local zoneState = { laneSlots = { ["W1-B1"] = { "ACV-1", "ACV-2" } } }
      local saveData = buildSaveData({ zoneStates = { A = zoneState } })

      assert.is_true(LandingOps.removeDestroyedUnit(saveData, "ACV-1"))

      assert.are.same({ false, "ACV-2" }, zoneState.laneSlots["W1-B1"])
    end)

    it("should remove a unit from every record that holds it", function()
      local zoneState = {
        boats = { ["BOAT-1"] = { status = "arrived" } },
        laneSlots = { ["W1-B1"] = { false, "BOAT-1" } },
      }
      local saveData = buildSaveData({ zoneStates = { A = zoneState } })

      assert.is_true(LandingOps.removeDestroyedUnit(saveData, "BOAT-1"))

      assert.is_nil(zoneState.boats["BOAT-1"])
      assert.are.same({ false, false }, zoneState.laneSlots["W1-B1"])
    end)
  end)
end)
