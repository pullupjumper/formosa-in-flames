-- ============================================================================
-- CMO Game API Types
-- ============================================================================
-- CMO native API type definitions provided by the game engine

---@meta

---Display weapon allocation from attacker to target
---Supply attacker GUID and contact GUID to see salvos between units
---@param attackerGUID string
---@param contactGUID string
---@param attackingSideGUID string
---@return table<integer, { weapon: integer, qtyFired: integer, shooter: string, target: string, qtyAssigned: integer, weaponName: string }>|nil # Returns a weapon allocation table
function ScenEdit_WeaponAllocation(attackerGUID, contactGUID, attackingSideGUID) end

---Create a new flight plan for a mission
---@param sideName string
---@param missionName string
---@param opts CMO__FlightPlanOptions
---@return table<number, any>|nil # Returns all the flights on the mission (currently only returns the first flight, will be fixed in an upcoming release)
function ScenEdit_CreateMissionFlightPlan(sideName, missionName, opts) end

---Get a zone by name or GUID
---@param sideName string
---@param zoneName string
---@param zoneType number The zone type (constants.ZONE_TYPES)
---@return CMO__Zone|nil
function ScenEdit_GetZone(sideName, zoneName, zoneType) end

---@param params CMO__MinefieldDescriptor
---@return number
function ScenEdit_AddMinefield(params) end

---@param params CMO__DeleteMinefieldDescriptor
---@return number
function ScenEdit_DeleteMinefield(params) end

---@class CMO__MinefieldDescriptor: table
---@field side string
---@field dbid number
---@field number number
---@field delay number
---@field area string[]

---@class CMO__DeleteMinefieldDescriptor: table
---@field side string
---@field area string[]

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
---@field spacing_unit? string Multiplier to the spacing if required
---@field bearing? number Desired bearing of formation lead (0-360)
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
-- Logging
-- ============================================================================
-- Deferred log result types shared by modules that emit batched summaries

---One outcome captured for batched log emission
---Producers return this shape instead of a formatted string, so field ordering
---and status counting stay owned by LogFormat at emit time.
---@class SBJ__LogResult: table
---@field tag string Status tag accepted by LogFormat ("OK"/"SKIP"/"FAIL"/"ERROR"/"WARN"/"HOLD"/"RESUME")
---@field fields table<string, any> Log fields keyed by field name
---@field details? SBJ__LogResult[] Rows nested one level under this one, excluded from the rollup

---Batched log collector returned by LogFormat.report
---Rows are buffered until emit routes FAIL and ERROR to the error sink and
---everything else to the info log; empty sinks emit nothing.
---@class SBJ__LogReport: table
---@field add fun(tag: string, fields: table<string, any>|nil, details?: SBJ__LogResult[]) Buffer one row and its nested detail rows
---@field addAll fun(results: SBJ__LogResult[]|nil) Buffer every result in order, ignoring nil
---@field emit fun(actionFields?: table<string, any>) Emit the buffered rows; optional batch-level counters are appended to the action


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
---@class SBJ__SIGINTFormulaConfig: table
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
---@field maxRangeNm number Maximum detection range (nautical miles)
---@field detectionThreshold number Distance threshold for guaranteed detection (nautical miles)
---@field maxDetectionRange number[] Range [min, max] for random maximum detection distance
---@field formulaConstants SBJ__SIGINTFormulaConfig Detection formula constants
---@field defaultDisplay SBJ__SIGINTDisplayConfig Default display configuration
---@field minPolygonPoints integer Minimum polygon points for area validation
---@field detectionSkipProbability number Probability to skip detection check for performance (0-1)

---Aircraft communications default values
---@class SBJ__AircraftCommsConfig: table
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
---@field aircraftDefaults SBJ__AircraftCommsConfig Aircraft communications default values

---GNSS jammer weapon configuration
---@class SBJ__GNSSJammedWeapon: table
---@field dbid number Weapon database ID
---@field jammingResistance number Jamming resistance value

---GNSS jamming configuration
---@class SBJ__GNSSJammingConfig: table
---@field randomRadiusNm number Random deployment radius (nautical miles)
---@field radius number Jamming effectiveness radius (nautical miles)
---@field gnssGuidedWeapons SBJ__GNSSJammedWeapon[] GNSS-guided weapons to jam
---@field jammers table<string, SBJ__GNSSJammerDescriptor> GNSS jammer descriptors indexed by jammer name

---Weapon system configuration
---@class SBJ__MissileSystemConfig: table
---@field weaponCountDefault number Default weapon count
---@field ammoThreshold number Ammunition threshold for resupply
---@field contactAge? number Contact valid age in seconds
---@field reloadTime number Reload time in seconds
---@field stowTime number Stow time in seconds
---@field ammunitions table<string, SBJ__AmmunitionUnitDescriptor> Ammunition units indexed by unit name
---@field resupplyUnits table<string, SBJ__ResupplyUnitDescriptor> Resupply units indexed by unit name
---@field firingUnits table<string, SBJ__FiringUnitDescriptor|SBJ__FiringUnitWithWeaponRangeDescriptor> Firing units indexed by unit name

---Per-side ground policy; the only differences between the China and Taiwan event scripts
---@class SBJ__GroundPolicyConfig: table
---@field isAuto boolean Whether the reload/hide cycle and position events run in automatic mode
---@field hideOnEnterHA boolean Whether entering HA should force hide flow
---@field hideResupplyOnRLNoMeeting boolean Whether RL no-meeting fallback may hide resupply unit

---Ground force configuration
---@class SBJ__GroundConfig: table
---@field policy SBJ__GroundPolicyConfig Ground policy
---@field missileSystemTypes table<string,SBJ__MissileSystemConfig>  Missile system type configurations

---Dynamic operation type discriminator
---@alias SBJ__OperationType "air"|"ground"

---Strike mapping rewrite rule used by frontline redirect
---@class SBJ__StrikeMappingRewriteRule: table
---@field fromPrefix string Prefix that identifies the original mapping family (e.g. "AIR/STRIKE/AB/W/")
---@field toPrefix string Prefix substituted into the rewritten mapping name (e.g. "AIR/STRIKE/AB/W/AAR/")
---@field type SBJ__OperationType Strike mission type the rule applies to

---Frontline strike redirect configuration
---Switches strike mappings from frontline bases to rear bases with AAR support
---@class SBJ__FrontlineRedirectConfig: table
---@field enabled boolean Whether the redirect mechanism is active
---@field attritionThresholdPct number Aggregated attrition percentage that triggers redirect (0-100)
---@field frontlineBaseNames string[] Frontline airbase names (must match config.red.air.deployedACs[].name)
---@field mappings SBJ__StrikeMappingRewriteRule[] Strike mapping rewrites applied once redirect is active

---Reconnaissance configuration
---@class SBJ__ReconConfig: table
---@field templates table<string, SBJ__ReconUAVTemplate> Reconnaissance templates indexed by template name
---@field queue SBJ__ReconQueueDescriptor[] Reconnaissance queue as authored in config; initQueue turns each plan into its SBJ__ReconQueueEntry form
---@field strikeMappings table<string, SBJ__ReconStrikeMapping[]> Strike mappings indexed by reconnaissance objective ID
---@field frontlineRedirect SBJ__FrontlineRedirectConfig Frontline strike redirect configuration
---@field isTesting boolean Whether system is in test mode
---@field observationWindowSec number Dynamic operation observation window in seconds, shared by air and ground (window starts at recon trigger time; operations re-evaluate every tick within it, and are dropped from their batch once it expires)
---@field fsemStaleAfterSec number Age in seconds after which an active unfinished FSEM is retired by FsemBuilder, releasing its firing units back to the assignable pool

---Air package timing configuration
---@class SBJ__AirTimingConfig: table
---@field assignmentSafetyMargin number Seconds reserved between assignment completion and planned takeoff
---@field flightTimeSafetyMargin number Extra seconds added to estimated transit time
---@field supportLeadTime table<string, number> Support-role arrival lead time before striker TOT
---@field tankerSetupTime number Seconds tanker should be on station before the earliest receiver arrives
---@field tankerUnresolvedArrivalLeadTime number Tanker lead time before striker TOT when receiver arrival cannot be resolved
---@field unresolvedFlightTime { striker: number, support: number } Fallback flight times when route data cannot be resolved
---@field missionDuration { standard: number, tanker: number } Mission durations measured from TOS/TOT, or takeoff in takeoff-only mode
---@field cruiseSpeed { combatAircraft: number, tanker: number } Cruise speeds used for flight-time estimation in knots

---Air operations configuration
---@class SBJ__AirOperationsConfig: table
---@field strikeInterval number Default interval between strike packages of an air operation (seconds)
---@field minimumStrengthRatio number Fraction of a role's requested aircraft a base must supply for the package to be dispatched; at or above it the package launches understrength rather than being skipped
---@field timing SBJ__AirTimingConfig Dynamic ATO timing and safety margins
---@field deployedACs SBJ__AirbaseDeploymentDescriptor[] Land-based aircraft deployment
---@field weaponCount? number Weapons per loadout slot (Taiwan only)

---Surface operations configuration (LACM)
---@class SBJ__SurfaceLACMConfig: table
---@field weaponDBID number LACM weapon database ID
---@field csg SBJ__CSGDescriptor Carrier Strike Group configuration
---@field targetlist string[] Target GUID list

---Surface operations configuration
---@class SBJ__SurfaceOperationsConfig: table
---@field lacm SBJ__SurfaceLACMConfig LACM configuration
---@field sags? table<string, SBJ__SAGDescriptor> Surface Action Groups (Taiwan only)
---@field deployedShips? SBJ__AirbaseDeploymentDescriptor[] Deployed ships (Taiwan only)

---Submarine SLCM configuration
---@class SBJ__SubSurfaceSLCMConfig: table
---@field weaponDBID number SLCM weapon database ID
---@field submarines table<string, SBJ__SubmarineDescriptor> Submarines indexed by submarine name
---@field targetlist string[] Target GUID list
---@field randomRadiusNm number Random deployment radius (nautical miles)

---Subsurface operations configuration
---@class SBJ__SubsurfaceOperationsConfig: table
---@field slcm SBJ__SubSurfaceSLCMConfig SLCM configuration

---IADS configuration for faction
---@class SBJ__IADSFactionConfig: table
---@field taaoc? SBJ__C2Descriptor[] TAAOC descriptors
---@field rocc? SBJ__C2Descriptor[] ROCC descriptors

---Red side configuration (script-driven attacker)
---@class SBJ__RedConfig: table
---@field triggers SBJ__TriggerConfig Trigger timing configuration
---@field targetScanning SBJ__TargetScanningConfig Target scanning configuration
---@field repairRunway SBJ__RedRunwayRepairConfig Runway repair configuration
---@field sigint SBJ__SIGINTConfig SIGINT configuration
---@field iads SBJ__IADSConfig IADS configuration
---@field commsJamming SBJ__CommsJammingConfig Communications jamming configuration
---@field gnssJamming SBJ__GNSSJammingConfig GNSS jamming configuration
---@field ground SBJ__GroundConfig Ground force configuration
---@field recon SBJ__ReconConfig Reconnaissance configuration
---@field air SBJ__AirOperationsConfig Air operations configuration
---@field amphibOps SBJ__AmphibOpsConfig Amphibious operations configuration
---@field surface SBJ__SurfaceOperationsConfig Surface operations configuration
---@field subSurface SBJ__SubsurfaceOperationsConfig Subsurface operations configuration
---@field fireSupportTaskTemplates table<string, SBJ__FireSupportTaskTemplate[]> Fire support task templates
---@field packageTemplates table<string, SBJ__PackageTemplate[]> Air package templates

---Blue side configuration (player defender)
---@class SBJ__BlueConfig: table
---@field gnssJamming SBJ__GNSSJammingConfig GNSS jamming configuration
---@field ground SBJ__GroundConfig Ground force configuration
---@field iads SBJ__IADSFactionConfig IADS configuration
---@field repairRunway SBJ__BlueRunwayRepairConfig Runway repair configuration
---@field air SBJ__AirOperationsConfig Air operations configuration
---@field surface SBJ__SurfaceOperationsConfig Surface operations configuration

---Ally side configuration (supports blue)
---@class SBJ__AllyConfig: table
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

---@class SBJ__SideKey: table

---Global configuration data structure
---@class SBJ__Config: table
---@field version string Version of the game
---@field isEditMode boolean Reset saved state on every load so init reruns; build.sh -p sets false for play
---@field difficulty string Difficulty level
---@field logging SBJ__LoggingConfig Logging configuration
---@field aircraftReadySec number Ready time for aircraft after landing and for package templates (seconds)
---@field red SBJ__RedConfig Red side configuration
---@field blue SBJ__BlueConfig Blue side configuration
---@field ally SBJ__AllyConfig Ally side configuration
---@field score SBJ__ScoringConfig Scoring system configuration
---@field [SBJ__SideKey] SBJ__RedConfig|SBJ__BlueConfig|SBJ__AllyConfig

---GNSS jamming context managing GNSS denial operations state
---@class SBJ__GNSSJammingContext: table
---@field enabled boolean Whether GNSS jamming system is activated
---@field jammers table<string, SBJ__GNSSJammerContext> GNSS jammer contexts indexed by jammer name

---Submarine-launched cruise missile context managing SLCM operations state
---@class SBJ__SLCMContext: table
---@field enabled boolean Whether SLCM system is activated

---Surface operations context managing surface-launched weapons
---@class SBJ__SurfaceOperationsContext: table
---@field lacm SBJ__LACMContext Land-Attack Cruise Missile context

---Subsurface operations context managing submarine-launched weapons
---@class SBJ__SubsurfaceOperationsContext: table
---@field slcm SBJ__SLCMContext Submarine-launched cruise missile context

---Red side saved data structure
---@class SBJ__RedSaveData: table
---@field targetlist SBJ__TargetEntry[] Target list for strike planning
---@field sigint SBJ__SIGINTContext Signals intelligence context
---@field iads SBJ__IADSContext Integrated Air Defense System context
---@field commsJamming SBJ__CommsJammingContext Communications jamming context
---@field gnssJamming SBJ__GNSSJammingContext GNSS jamming context
---@field ground SBJ__StrikingGroundContext Ground force systems context with fire support
---@field recon SBJ__ReconContext Reconnaissance operations context
---@field air SBJ__AirOperationsContext Air operations context
---@field amphibOps SBJ__AmphibOpsContext Amphibious operations context
---@field surface SBJ__SurfaceOperationsContext Surface operations context
---@field subSurface SBJ__SubsurfaceOperationsContext Subsurface operations context
---@field repairRunway SBJ__RunwayRepairmentContext Runway repair context
---@field dynamicOperations SBJ__DynamicOperationsContext Dynamic operations context
---@field deploymentLocked boolean Play-mode control panel deployment already submitted

---Blue side saved data structure
---@class SBJ__BlueSaveData: table
---@field ground SBJ__GroundContext Ground force systems context
---@field repairRunway SBJ__RunwayRepairmentContext Runway repair context
---@field iads SBJ__IADSContext Integrated Air Defense System context (includes ROCC and TAAOC)
---@field air SBJ__AircraftSliceContext Aircraft context
---@field gnssJamming SBJ__GNSSJammingContext GNSS jamming context
---@field deploymentLocked boolean Play-mode control panel deployment already submitted

---Ally side saved data structure
---@class SBJ__AllySaveData: table
---@field sigint SBJ__SIGINTContext Signals intelligence context

---Saved data structure for persistent state
---@class SBJ__SaveData: table
---@field red SBJ__RedSaveData Red side data
---@field blue SBJ__BlueSaveData Blue side data
---@field ally SBJ__AllySaveData Ally side data
---@field [SBJ__SideKey] SBJ__RedSaveData|SBJ__BlueSaveData|SBJ__AllySaveData


-- ============================================================================
-- Faction & Side Configuration
-- ============================================================================
-- Faction configuration related types

---Side configuration for faction settings
---@class SBJ__SideConfig: table
---@field field SBJ__SideKey Side field identifier ("red", "blue" or "ally")
---@field enemySide string Enemy side name


-- ============================================================================
-- Unit Placement & Deployment Utilities
-- ============================================================================
-- Unit placement and deployment parameters for unitGenerator and other modules

---Linear placement parameters for positioning multiple units in a line
---Input table for GameUtils.buildLocations
---@class SBJ__LinearPlacementParams: table
---@field initialLocation CMO__Location Starting position
---@field num number Number of units to place
---@field bearing number Direction angle (degrees)
---@field distance number Distance between units (nautical miles)
---@field firstDistance? number Distance for the first unit; falls back to distance

---Random units descriptor for creating multiple units at random positions
---@class SBJ__RandomUnitsDescriptor: table
---@field centerPoint CMO__Waypoint Center point for random positioning
---@field randomRadiusNm number Maximum radius from center point (nautical miles)
---@field autodetectable boolean Whether units are automatically detectable
---@field unitname string Base name for created units (random suffix will be added if useRandomSuffix is true)
---@field sideName string Side name (e.g., "China", "Taiwan", "US")
---@field unitType string Unit type (e.g., "Facility", "Ship", "Submarine", "Aircraft")
---@field count number Number of units to create
---@field dbids number[] Array of database IDs to randomly select from
---@field useRandomSuffix? boolean Whether to append random text suffix to unit names (default: true)

---Unit descriptor for creating units with specific properties
---@class SBJ__UnitDescriptor: CMO__SetUnitDescriptor
---@field cargo SBJ__CargoDescriptor[] Cargo items to load onto the unit

---Ship formation specification - defines a single ship's configuration within a formation
---Used to specify ship positioning, armament, and embarked units in naval groups
---@class SBJ__ShipFormationDescriptor: table
---@field dbid number Ship platform database ID
---@field unitname string Ship unit name
---@field distance number Distance from formation center (nautical miles)
---@field angle number Angle offset from formation heading (degrees)
---@field embarkedUnits? SBJ__EmbarkedUnit[] Embarked aircraft/boats
---@field loadouts? SBJ__Loadout[] Ammunition stockpile configuration

---Formation configuration for internal ship creation
---Used internally by createShipFormation() to configure ship group formations
---@class SBJ__SAGFormationConfig: table
---@field centerPoint CMO__Location Formation center point coordinates
---@field heading number Formation heading angle
---@field groupName string Ship group name
---@field sideName string Side name (e.g., 'China', 'Taiwan')
---@field shipTypes SBJ__ShipFormationDescriptor[] Array of ship configurations to create

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
---| '"type082"'

-- ============================================================================
-- Cargo & Logistics
-- ============================================================================
-- Cargo and logistics types for amphibiousLogistics module

---Loadout configuration for units
---@class SBJ__Loadout: table
---@field loadoutId number Ammunition configuration ID
---@field name? string Loadout display name
---@field num number Unit count
---@field missionName? string Mission name

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
---@field loadouts? SBJ__Loadout[] Unit ammunition configuration

---Airbase deployment descriptor
---Comprehensive configuration for aircraft deployment and ammunition stockpile at an airbase
---Used for scenario initialization and deployment planning
---@class SBJ__AirbaseDeploymentDescriptor: table
---@field name? string Airbase name
---@field baseGUID? string Airbase unit GUID reference
---@field dbid? number Database ID if the object is a ship
---@field embarkedUnits? SBJ__EmbarkedUnit[] Aircraft units stationed at this base
---@field loadouts? SBJ__Loadout[] Ammunition stockpile in base magazines
---@field latitude? number Airbase latitude coordinate
---@field longitude? number Airbase longitude coordinate

---Per-DBID attrition detail for an airbase
---@class SBJ__AirbaseAttritionEntry: table
---@field dbid number Aircraft DBID
---@field expected integer Planned aircraft count
---@field current integer Current aircraft count
---@field loss integer Attrition count (expected - current)

---Per-airbase attrition summary
---@class SBJ__AirbaseAttritionBaseEntry: table
---@field baseName string Queried base name
---@field baseGUID string|nil Base GUID in deployment descriptor
---@field expectedTotal integer Planned aircraft total
---@field currentTotal integer Current aircraft total
---@field lossTotal integer Attrition total
---@field attritionPct number Attrition percentage (0-100)
---@field isDestroyed boolean Whether the airbase unit has been destroyed (entire wing loses combat capability)
---@field details SBJ__AirbaseAttritionEntry[] DBID-level attrition details

---Aggregated attrition summary for multiple airbases
---@class SBJ__AirbaseAttritionResult: table
---@field queriedBaseNames string[] Queried base names
---@field expectedTotal integer Planned aircraft total across all found bases
---@field currentTotal integer Current aircraft total across all found bases
---@field lossTotal integer Attrition total across all found bases
---@field attritionPct number Aggregated attrition percentage (0-100)
---@field bases SBJ__AirbaseAttritionBaseEntry[] Per-airbase summaries
---@field missingBases string[] Queried base names not found in deployment descriptors

-- ============================================================================
-- Naval Operations
-- ============================================================================
-- Naval operations types for shipMovement and other modules

---Departure point definition with starting coordinates and heading
---@class SBJ__DeparturePoint: table
---@field pos CMO__Location Starting coordinates
---@field heading number Initial heading angle

---Destination area definition with waypoints
---@class SBJ__DestinationArea: table
---@field area? CMO__Location[] Destination area waypoints

---Destination staging area with holding and vehicle staging zones
---Extends destination area with additional staging and holding areas
---@class SBJ__DestinationStagingArea: SBJ__DestinationArea
---@field holdingArea CMO__Waypoint[] Holding area waypoints
---@field amphibiousVehicleStagingArea CMO__Waypoint[] Amphibious vehicle staging area waypoints

---Where a ship group spawns: heading plus a literal position or reference point names per ship type
---@class SBJ__Placement: table
---@field heading number Heading at spawn (degrees)
---@field pos? CMO__Location Literal coordinate (SAG, CSG, submarines)
---@field startingPoints? SBJ__StartingPoints Reference points per ship type (amphibious fleet)

---Reference point names of the first ship of each row (type071 used at destination only)
---@class SBJ__StartingPoints: table
---@field type075 string[]
---@field type071? string[]

---Ship group that spawns at `from` and sails to `to`; shared by fleet groups and SAGs
---@class SBJ__ShipGroup: table
---@field from SBJ__Placement Spawn placement
---@field to? table Destination, shape depends on the group kind

---Submarine descriptor for SLCM operations
---@class SBJ__SubmarineDescriptor: table
---@field name string Submarine name/identifier
---@field course CMO__Waypoint[] Submarine patrol route waypoints
---@field from SBJ__DeparturePoint Starting location with heading
---@field weaponDBID number Weapon database ID for SLCM

---Surface Action Group descriptor
---@class SBJ__SAGDescriptor: SBJ__ShipGroup
---@field groupName string Group name
---@field from SBJ__DeparturePoint Starting location
---@field to? SBJ__DestinationStagingArea Destination staging area; arrival heading is the zone heading
---@field unitMap table<string, SBJ__AirbaseDeploymentDescriptor> Unit list indexed by unit name
---@field area? string[] Operational area reference points
---@field missionName? string Mission name

---Carrier Strike Group descriptor
---@class SBJ__CSGDescriptor: table
---@field groupName string Group name
---@field from SBJ__DeparturePoint Starting location
---@field to SBJ__DestinationArea Destination area
---@field unitMap table<string, SBJ__AirbaseDeploymentDescriptor> Unit list indexed by unit name


-- ============================================================================
-- Amphibious Operations
-- ============================================================================
-- Amphibious operations types for amphibiousAssault and landingOps modules

---Barge context for tracking barge operations and associated units
---@class SBJ__BargeContext: table
---@field guid string Barge unit GUID
---@field bridgeGUID? string Bridge unit GUID for barge connection
---@field roros string[] Array of RORO ship GUIDs transported by this barge

---Ship position calculation result for amphibious operation planning
---@class SBJ__ShipCalculationState: table
---@field locations CMO__Location[] Calculated positions for ship formation
---@field locationIndex number Current position index in the locations array
---@field dbid number Platform database ID for this ship type

---Operation zone calculation result containing all ship type positions
---Stores calculated ship formation positions for each ship type in the operation zone
---@class SBJ__OperationZoneCalculationState: table
---@field name string Operation zone name (e.g., "Taoyuan", "Penghu", "Sishu")
---@field result table<string, SBJ__ShipCalculationState> Ship type calculation results indexed by ship type name (type075, type071, type076, type072iii, type072a, type073a, type071OnDeployLine, ferry, roro, barge)

---Inputs for laying out every ship row of one fleet group
---@class SBJ__BuildAllShipLocationsParams
---@field startingPointMap table<string, CMO__Location>
---@field shipCounts SBJ__FleetCompositionConfig
---@field heading number Zone heading; ships of one type line up perpendicular to it
---@field formationSettings SBJ__AmphibiousFormationConfig

---Per-zone state for amphibious operation phase tracking
---@class SBJ__ZoneState: table
---@field phase string Current phase (constants.AMPHIBIOUS_PHASES value)
---@field amphibiousAssaultStartTime? number Amphibious assault start timestamp
---@field airlandingMissionStartTime? number Air landing mission start timestamp
---@field lanes? SBJ__LanePlanState Water and beach lanes, built when mine clearing starts
---@field minesweepers? table<string, SBJ__MinesweeperState> Type 529 progress indexed by GUID
---@field boats? table<string, SBJ__AssaultBoatState> Assault boat pairing and progress indexed by boat GUID
---@field obstacle? SBJ__ObstacleState Beach obstacle cells
---@field obstacleStartedAt? number Time all boats finished and obstacle clearing began
---@field acvGuids? table<string, string[]> Launched ACV GUIDs per type key (zbd05, ztd05)
---@field acvPausedAt? table<string, number> Pause start per ACV type key; nil while releasing
---@field acvFirstWaveFull? boolean Latched once the first ACV wave is full or the wait timed out; hovercraft wait for it
---@field acvWaitStartedAt? number Time hovercraft first started waiting for the first ACV wave
---@field queueCounters? table<string, integer> Units routed per water lane id
---@field laneSlots? SBJ__LaneSlotsState Parking slot holders per beach lane
---@field hovercraft? table<string, SBJ__HovercraftState> Routed hovercraft indexed by GUID

---Local flat frame for lane geometry
---@class SBJ__LaneFrame: table
---@field origin CMO__Location Lane center on the shore
---@field bearing number Bearing toward the shore (degrees)

---All lanes of a zone
---@class SBJ__LanePlanState: SBJ__LaneFrame
---@field waterLanes SBJ__WaterLaneEntry[] Water lanes ordered left to right (facing the shore)

---One water lane (one Type 529 / one battalion)
---@class SBJ__WaterLaneEntry: table
---@field id string Water lane id ("W1")
---@field deployPoint CMO__Location Point on the deployment line
---@field launchPoint CMO__Location L_i, point on the launch line
---@field assaultPoint CMO__Location A_i, point on the assault line
---@field beachLanes SBJ__BeachLaneEntry[] Beach lanes ordered left to right
---@field sweepCourse CMO__Waypoint[] Type 082 course: water lane then serpentine over beach lanes
---@field missionArea CMO__Location[] Sweep mission rectangle (4 corners)

---One beach lane
---@class SBJ__BeachLaneEntry: table
---@field id string Beach lane id ("W1-B2")
---@field waterLaneId string Parent water lane id
---@field assaultPoint CMO__Location A_lane, start on the assault line
---@field shorePoint CMO__Location S_lane, just off the shore
---@field endPoint CMO__Location E_lane, inland past the obstacle area
---@field isCleared boolean Whether obstacles on this lane are cleared

---@class SBJ__BuildLanesParams: table
---@field origin CMO__Location Lane center on the shore
---@field bearing number Bearing toward the shore (degrees)
---@field count integer Number of water lanes (Type 529 count)
---@field inlandDepthM number E_lane distance inland
---@field areaMarginM number Sweep mission area margin
---@field routeConfig SBJ__RouteConfig

---One obstacle cell
---@class SBJ__ObstacleCellEntry: table
---@field corners CMO__Location[] 4 corners
---@field state string constants.OBSTACLE_CELL_STATES value
---@field beachLaneId? string Beach lane that cleared this cell

---@class SBJ__ObstacleState: table
---@field cells SBJ__ObstacleCellEntry[]

---@class SBJ__LaneSlotsState: table
---@field acv table<string, table<integer, string>> ACV slot holders per beach lane id
---@field hovercraft table<string, table<integer, string>> Hovercraft slot holders per beach lane id

---@class SBJ__BuildRouteParams: table
---@field lanes SBJ__LanePlanState
---@field launchPos CMO__Location Where the unit starts
---@field guid string Unit taking the slot
---@field routeConfig SBJ__RouteConfig
---@field queueCounters table<string, integer> Also used as water lane load
---@field laneSlots table<string, table<integer, string>> Slot holders for this unit kind
---@field cells SBJ__ObstacleCellEntry[]|nil
---@field isAlive fun(guid: string): boolean

---@class SBJ__BuildRouteOpts: table
---@field isFromDeployLine? boolean Prepend the water lane's deployment line point (units launched far offshore)

---@class SBJ__RoutePlanResult: table
---@field course CMO__Location[]
---@field waterLaneId string
---@field beachLaneId string
---@field slot integer

---@class SBJ__MinesweeperState: table
---@field waterLaneId string
---@field missionArea CMO__Location[] Sweep mission rectangle (4 corners), for the mine clearing mission
---@field finalPoint CMO__Location Last waypoint of the sweep course
---@field isDone boolean Reached the final point (and sent RTB) or was destroyed

---@class SBJ__AssaultBoatState: table
---@field shipGuid string Carrying LST
---@field beachLaneId string Paired beach lane
---@field status string "pending" | "launched" | "arrived" | "lost"
---@field finalPoint? CMO__Location S_lane, set at launch

---@class SBJ__HovercraftState: table
---@field missionName string Cargo mission to assign after arrival
---@field finalPoint CMO__Location Parking slot
---@field arrived boolean

---Amphibious operations context managing all amphibious operation state
---@class SBJ__AmphibOpsContext: table
---@field zoneStates table<string, SBJ__ZoneState> Per-zone state indexed by zone name
---@field calculationResult table<string, SBJ__OperationZoneCalculationState> Operation zone calculation results indexed by zone name
---@field barges table<string, SBJ__BargeContext> Barge contexts indexed by barge GUID
---@field fireSupportOnHold? boolean Whether SRBM fire-support strikes are on hold for ammo conservation; set true when ammo low and not all zones arrived, cleared once all zones reach staging

---ACV deployment parameters for launching amphibious combat vehicles
---Input table for AmphibiousAssault.launchACV
---@class SBJ__ACVDeploymentParams: table
---@field bearing number Deployment direction (degrees)
---@field distance number Deployment distance (nautical miles)
---@field ship CMO__Unit Parent landing ship
---@field num integer Maximum number of ACVs to deploy
---@field quota table<string, integer> Remaining quota per ACV type key (zbd05, ztd05)
---@field routeACV fun(unit: CMO__Unit, acvKey: string): CMO__Waypoint[] Course for a freshly spawned ACV

---@class SBJ__LaunchACVResult: table
---@field count integer|nil ACVs launched, nil when a spawn failed
---@field isEmpty boolean Ship carries no ZBD/ZTD cargo
---@field isPaused boolean Cargo remains but the wave quota allows none of it

---Vehicle offload parameters for unloading vehicles from landing ships
---Input table for AdminUnloading.offloadVehicles
---@class SBJ__VehicleOffloadParams: table
---@field ship CMO__Unit Landing ship to offload from
---@field num integer Number of vehicles to offload
---@field bearing number Offload direction (degrees)
---@field distance number Distance between vehicles (nautical miles)
---@field firstDistance? number Distance for first vehicle (nautical miles); falls back to distance

---Landing mission descriptor for amphibious operations
---@class SBJ__LandingMissionDescriptor: table
---@field name string Mission name
---@field loadoutId number Loadout configuration ID
---@field unitCount integer Number of units
---@field startTime number Mission start time

---Air Cushion Vehicle deployment configuration
---@class SBJ__ACVDescriptor: table
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
---@class SBJ__HovercraftMissionDescriptor: SBJ__CargoLandingPlatformDescriptor
---@field speed number

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
---@field distance number Approach distance along the zone heading (nautical miles)

---@class SBJ__SweeperDescriptor: table
---@field missionName string
---@field settings CMO__Mission
---@field speed number

---Operational zone descriptor for amphibious operations
---Defines one landing zone: its fleet and SAGs, plus holding areas, air and landing setup
---@class SBJ__OperationalZoneDescriptor: table
---@field name string Operational zone name (e.g., "Taoyuan", "Sishu", "Penghu")
---@field heading number Approach bearing toward the shore (degrees); lane, LST, ACV and SAG bearings derive from it
---@field fleet SBJ__FleetDescriptor Ship groups leaving for and holding in this zone
---@field sags SBJ__SAGDescriptor[] Surface Action Groups assigned to this zone
---@field movement SBJ__ZoneMovement Home base, holding areas and arrival check
---@field air SBJ__ZoneAir Air landing and air support
---@field landing SBJ__ZoneLanding Landing craft, vehicles and beach setup

---Fleet movement setup of a zone: home base, where the fleet waits, when it counts as arrived
---@class SBJ__ZoneMovement: table
---@field baseGUID string Home base GUID for embarked units
---@field arrivalThreshold integer Minimum unit count to consider fleet arrived
---@field holdingAreas SBJ__ZoneHoldingAreas Where the fleet waits before the assault

---Waiting areas of a zone's fleet (docs/landingOps/assaultTimeline.md)
---@class SBJ__ZoneHoldingAreas: table
---@field mothership string[] Mothership area (登陸母艦乘載區): Type 075/076/071 reference points
---@field deployLine string[] Deploy line (登陸艦艇展開線): other landing ships' reference points

---Air landing and air support of a zone
---@class SBJ__ZoneAir: table
---@field landingZone string[] Air landing zone reference area
---@field contactThreshold integer Contact threshold for amphibious assault in air landing zone
---@field casArea string[] CAS area reference points
---@field transportHelicopter SBJ__TransportHelicopterDescriptor Transport helicopter configuration
---@field attackHelicopter SBJ__AttackHelicopterDescriptor Attack helicopter configuration

---Landing craft, vehicles and beach setup of a zone
---@class SBJ__ZoneLanding: table
---@field hovercraft SBJ__HovercraftMissionDescriptor Landing craft configuration
---@field lstSettings SBJ__LSTMovementDescriptor LST movement configuration
---@field acv SBJ__ACVDescriptor Amphibious combat vehicle configuration
---@field laneCenter string[] Reference point name of the lane center on the shore (one point)
---@field obstacleArea string[] Beach obstacle polygon reference point names (BLUE side)
---@field offloadArea string[] Vehicle offload area reference points
---@field sweeper SBJ__SweeperDescriptor

---Formation settings for amphibious operation layouts
---Defines spacing and movement parameters for amphibious assault ship formations
---Used internally for calculating ship positions during landing operations
---@class SBJ__AmphibiousFormationConfig: table
---@field deployLineSetback number Distance from the mothership area to the deploy line
---@field horizontalDistance number Horizontal spacing between ships in formation
---@field verticalDistance number Vertical spacing between ships in formation
---@field transitDistance number Distance for transit phase
---@field shipSpeed number Ship movement speed
---@field acvSpeed number Amphibious combat vehicle speed
---@field acvTransitDistance number Amphibious combat vehicle transit distance
---@field acvHorizontalDistance number Amphibious combat vehicle horizontal spacing
---@field hovercraftSpeed number
---@field sweeperSpeed number
---@field rowBearingOffset number Degrees between the zone heading and the direction ships of one type line up along

---Fleet composition configuration for amphibious operations
---Defines the number of ships by type for amphibious assault fleets
---@class SBJ__FleetCompositionConfig: table
---@field type075 integer Number of Type 075 amphibious assault ships
---@field type071 integer Number of Type 071 amphibious transport docks
---@field type076 integer Number of Type 076 amphibious assault ships
---@field type072iii integer Number of Type 072III landing ships
---@field type072a integer Number of Type 072A landing ships
---@field type073a integer Number of Type 073A landing craft
---@field type071OnDeployLine? integer Number of Type 071 ships on the deploy line
---@field ferry integer Number of ferries
---@field roro integer Number of roll-on/roll-off ships
---@field barge integer Number of barges
---@field type082 integer

---Fleet group destination: reference points where each ship row holds
---@class SBJ__FleetDestination: table
---@field startingPoints SBJ__StartingPoints Holding area reference points

---One fleet group: ships spawn at `from`, sail to `to`, composition in `shipCounts`
---Several groups may land in the same zone
---@class SBJ__FleetGroup: SBJ__ShipGroup
---@field from SBJ__Placement Spawn placement
---@field to SBJ__FleetDestination Holding placement
---@field shipCounts SBJ__FleetCompositionConfig Ship quantity configuration

---Amphibious fleet descriptor
---Unit naming and ship groups of one zone
---Used for scenario initialization and deployment planning
---@class SBJ__FleetDescriptor: table
---@field names string[] Unit name array
---@field stagingArea string[] Staging area reference points; ships inside belong to this zone
---@field groups SBJ__FleetGroup[] Ship groups

---Live-test shortcuts for the amphibious flow
---@class SBJ__AmphibDebugConfig: table
---@field enabled boolean Master switch; false disables every shortcut
---@field startStage? string Phase to start testing at (constants.AMPHIBIOUS_PHASES); earlier phases are fast-forwarded. nil fast-forwards all phases
---@field teleportLanding boolean Hovercraft and ACVs teleport to their parking slot instead of sailing

---Amphibious Operations system configuration
---Comprehensive configuration for amphibious assault operations including
---cargo manifests, ship layouts, operational zones, and mission timing
---@class SBJ__AmphibOpsConfig: table
---@field periodSec number Check interval in seconds
---@field fireSupportHoldThreshold number SRBM total-ammo % below which recon-driven SRBM strikes (STRIKE/INFRA/*) are held until all zones reach staging waters
---@field cargo table<string, SBJ__CargoDescriptor[]> Cargo manifest by ship type
---@field transferCargo table<string, SBJ__CargoDescriptor[]> Transfer cargo groups
---@field missionStartTime table<string, number[]> Mission start times by type (seconds)
---@field formationSettings SBJ__AmphibiousFormationConfig Ship formation layout configuration
---@field zones SBJ__OperationalZoneDescriptor[] Operation zone descriptors (fleet, SAGs and landing setup per zone)
---@field transportAircraft SBJ__TransportAircraftDescriptor[] Transport aircraft configuration
---@field debug SBJ__AmphibDebugConfig Live-test shortcuts
---@field tuning SBJ__AmphibTuningConfig Shared lane, boat, obstacle and ACV wave parameters
---@field minefields SBJ__MinefieldDescriptor[] Offshore minefields laid at scenario start

---Shared parameters used by every zone of the amphibious operations
---@class SBJ__AmphibTuningConfig: table
---@field route SBJ__RouteConfig Lane layout and routing through swept lanes
---@field mineClearing SBJ__MineClearingConfig Type 529 mine clearing settings
---@field assaultBoat SBJ__AssaultBoatConfig Assault boat settings
---@field obstacle SBJ__ObstacleConfig Beach obstacle settings
---@field acvWave SBJ__AcvWaveConfig ACV wave limits

---Lane layout and routing settings (distances measured from the lane center on the shore)
---@class SBJ__RouteConfig: table
---@field deployLineNm number Deployment line distance offshore (water lane start)
---@field launchLineNm number Launch line distance offshore (L_i)
---@field assaultLineNm number Assault line distance offshore (A_i, A_lane)
---@field launchStationNearNm number Inner edge of the LST station band, distance offshore
---@field launchStationFarNm number Outer edge of the LST station band, distance offshore
---@field waterLaneSpacingM number Spacing between adjacent water lanes
---@field beachLaneOffsetsM number[] Beach lane lateral offsets from their water lane, ascending
---@field shoreStandoffM number S_lane distance offshore
---@field inlandMarginM number How far E_lane extends past the obstacle area
---@field columnSpacingM number Spacing between queue entry points along the water lane
---@field queueDepth integer Number of queue entry points per water lane
---@field queueSpacingM number Spacing between parking slots inside a beach lane
---@field laneTieNm number Distance difference treated as a tie when choosing a water lane
---@field arrivalNm number Distance to the final waypoint that counts as arrived

---@class SBJ__MineClearingConfig: table
---@field areaMarginM number Extra width of the sweep mission area beyond the outermost beach lane

---Offshore minefield laid for BLUE at scenario start
---@class SBJ__MinefieldDescriptor: table
---@field area string[] BLUE-side reference point names; empty skips this minefield
---@field number integer Number of mines
---@field delay number CMO arming delay

---@class SBJ__AssaultBoatConfig: table
---@field speed number Manual speed (knots)

---@class SBJ__ObstacleConfig: table
---@field cellSizeM number Obstacle cell edge length
---@field clearSec number Seconds after all boats land before obstacles are cleared

---@class SBJ__AcvWaveConfig: table
---@field capacity table<string, integer> Alive ACV cap per type key (zbd05, ztd05)
---@field lossRatio number Resume when alive drops below capacity * (1 - lossRatio)
---@field holdSec number Resume when paused longer than this
---@field hovercraftWaitSec number Hovercraft stop waiting for the first ACV wave after this many seconds

---Land-Attack Cruise Missile context managing LACM operations state
---@class SBJ__LACMContext: table
---@field enabled boolean Sticky flag set true once the CSG reaches its station; never cleared, so it reads as "the LACM element is committed" rather than "the salvo is pending"
---@field hasLaunched boolean Whether the salvo has already been fired

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
---@field opts CMO__MissionOpts The options for the mission

---Tanker mission creation parameters
---Supports one mission or multiple independently configured tanker missions
---@alias SBJ__TankerMissionCreationParams SBJ__MissionCreationParams|SBJ__MissionCreationParams[]

---Mission deployment descriptor for air operations
---Complete mission deployment configuration including base, units, weapons, and timing
---@class SBJ__MissionDeploymentDescriptor: table
---@field baseGUID string The GUID of the base to use for the mission (resolved after validation)
---@field baseGUIDCandidates? string[] Fallback bases tried in order when the primary base lacks aircraft of unitDBID; validator narrows to a single resolved baseGUID before persisting
---@field missionCreationParams SBJ__MissionCreationParams The parameters for the mission
---@field unitCount integer The number of units to assign to the mission
---@field weaponDBID number The weapon DBID to use for the mission
---@field unitDBID number The unit DBID to use for the mission
---@field loadoutID? number The loadout ID to filter by, 0 for any loadout
---@field startTime? string The start time of the mission
---@field endTime? string The end time of the mission
---@field timeOnStation? string The time on station
---@field emcon string The EMCON settings for the mission

---Calculated timestamps for one air package role
---@class SBJ__RoleTiming: table
---@field startTime number Conservative planned takeoff timestamp
---@field timeOnStation? number CMO time-on-station timestamp
---@field endTime number Mission end timestamp

---Tanker deployment descriptor supporting multiple tanker missions
---@class SBJ__TankerMissionDeploymentDescriptor: SBJ__MissionDeploymentDescriptor
---@field missionCreationParams SBJ__TankerMissionCreationParams The tanker mission parameters

---Air operations context managing air tasking orders and aircraft status
---@class SBJ__AirOperationsContext: table
---@field enabled boolean Whether air operations system is activated
---@field airTaskingOrder table<string, SBJ__Wave> Air Tasking Order waves indexed by wave name


-- ============================================================================
-- Launcher & TEL Systems
-- ============================================================================
-- Launcher and Transporter-Erector-Launcher (TEL) systems for launcher module

---Area creation parameters for GameUtils.createArea
---@class SBJ__AreaParams: table
---@field side string Side name
---@field shape string Area shape ("circle" or "square")
---@field distance number Distance from center to each vertex (nautical miles)
---@field name? string Area name (default: "RP")
---@field bearOffset? number Bearing offset in degrees for square areas (default: 0)

---Position definition with course and area reference points
---@class SBJ__Position: table
---@field course CMO__Waypoint[] Waypoints to area
---@field area string[] Area reference points, e.g., {"rp-100","rp-101","rp-102","rp-103","rp-104"}

---@class SBJ__PositionType: table

---Operational area definition with multiple tactical position types
---Defines fire positions, hide areas, and reload locations for TEL operations
---@class SBJ__OperationalArea: table
---@field FP SBJ__Position[] Fire Points
---@field HA SBJ__Position[] Hide Areas
---@field AHA SBJ__Position[] Ammo Holding Areas
---@field RL SBJ__Position[] Reload Points
---@field mask {area: string[]} Mask area reference points
---@field name? string Area name
---@field uShapeVertices? CMO__Location[] U shape vertices
---@field shelterPoints? CMO__Location[] Shelter points
---@field SHRL? SBJ__Position[] Shelter-hide-reload loop path
---@field [SBJ__PositionType] SBJ__Position[]

---Player-chosen operational area for one battery, applied by MissileSystem.redeploy
---@class SBJ__MissileSystemLayout: table
---@field missileSystemType string Missile system type key (constants.MISSILE_SYSTEM_TYPES)
---@field unitname string Firing unit name in the side's ground force config
---@field operationalArea SBJ__OperationalArea New operational area for the firing unit and its resupply unit

---One battery's status in the control panel (a firing unit plus its paired resupply unit), built by MissileSystem.buildBatteryStatuses
---@class SBJ__BatteryStatus: table
---@field name string Firing unit name
---@field missileSystemType string Missile system type key (constants.MISSILE_SYSTEM_TYPES)
---@field firingUnitState string Firing unit state label
---@field resupplyUnitState string Paired resupply unit state label
---@field missilesInAmmoVehicles number Missiles carried by the resupply unit
---@field missilesInTransloaderDefault number
---@field missilesInAHA number Missiles left in the paired ammo holding area
---@field missilesInAHADefault number
---@field firingUnitReloadTime number Minutes elapsed in the firing unit's reload, 0 when not reloading
---@field resupplyUnitReloadTime number Minutes elapsed in the resupply unit's reload, 0 when not reloading
---@field defaultReloadTime number Configured reload time in minutes

---Weapon status tracking for ammunition count
---@class SBJ__WeaponStatus: table
---@field weaponCountCurrent number Current available ammunition count
---@field weaponCountDefault number Default/maximum ammunition count

---Base unit information with GUID and name
---@class SBJ__UnitBase: table
---@field guid? string Unit GUID (runtime only, absent in config)
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
---@field missileSystem string Missile system designation (e.g. "HF-3")
---@field mountDescriptors? {dbid:number, mountCount:integer}[] Mount DBIDs and counts on the firing unit

---@class SBJ__FiringUnitWithWeaponRangeDescriptor: SBJ__FiringUnitDescriptor
---@field weaponRange number

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
---@field firingUnits table<string, SBJ__FiringUnitContext> Firing units indexed by GUID for attack operations
---@field resupplyUnits table<string, SBJ__ResupplyUnitContext> Resupply units indexed by GUID for ammunition replenishment
---@field ammunitions table<string, SBJ__AmmunitionContext> Ammunition units indexed by GUID for tracking available munitions
---@field test? table Test data structure

---Ammunition subtotal with current/max counts and usage percentage
---@class SBJ__AmmoSubtotalEntry: table
---@field current number Current ammunition count
---@field max number Maximum ammunition count
---@field percentage integer Usage percentage (current/max * 100), rounded to nearest integer; 0 when max is 0

---Ammunition inventory report aggregating firing/resupply/ammo subtotals and overall total
---@class SBJ__AmmoInventoryResult: table
---@field firing SBJ__AmmoSubtotalEntry Firing units total (queried from live game state)
---@field resupply SBJ__AmmoSubtotalEntry Resupply units total (sum of context weaponCountCurrent/weaponCountDefault)
---@field ammo SBJ__AmmoSubtotalEntry Ammunition depots total (sum of context weaponCountCurrent/weaponCountDefault)
---@field total SBJ__AmmoSubtotalEntry Combined total across firing + resupply + ammo

---Ground context base - common missile systems for all ground operations
---@class SBJ__GroundContext: table
---@field enabled boolean Whether ground force systems are activated
---@field missileSystemTypes table<string, SBJ__MissileSystemContext> Missile system runtime state by type

---Ground context with fire support - for strike operations (China/Taiwan)
---Extends base context with dynamic fire support execution matrices
---@class SBJ__StrikingGroundContext: SBJ__GroundContext
---@field fireSupportPlan table<string, SBJ__FireSupportExecutionMatrix> Fire Support Plan execution matrices (always initialized)

---Optional unit property overrides for ground units
---Passing nil applies every default
---@class SBJ__SetUnitPropertiesOpts: table
---@field throttle? string Throttle setting (default: 'Stop')
---@field speed? number Speed (default: 0)
---@field course? CMO__Waypoint[] Waypoints
---@field holdPosition? boolean Whether to hold position (default: true)
---@field wcs? integer Weapon control status: 1=Free, 2=Hold
---@field formation? CMO__FormationGroup Formation settings

---Required input for GameUtils.setUnitEntersAreaEvent
---@class SBJ__UnitEntersAreaEventParams: table
---@field name string Event name (must be unique within the scenario)
---@field mode string Operation mode: 'add', 'update' or 'remove'
---@field filter? table Unit filter criteria (e.g. side name, unit type)
---@field area? table Reference point area defining the trigger zone
---@field script? string Lua script executed when the event triggers

---Optional settings for GameUtils.setUnitEntersAreaEvent
---Passing nil applies every default
---@class SBJ__UnitEntersAreaEventOpts: table
---@field exit? boolean Trigger on EXIT instead of ENTER (default: false)
---@field isRepeatable? boolean Whether the event can trigger more than once (default: false)
---@field isActive? boolean Whether the event is active immediately (default: true)

---Required input for GameUtils.tryAddUnit
---@class SBJ__TryAddUnitParams: table
---@field name string Unique name for the unit to be created
---@field pos CMO__Location Center point for unit placement
---@field randomRadiusNm number Maximum distance in nautical miles from the center point
---@field unitDBID integer CMO platform DBID of the unit type to create

---Optional settings for GameUtils.tryAddUnit
---Passing nil applies every default
---@class SBJ__TryAddUnitOpts: table
---@field maxAttempts? integer Maximum placement attempts before giving up (default: 50)

---Required input for AssignMission.assignEmbarkedUnitToStrikeMission
---@class SBJ__AssignEmbarkedUnitParams: table
---@field baseGUID string GUID of the unit carrying the embarked aircraft
---@field unitCount integer Number of units to assign to the mission
---@field weaponDBID number Weapon DBID to filter by, or 0 for any weapon
---@field unitDBID? number Unit DBID to filter by, or nil for any unit
---@field missionName string Name of the mission to assign units to

---Optional settings for AssignMission.assignEmbarkedUnitToStrikeMission
---Passing nil applies every default
---@class SBJ__AssignEmbarkedUnitOpts: table
---@field isEscort? boolean Whether the mission is an escort mission (default: false)

---Optional settings for GameUtils.createMission
---Passing nil applies every default
---@class SBJ__CreateMissionOpts: table
---@field emcon? string EMCON settings string applied to the mission

---Required input for TargetingProcess.processTargets
---@class SBJ__ProcessTargetsParams: table
---@field contacts CMO__Contact[] Available sensor contacts
---@field targetConfig? SBJ__TargetTemplate Target configuration (from taskTemplate.target or packageData.target)

---Optional settings for TargetingProcess.processTargets
---Passing nil applies every default
---@class SBJ__ProcessTargetsOpts: table
---@field isFirstWave? boolean Whether this is the first wave (default: false)

---Required input for DynamicPlan.evaluateTargets
---@class SBJ__EvaluateTargetsParams: table
---@field contacts CMO__Contact[] Available sensor contacts from the game
---@field operationType SBJ__OperationType Operation type the template belongs to
---@field template SBJ__WaveTemplate|SBJ__FireSupportExecutionMatrixTemplate Template whose entries are evaluated

---Required input for DynamicPlan.add
---@class SBJ__InsertPlanParams: table
---@field operationType SBJ__OperationType Operation type deciding which plan table and registry are used
---@field templateName string Full operation template name, wave-stage number included
---@field reconType string Reconnaissance source that triggered the operation
---@field buildPlan fun(planName: string): table Builds the plan entry for the generated name

---Movement parameters for commanding units to a randomly selected position
---@class SBJ__MoveToPositionParams: table
---@field unitName string Unit name (for messages)
---@field firingUnit CMO__Unit Unit group
---@field positions SBJ__Position[] Position array
---@field positionType string Position type (RL/HA/AHA/FP)
---@field areaName string Operational area name (for messages)
---@field wcs? integer Weapon control status
---@field useLastCourse? boolean Whether to use the last waypoint in course

---Per-run mode shared by every unit handled in one missileSystem run
---@class SBJ__MissileRunContext: table
---@field isAuto boolean Whether the run is automatic (computer-controlled side)

---Per-run settings shared by every unit in one missileSystem reload cycle
---@class SBJ__CycleRunContext: SBJ__MissileRunContext
---@field systemConfig SBJ__MissileSystemConfig Missile system configuration (reload/stow timers)

---Side-specific switches shared by every system in one UnitEntersArea event
---@class SBJ__MoveToPositionContext: SBJ__MissileRunContext
---@field hideOnEnterHA boolean Whether entering HA should force hide flow
---@field hideResupplyOnRLNoMeeting boolean Whether RL no-meeting fallback may hide resupply unit
---@field firingUnitLookupSide string Side name used to resolve paired firing unit

---Input parameters for missileSystem UnitEntersArea event handling
---@class SBJ__MoveToPositionEventParams: table
---@field groundCtx table<string, SBJ__MissileSystemContext> Missile system runtime contexts by type
---@field unit CMO__Unit Unit that triggered UnitEntersArea
---@field event CMO__Event Event payload from CMO
---@field contacts? CMO__Contact[] Current side contacts used for drop-contact handling
---@field moveCtx SBJ__MoveToPositionContext Side-specific switches for this event

---Parameters for adding a unit-enters-area trigger to an event
---@class SBJ__AddTriggerParams: table
---@field positionType string Position type (RL/HA/FP)
---@field position SBJ__Position Position configuration
---@field index integer Position index within operational area
---@field operationalArea SBJ__OperationalArea Operational area configuration
---@field enemySide string Enemy side name for target filter
---@field sideName string Owner side name

---Structured result from missile-system supply asset destruction handling
---@class SBJ__SupplyAssetDestructionResult: table
---@field tag string Result tag (e.g. "OK")
---@field system string Missile system name
---@field unitName string Destroyed unit name
---@field contextName string Context unit name whose ammunition changed
---@field role string Supply asset role
---@field ammoBefore number Ammunition count before adjustment
---@field ammoAfter number Ammunition count after adjustment
---@field delta number Ammunition delta applied


-- ============================================================================
-- Air Operations Validation
-- ============================================================================
-- Aircraft validation context for air package processing

---Aircraft validation context for package processing
---Encapsulates aircraft reservations, available aircraft cache, and strength threshold
---@class SBJ__AircraftValidationContext: table
---@field reservedAircraft table<string, integer> Map of reservation key to reserved aircraft count; mutated on success
---@field freeAircraftCache table<string, table<number, integer>> Pass-scoped free aircraft cache keyed by base GUID, with per-DBID counts; mutated
---@field strikeInterval number Default interval between strike packages of an air operation (seconds)
---@field minimumStrengthRatio number Fraction of the requested aircraft a base must supply to be accepted (0-1)


-- ============================================================================
-- Strike Planning & Targeting
-- ============================================================================
-- Strike planning and targeting types for strikePlanner module

---Airfield pattern configuration for target matching
---@class SBJ__AirfieldPatternConfig: table
---@field runwayPattern string Lua pattern for runway matching (e.g., "Runway %(%d+m%)")
---@field taxiwayPattern string Lua pattern for taxiway matching
---@field shelterPattern string Lua pattern for aircraft shelter matching
---@field hangarPattern string Lua pattern for hangar matching
---@field tarmacPattern string Lua pattern for tarmac matching
---@field helipadPattern string Lua pattern for helipad matching
---@field ammoBunkerPattern string Lua pattern for ammunition bunker matching
---@field ammoRevetmentPattern string Lua pattern for ammunition revetment matching

---Port pattern configuration for target matching
---@class SBJ__PortPatternConfig: table
---@field pierPattern string Lua pattern for pier matching

---Radar pattern configuration for target matching
---@class SBJ__RadarPatternConfig: table
---@field radarPattern string Lua pattern for radar facility matching

---SAM pattern configuration for target matching
---@class SBJ__SAMPatternConfig: table
---@field skyBowPattern string Lua pattern for Sky Bow SAM system matching

---ASM pattern configuration for target matching
---@class SBJ__ASMPatternConfig: table
---@field asmPattern string Lua pattern for anti-ship missile system matching

---C2 pattern configuration for target matching
---@class SBJ__C2Patterns: table
---@field hengshanPattern string Lua pattern for Hengshan command center matching

---Target category patterns configuration
---@class SBJ__TargetCategoryPatternConfig: table
---@field airfield SBJ__AirfieldPatternConfig Airfield-related patterns
---@field port SBJ__PortPatternConfig Port-related patterns
---@field radar SBJ__RadarPatternConfig Radar facility patterns
---@field sam SBJ__SAMPatternConfig SAM system patterns
---@field asm SBJ__ASMPatternConfig ASM system patterns
---@field c2 SBJ__C2Patterns Command and control patterns

---Target scanning configuration for contact categorization
---@class SBJ__TargetScanningConfig: table
---@field distanceThreshold number Maximum distance threshold in nautical miles for base/port proximity matching
---@field blueAirBases string[] Array of Taiwan airbase names to scan for
---@field bluePorts string[] Array of Taiwan port names to scan for
---@field targetCategories SBJ__TargetCategoryPatternConfig Pattern configurations for each target category

---Target entry representing a scanned and categorized target
---@class SBJ__TargetEntry: table
---@field name string Target display name (format: "BaseName/Description" for base-related targets, or just "Description" for standalone targets)
---@field guid string Target contact GUID
---@field category string Target category ("Airfield", "Port", "ISR", "SAM", "ASM", "C2")
---@field subType string Target sub-type description (e.g., "Runway (3000m)", "Shelter", "Pier", "Radar")

---Target query parameter for filtering targets by base name and facility sub-types
---@class SBJ__TargetQueryEntry: table
---@field baseName? string Base name pattern for matching; omit to match all
---@field subTypes string[] Array of facility sub-type patterns to match

---Target template for strike planning
---@class SBJ__TargetTemplate: table
---@field objs? SBJ__TargetQueryEntry[] Target query entries (for fixed targets)
---@field areas? string[][] Operation areas
---@field filterNames? string[] Filter function names (for dynamic targets)
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
---Built once per pass by buildFilterParams and shared by every filter function
---@class SBJ__FilterParams: table
---@field config? SBJ__Config Configuration data
---@field transmissions? table<string, SBJ__RadioTransmissionContext> SIGINT transmissions read by findRadioDirection
---@field task SBJ__Task Task information
---@field contacts CMO__Contact[] Contact array

---Recon tracking a target filter asks for; produced by TargetingProcess, served by Recon.trackTargets
---@class SBJ__TrackingRequestEntry: table
---@field platformDBID number UAV platform database ID to send
---@field target CMO__Contact Resolved target contact to shadow

---Firing unit definition for fire support operations
---Invariant: name is always present. FsemBuilder rejects an entry whose name does not
---resolve to a runtime context, so downstream code indexes name without a nil guard.
---@class SBJ__FiringUnit: table
---@field name string Firing unit name
---@field weaponDBID number Firing unit weapon database ID

---Fire Support Task template extending task with firing units
---@class SBJ__FireSupportTaskTemplate: SBJ__Task
---@field name string FST name
---@field missileSystemType string Missile system type key (constants.MISSILE_SYSTEM_TYPES)
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
---@field createdAt? number Creation unix timestamp for stale retirement; nil on legacy saves (never stale)
---@field fireSupportTasks SBJ__FireSupportTask[] Fire support tasks array

---Attack contacts parameters for coordinating strikes
---@class SBJ__AttackContactsParams: table
---@field contacts table<integer, string> A table of contact GUIDs to attack
---@field qty? integer The number of salvos to launch (default: 1)
---@field firingUnits SBJ__FiringUnit[] A table of firing units to use for the attack
---@field weaponDBID? number The weapon DBID to use for the attack; nil uses the firing unit's default weapon
---@field sideName? string The side to use for the attack (default: constants.SIDES.RED)

---Inputs for attacking one contact
---@class SBJ__AttackContactParams: table
---@field ammoToAllocate integer Total ammunition to allocate for this contact
---@field firingUnits SBJ__FiringUnit[] Firing units to use for the attack
---@field weaponDBID? number Weapon DBID to use; nil uses the firing unit's default weapon

---Firing unit / shooter rotation carried across contacts
---@class SBJ__AttackRotationState: table
---@field firingUnitIdx integer Current firing unit index
---@field shooterIdx integer Current shooter index within a group

---One receiver role's inputs for tanker arrival timing
---@class SBJ__ReceiverContext: table
---@field role SBJ__RoleKey Receiver role name
---@field receiver SBJ__MissionDeploymentDescriptor Receiver role deployment descriptor
---@field receiverTiming SBJ__RoleTiming Calculated receiver timing

---Parameters for generating missile flight paths
---@class SBJ__GenerateMissilePathsParams: table
---@field targetLat number Target latitude
---@field targetLon number Target longitude
---@field launcherLat number Launcher latitude
---@field launcherLon number Launcher longitude
---@field radarRange number Radar range (nautical miles)
---@field missileCount? number Number of missiles (default: 5)
---@field missileSpeedKts? number Missile speed in knots (default: 600)
---@field missileRangeNm? number Maximum missile range in nautical miles (default: 100)

---Missile path definition with waypoints and timing
---@class SBJ__MissilePath: table
---@field waypoints CMO__Waypoint[] Missile waypoint list
---@field launchTime number Launch time (UTC timestamp)


-- ============================================================================
-- Reconnaissance & Intelligence
-- ============================================================================
-- Reconnaissance and intelligence types for recon module

---Reconnaissance platform discriminator
---@alias SBJ__ReconType "UAV"|"satellite"|"SIGINT"

---Execution state attached when a queue plan is initialized
---Both flags are always present on a queued entry, which is what separates
---SBJ__ReconQueueEntry from SBJ__ReconQueueDescriptor.
---@class SBJ__ReconRunState: table
---@field isFinished boolean Whether the mission has settled
---@field hasScheduledOperations boolean Whether follow-on operations were queued; never cleared, unlike isFinished

---UAV reconnaissance blueprint held in config.red.recon.templates
---Carries no timings: addEntry resolves those when the entry is queued.
---@class SBJ__ReconUAVTemplate: table
---@field type "UAV" Platform discriminator
---@field templateId string Unique identifier matching its key in config.red.recon.templates; used to detect duplicate queue entries
---@field reconObjectiveId? string Recon objective used to schedule follow-on strike mappings; omit for recon that does not trigger strikes
---@field baseGUID string Base GUID where the UAV is stationed
---@field unitDBID number Platform database ID of the unit launched from baseGUID
---@field course CMO__Waypoint[] Waypoints for the reconnaissance route
---@field speed number Cruise speed in knots of the launched unit; also drives flight-time estimation
---@field trackingSpeed? number Desired speed in knots while shadowing a contact; falls back to speed when the tracking airframe is the launched one
---@field isTracking? boolean Whether this mission may be handed a tracking target

---UAV blueprint plus resolved timings, as authored directly in config.red.recon.queue
---Recon.addEntry produces this shape too, by computing the timings from the course.
---@class SBJ__ReconUAVDescriptor: SBJ__ReconUAVTemplate
---@field takeoffTime string Scheduled takeoff time in format "YYYY-MM-DD HH:MM:SS"
---@field endTime string Scheduled end time in format "YYYY-MM-DD HH:MM:SS"

---UAV plan once queued, with execution state attached by initQueue
---@class SBJ__ReconUAVEntry: SBJ__ReconUAVDescriptor, SBJ__ReconRunState
---@field hasLaunched boolean Whether the launch phase has run
---@field unitGUID? string Unit being monitored: the launched aircraft, or the WZ-8 it released
---@field trackingTargetGUID? string Target contact GUID being shadowed

---Satellite or SIGINT pass as authored in config.red.recon.queue
---These have no launch phase, so the plan needs nothing beyond its objective and timing.
---@class SBJ__ReconPassiveDescriptor: table
---@field type "satellite"|"SIGINT" Platform discriminator
---@field reconObjectiveId? string Recon objective used to schedule follow-on strike mappings
---@field endTime string Scheduled end time in format "YYYY-MM-DD HH:MM:SS"

---Satellite or SIGINT pass once queued
---@class SBJ__ReconPassiveEntry: SBJ__ReconPassiveDescriptor, SBJ__ReconRunState

---Union of what config.red.recon.queue holds before initQueue runs
---@alias SBJ__ReconQueueDescriptor SBJ__ReconUAVDescriptor|SBJ__ReconPassiveDescriptor

---Union of every queued reconnaissance entry
---@alias SBJ__ReconQueueEntry SBJ__ReconUAVEntry|SBJ__ReconPassiveEntry

---Reconnaissance context managing reconnaissance operations state
---@class SBJ__ReconContext: table
---@field enabled boolean Whether reconnaissance system is activated
---@field queue SBJ__ReconQueueEntry[] Reconnaissance mission queue
---@field frontlineRedirected boolean Sticky flag set true once frontline strike redirect activates; never cleared

---Shared runtime inputs for processing reconnaissance queue entries
---@class SBJ__ReconQueueProcessingContext: table
---@field config SBJ__Config Configuration data
---@field reconCtx SBJ__ReconContext Reconnaissance runtime context
---@field reconTriggeredOperationBatches SBJ__ReconTriggeredOperationBatch[] Operation batches triggered by reconnaissance
---@field lacmCtx SBJ__LACMContext LACM context data
---@field fireSupportOnHold boolean Whether SRBM-driven mappings should be skipped to conserve ammo

---Reconnaissance-Strike mapping entry
---Defines strike mission to execute after reconnaissance platform detects target
---@class SBJ__ReconStrikeMapping: table
---@field name string Strike mission name
---@field type SBJ__OperationType Strike mission type
---@field requiresLACM? boolean Only schedule while the LACM element is committed; gates the first wave and every follow-on wave alike

-- ============================================================================
-- Dynamic Operations (ATO/FSEM)
-- ============================================================================
-- Dynamic operations types for atoBuilder and fsemBuilder modules

---Generated operations tracker for dynamic operations
---@class SBJ__GeneratedOperationsTracker: table
---@field air table<string, boolean> Generated air operation names indexed by operation name
---@field ground table<string, boolean> Generated ground operation names indexed by operation name

---Per-type facts that let the scheduler and DynamicPlan stay generic over air and ground
---Owned by OperationType; every air/ground dispatch reads one of these instead of branching on the type string.
---@class SBJ__OperationTypeDescriptor: table
---@field templateSource string Key under config.red holding the templates ("packageTemplates" or "fireSupportTaskTemplates")
---@field templateField string Array field inside an operation template ("packages" or "fireSupportTasks")
---@field registryKey string Key under generatedOperations that tracks names of this type
---@field resolvePlan fun(plannerState: SBJ__StrikePlannerState): table<string, any> The plan table generated operations are inserted into
---@field resolveDefaultInterval fun(config: SBJ__Config): number Strike interval used when a template carries none

---Outcome of turning one recon-triggered operation into an inserted ATO wave or FSEM
---Deliberately NOT a SBJ__LogResult: fields is a partial contribution that the
---caller merges with the operation identity (operation=, batch=) before it
---becomes a row, so this shape is not interchangeable with one. details and
---timing, by contrast, are complete rows handed straight to a report.
---A producer whose caller only needs "did it produce something" should return
---SBJ__LogResult directly instead; this type exists because the caller must
---also tell retryable failures apart from terminal ones, which needs reason.
---@class SBJ__OperationProcessResult: table
---@field success boolean Whether the operation produced an inserted wave or FSEM
---@field reason? string Failure reason token when success is false, also written into the row
---@field tag string Status tag for the operation row
---@field fields? table<string, any> Evaluation counters merged into the operation row
---@field details? SBJ__LogResult[] Complete rows nested under the operation row

---Air-path outcome adding the wave timing rows emitted into a separate report
---@class SBJ__AirOperationProcessResult: SBJ__OperationProcessResult
---@field timing? SBJ__LogResult[] Complete rows for the separate timing report

---Dynamic operations context managing intelligence-driven adaptive strike planning
---@class SBJ__DynamicOperationsContext: table
---@field enabled boolean Whether dynamic operations system is enabled
---@field generatedOperations SBJ__GeneratedOperationsTracker Generated operation name tracker
---@field reconTriggeredOperationBatches SBJ__ReconTriggeredOperationBatch[] Reconnaissance-triggered operation batches

---Air operation definition for dynamic ATO insertion
---@class SBJ__AirOperation: table
---@field type "air" Operation type discriminator
---@field executed boolean Whether the ATO wave was inserted into the plan; an operation given up on is removed from its batch instead of being marked, and insertion does not guarantee the package ever took off
---@field template SBJ__WaveTemplate ATO wave template

---Ground operation definition for dynamic fire support insertion
---@class SBJ__GroundOperation: table
---@field type "ground" Operation type discriminator
---@field executed boolean Whether the FSEM was inserted into the plan; an operation given up on is removed from its batch instead of being marked, and insertion does not guarantee the tasks ever fired
---@field template SBJ__FireSupportExecutionMatrixTemplate FSEM template

---Operation definition for dynamic operations
---@alias SBJ__Operation SBJ__AirOperation|SBJ__GroundOperation

---Operation batch triggered by completed reconnaissance
---@class SBJ__ReconTriggeredOperationBatch: table
---@field time string Reconnaissance time in format "2027-06-09 14:30:00"
---@field type string Reconnaissance type: "satellite", "aircraft", or "UAV"
---@field delay number Delay trigger time (seconds)
---@field executed boolean Whether already executed
---@field operations SBJ__Operation[] Operations to execute

---Operation paired with the reconnaissance-triggered batch that owns it
---Handed to the builder's tryInsert by OperationBatch.process; execution status is written back by OperationBatch, not the builder
---@class SBJ__BatchedOperation: table
---@field operationBatch SBJ__ReconTriggeredOperationBatch Parent batch owning the operation
---@field operation SBJ__Operation Operation to execute

---Inputs for one OperationBatch.process tick
---The builder only answers "can this template be inserted right now"; every batch
---policy (observation window, retry, abandon, expiry) stays inside OperationBatch.
---@class SBJ__OperationBatchRunParams: table
---@field currentTime integer Current scenario time in unix timestamp
---@field windowSec number Observation window duration in seconds
---@field retryableReasonSet table<string, true> Failure reasons that keep an operation pending inside the window
---@field tryInsert fun(batchedOp: SBJ__BatchedOperation): SBJ__OperationProcessResult Attempt to build and insert the operation's plan

---One attempted operation from an OperationBatch.process tick
---fields already carries operation=, batch=, reason= and state=, ready for a report row.
---@class SBJ__OperationBatchRunEntry: table
---@field tag string Status tag for the operation row
---@field fields table<string, any> Merged row fields
---@field outcome SBJ__OperationProcessResult Raw outcome returned by tryInsert or synthesized on expiry

---Outcome of one OperationBatch.process tick
---@class SBJ__OperationBatchRunResult: table
---@field hasExecutedAny boolean True when at least one operation had its plan inserted
---@field entries SBJ__OperationBatchRunEntry[] One entry per operation that was due this tick

---Most recent batch's operations by type plus the next batch time
---@class SBJ__OperationBatchSnapshot: table
---@field air SBJ__Operation[] Air operations of the most recent elapsed batch
---@field ground SBJ__Operation[] Ground operations of the most recent elapsed batch
---@field nextOperationBatchTime string|nil Time of the earliest batch still in the future
---@field mostRecentTime string|nil Time of the most recent elapsed batch

---Wave template for Dynamic ATO Insertion
---@class SBJ__WaveTemplate: table
---@field name string ATO wave name
---@field isFirstWave boolean Whether it's the first wave attack
---@field strikeInterval number Strike interval time (seconds)
---@field packages SBJ__PackageTemplate[] ATO package array

---@class SBJ__RoleKey: table

---Package template for air operation coordination
---@class SBJ__PackageTemplate: SBJ__Task
---@field striker? SBJ__MissionDeploymentDescriptor Main striker configuration
---@field escort? SBJ__MissionDeploymentDescriptor Escort configuration
---@field wildWeasel? SBJ__MissionDeploymentDescriptor Wild Weasel configuration
---@field jammer? SBJ__MissionDeploymentDescriptor Jammer configuration
---@field tanker? SBJ__TankerMissionDeploymentDescriptor Tanker configuration
---@field reconUAV? SBJ__ReconUAVTemplate Reconnaissance UAV configuration
---@field timeToReady number Ready time in seconds
---@field [SBJ__RoleKey] SBJ__MissionDeploymentDescriptor

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
---@field pos? CMO__Location Deployment coordinates
---@field randomRadiusNm number Position randomization radius (nautical miles)
---@field radius number GNSS jamming effectiveness radius (nautical miles)

---GNSS jammer context extending descriptor with runtime state
---@class SBJ__GNSSJammerContext: SBJ__GNSSJammerDescriptor

---Enhanced SIGINT detection result with confidence and metadata
---@class SBJ__SIGINTResult: table
---@field longitude number Detected longitude coordinate
---@field latitude number Detected latitude coordinate
---@field isDetected boolean Whether signal is detected
---@field confidence number Detection confidence level (0-1)
---@field detectorId? string ID of detecting unit
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

---SIGINT context managing all transmission tracking
---@class SBJ__SIGINTContext: table
---@field transmissions table<string, SBJ__RadioTransmissionContext> Radio transmission contexts indexed by GUID
---@field reconAircraft table<string, SBJ__AircraftContext> Recon aircraft context data structure indexed by GUID
---@field enabled boolean Whether SIGINT is activated

---Communications jamming context managing electronic warfare jamming operations
---@class SBJ__CommsJammingContext: table
---@field enabled boolean Whether communications jamming system is activated
---@field jammers table<string, SBJ__AircraftContext> Jamming aircraft indexed by GUID

---State slices the China strike planner reads and mutates in one tick
---@class SBJ__StrikePlannerState: table
---@field targetlist SBJ__TargetEntry[] Persisted fixed-target list, refilled in place at init
---@field transmissions table<string, SBJ__RadioTransmissionContext> China SIGINT transmissions read by radio-direction targeting
---@field recon SBJ__ReconContext China recon context
---@field dynamicOperations SBJ__DynamicOperationsContext Recon-triggered batches and generated operation names
---@field air SBJ__AirOperationsContext China air operations, including the ATO
---@field ground SBJ__StrikingGroundContext China ground forces, including the FSP
---@field lacm SBJ__LACMContext CSG land-attack cruise missile state
---@field slcm SBJ__SLCMContext Submarine-launched cruise missile state
---@field fireSupportOnHold boolean Landing ops hold on SRBM fire support, read at slice time

---State slices landing operations read and mutate: own amphibious state, recon queue, SRBM inventory
---@class SBJ__LandingOpsState: table
---@field amphibOps SBJ__AmphibOpsContext China amphibious operations context
---@field recon SBJ__ReconContext China recon context the Taoyuan setup queues GJ-11 recon into
---@field ground SBJ__GroundContext China ground forces the fire support gate reads SRBM ammo from

---State slices read and mutated by one comms jamming cycle
---@class SBJ__CommsJammingState: table
---@field enabled boolean Whether China comms jamming is active
---@field jammers table<string, SBJ__AircraftContext> China jamming aircraft indexed by GUID
---@field iads SBJ__IADSContext Taiwan IADS whose SAM/radar comms are jammed
---@field aircraft table<string, SBJ__AircraftContext> Taiwan land-based aircraft indexed by GUID
---@field aew table<string, SBJ__AircraftContext> Taiwan AEW aircraft indexed by GUID


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

---@class SBJ__C2UnitKey: table

---@class SBJ__C2TypeKey: table

---Command and Control (C2) context data structure
---@class SBJ__C2Context: table
---@field name string C2 node name
---@field msg string Status message
---@field guid string C2 node GUID
---@field areas table<number, string[]> Associated operational areas
---@field sam table<string, SBJ__RadarContext> Surface-to-Air Missile systems
---@field radar? table<string, SBJ__RadarContext> Radar systems
---@field [SBJ__C2UnitKey] table<string, SBJ__RadarContext>

---C2 node deployment descriptor
---Defines how to create and deploy a single Command and Control node
---@class SBJ__C2Descriptor: table
---@field pos? CMO__Location C2 position coordinates
---@field areas string[][] Operation areas array
---@field name string Operation area name

---Integrated Air Defense System configuration
---Defines C2 facility parameters and deployment settings for IADS
---@class SBJ__IADSConfig: table
---@field c2FacilityDBIDs number[] Database IDs for C2 facility types
---@field randomRadiusNm number Random deployment radius (nautical miles)
---@field radarDistanceNm number Backup radar search distance when a radar is destroyed (nautical miles)
---@field c2Deployments SBJ__C2Descriptor[] C2 node deployment descriptors

---IADS context managing air defense system state
---Tracks all Command and Control nodes and system activation status
---@class SBJ__IADSContext: table
---@field c2? table<string, SBJ__C2Context> C2 node context data structure indexed by GUID
---@field rocc? table<string, SBJ__C2Context> ROCC context data structure indexed by GUID
---@field taaoc? table<string, SBJ__C2Context> TAAOC context data structure indexed by GUID
---@field enabled boolean Whether IADS is activated
---@field [SBJ__C2TypeKey] table<string, SBJ__C2Context>

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

---Aircraft slice tracking aircraft and AEW
---@class SBJ__AircraftSliceContext: table
---@field ac table<string, SBJ__AircraftContext> Aircraft context data structure indexed by GUID
---@field aew table<string, SBJ__AircraftContext> AEW aircraft context data structure indexed by GUID


-- ============================================================================
-- Runway Repairment
-- ============================================================================
-- Runway damage assessment and repair management types

---Runway entry for tracking runway damage and repair progress
---@class SBJ__RunwayEntry: table
---@field guid string Runway unit GUID
---@field startTime number|nil Repair operation start timestamp, nil if not yet started

---China runway repair configuration
---@class SBJ__RedRunwayRepairConfig: table
---@field percentagePerHour number Repair percentage per hour
---@field runwayDBIDs number[] List of runway database IDs to repair

---Taiwan runway repair configuration
---@class SBJ__BlueRunwayRepairConfig: table
---@field percentagePerHour number Repair percentage per hour
---@field airBases string[] List of Taiwan airbases with runways to repair
---@field runwaySubTypes string[] Array of runway facility sub-type patterns to match

---Runway repair context managing runway damage repair operations
---@class SBJ__RunwayRepairmentContext: table
---@field enabled boolean Whether runway repair system is activated
---@field runways SBJ__RunwayEntry[] Array of runways being tracked for repair


-- ============================================================================
-- Tactical Area Generation
-- ============================================================================
-- Types for generating tactical area layouts (U-shaped areas, fire points, etc.)

---Tactical area generation result
---Contains all generated vertices for U-shape, internal zones, and fire points
---@class SBJ__TacticalAreas: table
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

---Movement paths configuration for tactical area
---Maps path types to their waypoint arrays
---@class SBJ__MovementPaths: table
---@field FP table<integer, SBJ__MovementPath> Fire Point paths: hide area -> each fire point
---@field HA SBJ__MovementPath Hide Area path: reload point -> hide area
---@field RL table<integer, SBJ__MovementPath> Reload paths: each fire point -> reload point
---@field AHA SBJ__MovementPath Ammo Holding Area path: reload point -> ammo holding area
---@field SHRL SBJ__MovementPath Shelter Hide Reload Loop path: shelter -> reload point

---Battery placement submitted by the control panel
---@class SBJ__MissileSystemResult: table
---@field key string Control panel row key
---@field unitname string Firing unit name in the side's ground force config
---@field missileSystemType string Missile system type key (constants.MISSILE_SYSTEM_TYPES)
---@field center CMO__Location Center of the drawn layout
---@field openingAngle number U-shape opening angle in degrees
---@field tacticalAreas SBJ__TacticalAreas Drawn zones
---@field paths SBJ__MovementPaths Drawn movement paths

---Point budget the player spent in the control panel
---@class SBJ__BudgetResult: table
---@field initial number Points available at the start
---@field used number Points spent
---@field remaining number Points left

---Control panel deployment result containing user selections
---@class SBJ__ControlPanelResult: table
---@field budget SBJ__BudgetResult Point budget the player spent
---@field jammers SBJ__GNSSJammerDescriptor[] GNSS jammer deployment configurations
---@field airbases SBJ__AirbaseDeploymentDescriptor[] Airbase deployment configurations
---@field missileSystems SBJ__MissileSystemResult[] TEL missile system deployment configurations with tactical areas and paths

---One `addXXX` option in the add-units menu
---@class SBJ__AddUnitAction: table
---@field id string Stable id sent back by the page
---@field label string Text shown next to the checkbox
---@field run fun(config: SBJ__Config) Add the units

---Add-units menu result containing the ticked action ids
---@class SBJ__AddUnitsMenuResult: table
---@field actionIds string[] Ids of the `addXXX` actions to run

---Weapons control choice for one live SAM unit
---@class SBJ__SamDoctrineEntry: table
---@field guid string SAM unit GUID
---@field name string SAM unit name
---@field weaponFree boolean True for weapons free, false for hold fire

---A C2 node whose SAM units changed, shaped like SBJ__C2Context
---@class SBJ__C2ContextEntry: table
---@field guid string GUID of the C2 node
---@field type SBJ__C2TypeKey IADS group the node lives in ('c2', 'rocc' or 'taaoc')
---@field name string C2 node name
---@field sam table<string, {guid: string, name: string}> SAM units now under the node, indexed by GUID

---EMCON configuration result containing user selections
---@class SBJ__EmconResult: table
---@field sams SBJ__SamDoctrineEntry[] SAM units with the weapons control status the player chose
---@field c2Nodes SBJ__C2ContextEntry[]|nil C2 nodes whose SAM units changed after redeployment

-- ============================================================================
-- Ground Operations (Fire Support) - FSEM Builder
-- ============================================================================
-- Fire support execution matrix types for fsemBuilder module

---Firing unit status counter tracking validation outcomes
---@alias SBJ__FiringUnitStatusResult table<string, number>

---Pass-scoped state for one ATO insertion pass
---The free aircraft cache is local to the pass so a later tick never counts aircraft already committed
---@class SBJ__AtoPassContext: table
---@field config SBJ__Config Global configuration
---@field contacts CMO__Contact[] Sensor contacts for this pass
---@field freeAircraftCache table<string, table<number, integer>> Free aircraft per base GUID and DBID; mutated as packages are built

---Inputs for inserting one evaluated ATO wave
---@class SBJ__WaveInsertParams: table
---@field waveTemplate SBJ__WaveTemplate Template defining ATO wave and package configurations
---@field targetsByPackageIndex table<integer, string[]> Evaluated targets grouped by package index
---@field reconType string Reconnaissance type identifier used for wave naming

---Pass-scoped caches for firing unit lookups within one execution pass
---Caches are local to prevent cross-tick stale data while building FSEMs
---@class SBJ__FsemPassContext: table
---@field contacts CMO__Contact[] Sensor contacts for this pass
---@field currentTime integer Game time captured at the start of this pass
---@field firingUnitCache table<string, CMO__Unit|false> Firing unit lookups resolved in this pass; false means "looked up and missing"
---@field assignedFiringUnitNames table<string, boolean> Firing unit names already committed, seeded from the FSP and grown as tasks are built

---Game snapshot handed to Coordinator.process for one event tick
---@class SBJ__LandingTickParams: table
---@field contacts CMO__Contact[] Contact list from the game
---@field currentTime number Current scenario time in seconds
---@field filteredShips CMO__SideUnit[] Unit list from the side filtered for ships

---Inputs shared by every landing phase in one event tick
---@class SBJ__LandingTickContext: table
---@field config SBJ__Config Global configuration table
---@field landingState SBJ__LandingOpsState Amphibious, recon, and ground force slices
---@field contacts CMO__Contact[] Contact list from the game
---@field currentTime number Current scenario time in seconds
---@field filteredShips CMO__SideUnit[] Unit list from the side filtered for ships

---Ammunition totals and weapon choice for one group-attack step
---@class SBJ__GroupAttackRequest: table
---@field totalAmmoRequested integer Total amount of ammunition requested for this attack
---@field ammoAlreadyAllocated integer Amount of ammunition already allocated in this attack
---@field weaponDBID number Specific weapon DBID to use

---A detected SIGINT emitter paired with its detection result
---@class SBJ__SIGINTHit: table
---@field unit CMO__Unit Actual unit object for autodetectable state updates
---@field result SBJ__SIGINTResult Detection result with position and confidence

---Inputs for launching embarked units from a base
---@class SBJ__LaunchUnitsParams: table
---@field baseGUID string The base GUID to launch units from
---@field course CMO__Waypoint[] The course waypoints for launched units
---@field unitCount number The number of units to launch
---@field unitDBID number The unit database ID to filter by
---@field unitType string The unit type to launch (e.g., 'Aircraft' or 'Boats')

---Settings shared by every group member when loading cargo proxies onto a ship
---@class SBJ__CargoLoadContext: table
---@field weaponDBIDSet table<number, boolean> Set of weapon DBIDs to track
---@field sideName string Side name

---Group, fleet, layout and cargo shared by every ship type created for one fleet group
---@class SBJ__ShipFormationContext: table
---@field group SBJ__FleetGroup Group configuration
---@field fleet SBJ__FleetDescriptor Fleet configuration of the zone
---@field shipSettings SBJ__AmphibiousFormationConfig Amphibious layout configuration
---@field cargoMap table<string, SBJ__CargoDescriptor[]> Cargo list

---Inputs for inserting one evaluated FSEM
---@class SBJ__MatrixInsertParams: table
---@field matrixTemplate SBJ__FireSupportExecutionMatrixTemplate Template defining FSEM structure
---@field targetsByTaskIndex table<integer, string[]> Evaluated targets keyed by FST index
---@field reconType string Reconnaissance type identifier used for FSEM naming

---Position emitter describing one opArea field and where to find its AREAS const
---@class SBJ__OpAreaPositionEmitter
---@field field string opArea field name (RL/HA/FP/AHA/SHRL)
---@field keyPrefix string areaRefMap subkey; combined with position index as `keyPrefix .. "_" .. i` when indexed
---@field indexed boolean When true, subkey varies per position; when false, keyPrefix is the full subkey

---Inputs for emitting one position block
---@class SBJ__PositionBlockParams
---@field key string Operational-area key (e.g. "ANW")
---@field map table<string, table<string, string>> Phase 2's [opKey][posType_index] -> AREAS const-name map

---Shared context for Phase 4 field serializers
---@class SBJ__FieldSerializerContext
---@field configPath string Current config.{side}.ground.missileSystemTypes.{sys} path
---@field opAreaMap table<table, string> opArea table ref -> constant key
---@field reverseState table<any, string> state value -> constant key
---@field reverseWeapons table<integer, string> weapon DBID -> constant key
---@field reversePlatforms table<integer, string> platform DBID -> constant key

---Per-field serializer signature; return nil to fall through to default
---@alias SBJ__FieldSerializer fun(value: any, ctx: SBJ__FieldSerializerContext): string|nil

---Embarked platform selector for cargo transfer
---@class SBJ__TransferCargoParams
---@field platformType string Embarked unit type ('Aircraft' or 'Boats')
---@field platformDBID number DBID of the receiving platform
---@field loadoutDBID number Loadout ID for aircraft filtering (ignored for boats)
