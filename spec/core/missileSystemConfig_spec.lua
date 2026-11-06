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

  it("should link every launcher to its own transloader and canister stock, and back", function()
    local problems = {}

    forEachSystem(function(label, systemConfig)
      local transloaderLinks, canisterStockLinks = {}, {}

      for _, launcher in pairs(systemConfig.launchers) do
        local transloader = systemConfig.transloaders[launcher.transloader]
        if not transloader then
          table.insert(problems, label .. " no transloader: " .. launcher.name)
        else
          transloaderLinks[transloader.name] = (transloaderLinks[transloader.name] or 0) + 1
          canisterStockLinks[transloader.canisterStock] = (canisterStockLinks[transloader.canisterStock] or 0) + 1
          if transloader.launcher ~= launcher.name then
            table.insert(problems, label .. " transloader links back elsewhere: " .. transloader.name)
          end
          if not systemConfig.canisterStocks[transloader.canisterStock] then
            table.insert(problems, label .. " no canister stock: " .. transloader.name)
          end
        end
      end

      for name in pairs(systemConfig.transloaders) do
        if transloaderLinks[name] ~= 1 then
          table.insert(problems, label .. " transloader linked " .. (transloaderLinks[name] or 0) .. " times: " .. name)
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

  -- Group members are named "<prefix><ordinal>, <launcher name>", so every name must end with the launcher name
  it("should end every transloader and canister stock name with its launcher name", function()
    local problems = {}

    forEachSystem(function(label, systemConfig)
      for _, launcher in pairs(systemConfig.launchers) do
        local transloader = systemConfig.transloaders[launcher.transloader]
        local canisterStock = transloader and systemConfig.canisterStocks[transloader.canisterStock]
        for _, descriptor in ipairs({ transloader, canisterStock }) do
          if not endsWith(descriptor.name, ", " .. launcher.name) then
            table.insert(problems, label .. " " .. descriptor.name)
          end
        end
      end
    end)

    assert.are.same({}, problems)
  end)

  -- The reload cycle hides a transloader after a reload on the strength of its meeting in the
  -- launcher's RL zone, which holds only while both units share one operational area.
  it("should place every launcher and its transloader in the same operational area", function()
    local problems = {}

    forEachSystem(function(label, systemConfig)
      for _, launcher in pairs(systemConfig.launchers) do
        local transloader = systemConfig.transloaders[launcher.transloader]
        if transloader and transloader.operationalArea ~= launcher.operationalArea then
          table.insert(problems, label .. " " .. launcher.name)
        end
      end
    end)

    assert.are.same({}, problems)
  end)

  it("should name every launcher once per side, whatever its missile system type", function()
    local problems = {}

    for _, sideKey in ipairs({ "red", "blue", "ally" }) do
      local ground = config[sideKey] and config[sideKey].ground
      local owners = {}

      for systemType, systemConfig in pairs(ground and ground.missileSystemTypes or {}) do
        for _, launcher in pairs(systemConfig.launchers) do
          if owners[launcher.name] then
            table.insert(problems, sideKey .. " " .. launcher.name .. " in " .. owners[launcher.name] .. " and " .. systemType)
          end
          owners[launcher.name] = systemType
        end
      end
    end

    assert.are.same({}, problems)
  end)

  -- Fire support looks each launcher's weapon up by system and name, so a stray name would be skipped silently.
  it("should list only launchers of the task's own missile system in fire support task templates", function()
    local problems = {}
    local missileSystemTypes = config.red.ground.missileSystemTypes

    for templateName, taskTemplates in pairs(config.red.fireSupportTaskTemplates) do
      for _, taskTemplate in ipairs(taskTemplates) do
        local systemConfig = missileSystemTypes[string.lower(taskTemplate.missileSystemType)]
        for _, launcherName in ipairs(taskTemplate.launcherNames) do
          if not (systemConfig and systemConfig.launchers[launcherName]) then
            table.insert(problems, templateName .. "/" .. taskTemplate.name .. " " .. launcherName)
          end
        end
      end
    end

    assert.are.same({}, problems)
  end)
end)
