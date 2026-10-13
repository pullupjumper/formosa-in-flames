local Logger = require("src.utils.logger")
local Utils = require("src.utils.utils")

---@class SBJ__GameApi
local realApi = {}
---@type SBJ__GameApi
local GameApi = {}

---Get unit by GUID or name
---@param guid string
---@param sideName? string
---@return CMO__Unit|nil # Returns the unit object, or nil if not found
function realApi.ScenEdit_GetUnit(guid, sideName)
  local result = nil

  if not sideName then
    result = ScenEdit_GetUnit({ guid = guid })
  end

  if result == nil then
    sideName = sideName or "China"
    result = ScenEdit_GetUnit({ unitname = guid, side = sideName })
  end

  if result == nil then
    error("Unit not found with name: " .. tostring(guid))
  end

  return result
end

---Attack a contact with specified options
---@param attackerID string
---@param contactId string
---@param opts CMO__AttackOptions
---@return boolean # True if attack was successfully initiated
function realApi.ScenEdit_AttackContact(attackerID, contactId, opts)
  local result = ScenEdit_AttackContact(attackerID, contactId, opts)
  if not result then
    error("Failed to attack contact: " .. tostring(contactId) .. " with attacker: " .. tostring(attackerID))
  end
  return result
end

---Get doctrine settings for a unit or side
---@param guid string
---@return CMO__Doctrine # Doctrine settings object
function realApi.ScenEdit_GetDoctrine(guid)
  return ScenEdit_GetDoctrine({ guid = guid })
end

---Get weapon allocation information
---@param attackerGUID string The GUID of the attacker unit (empty string for all)
---@param contactGUID string The GUID of the target contact (empty string for all)
---@param attackingSideGUID string The GUID or name of the attacking side (empty string for all)
---@return table<integer, { weapon: integer, qtyFired: integer, shooter: string, target: string, qtyAssigned: integer, weaponName: string }>|nil # Weapon allocation table
function realApi.ScenEdit_WeaponAllocation(attackerGUID, contactGUID, attackingSideGUID)
  local result = ScenEdit_WeaponAllocation(attackerGUID, contactGUID, attackingSideGUID)

  if result == nil then
    error("Weapon allocation not found for attacker: " ..
      tostring(attackerGUID) .. ", contact: " .. tostring(contactGUID) .. ", side: " .. tostring(attackingSideGUID))
  end

  return result
end

---Get contact information by side and contact ID
---@param side string
---@param contactId string
---@return CMO__Contact|nil # Contact object
function realApi.ScenEdit_GetContact(side, contactId)
  local result = ScenEdit_GetContact({ side = side, guid = contactId })

  if result == nil then
    error("Contact not found with side: " .. tostring(side) .. ", contactId: " .. tostring(contactId))
  end

  return result
end

---Get loadout information for a unit
---@param guid string
---@return CMO__Loadout|nil # Loadout object with weapon details
function realApi.ScenEdit_GetLoadout(guid)
  local result = ScenEdit_GetLoadout({ unitname = guid })

  if result == nil then
    error("Loadout not found with guid: " .. tostring(guid))
  end

  return result
end

---Assign unit to a mission
---@param guid string
---@param missionName string
---@param isEscort? boolean Whether this is an escort assignment (default: false)
---@return boolean # True if successfully assigned
function realApi.ScenEdit_AssignUnitToMission(guid, missionName, isEscort)
  isEscort = isEscort or false
  local result = ScenEdit_AssignUnitToMission(guid, missionName, isEscort)

  if not result then
    error("Failed to assign")
  end

  return result
end

---Calculate a point from bearing and distance
---@param params CMO__GetPointFromBearing_Params
---@return CMO__Location # Location with latitude and longitude
function realApi.World_GetPointFromBearing(params)
  return World_GetPointFromBearing(params)
end

---Add a reference point to the scenario
---@param opts CMO__ReferencePointDescriptor
---@return CMO__ReferencePoint # Created reference point object
function realApi.ScenEdit_AddReferencePoint(opts)
  return ScenEdit_AddReferencePoint(opts)
end

---Send a special message to a side
---@param side string
---@param message string
---@param locationPoint? CMO__Location
---@return number # 1 if successful
function realApi.ScenEdit_SpecialMessage(side, message, locationPoint)
  return ScenEdit_SpecialMessage(side, message, locationPoint)
end

---Generate a circle of points around a location
---@param params CMO__GetCircleOfPoints_Params
---@return CMO__TableOfLocations # Table of location points forming a circle
function realApi.World_GetCircleFromPoint(params)
  return World_GetCircleFromPoint(params)
end

---Get mission by side and mission name or GUID
---@param SideNameOrGuid string
---@param missionNameOrGuid string
---@return CMO__Mission|nil # Mission object
function realApi.ScenEdit_GetMission(SideNameOrGuid, missionNameOrGuid)
  local result = ScenEdit_GetMission(SideNameOrGuid, missionNameOrGuid)

  if result == nil then
    error("Mission not found with side: " ..
      tostring(SideNameOrGuid) .. ", missionNameOrGuid: " .. tostring(missionNameOrGuid))
  end

  return result
end

---Get current scenario time
---@return integer # Current time as Unix timestamp
function realApi.ScenEdit_CurrentTime()
  return ScenEdit_CurrentTime()
end

---Update unit properties
---@param opts CMO__UnitUpdate
---@return CMO__Unit # Updated unit object
function realApi.ScenEdit_SetUnit(opts)
  return ScenEdit_SetUnit(opts)
end

---Update mission settings
---@param side string
---@param missionName string
---@param settings CMO__MissionOpts
---@return CMO__Mission|nil # Updated mission object
function realApi.ScenEdit_SetMission(side, missionName, settings)
  local result = ScenEdit_SetMission(side, missionName, settings)

  if result == nil then
    error("Failed to set mission with side: " .. tostring(side) .. ", missionName: " .. tostring(missionName))
  end

  return result
end

---Set doctrine for a unit or side
---@param selector CMO__DoctrineSelector Doctrine selector (unit GUID or side name)
---@param doctrine CMO__Doctrine
---@return CMO__Doctrine|nil # Updated doctrine object
function realApi.ScenEdit_SetDoctrine(selector, doctrine)
  local result = ScenEdit_SetDoctrine(selector, doctrine)

  if result == nil then
    error("Failed to set doctrine with selector: " .. tostring(selector))
  end

  return result
end

---Add a new mission to a side
---@param side string
---@param missionName string
---@param missionType string Mission type (e.g., 'patrol', 'strike')
---@param opts CMO__Mission
---@return CMO__Mission|nil # Created mission object
function realApi.ScenEdit_AddMission(side, missionName, missionType, opts)
  local result = ScenEdit_AddMission(side, missionName, missionType, opts)

  if result == nil then
    error("Failed to add mission with side: " .. tostring(side) .. ", missionName: " .. tostring(missionName))
  end

  return result
end

---Get all contacts for a side
---@param side string
---@return CMO__TableOfContacts|nil # Table of all detected contacts
function realApi.ScenEdit_GetContacts(side)
  local result = ScenEdit_GetContacts(side)

  if result == nil then
    error("Failed to get contacts with side: " .. tostring(side))
  end

  return result
end

---Display a message box
---@param text string
---@param code? integer
function realApi.ScenEdit_MsgBox(text, code)
  return ScenEdit_MsgBox(text, code)
end

---Get side information
---@param opts CMO__SideSelector
---@return CMO__Side # Side object with units and other data
function realApi.VP_GetSide(opts)
  local result = VP_GetSide(opts)

  if result == nil then
    error("Failed to get side with opts: " .. tostring(opts))
  end

  return result
end

---Calculate range between two locations
---@param startLocation string|CMO__Location Starting location (GUID or coordinates)
---@param endLocation string|CMO__Location Ending location (GUID or coordinates)
---@return number # Range in nautical miles
function realApi.Tool_Range(startLocation, endLocation)
  return Tool_Range(startLocation, endLocation)
end

---Calculate bearing between two locations
---@param startLocation string|CMO__Location Starting location (GUID or coordinates)
---@param endLocation string|CMO__Location Ending location (GUID or coordinates)
---@return number # Bearing in degrees
function realApi.Tool_Bearing(startLocation, endLocation)
  return Tool_Bearing(startLocation, endLocation)
end

---Get multiple reference points by filter
---@param opts CMO__ReferencePointDescriptor
---@return CMO__TableOfReferencePoints|nil # Table of matching reference points
function realApi.ScenEdit_GetReferencePoints(opts)
  local result = ScenEdit_GetReferencePoints(opts)

  if result == nil then
    error("Failed to get reference points with opts: " .. tostring(opts))
  end

  return result
end

---Get a single reference point
---@param opts CMO__ReferencePointDescriptor
---@return CMO__ReferencePoint # Reference point object
function realApi.ScenEdit_GetReferencePoint(opts)
  local result = ScenEdit_GetReferencePoint(opts)

  if result == nil then
    error("Failed to get reference point with opts: " .. tostring(opts))
  end

  return result
end

---Query the game database
---@param objectType string Object type ('Unit', 'Weapon', 'Sensor', etc.)
---@param DBID integer
---@return table # Database entry information
function realApi.ScenEdit_QueryDB(objectType, DBID)
  return ScenEdit_QueryDB(objectType, DBID)
end

---Add a new unit to the scenario
---@param opts CMO__SetUnitDescriptor
---@return CMO__Unit|nil # Created unit object
function realApi.ScenEdit_AddUnit(opts)
  local result = ScenEdit_AddUnit(opts)

  if result == nil then
    error("Failed to add unit with opts: " .. tostring(opts))
  end

  return result
end

---Get the current context unit (UnitX)
---@return CMO__Unit|nil # The current unit being processed
function realApi.ScenEdit_UnitX()
  local result = ScenEdit_UnitX()

  if result == nil then
    error("Failed to get unitX")
  end

  return result
end

---Host a unit to its parent (embark)
---@param param CMO__HostUnit
---@return boolean # True if successfully hosted
function realApi.ScenEdit_HostUnitToParent(param)
  return ScenEdit_HostUnitToParent(param)
end

---Update unit properties (alternative to SetUnit)
---@param params CMO__UpdateUnit
---@return CMO__Unit # Updated unit object
function realApi.ScenEdit_UpdateUnit(params)
  return ScenEdit_UpdateUnit(params)
end

---Set EMCON (Emission Control) settings
---@param objType string Object type ('Unit', 'Side', 'Mission')
---@param name string Object name or GUID
---@param emcon string
---@return boolean # True if successfully set
function realApi.ScenEdit_SetEMCON(objType, name, emcon)
  return ScenEdit_SetEMCON(objType, name, emcon)
end

---Assign units as targets for a mission
---@param AUNameOrIDOrTable string|string[] Unit name(s) or GUID(s) to assign as targets
---@param MissionNameOrIDOrTable string Mission name or GUID
---@return string[] # Array of assigned unit GUIDs
function realApi.ScenEdit_AssignUnitAsTarget(AUNameOrIDOrTable, MissionNameOrIDOrTable)
  return ScenEdit_AssignUnitAsTarget(AUNameOrIDOrTable, MissionNameOrIDOrTable)
end

---Set Weapon Release Authority (WRA) settings
---@param selector CMO__DoctrineWRASelector
---@param wra CMO__WRA
function realApi.ScenEdit_SetDoctrineWRA(selector, wra)
  local result = ScenEdit_SetDoctrineWRA(selector, wra)

  if result == nil then
    error("Failed to set doctrine with selector: " .. tostring(selector))
  end

  return result
end

---Add reloads to a unit
---@param descriptor CMO__Weapon2MountDescriptor
---@return number # Number of reloads added
function realApi.ScenEdit_AddReloadsToUnit(descriptor)
  return ScenEdit_AddReloadsToUnit(descriptor)
end

---Set score for a side
---@param SideOrGuid string Side name or GUID
---@param newScore number
---@param reason? string
function realApi.ScenEdit_SetScore(SideOrGuid, newScore, reason)
  return ScenEdit_SetScore(SideOrGuid, newScore, reason)
end

---Get current score for a side
---@param side string
---@return number # Current score value
function realApi.ScenEdit_GetScore(side)
  return ScenEdit_GetScore(side)
end

---Display advanced HTML dialog
---@param title string
---@param htmlContent string
---@param buttons table
---@return table # Dialog result
function realApi.UI_CallAdvancedHTMLDialog(title, htmlContent, buttons)
  return UI_CallAdvancedHTMLDialog(title, htmlContent, buttons)
end

---Configure intermittent emission settings for a unit
---@param unitGuid string
---@param emconState string
---@param settings CMO__ConfigTable
---@return boolean # True if successfully configured
function realApi.ScenEdit_SetUnitIntermittentEmissionConfig(unitGuid, emconState, settings)
  return ScenEdit_SetUnitIntermittentEmissionConfig(unitGuid, emconState, settings)
end

---Delete a unit from the scenario
---@param opts CMO__UnitSelector
---@return boolean # True if successfully deleted
function realApi.ScenEdit_DeleteUnit(opts)
  local result = ScenEdit_DeleteUnit(opts)

  if not result then
    error("Failed to delete unit with opts: " .. tostring(opts))
  end

  return result
end

---Add weapon to unit magazine
---@param opts CMO__Weapon2MountDescriptor
---@return number # Number of weapons added
function realApi.ScenEdit_AddWeaponToUnitMagazine(opts)
  local result = ScenEdit_AddWeaponToUnitMagazine(opts)

  if not result then
    error("Failed to add weapon to unit magazine with opts: " .. tostring(opts))
  end

  return result
end

---Fill magazines for loadout
---@param opts CMO__FillMagClass
---@return table # Fill result information
function realApi.ScenEdit_FillMagsForLoadout(opts)
  return ScenEdit_FillMagsForLoadout(opts)
end

---Update reference point properties
---@param opts CMO__ReferencePointDescriptor
---@return CMO__ReferencePoint|nil # Updated reference point
function realApi.ScenEdit_SetReferencePoint(opts)
  local result = ScenEdit_SetReferencePoint(opts)

  if not result then
    error("Failed to set reference point with opts: " .. tostring(opts))
  end

  return result
end

---Set unit damage
---@param opts CMO__DamageOptions
---@return table<integer, CMO__UnitComponent_Return>|nil # Damage result components
function realApi.ScenEdit_SetUnitDamage(opts)
  local result = ScenEdit_SetUnitDamage(opts)

  if not result then
    error("Failed to set unit damage with opts: " .. tostring(opts))
  end

  return result
end

---Create bark notification at geographic location
---@param longitude number|string
---@param latitude number|string
---@param notification string
---@param R number Red color component (0-255)
---@param G number Green color component (0-255)
---@param B number Blue color component (0-255)
---@param showToAll boolean
---@param persistent boolean
---@param lifeTime number Duration in seconds
---@param fontSize number
function realApi.ScenEdit_CreateBarkNotification_Geo(
    longitude, latitude, notification, R, G, B, showToAll, persistent, lifeTime, fontSize
)
  return ScenEdit_CreateBarkNotification_Geo(
    longitude, latitude, notification, R, G, B, showToAll, persistent, lifeTime, fontSize
  )
end

---Delete a reference point
---@param opts CMO__ReferencePointDescriptor
---@return boolean # True if successfully deleted
function realApi.ScenEdit_DeleteReferencePoint(opts)
  return ScenEdit_DeleteReferencePoint(opts)
end

---Remove a zone
---@param side string
---@param zoneType string|integer
---@param opts table
---@return CMO__Zone # Removed zone information
function realApi.ScenEdit_RemoveZone(side, zoneType, opts)
  return ScenEdit_RemoveZone(side, zoneType, opts)
end

---Add a zone to a side
---@param side string
---@param zoneType number
---@param opts CMO__Zone
---@return CMO__Zone|nil # Created zone object
function realApi.ScenEdit_AddZone(side, zoneType, opts)
  local result = ScenEdit_AddZone(side, zoneType, opts)

  if not result then
    error("Failed to add zone with opts: " .. tostring(opts))
  end

  return result
end

---Get a zone by name
---@param sideName string
---@param zoneName string
---@param zoneType number
---@return CMO__Zone|nil # Zone object
function realApi.ScenEdit_GetZone(sideName, zoneName, zoneType)
  local result = ScenEdit_GetZone(sideName, zoneName, zoneType)

  if not result then
    error("Failed to get zone with name: " .. tostring(zoneName))
  end

  return result
end

---Get player's current side
---@return string # Player side name
function realApi.ScenEdit_PlayerSide()
  return ScenEdit_PlayerSide()
end

---Get event by name
---@param eventName string
---@return CMO__Event|nil # Event object
function realApi.ScenEdit_GetEvent(eventName)
  local result = ScenEdit_GetEvent(eventName)

  if result == nil then
    error("Failed to get event with name: " .. tostring(eventName))
  end

  return result
end

---Update event settings
---@param eventName string
---@param opts CMO__EventUpdate
---@return string|CMO__Event|nil # Updated event object
function realApi.ScenEdit_SetEvent(eventName, opts)
  local result = ScenEdit_SetEvent(eventName, opts)

  if not result then
    error("Failed to set event with opts: " .. tostring(opts))
  end
  return result
end

---Update trigger settings
---@param opts CMO__TriggerUpdate
---@return table # Updated trigger information
function realApi.ScenEdit_SetTrigger(opts)
  return ScenEdit_SetTrigger(opts)
end

---Update action settings
---@param opts table
---@return CMO__TCA_ReturnTable|nil # Updated action information
function realApi.ScenEdit_SetAction(opts)
  local result = ScenEdit_SetAction(opts)

  if not result then
    error("Failed to set action with opts: " .. tostring(opts))
  end

  return result
end

---Set event trigger
---@param eventName string
---@param opts CMO__EventTCAUpdate
---@return CMO__TCA_ReturnTable # Trigger result
function realApi.ScenEdit_SetEventTrigger(eventName, opts)
  return ScenEdit_SetEventTrigger(eventName, opts)
end

---Set event action
---@param eventName string
---@param opts CMO__EventTCAUpdate
---@return CMO__TCA_ReturnTable # Action result
function realApi.ScenEdit_SetEventAction(eventName, opts)
  return ScenEdit_SetEventAction(eventName, opts)
end

---Create mission flight plan
---@param side string
---@param missionName string
---@param opts CMO__FlightPlanOptions|{}
---@return table<number, any>|nil # Flight plan waypoints
function realApi.ScenEdit_CreateMissionFlightPlan(side, missionName, opts)
  return ScenEdit_CreateMissionFlightPlan(side, missionName, opts)
end

---Set loadout for a unit
---@param opts CMO__LoadoutInfo
---@return boolean # True if successfully set
function realApi.ScenEdit_SetLoadout(opts)
  return ScenEdit_SetLoadout(opts)
end

---Get the current context event (EventX)
---@return CMO__Event # The current event being processed
function realApi.ScenEdit_EventX()
  local result = ScenEdit_EventX()

  if not result then
    error("Failed to get event")
  end

  return result
end

---Update special action settings
---@param opts CMO__SpecialActionUpdate
---@return boolean|nil # Updated special action information
function realApi.ScenEdit_SetSpecialAction(opts)
  local result = ScenEdit_SetSpecialAction(opts)

  if not result then
    error("Failed to set special action with opts: " .. tostring(opts))
  end

  return result
end

---Get special action settings
---@param opts CMO__SpecialActionUpdate
---@return CMO__SpecialAction|CMO__SpecialAction[]|nil # Special action information
function realApi.ScenEdit_GetSpecialAction(opts)
  local result = ScenEdit_GetSpecialAction(opts)

  if not result then
    error("Failed to get special action with opts: " .. tostring(opts))
  end

  return result
end

---Add special action settings
---@param opts CMO__SpecialActionUpdate
---@return CMO__SpecialAction|nil # Special action information
function realApi.ScenEdit_AddSpecialAction(opts)
  local result = ScenEdit_AddSpecialAction(opts)

  if not result then
    error("Failed to get special action with opts: " .. tostring(opts))
  end

  return result
end

---Clear all unit magazines
---@param opts CMO__UnitSelector
---@return boolean # True if successfully cleared
function realApi.ScenEdit_ClearAllMagazines(opts)
  return ScenEdit_ClearAllMagazines(opts)
end

---Update unit cargo contents
---@param opts CMO__UpdateUnitCargo
---@return CMO__Unit|nil # Updated unit object
function realApi.ScenEdit_UpdateUnitCargo(opts)
  return ScenEdit_UpdateUnitCargo(opts)
end

---Unload cargo from a unit
---@param fromUnit CMO__UnitSelector|string
---@param cargos string[]|number[][]
---@return boolean # True if Successful or false if not
function realApi.ScenEdit_UnloadCargo(fromUnit, cargos)
  return ScenEdit_UnloadCargo(fromUnit, cargos)
end

---@param params CMO__MinefieldDescriptor
---@return number # Number of mines actually laid
function realApi.ScenEdit_AddMinefield(params)
  return ScenEdit_AddMinefield(params)
end

---@param sideName string
---@param guid string
---@return boolean # True if successful
function realApi.ScenEdit_DeleteMine(sideName, guid)
  return ScenEdit_DeleteMine(sideName, guid)
end

setmetatable(GameApi, {
  __index = function(t, key)
    local targetFunc = realApi[key]
    if type(targetFunc) ~= "function" then return nil end

    local label = "GameApi." .. key
    local wrapper = function(...)
      local result, err = Utils.tryCall(label, targetFunc, ...)
      if err then
        Logger.error(err)
        return nil
      end
      return result
    end

    -- No __newindex on GameApi, so this plain assignment is a raw write that
    -- caches the wrapper; later lookups hit it directly and skip __index.
    t[key] = wrapper
    return wrapper
  end
})

return GameApi
