---@diagnostic disable: need-check-nil, assign-type-mismatch, cast-local-type, param-type-mismatch, inject-field
-- UnitStatusUI Unit Tests
local UnitStatusUI = require("src.modules.unitStatusUI")
local GameApi = require("src.utils.gameApi")
local GnssJamming = require("src.modules.ew.gnssJamming")
local UnitGenerator = require("src.modules.unitGenerator")
local CommsJamming = require("src.modules.ew.commsJamming")
local MissileSystem = require("src.modules.missileSystem.init")
local LandingOps = require("src.modules.landingOps.init")
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
      return { gnssJamming = { jammers = {} }, air = { deployedACs = {} }, ground = { missileSystemTypes = {} } }
    end
    local config = { red = makeSideConfig(), blue = makeSideConfig() }
    config.red.amphibOps = { operations = {}, operationalZones = {} }
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
      return { sigint = { transmissions = {} }, iads = {}, air = {} }
    end
    local saveData = { red = makeSideState(), blue = makeSideState(), ally = makeSideState() }
    if overrides then
      for k, v in pairs(overrides) do saveData[k] = v end
    end
    return saveData
  end

  -- ============================================================================
  -- createControlPanel
  -- ============================================================================
  describe("createControlPanel", function()
    local addAircraftStub
    local sagStub
    local countUnitsStub
    local sigintSpy
    local saveData

    ---@param isEditMode boolean
    ---@return table
    local function configFor(isEditMode)
      local config = makeConfig({ isEditMode = isEditMode })
      config.blue.surface = { sags = {} }
      return config
    end

    ---@param form table
    local function submit(form)
      form.pressed = "Done"
      dialogStub.returns(form)
    end

    local AIRCRAFT_FORM = { summaryData = "'{\"airbases\":[{\"name\":\"AB-1\"}]}'" }

    before_each(function()
      saveData = makeSaveData()
      trackStub(stub(PersistentState, "read").invokes(function(fn) fn(saveData) return true end))
      trackStub(stub(PersistentState, "update").invokes(function(fn) fn(saveData) end))
      addAircraftStub = trackStub(stub(UnitGenerator, "addAircraft"))
      sagStub = trackStub(stub(UnitGenerator, "createSAGs"))
      trackStub(stub(MissileSystem, "buildBatteryStatuses").returns({}))
      countUnitsStub = trackStub(stub(LandingOps, "countUnitsInEachArea").returns({}))
      sigintSpy = trackStub(spy.on(PersistentState, "sigint"))
      dialogStub.returns({})
      trackStub(stub(CommsJamming, "updateTargetAircraft"))
    end)

    -- Positive: China's page adds landed units
    it("should show landed units for China", function()
      UnitStatusUI.createControlPanel(configFor(true), constants.SIDES.RED)

      assert.stub(countUnitsStub).was.called(1)
    end)

    -- Positive: Taiwan's SIGINT shows what US collectors heard
    it("should read SIGINT from the US side when showing Taiwan", function()
      UnitStatusUI.createControlPanel(configFor(true), constants.SIDES.BLUE)

      assert.spy(sigintSpy).was.called_with(saveData, "US")
    end)

    -- Negative: Taiwan has no landing units
    it("should leave out landed units for Taiwan", function()
      UnitStatusUI.createControlPanel(configFor(true), constants.SIDES.BLUE)

      assert.stub(countUnitsStub).was_not.called()
    end)

    -- Positive: edit mode never locks, so the deployment can be redone
    it("should apply every submission in edit mode", function()
      submit(AIRCRAFT_FORM)

      UnitStatusUI.createControlPanel(configFor(true), constants.SIDES.BLUE)
      UnitStatusUI.createControlPanel(configFor(true), constants.SIDES.BLUE)

      assert.stub(addAircraftStub).was.called(2)
      assert.is_not_true(saveData.blue.deploymentLocked)
    end)

    -- Positive: play mode accepts the first deployment then locks
    it("should lock the deployment after the first play mode submission", function()
      submit(AIRCRAFT_FORM)

      UnitStatusUI.createControlPanel(configFor(false), constants.SIDES.BLUE)

      assert.stub(addAircraftStub).was.called(1)
      assert.is_true(saveData.blue.deploymentLocked)
    end)

    -- Negative: a locked deployment ignores later submissions
    it("should ignore a play mode submission once locked", function()
      saveData.blue.deploymentLocked = true
      submit(AIRCRAFT_FORM)

      UnitStatusUI.createControlPanel(configFor(false), constants.SIDES.BLUE)

      assert.stub(addAircraftStub).was_not.called()
    end)

    -- Negative: the other side's lock is independent
    it("should not lock the other side", function()
      submit(AIRCRAFT_FORM)

      UnitStatusUI.createControlPanel(configFor(false), constants.SIDES.BLUE)

      assert.is_not_true(saveData.red.deploymentLocked)
    end)

    -- Negative: add-units only exists in edit mode
    it("should run add-units actions only in edit mode", function()
      submit({ selectedActions = "'{\"actionIds\":[\"addSAGs\"]}'" })

      UnitStatusUI.createControlPanel(configFor(false), constants.SIDES.BLUE)
      assert.stub(sagStub).was_not.called()

      UnitStatusUI.createControlPanel(configFor(true), constants.SIDES.BLUE)
      assert.stub(sagStub).was.called(1)
    end)

    -- Boundary: CMO returns inputs the page never wrote as empty strings
    it("should skip inputs left empty by the page", function()
      submit({ summaryData = "'{\"airbases\":[{\"name\":\"AB-1\"}]}'", emconData = "", selectedActions = "''" })

      UnitStatusUI.createControlPanel(configFor(true), constants.SIDES.BLUE)

      assert.stub(addAircraftStub).was.called(1)
      assert.stub(sagStub).was_not.called()
    end)

    -- Negative: dismissing the dialog neither applies nor locks
    it("should neither apply nor lock when the dialog is dismissed", function()
      dialogStub.returns({})

      UnitStatusUI.createControlPanel(configFor(false), constants.SIDES.BLUE)

      assert.stub(addAircraftStub).was_not.called()
      assert.is_not_true(saveData.blue.deploymentLocked)
    end)
  end)
end)
