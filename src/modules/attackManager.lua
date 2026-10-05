local GameApi = require("src.utils.gameApi")
local Logger = require("src.utils.logger")
local GameUtils = require("src.utils.gameUtils")
local constants = require("src.core.constants")

local AttackManager = {}

---Get total ammunition already allocated for attacking a specific target
---@param contactGUID string
---@param sideName string
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
---@param unit CMO__Unit
---@param contact CMO__Contact
---@param weaponInfo {weaponDBID: number, mountDBID: number, availableWeapons: integer, maxWeapons: integer, assignedWeapons: integer}
---@param totalAmmoRequested integer
---@return boolean # Whether the unit can fire
local function canUnitFire(unit, contact, weaponInfo, totalAmmoRequested)
  local doctrine = GameApi.ScenEdit_GetDoctrine(unit.guid)

  if not doctrine then
    return false
  end

  local isHold = doctrine.weapon_control_status_land == 2 or doctrine.weapon_control_status_land == "2"

  if isHold then
    return false
  end

  if weaponInfo.availableWeapons <= 0 then
    Logger.log(constants.TAGS.ATTACK_MANAGER, "No weapons available, no need to fire more")
    return false
  end

  if weaponInfo.assignedWeapons >= weaponInfo.maxWeapons then
    Logger.log(constants.TAGS.ATTACK_MANAGER, "Maximum weapon allocation reached, no need to fire more")
    return false
  end

  local totalAmmoAlreadyAllocatedForTarget = getAmmoAllocatedForTarget(contact.guid, unit.side)

  if totalAmmoAlreadyAllocatedForTarget >= totalAmmoRequested then
    Logger.log(constants.TAGS.ATTACK_MANAGER, "Target already has sufficient weapons allocated, no need to fire more")
    return false -- Target already has sufficient weapons allocated, no need to fire more
  end

  return true
end

---Process a fire unit and attempt to allocate weapons for attack
---@param firingUnit CMO__Unit
---@param contact CMO__Contact
---@param request SBJ__GroupAttackRequest
---@param shooterIdx integer
---@return boolean success Whether to advance to next firing unit
---@return integer weaponsAllocated Number of weapons allocated
local function processUnitGroup(firingUnit, contact, request, shooterIdx)
  local totalAmmoRequested, ammoAlreadyAllocated = request.totalAmmoRequested, request.ammoAlreadyAllocated
  local weaponDBID = request.weaponDBID
  local ammoAllocated = 0
  local advanceFiringUnit = false

  if shooterIdx > #firingUnit.group.unitlist then
    return true, 0 -- Move to next battery, no weapons allocated
  end

  local guid = firingUnit.group.unitlist[shooterIdx]
  local unit = GameApi.ScenEdit_GetUnit(guid)

  if not unit then
    return true, 0 -- Unit not found, move to next, no weapons allocated
  end

  local weaponInfo = GameUtils.getWeaponInfo(unit, weaponDBID)
  weaponDBID = weaponInfo.weaponDBID -- Use found weaponDBID if not provided

  if canUnitFire(unit, contact, weaponInfo, totalAmmoRequested) then
    -- Determine how many weapons to allocate for this attack
    local ammoNeeded = totalAmmoRequested - ammoAlreadyAllocated
    local ammoToAllocate = math.min(ammoNeeded, weaponInfo.availableWeapons)
    local success = false

    if contact.areaofuncertainty and #contact.areaofuncertainty > 0 then
      success = GameApi.ScenEdit_AttackContact(guid, "BOL", {
        mode = "1",
        qty = ammoToAllocate,
        latitude = contact.latitude,
        longitude = contact.longitude,
        mount = weaponInfo.mountDBID,
        weapon = weaponDBID
      })
    else
      success = GameApi.ScenEdit_AttackContact(guid, contact.guid, {
        mode = "1",
        qty = ammoToAllocate,
        mount = weaponInfo.mountDBID,
        weapon = weaponDBID
      })
    end

    if success then
      ammoAllocated = ammoToAllocate
    end
  end

  if shooterIdx >= #firingUnit.group.unitlist then
    advanceFiringUnit = true
  end

  return advanceFiringUnit, ammoAllocated
end

---Process a single unit and attempt to allocate weapons for attack
---@param unit CMO__Unit
---@param contact CMO__Contact
---@param totalAmmoRequested integer
---@param weaponDBID number
---@return {ammoAllocated: integer} # Results including allocated weapons
local function processSingleUnit(unit, contact, totalAmmoRequested, weaponDBID)
  local weaponInfo = GameUtils.getWeaponInfo(unit, weaponDBID)
  weaponDBID = weaponInfo.weaponDBID -- Use found weaponDBID if not provided

  if canUnitFire(unit, contact, weaponInfo, totalAmmoRequested) then
    -- Determine how many weapons to allocate for this attack
    local ammoToAllocate = math.min(totalAmmoRequested, weaponInfo.availableWeapons)
    local success = false

    if contact.areaofuncertainty and #contact.areaofuncertainty > 0 then
      success = GameApi.ScenEdit_AttackContact(unit.guid, "BOL", {
        mode = "1",
        qty = ammoToAllocate,
        latitude = contact.latitude,
        longitude = contact.longitude,
        mount = weaponInfo.mountDBID,
        weapon = weaponDBID
      })
    else
      success = GameApi.ScenEdit_AttackContact(unit.guid, contact.guid, {
        mode = "1",
        qty = ammoToAllocate,
        mount = weaponInfo.mountDBID,
        weapon = weaponDBID
      })
    end

    if success then
      return { ammoAllocated = ammoToAllocate }
    end
  end

  return { ammoAllocated = 0 }
end

---Attack a single contact with weapon allocation from firing units
---Advances `state` in place so the next contact continues the rotation.
---@param sideName string
---@param contactGUID string
---@param params SBJ__AttackContactParams
---@param state SBJ__AttackRotationState
---@return integer # Number of weapons launched
local function attackContact(sideName, contactGUID, params, state)
  local ammoToAllocate = params.ammoToAllocate
  local firingUnits = params.firingUnits
  local weaponDBID = params.weaponDBID
  local firingUnitIdx = state.firingUnitIdx
  local shooterIdx = state.shooterIdx
  local totalAmmoAllocated = 0
  local attemptCount = 0
  local maxAttempts = 50
  local contact = GameApi.ScenEdit_GetContact(sideName, contactGUID)

  if contact == nil then
    Logger.error("AttackContact: Contact not found with GUID: " .. tostring(contactGUID))
  else
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
          actualUnit,
          contact,
          { totalAmmoRequested = ammoToAllocate, ammoAlreadyAllocated = totalAmmoAllocated, weaponDBID = wpnDBID },
          shooterIdx
        )

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

        if totalAmmoAllocated >= ammoToAllocate then
          break
        end
      end
    end
  end

  state.firingUnitIdx = firingUnitIdx
  state.shooterIdx = shooterIdx

  return totalAmmoAllocated
end

---Attack multiple contacts with weapon allocation from firing units
---@param params SBJ__AttackContactsParams
---@return integer # Total number of ammunition launched across all contacts
function AttackManager.attackContacts(params)
  local state = { firingUnitIdx = 1, shooterIdx = 1 }
  local totalAmmoAllocated = 0
  local contacts = params.contacts or {}
  local qty = params.qty or 1
  local firingUnits = params.firingUnits
  local weaponDBID = params.weaponDBID
  local sideName = params.sideName or constants.SIDES.RED

  for _, contact in ipairs(contacts) do
    totalAmmoAllocated = totalAmmoAllocated
      + attackContact(sideName, contact, { ammoToAllocate = qty, firingUnits = firingUnits, weaponDBID = weaponDBID }, state)
  end

  return totalAmmoAllocated
end

return AttackManager
