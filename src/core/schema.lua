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

---Linear placement parameters for positioning multiple units in a line
---Temporary parameter pack used for unit placement functions
---@class SBJ__LinearPlacementParams:table
---@field initialLocation {latitude:number|string, longitude:number|string} Starting position
---@field num number Number of units to place
---@field bearing number Direction angle (degrees)
---@field distance number Distance between units (nautical miles)
---@field firstDistance? number Special distance for first unit (optional)

---ACV deployment parameters for launching air cushion vehicles
---Temporary parameter pack used for ACV deployment functions
---@class SBJ__ACVDeploymentParams:table
---@field bearing number Deployment direction (degrees)
---@field distance number Deployment distance (nautical miles)
---@field ship CMO__Unit Parent landing ship
---@field speed number ACV movement speed (knots)
---@field destination CMO__TableOfWaypoints ACV destination waypoints

---Vehicle offload parameters for unloading vehicles from landing ships
---Temporary parameter pack used for vehicle offloading functions
---@class SBJ__VehicleOffloadParams:table
---@field ship CMO__Unit Landing ship to offload from
---@field num number Number of vehicles to offload
---@field bearing number Offload direction (degrees)
---@field distance number Distance between vehicles (nautical miles)
---@field firstDistance number Distance for first vehicle (nautical miles)

---@class SBJ__AreaMode:table
---@field side string
---@field shape string
---@field distance number
---@field name string|nil
---@field bear_offset number|nil

---@class SBJ__Position:table
---@field course CMO__TableOfWaypoints @Waypoints to area
---@field area string[]  EX:{"rp-100","rp-101","rp-102","rp-103","rp-104"}

---@class SBJ__OPAREA:table
---@field FP SBJ__Position[]
---@field HA? SBJ__Position[]
---@field AHA SBJ__Position[]
---@field RL SBJ__Position[]

--- Ammunition context data structure for tracking ammunition unit status and counts
---@class SBJ__AmmunitionContext:table
---@field guid string Ammunition unit GUID
---@field wpnCurrent number Current available ammunition count
---@field wpnDefault number Default/maximum ammunition count

--- Resupply unit context data structure, extends AmmunitionContext with operational area and resupply management
---@class SBJ__ResupplyUnitContext:SBJ__AmmunitionContext
---@field name string Resupply unit name
---@field unitCount number Number of resupply vehicles in this unit
---@field OPAREA SBJ__OPAREA Operational area definition for this resupply unit
---@field reloadStartTime number|nil Reload operation start timestamp, nil if not currently reloading
---@field state batteryState Current unit state (STATIC/HIDE, etc.)
---@field ammunition string Associated ammunition unit GUID for this resupply unit

--- Firing unit context data structure, extends ResupplyUnitContext with weapon system configuration
---@class SBJ__FiringUnitContext:SBJ__ResupplyUnitContext
---@field weaponDBID number The weapon database ID to use for the firing unit
---@field ammoThreshold number The ammunition threshold for the firing unit, if not specified, the default value will be used
---@field resupplyUnit string The resupply unit GUID associated with this firing unit
---@field msg string The status message to display for the firing unit

--- Weapon system context data structure, consolidates all components of a complete weapon system
---@class SBJ__WeaponSystemContext:table
---@field isActivated boolean Whether the weapon system is currently active
---@field reloadTime number Reload time for all firing units/resupply units in this system (seconds)
---@field OPAREAs table<string, SBJ__OPAREA> Operational areas indexed by area name for this weapon system
---@field firingUnits table<string, SBJ__FiringUnitContext> Firing units indexed by GUID for attack operations
---@field resupplyUnits table<string, SBJ__ResupplyUnitContext> Resupply units indexed by GUID for ammunition replenishment
---@field ammunitions table<string, SBJ__AmmunitionContext> Ammunition units indexed by GUID for tracking available munitions

---@class SBJ__C2Context:table
---@field name string
---@field msg string
---@field guid string
---@field areas table<number, string[]>
---@field SAM table
---@field radar? table

---@class SBJ__AttackContacts_Params:table
---@field contacts table<integer, string> -- A table of contact GUIDs to attack
---@field qty number -- The number of salvos to launch
---@field firingUnits table<string, SBJ__FiringUnitContext> -- A table of firing units to use for the attack
---@field weaponDBID? number -- The weapon DBID to use for the attack, if not specified, the default weapon will be used
---@field side? string -- The side to use for the attack, if not specified, the side of the first firing unit will be used

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


---@class SBJ__LandingMissionDescriptor:table
---@field name string
---@field loadoutId number
---@field num number
---@field startTime number

---Air Cushion Vehicle deployment configuration
---@class SBJ__ACVConfig:table
---@field bearing number Deployment direction (degrees)
---@field distance number Horizontal spacing between ACVs (nautical miles)
---@field speed number ACV transit speed (knots)
---@field destination CMO__TableOfWaypoints Destination waypoints
---@field area string[] Staging area reference points

---Landing craft mission configuration
---Used for boat-based amphibious landings
---@class SBJ__BoatMissionConfig:table
---@field dbid number Landing craft platform database ID
---@field missions SBJ__LandingMissionDescriptor[] Landing mission descriptors
---@field zone string[] Landing zone reference points
---@field settings CMO__Mission Mission behavior settings (Subtype, throttle, active status)
---@field cargoItemsForTransfer SBJ__CargoForTransfer Cargo manifest by ship type

---Transport helicopter mission configuration
---Used for air assault operations
---@class SBJ__TransportHelicopterConfig:table
---@field dbid number Helicopter platform database ID
---@field missions SBJ__LandingMissionDescriptor[] Air landing mission descriptors
---@field zone string[] Landing zone reference points
---@field settings CMO__Mission Mission behavior settings (Subtype, throttle, altitude, active status)
---@field cargoItemsForTransfer SBJ__CargoForTransfer Cargo manifest by ship type

---Attack helicopter mission configuration
---Used for close air support during landings
---@class SBJ__AttackHelicopterConfig:table
---@field dbid number Attack helicopter platform database ID
---@field missions SBJ__LandingMissionDescriptor[] CAS mission descriptors

---Landing Ship Tank movement configuration
---Defines LST approach to beach
---@class SBJ__LSTMovementConfig:table
---@field speed number LST transit speed (knots)
---@field course {bearing:number, distance:number} Approach course (bearing in degrees, distance in nautical miles)

---Reconnaissance UAV mission configuration
---Used for ISR support during amphibious operations
---@class SBJ__ReconUAVConfig:table
---@field dbid number UAV platform database ID
---@field missions SBJ__LandingMissionDescriptor[] Reconnaissance mission descriptors

---Operational zone descriptor for amphibious operations
---Defines complete landing zone configuration including air and surface assets
---@class SBJ__OperationZoneDescriptor:table
---@field name string Operational zone name
---@field baseGUID string Home base GUID for embarked units
---@field anchorageArea string[] LHD/LPD anchorage area reference points
---@field LSTAnchorageArea string[] LST anchorage area reference points
---@field area string[] General operational area reference points
---@field offloadArea string[] Vehicle offload area reference points
---@field boat SBJ__BoatMissionConfig Landing craft configuration
---@field tansportHelicopter SBJ__TransportHelicopterConfig Transport helicopter configuration
---@field attackHelicopter SBJ__AttackHelicopterConfig Attack helicopter configuration
---@field LSTSettings SBJ__LSTMovementConfig LST movement configuration
---@field ACV SBJ__ACVConfig Air cushion vehicle configuration
---@field reconUAV? SBJ__ReconUAVConfig Reconnaissance UAV configuration (optional)

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
---@field firingUnits SBJ__FiringUnitContext[]
---@field startTime string
---@field isFinished boolean

---@class SBJ__FireSupportExecutionMatrix:table
---@field name string
---@field isActivated boolean
---@field isFirstWave boolean
---@field strikeInterval number
---@field reconUAVs table
---@field allFiringUnitsInPosition boolean
---@field isFinished boolean
---@field FSTs SBJ__FireSupportTask[]

---@class SBJ__FilterParams:table
---@field config SBJ__CONFIG
---@field saveData SBJ__SaveData
---@field task SBJ__Task
---@field contacts CMO__Contact[]
---@field shouldTrack? boolean


--------------------------------------------------------------------
---@class SBJ__CargoForTransfer:table
---@field type075 SBJ__TransferCargoByLoadout[]
---@field type071 SBJ__TransferCargoByLoadout[]

---@class SBJ__TransferCargoByLoadout:table
---@field loadoutId number
---@field cargoItems table<number, SBJ__CargoDescriptor[]>

---Cargo descriptor - defines parameters for creating cargo units on ships
---Used to specify what type and quantity of cargo to create
---@class SBJ__CargoDescriptor:table
---@field type number Cargo type identifier
---@field num number Quantity of cargo items to create
---@field dbid number Database ID of the cargo platform

------------------------------------------------------------------------
---@class SBJ__Loadout:table
---@field loadoutId number Ammunition configuration ID
---@field name string Loadout display name
---@field num number Unit count

---@class SBJ__EmbarkedUnit:table
---@field side string Side name
---@field type string Unit type
---@field name string Unit name
---@field platformName string Display name of aircraft platform
---@field dbid number Unit database ID
---@field loadouts SBJ__Loadout[]|nil Unit ammunition configuration

---@class SBJ__From:table
---@field startingPoint {lat:number, lon:number}
---@field heading number

---@class SBJ__To:table
---@field area CMO__Location[]

---@class SBJ__ToStagingArea:SBJ__To
---@field archorageArea CMO__Location[]
---@field amphibiousVehicleStagingArea CMO__Location[]
---@field heading number

---@class SBJ__SAGDescriptor:table
---@field groupName string Group name
---@field from SBJ__From
---@field to SBJ__ToStagingArea
---@field unitList table<string, SBJ__AirbaseDeploymentDescriptor>
---@field area string[]
---@field missionName? string

---@class SBJ__CSGDescriptor:table
---@field groupName string Group name
---@field from SBJ__From
---@field to SBJ__To
---@field unitList table<string, SBJ__AirbaseDeploymentDescriptor>

---@class SBJ__FormationHeading:table
---@field horizontal number
---@field vertical number
---@field destination CMO__Location[]

---Amphibious operation layout configuration - defines spacing and movement parameters for amphibious assault
---Used internally for calculating ship positions during landing operations
---@class SBJ__AmphibiousLayoutConfig:table
---@field distanceBetweenLSTAndLPDArea string Distance between LST and LPD staging areas
---@field horizontalDistance number Horizontal spacing between ships in formation
---@field verticalDistance number Vertical spacing between ships in formation
---@field transitDistance number Distance for transit phase
---@field shipSpeed number Ship movement speed
---@field heading table<string, SBJ__FormationHeading> Formation heading configuration
---@field ACVSpeed number Air Cushion Vehicle speed
---@field ACVTransitDistance number ACV transit distance
---@field ACVHorizontalDistance number ACV horizontal spacing

---Ship type starting point configuration
---@class SBJ__ShipTypeStartPoint:table
---@field side string Side name (e.g., 'China', 'Taiwan')
---@field area string[] Area reference points array

---Ship quantity configuration for amphibious operations
---@class SBJ__ShipQuantity:table
---@field type075 number Number of Type 075 amphibious assault ships
---@field type071 number Number of Type 071 amphibious transport docks
---@field type076 number Number of Type 076 amphibious assault ships
---@field type072iii number Number of Type 072III landing ships
---@field type072a number Number of Type 072A landing ships
---@field type073a number Number of Type 073A landing craft
---@field type071InLSTArea? number Number of Type 071 ships in LST area (optional)
---@field ferry number Number of ferries
---@field roro number Number of roll-on/roll-off ships
---@field barge number Number of barges

---Amphibious operation area descriptor
---@class SBJ__AmphibiousAreaDescriptor:table
---@field startingPoints table<string, SBJ__ShipTypeStartPoint> Starting points for each ship type
---@field heading SBJ__FormationHeading Formation heading angle
---@field num? SBJ__ShipQuantity Ship quantity configuration (optional, only in destination)

---Amphibious operation departure/destination descriptor
---@class SBJ__AmphibiousLocationDescriptor:table
---@field areas SBJ__AmphibiousAreaDescriptor[] Array of area descriptors
---@field stagingArea? string Staging area reference (optional, only in departure)
---@field num? SBJ__ShipQuantity Ship quantity configuration (optional, only in departure)

---Amphibious operation descriptor
---Comprehensive configuration for one amphibious landing operation including departure, destination, and air landing zones
---Used for scenario initialization and deployment planning
---@class SBJ__AmphibOpsDescriptor:table
---@field name string Operation name (e.g., 'Taoyuan', 'Sishu', 'Penghu')
---@field names string[] Unit name array
---@field from SBJ__AmphibiousLocationDescriptor Departure configuration
---@field to SBJ__AmphibiousLocationDescriptor Destination configuration
---@field airLandingZone string[] Air landing zone reference area
---@field numOfContactsInAirLandingZone number Number of contacts required in air landing zone

---Amphibious Operations configuration
---Comprehensive configuration for amphibious assault operations including
---cargo manifests, ship layouts, operational zones, and mission timing
---@class SBJ__AmphibOpsConfig:table
---@field periodOfTime number Check interval in seconds
---@field cargoList table<string, SBJ__CargoDescriptor[]> Cargo manifest by ship type
---@field cargoListForTransfer table<string, SBJ__CargoDescriptor[]> Transfer cargo groups
---@field missionStartime table<string, number[]> Mission start times by type (seconds)
---@field shipSettings SBJ__AmphibiousLayoutConfig Ship layout configuration
---@field initialLocations SBJ__AmphibOpsDescriptor[] Initial deployment descriptors
---@field operationalZones SBJ__OperationZoneDescriptor[] Operation zone descriptors
---@field transportAircraft table[] Transport aircraft configuration
---@field sag table<string, SBJ__SAGDescriptor> Surface Action Group descriptors

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
---@field firingUnits SBJ__FiringUnitContext[] Firing unit array

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

---GPS jammer deployment descriptor
---Serves as a blueprint for creating jammer units, related events, and jamming zones
---@class SBJ__GPSJammerDescriptor
---@field name string Jammer unit identifier
---@field zoneName string Associated jamming zone name for area creation
---@field point CMO__Location Deployment coordinates
---@field randomRadius number Position randomization radius (kilometers)
---@field radius number GPS jamming effectiveness radius (nautical miles)

---Airbase deployment descriptor
---Comprehensive configuration for aircraft deployment and ammunition stockpile at an airbase
---Used for scenario initialization and deployment planning
---@class SBJ__AirbaseDeploymentDescriptor:table
---@field name string Airbase name
---@field baseGUID? string Airbase unit GUID reference
---@field dbid? number  Database ID if the object is a ship
---@field embarkedUnits SBJ__EmbarkedUnit[] Aircraft units stationed at this base
---@field loadouts SBJ__Loadout[] Ammunition stockpile in base magazines

---C2 node deployment descriptor
---Defines how to create a single C2 (Command and Control) node
---@class SBJ__C2Descriptor:table
---@field position CMO__Location C2 position
---@field areas string[][] Operation areas
---@field areaName string Operation area name

---Integrated Air Defense System configuration
---Defines C2 facility parameters and deployment settings
---@class SBJ__IADSConfig:table
---@field ratio {C2:number} C2 facility ratio multiplier
---@field C2FacilityDBIDs number[] Database IDs for C2 facility types
---@field randomRadius number Random deployment radius (nautical miles)
---@field C2Settings SBJ__C2Descriptor[] C2 node deployment descriptors



---Random units descriptor - Configuration for creating multiple units at random positions
---@class SBJ__RandomUnitsDescriptor:table
---@field centerPoint {lat:number, lon:number} Center point for random positioning
---@field randomRadius number Maximum radius from center point (nautical miles)
---@field autodetectable boolean Whether units are automatically detectable
---@field unitname string Base name for created units (random suffix will be added)
---@field sideName string Side name (e.g., 'China', 'Taiwan', 'US')
---@field unitType string Unit type (e.g., 'Facility', 'Ship', 'Submarine', 'Aircraft')
---@field count number Number of units to create
---@field dbids number[] Array of database IDs to randomly select from

---@class SBJ__IADSContext:table
---@field C2? table<string, SBJ__C2Context> C2 node context data structure
---@field ROCC? table<string, SBJ__C2Context> ROCC context data structure
---@field TAAOC? table<string, SBJ__C2Context> TAAOC context data structure
---@field isActivated boolean Whether IADS is activated

---@class SBJ__AircraftContext:table
---@field guid string Aircraft unit GUID
---@field OODA table Aircraft OODA data
---@field commsLevel number Aircraft comms level
---@field commsBase number Aircraft comms base
---@field commsThreshold number Aircraft comms threshold
---@field outofcomms number Aircraft out of comms threshold

---@class SBJ__LandBasedPlatformContext:table
---@field AC table<string, SBJ__AircraftContext> Aircraft context data structure
---@field AEW table<string, SBJ__AircraftContext> AEW aircraft context data structure
