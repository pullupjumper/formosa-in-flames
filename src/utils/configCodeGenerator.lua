---Generates Lua source-code strings from ground-force configuration.
---Produces `constants.AREAS`, `constants.OPERATIONAL_AREAS`, and per-system
---`config.{side}.ground.{sys}.{ammunitions,resupplyUnits,firingUnits}` blocks.
---Invoked interactively (console/REPL) to regenerate the hand-pasted constants
---and config sections whenever the scenario layout changes.

local constants = require("src.core.constants")

local ConfigCodeGenerator = {}

-- ============================================================================
-- Pipeline (ConfigCodeGenerator.generate):
--   Phase 1 (collectUniqueAreas)  : scan config -> dedupe operationalArea tables, build opAreaMap
--   Phase 2 (generateAreasCode)   : emit `constants.AREAS = { ... }`, build areaRefMap for Phase 3
--   Phase 3 (generateOpAreasCode) : emit `constants.OPERATIONAL_AREAS = { ... }` via POSITION_EMITTERS
--   Phase 4 (generateConfigCode)  : emit `config.{side}.ground.{sys}.{ammo,resupply,firing}` blocks
-- ============================================================================

local AREA_NAME_PREFIXES = {
  RL = "RELOAD_POINT",
  HA = "HIDE_AREA",
  FP = "FIRE_POINT",
  AHA = "AMMO_HOLDING_AREA",
}
-- Phase 2 only. SHRL is intentionally excluded: it reuses RL's area constant
-- rather than defining its own (see POSITION_EMITTERS for Phase 3 emission).
local POSITION_TYPE_ORDER = { "RL", "HA", "FP", "AHA" }

---Serialize coordinate value (string or number) to Lua code
---@param val string|number Raw coordinate value; strings are quoted verbatim, numbers stringified
---@return string # Lua literal ready for source emission
local function serializeCoord(val)
  return type(val) == "string" and ('"' .. val .. '"') or tostring(val)
end

---Serialize string array on single line
---@param arr string[] Strings to quote and join in output order
---@return string # Inline `{ "a", "b", ... }` Lua literal
local function serializeStringArray(arr)
  local parts = {}
  for _, v in ipairs(arr) do parts[#parts + 1] = '"' .. v .. '"' end
  return "{ " .. table.concat(parts, ", ") .. " }"
end

---Serialize waypoint to inline Lua code
---@param wp CMO__Waypoint Waypoint carrying latitude/longitude fields
---@return string # Inline `{ latitude = ..., longitude = ..., }` literal
local function serializeWaypoint(wp)
  return "{ latitude = " .. serializeCoord(wp.latitude) .. ", longitude = " .. serializeCoord(wp.longitude) .. ", }"
end

---Resolve operational area key name from name field or constants reverse-lookup
---@param opArea SBJ__OperationalArea Operational area table to identify
---@return string|nil # Key name with `#` stripped, or nil when not found in constants
local function resolveOpAreaKey(opArea)
  if opArea.name then
    local str = opArea.name:gsub("#", "")
    return str
  end
  for constKey, constOpArea in pairs(constants.OPERATIONAL_AREAS) do
    if constOpArea == opArea then
      return constKey
    end
  end
  return nil
end

---Recursive Lua value serializer with operationalArea replacement
---@param value any Value to serialize
---@param level integer Indentation level
---@param opAreaMap table<table, string> Maps operationalArea table refs to constant key names
---@return string # Serialized Lua expression with nested tables indented by `level`
local function serializeValue(value, level, opAreaMap)
  local pad = string.rep("  ", level)
  local pad1 = string.rep("  ", level + 1)

  if value == nil then return "nil" end
  if type(value) == "boolean" then return tostring(value) end
  if type(value) == "number" then return tostring(value) end
  if type(value) == "string" then return string.format("%q", value) end
  if type(value) ~= "table" then return tostring(value) end

  local isArray = true
  for k in pairs(value) do
    if type(k) ~= "number" then
      isArray = false; break
    end
  end

  local lines = { "{" }

  if isArray then
    for _, v in ipairs(value) do
      lines[#lines + 1] = pad1 .. serializeValue(v, level + 1, opAreaMap) .. ","
    end
  else
    local keys = {}
    for k in pairs(value) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)

    for _, k in ipairs(keys) do
      local v = value[k]
      local keyStr = type(k) == "string"
          and (k:match("^[%a_][%w_]*$") and k or '["' .. k .. '"]')
          or ("[" .. tostring(k) .. "]")

      if k == "operationalArea" and type(v) == "table" then
        local opKey = opAreaMap[v] or resolveOpAreaKey(v)
        if opKey then
          lines[#lines + 1] = pad1 .. keyStr .. " = constants.OPERATIONAL_AREAS." .. opKey .. ","
        else
          lines[#lines + 1] = pad1 .. keyStr .. " = " .. serializeValue(v, level + 1, opAreaMap) .. ","
        end
      else
        lines[#lines + 1] = pad1 .. keyStr .. " = " .. serializeValue(v, level + 1, opAreaMap) .. ","
      end
    end
  end

  lines[#lines + 1] = pad .. "}"
  return table.concat(lines, "\n")
end

---Serialize wpnCurrent/wpnDefault value as configPath reference when possible
---@param value number Ammunition count value
---@param wpnDefault number System's default weapon count
---@param configPath string Config path prefix
---@return string # Serialized expression string
local function serializeWpnRef(value, wpnDefault, configPath)
  if wpnDefault and wpnDefault > 0 and value > 0 then
    if value == wpnDefault then
      return configPath .. ".wpnDefault"
    end
    local ratio = value / wpnDefault
    if ratio == math.floor(ratio) and ratio > 1 then
      return configPath .. ".wpnDefault * " .. math.floor(ratio)
    end
    if value * 2 == wpnDefault then
      return configPath .. ".wpnDefault / 2"
    end
  end
  return tostring(value)
end

---Build reverse lookup map (value -> key) from a table
---@generic K, V
---@param tbl table<K, V> Source table keyed by K with value V
---@return table<V, K> # Reverse-indexed table keyed by the original values
local function buildReverseMap(tbl)
  local reverse = {}
  for k, v in pairs(tbl) do reverse[v] = k end
  return reverse
end

---Collect unique operational areas from a unit collection into shared accumulators
---@param units table<string, {operationalArea: SBJ__OperationalArea}> Units keyed by name
---@param opAreaMap table<table, string> Maps opArea refs to keys (mutated)
---@param seenKeys table<string, boolean> Already-seen keys (mutated)
---@param uniqueAreas {key: string, opArea: SBJ__OperationalArea}[] Accumulator (mutated)
local function collectOpAreasFromUnits(units, opAreaMap, seenKeys, uniqueAreas)
  for _, unit in pairs(units) do
    local opArea = unit.operationalArea
    if opArea then
      local key = resolveOpAreaKey(opArea)
      if key then
        opAreaMap[opArea] = key
        if not seenKeys[key] then
          seenKeys[key] = true
          uniqueAreas[#uniqueAreas + 1] = { key = key, opArea = opArea }
        end
      end
    end
  end
end

---Phase 1: Collect unique operational areas from all firing/resupply units
---@param groundForceConfig SBJ__GroundForceConfig Ground force config to scan
---@return {key: string, opArea: SBJ__OperationalArea}[] uniqueAreas Sorted by key
---@return table<table, string> opAreaMap Maps opArea refs to constant key names
local function collectUniqueAreas(groundForceConfig)
  local uniqueAreas = {}
  local seenKeys = {}
  local opAreaMap = {}
  for _, sysConfig in pairs(groundForceConfig) do
    if type(sysConfig) == "table" and sysConfig.firingUnits then
      collectOpAreasFromUnits(sysConfig.firingUnits, opAreaMap, seenKeys, uniqueAreas)
      if sysConfig.resupplyUnits then
        collectOpAreasFromUnits(sysConfig.resupplyUnits, opAreaMap, seenKeys, uniqueAreas)
      end
    end
  end
  table.sort(uniqueAreas, function(a, b) return a.key < b.key end)
  return uniqueAreas, opAreaMap
end

---Phase 2: Generate constants.AREAS code block and areaRefMap for Phase 3 lookups
---@param uniqueAreas {key: string, opArea: SBJ__OperationalArea}[] Sorted unique operational areas from Phase 1
---@return string areasStr Generated constants.AREAS = { ... } code
---@return table<string, table<string, string>> areaRefMap Maps [opKey][posType_index] to AREAS const name
local function generateAreasCode(uniqueAreas)
  local areasLines = {}
  local areaRefMap = {}

  for _, entry in ipairs(uniqueAreas) do
    local key, opArea = entry.key, entry.opArea
    areaRefMap[key] = {}

    for _, posType in ipairs(POSITION_TYPE_ORDER) do
      local positions = opArea[posType]
      if positions then
        for i, pos in ipairs(positions) do
          if pos.area then
            local constName = AREA_NAME_PREFIXES[posType] .. "_" .. key
            if posType == "FP" then constName = constName .. "_" .. i end
            areasLines[#areasLines + 1] = "  " .. constName .. " = " .. serializeStringArray(pos.area) .. ","
            areaRefMap[key][posType .. "_" .. i] = constName
          end
        end
      end
    end

    if opArea.mask and opArea.mask.area then
      local constName = "MASK_" .. key
      areasLines[#areasLines + 1] = "  " .. constName .. " = " .. serializeStringArray(opArea.mask.area) .. ","
      areaRefMap[key]["mask"] = constName
    end
  end

  return "constants.AREAS = {\n" .. table.concat(areasLines, "\n") .. "\n}", areaRefMap
end

---Position emitters driving Phase 3 serialization
---Each emitter describes one opArea field and where to find its AREAS const
---SHRL reuses RL's area by design (shelter -> reload loop shares the reload area)
---@class OpAreaPositionEmitter
---@field field string opArea field name (RL/HA/FP/AHA/SHRL)
---@field keyPrefix string areaRefMap subkey; combined with position index as `keyPrefix .. "_" .. i` when indexed
---@field indexed boolean When true, subkey varies per position; when false, keyPrefix is the full subkey
local POSITION_EMITTERS = {
  { field = "RL",   keyPrefix = "RL",   indexed = true },
  { field = "HA",   keyPrefix = "HA",   indexed = true },
  { field = "FP",   keyPrefix = "FP",   indexed = true },
  { field = "AHA",  keyPrefix = "AHA",  indexed = true },
  { field = "SHRL", keyPrefix = "RL_1", indexed = false },
}

---Resolve the AREAS constant reference for the i-th position under emitter
---@param emitter OpAreaPositionEmitter Emitter describing field and subkey lookup
---@param i integer Position index (1-based)
---@param key string Operational-area key (e.g. "ANW")
---@param areaRefMap table<string, table<string, string>> Phase 2's [opKey][posType_index] -> AREAS const-name map
---@return string|nil # "constants.AREAS.<NAME>" or nil when unmapped
local function resolveAreaRef(emitter, i, key, areaRefMap)
  local subKey = emitter.indexed and (emitter.keyPrefix .. "_" .. i) or emitter.keyPrefix
  local constName = areaRefMap[key][subKey]
  return constName and ("constants.AREAS." .. constName) or nil
end

---Emit one position block (single- or multi-position) into opLines
---Skips silently if the first position has no resolvable AREAS reference
---@param opLines string[] Output accumulator (mutated)
---@param emitter OpAreaPositionEmitter Emitter describing field and areaRefMap subkey lookup
---@param positions SBJ__Position[] Position list from opArea[emitter.field]
---@param key string Operational-area key (e.g. "ANW")
---@param areaRefMap table<string, table<string, string>> Phase 2's [opKey][posType_index] -> AREAS const-name map
local function emitPositionBlock(opLines, emitter, positions, key, areaRefMap)
  if not resolveAreaRef(emitter, 1, key, areaRefMap) then return end

  if #positions == 1 then
    local pos = positions[1]
    opLines[#opLines + 1] = "    " .. emitter.field .. " = { {"
    opLines[#opLines + 1] = "      course = {"
    for _, wp in ipairs(pos.course) do
      opLines[#opLines + 1] = "        " .. serializeWaypoint(wp) .. ","
    end
    opLines[#opLines + 1] = "      },"
    opLines[#opLines + 1] = "      area = " .. resolveAreaRef(emitter, 1, key, areaRefMap)
    opLines[#opLines + 1] = "    } },"
  else
    opLines[#opLines + 1] = "    " .. emitter.field .. " = {"
    for i, pos in ipairs(positions) do
      opLines[#opLines + 1] = "      {"
      opLines[#opLines + 1] = "        course = {"
      for _, wp in ipairs(pos.course) do
        opLines[#opLines + 1] = "          " .. serializeWaypoint(wp) .. ","
      end
      opLines[#opLines + 1] = "        },"
      opLines[#opLines + 1] = "        area = " .. resolveAreaRef(emitter, i, key, areaRefMap)
      opLines[#opLines + 1] = "      },"
    end
    opLines[#opLines + 1] = "    },"
  end
end

---Phase 3: Generate constants.OPERATIONAL_AREAS code block
---@param uniqueAreas {key: string, opArea: SBJ__OperationalArea}[] Sorted unique operational areas from Phase 1
---@param areaRefMap table<string, table<string, string>> Phase 2's [opKey][posType_index] -> AREAS const-name map
---@return string # Generated constants.OPERATIONAL_AREAS = { ... } code
local function generateOpAreasCode(uniqueAreas, areaRefMap)
  local opLines = {}

  for _, entry in ipairs(uniqueAreas) do
    local key, opArea = entry.key, entry.opArea
    opLines[#opLines + 1] = "  " .. key .. " = {"

    for _, emitter in ipairs(POSITION_EMITTERS) do
      local positions = opArea[emitter.field]
      if positions then
        emitPositionBlock(opLines, emitter, positions, key, areaRefMap)
      end
    end

    if opArea.mask then
      local maskRef = areaRefMap[key]["mask"]
      if maskRef then
        opLines[#opLines + 1] = "    mask = { area = constants.AREAS." .. maskRef .. " },"
      end
    end

    opLines[#opLines + 1] = "  },"
  end

  return "constants.OPERATIONAL_AREAS = {\n" .. table.concat(opLines, "\n") .. "\n}"
end

---Firing-unit field output order; extras are appended alphabetically
local FIELD_ORDER = {
  "guid", "name", "msg", "state", "operationalArea",
  "weaponDBID", "ammoThreshold", "resupplyUnit", "dbid", "mountDescriptors"
}

---Sort a table's string keys alphabetically (ignores non-string keys)
---@param tbl table Any table whose string keys should be enumerated in order
---@return string[] # Sorted array of string keys found in tbl
local function sortedStringKeys(tbl)
  local keys = {}
  for k in pairs(tbl) do
    if type(k) == "string" then keys[#keys + 1] = k end
  end
  table.sort(keys)
  return keys
end

---Shared context for Phase 4 field serializers
---@class SBJ__FieldSerializerContext
---@field configPath string Current config.{side}.ground.{sys} path
---@field opAreaMap table<table, string> opArea table ref -> constant key
---@field reverseState table<any, string> state value -> constant key
---@field reverseWeapons table<integer, string> weapon DBID -> constant key
---@field reversePlatforms table<integer, string> platform DBID -> constant key

---Per-field serializer signature; return nil to fall through to default
---@alias FieldSerializer fun(value: any, ctx: SBJ__FieldSerializerContext): string|nil

---Serialize a MissileSystemState enum value to its constant reference
---@param value any Field value (expected number)
---@param ctx SBJ__FieldSerializerContext Shared serializer context
---@return string|nil # Constant reference, or nil to fall through to default
local function serializeStateField(value, ctx)
  if type(value) ~= "number" then return nil end
  local key = ctx.reverseState[value]
  return key and ("constants.MISSILE_SYSTEM_STATE." .. key) or tostring(value)
end

---Serialize an operationalArea table to its OPERATIONAL_AREAS reference
---@param value any Field value (expected opArea table)
---@param ctx SBJ__FieldSerializerContext Shared serializer context
---@return string|nil # Constant reference, or nil to fall through to default
local function serializeOperationalAreaField(value, ctx)
  if type(value) ~= "table" then return nil end
  local key = ctx.opAreaMap[value]
  return key and ("constants.OPERATIONAL_AREAS." .. key) or serializeValue(value, 2, ctx.opAreaMap)
end

---Serialize a weapon DBID (scalar or array) to WEAPONS constant reference(s)
---@param value any Field value (expected number or number[])
---@param ctx SBJ__FieldSerializerContext Shared serializer context
---@return string|nil # Constant reference or inline table, or nil to fall through
local function serializeWeaponDBIDField(value, ctx)
  if type(value) == "number" then
    local key = ctx.reverseWeapons[value]
    return key and ("constants.WEAPONS." .. key) or tostring(value)
  end
  if type(value) == "table" then
    local parts = {}
    for _, v in ipairs(value) do
      local key = ctx.reverseWeapons[v]
      parts[#parts + 1] = key and ("constants.WEAPONS." .. key) or tostring(v)
    end
    return "{ " .. table.concat(parts, ", ") .. " }"
  end
  return nil
end

---Serialize ammoThreshold as a configPath reference (value ignored)
---@param _ any Unused; threshold value lives in config, not inlined
---@param ctx SBJ__FieldSerializerContext Shared serializer context
---@return string # `configPath.ammoThreshold` expression
local function serializeAmmoThresholdField(_, ctx)
  return ctx.configPath .. ".ammoThreshold"
end

---Serialize a platform DBID to its PLATFORMS constant reference
---@param value any Field value (expected number)
---@param ctx SBJ__FieldSerializerContext Shared serializer context
---@return string|nil # Constant reference, or nil to fall through to default
local function serializeDbidField(value, ctx)
  if type(value) ~= "number" then return nil end
  local key = ctx.reversePlatforms[value]
  return key and ("constants.PLATFORMS." .. key) or tostring(value)
end

---Serialize mountDescriptors by structural match against MOUNT_DESCRIPTORS constants
---@param value any Field value (expected {dbid:number, mountCount:integer}[])
---@param ctx SBJ__FieldSerializerContext Shared serializer context
---@return string|nil # Constant reference if match found, nested table otherwise, or nil if not a table
local function serializeMountDescriptorsField(value, ctx)
  if type(value) ~= "table" then return nil end
  -- Structural match against each constants.MOUNT_DESCRIPTORS entry by length
  -- and per-entry dbid/mountCount; first match wins. No built-in deep equality
  -- in Lua, so compare manually.
  for k, v in pairs(constants.MOUNT_DESCRIPTORS) do
    if #v == #value then
      local match = true
      for i, entry in ipairs(v) do
        if not value[i] or entry.dbid ~= value[i].dbid or entry.mountCount ~= value[i].mountCount then
          match = false; break
        end
      end
      if match then return "constants.MOUNT_DESCRIPTORS." .. k end
    end
  end
  return serializeValue(value, 2, ctx.opAreaMap)
end

---@type table<string, FieldSerializer>
local FIELD_SERIALIZERS = {
  state            = serializeStateField,
  operationalArea  = serializeOperationalAreaField,
  weaponDBID       = serializeWeaponDBIDField,
  ammoThreshold    = serializeAmmoThresholdField,
  dbid             = serializeDbidField,
  mountDescriptors = serializeMountDescriptorsField,
}

---Fallback serializer used when no field-specific serializer applies
---@param value any Field value of unknown type
---@param ctx SBJ__FieldSerializerContext Shared context (used for nested opAreaMap lookups)
---@return string # Quoted string, primitive tostring, or fully serialized table
local function serializeDefaultValue(value, ctx)
  if type(value) == "string" then return string.format("%q", value) end
  if type(value) == "number" or type(value) == "boolean" then return tostring(value) end
  return serializeValue(value, 2, ctx.opAreaMap)
end

---Resolve a firingUnit field to its serialized Lua expression
---@param field string Field name used to dispatch into FIELD_SERIALIZERS
---@param value any Field value to serialize
---@param ctx SBJ__FieldSerializerContext Shared context forwarded to the chosen serializer
---@return string # Serialized Lua expression for the field value
local function serializeField(field, value, ctx)
  local serializer = FIELD_SERIALIZERS[field]
  local result = serializer and serializer(value, ctx)
  return result or serializeDefaultValue(value, ctx)
end

---Serialize a firingUnit reference (string or string-array), or nil if unsupported type
---@param value string|string[]|any Single unit name, array of unit names, or other
---@return string|nil # Quoted string, inline array, or nil when value type is unsupported
local function serializeFiringUnitRef(value)
  if type(value) == "string" then
    return string.format("%q", value)
  end
  if type(value) == "table" then
    local parts = {}
    for _, v in ipairs(value) do
      parts[#parts + 1] = string.format("%q", v)
    end
    return "{ " .. table.concat(parts, ", ") .. " }"
  end
  return nil
end

---Compute firingUnit field emission order: FIELD_ORDER first, extras alphabetically
---@param unit table FiringUnit descriptor whose fields should be ordered
---@return string[] # Ordered field names for serialization
local function orderFiringUnitFields(unit)
  local ordered, seen = {}, {}
  for _, f in ipairs(FIELD_ORDER) do
    if unit[f] ~= nil then
      ordered[#ordered + 1] = f
      seen[f] = true
    end
  end
  local extras = {}
  for f in pairs(unit) do
    if not seen[f] then extras[#extras + 1] = f end
  end
  table.sort(extras)
  for _, f in ipairs(extras) do ordered[#ordered + 1] = f end
  return ordered
end

---Emit the `config.{...}.ammunitions = { ... }` block, or nil if ammunitions absent
---@param configPath string Config path prefix (e.g. "config.c.ground.mlrs")
---@param ammunitions table<string, SBJ__AmmunitionUnitDescriptor>|nil Ammunition units keyed by unit name
---@param wpnDefault number System's default weapon count for wpnRef simplification
---@return string|nil # Serialized block, or nil when ammunitions is nil
local function emitAmmunitionsBlock(configPath, ammunitions, wpnDefault)
  if not ammunitions then return nil end
  local lines = { configPath .. ".ammunitions = {" }
  for _, name in ipairs(sortedStringKeys(ammunitions)) do
    local ammo = ammunitions[name]
    lines[#lines + 1] = '  ["' .. name .. '"] = {'
    lines[#lines + 1] = "    guid = " .. string.format("%q", ammo.guid) .. ","
    lines[#lines + 1] = "    name = " .. string.format("%q", ammo.name) .. ","
    lines[#lines + 1] = "    wpnCurrent = " .. serializeWpnRef(ammo.wpnCurrent, wpnDefault, configPath) .. ","
    lines[#lines + 1] = "    wpnDefault = " .. serializeWpnRef(ammo.wpnDefault, wpnDefault, configPath) .. ","
    lines[#lines + 1] = "  },"
  end
  lines[#lines + 1] = "}"
  return table.concat(lines, "\n")
end

---Emit the `config.{...}.resupplyUnits = { ... }` block, or nil if resupplyUnits absent
---@param configPath string Config path prefix (e.g. "config.c.ground.mlrs")
---@param resupplyUnits table<string, SBJ__ResupplyUnitDescriptor>|nil Resupply units keyed by unit name
---@param wpnDefault number System's default weapon count for wpnRef simplification
---@param ctx SBJ__FieldSerializerContext Shared context for operationalArea/state serialization
---@return string|nil # Serialized block, or nil when resupplyUnits is nil
local function emitResupplyUnitsBlock(configPath, resupplyUnits, wpnDefault, ctx)
  if not resupplyUnits then return nil end
  local lines = { configPath .. ".resupplyUnits = {" }
  for _, name in ipairs(sortedStringKeys(resupplyUnits)) do
    local unit = resupplyUnits[name]
    lines[#lines + 1] = '  ["' .. name .. '"] = {'
    lines[#lines + 1] = "    guid = " .. string.format("%q", unit.guid) .. ","
    lines[#lines + 1] = "    name = " .. string.format("%q", unit.name) .. ","
    lines[#lines + 1] = "    wpnCurrent = " .. serializeWpnRef(unit.wpnCurrent, wpnDefault, configPath) .. ","
    lines[#lines + 1] = "    wpnDefault = " .. serializeWpnRef(unit.wpnDefault, wpnDefault, configPath) .. ","
    lines[#lines + 1] = "    unitCount = " .. tostring(unit.unitCount) .. ","
    lines[#lines + 1] = "    operationalArea = " .. serializeField("operationalArea", unit.operationalArea, ctx) .. ","
    lines[#lines + 1] = "    state = " .. serializeField("state", unit.state, ctx) .. ","
    lines[#lines + 1] = "    ammunition = " .. string.format("%q", unit.ammunition) .. ","

    local firingUnitRef = serializeFiringUnitRef(unit.firingUnit)
    if firingUnitRef then
      -- Intentionally no trailing comma: firingUnit is the last field emitted and
      -- the original output shape omitted it here. Lua accepts either form.
      lines[#lines + 1] = "    firingUnit = " .. firingUnitRef
    end

    lines[#lines + 1] = "  },"
  end
  lines[#lines + 1] = "}"
  return table.concat(lines, "\n")
end

---Emit the `config.{...}.firingUnits = { ... }` block
---@param configPath string Config path prefix (e.g. "config.c.ground.mlrs")
---@param firingUnits table<string, SBJ__FiringUnitDescriptor> Firing units keyed by unit name
---@param ctx SBJ__FieldSerializerContext Shared context for per-field constant lookup
---@return string # Serialized `config.{...}.firingUnits = { ... }` block
local function emitFiringUnitsBlock(configPath, firingUnits, ctx)
  local lines = { configPath .. ".firingUnits = {" }
  for _, name in ipairs(sortedStringKeys(firingUnits)) do
    local unit = firingUnits[name]
    lines[#lines + 1] = '  ["' .. name .. '"] = {'
    for _, field in ipairs(orderFiringUnitFields(unit)) do
      lines[#lines + 1] = "    " .. field .. " = " .. serializeField(field, unit[field], ctx) .. ","
    end
    lines[#lines + 1] = "  },"
  end
  lines[#lines + 1] = "}"
  return table.concat(lines, "\n")
end

---Phase 4: Generate all `config.{side}.ground.{sys}.{ammunitions,resupplyUnits,firingUnits}` blocks
---@param sideField string Side config field key ("c" / "t" / "u")
---@param groundForceConfig SBJ__GroundForceConfig Source ground-force config to serialize
---@param opAreaMap table<table, string> Phase 1's opArea-ref -> constant-key map for cross-references
---@return string # Concatenated ammunitions/resupplyUnits/firingUnits blocks separated by newlines
local function generateConfigCode(sideField, groundForceConfig, opAreaMap)
  local ctx = {
    configPath = "",
    opAreaMap = opAreaMap,
    reverseState = buildReverseMap(constants.MISSILE_SYSTEM_STATE),
    reverseWeapons = buildReverseMap(constants.WEAPONS),
    reversePlatforms = buildReverseMap(constants.PLATFORMS),
  }

  local blocks = {}
  for _, sysKey in ipairs(sortedStringKeys(groundForceConfig)) do
    local sysConfig = groundForceConfig[sysKey]
    if type(sysConfig) == "table" and sysConfig.firingUnits then
      ctx.configPath = "config." .. sideField .. ".ground." .. sysKey
      local ammoBlock = emitAmmunitionsBlock(ctx.configPath, sysConfig.ammunitions, sysConfig.wpnDefault)
      if ammoBlock then blocks[#blocks + 1] = ammoBlock end
      local resBlock = emitResupplyUnitsBlock(ctx.configPath, sysConfig.resupplyUnits, sysConfig.wpnDefault, ctx)
      if resBlock then blocks[#blocks + 1] = resBlock end
      blocks[#blocks + 1] = emitFiringUnitsBlock(ctx.configPath, sysConfig.firingUnits, ctx)
    end
  end

  return table.concat(blocks, "\n")
end

---Resolve side name to its config field key
---@param sideName string Side name ("China", "Taiwan", "US")
---@return string # Config field key ("c" / "t" / "u")
local function resolveSideField(sideName)
  if sideName == constants.SIDES.ENEMY then
    return "c"
  elseif sideName == "US" then
    return "u"
  else
    return "t"
  end
end

---Generate Lua source-code strings from ground-force configuration
---Produces `constants.AREAS`, `constants.OPERATIONAL_AREAS`, and per-system
---`config.{side}.ground.{sys}.{ammunitions,resupplyUnits,firingUnits}` blocks
---Example: local areasStr, opAreasStr, configStr = ConfigCodeGenerator.generate("China", config.c.ground)
---@param sideName string Side name ("China", "Taiwan")
---@param groundForceConfig SBJ__GroundForceConfig Ground force configuration
---@return string areasStr constants.AREAS code
---@return string opAreasStr constants.OPERATIONAL_AREAS code
---@return string configStr config blocks with constant references
function ConfigCodeGenerator.generate(sideName, groundForceConfig)
  local sideField = resolveSideField(sideName)
  local uniqueAreas, opAreaMap = collectUniqueAreas(groundForceConfig)
  local areasStr, areaRefMap = generateAreasCode(uniqueAreas)
  local opAreasStr = generateOpAreasCode(uniqueAreas, areaRefMap)
  local configStr = generateConfigCode(sideField, groundForceConfig, opAreaMap)
  return areasStr, opAreasStr, configStr
end

return ConfigCodeGenerator
