// Control Panel constants (tuning values and static geometry). Types live in
// `types/controlPanel.ts`; this file holds runtime values only.

export const CONFIG = {
  LOADOUT_COST: 100,
  INITIAL_SCORE: 1000,
  WEAPON_NAMES: {
    srbm: 'SRBM (ATACMS/162 NM)',
    ascm: 'ASCM (Hsiung Feng III/100 NM)',
    mlrs: 'MLRS (MK-45/20 NM)',
    glcm: 'GLCM (Hsiung Feng IIE/324 NM)',
    sam: 'SAM (Long-Range Air Defense/108 NM)',
    mrbm: 'MRBM (DF-21D/810 NM)',
  } as Record<string, string>,
};
