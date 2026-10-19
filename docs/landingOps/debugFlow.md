# debugFlow — 實測快轉與瞬移開關

> 原始碼：`src/modules/landingOps/debugFlow.lua`

**職責**：讓開發者不用等完整流程就能直接測後段階段

---

## 概述

兩棲流程很長（艦隊航渡、掃雷、衝鋒舟、破障計時），要測氣墊船或兩棲車分波時不可能每次從頭等。`config.red.amphibOps.debug` 提供三個欄位：

| 欄位 | 作用 |
|---|---|
| `enabled` | 總開關。**正式跑必須是 `false`** |
| `startStage` | 順序**早於**此階段的階段會被快轉；`nil` 表示全部快轉 |
| `teleportLanding` | 氣墊船與 ACV 直接瞬移到停車位，不實際航行 |

`isFastForward(amphibOps, phase)` 以 `constants.AMPHIBIOUS_PHASE_ORDER` 比較階段順序。被快轉的階段**仍然會執行**，只是耗時動作改成瞬間完成，所以後面的階段拿得到需要的 state（通道、配對、障礙方塊）。

---

## 各階段的快轉行為

| 階段 | 快轉時 |
|---|---|
| `MOVING` | 艦隊與 SAG 瞬移到等待位置，`manualSpeed` 設 0 |
| `WAITING_ASSAULT` | 不等接觸數與 `periodSec`，直接放行 |
| `MINE_CLEARING` | 刪除落在通道內的水雷、082 瞬移到掃雷終點，完成後瞬移回基地；LST、SAG 瞬移到就位點；另有佈雷，見下節 |
| `BOAT_ASSAULT` | 衝鋒舟放出後瞬移到 S_lane |
| `OBSTACLE_CLEARING` | 略過 `clearSec` 計時 |

### 為什麼佈雷只在快轉時發生？

`createMinefields` 目前只在 coordinator 的 `stepWaitingAssault` 被呼叫，條件是 `MINE_CLEARING` 要快轉，且排在 `startMineClearing` **之後**。一般流程不會由程式佈雷。

`removeMinesOnLanes`（快轉時刪掉通道內的雷）則在 `startMineClearing` 內執行，也就是**早於**佈雷。因此快轉時通道內的雷是否被清掉，取決於雷區在那之前是否已存在；這個順序沒有被測試或註解保證，改動時要留意。

---

## 公開 API

| 函式 | 說明 |
|---|---|
| `isFastForward(amphibOps, phase)` | 該階段是否快轉。`debug` 缺失或 `enabled = false` 一律回 `false` |
| `isLandingTeleport(amphibOps)` | 氣墊船與 ACV 是否瞬移 |
| `teleport(guid, location)` | 瞬移單位 |

---

## 相關模組

- [coordinator](coordinator.md) — 階段推進時查詢
- [mineClearing](mineClearing.md)、[assaultBoat](assaultBoat.md)、[obstacleClearing](obstacleClearing.md)、[hovercraft](hovercraft.md) — 各自有快轉分支
- [系統架構](README.md)
