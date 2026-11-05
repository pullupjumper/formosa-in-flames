---@diagnostic disable: need-check-nil, assign-type-mismatch, cast-local-type, param-type-mismatch, inject-field, missing-fields
-- MissileSystem GroundStateStore Unit Tests
local stub = require("luassert.stub")
local GroundStateStore = require("src.modules.missileSystem.groundStateStore")
local constants = require("src.core.constants")
local Logger = require("src.utils.logger")

describe("MissileSystem GroundStateStore", function()
  ---@type luassert.spy[]
  local activeStubs

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
    local mockSystemState

    before_each(function()
      mockSystemState = makeSystemState({
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

      local result, detail = GroundStateStore.processSupplyAssetDestruction(unit, mockSystemState)

      assert.is_true(result)
      assert.are.equal(0, mockSystemState.ammunitions["Ammo Depot Alpha"].weaponCountCurrent)
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

      local result, detail = GroundStateStore.processSupplyAssetDestruction(unit, mockSystemState)

      assert.is_true(result)
      assert.are.equal(15, mockSystemState.resupplyUnits["Resupply Group Alpha"].weaponCountCurrent)
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

      local result = GroundStateStore.processSupplyAssetDestruction(unit, mockSystemState)

      assert.is_true(result)
      assert.are.equal(0, mockSystemState.resupplyUnits["Resupply Group Beta"].weaponCountCurrent)
    end)

    -- Negative: returns false when resupply unit has no ammo
    it("should return false when resupply unit has no ammo", function()
      local unit = {
        name = "Resupply Vehicle 1",
        group = { name = "Resupply Group Empty" }
      }

      local result, detail = GroundStateStore.processSupplyAssetDestruction(unit, mockSystemState)

      assert.is_false(result)
      assert.is_nil(detail)
      assert.are.equal(0, mockSystemState.resupplyUnits["Resupply Group Empty"].weaponCountCurrent)
    end)

    -- Negative: returns false for unknown units
    it("should return false when unit is not in ammunitions or resupplyUnits", function()
      local unit = {
        name = "Unknown Unit",
        group = { name = "Unknown Group" }
      }

      local result = GroundStateStore.processSupplyAssetDestruction(unit, mockSystemState)

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

      GroundStateStore.processSupplyAssetDestruction(unit1, mockSystemState)
      GroundStateStore.processSupplyAssetDestruction(unit2, mockSystemState)

      assert.are.equal(10, mockSystemState.resupplyUnits["Resupply Group Alpha"].weaponCountCurrent)
    end)

    -- Positive: prioritizes ammo depot match over resupply group match
    it("should prioritize ammo depot match over resupply unit match", function()
      mockSystemState.resupplyUnits["Ammo Depot Alpha"] = {
        name = "Ammo Depot Alpha",
        weaponCountCurrent = 50,
        weaponCountDefault = 50,
        unitCount = 5
      }

      local unit = { name = "Ammo Depot Alpha" }

      local result = GroundStateStore.processSupplyAssetDestruction(unit, mockSystemState)

      assert.is_true(result)
      assert.are.equal(0, mockSystemState.ammunitions["Ammo Depot Alpha"].weaponCountCurrent)
      assert.are.equal(50, mockSystemState.resupplyUnits["Ammo Depot Alpha"].weaponCountCurrent)
    end)
  end)

  -- ============================================================================
  -- resolvePair
  -- ============================================================================

  describe("resolvePair", function()
    local systemState

    before_each(function()
      systemState = {
        firingUnits = {
          ["FU1"] = { name = "FU1", resupplyUnit = "RU1" },
          ["FU2"] = { name = "FU2", resupplyUnit = "RU-missing" },
        },
        resupplyUnits = {
          ["RU1"] = { name = "RU1", firingUnit = "FU1", ammunition = "AD1" },
          ["RU2"] = { name = "RU2", firingUnit = "FU-missing", ammunition = "AD-missing" },
        },
        ammunitions = {
          ["AD1"] = { name = "AD1" },
        },
      }
    end)

    local cases = {
      -- Positive: either end of the pair resolves the whole chain
      { desc = "firing unit name", unitName = "FU1", firing = "FU1", resupply = "RU1", depot = "AD1" },
      { desc = "resupply unit name", unitName = "RU1", firing = "FU1", resupply = "RU1", depot = "AD1" },
      -- Negative: a missing link leaves that end and everything past it nil
      { desc = "firing unit whose resupply unit is missing", unitName = "FU2", firing = "FU2" },
      { desc = "resupply unit whose partners are missing", unitName = "RU2", resupply = "RU2" },
      { desc = "unknown name", unitName = "nobody" },
    }

    for _, case in ipairs(cases) do
      it("should resolve the pair from a " .. case.desc, function()
        local firingUnitState, resupplyUnitState, ammoDepotState = GroundStateStore.resolvePair(systemState, case.unitName)

        assert.are.equal(case.firing, firingUnitState and firingUnitState.name)
        assert.are.equal(case.resupply, resupplyUnitState and resupplyUnitState.name)
        assert.are.equal(case.depot, ammoDepotState and ammoDepotState.name)
      end)
    end
  end)

  -- ============================================================================
  -- ensureGroundState
  -- ============================================================================

  describe("ensureGroundState", function()
    -- Positive: every configured system gets its full default state; timers stay in config
    it("should create default state for each configured system", function()
      local missileSystemConfigMap = { srbm = { reloadTime = 300, stowTime = 60 } }
      local groundState = {}

      GroundStateStore.ensureGroundState(missileSystemConfigMap, groundState)

      assert.are.same({
        name = "srbm",
        enabled = true,
        ammunitions = {},
        resupplyUnits = {},
        firingUnits = {},
      }, groundState.missileSystemTypes.srbm)
    end)

    -- Positive: extras seeded elsewhere (Taiwan ascm.test) must survive seeding
    it("should keep fields already present on the system state", function()
      local test = { isAntishipMissionActivated = false }
      local firingUnits = { ["FU-1"] = { name = "FU-1" } }
      local missileSystemConfigMap = { ascm = { reloadTime = 1, stowTime = 1 } }
      local groundState = { missileSystemTypes = { ascm = { test = test, enabled = false, firingUnits = firingUnits } } }

      GroundStateStore.ensureGroundState(missileSystemConfigMap, groundState)

      assert.are.equal(test, groundState.missileSystemTypes.ascm.test)
      assert.is_false(groundState.missileSystemTypes.ascm.enabled)
      assert.are.equal(firingUnits, groundState.missileSystemTypes.ascm.firingUnits)
    end)

    -- Negative: side-level keys that are not systems are left alone
    it("should not touch ground keys absent from config", function()
      local missileSystemConfigMap = {}
      local groundState = { enabled = true, fireSupportPlan = {} }

      GroundStateStore.ensureGroundState(missileSystemConfigMap, groundState)

      assert.are.same({ enabled = true, fireSupportPlan = {}, missileSystemTypes = {} }, groundState)
    end)
  end)

  -- ============================================================================
  -- setBatteryStates
  -- ============================================================================

  describe("setBatteryStates", function()
    ---One battery whose config descriptors carry the config area
    local function buildBattery(suffix, area)
      local configArea = { name = "OPAREA-CONFIG-" .. suffix }
      return {
        missileSystemType = "srbm",
        firing = { name = "FU-" .. suffix, state = 0, operationalArea = configArea },
        resupply = { name = "RU-" .. suffix, weaponCountCurrent = 8, operationalArea = configArea },
        depot = { name = "AMMO-" .. suffix, weaponCountCurrent = 40 },
        unitCount = 1,
        operationalArea = area or configArea
      }
    end

    local function buildGroundState()
      return { missileSystemTypes = { srbm = { firingUnits = {}, resupplyUnits = {}, ammunitions = {} } } }
    end

    -- Positive: the three units get fresh state copies at the battery's area
    it("should copy the battery's descriptors into state at the battery's area", function()
      local battery = buildBattery("A", { name = "OPAREA-NEW" })
      local groundState = buildGroundState()

      GroundStateStore.setBatteryStates(groundState, { battery })

      local systemState = groundState.missileSystemTypes.srbm
      assert.are.equal("OPAREA-NEW", systemState.firingUnits["FU-A"].operationalArea.name)
      assert.are.equal("OPAREA-NEW", systemState.resupplyUnits["RU-A"].operationalArea.name)
      assert.are.equal(8, systemState.resupplyUnits["RU-A"].weaponCountCurrent)
      assert.are.equal(40, systemState.ammunitions["AMMO-A"].weaponCountCurrent)
    end)

    -- Negative: state must not alias config or the battery, or runtime writes would leak back
    it("should not share tables with config or the battery's area", function()
      local battery = buildBattery("A")
      local groundState = buildGroundState()

      GroundStateStore.setBatteryStates(groundState, { battery })

      local systemState = groundState.missileSystemTypes.srbm
      systemState.firingUnits["FU-A"].operationalArea.name = "CHANGED"
      systemState.ammunitions["AMMO-A"].weaponCountCurrent = 0
      assert.are.equal("OPAREA-CONFIG-A", battery.firing.operationalArea.name)
      assert.are.equal(40, battery.depot.weaponCountCurrent)
    end)

    -- Negative: a battery that is not given keeps its runtime state
    it("should leave other batteries' state untouched", function()
      local groundState = buildGroundState()
      local untouched = { name = "FU-B", state = 3, reloadStartTime = 123 }
      groundState.missileSystemTypes.srbm.firingUnits["FU-B"] = untouched

      GroundStateStore.setBatteryStates(groundState, { buildBattery("A") })

      assert.are.equal(untouched, groundState.missileSystemTypes.srbm.firingUnits["FU-B"])
      assert.are.equal(123, untouched.reloadStartTime)
    end)
  end)

  -- ============================================================================
  -- resolveOperationalArea
  -- ============================================================================

  describe("resolveOperationalArea", function()
    local configArea = { name = "OPAREA-CONFIG" }
    local descriptor = { name = "FU-A", operationalArea = configArea }

    -- Positive: a battery with state is where its state says
    it("should return the saved state's area", function()
      local savedArea = { name = "OPAREA-SAVED" }
      local groundState = { missileSystemTypes = { srbm = { firingUnits = {
        ["FU-A"] = { name = "FU-A", operationalArea = savedArea }
      } } } }

      assert.are.equal(savedArea, GroundStateStore.resolveOperationalArea(groundState, "srbm", descriptor))
    end)

    -- Boundary: before the first deploy there is no state, so the config area is current
    it("should fall back to the config area when the battery has no state", function()
      assert.are.equal(configArea, GroundStateStore.resolveOperationalArea({}, "srbm", descriptor))
      assert.are.equal(configArea, GroundStateStore.resolveOperationalArea(
        { missileSystemTypes = { srbm = { firingUnits = {} } } }, "srbm", descriptor))
    end)
  end)
end)
