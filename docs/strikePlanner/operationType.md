# operationType — air / ground descriptor

> 原始碼：`src/modules/strikePlanner/operationType.lua`

**職責**：把 air 與 ground 的差異變成資料。任何需要依 operation type 分派的地方，讀這張表，不在型別字串上寫 `if`。

---

## Descriptor 欄位

`OperationType.resolve(operationType)` 回傳 `SBJ__OperationTypeProfile`，未知型別回 `nil`。

| 欄位 | air | ground | 誰在讀 |
|---|---|---|---|
| `templateSource` | `"packageTemplates"` | `"fireSupportTaskTemplates"` | [operationScheduler](operationScheduler.md) 查 `config.red[templateSource]` |
| `templateField` | `"packages"` | `"fireSupportTasks"` | operationScheduler 組 template；[dynamicPlan](dynamicPlan.md) 走訪 template |
| `registryKey` | `"air"` | `"ground"` | dynamicPlan 登記到 `generatedOperations[registryKey]` |
| `resolvePlan(saveData)` | `saveData.red.air.airTaskingOrder` | `saveData.red.ground.fireSupportPlan` | dynamicPlan 寫入計畫 |
| `resolveDefaultInterval(config)` | `config.red.air.strikeInterval` | `0` | operationScheduler 補 template 缺省的 `strikeInterval` |

ground 的預設間隔固定為 `0`，因為地面 FSEM 採 TOT 導向，與空中 wave 的錯開發射相反。

新增 operation type 只需在此表加一列，並在 `src/core/schema.lua` 的 `SBJ__OperationType` alias 補上字串。

---

## Public API

| 函數 | 參數 | 回傳 |
|---|---|---|
| `resolve(operationType)` | `string` | `SBJ__OperationTypeProfile\|nil` |

---

## 相關模組

- [operationScheduler](operationScheduler.md) — 依 descriptor 解析模板來源與欄位
- [dynamicPlan](dynamicPlan.md) — 依 descriptor 走訪 template、選擇計畫表與登記 key
- [系統架構](README.md)
