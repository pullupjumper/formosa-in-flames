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

  local function makeGroundForceCfg()
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
      trackStub(GameUtils, "extractUnitType").returns("Unit")
      trackStub(GameApi, "ScenEdit_AddUnit").invokes(function(opts)
        if opts.unitname == "Firing Unit Alpha" then
          return nil
        end
        return { guid = "RU-1", name = opts.unitname, mounts = {} }
      end)

      Deployment.addMissileSystems(makeGroundForceCfg(), constants.SIDES.ENEMY)

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
end)
