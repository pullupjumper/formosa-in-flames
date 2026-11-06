import type { EmconResult } from '@/types/generated';
import { useCallback, useMemo, useState } from 'react';
import type { Coordinate } from '@/types/geo';
import type { Battery } from '@pages/control-panel/logic/batteryGroups';
import {
  applySamWeaponsFree,
  buildC2MapLayers,
  buildC2NodeViews,
  collectC2ContextUpdates,
  collectDeployedPlacements,
  collectSamUnits,
  getSamDeploymentWarning,
} from '../logic/c2Nodes';
import type { ControlPanelPayload } from '../logic/controlPanelPayload';

const NO_PINNED_NODES: ReadonlyMap<string, string> = new Map();

/**
 * State of the C2 Nodes section: the node views built from the injected C2 data
 * and the SAM batteries, where each SAM was last deployed, and the SAM weapons
 * control choice. Also builds the SAM part of the submitted result.
 */
export function useC2Nodes(payload: ControlPanelPayload, samBatteries: Battery[]) {
  const { c2Data } = payload;

  // Where each SAM was last deployed, so cancelling keeps its card under that node;
  // a fresh payload is the game's word and clears it
  const [pinned, setPinned] = useState({
    data: c2Data,
    nodes: new Map<string, string>(),
  });
  const pinnedNodes = pinned.data === c2Data ? pinned.nodes : NO_PINNED_NODES;

  const c2Nodes = useMemo(
    () => buildC2NodeViews(c2Data, samBatteries, pinnedNodes),
    [c2Data, samBatteries, pinnedNodes]
  );
  const newPlacements = [...collectDeployedPlacements(c2Nodes)].filter(
    ([unit, node]) => pinnedNodes.get(unit) !== node
  );
  if (newPlacements.length > 0) {
    setPinned({ data: c2Data, nodes: new Map([...pinnedNodes, ...newPlacements]) });
  }

  const validateMissilePosition = useCallback(
    (unitKey: string, position: Coordinate) => getSamDeploymentWarning(c2Nodes, unitKey, position),
    [c2Nodes]
  );

  // null until the player touches the checkbox; until then the SAMs keep their own status
  const [samWeaponsFreeChoice, setSamWeaponsFreeChoice] = useState<boolean | null>(null);

  // Cards, checkbox and submitted result all read the nodes with the choice applied
  const shownNodes = applySamWeaponsFree(c2Nodes, samWeaponsFreeChoice);
  const samUnits = collectSamUnits(shownNodes);
  const layers = useMemo(() => buildC2MapLayers(c2Nodes, pinnedNodes), [c2Nodes, pinnedNodes]);

  const buildEmconResult = (): EmconResult => ({
    sams: samUnits,
    c2Nodes: collectC2ContextUpdates(
      c2Data,
      // Only SAMs that are really deployed move; a pinned card is just a display hold
      buildC2NodeViews(c2Data, samBatteries)
    ),
  });

  return {
    nodes: shownNodes,
    layers,
    isAllSamWeaponsFree: samUnits.length > 0 && samUnits.every((sam) => sam.weaponFree),
    samWeaponsFreeChoice,
    setSamWeaponsFreeChoice,
    validateMissilePosition,
    buildEmconResult,
  };
}
