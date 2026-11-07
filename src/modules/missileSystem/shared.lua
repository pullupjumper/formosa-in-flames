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

---Process steps in order against their handlers and keep the rows they return
---Arrival, the reload cycle and fire support dispatch all carry out Rules' steps through here.
---@generic C, O
---@param steps string[] Steps from one Rules.evaluate* call
---@param handlers table<string, fun(ctx: C, obs: O): SBJ__LogResult|nil> Handlers keyed by Rules.STEP
---@param ctx C What every step may read; steps never write it
---@param obs? O What the executor observed; nil only when Rules took its no-observation branch, whose steps read ctx only
---@return SBJ__LogResult[] rows Rows of the steps that produced one, in step order
function Shared.executeSteps(steps, handlers, ctx, obs)
  local rows = {}
  for _, step in ipairs(steps) do
    local row = handlers[step](ctx, obs)
    if row then
      table.insert(rows, row)
    end
  end
  return rows
end

return Shared
