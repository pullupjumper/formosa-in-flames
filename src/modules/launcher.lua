function Reload(battery, ammunitionSection, weaponDBID)
  local group = SE_GetUnit({ guid = battery.guid })
  if group == nil then return end

  for index, guid in ipairs(group.group.unitlist) do
    local unit = SE_GetUnit({ guid = guid })

    if unit == nil or unit.mounts == nil then goto continue end

    for _, mount in ipairs(unit.mounts) do
      local totalWpnCurrentNum = 0
      local totalWpnDefaultNum = 0

      for wpnIdx, wpn in ipairs(mount['mount_weapons']) do
        if wpn['wpn_dbid'] == weaponDBID then
          totalWpnCurrentNum = totalWpnCurrentNum + wpn['wpn_current']
          totalWpnDefaultNum = totalWpnDefaultNum + wpn['wpn_maxcap']
        end
      end

      local requiredNum = totalWpnDefaultNum - totalWpnCurrentNum

      if ammunitionSection.wpnCurrent >= requiredNum then
        ScenEdit_AddReloadsToUnit({
          guid = unit.guid,
          wpn_dbid = weaponDBID,
          number = requiredNum
        })
        ammunitionSection.wpnCurrent = ammunitionSection.wpnCurrent - requiredNum
      elseif ammunitionSection.wpnCurrent > 0 and ammunitionSection.wpnCurrent < requiredNum then
        ScenEdit_AddReloadsToUnit({
          guid = unit.guid,
          wpn_dbid = weaponDBID,
          number = ammunitionSection.wpnCurrent
        })
        ammunitionSection.wpnCurrent = 0
      end
    end

    ::continue::
  end

  battery.reloadStartTime = nil

  if CONFIG.isDevMode then
    PrintBox('China', 'func/Reload/Remaining ammo of ammunitionSection/' .. tostring(ammunitionSection.wpnCurrent))
    PrintBox('Taiwan', 'func/Reload/Remaining ammo of ammunitionSection/' .. tostring(ammunitionSection.wpnCurrent))
  end
end

function SetReloadStartTime(battery, group, isRepositioningAutomatically)
  battery.state = CONFIG.batteryState.RELOAD
  battery.reloadStartTime = ScenEdit_CurrentTime()

  for _, guid in ipairs(group.group.unitlist) do
    local u = SE_GetUnit({ guid = guid })

    if u and isRepositioningAutomatically then
      ScenEdit_SetUnit({ guid = u.guid, manualthrottle = 'Stop', manualSpeed = 0, holdposition = true })
      u.formation = { spacing = 0, transpose = true }
    end
  end
end

function SetWCSToFree(battery, group)
  battery.state = CONFIG.batteryState.STATIC

  for _, guid in ipairs(group.group.unitlist) do
    local u = SE_GetUnit({ guid = guid })

    if u then
      ScenEdit_SetUnit({ guid = u.guid, manualthrottle = 'Stop', manualSpeed = 0, holdposition = true })
      ScenEdit_SetDoctrine({ side = 'China', guid = u.guid }, { weapon_control_status_land = 1 })
      u.formation = { spacing = 0, transpose = true }
    end
  end
end

function SetStateToHIDE(battery, group)
  battery.state = CONFIG.batteryState.HIDE

  for _, guid in ipairs(group.group.unitlist) do
    local u = SE_GetUnit({ guid = guid })

    if u then
      ScenEdit_SetUnit({ guid = u.guid, manualthrottle = 'Stop', manualSpeed = 0, holdposition = true })
      ScenEdit_SetDoctrine({ side = 'China', guid = u.guid }, { weapon_control_status_land = 2 })
      u.formation = { spacing = 0, transpose = true }
    end
  end
end

function IsLowAmmo(group, percentage, weaponDBID)
  -- Calculate total weapon counts for a specific weapon type
  -- Returns true if the percentage of current weapons is <= the threshold percentage

  local totalWpnCurrentNum = 0
  local totalWpnDefaultNum = 0

  -- Helper function to process a single unit
  local function processUnit(unit)
    if not unit then return end

    -- Iterate through all mounts on the unit
    for _, mount in ipairs(unit.mounts) do
      -- Check all weapons in the mount
      for _, weapon in ipairs(mount.mount_weapons) do
        -- Only count weapons matching the specified weapon ID
        if weapon.wpn_dbid == weaponDBID then
          totalWpnCurrentNum = totalWpnCurrentNum + weapon.wpn_current
          totalWpnDefaultNum = totalWpnDefaultNum + weapon.wpn_maxcap
        end
      end
    end
  end

  -- Process either a single unit or a group of units
  if group.group == nil then
    -- Single unit case
    local unit = SE_GetUnit({ guid = group.guid })
    processUnit(unit)
  else
    -- Group of units case
    for _, guid in ipairs(group.group.unitlist) do
      local unit = SE_GetUnit({ guid = guid })
      processUnit(unit)
    end
  end

  local currentPercentage = (totalWpnCurrentNum / totalWpnDefaultNum) * 100
  return currentPercentage <= percentage
end

function ToFringPosition(battery, group)
  battery.state = CONFIG.batteryState.REPOSITIONING
  local courseIdx = math.random(GetCount(battery.position.FP))
  -- group.course = battery.position.FP[courseIdx].course
  -- group.manualSpeed = 30

  for _, guid in ipairs(group.group.unitlist) do
    local unit = SE_GetUnit({ guid = guid })

    if unit then
      ScenEdit_SetUnit({
        guid = unit.guid,
        manualthrottle = 'Flank',
        manualSpeed = 30,
        course = battery.position.FP[courseIdx].course,
        holdposition = false
      })
    end
  end
end

local function toRL(battery, group)
  battery.state = CONFIG.batteryState.REPOSITIONING
  -- group.course = battery.position.RL.course
  -- group.manualSpeed = 30

  for _, guid in ipairs(group.group.unitlist) do
    local unit = SE_GetUnit({ guid = guid })

    if unit then
      ScenEdit_SetUnit({
        guid = unit.guid,
        manualthrottle = 'Flank',
        manualSpeed = 30,
        course = battery.position.RL.course,
        holdposition = false
      })
      ScenEdit_SetDoctrine({ side = 'China', guid = unit.guid }, { weapon_control_status_land = 2 })
    end
  end
end

local function toHA(battery, group)
  battery.state = CONFIG.batteryState.REPOSITIONING
  -- group.course = battery.position.HA.course
  -- group.manualSpeed = 30

  for _, guid in ipairs(group.group.unitlist) do
    local unit = SE_GetUnit({ guid = guid })

    if unit then
      ScenEdit_SetUnit({
        guid = unit.guid,
        manualthrottle = 'Flank',
        manualSpeed = 30,
        course = battery.position.HA.course,
        holdposition = false
      })
      ScenEdit_SetDoctrine({ side = 'China', guid = unit.guid }, { weapon_control_status_land = 2 })
    end
  end
end

local function toAHA(section, group)
  section.state = CONFIG.batteryState.REPOSITIONING
  -- group.course = section.position.AHA.course
  -- group.manualSpeed = 30

  for _, guid in ipairs(group.group.unitlist) do
    local unit = SE_GetUnit({ guid = guid })

    if unit then
      ScenEdit_SetUnit({
        guid = unit.guid,
        manualthrottle = 'Flank',
        manualSpeed = 30,
        course = section.position.AHA.course,
        holdposition = false,
      })
    end
  end

  if CONFIG.isDevMode then
    PrintBox('China', 'func/toAHA/' .. tostring(section.name))
  end
end

local function transload(section, ammunition)
  if ammunition.wpnCurrent > 0 and section.wpnCurrent < section.wpnDefault then
    if ammunition.wpnCurrent >= section.wpnDefault then
      section.wpnCurrent = section.wpnCurrent + section.wpnDefault
      ammunition.wpnCurrent = ammunition.wpnCurrent - section.wpnDefault
    else
      section.wpnCurrent = section.wpnCurrent + ammunition.wpnCurrent
      ammunition.wpnCurrent = 0
    end
  end

  section.reloadStartTime = nil

  if CONFIG.isDevMode then
    PrintBox('China', 'func/transload/Remaining ammunition/' .. tostring(ammunition.wpnCurrent))
  end
end

local function ammoSecToRL(section, group)
  section.state = CONFIG.batteryState.REPOSITIONING
  -- group.course = { section.position.RL.course[GetCount(section.position.RL.course)] }
  -- group.manualSpeed = 30

  for _, guid in ipairs(group.group.unitlist) do
    local unit = SE_GetUnit({ guid = guid })

    if unit then
      ScenEdit_SetUnit({
        guid = unit.guid,
        manualthrottle = 'Flank',
        manualSpeed = 30,
        course = { section.position.RL.course[#section.position.RL.course] },
        holdposition = false
      })
    end
  end

  if CONFIG.isDevMode then
    PrintBox('China', 'func/ammoSecToRL/' .. section.name)
  end
end


function CheckBatteryState(saveData, platform, side, isRepositioningAutomatically)
  -- Process all batteries
  ProcessBatteries(saveData, platform, side, isRepositioningAutomatically)

  -- Process all ammunition sections
  ProcessAmmunitionSections(saveData, platform, side, isRepositioningAutomatically)
end

-- Process all batteries' states and actions
function ProcessBatteries(saveData, platform, side, isRepositioningAutomatically)
  local field = (side == 'China') and 'c' or 't'
  local platformConfig = saveData[field]['ground'][platform]

  for _, battery in pairs(platformConfig.batteries) do
    local group = SE_GetUnit({ guid = battery.guid })
    if not group then goto continue end

    if isRepositioningAutomatically then
      HandleAutomaticBatteryRepositioning(saveData, platform, side, battery, group,
        isRepositioningAutomatically)
    else
      HandleManualBatteryReload(saveData, platform, side, battery, group, isRepositioningAutomatically)
    end

    ::continue::
  end
end

-- Handle automatic battery repositioning logic
function HandleAutomaticBatteryRepositioning(saveData, platform, side, battery, group,
                                             isRepositioningAutomatically)
  local field = (side == 'China') and 'c' or 't'
  local platforms = saveData[field]['ground'][platform]
  local config = CONFIG[field]['ground'][platform]
  -- Handle STATIC state batteries
  if battery.state == CONFIG.batteryState.STATIC then
    if IsLowAmmo(group, battery.ammoThreshold, battery.weaponDBID) then
      toRL(battery, group)
    end
  end

  -- Handle RELOAD state batteries
  if battery.state == CONFIG.batteryState.RELOAD then
    -- Initialize reload start time if needed
    if battery.reloadStartTime == nil then
      battery.reloadStartTime = ScenEdit_CurrentTime() - config.reloadTime
    end

    -- Check if reload conditions are met
    local elapsedTime = ScenEdit_CurrentTime() - battery.reloadStartTime
    local result = IsMetWithAmmoTrucks(saveData, group, platform, isRepositioningAutomatically)
    local isMoreThanReloadTime = (battery.reloadStartTime ~= nil and
      elapsedTime >= config.reloadTime and
      result.isMet and
      IsLowAmmo(group, battery.ammoThreshold, battery.weaponDBID))

    -- Log debug information if dev mode is enabled
    LogBatteryDebugInfo(battery, elapsedTime, result, isMoreThanReloadTime)

    -- Perform reload if conditions are met
    if isMoreThanReloadTime then
      Reload(battery, platforms.ammunitionSections[battery.ammunitionSection], battery.weaponDBID)
      toHA(battery, group)
    end
  end
end

-- Handle manual battery reload logic
function HandleManualBatteryReload(saveData, platform, side, battery, group, isRepositioningAutomatically)
  local field = (side == 'China') and 'c' or 't'
  local platforms = saveData[field]['ground'][platform]
  local config = CONFIG[field]['ground'][platform]

  -- Initialize reload start time if needed
  if battery.reloadStartTime == nil then
    battery.reloadStartTime = ScenEdit_CurrentTime() + config.reloadTime * 100
  end

  -- Check if reload conditions are met
  local elapsedTime = ScenEdit_CurrentTime() - battery.reloadStartTime
  local result = IsMetWithAmmoTrucks(saveData, group, platform, isRepositioningAutomatically)
  local isMoreThanReloadTime = (battery.reloadStartTime ~= nil and
    elapsedTime >= config.reloadTime and
    result.isMet and
    IsLowAmmo(group, battery.ammoThreshold, battery.weaponDBID))

  -- Perform reload if conditions are met
  if isMoreThanReloadTime then
    Reload(battery, platforms.ammunitionSections[battery.ammunitionSection], battery.weaponDBID)

    if CONFIG.isDevMode then
      ScenEdit_MsgBox('Missile reload is finished/' .. battery.name, 1)
    end
  end
end

-- Log debug information for battery operations
function LogBatteryDebugInfo(battery, elapsedTime, result, isMoreThanReloadTime)
  if CONFIG.isDevMode then
    PrintBox(
      'China',
      'func/CheckBatteryState',
      'name:' .. battery.name,
      'elapsedTime:' .. tostring(elapsedTime),
      'isMet:' .. tostring(result.isMet),
      'isMoreThanReloadTime:' .. tostring(isMoreThanReloadTime)
    )
  end
end

-- Process all ammunition sections' states and actions
function ProcessAmmunitionSections(saveData, platform, side, isRepositioningAutomatically)
  local field = (side == 'China') and 'c' or 't'
  local platforms = saveData[field]['ground'][platform]

  for _, section in pairs(platforms.ammunitionSections) do
    local group = SE_GetUnit({ guid = section.guid })
    if not group then goto continue end

    if isRepositioningAutomatically then
      HandleAutomaticSectionRepositioning(saveData, platform, side, section, group,
        isRepositioningAutomatically)
    else
      HandleManualSectionReload(saveData, platform, side, section, group, isRepositioningAutomatically)
    end

    ::continue::
  end
end

-- Handle automatic ammunition section repositioning logic
function HandleAutomaticSectionRepositioning(saveData, platform, side, section, group,
                                             isRepositioningAutomatically)
  local field = (side == 'China') and 'c' or 't'
  local platforms = saveData[field]['ground'][platform]
  local config = CONFIG[field]['ground'][platform]

  -- Handle STATIC state sections
  if section.state == CONFIG.batteryState.STATIC then
    if section.wpnCurrent == 0 and group:inArea(section.position.RL.area) then
      toAHA(section, group)
    end
  end

  -- Handle RELOAD state sections
  if section.state == CONFIG.batteryState.RELOAD then
    local elapsedTime = ScenEdit_CurrentTime() - section.reloadStartTime
    local result = IsMetWithAmmo(saveData, group, platform, isRepositioningAutomatically)
    local isMoreThanReloadTime = (section.reloadStartTime ~= nil and
      elapsedTime >= config.reloadTime and
      section.wpnCurrent == 0 and
      result.isMet)

    if isMoreThanReloadTime then
      transload(section, platforms.ammunitions[section.ammunition])
      ammoSecToRL(section, group)

      if CONFIG.isDevMode then
        ScenEdit_MsgBox('Ammo transload is finished/' .. section.name, 1)
      end
    end
  end
end

-- Handle manual ammunition section reload logic
function HandleManualSectionReload(saveData, platform, side, section, group, isRepositioningAutomatically)
  local field = (side == 'China') and 'c' or 't'
  local platforms = saveData[field]['ground'][platform]
  local config = CONFIG[field]['ground'][platform]

  -- Initialize reload start time if needed
  if section.reloadStartTime == nil then
    section.reloadStartTime = ScenEdit_CurrentTime() + config.reloadTime * 100
  end

  -- Check if reload conditions are met
  local elapsedTime = ScenEdit_CurrentTime() - section.reloadStartTime
  local result = IsMetWithAmmo(saveData, group, platform, isRepositioningAutomatically)
  local isMoreThanReloadTime = (section.reloadStartTime ~= nil and
    elapsedTime >= config.reloadTime and
    section.wpnCurrent == 0 and
    result.isMet)

  -- Perform reload if conditions are met
  if isMoreThanReloadTime then
    transload(section, platforms.ammunitions[section.ammunition])

    if CONFIG.isDevMode then
      ScenEdit_MsgBox('Ammo transload is finished/' .. section.name, 1)
    end
  end
end

-- function IsMetWithAmmoTrucks(CONFIG, unit, platform, isRepositioningAutomatically)
--     local side = unit.side
--     local key = 't'

--     if side == 'China' then
--         key = 'c'
--     end

--     if unit.group then
--         local group = SE_GetUnit({ guid = unit.group.guid })

--         if group then
--             local field1 = 'batteries'
--             local field3 = 'ammunitionSections'

--             if string.find(group.name, 'Ammo') ~= nil or string.find(group.name, 'SUPP') ~= nil then
--                 field1 = 'ammunitionSections'
--                 field3 = 'batteries'
--             end

--             for _, battery in pairs(CONFIG[key].ground[platform][field1]) do
--                 local isTrue = true

--                 if isRepositioningAutomatically then
--                     isTrue = battery.state == CONFIG.batteryState.REPOSITIONING or
--                         battery.state == CONFIG.batteryState.RELOAD
--                 end

--                 if battery.guid == group.guid and isTrue then
--                     local area = nil

--                     for _, p in pairs(CONFIG[key].ground[platform].positions) do
--                         if unit:inArea(p.RL.area) then
--                             area = p.RL.area
--                             break
--                         end
--                     end

--                     for _, section in pairs(CONFIG[key].ground[platform][field3]) do
--                         local ammoSec = SE_GetUnit({ guid = section.guid })

--                         if ammoSec and area and ammoSec:inArea(area) then
--                             return { isMet = true, battery = battery }
--                         end
--                     end
--                 end
--             end
--         end
--     end

--     return { isMet = false, battery = nil }
-- end

-- function IsMetWithAmmo(CONFIG, unit, platform, isRepositioningAutomatically)
--     local side = unit.side
--     local key = 't'

--     if side == 'China' then
--         key = 'c'
--     end

--     if unit.group then
--         local group = SE_GetUnit({ guid = unit.group.guid })

--         if group then
--             for _, section in pairs(CONFIG[key].ground[platform].ammunitionSections) do
--                 local isTrue = true

--                 if isRepositioningAutomatically then
--                     isTrue = section.state == CONFIG.batteryState.REPOSITIONING or
--                         section.state == CONFIG.batteryState.RELOAD
--                 end

--                 if section.guid == group.guid and isTrue then
--                     local ammo = SE_GetUnit({ guid = section.ammunition })

--                     for _, p in pairs(CONFIG[key].ground[platform].positions) do
--                         local isMetWithAmmo = unit:inArea(p.AHA.area) and (ammo and ammo:inArea(p.AHA.area))

--                         if isMetWithAmmo then
--                             return { isMet = true, battery = section }
--                         end
--                     end
--                 end
--             end
--         end
--     end

--     return { isMet = false, battery = nil }
-- end

-- Check if a unit has met with ammo trucks
function IsMetWithAmmoTrucks(saveData, unit, platform, isRepositioningAutomatically)
  -- Get unit's side and corresponding config field
  local side = unit.side
  local field = (side == 'China') and 'c' or 't'

  -- If unit has no group, return not met
  if not unit.group then
    return { isMet = false, battery = nil }
  end

  -- Get the unit's group
  local group = SE_GetUnit({ guid = unit.group.guid })
  if not group then return { isMet = false, battery = nil } end

  -- Determine field names based on group name
  local batteryField, ammunitionField = 'batteries', 'ammunitionSections'
  if string.find(group.name, 'Ammo') or string.find(group.name, 'SUPP') then
    batteryField, ammunitionField = 'ammunitionSections', 'batteries'
  end

  -- Get configuration information
  local platforms = saveData[field]['ground'][platform]
  local config = CONFIG[field]['ground'][platform]

  -- Iterate through batteries
  for _, battery in pairs(platforms[batteryField]) do
    -- Check if conditions are met
    local isStateValid = true
    if isRepositioningAutomatically then
      local repoState = CONFIG.batteryState.REPOSITIONING
      local reloadState = CONFIG.batteryState.RELOAD
      isStateValid = (battery.state == repoState or battery.state == reloadState)
    end

    -- If matching group found and state is valid
    if battery.guid == group.guid and isStateValid then
      -- Find the area where unit is located
      local area = FindUnitArea(unit, config.positions)
      if not area then
        return { isMet = false, battery = nil }
      end

      -- Check if ammo is in the same area
      for _, section in pairs(platforms[ammunitionField]) do
        local ammoSec = SE_GetUnit({ guid = section.guid })
        if ammoSec and ammoSec:inArea(area) then
          return { isMet = true, battery = battery }
        end
      end
    end
  end

  return { isMet = false, battery = nil }
end

-- Check if a unit has met with ammo
function IsMetWithAmmo(saveData, unit, platform, isRepositioningAutomatically)
  -- Get unit's side and corresponding config field
  local side = unit.side
  local field = (side == 'China') and 'c' or 't'

  -- If unit has no group, return not met
  if not unit.group then return { isMet = false, battery = nil } end

  -- Get the unit's group
  local group = SE_GetUnit({ guid = unit.group.guid })
  if not group then return { isMet = false, battery = nil } end

  -- Get configuration information
  local platfroms = saveData[field]['ground'][platform]
  local config = CONFIG[field]['ground'][platform]

  -- Iterate through ammunition sections
  for _, section in pairs(platfroms.ammunitionSections) do
    -- Check if conditions are met
    local isStateValid = true
    if isRepositioningAutomatically then
      local repoState = CONFIG.batteryState.REPOSITIONING
      local reloadState = CONFIG.batteryState.RELOAD
      isStateValid = (section.state == repoState or section.state == reloadState)
    end

    -- If matching group found and state is valid
    if section.guid == group.guid and isStateValid then
      local ammo = SE_GetUnit({ guid = section.ammunition })

      -- Check if unit and ammo are in the same area
      for _, p in pairs(config.positions) do
        local isInSameArea = unit:inArea(p.AHA.area) and (ammo and ammo:inArea(p.AHA.area))
        if isInSameArea then
          return { isMet = true, battery = section }
        end
      end
    end
  end

  return { isMet = false, battery = nil }
end

-- Helper function: Find the area where a unit is located
function FindUnitArea(unit, positions)
  for _, p in pairs(positions) do
    if unit:inArea(p.RL.area) then
      return p.RL.area
    end
  end
  return nil
end

function DestroyAmmoSecHandler(unit, side, platform, saveData)
  local field = (side == 'China') and 'c' or 't'
  local isAmmo = false
  if unit.group == nil then isAmmo = true end

  if isAmmo then
    local ammo = saveData[field].ground[platform].ammunitions[unit.guid]

    if ammo and ammo.wpnCurrent > 0 then
      ammo.wpnCurrent = 0
    end
  else
    local ammoSec = saveData[field].ground[platform].ammunitionSections[unit.group.guid]

    if ammoSec and ammoSec.wpnCurrent > 0 then
      if (ammoSec.wpnCurrent - ammoSec.wpnDefault / ammoSec.unitCount) < 0 then
        ammoSec.wpnCurrent = 0
      else
        ammoSec.wpnCurrent = ammoSec.wpnCurrent - ammoSec.wpnDefault / ammoSec.unitCount
      end
    end
  end
end
