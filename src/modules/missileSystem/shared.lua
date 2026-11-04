local Shared = {}

---Normalize weaponDBID to always be an array
---@param weaponDBID number|number[]
---@return number[]
function Shared.normalizeWeaponDBIDs(weaponDBID)
  if type(weaponDBID) == "table" then
    return weaponDBID
  end
  return { weaponDBID }
end

---Get the list of unit GUIDs from a unit or its group
---@param unit CMO__Unit
---@return string[] # Array of unit GUIDs
function Shared.getGroupUnits(unit)
  return unit.group and unit.group.unitlist or { unit.guid }
end

return Shared
