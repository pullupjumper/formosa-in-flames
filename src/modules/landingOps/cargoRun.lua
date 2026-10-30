local constants = require("src.core.constants")
local GameApi = require("src.utils.gameApi")

---Own the cargo run of a transport (helicopter, airlifter, hovercraft): it waits loaded aboard its host,
---goes out to its drop point, unloads there, then heads home.
---Callers set the course and launch; this module finds the ready transports and moves each run through its phases.
local CargoRun = {}

---@enum SBJ__CargoRunPhaseType
CargoRun.PHASE = {
  ENROUTE   = "enroute",
  UNLOADING = "unloading",
  RETURNING = "returning",
}

---Check if a unit carries any cargo
---@param unit CMO__Unit
---@return boolean # True if the unit carries at least one cargo item
local function hasCargo(unit)
  return unit.cargo ~= nil and unit.cargo[1] ~= nil and unit.cargo[1].cargo ~= nil and #unit.cargo[1].cargo > 0
end

---Check if a unit has finished unloading its cargo: it is under way again
---@param unit CMO__Unit
---@return boolean
local function isCargoUnloaded(unit)
  return unit.condition == constants.UNIT_CONDITIONS.UNDERWAY and unit.cargo == nil
end

---Check if a transport is close enough to its drop point
---@param unit CMO__Unit
---@param dropPoint CMO__Location
---@param arrivalNm number
---@return boolean # True if the unit is within arrivalNm of the drop point
local function hasArrived(unit, dropPoint, arrivalNm)
  local range = GameApi.Tool_Range(unit.guid, dropPoint)
  return range ~= nil and range < arrivalNm
end

---Find the transports aboard a host that are ready and loaded
---@param host CMO__Unit Ship or airfield
---@param platformType string Key of host.embarkedUnits
---@param dbid number Transport DBID
---@param skipMap? table<string, any> GUIDs to leave out, for example transports already on a run
---@return CMO__Unit[]
function CargoRun.findReady(host, platformType, dbid, skipMap)
  local ready = {}
  local embarked = host.embarkedUnits and host.embarkedUnits[platformType] or {}

  for _, guid in ipairs(embarked) do
    if not (skipMap and skipMap[guid]) then
      local unit = GameApi.ScenEdit_GetUnit(guid)
      if unit and unit.dbid == dbid and unit.readytime_v == 0 and hasCargo(unit) then
        table.insert(ready, unit)
      end
    end
  end

  return ready
end

---Return a transport to base and mark its run as returning
---@param unit CMO__Unit
---@param run {phase: SBJ__CargoRunPhaseType}
function CargoRun.returnToBase(unit, run)
  unit:RTB(true)
  run.phase = CargoRun.PHASE.RETURNING
end

---Move a run one step: at the drop point unload the cargo, and once the cargo is out return to base
---@param unit CMO__Unit
---@param run {phase: SBJ__CargoRunPhaseType}
---@param dropPoint CMO__Location
---@param arrivalNm number
function CargoRun.step(unit, run, dropPoint, arrivalNm)
  if run.phase == CargoRun.PHASE.ENROUTE then
    if hasArrived(unit, dropPoint, arrivalNm) then
      GameApi.ScenEdit_UnloadCargo(unit.guid)
      run.phase = CargoRun.PHASE.UNLOADING
    end
  elseif run.phase == CargoRun.PHASE.UNLOADING and isCargoUnloaded(unit) then
    CargoRun.returnToBase(unit, run)
  end
end

return CargoRun
