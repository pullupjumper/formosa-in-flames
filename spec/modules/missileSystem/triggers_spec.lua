-- MissileSystem Triggers Unit Tests
local Triggers = require("src.modules.missileSystem.triggers")
local constants = require("src.core.constants")

describe("MissileSystem Triggers", function()
  describe("trigger name protocol", function()
    local POS = constants.POSITION_TYPES

    it("should parse back the position type of every trigger name it formats", function()
      for _, positionType in ipairs({ POS.FIRING_POINT, POS.HIDE_AREA, POS.RELOAD_POINT, POS.AMMO_HOLDING_AREA }) do
        local name = Triggers.formatTriggerName(constants.SIDES.RED, positionType, 3, "AreaA")
        assert.are.equal(positionType, Triggers.parsePositionType(name))
      end
    end)

    it("should not parse position types that have no arrival handling", function()
      assert.is_nil(Triggers.parsePositionType(Triggers.formatTriggerName(constants.SIDES.RED, POS.MASK, 1, "AreaA")))
      assert.is_nil(Triggers.parsePositionType("Arrive in HAPPY - 1 - AreaA"))
      assert.is_nil(Triggers.parsePositionType("Random text with RL inside"))
      assert.is_nil(Triggers.parsePositionType(nil))
    end)
  end)
end)
