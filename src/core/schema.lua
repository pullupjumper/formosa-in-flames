---To show weapon allocation from attacker to target
---@param attackerGUID string The GUID of the attacker unit
---@param contactGUID string The GUID of the target contact
---@param attackingSideGUID string The GUID of the attacking side
---@return table|nil @ Returns an weapon allocation table
---Example: ScenEdit_WeaponAllocation('attackerGUID', '', '') supply attacker GUID and empty contact to see salvos from the attacker to anyone
---Example: ScenEdit_WeaponAllocation('', 'contactGUID', 'attackingSideGUID') supply contact GUID and empty attacker to see salvos against contact. Note in this case, you MUST supply the side from which attacks are coming from.
---Example: ScenEdit_WeaponAllocation('attackerGUID', 'contactGUID', '') supply attacker and contact GUIDs to see salvos generated between the 2
function ScenEdit_WeaponAllocation(attackerGUID, contactGUID, attackingSideGUID) end

---Create a new flight plan
---@param side string @The mission side
---@param missionName string @The mission name/guid
---@param opts CMO__FlightPlanOptions @The options for the flight plan
---@return table<number, any> @ Returns all the flights on the mission. Currently only returns the first flight, will be fixed in a upcoming release.
function ScenEdit_CreateMissionFlightPlan(side, missionName, opts) end

---@class CMO__FlightPlanOptions:table
---@field DATEONTARGET string @ The mission time on target day, YYYY/MM/DD
---@field TIMEONTARGET string @ The mission time on target, HH:MM:SS
---@field TAKEOFFDATE string @ The takeoff date, YYYY/MM/DD
---@field TAKEOFFTIME string @ The takeoff time, HH:MM:SS

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

---@class SBJ__Position:table
---@field course CMO__TableOfWaypoints @Waypoints to area
---@field area string[]  EX:{"rp-100","rp-101","rp-102","rp-103","rp-104"}

---@class SBJ__OPAREAs:table
---@field FP SBJ__Position
---@field HA? SBJ__Position
---@field AHA SBJ__Position
---@field RL SBJ__Position

---@class SBJ__Ammunition:table
---@field guid string
---@field wpnCurrent number
---@field wpnDefault number

---@class SBJ__AmmunitionSection:SBJ__Ammunition
---@field name string
---@field unitCount number
---@field position SBJ__OPAREAs
---@field reloadStartTime number|nil
---@field state CONFIG.batteryState
---@field ammunition string

---@class SBJ__Battery:SBJ__AmmunitionSection
---@field weaponDBID number -- The weapon DBID to use for the battery
---@field ammoThreshold number -- The ammo threshold for the battery, if not specified, the default value will be used
---@field ammunitionSection string -- The ammunition section guid to use for the battery
---@field msg string -- The message to display for the battery

---@class SBJ__C2:table
---@field name string
---@field msg string
---@field guid string
---@field areas table<number, string[]>
---@field SAM table
---@field radar? table

---@class SBJ__AttackContacts_Params:table
---@field contacts table<integer, string> -- A table of contact GUIDs to attack
---@field qty number -- The number of salvos to launch
---@field batteries table<string, SBJ__Battery> -- A table of batteries to use for the attack
---@field weaponDBID? number -- The weapon DBID to use for the attack, if not specified, the default weapon will be used
---@field side? string -- The side to use for the attack, if not specified, the side of the first battery will be used

---@class SBJ__MissionEntry:table
---@field baseGUID string -- The GUID of the base to use for the mission
---@field missionParams SBJ__MissionParams -- The parameters for the mission
---@field unitCount number -- The number of units to assign to the mission
---@field weaponDBID? number -- The weapon DBID to use for the mission
---@field unitDBID? number -- The unit DBID to use for the mission
---@field loadoutId? number -- The loadout ID to filter by, 0 for any loadout
---@field startTime string -- The start time of the mission
---@field endTime? string -- The end time of the mission

---@class SBJ__MissionParams:table
---@field name string -- The name of the mission
---@field side string -- The side of the mission
---@field type string -- The type of the mission
---@field opts CMO__Mission -- The options for the mission

---@class SBJ__GenerateMissilePaths_Params
---@field target_lat number Target latitude
---@field target_lon number Target longitude
---@field launcher_lat number Launcher latitude
---@field launcher_lon number Launcher longitude
---@field radar_range number Radar range (nautical miles)
---@field missile_count number|nil Number of missiles, default is 5
---@field missile_speed_kts number|nil Missile speed (knots), default is 600
---@field missile_range_nm number|nil Maximum missile range (nautical miles), default is 100

---@class SBJ__MissilePath
---@field waypoints table<integer, CMO__Location> Missile waypoint list
---@field launch_time number Launch time (UTC timestamp)

---@class SBJ__CONFIG:table

---@class SBJ__SaveData:table

---@class SBJ__ACV:table
---@field bearing number
---@field distance number
---@field speed number
---@field destination CMO__TableOfWaypoints
---@field area string[]

---@class SBJ__OperationalZone:table
---@field name string
---@field baseGUID string
---@field anchorageArea string[]
---@field LSTAnchorageArea string[]
---@field area string[]
---@field offloadArea string[]
---@field boat table
---@field tansportHelicopter table
---@field attackHelicopter table
---@field LSTSettings table
---@field ACV SBJ__ACV
---@field reconUAV table

---@class SBJ__Target:table
---@field list string[]
---@field evaluatedlist string[]
---@field objs table
---@field areas table
---@field filterNames string[]
---@field contactAge number
---@field minTargetCount number
---@field ammoPerTarget number

---@class SBJ__Task:table
---@field target SBJ__Target

---@class SBJ__Package:SBJ__Task
---@field striker SBJ__MissionEntry
---@field escort SBJ__MissionEntry
---@field wildWeasel SBJ__MissionEntry
---@field jammer SBJ__MissionEntry
---@field tanker SBJ__MissionEntry
---@field reconUAV table
---@field hasLaunched boolean
---@field loadoutStatus table

---@class SBJ__FireSupportTask:SBJ__Task
---@field name string
---@field wpnSystem string
---@field batteries SBJ__Battery[]
---@field startTime string
---@field isFinished boolean

---@class SBJ__FireSupportExecutionMatrix:table
---@field name string
---@field isActivated boolean
---@field isFirstWave boolean
---@field strikeInterval number
---@field reconUAVs table
---@field allBatteriesInPosition boolean
---@field isFinished boolean
---@field FSTs SBJ__FireSupportTask[]

---@class SBJ__FilterParams:table
---@field config SBJ__CONFIG
---@field saveData SBJ__SaveData
---@field task SBJ__Task
---@field contacts CMO__Contact[]
---@field shouldTrack? boolean

---@class SBJ__LandingMission:table
---@field name string
---@field loadoutId number
---@field num number
---@field startTime string
--------------------------------------------------------------------
---@class SBJ__CargoForTransfer:table
---@field type075 SBJ__TransferCargoByLoadout[]
---@field type071 SBJ__TransferCargoByLoadout[]

---@class SBJ__TransferCargoByLoadout:table
---@field loadoutId number
---@field cargoItems SBJ__CargoList[]

---@class SBJ__CargoList:SBJ__CargoItem[]

---@class SBJ__CargoItem:table
---@field type number
---@field num number
---@field dbid number

------------------------------------------------------------------------
---@class SBJ__Loadout:table
---@field loadoutId number Ammunition configuration ID
---@field num number Unit count

---@class SBJ__EmbarkedUnit:table
---@field side string Side name
---@field type string Unit type
---@field name string Unit name
---@field dbid number Unit database ID
---@field loadouts SBJ__Loadout[]|nil Unit ammunition configuration

---@class SBJ__ShipConfig:table
---@field dbid number Database ID
---@field unitname string Unit name
---@field distance number Distance
---@field angle number Angle
---@field embarkedUnits SBJ__EmbarkedUnit[]|nil Embarked units
---@field loadouts SBJ__Loadout[]|nil Ammunition configuration

---@class SBJ__ShipSettings:table
---@field distanceBetweenLSTAndLPDArea string
---@field horizontalDistance number
---@field verticalDistance number
---@field transitDistance number
---@field shipSpeed number
---@field heading table
---@field ACVSpeed number
---@field ACVTransitDistance number
---@field ACVHorizontalDistance number

---@class SBJ__RandomUnits:table
---@field centerPoint {lat:number, lon:number}
---@field randomRadius number
---@field autodetectable boolean
---@field unitname string
---@field sideName string
---@field unitType string
---@field count number
---@field dbids number[]

---@class SBJ__FormationConfig:table
---@field centerPoint {lat:number, lon:number}
---@field heading number
---@field groupName string
---@field sideName string
---@field unitTypes SBJ__ShipConfig[]


---SIGINT detection configuration
---@class SBJ__SIGINTConfig:table
---@field detectionThreshold number minimum detection range
---@field maxRange table maximum detection range {min, max}
---@field decayRate number signal decay rate
---@field randomFactor number random deviation factor
---@field displayConfig SBJ__SIGINTDisplayData default display settings

---Enhanced SIGINT detection result
---@class SBJ__SIGINTResult:table
---@field longitude number detected longitude
---@field latitude number detected latitude
---@field isDetected boolean whether signal is detected
---@field confidence number detection confidence (0-1)
---@field detectorId string|nil ID of detecting unit
---@field timestamp number detection timestamp

---Enhanced SIGINT display data configuration
---@class SBJ__SIGINTDisplayData:table
---@field R number|nil red value (default: 255)
---@field G number|nil green value (default: 255)
---@field B number|nil blue value (default: 255)
---@field lifeTime number|nil display time (default: 4)
---@field fontSize number|nil font size (default: 16)
---@field showConfidence boolean|nil whether to show confidence level

---Enhanced side configuration
---@class SBJ__SideConfig:table
---@field field string side field identifier ('c' or 'u')
---@field enemySide string enemy side name
---@field displayName string human-readable side name

---Dynamic Fire Support Plan Types
---@class SBJ__ReconScheduleEntry
---@field time string Reconnaissance time "2027-06-09 14:30:00"
---@field type string Reconnaissance type "satellite" | "aircraft"
---@field delay number Delay trigger time (seconds)
---@field executed boolean Whether already executed
---@field fsemTemplate SBJ__FsemTemplate FSEM template

---@class SBJ__FsemTemplate
---@field name string FSEM name
---@field isFirstWave boolean Whether it's the first wave attack
---@field strikeInterval number Strike interval time (seconds)
---@field FSTs SBJ__FstTemplate[] FST template array

---@class SBJ__FstTemplate
---@field name string FST name
---@field target SBJ__TargetTemplate Target configuration
---@field wpnSystem string Weapon system type
---@field batteries SBJ__Battery[] Battery/fire unit array

---@class SBJ__TargetTemplate
---@field objs table[]? Target object array (for fixed targets)
---@field areas string[] Operation areas
---@field filterNames string[]? Filter function names (for dynamic targets)
---@field contactAge number Contact valid time (seconds)
---@field minTargetCount number Minimum target count threshold
---@field ammoPerTarget number Ammunition count per target

---@class SBJ__DynamicFSPConfig
---@field enabled boolean Whether to enable dynamic fire support plan
---@field reconSchedule SBJ__ReconScheduleEntry[] Reconnaissance schedule

---@class SBJ__BatteryAssignment
---@field guid string Fire unit GUID
---@field battery table Fire unit data

---Dynamic ATO Insertion Types
---@class SBJ__ATOTemplate
---@field name string ATO wave name
---@field targetType string Target type ("STRIKE", "SEAD", etc.)
---@field isFirstWave boolean Whether it's the first wave attack
---@field strikeInterval number Strike interval time (seconds)
---@field packages SBJ__ATOPackage[] ATO package array

---@class SBJ__ATOPackage:SBJ__Task
---@field striker SBJ__MissionEntry? Main striker configuration
---@field escort SBJ__MissionEntry? Escort configuration
---@field wildWeasel SBJ__MissionEntry? Wild Weasel configuration
---@field jammer SBJ__MissionEntry? Jammer configuration
---@field tanker SBJ__MissionEntry? Tanker configuration
---@field timeToReady number? Ready time (minutes)

---@class SBJ__GPSJammerData:table
---@field name string
---@field zoneName string
---@field point CMO__Location
---@field randomRadius number
---@field radius number
