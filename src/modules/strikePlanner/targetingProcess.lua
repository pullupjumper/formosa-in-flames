local GameApi = require("src.utils.gameApi")
local Utils = require("src.utils.utils")
local Logger = require("src.utils.logger")
local Recon = require("src.modules.strikePlanner.recon")

local TargetingProcess = {}


---comment
---@param opts SBJ__FilterParams
---@return string[]
function TargetingProcess.findInfantry(opts)
  local contacts = opts.contacts
  local task = opts.task
  local targets = {}

  for _, area in ipairs(task.target.areas) do
    for _, contact in ipairs(contacts) do
      if contact.typed == 8 and contact:inArea(area) then
        table.insert(targets, contact.guid)
      end
    end
  end

  return targets
end

---comment
---@param opts SBJ__FilterParams
---@return string[]
function TargetingProcess.findAirborne(opts)
  local contacts = opts.contacts
  local task = opts.task
  local config = opts.config
  local targets = {}

  for _, area in ipairs(task.target.areas) do
    for _, contact in ipairs(contacts) do
      if contact.emissions and contact.emissions[1] then
        local emission = contact.emissions[1]['sensor_dbid']
        if (emission == config.sensorDBID7 or emission == config.sensorDBID8) and
            contact.typed == 0 and
            contact:inArea(area) then
          table.insert(targets, contact.guid)
        end
      end
    end
  end

  return targets
end

---comment
---@param opts SBJ__FilterParams
---@return string[]
function TargetingProcess.analyzeEmissions(opts)
  local contacts = opts.contacts
  local task = opts.task
  local config = opts.config
  local SAMTargets = {}

  for _, area in ipairs(task.target.areas) do
    for _, c in ipairs(contacts) do
      local isSensor = c.emissions and
          (c.emissions[1]['sensor_dbid'] == config.sensorDBID9 or
            c.emissions[1]['sensor_dbid'] == config.sensorDBID10 or
            c.emissions[1]['sensor_dbid'] == config.sensorDBID11 or
            c.emissions[1]['sensor_dbid'] == config.sensorDBID12 or
            c.emissions[1]['sensor_dbid'] == config.sensorDBID14)
      local isAgeLessThan = c.lastDetections and c.lastDetections[1].age <= task.target.contactAge
      local isSAM = isSensor and isAgeLessThan
      if c:inArea(area) and isSAM then table.insert(SAMTargets, c.guid) end
    end
  end

  return SAMTargets
end

---comment
---@param config SBJ__CONFIG
---@param distance number
---@param transmission table
---@return boolean
local function isWithinRange(config, distance, transmission)
  return distance <= config.c.SIGINT.maxRange and transmission.temp > config.c.SIGINT.maxCount
end

---comment
---@param opts SBJ__FilterParams
---@return string[]
function TargetingProcess.findMobileTargets(opts)
  local contacts = opts.contacts
  local task = opts.task
  local targets = {}

  for _, area in ipairs(task.target.areas) do
    for _, c in ipairs(contacts) do
      if (c.typed == 8) and c:inArea(area) then
        table.insert(targets, c.guid)
      end
    end
  end

  return targets
end

---comment
---@param config SBJ__CONFIG
---@param saveData SBJ__SaveData
---@param contacts string[]
---@return string[]|nil
local function filterTargetsWithinRangeOfRadioSource(config, saveData, contacts)
  local targets = {}
  local isTracking = false

  local side = GameApi.VP_GetSide({ side = 'China' })

  if not side then
    return
  end

  local units = side.units

  for _, guid in ipairs(contacts) do
    local contact = GameApi.ScenEdit_GetContact('China', guid)

    if contact then
      for _, tm in pairs(saveData.c.SIGINT.transmissions) do
        local distance = GameApi.Tool_Range({ latitude = tm.latitude, longitude = tm.longitude }, guid)

        if distance and isWithinRange(config, distance, tm) then
          table.insert(targets, guid)

          if not isTracking and tm.type == 'mobile' then
            isTracking = Recon.trackTarget(config, saveData, units, config.platformDBID13, contact)
          end
        end
      end
    end
  end

  return targets
end

---comment
---@param opts SBJ__FilterParams
---@return string[]|nil
function TargetingProcess.findRadioDirection(opts)
  local contacts = opts.contacts
  local saveData = opts.saveData
  local task = opts.task
  local config = opts.config
  local targets = {}
  local mobileTargets = TargetingProcess.findMobileTargets({ contacts = contacts, task = task })
  local c2Targets = TargetingProcess.findC2({ contacts = contacts, task = task })
  Utils.insertList(targets, mobileTargets)
  Utils.insertList(targets, c2Targets)
  local radioSource = filterTargetsWithinRangeOfRadioSource(config, saveData, targets)
  return radioSource
end

---comment
---@param opts SBJ__FilterParams
---@return string[]|nil
function TargetingProcess.findNavalTargets(opts)
  local shouldTrack = opts.shouldTrack or false
  local contacts = opts.contacts
  local saveData = opts.saveData
  local task = opts.task
  local config = opts.config
  local navalTargets = {}
  local hasTracked = false

  local side = GameApi.VP_GetSide({ side = 'China' })

  if not side then
    return
  end

  for _, area in ipairs(task.target.areas) do
    for _, contact in ipairs(contacts) do
      if contact.typed == 2 and
          contact:inArea(area) and
          contact.lastDetections and
          contact.lastDetections[1].age <= task.target.contactAge then
        table.insert(navalTargets, contact.guid)

        if not hasTracked then
          hasTracked = Recon.trackTarget(config, saveData, side.units, config.platformDBID12, contact)
          Logger.log("hasTracked: " .. tostring(hasTracked))
        end
      end
    end
  end

  return navalTargets
end

---comment
---@param opts SBJ__FilterParams
---@return string[]
function TargetingProcess.findC2(opts)
  local contacts = opts.contacts
  local task = opts.task
  local targets = {}

  for _, area in ipairs(task.target.areas) do
    for _, contact in ipairs(contacts) do
      if (string.find(contact.type_description, 'ROCC') ~= nil or
            string.find(contact.type_description, 'TAAOC') ~= nil) and
          contact:inArea(area) then
        table.insert(targets, contact.guid)
      end
    end
  end

  return targets
end

---comment
---@param target CMO__Contact
---@param contactAge number
---@param isFirstWave boolean
---@return boolean
function TargetingProcess.evaluateTarget(target, contactAge, isFirstWave)
  local actualUnit = GameApi.ScenEdit_GetUnit(target.actualunitid)

  if not actualUnit then
    return false
  end

  local isHelipad = string.find(target.type_description, 'Helipad') ~= nil
  local BDA = target.BDA
  local detections = target.lastDetections
  local hasEvaluated = BDA and not (BDA['STRUCTURAL'] == 'Heavy damage') and
      (detections and detections[1].age <= contactAge) and
      not isHelipad
  local isHelipadEmbarkedWithHelicopter = isHelipad and #actualUnit.embarkedUnits['Aircraft'] > 0
  return hasEvaluated or isHelipadEmbarkedWithHelicopter or isFirstWave
end

---comment
---@param task SBJ__Task
---@param isFirstWave boolean
---@return string[]
function TargetingProcess.assessTargetsDamage(task, isFirstWave)
  local evaluatedTargetlist = {}

  if type(task.target.list) ~= 'table' or #task.target.list == 0 then
    return evaluatedTargetlist
  end

  for _, guid in ipairs(task.target.list) do
    local actualTarget = GameApi.ScenEdit_GetContact('China', guid)

    if actualTarget and TargetingProcess.evaluateTarget(actualTarget, task.target.contactAge, isFirstWave) then
      table.insert(evaluatedTargetlist, actualTarget.guid)
    end
  end

  return evaluatedTargetlist
end

function TargetingProcess.selectTargetsByQueryParams(opts)
  local targetlist = opts.targetlist
  local queryParams = opts.queryParams
  local selectedTargetlist = {}

  for _, item in ipairs(targetlist) do
    for _, param in ipairs(queryParams) do
      local isNameMatched = false
      local isSubTypeMatched = false

      if not param.baseName then
        isNameMatched = true
      end

      if param.baseName then
        if string.find(item.name, param.baseName) ~= nil then
          isNameMatched = true
        end
      end

      for _, subType in ipairs(param.subTypes) do
        if string.find(item.subType, subType) ~= nil then
          isSubTypeMatched = true
          break
        end
      end

      if isNameMatched and isSubTypeMatched then
        table.insert(selectedTargetlist, item.guid)
      end
    end
  end

  return selectedTargetlist
end

return TargetingProcess
