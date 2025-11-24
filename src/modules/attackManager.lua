local GameApi = require("src.utils.gameApi")
local Logger = require("src.utils.logger")

--- Attack Manager
---
--- Coordinates weapon allocation and attack execution against contacts with multi-unit support
local AttackManager = {}

---Get weapon information for a unit
---@param unit CMO__Unit The unit to check
---@param weaponDBID number|nil Specific weapon DBID to look for
---@return {weaponDBID: number, mountDBID: number, availableWeapons: number, maxWeapons: number, assignedWeapons: number} # Weapon information
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
  local weaponAllocations = GameApi.ScenEdit_WeaponAllocation(unit.guid, '', '')

  if not weaponAllocations then
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
---@return number # Total ammunition currently allocated to attack this target
local function getAmmoAllocatedForTarget(contactGuid, side)
  local totalTargetAmmoCount = 0

  local weaponAllocations = GameApi.ScenEdit_WeaponAllocation('', contactGuid, side)

  if not weaponAllocations then
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
---@return boolean # Whether the unit can fire
local function canUnitFire(unit, contact, weaponInfo, totalAmmoRequested)
  -- Check if unit is on hold
  local doctrine = GameApi.ScenEdit_GetDoctrine(unit.guid)

  if not doctrine then
    return false
  end

  local isHold = doctrine.weapon_control_status_land == 2 or doctrine.weapon_control_status_land == '2'

  if isHold then
    return false
  end

  -- Check if we have any weapons available
  if weaponInfo.availableWeapons <= 0 then
    Logger.log("attackManager", 'No weapons available, no need to fire more')
    return false
  end

  -- Check if we've reached maximum weapon allocation
  if weaponInfo.assignedWeapons >= weaponInfo.maxWeapons then
    Logger.log("attackManager", 'Maximum weapon allocation reached, no need to fire more')
    return false
  end

  -- Check if total weapons already allocated to this target meets requirements
  local totalAmmoAlreadyAllocatedForTarget = getAmmoAllocatedForTarget(contact.guid, unit.side)

  if totalAmmoAlreadyAllocatedForTarget >= totalAmmoRequested then
    Logger.log("attackManager", 'Target already has sufficient weapons allocated, no need to fire more')
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
---@return boolean success Whether to advance to next battery
---@return number weaponsAllocated Number of weapons allocated
local function processUnitGroup(groupUnit, contact, totalAmmoRequested, ammoAlreadyAllocated, weaponDBID, grpIdx)
  local ammoAllocated = 0
  local advanceBattery = false

  -- Check if we have a valid unit at the current group index
  if grpIdx > #groupUnit.group.unitlist then
    return true, 0 -- Move to next battery, no weapons allocated
  end

  local guid = groupUnit.group.unitlist[grpIdx]
  local unit = GameApi.ScenEdit_GetUnit(guid)

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
    local result = GameApi.ScenEdit_AttackContact(
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
---@param unit CMO__Unit The unit to process
---@param contact CMO__Contact The target contact
---@param totalAmmoRequested number Total amount of ammunition requested for this attack
---@param weaponDBID number Specific weapon DBID to use
---@return table # Results including allocated weapons
local function processSingleUnit(unit, contact, totalAmmoRequested, weaponDBID)
  -- Find weapon info and check availability
  local weaponInfo = getWeaponInfo(unit, weaponDBID)
  weaponDBID = weaponInfo.weaponDBID -- Use found weaponDBID if not provided

  -- Check if unit can fire
  if canUnitFire(unit, contact, weaponInfo, totalAmmoRequested) then
    -- Determine how many weapons to allocate for this attack
    local ammoToAllocate = math.min(totalAmmoRequested, weaponInfo.availableWeapons)

    -- Attack the contact
    local result = GameApi.ScenEdit_AttackContact(
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

---Attack a single contact with weapon allocation from firing units
---@param contactGUID string The target contact to attack
---@param ammoToAllocate number Total amount of ammunition to allocate for this attack
---@param firingUnits table<string, SBJ__FiringUnitContext> Array of firing units to use for attack
---@param btyIdx number Starting firing unit index
---@param grpIdx number Starting group index
---@param weaponDBID number|nil Specific weapon DBID to use, defaults to nil
---@param side string The side to use for the attack, default is 'China'
---@return table # Results including next indices and number of weapons launched
function AttackManager.attackContact(contactGUID, ammoToAllocate, firingUnits, btyIdx, grpIdx, weaponDBID, side)
  -- Initialize variables
  local totalAmmoAllocated = 0
  local attemptCount = 0
  local maxAttempts = 50

  local contact = GameApi.ScenEdit_GetContact(side, contactGUID)

  if contact == nil then
    Logger.error("AttackContact: Contact not found with GUID: " .. tostring(contactGUID))
  else
    -- Set default values if not provided
    btyIdx = btyIdx or 1
    grpIdx = grpIdx or 1

    -- Process each firing unit until we've allocated enough ammo or tried all firing units
    while btyIdx <= #firingUnits and totalAmmoAllocated < ammoToAllocate and attemptCount < maxAttempts do
      local actualUnit = GameApi.ScenEdit_GetUnit(firingUnits[btyIdx].guid)
      local wpnDBID = weaponDBID or firingUnits[btyIdx].weaponDBID

      if not actualUnit then
        actualUnit = GameApi.ScenEdit_GetUnit(firingUnits[btyIdx].name, side)
        if not actualUnit then break end
      end

      -- Handle differently based on whether it's a group or individual unit
      if actualUnit.group then
        -- Track if we need to advance to next firing unit
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

        -- Wrap around to first firing unit if needed
        if btyIdx > #firingUnits then btyIdx = 1 end

        -- Check if we've allocated enough ammo
        if totalAmmoAllocated >= ammoToAllocate then
          break
        end
      else
        -- Handle single unit
        local unitResult = processSingleUnit(actualUnit, contact, ammoToAllocate, wpnDBID)
        totalAmmoAllocated = totalAmmoAllocated + unitResult.ammoAllocated
        attemptCount = attemptCount + 1

        -- Move to next firing unit
        btyIdx = btyIdx + 1
        if btyIdx > #firingUnits then btyIdx = 1 end

        -- Check if we've allocated enough ammo
        if totalAmmoAllocated >= ammoToAllocate then
          break
        end
      end
    end
  end

  return { btyIdx = btyIdx, grpIdx = grpIdx, ammoAllocated = totalAmmoAllocated }
end

---Attack multiple contacts with weapon allocation from firing units
---@param opts SBJ__AttackContacts_Params Attack parameters
---@return number # Total number of ammunition launched across all contacts
function AttackManager.attackContacts(opts)
  local result = { btyIdx = 1, grpIdx = 1, launchedNum = 0 }
  local totalLaunchedNum = 0
  local contacts = opts.contacts or {}
  local qty = opts.qty or 1
  local firingUnits = opts.firingUnits
  local weaponDBID = opts.weaponDBID
  local side = opts.side or 'China'

  for _, contact in ipairs(contacts) do
    result = AttackManager.attackContact(
      contact,
      qty,
      firingUnits,
      result.btyIdx,
      result.grpIdx,
      weaponDBID,
      side
    )

    totalLaunchedNum = totalLaunchedNum + result.ammoAllocated
  end

  return totalLaunchedNum
end

return AttackManager
