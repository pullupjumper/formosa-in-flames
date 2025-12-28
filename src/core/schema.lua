-- ============================================================================
-- CMO Game API Types
-- ============================================================================
-- CMO native API type definitions provided by the game engine

---Display weapon allocation from attacker to target
---Supply attacker GUID and contact GUID to see salvos between units
---@param attackerGUID string The GUID of the attacker unit
---@param contactGUID string The GUID of the target contact
---@param attackingSideGUID string The GUID of the attacking side
---@return table<integer, { weapon:number, qtyFired:number, shooter:string, target:string, qtyAssigned:number, weaponName:string }>|nil # Returns a weapon allocation table
function ScenEdit_WeaponAllocation(attackerGUID, contactGUID, attackingSideGUID) end

---Create a new flight plan for a mission
---@param sideName string The mission side
---@param missionName string The mission name or GUID
---@param opts CMO__FlightPlanOptions The options for the flight plan
---@return table<number, any>|nil # Returns all the flights on the mission (currently only returns the first flight, will be fixed in an upcoming release)
function ScenEdit_CreateMissionFlightPlan(sideName, missionName, opts) end

---Unit OODA (Observe, Orient, Decide, Act) loop characteristics
---@class CMO__OODA:table
---@field evasion number The evasion of the unit
---@field targeting number The targeting of the unit
---@field detection number The detection of the unit

---Flight plan options for creating mission flight plans
---@class CMO__FlightPlanOptions:table
---@field DATEONTARGET string The mission time on target day, YYYY/MM/DD
---@field TIMEONTARGET string The mission time on target, HH:MM:SS
---@field TAKEOFFDATE string The takeoff date, YYYY/MM/DD
---@field TAKEOFFTIME string The takeoff time, HH:MM:SS

---Zone definition (No-Navigation or Exclusion Zone)
---@class CMO__Zone:table
---@field guid string The GUID of the zone (READ ONLY)
---@field type string The type of the zone: "NoNavZone" = 0, "ExclusionZone" = 1
---@field description string The description of the zone
---@field isactive boolean Zone is currently active
---@field area CMO__TableOfReferencePoints A set of reference points marking the zone (can be updated by a list of RPs or a table of new RP values)
---@field affects? table List of unit types (ship, submarine, aircraft, facility)
---@field locked? boolean Zone is locked or not
---@field markas? string Posture of violator of exclusion zone
---@field relativeto? string Unit name or unit GUID of unit to make this zone"s area relative to (undocumented - the side of the unit must match)
---@field rename? string Name to rename the description/name to (only applies for calls to ScenEdit_SetZone)
---@field enablers table Table of enablers for the zone (undocumented)

---Formation configuration for unit groupings
---@class CMO__FormationGroup:table
---@field name string The name of the formation
---@field spacing number The spacing of the formation
---@field spacing_unit string Multipler to the spacing if required (Opertional)
---@field bearing number The type of formationDesired bearing of formation lead (0-360)
---@field transpose boolean Units jump to the new stations immediately

---Weapon load information on a mount
---@class CMO__Mount:table
---@field mount_dbid number The database ID of the mount
---@field mount_name string The name of the mount
---@field mount_GUID string The GUID of the mount
---@field mount_status string The status of the mount (Active/Inactive/Destroyed)
---@field mount_statusR string Reason why inoperative [if not operational]
---@field mount_damage string Damage Severity [if not operational]
---@field mount_weapons CMO__WeaponLoaded[] Table of weapon loads on mount

---Cargo item information on a unit
---@class CMO__CargoInfo:table
---@field name string The name of the unit
---@field guid string The GUID of the unit
---@field cargo CMO__Cargo[] Table of cargo items on the unit



-- ============================================================================
-- Core Configuration & Data
-- ============================================================================
-- Core configuration and persistent data structures

---Global configuration data structure
---@class SBJ__Config:table

---Saved data structure for persistent state
---@class SBJ__SaveData:table


-- ============================================================================
-- Faction & Side Configuration
-- ============================================================================
-- Faction configuration related types

---Side configuration for faction settings
---@class SBJ__SideConfig:table
---@field field string Side field identifier ("c" for China, "u" for US, "t" for Taiwan)
---@field enemySide string Enemy side name
---@field displayName string Human-readable side name


-- ============================================================================
-- Unit Placement & Deployment Utilities
-- ============================================================================
-- Unit placement and deployment parameters for unitGenerator and other modules

---Linear placement parameters for positioning multiple units in a line
---Temporary parameter pack used for unit placement functions
---@class SBJ__LinearPlacementParams:table
---@field initialLocation CMO__Location Starting position
---@field num number Number of units to place
---@field bearing number Direction angle (degrees)
---@field distance number Distance between units (nautical miles)
---@field firstDistance? number Special distance for first unit (optional)

---Random units descriptor for creating multiple units at random positions
---@class SBJ__RandomUnitsDescriptor:table
---@field centerPoint CMO__Waypoint Center point for random positioning
---@field randomRadius number Maximum radius from center point (nautical miles)
---@field autodetectable boolean Whether units are automatically detectable
---@field unitname string Base name for created units (random suffix will be added if useRandomSuffix is true)
---@field sideName string Side name (e.g., "China", "Taiwan", "US")
---@field unitType string Unit type (e.g., "Facility", "Ship", "Submarine", "Aircraft")
---@field count number Number of units to create
---@field dbids number[] Array of database IDs to randomly select from
---@field useRandomSuffix? boolean Optional: Whether to append random text suffix to unit names (defaults to true)

---Unit descriptor for creating units with specific properties
---@class SBJ__UnitDescriptor:CMO__SetUnitDescriptor
---@field cargo SBJ__CargoDescriptor[] Cargo items to load onto the unit

---Ship formation specification - defines a single ship's configuration within a formation
---Used to specify ship positioning, armament, and embarked units in naval groups
---@class SBJ__ShipFormationSpec
---@field dbid number Ship platform database ID
---@field unitname string Ship unit name
---@field distance number Distance from formation center (nautical miles)
---@field angle number Angle offset from formation heading (degrees)
---@field embarkedUnits SBJ__EmbarkedUnit[]|nil Embarked aircraft/boats (optional)
---@field loadouts SBJ__Loadout[]|nil Ammunition stockpile configuration (optional)

---Formation configuration for internal ship creation
---Used internally by createShipFormation() to configure ship group formations
---@class SBJ__SAGFormationConfig
---@field centerPoint CMO__Location Formation center point coordinates
---@field heading number Formation heading angle
---@field groupName string Ship group name
---@field sideName string Side name (e.g., 'China', 'Taiwan')
---@field shipTypes SBJ__ShipFormationSpec[] Array of ship configurations to create

---@alias SBJ__AmphibiousShipType
---| '"type075"'
---| '"type071"'
---| '"type076"'
---| '"type072iii"'
---| '"type072a"'
---| '"type073a"'
---| '"ferry"'
---| '"barge"'
---| '"roro"'

-- ============================================================================
-- Cargo & Logistics
-- ============================================================================
-- Cargo and logistics types for amphibiousLogistics module

---Loadout configuration for units
---@class SBJ__Loadout:table
---@field loadoutId number Ammunition configuration ID
---@field name string Loadout display name
---@field num number Unit count

---Cargo descriptor defining parameters for creating cargo units on ships
---@class SBJ__CargoDescriptor:table
---@field type number Cargo type identifier
---@field num number Quantity of cargo items to create
---@field dbid number Database ID of the cargo platform

---Cargo manifest organized by loadout configuration
---Maps a specific loadout to its associated cargo items
---@class SBJ__LoadoutCargoManifest:table
---@field loadoutId number Loadout configuration ID
---@field cargoItems table<number, SBJ__CargoDescriptor[]> Cargo items for this loadout

---Cargo transfer manifest organized by ship type
---Different ship types carry different loadout configurations
---@class SBJ__ShipTypeCargoManifest:table
---@field type075 SBJ__LoadoutCargoManifest[] Type 075 ship cargo manifests
---@field type071 SBJ__LoadoutCargoManifest[] Type 071 ship cargo manifests


-- ============================================================================
-- Airbase & Embarked Units
-- ============================================================================
-- Airbase and embarked unit configuration

---Embarked unit configuration for ships and airbases
---@class SBJ__EmbarkedUnit:table
---@field side string Side name (e.g., "China", "Taiwan", "US")
---@field type string Unit type (e.g., "Aircraft", "Helicopter")
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
---@field latitude? number Airbase latitude coordinate (optional)
---@field longitude? number Airbase longitude coordinate (optional)

-- ============================================================================
-- Naval Operations
-- ============================================================================
-- Naval operations types for shipMovement and other modules

---Departure point definition with starting coordinates and heading
---@class SBJ__DeparturePoint:table
---@field startingPoint CMO__Location Starting coordinates
---@field heading number Initial heading angle

---Destination area definition with waypoints
---@class SBJ__DestinationArea:table
---@field area CMO__Location[] Destination area waypoints

---Destination staging area with anchorage and vehicle staging zones
---Extends destination area with additional staging and anchorage areas
---@class SBJ__DestinationStagingArea:SBJ__DestinationArea
---@field anchorageArea CMO__Waypoint[] Anchorage area waypoints
---@field amphibiousVehicleStagingArea CMO__Waypoint[] Amphibious vehicle staging area waypoints
---@field heading number Formation heading angle

---Formation heading configuration
---@class SBJ__FormationHeading:table
---@field horizontal number Horizontal spacing angle
---@field vertical number Vertical spacing angle
---@field destination CMO__Waypoint[] Destination waypoints

---Submarine descriptor for SLCM operations
---@class SBJ__SubmarineDescriptor:table
---@field name string Submarine name/identifier
---@field guid string Submarine unit GUID (empty string if not yet created)
---@field course CMO__Waypoint[] Submarine patrol route waypoints
---@field from SBJ__DeparturePoint Starting location with heading
---@field weaponDBID number Weapon database ID for SLCM

---Surface Action Group descriptor
---@class SBJ__SAGDescriptor:table
---@field groupName string Group name
---@field from SBJ__DeparturePoint Starting location
---@field to SBJ__DestinationStagingArea Destination staging area
---@field unitList table<string, SBJ__AirbaseDeploymentDescriptor> Unit list indexed by unit name
---@field area string[] Operational area reference points
---@field missionName? string Mission name (optional)

---Carrier Strike Group descriptor
---@class SBJ__CSGDescriptor:table
---@field groupName string Group name
---@field from SBJ__DeparturePoint Starting location
---@field to SBJ__DestinationArea Destination area
---@field unitList table<string, SBJ__AirbaseDeploymentDescriptor> Unit list indexed by unit name


-- ============================================================================
-- Amphibious Operations
-- ============================================================================
-- Amphibious operations types for amphibiousAssault and landingOps modules

---Barge context for tracking barge operations and associated units
---@class SBJ__BargeContext:table
---@field guid string Barge unit GUID
---@field bridgeGUID? string Bridge unit GUID for barge connection (optional)
---@field roros string[] Array of RORO ship GUIDs transported by this barge

---Ship position calculation result for amphibious operation planning
---@class SBJ__ShipCalculationResult:table
---@field locations CMO__Location[] Calculated positions for ship formation
---@field locationIndex number Current position index in the locations array
---@field dbid number Platform database ID for this ship type

---Operation zone calculation result containing all ship type positions
---Stores calculated ship formation positions for each ship type in the operation zone
---@class SBJ__OperationZoneCalculationResult:table
---@field name string Operation zone name (e.g., "Taoyuan", "Penghu", "Sishu")
---@field result table<string, SBJ__ShipCalculationResult> Ship type calculation results indexed by ship type name (type075, type071, type076, type072iii, type072a, type073a, type071InLSTArea, ferry, roro, barge)

---Amphibious operations context managing all amphibious operation state
---@class SBJ__PHIBOPContext:table
---@field startTime string Operation start time
---@field isTesting boolean Whether in testing mode
---@field isShipsStartedMoving boolean Whether ships have started moving
---@field isWaitingForShipArrival boolean Whether waiting for ship arrival
---@field amphibiousAssaultStartTime? number Amphibious assault start timestamp (optional)
---@field isWaitingForAmphibiousAssault boolean Whether waiting for amphibious assault
---@field isWaitingForSecondWaveUnloading boolean Whether waiting for second wave unloading
---@field airlandingMissionStartTime? number Air landing mission start timestamp (optional)
---@field calculationResult table<string, SBJ__OperationZoneCalculationResult> Operation zone calculation results indexed by zone name
---@field barges table<string, SBJ__BargeContext> Barge contexts indexed by barge GUID

---ACV deployment parameters for launching air cushion vehicles
---Temporary parameter pack used for ACV deployment functions
---@class SBJ__ACVDeploymentParams:table
---@field bearing number Deployment direction (degrees)
---@field distance number Deployment distance (nautical miles)
---@field ship CMO__Unit Parent landing ship
---@field speed number ACV movement speed (knots)
---@field destination CMO__Waypoint[] ACV destination waypoints
---@field num integer Number of ACVs to deploy

---Vehicle offload parameters for unloading vehicles from landing ships
---Temporary parameter pack used for vehicle offloading functions
---@class SBJ__VehicleOffloadParams:table
---@field ship CMO__Unit Landing ship to offload from
---@field num integer Number of vehicles to offload
---@field bearing number Offload direction (degrees)
---@field distance number Distance between vehicles (nautical miles)
---@field firstDistance number Distance for first vehicle (nautical miles)

---Landing mission descriptor for amphibious operations
---@class SBJ__LandingMissionDescriptor:table
---@field name string Mission name
---@field loadoutId number Loadout configuration ID
---@field unitCount integer Number of units
---@field startTime number Mission start time

---Air Cushion Vehicle deployment configuration
---@class SBJ__ACVDescriptor:table
---@field bearing number Deployment direction (degrees)
---@field distance number Horizontal spacing between ACVs (nautical miles)
---@field speed number ACV transit speed (knots)
---@field destination CMO__Waypoint[] Destination waypoints
---@field area string[] Staging area reference points

---Amphibious landing platform base descriptor
---Common configuration for platforms that conduct landing missions with cargo transfer
---@class SBJ__CargoLandingPlatformDescriptor:table
---@field dbid number Platform database ID
---@field missions SBJ__LandingMissionDescriptor[] Landing mission descriptors
---@field zone string[] Landing zone reference points
---@field settings CMO__Mission Mission behavior settings (throttle, altitude, active status)
---@field transferManifest SBJ__ShipTypeCargoManifest Cargo transfer manifest by ship type

---Landing craft mission configuration for boat-based amphibious landings
---@class SBJ__BoatMissionDescriptor:SBJ__CargoLandingPlatformDescriptor

---Transport helicopter mission configuration for air assault operations
---@class SBJ__TransportHelicopterDescriptor:SBJ__CargoLandingPlatformDescriptor

---Attack helicopter mission configuration for close air support
---No cargo transfer capability
---@class SBJ__AttackHelicopterDescriptor:table
---@field dbid number Attack helicopter platform database ID
---@field missions SBJ__LandingMissionDescriptor[] CAS mission descriptors

---Transport aircraft configuration for airlift operations
---Defines transport aircraft deployment from airbases for airborne assault missions
---@class SBJ__TransportAircraftDescriptor:table
---@field name string Airbase name where transport aircraft are stationed
---@field guid string Airbase GUID reference
---@field dbid number Transport aircraft platform database ID
---@field missions SBJ__LandingMissionDescriptor[] Air landing mission descriptors
---@field cargoItemsForTransfer SBJ__LoadoutCargoManifest[] Cargo manifest for airlift operations

---Landing Ship Tank movement configuration
---Defines LST approach to beach
---@class SBJ__LSTMovementDescriptor:table
---@field speed number LST transit speed (knots)
---@field course {bearing:number, distance:number} Approach course (bearing in degrees, distance in nautical miles)

---Operational zone descriptor for amphibious operations
---Defines complete landing zone configuration including air and surface assets
---@class SBJ__OperationalZoneDescriptor:table
---@field name string Operational zone name
---@field baseGUID string Home base GUID for embarked units
---@field anchorageArea string[] LHD/LPD anchorage area reference points
---@field LSTAnchorageArea string[] LST anchorage area reference points
---@field area string[] General operational area reference points
---@field offloadArea string[] Vehicle offload area reference points
---@field boat SBJ__BoatMissionDescriptor Landing craft configuration
---@field transportHelicopter SBJ__TransportHelicopterDescriptor Transport helicopter configuration
---@field attackHelicopter SBJ__AttackHelicopterDescriptor Attack helicopter configuration
---@field LSTSettings SBJ__LSTMovementDescriptor LST movement configuration
---@field ACV SBJ__ACVDescriptor Amphibious combat vehicle configuration

---Formation settings for amphibious operation layouts
---Defines spacing and movement parameters for amphibious assault ship formations
---Used internally for calculating ship positions during landing operations
---@class SBJ__AmphibiousFormationSettings:table
---@field distanceBetweenLSTAndLPDArea string Distance between LST and LPD staging areas
---@field horizontalDistance number Horizontal spacing between ships in formation
---@field verticalDistance number Vertical spacing between ships in formation
---@field transitDistance number Distance for transit phase
---@field shipSpeed number Ship movement speed
---@field heading table<string, SBJ__FormationHeading> Formation heading configuration
---@field ACVSpeed number Amphibious combat vehicle speed
---@field ACVTransitDistance number ACV transit distance
---@field ACVHorizontalDistance number ACV horizontal spacing

---Ship type starting point configuration
---@class SBJ__ShipTypeStartPoint:table
---@field sideName string Side name (e.g., "China", "Taiwan")
---@field area string[] Area reference points array

---Fleet composition configuration for amphibious operations
---Defines the number of ships by type for amphibious assault fleets
---@class SBJ__FleetComposition:table
---@field type075 integer Number of Type 075 amphibious assault ships
---@field type071 integer Number of Type 071 amphibious transport docks
---@field type076 integer Number of Type 076 amphibious assault ships
---@field type072iii integer Number of Type 072III landing ships
---@field type072a integer Number of Type 072A landing ships
---@field type073a integer Number of Type 073A landing craft
---@field type071InLSTArea? integer Number of Type 071 ships in LST area (optional)
---@field ferry integer Number of ferries
---@field roro integer Number of roll-on/roll-off ships
---@field barge integer Number of barges

---Amphibious operation area descriptor
---@class SBJ__AmphibiousAreaDescriptor:table
---@field startingPoints table<string, SBJ__ShipTypeStartPoint> Starting points for each ship type
---@field heading SBJ__FormationHeading Formation heading angle
---@field num? SBJ__FleetComposition Ship quantity configuration (optional, only in destination)

---Amphibious operation departure/destination descriptor
---@class SBJ__AmphibiousLocationDescriptor:table
---@field areas SBJ__AmphibiousAreaDescriptor[] Array of area descriptors
---@field stagingArea? string Staging area reference (optional, only in departure)
---@field num? SBJ__FleetComposition Ship quantity configuration (optional, only in departure)

---Amphibious operation descriptor
---Comprehensive configuration for one complete amphibious landing operation
---Includes departure, destination, air landing zones, and participating forces
---Used for scenario initialization and deployment planning
---@class SBJ__AmphibiousOperationDescriptor:table
---@field name string Operation name (e.g., "Taoyuan", "Sishu", "Penghu")
---@field names string[] Unit name array
---@field from SBJ__AmphibiousLocationDescriptor Departure configuration
---@field to SBJ__AmphibiousLocationDescriptor Destination configuration
---@field airLandingZone string[] Air landing zone reference area
---@field numOfContactsInAirLandingZone integer Number of contacts required in air landing zone

---Amphibious Operations system configuration
---Comprehensive configuration for amphibious assault operations including
---cargo manifests, ship layouts, operational zones, and mission timing
---@class SBJ__AmphibOpsConfig:table
---@field periodOfTime number Check interval in seconds
---@field cargoList table<string, SBJ__CargoDescriptor[]> Cargo manifest by ship type
---@field cargoListForTransfer table<string, SBJ__CargoDescriptor[]> Transfer cargo groups
---@field missionStartime table<string, number[]> Mission start times by type (seconds)
---@field formationSettings SBJ__AmphibiousFormationSettings Ship formation layout configuration
---@field operations SBJ__AmphibiousOperationDescriptor[] Amphibious operation descriptors
---@field operationalZones SBJ__OperationalZoneDescriptor[] Operation zone descriptors
---@field transportAircraft SBJ__TransportAircraftDescriptor[] Transport aircraft configuration
---@field sag table<string, SBJ__SAGDescriptor> Surface Action Group descriptors

---Land-Attack Cruise Missile context managing LACM operations state
---@class SBJ__LACMContext:table
---@field isActivated boolean Whether LACM is activated
---@field startTime string LACM start time

-- ============================================================================
-- Air Operations & Missions
-- ============================================================================
-- Air operations and mission types for assignMission and other modules

---Mission creation parameters for CMO API
---Maps directly to ScenEdit_AddMission parameters
---@class SBJ__MissionCreationParams:table
---@field name string The name of the mission
---@field side string The side of the mission
---@field type string The type of the mission
---@field opts CMO__Mission The options for the mission

---Mission deployment descriptor for air operations
---Complete mission deployment configuration including base, units, weapons, and timing
---@class SBJ__MissionDeploymentDescriptor:table
---@field baseGUID string The GUID of the base to use for the mission
---@field missionCreationParams SBJ__MissionCreationParams The parameters for the mission
---@field unitCount integer The number of units to assign to the mission
---@field weaponDBID number The weapon DBID to use for the mission
---@field unitDBID number The unit DBID to use for the mission
---@field loadoutId? number The loadout ID to filter by, 0 for any loadout (optional)
---@field startTime string The start time of the mission
---@field endTime? string The end time of the mission (optional)
---@field timeOnStation? string The time on station (optional)
---@field emcon string The EMCON settings for the mission

---Air operations context managing air tasking orders and aircraft status
---@class SBJ__AirOperationsContext:table
---@field landBased table Land-based aircraft context (reserved for future use)
---@field shipBased table Ship-based aircraft context (reserved for future use)
---@field isActivated boolean Whether air operations system is activated
---@field ATO table<string, SBJ__Wave> Air Tasking Order waves indexed by wave name


-- ============================================================================
-- Launcher & TEL Systems
-- ============================================================================
-- Launcher and Transporter-Erector-Launcher (TEL) systems for launcher module

---Area mode parameters for defining operational areas
---@class SBJ__AreaMode:table
---@field side string Side name
---@field shape string Area shape type
---@field distance number Distance parameter
---@field name? string Area name (optional)
---@field bear_offset? number Bearing offset (optional)

---Position definition with course and area reference points
---@class SBJ__Position:table
---@field course CMO__Waypoint[] Waypoints to area
---@field area string[] Area reference points, e.g., {"rp-100","rp-101","rp-102","rp-103","rp-104"}

---Operational area definition with multiple tactical position types
---Defines firing positions, hide areas, and reload locations for TEL operations
---@class SBJ__OperationalArea:table
---@field FP SBJ__Position[] Firing Position
---@field HA? SBJ__Position[] Hide Area (optional)
---@field AHA SBJ__Position[] Alternative Hide Area
---@field RL SBJ__Position[] Reload Location

---Ammunition context data structure
---Tracks ammunition unit status and remaining ammunition counts
---@class SBJ__AmmunitionContext:table
---@field guid string Ammunition unit GUID
---@field name string Ammunition unit name
---@field wpnCurrent number Current available ammunition count
---@field wpnDefault number Default/maximum ammunition count

---Resupply unit context data structure
---Extends ammunition context with operational area and resupply management
---@class SBJ__ResupplyUnitContext:SBJ__AmmunitionContext
---@field name string Resupply unit name
---@field unitCount number Number of resupply vehicles in this unit
---@field operationalArea SBJ__OperationalArea Operational area definition for this resupply unit
---@field reloadStartTime? number Reload operation start timestamp, nil if not currently reloading
---@field state batteryState Current unit state (STATIC/HIDE, etc.)
---@field ammunition string Associated ammunition unit name for this resupply unit

---Firing unit context data structure
---Extends resupply unit context with weapon system configuration
---@class SBJ__FiringUnitContext:SBJ__ResupplyUnitContext
---@field weaponDBID number The weapon database ID to use for the firing unit
---@field ammoThreshold number The ammunition threshold for the firing unit, if not specified, the default value will be used
---@field resupplyUnit string The resupply unit name associated with this firing unit
---@field msg string The status message to display for the firing unit
---@field dbid number The firing unit database ID

---Weapon system context data structure
---Consolidates all components of a complete weapon system (firing units, resupply units, ammunition)
---@class SBJ__WeaponSystemContext:table
---@field isActivated boolean Whether the weapon system is currently active
---@field reloadTime number Reload time for all firing units/resupply units in this system (seconds)
---@field operationalAreas table<string, SBJ__OperationalArea> Operational areas indexed by area name for this weapon system
---@field firingUnits table<string, SBJ__FiringUnitContext> Firing units indexed by GUID for attack operations
---@field resupplyUnits table<string, SBJ__ResupplyUnitContext> Resupply units indexed by GUID for ammunition replenishment
---@field ammunitions table<string, SBJ__AmmunitionContext> Ammunition units indexed by GUID for tracking available munitions
---@field test? table Test data structure (optional)

---Ground force context data structure
---Manages all ground-based weapon systems and fire support operations
---@class SBJ__GroundForceContext:table
---@field isActivated boolean Whether ground force systems are activated
---@field mlrs SBJ__WeaponSystemContext Multiple Launch Rocket System
---@field srbm SBJ__WeaponSystemContext Short-Range Ballistic Missile system
---@field mrbm SBJ__WeaponSystemContext Medium-Range Ballistic Missile system
---@field glcm SBJ__WeaponSystemContext Ground-Launched Cruise Missile system
---@field ascm SBJ__WeaponSystemContext Anti-Ship Cruise Missile system
---@field FSP table<string, SBJ__FireSupportExecutionMatrix> Fire Support Plan execution matrices

---Unit property setting parameters for ground units
---@class SBJ__SetUnitPropertiesParams
---@field unit CMO__Unit Unit object (required)
---@field throttle string? Throttle setting (default: 'Stop')
---@field speed number? Speed (default: 0)
---@field course CMO__Waypoint[]? Waypoints (optional)
---@field holdPosition boolean? Whether to hold position (default: true)
---@field wcs integer? Weapon control status: 1=Free, 2=Hold (optional)
---@field formation CMO__FormationGroup? Formation settings (optional)


-- ============================================================================
-- Strike Planning & Targeting
-- ============================================================================
-- Strike planning and targeting types for strikePlanner module

---Airfield pattern configuration for target matching
---@class SBJ__AirfieldPatterns:table
---@field runwayPattern string Lua pattern for runway matching (e.g., "Runway %(%d+m%)")
---@field taxiwayPattern string Lua pattern for taxiway matching
---@field shelterPattern string Lua pattern for aircraft shelter matching
---@field hangarPattern string Lua pattern for hangar matching
---@field tarmacPattern string Lua pattern for tarmac matching
---@field helipadPattern string Lua pattern for helipad matching
---@field ammoBunkerPattern string Lua pattern for ammunition bunker matching
---@field ammoRevetmentPattern string Lua pattern for ammunition revetment matching

---Port pattern configuration for target matching
---@class SBJ__PortPatterns:table
---@field pierPattern string Lua pattern for pier matching

---Radar pattern configuration for target matching
---@class SBJ__RadarPatterns:table
---@field radarPattern string Lua pattern for radar facility matching

---SAM pattern configuration for target matching
---@class SBJ__SAMPatterns:table
---@field skyBowPattern string Lua pattern for Sky Bow SAM system matching

---ASM pattern configuration for target matching
---@class SBJ__ASMPatterns:table
---@field asmPattern string Lua pattern for anti-ship missile system matching

---C2 pattern configuration for target matching
---@class SBJ__C2Patterns:table
---@field hengshanPattern string Lua pattern for Hengshan command center matching

---Target category patterns configuration
---@class SBJ__TargetCategoryPatterns:table
---@field airfield SBJ__AirfieldPatterns Airfield-related patterns
---@field port SBJ__PortPatterns Port-related patterns
---@field radar SBJ__RadarPatterns Radar facility patterns
---@field sam SBJ__SAMPatterns SAM system patterns
---@field asm SBJ__ASMPatterns ASM system patterns
---@field c2 SBJ__C2Patterns Command and control patterns

---Target scanning configuration for contact categorization
---@class SBJ__TargetScanningConfig:table
---@field distanceThreshold number Maximum distance threshold in nautical miles for base/port proximity matching
---@field taiwanAirBases string[] Array of Taiwan airbase names to scan for
---@field taiwanPorts string[] Array of Taiwan port names to scan for
---@field targetCategories SBJ__TargetCategoryPatterns Pattern configurations for each target category

---Target entry representing a scanned and categorized target
---@class SBJ__TargetEntry:table
---@field name string Target display name (format: "BaseName/Description" for base-related targets, or just "Description" for standalone targets)
---@field guid string Target contact GUID
---@field category string Target category ("Airfield", "Port", "ISR", "SAM", "ASM", "C2")
---@field subType string Target sub-type description (e.g., "Runway (3000m)", "Shelter", "Pier", "Radar")

---Target query parameter for filtering targets by base name and facility sub-types
---@class SBJ__TargetQueryParam:table
---@field baseName? string Base name pattern for matching (optional, if omitted matches all)
---@field subTypes string[] Array of facility sub-type patterns to match

---Target template for strike planning
---@class SBJ__TargetTemplate
---@field objs? SBJ__TargetQueryParam[] Target query parameters (for fixed targets, optional)
---@field areas string[] Operation areas
---@field filterNames? string[] Filter function names (for dynamic targets, optional)
---@field contactAge number Contact valid time (seconds)
---@field minTargetCount number Minimum target count threshold
---@field ammoPerTarget number Ammunition count per target

---Target definition extending template with contact list
---@class SBJ__Target:SBJ__TargetTemplate
---@field list string[] List of target contact GUIDs

---Task definition with target information
---@class SBJ__Task:table
---@field target SBJ__Target Target information

---Filter parameters for target selection and filtering
---@class SBJ__FilterParams:table
---@field config SBJ__Config Configuration data
---@field saveData SBJ__SaveData Saved data
---@field task SBJ__Task Task information
---@field contacts CMO__Contact[] Contact array
---@field shouldTrack? boolean Whether to track contacts (optional)

---Firing unit definition for fire support operations
---@class SBJ__FiringUnit:table
---@field name string Firing unit name
---@field guid string Firing unit GUID
---@field weaponDBID number Firing unit weapon database ID

---Fire Support Task template extending task with firing units
---@class SBJ__FireSupportTaskTemplate:SBJ__Task
---@field name string FST name
---@field wpnSystem string Weapon system type
---@field firingUnits SBJ__FiringUnit[] Firing unit array

---Fire Support Task execution state
---@class SBJ__FireSupportTask: SBJ__FireSupportTaskTemplate
---@field startTime string Task start time
---@field isFinished boolean Whether task is finished

---Fire Support Execution Matrix template
---@class SBJ__FireSupportExecutionMatrixTemplate:table
---@field name string FSEM name
---@field isFirstWave boolean Whether it's the first wave attack
---@field strikeInterval number Strike interval time (seconds)
---@field FSTs SBJ__FireSupportTaskTemplate[] FST template array

---Fire Support Execution Matrix with execution state
---@class SBJ__FireSupportExecutionMatrix:SBJ__FireSupportExecutionMatrixTemplate
---@field isActivated boolean Whether FSEM is activated
---@field allFiringUnitsInPosition boolean Whether all firing units are in position
---@field isFinished boolean Whether FSEM is finished
---@field FSTs SBJ__FireSupportTask[] Fire support tasks array

---Attack contacts parameters for coordinating strikes
---@class SBJ__AttackParams:table
---@field contacts table<integer, string> A table of contact GUIDs to attack
---@field qty integer The number of salvos to launch
---@field firingUnits SBJ__FiringUnit[] A table of firing units to use for the attack
---@field weaponDBID? number The weapon DBID to use for the attack (if not specified, the default weapon will be used)
---@field sideName? string The side to use for the attack (if not specified, the side of the first firing unit will be used)

---Parameters for generating missile flight paths
---@class SBJ__GenerateMissilePaths_Params
---@field targetLat number Target latitude
---@field targetLon number Target longitude
---@field launcherLat number Launcher latitude
---@field launcherLon number Launcher longitude
---@field radarRange number Radar range (nautical miles)
---@field missileCount? number Number of missiles (default is 5)
---@field missileSpeedKts? number Missile speed in knots (default is 600)
---@field missileRangeNm? number Maximum missile range in nautical miles (default is 100)

---Missile path definition with waypoints and timing
---@class SBJ__MissilePath
---@field waypoints CMO__Waypoint[] Missile waypoint list
---@field launchTime number Launch time (UTC timestamp)


-- ============================================================================
-- Reconnaissance & Intelligence
-- ============================================================================
-- Reconnaissance and intelligence types for recon module

---Base reconnaissance queue entry template with shared fields
---@class SBJ__ReconQueueEntryBase:table
---@field type string Reconnaissance type: "UAV"|"satellite"
---@field endTime? string Scheduled end time in format "YYYY-MM-DD HH:MM:SS" (optional)

---UAV reconnaissance queue entry template
---Complete configuration for UAV reconnaissance missions including launch and flight parameters
---@class SBJ__ReconQueueEntryTemplateUAV:SBJ__ReconQueueEntryBase
---@field baseGUID string Base GUID where UAV is stationed
---@field unitDBID number UAV platform database ID
---@field course CMO__Waypoint[] Waypoints for reconnaissance route
---@field unitCount number Number of UAVs to deploy
---@field speed number Cruise speed in knots for tracking mode
---@field takeoffTime string Scheduled takeoff time in format "YYYY-MM-DD HH:MM:SS"
---@field isTracking? boolean Whether to track this reconnaissance mission (optional)

---Satellite reconnaissance queue entry template
---Simplified configuration for satellite reconnaissance requiring only timing information
---@class SBJ__ReconQueueEntryTemplateSatellite:SBJ__ReconQueueEntryBase
-- No additional fields beyond base - satellites only need type and endTime

---Union type for all reconnaissance entry templates
---@alias SBJ__ReconQueueEntryTemplate SBJ__ReconQueueEntryTemplateUAV|SBJ__ReconQueueEntryTemplateSatellite

---UAV reconnaissance queue entry with execution state
---@class SBJ__ReconQueueEntryUAV:SBJ__ReconQueueEntryTemplateUAV
---@field unitGUID? string UAV unit GUID (nil if not yet created)
---@field hasLaunched boolean Whether reconnaissance mission has launched
---@field isFinished? boolean Whether reconnaissance mission has finished (optional)
---@field trackingTargetGUID? string Target contact GUID being tracked (optional, only used when isTracking is true)

---Satellite reconnaissance queue entry with execution state
---@class SBJ__ReconQueueEntrySatellite:SBJ__ReconQueueEntryTemplateSatellite
---@field isFinished? boolean Whether reconnaissance mission has finished (optional)

---Union type for all reconnaissance queue entries with execution state
---@alias SBJ__ReconQueueEntry SBJ__ReconQueueEntryUAV|SBJ__ReconQueueEntrySatellite

---Reconnaissance context managing reconnaissance operations state
---@class SBJ__ReconContext:table
---@field isActivated boolean Whether reconnaissance system is activated
---@field queue SBJ__ReconQueueEntry[] Reconnaissance mission queue
---@field reconStrikeMatrix table<SBJ__ReconPlatformType, table<string, SBJ__ReconStrikeMapping[]>> Reconnaissance-strike mappings indexed by platform type

---Reconnaissance-Strike mapping entry
---Defines strike mission to execute after reconnaissance platform detects target
---@class SBJ__ReconStrikeMapping
---@field name string Strike mission name
---@field type "air"|"ground" Strike mission type

---Reconnaissance platform type
---@alias SBJ__ReconPlatformType "UAV"|"satellite"


-- ============================================================================
-- Dynamic Operations (ATO/FSEM)
-- ============================================================================
-- Dynamic operations types for dynamicATOInsertion and dynamicFireSupportPlan modules

---Generated operations tracker for dynamic operations
---@class SBJ__GeneratedOperationsTracker:table
---@field air table<string, boolean> Generated air operation names indexed by operation name
---@field ground table<string, boolean> Generated ground operation names indexed by operation name

---Dynamic operations context managing intelligence-driven adaptive strike planning
---@class SBJ__DynamicOperationsContext:table
---@field enabled boolean Whether dynamic operations system is enabled
---@field lastEvaluationTime? number Last evaluation timestamp (Unix time)
---@field generatedOperations SBJ__GeneratedOperationsTracker Generated operation name tracker
---@field reconSchedule SBJ__ReconScheduleEntry[] Reconnaissance-driven operation schedule

---Reconnaissance schedule entry for intelligence gathering operations
---@class SBJ__ReconScheduleEntry:table
---@field time string Reconnaissance time in format "2027-06-09 14:30:00"
---@field type string Reconnaissance type: "satellite", "aircraft", or "UAV"
---@field delay number Delay trigger time (seconds)
---@field executed boolean Whether already executed
---@field operations SBJ__Operation[] Operations to execute

---Operation definition for dynamic operations
---@class SBJ__Operation:table
---@field type string Template type
---@field executed boolean Whether operation has been executed
---@field template SBJ__FireSupportExecutionMatrixTemplate|SBJ__WaveTemplate Operation template (FSEM or Wave)
---@field executionResult? boolean Operation execution result (true for success, false for failure)

---Wave template for Dynamic ATO Insertion
---@class SBJ__WaveTemplate:table
---@field name string ATO wave name
---@field isFirstWave boolean Whether it's the first wave attack
---@field strikeInterval number Strike interval time (seconds)
---@field packages SBJ__PackageTemplate[] ATO package array

---Package template for air operation coordination
---@class SBJ__PackageTemplate:SBJ__Task
---@field striker? SBJ__MissionDeploymentDescriptor Main striker configuration (optional)
---@field escort? SBJ__MissionDeploymentDescriptor Escort configuration (optional)
---@field wildWeasel? SBJ__MissionDeploymentDescriptor Wild Weasel configuration (optional)
---@field jammer? SBJ__MissionDeploymentDescriptor Jammer configuration (optional)
---@field tanker? SBJ__MissionDeploymentDescriptor Tanker configuration (optional)
---@field reconUAV? SBJ__ReconQueueEntryTemplateUAV Reconnaissance UAV configuration (optional)
---@field timeToReady? number Ready time in minutes (optional)

---Loadout status tracking for mission preparation
---@class SBJ__LoadoutStatus:table
---@field isLoadoutInitiated boolean Whether loadout process has started
---@field loadoutInitiatedTime number Loadout initiation timestamp
---@field expectedReadyTime number Expected ready timestamp
---@field loadoutStartTime number Loadout start timestamp

---Package execution state extending template with launch and loadout status
---@class SBJ__Package:SBJ__PackageTemplate
---@field hasLaunched boolean Whether package has launched
---@field loadoutStatus SBJ__LoadoutStatus Loadout preparation status

---Wave execution state with packages and activation status
---@class SBJ__Wave:SBJ__WaveTemplate
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
---@field randomRadius number Position randomization radius (nautical miles)
---@field radius number GPS jamming effectiveness radius (nautical miles)

---SIGINT detection configuration parameters
---@class SBJ__SIGINTConfig:table
---@field detectionThreshold number Minimum detection range
---@field maxRange table Maximum detection range as {min, max}
---@field decayRate number Signal decay rate
---@field randomFactor number Random deviation factor
---@field displayConfig SBJ__SIGINTDisplayData Default display settings

---Enhanced SIGINT detection result with confidence and metadata
---@class SBJ__SIGINTResult:table
---@field longitude number Detected longitude coordinate
---@field latitude number Detected latitude coordinate
---@field isDetected boolean Whether signal is detected
---@field confidence number Detection confidence level (0-1)
---@field detectorId? string ID of detecting unit (optional)
---@field timestamp number Detection timestamp

---Radio transmission context data structure
---Tracks and manages detected radio transmission sources with detection metadata
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

---Enhanced SIGINT display data configuration
---@class SBJ__SIGINTDisplayData:table
---@field R? number Red value (default: 255)
---@field G? number Green value (default: 255)
---@field B? number Blue value (default: 255)
---@field lifeTime? number Display time in seconds (default: 4)
---@field fontSize? number Font size (default: 16)
---@field showConfidence? boolean Whether to show confidence level

---SIGINT context managing all transmission tracking
---@class SBJ__SIGINTContext:table
---@field transmissions table<string, SBJ__RadioTransmissionContext> Radio transmission contexts indexed by GUID
---@field RA table<string, SBJ__AircraftContext> Recon aircraft context data structure indexed by GUID
---@field isActivated boolean Whether SIGINT is activated
---@field maxCount number Maximum detection level

---Communications jamming context managing electronic warfare jamming operations
---@class SBJ__CommsJammingContext:table
---@field isActivated boolean Whether communications jamming system is activated
---@field jammers table<string, SBJ__AircraftContext> Jamming aircraft indexed by GUID


-- ============================================================================
-- Command & Control (C2) and IADS
-- ============================================================================
-- Command & Control and Integrated Air Defense System types for IADS module

---Radar context for tracking radar status and communications
---@class SBJ__RadarContext:table
---@field name string Radar unit name
---@field guid string Radar unit GUID
---@field OODA CMO__OODA Radar OODA data
---@field currOODA CMO__OODA Current OODA state
---@field isOutOfComms boolean Whether the radar is out of communications
---@field outofcomms number Radar out of communications threshold

---Command and Control (C2) context data structure
---@class SBJ__C2Context:table
---@field name string C2 node name
---@field msg string Status message
---@field guid string C2 node GUID
---@field areas table<number, string[]> Associated operational areas
---@field SAM table<string, SBJ__RadarContext> Surface-to-Air Missile systems
---@field radar? table<string, SBJ__RadarContext> Radar systems (optional)

---C2 node deployment descriptor
---Defines how to create and deploy a single Command and Control node
---@class SBJ__C2Descriptor:table
---@field position CMO__Location C2 position coordinates
---@field areas string[][] Operation areas array
---@field areaName string Operation area name

---Integrated Air Defense System configuration
---Defines C2 facility parameters and deployment settings for IADS
---@class SBJ__IADSConfig:table
---@field ratio {C2:number} C2 facility ratio multiplier
---@field C2FacilityDBIDs number[] Database IDs for C2 facility types
---@field randomRadius number Random deployment radius (nautical miles)
---@field C2Deployments SBJ__C2Descriptor[] C2 node deployment descriptors

---IADS context managing air defense system state
---Tracks all Command and Control nodes and system activation status
---@class SBJ__IADSContext:table
---@field C2? table<string, SBJ__C2Context> C2 node context data structure indexed by GUID (optional)
---@field ROCC? table<string, SBJ__C2Context> ROCC context data structure indexed by GUID (optional)
---@field TAAOC? table<string, SBJ__C2Context> TAAOC context data structure indexed by GUID (optional)
---@field isActivated boolean Whether IADS is activated


-- ============================================================================
-- Aircraft & Communications Tracking
-- ============================================================================
-- Aircraft and communications tracking types for commsJamming and other modules

---Aircraft context for tracking aircraft status and communications
---@class SBJ__AircraftContext:table
---@field guid string Aircraft unit GUID
---@field OODA CMO__OODA Aircraft OODA data
---@field commsLevel number Aircraft communications level
---@field commsBase number Aircraft communications base level
---@field commsThreshold number Aircraft communications threshold
---@field outofcomms number Aircraft out of communications threshold

---Land-based platform context tracking aircraft and AEW
---@class SBJ__LandBasedPlatformContext:table
---@field AC table<string, SBJ__AircraftContext> Aircraft context data structure indexed by GUID
---@field AEW table<string, SBJ__AircraftContext> AEW aircraft context data structure indexed by GUID


-- ============================================================================
-- Runway Repairment
-- ============================================================================
-- Runway damage assessment and repair management types

---Runway entry for tracking runway damage and repair progress
---@class SBJ__RunwayEntry:table
---@field guid string Runway unit GUID
---@field startTime number|nil Repair operation start timestamp, nil if not yet started

---Unified runway repair configuration for all factions
---@class SBJ__RunwayRepairConfig:table
---@field percentagePerHour number Repair percentage per hour
---@field runwayDBIDs number[] List of runway database IDs to repair (China)
---@field airBases string[] List of Taiwan airbases with runways to repair (Taiwan)
---@field runwaySubTypes string[] Array of runway facility sub-type patterns to match (Taiwan)

---Runway repair context managing runway damage repair operations
---@class SBJ__RunwayRepairmentContext:table
---@field isActivated boolean Whether runway repair system is activated
---@field runways SBJ__RunwayEntry[] Array of runways being tracked for repair


-- ============================================================================
-- Tactical Area Generation
-- ============================================================================
-- Types for generating tactical area layouts (U-shaped areas, fire points, etc.)

---Internal squares configuration for U-shaped area
---Defines three functional zones inside U-shaped tactical area (ammo, hide, reload)
---@class SBJ__UShapeInternalSquaresConfig:table
---@field size number Square size in nautical miles
---@field marginToWall? number Safety margin between squares and U-shape walls (default: 0.1 nm)
---@field marginBetweenSquares? number Safety margin between squares (default: 0.1 nm)

---Fire points configuration for U-shaped area
---Defines fire point positions on circle perimeter around U-shaped area
---@class SBJ__UShapeFirePointsConfig:table
---@field radius number Radius of circle for fire point placement in nautical miles
---@field squareSize number Size of fire point squares in nautical miles
---@field count number Number of fire points to generate
---@field angleRange? number Angular range for placement in degrees, 360=full circle (default: 360)
---@field margin? number Safety margin between fire points in nautical miles (default: 0.1 nm)

---U-shaped tactical area configuration
---Complete configuration for generating U-shaped area with optional internal zones and fire points
---@class SBJ__UShapeAreaConfig:table
---@field centerLat number Center latitude in degrees
---@field centerLon number Center longitude in degrees
---@field thickness number Wall thickness in nautical miles
---@field width number Total width of the shape in nautical miles
---@field height number Total height of the shape in nautical miles
---@field openingAngle number Opening direction in degrees (0=North, 90=East, 180=South, 270=West)
---@field internalSquares? SBJ__UShapeInternalSquaresConfig Optional internal functional zones configuration
---@field firePoints? SBJ__UShapeFirePointsConfig Optional fire points configuration

---U-shaped area generation result
---Contains all generated vertices for U-shape, internal zones, and fire points
---@class SBJ__UShapeAreaResult:table
---@field uShapeVertices table<CMO__Location> Array of 8 vertices forming U-shape polygon
---@field ammoArea? table<CMO__Location> Ammo holding area vertices (4 points) if internal squares configured
---@field hideArea? table<CMO__Location> Hide area vertices (4 points) if internal squares configured
---@field reloadArea? table<CMO__Location> Reload area vertices (4 points) if internal squares configured
---@field firePoints? table<table<CMO__Location>> Array of fire point areas, each with 4 vertices, if fire points configured
