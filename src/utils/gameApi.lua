GameApi = {}

---comment
---@param guid string -- The GUID of the unit
---@return CMO__Unit|nil -- Returns the unit object associated with the given GUID or side
function GameApi.ScenEdit_GetUnit(guid)
  local result = ScenEdit_GetUnit({ guid = guid })

  if result == nil then
    result = ScenEdit_GetUnit({ unitname = guid })
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
  local result = ScenEdit_AttackContact(attackerID, contactId, opts)
  if not result then
    error('Failed to attack contact: ' .. tostring(contactId) .. ' with attacker: ' .. tostring(attackerID))
  end
  return result
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
---@return CMO__Contact|nil -- Returns the contact object associated with the given side and contact ID
function GameApi.ScenEdit_GetContact(side, contactId)
  local result = ScenEdit_GetContact({ side = side, guid = contactId })

  if result == nil then
    error("Contact not found with side: " .. tostring(side) .. ", contactId: " .. tostring(contactId))
  end

  return result
end

---comment
---@param guid string -- The GUID of the loadout
---@return CMO__Loadout|nil -- Returns the loadout object associated with the given GUID
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
  isEscort = isEscort or false
  local result = ScenEdit_AssignUnitToMission(guid, missionName, isEscort)

  if not result then
    error('Failed to assign')
  end

  return result
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

---Gets a Mission wrapper for the specfied mission name or guid.
---@param SideNameOrGuid string @ The name of the side or its guid.
---@param missionNameOrGuid string @ the name or guid of the mission.
---@return CMO__Mission|nil @ The associated mission wrapper or nil on failure.
function GameApi.ScenEdit_GetMission(SideNameOrGuid, missionNameOrGuid)
  local result = ScenEdit_GetMission(SideNameOrGuid, missionNameOrGuid)

  if result == nil then
    error("Mission not found with side: " ..
      tostring(SideNameOrGuid) .. ", missionNameOrGuid: " .. tostring(missionNameOrGuid))
  end

  return result
end

---@return integer
function GameApi.ScenEdit_CurrentTime()
  return ScenEdit_CurrentTime()
end

---@param opts CMO__UnitUpdate
---@return CMO__Unit
function GameApi.ScenEdit_SetUnit(opts)
  return ScenEdit_SetUnit(opts)
end

---@param side string
---@param missionName string
---@param settings CMO__Mission
---@return CMO__Mission|nil
function GameApi.ScenEdit_SetMission(side, missionName, settings)
  local result = ScenEdit_SetMission(side, missionName, settings)

  if result == nil then
    error("Failed to set mission with side: " .. tostring(side) .. ", missionName: " .. tostring(missionName))
  end

  return result
end

---@param selector CMO__DoctrineSelector
---@param doctrine CMO__Doctrine
---@return CMO__Doctrine|nil
function GameApi.ScenEdit_SetDoctrine(selector, doctrine)
  local result = ScenEdit_SetDoctrine(selector, doctrine)

  if result == nil then
    error("Failed to set doctrine with selector: " .. tostring(selector))
  end

  return result
end

---@param side string
---@param missionName string
---@param missionType string
---@param opts CMO__Mission
---@return CMO__Mission|nil
function GameApi.ScenEdit_AddMission(side, missionName, missionType, opts)
  local result = ScenEdit_AddMission(side, missionName, missionType, opts)

  if result == nil then
    error("Failed to add mission with side: " .. tostring(side) .. ", missionName: " .. tostring(missionName))
  end

  return result
end

---@param side string
---@return CMO__TableOfContacts|nil
function GameApi.ScenEdit_GetContacts(side)
  local result = ScenEdit_GetContacts(side)

  if result == nil then
    error("Failed to get contacts with side: " .. tostring(side))
  end

  return result
end

---@param text string
---@param code? integer
function GameApi.ScenEdit_MsgBox(text, code)
  return ScenEdit_MsgBox(text, code)
end

---@param opts CMO__SideSelector
---@return CMO__Side
function GameApi.VP_GetSide(opts)
  local result = VP_GetSide(opts)

  if result == nil then
    error("Failed to get side with opts: " .. tostring(opts))
  end

  return result
end

---comment
---@param startLocation string|CMO__Location
---@param endLocation string|CMO__Location
---@return number
function GameApi.Tool_Range(startLocation, endLocation)
  return Tool_Range(startLocation, endLocation)
end

---comment
---@param startLocation string|CMO__Location
---@param endLocation string|CMO__Location
---@return number
function GameApi.Tool_Bearing(startLocation, endLocation)
  return Tool_Bearing(startLocation, endLocation)
end

---comment
---@param opts CMO__ReferencePointDescriptor
---@return CMO__TableOfReferencePoints|nil
function GameApi.ScenEdit_GetReferencePoints(opts)
  local result = ScenEdit_GetReferencePoints(opts)

  if result == nil then
    error("Failed to get reference points with opts: " .. tostring(opts))
  end

  return result
end

---comment
---@param opts CMO__SetUnitDescriptor
---@return CMO__Unit|nil
function GameApi.ScenEdit_AddUnit(opts)
  local result = ScenEdit_AddUnit(opts)

  if result == nil then
    error("Failed to add unit with opts: " .. tostring(opts))
  end

  return result
end

---comment
---@return CMO__Unit|nil
function GameApi.ScenEdit_UnitX()
  local result = ScenEdit_UnitX()

  if result == nil then
    error("Failed to get unitX")
  end

  return result
end

---comment
---@param param CMO__HostUnit
---@return boolean
function GameApi.ScenEdit_HostUnitToParent(param)
  return ScenEdit_HostUnitToParent(param)
end

---comment
---@param params CMO__UpdateUnit
---@return CMO__Unit
function GameApi.ScenEdit_UpdateUnit(params)
  return ScenEdit_UpdateUnit(params)
end

---comment
---@param objType string
---@param name string
---@param emcon string
---@return boolean
function GameApi.ScenEdit_SetEMCON(objType, name, emcon)
  return ScenEdit_SetEMCON(objType, name, emcon)
end

return GameApi
