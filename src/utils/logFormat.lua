local LogFormat = {}

-- Project log format examples:
--
-- Batch summary:
-- [zone=Taoyuan] Transfer and assign: total=2 ok=1 skip=1 fail=0 error=0 warn=0
--   [OK] ship=Type075-1 dbid=12345
--   [SKIP] guid=SHIP-002 reason=unit_not_found
--
-- Operation-scoped summary:
-- [operation=Kinmen] Move to staging area: total=3 ok=2 skip=1 fail=0 error=0 warn=0
--   [OK] ship=Type071-1 dbid=67890 dest=type071 area=LPD index=1
--   [SKIP] ship=Unknown dbid=99999 reason=unmatched
--
-- Single event:
-- [scope=fireSupportGate] [HOLD] reason=srbm_low total=25 threshold=30 firing=20 resupply=40 depot=10
--
-- Entry messages should prefer key=value fields. Use reason=<snake_case> for
-- non-OK outcomes so failed and skipped cases are easy to search.

local STATUS = {
  OK = true,
  SKIP = true,
  FAIL = true,
  ERROR = true,
  WARN = true,
  HOLD = true,
  RESUME = true,
}

---Normalize a status tag for log output
---@param tag string Status tag with or without square brackets
---@return string # Normalized status tag without square brackets
local function normalizeTag(tag)
  local normalized = tostring(tag or "OK"):gsub("^%[", ""):gsub("%]$", "")
  if STATUS[normalized] then
    return normalized
  end
  return "OK"
end

---Format a single batch log entry
---@param tag string Status tag with or without square brackets
---@param message string Entry message
---@return string # Formatted log entry
function LogFormat.entry(tag, message)
  return string.format("  [%s] %s", normalizeTag(tag), message)
end

---Format a human-readable value without replacing whitespace
---@param value any Value to format
---@return string # Printable value for quoted log fields
function LogFormat.readable(value)
  if value == nil then
    return "unknown"
  end

  return tostring(value)
end

---Format a value for key=value log fields
---@param value any Value to format
---@return string # Log-safe value
function LogFormat.value(value)
  local formatted = LogFormat.readable(value):gsub("%s+", "_")
  return formatted
end

---Format a lower-case token for action/reason fields
---@param value any Value to format
---@return string # Lower-case log-safe token
function LogFormat.token(value)
  return string.lower(LogFormat.value(value))
end

---Count entry status tags in a formatted entry list
---@param entries string[] Formatted log entries
---@return table<string, integer> # Count by status tag
local function countStatuses(entries)
  local counts = { OK = 0, SKIP = 0, FAIL = 0, ERROR = 0, WARN = 0, HOLD = 0, RESUME = 0 }

  for _, entry in ipairs(entries) do
    local tag = entry:match("^%s*%[([A-Z]+)%]")
    if tag and counts[tag] ~= nil then
      counts[tag] = counts[tag] + 1
    end
  end

  return counts
end

---Format a scope label for a log summary
---@param scopeKey string Scope key name
---@param scopeValue string|number Scope value
---@return string # Formatted scope label
local function formatScope(scopeKey, scopeValue)
  return string.format("[%s=%s]", scopeKey, tostring(scopeValue))
end

---Format a batch log summary with status counts
---@param scopeKey string Scope key name
---@param scopeValue string|number Scope value
---@param action string Action description
---@param entries string[] Formatted log entries
---@return string # Formatted summary and entries
function LogFormat.summary(scopeKey, scopeValue, action, entries)
  local counts = countStatuses(entries)
  return string.format(
    "%s %s: total=%d ok=%d skip=%d fail=%d error=%d warn=%d\n%s",
    formatScope(scopeKey, scopeValue),
    action,
    #entries,
    counts.OK,
    counts.SKIP,
    counts.FAIL,
    counts.ERROR,
    counts.WARN,
    table.concat(entries, "\n")
  )
end

---Format a one-line scoped event log
---@param scopeKey string Scope key name
---@param scopeValue string|number Scope value
---@param tag string Status tag
---@param message string Event message
---@return string # Formatted scoped event log
function LogFormat.event(scopeKey, scopeValue, tag, message)
  return string.format("%s [%s] %s", formatScope(scopeKey, scopeValue), normalizeTag(tag), message)
end

return LogFormat
