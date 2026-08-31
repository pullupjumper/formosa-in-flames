import { useMemo } from 'react';
import { LayersControl, MapContainer, Marker, Polyline, Circle, TileLayer } from 'react-leaflet';
import L from 'leaflet';
import type { LatLngExpression, LatLngTuple } from 'leaflet';
import 'leaflet/dist/leaflet.css';
import '@components/Map/leaflet-dark.css';
import type { AmphibiousLocation, ForceImage } from '@/types/setupMenu';

// ============================================================================
// FORCE IMAGERY SLOTS
// Reserved space for amphibious task force / carrier strike group imagery.
// Drop a URL (or an injected data URI) in here and the map marker renders it;
// until then a dashed placeholder box of the same size holds the layout.
// ============================================================================

interface OpordTabProps {
  amphibiousLocations: AmphibiousLocation[];
}

const AMPHIBIOUS_IMAGE_URL = 'https://i.meee.com.tw/k9bABdK.png';
const CARRIER_IMAGE_URL = 'https://i.meee.com.tw/KaFhzmY.png';

const FORCE_IMAGES: Record<'atf1' | 'atf2' | 'csg', ForceImage> = {
  atf1: { url: AMPHIBIOUS_IMAGE_URL, label: 'ATF-1', width: 48, height: 32 },
  atf2: { url: AMPHIBIOUS_IMAGE_URL, label: 'ATF-2', width: 48, height: 32 },
  csg: { url: CARRIER_IMAGE_URL, label: 'CSG', width: 48, height: 32 },
};

/**
 * Build a Leaflet divIcon that either shows the force image or a placeholder
 * box occupying the exact same footprint.
 */
function createForceIcon(image: ForceImage): L.DivIcon {
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

/**
 * Return a copy of the route whose staging point is replaced by the runtime
 * position of the matching amphibious operation. Falls back to the static
 * route when the operation is absent from the injected data.
 */
function resolveAmphibiousRoute(locations: AmphibiousLocation[], name: string): LatLngTuple[] {
  const match = locations.find((location) => location.name === name);
  if (!match) return [];
  return match.waypoints.map((waypoint) => [waypoint.latitude, waypoint.longitude]);
}

// ============================================================================
// MAP DATA
// ============================================================================
// Fig 1 frames Taiwan only; Fig 2 must also cover Zhoushan (30.1N) and the
// Bashi Channel (21.0N), so it uses a wider, northward-shifted view.
const MAP_CENTER: LatLngExpression = [24.5, 120.5];
const MAP_ZOOM = 7;
const THREAT_MAP_CENTER: LatLngExpression = [25.5, 121.0];
const THREAT_MAP_ZOOM = 5;

const CSG_ROUTE: LatLngTuple[] = [
  [21.0, 122.0], // Bashi Channel entry
  [23.5, 121.5], // Eastern Taiwan waters
];

// ============================================================================
// MAIN COMPONENT
// ============================================================================
export function OpordTab({ amphibiousLocations }: OpordTabProps) {
  const icons = useMemo(
    () => ({
      atf1: createForceIcon(FORCE_IMAGES.atf1),
      atf2: createForceIcon(FORCE_IMAGES.atf2),
      csg: createForceIcon(FORCE_IMAGES.csg),
    }),
    []
  );

  const routes = useMemo(
    () => ({
      atf1: resolveAmphibiousRoute(amphibiousLocations, 'Taoyuan'),
      atf2: resolveAmphibiousRoute(amphibiousLocations, 'Sishu'),
      atf3: resolveAmphibiousRoute(amphibiousLocations, 'Penghu'),
    }),
    [amphibiousLocations]
  );

  return (
    <div className="h-full overflow-y-auto">
      <div className="mx-auto max-w-260 p-8">
        <Classification />

        {/* Header */}
        <header className="border-x border-dark-border bg-dark-panel px-5 py-5 text-center">
          <h1 className="mb-2.5 text-2xl font-bold underline">(U) OPERATIONS ORDER 26-001</h1>
          <div className="text-sm text-text-secondary">DEFENSE OF TAIWAN</div>
          <div className="text-sm text-text-secondary">TAIWAN DEFENSE COMMAND</div>
          <div className="text-sm text-text-secondary">09JUN27 0200Z</div>
        </header>

        <main className="border-x border-b border-dark-border bg-dark-panel px-5 py-6">
          {/* ---------------------------------------------------------------- */}
          <Section title="(U) 1. SITUATION">
            <Subsection title="1.a. General.">
              <Paragraph>
                China has launched a full-scale invasion of Taiwan. Intelligence indicates three
                simultaneous offensive operations: (1) PLA Navy Carrier Strike Group transits Bashi
                Channel into eastern Taiwan waters; (2) Amphibious Task Force One (Zhoushan-staged)
                proceeds toward Zhuwei/Taoyuan landing zone on the northwestern coast; (3)
                Amphibious Task Force Two (Fujian-staged) proceeds toward Sishu/Tainan landing zone
                on the southwestern coast. Preliminary PLA strikes have begun against airbases,
                command centers, and air defense systems.
              </Paragraph>
            </Subsection>

            <Subsection title="1.b. Area of Operations.">
              <OpordMap>
                <Circle
                  center={routes.atf1[routes.atf1.length - 1]}
                  radius={20000}
                  pathOptions={{
                    color: '#db3737',
                    fillColor: '#db3737',
                    fillOpacity: 0.25,
                    weight: 2,
                  }}
                />
                <Circle
                  center={routes.atf2[routes.atf2.length - 1]}
                  radius={20000}
                  pathOptions={{
                    color: '#db3737',
                    fillColor: '#db3737',
                    fillOpacity: 0.25,
                    weight: 2,
                  }}
                />
                <Circle
                  center={routes.atf3[routes.atf3.length - 1]}
                  radius={20000}
                  pathOptions={{
                    color: '#db3737',
                    fillColor: '#db3737',
                    fillOpacity: 0.25,
                    weight: 2,
                  }}
                />
              </OpordMap>
              <MapCaption>Fig 1. Taiwan and Amphibious Approach Zones</MapCaption>

              <Indent>
                <SubTitle>1.b.1. Primary Landing Zones.</SubTitle>
                <Paragraph>
                  Zhuwei / Taoyuan International Airport (northwestern Taiwan); Sishu / Tainan AB
                  (southwestern Taiwan). Each beach zone supported by forward air defense,
                  helicopter insertion, and sustained logistics landing.
                </Paragraph>
              </Indent>
              <Indent>
                <SubTitle>1.b.2. Carrier Strike Group Approach.</SubTitle>
                <Paragraph>
                  PLA CSG transit Bashi Channel into eastern waters to launch stand-off strikes
                  against Jiashan AB and eastward-facing bases. Terrain shields Jiashan underground
                  hangars from ballistic missile threats.
                </Paragraph>
              </Indent>
            </Subsection>

            <Subsection title="1.c. Enemy Forces.">
              <Indent>
                <SubTitle>1.c.1. Order of Battle.</SubTitle>
                <OrderOfBattleTable />

                <Indent>
                  <SubTitle>1.c.2. Enemy Courses of Action.</SubTitle>
                  <Indent>
                    <SubTitle>1.c.2.a. MLCOA - Overwhelming Saturation.</SubTitle>
                    <Paragraph>
                      Massive preliminary SRBM and GLCM waves suppress air defenses and degrade
                      airfields, followed by fighter dominance and helicopter insertion at both
                      landing zones simultaneously to overwhelm point defenses.
                    </Paragraph>
                  </Indent>
                  <Indent>
                    <SubTitle>1.c.2.b. MDCOA - Sequential Beachheads.</SubTitle>
                    <Paragraph>
                      Establish primary lodgement at Zhuwei / Taoyuan through sustained waves;
                      consolidate before committing second landing at Sishu / Tainan, maximizing air
                      umbrella time at each zone.
                    </Paragraph>
                  </Indent>
                </Indent>
              </Indent>

              <OpordMap center={THREAT_MAP_CENTER} zoom={THREAT_MAP_ZOOM}>
                {/* Carrier Strike Group */}
                <Polyline
                  positions={CSG_ROUTE}
                  pathOptions={{
                    color: '#db3737',
                    weight: 3,
                    opacity: 0.85,
                    dashArray: '10, 5',
                  }}
                />
                <Marker position={CSG_ROUTE[0]} icon={icons.csg} />

                {/* Amphibious Task Force One */}
                <Polyline
                  positions={routes.atf1}
                  pathOptions={{
                    color: '#137cbd',
                    weight: 3,
                    opacity: 0.85,
                    dashArray: '10, 5',
                  }}
                />
                <Marker position={routes.atf1[0]} icon={icons.atf1} />

                {/* Amphibious Task Force Two */}
                <Polyline
                  positions={routes.atf2}
                  pathOptions={{
                    color: '#137cbd',
                    weight: 3,
                    opacity: 0.85,
                    dashArray: '10, 5',
                  }}
                />
                <Marker position={routes.atf2[0]} icon={icons.atf2} />

                {/* Amphibious Task Force Three */}
                <Polyline
                  positions={routes.atf3}
                  pathOptions={{
                    color: '#137cbd',
                    weight: 3,
                    opacity: 0.85,
                    dashArray: '10, 5',
                  }}
                />
                <Marker position={routes.atf3[0]} icon={icons.atf2} />
                {/* Landing zones */}
                <Circle
                  center={routes.atf1[routes.atf1.length - 1]}
                  radius={20000}
                  pathOptions={{ color: '#ffffff', fillOpacity: 0, weight: 2 }}
                />
                <Circle
                  center={routes.atf2[routes.atf2.length - 1]}
                  radius={20000}
                  pathOptions={{ color: '#ffffff', fillOpacity: 0, weight: 2 }}
                />
                <Circle
                  center={routes.atf3[routes.atf3.length - 1]}
                  radius={20000}
                  pathOptions={{ color: '#ffffff', fillOpacity: 0, weight: 2 }}
                />
              </OpordMap>
              <MapCaption>Fig 2. Red Offensive Axes and Landing Zones</MapCaption>
            </Subsection>

            <Subsection title="1.d. Friendly Forces.">
              <Paragraph>
                Taiwan Armed Forces. Forward air defense systems positioned to cover approach
                corridors and landing beaches. Missile units positioned for deep strike against
                enemy staging areas and close-in fires against amphibious forces. Fighter squadrons
                dispersed across 14 main airbases and emergency highway strips. Two GPS jammer
                companies forward-deployed. Submarines in Bashi Channel and eastern waters for
                anti-shipping and anti-submarine operations. No foreign military assistance in
                active combat; US provides signals intelligence via RC-135V collection aircraft.
              </Paragraph>
            </Subsection>

            <Panel>
              <SubTitle>1.e. CCIR.</SubTitle>
              <List>
                <li>
                  PIR: CSG departure from Bashi Channel; primary and secondary landing wave timing
                  and composition; preliminary strike damage assessment; enemy air defense
                  suppression effectiveness.
                </li>
                <li>
                  FFIR: Friendly airfield damage and repair timeline; fighter aircraft serviceable
                  rate; air defense system survivability; missile unit ammunition consumption vs.
                  reload capacity.
                </li>
              </List>
            </Panel>
          </Section>

          {/* ---------------------------------------------------------------- */}
          <Section title="(U) 2. MISSION">
            <div className="my-3.5 border-2 border-accent-blue p-2.5 text-center text-sm font-bold">
              Taiwan Defense Command repels the PLA invasion by denying enemy landing at Zhuwei /
              Taoyuan and Sishu / Tainan; destroys maximum PLA amphibious and air assets; and
              preserves combat capability to sustain multi-domain defense.
            </div>
          </Section>

          {/* ---------------------------------------------------------------- */}
          <Section title="(U) 3. EXECUTION">
            <Subsection title="3.a. Commander's Intent.">
              <Paragraph>
                Purpose: Preserve Taiwan sovereignty; deny PLA any beachhead at battalion strength
                or greater.
              </Paragraph>
              <Paragraph>
                Method: (1) Weather preliminary strikes by dispersing aircraft and hardening air
                defense; (2) Engage amphibious task forces with shore-based anti-ship missiles
                before they close to beaches; (3) Deny PLA air superiority through sustained fighter
                operations; (4) Prosecute ground defense at landing zones with prepared positions
                and concentrated fires.
              </Paragraph>
              <Paragraph>
                End State: Amphibious forces defeated at sea and on beach; fighter and air defense
                capacity preserved to prevent enemy air supremacy; Jiashan AB intact as strategic
                reserve.
              </Paragraph>
            </Subsection>

            <Subsection title="3.b. Concept of Operations.">
              <Indent>
                <SubTitle>Phase 0 - Setup and Hardening.</SubTitle>
                <Paragraph>
                  Position air defense SAM batteries, MLRS, ASCM, SRBM/GLCM units across Taiwan to
                  cover approach corridors and landing zones. Disperse fighters to highway strips
                  and hardened shelters. Position GPS jammers to degrade enemy targeting. Emplace
                  submarine pickets in eastern waters and Bashi Channel.
                </Paragraph>
              </Indent>
              <Indent>
                <SubTitle>Phase 1 - Preliminary Defense.</SubTitle>
                <Paragraph>
                  Engage preliminary enemy air and missile strikes with IADS. Repair damaged runways
                  automatically. Launch fighter CAP and intercept incoming aircraft and cruise
                  missiles. Pre-emptively strike enemy staging areas with SRBM and GLCM.
                </Paragraph>
              </Indent>
              <Indent>
                <SubTitle>Phase 2 - Anti-Ship and Air Dominance.</SubTitle>
                <Paragraph>
                  As amphibious task forces approach, saturate attack with ASCM batteries. Maintain
                  fighter CAP to contest enemy air operations. Launch torpedo attacks from
                  submarines vs. CSG. Concentrate MLRS against landing craft in transit and beach
                  approach.
                </Paragraph>
              </Indent>
              <Indent>
                <SubTitle>Phase 3 - Beachhead Denial.</SubTitle>
                <Paragraph>
                  Ground defense at Zhuwei and Sishu engages landed forces with prepared artillery
                  and infantry positions. Close air support by fighters vs. landing helicopters and
                  inserted troops. MLRS continuous fire against beach assault waves.
                </Paragraph>
              </Indent>
            </Subsection>

            <Subsection title="3.c. Tasks to Subordinate Commands.">
              {TASKS.map((task) => (
                <Indent key={task.title}>
                  <SubTitle>{task.title}</SubTitle>
                  <List>
                    {task.items.map((item) => (
                      <li key={item}>{item}</li>
                    ))}
                  </List>
                </Indent>
              ))}
            </Subsection>

            <Subsection title="3.d. Coordinating Instructions.">
              <Panel>
                <Paragraph>
                  a. Airspace: Combat air patrol zones deconflicted from missile and air defense
                  engagement zones.
                </Paragraph>
                <Paragraph>
                  b. Target Priorities: (1) Amphibious task force ships (ASCM priority); (2) enemy
                  fighter and transport aircraft (fighter CAP priority); (3) enemy staging areas and
                  logistics (SRBM/GLCM priority); (4) landing craft in transit and assault (MLRS/air
                  priority).
                </Paragraph>
                <Paragraph>
                  c. Casualty Report: Real-time battle damage assessment against friendly forces to
                  inform tactical redeployment.
                </Paragraph>
                <Paragraph>
                  d. Runway Repair: Damaged airfield runways automatically regenerate at ~3% per
                  hour, so continuous operations are sustainable.
                </Paragraph>
              </Panel>
            </Subsection>
          </Section>

          {/* ---------------------------------------------------------------- */}
          <Section title="(U) 4. SUSTAINMENT">
            <Subsection title="4.a. Ammunition and Fuel.">
              <Paragraph>
                Pre-positioned stocks at all airbases and missile unit positions. No external
                resupply available. Ammunition consumption must be managed for sustained firing
                tempo. Fuel stocks sufficient for multi-hour air operations.
              </Paragraph>
            </Subsection>
            <Subsection title="4.b. Aircraft Losses and Maintenance.">
              <Paragraph>
                Dispersal to multiple airfields and hardened shelters minimizes concentration
                losses. Maintenance capability limited to organic repair; no replacement aircraft
                available. Operational readiness depends on minimizing attrition.
              </Paragraph>
            </Subsection>
            <Subsection title="4.c. Missile Unit Survivability.">
              <Paragraph>
                Every missile unit operates under a shoot-relocate-conceal-reload cycle. Unit
                survival depends on position selection (dispersion and cover) and rapid
                repositioning after strikes.
              </Paragraph>
            </Subsection>
          </Section>

          {/* ---------------------------------------------------------------- */}
          <Section title="(U) 5. COMMAND AND CONTROL">
            <Subsection title="5.a. Command.">
              <Paragraph>
                Taiwan Defense Command exercises command of all armed forces. Command authority is
                centralized for strategic decisions; tactical authority is distributed to component
                commanders.
              </Paragraph>
            </Subsection>
            <Subsection title="5.b. Intelligence Support.">
              <Paragraph>
                US provides signals intelligence via RC-135V positioned to intercept enemy
                electromagnetic and radio signals. Intelligence is shared in near-real time to
                inform targeting and tactical adjustments.
              </Paragraph>
            </Subsection>
          </Section>
        </main>

        <Classification />
      </div>
    </div>
  );
}

// ============================================================================
// STATIC CONTENT
// ============================================================================
const ORDER_OF_BATTLE: { element: string; composition: string; role: string; staging: string }[] = [
  {
    element: 'Preliminary Strike Campaign',
    composition: 'SRBM, GLCM, fighter-bombers, attack aircraft',
    role: 'Saturation strikes on military installations, airfields, command centers',
    staging: 'Mainland coast',
  },
  {
    element: 'Carrier Strike Group',
    composition: 'Carrier, escort ships, carrier air wing',
    role: 'Stand-off strikes vs. eastward bases; air cover for fleet',
    staging: 'Bashi Channel -> eastern waters',
  },
  {
    element: 'ATF One (Zhoushan)',
    composition: 'LST, LPD, ACV, transport helicopters, air defense',
    role: 'Primary landing at Zhuwei / Taoyuan Airport',
    staging: 'Zhoushan Islands',
  },
  {
    element: 'ATF Two (Fujian)',
    composition: 'LST, LPD, ACV, transport helicopters, air defense',
    role: 'Secondary landing at Sishu / Tainan AB',
    staging: 'Fujian ports',
  },
];

const TASKS: { title: string; items: string[] }[] = [
  {
    title: '3.c.1. Air Defense Command.',
    items: [
      'Deploy SAM batteries (Sky Bow III, PAC-2/PAC-3) to cover airfields, command centers, and approach corridors.',
      'Engage inbound aircraft, cruise missiles, and ballistic missiles in layered defense.',
      'Relocate and conceal after strike waves to maximize unit survivability.',
      'Prioritize defense of critical airbases to sustain fighter operations.',
    ],
  },
  {
    title: '3.c.2. Fighter Operations.',
    items: [
      'Launch and maintain CAP over northern and southwestern landing zone approaches.',
      'Engage enemy strike aircraft, transport helicopters, and rotary-wing assets.',
      'Intercept cruise missile threats in coordination with IADS.',
      'Disperse to highway strips and shelters to avoid concentration damage.',
    ],
  },
  {
    title: '3.c.3. Anti-Ship Missile Command.',
    items: [
      'Deploy shore-based ASCM (Hsiung Feng III, 100 NM range) to cover Zhuwei and Sishu approach corridors.',
      'Engage amphibious task forces before they close to beaches.',
      'Shoot, relocate, reload and conceal to maximize firing cycles.',
    ],
  },
  {
    title: '3.c.4. Missile Strike Command.',
    items: [
      'Deploy SRBM (ATACMS, 162 NM range) and GLCM (Hsiung Feng IIE, 324 NM range) against enemy staging areas, ports, and mainland airbases.',
      'Shoot and relocate per plan; GLCM longest reload times must be managed for sustained tempo.',
      'Concentrate fires on enemy amphibious ports and logistics hubs to disrupt follow-on waves.',
    ],
  },
  {
    title: '3.c.5. Close-In Fires (MLRS).',
    items: [
      'Deploy MK-45 MLRS (20 NM range) to beach approach zones at Zhuwei and Sishu.',
      'Engage landing craft in transit and in surf zone with rocket fire.',
      'Support ground defense with suppressive fire against landed troops.',
    ],
  },
  {
    title: '3.c.6. Electronic Warfare.',
    items: [
      'GPS jammer companies degrade enemy precision-guided weapon accuracy.',
      'Maintain coverage over enemy approach routes and landing zones.',
    ],
  },
  {
    title: '3.c.7. Submarine Operations.',
    items: [
      'Deploy in Bashi Channel and eastern waters to intercept CSG and ATF escorts.',
      'Launch anti-ship and anti-submarine attacks vs. enemy naval forces.',
    ],
  },
  {
    title: '3.c.8. Ground Defense (Northern and Southwestern).',
    items: [
      'Zhuwei/Taoyuan zone: defend beach and airport approaches with prepared infantry and artillery positions.',
      'Sishu/Tainan zone: similar prepared defense to deny second landing zone.',
      'Engage landed forces with organic fires; coordinate with air and naval support.',
    ],
  },
];

// ============================================================================
// SUB-COMPONENTS
// ============================================================================
function Classification() {
  return (
    <div className="border border-dark-border bg-accent-blue px-2 py-1.5 text-center text-sm font-bold tracking-[3px] text-white">
      (U) UNCLASSIFIED
    </div>
  );
}

interface SectionProps {
  title: string;
  children: React.ReactNode;
}

function Section({ title, children }: SectionProps) {
  return (
    <section className="mb-6">
      <div className="mb-2.5 border-b border-dark-border pb-2 text-base font-semibold uppercase tracking-wide text-accent-blue">
        {title}
      </div>
      {children}
    </section>
  );
}

interface SubsectionProps {
  title: string;
  children: React.ReactNode;
}

function Subsection({ title, children }: SubsectionProps) {
  return (
    <div className="mb-4 ml-5">
      <SubTitle>{title}</SubTitle>
      {children}
    </div>
  );
}

function SubTitle({ children }: { children: React.ReactNode }) {
  return <div className="mb-1.5 text-[13px] font-semibold text-text-primary">{children}</div>;
}

function Paragraph({ children }: { children: React.ReactNode }) {
  return <p className="my-2 text-[13px] leading-relaxed text-text-secondary">{children}</p>;
}

function Indent({ children }: { children: React.ReactNode }) {
  return <div className="ml-5 mt-3">{children}</div>;
}

function List({ children }: { children: React.ReactNode }) {
  return (
    <ul className="my-1.5 ml-6 list-disc space-y-1 text-[13px] leading-relaxed text-text-secondary">
      {children}
    </ul>
  );
}

function Panel({ children }: { children: React.ReactNode }) {
  return (
    <div className="my-2.5 rounded-sm border border-dark-border bg-black/30 p-3">{children}</div>
  );
}

function MapCaption({ children }: { children: React.ReactNode }) {
  return (
    <div className="mb-2.5 mt-1.5 text-center text-xs italic text-text-secondary">{children}</div>
  );
}

function OpordMap({
  children,
  center = MAP_CENTER,
  zoom = MAP_ZOOM,
}: {
  children: React.ReactNode;
  center?: LatLngExpression;
  zoom?: number;
}) {
  return (
    <div className="my-4 h-100 overflow-hidden rounded-sm border border-dark-border">
      <MapContainer
        center={center}
        zoom={zoom}
        scrollWheelZoom={false}
        className="h-full w-full"
        style={{ background: '#10161a' }}
      >
        <LayersControl position="topright">
          <LayersControl.BaseLayer name="Dark">
            <TileLayer
              attribution="&copy; OpenStreetMap, &copy; CARTO"
              url="https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png"
              maxZoom={18}
            />
          </LayersControl.BaseLayer>
          <LayersControl.BaseLayer name="Terrain">
            <TileLayer
              attribution="&copy; Esri"
              url="https://server.arcgisonline.com/ArcGIS/rest/services/World_Topo_Map/MapServer/tile/{z}/{y}/{x}"
              maxZoom={18}
            />
          </LayersControl.BaseLayer>
          <LayersControl.BaseLayer checked name="Satellite">
            <TileLayer
              attribution="&copy; Esri, Maxar, Earthstar Geographics"
              url="https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}"
              maxZoom={18}
            />
          </LayersControl.BaseLayer>
        </LayersControl>
        {children}
      </MapContainer>
    </div>
  );
}

function OrderOfBattleTable() {
  return (
    <div className="my-2.5 overflow-x-auto">
      <table className="w-full border-collapse text-xs">
        <thead>
          <tr>
            {['Force Element', 'Composition', 'Role', 'Staging Area'].map((head) => (
              <th
                key={head}
                className="border border-dark-border bg-dark-bg px-2 py-1.5 text-left font-semibold text-text-primary"
              >
                {head}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {ORDER_OF_BATTLE.map((row) => (
            <tr key={row.element}>
              <td className="border border-dark-border px-2 py-1.5 text-text-primary">
                {row.element}
              </td>
              <td className="border border-dark-border px-2 py-1.5 text-text-secondary">
                {row.composition}
              </td>
              <td className="border border-dark-border px-2 py-1.5 text-text-secondary">
                {row.role}
              </td>
              <td className="border border-dark-border px-2 py-1.5 text-text-secondary">
                {row.staging}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
