-- Recon Unit Tests
---@diagnostic disable: undefined-field
local Recon = require("src.modules.strikePlanner.recon")
local GameApi = require("src.utils.gameApi")
local GameUtils = require("src.utils.gameUtils")
local Logger = require("src.utils.logger")
local DynamicOperationsUtils = require("src.modules.strikePlanner.dynamicOperationsUtils")
local Utils = require("src.utils.utils")
local constants = require("src.core.constants")

describe("Recon", function()
  local activeStubs

  local function trackStub(s)
    table.insert(activeStubs, s)
    return s
  end

  before_each(function()
    activeStubs = {}
    trackStub(stub(Logger, "log"))
    trackStub(stub(Logger, "error"))
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
  ---@return table
  local function makeReconContext(queue)
    return { queue = queue or {} }
  end

  ---Create a minimal config for getPlatformSpecialOperations / scheduleDynamicReconOperations
  ---@param overrides? table
  ---@return table
  local function makeConfig(overrides)
    local cfg = {
      c = {
        recon = {
          reconStrikeMatrix = {
            UAV = {
              BZK005 = {
                { name = "STRIKE/C2/1", type = "ground" },
              },
            },
            satellite = {},
          },
        },
        packageTemplates = {},
        fireSupportTaskTemplates = {
          STRIKE_C2_2 = { { name = "FST-C2-2" } },
        },
      },
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
    for _, call in ipairs(Logger.log.calls) do
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
    for _, call in ipairs(Logger.error.calls) do
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
        guid = "H6N-001", name = "H-6N #1",
        latitude = 26.0, longitude = 119.0,
      })
    end)

    -- Positive: successful WZ-8 launch
    it("should create WZ-8, add sensor, set EMCON, and RTB the H-6N", function()
      local wz8 = makeUnit({ guid = "WZ8-001", name = "WZ-8" })

      trackStub(stub(GameApi, "ScenEdit_AddUnit").returns(wz8))
      trackStub(stub(GameApi, "ScenEdit_UpdateUnit").returns(wz8))
      trackStub(stub(GameApi, "ScenEdit_SetEMCON").returns(true))
      local rtbSpy = spy.on(h6n, "RTB")

      local result = Recon.launchWZ8(h6n, wz8Course)

      assert.is_not_nil(result)
      assert.are.equal("WZ8-001", result.guid)
      assert.are.same(wz8Course, result.course)
      assert.spy(rtbSpy).was.called_with(h6n, true)

      -- Verify AddUnit params
      local addCall = GameApi.ScenEdit_AddUnit.calls[1].vals[1]
      assert.are.equal("China", addCall.side)
      assert.are.equal(constants.PLATFORMS.WZ8, addCall.dbid)
      assert.are.equal(constants.LOADOUTS.WZ8_RECON, addCall.loadoutid)
      assert.are.equal(26.0, addCall.latitude)
      assert.are.equal(119.0, addCall.longitude)

      -- Verify UpdateUnit params
      local updateCall = GameApi.ScenEdit_UpdateUnit.calls[1].vals[1]
      assert.are.equal("WZ8-001", updateCall.guid)
      assert.are.equal("add_sensor", updateCall.mode)
      assert.are.equal(constants.SENSORS.WZ8_RADAR, updateCall.dbid)

      -- Verify EMCON call
      assert.stub(GameApi.ScenEdit_SetEMCON).was.called_with("Unit", "WZ8-001", "Radar=Active")
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
  -- handleReconQueue
  -- ============================================================================

  describe("handleReconQueue", function()
    local config, reconSchedule, LACMContext

    before_each(function()
      config = makeConfig()
      reconSchedule = {}
      LACMContext = makeLACMContext()
    end)

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
      Recon.handleReconQueue(config, reconContext, reconSchedule, LACMContext)

      assert.is_true(entry.hasLaunched)
      assert.are.equal("AC-001", entry.unitGUID)
    end)

    it("should not launch UAV before takeoff time", function()
      local entry = makeUAVEntry()

      trackStub(stub(GameUtils, "isAfterStartTime").returns(false))

      local reconContext = makeReconContext({ entry })
      Recon.handleReconQueue(config, reconContext, reconSchedule, LACMContext)

      assert.is_false(entry.hasLaunched)
      assert.is_nil(entry.unitGUID)
    end)

    it("should skip already launched UAV entries in launch phase", function()
      local entry = makeUAVEntry({ hasLaunched = true, unitGUID = "AC-001" })
      local ac = makeUnit({ guid = "AC-001", course = { { latitude = 24.5 } } })

      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(ac))
      trackStub(stub(GameUtils, "isAfterStartTime").returns(false))

      local reconContext = makeReconContext({ entry })
      Recon.handleReconQueue(config, reconContext, reconSchedule, LACMContext)

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
      Recon.handleReconQueue(config, reconContext, reconSchedule, LACMContext)

      assert.is_false(entry.isFinished)
    end)

    it("should log and wait when course complete but endTime not reached", function()
      local entry = makeUAVEntry({ hasLaunched = true, unitGUID = "AC-001" })
      local ac = makeUnit({ guid = "AC-001", course = {} })

      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(ac))
      trackStub(stub(GameUtils, "isAfterStartTime").returns(false))

      local reconContext = makeReconContext({ entry })
      Recon.handleReconQueue(config, reconContext, reconSchedule, LACMContext)

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
      Recon.handleReconQueue(config, reconContext, reconSchedule, LACMContext)

      assert.is_true(entry.isFinished)
      -- No dynamic operations scheduled (mission failed)
      assert.are.equal(0, #reconSchedule)
    end)

    it("should mark mission as successful when UAV destroyed after endTime", function()
      local entry = makeUAVEntry({ hasLaunched = true, unitGUID = "AC-001" })

      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(nil))
      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(DynamicOperationsUtils, "getLastExecutedOperationsAndNextTime").returns({
        air = {}, ground = {}, mostRecentTime = nil, nextReconTime = nil,
      }))
      trackStub(stub(DynamicOperationsUtils, "hasOperation").returns(false))

      local reconContext = makeReconContext({ entry })
      Recon.handleReconQueue(config, reconContext, reconSchedule, LACMContext)

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
      trackStub(stub(DynamicOperationsUtils, "getLastExecutedOperationsAndNextTime").returns({
        air = {}, ground = {}, mostRecentTime = nil, nextReconTime = nil,
      }))
      trackStub(stub(DynamicOperationsUtils, "hasOperation").returns(false))

      local reconContext = makeReconContext({ entry })
      Recon.handleReconQueue(config, reconContext, reconSchedule, LACMContext)

      assert.is_true(entry.isFinished)
    end)

    -- ========================================================================
    -- UAV tracking mode
    -- ========================================================================

    it("should update course when tracking target successfully", function()
      local entry = makeUAVEntry({
        hasLaunched = true, unitGUID = "AC-001",
        isTracking = true, trackingTargetGUID = "CONTACT-001", speed = 300,
      })
      local ac = makeUnit({ guid = "AC-001", course = {} })
      local target = { guid = "CONTACT-001", latitude = 23.0, longitude = 119.0 }

      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(ac))
      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(GameApi, "ScenEdit_GetContact").returns(target))

      local reconContext = makeReconContext({ entry })
      Recon.handleReconQueue(config, reconContext, reconSchedule, LACMContext)

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
        hasLaunched = true, unitGUID = "AC-001",
        isTracking = true, trackingTargetGUID = "CONTACT-001", speed = 300,
      })
      local ac = makeUnit({ guid = "AC-001", course = {} })

      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(ac))
      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(GameApi, "ScenEdit_GetContact").returns(nil))
      trackStub(stub(DynamicOperationsUtils, "getLastExecutedOperationsAndNextTime").returns({
        air = {}, ground = {}, mostRecentTime = nil, nextReconTime = nil,
      }))
      trackStub(stub(DynamicOperationsUtils, "hasOperation").returns(false))

      local reconContext = makeReconContext({ entry })
      Recon.handleReconQueue(config, reconContext, reconSchedule, LACMContext)

      assert.is_true(entry.isFinished)
    end)

    it("should complete normally when isTracking set but no trackingTargetGUID", function()
      local entry = makeUAVEntry({
        hasLaunched = true, unitGUID = "AC-001",
        isTracking = true, trackingTargetGUID = nil, speed = 300,
      })
      local ac = makeUnit({ guid = "AC-001", course = {} })

      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(ac))
      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(DynamicOperationsUtils, "getLastExecutedOperationsAndNextTime").returns({
        air = {}, ground = {}, mostRecentTime = nil, nextReconTime = nil,
      }))
      trackStub(stub(DynamicOperationsUtils, "hasOperation").returns(false))

      local reconContext = makeReconContext({ entry })
      Recon.handleReconQueue(config, reconContext, reconSchedule, LACMContext)

      -- Tracking failed => finishReconMission called with success=true
      assert.is_true(entry.isFinished)
    end)

    it("should finish mission via tracking failure when no speed configured", function()
      local entry = makeUAVEntry({
        hasLaunched = true, unitGUID = "AC-001",
        isTracking = true, trackingTargetGUID = "CONTACT-001", speed = nil,
      })
      local ac = makeUnit({ guid = "AC-001", course = {} })

      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(ac))
      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(DynamicOperationsUtils, "getLastExecutedOperationsAndNextTime").returns({
        air = {}, ground = {}, mostRecentTime = nil, nextReconTime = nil,
      }))
      trackStub(stub(DynamicOperationsUtils, "hasOperation").returns(false))

      local reconContext = makeReconContext({ entry })
      Recon.handleReconQueue(config, reconContext, reconSchedule, LACMContext)

      assert.is_true(entry.isFinished)
    end)

    -- ========================================================================
    -- Double execution prevention
    -- ========================================================================

    it("should not execute finishReconMission twice for same entry", function()
      local entry = makeUAVEntry({
        hasLaunched = true, unitGUID = "AC-001",
        isFinished = true, -- Already finished
      })

      local reconContext = makeReconContext({ entry })
      Recon.handleReconQueue(config, reconContext, reconSchedule, LACMContext)

      -- isFinished should remain true, no additional scheduling
      assert.is_true(entry.isFinished)
      assert.are.equal(0, #reconSchedule)
    end)

    -- ========================================================================
    -- Satellite entry processing
    -- ========================================================================

    it("should finish satellite mission when endTime reached", function()
      local entry = makeSatelliteEntry()

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(DynamicOperationsUtils, "getLastExecutedOperationsAndNextTime").returns({
        air = {}, ground = {}, mostRecentTime = nil, nextReconTime = nil,
      }))

      local reconContext = makeReconContext({ entry })
      Recon.handleReconQueue(config, reconContext, reconSchedule, LACMContext)

      assert.is_true(entry.isFinished)
    end)

    it("should not finish satellite mission before endTime", function()
      local entry = makeSatelliteEntry()

      trackStub(stub(GameUtils, "isAfterStartTime").returns(false))

      local reconContext = makeReconContext({ entry })
      Recon.handleReconQueue(config, reconContext, reconSchedule, LACMContext)

      assert.is_false(entry.isFinished)
    end)

    it("should skip already finished satellite entry", function()
      local entry = makeSatelliteEntry({ isFinished = true })

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))

      local reconContext = makeReconContext({ entry })
      Recon.handleReconQueue(config, reconContext, reconSchedule, LACMContext)

      -- Should not schedule duplicate operations
      assert.are.equal(0, #reconSchedule)
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
      trackStub(stub(DynamicOperationsUtils, "getLastExecutedOperationsAndNextTime").returns({
        air = {}, ground = {}, mostRecentTime = nil, nextReconTime = nil,
      }))

      local reconContext = makeReconContext({ uavEntry, satEntry })
      Recon.handleReconQueue(config, reconContext, reconSchedule, LACMContext)

      assert.is_false(uavEntry.hasLaunched)
      assert.is_true(satEntry.isFinished)
    end)

    -- ========================================================================
    -- Dynamic operations scheduling on mission completion
    -- ========================================================================

    it("should schedule new operations when mission completes with matching strike matrix", function()
      local entry = makeUAVEntry({ hasLaunched = true, unitGUID = "AC-001" })
      local ac = makeUnit({ guid = "AC-001", course = {} })

      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(ac))
      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(DynamicOperationsUtils, "getLastExecutedOperationsAndNextTime").returns({
        air = {}, ground = {}, mostRecentTime = nil, nextReconTime = nil,
      }))
      trackStub(stub(DynamicOperationsUtils, "hasOperation").returns(false))
      trackStub(stub(DynamicOperationsUtils, "generateNextOperation").returns(
        { type = "ground", executed = false, template = { name = "STRIKE/C2/2" } }, "FOUND_NEXT"
      ))

      local reconContext = makeReconContext({ entry })
      Recon.handleReconQueue(config, reconContext, reconSchedule, LACMContext)

      assert.is_true(entry.isFinished)
      -- Should have scheduled operations (STRIKE/C2/1 new + STRIKE/C2/2 next)
      assert.is_true(#reconSchedule > 0)
    end)

    it("should skip STRIKE/AB/E/1 when LACM is not enabled", function()
      local cfg = makeConfig()
      cfg.c.recon.reconStrikeMatrix.UAV.BZK005 = {
        { name = "STRIKE/AB/E/1", type = "air" },
      }

      local entry = makeUAVEntry({ hasLaunched = true, unitGUID = "AC-001" })
      local ac = makeUnit({ guid = "AC-001", course = {} })

      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(ac))
      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(DynamicOperationsUtils, "getLastExecutedOperationsAndNextTime").returns({
        air = {}, ground = {}, mostRecentTime = nil, nextReconTime = nil,
      }))
      trackStub(stub(DynamicOperationsUtils, "hasOperation").returns(false))

      local reconContext = makeReconContext({ entry })
      Recon.handleReconQueue(config, reconContext, reconSchedule, LACMContext)

      -- LACM not enabled => STRIKE/AB/E/1 skipped => no operations
      assert.is_true(entry.isFinished)
    end)

    it("should not schedule operations when mission fails", function()
      local entry = makeUAVEntry({ hasLaunched = true, unitGUID = "AC-001" })

      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(nil))
      trackStub(stub(GameUtils, "isAfterStartTime").returns(false))

      local reconContext = makeReconContext({ entry })
      Recon.handleReconQueue(config, reconContext, reconSchedule, LACMContext)

      assert.is_true(entry.isFinished)
      assert.are.equal(0, #reconSchedule)
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
      Recon.handleReconQueue(config, reconContext, reconSchedule, LACMContext)

      assert.is_true(hasLogCall("recon", "%[OK%]"))
      assert.stub(Logger.error).was_not.called()
    end)

    it("should batch log [SKIP] via Logger.log when UAV is not ready for launch", function()
      local entry = makeUAVEntry()

      trackStub(stub(GameUtils, "isAfterStartTime").returns(false))

      local reconContext = makeReconContext({ entry })
      Recon.handleReconQueue(config, reconContext, reconSchedule, LACMContext)

      assert.is_true(hasLogCall("recon", "%[SKIP%]"))
      assert.stub(Logger.error).was_not.called()
    end)

    it("should batch log [FAIL] via Logger.error when UAV destroyed before endTime", function()
      local entry = makeUAVEntry({ hasLaunched = true, unitGUID = "AC-001" })

      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(nil))
      trackStub(stub(GameUtils, "isAfterStartTime").returns(false))

      local reconContext = makeReconContext({ entry })
      Recon.handleReconQueue(config, reconContext, reconSchedule, LACMContext)

      assert.is_true(hasErrorCall("%[FAIL%]"))
    end)

    it("should batch log [OK] via Logger.log for satellite completion", function()
      local entry = makeSatelliteEntry()

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(DynamicOperationsUtils, "getLastExecutedOperationsAndNextTime").returns({
        air = {}, ground = {}, mostRecentTime = nil, nextReconTime = nil,
      }))

      local reconContext = makeReconContext({ entry })
      Recon.handleReconQueue(config, reconContext, reconSchedule, LACMContext)

      assert.is_true(hasLogCall("recon", "%[OK%]"))
      assert.stub(Logger.error).was_not.called()
    end)

    it("should not emit any recon log when all entries are already finished", function()
      local entry1 = makeUAVEntry({ hasLaunched = true, unitGUID = "AC-001", isFinished = true })
      local entry2 = makeSatelliteEntry({ isFinished = true })

      local reconContext = makeReconContext({ entry1, entry2 })
      Recon.handleReconQueue(config, reconContext, reconSchedule, LACMContext)

      assert.is_false(hasLogCall("recon", "."))
      assert.stub(Logger.error).was_not.called()
    end)

    -- ========================================================================
    -- Dynamic operations scheduling (indirect getPlatformSpecialOperations)
    -- ========================================================================

    it("should handle missing reconStrikeMatrix for entry platform type", function()
      local cfg = makeConfig()
      cfg.c.recon.reconStrikeMatrix.UAV = nil

      local entry = makeUAVEntry({ hasLaunched = true, unitGUID = "AC-001" })
      local ac = makeUnit({ guid = "AC-001", course = {} })

      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(ac))
      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(DynamicOperationsUtils, "getLastExecutedOperationsAndNextTime").returns({
        air = {}, ground = {}, mostRecentTime = nil, nextReconTime = nil,
      }))

      local reconContext = makeReconContext({ entry })
      Recon.handleReconQueue(cfg, reconContext, reconSchedule, LACMContext)

      assert.is_true(entry.isFinished)
      -- No operations scheduled (no strike matrix for UAV type)
      assert.are.equal(0, #reconSchedule)
    end)

    it("should process multiple strikeMappings with mixed new, skip, and next", function()
      local cfg = makeConfig()
      cfg.c.recon.reconStrikeMatrix.UAV.BZK005 = {
        { name = "STRIKE/C2/1", type = "ground" },
        { name = "STRIKE/AB/E/1", type = "air" },
      }
      cfg.c.fireSupportTaskTemplates.STRIKE_C2_1 = { { name = "FST-C2-1" } }

      local entry = makeUAVEntry({ hasLaunched = true, unitGUID = "AC-001" })
      local ac = makeUnit({ guid = "AC-001", course = {} })

      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(ac))
      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(DynamicOperationsUtils, "getLastExecutedOperationsAndNextTime").returns({
        air = {}, ground = {}, mostRecentTime = nil, nextReconTime = nil,
      }))
      trackStub(stub(DynamicOperationsUtils, "hasOperation").invokes(function(schedule, name, opType)
        -- Exact matches: not found (new)
        if name == "STRIKE/C2/1" and opType == "ground" then return false end
        if name == "STRIKE/AB/E/1" and opType == "air" then return false end
        -- Prefix match: found existing for C2
        if name == "STRIKE/C2/" and opType == "ground" then
          return true, { type = "ground", template = { name = "STRIKE/C2/1" } }
        end
        return false
      end))
      trackStub(stub(DynamicOperationsUtils, "generateNextOperation").returns(
        { type = "ground", executed = false, template = { name = "STRIKE/C2/2" } }, "FOUND_NEXT"
      ))

      local reconContext = makeReconContext({ entry })
      Recon.handleReconQueue(cfg, reconContext, reconSchedule, LACMContext)

      assert.is_true(entry.isFinished)
      -- Should have scheduled operations: STRIKE/C2/1 (new) + STRIKE/C2/2 (next)
      -- STRIKE/AB/E/1 skipped due to LACM not enabled
      assert.are.equal(1, #reconSchedule)
      local scheduledEntry = reconSchedule[1]
      assert.are.equal(2, #scheduledEntry.operations)
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
        guid = "UAV-FAR", dbid = UAVDBID, condition = "Airborne",
        latitude = 28.0, longitude = 122.0,
      })
      local closeUAV = makeUnit({
        guid = "UAV-CLOSE", dbid = UAVDBID, condition = "Airborne",
        latitude = 23.5, longitude = 119.5,
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
        return 100 -- closeUAV
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
    ---Shallow copy that copies each entry as a new table (simulates deepCopy for flat entries)
    local function shallowCopyQueue(t)
      local copy = {}
      for i, v in ipairs(t) do
        local entryCopy = {}
        for k, val in pairs(v) do entryCopy[k] = val end
        copy[i] = entryCopy
      end
      return copy
    end

    before_each(function()
      trackStub(stub(Utils, "deepCopy").invokes(shallowCopyQueue))
    end)

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

      Recon.initReconQueueEntries(reconConfig, reconContext)

      assert.stub(Utils.deepCopy).was.called(1)
      -- Original should not have isFinished field
      assert.is_nil(reconConfig.queue[1].isFinished)
    end)
  end)
end)
