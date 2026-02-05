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
    [25.296, 121.581],
    [25.194, 121.41],
    [25.123, 121.255],
    [25.045, 121.053],
    [24.869, 120.941],
    [24.713, 120.884],
    [24.614, 120.729],
    [24.196, 120.476],
    [23.886, 120.3],
    [23.736, 120.187],
    [23.38, 120.146],
    [23.144, 120.088],
    [22.509, 120.371],
    [22.362, 120.6],
    [21.985, 120.755],
    [22.043, 120.902],
    [22.341, 120.871],
    [22.792, 121.115],
    [23.209, 121.376],
    [23.945, 121.604],
    [24.136, 121.619],
    [24.607, 121.869],
    [24.849, 121.79],
    [24.994, 121.933],
    [25.141, 121.707],
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
