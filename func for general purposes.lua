-- RenameUnitsFromBase('6Z8LM5-0HMIJ3QGCRQ5F', 12, 683, '603rd Air Cavalry Bde')
---@param fromUnit string
---@param num number
---@param weaponDBID number
---@param name string
function RenameUnitsFromBase(fromUnit, num, weaponDBID, name)
  local base = ScenEdit_GetUnit({ guid = fromUnit })
  if base == nil then return end
  local platforms = base.embarkedUnits['Aircraft']
  if platforms == nil then return end
  local filteredPlatforms = {}

  for _, v in ipairs(platforms) do
    local unit = SE_GetUnit({ guid = v })

    if unit then
      local weapons = ScenEdit_GetLoadout({ unitname = unit.guid }).weapons

      if weapons then
        for _, w in ipairs(weapons) do
          if w["wpn_dbid"] == weaponDBID and w["wpn_current"] > 0 then
            table.insert(filteredPlatforms, unit)
          end
        end
      end
    end

    if GetCount(filteredPlatforms) >= num then
      break
    end
  end

  for k, unit in ipairs(filteredPlatforms) do
    unit.name = name .. ' #' .. tostring(k)
  end
end

---@param fromUnit string
---@param platformType string
---@param platformDBID number
---@param missions table<number, string>
function AssignEmbarkedUnitsToMissions(fromUnit, platformType, platformDBID, missions)
  local base = ScenEdit_GetUnit({ guid = fromUnit })
  if base == nil then return end
  local platforms = base.embarkedUnits[platformType]
  local filteredPlatforms = {}

  for _, value in ipairs(platforms) do
    local unit = SE_GetUnit({ guid = value })
    if unit ~= nil and unit.dbid == platformDBID then
      unit.manualSpeed = 'OFF'
      table.insert(filteredPlatforms, unit)
    end
  end

  for _, mission in ipairs(missions) do
    local count = 0

    for idx, unit in ipairs(filteredPlatforms) do
      if count >= mission.num then break end

      if mission.loadoutId == 0 then
        if not unit.mission then
          ScenEdit_AssignUnitToMission(unit.guid, mission.name)
          count = count + 1
        end
      else
        if unit.loadoutdbid == mission.loadoutId and not unit.mission then
          ScenEdit_AssignUnitToMission(unit.guid, mission.name)
          count = count + 1
        end
      end
    end
  end
end

---@param fromUnit string
---@param num number
---@param weaponDBID number | 0
---@param unitDBID number | nil
---@param missionName string
---@param isEscort boolean
---@param course? CMO__TableOfWaypoints|nil
function AssignEmbarkedUnitToStrikeMission(fromUnit, num, weaponDBID, unitDBID, missionName, isEscort, course)
  local airbase = ScenEdit_GetUnit({ guid = fromUnit })

  if airbase == nil then
    airbase = ScenEdit_GetUnit({ unitname = fromUnit })
  end

  if airbase == nil or airbase.embarkedUnits['Aircraft'] == nil then return end
  local m = ScenEdit_GetMission(airbase.side, missionName)
  if m == nil then return end
  m.isactive = false
  local temp = {}
  local count = 0

  for _, item in ipairs(airbase.embarkedUnits.Aircraft) do
    local unit = ScenEdit_GetUnit({ guid = item })
    if unit == nil then goto continue end

    local weapons = ScenEdit_GetLoadout({ unitname = unit.guid }).weapons
    local weaponNum = 0

    if weapons and #weapons > 0 then
      for _, w in ipairs(weapons) do
        if w["wpn_dbid"] == weaponDBID then weaponNum = w["wpn_current"] end
      end
    end

    if unit.readytime_v == 0 and unit.mission == nil and count < num and (weaponNum > 0 or unit.dbid == unitDBID) then
      -- if unit.readytime_v == 0 and count < num and (weaponNum > 0 or unit.dbid == unitDBID) then
      if isEscort then
        ScenEdit_AssignUnitToMission(unit.guid, missionName, true)
      else
        ScenEdit_AssignUnitToMission(unit.guid, missionName)
      end

      if course then unit.course = course end
      count = count + 1
      table.insert(temp, { unit = unit.guid })
      if count >= num then break end
    end

    ::continue::
  end
  if not m.isactive then m.isactive = true end
  return temp
end

-- ---@param contact CMO__Contact
-- ---@param qty number
-- ---@param batteries table<CONFIG__Battery>
-- ---@param btyIdx number
-- ---@param grpIdx number
-- ---@param weaponDBID? number|nil
-- ---@return table
-- function AttackContact(contact, qty, batteries, btyIdx, grpIdx, weaponDBID)
--     local launchedNum = 0
--     local count = 0
--     if btyIdx == nil then btyIdx = 1 end
--     if grpIdx == nil then grpIdx = 1 end

--     while btyIdx <= #batteries do
--         local group = ScenEdit_GetUnit({ guid = batteries[btyIdx].guid })

--         if group then
--             -- determine if it's a group or unit
--             if group.group then
--                 while grpIdx <= #group.group.unitlist do
--                     local guid = group.group.unitlist[grpIdx]
--                     local unit = ScenEdit_GetUnit({ guid = guid })

--                     if unit then
--                         local totalWpnCurrentNum = 0
--                         local totalWpnDefaultNum = 0
--                         local totalQtyAssigned = 0
--                         local toatalQtyFired = 0
--                         local defaultNum = 1
--                         local mountDBID = unit.mounts[1]['mount_dbid']
--                         local mountIndex = 1
--                         local wpnIndex = 1
--                         local isHold = ScenEdit_GetDoctrine({ guid = guid }).weapon_control_status_land == 2
--                             or ScenEdit_GetDoctrine({ guid = guid }).weapon_control_status_land == '2'

--                         for _, mount in ipairs(unit.mounts) do
--                             for wpnIdx, wpn in ipairs(mount['mount_weapons']) do
--                                 if wpn['wpn_dbid'] == weaponDBID then
--                                     wpnIndex = wpnIdx
--                                     mountIndex = _
--                                     mountDBID = mount['mount_dbid']
--                                     totalWpnCurrentNum = totalWpnCurrentNum + wpn['wpn_current']
--                                     totalWpnDefaultNum = totalWpnDefaultNum + wpn['wpn_maxcap']
--                                 end
--                             end
--                         end

--                         if weaponDBID == nil then
--                             weaponDBID = unit.mounts[mountIndex]['mount_weapons'][wpnIndex]['wpn_dbid']
--                         end

--                         for _, item in ipairs(ScenEdit_WeaponAllocation(guid, '', '')) do
--                             totalQtyAssigned = totalQtyAssigned + item.qtyAssigned
--                             toatalQtyFired = toatalQtyFired + item.qtyFired
--                         end

--                         local isLessThanTotalWpnDefault = totalQtyAssigned < totalWpnDefaultNum
--                         -- local isCurrentQtyMoreThan = totalWpnCurrentNum > totalQtyAssigned
--                         local qtyAssignedOnTarget = 0
--                         local isQtyAssignedOnTargetMoreThan = false

--                         if #ScenEdit_WeaponAllocation('', contact.guid, group.side) > 0 then
--                             for index, item in ipairs(ScenEdit_WeaponAllocation('', contact.guid, group.side)) do
--                                 qtyAssignedOnTarget = qtyAssignedOnTarget + item.qtyAssigned
--                             end

--                             isQtyAssignedOnTargetMoreThan = qtyAssignedOnTarget >= qty
--                         end

--                         if totalWpnCurrentNum >= qty then
--                             defaultNum = qty
--                         else
--                             defaultNum = totalWpnCurrentNum
--                         end

--                         if totalWpnCurrentNum > 0 and not isHold and isLessThanTotalWpnDefault and not isQtyAssignedOnTargetMoreThan then
--                             local result = ScenEdit_AttackContact(
--                                 guid,
--                                 contact.guid,
--                                 { mode = '1', qty = defaultNum, mount = mountDBID, weapon = weaponDBID }
--                             )

--                             if result then launchedNum = launchedNum + defaultNum end
--                         end

--                         if (grpIdx + 1) > #group.group.unitlist then
--                             grpIdx = 1
--                             btyIdx = btyIdx + 1
--                         else
--                             grpIdx = grpIdx + 1
--                         end

--                         if btyIdx > #batteries then btyIdx = 1 end
--                         count = count + 1

--                         if launchedNum >= qty or count >= 50 then
--                             return { btyIdx = btyIdx, grpIdx = grpIdx, launchedNum = launchedNum }
--                         end
--                     end
--                 end
--             else
--                 local totalWpnCurrentNum = 0
--                 local totalWpnDefaultNum = 0
--                 local totalQtyAssigned = 0
--                 local toatalQtyFired = 0
--                 local defaultNum = 1
--                 local mountDBID = group.mounts[1]['mount_dbid']
--                 local mountIndex = 1
--                 local wpnIndex = 1
--                 local isHold = ScenEdit_GetDoctrine({ guid = group.guid }).weapon_control_status_land == 2
--                     or ScenEdit_GetDoctrine({ guid = group.guid }).weapon_control_status_land == '2'

--                 for _, mount in ipairs(group.mounts) do
--                     for wpnIdx, wpn in ipairs(mount['mount_weapons']) do
--                         if wpn['wpn_dbid'] == weaponDBID then
--                             wpnIndex = wpnIdx
--                             mountIndex = _
--                             mountDBID = mount['mount_dbid']
--                             totalWpnCurrentNum = totalWpnCurrentNum + wpn['wpn_current']
--                             totalWpnDefaultNum = totalWpnDefaultNum + wpn['wpn_maxcap']
--                         end
--                     end
--                 end

--                 if weaponDBID == nil then
--                     weaponDBID = group.mounts[mountIndex]['mount_weapons'][wpnIndex]['wpn_dbid']
--                 end

--                 for _, item in ipairs(ScenEdit_WeaponAllocation(group.guid, '', '')) do
--                     totalQtyAssigned = totalQtyAssigned + item.qtyAssigned
--                     toatalQtyFired = toatalQtyFired + item.qtyFired
--                 end

--                 local isLessThanTotalWpnDefault = totalQtyAssigned < totalWpnDefaultNum
--                 -- local isCurrentQtyMoreThan = totalWpnCurrentNum > totalQtyAssigned
--                 local isQtyAssignedOnTargetMoreThan = false
--                 local qtyAssignedOnTarget = 0

--                 if #ScenEdit_WeaponAllocation('', contact.guid, group.side) > 0 then
--                     for index, item in ipairs(ScenEdit_WeaponAllocation('', contact.guid, group.side)) do
--                         qtyAssignedOnTarget = qtyAssignedOnTarget + item.qtyAssigned
--                     end

--                     isQtyAssignedOnTargetMoreThan = qtyAssignedOnTarget >= qty
--                 end

--                 if totalWpnCurrentNum >= qty then
--                     defaultNum = qty
--                 else
--                     defaultNum = totalWpnCurrentNum
--                 end

--                 if totalWpnCurrentNum > 0 and not isHold and isLessThanTotalWpnDefault and not isQtyAssignedOnTargetMoreThan then
--                     local result = ScenEdit_AttackContact(
--                         group.guid,
--                         contact.guid,
--                         { mode = '1', qty = defaultNum, mount = mountDBID, weapon = weaponDBID }
--                     )

--                     if result then launchedNum = launchedNum + defaultNum end
--                 end

--                 btyIdx = btyIdx + 1
--                 if btyIdx > #batteries then btyIdx = 1 end
--                 count = count + 1

--                 if launchedNum >= qty or count >= 50 then
--                     return { btyIdx = btyIdx, grpIdx = grpIdx, launchedNum = launchedNum }
--                 end
--             end
--         else
--             break
--         end
--     end

--     return { btyIdx = btyIdx, grpIdx = grpIdx, launchedNum = 0 }
-- end

---Get weapon information for a unit
---@param unit table The unit to check
---@param weaponDBID number|nil Specific weapon DBID to look for
---@return table Weapon information
local function getWeaponInfo(unit, weaponDBID)
  local availableWeapons = 0
  local maxWeaponCapacity = 0
  local mountDBID = unit.mounts[1]['mount_dbid']
  local mountIndex = 1
  local wpnIndex = 1

  -- Find the specified weapon or use the first available weapon with ammo
  for mountIdx, mount in ipairs(unit.mounts) do
    for wpnIdx, wpn in ipairs(mount['mount_weapons']) do
      if (weaponDBID == nil and wpn['wpn_default'] > 0) or wpn['wpn_dbid'] == weaponDBID then
        wpnIndex = wpnIdx
        mountIndex = mountIdx
        mountDBID = mount['mount_dbid']
        availableWeapons = availableWeapons + wpn['wpn_current']
        maxWeaponCapacity = maxWeaponCapacity + wpn['wpn_maxcap']
      end
    end
  end

  -- If no weaponDBID was provided, use the one we found
  if weaponDBID == nil then
    weaponDBID = unit.mounts[mountIndex]['mount_weapons'][wpnIndex]['wpn_dbid']
  end

  -- Get currently assigned weapons
  local alreadyAllocatedWeapons = 0
  for _, item in ipairs(ScenEdit_WeaponAllocation(unit.guid, '', '')) do
    alreadyAllocatedWeapons = alreadyAllocatedWeapons + item.qtyAssigned
  end

  return {
    weaponDBID = weaponDBID,
    mountDBID = mountDBID,
    availableWeapons = availableWeapons,
    maxWeapons = maxWeaponCapacity,
    assignedWeapons = alreadyAllocatedWeapons
  }
end

---Get total ammunition already allocated for attacking a specific target
---@param contactGuid string The target contact's unique identifier
---@param side string The attacking side's name
---@return number Total ammunition currently allocated to attack this target
local function getAmmoAllocatedForTarget(contactGuid, side)
  local totalTargetAmmoCount = 0

  local weaponAllocations = ScenEdit_WeaponAllocation('', contactGuid, side)
  if #weaponAllocations > 0 then
    for _, allocation in ipairs(weaponAllocations) do
      totalTargetAmmoCount = totalTargetAmmoCount + allocation.qtyAssigned
    end
  end

  return totalTargetAmmoCount
end

---Check if a unit can fire at a contact
---@param unit table The unit to check
---@param contact table The target contact
---@param weaponInfo table Weapon information
---@param totalAmmoRequested number Total amount of ammunition requested for attack
---@return boolean Whether the unit can fire
local function canUnitFire(unit, contact, weaponInfo, totalAmmoRequested)
  -- Check if unit is on hold
  local doctrine = ScenEdit_GetDoctrine({ guid = unit.guid })
  local isHold = doctrine.weapon_control_status_land == 2 or doctrine.weapon_control_status_land == '2'

  if isHold then
    return false
  end

  -- Check if we have any weapons available
  if weaponInfo.availableWeapons <= 0 then
    printBox('China', 'func/AttackContact/No weapons available, no need to fire more')
    return false
  end

  -- Check if we've reached maximum weapon allocation
  if weaponInfo.assignedWeapons >= weaponInfo.maxWeapons then
    printBox('China', 'func/AttackContact/Maximum weapon allocation reached, no need to fire more')
    return false
  end

  -- Check if total weapons already allocated to this target meets requirements
  local totalAmmoAlreadyAllocatedForTarget = getAmmoAllocatedForTarget(contact.guid, unit.side)

  if totalAmmoAlreadyAllocatedForTarget >= totalAmmoRequested then
    printBox('China', 'func/AttackContact/Target already has sufficient weapons allocated, no need to fire more')
    return false     -- Target already has sufficient weapons allocated, no need to fire more
  end

  return true
end

---Process a group unit and attempt to allocate weapons for attack
---@param groupUnit table The group unit to process
---@param contact table The target contact
---@param totalAmmoRequested number Total amount of ammunition requested for this attack
---@param ammoAlreadyAllocated number Amount of ammunition already allocated in this attack
---@param weaponDBID number|nil Specific weapon DBID to use
---@param grpIdx number Current group index
---@return boolean Whether to advance to next battery
---@return number Number of weapons allocated
local function processUnitGroup(groupUnit, contact, totalAmmoRequested, ammoAlreadyAllocated, weaponDBID, grpIdx)
  local ammoAllocated = 0
  local advanceBattery = false

  -- Check if we have a valid unit at the current group index
  if grpIdx > #groupUnit.group.unitlist then
    return true, 0     -- Move to next battery, no weapons allocated
  end

  local guid = groupUnit.group.unitlist[grpIdx]
  local unit = ScenEdit_GetUnit({ guid = guid })

  if not unit then
    return true, 0     -- Unit not found, move to next, no weapons allocated
  end

  -- Find weapon info and check availability
  local weaponInfo = getWeaponInfo(unit, weaponDBID)
  weaponDBID = weaponInfo.weaponDBID   -- Use found weaponDBID if not provided

  -- Check if unit can fire
  if canUnitFire(unit, contact, weaponInfo, totalAmmoRequested) then
    -- Determine how many weapons to allocate for this attack
    local ammoNeeded = totalAmmoRequested - ammoAlreadyAllocated
    local ammoToAllocate = math.min(ammoNeeded, weaponInfo.availableWeapons)

    -- Attack the contact
    local result = ScenEdit_AttackContact(
      guid,
      contact.guid,
      { mode = '1', qty = ammoToAllocate, mount = weaponInfo.mountDBID, weapon = weaponDBID }
    )

    if result then
      ammoAllocated = ammoToAllocate
    end
  end

  -- Check if this was the last unit in the group
  if grpIdx >= #groupUnit.group.unitlist then
    advanceBattery = true
  end

  return advanceBattery, ammoAllocated
end

---Process a single unit and attempt to allocate weapons for attack
---@param unit table The unit to process
---@param contact table The target contact
---@param totalAmmoRequested number Total amount of ammunition requested for this attack
---@param weaponDBID number|nil Specific weapon DBID to use
---@return table Results including allocated weapons
local function processSingleUnit(unit, contact, totalAmmoRequested, weaponDBID)
  -- Find weapon info and check availability
  local weaponInfo = getWeaponInfo(unit, weaponDBID)
  weaponDBID = weaponInfo.weaponDBID   -- Use found weaponDBID if not provided

  -- Check if unit can fire
  if canUnitFire(unit, contact, weaponInfo, totalAmmoRequested) then
    -- Determine how many weapons to allocate for this attack
    local ammoToAllocate = math.min(totalAmmoRequested, weaponInfo.availableWeapons)

    -- Attack the contact
    local result = ScenEdit_AttackContact(
      unit.guid,
      contact.guid,
      { mode = '1', qty = ammoToAllocate, mount = weaponInfo.mountDBID, weapon = weaponDBID }
    )

    if result then
      return { ammoAllocated = ammoToAllocate }
    end
  end

  return { ammoAllocated = 0 }
end

---@param contact CMO__Contact The target contact to attack
---@param ammoToAllocate number Total amount of ammunition to allocate for this attack
---@param batteries table<CONFIG__Battery> Array of batteries to use for attack
---@param btyIdx number Starting battery index
---@param grpIdx number Starting group index
---@param weaponDBID? number|nil Optional specific weapon DBID to use
---@return table Results including next indices and number of weapons launched
function AttackContact(contact, ammoToAllocate, batteries, btyIdx, grpIdx, weaponDBID, side)
  -- Initialize variables
  local totalAmmoAllocated = 0
  local attemptCount = 0
  local maxAttempts = 50

  -- Set default values if not provided
  btyIdx = btyIdx or 1
  grpIdx = grpIdx or 1

  -- Process each battery until we've allocated enough ammo or tried all batteries
  while btyIdx <= #batteries and totalAmmoAllocated < ammoToAllocate and attemptCount < maxAttempts do
    local actualUnit = ScenEdit_GetUnit({ guid = batteries[btyIdx].guid })

    if not actualUnit then
      side = (side == nil) and 'China' or 'Taiwan'
      actualUnit = ScenEdit_GetUnit({ side = side, unitname = batteries[btyIdx].name })
      -- break -- Battery not found, exit loop
      if not actualUnit then break end
    end

    -- Handle differently based on whether it's a group or individual unit
    if actualUnit.group then
      -- Track if we need to advance to next battery
      local advanceBattery, ammoAllocated = processUnitGroup(
        actualUnit, contact, ammoToAllocate, totalAmmoAllocated, weaponDBID, grpIdx
      )

      -- Update our tracking variables
      totalAmmoAllocated = totalAmmoAllocated + ammoAllocated
      attemptCount = attemptCount + 1       -- Count each unit processing as one attempt

      if advanceBattery then
        btyIdx = btyIdx + 1
        grpIdx = 1
      else
        grpIdx = grpIdx + 1
      end

      -- Wrap around to first battery if needed
      if btyIdx > #batteries then btyIdx = 1 end

      -- Check if we've allocated enough ammo
      if totalAmmoAllocated >= ammoToAllocate then
        break
      end
    else
      -- Handle single unit
      local unitResult = processSingleUnit(actualUnit, contact, ammoToAllocate, weaponDBID)
      totalAmmoAllocated = totalAmmoAllocated + unitResult.ammoAllocated
      attemptCount = attemptCount + 1

      -- Move to next battery
      btyIdx = btyIdx + 1
      if btyIdx > #batteries then btyIdx = 1 end

      -- Check if we've allocated enough ammo
      if totalAmmoAllocated >= ammoToAllocate then
        break
      end
    end
  end

  return { btyIdx = btyIdx, grpIdx = grpIdx, ammoAllocated = totalAmmoAllocated }
end

function AttackContacts(contacts, qty, batteries, weaponDBID)
  local result = { btyIdx = 1, grpIdx = 1, launchedNum = 0 }
  local totalLaunchedNum = 0

  for _, contact in ipairs(contacts) do
    result = AttackContact(
      contact,
      qty,
      batteries,
      result.btyIdx,
      result.grpIdx,
      weaponDBID
    )

    totalLaunchedNum = totalLaunchedNum + result.ammoAllocated
  end

  return totalLaunchedNum
end

---@param side string
---@param missionName string
---@return table<number, CONFIG__TargetList>
function InitTargetList(side, missionName)
  local m = ScenEdit_GetMission(side, missionName)
  local temp = {}
  if m == nil then return temp end

  for _, value in ipairs(m.targetlist) do
    ---@class CONFIG__TargetList
    ---@field guid string
    ---@field strikeTimes number
    table.insert(temp, { guid = value, strikeTimes = 0 })
  end

  return temp
end

function GetOODA(d)
  return {
    detection = math.random(10 * d, 30 * d),
    targeting = math.random(20 * d, 20 * d),
    evasion = math.random(90 * d, 120 * d)
  }
end

function CircularRandomPosition(x_latitude, x_longitude, max_radius)
  local randomisationCircle = World_GetCircleFromPoint({
    latitude = x_latitude,
    longitude = x_longitude,
    radius = (math.random(0, max_radius * 10) / 10),
    numpoints = 72
  })
  local randomisedPoint = randomisationCircle[math.random(1, #randomisationCircle)]
  return randomisedPoint
end

function RandomTxt(numLetters)
  local totTxt = ""
  for i = 1, numLetters do
    totTxt = totTxt .. string.char(math.random(65, 90))
  end
  return totTxt
end

---@param list table
---@return number
function GetCount(list)
  if list == nil then return 0 end
  local count = 0

  for k, v in pairs(list) do
    count = count + 1
  end

  return count
end

---@param list table
---@param insertedList table
function InsertList(list, insertedList)
  local count = GetCount(insertedList)

  for i = 1, count, 1 do
    table.insert(list, insertedList[i])
  end

  return list
end

-- 定義函數：printBox
-- 參數：strings - 一個包含多個字串的 table
function printBox(side, ...)
  -- 收集所有字串參數到陣列中
  local strings = { ... }

  -- 找出最長字串的長度
  local maxLen = 0
  for _, str in ipairs(strings) do
    if #str > maxLen then
      maxLen = #str
    end
  end

  -- 計算邊框寬度
  local width = 70

  -- 構建頂部和底部邊框：連續的 -
  local border = string.rep("-", width)

  -- 構建中間行
  local middleLines = {}
  for _, str in ipairs(strings) do
    -- 構建中間行：| 空格 字串
    local middle = "| " .. str
    table.insert(middleLines, middle)
  end

  -- 組合成一個單一的字串
  local boxString = border .. "\n" .. table.concat(middleLines, "\n") .. "\n" .. border

  -- 一次性輸出
  ScenEdit_SpecialMessage(side, boxString)
end
