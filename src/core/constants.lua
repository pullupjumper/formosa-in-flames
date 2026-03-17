local constants = {}

constants.AREAS = {
  RELOAD_POINT_ANC = { "RP-192255", "RP-192256", "RP-192257", "RP-192258" },
  HIDE_AREA_ANC = { "RP-192267", "RP-192268", "RP-192269", "RP-192270" },
  FIRE_POINT_ANC_1 = { "RP-192259", "RP-192260", "RP-192261", "RP-192262" },
  FIRE_POINT_ANC_2 = { "RP-192263", "RP-192264", "RP-192265", "RP-192266" },
  AMMO_HOLDING_AREA_ANC = { "RP-192271", "RP-192272", "RP-192273", "RP-192274" },
  MASK_ANC = { "RP-192278", "RP-192279", "RP-192280", "RP-192281" },
  RELOAD_POINT_CFO = { "RP-192395", "RP-192396", "RP-192397", "RP-192398" },
  HIDE_AREA_CFO = { "RP-192407", "RP-192408", "RP-192409", "RP-192410" },
  FIRE_POINT_CFO_1 = { "RP-192399", "RP-192400", "RP-192401", "RP-192402" },
  FIRE_POINT_CFO_2 = { "RP-192403", "RP-192404", "RP-192405", "RP-192406" },
  AMMO_HOLDING_AREA_CFO = { "RP-192411", "RP-192412", "RP-192413", "RP-192414" },
  MASK_CFO = { "RP-192418", "RP-192419", "RP-192420", "RP-192421" },
  RELOAD_POINT_CZT = { "RP-192591", "RP-192592", "RP-192593", "RP-192594" },
  HIDE_AREA_CZT = { "RP-192603", "RP-192604", "RP-192605", "RP-192606" },
  FIRE_POINT_CZT_1 = { "RP-192595", "RP-192596", "RP-192597", "RP-192598" },
  FIRE_POINT_CZT_2 = { "RP-192599", "RP-192600", "RP-192601", "RP-192602" },
  AMMO_HOLDING_AREA_CZT = { "RP-192607", "RP-192608", "RP-192609", "RP-192610" },
  MASK_CZT = { "RP-192614", "RP-192615", "RP-192616", "RP-192617" },
  RELOAD_POINT_DAW = { "RP-192563", "RP-192564", "RP-192565", "RP-192566" },
  HIDE_AREA_DAW = { "RP-192575", "RP-192576", "RP-192577", "RP-192578" },
  FIRE_POINT_DAW_1 = { "RP-192567", "RP-192568", "RP-192569", "RP-192570" },
  FIRE_POINT_DAW_2 = { "RP-192571", "RP-192572", "RP-192573", "RP-192574" },
  AMMO_HOLDING_AREA_DAW = { "RP-192579", "RP-192580", "RP-192581", "RP-192582" },
  MASK_DAW = { "RP-192586", "RP-192587", "RP-192588", "RP-192589" },
  RELOAD_POINT_DXN = { "RP-192423", "RP-192424", "RP-192425", "RP-192426" },
  HIDE_AREA_DXN = { "RP-192435", "RP-192436", "RP-192437", "RP-192438" },
  FIRE_POINT_DXN_1 = { "RP-192427", "RP-192428", "RP-192429", "RP-192430" },
  FIRE_POINT_DXN_2 = { "RP-192431", "RP-192432", "RP-192433", "RP-192434" },
  AMMO_HOLDING_AREA_DXN = { "RP-192439", "RP-192440", "RP-192441", "RP-192442" },
  MASK_DXN = { "RP-192446", "RP-192447", "RP-192448", "RP-192449" },
  RELOAD_POINT_EAA = { "RP-192731", "RP-192732", "RP-192733", "RP-192734" },
  HIDE_AREA_EAA = { "RP-192743", "RP-192744", "RP-192745", "RP-192746" },
  FIRE_POINT_EAA_1 = { "RP-192735", "RP-192736", "RP-192737", "RP-192738" },
  FIRE_POINT_EAA_2 = { "RP-192739", "RP-192740", "RP-192741", "RP-192742" },
  AMMO_HOLDING_AREA_EAA = { "RP-192747", "RP-192748", "RP-192749", "RP-192750" },
  MASK_EAA = { "RP-192754", "RP-192755", "RP-192756", "RP-192757" },
  RELOAD_POINT_FAH = { "RP-192227", "RP-192228", "RP-192229", "RP-192230" },
  HIDE_AREA_FAH = { "RP-192239", "RP-192240", "RP-192241", "RP-192242" },
  FIRE_POINT_FAH_1 = { "RP-192231", "RP-192232", "RP-192233", "RP-192234" },
  FIRE_POINT_FAH_2 = { "RP-192235", "RP-192236", "RP-192237", "RP-192238" },
  AMMO_HOLDING_AREA_FAH = { "RP-192243", "RP-192244", "RP-192245", "RP-192246" },
  MASK_FAH = { "RP-192250", "RP-192251", "RP-192252", "RP-192253" },
  RELOAD_POINT_FOW = { "RP-192507", "RP-192508", "RP-192509", "RP-192510" },
  HIDE_AREA_FOW = { "RP-192519", "RP-192520", "RP-192521", "RP-192522" },
  FIRE_POINT_FOW_1 = { "RP-192511", "RP-192512", "RP-192513", "RP-192514" },
  FIRE_POINT_FOW_2 = { "RP-192515", "RP-192516", "RP-192517", "RP-192518" },
  AMMO_HOLDING_AREA_FOW = { "RP-192523", "RP-192524", "RP-192525", "RP-192526" },
  MASK_FOW = { "RP-192530", "RP-192531", "RP-192532", "RP-192533" },
  RELOAD_POINT_GDN = { "RP-192787", "RP-192788", "RP-192789", "RP-192790" },
  HIDE_AREA_GDN = { "RP-192799", "RP-192800", "RP-192801", "RP-192802" },
  FIRE_POINT_GDN_1 = { "RP-192791", "RP-192792", "RP-192793", "RP-192794" },
  FIRE_POINT_GDN_2 = { "RP-192795", "RP-192796", "RP-192797", "RP-192798" },
  AMMO_HOLDING_AREA_GDN = { "RP-192803", "RP-192804", "RP-192805", "RP-192806" },
  MASK_GDN = { "RP-192810", "RP-192811", "RP-192812", "RP-192813" },
  RELOAD_POINT_GVG = { "RP-192815", "RP-192816", "RP-192817", "RP-192818" },
  HIDE_AREA_GVG = { "RP-192827", "RP-192828", "RP-192829", "RP-192830" },
  FIRE_POINT_GVG_1 = { "RP-192819", "RP-192820", "RP-192821", "RP-192822" },
  FIRE_POINT_GVG_2 = { "RP-192823", "RP-192824", "RP-192825", "RP-192826" },
  AMMO_HOLDING_AREA_GVG = { "RP-192831", "RP-192832", "RP-192833", "RP-192834" },
  MASK_GVG = { "RP-192838", "RP-192839", "RP-192840", "RP-192841" },
  RELOAD_POINT_IXZ = { "RP-192311", "RP-192312", "RP-192313", "RP-192314" },
  HIDE_AREA_IXZ = { "RP-192323", "RP-192324", "RP-192325", "RP-192326" },
  FIRE_POINT_IXZ_1 = { "RP-192315", "RP-192316", "RP-192317", "RP-192318" },
  FIRE_POINT_IXZ_2 = { "RP-192319", "RP-192320", "RP-192321", "RP-192322" },
  AMMO_HOLDING_AREA_IXZ = { "RP-192327", "RP-192328", "RP-192329", "RP-192330" },
  MASK_IXZ = { "RP-192334", "RP-192335", "RP-192336", "RP-192337" },
  RELOAD_POINT_JBT = { "RP-192171", "RP-192172", "RP-192173", "RP-192174" },
  HIDE_AREA_JBT = { "RP-192183", "RP-192184", "RP-192185", "RP-192186" },
  FIRE_POINT_JBT_1 = { "RP-192175", "RP-192176", "RP-192177", "RP-192178" },
  FIRE_POINT_JBT_2 = { "RP-192179", "RP-192180", "RP-192181", "RP-192182" },
  AMMO_HOLDING_AREA_JBT = { "RP-192187", "RP-192188", "RP-192189", "RP-192190" },
  MASK_JBT = { "RP-192194", "RP-192195", "RP-192196", "RP-192197" },
  RELOAD_POINT_NGP = { "RP-192199", "RP-192200", "RP-192201", "RP-192202" },
  HIDE_AREA_NGP = { "RP-192211", "RP-192212", "RP-192213", "RP-192214" },
  FIRE_POINT_NGP_1 = { "RP-192203", "RP-192204", "RP-192205", "RP-192206" },
  FIRE_POINT_NGP_2 = { "RP-192207", "RP-192208", "RP-192209", "RP-192210" },
  AMMO_HOLDING_AREA_NGP = { "RP-192215", "RP-192216", "RP-192217", "RP-192218" },
  MASK_NGP = { "RP-192222", "RP-192223", "RP-192224", "RP-192225" },
  RELOAD_POINT_NYD = { "RP-192367", "RP-192368", "RP-192369", "RP-192370" },
  HIDE_AREA_NYD = { "RP-192379", "RP-192380", "RP-192381", "RP-192382" },
  FIRE_POINT_NYD_1 = { "RP-192371", "RP-192372", "RP-192373", "RP-192374" },
  FIRE_POINT_NYD_2 = { "RP-192375", "RP-192376", "RP-192377", "RP-192378" },
  AMMO_HOLDING_AREA_NYD = { "RP-192383", "RP-192384", "RP-192385", "RP-192386" },
  MASK_NYD = { "RP-192390", "RP-192391", "RP-192392", "RP-192393" },
  RELOAD_POINT_ONY = { "RP-192759", "RP-192760", "RP-192761", "RP-192762" },
  HIDE_AREA_ONY = { "RP-192771", "RP-192772", "RP-192773", "RP-192774" },
  FIRE_POINT_ONY_1 = { "RP-192763", "RP-192764", "RP-192765", "RP-192766" },
  FIRE_POINT_ONY_2 = { "RP-192767", "RP-192768", "RP-192769", "RP-192770" },
  AMMO_HOLDING_AREA_ONY = { "RP-192775", "RP-192776", "RP-192777", "RP-192778" },
  MASK_ONY = { "RP-192782", "RP-192783", "RP-192784", "RP-192785" },
  RELOAD_POINT_PCQ = { "RP-192535", "RP-192536", "RP-192537", "RP-192538" },
  HIDE_AREA_PCQ = { "RP-192547", "RP-192548", "RP-192549", "RP-192550" },
  FIRE_POINT_PCQ_1 = { "RP-192539", "RP-192540", "RP-192541", "RP-192542" },
  FIRE_POINT_PCQ_2 = { "RP-192543", "RP-192544", "RP-192545", "RP-192546" },
  AMMO_HOLDING_AREA_PCQ = { "RP-192551", "RP-192552", "RP-192553", "RP-192554" },
  MASK_PCQ = { "RP-192558", "RP-192559", "RP-192560", "RP-192561" },
  RELOAD_POINT_SPK = { "RP-192843", "RP-192844", "RP-192845", "RP-192846" },
  HIDE_AREA_SPK = { "RP-192855", "RP-192856", "RP-192857", "RP-192858" },
  FIRE_POINT_SPK_1 = { "RP-192847", "RP-192848", "RP-192849", "RP-192850" },
  FIRE_POINT_SPK_2 = { "RP-192851", "RP-192852", "RP-192853", "RP-192854" },
  AMMO_HOLDING_AREA_SPK = { "RP-192859", "RP-192860", "RP-192861", "RP-192862" },
  MASK_SPK = { "RP-192866", "RP-192867", "RP-192868", "RP-192869" },
  RELOAD_POINT_TLM = { "RP-192339", "RP-192340", "RP-192341", "RP-192342" },
  HIDE_AREA_TLM = { "RP-192351", "RP-192352", "RP-192353", "RP-192354" },
  FIRE_POINT_TLM_1 = { "RP-192343", "RP-192344", "RP-192345", "RP-192346" },
  FIRE_POINT_TLM_2 = { "RP-192347", "RP-192348", "RP-192349", "RP-192350" },
  AMMO_HOLDING_AREA_TLM = { "RP-192355", "RP-192356", "RP-192357", "RP-192358" },
  MASK_TLM = { "RP-192362", "RP-192363", "RP-192364", "RP-192365" },
  RELOAD_POINT_TQG = { "RP-192479", "RP-192480", "RP-192481", "RP-192482" },
  HIDE_AREA_TQG = { "RP-192491", "RP-192492", "RP-192493", "RP-192494" },
  FIRE_POINT_TQG_1 = { "RP-192483", "RP-192484", "RP-192485", "RP-192486" },
  FIRE_POINT_TQG_2 = { "RP-192487", "RP-192488", "RP-192489", "RP-192490" },
  AMMO_HOLDING_AREA_TQG = { "RP-192495", "RP-192496", "RP-192497", "RP-192498" },
  MASK_TQG = { "RP-192502", "RP-192503", "RP-192504", "RP-192505" },
  RELOAD_POINT_UHE = { "RP-192283", "RP-192284", "RP-192285", "RP-192286" },
  HIDE_AREA_UHE = { "RP-192295", "RP-192296", "RP-192297", "RP-192298" },
  FIRE_POINT_UHE_1 = { "RP-192287", "RP-192288", "RP-192289", "RP-192290" },
  FIRE_POINT_UHE_2 = { "RP-192291", "RP-192292", "RP-192293", "RP-192294" },
  AMMO_HOLDING_AREA_UHE = { "RP-192299", "RP-192300", "RP-192301", "RP-192302" },
  MASK_UHE = { "RP-192306", "RP-192307", "RP-192308", "RP-192309" },
  RELOAD_POINT_UMA = { "RP-192647", "RP-192648", "RP-192649", "RP-192650" },
  HIDE_AREA_UMA = { "RP-192659", "RP-192660", "RP-192661", "RP-192662" },
  FIRE_POINT_UMA_1 = { "RP-192651", "RP-192652", "RP-192653", "RP-192654" },
  FIRE_POINT_UMA_2 = { "RP-192655", "RP-192656", "RP-192657", "RP-192658" },
  AMMO_HOLDING_AREA_UMA = { "RP-192663", "RP-192664", "RP-192665", "RP-192666" },
  MASK_UMA = { "RP-192670", "RP-192671", "RP-192672", "RP-192673" },
  RELOAD_POINT_VAJ = { "RP-192619", "RP-192620", "RP-192621", "RP-192622" },
  HIDE_AREA_VAJ = { "RP-192631", "RP-192632", "RP-192633", "RP-192634" },
  FIRE_POINT_VAJ_1 = { "RP-192623", "RP-192624", "RP-192625", "RP-192626" },
  FIRE_POINT_VAJ_2 = { "RP-192627", "RP-192628", "RP-192629", "RP-192630" },
  AMMO_HOLDING_AREA_VAJ = { "RP-192635", "RP-192636", "RP-192637", "RP-192638" },
  MASK_VAJ = { "RP-192642", "RP-192643", "RP-192644", "RP-192645" },
  RELOAD_POINT_XTV = { "RP-192703", "RP-192704", "RP-192705", "RP-192706" },
  HIDE_AREA_XTV = { "RP-192715", "RP-192716", "RP-192717", "RP-192718" },
  FIRE_POINT_XTV_1 = { "RP-192707", "RP-192708", "RP-192709", "RP-192710" },
  FIRE_POINT_XTV_2 = { "RP-192711", "RP-192712", "RP-192713", "RP-192714" },
  AMMO_HOLDING_AREA_XTV = { "RP-192719", "RP-192720", "RP-192721", "RP-192722" },
  MASK_XTV = { "RP-192726", "RP-192727", "RP-192728", "RP-192729" },
  RELOAD_POINT_YUR = { "RP-192451", "RP-192452", "RP-192453", "RP-192454" },
  HIDE_AREA_YUR = { "RP-192463", "RP-192464", "RP-192465", "RP-192466" },
  FIRE_POINT_YUR_1 = { "RP-192455", "RP-192456", "RP-192457", "RP-192458" },
  FIRE_POINT_YUR_2 = { "RP-192459", "RP-192460", "RP-192461", "RP-192462" },
  AMMO_HOLDING_AREA_YUR = { "RP-192467", "RP-192468", "RP-192469", "RP-192470" },
  MASK_YUR = { "RP-192474", "RP-192475", "RP-192476", "RP-192477" },
  RELOAD_POINT_ZJL = { "RP-192675", "RP-192676", "RP-192677", "RP-192678" },
  HIDE_AREA_ZJL = { "RP-192687", "RP-192688", "RP-192689", "RP-192690" },
  FIRE_POINT_ZJL_1 = { "RP-192679", "RP-192680", "RP-192681", "RP-192682" },
  FIRE_POINT_ZJL_2 = { "RP-192683", "RP-192684", "RP-192685", "RP-192686" },
  AMMO_HOLDING_AREA_ZJL = { "RP-192691", "RP-192692", "RP-192693", "RP-192694" },
  MASK_ZJL = { "RP-192698", "RP-192699", "RP-192700", "RP-192701" },
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
  MASK_PINGTAN = { "RP-44256", "RP-44257", "RP-44258", "RP-44259" },
  RELOAD_POINT_CHINCHEW = { "RP-114455", "RP-114456", "RP-114457", "RP-114458" },
  HIDE_AREA_CHINCHEW = { "RP-114451", "RP-114452", "RP-114453", "RP-114454" },
  FIRE_POINT_CHINCHEW_1 = { "RP-46390", "RP-46391", "RP-46392", "RP-46393" },
  AMMO_HOLDING_AREA_CHINCHEW = { "RP-114459", "RP-114460", "RP-114461", "RP-114462" },
  MASK_CHINCHEW = { "RP-46386", "RP-46387", "RP-46388", "RP-46389" },
  RELOAD_POINT_BRIGADE615 = { "RP-114467", "RP-114468", "RP-114469", "RP-114470" },
  HIDE_AREA_BRIGADE615 = { "RP-114463", "RP-114464", "RP-114465", "RP-114466" },
  FIRE_POINT_BRIGADE615_1 = { "RP-44322", "RP-44323", "RP-44324", "RP-44325" },
  AMMO_HOLDING_AREA_BRIGADE615 = { "RP-114471", "RP-114472", "RP-114473", "RP-114474" },
  MASK_BRIGADE615 = { "RP-44316", "RP-44317", "RP-44318", "RP-44319" },
  RELOAD_POINT_BRIGADE614 = { "RP-114479", "RP-114480", "RP-114481", "RP-114482" },
  HIDE_AREA_BRIGADE614 = { "RP-114475", "RP-114476", "RP-114477", "RP-114478" },
  FIRE_POINT_BRIGADE614_1 = { "RP-44335", "RP-44336", "RP-44337", "RP-44338" },
  AMMO_HOLDING_AREA_BRIGADE614 = { "RP-114483", "RP-114484", "RP-114485", "RP-114486" },
  MASK_BRIGADE614 = { "RP-44330", "RP-44331", "RP-44332", "RP-44333" },
  RELOAD_POINT_BRIGADE636 = { "RP-114491", "RP-114492", "RP-114493", "RP-114494" },
  HIDE_AREA_BRIGADE636 = { "RP-114487", "RP-114488", "RP-114489", "RP-114490" },
  FIRE_POINT_BRIGADE636_1 = { "RP-44357", "RP-44358", "RP-44359", "RP-44360" },
  AMMO_HOLDING_AREA_BRIGADE636 = { "RP-114495", "RP-114496", "RP-114497", "RP-114498" },
  MASK_BRIGADE636 = { "RP-44342", "RP-44343", "RP-44344", "RP-44345" },
  RELOAD_POINT_BRIGADE616 = { "RP-114503", "RP-114504", "RP-114505", "RP-114506" },
  HIDE_AREA_BRIGADE616 = { "RP-114499", "RP-114500", "RP-114501", "RP-114502" },
  FIRE_POINT_BRIGADE616_1 = { "RP-44369", "RP-44370", "RP-44371", "RP-44372" },
  AMMO_HOLDING_AREA_BRIGADE616 = { "RP-114507", "RP-114508", "RP-114509", "RP-114510" },
  MASK_BRIGADE616 = { "RP-44364", "RP-44365", "RP-44366", "RP-44367" },
  RELOAD_POINT_BRIGADE613 = { "RP-114515", "RP-114516", "RP-114517", "RP-114518" },
  HIDE_AREA_BRIGADE613 = { "RP-114511", "RP-114512", "RP-114513", "RP-114514" },
  FIRE_POINT_BRIGADE613_1 = { "RP-44391", "RP-44392", "RP-44393", "RP-44394" },
  AMMO_HOLDING_AREA_BRIGADE613 = { "RP-114519", "RP-114520", "RP-114521", "RP-114522" },
  MASK_BRIGADE613 = { "RP-44386", "RP-44387", "RP-44388", "RP-44389" },
  RELOAD_POINT_BRIGADE617 = { "RP-114527", "RP-114528", "RP-114529", "RP-114530" },
  HIDE_AREA_BRIGADE617 = { "RP-114523", "RP-114524", "RP-114525", "RP-114526" },
  FIRE_POINT_BRIGADE617_1 = { "RP-44413", "RP-44414", "RP-44415", "RP-44416" },
  AMMO_HOLDING_AREA_BRIGADE617 = { "RP-114531", "RP-114532", "RP-114533", "RP-114534" },
  MASK_BRIGADE617 = { "RP-44408", "RP-44409", "RP-44410", "RP-44411" },
  RELOAD_POINT_BRIGADE624 = { "RP-156928", "RP-156929", "RP-156930", "RP-156931" },
  HIDE_AREA_BRIGADE624 = { "RP-156932", "RP-156933", "RP-156934", "RP-156935" },
  FIRE_POINT_BRIGADE624_1 = { "RP-156936", "RP-156937", "RP-156938", "RP-156939" },
  AMMO_HOLDING_AREA_BRIGADE624 = { "RP-156924", "RP-156925", "RP-156926", "RP-156927" },
  MASK_BRIGADE624 = { "RP-156916", "RP-156921", "RP-156922", "RP-156923" },
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
  YJ12B = 3177,
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
  CSS11_MOD1 = 2885, --DF-16A
  CSS6_MOD2 = 4397,  --DF-15C
  CSS6_MOD3 = 4396,  --DF-15B
  CSS7_MOD2 = 4395,  --DF-11A
  CSS5_MOD5 = 1669,  --DF-21D
  CH_SSC_9 = 4399,   --CJ-10A
  HF3 = 3531,
  HF2E = 2587,
  LT2000 = 2251,
  HIMARS = 2446,
  BUILDING = 448,
  CUSTOMED_SSM = 3727,
  CUSTOMED_SAM = 2988,
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
  YJ12 = 2862,         -- YJ-12 Anti-Ship Missile
  FD280 = 4472,        -- FD280 Multiple Launch Rocket System
  CJ10A = 4515,        -- CJ-10A Cruise Missile
  DF11A = 2142,        -- DF-11A Short-Range Ballistic Missile
  DF16A = 4511,        -- DF-16A Short-Range Ballistic Missile
  DF15C = 2145,        -- DF-15C Short-Range Ballistic Missile
  DF15B = 4509,        -- DF-15B Short-Range Ballistic Missile
  DF21D = 2105,        -- DF-21D Medium-Range Ballistic Missile
  YJ21 = 4058,         -- YJ-18A Land Attack Cruise Missile
  CJ10_SLCM = 3716,    -- YJ-18 Submarine-Launched Cruise Missile
  AKD88 = 2876,        -- AKD-88 Air-to-Surface Missile
  PL15 = 3413,         -- PL-15 Air-to-Air Missile
  YJ91_ARM = 2875,     -- YJ-91 Anti-Radiation Missile
  YJ63 = 2107,         -- YJ-63 Air-Launched Cruise Missile
  KAB1500 = 3077,      -- KAB-1500 Laser-Guided Bomb
  LS_6_500 = 3226,     -- LS-6-500 Glide Bomb
  CS_BBC_5 = 4541,     -- CS-BBC-5 Glide Bomb (Submunitions)
  YJ91_ASM = 276,      -- YJ-91 Anti-Ship Missile
  YJ83 = 2137,         -- YJ-83 Anti-Ship Missile
  MK45_AMLRS = 2948,   -- MK45 AMLRS Multiple Launch Rocket System
  ATACMS = 1717,       -- ATACMS Tactical Missile System
  HF2E = 3228,         -- HF-2E Anti-Ship Cruise Missile
  HF3 = 1133,          -- HF-2 Anti-Ship Missile
  MK48_TORPEDO = 905,  -- MK-48 Torpedo
  HARPOON_II = 816,    -- Harpoon II
  JSOW = 826,          -- JSOW
  WAN_CHIEN = 3026,    -- Wan Chien
  SLAMER = 452,        -- SLAMER
  JDAM = 554,          -- JDAM
  HPJ_38 = 2691,       -- H/PJ-38 130mm
  MIM104F_PAC3 = 1150, -- MIM-104F PAC-3 Air Defense Missile
  MIM104F_PAC2 = 642,  -- MIM-104F PAC-2 Air Defense Missile
  TK3 = 888,           -- TK-3 Air-to-Surface Missile
}

constants.UNIT_TYPES = {
  AIRCRAFT = "Aircraft",
  SHIP = "Ship",
  SUBMARINE = "Submarine",
  FACILITY = "Facility",
  AIMPOINT = "AimPoint",
  WEAPON = "Weapon",
  SATELLITE = "Satellite",
  GROUND_UNIT = "GroundUnit"
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

constants.SPEEDS = {
  NORMAL = 20,
  FAST = 30,
}

constants.THROTTLES = {
  FLANK = "Flank",
  FULL = "Full",
  CRUSE = "Cruse",
}

---@type table<string, SBJ__OperationalArea>
constants.OPERATIONAL_AREAS = {
  PINGTAN = {
    RL = { {
      course = {
        { latitude = "N 25.30.20", longitude = "E 119.46.50", },
        { latitude = "N 25.30.13", longitude = "E 119.47.36", },
      },
      area = constants.AREAS.RELOAD_POINT_PINGTAN
    } },
    HA = { {
      course = {
        { latitude = "N 25.30.02", longitude = "E 119.47.17", },
      },
      area = constants.AREAS.HIDE_AREA_PINGTAN
    } },
    FP = {
      {
        course = {
          { latitude = "N 25.30.20", longitude = "E 119.46.50", },
          { latitude = "N 25.25.45", longitude = "E 119.44.25", },
        },
        area = constants.AREAS.FIRE_POINT_PINGTAN_1
      },
      {
        course = {
          { latitude = "N 25.30.20", longitude = "E 119.46.50", },
          { latitude = "N 25.27.22", longitude = "E 119.45.39", },
        },
        area = constants.AREAS.FIRE_POINT_PINGTAN_2
      },
    },
    AHA = { {
      course = {
        { latitude = "N 25.30.31", longitude = "E 119.47.37", },
      },
      area = constants.AREAS.AMMO_HOLDING_AREA_PINGTAN
    } },
    mask = { area = constants.AREAS.MASK_PINGTAN },
  },
  CHINCHEW = {
    RL = { {
      course = {
        { latitude = "N 24.46.44", longitude = "E 118.40.37", },
        { latitude = "N 24.46.36", longitude = "E 118.42.17", },
      },
      area = constants.AREAS.RELOAD_POINT_CHINCHEW
    } },
    HA = { {
      course = {
        { latitude = "N 24.46.31", longitude = "E 118.41.51", },
      },
      area = constants.AREAS.HIDE_AREA_CHINCHEW
    } },
    FP = { {
      course = {
        { latitude = "N 24.46.44", longitude = "E 118.40.37", },
        { latitude = "N 24.41.45", longitude = "E 118.43.18", },
      },
      area = constants.AREAS.FIRE_POINT_CHINCHEW_1
    }, },
    AHA = { {
      course = {
        { latitude = "N 24.47.10", longitude = "E 118.42.22", },
      },
      area = constants.AREAS.AMMO_HOLDING_AREA_CHINCHEW
    } },
    mask = { area = constants.AREAS.MASK_CHINCHEW },
  },
  BRIGADE_635 = {
    RL = { {
      course = {
        { latitude = "N 24.46.44", longitude = "E 118.40.37", },
        { latitude = "N 24.46.36", longitude = "E 118.42.17", },
      },
      area = constants.AREAS.RELOAD_POINT_CHINCHEW
    } },
    HA = { {
      course = {
        { latitude = "N 24.46.31", longitude = "E 118.41.51", },
      },
      area = constants.AREAS.HIDE_AREA_CHINCHEW
    } },
    FP = { {
      course = {
        { latitude = "N 24.46.44", longitude = "E 118.40.37", },
        { latitude = "N 24.41.45", longitude = "E 118.43.18", },
      },
      area = constants.AREAS.FIRE_POINT_CHINCHEW_1
    }, },
    AHA = { {
      course = {
        { latitude = "N 24.47.10", longitude = "E 118.42.22", },
      },
      area = constants.AREAS.AMMO_HOLDING_AREA_CHINCHEW
    } },
    mask = { area = constants.AREAS.MASK_CHINCHEW },
  },
  BRIGADE_615 = {
    RL = { {
      course = {
        { latitude = "N 24.17.32", longitude = "E 115.58.09", },
        { latitude = "N 24.16.56", longitude = "E 115.58.12", },
      },
      area = constants.AREAS.RELOAD_POINT_BRIGADE615
    } },
    HA = { {
      course = {
        { latitude = "N 24.17.06", longitude = "E 115.58.35", },
      },
      area = constants.AREAS.HIDE_AREA_BRIGADE615
    } },
    FP = { {
      course = {
        { latitude = "N 24.17.32", longitude = "E 115.58.09", },
        { latitude = "N 24.17.05", longitude = "E 115.59.41", },
      },
      area = constants.AREAS.FIRE_POINT_BRIGADE615_1
    }, },
    AHA = { {
      course = {
        { latitude = "N 24.17.05", longitude = "E 115.58.00", },
      },
      area = constants.AREAS.AMMO_HOLDING_AREA_BRIGADE615
    } },
    mask = { area = constants.AREAS.MASK_BRIGADE615 },
  },
  BRIGADE_614 = {
    RL = { {
      course = {
        { latitude = "N 26.04.01", longitude = "E 117.18.55", },
        { latitude = "N 26.03.40", longitude = "E 117.18.55", },
      },
      area = constants.AREAS.RELOAD_POINT_BRIGADE614
    } },
    HA = { {
      course = {
        { latitude = "N 26.03.48", longitude = "E 117.19.11", },
      },
      area = constants.AREAS.HIDE_AREA_BRIGADE614
    } },
    FP = { {
      course = {
        { latitude = "N 26.04.18", longitude = "E 117.18.51", },
        { latitude = "N 26.03.49", longitude = "E 117.20.05", },
      },
      area = constants.AREAS.FIRE_POINT_BRIGADE614_1
    }, },
    AHA = { {
      course = {
        { latitude = "N 26.03.47", longitude = "E 117.18.50", },
      },
      area = constants.AREAS.AMMO_HOLDING_AREA_BRIGADE614
    } },
    mask = { area = constants.AREAS.MASK_BRIGADE614 },
  },
  BRIGADE_636 = {
    RL = { {
      course = {
        { latitude = "N 24.45.52", longitude = "E 113.40.52", },
        { latitude = "N 24.45.25", longitude = "E 113.40.29", },
      },
      area = constants.AREAS.RELOAD_POINT_BRIGADE636
    } },
    HA = { {
      course = {
        { latitude = "N 24.45.33", longitude = "E 113.40.47", },
      },
      area = constants.AREAS.HIDE_AREA_BRIGADE636
    } },
    FP = { {
      course = {
        { latitude = "N 24.45.52", longitude = "E 113.40.52", },
        { latitude = "N 24.45.52", longitude = "E 113.41.35", },
      },
      area = constants.AREAS.FIRE_POINT_BRIGADE636_1
    }, },
    AHA = { {
      course = {
        { latitude = "N 24.45.34", longitude = "E 113.40.14", },
      },
      area = constants.AREAS.AMMO_HOLDING_AREA_BRIGADE636
    } },
    mask = { area = constants.AREAS.MASK_BRIGADE636 },
  },
  BRIGADE_616 = {
    RL = { {
      course = {
        { latitude = "N 25.54.31", longitude = "E 114.57.21", },
      },
      area = constants.AREAS.RELOAD_POINT_BRIGADE616
    } },
    HA = { {
      course = {
        { latitude = "N 25.54.40", longitude = "E 114.57.42", },
      },
      area = constants.AREAS.HIDE_AREA_BRIGADE616
    } },
    FP = { {
      course = {
        { latitude = "N 25.55.33", longitude = "E 114.58.25", },
      },
      area = constants.AREAS.FIRE_POINT_BRIGADE616_1
    }, },
    AHA = { {
      course = {
        { latitude = "N 25.54.38", longitude = "E 114.57.06", },
      },
      area = constants.AREAS.AMMO_HOLDING_AREA_BRIGADE616
    } },
    mask = { area = constants.AREAS.MASK_BRIGADE616 },
  },
  BRIGADE_613 = {
    RL = { {
      course = {
        { latitude = "N 28.27.25", longitude = "E 117.51.51", },
        { latitude = "N 28.27.26", longitude = "E 117.51.02", },
        { latitude = "N 28.27.03", longitude = "E 117.51.04", },
      },
      area = constants.AREAS.RELOAD_POINT_BRIGADE613
    } },
    HA = { {
      course = {
        { latitude = "N 28.27.12", longitude = "E 117.51.17", },
      },
      area = constants.AREAS.HIDE_AREA_BRIGADE613
    } },
    FP = { {
      course = {
        { latitude = 28.455760146701, longitude = 117.85790803852, },
        { latitude = 28.455941652975, longitude = 117.86516402324, },
        { latitude = 28.443410902986, longitude = 117.86719441616, },
      },
      area = constants.AREAS.FIRE_POINT_BRIGADE613_1
    }, },
    AHA = { {
      course = {
        { latitude = "N 28.27.12", longitude = "E 117.50.55", },
      },
      area = constants.AREAS.AMMO_HOLDING_AREA_BRIGADE613
    } },
    mask = { area = constants.AREAS.MASK_BRIGADE613 },
  },
  BRIGADE_617 = {
    RL = { {
      course = {
        { latitude = "N 29.09.32", longitude = "E 119.36.38", },
        { latitude = "N 29.08.57", longitude = "E 119.36.31", },
      },
      area = constants.AREAS.RELOAD_POINT_BRIGADE617
    } },
    HA = { {
      course = {
        { latitude = "N 29.09.01", longitude = "E 119.36.49", },
      },
      area = constants.AREAS.HIDE_AREA_BRIGADE617
    } },
    FP = { {
      course = {
        { latitude = 29.158533243915, longitude = 119.61541712539, },
        { latitude = 29.158295428459, longitude = 119.62849131226, },
      },
      area = constants.AREAS.FIRE_POINT_BRIGADE617_1
    }, },
    AHA = { {
      course = {
        { latitude = "N 29.09.03", longitude = "E 119.36.26", },
      },
      area = constants.AREAS.AMMO_HOLDING_AREA_BRIGADE617
    } },
    mask = { area = constants.AREAS.MASK_BRIGADE617 },
  },
  BRIGADE_624 = {
    RL = { {
      course = {
        { latitude = "N 19.29.01", longitude = "E 109.26.40", },
        { latitude = "N 19.28.27", longitude = "E 109.26.56", },
        { latitude = "N 19.28.29", longitude = "E 109.27.44", },
      },
      area = constants.AREAS.RELOAD_POINT_BRIGADE624
    } },
    HA = { {
      course = {
        { latitude = "N 19.28.35", longitude = "E 109.27.22", },
      },
      area = constants.AREAS.HIDE_AREA_BRIGADE624
    } },
    FP = { {
      course = {
        { latitude = "N 19.29.01", longitude = "E 109.26.40", },
        { latitude = "N 19.29.40", longitude = "E 109.27.17", },
      },
      area = constants.AREAS.FIRE_POINT_BRIGADE624_1
    }, },
    AHA = { {
      course = {
        { latitude = "N 19.28.12", longitude = "E 109.27.21", },
      },
      area = constants.AREAS.AMMO_HOLDING_AREA_BRIGADE624
    } },
    mask = { area = constants.AREAS.MASK_BRIGADE624 },
  },
  ANC = {
    RL = { {
      course = {
        { latitude = 22.734448481345, longitude = 120.34464870381, },
        { latitude = 22.692255445879, longitude = 120.33408272919, },
        { latitude = 22.700122214483, longitude = 120.29714192208, },
        { latitude = 22.709859490883, longitude = 120.29957865231, },
        { latitude = 22.711714026187, longitude = 120.30508065166, },
      },
      area = constants.AREAS.RELOAD_POINT_ANC
    } },
    HA = { {
      course = {
        { latitude = 22.711714026187, longitude = 120.30508065166, },
        { latitude = 22.719361110011, longitude = 120.3247169095, },
      },
      area = constants.AREAS.HIDE_AREA_ANC
    } },
    FP = {
      {
        course = {
          { latitude = 22.719361110011, longitude = 120.3247169095, },
          { latitude = 22.70802543728,  longitude = 120.30759960934, },
          { latitude = 22.709412883691, longitude = 120.30105601434, },
          { latitude = 22.709859490883, longitude = 120.29957865231, },
          { latitude = 22.700122214483, longitude = 120.29714192208, },
          { latitude = 22.692255445879, longitude = 120.33408272919, },
          { latitude = 22.734448481345, longitude = 120.34464870381, },
          { latitude = 22.703136483386, longitude = 120.37326412791, },
        },
        area = constants.AREAS.FIRE_POINT_ANC_1
      },
      {
        course = {
          { latitude = 22.719361110011, longitude = 120.3247169095, },
          { latitude = 22.70802543728,  longitude = 120.30759960934, },
          { latitude = 22.709412883691, longitude = 120.30105601434, },
          { latitude = 22.709859490883, longitude = 120.29957865231, },
          { latitude = 22.700122214483, longitude = 120.29714192208, },
          { latitude = 22.692255445879, longitude = 120.33408272919, },
          { latitude = 22.679493645888, longitude = 120.35660967565, },
        },
        area = constants.AREAS.FIRE_POINT_ANC_2
      },
    },
    AHA = { {
      course = {
        { latitude = 22.711714026187, longitude = 120.30508065166, },
        { latitude = 22.726770699839, longitude = 120.3128854188, },
      },
      area = constants.AREAS.AMMO_HOLDING_AREA_ANC
    } },
    mask = { area = constants.AREAS.MASK_ANC },
  },
  CFO = {
    RL = { {
      course = {
        { latitude = 23.443355126306, longitude = 120.43194998324, },
        { latitude = 23.443355126306, longitude = 120.47007333219, },
        { latitude = 23.433361970149, longitude = 120.4700731492, },
        { latitude = 23.430634723234, longitude = 120.44812923787, },
      },
      area = constants.AREAS.RELOAD_POINT_CFO
    } },
    HA = { {
      course = {
        { latitude = 23.430634723234, longitude = 120.44812923787, },
        { latitude = 23.415951581633, longitude = 120.44816467816, },
      },
      area = constants.AREAS.HIDE_AREA_CFO
    } },
    FP = {
      {
        course = {
          { latitude = 23.415951581633, longitude = 120.44816467816, },
          { latitude = 23.426722339092, longitude = 120.45660597859, },
          { latitude = 23.426722339092, longitude = 120.46333164968, },
          { latitude = 23.433361970149, longitude = 120.4700731492, },
          { latitude = 23.443355126306, longitude = 120.47007333219, },
          { latitude = 23.443355126306, longitude = 120.43194998324, },
          { latitude = 23.439934327267, longitude = 120.4001621619, },
        },
        area = constants.AREAS.FIRE_POINT_CFO_1
      },
      {
        course = {
          { latitude = 23.415951581633, longitude = 120.44816467816, },
          { latitude = 23.426722339092, longitude = 120.45660597859, },
          { latitude = 23.426722339092, longitude = 120.46333164968, },
          { latitude = 23.433361970149, longitude = 120.4700731492, },
          { latitude = 23.443355126306, longitude = 120.47007333219, },
          { latitude = 23.443355126306, longitude = 120.43194998324, },
          { latitude = 23.454148240833, longitude = 120.40947436051, },
        },
        area = constants.AREAS.FIRE_POINT_CFO_2
      },
    },
    AHA = { {
      course = {
        { latitude = 23.430634723234, longitude = 120.44812923787, },
        { latitude = 23.423645579333, longitude = 120.45996881413, },
      },
      area = constants.AREAS.AMMO_HOLDING_AREA_CFO
    } },
    mask = { area = constants.AREAS.MASK_CFO },
  },
  CZT = {
    RL = { {
      course = {
        { latitude = 25.048609043289, longitude = 121.21250617534, },
        { latitude = 25.084084613881, longitude = 121.23992237613, },
        { latitude = 25.064020063323, longitude = 121.27155210249, },
        { latitude = 25.055834217464, longitude = 121.26522459086, },
        { latitude = 25.051074854972, longitude = 121.2346921168, },
      },
      area = constants.AREAS.RELOAD_POINT_CZT
    } },
    HA = { {
      course = {
        { latitude = 25.051074854972, longitude = 121.2346921168, },
        { latitude = 25.044268041641, longitude = 121.2487884433, },
      },
      area = constants.AREAS.HIDE_AREA_CZT
    } },
    FP = {
      {
        course = {
          { latitude = 25.044268041641, longitude = 121.2487884433, },
          { latitude = 25.055834217464, longitude = 121.26522459086, },
          { latitude = 25.064020063323, longitude = 121.27155210249, },
          { latitude = 25.084084613881, longitude = 121.23992237613, },
          { latitude = 25.048609043289, longitude = 121.21250617534, },
          { latitude = 25.08838323961,  longitude = 121.20014056497, },
        },
        area = constants.AREAS.FIRE_POINT_CZT_1
      },
      {
        course = {
          { latitude = 25.044268041641, longitude = 121.2487884433, },
          { latitude = 25.055834217464, longitude = 121.26522459086, },
          { latitude = 25.064020063323, longitude = 121.27155210249, },
          { latitude = 25.084084613881, longitude = 121.23992237613, },
          { latitude = 25.104879867912, longitude = 121.2291706725, },
        },
        area = constants.AREAS.FIRE_POINT_CZT_2
      },
    },
    AHA = { {
      course = {
        { latitude = 25.051074854972, longitude = 121.2346921168, },
        { latitude = 25.056590359678, longitude = 121.24660297625, },
      },
      area = constants.AREAS.AMMO_HOLDING_AREA_CZT
    } },
    mask = { area = constants.AREAS.MASK_CZT },
  },
  DAW = {
    RL = { {
      course = {
        { latitude = 24.218572987131, longitude = 120.58382742372, },
        { latitude = 24.175268856826, longitude = 120.58382091228, },
        { latitude = 24.175268856826, longitude = 120.54548206624, },
        { latitude = 24.185262226627, longitude = 120.54548187557, },
        { latitude = 24.202180150883, longitude = 120.56737533067, },
      },
      area = constants.AREAS.RELOAD_POINT_DAW
    } },
    HA = { {
      course = {
        { latitude = 24.202180150883, longitude = 120.56737533067, },
        { latitude = 24.205730593615, longitude = 120.55336659615, },
      },
      area = constants.AREAS.HIDE_AREA_DAW
    } },
    FP = {
      {
        course = {
          { latitude = 24.205730593615, longitude = 120.55336659615, },
          { latitude = 24.185262226627, longitude = 120.54548187557, },
          { latitude = 24.175268856826, longitude = 120.54548206624, },
          { latitude = 24.175268856826, longitude = 120.58382091228, },
          { latitude = 24.218572987131, longitude = 120.58382742372, },
          { latitude = 24.222362628299, longitude = 120.61165792482, },
        },
        area = constants.AREAS.FIRE_POINT_DAW_1
      },
      {
        course = {
          { latitude = 24.205730593615, longitude = 120.55336659615, },
          { latitude = 24.185262226627, longitude = 120.54548187557, },
          { latitude = 24.175268856826, longitude = 120.54548206624, },
          { latitude = 24.175268856826, longitude = 120.58382091228, },
          { latitude = 24.166238635937, longitude = 120.60774718454, },
        },
        area = constants.AREAS.FIRE_POINT_DAW_2
      },
    },
    AHA = { {
      course = {
        { latitude = 24.202180150883, longitude = 120.56737533067, },
        { latitude = 24.189599340819, longitude = 120.55799841409, },
      },
      area = constants.AREAS.AMMO_HOLDING_AREA_DAW
    } },
    mask = { area = constants.AREAS.MASK_DAW },
  },
  DXN = {
    RL = { {
      course = {
        { latitude = 24.661305655003, longitude = 121.68482676374, },
        { latitude = 24.660695338381, longitude = 121.7233075961, },
        { latitude = 24.670687183998, longitude = 121.72349971391, },
        { latitude = 24.675050166405, longitude = 121.71750435888, },
      },
      area = constants.AREAS.RELOAD_POINT_DXN
    } },
    HA = { {
      course = {
        { latitude = 24.675050166405, longitude = 121.71750435888, },
        { latitude = 24.690921664929, longitude = 121.71450505669, },
      },
      area = constants.AREAS.HIDE_AREA_DXN
    } },
    FP = {
      {
        course = {
          { latitude = 24.690921664929, longitude = 121.71450505669, },
          { latitude = 24.670687183998, longitude = 121.72349971391, },
          { latitude = 24.660695338381, longitude = 121.7233075961, },
          { latitude = 24.661305655003, longitude = 121.68482676374, },
          { latitude = 24.672262963844, longitude = 121.65106789401, },
        },
        area = constants.AREAS.FIRE_POINT_DXN_1
      },
      {
        course = {
          { latitude = 24.690921664929, longitude = 121.71450505669, },
          { latitude = 24.694001143985, longitude = 121.72395387247, },
          { latitude = 24.70399276724,  longitude = 121.72414603222, },
          { latitude = 24.704603295861, longitude = 121.68565183726, },
          { latitude = 24.661305655003, longitude = 121.68482676374, },
          { latitude = 24.68682269679,  longitude = 121.6500624823, },
        },
        area = constants.AREAS.FIRE_POINT_DXN_2
      },
    },
    AHA = { {
      course = {
        { latitude = 24.675050166405, longitude = 121.71750435888, },
        { latitude = 24.681246865891, longitude = 121.70573910019, },
      },
      area = constants.AREAS.AMMO_HOLDING_AREA_DXN
    } },
    mask = { area = constants.AREAS.MASK_DXN },
  },
  EAA = {
    RL = { {
      course = {
        { latitude = 22.995695360115, longitude = 120.21434714289, },
        { latitude = 22.952391229765, longitude = 120.2143532291, },
        { latitude = 22.952391229765, longitude = 120.25233683437, },
        { latitude = 22.962384593417, longitude = 120.25233701259, },
        { latitude = 22.966835804915, longitude = 120.22960088586, },
      },
      area = constants.AREAS.RELOAD_POINT_EAA
    } },
    HA = { {
      course = {
        { latitude = 22.966835804915, longitude = 120.22960088586, },
        { latitude = 22.982772579667, longitude = 120.23400849108, },
      },
      area = constants.AREAS.HIDE_AREA_EAA
    } },
    FP = {
      {
        course = {
          { latitude = 22.982772579667, longitude = 120.23400849108, },
          { latitude = 22.962384593417, longitude = 120.25233701259, },
          { latitude = 22.952391229765, longitude = 120.25233683437, },
          { latitude = 22.952391229765, longitude = 120.2143532291, },
          { latitude = 22.995695360115, longitude = 120.21434714289, },
          { latitude = 22.971087643121, longitude = 120.17883095863, },
        },
        area = constants.AREAS.FIRE_POINT_EAA_1
      },
      {
        course = {
          { latitude = 22.982772579667, longitude = 120.23400849108, },
          { latitude = 22.962384593417, longitude = 120.25233701259, },
          { latitude = 22.952391229765, longitude = 120.25233683437, },
          { latitude = 22.952391229765, longitude = 120.2143532291, },
          { latitude = 22.950967671566, longitude = 120.18491208786, },
        },
        area = constants.AREAS.FIRE_POINT_EAA_2
      },
    },
    AHA = { {
      course = {
        { latitude = 22.966835804915, longitude = 120.22960088586, },
        { latitude = 22.974759427885, longitude = 120.24459496634, },
      },
      area = constants.AREAS.AMMO_HOLDING_AREA_EAA
    } },
    mask = { area = constants.AREAS.MASK_EAA },
  },
  FAH = {
    RL = { {
      course = {
        { latitude = 24.967401054098, longitude = 121.48081728109, },
        { latitude = 24.979933418809, longitude = 121.44479520012, },
        { latitude = 24.989263100664, longitude = 121.44874612527, },
        { latitude = 24.993105356298, longitude = 121.4543197487, },
        { latitude = 24.998863259624, longitude = 121.45674587106, },
        { latitude = 25.005039033354, longitude = 121.46736693743, },
      },
      area = constants.AREAS.RELOAD_POINT_FAH
    } },
    HA = { {
      course = {
        { latitude = 25.005039033354, longitude = 121.46736693743, },
        { latitude = 24.994882762705, longitude = 121.45868287495, },
      },
      area = constants.AREAS.HIDE_AREA_FAH
    } },
    FP = {
      {
        course = {
          { latitude = 24.994882762705, longitude = 121.45868287495, },
          { latitude = 24.989263100664, longitude = 121.44874612527, },
          { latitude = 24.979933418809, longitude = 121.44479520012, },
          { latitude = 24.967401054098, longitude = 121.48081728109, },
          { latitude = 24.967060300271, longitude = 121.51743724562, },
        },
        area = constants.AREAS.FIRE_POINT_FAH_1
      },
      {
        course = {
          { latitude = 24.994882762705, longitude = 121.45868287495, },
          { latitude = 24.989263100664, longitude = 121.44874612527, },
          { latitude = 24.979933418809, longitude = 121.44479520012, },
          { latitude = 24.967401054098, longitude = 121.48081728109, },
          { latitude = 24.955589661925, longitude = 121.50644320841, },
        },
        area = constants.AREAS.FIRE_POINT_FAH_2
      },
    },
    AHA = { {
      course = {
        { latitude = 25.005039033354, longitude = 121.46736693743, },
        { latitude = 24.994069995929, longitude = 121.47219215191, },
      },
      area = constants.AREAS.AMMO_HOLDING_AREA_FAH
    } },
    mask = { area = constants.AREAS.MASK_FAH },
  },
  FOW = {
    RL = { {
      course = {
        { latitude = 24.80879486298,  longitude = 120.98458340579, },
        { latitude = 24.791304013249, longitude = 121.01794945529, },
        { latitude = 24.782649757943, longitude = 121.0124457825, },
        { latitude = 24.78074805745,  longitude = 121.00027466363, },
        { latitude = 24.783824087424, longitude = 120.99443071324, },
        { latitude = 24.782881920996, longitude = 120.98554559024, },
      },
      area = constants.AREAS.RELOAD_POINT_FOW
    } },
    HA = { {
      course = {
        { latitude = 24.782881920996, longitude = 120.98554559024, },
        { latitude = 24.772994901784, longitude = 120.99276846382, },
      },
      area = constants.AREAS.HIDE_AREA_FOW
    } },
    FP = {
      {
        course = {
          { latitude = 24.772994901784, longitude = 120.99276846382, },
          { latitude = 24.782649757943, longitude = 121.0124457825, },
          { latitude = 24.791304013249, longitude = 121.01794945529, },
          { latitude = 24.80879486298,  longitude = 120.98458340579, },
          { latitude = 24.818325412541, longitude = 120.95266632912, },
        },
        area = constants.AREAS.FIRE_POINT_FOW_1
      },
      {
        course = {
          { latitude = 24.772994901784, longitude = 120.99276846382, },
          { latitude = 24.762458531502, longitude = 120.99960059181, },
          { latitude = 24.753804178291, longitude = 120.99409795796, },
          { latitude = 24.771289743409, longitude = 120.96073862952, },
          { latitude = 24.80879486298,  longitude = 120.98458340579, },
          { latitude = 24.802960848135, longitude = 120.94012574641, },
        },
        area = constants.AREAS.FIRE_POINT_FOW_2
      },
    },
    AHA = { {
      course = {
        { latitude = 24.782881920996, longitude = 120.98554559024, },
        { latitude = 24.784954766007, longitude = 120.99904270473, },
      },
      area = constants.AREAS.AMMO_HOLDING_AREA_FOW
    } },
    mask = { area = constants.AREAS.MASK_FOW },
  },
  GDN = {
    RL = { {
      course = {
        { latitude = 22.606477340789, longitude = 120.58314334131, },
        { latitude = 22.563179901791, longitude = 120.58231885556, },
        { latitude = 22.563790228473, longitude = 120.54444901911, },
        { latitude = 22.573782072229, longitude = 120.54463771935, },
        { latitude = 22.576520386606, longitude = 120.56214616101, },
      },
      area = constants.AREAS.RELOAD_POINT_GDN
    } },
    HA = { {
      course = {
        { latitude = 22.576520386606, longitude = 120.56214616101, },
        { latitude = 22.585402057136, longitude = 120.55272859842, },
      },
      area = constants.AREAS.HIDE_AREA_GDN
    } },
    FP = {
      {
        course = {
          { latitude = 22.585402057136, longitude = 120.55272859842, },
          { latitude = 22.573782072229, longitude = 120.54463771935, },
          { latitude = 22.563790228473, longitude = 120.54444901911, },
          { latitude = 22.563179901791, longitude = 120.58231885556, },
          { latitude = 22.606477340789, longitude = 120.58314334131, },
          { latitude = 22.591031066358, longitude = 120.6175327437, },
        },
        area = constants.AREAS.FIRE_POINT_GDN_1
      },
      {
        course = {
          { latitude = 22.585402057136, longitude = 120.55272859842, },
          { latitude = 22.573782072229, longitude = 120.54463771935, },
          { latitude = 22.563790228473, longitude = 120.54444901911, },
          { latitude = 22.563179901791, longitude = 120.58231885556, },
          { latitude = 22.556808258479, longitude = 120.60836848597, },
        },
        area = constants.AREAS.FIRE_POINT_GDN_2
      },
    },
    AHA = { {
      course = {
        { latitude = 22.576520386606, longitude = 120.56214616101, },
        { latitude = 22.589910094482, longitude = 120.56618208956, },
      },
      area = constants.AREAS.AMMO_HOLDING_AREA_GDN
    } },
    mask = { area = constants.AREAS.MASK_GDN },
  },
  GVG = {
    RL = { {
      course = {
        { latitude = 24.259847248629, longitude = 120.68932156814, },
        { latitude = 24.303151378932, longitude = 120.68931502662, },
        { latitude = 24.303151378932, longitude = 120.72769241967, },
        { latitude = 24.29315822712,  longitude = 120.72769222784, },
        { latitude = 24.276510816253, longitude = 120.71727249174, },
      },
      area = constants.AREAS.RELOAD_POINT_GVG
    } },
    HA = { {
      course = {
        { latitude = 24.276510816253, longitude = 120.71727249174, },
        { latitude = 24.27941830869,  longitude = 120.70375754453, },
      },
      area = constants.AREAS.HIDE_AREA_GVG
    } },
    FP = {
      {
        course = {
          { latitude = 24.27941830869,  longitude = 120.70375754453, },
          { latitude = 24.287008845798, longitude = 120.71420159768, },
          { latitude = 24.287008845798, longitude = 120.72093764223, },
          { latitude = 24.29315822712,  longitude = 120.72769222784, },
          { latitude = 24.303151378932, longitude = 120.72769241967, },
          { latitude = 24.303151378932, longitude = 120.68931502662, },
          { latitude = 24.259847248629, longitude = 120.68932156814, },
          { latitude = 24.281964020233, longitude = 120.65389558403, },
        },
        area = constants.AREAS.FIRE_POINT_GVG_1
      },
      {
        course = {
          { latitude = 24.27941830869,  longitude = 120.70375754453, },
          { latitude = 24.287008845798, longitude = 120.71420159768, },
          { latitude = 24.287008845798, longitude = 120.72093764223, },
          { latitude = 24.29315822712,  longitude = 120.72769222784, },
          { latitude = 24.303151378932, longitude = 120.72769241967, },
          { latitude = 24.303151378932, longitude = 120.68931502662, },
          { latitude = 24.302157269513, longitude = 120.65877465187, },
        },
        area = constants.AREAS.FIRE_POINT_GVG_2
      },
    },
    AHA = { {
      course = {
        { latitude = 24.276510816253, longitude = 120.71727249174, },
        { latitude = 24.290090300469, longitude = 120.71756961996, },
      },
      area = constants.AREAS.AMMO_HOLDING_AREA_GVG
    } },
    mask = { area = constants.AREAS.MASK_GVG },
  },
  IXZ = {
    RL = { {
      course = {
        { latitude = 23.028420799939, longitude = 120.29423290578, },
        { latitude = 22.985116669589, longitude = 120.29422680841, },
        { latitude = 22.985116669589, longitude = 120.25623400702, },
        { latitude = 22.995110033404, longitude = 120.25623382847, },
        { latitude = 22.998307432687, longitude = 120.26245429515, },
      },
      area = constants.AREAS.RELOAD_POINT_IXZ
    } },
    HA = { {
      course = {
        { latitude = 22.998307432687, longitude = 120.26245429515, },
        { latitude = 23.003633733138, longitude = 120.27897560947, },
      },
      area = constants.AREAS.HIDE_AREA_IXZ
    } },
    FP = {
      {
        course = {
          { latitude = 23.003633733138, longitude = 120.27897560947, },
          { latitude = 22.995232864089, longitude = 120.26581435103, },
          { latitude = 22.995232864089, longitude = 120.25909423927, },
          { latitude = 22.995110033404, longitude = 120.25623382847, },
          { latitude = 22.985116669589, longitude = 120.25623400702, },
          { latitude = 22.985116669589, longitude = 120.29422680841, },
          { latitude = 23.028420799939, longitude = 120.29423290578, },
          { latitude = 23.013787555096, longitude = 120.32930095807, },
        },
        area = constants.AREAS.FIRE_POINT_IXZ_1
      },
      {
        course = {
          { latitude = 23.003633733138, longitude = 120.27897560947, },
          { latitude = 22.995232864089, longitude = 120.26581435103, },
          { latitude = 22.995232864089, longitude = 120.25909423927, },
          { latitude = 22.995110033404, longitude = 120.25623382847, },
          { latitude = 22.985116669589, longitude = 120.25623400702, },
          { latitude = 22.985116669589, longitude = 120.29422680841, },
          { latitude = 22.988521888895, longitude = 120.32606512849, },
        },
        area = constants.AREAS.FIRE_POINT_IXZ_2
      },
    },
    AHA = { {
      course = {
        { latitude = 22.998307432687, longitude = 120.26245429515, },
        { latitude = 23.010642609747, longitude = 120.26332076226, },
      },
      area = constants.AREAS.AMMO_HOLDING_AREA_IXZ
    } },
    mask = { area = constants.AREAS.MASK_IXZ },
  },
  JBT = {
    RL = { {
      course = {
        { latitude = 25.158191767835, longitude = 121.66382500619, },
        { latitude = 25.140706249743, longitude = 121.63036064964, },
        { latitude = 25.1493606018,   longitude = 121.62484069544, },
        { latitude = 25.162004342185, longitude = 121.63906801507, },
      },
      area = constants.AREAS.RELOAD_POINT_JBT
    } },
    HA = { {
      course = {
        { latitude = 25.162004342185, longitude = 121.63906801507, },
        { latitude = 25.167564528807, longitude = 121.62005901342, },
      },
      area = constants.AREAS.HIDE_AREA_JBT
    } },
    FP = {
      {
        course = {
          { latitude = 25.167564528807, longitude = 121.62005901342, },
          { latitude = 25.1493606018,   longitude = 121.62484069544, },
          { latitude = 25.140706249743, longitude = 121.63036064964, },
          { latitude = 25.158191767835, longitude = 121.66382500619, },
          { latitude = 25.160694544308, longitude = 121.68912078849, },
        },
        area = constants.AREAS.FIRE_POINT_JBT_1
      },
      {
        course = {
          { latitude = 25.167564528807, longitude = 121.62005901342, },
          { latitude = 25.1493606018,   longitude = 121.62484069544, },
          { latitude = 25.140706249743, longitude = 121.63036064964, },
          { latitude = 25.158191767835, longitude = 121.66382500619, },
          { latitude = 25.195696934431, longitude = 121.63990517444, },
          { latitude = 25.197353821077, longitude = 121.679489115, },
        },
        area = constants.AREAS.FIRE_POINT_JBT_2
      },
    },
    AHA = { {
      course = {
        { latitude = 25.162004342185, longitude = 121.63906801507, },
        { latitude = 25.174030815462, longitude = 121.63697597053, },
      },
      area = constants.AREAS.AMMO_HOLDING_AREA_JBT
    } },
    mask = { area = constants.AREAS.MASK_JBT },
  },
  NGP = {
    RL = { {
      course = {
        { latitude = 25.051286187926, longitude = 121.55889584624, },
        { latitude = 25.008087973828, longitude = 121.55555523996, },
        { latitude = 25.01052737575,  longitude = 121.51705409657, },
        { latitude = 25.020496423972, longitude = 121.51782317403, },
        { latitude = 25.024781031157, longitude = 121.5277933076, },
      },
      area = constants.AREAS.RELOAD_POINT_NGP
    } },
    HA = { {
      course = {
        { latitude = 25.024781031157, longitude = 121.5277933076, },
        { latitude = 25.035019016289, longitude = 121.53665845807, },
      },
      area = constants.AREAS.HIDE_AREA_NGP
    } },
    FP = {
      {
        course = {
          { latitude = 25.035019016289, longitude = 121.53665845807, },
          { latitude = 25.020496423972, longitude = 121.51782317403, },
          { latitude = 25.01052737575,  longitude = 121.51705409657, },
          { latitude = 25.008087973828, longitude = 121.55555523996, },
          { latitude = 25.051286187926, longitude = 121.55889584624, },
          { latitude = 25.03412562636,  longitude = 121.59246923097, },
        },
        area = constants.AREAS.FIRE_POINT_NGP_1
      },
      {
        course = {
          { latitude = 25.035019016289, longitude = 121.53665845807, },
          { latitude = 25.020496423972, longitude = 121.51782317403, },
          { latitude = 25.01052737575,  longitude = 121.51705409657, },
          { latitude = 25.008087973828, longitude = 121.55555523996, },
          { latitude = 25.051286187926, longitude = 121.55889584624, },
          { latitude = 25.04353650045,  longitude = 121.59081154742, },
        },
        area = constants.AREAS.FIRE_POINT_NGP_2
      },
    },
    AHA = { {
      course = {
        { latitude = 25.024781031157, longitude = 121.5277933076, },
        { latitude = 25.023251000892, longitude = 121.54096896885, },
      },
      area = constants.AREAS.AMMO_HOLDING_AREA_NGP
    } },
    mask = { area = constants.AREAS.MASK_NGP },
  },
  NYD = {
    RL = { {
      course = {
        { latitude = 24.156681019605, longitude = 120.69934622871, },
        { latitude = 24.113376889297, longitude = 120.69933973922, },
        { latitude = 24.113376889297, longitude = 120.66101945268, },
        { latitude = 24.123370258784, longitude = 120.66101926265, },
        { latitude = 24.12752419677,  longitude = 120.66835028418, },
      },
      area = constants.AREAS.RELOAD_POINT_NYD
    } },
    HA = { {
      course = {
        { latitude = 24.12752419677,  longitude = 120.66835028418, },
        { latitude = 24.128480939802, longitude = 120.68225129295, },
      },
      area = constants.AREAS.HIDE_AREA_NYD
    } },
    FP = {
      {
        course = {
          { latitude = 24.128480939802, longitude = 120.68225129295, },
          { latitude = 24.124443554635, longitude = 120.67171700135, },
          { latitude = 24.124443554635, longitude = 120.66498356702, },
          { latitude = 24.123370258784, longitude = 120.66101926265, },
          { latitude = 24.113376889297, longitude = 120.66101945268, },
          { latitude = 24.113376889297, longitude = 120.69933973922, },
          { latitude = 24.156681019605, longitude = 120.69934622871, },
          { latitude = 24.142864693726, longitude = 120.73411613005, },
        },
        area = constants.AREAS.FIRE_POINT_NYD_1
      },
      {
        course = {
          { latitude = 24.128480939802, longitude = 120.68225129295, },
          { latitude = 24.124443554635, longitude = 120.67171700135, },
          { latitude = 24.124443554635, longitude = 120.66498356702, },
          { latitude = 24.123370258784, longitude = 120.66101926265, },
          { latitude = 24.113376889297, longitude = 120.66101945268, },
          { latitude = 24.113376889297, longitude = 120.69933973922, },
          { latitude = 24.156681019605, longitude = 120.69934622871, },
          { latitude = 24.152686900354, longitude = 120.73127012226, },
        },
        area = constants.AREAS.FIRE_POINT_NYD_2
      },
    },
    AHA = { {
      course = {
        { latitude = 24.12752419677,  longitude = 120.66835028418, },
        { latitude = 24.140802906413, longitude = 120.67770567055, },
      },
      area = constants.AREAS.AMMO_HOLDING_AREA_NYD
    } },
    mask = { area = constants.AREAS.MASK_NYD },
  },
  ONY = {
    RL = { {
      course = {
        { latitude = 24.887677989594, longitude = 121.08483790186, },
        { latitude = 24.887677989594, longitude = 121.04628087255, },
        { latitude = 24.897671363032, longitude = 121.04628067438, },
        { latitude = 24.901588769067, longitude = 121.05494852874, },
      },
      area = constants.AREAS.RELOAD_POINT_ONY
    } },
    HA = { {
      course = {
        { latitude = 24.901588769067, longitude = 121.05494852874, },
        { latitude = 24.909288424199, longitude = 121.064931797, },
      },
      area = constants.AREAS.HIDE_AREA_ONY
    } },
    FP = {
      {
        course = {
          { latitude = 24.909288424199, longitude = 121.064931797, },
          { latitude = 24.904673747699, longitude = 121.05832009733, },
          { latitude = 24.904673747699, longitude = 121.05157696015, },
          { latitude = 24.897671363032, longitude = 121.04628067438, },
          { latitude = 24.887677989594, longitude = 121.04628087255, },
          { latitude = 24.887677989594, longitude = 121.08483790186, },
          { latitude = 24.877901188266, longitude = 121.10800753417, },
        },
        area = constants.AREAS.FIRE_POINT_ONY_1
      },
      {
        course = {
          { latitude = 24.909288424199, longitude = 121.064931797, },
          { latitude = 24.904673747699, longitude = 121.05832009733, },
          { latitude = 24.904673747699, longitude = 121.05157696015, },
          { latitude = 24.897671363032, longitude = 121.04628067438, },
          { latitude = 24.887677989594, longitude = 121.04628087255, },
          { latitude = 24.887677989594, longitude = 121.08483790186, },
          { latitude = 24.930982119872, longitude = 121.08484466943, },
          { latitude = 24.935754927043, longitude = 121.1119134759, },
        },
        area = constants.AREAS.FIRE_POINT_ONY_2
      },
    },
    AHA = { {
      course = {
        { latitude = 24.901588769067, longitude = 121.05494852874, },
        { latitude = 24.914238446662, longitude = 121.05216595839, },
      },
      area = constants.AREAS.AMMO_HOLDING_AREA_ONY
    } },
    mask = { area = constants.AREAS.MASK_ONY },
  },
  PCQ = {
    RL = { {
      course = {
        { latitude = 25.192297807474, longitude = 121.46944932985, },
        { latitude = 25.20596194267,  longitude = 121.50503256964, },
        { latitude = 25.215160959158, longitude = 121.50071686344, },
        { latitude = 25.220266463131, longitude = 121.49127584443, },
        { latitude = 25.21786485501,  longitude = 121.4850599655, },
        { latitude = 25.218563451281, longitude = 121.47327336611, },
      },
      area = constants.AREAS.RELOAD_POINT_PCQ
    } },
    HA = { {
      course = {
        { latitude = 25.218563451281, longitude = 121.47327336611, },
        { latitude = 25.228784935235, longitude = 121.47944716878, },
      },
      area = constants.AREAS.HIDE_AREA_PCQ
    } },
    FP = {
      {
        course = {
          { latitude = 25.228784935235, longitude = 121.47944716878, },
          { latitude = 25.215160959158, longitude = 121.50071686344, },
          { latitude = 25.20596194267,  longitude = 121.50503256964, },
          { latitude = 25.192297807474, longitude = 121.46944932985, },
          { latitude = 25.175174819277, longitude = 121.45178829687, },
        },
        area = constants.AREAS.FIRE_POINT_PCQ_1
      },
      {
        course = {
          { latitude = 25.228784935235, longitude = 121.47944716878, },
          { latitude = 25.215160959158, longitude = 121.50071686344, },
          { latitude = 25.20596194267,  longitude = 121.50503256964, },
          { latitude = 25.192297807474, longitude = 121.46944932985, },
          { latitude = 25.190485622126, longitude = 121.4330972854, },
        },
        area = constants.AREAS.FIRE_POINT_PCQ_2
      },
    },
    AHA = { {
      course = {
        { latitude = 25.218563451281, longitude = 121.47327336611, },
        { latitude = 25.216226507284, longitude = 121.48949189097, },
      },
      area = constants.AREAS.AMMO_HOLDING_AREA_PCQ
    } },
    mask = { area = constants.AREAS.MASK_PCQ },
  },
  SPK = {
    RL = { {
      course = {
        { latitude = 24.978487183536, longitude = 121.27605787964, },
        { latitude = 24.96099631321,  longitude = 121.30946978657, },
        { latitude = 24.952342059172, longitude = 121.303958552, },
        { latitude = 24.959511668402, longitude = 121.28358706164, },
      },
      area = constants.AREAS.RELOAD_POINT_SPK
    } },
    HA = { {
      course = {
        { latitude = 24.959511668402, longitude = 121.28358706164, },
        { latitude = 24.944505930391, longitude = 121.29262143349, },
      },
      area = constants.AREAS.HIDE_AREA_SPK
    } },
    FP = {
      {
        course = {
          { latitude = 24.944505930391, longitude = 121.29262143349, },
          { latitude = 24.952342059172, longitude = 121.303958552, },
          { latitude = 24.96099631321,  longitude = 121.30946978657, },
          { latitude = 24.978487183536, longitude = 121.27605787964, },
          { latitude = 24.991296303426, longitude = 121.24854003788, },
        },
        area = constants.AREAS.FIRE_POINT_SPK_1
      },
      {
        course = {
          { latitude = 24.944505930391, longitude = 121.29262143349, },
          { latitude = 24.932150851553, longitude = 121.29109568699, },
          { latitude = 24.923496498848, longitude = 121.2855855009, },
          { latitude = 24.940982043377, longitude = 121.25218037671, },
          { latitude = 24.94482707325,  longitude = 121.22663089566, },
        },
        area = constants.AREAS.FIRE_POINT_SPK_2
      },
    },
    AHA = { {
      course = {
        { latitude = 24.959511668402, longitude = 121.28358706164, },
        { latitude = 24.947889994464, longitude = 121.27995340454, },
      },
      area = constants.AREAS.AMMO_HOLDING_AREA_SPK
    } },
    mask = { area = constants.AREAS.MASK_SPK },
  },
  TLM = {
    RL = { {
      course = {
        { latitude = 24.246781903079, longitude = 120.67078411005, },
        { latitude = 24.246781903079, longitude = 120.70914447882, },
        { latitude = 24.23678875098,  longitude = 120.70914428757, },
        { latitude = 24.230731734306, longitude = 120.70338783849, },
        { latitude = 24.230731734306, longitude = 120.69665247277, },
        { latitude = 24.228598311034, longitude = 120.68734102235, },
      },
      area = constants.AREAS.RELOAD_POINT_TLM
    } },
    HA = { {
      course = {
        { latitude = 24.228598311034, longitude = 120.68734102235, },
        { latitude = 24.233812876215, longitude = 120.70002015563, },
      },
      area = constants.AREAS.HIDE_AREA_TLM
    } },
    FP = {
      {
        course = {
          { latitude = 24.233812876215, longitude = 120.70002015563, },
          { latitude = 24.23678875098,  longitude = 120.70914428757, },
          { latitude = 24.246781903079, longitude = 120.70914447882, },
          { latitude = 24.246781903079, longitude = 120.67078411005, },
          { latitude = 24.253551141927, longitude = 120.64504311455, },
        },
        area = constants.AREAS.FIRE_POINT_TLM_1
      },
      {
        course = {
          { latitude = 24.233812876215, longitude = 120.70002015563, },
          { latitude = 24.23678875098,  longitude = 120.70914428757, },
          { latitude = 24.246781903079, longitude = 120.70914447882, },
          { latitude = 24.246781903079, longitude = 120.67078411005, },
          { latitude = 24.240270076649, longitude = 120.63791782043, },
        },
        area = constants.AREAS.FIRE_POINT_TLM_2
      },
    },
    AHA = { {
      course = {
        { latitude = 24.228598311034, longitude = 120.68734102235, },
        { latitude = 24.217681217646, longitude = 120.6939117617, },
      },
      area = constants.AREAS.AMMO_HOLDING_AREA_TLM
    } },
    mask = { area = constants.AREAS.MASK_TLM },
  },
  TQG = {
    RL = { {
      course = {
        { latitude = 22.750745374181, longitude = 121.13368174774, },
        { latitude = 22.750135048383, longitude = 121.09576029522, },
        { latitude = 22.760126884773, longitude = 121.09557098788, },
        { latitude = 22.76543739252,  longitude = 121.10034581861, },
      },
      area = constants.AREAS.RELOAD_POINT_TQG
    } },
    HA = { {
      course = {
        { latitude = 22.76543739252,  longitude = 121.10034581861, },
        { latitude = 22.774934085276, longitude = 121.1086026512, },
      },
      area = constants.AREAS.HIDE_AREA_TQG
    } },
    FP = {
      {
        course = {
          { latitude = 22.774934085276, longitude = 121.1086026512, },
          { latitude = 22.768456436275, longitude = 121.09692905118, },
          { latitude = 22.762310688427, longitude = 121.097045983, },
          { latitude = 22.760126884773, longitude = 121.09557098788, },
          { latitude = 22.750135048383, longitude = 121.09576029522, },
          { latitude = 22.750745374181, longitude = 121.13368174774, },
          { latitude = 22.755789806542, longitude = 121.16593075094, },
        },
        area = constants.AREAS.FIRE_POINT_TQG_1
      },
      {
        course = {
          { latitude = 22.774934085276, longitude = 121.1086026512, },
          { latitude = 22.768456436275, longitude = 121.09692905118, },
          { latitude = 22.762310688427, longitude = 121.097045983, },
          { latitude = 22.760126884773, longitude = 121.09557098788, },
          { latitude = 22.750135048383, longitude = 121.09576029522, },
          { latitude = 22.750745374181, longitude = 121.13368174774, },
          { latitude = 22.794043005932, longitude = 121.13286811009, },
          { latitude = 22.792948410961, longitude = 121.16393971025, },
        },
        area = constants.AREAS.FIRE_POINT_TQG_2
      },
    },
    AHA = { {
      course = {
        { latitude = 22.76543739252,  longitude = 121.10034581861, },
        { latitude = 22.763873637269, longitude = 121.11876126655, },
      },
      area = constants.AREAS.AMMO_HOLDING_AREA_TQG
    } },
    mask = { area = constants.AREAS.MASK_TQG },
  },
  UHE = {
    RL = { {
      course = {
        { latitude = 22.664434036254, longitude = 120.51070402395, },
        { latitude = 22.626929172203, longitude = 120.48724769205, },
        { latitude = 22.609443351559, longitude = 120.52006345119, },
        { latitude = 22.618097711039, longitude = 120.5254764448, },
        { latitude = 22.643786792107, longitude = 120.51424801616, },
      },
      area = constants.AREAS.RELOAD_POINT_UHE
    } },
    HA = { {
      course = {
        { latitude = 22.643786792107, longitude = 120.51424801616, },
        { latitude = 22.636353805408, longitude = 120.52654706757, },
      },
      area = constants.AREAS.HIDE_AREA_UHE
    } },
    FP = {
      {
        course = {
          { latitude = 22.636353805408, longitude = 120.52654706757, },
          { latitude = 22.618097711039, longitude = 120.5254764448, },
          { latitude = 22.609443351559, longitude = 120.52006345119, },
          { latitude = 22.626929172203, longitude = 120.48724769205, },
          { latitude = 22.664434036254, longitude = 120.51070402395, },
          { latitude = 22.6616816771,   longitude = 120.46793555836, },
        },
        area = constants.AREAS.FIRE_POINT_UHE_1
      },
      {
        course = {
          { latitude = 22.636353805408, longitude = 120.52654706757, },
          { latitude = 22.638289171084, longitude = 120.53811183835, },
          { latitude = 22.646943442123, longitude = 120.54352575511, },
          { latitude = 22.664434036254, longitude = 120.51070402395, },
          { latitude = 22.67257745647,  longitude = 120.47710274545, },
        },
        area = constants.AREAS.FIRE_POINT_UHE_2
      },
    },
    AHA = { {
      course = {
        { latitude = 22.643786792107, longitude = 120.51424801616, },
        { latitude = 22.627667705883, longitude = 120.51771271256, },
      },
      area = constants.AREAS.AMMO_HOLDING_AREA_UHE
    } },
    mask = { area = constants.AREAS.MASK_UHE },
  },
  UMA = {
    RL = { {
      course = {
        { latitude = 24.995547373593, longitude = 121.07709949398, },
        { latitude = 24.969153390257, longitude = 121.1024184927, },
        { latitude = 24.975709396492, longitude = 121.11073848518, },
        { latitude = 24.994951384876, longitude = 121.12147435624, },
      },
      area = constants.AREAS.RELOAD_POINT_UMA
    } },
    HA = { {
      course = {
        { latitude = 24.994951384876, longitude = 121.12147435624, },
        { latitude = 25.001554313253, longitude = 121.10998352894, },
      },
      area = constants.AREAS.HIDE_AREA_UMA
    } },
    FP = {
      {
        course = {
          { latitude = 25.001554313253, longitude = 121.10998352894, },
          { latitude = 24.975709396492, longitude = 121.11073848518, },
          { latitude = 24.969153390257, longitude = 121.1024184927, },
          { latitude = 24.995547373593, longitude = 121.07709949398, },
          { latitude = 25.025042579961, longitude = 121.06291644511, },
        },
        area = constants.AREAS.FIRE_POINT_UMA_1
      },
      {
        course = {
          { latitude = 25.001554313253, longitude = 121.10998352894, },
          { latitude = 24.999294966571, longitude = 121.12180632219, },
          { latitude = 24.994646321858, longitude = 121.12624210815, },
          { latitude = 24.991004335657, longitude = 121.1301559868, },
          { latitude = 24.997560405266, longitude = 121.1384771806, },
          { latitude = 25.023960491121, longitude = 121.11316007446, },
          { latitude = 25.045541759319, longitude = 121.09701479366, },
        },
        area = constants.AREAS.FIRE_POINT_UMA_2
      },
    },
    AHA = { {
      course = {
        { latitude = 24.994951384876, longitude = 121.12147435624, },
        { latitude = 24.98414158538,  longitude = 121.10747690962, },
      },
      area = constants.AREAS.AMMO_HOLDING_AREA_UMA
    } },
    mask = { area = constants.AREAS.MASK_UMA },
  },
  VAJ = {
    RL = { {
      course = {
        { latitude = 25.049777176127, longitude = 121.17667591466, },
        { latitude = 25.023377086681, longitude = 121.20199834197, },
        { latitude = 25.01682101719,  longitude = 121.19367539916, },
        { latitude = 25.010136353017, longitude = 121.17328539091, },
      },
      area = constants.AREAS.RELOAD_POINT_VAJ
    } },
    HA = { {
      course = {
        { latitude = 25.010136353017, longitude = 121.17328539091, },
        { latitude = 25.027547246497, longitude = 121.17539916292, },
      },
      area = constants.AREAS.HIDE_AREA_VAJ
    } },
    FP = {
      {
        course = {
          { latitude = 25.027547246497, longitude = 121.17539916292, },
          { latitude = 25.01682101719,  longitude = 121.19367539916, },
          { latitude = 25.023377086681, longitude = 121.20199834197, },
          { latitude = 25.049777176127, longitude = 121.17667591466, },
          { latitude = 25.072239143398, longitude = 121.16783402393, },
        },
        area = constants.AREAS.FIRE_POINT_VAJ_1
      },
      {
        course = {
          { latitude = 25.027547246497, longitude = 121.17539916292, },
          { latitude = 25.014479936662, longitude = 121.17361732985, },
          { latitude = 25.009831261236, longitude = 121.17805320238, },
          { latitude = 25.001526081306, longitude = 121.17425381459, },
          { latitude = 24.994970075263, longitude = 121.16593207476, },
          { latitude = 25.021364055009, longitude = 121.14060775225, },
          { latitude = 25.046888027164, longitude = 121.12371216191, },
        },
        area = constants.AREAS.FIRE_POINT_VAJ_2
      },
    },
    AHA = { {
      course = {
        { latitude = 25.010136353017, longitude = 121.17328539091, },
        { latitude = 25.017733420495, longitude = 121.16281570787, },
      },
      area = constants.AREAS.AMMO_HOLDING_AREA_VAJ
    } },
    mask = { area = constants.AREAS.MASK_VAJ },
  },
  XTV = {
    RL = { {
      course = {
        { latitude = 23.002691454306, longitude = 120.19889663431, },
        { latitude = 23.002691454306, longitude = 120.23689438132, },
        { latitude = 23.012684818209, longitude = 120.23689456004, },
        { latitude = 23.018455299909, longitude = 120.22931907857, },
      },
      area = constants.AREAS.RELOAD_POINT_XTV
    } },
    HA = { {
      course = {
        { latitude = 23.018455299909, longitude = 120.22931907857, },
        { latitude = 23.030734954812, longitude = 120.22592008365, },
      },
      area = constants.AREAS.HIDE_AREA_XTV
    } },
    FP = {
      {
        course = {
          { latitude = 23.030734954812, longitude = 120.22592008365, },
          { latitude = 23.012684818209, longitude = 120.23689456004, },
          { latitude = 23.002691454306, longitude = 120.23689438132, },
          { latitude = 23.002691454306, longitude = 120.19889663431, },
          { latitude = 23.014646664765, longitude = 120.16432560268, },
        },
        area = constants.AREAS.FIRE_POINT_XTV_1
      },
      {
        course = {
          { latitude = 23.030734954812, longitude = 120.22592008365, },
          { latitude = 23.036002426509, longitude = 120.23690030569, },
          { latitude = 23.045995584655, longitude = 120.23690048468, },
          { latitude = 23.045995584655, longitude = 120.19889053095, },
          { latitude = 23.002691454306, longitude = 120.19889663431, },
          { latitude = 23.028348770782, longitude = 120.16345991119, },
        },
        area = constants.AREAS.FIRE_POINT_XTV_2
      },
    },
    AHA = { {
      course = {
        { latitude = 23.018455299909, longitude = 120.22931907857, },
        { latitude = 23.017261201508, longitude = 120.21663493722, },
      },
      area = constants.AREAS.AMMO_HOLDING_AREA_XTV
    } },
    mask = { area = constants.AREAS.MASK_XTV },
  },
  YUR = {
    RL = { {
      course = {
        { latitude = 24.012189526768, longitude = 121.56346988392, },
        { latitude = 24.006911369076, longitude = 121.61052222423, },
        { latitude = 23.972196376996, longitude = 121.60585031533, },
        { latitude = 23.973414087625, longitude = 121.5949952117, },
        { latitude = 23.996531871249, longitude = 121.58178046692, },
      },
      area = constants.AREAS.RELOAD_POINT_YUR
    } },
    HA = { {
      course = {
        { latitude = 23.996531871249, longitude = 121.58178046692, },
        { latitude = 23.986882102976, longitude = 121.59389581867, },
      },
      area = constants.AREAS.HIDE_AREA_YUR
    } },
    FP = {
      {
        course = {
          { latitude = 23.986882102976, longitude = 121.59389581867, },
          { latitude = 23.973414087625, longitude = 121.5949952117, },
          { latitude = 23.972196376996, longitude = 121.60585031533, },
          { latitude = 24.006911369076, longitude = 121.61052222423, },
          { latitude = 24.012189526768, longitude = 121.56346988392, },
          { latitude = 24.041348800122, longitude = 121.59446981764, },
        },
        area = constants.AREAS.FIRE_POINT_YUR_1
      },
      {
        course = {
          { latitude = 23.986882102976, longitude = 121.59389581867, },
          { latitude = 23.973414087625, longitude = 121.5949952117, },
          { latitude = 23.972196376996, longitude = 121.60585031533, },
          { latitude = 24.006911369076, longitude = 121.61052222423, },
          { latitude = 24.023571076243, longitude = 121.62716895537, },
        },
        area = constants.AREAS.FIRE_POINT_YUR_2
      },
    },
    AHA = { {
      course = {
        { latitude = 23.996531871249, longitude = 121.58178046692, },
        { latitude = 23.984656051992, longitude = 121.57694047496, },
      },
      area = constants.AREAS.AMMO_HOLDING_AREA_YUR
    } },
    mask = { area = constants.AREAS.MASK_YUR },
  },
  ZJL = {
    RL = { {
      course = {
        { latitude = 22.900177908135, longitude = 120.22672016701, },
        { latitude = 22.900177908135, longitude = 120.26468913475, },
        { latitude = 22.910171271526, longitude = 120.26468931245, },
        { latitude = 22.913381907687, longitude = 120.2587726682, },
      },
      area = constants.AREAS.RELOAD_POINT_ZJL
    } },
    HA = { {
      course = {
        { latitude = 22.913381907687, longitude = 120.2587726682, },
        { latitude = 22.912739467852, longitude = 120.24604272991, },
      },
      area = constants.AREAS.HIDE_AREA_ZJL
    } },
    FP = {
      {
        course = {
          { latitude = 22.912739467852, longitude = 120.24604272991, },
          { latitude = 22.910307784165, longitude = 120.2554130983, },
          { latitude = 22.910307784165, longitude = 120.26213223809, },
          { latitude = 22.910171271526, longitude = 120.26468931245, },
          { latitude = 22.900177908135, longitude = 120.26468913475, },
          { latitude = 22.900177908135, longitude = 120.22672016701, },
          { latitude = 22.911197999232, longitude = 120.19234731039, },
        },
        area = constants.AREAS.FIRE_POINT_ZJL_1
      },
      {
        course = {
          { latitude = 22.912739467852, longitude = 120.24604272991, },
          { latitude = 22.910307784165, longitude = 120.2554130983, },
          { latitude = 22.910307784165, longitude = 120.26213223809, },
          { latitude = 22.910171271526, longitude = 120.26468931245, },
          { latitude = 22.900177908135, longitude = 120.26468913475, },
          { latitude = 22.900177908135, longitude = 120.22672016701, },
          { latitude = 22.887146824014, longitude = 120.20639982702, },
        },
        area = constants.AREAS.FIRE_POINT_ZJL_2
      },
    },
    AHA = { {
      course = {
        { latitude = 22.913381907687, longitude = 120.2587726682, },
        { latitude = 22.927264141908, longitude = 120.24945558721, },
      },
      area = constants.AREAS.AMMO_HOLDING_AREA_ZJL
    } },
    mask = { area = constants.AREAS.MASK_ZJL },
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

constants.ZONE_TYPES = {
  NON_NAVIGATION = 0,
  EXCLUSION = 1,
  CUSTOM_ENVIRONMENT = 2,
  STANDARD = -925,
}

constants.POSITION_TYPES = {
  FIRING_POINT = "FP",
  HIDE_AREA = "HA",
  AMMO_HOLDING_AREA = "AHA",
  RELOAD_POINT = "RL",
  MASK = "MASK"
}
---@enum missileSystemState
constants.MISSILE_SYSTEM_STATE = {
  STATIC = 0,
  REPOSITIONING = 1,
  RELOAD = 2,
  HIDE = 3,
}

constants.UNIT_CONDITIONS = {
  AIRBORNE = "Airborne",
}

constants.PLATFORM_TYPES = {
  AIRCRAFT = "Aircraft",
  BOATS    = "Boats",
}

constants.CONTACT_TYPES = {
  AIR = 0,
  SURFACE = 2,
  FACILITY_MOBILE = 8
}

constants.SIDES = {
  ENEMY = "China",
  PLAYER = "Taiwan"
}

constants.AMPHIBIOUS_PHASES = {
  MOVING              = "MOVING",
  WAITING_ARRIVAL     = "WAITING_ARRIVAL",
  WAITING_ASSAULT     = "WAITING_ASSAULT",
  WAITING_SECOND_WAVE = "WAITING_SECOND_WAVE",
  COMPLETED           = "COMPLETED",
}

constants.SENSOR_ARCS = { "PB1", "PB2", "SB1", "SB2", "SMF1", "PMF2" }
constants.TIME_FORMATS = "!yyyy-MM-dd HH:mm:ss"
constants.MOUNT_DESCRIPTORS = {
  CUSTOMED_TK3 = { { dbid = 1630, mountCount = 1 }, { dbid = 45, mountCount = 6 } },
  HF2E = { { dbid = 2782, mountCount = 2 } },
  CSS5_MOD5 = { { dbid = 1858, mountCount = 4 } },
  CSS11_MOD1 = { { dbid = 4274, mountCount = 4 } },
  CSS6_MOD3 = { { dbid = 1882, mountCount = 6 } },
  CSS6_MOD2 = { { dbid = 4272, mountCount = 6 } },
  CSS7_MOD2 = { { dbid = 4263, mountCount = 6 } },
  CH_SSC_9 = { { dbid = 4276, mountCount = 8 } }
}

return constants
