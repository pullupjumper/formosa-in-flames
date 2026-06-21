-- MissileSystem Triggers Unit Tests
local stub = require("luassert.stub")
local Triggers = require("src.modules.missileSystem.triggers")
local GameApi = require("src.utils.gameApi")
local GameUtils = require("src.utils.gameUtils")
local Logger = require("src.utils.logger")
local constants = require("src.core.constants")

describe("MissileSystem Triggers", function()
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

  -- ============================================================================
  -- initEventTriggers
  -- ============================================================================

  describe("initEventTriggers", function()
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

      trackStub(GameUtils, "getCachedSideConfig").returns({ enemySide = constants.SIDES.ENEMY })
      trackStub(GameUtils, "removeZones").returns(0, true)
      trackStub(GameUtils, "removeEventTriggers").returns(0, true)
      trackStub(GameApi, "ScenEdit_GetEvent").returns({ triggers = {} })
      trackStub(GameApi, "VP_GetSide").returns({ standardzones = {} })
      trackStub(GameUtils, "convertToRPArray").invokes(function(zone)
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

      Triggers.initEventTriggers(
        operationalAreas,
        {},
        { constants.POSITION_TYPES.RELOAD_POINT },
        constants.SIDES.ENEMY
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

      trackStub(GameUtils, "getCachedSideConfig").returns({ enemySide = constants.SIDES.ENEMY })
      trackStub(GameUtils, "removeZones").returns(0, true)
      trackStub(GameUtils, "removeEventTriggers").returns(0, true)
      trackStub(GameApi, "ScenEdit_GetEvent").returns({ triggers = {} })
      trackStub(GameApi, "VP_GetSide").returns({ standardzones = {} })
      trackStub(GameUtils, "convertToRPArray").invokes(function(zone)
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

      Triggers.initEventTriggers(
        { operationalArea },
        {},
        { constants.POSITION_TYPES.RELOAD_POINT },
        constants.SIDES.PLAYER
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

      trackStub(GameUtils, "getCachedSideConfig").returns({ enemySide = constants.SIDES.ENEMY })
      trackStub(GameApi, "ScenEdit_GetEvent").returns({ triggers = {} })
      trackStub(GameApi, "VP_GetSide").returns({ standardzones = {} })
      trackStub(GameUtils, "convertToRPArray").invokes(function(zone)
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

      Triggers.initEventTriggers(
        { operationalArea },
        {},
        { constants.POSITION_TYPES.RELOAD_POINT },
        constants.SIDES.PLAYER
      )

      assert.stub(errorStub).was.called(1)
      local message = errorStub.calls[1].vals[1]
      assert.is_not_nil(string.find(message, "reason=set_event_trigger_failed", 1, true))
      assert.is_not_nil(string.find(message, "area=\"OPAREA-1\"", 1, true))
      assert.stub(logStub).was.called(1)
    end)
  end)
end)
