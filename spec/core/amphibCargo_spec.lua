---@diagnostic disable: need-check-nil, assign-type-mismatch, cast-local-type, param-type-mismatch, inject-field
-- AmphibOps cargo balance Unit Tests (pins the numbers in docs/landingOps/hovercraftCapacity.md)
local config = require("src.core.config")
local constants = require("src.core.constants")

describe("config.red.amphibOps cargo balance", function()
  local amphibOps = config.red.amphibOps
  local CARGO_KEY_BY_SHIP = { type076 = "type075" }

  ---@param manifestKey string
  ---@return table<number, number> # Count per DBID in one ship's manifest
  local function countManifest(manifestKey)
    local totals = {}
    for _, item in ipairs(amphibOps.cargo[manifestKey] or {}) do
      totals[item.dbid] = (totals[item.dbid] or 0) + item.num
    end
    return totals
  end

  ---Sum the cargo of every ship in every zone
  ---@param shipKeys string[]
  ---@return table<number, number> # Count per DBID
  local function sumCargo(shipKeys)
    local totals = {}
    for _, zone in ipairs(amphibOps.zones) do
      for _, group in ipairs(zone.fleet.groups) do
        for _, shipKey in ipairs(shipKeys) do
          local shipCount = group.shipCounts[shipKey] or 0
          for dbid, num in pairs(countManifest(CARGO_KEY_BY_SHIP[shipKey] or shipKey)) do
            totals[dbid] = (totals[dbid] or 0) + shipCount * num
          end
        end
      end
    end
    return totals
  end

  it("should give the amphibious composite brigades 135 PLZ-96 (5 brigades of 27)", function()
    local totals = sumCargo({ "type075", "type076", "type071" })

    assert.are.equal(135, totals[constants.PLATFORMS.PLZ96])
  end)

  it("should give the RORO ships 252 ZBD-04 across the heavy-brigade zones", function()
    local totals = sumCargo({ "roro" })

    assert.are.equal(252, totals[constants.PLATFORMS.ZBD04])
  end)

  it("should have 6 RORO in total and none in Penghu", function()
    local roroCountMap = {}
    for _, zone in ipairs(amphibOps.zones) do
      local count = 0
      for _, group in ipairs(zone.fleet.groups) do
        count = count + (group.shipCounts.roro or 0)
      end
      roroCountMap[zone.name] = count
    end

    assert.are.same({ Taoyuan = 3, Sishu = 3, Penghu = 0 }, roroCountMap)
  end)
end)
