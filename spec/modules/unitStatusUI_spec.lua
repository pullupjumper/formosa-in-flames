-- UnitStatusUI Unit Tests
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
  ---@type luassert.spy
  local dialogStub

  ---Track and register test stub for automatic cleanup.
  ---@param s any
  ---@return luassert.spy
  local function trackStub(s)
    table.insert(activeStubs, s)
    return s
  end

  before_each(function()
    activeStubs = {}
    dialogStub = trackStub(stub(GameApi, "UI_CallAdvancedHTMLDialog"))
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

  ---Create a config where both sides have nothing deployed
  ---@param overrides? table
  ---@return table
  local function makeConfig(overrides)
    local function makeSideConfig()
      return { gnssJamming = { jammers = {} }, air = { landBased = { deployedACs = {} } }, ground = {} }
    end
    local config = { c = makeSideConfig(), t = makeSideConfig() }
    config.c.amphibOps = { operations = {}, operationalZones = {} }
    if overrides then
      for k, v in pairs(overrides) do config[k] = v end
    end
    return config
  end

  ---Create save data with empty SIGINT, IADS and aircraft slices for every side
  ---@param overrides? table
  ---@return table
  local function makeSaveData(overrides)
    local function makeSideState()
      return { sigint = { transmissions = {} }, iads = {}, air = { landBased = {} } }
    end
    local saveData = { c = makeSideState(), t = makeSideState(), u = makeSideState() }
    if overrides then
      for k, v in pairs(overrides) do saveData[k] = v end
    end
    return saveData
  end

  -- ============================================================================
  -- createSetupMenu
  -- ============================================================================

  describe("createSetupMenu", function()
    local removeJammersStub
    local addGnssJammerStub
    local addAircraftStub
    local initTargetAircraftStub
    local redeployStub
    local saveData

    ---Make the dialog return a submitted setup form
    ---@param summaryJson string|nil JSON body of summaryData, nil to omit it
    ---@param pressed? string Button pressed, defaults to Done
    local function submit(summaryJson, pressed)
      dialogStub.returns({
        pressed = pressed or "Done",
        summaryData = summaryJson and ("'" .. summaryJson .. "'") or nil
      })
    end

    before_each(function()
      saveData = makeSaveData()
      trackStub(stub(PersistentState, "update").invokes(function(fn) fn(saveData) end))
      removeJammersStub = trackStub(stub(GnssJamming, "removeJammers"))
      addGnssJammerStub = trackStub(stub(GnssJamming, "addGnssJammer"))
      addAircraftStub = trackStub(stub(UnitGenerator, "addAircraft"))
      initTargetAircraftStub = trackStub(stub(CommsJamming, "updateTargetAircraft"))
      redeployStub = trackStub(stub(MissileSystem, "redeployFromSetup"))
    end)

    -- Positive: every part of the submission reaches its owner
    it("should apply jammers, aircraft and batteries from a full submission", function()
      local config = makeConfig()
      submit([[{"jammers":[{"name":"J-1"},{"name":"J-2"}],"airbases":[{"name":"AB-1"}],"missileSystems":[{"unitname":"FU-1"}]}]])

      UnitStatusUI.createSetupMenu(config, constants.SIDES.PLAYER)

      assert.stub(removeJammersStub).was.called_with({ { name = "J-1" }, { name = "J-2" } }, constants.SIDES.PLAYER)
      assert.stub(addGnssJammerStub).was.called(2)
      assert.stub(addAircraftStub).was.called_with({ { name = "AB-1" } })
      assert.stub(initTargetAircraftStub).was.called_with(config, saveData)
      assert.stub(redeployStub).was.called_with(config, saveData, constants.SIDES.PLAYER, { { unitname = "FU-1" } })
    end)

    -- Negative: comms jamming targets only Taiwan's aircraft
    it("should skip comms jamming target registration for China", function()
      submit([[{"airbases":[{"name":"AB-1"}]}]])

      UnitStatusUI.createSetupMenu(makeConfig(), constants.SIDES.ENEMY)

      assert.stub(addAircraftStub).was.called(1)
      assert.stub(initTargetAircraftStub).was_not.called()
    end)

    -- Negative: closing the dialog any other way discards the form
    it("should apply nothing when the form is closed without Done", function()
      submit([[{"airbases":[{"name":"AB-1"}]}]], "Cancel")

      UnitStatusUI.createSetupMenu(makeConfig(), constants.SIDES.PLAYER)

      assert.stub(addAircraftStub).was_not.called()
    end)

    -- Negative: Done without a summary has nothing to apply
    it("should apply nothing when the form has no summary", function()
      submit(nil)

      UnitStatusUI.createSetupMenu(makeConfig(), constants.SIDES.PLAYER)

      assert.stub(addAircraftStub).was_not.called()
    end)

    -- Boundary: empty lists must not clear existing jammers or redeploy batteries
    it("should do nothing for an empty submission", function()
      submit([[{"jammers":[],"airbases":[],"missileSystems":[]}]])

      UnitStatusUI.createSetupMenu(makeConfig(), constants.SIDES.PLAYER)

      assert.stub(removeJammersStub).was_not.called()
      assert.stub(addAircraftStub).was_not.called()
      assert.stub(redeployStub).was_not.called()
    end)
  end)

  -- ============================================================================
  -- createUI
  -- ============================================================================

  describe("createUI", function()
    local batteryStub
    local countUnitsStub
    local sigintSpy
    local saveData

    before_each(function()
      saveData = makeSaveData()
      trackStub(stub(PersistentState, "read").invokes(function(fn) fn(saveData) end))
      sigintSpy = trackStub(spy.on(PersistentState, "sigint"))
      batteryStub = trackStub(stub(MissileSystem, "buildBatteryStatusRows").returns({}))
      countUnitsStub = trackStub(stub(AmphibiousAssault, "countUnitsInEachArea").returns({}))
    end)

    -- Positive: China's dashboard adds MRBM batteries and landed units
    it("should show MRBM batteries and landed units for China", function()
      UnitStatusUI.createUI(makeConfig(), constants.SIDES.ENEMY)

      local types = constants.MISSILE_SYSTEM_TYPES
      assert.are.same({ types.SRBM, types.MLRS, types.GLCM, types.ASCM, types.MRBM, types.SAM },
        batteryStub.calls[1].vals[4])
      assert.stub(countUnitsStub).was.called(1)
      assert.stub(dialogStub).was.called(1)
    end)

    -- Positive: Taiwan's SIGINT tab shows what US collectors heard
    it("should read SIGINT from the US side when showing Taiwan", function()
      UnitStatusUI.createUI(makeConfig(), constants.SIDES.PLAYER)

      assert.spy(sigintSpy).was.called_with(saveData, "US")
    end)

    -- Negative: Taiwan has no MRBM batteries and no landing tab
    it("should leave out MRBM batteries and landed units for Taiwan", function()
      UnitStatusUI.createUI(makeConfig(), constants.SIDES.PLAYER)

      local types = constants.MISSILE_SYSTEM_TYPES
      assert.are.same({ types.SRBM, types.MLRS, types.GLCM, types.ASCM, types.SAM },
        batteryStub.calls[1].vals[4])
      assert.stub(countUnitsStub).was_not.called()
      assert.stub(dialogStub).was.called(1)
    end)
  end)
end)
