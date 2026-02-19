-- MissileSystem Unit Tests
---@diagnostic disable: undefined-field
local MissileSystem = require("src.modules.missileSystem")
local GameApi = require("src.utils.gameApi")
local GameUtils = require("src.utils.gameUtils")
local constants = require("src.core.constants")

describe("MissileSystem", function()
  describe("isLowAmmo", function()
    local stubGetUnit, stubGetWeaponInfo

    after_each(function()
      if stubGetUnit then stubGetUnit:revert() end
      if stubGetWeaponInfo then stubGetWeaponInfo:revert() end
      stubGetUnit, stubGetWeaponInfo = nil, nil
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
      stubGetUnit = stub(GameApi, "ScenEdit_GetUnit").returns(unit)
      stubGetWeaponInfo = stub(GameUtils, "getWeaponInfo").returns({ availableWeapons = 0, maxWeapons = 0 })

      assert.is_false(MissileSystem.isLowAmmo(unit, 50, 1234))
    end)

    it("should return true when ammo percentage is equal to threshold", function()
      local unit = { guid = "UNIT-001" }
      stubGetUnit = stub(GameApi, "ScenEdit_GetUnit").returns(unit)
      stubGetWeaponInfo = stub(GameUtils, "getWeaponInfo").returns({ availableWeapons = 5, maxWeapons = 10 })

      assert.is_true(MissileSystem.isLowAmmo(unit, 50, 1234))
    end)

    it("should return false when ammo percentage is above threshold", function()
      local unit = { guid = "UNIT-001" }
      stubGetUnit = stub(GameApi, "ScenEdit_GetUnit").returns(unit)
      stubGetWeaponInfo = stub(GameUtils, "getWeaponInfo").returns({ availableWeapons = 6, maxWeapons = 10 })

      assert.is_false(MissileSystem.isLowAmmo(unit, 50, 1234))
    end)

    it("should sum ammo across group units", function()
      local unit = { guid = "GROUP-001", group = { unitlist = { "U1", "U2" } } }
      stubGetUnit = stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
        if guid == "U1" then return { guid = "U1" } end
        if guid == "U2" then return { guid = "U2" } end
        return nil
      end)
      stubGetWeaponInfo = stub(GameUtils, "getWeaponInfo").invokes(function(u)
        if u.guid == "U1" then return { availableWeapons = 2, maxWeapons = 10 } end
        if u.guid == "U2" then return { availableWeapons = 1, maxWeapons = 10 } end
        return { availableWeapons = 0, maxWeapons = 0 }
      end)

      assert.is_true(MissileSystem.isLowAmmo(unit, 15, 1234))
    end)

    it("should ignore missing units in group list", function()
      local unit = { guid = "GROUP-001", group = { unitlist = { "U1", "U2" } } }
      stubGetUnit = stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
        if guid == "U1" then return { guid = "U1" } end
        return nil
      end)
      stubGetWeaponInfo = stub(GameUtils, "getWeaponInfo").returns({ availableWeapons = 5, maxWeapons = 10 })

      assert.is_true(MissileSystem.isLowAmmo(unit, 50, 1234))
    end)

    it("should pass weaponDBID to GameUtils.getWeaponInfo", function()
      local unit = { guid = "UNIT-001" }
      stubGetUnit = stub(GameApi, "ScenEdit_GetUnit").returns(unit)
      stubGetWeaponInfo = stub(GameUtils, "getWeaponInfo").returns({ availableWeapons = 1, maxWeapons = 10 })

      MissileSystem.isLowAmmo(unit, 90, 4321)

      assert.stub(stubGetWeaponInfo).was.called()
      assert.are.equal(4321, stubGetWeaponInfo.calls[1].vals[2])
    end)
  end)

  describe("isMetWithResupplyUnits", function()
    local mockSystemCtx
    local stubGetUnit, stubWeaponAllocation

    before_each(function()
      mockSystemCtx = {
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
        }
      }
    end)

    after_each(function()
      if stubGetUnit then stubGetUnit:revert() end
      if stubWeaponAllocation then stubWeaponAllocation:revert() end
      stubGetUnit, stubWeaponAllocation = nil, nil
    end)

    -- Boundary cases
    it("should return false when unit name not in firingUnits or resupplyUnits", function()
      local unit = { guid = "UNIT-001", name = "Unknown Unit", side = "Taiwan" }
      local isMet, ctx = MissileSystem.isMetWithResupplyUnits(mockSystemCtx, unit, true)
      assert.is_false(isMet)
      assert.is_nil(ctx)
    end)

    it("should return false when unit is firing unit but not in any RL area", function()
      local firingUnit = {
        guid = "FIRING-001",
        name = "Firing Unit Alpha",
        side = "Taiwan",
        inArea = function() return false end
      }

      local isMet, ctx = MissileSystem.isMetWithResupplyUnits(mockSystemCtx, firingUnit, true)
      assert.is_false(isMet)
      assert.is_nil(ctx)
    end)

    it("should return false when unit is resupply unit but not in any RL area", function()
      local resupplyUnit = {
        guid = "RESUPPLY-001",
        name = "Ammo Sec, Alpha",
        side = "Taiwan",
        inArea = function() return false end
      }

      local isMet, ctx = MissileSystem.isMetWithResupplyUnits(mockSystemCtx, resupplyUnit, true)
      assert.is_false(isMet)
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

      stubGetUnit = stub(GameApi, "ScenEdit_GetUnit").invokes(function(guidOrName)
        if guidOrName == "Ammo Sec, Alpha" then return mockResupplyUnit end
        if guidOrName == "FIRING-001" then return firingUnit end
        return nil
      end)
      stubWeaponAllocation = stub(GameApi, "ScenEdit_WeaponAllocation").returns({})

      local isMet, ctx = MissileSystem.isMetWithResupplyUnits(mockSystemCtx, firingUnit, true)
      assert.is_true(isMet)
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

      stubGetUnit = stub(GameApi, "ScenEdit_GetUnit").invokes(function(guidOrName)
        if guidOrName == "Firing Unit Alpha" then return mockFiringUnit end
        if guidOrName == "FIRING-001" then return mockFiringUnit end
        return nil
      end)
      stubWeaponAllocation = stub(GameApi, "ScenEdit_WeaponAllocation").returns({})

      local isMet, ctx = MissileSystem.isMetWithResupplyUnits(mockSystemCtx, resupplyUnit, true)
      assert.is_true(isMet)
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

      stubGetUnit = stub(GameApi, "ScenEdit_GetUnit").invokes(function(guidOrName)
        if guidOrName == "Ammo Sec, Alpha" then return mockResupplyUnit end
        if guidOrName == "FIRING-001" then return firingUnit end
        return nil
      end)

      local isMet, ctx = MissileSystem.isMetWithResupplyUnits(mockSystemCtx, firingUnit, true)
      assert.is_false(isMet)
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

      local isMet, ctx = MissileSystem.isMetWithResupplyUnits(mockSystemCtx, firingUnit, true)
      assert.is_false(isMet)
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

      stubGetUnit = stub(GameApi, "ScenEdit_GetUnit").invokes(function(guidOrName)
        if guidOrName == "Ammo Sec, Alpha" then return mockResupplyUnit end
        if guidOrName == "FIRING-001" then return firingUnit end
        return nil
      end)
      stubWeaponAllocation = stub(GameApi, "ScenEdit_WeaponAllocation").returns({})

      local isMet, ctx = MissileSystem.isMetWithResupplyUnits(mockSystemCtx, firingUnit, false)
      assert.is_true(isMet)
      assert.is_not_nil(ctx)
    end)
  end)

  describe("reload", function()
    local stubGetUnit, stubAddReloads, stubGetWeaponInfo

    after_each(function()
      if stubGetUnit then stubGetUnit:revert() end
      if stubAddReloads then stubAddReloads:revert() end
      if stubGetWeaponInfo then stubGetWeaponInfo:revert() end
      stubGetUnit, stubAddReloads, stubGetWeaponInfo = nil, nil, nil
    end)

    it("should return 0 when firing unit not found", function()
      local firingUnitCtx = {
        name = "Firing Unit Alpha",
        state = constants.MISSILE_SYSTEM_STATE.RELOAD,
        reloadStartTime = 123
      }
      local resupplyUnitCtx = { wpnCurrent = 10 }

      stubGetUnit = stub(GameApi, "ScenEdit_GetUnit").returns(nil)

      local loaded = MissileSystem.reload(firingUnitCtx, resupplyUnitCtx, 1234, "Taiwan")
      assert.are.equal(0, loaded)
      assert.are.equal(constants.MISSILE_SYSTEM_STATE.RELOAD, firingUnitCtx.state)
      assert.are.equal(123, firingUnitCtx.reloadStartTime)
      assert.are.equal(10, resupplyUnitCtx.wpnCurrent)
    end)

    it("should reload single unit and consume resupply ammo", function()
      local firingUnitCtx = {
        name = "Firing Unit Alpha",
        state = constants.MISSILE_SYSTEM_STATE.RELOAD,
        reloadStartTime = 456
      }
      local resupplyUnitCtx = { wpnCurrent = 5 }

      local firingUnit = { guid = "F1", side = "Taiwan" }
      stubGetUnit = stub(GameApi, "ScenEdit_GetUnit").invokes(function(guidOrName)
        if guidOrName == "Firing Unit Alpha" then return firingUnit end
        if guidOrName == "F1" then return firingUnit end
        return nil
      end)
      stubGetWeaponInfo = stub(GameUtils, "getWeaponInfo").returns({ maxWeapons = 10, availableWeapons = 7 })
      stubAddReloads = stub(GameApi, "ScenEdit_AddReloadsToUnit")

      local loaded = MissileSystem.reload(firingUnitCtx, resupplyUnitCtx, 1234, "Taiwan")
      assert.are.equal(3, loaded)
      assert.are.equal(2, resupplyUnitCtx.wpnCurrent)
      assert.are.equal(constants.MISSILE_SYSTEM_STATE.STATIC, firingUnitCtx.state)
      assert.is_nil(firingUnitCtx.reloadStartTime)
      assert.stub(stubAddReloads).was.called(1)
      assert.are.equal("F1", stubAddReloads.calls[1].vals[1].guid)
      assert.are.equal(1234, stubAddReloads.calls[1].vals[1].wpn_dbid)
      assert.are.equal(3, stubAddReloads.calls[1].vals[1].number)
    end)

    it("should reload group units and cap by resupply ammo", function()
      local firingUnitCtx = {
        name = "Firing Unit Alpha",
        state = constants.MISSILE_SYSTEM_STATE.RELOAD,
        reloadStartTime = 789
      }
      local resupplyUnitCtx = { wpnCurrent = 5 }

      local firingUnit = { guid = "G1", side = "Taiwan", group = { unitlist = { "U1", "U2" } } }
      stubGetUnit = stub(GameApi, "ScenEdit_GetUnit").invokes(function(guidOrName)
        if guidOrName == "Firing Unit Alpha" then return firingUnit end
        if guidOrName == "U1" then return { guid = "U1", side = "Taiwan" } end
        if guidOrName == "U2" then return { guid = "U2", side = "Taiwan" } end
        return nil
      end)
      stubGetWeaponInfo = stub(GameUtils, "getWeaponInfo").invokes(function(unit)
        if unit.guid == "U1" then
          return { maxWeapons = 10, availableWeapons = 6 } -- needs 4
        end
        return { maxWeapons = 10, availableWeapons = 6 }   -- needs 4
      end)
      stubAddReloads = stub(GameApi, "ScenEdit_AddReloadsToUnit")

      local loaded = MissileSystem.reload(firingUnitCtx, resupplyUnitCtx, 5678, "Taiwan")
      assert.are.equal(5, loaded)
      assert.are.equal(0, resupplyUnitCtx.wpnCurrent)
      assert.stub(stubAddReloads).was.called(2)
      assert.are.equal("U1", stubAddReloads.calls[1].vals[1].guid)
      assert.are.equal(4, stubAddReloads.calls[1].vals[1].number)
      assert.are.equal("U2", stubAddReloads.calls[2].vals[1].guid)
      assert.are.equal(1, stubAddReloads.calls[2].vals[1].number)
    end)
  end)

  describe("isMetWithAmmoDepot", function()
    local mockSystemCtx
    local stubGetUnit

    before_each(function()
      mockSystemCtx = {
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
      }
    end)

    after_each(function()
      if stubGetUnit then stubGetUnit:revert() end
      stubGetUnit = nil
    end)

    -- Boundary cases
    it("should return false when unit name not in resupplyUnits", function()
      local unit = { guid = "UNIT-001", name = "Unknown Unit", side = "China" }
      local isMet, ctx = MissileSystem.isMetWithAmmoDepot(mockSystemCtx, unit, true)
      assert.is_false(isMet)
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

      stubGetUnit = stub(GameApi, "ScenEdit_GetUnit").invokes(function(guidOrName)
        if guidOrName == "Ammo Revetment, Alpha" then return mockAmmoDepot end
        return nil
      end)

      local isMet, ctx = MissileSystem.isMetWithAmmoDepot(mockSystemCtx, resupplyUnit, true)
      assert.is_false(isMet)
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

      stubGetUnit = stub(GameApi, "ScenEdit_GetUnit").invokes(function(guidOrName)
        if guidOrName == "Ammo Revetment, Alpha" then return mockAmmoDepot end
        return nil
      end)

      local isMet, ctx = MissileSystem.isMetWithAmmoDepot(mockSystemCtx, resupplyUnit, true)
      assert.is_true(isMet)
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

      stubGetUnit = stub(GameApi, "ScenEdit_GetUnit").invokes(function(guidOrName)
        if guidOrName == "Ammo Revetment, Alpha" then return mockAmmoDepot end
        return nil
      end)

      local isMet, ctx = MissileSystem.isMetWithAmmoDepot(mockSystemCtx, resupplyUnit, true)
      assert.is_false(isMet)
      assert.is_nil(ctx)
    end)

    it("should return false when ammunition depot does not exist", function()
      local resupplyUnit = {
        guid = "RESUPPLY-001",
        name = "Ammo Sec, Alpha",
        side = "China",
        inArea = function(_, area) return area[1] == "RP-101" end
      }

      stubGetUnit = stub(GameApi, "ScenEdit_GetUnit").returns(nil)

      local isMet, ctx = MissileSystem.isMetWithAmmoDepot(mockSystemCtx, resupplyUnit, true)
      assert.is_false(isMet)
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

      local isMet, ctx = MissileSystem.isMetWithAmmoDepot(mockSystemCtx, resupplyUnit, true)
      assert.is_false(isMet)
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

      stubGetUnit = stub(GameApi, "ScenEdit_GetUnit").invokes(function(guidOrName)
        if guidOrName == "Ammo Revetment, Alpha" then return mockAmmoDepot end
        return nil
      end)

      local isMet, ctx = MissileSystem.isMetWithAmmoDepot(mockSystemCtx, resupplyUnit, false)
      assert.is_true(isMet)
      assert.is_not_nil(ctx)
    end)
  end)

  describe("transferAmmunition", function()
    -- Boundary cases
    it("should not transfer when ammo depot has no ammunition", function()
      local resupplyUnitCtx = {
        name = "Ammo Sec, Alpha",
        state = constants.MISSILE_SYSTEM_STATE.REPOSITIONING,
        reloadStartTime = 12345,
        wpnCurrent = 5,
        wpnDefault = 20
      }
      local ammoDepotCtx = { wpnCurrent = 0 }

      MissileSystem.transferAmmunition(resupplyUnitCtx, ammoDepotCtx)

      assert.are.equal(5, resupplyUnitCtx.wpnCurrent)
      assert.are.equal(0, ammoDepotCtx.wpnCurrent)
      assert.are.equal(constants.MISSILE_SYSTEM_STATE.STATIC, resupplyUnitCtx.state)
      assert.is_nil(resupplyUnitCtx.reloadStartTime)
    end)

    it("should not transfer when resupply unit is already full", function()
      local resupplyUnitCtx = {
        name = "Ammo Sec, Alpha",
        state = constants.MISSILE_SYSTEM_STATE.REPOSITIONING,
        reloadStartTime = 12345,
        wpnCurrent = 20,
        wpnDefault = 20
      }
      local ammoDepotCtx = { wpnCurrent = 100 }

      MissileSystem.transferAmmunition(resupplyUnitCtx, ammoDepotCtx)

      assert.are.equal(20, resupplyUnitCtx.wpnCurrent)
      assert.are.equal(100, ammoDepotCtx.wpnCurrent)
      assert.are.equal(constants.MISSILE_SYSTEM_STATE.STATIC, resupplyUnitCtx.state)
      assert.is_nil(resupplyUnitCtx.reloadStartTime)
    end)

    it("should not transfer when resupply unit exceeds default", function()
      local resupplyUnitCtx = {
        name = "Ammo Sec, Alpha",
        state = constants.MISSILE_SYSTEM_STATE.REPOSITIONING,
        reloadStartTime = 12345,
        wpnCurrent = 25,
        wpnDefault = 20
      }
      local ammoDepotCtx = { wpnCurrent = 100 }

      MissileSystem.transferAmmunition(resupplyUnitCtx, ammoDepotCtx)

      assert.are.equal(25, resupplyUnitCtx.wpnCurrent)
      assert.are.equal(100, ammoDepotCtx.wpnCurrent)
    end)

    -- Normal cases
    it("should transfer full deficit when ammo depot has enough", function()
      local resupplyUnitCtx = {
        name = "Ammo Sec, Alpha",
        state = constants.MISSILE_SYSTEM_STATE.REPOSITIONING,
        reloadStartTime = 12345,
        wpnCurrent = 5,
        wpnDefault = 20
      }
      local ammoDepotCtx = { wpnCurrent = 100 }

      MissileSystem.transferAmmunition(resupplyUnitCtx, ammoDepotCtx)

      assert.are.equal(20, resupplyUnitCtx.wpnCurrent)
      assert.are.equal(85, ammoDepotCtx.wpnCurrent)
      assert.are.equal(constants.MISSILE_SYSTEM_STATE.STATIC, resupplyUnitCtx.state)
      assert.is_nil(resupplyUnitCtx.reloadStartTime)
    end)

    it("should transfer only available ammo when depot has insufficient", function()
      local resupplyUnitCtx = {
        name = "Ammo Sec, Alpha",
        state = constants.MISSILE_SYSTEM_STATE.REPOSITIONING,
        reloadStartTime = 12345,
        wpnCurrent = 5,
        wpnDefault = 20
      }
      local ammoDepotCtx = { wpnCurrent = 10 }

      MissileSystem.transferAmmunition(resupplyUnitCtx, ammoDepotCtx)

      assert.are.equal(15, resupplyUnitCtx.wpnCurrent)
      assert.are.equal(0, ammoDepotCtx.wpnCurrent)
      assert.are.equal(constants.MISSILE_SYSTEM_STATE.STATIC, resupplyUnitCtx.state)
      assert.is_nil(resupplyUnitCtx.reloadStartTime)
    end)

    it("should transfer exact deficit when depot matches deficit exactly", function()
      local resupplyUnitCtx = {
        name = "Ammo Sec, Alpha",
        state = constants.MISSILE_SYSTEM_STATE.REPOSITIONING,
        reloadStartTime = 12345,
        wpnCurrent = 12,
        wpnDefault = 20
      }
      local ammoDepotCtx = { wpnCurrent = 8 }

      MissileSystem.transferAmmunition(resupplyUnitCtx, ammoDepotCtx)

      assert.are.equal(20, resupplyUnitCtx.wpnCurrent)
      assert.are.equal(0, ammoDepotCtx.wpnCurrent)
    end)
  end)

  describe("moveToFiringPoint", function()
    local stubGetUnit, stubSetUnit, stubSetDoctrine, stubRandom

    after_each(function()
      if stubGetUnit then stubGetUnit:revert() end
      if stubSetUnit then stubSetUnit:revert() end
      if stubSetDoctrine then stubSetDoctrine:revert() end
      if stubRandom then stubRandom:revert() end
      stubGetUnit, stubSetUnit, stubSetDoctrine, stubRandom = nil, nil, nil, nil
    end)

    -- State transitions
    it("should set state to REPOSITIONING", function()
      local firingUnitCtx = {
        name = "Firing Unit Alpha",
        state = constants.MISSILE_SYSTEM_STATE.STATIC,
        operationalArea = {
          name = "OPAREA-1",
          FP = { { course = { { latitude = "N 25.00.00", longitude = "E 121.00.00" } } } }
        }
      }
      local firingUnit = { guid = "F1" }

      stubRandom = stub(math, "random").returns(1)
      stubGetUnit = stub(GameApi, "ScenEdit_GetUnit").returns(firingUnit)
      stubSetUnit = stub(GameApi, "ScenEdit_SetUnit")

      MissileSystem.moveToFiringPoint(firingUnitCtx, firingUnit)

      assert.are.equal(constants.MISSILE_SYSTEM_STATE.REPOSITIONING, firingUnitCtx.state)
    end)

    -- Return value tests
    it("should return true when move is successful", function()
      local firingUnitCtx = {
        name = "Firing Unit Alpha",
        state = constants.MISSILE_SYSTEM_STATE.STATIC,
        operationalArea = {
          name = "OPAREA-1",
          FP = { { course = { { latitude = "N 25.00.00", longitude = "E 121.00.00" } } } }
        }
      }
      local firingUnit = { guid = "F1" }

      stubRandom = stub(math, "random").returns(1)
      stubGetUnit = stub(GameApi, "ScenEdit_GetUnit").returns(firingUnit)
      stubSetUnit = stub(GameApi, "ScenEdit_SetUnit")

      local result = MissileSystem.moveToFiringPoint(firingUnitCtx, firingUnit)

      assert.is_true(result)
    end)

    it("should return false when FP positions array is empty", function()
      local firingUnitCtx = {
        name = "Firing Unit Alpha",
        state = constants.MISSILE_SYSTEM_STATE.STATIC,
        operationalArea = {
          name = "OPAREA-1",
          FP = {}
        }
      }
      local firingUnit = { guid = "F1" }

      local result = MissileSystem.moveToFiringPoint(firingUnitCtx, firingUnit)

      assert.is_false(result)
      -- State should still be set to REPOSITIONING before the check
      assert.are.equal(constants.MISSILE_SYSTEM_STATE.REPOSITIONING, firingUnitCtx.state)
    end)

    it("should return false when position has no course", function()
      local firingUnitCtx = {
        name = "Firing Unit Alpha",
        state = constants.MISSILE_SYSTEM_STATE.STATIC,
        operationalArea = {
          name = "OPAREA-1",
          FP = { { area = { "RP-001" } } } -- no course field
        }
      }
      local firingUnit = { guid = "F1" }

      stubRandom = stub(math, "random").returns(1)

      local result = MissileSystem.moveToFiringPoint(firingUnitCtx, firingUnit)

      assert.is_false(result)
    end)

    -- Unit movement
    it("should set unit properties for single unit", function()
      local firingUnitCtx = {
        name = "Firing Unit Alpha",
        state = constants.MISSILE_SYSTEM_STATE.STATIC,
        operationalArea = {
          name = "OPAREA-1",
          FP = { { course = { { latitude = "N 25.00.00", longitude = "E 121.00.00" } } } }
        }
      }
      local firingUnit = { guid = "F1", side = "Taiwan" }

      stubRandom = stub(math, "random").returns(1)
      stubGetUnit = stub(GameApi, "ScenEdit_GetUnit").returns(firingUnit)
      stubSetUnit = stub(GameApi, "ScenEdit_SetUnit")

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
      local firingUnitCtx = {
        name = "Firing Unit Alpha",
        state = constants.MISSILE_SYSTEM_STATE.STATIC,
        operationalArea = {
          name = "OPAREA-1",
          FP = { { course = expectedCourse } }
        }
      }
      local firingUnit = { guid = "F1", side = "Taiwan" }

      stubRandom = stub(math, "random").returns(1)
      stubGetUnit = stub(GameApi, "ScenEdit_GetUnit").returns(firingUnit)
      stubSetUnit = stub(GameApi, "ScenEdit_SetUnit")

      MissileSystem.moveToFiringPoint(firingUnitCtx, firingUnit)

      assert.are.same(expectedCourse, stubSetUnit.calls[1].vals[1].course)
    end)

    it("should iterate through all units in group", function()
      local firingUnitCtx = {
        name = "Firing Unit Alpha",
        state = constants.MISSILE_SYSTEM_STATE.STATIC,
        operationalArea = {
          name = "OPAREA-1",
          FP = { { course = { { latitude = "N 25.00.00", longitude = "E 121.00.00" } } } }
        }
      }
      local firingUnit = {
        guid = "GROUP-001",
        side = "Taiwan",
        group = { unitlist = { "U1", "U2", "U3" } }
      }

      stubRandom = stub(math, "random").returns(1)
      stubGetUnit = stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
        if guid == "U1" then return { guid = "U1", side = "Taiwan" } end
        if guid == "U2" then return { guid = "U2", side = "Taiwan" } end
        if guid == "U3" then return { guid = "U3", side = "Taiwan" } end
        return nil
      end)
      stubSetUnit = stub(GameApi, "ScenEdit_SetUnit")

      MissileSystem.moveToFiringPoint(firingUnitCtx, firingUnit)

      assert.stub(stubSetUnit).was.called(3)
      assert.are.equal("U1", stubSetUnit.calls[1].vals[1].guid)
      assert.are.equal("U2", stubSetUnit.calls[2].vals[1].guid)
      assert.are.equal("U3", stubSetUnit.calls[3].vals[1].guid)
    end)

    it("should skip nil units in group list", function()
      local firingUnitCtx = {
        name = "Firing Unit Alpha",
        state = constants.MISSILE_SYSTEM_STATE.STATIC,
        operationalArea = {
          name = "OPAREA-1",
          FP = { { course = { { latitude = "N 25.00.00", longitude = "E 121.00.00" } } } }
        }
      }
      local firingUnit = {
        guid = "GROUP-001",
        side = "Taiwan",
        group = { unitlist = { "U1", "U2", "U3" } }
      }

      stubRandom = stub(math, "random").returns(1)
      stubGetUnit = stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
        if guid == "U1" then return { guid = "U1", side = "Taiwan" } end
        if guid == "U2" then return nil end -- U2 not found
        if guid == "U3" then return { guid = "U3", side = "Taiwan" } end
        return nil
      end)
      stubSetUnit = stub(GameApi, "ScenEdit_SetUnit")

      MissileSystem.moveToFiringPoint(firingUnitCtx, firingUnit)

      assert.stub(stubSetUnit).was.called(2)
      assert.are.equal("U1", stubSetUnit.calls[1].vals[1].guid)
      assert.are.equal("U3", stubSetUnit.calls[2].vals[1].guid)
    end)

    -- Random position selection
    it("should use random position from FP array", function()
      local course1 = { { latitude = "N 25.00.00", longitude = "E 121.00.00" } }
      local course2 = { { latitude = "N 26.00.00", longitude = "E 122.00.00" } }
      local firingUnitCtx = {
        name = "Firing Unit Alpha",
        state = constants.MISSILE_SYSTEM_STATE.STATIC,
        operationalArea = {
          name = "OPAREA-1",
          FP = {
            { course = course1 },
            { course = course2 }
          }
        }
      }
      local firingUnit = { guid = "F1", side = "Taiwan" }

      stubRandom = stub(math, "random").returns(2) -- Select second position
      stubGetUnit = stub(GameApi, "ScenEdit_GetUnit").returns(firingUnit)
      stubSetUnit = stub(GameApi, "ScenEdit_SetUnit")

      MissileSystem.moveToFiringPoint(firingUnitCtx, firingUnit)

      assert.are.same(course2, stubSetUnit.calls[1].vals[1].course)
    end)
  end)

  describe("setReloadStartTime", function()
    local stubGetUnit, stubSetUnit, stubCurrentTime

    after_each(function()
      if stubGetUnit then stubGetUnit:revert() end
      if stubSetUnit then stubSetUnit:revert() end
      if stubCurrentTime then stubCurrentTime:revert() end
      stubGetUnit, stubSetUnit, stubCurrentTime = nil, nil, nil
    end)

    -- State transitions
    it("should set state to RELOAD", function()
      local firingUnitCtx = { state = constants.MISSILE_SYSTEM_STATE.STATIC }
      local firingUnit = { guid = "F1" }

      stubCurrentTime = stub(GameApi, "ScenEdit_CurrentTime").returns(12345)
      stubGetUnit = stub(GameApi, "ScenEdit_GetUnit").returns(firingUnit)
      stubSetUnit = stub(GameApi, "ScenEdit_SetUnit")

      MissileSystem.setReloadStartTime(firingUnitCtx, firingUnit, false)

      assert.are.equal(constants.MISSILE_SYSTEM_STATE.RELOAD, firingUnitCtx.state)
    end)

    it("should set reloadStartTime to current time", function()
      local firingUnitCtx = { state = constants.MISSILE_SYSTEM_STATE.STATIC, reloadStartTime = nil }
      local firingUnit = { guid = "F1" }

      stubCurrentTime = stub(GameApi, "ScenEdit_CurrentTime").returns(67890)
      stubGetUnit = stub(GameApi, "ScenEdit_GetUnit").returns(firingUnit)
      stubSetUnit = stub(GameApi, "ScenEdit_SetUnit")

      MissileSystem.setReloadStartTime(firingUnitCtx, firingUnit, false)

      assert.are.equal(67890, firingUnitCtx.reloadStartTime)
    end)

    -- Single unit (no group)
    it("should handle single unit without group", function()
      local firingUnitCtx = { state = constants.MISSILE_SYSTEM_STATE.STATIC }
      local firingUnit = { guid = "SINGLE-001", side = "Taiwan" }

      stubCurrentTime = stub(GameApi, "ScenEdit_CurrentTime").returns(12345)
      stubGetUnit = stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
        if guid == "SINGLE-001" then return firingUnit end
        return nil
      end)
      stubSetUnit = stub(GameApi, "ScenEdit_SetUnit")

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

      stubCurrentTime = stub(GameApi, "ScenEdit_CurrentTime").returns(12345)
      stubGetUnit = stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
        if guid == "U1" then return { guid = "U1", side = "Taiwan" } end
        if guid == "U2" then return { guid = "U2", side = "Taiwan" } end
        if guid == "U3" then return { guid = "U3", side = "Taiwan" } end
        return nil
      end)
      stubSetUnit = stub(GameApi, "ScenEdit_SetUnit")

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

      stubCurrentTime = stub(GameApi, "ScenEdit_CurrentTime").returns(12345)
      stubGetUnit = stub(GameApi, "ScenEdit_GetUnit").returns(firingUnit)
      stubSetUnit = stub(GameApi, "ScenEdit_SetUnit")

      MissileSystem.setReloadStartTime(firingUnitCtx, firingUnit, true)

      assert.stub(stubSetUnit).was.called(1)
      assert.is_true(stubSetUnit.calls[1].vals[1].holdposition)
    end)

    it("should NOT call setUnitProperties when isAuto is false", function()
      local firingUnitCtx = { state = constants.MISSILE_SYSTEM_STATE.STATIC }
      local firingUnit = { guid = "F1", side = "Taiwan" }

      stubCurrentTime = stub(GameApi, "ScenEdit_CurrentTime").returns(12345)
      stubGetUnit = stub(GameApi, "ScenEdit_GetUnit").returns(firingUnit)
      stubSetUnit = stub(GameApi, "ScenEdit_SetUnit")

      MissileSystem.setReloadStartTime(firingUnitCtx, firingUnit, false)

      assert.stub(stubSetUnit).was_not.called()
    end)

    -- Nil unit handling
    it("should skip nil units in group list", function()
      local firingUnitCtx = { state = constants.MISSILE_SYSTEM_STATE.STATIC }
      local firingUnit = {
        guid = "GROUP-001",
        side = "Taiwan",
        group = { unitlist = { "U1", "U2", "U3" } }
      }

      stubCurrentTime = stub(GameApi, "ScenEdit_CurrentTime").returns(12345)
      stubGetUnit = stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
        if guid == "U1" then return { guid = "U1", side = "Taiwan" } end
        if guid == "U2" then return nil end -- U2 not found
        if guid == "U3" then return { guid = "U3", side = "Taiwan" } end
        return nil
      end)
      stubSetUnit = stub(GameApi, "ScenEdit_SetUnit")

      MissileSystem.setReloadStartTime(firingUnitCtx, firingUnit, true)

      assert.stub(stubSetUnit).was.called(2)
      assert.are.equal("U1", stubSetUnit.calls[1].vals[1].guid)
      assert.are.equal("U3", stubSetUnit.calls[2].vals[1].guid)
    end)
  end)

  describe("setStateToStatic", function()
    local mockSystemCtx
    local stubGetUnit, stubSetUnit, stubSetDoctrine

    before_each(function()
      mockSystemCtx = {
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
      }
    end)

    after_each(function()
      if stubGetUnit then stubGetUnit:revert() end
      if stubSetUnit then stubSetUnit:revert() end
      if stubSetDoctrine then stubSetDoctrine:revert() end
      stubGetUnit, stubSetUnit, stubSetDoctrine = nil, nil, nil
    end)

    -- Boundary cases
    it("should do nothing when unit name not in firingUnits or resupplyUnits", function()
      local firingUnit = { guid = "UNKNOWN-001", name = "Unknown Unit" }
      local firingUnitAlpha = mockSystemCtx.firingUnits["Firing Unit Alpha"]

      stubGetUnit = stub(GameApi, "ScenEdit_GetUnit").returns(nil)
      stubSetUnit = stub(GameApi, "ScenEdit_SetUnit")

      MissileSystem.setStateToStatic(mockSystemCtx, firingUnit, true)

      assert.are.equal(constants.MISSILE_SYSTEM_STATE.RELOAD, firingUnitAlpha.state)
      assert.are.equal(12345, firingUnitAlpha.reloadStartTime)
      assert.stub(stubGetUnit).was_not.called()
      assert.stub(stubSetUnit).was_not.called()
    end)

    -- State transitions for firing units
    it("should set firingUnit state to STATIC", function()
      local firingUnit = { guid = "F1", name = "Firing Unit Alpha" }
      local firingUnitAlpha = mockSystemCtx.firingUnits["Firing Unit Alpha"]

      stubGetUnit = stub(GameApi, "ScenEdit_GetUnit").returns(firingUnit)
      stubSetUnit = stub(GameApi, "ScenEdit_SetUnit")

      MissileSystem.setStateToStatic(mockSystemCtx, firingUnit, false)

      assert.are.equal(constants.MISSILE_SYSTEM_STATE.STATIC, firingUnitAlpha.state)
    end)

    it("should clear firingUnit reloadStartTime", function()
      local firingUnit = { guid = "F1", name = "Firing Unit Alpha" }
      local firingUnitAlpha = mockSystemCtx.firingUnits["Firing Unit Alpha"]

      stubGetUnit = stub(GameApi, "ScenEdit_GetUnit").returns(firingUnit)
      stubSetUnit = stub(GameApi, "ScenEdit_SetUnit")

      MissileSystem.setStateToStatic(mockSystemCtx, firingUnit, false)

      assert.is_nil(firingUnitAlpha.reloadStartTime)
    end)

    -- isAuto behavior
    it("should call setUnitProperties when isAuto is true", function()
      local firingUnit = { guid = "F1", name = "Firing Unit Alpha", side = "Taiwan" }

      stubGetUnit = stub(GameApi, "ScenEdit_GetUnit").returns(firingUnit)
      stubSetUnit = stub(GameApi, "ScenEdit_SetUnit")
      stubSetDoctrine = stub(GameApi, "ScenEdit_SetDoctrine")

      MissileSystem.setStateToStatic(mockSystemCtx, firingUnit, true)

      assert.stub(stubSetUnit).was.called(1)
      assert.is_true(stubSetUnit.calls[1].vals[1].holdposition)
      assert.stub(stubSetDoctrine).was.called(1)
      assert.are.equal(constants.WCS.HOLD, stubSetDoctrine.calls[1].vals[2].weapon_control_status_land)
    end)

    it("should NOT call setUnitProperties when isAuto is false", function()
      local firingUnit = { guid = "F1", name = "Firing Unit Alpha" }

      stubGetUnit = stub(GameApi, "ScenEdit_GetUnit").returns(firingUnit)
      stubSetUnit = stub(GameApi, "ScenEdit_SetUnit")

      MissileSystem.setStateToStatic(mockSystemCtx, firingUnit, false)

      assert.stub(stubSetUnit).was_not.called()
    end)

    -- Single unit (no group)
    it("should handle single unit without group", function()
      local firingUnit = { guid = "SINGLE-001", name = "Firing Unit Alpha", side = "Taiwan" }

      stubGetUnit = stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
        if guid == "SINGLE-001" then return firingUnit end
        return nil
      end)
      stubSetUnit = stub(GameApi, "ScenEdit_SetUnit")
      stubSetDoctrine = stub(GameApi, "ScenEdit_SetDoctrine")

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

      stubGetUnit = stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
        if guid == "U1" then return { guid = "U1", side = "Taiwan" } end
        if guid == "U2" then return { guid = "U2", side = "Taiwan" } end
        if guid == "U3" then return { guid = "U3", side = "Taiwan" } end
        return nil
      end)
      stubSetUnit = stub(GameApi, "ScenEdit_SetUnit")
      stubSetDoctrine = stub(GameApi, "ScenEdit_SetDoctrine")

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

      stubGetUnit = stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
        if guid == "U1" then return { guid = "U1", side = "Taiwan" } end
        if guid == "U2" then return nil end -- U2 not found
        if guid == "U3" then return { guid = "U3", side = "Taiwan" } end
        return nil
      end)
      stubSetUnit = stub(GameApi, "ScenEdit_SetUnit")
      stubSetDoctrine = stub(GameApi, "ScenEdit_SetDoctrine")

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

      stubGetUnit = stub(GameApi, "ScenEdit_GetUnit").returns(firingUnit)
      stubSetUnit = stub(GameApi, "ScenEdit_SetUnit")

      MissileSystem.setStateToStatic(mockSystemCtx, firingUnit, false)

      assert.are.equal(constants.MISSILE_SYSTEM_STATE.STATIC, firingUnitAlpha.state)
      assert.is_nil(firingUnitAlpha.reloadStartTime)
      assert.are.equal(constants.MISSILE_SYSTEM_STATE.HIDE, resupplyUnitAlpha.state)
      assert.are.equal(99999, resupplyUnitAlpha.reloadStartTime)
    end)
  end)

  describe("setStateToHIDE", function()
    local stubGetUnit, stubSetUnit, stubSetDoctrine

    after_each(function()
      if stubGetUnit then stubGetUnit:revert() end
      if stubSetUnit then stubSetUnit:revert() end
      if stubSetDoctrine then stubSetDoctrine:revert() end
      stubGetUnit, stubSetUnit, stubSetDoctrine = nil, nil, nil
    end)

    -- State transitions
    it("should set state to HIDE", function()
      local firingUnitCtx = { state = constants.MISSILE_SYSTEM_STATE.STATIC }
      local firingUnit = { guid = "F1" }

      stubGetUnit = stub(GameApi, "ScenEdit_GetUnit").returns(firingUnit)
      stubSetUnit = stub(GameApi, "ScenEdit_SetUnit")

      MissileSystem.setStateToHIDE(firingUnitCtx, firingUnit, false)

      assert.are.equal(constants.MISSILE_SYSTEM_STATE.HIDE, firingUnitCtx.state)
    end)

    -- Single unit (no group)
    it("should handle single unit without group", function()
      local firingUnitCtx = { state = constants.MISSILE_SYSTEM_STATE.STATIC }
      local firingUnit = { guid = "SINGLE-001", side = "Taiwan" }

      stubGetUnit = stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
        if guid == "SINGLE-001" then return firingUnit end
        return nil
      end)
      stubSetUnit = stub(GameApi, "ScenEdit_SetUnit")
      stubSetDoctrine = stub(GameApi, "ScenEdit_SetDoctrine")

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

      stubGetUnit = stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
        if guid == "U1" then return { guid = "U1", side = "Taiwan" } end
        if guid == "U2" then return { guid = "U2", side = "Taiwan" } end
        if guid == "U3" then return { guid = "U3", side = "Taiwan" } end
        return nil
      end)
      stubSetUnit = stub(GameApi, "ScenEdit_SetUnit")
      stubSetDoctrine = stub(GameApi, "ScenEdit_SetDoctrine")

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

      stubGetUnit = stub(GameApi, "ScenEdit_GetUnit").returns(firingUnit)
      stubSetUnit = stub(GameApi, "ScenEdit_SetUnit")
      stubSetDoctrine = stub(GameApi, "ScenEdit_SetDoctrine")

      MissileSystem.setStateToHIDE(firingUnitCtx, firingUnit, true)

      assert.stub(stubSetUnit).was.called(1)
      assert.is_true(stubSetUnit.calls[1].vals[1].holdposition)
      assert.stub(stubSetDoctrine).was.called(1)
      assert.are.equal(constants.WCS.HOLD, stubSetDoctrine.calls[1].vals[2].weapon_control_status_land)
    end)

    it("should NOT call setUnitProperties when isAuto is false", function()
      local firingUnitCtx = { state = constants.MISSILE_SYSTEM_STATE.STATIC }
      local firingUnit = { guid = "F1", side = "Taiwan" }

      stubGetUnit = stub(GameApi, "ScenEdit_GetUnit").returns(firingUnit)
      stubSetUnit = stub(GameApi, "ScenEdit_SetUnit")

      MissileSystem.setStateToHIDE(firingUnitCtx, firingUnit, false)

      assert.stub(stubSetUnit).was_not.called()
    end)

    -- Nil unit handling
    it("should skip nil units in group list", function()
      local firingUnitCtx = { state = constants.MISSILE_SYSTEM_STATE.STATIC }
      local firingUnit = {
        guid = "GROUP-001",
        side = "Taiwan",
        group = { unitlist = { "U1", "U2", "U3" } }
      }

      stubGetUnit = stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
        if guid == "U1" then return { guid = "U1", side = "Taiwan" } end
        if guid == "U2" then return nil end -- U2 not found
        if guid == "U3" then return { guid = "U3", side = "Taiwan" } end
        return nil
      end)
      stubSetUnit = stub(GameApi, "ScenEdit_SetUnit")
      stubSetDoctrine = stub(GameApi, "ScenEdit_SetDoctrine")

      MissileSystem.setStateToHIDE(firingUnitCtx, firingUnit, true)

      assert.stub(stubSetUnit).was.called(2)
      assert.are.equal("U1", stubSetUnit.calls[1].vals[1].guid)
      assert.are.equal("U3", stubSetUnit.calls[2].vals[1].guid)
    end)
  end)

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

  describe("setWCSToFree", function()
    local stubGetUnit, stubSetUnit, stubSetDoctrine

    after_each(function()
      if stubGetUnit then stubGetUnit:revert() end
      if stubSetUnit then stubSetUnit:revert() end
      if stubSetDoctrine then stubSetDoctrine:revert() end
      stubGetUnit, stubSetUnit, stubSetDoctrine = nil, nil, nil
    end)

    it("should set state to STATIC", function()
      local firingUnitCtx = { state = constants.MISSILE_SYSTEM_STATE.RELOAD }
      local firingUnit = { guid = "F1" }

      stubGetUnit = stub(GameApi, "ScenEdit_GetUnit").returns(firingUnit)
      stubSetUnit = stub(GameApi, "ScenEdit_SetUnit")

      MissileSystem.setWCSToFree(firingUnitCtx, firingUnit, false)

      assert.are.equal(constants.MISSILE_SYSTEM_STATE.STATIC, firingUnitCtx.state)
    end)

    it("should set wcs to FREE when isAuto is true", function()
      local firingUnitCtx = { state = constants.MISSILE_SYSTEM_STATE.RELOAD }
      local firingUnit = { guid = "F1", side = "Taiwan" }

      stubGetUnit = stub(GameApi, "ScenEdit_GetUnit").returns(firingUnit)
      stubSetUnit = stub(GameApi, "ScenEdit_SetUnit")
      stubSetDoctrine = stub(GameApi, "ScenEdit_SetDoctrine")

      MissileSystem.setWCSToFree(firingUnitCtx, firingUnit, true)

      assert.stub(stubSetDoctrine).was.called(1)
      assert.are.equal(constants.WCS.FREE, stubSetDoctrine.calls[1].vals[2].weapon_control_status_land)
    end)

    it("should NOT call setUnitProperties when isAuto is false", function()
      local firingUnitCtx = { state = constants.MISSILE_SYSTEM_STATE.RELOAD }
      local firingUnit = { guid = "F1", side = "Taiwan" }

      stubGetUnit = stub(GameApi, "ScenEdit_GetUnit").returns(firingUnit)
      stubSetUnit = stub(GameApi, "ScenEdit_SetUnit")

      MissileSystem.setWCSToFree(firingUnitCtx, firingUnit, false)

      assert.stub(stubSetUnit).was_not.called()
    end)

    it("should iterate group units and skip nil units", function()
      local firingUnitCtx = { state = constants.MISSILE_SYSTEM_STATE.RELOAD }
      local firingUnit = {
        guid = "GROUP-001",
        side = "Taiwan",
        group = { unitlist = { "U1", "U2", "U3" } }
      }

      stubGetUnit = stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
        if guid == "U1" then return { guid = "U1", side = "Taiwan" } end
        if guid == "U2" then return nil end
        if guid == "U3" then return { guid = "U3", side = "Taiwan" } end
        return nil
      end)
      stubSetUnit = stub(GameApi, "ScenEdit_SetUnit")
      stubSetDoctrine = stub(GameApi, "ScenEdit_SetDoctrine")

      MissileSystem.setWCSToFree(firingUnitCtx, firingUnit, true)

      assert.stub(stubSetUnit).was.called(2)
      assert.are.equal("U1", stubSetUnit.calls[1].vals[1].guid)
      assert.are.equal("U3", stubSetUnit.calls[2].vals[1].guid)
    end)
  end)

  describe("handleSupplyAssetDestruction", function()
    local mockSystemCtx

    before_each(function()
      mockSystemCtx = {
        ammunitions = {
          ["Ammo Depot Alpha"] = {
            name = "Ammo Depot Alpha",
            wpnCurrent = 100
          },
          ["Ammo Depot Empty"] = {
            name = "Ammo Depot Empty",
            wpnCurrent = 0
          }
        },
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
        }
      }
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
end)
