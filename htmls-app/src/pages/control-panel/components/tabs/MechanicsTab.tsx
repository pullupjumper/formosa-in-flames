import {
  Section,
  SubTitle,
  Paragraph,
  List,
  Callout,
  Term,
  Screenshot,
  Figure,
  DocTable,
  DocTd,
} from '@/components/Doc';

// ============================================================================
// GAME MECHANICS -- PLAYER BRIEFING
// Short, action-oriented tips shown before the scenario starts.
// Chapter 1 covers the missile system: your launchers are under manual
// control, so you have to run the reload cycle and the concealment yourself.
// ============================================================================

// ============================================================================
// POSITION PALETTE
// Mirrors the Tailwind @theme colors used across the control panel.
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
    code: 'ATP',
    name: 'Ammunition Transfer Point',
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
        <header className="border border-aip-border bg-aip-panel px-5 py-5 text-center">
          <h1 className="mb-2.5 text-2xl font-bold underline">GAME MECHANICS</h1>
          <div className="text-sm text-text-secondary">MISSILE SYSTEM -- HOW TO PLAY</div>
        </header>

        <main className="border-x border-b border-aip-border bg-aip-pane px-5 py-6">
          {/* ---------------------------------------------------------------- */}
          <Section title="1. YOUR LAUNCHERS ARE ON MANUAL CONTROL">
            <Paragraph>
              Your missile units will not resupply, reposition or hide by themselves. Every move is
              your order. Plan for it -- a battery with empty tubes sitting at a firing point stays
              empty until you do something about it.
            </Paragraph>
            <Callout title="Your job, in one line each">
              <List>
                <li>Keep launchers at a FP while you want them shooting.</li>
                <li>
                  When ammo runs low, send the launcher to a RL -- and send an ammo truck too.
                </li>
                <li>When a truck runs empty, send it to the ATP to take on more missiles.</li>
                <li>Hide idle vehicles in MASK buildings so they survive.</li>
              </List>
            </Callout>
          </Section>

          {/* ---------------------------------------------------------------- */}
          <Section title="2. THE POSITIONS IN YOUR OPERATIONAL AREA">
            <Paragraph>
              Each missile unit has its own operational area with these positions marked as
              reference points on the map. Move your vehicles between them.
            </Paragraph>
            <Figure caption="Fig 1. The MASK area (red box) covers the HA and RL positions and the shelter buildings. The FP and ATP positions sit outside it.">
              <Screenshot
                src={SCREENSHOT.positionLayout}
                alt="Operational area layout on the map"
              />
            </Figure>
            <PositionTable />
            <Callout title="Reloading only works if you get this right">
              <List>
                <li>
                  The launcher and the ammo truck must be in the <Term>same</Term> RL. Different RLs
                  means nothing happens.
                </li>
                <li>Same rule at the ATP -- the truck and the depot must be in the same one.</li>
                <li>
                  An empty truck has to go back to the ATP and draw from the depot stock before it
                  can reload anything.
                </li>
                <li>
                  Reloading takes time. Pull a battery out before it is completely dry, not after.
                </li>
              </List>
            </Callout>
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
            <Callout title="Steps">
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
            </Callout>
          </Section>

          {/* ---------------------------------------------------------------- */}
          <Section title="4. CHECK BATTERY STATUS">
            <Paragraph>
              Open the <Term>Deployment</Term> tab and click a battery in the{' '}
              <Term>Missile Batteries</Term> panel to see what it is doing instead of clicking
              through units one by one.
            </Paragraph>
            <Callout>
              <List>
                <li>
                  <Term>FIRING</Term> -- whether the battery is hiding, in position, or reloading,
                  with its reload progress.
                </li>
                <li>
                  <Term>RESUPPLY</Term> -- the same for the ammo truck serving it.
                </li>
                <li>
                  <Term>MISSILES (AMMO)</Term> -- what the truck is still carrying.
                </li>
                <li>
                  <Term>MISSILES (ATP)</Term> -- remaining stock at the depot.
                </li>
              </List>
            </Callout>
            <Paragraph>
              Depot feeds truck, truck feeds launcher. A zero anywhere in that chain means a battery
              goes quiet soon -- this panel is where you spot it early.
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
    <DocTable headers={['Position', 'Name', 'What you use it for']}>
      {POSITIONS.map((position) => (
        <tr key={position.code}>
          <DocTd className="font-semibold" style={{ color: position.color }}>
            {position.code}
          </DocTd>
          <DocTd className="text-text-primary">{position.name}</DocTd>
          <DocTd>{position.usage}</DocTd>
        </tr>
      ))}
    </DocTable>
  );
}
