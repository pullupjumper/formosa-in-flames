-- AirTaskingOrder Unit Tests
local AirTaskingOrder = require("src.modules.strikePlanner.airTaskingOrder")
local Utils = require("src.utils.utils")
local GameApi = require("src.utils.gameApi")
local GameUtils = require("src.utils.gameUtils")
local Logger = require("src.utils.logger")
local AssignMission = require("src.modules.assignMission")
local BaseConfig = require("src.core.config")

describe("AirTaskingOrder", function()
  ---@type luassert.spy[]
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

  ---Create a MissionDeploymentDescriptor with sensible defaults
  ---@param overrides? table
  ---@return table
  local function makeRole(overrides)
    overrides = overrides or {}
    return {
      baseGUID = overrides.baseGUID or "BASE-1",
      missionCreationParams = overrides.missionCreationParams or {
        name = overrides.missionName or "STRIKE-MISSION-1",
        type = overrides.missionType or "strike",
        opts = overrides.opts or {}
      },
      unitCount = overrides.unitCount or 2,
      weaponDBID = overrides.weaponDBID or 3000,
      unitDBID = overrides.unitDBID or 100,
      loadoutID = overrides.loadoutID,
      startTime = overrides.startTime or "2026-02-14 06:00:00",
      endTime = overrides.endTime or "2026-02-14 08:00:00",
      timeOnStation = overrides.timeOnStation,
      emcon = overrides.emcon or "Radar=Passive"
    }
  end

  ---Create a package; defaults to loadout-already-done state for lifecycle tests
  ---@param overrides? table
  ---@return table
  local function makePackage(overrides)
    overrides = overrides or {}
    return {
      hasLaunched = overrides.hasLaunched or false,
      timeToReady = overrides.timeToReady,
      loadoutStatus = overrides.loadoutStatus or {
        isLoadoutInitiated = true,
        loadoutInitiatedTime = 1000,
        expectedReadyTime = 1500,
        loadoutStartTime = 800
      },
      striker = overrides.striker or makeRole({ missionName = "STRIKE-PKG-1" }),
      escort = overrides.escort,
      wildWeasel = overrides.wildWeasel,
      jammer = overrides.jammer,
      tanker = overrides.tanker,
      reconUAV = overrides.reconUAV,
      target = overrides.target or {
        list = overrides.targetList or { "TGT-1", "TGT-2" },
        minTargetCount = overrides.minTargetCount or 1
      }
    }
  end

  ---Create full saveData with one ATO wave
  ---@param overrides? table
  ---@return table
  local function makeSaveData(overrides)
    overrides = overrides or {}
    local packages = overrides.packages or { makePackage(overrides.packageOverrides) }

    local wave = {
      isActivated = overrides.isActivated == nil and true or overrides.isActivated,
      hasLaunched = overrides.waveHasLaunched or false,
      packages = packages
    }

    local ato = { [overrides.waveName or "WAVE-1"] = wave }

    if overrides.extraWaves then
      for name, w in pairs(overrides.extraWaves) do
        ato[name] = w
      end
    end

    return {
      c = {
        air = { airTaskingOrder = ato },
        recon = overrides.reconContext or { queue = {} }
      }
    }
  end


  ---Create a full typed config for airStrike tests
  ---@return SBJ__Config
  local function makeConfig()
    return Utils.deepCopy(BaseConfig) --[[@as SBJ__Config]]
  end

  ---Stub all dependencies needed for a package to fully launch (steps 4-8)
  local function stubMissionAndAssignment()
    trackStub(stub(GameApi, "ScenEdit_GetMission").returns(nil))
    trackStub(stub(GameUtils, "createMission").returns({ name = "m" }))
    trackStub(stub(GameApi, "ScenEdit_SetDoctrine"))
    trackStub(stub(GameApi, "ScenEdit_AssignUnitAsTarget").returns(true))
    trackStub(stub(AssignMission, "assignEmbarkedUnitToStrikeMission").returns({ "U1" }))
    trackStub(stub(GameApi, "ScenEdit_CreateMissionFlightPlan"))
  end

  -- ============================================================================
  -- Wave filtering
  -- ============================================================================

  describe("wave filtering", function()
    -- Negative: wave not activated
    it("should skip non-activated waves", function()
      local saveData = makeSaveData({ isActivated = false })
      local stubIsAfter = trackStub(stub(GameUtils, "isAfterStartTime"))

      AirTaskingOrder.airStrike(makeConfig(), saveData)

      assert.stub(stubIsAfter).was_not.called()
    end)

    -- Negative: wave already launched
    it("should skip already-launched waves", function()
      local saveData = makeSaveData({ waveHasLaunched = true })
      local stubIsAfter = trackStub(stub(GameUtils, "isAfterStartTime"))

      AirTaskingOrder.airStrike(makeConfig(), saveData)

      assert.stub(stubIsAfter).was_not.called()
    end)

    -- Negative: package already launched
    it("should skip already-launched packages within active wave", function()
      local pkg = makePackage({ hasLaunched = true })
      local saveData = makeSaveData({ packages = { pkg } })
      local stubIsAfter = trackStub(stub(GameUtils, "isAfterStartTime"))

      AirTaskingOrder.airStrike(makeConfig(), saveData)

      assert.stub(stubIsAfter).was_not.called()
    end)

    -- Boundary: empty ATO
    it("should handle empty airTaskingOrder without error", function()
      local saveData = { c = { air = { airTaskingOrder = {} } } }

      AirTaskingOrder.airStrike(makeConfig(), saveData)
    end)
  end)

  -- ============================================================================
  -- Loadout timing (isTimeToStartLoadout)
  -- ============================================================================

  describe("loadout timing", function()
    -- Negative: time not reached
    it("should not proceed when loadout start time not reached", function()
      local pkg = makePackage({ loadoutStatus = { isLoadoutInitiated = false, loadoutStartTime = nil } })
      local saveData = makeSaveData({ packages = { pkg } })

      trackStub(stub(GameUtils, "isAfterStartTime").returns(false))
      trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(5000))
      local stubGetUnit = trackStub(stub(GameApi, "ScenEdit_GetUnit"))

      AirTaskingOrder.airStrike(makeConfig(), saveData)

      assert.stub(stubGetUnit).was_not.called()
      assert.is_false(pkg.hasLaunched)
    end)

    -- Negative: nil loadoutStatus
    it("should not proceed when loadoutStatus is nil", function()
      local pkg = makePackage()
      pkg.loadoutStatus = nil
      local saveData = makeSaveData({ packages = { pkg } })

      AirTaskingOrder.airStrike(makeConfig(), saveData)

      assert.is_false(pkg.hasLaunched)
    end)

    -- Positive: calculate loadoutStartTime
    it("should calculate loadoutStartTime as earliest startTime minus timeToReady", function()
      local pkg = makePackage({
        timeToReady = 600,
        loadoutStatus = { isLoadoutInitiated = false, loadoutStartTime = nil }
      })
      local saveData = makeSaveData({ packages = { pkg } })

      trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(5000))
      trackStub(stub(GameUtils, "isAfterStartTime").returns(false))

      AirTaskingOrder.airStrike(makeConfig(), saveData)

      assert.are.equal(5000 - 600, pkg.loadoutStatus.loadoutStartTime)
    end)

    -- Positive: default timeToReady
    it("should default timeToReady to 9*60 when not specified", function()
      local pkg = makePackage({
        loadoutStatus = { isLoadoutInitiated = false, loadoutStartTime = nil }
      })
      local saveData = makeSaveData({ packages = { pkg } })

      trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(5000))
      trackStub(stub(GameUtils, "isAfterStartTime").returns(false))

      AirTaskingOrder.airStrike(makeConfig(), saveData)

      assert.are.equal(5000 - 540, pkg.loadoutStatus.loadoutStartTime)
    end)

    -- Positive: earliest across multiple roles
    it("should pick earliest startTime across all roles", function()
      local escort = makeRole({
        missionName = "ESCORT-1",
        startTime = "2026-02-14 05:30:00"
      })
      local pkg = makePackage({
        escort = escort,
        timeToReady = 600,
        loadoutStatus = { isLoadoutInitiated = false, loadoutStartTime = nil }
      })
      local saveData = makeSaveData({ packages = { pkg } })

      trackStub(stub(Utils, "parseDatetimeToTimestamp").invokes(function(dateStr)
        if dateStr == "2026-02-14 05:30:00" then return 4000 end
        return 5000
      end))
      trackStub(stub(GameUtils, "isAfterStartTime").returns(false))

      AirTaskingOrder.airStrike(makeConfig(), saveData)

      -- Earliest = escort 4000, minus timeToReady 600 = 3400
      assert.are.equal(3400, pkg.loadoutStatus.loadoutStartTime)
    end)

    -- Boundary: no role has startTime
    it("should return nil when no role has startTime", function()
      local striker = makeRole({ missionName = "STRIKE-PKG-1" })
      striker.startTime = nil
      local pkg = makePackage({
        striker = striker,
        loadoutStatus = { isLoadoutInitiated = false, loadoutStartTime = nil }
      })
      local saveData = makeSaveData({ packages = { pkg } })

      trackStub(stub(GameUtils, "isAfterStartTime").returns(false))

      AirTaskingOrder.airStrike(makeConfig(), saveData)

      assert.is_nil(pkg.loadoutStatus.loadoutStartTime)
    end)
  end)

  -- ============================================================================
  -- Loadout initiation (initiateLoadoutForPackage)
  -- ============================================================================

  describe("loadout initiation", function()
    -- Positive: set loadout and update status
    it("should set loadout for matching aircraft and update status", function()
      local striker = makeRole({
        missionName = "STRIKE-PKG-1",
        loadoutID = 5001,
        unitDBID = 100,
        unitCount = 2
      })
      local pkg = makePackage({
        striker = striker,
        timeToReady = 600,
        loadoutStatus = { isLoadoutInitiated = false }
      })
      local saveData = makeSaveData({ packages = { pkg } })

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(2000))
      trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(3000))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
        if guid == "BASE-1" then
          return {
            guid = "BASE-1",
            name = "Air Base",
            embarkedUnits = { Aircraft = { "AC-1", "AC-2", "AC-3" } }
          }
        end
        return { guid = guid, name = "AC-" .. guid, dbid = 100 }
      end))
      local stubSetLoadout = trackStub(stub(GameApi, "ScenEdit_SetLoadout").returns(true))

      AirTaskingOrder.airStrike(makeConfig(), saveData)

      assert.stub(stubSetLoadout).was.called(2)
      assert.is_true(pkg.loadoutStatus.isLoadoutInitiated)
      assert.are.equal(3000, pkg.loadoutStatus.loadoutInitiatedTime)
      assert.are.equal(3600, pkg.loadoutStatus.expectedReadyTime)
      -- Package NOT launched yet (isLoadoutReady returns false on first initiation)
      assert.is_false(pkg.hasLaunched)
    end)

    -- Negative: no loadoutID
    it("should skip roles without loadoutID", function()
      local striker = makeRole({ missionName = "STRIKE-PKG-1" })
      -- loadoutID is nil by default
      local pkg = makePackage({
        striker = striker,
        loadoutStatus = { isLoadoutInitiated = false }
      })
      local saveData = makeSaveData({ packages = { pkg } })

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(2000))
      trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(3000))
      local stubSetLoadout = trackStub(stub(GameApi, "ScenEdit_SetLoadout"))

      AirTaskingOrder.airStrike(makeConfig(), saveData)

      assert.stub(stubSetLoadout).was_not.called()
    end)

    -- Negative: no unitDBID
    it("should skip roles without unitDBID", function()
      local striker = makeRole({ missionName = "STRIKE-PKG-1", loadoutID = 5001 })
      striker.unitDBID = nil
      local pkg = makePackage({
        striker = striker,
        loadoutStatus = { isLoadoutInitiated = false }
      })
      local saveData = makeSaveData({ packages = { pkg } })

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(2000))
      trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(3000))
      local stubGetUnit = trackStub(stub(GameApi, "ScenEdit_GetUnit"))

      AirTaskingOrder.airStrike(makeConfig(), saveData)

      -- goto continue skips the base lookup
      assert.stub(stubGetUnit).was_not.called()
    end)

    -- Positive: filter by unitDBID
    it("should only set loadout for aircraft matching target unitDBID", function()
      local striker = makeRole({
        missionName = "STRIKE-PKG-1",
        loadoutID = 5001,
        unitDBID = 100,
        unitCount = 2
      })
      local pkg = makePackage({
        striker = striker,
        loadoutStatus = { isLoadoutInitiated = false }
      })
      local saveData = makeSaveData({ packages = { pkg } })

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(2000))
      trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(3000))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
        if guid == "BASE-1" then
          return {
            guid = "BASE-1",
            name = "Air Base",
            embarkedUnits = { Aircraft = { "AC-1", "AC-2", "AC-3" } }
          }
        end
        if guid == "AC-1" then return { guid = "AC-1", name = "J-16-1", dbid = 100 } end
        if guid == "AC-2" then return { guid = "AC-2", name = "KJ-500", dbid = 999 } end
        if guid == "AC-3" then return { guid = "AC-3", name = "J-16-2", dbid = 100 } end
        return nil
      end))
      local stubSetLoadout = trackStub(stub(GameApi, "ScenEdit_SetLoadout").returns(true))

      AirTaskingOrder.airStrike(makeConfig(), saveData)

      assert.stub(stubSetLoadout).was.called(2)
      assert.are.equal("J-16-1", stubSetLoadout.calls[1].vals[1].unitname)
      assert.are.equal("J-16-2", stubSetLoadout.calls[2].vals[1].unitname)
    end)

    -- Boundary: unitCount limit
    it("should not exceed unitCount when setting loadouts", function()
      local striker = makeRole({
        missionName = "STRIKE-PKG-1",
        loadoutID = 5001,
        unitDBID = 100,
        unitCount = 1
      })
      local pkg = makePackage({
        striker = striker,
        loadoutStatus = { isLoadoutInitiated = false }
      })
      local saveData = makeSaveData({ packages = { pkg } })

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(2000))
      trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(3000))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
        if guid == "BASE-1" then
          return {
            guid = "BASE-1",
            name = "Air Base",
            embarkedUnits = { Aircraft = { "AC-1", "AC-2", "AC-3" } }
          }
        end
        return { guid = guid, name = "Aircraft", dbid = 100 }
      end))
      local stubSetLoadout = trackStub(stub(GameApi, "ScenEdit_SetLoadout").returns(true))

      AirTaskingOrder.airStrike(makeConfig(), saveData)

      -- unitCount = 1, so only 1 loadout despite 3 matching aircraft
      assert.stub(stubSetLoadout).was.called(1)
    end)

    -- Positive: multiple roles
    it("should set loadouts for multiple roles in same package", function()
      local striker = makeRole({
        missionName = "STRIKE-PKG-1",
        loadoutID = 5001,
        unitDBID = 100,
        unitCount = 1,
        baseGUID = "BASE-1"
      })
      local escort = makeRole({
        missionName = "ESCORT-1",
        missionType = "patrol",
        loadoutID = 6001,
        unitDBID = 200,
        unitCount = 1,
        baseGUID = "BASE-2"
      })
      local pkg = makePackage({
        striker = striker,
        escort = escort,
        loadoutStatus = { isLoadoutInitiated = false }
      })
      local saveData = makeSaveData({ packages = { pkg } })

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(2000))
      trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(3000))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
        if guid == "BASE-1" then
          return { guid = "BASE-1", name = "Base 1", embarkedUnits = { Aircraft = { "AC-1" } } }
        end
        if guid == "BASE-2" then
          return { guid = "BASE-2", name = "Base 2", embarkedUnits = { Aircraft = { "AC-2" } } }
        end
        if guid == "AC-1" then return { guid = "AC-1", name = "J-16", dbid = 100 } end
        if guid == "AC-2" then return { guid = "AC-2", name = "J-11", dbid = 200 } end
        return nil
      end))
      local stubSetLoadout = trackStub(stub(GameApi, "ScenEdit_SetLoadout").returns(true))

      AirTaskingOrder.airStrike(makeConfig(), saveData)

      assert.stub(stubSetLoadout).was.called(2)
      assert.are.equal(5001, stubSetLoadout.calls[1].vals[1].LoadoutID)
      assert.are.equal(6001, stubSetLoadout.calls[2].vals[1].LoadoutID)
    end)

    -- Negative: base not found
    it("should handle base not found gracefully", function()
      local striker = makeRole({
        missionName = "STRIKE-PKG-1",
        loadoutID = 5001,
        unitDBID = 100
      })
      local pkg = makePackage({
        striker = striker,
        loadoutStatus = { isLoadoutInitiated = false }
      })
      local saveData = makeSaveData({ packages = { pkg } })

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(2000))
      trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(3000))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(nil))
      local stubSetLoadout = trackStub(stub(GameApi, "ScenEdit_SetLoadout"))

      AirTaskingOrder.airStrike(makeConfig(), saveData)

      assert.stub(stubSetLoadout).was_not.called()
      -- Still marks as initiated (function completes normally)
      assert.is_true(pkg.loadoutStatus.isLoadoutInitiated)
    end)

    -- Boundary: empty aircraft list
    it("should handle base with empty aircraft list", function()
      local striker = makeRole({
        missionName = "STRIKE-PKG-1",
        loadoutID = 5001,
        unitDBID = 100
      })
      local pkg = makePackage({
        striker = striker,
        loadoutStatus = { isLoadoutInitiated = false }
      })
      local saveData = makeSaveData({ packages = { pkg } })

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(2000))
      trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(3000))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns({
        guid = "BASE-1",
        name = "Air Base",
        embarkedUnits = { Aircraft = {} }
      }))
      local stubSetLoadout = trackStub(stub(GameApi, "ScenEdit_SetLoadout"))

      AirTaskingOrder.airStrike(makeConfig(), saveData)

      assert.stub(stubSetLoadout).was_not.called()
    end)

    -- Negative: partial SetLoadout failure
    it("should continue processing when SetLoadout fails for individual aircraft", function()
      local striker = makeRole({
        missionName = "STRIKE-PKG-1",
        loadoutID = 5001,
        unitDBID = 100,
        unitCount = 2
      })
      local pkg = makePackage({
        striker = striker,
        loadoutStatus = { isLoadoutInitiated = false }
      })
      local saveData = makeSaveData({ packages = { pkg } })

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(2000))
      trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(3000))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
        if guid == "BASE-1" then
          return {
            guid = "BASE-1",
            name = "Air Base",
            embarkedUnits = { Aircraft = { "AC-1", "AC-2", "AC-3" } }
          }
        end
        return { guid = guid, name = "Aircraft-" .. guid, dbid = 100 }
      end))
      -- First aircraft (AC-1) fails, remaining succeed
      local stubSetLoadout = trackStub(stub(GameApi, "ScenEdit_SetLoadout").invokes(function(params)
        if params.unitname == "Aircraft-AC-1" then return nil end
        return true
      end))

      AirTaskingOrder.airStrike(makeConfig(), saveData)

      -- All 3 aircraft attempted (first fails, second/third succeed -> 2 processed = unitCount)
      assert.stub(stubSetLoadout).was.called(3)
      assert.is_true(pkg.loadoutStatus.isLoadoutInitiated)
    end)
  end)

  -- ============================================================================
  -- Loadout readiness (isLoadoutReady)
  -- ============================================================================

  describe("loadout readiness", function()
    -- Positive: loadout ready
    it("should proceed when loadout initiated and ready time passed", function()
      local pkg = makePackage({
        loadoutStatus = {
          isLoadoutInitiated = true,
          expectedReadyTime = 1500
        }
      })
      local saveData = makeSaveData({ packages = { pkg } })

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(2000))
      stubMissionAndAssignment()

      AirTaskingOrder.airStrike(makeConfig(), saveData)

      assert.is_true(pkg.hasLaunched)
    end)

    -- Negative: nil expectedReadyTime
    it("should not proceed when loadout initiated but expectedReadyTime is nil", function()
      local pkg = makePackage({
        loadoutStatus = {
          isLoadoutInitiated = true,
          expectedReadyTime = nil
        }
      })
      local saveData = makeSaveData({ packages = { pkg } })

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(2000))

      AirTaskingOrder.airStrike(makeConfig(), saveData)

      assert.is_false(pkg.hasLaunched)
    end)
  end)

  -- ============================================================================
  -- Departure time check (findEarliestRole)
  -- ============================================================================

  describe("departure time check", function()
    -- Negative: departure time not reached
    it("should not launch when departure time not reached", function()
      local pkg = makePackage({
        loadoutStatus = {
          isLoadoutInitiated = true,
          expectedReadyTime = 1500
        }
      })
      local saveData = makeSaveData({ packages = { pkg } })

      -- departure check receives string startTime; loadout checks receive numeric timestamps
      trackStub(stub(GameUtils, "isAfterStartTime").invokes(function(timeVal)
        if type(timeVal) == "string" then return false end
        return true
      end))
      trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(2000))

      AirTaskingOrder.airStrike(makeConfig(), saveData)

      assert.is_false(pkg.hasLaunched)
    end)

    -- Negative: no startTime on any role
    it("should not launch when no role has startTime", function()
      local striker = makeRole({ missionName = "STRIKE-PKG-1" })
      striker.startTime = nil
      local pkg = makePackage({
        striker = striker,
        loadoutStatus = {
          isLoadoutInitiated = true,
          expectedReadyTime = 1500
        }
      })
      local saveData = makeSaveData({ packages = { pkg } })

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(2000))

      AirTaskingOrder.airStrike(makeConfig(), saveData)

      -- findEarliestRole returns nil -> processPackage returns false
      assert.is_false(pkg.hasLaunched)
    end)

    -- Positive: earliest role selection
    it("should use earliest startTime among all roles for departure check", function()
      local escort = makeRole({
        missionName = "ESCORT-1",
        startTime = "2026-02-14 05:30:00"
      })
      local pkg = makePackage({
        escort = escort,
        loadoutStatus = {
          isLoadoutInitiated = true,
          expectedReadyTime = 1500
        }
      })
      local saveData = makeSaveData({ packages = { pkg } })

      trackStub(stub(Utils, "parseDatetimeToTimestamp").invokes(function(dateStr)
        if dateStr == "2026-02-14 05:30:00" then return 4000 end
        return 5000
      end))

      local stubIsAfter = trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      stubMissionAndAssignment()

      AirTaskingOrder.airStrike(makeConfig(), saveData)

      -- 3rd call = departure check, should use escort's startTime (earlier)
      assert.are.equal("2026-02-14 05:30:00", stubIsAfter.calls[3].vals[1])
      assert.are.equal(300, stubIsAfter.calls[3].vals[2])
    end)
  end)

  -- ============================================================================
  -- Mission creation (createMission)
  -- ============================================================================

  describe("mission creation", function()
    -- Positive: create new mission
    it("should create mission when it does not exist", function()
      local pkg = makePackage()
      local saveData = makeSaveData({ packages = { pkg } })

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(2000))
      trackStub(stub(GameApi, "ScenEdit_GetMission").returns(nil))
      local stubCreate = trackStub(stub(GameUtils, "createMission").returns({ name = "m" }))
      trackStub(stub(GameApi, "ScenEdit_SetDoctrine"))
      trackStub(stub(GameApi, "ScenEdit_AssignUnitAsTarget").returns(true))
      trackStub(stub(AssignMission, "assignEmbarkedUnitToStrikeMission").returns({ "U1" }))
      trackStub(stub(GameApi, "ScenEdit_CreateMissionFlightPlan"))

      AirTaskingOrder.airStrike(makeConfig(), saveData)

      assert.stub(stubCreate).was.called(1)
      assert.are.equal("China", stubCreate.calls[1].vals[1])
      assert.are.equal("STRIKE-PKG-1", stubCreate.calls[1].vals[2])
    end)

    -- Positive: mission properties assignment
    it("should set mission properties on newly created strike mission", function()
      local striker = makeRole({
        missionName = "STRIKE-PKG-1",
        startTime = "2026-02-14 06:00:00",
        endTime = "2026-02-14 08:00:00",
        timeOnStation = "00:30"
      })
      local pkg = makePackage({ striker = striker })
      local saveData = makeSaveData({ packages = { pkg } })

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(2000))
      trackStub(stub(GameApi, "ScenEdit_GetMission").returns(nil))
      local missionObj = { name = "STRIKE-PKG-1" }
      trackStub(stub(GameUtils, "createMission").returns(missionObj))
      local stubDoctrine = trackStub(stub(GameApi, "ScenEdit_SetDoctrine"))
      trackStub(stub(GameApi, "ScenEdit_AssignUnitAsTarget").returns(true))
      trackStub(stub(AssignMission, "assignEmbarkedUnitToStrikeMission").returns({ "U1" }))
      trackStub(stub(GameApi, "ScenEdit_CreateMissionFlightPlan"))

      AirTaskingOrder.airStrike(makeConfig(), saveData)

      assert.is_true(missionObj.OnDeactivateDelete)
      assert.is_true(missionObj.OnDeactivateRTB)
      assert.are.equal("2026-02-14 06:00:00!yyyy-MM-dd HH:mm:ss", missionObj.TakeOffTime)
      assert.are.equal("2026-02-14 08:00:00!yyyy-MM-dd HH:mm:ss", missionObj.endtime)
      assert.are.equal("00:30!yyyy-MM-dd HH:mm:ss", missionObj.TimeOnTargetStation)
      assert.stub(stubDoctrine).was.called(1)
    end)

    -- Negative: striker creation fails
    it("should abort package when striker mission creation fails", function()
      local pkg = makePackage()
      local saveData = makeSaveData({ packages = { pkg } })

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(2000))
      trackStub(stub(GameApi, "ScenEdit_GetMission").returns(nil))
      trackStub(stub(GameUtils, "createMission").returns(nil))
      local stubAssignTarget = trackStub(stub(GameApi, "ScenEdit_AssignUnitAsTarget"))

      AirTaskingOrder.airStrike(makeConfig(), saveData)

      assert.is_false(pkg.hasLaunched)
      assert.stub(stubAssignTarget).was_not.called()
    end)

    -- Negative: non-striker creation fails (non-critical)
    it("should continue when non-striker mission creation fails", function()
      local escort = makeRole({
        missionName = "ESCORT-1",
        missionType = "patrol",
        startTime = "2026-02-14 05:50:00"
      })
      local pkg = makePackage({ escort = escort })
      local saveData = makeSaveData({ packages = { pkg } })

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(2000))
      -- Striker found but escort not found and creation fails
      trackStub(stub(GameApi, "ScenEdit_GetMission").returns(nil))
      trackStub(stub(GameUtils, "createMission").invokes(function(_, name)
        if name == "STRIKE-PKG-1" then return { name = name } end
        return nil
      end))
      trackStub(stub(GameApi, "ScenEdit_SetDoctrine"))
      trackStub(stub(GameApi, "ScenEdit_AssignUnitAsTarget").returns(true))
      trackStub(stub(AssignMission, "assignEmbarkedUnitToStrikeMission").returns({ "U1" }))
      trackStub(stub(GameApi, "ScenEdit_CreateMissionFlightPlan"))

      AirTaskingOrder.airStrike(makeConfig(), saveData)

      -- Package still launches because only striker failure is critical
      assert.is_true(pkg.hasLaunched)
    end)

    -- Negative: non-strike type skips doctrine
    it("should not set doctrine for non-strike mission types", function()
      local escort = makeRole({
        missionName = "ESCORT-1",
        missionType = "patrol",
        startTime = "2026-02-14 05:50:00"
      })
      local pkg = makePackage({ escort = escort })
      local saveData = makeSaveData({ packages = { pkg } })

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(2000))
      trackStub(stub(GameApi, "ScenEdit_GetMission").returns(nil))
      trackStub(stub(GameUtils, "createMission").returns({ name = "m" }))
      local stubDoctrine = trackStub(stub(GameApi, "ScenEdit_SetDoctrine"))
      trackStub(stub(GameApi, "ScenEdit_AssignUnitAsTarget").returns(true))
      trackStub(stub(AssignMission, "assignEmbarkedUnitToStrikeMission").returns({ "U1" }))
      trackStub(stub(GameApi, "ScenEdit_CreateMissionFlightPlan"))

      AirTaskingOrder.airStrike(makeConfig(), saveData)

      -- Only 1 doctrine call for striker (type "strike"), not for escort (type "patrol")
      assert.stub(stubDoctrine).was.called(1)
    end)
  end)

  -- ============================================================================
  -- Target assignment
  -- ============================================================================

  describe("target assignment", function()
    -- Negative: insufficient targets
    it("should not launch when target count below minTargetCount", function()
      local pkg = makePackage({ targetList = {}, minTargetCount = 3 })
      local saveData = makeSaveData({ packages = { pkg } })

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(2000))
      trackStub(stub(GameApi, "ScenEdit_GetMission").returns(nil))
      trackStub(stub(GameUtils, "createMission").returns({ name = "m" }))
      trackStub(stub(GameApi, "ScenEdit_SetDoctrine"))
      local stubAssignTarget = trackStub(stub(GameApi, "ScenEdit_AssignUnitAsTarget"))

      AirTaskingOrder.airStrike(makeConfig(), saveData)

      assert.is_false(pkg.hasLaunched)
      assert.stub(stubAssignTarget).was_not.called()
    end)

    -- Boundary: exactly minTargetCount
    it("should proceed when target count equals minTargetCount", function()
      local pkg = makePackage({
        targetList = { "TGT-1", "TGT-2", "TGT-3" },
        minTargetCount = 3
      })
      local saveData = makeSaveData({ packages = { pkg } })

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(2000))
      stubMissionAndAssignment()

      AirTaskingOrder.airStrike(makeConfig(), saveData)

      assert.is_true(pkg.hasLaunched)
    end)

    -- Positive: target list forwarding
    it("should pass target list to ScenEdit_AssignUnitAsTarget", function()
      local targets = { "TGT-A", "TGT-B" }
      local pkg = makePackage({ targetList = targets })
      local saveData = makeSaveData({ packages = { pkg } })

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(2000))
      trackStub(stub(GameApi, "ScenEdit_GetMission").returns(nil))
      trackStub(stub(GameUtils, "createMission").returns({ name = "m" }))
      trackStub(stub(GameApi, "ScenEdit_SetDoctrine"))
      local stubAssignTarget = trackStub(stub(GameApi, "ScenEdit_AssignUnitAsTarget").returns(true))
      trackStub(stub(AssignMission, "assignEmbarkedUnitToStrikeMission").returns({ "U1" }))
      trackStub(stub(GameApi, "ScenEdit_CreateMissionFlightPlan"))

      AirTaskingOrder.airStrike(makeConfig(), saveData)

      assert.are.same(targets, stubAssignTarget.calls[1].vals[1])
      assert.are.equal("STRIKE-PKG-1", stubAssignTarget.calls[1].vals[2])
    end)

    -- Negative: target assignment API returns nil
    it("should not launch when ScenEdit_AssignUnitAsTarget returns nil", function()
      local pkg = makePackage()
      local saveData = makeSaveData({ packages = { pkg } })

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(2000))
      trackStub(stub(GameApi, "ScenEdit_GetMission").returns(nil))
      trackStub(stub(GameUtils, "createMission").returns({ name = "m" }))
      trackStub(stub(GameApi, "ScenEdit_SetDoctrine"))
      trackStub(stub(GameApi, "ScenEdit_AssignUnitAsTarget").returns(nil))
      local stubAssignUnits = trackStub(stub(AssignMission, "assignEmbarkedUnitToStrikeMission"))

      AirTaskingOrder.airStrike(makeConfig(), saveData)

      assert.is_false(pkg.hasLaunched)
      assert.stub(stubAssignUnits).was_not.called()
    end)
  end)

  -- ============================================================================
  -- Unit assignment (assignUnits)
  -- ============================================================================

  describe("unit assignment", function()
    -- Positive: successful assignment
    it("should launch when striker units assigned successfully", function()
      local pkg = makePackage()
      local saveData = makeSaveData({ packages = { pkg } })

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(2000))
      stubMissionAndAssignment()

      AirTaskingOrder.airStrike(makeConfig(), saveData)

      assert.is_true(pkg.hasLaunched)
    end)

    -- Negative: empty assignment result
    it("should not launch when striker assignment returns empty result", function()
      local pkg = makePackage()
      local saveData = makeSaveData({ packages = { pkg } })

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(2000))
      trackStub(stub(GameApi, "ScenEdit_GetMission").returns(nil))
      trackStub(stub(GameUtils, "createMission").returns({ name = "m" }))
      trackStub(stub(GameApi, "ScenEdit_SetDoctrine"))
      trackStub(stub(GameApi, "ScenEdit_AssignUnitAsTarget").returns(true))
      trackStub(stub(AssignMission, "assignEmbarkedUnitToStrikeMission").returns({}))
      trackStub(stub(GameApi, "ScenEdit_CreateMissionFlightPlan"))

      AirTaskingOrder.airStrike(makeConfig(), saveData)

      assert.is_false(pkg.hasLaunched)
    end)

    -- Negative: nil assignment result
    it("should not launch when striker assignment returns nil", function()
      local pkg = makePackage()
      local saveData = makeSaveData({ packages = { pkg } })

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(2000))
      trackStub(stub(GameApi, "ScenEdit_GetMission").returns(nil))
      trackStub(stub(GameUtils, "createMission").returns({ name = "m" }))
      trackStub(stub(GameApi, "ScenEdit_SetDoctrine"))
      trackStub(stub(GameApi, "ScenEdit_AssignUnitAsTarget").returns(true))
      trackStub(stub(AssignMission, "assignEmbarkedUnitToStrikeMission").returns(nil))
      trackStub(stub(GameApi, "ScenEdit_CreateMissionFlightPlan"))

      AirTaskingOrder.airStrike(makeConfig(), saveData)

      assert.is_false(pkg.hasLaunched)
    end)

    -- Positive: flight plan for non-striker/non-tanker roles
    it("should call CreateMissionFlightPlan for support roles only", function()
      local escort = makeRole({
        missionName = "ESCORT-1",
        missionType = "patrol",
        startTime = "2026-02-14 05:50:00"
      })
      local tanker = makeRole({
        missionName = "TANKER-1",
        missionType = "support",
        startTime = "2026-02-14 05:40:00"
      })
      local pkg = makePackage({ escort = escort, tanker = tanker })
      local saveData = makeSaveData({ packages = { pkg } })

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(2000))
      trackStub(stub(GameApi, "ScenEdit_GetMission").returns(nil))
      trackStub(stub(GameUtils, "createMission").returns({ name = "m" }))
      trackStub(stub(GameApi, "ScenEdit_SetDoctrine"))
      trackStub(stub(GameApi, "ScenEdit_AssignUnitAsTarget").returns(true))
      trackStub(stub(AssignMission, "assignEmbarkedUnitToStrikeMission").returns({ "U1" }))

      local stubFlightPlan = trackStub(stub(GameApi, "ScenEdit_CreateMissionFlightPlan"))

      AirTaskingOrder.airStrike(makeConfig(), saveData)

      -- FlightPlan called for escort (non-tanker, non-striker) but NOT for tanker or striker
      assert.stub(stubFlightPlan).was.called(1)
      assert.are.equal("ESCORT-1", stubFlightPlan.calls[1].vals[2])
    end)
  end)

  -- ============================================================================
  -- Recon UAV handling
  -- ============================================================================

  describe("recon UAV handling", function()
    -- Positive: schedule recon UAV with calculated takeoff time
    it("should add reconUAV to recon queue and calculate takeoff time", function()
      local reconUAV = {
        course = { { latitude = 25.0, longitude = 121.0 }, { latitude = 24.0, longitude = 120.0 } },
        speed = 400,
        takeoffTime = nil
      }
      local pkg = makePackage({
        reconUAV = reconUAV,
        striker = {
          startTime = "1970-01-03 08:03:20", endTime = "1970-01-03 11:03:20", missionCreationParams = { name = "" }
        },
      })
      local saveData = makeSaveData({
        packages = { pkg },
        reconContext = {
          queue = {
            {
              type = "satellite",
              reconObjectiveId = "FIXED_SITE_TARGETING",
              endTime = "1970-01-03 15:03:20",
            },
          }
        }
      })
      local config = { c = { ground = { srbm = { reloadTime = 300 } } } }
      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      -- trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(2000))
      stubMissionAndAssignment()
      -- trackStub(stub(GameUtils, "calculatePathDistanceAndTime").returns(500, 500))
      trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(100))

      AirTaskingOrder.airStrike(config, saveData)

      assert.is_true(pkg.hasLaunched)
      assert.are.equal(2, #saveData.c.recon.queue)

      local entry = saveData.c.recon.queue[2]
      assert.is_false(entry.hasLaunched)
      assert.is_false(entry.isFinished)
      assert.is_nil(entry.trackingTargetGUID)
      -- takeoffTime should have been calculated
      assert.is_string(entry.takeoffTime)
      assert.is_string(entry.endTime)
    end)

    -- Negative: insertEntry finds no satellite gap, so nothing is queued but the package still launches
    it("should launch without queueing a recon UAV when no satellite gap exists", function()
      local reconUAV = {
        course = { { latitude = 25.0, longitude = 121.0 }, { latitude = 24.0, longitude = 120.0 } },
        speed = 400,
        takeoffTime = nil
      }
      local pkg = makePackage({ reconUAV = reconUAV })
      -- Default recon queue has no satellite pass, so insertEntry has no window to anchor.
      local saveData = makeSaveData({ packages = { pkg } })
      local config = { c = { ground = { srbm = { reloadTime = 300 } } } }

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(2000))
      trackStub(stub(GameUtils, "calculatePathDistanceAndTime").returns(500, 500))
      trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(100))
      stubMissionAndAssignment()

      AirTaskingOrder.airStrike(config, saveData)

      assert.is_true(pkg.hasLaunched)
      assert.are.equal(0, #saveData.c.recon.queue)
    end)

    -- Negative: takeoffTime already calculated
    it("should not recalculate takeoffTime if already set", function()
      local reconUAV = {
        course = { { lat = 25.0, lon = 121.0 }, { lat = 24.0, lon = 120.0 } },
        speed = 400,
        takeoffTime = "2026-02-14 07:00:00",
        endTime = "2026-02-14 08:00:00"
      }
      local pkg = makePackage({ reconUAV = reconUAV })
      local saveData = makeSaveData({ packages = { pkg } })

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(2000))
      stubMissionAndAssignment()
      local stubCalcPath = trackStub(stub(GameUtils, "calculatePathDistanceAndTime"))

      AirTaskingOrder.airStrike(makeConfig(), saveData)

      assert.stub(stubCalcPath).was_not.called()
      assert.are.equal("2026-02-14 07:00:00", reconUAV.takeoffTime)
      -- An already-scheduled reconUAV is not re-inserted into the queue
      assert.are.equal(0, #saveData.c.recon.queue)
    end)
  end)

  -- ============================================================================
  -- Wave completion (isWaveFinished)
  -- ============================================================================

  describe("wave completion", function()
    -- Positive: all packages launched
    it("should mark wave as launched when all packages launched", function()
      local pkg1 = makePackage({ hasLaunched = true })
      local pkg2 = makePackage()
      local saveData = makeSaveData({ packages = { pkg1, pkg2 } })

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(2000))
      stubMissionAndAssignment()

      AirTaskingOrder.airStrike(makeConfig(), saveData)

      assert.is_true(pkg2.hasLaunched)
      local wave = saveData.c.air.airTaskingOrder["WAVE-1"]
      assert.is_true(wave.hasLaunched)
    end)

    -- Negative: remaining packages
    it("should not mark wave as launched when some packages remain", function()
      local pkg1 = makePackage()
      local pkg2 = makePackage()
      local saveData = makeSaveData({ packages = { pkg1, pkg2 } })

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(2000))
      stubMissionAndAssignment()

      AirTaskingOrder.airStrike(makeConfig(), saveData)

      -- Only one package launches per tick (break after success)
      assert.is_true(pkg1.hasLaunched)
      assert.is_false(pkg2.hasLaunched)
      local wave = saveData.c.air.airTaskingOrder["WAVE-1"]
      assert.is_false(wave.hasLaunched)
    end)

    -- Positive: one-per-tick throttling
    it("should process only one package per tick then break", function()
      local pkg1 = makePackage()
      local pkg2 = makePackage()
      local saveData = makeSaveData({ packages = { pkg1, pkg2 } })

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(2000))
      trackStub(stub(GameApi, "ScenEdit_GetMission").returns(nil))
      trackStub(stub(GameUtils, "createMission").returns({ name = "m" }))
      trackStub(stub(GameApi, "ScenEdit_SetDoctrine"))
      trackStub(stub(GameApi, "ScenEdit_AssignUnitAsTarget").returns(true))
      trackStub(
        stub(AssignMission, "assignEmbarkedUnitToStrikeMission").returns({ "U1" })
      )
      trackStub(stub(GameApi, "ScenEdit_CreateMissionFlightPlan"))

      AirTaskingOrder.airStrike(makeConfig(), saveData)

      assert.is_true(pkg1.hasLaunched)
      assert.is_false(pkg2.hasLaunched)
    end)

    -- Positive: fallthrough to next package
    it("should try next package if first one fails", function()
      -- pkg1: 0 targets, minTargetCount = 2 -> fails
      local pkg1 = makePackage({ targetList = {}, minTargetCount = 2 })
      -- pkg2: enough targets -> succeeds
      local pkg2 = makePackage({
        striker = makeRole({ missionName = "STRIKE-PKG-2" }),
        targetList = { "TGT-1", "TGT-2" },
        minTargetCount = 1
      })
      local saveData = makeSaveData({ packages = { pkg1, pkg2 } })

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(2000))
      stubMissionAndAssignment()

      AirTaskingOrder.airStrike(makeConfig(), saveData)

      -- pkg1 fails at target check, pkg2 succeeds
      assert.is_false(pkg1.hasLaunched)
      assert.is_true(pkg2.hasLaunched)
    end)
  end)

  -- ============================================================================
  -- Multiple waves
  -- ============================================================================

  describe("multiple waves", function()
    -- Positive: selective wave processing
    it("should process activated waves and skip non-activated ones", function()
      local pkg1 = makePackage()
      local pkg2 = makePackage()
      local saveData = makeSaveData({
        packages = { pkg1 },
        extraWaves = {
          ["WAVE-2"] = {
            isActivated = false,
            hasLaunched = false,
            packages = { pkg2 }
          }
        }
      })

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(2000))
      stubMissionAndAssignment()

      AirTaskingOrder.airStrike(makeConfig(), saveData)

      assert.is_true(pkg1.hasLaunched)
      assert.is_false(pkg2.hasLaunched)
    end)
  end)

  -- ============================================================================
  -- Consolidated Log Output
  -- ============================================================================

  describe("consolidated log output", function()
    -- Positive: info log for successful and skipped packages
    it("should output single info log mixing OK and SKIP outcomes without error log", function()
      local pkg1 = makePackage({ targetList = {}, minTargetCount = 2 })
      local pkg2 = makePackage({
        striker = makeRole({ missionName = "STRIKE-PKG-2" }),
        targetList = { "TGT-1", "TGT-2" },
        minTargetCount = 1
      })
      local saveData = makeSaveData({ packages = { pkg1, pkg2 } })

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(2000))
      stubMissionAndAssignment()

      AirTaskingOrder.airStrike(makeConfig(), saveData)

      assert.stub(logStub).was.called(1)
      assert.stub(errorStub).was_not.called()
      local logMessage = logStub.calls[1].vals[2]
      assert.truthy(logMessage:find("%[OK%]"))
      assert.truthy(logMessage:find("%[SKIP%]"))
      assert.truthy(logMessage:find("reason=invalid_package_targets"))
      assert.truthy(logMessage:find("wave=WAVE%-1"))
      assert.truthy(logMessage:find("total=2"))
    end)

    -- Negative: package execution failures are emitted through error log
    it("should output FAIL error log when target assignment API fails", function()
      local pkg = makePackage()
      local saveData = makeSaveData({ packages = { pkg } })

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(2000))
      trackStub(stub(GameApi, "ScenEdit_GetMission").returns(nil))
      trackStub(stub(GameUtils, "createMission").returns({ name = "m" }))
      trackStub(stub(GameApi, "ScenEdit_SetDoctrine"))
      trackStub(stub(GameApi, "ScenEdit_AssignUnitAsTarget").returns(nil))

      AirTaskingOrder.airStrike(makeConfig(), saveData)

      assert.stub(logStub).was_not.called()
      assert.stub(errorStub).was.called(1)
      local errorMessage = errorStub.calls[1].vals[1]
      assert.truthy(errorMessage:find("%[FAIL%]"))
      assert.truthy(errorMessage:find("reason=target_assignment_failed"))
      assert.truthy(errorMessage:find("total=1"))
    end)
  end)

  -- ============================================================================
  -- Full lifecycle (integration)
  -- ============================================================================

  describe("full lifecycle", function()
    -- Positive: complete sequence with escort
    it("should launch package with escort through complete sequence", function()
      local escort = makeRole({
        missionName = "ESCORT-1",
        missionType = "patrol",
        baseGUID = "BASE-2",
        unitDBID = 200,
        startTime = "2026-02-14 05:50:00",
        endTime = "2026-02-14 08:00:00"
      })
      local pkg = makePackage({
        escort = escort,
        targetList = { "TGT-1", "TGT-2", "TGT-3" },
        minTargetCount = 2
      })
      local saveData = makeSaveData({ packages = { pkg } })

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(2000))
      trackStub(stub(GameApi, "ScenEdit_GetMission").returns(nil))

      local createdMissions = {}
      trackStub(stub(GameUtils, "createMission").invokes(function(_, name)
        local m = { name = name }
        createdMissions[name] = m
        return m
      end))
      trackStub(stub(GameApi, "ScenEdit_SetDoctrine"))
      trackStub(stub(GameApi, "ScenEdit_AssignUnitAsTarget").returns(true))
      trackStub(stub(AssignMission, "assignEmbarkedUnitToStrikeMission").returns({ "U1", "U2" }))
      trackStub(stub(GameApi, "ScenEdit_CreateMissionFlightPlan"))

      AirTaskingOrder.airStrike(makeConfig(), saveData)

      assert.is_true(pkg.hasLaunched)
      assert.is_table(createdMissions["STRIKE-PKG-1"])
      assert.is_table(createdMissions["ESCORT-1"])

      local wave = saveData.c.air.airTaskingOrder["WAVE-1"]
      assert.is_true(wave.hasLaunched)
    end)

    -- Positive: all support roles
    it("should launch package with all four support roles", function()
      local escort = makeRole({
        missionName = "ESCORT-1",
        missionType = "patrol",
        startTime = "2026-02-14 05:50:00"
      })
      local wildWeasel = makeRole({
        missionName = "SEAD-1",
        missionType = "strike",
        startTime = "2026-02-14 05:45:00"
      })
      local jammer = makeRole({
        missionName = "JAMMER-1",
        missionType = "patrol",
        startTime = "2026-02-14 05:55:00"
      })
      local tanker = makeRole({
        missionName = "TANKER-1",
        missionType = "support",
        startTime = "2026-02-14 05:30:00"
      })
      local pkg = makePackage({
        escort = escort,
        wildWeasel = wildWeasel,
        jammer = jammer,
        tanker = tanker
      })
      local saveData = makeSaveData({ packages = { pkg } })

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(2000))
      trackStub(stub(GameApi, "ScenEdit_GetMission").returns(nil))

      local createdMissions = {}
      trackStub(stub(GameUtils, "createMission").invokes(function(_, name)
        local m = { name = name }
        createdMissions[name] = m
        return m
      end))
      trackStub(stub(GameApi, "ScenEdit_SetDoctrine"))
      trackStub(stub(GameApi, "ScenEdit_AssignUnitAsTarget").returns(true))
      trackStub(stub(AssignMission, "assignEmbarkedUnitToStrikeMission").returns({ "U1" }))
      trackStub(stub(GameApi, "ScenEdit_CreateMissionFlightPlan"))

      AirTaskingOrder.airStrike(makeConfig(), saveData)

      assert.is_true(pkg.hasLaunched)
      -- All 5 missions created
      assert.is_table(createdMissions["STRIKE-PKG-1"])
      assert.is_table(createdMissions["ESCORT-1"])
      assert.is_table(createdMissions["SEAD-1"])
      assert.is_table(createdMissions["JAMMER-1"])
      assert.is_table(createdMissions["TANKER-1"])
    end)
  end)
end)
