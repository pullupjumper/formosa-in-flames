---@diagnostic disable: need-check-nil, assign-type-mismatch, cast-local-type, param-type-mismatch, inject-field
-- MissileSystem Deployment Unit Tests
local stub = require("luassert.stub")
local Deployment = require("src.modules.missileSystem.deployment")
local GameApi = require("src.utils.gameApi")
local GameUtils = require("src.utils.gameUtils")
local Logger = require("src.utils.logger")
local config = require("src.core.config")
local constants = require("src.core.constants")

describe("MissileSystem Deployment", function()
  ---@type luassert.spy[]
  local activeStubs
  ---@type luassert.spy
  local logStub
  ---@type luassert.spy
  local errorStub

  ---Track and register method stub for automatic cleanup.
  ---@param obj table
  ---@param method string
  ---@return luassert.spy
  local function trackStub(obj, method)
    local s = stub(obj, method)
    table.insert(activeStubs, s)
    return s
  end

  local function makeMissileSystemConfigMap()
    return {
      srbm = {
        firingUnits = {
          alpha = {
            name = "Firing Unit Alpha",
            dbid = 1234,
            resupplyUnit = "Ammo Sec Alpha",
            weaponDBID = 5678,
            operationalArea = {
              name = "OPAREA-1",
              HA = {
                { course = { { latitude = 25.0, longitude = 121.0 } } }
              }
            }
          }
        },
        resupplyUnits = {
          ["Ammo Sec Alpha"] = {
            name = "Ammo Sec Alpha",
            unitCount = 1,
            operationalArea = {
              name = "OPAREA-1",
              RL = {
                { course = { { latitude = 25.1, longitude = 121.1 } } }
              }
            }
          }
        },
        ammunitions = {}
      }
    }
  end

  before_each(function()
    activeStubs = {}
    logStub = trackStub(Logger, "log")
    errorStub = trackStub(Logger, "error")
  end)

  after_each(function()
    for i = #activeStubs, 1, -1 do
      activeStubs[i]:revert()
    end
    activeStubs = {}
  end)

  -- ============================================================================
  -- addMissileSystems
  -- ============================================================================

  describe("addMissileSystems", function()
    -- Negative: logs AddUnit failure detail for firing units
    it("should log add unit failure details for firing units", function()
      trackStub(GameApi, "ScenEdit_GetUnit").returns(nil)
      trackStub(GameUtils, "resolveUnitType").returns("Unit")
      trackStub(GameApi, "ScenEdit_AddUnit").invokes(function(opts)
        if opts.unitname == "Firing Unit Alpha" then
          return nil
        end
        return { guid = "RU-1", name = opts.unitname, mounts = {} }
      end)

      Deployment.addMissileSystems(makeMissileSystemConfigMap(), constants.SIDES.RED)

      assert.stub(logStub).was_not.called()
      assert.stub(errorStub).was.called(1)

      local message = errorStub.calls[1].vals[1]
      assert.is_not_nil(string.find(message, "reason=add_unit_failed", 1, true))
      assert.is_not_nil(string.find(message, "system=srbm", 1, true))
      assert.is_not_nil(string.find(message, "role=firing", 1, true))
      assert.is_not_nil(string.find(message, "unit=\"Firing Unit Alpha\"", 1, true))
      assert.is_not_nil(string.find(message, "firing=0/1", 1, true))
      assert.is_not_nil(string.find(message, "resupply=1/1", 1, true))
    end)

    -- Positive: a SAM firing unit spawns at a firing point, other systems at their hide area
    it("should spawn SAM firing units at a firing point and others at the hide area", function()
      local function makeSystem(name)
        return {
          firingUnits = { [name] = { name = name, dbid = 1234, resupplyUnit = "RU-" .. name, weaponDBID = 5678,
            operationalArea = { name = "OPAREA-" .. name,
              HA = { { course = { { latitude = 1, longitude = 1 } } } },
              FP = { { course = { { latitude = 2, longitude = 2 } } } } } } },
          resupplyUnits = { ["RU-" .. name] = { name = "RU-" .. name, unitCount = 1,
            operationalArea = { name = "OPAREA-" .. name, RL = { { course = { { latitude = 3, longitude = 3 } } } } } } },
          ammunitions = {}
        }
      end
      trackStub(GameApi, "ScenEdit_GetUnit").returns(nil)
      trackStub(GameUtils, "resolveUnitType").returns("Unit")
      local spawnedAt = {}
      trackStub(GameApi, "ScenEdit_AddUnit").invokes(function(opts)
        spawnedAt[opts.unitname] = opts.latitude
        return { guid = "new-" .. opts.unitname, name = opts.unitname, mounts = {} }
      end)

      Deployment.addMissileSystems({ sam = makeSystem("FU-SAM"), srbm = makeSystem("FU-SRBM") }, constants.SIDES.BLUE)

      assert.are.equal(2, spawnedAt["FU-SAM"])
      assert.are.equal(1, spawnedAt["FU-SRBM"])
    end)

    -- Positive: replacing a grouped unit deletes every member of the group
    it("should delete every member of an existing group before rebuilding", function()
      local missileSystemConfigMap = makeMissileSystemConfigMap()
      trackStub(GameApi, "ScenEdit_GetUnit").invokes(function(name)
        if name == "Firing Unit Alpha" then
          return { guid = "G-1", name = name, group = { unitlist = { "M-1", "M-2" } } }
        end
        return nil
      end)
      trackStub(GameUtils, "resolveUnitType").returns("Unit")
      local deleteStub = trackStub(GameApi, "ScenEdit_DeleteUnit").returns(true)
      trackStub(GameApi, "ScenEdit_AddUnit").invokes(function(opts)
        return { guid = "new-" .. opts.unitname, name = opts.unitname, mounts = {} }
      end)

      Deployment.addMissileSystems(missileSystemConfigMap, constants.SIDES.RED)

      assert.stub(deleteStub).was.called(2)
      assert.stub(deleteStub).was.called_with({ side = constants.SIDES.RED, guid = "M-1" })
      assert.stub(deleteStub).was.called_with({ side = constants.SIDES.RED, guid = "M-2" })
    end)

    -- Positive: only the batteries picked by selectBatteries are removed and rebuilt
    it("should rebuild only the selected batteries and leave the others untouched", function()
      local function makeUnitPair(suffix)
        return {
          name = "FU-" .. suffix,
          dbid = 1234,
          resupplyUnit = "RU-" .. suffix,
          weaponDBID = 5678,
          operationalArea = { name = "OPAREA-" .. suffix, HA = { { course = { { latitude = 25.0, longitude = 121.0 } } } } }
        }, {
          name = "RU-" .. suffix,
          unitCount = 1,
          operationalArea = { name = "OPAREA-" .. suffix, RL = { { course = { { latitude = 25.1, longitude = 121.1 } } } } }
        }
      end
      local firingA, resupplyA = makeUnitPair("A")
      local firingB, resupplyB = makeUnitPair("B")
      local missileSystemConfigMap = {
        srbm = {
          firingUnits = { ["FU-A"] = firingA, ["FU-B"] = firingB },
          resupplyUnits = { ["RU-A"] = resupplyA, ["RU-B"] = resupplyB },
          ammunitions = {}
        }
      }
      trackStub(GameApi, "ScenEdit_GetUnit").invokes(function(name)
        return { guid = "old-" .. name, name = name }
      end)
      trackStub(GameUtils, "resolveUnitType").returns("Unit")
      local deleteStub = trackStub(GameApi, "ScenEdit_DeleteUnit").returns(true)
      local addedNames = {}
      trackStub(GameApi, "ScenEdit_AddUnit").invokes(function(opts)
        table.insert(addedNames, opts.unitname)
        return { guid = "new-" .. opts.unitname, name = opts.unitname, mounts = {} }
      end)

      Deployment.addMissileSystems(
        Deployment.selectBatteries(missileSystemConfigMap, { ["FU-A"] = true }),
        constants.SIDES.RED
      )

      table.sort(addedNames)
      assert.are.same({ "FU-A", "RU-A" }, addedNames)
      assert.stub(deleteStub).was.called_with({ side = constants.SIDES.RED, guid = "old-FU-A" })
      assert.stub(deleteStub).was_not.called_with({ side = constants.SIDES.RED, guid = "old-FU-B" })
      assert.stub(deleteStub).was_not.called_with({ side = constants.SIDES.RED, guid = "old-RU-B" })
    end)
  end)

  -- ============================================================================
  -- selectBatteries
  -- ============================================================================

  describe("selectBatteries", function()
    -- Positive: a named firing unit brings its resupply unit and ammo; other systems and batteries are left out
    it("should keep only the named batteries and the systems that field them", function()
      local missileSystemConfigMap = {
        srbm = {
          reloadTime = 600,
          firingUnits = {
            ["FU-A"] = { name = "FU-A", resupplyUnit = "RU-A" },
            ["FU-B"] = { name = "FU-B", resupplyUnit = "RU-B" }
          },
          resupplyUnits = {
            ["RU-A"] = { name = "RU-A", ammunition = "AMMO-A" },
            ["RU-B"] = { name = "RU-B", ammunition = "AMMO-B" }
          },
          ammunitions = { ["AMMO-A"] = { name = "AMMO-A" }, ["AMMO-B"] = { name = "AMMO-B" } }
        },
        glcm = {
          firingUnits = { ["FU-C"] = { name = "FU-C", resupplyUnit = "RU-C" } },
          resupplyUnits = { ["RU-C"] = { name = "RU-C" } },
          ammunitions = {}
        }
      }

      local function keysOf(map)
        local keys = {}
        for key in pairs(map) do
          table.insert(keys, key)
        end
        table.sort(keys)
        return keys
      end

      local selected = Deployment.selectBatteries(missileSystemConfigMap, { ["FU-A"] = true })

      assert.is_nil(selected.glcm)
      assert.are.equal(600, selected.srbm.reloadTime)
      assert.are.same({ "FU-A" }, keysOf(selected.srbm.firingUnits))
      assert.are.same({ "RU-A" }, keysOf(selected.srbm.resupplyUnits))
      assert.are.same({ "AMMO-A" }, keysOf(selected.srbm.ammunitions))
      assert.are.same({ "FU-A", "FU-B" }, keysOf(missileSystemConfigMap.srbm.firingUnits))
    end)
  end)

  -- ============================================================================
  -- updateLayouts
  -- ============================================================================

  describe("updateLayouts", function()
    local function makeLayoutConfig()
      local oldArea = { name = "OPAREA-OLD" }
      return {
        srbm = {
          firingUnits = {
            ["FU-1"] = { name = "FU-1", resupplyUnit = "RU-1", operationalArea = oldArea }
          },
          resupplyUnits = {
            ["RU-1"] = { name = "RU-1", ammunition = "AMMO-1", operationalArea = oldArea }
          },
          ammunitions = {
            ["AMMO-1"] = { name = "AMMO-1" }
          }
        }
      }, oldArea
    end

    -- Positive: firing and resupply descriptors move to the new area as fresh copies
    it("should point both descriptors at the new area and report old and new areas", function()
      local missileSystemConfigMap, oldArea = makeLayoutConfig()
      local originalFiringUnit = missileSystemConfigMap.srbm.firingUnits["FU-1"]
      local newArea = { name = "#ABC" }

      local operationalAreas, operationalAreasToRemove = Deployment.updateLayouts(missileSystemConfigMap, {
        { missileSystemType = "srbm", unitname = "FU-1", operationalArea = newArea }
      })

      assert.are.same({ newArea }, operationalAreas)
      assert.are.same(oldArea, operationalAreasToRemove[1])
      assert.are.equal(newArea, missileSystemConfigMap.srbm.firingUnits["FU-1"].operationalArea)
      assert.are.equal(newArea, missileSystemConfigMap.srbm.resupplyUnits["RU-1"].operationalArea)
      assert.are_not.equal(originalFiringUnit, missileSystemConfigMap.srbm.firingUnits["FU-1"])
      assert.are.equal(oldArea, originalFiringUnit.operationalArea)
    end)

    -- Negative: unknown system or firing unit is skipped
    it("should skip layouts naming an unknown system or firing unit", function()
      local missileSystemConfigMap, oldArea = makeLayoutConfig()
      local operationalArea1 = { name = "#X" }
      local operationalArea2 = { name = "#Y" }

      local operationalAreas, operationalAreasToRemove = Deployment.updateLayouts(missileSystemConfigMap, {
        { missileSystemType = "glcm", unitname = "FU-1",  operationalArea = operationalArea1 },
        { missileSystemType = "srbm", unitname = "Ghost", operationalArea = operationalArea2 }
      })

      assert.are.same({}, operationalAreas)
      assert.are.same({}, operationalAreasToRemove)
      assert.are.equal(oldArea, missileSystemConfigMap.srbm.firingUnits["FU-1"].operationalArea)
    end)
  end)

  -- ============================================================================
  -- configured batteries
  -- ============================================================================

  -- The reload cycle hides a resupply unit after a reload on the strength of its meeting in the
  -- firing unit's RL zone, which holds only while both units share one operational area.
  it("should give each configured firing unit and its resupply unit the same operational area", function()
    local pairCount = 0
    for _, field in ipairs({ "red", "blue", "ally" }) do
      local ground = config[field] and config[field].ground
      for systemType, systemConfig in pairs(ground and ground.missileSystemTypes or {}) do
        for name, firingUnit in pairs(systemConfig.firingUnits or {}) do
          local resupplyUnit = systemConfig.resupplyUnits[firingUnit.resupplyUnit]
          assert.is_not_nil(resupplyUnit)
          assert.are.same(firingUnit.operationalArea, resupplyUnit.operationalArea, field .. "/" .. systemType .. "/" .. name)
          pairCount = pairCount + 1
        end
      end
    end
    assert.is_true(pairCount > 0)
  end)
end)
