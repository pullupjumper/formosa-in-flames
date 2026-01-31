# Missile System 模組架構文件

本文件說明 `src/modules/missileSystem.lua` 的設計架構與運行流程。

## 概述

TEL（Transporter Erector Launcher）機動飛彈系統模組，管理發射單元、補給單元、彈藥庫三者之間的再裝填循環。採用 **狀態機 + 事件驅動** 架構。

支援的武器系統：`srbm`、`mrbm`、`mlrs`、`glcm`、`ascm`

---

## 狀態機

### 狀態定義

| 狀態 | 值 | 說明 |
|------|:--:|------|
| `STATIC` | 0 | 靜止待命，可接受新指令 |
| `REPOSITIONING` | 1 | 正在移動至目標位置 |
| `RELOAD` | 2 | 已抵達裝填點，等待裝填完成 |
| `HIDE` | 3 | 已進入隱蔽區域，武器管制為 HOLD |

### 狀態轉移圖

```mermaid
stateDiagram-v2
    [*] --> STATIC: 初始化

    STATIC --> REPOSITIONING: 彈量低於門檻，移動至 RL
    REPOSITIONING --> RELOAD: 抵達 RL，與補給單元會合
    REPOSITIONING --> STATIC: 抵達 RL，未會合
    RELOAD --> REPOSITIONING: 裝填完成，移動至 HA
    REPOSITIONING --> HIDE: 抵達 HA

    HIDE --> REPOSITIONING: 收到部署指令，移動至 FP
    REPOSITIONING --> STATIC: 抵達 FP，WCS=FREE

    note right of RELOAD: 等待 reloadTime 秒
    note right of HIDE: WCS=HOLD，雷達靜默
```

---

## 位置類型

### 作戰區域定義

| 代號 | 名稱 | 用途 | Zone 類型 |
|:----:|------|------|-----------|
| `FP` | Firing Point | 射擊陣地，WCS 設為 FREE | Standard |
| `HA` | Hide Area | 隱蔽區，射後轉移用 | Standard |
| `RL` | Reload Point | 裝填點，發射單元與補給單元會合 | Standard |
| `AHA` | Ammo Holding Area | 彈藥集結區，補給單元與彈藥庫會合 | Standard |
| `MASK` | Mask | 地形遮蔽區 | Custom Environment |

### 位置關係圖

```mermaid
flowchart TB
    subgraph 作戰區域
        FP["FP<br>射擊陣地"]
        HA["HA<br>隱蔽區"]
        RL["RL<br>裝填點"]
    end

    subgraph 後勤區域
        AHA["AHA<br>彈藥集結區"]
        DEPOT[("彈藥庫")]
    end

    FP <-->|射後轉移| HA
    HA <-->|低彈量| RL
    RL <-->|補給車往返| AHA
    AHA --- DEPOT
```

---

## 三級供應鏈

### 彈藥流向

```mermaid
flowchart LR
    DEPOT[("彈藥庫<br>Ammunition")]
    RESUPPLY["補給單元<br>Resupply Unit"]
    FIRING["發射單元<br>Firing Unit"]

    DEPOT -->|transferAmmunition| RESUPPLY
    RESUPPLY -->|reload| FIRING

    style DEPOT fill:#0f9960
    style RESUPPLY fill:#d9822b
    style FIRING fill:#137cbd
```

### 補給循環時序圖

```mermaid
sequenceDiagram
    participant FU as 發射單元
    participant RU as 補給單元
    participant AD as 彈藥庫

    Note over FU: 彈量低於門檻
    FU->>FU: moveToReloadPoint()
    FU->>RU: 在 RL 會合

    Note over FU,RU: 等待 reloadTime
    RU->>FU: reload()
    FU->>FU: moveToHideArea()

    Note over RU: 彈量歸零
    RU->>RU: moveToAmmoHoldingArea()
    RU->>AD: 在 AHA 會合

    Note over RU,AD: 等待 reloadTime
    AD->>RU: transferAmmunition()
    RU->>RU: moveToReloadPoint()
```

---

## 事件驅動架構

### 雙路徑觸發機制

```mermaid
flowchart TB
    subgraph 定時檢查["定時檢查（每 5 分鐘）"]
        SCHED[scheduledReloadHideCheck.lua]
        CHECK[checkMissileSystemState]
        SCHED --> CHECK
        CHECK --> PFU[processFiringUnits]
        CHECK --> PRU[processResupplyUnits]
    end

    subgraph 區域觸發["區域觸發（即時）"]
        MOVE[moveToPosition.lua]
        MOVE --> |進入 FP| WCS[setWCSToFree]
        MOVE --> |進入 HA| HIDE[setStateToHIDE]
        MOVE --> |進入 RL| RLCHECK{會合檢查}
        MOVE --> |進入 AHA| AHACHECK{會合檢查}
        RLCHECK --> |成功| RELOAD1[setReloadStartTime]
        RLCHECK --> |失敗| STATIC1[setStateToStatic]
        AHACHECK --> |成功| RELOAD2[setReloadStartTime]
        AHACHECK --> |失敗| STATIC2[setStateToStatic]
    end

    PFU -.->|偵測低彈量| MOVE
    PRU -.->|偵測彈量歸零| MOVE
```

---

## 公開 API

### 初始化函數

| 函數 | 說明 |
|------|------|
| `addMissileSystems(groundForceCfg, sideName)` | 建立所有飛彈系統單元 |
| `initEventTriggers(operationalAreas, positionTypes, sideName)` | 建立 Zone 和 UnitEntersArea 觸發器 |
| `initMissileSystemContexts(groundForceCfg, groundForceCtx)` | 初始化執行期 context |

### 狀態控制函數

| 函數 | 說明 |
|------|------|
| `setWCSToFree(firingUnitCtx, firingUnit, isAuto)` | 設定武器管制為 FREE |
| `setStateToHIDE(firingUnitCtx, firingUnit, isAuto)` | 設定狀態為 HIDE，WCS=HOLD |
| `setStateToStatic(systemCtx, firingUnit, isAuto)` | 重設狀態為 STATIC |
| `setReloadStartTime(firingUnitCtx, firingUnit, isAuto)` | 開始裝填計時 |
| `moveToFiringPoint(firingUnitCtx, firingUnit)` | 移動至射擊陣地 |

### 查詢函數

| 函數 | 說明 |
|------|------|
| `isLowAmmo(firingUnit, percentage, weaponDBID)` | 檢查彈量是否低於門檻 |
| `isRepositioning(firingUnitCtx, isAuto)` | 檢查是否正在移動中 |
| `isMetWithResupplyUnits(systemCtx, unit, isAuto)` | 檢查發射單元是否與補給單元會合 |
| `isMetWithAmmoDepot(systemCtx, unit, isAuto)` | 檢查補給單元是否與彈藥庫會合 |

### 核心邏輯函數

| 函數 | 說明 |
|------|------|
| `reload(firingUnitCtx, resupplyUnitCtx, weaponDBID, sideName)` | 執行發射單元裝填 |
| `checkMissileSystemState(systemCtx, isAuto, sideName)` | 檢查並處理所有單元狀態 |
| `handleSupplyAssetDestruction(unit, systemCtx)` | 處理補給資產被摧毀 |

---

## 相關檔案

| 檔案 | 說明 |
|------|------|
| `src/modules/missileSystem.lua` | 主模組 |
| `src/core/constants.lua` | 狀態與位置類型常數 |
| `src/scripts/china/missileSystem/moveToPosition.lua` | 中國區域觸發事件 |
| `src/scripts/china/missileSystem/scheduledReloadHideCheck.lua` | 中國定時檢查事件 |
| `src/scripts/taiwan/missileSystem/moveToPosition.lua` | 台灣區域觸發事件 |
| `src/scripts/taiwan/missileSystem/scheduledReloadHideCheck.lua` | 台灣定時檢查事件 |

---

## 自動 vs 手動模式

模組支援 `isAuto` 參數切換模式：

| 行為 | 自動模式 | 手動模式 |
|------|:--------:|:--------:|
| 偵測低彈量並移動 | Yes | No |
| 會合後開始裝填計時 | Yes | Yes |
| 裝填完成後自動移動至 HA | Yes | No |
| 狀態檢查 | 檢查 state | 直接返回 true |
