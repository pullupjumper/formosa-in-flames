-- ============================================================================
-- CMO Game API Types
-- ============================================================================
-- CMO native API type definitions provided by the game engine

---Display weapon allocation from attacker to target
---Supply attacker GUID and contact GUID to see salvos between units
---@param attackerGUID string The GUID of the attacker unit
---@param contactGUID string The GUID of the target contact
---@param attackingSideGUID string The GUID of the attacking side
---@return table<integer, { weapon: integer, qtyFired: integer, shooter: string, target: string, qtyAssigned: integer, weaponName: string }>|nil # Returns a weapon allocation table
function ScenEdit_WeaponAllocation(attackerGUID, contactGUID, attackingSideGUID) end

---Create a new flight plan for a mission
---@param sideName string The mission side
---@param missionName string The mission name or GUID
---@param opts CMO__FlightPlanOptions The options for the flight plan
---@return table<number, any>|nil # Returns all the flights on the mission (currently only returns the first flight, will be fixed in an upcoming release)
function ScenEdit_CreateMissionFlightPlan(sideName, missionName, opts) end

---comment
---@param sideName string
---@param zoneName string
---@param zoneType number
---@return CMO__Zone|nil
function ScenEdit_GetZone(sideName, zoneName, zoneType) end

---Unit OODA (Observe, Orient, Decide, Act) loop characteristics
---@class CMO__OODA: table
---@field evasion number The evasion of the unit
---@field targeting number The targeting of the unit
---@field detection number The detection of the unit

---Flight plan options for creating mission flight plans
---@class CMO__FlightPlanOptions: table
---@field DATEONTARGET string The mission time on target day, YYYY/MM/DD
---@field TIMEONTARGET string The mission time on target, HH:MM:SS
---@field TAKEOFFDATE string The takeoff date, YYYY/MM/DD
---@field TAKEOFFTIME string The takeoff time, HH:MM:SS

---@class CMO__TriggerResult: table
---@field Type? string @ Type of Trigger string code [required only for 'add' option]
---@field SideID? string @ guid of side involved.
---@field PointValue? number @ point value [Points]
---@field ReachDirection? any @ ?? [Points]
---@field EarliestTime? number @ .netticktime [RandomTime]
---@field LatestTime? number @ .netticktime [RandomTime]
---@field Interval? number @ enumcode 0-11 if I recall right [RegularTime] see CMO__Constants.EventTimeInterval.
---@field Time? string|osdate @ .netticktime [Time]
---@field DamagePercent? number @ [UnitDamaged]
---@field TargetFilter? CMO__TargetFilter-UnitsInArea @ table of targetfilter options [UnitDamaged, UnitDestroyed, UnitDetected, UnitEmissions, UnitEntersArea, UnitRemainsInArea, UnitBaseStatus]
---@field Area? {Name:string}[] @ [UnitDetected, UnitEmissions, UnitEntersArea, UnitRemainsInArea]
---@field DetectorSideID? string @ guid of detecting side.[UnitDetected, UnitEmissions]
---@field MCL? any @ detection classification level [UnitDetected, UnitEmissions]
---@field NOT? boolean @ invoke opposite of the set parameters. [UnitEntersArea]
---@field ETOA? number @ .netticktime? entertime limits related [UnitEntersArea]
---@field LTOA? number @ .netticktime? leavetime limits related [UnitEntersArea]
---@field ExitArea? boolean @ treat trigger as unit Exits area instead of entering. [UnitEntersArea]
---@field TD? any @ Target Duration in the area?  [UnitRemainsInArea]
---@field TargetCondition? any @ Condition of the base. [UnitBaseStatus]
---@field BaseUnit? string @ the guid of the base unit? [UnitCargoMoved]
---@field CargoFilter? table @ cargo filter table [UnitCargoMoved]

---Formation configuration for unit groupings
---@class CMO__FormationGroup: table
---@field name? string The name of the formation
---@field spacing number The spacing of the formation
---@field spacing_unit? string Multipler to the spacing if required (Opertional)
---@field bearing? number The type of formationDesired bearing of formation lead (0-360)
---@field transpose boolean Units jump to the new stations immediately

---Weapon load information on a mount
---@class CMO__Mount: table
---@field mount_dbid number The database ID of the mount
---@field mount_name string The name of the mount
---@field mount_guid string The GUID of the mount
---@field mount_status string The status of the mount (Active/Inactive/Destroyed)
---@field mount_statusR string Reason why inoperative [if not operational]
---@field mount_damage string Damage Severity [if not operational]
---@field mount_weapons CMO__WeaponLoaded[] Table of weapon loads on mount

---Cargo item information on a unit
---@class CMO__CargoInfo: table
---@field name string The name of the unit
---@field guid string The GUID of the unit
---@field cargo CMO__Cargo[] Table of cargo items on the unit


-- ============================================================================
-- Core Configuration & Data
-- ============================================================================
-- Core configuration and persistent data structures

---Logging module configuration
---@class SBJ__LoggingModuleConfig: table
---@field verbose boolean Whether verbose logging is enabled

---Logging configuration for all modules
---@class SBJ__LoggingConfig: table
---@field modules table<string, SBJ__LoggingModuleConfig> Module logging settings indexed by module name

---Trigger timing configuration
---@class SBJ__TriggerConfig: table
---@field amphibiousOps { startTime: string } Amphibious operations start time
---@field launchLACM { startTime: string } LACM launch start time
---@field launchSLCM { startTime: string } SLCM launch start time

---SIGINT detection formula constants
---@class SBJ__SIGINTFormulaConstants: table
---@field decayRate number Decay rate coefficient for probability calculation
---@field power number Power factor for distance calculation
---@field baseCoefficient number Base coefficient for signal deviation
---@field powerDivisor number Power divisor for signal deviation
---@field randomFactor number Random factor multiplier
---@field randomDivisor number Random divisor for deviation calculation
---@field randomPowerDivisor number Random power divisor
---@field distancePower number Distance power factor
---@field distanceDivisor number Distance divisor for deviation calculation

---SIGINT display configuration
---@class SBJ__SIGINTDisplayConfig: table
---@field r integer Red color component (0-255)
---@field g integer Green color component (0-255)
---@field b integer Blue color component (0-255)
---@field lifeTime integer Display lifetime in minutes
---@field fontSize integer Font size for map notifications

---SIGINT operation configuration
---@class SBJ__SIGINTConfig: table
---@field maxCount integer Maximum detection count before unit becomes autodetectable
---@field maxRange number Maximum detection range (nautical miles)
---@field detectionThreshold number Distance threshold for guaranteed detection (nautical miles)
---@field maxDetectionRange number[] Range [min, max] for random maximum detection distance
---@field formulaConstants SBJ__SIGINTFormulaConstants Detection formula constants
---@field defaultDisplay SBJ__SIGINTDisplayConfig Default display configuration
---@field minPolygonPoints integer Minimum polygon points for area validation
---@field detectionSkipProbability number Probability to skip detection check for performance (0-1)

---Aircraft communications default values
---@class SBJ__AircraftCommsDefaults: table
---@field commsLevel number Default communications level
---@field commsBase number Default communications base level
---@field commsThreshold number Communications threshold for RTB trigger
---@field outOfComms number Default out-of-communications counter

---Communications jamming configuration
---@class SBJ__CommsJammingConfig: table
---@field limit number Jammer unit limit
---@field range number Jamming range (nautical miles)
---@field initialComms number Initial communications level
---@field baseJammingPower number Base jamming power
---@field distanceExponent number Distance decay exponent
---@field effectivenessFormula { base: number, range: number } Effectiveness formula parameters
---@field distanceThresholds { close: number, medium: number, far: number, distant: number } Distance thresholds
---@field aewSupport { close: number, medium: number, far: number, distant: number } AEW support values
---@field recoveryTime { min: number, max: number } Recovery time range
---@field jammingTime { min: number, max: number } Jamming time range
---@field cooldownTime { min: number, max: number } Cooldown time range
---@field randomVariance table<string, { min: number, max: number }> Random variance by distance
---@field mode string Jamming mode ('omnidirectional' or 'directional')
---@field aircraftDefaults SBJ__AircraftCommsDefaults Aircraft communications default values

---GNSS jammer weapon configuration
---@class SBJ__GNSSJammedWeapon: table
---@field dbid number Weapon database ID
---@field jammingResistance number Jamming resistance value

---GNSS jamming configuration
---@class SBJ__GNSSJammingConfig: table
---@field randomRadius number Random deployment radius (nautical miles)
---@field radius number Jamming effectiveness radius (nautical miles)
---@field gnssGuidedWeapons SBJ__GNSSJammedWeapon[] GNSS-guided weapons to jam
---@field jammers table<string, SBJ__GNSSJammerDescriptor> GNSS jammer descriptors indexed by jammer name

---Weapon system configuration
---@class SBJ__MissileSystemConfig: table
---@field wpnDefault number Default weapon count
---@field ammoThreshold number Ammunition threshold for resupply
---@field contactAge? number Contact valid age in seconds (optional)
---@field reloadTime number Reload time in seconds
---@field stowTime number Stow time in seconds
---@field ammunitions table<string, SBJ__AmmunitionUnitDescriptor> Ammunition units indexed by unit name
---@field resupplyUnits table<string, SBJ__ResupplyUnitDescriptor> Resupply units indexed by unit name
---@field firingUnits table<string, SBJ__FiringUnitDescriptor> Firing units indexed by unit name

---Ground force configuration
---@class SBJ__GroundForceConfig: table
---@field mlrs SBJ__MissileSystemConfig MLRS configuration
---@field glcm SBJ__MissileSystemConfig GLCM configuration
---@field srbm SBJ__MissileSystemConfig SRBM configuration
---@field mrbm? SBJ__MissileSystemConfig MRBM configuration (China only)
---@field ascm SBJ__MissileSystemConfig ASCM configuration (Taiwan only)
---@field sam? SBJ__MissileSystemConfig SAM configuration (Taiwan only)
---@field [SBJ__MissileSystemConfig] SBJ__MissileSystemConfig

---Strike mapping rewrite rule used by frontline redirect
---@class SBJ__StrikeMappingRewriteRule: table
---@field fromPrefix string Prefix that identifies the original mapping family (e.g. "STRIKE/AB/W/")
---@field toPrefix string Prefix substituted into the rewritten mapping name (e.g. "STRIKE/AB/W/AAR/")
---@field type "air"|"ground" Strike mission type the rule applies to

---Frontline strike redirect configuration
---Switches strike mappings from frontline bases to rear bases with AAR support
---@class SBJ__FrontlineRedirectConfig: table
---@field enabled boolean Whether the redirect mechanism is active
---@field attritionThresholdPct number Aggregated attrition percentage that triggers redirect (0-100)
---@field frontlineBaseNames string[] Frontline airbase names (must match config.c.air.landBased.deployedACs[].name)
---@field mappings SBJ__StrikeMappingRewriteRule[] Strike mapping rewrites applied once redirect is active

---Reconnaissance configuration
---@class SBJ__ReconConfig: table
---@field template table<string, SBJ__ReconQueueEntryTemplateUAV> Reconnaissance templates indexed by template name
---@field queue SBJ__ReconQueueEntryTemplate[] Reconnaissance queue
---@field reconStrikeMatrix table<SBJ__ReconPlatformType, table<integer|string, SBJ__ReconStrikeMapping[]>> Reconnaissance-strike mappings; UAV inner key is platform DBID (integer), satellite/SIGINT inner key is semantic platform name (string)
---@field frontlineRedirect SBJ__FrontlineRedirectConfig Frontline strike redirect configuration
---@field isTesting boolean Whether system is in test mode
---@field observationWindowSec number Ground operation observation window in seconds (window starts at recon trigger time; ground operations re-evaluate targets every tick within this window before being marked executed)

---Air operations configuration
---@class SBJ__AirOperationsConfig: table
---@field landBased { deployedACs: SBJ__AirbaseDeploymentDescriptor[], wpnNum?: number } Land-based aircraft deployment
---@field shipBased table Ship-based aircraft configuration (reserved)

---Surface operations configuration (LACM)
---@class SBJ__SurfaceLACMConfig: table
---@field weaponDBID number LACM weapon database ID
---@field csg SBJ__CSGDescriptor Carrier Strike Group configuration
---@field targetlist string[] Target GUID list

---Surface operations configuration
---@class SBJ__SurfaceOperationsConfig: table
---@field lacm SBJ__SurfaceLACMConfig LACM configuration
---@field sag? table<string, SBJ__SAGDescriptor> Surface Action Groups (Taiwan only)
---@field deployedShips? SBJ__AirbaseDeploymentDescriptor[] Deployed ships (Taiwan only)

---Submarine SLCM configuration
---@class SBJ__SubSurfaceSLCMConfig: table
---@field weaponDBID number SLCM weapon database ID
---@field submarines table<string, SBJ__SubmarineDescriptor> Submarines indexed by submarine name
---@field targetlist string[] Target GUID list
---@field randomRadius number Random deployment radius (nautical miles)

---Subsurface operations configuration
---@class SBJ__SubsurfaceOperationsConfig: table
---@field slcm SBJ__SubSurfaceSLCMConfig SLCM configuration

---IADS configuration for faction
---@class SBJ__IADSFactionConfig: table
---@field ratio table<string, number> C2 facility ratio multipliers
---@field taaoc? SBJ__C2Descriptor[] TAAOC descriptors
---@field rocc? SBJ__C2Descriptor[] ROCC descriptors

---China faction configuration
---@class SBJ__ChinaConfig: table
---@field triggers SBJ__TriggerConfig Trigger timing configuration
---@field sigint SBJ__SIGINTConfig SIGINT configuration
---@field iads SBJ__IADSConfig IADS configuration
---@field commsJamming SBJ__CommsJammingConfig Communications jamming configuration
---@field gnssJamming SBJ__GNSSJammingConfig GNSS jamming configuration
---@field ground SBJ__GroundForceConfig Ground force configuration
---@field recon SBJ__ReconConfig Reconnaissance configuration
---@field air SBJ__AirOperationsConfig Air operations configuration
---@field amphibOps SBJ__AmphibOpsConfig Amphibious operations configuration
---@field surface SBJ__SurfaceOperationsConfig Surface operations configuration
---@field subSurface SBJ__SubsurfaceOperationsConfig Subsurface operations configuration
---@field fireSupportTaskTemplates table<string, SBJ__FireSupportTaskTemplate[]> Fire support task templates
---@field packageTemplates table<string, SBJ__PackageTemplate[]> Air package templates

---Taiwan faction configuration
---@class SBJ__TaiwanConfig: table
---@field gnssJamming SBJ__GNSSJammingConfig GNSS jamming configuration
---@field ground SBJ__GroundForceConfig Ground force configuration
---@field iads SBJ__IADSFactionConfig IADS configuration
---@field air SBJ__AirOperationsConfig Air operations configuration
---@field surface SBJ__SurfaceOperationsConfig Surface operations configuration

---US faction configuration
---@class SBJ__USConfig: table
---@field sigint SBJ__SIGINTConfig SIGINT configuration

---Scoring system configuration
---@class SBJ__ScoringConfig: table
---@field destroyingAircraftOnTheGround number Points for destroying aircraft on ground
---@field destroyingAmmo number Points for destroying ammunition
---@field destroyingAmmoTruck number Points for destroying ammunition truck
---@field lhd number Points for LHD
---@field lst number Points for LST
---@field ddg number Points for DDG
---@field cv number Points for CV
---@field ifv number Points for IFV
---@field infantry number Points for infantry
---@field sub number Points for submarine
---@field uav number Points for UAV
---@field tel number Points for TEL
---@field weaponDBID number Weapon database ID for scoring
---@field attackBeforeTheHHour number Penalty for early attack
---@field undergroundShelterIsDestroyed number Penalty for destroying shelter
---@field destroyingCivilianFacility number Penalty for destroying civilian facility

---Global configuration data structure
---@class SBJ__Config: table
---@field isDevMode boolean Development mode flag
---@field isSaved boolean Save game flag
---@field difficulty string Difficulty level
---@field logging SBJ__LoggingConfig Logging configuration
---@field targetScanning SBJ__TargetScanningConfig Target scanning configuration
---@field radarDistance number Radar detection distance (nautical miles)
---@field readytime number Ready time for missions (seconds)
---@field missileSystemState table<string, integer> Battery state enumeration
---@field repairRunway SBJ__RunwayRepairConfig Runway repair configuration
---@field c SBJ__ChinaConfig China faction configuration
---@field t SBJ__TaiwanConfig Taiwan faction configuration
---@field u SBJ__USConfig US faction configuration
---@field s SBJ__ScoringConfig Scoring system configuration
---@field [SBJ__ChinaConfig|SBJ__TaiwanConfig|SBJ__USConfig|SBJ__ScoringConfig] SBJ__ChinaConfig|SBJ__TaiwanConfig|SBJ__USConfig|SBJ__ScoringConfig

---GNSS jamming context managing GNSS denial operations state
---@class SBJ__GNSSJammingContext: table
---@field enabled boolean Whether GNSS jamming system is activated
---@field jammers table<string, SBJ__GNSSJammerContext> GNSS jammer contexts indexed by jammer name

---Submarine-launched cruise missile context managing SLCM operations state
---@class SBJ__SLCMContext: table
---@field enabled boolean Whether SLCM system is activated
---@field startTime string SLCM operation start time

---Surface operations context managing surface-launched weapons
---@class SBJ__SurfaceOperationsContext: table
---@field lacm SBJ__LACMContext Land-Attack Cruise Missile context

---Subsurface operations context managing submarine-launched weapons
---@class SBJ__SubsurfaceOperationsContext: table
---@field slcm SBJ__SLCMContext Submarine-launched cruise missile context

---China faction saved data structure
---@class SBJ__ChinaSaveData: table
---@field targetlist SBJ__TargetEntry[] Target list for strike planning
---@field sigint SBJ__SIGINTContext Signals intelligence context
---@field iads SBJ__IADSContext Integrated Air Defense System context
---@field commsJamming SBJ__CommsJammingContext Communications jamming context
---@field gnssJamming SBJ__GNSSJammingContext GNSS jamming context
---@field ground SBJ__GroundForceContext Ground force systems context
---@field recon SBJ__ReconContext Reconnaissance operations context
---@field air SBJ__AirOperationsContext Air operations context
---@field amphibOps SBJ__AmphibOpsContext Amphibious operations context
---@field surface SBJ__SurfaceOperationsContext Surface operations context
---@field subSurface SBJ__SubsurfaceOperationsContext Subsurface operations context
---@field repairRunway SBJ__RunwayRepairmentContext Runway repair context
---@field dynamicOperations SBJ__DynamicOperationsContext Dynamic operations context

---Taiwan faction saved data structure
---@class SBJ__TaiwanSaveData: table
---@field ground SBJ__GroundForceContext Ground force systems context
---@field repairRunway SBJ__RunwayRepairmentContext Runway repair context
---@field iads SBJ__IADSContext Integrated Air Defense System context (includes ROCC and TAAOC)
---@field air { landBased: SBJ__LandBasedPlatformContext } Air operations context
---@field gnssJamming SBJ__GNSSJammingContext GNSS jamming context

---US faction saved data structure
---@class SBJ__USSaveData: table
---@field sigint SBJ__SIGINTContext Signals intelligence context

---Saved data structure for persistent state
---@class SBJ__SaveData: table
---@field c SBJ__ChinaSaveData China faction data
---@field t SBJ__TaiwanSaveData Taiwan faction data
---@field u SBJ__USSaveData US faction data
---@field [SBJ__ChinaSaveData|SBJ__TaiwanSaveData|SBJ__USSaveData] SBJ__ChinaSaveData|SBJ__TaiwanSaveData|SBJ__USSaveData


-- ============================================================================
-- Faction & Side Configuration
-- ============================================================================
-- Faction configuration related types

---Side configuration for faction settings
---@class SBJ__SideConfig: table
---@field field SBJ__TaiwanConfig|SBJ__ChinaConfig Side field identifier ("c" for China, "u" for US, "t" for Taiwan)
---@field enemySide string Enemy side name
---@field displayName string Human-readable side name


-- ============================================================================
-- Unit Placement & Deployment Utilities
-- ============================================================================
-- Unit placement and deployment parameters for unitGenerator and other modules

---Linear placement parameters for positioning multiple units in a line
---Temporary parameter pack used for unit placement functions
---@class SBJ__LinearPlacementParams: table
---@field initialLocation CMO__Location Starting position
---@field num number Number of units to place
---@field bearing number Direction angle (degrees)
---@field distance number Distance between units (nautical miles)
---@field firstDistance? number Special distance for first unit (optional)

---Random units descriptor for creating multiple units at random positions
---@class SBJ__RandomUnitsDescriptor: table
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
---@class SBJ__UnitDescriptor: CMO__SetUnitDescriptor
---@field cargo SBJ__CargoDescriptor[] Cargo items to load onto the unit

---Ship formation specification - defines a single ship's configuration within a formation
---Used to specify ship positioning, armament, and embarked units in naval groups
---@class SBJ__ShipFormationSpec: table
---@field dbid number Ship platform database ID
---@field unitname string Ship unit name
---@field distance number Distance from formation center (nautical miles)
---@field angle number Angle offset from formation heading (degrees)
---@field embarkedUnits SBJ__EmbarkedUnit[]|nil Embarked aircraft/boats (optional)
---@field loadouts SBJ__Loadout[]|nil Ammunition stockpile configuration (optional)

---Formation configuration for internal ship creation
---Used internally by createShipFormation() to configure ship group formations
---@class SBJ__SAGFormationConfig: table
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
---@class SBJ__Loadout: table
---@field loadoutId number Ammunition configuration ID
---@field name? string Loadout display name
---@field num number Unit count
---@field missionName? string Mission name (optional)

---Cargo descriptor defining parameters for creating cargo units on ships
---@class SBJ__CargoDescriptor: table
---@field type number Cargo type identifier
---@field num number Quantity of cargo items to create
---@field dbid number Database ID of the cargo platform

---Cargo manifest organized by loadout configuration
---Maps a specific loadout to its associated cargo items
---@class SBJ__LoadoutCargoManifest: table
---@field loadoutId number Loadout configuration ID
---@field cargoItems table<number, SBJ__CargoDescriptor[]> Cargo items for this loadout

---Cargo transfer manifest organized by ship type
---Different ship types carry different loadout configurations
---@class SBJ__ShipTypeCargoManifest: table
---@field type075 SBJ__LoadoutCargoManifest[] Type 075 ship cargo manifests
---@field type071 SBJ__LoadoutCargoManifest[] Type 071 ship cargo manifests


-- ============================================================================
-- Airbase & Embarked Units
-- ============================================================================
-- Airbase and embarked unit configuration

---Embarked unit configuration for ships and airbases
---@class SBJ__EmbarkedUnit: table
---@field side string Side name (e.g., "China", "Taiwan", "US")
---@field type string Unit type (e.g., "Aircraft", "Helicopter")
---@field name string Unit name
---@field platformName string Display name of aircraft platform
---@field dbid number Unit database ID
---@field loadouts? SBJ__Loadout[] Unit ammunition configuration (optional)

---Airbase deployment descriptor
---Comprehensive configuration for aircraft deployment and ammunition stockpile at an airbase
---Used for scenario initialization and deployment planning
---@class SBJ__AirbaseDeploymentDescriptor: table
---@field name? string Airbase name
---@field baseGUID? string Airbase unit GUID reference
---@field dbid? number  Database ID if the object is a ship
---@field embarkedUnits? SBJ__EmbarkedUnit[] Aircraft units stationed at this base
---@field loadouts? SBJ__Loadout[] Ammunition stockpile in base magazines
---@field latitude? number Airbase latitude coordinate (optional)
---@field longitude? number Airbase longitude coordinate (optional)

---Per-DBID attrition detail for an airbase
---@class SBJ__AirbaseAttritionDetail: table
---@field dbid number Aircraft DBID
---@field expected integer Planned aircraft count
---@field current integer Current aircraft count
---@field loss integer Attrition count (expected - current)

---Per-airbase attrition summary
---@class SBJ__AirbaseAttritionBaseSummary: table
---@field baseName string Queried base name
---@field baseGUID string|nil Base GUID in deployment descriptor
---@field expectedTotal integer Planned aircraft total
---@field currentTotal integer Current aircraft total
---@field lossTotal integer Attrition total
---@field attritionPct number Attrition percentage (0-100)
---@field isDestroyed boolean Whether the airbase unit has been destroyed (entire wing loses combat capability)
---@field details SBJ__AirbaseAttritionDetail[] DBID-level attrition details

---Aggregated attrition summary for multiple airbases
---@class SBJ__AirbaseAttritionSummary: table
---@field queriedBaseNames string[] Queried base names
---@field expectedTotal integer Planned aircraft total across all found bases
---@field currentTotal integer Current aircraft total across all found bases
---@field lossTotal integer Attrition total across all found bases
---@field attritionPct number Aggregated attrition percentage (0-100)
---@field bases SBJ__AirbaseAttritionBaseSummary[] Per-airbase summaries
---@field missingBases string[] Queried base names not found in deployment descriptors

-- ============================================================================
-- Naval Operations
-- ============================================================================
-- Naval operations types for shipMovement and other modules

---Departure point definition with starting coordinates and heading
---@class SBJ__DeparturePoint: table
---@field startingPoint CMO__Location Starting coordinates
---@field heading number Initial heading angle

---Destination area definition with waypoints
---@class SBJ__DestinationArea: table
---@field area? CMO__Location[] Destination area waypoints

---Destination staging area with anchorage and vehicle staging zones
---Extends destination area with additional staging and anchorage areas
---@class SBJ__DestinationStagingArea: SBJ__DestinationArea
---@field anchorageArea CMO__Waypoint[] Anchorage area waypoints
---@field amphibiousVehicleStagingArea CMO__Waypoint[] Amphibious vehicle staging area waypoints
---@field heading number Formation heading angle

---Formation heading configuration
---@class SBJ__FormationHeading: table
---@field horizontal number Horizontal spacing angle
---@field vertical number Vertical spacing angle
---@field destination CMO__Waypoint[] Destination waypoints

---Submarine descriptor for SLCM operations
---@class SBJ__SubmarineDescriptor: table
---@field name string Submarine name/identifier
---@field guid string Submarine unit GUID (empty string if not yet created)
---@field course CMO__Waypoint[] Submarine patrol route waypoints
---@field from SBJ__DeparturePoint Starting location with heading
---@field weaponDBID number Weapon database ID for SLCM

---Surface Action Group descriptor
---@class SBJ__SAGDescriptor: table
---@field groupName string Group name
---@field from SBJ__DeparturePoint Starting location
---@field to? SBJ__DestinationStagingArea Destination staging area
---@field unitList table<string, SBJ__AirbaseDeploymentDescriptor> Unit list indexed by unit name
---@field area? string[] Operational area reference points
---@field missionName? string Mission name (optional)

---Carrier Strike Group descriptor
---@class SBJ__CSGDescriptor: table
---@field groupName string Group name
---@field from SBJ__DeparturePoint Starting location
---@field to SBJ__DestinationArea Destination area
---@field unitList table<string, SBJ__AirbaseDeploymentDescriptor> Unit list indexed by unit name


-- ============================================================================
-- Amphibious Operations
-- ============================================================================
-- Amphibious operations types for amphibiousAssault and landingOps modules

---Barge context for tracking barge operations and associated units
---@class SBJ__BargeContext: table
---@field guid string Barge unit GUID
---@field bridgeGUID? string Bridge unit GUID for barge connection (optional)
---@field roros string[] Array of RORO ship GUIDs transported by this barge

---Ship position calculation result for amphibious operation planning
---@class SBJ__ShipCalculationResult: table
---@field locations CMO__Location[] Calculated positions for ship formation
---@field locationIndex number Current position index in the locations array
---@field dbid number Platform database ID for this ship type

---Operation zone calculation result containing all ship type positions
---Stores calculated ship formation positions for each ship type in the operation zone
---@class SBJ__OperationZoneCalculationResult: table
---@field name string Operation zone name (e.g., "Taoyuan", "Penghu", "Sishu")
---@field result table<string, SBJ__ShipCalculationResult> Ship type calculation results indexed by ship type name (type075, type071, type076, type072iii, type072a, type073a, type071InLSTArea, ferry, roro, barge)

---Per-zone state for amphibious operation phase tracking
---@class SBJ__ZoneState: table
---@field phase string Current phase (constants.AMPHIBIOUS_PHASES value)
---@field amphibiousAssaultStartTime? number Amphibious assault start timestamp (optional)
---@field airlandingMissionStartTime? number Air landing mission start timestamp (optional)

---Amphibious operations context managing all amphibious operation state
---@class SBJ__AmphibOpsContext: table
---@field startTime string Operation start time
---@field zoneStates table<string, SBJ__ZoneState> Per-zone state indexed by zone name
---@field calculationResult table<string, SBJ__OperationZoneCalculationResult> Operation zone calculation results indexed by zone name
---@field barges table<string, SBJ__BargeContext> Barge contexts indexed by barge GUID
---@field fireSupportOnHold? boolean Whether SRBM fire-support strikes are on hold for ammo conservation; set true when ammo low and not all zones arrived, cleared once all zones reach staging

---ACV deployment parameters for launching air cushion vehicles
---Temporary parameter pack used for ACV deployment functions
---@class SBJ__ACVDeploymentParams: table
---@field bearing number Deployment direction (degrees)
---@field distance number Deployment distance (nautical miles)
---@field ship CMO__Unit Parent landing ship
---@field speed number ACV movement speed (knots)
---@field destination CMO__Waypoint[] ACV destination waypoints
---@field num integer Number of ACVs to deploy

---Vehicle offload parameters for unloading vehicles from landing ships
---Temporary parameter pack used for vehicle offloading functions
---@class SBJ__VehicleOffloadParams: table
---@field ship CMO__Unit Landing ship to offload from
---@field num integer Number of vehicles to offload
---@field bearing number Offload direction (degrees)
---@field distance number Distance between vehicles (nautical miles)
---@field firstDistance number Distance for first vehicle (nautical miles)

---Landing mission descriptor for amphibious operations
---@class SBJ__LandingMissionDescriptor: table
---@field name string Mission name
---@field loadoutId number Loadout configuration ID
---@field unitCount integer Number of units
---@field startTime number Mission start time

---Air Cushion Vehicle deployment configuration
---@class SBJ__ACVDescriptor: table
---@field bearing number Deployment direction (degrees)
---@field distance number Horizontal spacing between ACVs (nautical miles)
---@field speed number ACV transit speed (knots)
---@field destination CMO__Waypoint[] Destination waypoints
---@field area string[] Staging area reference points

---Amphibious landing platform base descriptor
---Common configuration for platforms that conduct landing missions with cargo transfer
---@class SBJ__CargoLandingPlatformDescriptor: table
---@field dbid number Platform database ID
---@field missions SBJ__LandingMissionDescriptor[] Landing mission descriptors
---@field zone string[] Landing zone reference points
---@field settings CMO__Mission Mission behavior settings (throttle, altitude, active status)
---@field transferManifest SBJ__ShipTypeCargoManifest Cargo transfer manifest by ship type

---Landing craft mission configuration for boat-based amphibious landings
---@class SBJ__BoatMissionDescriptor: SBJ__CargoLandingPlatformDescriptor

---Transport helicopter mission configuration for air assault operations
---@class SBJ__TransportHelicopterDescriptor: SBJ__CargoLandingPlatformDescriptor

---Attack helicopter mission configuration for close air support
---No cargo transfer capability
---@class SBJ__AttackHelicopterDescriptor: table
---@field dbid number Attack helicopter platform database ID
---@field missions SBJ__LandingMissionDescriptor[] CAS mission descriptors

---Transport aircraft configuration for airlift operations
---Defines transport aircraft deployment from airbases for airborne assault missions
---@class SBJ__TransportAircraftDescriptor: table
---@field name string Airbase name where transport aircraft are stationed
---@field guid string Airbase GUID reference
---@field dbid number Transport aircraft platform database ID
---@field missions SBJ__LandingMissionDescriptor[] Air landing mission descriptors
---@field cargoItemsForTransfer SBJ__LoadoutCargoManifest[] Cargo manifest for airlift operations

---Landing Ship Tank movement configuration
---Defines LST approach to beach
---@class SBJ__LSTMovementDescriptor: table
---@field speed number LST transit speed (knots)
---@field course {bearing:number, distance:number} Approach course (bearing in degrees, distance in nautical miles)

---Operational zone descriptor for amphibious operations
---Defines complete landing zone configuration including air and surface assets
---@class SBJ__OperationalZoneDescriptor: table
---@field name string Operational zone name
---@field baseGUID string Home base GUID for embarked units
---@field anchorageArea string[] LHD/LPD anchorage area reference points
---@field lstAnchorageArea string[] LST anchorage area reference points
---@field arrivalThreshold integer Minimum unit count to consider fleet arrived
---@field casArea string[] CAS area reference points
---@field offloadArea string[] Vehicle offload area reference points
---@field boat SBJ__BoatMissionDescriptor Landing craft configuration
---@field transportHelicopter SBJ__TransportHelicopterDescriptor Transport helicopter configuration
---@field attackHelicopter SBJ__AttackHelicopterDescriptor Attack helicopter configuration
---@field lstSettings SBJ__LSTMovementDescriptor LST movement configuration
---@field acv SBJ__ACVDescriptor Amphibious combat vehicle configuration

---Formation settings for amphibious operation layouts
---Defines spacing and movement parameters for amphibious assault ship formations
---Used internally for calculating ship positions during landing operations
---@class SBJ__AmphibiousFormationSettings: table
---@field distanceBetweenLSTAndLPDArea number Distance between LST and LPD staging areas
---@field horizontalDistance number Horizontal spacing between ships in formation
---@field verticalDistance number Vertical spacing between ships in formation
---@field transitDistance number Distance for transit phase
---@field shipSpeed number Ship movement speed
---@field heading table<string, SBJ__FormationHeading> Formation heading configuration
---@field acvSpeed number Amphibious combat vehicle speed
---@field acvTransitDistance number Amphibious combat vehicle transit distance
---@field acvHorizontalDistance number Amphibious combat vehicle horizontal spacing

---Fleet composition configuration for amphibious operations
---Defines the number of ships by type for amphibious assault fleets
---@class SBJ__FleetComposition: table
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

---Operation area descriptor for amphibious operation origin or destination
---@class SBJ__OperationAreaDescriptor: table
---@field startingPoints { type075: string[], type071?: string[] } Starting point reference points (type071 used at destination only)
---@field heading SBJ__FormationHeading Formation heading angle
---@field shipCounts SBJ__FleetComposition Ship quantity configuration

---Departure descriptor for amphibious operation origin
---@class SBJ__DepartureDescriptor: table
---@field areas SBJ__OperationAreaDescriptor[] Array of departure area descriptors
---@field stagingArea string[] Staging area reference points

---Destination descriptor for amphibious operation target
---@class SBJ__DestinationDescriptor: table
---@field areas SBJ__OperationAreaDescriptor[] Array of destination area descriptors

---Amphibious operation descriptor
---Comprehensive configuration for one complete amphibious landing operation
---Includes departure, destination, air landing zones, and participating forces
---Used for scenario initialization and deployment planning
---@class SBJ__AmphibiousOperationDescriptor: table
---@field name string Operation name (e.g., "Taoyuan", "Sishu", "Penghu")
---@field names string[] Unit name array
---@field sagNames string[] Surface Action Group names assigned to this operation
---@field from SBJ__DepartureDescriptor Departure configuration
---@field to SBJ__DestinationDescriptor Destination configuration
---@field airLandingZone string[] Air landing zone reference area
---@field contactThreshold integer Contact threshold for amphibious assault in air landing zone

---Amphibious Operations system configuration
---Comprehensive configuration for amphibious assault operations including
---cargo manifests, ship layouts, operational zones, and mission timing
---@class SBJ__AmphibOpsConfig: table
---@field periodOfTime number Check interval in seconds
---@field fireSupportHoldThreshold number SRBM total-ammo % below which recon-driven SRBM strikes (STRIKE/INFRASTRUCTURE/*) are held until all zones reach staging waters
---@field cargoList table<string, SBJ__CargoDescriptor[]> Cargo manifest by ship type
---@field cargoListForTransfer table<string, SBJ__CargoDescriptor[]> Transfer cargo groups
---@field missionStartime table<string, number[]> Mission start times by type (seconds)
---@field formationSettings SBJ__AmphibiousFormationSettings Ship formation layout configuration
---@field operations SBJ__AmphibiousOperationDescriptor[] Amphibious operation descriptors
---@field operationalZones SBJ__OperationalZoneDescriptor[] Operation zone descriptors
---@field transportAircraft SBJ__TransportAircraftDescriptor[] Transport aircraft configuration
---@field sag table<string, SBJ__SAGDescriptor> Surface Action Group descriptors
---@field isTesting boolean Whether the system is in testing mode

---Land-Attack Cruise Missile context managing LACM operations state
---@class SBJ__LACMContext: table
---@field enabled boolean Whether LACM is activated
---@field startTime string LACM start time

-- ============================================================================
-- Air Operations & Missions
-- ============================================================================
-- Air operations and mission types for assignMission and other modules

---Mission creation parameters for CMO API
---Maps directly to ScenEdit_AddMission parameters
---@class SBJ__MissionCreationParams: table
---@field name string The name of the mission
---@field side? string The side of the mission
---@field type string The type of the mission
---@field opts CMO__Mission The options for the mission

---Mission deployment descriptor for air operations
---Complete mission deployment configuration including base, units, weapons, and timing
---@class SBJ__MissionDeploymentDescriptor: table
---@field baseGUID string The GUID of the base to use for the mission
---@field missionCreationParams SBJ__MissionCreationParams The parameters for the mission
---@field unitCount integer The number of units to assign to the mission
---@field weaponDBID number The weapon DBID to use for the mission
---@field unitDBID number The unit DBID to use for the mission
---@field loadoutId? number The loadout ID to filter by, 0 for any loadout (optional)
---@field startTime? string The start time of the mission
---@field endTime? string The end time of the mission (optional)
---@field timeOnStation? string The time on station (optional)
---@field emcon string The EMCON settings for the mission

---Air operations context managing air tasking orders and aircraft status
---@class SBJ__AirOperationsContext: table
---@field landBased table Land-based aircraft context (reserved for future use)
---@field shipBased table Ship-based aircraft context (reserved for future use)
---@field enabled boolean Whether air operations system is activated
---@field airTaskingOrder table<string, SBJ__Wave> Air Tasking Order waves indexed by wave name


-- ============================================================================
-- Launcher & TEL Systems
-- ============================================================================
-- Launcher and Transporter-Erector-Launcher (TEL) systems for launcher module

---Area mode parameters for defining operational areas
---@class SBJ__AreaMode: table
---@field side string Side name
---@field shape string Area shape type
---@field distance number Distance parameter
---@field name? string Area name (optional)
---@field bear_offset? number Bearing offset (optional)

---Position definition with course and area reference points
---@class SBJ__Position: table
---@field course CMO__Waypoint[] Waypoints to area
---@field area string[] Area reference points, e.g., {"rp-100","rp-101","rp-102","rp-103","rp-104"}

---Operational area definition with multiple tactical position types
---Defines fire positions, hide areas, and reload locations for TEL operations
---@class SBJ__OperationalArea: table
---@field FP SBJ__Position[] Fire Points
---@field HA SBJ__Position[] Hide Areas
---@field AHA SBJ__Position[] Ammo Holding Areas
---@field RL SBJ__Position[] Reload Points
---@field mask {area: string[]}
---@field name? string Area name (optional)
---@field uShapeVertices? CMO__Location[] U shape vertices (optional)
---@field shelterPoints? CMO__Location[] Shelter points (optional)
---@field SHRL? SBJ__Position[] SHRL Path (optional)

---Weapon status tracking for ammunition count
---@class SBJ__WeaponStatus: table
---@field wpnCurrent number Current available ammunition count
---@field wpnDefault number Default/maximum ammunition count

---Base unit information with GUID and name
---@class SBJ__UnitBase: table
---@field guid string Unit GUID
---@field name string Unit name

---Unit operational status information
---@class SBJ__UnitStatus: table
---@field state missileSystemState Current unit state (STATIC/HIDE, etc.)
---@field operationalArea SBJ__OperationalArea Operational area definition for this resupply unit

---Ammunition unit descriptor combining base unit info and weapon status
---@class SBJ__AmmunitionUnitDescriptor: SBJ__UnitBase, SBJ__WeaponStatus

---Resupply unit descriptor with operational status and ammunition tracking
---@class SBJ__ResupplyUnitDescriptor: SBJ__UnitBase, SBJ__UnitStatus, SBJ__WeaponStatus
---@field unitCount number Number of resupply vehicles in this unit
---@field ammunition string Associated ammunition unit name for this resupply unit
---@field firingUnit string Associated firing unit name for this resupply unit

---Firing unit descriptor with weapon configuration and status
---@class SBJ__FiringUnitDescriptor: SBJ__UnitBase, SBJ__UnitStatus
---@field weaponDBID number|number[] The weapon database ID(s) to use for the firing unit
---@field ammoThreshold number The ammunition threshold for the firing unit, if not specified, the default value will be used
---@field resupplyUnit string The resupply unit name associated with this firing unit
---@field msg string The status message to display for the firing unit
---@field dbid number The firing unit database ID
---@field mountDescriptors? {dbid:number, mountCount:integer}[]

---Ammunition context data structure
---Tracks ammunition unit status and remaining ammunition counts
---@class SBJ__AmmunitionContext: SBJ__AmmunitionUnitDescriptor

---Resupply unit context data structure
---Extends ammunition context with operational area and resupply management
---@class SBJ__ResupplyUnitContext: SBJ__ResupplyUnitDescriptor
---@field reloadStartTime number|nil Reload operation start timestamp, nil if not currently reloading

---Firing unit context data structure
---Extends resupply unit context with weapon system configuration
---@class SBJ__FiringUnitContext: SBJ__FiringUnitDescriptor
---@field reloadStartTime number|nil Reload operation start timestamp, nil if not currently reloading
---@field stowStartTime number|nil Stowing start timestamp, nil if not currently stowing

---Missile system runtime context data structure
---Contains the missile system name, runtime status, and all system components
---@class SBJ__MissileSystemContext: table
---@field name string Missile system identifier
---@field enabled boolean Whether the weapon system is currently active
---@field reloadTime number Reload time for all firing units/resupply units in this system (seconds)
---@field stowTime number Stow time for all firing units in this system (seconds)
---@field firingUnits table<string, SBJ__FiringUnitContext> Firing units indexed by GUID for attack operations
---@field resupplyUnits table<string, SBJ__ResupplyUnitContext> Resupply units indexed by GUID for ammunition replenishment
---@field ammunitions table<string, SBJ__AmmunitionContext> Ammunition units indexed by GUID for tracking available munitions
---@field test? table Test data structure (optional)

---Ammunition subtotal with current/max counts and usage percentage
---@class SBJ__AmmoSubtotal: table
---@field current number Current ammunition count
---@field max number Maximum ammunition count
---@field percentage integer Usage percentage (current/max * 100), rounded to nearest integer; 0 when max is 0

---Ammunition inventory report aggregating firing/resupply/ammo subtotals and overall total
---@class SBJ__AmmoInventoryReport: table
---@field firing SBJ__AmmoSubtotal Firing units total (queried from live game state)
---@field resupply SBJ__AmmoSubtotal Resupply units total (sum of context wpnCurrent/wpnDefault)
---@field ammo SBJ__AmmoSubtotal Ammunition depots total (sum of context wpnCurrent/wpnDefault)
---@field total SBJ__AmmoSubtotal Combined total across firing + resupply + ammo

---Ground force context data structure
---Manages all ground-based weapon systems and fire support operations
---@class SBJ__GroundForceContext: table
---@field enabled boolean Whether ground force systems are activated
---@field mlrs SBJ__MissileSystemContext Multiple Launch Rocket System
---@field srbm SBJ__MissileSystemContext Short-Range Ballistic Missile system
---@field mrbm? SBJ__MissileSystemContext Medium-Range Ballistic Missile system (Optional)
---@field glcm SBJ__MissileSystemContext Ground-Launched Cruise Missile system
---@field ascm SBJ__MissileSystemContext Anti-Ship Cruise Missile system
---@field sam? SBJ__MissileSystemContext Surface-to-Air Missile system (Optional)
---@field fireSupportPlan? table<string, SBJ__FireSupportExecutionMatrix> Fire Support Plan execution matrices
---@field [SBJ__MissileSystemContext] SBJ__MissileSystemContext

---Unit property setting parameters for ground units
---@class SBJ__SetUnitPropertiesParams: table
---@field unit CMO__Unit Unit object (required)
---@field throttle string? Throttle setting (default: 'Stop')
---@field speed number? Speed (default: 0)
---@field course CMO__Waypoint[]? Waypoints (optional)
---@field holdPosition boolean? Whether to hold position (default: true)
---@field wcs integer? Weapon control status: 1=Free, 2=Hold (optional)
---@field formation CMO__FormationGroup? Formation settings (optional)

---Movement options for commanding units to a randomly selected position
---@class SBJ__MoveToPositionOpts: table
---@field unitName string Unit name (for messages)
---@field battery CMO__Unit Unit group
---@field positions SBJ__Position[] Position array
---@field positionType string Position type (RL/HA/AHA/FP)
---@field areaName string Operational area name (for messages)
---@field wcs integer? Weapon control status (optional)
---@field useLastCourse boolean? Whether to use the last waypoint in course

---Behavior switches for UnitEntersArea move-to-position flow
---@class SBJ__MoveToPositionBehavior: table
---@field hideOnEnterHA boolean Whether entering HA should force hide flow
---@field hideResupplyOnRLNoMeeting boolean Whether RL no-meeting fallback may hide resupply unit
---@field firingUnitLookupSide string Side name used to resolve paired firing unit

---Input options for missileSystem UnitEntersArea event handling
---@class SBJ__MoveToPositionEventOpts: table
---@field groundCtx table<string, SBJ__MissileSystemContext> Missile system runtime contexts by type
---@field unit CMO__Unit Unit that triggered UnitEntersArea
---@field event CMO__Event Event payload from CMO
---@field isAuto boolean Whether the flow runs in automatic mode
---@field contacts CMO__Contact[]|nil Current side contacts used for drop-contact handling
---@field behavior SBJ__MoveToPositionBehavior|nil Optional behavior switches for side-specific differences

---Structured result from a reload cycle action
---@class SBJ__ReloadCycleResult: table
---@field tag string Result tag (e.g. "OK")
---@field unitName string Unit name
---@field action string Action description

---Options for adding a unit-enters-area trigger to an event
---@class SBJ__AddTriggerOpts: table
---@field positionType string Position type (RL/HA/FP)
---@field position SBJ__Position Position configuration
---@field index integer Position index within operational area
---@field operationalArea SBJ__OperationalArea Operational area configuration
---@field enemySide string Enemy side name for target filter
---@field sideName string Owner side name


-- ============================================================================
-- Strike Planning & Targeting
-- ============================================================================
-- Strike planning and targeting types for strikePlanner module

---Airfield pattern configuration for target matching
---@class SBJ__AirfieldPatterns: table
---@field runwayPattern string Lua pattern for runway matching (e.g., "Runway %(%d+m%)")
---@field taxiwayPattern string Lua pattern for taxiway matching
---@field shelterPattern string Lua pattern for aircraft shelter matching
---@field hangarPattern string Lua pattern for hangar matching
---@field tarmacPattern string Lua pattern for tarmac matching
---@field helipadPattern string Lua pattern for helipad matching
---@field ammoBunkerPattern string Lua pattern for ammunition bunker matching
---@field ammoRevetmentPattern string Lua pattern for ammunition revetment matching

---Port pattern configuration for target matching
---@class SBJ__PortPatterns: table
---@field pierPattern string Lua pattern for pier matching

---Radar pattern configuration for target matching
---@class SBJ__RadarPatterns: table
---@field radarPattern string Lua pattern for radar facility matching

---SAM pattern configuration for target matching
---@class SBJ__SAMPatterns: table
---@field skyBowPattern string Lua pattern for Sky Bow SAM system matching

---ASM pattern configuration for target matching
---@class SBJ__ASMPatterns: table
---@field asmPattern string Lua pattern for anti-ship missile system matching

---C2 pattern configuration for target matching
---@class SBJ__C2Patterns: table
---@field hengshanPattern string Lua pattern for Hengshan command center matching

---Target category patterns configuration
---@class SBJ__TargetCategoryPatterns: table
---@field airfield SBJ__AirfieldPatterns Airfield-related patterns
---@field port SBJ__PortPatterns Port-related patterns
---@field radar SBJ__RadarPatterns Radar facility patterns
---@field sam SBJ__SAMPatterns SAM system patterns
---@field asm SBJ__ASMPatterns ASM system patterns
---@field c2 SBJ__C2Patterns Command and control patterns

---Target scanning configuration for contact categorization
---@class SBJ__TargetScanningConfig: table
---@field distanceThreshold number Maximum distance threshold in nautical miles for base/port proximity matching
---@field taiwanAirBases string[] Array of Taiwan airbase names to scan for
---@field taiwanPorts string[] Array of Taiwan port names to scan for
---@field targetCategories SBJ__TargetCategoryPatterns Pattern configurations for each target category

---Target entry representing a scanned and categorized target
---@class SBJ__TargetEntry: table
---@field name string Target display name (format: "BaseName/Description" for base-related targets, or just "Description" for standalone targets)
---@field guid string Target contact GUID
---@field category string Target category ("Airfield", "Port", "ISR", "SAM", "ASM", "C2")
---@field subType string Target sub-type description (e.g., "Runway (3000m)", "Shelter", "Pier", "Radar")

---Target query parameter for filtering targets by base name and facility sub-types
---@class SBJ__TargetQueryParam: table
---@field baseName? string Base name pattern for matching (optional, if omitted matches all)
---@field subTypes string[] Array of facility sub-type patterns to match

---Target template for strike planning
---@class SBJ__TargetTemplate: table
---@field objs? SBJ__TargetQueryParam[] Target query parameters (for fixed targets, optional)
---@field areas? string[][] Operation areas
---@field filterNames? string[] Filter function names (for dynamic targets, optional)
---@field contactAge number Contact valid time (seconds)
---@field minTargetCount number Minimum target count threshold
---@field ammoPerTarget? number Ammunition count per target

---Target definition extending template with contact list
---@class SBJ__Target: SBJ__TargetTemplate
---@field list string[] List of target contact GUIDs

---Task definition with target information
---@class SBJ__Task: table
---@field target SBJ__Target Target information

---Filter parameters for target selection and filtering
---@class SBJ__FilterParams: table
---@field config? SBJ__Config Configuration data
---@field saveData? SBJ__SaveData Saved data
---@field task SBJ__Task Task information
---@field contacts CMO__Contact[] Contact array

---Firing unit definition for fire support operations
---@class SBJ__FiringUnit: table
---@field name string Firing unit name
---@field weaponDBID number Firing unit weapon database ID

---Fire Support Task template extending task with firing units
---@class SBJ__FireSupportTaskTemplate: SBJ__Task
---@field name string FST name
---@field missileSystem string Missile system type
---@field firingUnits SBJ__FiringUnit[] Firing unit array

---Fire Support Task execution state
---@class SBJ__FireSupportTask: SBJ__FireSupportTaskTemplate
---@field startTime string Task start time
---@field isFinished boolean Whether task is finished

---Fire Support Execution Matrix template
---@class SBJ__FireSupportExecutionMatrixTemplate: table
---@field name string FSEM name
---@field isFirstWave boolean Whether it's the first wave attack
---@field strikeInterval number Strike interval time (seconds)
---@field fireSupportTasks SBJ__FireSupportTaskTemplate[] FST template array

---Fire Support Execution Matrix with execution state
---@class SBJ__FireSupportExecutionMatrix: SBJ__FireSupportExecutionMatrixTemplate
---@field isActivated boolean Whether FSEM is activated
---@field allFiringUnitsInPosition boolean Whether all firing units are in position
---@field isFinished boolean Whether FSEM is finished
---@field fireSupportTasks SBJ__FireSupportTask[] Fire support tasks array

---Attack contacts parameters for coordinating strikes
---@class SBJ__AttackContactsOpts: table
---@field contacts table<integer, string> A table of contact GUIDs to attack
---@field qty integer The number of salvos to launch
---@field firingUnits SBJ__FiringUnit[] A table of firing units to use for the attack
---@field weaponDBID? number The weapon DBID to use for the attack (if not specified, the default weapon will be used)
---@field sideName? string The side to use for the attack (if not specified, the side of the first firing unit will be used)

---Parameters for generating missile flight paths
---@class SBJ__GenerateMissilePaths_Params: table
---@field targetLat number Target latitude
---@field targetLon number Target longitude
---@field launcherLat number Launcher latitude
---@field launcherLon number Launcher longitude
---@field radarRange number Radar range (nautical miles)
---@field missileCount? number Number of missiles (default is 5)
---@field missileSpeedKts? number Missile speed in knots (default is 600)
---@field missileRangeNm? number Maximum missile range in nautical miles (default is 100)

---Missile path definition with waypoints and timing
---@class SBJ__MissilePath: table
---@field waypoints CMO__Waypoint[] Missile waypoint list
---@field launchTime number Launch time (UTC timestamp)


-- ============================================================================
-- Reconnaissance & Intelligence
-- ============================================================================
-- Reconnaissance and intelligence types for recon module

---Base reconnaissance queue entry template with shared fields
---@class SBJ__ReconQueueEntryBase: table
---@field type string Reconnaissance type: "UAV"|"satellite"
---@field endTime? string Scheduled end time in format "YYYY-MM-DD HH:MM:SS" (optional)

---UAV reconnaissance queue entry template
---Complete configuration for UAV reconnaissance missions including launch and flight parameters
---@class SBJ__ReconQueueEntryTemplateUAV: SBJ__ReconQueueEntryBase
---@field baseGUID string Base GUID where UAV is stationed
---@field unitDBID number UAV platform database ID
---@field course CMO__Waypoint[] Waypoints for reconnaissance route
---@field unitCount number Number of UAVs to deploy
---@field speed number Cruise speed in knots for tracking mode
---@field takeoffTime? string Scheduled takeoff time in format "YYYY-MM-DD HH:MM:SS"
---@field isTracking? boolean Whether to track this reconnaissance mission (optional)

---Satellite reconnaissance queue entry template
---Simplified configuration for satellite reconnaissance requiring only timing information
---@class SBJ__ReconQueueEntryTemplateSatellite: SBJ__ReconQueueEntryBase
---@field platformKey string Semantic platform key (e.g. "EOS", "ELINT") used to index reconStrikeMatrix

---Union type for all reconnaissance entry templates
---@alias SBJ__ReconQueueEntryTemplate SBJ__ReconQueueEntryTemplateUAV|SBJ__ReconQueueEntryTemplateSatellite

---UAV reconnaissance queue entry with execution state
---@class SBJ__ReconQueueEntryUAV: SBJ__ReconQueueEntryTemplateUAV
---@field unitGUID? string UAV unit GUID (nil if not yet created)
---@field hasLaunched boolean Whether reconnaissance mission has launched
---@field isFinished? boolean Whether reconnaissance mission has finished (optional)
---@field trackingTargetGUID? string Target contact GUID being tracked (optional, only used when isTracking is true)

---Satellite reconnaissance queue entry with execution state
---@class SBJ__ReconQueueEntrySatellite: SBJ__ReconQueueEntryTemplateSatellite
---@field isFinished? boolean Whether reconnaissance mission has finished (optional)

---Union type for all reconnaissance queue entries with execution state
---@alias SBJ__ReconQueueEntry SBJ__ReconQueueEntryUAV|SBJ__ReconQueueEntrySatellite

---Reconnaissance context managing reconnaissance operations state
---@class SBJ__ReconContext: table
---@field enabled boolean Whether reconnaissance system is activated
---@field queue SBJ__ReconQueueEntry[] Reconnaissance mission queue
---@field frontlineRedirected boolean Sticky flag set true once frontline strike redirect activates; never cleared

---Reconnaissance-Strike mapping entry
---Defines strike mission to execute after reconnaissance platform detects target
---@class SBJ__ReconStrikeMapping: table
---@field name string Strike mission name
---@field type "air"|"ground" Strike mission type

---Reconnaissance platform type
---@alias SBJ__ReconPlatformType "UAV"|"satellite"|"SIGINT"


-- ============================================================================
-- Dynamic Operations (ATO/FSEM)
-- ============================================================================
-- Dynamic operations types for dynamicATOInsertion and dynamicFireSupportPlan modules

---Generated operations tracker for dynamic operations
---@class SBJ__GeneratedOperationsTracker: table
---@field air table<string, boolean> Generated air operation names indexed by operation name
---@field ground table<string, boolean> Generated ground operation names indexed by operation name

---Dynamic operations context managing intelligence-driven adaptive strike planning
---@class SBJ__DynamicOperationsContext: table
---@field enabled boolean Whether dynamic operations system is enabled
---@field lastEvaluationTime? number Last evaluation timestamp (Unix time)
---@field generatedOperations SBJ__GeneratedOperationsTracker Generated operation name tracker
---@field reconSchedule SBJ__ReconScheduleEntry[] Reconnaissance-driven operation schedule

---Reconnaissance schedule entry for intelligence gathering operations
---@class SBJ__ReconScheduleEntry: table
---@field time string Reconnaissance time in format "2027-06-09 14:30:00"
---@field type string Reconnaissance type: "satellite", "aircraft", or "UAV"
---@field delay number Delay trigger time (seconds)
---@field executed boolean Whether already executed
---@field operations SBJ__Operation[] Operations to execute

---Operation definition for dynamic operations
---@class SBJ__Operation: table
---@field type string Template type
---@field executed boolean Whether operation has been executed
---@field template SBJ__FireSupportExecutionMatrixTemplate|SBJ__WaveTemplate Operation template (FSEM or Wave)
---@field executionResult? boolean Operation execution result (true for success, false for failure)

---Wave template for Dynamic ATO Insertion
---@class SBJ__WaveTemplate: table
---@field name string ATO wave name
---@field isFirstWave boolean Whether it's the first wave attack
---@field strikeInterval number Strike interval time (seconds)
---@field packages SBJ__PackageTemplate[] ATO package array

---Package template for air operation coordination
---@class SBJ__PackageTemplate: SBJ__Task
---@field striker? SBJ__MissionDeploymentDescriptor Main striker configuration (optional)
---@field escort? SBJ__MissionDeploymentDescriptor Escort configuration (optional)
---@field wildWeasel? SBJ__MissionDeploymentDescriptor Wild Weasel configuration (optional)
---@field jammer? SBJ__MissionDeploymentDescriptor Jammer configuration (optional)
---@field tanker? SBJ__MissionDeploymentDescriptor Tanker configuration (optional)
---@field reconUAV? SBJ__ReconQueueEntryTemplateUAV Reconnaissance UAV configuration (optional)
---@field timeToReady? number Ready time in minutes (optional)
---@field [SBJ__MissionDeploymentDescriptor] SBJ__MissionDeploymentDescriptor

---Loadout status tracking for mission preparation
---@class SBJ__LoadoutStatus: table
---@field isLoadoutInitiated boolean Whether loadout process has started
---@field loadoutInitiatedTime number|nil Loadout initiation timestamp
---@field expectedReadyTime number|nil Expected ready timestamp
---@field loadoutStartTime number|nil Loadout start timestamp

---Package execution state extending template with launch and loadout status
---@class SBJ__Package: SBJ__PackageTemplate
---@field hasLaunched boolean Whether package has launched
---@field loadoutStatus SBJ__LoadoutStatus Loadout preparation status

---Wave execution state with packages and activation status
---@class SBJ__Wave: SBJ__WaveTemplate
---@field packages SBJ__Package[] Array of packages in this wave
---@field hasLaunched boolean Whether wave has launched
---@field isActivated boolean Whether wave is activated


-- ============================================================================
-- Electronic Warfare
-- ============================================================================
-- Electronic warfare types for EW modules (SIGINT, GNSS Jamming, Comms Jamming)

---GNSS jammer deployment descriptor
---Serves as a blueprint for creating jammer units, related events, and jamming zones
---@class SBJ__GNSSJammerDescriptor: table
---@field name string Jammer unit identifier
---@field zoneName string Associated jamming zone name for area creation
---@field point? CMO__Location Deployment coordinates
---@field randomRadius number Position randomization radius (nautical miles)
---@field radius number GNSS jamming effectiveness radius (nautical miles)

---GNSS jammer context extending descriptor with runtime state
---@class SBJ__GNSSJammerContext: SBJ__GNSSJammerDescriptor

---Enhanced SIGINT detection result with confidence and metadata
---@class SBJ__SIGINTResult: table
---@field longitude number Detected longitude coordinate
---@field latitude number Detected latitude coordinate
---@field isDetected boolean Whether signal is detected
---@field confidence number Detection confidence level (0-1)
---@field detectorId? string ID of detecting unit (optional)
---@field timestamp number Detection timestamp

---Radio transmission context data structure
---Tracks and manages detected radio transmission sources with detection metadata
---@class SBJ__RadioTransmissionContext: table
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
---@class SBJ__SIGINTDisplayData: table
---@field R? number Red value (default: 255)
---@field G? number Green value (default: 255)
---@field B? number Blue value (default: 255)
---@field lifeTime? number Display time in seconds (default: 4)
---@field fontSize? number Font size (default: 16)
---@field showConfidence? boolean Whether to show confidence level

---SIGINT context managing all transmission tracking
---@class SBJ__SIGINTContext: table
---@field transmissions table<string, SBJ__RadioTransmissionContext> Radio transmission contexts indexed by GUID
---@field reconAircraft table<string, SBJ__AircraftContext> Recon aircraft context data structure indexed by GUID
---@field enabled boolean Whether SIGINT is activated
---@field maxCount number Maximum detection level

---Communications jamming context managing electronic warfare jamming operations
---@class SBJ__CommsJammingContext: table
---@field enabled boolean Whether communications jamming system is activated
---@field jammers table<string, SBJ__AircraftContext> Jamming aircraft indexed by GUID


-- ============================================================================
-- Command & Control (C2) and IADS
-- ============================================================================
-- Command & Control and Integrated Air Defense System types for IADS module

---Radar context for tracking radar status and communications
---@class SBJ__RadarContext: table
---@field name string Radar unit name
---@field guid string Radar unit GUID
---@field OODA CMO__OODA Radar OODA data
---@field currOODA CMO__OODA Current OODA state
---@field isOutOfComms boolean Whether the radar is out of communications
---@field outofcomms number Radar out of communications threshold
---@field EMCONSetting? string EMCON setting for radar

---Command and Control (C2) context data structure
---@class SBJ__C2Context: table
---@field name string C2 node name
---@field msg string Status message
---@field guid string C2 node GUID
---@field areas table<number, string[]> Associated operational areas
---@field sam table<string, SBJ__RadarContext> Surface-to-Air Missile systems
---@field radar? table<string, SBJ__RadarContext> Radar systems (optional)
---@field [string] table<string, SBJ__RadarContext>

---C2 node deployment descriptor
---Defines how to create and deploy a single Command and Control node
---@class SBJ__C2Descriptor: table
---@field position? CMO__Location C2 position coordinates
---@field areas string[][] Operation areas array
---@field name string Operation area name

---Integrated Air Defense System configuration
---Defines C2 facility parameters and deployment settings for IADS
---@class SBJ__IADSConfig: table
---@field ratio {C2:number} C2 facility ratio multiplier
---@field c2FacilityDBIDs number[] Database IDs for C2 facility types
---@field randomRadius number Random deployment radius (nautical miles)
---@field c2Deployments SBJ__C2Descriptor[] C2 node deployment descriptors

---IADS context managing air defense system state
---Tracks all Command and Control nodes and system activation status
---@class SBJ__IADSContext: table
---@field c2? table<string, SBJ__C2Context> C2 node context data structure indexed by GUID (optional)
---@field rocc? table<string, SBJ__C2Context> ROCC context data structure indexed by GUID (optional)
---@field taaoc? table<string, SBJ__C2Context> TAAOC context data structure indexed by GUID (optional)
---@field enabled boolean Whether IADS is activated
---@field [string] table<string, SBJ__C2Context>

-- ============================================================================
-- Aircraft & Communications Tracking
-- ============================================================================
-- Aircraft and communications tracking types for commsJamming and other modules

---Aircraft context for tracking aircraft status and communications
---@class SBJ__AircraftContext: table
---@field guid string Aircraft unit GUID
---@field OODA CMO__OODA Aircraft OODA data
---@field commsLevel number Aircraft communications level
---@field commsBase number Aircraft communications base level
---@field commsThreshold number Aircraft communications threshold
---@field outofcomms number Aircraft out of communications threshold

---Land-based platform context tracking aircraft and AEW
---@class SBJ__LandBasedPlatformContext: table
---@field AC table<string, SBJ__AircraftContext> Aircraft context data structure indexed by GUID
---@field AEW table<string, SBJ__AircraftContext> AEW aircraft context data structure indexed by GUID


-- ============================================================================
-- Runway Repairment
-- ============================================================================
-- Runway damage assessment and repair management types

---Runway entry for tracking runway damage and repair progress
---@class SBJ__RunwayEntry: table
---@field guid string Runway unit GUID
---@field startTime number|nil Repair operation start timestamp, nil if not yet started

---Unified runway repair configuration for all factions
---@class SBJ__RunwayRepairConfig: table
---@field percentagePerHour number Repair percentage per hour
---@field runwayDBIDs number[] List of runway database IDs to repair (China)
---@field airBases string[] List of Taiwan airbases with runways to repair (Taiwan)
---@field runwaySubTypes string[] Array of runway facility sub-type patterns to match (Taiwan)

---Runway repair context managing runway damage repair operations
---@class SBJ__RunwayRepairmentContext: table
---@field enabled boolean Whether runway repair system is activated
---@field runways SBJ__RunwayEntry[] Array of runways being tracked for repair


-- ============================================================================
-- Tactical Area Generation
-- ============================================================================
-- Types for generating tactical area layouts (U-shaped areas, fire points, etc.)

---Internal squares configuration for U-shaped area
---Defines three functional zones inside U-shaped tactical area (ammo, hide, reload)
---@class SBJ__UShapeInternalSquaresConfig: table
---@field size number Square size in nautical miles
---@field marginToWall? number Safety margin between squares and U-shape walls (default: 0.1 nm)
---@field marginBetweenSquares? number Safety margin between squares (default: 0.1 nm)

---Fire points configuration for U-shaped area
---Defines fire point positions on circle perimeter around U-shaped area
---@class SBJ__UShapeFirePointsConfig: table
---@field radius number Radius of circle for fire point placement in nautical miles
---@field squareSize number Size of fire point squares in nautical miles
---@field count number Number of fire points to generate
---@field angleRange? number Angular range for placement in degrees, 360=full circle (default: 360)
---@field margin? number Safety margin between fire points in nautical miles (default: 0.1 nm)

---U-shaped tactical area configuration
---Complete configuration for generating U-shaped area with optional internal zones and fire points
---@class SBJ__UShapeAreaConfig: table
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
---@class SBJ__UShapeAreaResult: table
---@field uShapeVertices CMO__Location[] Array of 8 vertices forming U-shape polygon
---@field ammoArea? CMO__Location[] Ammo holding area vertices (4 points) if internal squares configured
---@field hideArea? CMO__Location[] Hide area vertices (4 points) if internal squares configured
---@field reloadArea? CMO__Location[] Reload area vertices (4 points) if internal squares configured
---@field firePoints? table<integer, CMO__Location[]> Array of fire point areas, each with 4 vertices, if fire points configured
---@field shelterPoints? CMO__Location[] Shelter points

---Path waypoint for TEL movement routes
---@class SBJ__PathWaypoint: table
---@field latitude number Waypoint latitude coordinate
---@field longitude number Waypoint longitude coordinate

---Movement path between two tactical positions
---@class SBJ__MovementPath: table
---@field waypoints SBJ__PathWaypoint[] Array of waypoints forming the path

---Movement path calculation configuration
---Parameters for calculating tactical movement paths with U-shape avoidance
---@class SBJ__MovementPathsConfig: table
---@field centerLat number U-shape center latitude in degrees
---@field centerLon number U-shape center longitude in degrees
---@field width number U-shape width in nautical miles
---@field height number U-shape height in nautical miles
---@field thickness number U-shape wall thickness in nautical miles
---@field openingAngle number U-shape opening direction in degrees (0=North, 90=East, 180=South, 270=West)
---@field ammoArea CMO__Location[] Ammo holding area vertices (4 points)
---@field hideArea CMO__Location[] Hide area vertices (4 points)
---@field reloadArea CMO__Location[] Reload area vertices (4 points)
---@field firePoints? table<integer, CMO__Location[]> Fire point areas array, each with 4 vertices (optional)
---@field avoidanceMargin? number Safety margin for U-shape avoidance in nautical miles (default: 0.3)

---Movement paths configuration for tactical area
---Maps path types to their waypoint arrays
---@class SBJ__MovementPaths: table
---@field FP table<integer, SBJ__MovementPath> Fire Point paths: hide area -> each fire point
---@field HA SBJ__MovementPath Hide Area path: reload point -> hide area
---@field RL table<integer, SBJ__MovementPath> Reload paths: each fire point -> reload point
---@field AHA SBJ__MovementPath Ammo Holding Area path: reload point -> ammo holding area
---@field SHRL SBJ__MovementPath Shelter Hide Reload Loop path: shelter -> reload point

---Setup menu configuration result containing user selections
---@class SBJ__SetupResult: table
---@field jammers SBJ__GNSSJammerDescriptor[] GNSS jammer deployment configurations
---@field airbases SBJ__AirbaseDeploymentDescriptor[] Airbase deployment configurations
---@field missileSystems {key: string, unitname: string, category: string, center: CMO__Location, openingAngle: number, tacticalAreas: SBJ__UShapeAreaResult, paths: SBJ__MovementPaths}[] TEL missile system deployment configurations with tactical areas and paths

---EMCON configuration result containing user selections
---@class SBJ__EmconResult: table
---@field doctrine {id: string, weaponsFree: boolean}[] SAM system deployment configurations
