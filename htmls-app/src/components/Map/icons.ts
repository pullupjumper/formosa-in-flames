import L from 'leaflet';
import type { ForceImage } from '@/types/setupMenu';

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
