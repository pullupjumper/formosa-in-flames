GameApi = {}

---comment
---@param guid string
---@param side? string
---@return CMO__Unit
function GameApi.ScenEdit_GetUnit(guid, side)
  local result = ScenEdit_GetUnit({ guid = guid })

  if result == nil then
    result = ScenEdit_GetUnit({ side = side, unitname = guid })
  end

  if result == nil then
    error("Unit not found with guid: " .. tostring(guid))
  end

  return result
end
