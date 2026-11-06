---@diagnostic disable: need-check-nil, assign-type-mismatch, cast-local-type, param-type-mismatch, inject-field
-- UnitStatusUI Unit Tests
local UnitStatusUI = require("src.modules.unitStatusUI")
local GameApi = require("src.utils.gameApi")
local GnssJamming = require("src.modules.ew.gnssJamming")
local UnitGenerator = require("src.modules.unitGenerator")
local CommsJamming = require("src.modules.ew.commsJamming")
local MissileSystem = require("src.modules.missileSystem.init")
local LandingOps = require("src.modules.landingOps.init")
local IntegratedAirDefenseSystem = require("src.modules.integratedAirDefenseSystem")
local gKH = require("src.core.gKH_State_Standalone")
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
    config.red.amphibOps = { zones = {} }
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
      return { sigint = { transmissions = {} }, iads = {}, air = {}, ground = { missileSystemTypes = {} } }
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
      trackStub(stub(MissileSystem, "buildPanelBatteries").returns({}))
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
      assert.is_not_true(saveData.blue.isDeploymentLocked)
    end)

    -- Positive: play mode accepts the first deployment then locks
    it("should lock the deployment after the first play mode submission", function()
      submit(AIRCRAFT_FORM)

      UnitStatusUI.createControlPanel(configFor(false), constants.SIDES.BLUE)

      assert.stub(addAircraftStub).was.called(1)
      assert.is_true(saveData.blue.isDeploymentLocked)
    end)

    -- Negative: a locked deployment ignores later submissions
    it("should ignore a play mode submission once locked", function()
      saveData.blue.isDeploymentLocked = true
      submit(AIRCRAFT_FORM)

      UnitStatusUI.createControlPanel(configFor(false), constants.SIDES.BLUE)

      assert.stub(addAircraftStub).was_not.called()
    end)

    -- Negative: the other side's lock is independent
    it("should not lock the other side", function()
      submit(AIRCRAFT_FORM)

      UnitStatusUI.createControlPanel(configFor(false), constants.SIDES.BLUE)

      assert.is_not_true(saveData.red.isDeploymentLocked)
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

    it("should hand the submitted C2 nodes to the IADS of the side", function()
      local reassignStub = trackStub(stub(IntegratedAirDefenseSystem, "reassignSamUnits"))
      submit({
        summaryData = AIRCRAFT_FORM.summaryData,
        emconData = "'{\"c2Nodes\":[{\"guid\":\"C2-1\",\"type\":\"rocc\",\"name\":\"ROCC-1\",\"sam\":{}}]}'",
      })

      UnitStatusUI.createControlPanel(configFor(true), constants.SIDES.BLUE)

      assert.stub(reassignStub).was.called_with(
        saveData.blue.iads,
        { { guid = "C2-1", type = "rocc", name = "ROCC-1", sam = {} } }
      )
    end)

    it("should leave the IADS alone when the submission has no C2 nodes", function()
      local reassignStub = trackStub(stub(IntegratedAirDefenseSystem, "reassignSamUnits"))
      submit({ summaryData = AIRCRAFT_FORM.summaryData, emconData = "'{\"c2Nodes\":[]}'" })

      UnitStatusUI.createControlPanel(configFor(true), constants.SIDES.BLUE)

      assert.stub(reassignStub).was_not.called()
    end)

    -- Negative: dismissing the dialog neither applies nor locks
    it("should neither apply nor lock when the dialog is dismissed", function()
      dialogStub.returns({})

      UnitStatusUI.createControlPanel(configFor(false), constants.SIDES.BLUE)

      assert.stub(addAircraftStub).was_not.called()
      assert.is_not_true(saveData.blue.isDeploymentLocked)
    end)

    describe("C2 node payload", function()
      local stringifySpy
      ---@type luassert.spy
      local doctrineStub

      ---@param guid string
      ---@param latitude number
      ---@return table
      local function buildUnit(guid, latitude)
        return { guid = guid, latitude = latitude, longitude = 121.5 }
      end

      ---Find the payload the page receives for the C2 nodes: the table keyed by C2 node guid
      ---@param guid string
      ---@return table|nil
      local function findC2Payload(guid)
        for _, call in ipairs(stringifySpy.calls) do
          local payload = call.vals[1]
          if type(payload) == "table" and payload[guid] then
            return payload
          end
        end
        return nil
      end

      before_each(function()
        stringifySpy = trackStub(spy.on(gKH.json, "stringify"))
        saveData.blue.iads = {
          rocc = {
            {
              guid = "C2-1",
              name = "ROCC-1",
              areas = { { "RP-1", "RP-2", "RP-3" } },
              sam = {
                ["SAM-1"] = {
                  guid = "SAM-1",
                  name = "SAM-1",
                  currOODA = { detection = 1, targeting = 2 },
                  OODA = { detection = 3, targeting = 4 },
                  isOutOfComms = false,
                  EMCONSetting = "Green",
                },
                ["SAM-GONE"] = {
                  guid = "SAM-GONE",
                  name = "SAM-GONE",
                  currOODA = { detection = 1, targeting = 2 },
                  OODA = { detection = 3, targeting = 4 },
                },
              },
              radar = {
                ["RAD-1"] = {
                  guid = "RAD-1",
                  name = "RAD-1",
                  currOODA = { detection = 5, targeting = 6 },
                  OODA = { detection = 7, targeting = 8 },
                  isOutOfComms = true,
                  EMCONSetting = "Red",
                },
              },
            },
          },
        }
        local unitMap = {
          ["C2-1"] = buildUnit("C2-1", 24.0),
          ["SAM-1"] = buildUnit("SAM-1", 25.0),
          ["RAD-1"] = buildUnit("RAD-1", 26.0),
        }
        trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid) return unitMap[guid] end))
        doctrineStub = trackStub(stub(GameApi, "ScenEdit_GetDoctrine"))
        doctrineStub.returns({ weapon_control_status_air = constants.WCS.HOLD })
        trackStub(stub(GameApi, "ScenEdit_GetReferencePoints").returns({
          { latitude = "24.5", longitude = "121.25" },
          { latitude = "24.75", longitude = "121.5" },
        }))
      end)

      it("should key each node by guid and carry its type, name and position", function()
        UnitStatusUI.createControlPanel(configFor(true), constants.SIDES.BLUE)

        local node = findC2Payload("C2-1")["C2-1"]
        assert.are.equal("rocc", node.type)
        assert.are.equal("ROCC-1", node.name)
        assert.are.same({ latitude = 24.0, longitude = 121.5 }, node.pos)
      end)

      it("should resolve each area to numeric points", function()
        UnitStatusUI.createControlPanel(configFor(true), constants.SIDES.BLUE)

        local node = findC2Payload("C2-1")["C2-1"]
        assert.are.same({
          {
            { latitude = 24.5, longitude = 121.25 },
            { latitude = 24.75, longitude = 121.5 },
          },
        }, node.areas)
      end)

      it("should describe each SAM with its OODA, comms, doctrine and position", function()
        UnitStatusUI.createControlPanel(configFor(true), constants.SIDES.BLUE)

        local sam = findC2Payload("C2-1")["C2-1"].sam["SAM-1"]
        assert.are.equal("SAM-1", sam.name)
        assert.are.equal("1/3", sam.OODADetection)
        assert.are.equal("2/4", sam.OODATargeting)
        assert.is_false(sam.isOutOfComms)
        assert.are.equal("Green", sam.EMCONSetting)
        assert.is_false(sam.weaponFree)
        assert.are.same({ latitude = 25.0, longitude = 121.5 }, sam.pos)
      end)

      it("should describe each radar without a doctrine", function()
        UnitStatusUI.createControlPanel(configFor(true), constants.SIDES.BLUE)

        local radar = findC2Payload("C2-1")["C2-1"].radar["RAD-1"]
        assert.are.equal("5/7", radar.OODADetection)
        assert.are.equal("6/8", radar.OODATargeting)
        assert.is_true(radar.isOutOfComms)
        assert.is_nil(radar.weaponFree)
        assert.are.same({ latitude = 26.0, longitude = 121.5 }, radar.pos)
      end)

      it("should skip a SAM that no longer exists in the game", function()
        UnitStatusUI.createControlPanel(configFor(true), constants.SIDES.BLUE)

        assert.is_nil(findC2Payload("C2-1")["C2-1"].sam["SAM-GONE"])
      end)

      it("should mark a SAM weapons free when its doctrine is not hold", function()
        doctrineStub.returns({ weapon_control_status_air = constants.WCS.TIGHT })

        UnitStatusUI.createControlPanel(configFor(true), constants.SIDES.BLUE)

        assert.is_true(findC2Payload("C2-1")["C2-1"].sam["SAM-1"].weaponFree)
      end)
    end)
  end)
end)
