-- AirTaskingOrder Unit Tests
---@diagnostic disable: undefined-field
local AirTaskingOrder = require("src.modules.strikePlanner.airTaskingOrder")
local Utils = require("src.utils.utils")
local GameApi = require("src.utils.gameApi")
local GameUtils = require("src.utils.gameUtils")
local AssignMission = require("src.modules.assignMission")

describe("AirTaskingOrder", function()
  local activeStubs

  local function trackStub(s)
    table.insert(activeStubs, s)
    return s
  end

  before_each(function()
    activeStubs = {}
  end)

  after_each(function()
    for _, s in ipairs(activeStubs) do
      s:revert()
    end
    activeStubs = {}
  end)

  -- ============================================================================
  -- Shared builders
  -- ============================================================================

  ---Build a MissionDeploymentDescriptor with sensible defaults
  ---@param overrides? table
  ---@return table
  local function buildRole(overrides)
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
      loadoutId = overrides.loadoutId,
      startTime = overrides.startTime or "2026-02-14 06:00:00",
      endTime = overrides.endTime or "2026-02-14 08:00:00",
      timeOnStation = overrides.timeOnStation,
      emcon = overrides.emcon or "Radar=Passive"
    }
  end

  ---Build a package; defaults to loadout-already-done state for lifecycle tests
  ---@param overrides? table
  ---@return table
  local function buildPackage(overrides)
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
      striker = overrides.striker or buildRole({ missionName = "STRIKE-PKG-1" }),
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

  ---Build full saveData with one ATO wave
  ---@param overrides? table
  ---@return table
  local function buildSaveData(overrides)
    overrides = overrides or {}
    local packages = overrides.packages or { buildPackage(overrides.packageOverrides) }

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
  -- saveData guard (negative)
  -- ============================================================================

  -- ============================================================================
  -- Wave filtering (negative)
  -- ============================================================================

  describe("wave filtering", function()
    it("should skip non-activated waves", function()
      local saveData = buildSaveData({ isActivated = false })
      local stubIsAfter = trackStub(stub(GameUtils, "isAfterStartTime"))

      AirTaskingOrder.airStrike({}, saveData)

      assert.stub(stubIsAfter).was_not.called()
    end)

    it("should skip already-launched waves", function()
      local saveData = buildSaveData({ waveHasLaunched = true })
      local stubIsAfter = trackStub(stub(GameUtils, "isAfterStartTime"))

      AirTaskingOrder.airStrike({}, saveData)

      assert.stub(stubIsAfter).was_not.called()
    end)

    it("should skip already-launched packages within active wave", function()
      local pkg = buildPackage({ hasLaunched = true })
      local saveData = buildSaveData({ packages = { pkg } })
      local stubIsAfter = trackStub(stub(GameUtils, "isAfterStartTime"))

      AirTaskingOrder.airStrike({}, saveData)

      assert.stub(stubIsAfter).was_not.called()
    end)

    it("should handle empty airTaskingOrder without error", function()
      local saveData = { c = { air = { airTaskingOrder = {} } } }

      AirTaskingOrder.airStrike({}, saveData)
    end)
  end)

  -- ============================================================================
  -- Loadout timing (isTimeToStartLoadout)
  -- ============================================================================

  describe("loadout timing", function()
    it("should not proceed when loadout start time not reached", function()
      local pkg = buildPackage({
        loadoutStatus = { isLoadoutInitiated = false, loadoutStartTime = nil }
      })
      local saveData = buildSaveData({ packages = { pkg } })

      trackStub(stub(GameUtils, "isAfterStartTime").returns(false))
      trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(5000))
      local stubGetUnit = trackStub(stub(GameApi, "ScenEdit_GetUnit"))

      AirTaskingOrder.airStrike({}, saveData)

      assert.stub(stubGetUnit).was_not.called()
      assert.is_false(pkg.hasLaunched)
    end)

    it("should not proceed when loadoutStatus is nil", function()
      local pkg = buildPackage()
      pkg.loadoutStatus = nil
      local saveData = buildSaveData({ packages = { pkg } })

      AirTaskingOrder.airStrike({}, saveData)

      assert.is_false(pkg.hasLaunched)
    end)

    it("should calculate loadoutStartTime as earliest startTime minus timeToReady", function()
      local pkg = buildPackage({
        timeToReady = 600,
        loadoutStatus = { isLoadoutInitiated = false, loadoutStartTime = nil }
      })
      local saveData = buildSaveData({ packages = { pkg } })

      trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(5000))
      trackStub(stub(GameUtils, "isAfterStartTime").returns(false))

      AirTaskingOrder.airStrike({}, saveData)

      assert.are.equal(5000 - 600, pkg.loadoutStatus.loadoutStartTime)
    end)

    it("should default timeToReady to 9*60 when not specified", function()
      local pkg = buildPackage({
        loadoutStatus = { isLoadoutInitiated = false, loadoutStartTime = nil }
      })
      local saveData = buildSaveData({ packages = { pkg } })

      trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(5000))
      trackStub(stub(GameUtils, "isAfterStartTime").returns(false))

      AirTaskingOrder.airStrike({}, saveData)

      assert.are.equal(5000 - 540, pkg.loadoutStatus.loadoutStartTime)
    end)

    it("should pick earliest startTime across all roles", function()
      local escort = buildRole({
        missionName = "ESCORT-1",
        startTime = "2026-02-14 05:30:00"
      })
      local pkg = buildPackage({
        escort = escort,
        timeToReady = 600,
        loadoutStatus = { isLoadoutInitiated = false, loadoutStartTime = nil }
      })
      local saveData = buildSaveData({ packages = { pkg } })

      trackStub(stub(Utils, "parseDatetimeToTimestamp").invokes(function(dateStr)
        if dateStr == "2026-02-14 05:30:00" then return 4000 end
        return 5000
      end))
      trackStub(stub(GameUtils, "isAfterStartTime").returns(false))

      AirTaskingOrder.airStrike({}, saveData)

      -- Earliest = escort 4000, minus timeToReady 600 = 3400
      assert.are.equal(3400, pkg.loadoutStatus.loadoutStartTime)
    end)

    it("should return nil when no role has startTime", function()
      local striker = buildRole({ missionName = "STRIKE-PKG-1" })
      striker.startTime = nil
      local pkg = buildPackage({
        striker = striker,
        loadoutStatus = { isLoadoutInitiated = false, loadoutStartTime = nil }
      })
      local saveData = buildSaveData({ packages = { pkg } })

      trackStub(stub(GameUtils, "isAfterStartTime").returns(false))

      AirTaskingOrder.airStrike({}, saveData)

      assert.is_nil(pkg.loadoutStatus.loadoutStartTime)
    end)
  end)

  -- ============================================================================
  -- Loadout initiation (initiateLoadoutForPackage)
  -- ============================================================================

  describe("loadout initiation", function()
    it("should set loadout for matching aircraft and update status", function()
      local striker = buildRole({
        missionName = "STRIKE-PKG-1",
        loadoutId = 5001,
        unitDBID = 100,
        unitCount = 2
      })
      local pkg = buildPackage({
        striker = striker,
        timeToReady = 600,
        loadoutStatus = { isLoadoutInitiated = false }
      })
      local saveData = buildSaveData({ packages = { pkg } })

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(2000))
      trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(3000))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
        if guid == "BASE-1" then
          return {
            guid = "BASE-1", name = "Air Base",
            embarkedUnits = { Aircraft = { "AC-1", "AC-2", "AC-3" } }
          }
        end
        return { guid = guid, name = "AC-" .. guid, dbid = 100 }
      end))
      local stubSetLoadout = trackStub(stub(GameApi, "ScenEdit_SetLoadout").returns(true))

      AirTaskingOrder.airStrike({}, saveData)

      assert.stub(stubSetLoadout).was.called(2)
      assert.is_true(pkg.loadoutStatus.isLoadoutInitiated)
      assert.are.equal(3000, pkg.loadoutStatus.loadoutInitiatedTime)
      assert.are.equal(3600, pkg.loadoutStatus.expectedReadyTime)
      -- Package NOT launched yet (isLoadoutReady returns false on first initiation)
      assert.is_false(pkg.hasLaunched)
    end)

    it("should skip roles without loadoutId", function()
      local striker = buildRole({ missionName = "STRIKE-PKG-1" })
      -- loadoutId is nil by default
      local pkg = buildPackage({
        striker = striker,
        loadoutStatus = { isLoadoutInitiated = false }
      })
      local saveData = buildSaveData({ packages = { pkg } })

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(2000))
      trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(3000))
      local stubSetLoadout = trackStub(stub(GameApi, "ScenEdit_SetLoadout"))

      AirTaskingOrder.airStrike({}, saveData)

      assert.stub(stubSetLoadout).was_not.called()
    end)

    it("should skip roles without unitDBID", function()
      local striker = buildRole({ missionName = "STRIKE-PKG-1", loadoutId = 5001 })
      striker.unitDBID = nil
      local pkg = buildPackage({
        striker = striker,
        loadoutStatus = { isLoadoutInitiated = false }
      })
      local saveData = buildSaveData({ packages = { pkg } })

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(2000))
      trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(3000))
      local stubGetUnit = trackStub(stub(GameApi, "ScenEdit_GetUnit"))

      AirTaskingOrder.airStrike({}, saveData)

      -- goto continue skips the base lookup
      assert.stub(stubGetUnit).was_not.called()
    end)

    it("should only set loadout for aircraft matching target unitDBID", function()
      local striker = buildRole({
        missionName = "STRIKE-PKG-1",
        loadoutId = 5001,
        unitDBID = 100,
        unitCount = 2
      })
      local pkg = buildPackage({
        striker = striker,
        loadoutStatus = { isLoadoutInitiated = false }
      })
      local saveData = buildSaveData({ packages = { pkg } })

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(2000))
      trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(3000))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
        if guid == "BASE-1" then
          return {
            guid = "BASE-1", name = "Air Base",
            embarkedUnits = { Aircraft = { "AC-1", "AC-2", "AC-3" } }
          }
        end
        if guid == "AC-1" then return { guid = "AC-1", name = "J-16-1", dbid = 100 } end
        if guid == "AC-2" then return { guid = "AC-2", name = "KJ-500", dbid = 999 } end
        if guid == "AC-3" then return { guid = "AC-3", name = "J-16-2", dbid = 100 } end
        return nil
      end))
      local stubSetLoadout = trackStub(stub(GameApi, "ScenEdit_SetLoadout").returns(true))

      AirTaskingOrder.airStrike({}, saveData)

      assert.stub(stubSetLoadout).was.called(2)
      assert.are.equal("J-16-1", stubSetLoadout.calls[1].vals[1].unitname)
      assert.are.equal("J-16-2", stubSetLoadout.calls[2].vals[1].unitname)
    end)

    it("should not exceed unitCount when setting loadouts", function()
      local striker = buildRole({
        missionName = "STRIKE-PKG-1",
        loadoutId = 5001,
        unitDBID = 100,
        unitCount = 1
      })
      local pkg = buildPackage({
        striker = striker,
        loadoutStatus = { isLoadoutInitiated = false }
      })
      local saveData = buildSaveData({ packages = { pkg } })

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(2000))
      trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(3000))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
        if guid == "BASE-1" then
          return {
            guid = "BASE-1", name = "Air Base",
            embarkedUnits = { Aircraft = { "AC-1", "AC-2", "AC-3" } }
          }
        end
        return { guid = guid, name = "Aircraft", dbid = 100 }
      end))
      local stubSetLoadout = trackStub(stub(GameApi, "ScenEdit_SetLoadout").returns(true))

      AirTaskingOrder.airStrike({}, saveData)

      -- unitCount = 1, so only 1 loadout despite 3 matching aircraft
      assert.stub(stubSetLoadout).was.called(1)
    end)

    it("should set loadouts for multiple roles in same package", function()
      local striker = buildRole({
        missionName = "STRIKE-PKG-1",
        loadoutId = 5001,
        unitDBID = 100,
        unitCount = 1,
        baseGUID = "BASE-1"
      })
      local escort = buildRole({
        missionName = "ESCORT-1",
        missionType = "patrol",
        loadoutId = 6001,
        unitDBID = 200,
        unitCount = 1,
        baseGUID = "BASE-2"
      })
      local pkg = buildPackage({
        striker = striker,
        escort = escort,
        loadoutStatus = { isLoadoutInitiated = false }
      })
      local saveData = buildSaveData({ packages = { pkg } })

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

      AirTaskingOrder.airStrike({}, saveData)

      assert.stub(stubSetLoadout).was.called(2)
      assert.are.equal(5001, stubSetLoadout.calls[1].vals[1].LoadoutID)
      assert.are.equal(6001, stubSetLoadout.calls[2].vals[1].LoadoutID)
    end)

    it("should handle base not found gracefully", function()
      local striker = buildRole({
        missionName = "STRIKE-PKG-1",
        loadoutId = 5001,
        unitDBID = 100
      })
      local pkg = buildPackage({
        striker = striker,
        loadoutStatus = { isLoadoutInitiated = false }
      })
      local saveData = buildSaveData({ packages = { pkg } })

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(2000))
      trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(3000))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns(nil))
      local stubSetLoadout = trackStub(stub(GameApi, "ScenEdit_SetLoadout"))

      AirTaskingOrder.airStrike({}, saveData)

      assert.stub(stubSetLoadout).was_not.called()
      -- Still marks as initiated (function completes normally)
      assert.is_true(pkg.loadoutStatus.isLoadoutInitiated)
    end)

    it("should handle base with empty aircraft list", function()
      local striker = buildRole({
        missionName = "STRIKE-PKG-1",
        loadoutId = 5001,
        unitDBID = 100
      })
      local pkg = buildPackage({
        striker = striker,
        loadoutStatus = { isLoadoutInitiated = false }
      })
      local saveData = buildSaveData({ packages = { pkg } })

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(2000))
      trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(3000))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").returns({
        guid = "BASE-1", name = "Air Base",
        embarkedUnits = { Aircraft = {} }
      }))
      local stubSetLoadout = trackStub(stub(GameApi, "ScenEdit_SetLoadout"))

      AirTaskingOrder.airStrike({}, saveData)

      assert.stub(stubSetLoadout).was_not.called()
    end)

    it("should continue processing when SetLoadout fails for individual aircraft", function()
      local striker = buildRole({
        missionName = "STRIKE-PKG-1",
        loadoutId = 5001,
        unitDBID = 100,
        unitCount = 2
      })
      local pkg = buildPackage({
        striker = striker,
        loadoutStatus = { isLoadoutInitiated = false }
      })
      local saveData = buildSaveData({ packages = { pkg } })

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(2000))
      trackStub(stub(GameApi, "ScenEdit_CurrentTime").returns(3000))
      trackStub(stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
        if guid == "BASE-1" then
          return {
            guid = "BASE-1", name = "Air Base",
            embarkedUnits = { Aircraft = { "AC-1", "AC-2", "AC-3" } }
          }
        end
        return { guid = guid, name = "Aircraft-" .. guid, dbid = 100 }
      end))
      -- First call fails, second succeeds, third succeeds
      local setLoadoutCount = 0
      trackStub(stub(GameApi, "ScenEdit_SetLoadout").invokes(function()
        setLoadoutCount = setLoadoutCount + 1
        if setLoadoutCount == 1 then return nil end
        return true
      end))

      AirTaskingOrder.airStrike({}, saveData)

      -- All 3 aircraft attempted (first fails, second/third succeed → 2 processed = unitCount)
      assert.are.equal(3, setLoadoutCount)
      assert.is_true(pkg.loadoutStatus.isLoadoutInitiated)
    end)
  end)

  -- ============================================================================
  -- Loadout readiness (isLoadoutReady)
  -- ============================================================================

  describe("loadout readiness", function()
    it("should proceed when loadout initiated and ready time passed", function()
      local pkg = buildPackage({
        loadoutStatus = {
          isLoadoutInitiated = true,
          expectedReadyTime = 1500
        }
      })
      local saveData = buildSaveData({ packages = { pkg } })

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(2000))
      stubMissionAndAssignment()

      AirTaskingOrder.airStrike({}, saveData)

      assert.is_true(pkg.hasLaunched)
    end)

    it("should not proceed when loadout initiated but expectedReadyTime is nil", function()
      local pkg = buildPackage({
        loadoutStatus = {
          isLoadoutInitiated = true,
          expectedReadyTime = nil
        }
      })
      local saveData = buildSaveData({ packages = { pkg } })

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(2000))

      AirTaskingOrder.airStrike({}, saveData)

      assert.is_false(pkg.hasLaunched)
    end)
  end)

  -- ============================================================================
  -- Departure time check (findEarliestRole)
  -- ============================================================================

  describe("departure time check", function()
    it("should not launch when departure time not reached", function()
      local pkg = buildPackage({
        loadoutStatus = {
          isLoadoutInitiated = true,
          expectedReadyTime = 1500
        }
      })
      local saveData = buildSaveData({ packages = { pkg } })

      local callCount = 0
      trackStub(stub(GameUtils, "isAfterStartTime").invokes(function()
        callCount = callCount + 1
        -- 1st: loadout timing → true
        -- 2nd: loadout readiness → true
        -- 3rd: departure time → false
        return callCount < 3
      end))
      trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(2000))

      AirTaskingOrder.airStrike({}, saveData)

      assert.is_false(pkg.hasLaunched)
    end)

    it("should not launch when no role has startTime", function()
      local striker = buildRole({ missionName = "STRIKE-PKG-1" })
      striker.startTime = nil
      local pkg = buildPackage({
        striker = striker,
        loadoutStatus = {
          isLoadoutInitiated = true,
          expectedReadyTime = 1500
        }
      })
      local saveData = buildSaveData({ packages = { pkg } })

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(2000))

      AirTaskingOrder.airStrike({}, saveData)

      -- findEarliestRole returns nil → processPackage returns false
      assert.is_false(pkg.hasLaunched)
    end)

    it("should use earliest startTime among all roles for departure check", function()
      local escort = buildRole({
        missionName = "ESCORT-1",
        startTime = "2026-02-14 05:30:00"
      })
      local pkg = buildPackage({
        escort = escort,
        loadoutStatus = {
          isLoadoutInitiated = true,
          expectedReadyTime = 1500
        }
      })
      local saveData = buildSaveData({ packages = { pkg } })

      trackStub(stub(Utils, "parseDatetimeToTimestamp").invokes(function(dateStr)
        if dateStr == "2026-02-14 05:30:00" then return 4000 end
        return 5000
      end))

      local isAfterArgs = {}
      trackStub(stub(GameUtils, "isAfterStartTime").invokes(function(timeStr, advanceSec)
        table.insert(isAfterArgs, { timeStr = timeStr, advanceSec = advanceSec })
        return true
      end))
      stubMissionAndAssignment()

      AirTaskingOrder.airStrike({}, saveData)

      -- 3rd call = departure check, should use escort's startTime (earlier)
      assert.are.equal("2026-02-14 05:30:00", isAfterArgs[3].timeStr)
      assert.are.equal(300, isAfterArgs[3].advanceSec)
    end)
  end)

  -- ============================================================================
  -- Mission creation (createMission)
  -- ============================================================================

  describe("mission creation", function()
    it("should create mission when it does not exist", function()
      local pkg = buildPackage()
      local saveData = buildSaveData({ packages = { pkg } })

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(2000))
      trackStub(stub(GameApi, "ScenEdit_GetMission").returns(nil))
      local stubCreate = trackStub(stub(GameUtils, "createMission").returns({ name = "m" }))
      trackStub(stub(GameApi, "ScenEdit_SetDoctrine"))
      trackStub(stub(GameApi, "ScenEdit_AssignUnitAsTarget").returns(true))
      trackStub(stub(AssignMission, "assignEmbarkedUnitToStrikeMission").returns({ "U1" }))
      trackStub(stub(GameApi, "ScenEdit_CreateMissionFlightPlan"))

      AirTaskingOrder.airStrike({}, saveData)

      assert.stub(stubCreate).was.called(1)
      assert.are.equal("China", stubCreate.calls[1].vals[1])
      assert.are.equal("STRIKE-PKG-1", stubCreate.calls[1].vals[2])
    end)

    it("should not create mission when it already exists", function()
      local pkg = buildPackage()
      local saveData = buildSaveData({ packages = { pkg } })

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(2000))
      trackStub(stub(GameApi, "ScenEdit_GetMission").returns({ name = "STRIKE-PKG-1" }))
      local stubCreate = trackStub(stub(GameUtils, "createMission"))
      trackStub(stub(GameApi, "ScenEdit_AssignUnitAsTarget").returns(true))
      trackStub(stub(AssignMission, "assignEmbarkedUnitToStrikeMission").returns({ "U1" }))
      trackStub(stub(GameApi, "ScenEdit_CreateMissionFlightPlan"))

      AirTaskingOrder.airStrike({}, saveData)

      assert.stub(stubCreate).was_not.called()
    end)

    it("should set mission properties on newly created strike mission", function()
      local striker = buildRole({
        missionName = "STRIKE-PKG-1",
        startTime = "2026-02-14 06:00:00",
        endTime = "2026-02-14 08:00:00",
        timeOnStation = "00:30"
      })
      local pkg = buildPackage({ striker = striker })
      local saveData = buildSaveData({ packages = { pkg } })

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(2000))
      trackStub(stub(GameApi, "ScenEdit_GetMission").returns(nil))
      local missionObj = { name = "STRIKE-PKG-1" }
      trackStub(stub(GameUtils, "createMission").returns(missionObj))
      local stubDoctrine = trackStub(stub(GameApi, "ScenEdit_SetDoctrine"))
      trackStub(stub(GameApi, "ScenEdit_AssignUnitAsTarget").returns(true))
      trackStub(stub(AssignMission, "assignEmbarkedUnitToStrikeMission").returns({ "U1" }))
      trackStub(stub(GameApi, "ScenEdit_CreateMissionFlightPlan"))

      AirTaskingOrder.airStrike({}, saveData)

      assert.is_true(missionObj.OnDeactivateDelete)
      assert.is_true(missionObj.OnDeactivateRTB)
      assert.are.equal("2026-02-14 06:00:00", missionObj.TakeOffTime)
      assert.are.equal("2026-02-14 08:00:00", missionObj.endtime)
      assert.are.equal("00:30", missionObj.TimeOnTargetStation)
      assert.stub(stubDoctrine).was.called(1)
    end)

    it("should abort package when striker mission creation fails", function()
      local pkg = buildPackage()
      local saveData = buildSaveData({ packages = { pkg } })

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(2000))
      trackStub(stub(GameApi, "ScenEdit_GetMission").returns(nil))
      trackStub(stub(GameUtils, "createMission").returns(nil))
      local stubAssignTarget = trackStub(stub(GameApi, "ScenEdit_AssignUnitAsTarget"))

      AirTaskingOrder.airStrike({}, saveData)

      assert.is_false(pkg.hasLaunched)
      assert.stub(stubAssignTarget).was_not.called()
    end)

    it("should continue when non-striker mission creation fails", function()
      local escort = buildRole({
        missionName = "ESCORT-1",
        missionType = "patrol",
        startTime = "2026-02-14 05:50:00"
      })
      local pkg = buildPackage({ escort = escort })
      local saveData = buildSaveData({ packages = { pkg } })

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(2000))
      -- Striker found but escort not found and creation fails
      trackStub(stub(GameApi, "ScenEdit_GetMission").returns(nil))
      local createCount = 0
      trackStub(stub(GameUtils, "createMission").invokes(function(_, name)
        createCount = createCount + 1
        -- Striker succeeds (created first as "tanker" is checked first, then "striker")
        if name == "STRIKE-PKG-1" then return { name = name } end
        -- Escort fails
        return nil
      end))
      trackStub(stub(GameApi, "ScenEdit_SetDoctrine"))
      trackStub(stub(GameApi, "ScenEdit_AssignUnitAsTarget").returns(true))
      trackStub(stub(AssignMission, "assignEmbarkedUnitToStrikeMission").returns({ "U1" }))
      trackStub(stub(GameApi, "ScenEdit_CreateMissionFlightPlan"))

      AirTaskingOrder.airStrike({}, saveData)

      -- Package still launches because only striker failure is critical
      assert.is_true(pkg.hasLaunched)
    end)

    it("should not set doctrine for non-strike mission types", function()
      local escort = buildRole({
        missionName = "ESCORT-1",
        missionType = "patrol",
        startTime = "2026-02-14 05:50:00"
      })
      local pkg = buildPackage({ escort = escort })
      local saveData = buildSaveData({ packages = { pkg } })

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(2000))
      trackStub(stub(GameApi, "ScenEdit_GetMission").returns(nil))
      trackStub(stub(GameUtils, "createMission").returns({ name = "m" }))
      local stubDoctrine = trackStub(stub(GameApi, "ScenEdit_SetDoctrine"))
      trackStub(stub(GameApi, "ScenEdit_AssignUnitAsTarget").returns(true))
      trackStub(stub(AssignMission, "assignEmbarkedUnitToStrikeMission").returns({ "U1" }))
      trackStub(stub(GameApi, "ScenEdit_CreateMissionFlightPlan"))

      AirTaskingOrder.airStrike({}, saveData)

      -- Only 1 doctrine call for striker (type "strike"), not for escort (type "patrol")
      assert.stub(stubDoctrine).was.called(1)
    end)
  end)

  -- ============================================================================
  -- Target assignment
  -- ============================================================================

  describe("target assignment", function()
    it("should not launch when target count below minTargetCount", function()
      local pkg = buildPackage({ targetList = {}, minTargetCount = 3 })
      local saveData = buildSaveData({ packages = { pkg } })

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(2000))
      trackStub(stub(GameApi, "ScenEdit_GetMission").returns(nil))
      trackStub(stub(GameUtils, "createMission").returns({ name = "m" }))
      trackStub(stub(GameApi, "ScenEdit_SetDoctrine"))
      local stubAssignTarget = trackStub(stub(GameApi, "ScenEdit_AssignUnitAsTarget"))

      AirTaskingOrder.airStrike({}, saveData)

      assert.is_false(pkg.hasLaunched)
      assert.stub(stubAssignTarget).was_not.called()
    end)

    it("should proceed when target count equals minTargetCount", function()
      local pkg = buildPackage({
        targetList = { "TGT-1", "TGT-2", "TGT-3" },
        minTargetCount = 3
      })
      local saveData = buildSaveData({ packages = { pkg } })

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(2000))
      stubMissionAndAssignment()

      AirTaskingOrder.airStrike({}, saveData)

      assert.is_true(pkg.hasLaunched)
    end)

    it("should pass target list to ScenEdit_AssignUnitAsTarget", function()
      local targets = { "TGT-A", "TGT-B" }
      local pkg = buildPackage({ targetList = targets })
      local saveData = buildSaveData({ packages = { pkg } })

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(2000))
      trackStub(stub(GameApi, "ScenEdit_GetMission").returns(nil))
      trackStub(stub(GameUtils, "createMission").returns({ name = "m" }))
      trackStub(stub(GameApi, "ScenEdit_SetDoctrine"))
      local stubAssignTarget = trackStub(stub(GameApi, "ScenEdit_AssignUnitAsTarget").returns(true))
      trackStub(stub(AssignMission, "assignEmbarkedUnitToStrikeMission").returns({ "U1" }))
      trackStub(stub(GameApi, "ScenEdit_CreateMissionFlightPlan"))

      AirTaskingOrder.airStrike({}, saveData)

      assert.are.same(targets, stubAssignTarget.calls[1].vals[1])
      assert.are.equal("STRIKE-PKG-1", stubAssignTarget.calls[1].vals[2])
    end)

    it("should not launch when ScenEdit_AssignUnitAsTarget returns nil", function()
      local pkg = buildPackage()
      local saveData = buildSaveData({ packages = { pkg } })

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(2000))
      trackStub(stub(GameApi, "ScenEdit_GetMission").returns(nil))
      trackStub(stub(GameUtils, "createMission").returns({ name = "m" }))
      trackStub(stub(GameApi, "ScenEdit_SetDoctrine"))
      trackStub(stub(GameApi, "ScenEdit_AssignUnitAsTarget").returns(nil))
      local stubAssignUnits = trackStub(stub(AssignMission, "assignEmbarkedUnitToStrikeMission"))

      AirTaskingOrder.airStrike({}, saveData)

      assert.is_false(pkg.hasLaunched)
      assert.stub(stubAssignUnits).was_not.called()
    end)
  end)

  -- ============================================================================
  -- Unit assignment (assignUnits)
  -- ============================================================================

  describe("unit assignment", function()
    it("should launch when striker units assigned successfully", function()
      local pkg = buildPackage()
      local saveData = buildSaveData({ packages = { pkg } })

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(2000))
      stubMissionAndAssignment()

      AirTaskingOrder.airStrike({}, saveData)

      assert.is_true(pkg.hasLaunched)
    end)

    it("should not launch when striker assignment returns empty result", function()
      local pkg = buildPackage()
      local saveData = buildSaveData({ packages = { pkg } })

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(2000))
      trackStub(stub(GameApi, "ScenEdit_GetMission").returns(nil))
      trackStub(stub(GameUtils, "createMission").returns({ name = "m" }))
      trackStub(stub(GameApi, "ScenEdit_SetDoctrine"))
      trackStub(stub(GameApi, "ScenEdit_AssignUnitAsTarget").returns(true))
      trackStub(stub(AssignMission, "assignEmbarkedUnitToStrikeMission").returns({}))
      trackStub(stub(GameApi, "ScenEdit_CreateMissionFlightPlan"))

      AirTaskingOrder.airStrike({}, saveData)

      assert.is_false(pkg.hasLaunched)
    end)

    it("should not launch when striker assignment returns nil", function()
      local pkg = buildPackage()
      local saveData = buildSaveData({ packages = { pkg } })

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(2000))
      trackStub(stub(GameApi, "ScenEdit_GetMission").returns(nil))
      trackStub(stub(GameUtils, "createMission").returns({ name = "m" }))
      trackStub(stub(GameApi, "ScenEdit_SetDoctrine"))
      trackStub(stub(GameApi, "ScenEdit_AssignUnitAsTarget").returns(true))
      trackStub(stub(AssignMission, "assignEmbarkedUnitToStrikeMission").returns(nil))
      trackStub(stub(GameApi, "ScenEdit_CreateMissionFlightPlan"))

      AirTaskingOrder.airStrike({}, saveData)

      assert.is_false(pkg.hasLaunched)
    end)

    it("should call CreateMissionFlightPlan for support roles only", function()
      local escort = buildRole({
        missionName = "ESCORT-1",
        missionType = "patrol",
        startTime = "2026-02-14 05:50:00"
      })
      local tanker = buildRole({
        missionName = "TANKER-1",
        missionType = "support",
        startTime = "2026-02-14 05:40:00"
      })
      local pkg = buildPackage({ escort = escort, tanker = tanker })
      local saveData = buildSaveData({ packages = { pkg } })

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(2000))
      trackStub(stub(GameApi, "ScenEdit_GetMission").returns(nil))
      trackStub(stub(GameUtils, "createMission").returns({ name = "m" }))
      trackStub(stub(GameApi, "ScenEdit_SetDoctrine"))
      trackStub(stub(GameApi, "ScenEdit_AssignUnitAsTarget").returns(true))
      trackStub(stub(AssignMission, "assignEmbarkedUnitToStrikeMission").returns({ "U1" }))

      local flightPlanCalls = {}
      trackStub(stub(GameApi, "ScenEdit_CreateMissionFlightPlan").invokes(function(side, name, plan)
        table.insert(flightPlanCalls, name)
      end))

      AirTaskingOrder.airStrike({}, saveData)

      -- FlightPlan called for escort (non-tanker, non-striker) but NOT for tanker or striker
      assert.are.equal(1, #flightPlanCalls)
      assert.are.equal("ESCORT-1", flightPlanCalls[1])
    end)
  end)

  -- ============================================================================
  -- Recon UAV handling
  -- ============================================================================

  describe("recon UAV handling", function()
    it("should add reconUAV to recon queue and calculate takeoff time", function()
      local reconUAV = {
        course = { { lat = 25.0, lon = 121.0 }, { lat = 24.0, lon = 120.0 } },
        speed = 400,
        takeoffTime = nil
      }
      local pkg = buildPackage({ reconUAV = reconUAV })
      local saveData = buildSaveData({ packages = { pkg } })
      local config = { c = { ground = { srbm = { reloadTime = 1800 } } } }

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(2000))
      stubMissionAndAssignment()
      trackStub(stub(GameUtils, "calculatePathDistanceAndTime").returns(500, 3600))
      trackStub(stub(Utils, "deepCopy").invokes(function(t)
        local copy = {}
        for k, v in pairs(t) do copy[k] = v end
        return copy
      end))

      AirTaskingOrder.airStrike(config, saveData)

      assert.is_true(pkg.hasLaunched)
      assert.are.equal(1, #saveData.c.recon.queue)

      local entry = saveData.c.recon.queue[1]
      assert.is_false(entry.hasLaunched)
      assert.is_false(entry.isFinished)
      assert.is_nil(entry.trackingTargetGUID)
      -- takeoffTime should have been calculated
      assert.is_string(reconUAV.takeoffTime)
      assert.is_string(reconUAV.endTime)
    end)

    it("should not recalculate takeoffTime if already set", function()
      local reconUAV = {
        course = { { lat = 25.0, lon = 121.0 }, { lat = 24.0, lon = 120.0 } },
        speed = 400,
        takeoffTime = "2026-02-14 07:00:00",
        endTime = "2026-02-14 08:00:00"
      }
      local pkg = buildPackage({ reconUAV = reconUAV })
      local saveData = buildSaveData({ packages = { pkg } })

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(2000))
      stubMissionAndAssignment()
      local stubCalcPath = trackStub(stub(GameUtils, "calculatePathDistanceAndTime"))
      trackStub(stub(Utils, "deepCopy").invokes(function(t)
        local copy = {}
        for k, v in pairs(t) do copy[k] = v end
        return copy
      end))

      AirTaskingOrder.airStrike({}, saveData)

      assert.stub(stubCalcPath).was_not.called()
      assert.are.equal("2026-02-14 07:00:00", reconUAV.takeoffTime)
    end)
  end)

  -- ============================================================================
  -- Wave completion (isWaveFinished)
  -- ============================================================================

  describe("wave completion", function()
    it("should mark wave as launched when all packages launched", function()
      local pkg1 = buildPackage({ hasLaunched = true })
      local pkg2 = buildPackage()
      local saveData = buildSaveData({ packages = { pkg1, pkg2 } })

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(2000))
      stubMissionAndAssignment()

      AirTaskingOrder.airStrike({}, saveData)

      assert.is_true(pkg2.hasLaunched)
      local wave = saveData.c.air.airTaskingOrder["WAVE-1"]
      assert.is_true(wave.hasLaunched)
    end)

    it("should not mark wave as launched when some packages remain", function()
      local pkg1 = buildPackage()
      local pkg2 = buildPackage()
      local saveData = buildSaveData({ packages = { pkg1, pkg2 } })

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(2000))
      stubMissionAndAssignment()

      AirTaskingOrder.airStrike({}, saveData)

      -- Only one package launches per tick (break after success)
      assert.is_true(pkg1.hasLaunched)
      assert.is_false(pkg2.hasLaunched)
      local wave = saveData.c.air.airTaskingOrder["WAVE-1"]
      assert.is_false(wave.hasLaunched)
    end)

    it("should process only one package per tick then break", function()
      local pkg1 = buildPackage()
      local pkg2 = buildPackage()
      local saveData = buildSaveData({ packages = { pkg1, pkg2 } })

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(2000))
      trackStub(stub(GameApi, "ScenEdit_GetMission").returns(nil))
      trackStub(stub(GameUtils, "createMission").returns({ name = "m" }))
      trackStub(stub(GameApi, "ScenEdit_SetDoctrine"))
      trackStub(stub(GameApi, "ScenEdit_AssignUnitAsTarget").returns(true))
      local stubAssign = trackStub(
        stub(AssignMission, "assignEmbarkedUnitToStrikeMission").returns({ "U1" })
      )
      trackStub(stub(GameApi, "ScenEdit_CreateMissionFlightPlan"))

      AirTaskingOrder.airStrike({}, saveData)

      assert.is_true(pkg1.hasLaunched)
      assert.is_false(pkg2.hasLaunched)
    end)

    it("should try next package if first one fails", function()
      -- pkg1: 0 targets, minTargetCount = 2 → fails
      local pkg1 = buildPackage({ targetList = {}, minTargetCount = 2 })
      -- pkg2: enough targets → succeeds
      local pkg2 = buildPackage({
        striker = buildRole({ missionName = "STRIKE-PKG-2" }),
        targetList = { "TGT-1", "TGT-2" },
        minTargetCount = 1
      })
      local saveData = buildSaveData({ packages = { pkg1, pkg2 } })

      trackStub(stub(GameUtils, "isAfterStartTime").returns(true))
      trackStub(stub(Utils, "parseDatetimeToTimestamp").returns(2000))
      stubMissionAndAssignment()

      AirTaskingOrder.airStrike({}, saveData)

      -- pkg1 fails at target check, pkg2 succeeds
      assert.is_false(pkg1.hasLaunched)
      assert.is_true(pkg2.hasLaunched)
    end)
  end)

  -- ============================================================================
  -- Multiple waves
  -- ============================================================================

  describe("multiple waves", function()
    it("should process activated waves and skip non-activated ones", function()
      local pkg1 = buildPackage()
      local pkg2 = buildPackage()
      local saveData = buildSaveData({
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

      AirTaskingOrder.airStrike({}, saveData)

      assert.is_true(pkg1.hasLaunched)
      assert.is_false(pkg2.hasLaunched)
    end)
  end)

  -- ============================================================================
  -- Full lifecycle (integration)
  -- ============================================================================

  describe("full lifecycle", function()
    it("should launch package with escort through complete sequence", function()
      local escort = buildRole({
        missionName = "ESCORT-1",
        missionType = "patrol",
        baseGUID = "BASE-2",
        unitDBID = 200,
        startTime = "2026-02-14 05:50:00",
        endTime = "2026-02-14 08:00:00"
      })
      local pkg = buildPackage({
        escort = escort,
        targetList = { "TGT-1", "TGT-2", "TGT-3" },
        minTargetCount = 2
      })
      local saveData = buildSaveData({ packages = { pkg } })

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

      AirTaskingOrder.airStrike({}, saveData)

      assert.is_true(pkg.hasLaunched)
      assert.is_table(createdMissions["STRIKE-PKG-1"])
      assert.is_table(createdMissions["ESCORT-1"])

      local wave = saveData.c.air.airTaskingOrder["WAVE-1"]
      assert.is_true(wave.hasLaunched)
    end)

    it("should launch package with all four support roles", function()
      local escort = buildRole({
        missionName = "ESCORT-1", missionType = "patrol",
        startTime = "2026-02-14 05:50:00"
      })
      local wildWeasel = buildRole({
        missionName = "SEAD-1", missionType = "strike",
        startTime = "2026-02-14 05:45:00"
      })
      local jammer = buildRole({
        missionName = "JAMMER-1", missionType = "patrol",
        startTime = "2026-02-14 05:55:00"
      })
      local tanker = buildRole({
        missionName = "TANKER-1", missionType = "support",
        startTime = "2026-02-14 05:30:00"
      })
      local pkg = buildPackage({
        escort = escort,
        wildWeasel = wildWeasel,
        jammer = jammer,
        tanker = tanker
      })
      local saveData = buildSaveData({ packages = { pkg } })

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

      AirTaskingOrder.airStrike({}, saveData)

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
