-- Guard: landingOps functions take at most 4 parameters (docs/specs/refactor-landing-ops-param-count.md)
local MAX_PARAMS = 4
local SOURCE_DIR = "src/modules/landingOps"

---@return string[]
local function listSourceFiles()
  local pipe = assert(io.popen('ls "' .. SOURCE_DIR .. '"/*.lua'))
  local files = {}
  for path in pipe:lines() do
    table.insert(files, path)
  end
  pipe:close()
  return files
end

describe("landingOps parameter count", function()
  it("should keep every function at or below " .. MAX_PARAMS .. " parameters", function()
    local offenders = {}

    for _, path in ipairs(listSourceFiles()) do
      local lineNumber = 0
      for line in io.lines(path) do
        lineNumber = lineNumber + 1
        local params = line:match("^%s*local function [%w_]+%(([^)]*)%)") or line:match("^%s*function [%w_.:]+%(([^)]*)%)")
        if params and params ~= "" then
          local count = select(2, params:gsub(",", ",")) + 1
          if count > MAX_PARAMS then
            table.insert(offenders, path .. ":" .. lineNumber .. " (" .. count .. ")")
          end
        end
      end
    end

    assert.are.same({}, offenders)
  end)
end)
