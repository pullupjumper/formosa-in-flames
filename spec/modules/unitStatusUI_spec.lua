-- UnitStatusUI Unit Tests
local stub = require("luassert.stub")
local UnitStatusUI = require("src.modules.unitStatusUI")
local GameApi = require("src.utils.gameApi")
local GnssJamming = require("src.modules.ew.gnssJamming")
local UnitGenerator = require("src.modules.unitGenerator")
local CommsJamming = require("src.modules.ew.commsJamming")
local MissileSystem = require("src.modules.missileSystem.init")
local AmphibiousAssault = require("src.modules.landingOps.amphibiousAssault")
local PersistentState = require("src.core.persistentState")
local constants = require("src.core.constants")

describe("UnitStatusUI", function()
  ---@type luassert.spy[]
  local activeStubs

  ---Track and register method stub for automatic cleanup.
  ---@param obj table
  ---@param method string
  ---@return luassert.spy
  local function trackStub(obj, method)
    local s = stub(obj, method)
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
  end)

  describe("applySetupResult", function()
    local removeJammersStub
    local addGnssJammerStub
    local addAircraftStub
    local initTargetAircraftStub
    local redeployStub
    local config = { c = { commsJamming = { aircraftDefaults = { "defaults" } } } }

    before_each(function()
      removeJammersStub = trackStub(GnssJamming, "removeJammers")
      addGnssJammerStub = trackStub(GnssJamming, "addGnssJammer")
      addAircraftStub = trackStub(UnitGenerator, "addAircraft")
      initTargetAircraftStub = trackStub(CommsJamming, "initTargetAircraftContexts")
      redeployStub = trackStub(MissileSystem, "redeployFromSetup")
      trackStub(PersistentState, "landBasedAircraft").returns({ "aircraft slice" })
    end)

    it("should apply jammers, aircraft and batteries from a full submission", function()
      local jammers = { { name = "J-1" }, { name = "J-2" } }
      local airbases = { { name = "AB-1" } }
      local missileSystems = { { unitname = "FU-1" } }
      local saveData = {}

      UnitStatusUI.applySetupResult(config, saveData, constants.SIDES.PLAYER,
        { jammers = jammers, airbases = airbases, missileSystems = missileSystems })

      assert.stub(removeJammersStub).was.called_with(jammers, constants.SIDES.PLAYER)
      assert.stub(addGnssJammerStub).was.called(2)
      assert.stub(addAircraftStub).was.called_with(airbases)
      assert.stub(initTargetAircraftStub).was.called_with({ "aircraft slice" }, { "defaults" })
      assert.stub(redeployStub).was.called_with(config, saveData, constants.SIDES.PLAYER, missileSystems)
    end)

    it("should skip comms jamming target registration for China", function()
      UnitStatusUI.applySetupResult(config, {}, constants.SIDES.ENEMY, { airbases = { { name = "AB-1" } } })

      assert.stub(addAircraftStub).was.called(1)
      assert.stub(initTargetAircraftStub).was_not.called()
    end)

    it("should do nothing for an empty submission", function()
      UnitStatusUI.applySetupResult(config, {}, constants.SIDES.PLAYER, { jammers = {}, airbases = {}, missileSystems = {} })

      assert.stub(removeJammersStub).was_not.called()
      assert.stub(addAircraftStub).was_not.called()
      assert.stub(redeployStub).was_not.called()
    end)
  end)

  describe("createUI", function()
    local batteryStub
    local countUnitsStub
    local dialogStub

    before_each(function()
      trackStub(PersistentState, "read").invokes(function(fn) fn({}) end)
      trackStub(PersistentState, "sigint").returns({ transmissions = {} })
      trackStub(PersistentState, "iads").returns({})
      trackStub(GameApi, "ScenEdit_GetUnit").returns(nil)
      batteryStub = trackStub(MissileSystem, "buildBatteryStatusRows").returns({})
      countUnitsStub = trackStub(AmphibiousAssault, "countUnitsInEachArea").returns({})
      dialogStub = trackStub(GameApi, "UI_CallAdvancedHTMLDialog")
    end)

    local function makeConfig()
      return {
        c = { air = { landBased = { deployedACs = {} } } },
        t = { air = { landBased = { deployedACs = {} } } }
      }
    end

    it("should include MRBM and landed units for China", function()
      UnitStatusUI.createUI(makeConfig(), constants.SIDES.ENEMY)

      local systemTypes = batteryStub.calls[1].vals[4]
      assert.is_true(#systemTypes == 6)
      assert.stub(countUnitsStub).was.called(1)
      assert.stub(dialogStub).was.called(1)
    end)

    it("should leave out MRBM and landed units for Taiwan", function()
      UnitStatusUI.createUI(makeConfig(), constants.SIDES.PLAYER)

      local systemTypes = batteryStub.calls[1].vals[4]
      assert.is_true(#systemTypes == 5)
      for _, systemType in ipairs(systemTypes) do
        assert.are_not.equal(constants.MISSILE_SYSTEM_TYPES.MRBM, systemType)
      end
      assert.stub(countUnitsStub).was_not.called()
      assert.stub(dialogStub).was.called(1)
    end)

    it("should read SIGINT from the US side when showing Taiwan", function()
      UnitStatusUI.createUI(makeConfig(), constants.SIDES.PLAYER)

      assert.stub(PersistentState.sigint).was.called_with({}, "US")
    end)
  end)
end)
