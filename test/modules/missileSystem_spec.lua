-- MissileSystem Unit Tests
---@diagnostic disable: undefined-field
local MissileSystem = require("src.modules.missileSystem.init")
local Concealment = require("src.modules.missileSystem.concealment")
local Utils = require("src.utils.utils")
local GameApi = require("src.utils.gameApi")
local GameUtils = require("src.utils.gameUtils")
local Logger = require("src.utils.logger")
local constants = require("src.core.constants")
local AmphibiousLogistics = require("src.modules.landingOps.amphibiousLogistics")

-- ============================================================================
-- Stub Tracking
-- ============================================================================

local activeStubs = {}
local function trackStub(obj, method)
  local s = stub(obj, method)
  table.insert(activeStubs, s)
  return s
end

-- ============================================================================
-- Test Data Factories
-- ============================================================================

---Create a mock missile system context with sensible defaults
---@param overrides? table Key-value overrides applied to top-level fields
---@return table
local function createMockSystemCtx(overrides)
  local ctx = {
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
        wpnCurrent = 10,
        wpnDefault = 20,
        operationalArea = {
          name = "OPAREA-1",
          RL = { { area = { "RP-001", "RP-002", "RP-003", "RP-004" } } }
        }
      }
    },
    ammunitions = {}
  }
  if overrides then
    for k, v in pairs(overrides) do ctx[k] = v end
  end
  return ctx
end

---Create a mock firing unit context with sensible defaults
---@param overrides? table Key-value overrides applied to top-level fields
---@return table
local function createMockFiringUnitCtx(overrides)
  local ctx = {
    name = "Firing Unit Alpha",
    state = constants.MISSILE_SYSTEM_STATE.STATIC,
    operationalArea = {
      name = "OPAREA-1",
      FP = { { course = { { latitude = "N 25.00.00", longitude = "E 121.00.00" } } } }
    }
  }
  if overrides then
    for k, v in pairs(overrides) do ctx[k] = v end
  end
  return ctx
end

---Create a mock resupply unit context with sensible defaults
---@param overrides? table Key-value overrides applied to top-level fields
---@return table
local function createMockResupplyUnitCtx(overrides)
  local ctx = {
    name = "Ammo Sec, Alpha",
    state = constants.MISSILE_SYSTEM_STATE.REPOSITIONING,
    reloadStartTime = 12345,
    wpnCurrent = 5,
    wpnDefault = 20
  }
  if overrides then
    for k, v in pairs(overrides) do ctx[k] = v end
  end
  return ctx
end

-- ============================================================================
-- MissileSystem
-- ============================================================================

describe("MissileSystem", function()
  before_each(function()
    stub(Logger, "log")
    stub(Logger, "error")
    table.insert(activeStubs, Logger.log)
    table.insert(activeStubs, Logger.error)
  end)

  -- ==========================================================================
  -- isLowAmmo
  -- ==========================================================================

  describe("isLowAmmo", function()
    after_each(function()
      for _, s in ipairs(activeStubs) do s:revert() end
      activeStubs = {}
    end)

    it("should return false when percentage is nil", function()
      local unit = { guid = "UNIT-001" }
      assert.is_false(MissileSystem.isLowAmmo(unit, nil, 1234))
    end)

    it("should return false when weaponDBID is nil", function()
      local unit = { guid = "UNIT-001" }
      assert.is_false(MissileSystem.isLowAmmo(unit, 50, nil))
    end)

    it("should return false when total max ammo is zero", function()
      local unit = { guid = "UNIT-001" }
      trackStub(GameApi, "ScenEdit_GetUnit").returns(unit)
      trackStub(GameUtils, "getWeaponInfo").returns({ availableWeapons = 0, maxWeapons = 0 })

      assert.is_false(MissileSystem.isLowAmmo(unit, 50, 1234))
    end)

    it("should return true when ammo percentage is equal to threshold", function()
      local unit = { guid = "UNIT-001" }
      trackStub(GameApi, "ScenEdit_GetUnit").returns(unit)
      trackStub(GameUtils, "getWeaponInfo").returns({ availableWeapons = 5, maxWeapons = 10 })

      assert.is_true(MissileSystem.isLowAmmo(unit, 50, 1234))
    end)

    it("should return false when ammo percentage is above threshold", function()
      local unit = { guid = "UNIT-001" }
      trackStub(GameApi, "ScenEdit_GetUnit").returns(unit)
      trackStub(GameUtils, "getWeaponInfo").returns({ availableWeapons = 6, maxWeapons = 10 })

      assert.is_false(MissileSystem.isLowAmmo(unit, 50, 1234))
    end)

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

      assert.is_true(MissileSystem.isLowAmmo(unit, 15, 1234))
    end)

    it("should ignore missing units in group list", function()
      local unit = { guid = "GROUP-001", group = { unitlist = { "U1", "U2" } } }
      trackStub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
        if guid == "U1" then return { guid = "U1" } end
        return nil
      end)
      trackStub(GameUtils, "getWeaponInfo").returns({ availableWeapons = 5, maxWeapons = 10 })

      assert.is_true(MissileSystem.isLowAmmo(unit, 50, 1234))
    end)

    it("should pass weaponDBID to GameUtils.getWeaponInfo", function()
      local unit = { guid = "UNIT-001" }
      trackStub(GameApi, "ScenEdit_GetUnit").returns(unit)
      local stubGetWeaponInfo = trackStub(GameUtils, "getWeaponInfo").returns({ availableWeapons = 1, maxWeapons = 10 })

      MissileSystem.isLowAmmo(unit, 90, 4321)

      assert.stub(stubGetWeaponInfo).was.called()
      assert.are.equal(4321, stubGetWeaponInfo.calls[1].vals[2])
    end)

    -- Positive: multi-weapon DBID array
    it("should aggregate ammo across multiple weapon DBIDs", function()
      local unit = { guid = "UNIT-001" }
      trackStub(GameApi, "ScenEdit_GetUnit").returns(unit)
      trackStub(GameUtils, "getWeaponInfo").invokes(function(_, dbid)
        if dbid == 1111 then return { availableWeapons = 3, maxWeapons = 10 } end
        if dbid == 2222 then return { availableWeapons = 2, maxWeapons = 10 } end
        return { availableWeapons = 0, maxWeapons = 0 }
      end)

      -- total: 5/20 = 25%
      assert.is_true(MissileSystem.isLowAmmo(unit, 25, { 1111, 2222 }))
    end)

    -- Negative: multi-weapon DBID array above threshold
    it("should return false when multi-weapon total is above threshold", function()
      local unit = { guid = "UNIT-001" }
      trackStub(GameApi, "ScenEdit_GetUnit").returns(unit)
      trackStub(GameUtils, "getWeaponInfo").invokes(function(_, dbid)
        if dbid == 1111 then return { availableWeapons = 8, maxWeapons = 10 } end
        if dbid == 2222 then return { availableWeapons = 9, maxWeapons = 10 } end
        return { availableWeapons = 0, maxWeapons = 0 }
      end)

      -- total: 17/20 = 85%
      assert.is_false(MissileSystem.isLowAmmo(unit, 50, { 1111, 2222 }))
    end)
  end)

  -- ==========================================================================
  -- hasMetResupplyUnit
  -- ==========================================================================

  describe("hasMetResupplyUnit", function()
    local mockSystemCtx

    before_each(function()
      mockSystemCtx = createMockSystemCtx()
    end)

    after_each(function()
      for _, s in ipairs(activeStubs) do s:revert() end
      activeStubs = {}
    end)

    -- Boundary cases
    it("should return false when unit name not in firingUnits or resupplyUnits", function()
      local unit = { guid = "UNIT-001", name = "Unknown Unit", side = "Taiwan" }
      local hasMet, ctx = MissileSystem.hasMetResupplyUnit(mockSystemCtx, unit, true)
      assert.is_false(hasMet)
      assert.is_nil(ctx)
    end)

    it("should return false when unit is firing unit but not in any RL area", function()
      local firingUnit = {
        guid = "FIRING-001",
        name = "Firing Unit Alpha",
        side = "Taiwan",
        inArea = function() return false end
      }

      local hasMet, ctx = MissileSystem.hasMetResupplyUnit(mockSystemCtx, firingUnit, true)
      assert.is_false(hasMet)
      assert.is_nil(ctx)
    end)

    it("should return false when unit is resupply unit but not in any RL area", function()
      local resupplyUnit = {
        guid = "RESUPPLY-001",
        name = "Ammo Sec, Alpha",
        side = "Taiwan",
        inArea = function() return false end
      }

      local hasMet, ctx = MissileSystem.hasMetResupplyUnit(mockSystemCtx, resupplyUnit, true)
      assert.is_false(hasMet)
      assert.is_nil(ctx)
    end)

    -- Normal cases
    it("should return true when firing unit meets resupply unit in same area", function()
      local firingUnit = {
        guid = "FIRING-001",
        name = "Firing Unit Alpha",
        side = "Taiwan",
        group = { unitlist = { "FIRING-001" } },
        inArea = function(_, area) return area[1] == "RP-001" end,
        mounts = { { mount_dbid = 100, mount_weapons = { { wpn_dbid = 1234, wpn_current = 2, wpn_maxcap = 10, wpn_default = 10 } } } }
      }
      local mockResupplyUnit = {
        guid = "RESUPPLY-001",
        side = "Taiwan",
        inArea = function(_, area) return area[1] == "RP-001" end
      }

      trackStub(GameApi, "ScenEdit_GetUnit").invokes(function(guidOrName)
        if guidOrName == "Ammo Sec, Alpha" then return mockResupplyUnit end
        if guidOrName == "FIRING-001" then return firingUnit end
        return nil
      end)
      trackStub(GameApi, "ScenEdit_WeaponAllocation").returns({})

      local hasMet, ctx = MissileSystem.hasMetResupplyUnit(mockSystemCtx, firingUnit, true)
      assert.is_true(hasMet)
      assert.are.equal("Firing Unit Alpha", ctx.name)
    end)

    it("should return true when resupply unit meets firing unit in same area", function()
      local resupplyUnit = {
        guid = "RESUPPLY-001",
        name = "Ammo Sec, Alpha",
        side = "Taiwan",
        inArea = function(_, area) return area[1] == "RP-001" end
      }
      local mockFiringUnit = {
        guid = "FIRING-001",
        side = "Taiwan",
        group = { unitlist = { "FIRING-001" } },
        inArea = function(_, area) return area[1] == "RP-001" end,
        mounts = { { mount_dbid = 100, mount_weapons = { { wpn_dbid = 1234, wpn_current = 2, wpn_maxcap = 10, wpn_default = 10 } } } }
      }

      trackStub(GameApi, "ScenEdit_GetUnit").invokes(function(guidOrName)
        if guidOrName == "Firing Unit Alpha" then return mockFiringUnit end
        if guidOrName == "FIRING-001" then return mockFiringUnit end
        return nil
      end)
      trackStub(GameApi, "ScenEdit_WeaponAllocation").returns({})

      local hasMet, ctx = MissileSystem.hasMetResupplyUnit(mockSystemCtx, resupplyUnit, true)
      assert.is_true(hasMet)
      assert.are.equal("Ammo Sec, Alpha", ctx.name)
    end)

    it("should return false when units are in different areas", function()
      local firingUnit = {
        guid = "FIRING-001",
        name = "Firing Unit Alpha",
        side = "Taiwan",
        group = { unitlist = { "FIRING-001" } },
        inArea = function(_, area) return area[1] == "RP-001" end,
        mounts = { { mount_dbid = 100, mount_weapons = { { wpn_dbid = 1234, wpn_current = 2, wpn_maxcap = 10, wpn_default = 10 } } } }
      }
      local mockResupplyUnit = {
        guid = "RESUPPLY-001",
        side = "Taiwan",
        inArea = function() return false end
      }

      trackStub(GameApi, "ScenEdit_GetUnit").invokes(function(guidOrName)
        if guidOrName == "Ammo Sec, Alpha" then return mockResupplyUnit end
        if guidOrName == "FIRING-001" then return firingUnit end
        return nil
      end)

      local hasMet, ctx = MissileSystem.hasMetResupplyUnit(mockSystemCtx, firingUnit, true)
      assert.is_false(hasMet)
      assert.is_nil(ctx)
    end)

    -- State validation (auto mode)
    it("should NOT match when state is STATIC in auto mode", function()
      mockSystemCtx.firingUnits["Firing Unit Alpha"].state = constants.MISSILE_SYSTEM_STATE.STATIC

      local firingUnit = {
        guid = "FIRING-001",
        name = "Firing Unit Alpha",
        side = "Taiwan",
        inArea = function(_, area) return area[1] == "RP-001" end
      }

      local hasMet, ctx = MissileSystem.hasMetResupplyUnit(mockSystemCtx, firingUnit, true)
      assert.is_false(hasMet)
      assert.is_nil(ctx)
    end)

    it("should match when state is STATIC in manual mode (isAuto=false)", function()
      mockSystemCtx.firingUnits["Firing Unit Alpha"].state = constants.MISSILE_SYSTEM_STATE.STATIC

      local firingUnit = {
        guid = "FIRING-001",
        name = "Firing Unit Alpha",
        side = "Taiwan",
        group = { unitlist = { "FIRING-001" } },
        inArea = function(_, area) return area[1] == "RP-001" end,
        mounts = { { mount_dbid = 100, mount_weapons = { { wpn_dbid = 1234, wpn_current = 2, wpn_maxcap = 10, wpn_default = 10 } } } }
      }
      local mockResupplyUnit = {
        guid = "RESUPPLY-001",
        side = "Taiwan",
        inArea = function(_, area) return area[1] == "RP-001" end
      }

      trackStub(GameApi, "ScenEdit_GetUnit").invokes(function(guidOrName)
        if guidOrName == "Ammo Sec, Alpha" then return mockResupplyUnit end
        if guidOrName == "FIRING-001" then return firingUnit end
        return nil
      end)
      trackStub(GameApi, "ScenEdit_WeaponAllocation").returns({})

      local hasMet, ctx = MissileSystem.hasMetResupplyUnit(mockSystemCtx, firingUnit, false)
      assert.is_true(hasMet)
      assert.is_not_nil(ctx)
    end)
  end)

  -- ==========================================================================
  -- hasMetAmmoDepot
  -- ==========================================================================

  describe("hasMetAmmoDepot", function()
    local mockSystemCtx

    before_each(function()
      mockSystemCtx = createMockSystemCtx({
        firingUnits = {},
        resupplyUnits = {
          ["Ammo Sec, Alpha"] = {
            name = "Ammo Sec, Alpha",
            state = constants.MISSILE_SYSTEM_STATE.REPOSITIONING,
            ammunition = "Ammo Revetment, Alpha",
            wpnCurrent = 0,
            operationalArea = {
              name = "OPAREA-1",
              AHA = { { area = { "RP-101", "RP-102", "RP-103", "RP-104" } } }
            }
          }
        }
      })
    end)

    after_each(function()
      for _, s in ipairs(activeStubs) do s:revert() end
      activeStubs = {}
    end)

    -- Boundary cases
    it("should return false when unit name not in resupplyUnits", function()
      local unit = { guid = "UNIT-001", name = "Unknown Unit", side = "China" }
      local hasMet, ctx = MissileSystem.hasMetAmmoDepot(mockSystemCtx, unit, true)
      assert.is_false(hasMet)
      assert.is_nil(ctx)
    end)

    it("should return false when unit is resupply unit but not in any AHA area", function()
      local resupplyUnit = {
        guid = "RESUPPLY-001",
        name = "Ammo Sec, Alpha",
        side = "China",
        inArea = function() return false end
      }
      local mockAmmoDepot = {
        guid = "AMMO-001",
        side = "China",
        inArea = function(_, area) return area[1] == "RP-101" end
      }

      trackStub(GameApi, "ScenEdit_GetUnit").invokes(function(guidOrName)
        if guidOrName == "Ammo Revetment, Alpha" then return mockAmmoDepot end
        return nil
      end)

      local hasMet, ctx = MissileSystem.hasMetAmmoDepot(mockSystemCtx, resupplyUnit, true)
      assert.is_false(hasMet)
      assert.is_nil(ctx)
    end)

    -- Normal cases
    it("should return true when resupply unit meets ammo depot in same AHA", function()
      local resupplyUnit = {
        guid = "RESUPPLY-001",
        name = "Ammo Sec, Alpha",
        side = "China",
        inArea = function(_, area) return area[1] == "RP-101" end
      }
      local mockAmmoDepot = {
        guid = "AMMO-001",
        side = "China",
        inArea = function(_, area) return area[1] == "RP-101" end
      }

      trackStub(GameApi, "ScenEdit_GetUnit").invokes(function(guidOrName)
        if guidOrName == "Ammo Revetment, Alpha" then return mockAmmoDepot end
        return nil
      end)

      local hasMet, ctx = MissileSystem.hasMetAmmoDepot(mockSystemCtx, resupplyUnit, true)
      assert.is_true(hasMet)
      assert.are.equal("Ammo Sec, Alpha", ctx.name)
    end)

    it("should return false when resupply unit and ammo depot are in different areas", function()
      local resupplyUnit = {
        guid = "RESUPPLY-001",
        name = "Ammo Sec, Alpha",
        side = "China",
        inArea = function(_, area) return area[1] == "RP-101" end
      }
      local mockAmmoDepot = {
        guid = "AMMO-001",
        side = "China",
        inArea = function() return false end
      }

      trackStub(GameApi, "ScenEdit_GetUnit").invokes(function(guidOrName)
        if guidOrName == "Ammo Revetment, Alpha" then return mockAmmoDepot end
        return nil
      end)

      local hasMet, ctx = MissileSystem.hasMetAmmoDepot(mockSystemCtx, resupplyUnit, true)
      assert.is_false(hasMet)
      assert.is_nil(ctx)
    end)

    it("should return false when ammunition depot does not exist", function()
      local resupplyUnit = {
        guid = "RESUPPLY-001",
        name = "Ammo Sec, Alpha",
        side = "China",
        inArea = function(_, area) return area[1] == "RP-101" end
      }

      trackStub(GameApi, "ScenEdit_GetUnit").returns(nil)

      local hasMet, ctx = MissileSystem.hasMetAmmoDepot(mockSystemCtx, resupplyUnit, true)
      assert.is_false(hasMet)
      assert.is_nil(ctx)
    end)

    -- State validation (auto mode)
    it("should NOT match when state is STATIC in auto mode", function()
      mockSystemCtx.resupplyUnits["Ammo Sec, Alpha"].state = constants.MISSILE_SYSTEM_STATE.STATIC

      local resupplyUnit = {
        guid = "RESUPPLY-001",
        name = "Ammo Sec, Alpha",
        side = "China",
        inArea = function(_, area) return area[1] == "RP-101" end
      }

      local hasMet, ctx = MissileSystem.hasMetAmmoDepot(mockSystemCtx, resupplyUnit, true)
      assert.is_false(hasMet)
      assert.is_nil(ctx)
    end)

    it("should match when state is STATIC in manual mode (isAuto=false)", function()
      mockSystemCtx.resupplyUnits["Ammo Sec, Alpha"].state = constants.MISSILE_SYSTEM_STATE.STATIC

      local resupplyUnit = {
        guid = "RESUPPLY-001",
        name = "Ammo Sec, Alpha",
        side = "China",
        inArea = function(_, area) return area[1] == "RP-101" end
      }
      local mockAmmoDepot = {
        guid = "AMMO-001",
        side = "China",
        inArea = function(_, area) return area[1] == "RP-101" end
      }

      trackStub(GameApi, "ScenEdit_GetUnit").invokes(function(guidOrName)
        if guidOrName == "Ammo Revetment, Alpha" then return mockAmmoDepot end
        return nil
      end)

      local hasMet, ctx = MissileSystem.hasMetAmmoDepot(mockSystemCtx, resupplyUnit, false)
      assert.is_true(hasMet)
      assert.is_not_nil(ctx)
    end)
  end)

  -- ==========================================================================
  -- moveToFiringPoint
  -- ==========================================================================

  describe("moveToFiringPoint", function()
    after_each(function()
      for _, s in ipairs(activeStubs) do s:revert() end
      activeStubs = {}
    end)

    -- State transitions
    it("should set state to REPOSITIONING", function()
      local firingUnitCtx = createMockFiringUnitCtx()
      local firingUnit = { guid = "F1" }

      trackStub(math, "random").returns(1)
      trackStub(GameApi, "ScenEdit_GetUnit").returns(firingUnit)
      trackStub(GameApi, "ScenEdit_SetUnit")

      MissileSystem.moveToFiringPoint(firingUnitCtx, firingUnit)

      assert.are.equal(constants.MISSILE_SYSTEM_STATE.REPOSITIONING, firingUnitCtx.state)
    end)

    -- Return value tests
    it("should return true when move is successful", function()
      local firingUnitCtx = createMockFiringUnitCtx()
      local firingUnit = { guid = "F1" }

      trackStub(math, "random").returns(1)
      trackStub(GameApi, "ScenEdit_GetUnit").returns(firingUnit)
      trackStub(GameApi, "ScenEdit_SetUnit")

      local result = MissileSystem.moveToFiringPoint(firingUnitCtx, firingUnit)

      assert.is_true(result)
    end)

    it("should return false when FP positions array is empty", function()
      local firingUnitCtx = createMockFiringUnitCtx({
        operationalArea = {
          name = "OPAREA-1",
          FP = {}
        }
      })
      local firingUnit = { guid = "F1" }

      local result = MissileSystem.moveToFiringPoint(firingUnitCtx, firingUnit)

      assert.is_false(result)
      -- State should still be set to REPOSITIONING before the check
      assert.are.equal(constants.MISSILE_SYSTEM_STATE.REPOSITIONING, firingUnitCtx.state)
    end)

    it("should return false when position has no course", function()
      local firingUnitCtx = createMockFiringUnitCtx({
        operationalArea = {
          name = "OPAREA-1",
          FP = { { area = { "RP-001" } } } -- no course field
        }
      })
      local firingUnit = { guid = "F1" }

      trackStub(math, "random").returns(1)

      local result = MissileSystem.moveToFiringPoint(firingUnitCtx, firingUnit)

      assert.is_false(result)
    end)

    -- Unit movement
    it("should set unit properties for single unit", function()
      local firingUnitCtx = createMockFiringUnitCtx()
      local firingUnit = { guid = "F1", side = "Taiwan" }

      trackStub(math, "random").returns(1)
      trackStub(GameApi, "ScenEdit_GetUnit").returns(firingUnit)
      local stubSetUnit = trackStub(GameApi, "ScenEdit_SetUnit")

      MissileSystem.moveToFiringPoint(firingUnitCtx, firingUnit)

      assert.stub(stubSetUnit).was.called(1)
      assert.are.equal("F1", stubSetUnit.calls[1].vals[1].guid)
      assert.are.equal(constants.THROTTLES.FULL, stubSetUnit.calls[1].vals[1].manualthrottle)
      assert.are.equal(constants.SPEEDS.NORMAL, stubSetUnit.calls[1].vals[1].manualSpeed)
      assert.is_false(stubSetUnit.calls[1].vals[1].holdposition)
    end)

    it("should set course from selected position", function()
      local expectedCourse = {
        { latitude = "N 25.00.00", longitude = "E 121.00.00" },
        { latitude = "N 25.01.00", longitude = "E 121.01.00" }
      }
      local firingUnitCtx = createMockFiringUnitCtx({
        operationalArea = {
          name = "OPAREA-1",
          FP = { { course = expectedCourse } }
        }
      })
      local firingUnit = { guid = "F1", side = "Taiwan" }

      trackStub(math, "random").returns(1)
      trackStub(GameApi, "ScenEdit_GetUnit").returns(firingUnit)
      local stubSetUnit = trackStub(GameApi, "ScenEdit_SetUnit")

      MissileSystem.moveToFiringPoint(firingUnitCtx, firingUnit)

      assert.are.same(expectedCourse, stubSetUnit.calls[1].vals[1].course)
    end)

    it("should iterate through all units in group", function()
      local firingUnitCtx = createMockFiringUnitCtx()
      local firingUnit = {
        guid = "GROUP-001",
        side = "Taiwan",
        group = { unitlist = { "U1", "U2", "U3" } }
      }

      trackStub(math, "random").returns(1)
      trackStub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
        if guid == "U1" then return { guid = "U1", side = "Taiwan" } end
        if guid == "U2" then return { guid = "U2", side = "Taiwan" } end
        if guid == "U3" then return { guid = "U3", side = "Taiwan" } end
        return nil
      end)
      local stubSetUnit = trackStub(GameApi, "ScenEdit_SetUnit")

      MissileSystem.moveToFiringPoint(firingUnitCtx, firingUnit)

      assert.stub(stubSetUnit).was.called(3)
      assert.are.equal("U1", stubSetUnit.calls[1].vals[1].guid)
      assert.are.equal("U2", stubSetUnit.calls[2].vals[1].guid)
      assert.are.equal("U3", stubSetUnit.calls[3].vals[1].guid)
    end)

    it("should skip nil units in group list", function()
      local firingUnitCtx = createMockFiringUnitCtx()
      local firingUnit = {
        guid = "GROUP-001",
        side = "Taiwan",
        group = { unitlist = { "U1", "U2", "U3" } }
      }

      trackStub(math, "random").returns(1)
      trackStub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
        if guid == "U1" then return { guid = "U1", side = "Taiwan" } end
        if guid == "U2" then return nil end -- U2 not found
        if guid == "U3" then return { guid = "U3", side = "Taiwan" } end
        return nil
      end)
      local stubSetUnit = trackStub(GameApi, "ScenEdit_SetUnit")

      MissileSystem.moveToFiringPoint(firingUnitCtx, firingUnit)

      assert.stub(stubSetUnit).was.called(2)
      assert.are.equal("U1", stubSetUnit.calls[1].vals[1].guid)
      assert.are.equal("U3", stubSetUnit.calls[2].vals[1].guid)
    end)

    -- Random position selection
    it("should use random position from FP array", function()
      local course1 = { { latitude = "N 25.00.00", longitude = "E 121.00.00" } }
      local course2 = { { latitude = "N 26.00.00", longitude = "E 122.00.00" } }
      local firingUnitCtx = createMockFiringUnitCtx({
        operationalArea = {
          name = "OPAREA-1",
          FP = {
            { course = course1 },
            { course = course2 }
          }
        }
      })
      local firingUnit = { guid = "F1", side = "Taiwan" }

      trackStub(math, "random").returns(2) -- Select second position
      trackStub(GameApi, "ScenEdit_GetUnit").returns(firingUnit)
      local stubSetUnit = trackStub(GameApi, "ScenEdit_SetUnit")

      MissileSystem.moveToFiringPoint(firingUnitCtx, firingUnit)

      assert.are.same(course2, stubSetUnit.calls[1].vals[1].course)
    end)
  end)

  -- ==========================================================================
  -- setReloadStartTime
  -- ==========================================================================

  describe("setReloadStartTime", function()
    after_each(function()
      for _, s in ipairs(activeStubs) do s:revert() end
      activeStubs = {}
    end)

    -- State transitions
    it("should set state to RELOAD", function()
      local firingUnitCtx = { state = constants.MISSILE_SYSTEM_STATE.STATIC }
      local firingUnit = { guid = "F1" }

      trackStub(GameApi, "ScenEdit_CurrentTime").returns(12345)
      trackStub(GameApi, "ScenEdit_GetUnit").returns(firingUnit)
      trackStub(GameApi, "ScenEdit_SetUnit")

      MissileSystem.setReloadStartTime(firingUnitCtx, firingUnit, false)

      assert.are.equal(constants.MISSILE_SYSTEM_STATE.RELOAD, firingUnitCtx.state)
    end)

    it("should set reloadStartTime to current time", function()
      local firingUnitCtx = { state = constants.MISSILE_SYSTEM_STATE.STATIC, reloadStartTime = nil }
      local firingUnit = { guid = "F1" }

      trackStub(GameApi, "ScenEdit_CurrentTime").returns(67890)
      trackStub(GameApi, "ScenEdit_GetUnit").returns(firingUnit)
      trackStub(GameApi, "ScenEdit_SetUnit")

      MissileSystem.setReloadStartTime(firingUnitCtx, firingUnit, false)

      assert.are.equal(67890, firingUnitCtx.reloadStartTime)
    end)

    -- Single unit (no group)
    it("should handle single unit without group", function()
      local firingUnitCtx = { state = constants.MISSILE_SYSTEM_STATE.STATIC }
      local firingUnit = { guid = "SINGLE-001", side = "Taiwan" }

      trackStub(GameApi, "ScenEdit_CurrentTime").returns(12345)
      trackStub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
        if guid == "SINGLE-001" then return firingUnit end
        return nil
      end)
      local stubSetUnit = trackStub(GameApi, "ScenEdit_SetUnit")

      MissileSystem.setReloadStartTime(firingUnitCtx, firingUnit, true)

      assert.stub(stubSetUnit).was.called(1)
      assert.are.equal("SINGLE-001", stubSetUnit.calls[1].vals[1].guid)
    end)

    -- Group units
    it("should iterate through all units in group", function()
      local firingUnitCtx = { state = constants.MISSILE_SYSTEM_STATE.STATIC }
      local firingUnit = {
        guid = "GROUP-001",
        side = "Taiwan",
        group = { unitlist = { "U1", "U2", "U3" } }
      }

      trackStub(GameApi, "ScenEdit_CurrentTime").returns(12345)
      trackStub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
        if guid == "U1" then return { guid = "U1", side = "Taiwan" } end
        if guid == "U2" then return { guid = "U2", side = "Taiwan" } end
        if guid == "U3" then return { guid = "U3", side = "Taiwan" } end
        return nil
      end)
      local stubSetUnit = trackStub(GameApi, "ScenEdit_SetUnit")

      MissileSystem.setReloadStartTime(firingUnitCtx, firingUnit, true)

      assert.stub(stubSetUnit).was.called(3)
      assert.are.equal("U1", stubSetUnit.calls[1].vals[1].guid)
      assert.are.equal("U2", stubSetUnit.calls[2].vals[1].guid)
      assert.are.equal("U3", stubSetUnit.calls[3].vals[1].guid)
    end)

    -- isAuto behavior
    it("should call setUnitProperties when isAuto is true", function()
      local firingUnitCtx = { state = constants.MISSILE_SYSTEM_STATE.STATIC }
      local firingUnit = { guid = "F1", side = "Taiwan" }

      trackStub(GameApi, "ScenEdit_CurrentTime").returns(12345)
      trackStub(GameApi, "ScenEdit_GetUnit").returns(firingUnit)
      local stubSetUnit = trackStub(GameApi, "ScenEdit_SetUnit")

      MissileSystem.setReloadStartTime(firingUnitCtx, firingUnit, true)

      assert.stub(stubSetUnit).was.called(1)
      assert.is_true(stubSetUnit.calls[1].vals[1].holdposition)
    end)

    it("should call setUnitProperties with manual params when isAuto is false", function()
      local firingUnitCtx = { state = constants.MISSILE_SYSTEM_STATE.STATIC }
      local firingUnit = { guid = "F1", side = "Taiwan" }

      trackStub(GameApi, "ScenEdit_CurrentTime").returns(12345)
      trackStub(GameApi, "ScenEdit_GetUnit").returns(firingUnit)
      local stubSetUnit = trackStub(GameApi, "ScenEdit_SetUnit")

      MissileSystem.setReloadStartTime(firingUnitCtx, firingUnit, false)

      assert.stub(stubSetUnit).was.called(1)
      assert.is_false(stubSetUnit.calls[1].vals[1].holdposition)
    end)

    -- Nil unit handling
    it("should skip nil units in group list", function()
      local firingUnitCtx = { state = constants.MISSILE_SYSTEM_STATE.STATIC }
      local firingUnit = {
        guid = "GROUP-001",
        side = "Taiwan",
        group = { unitlist = { "U1", "U2", "U3" } }
      }

      trackStub(GameApi, "ScenEdit_CurrentTime").returns(12345)
      trackStub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
        if guid == "U1" then return { guid = "U1", side = "Taiwan" } end
        if guid == "U2" then return nil end -- U2 not found
        if guid == "U3" then return { guid = "U3", side = "Taiwan" } end
        return nil
      end)
      local stubSetUnit = trackStub(GameApi, "ScenEdit_SetUnit")

      MissileSystem.setReloadStartTime(firingUnitCtx, firingUnit, true)

      assert.stub(stubSetUnit).was.called(2)
      assert.are.equal("U1", stubSetUnit.calls[1].vals[1].guid)
      assert.are.equal("U3", stubSetUnit.calls[2].vals[1].guid)
    end)
  end)

  -- ==========================================================================
  -- setStateToStatic
  -- ==========================================================================

  describe("setStateToStatic", function()
    local mockSystemCtx

    before_each(function()
      mockSystemCtx = createMockSystemCtx({
        firingUnits = {
          ["Firing Unit Alpha"] = {
            name = "Firing Unit Alpha",
            state = constants.MISSILE_SYSTEM_STATE.RELOAD,
            reloadStartTime = 12345
          }
        },
        resupplyUnits = {
          ["Ammo Sec, Alpha"] = {
            name = "Ammo Sec, Alpha",
            state = constants.MISSILE_SYSTEM_STATE.REPOSITIONING,
            reloadStartTime = 67890
          }
        }
      })
    end)

    after_each(function()
      for _, s in ipairs(activeStubs) do s:revert() end
      activeStubs = {}
    end)

    -- Boundary cases
    it("should do nothing when unit name not in firingUnits or resupplyUnits", function()
      local firingUnit = { guid = "UNKNOWN-001", name = "Unknown Unit" }
      local firingUnitAlpha = mockSystemCtx.firingUnits["Firing Unit Alpha"]

      local stubGetUnit = trackStub(GameApi, "ScenEdit_GetUnit").returns(nil)
      local stubSetUnit = trackStub(GameApi, "ScenEdit_SetUnit")

      MissileSystem.setStateToStatic(mockSystemCtx, firingUnit, true)

      assert.are.equal(constants.MISSILE_SYSTEM_STATE.RELOAD, firingUnitAlpha.state)
      assert.are.equal(12345, firingUnitAlpha.reloadStartTime)
      assert.stub(stubGetUnit).was_not.called()
      assert.stub(stubSetUnit).was_not.called()
    end)

    -- State transitions for firing units
    it("should set firingUnit state to STATIC", function()
      local firingUnit = { guid = "F1", name = "Firing Unit Alpha" }

      trackStub(GameApi, "ScenEdit_GetUnit").returns(firingUnit)
      trackStub(GameApi, "ScenEdit_SetUnit")

      MissileSystem.setStateToStatic(mockSystemCtx, firingUnit, false)

      assert.are.equal(constants.MISSILE_SYSTEM_STATE.STATIC, mockSystemCtx.firingUnits["Firing Unit Alpha"].state)
    end)

    it("should clear firingUnit reloadStartTime", function()
      local firingUnit = { guid = "F1", name = "Firing Unit Alpha" }

      trackStub(GameApi, "ScenEdit_GetUnit").returns(firingUnit)
      trackStub(GameApi, "ScenEdit_SetUnit")

      MissileSystem.setStateToStatic(mockSystemCtx, firingUnit, false)

      assert.is_nil(mockSystemCtx.firingUnits["Firing Unit Alpha"].reloadStartTime)
    end)

    -- isAuto behavior
    it("should call setUnitProperties when isAuto is true", function()
      local firingUnit = { guid = "F1", name = "Firing Unit Alpha", side = "Taiwan" }

      trackStub(GameApi, "ScenEdit_GetUnit").returns(firingUnit)
      local stubSetUnit = trackStub(GameApi, "ScenEdit_SetUnit")
      local stubSetDoctrine = trackStub(GameApi, "ScenEdit_SetDoctrine")

      MissileSystem.setStateToStatic(mockSystemCtx, firingUnit, true)

      assert.stub(stubSetUnit).was.called(1)
      assert.is_true(stubSetUnit.calls[1].vals[1].holdposition)
      assert.stub(stubSetDoctrine).was.called(1)
      assert.are.equal(constants.WCS.HOLD, stubSetDoctrine.calls[1].vals[2].weapon_control_status_land)
    end)

    it("should call setUnitProperties with manual params when isAuto is false", function()
      local firingUnit = { guid = "F1", name = "Firing Unit Alpha", side = "Taiwan" }

      trackStub(GameApi, "ScenEdit_GetUnit").returns(firingUnit)
      local stubSetUnit = trackStub(GameApi, "ScenEdit_SetUnit")
      trackStub(GameApi, "ScenEdit_SetDoctrine")

      MissileSystem.setStateToStatic(mockSystemCtx, firingUnit, false)

      assert.stub(stubSetUnit).was.called(1)
      assert.is_false(stubSetUnit.calls[1].vals[1].holdposition)
    end)

    -- Single unit (no group)
    it("should handle single unit without group", function()
      local firingUnit = { guid = "SINGLE-001", name = "Firing Unit Alpha", side = "Taiwan" }

      trackStub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
        if guid == "SINGLE-001" then return firingUnit end
        return nil
      end)
      local stubSetUnit = trackStub(GameApi, "ScenEdit_SetUnit")
      trackStub(GameApi, "ScenEdit_SetDoctrine")

      MissileSystem.setStateToStatic(mockSystemCtx, firingUnit, true)

      assert.stub(stubSetUnit).was.called(1)
      assert.are.equal("SINGLE-001", stubSetUnit.calls[1].vals[1].guid)
    end)

    -- Group units
    it("should iterate through all units in group", function()
      local firingUnit = {
        guid = "GROUP-001",
        name = "Firing Unit Alpha",
        side = "Taiwan",
        group = { unitlist = { "U1", "U2", "U3" } }
      }

      trackStub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
        if guid == "U1" then return { guid = "U1", side = "Taiwan" } end
        if guid == "U2" then return { guid = "U2", side = "Taiwan" } end
        if guid == "U3" then return { guid = "U3", side = "Taiwan" } end
        return nil
      end)
      local stubSetUnit = trackStub(GameApi, "ScenEdit_SetUnit")
      trackStub(GameApi, "ScenEdit_SetDoctrine")

      MissileSystem.setStateToStatic(mockSystemCtx, firingUnit, true)

      assert.stub(stubSetUnit).was.called(3)
      assert.are.equal("U1", stubSetUnit.calls[1].vals[1].guid)
      assert.are.equal("U2", stubSetUnit.calls[2].vals[1].guid)
      assert.are.equal("U3", stubSetUnit.calls[3].vals[1].guid)
    end)

    it("should skip nil units in group list", function()
      local firingUnit = {
        guid = "GROUP-001",
        name = "Firing Unit Alpha",
        side = "Taiwan",
        group = { unitlist = { "U1", "U2", "U3" } }
      }

      trackStub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
        if guid == "U1" then return { guid = "U1", side = "Taiwan" } end
        if guid == "U2" then return nil end -- U2 not found
        if guid == "U3" then return { guid = "U3", side = "Taiwan" } end
        return nil
      end)
      local stubSetUnit = trackStub(GameApi, "ScenEdit_SetUnit")
      trackStub(GameApi, "ScenEdit_SetDoctrine")

      MissileSystem.setStateToStatic(mockSystemCtx, firingUnit, true)

      assert.stub(stubSetUnit).was.called(2)
      assert.are.equal("U1", stubSetUnit.calls[1].vals[1].guid)
      assert.are.equal("U3", stubSetUnit.calls[2].vals[1].guid)
    end)

    -- Priority: firingUnits over resupplyUnits
    it("should prioritize firingUnits when unit exists in both collections", function()
      mockSystemCtx.resupplyUnits["Firing Unit Alpha"] = {
        name = "Firing Unit Alpha",
        state = constants.MISSILE_SYSTEM_STATE.HIDE,
        reloadStartTime = 99999
      }

      local firingUnit = { guid = "F1", name = "Firing Unit Alpha" }
      local firingUnitAlpha = mockSystemCtx.firingUnits["Firing Unit Alpha"]
      local resupplyUnitAlpha = mockSystemCtx.resupplyUnits["Firing Unit Alpha"]

      trackStub(GameApi, "ScenEdit_GetUnit").returns(firingUnit)
      trackStub(GameApi, "ScenEdit_SetUnit")

      MissileSystem.setStateToStatic(mockSystemCtx, firingUnit, false)

      assert.are.equal(constants.MISSILE_SYSTEM_STATE.STATIC, firingUnitAlpha.state)
      assert.is_nil(firingUnitAlpha.reloadStartTime)
      assert.are.equal(constants.MISSILE_SYSTEM_STATE.HIDE, resupplyUnitAlpha.state)
      assert.are.equal(99999, resupplyUnitAlpha.reloadStartTime)
    end)
  end)

  -- ==========================================================================
  -- setStateToHIDE
  -- ==========================================================================

  describe("setStateToHIDE", function()
    after_each(function()
      for _, s in ipairs(activeStubs) do s:revert() end
      activeStubs = {}
    end)

    -- State transitions
    it("should set state to HIDE", function()
      local firingUnitCtx = { state = constants.MISSILE_SYSTEM_STATE.STATIC }
      local firingUnit = { guid = "F1" }

      trackStub(GameApi, "ScenEdit_GetUnit").returns(firingUnit)
      trackStub(GameApi, "ScenEdit_SetUnit")

      MissileSystem.setStateToHIDE(firingUnitCtx, firingUnit, false)

      assert.are.equal(constants.MISSILE_SYSTEM_STATE.HIDE, firingUnitCtx.state)
    end)

    -- Single unit (no group)
    it("should handle single unit without group", function()
      local firingUnitCtx = { state = constants.MISSILE_SYSTEM_STATE.STATIC }
      local firingUnit = { guid = "SINGLE-001", side = "Taiwan" }

      trackStub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
        if guid == "SINGLE-001" then return firingUnit end
        return nil
      end)
      local stubSetUnit = trackStub(GameApi, "ScenEdit_SetUnit")
      trackStub(GameApi, "ScenEdit_SetDoctrine")

      MissileSystem.setStateToHIDE(firingUnitCtx, firingUnit, true)

      assert.stub(stubSetUnit).was.called(1)
      assert.are.equal("SINGLE-001", stubSetUnit.calls[1].vals[1].guid)
    end)

    -- Group units
    it("should iterate through all units in group", function()
      local firingUnitCtx = { state = constants.MISSILE_SYSTEM_STATE.STATIC }
      local firingUnit = {
        guid = "GROUP-001",
        side = "Taiwan",
        group = { unitlist = { "U1", "U2", "U3" } }
      }

      trackStub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
        if guid == "U1" then return { guid = "U1", side = "Taiwan" } end
        if guid == "U2" then return { guid = "U2", side = "Taiwan" } end
        if guid == "U3" then return { guid = "U3", side = "Taiwan" } end
        return nil
      end)
      local stubSetUnit = trackStub(GameApi, "ScenEdit_SetUnit")
      trackStub(GameApi, "ScenEdit_SetDoctrine")

      MissileSystem.setStateToHIDE(firingUnitCtx, firingUnit, true)

      assert.stub(stubSetUnit).was.called(3)
      assert.are.equal("U1", stubSetUnit.calls[1].vals[1].guid)
      assert.are.equal("U2", stubSetUnit.calls[2].vals[1].guid)
      assert.are.equal("U3", stubSetUnit.calls[3].vals[1].guid)
    end)

    -- isAuto behavior
    it("should call setUnitProperties when isAuto is true", function()
      local firingUnitCtx = { state = constants.MISSILE_SYSTEM_STATE.STATIC }
      local firingUnit = { guid = "F1", side = "Taiwan" }

      trackStub(GameApi, "ScenEdit_GetUnit").returns(firingUnit)
      local stubSetUnit = trackStub(GameApi, "ScenEdit_SetUnit")
      local stubSetDoctrine = trackStub(GameApi, "ScenEdit_SetDoctrine")

      MissileSystem.setStateToHIDE(firingUnitCtx, firingUnit, true)

      assert.stub(stubSetUnit).was.called(1)
      assert.is_true(stubSetUnit.calls[1].vals[1].holdposition)
      assert.stub(stubSetDoctrine).was.called(1)
      assert.are.equal(constants.WCS.HOLD, stubSetDoctrine.calls[1].vals[2].weapon_control_status_land)
    end)

    it("should call setUnitProperties with manual params when isAuto is false", function()
      local firingUnitCtx = { state = constants.MISSILE_SYSTEM_STATE.STATIC }
      local firingUnit = { guid = "F1", side = "Taiwan" }

      trackStub(GameApi, "ScenEdit_GetUnit").returns(firingUnit)
      local stubSetUnit = trackStub(GameApi, "ScenEdit_SetUnit")
      trackStub(GameApi, "ScenEdit_SetDoctrine")

      MissileSystem.setStateToHIDE(firingUnitCtx, firingUnit, false)

      assert.stub(stubSetUnit).was.called(1)
      assert.is_false(stubSetUnit.calls[1].vals[1].holdposition)
    end)

    -- Nil unit handling
    it("should skip nil units in group list", function()
      local firingUnitCtx = { state = constants.MISSILE_SYSTEM_STATE.STATIC }
      local firingUnit = {
        guid = "GROUP-001",
        side = "Taiwan",
        group = { unitlist = { "U1", "U2", "U3" } }
      }

      trackStub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
        if guid == "U1" then return { guid = "U1", side = "Taiwan" } end
        if guid == "U2" then return nil end -- U2 not found
        if guid == "U3" then return { guid = "U3", side = "Taiwan" } end
        return nil
      end)
      local stubSetUnit = trackStub(GameApi, "ScenEdit_SetUnit")
      trackStub(GameApi, "ScenEdit_SetDoctrine")

      MissileSystem.setStateToHIDE(firingUnitCtx, firingUnit, true)

      assert.stub(stubSetUnit).was.called(2)
      assert.are.equal("U1", stubSetUnit.calls[1].vals[1].guid)
      assert.are.equal("U3", stubSetUnit.calls[2].vals[1].guid)
    end)
  end)

  -- ==========================================================================
  -- isRepositioning
  -- ==========================================================================

  describe("isRepositioning", function()
    it("should return false when firingUnitCtx is nil", function()
      assert.is_false(MissileSystem.isRepositioning(nil, true))
      assert.is_false(MissileSystem.isRepositioning(nil, false))
    end)

    it("should return true when isAuto and state is REPOSITIONING", function()
      local firingUnitCtx = { state = constants.MISSILE_SYSTEM_STATE.REPOSITIONING }
      assert.is_true(MissileSystem.isRepositioning(firingUnitCtx, true))
    end)

    it("should return false when isAuto and state is not REPOSITIONING", function()
      local states = {
        constants.MISSILE_SYSTEM_STATE.STATIC,
        constants.MISSILE_SYSTEM_STATE.RELOAD,
        constants.MISSILE_SYSTEM_STATE.HIDE
      }

      for _, state in ipairs(states) do
        local firingUnitCtx = { state = state }
        assert.is_false(MissileSystem.isRepositioning(firingUnitCtx, true))
      end
    end)

    it("should always return true when isAuto is false (manual mode)", function()
      local states = {
        constants.MISSILE_SYSTEM_STATE.STATIC,
        constants.MISSILE_SYSTEM_STATE.REPOSITIONING,
        constants.MISSILE_SYSTEM_STATE.RELOAD,
        constants.MISSILE_SYSTEM_STATE.HIDE
      }

      for _, state in ipairs(states) do
        local firingUnitCtx = { state = state }
        assert.is_true(MissileSystem.isRepositioning(firingUnitCtx, false))
      end
    end)
  end)

  -- ==========================================================================
  -- setWCSToFree
  -- ==========================================================================

  describe("setWCSToFree", function()
    after_each(function()
      for _, s in ipairs(activeStubs) do s:revert() end
      activeStubs = {}
    end)

    it("should set state to STATIC", function()
      local firingUnitCtx = { state = constants.MISSILE_SYSTEM_STATE.RELOAD }
      local firingUnit = { guid = "F1" }

      trackStub(GameApi, "ScenEdit_GetUnit").returns(firingUnit)
      trackStub(GameApi, "ScenEdit_SetUnit")

      MissileSystem.setWCSToFree(firingUnitCtx, firingUnit, false)

      assert.are.equal(constants.MISSILE_SYSTEM_STATE.STATIC, firingUnitCtx.state)
    end)

    it("should set wcs to FREE when isAuto is true", function()
      local firingUnitCtx = { state = constants.MISSILE_SYSTEM_STATE.RELOAD }
      local firingUnit = { guid = "F1", side = "Taiwan" }

      trackStub(GameApi, "ScenEdit_GetUnit").returns(firingUnit)
      trackStub(GameApi, "ScenEdit_SetUnit")
      local stubSetDoctrine = trackStub(GameApi, "ScenEdit_SetDoctrine")

      MissileSystem.setWCSToFree(firingUnitCtx, firingUnit, true)

      assert.stub(stubSetDoctrine).was.called(1)
      assert.are.equal(constants.WCS.FREE, stubSetDoctrine.calls[1].vals[2].weapon_control_status_land)
    end)

    it("should call setUnitProperties with manual params when isAuto is false", function()
      local firingUnitCtx = { state = constants.MISSILE_SYSTEM_STATE.RELOAD }
      local firingUnit = { guid = "F1", side = "Taiwan" }

      trackStub(GameApi, "ScenEdit_GetUnit").returns(firingUnit)
      local stubSetUnit = trackStub(GameApi, "ScenEdit_SetUnit")
      trackStub(GameApi, "ScenEdit_SetDoctrine")

      MissileSystem.setWCSToFree(firingUnitCtx, firingUnit, false)

      assert.stub(stubSetUnit).was.called(1)
      assert.is_false(stubSetUnit.calls[1].vals[1].holdposition)
    end)

    it("should iterate group units and skip nil units", function()
      local firingUnitCtx = { state = constants.MISSILE_SYSTEM_STATE.RELOAD }
      local firingUnit = {
        guid = "GROUP-001",
        side = "Taiwan",
        group = { unitlist = { "U1", "U2", "U3" } }
      }

      trackStub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
        if guid == "U1" then return { guid = "U1", side = "Taiwan" } end
        if guid == "U2" then return nil end
        if guid == "U3" then return { guid = "U3", side = "Taiwan" } end
        return nil
      end)
      local stubSetUnit = trackStub(GameApi, "ScenEdit_SetUnit")
      trackStub(GameApi, "ScenEdit_SetDoctrine")

      MissileSystem.setWCSToFree(firingUnitCtx, firingUnit, true)

      assert.stub(stubSetUnit).was.called(2)
      assert.are.equal("U1", stubSetUnit.calls[1].vals[1].guid)
      assert.are.equal("U3", stubSetUnit.calls[2].vals[1].guid)
    end)

    -- Positive: SAM DBID uses weapon_control_status_air
    it("should set weapon_control_status_air for SAM unit", function()
      local firingUnitCtx = { state = constants.MISSILE_SYSTEM_STATE.RELOAD }
      local firingUnit = { guid = "SAM-001", side = "Taiwan", dbid = constants.PLATFORMS.PAC3 }

      trackStub(GameApi, "ScenEdit_GetUnit").returns(firingUnit)
      trackStub(GameApi, "ScenEdit_SetUnit")
      local stubSetDoctrine = trackStub(GameApi, "ScenEdit_SetDoctrine")

      MissileSystem.setWCSToFree(firingUnitCtx, firingUnit, true)

      assert.stub(stubSetDoctrine).was.called(1)
      assert.are.equal(constants.WCS.FREE, stubSetDoctrine.calls[1].vals[2].weapon_control_status_air)
      assert.is_nil(stubSetDoctrine.calls[1].vals[2].weapon_control_status_land)
    end)
  end)

  -- ==========================================================================
  -- handleSupplyAssetDestruction
  -- ==========================================================================

  describe("handleSupplyAssetDestruction", function()
    local mockSystemCtx

    before_each(function()
      mockSystemCtx = createMockSystemCtx({
        firingUnits = {},
        resupplyUnits = {
          ["Resupply Group Alpha"] = {
            name = "Resupply Group Alpha",
            wpnCurrent = 20,
            wpnDefault = 20,
            unitCount = 4
          },
          ["Resupply Group Beta"] = {
            name = "Resupply Group Beta",
            wpnCurrent = 3,
            wpnDefault = 20,
            unitCount = 4
          },
          ["Resupply Group Empty"] = {
            name = "Resupply Group Empty",
            wpnCurrent = 0,
            wpnDefault = 20,
            unitCount = 4
          }
        },
        ammunitions = {
          ["Ammo Depot Alpha"] = {
            name = "Ammo Depot Alpha",
            wpnCurrent = 100
          },
          ["Ammo Depot Empty"] = {
            name = "Ammo Depot Empty",
            wpnCurrent = 0
          }
        }
      })
    end)

    -- Ammunition depot destruction
    it("should set wpnCurrent to 0 when ammo depot with ammo is destroyed", function()
      local unit = { name = "Ammo Depot Alpha" }

      local result = MissileSystem.handleSupplyAssetDestruction(unit, mockSystemCtx)

      assert.is_true(result)
      assert.are.equal(0, mockSystemCtx.ammunitions["Ammo Depot Alpha"].wpnCurrent)
    end)

    -- Resupply unit destruction
    it("should reduce wpnCurrent proportionally when resupply unit is destroyed", function()
      local unit = {
        name = "Resupply Vehicle 1",
        group = { name = "Resupply Group Alpha" }
      }

      local result = MissileSystem.handleSupplyAssetDestruction(unit, mockSystemCtx)

      assert.is_true(result)
      -- wpnDefault=20, unitCount=4, ammoPerUnit=5, wpnCurrent=20-5=15
      assert.are.equal(15, mockSystemCtx.resupplyUnits["Resupply Group Alpha"].wpnCurrent)
    end)

    it("should set wpnCurrent to 0 when reduction would go negative", function()
      local unit = {
        name = "Resupply Vehicle 1",
        group = { name = "Resupply Group Beta" }
      }

      local result = MissileSystem.handleSupplyAssetDestruction(unit, mockSystemCtx)

      assert.is_true(result)
      -- wpnDefault=20, unitCount=4, ammoPerUnit=5, wpnCurrent=3-5=-2 -> 0
      assert.are.equal(0, mockSystemCtx.resupplyUnits["Resupply Group Beta"].wpnCurrent)
    end)

    it("should return false when resupply unit has no ammo", function()
      local unit = {
        name = "Resupply Vehicle 1",
        group = { name = "Resupply Group Empty" }
      }

      local result = MissileSystem.handleSupplyAssetDestruction(unit, mockSystemCtx)

      assert.is_false(result)
      assert.are.equal(0, mockSystemCtx.resupplyUnits["Resupply Group Empty"].wpnCurrent)
    end)

    -- Unknown unit
    it("should return false when unit is not in ammunitions or resupplyUnits", function()
      local unit = {
        name = "Unknown Unit",
        group = { name = "Unknown Group" }
      }

      local result = MissileSystem.handleSupplyAssetDestruction(unit, mockSystemCtx)

      assert.is_false(result)
    end)

    -- Edge cases
    it("should handle multiple destructions correctly", function()
      local unit1 = {
        name = "Resupply Vehicle 1",
        group = { name = "Resupply Group Alpha" }
      }
      local unit2 = {
        name = "Resupply Vehicle 2",
        group = { name = "Resupply Group Alpha" }
      }

      MissileSystem.handleSupplyAssetDestruction(unit1, mockSystemCtx)
      MissileSystem.handleSupplyAssetDestruction(unit2, mockSystemCtx)

      -- First: 20-5=15, Second: 15-5=10
      assert.are.equal(10, mockSystemCtx.resupplyUnits["Resupply Group Alpha"].wpnCurrent)
    end)

    it("should prioritize ammo depot match over resupply unit match", function()
      -- Add a resupply unit with same group name as ammo depot name
      mockSystemCtx.resupplyUnits["Ammo Depot Alpha"] = {
        name = "Ammo Depot Alpha",
        wpnCurrent = 50,
        wpnDefault = 50,
        unitCount = 5
      }

      local unit = { name = "Ammo Depot Alpha" }

      local result = MissileSystem.handleSupplyAssetDestruction(unit, mockSystemCtx)

      assert.is_true(result)
      -- Should match ammo depot first, set to 0
      assert.are.equal(0, mockSystemCtx.ammunitions["Ammo Depot Alpha"].wpnCurrent)
      -- Resupply unit should be unchanged
      assert.are.equal(50, mockSystemCtx.resupplyUnits["Ammo Depot Alpha"].wpnCurrent)
    end)
  end)

  -- ==========================================================================
  -- checkMissileSystemState
  -- ==========================================================================

  describe("checkMissileSystemState", function()
    after_each(function()
      for _, s in ipairs(activeStubs) do s:revert() end
      activeStubs = {}
    end)

    -- Positive: firing unit completes reload cycle
    it("should reload firing unit when reload conditions are met", function()
      local systemCtx = createMockSystemCtx({
        reloadTime = 60,
        firingUnits = {
          ["Firing Unit Alpha"] = {
            name = "Firing Unit Alpha",
            state = constants.MISSILE_SYSTEM_STATE.RELOAD,
            reloadStartTime = 1000,
            resupplyUnit = "Ammo Sec, Alpha",
            weaponDBID = 1234,
            ammoThreshold = 60,
            operationalArea = {
              name = "OPAREA-1",
              RL = { { area = { "RP-001", "RP-002", "RP-003", "RP-004" } } }
            }
          }
        },
        resupplyUnits = {
          ["Ammo Sec, Alpha"] = {
            name = "Ammo Sec, Alpha",
            state = constants.MISSILE_SYSTEM_STATE.REPOSITIONING,
            wpnCurrent = 10,
            wpnDefault = 20,
            operationalArea = {
              name = "OPAREA-1",
              RL = { { area = { "RP-001", "RP-002", "RP-003", "RP-004" } } }
            }
          }
        }
      })

      local firingUnit = {
        guid = "F1",
        name = "Firing Unit Alpha",
        side = "Taiwan",
        group = { unitlist = { "F1" } },
        inArea = function(_, area) return area[1] == "RP-001" end
      }
      local resupplyUnit = {
        guid = "R1",
        side = "Taiwan",
        inArea = function(_, area) return area[1] == "RP-001" end
      }

      trackStub(GameApi, "ScenEdit_CurrentTime").returns(1100)
      trackStub(GameApi, "ScenEdit_GetUnit").invokes(function(guidOrName)
        if guidOrName == "Firing Unit Alpha" then return firingUnit end
        if guidOrName == "F1" then return firingUnit end
        if guidOrName == "Ammo Sec, Alpha" then return resupplyUnit end
        return nil
      end)
      trackStub(GameUtils, "getWeaponInfo").returns({ availableWeapons = 2, maxWeapons = 10 })
      trackStub(GameApi, "ScenEdit_AddReloadsToUnit")
      trackStub(GameApi, "ScenEdit_SetUnit")

      MissileSystem.checkMissileSystemState(systemCtx, false, "Taiwan")

      assert.are.equal(constants.MISSILE_SYSTEM_STATE.STATIC, systemCtx.firingUnits["Firing Unit Alpha"].state)
      assert.is_nil(systemCtx.firingUnits["Firing Unit Alpha"].reloadStartTime)
    end)

    -- Positive: resupply unit completes ammunition transfer
    it("should transfer ammo to resupply unit when transfer conditions are met", function()
      local systemCtx = createMockSystemCtx({
        reloadTime = 60,
        firingUnits = {},
        resupplyUnits = {
          ["Ammo Sec, Alpha"] = {
            name = "Ammo Sec, Alpha",
            state = constants.MISSILE_SYSTEM_STATE.RELOAD,
            reloadStartTime = 1000,
            ammunition = "Ammo Depot",
            wpnCurrent = 0,
            wpnDefault = 20,
            operationalArea = {
              name = "OPAREA-1",
              RL = { { area = { "RP-001", "RP-002", "RP-003", "RP-004" } } },
              AHA = { { area = { "AHA-001", "AHA-002", "AHA-003", "AHA-004" } } }
            }
          }
        },
        ammunitions = {
          ["Ammo Depot"] = {
            name = "Ammo Depot",
            wpnCurrent = 100
          }
        }
      })

      local resupplyUnit = {
        guid = "R1",
        name = "Ammo Sec, Alpha",
        side = "Taiwan",
        inArea = function(_, area) return area[1] == "AHA-001" end
      }
      local ammoDepotUnit = {
        guid = "AD1",
        side = "Taiwan",
        inArea = function(_, area) return area[1] == "AHA-001" end
      }

      trackStub(GameApi, "ScenEdit_CurrentTime").returns(1100)
      trackStub(GameApi, "ScenEdit_GetUnit").invokes(function(guidOrName)
        if guidOrName == "Ammo Sec, Alpha" then return resupplyUnit end
        if guidOrName == "Ammo Depot" then return ammoDepotUnit end
        return nil
      end)

      MissileSystem.checkMissileSystemState(systemCtx, false, "Taiwan")

      assert.are.equal(20, systemCtx.resupplyUnits["Ammo Sec, Alpha"].wpnCurrent)
      assert.are.equal(80, systemCtx.ammunitions["Ammo Depot"].wpnCurrent)
      assert.are.equal(constants.MISSILE_SYSTEM_STATE.STATIC, systemCtx.resupplyUnits["Ammo Sec, Alpha"].state)
    end)

    -- Negative: firing unit not found
    it("should skip firing unit when unit not found in game", function()
      local systemCtx = createMockSystemCtx({
        reloadTime = 60,
        firingUnits = {
          ["Firing Unit Alpha"] = {
            name = "Firing Unit Alpha",
            state = constants.MISSILE_SYSTEM_STATE.RELOAD,
            reloadStartTime = 1000,
            resupplyUnit = "Ammo Sec, Alpha",
            weaponDBID = 1234,
            ammoThreshold = 60
          }
        },
        resupplyUnits = {}
      })

      trackStub(GameApi, "ScenEdit_GetUnit").returns(nil)

      MissileSystem.checkMissileSystemState(systemCtx, false, "Taiwan")

      -- State unchanged
      assert.are.equal(constants.MISSILE_SYSTEM_STATE.RELOAD, systemCtx.firingUnits["Firing Unit Alpha"].state)
    end)

    -- Negative: no units to process
    it("should not log when no reload events occurred", function()
      local systemCtx = createMockSystemCtx({
        firingUnits = {},
        resupplyUnits = {}
      })

      MissileSystem.checkMissileSystemState(systemCtx, false, "Taiwan")

      assert.stub(Logger.log).was_not.called()
    end)

    -- Positive: auto mode triggers low ammo move to RL
    it("should move firing unit to reload point when low ammo in auto mode", function()
      local systemCtx = createMockSystemCtx({
        reloadTime = 60,
        firingUnits = {
          ["Firing Unit Alpha"] = {
            name = "Firing Unit Alpha",
            state = constants.MISSILE_SYSTEM_STATE.STATIC,
            reloadStartTime = nil,
            resupplyUnit = "Ammo Sec, Alpha",
            weaponDBID = 1234,
            ammoThreshold = 60,
            operationalArea = {
              name = "OPAREA-1",
              RL = { { course = { { latitude = 25.0, longitude = 121.0 } }, area = { "RP-001" } } }
            }
          }
        },
        resupplyUnits = {
          ["Ammo Sec, Alpha"] = {
            name = "Ammo Sec, Alpha",
            state = constants.MISSILE_SYSTEM_STATE.STATIC,
            wpnCurrent = 10,
            wpnDefault = 20
          }
        }
      })

      local firingUnit = {
        guid = "F1",
        name = "Firing Unit Alpha",
        side = "Taiwan",
        group = { unitlist = { "F1" } }
      }

      trackStub(GameApi, "ScenEdit_GetUnit").invokes(function(guidOrName)
        if guidOrName == "Firing Unit Alpha" then return firingUnit end
        if guidOrName == "F1" then return firingUnit end
        return nil
      end)
      trackStub(GameUtils, "getWeaponInfo").returns({ availableWeapons = 1, maxWeapons = 10 })
      trackStub(GameApi, "ScenEdit_SetUnit")
      trackStub(math, "random").returns(1)

      MissileSystem.checkMissileSystemState(systemCtx, true, "Taiwan")

      assert.are.equal(constants.MISSILE_SYSTEM_STATE.REPOSITIONING,
        systemCtx.firingUnits["Firing Unit Alpha"].state)
    end)

    it("should move non-SAM firing unit to hide area after reload in auto mode", function()
      local hideCourse = {
        { latitude = "N 25.10.00", longitude = "E 121.10.00" }
      }
      local systemCtx = createMockSystemCtx({
        name = "srbm",
        reloadTime = 60,
        firingUnits = {
          ["Firing Unit Alpha"] = {
            name = "Firing Unit Alpha",
            state = constants.MISSILE_SYSTEM_STATE.RELOAD,
            reloadStartTime = 1000,
            resupplyUnit = "Ammo Sec, Alpha",
            weaponDBID = 1234,
            ammoThreshold = 60,
            operationalArea = {
              name = "OPAREA-1",
              RL = { { area = { "RP-001", "RP-002", "RP-003", "RP-004" } } },
              HA = { { course = hideCourse, area = { "HA-001", "HA-002", "HA-003", "HA-004" } } }
            }
          }
        },
        resupplyUnits = {
          ["Ammo Sec, Alpha"] = {
            name = "Ammo Sec, Alpha",
            state = constants.MISSILE_SYSTEM_STATE.REPOSITIONING,
            wpnCurrent = 10,
            wpnDefault = 20,
            operationalArea = {
              name = "OPAREA-1",
              RL = { { area = { "RP-001", "RP-002", "RP-003", "RP-004" } } },
              mask = { area = { "MASK-001", "MASK-002", "MASK-003", "MASK-004" } }
            }
          }
        }
      })

      local firingUnit = {
        guid = "F1",
        name = "Firing Unit Alpha",
        side = "Taiwan",
        group = { unitlist = { "F1" } },
        inArea = function(_, area) return area[1] == "RP-001" end
      }
      local resupplyUnit = {
        guid = "R1",
        name = "Ammo Sec, Alpha",
        side = "Taiwan",
        inArea = function(_, area) return area[1] == "RP-001" end
      }

      trackStub(GameApi, "ScenEdit_CurrentTime").returns(1100)
      trackStub(GameApi, "ScenEdit_GetUnit").invokes(function(guidOrName)
        if guidOrName == "Firing Unit Alpha" then return firingUnit end
        if guidOrName == "F1" then return firingUnit end
        if guidOrName == "Ammo Sec, Alpha" then return resupplyUnit end
        return nil
      end)
      trackStub(GameUtils, "getWeaponInfo").returns({ availableWeapons = 2, maxWeapons = 10 })
      trackStub(GameApi, "ScenEdit_AddReloadsToUnit")
      local stubSetUnit = trackStub(GameApi, "ScenEdit_SetUnit")
      local stubHideUnit = trackStub(Concealment, "hideUnit").returns(true)
      trackStub(math, "random").returns(1)

      MissileSystem.checkMissileSystemState(systemCtx, true, "Taiwan")

      assert.are.equal(constants.MISSILE_SYSTEM_STATE.REPOSITIONING, systemCtx.firingUnits["Firing Unit Alpha"].state)
      assert.stub(stubHideUnit).was.called(1)
      assert.are.same(hideCourse, stubSetUnit.calls[1].vals[1].course)
    end)

    it("should move SAM firing unit to firing point after reload in auto mode", function()
      local fpCourse = {
        { latitude = "N 25.20.00", longitude = "E 121.20.00" }
      }
      local systemCtx = createMockSystemCtx({
        name = "sam",
        reloadTime = 60,
        firingUnits = {
          ["Firing Unit Alpha"] = {
            name = "Firing Unit Alpha",
            state = constants.MISSILE_SYSTEM_STATE.RELOAD,
            reloadStartTime = 1000,
            resupplyUnit = "Ammo Sec, Alpha",
            weaponDBID = 1234,
            ammoThreshold = 60,
            operationalArea = {
              name = "OPAREA-1",
              RL = { { area = { "RP-001", "RP-002", "RP-003", "RP-004" } } },
              FP = { { course = fpCourse, area = { "FP-001", "FP-002", "FP-003", "FP-004" } } },
              HA = { { course = { { latitude = "N 25.30.00", longitude = "E 121.30.00" } } } }
            }
          }
        },
        resupplyUnits = {
          ["Ammo Sec, Alpha"] = {
            name = "Ammo Sec, Alpha",
            state = constants.MISSILE_SYSTEM_STATE.REPOSITIONING,
            wpnCurrent = 10,
            wpnDefault = 20,
            operationalArea = {
              name = "OPAREA-1",
              RL = { { area = { "RP-001", "RP-002", "RP-003", "RP-004" } } },
              mask = { area = { "MASK-001", "MASK-002", "MASK-003", "MASK-004" } }
            }
          }
        }
      })

      local firingUnit = {
        guid = "F1",
        name = "Firing Unit Alpha",
        side = "Taiwan",
        group = { unitlist = { "F1" } },
        inArea = function(_, area) return area[1] == "RP-001" end
      }
      local resupplyUnit = {
        guid = "R1",
        name = "Ammo Sec, Alpha",
        side = "Taiwan",
        inArea = function(_, area) return area[1] == "RP-001" end
      }

      trackStub(GameApi, "ScenEdit_CurrentTime").returns(1100)
      trackStub(GameApi, "ScenEdit_GetUnit").invokes(function(guidOrName)
        if guidOrName == "Firing Unit Alpha" then return firingUnit end
        if guidOrName == "F1" then return firingUnit end
        if guidOrName == "Ammo Sec, Alpha" then return resupplyUnit end
        return nil
      end)
      trackStub(GameUtils, "getWeaponInfo").returns({ availableWeapons = 2, maxWeapons = 10 })
      trackStub(GameApi, "ScenEdit_AddReloadsToUnit")
      local stubSetUnit = trackStub(GameApi, "ScenEdit_SetUnit")
      local stubHideUnit = trackStub(Concealment, "hideUnit").returns(true)
      trackStub(math, "random").returns(1)

      MissileSystem.checkMissileSystemState(systemCtx, true, "Taiwan")

      assert.are.equal(constants.MISSILE_SYSTEM_STATE.REPOSITIONING, systemCtx.firingUnits["Firing Unit Alpha"].state)
      assert.stub(stubHideUnit).was.called(1)
      assert.are.same(fpCourse, stubSetUnit.calls[1].vals[1].course)
    end)
  end)

  -- ==========================================================================
  -- initEventTriggers
  -- ==========================================================================

  describe("initEventTriggers", function()
    after_each(function()
      for _, s in ipairs(activeStubs) do s:revert() end
      activeStubs = {}
    end)

    it("should set area color for standard position zones regardless of side", function()
      local operationalAreas = {
        {
          name = "OPAREA-1",
          uShapeVertices = { "MASK-RP-1", "MASK-RP-2", "MASK-RP-3", "MASK-RP-4" },
          RL = {
            { area = { "RL-RP-1", "RL-RP-2", "RL-RP-3", "RL-RP-4" } }
          }
        }
      }
      local createdZones = {}

      trackStub(GameUtils, "getCachedSideConfig").returns({ enemySide = constants.SIDES.ENEMY })
      trackStub(GameUtils, "removeZones")
      trackStub(GameUtils, "removeEventTriggers")
      trackStub(GameUtils, "convertToRPArray").invokes(function(zone)
        return zone.area
      end)
      trackStub(GameApi, "ScenEdit_SetTrigger")
      trackStub(GameApi, "ScenEdit_SetEventTrigger")
      trackStub(GameApi, "ScenEdit_AddZone").invokes(function(_, zoneType, opts)
        local zone = {
          description = opts.description,
          area = opts.area,
          zoneType = zoneType
        }
        table.insert(createdZones, zone)
        return zone
      end)

      MissileSystem.initEventTriggers(
        operationalAreas,
        { constants.POSITION_TYPES.RELOAD_POINT },
        constants.SIDES.ENEMY
      )

      assert.are.equal(2, #createdZones)
      assert.are.equal("4dd9822b", createdZones[1].areacolor)
      assert.are.equal(constants.ZONE_TYPES.STANDARD, createdZones[1].zoneType)
    end)

    it("should create mask zone as standard zone and store converted area", function()
      local operationalArea = {
        name = "OPAREA-1",
        uShapeVertices = { "MASK-RP-1", "MASK-RP-2", "MASK-RP-3", "MASK-RP-4" },
        RL = {
          { area = { "RL-RP-1", "RL-RP-2", "RL-RP-3", "RL-RP-4" } }
        }
      }
      local maskZoneType
      local maskZone

      trackStub(GameUtils, "getCachedSideConfig").returns({ enemySide = constants.SIDES.ENEMY })
      trackStub(GameUtils, "removeZones")
      trackStub(GameUtils, "removeEventTriggers")
      trackStub(GameUtils, "convertToRPArray").invokes(function(zone)
        return { zone.description .. "-RP-1", zone.description .. "-RP-2" }
      end)
      trackStub(GameApi, "ScenEdit_SetTrigger")
      trackStub(GameApi, "ScenEdit_SetEventTrigger")
      trackStub(GameApi, "ScenEdit_AddZone").invokes(function(_, zoneType, opts)
        local zone = {
          description = opts.description,
          area = opts.area
        }
        if opts.description == constants.POSITION_TYPES.MASK .. "/" .. operationalArea.name then
          maskZoneType = zoneType
          maskZone = zone
        end
        return zone
      end)

      MissileSystem.initEventTriggers(
        { operationalArea },
        { constants.POSITION_TYPES.RELOAD_POINT },
        constants.SIDES.PLAYER
      )

      assert.are.equal(constants.ZONE_TYPES.STANDARD, maskZoneType)
      assert.are.equal("4dff6b6b", maskZone.areacolor)
      assert.are.same({
        constants.POSITION_TYPES.MASK .. "/" .. operationalArea.name .. "-RP-1",
        constants.POSITION_TYPES.MASK .. "/" .. operationalArea.name .. "-RP-2"
      }, operationalArea.mask.area)
    end)
  end)

  -- ==========================================================================
  -- initMissileSystemContexts
  -- ==========================================================================

  describe("initMissileSystemContexts", function()
    -- Positive: initializes firing unit contexts from config
    it("should deep copy firing unit descriptors and set reloadStartTime to nil", function()
      local groundForceCfg = {
        system1 = {
          firingUnits = {
            fu1 = { name = "FU-1", state = 0, reloadStartTime = 999 }
          },
          resupplyUnits = {},
          ammunitions = {}
        }
      }
      local groundForceCtx = {
        system1 = { firingUnits = {}, resupplyUnits = {}, ammunitions = {} }
      }

      MissileSystem.initMissileSystemContexts(groundForceCfg, groundForceCtx)

      local ctx = groundForceCtx.system1.firingUnits["FU-1"]
      assert.is_not_nil(ctx)
      assert.are.equal("FU-1", ctx.name)
      assert.is_nil(ctx.reloadStartTime)
    end)

    -- Positive: initializes resupply unit contexts from config
    it("should deep copy resupply unit descriptors and set reloadStartTime to nil", function()
      local groundForceCfg = {
        system1 = {
          firingUnits = {},
          resupplyUnits = {
            ru1 = { name = "RU-1", state = 0, reloadStartTime = 888 }
          },
          ammunitions = {}
        }
      }
      local groundForceCtx = {
        system1 = { firingUnits = {}, resupplyUnits = {}, ammunitions = {} }
      }

      MissileSystem.initMissileSystemContexts(groundForceCfg, groundForceCtx)

      local ctx = groundForceCtx.system1.resupplyUnits["RU-1"]
      assert.is_not_nil(ctx)
      assert.are.equal("RU-1", ctx.name)
      assert.is_nil(ctx.reloadStartTime)
    end)

    -- Positive: initializes ammunition contexts from config
    it("should deep copy ammunition descriptors into context", function()
      local groundForceCfg = {
        system1 = {
          firingUnits = {},
          resupplyUnits = {},
          ammunitions = {
            ammo1 = { name = "Ammo-1", wpnCurrent = 50 }
          }
        }
      }
      local groundForceCtx = {
        system1 = { firingUnits = {}, resupplyUnits = {}, ammunitions = {} }
      }

      MissileSystem.initMissileSystemContexts(groundForceCfg, groundForceCtx)

      local ctx = groundForceCtx.system1.ammunitions["Ammo-1"]
      assert.is_not_nil(ctx)
      assert.are.equal("Ammo-1", ctx.name)
      assert.are.equal(50, ctx.wpnCurrent)
    end)

    -- Positive: deep copy isolation
    it("should not share references between config and context", function()
      local groundForceCfg = {
        system1 = {
          firingUnits = {
            fu1 = { name = "FU-1", state = 0, operationalArea = { name = "OA-1" } }
          },
          resupplyUnits = {},
          ammunitions = {}
        }
      }
      local groundForceCtx = {
        system1 = { firingUnits = {}, resupplyUnits = {}, ammunitions = {} }
      }

      MissileSystem.initMissileSystemContexts(groundForceCfg, groundForceCtx)

      -- Mutating context should not affect config
      groundForceCtx.system1.firingUnits["FU-1"].operationalArea.name = "CHANGED"
      assert.are.equal("OA-1", groundForceCfg.system1.firingUnits.fu1.operationalArea.name)
    end)

    -- Positive: multiple systems
    it("should initialize contexts for multiple missile systems", function()
      local groundForceCfg = {
        sysA = {
          firingUnits = { a = { name = "A", state = 0 } },
          resupplyUnits = {},
          ammunitions = {}
        },
        sysB = {
          firingUnits = {},
          resupplyUnits = { b = { name = "B", state = 0 } },
          ammunitions = {}
        }
      }
      local groundForceCtx = {
        sysA = { firingUnits = {}, resupplyUnits = {}, ammunitions = {} },
        sysB = { firingUnits = {}, resupplyUnits = {}, ammunitions = {} }
      }

      MissileSystem.initMissileSystemContexts(groundForceCfg, groundForceCtx)

      assert.is_not_nil(groundForceCtx.sysA.firingUnits["A"])
      assert.is_not_nil(groundForceCtx.sysB.resupplyUnits["B"])
    end)
  end)

  -- ==========================================================================
  -- hideUnit
  -- ==========================================================================

  describe("hideUnit", function()
    after_each(function()
      for _, s in ipairs(activeStubs) do s:revert() end
      activeStubs = {}
    end)

    local function createHideUnitCtx()
      return {
        name = "TEL Alpha",
        operationalArea = {
          name = "OPAREA-1",
          mask = { area = { "MASK-001", "MASK-002", "MASK-003", "MASK-004" } }
        }
      }
    end

    local function createMockSide(filteredUnits)
      return {
        unitsInArea = function() return filteredUnits end
      }
    end

    it("should return false when no buildings found in mask area", function()
      local unitCtx = createHideUnitCtx()
      local unit = { guid = "U1", side = "China" }

      trackStub(GameApi, "VP_GetSide").returns(createMockSide(nil))

      local success, errorMsg = MissileSystem.hideUnit(unitCtx, unit)

      assert.is_false(success)
      assert.are.equal("No buildings found in mask area", errorMsg)
    end)

    it("should return false when no buildings can be retrieved", function()
      local unitCtx = createHideUnitCtx()
      local unit = { guid = "U1", side = "China" }

      trackStub(GameApi, "VP_GetSide").returns(createMockSide({ { guid = "B1" } }))
      trackStub(GameApi, "ScenEdit_GetUnit").returns(nil)

      local success, errorMsg = MissileSystem.hideUnit(unitCtx, unit)

      assert.is_false(success)
      assert.is_truthy(errorMsg:match("No available building"))
    end)

    it("should return false when all buildings are occupied", function()
      local unitCtx = createHideUnitCtx()
      local unit = { guid = "U1", side = "China" }
      local mockBuilding = {
        guid = "B1",
        cargo = { { cargo = { { guid = "OTHER" } } } }
      }

      trackStub(GameApi, "VP_GetSide").returns(createMockSide({ { guid = "B1" } }))
      trackStub(GameApi, "ScenEdit_GetUnit").returns(mockBuilding)

      local success, errorMsg = MissileSystem.hideUnit(unitCtx, unit)

      assert.is_false(success)
      assert.is_truthy(errorMsg:match("No available building"))
    end)

    it("should call loadCargo when building exists and return true", function()
      local unitCtx = createHideUnitCtx()
      local unit = { guid = "U1", side = "China" }
      local mockBuilding = { guid = "B1", name = "Building 1" }

      trackStub(GameApi, "VP_GetSide").returns(createMockSide({ { guid = "B1" } }))
      trackStub(GameApi, "ScenEdit_GetUnit").returns(mockBuilding)
      trackStub(math, "random").returns(1)
      local stubLoadCargo = trackStub(AmphibiousLogistics, "loadCargo")

      local success, errorMsg = MissileSystem.hideUnit(unitCtx, unit)

      assert.is_true(success)
      assert.is_nil(errorMsg)
      assert.stub(stubLoadCargo).was.called(1)
      assert.are.same(mockBuilding, stubLoadCargo.calls[1].vals[1])
      assert.are.same(unitCtx, stubLoadCargo.calls[1].vals[2])
      assert.are.equal("China", stubLoadCargo.calls[1].vals[3])
    end)

    it("should select a random building from the list", function()
      local unitCtx = createHideUnitCtx()
      local unit = { guid = "U1", side = "China" }
      local mockBuilding2 = { guid = "B2", name = "Building 2" }

      trackStub(GameApi, "VP_GetSide").returns(createMockSide({
        { guid = "B1" }, { guid = "B2" }, { guid = "B3" }
      }))
      trackStub(GameApi, "ScenEdit_GetUnit").returns(mockBuilding2)
      trackStub(math, "random").returns(2)
      local stubLoadCargo = trackStub(AmphibiousLogistics, "loadCargo")

      MissileSystem.hideUnit(unitCtx, unit)

      assert.stub(stubLoadCargo).was.called(1)
      assert.are.same(mockBuilding2, stubLoadCargo.calls[1].vals[1])
    end)
  end)

  -- ==========================================================================
  -- moveFromHideArea
  -- ==========================================================================

  describe("moveFromHideArea", function()
    after_each(function()
      for _, s in ipairs(activeStubs) do s:revert() end
      activeStubs = {}
    end)

    local function createMoveFromHideCtx()
      return {
        name = "TEL Alpha",
        operationalArea = {
          name = "OPAREA-1",
          mask = { area = { "MASK-001", "MASK-002", "MASK-003", "MASK-004" } }
        }
      }
    end

    local function createMockSide(filteredUnits)
      return {
        unitsInArea = function() return filteredUnits end
      }
    end

    it("should return false when no buildings found in mask area", function()
      local unitCtx = createMoveFromHideCtx()
      local unit = { guid = "U1", side = "China" }

      trackStub(GameApi, "VP_GetSide").returns(createMockSide(nil))

      local success, errorMsg = MissileSystem.moveFromHideArea(unitCtx, unit)

      assert.is_false(success)
      assert.are.equal("No buildings found in mask area", errorMsg)
    end)

    it("should unload cargo when unit is found in building", function()
      local unitCtx = createMoveFromHideCtx()
      local unit = { guid = "U1", side = "China" }
      local mockBuilding = {
        guid = "B1",
        cargo = { { cargo = { { guid = "U1" } } } }
      }

      trackStub(GameApi, "VP_GetSide").returns(createMockSide({ { guid = "B1" } }))
      trackStub(GameApi, "ScenEdit_GetUnit").returns(mockBuilding)
      local stubUnload = trackStub(GameApi, "ScenEdit_UnloadCargo")

      local success = MissileSystem.moveFromHideArea(unitCtx, unit)

      assert.is_true(success)
      assert.stub(stubUnload).was.called(1)
      assert.are.equal("B1", stubUnload.calls[1].vals[1])
    end)

    it("should not unload when unit is not in building cargo", function()
      local unitCtx = createMoveFromHideCtx()
      local unit = { guid = "U1", side = "China" }
      local mockBuilding = {
        guid = "B1",
        cargo = { { cargo = { { guid = "OTHER" } } } }
      }

      trackStub(GameApi, "VP_GetSide").returns(createMockSide({ { guid = "B1" } }))
      trackStub(GameApi, "ScenEdit_GetUnit").returns(mockBuilding)
      local stubUnload = trackStub(GameApi, "ScenEdit_UnloadCargo")

      local success = MissileSystem.moveFromHideArea(unitCtx, unit)

      assert.is_true(success)
      assert.stub(stubUnload).was_not.called()
    end)

    it("should unload all group units from buildings", function()
      local unitCtx = createMoveFromHideCtx()
      local unit = { guid = "G1", side = "China", group = { unitlist = { "U1", "U2" } } }

      local mockBuilding1 = {
        guid = "B1",
        cargo = { { cargo = { { guid = "U1" } } } }
      }
      local mockBuilding2 = {
        guid = "B2",
        cargo = { { cargo = { { guid = "U2" } } } }
      }

      trackStub(GameApi, "VP_GetSide").returns(createMockSide({ { guid = "B1" }, { guid = "B2" } }))
      trackStub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
        if guid == "B1" then return mockBuilding1 end
        if guid == "B2" then return mockBuilding2 end
        return nil
      end)
      local stubUnload = trackStub(GameApi, "ScenEdit_UnloadCargo")

      local success = MissileSystem.moveFromHideArea(unitCtx, unit)

      assert.is_true(success)
      assert.stub(stubUnload).was.called(2)
      assert.are.equal("B1", stubUnload.calls[1].vals[1])
      assert.are.equal("B2", stubUnload.calls[2].vals[1])
    end)

    it("should skip buildings that cannot be retrieved", function()
      local unitCtx = createMoveFromHideCtx()
      local unit = { guid = "U1", side = "China" }

      trackStub(GameApi, "VP_GetSide").returns(createMockSide({ { guid = "B1" }, { guid = "B2" } }))
      trackStub(GameApi, "ScenEdit_GetUnit").returns(nil)
      local stubUnload = trackStub(GameApi, "ScenEdit_UnloadCargo")

      local success = MissileSystem.moveFromHideArea(unitCtx, unit)

      assert.is_true(success)
      assert.stub(stubUnload).was_not.called()
    end)
  end)
end)
