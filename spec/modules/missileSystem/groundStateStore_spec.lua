---@diagnostic disable: need-check-nil, assign-type-mismatch, cast-local-type, param-type-mismatch, inject-field, missing-fields
-- MissileSystem GroundStateStore Unit Tests
local stub = require("luassert.stub")
local GroundStateStore = require("src.modules.missileSystem.groundStateStore")
local Logger = require("src.utils.logger")

describe("MissileSystem GroundStateStore", function()
  ---@type luassert.spy[]
  local activeStubs

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
    local mockSystemConfig, mockSystemState

    before_each(function()
      mockSystemConfig = {
        firingUnits = {},
        resupplyUnits = {
          ["Resupply Group Alpha"] = { name = "Resupply Group Alpha", weaponCountDefault = 20, unitCount = 4 },
          ["Resupply Group Beta"] = { name = "Resupply Group Beta", weaponCountDefault = 20, unitCount = 4 },
          ["Resupply Group Empty"] = { name = "Resupply Group Empty", weaponCountDefault = 20, unitCount = 4 },
        },
        canisterStocks = {},
      }
      mockSystemState = {
        name = "srbm",
        firingUnits = {},
        resupplyUnits = {
          ["Resupply Group Alpha"] = { name = "Resupply Group Alpha", weaponCountCurrent = 20 },
          ["Resupply Group Beta"] = { name = "Resupply Group Beta", weaponCountCurrent = 3 },
          ["Resupply Group Empty"] = { name = "Resupply Group Empty", weaponCountCurrent = 0 },
        },
        canisterStocks = {
          ["Canister Stock Alpha"] = {
            name = "Canister Stock Alpha",
            weaponCountCurrent = 100
          },
          ["Canister Stock Empty"] = {
            name = "Canister Stock Empty",
            weaponCountCurrent = 0
          }
        }
      }
    end)

    -- Positive: clears canister stock ammo on destruction
    it("should set weaponCountCurrent to 0 when canister stock with ammo is destroyed", function()
      local unit = { name = "Canister Stock Alpha" }

      local result, detail = GroundStateStore.processSupplyAssetDestruction(unit, mockSystemConfig, mockSystemState)

      assert.is_true(result)
      assert.are.equal(0, mockSystemState.canisterStocks["Canister Stock Alpha"].weaponCountCurrent)
      assert.are.equal("canister_stock", detail.role)
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

      local result, detail = GroundStateStore.processSupplyAssetDestruction(unit, mockSystemConfig, mockSystemState)

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

      local result = GroundStateStore.processSupplyAssetDestruction(unit, mockSystemConfig, mockSystemState)

      assert.is_true(result)
      assert.are.equal(0, mockSystemState.resupplyUnits["Resupply Group Beta"].weaponCountCurrent)
    end)

    -- Negative: returns false when resupply unit has no ammo
    it("should return false when resupply unit has no ammo", function()
      local unit = {
        name = "Resupply Vehicle 1",
        group = { name = "Resupply Group Empty" }
      }

      local result, detail = GroundStateStore.processSupplyAssetDestruction(unit, mockSystemConfig, mockSystemState)

      assert.is_false(result)
      assert.is_nil(detail)
      assert.are.equal(0, mockSystemState.resupplyUnits["Resupply Group Empty"].weaponCountCurrent)
    end)

    -- Negative: returns false for unknown units
    it("should return false when unit is not in canisterStocks or resupplyUnits", function()
      local unit = {
        name = "Unknown Unit",
        group = { name = "Unknown Group" }
      }

      local result = GroundStateStore.processSupplyAssetDestruction(unit, mockSystemConfig, mockSystemState)

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

      GroundStateStore.processSupplyAssetDestruction(unit1, mockSystemConfig, mockSystemState)
      GroundStateStore.processSupplyAssetDestruction(unit2, mockSystemConfig, mockSystemState)

      assert.are.equal(10, mockSystemState.resupplyUnits["Resupply Group Alpha"].weaponCountCurrent)
    end)

    -- Positive: prioritizes canister stock match over resupply group match
    it("should prioritize canister stock match over resupply unit match", function()
      mockSystemConfig.resupplyUnits["Canister Stock Alpha"] = {
        name = "Canister Stock Alpha",
        weaponCountDefault = 50,
        unitCount = 5
      }
      mockSystemState.resupplyUnits["Canister Stock Alpha"] = { name = "Canister Stock Alpha", weaponCountCurrent = 50 }

      local unit = { name = "Canister Stock Alpha" }

      local result = GroundStateStore.processSupplyAssetDestruction(unit, mockSystemConfig, mockSystemState)

      assert.is_true(result)
      assert.are.equal(0, mockSystemState.canisterStocks["Canister Stock Alpha"].weaponCountCurrent)
      assert.are.equal(50, mockSystemState.resupplyUnits["Canister Stock Alpha"].weaponCountCurrent)
    end)

    -- Positive: ammo per vehicle follows config, so a config change reaches an old save
    it("should take each vehicle's share from the config descriptor", function()
      mockSystemConfig.resupplyUnits["Resupply Group Alpha"].weaponCountDefault = 40
      local unit = { name = "Resupply Vehicle 1", group = { name = "Resupply Group Alpha" } }

      GroundStateStore.processSupplyAssetDestruction(unit, mockSystemConfig, mockSystemState)

      assert.are.equal(10, mockSystemState.resupplyUnits["Resupply Group Alpha"].weaponCountCurrent)
    end)

    -- Negative: a resupply state whose battery config dropped is left alone
    it("should return false when the resupply unit has no config descriptor", function()
      mockSystemConfig.resupplyUnits["Resupply Group Alpha"] = nil
      local unit = { name = "Resupply Vehicle 1", group = { name = "Resupply Group Alpha" } }

      assert.is_false(GroundStateStore.processSupplyAssetDestruction(unit, mockSystemConfig, mockSystemState))
      assert.are.equal(20, mockSystemState.resupplyUnits["Resupply Group Alpha"].weaponCountCurrent)
    end)
  end)

  -- ============================================================================
  -- resolvePair
  -- ============================================================================

  describe("resolvePair", function()
    local systemConfig, systemState

    before_each(function()
      systemConfig = {
        firingUnits = {
          ["FU1"] = { name = "FU1", resupplyUnit = "RU1" },
          ["FU2"] = { name = "FU2", resupplyUnit = "RU2" },
        },
        resupplyUnits = {
          ["RU1"] = { name = "RU1", firingUnit = "FU1", canisterStock = "AD1" },
          ["RU2"] = { name = "RU2", firingUnit = "FU2", canisterStock = "AD2" },
        },
        canisterStocks = {
          ["AD1"] = { name = "AD1" },
          ["AD2"] = { name = "AD2" },
        },
      }
      systemState = {
        firingUnits = { ["FU1"] = { name = "FU1" } },
        resupplyUnits = { ["RU1"] = { name = "RU1" } },
        canisterStocks = { ["AD1"] = { name = "AD1" } },
      }
    end)

    local cases = {
      -- Positive: either end of the pair resolves the whole chain
      { desc = "firing unit name", unitName = "FU1", firing = "FU1", resupply = "RU1", canisterStock = "AD1" },
      { desc = "resupply unit name", unitName = "RU1", firing = "FU1", resupply = "RU1", canisterStock = "AD1" },
      -- Negative: an untracked state is nil, the others still resolve through config links
      { desc = "firing unit whose partners have no state", unitName = "FU2", stateless = { "RU2", "AD2" }, firing = "FU2" },
      { desc = "resupply unit whose firing unit has no state", unitName = "RU1", stateless = { "FU1" }, resupply = "RU1", canisterStock = "AD1" },
      { desc = "unknown name", unitName = "nobody" },
    }

    for _, case in ipairs(cases) do
      it("should resolve the pair from a " .. case.desc, function()
        systemState.firingUnits["FU2"] = { name = "FU2" }
        for _, name in ipairs(case.stateless or {}) do
          systemState.firingUnits[name], systemState.resupplyUnits[name], systemState.canisterStocks[name] = nil, nil, nil
        end

        local firingUnitState, resupplyUnitState, canisterStockState = GroundStateStore.resolvePair(
          systemConfig, systemState, case.unitName
        )

        assert.are.equal(case.firing, firingUnitState and firingUnitState.name)
        assert.are.equal(case.resupply, resupplyUnitState and resupplyUnitState.name)
        assert.are.equal(case.canisterStock, canisterStockState and canisterStockState.name)
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
        canisterStocks = {},
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
  -- resetBatteryStates
  -- ============================================================================

  describe("resetBatteryStates", function()
    ---One battery whose config descriptors carry the config area
    local function buildBattery(suffix, area)
      local configArea = { name = "OPAREA-CONFIG-" .. suffix }
      return {
        missileSystemType = "srbm",
        firing = {
          name = "FU-" .. suffix, state = 0, operationalArea = configArea, resupplyUnit = "RU-" .. suffix,
          weaponDBID = 1234, ammoThreshold = 60, msg = "Radio source", dbid = 99, missileSystem = "DF-15",
        },
        resupply = {
          name = "RU-" .. suffix, state = 1, operationalArea = configArea, weaponCountCurrent = 8,
          weaponCountDefault = 8, unitCount = 2, canisterStock = "AMMO-" .. suffix, firingUnit = "FU-" .. suffix,
        },
        canisterStock = { name = "AMMO-" .. suffix, weaponCountCurrent = 40, weaponCountDefault = 40 },
        unitCount = 1,
        operationalArea = area or configArea
      }
    end

    local function buildGroundState()
      return { missileSystemTypes = { srbm = { firingUnits = {}, resupplyUnits = {}, canisterStocks = {} } } }
    end

    -- Positive: the three units get fresh state copies at the battery's area
    it("should copy the battery's descriptors into state at the battery's area", function()
      local battery = buildBattery("A", { name = "OPAREA-NEW" })
      local groundState = buildGroundState()

      GroundStateStore.resetBatteryStates(groundState, { battery })

      local systemState = groundState.missileSystemTypes.srbm
      assert.are.equal("OPAREA-NEW", systemState.firingUnits["FU-A"].operationalArea.name)
      assert.are.equal("OPAREA-NEW", systemState.resupplyUnits["RU-A"].operationalArea.name)
      assert.are.equal(8, systemState.resupplyUnits["RU-A"].weaponCountCurrent)
      assert.are.equal(40, systemState.canisterStocks["AMMO-A"].weaponCountCurrent)
    end)

    -- Positive: state holds only what changes at runtime; everything else stays in config
    it("should keep only runtime values in state", function()
      local area = { name = "OPAREA-NEW" }
      local groundState = buildGroundState()

      GroundStateStore.resetBatteryStates(groundState, { buildBattery("A", area) })

      assert.are.same({
        firingUnits = { ["FU-A"] = { name = "FU-A", state = 0, operationalArea = area } },
        resupplyUnits = { ["RU-A"] = { name = "RU-A", state = 1, operationalArea = area, weaponCountCurrent = 8 } },
        canisterStocks = { ["AMMO-A"] = { name = "AMMO-A", weaponCountCurrent = 40 } },
      }, groundState.missileSystemTypes.srbm)
    end)

    -- Negative: state must not alias config or the battery, or runtime writes would leak back
    it("should not share tables with config or the battery's area", function()
      local battery = buildBattery("A")
      local groundState = buildGroundState()

      GroundStateStore.resetBatteryStates(groundState, { battery })

      local systemState = groundState.missileSystemTypes.srbm
      systemState.firingUnits["FU-A"].operationalArea.name = "CHANGED"
      systemState.canisterStocks["AMMO-A"].weaponCountCurrent = 0
      assert.are.equal("OPAREA-CONFIG-A", battery.firing.operationalArea.name)
      assert.are.equal(40, battery.canisterStock.weaponCountCurrent)
    end)

    -- Negative: a battery that is not given keeps its runtime state
    it("should leave other batteries' state untouched", function()
      local groundState = buildGroundState()
      local untouched = { name = "FU-B", state = 3, reloadStartTime = 123 }
      groundState.missileSystemTypes.srbm.firingUnits["FU-B"] = untouched

      GroundStateStore.resetBatteryStates(groundState, { buildBattery("A") })

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

    -- Boundary: an older save copied the config area without its name, so redeploy could not find its zones
    it("should return the config area when the state area has no name", function()
      local groundState = { missileSystemTypes = { srbm = { firingUnits = { ["FU-A"] = { operationalArea = {} } } } } }
      assert.are.equal(configArea, GroundStateStore.resolveOperationalArea(groundState, "srbm", descriptor))
    end)
  end)
end)
