---@diagnostic disable: need-check-nil, assign-type-mismatch, cast-local-type, param-type-mismatch, inject-field
-- MissileSystem PositionZones Unit Tests
local stub = require("luassert.stub")
local PositionZones = require("src.modules.missileSystem.positionZones")
local Triggers = require("src.modules.missileSystem.triggers")
local GameApi = require("src.utils.gameApi")
local GameUtils = require("src.utils.gameUtils")
local Logger = require("src.utils.logger")
local constants = require("src.core.constants")

describe("MissileSystem PositionZones", function()
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

  it("should name every config operational area the way the scenario names its zones", function()
    for key, operationalArea in pairs(constants.OPERATIONAL_AREAS) do
      assert.are.equal("#" .. key, operationalArea.name)
    end
  end)

  describe("rebuild", function()
    -- Positive: sets area color for standard position zones
    it("should set area color for standard position zones regardless of side", function()
      local operationalAreas = {
        {
          name = "OPAREA-1",
          uShapeVertices = { "MASK-RP-1", "MASK-RP-2", "MASK-RP-3", "MASK-RP-4" },
          RL = {
            { area = { "RL-RP-1", "RL-RP-2", "RL-RP-3", "RL-RP-4" } }
          }
        }
      }
      local createdZones = {}

      trackStub(GameApi, "ScenEdit_GetEvent").returns({ triggers = {} })
      trackStub(GameApi, "VP_GetSide").returns({ standardzones = {} })
      trackStub(GameUtils, "normalizeToRPArray").invokes(function(zone)
        return zone.area
      end)
      trackStub(GameApi, "ScenEdit_SetTrigger").returns(true)
      trackStub(GameApi, "ScenEdit_SetEventTrigger").returns(true)
      trackStub(GameApi, "ScenEdit_AddZone").invokes(function(_, zoneType, opts)
        local zone = {
          description = opts.description,
          area = opts.area,
          zoneType = zoneType,
          areacolor = opts.areacolor
        }
        table.insert(createdZones, zone)
        return zone
      end)

      PositionZones.update(
        constants.SIDES.RED,
        operationalAreas,
        {},
        { constants.POSITION_TYPES.RELOAD_POINT }
      )

      assert.are.equal(2, #createdZones)
      assert.are.equal("4dd9822b", createdZones[1].areacolor)
      assert.are.equal(constants.ZONE_TYPES.STANDARD, createdZones[1].zoneType)
    end)

    -- Positive: creates mask zone as standard zone and stores converted area
    it("should create mask zone as standard zone and store converted area", function()
      local operationalArea = {
        name = "OPAREA-1",
        uShapeVertices = { "MASK-RP-1", "MASK-RP-2", "MASK-RP-3", "MASK-RP-4" },
        RL = {
          { area = { "RL-RP-1", "RL-RP-2", "RL-RP-3", "RL-RP-4" } }
        }
      }
      local maskZoneType
      local maskZone

      trackStub(GameApi, "ScenEdit_GetEvent").returns({ triggers = {} })
      trackStub(GameApi, "VP_GetSide").returns({ standardzones = {} })
      trackStub(GameUtils, "normalizeToRPArray").invokes(function(zone)
        return { zone.description .. "-RP-1", zone.description .. "-RP-2" }
      end)
      trackStub(GameApi, "ScenEdit_SetTrigger").returns(true)
      trackStub(GameApi, "ScenEdit_SetEventTrigger").returns(true)
      trackStub(GameApi, "ScenEdit_AddZone").invokes(function(_, zoneType, opts)
        local zone = {
          description = opts.description,
          area = opts.area,
          areacolor = opts.areacolor
        }
        if opts.description == constants.POSITION_TYPES.MASK .. "/" .. operationalArea.name then
          maskZoneType = zoneType
          maskZone = zone
        end
        return zone
      end)

      PositionZones.update(
        constants.SIDES.BLUE,
        { operationalArea },
        {},
        { constants.POSITION_TYPES.RELOAD_POINT }
      )

      assert.are.equal(constants.ZONE_TYPES.STANDARD, maskZoneType)
      assert.are.equal("4dff6b6b", maskZone.areacolor)
      assert.are.same({
        constants.POSITION_TYPES.MASK .. "/" .. operationalArea.name .. "-RP-1",
        constants.POSITION_TYPES.MASK .. "/" .. operationalArea.name .. "-RP-2"
      }, operationalArea.mask.area)
    end)

    -- Negative: logs a specific failure reason when event trigger binding fails
    it("should log event trigger binding failure reason", function()
      local operationalArea = {
        name = "OPAREA-1",
        uShapeVertices = { "MASK-RP-1", "MASK-RP-2", "MASK-RP-3", "MASK-RP-4" },
        shelterPoints = {
          { latitude = 25.0, longitude = 121.0 }
        },
        RL = {
          { area = { "RL-RP-1", "RL-RP-2", "RL-RP-3", "RL-RP-4" } }
        }
      }

      trackStub(GameApi, "ScenEdit_GetEvent").returns({ triggers = {} })
      trackStub(GameApi, "VP_GetSide").returns({ standardzones = {} })
      trackStub(GameUtils, "normalizeToRPArray").invokes(function(zone)
        return zone.area
      end)
      trackStub(GameApi, "ScenEdit_SetTrigger").returns(true)
      trackStub(GameApi, "ScenEdit_SetEventTrigger").returns(nil)
      trackStub(GameApi, "ScenEdit_AddUnit").returns({ guid = "BUNKER-1" })
      trackStub(GameApi, "ScenEdit_AddZone").invokes(function(_, zoneType, opts)
        return {
          description = opts.description,
          area = opts.area,
          zoneType = zoneType
        }
      end)

      PositionZones.update(
        constants.SIDES.BLUE,
        { operationalArea },
        {},
        { constants.POSITION_TYPES.RELOAD_POINT }
      )

      assert.stub(errorStub).was.called(1)
      local message = errorStub.calls[1].vals[1]
      assert.is_not_nil(string.find(message, "reason=set_event_trigger_failed", 1, true))
      assert.is_not_nil(string.find(message, "area=OPAREA-1", 1, true))
      -- Two info reports: the cleanup report, plus the init report's non-failing rows,
      -- which the per-row routing keeps out of the error sink.
      assert.stub(logStub).was.called(2)
    end)

    it("should remove only the zones, triggers and bunkers of the areas being left", function()
      local POS = constants.POSITION_TYPES
      local side = constants.SIDES.RED
      local leftTrigger = Triggers.formatTriggerName(side, POS.RELOAD_POINT, 1, "LEFT")
      local keptTrigger = Triggers.formatTriggerName(side, POS.RELOAD_POINT, 1, "KEPT")
      local zones = {
        ["RL/1/LEFT"] = { description = "RL/1/LEFT", area = { { name = "LEFT-RL-1" }, { name = "LEFT-RL-2" } } },
        ["MASK/LEFT"] = { description = "MASK/LEFT", area = { { name = "LEFT-MASK-1" }, { name = "LEFT-MASK-2" } } },
        ["RL/1/KEPT"] = { description = "RL/1/KEPT", area = { { name = "KEPT-RL-1" }, { name = "KEPT-RL-2" } } },
      }
      local sideObj = {
        standardzones = {
          { description = "RL/1/LEFT" }, { description = "MASK/LEFT" }, { description = "RL/1/KEPT" },
        },
        getstandardzone = function(_, description) return zones[description] end,
        unitsInArea = function() return { { guid = "BUNKER-1" } } end,
      }
      local leftArea = {
        name = "LEFT",
        RL = { { area = { "LEFT-RL-1", "LEFT-RL-2" } } },
        mask = { area = { "LEFT-MASK-1", "LEFT-MASK-2" } },
      }

      trackStub(GameApi, "VP_GetSide").returns(sideObj)
      trackStub(GameApi, "ScenEdit_GetEvent").returns({
        triggers = {
          { UnitEntersArea = { Description = leftTrigger, Area = zones["RL/1/LEFT"].area } },
          { UnitEntersArea = { Description = keptTrigger, Area = zones["RL/1/KEPT"].area } },
        },
      })
      local removeZoneStub = trackStub(GameApi, "ScenEdit_RemoveZone").returns(true)
      local setTriggerStub = trackStub(GameApi, "ScenEdit_SetTrigger").returns(true)
      local setEventTriggerStub = trackStub(GameApi, "ScenEdit_SetEventTrigger").returns(true)
      local deleteRPStub = trackStub(GameApi, "ScenEdit_DeleteReferencePoint").returns(true)
      local deleteUnitStub = trackStub(GameApi, "ScenEdit_DeleteUnit").returns(true)

      PositionZones.update(side, {}, { leftArea }, { POS.RELOAD_POINT })

      local removedZones = {}
      for _, call in ipairs(removeZoneStub.calls) do
        table.insert(removedZones, call.vals[3].description)
      end
      table.sort(removedZones)
      assert.are.same({ "MASK/LEFT", "RL/1/LEFT" }, removedZones)

      local removedRPs = {}
      for _, call in ipairs(deleteRPStub.calls) do
        table.insert(removedRPs, call.vals[1].name)
      end
      table.sort(removedRPs)
      assert.are.same({ "LEFT-MASK-1", "LEFT-MASK-2", "LEFT-RL-1", "LEFT-RL-2" }, removedRPs)

      assert.stub(setTriggerStub).was.called(1)
      assert.are.same({ Description = leftTrigger, Mode = "remove" }, setTriggerStub.calls[1].vals[1])
      assert.stub(setEventTriggerStub).was.called(1)
      assert.are.equal(leftTrigger, setEventTriggerStub.calls[1].vals[2].description)

      assert.stub(deleteUnitStub).was.called_with({ guid = "BUNKER-1" })
      assert.stub(errorStub).was_not.called()
    end)
  end)
end)
