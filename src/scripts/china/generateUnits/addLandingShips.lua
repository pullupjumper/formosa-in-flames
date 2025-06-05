RemoveLandingShips()
AddLandingShips()
local units = VP_GetSide({ Side = 'China' }).units

local list = {}
for index, u in ipairs(units) do
  local unit = SE_GetUnit({ guid = u.guid })

  if unit then
    if unit.name == 'Air Assault Bn' then
      table.insert(list, unit)
    end
  end
end

for index, unit in ipairs(list) do
  unit.name = unit.name .. ' #' .. tostring(index)
end
