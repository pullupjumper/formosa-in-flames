import { useState, useCallback, useRef, useEffect } from 'react';
import type { Coordinate } from '@/types/geo';
import type {
  Airbase,
  BudgetState,
  SetupMenuTabId,
  MissileDeployment,
  Jammer,
  MissileSystems,
  AmphibiousLocation,
} from '@/types/setupMenu';
import { CONFIG } from '@/constants/setupMenu';
import { parseInjectedJSON, readInjectedString } from '@/utils/inject';
import {
  AIRBASES_DATA,
  JAMMERS_DATA,
  MISSILE_SYSTEMS_DATA,
  AMPHIBIOUS_LOCATION_DATA,
} from '@/data/setupMenuData';
import { MechanicsTab } from './components/MechanicsTab';
import { DeploymentTab } from './components/DeploymentTab';
import { OpordTab } from './components/OpordTab';
import { SummaryTab } from './components/SummaryTab';
import { makeUnitKey } from '@/utils/map';
import { calculateCentroid } from '@/utils/geo';

// ============================================================================
// GLOBAL TYPE DECLARATION
// ============================================================================
declare global {
  interface Window {
    __INJECT_JAMMERS__?: string;
    __INJECT_AIRBASES__?: string;
    __INJECT_MISSILE_SYSTEMS__?: string;
    __INJECT_SIDE_NAME__?: string;
    __INJECT_AMPHIBIOUS_LOCATIONS__?: string;
  }
}

// ============================================================================
// DATA LOADER
// ============================================================================
function loadInjectedData() {
  return {
    airbases: parseInjectedJSON<Airbase[]>(window.__INJECT_AIRBASES__, AIRBASES_DATA, 'AIRBASES'),
    jammers: parseInjectedJSON<Jammer[]>(window.__INJECT_JAMMERS__, JAMMERS_DATA, 'JAMMERS'),
    missileSystems: parseInjectedJSON<MissileSystems>(
      window.__INJECT_MISSILE_SYSTEMS__,
      MISSILE_SYSTEMS_DATA,
      'MISSILE_SYSTEMS'
    ),
    sideName: readInjectedString(window.__INJECT_SIDE_NAME__, 'Taiwan'),
    amphibiousLocations: parseInjectedJSON<AmphibiousLocation[]>(
      window.__INJECT_AMPHIBIOUS_LOCATIONS__,
      AMPHIBIOUS_LOCATION_DATA,
      'AMPHIBIOUS_LOCATIONS'
    ),
  };
}

/**
 * Rebuild the map-side deployment for a firing unit that the scenario already
 * placed, so pre-existing units render exactly like player-placed ones.
 */
function buildInjectedDeployments(missileSystems: MissileSystems): Map<string, MissileDeployment> {
  const deployments = new Map<string, MissileDeployment>();

  for (const category of Object.keys(missileSystems)) {
    const firingUnits = missileSystems[category]?.firingUnits;
    if (!firingUnits) continue;

    for (const [unitName, unit] of Object.entries(firingUnits)) {
      const { operationalArea } = unit;
      const reloadCourse = operationalArea.RL[0].course;
      const tacticalAreas = {
        uShapeVertices: operationalArea.uShapeVertices,
        ammoArea: operationalArea.AHA[0].area,
        hideArea: operationalArea.HA[0].area,
        reloadArea: operationalArea.RL[0].area,
        firePoints: operationalArea.FP.map((position) => position.area),
        shelterPoints: operationalArea.shelterPoints,
      };

      deployments.set(makeUnitKey(category, unitName), {
        unitName,
        category,
        center: calculateCentroid(operationalArea.uShapeVertices),
        openingAngle: 0,
        ahaRadius: 0,
        ahaCenter: { latitude: 0, longitude: 0 },
        tacticalAreas,
        paths: {
          FP: operationalArea.FP.map((position) => ({ waypoints: position.course })),
          HA: { waypoints: reloadCourse.concat(operationalArea.HA[0].course) },
          AHA: { waypoints: reloadCourse.concat(operationalArea.AHA[0].course) },
          RL: operationalArea.FP.map((position) => ({
            waypoints: [position.course[position.course.length - 1]].concat(reloadCourse),
          })),
          SHRL: { waypoints: operationalArea.SHRL?.[0].course ?? [] },
        },
      });
    }
  }

  return deployments;
}

// ============================================================================
// TAB CONFIGURATION
// ============================================================================
const TABS: { id: SetupMenuTabId; label: string }[] = [
  { id: 'opord', label: 'OPORD' },
  { id: 'mechanics', label: 'Game Mechanics' },
  { id: 'deployment', label: 'Deployment' },
  { id: 'summary', label: 'Summary' },
];

// ============================================================================
// MAIN COMPONENT
// ============================================================================
function SetupMenuPage() {
  const [activeTab, setActiveTab] = useState<SetupMenuTabId>('opord');
  const [budget, setBudget] = useState<BudgetState>({
    current: CONFIG.INITIAL_SCORE,
    used: 0,
    total: CONFIG.INITIAL_SCORE,
  });
  const budgetRef = useRef(budget);
  useEffect(() => {
    budgetRef.current = budget;
  }, [budget]);
  const [injectedData] = useState(loadInjectedData);
  const [airbases, setAirbases] = useState(() => structuredClone(injectedData.airbases));
  const jammers = injectedData.jammers;
  const amphibiousLocations = injectedData.amphibiousLocations;
  const missileSystems = injectedData.missileSystems;
  const sideName = injectedData.sideName;
  const shouldValidateTaiwanBoundary = sideName === 'Taiwan';
  const [deployedJammers, setDeployedJammers] = useState<Map<number, Coordinate>>(new Map());
  // Units the scenario already placed start out deployed; the injected payload
  // is read once, so seeding state here replaces a setState-in-effect.
  const [deployedMissileSystems, setDeployedMissileSystems] = useState(() =>
    buildInjectedDeployments(missileSystems)
  );

  // Budget handlers
  const spendBudget = useCallback((amount: number = CONFIG.LOADOUT_COST): boolean => {
    if (budgetRef.current.current < amount) {
      return false;
    }
    setBudget((prev) => ({
      ...prev,
      current: prev.current - amount,
      used: prev.used + amount,
    }));
    budgetRef.current = {
      ...budgetRef.current,
      current: budgetRef.current.current - amount,
      used: budgetRef.current.used + amount,
    };
    return true;
  }, []);

  const refundBudget = useCallback((amount: number = CONFIG.LOADOUT_COST): void => {
    setBudget((prev) => ({
      ...prev,
      current: prev.current + amount,
      used: prev.used - amount,
    }));
    budgetRef.current = {
      ...budgetRef.current,
      current: budgetRef.current.current + amount,
      used: budgetRef.current.used - amount,
    };
  }, []);

  const updateAirbase = useCallback((index: number, updater: (base: Airbase) => Airbase) => {
    setAirbases((prev) => prev.map((base, i) => (i === index ? updater(base) : base)));
  }, []);

  // Deployment handlers — kept stable so DeploymentTab's memoized map layers are
  // not invalidated by unrelated re-renders (e.g. budget edits)
  const deployMissileSystem = useCallback((key: string, data: MissileDeployment) => {
    setDeployedMissileSystems((prev) => new Map(prev).set(key, data));
  }, []);

  const undeployMissileSystem = useCallback((key: string) => {
    setDeployedMissileSystems((prev) => {
      const next = new Map(prev);
      next.delete(key);
      return next;
    });
  }, []);

  const deployJammer = useCallback((index: number, position: Coordinate) => {
    setDeployedJammers((prev) => new Map(prev).set(index, position));
  }, []);

  const undeployJammer = useCallback((index: number) => {
    setDeployedJammers((prev) => {
      const next = new Map(prev);
      next.delete(index);
      return next;
    });
  }, []);

  return (
    <div className="flex h-screen flex-col">
      {/* Top Bar */}
      <div className="flex h-12.5 items-center justify-between border-b border-dark-border bg-dark-panel px-5">
        <div className="text-sm font-medium text-text-secondary">
          <span className="text-text-primary">{sideName.toUpperCase()}</span> / DEPLOYMENT PLANNING
        </div>
      </div>

      {/* Tab Container */}
      <div className="flex border-b border-dark-border bg-dark-bg px-5">
        {TABS.map((tab) => (
          <button
            key={tab.id}
            className={`border-b-[3px] px-4 py-3 text-[13px] font-semibold uppercase tracking-wide transition-colors ${
              activeTab === tab.id
                ? 'border-accent-blue text-accent-blue'
                : 'border-transparent text-text-secondary hover:text-text-primary'
            }`}
            onClick={() => setActiveTab(tab.id)}
          >
            {tab.label}
          </button>
        ))}
      </div>

      {/* Content */}
      <div className="relative flex-1 overflow-hidden">
        {activeTab === 'opord' && <OpordTab amphibiousLocations={amphibiousLocations} />}
        {activeTab === 'mechanics' && <MechanicsTab />}
        {activeTab === 'deployment' && (
          <DeploymentTab
            missileSystems={missileSystems}
            airbases={airbases}
            baselineAirbases={injectedData.airbases}
            jammers={jammers}
            budget={budget}
            deployedSystems={deployedMissileSystems}
            deployedJammers={deployedJammers}
            shouldValidateTaiwanBoundary={shouldValidateTaiwanBoundary}
            sideName={sideName}
            onDeploySystem={deployMissileSystem}
            onUndeploySystem={undeployMissileSystem}
            onDeployJammer={deployJammer}
            onUndeployJammer={undeployJammer}
            onSpendBudget={spendBudget}
            onRefundBudget={refundBudget}
            onUpdateAirbase={updateAirbase}
          />
        )}
        {activeTab === 'summary' && (
          <SummaryTab
            budget={budget}
            airbases={airbases}
            jammers={jammers}
            missileSystems={missileSystems}
            deployedJammers={deployedJammers}
            deployedMissileSystems={deployedMissileSystems}
          />
        )}
      </div>
    </div>
  );
}

export default SetupMenuPage;
