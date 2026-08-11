-- Recon Unit Tests
local Recon = require("src.modules.strikePlanner.recon")
local GameApi = require("src.utils.gameApi")
local GameUtils = require("src.utils.gameUtils")
local Logger = require("src.utils.logger")
local FrontlineRedirect = require("src.modules.strikePlanner.frontlineRedirect")
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
  ---Register a stub or spy so after_each reverts it
  ---@param testDouble luassert.spy Stub or spy to track
  ---@return luassert.spy # The same double, so calls can be chained inline
  local function trackStub(testDouble)
    table.insert(activeStubs, testDouble)
    return testDouble
  end

  before_each(function()
    activeStubs = {}
    logStub = trackStub(stub(Logger, "log"))
    errorStub = trackStub(stub(Logger, "error"))
  end)

  after_each(function()
    for _, testDouble in ipairs(activeStubs) do
      testDouble:revert()
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
        Aircraft = { "UAV-001", "UAV-002", "UAV-003" },
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
      local setUnitStub = trackStub(stub(GameApi, "ScenEdit_SetUnit"))
      local setEMCONStub = trackStub(stub(GameApi, "ScenEdit_SetEMCON").returns(true))
      local rtbSpy = spy.on(h6n, "RTB")

      local result = Recon.launchWZ8(h6n, wz8Course)

      assert.is_not_nil(result)
      assert(result ~= nil)
      assert.are.equal("WZ8-001", result.guid)
      assert.are.same(wz8Course, result.course)
      assert.spy(rtbSpy).was.called_with(h6n, true)

      local addCall = addUnitStub.calls[1].vals[1]
      assert.are.equal("China", addCall.side)
      assert.are.equal(constants.PLATFORMS.WZ8, addCall.dbid)
      assert.are.equal(constants.LOADOUTS.WZ8_RECON, addCall.loadoutid)
      assert.are.equal(26.0, addCall.latitude)
      assert.are.equal(119.0, addCall.longitude)

      local updateCall = updateUnitStub.calls[1].vals[1]
      assert.are.equal("WZ8-001", updateCall.guid)
      assert.are.equal("add_sensor", updateCall.mode)
      assert.are.equal(constants.SENSORS.WZ8_RADAR, updateCall.dbid)

      local setCall = setUnitStub.calls[1].vals[1]
      assert.are.equal("WZ8-001", setCall.guid)
      assert.are.equal(constants.BASES.LONGTIAN_AAB, setCall.base)

      assert.stub(setEMCONStub).was.called_with("Unit", "WZ8-001", "Radar=Active")
    end)

    -- Negative: a half-configured drone must be removed, not left flying with no course
    it("should delete the WZ-8 and leave the H-6N alone when add_sensor fails", function()
      local wz8 = makeUnit({ guid = "WZ8-001" })
      trackStub(stub(GameApi, "ScenEdit_AddUnit").returns(wz8))
      trackStub(stub(GameApi, "ScenEdit_UpdateUnit").returns(nil))
      local deleteUnitStub = trackStub(stub(GameApi, "ScenEdit_DeleteUnit"))
      local rtbSpy = spy.on(h6n, "RTB")

      local result = Recon.launchWZ8(h6n, wz8Course)

      assert.is_nil(result)
      assert.stub(deleteUnitStub).was.called_with({ guid = "WZ8-001" })
      -- The H-6N keeps its own course; nothing was handed off to it
      assert.spy(rtbSpy).was_not.called()
      assert.is_true(hasErrorCall("reason=add_sensor_failed"))
    end)

    -- Negative: EMCON failure is the last gate; the drone is already fully built by then
    it("should delete the WZ-8 when SetEMCON fails", function()
      local wz8 = makeUnit({ guid = "WZ8-001" })
      trackStub(stub(GameApi, "ScenEdit_AddUnit").returns(wz8))
      trackStub(stub(GameApi, "ScenEdit_UpdateUnit").returns(wz8))
      trackStub(stub(GameApi, "ScenEdit_SetUnit"))
      trackStub(stub(GameApi, "ScenEdit_SetEMCON").returns(nil))
      local deleteUnitStub = trackStub(stub(GameApi, "ScenEdit_DeleteUnit"))
      local rtbSpy = spy.on(h6n, "RTB")

      local result = Recon.launchWZ8(h6n, wz8Course)

      assert.is_nil(result)
      assert.stub(deleteUnitStub).was.called_with({ guid = "WZ8-001" })
      assert.spy(rtbSpy).was_not.called()
      assert.is_true(hasErrorCall("reason=set_emcon_failed"))
    end)

    -- Boundary: nothing exists yet when AddUnit fails, so there is nothing to delete
    it("should not attempt deletion when AddUnit fails", function()
      trackStub(stub(GameApi, "ScenEdit_AddUnit").returns(nil))
      local deleteUnitStub = trackStub(stub(GameApi, "ScenEdit_DeleteUnit"))

      local result = Recon.launchWZ8(h6n, wz8Course)

      assert.is_nil(result)
      assert.stub(deleteUnitStub).was_not.called()
    end)
  end)

  -- ============================================================================
  -- processQueue
  -- ============================================================================

  describe("processQueue", function()
    local config, reconTriggeredOperationBatches, LACMContext

    before_each(function()
      config = makeConfig()
      reconTriggeredOperationBatches = {}
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
        reconTriggeredOperationBatches = reconTriggeredOperationBatches,
        LACMContext = LACMContext,
        fireSupportOnHold = fireSupportOnHold == true
      }
    end

    -- ========================================================================
    -- UAV Phase 1: Launch
    -- ========================================================================

    -- Positive: the launch phase fires once takeoff time passes
    it("should launch UAV when takeoff time has been reached", function()
      local uav = makeUnit({ guid = "UAV-001" })
      local base = makeBase({ embarkedUnits = { Aircraft = { "UAV-001" } } })
      local entry = makeUAVEntry()

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
        if guid == "BASE-001" then return base end
        if guid == "UAV-001" then return uav end
        return nil
      end))
      trackStub(stub(GameApi, "ScenEdit_SetDoctrine"))

      local reconContext = makeReconContext({ entry })
      Recon.processQueue(makeProcessingContext(reconContext))

      assert.is_true(entry.hasLaunched)
      assert.are.equal("UAV-001", entry.unitGUID)
    end)

    -- Negative: nothing happens until takeoff time is reached
    it("should not launch UAV before takeoff time", function()
      local entry = makeUAVEntry()

      trackStub(stub(GameUtils, "isAfterStartTime").returns(false))

      local reconContext = makeReconContext({ entry })
      Recon.processQueue(makeProcessingContext(reconContext))

      assert.is_false(entry.hasLaunched)
      assert.is_nil(entry.unitGUID)
    end)

    -- Negative: takeoff time reached but the hangar has nothing to send
    it("should report launch failure when no aircraft can be launched", function()
      local base = makeBase({ embarkedUnits = { Aircraft = {} } })
      local entry = makeUAVEntry()

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(base))

      local reconContext = makeReconContext({ entry })
      Recon.processQueue(makeProcessingContext(reconContext))

      assert.is_false(entry.hasLaunched)
      assert.is_nil(entry.unitGUID)
      assert.is_true(hasErrorCall("reason=launch_failed"))
    end)

    -- Negative: an aircraft still rearming must not be sent out
    it("should not launch an aircraft whose readytime has not elapsed", function()
      local uav = makeUnit({ guid = "UAV-001", readytime_v = 900 })
      local base = makeBase({ embarkedUnits = { Aircraft = { "UAV-001" } } })
      local entry = makeUAVEntry()

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
        if guid == "BASE-001" then return base end
        if guid == "UAV-001" then return uav end
        return nil
      end))
      trackStub(stub(GameApi, "ScenEdit_SetDoctrine"))
      local launchSpy = spy.on(uav, "Launch")

      local reconContext = makeReconContext({ entry })
      Recon.processQueue(makeProcessingContext(reconContext))

      assert.spy(launchSpy).was_not.called()
      assert.is_false(entry.hasLaunched)
      assert.is_true(hasErrorCall("reason=launch_failed"))
    end)

    -- Boundary: recon entries always deploy a single aircraft, whatever the base holds
    it("should launch a single aircraft when the base has more", function()
      local aircraft = {
        ["UAV-001"] = makeUnit({ guid = "UAV-001" }),
        ["UAV-002"] = makeUnit({ guid = "UAV-002" }),
        ["UAV-003"] = makeUnit({ guid = "UAV-003" }),
      }
      local base = makeBase()
      local entry = makeUAVEntry()

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
        if guid == "BASE-001" then return base end
        return aircraft[guid]
      end))
      trackStub(stub(GameApi, "ScenEdit_SetDoctrine"))
      local launchSpies = {
        ["UAV-001"] = spy.on(aircraft["UAV-001"], "Launch"),
        ["UAV-002"] = spy.on(aircraft["UAV-002"], "Launch"),
        ["UAV-003"] = spy.on(aircraft["UAV-003"], "Launch"),
      }

      local reconContext = makeReconContext({ entry })
      Recon.processQueue(makeProcessingContext(reconContext))

      assert.spy(launchSpies["UAV-001"]).was.called(1)
      assert.spy(launchSpies["UAV-002"]).was_not.called()
      assert.spy(launchSpies["UAV-003"]).was_not.called()
      assert.are.equal("UAV-001", entry.unitGUID)
    end)

    -- Boundary: the base lookup is delegated wholesale to the GameApi wrapper, which already
    -- falls back from GUID to name against constants.SIDES.ENEMY. Retrying here would only
    -- double the failed calls and their error tracebacks.
    -- Boundary: the base lookup is delegated wholesale to the GameApi wrapper, which already
    -- falls back from GUID to name against constants.SIDES.ENEMY. Retrying here would only
    -- double the failed calls and their error tracebacks.
    it("should look the base up exactly once and not retry per side", function()
      local uav = makeUnit({ guid = "UAV-001" })
      local base = makeBase({ embarkedUnits = { Aircraft = { "UAV-001" } } })
      local entry = makeUAVEntry()

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      local getUnitStub = trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
        if guid == "BASE-001" then return base end
        if guid == "UAV-001" then return uav end
        return nil
      end))
      trackStub(stub(GameApi, "ScenEdit_SetDoctrine"))

      local reconContext = makeReconContext({ entry })
      Recon.processQueue(makeProcessingContext(reconContext))

      assert.is_true(entry.hasLaunched)
      assert.are.equal("UAV-001", entry.unitGUID)

      local baseLookups = 0
      for _, call in ipairs(getUnitStub.calls) do
        if call.vals[1] == "BASE-001" then baseLookups = baseLookups + 1 end
      end
      assert.are.equal(1, baseLookups)
    end)

    -- Negative: a base the wrapper cannot resolve at all yields a launch failure, not a retry
    it("should report launch failure when the base cannot be resolved", function()
      local entry = makeUAVEntry()

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      local getUnitStub = trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(nil))

      local reconContext = makeReconContext({ entry })
      Recon.processQueue(makeProcessingContext(reconContext))

      assert.is_false(entry.hasLaunched)
      assert.is_true(hasErrorCall("reason=launch_failed"))
      assert.stub(getUnitStub).was.called(1)
    end)

    -- ========================================================================
    -- UAV Phase 2: In-flight monitoring
    -- ========================================================================

    -- Negative: an empty hangar may expose no embarkedUnits table at all
    it("should report launch failure when the base exposes no embarkedUnits", function()
      local base = makeBase()
      -- embarkedUnits=nil cannot travel through the overrides table, so clear it explicitly
      base.embarkedUnits = nil
      local entry = makeUAVEntry()

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(base))

      local reconContext = makeReconContext({ entry })
      assert.has_no.Error(function()
        Recon.processQueue(makeProcessingContext(reconContext))
      end)

      assert.is_false(entry.hasLaunched)
      assert.is_true(hasErrorCall("reason=launch_failed"))
    end)

    -- Negative: the container exists but the requested unit type bucket does not
    it("should report launch failure when the base has no bucket for the unit type", function()
      local base = makeBase()
      base.embarkedUnits = { Boats = {} }
      local entry = makeUAVEntry()

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(base))

      local reconContext = makeReconContext({ entry })
      assert.has_no.Error(function()
        Recon.processQueue(makeProcessingContext(reconContext))
      end)

      assert.is_false(entry.hasLaunched)
      assert.is_true(hasErrorCall("reason=launch_failed"))
    end)

    -- Positive: an unfinished course keeps the entry in flight, untouched
    it("should continue monitoring when UAV is still flying course", function()
      local entry = makeUAVEntry({ hasLaunched = true, unitGUID = "UAV-001" })
      local uav = makeUnit({ guid = "UAV-001", course = { { latitude = 24.5 } } })

      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(uav))
      trackStub(stub(GameUtils, "isAfterStartTime").returns(false))

      local reconContext = makeReconContext({ entry })
      Recon.processQueue(makeProcessingContext(reconContext))

      -- Phase 2b is the only path emitting this reason, so the log identifies it
      assert.is_true(hasLogCall("recon", "reason=course_not_completed"))
      assert.is_false(entry.isFinished)
      assert.are.equal(0, #reconTriggeredOperationBatches)
    end)

    -- Boundary: course done but the clock is not, so the mission must not settle yet
    it("should log and wait when course complete but endTime not reached", function()
      local entry = makeUAVEntry({ hasLaunched = true, unitGUID = "UAV-001" })
      local uav = makeUnit({ guid = "UAV-001", course = {} })

      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(uav))
      trackStub(stub(GameUtils, "isAfterStartTime").returns(false))

      local reconContext = makeReconContext({ entry })
      Recon.processQueue(makeProcessingContext(reconContext))

      -- Phase 2c is the only UAV path emitting this state, so the log identifies it
      assert.is_true(hasLogCall("recon", "state=waiting_end_time"))
      -- Waiting only: the mission must not settle before endTime
      assert.is_false(entry.isFinished)
      assert.are.equal(0, #reconTriggeredOperationBatches)
    end)

    -- ========================================================================
    -- UAV destroyed scenarios
    -- ========================================================================

    -- Negative: losing the UAV early means the intelligence is incomplete
    it("should mark mission as failed when UAV destroyed before endTime", function()
      local entry = makeUAVEntry({ hasLaunched = true, unitGUID = "UAV-001" })

      -- GetUnit returns nil (destroyed), isAfterStartTime returns false (before endTime)
      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(nil))
      trackStub(stub(GameUtils, "isAfterStartTime").returns(false))

      local reconContext = makeReconContext({ entry })
      Recon.processQueue(makeProcessingContext(reconContext))

      -- Phase 3a is the only path emitting this reason, so the error log identifies it
      assert.is_true(hasErrorCall("reason=destroyed_before_end_time"))
      assert.is_true(entry.isFinished)
      -- No dynamic operations scheduled, and the flag stays clear so a later
      -- success on a re-tracked entry can still schedule
      assert.are.equal(0, #reconTriggeredOperationBatches)
      assert.is_falsy(entry.hasScheduledOperations)
    end)

    -- Boundary: the same loss after endTime still counts as a completed pass
    it("should mark mission as successful when UAV destroyed after endTime", function()
      local entry = makeUAVEntry({ hasLaunched = true, unitGUID = "UAV-001" })

      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(nil))
      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      local scheduleStub = trackStub(stub(OperationScheduler, "schedule"))

      local reconContext = makeReconContext({ entry })
      Recon.processQueue(makeProcessingContext(reconContext))

      assert.is_true(hasLogCall("recon", "reason=end_time_reached"))
      assert.is_true(entry.isFinished)
      assert.stub(scheduleStub).was.called(1)
    end)

    -- ========================================================================
    -- UAV mission completion (normal mode)
    -- ========================================================================

    -- Positive: the normal completion path
    it("should finish mission successfully when course and endTime completed", function()
      local entry = makeUAVEntry({ hasLaunched = true, unitGUID = "UAV-001" })
      local uav = makeUnit({ guid = "UAV-001", course = {} })

      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(uav))
      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      local scheduleStub = trackStub(stub(OperationScheduler, "schedule"))

      local reconContext = makeReconContext({ entry })
      Recon.processQueue(makeProcessingContext(reconContext))

      assert.is_true(hasLogCall("recon", "action=complete_mission"))
      assert.is_true(entry.isFinished)
      assert.stub(scheduleStub).was.called(1)
    end)

    -- ========================================================================
    -- UAV tracking mode
    -- ========================================================================

    -- Positive: a live contact retargets the UAV and keeps the entry open
    it("should update course when tracking target successfully", function()
      local entry = makeUAVEntry({
        hasLaunched = true,
        unitGUID = "UAV-001",
        isTracking = true,
        trackingTargetGUID = "CONTACT-001",
        speed = 300,
      })
      local uav = makeUnit({ guid = "UAV-001", course = {} })
      local target = { guid = "CONTACT-001", latitude = 23.0, longitude = 119.0 }

      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(uav))
      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(GameApi, "ScenEdit_GetContact").returns(target))

      local reconContext = makeReconContext({ entry })
      Recon.processQueue(makeProcessingContext(reconContext))

      assert.are.same({
        latitude = 23.0,
        longitude = 119.0,
        desiredSpeed = 300,
        presetThrottle = "Military",
      }, uav.course[1])
      assert.is_false(entry.isFinished)
    end)

    -- Positive: WZ8_RECON_ISLAND launches an H-6N but shadows with the WZ-8 it releases,
    -- so the tracking airframe's speed must win over the one used for flight-time estimation
    -- Positive: WZ8_RECON_ISLAND launches an H-6N but shadows with the WZ-8 it releases,
    -- so the tracking airframe's speed must win over the flight-time estimation one
    it("should prefer trackingSpeed over speed when shadowing a contact", function()
      local entry = makeUAVEntry({
        hasLaunched = true,
        unitGUID = "UAV-001",
        isTracking = true,
        trackingTargetGUID = "CONTACT-001",
        speed = 450,
        trackingSpeed = 3300,
      })
      local uav = makeUnit({ guid = "UAV-001", course = {} })
      local target = { guid = "CONTACT-001", latitude = 23.0, longitude = 119.0 }

      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(uav))
      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(GameApi, "ScenEdit_GetContact").returns(target))

      local reconContext = makeReconContext({ entry })
      Recon.processQueue(makeProcessingContext(reconContext))

      assert.are.equal(3300, uav.course[1].desiredSpeed)
      assert.is_false(entry.isFinished)
    end)

    -- Boundary: trackingSpeed alone is enough; the guard must not demand speed
    it("should track on trackingSpeed alone when speed is unset", function()
      local entry = makeUAVEntry({
        hasLaunched = true,
        unitGUID = "UAV-001",
        isTracking = true,
        trackingTargetGUID = "CONTACT-001",
        trackingSpeed = 3300,
      })
      -- speed=nil cannot travel through the overrides table, so clear it explicitly
      entry.speed = nil
      local uav = makeUnit({ guid = "UAV-001", course = {} })
      local target = { guid = "CONTACT-001", latitude = 23.0, longitude = 119.0 }

      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(uav))
      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(GameApi, "ScenEdit_GetContact").returns(target))

      local reconContext = makeReconContext({ entry })
      Recon.processQueue(makeProcessingContext(reconContext))

      assert.are.equal(3300, uav.course[1].desiredSpeed)
      assert.is_false(hasErrorCall("reason=speed_not_configured"))
    end)

    -- Negative: a lost contact ends the shadowing, but the recon leg still counts as done
    it("should finish mission when tracking target is lost", function()
      local entry = makeUAVEntry({
        hasLaunched = true,
        unitGUID = "UAV-001",
        isTracking = true,
        trackingTargetGUID = "CONTACT-001",
        speed = 300,
      })
      local uav = makeUnit({ guid = "UAV-001", course = {} })

      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(uav))
      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(GameApi, "ScenEdit_GetContact").returns(nil))
      local scheduleStub = trackStub(stub(OperationScheduler, "schedule"))

      local reconContext = makeReconContext({ entry })
      Recon.processQueue(makeProcessingContext(reconContext))

      -- The specific tracking reason reaches the log; state keeps the coarse token greppable
      assert.is_true(hasErrorCall("state=tracking_failed"))
      assert.is_true(hasErrorCall("reason=tracking_target_lost"))
      assert.is_true(hasErrorCall("missionStatus=completed"))
      assert.is_true(entry.isFinished)
      assert.stub(scheduleStub).was.called(1)
    end)

    -- Boundary: isTracking without an assigned target is just an ordinary completion
    it("should complete normally when isTracking set but no trackingTargetGUID", function()
      local entry = makeUAVEntry({
        hasLaunched = true,
        unitGUID = "UAV-001",
        isTracking = true,
        trackingTargetGUID = nil,
        speed = 300,
      })
      local uav = makeUnit({ guid = "UAV-001", course = {} })

      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(uav))
      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      local scheduleStub = trackStub(stub(OperationScheduler, "schedule"))

      local reconContext = makeReconContext({ entry })
      Recon.processQueue(makeProcessingContext(reconContext))

      -- No trackingTargetGUID never enters the tracking path, so this is a normal completion
      assert.is_true(hasLogCall("recon", "action=complete_mission"))
      assert.is_true(entry.isFinished)
      assert.stub(scheduleStub).was.called(1)
    end)

    -- Negative: neither speed field set, so the UAV cannot be given a course
    it("should finish mission via tracking failure when no speed configured", function()
      local entry = makeUAVEntry({
        hasLaunched = true,
        unitGUID = "UAV-001",
        isTracking = true,
        trackingTargetGUID = "CONTACT-001",
      })
      -- speed=nil cannot travel through the overrides table, so clear it explicitly
      entry.speed = nil
      local uav = makeUnit({ guid = "UAV-001", course = {} })

      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(uav))
      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      local scheduleStub = trackStub(stub(OperationScheduler, "schedule"))

      local reconContext = makeReconContext({ entry })
      Recon.processQueue(makeProcessingContext(reconContext))

      assert.is_true(hasErrorCall("reason=speed_not_configured"))
      assert.is_true(hasErrorCall("state=tracking_failed"))
      assert.is_true(entry.isFinished)
      assert.stub(scheduleStub).was.called(1)
    end)

    -- Negative: trackTarget reactivates a settled entry by clearing isFinished. The follow-on
    -- wave is already queued by then, so settling again must not schedule a second time --
    -- otherwise every lost contact walks the /N strike counter forward.
    it("should not schedule operations twice when a settled entry is re-tracked", function()
      local entry = makeUAVEntry({ hasLaunched = true, unitGUID = "UAV-001", isTracking = true })
      local uav = makeUnit({ guid = "UAV-001", course = {} })

      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(uav))
      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(GameApi, "Tool_Range").returns(50))
      local scheduleStub = trackStub(stub(OperationScheduler, "schedule"))

      local reconContext = makeReconContext({ entry })

      -- Tick 1: course and endTime complete, so the entry settles and queues its wave
      Recon.processQueue(makeProcessingContext(reconContext))
      assert.is_true(entry.isFinished)
      assert.is_true(entry.hasScheduledOperations)
      assert.stub(scheduleStub).was.called(1)

      -- targetingProcess hands the still-airborne UAV a contact to shadow
      local assigned = Recon.trackTarget(reconContext, { { name = "", guid = "UAV-001" } }, entry.unitDBID,
        { guid = "CONTACT-001" })
      assert.is_true(assigned)
      assert.is_false(entry.isFinished)

      -- Tick 2: the contact is lost, re-settling the entry
      trackStub(stub(GameApi, "ScenEdit_GetContact").returns(nil))
      Recon.processQueue(makeProcessingContext(reconContext))

      assert.is_true(entry.isFinished)
      assert.stub(scheduleStub).was.called(1)
    end)

    -- ========================================================================
    -- Satellite entry processing
    -- ========================================================================

    -- Positive: a satellite pass settles purely on the clock
    it("should finish satellite mission when endTime reached", function()
      local entry = makeSatelliteEntry()

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      local scheduleStub = trackStub(stub(OperationScheduler, "schedule"))

      local reconContext = makeReconContext({ entry })
      Recon.processQueue(makeProcessingContext(reconContext))

      assert.is_true(entry.isFinished)
      assert.stub(scheduleStub).was.called(1)
    end)

    -- Negative: before endTime the pass stays open
    it("should not finish satellite mission before endTime", function()
      local entry = makeSatelliteEntry()

      trackStub(stub(GameUtils, "isAfterStartTime").returns(false))

      local reconContext = makeReconContext({ entry })
      Recon.processQueue(makeProcessingContext(reconContext))

      assert.is_false(entry.isFinished)
    end)

    -- Positive: SIGINT shares the passive path with satellite
    it("should finish SIGINT mission when endTime reached", function()
      local entry = makeSIGINTEntry()

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      local scheduleStub = trackStub(stub(OperationScheduler, "schedule"))

      local reconContext = makeReconContext({ entry })
      Recon.processQueue(makeProcessingContext(reconContext))

      assert.is_true(entry.isFinished)
      assert.stub(scheduleStub).was.called(1)
    end)

    -- ========================================================================
    -- Mixed queue processing
    -- ========================================================================

    -- Boundary: one tick, two entry types, each resolved on its own terms
    it("should process UAV and satellite entries independently", function()
      local uavEntry = makeUAVEntry()
      -- A distinct endTime keeps the stub below dispatching on the satellite alone;
      -- the builder default collides with makeUAVEntry's endTime
      local satEntry = makeSatelliteEntry({ endTime = "2026-02-14 09:00:00" })

      trackStub(stub(GameUtils, "isAfterStartTime").invokes(function(time)
        -- UAV takeoff time not reached, satellite endTime reached
        if time == uavEntry.takeoffTime then return false end
        if time == satEntry.endTime then return true end
        return false
      end))
      local scheduleStub = trackStub(stub(OperationScheduler, "schedule"))

      local reconContext = makeReconContext({ uavEntry, satEntry })
      Recon.processQueue(makeProcessingContext(reconContext))

      assert.is_true(hasLogCall("recon", "reason=takeoff_time_not_reached"))
      -- called(1) proves the loop reached the satellite and settled it alone
      assert.is_true(satEntry.isFinished)
      assert.stub(scheduleStub).was.called(1)
    end)

    -- ========================================================================
    -- Batched logging
    -- ========================================================================

    -- Positive: activation is only visible through this row, so processQueue must emit it
    it("should emit a RESUME row when frontline redirect activates", function()
      trackStub(stub(FrontlineRedirect, "evaluate").returns(true, {
        action = "activate",
        reason = "attrition_threshold_reached",
        attritionPct = "62.5",
      }))

      local reconContext = makeReconContext({})
      Recon.processQueue(makeProcessingContext(reconContext))

      assert.is_true(hasLogCall("recon", "%[RESUME%].*scope=frontlineRedirect"))
      assert.is_true(hasLogCall("recon", "reason=attrition_threshold_reached"))
    end)

    -- Boundary: an empty report stays silent instead of printing an empty header
    it("should not emit any recon log when all entries are already finished", function()
      local entry1 = makeUAVEntry({ hasLaunched = true, unitGUID = "UAV-001", isFinished = true })
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
        unitGUID = "UAV-001",
        trackingTargetGUID = "CONTACT-001",
      })
      local uav = makeUnit({ guid = "UAV-001" })

      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(uav))

      local reconContext = makeReconContext({ entry })
      local result = Recon.trackTarget(reconContext, {}, UAVDBID, target)

      assert.is_true(result)
    end)

    -- Negative: already tracking but UAV destroyed
    it("should not return early when tracked UAV is destroyed", function()
      local entry = makeUAVEntry({
        hasLaunched = true,
        unitGUID = "UAV-001",
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

    -- Boundary: a settled entry must not keep claiming its old target
    it("should reassign a free UAV when the tracking entry is already finished", function()
      -- Same target GUID and a live unit, but the entry settled: processQueue skips it,
      -- so treating it as "already tracked" would strand the target permanently
      local settledEntry = makeUAVEntry({
        hasLaunched = true,
        unitGUID = "UAV-OLD",
        trackingTargetGUID = "CONTACT-001",
        isTracking = true,
        isFinished = true,
      })
      local freeEntry = makeUAVEntry({ hasLaunched = true, unitGUID = "UAV-FREE" })
      local oldUAV = makeUnit({ guid = "UAV-OLD", dbid = UAVDBID, condition = "Airborne" })
      local freeUAV = makeUnit({ guid = "UAV-FREE", dbid = UAVDBID, condition = "Airborne" })

      trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
        if guid == "UAV-OLD" then return oldUAV end
        if guid == "UAV-FREE" then return freeUAV end
        return nil
      end))
      trackStub(stub(GameApi, "Tool_Range").returns(50))

      local reconContext = makeReconContext({ settledEntry, freeEntry })
      local result = Recon.trackTarget(reconContext, { { name = "", guid = "UAV-FREE" } }, UAVDBID, target)

      assert.is_true(result)
      assert.are.equal("CONTACT-001", freeEntry.trackingTargetGUID)
      assert.is_false(freeEntry.isFinished)
    end)

    -- Boundary: satellite entries in queue should be ignored during tracking lookup
    it("should ignore satellite entries when looking for tracked UAV", function()
      -- unitGUID is what makes the entry look "already tracking"; only the type
      -- check keeps it out, so without it this entry would short-circuit to true
      local satEntry = makeSatelliteEntry({
        trackingTargetGUID = "CONTACT-001",
        unitGUID = "SAT-001",
      })
      local sat = makeUnit({ guid = "SAT-001" })

      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(sat))

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
  -- initQueue
  -- ============================================================================

  describe("initQueue", function()
    -- Positive: a UAV authored straight into config.c.recon.queue carries its own timings and
    -- must reach processQueue as a fully initialized entry, without going through insertEntry
    -- Positive: a UAV authored straight into config.c.recon.queue carries its own timings and
    -- must reach processQueue fully initialized, without going through insertEntry
    it("should initialize a UAV authored directly in the config queue", function()
      local reconConfig = {
        queue = {
          {
            type = "UAV",
            templateId = "H6N_RECON_ISLAND",
            baseGUID = "BASE-001",
            unitDBID = constants.PLATFORMS.BZK005,
            course = {},
            speed = 450,
            takeoffTime = "2026-02-14 06:00:00",
            endTime = "2026-02-14 08:00:00",
          },
        },
      }
      local reconContext = {}

      Recon.initQueue(reconConfig, reconContext)

      local planned = reconContext.queue[1]
      assert.is_false(planned.hasLaunched)
      assert.is_false(planned.isFinished)
      assert.is_false(planned.hasScheduledOperations)
      -- The plan's own timings survive init untouched
      assert.are.equal("2026-02-14 06:00:00", planned.takeoffTime)
      assert.are.equal("2026-02-14 08:00:00", planned.endTime)

      -- And it launches like any other entry on the next tick
      local uav = makeUnit({ guid = "UAV-001" })
      local base = makeBase({ embarkedUnits = { Aircraft = { "UAV-001" } } })
      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
        if guid == "BASE-001" then return base end
        if guid == "UAV-001" then return uav end
        return nil
      end))
      trackStub(stub(GameApi, "ScenEdit_SetDoctrine"))

      Recon.processQueue({
        config = makeConfig(),
        reconContext = reconContext,
        reconTriggeredOperationBatches = {},
        LACMContext = makeLACMContext(),
        fireSupportOnHold = false,
      })

      assert.is_true(planned.hasLaunched)
      assert.are.equal("UAV-001", planned.unitGUID)
    end)

    -- Positive: every entry type is reset in one pass
    it("should reset UAV, satellite and SIGINT entries in a mixed queue", function()
      local reconConfig = {
        queue = {
          {
            type = "UAV",
            baseGUID = "BASE-001",
            unitDBID = constants.PLATFORMS.BZK005,
            course = {},
            speed = 200,
          },
          { type = "satellite", endTime = "2026-02-14 10:00:00" },
          { type = "SIGINT",    endTime = "2026-02-14 11:00:00" },
          {
            type = "UAV",
            baseGUID = "BASE-002",
            unitDBID = constants.PLATFORMS.BZK005,
            course = {},
            speed = 250,
          },
        },
      }
      local reconContext = {}

      Recon.initQueue(reconConfig, reconContext)

      assert.are.equal(4, #reconContext.queue)
      assert.is_false(reconContext.queue[1].hasLaunched)
      assert.is_false(reconContext.queue[1].isFinished)
      assert.is_false(reconContext.queue[2].isFinished)
      assert.is_false(reconContext.queue[3].isFinished)
      assert.is_false(reconContext.queue[4].hasLaunched)
      assert.is_false(reconContext.queue[4].isFinished)
      -- Every entry type gates follow-on scheduling on this flag, so all four are reset
      for index = 1, 4 do
        assert.is_false(reconContext.queue[index].hasScheduledOperations)
      end
    end)

    -- Boundary: empty queue
    it("should handle empty queue config", function()
      local reconConfig = { queue = {} }
      local reconContext = {}

      Recon.initQueue(reconConfig, reconContext)

      assert.is_table(reconContext.queue)
      assert.are.equal(0, #reconContext.queue)
    end)

    -- Boundary: deep copy is used (original not mutated)
    it("should deep copy the config queue to avoid mutating the original", function()
      local reconConfig = { queue = { { type = "satellite", endTime = "2026-02-14 08:00:00" } } }
      local reconContext = {}
      local deepCopySpy = trackStub(spy.on(Utils, "deepCopy"))
      Recon.initQueue(reconConfig, reconContext)

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
      assert.is_false(inserted.hasScheduledOperations)
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
      -- 2500 keeps the flight itself admissible (end 7500 <= next pass 8000), so the only
      -- thing that can block insertion is the templateId dedup under test
      stubTimeline(2500)
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
      -- Admissible flight time, so the dedup is what must reject this, not the window bound
      stubTimeline(2500)
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

    -- Boundary: a previously inserted UAV must NOT anchor the gap window. Satellites end at
    -- 4000/8000/12000; an already-inserted UAV ends at 8500. With the satellite-only boundary
    -- the next pass is 12000, so the flight (end 8600 <= 12000) is correctly admitted. If the
    -- UAV (8500) were wrongly picked as the boundary, 8600 <= 8500 would fail and it would be skipped.
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
