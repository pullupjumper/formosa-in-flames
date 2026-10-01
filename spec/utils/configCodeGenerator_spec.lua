-- ConfigCodeGenerator Unit Tests
local ConfigCodeGenerator = require("src.utils.configCodeGenerator")
local constants = require("src.core.constants")

describe("ConfigCodeGenerator", function()
  local function buildMlrsConfig()
    return {
      mlrs = {
        weaponCountDefault = 4,
        ammoThreshold = 2,
        ammunitions = {
          ["AHA-1"] = { name = "AHA-1", weaponCountCurrent = 8, weaponCountDefault = 8 },
        },
        resupplyUnits = {
          ["RES-1"] = { name = "RES-1", weaponCountCurrent = 4, weaponCountDefault = 2, unitCount = 3 },
        },
        firingUnits = {
          ["TEL-1"] = {
            name = "TEL-1",
            state = constants.MISSILE_SYSTEM_STATE.STATIC,
            weaponDBID = constants.WEAPONS.FD280,
            ammoThreshold = 2,
            dbid = constants.PLATFORMS.PHL16,
            missileSystem = "PHL-16",
          },
        },
      },
    }
  end

  describe("format", function()
    -- Positive: emits one block per section under the config path
    it("should emit ammunitions, resupplyUnits and firingUnits blocks for a system", function()
      local _, _, configStr = ConfigCodeGenerator.format("China", buildMlrsConfig())

      assert.is_truthy(configStr:find("config.red.ground.missileSystemTypes.mlrs.ammunitions = {", 1, true))
      assert.is_truthy(configStr:find("config.red.ground.missileSystemTypes.mlrs.resupplyUnits = {", 1, true))
      assert.is_truthy(configStr:find("config.red.ground.missileSystemTypes.mlrs.firingUnits = {", 1, true))
    end)

    -- Positive: side name resolves to side field
    it("should use side field blue for Taiwan", function()
      local _, _, configStr = ConfigCodeGenerator.format("Taiwan", buildMlrsConfig())

      assert.is_truthy(configStr:find("config.blue.ground.missileSystemTypes.mlrs.firingUnits = {", 1, true))
    end)

    -- Positive: wpn values are rewritten as weaponCountDefault references
    it("should reference weaponCountDefault with multiplier and divisor", function()
      local _, _, configStr = ConfigCodeGenerator.format("China", buildMlrsConfig())

      assert.is_truthy(configStr:find("weaponCountCurrent = config.red.ground.missileSystemTypes.mlrs.weaponCountDefault * 2,", 1, true))
      assert.is_truthy(configStr:find("weaponCountDefault = config.red.ground.missileSystemTypes.mlrs.weaponCountDefault / 2,", 1, true))
      assert.is_truthy(configStr:find("weaponCountCurrent = config.red.ground.missileSystemTypes.mlrs.weaponCountDefault,", 1, true))
    end)

    -- Positive: constants and thresholds are emitted as references
    it("should serialize state, weapon, platform and ammoThreshold as references", function()
      local _, _, configStr = ConfigCodeGenerator.format("China", buildMlrsConfig())

      assert.is_truthy(configStr:find("state = constants.MISSILE_SYSTEM_STATE.STATIC,", 1, true))
      assert.is_truthy(configStr:find("weaponDBID = constants.WEAPONS.FD280,", 1, true))
      assert.is_truthy(configStr:find("dbid = constants.PLATFORMS.PHL16,", 1, true))
      assert.is_truthy(configStr:find("ammoThreshold = config.red.ground.missileSystemTypes.mlrs.ammoThreshold,", 1, true))
    end)

    -- Positive: missileSystem is quoted and follows dbid
    it("should serialize missileSystem as a quoted string after dbid", function()
      local _, _, configStr = ConfigCodeGenerator.format("China", buildMlrsConfig())

      assert.is_truthy(configStr:find("dbid = constants.PLATFORMS.PHL16,\n    missileSystem = \"PHL-16\",", 1, true))
    end)

    -- Boundary: entries without firingUnits are skipped
    it("should skip entries that have no firingUnits", function()
      local config = { policy = { isAuto = true } }
      local _, _, configStr = ConfigCodeGenerator.format("China", config)

      assert.are.equal("", configStr)
    end)
  end)
end)
