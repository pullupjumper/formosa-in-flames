local constants = {}

constants.AREAS = {
  RELOAD_POINT_PINGZHEN = { "RP-100174", "RP-100175", "RP-100176", "RP-100177" },
  FIRE_POINT_PINGZHEN_1 = { "RP-44300", "RP-44301", "RP-44302", "RP-44303" },
  AMMO_HOLDING_AREA_PINGZHEN = { "RP-114539", "RP-114540", "RP-114541", "RP-114542" },
  RELOAD_POINT_DADU = { "RP-101781", "RP-101782", "RP-101783", "RP-101784" },
  FIRE_POINT_DADU_1 = { "RP-101785", "RP-101786", "RP-101787", "RP-101788" },
  AMMO_HOLDING_AREA_DADU = { "RP-114555", "RP-114556", "RP-114557", "RP-114558" },
  RELOAD_POINT_QUANXI = { "RP-100170", "RP-100171", "RP-100172", "RP-100173" },
  FIRE_POINT_QUANXI_1 = { "RP-44300", "RP-44301", "RP-44302", "RP-44303" },
  AMMO_HOLDING_AREA_QUANXI = { "RP-114547", "RP-114548", "RP-114549", "RP-114550" },
  RELOAD_POINT_NEIPU = { "RP-100166", "RP-100167", "RP-100168", "RP-100169" },
  FIRE_POINT_NEIPU_1 = { "RP-44288", "RP-44289", "RP-44290", "RP-44291" },
  AMMO_HOLDING_AREA_NEIPU = { "RP-114563", "RP-114564", "RP-114565", "RP-114566" },
  RELOAD_POINT_LUZHU = { "RP-107197", "RP-107198", "RP-107199", "RP-107200" },
  FIRE_POINT_LUZHU_1 = { "RP-107201", "RP-107202", "RP-107203", "RP-107204" },
  AMMO_HOLDING_AREA_LUZHU = { "RP-114435", "RP-114436", "RP-114437", "RP-114438" },
  RELOAD_POINT_DONG = { "RP-116585", "RP-116586", "RP-116587", "RP-116588" },
  FIRE_POINT_DONG_1 = { "RP-116593", "RP-116594", "RP-116595", "RP-116596" },
  AMMO_HOLDING_AREA_DONG = { "RP-116581", "RP-116582", "RP-116583", "RP-116584" },
  THEATER_OF_OPS_3RD = { "RP-83642", "RP-83643", "RP-83644", "RP-83645" },
  THEATER_OF_OPS_2ND = { "RP-156521", "RP-156522", "RP-156523", "RP-156524", "RP-156525", "RP-156526" },
  THEATER_OF_OPS_5TH = {
    "RP-156527", "RP-156528", "RP-156529",
    "RP-156530", "RP-156531", "RP-156532",
    "RP-156533", "RP-156534", "RP-156535"
  },
  THEATER_OF_OPS_4TH = {
    "RP-156536", "RP-156537", "RP-156538",
    "RP-156539", "RP-156540", "RP-156541",
    "RP-156542", "RP-156543", "RP-156544",
    "RP-156545", "RP-156546", "RP-156547", "RP-156548"
  },
  groundAscmTestNai1 = { "RP-7760", "RP-7761", "RP-7762", "RP-7763" },
  groundAscmTestNai2 = { "RP-7787", "RP-7788", "RP-7789", "RP-7790" },
  MILITARY_SUB_DISTRICT_FUZHOU = { "RP-85138", "RP-85139", "RP-85140", "RP-85141", },
  MILITARY_SUB_DISTRICT_PUTIAN = { "RP-156577", "RP-156578", "RP-156579", "RP-156580", },
  MILITARY_SUB_DISTRICT_CHANGZHOU = { "RP-156581", "RP-156582", "RP-156583", "RP-156584", },
  MILITARY_SUB_DISTRICT_XIAMEN = { "RP-156585", "RP-156586", "RP-156587", "RP-156588", },
  MILITARY_SUB_DISTRICT_ZHANGZHOU = { "RP-85134", "RP-85135", "RP-85136", "RP-85137", },
  MILITARY_SUB_DISTRICT_SHANTOU = { "RP-156589", "RP-156590", "RP-156591", "RP-156592", },
  MILITARY_SUB_DISTRICT_SHANWEI = { "RP-156593", "RP-156594", "RP-156595", "RP-156596", },
  MILITARY_SUB_DISTRICT_MEIZHOU = { "RP-85130", "RP-85131", "RP-85132", "RP-85133", },
  RELOAD_POINT_PINGTAN = { "RP-114443", "RP-114444", "RP-114445", "RP-114446" },
  HIDE_AREA_PINGTAN = { "RP-114439", "RP-114440", "RP-114441", "RP-114442" },
  FIRE_POINT_PINGTAN_1 = { "RP-44264", "RP-44265", "RP-44266", "RP-44267" },
  FIRE_POINT_PINGTAN_2 = { "RP-44260", "RP-44261", "RP-44262", "RP-44263" },
  AMMO_HOLDING_AREA_PINGTAN = { "RP-114447", "RP-114448", "RP-114449", "RP-114450" },
  RELOAD_POINT_CHINCHEW = { "RP-114455", "RP-114456", "RP-114457", "RP-114458" },
  HIDE_AREA_CHINCHEW = { "RP-114451", "RP-114452", "RP-114453", "RP-114454" },
  FIRE_POINT_CHINCHEW_1 = { "RP-46390", "RP-46391", "RP-46392", "RP-46393" },
  AMMO_HOLDING_AREA_CHINCHEW = { "RP-114459", "RP-114460", "RP-114461", "RP-114462" },
  RELOAD_POINT_BRIGADE615 = { "RP-114467", "RP-114468", "RP-114469", "RP-114470" },
  HIDE_AREA_BRIGADE615 = { "RP-114463", "RP-114464", "RP-114465", "RP-114466" },
  FIRE_POINT_BRIGADE615_1 = { "RP-44322", "RP-44323", "RP-44324", "RP-44325" },
  AMMO_HOLDING_AREA_BRIGADE615 = { "RP-114471", "RP-114472", "RP-114473", "RP-114474" },
  RELOAD_POINT_BRIGADE614 = { "RP-114479", "RP-114480", "RP-114481", "RP-114482" },
  HIDE_AREA_BRIGADE614 = { "RP-114475", "RP-114476", "RP-114477", "RP-114478" },
  FIRE_POINT_BRIGADE614_1 = { "RP-44335", "RP-44336", "RP-44337", "RP-44338" },
  AMMO_HOLDING_AREA_BRIGADE614 = { "RP-114483", "RP-114484", "RP-114485", "RP-114486" },
  RELOAD_POINT_BRIGADE636 = { "RP-114491", "RP-114492", "RP-114493", "RP-114494" },
  HIDE_AREA_BRIGADE636 = { "RP-114487", "RP-114488", "RP-114489", "RP-114490" },
  FIRE_POINT_BRIGADE636_1 = { "RP-44357", "RP-44358", "RP-44359", "RP-44360" },
  AMMO_HOLDING_AREA_BRIGADE636 = { "RP-114495", "RP-114496", "RP-114497", "RP-114498" },
  RELOAD_POINT_BRIGADE616 = { "RP-114503", "RP-114504", "RP-114505", "RP-114506" },
  HIDE_AREA_BRIGADE616 = { "RP-114499", "RP-114500", "RP-114501", "RP-114502" },
  FIRE_POINT_BRIGADE616_1 = { "RP-44369", "RP-44370", "RP-44371", "RP-44372" },
  AMMO_HOLDING_AREA_BRIGADE616 = { "RP-114507", "RP-114508", "RP-114509", "RP-114510" },
  RELOAD_POINT_BRIGADE613 = { "RP-114515", "RP-114516", "RP-114517", "RP-114518" },
  HIDE_AREA_BRIGADE613 = { "RP-114511", "RP-114512", "RP-114513", "RP-114514" },
  FIRE_POINT_BRIGADE613_1 = { "RP-44391", "RP-44392", "RP-44393", "RP-44394" },
  AMMO_HOLDING_AREA_BRIGADE613 = { "RP-114519", "RP-114520", "RP-114521", "RP-114522" },
  RELOAD_POINT_BRIGADE617 = { "RP-114527", "RP-114528", "RP-114529", "RP-114530" },
  HIDE_AREA_BRIGADE617 = { "RP-114523", "RP-114524", "RP-114525", "RP-114526" },
  FIRE_POINT_BRIGADE617_1 = { "RP-44413", "RP-44414", "RP-44415", "RP-44416" },
  AMMO_HOLDING_AREA_BRIGADE617 = { "RP-114531", "RP-114532", "RP-114533", "RP-114534" },
  RELOAD_POINT_BRIGADE624 = { "RP-156928", "RP-156929", "RP-156930", "RP-156931" },
  HIDE_AREA_BRIGADE624 = { "RP-156932", "RP-156933", "RP-156934", "RP-156935" },
  FIRE_POINT_BRIGADE624_1 = { "RP-156936", "RP-156937", "RP-156938", "RP-156939" },
  AMMO_HOLDING_AREA_BRIGADE624 = { "RP-156924", "RP-156925", "RP-156926", "RP-156927" },
  STARTING_POINT_075_TAOYUAN = { "RP-11169" },
  AREA_OF_OPS_D = { "RP-46580", "RP-46581", "RP-46582", "RP-46583" },
  DESTINATION_075_TAOYUAN = { "RP-4322" },
  DESTINATION_071_TAOYUAN = { "RP-3915" },
  AIRLANDING_TAOYUAN = { "RP-3819", "RP-3820", "RP-3821", "RP-3822" },
  STARTING_POINT_075_SISHU = { "RP-56195" },
  AREA_OF_OPS_F = { "RP-46584", "RP-46585", "RP-46586", "RP-46587" },
  DESTINATION_075_SISHU = { "RP-69332" },
  DESTINATION_071_SISHU = { "RP-69333" },
  STARTING_POINT_075_PENGHU = { "RP-59972" },
  AREA_OF_OPS_E = { "RP-59975", "RP-59976", "RP-59977", "RP-59978" },
  DESTINATION_075_PENGHU = { "RP-59973" },
  DESTINATION_071_PENGHU = { "RP-59974" },
  ANCH_AREA_TAOYUAN = { "RP-9684", "RP-9685", "RP-9686", "RP-9687" },
  LST_ANCH_AREA_TAOYUAN = { "RP-9712", "RP-9713", "RP-9714", "RP-9715" },
  CAS_E = { "RP-6787", "RP-6788", "RP-6789", "RP-6790" },
  OFFLOAD_AREA_TAOYUAN = { "RP-141074", "RP-141075", "RP-141076", "RP-141077" },
  LANDING_TAOYUAN = { "RP-7702", "RP-7703", "RP-7704", "RP-7705" },
  AMPH_VEH_STAGING_AREA_TAOYUAN = { "RP-7722", "RP-7723", "RP-7724", "RP-7725" },
  ANCH_AREA_SISHU = { "RP-69328", "RP-69329", "RP-69330", "RP-69331" },
  LST_ANCH_AREA_SISHU = { "RP-69324", "RP-69325", "RP-69326", "RP-69327" },
  CAS_S = { "RP-73973", "RP-73974", "RP-73975", "RP-73976" },
  OFFLOAD_AREA_SISHU = { "RP-141078", "RP-141079", "RP-141080", "RP-141081" },
  LANDING_SISHU = { "RP-69316", "RP-69317", "RP-69318", "RP-69319" },
  AIRLANDING_CHANGLONG = { "RP-11165", "RP-11166", "RP-11167", "RP-11168" },
  AMPH_VEH_STAGING_AREA_SHISHU = { "RP-69320", "RP-69321", "RP-69322", "RP-69323" },
  ANCH_AREA_PENGHU = { "RP-46576", "RP-46577", "RP-46578", "RP-46579" },
  LST_ANCH_AREA_PENGHU = { "RP-46572", "RP-46573", "RP-46574", "RP-46575" },
  CAS_PENGHU = { "RP-69261", "RP-69262", "RP-69263", "RP-69264" },
  OFFLOAD_AREA_PENGHU = { "RP-141082", "RP-141083", "RP-141084", "RP-141085" },
  LANDING_PENGHU = { "RP-46290", "RP-46291", "RP-46292", "RP-46293" },
  AIRLANDING_PENGHU = { "RP-59968", "RP-59969", "RP-59970", "RP-59971" },
  AMPH_VEH_STAGING_AREA_PENGHU = { "RP-46329", "RP-46330", "RP-46331", "RP-46332" },
  AREA_OF_OPS_NORTH = { "RP-8012", "RP-8013", "RP-8014", "RP-8015" },
  AREA_OF_OPS_CENTER = {
    "RP-156966", "RP-156967", "RP-156968",
    "RP-156969", "RP-156970", "RP-156971",
    "RP-156972", "RP-156973", "RP-156974"
  },
  AREA_OF_OPS_PACIFIC = { "RP-76319", "RP-42688", "RP-42687", "RP-76320" },
  AREA_OF_OPS_SOUTH = {
    "RP-156975", "RP-156976", "RP-156977",
    "RP-156978", "RP-156979", "RP-156980",
    "RP-156981", "RP-156982", "RP-156983",
    "RP-156984", "RP-156985", "RP-156986", "RP-156987"
  },
  AREA_OF_OPS_EAST = { "RP-156988", "RP-156989", "RP-156990", "RP-156991", "RP-156992", "RP-156993" },
  TARGET_AREA_SOUTH_PROSECUTION = { "rp-163362", "rp-163363", "rp-163364", "rp-163365", },
  TARGET_AREA_SOUTH_PATROL = { "rp-163366", "rp-163367", },
  TARGET_AREA_CENTER_PROSECUTION = { "rp-163338", "rp-163339", "rp-163340", "rp-163341", },
  TARGET_AREA_CENTER_PATROL = { "rp-163342", "rp-163343", },
  TARGET_AREA_NORTH_PROSECUTION = { "rp-163344", "rp-163345", "rp-163346", "rp-163347", },
  TARGET_AREA_NORTH_PATROL = { "rp-163348", "rp-163349", },
  TARGET_AREA_JHI_PROSECUTION = { "rp-163350", "rp-163351", "rp-163352", "rp-163353", },
  TARGET_AREA_JHI_PATROL = { "rp-163354", "rp-163355", },
  TARGET_AREA_JIASHAN_PROSECUTION = { "rp-163356", "rp-163357", "rp-163358", "rp-163359", },
  TARGET_AREA_JIASHAN_PATROL = { "rp-163360", "rp-163161", },
  AAR_PATROL = { "RP-44509", "RP-44510", "RP-44511", "RP-44512", },
  AAR_PATROL_2 = { "RP-181270", "RP-181271", "RP-181272", "RP-181273", },
}

constants.BASES = {
  -- China Bases (PLAAF / PLAN)
  HUIZHOU_PINGTAN_AB     = "6Z8LM5-0HMLLL9B5QBF0", -- Huizhou Pingtan AB (PLAAF)
  SHANTOU_WAISHA_AB      = "6Z8LM5-0HMLLEF9H5P44", -- Shantou Waisha AB (PLAAF)
  ZHANGPU_AAB            = "X58F5H-0HN00TRR0Q1JQ", -- Zhangpu AAB
  ZHANGZHOU_LONGXI_AB    = "6Z8LM5-0HMIJ3QGCRQ2G", -- Zhangzhou-Longxi AB (PLAAF)
  HUIAN_AAB              = "6Z8LM5-0HMIJ3QGCRQ5F", -- Huian AAB
  LONGTIAN_AAB           = "6Z8LM5-0HMIJ3QGCRQC4", -- Longtian AAB
  XINGNING_AB            = "6Z8LM5-0HMLLEF9H7VDF", -- Xingning AB (PLAAF)
  SHUIMEN_AAB            = "6Z8LM5-0HMMJDEFRFJ4V", -- Shuimen AAB (PLAAF)
  ANQING_AB              = "6Z8LM5-0HMIJ7B8971MA", -- Anqing AB (PLAAF)
  WUHU_AB                = "6Z8LM5-0HMIJ7B896RA9", -- Wuhu AB (PLAAF)
  LIUAN_AB               = "X58F5H-0HMRAQFR07T2V", -- Liuan AB
  PINGTAN_PORT           = "6Z8LM5-0HMMNGU6J8P2N", -- Pingtan Port (Amphibious Ops)
  KWANG_CHOW_WAN_NB      = "6Z8LM5-0HMJV6AONGLAU", -- Kwang Chow Wan Naval Base (PLAN) (Amphibious Ops)
  TAIZHOU_AB             = "IC8B0X-0HNFDVSDK067T", -- Taizhou AB
  WUYISHAN_AB            = "IC8B0X-0HNFDVSDK0AM9", -- Wuyishan AB
  RUGAO_AB               = "X58F5H-0HN201E9DHM1C", -- Rugao AB
  XIAHGTANG_AB           = "6Z8LM5-0HMIJ7B89707I", -- Xiahgtang AB (PLAAF)
  JIAXING_AB             = "6Z8LM5-0HMITKFQH25Q8", -- Jiaxing AB (PLAAF)
  -- Taiwan Bases
  CHING_CHUANG_KANG_AB   = "6Z8LM5-0HMIHS2L949R0", -- Ching Chuang Kang AB (Taiwan)
  CHIAYI_AB              = "6Z8LM5-0HMIJ3QGCHSUB", -- Chiayi AB (Taiwan)
  TAINAN_AB              = "6Z8LM5-0HMIJ3QGCHVVS", -- Tainan AB (Taiwan)
  MAGONG_AB              = "6Z8LM5-0HMISSTNL3T8K", -- Magong AB (Taiwan)
  GUIREN_AAB             = "IC8B0X-0HN37BVOG0T9O", -- Guiren AAB (Taiwan)
  PINGTUNG_NORTH_AB      = "IC8B0X-0HNCTPETEF6GG", -- Pingtung North AB (Taiwan)
  TAITUNG_JHIHHANG_AB    = "6Z8LM5-0HMIJ3QGCI3V3", -- Taitung/Jhihhang AB (Taiwan)
  JIASHAN_AB             = "IC8B0X-0HNCTPETEF5C1", -- Jiashan AB (Taiwan)
  HSINCHU_AB             = "6Z8LM5-0HMIK08HEK556", -- Hsinchu AB (Taiwan)
  LONGTAN_AAB            = "IC8B0X-0HN3ADVRF2U7P", -- Longtan AAB (Taiwan)
  TAOYUAN_AIRPORT        = "6Z8LM5-0HMJ1GE4HSIU5", -- Taoyuan International Airport (Taiwan)
  RENDE_STRIP            = "X58F5H-0HMU28MM77N82", -- Rende Emergency Highway Strip (Taiwan)
  MADOU_STRIP            = "X58F5H-0HMU28MM7836P", -- Madou Emergency Highway Strip (Taiwan)
  MINXIONG_STRIP         = "X58F5H-0HMU28MM78J9P", -- Minxiong Emergency Highway Strip (Taiwan)
  TAINAN_FIELD_AIRDROME  = "IC8B0X-0HN81FNLB6M8Q", -- Tainan Field Airdrome (Taiwan)
  HSINCHU_FIELD_AIRDROME = "IC8B0X-0HN81FNLB2OPJ", -- Hsinchu Field Airdrome (Taiwan)
  PORT_OF_KEELUNG        = "X58F5H-0HMSMDQJ7LEUI", -- Port of Keelung (Taiwan)
  PINGTUNG_SOUTH_AB      = "IC8B0X-0HNCTPETEF6F9", -- Pingtung South AB (Taiwan)
}

constants.PLATFORMS = {
  TB001 = 7062,
  WZ7 = 7371,
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

constants.SENSORS = {
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
  WZ8_RADAR = 4576,
}

constants.LOADOUTS = {
  TB001_RECON = 33455,
  WZ7_RECON = 25184,
  KA52_ATTACK = 30568,
  Z10_ATTACK = 31490,
  Z18_TRANSPORT_1 = 18367,
  Z18_TRANSPORT_2 = 18365,
  IL76_TRANSPORT = 25504,
  GJ11_RECON = 27825,
  J16_AKD88 = 26233,
  J16_YJ91 = 21748,
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
  J10C_CS_BBC_5 = 34241,
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
  WZ8_RECON = 32885,
}

constants.WEAPONS = {
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
  CS_BBC_5 = 4541,    -- CS-BBC-5 Glide Bomb (Submunitions)
  YJ91_ASM = 276,     -- YJ-91 Anti-Ship Missile
  YJ83 = 2137,        -- YJ-83 Anti-Ship Missile
  MK45_AMLRS = 2948,  -- MK45 AMLRS Multiple Launch Rocket System
  ATACMS = 1717,      -- ATACMS Tactical Missile System
  HF2E = 3228,        -- HF-2E Anti-Ship Cruise Missile
  HF3 = 1133,         -- HF-2 Anti-Ship Missile
  MK48_TORPEDO = 905, -- MK-48 Torpedo
  HARPOON_II = 816,   -- Harpoon II
  JSOW = 826,         -- JSOW
  WAN_CHIEN = 3026,   -- Wan Chien
  SLAMER = 452,       -- SLAMER
  JDAM = 554,         -- JDAM
  HPJ_38 = 2691,      -- H/PJ-38 130mm
}

constants.UNIT_TYPES = {
  AIRCRAFT = "1",
  SHIP = "2",
  SUBMARINE = "3",
  FACILITY = "4",
  AIMPOINT = "5",
  WEAPON = "6",
  SATELLITE = "7",
  GROUND_UNIT = "8"
}

constants.AIRCRAFT_CATEGORIES = {
  NONE = 1001,
  FIXED_WING = 2001,
  FIXED_WING_CARRIER_CAPABLE = 2002,
  HELICOPTER = 2003,
  TILTROTOR = 2004,
  AIRSHIP = 2006,
  SEAPLANE = 2007,
  AMPHIBIAN = 2008
}

constants.FIXED_FACILITY_CATEGORIES = {
  NONE = 1001,
  RUNWAY = 2001,
  RUNWAY_GRADE_TAXIWAY = 2002,
  RUNWAY_ACCESS_POINT = 2003,
  BUILDING_SURFACE = 3001,
  BUILDING_REVETED = 3002,
  BUILDING_BUNKER = 3003,
  BUILDING_UNDERGROUND = 3004,
  STRUCTURE_OPEN = 3005,
  STRUCTURE_REVETED = 3006,
  UNDERWATER = 4001,
  MOBILE_VEHICLE = 5001,
  MOBILE_PERSONNEL = 5002,
  AEROSTAT_MOORING = 6001,
  AIR_BASE = 9001
}

---@type table<string, SBJ__OperationalArea>
constants.OPERATIONAL_AREAS = {
  PINGTAN = {
    RL = { {
      course = {
        { latitude = "N 25.30.20", longitude = "E 119.46.50", desiredSpeed = 30, presetThrottle = "Flank" },
        { latitude = "N 25.30.13", longitude = "E 119.47.36", desiredSpeed = 30, presetThrottle = "Flank" },
      },
      area = constants.AREAS.RELOAD_POINT_PINGTAN
    } },
    HA = { {
      course = {
        { latitude = "N 25.30.02", longitude = "E 119.47.17", desiredSpeed = 30, presetThrottle = "Flank" },
      },
      area = constants.AREAS.HIDE_AREA_PINGTAN
    } },
    FP = {
      {
        course = {
          { latitude = "N 25.30.20", longitude = "E 119.46.50", desiredSpeed = 30, presetThrottle = "Flank" },
          { latitude = "N 25.25.45", longitude = "E 119.44.25", desiredSpeed = 30, presetThrottle = "Flank" },
        },
        area = constants.AREAS.FIRE_POINT_PINGTAN_1
      },
      {
        course = {
          { latitude = "N 25.30.20", longitude = "E 119.46.50", desiredSpeed = 30, presetThrottle = "Flank" },
          { latitude = "N 25.27.22", longitude = "E 119.45.39", desiredSpeed = 30, presetThrottle = "Flank" },
        },
        area = constants.AREAS.FIRE_POINT_PINGTAN_2
      },
    },
    AHA = { {
      course = {
        { latitude = "N 25.30.31", longitude = "E 119.47.37", desiredSpeed = 30, presetThrottle = "Flank" },
      },
      area = constants.AREAS.AMMO_HOLDING_AREA_PINGTAN
    } },
  },
  CHINCHEW = {
    RL = { {
      course = {
        { latitude = "N 24.46.44", longitude = "E 118.40.37", desiredSpeed = 30, presetThrottle = "Flank" },
        { latitude = "N 24.46.36", longitude = "E 118.42.17", desiredSpeed = 30, presetThrottle = "Flank" },
      },
      area = constants.AREAS.RELOAD_POINT_CHINCHEW
    } },
    HA = { {
      course = {
        { latitude = "N 24.46.31", longitude = "E 118.41.51", desiredSpeed = 30, presetThrottle = "Flank" },
      },
      area = constants.AREAS.HIDE_AREA_CHINCHEW
    } },
    FP = { {
      course = {
        { latitude = "N 24.46.44", longitude = "E 118.40.37", desiredSpeed = 30, presetThrottle = "Flank" },
        { latitude = "N 24.41.45", longitude = "E 118.43.18", desiredSpeed = 30, presetThrottle = "Flank" },
      },
      area = constants.AREAS.FIRE_POINT_CHINCHEW_1
    }, },
    AHA = { {
      course = {
        { latitude = "N 24.47.10", longitude = "E 118.42.22", desiredSpeed = 30, presetThrottle = "Flank" },
      },
      area = constants.AREAS.AMMO_HOLDING_AREA_CHINCHEW
    } },
  },
  BRIGADE_635 = {
    RL = { {
      course = {
        { latitude = "N 24.46.44", longitude = "E 118.40.37", desiredSpeed = 30, presetThrottle = "Flank" },
        { latitude = "N 24.46.36", longitude = "E 118.42.17", desiredSpeed = 30, presetThrottle = "Flank" },
      },
      area = constants.AREAS.RELOAD_POINT_CHINCHEW
    } },
    HA = { {
      course = {
        { latitude = "N 24.46.31", longitude = "E 118.41.51", desiredSpeed = 30, presetThrottle = "Flank" },
      },
      area = constants.AREAS.HIDE_AREA_CHINCHEW
    } },
    FP = { {
      course = {
        { latitude = "N 24.46.44", longitude = "E 118.40.37", desiredSpeed = 30, presetThrottle = "Flank" },
        { latitude = "N 24.41.45", longitude = "E 118.43.18", desiredSpeed = 30, presetThrottle = "Flank" },
      },
      area = constants.AREAS.FIRE_POINT_CHINCHEW_1
    }, },
    AHA = { {
      course = {
        { latitude = "N 24.47.10", longitude = "E 118.42.22", desiredSpeed = 30, presetThrottle = "Flank" },
      },
      area = constants.AREAS.AMMO_HOLDING_AREA_CHINCHEW
    } },
  },
  BRIGADE_615 = {
    RL = { {
      course = {
        { latitude = "N 24.17.32", longitude = "E 115.58.09", desiredSpeed = 30, presetThrottle = "Flank" },
        { latitude = "N 24.16.56", longitude = "E 115.58.12", desiredSpeed = 30, presetThrottle = "Flank" },
      },
      area = constants.AREAS.RELOAD_POINT_BRIGADE615
    } },
    HA = { {
      course = {
        { latitude = "N 24.17.06", longitude = "E 115.58.35", desiredSpeed = 30, presetThrottle = "Flank" },
      },
      area = constants.AREAS.HIDE_AREA_BRIGADE615
    } },
    FP = { {
      course = {
        { latitude = "N 24.17.32", longitude = "E 115.58.09", desiredSpeed = 30, presetThrottle = "Flank" },
        { latitude = "N 24.17.05", longitude = "E 115.59.41", desiredSpeed = 30, presetThrottle = "Flank" },
      },
      area = constants.AREAS.FIRE_POINT_BRIGADE615_1
    }, },
    AHA = { {
      course = {
        { latitude = "N 24.17.05", longitude = "E 115.58.00", desiredSpeed = 30, presetThrottle = "Flank" },
      },
      area = constants.AREAS.AMMO_HOLDING_AREA_BRIGADE615
    } },
  },
  BRIGADE_614 = {
    RL = { {
      course = {
        { latitude = "N 26.04.01", longitude = "E 117.18.55", desiredSpeed = 30, presetThrottle = "Flank" },
        { latitude = "N 26.03.40", longitude = "E 117.18.55", desiredSpeed = 30, presetThrottle = "Flank" },
      },
      area = constants.AREAS.RELOAD_POINT_BRIGADE614
    } },
    HA = { {
      course = {
        { latitude = "N 26.03.48", longitude = "E 117.19.11", desiredSpeed = 30, presetThrottle = "Flank" },
      },
      area = constants.AREAS.HIDE_AREA_BRIGADE614
    } },
    FP = { {
      course = {
        { latitude = "N 26.04.18", longitude = "E 117.18.51", desiredSpeed = 30, presetThrottle = "Flank" },
        { latitude = "N 26.03.49", longitude = "E 117.20.05", desiredSpeed = 30, presetThrottle = "Flank" },
      },
      area = constants.AREAS.FIRE_POINT_BRIGADE614_1
    }, },
    AHA = { {
      course = {
        { latitude = "N 26.03.47", longitude = "E 117.18.50", desiredSpeed = 30, presetThrottle = "Flank" },
      },
      area = constants.AREAS.AMMO_HOLDING_AREA_BRIGADE614
    } },
  },
  BRIGADE_636 = {
    RL = { {
      course = {
        { latitude = "N 24.45.52", longitude = "E 113.40.52", desiredSpeed = 30, presetThrottle = "Flank" },
        { latitude = "N 24.45.25", longitude = "E 113.40.29", desiredSpeed = 30, presetThrottle = "Flank" },
      },
      area = constants.AREAS.RELOAD_POINT_BRIGADE636
    } },
    HA = { {
      course = {
        { latitude = "N 24.45.33", longitude = "E 113.40.47", desiredSpeed = 30, presetThrottle = "Flank" },
      },
      area = constants.AREAS.HIDE_AREA_BRIGADE636
    } },
    FP = { {
      course = {
        { latitude = "N 24.45.52", longitude = "E 113.40.52", desiredSpeed = 30, presetThrottle = "Flank" },
        { latitude = "N 24.45.52", longitude = "E 113.41.35", desiredSpeed = 30, presetThrottle = "Flank" },
      },
      area = constants.AREAS.FIRE_POINT_BRIGADE636_1
    }, },
    AHA = { {
      course = {
        { latitude = "N 24.45.34", longitude = "E 113.40.14", desiredSpeed = 30, presetThrottle = "Flank" },
      },
      area = constants.AREAS.AMMO_HOLDING_AREA_BRIGADE636
    } },
  },
  BRIGADE_616 = {
    RL = { {
      course = {
        { latitude = "N 25.54.31", longitude = "E 114.57.21", desiredSpeed = 30, presetThrottle = "Flank" },
      },
      area = constants.AREAS.RELOAD_POINT_BRIGADE616
    } },
    HA = { {
      course = {
        { latitude = "N 25.54.40", longitude = "E 114.57.42", desiredSpeed = 30, presetThrottle = "Flank" },
      },
      area = constants.AREAS.HIDE_AREA_BRIGADE616
    } },
    FP = { {
      course = {
        { latitude = "N 25.55.33", longitude = "E 114.58.25", desiredSpeed = 30, presetThrottle = "Flank" },
      },
      area = constants.AREAS.FIRE_POINT_BRIGADE616_1
    }, },
    AHA = { {
      course = {
        { latitude = "N 25.54.38", longitude = "E 114.57.06", desiredSpeed = 30, presetThrottle = "Flank" },
      },
      area = constants.AREAS.AMMO_HOLDING_AREA_BRIGADE616
    } },
  },
  BRIGADE_613 = {
    RL = { {
      course = {
        { latitude = "N 28.27.25", longitude = "E 117.51.51", desiredSpeed = 30, presetThrottle = "Flank" },
        { latitude = "N 28.27.26", longitude = "E 117.51.02", desiredSpeed = 30, presetThrottle = "Flank" },
        { latitude = "N 28.27.03", longitude = "E 117.51.04", desiredSpeed = 30, presetThrottle = "Flank" },
      },
      area = constants.AREAS.RELOAD_POINT_BRIGADE613
    } },
    HA = { {
      course = {
        { latitude = "N 28.27.12", longitude = "E 117.51.17", desiredSpeed = 30, presetThrottle = "Flank" },
      },
      area = constants.AREAS.HIDE_AREA_BRIGADE613
    } },
    FP = { {
      course = {
        { latitude = 28.455760146701, longitude = 117.85790803852, desiredSpeed = 30, presetThrottle = "Flank" },
        { latitude = 28.455941652975, longitude = 117.86516402324, desiredSpeed = 30, presetThrottle = "Flank" },
        { latitude = 28.443410902986, longitude = 117.86719441616, desiredSpeed = 30, presetThrottle = "Flank" },
      },
      area = constants.AREAS.FIRE_POINT_BRIGADE613_1
    }, },
    AHA = { {
      course = {
        { latitude = "N 28.27.12", longitude = "E 117.50.55", desiredSpeed = 30, presetThrottle = "Flank" },
      },
      area = constants.AREAS.AMMO_HOLDING_AREA_BRIGADE613
    } },
  },
  BRIGADE_617 = {
    RL = { {
      course = {
        { latitude = "N 29.09.32", longitude = "E 119.36.38", desiredSpeed = 30, presetThrottle = "Flank" },
        { latitude = "N 29.08.57", longitude = "E 119.36.31", desiredSpeed = 30, presetThrottle = "Flank" },
      },
      area = constants.AREAS.RELOAD_POINT_BRIGADE617
    } },
    HA = { {
      course = {
        { latitude = "N 29.09.01", longitude = "E 119.36.49", desiredSpeed = 30, presetThrottle = "Flank" },
      },
      area = constants.AREAS.HIDE_AREA_BRIGADE617
    } },
    FP = { {
      course = {
        { latitude = 29.158533243915, longitude = 119.61541712539, desiredSpeed = 30, presetThrottle = "Flank" },
        { latitude = 29.158295428459, longitude = 119.62849131226, desiredSpeed = 30, presetThrottle = "Flank" },
      },
      area = constants.AREAS.FIRE_POINT_BRIGADE617_1
    }, },
    AHA = { {
      course = {
        { latitude = "N 29.09.03", longitude = "E 119.36.26", desiredSpeed = 30, presetThrottle = "Flank" },
      },
      area = constants.AREAS.AMMO_HOLDING_AREA_BRIGADE617
    } },
  },
  BRIGADE_624 = {
    RL = { {
      course = {
        { latitude = "N 19.29.01", longitude = "E 109.26.40", desiredSpeed = 30, presetThrottle = "Flank" },
        { latitude = "N 19.28.27", longitude = "E 109.26.56", desiredSpeed = 30, presetThrottle = "Flank" },
        { latitude = "N 19.28.29", longitude = "E 109.27.44", desiredSpeed = 30, presetThrottle = "Flank" },
      },
      area = constants.AREAS.RELOAD_POINT_BRIGADE624
    } },
    HA = { {
      course = {
        { latitude = "N 19.28.35", longitude = "E 109.27.22", desiredSpeed = 30, presetThrottle = "Flank" },
      },
      area = constants.AREAS.HIDE_AREA_BRIGADE624
    } },
    FP = { {
      course = {
        { latitude = "N 19.29.01", longitude = "E 109.26.40", desiredSpeed = 30, presetThrottle = "Flank" },
        { latitude = "N 19.29.40", longitude = "E 109.27.17", desiredSpeed = 30, presetThrottle = "Flank" },
      },
      area = constants.AREAS.FIRE_POINT_BRIGADE624_1
    }, },
    AHA = { {
      course = {
        { latitude = "N 19.28.12", longitude = "E 109.27.21", desiredSpeed = 30, presetThrottle = "Flank" },
      },
      area = constants.AREAS.AMMO_HOLDING_AREA_BRIGADE624
    } },
  },
  PINGZHEN = {
    RL = { {
      course = {
        { latitude = "N 24.55.15", longitude = "E 121.16.02", desiredSpeed = 10, presetThrottle = "Flank" },
        { latitude = "N 24.57.13", longitude = "E 121.13.45", desiredSpeed = 10, presetThrottle = "Flank" },
      },
      area = constants.AREAS.RELOAD_POINT_PINGZHEN
    } },
    FP = { {
      course = {
        { latitude = "N 24.55.15", longitude = "E 121.16.02", desiredSpeed = 10, presetThrottle = "Flank" },
        { latitude = "N 24.53.01", longitude = "E 121.14.17", desiredSpeed = 10, presetThrottle = "Flank" },
      },
      area = constants.AREAS.FIRE_POINT_PINGZHEN_1
    }, },
    AHA = { {
      course = {
        { latitude = "N 24.55.15", longitude = "E 121.16.02", desiredSpeed = 10, presetThrottle = "Flank" },
      },
      area = constants.AREAS.AMMO_HOLDING_AREA_PINGZHEN
    } },
  },
  DADU = {
    RL = { {
      course = {
        { latitude = "N 24.09.07", longitude = "E 120.36.27", desiredSpeed = 10, presetThrottle = "Flank" },
        { latitude = "N 24.09.09", longitude = "E 120.35.47", desiredSpeed = 10, presetThrottle = "Flank" },
      },
      area = constants.AREAS.RELOAD_POINT_DADU
    } },
    FP = { {
      course = {
        { latitude = "N 24.09.07", longitude = "E 120.36.27", desiredSpeed = 10, presetThrottle = "Flank" },
        { latitude = "N 24.11.43", longitude = "E 120.38.29", desiredSpeed = 10, presetThrottle = "Flank" },
      },
      area = constants.AREAS.FIRE_POINT_DADU_1
    }, },
    AHA = { {
      course = {
        { latitude = "N 24.09.07", longitude = "E 120.36.27", desiredSpeed = 10, presetThrottle = "Flank" },
      },
      area = constants.AREAS.AMMO_HOLDING_AREA_DADU
    } },
  },
  QUANXI = {
    RL = { {
      course = {},
      area = constants.AREAS.RELOAD_POINT_QUANXI
    } },
    FP = { {
      course = {},
      area = constants.AREAS.FIRE_POINT_PINGZHEN_1
    }, },
    AHA = { {
      course = {},
      area = constants.AREAS.AMMO_HOLDING_AREA_QUANXI
    } },
  },
  NEIPU = {
    RL = { {
      course = {},
      area = constants.AREAS.RELOAD_POINT_NEIPU
    } },
    FP = { {
      course = {},
      area = constants.AREAS.FIRE_POINT_NEIPU_1
    }, },
    AHA = { {
      course = {},
      area = constants.AREAS.AMMO_HOLDING_AREA_NEIPU
    } },
  },
  LUZHU = {
    RL = { {
      course = {},
      area = constants.AREAS.RELOAD_POINT_LUZHU
    } },
    FP = { {
      course = {},
      area = constants.AREAS.FIRE_POINT_LUZHU_1
    }, },
    AHA = { {
      course = {},
      area = constants.AREAS.AMMO_HOLDING_AREA_LUZHU
    } },
  },
  DONG = {
    RL = { {
      course = {},
      area = constants.AREAS.RELOAD_POINT_DONG
    } },
    FP = { {
      course = {},
      area = constants.AREAS.FIRE_POINT_DONG_1
    }, },
    AHA = { {
      course = {},
      area = constants.AREAS.AMMO_HOLDING_AREA_DONG
    } },
  },
}

constants.COURSES = {
  WZ8 = {
    { latitude = "N 24.59.45", longitude = "E 121.59.21", desiredAltitude = 30480, desiredSpeed = 3300 },
    { latitude = "N 24.01.38", longitude = "E 121.37.51", desiredAltitude = 30480, desiredSpeed = 3300 },
    { latitude = "N 21.55.32", longitude = "E 120.51.30", desiredAltitude = 30480, desiredSpeed = 3300 },
    { latitude = "N 22.41.05", longitude = "E 120.27.58", desiredAltitude = 30480, desiredSpeed = 3300 },
    { latitude = "N 22.57.13", longitude = "E 120.12.37", desiredAltitude = 30480, desiredSpeed = 3300 },
    { latitude = "N 23.28.13", longitude = "E 120.22.57", desiredAltitude = 30480, desiredSpeed = 3300 },
    { latitude = "N 24.15.54", longitude = "E 120.38.12", desiredAltitude = 30480, desiredSpeed = 3300 },
    { latitude = "N 25.14.02", longitude = "E 121.21.47", desiredAltitude = 30480, desiredSpeed = 3300 },
  },
  H6N = {
    { latitude = "31.4291627579406", longitude = "116.708479118499", desiredAltitude = 13716, desiredSpeed = 450 },
    { latitude = "N 29.47.52",       longitude = "E 119.19.47",      desiredAltitude = 13716, desiredSpeed = 450 },
    { latitude = "N 25.57.34",       longitude = "E 121.32.45",      desiredAltitude = 13716, desiredSpeed = 550 },
  },
  BZK005_1 = {
    { longitude = 119.651011005704, latitude = 25.6118001826929, desiredSpeed = 115 },
    { longitude = 121.238926932242, latitude = 25.459719525138,  desiredSpeed = 115 },
    { longitude = 120.926681879442, latitude = 25.2124494777565, desiredSpeed = 115 },
    { longitude = 120.929674562224, latitude = 24.991467160603,  desiredSpeed = 115 },
    { longitude = 120.479387627427, latitude = 24.2630653534717, desiredSpeed = 115 },
  },
  BZK005_2 = {
    { longitude = 118.031467210727, latitude = 23.9011198341539, desiredSpeed = 115 },
    { longitude = 120.074966412556, latitude = 23.5745839530736, desiredSpeed = 115 },
    { longitude = 119.894517624583, latitude = 23.1838444302557, desiredSpeed = 115 },
    { longitude = 119.884596562779, latitude = 22.8618144043299, desiredSpeed = 115 },
    { longitude = 120.200631279976, latitude = 22.571862857163,  desiredSpeed = 115 },
    { longitude = 120.536274602033, latitude = 22.1911994531482, desiredSpeed = 115 },
  },
  GJ11 = {
    { longitude = 120.954426817633, latitude = 25.4296233744497, desiredSpeed = 450, desiredAltitude = 100 },
    { longitude = 121.087994141654, latitude = 25.0506579616447, desiredSpeed = 450, desiredAltitude = 100 },
    { longitude = 121.249386737925, latitude = 25.1186720471747, desiredSpeed = 450, desiredAltitude = 100 },
  }
}

constants.WCS = {
  FREE = 0,
  TIGHT = 1,
  HOLD = 2,
}

return constants
