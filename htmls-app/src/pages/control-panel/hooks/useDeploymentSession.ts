import type { AirbaseDeploymentDescriptor } from '@/types/generated';
import { useState, useCallback } from 'react';
import type { Coordinate } from '@/types/geo';
import type { DeployedBattery } from '@/types/deployment';
import { CONFIG } from '@/constants/controlPanel';
import { buildInjectedDeployments } from '@/pages/control-panel/logic/deploymentPayload';
import { createBudgetState } from '@/pages/control-panel/logic/budgetLedger';
import type { ControlPanelPayload } from '../logic/controlPanelPayload';

/**
 * Deployment state for the Deployment tab: the loadout budget and what the
 * player has deployed so far, seeded from the injected payload. Lives above the tabs so it survives switching between them.
 */
export function useDeploymentSession(payload: ControlPanelPayload) {
  const [budget, setBudget] = useState(() => createBudgetState(CONFIG.INITIAL_SCORE));
  const [airbases, setAirbases] = useState(() => structuredClone(payload.airbases));
  const [deployedJammers, setDeployedJammers] = useState<Map<number, Coordinate>>(new Map());
  // Units the scenario already placed start out deployed; the injected payload
  // is read once, so seeding state here replaces a setState-in-effect.
  const [injectedDeployments] = useState(() => buildInjectedDeployments(payload.batteries));
  const [deployedBatteries, setDeployedBatteries] = useState(() => new Map(injectedDeployments));

  const updateAirbase = useCallback(
    (
      index: number,
      updater: (base: AirbaseDeploymentDescriptor) => AirbaseDeploymentDescriptor
    ) => {
      setAirbases((prev) => prev.map((base, i) => (i === index ? updater(base) : base)));
    },
    []
  );

  // Deployment handlers — kept stable so the Deployment tab's memoized map layers
  // are not invalidated by unrelated re-renders (e.g. budget edits)
  const deployMissileSystem = useCallback((key: string, data: DeployedBattery) => {
    setDeployedBatteries((prev) => new Map(prev).set(key, data));
  }, []);

  const undeployMissileSystem = useCallback((key: string) => {
    setDeployedBatteries((prev) => {
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
    deployedBatteries,
    injectedDeployments,
    deployMissileSystem,
    undeployMissileSystem,
  };
}

export type DeploymentSession = ReturnType<typeof useDeploymentSession>;
