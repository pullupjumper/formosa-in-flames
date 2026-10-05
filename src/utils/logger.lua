local config = require("src.core.config")

local Logger = {}

-- Toggle whether in game (set by you in main)
Logger.inGame = type(ScenEdit_SpecialMessage) == "userdata"


---Print formatted box message to player
---@param sideName string
---@param ... string Variable number of string arguments to be printed inside the box
local function logBox(sideName, ...)
  -- Collect all string parameters into array
  local strings = { ... }

  local maxLen = 0
  for _, str in ipairs(strings) do
    if #str > maxLen then
      maxLen = #str
    end
  end

  -- local width = 70

  -- local border = string.rep(" ", width)

  local middleLines = {}
  for _, str in ipairs(strings) do
    local middle = "  " .. str
    table.insert(middleLines, middle)
  end

  -- Combine into a single string
  local boxString = "\n" .. table.concat(middleLines, "\n")

  -- Output all at once
  ScenEdit_SpecialMessage(sideName, boxString)
end

---@param message string
---@param level string
local function logMessage(message, level)
  if Logger.inGame then
    logBox("playerside", string.format("[%s] %s", level, message))
  end

  print(string.format("[%s] %s", level, message))
end

---Log with module name and verbose check
---@param moduleNameOrMessage string
---@param message? string
function Logger.log(moduleNameOrMessage, message)
  local moduleConfig = config.logging and config.logging.modules and config.logging.modules[moduleNameOrMessage]

  if moduleConfig and moduleConfig.verbose then
    local formattedMessage = string.format("[%s] %s", moduleNameOrMessage, message)
    logMessage(formattedMessage, "LOG")
  elseif moduleNameOrMessage and not message then
    logMessage(moduleNameOrMessage, "LOG")
  end
end

---Error logging (always output, no verbose check)
---@param message string
function Logger.error(message)
  logMessage(message, "ERROR")
end

---Warning logging (similar to error, always output)
---@param message string
function Logger.warn(message)
  logMessage(message, "WARN")
end

return Logger
