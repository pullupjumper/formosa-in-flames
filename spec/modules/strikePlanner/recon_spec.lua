-- Recon Unit Tests
local Recon = require("src.modules.strikePlanner.recon")
local GameApi = require("src.utils.gameApi")
local GameUtils = require("src.utils.gameUtils")
local Logger = require("src.utils.logger")
local OperationScheduler = require("src.modules.strikePlanner.operationScheduler")
local Utils = require("src.utils.utils")
local constants = require("src.core.constants")
local BaseConfig = require("src.core.config")

describe("Recon", function()
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
    for _, s in ipairs(activeStubs) do
      s:revert()
    end
    activeStubs = {}
  end)

  -- ============================================================================
  -- Shared mock data builders
  -- ============================================================================

  ---Create a mock CMO unit
  ---@param overrides? table
  ---@return table
  local function makeUnit(overrides)
    local unit = {
      guid = "UNIT-001",
      name = "BZK-005 #1",
      dbid = constants.PLATFORMS.BZK005,
      readytime_v = 0,
      course = {},
      condition = "Airborne",
      latitude = 25.0,
      longitude = 121.0,
      Launch = function() end,
      RTB = function() end,
    }
    if overrides then
      for k, v in pairs(overrides) do unit[k] = v end
    end
    return unit
  end

  ---Create a mock base unit with embarked aircraft
  ---@param overrides? table
  ---@return table
  local function makeBase(overrides)
    local base = {
      guid = "BASE-001",
      name = "Liuan AB",
      embarkedUnits = {
        Aircraft = { "AC-001", "AC-002", "AC-003" },
        Boats = {},
      },
    }
    if overrides then
      for k, v in pairs(overrides) do base[k] = v end
    end
    return base
  end

  ---Create a UAV reconnaissance queue entry
  ---@param overrides? table
  ---@return table
  local function makeUAVEntry(overrides)
    local entry = {
      type = "UAV",
      baseGUID = "BASE-001",
      unitDBID = constants.PLATFORMS.BZK005,
      course = { { latitude = 24.5, longitude = 120.5 } },
      unitCount = 1,
      speed = 200,
      takeoffTime = "2026-02-14 06:00:00",
      endTime = "2026-02-14 08:00:00",
      hasLaunched = false,
      isFinished = false,
    }
    if overrides then
      for k, v in pairs(overrides) do entry[k] = v end
    end
    return entry
  end

  ---Create a satellite reconnaissance queue entry
  ---@param overrides? table
  ---@return table
  local function makeSatelliteEntry(overrides)
    local entry = {
      type = "satellite",
      reconObjectiveId = "FIXED_SITE_TARGETING",
      endTime = "2026-02-14 08:00:00",
      isFinished = false,
    }
    if overrides then
      for k, v in pairs(overrides) do entry[k] = v end
    end
    return entry
  end

  ---Create a SIGINT reconnaissance queue entry
  ---@param overrides? table
  ---@return table
  local function makeSIGINTEntry(overrides)
    local entry = {
      type = "SIGINT",
      reconObjectiveId = "C2_EMITTER_TARGETING",
      endTime = "2026-02-14 08:00:00",
      isFinished = false,
    }
    if overrides then
      for k, v in pairs(overrides) do entry[k] = v end
    end
    return entry
  end

  ---Create a minimal reconContext
  ---@param queue? table[]
  ---@param overrides? table
  ---@return table
  local function makeReconContext(queue, overrides)
    local ctx = { queue = queue or {}, frontlineRedirected = false }
    if overrides then
      for k, v in pairs(overrides) do ctx[k] = v end
    end
    return ctx
  end

  ---Create a minimal config for buildOperationsForReconObjective / scheduleDynamicReconOperations
  ---@param overrides? table
  ---@return SBJ__Config
  local function makeConfig(overrides)
    local cfg = Utils.deepCopy(BaseConfig) --[[@as SBJ__Config]]
    cfg.c.recon.strikeMappingsByReconObjective = {
      C2_NORTH_TARGETING = {
        { name = "GND/STRIKE/C2/N/1", type = "ground" },
      },
    }
    cfg.c.recon.frontlineRedirect = {
      enabled = false,
      attritionThresholdPct = 50,
      frontlineBaseNames = {},
      mappings = {
        { fromPrefix = "AIR/STRIKE/AB/W/", toPrefix = "AIR/STRIKE/AB/W/AAR/", type = "air" },
      },
    }
    cfg.c.packageTemplates = {}
    cfg.c.fireSupportTaskTemplates = {
      STRIKE_C2_2 = { {
        name = "FST-C2-2",
        firingUnits = {},
        missileSystem = '',
        target = { list = {}, contactAge = 0, minTargetCount = 1 },
      } },
    }
    if overrides then
      for k, v in pairs(overrides) do cfg[k] = v end
    end
    return cfg
  end

  ---Create a minimal LACMContext
  ---@param enabled? boolean
  ---@return table
  local function makeLACMContext(enabled)
    return { enabled = enabled or false, startTime = "2026-02-14 06:00:00" }
  end

  ---Find a Logger.log call matching the given tag and message pattern
  ---@param logTag string Module name tag to match
  ---@param pattern string Lua pattern to search for in the message
  ---@return boolean # Whether a matching call was found
  local function hasLogCall(logTag, pattern)
    for _, call in ipairs(logStub.calls) do
      if call.vals[1] == logTag and string.find(call.vals[2], pattern) then
        return true
      end
    end
    return false
  end

  ---Find a Logger.error call matching the given pattern
  ---@param pattern string Lua pattern to search for in the message
  ---@return boolean # Whether a matching call was found
  local function hasErrorCall(pattern)
    for _, call in ipairs(errorStub.calls) do
      if string.find(call.vals[1], pattern) then
        return true
      end
    end
    return false
  end

  -- ============================================================================
  -- launchWZ8
  -- ============================================================================

  describe("launchWZ8", function()
    local h6n
    local wz8Course = { { latitude = 24.0, longitude = 120.0 } }

    before_each(function()
      h6n = makeUnit({
        guid = "H6N-001",
        name = "H-6N #1",
        latitude = 26.0,
        longitude = 119.0,
      })
    end)

    -- Positive: successful WZ-8 launch
    it("should create WZ-8, add sensor, set EMCON, and RTB the H-6N", function()
      local wz8 = makeUnit({ guid = "WZ8-001", name = "WZ-8" })

      local addUnitStub = trackStub(stub(GameApi, "ScenEdit_AddUnit").returns(wz8))
      local updateUnitStub = trackStub(stub(GameApi, "ScenEdit_UpdateUnit").returns(wz8))
      local setEMCONStub = trackStub(stub(GameApi, "ScenEdit_SetEMCON").returns(true))
      local rtbSpy = spy.on(h6n, "RTB")

      local result = Recon.launchWZ8(h6n, wz8Course)

      assert.is_not_nil(result)
      assert(result ~= nil)
      assert.are.equal("WZ8-001", result.guid)
      assert.are.same(wz8Course, result.course)
      assert.spy(rtbSpy).was.called_with(h6n, true)

      -- Verify AddUnit params
      local addCall = addUnitStub.calls[1].vals[1]
      assert.are.equal("China", addCall.side)
      assert.are.equal(constants.PLATFORMS.WZ8, addCall.dbid)
      assert.are.equal(constants.LOADOUTS.WZ8_RECON, addCall.loadoutid)
      assert.are.equal(26.0, addCall.latitude)
      assert.are.equal(119.0, addCall.longitude)

      -- Verify UpdateUnit params
      local updateCall = updateUnitStub.calls[1].vals[1]
      assert.are.equal("WZ8-001", updateCall.guid)
      assert.are.equal("add_sensor", updateCall.mode)
      assert.are.equal(constants.SENSORS.WZ8_RADAR, updateCall.dbid)

      -- Verify EMCON call
      assert.stub(setEMCONStub).was.called_with("Unit", "WZ8-001", "Radar=Active")
    end)

    -- Negative: AddUnit fails
    it("should return nil when ScenEdit_AddUnit fails", function()
      trackStub(stub(GameApi, "ScenEdit_AddUnit").returns(nil))

      local result = Recon.launchWZ8(h6n, wz8Course)

      assert.is_nil(result)
    end)

    -- Negative: UpdateUnit fails
    it("should return nil when ScenEdit_UpdateUnit fails", function()
      local wz8 = makeUnit({ guid = "WZ8-001" })
      trackStub(stub(GameApi, "ScenEdit_AddUnit").returns(wz8))
      trackStub(stub(GameApi, "ScenEdit_UpdateUnit").returns(nil))

      local result = Recon.launchWZ8(h6n, wz8Course)

      assert.is_nil(result)
    end)

    -- Negative: SetEMCON fails
    it("should return nil when ScenEdit_SetEMCON fails", function()
      local wz8 = makeUnit({ guid = "WZ8-001" })
      trackStub(stub(GameApi, "ScenEdit_AddUnit").returns(wz8))
      trackStub(stub(GameApi, "ScenEdit_UpdateUnit").returns(wz8))
      trackStub(stub(GameApi, "ScenEdit_SetEMCON").returns(nil))

      local result = Recon.launchWZ8(h6n, wz8Course)

      assert.is_nil(result)
    end)
  end)

  -- ============================================================================
  -- processQueue
  -- ============================================================================

  describe("processQueue", function()
    local config, reconTriggeredOperations, LACMContext

    before_each(function()
      config = makeConfig()
      reconTriggeredOperations = {}
      LACMContext = makeLACMContext()
    end)

    ---Create a reconnaissance queue processing context
    ---@param reconContext table Reconnaissance runtime context
    ---@param fireSupportOnHold? boolean Whether SRBM-driven mappings should be skipped
    ---@return SBJ__ReconQueueProcessingContext
    local function makeProcessingContext(reconContext, fireSupportOnHold)
      return {
        config = config,
        reconContext = reconContext,
        reconTriggeredOperations = reconTriggeredOperations,
        LACMContext = LACMContext,
        fireSupportOnHold = fireSupportOnHold == true
      }
    end

    -- ========================================================================
    -- UAV Phase 1: Launch
    -- ========================================================================

    it("should launch UAV when takeoff time has been reached", function()
      local ac = makeUnit({ guid = "AC-001" })
      local base = makeBase({ embarkedUnits = { Aircraft = { "AC-001" } } })
      local entry = makeUAVEntry()

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
        if guid == "BASE-001" then return base end
        if guid == "AC-001" then return ac end
        return nil
      end))
      trackStub(stub(GameApi, "ScenEdit_SetDoctrine"))

      local reconContext = makeReconContext({ entry })
      Recon.processQueue(makeProcessingContext(reconContext))

      assert.is_true(entry.hasLaunched)
      assert.are.equal("AC-001", entry.unitGUID)
    end)

    it("should not launch UAV before takeoff time", function()
      local entry = makeUAVEntry()

      trackStub(stub(GameUtils, "isAfterStartTime").returns(false))

      local reconContext = makeReconContext({ entry })
      Recon.processQueue(makeProcessingContext(reconContext))

      assert.is_false(entry.hasLaunched)
      assert.is_nil(entry.unitGUID)
    end)

    it("should skip already launched UAV entries in launch phase", function()
      local entry = makeUAVEntry({ hasLaunched = true, unitGUID = "AC-001" })
      local ac = makeUnit({ guid = "AC-001", course = { { latitude = 24.5 } } })

      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(ac))
      trackStub(stub(GameUtils, "isAfterStartTime").returns(false))

      local reconContext = makeReconContext({ entry })
      Recon.processQueue(makeProcessingContext(reconContext))

      -- Should proceed to phase 2, not re-launch
      assert.is_true(entry.hasLaunched)
    end)

    -- ========================================================================
    -- UAV Phase 2: In-flight monitoring
    -- ========================================================================

    it("should continue monitoring when UAV is still flying course", function()
      local entry = makeUAVEntry({ hasLaunched = true, unitGUID = "AC-001" })
      local ac = makeUnit({ guid = "AC-001", course = { { latitude = 24.5 } } })

      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(ac))
      trackStub(stub(GameUtils, "isAfterStartTime").returns(false))

      local reconContext = makeReconContext({ entry })
      Recon.processQueue(makeProcessingContext(reconContext))

      assert.is_false(entry.isFinished)
    end)

    it("should log and wait when course complete but endTime not reached", function()
      local entry = makeUAVEntry({ hasLaunched = true, unitGUID = "AC-001" })
      local ac = makeUnit({ guid = "AC-001", course = {} })

      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(ac))
      trackStub(stub(GameUtils, "isAfterStartTime").returns(false))

      local reconContext = makeReconContext({ entry })
      Recon.processQueue(makeProcessingContext(reconContext))

      assert.is_false(entry.isFinished)
    end)

    -- ========================================================================
    -- UAV destroyed scenarios
    -- ========================================================================

    it("should mark mission as failed when UAV destroyed before endTime", function()
      local entry = makeUAVEntry({ hasLaunched = true, unitGUID = "AC-001" })

      -- GetUnit returns nil (destroyed), isAfterStartTime returns false (before endTime)
      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(nil))
      trackStub(stub(GameUtils, "isAfterStartTime").returns(false))

      local reconContext = makeReconContext({ entry })
      Recon.processQueue(makeProcessingContext(reconContext))

      assert.is_true(entry.isFinished)
      -- No dynamic operations scheduled (mission failed)
      assert.are.equal(0, #reconTriggeredOperations)
    end)

    it("should mark mission as successful when UAV destroyed after endTime", function()
      local entry = makeUAVEntry({ hasLaunched = true, unitGUID = "AC-001" })

      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(nil))
      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(OperationScheduler, "getLastExecutedOperationsAndNextTime").returns({
        air = {}, ground = {}, mostRecentTime = nil, nextReconTime = nil,
      }))
      trackStub(stub(OperationScheduler, "hasOperation").returns(false))

      local reconContext = makeReconContext({ entry })
      Recon.processQueue(makeProcessingContext(reconContext))

      assert.is_true(entry.isFinished)
    end)

    -- ========================================================================
    -- UAV mission completion (normal mode)
    -- ========================================================================

    it("should finish mission successfully when course and endTime completed", function()
      local entry = makeUAVEntry({ hasLaunched = true, unitGUID = "AC-001" })
      local ac = makeUnit({ guid = "AC-001", course = {} })

      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(ac))
      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(OperationScheduler, "getLastExecutedOperationsAndNextTime").returns({
        air = {}, ground = {}, mostRecentTime = nil, nextReconTime = nil,
      }))
      trackStub(stub(OperationScheduler, "hasOperation").returns(false))

      local reconContext = makeReconContext({ entry })
      Recon.processQueue(makeProcessingContext(reconContext))

      assert.is_true(entry.isFinished)
    end)

    -- ========================================================================
    -- UAV tracking mode
    -- ========================================================================

    it("should update course when tracking target successfully", function()
      local entry = makeUAVEntry({
        hasLaunched = true,
        unitGUID = "AC-001",
        isTracking = true,
        trackingTargetGUID = "CONTACT-001",
        speed = 300,
      })
      local ac = makeUnit({ guid = "AC-001", course = {} })
      local target = { guid = "CONTACT-001", latitude = 23.0, longitude = 119.0 }

      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(ac))
      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(GameApi, "ScenEdit_GetContact").returns(target))

      local reconContext = makeReconContext({ entry })
      Recon.processQueue(makeProcessingContext(reconContext))

      -- Should update course to target position
      assert.are.equal(1, #ac.course)
      assert.are.equal(23.0, ac.course[1].latitude)
      assert.are.equal(119.0, ac.course[1].longitude)
      assert.are.equal(300, ac.course[1].desiredSpeed)
      assert.are.equal("Military", ac.course[1].presetThrottle)
      -- Should NOT be finished (still tracking)
      assert.is_false(entry.isFinished)
    end)

    it("should finish mission when tracking target is lost", function()
      local entry = makeUAVEntry({
        hasLaunched = true,
        unitGUID = "AC-001",
        isTracking = true,
        trackingTargetGUID = "CONTACT-001",
        speed = 300,
      })
      local ac = makeUnit({ guid = "AC-001", course = {} })

      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(ac))
      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(GameApi, "ScenEdit_GetContact").returns(nil))
      trackStub(stub(OperationScheduler, "getLastExecutedOperationsAndNextTime").returns({
        air = {}, ground = {}, mostRecentTime = nil, nextReconTime = nil,
      }))
      trackStub(stub(OperationScheduler, "hasOperation").returns(false))

      local reconContext = makeReconContext({ entry })
      Recon.processQueue(makeProcessingContext(reconContext))

      assert.is_true(entry.isFinished)
    end)

    it("should complete normally when isTracking set but no trackingTargetGUID", function()
      local entry = makeUAVEntry({
        hasLaunched = true,
        unitGUID = "AC-001",
        isTracking = true,
        trackingTargetGUID = nil,
        speed = 300,
      })
      local ac = makeUnit({ guid = "AC-001", course = {} })

      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(ac))
      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(OperationScheduler, "getLastExecutedOperationsAndNextTime").returns({
        air = {}, ground = {}, mostRecentTime = nil, nextReconTime = nil,
      }))
      trackStub(stub(OperationScheduler, "hasOperation").returns(false))

      local reconContext = makeReconContext({ entry })
      Recon.processQueue(makeProcessingContext(reconContext))

      -- Tracking failed => settleReconMission called with success=true
      assert.is_true(entry.isFinished)
    end)

    it("should finish mission via tracking failure when no speed configured", function()
      local entry = makeUAVEntry({
        hasLaunched = true,
        unitGUID = "AC-001",
        isTracking = true,
        trackingTargetGUID = "CONTACT-001",
        speed = nil,
      })
      local ac = makeUnit({ guid = "AC-001", course = {} })

      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(ac))
      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(OperationScheduler, "getLastExecutedOperationsAndNextTime").returns({
        air = {}, ground = {}, mostRecentTime = nil, nextReconTime = nil,
      }))
      trackStub(stub(OperationScheduler, "hasOperation").returns(false))

      local reconContext = makeReconContext({ entry })
      Recon.processQueue(makeProcessingContext(reconContext))

      assert.is_true(entry.isFinished)
    end)

    -- ========================================================================
    -- Double execution prevention
    -- ========================================================================

    it("should not execute settleReconMission twice for same entry", function()
      local entry = makeUAVEntry({
        hasLaunched = true,
        unitGUID = "AC-001",
        isFinished = true, -- Already finished
      })

      local reconContext = makeReconContext({ entry })
      Recon.processQueue(makeProcessingContext(reconContext))

      -- isFinished should remain true, no additional scheduling
      assert.is_true(entry.isFinished)
      assert.are.equal(0, #reconTriggeredOperations)
    end)

    -- ========================================================================
    -- Satellite entry processing
    -- ========================================================================

    it("should finish satellite mission when endTime reached", function()
      local entry = makeSatelliteEntry()

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(OperationScheduler, "getLastExecutedOperationsAndNextTime").returns({
        air = {}, ground = {}, mostRecentTime = nil, nextReconTime = nil,
      }))

      local reconContext = makeReconContext({ entry })
      Recon.processQueue(makeProcessingContext(reconContext))

      assert.is_true(entry.isFinished)
    end)

    it("should not finish satellite mission before endTime", function()
      local entry = makeSatelliteEntry()

      trackStub(stub(GameUtils, "isAfterStartTime").returns(false))

      local reconContext = makeReconContext({ entry })
      Recon.processQueue(makeProcessingContext(reconContext))

      assert.is_false(entry.isFinished)
    end)

    it("should skip already finished satellite entry", function()
      local entry = makeSatelliteEntry({ isFinished = true })

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))

      local reconContext = makeReconContext({ entry })
      Recon.processQueue(makeProcessingContext(reconContext))

      -- Should not schedule duplicate operations
      assert.are.equal(0, #reconTriggeredOperations)
    end)

    it("should finish SIGINT mission when endTime reached", function()
      local entry = makeSIGINTEntry()

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(OperationScheduler, "getLastExecutedOperationsAndNextTime").returns({
        air = {}, ground = {}, mostRecentTime = nil, nextReconTime = nil,
      }))

      local reconContext = makeReconContext({ entry })
      Recon.processQueue(makeProcessingContext(reconContext))

      assert.is_true(entry.isFinished)
    end)

    -- ========================================================================
    -- Mixed queue processing
    -- ========================================================================

    it("should process UAV and satellite entries independently", function()
      local uavEntry = makeUAVEntry()
      local satEntry = makeSatelliteEntry()

      trackStub(stub(GameUtils, "isAfterStartTime").invokes(function(time)
        -- UAV takeoff time not reached, satellite endTime reached
        if time == uavEntry.takeoffTime then return false end
        if time == satEntry.endTime then return true end
        return false
      end))
      trackStub(stub(OperationScheduler, "getLastExecutedOperationsAndNextTime").returns({
        air = {}, ground = {}, mostRecentTime = nil, nextReconTime = nil,
      }))

      local reconContext = makeReconContext({ uavEntry, satEntry })
      Recon.processQueue(makeProcessingContext(reconContext))

      assert.is_false(uavEntry.hasLaunched)
      assert.is_true(satEntry.isFinished)
    end)

    -- ========================================================================
    -- Dynamic operations scheduling on mission completion
    -- ========================================================================

    it("should schedule new operations when mission completes with matching strike mappings", function()
      local entry = makeUAVEntry({
        hasLaunched = true,
        unitGUID = "AC-001",
        templateId = "BZK005_RECON_1",
        reconObjectiveId = "C2_NORTH_TARGETING",
      })
      local ac = makeUnit({ guid = "AC-001", course = {} })

      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(ac))
      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(OperationScheduler, "getLastExecutedOperationsAndNextTime").returns({
        air = {}, ground = {}, mostRecentTime = nil, nextReconTime = nil,
      }))
      trackStub(stub(OperationScheduler, "hasOperation").returns(false))
      trackStub(stub(OperationScheduler, "generateNextOperation").returns(
        { type = "ground", executed = false, template = { name = "STRIKE/C2/2" } }, "FOUND_NEXT"
      ))

      local reconContext = makeReconContext({ entry })
      Recon.processQueue(makeProcessingContext(reconContext))

      assert.is_true(entry.isFinished)
      -- Should have scheduled operations (STRIKE/C2/1 new + STRIKE/C2/2 next)
      assert.is_true(#reconTriggeredOperations > 0)
    end)

    it("should skip AIR/STRIKE/AB/E/1 when LACM is not enabled", function()
      local cfg = makeConfig()
      cfg.c.recon.strikeMappingsByReconObjective.C2_NORTH_TARGETING = {
        { name = "AIR/STRIKE/AB/E/1", type = "air" },
      }

      local entry = makeUAVEntry({
        hasLaunched = true,
        unitGUID = "AC-001",
        templateId = "BZK005_RECON_1",
        reconObjectiveId = "C2_NORTH_TARGETING",
      })
      local ac = makeUnit({ guid = "AC-001", course = {} })

      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(ac))
      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(OperationScheduler, "getLastExecutedOperationsAndNextTime").returns({
        air = {}, ground = {}, mostRecentTime = nil, nextReconTime = nil,
      }))
      trackStub(stub(OperationScheduler, "hasOperation").returns(false))

      local reconContext = makeReconContext({ entry })
      Recon.processQueue(makeProcessingContext(reconContext))

      -- LACM not enabled => AIR/STRIKE/AB/E/1 skipped => no operations
      assert.is_true(entry.isFinished)
    end)

    it("should not schedule operations when mission fails", function()
      local entry = makeUAVEntry({ hasLaunched = true, unitGUID = "AC-001" })

      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(nil))
      trackStub(stub(GameUtils, "isAfterStartTime").returns(false))

      local reconContext = makeReconContext({ entry })
      Recon.processQueue(makeProcessingContext(reconContext))

      assert.is_true(entry.isFinished)
      assert.are.equal(0, #reconTriggeredOperations)
    end)

    -- ========================================================================
    -- Batched logging
    -- ========================================================================

    it("should batch log [OK] via Logger.log when UAV launches successfully", function()
      local ac = makeUnit({ guid = "AC-001" })
      local base = makeBase({ embarkedUnits = { Aircraft = { "AC-001" } } })
      local entry = makeUAVEntry()

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
        if guid == "BASE-001" then return base end
        if guid == "AC-001" then return ac end
        return nil
      end))
      trackStub(stub(GameApi, "ScenEdit_SetDoctrine"))

      local reconContext = makeReconContext({ entry })
      Recon.processQueue(makeProcessingContext(reconContext))

      assert.is_true(hasLogCall("recon", "%[OK%]"))
      assert.stub(errorStub).was_not.called()
    end)

    it("should batch log [SKIP] via Logger.log when UAV is not ready for launch", function()
      local entry = makeUAVEntry()

      trackStub(stub(GameUtils, "isAfterStartTime").returns(false))

      local reconContext = makeReconContext({ entry })
      Recon.processQueue(makeProcessingContext(reconContext))

      assert.is_true(hasLogCall("recon", "%[SKIP%]"))
      assert.stub(errorStub).was_not.called()
    end)

    it("should batch log [FAIL] via Logger.error when UAV destroyed before endTime", function()
      local entry = makeUAVEntry({ hasLaunched = true, unitGUID = "AC-001" })

      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(nil))
      trackStub(stub(GameUtils, "isAfterStartTime").returns(false))

      local reconContext = makeReconContext({ entry })
      Recon.processQueue(makeProcessingContext(reconContext))

      assert.is_true(hasErrorCall("%[FAIL%]"))
    end)

    it("should batch log [OK] via Logger.log for satellite completion", function()
      local entry = makeSatelliteEntry()

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(OperationScheduler, "getLastExecutedOperationsAndNextTime").returns({
        air = {}, ground = {}, mostRecentTime = nil, nextReconTime = nil,
      }))

      local reconContext = makeReconContext({ entry })
      Recon.processQueue(makeProcessingContext(reconContext))

      assert.is_true(hasLogCall("recon", "%[OK%]"))
      assert.stub(errorStub).was_not.called()
    end)

    it("should not emit any recon log when all entries are already finished", function()
      local entry1 = makeUAVEntry({ hasLaunched = true, unitGUID = "AC-001", isFinished = true })
      local entry2 = makeSatelliteEntry({ isFinished = true })

      local reconContext = makeReconContext({ entry1, entry2 })
      Recon.processQueue(makeProcessingContext(reconContext))

      assert.is_false(hasLogCall("recon", "."))
      assert.stub(errorStub).was_not.called()
    end)
  end)

  -- ============================================================================
  -- trackTarget
  -- ============================================================================

  describe("trackTarget", function()
    local UAVDBID = constants.PLATFORMS.BZK005
    local target = { guid = "CONTACT-001", latitude = 23.0, longitude = 119.0 }

    -- Positive: return true when UAV already tracking same target
    it("should return true when UAV already assigned to track same target", function()
      local entry = makeUAVEntry({
        hasLaunched = true,
        unitGUID = "AC-001",
        trackingTargetGUID = "CONTACT-001",
      })
      local ac = makeUnit({ guid = "AC-001" })

      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(ac))

      local reconContext = makeReconContext({ entry })
      local result = Recon.trackTarget(reconContext, {}, UAVDBID, target)

      assert.is_true(result)
    end)

    -- Negative: already tracking but UAV destroyed
    it("should not return early when tracked UAV is destroyed", function()
      local entry = makeUAVEntry({
        hasLaunched = true,
        unitGUID = "AC-001",
        trackingTargetGUID = "CONTACT-001",
      })

      -- UAV in queue is destroyed
      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(nil))

      local reconContext = makeReconContext({ entry })
      local result = Recon.trackTarget(reconContext, {}, UAVDBID, target)

      -- No available UAV => false
      assert.is_false(result)
    end)

    -- Positive: assign closest available UAV to track target
    it("should assign closest available UAV from units list", function()
      local farUAV = makeUnit({
        guid = "UAV-FAR",
        dbid = UAVDBID,
        condition = "Airborne",
        latitude = 28.0,
        longitude = 122.0,
      })
      local closeUAV = makeUnit({
        guid = "UAV-CLOSE",
        dbid = UAVDBID,
        condition = "Airborne",
        latitude = 23.5,
        longitude = 119.5,
      })
      local queueEntry = makeUAVEntry({
        hasLaunched = true, unitGUID = "UAV-CLOSE",
      })

      trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
        if guid == "UAV-FAR" then return farUAV end
        if guid == "UAV-CLOSE" then return closeUAV end
        return nil
      end))
      trackStub(stub(GameApi, "Tool_Range").invokes(function(pos)
        if pos.latitude == 28.0 then return 500 end -- farUAV
        return 100                                  -- closeUAV
      end))

      local units = {
        { guid = "UAV-FAR" },
        { guid = "UAV-CLOSE" },
      }
      local reconContext = makeReconContext({ queueEntry })
      local result = Recon.trackTarget(reconContext, units, UAVDBID, target)

      assert.is_true(result)
      assert.is_true(queueEntry.isTracking)
      assert.are.equal("CONTACT-001", queueEntry.trackingTargetGUID)
      assert.is_false(queueEntry.isFinished) -- Reactivated
    end)

    -- Negative: no airborne UAVs
    it("should return false when no airborne UAVs available", function()
      local groundedUAV = makeUnit({
        guid = "UAV-001", dbid = UAVDBID, condition = "Landed",
      })

      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(groundedUAV))

      local units = { { guid = "UAV-001" } }
      local reconContext = makeReconContext({})
      local result = Recon.trackTarget(reconContext, units, UAVDBID, target)

      assert.is_false(result)
    end)

    -- Negative: UAVs available but wrong DBID
    it("should return false when available UAVs have wrong DBID", function()
      local wrongUAV = makeUnit({
        guid = "UAV-001", dbid = 9999, condition = "Airborne",
      })

      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(wrongUAV))

      local units = { { guid = "UAV-001" } }
      local reconContext = makeReconContext({})
      local result = Recon.trackTarget(reconContext, units, UAVDBID, target)

      assert.is_false(result)
    end)

    -- Negative: UAV found but not in recon queue
    it("should return false when closest UAV is not in recon queue", function()
      local uav = makeUnit({
        guid = "UAV-NOTINQUEUE", dbid = UAVDBID, condition = "Airborne",
      })

      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(uav))
      trackStub(stub(GameApi, "Tool_Range").returns(50))

      local units = { { guid = "UAV-NOTINQUEUE" } }
      local reconContext = makeReconContext({}) -- Empty queue
      local result = Recon.trackTarget(reconContext, units, UAVDBID, target)

      assert.is_false(result)
    end)

    -- Boundary: UAV distance exceeds max threshold (1000)
    it("should not select UAV beyond max distance threshold", function()
      local farUAV = makeUnit({
        guid = "UAV-001", dbid = UAVDBID, condition = "Airborne",
      })

      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(farUAV))
      trackStub(stub(GameApi, "Tool_Range").returns(1500))

      local units = { { guid = "UAV-001" } }
      local reconContext = makeReconContext({})
      local result = Recon.trackTarget(reconContext, units, UAVDBID, target)

      assert.is_false(result)
    end)

    -- Boundary: Tool_Range returns nil
    it("should skip UAV when Tool_Range returns nil", function()
      local uav = makeUnit({
        guid = "UAV-001", dbid = UAVDBID, condition = "Airborne",
      })

      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(uav))
      trackStub(stub(GameApi, "Tool_Range").returns(nil))

      local units = { { guid = "UAV-001" } }
      local reconContext = makeReconContext({})
      local result = Recon.trackTarget(reconContext, units, UAVDBID, target)

      assert.is_false(result)
    end)

    -- Boundary: satellite entries in queue should be ignored during tracking lookup
    it("should ignore satellite entries when looking for tracked UAV", function()
      local satEntry = makeSatelliteEntry({ trackingTargetGUID = "CONTACT-001" })

      local reconContext = makeReconContext({ satEntry })
      -- No units available
      local result = Recon.trackTarget(reconContext, {}, UAVDBID, target)

      assert.is_false(result)
    end)

    -- Boundary: GetUnit returns nil for unit in units list
    it("should skip units that return nil from GetUnit", function()
      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(nil))

      local units = { { guid = "UAV-001" } }
      local reconContext = makeReconContext({})
      local result = Recon.trackTarget(reconContext, units, UAVDBID, target)

      assert.is_false(result)
    end)
  end)

  -- ============================================================================
  -- initReconQueueEntries
  -- ============================================================================

  describe("initReconQueueEntries", function()
    -- Positive: initialize UAV entries
    it("should set hasLaunched and isFinished to false for UAV entries", function()
      local reconConfig = {
        queue = {
          {
            type = "UAV",
            baseGUID = "BASE-001",
            unitDBID = constants.PLATFORMS.BZK005,
            course = { { latitude = 24.5 } },
            unitCount = 1,
            speed = 200,
            takeoffTime = "2026-02-14 06:00:00",
            endTime = "2026-02-14 08:00:00",
          },
        },
      }
      local reconContext = {}

      Recon.initReconQueueEntries(reconConfig, reconContext)

      assert.is_table(reconContext.queue)
      assert.are.equal(1, #reconContext.queue)
      assert.is_false(reconContext.queue[1].hasLaunched)
      assert.is_false(reconContext.queue[1].isFinished)
    end)

    -- Positive: initialize satellite entries
    it("should set isFinished to false for satellite entries", function()
      local reconConfig = {
        queue = {
          { type = "satellite", endTime = "2026-02-14 08:00:00" },
        },
      }
      local reconContext = {}

      Recon.initReconQueueEntries(reconConfig, reconContext)

      assert.is_table(reconContext.queue)
      assert.are.equal(1, #reconContext.queue)
      assert.is_false(reconContext.queue[1].isFinished)
    end)

    it("should set isFinished to false for SIGINT entries", function()
      local reconConfig = {
        queue = {
          { type = "SIGINT", endTime = "2026-02-14 08:00:00" },
        },
      }
      local reconContext = {}

      Recon.initReconQueueEntries(reconConfig, reconContext)

      assert.is_table(reconContext.queue)
      assert.are.equal(1, #reconContext.queue)
      assert.is_false(reconContext.queue[1].isFinished)
    end)

    -- Positive: mixed queue
    it("should initialize both UAV and satellite entries in mixed queue", function()
      local reconConfig = {
        queue = {
          {
            type = "UAV",
            baseGUID = "BASE-001",
            unitDBID = constants.PLATFORMS.BZK005,
            course = {},
            unitCount = 1,
            speed = 200,
          },
          { type = "satellite", endTime = "2026-02-14 10:00:00" },
          {
            type = "UAV",
            baseGUID = "BASE-002",
            unitDBID = constants.PLATFORMS.BZK005,
            course = {},
            unitCount = 2,
            speed = 250,
          },
        },
      }
      local reconContext = {}

      Recon.initReconQueueEntries(reconConfig, reconContext)

      assert.are.equal(3, #reconContext.queue)
      assert.is_false(reconContext.queue[1].hasLaunched)
      assert.is_false(reconContext.queue[1].isFinished)
      assert.is_false(reconContext.queue[2].isFinished)
      assert.is_false(reconContext.queue[3].hasLaunched)
      assert.is_false(reconContext.queue[3].isFinished)
    end)

    -- Boundary: empty queue
    it("should handle empty queue config", function()
      local reconConfig = { queue = {} }
      local reconContext = {}

      Recon.initReconQueueEntries(reconConfig, reconContext)

      assert.is_table(reconContext.queue)
      assert.are.equal(0, #reconContext.queue)
    end)

    -- Boundary: deep copy is used (original not mutated)
    it("should deep copy the config queue to avoid mutating the original", function()
      local reconConfig = { queue = { { type = "satellite", endTime = "2026-02-14 08:00:00" } } }
      local reconContext = {}
      local deepCopySpy = trackStub(spy.on(Utils, "deepCopy"))
      Recon.initReconQueueEntries(reconConfig, reconContext)

      assert.spy(deepCopySpy).was.called()
      -- Original should not have isFinished field
      assert.is_nil(reconConfig.queue[1].isFinished)
    end)
  end)

  -- ============================================================================
  -- insertEntry (UAV insertion into satellite reconnaissance gaps)
  -- ============================================================================

  describe("insertEntry", function()
    -- Fixed timeline (all timestamps are abstract numbers mapped from datetime strings,
    -- keeping tests timezone-independent):
    --   most recent pass end = 4000, current = 5000, next pass end = 8000
    local CURRENT_TIMESTAMP = 5000
    local TIMESTAMPS = {
      ["2026-02-14 03:00:00"] = 3000, -- old UAV takeoff (outside window)
      ["2026-02-14 03:30:00"] = 3500, -- old UAV end (outside window)
      ["2026-02-14 04:00:00"] = 4000, -- most recent satellite pass end
      ["2026-02-14 05:30:00"] = 5500, -- in-window UAV takeoff
      ["2026-02-14 07:00:00"] = 7000, -- in-window UAV end
      ["2026-02-14 08:00:00"] = 8000, -- next satellite pass end
    }

    ---Create a UAV queue entry template (no runtime fields)
    ---@param overrides? table
    ---@return table
    local function makeUAVTemplate(overrides)
      local template = {
        templateId = "TEST_RECON_1",
        type = "UAV",
        baseGUID = "BASE-001",
        unitDBID = constants.PLATFORMS.BZK005,
        course = { { latitude = 24.5, longitude = 120.5 } },
        unitCount = 1,
        speed = 200,
      }
      if overrides then
        for k, v in pairs(overrides) do template[k] = v end
      end
      return template
    end

    ---Stub time helpers so insertEntry sees the fixed timeline above
    ---@param flightTime number Flight time (seconds) returned for the template course
    local function stubTimeline(flightTime)
      trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(CURRENT_TIMESTAMP))
      trackStub(stub(GameUtils, "calculatePathDistanceAndTime").returns(100, flightTime))
      trackStub(stub(Utils, "parseDatetimeToTimestamp").invokes(function(datetimeStr)
        local timestamp = TIMESTAMPS[datetimeStr]
        if not timestamp then
          error("No test timestamp mapping for: " .. tostring(datetimeStr))
        end
        return timestamp
      end))
    end

    -- Positive: gap exists and the UAV lands by the next satellite pass
    it("should insert UAV entry when flight ends by the next pass", function()
      stubTimeline(2500) -- UAV end = 7500 <= next pass end 8000
      local queue = {
        makeSatelliteEntry({ endTime = "2026-02-14 04:00:00", isFinished = true }),
        makeSatelliteEntry({ endTime = "2026-02-14 08:00:00" }),
      }
      local reconContext = makeReconContext(queue)
      local template = makeUAVTemplate()

      local result = Recon.insertEntry(reconContext, template)

      assert.is_not_nil(result)
      assert.are.equal(3, #reconContext.queue)
      local inserted = reconContext.queue[3]
      assert.are.equal("UAV", inserted.type)
      assert.is_false(inserted.hasLaunched)
      assert.is_false(inserted.isFinished)
      assert.is_nil(inserted.trackingTargetGUID)
      assert.are.equal(os.date(constants.DATE_FORMAT, CURRENT_TIMESTAMP), inserted.takeoffTime)
      assert.are.equal(os.date(constants.DATE_FORMAT, CURRENT_TIMESTAMP + 2500), inserted.endTime)
    end)

    -- Positive: inserted entry is a deep copy; the template stays untouched
    it("should not mutate the entry template on insertion", function()
      stubTimeline(2500)
      local queue = {
        makeSatelliteEntry({ endTime = "2026-02-14 04:00:00", isFinished = true }),
        makeSatelliteEntry({ endTime = "2026-02-14 08:00:00" }),
      }
      local reconContext = makeReconContext(queue)
      local template = makeUAVTemplate()

      local result = Recon.insertEntry(reconContext, template)

      assert.is_not_nil(result)
      assert.are_not.equal(template, reconContext.queue[3])
      assert.is_nil(template.hasLaunched)
      assert.is_nil(template.takeoffTime)
      assert.is_nil(template.endTime)
    end)

    -- Positive: an explicit startTime anchors the flight window instead of current time
    it("should anchor takeoff and end times to the provided startTime", function()
      -- current=5000 is ignored; startTime=5500, flight 2000 => end 7500 <= next pass 8000
      stubTimeline(2000)
      local queue = {
        makeSatelliteEntry({ endTime = "2026-02-14 04:00:00", isFinished = true }),
        makeSatelliteEntry({ endTime = "2026-02-14 08:00:00" }),
      }
      local reconContext = makeReconContext(queue)

      local result = Recon.insertEntry(reconContext, makeUAVTemplate(), "2026-02-14 05:30:00")

      assert.is_not_nil(result)
      assert.are.equal(os.date(constants.DATE_FORMAT, 5500), result and result.takeoffTime)
      assert.are.equal(os.date(constants.DATE_FORMAT, 7500), result and result.endTime)
    end)

    -- Negative: startTime delays the flight past the next pass (would have fit from current time)
    it("should return nil when startTime pushes the flight end past the next pass", function()
      -- from current=5000 the same flight (3000) lands exactly at 8000 and fits;
      -- anchored at startTime=5500 it ends at 8500 > 8000 and must be rejected.
      stubTimeline(3000)
      local queue = {
        makeSatelliteEntry({ endTime = "2026-02-14 04:00:00", isFinished = true }),
        makeSatelliteEntry({ endTime = "2026-02-14 08:00:00" }),
      }
      local reconContext = makeReconContext(queue)

      local result = Recon.insertEntry(reconContext, makeUAVTemplate(), "2026-02-14 05:30:00")

      assert.is_nil(result)
      assert.are.equal(2, #reconContext.queue)
    end)

    -- Negative: no upcoming entry in queue (all passes already ended)
    it("should return nil when no upcoming entry exists", function()
      stubTimeline(3500)
      local queue = {
        makeSatelliteEntry({ endTime = "2026-02-14 04:00:00", isFinished = true }),
      }
      local reconContext = makeReconContext(queue)

      local result = Recon.insertEntry(reconContext, makeUAVTemplate())

      assert.is_nil(result)
      assert.are.equal(1, #reconContext.queue)
    end)

    -- Negative: UAV flight would finish after the next pass ends (lands too late to fit the gap)
    it("should return nil when flight ends after next pass endTime", function()
      stubTimeline(3500) -- UAV end = 8500 > next pass end 8000
      local queue = {
        makeSatelliteEntry({ endTime = "2026-02-14 04:00:00", isFinished = true }),
        makeSatelliteEntry({ endTime = "2026-02-14 08:00:00" }),
      }
      local reconContext = makeReconContext(queue)

      local result = Recon.insertEntry(reconContext, makeUAVTemplate())

      assert.is_nil(result)
      assert.are.equal(2, #reconContext.queue)
    end)

    -- Negative: an unfinished same-template UAV already covers the window
    it("should return nil when an unfinished UAV already covers the window", function()
      stubTimeline(3500)
      local template = makeUAVTemplate()
      local blockingUAV = makeUAVEntry({
        templateId = template.templateId, -- matching is by templateId, not course content
        takeoffTime = "2026-02-14 05:30:00",
        endTime = "2026-02-14 08:00:00",
      })
      local queue = {
        makeSatelliteEntry({ endTime = "2026-02-14 04:00:00", isFinished = true }),
        makeSatelliteEntry({ endTime = "2026-02-14 08:00:00" }),
        blockingUAV,
      }
      local reconContext = makeReconContext(queue)

      local result = Recon.insertEntry(reconContext, template)

      assert.is_nil(result)
      assert.are.equal(3, #reconContext.queue)
    end)

    -- Negative: a previously inserted deep copy (different course table) still blocks re-insertion
    it("should return nil when re-inserting the same template consecutively", function()
      stubTimeline(3500)
      local template = makeUAVTemplate()
      local previousCopy = Utils.deepCopy(template)
      previousCopy.takeoffTime = "2026-02-14 05:30:00"
      previousCopy.endTime = "2026-02-14 08:00:00"
      previousCopy.hasLaunched = false
      previousCopy.isFinished = false
      local queue = {
        makeSatelliteEntry({ endTime = "2026-02-14 04:00:00", isFinished = true }),
        makeSatelliteEntry({ endTime = "2026-02-14 08:00:00" }),
        previousCopy,
      }
      local reconContext = makeReconContext(queue)

      local result = Recon.insertEntry(reconContext, template)

      assert.is_nil(result)
      assert.are.equal(3, #reconContext.queue)
    end)

    -- Boundary: a finished same-template UAV in the window does not block insertion
    it("should insert when the same-template UAV in window is already finished", function()
      stubTimeline(2500)
      local template = makeUAVTemplate()
      local finishedUAV = makeUAVEntry({
        templateId = template.templateId,
        takeoffTime = "2026-02-14 05:30:00",
        endTime = "2026-02-14 08:00:00",
        isFinished = true,
      })
      local queue = {
        makeSatelliteEntry({ endTime = "2026-02-14 04:00:00", isFinished = true }),
        makeSatelliteEntry({ endTime = "2026-02-14 08:00:00" }),
        finishedUAV,
      }
      local reconContext = makeReconContext(queue)

      local result = Recon.insertEntry(reconContext, template)

      assert.is_not_nil(result)
      assert.are.equal(4, #reconContext.queue)
    end)

    -- Boundary: a same-template UAV whose flight ended before the window does not block
    it("should insert when the same-template UAV flew before the window", function()
      stubTimeline(2500)
      local template = makeUAVTemplate()
      local oldUAV = makeUAVEntry({
        templateId = template.templateId,
        takeoffTime = "2026-02-14 03:00:00",
        endTime = "2026-02-14 03:30:00",
      })
      local queue = {
        makeSatelliteEntry({ endTime = "2026-02-14 04:00:00", isFinished = true }),
        makeSatelliteEntry({ endTime = "2026-02-14 08:00:00" }),
        oldUAV,
      }
      local reconContext = makeReconContext(queue)

      local result = Recon.insertEntry(reconContext, template)

      assert.is_not_nil(result)
      assert.are.equal(4, #reconContext.queue)
    end)

    -- Boundary: a different-template UAV in the window does not block, even with identical course
    it("should insert when the in-window UAV belongs to a different template", function()
      stubTimeline(2500)
      local template = makeUAVTemplate()
      local otherTemplateUAV = makeUAVEntry({
        templateId = "OTHER_RECON_1",
        course = template.course, -- identical course must not cause a match
        takeoffTime = "2026-02-14 05:30:00",
        endTime = "2026-02-14 08:00:00",
      })
      local queue = {
        makeSatelliteEntry({ endTime = "2026-02-14 04:00:00", isFinished = true }),
        makeSatelliteEntry({ endTime = "2026-02-14 08:00:00" }),
        otherTemplateUAV,
      }
      local reconContext = makeReconContext(queue)

      local result = Recon.insertEntry(reconContext, template)

      assert.is_not_nil(result)
      assert.are.equal(4, #reconContext.queue)
    end)

    -- Boundary: a legacy UAV entry without templateId never blocks insertion
    it("should insert when the in-window UAV has no templateId", function()
      stubTimeline(2500)
      local legacyUAV = makeUAVEntry({
        takeoffTime = "2026-02-14 05:30:00",
        endTime = "2026-02-14 08:00:00",
      })
      local queue = {
        makeSatelliteEntry({ endTime = "2026-02-14 04:00:00", isFinished = true }),
        makeSatelliteEntry({ endTime = "2026-02-14 08:00:00" }),
        legacyUAV,
      }
      local reconContext = makeReconContext(queue)

      local result = Recon.insertEntry(reconContext, makeUAVTemplate())

      assert.is_not_nil(result)
      assert.are.equal(4, #reconContext.queue)
    end)

    -- Boundary: flight end exactly equals next pass endTime still counts as covering the gap
    it("should insert when flight end exactly equals next pass endTime", function()
      stubTimeline(3000) -- UAV end = 8000 == next pass end 8000
      local queue = {
        makeSatelliteEntry({ endTime = "2026-02-14 04:00:00", isFinished = true }),
        makeSatelliteEntry({ endTime = "2026-02-14 08:00:00" }),
      }
      local reconContext = makeReconContext(queue)

      local result = Recon.insertEntry(reconContext, makeUAVTemplate())

      assert.is_not_nil(result)
      assert.are.equal(3, #reconContext.queue)
    end)

    -- Boundary: no past pass yet (window start unbounded) still detects covering UAV
    it("should return nil when UAV covers window with no past pass", function()
      stubTimeline(3500)
      local template = makeUAVTemplate()
      local coveringUAV = makeUAVEntry({
        templateId = template.templateId,
        takeoffTime = "2026-02-14 03:00:00",
        endTime = "2026-02-14 07:00:00",
      })
      local queue = {
        makeSatelliteEntry({ endTime = "2026-02-14 08:00:00" }),
        coveringUAV,
      }
      local reconContext = makeReconContext(queue)

      local result = Recon.insertEntry(reconContext, template)

      assert.is_nil(result)
      assert.are.equal(2, #reconContext.queue)
    end)

    -- Boundary: empty queue has no next pass to anchor the window
    it("should return nil for an empty queue", function()
      stubTimeline(3500)
      local reconContext = makeReconContext({})

      local result = Recon.insertEntry(reconContext, makeUAVTemplate())

      assert.is_nil(result)
      assert.are.equal(0, #reconContext.queue)
    end)

    -- Bug 2 regression: a previously inserted UAV must NOT anchor the gap window.
    -- Satellites end at 4000/8000/12000; an already-inserted UAV ends at 8500. With the
    -- satellite-only boundary the next pass is 12000, so the flight (end 8600 <= 12000) is
    -- correctly admitted. If the UAV (8500) were wrongly picked as the boundary, the check
    -- 8600 <= 8500 would fail and insertion would be skipped.
    it("should insert using the satellite boundary, ignoring a previously inserted UAV", function()
      local TS = {
        ["2026-02-14 04:00:00"] = 4000,  -- satellite pass already ended
        ["2026-02-14 05:00:00"] = 5000,  -- inserted UAV takeoff
        ["2026-02-14 08:00:00"] = 8000,  -- most recent satellite pass end
        ["2026-02-14 08:30:00"] = 8500,  -- inserted UAV end (before next satellite)
        ["2026-02-14 12:00:00"] = 12000, -- next satellite pass end
      }
      trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(8100))
      trackStub(stub(GameUtils, "calculatePathDistanceAndTime").returns(100, 500)) -- end = 8600
      trackStub(stub(Utils, "parseDatetimeToTimestamp").invokes(function(datetimeStr)
        local timestamp = TS[datetimeStr]
        if not timestamp then
          error("No test timestamp mapping for: " .. tostring(datetimeStr))
        end
        return timestamp
      end))

      local template = makeUAVTemplate()
      local insertedUAV = makeUAVEntry({
        templateId = template.templateId,
        takeoffTime = "2026-02-14 05:00:00",
        endTime = "2026-02-14 08:30:00",
      })
      local queue = {
        makeSatelliteEntry({ endTime = "2026-02-14 04:00:00", isFinished = true }),
        makeSatelliteEntry({ endTime = "2026-02-14 08:00:00" }),
        makeSatelliteEntry({ endTime = "2026-02-14 12:00:00" }),
        insertedUAV,
      }
      local reconContext = makeReconContext(queue)

      local result = Recon.insertEntry(reconContext, template)

      assert.is_not_nil(result)
      assert.are.equal(5, #reconContext.queue)
    end)
  end)
end)
