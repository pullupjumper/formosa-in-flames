---@class SBJ__CONFIG
local CONFIG = {}
CONFIG.isDevMode = true
CONFIG.isSaved = true
CONFIG.difficulty = 'normal'
CONFIG.c = {}
CONFIG.c.air = {}
CONFIG.c.air.landBased = {}
CONFIG.c.air.shipBased = {}
CONFIG.c.ground = {}
CONFIG.c.ground.mlrs = {}
CONFIG.c.ground.srbm = {}
CONFIG.c.ground.mrbm = {}
CONFIG.c.ground.glcm = {}
CONFIG.c.ground.ascm = {}
CONFIG.c.surface = {}
CONFIG.c.surface.lacm = {}
CONFIG.c.subSurface = {}
CONFIG.c.subSurface.slcm = {}
CONFIG.c.PHIBOP = {}
CONFIG.c.recon = {}
CONFIG.c.GPSJamming = {}
CONFIG.c.commsJamming = {}
CONFIG.c.repairRunway = {}
CONFIG.c.IADS = {}
CONFIG.c.SIGINT = {}
CONFIG.t = {}
CONFIG.t.ground = {}
CONFIG.t.ground.mlrs = {}
CONFIG.t.ground.glcm = {}
CONFIG.t.ground.srbm = {}
CONFIG.t.ground.ascm = {}
CONFIG.t.repairRunway = {}
CONFIG.t.IADS = {}
CONFIG.t.air = {}
CONFIG.t.air.landBased = {}
CONFIG.t.surface = {}
CONFIG.u = {}
CONFIG.u.SIGINT = {}
CONFIG.s = {}
CONFIG.c.areas = {
  ["OPAREA/FUZHOU"] = { 'RP-85130', 'RP-85131', 'RP-85132', 'RP-85133', },
  ["OPAREA/PUTIAN"] = { 'RP-156577', 'RP-156578', 'RP-156579', 'RP-156580', },
  ["OPAREA/CHANGZHOU"] = { 'RP-156581', 'RP-156582', 'RP-156583', 'RP-156584', },
  ["OPAREA/XIAMEN"] = { 'RP-156585', 'RP-156586', 'RP-156587', 'RP-156588', },
  ["OPAREA/ZHANGZHOU"] = { 'RP-85134', 'RP-85135', 'RP-85136', 'RP-85137', },
  ["OPAREA/SHANTOU"] = { 'RP-156589', 'RP-156590', 'RP-156591', 'RP-156592', },
  ["OPAREA/SHANWEI"] = { 'RP-156593', 'RP-156594', 'RP-156595', 'RP-156596', },
  ["OPAREA/MEIZHOU"] = { 'RP-85138', 'RP-85139', 'RP-85140', 'RP-85141', },
  ["RL/PINGTAN"] = { 'RP-114443', 'RP-114444', 'RP-114445', 'RP-114446' },
  ["HA/PINGTAN"] = { 'RP-114439', 'RP-114440', 'RP-114441', 'RP-114442' },
  ["FP1/PINGTAN"] = { 'RP-44264', 'RP-44265', 'RP-44266', 'RP-44267' },
  ["FP2/PINGTAN"] = { 'RP-44260', 'RP-44261', 'RP-44262', 'RP-44263' },
  ["AHA/PINGTAN"] = { 'RP-114447', 'RP-114448', 'RP-114449', 'RP-114450' },
  ["RL/CHINCHEW"] = { 'RP-114455', 'RP-114456', 'RP-114457', 'RP-114458' },
  ["HA/CHINCHEW"] = { 'RP-114451', 'RP-114452', 'RP-114453', 'RP-114454' },
  ["FP1/CHINCHEW"] = { 'RP-46390', 'RP-46391', 'RP-46392', 'RP-46393' },
  ["AHA/CHINCHEW"] = { 'RP-114459', 'RP-114460', 'RP-114461', 'RP-114462' },
  ["RL/BRIGADE615"] = { 'RP-114467', 'RP-114468', 'RP-114469', 'RP-114470' },
  ["HA/BRIGADE615"] = { 'RP-114463', 'RP-114464', 'RP-114465', 'RP-114466' },
  ["FP1/BRIGADE615"] = { 'RP-44322', 'RP-44323', 'RP-44324', 'RP-44325' },
  ["AHA/BRIGADE615"] = { 'RP-114471', 'RP-114472', 'RP-114473', 'RP-114474' },
  ["RL/BRIGADE614"] = { 'RP-114479', 'RP-114480', 'RP-114481', 'RP-114482' },
  ["HA/BRIGADE614"] = { 'RP-114475', 'RP-114476', 'RP-114477', 'RP-114478' },
  ["FP1/BRIGADE614"] = { 'RP-44335', 'RP-44336', 'RP-44337', 'RP-44338' },
  ["AHA/BRIGADE614"] = { 'RP-114483', 'RP-114484', 'RP-114485', 'RP-114486' },
  ["RL/BRIGADE636"] = { 'RP-114491', 'RP-114492', 'RP-114493', 'RP-114494' },
  ["HA/BRIGADE636"] = { 'RP-114487', 'RP-114488', 'RP-114489', 'RP-114490' },
  ["FP1/BRIGADE636"] = { 'RP-44357', 'RP-44358', 'RP-44359', 'RP-44360' },
  ["AHA/BRIGADE636"] = { 'RP-114495', 'RP-114496', 'RP-114497', 'RP-114498' },
  ["RL/BRIGADE616"] = { 'RP-114503', 'RP-114504', 'RP-114505', 'RP-114506' },
  ["HA/BRIGADE616"] = { 'RP-114499', 'RP-114500', 'RP-114501', 'RP-114502' },
  ["FP1/BRIGADE616"] = { 'RP-44369', 'RP-44370', 'RP-44371', 'RP-44372' },
  ["AHA/BRIGADE616"] = { 'RP-114507', 'RP-114508', 'RP-114509', 'RP-114510' },
  ["RL/BRIGADE613"] = { 'RP-114515', 'RP-114516', 'RP-114517', 'RP-114518' },
  ["HA/BRIGADE613"] = { 'RP-114511', 'RP-114512', 'RP-114513', 'RP-114514' },
  ["FP1/BRIGADE613"] = { 'RP-44391', 'RP-44392', 'RP-44393', 'RP-44394' },
  ["AHA/BRIGADE613"] = { 'RP-114519', 'RP-114520', 'RP-114521', 'RP-114522' },
  ["RL/BRIGADE617"] = { 'RP-114527', 'RP-114528', 'RP-114529', 'RP-114530' },
  ["HA/BRIGADE617"] = { 'RP-114523', 'RP-114524', 'RP-114525', 'RP-114526' },
  ["FP1/BRIGADE617"] = { 'RP-44413', 'RP-44414', 'RP-44415', 'RP-44416' },
  ["AHA/BRIGADE617"] = { 'RP-114531', 'RP-114532', 'RP-114533', 'RP-114534' },
  ["RL/BRIGADE624"] = { 'RP-156928', 'RP-156929', 'RP-156930', 'RP-156931' },
  ["HA/BRIGADE624"] = { 'RP-156932', 'RP-156933', 'RP-156934', 'RP-156935' },
  ["FP1/BRIGADE624"] = { 'RP-156936', 'RP-156937', 'RP-156938', 'RP-156939' },
  ["AHA/BRIGADE624"] = { 'RP-156924', 'RP-156925', 'RP-156926', 'RP-156927' },
  ["STARTING POINT/075/TAOYUAN"] = { 'RP-11169' },
  ["OPAREA/D"] = { 'RP-46580', 'RP-46581', 'RP-46582', 'RP-46583' },
  ["DESTINATION/075/TAOYUAN"] = { 'RP-4322' },
  ["DESTINATION/071/TAOYUAN"] = { 'RP-3915' },
  ["AIRLANDING/TAOYUAN"] = { 'RP-3819', 'RP-3820', 'RP-3821', 'RP-3822' },
  ["STARTING POINT/075/SISHU"] = { 'RP-56195' },
  ["OPAREA/F"] = { 'RP-46584', 'RP-46585', 'RP-46586', 'RP-46587' },
  ["DESTINATION/075/SISHU"] = { 'RP-69332' },
  ["DESTINATION/071/SISHU"] = { 'RP-69333' },
  ["STARTING POINT/075/PENGHU"] = { 'RP-59972' },
  ["OPAREA/E"] = { 'RP-59975', 'RP-59976', 'RP-59977', 'RP-59978' },
  ["DESTINATION/075/PENGHU"] = { 'RP-59973' },
  ["DESTINATION/071/PENGHU"] = { 'RP-59974' },
  ["ANCH AREA/TAOYUAN"] = { 'RP-9684', 'RP-9685', 'RP-9686', 'RP-9687' },
  ["LST ANCH AREA/TAOYUAN"] = { 'RP-9712', 'RP-9713', 'RP-9714', 'RP-9715' },
  ["CAS/E"] = { 'RP-6787', 'RP-6788', 'RP-6789', 'RP-6790' },
  ["OFFLOAD AREA/TAOYUAN"] = { 'RP-141074', 'RP-141075', 'RP-141076', 'RP-141077' },
  ["LANDING/TAOYUAN"] = { 'RP-7702', 'RP-7703', 'RP-7704', 'RP-7705' },
  ["AMPH VEH STAGING AREA/TAOYUAN"] = { 'RP-7722', 'RP-7723', 'RP-7724', 'RP-7725' },
  ["ANCH AREA/SISHU"] = { 'RP-69328', 'RP-69329', 'RP-69330', 'RP-69331' },
  ["LST ANCH AREA/SISHU"] = { 'RP-69324', 'RP-69325', 'RP-69326', 'RP-69327' },
  ["CAS/S"] = { 'RP-73973', 'RP-73974', 'RP-73975', 'RP-73976' },
  ["OFFLOAD AREA/SISHU"] = { 'RP-141078', 'RP-141079', 'RP-141080', 'RP-141081' },
  ["LANDING/SISHU"] = { 'RP-69316', 'RP-69317', 'RP-69318', 'RP-69319' },
  ["AIRLANDING/CHANGLONG"] = { 'RP-11165', 'RP-11166', 'RP-11167', 'RP-11168' },
  ["AMPH VEH STAGING AREA/SHISHU"] = { 'RP-69320', 'RP-69321', 'RP-69322', 'RP-69323' },
  ["ANCH AREA/PENGHU"] = { 'RP-46576', 'RP-46577', 'RP-46578', 'RP-46579' },
  ["LST ANCH AREA/PENGHU"] = { 'RP-46572', 'RP-46573', 'RP-46574', 'RP-46575' },
  ["CAS/PENGHU"] = { 'RP-69261', 'RP-69262', 'RP-69263', 'RP-69264' },
  ["OFFLOAD AREA/PENGHU"] = { 'RP-141082', 'RP-141083', 'RP-141084', 'RP-141085' },
  ["LANDING/PENGHU"] = { 'RP-46290', 'RP-46291', 'RP-46292', 'RP-46293' },
  ["AIRLANDING/PENGHU"] = { 'RP-59968', 'RP-59969', 'RP-59970', 'RP-59971' },
  ["AMPH VEH STAGING AREA/PENGHU"] = { 'RP-46329', 'RP-46330', 'RP-46331', 'RP-46332' },
  ["OPAREA/NORTH"] = { 'RP-8012', 'RP-8013', 'RP-8014', 'RP-8015' },
  ["OPAREA/CENTER"] = {
    'RP-156966', 'RP-156967', 'RP-156968',
    'RP-156969', 'RP-156970', 'RP-156971',
    'RP-156972', 'RP-156973', 'RP-156974'
  },
  ["OPAREA/PACIFIC"] = { 'RP-76319', 'RP-42688', 'RP-42687', 'RP-76320' },
  ["OPAREA/SOUTH"] = {
    'RP-156975', 'RP-156976', 'RP-156977',
    'RP-156978', 'RP-156979', 'RP-156980',
    'RP-156981', 'RP-156982', 'RP-156983',
    'RP-156984', 'RP-156985', 'RP-156986', 'RP-156987'
  },
  ["OPAREA/EAST"] = { 'RP-156988', 'RP-156989', 'RP-156990', 'RP-156991', 'RP-156992', 'RP-156993' },
  ["SWEAP/SOUTH/PROSECUTION"] = { 'rp-163362', 'rp-163363', 'rp-163364', 'rp-163365', },
  ["SWEAP/SOUTH/PATROL"] = { 'rp-163366', 'rp-163367', },
  ["SWEAP/CENTER/PROSECUTION"] = { 'rp-163338', 'rp-163339', 'rp-163340', 'rp-163341', },
  ["SWEAP/CENTER/PATROL"] = { 'rp-163342', 'rp-163343', },
  ["SWEAP/NORTH/PROSECUTION"] = { 'rp-163344', 'rp-163345', 'rp-163346', 'rp-163347', },
  ["SWEAP/NORTH/PATROL"] = { 'rp-163348', 'rp-163349', },
  ["SWEAP/JHI/PROSECUTION"] = { 'rp-163350', 'rp-163351', 'rp-163352', 'rp-163353', },
  ["SWEAP/JHI/PATROL"] = { 'rp-163354', 'rp-163355', },
  ["SWEAP/E/PROSECUTION"] = { 'rp-163356', 'rp-163357', 'rp-163358', 'rp-163359', },
  ["SWEAP/E/PATROL"] = { 'rp-163360', 'rp-163161', },
}

CONFIG.t.areas = {
  ["RL/PINGZHEN"] = { 'RP-100174', 'RP-100175', 'RP-100176', 'RP-100177' },
  ["FP1/PINGZHEN"] = { 'RP-44300', 'RP-44301', 'RP-44302', 'RP-44303' },
  ["AHA/PINGZHEN"] = { 'RP-114539', 'RP-114540', 'RP-114541', 'RP-114542' },
  ["RL/DADU"] = { 'RP-101781', 'RP-101782', 'RP-101783', 'RP-101784' },
  ["FP1/DADU"] = { 'RP-101785', 'RP-101786', 'RP-101787', 'RP-101788' },
  ["AHA/DADU"] = { 'RP-114555', 'RP-114556', 'RP-114557', 'RP-114558' },
  ["RL/QUANXI"] = { 'RP-100170', 'RP-100171', 'RP-100172', 'RP-100173' },
  ["FP1/QUANXI"] = { 'RP-44300', 'RP-44301', 'RP-44302', 'RP-44303' },
  ["AHA/QUANXI"] = { 'RP-114547', 'RP-114548', 'RP-114549', 'RP-114550' },
  ["RL/NEIPU"] = { 'RP-100166', 'RP-100167', 'RP-100168', 'RP-100169' },
  ["FP1/NEIPU"] = { 'RP-44288', 'RP-44289', 'RP-44290', 'RP-44291' },
  ["AHA/NEIPU"] = { 'RP-114563', 'RP-114564', 'RP-114565', 'RP-114566' },
  ["RL/LUZHU"] = { 'RP-107197', 'RP-107198', 'RP-107199', 'RP-107200' },
  ["FP1/LUZHU"] = { 'RP-107201', 'RP-107202', 'RP-107203', 'RP-107204' },
  ["AHA/LUZHU"] = { 'RP-114435', 'RP-114436', 'RP-114437', 'RP-114438' },
  ["RL/DONG"] = { 'RP-116585', 'RP-116586', 'RP-116587', 'RP-116588' },
  ["FP1/DONG"] = { 'RP-116593', 'RP-116594', 'RP-116595', 'RP-116596' },
  ["AHA/DONG"] = { 'RP-116581', 'RP-116582', 'RP-116583', 'RP-116584' },
  ["OPAREA/3RD"] = { 'RP-83642', 'RP-83643', 'RP-83644', 'RP-83645' },
  ["OPAREA/2ND"] = { 'RP-156521', 'RP-156522', 'RP-156523', 'RP-156524', 'RP-156525', 'RP-156526' },
  ["OPAREA/5TH"] = {
    'RP-156527', 'RP-156528', 'RP-156529',
    'RP-156530', 'RP-156531', 'RP-156532',
    'RP-156533', 'RP-156534', 'RP-156535'
  },
  ["OPAREA/4TH"] = {
    'RP-156536', 'RP-156537', 'RP-156538',
    'RP-156539', 'RP-156540', 'RP-156541',
    'RP-156542', 'RP-156543', 'RP-156544',
    'RP-156545', 'RP-156546', 'RP-156547', 'RP-156548'
  },
  groundAscmTestNai1 = { 'RP-7760', 'RP-7761', 'RP-7762', 'RP-7763' },
  groundAscmTestNai2 = { 'RP-7787', 'RP-7788', 'RP-7789', 'RP-7790' },
}

CONFIG.platformDBID1 = 2149  -- 726a
CONFIG.platformDBID2 = 3708  -- Z-18
CONFIG.platformDBID3 = 2511  -- 724
CONFIG.platformDBID4 = 2930  -- Ka-52k
CONFIG.platformDBID5 = 5856  -- Z-10
CONFIG.platformDBID6 = 3153  -- 075
CONFIG.platformDBID7 = 2006  -- 071
CONFIG.platformDBID8 = 4683  -- 072III
CONFIG.platformDBID9 = 4602  -- 072A
CONFIG.platformDBID10 = 2925 -- 073A
CONFIG.platformDBID11 = 3187 -- 002
CONFIG.platformDBID12 = 6642 -- WZ-8
CONFIG.platformDBID13 = 3309 -- BZK-005
CONFIG.platformDBID14 = 391  -- Customed TK-3
CONFIG.platformDBID15 = 2227 -- PAC-3
CONFIG.platformDBID16 = 2537 -- JY-26
CONFIG.platformDBID17 = 2538 -- YLC-8B
CONFIG.platformDBID18 = 3281 -- HQ-22
CONFIG.platformDBID19 = 386  -- S-300
CONFIG.platformDBID20 = 2442 -- S-400
CONFIG.platformDBID21 = 1277 -- HQ-12
CONFIG.platformDBID22 = 4324 -- PHL-16
CONFIG.platformDBID23 = 624  -- supply
CONFIG.platformDBID24 = 3126 -- PHL-03
CONFIG.platformDBID25 = 4582 -- GPS Jammer
CONFIG.platformDBID26 = 1376 -- underground shelter
CONFIG.platformDBID27 = 322  -- weapon storage facility
CONFIG.platformDBID28 = 5014 -- J-20
CONFIG.platformDBID29 = 4926 -- J-16
CONFIG.platformDBID30 = 4652 -- Su-30
CONFIG.platformDBID31 = 1731 -- H-6K
CONFIG.platformDBID32 = 4601 -- 072a
CONFIG.platformDBID33 = 4141 -- 劍二
CONFIG.platformDBID34 = 1092 -- skyguard
CONFIG.platformDBID35 = 4203 -- Y-9
CONFIG.platformDBID36 = 4454 -- J-35
CONFIG.platformDBID37 = 4817 -- J-15D
CONFIG.platformDBID38 = 2095 -- E-2K
CONFIG.platformDBID39 = 317  -- ZBD-03
CONFIG.platformDBID40 = 2503 -- II-76
CONFIG.platformDBID41 = 960  -- FPS-117
CONFIG.platformDBID42 = 1057 -- TPS-43F
CONFIG.platformDBID43 = 1363 -- HR-3000
CONFIG.platformDBID44 = 1362 -- GE-592
CONFIG.platformDBID45 = 5832 -- RC-135V
CONFIG.platformDBID46 = 3730 -- C2
CONFIG.platformDBID47 = 7064 -- Y-9DZ
CONFIG.platformDBID48 = 3587 -- 052d
CONFIG.platformDBID49 = 2714 -- 054a
CONFIG.platformDBID50 = 2086 -- Ammo Truck
CONFIG.platformDBID51 = 3883 -- 055
CONFIG.platformDBID52 = 2980 -- 901
CONFIG.platformDBID53 = 320  -- ammo
CONFIG.platformDBID54 = 4876 -- 076
CONFIG.platformDBID55 = 4962 -- GJ-11
CONFIG.platformDBID56 = 2566 -- ferry
CONFIG.platformDBID57 = 7419 -- J-10C
CONFIG.platformDBID58 = 241  -- ZBD-05
CONFIG.platformDBID59 = 240  -- ZTD-05
CONFIG.platformDBID60 = 318  -- PLL-05
CONFIG.platformDBID61 = 319  -- PLZ-96
CONFIG.platformDBID62 = 2876 -- PGZ-09
CONFIG.platformDBID63 = 758  -- PGZ-95
CONFIG.platformDBID64 = 2034 -- 悍馬車
CONFIG.platformDBID65 = 2806 -- MC
CONFIG.platformDBID66 = 2162 -- SA-15
CONFIG.platformDBID67 = 430  -- M977
CONFIG.platformDBID68 = 2034 -- 悍馬車
CONFIG.platformDBID69 = 236  -- ZBD-04
CONFIG.platformDBID70 = 245  -- ZTZ-96A
CONFIG.platformDBID71 = 4122 -- bridge
CONFIG.platformDBID72 = 4925 -- Barge
CONFIG.platformDBID73 = 2155 -- Kidd
CONFIG.platformDBID74 = 4149 -- Kang Ding
CONFIG.platformDBID75 = 906  -- S-70C
CONFIG.platformDBID76 = 7136 -- H-6N
CONFIG.platformDBID77 = 665  -- 093B
CONFIG.platformDBID78 = 177  -- Bunker (Sector Control Station)

CONFIG.sensorDBID1 = 2788    -- S-300 Tombstone
CONFIG.sensorDBID2 = 4155    -- S-400 Grave Stone
CONFIG.sensorDBID3 = 3396    -- HQ-12 China H-200
CONFIG.sensorDBID4 = 6123    -- HQ-22 China H-200 Improved
CONFIG.sensorDBID5 = 3204    -- S-300 Cheese Board
CONFIG.sensorDBID6 = 5054    -- S-400 Cheese Board
CONFIG.sensorDBID7 = 6847    -- P-3C SeaVue
CONFIG.sensorDBID8 = 2938    -- E-2K
CONFIG.sensorDBID9 = 6366    -- TK-3
CONFIG.sensorDBID10 = 282    -- TK-3
CONFIG.sensorDBID11 = 919    -- TK-2
CONFIG.sensorDBID12 = 2498   -- PAC-3
CONFIG.sensorDBID13 = 2539   -- GPS Jammer
CONFIG.sensorDBID14 = 6381   -- TC-2


CONFIG.loadoutDBID1 = 30568 -- ka-52
CONFIG.loadoutDBID2 = 31490 -- z-10
CONFIG.loadoutDBID3 = 18367 -- z-18
CONFIG.loadoutDBID4 = 18365 -- z-18
CONFIG.loadoutDBID5 = 25504 -- II-76
CONFIG.loadoutDBID6 = 27825 -- GJ-11


CONFIG.radarDistance = 70
CONFIG.readytime = 3600 * 1.5
---@enum CONFIG.batteryState
--- Battery states for the ground units
CONFIG.batteryState = {
  STATIC = 0,
  REPOSITIONING = 1,
  RELOAD = 2,
  HIDE = 3,
}

--Setup start time
CONFIG.c.triggers = {
  ['(China) (Amphibious ops) start time'] = { startTime = '2027-06-09 02:40:00' },
  -- ['(China) (Amphibious ops) start time'] = { startTime = '2027-06-09 1:00:00' },
  ['(China) (Surface/LACM) start time'] = { startTime = '2027-06-09 06:00:00' },
  ['(China) (Sub-surface/SLCM) start time'] = { startTime = '2027-06-09 06:30:00' },
}


-- SIGINT
-- CONFIG.c.SIGINT.maxCount = 6
CONFIG.c.SIGINT.maxCount = 1
CONFIG.c.SIGINT.maxRange = 2.5

-- IADS
CONFIG.c.IADS.ratio = { C2 = 1.5, }
CONFIG.c.IADS.C2FacilityDBIDs = { 319, 318, 115, 113 }
CONFIG.c.IADS.randomRadius = 10
CONFIG.c.IADS.C2Settings = {
  {
    position = { lat = "N 25.30.05", lon = "E 119.30.41" },
    areas = { CONFIG.c.areas["OPAREA/FUZHOU"], },
    areaName = 'Fuzhou'
  },
  {
    position = { lat = "N 25.19.12", lon = "E 119.06.36" },
    areas = { CONFIG.c.areas["OPAREA/PUTIAN"], },
    areaName = 'Putian'
  },
  {
    position = { lat = "N 24.57.01", lon = "E 118.34.22" },
    areas = { CONFIG.c.areas["OPAREA/CHANGZHOU"], },
    areaName = 'Changzhou'
  },
  {
    position = { lat = "N 24.43.19", lon = "E 118.12.29" },
    areas = { CONFIG.c.areas["OPAREA/XIAMEN"], },
    areaName = 'Xiamen'
  },
  {
    position = { lat = "N 24.10.12", lon = "E 117.28.46" },
    areas = { CONFIG.c.areas["OPAREA/ZHANGZHOU"], },
    areaName = 'Zhangzhou'
  },
  {
    position = { lat = "N 23.39.17", lon = "E 116.41.26" },
    areas = { CONFIG.c.areas["OPAREA/SHANTOU"], },
    areaName = 'Shantou'
  },
  {
    position = { lat = "N 23.08.19", lon = "E 115.22.49" },
    areas = { CONFIG.c.areas["OPAREA/SHANWEI"], },
    areaName = 'Shanwei'
  },
  {
    position = { lat = "N 23.55.21", lon = "E 115.36.40" },
    areas = { CONFIG.c.areas["OPAREA/MEIZHOU"], },
    areaName = 'Meizhou'
  },
}

-- Comms Jamming
CONFIG.c.commsJamming.limit = 12
CONFIG.c.commsJamming.range = 150
CONFIG.c.commsJamming.initialComms = -20

-- GPS Jamming
CONFIG.c.GPSJamming.jammers = {
  { zoneName = 'JAMMING ZONE/1', name = '1st Bn, 1st ECM Bde', point = { lat = 'N 25.28.17', lon = 'E 119.35.17' }, randomRadius = 20, radius = 14 },
  { zoneName = 'JAMMING ZONE/2', name = '2nd Bn, 1st ECM Bde', point = { lat = 'N 24.43.49', lon = 'E 118.29.41' }, randomRadius = 20, radius = 14 },
}

-- MLRS
CONFIG.c.ground.mlrs.wpnDefault = 192
CONFIG.c.ground.mlrs.ammoThreshold = 50
CONFIG.c.ground.mlrs.positions = {
  pingtan = {
    RL = {
      course = {
        { lat = 'N 25.30.20', lon = 'E 119.46.50', desiredSpeed = 30, presetThrottle = 'Flank' },
        { lat = 'N 25.30.13', lon = 'E 119.47.36', desiredSpeed = 30, presetThrottle = 'Flank' },
      },
      area = CONFIG.c.areas["RL/PINGTAN"]
    },
    HA = {
      course = {
        { lat = 'N 25.30.02', lon = 'E 119.47.17', desiredSpeed = 30, presetThrottle = 'Flank' },
      },
      area = CONFIG.c.areas["HA/PINGTAN"]
    },
    FP = {
      {
        course = {
          { lat = 'N 25.30.20', lon = 'E 119.46.50', desiredSpeed = 30, presetThrottle = 'Flank' },
          { lat = 'N 25.25.45', lon = 'E 119.44.25', desiredSpeed = 30, presetThrottle = 'Flank' },
        },
        area = CONFIG.c.areas["FP1/PINGTAN"]
      },
      {
        course = {
          { lat = 'N 25.30.20', lon = 'E 119.46.50', desiredSpeed = 30, presetThrottle = 'Flank' },
          { lat = 'N 25.27.22', lon = 'E 119.45.39', desiredSpeed = 30, presetThrottle = 'Flank' },
        },
        area = CONFIG.c.areas["FP2/PINGTAN"]
      },
    },
    AHA = {
      course = {
        { lat = 'N 25.30.31', lon = 'E 119.47.37', desiredSpeed = 30, presetThrottle = 'Flank' },
      },
      area = CONFIG.c.areas["AHA/PINGTAN"]
    },
  },
  chinchew = {
    RL = {
      course = {
        { lat = 'N 24.46.44', lon = 'E 118.40.37', desiredSpeed = 30, presetThrottle = 'Flank' },
        { lat = 'N 24.46.36', lon = 'E 118.42.17', desiredSpeed = 30, presetThrottle = 'Flank' },
      },
      area = CONFIG.c.areas["RL/CHINCHEW"]
    },
    HA = {
      course = {
        { lat = 'N 24.46.31', lon = 'E 118.41.51', desiredSpeed = 30, presetThrottle = 'Flank' },
      },
      area = CONFIG.c.areas["HA/CHINCHEW"]
    },
    FP = {
      {
        course = {
          { lat = 'N 24.46.44', lon = 'E 118.40.37', desiredSpeed = 30, presetThrottle = 'Flank' },
          { lat = 'N 24.41.45', lon = 'E 118.43.18', desiredSpeed = 30, presetThrottle = 'Flank' },
        },
        area = CONFIG.c.areas["FP1/CHINCHEW"]
      },
    },
    AHA = {
      course = {
        { lat = 'N 24.47.10', lon = 'E 118.42.22', desiredSpeed = 30, presetThrottle = 'Flank' },
      },
      area = CONFIG.c.areas["AHA/CHINCHEW"]
    },
  },
}
CONFIG.c.ground.mlrs.contactAge = 30 * 60
CONFIG.c.ground.mlrs.reloadTime = 30 * 60

-- GLCM
CONFIG.c.ground.glcm.wpnDefault = 48
CONFIG.c.ground.glcm.ammoThreshold = 50
CONFIG.c.ground.glcm.positions = {
  brigade635 = {
    RL = {
      course = {
        { lat = 'N 24.46.44', lon = 'E 118.40.37', desiredSpeed = 30, presetThrottle = 'Flank' },
        { lat = 'N 24.46.36', lon = 'E 118.42.17', desiredSpeed = 30, presetThrottle = 'Flank' },
      },
      area = CONFIG.c.areas["RL/CHINCHEW"]
    },
    HA = {
      course = {
        { lat = 'N 24.46.31', lon = 'E 118.41.51', desiredSpeed = 30, presetThrottle = 'Flank' },
      },
      area = CONFIG.c.areas["HA/CHINCHEW"]
    },
    FP = {
      {
        course = {
          { lat = 'N 24.46.44', lon = 'E 118.40.37', desiredSpeed = 30, presetThrottle = 'Flank' },
          { lat = 'N 24.41.45', lon = 'E 118.43.18', desiredSpeed = 30, presetThrottle = 'Flank' },
        },
        area = CONFIG.c.areas["FP1/CHINCHEW"]
      },
    },
    AHA = {
      course = {
        { lat = 'N 24.47.10', lon = 'E 118.42.22', desiredSpeed = 30, presetThrottle = 'Flank' },
      },
      area = CONFIG.c.areas["AHA/CHINCHEW"]
    },
  },
}
CONFIG.c.ground.glcm.contactAge = 30 * 60
CONFIG.c.ground.glcm.reloadTime = 45 * 60

-- SRBM
CONFIG.c.ground.srbm.wpnDefault = 36
CONFIG.c.ground.srbm.ammoThreshold = 35
CONFIG.c.ground.srbm.positions = {
  brigade615 = {
    RL = {
      course = {
        { lat = 'N 24.17.32', lon = 'E 115.58.09', desiredSpeed = 30, presetThrottle = 'Flank' },
        { lat = 'N 24.16.56', lon = 'E 115.58.12', desiredSpeed = 30, presetThrottle = 'Flank' },
      },
      area = CONFIG.c.areas["RL/BRIGADE615"]
    },
    HA = {
      course = {
        { lat = 'N 24.17.06', lon = 'E 115.58.35', desiredSpeed = 30, presetThrottle = 'Flank' },
      },
      area = CONFIG.c.areas["HA/BRIGADE615"]
    },
    FP = {
      {
        course = {
          { lat = 'N 24.17.32', lon = 'E 115.58.09', desiredSpeed = 30, presetThrottle = 'Flank' },
          { lat = 'N 24.17.05', lon = 'E 115.59.41', desiredSpeed = 30, presetThrottle = 'Flank' },
        },
        area = CONFIG.c.areas["FP1/BRIGADE615"]
      },
    },
    AHA = {
      course = {
        { lat = 'N 24.17.05', lon = 'E 115.58.00', desiredSpeed = 30, presetThrottle = 'Flank' },
      },
      area = CONFIG.c.areas["AHA/BRIGADE615"]
    },
  },
  brigade614 = {
    RL = {
      course = {
        { lat = 'N 26.04.01', lon = 'E 117.18.55', desiredSpeed = 30, presetThrottle = 'Flank' },
        { lat = 'N 26.03.40', lon = 'E 117.18.55', desiredSpeed = 30, presetThrottle = 'Flank' },
      },
      area = CONFIG.c.areas["RL/BRIGADE614"]
    },
    HA = {
      course = {
        { lat = 'N 26.03.48', lon = 'E 117.19.11', desiredSpeed = 30, presetThrottle = 'Flank' },
      },
      area = CONFIG.c.areas["HA/BRIGADE614"]
    },
    FP = {
      {
        course = {
          { lat = 'N 26.04.18', lon = 'E 117.18.51', desiredSpeed = 30, presetThrottle = 'Flank' },
          { lat = 'N 26.03.49', lon = 'E 117.20.05', desiredSpeed = 30, presetThrottle = 'Flank' },
        },
        area = CONFIG.c.areas["FP1/BRIGADE614"]
      },
    },
    AHA = {
      course = {
        { lat = 'N 26.03.47', lon = 'E 117.18.50', desiredSpeed = 30, presetThrottle = 'Flank' },
      },
      area = CONFIG.c.areas["AHA/BRIGADE614"]
    },
  },
  brigade636 = {
    RL = {
      course = {
        { lat = 'N 24.45.52', lon = 'E 113.40.52', desiredSpeed = 30, presetThrottle = 'Flank' },
        { lat = 'N 24.45.25', lon = 'E 113.40.29', desiredSpeed = 30, presetThrottle = 'Flank' },
      },
      area = CONFIG.c.areas["RL/BRIGADE636"]
    },
    HA = {
      course = {
        { lat = 'N 24.45.33', lon = 'E 113.40.47', desiredSpeed = 30, presetThrottle = 'Flank' },
      },
      area = CONFIG.c.areas["HA/BRIGADE636"]
    },
    FP = {
      {
        course = {
          { lat = 'N 24.45.52', lon = 'E 113.40.52', desiredSpeed = 30, presetThrottle = 'Flank' },
          { lat = 'N 24.45.52', lon = 'E 113.41.35', desiredSpeed = 30, presetThrottle = 'Flank' },
        },
        area = CONFIG.c.areas["FP1/BRIGADE636"]
      },
    },
    AHA = {
      course = {
        { lat = 'N 24.45.34', lon = 'E 113.40.14', desiredSpeed = 30, presetThrottle = 'Flank' },
      },
      area = CONFIG.c.areas["AHA/BRIGADE636"]
    },
  },
  brigade616 = {
    RL = {
      course = {
        { lat = 'N 25.54.31', lon = 'E 114.57.21', desiredSpeed = 30, presetThrottle = 'Flank' },
      },
      area = CONFIG.c.areas["RL/BRIGADE616"]
    },
    HA = {
      course = {
        { lat = 'N 25.54.40', lon = 'E 114.57.42', desiredSpeed = 30, presetThrottle = 'Flank' },
      },
      area = CONFIG.c.areas["HA/BRIGADE616"]
    },
    FP = {
      {
        course = {
          { lat = 'N 25.55.33', lon = 'E 114.58.25', desiredSpeed = 30, presetThrottle = 'Flank' },
        },
        area = CONFIG.c.areas["FP1/BRIGADE616"]
      },
    },
    AHA = {
      course = {
        { lat = 'N 25.54.38', lon = 'E 114.57.06', desiredSpeed = 30, presetThrottle = 'Flank' },
      },
      area = CONFIG.c.areas["AHA/BRIGADE616"]
    },
  },
  brigade613 = {
    RL = {
      course = {
        { lat = 'N 28.27.25', lon = 'E 117.51.51', desiredSpeed = 30, presetThrottle = 'Flank' },
        { lat = 'N 28.27.26', lon = 'E 117.51.02', desiredSpeed = 30, presetThrottle = 'Flank' },
        { lat = 'N 28.27.03', lon = 'E 117.51.04', desiredSpeed = 30, presetThrottle = 'Flank' },
      },
      area = CONFIG.c.areas["RL/BRIGADE613"]
    },
    HA = {
      course = {
        { lat = 'N 28.27.12', lon = 'E 117.51.17', desiredSpeed = 30, presetThrottle = 'Flank' },
      },
      area = CONFIG.c.areas["HA/BRIGADE613"]
    },
    FP = {
      {
        course = {
          { lat = 28.455760146701, lon = 117.85790803852, desiredSpeed = 30, presetThrottle = 'Flank' },
          { lat = 28.455941652975, lon = 117.86516402324, desiredSpeed = 30, presetThrottle = 'Flank' },
          { lat = 28.443410902986, lon = 117.86719441616, desiredSpeed = 30, presetThrottle = 'Flank' },
        },
        area = CONFIG.c.areas["FP1/BRIGADE613"]
      },
    },
    AHA = {
      course = {
        { lat = 'N 28.27.12', lon = 'E 117.50.55', desiredSpeed = 30, presetThrottle = 'Flank' },
      },
      area = CONFIG.c.areas["AHA/BRIGADE613"]
    },
  },
  brigade617 = {
    RL = {
      course = {
        { lat = 'N 29.09.32', lon = 'E 119.36.38', desiredSpeed = 30, presetThrottle = 'Flank' },
        { lat = 'N 29.08.57', lon = 'E 119.36.31', desiredSpeed = 30, presetThrottle = 'Flank' },
      },
      area = CONFIG.c.areas["RL/BRIGADE617"]
    },
    HA = {
      course = {
        { lat = 'N 29.09.01', lon = 'E 119.36.49', desiredSpeed = 30, presetThrottle = 'Flank' },
      },
      area = CONFIG.c.areas["HA/BRIGADE617"]
    },
    FP = {
      {
        course = {
          { lat = 29.158533243915, lon = 119.61541712539, desiredSpeed = 30, presetThrottle = 'Flank' },
          { lat = 29.158295428459, lon = 119.62849131226, desiredSpeed = 30, presetThrottle = 'Flank' },
        },
        area = CONFIG.c.areas["FP1/BRIGADE617"]
      },
    },
    AHA = {
      course = {
        { lat = 'N 29.09.03', lon = 'E 119.36.26', desiredSpeed = 30, presetThrottle = 'Flank' },
      },
      area = CONFIG.c.areas["AHA/BRIGADE617"]
    },
  },
}
CONFIG.c.ground.srbm.contactAge = 30 * 60
CONFIG.c.ground.srbm.reloadTime = 5 * 60

-- MRBM
CONFIG.c.ground.mrbm.wpnDefault = 24
CONFIG.c.ground.mrbm.ammoThreshold = 35
CONFIG.c.ground.mrbm.positions = {
  brigade624 = {
    RL = {
      course = {
        { lat = 'N 19.29.01', lon = 'E 109.26.40', desiredSpeed = 30, presetThrottle = 'Flank' },
        { lat = 'N 19.28.27', lon = 'E 109.26.56', desiredSpeed = 30, presetThrottle = 'Flank' },
        { lat = 'N 19.28.29', lon = 'E 109.27.44', desiredSpeed = 30, presetThrottle = 'Flank' },
      },
      area = CONFIG.c.areas["RL/BRIGADE624"]
    },
    HA = {
      course = {
        { lat = 'N 19.28.35', lon = 'E 109.27.22', desiredSpeed = 30, presetThrottle = 'Flank' },
      },
      area = CONFIG.c.areas["HA/BRIGADE624"]
    },
    FP = {
      {
        course = {
          { lat = 'N 19.29.01', lon = 'E 109.26.40', desiredSpeed = 30, presetThrottle = 'Flank' },
          { lat = 'N 19.29.40', lon = 'E 109.27.17', desiredSpeed = 30, presetThrottle = 'Flank' },
        },
        area = CONFIG.c.areas["FP1/BRIGADE624"]
      },
    },
    AHA = {
      course = {
        { lat = 'N 19.28.12', lon = 'E 109.27.21', desiredSpeed = 30, presetThrottle = 'Flank' },
      },
      area = CONFIG.c.areas["AHA/BRIGADE624"]
    },
  },
}
CONFIG.c.ground.mrbm.contactAge = 15 * 60
CONFIG.c.ground.mrbm.reloadTime = 5 * 60


-- Recon
CONFIG.c.recon.bases = {
  H6N = { guid = 'X58F5H-0HMRAQFR07T2V' },
  BZK005 = { guid = '6Z8LM5-0HMIJ3QGCRQC4' }
}
CONFIG.c.recon.contactAge = 15 * 60
CONFIG.c.recon.courses = {
  WZ8 = {
    {
      { lat = 'N 25.53.18', lon = 'E 121.32.54', desiredAltitude = 30480, desiredSpeed = 3300 },
      { lat = 'N 24.58.25', lon = 'E 121.41.17', desiredAltitude = 30480, desiredSpeed = 3300 },
      { lat = 'N 24.38.39', lon = 'E 121.41.42', desiredAltitude = 30480, desiredSpeed = 3300 },
      { lat = 'N 24.05.04', lon = 'E 121.22.33', desiredAltitude = 30480, desiredSpeed = 3300 },
      { lat = 'N 22.52.27', lon = 'E 121.06.41', desiredAltitude = 30480, desiredSpeed = 3300 },
      { lat = 'N 22.31.53', lon = 'E 120.29.25', desiredAltitude = 30480, desiredSpeed = 3300 },
      { lat = 'N 23.21.08', lon = 'E 120.19.55', desiredAltitude = 30480, desiredSpeed = 3300 },
      { lat = 'N 24.16.15', lon = 'E 120.29.30', desiredAltitude = 30480, desiredSpeed = 3300 },
      { lat = 'N 25.09.57', lon = 'E 121.08.54', desiredAltitude = 30480, desiredSpeed = 3300 },
    },
    {
      { lat = 'N 25.08.36', lon = 'E 122.40.26', desiredAltitude = 30480, desiredSpeed = 3300 },
      { lat = 'N 21.21.28', lon = 'E 121.20.36', desiredAltitude = 30480, desiredSpeed = 3300 },
    }
  },
  H6N = {
    { lat = 'N 29.47.52', lon = 'E 119.19.47', desiredAltitude = 13716, desiredSpeed = 450 },
    { lat = 'N 25.57.34', lon = 'E 121.32.45', desiredAltitude = 13716, desiredSpeed = 550 },
  }
}

-- Aircraft deployment
CONFIG.c.air.landBased.deployedACs = {
  {
    name = 'Huizhou Pingtan AB (PLAAF)',
    baseGUID = '6Z8LM5-0HMLLL9B5QBF0',
    embarkedUnits = {
      {
        side = 'China',
        type = 'Air',
        dbid = 3301,
        name = '1st Naval AF Div',
        loadouts = {
          { loadoutId = 27636, num = 3, missionName = 'ASW/PATROL AC' },
        }
      }
    }
  },
  {
    name = 'Shantou Waisha AB (PLAAF)',
    baseGUID = '6Z8LM5-0HMLLEF9H5P44',
    embarkedUnits = {
      {
        side = 'China',
        type = 'Air',
        dbid = 4926,
        name = '7th Air Bde',
        loadouts = {
          { loadoutId = 26233, num = 24 },
        }
      }
    },
    loadouts = {
      { loadoutId = 26233, num = 24 }, --AKD-88 X 2
    }
  },
  {
    name = 'Zhangpu AAB',
    baseGUID = 'X58F5H-0HN00TRR0Q1JQ',
    embarkedUnits = {
      {
        side = 'China',
        type = 'Air',
        dbid = 4652,
        name = '804th Air Bde',
        loadouts = {
          { loadoutId = 25380, num = 12 },
        }
      },
      {
        side = 'China',
        type = 'Air',
        dbid = 4203,
        name = '60th Air Reg',
        loadouts = {
          { loadoutId = 21678, num = 3 },
        }
      },
      {
        side = 'China',
        type = 'Air',
        dbid = 2503,
        name = '39th Air Reg',
        loadouts = {
          { loadoutId = 25504, num = 3 },
        }
      },
      {
        side = 'China',
        type = 'Air',
        dbid = 7064,
        name = '60th Air Reg',
        loadouts = {
          { loadoutId = 33464, num = 3, missionName = 'SIGINT' },
        }
      },
    },
    loadouts = {
      { loadoutId = 25380, num = 12 }, --KAB-1500 X 2
    }
  },
  {
    name = 'Zhangzhou-Longxi AB (PLAAF)',
    baseGUID = '6Z8LM5-0HMIJ3QGCRQ2G',
    embarkedUnits = {
      {
        side = 'China',
        type = 'Air',
        dbid = 4652,
        name = '804th Air Bde',
        loadouts = {
          { loadoutId = 25378, num = 24 },
        }
      }
    },
    loadouts = {
      { loadoutId = 25378, num = 24 }, --YJ-91 X 2
    }
  },
  {
    name = 'Huian AAB',
    baseGUID = '6Z8LM5-0HMIJ3QGCRQ5F',
    embarkedUnits = {
      {
        side = 'China',
        type = 'Air',
        dbid = 4926,
        name = '40th Air Bde',
        loadouts = {
          { loadoutId = 26233, num = 12 },
        }
      },
      {
        side = 'China',
        type = 'Air',
        dbid = 5014,
        name = '41st Air Bde',
        loadouts = {
          { loadoutId = 28027, num = 12, missionName = 'CAP/W' },
        }
      },
    },
    loadouts = {
      { loadoutId = 28027, num = 12 }, --PL-15 X 4
      { loadoutId = 26233, num = 12 }, --AKD-88 X 2
    }
  },
  {
    name = 'Longtian AAB',
    baseGUID = '6Z8LM5-0HMIJ3QGCRQC4',
    embarkedUnits = {
      {
        side = 'China',
        type = 'Air',
        dbid = 3309,
        name = 'PLARF UAV Reg',
        loadouts = {
          { loadoutId = 17495, num = 6 },
        }
      },
      {
        side = 'China',
        type = 'Air',
        dbid = 4652,
        name = '804th Air Bde',
        loadouts = {
          { loadoutId = 25378, num = 8 },
        }
      }
    },
    loadouts = {
      { loadoutId = 25378, num = 8 }, --YJ-91 X 2
    }
  },
  {
    name = 'Xingning AB (PLAAF)',
    baseGUID = '6Z8LM5-0HMLLEF9H7VDF',
    embarkedUnits = {
      {
        side = 'China',
        type = 'Air',
        dbid = 1731,
        name = '29th Air Reg',
        loadouts = {
          { loadoutId = 33615, num = 12 },
        }
      }
    },
    loadouts = {
      { loadoutId = 33615, num = 12 }, --YJ-63 X 4
    }
  },
  {
    name = 'Shuimen AAB (PLAAF)',
    baseGUID = '6Z8LM5-0HMMJDEFRFJ4V',
    embarkedUnits = {
      {
        side = 'China',
        type = 'Air',
        dbid = 4652,
        name = '804th Air Bde',
        loadouts = {
          { loadoutId = 25378, num = 8 },
        }
      },
      {
        side = 'China',
        type = 'Air',
        dbid = 4926,
        name = '40th Air Bde',
        loadouts = {
          { loadoutId = 21743, num = 8 },
        }
      },
      {
        side = 'China',
        type = 'Air',
        dbid = 3683,
        name = '75th Air Reg',
        loadouts = {
          { loadoutId = 18300, num = 3, missionName = 'AEW/N' },
        }
      },
      {
        side = 'China',
        type = 'Air',
        dbid = 823,
        name = '23rd Air Reg',
        loadouts = {
          { loadoutId = 8811, num = 3, missionName = 'AAR' },
        }
      },
      {
        side = 'China',
        type = 'Air',
        dbid = 7419,
        name = '25th Air Bde',
        loadouts = {
          { loadoutId = 25595, num = 8 },
        }
      },
    },
    loadouts = {
      { loadoutId = 25378, num = 8 }, --YJ-91 X 2
      { loadoutId = 21743, num = 8 }, --YJ-83 X 2
      { loadoutId = 25595, num = 8 }, --LS-6-500 X 2
    }
  },
  {
    name = 'Anqing AB (PLAAF)',
    baseGUID = '6Z8LM5-0HMIJ7B8971MA',
    embarkedUnits = {
      {
        side = 'China',
        type = 'Air',
        dbid = 1731,
        name = '28th Air Reg',
        loadouts = {
          { loadoutId = 33615, num = 12 },
        }
      }
    },
    loadouts = {
      { loadoutId = 33615, num = 12 }, --YJ-63 X 4
    }
  },
  {
    name = 'Wuhu AB (PLAAF)',
    baseGUID = '6Z8LM5-0HMIJ7B896RA9',
    embarkedUnits = {
      {
        side = 'China',
        type = 'Air',
        dbid = 5014,
        name = '9th Air Bde',
        loadouts = {
          { loadoutId = 28027, num = 12 },
        }
      }
    },
    loadouts = {
      { loadoutId = 28027, num = 12 }, --PL-15 X 4
    }
  },
  {
    name = 'Liuan AB',
    baseGUID = 'X58F5H-0HMRAQFR07T2V',
    embarkedUnits = {
      {
        side = 'China',
        type = 'Air',
        dbid = 7136,
        name = '107th Air Reg',
        loadouts = {
          { loadoutId = 8792, num = 4 },
        }
      }
    }
  },
}

-- Amphibious ops
CONFIG.c.PHIBOP.periodOfTime = 5 * 60
---@class CargoItem:table
---@field type number
---@field num number
---@field dbid number

CONFIG.c.PHIBOP.cargoList = {
  ---@type table<number, CargoItem>
  type075 = {
    ---@type CargoItem
    { type = 2, num = 21, dbid = CONFIG.platformDBID60 }, -- PLL-05 11
    { type = 2, num = 12, dbid = CONFIG.platformDBID61 }, -- PLZ-96 12
    { type = 3, num = 3,  dbid = CONFIG.platformDBID62 }, -- PGZ-09 3
    { type = 3, num = 1,  dbid = CONFIG.platformDBID63 }, -- PGZ-95 1
    { type = 3, num = 30, dbid = CONFIG.platformDBID68 }, -- 悍馬車 30
    { type = 3, num = 76, dbid = CONFIG.platformDBID65 }, -- MC 76
  },
  ---@type table<number, CargoItem>
  type071 = {
    { type = 2, num = 5,  dbid = CONFIG.platformDBID60 }, -- PLL-05 11
    { type = 2, num = 12, dbid = CONFIG.platformDBID61 }, -- PLZ-96 12
    { type = 3, num = 3,  dbid = CONFIG.platformDBID62 }, -- PGZ-09 3
    { type = 3, num = 1,  dbid = CONFIG.platformDBID63 }, -- PGZ-95 1
    { type = 3, num = 2,  dbid = CONFIG.platformDBID66 }, -- SA-15 2
    { type = 3, num = 22, dbid = CONFIG.platformDBID65 }  -- MC
  },
  ---@type table<number, CargoItem>
  type072iii = {
    { type = 2, num = 5, dbid = CONFIG.platformDBID58 }, -- ZBD-05
    { type = 2, num = 5, dbid = CONFIG.platformDBID59 }, -- ZTD-05
    { type = 3, num = 6, dbid = CONFIG.platformDBID65 }
  },
  ---@type table<number, CargoItem>
  type072a = {
    { type = 2, num = 5, dbid = CONFIG.platformDBID58 }, -- ZBD-05
    { type = 2, num = 5, dbid = CONFIG.platformDBID59 }, -- ZTD-05
    { type = 3, num = 6, dbid = CONFIG.platformDBID65 }
  },
  ---@type table<number, CargoItem>
  type073a = {
    { type = 2, num = 3, dbid = CONFIG.platformDBID58 },
    { type = 2, num = 3, dbid = CONFIG.platformDBID59 }, -- ZTD-05
  },
  ---@type table<number, CargoItem>
  ferry = {
    { type = 2, num = 56, dbid = CONFIG.platformDBID58 }, -- ZBD-05
    { type = 2, num = 56, dbid = CONFIG.platformDBID59 }, -- ZTD-05
  },
  ---@type table<number, CargoItem>
  barge = {
    { type = 2, num = 28, dbid = CONFIG.platformDBID69 }, -- ZBD-04
    { type = 2, num = 28, dbid = CONFIG.platformDBID70 }, -- ZTZ-96A
    { type = 2, num = 9,  dbid = CONFIG.platformDBID60 }, -- PLL-05
    { type = 3, num = 2,  dbid = CONFIG.platformDBID63 }, -- PGZ-95
    { type = 3, num = 1,  dbid = CONFIG.platformDBID62 }, -- PGZ-09
    { type = 2, num = 7,  dbid = CONFIG.platformDBID61 }, -- PLZ-07/PLZ-96
    { type = 3, num = 1,  dbid = CONFIG.platformDBID66 }, -- SA-15
    { type = 2, num = 4,  dbid = CONFIG.platformDBID67 }, -- M977
  }
}
CONFIG.c.PHIBOP.cargoListForTransfer = {
  boat = {
    { type = 2, num = 1, dbid = CONFIG.platformDBID58 }, -- ZBD-05
    { type = 2, num = 1, dbid = CONFIG.platformDBID59 }, -- ZTD-05
  },
  assultLandingGroup = {
    { type = 2, num = 4, dbid = CONFIG.platformDBID60 }, -- PLL-05
    -- 突擊上陸群
  },
  deepAssaultGroup1 = {
    { type = 2, num = 1, dbid = CONFIG.platformDBID61 }, -- PLZ-96
    { type = 3, num = 1, dbid = CONFIG.platformDBID62 }, -- PGZ-09
    -- 縱深突擊群
  },
  deepAssaultGroup2 = {
    { type = 2, num = 1, dbid = CONFIG.platformDBID61 }, -- PLZ-96
    { type = 3, num = 1, dbid = CONFIG.platformDBID63 }, -- PGZ-95
    -- 縱深突擊群
  },
  deepAssaultGroup3 = {
    { type = 3, num = 1, dbid = CONFIG.platformDBID66 }, -- SA-15
    -- 縱深突擊群
  },
  airAssaultGroup1 = {
    { type = 3, num = 2, dbid = CONFIG.platformDBID65 }, -- MC -- 075/071 Z-18
  },
  airAssaultGroup2 = {
    { type = 3, num = 1, dbid = CONFIG.platformDBID68 }, -- 悍馬車
  },
  airAssaultGroup3 = {
    { type = 2, num = 3, dbid = CONFIG.platformDBID39 }, -- II-76 ZBD-03
  },
}
CONFIG.c.PHIBOP.missionStartime = {
  transportHelicopter = { 42 * 60, 72 * 60, 92 * 60, 112 * 60 },
  attackHelicopter = { 40 * 60, },
  boat = { 41 * 60, 61 * 60, },
  reconUAV = { 0 }
}
CONFIG.c.PHIBOP.shipSettings = {
  distanceBetweenLSTAndLPDArea = 13,
  horizontalDistance = 0.4,
  verticalDistance = 0.4,
  transitDistance = 13,
  shipSpeed = 14,
  heading = {
    north = {
      horizontal  = 220 - 90,
      vertical    = 220,
      destination = {
        { lat = 'N 25.04.44', lon = 'E 121.13.54', },
      }
    },
    west = {
      horizontal = 150 - 90,
      vertical = 150,
      destination = {
        { lat = 'N 25.04.52', lon = 'E 121.10.05', },
        { lat = 'N 25.04.44', lon = 'E 121.13.54', },
      }
    },
    south = {
      horizontal = 45 - 90,
      vertical = 45,
      destination = {
        { lat = 'N 25.04.44', lon = 'E 121.13.54', },
      }
    },
    penghu = {
      horizontal = 82 - 90,
      vertical = 82,
      destination = {
        { lat = 'N 23.31.00', lon = 'E 119.33.54', },
        { lat = 'N 23.31.35', lon = 'E 119.35.36', },
        { lat = 'N 23.34.09', lon = 'E 119.37.41', },
      }
    },
    sishu = {
      horizontal = 73 - 90,
      vertical = 73,
      destination = {
        { lat = 'N 22.56.39', lon = 'E 120.10.37', },
        { lat = 'N 22.57.14', lon = 'E 120.12.09', },
      }
    },
  },
  ACVSpeed = 8,
  ACVTransitDistance = 5,
  ACVHorizontalDistance = 0.05,
}
CONFIG.c.PHIBOP.initialLocations = {
  {
    name = 'Taoyuan',
    names = {
      'Air Assault Bn',
      'Combined Arms Bn',
      '5th Landing Ship Div'
    },
    from = {
      areas = { {
        startingPoints = { type075 = { side = "China", area = CONFIG.c.areas["STARTING POINT/075/TAOYUAN"] } },
        heading = CONFIG.c.PHIBOP.shipSettings.heading.north
      } },
      stagingArea = CONFIG.c.areas["OPAREA/D"],
      num = {
        type075 = 2,
        type071 = 4,
        type076 = 1,
        type072iii = 7,
        type072a = 8,
        type073a = 7,
        ferry = 4,
        roro = 2,
        barge = 1,
      }
    },
    to = {
      areas = {
        {
          startingPoints = {
            type075 = { side = "China", area = CONFIG.c.areas["DESTINATION/075/TAOYUAN"] },
            type071 = { side = "China", area = CONFIG.c.areas["DESTINATION/071/TAOYUAN"] },
          },
          heading = CONFIG.c.PHIBOP.shipSettings.heading.west,
          num = {
            type075 = 2,
            type071 = 4,
            type076 = 1,
            type072iii = 7,
            type072a = 8,
            type073a = 7,
            type071InLSTArea = 0,
            ferry = 4,
            roro = 2,
            barge = 1,
          }
        },
      }
    },
    airLandingZone = CONFIG.c.areas["AIRLANDING/TAOYUAN"],
    numOfContactsInAirLandingZone = 3
  },
  {
    name = 'Sishu',
    names = {
      'Air Assault Bn',
      'Combined Arms Bn',
      '5th Landing Ship Div'
    },
    from = {
      areas = { {
        startingPoints = { type075 = { side = "China", area = CONFIG.c.areas["STARTING POINT/075/SISHU"] } },
        heading = CONFIG.c.PHIBOP.shipSettings.heading.sishu
      } },
      stagingArea = CONFIG.c.areas["OPAREA/F"],
      num = {
        type075 = 1,
        type071 = 3,
        type076 = 0,
        type072iii = 2,
        type072a = 4,
        type073a = 2,
        type071InLSTArea = 0,
        ferry = 4,
        roro = 2,
        barge = 1,
      }
    },
    to = {
      areas = {
        {
          startingPoints = {
            type075 = { side = "China", area = CONFIG.c.areas["DESTINATION/075/SISHU"] },
            type071 = { side = "China", area = CONFIG.c.areas["DESTINATION/071/SISHU"] },
          },
          heading = CONFIG.c.PHIBOP.shipSettings.heading.sishu,
          num = {
            type075 = 1,
            type071 = 3,
            type076 = 0,
            type072iii = 2,
            type072a = 4,
            type073a = 2,
            type071InLSTArea = 0,
            ferry = 4,
            roro = 2,
            barge = 1,
          }
        },
      }
    },
    airLandingZone = CONFIG.c.areas["AIRLANDING/TAOYUAN"],
    numOfContactsInAirLandingZone = 3
  },
  {
    name = 'Penghu',
    names = {
      'Air Assault Bn',
      'Combined Arms Bn',
      '5th Landing Ship Div'
    },
    from = {
      areas = { {
        startingPoints = { type075 = { side = "China", area = CONFIG.c.areas["STARTING POINT/075/PENGHU"] } },
        heading = CONFIG.c.PHIBOP.shipSettings.heading.penghu
      } },
      stagingArea = CONFIG.c.areas["OPAREA/E"],
      num = {
        type075 = 1,
        type071 = 1,
        type076 = 0,
        type072iii = 2,
        type072a = 3,
        type073a = 1,
        type071InLSTArea = 0,
        ferry = 0,
        roro = 0,
        barge = 0,
      }
    },
    to = {
      areas = {
        {
          startingPoints = {
            type075 = { side = "China", area = CONFIG.c.areas["DESTINATION/075/PENGHU"] },
            type071 = { side = "China", area = CONFIG.c.areas["DESTINATION/071/PENGHU"] },
          },
          heading = CONFIG.c.PHIBOP.shipSettings.heading.penghu,
          num = {
            type075 = 1,
            type071 = 1,
            type076 = 0,
            type072iii = 2,
            type072a = 3,
            type073a = 1,
            type071InLSTArea = 0,
            ferry = 0,
            roro = 0,
            barge = 0,
          }
        },
      }
    },
    airLandingZone = CONFIG.c.areas["AIRLANDING/TAOYUAN"],
    numOfContactsInAirLandingZone = 3
  },

}
---@type SBJ__OperationalZone[]
CONFIG.c.PHIBOP.operationalZones = {
  {
    name = 'Taoyuan',
    baseGUID = '6Z8LM5-0HMMNGU6J8P2N',
    anchorageArea = CONFIG.c.areas["ANCH AREA/TAOYUAN"],
    LSTAnchorageArea = CONFIG.c.areas["LST ANCH AREA/TAOYUAN"],
    area = CONFIG.c.areas["CAS/E"],
    offloadArea = CONFIG.c.areas["OFFLOAD AREA/TAOYUAN"],
    boat = {
      dbid = CONFIG.platformDBID1,
      missions = {
        {
          name = 'LANDING/TAO/1/1',
          loadoutId = 0,
          num = 1,
          startTime = CONFIG.c.PHIBOP.missionStartime.boat[1],
        },
        {
          name = 'LANDING/TAO/1/2',
          loadoutId = 0,
          num = 3,
          startTime = CONFIG.c.PHIBOP.missionStartime.boat[2],
        },
      },
      zone = CONFIG.c.areas["LANDING/TAOYUAN"],
      settings = {
        Subtype = 'delivery',
        TransitThrottleShip = 'Full',
        StationThrottleShip = 'Full',
        isactive = false
      },
      cargoItemsForTransfer = {
        type075 = {
          {
            loadoutId = 0,
            cargoItems = {
              CONFIG.c.PHIBOP.cargoListForTransfer.assultLandingGroup,
              CONFIG.c.PHIBOP.cargoListForTransfer.deepAssaultGroup1,
              CONFIG.c.PHIBOP.cargoListForTransfer.deepAssaultGroup2,
            }
          },
        },
        type071 = {
          {
            loadoutId = 0,
            cargoItems = {
              CONFIG.c.PHIBOP.cargoListForTransfer.assultLandingGroup,
              CONFIG.c.PHIBOP.cargoListForTransfer.deepAssaultGroup1,
              CONFIG.c.PHIBOP.cargoListForTransfer.deepAssaultGroup2,
              CONFIG.c.PHIBOP.cargoListForTransfer.deepAssaultGroup3,
            }
          },
        }
      },
    },
    tansportHelicopter = {
      dbid = CONFIG.platformDBID2,
      missions = {
        {
          name = 'AIRLANDING/TAO/1/1',
          loadoutId = CONFIG.loadoutDBID3,
          num = 3,
          startTime = CONFIG.c.PHIBOP.missionStartime.transportHelicopter[1],
        },
        {
          name = 'AIRLANDING/TAO/1/2',
          loadoutId = CONFIG.loadoutDBID3,
          num = 3,
          startTime = CONFIG.c.PHIBOP.missionStartime.transportHelicopter[2],
        },
        {
          name = 'AIRLANDING/TAO/2/1',
          loadoutId = CONFIG.loadoutDBID4,
          num = 3,
          startTime = CONFIG.c.PHIBOP.missionStartime.transportHelicopter[3],
        },
        {
          name = 'AIRLANDING/TAO/2/2',
          loadoutId = CONFIG.loadoutDBID4,
          num = 3,
          startTime = CONFIG.c.PHIBOP.missionStartime.transportHelicopter[4],
        },
      },
      zone = CONFIG.c.areas["AIRLANDING/TAOYUAN"],
      settings = {
        Subtype = 'delivery',
        TransitThrottleAircraft = 'Military',
        TransitAltitudeAircraft = 304,
        StationThrottleAircraft = 'Afterburner',
        StationAltitudeAircraft = 304,
        isactive = false
      },
      cargoItemsForTransfer = {
        type075 = {
          {
            loadoutId = CONFIG.loadoutDBID3,
            cargoItems = { CONFIG.c.PHIBOP.cargoListForTransfer.airAssaultGroup1 }

          },
          {
            loadoutId = CONFIG.loadoutDBID4,
            cargoItems = { CONFIG.c.PHIBOP.cargoListForTransfer.airAssaultGroup2 }
          },
        },
        type071 = {
          {
            loadoutId = CONFIG.loadoutDBID3,
            cargoItems = { CONFIG.c.PHIBOP.cargoListForTransfer.airAssaultGroup1 }
          },
        }
      },
    },
    attackHelicopter = {
      dbid = CONFIG.platformDBID5,
      missions = {
        {
          name = 'CAS/E',
          loadoutId = CONFIG.loadoutDBID2,
          num = 13,
          startTime = CONFIG.c.PHIBOP.missionStartime.attackHelicopter[1],
        },
      }
    },
    LSTSettings = {
      speed = CONFIG.c.PHIBOP.shipSettings.shipSpeed,
      course = {
        bearing = CONFIG.c.PHIBOP.shipSettings.heading.west.vertical,
        distance = CONFIG.c.PHIBOP.shipSettings.transitDistance
      }
    },
    ---@type SBJ__ACV
    ACV = {
      bearing = CONFIG.c.PHIBOP.shipSettings.heading.west.horizontal,
      distance = CONFIG.c.PHIBOP.shipSettings.ACVHorizontalDistance,
      speed = CONFIG.c.PHIBOP.shipSettings.ACVSpeed,
      destination = CONFIG.c.PHIBOP.shipSettings.heading.west.destination,
      area = CONFIG.c.areas["AMPH VEH STAGING AREA/TAOYUAN"]
    },
    reconUAV = {
      dbid = CONFIG.platformDBID55,
      missions = {
        {
          name = 'RECON/3',
          loadoutId = CONFIG.loadoutDBID6,
          num = 8,
          startTime = CONFIG.c.PHIBOP.missionStartime.reconUAV[1],
        },
      }
    }
  },
  {
    name = "Sishu",
    baseGUID = '6Z8LM5-0HMJV6AONGLAU',
    anchorageArea = CONFIG.c.areas["ANCH AREA/SISHU"],
    LSTAnchorageArea = CONFIG.c.areas["LST ANCH AREA/SISHU"],
    area = CONFIG.c.areas["CAS/S"],
    offloadArea = CONFIG.c.areas["OFFLOAD AREA/SISHU"],
    boat = {
      dbid = CONFIG.platformDBID1,
      ---@type SBJ__LandingMission[]
      missions = {
        {
          name = 'LANDING/SISHU/1/1',
          loadoutId = 0,
          num = 1,
          startTime = CONFIG.c.PHIBOP.missionStartime.boat[1],
        },
        {
          name = 'LANDING/SISHU/1/2',
          loadoutId = 0,
          num = 3,
          startTime = CONFIG.c.PHIBOP.missionStartime.boat[2],
        },
      },
      zone = CONFIG.c.areas["LANDING/SISHU"],
      settings = {
        Subtype = 'delivery',
        TransitThrottleShip = 'Full',
        StationThrottleShip = 'Full',
        isactive = false
      },
      cargoItemsForTransfer = {
        type075 = {
          {
            loadoutId = 0,
            cargoItems = {
              CONFIG.c.PHIBOP.cargoListForTransfer.assultLandingGroup,
              CONFIG.c.PHIBOP.cargoListForTransfer.deepAssaultGroup1,
              CONFIG.c.PHIBOP.cargoListForTransfer.deepAssaultGroup2,
            }
          },
        },
        type071 = {
          {
            loadoutId = 0,
            cargoItems = {
              CONFIG.c.PHIBOP.cargoListForTransfer.assultLandingGroup,
              CONFIG.c.PHIBOP.cargoListForTransfer.deepAssaultGroup1,
              CONFIG.c.PHIBOP.cargoListForTransfer.deepAssaultGroup2,
              CONFIG.c.PHIBOP.cargoListForTransfer.deepAssaultGroup3
            }
          },
        }
      },
    },
    tansportHelicopter = {
      dbid = CONFIG.platformDBID2,
      missions = {
        {
          name = 'AIRLANDING/CHANGLONG/1/1',
          loadoutId = CONFIG.loadoutDBID3,
          num = 3,
          startTime = CONFIG.c.PHIBOP.missionStartime.transportHelicopter[1],
        },
        {
          name = 'AIRLANDING/CHANGLONG/1/2',
          loadoutId = CONFIG.loadoutDBID3,
          num = 3,
          startTime = CONFIG.c.PHIBOP.missionStartime.transportHelicopter[2],
        },
        {
          name = 'AIRLANDING/CHANGLONG/2/1',
          loadoutId = CONFIG.loadoutDBID4,
          num = 3,
          startTime = CONFIG.c.PHIBOP.missionStartime.transportHelicopter[3],
        },
        {
          name = 'AIRLANDING/CHANGLONG/2/2',
          loadoutId = CONFIG.loadoutDBID4,
          num = 3,
          startTime = CONFIG.c.PHIBOP.missionStartime.transportHelicopter[4],
        },
      },
      zone = CONFIG.c.areas["AIRLANDING/CHANGLONG"],
      settings = {
        Subtype = 'delivery',
        TransitThrottleAircraft = 'Military',
        TransitAltitudeAircraft = 304,
        StationThrottleAircraft = 'Afterburner',
        StationAltitudeAircraft = 304,
        isactive = false
      },
      cargoItemsForTransfer = {
        type075 = {
          {
            loadoutId = CONFIG.loadoutDBID3,
            cargoItems = { CONFIG.c.PHIBOP.cargoListForTransfer.airAssaultGroup1 }
          },
          {
            loadoutId = CONFIG.loadoutDBID4,
            cargoItems = { CONFIG.c.PHIBOP.cargoListForTransfer.airAssaultGroup2 }
          },
        },
        type071 = {
          {
            loadoutId = CONFIG.loadoutDBID3,
            cargoItems = { CONFIG.c.PHIBOP.cargoListForTransfer.airAssaultGroup1 }
          },
        }
      },
    },
    attackHelicopter = {
      dbid = CONFIG.platformDBID5,
      missions = {
        {
          name = 'CAS/S',
          loadoutId = CONFIG.loadoutDBID2,
          num = 13,
          startTime = CONFIG.c.PHIBOP.missionStartime.attackHelicopter[1],
        },
      }
    },
    LSTSettings = {
      speed = CONFIG.c.PHIBOP.shipSettings.shipSpeed,
      course = {
        bearing = CONFIG.c.PHIBOP.shipSettings.heading.sishu.vertical,
        distance = CONFIG.c.PHIBOP.shipSettings.transitDistance
      }
    },
    ACV = {
      bearing = CONFIG.c.PHIBOP.shipSettings.heading.sishu.horizontal,
      distance = CONFIG.c.PHIBOP.shipSettings.ACVHorizontalDistance,
      speed = CONFIG.c.PHIBOP.shipSettings.ACVSpeed,
      destination = CONFIG.c.PHIBOP.shipSettings.heading.sishu.destination,
      area = CONFIG.c.areas["AMPH VEH STAGING AREA/SHISHU"]
    }
  },
  {
    name = "Penghu",
    baseGUID = '6Z8LM5-0HMJV6AONGLAU',
    anchorageArea = CONFIG.c.areas["ANCH AREA/PENGHU"],
    LSTAnchorageArea = CONFIG.c.areas["LST ANCH AREA/PENGHU"],
    area = CONFIG.c.areas["CAS/PENGHU"],
    offloadArea = CONFIG.c.areas["OFFLOAD AREA/PENGHU"],
    boat = {
      dbid = CONFIG.platformDBID1,
      missions = {
        {
          name = 'LANDING/PENGHU/1/1',
          loadoutId = 0,
          num = 1,
          startTime = CONFIG.c.PHIBOP.missionStartime.boat[1],
        },
        {
          name = 'LANDING/PENGHU/1/2',
          loadoutId = 0,
          num = 3,
          startTime = CONFIG.c.PHIBOP.missionStartime.boat[2],
        },
      },
      zone = CONFIG.c.areas["LANDING/PENGHU"],
      settings = {
        Subtype = 'delivery',
        TransitThrottleShip = 'Full',
        StationThrottleShip = 'Full',
        isactive = false
      },
      cargoItemsForTransfer = {
        type075 = {
          {
            loadoutId = 0,
            cargoItems = {
              CONFIG.c.PHIBOP.cargoListForTransfer.assultLandingGroup,
              CONFIG.c.PHIBOP.cargoListForTransfer.deepAssaultGroup1,
              CONFIG.c.PHIBOP.cargoListForTransfer.deepAssaultGroup2,
            }
          },
        },
        type071 = {
          {
            loadoutId = 0,
            cargoItems = {
              CONFIG.c.PHIBOP.cargoListForTransfer.assultLandingGroup,
              CONFIG.c.PHIBOP.cargoListForTransfer.deepAssaultGroup1,
              CONFIG.c.PHIBOP.cargoListForTransfer.deepAssaultGroup2,
              CONFIG.c.PHIBOP.cargoListForTransfer.deepAssaultGroup3
            }
          },
        }
      },
    },
    tansportHelicopter = {
      dbid = CONFIG.platformDBID2,
      missions = {
        {
          name = 'AIRLANDING/PENGHU/1/1',
          loadoutId = CONFIG.loadoutDBID3,
          num = 3,
          startTime = CONFIG.c.PHIBOP.missionStartime.transportHelicopter[1],
        },
        {
          name = 'AIRLANDING/PENGHU/1/2',
          loadoutId = CONFIG.loadoutDBID3,
          num = 3,
          startTime = CONFIG.c.PHIBOP.missionStartime.transportHelicopter[2],
        },
        {
          name = 'AIRLANDING/PENGHU/2/1',
          loadoutId = CONFIG.loadoutDBID4,
          num = 3,
          startTime = CONFIG.c.PHIBOP.missionStartime.transportHelicopter[3],
        },
        {
          name = 'AIRLANDING/PENGHU/2/2',
          loadoutId = CONFIG.loadoutDBID4,
          num = 3,
          startTime = CONFIG.c.PHIBOP.missionStartime.transportHelicopter[4],
        },
      },
      zone = CONFIG.c.areas["AIRLANDING/PENGHU"],
      settings = {
        Subtype = 'delivery',
        TransitThrottleAircraft = 'Military',
        TransitAltitudeAircraft = 304,
        StationThrottleAircraft = 'Afterburner',
        StationAltitudeAircraft = 304,
        isactive = false
      },
      cargoItemsForTransfer = {
        type075 = {
          {
            loadoutId = CONFIG.loadoutDBID3,
            cargoItems = { CONFIG.c.PHIBOP.cargoListForTransfer.airAssaultGroup1 }
          },
          {
            loadoutId = CONFIG.loadoutDBID4,
            cargoItems = { CONFIG.c.PHIBOP.cargoListForTransfer.airAssaultGroup2 }
          },
        },
        type071 = {
          {
            loadoutId = CONFIG.loadoutDBID3,
            cargoItems = { CONFIG.c.PHIBOP.cargoListForTransfer.airAssaultGroup1 }
          },
        }
      },
    },
    attackHelicopter = {
      dbid = CONFIG.platformDBID5,
      missions = {
        {
          name = 'CAS/PENGHU',
          loadoutId = CONFIG.loadoutDBID2,
          num = 13,
          startTime = CONFIG.c.PHIBOP.missionStartime.attackHelicopter[1],
        },
      }
    },
    LSTSettings = {
      speed = CONFIG.c.PHIBOP.shipSettings.shipSpeed,
      course = {
        bearing = CONFIG.c.PHIBOP.shipSettings.heading.penghu.vertical,
        distance = CONFIG.c.PHIBOP.shipSettings.transitDistance
      }
    },
    ACV = {
      bearing = CONFIG.c.PHIBOP.shipSettings.heading.penghu.horizontal,
      distance = CONFIG.c.PHIBOP.shipSettings.ACVHorizontalDistance,
      speed = CONFIG.c.PHIBOP.shipSettings.ACVSpeed,
      destination = CONFIG.c.PHIBOP.shipSettings.heading.penghu.destination,
      area = CONFIG.c.areas["AMPH VEH STAGING AREA/PENGHU"]
    }
  },
}
CONFIG.c.PHIBOP.transportAircraft = {
  {
    name = 'Zhangpu AAB',
    guid = 'X58F5H-0HN00TRR0Q1JQ',
    dbid = 2503,
    missions = {
      {
        name = 'AIRLANDING/PENGHU/2/2',
        loadoutId = CONFIG.loadoutDBID5,
        num = 3,
        startTime = 0
      },
    },
    cargoItemsForTransfer = {
      {
        loadoutId = CONFIG.loadoutDBID5,
        cargoItems = { CONFIG.c.PHIBOP.cargoListForTransfer.airAssaultGroup3 }
      },
    }
  },
}
CONFIG.c.PHIBOP.sag = {
  ['SAG 173'] = {
    groupName = 'SAG 173',
    from = {
      startingPoint = { lat = 'N 26.54.18', lon = 'E 121.31.38', },
      heading = 225
    },
    to = {
      archorageArea = {
        { lat = 'N 25.17.39', lon = 'E 120.56.04', desiredSpeed = 14, },
        { lat = 'N 25.17.32', lon = 'E 120.56.07', desiredSpeed = 14, },
      },
      amphibiousVehicleStagingArea = {
        { lat = 'N 25.05.36', lon = 'E 121.01.58', desiredSpeed = 14, },
      },
      heading = CONFIG.c.PHIBOP.shipSettings.heading.west.vertical,
    },
    area = CONFIG.c.areas["AIRLANDING/TAOYUAN"]
  },
  ['SAG 155'] = {
    groupName = 'SAG 155',
    from = {
      startingPoint = { lat = 'N 26.13.13', lon = 'E 120.59.55', },
      heading = 225
    },
    to = {
      archorageArea = {
        { lat = 'N 25.33.23', lon = 'E 120.54.45', desiredSpeed = 14, },
        { lat = 'N 25.21.00', lon = 'E 121.04.12', desiredSpeed = 14, },
      },
      amphibiousVehicleStagingArea = {
        { lat = 'N 25.08.29', lon = 'E 121.10.20', desiredSpeed = 14, },
      },
      heading = CONFIG.c.PHIBOP.shipSettings.heading.west.vertical,
    },
    area = CONFIG.c.areas["AIRLANDING/TAOYUAN"]
  },
  ['SAG 167'] = {
    groupName = 'SAG 167',
    from = {
      startingPoint = { lat = 'N 23.29.19', lon = 'E 118.04.37', },
      heading = CONFIG.c.PHIBOP.shipSettings.heading.penghu.vertical,
    },
    to = {
      archorageArea = {
        { lat = 'N 23.32.46', lon = 'E 119.16.11', desiredSpeed = 14, },
      },
      amphibiousVehicleStagingArea = {
        { lat = 'N 23.32.34', lon = 'E 119.29.14', desiredSpeed = 14, },
      },
      heading = CONFIG.c.PHIBOP.shipSettings.heading.penghu.vertical,
    },
    area = CONFIG.c.areas["AIRLANDING/PENGHU"],
  },
  ['SAG 154'] = {
    groupName = 'SAG 154',
    from = {
      startingPoint = { lat = 'N 22.32.59', lon = 'E 118.04.52', },
      heading = CONFIG.c.PHIBOP.shipSettings.heading.sishu.vertical,
    },
    to = {
      archorageArea = {
        { lat = 'N 22.49.20', lon = 'E 119.55.57', desiredSpeed = 14, },
      },
      amphibiousVehicleStagingArea = {
        { lat = 'N 22.53.16', lon = 'E 120.07.39', desiredSpeed = 14, },
      },
      heading = CONFIG.c.PHIBOP.shipSettings.heading.sishu.vertical,
    },
    area = CONFIG.c.areas["AIRLANDING/CHANGLONG"],
  },
  ['SAG 175'] = {
    groupName = 'SAG 175',
    from = {
      startingPoint = { lat = 'N 22.44.28', lon = 'E 118.01.16', },
      heading = CONFIG.c.PHIBOP.shipSettings.heading.sishu.vertical,
    },
    to = {
      archorageArea = {
        { lat = 'N 22.55.20', lon = 'E 119.52.25', desiredSpeed = 14, },
      },
      amphibiousVehicleStagingArea = {
        { lat = 'N 22.58.52', lon = 'E 120.05.48', desiredSpeed = 14, },
      },
      heading = CONFIG.c.PHIBOP.shipSettings.heading.sishu.vertical,
    },
    area = CONFIG.c.areas["AIRLANDING/CHANGLONG"],
  },
}

-- Land strike from
CONFIG.c.surface.lacm.weaponDBID = 4058
CONFIG.c.surface.lacm.csg = {
  groupName = 'CSG',
  unitList = {
    type002 = {
      dbid = CONFIG.platformDBID11,
      embarkedUnits = {
        {
          side = 'China',
          type = 'Air',
          dbid = 6098,
          name = '2nd Carrier Air Wing',
          loadouts = {
            { loadoutId = 9677,  num = 16 },
            { loadoutId = 34294, num = 24 },
          }
        },
        {
          side = 'China',
          type = 'Air',
          dbid = 3707,
          name = '10th Naval Air Bde',
          loadouts = {
            { loadoutId = 18368, num = 6, missionName = 'ASW/CSG' },
          }
        },
        {
          side = 'China',
          type = 'Air',
          dbid = 3303,
          name = '10th Naval Air Bde',
          loadouts = {
            { loadoutId = 17471, num = 3, missionName = 'AEW/CSG' },
          }
        },
        {
          side = 'China',
          type = 'Air',
          dbid = 4817,
          name = '2nd Carrier Air Wing',
          loadouts = {
            { loadoutId = 25212, num = 3, },
          }
        },
      },
      loadouts = {
        { loadoutId = 34294, num = 24, }, -- LS-6-500 X 4
        { loadoutId = 9677,  num = 16, }, -- YJ-91 X 4
      }
    },
    type055 = {
      dbid = CONFIG.platformDBID51,
      embarkedUnits = {
        {
          side = 'China',
          type = 'Air',
          dbid = 4902,
          name = '10th Naval Air Bde',
          loadouts = {
            { loadoutId = 13926, num = 1, missionName = 'ASW/CSG' },
          }
        },
      }
    },
    type054a = {
      dbid = CONFIG.platformDBID49,
      embarkedUnits = {
        {
          side = 'China',
          type = 'Air',
          dbid = 4902,
          name = '10th Naval Air Bde',
          loadouts = {
            { loadoutId = 13926, num = 1, missionName = 'ASW/CSG' },
          }
        },
      }
    },
    type901 = {
      dbid = CONFIG.platformDBID52,
      embarkedUnits = {
        {
          side = 'China',
          type = 'Air',
          dbid = 3707,
          name = '10th Naval Air Bde',
          loadouts = {
            { loadoutId = 18368, num = 1, missionName = 'ASW/CSG' },
          }
        },
      }
    },
  },
  from = {
    startingPoint = { lat = 'N 21.09.59', lon = 'E 120.48.05', },
    heading = 83
  },
  to = {
    area = {
      { lat = 'N 21.14.11', lon = 'E 121.34.36', },
      { lat = 'N 21.32.59', lon = 'E 122.12.58', },
    },
    -- heading = CONFIG.c.PHIBOP.shipInfo.heading.west.vertical,
  },
}
CONFIG.c.surface.lacm.targetlist = {
  '6Z8LM5-0HMIJ7B89BC71',
  '6Z8LM5-0HMIJ7B89BC73',
  '6Z8LM5-0HMIJ7B89BC6V',
}


-- SLCM
CONFIG.c.subSurface.slcm.weaponDBID = 3716
CONFIG.c.subSurface.slcm.submarines = {
  {
    name = "407",
    guid = '',
    course = {
      -- { lat = 'N 25.07.11', lon = 'E 122.12.20', },
      { lat = 'N 25.07.57', lon = 'E 122.46.06', presetDepth = 3 },
      { lat = 'N 24.33.33', lon = 'E 122.05.57', presetDepth = 3 },
      { lat = 'N 24.30.54', lon = 'E 122.48.02', presetDepth = 3 },
    },
    from = {
      startingPoint = { lat = 'N 25.05.32', lon = 'E 122.11.39' },
      heading = 180
    },
    weaponDBID = CONFIG.c.subSurface.slcm.weaponDBID
  },
  {
    name = "408",
    guid = '',
    course = {
      -- { lat = 'N 24.32.29', lon = 'E 122.47.27', },
      { lat = 'N 25.11.06', lon = 'E 122.42.15', presetDepth = 3 },
      { lat = 'N 24.33.33', lon = 'E 122.08.38', presetDepth = 3 },
      { lat = 'N 25.09.37', lon = 'E 122.06.45', presetDepth = 3 },
    },
    from = {
      startingPoint = { lat = 'N 24.32.30', lon = 'E 122.47.45', },
      heading = 270
    },
    weaponDBID = CONFIG.c.subSurface.slcm.weaponDBID
  },
  {
    name = "409",
    guid = '',
    course = {
      { lat = 23.1405738004732, lon = 122.453896349795, presetDepth = 3 },
      { lat = 24.3097078500905, lon = 122.142301456749, presetDepth = 3 },
      { lat = 23.3573584800694, lon = 121.777514450334, presetDepth = 3 }
    },
    from = {
      startingPoint = { lat = 'N 23.29.41', lon = 'E 122.39.12', },
      heading = 180
    },
    weaponDBID = CONFIG.c.subSurface.slcm.weaponDBID
  },
  {
    name = "410",
    guid = '',
    course = {
      { lat = 24.2344610141018, lon = 122.681795983267, presetDepth = 3 },
      { lat = 23.4458260682078, lon = 121.855392759008, presetDepth = 3 },
      { lat = 24.280771111992,  lon = 121.981212557257, presetDepth = 3 }
    },
    from = {
      startingPoint = { lat = 'N 22.41.17', lon = 'E 122.01.36', },
      heading = 30
    },
    weaponDBID = CONFIG.c.subSurface.slcm.weaponDBID
  },
}

CONFIG.c.subSurface.slcm.targetlist = {
  '6Z8LM5-0HMIJ7B89BCF3',
  '6Z8LM5-0HMIJ7B89BCF4',
  '6Z8LM5-0HMIJ7B89BCF5',
}
CONFIG.c.subSurface.slcm.randomRadius = 20


-- Runway repairment
CONFIG.c.repairRunway.percentagePerHour = 3



-- MLRS
CONFIG.t.ground.mlrs.wpnDefault = 144
CONFIG.t.ground.mlrs.ammoThreshold = 25
CONFIG.t.ground.mlrs.positions = {
  pingzhen = {
    RL = {
      course = {
        { lat = 'N 24.55.15', lon = 'E 121.16.02', desiredSpeed = 10, presetThrottle = 'Flank' },
        { lat = 'N 24.57.13', lon = 'E 121.13.45', desiredSpeed = 10, presetThrottle = 'Flank' },
      },
      area = CONFIG.t.areas["RL/PINGZHEN"]
    },
    FP = {
      {
        course = {
          { lat = 'N 24.55.15', lon = 'E 121.16.02', desiredSpeed = 10, presetThrottle = 'Flank' },
          { lat = 'N 24.53.01', lon = 'E 121.14.17', desiredSpeed = 10, presetThrottle = 'Flank' },
        },
        area = CONFIG.t.areas["FP1/PINGZHEN"]
      },
    },
    AHA = {
      course = {
        { lat = 'N 24.55.15', lon = 'E 121.16.02', desiredSpeed = 10, presetThrottle = 'Flank' },
      },
      area = CONFIG.t.areas["AHA/PINGZHEN"]
    },
  },
}
CONFIG.t.ground.mlrs.reloadTime = 30 * 60


-- SRBM
CONFIG.t.ground.srbm.wpnDefault = 27
CONFIG.t.ground.srbm.ammoThreshold = 25
CONFIG.t.ground.srbm.positions = {
  pingzhen = {
    RL = {
      course = {
        { lat = 'N 24.55.15', lon = 'E 121.16.02', desiredSpeed = 10, presetThrottle = 'Flank' },
        { lat = 'N 24.57.13', lon = 'E 121.13.45', desiredSpeed = 10, presetThrottle = 'Flank' },
      },
      area = CONFIG.t.areas["RL/PINGZHEN"]
    },
    FP = {
      {
        course = {
          { lat = 'N 24.55.15', lon = 'E 121.16.02', desiredSpeed = 10, presetThrottle = 'Flank' },
          { lat = 'N 24.53.01', lon = 'E 121.14.17', desiredSpeed = 10, presetThrottle = 'Flank' },
        },
        area = CONFIG.t.areas["FP1/PINGZHEN"]
      },
    },
    AHA = {
      course = {
        { lat = 'N 24.55.15', lon = 'E 121.16.02', desiredSpeed = 10, presetThrottle = 'Flank' },
      },
      area = CONFIG.t.areas["AHA/PINGZHEN"]
    },
  },
  dadu = {
    RL = {
      course = {
        { lat = 'N 24.09.07', lon = 'E 120.36.27', desiredSpeed = 10, presetThrottle = 'Flank' },
        { lat = 'N 24.09.09', lon = 'E 120.35.47', desiredSpeed = 10, presetThrottle = 'Flank' },
      },
      area = CONFIG.t.areas["RL/DADU"]
    },
    FP = {
      {
        course = {
          { lat = 'N 24.09.07', lon = 'E 120.36.27', desiredSpeed = 10, presetThrottle = 'Flank' },
          { lat = 'N 24.11.43', lon = 'E 120.38.29', desiredSpeed = 10, presetThrottle = 'Flank' },
        },
        area = CONFIG.t.areas["FP1/DADU"]
      },
    },
    AHA = {
      course = {
        { lat = 'N 24.09.07', lon = 'E 120.36.27', desiredSpeed = 10, presetThrottle = 'Flank' },
      },
      area = CONFIG.t.areas["AHA/DADU"]
    },
  },
}
CONFIG.t.ground.srbm.reloadTime = 10 * 60


-- GLCM
CONFIG.t.ground.glcm.wpnDefault = 24
CONFIG.t.ground.glcm.ammoThreshold = 25
CONFIG.t.ground.glcm.positions = {
  quanxi = {
    RL = {
      course = {},
      area = CONFIG.t.areas["RL/QUANXI"]
    },
    FP = {
      {
        course = {},
        area = CONFIG.t.areas["FP1/PINGZHEN"]
      },
    },
    AHA = {
      course = {},
      area = CONFIG.t.areas["AHA/QUANXI"]
    },
  },
  neipu = {
    RL = {
      area = CONFIG.t.areas["RL/NEIPU"]
    },
    FP = {
      {
        area = CONFIG.t.areas["FP1/NEIPU"]
      },
    },
    AHA = {
      course = {},
      area = CONFIG.t.areas["AHA/NEIPU"]
    },
  }
}
CONFIG.t.ground.glcm.reloadTime = 45 * 60


-- ASCM
CONFIG.t.ground.ascm.wpnDefault = 16
CONFIG.t.ground.ascm.ammoThreshold = 25
CONFIG.t.ground.ascm.positions = {
  pingzhen = {
    RL = {
      course = {
        { lat = 'N 24.55.15', lon = 'E 121.16.02', desiredSpeed = 10, presetThrottle = 'Flank' },
        { lat = 'N 24.57.13', lon = 'E 121.13.45', desiredSpeed = 10, presetThrottle = 'Flank' },
      },
      area = CONFIG.t.areas["RL/PINGZHEN"]
    },
    FP = {
      {
        course = {
          { lat = 'N 24.55.15', lon = 'E 121.16.02', desiredSpeed = 10, presetThrottle = 'Flank' },
          { lat = 'N 24.53.01', lon = 'E 121.14.17', desiredSpeed = 10, presetThrottle = 'Flank' },
        },
        area = CONFIG.t.areas["FP1/PINGZHEN"]
      },
    },
    AHA = {
      course = {
        { lat = 'N 24.55.15', lon = 'E 121.16.02', desiredSpeed = 10, presetThrottle = 'Flank' },
      },
      area = CONFIG.t.areas["AHA/PINGZHEN"]
    },
  },
  dadu = {
    RL = {
      course = {
        { lat = 'N 24.09.07', lon = 'E 120.36.27', desiredSpeed = 10, presetThrottle = 'Flank' },
        { lat = 'N 24.09.09', lon = 'E 120.35.47', desiredSpeed = 10, presetThrottle = 'Flank' },
      },
      area = CONFIG.t.areas["RL/DADU"]
    },
    FP = {
      {
        course = {
          { lat = 'N 24.09.07', lon = 'E 120.36.27', desiredSpeed = 10, presetThrottle = 'Flank' },
          { lat = 'N 24.11.43', lon = 'E 120.38.29', desiredSpeed = 10, presetThrottle = 'Flank' },
        },
        area = CONFIG.t.areas["FP1/DADU"]
      },
    },
    AHA = {
      course = {
        { lat = 'N 24.09.07', lon = 'E 120.36.27', desiredSpeed = 10, presetThrottle = 'Flank' },
      },
      area = CONFIG.t.areas["AHA/DADU"]
    },
  },
  neipu = {
    RL = {
      area = CONFIG.t.areas["RL/NEIPU"]
    },
    FP = {
      {
        area = CONFIG.t.areas["FP1/NEIPU"]
      },
    },
    AHA = {
      course = {},
      area = CONFIG.t.areas["AHA/NEIPU"]
    },
  },
  luzhu = {
    RL = {
      area = CONFIG.t.areas["RL/LUZHU"]
    },
    FP = {
      {
        area = CONFIG.t.areas["FP1/LUZHU"]
      },
    },
    AHA = {
      course = {},
      area = CONFIG.t.areas["AHA/LUZHU"]
    },
  },
  dong = {
    RL = {
      area = CONFIG.t.areas["RL/DONG"]
    },
    FP = {
      {
        area = CONFIG.t.areas["FP1/DONG"]
      },
    },
    AHA = {
      course = {},
      area = CONFIG.t.areas["AHA/DONG"]
    },
  },
}
CONFIG.t.ground.ascm.reloadTime = 45 * 60


-- Runway repairment
CONFIG.t.repairRunway.percentagePerHour = 3


-- IADS
CONFIG.t.IADS.ratio = { ROCC = 1.5, TAAOC = 1.5 }


-- Aircraft settings
CONFIG.t.air.landBased.wpnNum = 8
CONFIG.t.air.landBased.deployedACs = {
  {
    name = 'Ching Chuang Kang AB',
    baseGUID = '6Z8LM5-0HMIHS2L949R0',
    embarkedUnits = {
      {
        side = 'Taiwan',
        type = 'Air',
        dbid = 3795,
        name = '3rd Tactical Fighter Wing',
        loadouts = {
          { loadoutId = 19104, num = 8 },
        }
      }
    },
    loadouts = {
      { loadoutId = 19104, num = CONFIG.t.air.landBased.wpnNum }, --Wan Chien X 2
    }
  },
  {
    name = 'Chiayi AB',
    baseGUID = '6Z8LM5-0HMIJ3QGCHSUB',
    embarkedUnits = {
      {
        side = 'Taiwan',
        type = 'Air',
        dbid = 3962,
        name = '4th Tactical Fighter Wing',
        loadouts = {
          { loadoutId = 22798, num = 8 },
        }
      }
    },
    loadouts = {
      { loadoutId = 22785, num = CONFIG.t.air.landBased.wpnNum }, --AMRAAM X 4
      { loadoutId = 22789, num = CONFIG.t.air.landBased.wpnNum }, --Harpoon X 2
      { loadoutId = 22790, num = CONFIG.t.air.landBased.wpnNum }, --GBU X 2
    }
  },
  {
    name = 'Tainan AB',
    baseGUID = '6Z8LM5-0HMIJ3QGCHVVS',
    embarkedUnits = {
      {
        side = 'Taiwan',
        type = 'Air',
        dbid = 3795,
        name = '1st Tactical Fighter Wing',
        loadouts = {
          { loadoutId = 19104, num = 4 },
        }
      }
    },
    loadouts = {
      { loadoutId = 19104, num = CONFIG.t.air.landBased.wpnNum }, --Wan Chien X 2
    }
  },
  {
    name = 'Magong AB',
    baseGUID = '6Z8LM5-0HMISSTNL3T8K',
    embarkedUnits = {
      {
        side = 'Taiwan',
        type = 'Air',
        dbid = 3795,
        name = '1st Tactical Fighter Wing',
        loadouts = {
          { loadoutId = 19104, num = 4 },
        }
      }
    },
    loadouts = {
      { loadoutId = 19104, num = CONFIG.t.air.landBased.wpnNum }, --Wan Chien X 2
    }
  },
  {
    name = 'Guiren AAB',
    baseGUID = 'IC8B0X-0HN37BVOG0T9O',
    embarkedUnits = {
      {
        side = 'Taiwan',
        type = 'Air',
        dbid = 2126,
        name = '603rd Air Cavalry Bde',
        loadouts = {
          { loadoutId = 7347, num = 8, missionName = 'ASUW/ACV/PENGHU' },
        }
      }
    },
    loadouts = {
      { loadoutId = 7347, num = CONFIG.t.air.landBased.wpnNum }, --Hellfire X 8
    }
  },
  {
    name = 'Pingtung North AB',
    baseGUID = '6Z8LM5-0HMIJ3QGCI1GF',
    embarkedUnits = {
      {
        side = 'Taiwan',
        type = 'Air',
        dbid = 2095,
        name = '6th Mixed Wing',
        loadouts = {
          { loadoutId = 14639, num = 3, missionName = 'FERRY/2' },
        }
      },
      -- {
      --   side = 'Taiwan',
      --   type = 'Air',
      --   dbid = 2825,
      --   name = '6th Mixed Wing',
      --   loadouts = {
      --     { loadoutId = 13537, num = 3, missionName = 'ASW/E' },
      --   }
      -- },
      -- {
      --   side = 'Taiwan',
      --   type = 'Air',
      --   dbid = 4755,
      --   name = '6th Mixed Wing',
      --   loadouts = {
      --     { loadoutId = 25876, num = 1, missionName = 'FERRY/2' },
      --   }
      -- },
    }
  },
  {
    name = 'Pingtung South AB',
    baseGUID = '6Z8LM5-0HMIJ3QGCI1GF',
    embarkedUnits = {
      -- {
      --   side = 'Taiwan',
      --   type = 'Air',
      --   dbid = 2095,
      --   name = '6th Mixed Wing',
      --   loadouts = {
      --     { loadoutId = 14639, num = 3, missionName = 'FERRY/2' },
      --   }
      -- },
      {
        side = 'Taiwan',
        type = 'Air',
        dbid = 2825,
        name = '6th Mixed Wing',
        loadouts = {
          { loadoutId = 13537, num = 3, missionName = 'ASW/E' },
        }
      },
      {
        side = 'Taiwan',
        type = 'Air',
        dbid = 4755,
        name = '6th Mixed Wing',
        loadouts = {
          { loadoutId = 25876, num = 1, missionName = 'FERRY/2' },
        }
      },
    }
  },
  {
    name = 'Taitung/Jhihhang AB',
    baseGUID = '6Z8LM5-0HMIJ3QGCI3V3',
    embarkedUnits = {
      {
        side = 'Taiwan',
        type = 'Air',
        dbid = 6889,
        name = '7th Tactical Fighter Wing',
        loadouts = {
          { loadoutId = 33012, num = 8, missionName = 'FERRY/3' },
        }
      }
    },
    loadouts = {
      { loadoutId = 33012, num = CONFIG.t.air.landBased.wpnNum }, --SLAMER X 2
      { loadoutId = 9479,  num = CONFIG.t.air.landBased.wpnNum }, --JDAM X 4
      { loadoutId = 9326,  num = CONFIG.t.air.landBased.wpnNum }, --HARM X 2
      { loadoutId = 9481,  num = CONFIG.t.air.landBased.wpnNum }, --JSOW X 4
    }
  },
  {
    name = 'Jiashan AB',
    baseGUID = '6Z8LM5-0HMIJ3QGCI783',
    embarkedUnits = {
      {
        side = 'Taiwan',
        type = 'Air',
        dbid = 6039,
        name = '5th Tactical Mixed Wing',
        loadouts = {
          { loadoutId = 32059, num = 3, missionName = 'AEW/S' },
        }
      },
      {
        side = 'Taiwan',
        type = 'Air',
        dbid = 3962,
        name = '5th Tactical Mixed Wing',
        loadouts = {
          { loadoutId = 22789, num = 8, },
        }
      }
    },
    loadouts = {
      { loadoutId = 22785, num = CONFIG.t.air.landBased.wpnNum }, --AMRAAM X 4
      { loadoutId = 22789, num = CONFIG.t.air.landBased.wpnNum }, --Harpoon X 2
      { loadoutId = 22790, num = CONFIG.t.air.landBased.wpnNum }, --GBU X 2
    }
  },
  {
    name = 'Hsinchu AB',
    baseGUID = '6Z8LM5-0HMIK08HEK556',
    embarkedUnits = {
      {
        side = 'Taiwan',
        type = 'Air',
        dbid = 175,
        name = '2nd Tactical Fighter Wing',
        loadouts = {
          { loadoutId = 5732, num = 8, },
        }
      }
    },
    loadouts = {
      { loadoutId = 5732, num = CONFIG.t.air.landBased.wpnNum }, --MICA X 4

    }
  },
  {
    name = 'Longtan AAB',
    baseGUID = 'IC8B0X-0HN3ADVRF2U7P',
    embarkedUnits = {
      {
        side = 'Taiwan',
        type = 'Air',
        dbid = 2419,
        name = '601st Air Cavalry Bde',
        loadouts = {
          { loadoutId = 15213, num = 8, missionName = 'ASUW/ACV/W' },
        }
      }
    },
    loadouts = {
      { loadoutId = 15213, num = CONFIG.t.air.landBased.wpnNum }, --Hellfire X 16
    }
  },
  {
    name = 'Taoyuan International Airport',
    baseGUID = '6Z8LM5-0HMJ1GE4HSIU5',
    embarkedUnits = {
      {
        side = 'Taiwan',
        type = 'Air',
        dbid = 5035,
        name = '1st Maritime Tactical Recon Sqn',
        loadouts = {
          { loadoutId = 28116, num = 3, missionName = 'RECON/3' },
        }
      }
    }
  },
  {
    name = 'Rende Emergency Highway Strip',
    baseGUID = 'X58F5H-0HMU28MM77N82',
    loadouts = {
      { loadoutId = 19104, num = CONFIG.t.air.landBased.wpnNum }, --Wan Chien X 2
    }
  },
  {
    name = 'Madou Emergency Highway Strip',
    baseGUID = 'X58F5H-0HMU28MM7836P',
    loadouts = {
      { loadoutId = 22785, num = CONFIG.t.air.landBased.wpnNum }, --AMRAAM X 4
      { loadoutId = 22789, num = CONFIG.t.air.landBased.wpnNum }, --Harpoon X 2
      { loadoutId = 22790, num = CONFIG.t.air.landBased.wpnNum }, --GBU X 2
    }
  },
  {
    name = 'Minxiong Emergency Highway Strip',
    baseGUID = 'X58F5H-0HMU28MM78J9P',
    loadouts = {
      { loadoutId = 22785, num = CONFIG.t.air.landBased.wpnNum }, --AMRAAM X 4
      { loadoutId = 22789, num = CONFIG.t.air.landBased.wpnNum }, --Harpoon X 2
      { loadoutId = 22790, num = CONFIG.t.air.landBased.wpnNum }, --GBU X 2
    }
  },
  {
    name = 'Tainan Field Airdrome',
    baseGUID = 'IC8B0X-0HN81FNLB6M8Q',
    loadouts = {
      { loadoutId = 7347, num = CONFIG.t.air.landBased.wpnNum }, --Hellfire X 8
    }
  },
  {
    name = 'Hsinchu Field Airdrome ',
    baseGUID = 'IC8B0X-0HN81FNLB2OPJ',
    loadouts = {
      { loadoutId = 15213, num = CONFIG.t.air.landBased.wpnNum }, --Hellfire X 16
    }
  },
}

CONFIG.t.surface.sag = {
  ['264th Sqn'] = {
    groupName = '264th Sqn',
    unitList = {
      kidd = {
        dbid = CONFIG.platformDBID73,
        embarkedUnits = {
          {
            side = 'Taiwan',
            type = 'Air',
            dbid = CONFIG.platformDBID75,
            name = '2nd ASW Aviation Grp',
            loadouts = {
              { loadoutId = 845, num = 2 },
            }
          },
        },
      },
      kangDing = {
        dbid = CONFIG.platformDBID74,
        embarkedUnits = {
          {
            side = 'Taiwan',
            type = 'Air',
            dbid = CONFIG.platformDBID75,
            name = '2nd ASW Aviation Grp',
            loadouts = {
              { loadoutId = 845, num = 1 },
            }
          },
        }
      },
    },
    missionName = 'ASW/E',
    from = {
      startingPoint = { lat = 'N 24.28.47', lon = 'E 122.25.49', },
      heading = 0
    },
  },
}

CONFIG.t.surface.deployedShips = {
  {
    name = 'Port of Keelung',
    baseGUID = 'X58F5H-0HMSMDQJ7LEUI',
    embarkedUnits = {
      {
        side = 'Taiwan',
        type = 'Ship',
        dbid = 3441,
        name = '131st Fleet',
        loadouts = {
          { loadoutId = 0, num = 6 },
        }
      }
    }
  },
}


-- SIGINT
-- CONFIG.u.SIGINT.maxCount = 5
CONFIG.u.SIGINT.maxCount = 1


-- Score
CONFIG.s.destroyingAircraftOnTheGround = 5
CONFIG.s.destroyingAmmo = 100
CONFIG.s.destroyingAmmoTruck = 20
CONFIG.s.lhd = 10
CONFIG.s.lst = 10
CONFIG.s.ddg = 10
CONFIG.s.cv = 100
CONFIG.s.ifv = -5
CONFIG.s.infantry = -3
CONFIG.s.sub = 15
CONFIG.s.uav = 20
CONFIG.s.tel = 20
CONFIG.s.weaponDBID = 905
CONFIG.s.attackBeforeTheHHour = -1000
CONFIG.s.undergroundShelterIsDestroyed = -200
CONFIG.s.destroyingCivilianFacility = -100

return CONFIG
