---@diagnostic disable: need-check-nil, assign-type-mismatch, cast-local-type, param-type-mismatch, inject-field
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

  describe("dump", function()
    local originalPrint = print
    local printed

    before_each(function()
      printed = {}
      _G.print = function(s) printed[#printed + 1] = s end
    end)

    after_each(function()
      _G.print = originalPrint
    end)

    -- Positive: one marked section per generated block, tagged by side
    it("should print marked AREAS, OPERATIONAL_AREAS and CONFIG sections", function()
      ConfigCodeGenerator.dump("China", buildMlrsConfig())

      assert.are.equal(3, #printed)
      assert.is_truthy(printed[1]:find("^@@GEN_BEGIN CHINA_AREAS_BLOCK\n"))
      assert.is_truthy(printed[1]:find("\n@@GEN_END CHINA_AREAS_BLOCK$"))
      assert.is_truthy(printed[2]:find("^@@GEN_BEGIN CHINA_OPERATIONAL_AREAS_BLOCK\n"))
      assert.is_truthy(printed[3]:find("^@@GEN_BEGIN CONFIG_red\nconfig.red.ground.missileSystemTypes.mlrs.ammunitions = {"))
    end)

    -- Boundary: table wrapper is stripped so the body fits between START/END markers
    it("should strip the constants wrapper lines from area sections", function()
      ConfigCodeGenerator.dump("China", buildMlrsConfig())

      assert.is_nil(printed[1]:find("constants.AREAS = {", 1, true))
      assert.is_nil(printed[2]:find("constants.OPERATIONAL_AREAS = {", 1, true))
    end)
  end)
end)
