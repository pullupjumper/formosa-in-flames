---@diagnostic disable: need-check-nil, assign-type-mismatch, cast-local-type, param-type-mismatch, inject-field
-- LandingOps Init Unit Tests
local LandingOps = require("src.modules.landingOps.init")
local GameApi = require("src.utils.gameApi")
local Logger = require("src.utils.logger")
local ShipMovement = require("src.modules.landingOps.shipMovement")
local Coordinator = require("src.modules.landingOps.coordinator")
local AmphibiousAssault = require("src.modules.landingOps.amphibiousAssault")
local MineClearing = require("src.modules.landingOps.mineClearing")
local SecondWaveUnloading = require("src.modules.landingOps.secondWaveUnloading")
local AttackManager = require("src.modules.attackManager")
local Utils = require("src.utils.utils")
local constants = require("src.core.constants")

describe("LandingOps", function()
  ---@type luassert.spy[]
  local activeStubs
  ---@type luassert.spy
  local logStub
  ---@type luassert.spy
  local errorStub
  ---Track and register test stub for automatic cleanup.
  ---@param s any
  ---@return luassert.spy
  local function trackStub(s)
    table.insert(activeStubs, s)
    return s
  end

  before_each(function()
    activeStubs = {}
    logStub = trackStub(stub(Logger, "log"))
    errorStub = trackStub(stub(Logger, "error"))
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

  ---Create a ship unit with sensible defaults
  ---@param overrides? table
  ---@return table
  local function makeShip(overrides)
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
  local function makeZone(overrides)
    local zone = {
      baseGUID = "BASE-001",
      acv = {
        bearing = 90,
        distance = 0.5,
        speed = 20,
        destination = { { latitude = 25.0, longitude = 121.0 } },
      },
    }
    if overrides then
      for k, v in pairs(overrides) do
        zone[k] = v
      end
    end
    return zone
  end

  ---Create a mock contact with sensible defaults
  ---@param overrides? table
  ---@return table
  local function makeContact(overrides)
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
  local function makeConfig(amphibOpsConfig)
    return { red = { amphibOps = amphibOpsConfig } }
  end

  ---Create save data holding China's amphibious state
  ---@param amphibOps table
  ---@return table
  local function makeSaveData(amphibOps)
    return { red = { amphibOps = amphibOps, recon = {}, ground = {} } }
  end

  -- ============================================================================
  -- init
  -- ============================================================================

  describe("init", function()
    -- Positive: delegates destination pre-calculation to ShipMovement
    it("should initialize landing operations by calculating destinations", function()
      local saveData = makeSaveData({ calculationResult = {} })
      local cfg = { zones = {}, formationSettings = {} }
      local stubCalc = trackStub(stub(ShipMovement, "calculateDestination"))
      local stubLay = trackStub(stub(MineClearing, "layMinefields"))

      LandingOps.init(makeConfig(cfg), saveData)

      assert.stub(stubCalc).was.called_with(cfg.zones, cfg.formationSettings, saveData.red.amphibOps.calculationResult)
      assert.stub(stubLay).was.called_with(cfg)
    end)
  end)

  -- ============================================================================
  -- process
  -- ============================================================================

  describe("process", function()
    -- Positive: the coordinator gets China's landing state and this tick's game snapshot
    it("should forward landing state, contacts, time and ships to coordinator", function()
      local stubProcess = trackStub(stub(Coordinator, "process"))
      local config = makeConfig({})
      local saveData = makeSaveData({ barges = { ["BARGE-001"] = { roros = {} } } })
      local contacts = { makeContact() }
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

    -- Negative: without contacts the tick stops before the coordinator runs
    it("should skip the coordinator when contacts are unavailable", function()
      local stubProcess = trackStub(stub(Coordinator, "process"))
      trackStub(stub(GameApi, "ScenEdit_GetContacts").returns(nil))

      LandingOps.process(makeConfig({}), makeSaveData({}))

      assert.stub(stubProcess).was_not.called()
    end)
  end)

  -- ============================================================================
  -- launchACV
  -- ============================================================================

  describe("launchACV", function()
    local ACV_WAVE = { capacity = { zbd05 = 112, ztd05 = 112 }, lossRatio = 0.3, holdSec = 1800 }

    ---@param phase string
    ---@return table saveData
    ---@return table zoneState
    local function makeZoneSaveData(phase)
      local zoneState = { phase = phase }
      return makeSaveData({ zoneStates = { ZoneAlpha = zoneState } }), zoneState
    end

    before_each(function()
      trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(1000))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(nil))
    end)

    -- Positive: launches ACVs with the wave quota once assault landing has started
    it("should launch ACVs with quota and a router when the zone is in ASSAULT_LANDING", function()
      local ship = makeShip()
      local zone = makeZone({ name = "ZoneAlpha" })
      local saveData, zoneState = makeZoneSaveData(constants.AMPHIBIOUS_PHASES.ASSAULT_LANDING)
      trackStub(stub(AmphibiousAssault, "isFerryOrLST").returns(true))
      trackStub(stub(AmphibiousAssault, "getShipZone").returns(zone))
      local stubLaunch = trackStub(stub(AmphibiousAssault, "launchACV")
        .returns({ count = 2, isEmpty = false, isPaused = false }))

      local result = LandingOps.launchACV(makeConfig({ tuning = { acvWave = ACV_WAVE, route = {} } }), saveData, ship)

      assert.is_true(result)
      local params = stubLaunch.calls[1].vals[1]
      assert.are.same(ship, params.ship)
      assert.are.equal(5, params.num)
      assert.are.equal(180, params.bearing)
      assert.are.same({ zbd05 = 112, ztd05 = 112 }, params.quota)
      assert.are.equal("function", type(params.routeACV))
      assert.is_not_nil(zoneState.acvGuids)
    end)

    -- Positive: without lanes the router counts the ACV and falls back to the zone destination
    it("should record the ACV and fall back to the zone destination when no lane is available", function()
      local zone = makeZone({ name = "ZoneAlpha" })
      local saveData, zoneState = makeZoneSaveData(constants.AMPHIBIOUS_PHASES.ASSAULT_LANDING)
      trackStub(stub(AmphibiousAssault, "isFerryOrLST").returns(true))
      trackStub(stub(AmphibiousAssault, "getShipZone").returns(zone))
      local course
      trackStub(stub(AmphibiousAssault, "launchACV").invokes(function(params)
        course = params.routeACV({ guid = "ACV-1", latitude = 25.0, longitude = 121.0 }, "zbd05")
        return { count = 1, isEmpty = false, isPaused = false }
      end))
      trackStub(stub(Logger, "warn"))

      LandingOps.launchACV(makeConfig({ tuning = { acvWave = ACV_WAVE, route = {} } }), saveData, makeShip())

      assert.are.same(zone.acv.destination, course)
      assert.are.same({ "ACV-1" }, zoneState.acvGuids.zbd05)
    end)

    -- Negative: nothing happens before assault landing
    it("should not launch before the zone reaches ASSAULT_LANDING", function()
      local zone = makeZone({ name = "ZoneAlpha" })
      local saveData = makeZoneSaveData(constants.AMPHIBIOUS_PHASES.OBSTACLE_CLEARING)
      trackStub(stub(AmphibiousAssault, "isFerryOrLST").returns(true))
      trackStub(stub(AmphibiousAssault, "getShipZone").returns(zone))
      local stubLaunch = trackStub(stub(AmphibiousAssault, "launchACV"))

      local result = LandingOps.launchACV(makeConfig({ tuning = { acvWave = ACV_WAVE, route = {} } }), saveData, makeShip())

      assert.is_false(result)
      assert.stub(stubLaunch).was_not.called()
    end)

    -- Negative: exits when ship type is not eligible
    it("should return false when ship is not a ferry or LST", function()
      local ship = makeShip()
      local stubIsFerry = trackStub(stub(AmphibiousAssault, "isFerryOrLST").returns(false))
      local stubGetZone = trackStub(stub(AmphibiousAssault, "getShipZone"))

      local result = LandingOps.launchACV(makeConfig({}), makeSaveData({}), ship)

      assert.is_false(result)
      assert.stub(stubIsFerry).was.called_with(ship)
      assert.stub(stubGetZone).was_not.called()
    end)

    -- Boundary: hosts and RTBs when the ship is empty
    it("should host the ship back to base and RTB when the ship is empty", function()
      local wasRTB = false
      local ship = makeShip({
        RTB = function(_, force)
          wasRTB = force
        end,
      })
      local zone = makeZone({ name = "ZoneAlpha" })
      local saveData = makeZoneSaveData(constants.AMPHIBIOUS_PHASES.COMPLETED)
      trackStub(stub(AmphibiousAssault, "isFerryOrLST").returns(true))
      trackStub(stub(AmphibiousAssault, "getShipZone").returns(zone))
      trackStub(stub(AmphibiousAssault, "launchACV").returns({ count = 0, isEmpty = true, isPaused = false }))
      local stubHost = trackStub(stub(GameApi, "ScenEdit_HostUnitToParent").returns(true))

      local result = LandingOps.launchACV(makeConfig({ tuning = { acvWave = ACV_WAVE, route = {} } }), saveData, ship)

      assert.is_true(result)
      assert.is_true(wasRTB)
      assert.stub(stubHost).was.called_with({
        HostedUnitNameOrID = ship.guid,
        SelectedBaseNameOrID = zone.baseGUID
      })
    end)

    -- Negative: a paused wave keeps the ship on station
    it("should not RTB the ship when the wave is paused", function()
      local wasRTB = false
      local ship = makeShip({ RTB = function() wasRTB = true end })
      local zone = makeZone({ name = "ZoneAlpha" })
      local saveData = makeZoneSaveData(constants.AMPHIBIOUS_PHASES.ASSAULT_LANDING)
      trackStub(stub(AmphibiousAssault, "isFerryOrLST").returns(true))
      trackStub(stub(AmphibiousAssault, "getShipZone").returns(zone))
      trackStub(stub(AmphibiousAssault, "launchACV").returns({ count = 0, isEmpty = false, isPaused = true }))
      local stubHost = trackStub(stub(GameApi, "ScenEdit_HostUnitToParent"))

      local result = LandingOps.launchACV(makeConfig({ tuning = { acvWave = ACV_WAVE, route = {} } }), saveData, ship)

      assert.is_true(result)
      assert.is_false(wasRTB)
      assert.stub(stubHost).was_not.called()
    end)
  end)

  -- ============================================================================
  -- offloadVehicles
  -- ============================================================================

  describe("offloadVehicles", function()
    -- Positive: creates a bridge for barges without one
    it("should create a bridge and stop the barge when no bridge exists", function()
      local ship = makeShip({ name = "Barge" })
      local saveData = makeSaveData({
        barges = {
          [ship.guid] = {
            roros = {},
          },
        },
      })
      local cfg = {}
      local stubHasBridge = trackStub(stub(SecondWaveUnloading, "hasExtendedBridge").returns(false))
      local stubIsBridgeDestroyed = trackStub(stub(SecondWaveUnloading, "isBridgeDestroyed").returns(true))
      local stubAddUnit = trackStub(stub(GameApi, "ScenEdit_AddUnit").returns({ guid = "BRIDGE-001" }))

      local result = LandingOps.offloadVehicles(makeConfig(cfg), saveData, ship)

      assert.is_true(result)
      assert.is_nil(ship.course)
      assert.are.equal(0, ship.manualSpeed)
      assert.is_true(ship.holdposition)
      assert.are.equal("BRIDGE-001", saveData.red.amphibOps.barges[ship.guid].bridgeGUID)
      assert.stub(stubHasBridge).was.called(1)
      assert.stub(stubIsBridgeDestroyed).was.called(1)
      assert.stub(stubAddUnit).was.called(1)
    end)

    -- Positive: offloads vehicles for RORO units paired with a barge
    it("should offload vehicles for paired RORO units when the barge bridge is active", function()
      local ship = makeShip({ name = "Barge", guid = "BARGE-001" })
      local roro = makeShip({ name = "RORO", guid = "RORO-001" })
      local zone = makeZone()
      local saveData = makeSaveData({
        barges = {
          [ship.guid] = {
            bridgeGUID = "BRIDGE-001",
            roros = { roro.guid },
          },
        },
      })
      local cfg = { zones = { zone } }
      local stubHasBridge = trackStub(stub(SecondWaveUnloading, "hasExtendedBridge").returns(true))
      local stubIsBridgeDestroyed = trackStub(stub(SecondWaveUnloading, "isBridgeDestroyed").returns(false))
      local stubGetUnit = trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(roro))
      local stubGetZone = trackStub(stub(SecondWaveUnloading, "getBargeROROZone").returns(zone))
      local stubOffload = trackStub(stub(SecondWaveUnloading, "offloadVehicles").returns(20))

      local result = LandingOps.offloadVehicles(makeConfig(cfg), saveData, ship)

      assert.is_true(result)
      assert.stub(stubHasBridge).was.called_with(saveData.red.amphibOps.barges, ship)
      assert.stub(stubIsBridgeDestroyed).was.called_with(saveData.red.amphibOps.barges, ship)
      assert.stub(stubGetUnit).was.called_with(roro.guid)
      assert.stub(stubGetZone).was.called_with({ zone }, ship, roro)
      assert.stub(stubOffload).was.called_with({
        ship = roro,
        num = 20,
        bearing = zone.acv.bearing + 90,
        distance = zone.acv.distance,
        firstDistance = 1
      })
    end)

    -- Boundary: stops a RORO ship in place without extra offload work
    it("should stop a RORO ship in place", function()
      local ship = makeShip({ name = "RORO" })
      local saveData = makeSaveData({ barges = {} })

      local result = LandingOps.offloadVehicles(makeConfig({}), saveData, ship)

      assert.is_true(result)
      assert.is_nil(ship.course)
      assert.are.equal(0, ship.manualSpeed)
      assert.is_true(ship.holdposition)
    end)
  end)

  -- ============================================================================
  -- neutralizeAirlandingZone
  -- ============================================================================

  describe("neutralizeAirlandingZone", function()
    -- Positive: sets doctrine and attacks filtered contacts for valid SAG destroyers
    it("should attack filtered mobile ground contacts for a valid Type 052D SAG ship", function()
      local ship = makeShip()
      local contacts = {
        makeContact({ guid = "C-1" }),
        makeContact({ guid = "C-2" }),
        makeContact({
          guid = "C-3",
          typed = constants.CONTACT_TYPES.AIR,
        }),
      }
      local cfg = {
        zones = {
          {
            sags = {
              { groupName = "SAG Alpha", area = { "RP-SAG-1", "RP-SAG-2" } },
            },
          },
        },
      }
      local stubGetCount = trackStub(stub(Utils, "getCount").invokes(function(items)
        return #items
      end))
      local stubSetDoctrine = trackStub(stub(GameApi, "ScenEdit_SetDoctrine"))
      local stubAttackContacts = trackStub(stub(AttackManager, "attackContacts"))
      trackStub(stub(GameApi, "ScenEdit_GetContacts").returns(contacts))

      local result = LandingOps.neutralizeAirlandingZone(makeConfig(cfg), ship)

      assert.is_true(result)
      assert.stub(stubGetCount).was.called(2)
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

    -- Negative: returns false when the ship is not a valid Type 052D SAG unit
    it("should return false for ships outside the supported SAG destroyer context", function()
      local ship = makeShip({ dbid = constants.PLATFORMS.TYPE_054A })
      local cfg = { zones = {} }

      local stubAttackContacts = trackStub(stub(AttackManager, "attackContacts"))

      local result = LandingOps.neutralizeAirlandingZone(makeConfig(cfg), ship)

      assert.is_false(result)
      assert.stub(stubAttackContacts).was_not.called()
    end)

    -- Boundary: returns false when no filtered contacts remain
    it("should return false when no mobile ground contacts remain after filtering", function()
      local ship = makeShip()
      local contacts = {
        makeContact({
          guid = "C-1",
          inArea = function() return false end,
        }),
      }
      local cfg = {
        zones = {
          {
            sags = {
              { groupName = "SAG Alpha", area = { "RP-SAG-1", "RP-SAG-2" } },
            },
          },
        },
      }
      local stubGetCount = trackStub(stub(Utils, "getCount").returns(0))
      local stubSetDoctrine = trackStub(stub(GameApi, "ScenEdit_SetDoctrine"))
      trackStub(stub(GameApi, "ScenEdit_GetContacts").returns(contacts))

      local result = LandingOps.neutralizeAirlandingZone(makeConfig(cfg), ship)

      assert.is_false(result)
      assert.stub(stubGetCount).was.called(1)
      assert.stub(stubSetDoctrine).was_not.called()
    end)
  end)
end)
