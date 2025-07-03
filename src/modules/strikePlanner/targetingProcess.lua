local GameApi = require("src.utils.gameApi")
local Utils = require("src.utils.utils")
local Logger = require("src.utils.logger")
local Recon = require("src.modules.strikePlanner.recon")

local TargetingProcess = {}


---comment
---@param opts SBJ__FilterParams
---@return string[]
function TargetingProcess.FindInfantry(opts)
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
function TargetingProcess.FindAirborne(opts)
  local contacts = opts.contacts
  local task = opts.task
  local CONFIG = opts.CONFIG
  local targets = {}

  for _, area in ipairs(task.target.areas) do
    for _, contact in ipairs(contacts) do
      if contact.emissions and contact.emissions[1] then
        local emission = contact.emissions[1]['sensor_dbid']
        if (emission == CONFIG.sensorDBID7 or emission == CONFIG.sensorDBID8) and
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
function TargetingProcess.AnalyzeEmissions(opts)
  local contacts = opts.contacts
  local task = opts.task
  local CONFIG = opts.CONFIG
  local SAMTargets = {}

  for _, area in ipairs(task.target.areas) do
    for _, c in ipairs(contacts) do
      local isSensor = c.emissions and
          (c.emissions[1]['sensor_dbid'] == CONFIG.sensorDBID9 or
            c.emissions[1]['sensor_dbid'] == CONFIG.sensorDBID10 or
            c.emissions[1]['sensor_dbid'] == CONFIG.sensorDBID11 or
            c.emissions[1]['sensor_dbid'] == CONFIG.sensorDBID12 or
            c.emissions[1]['sensor_dbid'] == CONFIG.sensorDBID14)
      local isAgeLessThan = c.lastDetections and c.lastDetections[1].age <= task.target.contactAge
      local isSAM = isSensor and isAgeLessThan
      if c:inArea(area) and isSAM then table.insert(SAMTargets, c.guid) end
    end
  end

  return SAMTargets
end

---comment
---@param CONFIG SBJ__CONFIG
---@param distance number
---@param transmission table
---@return boolean
function TargetingProcess._isWithinRange(CONFIG, distance, transmission)
  return distance <= CONFIG.c.SIGINT.maxRange and transmission.temp > CONFIG.c.SIGINT.maxCount
end

---comment
---@param opts SBJ__FilterParams
---@return string[]
function TargetingProcess.FindMobileTargets(opts)
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
---@param CONFIG SBJ__CONFIG
---@param saveData SBJ__SaveData
---@param contacts string[]
---@return string[]|nil
function TargetingProcess._filterTargetsWithinRangeOfRadioSource(CONFIG, saveData, contacts)
  local targets = {}
  local isTracking = false
  -- local units = VP_GetSide({ Side = 'China' }).units

  local side, err = Utils.SafeCall("GameApi.VP_GetSide", GameApi.VP_GetSide, { side = 'China' })

  if not side then
    Logger.error("Error in VP_GetSide: " .. err)
    return
  end

  local units = side.units

  for _, guid in ipairs(contacts) do
    local contact, err = Utils.SafeCall("GameApi.ScenEdit_GetContact", GameApi.ScenEdit_GetContact, 'China', guid)

    if not contact then
      Logger.error("Error in ScenEdit_GetContact: " .. err)
      goto continue
    end

    for _, tm in pairs(saveData.c.SIGINT.transmissions) do
      local distance = Utils.SafeCall(
        'GameApi.Tool_Range',
        GameApi.Tool_Range,
        { latitude = tm.latitude, longitude = tm.longitude },
        guid
      )

      if not distance then
        Logger.error("Error in Tool_Range: " .. err)
        goto continue
      end
      -- local distance = Tool_Range({ latitude = tm.latitude, longitude = tm.longitude }, guid)

      if TargetingProcess._isWithinRange(CONFIG, distance, tm) then
        table.insert(targets, guid)

        if not isTracking and tm.type == 'mobile' then
          isTracking = Recon.TrackTarget(CONFIG, saveData, units, CONFIG.platformDBID13, contact)
        end
      end
    end

    ::continue::
  end

  return targets
end

---comment
---@param opts SBJ__FilterParams
---@return string[]|nil
function TargetingProcess.FindRadioDirection(opts)
  local contacts = opts.contacts
  local saveData = opts.saveData
  local task = opts.task
  local CONFIG = opts.CONFIG
  local targets = {}
  local mobileTargets = TargetingProcess.FindMobileTargets({ contacts = contacts, task = task })
  local c2Targets = TargetingProcess.FindC2({ contacts = contacts, task = task })
  Utils.InsertList(targets, mobileTargets)
  Utils.InsertList(targets, c2Targets)
  local radioSource = TargetingProcess._filterTargetsWithinRangeOfRadioSource(CONFIG, saveData, targets)
  -- local targets = filterTargetsInArea(contacts, package.target.areas)
  -- targets = TargetingProcess._filterTargetsWithinRangeOfRadioSource(saveData, targets, CONFIG)
  return radioSource
end

---comment
---@param opts SBJ__FilterParams
---@return string[]|nil
function TargetingProcess.FindNavalTargets(opts)
  local shouldTrack = opts.shouldTrack or false
  local contacts = opts.contacts
  local saveData = opts.saveData
  local task = opts.task
  local CONFIG = opts.CONFIG
  local navalTargets = {}
  local hasTracked = false

  local side, err = Utils.SafeCall("GameApi.VP_GetSide", GameApi.VP_GetSide, { side = 'China' })

  if not side then
    Logger.error("Error in VP_GetSide: " .. err)
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
          hasTracked = Recon.TrackTarget(CONFIG, saveData, side.units, CONFIG.platformDBID12, contact)
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
function TargetingProcess.FindC2(opts)
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
function TargetingProcess.EvaluateTarget(target, contactAge, isFirstWave)
  local actualUnit, err = Utils.SafeCall("GameApi.ScenEdit_GetUnit", GameApi.ScenEdit_GetUnit, target.actualunitid)

  if not actualUnit then
    Logger.error('Failed to get unit ' .. target.actualunitid .. ': ' .. err)
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
function TargetingProcess.AssessTargetsDamage(task, isFirstWave)
  local evaluatedTargetlist = {}

  if type(task.target.list) ~= 'table' and #task.target.list == 0 then
    goto continue
  end

  for _, guid in ipairs(task.target.list) do
    local actualTarget, err = Utils.SafeCall(
      "GameApi.ScenEdit_GetContact", GameApi.ScenEdit_GetContact, 'China', guid
    )

    if not actualTarget then
      Logger.error('Failed to get contact ' .. guid .. ': ' .. err)
      goto continue2
    end

    if TargetingProcess.EvaluateTarget(actualTarget, task.target.contactAge, isFirstWave) then
      table.insert(evaluatedTargetlist, actualTarget.guid)
    end

    ::continue2::
  end

  ::continue::
  return evaluatedTargetlist
end

function TargetingProcess.SelectTargetsByQueryParams(opts)
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
