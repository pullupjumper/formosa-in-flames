---@class SBJ__CONFIG
local config = {}
config.isDevMode = true
config.isSaved = true
config.difficulty = 'normal'
config.c = {}
config.c.air = {}
config.c.air.landBased = {}
config.c.air.shipBased = {}
config.c.ground = {}
config.c.ground.mlrs = {}
config.c.ground.srbm = {}
config.c.ground.mrbm = {}
config.c.ground.glcm = {}
config.c.ground.ascm = {}
config.c.surface = {}
config.c.surface.lacm = {}
config.c.subSurface = {}
config.c.subSurface.slcm = {}
config.c.PHIBOP = {}
config.c.recon = {}
config.c.GPSJamming = {}
config.c.commsJamming = {}
config.c.repairRunway = {}
config.c.IADS = {}
config.c.SIGINT = {}
config.t = {}
config.t.ground = {}
config.t.ground.mlrs = {}
config.t.ground.glcm = {}
config.t.ground.srbm = {}
config.t.ground.ascm = {}
config.t.repairRunway = {}
config.t.IADS = {}
config.t.air = {}
config.t.air.landBased = {}
config.t.surface = {}
config.u = {}
config.u.SIGINT = {}
config.s = {}

config.c.area = {
  MILITARY_SUB_DISTRICT_FUZHOU = { 'RP-85138', 'RP-85139', 'RP-85140', 'RP-85141', },
  MILITARY_SUB_DISTRICT_PUTIAN = { 'RP-156577', 'RP-156578', 'RP-156579', 'RP-156580', },
  MILITARY_SUB_DISTRICT_CHANGZHOU = { 'RP-156581', 'RP-156582', 'RP-156583', 'RP-156584', },
  MILITARY_SUB_DISTRICT_XIAMEN = { 'RP-156585', 'RP-156586', 'RP-156587', 'RP-156588', },
  MILITARY_SUB_DISTRICT_ZHANGZHOU = { 'RP-85134', 'RP-85135', 'RP-85136', 'RP-85137', },
  MILITARY_SUB_DISTRICT_SHANTOU = { 'RP-156589', 'RP-156590', 'RP-156591', 'RP-156592', },
  MILITARY_SUB_DISTRICT_SHANWEI = { 'RP-156593', 'RP-156594', 'RP-156595', 'RP-156596', },
  MILITARY_SUB_DISTRICT_MEIZHOU = { 'RP-85130', 'RP-85131', 'RP-85132', 'RP-85133', },
  RELOAD_POINT_PINGTAN = { 'RP-114443', 'RP-114444', 'RP-114445', 'RP-114446' },
  HIDE_AREA_PINGTAN = { 'RP-114439', 'RP-114440', 'RP-114441', 'RP-114442' },
  FIRE_POINT_PINGTAN_1 = { 'RP-44264', 'RP-44265', 'RP-44266', 'RP-44267' },
  FIRE_POINT_PINGTAN_2 = { 'RP-44260', 'RP-44261', 'RP-44262', 'RP-44263' },
  AMMO_HOLDING_AREA_PINGTAN = { 'RP-114447', 'RP-114448', 'RP-114449', 'RP-114450' },
  RELOAD_POINT_CHINCHEW = { 'RP-114455', 'RP-114456', 'RP-114457', 'RP-114458' },
  HIDE_AREA_CHINCHEW = { 'RP-114451', 'RP-114452', 'RP-114453', 'RP-114454' },
  FIRE_POINT_CHINCHEW_1 = { 'RP-46390', 'RP-46391', 'RP-46392', 'RP-46393' },
  AMMO_HOLDING_AREA_CHINCHEW = { 'RP-114459', 'RP-114460', 'RP-114461', 'RP-114462' },
  RELOAD_POINT_BRIGADE615 = { 'RP-114467', 'RP-114468', 'RP-114469', 'RP-114470' },
  HIDE_AREA_BRIGADE615 = { 'RP-114463', 'RP-114464', 'RP-114465', 'RP-114466' },
  FIRE_POINT_BRIGADE615_1 = { 'RP-44322', 'RP-44323', 'RP-44324', 'RP-44325' },
  AMMO_HOLDING_AREA_BRIGADE615 = { 'RP-114471', 'RP-114472', 'RP-114473', 'RP-114474' },
  RELOAD_POINT_BRIGADE614 = { 'RP-114479', 'RP-114480', 'RP-114481', 'RP-114482' },
  HIDE_AREA_BRIGADE614 = { 'RP-114475', 'RP-114476', 'RP-114477', 'RP-114478' },
  FIRE_POINT_BRIGADE614_1 = { 'RP-44335', 'RP-44336', 'RP-44337', 'RP-44338' },
  AMMO_HOLDING_AREA_BRIGADE614 = { 'RP-114483', 'RP-114484', 'RP-114485', 'RP-114486' },
  RELOAD_POINT_BRIGADE636 = { 'RP-114491', 'RP-114492', 'RP-114493', 'RP-114494' },
  HIDE_AREA_BRIGADE636 = { 'RP-114487', 'RP-114488', 'RP-114489', 'RP-114490' },
  FIRE_POINT_BRIGADE636_1 = { 'RP-44357', 'RP-44358', 'RP-44359', 'RP-44360' },
  AMMO_HOLDING_AREA_BRIGADE636 = { 'RP-114495', 'RP-114496', 'RP-114497', 'RP-114498' },
  RELOAD_POINT_BRIGADE616 = { 'RP-114503', 'RP-114504', 'RP-114505', 'RP-114506' },
  HIDE_AREA_BRIGADE616 = { 'RP-114499', 'RP-114500', 'RP-114501', 'RP-114502' },
  FIRE_POINT_BRIGADE616_1 = { 'RP-44369', 'RP-44370', 'RP-44371', 'RP-44372' },
  AMMO_HOLDING_AREA_BRIGADE616 = { 'RP-114507', 'RP-114508', 'RP-114509', 'RP-114510' },
  RELOAD_POINT_BRIGADE613 = { 'RP-114515', 'RP-114516', 'RP-114517', 'RP-114518' },
  HIDE_AREA_BRIGADE613 = { 'RP-114511', 'RP-114512', 'RP-114513', 'RP-114514' },
  FIRE_POINT_BRIGADE613_1 = { 'RP-44391', 'RP-44392', 'RP-44393', 'RP-44394' },
  AMMO_HOLDING_AREA_BRIGADE613 = { 'RP-114519', 'RP-114520', 'RP-114521', 'RP-114522' },
  RELOAD_POINT_BRIGADE617 = { 'RP-114527', 'RP-114528', 'RP-114529', 'RP-114530' },
  HIDE_AREA_BRIGADE617 = { 'RP-114523', 'RP-114524', 'RP-114525', 'RP-114526' },
  FIRE_POINT_BRIGADE617_1 = { 'RP-44413', 'RP-44414', 'RP-44415', 'RP-44416' },
  AMMO_HOLDING_AREA_BRIGADE617 = { 'RP-114531', 'RP-114532', 'RP-114533', 'RP-114534' },
  RELOAD_POINT_BRIGADE624 = { 'RP-156928', 'RP-156929', 'RP-156930', 'RP-156931' },
  HIDE_AREA_BRIGADE624 = { 'RP-156932', 'RP-156933', 'RP-156934', 'RP-156935' },
  FIRE_POINT_BRIGADE624_1 = { 'RP-156936', 'RP-156937', 'RP-156938', 'RP-156939' },
  AMMO_HOLDING_AREA_BRIGADE624 = { 'RP-156924', 'RP-156925', 'RP-156926', 'RP-156927' },
  STARTING_POINT_075_TAOYUAN = { 'RP-11169' },
  AREA_OF_OPS_D = { 'RP-46580', 'RP-46581', 'RP-46582', 'RP-46583' },
  DESTINATION_075_TAOYUAN = { 'RP-4322' },
  DESTINATION_071_TAOYUAN = { 'RP-3915' },
  AIRLANDING_TAOYUAN = { 'RP-3819', 'RP-3820', 'RP-3821', 'RP-3822' },
  STARTING_POINT_075_SISHU = { 'RP-56195' },
  AREA_OF_OPS_F = { 'RP-46584', 'RP-46585', 'RP-46586', 'RP-46587' },
  DESTINATION_075_SISHU = { 'RP-69332' },
  DESTINATION_071_SISHU = { 'RP-69333' },
  STARTING_POINT_075_PENGHU = { 'RP-59972' },
  AREA_OF_OPS_E = { 'RP-59975', 'RP-59976', 'RP-59977', 'RP-59978' },
  DESTINATION_075_PENGHU = { 'RP-59973' },
  DESTINATION_071_PENGHU = { 'RP-59974' },
  ANCH_AREA_TAOYUAN = { 'RP-9684', 'RP-9685', 'RP-9686', 'RP-9687' },
  LST_ANCH_AREA_TAOYUAN = { 'RP-9712', 'RP-9713', 'RP-9714', 'RP-9715' },
  CAS_E = { 'RP-6787', 'RP-6788', 'RP-6789', 'RP-6790' },
  OFFLOAD_AREA_TAOYUAN = { 'RP-141074', 'RP-141075', 'RP-141076', 'RP-141077' },
  LANDING_TAOYUAN = { 'RP-7702', 'RP-7703', 'RP-7704', 'RP-7705' },
  AMPH_VEH_STAGING_AREA_TAOYUAN = { 'RP-7722', 'RP-7723', 'RP-7724', 'RP-7725' },
  ANCH_AREA_SISHU = { 'RP-69328', 'RP-69329', 'RP-69330', 'RP-69331' },
  LST_ANCH_AREA_SISHU = { 'RP-69324', 'RP-69325', 'RP-69326', 'RP-69327' },
  CAS_S = { 'RP-73973', 'RP-73974', 'RP-73975', 'RP-73976' },
  OFFLOAD_AREA_SISHU = { 'RP-141078', 'RP-141079', 'RP-141080', 'RP-141081' },
  LANDING_SISHU = { 'RP-69316', 'RP-69317', 'RP-69318', 'RP-69319' },
  AIRLANDING_CHANGLONG = { 'RP-11165', 'RP-11166', 'RP-11167', 'RP-11168' },
  AMPH_VEH_STAGING_AREA_SHISHU = { 'RP-69320', 'RP-69321', 'RP-69322', 'RP-69323' },
  ANCH_AREA_PENGHU = { 'RP-46576', 'RP-46577', 'RP-46578', 'RP-46579' },
  LST_ANCH_AREA_PENGHU = { 'RP-46572', 'RP-46573', 'RP-46574', 'RP-46575' },
  CAS_PENGHU = { 'RP-69261', 'RP-69262', 'RP-69263', 'RP-69264' },
  OFFLOAD_AREA_PENGHU = { 'RP-141082', 'RP-141083', 'RP-141084', 'RP-141085' },
  LANDING_PENGHU = { 'RP-46290', 'RP-46291', 'RP-46292', 'RP-46293' },
  AIRLANDING_PENGHU = { 'RP-59968', 'RP-59969', 'RP-59970', 'RP-59971' },
  AMPH_VEH_STAGING_AREA_PENGHU = { 'RP-46329', 'RP-46330', 'RP-46331', 'RP-46332' },
  AREA_OF_OPS_NORTH = { 'RP-8012', 'RP-8013', 'RP-8014', 'RP-8015' },
  AREA_OF_OPS_CENTER = {
    'RP-156966', 'RP-156967', 'RP-156968',
    'RP-156969', 'RP-156970', 'RP-156971',
    'RP-156972', 'RP-156973', 'RP-156974'
  },
  AREA_OF_OPS_PACIFIC = { 'RP-76319', 'RP-42688', 'RP-42687', 'RP-76320' },
  AREA_OF_OPS_SOUTH = {
    'RP-156975', 'RP-156976', 'RP-156977',
    'RP-156978', 'RP-156979', 'RP-156980',
    'RP-156981', 'RP-156982', 'RP-156983',
    'RP-156984', 'RP-156985', 'RP-156986', 'RP-156987'
  },
  AREA_OF_OPS_EAST = { 'RP-156988', 'RP-156989', 'RP-156990', 'RP-156991', 'RP-156992', 'RP-156993' },
  TARGET_AREA_SOUTH_PROSECUTION = { 'rp-163362', 'rp-163363', 'rp-163364', 'rp-163365', },
  TARGET_AREA_SOUTH_PATROL = { 'rp-163366', 'rp-163367', },
  TARGET_AREA_CENTER_PROSECUTION = { 'rp-163338', 'rp-163339', 'rp-163340', 'rp-163341', },
  TARGET_AREA_CENTER_PATROL = { 'rp-163342', 'rp-163343', },
  TARGET_AREA_NORTH_PROSECUTION = { 'rp-163344', 'rp-163345', 'rp-163346', 'rp-163347', },
  TARGET_AREA_NORTH_PATROL = { 'rp-163348', 'rp-163349', },
  TARGET_AREA_JHI_PROSECUTION = { 'rp-163350', 'rp-163351', 'rp-163352', 'rp-163353', },
  TARGET_AREA_JHI_PATROL = { 'rp-163354', 'rp-163355', },
  TARGET_AREA_JIASHAN_PROSECUTION = { 'rp-163356', 'rp-163357', 'rp-163358', 'rp-163359', },
  TARGET_AREA_JIASHAN_PATROL = { 'rp-163360', 'rp-163161', },
  AAR_PATROL = { 'RP-44509', 'RP-44510', 'RP-44511', 'RP-44512', },
  AAR_PATROL_2 = { 'RP-181270', 'RP-181271', 'RP-181272', 'RP-181273', },
}


config.t.area = {
  RELOAD_POINT_PINGZHEN = { 'RP-100174', 'RP-100175', 'RP-100176', 'RP-100177' },
  FIRE_POINT_PINGZHEN_1 = { 'RP-44300', 'RP-44301', 'RP-44302', 'RP-44303' },
  AMMO_HOLDING_AREA_PINGZHEN = { 'RP-114539', 'RP-114540', 'RP-114541', 'RP-114542' },
  RELOAD_POINT_DADU = { 'RP-101781', 'RP-101782', 'RP-101783', 'RP-101784' },
  FIRE_POINT_DADU_1 = { 'RP-101785', 'RP-101786', 'RP-101787', 'RP-101788' },
  AMMO_HOLDING_AREA_DADU = { 'RP-114555', 'RP-114556', 'RP-114557', 'RP-114558' },
  RELOAD_POINT_QUANXI = { 'RP-100170', 'RP-100171', 'RP-100172', 'RP-100173' },
  FIRE_POINT_QUANXI_1 = { 'RP-44300', 'RP-44301', 'RP-44302', 'RP-44303' },
  AMMO_HOLDING_AREA_QUANXI = { 'RP-114547', 'RP-114548', 'RP-114549', 'RP-114550' },
  RELOAD_POINT_NEIPU = { 'RP-100166', 'RP-100167', 'RP-100168', 'RP-100169' },
  FIRE_POINT_NEIPU_1 = { 'RP-44288', 'RP-44289', 'RP-44290', 'RP-44291' },
  AMMO_HOLDING_AREA_NEIPU = { 'RP-114563', 'RP-114564', 'RP-114565', 'RP-114566' },
  RELOAD_POINT_LUZHU = { 'RP-107197', 'RP-107198', 'RP-107199', 'RP-107200' },
  FIRE_POINT_LUZHU_1 = { 'RP-107201', 'RP-107202', 'RP-107203', 'RP-107204' },
  AMMO_HOLDING_AREA_LUZHU = { 'RP-114435', 'RP-114436', 'RP-114437', 'RP-114438' },
  RELOAD_POINT_DONG = { 'RP-116585', 'RP-116586', 'RP-116587', 'RP-116588' },
  FIRE_POINT_DONG_1 = { 'RP-116593', 'RP-116594', 'RP-116595', 'RP-116596' },
  AMMO_HOLDING_AREA_DONG = { 'RP-116581', 'RP-116582', 'RP-116583', 'RP-116584' },
  THEATER_OF_OPS_3RD = { 'RP-83642', 'RP-83643', 'RP-83644', 'RP-83645' },
  THEATER_OF_OPS_2ND = { 'RP-156521', 'RP-156522', 'RP-156523', 'RP-156524', 'RP-156525', 'RP-156526' },
  THEATER_OF_OPS_5TH = {
    'RP-156527', 'RP-156528', 'RP-156529',
    'RP-156530', 'RP-156531', 'RP-156532',
    'RP-156533', 'RP-156534', 'RP-156535'
  },
  THEATER_OF_OPS_4TH = {
    'RP-156536', 'RP-156537', 'RP-156538',
    'RP-156539', 'RP-156540', 'RP-156541',
    'RP-156542', 'RP-156543', 'RP-156544',
    'RP-156545', 'RP-156546', 'RP-156547', 'RP-156548'
  },
  groundAscmTestNai1 = { 'RP-7760', 'RP-7761', 'RP-7762', 'RP-7763' },
  groundAscmTestNai2 = { 'RP-7787', 'RP-7788', 'RP-7789', 'RP-7790' },
}


-- Base GUIDs - Base identifiers
config.base = {
  -- China Bases (PLAAF / PLAN)
  HUIZHOU_PINGTAN_AB     = '6Z8LM5-0HMLLL9B5QBF0', -- Huizhou Pingtan AB (PLAAF)
  SHANTOU_WAISHA_AB      = '6Z8LM5-0HMLLEF9H5P44', -- Shantou Waisha AB (PLAAF)
  ZHANGPU_AAB            = 'X58F5H-0HN00TRR0Q1JQ', -- Zhangpu AAB
  ZHANGZHOU_LONGXI_AB    = '6Z8LM5-0HMIJ3QGCRQ2G', -- Zhangzhou-Longxi AB (PLAAF)
  HUIAN_AAB              = '6Z8LM5-0HMIJ3QGCRQ5F', -- Huian AAB
  LONGTIAN_AAB           = '6Z8LM5-0HMIJ3QGCRQC4', -- Longtian AAB
  XINGNING_AB            = '6Z8LM5-0HMLLEF9H7VDF', -- Xingning AB (PLAAF)
  SHUIMEN_AAB            = '6Z8LM5-0HMMJDEFRFJ4V', -- Shuimen AAB (PLAAF)
  ANQING_AB              = '6Z8LM5-0HMIJ7B8971MA', -- Anqing AB (PLAAF)
  WUHU_AB                = '6Z8LM5-0HMIJ7B896RA9', -- Wuhu AB (PLAAF)
  LIUAN_AB               = 'X58F5H-0HMRAQFR07T2V', -- Liuan AB
  PINGTAN_PORT           = '6Z8LM5-0HMMNGU6J8P2N', -- Pingtan Port (Amphibious Ops)
  KWANG_CHOW_WAN_NB      = '6Z8LM5-0HMJV6AONGLAU', -- Kwang Chow Wan Naval Base (PLAN) (Amphibious Ops)
  TAIZHOU_AB             = 'IC8B0X-0HNFDVSDK067T', -- Taizhou AB
  WUYISHAN_AB            = 'IC8B0X-0HNFDVSDK0AM9', -- Wuyishan AB
  RUGOA_AB               = 'X58F5H-0HN201E9DHM1C', -- Rugoa AB
  XIAHGTANG_AB           = '6Z8LM5-0HMIJ7B89707I', -- Xiahgtang AB (PLAAF)
  -- Taiwan Bases
  CHING_CHUANG_KANG_AB   = '6Z8LM5-0HMIHS2L949R0', -- Ching Chuang Kang AB (Taiwan)
  CHIAYI_AB              = '6Z8LM5-0HMIJ3QGCHSUB', -- Chiayi AB (Taiwan)
  TAINAN_AB              = '6Z8LM5-0HMIJ3QGCHVVS', -- Tainan AB (Taiwan)
  MAGONG_AB              = '6Z8LM5-0HMISSTNL3T8K', -- Magong AB (Taiwan)
  GUIREN_AAB             = 'IC8B0X-0HN37BVOG0T9O', -- Guiren AAB (Taiwan)
  PINGTUNG_NORTH_AB      = 'IC8B0X-0HNCTPETEF6GG', -- Pingtung North AB (Taiwan)
  TAITUNG_JHIHHANG_AB    = '6Z8LM5-0HMIJ3QGCI3V3', -- Taitung/Jhihhang AB (Taiwan)
  JIASHAN_AB             = '6Z8LM5-0HMIJ3QGCI783', -- Jiashan AB (Taiwan)
  HSINCHU_AB             = '6Z8LM5-0HMIK08HEK556', -- Hsinchu AB (Taiwan)
  LONGTAN_AAB            = 'IC8B0X-0HN3ADVRF2U7P', -- Longtan AAB (Taiwan)
  TAOYUAN_AIRPORT        = '6Z8LM5-0HMJ1GE4HSIU5', -- Taoyuan International Airport (Taiwan)
  RENDE_STRIP            = 'X58F5H-0HMU28MM77N82', -- Rende Emergency Highway Strip (Taiwan)
  MADOU_STRIP            = 'X58F5H-0HMU28MM7836P', -- Madou Emergency Highway Strip (Taiwan)
  MINXIONG_STRIP         = 'X58F5H-0HMU28MM78J9P', -- Minxiong Emergency Highway Strip (Taiwan)
  TAINAN_FIELD_AIRDROME  = 'IC8B0X-0HN81FNLB6M8Q', -- Tainan Field Airdrome (Taiwan)
  HSINCHU_FIELD_AIRDROME = 'IC8B0X-0HN81FNLB2OPJ', -- Hsinchu Field Airdrome (Taiwan)
  PORT_OF_KEELUNG        = 'X58F5H-0HMSMDQJ7LEUI', -- Port of Keelung (Taiwan)
  PINGTUNG_SOUTH_AB      = 'IC8B0X-0HNCTPETEF6F9', -- Pingtung South AB (Taiwan)
}

config.platform = {
  J16D = 4632,
  TYPE_726A = 2149,
  Z18 = 3708,
  TYPE_724 = 2511,
  KA52K = 2930,
  Z10 = 5856,
  TYPE_075 = 3153,
  TYPE_071 = 2006,
  TYPE_072III = 4683,
  TYPE_072A = 4602,
  TYPE_073A = 2925,
  TYPE_002 = 3187,
  WZ8 = 6642,
  BZK005 = 3309,
  CUSTOMED_TK3 = 391,
  PAC3 = 2227,
  JY26 = 2537,
  YLC8B = 2538,
  HQ22 = 3281,
  S300 = 386,
  S400 = 2442,
  HQ12 = 1277,
  PHL16 = 4324,
  SUPPLY = 624,
  PHL03 = 3126,
  GPS_JAMMER = 4582,
  UNDERGROUND_SHELTER = 1376,
  WEAPON_STORAGE_FACILITY = 322,
  J20 = 5014,
  J16 = 4926,
  SU30 = 4652,
  H6K = 1731,
  TYPE_072A_2 = 4601, -- Original comment was also Type 072A, added _2 to distinguish from DBID 4602
  TC2 = 4141,
  SKY_GUARD = 1092,
  Y9 = 4203,
  J35 = 4454,
  J15D = 4817,
  E2K = 2095,
  ZBD03 = 317,
  IL76 = 2503,
  FPS117 = 960,
  TPS43F = 1057,
  HR3000 = 1363,
  GE592 = 1362,
  RC135V = 5832,
  C2 = 3730,
  Y9DZ = 7064,
  TYPE_052D = 3587,
  TYPE_054A = 2714,
  AMMO_TRUCK = 2086,
  TYPE_055 = 3883,
  TYPE_901 = 2980,
  AMMO = 320,
  TYPE_076 = 4876,
  GJ11 = 4962,
  FERRY = 2566,
  J10C = 7419,
  ZBD05 = 241,
  ZTD05 = 240,
  PLL05 = 318,
  PLZ96 = 319,
  PGZ09 = 2876,
  PGZ95 = 758,
  HMMWV = 2034,
  MC = 2806,
  SA15 = 2162,
  M977 = 430,
  ZBD04 = 236,
  ZTZ96A = 245,
  BRIDGE = 4122,
  BARGE = 4925,
  KIDD = 2155,
  KANG_DING = 4149,
  S70C = 906,
  H6N = 7136,
  TYPE_093B = 665,
  BUNKER_SECTOR_CONTROL_STATION = 177,
  Y8Q_CUB = 3301,
  KJ500 = 3683,
  HY6U_BADGER = 823,
  J15 = 6098,
  Z18F_SEA_EAGLE = 3707,
  Z18J = 3303,
  KA28 = 4902,
  IDF = 3795,
  F16V_BLK20 = 3962,
  AH1W = 2126,
  P3C = 2825,
  C130HE = 4755,
  F16V_BLK70 = 6889,
  MQ9B = 6039,
  MIRAGE2000 = 175,
  AH64E = 2419,
  CHUNG_SHYANG_II = 5035,
  TA_CHIANG = 3441,
}

config.sensor = {
  S300_TOMBSTONE = 2788,
  S400_GRAVE_STONE = 4155,
  HQ12_H200 = 3396,
  HQ22_H200_IMPROVED = 6123,
  S300_CHEESE_BOARD = 3204,
  S400_CHEESE_BOARD = 5054,
  P3C_SEAVUE = 6847,
  E2K_APS145 = 2938,
  TK3_LONG_MOUNTAIN = 6366,
  TK3_LONG_WHITE_2 = 282,
  TK2_CS_MPG25 = 919,
  PAC3_MPQ65 = 2498,
  GPS_JAMMER = 2539,
  TC2_CS_MPQ90 = 6381,
}

config.loadout = {
  KA52_ATTACK = 30568,
  Z10_ATTACK = 31490,
  Z18_TRANSPORT_1 = 18367,
  Z18_TRANSPORT_2 = 18365,
  IL76_TRANSPORT = 25504,
  GJ11_RECON = 27825,
  J16_AKD88 = 26233,
  J16_YJ91 = 21747,
  J16D_OECM = 25444,
  J20_PL15 = 28027,
  SU30_YJ91 = 25378,
  Y8Q_ASW = 27636,
  SU30_KAB1500 = 25380,
  Y9_EW = 21678,
  Y9DZ_SIGINT = 33464,
  BZK005_RECON = 17495,
  H6K_YJ63 = 33615,
  J16_YJ83 = 21743,
  KJ500_AEW = 18300,
  HY6U_AAR = 8811,
  J10C_LS_6_500 = 25595,
  H6N_TRANSPORT = 8792,
  S70C_ASW = 845,
  J15_YJ91 = 9677,
  J15_LS6_500 = 34294,
  Z18F_CARRIER_ASW = 18368,
  Z18J_AEW = 17471,
  J15D_EW = 25212,
  KA28_ASW = 13926,
  IDF_WAN_CHIEN = 19104,
  F16V_BLK20_AMRAAM = 22785,
  F16V_BLK20_HARPOON = 22789,
  F16V_BLK20_GBU = 22790,
  AH1W_HELLFIRE = 7347,
  E2K_AEW = 14639,
  P3C_ASW = 13537,
  C130HE_EW = 25876,
  F16V_BLK70_SLAM_ER = 33012,
  F16V_BLK70_JDAM = 9479,
  F16V_BLK70_HARM = 9326,
  F16V_BLK70_JSOW = 9481,
  MQ9B_RECON = 32059,
  MIRAGE2000_MICA = 5732,
  AH64E_HELLFIRE = 15213,
  CHUNG_SHYANG_II_RECON = 28116,
}

config.weapon = {
  FD280 = 4472,       -- FD280 Multiple Launch Rocket System
  CJ10 = 2122,        -- CJ-10 Cruise Missile
  DF11A = 2142,       -- DF-11A Short-Range Ballistic Missile
  DF16A = 4511,       -- DF-16A Short-Range Ballistic Missile
  DF15C = 2145,       -- DF-15C Short-Range Ballistic Missile
  DF15B = 40,         -- DF-15B Short-Range Ballistic Missile
  DF21D = 2105,       -- DF-21D Medium-Range Ballistic Missile
  YJ21 = 4058,        -- YJ-18A Land Attack Cruise Missile
  CJ10_SLCM = 3716,   -- YJ-18 Submarine-Launched Cruise Missile
  AKD88 = 2876,       -- AKD-88 Air-to-Surface Missile
  PL15 = 3413,        -- PL-15 Air-to-Air Missile
  YJ91_ARM = 2875,    -- YJ-91 Anti-Radiation Missile
  YJ63 = 2107,        -- YJ-63 Air-Launched Cruise Missile
  KAB1500 = 3077,     -- KAB-1500 Laser-Guided Bomb
  LS_6_500 = 3226,    -- LS-6-500 Glide Bomb
  YJ91_ASM = 276,     -- YJ-91 Anti-Ship Missile
  YJ83 = 2137,        -- YJ-83 Anti-Ship Missile
  MK45_AMLRS = 2948,  -- MK45 AMLRS Multiple Launch Rocket System
  ATACMS = 1717,      -- ATACMS Tactical Missile System
  HF2E = 3228,        -- HF-2E Anti-Ship Cruise Missile
  HF2 = 1133,         -- HF-2 Anti-Ship Missile
  MK48_TORPEDO = 905, -- MK-48 Torpedo
}


config.radarDistance = 70
-- config.readytime = 3600 * 1.5
config.readytime = 5 * 60
---@enum CONFIG.batteryState
--- Battery states for the ground units
config.batteryState = {
  STATIC = 0,
  REPOSITIONING = 1,
  RELOAD = 2,
  HIDE = 3,
}

--Setup start time
config.c.triggers = {
  amphibiousOps = { startTime = '2027-06-09 02:40:00' },
  -- amphibiousOps = { startTime = '2027-06-09 1:00:00' },
  launchLACM = { startTime = '2027-06-09 06:00:00' },
  launchSLCM = { startTime = '2027-06-09 06:30:00' },
}


-- SIGINT
-- CONFIG.c.SIGINT.maxCount = 6
config.c.SIGINT.maxCount = 1
config.c.SIGINT.maxRange = 2.5

-- IADS
config.c.IADS.ratio = { C2 = 1.5, }
config.c.IADS.C2FacilityDBIDs = { 319, 318, 115, 113 }
config.c.IADS.randomRadius = 10
config.c.IADS.C2Settings = {
  {
    position = { lat = "N 25.30.37", lon = "E 119.30.54" },
    areas = { config.c.area.MILITARY_SUB_DISTRICT_FUZHOU, },
    areaName = 'Fuzhou'
  },
  {
    position = { lat = "N 25.19.12", lon = "E 119.06.36" },
    areas = { config.c.area.MILITARY_SUB_DISTRICT_PUTIAN, },
    areaName = 'Putian'
  },
  {
    position = { lat = "N 24.57.01", lon = "E 118.34.22" },
    areas = { config.c.area.MILITARY_SUB_DISTRICT_CHANGZHOU, },
    areaName = 'Changzhou'
  },
  {
    position = { lat = "N 24.43.19", lon = "E 118.12.29" },
    areas = { config.c.area.MILITARY_SUB_DISTRICT_XIAMEN, },
    areaName = 'Xiamen'
  },
  {
    position = { lat = "N 24.10.12", lon = "E 117.28.46" },
    areas = { config.c.area.MILITARY_SUB_DISTRICT_ZHANGZHOU, },
    areaName = 'Zhangzhou'
  },
  {
    position = { lat = "N 23.39.17", lon = "E 116.41.26" },
    areas = { config.c.area.MILITARY_SUB_DISTRICT_SHANTOU, },
    areaName = 'Shantou'
  },
  {
    position = { lat = "N 23.08.19", lon = "E 115.22.49" },
    areas = { config.c.area.MILITARY_SUB_DISTRICT_SHANWEI, },
    areaName = 'Shanwei'
  },
  {
    position = { lat = "N 24.06.12", lon = "E 116.05.36" },
    areas = { config.c.area.MILITARY_SUB_DISTRICT_MEIZHOU, },
    areaName = 'Meizhou'
  },
}

-- Comms Jamming
config.c.commsJamming.limit = 6
config.c.commsJamming.range = 75
config.c.commsJamming.initialComms = -20
config.c.commsJamming.baseJammingPower = -120
config.c.commsJamming.distanceExponent = 1.04
config.c.commsJamming.effectivenessFormula = { base = 1.9, range = 1.8 }
config.c.commsJamming.aewSupport = {
  close = 400,  -- < 100nm
  medium = 350, -- < 200nm
  far = 250,    -- < 300nm
  distant = 150 -- < 400nm
}
config.c.commsJamming.recoveryTime = { min = 15, max = 25 }
config.c.commsJamming.jammingTime = { min = 5, max = 10 }
config.c.commsJamming.cooldownTime = { min = -5, max = -1 }
config.c.commsJamming.randomVariance = {
  close = { min = -1, max = 1 },
  medium = { min = -3, max = 3 },
  far = { min = -6, max = 6 },
  distant = { min = -10, max = 10 }
}

-- GPS Jamming
config.c.GPSJamming.jammers = {
  { zoneName = 'JAMMING ZONE/1', name = '1st Bn, 1st ECM Bde', point = { lat = 'N 25.28.17', lon = 'E 119.35.17' }, randomRadius = 20, radius = 14 },
  { zoneName = 'JAMMING ZONE/2', name = '2nd Bn, 1st ECM Bde', point = { lat = 'N 24.43.49', lon = 'E 118.29.41' }, randomRadius = 20, radius = 14 },
}

-- MLRS
config.c.ground.mlrs.wpnDefault = 192
config.c.ground.mlrs.ammoThreshold = 50
config.c.ground.mlrs.positions = {
  pingtan = {
    RL = {
      course = {
        { lat = 'N 25.30.20', lon = 'E 119.46.50', desiredSpeed = 30, presetThrottle = 'Flank' },
        { lat = 'N 25.30.13', lon = 'E 119.47.36', desiredSpeed = 30, presetThrottle = 'Flank' },
      },
      area = config.c.area.RELOAD_POINT_PINGTAN
    },
    HA = {
      course = {
        { lat = 'N 25.30.02', lon = 'E 119.47.17', desiredSpeed = 30, presetThrottle = 'Flank' },
      },
      area = config.c.area.HIDE_AREA_PINGTAN
    },
    FP = {
      {
        course = {
          { lat = 'N 25.30.20', lon = 'E 119.46.50', desiredSpeed = 30, presetThrottle = 'Flank' },
          { lat = 'N 25.25.45', lon = 'E 119.44.25', desiredSpeed = 30, presetThrottle = 'Flank' },
        },
        area = config.c.area.FIRE_POINT_PINGTAN_1
      },
      {
        course = {
          { lat = 'N 25.30.20', lon = 'E 119.46.50', desiredSpeed = 30, presetThrottle = 'Flank' },
          { lat = 'N 25.27.22', lon = 'E 119.45.39', desiredSpeed = 30, presetThrottle = 'Flank' },
        },
        area = config.c.area.FIRE_POINT_PINGTAN_2
      },
    },
    AHA = {
      course = {
        { lat = 'N 25.30.31', lon = 'E 119.47.37', desiredSpeed = 30, presetThrottle = 'Flank' },
      },
      area = config.c.area.AMMO_HOLDING_AREA_PINGTAN
    },
  },
  chinchew = {
    RL = {
      course = {
        { lat = 'N 24.46.44', lon = 'E 118.40.37', desiredSpeed = 30, presetThrottle = 'Flank' },
        { lat = 'N 24.46.36', lon = 'E 118.42.17', desiredSpeed = 30, presetThrottle = 'Flank' },
      },
      area = config.c.area.RELOAD_POINT_CHINCHEW
    },
    HA = {
      course = {
        { lat = 'N 24.46.31', lon = 'E 118.41.51', desiredSpeed = 30, presetThrottle = 'Flank' },
      },
      area = config.c.area.HIDE_AREA_CHINCHEW
    },
    FP = {
      {
        course = {
          { lat = 'N 24.46.44', lon = 'E 118.40.37', desiredSpeed = 30, presetThrottle = 'Flank' },
          { lat = 'N 24.41.45', lon = 'E 118.43.18', desiredSpeed = 30, presetThrottle = 'Flank' },
        },
        area = config.c.area.FIRE_POINT_CHINCHEW_1
      },
    },
    AHA = {
      course = {
        { lat = 'N 24.47.10', lon = 'E 118.42.22', desiredSpeed = 30, presetThrottle = 'Flank' },
      },
      area = config.c.area.AMMO_HOLDING_AREA_CHINCHEW
    },
  },
}
config.c.ground.mlrs.contactAge = 30 * 60
config.c.ground.mlrs.reloadTime = 30 * 60

-- GLCM
config.c.ground.glcm.wpnDefault = 48
config.c.ground.glcm.ammoThreshold = 50
config.c.ground.glcm.positions = {
  brigade635 = {
    RL = {
      course = {
        { lat = 'N 24.46.44', lon = 'E 118.40.37', desiredSpeed = 30, presetThrottle = 'Flank' },
        { lat = 'N 24.46.36', lon = 'E 118.42.17', desiredSpeed = 30, presetThrottle = 'Flank' },
      },
      area = config.c.area.RELOAD_POINT_CHINCHEW
    },
    HA = {
      course = {
        { lat = 'N 24.46.31', lon = 'E 118.41.51', desiredSpeed = 30, presetThrottle = 'Flank' },
      },
      area = config.c.area.HIDE_AREA_CHINCHEW
    },
    FP = {
      {
        course = {
          { lat = 'N 24.46.44', lon = 'E 118.40.37', desiredSpeed = 30, presetThrottle = 'Flank' },
          { lat = 'N 24.41.45', lon = 'E 118.43.18', desiredSpeed = 30, presetThrottle = 'Flank' },
        },
        area = config.c.area.FIRE_POINT_CHINCHEW_1
      },
    },
    AHA = {
      course = {
        { lat = 'N 24.47.10', lon = 'E 118.42.22', desiredSpeed = 30, presetThrottle = 'Flank' },
      },
      area = config.c.area.AMMO_HOLDING_AREA_CHINCHEW
    },
  },
}
config.c.ground.glcm.contactAge = 30 * 60
config.c.ground.glcm.reloadTime = 45 * 60

-- SRBM
config.c.ground.srbm.wpnDefault = 36
config.c.ground.srbm.ammoThreshold = 35
config.c.ground.srbm.positions = {
  brigade615 = {
    RL = {
      course = {
        { lat = 'N 24.17.32', lon = 'E 115.58.09', desiredSpeed = 30, presetThrottle = 'Flank' },
        { lat = 'N 24.16.56', lon = 'E 115.58.12', desiredSpeed = 30, presetThrottle = 'Flank' },
      },
      area = config.c.area.RELOAD_POINT_BRIGADE615
    },
    HA = {
      course = {
        { lat = 'N 24.17.06', lon = 'E 115.58.35', desiredSpeed = 30, presetThrottle = 'Flank' },
      },
      area = config.c.area.HIDE_AREA_BRIGADE615
    },
    FP = {
      {
        course = {
          { lat = 'N 24.17.32', lon = 'E 115.58.09', desiredSpeed = 30, presetThrottle = 'Flank' },
          { lat = 'N 24.17.05', lon = 'E 115.59.41', desiredSpeed = 30, presetThrottle = 'Flank' },
        },
        area = config.c.area.FIRE_POINT_BRIGADE615_1
      },
    },
    AHA = {
      course = {
        { lat = 'N 24.17.05', lon = 'E 115.58.00', desiredSpeed = 30, presetThrottle = 'Flank' },
      },
      area = config.c.area.AMMO_HOLDING_AREA_BRIGADE615
    },
  },
  brigade614 = {
    RL = {
      course = {
        { lat = 'N 26.04.01', lon = 'E 117.18.55', desiredSpeed = 30, presetThrottle = 'Flank' },
        { lat = 'N 26.03.40', lon = 'E 117.18.55', desiredSpeed = 30, presetThrottle = 'Flank' },
      },
      area = config.c.area.RELOAD_POINT_BRIGADE614
    },
    HA = {
      course = {
        { lat = 'N 26.03.48', lon = 'E 117.19.11', desiredSpeed = 30, presetThrottle = 'Flank' },
      },
      area = config.c.area.HIDE_AREA_BRIGADE614
    },
    FP = {
      {
        course = {
          { lat = 'N 26.04.18', lon = 'E 117.18.51', desiredSpeed = 30, presetThrottle = 'Flank' },
          { lat = 'N 26.03.49', lon = 'E 117.20.05', desiredSpeed = 30, presetThrottle = 'Flank' },
        },
        area = config.c.area.FIRE_POINT_BRIGADE614_1
      },
    },
    AHA = {
      course = {
        { lat = 'N 26.03.47', lon = 'E 117.18.50', desiredSpeed = 30, presetThrottle = 'Flank' },
      },
      area = config.c.area.AMMO_HOLDING_AREA_BRIGADE614
    },
  },
  brigade636 = {
    RL = {
      course = {
        { lat = 'N 24.45.52', lon = 'E 113.40.52', desiredSpeed = 30, presetThrottle = 'Flank' },
        { lat = 'N 24.45.25', lon = 'E 113.40.29', desiredSpeed = 30, presetThrottle = 'Flank' },
      },
      area = config.c.area.RELOAD_POINT_BRIGADE636
    },
    HA = {
      course = {
        { lat = 'N 24.45.33', lon = 'E 113.40.47', desiredSpeed = 30, presetThrottle = 'Flank' },
      },
      area = config.c.area.HIDE_AREA_BRIGADE636
    },
    FP = {
      {
        course = {
          { lat = 'N 24.45.52', lon = 'E 113.40.52', desiredSpeed = 30, presetThrottle = 'Flank' },
          { lat = 'N 24.45.52', lon = 'E 113.41.35', desiredSpeed = 30, presetThrottle = 'Flank' },
        },
        area = config.c.area.FIRE_POINT_BRIGADE636_1
      },
    },
    AHA = {
      course = {
        { lat = 'N 24.45.34', lon = 'E 113.40.14', desiredSpeed = 30, presetThrottle = 'Flank' },
      },
      area = config.c.area.AMMO_HOLDING_AREA_BRIGADE636
    },
  },
  brigade616 = {
    RL = {
      course = {
        { lat = 'N 25.54.31', lon = 'E 114.57.21', desiredSpeed = 30, presetThrottle = 'Flank' },
      },
      area = config.c.area.RELOAD_POINT_BRIGADE616
    },
    HA = {
      course = {
        { lat = 'N 25.54.40', lon = 'E 114.57.42', desiredSpeed = 30, presetThrottle = 'Flank' },
      },
      area = config.c.area.HIDE_AREA_BRIGADE616
    },
    FP = {
      {
        course = {
          { lat = 'N 25.55.33', lon = 'E 114.58.25', desiredSpeed = 30, presetThrottle = 'Flank' },
        },
        area = config.c.area.FIRE_POINT_BRIGADE616_1
      },
    },
    AHA = {
      course = {
        { lat = 'N 25.54.38', lon = 'E 114.57.06', desiredSpeed = 30, presetThrottle = 'Flank' },
      },
      area = config.c.area.AMMO_HOLDING_AREA_BRIGADE616
    },
  },
  brigade613 = {
    RL = {
      course = {
        { lat = 'N 28.27.25', lon = 'E 117.51.51', desiredSpeed = 30, presetThrottle = 'Flank' },
        { lat = 'N 28.27.26', lon = 'E 117.51.02', desiredSpeed = 30, presetThrottle = 'Flank' },
        { lat = 'N 28.27.03', lon = 'E 117.51.04', desiredSpeed = 30, presetThrottle = 'Flank' },
      },
      area = config.c.area.RELOAD_POINT_BRIGADE613
    },
    HA = {
      course = {
        { lat = 'N 28.27.12', lon = 'E 117.51.17', desiredSpeed = 30, presetThrottle = 'Flank' },
      },
      area = config.c.area.HIDE_AREA_BRIGADE613
    },
    FP = {
      {
        course = {
          { lat = 28.455760146701, lon = 117.85790803852, desiredSpeed = 30, presetThrottle = 'Flank' },
          { lat = 28.455941652975, lon = 117.86516402324, desiredSpeed = 30, presetThrottle = 'Flank' },
          { lat = 28.443410902986, lon = 117.86719441616, desiredSpeed = 30, presetThrottle = 'Flank' },
        },
        area = config.c.area.FIRE_POINT_BRIGADE613_1
      },
    },
    AHA = {
      course = {
        { lat = 'N 28.27.12', lon = 'E 117.50.55', desiredSpeed = 30, presetThrottle = 'Flank' },
      },
      area = config.c.area.AMMO_HOLDING_AREA_BRIGADE613
    },
  },
  brigade617 = {
    RL = {
      course = {
        { lat = 'N 29.09.32', lon = 'E 119.36.38', desiredSpeed = 30, presetThrottle = 'Flank' },
        { lat = 'N 29.08.57', lon = 'E 119.36.31', desiredSpeed = 30, presetThrottle = 'Flank' },
      },
      area = config.c.area.RELOAD_POINT_BRIGADE617
    },
    HA = {
      course = {
        { lat = 'N 29.09.01', lon = 'E 119.36.49', desiredSpeed = 30, presetThrottle = 'Flank' },
      },
      area = config.c.area.HIDE_AREA_BRIGADE617
    },
    FP = {
      {
        course = {
          { lat = 29.158533243915, lon = 119.61541712539, desiredSpeed = 30, presetThrottle = 'Flank' },
          { lat = 29.158295428459, lon = 119.62849131226, desiredSpeed = 30, presetThrottle = 'Flank' },
        },
        area = config.c.area.FIRE_POINT_BRIGADE617_1
      },
    },
    AHA = {
      course = {
        { lat = 'N 29.09.03', lon = 'E 119.36.26', desiredSpeed = 30, presetThrottle = 'Flank' },
      },
      area = config.c.area.AMMO_HOLDING_AREA_BRIGADE617
    },
  },
}
config.c.ground.srbm.contactAge = 30 * 60
config.c.ground.srbm.reloadTime = 5 * 60

-- MRBM
config.c.ground.mrbm.wpnDefault = 24
config.c.ground.mrbm.ammoThreshold = 35
config.c.ground.mrbm.positions = {
  brigade624 = {
    RL = {
      course = {
        { lat = 'N 19.29.01', lon = 'E 109.26.40', desiredSpeed = 30, presetThrottle = 'Flank' },
        { lat = 'N 19.28.27', lon = 'E 109.26.56', desiredSpeed = 30, presetThrottle = 'Flank' },
        { lat = 'N 19.28.29', lon = 'E 109.27.44', desiredSpeed = 30, presetThrottle = 'Flank' },
      },
      area = config.c.area.RELOAD_POINT_BRIGADE624
    },
    HA = {
      course = {
        { lat = 'N 19.28.35', lon = 'E 109.27.22', desiredSpeed = 30, presetThrottle = 'Flank' },
      },
      area = config.c.area.HIDE_AREA_BRIGADE624
    },
    FP = {
      {
        course = {
          { lat = 'N 19.29.01', lon = 'E 109.26.40', desiredSpeed = 30, presetThrottle = 'Flank' },
          { lat = 'N 19.29.40', lon = 'E 109.27.17', desiredSpeed = 30, presetThrottle = 'Flank' },
        },
        area = config.c.area.FIRE_POINT_BRIGADE624_1
      },
    },
    AHA = {
      course = {
        { lat = 'N 19.28.12', lon = 'E 109.27.21', desiredSpeed = 30, presetThrottle = 'Flank' },
      },
      area = config.c.area.AMMO_HOLDING_AREA_BRIGADE624
    },
  },
}
config.c.ground.mrbm.contactAge = 15 * 60
config.c.ground.mrbm.reloadTime = 5 * 60

-- Recon
config.c.recon.bases = {
  H6N = { guid = config.base.LIUAN_AB },
  BZK005 = { guid = config.base.LONGTIAN_AAB }
}
config.c.recon.contactAge = 15 * 60
config.c.recon.courses = {
  WZ8 = {
    -- {
    --   { lat = 'N 25.53.18', lon = 'E 121.32.54', desiredAltitude = 30480, desiredSpeed = 3300 },
    --   { lat = 'N 24.58.25', lon = 'E 121.41.17', desiredAltitude = 30480, desiredSpeed = 3300 },
    --   { lat = 'N 24.38.39', lon = 'E 121.41.42', desiredAltitude = 30480, desiredSpeed = 3300 },
    --   { lat = 'N 24.05.04', lon = 'E 121.22.33', desiredAltitude = 30480, desiredSpeed = 3300 },
    --   { lat = 'N 22.52.27', lon = 'E 121.06.41', desiredAltitude = 30480, desiredSpeed = 3300 },
    --   { lat = 'N 22.31.53', lon = 'E 120.29.25', desiredAltitude = 30480, desiredSpeed = 3300 },
    --   { lat = 'N 23.21.08', lon = 'E 120.19.55', desiredAltitude = 30480, desiredSpeed = 3300 },
    --   { lat = 'N 24.16.15', lon = 'E 120.29.30', desiredAltitude = 30480, desiredSpeed = 3300 },
    --   { lat = 'N 25.09.57', lon = 'E 121.08.54', desiredAltitude = 30480, desiredSpeed = 3300 },
    -- },
    -- {
    --   { lat = 'N 25.08.36', lon = 'E 122.40.26', desiredAltitude = 30480, desiredSpeed = 3300 },
    --   { lat = 'N 21.21.28', lon = 'E 121.20.36', desiredAltitude = 30480, desiredSpeed = 3300 },
    -- },
    {
      { lat = 'N 24.59.45', lon = 'E 121.59.21', desiredAltitude = 30480, desiredSpeed = 3300 },
      { lat = 'N 24.01.38', lon = 'E 121.37.51', desiredAltitude = 30480, desiredSpeed = 3300 },
      { lat = 'N 21.55.32', lon = 'E 120.51.30', desiredAltitude = 30480, desiredSpeed = 3300 },
      { lat = 'N 22.41.05', lon = 'E 120.27.58', desiredAltitude = 30480, desiredSpeed = 3300 },
      { lat = 'N 22.57.13', lon = 'E 120.12.37', desiredAltitude = 30480, desiredSpeed = 3300 },
      { lat = 'N 23.28.13', lon = 'E 120.22.57', desiredAltitude = 30480, desiredSpeed = 3300 },
      { lat = 'N 24.15.54', lon = 'E 120.38.12', desiredAltitude = 30480, desiredSpeed = 3300 },
      { lat = 'N 25.14.02', lon = 'E 121.21.47', desiredAltitude = 30480, desiredSpeed = 3300 },
    }
  },
  H6N = {
    { lat = 'N 29.47.52', lon = 'E 119.19.47', desiredAltitude = 13716, desiredSpeed = 450 },
    { lat = 'N 25.57.34', lon = 'E 121.32.45', desiredAltitude = 13716, desiredSpeed = 550 },
  }
}
config.c.recon.template = {
  BZK005_RECON_1 = {
    baseGUID = config.base.LONGTIAN_AAB,
    unitDBID = config.platform.BZK005,
    unitGUID = nil,
    missionName = 'RECON/1',
    course = { { lat = 'N 25.27.28', lon = 'E 120.46.09' } },
    unitCount = 1,
    -- takeoffTime = '2027-06-09 01:00:00',
    takeoffTime = nil,
    -- missionStartTime = '2027-06-09 01:30:00',
    missionStartTime = nil,
  },
  BZK005_RECON_2 = {
    baseGUID = config.base.SHANTOU_WAISHA_AB,
    unitDBID = config.platform.BZK005,
    unitGUID = nil,
    missionName = 'RECON/2',
    course = { { lat = 'N 25.27.28', lon = 'E 120.46.09' } },
    unitCount = 1,
    -- takeoffTime = '2027-06-09 01:00:00',
    takeoffTime = nil,
    -- missionStartTime = '2027-06-09 01:30:00',
    missionStartTime = nil,
  },
  -- WZ8_RECON_EAST_WATER = {
  --   baseGUID = config.base.LIUAN_AB,
  --   unitDBID = config.platform.H6N,
  --   unitGUID = nil,
  --   missionName = nil,
  --   course = config.c.recon.courses.H6N,
  --   unitCount = 1,
  --   -- takeoffTime = '2027-06-09 01:20:00',
  --   -- takeoffTime = '2027-06-09 01:00:00',
  --   missionStartTime = nil,
  --   -- hasLaunched = false,
  --   isTracking = true
  -- },
  WZ8_RECON_ISLAND = {
    baseGUID = config.base.LIUAN_AB,
    unitDBID = config.platform.H6N,
    unitGUID = nil,
    missionName = nil,
    course = config.c.recon.courses.H6N,
    unitCount = 1,
    -- takeoffTime = '2027-06-09 01:20:00',
    -- takeoffTime = '2027-06-09 01:00:00',
    missionStartTime = nil,
    -- hasLaunched = false,
    isTracking = true
  },
}
config.c.recon.flightTime = {
  BZK005_RECON_1 = 60 * 60,
  BZK005_RECON_2 = 120 * 60,
  H6N_RECON = 65 * 60,
}

-- Aircraft deployment
config.c.air.landBased.deployedACs = {
  {
    name = 'Huizhou Pingtan AB (PLAAF)',
    baseGUID = config.base.HUIZHOU_PINGTAN_AB,
    embarkedUnits = {
      {
        side = 'China',
        type = 'Air',
        dbid = config.platform.Y8Q_CUB,
        name = '1st Naval AF Div',
        loadouts = {
          { loadoutId = config.loadout.Y8Q_ASW, num = 3, missionName = 'ASW/PATROL AC' },
        }
      }
    }
  },
  {
    name = 'Shantou Waisha AB (PLAAF)',
    baseGUID = config.base.SHANTOU_WAISHA_AB,
    embarkedUnits = {
      {
        side = 'China',
        type = 'Air',
        dbid = config.platform.J16,
        name = '7th Air Bde',
        loadouts = {
          { loadoutId = config.loadout.J16_AKD88, num = 24 },
        }
      },
      {
        side = 'China',
        type = 'Air',
        dbid = config.platform.BZK005,
        name = '60th Det, PLARF UAV Reg',
        loadouts = {
          { loadoutId = config.loadout.BZK005_RECON, num = 6 },
        }
      },
    },
    loadouts = {
      { loadoutId = config.loadout.J16_AKD88, num = 24 }, --AKD-88 X 2
    }
  },
  {
    name = 'Zhangpu AAB',
    baseGUID = config.base.ZHANGPU_AAB,
    embarkedUnits = {
      {
        side = 'China',
        type = 'Air',
        dbid = config.platform.SU30,
        name = '804th Air Bde',
        loadouts = {
          { loadoutId = config.loadout.SU30_KAB1500, num = 12 },
        }
      },
      {
        side = 'China',
        type = 'Air',
        dbid = config.platform.Y9,
        name = '60th Air Reg',
        loadouts = {
          { loadoutId = config.loadout.Y9_EW, num = 3 },
        }
      },
      {
        side = 'China',
        type = 'Air',
        dbid = config.platform.IL76,
        name = '39th Air Reg',
        loadouts = {
          { loadoutId = config.loadout.IL76_TRANSPORT, num = 3 },
        }
      },
      {
        side = 'China',
        type = 'Air',
        dbid = config.platform.Y9DZ,
        name = '60th Air Reg',
        loadouts = {
          { loadoutId = config.loadout.Y9DZ_SIGINT, num = 3, missionName = 'SIGINT' },
        }
      },
    },
    loadouts = {
      { loadoutId = config.loadout.SU30_KAB1500, num = 12 }, --KAB-1500 X 2
    }
  },
  {
    name = 'Zhangzhou-Longxi AB (PLAAF)',
    baseGUID = config.base.ZHANGZHOU_LONGXI_AB,
    embarkedUnits = {
      {
        side = 'China',
        type = 'Air',
        dbid = config.platform.SU30,
        name = '804th Air Bde',
        loadouts = {
          { loadoutId = config.loadout.SU30_YJ91, num = 24 },
        }
      }
    },
    loadouts = {
      { loadoutId = config.loadout.SU30_YJ91, num = 24 }, --YJ-91 X 2
    }
  },
  {
    name = 'Huian AAB',
    baseGUID = config.base.HUIAN_AAB,
    embarkedUnits = {
      {
        side = 'China',
        type = 'Air',
        dbid = config.platform.J16,
        name = '40th Air Bde',
        loadouts = {
          { loadoutId = config.loadout.J16_AKD88, num = 12 },
        }
      },
      {
        side = 'China',
        type = 'Air',
        dbid = config.platform.J20,
        name = '41st Air Bde',
        loadouts = {
          { loadoutId = config.loadout.J20_PL15, num = 12 },
        }
      },
    },
    loadouts = {
      { loadoutId = config.loadout.J20_PL15,  num = 12 }, --PL-15 X 4
      { loadoutId = config.loadout.J16_AKD88, num = 12 }, --AKD-88 X 2
    }
  },
  {
    name = 'Longtian AAB',
    baseGUID = config.base.LONGTIAN_AAB,
    embarkedUnits = {
      {
        side = 'China',
        type = 'Air',
        dbid = config.platform.BZK005,
        name = '62nd Det, PLARF UAV Reg',
        loadouts = {
          { loadoutId = config.loadout.BZK005_RECON, num = 6 },
        }
      },
      {
        side = 'China',
        type = 'Air',
        dbid = config.platform.SU30,
        name = '804th Air Bde',
        loadouts = {
          { loadoutId = config.loadout.SU30_YJ91, num = 8 },
        }
      }
    },
    loadouts = {
      { loadoutId = config.loadout.SU30_YJ91, num = 8 }, --YJ-91 X 2
    }
  },
  {
    name = 'Xingning AB (PLAAF)',
    baseGUID = config.base.XINGNING_AB,
    embarkedUnits = {
      {
        side = 'China',
        type = 'Air',
        dbid = config.platform.H6K,
        name = '29th Air Reg',
        loadouts = {
          { loadoutId = config.loadout.H6K_YJ63, num = 12 },
        }
      }
    },
    loadouts = {
      { loadoutId = config.loadout.H6K_YJ63, num = 12 }, --YJ-63 X 4
    }
  },
  {
    name = 'Shuimen AAB (PLAAF)',
    baseGUID = config.base.SHUIMEN_AAB,
    embarkedUnits = {
      {
        side = 'China',
        type = 'Air',
        dbid = config.platform.SU30,
        name = '804th Air Bde',
        loadouts = {
          { loadoutId = config.loadout.SU30_YJ91, num = 8 },
        }
      },
      {
        side = 'China',
        type = 'Air',
        dbid = config.platform.J16,
        name = '40th Air Bde',
        loadouts = {
          { loadoutId = config.loadout.J16_YJ83, num = 8 },
        }
      },
      {
        side = 'China',
        type = 'Air',
        dbid = config.platform.KJ500,
        name = '75th Air Reg',
        loadouts = {
          { loadoutId = config.loadout.KJ500_AEW, num = 3, missionName = 'AEW/N' },
        }
      },
      {
        side = 'China',
        type = 'Air',
        dbid = config.platform.HY6U_BADGER,
        name = '23rd Air Reg',
        loadouts = {
          { loadoutId = config.loadout.HY6U_AAR, num = 8, },
        }
      },
      {
        side = 'China',
        type = 'Air',
        dbid = config.platform.J10C,
        name = '25th Air Bde',
        loadouts = {
          { loadoutId = config.loadout.J10C_LS_6_500, num = 8 },
        }
      },
    },
    loadouts = {
      { loadoutId = config.loadout.SU30_YJ91,     num = 8 }, --YJ-91 X 2
      { loadoutId = config.loadout.J16_YJ83,      num = 8 }, --YJ-83 X 2
      { loadoutId = config.loadout.J10C_LS_6_500, num = 8 }, --LS-6-500 X 2
    }
  },
  {
    name = 'Anqing AB (PLAAF)',
    baseGUID = config.base.ANQING_AB,
    embarkedUnits = {
      {
        side = 'China',
        type = 'Air',
        dbid = config.platform.H6K,
        name = '28th Air Reg',
        loadouts = {
          { loadoutId = config.loadout.H6K_YJ63, num = 12 },
        }
      }
    },
    loadouts = {
      { loadoutId = config.loadout.H6K_YJ63, num = 12 }, --YJ-63 X 4
    }
  },
  {
    name = 'Wuhu AB (PLAAF)',
    baseGUID = config.base.WUHU_AB,
    embarkedUnits = {
      {
        side = 'China',
        type = 'Air',
        dbid = config.platform.J20,
        name = '9th Air Bde',
        loadouts = {
          { loadoutId = config.loadout.J20_PL15, num = 12 },
        }
      }
    },
    loadouts = {
      { loadoutId = config.loadout.J20_PL15, num = 12 }, --PL-15 X 4
    }
  },
  {
    name = 'Liuan AB',
    baseGUID = config.base.LIUAN_AB,
    embarkedUnits = {
      {
        side = 'China',
        type = 'Air',
        dbid = config.platform.H6N,
        name = '107th Air Reg',
        loadouts = {
          { loadoutId = config.loadout.H6N_TRANSPORT, num = 4 },
        }
      }
    }
  },
  {
    name = 'Taizhou AB (PLAAF)',
    baseGUID = config.base.TAIZHOU_AB,
    embarkedUnits = {
      {
        side = 'China',
        type = 'Air',
        dbid = config.platform.SU30,
        name = '94th Air Bde',
        loadouts = {
          { loadoutId = config.loadout.SU30_YJ91, num = 12 },
        }
      }
    },
    loadouts = {
      { loadoutId = config.loadout.SU30_YJ91, num = 12 }, --YJ-91 X 4
    }
  },
  {
    name = 'Rugoa AB (PLAAF)',
    baseGUID = config.base.RUGOA_AB,
    embarkedUnits = {
      {
        side = 'China',
        type = 'Air',
        dbid = config.platform.J16,
        name = '7th Air Bde',
        loadouts = {
          { loadoutId = config.loadout.J16_AKD88, num = 12 },
          { loadoutId = config.loadout.J16_YJ91,  num = 12 },
        }
      }
    },
    loadouts = {
      { loadoutId = config.loadout.J16_AKD88, num = 12 }, --AKD-88 X 4
      { loadoutId = config.loadout.J16_YJ91,  num = 12 }, --YJ-91 X 4
    }
  },
  {
    name = 'Nanchang Xiangtang AB (PLAAF)',
    baseGUID = config.base.XIAHGTANG_AB,
    embarkedUnits = {
      {
        side = 'China',
        type = 'Air',
        dbid = config.platform.J16D,
        name = '40th Air Bde',
        loadouts = {
          { loadoutId = config.loadout.J16D_OECM, num = 8 },
        }
      }
    },
    loadouts = {
      { loadoutId = config.loadout.J16D_OECM, num = 8 },
    }
  }
  -- {
  --   name = 'Wuyishan AB',
  --   baseGUID = config.base.WUYISHAN_AB,
  --   embarkedUnits = {
  --     {
  --       side = 'China',
  --       type = 'Air',
  --       dbid = config.platform.J20,
  --       name = '41st Air Bde',
  --       loadouts = {
  --         { loadoutId = config.loadout.J20_PL15, num = 12 },
  --       }
  --     }
  --   },
  --   loadouts = {
  --     { loadoutId = config.loadout.J20_PL15, num = 12 }, --PL-15 X 4
  --   }
  -- }
}

-- Amphibious ops
config.c.PHIBOP.periodOfTime = 5 * 60
---@class CargoItem:table
---@field type number
---@field num number
---@field dbid number

config.c.PHIBOP.cargoList = {
  ---@type table<number, CargoItem>
  type075 = {
    ---@type CargoItem
    { type = 2, num = 21, dbid = config.platform.PLL05 }, -- PLL-05 11
    { type = 2, num = 12, dbid = config.platform.PLZ96 }, -- PLZ-96 12
    { type = 3, num = 3,  dbid = config.platform.PGZ09 }, -- PGZ-09 3
    { type = 3, num = 1,  dbid = config.platform.PGZ95 }, -- PGZ-95 1
    { type = 3, num = 30, dbid = config.platform.HMMWV }, -- HMMWV 30
    { type = 3, num = 76, dbid = config.platform.MC },    -- MC 76
  },
  ---@type table<number, CargoItem>
  type071 = {
    { type = 2, num = 5,  dbid = config.platform.PLL05 }, -- PLL-05 11
    { type = 2, num = 12, dbid = config.platform.PLZ96 }, -- PLZ-96 12
    { type = 3, num = 3,  dbid = config.platform.PGZ09 }, -- PGZ-09 3
    { type = 3, num = 1,  dbid = config.platform.PGZ95 }, -- PGZ-95 1
    { type = 3, num = 2,  dbid = config.platform.SA15 },  -- SA-15 2
    { type = 3, num = 22, dbid = config.platform.MC }     -- MC
  },
  ---@type table<number, CargoItem>
  type072iii = {
    { type = 2, num = 5, dbid = config.platform.ZBD05 }, -- ZBD-05
    { type = 2, num = 5, dbid = config.platform.ZTD05 }, -- ZTD-05
    { type = 3, num = 6, dbid = config.platform.MC }
  },
  ---@type table<number, CargoItem>
  type072a = {
    { type = 2, num = 5, dbid = config.platform.ZBD05 }, -- ZBD-05
    { type = 2, num = 5, dbid = config.platform.ZTD05 }, -- ZTD-05
    { type = 3, num = 6, dbid = config.platform.MC }
  },
  ---@type table<number, CargoItem>
  type073a = {
    { type = 2, num = 3, dbid = config.platform.ZBD05 },
    { type = 2, num = 3, dbid = config.platform.ZTD05 }, -- ZTD-05
  },
  ---@type table<number, CargoItem>
  ferry = {
    { type = 2, num = 56, dbid = config.platform.ZBD05 }, -- ZBD-05
    { type = 2, num = 56, dbid = config.platform.ZTD05 }, -- ZTD-05
  },
  ---@type table<number, CargoItem>
  barge = {
    { type = 2, num = 28, dbid = config.platform.ZBD04 },  -- ZBD-04
    { type = 2, num = 28, dbid = config.platform.ZTZ96A }, -- ZTZ-96A
    { type = 2, num = 9,  dbid = config.platform.PLL05 },  -- PLL-05
    { type = 3, num = 2,  dbid = config.platform.PGZ95 },  -- PGZ-95
    { type = 3, num = 1,  dbid = config.platform.PGZ09 },  -- PGZ-09
    { type = 2, num = 7,  dbid = config.platform.PLZ96 },  -- PLZ-07/PLZ-96
    { type = 3, num = 1,  dbid = config.platform.SA15 },   -- SA-15
    { type = 2, num = 4,  dbid = config.platform.M977 },   -- M977
  }
}
config.c.PHIBOP.cargoListForTransfer = {
  boat = {
    { type = 2, num = 1, dbid = config.platform.ZBD05 }, -- ZBD-05
    { type = 2, num = 1, dbid = config.platform.ZTD05 }, -- ZTD-05
  },
  assultLandingGroup = {
    { type = 2, num = 4, dbid = config.platform.PLL05 }, -- PLL-05
    -- Assault Landing Group
  },
  deepAssaultGroup1 = {
    { type = 2, num = 1, dbid = config.platform.PLZ96 }, -- PLZ-96
    { type = 3, num = 1, dbid = config.platform.PGZ09 }, -- PGZ-09
    -- Deep Assault Group
  },
  deepAssaultGroup2 = {
    { type = 2, num = 1, dbid = config.platform.PLZ96 }, -- PLZ-96
    { type = 3, num = 1, dbid = config.platform.PGZ95 }, -- PGZ-95
    -- Deep Assault Group
  },
  deepAssaultGroup3 = {
    { type = 3, num = 1, dbid = config.platform.SA15 }, -- SA-15
    -- Deep Assault Group
  },
  airAssaultGroup1 = {
    { type = 3, num = 2, dbid = config.platform.MC }, -- MC -- 075/071 Z-18
  },
  airAssaultGroup2 = {
    { type = 3, num = 1, dbid = config.platform.HMMWV }, -- HMMWV
  },
  airAssaultGroup3 = {
    { type = 2, num = 3, dbid = config.platform.ZBD03 }, -- II-76 ZBD-03
  },
}
config.c.PHIBOP.missionStartime = {
  transportHelicopter = { 42 * 60, 72 * 60, 92 * 60, 112 * 60 },
  attackHelicopter = { 40 * 60, },
  boat = { 41 * 60, 61 * 60, },
  reconUAV = { 0 }
}
config.c.PHIBOP.shipSettings = {
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
config.c.PHIBOP.initialLocations = {
  {
    name = 'Taoyuan',
    names = {
      'Air Assault Bn',
      'Combined Arms Bn',
      '5th Landing Ship Div'
    },
    from = {
      areas = { {
        startingPoints = { type075 = { side = "China", area = config.c.area.STARTING_POINT_075_TAOYUAN } },
        heading = config.c.PHIBOP.shipSettings.heading.north
      } },
      stagingArea = config.c.area.AREA_OF_OPS_D,
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
            type075 = { side = "China", area = config.c.area.DESTINATION_075_TAOYUAN },
            type071 = { side = "China", area = config.c.area.DESTINATION_071_TAOYUAN },
          },
          heading = config.c.PHIBOP.shipSettings.heading.west,
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
    airLandingZone = config.c.area.AIRLANDING_TAOYUAN,
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
        startingPoints = { type075 = { side = "China", area = config.c.area.STARTING_POINT_075_SISHU } },
        heading = config.c.PHIBOP.shipSettings.heading.sishu
      } },
      stagingArea = config.c.area.AREA_OF_OPS_F,
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
            type075 = { side = "China", area = config.c.area.DESTINATION_075_SISHU },
            type071 = { side = "China", area = config.c.area.DESTINATION_071_SISHU },
          },
          heading = config.c.PHIBOP.shipSettings.heading.sishu,
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
    airLandingZone = config.c.area.AIRLANDING_TAOYUAN,
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
        startingPoints = { type075 = { side = "China", area = config.c.area.STARTING_POINT_075_PENGHU } },
        heading = config.c.PHIBOP.shipSettings.heading.penghu
      } },
      stagingArea = config.c.area.AREA_OF_OPS_E,
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
            type075 = { side = "China", area = config.c.area.DESTINATION_075_PENGHU },
            type071 = { side = "China", area = config.c.area.DESTINATION_071_PENGHU },
          },
          heading = config.c.PHIBOP.shipSettings.heading.penghu,
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
    airLandingZone = config.c.area.AIRLANDING_TAOYUAN,
    numOfContactsInAirLandingZone = 3
  },

}
---@type SBJ__OperationalZone[]
config.c.PHIBOP.operationalZones = {
  {
    name = 'Taoyuan',
    baseGUID = config.base.PINGTAN_PORT,
    anchorageArea = config.c.area.ANCH_AREA_TAOYUAN,
    LSTAnchorageArea = config.c.area.LST_ANCH_AREA_TAOYUAN,
    area = config.c.area.CAS_E,
    offloadArea = config.c.area.OFFLOAD_AREA_TAOYUAN,
    boat = {
      dbid = config.platform.TYPE_726A,
      missions = {
        {
          name = 'LANDING/TAO/1/1',
          loadoutId = 0,
          num = 1,
          startTime = config.c.PHIBOP.missionStartime.boat[1],
        },
        {
          name = 'LANDING/TAO/1/2',
          loadoutId = 0,
          num = 3,
          startTime = config.c.PHIBOP.missionStartime.boat[2],
        },
      },
      zone = config.c.area.LANDING_TAOYUAN,
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
              config.c.PHIBOP.cargoListForTransfer.assultLandingGroup,
              config.c.PHIBOP.cargoListForTransfer.deepAssaultGroup1,
              config.c.PHIBOP.cargoListForTransfer.deepAssaultGroup2,
            }
          },
        },
        type071 = {
          {
            loadoutId = 0,
            cargoItems = {
              config.c.PHIBOP.cargoListForTransfer.assultLandingGroup,
              config.c.PHIBOP.cargoListForTransfer.deepAssaultGroup1,
              config.c.PHIBOP.cargoListForTransfer.deepAssaultGroup2,
              config.c.PHIBOP.cargoListForTransfer.deepAssaultGroup3,
            }
          },
        }
      },
    },
    tansportHelicopter = {
      dbid = config.platform.Z18,
      missions = {
        {
          name = 'AIRLANDING/TAO/1/1',
          loadoutId = config.loadout.Z18_TRANSPORT_1,
          num = 3,
          startTime = config.c.PHIBOP.missionStartime.transportHelicopter[1],
        },
        {
          name = 'AIRLANDING/TAO/1/2',
          loadoutId = config.loadout.Z18_TRANSPORT_1,
          num = 3,
          startTime = config.c.PHIBOP.missionStartime.transportHelicopter[2],
        },
        {
          name = 'AIRLANDING/TAO/2/1',
          loadoutId = config.loadout.Z18_TRANSPORT_2,
          num = 3,
          startTime = config.c.PHIBOP.missionStartime.transportHelicopter[3],
        },
        {
          name = 'AIRLANDING/TAO/2/2',
          loadoutId = config.loadout.Z18_TRANSPORT_2,
          num = 3,
          startTime = config.c.PHIBOP.missionStartime.transportHelicopter[4],
        },
      },
      zone = config.c.area.AIRLANDING_TAOYUAN,
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
            loadoutId = config.loadout.Z18_TRANSPORT_1,
            cargoItems = { config.c.PHIBOP.cargoListForTransfer.airAssaultGroup1 }
          },
          {
            loadoutId = config.loadout.Z18_TRANSPORT_2,
            cargoItems = { config.c.PHIBOP.cargoListForTransfer.airAssaultGroup2 }
          },
        },
        type071 = {
          {
            loadoutId = config.loadout.Z18_TRANSPORT_1,
            cargoItems = { config.c.PHIBOP.cargoListForTransfer.airAssaultGroup1 }
          },
        }
      },
    },
    attackHelicopter = {
      dbid = config.platform.Z10,
      missions = {
        {
          name = 'CAS/E',
          loadoutId = config.loadout.Z10_ATTACK,
          num = 13,
          startTime = config.c.PHIBOP.missionStartime.attackHelicopter[1],
        },
      }
    },
    LSTSettings = {
      speed = config.c.PHIBOP.shipSettings.shipSpeed,
      course = {
        bearing = config.c.PHIBOP.shipSettings.heading.west.vertical,
        distance = config.c.PHIBOP.shipSettings.transitDistance
      }
    },
    ---@type SBJ__ACV
    ACV = {
      bearing = config.c.PHIBOP.shipSettings.heading.west.horizontal,
      distance = config.c.PHIBOP.shipSettings.ACVHorizontalDistance,
      speed = config.c.PHIBOP.shipSettings.ACVSpeed,
      destination = config.c.PHIBOP.shipSettings.heading.west.destination,
      area = config.c.area.AMPH_VEH_STAGING_AREA_TAOYUAN
    },
    reconUAV = {
      dbid = config.platform.GJ11,
      missions = {
        {
          name = 'RECON/3',
          loadoutId = config.loadout.GJ11_RECON,
          num = 8,
          startTime = config.c.PHIBOP.missionStartime.reconUAV[1],
        },
      }
    }
  },
  {
    name = 'Sishu',
    baseGUID = config.base.KWANG_CHOW_WAN_NB,
    anchorageArea = config.c.area.ANCH_AREA_SISHU,
    LSTAnchorageArea = config.c.area.LST_ANCH_AREA_SISHU,
    area = config.c.area.CAS_S,
    offloadArea = config.c.area.OFFLOAD_AREA_SISHU,
    boat = {
      dbid = config.platform.TYPE_726A,
      ---@type SBJ__LandingMission[]
      missions = {
        {
          name = 'LANDING/SISHU/1/1',
          loadoutId = 0,
          num = 1,
          startTime = config.c.PHIBOP.missionStartime.boat[1],
        },
        {
          name = 'LANDING/SISHU/1/2',
          loadoutId = 0,
          num = 3,
          startTime = config.c.PHIBOP.missionStartime.boat[2],
        },
      },
      zone = config.c.area.LANDING_SISHU,
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
              config.c.PHIBOP.cargoListForTransfer.assultLandingGroup,
              config.c.PHIBOP.cargoListForTransfer.deepAssaultGroup1,
              config.c.PHIBOP.cargoListForTransfer.deepAssaultGroup2,
            }
          },
        },
        type071 = {
          {
            loadoutId = 0,
            cargoItems = {
              config.c.PHIBOP.cargoListForTransfer.assultLandingGroup,
              config.c.PHIBOP.cargoListForTransfer.deepAssaultGroup1,
              config.c.PHIBOP.cargoListForTransfer.deepAssaultGroup2,
              config.c.PHIBOP.cargoListForTransfer.deepAssaultGroup3
            }
          },
        }
      },
    },
    tansportHelicopter = {
      dbid = config.platform.Z18,
      missions = {
        {
          name = 'AIRLANDING/CHANGLONG/1/1',
          loadoutId = config.loadout.Z18_TRANSPORT_1,
          num = 3,
          startTime = config.c.PHIBOP.missionStartime.transportHelicopter[1],
        },
        {
          name = 'AIRLANDING/CHANGLONG/1/2',
          loadoutId = config.loadout.Z18_TRANSPORT_1,
          num = 3,
          startTime = config.c.PHIBOP.missionStartime.transportHelicopter[2],
        },
        {
          name = 'AIRLANDING/CHANGLONG/2/1',
          loadoutId = config.loadout.Z18_TRANSPORT_2,
          num = 3,
          startTime = config.c.PHIBOP.missionStartime.transportHelicopter[3],
        },
        {
          name = 'AIRLANDING/CHANGLONG/2/2',
          loadoutId = config.loadout.Z18_TRANSPORT_2,
          num = 3,
          startTime = config.c.PHIBOP.missionStartime.transportHelicopter[4],
        },
      },
      zone = config.c.area.AIRLANDING_CHANGLONG,
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
            loadoutId = config.loadout.Z18_TRANSPORT_1,
            cargoItems = { config.c.PHIBOP.cargoListForTransfer.airAssaultGroup1 }
          },
          {
            loadoutId = config.loadout.Z18_TRANSPORT_2,
            cargoItems = { config.c.PHIBOP.cargoListForTransfer.airAssaultGroup2 }
          },
        },
        type071 = {
          {
            loadoutId = config.loadout.Z18_TRANSPORT_1,
            cargoItems = { config.c.PHIBOP.cargoListForTransfer.airAssaultGroup1 }
          },
        }
      },
    },
    attackHelicopter = {
      dbid = config.platform.Z10,
      missions = {
        {
          name = 'CAS/S',
          loadoutId = config.loadout.Z10_ATTACK,
          num = 13,
          startTime = config.c.PHIBOP.missionStartime.attackHelicopter[1],
        },
      }
    },
    LSTSettings = {
      speed = config.c.PHIBOP.shipSettings.shipSpeed,
      course = {
        bearing = config.c.PHIBOP.shipSettings.heading.sishu.vertical,
        distance = config.c.PHIBOP.shipSettings.transitDistance
      }
    },
    ACV = {
      bearing = config.c.PHIBOP.shipSettings.heading.sishu.horizontal,
      distance = config.c.PHIBOP.shipSettings.ACVHorizontalDistance,
      speed = config.c.PHIBOP.shipSettings.ACVSpeed,
      destination = config.c.PHIBOP.shipSettings.heading.sishu.destination,
      area = config.c.area.AMPH_VEH_STAGING_AREA_SHISHU
    }
  },
  {
    name = 'Penghu',
    baseGUID = config.base.KWANG_CHOW_WAN_NB,
    anchorageArea = config.c.area.ANCH_AREA_PENGHU,
    LSTAnchorageArea = config.c.area.LST_ANCH_AREA_PENGHU,
    area = config.c.area.CAS_PENGHU,
    offloadArea = config.c.area.OFFLOAD_AREA_PENGHU,
    boat = {
      dbid = config.platform.TYPE_726A,
      missions = {
        {
          name = 'LANDING/PENGHU/1/1',
          loadoutId = 0,
          num = 1,
          startTime = config.c.PHIBOP.missionStartime.boat[1],
        },
        {
          name = 'LANDING/PENGHU/1/2',
          loadoutId = 0,
          num = 3,
          startTime = config.c.PHIBOP.missionStartime.boat[2],
        },
      },
      zone = config.c.area.LANDING_PENGHU,
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
              config.c.PHIBOP.cargoListForTransfer.assultLandingGroup,
              config.c.PHIBOP.cargoListForTransfer.deepAssaultGroup1,
              config.c.PHIBOP.cargoListForTransfer.deepAssaultGroup2,
            }
          },
        },
        type071 = {
          {
            loadoutId = 0,
            cargoItems = {
              config.c.PHIBOP.cargoListForTransfer.assultLandingGroup,
              config.c.PHIBOP.cargoListForTransfer.deepAssaultGroup1,
              config.c.PHIBOP.cargoListForTransfer.deepAssaultGroup2,
              config.c.PHIBOP.cargoListForTransfer.deepAssaultGroup3
            }
          },
        }
      },
    },
    tansportHelicopter = {
      dbid = config.platform.Z18,
      missions = {
        {
          name = 'AIRLANDING/PENGHU/1/1',
          loadoutId = config.loadout.Z18_TRANSPORT_1,
          num = 3,
          startTime = config.c.PHIBOP.missionStartime.transportHelicopter[1],
        },
        {
          name = 'AIRLANDING/PENGHU/1/2',
          loadoutId = config.loadout.Z18_TRANSPORT_1,
          num = 3,
          startTime = config.c.PHIBOP.missionStartime.transportHelicopter[2],
        },
        {
          name = 'AIRLANDING/PENGHU/2/1',
          loadoutId = config.loadout.Z18_TRANSPORT_2,
          num = 3,
          startTime = config.c.PHIBOP.missionStartime.transportHelicopter[3],
        },
        {
          name = 'AIRLANDING/PENGHU/2/2',
          loadoutId = config.loadout.Z18_TRANSPORT_2,
          num = 3,
          startTime = config.c.PHIBOP.missionStartime.transportHelicopter[4],
        },
      },
      zone = config.c.area.AIRLANDING_PENGHU,
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
            loadoutId = config.loadout.Z18_TRANSPORT_1,
            cargoItems = { config.c.PHIBOP.cargoListForTransfer.airAssaultGroup1 }
          },
          {
            loadoutId = config.loadout.Z18_TRANSPORT_2,
            cargoItems = { config.c.PHIBOP.cargoListForTransfer.airAssaultGroup2 }
          },
        },
        type071 = {
          {
            loadoutId = config.loadout.Z18_TRANSPORT_1,
            cargoItems = { config.c.PHIBOP.cargoListForTransfer.airAssaultGroup1 }
          },
        }
      },
    },
    attackHelicopter = {
      dbid = config.platform.Z10,
      missions = {
        {
          name = 'CAS/PENGHU',
          loadoutId = config.loadout.Z10_ATTACK,
          num = 13,
          startTime = config.c.PHIBOP.missionStartime.attackHelicopter[1],
        },
      }
    },
    LSTSettings = {
      speed = config.c.PHIBOP.shipSettings.shipSpeed,
      course = {
        bearing = config.c.PHIBOP.shipSettings.heading.penghu.vertical,
        distance = config.c.PHIBOP.shipSettings.transitDistance
      }
    },
    ACV = {
      bearing = config.c.PHIBOP.shipSettings.heading.penghu.horizontal,
      distance = config.c.PHIBOP.shipSettings.ACVHorizontalDistance,
      speed = config.c.PHIBOP.shipSettings.ACVSpeed,
      destination = config.c.PHIBOP.shipSettings.heading.penghu.destination,
      area = config.c.area.AMPH_VEH_STAGING_AREA_PENGHU
    }
  },
}
config.c.PHIBOP.transportAircraft = {
  {
    name = 'Zhangpu AAB',
    guid = config.base.ZHANGPU_AAB,
    dbid = config.platform.IL76,
    missions = {
      {
        name = 'AIRLANDING/PENGHU/2/2',
        loadoutId = config.loadout.IL76_TRANSPORT,
        num = 3,
        startTime = 0
      },
    },
    cargoItemsForTransfer = {
      {
        loadoutId = config.loadout.IL76_TRANSPORT,
        cargoItems = { config.c.PHIBOP.cargoListForTransfer.airAssaultGroup3 }
      },
    }
  },
}
config.c.PHIBOP.sag = {
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
      heading = config.c.PHIBOP.shipSettings.heading.west.vertical,
    },
    area = config.c.area.AIRLANDING_TAOYUAN
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
      heading = config.c.PHIBOP.shipSettings.heading.west.vertical,
    },
    area = config.c.area.AIRLANDING_TAOYUAN
  },
  ['SAG 167'] = {
    groupName = 'SAG 167',
    from = {
      startingPoint = { lat = 'N 23.29.19', lon = 'E 118.04.37', },
      heading = config.c.PHIBOP.shipSettings.heading.penghu.vertical,
    },
    to = {
      archorageArea = {
        { lat = 'N 23.32.46', lon = 'E 119.16.11', desiredSpeed = 14, },
      },
      amphibiousVehicleStagingArea = {
        { lat = 'N 23.32.34', lon = 'E 119.29.14', desiredSpeed = 14, },
      },
      heading = config.c.PHIBOP.shipSettings.heading.penghu.vertical,
    },
    area = config.c.area.AIRLANDING_PENGHU,
  },
  ['SAG 154'] = {
    groupName = 'SAG 154',
    from = {
      startingPoint = { lat = 'N 22.32.59', lon = 'E 118.04.52', },
      heading = config.c.PHIBOP.shipSettings.heading.sishu.vertical,
    },
    to = {
      archorageArea = {
        { lat = 'N 22.49.20', lon = 'E 119.55.57', desiredSpeed = 14, },
      },
      amphibiousVehicleStagingArea = {
        { lat = 'N 22.53.16', lon = 'E 120.07.39', desiredSpeed = 14, },
      },
      heading = config.c.PHIBOP.shipSettings.heading.sishu.vertical,
    },
    area = config.c.area.AIRLANDING_CHANGLONG,
  },
  ['SAG 175'] = {
    groupName = 'SAG 175',
    from = {
      startingPoint = { lat = 'N 22.44.28', lon = 'E 118.01.16', },
      heading = config.c.PHIBOP.shipSettings.heading.sishu.vertical,
    },
    to = {
      archorageArea = {
        { lat = 'N 22.55.20', lon = 'E 119.52.25', desiredSpeed = 14, },
      },
      amphibiousVehicleStagingArea = {
        { lat = 'N 22.58.52', lon = 'E 120.05.48', desiredSpeed = 14, },
      },
      heading = config.c.PHIBOP.shipSettings.heading.sishu.vertical,
    },
    area = config.c.area.AIRLANDING_CHANGLONG,
  },
}

-- Land strike from
config.c.surface.lacm.weaponDBID = config.weapon.YJ21
config.c.surface.lacm.csg = {
  groupName = 'CSG',
  unitList = {
    type002 = {
      dbid = config.platform.TYPE_002,
      embarkedUnits = {
        {
          side = 'China',
          type = 'Air',
          dbid = config.platform.J15,
          name = '2nd Carrier Air Wing',
          loadouts = {
            { loadoutId = config.loadout.J15_YJ91,    num = 16 },
            { loadoutId = config.loadout.J15_LS6_500, num = 24 },
          }
        },
        {
          side = 'China',
          type = 'Air',
          dbid = config.platform.Z18F_SEA_EAGLE,
          name = '10th Naval Air Bde',
          loadouts = {
            { loadoutId = config.loadout.Z18F_CARRIER_ASW, num = 6, missionName = 'ASW/CSG' },
          }
        },
        {
          side = 'China',
          type = 'Air',
          dbid = config.platform.Z18J,
          name = '10th Naval Air Bde',
          loadouts = {
            { loadoutId = config.loadout.Z18J_AEW, num = 3, missionName = 'AEW/CSG' },
          }
        },
        {
          side = 'China',
          type = 'Air',
          dbid = config.platform.J15D,
          name = '2nd Carrier Air Wing',
          loadouts = {
            { loadoutId = config.loadout.J15D_EW, num = 3, },
          }
        },
      },
      loadouts = {
        { loadoutId = config.loadout.J15_LS6_500, num = 24, }, -- LS-6-500 X 4
        { loadoutId = config.loadout.J15_YJ91,    num = 16, }, -- YJ-91 X 4
      }
    },
    type055 = {
      dbid = config.platform.TYPE_055,
      embarkedUnits = {
        {
          side = 'China',
          type = 'Air',
          dbid = config.platform.KA28,
          name = '10th Naval Air Bde',
          loadouts = {
            { loadoutId = config.loadout.KA28_ASW, num = 1, missionName = 'ASW/CSG' },
          }
        },
      }
    },
    type054a = {
      dbid = config.platform.TYPE_054A,
      embarkedUnits = {
        {
          side = 'China',
          type = 'Air',
          dbid = config.platform.KA28,
          name = '10th Naval Air Bde',
          loadouts = {
            { loadoutId = config.loadout.KA28_ASW, num = 1, missionName = 'ASW/CSG' },
          }
        },
      }
    },
    type901 = {
      dbid = config.platform.TYPE_901,
      embarkedUnits = {
        {
          side = 'China',
          type = 'Air',
          dbid = config.platform.Z18F_SEA_EAGLE,
          name = '10th Naval Air Bde',
          loadouts = {
            { loadoutId = config.loadout.Z18F_CARRIER_ASW, num = 1, missionName = 'ASW/CSG' },
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
config.c.surface.lacm.targetlist = {
  '6Z8LM5-0HMIJ7B89BC71',
  '6Z8LM5-0HMIJ7B89BC73',
  '6Z8LM5-0HMIJ7B89BC6V',
}


-- SLCM
config.c.subSurface.slcm.weaponDBID = config.weapon.CJ10_SLCM
config.c.subSurface.slcm.submarines = {
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
    weaponDBID = config.c.subSurface.slcm.weaponDBID
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
    weaponDBID = config.c.subSurface.slcm.weaponDBID
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
    weaponDBID = config.c.subSurface.slcm.weaponDBID
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
    weaponDBID = config.c.subSurface.slcm.weaponDBID
  },
}

config.c.subSurface.slcm.targetlist = {
  '6Z8LM5-0HMIJ7B89BCF3',
  '6Z8LM5-0HMIJ7B89BCF4',
  '6Z8LM5-0HMIJ7B89BCF5',
}
config.c.subSurface.slcm.randomRadius = 20


-- Runway repairment
config.c.repairRunway.percentagePerHour = 3


config.c.FSEMTemplate = {
  STRIKE_INFRASTRUCTURE_1 = {
    {
      name = 'RADAR',
      wpnSystem = 'SRBM',
      batteries = {
        { name = '614th Bde', guid = 'X58F5H-0HN1LQGRV8HNQ', weaponDBID = config.weapon.DF11A },
        { name = '613rd Bde', guid = 'X58F5H-0HN1G2DEBC7O8', weaponDBID = config.weapon.DF15B }
      },
      target = {
        list = {},
        objs = {
          { baseName = nil, subTypes = { 'Radar', 'Hengshan ROC command', 'Sky Bow' } },
        },
        areas = {},
        filterNames = nil,
        contactAge = config.c.ground.srbm.contactAge,
        minTargetCount = 4,
        ammoPerTarget = 3
      },
    },
    {
      name = 'RUNWAY',
      wpnSystem = 'SRBM',
      batteries = {
        { name = '636th Bde', guid = 'IC8B0X-0HN822OHANPB3', weaponDBID = config.weapon.DF16A },
        { name = '617th Bde', guid = 'IC8B0X-0HN822OHANRHI', weaponDBID = config.weapon.DF16A }
      },
      target = {
        list = {},
        objs = {
          { baseName = 'Hualien AB',           subTypes = { 'Runway %(%d+m%)', 'Taxiway' } },
          { baseName = 'Taitung/Jhihhang AB',  subTypes = { 'Runway %(%d+m%)', 'Taxiway' } },
          { baseName = 'Ching Chuang Kang AB', subTypes = { 'Runway %(%d+m%)', 'Taxiway' } },
          { baseName = 'Chiayi AB',            subTypes = { 'Runway %(%d+m%)', 'Taxiway' } },
          { baseName = 'Tainan AB',            subTypes = { 'Runway %(%d+m%)', 'Taxiway' } },
          { baseName = 'Pingtung South AB',    subTypes = { 'Runway %(%d+m%)', 'Taxiway' } },
          { baseName = 'Pingtung North AB',    subTypes = { 'Runway %(%d+m%)', 'Taxiway' } },
          { baseName = 'Magong AB',            subTypes = { 'Runway %(%d+m%)', 'Taxiway' } },
          { baseName = 'Hsinchu AB',           subTypes = { 'Runway %(%d+m%)', 'Taxiway' } },
        },
        areas = {},
        filterNames = nil,
        contactAge = config.c.ground.srbm.contactAge,
        minTargetCount = 4,
        ammoPerTarget = 4
      },
    },
    {
      name = 'PORT',
      wpnSystem = 'SRBM',
      batteries = {
        { name = '615th Bde', guid = 'X58F5H-0HN1G2IFLNKG9', weaponDBID = config.weapon.DF11A }
      },
      target = {
        list = {},
        objs = {
          { baseName = 'Port of Keelung', subTypes = { 'Pier' } },
          { baseName = 'Suao Port',       subTypes = { 'Pier' } },
          { baseName = 'Kaohsiung Port',  subTypes = { 'Pier' } },
          { baseName = 'Magong Port',     subTypes = { 'Pier' } },
          { baseName = nil,               subTypes = { 'ASM' } },
        },
        areas = {},
        filterNames = nil,
        contactAge = config.c.ground.srbm.contactAge,
        minTargetCount = 4,
        ammoPerTarget = 2
      },
    },
    {
      name = 'SHELTER',
      wpnSystem = 'SRBM',
      batteries = {
        { name = '616th Bde', guid = 'X58F5H-0HN1G2IFLF6QE', weaponDBID = config.weapon.DF15C }
      },
      target = {
        list = {},
        objs = {
          { baseName = 'Chiayi AB',            subTypes = { 'Shelter', 'Tarmac', 'Hangar' } },
          { baseName = 'Pingtung South AB',    subTypes = { 'Shelter', 'Tarmac', 'Hangar' } },
          { baseName = 'Ching Chuang Kang AB', subTypes = { 'Shelter', 'Tarmac', 'Hangar' } },
          { baseName = 'Magong AB',            subTypes = { 'Shelter', 'Tarmac', 'Hangar' } },
        },
        areas = {},
        filterNames = nil,
        contactAge = config.c.ground.srbm.contactAge,
        minTargetCount = 4,
        ammoPerTarget = 2
      },
    },
  },
  STRIKE_INFRASTRUCTURE_2 = {
    {
      name = 'RADAR',
      wpnSystem = 'SRBM',
      batteries = {
        { name = '614th Bde', guid = 'X58F5H-0HN1LQGRV8HNQ', weaponDBID = config.weapon.DF11A },
        { name = '613rd Bde', guid = 'X58F5H-0HN1G2DEBC7O8', weaponDBID = config.weapon.DF15B }
      },
      target = {
        list = {},
        objs = {
          { baseName = nil, subTypes = { 'Radar', 'Hengshan ROC command', 'Sky Bow' } },
        },
        areas = {},
        filterNames = nil,
        contactAge = config.c.ground.srbm.contactAge,
        minTargetCount = 1,
        ammoPerTarget = 3
      },
    },
    {
      name = 'RUNWAY',
      wpnSystem = 'SRBM',
      batteries = {
        { name = '636th Bde', guid = 'IC8B0X-0HN822OHANPB3', weaponDBID = config.weapon.DF16A },
        { name = '617th Bde', guid = 'IC8B0X-0HN822OHANRHI', weaponDBID = config.weapon.DF16A }
      },
      target = {
        list = {},
        objs = {
          { baseName = 'Hualien AB',              subTypes = { 'Runway %(%d+m%)', 'Taxiway' } },
          { baseName = 'Taitung/Jhihhang AB',     subTypes = { 'Runway %(%d+m%)', 'Taxiway' } },
          { baseName = 'Ching Chuang Kang AB',    subTypes = { 'Runway %(%d+m%)', 'Taxiway' } },
          { baseName = 'Chiayi AB',               subTypes = { 'Runway %(%d+m%)', 'Taxiway' } },
          { baseName = 'Tainan AB',               subTypes = { 'Runway %(%d+m%)', 'Taxiway' } },
          { baseName = 'Pingtung South AB',       subTypes = { 'Runway %(%d+m%)', 'Taxiway' } },
          { baseName = 'Pingtung North AB',       subTypes = { 'Runway %(%d+m%)', 'Taxiway' } },
          { baseName = 'Magong AB',               subTypes = { 'Runway %(%d+m%)', 'Taxiway' } },
          { baseName = 'Hsinchu AB',              subTypes = { 'Runway %(%d+m%)', 'Taxiway' } },
          { baseName = 'Taitung/Jhihhang AB',     subTypes = { 'Runway %(%d+m%)', 'Taxiway' } },
          { baseName = 'Guiren AAB',              subTypes = { 'Runway %(%d+m%)', 'Taxiway' } },
          { baseName = 'Longtan AAB',             subTypes = { 'Runway %(%d+m%)', 'Taxiway' } },
          { baseName = 'Gangshan AB',             subTypes = { 'Runway %(%d+m%)', 'Taxiway' } },
          { baseName = 'Taipei Songshan Airport', subTypes = { 'Runway %(%d+m%)', 'Taxiway' } },
        },
        areas = {},
        filterNames = nil,
        contactAge = config.c.ground.srbm.contactAge,
        minTargetCount = 1,
        ammoPerTarget = 4
      },
    },
    {
      name = 'PORT',
      wpnSystem = 'SRBM',
      batteries = {
        { name = '615th Bde', guid = 'X58F5H-0HN1G2IFLNKG9', weaponDBID = config.weapon.DF11A }
      },
      target = {
        list = {},
        objs = {
          { baseName = 'Port of Keelung',          subTypes = { 'Pier' } },
          { baseName = 'Suao Port',                subTypes = { 'Pier' } },
          { baseName = 'Kaohsiung Port',           subTypes = { 'Pier' } },
          { baseName = 'Magong Port',              subTypes = { 'Pier' } },
          { baseName = 'HuangGang Fishing Harbor', subTypes = { 'Terminal' } },
          { baseName = 'Donggang Wharf',           subTypes = { 'Terminal' } },
          { baseName = nil,                        subTypes = { 'ASM' } },
        },
        areas = {},
        filterNames = nil,
        contactAge = config.c.ground.srbm.contactAge,
        minTargetCount = 1,
        ammoPerTarget = 2
      },
    },
    {
      name = 'SHELTER',
      wpnSystem = 'SRBM',
      batteries = {
        { name = '616th Bde', guid = 'X58F5H-0HN1G2IFLF6QE', weaponDBID = config.weapon.DF15C }
      },
      target = {
        list = {},
        objs = {
          { baseName = 'Chiayi AB',            subTypes = { 'Shelter', 'Tarmac', 'Hangar' } },
          { baseName = 'Pingtung South AB',    subTypes = { 'Shelter', 'Tarmac', 'Hangar' } },
          { baseName = 'Ching Chuang Kang AB', subTypes = { 'Shelter', 'Tarmac', 'Hangar' } },
          { baseName = 'Magong AB',            subTypes = { 'Shelter', 'Tarmac', 'Hangar' } },
          { baseName = 'Pingtung North AB',    subTypes = { 'Shelter', 'Tarmac', 'Hangar' } },
          { baseName = 'Hsinchu AB',           subTypes = { 'Shelter', 'Tarmac', 'Hangar' } },
          { baseName = 'Gangshan AB',          subTypes = { 'Shelter', 'Tarmac', 'Hangar' } },
          { baseName = 'Tainan AB',            subTypes = { 'Shelter', 'Tarmac', 'Hangar' } },
        },
        areas = {},
        filterNames = nil,
        contactAge = config.c.ground.srbm.contactAge,
        minTargetCount = 1,
        ammoPerTarget = 2
      },
    },
  },
  ANTISHIP = {
    {
      name = "ANTISHIP",
      wpnSystem = "MRBM",
      batteries = {
        { name = '624th Bde', guid = 'IC8B0X-0HNCOR6HG2JE1', weaponDBID = config.weapon.DF21D }
      },
      target = {
        list = {},
        objs = {},
        areas = { config.c.area.AREA_OF_OPS_PACIFIC },
        filterNames = { "findNavalTargets" },
        contactAge = config.c.ground.mrbm.contactAge,
        minTargetCount = 1,
        ammoPerTarget = 6
      },
    }
  },
  STRIKE_C2 = {
    {
      name = 'PINGTAN',
      wpnSystem = 'MLRS',
      batteries = {
        { name = '1st Bn, 1st Rockets Arty Bde', guid = 'IC8B0X-0HND05GGU36EN', weaponDBID = config.weapon.FD280 }
      },
      target = {
        list = {},
        objs = {},
        areas = { config.c.area.AREA_OF_OPS_NORTH },
        filterNames = { 'analyzeEmissions', 'findRadioDirection' },
        contactAge = config.c.ground.mlrs.contactAge,
        minTargetCount = 1,
        ammoPerTarget = 8
      },
    },
    {
      name = 'CHINCHEW',
      wpnSystem = 'MLRS',
      batteries = {
        { name = '6th Bn, 73rd Arty Bde', guid = 'IC8B0X-0HNBRRE2PRQAL', weaponDBID = config.weapon.FD280 }
      },
      target = {
        list = {},
        objs = {},
        areas = { config.c.area.AREA_OF_OPS_CENTER },
        filterNames = { 'analyzeEmissions', 'findRadioDirection' },
        contactAge = config.c.ground.mlrs.contactAge,
        minTargetCount = 1,
        ammoPerTarget = 8
      },
    },
  },
  STRIKE_HELIPAD = {
    {
      name = 'HELIPAD',
      wpnSystem = 'GLCM',
      batteries = {
        { name = '635th Bde', guid = '6Z8LM5-0HMN97ERAUODK', weaponDBID = config.weapon.CJ10 }
      },
      target = {
        list = {},
        objs = {
          { baseName = 'Guiren AAB',                       subTypes = { 'Helipad' } },
          { baseName = 'Longtan AAB',                      subTypes = { 'Helipad' } },
          { baseName = 'Minxiong Emergency Highway Strip', subTypes = { 'Runway %(%d+m%)', 'Taxiway' } },
          { baseName = 'Madou Emergency Highway Strip',    subTypes = { 'Runway %(%d+m%)', 'Taxiway' } },
          { baseName = 'Rende Emergency Highway Strip',    subTypes = { 'Runway %(%d+m%)', 'Taxiway' } },
        },
        areas = {},
        filterNames = nil,
        contactAge = config.c.ground.glcm.contactAge,
        minTargetCount = 1,
        ammoPerTarget = 4
      },
    },
  },
}

config.c.packageTemplate = {
  STRIKE_AB_W_1 = {
    {
      timeToReady = config.readytime,
      striker = {
        baseGUID = config.base.SHANTOU_WAISHA_AB,
        weaponDBID = config.weapon.AKD88,
        unitDBID = config.platform.J16,
        unitCount = 12,
        loadoutID = config.loadout.J16_AKD88,
        -- startTime = '2027-06-09 01:25:00',
        missionParams = { name = 'STRIKE/AB/W/1', type = 'strike', opts = { type = 'land' } },
        emcon = 'Radar=Passive;OECM=Active'
      },
      escort = {
        baseGUID = config.base.HUIAN_AAB,
        weaponDBID = config.weapon.PL15,
        unitDBID = config.platform.J20,
        unitCount = 8,
        loadoutID = config.loadout.J20_PL15,
        -- startTime = '2027-06-09 01:05:00',
        missionParams = {
          name = 'SWEEP/AB/W/1',
          type = 'patrol',
          opts = {
            type = 'aaw',
            OneThirdRule = false,
            FlightSize = 4,
            CheckOPAREA = false,
            CheckWWR = false,
            prosecutionZone = config.c.area.TARGET_AREA_SOUTH_PROSECUTION,
            patrolZone = config.c.area.TARGET_AREA_SOUTH_PATROL
          }
        },
        emcon = 'Radar=Passive;OECM=Active'
      },
      wildWeasel = {
        baseGUID = config.base.ZHANGZHOU_LONGXI_AB,
        weaponDBID = config.weapon.YJ91_ARM,
        unitDBID = config.platform.SU30,
        unitCount = 8,
        loadoutID = config.loadout.SU30_YJ91,
        -- startTime = '2027-06-09 01:05:00',
        missionParams = {
          name = 'SEAD/AB/W/1',
          type = 'patrol',
          opts = {
            type = 'sead',
            OneThirdRule = false,
            FlightSize = 4,
            CheckOPAREA = false,
            CheckWWR = false,
            prosecutionZone = config.c.area.TARGET_AREA_SOUTH_PROSECUTION,
            patrolZone = config.c.area.TARGET_AREA_SOUTH_PATROL
          }
        },
        emcon = 'Radar=Passive;OECM=Active'
      },
      jammer = {
        baseGUID = config.base.ZHANGPU_AAB,
        unitDBID = config.platform.Y9,
        weaponDBID = 0,
        unitCount = 1,
        loadoutID = nil, -- Electronic warfare aircraft
        -- startTime = '2027-06-09 01:05:00', -- Escort launch time
        missionParams = {
          name = 'JAMMING/AB/W/1',
          type = 'support',
          opts = { zone = config.c.area.TARGET_AREA_SOUTH_PATROL }
        },
        emcon = 'Radar=Passive;OECM=Active'
      },
      tanker = nil,
      reconUAV = config.c.recon.template.BZK005_RECON_1,
      target = {
        list = {},
        objs = {
          { baseName = 'Pingtung South AB', subTypes = { 'Shelter', 'Tarmac', 'Hangar' } },
          { baseName = 'Pingtung North AB', subTypes = { 'Shelter', 'Tarmac', 'Hangar' } }
        },
        areas = { config.c.area.AREA_OF_OPS_SOUTH },
        filterNames = {},
        contactAge = 60 * 60,
        minTargetCount = 1
      },
    },
    {
      timeToReady = config.readytime,
      striker = {
        baseGUID = config.base.SHANTOU_WAISHA_AB,
        weaponDBID = config.weapon.AKD88,
        unitDBID = config.platform.J16,
        unitCount = 12,
        loadoutID = config.loadout.J16_AKD88,
        startTime = nil,
        missionParams = { name = 'STRIKE/AB/C', type = 'strike', opts = { type = 'land' } },
        emcon = 'Radar=Passive;OECM=Active'
      },
      escort = {
        baseGUID = config.base.HUIAN_AAB,
        weaponDBID = config.weapon.PL15,
        unitDBID = config.platform.J20,
        unitCount = 8,
        loadoutID = config.loadout.J20_PL15,
        missionParams = {
          name = 'SWEEP/AB/C',
          type = 'patrol',
          opts = {
            type = 'aaw',
            OneThirdRule = false,
            FlightSize = 4,
            CheckOPAREA = false,
            CheckWWR = false,
            prosecutionZone = config.c.area.TARGET_AREA_CENTER_PROSECUTION,
            patrolZone = config.c.area.TARGET_AREA_CENTER_PATROL
          }
        },
        emcon = 'Radar=Passive;OECM=Active'
      },
      wildWeasel = {
        baseGUID = config.base.ZHANGZHOU_LONGXI_AB,
        weaponDBID = config.weapon.YJ91_ARM,
        unitDBID = config.platform.SU30,
        unitCount = 8,
        loadoutID = config.loadout.SU30_YJ91,
        missionParams = {
          name = 'SEAD/AB/C',
          type = 'patrol',
          opts = {
            type = 'sead',
            OneThirdRule = false,
            FlightSize = 4,
            CheckOPAREA = false,
            CheckWWR = false,
            prosecutionZone = config.c.area.TARGET_AREA_CENTER_PROSECUTION,
            patrolZone = config.c.area.TARGET_AREA_CENTER_PATROL
          }
        },
        emcon = 'Radar=Passive;OECM=Active'
      },
      jammer = {
        baseGUID = config.base.ZHANGPU_AAB,
        unitDBID = config.platform.Y9,
        weaponDBID = 0,
        unitCount = 1,
        loadoutID = nil,
        missionParams = {
          name = 'JAMMING/AB/C',
          type = 'support',
          opts = { zone = config.c.area.TARGET_AREA_CENTER_PATROL }
        },
        emcon = 'Radar=Passive;OECM=Active'
      },
      tanker = nil,
      reconUAV = nil,
      target = {
        list = {},
        objs = {
          { baseName = 'Ching Chuang Kang AB', subTypes = { 'Shelter', 'Ammo Bunker' } },
          { baseName = 'Chiayi AB',            subTypes = { 'Shelter', 'Ammo Bunker' } }
        },
        areas = { config.c.area.AREA_OF_OPS_CENTER },
        filterNames = {},
        contactAge = 60 * 60,
        minTargetCount = 1
      },
    },
    {
      timeToReady = config.readytime,
      striker = {
        baseGUID = config.base.HUIAN_AAB,
        weaponDBID = config.weapon.AKD88,
        unitDBID = config.platform.J16,
        unitCount = 12,
        loadoutID = config.loadout.J16_AKD88,
        startTime = nil,
        missionParams = { name = 'STRIKE/AB/N/1', type = 'strike', opts = { type = 'land' } },
        emcon = 'Radar=Passive;OECM=Active'
      },
      escort = {
        baseGUID = config.base.HUIAN_AAB,
        weaponDBID = config.weapon.PL15,
        unitDBID = config.platform.J20,
        unitCount = 8,
        loadoutID = config.loadout.J20_PL15,
        missionParams = {
          name = 'SWEEP/AB/N/1',
          type = 'patrol',
          opts = {
            type = 'aaw',
            OneThirdRule = false,
            FlightSize = 4,
            CheckOPAREA = false,
            CheckWWR = false,
            prosecutionZone = config.c.area.TARGET_AREA_NORTH_PROSECUTION,
            patrolZone = config.c.area.TARGET_AREA_NORTH_PATROL
          }
        },
        emcon = 'Radar=Passive;OECM=Active'
      },
      wildWeasel = {
        baseGUID = config.base.LONGTIAN_AAB,
        weaponDBID = config.weapon.YJ91_ARM,
        unitDBID = config.platform.SU30,
        unitCount = 8,
        loadoutID = config.loadout.SU30_YJ91,
        missionParams = {
          name = 'SEAD/AB/N/1',
          type = 'patrol',
          opts = {
            type = 'sead',
            OneThirdRule = false,
            FlightSize = 4,
            CheckOPAREA = false,
            CheckWWR = false,
            prosecutionZone = config.c.area.TARGET_AREA_NORTH_PROSECUTION,
            patrolZone = config.c.area.TARGET_AREA_NORTH_PATROL
          }
        },
        emcon = 'Radar=Passive;OECM=Active'
      },
      jammer = {
        baseGUID = config.base.ZHANGPU_AAB,
        unitDBID = config.platform.Y9,
        weaponDBID = 0,
        unitCount = 1,
        loadoutID = nil,
        missionParams = {
          name = 'JAMMING/AB/N/1',
          type = 'support',
          opts = { zone = config.c.area.TARGET_AREA_NORTH_PATROL }
        },
        emcon = 'Radar=Passive;OECM=Active'
      },
      tanker = nil,
      reconUAV = nil,
      target = {
        list = {},
        objs = {
          { baseName = 'Hsinchu AB', subTypes = { 'Shelter', 'Helipad', 'Ammo Bunker' } }
        },
        areas = { config.c.area.AREA_OF_OPS_NORTH },
        filterNames = {},
        contactAge = 60 * 60,
        minTargetCount = 1
      },
    }
  },
  STRIKE_AB_W_2 = {
    {
      timeToReady = config.readytime,
      striker = {
        baseGUID = config.base.XINGNING_AB,
        weaponDBID = config.weapon.YJ63,
        unitDBID = config.platform.H6K,
        unitCount = 12,
        loadoutID = config.loadout.H6K_YJ63,
        -- startTime = '2027-06-09 04:40:00',
        startTime = nil,
        missionParams = { name = 'STRIKE/AB/S/1', type = 'strike', opts = { type = 'land' } },
        emcon = 'Radar=Passive;OECM=Active'
      },
      escort = nil,
      wildWeasel = nil,
      jammer = nil,
      tanker = nil,
      reconUAV = nil,
      target = {
        list = {},
        objs = {
          { baseName = 'Pingtung South AB', subTypes = { 'Shelter', 'Tarmac', 'Hangar' } },
          { baseName = 'Pingtung North AB', subTypes = { 'Shelter', 'Tarmac', 'Hangar' } }
        },
        areas = { config.c.area.AREA_OF_OPS_SOUTH },
        filterNames = { 'findC2' },
        contactAge = 60 * 60,
        minTargetCount = 1
      },
    },
    {
      timeToReady = config.readytime,
      striker = {
        baseGUID = config.base.ANQING_AB,
        weaponDBID = config.weapon.YJ63,
        unitDBID = config.platform.H6K,
        unitCount = 12,
        loadoutID = config.loadout.H6K_YJ63,
        startTime = nil,
        missionParams = { name = 'STRIKE/AB/N/1', type = 'strike', opts = { type = 'land' } },
        emcon = 'Radar=Passive;OECM=Active'
      },
      escort = nil,
      wildWeasel = nil,
      jammer = nil,
      tanker = nil,
      reconUAV = nil,
      target = {
        list = {},
        objs = {
          { baseName = 'Hsinchu AB', subTypes = { 'Shelter', 'Helipad', 'Ammo Bunker' } }
        },
        areas = { config.c.area.AREA_OF_OPS_NORTH },
        filterNames = { 'findC2' },
        contactAge = 60 * 60,
        minTargetCount = 1
      },
    }
  },
  STRIKE_AB_W_3 = {
    {
      timeToReady = config.readytime,
      striker = {
        baseGUID = config.base.ZHANGPU_AAB,
        weaponDBID = config.weapon.KAB1500,
        unitDBID = config.platform.SU30,
        unitCount = 12,
        loadoutID = config.loadout.SU30_KAB1500,
        -- startTime = '2027-06-09 05:40:00',
        missionParams = { name = 'STRIKE/AB/S/2', type = 'strike', opts = { type = 'land' } },
        emcon = 'Radar=Passive;OECM=Active'
      },
      escort = {
        baseGUID = config.base.HUIAN_AAB,
        weaponDBID = config.weapon.PL15,
        unitDBID = config.platform.J20,
        unitCount = 8,
        loadoutID = config.loadout.J20_PL15,
        missionParams = {
          name = 'SWEEP/AB/S/2',
          type = 'patrol',
          opts = {
            type = 'aaw',
            OneThirdRule = false,
            FlightSize = 4,
            CheckOPAREA = false,
            CheckWWR = false,
            prosecutionZone = config.c.area.TARGET_AREA_SOUTH_PROSECUTION,
            patrolZone = config.c.area.TARGET_AREA_SOUTH_PATROL
          }
        },
        emcon = 'Radar=Passive;OECM=Active'
      },
      wildWeasel = {
        baseGUID = config.base.ZHANGZHOU_LONGXI_AB,
        weaponDBID = config.weapon.YJ91_ARM,
        unitDBID = config.platform.SU30,
        unitCount = 8,
        loadoutID = config.loadout.SU30_YJ91,
        missionParams = {
          name = 'SEAD/AB/S/2',
          type = 'patrol',
          opts = {
            type = 'sead',
            OneThirdRule = false,
            FlightSize = 4,
            CheckOPAREA = false,
            CheckWWR = false,
            prosecutionZone = config.c.area.TARGET_AREA_SOUTH_PROSECUTION,
            patrolZone = config.c.area.TARGET_AREA_SOUTH_PATROL
          }
        },
        emcon = 'Radar=Passive;OECM=Active'
      },
      jammer = {
        baseGUID = config.base.ZHANGPU_AAB,
        unitDBID = config.platform.Y9,
        weaponDBID = 0,
        unitCount = 1,
        loadoutID = nil,
        missionParams = {
          name = 'JAMMING/AB/S/2',
          type = 'support',
          opts = { zone = config.c.area.TARGET_AREA_SOUTH_PATROL }
        },
        emcon = 'Radar=Passive;OECM=Active'
      },
      tanker = nil,
      reconUAV = nil,
      target = {
        list = {},
        objs = {
          { baseName = 'Pingtung South AB', subTypes = { 'Ammo Bunker' } },
          { baseName = 'Tainan AB',         subTypes = { 'Ammo Bunker' } },
          { baseName = 'Magong AB',         subTypes = { 'Ammo Bunker' } }
        },
        areas = { config.c.area.AREA_OF_OPS_SOUTH },
        filterNames = { 'findC2' },
        contactAge = 60 * 60,
        minTargetCount = 1
      },
      hasLaunched = false
    }
  },
  STRIKE_AB_W_AAR_1 = {
    {
      timeToReady = config.readytime,
      striker = {
        baseGUID = config.base.RUGOA_AB,
        weaponDBID = config.weapon.AKD88,
        unitDBID = config.platform.J16,
        unitCount = 12,
        loadoutID = config.loadout.J16_AKD88,
        startTime = nil,
        missionParams = { name = 'STRIKE/AB/N/1', type = 'strike', opts = { type = 'land' } },
        emcon = 'Radar=Passive;OECM=Active'
      },
      escort = {
        baseGUID = config.base.WUHU_AB,
        weaponDBID = config.weapon.PL15,
        unitDBID = config.platform.J20,
        unitCount = 4,
        loadoutID = config.loadout.J20_PL15,
        missionParams = {
          name = 'SWEEP/AB/N/1',
          type = 'patrol',
          opts = {
            type = 'aaw',
            OneThirdRule = false,
            FlightSize = 4,
            CheckOPAREA = false,
            CheckWWR = false,
            prosecutionZone = config.c.area.TARGET_AREA_NORTH_PROSECUTION,
            patrolZone = config.c.area.TARGET_AREA_NORTH_PATROL,
            TankerUsage = 1,
            TankerMissionList = { 'AAR/E' },
            FuelQtyToStartLookingForTanker_airborne = 85,
            MaxReceiversInQueuePerTanker_airborne = 2,
            LaunchMissionWithoutTankersInPlace = true,
            TankerMaxDistance_airborne = 50
          }
        },
        emcon = 'Radar=Passive;OECM=Active'
      },
      wildWeasel = {
        baseGUID = config.base.RUGOA_AB,
        weaponDBID = config.weapon.YJ91_ASM,
        unitDBID = config.platform.J16,
        unitCount = 4,
        loadoutID = config.loadout.J16_YJ91,
        missionParams = {
          name = 'SEAD/AB/N/1',
          type = 'patrol',
          opts = {
            type = 'sead',
            OneThirdRule = false,
            FlightSize = 4,
            CheckOPAREA = false,
            CheckWWR = false,
            prosecutionZone = config.c.area.TARGET_AREA_NORTH_PROSECUTION,
            patrolZone = config.c.area.TARGET_AREA_NORTH_PATROL,
            TankerUsage = 1,
            TankerMissionList = { 'AAR/E' },
            FuelQtyToStartLookingForTanker_airborne = 85,
            MaxReceiversInQueuePerTanker_airborne = 2,
            LaunchMissionWithoutTankersInPlace = true,
            TankerMaxDistance_airborne = 50
          }
        },
        emcon = 'Radar=Passive;OECM=Active'
      },
      jammer = {
        baseGUID = config.base.XIAHGTANG_AB,
        unitDBID = config.platform.J16D,
        weaponDBID = 0,
        unitCount = 1,
        loadoutID = nil,
        missionParams = {
          name = 'JAMMING/AB/N/1',
          type = 'support',
          opts = {
            zone = config.c.area.TARGET_AREA_NORTH_PATROL,
            TankerUsage = 1,
            TankerMissionList = { 'AAR/E' },
            FuelQtyToStartLookingForTanker_airborne = 90,
            MaxReceiversInQueuePerTanker_airborne = 2,
            LaunchMissionWithoutTankersInPlace = true,
            TankerMaxDistance_airborne = 50
          }
        },
        emcon = 'Radar=Passive;OECM=Active'
      },
      tanker = {
        baseGUID = config.base.SHUIMEN_AAB,
        unitDBID = config.platform.HY6U_BADGER,
        weaponDBID = 0,
        unitCount = 4,
        loadoutID = nil,
        missionParams = {
          name = 'AAR/E',
          type = 'support',
          opts = {
            OneThirdRule = false,
            FlightSize = 1,
            zone = config.c.area.AAR_PATROL_2
          }
        },
        emcon = 'Radar=Passive;OECM=Passive'
      },
      reconUAV = nil,
      target = {
        list = {},
        objs = {
          { baseName = 'Hsinchu AB', subTypes = { 'Shelter', 'Helipad', 'Ammo Bunker' } }
        },
        areas = { config.c.area.AREA_OF_OPS_NORTH },
        filterNames = {},
        contactAge = 60 * 60,
        minTargetCount = 1
      },
    }
  },
  AIR_INTERCEPT_E = {
    {
      timeToReady = config.readytime,
      striker = {
        baseGUID = config.base.WUHU_AB,
        weaponDBID = config.weapon.PL15,
        unitDBID = config.platform.J20,
        unitCount = 6,
        loadoutID = config.loadout.J20_PL15,
        -- startTime = '2027-06-09 06:40:00',
        -- startTime = '2027-06-09 01:05:00',
        missionParams = {
          name = 'AIR INTERCEPT/E',
          type = 'strike',
          opts = {
            type = 'aaw',
            TankerUsage = 1,
            TankerMissionList = { 'AAR/E' },
            FuelQtyToStartLookingForTanker_airborne = 65,
            MaxReceiversInQueuePerTanker_airborne = 2,
            LaunchMissionWithoutTankersInPlace = true
          }
        },
        emcon = 'Radar=Passive;OECM=Active'
      },
      escort = nil,
      wildWeasel = nil,
      jammer = nil,
      tanker = {
        baseGUID = config.base.SHUIMEN_AAB,
        unitDBID = config.platform.HY6U_BADGER,
        weaponDBID = 0,
        unitCount = 3,
        loadoutID = nil,
        missionParams = {
          name = 'AAR/E',
          type = 'support',
          opts = {
            OneThirdRule = false,
            FlightSize = 1,
            zone = config.c.area.AAR_PATROL
          }
        },
        emcon = 'Radar=Passive;OECM=Passive'
      },
      reconUAV = nil,
      target = {
        list = {},
        objs = nil,
        areas = { config.c.area.AREA_OF_OPS_PACIFIC },
        filterNames = { 'findAirborne' },
        contactAge = 60 * 60,
        minTargetCount = 1
      }
    }
  },
  STRIKE_AB_E_1 = {
    {
      timeToReady = config.readytime,
      striker = {
        baseGUID = 'CSG',
        weaponDBID = config.weapon.LS_6_500,
        unitDBID = config.platform.J15,
        unitCount = 12,
        loadoutID = config.loadout.J15_LS6_500,
        -- startTime = '2027-06-09 07:00:00',
        missionParams = { name = 'STRIKE/AB/JHI', type = 'strike', opts = { type = 'land' } },
        emcon = 'Radar=Passive;OECM=Active'
      },
      escort = nil,
      -- escort = {
      --   baseGUID = 'CSG',
      --   weaponDBID = config.weapon.PL15,
      --   unitDBID = config.platform.J_15,
      --   unitCount = 8,
      --   loadoutID = config.loadout.J15_YJ91,
      --   missionParams = {
      --     name = 'SWEAP/AB/JHI',
      --     type = 'patrol',
      --     opts = {
      --       type = 'aaw',
      --       OneThirdRule = false,
      --       FlightSize = 4,
      --       CheckOPAREA = false,
      --       CheckWWR = false,
      --       prosecutionZone = config.c.areas.TARGET_AREA_JHI_PROSECUTION,
      --       patrolZone = config.c.areas.TARGET_AREA_JHI_PATROL
      --     }
      --   },
      --   emcon = 'Radar=Passive;OECM=Active'
      -- },
      wildWeasel = {
        baseGUID = 'CSG',
        weaponDBID = config.weapon.YJ91_ASM,
        unitDBID = config.platform.J15,
        unitCount = 8,
        loadoutID = config.loadout.J15_YJ91,
        missionParams = {
          name = 'SEAD/AB/JHI',
          type = 'patrol',
          opts = {
            type = 'sead',
            OneThirdRule = false,
            FlightSize = 4,
            CheckOPAREA = false,
            CheckWWR = false,
            prosecutionZone = config.c.area.TARGET_AREA_JHI_PROSECUTION,
            patrolZone = config.c.area.TARGET_AREA_JHI_PATROL
          }
        },
        emcon = 'Radar=Passive;OECM=Active'
      },
      jammer = {
        baseGUID = 'CSG',
        unitDBID = config.platform.J15D,
        weaponDBID = 0,
        unitCount = 1,
        loadoutID = config.loadout.J15D_EW,
        missionParams = {
          name = 'JAMMING/AB/JHI',
          type = 'support',
          opts = { zone = config.c.area.TARGET_AREA_JHI_PATROL }
        },
        emcon = 'Radar=Passive;OECM=Active'
      },
      tanker = nil,
      reconUAV = nil,
      target = {
        list = {},
        objs = {
          { baseName = 'Jhihhang AB', subTypes = { 'Shelter' } }
        },
        areas = { config.c.area.AREA_OF_OPS_EAST },
        filterNames = nil,
        contactAge = 60 * 60,
        minTargetCount = 1
      },
      hasLaunched = false
    },
    {
      timeToReady = config.readytime,
      loadoutStatus = {
        isLoadoutInitiated = false,
        loadoutInitiatedTime = nil,
        expectedReadyTime = nil,
        loadoutStartTime = nil
      },
      striker = {
        baseGUID = 'CSG',
        weaponDBID = config.weapon.LS_6_500,
        unitDBID = config.platform.J15,
        unitCount = 12,
        loadoutID = config.loadout.J15_LS6_500,
        startTime = nil,
        missionParams = { name = 'STRIKE/AB/E', type = 'strike', opts = { type = 'land' } },
        emcon = 'Radar=Passive;OECM=Active'
      },
      escort = nil,
      -- escort = {
      --   baseGUID = '6Z8LM5-0HMIJ3QGCRQ5F',
      --   weaponDBID = config.weapon.PL15,
      --   unitDBID = config.platform.J_15,
      --   unitCount = 8,
      --   loadoutID = config.loadout.J20_PL15,
      --   missionParams = {
      --     name = 'SWEAP/AB/E',
      --     type = 'patrol',
      --     opts = {
      --       type = 'aaw',
      --       OneThirdRule = false,
      --       FlightSize = 4,
      --       CheckOPAREA = false,
      --       CheckWWR = false,
      --       prosecutionZone = config.c.areas.TARGET_AREA_JIASHAN_PROSECUTION,
      --       patrolZone = config.c.areas.TARGET_AREA_JIASHAN_PATROL
      --     }
      --   },
      --   emcon = 'Radar=Passive;OECM=Active'
      -- },
      wildWeasel = {
        baseGUID = 'CSG',
        weaponDBID = config.weapon.YJ91_ASM,
        unitDBID = config.platform.J15,
        unitCount = 8,
        loadoutID = config.loadout.J15_YJ91,
        missionParams = {
          name = 'SEAD/AB/E',
          type = 'patrol',
          opts = {
            type = 'sead',
            OneThirdRule = false,
            FlightSize = 4,
            CheckOPAREA = false,
            CheckWWR = false,
            prosecutionZone = config.c.area.TARGET_AREA_JIASHAN_PROSECUTION,
            patrolZone = config.c.area.TARGET_AREA_JIASHAN_PATROL
          }
        },
        emcon = 'Radar=Passive;OECM=Active'
      },
      jammer = {
        baseGUID = 'CSG',
        unitDBID = config.platform.J15D,
        weaponDBID = 0,
        unitCount = 1,
        loadoutID = config.loadout.J15D_EW,
        missionParams = {
          name = 'JAMMING/AB/E',
          type = 'support',
          opts = { zone = config.c.area.TARGET_AREA_JIASHAN_PATROL }
        },
        emcon = 'Radar=Passive;OECM=Active'
      },
      tanker = nil,
      reconUAV = nil,
      target = {
        list = {},
        objs = {
          { baseName = 'Jiashan AB', subTypes = { 'Shelter' } }
        },
        areas = { config.c.area.AREA_OF_OPS_EAST },
        filterNames = nil,
        contactAge = 60 * 60,
        minTargetCount = 1
      },
      hasLaunched = false
    }
  },
  ASUW_N_1 = {
    {
      timeToReady = config.readytime,
      striker = {
        baseGUID = config.base.SHUIMEN_AAB,
        weaponDBID = config.weapon.YJ83,
        unitDBID = config.platform.J16,
        unitCount = 8,
        loadoutID = config.loadout.J16_YJ83,
        -- startTime = '2027-06-09 02:40:00',
        missionParams = { name = 'ASUW/N', type = 'strike', opts = { type = 'sea' } },
        emcon = 'Radar=Passive;OECM=Active'
      },
      escort = nil,
      wildWeasel = {
        baseGUID = config.base.SHUIMEN_AAB,
        weaponDBID = config.weapon.YJ91_ARM,
        unitDBID = config.platform.SU30,
        unitCount = 8,
        loadoutID = config.loadout.SU30_YJ91,
        missionParams = {
          name = 'SEAD/ASUW/N',
          type = 'patrol',
          opts = {
            type = 'sead',
            OneThirdRule = false,
            FlightSize = 4,
            CheckOPAREA = false,
            CheckWWR = false,
            zone = config.c.area.AREA_OF_OPS_D
          }
        },
        emcon = 'Radar=Passive;OECM=Active'
      },
      jammer = nil,
      tanker = nil,
      reconUAV = nil,
      target = {
        list = {},
        objs = nil,
        areas = { config.c.area.AREA_OF_OPS_D },
        filterNames = { 'findNavalTargets' },
        contactAge = 60 * 60,
        minTargetCount = 1
      },
      hasLaunched = false
    }
  },
  CAS_N_1 = {
    {
      timeToReady = config.readytime,
      striker = {
        baseGUID = config.base.SHUIMEN_AAB,
        weaponDBID = config.weapon.LS_6_500,
        unitDBID = config.platform.J10C,
        unitCount = 8,
        loadoutID = config.loadout.J10C_LS_6_500,
        -- startTime = '2027-06-09 01:30:00',
        missionParams = { name = 'CAS/N', type = 'strike', opts = { type = 'land' } },
        emcon = 'Radar=Passive;OECM=Active'
      },
      escort = nil,
      wildWeasel = nil,
      jammer = nil,
      tanker = nil,
      reconUAV = nil,
      target = {
        list = {},
        objs = nil,
        areas = { config.c.area.LANDING_TAOYUAN },
        filterNames = { 'findInfantry' },
        contactAge = 60 * 60,
        minTargetCount = 1
      },
      hasLaunched = false
    }
  }
}

-- MLRS
config.t.ground.mlrs.wpnDefault = 144
config.t.ground.mlrs.ammoThreshold = 25
config.t.ground.mlrs.positions = {
  pingzhen = {
    RL = {
      course = {
        { lat = 'N 24.55.15', lon = 'E 121.16.02', desiredSpeed = 10, presetThrottle = 'Flank' },
        { lat = 'N 24.57.13', lon = 'E 121.13.45', desiredSpeed = 10, presetThrottle = 'Flank' },
      },
      area = config.t.area.RELOAD_POINT_PINGZHEN
    },
    FP = {
      {
        course = {
          { lat = 'N 24.55.15', lon = 'E 121.16.02', desiredSpeed = 10, presetThrottle = 'Flank' },
          { lat = 'N 24.53.01', lon = 'E 121.14.17', desiredSpeed = 10, presetThrottle = 'Flank' },
        },
        area = config.t.area.FIRE_POINT_PINGZHEN_1
      },
    },
    AHA = {
      course = {
        { lat = 'N 24.55.15', lon = 'E 121.16.02', desiredSpeed = 10, presetThrottle = 'Flank' },
      },
      area = config.t.area.AMMO_HOLDING_AREA_PINGZHEN
    },
  },
}
config.t.ground.mlrs.reloadTime = 30 * 60


-- SRBM
config.t.ground.srbm.wpnDefault = 27
config.t.ground.srbm.ammoThreshold = 25
config.t.ground.srbm.positions = {
  pingzhen = {
    RL = {
      course = {
        { lat = 'N 24.55.15', lon = 'E 121.16.02', desiredSpeed = 10, presetThrottle = 'Flank' },
        { lat = 'N 24.57.13', lon = 'E 121.13.45', desiredSpeed = 10, presetThrottle = 'Flank' },
      },
      area = config.t.area.RELOAD_POINT_PINGZHEN
    },
    FP = {
      {
        course = {
          { lat = 'N 24.55.15', lon = 'E 121.16.02', desiredSpeed = 10, presetThrottle = 'Flank' },
          { lat = 'N 24.53.01', lon = 'E 121.14.17', desiredSpeed = 10, presetThrottle = 'Flank' },
        },
        area = config.t.area.FIRE_POINT_PINGZHEN_1
      },
    },
    AHA = {
      course = {
        { lat = 'N 24.55.15', lon = 'E 121.16.02', desiredSpeed = 10, presetThrottle = 'Flank' },
      },
      area = config.t.area.AMMO_HOLDING_AREA_PINGZHEN
    },
  },
  dadu = {
    RL = {
      course = {
        { lat = 'N 24.09.07', lon = 'E 120.36.27', desiredSpeed = 10, presetThrottle = 'Flank' },
        { lat = 'N 24.09.09', lon = 'E 120.35.47', desiredSpeed = 10, presetThrottle = 'Flank' },
      },
      area = config.t.area.RELOAD_POINT_DADU
    },
    FP = {
      {
        course = {
          { lat = 'N 24.09.07', lon = 'E 120.36.27', desiredSpeed = 10, presetThrottle = 'Flank' },
          { lat = 'N 24.11.43', lon = 'E 120.38.29', desiredSpeed = 10, presetThrottle = 'Flank' },
        },
        area = config.t.area.FIRE_POINT_DADU_1
      },
    },
    AHA = {
      course = {
        { lat = 'N 24.09.07', lon = 'E 120.36.27', desiredSpeed = 10, presetThrottle = 'Flank' },
      },
      area = config.t.area.AMMO_HOLDING_AREA_DADU
    },
  },
}
config.t.ground.srbm.reloadTime = 10 * 60


-- GLCM
config.t.ground.glcm.wpnDefault = 24
config.t.ground.glcm.ammoThreshold = 25
config.t.ground.glcm.positions = {
  quanxi = {
    RL = {
      course = {},
      area = config.t.area.RELOAD_POINT_QUANXI
    },
    FP = {
      {
        course = {},
        area = config.t.area.FIRE_POINT_PINGZHEN_1
      },
    },
    AHA = {
      course = {},
      area = config.t.area.AMMO_HOLDING_AREA_QUANXI
    },
  },
  neipu = {
    RL = {
      area = config.t.area.RELOAD_POINT_NEIPU
    },
    FP = {
      {
        area = config.t.area.FIRE_POINT_NEIPU_1
      },
    },
    AHA = {
      course = {},
      area = config.t.area.AMMO_HOLDING_AREA_NEIPU
    },
  }
}
config.t.ground.glcm.reloadTime = 45 * 60


-- ASCM
config.t.ground.ascm.wpnDefault = 16
config.t.ground.ascm.ammoThreshold = 25
config.t.ground.ascm.positions = {
  pingzhen = {
    RL = {
      course = {
        { lat = 'N 24.55.15', lon = 'E 121.16.02', desiredSpeed = 10, presetThrottle = 'Flank' },
        { lat = 'N 24.57.13', lon = 'E 121.13.45', desiredSpeed = 10, presetThrottle = 'Flank' },
      },
      area = config.t.area.RELOAD_POINT_PINGZHEN
    },
    FP = {
      {
        course = {
          { lat = 'N 24.55.15', lon = 'E 121.16.02', desiredSpeed = 10, presetThrottle = 'Flank' },
          { lat = 'N 24.53.01', lon = 'E 121.14.17', desiredSpeed = 10, presetThrottle = 'Flank' },
        },
        area = config.t.area.FIRE_POINT_PINGZHEN_1
      },
    },
    AHA = {
      course = {
        { lat = 'N 24.55.15', lon = 'E 121.16.02', desiredSpeed = 10, presetThrottle = 'Flank' },
      },
      area = config.t.area.AMMO_HOLDING_AREA_PINGZHEN
    },
  },
  dadu = {
    RL = {
      course = {
        { lat = 'N 24.09.07', lon = 'E 120.36.27', desiredSpeed = 10, presetThrottle = 'Flank' },
        { lat = 'N 24.09.09', lon = 'E 120.35.47', desiredSpeed = 10, presetThrottle = 'Flank' },
      },
      area = config.t.area.RELOAD_POINT_DADU
    },
    FP = {
      {
        course = {
          { lat = 'N 24.09.07', lon = 'E 120.36.27', desiredSpeed = 10, presetThrottle = 'Flank' },
          { lat = 'N 24.11.43', lon = 'E 120.38.29', desiredSpeed = 10, presetThrottle = 'Flank' },
        },
        area = config.t.area.FIRE_POINT_DADU_1
      },
    },
    AHA = {
      course = {
        { lat = 'N 24.09.07', lon = 'E 120.36.27', desiredSpeed = 10, presetThrottle = 'Flank' },
      },
      area = config.t.area.AMMO_HOLDING_AREA_DADU
    },
  },
  neipu = {
    RL = {
      area = config.t.area.RELOAD_POINT_NEIPU
    },
    FP = {
      {
        area = config.t.area.FIRE_POINT_NEIPU_1
      },
    },
    AHA = {
      course = {},
      area = config.t.area.AMMO_HOLDING_AREA_NEIPU
    },
  },
  luzhu = {
    RL = {
      area = config.t.area.RELOAD_POINT_LUZHU
    },
    FP = {
      {
        area = config.t.area.FIRE_POINT_LUZHU_1
      },
    },
    AHA = {
      course = {},
      area = config.t.area.AMMO_HOLDING_AREA_LUZHU
    },
  },
  dong = {
    RL = {
      area = config.t.area.RELOAD_POINT_DONG
    },
    FP = {
      {
        area = config.t.area.FIRE_POINT_DONG_1
      },
    },
    AHA = {
      course = {},
      area = config.t.area.AMMO_HOLDING_AREA_DONG
    },
  },
}
config.t.ground.ascm.reloadTime = 45 * 60


-- Runway repairment
config.t.repairRunway.percentagePerHour = 3


-- IADS
config.t.IADS.ratio = { ROCC = 1.5, TAAOC = 1.5 }


-- Aircraft settings
config.t.air.landBased.wpnNum = 8
config.t.air.landBased.deployedACs = {
  {
    name = 'Ching Chuang Kang AB',
    baseGUID = config.base.CHING_CHUANG_KANG_AB,
    embarkedUnits = {
      {
        side = 'Taiwan',
        type = 'Air',
        dbid = config.platform.IDF,
        name = '3rd Tactical Fighter Wing',
        loadouts = {
          { loadoutId = config.loadout.IDF_WAN_CHIEN, num = 8 },
        }
      }
    },
    loadouts = {
      { loadoutId = config.loadout.IDF_WAN_CHIEN, num = config.t.air.landBased.wpnNum }, --Wan Chien X 2
    }
  },
  {
    name = 'Chiayi AB',
    baseGUID = config.base.CHIAYI_AB,
    embarkedUnits = {
      {
        side = 'Taiwan',
        type = 'Air',
        dbid = config.platform.F16V_BLK20,
        name = '4th Tactical Fighter Wing',
        loadouts = {
          { loadoutId = config.loadout.F16V_BLK20_AMRAAM, num = 8 },
        }
      }
    },
    loadouts = {
      { loadoutId = config.loadout.F16V_BLK20_AMRAAM,  num = config.t.air.landBased.wpnNum }, --AMRAAM X 4
      { loadoutId = config.loadout.F16V_BLK20_HARPOON, num = config.t.air.landBased.wpnNum }, --Harpoon X 2
      { loadoutId = config.loadout.F16V_BLK20_GBU,     num = config.t.air.landBased.wpnNum }, --GBU X 2
    }
  },
  {
    name = 'Tainan AB',
    baseGUID = config.base.TAINAN_AB,
    embarkedUnits = {
      {
        side = 'Taiwan',
        type = 'Air',
        dbid = config.platform.IDF,
        name = '1st Tactical Fighter Wing',
        loadouts = {
          { loadoutId = config.loadout.IDF_WAN_CHIEN, num = 4 },
        }
      }
    },
    loadouts = {
      { loadoutId = config.loadout.IDF_WAN_CHIEN, num = config.t.air.landBased.wpnNum }, --Wan Chien X 2
    }
  },
  {
    name = 'Magong AB',
    baseGUID = config.base.MAGONG_AB,
    embarkedUnits = {
      {
        side = 'Taiwan',
        type = 'Air',
        dbid = config.platform.IDF,
        name = '1st Tactical Fighter Wing',
        loadouts = {
          { loadoutId = config.loadout.IDF_WAN_CHIEN, num = 4 },
        }
      }
    },
    loadouts = {
      { loadoutId = config.loadout.IDF_WAN_CHIEN, num = config.t.air.landBased.wpnNum }, --Wan Chien X 2
    }
  },
  {
    name = 'Guiren AAB',
    baseGUID = config.base.GUIREN_AAB,
    embarkedUnits = {
      {
        side = 'Taiwan',
        type = 'Air',
        dbid = config.platform.AH1W,
        name = '603rd Air Cavalry Bde',
        loadouts = {
          { loadoutId = config.loadout.AH1W_HELLFIRE, num = 8, missionName = 'ASUW/ACV/PENGHU' },
        }
      }
    },
    loadouts = {
      { loadoutId = config.loadout.AH1W_HELLFIRE, num = config.t.air.landBased.wpnNum }, --Hellfire X 8
    }
  },
  {
    name = 'Pingtung North AB',
    baseGUID = config.base.PINGTUNG_NORTH_AB,
    embarkedUnits = {
      {
        side = 'Taiwan',
        type = 'Air',
        dbid = config.platform.E2K,
        name = '6th Mixed Wing',
        loadouts = {
          { loadoutId = config.loadout.E2K_AEW, num = 3, missionName = 'FERRY/2' },
        }
      },
    }
  },
  {
    name = 'Pingtung South AB',
    baseGUID = config.base.PINGTUNG_SOUTH_AB,
    embarkedUnits = {
      {
        side = 'Taiwan',
        type = 'Air',
        dbid = config.platform.P3C,
        name = '6th Mixed Wing',
        loadouts = {
          { loadoutId = config.loadout.P3C_ASW, num = 3, missionName = 'ASW/E' },
        }
      },
      {
        side = 'Taiwan',
        type = 'Air',
        dbid = config.platform.C130HE,
        name = '6th Mixed Wing',
        loadouts = {
          { loadoutId = config.loadout.C130HE_EW, num = 1, missionName = 'FERRY/2' },
        }
      },
    }
  },
  {
    name = 'Taitung/Jhihhang AB',
    baseGUID = config.base.TAITUNG_JHIHHANG_AB,
    embarkedUnits = {
      {
        side = 'Taiwan',
        type = 'Air',
        dbid = config.platform.F16V_BLK70,
        name = '7th Tactical Fighter Wing',
        loadouts = {
          { loadoutId = config.loadout.F16V_BLK70_SLAM_ER, num = 8, missionName = 'FERRY/3' },
        }
      }
    },
    loadouts = {
      { loadoutId = config.loadout.F16V_BLK70_SLAM_ER, num = config.t.air.landBased.wpnNum }, --SLAMER X 2
      { loadoutId = config.loadout.F16V_BLK70_JDAM,    num = config.t.air.landBased.wpnNum }, --JDAM X 4
      { loadoutId = config.loadout.F16V_BLK70_HARM,    num = config.t.air.landBased.wpnNum }, --HARM X 2
      { loadoutId = config.loadout.F16V_BLK70_JSOW,    num = config.t.air.landBased.wpnNum }, --JSOW X 4
    }
  },
  {
    name = 'Jiashan AB',
    baseGUID = config.base.JIASHAN_AB,
    embarkedUnits = {
      {
        side = 'Taiwan',
        type = 'Air',
        dbid = config.platform.MQ9B,
        name = '5th Tactical Mixed Wing',
        loadouts = {
          { loadoutId = config.loadout.MQ9B_RECON, num = 3, missionName = 'AEW/S' },
        }
      },
      {
        side = 'Taiwan',
        type = 'Air',
        dbid = config.platform.F16V_BLK20,
        name = '5th Tactical Mixed Wing',
        loadouts = {
          { loadoutId = config.loadout.F16V_BLK20_HARPOON, num = 8, },
        }
      }
    },
    loadouts = {
      { loadoutId = config.loadout.F16V_BLK20_AMRAAM,  num = config.t.air.landBased.wpnNum }, --AMRAAM X 4
      { loadoutId = config.loadout.F16V_BLK20_HARPOON, num = config.t.air.landBased.wpnNum }, --Harpoon X 2
      { loadoutId = config.loadout.F16V_BLK20_GBU,     num = config.t.air.landBased.wpnNum }, --GBU X 2
    }
  },
  {
    name = 'Hsinchu AB',
    baseGUID = config.base.HSINCHU_AB,
    embarkedUnits = {
      {
        side = 'Taiwan',
        type = 'Air',
        dbid = config.platform.MIRAGE2000,
        name = '2nd Tactical Fighter Wing',
        loadouts = {
          { loadoutId = config.loadout.MIRAGE2000_MICA, num = 8, },
        }
      }
    },
    loadouts = {
      { loadoutId = config.loadout.MIRAGE2000_MICA, num = config.t.air.landBased.wpnNum }, --MICA X 4

    }
  },
  {
    name = 'Longtan AAB',
    baseGUID = config.base.LONGTAN_AAB,
    embarkedUnits = {
      {
        side = 'Taiwan',
        type = 'Air',
        dbid = config.platform.AH64E,
        name = '601st Air Cavalry Bde',
        loadouts = {
          { loadoutId = config.loadout.AH64E_HELLFIRE, num = 8, missionName = 'ASUW/ACV/W' },
        }
      }
    },
    loadouts = {
      { loadoutId = config.loadout.AH64E_HELLFIRE, num = config.t.air.landBased.wpnNum }, --Hellfire X 16
    }
  },
  {
    name = 'Taoyuan International Airport',
    baseGUID = config.base.TAOYUAN_AIRPORT,
    embarkedUnits = {
      {
        side = 'Taiwan',
        type = 'Air',
        dbid = config.platform.CHUNG_SHYANG_II,
        name = '1st Maritime Tactical Recon Sqn',
        loadouts = {
          { loadoutId = config.loadout.CHUNG_SHYANG_II_RECON, num = 3, missionName = 'RECON/3' },
        }
      }
    }
  },
  {
    name = 'Rende Emergency Highway Strip',
    baseGUID = config.base.RENDE_STRIP,
    loadouts = {
      { loadoutId = config.loadout.IDF_WAN_CHIEN, num = config.t.air.landBased.wpnNum }, --Wan Chien X 2
    }
  },
  {
    name = 'Madou Emergency Highway Strip',
    baseGUID = config.base.MADOU_STRIP,
    loadouts = {
      { loadoutId = config.loadout.F16V_BLK20_AMRAAM,  num = config.t.air.landBased.wpnNum }, --AMRAAM X 4
      { loadoutId = config.loadout.F16V_BLK20_HARPOON, num = config.t.air.landBased.wpnNum }, --Harpoon X 2
      { loadoutId = config.loadout.F16V_BLK20_GBU,     num = config.t.air.landBased.wpnNum }, --GBU X 2
    }
  },
  {
    name = 'Minxiong Emergency Highway Strip',
    baseGUID = config.base.MINXIONG_STRIP,
    loadouts = {
      { loadoutId = config.loadout.F16V_BLK20_AMRAAM,  num = config.t.air.landBased.wpnNum }, --AMRAAM X 4
      { loadoutId = config.loadout.F16V_BLK20_HARPOON, num = config.t.air.landBased.wpnNum }, --Harpoon X 2
      { loadoutId = config.loadout.F16V_BLK20_GBU,     num = config.t.air.landBased.wpnNum }, --GBU X 2
    }
  },
  {
    name = 'Tainan Field Airdrome',
    baseGUID = config.base.TAINAN_FIELD_AIRDROME,
    loadouts = {
      { loadoutId = config.loadout.AH1W_HELLFIRE, num = config.t.air.landBased.wpnNum }, --Hellfire X 8
    }
  },
  {
    name = 'Hsinchu Field Airdrome ',
    baseGUID = config.base.HSINCHU_FIELD_AIRDROME,
    loadouts = {
      { loadoutId = config.loadout.AH64E_HELLFIRE, num = config.t.air.landBased.wpnNum }, --Hellfire X 16
    }
  },
}

config.t.surface.sag = {
  ['264th Sqn'] = {
    groupName = '264th Sqn',
    unitList = {
      kidd = {
        dbid = config.platform.KIDD,
        embarkedUnits = {
          {
            side = 'Taiwan',
            type = 'Air',
            dbid = config.platform.S70C,
            name = '2nd ASW Aviation Grp',
            loadouts = {
              { loadoutId = config.loadout.S70C_ASW, num = 2 },
            }
          },
        },
      },
      kangDing = {
        dbid = config.platform.KANG_DING,
        embarkedUnits = {
          {
            side = 'Taiwan',
            type = 'Air',
            dbid = config.platform.S70C,
            name = '2nd ASW Aviation Grp',
            loadouts = {
              { loadoutId = config.loadout.S70C_ASW, num = 1 },
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

config.t.surface.deployedShips = {
  {
    name = 'Port of Keelung',
    baseGUID = config.base.PORT_OF_KEELUNG,
    embarkedUnits = {
      {
        side = 'Taiwan',
        type = 'Ship',
        dbid = config.platform.TA_CHIANG,
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
config.u.SIGINT.maxCount = 1


-- Score
config.s.destroyingAircraftOnTheGround = 5
config.s.destroyingAmmo = 100
config.s.destroyingAmmoTruck = 20
config.s.lhd = 10
config.s.lst = 10
config.s.ddg = 10
config.s.cv = 100
config.s.ifv = -5
config.s.infantry = -3
config.s.sub = 15
config.s.uav = 20
config.s.tel = 20
config.s.weaponDBID = config.weapon.MK48_TORPEDO
config.s.attackBeforeTheHHour = -1000
config.s.undergroundShelterIsDestroyed = -200
config.s.destroyingCivilianFacility = -100

return config
