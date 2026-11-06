import type { AirbaseDeploymentDescriptor } from '@/types/generated';
import { describe, it, expect } from 'vitest';
import { act, renderHook } from '@testing-library/react';
import { CONFIG } from '@/constants/controlPanel';
import type { MissileDeployment } from '@/types/deployment';
import { createBudgetState } from '../logic/budgetLedger';
import { buildInjectedDeployments } from '../logic/deploymentPayload';
import { readControlPanelPayload } from '../logic/controlPanelPayload';
import type { ControlPanelPayload } from '../logic/controlPanelPayload';
import { useDeploymentSession } from './useDeploymentSession';

// ============================================================================
// FIXTURES
// ============================================================================
function buildAirbase(name: string): AirbaseDeploymentDescriptor {
  return { name, longitude: 120, latitude: 23, baseGUID: `guid-${name}` };
}

function buildPayload(airbases: AirbaseDeploymentDescriptor[]): ControlPanelPayload {
  return { ...readControlPanelPayload(), airbases };
}

const DEPLOYMENT = {} as MissileDeployment;

// ============================================================================
// TESTS
// ============================================================================
describe('useDeploymentSession', () => {
  it('starts with the full loadout budget', () => {
    const { result } = renderHook(() => useDeploymentSession(buildPayload([])));

    expect(result.current.budget).toEqual(createBudgetState(CONFIG.INITIAL_SCORE));
  });

  it('starts with the missile systems the scenario already placed', () => {
    const payload = buildPayload([]);

    const { result } = renderHook(() => useDeploymentSession(payload));

    expect(result.current.deployedMissileSystems).toEqual(
      buildInjectedDeployments(payload.batteries)
    );
    expect(result.current.deployedJammers.size).toBe(0);
  });

  describe('airbases', () => {
    it('starts from a copy, so an in-place edit never reaches the injected airbases', () => {
      const payload = buildPayload([buildAirbase('AB-1')]);

      const { result } = renderHook(() => useDeploymentSession(payload));
      act(() =>
        result.current.updateAirbase(0, (base) => {
          base.name = 'Renamed';
          return base;
        })
      );

      expect(result.current.airbases[0].name).toBe('Renamed');
      expect(payload.airbases[0].name).toBe('AB-1');
    });

    it('updates only the airbase at the given index', () => {
      const payload = buildPayload([buildAirbase('AB-1'), buildAirbase('AB-2')]);

      const { result } = renderHook(() => useDeploymentSession(payload));
      act(() => result.current.updateAirbase(1, (base) => ({ ...base, name: 'Renamed' })));

      expect(result.current.airbases.map((base) => base.name)).toEqual(['AB-1', 'Renamed']);
    });
  });

  describe('jammers', () => {
    it('remembers where a jammer was deployed', () => {
      const { result } = renderHook(() => useDeploymentSession(buildPayload([])));

      act(() => result.current.deployJammer(2, { latitude: 24, longitude: 121 }));

      expect(result.current.deployedJammers.get(2)).toEqual({ latitude: 24, longitude: 121 });
    });

    it('forgets a jammer once it is undeployed', () => {
      const { result } = renderHook(() => useDeploymentSession(buildPayload([])));
      act(() => result.current.deployJammer(2, { latitude: 24, longitude: 121 }));
      act(() => result.current.deployJammer(3, { latitude: 25, longitude: 122 }));

      act(() => result.current.undeployJammer(2));

      expect([...result.current.deployedJammers.keys()]).toEqual([3]);
    });
  });

  describe('missile systems', () => {
    it('remembers a missile system deployed by the player', () => {
      const { result } = renderHook(() => useDeploymentSession(buildPayload([])));

      act(() => result.current.deployMissileSystem('player-unit', DEPLOYMENT));

      expect(result.current.deployedMissileSystems.get('player-unit')).toBe(DEPLOYMENT);
    });

    it('forgets a missile system once it is undeployed', () => {
      const { result } = renderHook(() => useDeploymentSession(buildPayload([])));
      act(() => result.current.deployMissileSystem('player-unit', DEPLOYMENT));

      act(() => result.current.undeployMissileSystem('player-unit'));

      expect(result.current.deployedMissileSystems.has('player-unit')).toBe(false);
    });
  });

  it('keeps its handlers stable across renders so memoized map layers stay valid', () => {
    const { result } = renderHook(() => useDeploymentSession(buildPayload([])));
    const before = {
      updateAirbase: result.current.updateAirbase,
      deployMissileSystem: result.current.deployMissileSystem,
      undeployMissileSystem: result.current.undeployMissileSystem,
      deployJammer: result.current.deployJammer,
      undeployJammer: result.current.undeployJammer,
    };

    act(() => result.current.setBudget(createBudgetState(1)));

    expect(result.current.updateAirbase).toBe(before.updateAirbase);
    expect(result.current.deployMissileSystem).toBe(before.deployMissileSystem);
    expect(result.current.undeployMissileSystem).toBe(before.undeployMissileSystem);
    expect(result.current.deployJammer).toBe(before.deployJammer);
    expect(result.current.undeployJammer).toBe(before.undeployJammer);
  });
});
