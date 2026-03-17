import { useState, useCallback, useRef, useEffect } from 'react';
import type {
  Airbase,
  BudgetState,
  TabId,
  DeployedMissileSystemData,
  Jammer,
  MissileSystems,
} from '@/types/setupMenu';
import { CONFIG } from '@/types/setupMenu';
import { AIRBASES_DATA, JAMMERS_DATA, MISSILE_SYSTEMS_DATA } from '@/data/setupMenuData';
import { AircraftTab } from './components/AircraftTab';
import { JammersTab } from './components/JammersTab';
import { MissileSystemsTab } from './components/MissileSystemsTab';
import { SummaryTab } from './components/SummaryTab';

// ============================================================================
// GLOBAL TYPE DECLARATION
// ============================================================================
declare global {
  interface Window {
    __INJECT_JAMMERS__?: string;
    __INJECT_AIRBASES__?: string;
    __INJECT_MISSILE_SYSTEMS__?: string;
  }
}

// ============================================================================
// DATA LOADER
// ============================================================================
function loadInjectedData() {
  const parseJSON = <T,>(str: string | undefined, fallback: T): T => {
    if (!str || str === '[]' || str === '{}') return fallback;
    try {
      return JSON.parse(str) as T;
    } catch {
      return fallback;
    }
  };

  return {
    airbases: parseJSON<Airbase[]>(window.__INJECT_AIRBASES__, AIRBASES_DATA),
    jammers: parseJSON<Jammer[]>(window.__INJECT_JAMMERS__, JAMMERS_DATA),
    missileSystems: parseJSON<MissileSystems>(
      window.__INJECT_MISSILE_SYSTEMS__,
      MISSILE_SYSTEMS_DATA
    ),
  };
}

// ============================================================================
// TAB CONFIGURATION
// ============================================================================
const TABS: { id: TabId; label: string }[] = [
  { id: 'aircraft', label: 'Aircraft & Loadouts' },
  { id: 'jammers', label: 'GPS Jammers' },
  { id: 'missileSystems', label: 'Missile Systems' },
  { id: 'summary', label: 'Summary' },
];

// ============================================================================
// MAIN COMPONENT
// ============================================================================
function SetupMenuPage() {
  const [activeTab, setActiveTab] = useState<TabId>('aircraft');
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
  const missileSystems = injectedData.missileSystems;
  const [deployedJammers, setDeployedJammers] = useState<Map<number, { lat: number; lng: number }>>(
    new Map()
  );
  const [deployedMissileSystems, setDeployedMissileSystems] = useState<
    Map<string, DeployedMissileSystemData>
  >(new Map());

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
    setAirbases((prev) => prev.map((b, i) => (i === index ? updater(b) : b)));
  }, []);

  return (
    <div className="flex h-screen flex-col">
      {/* Top Bar */}
      <div className="flex h-12.5 items-center justify-between border-b border-dark-border bg-dark-panel px-5">
        <div className="text-sm font-medium text-text-secondary">
          <span className="text-text-primary">TAIWAN</span> / DEPLOYMENT PLANNING
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
        {activeTab === 'aircraft' && (
          <AircraftTab
            airbases={airbases}
            budget={budget}
            onSpendBudget={spendBudget}
            onRefundBudget={refundBudget}
            onUpdateAirbase={updateAirbase}
          />
        )}
        {activeTab === 'jammers' && (
          <JammersTab
            jammers={jammers}
            airbases={airbases}
            deployedJammers={deployedJammers}
            onDeployJammer={(index, lat, lng) => {
              setDeployedJammers((prev) => new Map(prev).set(index, { lat, lng }));
            }}
            onUndeployJammer={(index) => {
              setDeployedJammers((prev) => {
                const next = new Map(prev);
                next.delete(index);
                return next;
              });
            }}
          />
        )}
        {activeTab === 'missileSystems' && (
          <MissileSystemsTab
            missileSystems={missileSystems}
            airbases={airbases}
            deployedSystems={deployedMissileSystems}
            onDeploySystem={(key, data) => {
              setDeployedMissileSystems((prev) => new Map(prev).set(key, data));
            }}
            onUndeploySystem={(key) => {
              setDeployedMissileSystems((prev) => {
                const next = new Map(prev);
                next.delete(key);
                return next;
              });
            }}
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
