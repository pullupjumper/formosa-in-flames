local GameApi = require("src.utils.gameApi")
local Logger = require("src.utils.logger")
local GameUtils = require("src.utils.gameUtils")
local constants = require("src.core.constants")

local AttackManager = {}

---Get total ammunition already allocated for attacking a specific target
---@param contactGUID string The target contact's unique identifier
---@param sideName string The attacking side's name
---@return integer # Total ammunition currently allocated to attack this target
local function getAmmoAllocatedForTarget(contactGUID, sideName)
  local totalTargetAmmoCount = 0
  local weaponAllocations = GameApi.ScenEdit_WeaponAllocation("", contactGUID, sideName)

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
---@param weaponInfo {weaponDBID: number, mountDBID: number, availableWeapons: integer, maxWeapons: integer, assignedWeapons: integer} Weapon information
---@param totalAmmoRequested integer Total amount of ammunition requested for attack
---@return boolean # Whether the unit can fire
local function canUnitFire(unit, contact, weaponInfo, totalAmmoRequested)
  -- Check if unit is on hold
  local doctrine = GameApi.ScenEdit_GetDoctrine(unit.guid)

  if not doctrine then
    return false
  end

  local isHold = doctrine.weapon_control_status_land == 2 or doctrine.weapon_control_status_land == "2"

  if isHold then
    return false
  end

  -- Check if we have any weapons available
  if weaponInfo.availableWeapons <= 0 then
    Logger.log(constants.TAGS.ATTACK_MANAGER, "No weapons available, no need to fire more")
    return false
  end

  -- Check if we've reached maximum weapon allocation
  if weaponInfo.assignedWeapons >= weaponInfo.maxWeapons then
    Logger.log(constants.TAGS.ATTACK_MANAGER, "Maximum weapon allocation reached, no need to fire more")
    return false
  end

  -- Check if total weapons already allocated to this target meets requirements
  local totalAmmoAlreadyAllocatedForTarget = getAmmoAllocatedForTarget(contact.guid, unit.side)

  if totalAmmoAlreadyAllocatedForTarget >= totalAmmoRequested then
    Logger.log(constants.TAGS.ATTACK_MANAGER, "Target already has sufficient weapons allocated, no need to fire more")
    return false -- Target already has sufficient weapons allocated, no need to fire more
  end

  return true
end

---Process a fire unit and attempt to allocate weapons for attack
---@param firingUnit CMO__Unit The fire unit to process
---@param contact CMO__Contact The target contact
---@param totalAmmoRequested integer Total amount of ammunition requested for this attack
---@param ammoAlreadyAllocated integer Amount of ammunition already allocated in this attack
---@param weaponDBID number Specific weapon DBID to use
---@param shooterIdx integer Current shooter index
---@return boolean success Whether to advance to next firing unit
---@return integer weaponsAllocated Number of weapons allocated
local function processUnitGroup(firingUnit, contact, totalAmmoRequested, ammoAlreadyAllocated, weaponDBID, shooterIdx)
  local ammoAllocated = 0
  local advanceFiringUnit = false

  -- Check if we have a valid unit at the current group index
  if shooterIdx > #firingUnit.group.unitlist then
    return true, 0 -- Move to next battery, no weapons allocated
  end

  local guid = firingUnit.group.unitlist[shooterIdx]
  local unit = GameApi.ScenEdit_GetUnit(guid)

  if not unit then
    return true, 0 -- Unit not found, move to next, no weapons allocated
  end

  -- Find weapon info and check availability
  local weaponInfo = GameUtils.getWeaponInfo(unit, weaponDBID)
  weaponDBID = weaponInfo.weaponDBID -- Use found weaponDBID if not provided

  -- Check if unit can fire
  if canUnitFire(unit, contact, weaponInfo, totalAmmoRequested) then
    -- Determine how many weapons to allocate for this attack
    local ammoNeeded = totalAmmoRequested - ammoAlreadyAllocated
    local ammoToAllocate = math.min(ammoNeeded, weaponInfo.availableWeapons)

    -- Attack the contact
    local success = GameApi.ScenEdit_AttackContact(
      guid,
      contact.guid,
      { mode = "1", qty = ammoToAllocate, mount = weaponInfo.mountDBID, weapon = weaponDBID }
    )

    if success then
      ammoAllocated = ammoToAllocate
    end
  end

  -- Check if this was the last unit in the group
  if shooterIdx >= #firingUnit.group.unitlist then
    advanceFiringUnit = true
  end

  return advanceFiringUnit, ammoAllocated
end

---Process a single unit and attempt to allocate weapons for attack
---@param unit CMO__Unit The unit to process
---@param contact CMO__Contact The target contact
---@param totalAmmoRequested integer Total amount of ammunition requested for this attack
---@param weaponDBID number Specific weapon DBID to use
---@return {ammoAllocated: integer} # Results including allocated weapons
local function processSingleUnit(unit, contact, totalAmmoRequested, weaponDBID)
  -- Find weapon info and check availability
  local weaponInfo = GameUtils.getWeaponInfo(unit, weaponDBID)
  weaponDBID = weaponInfo.weaponDBID -- Use found weaponDBID if not provided

  -- Check if unit can fire
  if canUnitFire(unit, contact, weaponInfo, totalAmmoRequested) then
    -- Determine how many weapons to allocate for this attack
    local ammoToAllocate = math.min(totalAmmoRequested, weaponInfo.availableWeapons)

    -- Attack the contact
    local success = GameApi.ScenEdit_AttackContact(
      unit.guid,
      contact.guid,
      { mode = "1", qty = ammoToAllocate, mount = weaponInfo.mountDBID, weapon = weaponDBID }
    )

    if success then
      return { ammoAllocated = ammoToAllocate }
    end
  end

  return { ammoAllocated = 0 }
end

---Attack a single contact with weapon allocation from firing units
---@param contactGUID string The target contact to attack
---@param ammoToAllocate integer Total amount of ammunition to allocate for this attack
---@param firingUnits SBJ__FiringUnit[] Array of firing units to use for attack
---@param firingUnitIdx integer Starting firing unit index
---@param shooterIdx integer Starting shooter index
---@param weaponDBID number|nil Specific weapon DBID to use, defaults to nil
---@param sideName string The side to use for the attack, default is 'China'
---@return {firingUnitIdx: integer, shooterIdx: integer, ammoAllocated: integer} # Results including next indices and number of weapons launched
function AttackManager.attackContact(contactGUID, ammoToAllocate, firingUnits, firingUnitIdx, shooterIdx, weaponDBID,
                                     sideName)
  -- Initialize variables
  local totalAmmoAllocated = 0
  local attemptCount = 0
  local maxAttempts = 50
  local contact = GameApi.ScenEdit_GetContact(sideName, contactGUID)

  if contact == nil then
    Logger.error("AttackContact: Contact not found with GUID: " .. tostring(contactGUID))
  else
    -- Set default values if not provided
    firingUnitIdx = firingUnitIdx or 1
    shooterIdx = shooterIdx or 1

    -- Process each firing unit until we've allocated enough ammo or tried all firing units
    while firingUnitIdx <= #firingUnits and totalAmmoAllocated < ammoToAllocate and attemptCount < maxAttempts do
      local actualUnit = GameApi.ScenEdit_GetUnit(firingUnits[firingUnitIdx].name, sideName)
      local wpnDBID = weaponDBID or firingUnits[firingUnitIdx].weaponDBID

      if not actualUnit then
        Logger.error("AttackContact: Unit not found with name: " .. tostring(firingUnits[firingUnitIdx].name))
        break
      end

      -- Handle differently based on whether it's a group or individual unit
      if actualUnit.group then
        -- Track if we need to advance to next firing unit
        local advanceFiringUnit, ammoAllocated = processUnitGroup(
          actualUnit, contact, ammoToAllocate, totalAmmoAllocated, wpnDBID, shooterIdx
        )

        -- Update our tracking variables
        totalAmmoAllocated = totalAmmoAllocated + ammoAllocated
        attemptCount = attemptCount + 1 -- Count each unit processing as one attempt

        if advanceFiringUnit then
          firingUnitIdx = firingUnitIdx + 1
          shooterIdx = 1
        else
          shooterIdx = shooterIdx + 1
        end

        -- Wrap around to first firing unit if needed
        if firingUnitIdx > #firingUnits then
          firingUnitIdx = 1
        end

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
        firingUnitIdx = firingUnitIdx + 1
        if firingUnitIdx > #firingUnits then
          firingUnitIdx = 1
        end

        -- Check if we've allocated enough ammo
        if totalAmmoAllocated >= ammoToAllocate then
          break
        end
      end
    end
  end

  return { firingUnitIdx = firingUnitIdx, shooterIdx = shooterIdx, ammoAllocated = totalAmmoAllocated }
end

---Attack multiple contacts with weapon allocation from firing units
---@param opts SBJ__AttackContactsOpts Attack parameters
---@return integer # Total number of ammunition launched across all contacts
function AttackManager.attackContacts(opts)
  local result = { firingUnitIdx = 1, shooterIdx = 1, ammoAllocated = 0 }
  local totalAmmoAllocated = 0
  local contacts = opts.contacts or {}
  local qty = opts.qty or 1
  local firingUnits = opts.firingUnits
  local weaponDBID = opts.weaponDBID
  local sideName = opts.sideName or constants.SIDES.ENEMY

  for _, contact in ipairs(contacts) do
    result = AttackManager.attackContact(contact, qty, firingUnits, result.firingUnitIdx, result.shooterIdx, weaponDBID,
      sideName)
    totalAmmoAllocated = totalAmmoAllocated + result.ammoAllocated
  end

  return totalAmmoAllocated
end

return AttackManager
