-- ============================================================================
-- CMO Game API Types
-- ============================================================================
-- CMO native API type definitions provided by the game engine

--- Display weapon allocation from attacker to target
--- Example: ScenEdit_WeaponAllocation('attackerGUID', '', '') - Supply attacker GUID and empty contact to see salvos from the attacker to anyone
--- Example: ScenEdit_WeaponAllocation('', 'contactGUID', 'attackingSideGUID') - Supply contact GUID and empty attacker to see salvos against contact. Note: you MUST supply the side from which attacks are coming from
--- Example: ScenEdit_WeaponAllocation('attackerGUID', 'contactGUID', '') - Supply attacker and contact GUIDs to see salvos generated between the two
---@param attackerGUID string The GUID of the attacker unit
---@param contactGUID string The GUID of the target contact
---@param attackingSideGUID string The GUID of the attacking side
---@return table|nil Returns a weapon allocation table
function ScenEdit_WeaponAllocation(attackerGUID, contactGUID, attackingSideGUID) end

--- Create a new flight plan for a mission
---@param side string The mission side
---@param missionName string The mission name or GUID
---@param opts CMO__FlightPlanOptions The options for the flight plan
---@return table<number, any> Returns all the flights on the mission (currently only returns the first flight, will be fixed in an upcoming release)
function ScenEdit_CreateMissionFlightPlan(side, missionName, opts) end

--- Unit OODA (Observe, Orient, Decide, Act) loop characteristics
---@class CMO__OODA:table
---@field evasion number The evasion of the unit
---@field targeting number The targeting of the unit
---@field detection number The detection of the unit

--- Flight plan options for creating mission flight plans
---@class CMO__FlightPlanOptions:table
---@field DATEONTARGET string The mission time on target day, YYYY/MM/DD
---@field TIMEONTARGET string The mission time on target, HH:MM:SS
---@field TAKEOFFDATE string The takeoff date, YYYY/MM/DD
---@field TAKEOFFTIME string The takeoff time, HH:MM:SS

--- Zone definition (No-Navigation or Exclusion Zone)
---@class CMO__Zone:table
---@field guid string The GUID of the zone (READ ONLY)
---@field type string The type of the zone: 'NoNavZone' = 0, 'ExclusionZone' = 1
---@field description string The description of the zone
---@field isactive boolean Zone is currently active
---@field area CMO__TableOfReferencePoints A set of reference points marking the zone (can be updated by a list of RPs or a table of new RP values)
---@field affects? table List of unit types (ship, submarine, aircraft, facility)
---@field locked? boolean Zone is locked or not
---@field markas? string Posture of violator of exclusion zone
---@field relativeto? string Unit name or unit GUID of unit to make this zone's area relative to (undocumented - the side of the unit must match)
---@field rename? string Name to rename the description/name to (only applies for calls to ScenEdit_SetZone)
---@field enablers table Table of enablers for the zone (undocumented)


-- ============================================================================
-- Core Configuration & Data
-- ============================================================================
-- Core configuration and persistent data structures

--- Global configuration data structure
---@class SBJ__CONFIG:table

--- Saved data structure for persistent state
---@class SBJ__SaveData:table


-- ============================================================================
-- Faction & Side Configuration
-- ============================================================================
-- Faction configuration related types

--- Side configuration for faction settings
---@class SBJ__SideConfig:table
---@field field string Side field identifier ('c' for China, 'u' for US, 't' for Taiwan)
---@field enemySide string Enemy side name
---@field displayName string Human-readable side name


-- ============================================================================
-- Unit Placement & Deployment Utilities
-- ============================================================================
-- Unit placement and deployment parameters for unitGenerator and other modules

---Linear placement parameters for positioning multiple units in a line
---Temporary parameter pack used for unit placement functions
---@class SBJ__LinearPlacementParams:table
---@field initialLocation {latitude:number|string, longitude:number|string} Starting position
---@field num number Number of units to place
---@field bearing number Direction angle (degrees)
---@field distance number Distance between units (nautical miles)
---@field firstDistance? number Special distance for first unit (optional)

--- Random units descriptor for creating multiple units at random positions
---@class SBJ__RandomUnitsDescriptor:table
---@field centerPoint {lat:number, lon:number} Center point for random positioning
---@field randomRadius number Maximum radius from center point (nautical miles)
---@field autodetectable boolean Whether units are automatically detectable
---@field unitname string Base name for created units (random suffix will be added if useRandomSuffix is true)
---@field sideName string Side name (e.g., 'China', 'Taiwan', 'US')
---@field unitType string Unit type (e.g., 'Facility', 'Ship', 'Submarine', 'Aircraft')
---@field count number Number of units to create
---@field dbids number[] Array of database IDs to randomly select from
---@field useRandomSuffix? boolean Optional: Whether to append random text suffix to unit names (defaults to true)


-- ============================================================================
-- Cargo & Logistics
-- ============================================================================
-- Cargo and logistics types for amphibiousLogistics module

--- Loadout configuration for units
---@class SBJ__Loadout:table
---@field loadoutId number Ammunition configuration ID
---@field name string Loadout display name
---@field num number Unit count

--- Cargo descriptor defining parameters for creating cargo units on ships
---@class SBJ__CargoDescriptor:table
---@field type number Cargo type identifier
---@field num number Quantity of cargo items to create
---@field dbid number Database ID of the cargo platform

--- Transfer cargo organized by loadout configuration
---@class SBJ__TransferCargoByLoadout:table
---@field loadoutId number Loadout configuration ID
---@field cargoItems table<number, SBJ__CargoDescriptor[]> Cargo items indexed by configuration number

--- Cargo transfer manifest by ship type
---@class SBJ__CargoForTransfer:table
---@field type075 SBJ__TransferCargoByLoadout[] Type 075 ship cargo manifest
---@field type071 SBJ__TransferCargoByLoadout[] Type 071 ship cargo manifest


-- ============================================================================
-- Airbase & Embarked Units
-- ============================================================================
-- Airbase and embarked unit configuration

--- Embarked unit configuration for ships and airbases
---@class SBJ__EmbarkedUnit:table
---@field side string Side name (e.g., 'China', 'Taiwan', 'US')
---@field type string Unit type (e.g., 'Aircraft', 'Helicopter')
---@field name string Unit name
---@field platformName string Display name of aircraft platform
---@field dbid number Unit database ID
---@field loadouts? SBJ__Loadout[] Unit ammunition configuration (optional)

---Airbase deployment descriptor
---Comprehensive configuration for aircraft deployment and ammunition stockpile at an airbase
---Used for scenario initialization and deployment planning
---@class SBJ__AirbaseDeploymentDescriptor:table
---@field name string Airbase name
---@field baseGUID? string Airbase unit GUID reference
---@field dbid? number  Database ID if the object is a ship
---@field embarkedUnits SBJ__EmbarkedUnit[] Aircraft units stationed at this base
---@field loadouts SBJ__Loadout[] Ammunition stockpile in base magazines


-- ============================================================================
-- Naval Operations
-- ============================================================================
-- Naval operations types for shipMovement and other modules

--- Starting location definition with heading
---@class SBJ__From:table
---@field startingPoint {lat:number, lon:number} Starting coordinates
---@field heading number Initial heading angle

--- Destination area definition
---@class SBJ__To:table
---@field area CMO__Location[] Destination area waypoints

--- Destination staging area with anchorage zones
---@class SBJ__ToStagingArea:SBJ__To
---@field archorageArea CMO__Location[] Anchorage area waypoints
---@field amphibiousVehicleStagingArea CMO__Location[] Amphibious vehicle staging area waypoints
---@field heading number Formation heading angle

--- Formation heading configuration
---@class SBJ__FormationHeading:table
---@field horizontal number Horizontal spacing angle
---@field vertical number Vertical spacing angle
---@field destination CMO__Location[] Destination waypoints

--- Submarine waypoint definition with depth control
---@class SBJ__SubmarineWaypoint:table
---@field lat number|string Latitude coordinate (can be number or string format like 'N 25.07.57')
---@field lon number|string Longitude coordinate (can be number or string format like 'E 122.46.06')
---@field presetDepth number Preset depth for this waypoint (depth in meters)

--- Submarine descriptor for SLCM operations
---@class SBJ__SubmarineDescriptor:table
---@field name string Submarine name/identifier
---@field guid string Submarine unit GUID (empty string if not yet created)
---@field course SBJ__SubmarineWaypoint[] Submarine patrol route waypoints
---@field from SBJ__From Starting location with heading
---@field weaponDBID number Weapon database ID for SLCM

--- Surface Action Group descriptor
---@class SBJ__SAGDescriptor:table
---@field groupName string Group name
---@field from SBJ__From Starting location
---@field to SBJ__ToStagingArea Destination staging area
---@field unitList table<string, SBJ__AirbaseDeploymentDescriptor> Unit list indexed by unit name
---@field area string[] Operational area reference points
---@field missionName? string Mission name (optional)

--- Carrier Strike Group descriptor
---@class SBJ__CSGDescriptor:table
---@field groupName string Group name
---@field from SBJ__From Starting location
---@field to SBJ__To Destination area
---@field unitList table<string, SBJ__AirbaseDeploymentDescriptor> Unit list indexed by unit name


-- ============================================================================
-- Amphibious Operations
-- ============================================================================
-- Amphibious operations types for amphibiousAssault and landingOps modules

--- Barge context for tracking barge operations and associated units
---@class SBJ__BargeContext:table
---@field guid string Barge unit GUID
---@field bridgeGUID? string Bridge unit GUID for barge connection (optional)
---@field roros string[] Array of RORO ship GUIDs transported by this barge

--- Ship position calculation result for amphibious operation planning
---@class SBJ__ShipCalculationResult:table
---@field locations CMO__Location[] Calculated positions for ship formation
---@field locationIndex number Current position index in the locations array
---@field dbid number Platform database ID for this ship type

--- Operation zone calculation result containing all ship type positions
---@class SBJ__OperationZoneCalculation:table
---@field name string Operation zone name (e.g., 'Taoyuan', 'Penghu', 'Sishu')
---@field result table<string, SBJ__ShipCalculationResult> Ship type calculation results indexed by ship type name (type075, type071, type076, type072iii, type072a, type073a, type071InLSTArea, ferry, roro, barge)

--- Amphibious operations context managing all amphibious operation state
---@class SBJ__PHIBOPContext:table
---@field startTime string Operation start time
---@field isTesting boolean Whether in testing mode
---@field isShipsStartedMoving boolean Whether ships have started moving
---@field isWaitingForShipArrival boolean Whether waiting for ship arrival
---@field amphibiousAssaultStartTime? number Amphibious assault start timestamp (optional)
---@field isWaitingForAmphibiousAssault boolean Whether waiting for amphibious assault
---@field isWaitingForSecondWaveUnloading boolean Whether waiting for second wave unloading
---@field airlandingMissionStartTime? number Air landing mission start timestamp (optional)
---@field calculations table<string, SBJ__OperationZoneCalculation> Operation zone calculations indexed by zone name
---@field barges table<string, SBJ__BargeContext> Barge contexts indexed by barge GUID

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

--- Landing mission descriptor for amphibious operations
---@class SBJ__LandingMissionDescriptor:table
---@field name string Mission name
---@field loadoutId number Loadout configuration ID
---@field num number Number of units
---@field startTime number Mission start time

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

---@class SBJ__LACMContext:table
---@field isActivated boolean Whether LACM is activated
---@field startTime string LACM start time

-- ============================================================================
-- Air Operations & Missions
-- ============================================================================
-- Air operations and mission types for assignMission and other modules

--- Mission parameters defining basic mission characteristics
---@class SBJ__MissionParams:table
---@field name string The name of the mission
---@field side string The side of the mission
---@field type string The type of the mission
---@field opts CMO__Mission The options for the mission

--- Mission entry configuration for air operations
---@class SBJ__MissionEntry:table
---@field baseGUID string The GUID of the base to use for the mission
---@field missionParams SBJ__MissionParams The parameters for the mission
---@field unitCount number The number of units to assign to the mission
---@field weaponDBID? number The weapon DBID to use for the mission (optional)
---@field unitDBID? number The unit DBID to use for the mission (optional)
---@field loadoutId? number The loadout ID to filter by, 0 for any loadout (optional)
---@field startTime string The start time of the mission
---@field endTime? string The end time of the mission (optional)

--- Air operations context managing air tasking orders and aircraft status
---@class SBJ__AirOperationsContext:table
---@field landBased table Land-based aircraft context (reserved for future use)
---@field shipBased table Ship-based aircraft context (reserved for future use)
---@field isActivated boolean Whether air operations system is activated
---@field ATO table<string, SBJ__Wave> Air Tasking Order waves indexed by wave name


-- ============================================================================
-- Launcher & TEL Systems
-- ============================================================================
-- Launcher and Transporter-Erector-Launcher (TEL) systems for launcher module

--- Area mode parameters for defining operational areas
---@class SBJ__AreaMode:table
---@field side string Side name
---@field shape string Area shape type
---@field distance number Distance parameter
---@field name? string Area name (optional)
---@field bear_offset? number Bearing offset (optional)

--- Position definition with course and area reference points
---@class SBJ__Position:table
---@field course CMO__TableOfWaypoints Waypoints to area
---@field area string[] Area reference points, e.g., {"rp-100","rp-101","rp-102","rp-103","rp-104"}

--- Operational area definition with multiple position types
---@class SBJ__OPAREA:table
---@field FP SBJ__Position[] Firing Position
---@field HA? SBJ__Position[] Hide Area (optional)
---@field AHA SBJ__Position[] Alternative Hide Area
---@field RL SBJ__Position[] Reload Location

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
---@field reloadStartTime? number Reload operation start timestamp, nil if not currently reloading
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

--- Ground force context data structure, manages all ground-based weapon systems and fire support operations
---@class SBJ__GroundForceContext:table
---@field isActivated boolean Whether ground force systems are activated
---@field mlrs SBJ__WeaponSystemContext Multiple Launch Rocket System
---@field srbm SBJ__WeaponSystemContext Short-Range Ballistic Missile system
---@field mrbm SBJ__WeaponSystemContext Medium-Range Ballistic Missile system
---@field glcm SBJ__WeaponSystemContext Ground-Launched Cruise Missile system
---@field ascm SBJ__WeaponSystemContext Anti-Ship Cruise Missile system
---@field FSP table<string, SBJ__FireSupportExecutionMatrix> Fire Support Plan execution matrices


-- ============================================================================
-- Strike Planning & Targeting
-- ============================================================================
-- Strike planning and targeting types for strikePlanner module

--- Target query parameter for filtering targets by base name and facility sub-types
---@class SBJ__TargetQueryParam:table
---@field baseName? string Base name pattern for matching (optional, if omitted matches all)
---@field subTypes string[] Array of facility sub-type patterns to match

--- Target template for strike planning
---@class SBJ__TargetTemplate
---@field objs? SBJ__TargetQueryParam[] Target query parameters (for fixed targets, optional)
---@field areas string[] Operation areas
---@field filterNames? string[] Filter function names (for dynamic targets, optional)
---@field contactAge number Contact valid time (seconds)
---@field minTargetCount number Minimum target count threshold
---@field ammoPerTarget number Ammunition count per target

--- Target definition extending template with contact list
---@class SBJ__Target:SBJ__TargetTemplate
---@field list string[] List of target contact GUIDs

--- Task definition with target information
---@class SBJ__Task:table
---@field target SBJ__Target Target information

--- Filter parameters for target selection and filtering
---@class SBJ__FilterParams:table
---@field config SBJ__CONFIG Configuration data
---@field saveData SBJ__SaveData Saved data
---@field task SBJ__Task Task information
---@field contacts CMO__Contact[] Contact array
---@field shouldTrack? boolean Whether to track contacts (optional)

--- Firing unit definition for fire support operations
---@class SBJ__FiringUnit:table
---@field name string Firing unit name
---@field guid string Firing unit GUID
---@field weaponDBID number Firing unit weapon database ID

--- Fire Support Task template extending task with firing units
---@class SBJ__FSTTemplate:SBJ__Task
---@field name string FST name
---@field wpnSystem string Weapon system type
---@field firingUnits SBJ__FiringUnit[] Firing unit array

--- Fire Support Task execution state
---@class SBJ__FireSupportTask: SBJ__FSTTemplate
---@field startTime string Task start time
---@field isFinished boolean Whether task is finished

--- Fire Support Execution Matrix template
---@class SBJ__FSEMTemplate:table
---@field name string FSEM name
---@field isFirstWave boolean Whether it's the first wave attack
---@field strikeInterval number Strike interval time (seconds)
---@field FSTs SBJ__FSTTemplate[] FST template array

--- Fire Support Execution Matrix with execution state
---@class SBJ__FireSupportExecutionMatrix:SBJ__FSEMTemplate
---@field isActivated boolean Whether FSEM is activated
---@field allFiringUnitsInPosition boolean Whether all firing units are in position
---@field isFinished boolean Whether FSEM is finished
---@field FSTs SBJ__FireSupportTask[] Fire support tasks array

--- Attack contacts parameters for coordinating strikes
---@class SBJ__AttackContacts_Params:table
---@field contacts table<integer, string> A table of contact GUIDs to attack
---@field qty number The number of salvos to launch
---@field firingUnits table<string, SBJ__FiringUnitContext> A table of firing units to use for the attack
---@field weaponDBID? number The weapon DBID to use for the attack (if not specified, the default weapon will be used)
---@field side? string The side to use for the attack (if not specified, the side of the first firing unit will be used)

--- Parameters for generating missile flight paths
---@class SBJ__GenerateMissilePaths_Params
---@field targetLat number Target latitude
---@field targetLon number Target longitude
---@field launcherLat number Launcher latitude
---@field launcherLon number Launcher longitude
---@field radarRange number Radar range (nautical miles)
---@field missileCount? number Number of missiles (default is 5)
---@field missileSpeedKts? number Missile speed in knots (default is 600)
---@field missileRangeNm? number Maximum missile range in nautical miles (default is 100)

--- Missile path definition with waypoints and timing
---@class SBJ__MissilePath
---@field waypoints table<integer, CMO__Location> Missile waypoint list
---@field launchTime number Launch time (UTC timestamp)


-- ============================================================================
-- Reconnaissance & Intelligence
-- ============================================================================
-- Reconnaissance and intelligence types for recon module

--- Reconnaissance UAV template configuration for defining reconnaissance UAV mission parameters
---@class SBJ__ReconUAVTemplate:table
---@field baseGUID string Base GUID where UAV is stationed
---@field unitDBID number UAV platform database ID
---@field unitGUID? string UAV unit GUID (nil if not yet created)
---@field course CMO__TableOfWaypoints Waypoints for reconnaissance route
---@field unitCount number Number of UAVs to deploy
---@field speed number Cruise speed in knots for tracking mode
---@field takeoffTime? string Scheduled takeoff time in format "YYYY-MM-DD HH:MM:SS" (optional)
---@field isTracking? boolean Whether to track this reconnaissance mission (optional)
---@field endTime? string Scheduled end time in format "YYYY-MM-DD HH:MM:SS" (optional)

--- Reconnaissance queue entry extending template with execution state
---@class SBJ__ReconQueueEntry:SBJ__ReconUAVTemplate
---@field hasLaunched boolean Whether reconnaissance mission has launched
---@field isFinished? boolean Whether reconnaissance mission has finished (optional)
---@field trackingTargetGUID? string Target contact GUID being tracked (optional, only used when isTracking is true)

--- Reconnaissance context managing reconnaissance operations state
---@class SBJ__ReconContext:table
---@field isActivated boolean Whether reconnaissance system is activated
---@field queue SBJ__ReconQueueEntry[] Reconnaissance mission queue


-- ============================================================================
-- Dynamic Operations (ATO/FSEM)
-- ============================================================================
-- Dynamic operations types for dynamicATOInsertion and dynamicFireSupportPlan modules

--- Generated operations tracker for dynamic operations
---@class SBJ__GeneratedOperationsTracker:table
---@field air table<string, boolean> Generated air operation names indexed by operation name
---@field ground table<string, boolean> Generated ground operation names indexed by operation name

--- Dynamic operations context managing intelligence-driven adaptive strike planning
---@class SBJ__DynamicOperationsContext:table
---@field enabled boolean Whether dynamic operations system is enabled
---@field lastEvaluationTime? number Last evaluation timestamp (Unix time)
---@field generatedOperations SBJ__GeneratedOperationsTracker Generated operation name tracker
---@field reconSchedule SBJ__ReconScheduleEntry[] Reconnaissance-driven operation schedule

--- Reconnaissance schedule entry for intelligence gathering operations
---@class SBJ__ReconScheduleEntry
---@field time string Reconnaissance time in format "2027-06-09 14:30:00"
---@field type string Reconnaissance type: "satellite", "aircraft", or "UAV"
---@field delay number Delay trigger time (seconds)
---@field executed boolean Whether already executed
---@field operations SBJ__Operation[] Operations to execute

--- Operation definition for dynamic operations
---@class SBJ__Operation:table
---@field type string Template type
---@field executed boolean Whether operation has been executed
---@field template SBJ__FSEMTemplate|SBJ__WaveTemplate Operation template (FSEM or Wave)
---@field executionResult? boolean Operation execution result (true for success, false for failure)

--- Wave template for Dynamic ATO Insertion
---@class SBJ__WaveTemplate:table
---@field name string ATO wave name
---@field isFirstWave boolean Whether it's the first wave attack
---@field strikeInterval number Strike interval time (seconds)
---@field packages SBJ__PackageTemplate[] ATO package array

--- Package template for air operation coordination
---@class SBJ__PackageTemplate:SBJ__Task
---@field striker? SBJ__MissionEntry Main striker configuration (optional)
---@field escort? SBJ__MissionEntry Escort configuration (optional)
---@field wildWeasel? SBJ__MissionEntry Wild Weasel configuration (optional)
---@field jammer? SBJ__MissionEntry Jammer configuration (optional)
---@field tanker? SBJ__MissionEntry Tanker configuration (optional)
---@field reconUAV? SBJ__ReconUAVTemplate Reconnaissance UAV configuration (optional)
---@field timeToReady? number Ready time in minutes (optional)

--- Loadout status tracking for mission preparation
---@class SBJ__LoadoutStatus:table
---@field isLoadoutInitiated boolean Whether loadout process has started
---@field loadoutInitiatedTime number Loadout initiation timestamp
---@field expectedReadyTime number Expected ready timestamp
---@field loadoutStartTime number Loadout start timestamp

--- Package execution state extending template with launch and loadout status
---@class SBJ__Package:SBJ__PackageTemplate
---@field hasLaunched boolean Whether package has launched
---@field loadoutStatus SBJ__LoadoutStatus Loadout preparation status

--- Wave execution state with packages and activation status
---@class SBJ__Wave:table
---@field packages SBJ__Package[] Array of packages in this wave
---@field hasLaunched boolean Whether wave has launched
---@field isActivated boolean Whether wave is activated


-- ============================================================================
-- Electronic Warfare
-- ============================================================================
-- Electronic warfare types for EW modules (SIGINT, GPS Jamming, Comms Jamming)

---GPS jammer deployment descriptor
---Serves as a blueprint for creating jammer units, related events, and jamming zones
---@class SBJ__GPSJammerDescriptor
---@field name string Jammer unit identifier
---@field zoneName string Associated jamming zone name for area creation
---@field point CMO__Location Deployment coordinates
---@field randomRadius number Position randomization radius (kilometers)
---@field radius number GPS jamming effectiveness radius (nautical miles)

--- SIGINT detection configuration parameters
---@class SBJ__SIGINTConfig:table
---@field detectionThreshold number Minimum detection range
---@field maxRange table Maximum detection range as {min, max}
---@field decayRate number Signal decay rate
---@field randomFactor number Random deviation factor
---@field displayConfig SBJ__SIGINTDisplayData Default display settings

--- Enhanced SIGINT detection result with confidence and metadata
---@class SBJ__SIGINTResult:table
---@field longitude number Detected longitude coordinate
---@field latitude number Detected latitude coordinate
---@field isDetected boolean Whether signal is detected
---@field confidence number Detection confidence level (0-1)
---@field detectorId? string ID of detecting unit (optional)
---@field timestamp number Detection timestamp

---Radio transmission context data structure
---Tracks and manages detected radio transmission sources with contextual information
---@class SBJ__RadioTransmissionContext:table
---@field name string Unit name of the transmission source
---@field guid string Unit GUID of the transmission source
---@field msg string Message content
---@field type string Type of the transmission source
---@field latitude number Latitude of the transmission source
---@field longitude number Longitude of the transmission source
---@field contacts table Contact list associated with this transmission
---@field currentDetectionLevel number Current detection level (increases on detection, decreases when undetected, determines autodetectable threshold)
---@field autodetectable boolean Whether the transmission can be automatically detected
---@field firstDetected number Timestamp of first detection
---@field lastDetected number Timestamp of last detection
---@field detectionCount number Number of times this transmission has been detected
---@field confidence number Confidence level/reliability of the detection

--- Enhanced SIGINT display data configuration
---@class SBJ__SIGINTDisplayData:table
---@field R? number Red value (default: 255)
---@field G? number Green value (default: 255)
---@field B? number Blue value (default: 255)
---@field lifeTime? number Display time in seconds (default: 4)
---@field fontSize? number Font size (default: 16)
---@field showConfidence? boolean Whether to show confidence level

--- SIGINT context managing all transmission tracking
---@class SBJ__SIGINTContext:table
---@field transmissions table<string, SBJ__RadioTransmissionContext> Radio transmission contexts indexed by GUID
---@field RA table<string, SBJ__AircraftContext> Recon aircraft context data structure indexed by GUID
---@field isActivated boolean Whether SIGINT is activated
---@field maxCount number Maximum detection level

--- Communications jamming context managing electronic warfare jamming operations
---@class SBJ__CommsJammingContext:table
---@field isActivated boolean Whether communications jamming system is activated
---@field jammers table<string, SBJ__AircraftContext> Jamming aircraft indexed by GUID


-- ============================================================================
-- Command & Control (C2) and IADS
-- ============================================================================
-- Command & Control and Integrated Air Defense System types for IADS module

--- Radar context for tracking radar status and communications
---@class SBJ__RadarContext:table
---@field name string Radar unit name
---@field guid string Radar unit GUID
---@field OODA CMO__OODA Radar OODA data
---@field currOODA CMO__OODA Current OODA state
---@field isOutOfComms boolean Whether the radar is out of communications
---@field outofcomms number Radar out of communications threshold

--- Command and Control (C2) context data structure
---@class SBJ__C2Context:table
---@field name string C2 node name
---@field msg string Status message
---@field guid string C2 node GUID
---@field areas table<number, string[]> Associated operational areas
---@field SAM table<string, SBJ__RadarContext> Surface-to-Air Missile systems
---@field radar? table<string, SBJ__RadarContext> Radar systems (optional)

--- C2 node deployment descriptor defining how to create a single C2 node
---@class SBJ__C2Descriptor:table
---@field position CMO__Location C2 position coordinates
---@field areas string[][] Operation areas array
---@field areaName string Operation area name

--- Integrated Air Defense System configuration defining C2 facility parameters and deployment settings
---@class SBJ__IADSConfig:table
---@field ratio {C2:number} C2 facility ratio multiplier
---@field C2FacilityDBIDs number[] Database IDs for C2 facility types
---@field randomRadius number Random deployment radius (nautical miles)
---@field C2Settings SBJ__C2Descriptor[] C2 node deployment descriptors

--- IADS context managing air defense system state
---@class SBJ__IADSContext:table
---@field C2? table<string, SBJ__C2Context> C2 node context data structure indexed by GUID (optional)
---@field ROCC? table<string, SBJ__C2Context> ROCC context data structure indexed by GUID (optional)
---@field TAAOC? table<string, SBJ__C2Context> TAAOC context data structure indexed by GUID (optional)
---@field isActivated boolean Whether IADS is activated


-- ============================================================================
-- Aircraft & Communications Tracking
-- ============================================================================
-- Aircraft and communications tracking types for commsJamming and other modules

--- Aircraft context for tracking aircraft status and communications
---@class SBJ__AircraftContext:table
---@field guid string Aircraft unit GUID
---@field OODA CMO__OODA Aircraft OODA data
---@field commsLevel number Aircraft communications level
---@field commsBase number Aircraft communications base level
---@field commsThreshold number Aircraft communications threshold
---@field outofcomms number Aircraft out of communications threshold

--- Land-based platform context tracking aircraft and AEW
---@class SBJ__LandBasedPlatformContext:table
---@field AC table<string, SBJ__AircraftContext> Aircraft context data structure indexed by GUID
---@field AEW table<string, SBJ__AircraftContext> AEW aircraft context data structure indexed by GUID
