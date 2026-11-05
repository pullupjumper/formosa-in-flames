import type { AreaType } from '@/types/deployment';

/**
 * One row per tactical area type. Adding an area means adding it to `AreaType`
 * and to this table; nothing else has to change.
 */
export const AREA_INFO: Record<AreaType, { label: string; color: string }> = {
  ushape: { label: 'U-Shape', color: '#ff6b6b' },
  atp: { label: 'ATP', color: '#ffd93d' },
  hide: { label: 'Hide Area', color: '#6bcb77' },
  reload: { label: 'Reload Area', color: '#4d96ff' },
  fp: { label: 'Fire Point', color: '#ff922b' },
};

export function getAreaLabel(type: AreaType): string {
  return AREA_INFO[type].label;
}

export function getAreaColor(type: AreaType): string {
  return AREA_INFO[type].color;
}
