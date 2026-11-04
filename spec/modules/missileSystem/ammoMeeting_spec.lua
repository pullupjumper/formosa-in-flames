---@diagnostic disable: need-check-nil, assign-type-mismatch, cast-local-type, param-type-mismatch, inject-field
-- MissileSystem Ammo And Meeting Unit Tests
local stub = require("luassert.stub")
local Ammo = require("src.modules.missileSystem.ammo")
local Meeting = require("src.modules.missileSystem.meeting")
local GameApi = require("src.utils.gameApi")
local GameUtils = require("src.utils.gameUtils")
local Logger = require("src.utils.logger")
local constants = require("src.core.constants")

describe("MissileSystem Ammo And Meeting", function()
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

  local function makeSystemState(overrides)
    local ctx = {
      name = "srbm",
      reloadTime = 60,
      firingUnits = {
        ["Firing Unit Alpha"] = {
          name = "Firing Unit Alpha",
          state = constants.MISSILE_SYSTEM_STATE.RELOAD,
          resupplyUnit = "Ammo Sec, Alpha",
          operationalArea = {
            name = "OPAREA-1",
            RL = { { area = { "RP-001", "RP-002", "RP-003", "RP-004" } } }
          },
          weaponDBID = 1234,
          ammoThreshold = 60,
        }
      },
      resupplyUnits = {
        ["Ammo Sec, Alpha"] = {
          name = "Ammo Sec, Alpha",
          state = constants.MISSILE_SYSTEM_STATE.REPOSITIONING,
          weaponCountCurrent = 10,
          weaponCountDefault = 20,
          firingUnit = "Firing Unit Alpha",
          operationalArea = {
            name = "OPAREA-1",
            RL = { { area = { "RP-001", "RP-002", "RP-003", "RP-004" } } }
          }
        }
      },
      ammunitions = {}
    }

    if overrides then
      for k, v in pairs(overrides) do
        ctx[k] = v
      end
    end

    return ctx
  end

  before_each(function()
    activeStubs = {}
    table.insert(activeStubs, stub(Logger, "log"))
    table.insert(activeStubs, stub(Logger, "error"))
  end)

  after_each(function()
    for i = #activeStubs, 1, -1 do
      activeStubs[i]:revert()
    end
    activeStubs = {}
  end)

  -- ============================================================================
  -- isLowAmmo
  -- ============================================================================

  describe("isLowAmmo", function()
    -- Boundary: returns false when percentage is nil
    it("should return false when percentage is nil", function()
      local unit = { guid = "UNIT-001" }
      assert.is_false(Ammo.isLowAmmo(unit, nil, 1234))
    end)

    -- Boundary: returns false when weaponDBID is nil
    it("should return false when weaponDBID is nil", function()
      local unit = { guid = "UNIT-001" }
      assert.is_false(Ammo.isLowAmmo(unit, 50, nil))
    end)

    -- Boundary: returns false when total max ammo is zero
    it("should return false when total max ammo is zero", function()
      local unit = { guid = "UNIT-001" }
      trackStub(GameApi, "ScenEdit_GetUnit").returns(unit)
      trackStub(GameUtils, "getWeaponInfo").returns({ availableWeapons = 0, maxWeapons = 0 })

      assert.is_false(Ammo.isLowAmmo(unit, 50, 1234))
    end)

    -- Positive: returns true when ammo percentage equals threshold
    it("should return true when ammo percentage is equal to threshold", function()
      local unit = { guid = "UNIT-001" }
      trackStub(GameApi, "ScenEdit_GetUnit").returns(unit)
      trackStub(GameUtils, "getWeaponInfo").returns({ availableWeapons = 5, maxWeapons = 10 })

      assert.is_true(Ammo.isLowAmmo(unit, 50, 1234))
    end)

    -- Negative: returns false when ammo percentage is above threshold
    it("should return false when ammo percentage is above threshold", function()
      local unit = { guid = "UNIT-001" }
      trackStub(GameApi, "ScenEdit_GetUnit").returns(unit)
      trackStub(GameUtils, "getWeaponInfo").returns({ availableWeapons = 6, maxWeapons = 10 })

      assert.is_false(Ammo.isLowAmmo(unit, 50, 1234))
    end)

    -- Positive: aggregates ammo across group units
    it("should sum ammo across group units", function()
      local unit = { guid = "GROUP-001", group = { unitlist = { "U1", "U2" } } }
      trackStub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
        if guid == "U1" then return { guid = "U1" } end
        if guid == "U2" then return { guid = "U2" } end
        return nil
      end)
      trackStub(GameUtils, "getWeaponInfo").invokes(function(u)
        if u.guid == "U1" then return { availableWeapons = 2, maxWeapons = 10 } end
        if u.guid == "U2" then return { availableWeapons = 1, maxWeapons = 10 } end
        return { availableWeapons = 0, maxWeapons = 0 }
      end)

      assert.is_true(Ammo.isLowAmmo(unit, 15, 1234))
    end)

    -- Boundary: ignores missing units in group list
    it("should ignore missing units in group list", function()
      local unit = { guid = "GROUP-001", group = { unitlist = { "U1", "U2" } } }
      trackStub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
        if guid == "U1" then return { guid = "U1" } end
        return nil
      end)
      trackStub(GameUtils, "getWeaponInfo").returns({ availableWeapons = 5, maxWeapons = 10 })

      assert.is_true(Ammo.isLowAmmo(unit, 50, 1234))
    end)

    -- Positive: forwards weapon DBID to GameUtils.getWeaponInfo
    it("should pass weaponDBID to GameUtils.getWeaponInfo", function()
      local unit = { guid = "UNIT-001" }
      trackStub(GameApi, "ScenEdit_GetUnit").returns(unit)
      local stubGetWeaponInfo = trackStub(GameUtils, "getWeaponInfo").returns({ availableWeapons = 1, maxWeapons = 10 })

      Ammo.isLowAmmo(unit, 90, 4321)

      assert.stub(stubGetWeaponInfo).was.called()
      assert.are.equal(4321, stubGetWeaponInfo.calls[1].vals[2])
    end)

    -- Positive: aggregates ammo across multiple weapon DBIDs
    it("should aggregate ammo across multiple weapon DBIDs", function()
      local unit = { guid = "UNIT-001" }
      trackStub(GameApi, "ScenEdit_GetUnit").returns(unit)
      trackStub(GameUtils, "getWeaponInfo").invokes(function(_, dbid)
        if dbid == 1111 then return { availableWeapons = 3, maxWeapons = 10 } end
        if dbid == 2222 then return { availableWeapons = 2, maxWeapons = 10 } end
        return { availableWeapons = 0, maxWeapons = 0 }
      end)

      assert.is_true(Ammo.isLowAmmo(unit, 25, { 1111, 2222 }))
    end)

    -- Negative: returns false when multi-weapon total is above threshold
    it("should return false when multi-weapon total is above threshold", function()
      local unit = { guid = "UNIT-001" }
      trackStub(GameApi, "ScenEdit_GetUnit").returns(unit)
      trackStub(GameUtils, "getWeaponInfo").invokes(function(_, dbid)
        if dbid == 1111 then return { availableWeapons = 8, maxWeapons = 10 } end
        if dbid == 2222 then return { availableWeapons = 9, maxWeapons = 10 } end
        return { availableWeapons = 0, maxWeapons = 0 }
      end)

      assert.is_false(Ammo.isLowAmmo(unit, 50, { 1111, 2222 }))
    end)
  end)

  -- ============================================================================
  -- buildReload / reloadFiringUnit
  -- ============================================================================

  describe("buildReload", function()
    ---Stub a two-member group whose members each miss `missing` missiles of every weapon
    ---@param missing integer
    ---@return table firingUnit
    local function stubGroup(missing)
      local members = {
        F1 = { guid = "F1", side = "Taiwan" },
        F2 = { guid = "F2", side = "Taiwan" },
      }
      trackStub(GameApi, "ScenEdit_GetUnit").invokes(function(guid) return members[guid] end)
      trackStub(GameUtils, "getWeaponInfo").returns({ availableWeapons = 10 - missing, maxWeapons = 10 })
      return { guid = "F1", side = "Taiwan", group = { unitlist = { "F1", "F2" } } }
    end

    -- Positive: fills every member and weapon when the stock covers them
    it("should fill every member and weapon when the stock covers them", function()
      local plan = Ammo.buildReload(stubGroup(3), { 1111, 2222 }, 20)

      assert.are.equal(12, plan.count)
      assert.are.same({ guid = "F1", side = "Taiwan", weaponDBID = 1111, number = 3 }, plan.entries[1])
      assert.are.same({ guid = "F2", side = "Taiwan", weaponDBID = 2222, number = 3 }, plan.entries[4])
    end)

    -- Boundary: stops filling when the stock runs out, partway through a member
    it("should stop filling when the stock runs out", function()
      local plan = Ammo.buildReload(stubGroup(3), 1111, 4)

      assert.are.equal(4, plan.count)
      assert.are.same({ guid = "F1", side = "Taiwan", weaponDBID = 1111, number = 3 }, plan.entries[1])
      assert.are.same({ guid = "F2", side = "Taiwan", weaponDBID = 1111, number = 1 }, plan.entries[2])
      assert.are.equal(2, #plan.entries)
    end)

    -- Boundary: a full group needs nothing
    it("should build an empty plan for a full group", function()
      local plan = Ammo.buildReload(stubGroup(0), 1111, 10)

      assert.are.equal(0, plan.count)
      assert.are.same({}, plan.entries)
    end)

    -- Positive: loading the plan writes each entry and takes its count from the stock
    it("should load every entry and take the count from the resupply unit", function()
      local plan = Ammo.buildReload(stubGroup(3), 1111, 10)
      local addReloads = trackStub(GameApi, "ScenEdit_AddReloadsToUnit")
      local resupplyUnitState = { weaponCountCurrent = 10 }

      local loaded = Ammo.reloadFiringUnit(resupplyUnitState, plan)

      assert.are.equal(6, loaded)
      assert.are.equal(4, resupplyUnitState.weaponCountCurrent)
      assert.stub(addReloads).was.called(2)
      assert.stub(addReloads).was.called_with({ guid = "F2", side = "Taiwan", wpn_dbid = 1111, number = 3 })
    end)
  end)

  -- ============================================================================
  -- getInventory
  -- ============================================================================

  describe("getInventory", function()
    -- Boundary: empty system returns zero subtotals and zero percentages
    it("should return zeros when system has no firing/resupply/ammo entries", function()
      local systemState = {
        firingUnits = {},
        resupplyUnits = {},
        ammunitions = {},
      }

      local report = Ammo.getInventory(systemState, "Taiwan")

      assert.are.same({ current = 0, max = 0, percentage = 0 }, report.firing)
      assert.are.same({ current = 0, max = 0, percentage = 0 }, report.resupply)
      assert.are.same({ current = 0, max = 0, percentage = 0 }, report.ammo)
      assert.are.same({ current = 0, max = 0, percentage = 0 }, report.total)
    end)

    -- Positive: aggregates subtotals from firing/resupply/ammo and computes overall total
    it("should aggregate subtotals across firing units, resupply units, and depots", function()
      local systemState = {
        firingUnits = {
          ["FU-Alpha"] = { name = "FU-Alpha", weaponDBID = 1234 },
        },
        resupplyUnits = {
          ["RU-Alpha"] = { name = "RU-Alpha", weaponCountCurrent = 6, weaponCountDefault = 10 },
          ["RU-Bravo"] = { name = "RU-Bravo", weaponCountCurrent = 4, weaponCountDefault = 10 },
        },
        ammunitions = {
          ["Depot-1"] = { name = "Depot-1", weaponCountCurrent = 50, weaponCountDefault = 100 },
        },
      }
      trackStub(GameApi, "ScenEdit_GetUnit").invokes(function(nameOrGuid)
        if nameOrGuid == "FU-Alpha" then return { guid = "FU-Alpha" } end
        return { guid = nameOrGuid }
      end)
      trackStub(GameUtils, "getWeaponInfo").returns({ availableWeapons = 8, maxWeapons = 20 })

      local report = Ammo.getInventory(systemState, "Taiwan")

      assert.are.same({ current = 8, max = 20, percentage = 40 }, report.firing)
      assert.are.same({ current = 10, max = 20, percentage = 50 }, report.resupply)
      assert.are.same({ current = 50, max = 100, percentage = 50 }, report.ammo)
      assert.are.equal(68, report.total.current)
      assert.are.equal(140, report.total.max)
      assert.are.equal(49, report.total.percentage)
    end)

    -- Boundary: missing firing unit (game lookup returns nil) does not break aggregation
    it("should skip firing units that cannot be resolved in game state", function()
      local systemState = {
        firingUnits = {
          ["FU-Ghost"] = { name = "FU-Ghost", weaponDBID = 1234 },
        },
        resupplyUnits = {
          ["RU-Alpha"] = { name = "RU-Alpha", weaponCountCurrent = 5, weaponCountDefault = 10 },
        },
        ammunitions = {},
      }
      trackStub(GameApi, "ScenEdit_GetUnit").returns(nil)
      trackStub(GameUtils, "getWeaponInfo").returns({ availableWeapons = 99, maxWeapons = 99 })

      local report = Ammo.getInventory(systemState, "Taiwan")

      assert.are.same({ current = 0, max = 0, percentage = 0 }, report.firing)
      assert.are.same({ current = 5, max = 10, percentage = 50 }, report.resupply)
      assert.are.equal(5, report.total.current)
      assert.are.equal(10, report.total.max)
      assert.are.equal(50, report.total.percentage)
    end)

    -- Boundary: percentage stays at 0 when max is 0 (no divide-by-zero)
    it("should return percentage 0 when subtotal max is zero", function()
      local systemState = {
        firingUnits = {},
        resupplyUnits = {
          ["RU-Empty"] = { name = "RU-Empty", weaponCountCurrent = 0, weaponCountDefault = 0 },
        },
        ammunitions = {},
      }

      local report = Ammo.getInventory(systemState, "Taiwan")

      assert.are.equal(0, report.resupply.percentage)
      assert.are.equal(0, report.total.percentage)
    end)

    -- Positive: aggregates ammo across multiple weapon DBIDs and group units for firing
    it("should expand groups and multi-weaponDBID for firing units", function()
      local systemState = {
        firingUnits = {
          ["FU-Group"] = { name = "FU-Group", weaponDBID = { 1111, 2222 } },
        },
        resupplyUnits = {},
        ammunitions = {},
      }
      trackStub(GameApi, "ScenEdit_GetUnit").invokes(function(nameOrGuid)
        if nameOrGuid == "FU-Group" then
          return { guid = "FU-Group", group = { unitlist = { "U1", "U2" } } }
        end
        if nameOrGuid == "U1" then return { guid = "U1" } end
        if nameOrGuid == "U2" then return { guid = "U2" } end
        return nil
      end)
      trackStub(GameUtils, "getWeaponInfo").invokes(function(unit, dbid)
        if unit.guid == "U1" and dbid == 1111 then return { availableWeapons = 3, maxWeapons = 10 } end
        if unit.guid == "U1" and dbid == 2222 then return { availableWeapons = 2, maxWeapons = 10 } end
        if unit.guid == "U2" and dbid == 1111 then return { availableWeapons = 4, maxWeapons = 10 } end
        if unit.guid == "U2" and dbid == 2222 then return { availableWeapons = 1, maxWeapons = 10 } end
        return { availableWeapons = 0, maxWeapons = 0 }
      end)

      local report = Ammo.getInventory(systemState, "Taiwan")

      assert.are.equal(10, report.firing.current)
      assert.are.equal(40, report.firing.max)
      assert.are.equal(25, report.firing.percentage)
    end)
  end)

  -- ============================================================================
  -- resolveReloadPair
  -- ============================================================================

  describe("resolveReloadPair", function()
    local mockSystemState
    local firingUnit
    local resupplyUnit

    before_each(function()
      mockSystemState = makeSystemState()
      firingUnit = {
        guid = "FIRING-001",
        name = "Firing Unit Alpha",
        side = "Taiwan",
        group = { unitlist = { "FIRING-001" } },
        inArea = function(_, area) return area[1] == "RP-001" end
      }
      resupplyUnit = {
        guid = "RESUPPLY-001",
        name = "Ammo Sec, Alpha",
        side = "Taiwan",
        inArea = function(_, area) return area[1] == "RP-001" end
      }
      trackStub(GameApi, "ScenEdit_GetUnit").invokes(function(guidOrName)
        if guidOrName == "Ammo Sec, Alpha" then return resupplyUnit end
        if guidOrName == "Firing Unit Alpha" or guidOrName == "FIRING-001" then return firingUnit end
        return nil
      end)
    end)

    -- Boundary: a unit outside the system has no pair
    it("should return nil when unit name not in firingUnits or resupplyUnits", function()
      local unit = { guid = "UNIT-001", name = "Unknown Unit", side = "Taiwan" }
      assert.is_nil(Meeting.resolveReloadPair(mockSystemState, unit))
    end)

    -- Negative: a partner missing from the game leaves no pair
    it("should return nil when the partner unit is not in the game", function()
      resupplyUnit = nil
      assert.is_nil(Meeting.resolveReloadPair(mockSystemState, firingUnit))
    end)

    -- Negative: a partner without state leaves no pair, and nothing is looked up
    it("should return nil without a lookup when the partner has no state", function()
      mockSystemState.resupplyUnits = {}
      assert.is_nil(Meeting.resolveReloadPair(mockSystemState, firingUnit))
      assert.stub(GameApi.ScenEdit_GetUnit).was_not.called()
    end)

    -- Positive: resolved from the firing unit, the firing unit is reused and its partner looked up on its side
    it("should resolve both ends from the firing unit", function()
      local pair = Meeting.resolveReloadPair(mockSystemState, firingUnit)

      assert.are.equal(firingUnit, pair.firingUnit)
      assert.are.equal(resupplyUnit, pair.resupplyUnit)
      assert.are.equal(mockSystemState.firingUnits["Firing Unit Alpha"], pair.firingUnitState)
      assert.are.equal(mockSystemState.resupplyUnits["Ammo Sec, Alpha"], pair.resupplyUnitState)
      assert.is_true(pair.isTriggeredByFiringUnit)
      assert.stub(GameApi.ScenEdit_GetUnit).was.called_with("Ammo Sec, Alpha", "Taiwan")
    end)

    -- Positive: resolved from the resupply unit, the pair says so
    it("should resolve both ends from the resupply unit", function()
      local pair = Meeting.resolveReloadPair(mockSystemState, resupplyUnit)

      assert.are.equal(firingUnit, pair.firingUnit)
      assert.are.equal(resupplyUnit, pair.resupplyUnit)
      assert.is_false(pair.isTriggeredByFiringUnit)
    end)

    -- Positive: both in the firing unit's RL zone
    it("should report both units in one RL zone", function()
      assert.is_true(Meeting.resolveReloadPair(mockSystemState, firingUnit).isInSameReloadArea())
    end)

    -- Negative: the resupply unit outside that zone
    it("should report different zones when the resupply unit is elsewhere", function()
      resupplyUnit.inArea = function() return false end
      assert.is_false(Meeting.resolveReloadPair(mockSystemState, firingUnit).isInSameReloadArea())
    end)

    -- Negative: the firing unit in no RL zone
    it("should report different zones when the firing unit is in no RL zone", function()
      firingUnit.inArea = function() return false end
      assert.is_false(Meeting.resolveReloadPair(mockSystemState, firingUnit).isInSameReloadArea())
    end)

    -- Positive: low ammo reads the firing unit's threshold and weapon
    it("should read the firing unit's ammo against its threshold", function()
      trackStub(GameUtils, "getWeaponInfo").returns({ availableWeapons = 2, maxWeapons = 10 })
      assert.is_true(Meeting.resolveReloadPair(mockSystemState, firingUnit).isFiringUnitLowAmmo())
    end)

    -- Positive: the reload is built once from the resupply unit's stock, so the rule and the step see one value
    it("should build the reload once from the resupply unit's stock", function()
      local getWeaponInfoStub = trackStub(GameUtils, "getWeaponInfo").returns({ availableWeapons = 2, maxWeapons = 10 })
      local pair = Meeting.resolveReloadPair(mockSystemState, firingUnit)

      local reload = pair.buildReload()

      assert.are.equal(8, reload.count)
      assert.are.equal(reload, pair.buildReload())
      assert.stub(getWeaponInfoStub).was.called(1)
    end)
  end)

  -- ============================================================================
  -- isAtAmmoDepot
  -- ============================================================================

  describe("isAtAmmoDepot", function()
    local resupplyUnitState
    local resupplyUnit
    local ammoDepot

    before_each(function()
      resupplyUnitState = {
        name = "Ammo Sec, Alpha",
        ammunition = "Ammo Revetment, Alpha",
        operationalArea = {
          name = "OPAREA-1",
          AHA = { { area = { "RP-101", "RP-102", "RP-103", "RP-104" } } }
        }
      }
      resupplyUnit = {
        guid = "RESUPPLY-001",
        name = "Ammo Sec, Alpha",
        side = "China",
        inArea = function(_, area) return area[1] == "RP-101" end
      }
      ammoDepot = {
        guid = "AMMO-001",
        side = "China",
        inArea = function(_, area) return area[1] == "RP-101" end
      }
      trackStub(GameApi, "ScenEdit_GetUnit").invokes(function(guidOrName)
        if guidOrName == "Ammo Revetment, Alpha" then return ammoDepot end
        return nil
      end)
    end)

    -- Positive: both in one AHA zone
    it("should return true when resupply unit meets ammo depot in same AHA", function()
      assert.is_true(Meeting.isAtAmmoDepot(resupplyUnitState, resupplyUnit))
      assert.stub(GameApi.ScenEdit_GetUnit).was.called_with("Ammo Revetment, Alpha", "China")
    end)

    -- Boundary: the resupply unit in no AHA zone
    it("should return false when the resupply unit is in no AHA zone", function()
      resupplyUnit.inArea = function() return false end
      assert.is_false(Meeting.isAtAmmoDepot(resupplyUnitState, resupplyUnit))
    end)

    -- Negative: the depot elsewhere
    it("should return false when resupply unit and ammo depot are in different areas", function()
      ammoDepot.inArea = function() return false end
      assert.is_false(Meeting.isAtAmmoDepot(resupplyUnitState, resupplyUnit))
    end)

    -- Negative: the depot gone
    it("should return false when ammunition depot does not exist", function()
      ammoDepot = nil
      assert.is_false(Meeting.isAtAmmoDepot(resupplyUnitState, resupplyUnit))
    end)
  end)
end)
