--[[
  gKH State library functions
  Filename: gKHApi\State.lua | gKH_State_Standalone.lua
  Namespace: gKH.State
  Requirement (to use all functions): no dependecies including gKH.base atm
  Lastmodified: I forget...early 2022 b1147.4x added param tagging for vscode
--]]


---- Setup ----
print('gKH.State library loading...');

--Does overall gKH library exist? If not set up dummy one, if so do not overwrite it.
if gKH == nil then
  gKH = {};
else
  print('gKH library namespace already exists.');
end

--Does State library already exist? If yes delete it force a flush of it.
if gKH.State ~= nil then --wipe existing copy if it exists.
  print('gKH.State library existed, removing old copy.');
  gKH.State = nil;
  gKH.json = nil;
  collectgarbage("collect");
end
gKH.State = {};
gKH.State.Version = 1.00001;
---- End Setup ----

--------------------------------------------------------------------------------------------------------------------------------
-- JSON Library - Credit: https://gist.github.com/tylerneylon/59f4bcf316be525b30ab
--              - Only changes were the function names to fit the namespace
--              -   note to self: namespace change may slow it down slightly > ~100k of data.
--              -   need to go back and benchmark throwing helper funcs inside each main fuc so refs are "local"
--              -   or meta table tweaks on gKH.json such that it never looks higher.
--              -   but the truth is I doubt it's going to make huge difference for cmo use cases.
--------------------------------------------------------------------------------------------------------------------------------

-- internal namespace used for all these functions. be careful fking with it, the whole point of the outer State namespace
-- is wrap usage of this and avoid calling the .json functions directly, though you can obviously if you want.
gKH.json = {};

-- Internal functions. --
function gKH.json.kind_of(obj)
  if type(obj) ~= 'table' then return type(obj) end
  local i = 1
  for _ in pairs(obj) do
    if obj[i] ~= nil then i = i + 1 else return 'table' end
  end
  if i == 1 then return 'table' else return 'array' end
end

function gKH.json.escape_str(s)
  local in_char  = { '\\', '"', '/', '\b', '\f', '\n', '\r', '\t' }
  local out_char = { '\\', '"', '/', 'b', 'f', 'n', 'r', 't' }
  for i, c in ipairs(in_char) do
    s = s:gsub(c, '\\' .. out_char[i])
  end
  return s
end

function gKH.json.skip_delim(str, pos, delim, err_if_missing)
  pos = pos + #str:match('^%s*', pos)
  if str:sub(pos, pos) ~= delim then
    if err_if_missing then
      error('Expected ' .. delim .. ' near position ' .. pos)
    end
    return pos, false
  end
  return pos + 1, true
end

function gKH.json.parse_str_val(str, pos, val)
  val = val or ''
  local early_end_error = 'End of input found while parsing string.'
  if pos > #str then error(early_end_error) end
  local c = str:sub(pos, pos)
  if c == '"' then return val, pos + 1 end
  if c ~= '\\' then return gKH.json.parse_str_val(str, pos + 1, val .. c) end
  -- We must have a \ character.
  local esc_map = { b = '\b', f = '\f', n = '\n', r = '\r', t = '\t' }
  local nextc = str:sub(pos + 1, pos + 1)
  if not nextc then error(early_end_error) end
  return gKH.json.parse_str_val(str, pos + 2, val .. (esc_map[nextc] or nextc))
end

function gKH.json.parse_num_val(str, pos)
  local num_str = str:match('^-?%d+%.?%d*[eE]?[+-]?%d*', pos)
  local val = tonumber(num_str)
  if not val then error('Error parsing number at position ' .. pos .. '.') end
  return val, pos + #num_str
end

function gKH.json.stringify(obj, as_key)
  local s = {}                       -- We'll build the string as an array of strings to be concatenated.
  local kind = gKH.json.kind_of(obj) -- This is 'array' if it's an array or type(obj) otherwise.
  if kind == 'array' then
    if as_key then error('Can\'t encode array as key.') end
    s[#s + 1] = '['
    for i, val in ipairs(obj) do
      if i > 1 then s[#s + 1] = ', ' end
      s[#s + 1] = gKH.json.stringify(val)
    end
    s[#s + 1] = ']'
  elseif kind == 'table' then
    if as_key then error('Can\'t encode table as key.') end
    s[#s + 1] = '{'
    for k, v in pairs(obj) do
      if #s > 1 then s[#s + 1] = ', ' end
      s[#s + 1] = gKH.json.stringify(k, true)
      s[#s + 1] = ':'
      s[#s + 1] = gKH.json.stringify(v)
    end
    s[#s + 1] = '}'
  elseif kind == 'string' then
    return '"' .. gKH.json.escape_str(obj) .. '"'
  elseif kind == 'number' then
    if as_key then return '"' .. tostring(obj) .. '"' end
    return tostring(obj)
  elseif kind == 'boolean' then
    return tostring(obj)
  elseif kind == 'nil' then
    return 'null'
  else
    error('Unjsonifiable type: ' .. kind .. '.')
  end
  return table.concat(s)
end

gKH.json.null = {} -- This is a one-off table to represent the null value.

function gKH.json.parse(str, pos, end_delim)
  pos = pos or 1
  if pos > #str then error('Reached unexpected end of input.') end
  local pos = pos + #str:match('^%s*', pos) -- Skip whitespace.
  local first = str:sub(pos, pos)
  if first == '{' then                      -- Parse an object.
    local obj, key, delim_found = {}, true, true
    pos = pos + 1
    while true do
      key, pos = gKH.json.parse(str, pos, '}')
      if key == nil then return obj, pos end
      if not delim_found then error('Comma missing between object items.') end
      pos = gKH.json.skip_delim(str, pos, ':', true) -- true -> error if missing.
      obj[key], pos = gKH.json.parse(str, pos)
      pos, delim_found = gKH.json.skip_delim(str, pos, ',')
    end
  elseif first == '[' then -- Parse an array.
    local arr, val, delim_found = {}, true, true
    pos = pos + 1
    while true do
      val, pos = gKH.json.parse(str, pos, ']')
      if val == nil then return arr, pos end
      if not delim_found then error('Comma missing between array items.') end
      arr[#arr + 1] = val
      pos, delim_found = gKH.json.skip_delim(str, pos, ',')
    end
  elseif first == '"' then                      -- Parse a string.
    return gKH.json.parse_str_val(str, pos + 1)
  elseif first == '-' or first:match('%d') then -- Parse a number.
    return gKH.json.parse_num_val(str, pos)
  elseif first == end_delim then                -- End of an object or array.
    return nil, pos + 1
  else                                          -- Parse true, false, or null.
    local literals = { ['true'] = true, ['false'] = false, ['null'] = gKH.json.null }
    for lit_str, lit_val in pairs(literals) do
      local lit_end = pos + #lit_str - 1
      if str:sub(pos, lit_end) == lit_str then return lit_val, lit_end + 1 end
    end
    local pos_info_str = 'position ' .. pos .. ': ' .. str:sub(pos, pos + 10)
    error('Invalid json syntax starting at ' .. pos_info_str)
  end
end

-----------  end internal json related functions ------------



--- Wrapper function for saving table\array data to CMO string keys.
--- @param theTbl table @ - required the lua table to serialize\convert to an encoded string.
--- @param theKey string @ - required string of the keyname to save the table to.
--- @param nolog? boolean @ - optional boolean if true indicates no logging should be done, defaults to false.
--- @return boolean @ true on successful save, false if something went wrong.
--- Note: While this should not be abused (it's not meant to store huge amounts of data), but it's what we have.
---  That said I've stored a dozen or so MB's worth of data across a couple different keys without issue.
---  If you're thinking we should maybe compress this data before saving let me just say I've been down that road
---  and it's pointless, talk to me directly for details but the tldr of it is the default LZ4
---  compression that late stage CMANO and CMO does for the whole scene xml makes it pointless to
---  try to do inside lua before-hand (say with a lua implementation of lib-deflate)99% of the time,
---  and the other 1% of time the savings aren't much without extremely specific types of ordered repeating data.
---  and tweaks to libdeflate to match that sort of specific data.
function gKH.State.SaveTableToKey(theTbl, theKey, nolog)
  local fn = "gKH.State.SaveTableToKey(): ";
  local retval = false;
  if nolog == nil then nolog = false; end
  if (theTbl ~= nil) and (theKey ~= nil and string.len(theKey) > 0) then
    retval = pcall(ScenEdit_SetKeyValue, theKey, gKH.json.stringify(theTbl));
    if retval == true then
      return true;
    elseif nolog == false then
      print(fn .. "Call to ScenEdit_SetKeyValue failed! key:" .. tostring(theKey));
    end
  else
    print(fn .. "Missing params theTbl or theKey value! call aborted.");
  end
  return false;
end

--- Wrapper function for loading a savedkey that contains a string-ified table.
--- @param theKey string @ As a string key to grab and de-stringify.
--- @param nolog? boolean @ Optional nolog param tells the function not to log most errors.
--- @return table|nil @nil or a table repopulated with data.
function gKH.State.LoadTableFromKey(theKey, nolog)
  local fn = "gKH.State.LoadTableFromKey(): "
  if nolog == nil then nolog = false; end
  if ((theKey ~= nil) and string.len(theKey) > 0) then
    local retval, theKeyData;
    retval, theKeyData = pcall(ScenEdit_GetKeyValue, theKey);

    if (retval ~= nil and theKeyData ~= nil) and retval == true and string.len(theKeyData) > 2 then
      local rettbl = gKH.json.parse(theKeyData);
      if rettbl ~= nil then
        return rettbl;
      elseif nolog == false then
        print(fn .. "Call to destringify the key failed to return data!");
      end
    elseif (retval ~= nil and theKeyData ~= nil) and retval == true and string.len(theKeyData) < 2 and nolog == false then
      print(fn .. "Call to ScenEdit_GetKeyValue " .. theKey .. " returned empty suggesting it has not yet been created.");
    elseif nolog == false then
      print(fn .. "Call to ScenEdit_GetKeyValue failed. Did you pass the right key? " .. theKey);
    end
  else
    print(fn .. "Missing param, missing Key to load from.");
  end
  return nil;
end

print('gKH.State library successfully loaded.');
