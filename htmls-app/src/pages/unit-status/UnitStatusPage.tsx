import { useState } from "react";
import { Table, Th, Td, Tr, EmptyRow, ProgressBar } from "@/components/Table";
import {
  formatTimestamp,
  calculateProgress,
  isDataEmpty,
} from "@/utils/format";
import { UNIT_STATUS_DATA } from "@/data/unitStatusData";
import type {
  SignalData,
  MissileSystemData,
  C2Data,
  C2Node,
  C2Unit,
  Base,
  LandingUnitsData,
  UnitStatusData,
} from "@/types/unitStatus";

// ============================================================================
// GLOBAL TYPE DECLARATION
// ============================================================================
declare global {
  interface Window {
    __INJECT_SIGNALS__?: string;
    __INJECT_LAUNCHERS__?: string;
    __INJECT_C2__?: string;
    __INJECT_BASE_WEAPONS__?: string;
    __INJECT_LANDING_UNITS__?: string;
  }
}

// ============================================================================
// DATA LOADER
// ============================================================================
function loadInjectedData(): UnitStatusData {
  const parseJSON = <T,>(
    str: string | undefined,
    fallback: T,
    name: string,
  ): T => {
    // Debug log - remove in production
    console.log(`[${name}] raw value:`, str);

    if (!str) {
      console.log(`[${name}] empty, using fallback`);
      return fallback;
    }

    const trimmed = str.trim();
    if (trimmed === "[]" || trimmed === "{}" || trimmed === "") {
      console.log(`[${name}] empty array/object, using fallback`);
      return fallback;
    }

    try {
      const parsed = JSON.parse(trimmed) as T;
      console.log(`[${name}] parsed successfully:`, parsed);
      return parsed;
    } catch (e) {
      console.error(`[${name}] JSON parse error:`, e);
      return fallback;
    }
  };

  return {
    signals: parseJSON<SignalData[]>(
      window.__INJECT_SIGNALS__,
      UNIT_STATUS_DATA.signals,
      "SIGNALS",
    ),
    launchers: parseJSON<MissileSystemData>(
      window.__INJECT_LAUNCHERS__,
      UNIT_STATUS_DATA.launchers,
      "LAUNCHERS",
    ),
    c2: parseJSON<C2Data>(window.__INJECT_C2__, UNIT_STATUS_DATA.c2, "C2"),
    baseWeapons: parseJSON<Base[]>(
      window.__INJECT_BASE_WEAPONS__,
      UNIT_STATUS_DATA.baseWeapons,
      "BASE_WEAPONS",
    ),
    landingUnits: parseJSON<LandingUnitsData>(
      window.__INJECT_LANDING_UNITS__,
      UNIT_STATUS_DATA.landingUnits,
      "LANDING_UNITS",
    ),
  };
}

// ============================================================================
// CONSTANTS
// ============================================================================
const TABS = [
  { id: "signal-data", label: "Signal Data" },
  { id: "mobile-launchers", label: "Missile Systems" },
  { id: "c2-nodes", label: "C2 Nodes" },
  { id: "base-weapons", label: "Base Weapons" },
  { id: "landing-units", label: "Landing Units" },
] as const;

type TabId = (typeof TABS)[number]["id"];

// ============================================================================
// MAIN COMPONENT
// ============================================================================
function UnitStatusPage() {
  const [activeTab, setActiveTab] = useState<TabId>("signal-data");
  const [data] = useState(loadInjectedData);

  // Filter visible tabs based on data availability
  const visibleTabs = TABS.filter((tab) => {
    switch (tab.id) {
      case "signal-data":
        return !isDataEmpty(data?.signals);
      case "mobile-launchers":
        return !isDataEmpty(data?.launchers);
      case "c2-nodes":
        return !isDataEmpty(data?.c2);
      case "base-weapons":
        return !isDataEmpty(data?.baseWeapons);
      case "landing-units":
        return !isDataEmpty(data?.landingUnits);
      default:
        return true;
    }
  });

  // Show all tabs if all data is empty (for demo purposes)
  const displayTabs = visibleTabs.length > 0 ? visibleTabs : TABS;

  return (
    <div className="flex h-screen flex-col">
      {/* Top Bar */}
      <div className="flex h-12.5 items-center justify-between border-b border-dark-border bg-dark-panel px-5">
        <div className="text-sm font-medium text-text-secondary">
          <span className="text-text-primary">UNIT STATUS</span> / DASHBOARD
        </div>
      </div>

      {/* Tab Container */}
      <div className="flex border-b border-dark-border bg-dark-bg px-5">
        {displayTabs.map((tab) => (
          <button
            key={tab.id}
            className={`border-b-[3px] px-4 py-3 text-[13px] font-semibold uppercase tracking-wide transition-colors ${
              activeTab === tab.id
                ? "border-accent-blue text-accent-blue"
                : "border-transparent text-text-secondary hover:text-text-primary"
            }`}
            onClick={() => setActiveTab(tab.id)}
          >
            {tab.label}
          </button>
        ))}
      </div>

      {/* Content */}
      <div className="flex-1 overflow-auto p-5">
        <div className="overflow-x-auto rounded-sm border border-dark-border bg-dark-panel">
          {activeTab === "signal-data" && (
            <SignalDataTable data={data.signals} />
          )}
          {activeTab === "mobile-launchers" && (
            <MobileLaunchersTable data={data.launchers} />
          )}
          {activeTab === "c2-nodes" && <C2NodesTable data={data.c2} />}
          {activeTab === "base-weapons" && (
            <BaseWeaponsTable data={data.baseWeapons} />
          )}
          {activeTab === "landing-units" && (
            <LandingUnitsTable data={data.landingUnits} />
          )}
        </div>
      </div>
    </div>
  );
}

// ============================================================================
// TABLE COMPONENTS
// ============================================================================
interface SignalDataTableProps {
  data: SignalData[];
}

function SignalDataTable({ data }: SignalDataTableProps) {
  const safeData = Array.isArray(data) ? data : [];

  return (
    <Table>
      <thead>
        <tr>
          <Th>NAME</Th>
          <Th>TYPE</Th>
          <Th>AUTODETECTABLE</Th>
          <Th>FIRST DETECTED</Th>
          <Th>LAST DETECTED</Th>
          <Th className="text-right">DETECTION COUNT</Th>
          <Th className="text-right">CONFIDENCE</Th>
          <Th className="text-right">DETECTION LEVEL</Th>
        </tr>
      </thead>
      <tbody>
        {safeData.length === 0 ? (
          <EmptyRow colSpan={8} message="No signal data available" />
        ) : (
          safeData.map((signal, index) => (
            <Tr key={index}>
              <Td>{signal.name || "N/A"}</Td>
              <Td>{signal.type ? signal.type.toUpperCase() : "N/A"}</Td>
              <Td>{signal.autodetectable ? "TRUE" : "FALSE"}</Td>
              <Td>{formatTimestamp(signal.firstDetected)}</Td>
              <Td>{formatTimestamp(signal.lastDetected)}</Td>
              <Td className="text-right">{signal.detectionCount || 0}</Td>
              <Td className="text-right">
                {Math.floor((signal.confidence || 0) * 100)}%
              </Td>
              <Td className="text-right">
                {signal.currentDetectionLevel || 0}
              </Td>
            </Tr>
          ))
        )}
      </tbody>
    </Table>
  );
}

interface MobileLaunchersTableProps {
  data: MissileSystemData;
}

function MobileLaunchersTable({ data }: MobileLaunchersTableProps) {
  const areas = Object.keys(data || {});

  return (
    <Table>
      <thead>
        <tr>
          <Th>NAME</Th>
          <Th>MISSILE SYSTEM</Th>
          <Th>FIRING UNIT STATE</Th>
          <Th style={{ width: 200 }}>FIRING UNIT RELOAD</Th>
          <Th>RESUPPLY UNIT STATE</Th>
          <Th style={{ width: 200 }}>RESUPPLY UNIT RELOAD</Th>
          <Th className="text-right">MISSILES (AMMO)</Th>
          <Th className="text-right">MISSILES (AHA)</Th>
        </tr>
      </thead>
      <tbody>
        {areas.length === 0 ? (
          <EmptyRow colSpan={8} message="No launcher data available" />
        ) : (
          areas.map((area) => {
            const units = Array.isArray(data[area]) ? data[area] : [];
            return units.map((unit, index) => {
              const firingProgress = calculateProgress(
                unit.firingUnitReloadTime,
                unit.defaultReloadTime,
              );
              const resupplyProgress = calculateProgress(
                unit.resupplyUnitReloadTime,
                unit.defaultReloadTime,
              );

              return (
                <Tr key={`${area}-${index}`}>
                  <Td>{unit.name}</Td>
                  <Td>{unit.missileSystem.toUpperCase()}</Td>
                  <Td>{unit.firingUnitState}</Td>
                  <Td>
                    {unit.firingUnitReloadTime >= 0 && (
                      <ProgressBar percentage={firingProgress} />
                    )}
                  </Td>
                  {index === 0 && (
                    <>
                      <Td rowSpan={units.length}>{unit.resupplyUnitState}</Td>
                      <Td rowSpan={units.length}>
                        {unit.resupplyUnitReloadTime >= 0 && (
                          <ProgressBar percentage={resupplyProgress} />
                        )}
                      </Td>
                      <Td className="text-right" rowSpan={units.length}>
                        {unit.missilesInAmmoVehicles}
                      </Td>
                      <Td className="text-right" rowSpan={units.length}>
                        {unit.missilesInAHA}
                      </Td>
                    </>
                  )}
                </Tr>
              );
            });
          })
        )}
      </tbody>
    </Table>
  );
}

interface C2NodesTableProps {
  data: C2Data;
}

function C2NodesTable({ data }: C2NodesTableProps) {
  // Flatten C2 data: supports both direct nodes { ROCC: {...}, TAAOC: {...} }
  // and wrapped format { C2: { guid1: {...}, guid2: {...} } }
  const flatNodes: Record<string, C2Node> = {};
  for (const [key, value] of Object.entries(data || {})) {
    if (value && typeof value === "object" && "name" in value) {
      // Direct node (e.g. ROCC, TAAOC)
      flatNodes[key] = value as C2Node;
    } else if (value && typeof value === "object") {
      // Wrapped group (e.g. C2: { guid1: {...} })
      for (const [subKey, subValue] of Object.entries(
        value as Record<string, C2Node>,
      )) {
        flatNodes[subKey] = subValue;
      }
    }
  }
  const nodeKeys = Object.keys(flatNodes);

  return (
    <Table>
      <thead>
        <tr>
          <Th>C2 NODE</Th>
          <Th>NAME</Th>
          <Th>OODA DETECTION</Th>
          <Th>OODA TARGETING</Th>
          <Th>OUT OF COMMS</Th>
          <Th>EMCON SETTING</Th>
          <Th>DESTROYED</Th>
        </tr>
      </thead>
      <tbody>
        {nodeKeys.length === 0 ? (
          <EmptyRow colSpan={7} message="No C2 node data available" />
        ) : (
          nodeKeys.map((nodeKey) => {
            const node = flatNodes[nodeKey];
            const units: { unit: C2Unit; type: string }[] = [];

            if (node.SAM) {
              Object.values(node.SAM).forEach((unit) =>
                units.push({ unit, type: "SAM" }),
              );
            }
            if (node.radar) {
              Object.values(node.radar).forEach((unit) =>
                units.push({ unit, type: "Radar" }),
              );
            }

            if (units.length === 0) {
              return (
                <Tr key={nodeKey}>
                  <Td>{node.name}</Td>
                  <Td colSpan={6} className="text-text-secondary">
                    No subordinate units
                  </Td>
                </Tr>
              );
            }

            return units.map((item, index) => (
              <Tr key={`${nodeKey}-${index}`}>
                {index === 0 && <Td rowSpan={units.length}>{node.name}</Td>}
                <Td>
                  {item.unit.name} ({item.type})
                </Td>
                <Td>{item.unit.OODADetection}</Td>
                <Td>{item.unit.OODATargeting}</Td>
                <Td
                  className={
                    item.unit.isOutOfComms
                      ? "text-status-danger"
                      : "text-status-success"
                  }
                >
                  {item.unit.isOutOfComms ? "YES" : "NO"}
                </Td>
                <Td>{item.unit.EMCONSetting}</Td>
                <Td
                  className={
                    item.unit.isDestroyed
                      ? "text-status-danger"
                      : "text-status-success"
                  }
                >
                  {item.unit.isDestroyed ? "YES" : "NO"}
                </Td>
              </Tr>
            ));
          })
        )}
      </tbody>
    </Table>
  );
}

interface BaseWeaponsTableProps {
  data: Base[];
}

function BaseWeaponsTable({ data }: BaseWeaponsTableProps) {
  const safeData = Array.isArray(data) ? data : [];

  return (
    <Table>
      <thead>
        <tr>
          <Th>BASE NAME</Th>
          <Th>WEAPON NAME</Th>
          <Th className="text-right">CURRENT WEAPONS</Th>
        </tr>
      </thead>
      <tbody>
        {safeData.length === 0 ? (
          <EmptyRow colSpan={3} message="No base weapons data available" />
        ) : (
          safeData.map((base) => {
            const wpns = Array.isArray(base.wpns) ? base.wpns : [];
            return wpns.map((weapon, index) => (
              <Tr key={`${base.name}-${index}`}>
                {index === 0 && <Td rowSpan={wpns.length || 1}>{base.name}</Td>}
                <Td>{weapon.name}</Td>
                <Td className="text-right">{weapon.currWpn}</Td>
              </Tr>
            ));
          })
        )}
      </tbody>
    </Table>
  );
}

interface LandingUnitsTableProps {
  data: LandingUnitsData;
}

function LandingUnitsTable({ data }: LandingUnitsTableProps) {
  const areas = Object.keys(data || {});

  return (
    <Table>
      <thead>
        <tr>
          <Th>AREA</Th>
          <Th>UNIT TYPE</Th>
          <Th className="text-right">COUNT</Th>
        </tr>
      </thead>
      <tbody>
        {areas.length === 0 ? (
          <EmptyRow colSpan={3} message="No landing units data available" />
        ) : (
          areas.map((area) => {
            const units = data[area] || {};
            const unitTypes = Object.keys(units);

            return unitTypes.map((unitType, index) => (
              <Tr key={`${area}-${unitType}`}>
                {index === 0 && <Td rowSpan={unitTypes.length}>{area}</Td>}
                <Td>{unitType}</Td>
                <Td className="text-right">{units[unitType]}</Td>
              </Tr>
            ));
          })
        )}
      </tbody>
    </Table>
  );
}

export default UnitStatusPage;
