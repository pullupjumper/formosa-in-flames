---To show weapon allocation from attacker to target
---@param attackerGUID string The GUID of the attacker unit
---@param contactGUID string The GUID of the target contact
---@param attackingSideGUID string The GUID of the attacking side
---@return table|nil @ Returns an weapon allocation table
---Example: ScenEdit_WeaponAllocation('attackerGUID', '', '') supply attacker GUID and empty contact to see salvos from the attacker to anyone
---Example: ScenEdit_WeaponAllocation('', 'contactGUID', 'attackingSideGUID') supply contact GUID and empty attacker to see salvos against contact. Note in this case, you MUST supply the side from which attacks are coming from.
---Example: ScenEdit_WeaponAllocation('attackerGUID', 'contactGUID', '') supply attacker and contact GUIDs to see salvos generated between the 2
function ScenEdit_WeaponAllocation(attackerGUID, contactGUID, attackingSideGUID) end

---@class CMO__Zone:table
---@field guid string @The GUID of the zone. READ ONLY.
---@field type string @ the type of the zone 'NoNavZone' = 0 | 'ExclusionZone' = 1
---@field description string @The description of the zone.
---@field isactive boolean @Zone is currently active.
---@field area CMO__TableOfReferencePoints @A set of reference points marking the zone. Can be updated by a list of RPs, or a table of new RP values.
---@field affects? table @List of unit types (ship, submarine, aircraft, facility)
---@field locked? boolean @Zone is locked or not.
---@field markas? string @Posture of violator of exclusion zone.
---@field relativeto? string @ unitname or unitguid of unit to make this zones area relative-to. (undocumented) Also the side of the unit must match the
---@field rename? string @ name to rename the description/name to [only applies for calls to ScenEdit_SetZone]
---@field enablers table @Table of enablers for the zone. (undocumented)

---@class SBJ__Location_Params:table
---@field initialLocation {latitude:number|string, longitude:number|string}
---@field num number
---@field bearing number
---@field distance number
---@field firstDistance? number

---@class SBJ__ACVLocation_Params:table
---@field bearing number
---@field distance number
---@field ship CMO__Unit
---@field speed number
---@field destination CMO__TableOfWaypoints

---@class SBJ__OffloadVehicles_Params:table
---@field ship CMO__Unit
---@field num number
---@field bearing number
---@field distance number
---@field firstDistance number

---@class SBJ__AreaMode:table
---@field side string
---@field shape string
---@field distance number
---@field name string|nil
---@field bear_offset number|nil

---@class SBJ__Battery:table
---@field name string
---@field guid string
---@field reloadStartTime? number|nil @in seconds or nil
---@field state BatteryState @ STATIC = 0, REPOSITIONING = 1, RELOAD = 2
---@field position table -- The position of the battery
---@field weaponDBID number -- The weapon DBID to use for the battery
---@field ammoThreshold number -- The ammo threshold for the battery, if not specified, the default value will be used
---@field ammunitionSection string -- The ammunition section guid to use for the battery

---@class SBJ__AttackContacts_Params:table
---@field contacts table<integer, string> -- A table of contact GUIDs to attack
---@field qty number -- The number of salvos to launch
---@field batteries table<string, SBJ__Battery> -- A table of batteries to use for the attack
---@field weaponDBID? number -- The weapon DBID to use for the attack, if not specified, the default weapon will be used
---@field side? string -- The side to use for the attack, if not specified, the side of the first battery will be used
