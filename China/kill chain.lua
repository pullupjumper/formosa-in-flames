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

local function shouldTakeoffBeforeStrike(q)
  return (not q.hasLaunched) and q.takeoffTime ~= nil and q.missionStartTime ~= nil
end

local function shouldTakeoffAfterStrike(q)
  return (not q.hasLaunched) and q.missionStartTime ~= nil
end

local function isAfterStartTime(time)
  return ScenEdit_CurrentTime() > ParseDatetimeToTimestamp(time)
end

local function isH6N(q)
  return not q.hasLaunched and q.unitDBID == CONFIG.platformDBID76
end

local function shouldEnterTargetArea(q)
  return q.hasLaunched and not q.isFinished and q.takeoffTime ~= nil and q.missionStartTime ~= nil
end

local function shouldRTB(q)
  return q.hasLaunched and not q.isFinished
end

local function handleReconQueue(saveData)
  for _, q in ipairs(saveData.c.recon.queue) do
    if shouldTakeoffBeforeStrike(q) and isAfterStartTime(q.takeoffTime) then
      local units = LaunchUnits(q.baseGUID, q.course, q.num, q.unitDBID, 'Aircraft')

      if units and #units > 0 then
        q.unitGUID = units[1].unit
        q.hasLaunched = true
      end
    elseif shouldTakeoffAfterStrike(q) and isAfterStartTime(q.missionStartTime) then
      local units = AssignEmbarkedUnitToStrikeMission(q.baseGUID, q.num, 0, q.unitDBID, q.missionName, false)

      if units and #units > 0 then
        q.unitGUID = units[1].unit
        q.hasLaunched = true
        q.isFinished = true
      end
    elseif isH6N(q) then
      local units = LaunchUnits(q.baseGUID, q.course, q.num, q.unitDBID, 'Aircraft')

      if units and #units > 0 then
        q.unitGUID = units[1].unit
        q.hasLaunched = true
      end
    end

    if shouldEnterTargetArea(q) and isAfterStartTime(q.missionStartTime) then
      local unit = SE_GetUnit({ guid = q.unitGUID })

      if unit then
        ScenEdit_AssignUnitToMission(unit.guid, q.missionName)
        q.isFinished = true
      end
    elseif shouldRTB(q) then
      local unit = SE_GetUnit({ guid = q.unitGUID })

      if unit and #unit.course == 0 and unit.dbid == CONFIG.platformDBID12 then
        unit:RTB(true)
        q.isFinished = true
      end
    end
  end
end

local function trackTarget(saveData, units, UAVDBID, target)
  local UAV = nil

  for guid, value in pairs(saveData.c.recon.temp.BZK005) do
    if value.targetGUID == target.guid then
      local unit = SE_GetUnit({ guid = guid })
      if unit then return true end
    end
  end

  if UAV == nil then
    local d = 1000

    for _, value in ipairs(units) do
      local unit = SE_GetUnit({ guid = value.guid })

      if unit and unit.dbid == UAVDBID and unit.condition == 'Airborne' then
        local distance = Tool_Range({ latitude = unit.latitude, longitude = unit.longitude }, target.guid)
        if distance < d then
          d = distance
          UAV = unit
        end
      end
    end
  end

  if UAV then
    if UAV.mission then UAV.mission = '' end

    UAV.course = { {
      latitude = target.latitude,
      longitude = target.longitude,
      desiredSpeed = 115,
      presetThrottle = 'Military'
    } }

    saveData.c.recon.temp.BZK005[UAV.guid] = { guid = UAV.guid, targetGUID = target.guid }
    return true
  end

  return false
end

local function analyzeTargets(saveData, type)
  local targetsSortedByPackage = {}
  local mlrsConfig = saveData.c.ground[type]

  for index, package in ipairs(mlrsConfig.packages) do
    local batchTargetlistsIdx = package.index
    local targets = {}

    for _, obj in ipairs(package.batchTargetlists[batchTargetlistsIdx]) do
      local target = ScenEdit_GetContact({ side = 'China', guid = obj.guid })

      if target then
        local isHelipad = string.find(target.type_description, 'Helipad') ~= nil
        local BDA = target.BDA
        local detections = target.lastDetections
        local hasEvaluated = BDA and not (BDA['STRUCTURAL'] == 'Heavy damage') and
            (detections and detections[1].age <= CONFIG.c.ground[type].contactAge) and
            not isHelipad
        local isInitialWaveOfAttacks = batchTargetlistsIdx == 1 and
            not mlrsConfig.packages[index].isFinished and
            not isHelipad
        local isRadar = package.name == 'RADAR' and not isHelipad
        local isHelipadEmbarkedWithHelicopter = isHelipad and
            not mlrsConfig.packages[index].isFinished and
            #SE_GetUnit({ guid = target.actualunitid }).embarkedUnits['Aircraft'] > 0

        if (isInitialWaveOfAttacks or hasEvaluated or isRadar or isHelipadEmbarkedWithHelicopter) then
          table.insert(targets, target)
        end
      end
    end

    table.insert(targetsSortedByPackage, {
      isDecidedToStrike = false,
      fixedTargets = targets,
      emittingTargets = {},
      radioTargets = {},
      targets = targets
    })

    if CONFIG.isDevMode and #targets > 0 then
      PrintBox('China', 'Fixed targets/' .. package.name .. ': ' .. #targets)
    end
  end

  return targetsSortedByPackage
end

local function analyzeEmissions(saveData, type, targetsSortedByPackage, contacts)
  local mlrsConfig = saveData.c.ground[type]

  for index, package in ipairs(mlrsConfig.packages) do
    local targets = {}

    for _, area in ipairs(package.areas) do
      for _, c in ipairs(contacts) do
        local isSensor = c.emissions and
            (c.emissions[1]['sensor_dbid'] == CONFIG.sensorDBID9 or
              c.emissions[1]['sensor_dbid'] == CONFIG.sensorDBID10 or
              c.emissions[1]['sensor_dbid'] == CONFIG.sensorDBID11 or
              c.emissions[1]['sensor_dbid'] == CONFIG.sensorDBID12 or
              c.emissions[1]['sensor_dbid'] == CONFIG.sensorDBID14)
        local isAgeLessThan = c.lastDetections and c.lastDetections[1].age <= CONFIG.c.recon.contactAge
        local isSAM = isSensor and isAgeLessThan
        if c:inArea(area) and isSAM then table.insert(targets, c) end
      end
    end

    targetsSortedByPackage[index].emittingTargets = targets
    InsertList(targetsSortedByPackage[index].targets, targets)

    if CONFIG.isDevMode and #targets > 0 then
      PrintBox('China', 'Emission targets/' .. package.name .. ': ' .. #targets)
    end
  end

  return targetsSortedByPackage
end

local function findRadioDirection(saveData, platform, targetsSortedByPackage, contacts)
  local mlrsConfig = saveData.c.ground[platform]

  local isWithinRange = function(distance, transmission)
    return distance <= CONFIG.c.SIGINT.maxRange and
        transmission.temp > CONFIG.c.SIGINT.maxCount
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
          table.insert(targets, contact)

          if not isTracking and tm.type == 'mobile' then
            isTracking = trackTarget(saveData, units, CONFIG.platformDBID13, contact)
          end
        end
      end
    end

    return targets
  end

  for index, package in ipairs(mlrsConfig.packages) do
    local targets = filterTargetsInArea(contacts, package.areas)
    targets = filterTargetsWithinRangeOfRadioSource(saveData, targets)
    targetsSortedByPackage[index].radioTargets = targets
    InsertList(targetsSortedByPackage[index].targets, targets)

    if CONFIG.isDevMode and #targets > 0 then
      PrintBox('China', 'Radio targets/' .. package.name .. ': ' .. #targets)
    end
  end

  return targetsSortedByPackage
end

local function determineIfDeployByTargetCount(targetsSortedByPackage, targetNum)
  for _, item in ipairs(targetsSortedByPackage) do
    item.isTargetsMoreThan = #item.targets >= targetNum
        or (#item.emittingTargets >= 1 and #item.fixedTargets <= 1)
        or (#item.radioTargets >= 1 and #item.fixedTargets <= 1)
  end

  return targetsSortedByPackage
end

local function deployBatteries(saveData, platform, targetsSortedByPackage)
  local mlrsConfig = saveData.c.ground[platform]
  local isAllBtiesArrived = true
  local keys = {}

  local isBtyReady = function(bty, mlrsConfig, group)
    return mlrsConfig.batteries[bty.guid].state == CONFIG.batteryState.HIDE
        and not IsLowAmmo(
          group,
          mlrsConfig.batteries[bty.guid].ammoThreshold,
          mlrsConfig.batteries[bty.guid].weaponDBID
        )
  end

  local isNotBtyAtFiringPosition = function(bty, mlrsConfig)
    return mlrsConfig.batteries[bty.guid].state ~= CONFIG.batteryState.STATIC
  end

  for index, item in ipairs(targetsSortedByPackage) do
    if item.isTargetsMoreThan then
      table.insert(keys, index)
    end
  end

  for _, index in ipairs(keys) do
    for _, bty in ipairs(mlrsConfig.packages[index].batteries) do
      local group = SE_GetUnit({ guid = bty.guid })

      if group then
        if isBtyReady(bty, mlrsConfig, group) then
          ToFringPosition(mlrsConfig.batteries[bty.guid], group)
        end

        if isNotBtyAtFiringPosition(bty, mlrsConfig) then
          isAllBtiesArrived = false
        end
      end
    end
  end

  return isAllBtiesArrived
end

local function launchMissiles(saveData, platform, targetsSortedByPackage, weaponDBID)
  local mlrsConfig = saveData.c.ground[platform]

  for idx, item in ipairs(targetsSortedByPackage) do
    if item.isTargetsMoreThan then
      local result = AttackContacts(
        item.targets,
        mlrsConfig.packages[idx].num,
        mlrsConfig.packages[idx].batteries,
        weaponDBID
      )

      if result > 0 then
        mlrsConfig.packages[idx].index = mlrsConfig.packages[idx].index + 1

        if CONFIG.isDevMode then
          PrintBox('China', mlrsConfig.packages[idx].name .. '/Fired missiles: ' .. result)
        end
      end

      local targetListLength = #mlrsConfig.packages[idx].batchTargetlists
      local nextTargetListIdx = mlrsConfig.packages[idx].index
      local isTargetListIdxOutOfBounds = nextTargetListIdx > targetListLength

      if isTargetListIdxOutOfBounds then
        mlrsConfig.packages[idx].index = targetListLength
        mlrsConfig.packages[idx].isFinished = true
      end
    end
  end
end

local function handleStrikePackagesWithMission(package, contacts, filterFn, contactNum)
  local assignAllUnitsToStrikeMission = function(pkg)
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
      AssignEmbarkedUnitToStrikeMission(
        pkg.jammer.baseGUID,
        pkg.jammer.num,
        0,
        pkg.jammer.unitDBID,
        pkg.missionName,
        true
      )
    end

    if pkg.tanker then
      local mission = ScenEdit_GetMission('China', pkg.tanker.missionName)
      mission.isactive = true
    end

    if result == nil then return false end

    return #result > 0
  end

  local mission = ScenEdit_GetMission('China', package.missionName)

  if mission then
    -- ScenEdit_SetMission('China', package.missionName, { starttime = ScenEdit_CurrentTime() })

    for _, guid in ipairs(mission.targetlist) do
      local contact = ScenEdit_GetContact({ side = 'China', guid = guid })

      if contact and contact.BDA and contact.BDA['STRUCTURAL'] == 'Heavy damage' then
        ScenEdit_RemoveUnitAsTarget({ contact.guid }, mission.name)
      end
    end
  end

  if contacts and filterFn and contactNum then
    local fn = filterFn(package)
    local filteredContacts = {}

    for _, contact in ipairs(contacts) do
      local result = fn(contact)
      if result then
        table.insert(filteredContacts, contact)
      end
    end
    -- local filteredContacts = FilterContacts(contacts, fn)
    -- local filteredContacts = Array_utils.new(contacts):filter(filterFn(package)):value()

    if #filteredContacts >= contactNum or (mission and #mission.targetlist > 0) then
      for _, value in ipairs(filteredContacts) do
        value.posture = 'H'
        ScenEdit_AssignUnitAsTarget(value.guid, package.missionName)
      end
      return assignAllUnitsToStrikeMission(package)
    end
  else
    return assignAllUnitsToStrikeMission(package)
  end
  return false
end

local function isPackagesFinished(packages)
  for _, package in ipairs(packages) do
    if not package.hasLaunched then
      return false
    end
  end

  return true
end

local function isNoUnitAssignedToMission(missionName)
  local mission = ScenEdit_GetMission('China', missionName)

  if mission then
    return #mission.unitlist == 0
  end

  return true
end

-- local function airStrike(saveData, base, type, contacts, contactHandler, contactNum)
--   local antishipConfig = saveData.c.air[base][type]
--   local elapsedTime = 0

--   if antishipConfig.lastStrikeTime then
--     elapsedTime = ScenEdit_CurrentTime() - antishipConfig.lastStrikeTime
--   end

--   local isAllowedToAttack = not antishipConfig.lastStrikeTime
--       or (antishipConfig.lastStrikeTime and elapsedTime >= CONFIG.c.air[base][type].strikeInterval)

--   for _, package in ipairs(antishipConfig.packages) do
--     if not package.hasLaunched and isAllowedToAttack then
--       local isAssigned = handleStrikePackagesWithMission(package, contacts, contactHandler, contactNum)

--       if isAssigned then
--         package.hasLaunched = true
--         antishipConfig.lastStrikeTime = ScenEdit_CurrentTime()
--       end

--       break
--     end
--   end

--   if isPackagesFinished(antishipConfig.packages) and
--       isNoUnitAssignedToMission(antishipConfig.packages[#antishipConfig.packages].missionName) then
--     for _, package in ipairs(antishipConfig.packages) do
--       package.hasLaunched = false
--     end
--   end
-- end

-- local function airStrike(saveData, base, type, contacts, contactHandler, contactNum)
--   local antishipConfig = saveData.c.air[base][type]
--   local elapsedTime = 0

--   if antishipConfig.lastStrikeTime then
--     elapsedTime = ScenEdit_CurrentTime() - antishipConfig.lastStrikeTime
--   end

--   local isAllowedToAttack = not antishipConfig.lastStrikeTime
--       or (antishipConfig.lastStrikeTime and elapsedTime >= CONFIG.c.air[base][type].strikeInterval)

--   for _, wave in ipairs(antishipConfig.ATO) do
--     if not wave.hasLaunched and isAfterStartTime(wave.startTime) then
--       for _, package in ipairs(wave.packages) do
--         if not package.hasLaunched and isAllowedToAttack then
--           local isAssigned = handleStrikePackagesWithMission(package, contacts, contactHandler, contactNum)

--           if isAssigned then
--             package.hasLaunched = true
--             antishipConfig.lastStrikeTime = ScenEdit_CurrentTime()
--           end

--           break
--         end
--       end

--       if isPackagesFinished(wave.packages) then
--         wave.hasLaunched = true
--       end

--       break
--     end
--   end
-- end

local function airStrike(saveData, contacts)
  -- local antishipConfig = saveData.c.air.ATO
  -- local elapsedTime = 0

  -- if antishipConfig.lastStrikeTime then
  --   elapsedTime = ScenEdit_CurrentTime() - antishipConfig.lastStrikeTime
  -- end

  -- local isAllowedToAttack = not antishipConfig.lastStrikeTime
  --     or (antishipConfig.lastStrikeTime and elapsedTime >= CONFIG.c.air[base][type].strikeInterval)

  for _, wave in pairs(saveData.c.air.ATO) do
    if not wave.hasLaunched and wave.isActivated then
      for _, package in ipairs(wave.packages) do
        if not package.hasLaunched and isAfterStartTime(package.takeoffTime) then
          local isAssigned = handleStrikePackagesWithMission(package, contacts, filterMakers[package.filterName], 1)

          if isAssigned then
            package.hasLaunched = true
            -- antishipConfig.lastStrikeTime = ScenEdit_CurrentTime()
          end

          break
        end
      end

      if isPackagesFinished(wave.packages) then
        wave.hasLaunched = true
      end

      -- break
    end
  end
end

local contacts = ScenEdit_GetContacts('China')
local saveData = gKH.State.LoadTableFromKey("SaveData")

if saveData == nil then
  ScenEdit_SpecialMessage('China', 'saveData is nil')
  return
end

if contacts == nil then
  return
end

if saveData.c.recon.isActivated then
  handleReconQueue(saveData)
end

if saveData.c.ground.mlrs.isActivated then
  local targetsSortedByPackage = {}
  local isAllArrived = false
  local key = saveData.c.ground.mlrs.packages[1].batteries[1].guid
  local weaponDBID = saveData.c.ground.mlrs.batteries[key].weaponDBID
  targetsSortedByPackage = analyzeTargets(saveData, 'mlrs')
  targetsSortedByPackage = analyzeEmissions(saveData, 'mlrs', targetsSortedByPackage, contacts)
  targetsSortedByPackage = findRadioDirection(saveData, 'mlrs', targetsSortedByPackage, contacts)
  targetsSortedByPackage = determineIfDeployByTargetCount(targetsSortedByPackage, 5)
  isAllArrived = deployBatteries(saveData, 'mlrs', targetsSortedByPackage)
  if isAllArrived then launchMissiles(saveData, 'mlrs', targetsSortedByPackage, weaponDBID) end
end

if saveData.c.ground.srbm.isActivated then
  local targetsSortedByPackage = analyzeTargets(saveData, 'srbm')
  targetsSortedByPackage = determineIfDeployByTargetCount(targetsSortedByPackage, 5)
  local isAllArrived = deployBatteries(saveData, 'srbm', targetsSortedByPackage)
  if isAllArrived then launchMissiles(saveData, 'srbm', targetsSortedByPackage) end
end


if saveData.c.ground.glcm.isActivated then
  local targetsSortedByPackage = analyzeTargets(saveData, 'glcm')
  targetsSortedByPackage = determineIfDeployByTargetCount(targetsSortedByPackage, 5)
  local isAllArrived = deployBatteries(saveData, 'glcm', targetsSortedByPackage)
  if isAllArrived then launchMissiles(saveData, 'glcm', targetsSortedByPackage) end
end

if saveData.c.surface.lacm.isActivated then
  local ships = {}

  for _, value in ipairs(SE_GetUnit({ unitname = 'CSG' }).group.unitlist) do
    local unit = SE_GetUnit({ guid = value })
    if unit and unit.dbid == CONFIG.platformDBID51 then
      table.insert(ships, { guid = value })
    end
  end

  AttackContacts(
    CONFIG.c.surface.lacm.targetlist,
    5,
    ships,
    CONFIG.c.surface.lacm.weaponDBID
  )
end

if saveData.c.subSurface.slcm.isActivated then
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

  AttackContacts(
    CONFIG.c.subSurface.slcm.targetlist,
    8,
    CONFIG.c.subSurface.slcm.submarines,
    CONFIG.c.subSurface.slcm.weaponDBID
  )
end

if saveData.c.air.isActivated then
  airStrike(saveData, contacts)
end

gKH.State.SaveTableToKey(saveData, "SaveData")
