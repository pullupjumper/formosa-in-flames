GameApi = require("src.utils.gameApi")
Logger = require("src.utils.logger")
SafeCall = require("src.utils.utils").SafeCall

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
---@param unit CMO__Unit The unit to check
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
  local weaponAllocations, err = SafeCall(
    "GameApi.ScenEdit_WeaponAllocation",
    GameApi.ScenEdit_WeaponAllocation,
    unit.guid,
    '',
    ''
  )

  if err then
    Logger.error(err)
    weaponAllocations = {}
  end

  for _, item in ipairs(weaponAllocations) do
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

  local weaponAllocations, err = SafeCall(
    "GameApi.ScenEdit_WeaponAllocation",
    GameApi.ScenEdit_WeaponAllocation,
    '',
    contactGuid,
    side
  )

  if err then
    Logger.error(err)
    weaponAllocations = {}
  end

  if weaponAllocations and #weaponAllocations > 0 then
    for _, allocation in ipairs(weaponAllocations) do
      totalTargetAmmoCount = totalTargetAmmoCount + allocation.qtyAssigned
    end
  end

  return totalTargetAmmoCount
end

---Check if a unit can fire at a contact
---@param unit CMO__Unit The unit to check
---@param contact CMO__Contact The target contact
---@param weaponInfo table Weapon information
---@param totalAmmoRequested number Total amount of ammunition requested for attack
---@return boolean Whether the unit can fire
local function canUnitFire(unit, contact, weaponInfo, totalAmmoRequested)
  -- Check if unit is on hold
  local doctrine, err = SafeCall("GameApi.ScenEdit_GetDoctrine", GameApi.ScenEdit_GetDoctrine, unit.guid)

  if err then
    Logger.error(err)
    return false
  end

  local isHold = doctrine.weapon_control_status_land == 2 or doctrine.weapon_control_status_land == '2'

  if isHold then
    return false
  end

  -- Check if we have any weapons available
  if weaponInfo.availableWeapons <= 0 then
    Logger.log('func/AttackContact/No weapons available, no need to fire more')
    return false
  end

  -- Check if we've reached maximum weapon allocation
  if weaponInfo.assignedWeapons >= weaponInfo.maxWeapons then
    Logger.log('func/AttackContact/Maximum weapon allocation reached, no need to fire more')
    return false
  end

  -- Check if total weapons already allocated to this target meets requirements
  local totalAmmoAlreadyAllocatedForTarget = getAmmoAllocatedForTarget(contact.guid, unit.side)

  if totalAmmoAlreadyAllocatedForTarget >= totalAmmoRequested then
    Logger.log('func/AttackContact/Target already has sufficient weapons allocated, no need to fire more')
    return false -- Target already has sufficient weapons allocated, no need to fire more
  end

  return true
end

---Process a group unit and attempt to allocate weapons for attack
---@param groupUnit CMO__Unit The group unit to process
---@param contact CMO__Contact The target contact
---@param totalAmmoRequested number Total amount of ammunition requested for this attack
---@param ammoAlreadyAllocated number Amount of ammunition already allocated in this attack
---@param weaponDBID number Specific weapon DBID to use
---@param grpIdx number Current group index
---@return boolean Whether to advance to next battery
---@return number Number of weapons allocated
local function processUnitGroup(groupUnit, contact, totalAmmoRequested, ammoAlreadyAllocated, weaponDBID, grpIdx)
  local ammoAllocated = 0
  local advanceBattery = false

  -- Check if we have a valid unit at the current group index
  if grpIdx > #groupUnit.group.unitlist then
    return true, 0 -- Move to next battery, no weapons allocated
  end

  local guid = groupUnit.group.unitlist[grpIdx]
  local unit, err = SafeCall("GameApi.ScenEdit_GetUnit", GameApi.ScenEdit_GetUnit, guid)

  if err then
    Logger.error(err)
  end

  if not unit then
    return true, 0 -- Unit not found, move to next, no weapons allocated
  end

  -- Find weapon info and check availability
  local weaponInfo = getWeaponInfo(unit, weaponDBID)
  weaponDBID = weaponInfo.weaponDBID -- Use found weaponDBID if not provided

  -- Check if unit can fire
  if canUnitFire(unit, contact, weaponInfo, totalAmmoRequested) then
    -- Determine how many weapons to allocate for this attack
    local ammoNeeded = totalAmmoRequested - ammoAlreadyAllocated
    local ammoToAllocate = math.min(ammoNeeded, weaponInfo.availableWeapons)

    -- Attack the contact
    local result, err = SafeCall("GameApi.ScenEdit_AttackContact", GameApi.ScenEdit_AttackContact,
      guid,
      contact.guid,
      { mode = '1', qty = ammoToAllocate, mount = weaponInfo.mountDBID, weapon = weaponDBID }
    )

    if err then
      Logger.error(err)
    end

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
---@param unit CMO__Unit The unit to process
---@param contact CMO__Contact The target contact
---@param totalAmmoRequested number Total amount of ammunition requested for this attack
---@param weaponDBID number Specific weapon DBID to use
---@return table Results including allocated weapons
local function processSingleUnit(unit, contact, totalAmmoRequested, weaponDBID)
  -- Find weapon info and check availability
  local weaponInfo = getWeaponInfo(unit, weaponDBID)
  weaponDBID = weaponInfo.weaponDBID -- Use found weaponDBID if not provided

  -- Check if unit can fire
  if canUnitFire(unit, contact, weaponInfo, totalAmmoRequested) then
    -- Determine how many weapons to allocate for this attack
    local ammoToAllocate = math.min(totalAmmoRequested, weaponInfo.availableWeapons)

    -- Attack the contact
    local result, err = SafeCall("GameApi.ScenEdit_AttackContact", GameApi.ScenEdit_AttackContact,
      unit.guid,
      contact.guid,
      { mode = '1', qty = ammoToAllocate, mount = weaponInfo.mountDBID, weapon = weaponDBID }
    )

    if err then
      Logger.error(err)
    end

    if result then
      return { ammoAllocated = ammoToAllocate }
    end
  end

  return { ammoAllocated = 0 }
end

---@param contactGUID string The target contact to attack
---@param ammoToAllocate number Total amount of ammunition to allocate for this attack
---@param batteries table<string, SBJ__Battery> Array of batteries to use for attack
---@param btyIdx number Starting battery index
---@param grpIdx number Starting group index
---@param weaponDBID number|nil Specific weapon DBID to use, defaults to nil
---@param side string The side to use for the attack, default is 'China'
---@return table Results including next indices and number of weapons launched
function AttackContact(contactGUID, ammoToAllocate, batteries, btyIdx, grpIdx, weaponDBID, side)
  -- Initialize variables
  -- side = (side == nil) and 'China' or 'Taiwan'
  local totalAmmoAllocated = 0
  local attemptCount = 0
  local maxAttempts = 50

  local contact, err = SafeCall("GameApi.ScenEdit_GetContact", GameApi.ScenEdit_GetContact, side, contactGUID)
  -- if err then
  --   Logger.error(err)
  -- end

  if contact == nil then
    Logger.error("AttackContact: Contact not found with GUID: " .. tostring(contactGUID))
  else
    -- Set default values if not provided
    btyIdx = btyIdx or 1
    grpIdx = grpIdx or 1

    -- Process each battery until we've allocated enough ammo or tried all batteries
    while btyIdx <= #batteries and totalAmmoAllocated < ammoToAllocate and attemptCount < maxAttempts do
      local actualUnit, err = SafeCall("GameApi.ScenEdit_GetUnit", GameApi.ScenEdit_GetUnit, batteries[btyIdx].guid)
      local wpnDBID = weaponDBID or batteries[btyIdx].weaponDBID

      if err then
        Logger.error(err)
      end

      if not actualUnit then
        actualUnit, err = SafeCall("GameApi.ScenEdit_GetUnit", GameApi.ScenEdit_GetUnit, batteries[btyIdx].name, side)
        if err then
          Logger.error(err)
        end
        -- break -- Battery not found, exit loop
        if not actualUnit then break end
      end

      -- Handle differently based on whether it's a group or individual unit
      if actualUnit.group then
        -- Track if we need to advance to next battery
        local advanceBattery, ammoAllocated = processUnitGroup(
          actualUnit, contact, ammoToAllocate, totalAmmoAllocated, wpnDBID, grpIdx
        )

        -- Update our tracking variables
        totalAmmoAllocated = totalAmmoAllocated + ammoAllocated
        attemptCount = attemptCount + 1 -- Count each unit processing as one attempt

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
        local unitResult = processSingleUnit(actualUnit, contact, ammoToAllocate, wpnDBID)
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
  end

  return { btyIdx = btyIdx, grpIdx = grpIdx, ammoAllocated = totalAmmoAllocated }
end

---@param opts SBJ__AttackContacts_Params
---@return number Total number of ammunition launched across all contacts
function AttackContacts(opts)
  local result = { btyIdx = 1, grpIdx = 1, launchedNum = 0 }
  local totalLaunchedNum = 0
  local contacts = opts.contacts or {}
  local qty = opts.qty or 1
  local batteries = opts.batteries
  local weaponDBID = opts.weaponDBID
  local side = opts.side or 'China'

  for _, contact in ipairs(contacts) do
    result = AttackContact(
      contact,
      qty,
      batteries,
      result.btyIdx,
      result.grpIdx,
      weaponDBID,
      side
    )

    totalLaunchedNum = totalLaunchedNum + result.ammoAllocated
  end

  return totalLaunchedNum
end

-- 導出模組的公共函數和內部函數以便測試
return {
  AttackContact = AttackContact,
  AttackContacts = AttackContacts,
  getWeaponInfo = getWeaponInfo,
  getAmmoAllocatedForTarget = getAmmoAllocatedForTarget,
  canUnitFire = canUnitFire,
  processUnitGroup = processUnitGroup,
  processSingleUnit = processSingleUnit,
}
