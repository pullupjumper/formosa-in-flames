import { useState, useCallback } from 'react';
import type { Coordinate } from '@/types/geo';
import type { Airbase, MissileDeployment } from '@/types/setupMenu';
import { CONFIG } from '@/constants/setupMenu';
import { buildInjectedDeployments } from '@/utils/setupMenuPayload';
import { createBudgetState } from '@/utils/budgetLedger';
import type { ControlPanelPayload } from '../controlPanelPayload';

/**
 * Deployment state for the Deployment tab: the loadout budget and what the
 * player has deployed so far, seeded from the injected payload. Lives above the tabs so it survives switching between them.
 */
export function useSetupMenuState(payload: ControlPanelPayload) {
  const [budget, setBudget] = useState(() => createBudgetState(CONFIG.INITIAL_SCORE));
  const [airbases, setAirbases] = useState(() => structuredClone(payload.airbases));
  const [deployedJammers, setDeployedJammers] = useState<Map<number, Coordinate>>(new Map());
  // Units the scenario already placed start out deployed; the injected payload
  // is read once, so seeding state here replaces a setState-in-effect.
  const [deployedMissileSystems, setDeployedMissileSystems] = useState(() =>
    buildInjectedDeployments(payload.missileSystems)
  );

  const updateAirbase = useCallback((index: number, updater: (base: Airbase) => Airbase) => {
    setAirbases((prev) => prev.map((base, i) => (i === index ? updater(base) : base)));
  }, []);

  // Deployment handlers — kept stable so the Deployment tab's memoized map layers
  // are not invalidated by unrelated re-renders (e.g. budget edits)
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

  return {
    budget,
    setBudget,
    airbases,
    updateAirbase,
    deployedJammers,
    deployJammer,
    undeployJammer,
    deployedMissileSystems,
    deployMissileSystem,
    undeployMissileSystem,
  };
}
