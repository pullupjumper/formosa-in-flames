---@diagnostic disable: need-check-nil, assign-type-mismatch, cast-local-type, param-type-mismatch, inject-field
-- LandingOps Coordinator Unit Tests
---@diagnostic disable: undefined-field, inject-field
local Coordinator = require("src.modules.landingOps.coordinator")
local Utils = require("src.utils.utils")
local GameUtils = require("src.utils.gameUtils")
local Logger = require("src.utils.logger")
local ShipMovement = require("src.modules.landingOps.shipMovement")
local AmphibiousLogistics = require("src.modules.landingOps.amphibiousLogistics")
local AmphibiousAssault = require("src.modules.landingOps.amphibiousAssault")
local SecondWaveUnloading = require("src.modules.landingOps.secondWaveUnloading")
local MineClearing = require("src.modules.landingOps.mineClearing")
local AssaultBoat = require("src.modules.landingOps.assaultBoat")
local ObstacleClearing = require("src.modules.landingOps.obstacleClearing")
local Hovercraft = require("src.modules.landingOps.hovercraft")
local MissileSystem = require("src.modules.missileSystem.init")
local StrikePlanner = require("src.modules.strikePlanner.init")
local constants = require("src.core.constants")

describe("LandingOps Coordinator", function()
  ---@type luassert.spy[]
  local activeStubs
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
    trackStub(stub(Logger, "log"))
    trackStub(stub(Logger, "warn"))
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

  ---Create an operational zone descriptor
  ---@param overrides? table
  ---@return table
  local function makeZone(overrides)
    local zone = {
      name = "Taoyuan",
      arrivalThreshold = 1,
      lstAnchorageArea = { "RP-LST-1", "RP-LST-2" },
      anchorageArea = { "RP-ANC-1", "RP-ANC-2" },
    }
    if overrides then
      for k, v in pairs(overrides) do
        zone[k] = v
      end
    end
    return zone
  end

  ---Create an operation descriptor
  ---@param overrides? table
  ---@return table
  local function makeOperation(overrides)
    local operation = {
      name = "Taoyuan",
      airLandingZone = { "RP-AIR-1", "RP-AIR-2" },
      contactThreshold = 2,
      sagNames = { "SAG Alpha" },
    }
    if overrides then
      for k, v in pairs(overrides) do
        operation[k] = v
      end
    end
    return operation
  end

  ---Create a zone state entry
  ---@param overrides? table
  ---@return table
  local function makeZoneState(overrides)
    local zoneState = {
      phase = constants.AMPHIBIOUS_PHASES.MOVING,
      amphibiousAssaultStartTime = nil,
      airlandingMissionStartTime = nil,
    }
    if overrides then
      for k, v in pairs(overrides) do
        zoneState[k] = v
      end
    end
    return zoneState
  end

  ---Create a global config structure
  ---@param overrides? table
  ---@return table
  local function makeConfig(overrides)
    local config = {
      red = {
        amphibOps = {
          operationalZones = { makeZone() },
          operations = { makeOperation() },
          periodSec = 3600,
          sags = { ["SAG Alpha"] = { groupName = "SAG Alpha" } },
          transportAircraft = { { guid = "TA-001", name = "Transport 1" } },
        },
        triggers = {
          amphibiousOps = { startTime = "2026-04-03 00:00:00" },
        },
        recon = {
          templates = {
            GJ11_RECON = {
              course = { { latitude = 25.0, longitude = 121.0 } },
              speed = 400,
            },
          },
        },
      },
    }
    if overrides then
      for k, v in pairs(overrides) do
        config[k] = v
      end
    end
    return config
  end

  ---Create a landing operations state slice (amphibOps, recon, ground)
  ---@param overrides? table
  ---@return table
  local function makeLandingState(overrides)
    local landingState = {
      amphibOps = {
        zoneStates = {
          Taoyuan = makeZoneState(),
        },
      },
      recon = {
        queue = {
          {
            type = "satellite",
            reconObjectiveId = "FIXED_SITE_TARGETING",
            endTime = "1970-01-03 15:03:20",
          },
        },
      },
    }
    if overrides then
      for k, v in pairs(overrides) do
        landingState[k] = v
      end
    end
    return landingState
  end

  ---Create an anchorage query result
  ---@param overrides? table
  ---@return table
  local function makeAnchorageResult(overrides)
    local result = {
      units = { { guid = "SHIP-001" }, { guid = "SHIP-002" } },
      isUnitMoving = false,
    }
    if overrides then
      for k, v in pairs(overrides) do
        result[k] = v
      end
    end
    return result
  end

  ---Create a contact list
  ---@param overrides? table
  ---@return table
  local function makeContacts(overrides)
    local contacts = {
      { guid = "CONTACT-001" },
    }
    if overrides then
      for k, v in pairs(overrides) do
        contacts[k] = v
      end
    end
    return contacts
  end

  ---Create a filtered ships list
  ---@param overrides? table
  ---@return table
  local function makeFilteredShips(overrides)
    local ships = {
      { guid = "SHIP-001" },
      { guid = "SHIP-002" },
    }
    if overrides then
      for k, v in pairs(overrides) do
        ships[k] = v
      end
    end
    return ships
  end

  -- ============================================================================
  -- process
  -- ============================================================================

  describe("process", function()
    local stubMoveToStagingArea
    local stubIsAfterStartTime
    local stubGetUnitsInAnchorageArea
    local stubGetCount
    local stubCreateCargoMissions
    local stubTransferAndAssign
    local stubTransferTransportAircraft
    local stubCalculatePathDistanceAndTime
    local stubCountContactsInArea
    local stubSetLandingMissionStartTime
    local stubSetCoursesForLSTs
    local stubCountUnitsInEachArea
    local stubStartSecondWaveUnloading
    local stubRetransferCargos
    local stubAddReconEntry
    local stubStartMineClearing
    local stubUpdateMineClearing
    local stubPairBoats
    local stubLaunchBoats
    local stubUpdateBoats
    local stubStartObstacleClearing
    local stubUpdateObstacleClearing
    local stubLaunchHovercraft
    local stubUpdateHovercraft

    before_each(function()
      stubStartMineClearing = trackStub(stub(MineClearing, "startMineClearing").returns(true))
      stubUpdateMineClearing = trackStub(stub(MineClearing, "updateMineClearing").returns(false))
      stubPairBoats = trackStub(stub(AssaultBoat, "pairBoats").returns(true))
      stubLaunchBoats = trackStub(stub(AssaultBoat, "launchBoats"))
      stubUpdateBoats = trackStub(stub(AssaultBoat, "updateBoats").returns(false))
      stubStartObstacleClearing = trackStub(stub(ObstacleClearing, "startObstacleClearing").returns(true))
      stubUpdateObstacleClearing = trackStub(stub(ObstacleClearing, "updateObstacleClearing").returns(false))
      stubLaunchHovercraft = trackStub(stub(Hovercraft, "launchHovercraft"))
      stubUpdateHovercraft = trackStub(stub(Hovercraft, "updateHovercraft"))
      stubMoveToStagingArea = trackStub(stub(ShipMovement, "moveToStagingArea").returns(false))
      stubIsAfterStartTime = trackStub(stub(GameUtils, "isAfterStartTime").returns(false))
      stubGetUnitsInAnchorageArea = trackStub(stub(AmphibiousLogistics, "getUnitsInAnchorageArea")
        .returns(makeAnchorageResult()))
      stubGetCount = trackStub(stub(Utils, "getCount").returns(0))
      stubCreateCargoMissions = trackStub(stub(AmphibiousLogistics, "createCargoMissions").returns(true))
      stubTransferAndAssign = trackStub(stub(AmphibiousLogistics, "transferAndAssign").returns(true))
      stubTransferTransportAircraft = trackStub(stub(AmphibiousLogistics, "transferAndAssignTransportAircraft"))
      stubCalculatePathDistanceAndTime = trackStub(stub(GameUtils, "calculatePathDistanceAndTime").returns(0, 600))
      stubCountContactsInArea = trackStub(stub(AmphibiousAssault, "countContactsInArea").returns(99))
      stubSetLandingMissionStartTime = trackStub(stub(AmphibiousAssault, "setLandingMissionStartTime").returns(true))
      stubSetCoursesForLSTs = trackStub(stub(AmphibiousAssault, "setCoursesForLSTs").returns(true))
      stubCountUnitsInEachArea = trackStub(stub(AmphibiousAssault, "countUnitsInEachArea").returns({}))
      stubStartSecondWaveUnloading = trackStub(stub(SecondWaveUnloading, "startSecondWaveUnloading").returns(true))
      stubRetransferCargos = trackStub(stub(AmphibiousLogistics, "retransferCargos").returns(true))
      stubAddReconEntry = trackStub(stub(StrikePlanner, "addReconEntry"))
    end)

    -- Positive: advances moving zones into arrival waiting state
    it("should move a zone from MOVING to WAITING_ARRIVAL when staging movement completes", function()
      local config = makeConfig()
      local landingState = makeLandingState()
      landingState.amphibOps.calculationResult = { Taoyuan = { name = "Taoyuan", result = {} } }

      landingState.amphibOps.zoneStates.Taoyuan.phase = constants.AMPHIBIOUS_PHASES.MOVING
      stubIsAfterStartTime.returns(true)
      stubMoveToStagingArea.returns(true)

      Coordinator.process(config, landingState, { contacts = makeContacts(), currentTime = 1000, filteredShips = makeFilteredShips() })

      assert.are.equal(constants.AMPHIBIOUS_PHASES.WAITING_ARRIVAL, landingState.amphibOps.zoneStates.Taoyuan.phase)
      assert.stub(stubMoveToStagingArea).was.called(1)
      assert.are.same(landingState.amphibOps.calculationResult, stubMoveToStagingArea.calls[1].vals[2])
    end)

    -- Positive: performs arrival logistics and Taoyuan temporary setup
    it("should queue the GJ-11 recon entry after Taoyuan arrival logistics succeeds", function()
      local config = makeConfig()
      local landingState = makeLandingState()

      landingState.amphibOps.zoneStates.Taoyuan.phase = constants.AMPHIBIOUS_PHASES.WAITING_ARRIVAL
      stubGetCount.returns(2)

      Coordinator.process(config, landingState, { contacts = makeContacts(), currentTime = 1000, filteredShips = makeFilteredShips() })

      assert.are.equal(constants.AMPHIBIOUS_PHASES.WAITING_ASSAULT, landingState.amphibOps.zoneStates.Taoyuan.phase)
      assert.are.equal(1000, landingState.amphibOps.zoneStates.Taoyuan.amphibiousAssaultStartTime)
      assert.stub(stubCreateCargoMissions).was.called(1)
      assert.stub(stubTransferAndAssign).was.called(1)
      assert.stub(stubTransferTransportAircraft).was.called(1)
      assert.stub(stubAddReconEntry).was.called_with(landingState.recon, config.red.recon.templates.GJ11_RECON)
    end)

    -- Negative: non-Taoyuan zones skip transport-aircraft transfer and recon insertion
    it("should not run Taoyuan temporary setup for a non-Taoyuan zone", function()
      local config = makeConfig()
      config.red.amphibOps.operationalZones = { makeZone({ name = "Tainan" }) }
      config.red.amphibOps.operations = { makeOperation({ name = "Tainan" }) }
      local landingState = makeLandingState()
      landingState.amphibOps.zoneStates = {
        Tainan = makeZoneState({ phase = constants.AMPHIBIOUS_PHASES.WAITING_ARRIVAL }),
      }
      stubGetCount.returns(2)

      Coordinator.process(config, landingState, { contacts = makeContacts(), currentTime = 1000, filteredShips = makeFilteredShips() })

      assert.are.equal(constants.AMPHIBIOUS_PHASES.WAITING_ASSAULT, landingState.amphibOps.zoneStates.Tainan.phase)
      assert.stub(stubTransferTransportAircraft).was_not.called()
      assert.stub(stubAddReconEntry).was_not.called()
    end)

    -- Positive: assault launch starts mine clearing and helicopter missions only
    it("should move a zone from WAITING_ASSAULT to MINE_CLEARING when assault launches", function()
      local config = makeConfig()
      local landingState = makeLandingState()

      landingState.amphibOps.zoneStates.Taoyuan = makeZoneState({
        phase = constants.AMPHIBIOUS_PHASES.WAITING_ASSAULT,
        amphibiousAssaultStartTime = 900,
      })
      stubCountContactsInArea.returns(1)

      Coordinator.process(config, landingState, { contacts = makeContacts(), currentTime = 1000, filteredShips = makeFilteredShips() })

      assert.are.equal(constants.AMPHIBIOUS_PHASES.MINE_CLEARING, landingState.amphibOps.zoneStates.Taoyuan.phase)
      assert.stub(stubStartMineClearing).was.called(1)
      assert.are.same({ "transportHelicopter", "attackHelicopter" }, stubSetLandingMissionStartTime.calls[1].vals[3])
      assert.stub(stubSetCoursesForLSTs).was_not.called()
    end)

    -- Negative: missing lane reference points keep the zone waiting
    it("should stay in WAITING_ASSAULT when mine clearing cannot start", function()
      local config = makeConfig()
      local landingState = makeLandingState()
      landingState.amphibOps.zoneStates.Taoyuan = makeZoneState({
        phase = constants.AMPHIBIOUS_PHASES.WAITING_ASSAULT,
        amphibiousAssaultStartTime = 900,
      })
      stubCountContactsInArea.returns(1)
      stubStartMineClearing.returns(false)

      Coordinator.process(config, landingState, { contacts = makeContacts(), currentTime = 1000, filteredShips = makeFilteredShips() })

      assert.are.equal(constants.AMPHIBIOUS_PHASES.WAITING_ASSAULT, landingState.amphibOps.zoneStates.Taoyuan.phase)
      assert.stub(stubSetLandingMissionStartTime).was_not.called()
    end)

    -- Negative: sweepers still working keep LSTs in the anchorage
    it("should keep MINE_CLEARING and LSTs anchored while sweepers are working", function()
      local config = makeConfig()
      local landingState = makeLandingState()
      landingState.amphibOps.zoneStates.Taoyuan.phase = constants.AMPHIBIOUS_PHASES.MINE_CLEARING

      Coordinator.process(config, landingState, { contacts = makeContacts(), currentTime = 1000, filteredShips = makeFilteredShips() })

      assert.are.equal(constants.AMPHIBIOUS_PHASES.MINE_CLEARING, landingState.amphibOps.zoneStates.Taoyuan.phase)
      assert.stub(stubSetCoursesForLSTs).was_not.called()
    end)

    -- Positive: the full assault chain advances one phase per completed step
    it("should advance MINE_CLEARING through ASSAULT_LANDING as each step completes", function()
      local config = makeConfig()
      local landingState = makeLandingState()
      local zoneState = landingState.amphibOps.zoneStates.Taoyuan
      zoneState.phase = constants.AMPHIBIOUS_PHASES.MINE_CLEARING
      stubUpdateMineClearing.returns(true)
      stubUpdateBoats.returns(true)
      stubUpdateObstacleClearing.returns(true)

      Coordinator.process(config, landingState, { contacts = makeContacts(), currentTime = 1000, filteredShips = makeFilteredShips() })

      assert.are.equal(constants.AMPHIBIOUS_PHASES.ASSAULT_LANDING, zoneState.phase)
      assert.stub(stubPairBoats).was.called(1)
      assert.stub(stubSetCoursesForLSTs).was.called(1)
      assert.stub(stubLaunchBoats).was.called(1)
      assert.stub(stubStartObstacleClearing).was.called(1)
      assert.stub(stubLaunchHovercraft).was.called(1)
    end)

    -- Negative: boats still under way hold the zone in BOAT_ASSAULT
    it("should keep BOAT_ASSAULT while boats are under way", function()
      local config = makeConfig()
      local landingState = makeLandingState()
      landingState.amphibOps.zoneStates.Taoyuan.phase = constants.AMPHIBIOUS_PHASES.BOAT_ASSAULT

      Coordinator.process(config, landingState, { contacts = makeContacts(), currentTime = 1000, filteredShips = makeFilteredShips() })

      assert.are.equal(constants.AMPHIBIOUS_PHASES.BOAT_ASSAULT, landingState.amphibOps.zoneStates.Taoyuan.phase)
      assert.stub(stubLaunchBoats).was.called(1)
      assert.stub(stubStartObstacleClearing).was_not.called()
      assert.stub(stubLaunchHovercraft).was_not.called()
    end)

    -- Positive: beachhead moves assault landing on to admin unloading and then completion
    it("should move ASSAULT_LANDING to COMPLETED via WAITING_ADMIN_UNLOADING when beachhead exists", function()
      local config = makeConfig()
      local landingState = makeLandingState()
      landingState.amphibOps.barges = { ["BARGE-001"] = { guid = "BARGE-001", roros = {} } }

      landingState.amphibOps.zoneStates.Taoyuan.phase = constants.AMPHIBIOUS_PHASES.ASSAULT_LANDING
      stubCountUnitsInEachArea.returns({
        Taoyuan = {
          ["ZBD-05"] = 1,
        },
      })

      Coordinator.process(config, landingState, { contacts = makeContacts(), currentTime = 1000, filteredShips = makeFilteredShips() })

      assert.are.equal(constants.AMPHIBIOUS_PHASES.COMPLETED, landingState.amphibOps.zoneStates.Taoyuan.phase)
      assert.stub(stubStartSecondWaveUnloading).was.called(1)
      assert.are.same(landingState.amphibOps.barges, stubStartSecondWaveUnloading.calls[1].vals[2])
      assert.stub(stubUpdateHovercraft).was.called(1)
    end)

    -- Negative: no beachhead keeps the assault landing going
    it("should stay in ASSAULT_LANDING without a beachhead", function()
      local config = makeConfig()
      local landingState = makeLandingState()
      landingState.amphibOps.zoneStates.Taoyuan.phase = constants.AMPHIBIOUS_PHASES.ASSAULT_LANDING
      stubCountUnitsInEachArea.returns({ Taoyuan = { ["ZBD-05"] = 0 } })

      Coordinator.process(config, landingState, { contacts = makeContacts(), currentTime = 1000, filteredShips = makeFilteredShips() })

      assert.are.equal(constants.AMPHIBIOUS_PHASES.ASSAULT_LANDING, landingState.amphibOps.zoneStates.Taoyuan.phase)
      assert.stub(stubStartSecondWaveUnloading).was_not.called()
    end)

    -- Negative: logs an error when zone operation mapping is missing
    it("should log an error when no matching operation exists for a zone", function()
      local config = makeConfig({
        red = {
          amphibOps = {
            operationalZones = { makeZone({ name = "Kaohsiung" }) },
            operations = { makeOperation({ name = "Taoyuan" }) },
            periodSec = 3600,
            sags = { ["SAG Alpha"] = { groupName = "SAG Alpha" } },
            transportAircraft = {},
          },
          recon = {
            templates = {
              GJ11_RECON = {
                course = { { latitude = 25.0, longitude = 121.0 } },
                speed = 400,
              },
            },
          },
        },
      })
      local landingState = makeLandingState({
        amphibOps = {
          zoneStates = {
            Kaohsiung = makeZoneState(),
          },
        },
        recon = {
          queue = {},
        },
      })

      Coordinator.process(config, landingState, { contacts = makeContacts(), currentTime = 1000, filteredShips = makeFilteredShips() })

      assert.stub(errorStub).was.called(1)
      assert.stub(stubMoveToStagingArea).was_not.called()
    end)

    -- Boundary: triggers cargo retransfer exactly at the two-hour threshold
    it("should retransfer cargos when airlanding mission has reached the two-hour threshold", function()
      local config = makeConfig()
      local landingState = makeLandingState()

      landingState.amphibOps.zoneStates.Taoyuan = makeZoneState({
        phase = constants.AMPHIBIOUS_PHASES.COMPLETED,
        airlandingMissionStartTime = 100,
      })

      Coordinator.process(config, landingState, { contacts = makeContacts(), currentTime = 7300, filteredShips = makeFilteredShips() })

      assert.are.equal(7300, landingState.amphibOps.zoneStates.Taoyuan.airlandingMissionStartTime)
      assert.stub(stubRetransferCargos).was.called(1)
    end)

    -- ============================================================================
    -- process: fire support gate
    -- ============================================================================

    -- Zone phases below stay put under the default stubs (not past start time, no arrivals,
    -- enemy contacts above threshold, no beachhead), so only the gate changes state.
    describe("fire support gate", function()
      ---@param totalPercentage number
      ---@return SBJ__AmmoInventoryResult
      local function makeReport(totalPercentage)
        return {
          firing   = { current = 0, max = 0, percentage = 0 },
          resupply = { current = 0, max = 0, percentage = 0 },
          ammo     = { current = 0, max = 0, percentage = 0 },
          total    = { current = 0, max = 0, percentage = totalPercentage },
        }
      end

      ---@param overrides? table
      local function makeGateConfig(overrides)
        local cfg = makeConfig()
        cfg.red.amphibOps.fireSupportHoldThreshold = 50
        if overrides then
          for k, v in pairs(overrides) do cfg.red.amphibOps[k] = v end
        end
        return cfg
      end

      ---@param overrides? table
      local function makeGateLandingState(overrides)
        local landingState = makeLandingState()
        landingState.ground = { srbm = { firingUnits = {}, resupplyUnits = {}, ammunitions = {} } }
        if overrides then
          for k, v in pairs(overrides) do landingState.amphibOps[k] = v end
        end
        return landingState
      end

      -- Positive: HOLD activates when ammo low and at least one zone has not arrived
      it("should set fireSupportOnHold true when ammo below threshold and zones not all arrived", function()
        local cfg = makeGateConfig()
        local landingState = makeGateLandingState()
        landingState.amphibOps.zoneStates.Taoyuan = makeZoneState({ phase = constants.AMPHIBIOUS_PHASES.MOVING })
        trackStub(stub(MissileSystem, "getAmmoInventory").returns(makeReport(40)))

        Coordinator.process(cfg, landingState, { contacts = makeContacts(), currentTime = 1000, filteredShips = makeFilteredShips() })

        assert.is_true(landingState.amphibOps.fireSupportOnHold)
      end)

      -- Negative: HOLD does not activate when ammo above threshold
      it("should not set fireSupportOnHold when ammo at or above threshold", function()
        local cfg = makeGateConfig()
        local landingState = makeGateLandingState()
        landingState.amphibOps.zoneStates.Taoyuan = makeZoneState({ phase = constants.AMPHIBIOUS_PHASES.MOVING })
        trackStub(stub(MissileSystem, "getAmmoInventory").returns(makeReport(50)))

        Coordinator.process(cfg, landingState, { contacts = makeContacts(), currentTime = 1000, filteredShips = makeFilteredShips() })

        assert.is_not_true(landingState.amphibOps.fireSupportOnHold)
      end)

      -- Positive: RESUME releases hold once all zones reach WAITING_ASSAULT or later
      it("should clear fireSupportOnHold once all zones reach WAITING_ASSAULT", function()
        local cfg = makeGateConfig()
        cfg.red.amphibOps.operationalZones = { makeZone({ name = "Taoyuan" }), makeZone({ name = "Tainan" }) }
        cfg.red.amphibOps.operations = { makeOperation({ name = "Taoyuan" }), makeOperation({ name = "Tainan" }) }
        local landingState = makeGateLandingState()
        landingState.amphibOps.fireSupportOnHold = true
        landingState.amphibOps.zoneStates = {
          Taoyuan = makeZoneState({ phase = constants.AMPHIBIOUS_PHASES.WAITING_ASSAULT }),
          Tainan  = makeZoneState({ phase = constants.AMPHIBIOUS_PHASES.WAITING_ADMIN_UNLOADING }),
        }

        Coordinator.process(cfg, landingState, { contacts = makeContacts(), currentTime = 1000, filteredShips = makeFilteredShips() })

        assert.is_false(landingState.amphibOps.fireSupportOnHold)
      end)

      -- Negative: RESUME requires ALL zones; one straggler keeps hold engaged
      it("should keep fireSupportOnHold when one zone still in WAITING_ARRIVAL", function()
        local cfg = makeGateConfig()
        cfg.red.amphibOps.operationalZones = { makeZone({ name = "Taoyuan" }), makeZone({ name = "Tainan" }) }
        cfg.red.amphibOps.operations = { makeOperation({ name = "Taoyuan" }), makeOperation({ name = "Tainan" }) }
        local landingState = makeGateLandingState()
        landingState.amphibOps.fireSupportOnHold = true
        landingState.amphibOps.zoneStates = {
          Taoyuan = makeZoneState({ phase = constants.AMPHIBIOUS_PHASES.WAITING_ASSAULT }),
          Tainan  = makeZoneState({ phase = constants.AMPHIBIOUS_PHASES.WAITING_ARRIVAL }),
        }
        trackStub(stub(MissileSystem, "getAmmoInventory").returns(makeReport(40)))

        Coordinator.process(cfg, landingState, { contacts = makeContacts(), currentTime = 1000, filteredShips = makeFilteredShips() })

        assert.is_true(landingState.amphibOps.fireSupportOnHold)
      end)

      -- Boundary: gate must not query SRBM ammo while already on hold (saves a game-state read)
      it("should not call getAmmoInventory when already on hold", function()
        local cfg = makeGateConfig()
        local landingState = makeGateLandingState()
        landingState.amphibOps.fireSupportOnHold = true
        landingState.amphibOps.zoneStates.Taoyuan = makeZoneState({ phase = constants.AMPHIBIOUS_PHASES.MOVING })
        local invStub = trackStub(stub(MissileSystem, "getAmmoInventory"))

        Coordinator.process(cfg, landingState, { contacts = makeContacts(), currentTime = 1000, filteredShips = makeFilteredShips() })

        assert.stub(invStub).was_not.called()
      end)

      -- Boundary: defensive guard when SRBM context is absent (e.g., a landing state without ground forces)
      it("should not error when ground.srbm context is missing", function()
        local cfg = makeGateConfig()
        local landingState = makeGateLandingState()
        landingState.ground = nil
        landingState.amphibOps.zoneStates.Taoyuan = makeZoneState({ phase = constants.AMPHIBIOUS_PHASES.MOVING })

        assert.has_no.errors(function()
          Coordinator.process(cfg, landingState, { contacts = makeContacts(), currentTime = 1000, filteredShips = makeFilteredShips() })
        end)
        assert.is_not_true(landingState.amphibOps.fireSupportOnHold)
      end)
    end)
  end)
end)
