# amphibiousLogistics — 兩棲後勤裝載與任務指派

> 原始碼：`src/modules/landingOps/amphibiousLogistics.lua`

**職責**：管理登陸艦的貨物轉移、運輸任務建立與登陸載具任務指派

---

## 概述

amphibiousLogistics 負責登陸作戰的第二階段——後勤裝載。當登陸艦隊到達錨泊區後，系統依艦型將貨物（車輛、步兵、裝備）從母艦轉移至搭載的直升機與登陸艇，同時建立貨物運輸任務（Cargo Mission）並指派登陸載具執行。

系統採用**資料驅動分派**（Data-Driven Dispatch）架構，透過 `SHIP_TRANSFER_SPECS` 描述符表定義各艦型的貨物轉移規格與任務指派規則，避免針對每型艦船寫硬編碼邏輯。

此外，模組也提供第二波作戰時的貨物重新裝載（`retransferCargos`），用於補充已耗盡彈藥的運輸載具。

---

## 資料驅動分派機制

`SHIP_TRANSFER_SPECS` 定義了各艦型的完整裝載規格：

```
SHIP_TRANSFER_SPECS[]
└── TransferSpec
    ├── dbids: number[]                  -- 適用艦型 DBID
    ├── manifestKey: string              -- 貨物清單索引鍵
    ├── transfers[]                      -- 貨物轉移規則
    │   ├── platform: string             -- 目標平台類型（Aircraft/Boats）
    │   ├── configKey: string            -- 區域配置鍵
    │   └── loadoutIdx: integer          -- 掛載索引
    └── assignments[]                    -- 任務指派規則
        ├── platform: string             -- 平台類型
        └── configKey: string            -- 區域配置鍵
```

### 艦型對應規格

| 艦型 | manifestKey | 轉移目標 | 任務指派 |
|---|---|---|---|
| Type 075 / Type 076 | `type075` | 氣墊船（loadout 1）、運輸直升機（loadout 1, 2） | 氣墊船、運輸直升機、攻擊直升機 |
| Type 071 | `type071` | 氣墊船（loadout 1）、運輸直升機（loadout 1） | 氣墊船、運輸直升機 |

---

## 貨物操作流程

```mermaid
flowchart TD
    START["transferAndAssign()"]
    ITER_UNIT["遍歷錨泊區單位"]
    IN_AREA{單位在<br>anchorageArea?}
    FIND_SPEC["findTransferSpec<br>匹配艦型"]
    TRANSFER["processShipTransfers<br>依 spec.transfers 轉移貨物"]
    ASSIGN["processShipAssignments<br>依 spec.assignments 指派任務"]
    DONE["完成"]

    START --> ITER_UNIT --> IN_AREA
    IN_AREA -->|是| FIND_SPEC --> TRANSFER --> ASSIGN
    ASSIGN -.-> ITER_UNIT
    IN_AREA -->|否| ITER_UNIT
    ITER_UNIT -->|遍歷完成| DONE
```

### 貨物轉移細節

`transferCargo` 函數將母艦貨物分配至搭載平台：

1. 取得母艦的搭載單元清單（`embarkedUnits`）
2. 依平台 DBID 與掛載 ID（`loadoutdbid`）匹配目標載具
3. 對每個匹配的載具執行 `updateCargo`：從母艦刪除貨物、在載具上建立對應貨物
4. 支援共用貨物清單（所有載具相同）與個別貨物清單（依索引分配）

### 建築物 / Cargo Proxy 裝載流程

`loadCargo` 主要供其他模組將地面單位轉為 cargo proxy 使用，目前 `missileSystem.hideUnit` 會用它把 TEL / 補給車載入建築物。

流程如下：

1. 依 `unitCtx.name` 取得來源單位，並展開 group member 清單
2. 透過 `createCargoProxy` 在目標載具或建築物上建立對應 cargo proxy
3. 對 cargo proxy 執行 `stripCargoProxyMounts`：清空彈匣並移除原有 mounts
4. 將來源單位的 mounts 複製到 cargo proxy，並根據 `unitCtx.weaponDBID` 統計需要保留的武器數量
5. 執行 `syncWeaponReloads`：先清除 cargo proxy 現有 mount weapon 的 reload，再依統計結果回填實際彈量
6. 複製群組名稱與單位名稱後，刪除原始來源單位

### 武器同步規則

`loadCargo` 的武器同步分成兩個步驟：

| 步驟 | 行為 |
|---|---|
| 清除既有 reload | 掃描 cargo proxy 目前 `mounts[].mount_weapons[]`，若 `wpn_default > 0` 則以 `remove = true` 清除 reload |
| 回填目標 reload | 僅針對 `unitCtx.weaponDBID` 指定的武器，依來源單位實際 `wpn_current` 回填數量 |

這表示 `weaponDBID` 控制的是「哪些武器要保留並回填」，而不是「哪些武器要先被清除」。

---

## 錨泊區監控

`getUnitsInAnchorageArea` 監控艦隊到達狀態：

| 檢查項目 | 說明 |
|---|---|
| 艦型過濾 | 僅計算 `AMPHIBIOUS_SHIP_DBIDS` 中的兩棲艦船 |
| 移動狀態 | 若有艦船 `unitstate != "Unassigned"` 則判定仍在移動 |
| 區域判定 | 艦船須在 `anchorageArea` 或 `lstAnchorageArea` 內 |

### 兩棲艦船 DBID 對照

| 艦型 | 常數路徑 |
|---|---|
| Type 075 LHD | `constants.PLATFORMS.TYPE_075` |
| Type 076 LHD | `constants.PLATFORMS.TYPE_076` |
| Type 071 LPD | `constants.PLATFORMS.TYPE_071` |
| Type 072III LST | `constants.PLATFORMS.TYPE_072III` |
| Type 072A LST | `constants.PLATFORMS.TYPE_072A` |
| Type 072A (2) LST | `constants.PLATFORMS.TYPE_072A_2` |
| Type 073A LST | `constants.PLATFORMS.TYPE_073A` |
| Ferry | `constants.PLATFORMS.FERRY` |
| Barge | `constants.PLATFORMS.BARGE` |

---

## 公開 API

| 函數 | 說明 |
|---|---|
| `getUnitsInAnchorageArea(zone, filteredUnits)` | 取得錨泊區內艦船清單及移動狀態 |
| `createCargoMissions(zone)` | 為作戰區建立貨物運輸任務 |
| `transferAndAssign(zone, unitsInAnchorageArea)` | 執行貨物轉移並指派登陸載具至任務 |
| `transferAndAssignTransportAircraft(transportAircraft)` | 陸基運輸機貨物轉移與任務指派 |
| `retransferCargos(zone, units)` | 第二波作戰的貨物重新裝載 |
| `updateCargo(fromUnit, toUnit, cargoItem)` | 單筆貨物從來源轉移至目標 |
| `deleteCargo(fromUnit, cargoItem)` | 從單位刪除指定貨物 |
| `transferCargo(fromUnit, platformType, platformDBID, loadoutDBID, cargoItems)` | 依平台規格轉移貨物至搭載單位 |
| `loadCargo(base, unitCtx, sideName)` | 將地面單位轉為 cargo proxy 並載入目標載具或建築物 |

---

## 日誌輸出

五個公開函式各自對應一份 `LogFormat.report`，scope 依對象而異（`zone=` / `ship=` / `transportAircraft`）。

```
[amphibiousLogistics] ship="Type 075 #1": Load cargo | total=2 ok=1 skip=1
  [OK]   unit="PHL-16 #1" index=1
  [SKIP] guid=U-4471 index=2 reason=unit_not_found
```

`createSingleCargoMission` 的三個失敗點原本一律收斂成 `false` 且不輸出任何日誌，現在各自帶具體 `reason`，並把已建立的任務留在 info log：

```
[amphibiousLogistics] zone=Taoyuan: Create cargo missions | total=1 ok=1
  [OK]   mission="Taoyuan Boat Ferry" platform=boat
```
```
（error sink）zone=Taoyuan: Create cargo missions | total=1 fail=1
  [FAIL] mission="Taoyuan Helo Ferry" platform=transportHelicopter reason=set_doctrine_failed
```

`reason` 三值：`add_mission_failed`、`set_mission_failed`、`set_doctrine_failed`。

---

## 相關模組

- [shipMovement](shipMovement.md) — 前置階段：艦隊移動至錨泊區
- [amphibiousAssault](amphibiousAssault.md) — 後續階段：ACV 釋放時呼叫 `deleteCargo`
- `assignMission` — `transferAndAssign` 呼叫 `AssignMission.assignEmbarkedUnitsToMissions`
- [系統架構](README.md)
