-- LandingOps Init Unit Tests
---@diagnostic disable: undefined-field
local LandingOps = require("src.modules.landingOps.init")
local GameApi = require("src.utils.gameApi")
local ShipMovement = require("src.modules.landingOps.shipMovement")
local Coordinator = require("src.modules.landingOps.coordinator")
local AmphibiousAssault = require("src.modules.landingOps.amphibiousAssault")
local SecondWaveUnloading = require("src.modules.landingOps.secondWaveUnloading")
local AttackManager = require("src.modules.attackManager")
local Utils = require("src.utils.utils")
local constants = require("src.core.constants")

describe("LandingOps", function()
  local activeStubs

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

  ---Create a ship unit with sensible defaults
  ---@param overrides? table
  ---@return table
  local function makeShip(overrides)
    local ship = {
      guid = "SHIP-001",
      name = "Ship",
      side = constants.SIDES.ENEMY,
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

  -- ============================================================================
  -- init
  -- ============================================================================

  describe("init", function()
    -- Positive: delegates destination pre-calculation to ShipMovement
    it("should initialize landing operations by calculating destinations", function()
      local saveData = {
        c = {
          amphibOps = {
            calculationResult = {},
          },
        },
      }
      local cfg = { operations = {} }
      local stubCalc = trackStub(stub(ShipMovement, "calculateDestination"))

      LandingOps.init(cfg, saveData)

      assert.stub(stubCalc).was.called_with(cfg, saveData.c.amphibOps.calculationResult)
    end)
  end)

  -- ============================================================================
  -- process
  -- ============================================================================

  describe("process", function()
    -- Positive: delegates event processing to Coordinator
    it("should forward process calls to coordinator", function()
      local stubProcess = trackStub(stub(Coordinator, "process"))
      local config = {}
      local saveData = {}
      local contacts = {}
      local currentTime = 100
      local filteredShips = {}

      LandingOps.process(config, saveData, contacts, currentTime, filteredShips)

      assert.stub(stubProcess).was.called_with(config, saveData, contacts, currentTime, filteredShips)
    end)
  end)

  -- ============================================================================
  -- launchACV
  -- ============================================================================

  describe("launchACV", function()
    -- Positive: launches ACV using derived zone settings
    it("should launch ACV when ship is a valid ferry or LST in a valid zone", function()
      local ship = makeShip()
      local zone = makeZone()
      local stubIsFerry = trackStub(stub(AmphibiousAssault, "isFerryOrLST").returns(true))
      local stubGetZone = trackStub(stub(AmphibiousAssault, "getShipZone").returns(zone))
      local stubLaunch = trackStub(stub(AmphibiousAssault, "launchACV").returns(2))

      local result = LandingOps.launchACV({ operationalZones = { zone } }, ship)

      assert.is_true(result)
      assert.stub(stubIsFerry).was.called_with(ship)
      assert.stub(stubGetZone).was.called_with({ operationalZones = { zone } }, ship)
      assert.stub(stubLaunch).was.called_with({
        ship = ship,
        num = 5,
        bearing = 180,
        distance = 0.5,
        speed = 20,
        destination = zone.acv.destination
      })
    end)

    -- Negative: exits when ship type is not eligible
    it("should return false when ship is not a ferry or LST", function()
      local ship = makeShip()
      local stubIsFerry = trackStub(stub(AmphibiousAssault, "isFerryOrLST").returns(false))
      local stubGetZone = trackStub(stub(AmphibiousAssault, "getShipZone"))

      local result = LandingOps.launchACV({}, ship)

      assert.is_false(result)
      assert.stub(stubIsFerry).was.called_with(ship)
      assert.stub(stubGetZone).was_not.called()
    end)

    -- Boundary: hosts and RTBs when no ACV can be launched
    it("should host the ship back to base and RTB when launch count is zero", function()
      local wasRTB = false
      local ship = makeShip({
        RTB = function(_, force)
          wasRTB = force
        end,
      })
      local zone = makeZone()
      local stubIsFerry = trackStub(stub(AmphibiousAssault, "isFerryOrLST").returns(true))
      local stubGetZone = trackStub(stub(AmphibiousAssault, "getShipZone").returns(zone))
      local stubLaunch = trackStub(stub(AmphibiousAssault, "launchACV").returns(0))
      local stubHost = trackStub(stub(GameApi, "ScenEdit_HostUnitToParent").returns(true))

      local result = LandingOps.launchACV({}, ship)

      assert.is_true(result)
      assert.is_true(wasRTB)
      assert.stub(stubIsFerry).was.called_with(ship)
      assert.stub(stubGetZone).was.called_with({}, ship)
      assert.stub(stubLaunch).was.called(1)
      assert.stub(stubHost).was.called_with({
        HostedUnitNameOrID = ship.guid,
        SelectedBaseNameOrID = zone.baseGUID
      })
    end)
  end)

  -- ============================================================================
  -- offloadVehicles
  -- ============================================================================

  describe("offloadVehicles", function()
    -- Positive: creates a bridge for barges without one
    it("should create a bridge and stop the barge when no bridge exists", function()
      local ship = makeShip({ name = "Barge" })
      local saveData = {
        c = {
          amphibOps = {
            barges = {
              [ship.guid] = {
                roros = {},
              },
            },
          },
        },
      }
      local stubHasBridge = trackStub(stub(SecondWaveUnloading, "hasExtendedBridge").returns(false))
      local stubIsBridgeDestroyed = trackStub(stub(SecondWaveUnloading, "isBridgeDestroyed").returns(true))
      local stubAddUnit = trackStub(stub(GameApi, "ScenEdit_AddUnit").returns({ guid = "BRIDGE-001" }))

      local result = LandingOps.offloadVehicles({}, saveData, ship)

      assert.is_true(result)
      assert.is_nil(ship.course)
      assert.are.equal(0, ship.manualSpeed)
      assert.is_true(ship.holdposition)
      assert.are.equal("BRIDGE-001", saveData.c.amphibOps.barges[ship.guid].bridgeGUID)
      assert.stub(stubHasBridge).was.called(1)
      assert.stub(stubIsBridgeDestroyed).was.called(1)
      assert.stub(stubAddUnit).was.called(1)
    end)

    -- Positive: offloads vehicles for RORO units paired with a barge
    it("should offload vehicles for paired RORO units when the barge bridge is active", function()
      local ship = makeShip({ name = "Barge", guid = "BARGE-001" })
      local roro = makeShip({ name = "RORO", guid = "RORO-001" })
      local zone = makeZone()
      local saveData = {
        c = {
          amphibOps = {
            barges = {
              [ship.guid] = {
                bridgeGUID = "BRIDGE-001",
                roros = { roro.guid },
              },
            },
          },
        },
      }
      local stubHasBridge = trackStub(stub(SecondWaveUnloading, "hasExtendedBridge").returns(true))
      local stubIsBridgeDestroyed = trackStub(stub(SecondWaveUnloading, "isBridgeDestroyed").returns(false))
      local stubGetUnit = trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(roro))
      local stubGetZone = trackStub(stub(SecondWaveUnloading, "getBargeROROZone").returns(zone))
      local stubOffload = trackStub(stub(SecondWaveUnloading, "offloadVehicles").returns(20))

      local result = LandingOps.offloadVehicles({ operationalZones = { zone } }, saveData, ship)

      assert.is_true(result)
      assert.stub(stubHasBridge).was.called_with(saveData, ship)
      assert.stub(stubIsBridgeDestroyed).was.called_with(saveData, ship)
      assert.stub(stubGetUnit).was.called_with(roro.guid)
      assert.stub(stubGetZone).was.called_with({ operationalZones = { zone } }, ship, roro)
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
      local saveData = {
        c = {
          amphibOps = {
            barges = {},
          },
        },
      }

      local result = LandingOps.offloadVehicles({}, saveData, ship)

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
      local stubGetCount = trackStub(stub(Utils, "getCount").invokes(function(items)
        return #items
      end))
      local stubSetDoctrine = trackStub(stub(GameApi, "ScenEdit_SetDoctrine"))
      local stubAttackContacts = trackStub(stub(AttackManager, "attackContacts"))

      local result = LandingOps.neutralizeAirlandingZone({
        sag = {
          ["SAG Alpha"] = {
            area = { "RP-SAG-1", "RP-SAG-2" },
          },
        },
      }, ship, contacts)

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
      local stubAttackContacts = trackStub(stub(AttackManager, "attackContacts"))

      local result = LandingOps.neutralizeAirlandingZone({ sag = {} }, ship, { makeContact() })

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
      local stubGetCount = trackStub(stub(Utils, "getCount").returns(0))
      local stubSetDoctrine = trackStub(stub(GameApi, "ScenEdit_SetDoctrine"))

      local result = LandingOps.neutralizeAirlandingZone({
        sag = {
          ["SAG Alpha"] = {
            area = { "RP-SAG-1", "RP-SAG-2" },
          },
        },
      }, ship, contacts)

      assert.is_false(result)
      assert.stub(stubGetCount).was.called(1)
      assert.stub(stubSetDoctrine).was_not.called()
    end)
  end)
end)
