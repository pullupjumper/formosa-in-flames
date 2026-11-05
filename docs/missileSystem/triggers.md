# triggers.lua

陣地 zone 與 arrival trigger 的名稱協定。

> Source: `src/modules/missileSystem/triggers.lua`

---

## 名稱

| 物件 | 格式 | 函式 |
|---|---|---|
| 事件 | `(<side>) Arrive in <type>` | `formatEventName` |
| Trigger | `(<side>) Arrive in <type> - <idx> - <oparea>` | `formatTriggerName` |
| 陣地 zone | `<type>/<idx>/<oparea>` | `formatZoneName` |
| Mask zone | `MASK/<oparea>` | `formatMaskZoneName` |

`parsePositionType` 從 trigger 名稱讀回 FP/HA/RL/ATP，`arrival.lua` 用它分派到達事件。

redeploy 用這些名字找出要刪的 zone 與 trigger（見 [positionZones](positionZones.md)），所以 `.scen` 內建的 zone 與 trigger 也必須照這個格式命名。2026-11-05 驗證過：目前 `.scen` 的 264 個陣地 zone、44 個 mask zone、264 個 trigger 全部符合。

---

## 相關模組

- [positionZones](positionZones.md)
- [arrival](arrival.md)
