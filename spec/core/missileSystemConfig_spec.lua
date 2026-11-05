---@diagnostic disable: need-check-nil, assign-type-mismatch, cast-local-type, param-type-mismatch, inject-field
-- Missile system config link Unit Tests (Deployment follows these links and names members from them)
local config = require("src.core.config")

describe("config ground.missileSystemTypes batteries", function()
  ---Call fn for every configured missile system of every side
  ---@param fn fun(label: string, systemConfig: SBJ__MissileSystemConfig)
  local function forEachSystem(fn)
    for _, sideKey in ipairs({ "red", "blue", "ally" }) do
      local ground = config[sideKey] and config[sideKey].ground
      for systemType, systemConfig in pairs(ground and ground.missileSystemTypes or {}) do
        fn(sideKey .. "." .. systemType, systemConfig)
      end
    end
  end

  ---@param name string
  ---@param suffix string
  ---@return boolean
  local function endsWith(name, suffix)
    return name:sub(-#suffix) == suffix
  end

  it("should link every firing unit to its own resupply unit and canister stock, and back", function()
    local problems = {}

    forEachSystem(function(label, systemConfig)
      local resupplyLinks, canisterStockLinks = {}, {}

      for _, firing in pairs(systemConfig.firingUnits) do
        local resupply = systemConfig.resupplyUnits[firing.resupplyUnit]
        if not resupply then
          table.insert(problems, label .. " no resupply unit: " .. firing.name)
        else
          resupplyLinks[resupply.name] = (resupplyLinks[resupply.name] or 0) + 1
          canisterStockLinks[resupply.canisterStock] = (canisterStockLinks[resupply.canisterStock] or 0) + 1
          if resupply.firingUnit ~= firing.name then
            table.insert(problems, label .. " resupply links back elsewhere: " .. resupply.name)
          end
          if not systemConfig.canisterStocks[resupply.canisterStock] then
            table.insert(problems, label .. " no canister stock: " .. resupply.name)
          end
        end
      end

      for name in pairs(systemConfig.resupplyUnits) do
        if resupplyLinks[name] ~= 1 then
          table.insert(problems, label .. " resupply unit linked " .. (resupplyLinks[name] or 0) .. " times: " .. name)
        end
      end
      for name in pairs(systemConfig.canisterStocks) do
        if canisterStockLinks[name] ~= 1 then
          table.insert(problems, label .. " canister stock linked " .. (canisterStockLinks[name] or 0) .. " times: " .. name)
        end
      end
    end)

    assert.are.same({}, problems)
  end)

  -- Group members are named "<prefix><ordinal>, <firing unit name>", so every name must end with the firing unit name
  it("should end every resupply unit and canister stock name with its firing unit name", function()
    local problems = {}

    forEachSystem(function(label, systemConfig)
      for _, firing in pairs(systemConfig.firingUnits) do
        local resupply = systemConfig.resupplyUnits[firing.resupplyUnit]
        local canisterStock = resupply and systemConfig.canisterStocks[resupply.canisterStock]
        for _, descriptor in ipairs({ resupply, canisterStock }) do
          if not endsWith(descriptor.name, ", " .. firing.name) then
            table.insert(problems, label .. " " .. descriptor.name)
          end
        end
      end
    end)

    assert.are.same({}, problems)
  end)

  -- The reload cycle hides a resupply unit after a reload on the strength of its meeting in the
  -- firing unit's RL zone, which holds only while both units share one operational area.
  it("should place every firing unit and its resupply unit in the same operational area", function()
    local problems = {}

    forEachSystem(function(label, systemConfig)
      for _, firing in pairs(systemConfig.firingUnits) do
        local resupply = systemConfig.resupplyUnits[firing.resupplyUnit]
        if resupply and resupply.operationalArea ~= firing.operationalArea then
          table.insert(problems, label .. " " .. firing.name)
        end
      end
    end)

    assert.are.same({}, problems)
  end)
end)
