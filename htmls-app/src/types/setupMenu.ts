// Setup Menu Types

export interface Loadout {
  num: number;
  loadoutId: number;
  name: string;
  missionName?: string;
}

export interface EmbarkedUnit {
  dbid: number;
  platformName: string;
  type: string;
  side: string;
  name: string;
  loadouts?: Loadout[];
}

export interface Airbase {
  name: string;
  longitude: number;
  latitude: number;
  baseGUID: string;
  embarkedUnits?: EmbarkedUnit[];
  loadouts?: Loadout[];
}

export interface Jammer {
  zoneName: string;
  name: string;
  randomRadius: number;
  radius: number;
  point?: {
    latitude: number;
    longitude: number;
  };
}

export interface CoursePoint {
  desiredSpeed: number;
  presetThrottle: string;
  latitude: number | string;
  longitude: number | string;
}

export interface AreaDefinition {
  course: CoursePoint[];
  area: string[];
}

export interface OperationalArea {
  RL: AreaDefinition[];
  FP: AreaDefinition[];
  AHA: AreaDefinition[];
  HA: AreaDefinition[];
}

export interface FiringUnit {
  dbid: number;
  resupplyUnit: string;
  guid: string;
  ammoThreshold: number;
  weaponDBID: number;
  name: string;
  operationalArea: OperationalArea;
  state: number;
  msg: string;
}

export interface ResupplyUnit {
  unitCount: number;
  wpnCurrent: number;
  ammunition: string;
  wpnDefault: number;
  name: string;
  state: number;
  guid: string;
  operationalArea: OperationalArea;
}

export interface Ammunition {
  name: string;
  wpnCurrent: number;
  guid: string;
  wpnDefault: number;
}

export interface MissileSystemCategory {
  operationalAreas: Record<string, OperationalArea>;
  reloadTime: number;
  wpnDefault: number;
  firingUnits: Record<string, FiringUnit>;
  resupplyUnits: Record<string, ResupplyUnit>;
  ammoThreshold: number;
  ammunitions: Record<string, Ammunition>;
}

export type MissileSystems = Record<string, MissileSystemCategory>;

export interface SetupMenuData {
  airbases: Airbase[];
  jammers: Jammer[];
  missileSystems: MissileSystems;
}

// State types
export interface BudgetState {
  current: number;
  used: number;
  total: number;
}

export interface DeployedJammer {
  index: number;
  center: { lat: number; lng: number };
}

export interface TacticalAreas {
  uShapeVertices: { latitude: number; longitude: number }[];
  ammoArea?: { latitude: number; longitude: number }[];
  hideArea?: { latitude: number; longitude: number }[];
  reloadArea?: { latitude: number; longitude: number }[];
  firePoints?: { latitude: number; longitude: number }[][];
}

export interface MovementPaths {
  FP: { waypoints: { latitude: number; longitude: number }[] }[];
  HA: { waypoints: { latitude: number; longitude: number }[] };
  RL: { waypoints: { latitude: number; longitude: number }[] }[];
  AHA: { waypoints: { latitude: number; longitude: number }[] };
}

export interface DeployedMissileSystemData {
  unitName: string;
  category: string;
  center: { lat: number; lng: number };
  openingAngle: number;
  ahaRadius: number;
  tacticalAreas: TacticalAreas;
  paths: MovementPaths;
}

export interface DeployedMissileSystem {
  unitKey: string;
  unitName: string;
  category: string;
  center: { lat: number; lng: number };
  openingAngle: number;
}

export type TabId = 'aircraft' | 'jammers' | 'missileSystems' | 'summary';

// Config constants
export const CONFIG = {
  LOADOUT_COST: 100,
  INITIAL_SCORE: 1000,
  WEAPON_RANGES: {
    srbm: 162,
    ascm: 100,
    mlrs: 20,
    glcm: 324,
  } as Record<string, number>,
  WEAPON_NAMES: {
    srbm: 'SRBM (ATACMS/162 NM)',
    ascm: 'ASCM (Hsiung Feng III/100 NM)',
    mlrs: 'MLRS (MK-45/20 NM)',
    glcm: 'GLCM (Hsiung Feng IIE/324 NM)',
  } as Record<string, string>,
  TAIWAN_BOUNDARY: [
    [21.90068036814239, 120.86291912742053],
    [21.944454401817154, 120.83834934398652],
    [21.989119397390652, 120.84916154607953],
    [22.033768404185366, 120.90125313812712],
    [22.142120317665714, 120.89437528643123],
    [22.296532821839534, 120.89339003932116],
    [22.35465486417887, 120.90518291725476],
    [22.46498643034853, 120.94815914889011],
    [22.563561357962726, 120.98255568144697],
    [22.595089235713914, 121.01341626236871],
    [22.623863479985744, 121.01518558350699],
    [22.670200604285228, 121.03705151965966],
    [22.701752107594288, 121.10256256556767],
    [22.736517396862737, 121.15236327853512],
    [22.76614668521802, 121.18356428222842],
    [22.79739151821316, 121.20220881977008],
    [22.865742187511984, 121.23543249542996],
    [22.97401413502149, 121.312164698934],
    [23.098269994230208, 121.38544951476047],
    [23.12523896725682, 121.41903667479119],
    [23.17091713211805, 121.40842986763141],
    [23.329804790069716, 121.472924120134],
    [23.682043655457974, 121.56174552567222],
    [23.910531269754046, 121.6116380913412],
    [23.964857408517645, 121.61921662734983],
    [24.008937439238778, 121.64927476570244],
    [24.064168287213036, 121.61719850709522],
    [24.13109083965078, 121.66505726016999],
    [24.245732033967826, 121.72701372214215],
    [24.307420017699187, 121.77615002510885],
    [24.453533956345723, 121.82353378613527],
    [24.488516721586706, 121.86707031291792],
    [24.532261655385355, 121.87621699102567],
    [24.60596068038204, 121.88498707664161],
    [24.71656871721946, 121.84126148752682],
    [24.837018482555763, 121.83369175538974],
    [24.955329431785444, 121.92670934018321],
    [25.005126565082392, 122.01533191080574],
    [25.028981527043513, 121.9956216660143],
    [25.12833982039467, 121.9222019842095],
    [25.162738410934736, 121.78085868092967],
    [25.176582089213298, 121.70989177397342],
    [25.211688609788297, 121.70023917719175],
    [25.23452867530382, 121.65017959446351],
    [25.274683548708097, 121.6250698593987],
    [25.301842736933438, 121.57630772959033],
    [25.300662601322287, 121.53452538268351],
    [25.289647914985025, 121.50491006867713],
    [25.266818714082106, 121.47664566082375],
    [25.250741922136783, 121.45102102024396],
    [25.226561267572706, 121.43895756121066],
    [25.186535895778846, 121.40338055300111],
    [25.15927387800116, 121.34420020789935],
    [25.12970342663516, 121.30570540125683],
    [25.12353791435264, 121.23985976438541],
    [25.066463261161246, 121.0965889963519],
    [25.04127686822919, 121.04472110656138],
    [24.950847394936304, 120.99119111794704],
    [24.91665375168384, 120.96210692856931],
    [24.844090384315578, 120.91385006270957],
    [24.814435357557002, 120.90042818461558],
    [24.71155451111389, 120.85338991184841],
    [24.665196804200306, 120.78050101015856],
    [24.606419962347175, 120.72019513610684],
    [24.480059400628008, 120.65405030282324],
    [24.40575415139847, 120.58915436548273],
    [24.310673632163102, 120.51735175360369],
    [24.215347783881853, 120.45253391200623],
    [24.117377756406057, 120.3902294063771],
    [24.05480338613873, 120.35628393084903],
    [23.971485520035657, 120.31927032948988],
    [23.92960128889247, 120.29545090581996],
    [23.861298197284526, 120.24718919824716],
    [23.807479959973534, 120.17381498637451],
    [23.75987726146643, 120.1551649200195],
    [23.718130015818687, 120.14987726439966],
    [23.64004724186266, 120.13798340447039],
    [23.525309157523708, 120.11815135661249],
    [23.45074752635567, 120.11682944293693],
    [23.390037406464714, 120.12871083394083],
    [23.325710437452997, 120.10623573816764],
    [23.291713796089212, 120.09103199691054],
    [23.18427058284773, 120.06260605862292],
    [23.102820169307677, 120.02889315955781],
    [23.05269687661125, 120.03317417445675],
    [23.03810164375834, 120.04506994125586],
    [23.021072206163026, 120.09265336644506],
    [22.96753598701872, 120.14882735748716],
    [22.847196200167062, 120.18715711247432],
    [22.74964374152698, 120.21888031170062],
    [22.68380600155008, 120.25258498429463],
    [22.652778654949515, 120.24320314646474],
    [22.581185036683067, 120.26976544685238],
    [22.54456781843794, 120.2796808975624],
    [22.5073300554255, 120.31074206642376],
    [22.514045803587194, 120.32990746848782],
    [22.43221367197252, 120.4677576320509],
    [22.370502156668763, 120.57415884979616],
    [22.338107980720892, 120.59530687965986],
    [22.31047956806212, 120.62570717258978],
    [22.25850065113916, 120.64090731905486],
    [22.201004697161537, 120.67722495315985],
    [22.13062168450007, 120.69640306302955],
    [22.096323490561815, 120.70962308215485],
    [22.080403324198286, 120.69047301404436],
    [22.042442576247666, 120.68383230044367],
    [22.009354247976063, 120.67922827733372],
    [21.96959392939435, 120.704929068681],
    [21.92967137702783, 120.70765578831305],
    [21.90882591585064, 120.72616031444392],
    [21.918647230713987, 120.74861950719207],
    [21.946847377020788, 120.75918783978602],
    [21.93396271072976, 120.78960440402886],
    [21.92047522622893, 120.82066557289022],
    [21.90271395957103, 120.84244320818243],
    [21.900482473095877, 120.86308989985633],
  ] as [number, number][],
  COLORS: {
    USHAPE: '#ff6b6b',
    AMMO_AREA: '#0f9960',
    HIDE_AREA: '#137cbd',
    RELOAD_AREA: '#d9822b',
    FIRE_POINT: '#8b5cf6',
    WEAPON_RANGE: '#ff4444',
  },
};
