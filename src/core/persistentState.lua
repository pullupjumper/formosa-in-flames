local gKH = require("src.core.gKH_State_Standalone")
local Logger = require("src.utils.logger")

---Sole owner of the SaveData key: every load is paired with its save here,
---so event scripts cannot forget to persist what they mutated.
local PersistentState = {}

local SAVE_KEY = "SaveData"

---@return SBJ__SaveData|nil
local function load()
  local state = gKH.State.LoadTableFromKey(SAVE_KEY)
  if state == nil then
    Logger.error("saveData is nil")
  end
  return state
end

---Load state, run fn against it, then save it back
---@param fn fun(state: SBJ__SaveData)
---@return boolean ran False when no saved state exists (fn not called)
function PersistentState.update(fn)
  local state = load()
  if state == nil then
    return false
  end

  fn(state)
  gKH.State.SaveTableToKey(state, SAVE_KEY)
  return true
end

---Load state and run fn against it without saving; mutations are discarded
---@param fn fun(state: SBJ__SaveData)
---@return boolean ran False when no saved state exists (fn not called)
function PersistentState.read(fn)
  local state = load()
  if state == nil then
    return false
  end

  fn(state)
  return true
end

return PersistentState
