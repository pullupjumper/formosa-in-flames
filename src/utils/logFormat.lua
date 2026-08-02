local Logger = require("src.utils.logger")

local LogFormat = {}

-- Project log format.
--
-- LogFormat.report is the one emitter every module should reach for. It buffers
-- rows, splits FAIL/ERROR onto the error sink, and prints nothing when a sink is
-- empty:
--
--   local report = LogFormat.report(constants.TAGS.AIR, "dynamicAirOperations", "Process operations")
--   report.add("OK", { operation = "Strike", packages = "2/3" }, detailRows)
--   report.emit()
--
-- produces
--
--   [AIR] dynamicAirOperations: Process operations | total=2 ok=1 skip=1
--     [OK]   operation=Strike wave=AIR/Strike/1 packages=2/3 targets=8
--       [SKIP] package=3 role=striker required=4 available=1 reason=insufficient_aircraft
--     [SKIP] operation=Recce packages=0/2 targets=0 reason=no_valid_packages
--
-- Detail rows are indented one level under their parent, follow the parent to
-- its sink, and are excluded from the rollup, so total always means "how many
-- items did this pass handle". Counts that are zero are omitted.
--
-- Entry messages should prefer key=value fields. Use reason=<snake_case> for
-- non-OK outcomes so failed and skipped cases are easy to search.
--
-- Producers should return SBJ__LogResult ({ tag = ..., fields = ... }) and let
-- the report do the formatting. Never pre-format a row into a string and then
-- stuff it into another field.
--
-- Field order: LEAD_ORDER keys first, then unlisted keys alphabetically, then
-- OUTCOME_ORDER, so reason and detail always come last. A new field needs no
-- registration -- it simply sorts alphabetically in the middle tier. Values are
-- quoted only when they contain whitespace or separators, and nil fields are
-- dropped.
--
-- LogFormat.line covers the one case report does not: a lone event that is not
-- part of a batch. It takes the same (tag, fields) pair and picks its own sink
-- at the call site.

local STATUS = {
  OK = true,
  SKIP = true,
  FAIL = true,
  ERROR = true,
  WARN = true,
  HOLD = true,
  RESUME = true,
}

-- Statuses routed to the error sink instead of the info log. Every other
-- status, including a typo downgraded to WARN, stays on the info log.
local ERROR_STATUS = {
  FAIL = true,
  ERROR = true,
}

-- Fields worth seeing first, broadest scope to concrete identity. Deliberately
-- short: anything not listed sorts alphabetically in the middle tier, so adding
-- a field never requires editing this table.
local LEAD_ORDER = {
  "module", "side", "system", "operation", "wave", "matrix", "package", "mission", "task",
  "zone", "area", "base",
  "unit", "ship", "sag", "aircraft", "target",
  "role", "type", "state", "action",
  "guid", "dbid", "index",
}

-- Outcome fields are emitted after every other field, including unknown keys,
-- so a log line always ends with why it happened.
local OUTCOME_ORDER = { "result", "status", "reason", "detail" }

-- Status counts printed in this order, and only when non-zero.
local ROLLUP_ORDER = { "OK", "SKIP", "FAIL", "ERROR", "WARN", "HOLD", "RESUME" }

-- Nesting levels for report rows.
local ROW_INDENT = "  "
local DETAIL_INDENT = "    "

local LEAD_RANK = {}
for index, key in ipairs(LEAD_ORDER) do
  LEAD_RANK[key] = index
end

local OUTCOME_RANK = {}
for index, key in ipairs(OUTCOME_ORDER) do
  OUTCOME_RANK[key] = index
end

---Normalize a status tag for log output
---A nil tag defaults to OK; an unrecognized tag falls back to WARN so a typo
---is never silently counted as a success.
---@param tag string Status tag with or without square brackets
---@return string # Normalized status tag without square brackets
local function normalizeTag(tag)
  if tag == nil then
    return "OK"
  end

  local normalized = tostring(tag):gsub("^%[", ""):gsub("%]$", "")
  if STATUS[normalized] then
    return normalized
  end
  return "WARN"
end

---Format a single value for key=value output
---Collapses whitespace and quotes the value when it would break field parsing.
---@param value any Value to format
---@return string # Field value, quoted only when required
local function formatFieldValue(value)
  if type(value) == "boolean" then
    return tostring(value)
  end

  local text = tostring(value):gsub("%s+", " ")
  if text == "" or text:find("[%s=\"]") then
    local escaped = text:gsub("\"", "\\\"")
    return "\"" .. escaped .. "\""
  end

  return text
end

---Rank a field key into an ordering tier
---Lead fields first, unlisted fields alphabetically, outcome fields last.
---@param key string Field key
---@return integer tier Ordering tier, lower sorts first
---@return integer|nil rank Rank inside the tier, nil for unlisted fields
local function fieldTier(key)
  if OUTCOME_RANK[key] then
    return 3, OUTCOME_RANK[key]
  end
  if LEAD_RANK[key] then
    return 1, LEAD_RANK[key]
  end
  return 2, nil
end

---Compare two field keys by tier, then rank, then alphabetically
---@param left string First field key
---@param right string Second field key
---@return boolean # True when left sorts before right
local function compareFieldKeys(left, right)
  local leftTier, leftRank = fieldTier(left)
  local rightTier, rightRank = fieldTier(right)

  if leftTier ~= rightTier then
    return leftTier < rightTier
  end
  if leftRank and rightRank then
    return leftRank < rightRank
  end

  return left < right
end

---Merge log field tables left to right into a new table
---Producers building deferred SBJ__LogResult values need the merged table
---rather than the formatted string LogFormat.fields returns.
---@param fields table<string, any>|nil Base field values
---@param extraFields? table<string, any> Additional fields overriding fields
---@param moreFields? table<string, any> Additional fields overriding extraFields
---@return table<string, any> # New table holding the merged fields
function LogFormat.merge(fields, extraFields, moreFields)
  local merged = {}

  for _, source in ipairs({ fields or {}, extraFields or {}, moreFields or {} }) do
    for key, value in pairs(source) do
      merged[key] = value
    end
  end

  return merged
end

---Format key=value fields in canonical order
---Tables merge left to right; nil values are omitted because Lua table
---constructors cannot hold them.
---@param fields table<string, any> Field values keyed by field name
---@param extraFields? table<string, any> Additional fields overriding fields
---@param moreFields? table<string, any> Additional fields overriding extraFields
---@return string # Space separated key=value pairs in canonical order
function LogFormat.fields(fields, extraFields, moreFields)
  local merged = LogFormat.merge(fields, extraFields, moreFields)

  local keys = {}
  for key in pairs(merged) do
    table.insert(keys, key)
  end
  table.sort(keys, compareFieldKeys)

  local parts = {}
  for _, key in ipairs(keys) do
    table.insert(parts, key .. "=" .. formatFieldValue(merged[key]))
  end

  return table.concat(parts, " ")
end

---Check whether a status tag belongs on the error log
---@param tag string Status tag with or without square brackets
---@return boolean # True when the tag routes to the error sink
local function isErrorTag(tag)
  return ERROR_STATUS[normalizeTag(tag)] == true
end

-- ============================================================================
-- Batched Report
-- ============================================================================

---Format a single report row
---Tags are padded so the field columns line up for the common statuses.
---@param tag string Status tag with or without square brackets
---@param fields table<string, any> Field values keyed by field name
---@param indent string Leading whitespace establishing the nesting level
---@return string # Formatted row
local function formatRow(tag, fields, indent)
  return string.format("%s%-6s %s", indent, "[" .. normalizeTag(tag) .. "]", LogFormat.fields(fields))
end

---Format a standalone one-line log row
---Carries no indent: report rows nest under a header, a lone event does not.
---The scope belongs in fields like any other key.
---@param tag string Status tag with or without square brackets
---@param fields table<string, any> Field values keyed by field name
---@return string # Formatted row
function LogFormat.line(tag, fields)
  return formatRow(tag, fields, "")
end

---Format the non-zero status counts for a report header
---Detail rows are excluded, so total counts the items the pass handled.
---@param rows SBJ__LogResult[] Parent rows routed to one sink
---@return string # Rollup fragment such as "total=2 ok=1 skip=1"
local function formatRollup(rows)
  local counts = {}
  for _, row in ipairs(rows) do
    local tag = normalizeTag(row.tag)
    counts[tag] = (counts[tag] or 0) + 1
  end

  local parts = { "total=" .. #rows }
  for _, tag in ipairs(ROLLUP_ORDER) do
    if counts[tag] then
      table.insert(parts, string.lower(tag) .. "=" .. counts[tag])
    end
  end

  return table.concat(parts, " ")
end

---Render one report sink into its header, rows and nested detail rows
---@param scope string Scope label
---@param action string Action description
---@param rows SBJ__LogResult[] Parent rows routed to this sink
---@return string # Formatted section
local function renderSection(scope, action, rows)
  local lines = { string.format("%s: %s | %s", scope, action, formatRollup(rows)) }

  for _, row in ipairs(rows) do
    table.insert(lines, formatRow(row.tag, row.fields, ROW_INDENT))

    for _, detail in ipairs(row.details or {}) do
      table.insert(lines, formatRow(detail.tag, detail.fields, DETAIL_INDENT))
    end
  end

  return table.concat(lines, "\n")
end

---Create a batched log collector
---Buffers rows until emit, which routes FAIL and ERROR rows to the error sink
---and stays silent when a sink has nothing to report.
---@param logTag string Module tag from constants.TAGS used for the info log
---@param scope string Scope label such as "dynamicAirOperations" or "zone=Taoyuan"
---@param action string Action description shared by both sinks
---@return SBJ__LogReport # Collector accepting rows until emit
function LogFormat.report(logTag, scope, action)
  local rows = {}
  local report = {}

  ---Buffer one row plus the detail rows nested under it
  ---@param tag string Status tag with or without square brackets
  ---@param fields table<string, any>|nil Field values keyed by field name
  ---@param details? SBJ__LogResult[] Rows indented under this one, nil when there are none
  function report.add(tag, fields, details)
    table.insert(rows, { tag = tag, fields = fields or {}, details = details })
  end

  ---Buffer every result in order
  ---@param results SBJ__LogResult[]|nil Results to append, nil is ignored
  function report.addAll(results)
    for _, result in ipairs(results or {}) do
      report.add(result.tag, result.fields, result.details)
    end
  end

  ---Emit the buffered rows, splitting them across the info and error sinks
  ---@param actionFields? table<string, any> Batch-level counters appended to the action; use this for totals that are only known after the loop
  function report.emit(actionFields)
    local fullAction = action
    if actionFields then
      fullAction = action .. " " .. LogFormat.fields(actionFields)
    end

    local infoRows, errorRows = {}, {}

    for _, row in ipairs(rows) do
      table.insert(isErrorTag(row.tag) and errorRows or infoRows, row)
    end

    if #infoRows > 0 then
      Logger.log(logTag, renderSection(scope, fullAction, infoRows))
    end

    if #errorRows > 0 then
      Logger.error(renderSection(scope, fullAction, errorRows))
    end
  end

  return report
end

return LogFormat
