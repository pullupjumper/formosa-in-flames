---@diagnostic disable: need-check-nil, assign-type-mismatch, cast-local-type, param-type-mismatch, inject-field
-- MissileSystem Context Unit Tests
local stub = require("luassert.stub")
local Context = require("src.modules.missileSystem.context")
local constants = require("src.core.constants")
local Logger = require("src.utils.logger")

describe("MissileSystem Context", function()
  ---@type luassert.spy[]
  local activeStubs

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
          weaponCountCurrent = 10,
          weaponCountDefault = 20,
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
  -- processSupplyAssetDestruction
  -- ============================================================================

  describe("processSupplyAssetDestruction", function()
    local mockSystemCtx

    before_each(function()
      mockSystemCtx = makeSystemCtx({
        firingUnits = {},
        resupplyUnits = {
          ["Resupply Group Alpha"] = {
            name = "Resupply Group Alpha",
            weaponCountCurrent = 20,
            weaponCountDefault = 20,
            unitCount = 4
          },
          ["Resupply Group Beta"] = {
            name = "Resupply Group Beta",
            weaponCountCurrent = 3,
            weaponCountDefault = 20,
            unitCount = 4
          },
          ["Resupply Group Empty"] = {
            name = "Resupply Group Empty",
            weaponCountCurrent = 0,
            weaponCountDefault = 20,
            unitCount = 4
          }
        },
        ammunitions = {
          ["Ammo Depot Alpha"] = {
            name = "Ammo Depot Alpha",
            weaponCountCurrent = 100
          },
          ["Ammo Depot Empty"] = {
            name = "Ammo Depot Empty",
            weaponCountCurrent = 0
          }
        }
      })
    end)

    -- Positive: clears ammo depot ammo on destruction
    it("should set weaponCountCurrent to 0 when ammo depot with ammo is destroyed", function()
      local unit = { name = "Ammo Depot Alpha" }

      local result, detail = Context.processSupplyAssetDestruction(unit, mockSystemCtx)

      assert.is_true(result)
      assert.are.equal(0, mockSystemCtx.ammunitions["Ammo Depot Alpha"].weaponCountCurrent)
      assert.are.equal("ammo_depot", detail.role)
      assert.are.equal(100, detail.ammoBefore)
      assert.are.equal(0, detail.ammoAfter)
      assert.are.equal(-100, detail.delta)
    end)

    -- Positive: reduces resupply ammo proportionally on destruction
    it("should reduce weaponCountCurrent proportionally when resupply unit is destroyed", function()
      local unit = {
        name = "Resupply Vehicle 1",
        group = { name = "Resupply Group Alpha" }
      }

      local result, detail = Context.processSupplyAssetDestruction(unit, mockSystemCtx)

      assert.is_true(result)
      assert.are.equal(15, mockSystemCtx.resupplyUnits["Resupply Group Alpha"].weaponCountCurrent)
      assert.are.equal("resupply_unit", detail.role)
      assert.are.equal("Resupply Group Alpha", detail.contextName)
      assert.are.equal(20, detail.ammoBefore)
      assert.are.equal(15, detail.ammoAfter)
      assert.are.equal(-5, detail.delta)
    end)

    -- Boundary: clamps resupply ammo at zero
    it("should set weaponCountCurrent to 0 when reduction would go negative", function()
      local unit = {
        name = "Resupply Vehicle 1",
        group = { name = "Resupply Group Beta" }
      }

      local result = Context.processSupplyAssetDestruction(unit, mockSystemCtx)

      assert.is_true(result)
      assert.are.equal(0, mockSystemCtx.resupplyUnits["Resupply Group Beta"].weaponCountCurrent)
    end)

    -- Negative: returns false when resupply unit has no ammo
    it("should return false when resupply unit has no ammo", function()
      local unit = {
        name = "Resupply Vehicle 1",
        group = { name = "Resupply Group Empty" }
      }

      local result, detail = Context.processSupplyAssetDestruction(unit, mockSystemCtx)

      assert.is_false(result)
      assert.is_nil(detail)
      assert.are.equal(0, mockSystemCtx.resupplyUnits["Resupply Group Empty"].weaponCountCurrent)
    end)

    -- Negative: returns false for unknown units
    it("should return false when unit is not in ammunitions or resupplyUnits", function()
      local unit = {
        name = "Unknown Unit",
        group = { name = "Unknown Group" }
      }

      local result = Context.processSupplyAssetDestruction(unit, mockSystemCtx)

      assert.is_false(result)
    end)

    -- Positive: handles multiple destructions correctly
    it("should handle multiple destructions correctly", function()
      local unit1 = {
        name = "Resupply Vehicle 1",
        group = { name = "Resupply Group Alpha" }
      }
      local unit2 = {
        name = "Resupply Vehicle 2",
        group = { name = "Resupply Group Alpha" }
      }

      Context.processSupplyAssetDestruction(unit1, mockSystemCtx)
      Context.processSupplyAssetDestruction(unit2, mockSystemCtx)

      assert.are.equal(10, mockSystemCtx.resupplyUnits["Resupply Group Alpha"].weaponCountCurrent)
    end)

    -- Positive: prioritizes ammo depot match over resupply group match
    it("should prioritize ammo depot match over resupply unit match", function()
      mockSystemCtx.resupplyUnits["Ammo Depot Alpha"] = {
        name = "Ammo Depot Alpha",
        weaponCountCurrent = 50,
        weaponCountDefault = 50,
        unitCount = 5
      }

      local unit = { name = "Ammo Depot Alpha" }

      local result = Context.processSupplyAssetDestruction(unit, mockSystemCtx)

      assert.is_true(result)
      assert.are.equal(0, mockSystemCtx.ammunitions["Ammo Depot Alpha"].weaponCountCurrent)
      assert.are.equal(50, mockSystemCtx.resupplyUnits["Ammo Depot Alpha"].weaponCountCurrent)
    end)
  end)

  -- ============================================================================
  -- ensureGroundState
  -- ============================================================================

  describe("ensureGroundState", function()
    -- Positive: every configured system gets its full default state; timers stay in config
    it("should create default state for each configured system", function()
      local missileSystemConfigMap = { srbm = { reloadTime = 300, stowTime = 60 } }
      local groundCtx = {}

      Context.ensureGroundState(missileSystemConfigMap, groundCtx)

      assert.are.same({
        name = "srbm",
        enabled = true,
        ammunitions = {},
        resupplyUnits = {},
        firingUnits = {},
      }, groundCtx.missileSystemTypes.srbm)
    end)

    -- Positive: extras seeded elsewhere (Taiwan ascm.test) must survive seeding
    it("should keep fields already present on the system state", function()
      local test = { isAntishipMissionActivated = false }
      local firingUnits = { ["FU-1"] = { name = "FU-1" } }
      local missileSystemConfigMap = { ascm = { reloadTime = 1, stowTime = 1 } }
      local groundCtx = { missileSystemTypes = { ascm = { test = test, enabled = false, firingUnits = firingUnits } } }

      Context.ensureGroundState(missileSystemConfigMap, groundCtx)

      assert.are.equal(test, groundCtx.missileSystemTypes.ascm.test)
      assert.is_false(groundCtx.missileSystemTypes.ascm.enabled)
      assert.are.equal(firingUnits, groundCtx.missileSystemTypes.ascm.firingUnits)
    end)

    -- Negative: side-level keys that are not systems are left alone
    it("should not touch ground keys absent from config", function()
      local missileSystemConfigMap = {}
      local groundCtx = { enabled = true, fireSupportPlan = {} }

      Context.ensureGroundState(missileSystemConfigMap, groundCtx)

      assert.are.same({ enabled = true, fireSupportPlan = {}, missileSystemTypes = {} }, groundCtx)
    end)
  end)

  -- ============================================================================
  -- initMissileSystemContexts
  -- ============================================================================

  describe("initMissileSystemContexts", function()
    -- Positive: initializes firing unit contexts from config
    it("should deep copy firing unit descriptors", function()
      local missileSystemConfigMap = {
        system1 = {
          firingUnits = {
            fu1 = { name = "FU-1", state = 0 }
          },
          resupplyUnits = {},
          ammunitions = {}
        }
      }
      local groundCtx = {
        missileSystemTypes = {
          system1 = { firingUnits = {}, resupplyUnits = {}, ammunitions = {} }
        }
      }

      Context.initMissileSystemContexts(missileSystemConfigMap, groundCtx)

      local ctx = groundCtx.missileSystemTypes.system1.firingUnits["FU-1"]
      assert.is_not_nil(ctx)
      assert.are.equal("FU-1", ctx.name)
      assert.are_not.equal(missileSystemConfigMap.system1.firingUnits.fu1, ctx)
    end)

    -- Positive: initializes resupply unit contexts from config
    it("should deep copy resupply unit descriptors", function()
      local missileSystemConfigMap = {
        system1 = {
          firingUnits = {},
          resupplyUnits = {
            ru1 = { name = "RU-1", state = 0 }
          },
          ammunitions = {}
        }
      }
      local groundCtx = {
        missileSystemTypes = {
          system1 = { firingUnits = {}, resupplyUnits = {}, ammunitions = {} }
        }
      }

      Context.initMissileSystemContexts(missileSystemConfigMap, groundCtx)

      local ctx = groundCtx.missileSystemTypes.system1.resupplyUnits["RU-1"]
      assert.is_not_nil(ctx)
      assert.are.equal("RU-1", ctx.name)
      assert.are_not.equal(missileSystemConfigMap.system1.resupplyUnits.ru1, ctx)
    end)

    -- Positive: initializes ammunition contexts from config
    it("should deep copy ammunition descriptors into context", function()
      local missileSystemConfigMap = {
        system1 = {
          firingUnits = {},
          resupplyUnits = {},
          ammunitions = {
            ammo1 = { name = "Ammo-1", weaponCountCurrent = 50 }
          }
        }
      }
      local groundCtx = {
        missileSystemTypes = {
          system1 = { firingUnits = {}, resupplyUnits = {}, ammunitions = {} }
        }
      }

      Context.initMissileSystemContexts(missileSystemConfigMap, groundCtx)

      local ctx = groundCtx.missileSystemTypes.system1.ammunitions["Ammo-1"]
      assert.is_not_nil(ctx)
      assert.are.equal("Ammo-1", ctx.name)
      assert.are.equal(50, ctx.weaponCountCurrent)
    end)

    -- Positive: isolates context from config references
    it("should not share references between config and context", function()
      local missileSystemConfigMap = {
        system1 = {
          firingUnits = {
            fu1 = { name = "FU-1", state = 0, operationalArea = { name = "OA-1" } }
          },
          resupplyUnits = {},
          ammunitions = {}
        }
      }
      local groundCtx = {
        missileSystemTypes = {
          system1 = { firingUnits = {}, resupplyUnits = {}, ammunitions = {} }
        }
      }

      Context.initMissileSystemContexts(missileSystemConfigMap, groundCtx)

      groundCtx.missileSystemTypes.system1.firingUnits["FU-1"].operationalArea.name = "CHANGED"
      assert.are.equal("OA-1", missileSystemConfigMap.system1.firingUnits.fu1.operationalArea.name)
    end)

    -- Positive: initializes contexts for multiple systems
    it("should initialize contexts for multiple missile systems", function()
      local missileSystemConfigMap = {
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
      local groundCtx = {
        missileSystemTypes = {
          sysA = { firingUnits = {}, resupplyUnits = {}, ammunitions = {} },
          sysB = { firingUnits = {}, resupplyUnits = {}, ammunitions = {} }
        }
      }

      Context.initMissileSystemContexts(missileSystemConfigMap, groundCtx)

      assert.is_not_nil(groundCtx.missileSystemTypes.sysA.firingUnits["A"])
      assert.is_not_nil(groundCtx.missileSystemTypes.sysB.resupplyUnits["B"])
    end)
  end)
end)
