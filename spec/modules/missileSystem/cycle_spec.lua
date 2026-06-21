-- MissileSystem Cycle Unit Tests
local stub = require("luassert.stub")
local Cycle = require("src.modules.missileSystem.cycle")
local Concealment = require("src.modules.missileSystem.concealment")
local GameApi = require("src.utils.gameApi")
local GameUtils = require("src.utils.gameUtils")
local Logger = require("src.utils.logger")
local constants = require("src.core.constants")

describe("MissileSystem Cycle", function()
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
  -- process
  -- ============================================================================

  describe("process", function()
    -- Positive: reloads firing unit when reload conditions are met
    it("should reload firing unit when reload conditions are met", function()
      local systemCtx = makeSystemCtx({
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

      local results = Cycle.process(systemCtx, false, "Taiwan")

      assert.are.equal(constants.MISSILE_SYSTEM_STATE.STATIC, systemCtx.firingUnits["Firing Unit Alpha"].state)
      assert.is_nil(systemCtx.firingUnits["Firing Unit Alpha"].reloadStartTime)
      assert.are.equal(1, #results)
      assert.are.equal("Missile reload finished", results[1].action)
    end)

    -- Positive: transfers ammo to resupply unit when transfer conditions are met
    it("should transfer ammo to resupply unit when transfer conditions are met", function()
      local systemCtx = makeSystemCtx({
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

      local results = Cycle.process(systemCtx, false, "Taiwan")

      assert.are.equal(20, systemCtx.resupplyUnits["Ammo Sec, Alpha"].wpnCurrent)
      assert.are.equal(80, systemCtx.ammunitions["Ammo Depot"].wpnCurrent)
      assert.are.equal(constants.MISSILE_SYSTEM_STATE.STATIC, systemCtx.resupplyUnits["Ammo Sec, Alpha"].state)
      assert.are.equal(1, #results)
      assert.are.equal("Ammo transload finished", results[1].action)
    end)

    -- Negative: skips firing unit when game unit cannot be found
    it("should skip firing unit when unit not found in game", function()
      local systemCtx = makeSystemCtx({
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

      local results = Cycle.process(systemCtx, false, "Taiwan")

      assert.are.equal(constants.MISSILE_SYSTEM_STATE.RELOAD, systemCtx.firingUnits["Firing Unit Alpha"].state)
      assert.are.equal(0, #results)
    end)

    -- Boundary: returns empty result list when no units are present
    it("should return empty results when no reload events occurred", function()
      local systemCtx = makeSystemCtx({
        firingUnits = {},
        resupplyUnits = {}
      })

      local results = Cycle.process(systemCtx, false, "Taiwan")

      assert.are.equal(0, #results)
    end)

    -- Positive: moves firing unit to reload point when stow elapsed and low ammo in auto mode
    it("should move firing unit to reload point when stow elapsed and low ammo in auto mode", function()
      local systemCtx = makeSystemCtx({
        reloadTime = 60,
        stowTime = 10,
        firingUnits = {
          ["Firing Unit Alpha"] = {
            name = "Firing Unit Alpha",
            state = constants.MISSILE_SYSTEM_STATE.STATIC,
            reloadStartTime = nil,
            stowStartTime = 1000,
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

      trackStub(GameApi, "ScenEdit_CurrentTime").returns(1100)
      trackStub(GameApi, "ScenEdit_GetUnit").invokes(function(guidOrName)
        if guidOrName == "Firing Unit Alpha" then return firingUnit end
        if guidOrName == "F1" then return firingUnit end
        return nil
      end)
      trackStub(GameUtils, "getWeaponInfo").returns({ availableWeapons = 1, maxWeapons = 10 })
      trackStub(GameApi, "ScenEdit_SetUnit")
      trackStub(math, "random").returns(1)

      Cycle.process(systemCtx, true, "Taiwan")

      local firingCtx = systemCtx.firingUnits["Firing Unit Alpha"]
      assert.are.equal(constants.MISSILE_SYSTEM_STATE.REPOSITIONING, firingCtx.state)
      assert.is_nil(firingCtx.stowStartTime)
    end)

    -- Positive: starts stow countdown without moving when low ammo first detected in auto mode
    it("should start stow countdown without moving when low ammo first detected in auto mode", function()
      local systemCtx = makeSystemCtx({
        reloadTime = 60,
        stowTime = 10,
        firingUnits = {
          ["Firing Unit Alpha"] = {
            name = "Firing Unit Alpha",
            state = constants.MISSILE_SYSTEM_STATE.STATIC,
            reloadStartTime = nil,
            stowStartTime = nil,
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

      trackStub(GameApi, "ScenEdit_CurrentTime").returns(2000)
      trackStub(GameApi, "ScenEdit_GetUnit").invokes(function(guidOrName)
        if guidOrName == "Firing Unit Alpha" then return firingUnit end
        if guidOrName == "F1" then return firingUnit end
        return nil
      end)
      trackStub(GameUtils, "getWeaponInfo").returns({ availableWeapons = 1, maxWeapons = 10 })
      trackStub(GameApi, "ScenEdit_SetUnit")

      local results = Cycle.process(systemCtx, true, "Taiwan")

      local firingCtx = systemCtx.firingUnits["Firing Unit Alpha"]
      assert.are.equal(constants.MISSILE_SYSTEM_STATE.STATIC, firingCtx.state)
      assert.are.equal(2000, firingCtx.stowStartTime)
      assert.are.equal(1, #results)
      assert.are.equal("Stow countdown started", results[1].action)
      assert.are.equal("startedAt=2000", results[1].detail)
    end)

    -- Negative: returns a failure result when movement command cannot be built
    it("should return failure result when hide movement has no available HA", function()
      local systemCtx = makeSystemCtx({
        reloadTime = 60,
        stowTime = 10,
        firingUnits = {
          ["Firing Unit Alpha"] = {
            name = "Firing Unit Alpha",
            state = constants.MISSILE_SYSTEM_STATE.STATIC,
            reloadStartTime = nil,
            stowStartTime = 1000,
            resupplyUnit = "Ammo Sec, Alpha",
            weaponDBID = 1234,
            ammoThreshold = 60,
            operationalArea = {
              name = "OPAREA-1"
            }
          }
        },
        resupplyUnits = {
          ["Ammo Sec, Alpha"] = {
            name = "Ammo Sec, Alpha",
            state = constants.MISSILE_SYSTEM_STATE.STATIC,
            wpnCurrent = 20,
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

      trackStub(GameApi, "ScenEdit_CurrentTime").returns(1100)
      trackStub(GameApi, "ScenEdit_GetUnit").invokes(function(guidOrName)
        if guidOrName == "Firing Unit Alpha" then return firingUnit end
        if guidOrName == "F1" then return firingUnit end
        return nil
      end)
      trackStub(GameUtils, "getWeaponInfo").returns({ availableWeapons = 10, maxWeapons = 10 })

      local results = Cycle.process(systemCtx, true, "Taiwan")

      assert.are.equal(1, #results)
      assert.are.equal("FAIL", results[1].tag)
      assert.are.equal("Move to hide area", results[1].action)
      assert.are.equal("command_failed", results[1].reason)
      assert.is_not_nil(string.find(results[1].detail, "No HA defined", 1, true))
    end)

    -- Positive: moves firing unit to hide area when stow elapsed and ammo sufficient in auto mode
    it("should move firing unit to hide area when stow elapsed and ammo sufficient in auto mode", function()
      local hideCourse = {
        { latitude = "N 25.10.00", longitude = "E 121.10.00" }
      }
      local systemCtx = makeSystemCtx({
        reloadTime = 60,
        stowTime = 10,
        firingUnits = {
          ["Firing Unit Alpha"] = {
            name = "Firing Unit Alpha",
            state = constants.MISSILE_SYSTEM_STATE.STATIC,
            reloadStartTime = nil,
            stowStartTime = 1000,
            resupplyUnit = "Ammo Sec, Alpha",
            weaponDBID = 1234,
            ammoThreshold = 60,
            operationalArea = {
              name = "OPAREA-1",
              HA = { { course = hideCourse, area = { "HA-001" } } }
            }
          }
        },
        resupplyUnits = {
          ["Ammo Sec, Alpha"] = {
            name = "Ammo Sec, Alpha",
            state = constants.MISSILE_SYSTEM_STATE.STATIC,
            wpnCurrent = 20,
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

      trackStub(GameApi, "ScenEdit_CurrentTime").returns(1100)
      trackStub(GameApi, "ScenEdit_GetUnit").invokes(function(guidOrName)
        if guidOrName == "Firing Unit Alpha" then return firingUnit end
        if guidOrName == "F1" then return firingUnit end
        return nil
      end)
      trackStub(GameUtils, "getWeaponInfo").returns({ availableWeapons = 10, maxWeapons = 10 })
      local stubSetUnit = trackStub(GameApi, "ScenEdit_SetUnit")
      trackStub(math, "random").returns(1)

      Cycle.process(systemCtx, true, "Taiwan")

      local firingCtx = systemCtx.firingUnits["Firing Unit Alpha"]
      assert.are.equal(constants.MISSILE_SYSTEM_STATE.REPOSITIONING, firingCtx.state)
      assert.is_nil(firingCtx.stowStartTime)
      assert.are.same(hideCourse, stubSetUnit.calls[1].vals[1].course)
    end)

    -- Negative: does not move firing unit while stow countdown is still in progress
    it("should not move firing unit while stow countdown still in progress", function()
      local systemCtx = makeSystemCtx({
        reloadTime = 60,
        stowTime = 300,
        firingUnits = {
          ["Firing Unit Alpha"] = {
            name = "Firing Unit Alpha",
            state = constants.MISSILE_SYSTEM_STATE.STATIC,
            reloadStartTime = nil,
            stowStartTime = 1000,
            resupplyUnit = "Ammo Sec, Alpha",
            weaponDBID = 1234,
            ammoThreshold = 60,
            operationalArea = {
              name = "OPAREA-1",
              RL = { { course = { { latitude = 25.0, longitude = 121.0 } }, area = { "RP-001" } } },
              HA = { { course = { { latitude = 25.1, longitude = 121.1 } }, area = { "HA-001" } } }
            }
          }
        },
        resupplyUnits = {
          ["Ammo Sec, Alpha"] = {
            name = "Ammo Sec, Alpha",
            state = constants.MISSILE_SYSTEM_STATE.STATIC,
            wpnCurrent = 20,
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

      trackStub(GameApi, "ScenEdit_CurrentTime").returns(1100)
      trackStub(GameApi, "ScenEdit_GetUnit").invokes(function(guidOrName)
        if guidOrName == "Firing Unit Alpha" then return firingUnit end
        if guidOrName == "F1" then return firingUnit end
        return nil
      end)
      trackStub(GameUtils, "getWeaponInfo").returns({ availableWeapons = 1, maxWeapons = 10 })
      local stubSetUnit = trackStub(GameApi, "ScenEdit_SetUnit")

      Cycle.process(systemCtx, true, "Taiwan")

      local firingCtx = systemCtx.firingUnits["Firing Unit Alpha"]
      assert.are.equal(constants.MISSILE_SYSTEM_STATE.STATIC, firingCtx.state)
      assert.are.equal(1000, firingCtx.stowStartTime)
      assert.stub(stubSetUnit).was_not.called()
    end)

    -- Positive: moves non-SAM firing unit to hide area after reload in auto mode
    it("should move non-SAM firing unit to hide area after reload in auto mode", function()
      local hideCourse = {
        { latitude = "N 25.10.00", longitude = "E 121.10.00" }
      }
      local systemCtx = makeSystemCtx({
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

      Cycle.process(systemCtx, true, "Taiwan")

      assert.are.equal(constants.MISSILE_SYSTEM_STATE.REPOSITIONING, systemCtx.firingUnits["Firing Unit Alpha"].state)
      assert.stub(stubHideUnit).was.called(1)
      assert.are.same(hideCourse, stubSetUnit.calls[1].vals[1].course)
    end)

    -- Positive: moves SAM firing unit to firing point after reload in auto mode
    it("should move SAM firing unit to firing point after reload in auto mode", function()
      local fpCourse = {
        { latitude = "N 25.20.00", longitude = "E 121.20.00" }
      }
      local systemCtx = makeSystemCtx({
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

      Cycle.process(systemCtx, true, "Taiwan")

      assert.are.equal(constants.MISSILE_SYSTEM_STATE.REPOSITIONING, systemCtx.firingUnits["Firing Unit Alpha"].state)
      assert.stub(stubHideUnit).was.called(1)
      assert.are.same(fpCourse, stubSetUnit.calls[1].vals[1].course)
    end)
  end)
end)
