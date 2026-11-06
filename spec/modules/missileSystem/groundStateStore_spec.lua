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
        launchers = {},
        transloaders = {
          ["Resupply Group Alpha"] = { name = "Resupply Group Alpha", weaponCountDefault = 20, unitCount = 4 },
          ["Resupply Group Beta"] = { name = "Resupply Group Beta", weaponCountDefault = 20, unitCount = 4 },
          ["Resupply Group Empty"] = { name = "Resupply Group Empty", weaponCountDefault = 20, unitCount = 4 },
        },
        canisterStocks = {},
      }
      mockSystemState = {
        name = "srbm",
        launchers = {},
        transloaders = {
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

    -- Positive: reduces transloader ammo proportionally on destruction
    it("should reduce weaponCountCurrent proportionally when transloader is destroyed", function()
      local unit = {
        name = "Resupply Vehicle 1",
        group = { name = "Resupply Group Alpha" }
      }

      local result, detail = GroundStateStore.processSupplyAssetDestruction(unit, mockSystemConfig, mockSystemState)

      assert.is_true(result)
      assert.are.equal(15, mockSystemState.transloaders["Resupply Group Alpha"].weaponCountCurrent)
      assert.are.equal("transloader", detail.role)
      assert.are.equal("Resupply Group Alpha", detail.contextName)
      assert.are.equal(20, detail.ammoBefore)
      assert.are.equal(15, detail.ammoAfter)
      assert.are.equal(-5, detail.delta)
    end)

    -- Boundary: clamps transloader ammo at zero
    it("should set weaponCountCurrent to 0 when reduction would go negative", function()
      local unit = {
        name = "Resupply Vehicle 1",
        group = { name = "Resupply Group Beta" }
      }

      local result = GroundStateStore.processSupplyAssetDestruction(unit, mockSystemConfig, mockSystemState)

      assert.is_true(result)
      assert.are.equal(0, mockSystemState.transloaders["Resupply Group Beta"].weaponCountCurrent)
    end)

    -- Negative: returns false when transloader has no ammo
    it("should return false when transloader has no ammo", function()
      local unit = {
        name = "Resupply Vehicle 1",
        group = { name = "Resupply Group Empty" }
      }

      local result, detail = GroundStateStore.processSupplyAssetDestruction(unit, mockSystemConfig, mockSystemState)

      assert.is_false(result)
      assert.is_nil(detail)
      assert.are.equal(0, mockSystemState.transloaders["Resupply Group Empty"].weaponCountCurrent)
    end)

    -- Negative: returns false for unknown units
    it("should return false when unit is not in canisterStocks or transloaders", function()
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

      assert.are.equal(10, mockSystemState.transloaders["Resupply Group Alpha"].weaponCountCurrent)
    end)

    -- Positive: prioritizes canister stock match over transloader group match
    it("should prioritize canister stock match over transloader match", function()
      mockSystemConfig.transloaders["Canister Stock Alpha"] = {
        name = "Canister Stock Alpha",
        weaponCountDefault = 50,
        unitCount = 5
      }
      mockSystemState.transloaders["Canister Stock Alpha"] = { name = "Canister Stock Alpha", weaponCountCurrent = 50 }

      local unit = { name = "Canister Stock Alpha" }

      local result = GroundStateStore.processSupplyAssetDestruction(unit, mockSystemConfig, mockSystemState)

      assert.is_true(result)
      assert.are.equal(0, mockSystemState.canisterStocks["Canister Stock Alpha"].weaponCountCurrent)
      assert.are.equal(50, mockSystemState.transloaders["Canister Stock Alpha"].weaponCountCurrent)
    end)

    -- Positive: ammo per vehicle follows config, so a config change reaches an old save
    it("should take each vehicle's share from the config descriptor", function()
      mockSystemConfig.transloaders["Resupply Group Alpha"].weaponCountDefault = 40
      local unit = { name = "Resupply Vehicle 1", group = { name = "Resupply Group Alpha" } }

      GroundStateStore.processSupplyAssetDestruction(unit, mockSystemConfig, mockSystemState)

      assert.are.equal(10, mockSystemState.transloaders["Resupply Group Alpha"].weaponCountCurrent)
    end)

    -- Negative: a transloader state whose battery config dropped is left alone
    it("should return false when the transloader has no config descriptor", function()
      mockSystemConfig.transloaders["Resupply Group Alpha"] = nil
      local unit = { name = "Resupply Vehicle 1", group = { name = "Resupply Group Alpha" } }

      assert.is_false(GroundStateStore.processSupplyAssetDestruction(unit, mockSystemConfig, mockSystemState))
      assert.are.equal(20, mockSystemState.transloaders["Resupply Group Alpha"].weaponCountCurrent)
    end)
  end)

  -- ============================================================================
  -- resolvePair
  -- ============================================================================

  describe("resolvePair", function()
    local systemConfig, systemState

    before_each(function()
      systemConfig = {
        launchers = {
          ["FU1"] = { name = "FU1", transloader = "RU1" },
          ["FU2"] = { name = "FU2", transloader = "RU2" },
        },
        transloaders = {
          ["RU1"] = { name = "RU1", launcher = "FU1", canisterStock = "AD1" },
          ["RU2"] = { name = "RU2", launcher = "FU2", canisterStock = "AD2" },
        },
        canisterStocks = {
          ["AD1"] = { name = "AD1" },
          ["AD2"] = { name = "AD2" },
        },
      }
      systemState = {
        launchers = { ["FU1"] = { name = "FU1" } },
        transloaders = { ["RU1"] = { name = "RU1" } },
        canisterStocks = { ["AD1"] = { name = "AD1" } },
      }
    end)

    local cases = {
      -- Positive: either end of the pair resolves the whole chain
      { desc = "launcher name", unitName = "FU1", launcher = "FU1", transloader = "RU1", canisterStock = "AD1" },
      { desc = "transloader name", unitName = "RU1", launcher = "FU1", transloader = "RU1", canisterStock = "AD1" },
      -- Negative: an untracked state is nil, the others still resolve through config links
      { desc = "launcher whose partners have no state", unitName = "FU2", stateless = { "RU2", "AD2" }, launcher = "FU2" },
      { desc = "transloader whose launcher has no state", unitName = "RU1", stateless = { "FU1" }, transloader = "RU1", canisterStock = "AD1" },
      { desc = "unknown name", unitName = "nobody" },
    }

    for _, case in ipairs(cases) do
      it("should resolve the pair from a " .. case.desc, function()
        systemState.launchers["FU2"] = { name = "FU2" }
        for _, name in ipairs(case.stateless or {}) do
          systemState.launchers[name], systemState.transloaders[name], systemState.canisterStocks[name] = nil, nil, nil
        end

        local launcherState, transloaderState, canisterStockState = GroundStateStore.resolvePair(
          systemConfig, systemState, case.unitName
        )

        assert.are.equal(case.launcher, launcherState and launcherState.name)
        assert.are.equal(case.transloader, transloaderState and transloaderState.name)
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
        transloaders = {},
        launchers = {},
      }, groundState.missileSystemTypes.srbm)
    end)

    -- Positive: extras seeded elsewhere (Taiwan ascm.test) must survive seeding
    it("should keep fields already present on the system state", function()
      local test = { isAntishipMissionActivated = false }
      local launchers = { ["FU-1"] = { name = "FU-1" } }
      local missileSystemConfigMap = { ascm = { reloadTime = 1, stowTime = 1 } }
      local groundState = { missileSystemTypes = { ascm = { test = test, enabled = false, launchers = launchers } } }

      GroundStateStore.ensureGroundState(missileSystemConfigMap, groundState)

      assert.are.equal(test, groundState.missileSystemTypes.ascm.test)
      assert.is_false(groundState.missileSystemTypes.ascm.enabled)
      assert.are.equal(launchers, groundState.missileSystemTypes.ascm.launchers)
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
        launcher = {
          name = "FU-" .. suffix, state = 0, operationalArea = configArea, transloader = "RU-" .. suffix,
          weaponDBID = 1234, ammoThreshold = 60, msg = "Radio source", dbid = 99, missileSystem = "DF-15",
        },
        transloader = {
          name = "RU-" .. suffix, state = 1, operationalArea = configArea, weaponCountCurrent = 8,
          weaponCountDefault = 8, unitCount = 2, canisterStock = "AMMO-" .. suffix, launcher = "FU-" .. suffix,
        },
        canisterStock = { name = "AMMO-" .. suffix, weaponCountCurrent = 40, weaponCountDefault = 40 },
        unitCount = 1,
        operationalArea = area or configArea
      }
    end

    local function buildGroundState()
      return { missileSystemTypes = { srbm = { launchers = {}, transloaders = {}, canisterStocks = {} } } }
    end

    -- Positive: the three units get fresh state copies at the battery's area
    it("should copy the battery's descriptors into state at the battery's area", function()
      local battery = buildBattery("A", { name = "OPAREA-NEW" })
      local groundState = buildGroundState()

      GroundStateStore.resetBatteryStates(groundState, { battery })

      local systemState = groundState.missileSystemTypes.srbm
      assert.are.equal("OPAREA-NEW", systemState.launchers["FU-A"].operationalArea.name)
      assert.are.equal("OPAREA-NEW", systemState.transloaders["RU-A"].operationalArea.name)
      assert.are.equal(8, systemState.transloaders["RU-A"].weaponCountCurrent)
      assert.are.equal(40, systemState.canisterStocks["AMMO-A"].weaponCountCurrent)
    end)

    -- Positive: state holds only what changes at runtime; everything else stays in config
    it("should keep only runtime values in state", function()
      local area = { name = "OPAREA-NEW" }
      local groundState = buildGroundState()

      GroundStateStore.resetBatteryStates(groundState, { buildBattery("A", area) })

      assert.are.same({
        launchers = { ["FU-A"] = { name = "FU-A", state = 0, operationalArea = area } },
        transloaders = { ["RU-A"] = { name = "RU-A", state = 1, operationalArea = area, weaponCountCurrent = 8 } },
        canisterStocks = { ["AMMO-A"] = { name = "AMMO-A", weaponCountCurrent = 40 } },
      }, groundState.missileSystemTypes.srbm)
    end)

    -- Negative: state must not alias config or the battery, or runtime writes would leak back
    it("should not share tables with config or the battery's area", function()
      local battery = buildBattery("A")
      local groundState = buildGroundState()

      GroundStateStore.resetBatteryStates(groundState, { battery })

      local systemState = groundState.missileSystemTypes.srbm
      systemState.launchers["FU-A"].operationalArea.name = "CHANGED"
      systemState.canisterStocks["AMMO-A"].weaponCountCurrent = 0
      assert.are.equal("OPAREA-CONFIG-A", battery.launcher.operationalArea.name)
      assert.are.equal(40, battery.canisterStock.weaponCountCurrent)
    end)

    -- Negative: a battery that is not given keeps its runtime state
    it("should leave other batteries' state untouched", function()
      local groundState = buildGroundState()
      local untouched = { name = "FU-B", state = 3, reloadStartTime = 123 }
      groundState.missileSystemTypes.srbm.launchers["FU-B"] = untouched

      GroundStateStore.resetBatteryStates(groundState, { buildBattery("A") })

      assert.are.equal(untouched, groundState.missileSystemTypes.srbm.launchers["FU-B"])
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
      local groundState = { missileSystemTypes = { srbm = { launchers = {
        ["FU-A"] = { name = "FU-A", operationalArea = savedArea }
      } } } }

      assert.are.equal(savedArea, GroundStateStore.resolveOperationalArea(groundState, "srbm", descriptor))
    end)

    -- Boundary: before the first deploy there is no state, so the config area is current
    it("should fall back to the config area when the battery has no state", function()
      assert.are.equal(configArea, GroundStateStore.resolveOperationalArea({}, "srbm", descriptor))
      assert.are.equal(configArea, GroundStateStore.resolveOperationalArea(
        { missileSystemTypes = { srbm = { launchers = {} } } }, "srbm", descriptor))
    end)

    -- Boundary: an older save copied the config area without its name, so redeploy could not find its zones
    it("should return the config area when the state area has no name", function()
      local groundState = { missileSystemTypes = { srbm = { launchers = { ["FU-A"] = { operationalArea = {} } } } } }
      assert.are.equal(configArea, GroundStateStore.resolveOperationalArea(groundState, "srbm", descriptor))
    end)
  end)
end)
