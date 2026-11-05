---@diagnostic disable: need-check-nil, assign-type-mismatch, cast-local-type, param-type-mismatch, inject-field
-- MissileSystem CargoProxy Unit Tests
local stub = require("luassert.stub")
local CargoProxy = require("src.modules.missileSystem.cargoProxy")
local GameApi = require("src.utils.gameApi")
local Logger = require("src.utils.logger")
local constants = require("src.core.constants")

describe("MissileSystem CargoProxy", function()
  ---@type luassert.spy[]
  local activeStubs
  ---@type luassert.spy
  local logStub
  ---Track and register method stub for automatic cleanup.
  ---@param obj table
  ---@param method string
  ---@return luassert.spy
  local function trackStub(obj, method)
    local s = stub(obj, method)
    table.insert(activeStubs, s)
    return s
  end

  before_each(function()
    activeStubs = {}
    logStub = trackStub(Logger, "log")
    trackStub(Logger, "error")
  end)

  after_each(function()
    for i = #activeStubs, 1, -1 do
      activeStubs[i]:revert()
    end
    activeStubs = {}
  end)

  -- ============================================================================
  -- loadCargo
  -- ============================================================================

  describe("loadCargo", function()
    local stubUpdateCargo, stubClearMags, stubUpdateUnit, stubAddReloads, stubDeleteUnit

    ---Create a mount weapon descriptor
    ---@param overrides? table
    ---@return table
    local function makeMountWeapon(overrides)
      local wpn = {
        wpn_dbid = 500,
        wpn_current = 10,
      }
      if overrides then
        for k, v in pairs(overrides) do wpn[k] = v end
      end
      return wpn
    end

    ---Create a mount descriptor
    ---@param overrides? table
    ---@return table
    local function makeMount(overrides)
      local mount = {
        mount_dbid = 100,
        mount_guid = "MNT-001",
        mount_weapons = {},
      }
      if overrides then
        for k, v in pairs(overrides) do mount[k] = v end
      end
      return mount
    end

    ---Create a base ship whose cargo list holds the created cargo proxies
    ---@param overrides? table
    ---@return table
    local function makeBase(overrides)
      local base = { guid = "BASE-001", name = "BaseShip" }
      if overrides then
        for k, v in pairs(overrides) do base[k] = v end
      end
      return base
    end

    ---Create a unit with mounts for loadCargo testing
    ---@param overrides? table
    ---@return table
    local function makeLoadCargoUnit(overrides)
      local unit = {
        guid = "SRC-001",
        name = "Infantry-1",
        dbid = 7001,
        group = nil,
        mounts = {},
      }
      if overrides then
        for k, v in pairs(overrides) do unit[k] = v end
      end
      return unit
    end

    before_each(function()
      stubUpdateCargo = trackStub(GameApi, "ScenEdit_UpdateUnitCargo")
      stubClearMags = trackStub(GameApi, "ScenEdit_ClearAllMagazines")
      stubUpdateUnit = trackStub(GameApi, "ScenEdit_UpdateUnit")
      stubAddReloads = trackStub(GameApi, "ScenEdit_AddReloadsToUnit")
      stubDeleteUnit = trackStub(GameApi, "ScenEdit_DeleteUnit")
    end)

    -- Positive: should convert single unit (no group) to cargo
    it("should convert single unit (no group) to cargo", function()
      local sourceUnit = makeLoadCargoUnit({
        guid = "SRC-001",
        name = "Infantry-1",
        dbid = 7001,
        mounts = {
          makeMount({
            mount_dbid = 100,
            mount_guid = "MNT-S1",
            mount_weapons = { makeMountWeapon({ wpn_dbid = 500, wpn_current = 10 }) },
          }),
        },
      })

      local cargoProxy = makeLoadCargoUnit({
        guid = "CARGO-001",
        name = "CargoProxy",
        mounts = {
          makeMount({
            mount_dbid = 200,
            mount_guid = "MNT-P1",
            mount_weapons = { makeMountWeapon({ wpn_dbid = 500, wpn_default = 10 }) },
          }),
        },
      })

      local base = makeBase({
        guid = "BASE-001",
        name = "BaseShip",
        cargo = { [1] = { cargo = { [1] = { guid = "CARGO-001" } } } },
      })

      trackStub(GameApi, "ScenEdit_GetUnit").invokes(function(identifier, side)
        if identifier == "Infantry-1" and side == "Red" then return sourceUnit end
        if identifier == "SRC-001" then return sourceUnit end
        if identifier == "CARGO-001" then return cargoProxy end
        return nil
      end)

      CargoProxy.loadCargo(base, "Infantry-1", 500, "Red")

      assert.stub(stubUpdateCargo).was.called(1)
      assert.stub(stubClearMags).was.called(1)
      -- 1 remove_mount (proxy's existing mount) + 1 add_mount (source's mount) = 2
      assert.stub(stubUpdateUnit).was.called(2)
      -- 1 clear reload + 1 set reload = 2
      assert.stub(stubAddReloads).was.called(2)
      assert.stub(stubDeleteUnit).was.called(1)
      assert.stub(stubDeleteUnit).was.called_with({ guid = "SRC-001" })
    end)

    -- Positive: should convert group members to cargo
    it("should convert group members to cargo", function()
      local groupObj = { name = "Alpha", unitlist = { "MEM-001", "MEM-002" } }
      local member1 = makeLoadCargoUnit({
        guid = "MEM-001",
        name = "Inf-1",
        dbid = 7001,
        group = groupObj,
        mounts = { makeMount({ mount_dbid = 100, mount_guid = "MNT-1", mount_weapons = {} }) },
      })
      local member2 = makeLoadCargoUnit({
        guid = "MEM-002",
        name = "Inf-2",
        dbid = 7001,
        group = groupObj,
        mounts = { makeMount({ mount_dbid = 101, mount_guid = "MNT-2", mount_weapons = {} }) },
      })
      local cargo1 = makeLoadCargoUnit({ guid = "CARGO-001", mounts = {} })
      local cargo2 = makeLoadCargoUnit({ guid = "CARGO-002", mounts = {} })

      local base = makeBase({
        guid = "BASE-001",
        name = "BaseShip",
        cargo = {
          [1] = {
            cargo = {
              [1] = { guid = "CARGO-001" },
              [2] = { guid = "CARGO-002" },
            }
          }
        },
      })
      trackStub(GameApi, "ScenEdit_GetUnit").invokes(function(identifier, side)
        if identifier == "Infantry-1" and side == "Red" then return member1 end
        if identifier == "MEM-001" then return member1 end
        if identifier == "MEM-002" then return member2 end
        if identifier == "CARGO-001" then return cargo1 end
        if identifier == "CARGO-002" then return cargo2 end
        return nil
      end)

      CargoProxy.loadCargo(base, "Infantry-1", nil, "Red")

      assert.stub(stubUpdateCargo).was.called(2)
      assert.stub(stubDeleteUnit).was.called(2)
    end)

    -- Negative: should return early when unit not found
    it("should return early when unit not found", function()
      trackStub(GameApi, "ScenEdit_GetUnit").returns(nil)

      CargoProxy.loadCargo(makeBase({ guid = "BASE-001" }), "NonExistent", nil, "Red")

      assert.stub(stubUpdateCargo).was_not.called()
      assert.stub(stubDeleteUnit).was_not.called()
      assert.stub(logStub).was_not.called()
    end)

    -- Negative: should skip group member when unit not found
    it("should skip group member when unit not found", function()
      local member1 = makeLoadCargoUnit({
        guid = "MEM-001",
        name = "Inf-1",
        dbid = 7001,
        group = { name = "Alpha", unitlist = { "MEM-001", "GHOST-002" } },
        mounts = {},
      })
      local cargo1 = makeLoadCargoUnit({ guid = "CARGO-001", mounts = {} })

      local base = makeBase({
        guid = "BASE-001",
        name = "BaseShip",
        cargo = { [1] = { cargo = { [1] = { guid = "CARGO-001" } } } },
      })

      trackStub(GameApi, "ScenEdit_GetUnit").invokes(function(identifier, side)
        if identifier == "Infantry-1" and side == "Red" then return member1 end
        if identifier == "MEM-001" then return member1 end
        if identifier == "CARGO-001" then return cargo1 end
        return nil
      end)

      CargoProxy.loadCargo(base, "Infantry-1", nil, "Red")

      -- Only 1 cargo addition (for member1, not GHOST-002)
      assert.stub(stubUpdateCargo).was.called(1)
      assert.stub(stubDeleteUnit).was.called(1)
    end)

    -- Negative: should skip when cargo proxy creation fails
    it("should skip when cargo proxy creation fails", function()
      local sourceUnit = makeLoadCargoUnit({ guid = "SRC-001", name = "Infantry-1", dbid = 7001, mounts = {} })
      local base = makeBase({ guid = "BASE-001", name = "BaseShip", cargo = nil })

      trackStub(GameApi, "ScenEdit_GetUnit").invokes(function(identifier, side)
        if identifier == "Infantry-1" and side == "Red" then return sourceUnit end
        if identifier == "SRC-001" then return sourceUnit end
        return nil
      end)

      CargoProxy.loadCargo(base, "Infantry-1", nil, "Red")

      assert.stub(stubUpdateCargo).was.called(1)
      assert.stub(stubClearMags).was_not.called()
      assert.stub(stubDeleteUnit).was_not.called()
    end)

    -- Positive: should handle weaponDBID as single number
    it("should handle weaponDBID as single number", function()
      local sourceUnit = makeLoadCargoUnit({
        guid = "SRC-001",
        name = "Infantry-1",
        dbid = 7001,
        mounts = {
          makeMount({
            mount_dbid = 100,
            mount_guid = "MNT-1",
            mount_weapons = { makeMountWeapon({ wpn_dbid = 500, wpn_current = 5 }) },
          }),
        },
      })
      local cargoProxy = makeLoadCargoUnit({
        guid = "CARGO-001",
        mounts = {
          makeMount({
            mount_dbid = 200,
            mount_guid = "MNT-P1",
            mount_weapons = { makeMountWeapon({ wpn_dbid = 500, wpn_default = 10 }) },
          }),
        },
      })
      local base = makeBase({
        guid = "BASE-001",
        name = "BaseShip",
        cargo = { [1] = { cargo = { [1] = { guid = "CARGO-001" } } } },
      })

      trackStub(GameApi, "ScenEdit_GetUnit").invokes(function(identifier, side)
        if identifier == "Infantry-1" and side == "Red" then return sourceUnit end
        if identifier == "SRC-001" then return sourceUnit end
        if identifier == "CARGO-001" then return cargoProxy end
        return nil
      end)

      CargoProxy.loadCargo(base, "Infantry-1", 500, "Red")

      -- 1 clear (remove=true) + 1 set = 2
      assert.stub(stubAddReloads).was.called(2)
      assert.stub(stubAddReloads).was.called_with({
        side = "Red", guid = "CARGO-001", wpn_dbid = 500, number = 999, remove = true
      })
      assert.stub(stubAddReloads).was.called_with({
        side = "Red", guid = "CARGO-001", wpn_dbid = 500, number = 5
      })
    end)

    -- Positive: should handle weaponDBID as table of numbers
    it("should handle weaponDBID as table of numbers", function()
      local sourceUnit = makeLoadCargoUnit({
        guid = "SRC-001",
        name = "Infantry-1",
        dbid = 7001,
        mounts = {
          makeMount({
            mount_dbid = 100,
            mount_guid = "MNT-1",
            mount_weapons = {
              makeMountWeapon({ wpn_dbid = 500, wpn_current = 5 }),
              makeMountWeapon({ wpn_dbid = 600, wpn_current = 3 }),
            },
          }),
        },
      })
      local cargoProxy = makeLoadCargoUnit({
        guid = "CARGO-001",
        mounts = {
          makeMount({
            mount_dbid = 200,
            mount_guid = "MNT-P1",
            mount_weapons = {
              makeMountWeapon({ wpn_dbid = 500, wpn_default = 10 }),
              makeMountWeapon({ wpn_dbid = 600, wpn_default = 10 }),
            },
          }),
        },
      })
      local base = makeBase({
        guid = "BASE-001",
        name = "BaseShip",
        cargo = { [1] = { cargo = { [1] = { guid = "CARGO-001" } } } },
      })

      trackStub(GameApi, "ScenEdit_GetUnit").invokes(function(identifier, side)
        if identifier == "Infantry-1" and side == "Red" then return sourceUnit end
        if identifier == "SRC-001" then return sourceUnit end
        if identifier == "CARGO-001" then return cargoProxy end
        return nil
      end)

      CargoProxy.loadCargo(base, "Infantry-1", { 500, 600 }, "Red")

      -- 2 clears + 2 sets = 4
      assert.stub(stubAddReloads).was.called(4)
    end)

    -- Positive: should skip weapon tally when weaponDBID is nil
    it("should skip weapon tally when weaponDBID is nil", function()
      local sourceUnit = makeLoadCargoUnit({
        guid = "SRC-001",
        name = "Infantry-1",
        dbid = 7001,
        mounts = {
          makeMount({
            mount_dbid = 100,
            mount_guid = "MNT-1",
            mount_weapons = { makeMountWeapon({ wpn_dbid = 500, wpn_current = 10 }) },
          }),
        },
      })
      local cargoProxy = makeLoadCargoUnit({ guid = "CARGO-001", mounts = {} })
      local base = makeBase({
        guid = "BASE-001",
        name = "BaseShip",
        cargo = { [1] = { cargo = { [1] = { guid = "CARGO-001" } } } },
      })

      trackStub(GameApi, "ScenEdit_GetUnit").invokes(function(identifier, side)
        if identifier == "Infantry-1" and side == "Red" then return sourceUnit end
        if identifier == "SRC-001" then return sourceUnit end
        if identifier == "CARGO-001" then return cargoProxy end
        return nil
      end)

      CargoProxy.loadCargo(base, "Infantry-1", nil, "Red")

      assert.stub(stubAddReloads).was_not.called()
    end)

    -- Positive: should set group name on cargo when source has group
    it("should set group name on cargo when source has group", function()
      local sourceUnit = makeLoadCargoUnit({
        guid = "SRC-001",
        name = "Infantry-1",
        dbid = 7001,
        group = { name = "Alpha", unitlist = { "SRC-001" } },
        mounts = {},
      })
      local cargoProxy = makeLoadCargoUnit({ guid = "CARGO-001", mounts = {} })
      local base = makeBase({
        guid = "BASE-001",
        name = "BaseShip",
        cargo = { [1] = { cargo = { [1] = { guid = "CARGO-001" } } } },
      })

      trackStub(GameApi, "ScenEdit_GetUnit").invokes(function(identifier, side)
        if identifier == "Infantry-1" and side == "Red" then return sourceUnit end
        if identifier == "SRC-001" then return sourceUnit end
        if identifier == "CARGO-001" then return cargoProxy end
        return nil
      end)

      CargoProxy.loadCargo(base, "Infantry-1", nil, "Red")

      assert.are.equal("Alpha", cargoProxy.group)
      assert.are.equal("Infantry-1", cargoProxy.name)
    end)

    -- Negative: should not set group when source has no group
    it("should not set group when source has no group", function()
      local sourceUnit = makeLoadCargoUnit({
        guid = "SRC-001",
        name = "Infantry-1",
        dbid = 7001,
        mounts = {},
      })
      local cargoProxy = makeLoadCargoUnit({ guid = "CARGO-001", mounts = {} })
      local base = makeBase({
        guid = "BASE-001",
        name = "BaseShip",
        cargo = { [1] = { cargo = { [1] = { guid = "CARGO-001" } } } },
      })

      trackStub(GameApi, "ScenEdit_GetUnit").invokes(function(identifier, side)
        if identifier == "Infantry-1" and side == "Red" then return sourceUnit end
        if identifier == "SRC-001" then return sourceUnit end
        if identifier == "CARGO-001" then return cargoProxy end
        return nil
      end)

      CargoProxy.loadCargo(base, "Infantry-1", nil, "Red")

      assert.is_nil(cargoProxy.group)
      assert.are.equal("Infantry-1", cargoProxy.name)
    end)

    -- Positive: should log results
    it("should log results", function()
      local sourceUnit = makeLoadCargoUnit({
        guid = "SRC-001",
        name = "Infantry-1",
        dbid = 7001,
        mounts = {},
      })
      local cargoProxy = makeLoadCargoUnit({ guid = "CARGO-001", mounts = {} })
      local base = makeBase({
        guid = "BASE-001",
        name = "BaseShip",
        cargo = { [1] = { cargo = { [1] = { guid = "CARGO-001" } } } },
      })

      trackStub(GameApi, "ScenEdit_GetUnit").invokes(function(identifier, side)
        if identifier == "Infantry-1" and side == "Red" then return sourceUnit end
        if identifier == "SRC-001" then return sourceUnit end
        if identifier == "CARGO-001" then return cargoProxy end
        return nil
      end)

      CargoProxy.loadCargo(base, "Infantry-1", nil, "Red")

      assert.stub(logStub).was.called(1)
      local callArgs = logStub.calls[1].vals
      assert.are.equal(constants.TAGS.MISSILE_SYSTEM, callArgs[1])
      assert.truthy(string.find(callArgs[2], "ship=BaseShip: Load cargo | total=1 ok=1"))
      assert.truthy(string.find(callArgs[2], "%[OK%]"))
    end)
  end)
end)
