# movement.lua

機動車組的移動與待命指令模組。

> Source: `src/modules/missileSystem/movement.lua`

責任摘要：統一封裝到 FP/HA/RL/AHA 的移動命令，以及原地待命與武器管制（WCS）的設定。不改任何狀態；狀態由 [transitions](transitions.md) 記錄。

---

## 概觀

每一條移動路線是 `Movement.ORDER` 表裡的一列：去哪個陣地、要不要設 WCS、要不要只走最後一個航點、log 叫什麼。`moveTo` 照這一列下指令，回傳整理好的 log row。

呼叫端不直接呼叫 `moveTo`，而是呼叫 `Transitions.depart(unitState, unit, order)`：它下指令，成功才記成 `REPOSITIONING`，再把 row 交回去。

---

## 移動路線（`Movement.ORDER`）

| 路線 | 陣地 | WCS | 只走最後航點 | log `action` | 用途 |
|---|---|---|---|---|---|
| `FIRING_POINT` | FP | 不動 | 否 | `move_to_firing_point` | 發射車去射擊點 |
| `HIDE_AREA` | HA | HOLD | 否 | `move_to_hide_area` | 發射車回躲藏區 |
| `RELOAD_POINT` | RL | HOLD | 否 | `move_firing_unit_to_reload_point` | 發射車去裝填點 |
| `RESUPPLY_VIA_SHRL` | SHRL，沒有 SHRL 就用 RL | HOLD | 否 | `move_resupply_to_reload_point` | 收車結束，補給車從掩體出發 |
| `RESUPPLY_RECALL` | RL | 不動 | 是 | `move_resupply_to_reload_point` | 轉載完成，補給車直接回 RL |
| `AMMO_HOLDING_AREA` | AHA | 不動 | 否 | `move_to_ammo_holding_area` | 補給車去彈藥區 |

兩條補給車回 RL 的路線 log 名稱相同，要看路線才分得出來。

`SHRL` 只有在「沒定義」時才改用 RL；定義成空陣列會直接失敗，不會改用 RL。

---

## Public API

| 函式 | 參數 | 回傳 | 說明 |
|---|---|---|---|
| `ORDER` | | `table<string, SBJ__MoveOrder>` | 所有移動路線 |
| `moveTo` | `unitState, unit, order` | `SBJ__LogResult` | 照路線下指令；只由 `Transitions.depart` 呼叫 |
| `applyMode` | `unit, isAuto, wcs` | `nil` | 整個 group 依模式待命並套用 WCS（SAM 平台用防空 WCS） |

成功回傳 `OK`，欄位是 `unit`、`action`。失敗回傳 `FAIL`，另外帶上原因：

| `reason` | 附帶欄位 | 情境 |
|---|---|---|
| `no_positions_available` | `position`、`area` | 該陣地類型沒有任何位置 |
| `invalid_position_data` | `position`、`index`、`area` | 抽中的位置缺少 `course` |
| `no_ha_defined` | `area` | `operationalArea.HA` 未定義 |

---

## 相關模組

- [shared](shared.md)
- [transitions](transitions.md)
- [init](init.md)
- [cycle](cycle.md)
