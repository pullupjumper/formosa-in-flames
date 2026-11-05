# meeting.lua

找出飛彈連單位站在哪裡、能跟哪個夥伴會合。不做判斷。

> Source: `src/modules/missileSystem/meeting.lua`

責任摘要：解析配對（發射車與補給車的 state 與 CMO 單位）、量測位置（RL 區、ATP 區）。「算不算會合」的條件（模式、狀態、低彈、存量）都在 [rules](rules.md)。

---

## 概觀

`meeting.lua` 只回答「誰跟誰配對」和「站在哪」。它不下命令、不寫 state，也不判斷要不要補給。

`resolveReloadPair` 把任一端（發射車或補給車）的單位換成完整的配對：兩端 state、兩端 CMO 單位都要在，缺一個就回 `nil`。需要讀 CMO 的觀察（低彈、同 RL 區、裝填計畫）放在配對裡當函式，Rules 走到需要的分支才呼叫。

---

## 主要機制

- `findReloadArea`：回傳單位所在的 RL 區（只看 RL）。
- `resolveCmoUnit`（module-local）：名稱和觸發單位相同就直接重用，另一端用觸發單位的陣營查。
- `resolveReloadPair`：`GroundStateStore.resolvePair` → 兩端 CMO 單位 → `SBJ__ReloadPair`。配對裡的 `buildReload` 只算一次，Rules 用它決定裝填後要不要藏補給車，`COMPLETE_RELOAD` 用同一份計畫裝彈。
- `isAtCanisterStock`：補給車和它的彈箱庫存在同一個 ATP 區；彈箱庫存不在遊戲裡回 false。

---

## Public API

| 函式 | 參數 | 回傳 | 說明 |
|---|---|---|---|
| `findReloadArea` | `unit, operationalArea` | `string[]|nil` | 單位所在的 RL 區 |
| `resolveReloadPair` | `systemState, unit` | `SBJ__ReloadPair|nil` | 任一端單位解析出完整配對；缺 state 或缺單位回 nil |
| `isAtCanisterStock` | `resupplyUnitState, resupplyUnit` | `boolean` | 補給車與彈箱庫存在同一 ATP 區 |

---

## 相關模組

- [rules](rules.md)
- [ammo](ammo.md)
- [arrival](arrival.md)
- [cycle](cycle.md)
