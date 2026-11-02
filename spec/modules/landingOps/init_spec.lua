---@diagnostic disable: need-check-nil, assign-type-mismatch, cast-local-type, param-type-mismatch, inject-field
-- LandingOps Init Unit Tests
local LandingOps = require("src.modules.landingOps.init")
local GameApi = require("src.utils.gameApi")
local Logger = require("src.utils.logger")
local ShipMovement = require("src.modules.landingOps.shipMovement")
local Coordinator = require("src.modules.landingOps.coordinator")
local AmphibiousAssault = require("src.modules.landingOps.amphibiousAssault")
local AdminOffloading = require("src.modules.landingOps.adminOffloading")
local DirectFirePrep = require("src.modules.landingOps.directFirePrep")
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
    it("should forward the amphibious config, zone states and ship to AmphibiousAssault", function()
      local ship = buildShip()
      local amphibOpsConfig = { zones = {} }
      local saveData = buildSaveData({ zoneStates = {} })
      local stubLaunch = trackStub(stub(AmphibiousAssault, "launchACV").returns(true))

      local result = LandingOps.launchACV(buildConfig(amphibOpsConfig), saveData, ship)

      assert.is_true(result)
      assert.stub(stubLaunch).was.called_with(amphibOpsConfig, saveData.red.amphibOps.zoneStates, ship)
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
    it("should forward the amphibious config, zone states and ship to DirectFirePrep", function()
      local ship = buildShip()
      local amphibOpsConfig = { zones = {} }
      local zoneStates = { A = {} }
      local saveData = buildSaveData({ zoneStates = zoneStates })
      local stubAttack = trackStub(stub(DirectFirePrep, "attackAirlandingZone").returns(true))

      local result = LandingOps.attackAirlandingZone(buildConfig(amphibOpsConfig), saveData, ship)

      assert.is_true(result)
      assert.stub(stubAttack).was.called_with(amphibOpsConfig, zoneStates, ship)
    end)
  end)

  describe("removeDestroyedUnit", function()
    it("should remove the unit from the zone that recorded it", function()
      local zoneStateA = { heliWave = { transport = { currentWave = {} }, attackHelis = {} } }
      local zoneStateB = { heliWave = { transport = { currentWave = { T1 = {} } }, attackHelis = {} } }
      local saveData = buildSaveData({ zoneStates = { A = zoneStateA, B = zoneStateB } })

      assert.is_true(LandingOps.removeDestroyedUnit(saveData, "T1"))

      assert.is_nil(zoneStateB.heliWave.transport.currentWave.T1)
    end)

    it("should return false when no zone recorded the unit", function()
      local saveData = buildSaveData({ zoneStates = { A = { heliWave = { transport = { currentWave = {} }, attackHelis = {} } } } })

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
