-- MissileSystem Ammo And Meeting Unit Tests
---@diagnostic disable: undefined-field
local stub = require("luassert.stub")
local Ammo = require("src.modules.missileSystem.ammo")
local Meeting = require("src.modules.missileSystem.meeting")
local GameApi = require("src.utils.gameApi")
local GameUtils = require("src.utils.gameUtils")
local Logger = require("src.utils.logger")
local constants = require("src.core.constants")

describe("MissileSystem Ammo And Meeting", function()
  local activeStubs
  local function trackStub(obj, method)
    local s = stub(obj, method)
    table.insert(activeStubs, s)
    return s
  end

  local function makeSystemCtx(overrides)
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
          wpnCurrent = 10,
          wpnDefault = 20,
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
  -- hasMetResupplyUnit
  -- ============================================================================

  describe("hasMetResupplyUnit", function()
    local mockSystemCtx

    before_each(function()
      mockSystemCtx = makeSystemCtx()
    end)

    -- Boundary: returns false when unit is unknown
    it("should return false when unit name not in firingUnits or resupplyUnits", function()
      local unit = { guid = "UNIT-001", name = "Unknown Unit", side = "Taiwan" }
      local hasMet, ctx = Meeting.hasMetResupplyUnit(mockSystemCtx, unit, true)
      assert.is_false(hasMet)
      assert.is_nil(ctx)
    end)

    -- Boundary: returns false when firing unit is not in any reload area
    it("should return false when unit is firing unit but not in any RL area", function()
      local firingUnit = {
        guid = "FIRING-001",
        name = "Firing Unit Alpha",
        side = "Taiwan",
        inArea = function() return false end
      }

      local hasMet, ctx = Meeting.hasMetResupplyUnit(mockSystemCtx, firingUnit, true)
      assert.is_false(hasMet)
      assert.is_nil(ctx)
    end)

    -- Boundary: returns false when resupply unit is not in any reload area
    it("should return false when unit is resupply unit but not in any RL area", function()
      local resupplyUnit = {
        guid = "RESUPPLY-001",
        name = "Ammo Sec, Alpha",
        side = "Taiwan",
        inArea = function() return false end
      }

      local hasMet, ctx = Meeting.hasMetResupplyUnit(mockSystemCtx, resupplyUnit, true)
      assert.is_false(hasMet)
      assert.is_nil(ctx)
    end)

    -- Positive: returns true when firing unit meets resupply unit in same area
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

      local hasMet, ctx = Meeting.hasMetResupplyUnit(mockSystemCtx, firingUnit, true)
      assert.is_true(hasMet)
      assert.are.equal("Firing Unit Alpha", ctx.name)
    end)

    -- Positive: returns true when resupply unit meets firing unit in same area
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

      local hasMet, ctx = Meeting.hasMetResupplyUnit(mockSystemCtx, resupplyUnit, true)
      assert.is_true(hasMet)
      assert.are.equal("Firing Unit Alpha", ctx.name)
    end)

    -- Negative: returns false when units are in different areas
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

      local hasMet, ctx = Meeting.hasMetResupplyUnit(mockSystemCtx, firingUnit, true)
      assert.is_false(hasMet)
      assert.is_nil(ctx)
    end)

    -- Negative: rejects STATIC state in auto mode
    it("should not match when state is STATIC in auto mode", function()
      mockSystemCtx.firingUnits["Firing Unit Alpha"].state = constants.MISSILE_SYSTEM_STATE.STATIC

      local firingUnit = {
        guid = "FIRING-001",
        name = "Firing Unit Alpha",
        side = "Taiwan",
        inArea = function(_, area) return area[1] == "RP-001" end
      }

      local hasMet, ctx = Meeting.hasMetResupplyUnit(mockSystemCtx, firingUnit, true)
      assert.is_false(hasMet)
      assert.is_nil(ctx)
    end)

    -- Positive: allows STATIC state in manual mode
    it("should match when state is STATIC in manual mode", function()
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

      local hasMet, ctx = Meeting.hasMetResupplyUnit(mockSystemCtx, firingUnit, false)
      assert.is_true(hasMet)
      assert.is_not_nil(ctx)
    end)
  end)

  -- ============================================================================
  -- hasMetAmmoDepot
  -- ============================================================================

  describe("hasMetAmmoDepot", function()
    local mockSystemCtx

    before_each(function()
      mockSystemCtx = makeSystemCtx({
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

    -- Boundary: returns false when unit is unknown
    it("should return false when unit name not in resupplyUnits", function()
      local unit = { guid = "UNIT-001", name = "Unknown Unit", side = "China" }
      local hasMet, ctx = Meeting.hasMetAmmoDepot(mockSystemCtx, unit, true)
      assert.is_false(hasMet)
      assert.is_nil(ctx)
    end)

    -- Boundary: returns false when resupply unit is not in any AHA area
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

      local hasMet, ctx = Meeting.hasMetAmmoDepot(mockSystemCtx, resupplyUnit, true)
      assert.is_false(hasMet)
      assert.is_nil(ctx)
    end)

    -- Positive: returns true when resupply unit meets ammo depot in same AHA
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

      local hasMet, ctx = Meeting.hasMetAmmoDepot(mockSystemCtx, resupplyUnit, true)
      assert.is_true(hasMet)
      assert.are.equal("Ammo Sec, Alpha", ctx.name)
    end)

    -- Negative: returns false when resupply unit and ammo depot are in different areas
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

      local hasMet, ctx = Meeting.hasMetAmmoDepot(mockSystemCtx, resupplyUnit, true)
      assert.is_false(hasMet)
      assert.is_nil(ctx)
    end)

    -- Negative: returns false when ammunition depot does not exist
    it("should return false when ammunition depot does not exist", function()
      local resupplyUnit = {
        guid = "RESUPPLY-001",
        name = "Ammo Sec, Alpha",
        side = "China",
        inArea = function(_, area) return area[1] == "RP-101" end
      }

      trackStub(GameApi, "ScenEdit_GetUnit").returns(nil)

      local hasMet, ctx = Meeting.hasMetAmmoDepot(mockSystemCtx, resupplyUnit, true)
      assert.is_false(hasMet)
      assert.is_nil(ctx)
    end)

    -- Negative: rejects STATIC state in auto mode
    it("should not match when state is STATIC in auto mode", function()
      mockSystemCtx.resupplyUnits["Ammo Sec, Alpha"].state = constants.MISSILE_SYSTEM_STATE.STATIC

      local resupplyUnit = {
        guid = "RESUPPLY-001",
        name = "Ammo Sec, Alpha",
        side = "China",
        inArea = function(_, area) return area[1] == "RP-101" end
      }

      local hasMet, ctx = Meeting.hasMetAmmoDepot(mockSystemCtx, resupplyUnit, true)
      assert.is_false(hasMet)
      assert.is_nil(ctx)
    end)

    -- Positive: allows STATIC state in manual mode
    it("should match when state is STATIC in manual mode", function()
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

      local hasMet, ctx = Meeting.hasMetAmmoDepot(mockSystemCtx, resupplyUnit, false)
      assert.is_true(hasMet)
      assert.is_not_nil(ctx)
    end)
  end)
end)
