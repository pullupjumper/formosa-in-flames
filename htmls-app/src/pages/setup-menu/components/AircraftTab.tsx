import { useState } from 'react';
import type { Airbase, BudgetState } from '@/types/setupMenu';
import { CONFIG } from '@/types/setupMenu';
import { BaseMap, AirbaseMarkers } from '@/components/Map';

interface AircraftTabProps {
  airbases: Airbase[];
  budget: BudgetState;
  onSpendBudget: (amount?: number) => boolean;
  onRefundBudget: (amount?: number) => void;
  onUpdateAirbase: (index: number, updater: (base: Airbase) => Airbase) => void;
  sideName: string;
}

export function AircraftTab({
  airbases,
  budget,
  onSpendBudget,
  onRefundBudget,
  onUpdateAirbase,
  sideName,
}: AircraftTabProps) {
  const [selectedBaseIndex, setSelectedBaseIndex] = useState<number | null>(null);
  const [coordinates, setCoordinates] = useState<{ lat: number; lng: number } | null>(null);

  const percentage = (budget.current / budget.total) * 100;
  const selectedBase = selectedBaseIndex !== null ? airbases[selectedBaseIndex] : null;

  const handleMapClick = (lat: number, lng: number) => {
    setCoordinates({ lat, lng });
  };

  const handleAirbaseClick = (index: number) => {
    setSelectedBaseIndex(index);
  };

  return (
    <div className="flex h-full">
      {/* Map Container */}
      <div className="flex-1">
        <BaseMap onMapClick={handleMapClick} sideName={sideName}>
          <AirbaseMarkers airbases={airbases} onAirbaseClick={handleAirbaseClick} />
        </BaseMap>
      </div>

      {/* Controls Panel */}
      <div className="w-80 overflow-y-auto border-l border-dark-border bg-dark-panel p-4">
        {/* Budget Section */}
        <div className="mb-5 border-b border-dark-border pb-4">
          <div className="mb-4 text-xs font-bold uppercase tracking-wide text-text-secondary">
            Loadout Budget
          </div>
          <div className="mb-2">
            <div className="mb-2 text-xs font-semibold">Remaining Budget</div>
            <div
              className={`mb-1 text-2xl font-bold ${
                budget.current < 200
                  ? 'text-status-danger'
                  : budget.current < 400
                    ? 'text-status-warning'
                    : 'text-status-success'
              }`}
            >
              {budget.current}
            </div>
            <div className="text-[11px] text-text-secondary">
              Used: {budget.used} / Total: {budget.total}
            </div>
            <div className="mt-2 h-1 rounded-sm bg-dark-border">
              <div
                className={`h-full rounded-sm transition-[width] duration-300 ${
                  budget.current < 200
                    ? 'bg-status-danger'
                    : budget.current < 400
                      ? 'bg-status-warning'
                      : 'bg-status-success'
                }`}
                style={{ width: `${percentage}%` }}
              />
            </div>
          </div>
        </div>

        {/* Base Editor Section */}
        <div className="mb-5">
          <div className="mb-4 text-xs font-bold uppercase tracking-wide text-text-secondary">
            Base Editor
          </div>
          {selectedBase ? (
            <BaseEditor
              base={selectedBase}
              baseIndex={selectedBaseIndex!}
              onSpendBudget={onSpendBudget}
              onRefundBudget={onRefundBudget}
              onUpdateAirbase={onUpdateAirbase}
            />
          ) : (
            <div className="text-xs italic text-text-secondary">
              Select an airbase on the map to edit loadouts
            </div>
          )}
        </div>

        {/* Coordinates Display */}
        {coordinates && (
          <div className="mt-5 font-mono text-[11px] text-text-secondary">
            Latitude: {coordinates.lat.toFixed(6)}°, Longitude: {coordinates.lng.toFixed(6)}°
          </div>
        )}
      </div>
    </div>
  );
}

interface BaseEditorProps {
  base: Airbase;
  baseIndex: number;
  onSpendBudget: (amount?: number) => boolean;
  onRefundBudget: (amount?: number) => void;
  onUpdateAirbase: (index: number, updater: (base: Airbase) => Airbase) => void;
}

function BaseEditor({
  base,
  baseIndex,
  onSpendBudget,
  onRefundBudget,
  onUpdateAirbase,
}: BaseEditorProps) {
  const adjustAircraft = (unitIndex: number, delta: number) => {
    const unit = base.embarkedUnits?.[unitIndex];
    if (!unit?.loadouts?.[0]) return;

    const newNum = unit.loadouts[0].num + delta;
    if (newNum < 0) return;

    if (delta > 0 && !onSpendBudget()) {
      alert('Insufficient budget!');
      return;
    }
    if (delta < 0) onRefundBudget();

    onUpdateAirbase(baseIndex, (prev) => ({
      ...prev,
      embarkedUnits: prev.embarkedUnits?.map((u, i) =>
        i === unitIndex
          ? {
              ...u,
              loadouts: u.loadouts?.map((lo, li) => (li === 0 ? { ...lo, num: newNum } : lo)),
            }
          : u
      ),
    }));
  };

  const adjustLoadout = (loadoutIndex: number, delta: number) => {
    const loadout = base.loadouts?.[loadoutIndex];
    if (!loadout) return;

    const newNum = loadout.num + delta;
    if (newNum < 0) return;

    if (delta > 0 && !onSpendBudget()) {
      alert('Insufficient budget!');
      return;
    }
    if (delta < 0) onRefundBudget();

    onUpdateAirbase(baseIndex, (prev) => ({
      ...prev,
      loadouts: prev.loadouts?.map((lo, i) => (i === loadoutIndex ? { ...lo, num: newNum } : lo)),
    }));
  };

  return (
    <div>
      <div className="mb-2.5 font-bold">{base.name}</div>

      {/* Deployed Aircraft */}
      {base.embarkedUnits && base.embarkedUnits.length > 0 && (
        <div className="mb-4">
          <div className="mb-2 text-[11px] text-text-secondary">DEPLOYED AIRCRAFT</div>
          {base.embarkedUnits.map((unit, unitIndex) => {
            const total = unit.loadouts?.reduce((sum, lo) => sum + lo.num, 0) || 0;
            return (
              <LoadoutControl
                key={unitIndex}
                name={unit.platformName}
                subtitle={unit.name}
                quantity={total}
                onDecrease={() => adjustAircraft(unitIndex, -1)}
                onIncrease={() => adjustAircraft(unitIndex, 1)}
              />
            );
          })}
        </div>
      )}

      {/* Base Ammunition Storage */}
      {base.loadouts && base.loadouts.length > 0 && (
        <div>
          <div className="mb-2 text-[11px] text-text-secondary">BASE AMMUNITION STORAGE</div>
          {base.loadouts.map((loadout, loadoutIndex) => (
            <LoadoutControl
              key={loadoutIndex}
              name={loadout.name || `Loadout ${loadout.loadoutId}`}
              subtitle={`Cost: ${CONFIG.LOADOUT_COST}`}
              quantity={loadout.num}
              onDecrease={() => adjustLoadout(loadoutIndex, -1)}
              onIncrease={() => adjustLoadout(loadoutIndex, 1)}
            />
          ))}
        </div>
      )}
    </div>
  );
}

interface LoadoutControlProps {
  name: string;
  subtitle: string;
  quantity: number;
  onDecrease: () => void;
  onIncrease: () => void;
}

function LoadoutControl({ name, subtitle, quantity, onDecrease, onIncrease }: LoadoutControlProps) {
  return (
    <div className="mb-2 flex items-center justify-between border-b border-white/5 py-1">
      <div className="flex-1">
        <div className="text-xs font-semibold">{name}</div>
        <div className="text-[10px] text-text-secondary">{subtitle}</div>
      </div>
      <div className="flex items-center gap-1.5">
        <button
          className="flex h-6 w-6 items-center justify-center rounded-sm border border-dark-border bg-dark-hover font-bold hover:border-accent-blue hover:bg-accent-blue"
          onClick={onDecrease}
        >
          -
        </button>
        <div className="min-w-5 text-center text-xs font-semibold">{quantity}</div>
        <button
          className="flex h-6 w-6 items-center justify-center rounded-sm border border-dark-border bg-dark-hover font-bold hover:border-accent-blue hover:bg-accent-blue"
          onClick={onIncrease}
        >
          +
        </button>
      </div>
    </div>
  );
}
