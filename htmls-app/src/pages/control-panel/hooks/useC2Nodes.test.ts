import type { C2NodeSet, C2SamUnit } from '@/types/generated';
import { describe, it, expect } from 'vitest';
import { act, renderHook } from '@testing-library/react';
import type { Battery } from '@pages/control-panel/logic/batteryGroups';
import { OUTSIDE_OPERATING_ZONE } from '../logic/c2Nodes';
import { readControlPanelPayload } from '../logic/controlPanelPayload';
import type { ControlPanelPayload } from '../logic/controlPanelPayload';
import { useC2Nodes } from './useC2Nodes';

// ============================================================================
// FIXTURES
// ============================================================================
const zone = (latitude: number, longitude: number) => [
  { latitude: latitude - 1, longitude: longitude - 1 },
  { latitude: latitude - 1, longitude: longitude + 1 },
  { latitude: latitude + 1, longitude: longitude + 1 },
  { latitude: latitude + 1, longitude: longitude - 1 },
];

function c2Unit(name: string): C2SamUnit {
  return {
    type: 'rocc',
    name,
    OODADetection: '15/15',
    OODATargeting: '5/5',
    isOutOfComms: false,
    EMCONSetting: 'Radar=Passive',
    isDestroyed: false,
    weaponFree: false,
    pos: { latitude: 23, longitude: 120 },
  };
}

/** Node `a` commands the SAM, node `b` is empty and sits far away. */
function buildC2Data(): C2NodeSet {
  return {
    a: {
      type: 'rocc',
      name: 'A',
      pos: { latitude: 23, longitude: 120 },
      areas: [zone(23, 120)],
      sam: { s1: c2Unit('SAM') },
    },
    b: {
      type: 'rocc',
      name: 'B',
      pos: { latitude: 30, longitude: 130 },
      areas: [zone(30, 130)],
    },
  };
}

function buildBattery(deployedAt?: { latitude: number; longitude: number }): Battery {
  return {
    name: 'SAM',
    missileSystem: 'PAC-3',
    missileSystemType: 'sam',
    deployment: deployedAt
      ? ({
          tacticalAreas: { HA: [zone(deployedAt.latitude, deployedAt.longitude)] },
        } as Battery['deployment'])
      : null,
    status: undefined,
  };
}

function buildPayload(c2Data: C2NodeSet): ControlPanelPayload {
  return { ...readControlPanelPayload(), c2Data };
}

const childKeys = (nodes: ReturnType<typeof useC2Nodes>['nodes']) =>
  Object.fromEntries(nodes.map((node) => [node.key, node.children.map((child) => child.key)]));

// ============================================================================
// TESTS
// ============================================================================
describe('useC2Nodes', () => {
  it('builds the node views from the payload and the SAM batteries', () => {
    const { result } = renderHook(() => useC2Nodes(buildPayload(buildC2Data()), [buildBattery()]));

    expect(childKeys(result.current.nodes)).toEqual({ a: ['s1'], b: [] });
    expect(result.current.nodes[0].children[0].battery?.name).toBe('SAM');
  });

  describe('a redeployed SAM', () => {
    it('moves under the node whose zone it was deployed into', () => {
      const payload = buildPayload(buildC2Data());

      const { result } = renderHook(() =>
        useC2Nodes(payload, [buildBattery({ latitude: 30, longitude: 130 })])
      );

      expect(childKeys(result.current.nodes)).toEqual({ a: [], b: ['s1'] });
    });

    it('stays under that node after its deployment is cancelled', () => {
      const payload = buildPayload(buildC2Data());
      const { result, rerender } = renderHook(({ batteries }) => useC2Nodes(payload, batteries), {
        initialProps: { batteries: [buildBattery({ latitude: 30, longitude: 130 })] },
      });

      rerender({ batteries: [buildBattery()] });

      expect(childKeys(result.current.nodes)).toEqual({ a: [], b: ['s1'] });
    });

    it('goes back to the node the game reports once a fresh payload arrives', () => {
      const { result, rerender } = renderHook(
        ({ payload, batteries }) => useC2Nodes(payload, batteries),
        {
          initialProps: {
            payload: buildPayload(buildC2Data()),
            batteries: [buildBattery({ latitude: 30, longitude: 130 })],
          },
        }
      );
      rerender({ payload: buildPayload(buildC2Data()), batteries: [buildBattery()] });

      expect(childKeys(result.current.nodes)).toEqual({ a: ['s1'], b: [] });
    });
  });

  describe('buildEmconResult', () => {
    it('reports the nodes whose SAM units moved by a real deployment', () => {
      const payload = buildPayload(buildC2Data());
      const { result } = renderHook(() =>
        useC2Nodes(payload, [buildBattery({ latitude: 30, longitude: 130 })])
      );

      expect(result.current.buildEmconResult().c2Nodes).toEqual([
        { guid: 'a', type: 'rocc', name: 'A', sam: {} },
        { guid: 'b', type: 'rocc', name: 'B', sam: { s1: { guid: 's1', name: 'SAM' } } },
      ]);
    });

    it('does not move a SAM whose deployment was cancelled, even though its card stays pinned', () => {
      const payload = buildPayload(buildC2Data());
      const { result, rerender } = renderHook(({ batteries }) => useC2Nodes(payload, batteries), {
        initialProps: { batteries: [buildBattery({ latitude: 30, longitude: 130 })] },
      });
      rerender({ batteries: [buildBattery()] });

      expect(childKeys(result.current.nodes)).toEqual({ a: [], b: ['s1'] });
      expect(result.current.buildEmconResult().c2Nodes).toEqual([]);
    });
  });

  describe('SAM weapons control', () => {
    it('keeps each SAM status until the player touches the checkbox', () => {
      const { result } = renderHook(() =>
        useC2Nodes(buildPayload(buildC2Data()), [buildBattery()])
      );

      expect(result.current.samWeaponsFreeChoice).toBeNull();
      expect(result.current.isAllSamWeaponsFree).toBe(false);
      expect(result.current.buildEmconResult().sams).toEqual([
        { guid: 's1', name: 'SAM', weaponFree: false },
      ]);
    });

    it('applies the choice to the cards and to the submitted result', () => {
      const { result } = renderHook(() =>
        useC2Nodes(buildPayload(buildC2Data()), [buildBattery()])
      );

      act(() => result.current.setSamWeaponsFreeChoice(true));

      expect(result.current.isAllSamWeaponsFree).toBe(true);
      const [child] = result.current.nodes[0].children;
      expect(child.type === 'sam' && child.unit.weaponFree).toBe(true);
      expect(result.current.buildEmconResult().sams).toEqual([
        { guid: 's1', name: 'SAM', weaponFree: true },
      ]);
    });

    it('is not all weapons free when there is no SAM unit', () => {
      const c2Data = buildC2Data();
      delete c2Data.a.sam;

      const { result } = renderHook(() => useC2Nodes(buildPayload(c2Data), []));

      expect(result.current.isAllSamWeaponsFree).toBe(false);
    });
  });

  describe('validateMissilePosition', () => {
    it('lets a SAM battery deploy inside the zone of a node of its type', () => {
      const { result } = renderHook(() =>
        useC2Nodes(buildPayload(buildC2Data()), [buildBattery()])
      );

      expect(
        result.current.validateMissilePosition('SAM', { latitude: 23, longitude: 120 })
      ).toBeNull();
    });

    it('warns when the position is outside every zone', () => {
      const { result } = renderHook(() =>
        useC2Nodes(buildPayload(buildC2Data()), [buildBattery()])
      );

      expect(result.current.validateMissilePosition('SAM', { latitude: 10, longitude: 100 })).toBe(
        OUTSIDE_OPERATING_ZONE
      );
    });
  });
});
