-- LandingOps Coordinator Unit Tests
---@diagnostic disable: undefined-field
local Coordinator = require("src.modules.landingOps.coordinator")
local Utils = require("src.utils.utils")
local GameUtils = require("src.utils.gameUtils")
local Logger = require("src.utils.logger")
local ShipMovement = require("src.modules.landingOps.shipMovement")
local AmphibiousLogistics = require("src.modules.landingOps.amphibiousLogistics")
local AmphibiousAssault = require("src.modules.landingOps.amphibiousAssault")
local SecondWaveUnloading = require("src.modules.landingOps.secondWaveUnloading")
local UnitStatusUI = require("src.modules.unitStatusUI")
local constants = require("src.core.constants")

describe("LandingOps Coordinator", function()
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
      c = {
        amphibOps = {
          operationalZones = { makeZone() },
          operations = { makeOperation() },
          periodOfTime = 3600,
          sag = { ["SAG Alpha"] = { groupName = "SAG Alpha" } },
          transportAircraft = { { guid = "TA-001", name = "Transport 1" } },
        },
        recon = {
          template = {
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

  ---Create a saveData structure
  ---@param overrides? table
  ---@return table
  local function makeSaveData(overrides)
    local saveData = {
      c = {
        amphibOps = {
          startTime = "2026-04-03 00:00:00",
          zoneStates = {
            Taoyuan = makeZoneState(),
          },
        },
        recon = {
          queue = {},
        },
      },
    }
    if overrides then
      for k, v in pairs(overrides) do
        saveData[k] = v
      end
    end
    return saveData
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
    local stubDeepCopy
    local stubCalculatePathDistanceAndTime
    local stubCountContactsInArea
    local stubSetLandingMissionStartTime
    local stubSetCoursesForLSTs
    local stubCountUnitsInEachArea
    local stubStartSecondWaveUnloading
    local stubRetransferCargos

    before_each(function()
      stubMoveToStagingArea = trackStub(stub(ShipMovement, "moveToStagingArea").returns(false))
      stubIsAfterStartTime = trackStub(stub(GameUtils, "isAfterStartTime").returns(false))
      stubGetUnitsInAnchorageArea = trackStub(stub(AmphibiousLogistics, "getUnitsInAnchorageArea")
        .returns(makeAnchorageResult()))
      stubGetCount = trackStub(stub(Utils, "getCount").returns(0))
      stubCreateCargoMissions = trackStub(stub(AmphibiousLogistics, "createCargoMissions").returns(true))
      stubTransferAndAssign = trackStub(stub(AmphibiousLogistics, "transferAndAssign").returns(true))
      stubTransferTransportAircraft = trackStub(stub(AmphibiousLogistics, "transferAndAssignTransportAircraft"))
      stubDeepCopy = trackStub(stub(Utils, "deepCopy").invokes(function(value)
        local copy = {}
        for k, v in pairs(value) do
          copy[k] = v
        end
        return copy
      end))
      stubCalculatePathDistanceAndTime = trackStub(stub(GameUtils, "calculatePathDistanceAndTime").returns(0, 600))
      stubCountContactsInArea = trackStub(stub(AmphibiousAssault, "countContactsInArea").returns(99))
      stubSetLandingMissionStartTime = trackStub(stub(AmphibiousAssault, "setLandingMissionStartTime").returns(true))
      stubSetCoursesForLSTs = trackStub(stub(AmphibiousAssault, "setCoursesForLSTs").returns(true))
      stubCountUnitsInEachArea = trackStub(stub(UnitStatusUI, "countUnitsInEachArea").returns({}))
      stubStartSecondWaveUnloading = trackStub(stub(SecondWaveUnloading, "startSecondWaveUnloading").returns(true))
      stubRetransferCargos = trackStub(stub(AmphibiousLogistics, "retransferCargos").returns(true))
    end)

    -- Positive: advances moving zones into arrival waiting state
    it("should move a zone from MOVING to WAITING_ARRIVAL when staging movement completes", function()
      local config = makeConfig()
      local saveData = makeSaveData()

      saveData.c.amphibOps.zoneStates.Taoyuan.phase = constants.AMPHIBIOUS_PHASES.MOVING
      stubIsAfterStartTime.returns(true)
      stubMoveToStagingArea.returns(true)

      Coordinator.process(config, saveData, makeContacts(), 1000, makeFilteredShips())

      assert.are.equal(constants.AMPHIBIOUS_PHASES.WAITING_ARRIVAL, saveData.c.amphibOps.zoneStates.Taoyuan.phase)
      assert.stub(stubMoveToStagingArea).was.called(1)
    end)

    -- Positive: performs arrival logistics and Taoyuan temporary setup
    it("should enqueue Taoyuan temporary tasks after arrival logistics succeeds", function()
      local config = makeConfig()
      local saveData = makeSaveData()

      saveData.c.amphibOps.zoneStates.Taoyuan.phase = constants.AMPHIBIOUS_PHASES.WAITING_ARRIVAL
      stubGetCount.returns(2)

      Coordinator.process(config, saveData, makeContacts(), 1000, makeFilteredShips())

      assert.are.equal(constants.AMPHIBIOUS_PHASES.WAITING_ASSAULT, saveData.c.amphibOps.zoneStates.Taoyuan.phase)
      assert.are.equal(1000, saveData.c.amphibOps.zoneStates.Taoyuan.amphibiousAssaultStartTime)
      assert.are.equal(1, #saveData.c.recon.queue)
      assert.stub(stubCreateCargoMissions).was.called(1)
      assert.stub(stubTransferAndAssign).was.called(1)
      assert.stub(stubTransferTransportAircraft).was.called(1)
      assert.stub(stubDeepCopy).was.called(1)
    end)

    -- Positive: advances assault phase when launch conditions are met
    it("should move a zone from WAITING_ASSAULT to WAITING_SECOND_WAVE when assault launches", function()
      local config = makeConfig()
      local saveData = makeSaveData()

      saveData.c.amphibOps.zoneStates.Taoyuan = makeZoneState({
        phase = constants.AMPHIBIOUS_PHASES.WAITING_ASSAULT,
        amphibiousAssaultStartTime = 900,
      })
      stubCountContactsInArea.returns(1)

      Coordinator.process(config, saveData, makeContacts(), 1000, makeFilteredShips())

      assert.are.equal(constants.AMPHIBIOUS_PHASES.WAITING_SECOND_WAVE, saveData.c.amphibOps.zoneStates.Taoyuan.phase)
      assert.stub(stubSetLandingMissionStartTime).was.called(1)
      assert.stub(stubSetCoursesForLSTs).was.called(1)
    end)

    -- Positive: completes second wave when beachhead exists
    it("should move a zone from WAITING_SECOND_WAVE to COMPLETED when beachhead exists", function()
      local config = makeConfig()
      local saveData = makeSaveData()

      saveData.c.amphibOps.zoneStates.Taoyuan.phase = constants.AMPHIBIOUS_PHASES.WAITING_SECOND_WAVE
      stubCountUnitsInEachArea.returns({
        Taoyuan = {
          ["ZBD-05"] = 1,
        },
      })

      Coordinator.process(config, saveData, makeContacts(), 1000, makeFilteredShips())

      assert.are.equal(constants.AMPHIBIOUS_PHASES.COMPLETED, saveData.c.amphibOps.zoneStates.Taoyuan.phase)
      assert.stub(stubStartSecondWaveUnloading).was.called(1)
    end)

    -- Negative: logs an error when zone operation mapping is missing
    it("should log an error when no matching operation exists for a zone", function()
      local config = makeConfig({
        c = {
          amphibOps = {
            operationalZones = { makeZone({ name = "Kaohsiung" }) },
            operations = { makeOperation({ name = "Taoyuan" }) },
            periodOfTime = 3600,
            sag = { ["SAG Alpha"] = { groupName = "SAG Alpha" } },
            transportAircraft = {},
          },
          recon = {
            template = {
              GJ11_RECON = {
                course = { { latitude = 25.0, longitude = 121.0 } },
                speed = 400,
              },
            },
          },
        },
      })
      local saveData = makeSaveData({
        c = {
          amphibOps = {
            startTime = "2026-04-03 00:00:00",
            zoneStates = {
              Kaohsiung = makeZoneState(),
            },
          },
          recon = {
            queue = {},
          },
        },
      })

      Coordinator.process(config, saveData, makeContacts(), 1000, makeFilteredShips())

      assert.stub(Logger.error).was.called(1)
      assert.stub(stubMoveToStagingArea).was_not.called()
    end)

    -- Boundary: triggers cargo retransfer exactly at the two-hour threshold
    it("should retransfer cargos when airlanding mission has reached the two-hour threshold", function()
      local config = makeConfig()
      local saveData = makeSaveData()

      saveData.c.amphibOps.zoneStates.Taoyuan = makeZoneState({
        phase = constants.AMPHIBIOUS_PHASES.COMPLETED,
        airlandingMissionStartTime = 100,
      })

      Coordinator.process(config, saveData, makeContacts(), 7300, makeFilteredShips())

      assert.are.equal(7300, saveData.c.amphibOps.zoneStates.Taoyuan.airlandingMissionStartTime)
      assert.stub(stubRetransferCargos).was.called(1)
    end)
  end)
end)
