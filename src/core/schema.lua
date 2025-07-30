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
---@field target_lat number 目標緯度
---@field target_lon number 目標經度
---@field launcher_lat number 發射器緯度
---@field launcher_lon number 發射器經度
---@field radar_range number 雷達範圍（海浬）
---@field missile_count number|nil 飛彈數量，預設為 5
---@field missile_speed_kts number|nil 飛彈速度（節），預設為 600
---@field missile_range_nm number|nil 飛彈最大射程（海浬），預設為 100

---@class SBJ__MissilePath
---@field waypoints table<integer, CMO__Location> 飛彈路徑點列表
---@field launch_time number 發射時間（UTC 時間戳）

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
---@field loadoutId number 彈藥配置ID
---@field num number 單位數量

---@class SBJ__EmbarkedUnit:table
---@field side string 陣營名稱
---@field type string 單位類型
---@field name string 單位名稱
---@field dbid number 單位數據庫ID
---@field loadouts SBJ__Loadout[]|nil 單位彈藥配置

---@class SBJ__ShipConfig:table
---@field dbid number 數據庫ID
---@field unitname string 單位名稱
---@field distance number 距離
---@field angle number 角度
---@field embarkedUnits SBJ__EmbarkedUnit[]|nil 搭載單位
---@field loadouts SBJ__Loadout[]|nil 彈藥配置

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
---@field time string 偵察時間 "2027-06-09 14:30:00"
---@field type string 偵察類型 "satellite" | "aircraft"
---@field delay number 延遲觸發時間（秒）
---@field executed boolean 是否已執行
---@field fsemTemplate SBJ__FsemTemplate FSEM模板

---@class SBJ__FsemTemplate
---@field name string FSEM名稱
---@field isFirstWave boolean 是否為第一波攻擊
---@field strikeInterval number 打擊間隔時間（秒）
---@field FSTs SBJ__FstTemplate[] FST模板陣列

---@class SBJ__FstTemplate
---@field name string FST名稱
---@field target SBJ__TargetTemplate 目標配置
---@field wpnSystem string 武器系統類型
---@field batteries SBJ__Battery[] 電池/火力單位陣列

---@class SBJ__TargetTemplate
---@field objs table[]? 目標物件陣列（固定目標使用）
---@field areas string[] 作戰區域
---@field filterNames string[]? 篩選函數名稱（動態目標使用）
---@field contactAge number 聯絡人有效時間（秒）
---@field minTargetCount number 最小目標數量閾值
---@field ammoPerTarget number 每目標彈藥數量

---@class SBJ__DynamicFSPConfig
---@field enabled boolean 是否啟用動態火力支援計畫
---@field reconSchedule SBJ__ReconScheduleEntry[] 偵察時程表

---@class SBJ__BatteryAssignment
---@field guid string 火力單位GUID
---@field battery table 火力單位資料
