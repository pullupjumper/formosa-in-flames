---@diagnostic disable: need-check-nil, assign-type-mismatch, cast-local-type, param-type-mismatch, inject-field
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

  ---Create missile system config: the reload/stow timers and the Alpha battery's descriptors
  ---@param overrides? table
  ---@return table
  local function makeSystemConfig(overrides)
    local cfg = {
      reloadTime = 60,
      stowTime = 10,
      launchers = {
        ["Launcher Alpha"] = {
          name = "Launcher Alpha",
          transloader = "Ammo Sec, Alpha",
          weaponDBID = 1234,
          ammoThreshold = 60,
        }
      },
      transloaders = {
        ["Ammo Sec, Alpha"] = {
          name = "Ammo Sec, Alpha",
          launcher = "Launcher Alpha",
          canisterStock = "Canister Stock",
          weaponCountDefault = 20,
        }
      },
      canisterStocks = {
        ["Canister Stock"] = { name = "Canister Stock", weaponCountDefault = 200 }
      },
    }
    if overrides then
      for k, v in pairs(overrides) do cfg[k] = v end
    end
    return cfg
  end

  local function makeSystemState(overrides)
    local ctx = {
      name = "srbm",
      launchers = {
        ["Launcher Alpha"] = {
          name = "Launcher Alpha",
          state = constants.MISSILE_UNIT_POSTURE.RELOAD,
          operationalArea = {
            name = "OPAREA-1",
            RL = { { area = { "RP-001", "RP-002", "RP-003", "RP-004" } } }
          },
        }
      },
      transloaders = {
        ["Ammo Sec, Alpha"] = {
          name = "Ammo Sec, Alpha",
          state = constants.MISSILE_UNIT_POSTURE.REPOSITIONING,
          weaponCountCurrent = 10,
          operationalArea = {
            name = "OPAREA-1",
            RL = { { area = { "RP-001", "RP-002", "RP-003", "RP-004" } } }
          }
        }
      },
      canisterStocks = {}
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
    -- Positive: reloads launcher when reload conditions are met
    it("should reload launcher when reload conditions are met", function()
      local systemState = makeSystemState({
        launchers = {
          ["Launcher Alpha"] = {
            name = "Launcher Alpha",
            state = constants.MISSILE_UNIT_POSTURE.RELOAD,
            reloadStartTime = 1000,
            operationalArea = {
              name = "OPAREA-1",
              RL = { { area = { "RP-001", "RP-002", "RP-003", "RP-004" } } }
            }
          }
        },
        transloaders = {
          ["Ammo Sec, Alpha"] = {
            name = "Ammo Sec, Alpha",
            state = constants.MISSILE_UNIT_POSTURE.REPOSITIONING,
            weaponCountCurrent = 10,
            operationalArea = {
              name = "OPAREA-1",
              RL = { { area = { "RP-001", "RP-002", "RP-003", "RP-004" } } }
            }
          }
        }
      })

      local launcher = {
        guid = "F1",
        name = "Launcher Alpha",
        side = "Taiwan",
        group = { unitlist = { "F1" } },
        inArea = function(_, area) return area[1] == "RP-001" end
      }
      local transloader = {
        guid = "R1",
        side = "Taiwan",
        inArea = function(_, area) return area[1] == "RP-001" end
      }

      trackStub(GameApi, "ScenEdit_CurrentTime").returns(1100)
      trackStub(GameApi, "ScenEdit_GetUnit").invokes(function(guidOrName)
        if guidOrName == "Launcher Alpha" then return launcher end
        if guidOrName == "F1" then return launcher end
        if guidOrName == "Ammo Sec, Alpha" then return transloader end
        return nil
      end)
      trackStub(GameUtils, "getWeaponInfo").returns({ availableWeapons = 2, maxWeapons = 10 })
      trackStub(GameApi, "ScenEdit_AddReloadsToUnit")
      trackStub(GameApi, "ScenEdit_SetUnit")

      local results = Cycle.process(systemState, { systemConfig = makeSystemConfig(), isAuto = false }, "Taiwan")

      assert.are.equal(constants.MISSILE_UNIT_POSTURE.STATIC, systemState.launchers["Launcher Alpha"].state)
      assert.is_nil(systemState.launchers["Launcher Alpha"].reloadStartTime)
      assert.are.equal(1, #results)
      assert.are.equal("missile_reload_finished", results[1].fields.action)
    end)

    -- Positive: transfers ammo to transloader when transfer conditions are met
    it("should transfer ammo to transloader when transfer conditions are met", function()
      local systemState = makeSystemState({
        launchers = {},
        transloaders = {
          ["Ammo Sec, Alpha"] = {
            name = "Ammo Sec, Alpha",
            state = constants.MISSILE_UNIT_POSTURE.RELOAD,
            reloadStartTime = 1000,
            weaponCountCurrent = 0,
            operationalArea = {
              name = "OPAREA-1",
              RL = { { area = { "RP-001", "RP-002", "RP-003", "RP-004" } } },
              ATP = { { area = { "ATP-001", "ATP-002", "ATP-003", "ATP-004" } } }
            }
          }
        },
        canisterStocks = {
          ["Canister Stock"] = {
            name = "Canister Stock",
            weaponCountCurrent = 100
          }
        }
      })

      local transloader = {
        guid = "R1",
        name = "Ammo Sec, Alpha",
        side = "Taiwan",
        inArea = function(_, area) return area[1] == "ATP-001" end
      }
      local canisterStockUnit = {
        guid = "AD1",
        side = "Taiwan",
        inArea = function(_, area) return area[1] == "ATP-001" end
      }

      trackStub(GameApi, "ScenEdit_CurrentTime").returns(1100)
      trackStub(GameApi, "ScenEdit_GetUnit").invokes(function(guidOrName)
        if guidOrName == "Ammo Sec, Alpha" then return transloader end
        if guidOrName == "Canister Stock" then return canisterStockUnit end
        return nil
      end)

      local results = Cycle.process(systemState, { systemConfig = makeSystemConfig(), isAuto = false }, "Taiwan")

      assert.are.equal(20, systemState.transloaders["Ammo Sec, Alpha"].weaponCountCurrent)
      assert.are.equal(80, systemState.canisterStocks["Canister Stock"].weaponCountCurrent)
      assert.are.equal(constants.MISSILE_UNIT_POSTURE.STATIC, systemState.transloaders["Ammo Sec, Alpha"].state)
      assert.are.equal(1, #results)
      assert.are.equal("ammo_transload_finished", results[1].fields.action)
    end)

    -- Negative: skips launcher when game unit cannot be found
    it("should skip launcher when unit not found in game", function()
      local systemState = makeSystemState({
        launchers = {
          ["Launcher Alpha"] = {
            name = "Launcher Alpha",
            state = constants.MISSILE_UNIT_POSTURE.RELOAD,
            reloadStartTime = 1000,
          }
        },
        transloaders = {}
      })

      trackStub(GameApi, "ScenEdit_GetUnit").returns(nil)

      local results = Cycle.process(systemState, { systemConfig = makeSystemConfig(), isAuto = false }, "Taiwan")

      assert.are.equal(constants.MISSILE_UNIT_POSTURE.RELOAD, systemState.launchers["Launcher Alpha"].state)
      assert.are.equal(0, #results)
    end)

    -- Boundary: returns empty result list when no units are present
    it("should return empty results when no reload events occurred", function()
      local systemState = makeSystemState({
        launchers = {},
        transloaders = {}
      })

      local results = Cycle.process(systemState, { systemConfig = makeSystemConfig(), isAuto = false }, "Taiwan")

      assert.are.equal(0, #results)
    end)

    -- Positive: moves launcher to reload point when stow elapsed and low ammo in auto mode
    it("should move launcher to reload point when stow elapsed and low ammo in auto mode", function()
      local systemState = makeSystemState({
        launchers = {
          ["Launcher Alpha"] = {
            name = "Launcher Alpha",
            state = constants.MISSILE_UNIT_POSTURE.STATIC,
            reloadStartTime = nil,
            stowStartTime = 1000,
            operationalArea = {
              name = "OPAREA-1",
              RL = { { course = { { latitude = 25.0, longitude = 121.0 } }, area = { "RP-001" } } }
            }
          }
        },
        transloaders = {
          ["Ammo Sec, Alpha"] = {
            name = "Ammo Sec, Alpha",
            state = constants.MISSILE_UNIT_POSTURE.STATIC,
            weaponCountCurrent = 10,
          }
        }
      })

      local launcher = {
        guid = "F1",
        name = "Launcher Alpha",
        side = "Taiwan",
        group = { unitlist = { "F1" } }
      }

      trackStub(GameApi, "ScenEdit_CurrentTime").returns(1100)
      trackStub(GameApi, "ScenEdit_GetUnit").invokes(function(guidOrName)
        if guidOrName == "Launcher Alpha" then return launcher end
        if guidOrName == "F1" then return launcher end
        return nil
      end)
      trackStub(GameUtils, "getWeaponInfo").returns({ availableWeapons = 1, maxWeapons = 10 })
      trackStub(GameApi, "ScenEdit_SetUnit")
      trackStub(math, "random").returns(1)

      Cycle.process(systemState, { systemConfig = makeSystemConfig(), isAuto = true }, "Taiwan")

      local launcherState = systemState.launchers["Launcher Alpha"]
      assert.are.equal(constants.MISSILE_UNIT_POSTURE.REPOSITIONING, launcherState.state)
      assert.is_nil(launcherState.stowStartTime)
    end)

    -- Positive: starts stow countdown without moving when low ammo first detected in auto mode
    it("should start stow countdown without moving when low ammo first detected in auto mode", function()
      local systemState = makeSystemState({
        launchers = {
          ["Launcher Alpha"] = {
            name = "Launcher Alpha",
            state = constants.MISSILE_UNIT_POSTURE.STATIC,
            reloadStartTime = nil,
            stowStartTime = nil,
            operationalArea = {
              name = "OPAREA-1",
              RL = { { course = { { latitude = 25.0, longitude = 121.0 } }, area = { "RP-001" } } }
            }
          }
        },
        transloaders = {
          ["Ammo Sec, Alpha"] = {
            name = "Ammo Sec, Alpha",
            state = constants.MISSILE_UNIT_POSTURE.STATIC,
            weaponCountCurrent = 10,
          }
        }
      })

      local launcher = {
        guid = "F1",
        name = "Launcher Alpha",
        side = "Taiwan",
        group = { unitlist = { "F1" } }
      }

      trackStub(GameApi, "ScenEdit_CurrentTime").returns(2000)
      trackStub(GameApi, "ScenEdit_GetUnit").invokes(function(guidOrName)
        if guidOrName == "Launcher Alpha" then return launcher end
        if guidOrName == "F1" then return launcher end
        return nil
      end)
      trackStub(GameUtils, "getWeaponInfo").returns({ availableWeapons = 1, maxWeapons = 10 })
      trackStub(GameApi, "ScenEdit_SetUnit")

      local results = Cycle.process(systemState, { systemConfig = makeSystemConfig(), isAuto = true }, "Taiwan")

      local launcherState = systemState.launchers["Launcher Alpha"]
      assert.are.equal(constants.MISSILE_UNIT_POSTURE.STATIC, launcherState.state)
      assert.are.equal(2000, launcherState.stowStartTime)
      assert.are.equal(1, #results)
      assert.are.equal("stow_countdown_started", results[1].fields.action)
      assert.are.equal(2000, results[1].fields.startedAt)
    end)

    -- Negative: returns a failure result when movement command cannot be built
    it("should return failure result when hide movement has no available HA", function()
      local systemState = makeSystemState({
        launchers = {
          ["Launcher Alpha"] = {
            name = "Launcher Alpha",
            state = constants.MISSILE_UNIT_POSTURE.STATIC,
            reloadStartTime = nil,
            stowStartTime = 1000,
            operationalArea = {
              name = "OPAREA-1"
            }
          }
        },
        transloaders = {
          ["Ammo Sec, Alpha"] = {
            name = "Ammo Sec, Alpha",
            state = constants.MISSILE_UNIT_POSTURE.STATIC,
            weaponCountCurrent = 20,
          }
        }
      })

      local launcher = {
        guid = "F1",
        name = "Launcher Alpha",
        side = "Taiwan",
        group = { unitlist = { "F1" } }
      }

      trackStub(GameApi, "ScenEdit_CurrentTime").returns(1100)
      trackStub(GameApi, "ScenEdit_GetUnit").invokes(function(guidOrName)
        if guidOrName == "Launcher Alpha" then return launcher end
        if guidOrName == "F1" then return launcher end
        return nil
      end)
      trackStub(GameUtils, "getWeaponInfo").returns({ availableWeapons = 10, maxWeapons = 10 })

      local results = Cycle.process(systemState, { systemConfig = makeSystemConfig(), isAuto = true }, "Taiwan")

      assert.are.equal(1, #results)
      assert.are.equal("FAIL", results[1].tag)
      assert.are.equal("move_to_hide_area", results[1].fields.action)
      assert.are.equal("no_ha_defined", results[1].fields.reason)
      assert.is_nil(results[1].fields.detail)
      -- Not stuck REPOSITIONING, and the stow is not retried every cycle
      assert.are.equal(constants.MISSILE_UNIT_POSTURE.STATIC, systemState.launchers["Launcher Alpha"].state)
      assert.is_nil(systemState.launchers["Launcher Alpha"].stowStartTime)
    end)

    -- Negative: a transloader that cannot reach ATP stays STATIC so the next cycle can retry
    it("should keep an empty transloader STATIC when its ATP move fails", function()
      local systemState = makeSystemState({
        launchers = {},
        transloaders = {
          ["Ammo Sec, Alpha"] = {
            name = "Ammo Sec, Alpha",
            state = constants.MISSILE_UNIT_POSTURE.STATIC,
            weaponCountCurrent = 0,
            operationalArea = {
              name = "OPAREA-1",
              RL = { { area = { "RP-001" } } },
              ATP = {}
            }
          }
        }
      })
      local transloader = { guid = "R1", name = "Ammo Sec, Alpha", side = "Taiwan", inArea = function() return true end }

      trackStub(GameApi, "ScenEdit_GetUnit").returns(transloader)

      local results = Cycle.process(systemState, { systemConfig = makeSystemConfig(), isAuto = true }, "Taiwan")

      assert.are.equal("FAIL", results[1].tag)
      assert.are.equal("move_to_ammunition_transfer_point", results[1].fields.action)
      assert.are.equal(constants.MISSILE_UNIT_POSTURE.STATIC, systemState.transloaders["Ammo Sec, Alpha"].state)
    end)

    -- Positive: moves launcher to hide area when stow elapsed and ammo sufficient in auto mode
    it("should move launcher to hide area when stow elapsed and ammo sufficient in auto mode", function()
      local hideCourse = {
        { latitude = "N 25.10.00", longitude = "E 121.10.00" }
      }
      local systemState = makeSystemState({
        launchers = {
          ["Launcher Alpha"] = {
            name = "Launcher Alpha",
            state = constants.MISSILE_UNIT_POSTURE.STATIC,
            reloadStartTime = nil,
            stowStartTime = 1000,
            operationalArea = {
              name = "OPAREA-1",
              HA = { { course = hideCourse, area = { "HA-001" } } }
            }
          }
        },
        transloaders = {
          ["Ammo Sec, Alpha"] = {
            name = "Ammo Sec, Alpha",
            state = constants.MISSILE_UNIT_POSTURE.STATIC,
            weaponCountCurrent = 20,
          }
        }
      })

      local launcher = {
        guid = "F1",
        name = "Launcher Alpha",
        side = "Taiwan",
        group = { unitlist = { "F1" } }
      }

      trackStub(GameApi, "ScenEdit_CurrentTime").returns(1100)
      trackStub(GameApi, "ScenEdit_GetUnit").invokes(function(guidOrName)
        if guidOrName == "Launcher Alpha" then return launcher end
        if guidOrName == "F1" then return launcher end
        return nil
      end)
      trackStub(GameUtils, "getWeaponInfo").returns({ availableWeapons = 10, maxWeapons = 10 })
      local stubSetUnit = trackStub(GameApi, "ScenEdit_SetUnit")
      trackStub(math, "random").returns(1)

      Cycle.process(systemState, { systemConfig = makeSystemConfig(), isAuto = true }, "Taiwan")

      local launcherState = systemState.launchers["Launcher Alpha"]
      assert.are.equal(constants.MISSILE_UNIT_POSTURE.REPOSITIONING, launcherState.state)
      assert.is_nil(launcherState.stowStartTime)
      assert.are.same(hideCourse, stubSetUnit.calls[1].vals[1].course)
    end)

    -- Negative: does not move launcher while stow countdown is still in progress
    it("should not move launcher while stow countdown still in progress", function()
      local systemState = makeSystemState({
        launchers = {
          ["Launcher Alpha"] = {
            name = "Launcher Alpha",
            state = constants.MISSILE_UNIT_POSTURE.STATIC,
            reloadStartTime = nil,
            stowStartTime = 1000,
            operationalArea = {
              name = "OPAREA-1",
              RL = { { course = { { latitude = 25.0, longitude = 121.0 } }, area = { "RP-001" } } },
              HA = { { course = { { latitude = 25.1, longitude = 121.1 } }, area = { "HA-001" } } }
            }
          }
        },
        transloaders = {
          ["Ammo Sec, Alpha"] = {
            name = "Ammo Sec, Alpha",
            state = constants.MISSILE_UNIT_POSTURE.STATIC,
            weaponCountCurrent = 20,
          }
        }
      })

      local launcher = {
        guid = "F1",
        name = "Launcher Alpha",
        side = "Taiwan",
        group = { unitlist = { "F1" } }
      }

      trackStub(GameApi, "ScenEdit_CurrentTime").returns(1100)
      trackStub(GameApi, "ScenEdit_GetUnit").invokes(function(guidOrName)
        if guidOrName == "Launcher Alpha" then return launcher end
        if guidOrName == "F1" then return launcher end
        return nil
      end)
      trackStub(GameUtils, "getWeaponInfo").returns({ availableWeapons = 1, maxWeapons = 10 })
      local stubSetUnit = trackStub(GameApi, "ScenEdit_SetUnit")

      Cycle.process(systemState, { systemConfig = makeSystemConfig({ stowTime = 300 }), isAuto = true }, "Taiwan")

      local launcherState = systemState.launchers["Launcher Alpha"]
      assert.are.equal(constants.MISSILE_UNIT_POSTURE.STATIC, launcherState.state)
      assert.are.equal(1000, launcherState.stowStartTime)
      assert.stub(stubSetUnit).was_not.called()
    end)

    -- Positive: moves non-SAM launcher to hide area after reload in auto mode
    it("should move non-SAM launcher to hide area after reload in auto mode", function()
      local hideCourse = {
        { latitude = "N 25.10.00", longitude = "E 121.10.00" }
      }
      local systemState = makeSystemState({
        name = "srbm",
        launchers = {
          ["Launcher Alpha"] = {
            name = "Launcher Alpha",
            state = constants.MISSILE_UNIT_POSTURE.RELOAD,
            reloadStartTime = 1000,
            operationalArea = {
              name = "OPAREA-1",
              RL = { { area = { "RP-001", "RP-002", "RP-003", "RP-004" } } },
              HA = { { course = hideCourse, area = { "HA-001", "HA-002", "HA-003", "HA-004" } } }
            }
          }
        },
        transloaders = {
          ["Ammo Sec, Alpha"] = {
            name = "Ammo Sec, Alpha",
            state = constants.MISSILE_UNIT_POSTURE.REPOSITIONING,
            weaponCountCurrent = 10,
            operationalArea = {
              name = "OPAREA-1",
              RL = { { area = { "RP-001", "RP-002", "RP-003", "RP-004" } } },
              mask = { area = { "MASK-001", "MASK-002", "MASK-003", "MASK-004" } }
            }
          }
        }
      })

      local launcher = {
        guid = "F1",
        name = "Launcher Alpha",
        side = "Taiwan",
        group = { unitlist = { "F1" } },
        inArea = function(_, area) return area[1] == "RP-001" end
      }
      local transloader = {
        guid = "R1",
        name = "Ammo Sec, Alpha",
        side = "Taiwan",
        inArea = function(_, area) return area[1] == "RP-001" end
      }

      trackStub(GameApi, "ScenEdit_CurrentTime").returns(1100)
      trackStub(GameApi, "ScenEdit_GetUnit").invokes(function(guidOrName)
        if guidOrName == "Launcher Alpha" then return launcher end
        if guidOrName == "F1" then return launcher end
        if guidOrName == "Ammo Sec, Alpha" then return transloader end
        return nil
      end)
      trackStub(GameUtils, "getWeaponInfo").returns({ availableWeapons = 2, maxWeapons = 10 })
      trackStub(GameApi, "ScenEdit_AddReloadsToUnit")
      local stubSetUnit = trackStub(GameApi, "ScenEdit_SetUnit")
      local stubHideUnit = trackStub(Concealment, "hideUnit").returns(true)
      trackStub(math, "random").returns(1)

      Cycle.process(systemState, { systemConfig = makeSystemConfig(), isAuto = true }, "Taiwan")

      assert.are.equal(constants.MISSILE_UNIT_POSTURE.REPOSITIONING, systemState.launchers["Launcher Alpha"].state)
      assert.stub(stubHideUnit).was.called(1)
      assert.are.same(hideCourse, stubSetUnit.calls[1].vals[1].course)
    end)

    -- Positive: moves SAM launcher to firing point after reload in auto mode
    it("should move SAM launcher to firing point after reload in auto mode", function()
      local fpCourse = {
        { latitude = "N 25.20.00", longitude = "E 121.20.00" }
      }
      local systemState = makeSystemState({
        name = "sam",
        launchers = {
          ["Launcher Alpha"] = {
            name = "Launcher Alpha",
            state = constants.MISSILE_UNIT_POSTURE.RELOAD,
            reloadStartTime = 1000,
            operationalArea = {
              name = "OPAREA-1",
              RL = { { area = { "RP-001", "RP-002", "RP-003", "RP-004" } } },
              FP = { { course = fpCourse, area = { "FP-001", "FP-002", "FP-003", "FP-004" } } },
              HA = { { course = { { latitude = "N 25.30.00", longitude = "E 121.30.00" } } } }
            }
          }
        },
        transloaders = {
          ["Ammo Sec, Alpha"] = {
            name = "Ammo Sec, Alpha",
            state = constants.MISSILE_UNIT_POSTURE.REPOSITIONING,
            weaponCountCurrent = 10,
            operationalArea = {
              name = "OPAREA-1",
              RL = { { area = { "RP-001", "RP-002", "RP-003", "RP-004" } } },
              mask = { area = { "MASK-001", "MASK-002", "MASK-003", "MASK-004" } }
            }
          }
        }
      })

      local launcher = {
        guid = "F1",
        name = "Launcher Alpha",
        side = "Taiwan",
        group = { unitlist = { "F1" } },
        inArea = function(_, area) return area[1] == "RP-001" end
      }
      local transloader = {
        guid = "R1",
        name = "Ammo Sec, Alpha",
        side = "Taiwan",
        inArea = function(_, area) return area[1] == "RP-001" end
      }

      trackStub(GameApi, "ScenEdit_CurrentTime").returns(1100)
      trackStub(GameApi, "ScenEdit_GetUnit").invokes(function(guidOrName)
        if guidOrName == "Launcher Alpha" then return launcher end
        if guidOrName == "F1" then return launcher end
        if guidOrName == "Ammo Sec, Alpha" then return transloader end
        return nil
      end)
      trackStub(GameUtils, "getWeaponInfo").returns({ availableWeapons = 2, maxWeapons = 10 })
      trackStub(GameApi, "ScenEdit_AddReloadsToUnit")
      local stubSetUnit = trackStub(GameApi, "ScenEdit_SetUnit")
      local stubHideUnit = trackStub(Concealment, "hideUnit").returns(true)
      trackStub(math, "random").returns(1)

      Cycle.process(systemState, { systemConfig = makeSystemConfig(), isAuto = true }, "Taiwan")

      assert.are.equal(constants.MISSILE_UNIT_POSTURE.REPOSITIONING, systemState.launchers["Launcher Alpha"].state)
      assert.stub(stubHideUnit).was.called(1)
      assert.are.same(fpCourse, stubSetUnit.calls[1].vals[1].course)
    end)

    -- Positive: an old save still carries copied config values; the threshold comes from config, not the save
    it("should judge low ammo by the config threshold when the saved state carries an old one", function()
      local systemConfig = makeSystemConfig()
      systemConfig.launchers["Launcher Alpha"].ammoThreshold = 30
      local systemState = makeSystemState()
      local launcherState = systemState.launchers["Launcher Alpha"]
      launcherState.state = constants.MISSILE_UNIT_POSTURE.STATIC
      launcherState.ammoThreshold = 60
      launcherState.weaponDBID = 9999
      systemState.transloaders["Ammo Sec, Alpha"].state = constants.MISSILE_UNIT_POSTURE.STATIC
      local launcher = { guid = "F1", name = "Launcher Alpha", side = "Taiwan", group = { unitlist = { "F1" } } }

      trackStub(GameApi, "ScenEdit_CurrentTime").returns(2000)
      trackStub(GameApi, "ScenEdit_GetUnit").invokes(function(guidOrName)
        if guidOrName == "Launcher Alpha" or guidOrName == "F1" then return launcher end
        return nil
      end)
      local getWeaponInfoStub = trackStub(GameUtils, "getWeaponInfo").returns({ availableWeapons = 5, maxWeapons = 10 })

      local results = Cycle.process(systemState, { systemConfig = systemConfig, isAuto = true }, "Taiwan")

      assert.are.same({}, results)
      assert.is_nil(launcherState.stowStartTime)
      assert.stub(getWeaponInfoStub).was.called_with(launcher, 1234)
    end)

    -- Negative: a state whose battery config dropped is skipped with a warning, the rest of the cycle runs
    it("should skip and warn about a unit with no config descriptor", function()
      local systemConfig = makeSystemConfig({ launchers = {}, transloaders = {} })
      local systemState = makeSystemState()
      local getUnitStub = trackStub(GameApi, "ScenEdit_GetUnit")
      trackStub(GameApi, "ScenEdit_CurrentTime").returns(2000)

      local results = Cycle.process(systemState, { systemConfig = systemConfig, isAuto = true }, "Taiwan")

      assert.are.same({
        { tag = "WARN", fields = { unit = "Launcher Alpha", action = "reload_cycle", reason = "descriptor_not_found" } },
        { tag = "WARN", fields = { unit = "Ammo Sec, Alpha", action = "reload_cycle", reason = "descriptor_not_found" } },
      }, results)
      assert.stub(getUnitStub).was_not.called()
      assert.are.equal(constants.MISSILE_UNIT_POSTURE.RELOAD, systemState.launchers["Launcher Alpha"].state)
    end)
  end)
end)
