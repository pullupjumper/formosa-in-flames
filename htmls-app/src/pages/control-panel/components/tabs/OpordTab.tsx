import { useMemo } from 'react';
import { Marker, Polyline, Circle } from 'react-leaflet';
import type { LatLngTuple, PathOptions } from 'leaflet';
import type { Coordinate } from '@/types/geo';
import type { AmphibiousLocation, ForceImage } from '@/types/controlPanel';
import { MapShell, createImageIcon, ICON_IMAGES } from '@/components/map';
import {
  Section,
  Subsection,
  SubTitle,
  Paragraph,
  Indent,
  List,
  Panel,
  Caption,
  DocTable,
  DocTd,
} from '@/components/Doc';

interface OpordTabProps {
  amphibiousLocations: AmphibiousLocation[];
}

const FORCE_IMAGES: Record<'atf1' | 'atf2' | 'csg', ForceImage> = {
  atf1: { ...ICON_IMAGES.taskForce, label: 'ATF-1' },
  atf2: { ...ICON_IMAGES.taskForce, label: 'ATF-2' },
  csg: { ...ICON_IMAGES.carrier, label: 'CSG' },
};

/**
 * Return the matching amphibious operation's runtime route as Leaflet tuples.
 * Empty when the operation is missing from the injected data or carries no
 * resolvable waypoints, so callers must guard before indexing into it.
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
const MAP_CENTER: Coordinate = { latitude: 24.5, longitude: 120.5 };
const MAP_ZOOM = 7;
const THREAT_MAP_CENTER: Coordinate = { latitude: 25.5, longitude: 121.0 };
const THREAT_MAP_ZOOM = 5;

const LANDING_ZONE_RADIUS_M = 20000;

const LANDING_ZONE_THREAT: PathOptions = {
  color: '#db3737',
  fillColor: '#db3737',
  fillOpacity: 0.25,
  weight: 2,
};
const LANDING_ZONE_OUTLINE: PathOptions = {
  color: '#ffffff',
  fillOpacity: 0,
  weight: 2,
};
const AXIS_AMPHIBIOUS: PathOptions = {
  color: '#137cbd',
  weight: 3,
  opacity: 0.85,
  dashArray: '10, 5',
};
const AXIS_CARRIER: PathOptions = {
  color: '#db3737',
  weight: 3,
  opacity: 0.85,
  dashArray: '10, 5',
};

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
      atf1: createImageIcon(FORCE_IMAGES.atf1),
      atf2: createImageIcon(FORCE_IMAGES.atf2),
      csg: createImageIcon(FORCE_IMAGES.csg),
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
        <header className="border border-aip-border bg-aip-panel px-5 py-5 text-center">
          <h1 className="mb-2.5 text-2xl font-bold underline">(U) OPERATIONS ORDER 26-001</h1>
          <div className="text-sm text-text-secondary">DEFENSE OF TAIWAN</div>
          <div className="text-sm text-text-secondary">TAIWAN DEFENSE COMMAND</div>
          <div className="text-sm text-text-secondary">09JUN27 0200Z</div>
        </header>

        <main className="border-x border-b border-aip-border bg-aip-panel px-5 py-6">
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
                <LandingZone route={routes.atf1} pathOptions={LANDING_ZONE_THREAT} />
                <LandingZone route={routes.atf2} pathOptions={LANDING_ZONE_THREAT} />
                <LandingZone route={routes.atf3} pathOptions={LANDING_ZONE_THREAT} />
              </OpordMap>
              <Caption>Fig 1. Taiwan and Amphibious Approach Zones</Caption>

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
                <ApproachAxis route={CSG_ROUTE} icon={icons.csg} pathOptions={AXIS_CARRIER} />

                {/* Amphibious Task Forces One, Two and Three */}
                <ApproachAxis route={routes.atf1} icon={icons.atf1} pathOptions={AXIS_AMPHIBIOUS} />
                <ApproachAxis route={routes.atf2} icon={icons.atf2} pathOptions={AXIS_AMPHIBIOUS} />
                <ApproachAxis route={routes.atf3} icon={icons.atf2} pathOptions={AXIS_AMPHIBIOUS} />

                {/* Landing zones */}
                <LandingZone route={routes.atf1} pathOptions={LANDING_ZONE_OUTLINE} />
                <LandingZone route={routes.atf2} pathOptions={LANDING_ZONE_OUTLINE} />
                <LandingZone route={routes.atf3} pathOptions={LANDING_ZONE_OUTLINE} />
              </OpordMap>
              <Caption>Fig 2. Red Offensive Axes and Landing Zones</Caption>
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
/**
 * Ring around a route's destination. Renders nothing when the route resolved
 * to no waypoints, since Leaflet throws on an undefined center.
 */
function LandingZone({ route, pathOptions }: { route: LatLngTuple[]; pathOptions: PathOptions }) {
  const destination = route[route.length - 1];
  if (!destination) return null;
  return <Circle center={destination} radius={LANDING_ZONE_RADIUS_M} pathOptions={pathOptions} />;
}

/**
 * Approach axis with its force marker at the staging point. Renders nothing
 * when the route resolved to no waypoints.
 */
function ApproachAxis({
  route,
  icon,
  pathOptions,
}: {
  route: LatLngTuple[];
  icon: L.DivIcon;
  pathOptions: PathOptions;
}) {
  const staging = route[0];
  if (!staging) return null;
  return (
    <>
      <Polyline positions={route} pathOptions={pathOptions} />
      <Marker position={staging} icon={icon} />
    </>
  );
}

function Classification() {
  return (
    <div className="border border-dark-border bg-accent-blue px-2 py-1.5 text-center text-sm font-bold tracking-[3px] text-white">
      (U) UNCLASSIFIED
    </div>
  );
}

function OpordMap({
  children,
  center = MAP_CENTER,
  zoom = MAP_ZOOM,
}: {
  children: React.ReactNode;
  center?: Coordinate;
  zoom?: number;
}) {
  return (
    <div className="my-4 h-100 overflow-hidden rounded-sm border border-dark-border">
      <MapShell center={center} zoom={zoom} scrollWheelZoom={false}>
        {children}
      </MapShell>
    </div>
  );
}

function OrderOfBattleTable() {
  return (
    <DocTable headers={['Force Element', 'Composition', 'Role', 'Staging Area']}>
      {ORDER_OF_BATTLE.map((row) => (
        <tr key={row.element}>
          <DocTd className="text-text-primary">{row.element}</DocTd>
          <DocTd>{row.composition}</DocTd>
          <DocTd>{row.role}</DocTd>
          <DocTd>{row.staging}</DocTd>
        </tr>
      ))}
    </DocTable>
  );
}
