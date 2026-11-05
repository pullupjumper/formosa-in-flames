---@diagnostic disable: need-check-nil, assign-type-mismatch, cast-local-type, param-type-mismatch, inject-field, missing-fields
-- MissileSystem Deployment Unit Tests
local stub = require("luassert.stub")
local Deployment = require("src.modules.missileSystem.deployment")
local GameApi = require("src.utils.gameApi")
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

  ---One shared operational area holding every position a battery spawns at
  local function buildArea(name)
    return {
      name = name,
      HA = { { course = { { latitude = 1, longitude = 1 } } } },
      FP = { { course = { { latitude = 2, longitude = 2 } } } },
      RL = { { course = { { latitude = 3, longitude = 3 } } } },
      ATP = { { course = { { latitude = 4, longitude = 4 } } } }
    }
  end

  ---One system with one battery per suffix, linked firing -> resupply -> canister stock
  ---@param suffixes string[]
  ---@param unitCount? integer
  local function buildSystemConfig(suffixes, unitCount)
    local systemConfig = { firingUnits = {}, resupplyUnits = {}, canisterStocks = {} }
    for _, suffix in ipairs(suffixes) do
      local area = buildArea("OPAREA-" .. suffix)
      local firingName = suffix .. " Bn, 1st Bde"
      systemConfig.firingUnits[firingName] = { name = firingName, dbid = 1234, weaponDBID = 5678,
        resupplyUnit = "Ammo Sec, " .. firingName, operationalArea = area }
      systemConfig.resupplyUnits["Ammo Sec, " .. firingName] = { name = "Ammo Sec, " .. firingName,
        unitCount = unitCount or 1, canisterStock = "Ammo Revetment, " .. firingName, firingUnit = firingName,
        operationalArea = area }
      systemConfig.canisterStocks["Ammo Revetment, " .. firingName] = { name = "Ammo Revetment, " .. firingName }
    end
    return systemConfig
  end

  ---Build every configured battery in the game
  local function deployAll(missileSystemConfigMap, sideName)
    Deployment.deployBatteries(sideName, Deployment.resolveBatteries(missileSystemConfigMap))
  end

  ---Every add succeeds; returns the AddUnit options by unit name
  local function stubEmptyMap()
    trackStub(GameApi, "ScenEdit_GetUnit").returns(nil)
    trackStub(GameApi, "ScenEdit_ClearAllMagazines")
    local added = {}
    trackStub(GameApi, "ScenEdit_AddUnit").invokes(function(opts)
      added[opts.unitname] = opts
      return { guid = "new-" .. opts.unitname, name = opts.unitname, mounts = {} }
    end)
    return added
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
  -- deployBatteries
  -- ============================================================================

  describe("deployBatteries", function()
    -- Negative: logs AddUnit failure detail for firing units
    it("should log add unit failure details for firing units", function()
      trackStub(GameApi, "ScenEdit_GetUnit").returns(nil)
      trackStub(GameApi, "ScenEdit_ClearAllMagazines")
      trackStub(GameApi, "ScenEdit_AddUnit").invokes(function(opts)
        if opts.unitname == "A Bn, 1st Bde" then
          return nil
        end
        return { guid = "new-" .. opts.unitname, name = opts.unitname, mounts = {} }
      end)

      deployAll({ srbm = buildSystemConfig({ "A" }) }, constants.SIDES.RED)

      assert.stub(logStub).was_not.called()
      assert.stub(errorStub).was.called(1)

      local message = errorStub.calls[1].vals[1]
      assert.is_not_nil(string.find(message, "reason=add_unit_failed", 1, true))
      assert.is_not_nil(string.find(message, "system=srbm", 1, true))
      assert.is_not_nil(string.find(message, "role=firing", 1, true))
      assert.is_not_nil(string.find(message, "unit=\"A Bn, 1st Bde\"", 1, true))
      assert.is_not_nil(string.find(message, "firing=0/1", 1, true))
      assert.is_not_nil(string.find(message, "resupply=1/1", 1, true))
      assert.is_not_nil(string.find(message, "canister_stock=1/1", 1, true))
    end)

    -- Positive: a SAM firing unit spawns at a firing point, other systems at their hide area
    it("should spawn SAM firing units at a firing point and others at the hide area", function()
      local added = stubEmptyMap()

      deployAll({ sam = buildSystemConfig({ "SAM" }), srbm = buildSystemConfig({ "SRBM" }) }, constants.SIDES.BLUE)

      assert.are.equal(2, added["SAM Bn, 1st Bde"].latitude)
      assert.are.equal(1, added["SRBM Bn, 1st Bde"].latitude)
    end)

    -- Positive: the resupply unit spawns at the reload point and the hidden canister stock at the ammunition transfer point
    it("should spawn the resupply unit at the reload point and the canister stock at the ammunition transfer point", function()
      local added = stubEmptyMap()

      deployAll({ srbm = buildSystemConfig({ "A" }) }, constants.SIDES.RED)

      assert.are.equal(3, added["Ammo Sec, A Bn, 1st Bde"].latitude)
      assert.are.equal(constants.PLATFORMS.AMMO_TRUCK, added["Ammo Sec, A Bn, 1st Bde"].dbid)
      assert.are.equal(4, added["Ammo Revetment, A Bn, 1st Bde"].latitude)
      assert.are.equal(constants.PLATFORMS.AMMO, added["Ammo Revetment, A Bn, 1st Bde"].dbid)
    end)

    -- Positive: multi-vehicle units are named with an ordinal in front of the firing unit name
    it("should name group members after the firing unit for both firing and resupply vehicles", function()
      local added = stubEmptyMap()

      deployAll({ srbm = buildSystemConfig({ "A" }, 2) }, constants.SIDES.RED)

      assert.is_not_nil(added["1st Coy, A Bn, 1st Bde"])
      assert.is_not_nil(added["2nd Coy, A Bn, 1st Bde"])
      assert.is_not_nil(added["Ammo Sec, 1st Coy, A Bn, 1st Bde"])
      assert.is_not_nil(added["Ammo Sec, 2nd Coy, A Bn, 1st Bde"])
      assert.are.equal("Ammo Sec, A Bn, 1st Bde", added["Ammo Sec, 2nd Coy, A Bn, 1st Bde"].group)
      assert.is_not_nil(added["Ammo Revetment, A Bn, 1st Bde"])
    end)

    -- Negative: an area missing the reload point rejects only the resupply unit
    it("should reject a resupply unit whose area has no reload point and still build the rest", function()
      local added = stubEmptyMap()
      local systemConfig = buildSystemConfig({ "A" }, 2)
      systemConfig.firingUnits["A Bn, 1st Bde"].operationalArea.RL = nil

      deployAll({ srbm = systemConfig }, constants.SIDES.RED)

      local message = errorStub.calls[1].vals[1]
      assert.is_not_nil(string.find(message, "reason=no_rl_defined", 1, true))
      assert.is_not_nil(string.find(message, "resupply=0/2", 1, true))
      assert.is_not_nil(string.find(message, "firing=2/2", 1, true))
      assert.is_nil(added["Ammo Sec, 1st Coy, A Bn, 1st Bde"])
    end)

    -- Positive: replacing a grouped unit deletes every member of the group
    it("should delete every member of an existing group before rebuilding", function()
      trackStub(GameApi, "ScenEdit_GetUnit").invokes(function(name)
        if name == "A Bn, 1st Bde" then
          return { guid = "G-1", name = name, group = { unitlist = { "M-1", "M-2" } } }
        end
        return nil
      end)
      trackStub(GameApi, "ScenEdit_ClearAllMagazines")
      local deleteStub = trackStub(GameApi, "ScenEdit_DeleteUnit").returns(true)
      trackStub(GameApi, "ScenEdit_AddUnit").invokes(function(opts)
        return { guid = "new-" .. opts.unitname, name = opts.unitname, mounts = {} }
      end)

      deployAll({ srbm = buildSystemConfig({ "A" }) }, constants.SIDES.RED)

      assert.stub(deleteStub).was.called(2)
      assert.stub(deleteStub).was.called_with({ side = constants.SIDES.RED, guid = "M-1" })
      assert.stub(deleteStub).was.called_with({ side = constants.SIDES.RED, guid = "M-2" })
    end)

    -- Positive: only the given batteries are removed and rebuilt, at the battery's area
    it("should rebuild only the given batteries, at each battery's area", function()
      local missileSystemConfigMap = { srbm = buildSystemConfig({ "A", "B" }) }
      trackStub(GameApi, "ScenEdit_GetUnit").invokes(function(name)
        return { guid = "old-" .. name, name = name }
      end)
      trackStub(GameApi, "ScenEdit_ClearAllMagazines")
      local deleteStub = trackStub(GameApi, "ScenEdit_DeleteUnit").returns(true)
      local added = {}
      trackStub(GameApi, "ScenEdit_AddUnit").invokes(function(opts)
        added[opts.unitname] = opts
        return { guid = "new-" .. opts.unitname, name = opts.unitname, mounts = {} }
      end)
      local newArea = buildArea("OPAREA-NEW")
      newArea.HA[1].course[1].latitude = 9

      local battery = Deployment.resolveBattery(missileSystemConfigMap,
        { missileSystemType = "srbm", unitname = "A Bn, 1st Bde", operationalArea = newArea })
      Deployment.deployBatteries(constants.SIDES.RED, { battery })

      assert.are.equal(9, added["A Bn, 1st Bde"].latitude)
      assert.is_nil(added["B Bn, 1st Bde"])
      assert.stub(deleteStub).was.called_with({ side = constants.SIDES.RED, guid = "old-A Bn, 1st Bde" })
      assert.stub(deleteStub).was_not.called_with({ side = constants.SIDES.RED, guid = "old-B Bn, 1st Bde" })
    end)
  end)

  -- ============================================================================
  -- resolveBattery
  -- ============================================================================

  describe("resolveBattery", function()
    -- Positive: follows config links firing -> resupply -> canister stock and keeps the layout's area
    it("should join the firing unit to its resupply unit and canister stock by config links", function()
      local systemConfig = buildSystemConfig({ "A", "B" }, 3)
      local newArea = buildArea("OPAREA-NEW")

      local battery = Deployment.resolveBattery({ srbm = systemConfig },
        { missileSystemType = "srbm", unitname = "B Bn, 1st Bde", operationalArea = newArea })

      assert.are.equal(systemConfig.firingUnits["B Bn, 1st Bde"], battery.firing)
      assert.are.equal(systemConfig.resupplyUnits["Ammo Sec, B Bn, 1st Bde"], battery.resupply)
      assert.are.equal(systemConfig.canisterStocks["Ammo Revetment, B Bn, 1st Bde"], battery.canisterStock)
      assert.are.equal(3, battery.unitCount)
      assert.are.equal(newArea, battery.operationalArea)
    end)

    -- Negative: unknown system or firing unit gives nil
    it("should return nil for an unknown system or firing unit", function()
      local missileSystemConfigMap = { srbm = buildSystemConfig({ "A" }) }

      assert.is_nil(Deployment.resolveBattery(missileSystemConfigMap,
        { missileSystemType = "glcm", unitname = "A Bn, 1st Bde", operationalArea = {} }))
      assert.is_nil(Deployment.resolveBattery(missileSystemConfigMap,
        { missileSystemType = "srbm", unitname = "Ghost", operationalArea = {} }))
    end)
  end)
end)
