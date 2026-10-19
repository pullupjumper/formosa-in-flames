# mineClearing — 反水雷

> 原始碼：`src/modules/landingOps/mineClearing.lua`

**職責**：建立通道、派 Type 082 獵雷艦沿通道與弓字型掃雷、追蹤完成；另提供除錯用的佈雷

---

## 概述

反水雷是登陸前的第一個動作。`startMineClearing` 在 `WAITING_ASSAULT` 離開時執行：

1. 讀 `landing.laneCenter`（紅方）與 `landing.obstacleArea`（藍方，至少 3 點）
2. 找本區的 Type 082（`TYPE_082`，在展開線或母艦區內），依橫向位置由左到右排序
3. 由 [amphibiousAssault](amphibiousAssault.md) 的 `findDeployLineLSTLaterals` 取得 LST 位置，排通道橫向位置
4. 呼叫 [laneGeometry](laneGeometry.md) 的 `buildLanes`，結果存入 `zoneState.lanes`
5. 每艘 082 領一條水際通道（一艘一營一條）：設 `course = sweepCourse`、速度、主動聲納，記入 `zoneState.minesweepers[guid]`

一艘 082 對應一條水際通道，通道數 = 082 數量，所以 `config` 裡各區 `fleet` 的 `type082` 數量要等於營數。

`updateMineClearing` 每 tick 檢查：走到最後航點（距離小於 `tuning.route.arrivalNm`）就 `RTB(true)`，被摧毀也算完成。全部完成才回 `true`，coordinator 才進入下一階段。

---

## 失敗時的行為

以下情況記 FAIL、回 `false`，且**什麼都不改**，所以階段停在 `WAITING_ASSAULT` 下個 tick 重試，不會 crash：

- `laneCenter` 或 `obstacleArea` 的參考點沒填
- 區內找不到任何 082（`no_type082_in_zone`）

艦間空隙排不出通道只記 WARN，並退回均勻排列，不算失敗。

### 為什麼掃雷任務有一個 TODO？

CMO 的掃雷由內建任務完成。程式只把 082 指派到 `zone.landing.sweeper.missionName`（任務不存在時建立 `Mineclearing` 類型、區域取 ACV 區），任務區域的四角存在 `zoneState.minesweepers[guid].missionArea`，**正確的掃雷區域設定留給使用者自己寫**（原始碼標 TODO）。實作時注意：**先設 `course`，再 assign 任務**。

### 為什麼灘際通道改由 082 開？

灘際通道原本屬於破障階段，但衝鋒舟不能反水雷，所以 082 在到達衝擊發起線後走弓字型，把每條灘際通道一併掃出。衝鋒舟只負責破障。

---

## 佈雷（除錯用）

`createMinefields(amphibOps, zoneName)` 依 `amphibOps.minefields` 中 `zone` 相符的每筆呼叫 `ScenEdit_AddMinefield`（藍方、`SEA_MINE`），先刪除同區域舊雷區。`area` 為空就跳過。目前只在 coordinator 的快轉路徑被呼叫，時序注意事項見 [debugFlow](debugFlow.md)。

快轉時 `removeMinesOnLanes` 會刪掉落在通道內的雷，作為 082 的替身。

---

## 公開 API

| 函式 | 說明 |
|---|---|
| `startMineClearing(amphibOps, zone, zoneState, ships)` | 建通道並派 082，回傳是否成功 |
| `updateMineClearing(amphibOps, zoneState)` | 每 tick 檢查，全部完成回 `true` |
| `createMinefields(amphibOpsConfig, zoneName)` | 佈雷 |

---

## 設定

| 路徑 | 用途 |
|---|---|
| `zones[].landing.laneCenter`、`obstacleArea` | 通道原點與障礙範圍參考點（`constants.AREAS`） |
| `zones[].landing.sweeper` | 掃雷任務名稱與速度 |
| `tuning.mineClearing.areaMarginM` | 掃雷任務區域比最外側灘際通道多出的寬度 |
| `tuning.mineClearing.cellSizeM` | 快轉掃雷的方塊邊長 |
| `tuning.route.inlandMarginM`、`arrivalNm` | E_lane 超出障礙的距離、到達判斷 |
| `amphibOps.minefields[]` | 雷區：`zone`、`area`、`number`、`delay` |

---

## 相關模組

- [laneGeometry](laneGeometry.md) — 通道建構
- [assaultBoat](assaultBoat.md) — 下一階段：配對衝鋒舟
- [debugFlow](debugFlow.md) — 快轉
- [系統架構](README.md)
