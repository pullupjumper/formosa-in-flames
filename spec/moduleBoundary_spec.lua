---@diagnostic disable: need-check-nil, assign-type-mismatch, cast-local-type, param-type-mismatch, inject-field
-- Module Boundary Tests
-- A module folder with an init.lua is a package: code outside the folder must go through
-- its init.lua facade instead of requiring the package's internal files.

---List Lua source files under a directory
---@param dir string Directory to scan
---@return string[] # File paths using forward slashes
local function listLuaFiles(dir)
  local files = {}
  local handle = assert(io.popen('find "' .. dir .. '" -name "*.lua"'))
  for path in handle:lines() do
    table.insert(files, path)
  end
  handle:close()
  return files
end

---Find package names: folders under src/modules that own an init.lua
---@return table<string, boolean> # Set of package folder names
local function findPackages()
  local packages = {}
  for _, path in ipairs(listLuaFiles("src/modules")) do
    local name = path:match("^src/modules/([%w_]+)/init%.lua$")
    if name then
      packages[name] = true
    end
  end
  return packages
end

---Collect requires that reach into another package's internal files
---@param packages table<string, boolean> Set of package folder names
---@return string[] # Violations as "file:line -> module"
local function findBoundaryViolations(packages)
  local violations = {}
  for _, path in ipairs(listLuaFiles("src")) do
    local lineNumber = 0
    for line in io.lines(path) do
      lineNumber = lineNumber + 1
      local package, internal = line:match('require%("src%.modules%.([%w_]+)%.([%w_]+)"%)')
      local isInsidePackage = path:find("^src/modules/" .. (package or "") .. "/") ~= nil
      if package and packages[package] and internal ~= "init" and not isInsidePackage then
        table.insert(violations, string.format("%s:%d -> %s.%s", path, lineNumber, package, internal))
      end
    end
  end
  return violations
end

describe("Module boundary", function()
  it("should find the known packages", function()
    local packages = findPackages()

    assert.is_true(packages.missileSystem)
    assert.is_true(packages.strikePlanner)
    assert.is_true(packages.landingOps)
  end)

  -- Negative: outside code must not require a package's internal files
  it("should only reach packages through their init.lua facade", function()
    local violations = findBoundaryViolations(findPackages())

    assert.are.same({}, violations)
  end)
end)
