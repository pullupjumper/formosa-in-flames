local config = require("src.core.config")

local Logger = {}

-- Toggle whether in game (set by you in main)
Logger.inGame = type(ScenEdit_SpecialMessage) == "userdata"


---Print formatted box message to player
---@param side string The side the message is visible to (sidename may also be used)
---@param ... string Variable number of string arguments to be printed inside the box
local function printBox(side, ...)
  -- Collect all string parameters into array
  local strings = { ... }

  -- Find the length of the longest string
  local maxLen = 0
  for _, str in ipairs(strings) do
    if #str > maxLen then
      maxLen = #str
    end
  end

  -- Calculate border width
  -- local width = 70

  -- Build top and bottom border: continuous -
  -- local border = string.rep(" ", width)

  -- Build middle lines
  local middleLines = {}
  for _, str in ipairs(strings) do
    local middle = "  " .. str
    table.insert(middleLines, middle)
  end

  -- Combine into a single string
  local boxString = "\n" .. table.concat(middleLines, "\n")

  -- Output all at once
  ScenEdit_SpecialMessage(side, boxString)
end

---Log with module name and verbose check
---@param moduleName string Module name to check verbose setting
---@param message string Log message
function Logger.log(moduleName, message)
  local moduleConfig = config.logging and config.logging.modules and config.logging.modules[moduleName]

  if moduleConfig and moduleConfig.verbose then
    local formattedMessage = string.format("[%s] %s", moduleName, message)
    if Logger.inGame then
      printBox("playerside", "[LOG] " .. formattedMessage)
    else
      print("[LOG] " .. formattedMessage)
    end
  end
end

---Error logging (always output, no verbose check)
---@param message string Error message
function Logger.error(message)
  if Logger.inGame then
    printBox("playerside", "[ERROR] " .. message)
  else
    print("[ERROR] " .. message)
  end
end

---Warning logging (similar to error, always output)
---@param message string Warning message
function Logger.warn(message)
  if Logger.inGame then
    printBox("playerside", "[WARN] " .. message)
  else
    print("[WARN] " .. message)
  end
end

return Logger
