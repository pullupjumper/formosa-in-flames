---@diagnostic disable: need-check-nil, assign-type-mismatch, cast-local-type, param-type-mismatch, inject-field
-- LandingOps Coordinator Unit Tests
local Coordinator = require("src.modules.landingOps.coordinator")
local GameApi = require("src.utils.gameApi")
local Logger = require("src.utils.logger")
local ShipMovement = require("src.modules.landingOps.shipMovement")
local AmphibiousLogistics = require("src.modules.landingOps.amphibiousLogistics")
local AmphibiousAssault = require("src.modules.landingOps.amphibiousAssault")
local AdminOffloading = require("src.modules.landingOps.adminOffloading")
local MineClearing = require("src.modules.landingOps.mineClearing")
local AssaultBoat = require("src.modules.landingOps.assaultBoat")
local ObstacleClearing = require("src.modules.landingOps.obstacleClearing")
local HeliWave = require("src.modules.landingOps.heliWave")
local Hovercraft = require("src.modules.landingOps.hovercraft")
local MissileSystem = require("src.modules.missileSystem.init")
local StrikePlanner = require("src.modules.strikePlanner.init")
local constants = require("src.core.constants")
local StubTracker = require("spec.support.stubTracker")

describe("LandingOps Coordinator", function()
  ---@type luassert.spy
  local errorStub
  local trackStub = StubTracker.track

  before_each(function()
    trackStub(stub(Logger, "log"))
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
      name = "Taoyuan",
      movement = {
        arrivalThreshold = 1,
        holdingAreas = {
          deployLine = { "RP-LST-1", "RP-LST-2" },
          mothership = { "RP-ANC-1", "RP-ANC-2" },
        },
      },
      air = {
        contactThreshold = 2,
        transportHelicopter = { zone = { "RP-AIR-1", "RP-AIR-2" } },
      },
      sags = { { groupName = "SAG Alpha" } },
      landing = { beachheadVehicles = 10, acv = { capacity = { zbd05 = 4, ztd05 = 4 } } },
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

  ---Create a zone state entry
  ---@param overrides? table
  ---@return table
  local function buildZoneState(overrides)
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

  ---Fill the zone's first ACV wave up to the capacity set by buildZone
  ---@param zoneState table
  local function fillFirstAcvWave(zoneState)
    zoneState.acvGuids = {
      zbd05 = { "ZBD-1", "ZBD-2", "ZBD-3", "ZBD-4" },
      ztd05 = { "ZTD-1", "ZTD-2", "ZTD-3", "ZTD-4" },
    }
  end

  ---Create a global config structure
  ---@param overrides? table
  ---@return table
  local function buildConfig(overrides)
    local config = {
      red = {
        amphibOps = {
          zones = { buildZone() },
          periodSec = 3600,
          acvWave = { lossRatio = 0.3, holdSec = 300, hovercraftWaitSec = 300 },
          heliWave = { cargoReloadSec = 7200 },
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
  local function buildLandingState(overrides)
    local landingState = {
      amphibOps = {
        zoneStates = {
          Taoyuan = buildZoneState(),
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

  ---Create a holding-areas query result
  ---@param overrides? table
  ---@return table
  local function buildHoldingResult(overrides)
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
  local function buildContacts(overrides)
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
  local function buildFilteredShips(overrides)
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

  describe("process", function()
    -- Scenario clock readings: before and after the configured start time
    local BEFORE_START, AFTER_START = 0, 4102444800
    local stubMoveToStagingArea
    local stubCurrentTime
    local stubGetUnitsInHoldingAreas
    local stubTransfer
    local stubTransferTransportAircraft
    local stubCountContactsInArea
    local stubScheduleHeliWave, stubUpdateHeliWave
    local stubMoveToLaunchStations
    local stubCountUnitsInEachArea
    local stubStartAdminOffloading
    local stubTransferRemainingCargos
    local stubAddReconEntry
    local stubStartMineClearing
    local stubUpdateMineClearing
    local stubPairBoats
    local stubLaunchBoats
    local stubUpdateBoats
    local stubStartObstacleClearing
    local stubUpdateObstacleClearing
    local stubLaunchHovercraft
    local stubGetUnit
    local stubUpdateHovercraft
    local stubHasUnreleasedACV
    local stubHasUnlaunchedHovercraft
    local stubHasPendingBoats

    before_each(function()
      stubHasUnreleasedACV = trackStub(stub(AmphibiousAssault, "hasUnreleasedACV").returns(false))
      stubHasUnlaunchedHovercraft = trackStub(stub(Hovercraft, "hasUnlaunchedHovercraft").returns(false))
      stubHasPendingBoats = trackStub(stub(AssaultBoat, "hasPendingBoats").returns(false))
      stubStartMineClearing = trackStub(stub(MineClearing, "startMineClearing").returns(true))
      stubUpdateMineClearing = trackStub(stub(MineClearing, "updateMineClearing").returns(false))
      stubPairBoats = trackStub(stub(AssaultBoat, "pairBoats").returns(true))
      stubLaunchBoats = trackStub(stub(AssaultBoat, "launchBoats"))
      stubUpdateBoats = trackStub(stub(AssaultBoat, "updateBoats").returns(false))
      stubStartObstacleClearing = trackStub(stub(ObstacleClearing, "startObstacleClearing").returns(true))
      stubUpdateObstacleClearing = trackStub(stub(ObstacleClearing, "updateObstacleClearing").returns(false))
      stubLaunchHovercraft = trackStub(stub(Hovercraft, "launchHovercraft"))
      stubUpdateHovercraft = trackStub(stub(Hovercraft, "updateHovercraft"))
      stubGetUnit = trackStub(stub(GameApi, "ScenEdit_GetUnit").returns({ guid = "ACV" }))
      stubMoveToStagingArea = trackStub(stub(ShipMovement, "moveToHoldingAreas").returns(false))
      stubCurrentTime = trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(BEFORE_START))
      stubGetUnitsInHoldingAreas = trackStub(stub(AmphibiousLogistics, "getUnitsInHoldingAreas")
        .returns(buildHoldingResult({ units = {} })))
      stubTransfer = trackStub(stub(AmphibiousLogistics, "transfer").returns(true))
      stubTransferTransportAircraft = trackStub(stub(AmphibiousLogistics, "transferTransportAircraftCargo"))
      stubCountContactsInArea = trackStub(stub(AmphibiousAssault, "countContactsInArea").returns(99))
      stubScheduleHeliWave = trackStub(stub(HeliWave, "schedule"))
      stubUpdateHeliWave = trackStub(stub(HeliWave, "update"))
      stubMoveToLaunchStations = trackStub(stub(AmphibiousAssault, "moveToLaunchStations").returns(true))
      stubCountUnitsInEachArea = trackStub(stub(AmphibiousAssault, "countUnitsInEachArea").returns({}))
      stubStartAdminOffloading = trackStub(stub(AdminOffloading, "startAdminOffloading").returns(true))
      stubTransferRemainingCargos = trackStub(stub(AmphibiousLogistics, "transferRemainingCargos").returns(true))
      stubAddReconEntry = trackStub(stub(StrikePlanner, "addReconEntry"))
    end)

    it("should move a zone from MOVING to WAITING_ARRIVAL when staging movement completes", function()
      local config = buildConfig()
      local landingState = buildLandingState()
      landingState.amphibOps.calculationResult = { Taoyuan = { name = "Taoyuan", result = {} } }

      landingState.amphibOps.zoneStates.Taoyuan.phase = constants.AMPHIBIOUS_PHASES.MOVING
      stubCurrentTime.returns(AFTER_START)
      stubMoveToStagingArea.returns(true)

      Coordinator.process(config, landingState,
        { contacts = buildContacts(), currentTime = 1000, filteredShips = buildFilteredShips() })

      assert.are.equal(constants.AMPHIBIOUS_PHASES.WAITING_ARRIVAL, landingState.amphibOps.zoneStates.Taoyuan.phase)
      assert.stub(stubMoveToStagingArea).was.called(1)
      assert.are.same(landingState.amphibOps.calculationResult, stubMoveToStagingArea.calls[1].vals[2])
    end)

    it("should queue the zone's recon template after arrival logistics succeeds", function()
      local config = buildConfig()
      config.red.amphibOps.zones[1].air.reconTemplate = "GJ11_RECON"
      local landingState = buildLandingState()

      landingState.amphibOps.zoneStates.Taoyuan.phase = constants.AMPHIBIOUS_PHASES.WAITING_ARRIVAL
      stubGetUnitsInHoldingAreas.returns(buildHoldingResult())

      Coordinator.process(config, landingState,
        { contacts = buildContacts(), currentTime = 1000, filteredShips = buildFilteredShips() })

      assert.are.equal(constants.AMPHIBIOUS_PHASES.WAITING_ASSAULT, landingState.amphibOps.zoneStates.Taoyuan.phase)
      assert.are.equal(1000, landingState.amphibOps.zoneStates.Taoyuan.amphibiousAssaultStartTime)
      assert.stub(stubTransfer).was.called(1)
      assert.stub(stubAddReconEntry).was.called_with(landingState.recon, config.red.recon.templates.GJ11_RECON)
    end)

    it("should airlift the zone's transport aircraft after arrival logistics succeeds", function()
      local config = buildConfig()
      local transportAircraft = { { guid = "TA-001", name = "Transport 1" } }
      config.red.amphibOps.zones[1].air.transportAircraft = transportAircraft
      local landingState = buildLandingState()

      landingState.amphibOps.zoneStates.Taoyuan.phase = constants.AMPHIBIOUS_PHASES.WAITING_ARRIVAL
      stubGetUnitsInHoldingAreas.returns(buildHoldingResult())

      Coordinator.process(config, landingState,
        { contacts = buildContacts(), currentTime = 1000, filteredShips = buildFilteredShips() })

      assert.stub(stubTransferTransportAircraft).was.called_with(transportAircraft)
    end)

    it("should skip transport aircraft transfer and recon when the zone configures neither", function()
      local config = buildConfig()
      local landingState = buildLandingState()

      landingState.amphibOps.zoneStates.Taoyuan.phase = constants.AMPHIBIOUS_PHASES.WAITING_ARRIVAL
      stubGetUnitsInHoldingAreas.returns(buildHoldingResult())

      Coordinator.process(config, landingState,
        { contacts = buildContacts(), currentTime = 1000, filteredShips = buildFilteredShips() })

      assert.are.equal(constants.AMPHIBIOUS_PHASES.WAITING_ASSAULT, landingState.amphibOps.zoneStates.Taoyuan.phase)
      assert.stub(stubTransferTransportAircraft).was_not.called()
      assert.stub(stubAddReconEntry).was_not.called()
    end)

    -- Assault launch starts mine clearing and records the landing start time
    it("should move a zone from WAITING_ASSAULT to MINE_CLEARING when assault launches", function()
      local config = buildConfig()
      local landingState = buildLandingState()

      landingState.amphibOps.zoneStates.Taoyuan = buildZoneState({
        phase = constants.AMPHIBIOUS_PHASES.WAITING_ASSAULT,
        amphibiousAssaultStartTime = 900,
      })
      stubCountContactsInArea.returns(1)

      Coordinator.process(config, landingState,
        { contacts = buildContacts(), currentTime = 1000, filteredShips = buildFilteredShips() })

      assert.are.equal(constants.AMPHIBIOUS_PHASES.MINE_CLEARING, landingState.amphibOps.zoneStates.Taoyuan.phase)
      assert.stub(stubStartMineClearing).was.called(1)
      assert.are.equal(1000, landingState.amphibOps.zoneStates.Taoyuan.airlandingMissionStartTime)
      assert.stub(stubMoveToLaunchStations).was_not.called()
    end)

    -- Missing lane reference points keep the zone waiting
    it("should stay in WAITING_ASSAULT when mine clearing cannot start", function()
      local config = buildConfig()
      local landingState = buildLandingState()
      landingState.amphibOps.zoneStates.Taoyuan = buildZoneState({
        phase = constants.AMPHIBIOUS_PHASES.WAITING_ASSAULT,
        amphibiousAssaultStartTime = 900,
      })
      stubCountContactsInArea.returns(1)
      stubStartMineClearing.returns(false)

      Coordinator.process(config, landingState,
        { contacts = buildContacts(), currentTime = 1000, filteredShips = buildFilteredShips() })

      assert.are.equal(constants.AMPHIBIOUS_PHASES.WAITING_ASSAULT, landingState.amphibOps.zoneStates.Taoyuan.phase)
      assert.is_nil(landingState.amphibOps.zoneStates.Taoyuan.airlandingMissionStartTime)
    end)

    it("should keep MINE_CLEARING and LSTs anchored while sweepers are working", function()
      local config = buildConfig()
      local landingState = buildLandingState()
      landingState.amphibOps.zoneStates.Taoyuan.phase = constants.AMPHIBIOUS_PHASES.MINE_CLEARING

      Coordinator.process(config, landingState,
        { contacts = buildContacts(), currentTime = 1000, filteredShips = buildFilteredShips() })

      assert.are.equal(constants.AMPHIBIOUS_PHASES.MINE_CLEARING, landingState.amphibOps.zoneStates.Taoyuan.phase)
      assert.stub(stubMoveToLaunchStations).was_not.called()
    end)

    it("should advance MINE_CLEARING through ASSAULT_LANDING as each step completes", function()
      local config = buildConfig()
      local landingState = buildLandingState()
      local zoneState = landingState.amphibOps.zoneStates.Taoyuan
      zoneState.phase = constants.AMPHIBIOUS_PHASES.MINE_CLEARING
      fillFirstAcvWave(zoneState)
      stubUpdateMineClearing.returns(true)
      stubUpdateBoats.returns(true)
      stubUpdateObstacleClearing.returns(true)

      Coordinator.process(config, landingState,
        { contacts = buildContacts(), currentTime = 1000, filteredShips = buildFilteredShips() })

      assert.are.equal(constants.AMPHIBIOUS_PHASES.ASSAULT_LANDING, zoneState.phase)
      assert.stub(stubPairBoats).was.called(1)
      assert.stub(stubMoveToLaunchStations).was.called(1)
      assert.stub(stubLaunchBoats).was.called(1)
      assert.stub(stubStartObstacleClearing).was.called(1)
      assert.stub(stubLaunchHovercraft).was.called(1)
      assert.stub(stubScheduleHeliWave).was.called(1)
    end)

    it("should update the helicopter waves of every zone each tick", function()
      local config = buildConfig()
      local landingState = buildLandingState()

      Coordinator.process(config, landingState,
        { contacts = buildContacts(), currentTime = 1000, filteredShips = buildFilteredShips() })

      assert.stub(stubUpdateHeliWave).was.called(#config.red.amphibOps.zones)
    end)

    -- Hovercraft wait for the first ACV wave, but are still updated
    it("should not launch hovercraft before the first ACV wave is full", function()
      local config = buildConfig()
      local landingState = buildLandingState()
      landingState.amphibOps.zoneStates.Taoyuan.phase = constants.AMPHIBIOUS_PHASES.ASSAULT_LANDING

      Coordinator.process(config, landingState,
        { contacts = buildContacts(), currentTime = 1000, filteredShips = buildFilteredShips() })

      assert.stub(stubLaunchHovercraft).was_not.called()
      assert.stub(stubUpdateHovercraft).was.called(1)
    end)

    it("should launch hovercraft once the first ACV wave is full", function()
      local config = buildConfig()
      local landingState = buildLandingState()
      local zoneState = landingState.amphibOps.zoneStates.Taoyuan
      zoneState.phase = constants.AMPHIBIOUS_PHASES.ASSAULT_LANDING
      fillFirstAcvWave(zoneState)

      Coordinator.process(config, landingState,
        { contacts = buildContacts(), currentTime = 1000, filteredShips = buildFilteredShips() })

      assert.stub(stubLaunchHovercraft).was.called(1)
    end)

    it("should hold hovercraft when a first-wave ACV is lost", function()
      local config = buildConfig()
      local landingState = buildLandingState()
      local zoneState = landingState.amphibOps.zoneStates.Taoyuan
      zoneState.phase = constants.AMPHIBIOUS_PHASES.ASSAULT_LANDING
      fillFirstAcvWave(zoneState)
      stubGetUnit.on_call_with("ZBD-1").returns(nil)

      Coordinator.process(config, landingState,
        { contacts = buildContacts(), currentTime = 1000, filteredShips = buildFilteredShips() })

      assert.stub(stubLaunchHovercraft).was_not.called()
    end)

    it("should launch hovercraft when the first ACV wave times out before it is full", function()
      local config = buildConfig()
      local landingState = buildLandingState()
      local zoneState = landingState.amphibOps.zoneStates.Taoyuan
      zoneState.phase = constants.AMPHIBIOUS_PHASES.ASSAULT_LANDING
      zoneState.acvWaitStartedAt = 1000 - config.red.amphibOps.acvWave.hovercraftWaitSec

      Coordinator.process(config, landingState,
        { contacts = buildContacts(), currentTime = 1000, filteredShips = buildFilteredShips() })

      assert.stub(stubLaunchHovercraft).was.called(1)
    end)

    it("should keep BOAT_ASSAULT while boats are under way", function()
      local config = buildConfig()
      local landingState = buildLandingState()
      landingState.amphibOps.zoneStates.Taoyuan.phase = constants.AMPHIBIOUS_PHASES.BOAT_ASSAULT

      Coordinator.process(config, landingState,
        { contacts = buildContacts(), currentTime = 1000, filteredShips = buildFilteredShips() })

      assert.are.equal(constants.AMPHIBIOUS_PHASES.BOAT_ASSAULT, landingState.amphibOps.zoneStates.Taoyuan.phase)
      assert.stub(stubLaunchBoats).was.called(1)
      assert.stub(stubStartObstacleClearing).was_not.called()
      assert.stub(stubLaunchHovercraft).was_not.called()
    end)

    it("should move ASSAULT_LANDING to COMPLETED via WAITING_ADMIN_OFFLOADING when beachhead exists", function()
      local config = buildConfig()
      local landingState = buildLandingState()
      landingState.amphibOps.barges = { ["BARGE-001"] = { guid = "BARGE-001", roros = {} } }

      landingState.amphibOps.zoneStates.Taoyuan.phase = constants.AMPHIBIOUS_PHASES.ASSAULT_LANDING
      stubCountUnitsInEachArea.returns({
        Taoyuan = {
          ["ZBD-05"] = 6,
          ["ZTD-05"] = 4,
        },
      })

      Coordinator.process(config, landingState,
        { contacts = buildContacts(), currentTime = 1000, filteredShips = buildFilteredShips() })

      assert.are.equal(constants.AMPHIBIOUS_PHASES.COMPLETED, landingState.amphibOps.zoneStates.Taoyuan.phase)
      assert.stub(stubStartAdminOffloading).was.called(1)
      assert.are.same(landingState.amphibOps.barges, stubStartAdminOffloading.calls[1].vals[2])
      assert.stub(stubUpdateHovercraft).was.called(1)
    end)

    for name, getStub in pairs({
      ACVs = function() return stubHasUnreleasedACV end,
      hovercraft = function() return stubHasUnlaunchedHovercraft end,
      boats = function() return stubHasPendingBoats end,
    }) do
      it("should hold admin offloading while the deploy line still has unreleased " .. name, function()
        local config = buildConfig()
        local landingState = buildLandingState()
        landingState.amphibOps.zoneStates.Taoyuan.phase = constants.AMPHIBIOUS_PHASES.WAITING_ADMIN_OFFLOADING
        getStub().returns(true)

        Coordinator.process(config, landingState,
          { contacts = buildContacts(), currentTime = 1000, filteredShips = buildFilteredShips() })

        assert.are.equal(constants.AMPHIBIOUS_PHASES.WAITING_ADMIN_OFFLOADING,
          landingState.amphibOps.zoneStates.Taoyuan.phase)
        assert.stub(stubStartAdminOffloading).was_not.called()
      end)
    end

    it("should use the zone's own beachhead size", function()
      local config = buildConfig()
      config.red.amphibOps.zones = { buildZone({ landing = { beachheadVehicles = 5 } }) }
      local landingState = buildLandingState()
      landingState.amphibOps.zoneStates.Taoyuan.phase = constants.AMPHIBIOUS_PHASES.ASSAULT_LANDING
      stubCountUnitsInEachArea.returns({ Taoyuan = { ["ZBD-05"] = 3, ["ZTD-05"] = 2 } })

      Coordinator.process(config, landingState,
        { contacts = buildContacts(), currentTime = 1000, filteredShips = buildFilteredShips() })

      assert.are.equal(constants.AMPHIBIOUS_PHASES.COMPLETED, landingState.amphibOps.zoneStates.Taoyuan.phase)
    end)

    it("should stay in ASSAULT_LANDING below the zone's beachhead size", function()
      local config = buildConfig()
      local landingState = buildLandingState()
      landingState.amphibOps.zoneStates.Taoyuan.phase = constants.AMPHIBIOUS_PHASES.ASSAULT_LANDING
      stubCountUnitsInEachArea.returns({ Taoyuan = { ["ZBD-05"] = 6, ["ZTD-05"] = 3 } })

      Coordinator.process(config, landingState,
        { contacts = buildContacts(), currentTime = 1000, filteredShips = buildFilteredShips() })

      assert.are.equal(constants.AMPHIBIOUS_PHASES.ASSAULT_LANDING, landingState.amphibOps.zoneStates.Taoyuan.phase)
      assert.stub(stubStartAdminOffloading).was_not.called()
    end)

    it("should count no landed vehicles when the zone has no unit statistics", function()
      local config = buildConfig()
      local landingState = buildLandingState()
      landingState.amphibOps.zoneStates.Taoyuan.phase = constants.AMPHIBIOUS_PHASES.ASSAULT_LANDING
      stubCountUnitsInEachArea.returns({})

      Coordinator.process(config, landingState,
        { contacts = buildContacts(), currentTime = 1000, filteredShips = buildFilteredShips() })

      assert.are.equal(constants.AMPHIBIOUS_PHASES.ASSAULT_LANDING, landingState.amphibOps.zoneStates.Taoyuan.phase)
    end)

    it("should ignore vehicles landed in another zone", function()
      local config = buildConfig()
      local landingState = buildLandingState()
      landingState.amphibOps.zoneStates.Taoyuan.phase = constants.AMPHIBIOUS_PHASES.ASSAULT_LANDING
      stubCountUnitsInEachArea.returns({ Sishu = { ["ZBD-05"] = 50, ["ZTD-05"] = 50 } })

      Coordinator.process(config, landingState,
        { contacts = buildContacts(), currentTime = 1000, filteredShips = buildFilteredShips() })

      assert.are.equal(constants.AMPHIBIOUS_PHASES.ASSAULT_LANDING, landingState.amphibOps.zoneStates.Taoyuan.phase)
    end)

    it("should transfer remaining cargos when airlanding mission has reached the two-hour threshold", function()
      local config = buildConfig()
      local landingState = buildLandingState()

      landingState.amphibOps.zoneStates.Taoyuan = buildZoneState({
        phase = constants.AMPHIBIOUS_PHASES.COMPLETED,
        airlandingMissionStartTime = 100,
      })

      Coordinator.process(config, landingState,
        { contacts = buildContacts(), currentTime = 7300, filteredShips = buildFilteredShips() })

      assert.are.equal(7300, landingState.amphibOps.zoneStates.Taoyuan.airlandingMissionStartTime)
      assert.stub(stubTransferRemainingCargos).was.called(1)
    end)

    it("should refill the transport aircraft along with the remaining cargos", function()
      local config = buildConfig()
      local transportAircraft = { guid = "TA-001", name = "Transport 1" }
      config.red.amphibOps.zones[1].air.transportAircraft = transportAircraft
      local landingState = buildLandingState()
      landingState.amphibOps.zoneStates.Taoyuan = buildZoneState({
        phase = constants.AMPHIBIOUS_PHASES.COMPLETED,
        airlandingMissionStartTime = 100,
      })

      Coordinator.process(config, landingState,
        { contacts = buildContacts(), currentTime = 7300, filteredShips = buildFilteredShips() })

      assert.stub(stubTransferTransportAircraft).was.called_with(transportAircraft)
    end)

    it("should not refill the transport aircraft before the transfer interval has passed", function()
      local config = buildConfig()
      config.red.amphibOps.zones[1].air.transportAircraft = { guid = "TA-001" }
      local landingState = buildLandingState()
      landingState.amphibOps.zoneStates.Taoyuan = buildZoneState({
        phase = constants.AMPHIBIOUS_PHASES.COMPLETED,
        airlandingMissionStartTime = 100,
      })

      Coordinator.process(config, landingState,
        { contacts = buildContacts(), currentTime = 200, filteredShips = buildFilteredShips() })

      assert.stub(stubTransferTransportAircraft).was_not.called()
    end)

    -- Zone phases below stay put under the default stubs (not past start time, no arrivals,
    -- enemy contacts above threshold, no beachhead), so only the gate changes state.
    describe("fire support gate", function()
      ---@param totalPercentage number
      ---@return SBJ__AmmoInventoryResult
      local function buildReport(totalPercentage)
        return {
          firing   = { current = 0, max = 0, percentage = 0 },
          resupply = { current = 0, max = 0, percentage = 0 },
          ammo     = { current = 0, max = 0, percentage = 0 },
          total    = { current = 0, max = 0, percentage = totalPercentage },
        }
      end

      ---@param overrides? table
      local function buildGateConfig(overrides)
        local config = buildConfig()
        config.red.amphibOps.fireSupport = { srbmHoldAmmoPct = 50 }
        if overrides then
          for k, v in pairs(overrides) do config.red.amphibOps[k] = v end
        end
        return config
      end

      ---@param overrides? table
      local function buildGateLandingState(overrides)
        local landingState = buildLandingState()
        landingState.ground = { srbm = { firingUnits = {}, resupplyUnits = {}, ammunitions = {} } }
        if overrides then
          for k, v in pairs(overrides) do landingState.amphibOps[k] = v end
        end
        return landingState
      end

      it("should set fireSupportOnHold true when ammo below threshold and zones not all arrived", function()
        local config = buildGateConfig()
        local landingState = buildGateLandingState()
        landingState.amphibOps.zoneStates.Taoyuan = buildZoneState({ phase = constants.AMPHIBIOUS_PHASES.MOVING })
        trackStub(stub(MissileSystem, "getAmmoInventory").returns(buildReport(40)))

        Coordinator.process(config, landingState,
          { contacts = buildContacts(), currentTime = 1000, filteredShips = buildFilteredShips() })

        assert.is_true(landingState.amphibOps.fireSupportOnHold)
      end)
    end)
  end)
end)
