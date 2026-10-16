---@diagnostic disable: need-check-nil, assign-type-mismatch, cast-local-type, param-type-mismatch, inject-field
-- MissileSystem Deployment Unit Tests
local stub = require("luassert.stub")
local Deployment = require("src.modules.missileSystem.deployment")
local GameApi = require("src.utils.gameApi")
local GameUtils = require("src.utils.gameUtils")
local Logger = require("src.utils.logger")
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
end)
