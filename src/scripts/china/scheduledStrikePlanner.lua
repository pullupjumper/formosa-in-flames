Utils = require("src.utils.utils")
GameUtils = require("src.utils.gameUtils")
Logger = require("src.utils.logger")
GameApi = require("src.utils.gameApi")
Recon = require("src.modules.strikePlanner.recon")
AttackManager = require("src.modules.strikePlanner.attackManager")


local contacts, err = Utils.SafeCall("GameApi.ScenEdit_GetContacts", GameApi.ScenEdit_GetContacts, 'China')

if not contacts then
  Logger.error("Error in ScenEdit_GetContacts: " .. err)
  return
end

local saveData = gKH.State.LoadTableFromKey("SaveData")

if saveData == nil then
  Logger.error("saveData is nil")
  return
end


local isWithinRange = function(distance, transmission)
  return distance <= CONFIG.c.SIGINT.maxRange and transmission.temp > CONFIG.c.SIGINT.maxCount
end

local function filterTargetsInArea(contacts, areas)
  local targets = {}

  for _, area in ipairs(areas) do
    for _, c in ipairs(contacts) do
      if (c.typed == 8 or
            string.find(c.type_description, 'ROCC') ~= nil or
            string.find(c.type_description, 'TAAOC') ~= nil) and
          c:inArea(area) then
        table.insert(targets, c)
      end
    end
  end

  return targets
end

local function filterTargetsWithinRangeOfRadioSource(saveData, contacts)
  local targets = {}
  local isTracking = false
  local units = VP_GetSide({ Side = 'China' }).units

  for _, contact in ipairs(contacts) do
    for _, tm in pairs(saveData.c.SIGINT.transmissions) do
      local distance = Tool_Range({ latitude = tm.latitude, longitude = tm.longitude }, contact.guid)

      if isWithinRange(distance, tm) then
        table.insert(targets, contact.guid)

        if not isTracking and tm.type == 'mobile' then
          isTracking = Recon.TrackTarget(CONFIG, saveData, units, CONFIG.platformDBID13, contact)
        end
      end
    end
  end

  return targets
end

local filterMakers = {
  ['makeInfentryFilter'] = function(package)
    return function(contact)
      return contact.typed == 8 and contact:inArea(package.area)
    end
  end,
  ['makeAirborneFilter'] = function(package)
    return function(contact)
      if contact.emissions and contact.emissions[1] then
        local emission = contact.emissions[1]['sensor_dbid']
        return (emission == CONFIG.sensorDBID7 or emission == CONFIG.sensorDBID8) and
            contact.typed == 0 and
            contact:inArea(package.area)
      end

      return false
    end
  end,
  ['makeNavalTargetFilter'] = function(package)
    return function(contact)
      return contact.typed == 2 and contact:inArea(package.area)
    end
  end,
  ['makeC2Filter'] = function(package)
    return function(contact)
      return
          (string.find(contact.type_description, 'ROCC') ~= nil or
            string.find(contact.type_description, 'TAAOC') ~= nil) and
          contact:inArea(package.area)
    end
  end,
}

local filters = {
  ['analyzeEmissions'] = function(FST, contacts)
    local SAMTargets = {}

    for _, area in ipairs(FST.areas) do
      for _, c in ipairs(contacts) do
        local isSensor = c.emissions and
            (c.emissions[1]['sensor_dbid'] == CONFIG.sensorDBID9 or
              c.emissions[1]['sensor_dbid'] == CONFIG.sensorDBID10 or
              c.emissions[1]['sensor_dbid'] == CONFIG.sensorDBID11 or
              c.emissions[1]['sensor_dbid'] == CONFIG.sensorDBID12 or
              c.emissions[1]['sensor_dbid'] == CONFIG.sensorDBID14)
        local isAgeLessThan = c.lastDetections and c.lastDetections[1].age <= FST.contactAge
        local isSAM = isSensor and isAgeLessThan
        if c:inArea(area) and isSAM then table.insert(SAMTargets, c.guid) end
      end
    end

    return SAMTargets
  end,
  ['findRadioDirection'] = function(FST, contacts, saveData)
    local targets = filterTargetsInArea(contacts, FST.areas)
    targets = filterTargetsWithinRangeOfRadioSource(saveData, targets)
    return targets
  end,
  ['findNavalTargets'] = function(FST, contacts, saveData)
    local navalTargets = {}
    local isTracking = false
    local units = VP_GetSide({ Side = 'China' }).units

    for _, area in ipairs(FST.areas) do
      for _, contact in ipairs(contacts) do
        if contact.typed == 2 and
            contact:inArea(area) and
            contact.lastDetections and
            contact.lastDetections[1].age <= FST.contactAge then
          table.insert(navalTargets, contact.guid)

          if not isTracking then
            isTracking = Recon.TrackTarget(CONFIG, saveData, units, CONFIG.platformDBID12, contact)
          end
        end
      end
    end

    return navalTargets
  end
}


local function assignAllUnitsToStrikeMission(pkg)
  local result = AssignEmbarkedUnitToStrikeMission(
    pkg.striker.baseGUID,
    pkg.striker.num,
    pkg.striker.weaponDBID,
    nil,
    pkg.missionName,
    false
  )

  if pkg.escort then
    AssignEmbarkedUnitToStrikeMission(
      pkg.escort.baseGUID,
      pkg.escort.num,
      pkg.escort.weaponDBID,
      nil,
      pkg.missionName,
      true
    )
  end

  if pkg.wildWeasel then
    AssignEmbarkedUnitToStrikeMission(
      pkg.wildWeasel.baseGUID,
      pkg.wildWeasel.num,
      pkg.wildWeasel.weaponDBID,
      nil,
      pkg.missionName,
      true
    )
  end

  if pkg.jammer then
    local jammers = AssignEmbarkedUnitToStrikeMission(
      pkg.jammer.baseGUID,
      pkg.jammer.num,
      0,
      pkg.jammer.unitDBID,
      pkg.missionName,
      true
    )

    if jammers then
      ScenEdit_SetEMCON('Unit', jammers[1], 'Radar=Passive;OECM=Active')
    end
  end

  if pkg.tanker then
    local mission = ScenEdit_GetMission('China', pkg.tanker.missionName)
    mission.isactive = true
  end

  if result == nil then return false end

  return #result > 0
end

local function isPackagesFinished(packages)
  for _, package in ipairs(packages) do
    if not package.hasLaunched then
      return false
    end
  end

  return true
end

local function isFSEMFinished(FSEM)
  for _, FST in ipairs(FSEM.FSTs) do
    if not FST.isFinished then
      return false
    end
  end

  return true
end

local function isBtyReady(bty, mlrsConfig, group)
  return mlrsConfig.batteries[bty.guid].state == CONFIG.batteryState.HIDE
      and not IsLowAmmo(
        group,
        mlrsConfig.batteries[bty.guid].ammoThreshold,
        mlrsConfig.batteries[bty.guid].weaponDBID
      )
end

local function isNotBtyAtFiringPosition(bty, mlrsConfig)
  return mlrsConfig.batteries[bty.guid].state ~= CONFIG.batteryState.STATIC
end

local function evaluateTarget(target, FST, isFirstWave)
  local isHelipad = string.find(target.type_description, 'Helipad') ~= nil
  local BDA = target.BDA
  local detections = target.lastDetections
  local hasEvaluated = BDA and not (BDA['STRUCTURAL'] == 'Heavy damage') and
      (detections and detections[1].age <= FST.contactAge) and
      not isHelipad
  local isHelipadEmbarkedWithHelicopter = isHelipad and
      #SE_GetUnit({ guid = target.actualunitid }).embarkedUnits['Aircraft'] > 0
  return hasEvaluated or isHelipadEmbarkedWithHelicopter or isFirstWave
end

local function shouldDeployToFiringPosition(saveData, FST)
  local allBatteriesInPosition = true

  for _, bty in ipairs(FST.batteries) do
    local actualBty = SE_GetUnit({ guid = bty.guid })

    if actualBty and isBtyReady(bty, saveData.c.ground[string.lower(FST.wpnSystem)], actualBty) then
      ToFringPosition(saveData.c.ground[string.lower(FST.wpnSystem)].batteries[bty.guid], actualBty)
    end

    if isNotBtyAtFiringPosition(bty, saveData.c.ground[string.lower(FST.wpnSystem)]) then
      allBatteriesInPosition = false
    end
  end

  return allBatteriesInPosition
end

local function identifyEmTargets(saveData, contacts, FST)
  local evaluatedTargetlist = {}

  for _, filterName in ipairs(FST.filterNames) do
    local targets = filters[filterName](FST, contacts, saveData)

    if CONFIG.isDevMode then
      GameUtils.PrintBox('China', filterName .. '/' .. FST.name .. ': ' .. #targets)
    end

    Utils.InsertList(evaluatedTargetlist, targets)
  end

  return evaluatedTargetlist
end

local function assessTargetsDamage(FST, FSEM)
  local evaluatedTargetlist = {}

  if type(FST.targetlist) ~= 'table' and #FST.targetlist == 0 then
    goto continue
  end

  for _, target in ipairs(FST.targetlist) do
    local actualTarget = ScenEdit_GetContact({ side = 'China', guid = target })

    if actualTarget and evaluateTarget(actualTarget, FST, FSEM.isFirstWave) then
      table.insert(evaluatedTargetlist, actualTarget.guid)
    end
  end

  ::continue::
  return evaluatedTargetlist
end

local function executeFireSupportTasks(FSEM)
  for _, FST in ipairs(FSEM.FSTs) do
    if not FST.isFinished and GameUtils.IsAfterStartTime(FST.startTime) and #FST.evaluatedTargetlist > FST.minTargetCount then
      local result = AttackManager.AttackContacts({
        contacts = FST.evaluatedTargetlist,
        qty = FST.ammoPerTarget,
        batteries = FST.batteries,
      })

      if result > 0 then
        FST.isFinished = true

        if CONFIG.isDevMode then
          GameUtils.PrintBox('China', FST.name .. '/Fired missiles: ' .. result)
        end
      end
    end
  end
end

local function strike(saveData, contacts)
  for _, FSEM in pairs(saveData.c.ground.FSP) do
    if not FSEM.isFinished and FSEM.isActivated then
      local allBatteriesInPosition = true

      for _, FST in ipairs(FSEM.FSTs) do
        if not FST.isFinished and GameUtils.IsAfterStartTime(FST.startTime) then
          local evaluatedTargetlist = assessTargetsDamage(FST, FSEM)

          if CONFIG.isDevMode then
            GameUtils.PrintBox('China', FST.name .. ': ' .. #evaluatedTargetlist)
          end

          if type(FST.filterNames) == "table" and #FST.filterNames > 0 then
            local emTargets = identifyEmTargets(saveData, contacts, FST)
            Utils.InsertList(evaluatedTargetlist, emTargets)
          end

          FST.evaluatedTargetlist = evaluatedTargetlist

          if #evaluatedTargetlist >= FST.minTargetCount then
            if not shouldDeployToFiringPosition(saveData, FST) then
              allBatteriesInPosition = false
            end
          else
            allBatteriesInPosition = false
          end
        end
      end

      FSEM.allBatteriesInPosition = allBatteriesInPosition
    end
  end

  for _, FSEM in pairs(saveData.c.ground.FSP) do
    if not FSEM.isFinished and FSEM.isActivated and FSEM.allBatteriesInPosition then
      executeFireSupportTasks(FSEM)
    end

    if isFSEMFinished(FSEM) then
      FSEM.isFinished = true
    end
  end
end


local function handleStrikePackagesWithMission(package, wave, contacts)
  local mission = ScenEdit_GetMission('China', package.missionName)
  local evaluatedTargetlist = {}

  if not mission then
    mission = ScenEdit_AddMission('China', package.missionName, 'strike', { type = package.missionType })
    ScenEdit_SetEMCON('Mission', package.missionName, 'Radar=Passive;OECM=Active')
  end

  if package.missionType == 'land' then
    evaluatedTargetlist = assessTargetsDamage(package, wave)
  end

  if type(package.filterName) == 'string' and #package.filterName > 0 then
    for _, contact in ipairs(contacts) do
      local result = filterMakers[package.filterName](package)(contact)

      if result then
        table.insert(evaluatedTargetlist, contact.guid)
      end
    end
  end

  if #evaluatedTargetlist >= package.minTargetCount then
    for _, guid in ipairs(evaluatedTargetlist) do
      ScenEdit_AssignUnitAsTarget(guid, package.missionName)
    end

    return assignAllUnitsToStrikeMission(package)
  end

  return false
end

local function airStrike(saveData, contacts)
  for _, wave in pairs(saveData.c.air.ATO) do
    if not wave.hasLaunched and wave.isActivated then
      for _, package in ipairs(wave.packages) do
        if not package.hasLaunched and GameUtils.IsAfterStartTime(package.takeoffTime) then
          local isAssigned = handleStrikePackagesWithMission(package, wave, contacts)

          if isAssigned then
            package.hasLaunched = true
          end

          break
        end
      end

      if isPackagesFinished(wave.packages) then
        wave.hasLaunched = true
      end
    end
  end
end


if saveData.c.recon.isActivated then
  Recon.HandleReconQueue(saveData)
end

if saveData.c.surface.lacm.isActivated and GameUtils.IsAfterStartTime(saveData.c.surface.lacm.startTime) then
  local ships = {}

  for _, value in ipairs(SE_GetUnit({ unitname = 'CSG' }).group.unitlist) do
    local unit = SE_GetUnit({ guid = value })
    if unit and unit.dbid == CONFIG.platformDBID51 then
      table.insert(ships, { guid = value, weaponDBID = CONFIG.c.surface.lacm.weaponDBID })
    end
  end

  AttackManager.AttackContacts({
    contacts = CONFIG.c.surface.lacm.targetlist,
    qty = 5,
    batteries = ships,
    weaponDBID = CONFIG.c.surface.lacm.weaponDBID
  })
  saveData.c.surface.lacm.isActivated = false
end

if saveData.c.subSurface.slcm.isActivated and GameUtils.IsAfterStartTime(saveData.c.subSurface.slcm.startTime) then
  for _, unit in pairs(CONFIG.c.subSurface.slcm.submarines) do
    local actualUnit = SE_GetUnit({ side = 'China', unitname = unit.name })

    if actualUnit then
      local course = { { latitude = actualUnit.latitude, longitude = actualUnit.longitude, presetDepth = 2 } }
      for _, value in ipairs(actualUnit.course) do
        table.insert(course, { latitude = value.latitude, longitude = value.longitude, presetDepth = 2 })
      end

      actualUnit.course = course
    end
  end

  AttackManager.AttackContacts({
    contacts = CONFIG.c.subSurface.slcm.targetlist,
    qty = 8,
    batteries = CONFIG.c.subSurface.slcm.submarines,
    weaponDBID = CONFIG.c.subSurface.slcm.weaponDBID
  })

  saveData.c.subSurface.slcm.isActivated = false
end

if saveData.c.ground.isActivated then
  strike(saveData, contacts)
end

if saveData.c.air.isActivated then
  airStrike(saveData, contacts)
end

gKH.State.SaveTableToKey(saveData, "SaveData")
