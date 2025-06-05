GameApi = {}

---comment
---@param guid string -- The GUID of the unit
---@param side? string -- The side of the unit, if not provided, will search by GUID only
---@return CMO__Unit -- Returns the unit object associated with the given GUID or side
function GameApi.ScenEdit_GetUnit(guid, side)
  local result = ScenEdit_GetUnit({ guid = guid })

  if result == nil then
    result = ScenEdit_GetUnit({ side = side, unitname = guid })
  end

  if result == nil then
    error("Unit not found with guid: " .. tostring(guid))
  end

  return result
end

---comment
---@param attackerID string -- The GUID of the attacker unit
---@param contactId string -- The contact ID of the target contact
---@param opts CMO__AttackOptions -- Options for the attack, such as weapon selection, salvo size, etc.
---@return boolean -- Returns true if the attack was successfully initiated, false otherwise
function GameApi.ScenEdit_AttackContact(attackerID, contactId, opts)
  return ScenEdit_AttackContact(attackerID, contactId, opts)
end

---comment
---@param guid string -- The GUID of the doctrine
---@return CMO__Doctrine -- Returns the doctrine object associated with the given GUID
function GameApi.ScenEdit_GetDoctrine(guid)
  return ScenEdit_GetDoctrine({ guid = guid })
end

---comment
---@param attackerGUID string -- The GUID of the attacker unit
---@param contactGUID string -- The GUID of the target contact
---@param attackingSideGUID string -- The GUID of the attacking side
---@return table<integer, { weapon:number, qtyFired:number, shooter:string, target:string, qtyAssigned:number, weaponName:string }>|nil -- Returns an weapon allocation table
function GameApi.ScenEdit_WeaponAllocation(attackerGUID, contactGUID, attackingSideGUID)
  local result = ScenEdit_WeaponAllocation(attackerGUID, contactGUID, attackingSideGUID)

  if result == nil then
    error("Weapon allocation not found for attacker: " ..
      tostring(attackerGUID) .. ", contact: " .. tostring(contactGUID) .. ", side: " .. tostring(attackingSideGUID))
  end

  return result
end

---comment
---@param side string -- The side of the contact
---@param contactId string -- The GUID of the contact
---@return CMO__Contact -- Returns the contact object associated with the given side and contact ID
function GameApi.ScenEdit_GetContact(side, contactId)
  local result = ScenEdit_GetContact({ side = side, guid = contactId })

  if result == nil then
    error("Contact not found with side: " .. tostring(side) .. ", contactId: " .. tostring(contactId))
  end

  return result
end

---comment
---@param guid string -- The GUID of the loadout
---@return CMO__Loadout -- Returns the loadout object associated with the given GUID
function GameApi.ScenEdit_GetLoadout(guid)
  local result = ScenEdit_GetLoadout({ Unitname = guid })

  if result == nil then
    error("Loadout not found with guid: " .. tostring(guid))
  end

  return result
end

---comment
---@param guid string -- The GUID of the unit to assign to the mission
---@param missionName string -- The name of the mission to assign the unit to
---@param isEscort? boolean -- Whether the mission is an escort mission
---@return boolean -- Returns true if the unit was successfully assigned to the mission, false otherwise
function GameApi.ScenEdit_AssignUnitToMission(guid, missionName, isEscort)
  return ScenEdit_AssignUnitToMission(guid, missionName, isEscort)
end

---comment
---@param params CMO__GetPointFromBearing_Params -- Params for getting a point from bearing
---@return CMO__Location -- Returns a location object with latitude and longitude based on the provided options
function GameApi.World_GetPointFromBearing(params)
  return World_GetPointFromBearing(params)
end

---comment
---@param opts CMO__ReferencePointDescriptor -- Options for getting a point from bearing
---@return CMO__ReferencePoint -- Returns a reference point object with latitude and longitude based on the provided options
function GameApi.ScenEdit_AddReferencePoint(opts)
  return ScenEdit_AddReferencePoint(opts)
end

---comment
---@param side string -- The side to which the special message is sent
---@param message string -- The message to be sent
---@param locationPoint? CMO__Location -- The location point where the message is sent
---@return number -- 1 if successful, raises an error if unsuccessful.
function GameApi.ScenEdit_SpecialMessage(side, message, locationPoint)
  return ScenEdit_SpecialMessage(side, message, locationPoint)
end

---comment
---@param params CMO__GetCircleOfPoints_Params -- Params for getting a circle from point
---@return CMO__TableOfLocations -- Returns a table of locations representing a circle around a point
function GameApi.World_GetCircleFromPoint(params)
  return World_GetCircleFromPoint(params)
end

return {
  GameApi = GameApi
}
