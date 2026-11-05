---Generates Lua source-code strings from ground-force configuration.
---Produces `constants.AREAS`, `constants.OPERATIONAL_AREAS`, and per-system
---`config.{side}.ground.missileSystemTypes.{sys}.{canisterStocks,resupplyUnits,firingUnits}` blocks.
---Invoked interactively (console/REPL) via `dump` to print marked sections into the CMO Lua log;
---`tools/apply_generated_config.py` then writes them into constants.lua / config.lua.

local constants = require("src.core.constants")
local GameUtils = require("src.utils.gameUtils")
local PersistentState = require("src.core.persistentState")

local ConfigCodeGenerator = {}

-- ============================================================================
-- Pipeline (ConfigCodeGenerator.format):
--   Phase 1 (collectUniqueAreas)  : scan config -> dedupe operationalArea tables, build opAreaMap
--   Phase 2 (formatAreasCode)   : emit `constants.AREAS = { ... }`, build areaRefMap for Phase 3
--   Phase 3 (formatOpAreasCode) : emit `constants.OPERATIONAL_AREAS = { ... }` via POSITION_EMITTERS
--   Phase 4 (formatConfigCode)  : emit `config.{side}.ground.missileSystemTypes.{sys}.{ammo,resupply,firing}` blocks
-- ============================================================================

local AREA_NAME_PREFIXES = {
  RL = "RELOAD_POINT",
  HA = "HIDE_AREA",
  FP = "FIRE_POINT",
  ATP = "AMMUNITION_TRANSFER_POINT",
}
-- Phase 2 only. SHRL is intentionally excluded: it reuses RL's area constant
-- rather than defining its own (see POSITION_EMITTERS for Phase 3 emission).
local POSITION_TYPE_ORDER = { "RL", "HA", "FP", "ATP" }

---Serialize coordinate value (string or number) to Lua code
---@param val string|number
---@return string # Lua literal ready for source emission
local function formatCoord(val)
  return type(val) == "string" and ('"' .. val .. '"') or tostring(val)
end

---Serialize string array on single line
---@param arr string[]
---@return string # Inline `{ "a", "b", ... }` Lua literal
local function formatStringArray(arr)
  local parts = {}
  for _, v in ipairs(arr) do parts[#parts + 1] = '"' .. v .. '"' end
  return "{ " .. table.concat(parts, ", ") .. " }"
end

---Serialize waypoint to inline Lua code
---@param wp CMO__Waypoint
---@return string # Inline `{ latitude = ..., longitude = ..., }` literal
local function formatWaypoint(wp)
  return "{ latitude = " .. formatCoord(wp.latitude) .. ", longitude = " .. formatCoord(wp.longitude) .. ", }"
end

---Resolve operational area key name from name field or constants reverse-lookup
---@param opArea SBJ__OperationalArea
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
---@param value any
---@param level integer
---@param opAreaMap table<table, string>
---@return string # Serialized Lua expression with nested tables indented by `level`
local function formatValue(value, level, opAreaMap)
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
      lines[#lines + 1] = pad1 .. formatValue(v, level + 1, opAreaMap) .. ","
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
          lines[#lines + 1] = pad1 .. keyStr .. " = " .. formatValue(v, level + 1, opAreaMap) .. ","
        end
      else
        lines[#lines + 1] = pad1 .. keyStr .. " = " .. formatValue(v, level + 1, opAreaMap) .. ","
      end
    end
  end

  lines[#lines + 1] = pad .. "}"
  return table.concat(lines, "\n")
end

---Serialize weaponCountCurrent/weaponCountDefault value as configPath reference when possible
---@param value number
---@param weaponCountDefault number System's default weapon count
---@param configPath string
---@return string # Serialized expression string
local function formatWeaponCountRef(value, weaponCountDefault, configPath)
  if weaponCountDefault and weaponCountDefault > 0 and value > 0 then
    if value == weaponCountDefault then
      return configPath .. ".weaponCountDefault"
    end
    local ratio = value / weaponCountDefault
    if ratio == math.floor(ratio) and ratio > 1 then
      return configPath .. ".weaponCountDefault * " .. math.floor(ratio)
    end
    if value * 2 == weaponCountDefault then
      return configPath .. ".weaponCountDefault / 2"
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
---@param unitMap table<string, {operationalArea: SBJ__OperationalArea}>
---@param opAreaMap table<table, string>
---@param seenKeySet table<string, boolean>
---@param uniqueAreas {key: string, opArea: SBJ__OperationalArea}[]
local function collectOpAreasFromUnits(unitMap, opAreaMap, seenKeySet, uniqueAreas)
  for _, unit in pairs(unitMap) do
    local opArea = unit.operationalArea
    if opArea then
      local key = resolveOpAreaKey(opArea)
      if key then
        opAreaMap[opArea] = key
        if not seenKeySet[key] then
          seenKeySet[key] = true
          uniqueAreas[#uniqueAreas + 1] = { key = key, opArea = opArea }
        end
      end
    end
  end
end

---Phase 1: Collect unique operational areas from all firing/resupply units
---@param missileSystemConfigMap table<string, SBJ__MissileSystemConfig>
---@return {key: string, opArea: SBJ__OperationalArea}[] uniqueAreas Sorted by key
---@return table<table, string> opAreaMap Maps opArea refs to constant key names
local function collectUniqueAreas(missileSystemConfigMap)
  local uniqueAreas = {}
  local seenKeySet = {}
  local opAreaMap = {}
  for _, sysConfig in pairs(missileSystemConfigMap) do
    if type(sysConfig) == "table" and sysConfig.firingUnits then
      collectOpAreasFromUnits(sysConfig.firingUnits, opAreaMap, seenKeySet, uniqueAreas)
      if sysConfig.resupplyUnits then
        collectOpAreasFromUnits(sysConfig.resupplyUnits, opAreaMap, seenKeySet, uniqueAreas)
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
local function formatAreasCode(uniqueAreas)
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
            areasLines[#areasLines + 1] = "  " .. constName .. " = " .. formatStringArray(pos.area) .. ","
            areaRefMap[key][posType .. "_" .. i] = constName
          end
        end
      end
    end

    if opArea.mask and opArea.mask.area then
      local constName = "MASK_" .. key
      areasLines[#areasLines + 1] = "  " .. constName .. " = " .. formatStringArray(opArea.mask.area) .. ","
      areaRefMap[key]["mask"] = constName
    end
  end

  return "constants.AREAS = {\n" .. table.concat(areasLines, "\n") .. "\n}", areaRefMap
end

---Position emitters driving Phase 3 serialization
---Each emitter describes one opArea field and where to find its AREAS const
---SHRL reuses RL's area by design (shelter -> reload loop shares the reload area)
local POSITION_EMITTERS = {
  { field = "RL",   keyPrefix = "RL",   indexed = true },
  { field = "HA",   keyPrefix = "HA",   indexed = true },
  { field = "FP",   keyPrefix = "FP",   indexed = true },
  { field = "ATP",  keyPrefix = "ATP",  indexed = true },
  { field = "SHRL", keyPrefix = "RL_1", indexed = false },
}

---Resolve the AREAS constant reference for the i-th position under emitter
---@param emitter SBJ__OpAreaPositionEmitter
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
---@param opLines string[]
---@param emitter SBJ__OpAreaPositionEmitter
---@param positions SBJ__Position[]
---@param params SBJ__PositionBlockParams
local function formatPositionBlock(opLines, emitter, positions, params)
  local key, areaRefMap = params.key, params.map
  if not resolveAreaRef(emitter, 1, key, areaRefMap) then return end

  if #positions == 1 then
    local pos = positions[1]
    opLines[#opLines + 1] = "    " .. emitter.field .. " = { {"
    opLines[#opLines + 1] = "      course = {"
    for _, wp in ipairs(pos.course) do
      opLines[#opLines + 1] = "        " .. formatWaypoint(wp) .. ","
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
        opLines[#opLines + 1] = "          " .. formatWaypoint(wp) .. ","
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
local function formatOpAreasCode(uniqueAreas, areaRefMap)
  local opLines = {}

  for _, entry in ipairs(uniqueAreas) do
    local key, opArea = entry.key, entry.opArea
    opLines[#opLines + 1] = "  " .. key .. " = {"
    opLines[#opLines + 1] = "    name = \"#" .. key .. "\","

    for _, emitter in ipairs(POSITION_EMITTERS) do
      local positions = opArea[emitter.field]
      if positions then
        formatPositionBlock(opLines, emitter, positions, { key = key, map = areaRefMap })
      end
    end

    if opArea.mask then
      local maskRef = areaRefMap[key]["mask"]
      if maskRef then
        opLines[#opLines + 1] = "    mask = { area = constants.AREAS." .. maskRef .. " },"
      end
    end

    if opArea.shelterPoints and #opArea.shelterPoints > 0 then
      opLines[#opLines + 1] = "    shelterPoints = {"

      for _, point in ipairs(opArea.shelterPoints) do
        opLines[#opLines + 1] = " { latitude = " ..
            tostring(point.latitude) .. ", longitude = " .. tostring(point.longitude) .. " },"
      end
      opLines[#opLines + 1] = " },"
    end

    opLines[#opLines + 1] = "  },"
  end

  return "constants.OPERATIONAL_AREAS = {\n" .. table.concat(opLines, "\n") .. "\n}"
end

---Firing-unit field output order; extras are appended alphabetically
local FIELD_ORDER = {
  "name", "msg", "state", "operationalArea",
  "weaponDBID", "ammoThreshold", "resupplyUnit", "dbid", "missileSystem", "mountDescriptors"
}

---Runtime-only fields that live in saveData states and never belong in generated config
local RUNTIME_FIELDS = { guid = true }

---Sort a table's string keys alphabetically (ignores non-string keys)
---@param tbl table Any table whose string keys should be enumerated in order
---@return string[] # Sorted array of string keys found in tbl
local function getSortedStringKeys(tbl)
  local keys = {}
  for k in pairs(tbl) do
    if type(k) == "string" then keys[#keys + 1] = k end
  end
  table.sort(keys)
  return keys
end

---Serialize a MissileSystemState enum value to its constant reference
---@param value any
---@param ctx SBJ__FieldSerializerContext
---@return string|nil # Constant reference, or nil to fall through to default
local function formatStateField(value, ctx)
  if type(value) ~= "number" then return nil end
  local key = ctx.reverseState[value]
  return key and ("constants.MISSILE_SYSTEM_STATE." .. key) or tostring(value)
end

---Serialize an operationalArea table to its OPERATIONAL_AREAS reference
---@param value any
---@param ctx SBJ__FieldSerializerContext
---@return string|nil # Constant reference, or nil to fall through to default
local function formatOperationalAreaField(value, ctx)
  if type(value) ~= "table" then return nil end
  local key = ctx.opAreaMap[value]
  return key and ("constants.OPERATIONAL_AREAS." .. key) or formatValue(value, 2, ctx.opAreaMap)
end

---Serialize a weapon DBID (scalar or array) to WEAPONS constant reference(s)
---@param value any
---@param ctx SBJ__FieldSerializerContext
---@return string|nil # Constant reference or inline table, or nil to fall through
local function formatWeaponDBIDField(value, ctx)
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
---@param ctx SBJ__FieldSerializerContext
---@return string # `configPath.ammoThreshold` expression
local function formatAmmoThresholdField(_, ctx)
  return ctx.configPath .. ".ammoThreshold"
end

---Serialize a platform DBID to its PLATFORMS constant reference
---@param value any
---@param ctx SBJ__FieldSerializerContext
---@return string|nil # Constant reference, or nil to fall through to default
local function formatDbidField(value, ctx)
  if type(value) ~= "number" then return nil end
  local key = ctx.reversePlatforms[value]
  return key and ("constants.PLATFORMS." .. key) or tostring(value)
end

---Serialize mountDescriptors by structural match against MOUNT_DESCRIPTORS constants
---@param value any
---@param ctx SBJ__FieldSerializerContext
---@return string|nil # Constant reference if match found, nested table otherwise, or nil if not a table
local function formatMountDescriptorsField(value, ctx)
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
  return formatValue(value, 2, ctx.opAreaMap)
end

---@type table<string, SBJ__FieldSerializer>
local FIELD_SERIALIZERS = {
  state            = formatStateField,
  operationalArea  = formatOperationalAreaField,
  weaponDBID       = formatWeaponDBIDField,
  ammoThreshold    = formatAmmoThresholdField,
  dbid             = formatDbidField,
  mountDescriptors = formatMountDescriptorsField,
}

---Fallback serializer used when no field-specific serializer applies
---@param value any
---@param ctx SBJ__FieldSerializerContext
---@return string # Quoted string, primitive tostring, or fully serialized table
local function formatDefaultValue(value, ctx)
  if type(value) == "string" then return string.format("%q", value) end
  if type(value) == "number" or type(value) == "boolean" then return tostring(value) end
  return formatValue(value, 2, ctx.opAreaMap)
end

---Resolve a firingUnit field to its serialized Lua expression
---@param field string
---@param value any
---@param ctx SBJ__FieldSerializerContext
---@return string # Serialized Lua expression for the field value
local function formatField(field, value, ctx)
  local serializer = FIELD_SERIALIZERS[field]
  local result = serializer and serializer(value, ctx)
  return result or formatDefaultValue(value, ctx)
end

---Serialize a firingUnit reference, or nil when it is not a unit name
---@param value string|any Firing unit name, or other
---@return string|nil # Quoted string, or nil when value is not a string
local function formatFiringUnitRef(value)
  if type(value) == "string" then
    return string.format("%q", value)
  end
  return nil
end

---Compute firingUnit field emission order: FIELD_ORDER first, extras alphabetically
---@param unit SBJ__FiringUnitDescriptor FiringUnit descriptor whose fields should be ordered
---@return string[] # Ordered field names for serialization
local function getOrderedFiringUnitFields(unit)
  local ordered, seen = {}, {}
  for _, f in ipairs(FIELD_ORDER) do
    if unit[f] ~= nil then
      ordered[#ordered + 1] = f
      seen[f] = true
    end
  end
  local extras = {}
  for f in pairs(unit) do
    if not seen[f] and not RUNTIME_FIELDS[f] then extras[#extras + 1] = f end
  end
  table.sort(extras)
  for _, f in ipairs(extras) do ordered[#ordered + 1] = f end
  return ordered
end

---Emit the `config.{...}.canisterStocks = { ... }` block, or nil if canisterStockMap absent
---@param configPath string Config path prefix (e.g. "config.red.ground.missileSystemTypes.mlrs")
---@param canisterStockMap table<string, SBJ__CanisterStockDescriptor>|nil
---@param weaponCountDefault number System's default weapon count for weaponCountRef simplification
---@return string|nil # Serialized block, or nil when canisterStockMap is nil
local function formatCanisterStocksBlock(configPath, canisterStockMap, weaponCountDefault)
  if not canisterStockMap then return nil end
  local lines = { configPath .. ".canisterStocks = {" }
  for _, name in ipairs(getSortedStringKeys(canisterStockMap)) do
    local ammo = canisterStockMap[name]
    lines[#lines + 1] = '  ["' .. name .. '"] = {'
    lines[#lines + 1] = "    name = " .. string.format("%q", ammo.name) .. ","
    lines[#lines + 1] = "    weaponCountCurrent = " ..
    formatWeaponCountRef(ammo.weaponCountCurrent, weaponCountDefault, configPath) .. ","
    lines[#lines + 1] = "    weaponCountDefault = " ..
    formatWeaponCountRef(ammo.weaponCountDefault, weaponCountDefault, configPath) .. ","
    lines[#lines + 1] = "  },"
  end
  lines[#lines + 1] = "}"
  return table.concat(lines, "\n")
end

---Emit the `config.{...}.resupplyUnits = { ... }` block, or nil if resupplyUnits absent
---@param configPath string Config path prefix (e.g. "config.red.ground.missileSystemTypes.mlrs")
---@param resupplyUnitMap table<string, SBJ__ResupplyUnitDescriptor>|nil
---@param weaponCountDefault number System's default weapon count for weaponCountRef simplification
---@param ctx SBJ__FieldSerializerContext
---@return string|nil # Serialized block, or nil when resupplyUnitMap is nil
local function formatResupplyUnitsBlock(configPath, resupplyUnitMap, weaponCountDefault, ctx)
  if not resupplyUnitMap then return nil end
  local lines = { configPath .. ".resupplyUnits = {" }
  for _, name in ipairs(getSortedStringKeys(resupplyUnitMap)) do
    local unit = resupplyUnitMap[name]
    lines[#lines + 1] = '  ["' .. name .. '"] = {'
    lines[#lines + 1] = "    name = " .. string.format("%q", unit.name) .. ","
    lines[#lines + 1] = "    weaponCountCurrent = " ..
    formatWeaponCountRef(unit.weaponCountCurrent, weaponCountDefault, configPath) .. ","
    lines[#lines + 1] = "    weaponCountDefault = " ..
    formatWeaponCountRef(unit.weaponCountDefault, weaponCountDefault, configPath) .. ","
    lines[#lines + 1] = "    unitCount = " .. tostring(unit.unitCount) .. ","
    lines[#lines + 1] = "    operationalArea = " .. formatField("operationalArea", unit.operationalArea, ctx) .. ","
    lines[#lines + 1] = "    state = " .. formatField("state", unit.state, ctx) .. ","
    lines[#lines + 1] = "    canisterStock = " .. string.format("%q", unit.canisterStock) .. ","

    local firingUnitRef = formatFiringUnitRef(unit.firingUnit)
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
---@param configPath string Config path prefix (e.g. "config.red.ground.missileSystemTypes.mlrs")
---@param firingUnitMap table<string, SBJ__FiringUnitDescriptor>
---@param ctx SBJ__FieldSerializerContext
---@return string # Serialized `config.{...}.firingUnits = { ... }` block
local function formatFiringUnitsBlock(configPath, firingUnitMap, ctx)
  local lines = { configPath .. ".firingUnits = {" }
  for _, name in ipairs(getSortedStringKeys(firingUnitMap)) do
    local unit = firingUnitMap[name]
    lines[#lines + 1] = '  ["' .. name .. '"] = {'
    for _, field in ipairs(getOrderedFiringUnitFields(unit)) do
      lines[#lines + 1] = "    " .. field .. " = " .. formatField(field, unit[field], ctx) .. ","
    end
    lines[#lines + 1] = "  },"
  end
  lines[#lines + 1] = "}"
  return table.concat(lines, "\n")
end

---Phase 4: Generate all `config.{side}.ground.missileSystemTypes.{sys}.{canisterStocks,resupplyUnits,firingUnits}` blocks
---@param sideField SBJ__SideKey
---@param missileSystemConfigMap table<string, SBJ__MissileSystemConfig>
---@param opAreaMap table<table, string> Phase 1's opArea-ref -> constant-key map for cross-references
---@return string # Concatenated canisterStocks/resupplyUnits/firingUnits blocks separated by newlines
local function formatConfigCode(sideField, missileSystemConfigMap, opAreaMap)
  local ctx = {
    configPath = "",
    opAreaMap = opAreaMap,
    reverseState = buildReverseMap(constants.MISSILE_SYSTEM_STATE),
    reverseWeapons = buildReverseMap(constants.WEAPONS),
    reversePlatforms = buildReverseMap(constants.PLATFORMS),
  }

  local blocks = {}
  for _, sysKey in ipairs(getSortedStringKeys(missileSystemConfigMap)) do
    local sysConfig = missileSystemConfigMap[sysKey]
    if type(sysConfig) == "table" and sysConfig.firingUnits then
      ctx.configPath = "config." .. sideField .. ".ground.missileSystemTypes." .. sysKey
      local ammoBlock = formatCanisterStocksBlock(ctx.configPath, sysConfig.canisterStocks, sysConfig.weaponCountDefault)
      if ammoBlock then blocks[#blocks + 1] = ammoBlock end
      local resBlock = formatResupplyUnitsBlock(ctx.configPath, sysConfig.resupplyUnits, sysConfig.weaponCountDefault,
        ctx)
      if resBlock then blocks[#blocks + 1] = resBlock end
      blocks[#blocks + 1] = formatFiringUnitsBlock(ctx.configPath, sysConfig.firingUnits, ctx)
    end
  end

  return table.concat(blocks, "\n")
end

---Generate Lua source-code strings from ground-force configuration
---Produces `constants.AREAS`, `constants.OPERATIONAL_AREAS`, and per-system
---`config.{side}.ground.missileSystemTypes.{sys}.{canisterStocks,resupplyUnits,firingUnits}` blocks
---Example: local areasStr, opAreasStr, configStr = ConfigCodeGenerator.format("China", config.red.ground.missileSystemTypes)
---@param sideName string
---@param missileSystemConfigMap table<string, SBJ__MissileSystemConfig>
---@return string areasStr constants.AREAS code
---@return string opAreasStr constants.OPERATIONAL_AREAS code
---@return string configStr config blocks with constant references
function ConfigCodeGenerator.format(sideName, missileSystemConfigMap)
  local sideField = GameUtils.getCachedSideConfig(sideName).field
  local uniqueAreas, opAreaMap = collectUniqueAreas(missileSystemConfigMap)
  local areasStr, areaRefMap = formatAreasCode(uniqueAreas)
  local opAreasStr = formatOpAreasCode(uniqueAreas, areaRefMap)
  local configStr = formatConfigCode(sideField, missileSystemConfigMap, opAreaMap)
  return areasStr, opAreasStr, configStr
end

---Marker tags matching `-- START: <tag>_AREAS_BLOCK` in constants.lua, keyed by side config field
local SIDE_BLOCK_TAGS = { red = "CHINA", blue = "TAIWAN" }

---Drop the `constants.X = {` first line and `}` last line, keeping only the table body
---@param code string Generated `constants.X = { ... }` block
---@return string # Body lines only (may be empty)
local function stripTableWrapper(code)
  return (code:gsub("^[^\n]*\n", ""):gsub("\n?}$", ""))
end

---Print one marked section so tools/apply_generated_config.py can lift it out of the CMO Lua log
---@param name string Section name (matches `-- START: <name>` marker, or `CONFIG_<field>`)
---@param body string
local function printSection(name, body)
  print("@@GEN_BEGIN " .. name .. "\n" .. body .. "\n@@GEN_END " .. name)
end

---Copy a table's top-level fields, then set the given fields
---@param source table
---@param fields table
---@return table
local function buildCopyWith(source, fields)
  local copy = {}
  for field, value in pairs(source) do
    copy[field] = value
  end
  for field, value in pairs(fields) do
    copy[field] = value
  end
  return copy
end

---Build config copies with each battery at the operational area its ground state holds
---Deploying from the control panel writes the new area into ground state only, never into config.
---Only a control panel area has a name (buildLayout's "#XYZ"). A state area without one is a copy of
---the config area, which resolveOpAreaKey can only match by identity, so the config table is kept.
---@param missileSystemConfigMap table<string, SBJ__MissileSystemConfig>
---@param groundState SBJ__GroundState
---@return table<string, SBJ__MissileSystemConfig>
local function buildPlacedConfigMap(missileSystemConfigMap, groundState)
  local placedConfigMap = {}

  for missileSystemType, systemConfig in pairs(missileSystemConfigMap) do
    local systemState = groundState.missileSystemTypes and groundState.missileSystemTypes[missileSystemType]
    local placed = buildCopyWith(systemConfig, { firingUnits = {}, resupplyUnits = {} })

    for name, firing in pairs(systemConfig.firingUnits) do
      local firingUnitState = systemState and systemState.firingUnits[name]
      local stateArea = firingUnitState and firingUnitState.operationalArea
      local area = { operationalArea = stateArea and stateArea.name and stateArea or firing.operationalArea }
      local resupply = systemConfig.resupplyUnits[firing.resupplyUnit]
      placed.firingUnits[name] = buildCopyWith(firing, area)
      placed.resupplyUnits[resupply.name] = buildCopyWith(resupply, area)
    end

    placedConfigMap[missileSystemType] = placed
  end

  return placedConfigMap
end

---Print the generated code into the CMO Lua log, wrapped in markers
---Each battery is printed where the saved ground state places it; with no saved state, config is printed as is.
---Run `python tools/apply_generated_config.py` afterwards to write it into constants.lua / config.lua
---Example: ConfigCodeGenerator.dump("China", config.red.ground.missileSystemTypes)
---@param sideName string
---@param missileSystemConfigMap table<string, SBJ__MissileSystemConfig>
function ConfigCodeGenerator.dump(sideName, missileSystemConfigMap)
  local field = GameUtils.getCachedSideConfig(sideName).field
  local tag = SIDE_BLOCK_TAGS[field]
  assert(tag, "ConfigCodeGenerator.dump: no constants.lua block for side " .. sideName)
  local placedConfigMap = missileSystemConfigMap
  PersistentState.read(function(state)
    placedConfigMap = buildPlacedConfigMap(missileSystemConfigMap, PersistentState.ground(state, sideName))
  end)
  local areasStr, opAreasStr, configStr = ConfigCodeGenerator.format(sideName, placedConfigMap)
  printSection(tag .. "_AREAS_BLOCK", stripTableWrapper(areasStr))
  printSection(tag .. "_OPERATIONAL_AREAS_BLOCK", stripTableWrapper(opAreasStr))
  printSection("CONFIG_" .. field, configStr)
end

return ConfigCodeGenerator
