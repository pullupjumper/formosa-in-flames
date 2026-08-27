// ============================================================================
// GAME MECHANICS -- PLAYER BRIEFING
// Short, action-oriented tips shown before the scenario starts.
// Chapter 1 covers the missile system: your launchers are under manual
// control, so you have to run the reload cycle and the concealment yourself.
// ============================================================================

// ============================================================================
// POSITION PALETTE
// Mirrors the Tailwind @theme colors used across the setup menu.
// ============================================================================
const COLOR = {
  blue: '#137cbd',
  green: '#0f9960',
  orange: '#d9822b',
  red: '#db3737',
  violet: '#8f6bd4',
} as const;

// ============================================================================
// SCREENSHOTS
// In-game captures, used instead of hand-drawn diagrams so the briefing
// matches what the player actually sees on screen.
// ============================================================================
const SCREENSHOT = {
  positionLayout: 'https://i.meee.com.tw/sXUai33.png',
  loadCargo: 'https://i.meee.com.tw/cwclF0T.png',
  unitStatus: 'https://i.meee.com.tw/ZcDqg1m.png',
} as const;

// ============================================================================
// POSITION REFERENCE DATA
// ============================================================================
interface PositionSpec {
  code: string;
  name: string;
  color: string;
  usage: string;
}

const POSITIONS: PositionSpec[] = [
  {
    code: 'FP',
    name: 'Firing Point',
    color: COLOR.red,
    usage:
      'Outside the MASK area. Launchers are weapons-free here -- park a battery here when you want it shooting.',
  },
  {
    code: 'HA',
    name: 'Hide Area',
    color: COLOR.green,
    usage:
      'Inside the MASK area. Weapons-tight waiting position between fire missions. Move launchers here to disperse.',
  },
  {
    code: 'RL',
    name: 'Reload Point',
    color: COLOR.orange,
    usage:
      'Inside the MASK area. Send a launcher AND an ammo truck to the same RL. Reloading starts once both arrive.',
  },
  {
    code: 'AHA',
    name: 'Ammo Holding Area',
    color: COLOR.violet,
    usage:
      'Outside the MASK area. Send an empty ammo truck here to take on missiles from the depot, then send it back to a RL.',
  },
  {
    code: 'MASK',
    name: 'Masking Area',
    color: COLOR.blue,
    usage:
      'An area, not a position. It covers your HA and RL positions and the buildings you can hide vehicles inside. See section 3.',
  },
];

// ============================================================================
// MAIN COMPONENT
// ============================================================================
export function MechanicsTab() {
  return (
    <div className="h-full overflow-y-auto">
      <div className="mx-auto max-w-260 p-8">
        <header className="border border-dark-border bg-dark-panel px-5 py-5 text-center">
          <h1 className="mb-2.5 text-2xl font-bold underline">GAME MECHANICS</h1>
          <div className="text-sm text-text-secondary">MISSILE SYSTEM -- HOW TO PLAY</div>
        </header>

        <main className="border-x border-b border-dark-border bg-dark-panel px-5 py-6">
          {/* ---------------------------------------------------------------- */}
          <Section title="1. YOUR LAUNCHERS ARE ON MANUAL CONTROL">
            <Paragraph>
              Your missile units will not resupply, reposition or hide by themselves. Every move is
              your order. Plan for it -- a battery with empty tubes sitting at a firing point stays
              empty until you do something about it.
            </Paragraph>
            <Panel>
              <SubTitle>Your job, in one line each</SubTitle>
              <List>
                <li>Keep launchers at a FP while you want them shooting.</li>
                <li>
                  When ammo runs low, send the launcher to a RL -- and send an ammo truck too.
                </li>
                <li>When a truck runs empty, send it to the AHA to take on more missiles.</li>
                <li>Hide idle vehicles in MASK buildings so they survive.</li>
              </List>
            </Panel>
          </Section>

          {/* ---------------------------------------------------------------- */}
          <Section title="2. THE POSITIONS IN YOUR OPERATIONAL AREA">
            <Paragraph>
              Each missile unit has its own operational area with these positions marked as
              reference points on the map. Move your vehicles between them.
            </Paragraph>
            <Figure caption="Fig 1. The MASK area (red box) covers the HA and RL positions and the shelter buildings. The FP and AHA positions sit outside it.">
              <Screenshot
                src={SCREENSHOT.positionLayout}
                alt="Operational area layout on the map"
              />
            </Figure>
            <PositionTable />
            <Panel>
              <SubTitle>Reloading only works if you get this right</SubTitle>
              <List>
                <li>
                  The launcher and the ammo truck must be in the <Term>same</Term> RL. Different RLs
                  means nothing happens.
                </li>
                <li>Same rule at the AHA -- the truck and the depot must be in the same one.</li>
                <li>
                  An empty truck has to go back to the AHA and draw from the depot stock before it
                  can reload anything.
                </li>
                <li>
                  Reloading takes time. Pull a battery out before it is completely dry, not after.
                </li>
              </List>
            </Panel>
          </Section>

          {/* ---------------------------------------------------------------- */}
          <Section title="3. HIDING VEHICLES IN MASK BUILDINGS">
            <Paragraph>
              A vehicle parked in the open will eventually be found and hit. The MASK area has
              buildings you can put vehicles inside using the cargo system.
            </Paragraph>
            <Figure caption="Fig 2. Cargo Operations. Pick the vehicles on the left, load them into the building on the right.">
              <Screenshot src={SCREENSHOT.loadCargo} alt="Cargo Operations dialog" />
            </Figure>
            <Panel>
              <SubTitle>Steps</SubTitle>
              <List>
                <li>Move the launchers and ammo trucks into the MASK area.</li>
                <li>
                  Select a shelter building and open <Term>Cargo Operations</Term>. Nearby vehicles
                  show up in the left list.
                </li>
                <li>
                  Load what you want to hide -- a single vehicle, a group, or the whole battery --
                  then <Term>Confirm</Term>.
                </li>
                <li>
                  Use <Term>Unload All</Term> on that building when you need the vehicles back.
                </li>
              </List>
              <SubTitle>Keep in mind</SubTitle>
              <List>
                <li>A hidden vehicle cannot fire or move until you unload it.</li>
                <li>If the building is destroyed, so is what is inside.</li>
              </List>
            </Panel>
          </Section>

          {/* ---------------------------------------------------------------- */}
          <Section title="4. CHECK THE UNIT STATUS PAGE">
            <Paragraph>
              Open the Unit Status page and switch to the <Term>MISSILE SYSTEMS</Term> tab to see
              what every battery is doing instead of clicking through units one by one.
            </Paragraph>
            <Figure caption="Fig 3. Unit Status -- MISSILE SYSTEMS tab.">
              <Screenshot src={SCREENSHOT.unitStatus} alt="Unit Status missile systems tab" />
            </Figure>
            <Panel>
              <List>
                <li>
                  <Term>Firing Unit State</Term> -- whether the battery is hiding, in position, or
                  reloading, with its reload progress.
                </li>
                <li>
                  <Term>Resupply Unit State</Term> -- the same for the ammo truck serving it.
                </li>
                <li>
                  <Term>Missiles (Ammo)</Term> -- what the truck is still carrying.
                </li>
                <li>
                  <Term>Missiles (AHA)</Term> -- remaining stock at the depot.
                </li>
              </List>
            </Panel>
            <Paragraph>
              Depot feeds truck, truck feeds launcher. A zero anywhere in that chain means a battery
              goes quiet soon -- this page is where you spot it early.
            </Paragraph>
          </Section>
        </main>
      </div>
    </div>
  );
}

// ============================================================================
// TABLES
// ============================================================================
function PositionTable() {
  return (
    <div className="my-2.5 overflow-x-auto">
      <table className="w-full border-collapse text-xs">
        <thead>
          <tr>
            {['Position', 'Name', 'What you use it for'].map((head) => (
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
          {POSITIONS.map((position) => (
            <tr key={position.code}>
              <td
                className="border border-dark-border px-2 py-1.5 font-semibold"
                style={{ color: position.color }}
              >
                {position.code}
              </td>
              <td className="border border-dark-border px-2 py-1.5 text-text-primary">
                {position.name}
              </td>
              <td className="border border-dark-border px-2 py-1.5 text-text-secondary">
                {position.usage}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

// ============================================================================
// PRESENTATION HELPERS
// ============================================================================
function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section className="mb-6">
      <div className="mb-2.5 border-b border-dark-border pb-2 text-base font-semibold uppercase tracking-wide text-accent-blue">
        {title}
      </div>
      {children}
    </section>
  );
}

function SubTitle({ children }: { children: React.ReactNode }) {
  return <div className="mb-1.5 text-[13px] font-semibold text-text-primary">{children}</div>;
}

function Paragraph({ children }: { children: React.ReactNode }) {
  return <p className="my-2 text-[13px] leading-relaxed text-text-secondary">{children}</p>;
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

function Term({ children }: { children: React.ReactNode }) {
  return <span className="font-semibold text-text-primary">{children}</span>;
}

function Screenshot({ src, alt }: { src: string; alt: string }) {
  return <img src={src} alt={alt} className="block w-full" />;
}

function Figure({ caption, children }: { caption: string; children: React.ReactNode }) {
  return (
    <div className="my-4">
      <div className="overflow-hidden rounded-sm border border-dark-border bg-dark-bg">
        {children}
      </div>
      <div className="mb-2.5 mt-1.5 text-center text-xs italic text-text-secondary">{caption}</div>
    </div>
  );
}
