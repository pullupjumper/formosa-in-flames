# rules.lua

飛彈連「下一步要做什麼」的唯一判斷處。

> Source: `src/modules/missileSystem/rules.lua`

責任摘要：把觀察到的情況（state、彈量、會合、經過秒數、policy 開關）轉成一串有順序的步驟名稱。會合的條件也在這裡。不呼叫 CMO、不寫 state；要讀 CMO 的觀察以函式傳進來，只在需要的分支呼叫。

---

## 概觀

missileSystem 的流程分成三層：

| 層 | 檔案 | 做什麼 |
|---|---|---|
| 判斷 | `rules.lua` | 看觀察表，回傳步驟清單 |
| 執行 | [arrival](arrival.md)、[cycle](cycle.md)、[init](init.md) | 收集觀察表 → 問 Rules → 照步驟呼叫 handler，產生 log |
| 寫入 | [transitions](transitions.md) | 唯一寫 state、裝填計時、收車計時的地方 |

步驟名稱放在 `Rules.STEP`。每個執行端有自己的 handler 表，handler 一律是 `fun(ctx, observation): SBJ__LogResult|nil`，由 `Shared.processSteps` 依序執行。

觀察只有兩種：完整，或 `nil`（例如 `SBJ__ReloadPair` 缺任何一端就是 nil）。Rules 先檢查 nil 才發出會讀觀察的步驟，所以 handler 拿到的觀察不會缺欄位，也不需要轉型。

成本政策只有一種：查 state 與單位是即時的，讀彈量、讀區域這類 CMO 查詢是函式，Rules 走到那個分支才呼叫。

---

## 主要機制

### 抵達陣地（`evaluate*Arrival`）

每個陣地一個函式：`evaluateFiringPointArrival`、`evaluateHideAreaArrival`、`evaluateReloadPointArrival`、`evaluateAmmoHoldingAreaArrival`。

會合條件（module-local）：

- `hasMetResupplyUnit(pair, isAuto)`：觸發端狀態可會合（自動模式要 REPOSITIONING / RELOAD）→ 發射車低彈 → 補給車有彈 → 兩車在同一 RL 區。
- `hasMetAmmoDepot(resupplyUnitState, isAuto, isAtAmmoDepot)`：狀態可會合 → 補給車彈量 0 → 和彈藥庫在同一 AHA 區。

| 陣地 | 條件 | 步驟 |
|---|---|---|
| FP | `isRepositioning`（手動模式下只要是發射車就算） | `ARRIVE_AT_FIRING_POINT` |
| HA | 是發射車 + `hideOnEnterHA` + 彈量足 | `HIDE_FIRING_UNIT` |
| RL | 配對不完整 | `STOP_IN_MANUAL_MODE` |
| RL | 有會合 | `BEGIN_RELOAD` |
| RL | 沒會合 | `STOP_IN_MANUAL_MODE`，若 `hideResupplyOnRLNoMeeting` + 抵達的是補給車 + 配對發射車彈量足，再加 `HIDE_UNMET_RESUPPLY_UNIT` |
| AHA | 有會合 | `BEGIN_TRANSLOAD`，否則 `STOP` |

### 發射車定時循環（`evaluateFiringUnitTick`）

- **STATIC（只在自動模式）**：沒有收車倒數且彈量足 → 不動；沒有倒數但低彈 → `BEGIN_STOW`；倒數未滿 `stowTime` → 不動；倒數結束 → 彈量足就 `MOVE_TO_HIDE_AREA`，低彈就連同補給車去 RL（補給車狀態或單位不見時改成 WARN 步驟，發射車照樣出發），最後 `END_STOW`。
- **RELOAD（兩種模式）**：先 `ENSURE_RELOAD_CLOCK`。`reloadTime` 已過 + 有會合（含仍低彈）→ `COMPLETE_RELOAD`；自動模式下，補給車存量多於這次裝填量（`pair.buildReload().count`）就加 `HIDE_RESUPPLY_UNIT_AFTER_RELOAD`，SAM（`staysDeployed`）回 FP，其他回 HA。
- STATIC 和 RELOAD 互斥（出發只會變成 REPOSITIONING），所以一次判斷就夠。
- 裝填是先算後裝（`Ammo.buildReload`），所以裝填後的存量在判斷時就知道。「補給車在 RL 區」由會合保證：同一連的發射車與補給車共用一個作戰區（`deployment_spec` 對 config 釘住這件事）。

### 補給車定時循環（`evaluateResupplyUnitTick`）

- **STATIC**：自動模式 + 彈量 0 + 在某個 RL 區 → `MOVE_TO_AMMO_HOLDING_AREA`。
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

`spec/modules/missileSystem/rules_spec.lua` 是表格測試：一行 = 觀察 → 步驟清單，不需要 stub。觀察函式用 `answer(value)` 產生；`value` 為 nil 時一被呼叫就讓測試失敗，用來釘住「這個分支不該讀 CMO」。新增或修改判斷時先在這裡加一行。

---

## 相關模組

- [transitions](transitions.md)
- [meeting](meeting.md)
- [arrival](arrival.md)
- [cycle](cycle.md)
- [init](init.md)
