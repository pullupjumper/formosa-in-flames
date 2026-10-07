import L from 'leaflet';
import { renderToStaticMarkup } from 'react-dom/server';
import {
  AmmunitionTransferPointIcon,
  AmphibiousIcon,
  ArmoredMechanizedTrackedIcon,
  CarrierIcon,
  CommandAndControlIcon,
  ElectronicWarfareIcon,
  EnemyCommandAndControlIcon,
  EnemySamIcon,
  FieldArtilleryIcon,
  SamIcon,
  SelfPropelledIcon,
  SsmIcon,
  MainGunSystemIcon,
  NavyTaskForceIcon,
} from '@/components/icons';
import type { ForceImage } from '@/types/controlPanel';

// ============================================================================
// BATTERY ICONS — NATO symbols shared by the map markers and the sidebar cards
// ============================================================================
export const ICON_IMAGES: Record<string, ForceImage> = {
  sam: { Icon: SamIcon, label: 'SAM', width: 25, height: 15 },
  ssm: { Icon: SsmIcon, label: 'SSM', width: 25, height: 15 },
  atp: { Icon: AmmunitionTransferPointIcon, label: 'ATP', width: 25 * 1.5, height: 15 * 1.5 },
  c2: { Icon: CommandAndControlIcon, label: 'C2', width: 25, height: 15 },
  suspectedC2: { Icon: EnemyCommandAndControlIcon, label: 'Suspected C2', width: 25, height: 15 },
  ew: { Icon: ElectronicWarfareIcon, label: 'EW', width: 25, height: 15 },
  taskForce: { Icon: NavyTaskForceIcon, label: 'Task Force', width: 48, height: 32 },
  carrier: { Icon: CarrierIcon, label: 'Carrier', width: 48, height: 32 },
};

const LANDING_UNIT_ICON_SIZE = { width: 20, height: 20 };
const LANDING_UNIT_IMAGES: Record<string, ForceImage> = {
  'ZBD-05': { Icon: ArmoredMechanizedTrackedIcon, label: 'ZBD-05', ...LANDING_UNIT_ICON_SIZE },
  'ZTD-05': { Icon: AmphibiousIcon, label: 'ZTD-05', ...LANDING_UNIT_ICON_SIZE },
  'PLL-05': { Icon: FieldArtilleryIcon, label: 'PLL-05', ...LANDING_UNIT_ICON_SIZE },
  'PLZ-96': { Icon: SelfPropelledIcon, label: 'PLZ-96', ...LANDING_UNIT_ICON_SIZE },
  'PGZ-09': { Icon: MainGunSystemIcon, label: 'PGZ-09', ...LANDING_UNIT_ICON_SIZE },
  'PGZ-95': { Icon: MainGunSystemIcon, label: 'PGZ-95', ...LANDING_UNIT_ICON_SIZE },
  'SA-15': { Icon: EnemySamIcon, label: 'SA-15', ...LANDING_UNIT_ICON_SIZE },
};

/** Symbol for a landed unit type, or undefined when the type has none */
export function getLandingUnitImage(unitType: string): ForceImage | undefined {
  return LANDING_UNIT_IMAGES[unitType];
}

export const AIRBASE_ICON_URL = 'https://i.meee.com.tw/5afNBSQ.png';
export const AIRBASE_ICON_SIZE = { width: 16, height: 16 };

/** Symbol for a battery's missile system type: SAM gets its own, everything else is SSM */
export function getBatteryImage(missileSystemType: string): ForceImage {
  return missileSystemType === 'sam' ? ICON_IMAGES.sam : ICON_IMAGES.ssm;
}

/** divIcon rendering a symbol at the image's size */
export function createImageIcon(image: ForceImage): L.DivIcon {
  const markup = renderToStaticMarkup(
    <image.Icon width="100%" height="100%" style={{ objectFit: 'contain' }} />
  );

  return L.divIcon({
    className: '',
    html: `<div style="width:${image.width}px;height:${image.height}px">${markup}</div>`,
    iconSize: [image.width, image.height],
    iconAnchor: [image.width / 2, image.height / 2],
  });
}
