local UnitGenerator = require('src.modules.unitGenerator')
local CONFIG = require('src.core.constants')

-- 移除現有登陸艦
UnitGenerator.removeLandingShips(CONFIG)

-- 添加新的登陸艦
UnitGenerator.addLandingShips(CONFIG)

-- 重命名空中突擊營
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