# rules.lua

飛彈連「下一步要做什麼」的唯一判斷處。

> Source: `src/modules/missileSystem/rules.lua`

責任摘要：把觀察到的情況（state、彈量、會合、經過秒數、policy 開關）轉成一串有順序的步驟名稱。純函式：不呼叫 CMO、不寫 state。

---

## 概觀

missileSystem 的流程分成三層：

| 層 | 檔案 | 做什麼 |
|---|---|---|
| 判斷 | `rules.lua` | 看觀察表，回傳步驟清單 |
| 執行 | [arrival](arrival.md)、[cycle](cycle.md)、[init](init.md) | 收集觀察表 → 問 Rules → 照步驟呼叫 handler，產生 log |
| 寫入 | [transitions](transitions.md) | 唯一寫 state、裝填計時、收車計時的地方 |

步驟名稱放在 `Rules.STEP`。每個執行端有自己的 handler 表（`ARRIVAL_STEPS`、`FIRING_UNIT_STEPS`、`RESUPPLY_UNIT_STEPS`、`SEND_TO_FIRING_POINT_STEPS`），因為各自的 log 格式不同。

觀察表一次收齊（`fireSupportPlan` 走的兩個 facade 例外，見下方），所以有些唯讀查詢會比「邊判斷邊查」多跑幾次，但不會寫入任何東西。

---

## 主要機制

### 抵達陣地（`evaluateArrival`）

| 陣地 | 條件 | 步驟 |
|---|---|---|
| FP | `isRepositioning`（手動模式下只要是發射車就算） | `ARRIVE_AT_FIRING_POINT` |
| HA | 是發射車 + `hideOnEnterHA` + 彈量足 | `HIDE_FIRING_UNIT` |
| RL | 有會合 + 會合的發射車還在遊戲裡 | `BEGIN_RELOAD` |
| RL | 有會合但發射車不見 | `WARN_FIRING_UNIT_NOT_FOUND` |
| RL | 沒會合 | `STOP_IN_MANUAL_MODE`，若 `hideResupplyOnRLNoMeeting` + 是補給車 + 配對發射車存在且彈量足，再加 `HIDE_RESUPPLY_UNIT` |
| AHA | 有會合 | `BEGIN_TRANSLOAD`，否則 `STOP` |

### 發射車定時循環（`evaluateFiringUnitTick`）

- **STATIC（只在自動模式）**：沒有收車倒數且彈量足 → 不動；沒有倒數但低彈 → `BEGIN_STOW`；倒數未滿 `stowTime` → 不動；倒數結束 → 彈量足就 `MOVE_TO_HIDE_AREA`，低彈就連同補給車去 RL（補給車狀態或單位不見時改成 WARN 步驟，發射車照樣出發），最後 `END_STOW`。
- **RELOAD（兩種模式）**：先 `ENSURE_RELOAD_CLOCK`。`reloadTime` 已過 + 有會合 + 仍低彈 → `COMPLETE_RELOAD`；自動模式再加 `HIDE_RESUPPLY_UNIT`，SAM（`staysDeployed`）回 FP，其他回 HA。
- STATIC 和 RELOAD 互斥（出發只會變成 REPOSITIONING），所以一次判斷就夠。
- `HIDE_RESUPPLY_UNIT` 在裝填之後才知道補給車剩多少彈，所以「還有彈且在作戰區」的檢查留在 cycle 的 handler 裡。

### 補給車定時循環（`evaluateResupplyUnitTick`）

- **STATIC**：自動模式 + 彈量 0 + 在作戰區 → `MOVE_TO_AMMO_HOLDING_AREA`。
- **RELOAD**：先 `ENSURE_RELOAD_CLOCK`。`reloadTime` 已過 + 彈量 0 + 有會合 → 彈藥儲備點沒有狀態就 `FAIL_AMMO_DEPOT_STATE_NOT_FOUND`，否則 `COMPLETE_TRANSLOAD`，自動模式再 `RECALL_TO_RELOAD_POINT`。

### Facade 用的判斷

| 函式 | 呼叫端 | 說明 |
|---|---|---|
| `evaluateSendToFiringPoint(firingUnitState, isLowAmmo)` | `sendToFiringPoint` | HIDE 且彈量足 → `UNHIDE`、`MOVE_TO_FIRING_POINT` |
| `evaluateReadiness(firingUnitState, isLowAmmo)` | `evaluateReadiness` | 不是 HIDE → `NOT_HIDDEN`；低彈 → `LOW_AMMO`；否則 `READY` |
| `isInPosition(firingUnitState)` | `sendToFiringPoint` | `STATIC` 算在位置上 |
| `shouldStow(firingUnitState, opts)` | `startStow` | `opts.onlyDeployed` 只收 STATIC / REPOSITIONING |
| `staysDeployed(missileSystemType)` | `startStow`、cycle | SAM 不收車、裝填後回 FP；唯一的 SAM 判斷 |
| `isRepositioning(firingUnitState, isAuto)` | 抵達 FP | 手動模式沒有 REPOSITIONING，一律算在移動中 |

前兩個的 `isLowAmmo` 是 callback，只在單位 HIDE 時才呼叫：FSP 每輪都會問，移動中的單位不必讀彈量。

---

## 已知風險

自動模式下，發射車往 FP 途中若穿過 RL，`STOP_IN_MANUAL_MODE` 會把它轉成 `STATIC`；抵達 FP 時 `isRepositioning` 回傳 false，WCS 不會開成 FREE。要修就改「RL 沒會合」那一列。

---

## 測試

`spec/modules/missileSystem/rules_spec.lua` 是表格測試：一行 = 觀察表 → 步驟清單，不需要 stub。新增或修改判斷時先在這裡加一行。

---

## 相關模組

- [transitions](transitions.md)
- [arrival](arrival.md)
- [cycle](cycle.md)
- [init](init.md)
