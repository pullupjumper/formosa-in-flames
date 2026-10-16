-- LandingOps AcvWave Unit Tests
local AcvWave = require("src.modules.landingOps.acvWave")
local GameApi = require("src.utils.gameApi")
---@diagnostic disable: need-check-nil, assign-type-mismatch, cast-local-type, param-type-mismatch, inject-field
describe("AcvWave", function()
  ---@type luassert.spy[]
  local activeStubs
  ---@type table<string, true>
  local aliveSet

  before_each(function()
    aliveSet = {}
    activeStubs = {
      stub(GameApi, "ScenEdit_GetUnit").invokes(function(guid)
        return aliveSet[guid] and { guid = guid } or nil
      end),
    }
  end)

  after_each(function()
    for i = #activeStubs, 1, -1 do
      activeStubs[i]:revert()
    end
  end)

  local CONFIG = { capacity = { zbd05 = 4, ztd05 = 4 }, lossRatio = 0.5, holdSec = 600 }

  ---@param zoneState table
  ---@param key string
  ---@param count integer
  local function launch(zoneState, key, count)
    for i = 1, count do
      local guid = key .. "-" .. i .. "-" .. #(zoneState.acvGuids and zoneState.acvGuids[key] or {})
      aliveSet[guid] = true
      AcvWave.addACV(zoneState, key, guid)
    end
  end

  -- Positive: each type has its own full quota
  it("should give each ACV type its own full capacity at first", function()
    local zoneState = {}

    assert.are.same({ zbd05 = 4, ztd05 = 4 }, AcvWave.getQuota(zoneState, CONFIG, 0))
  end)

  -- Positive: launches in the same tick share the quota
  it("should reduce the quota by ACVs already launched this tick", function()
    local zoneState = {}
    launch(zoneState, "zbd05", 3)

    assert.are.same({ zbd05 = 1, ztd05 = 4 }, AcvWave.getQuota(zoneState, CONFIG, 0))
  end)

  -- Boundary: reaching capacity pauses that type only
  it("should pause a type that reached capacity and keep the other open", function()
    local zoneState = {}
    launch(zoneState, "zbd05", 4)

    local quota = AcvWave.getQuota(zoneState, CONFIG, 100)

    assert.are.equal(0, quota.zbd05)
    assert.are.equal(4, quota.ztd05)
    assert.are.equal(100, zoneState.acvPausedAt.zbd05)
  end)

  -- Negative: small losses do not lift the pause before the hold time
  it("should stay paused when losses are below lossRatio and hold time has not passed", function()
    local zoneState = {}
    launch(zoneState, "zbd05", 4)
    AcvWave.getQuota(zoneState, CONFIG, 100)
    aliveSet[zoneState.acvGuids.zbd05[1]] = nil -- 3 of 4 alive, threshold is 2

    assert.are.equal(0, AcvWave.getQuota(zoneState, CONFIG, 200).zbd05)
  end)

  -- Positive: heavy losses release the next wave
  it("should resume and refill to capacity when alive drops below (1 - lossRatio)", function()
    local zoneState = {}
    launch(zoneState, "zbd05", 4)
    AcvWave.getQuota(zoneState, CONFIG, 100)
    aliveSet[zoneState.acvGuids.zbd05[1]] = nil
    aliveSet[zoneState.acvGuids.zbd05[2]] = nil
    aliveSet[zoneState.acvGuids.zbd05[3]] = nil -- 1 of 4 alive

    local quota = AcvWave.getQuota(zoneState, CONFIG, 200)

    assert.are.equal(3, quota.zbd05)
    assert.is_nil(zoneState.acvPausedAt.zbd05)
    assert.are.equal(1, #zoneState.acvGuids.zbd05)
  end)

  -- Positive: hold timeout releases the next wave even without losses
  it("should resume after holdSec even without heavy losses", function()
    local zoneState = {}
    launch(zoneState, "zbd05", 4)
    AcvWave.getQuota(zoneState, CONFIG, 100)
    aliveSet[zoneState.acvGuids.zbd05[1]] = nil

    assert.are.equal(1, AcvWave.getQuota(zoneState, CONFIG, 700).zbd05)
  end)
end)
