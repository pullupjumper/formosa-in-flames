import L from 'leaflet';
import type { ForceImage } from '@/types/controlPanel';

// ============================================================================
// LAUNCHER ICONS — NATO symbols shared by the map markers and the sidebar cards
// ============================================================================
const MISSILE_ICON_URL = 'https://i.meee.com.tw/suDq81b.png';
const SAM_ICON_URL = 'https://i.meee.com.tw/PCUEceO.png';
const ATP_ICON_URL = 'https://i.meee.com.tw/t9aLh0K.png';
const MSL_ICON_URL = 'https://i.meee.com.tw/lrsJGwE.png';
const C2_ICON_URL = 'https://i.meee.com.tw/NDFQE1m.png';
const SUSPECTED_C2_ICON_URL = 'https://i.meee.com.tw/RF2KySM.png';
export const ICON_IMAGES: Record<string, ForceImage> = {
  sam: { url: SAM_ICON_URL, label: 'SAM', width: 25, height: 15 },
  ssm: { url: MISSILE_ICON_URL, label: 'SSM', width: 25, height: 15 },
  atp: { url: ATP_ICON_URL, label: 'ATP', width: 25 * 1.5, height: 15 * 1.5 },
  msl: { url: MSL_ICON_URL, label: 'MSL', width: 25 * 1.3, height: 15 * 1.3 },
  c2: { url: C2_ICON_URL, label: 'C2', width: 25, height: 15 },
  suspectedC2: { url: SUSPECTED_C2_ICON_URL, label: 'Suspected C2', width: 25, height: 15 },
};

export const AIRBASE_ICON_URL = 'https://i.meee.com.tw/5afNBSQ.png';
export const AIRBASE_ICON_SIZE = { width: 16, height: 16 };
export const EW_ICON_URL = 'https://i.meee.com.tw/LO1UNjw.png';
export const EW_ICON_SIZE = { width: 25, height: 15 };

/** Symbol for a launcher's weapon category: SAM gets its own, everything else is SSM */
export function getLauncherImage(category: string): ForceImage {
  return category === 'sam' ? ICON_IMAGES.sam : ICON_IMAGES.ssm;
}

/** divIcon showing an image, or a dashed placeholder box of the same size */
export function createImageIcon(image: ForceImage): L.DivIcon {
  const inner = image.url
    ? `<img src="${image.url}" alt="${image.label}" style="width:100%;height:100%;object-fit:contain" />`
    : `<div style="display:flex;align-items:center;justify-content:center;width:100%;height:100%;
       border:1px dashed #137cbd;background:rgba(19,124,189,0.12);color:#a7b6c2;
       font-size:10px;letter-spacing:1px;text-align:center">${image.label}<br/>IMAGE</div>`;

  return L.divIcon({
    className: '',
    html: `<div style="width:${image.width}px;height:${image.height}px">${inner}</div>`,
    iconSize: [image.width, image.height],
    iconAnchor: [image.width / 2, image.height / 2],
  });
}
