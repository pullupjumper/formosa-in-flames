# dynamicOperationsUtils — 動態作戰共用工具

> 原始碼：`src/modules/strikePlanner/dynamicOperationsUtils.lua`

**職責**：提供偵察排程管理、作戰名稱生成、作戰狀態追蹤等共用功能

---

## 概述

dynamicOperationsUtils 是 [dynamicFireSupportPlan](dynamicFireSupportPlan.md)、[dynamicATOInsertion](dynamicATOInsertion.md) 與 [recon](recon.md) 三者共用的工具模組。負責偵察排程的狀態管理、動態作戰命名、作戰搜尋與下一波自動生成。

---

## 偵察排程狀態管理

```mermaid
flowchart TD
    SCHED["reconSchedule[]"]
    ENTRY["ReconScheduleEntry"]
    OP["Operation"]

    SCHED --> ENTRY
    ENTRY -->|operations[]| OP

    ENTRY_STATE["executed: boolean"]
    OP_STATE["executed: boolean<br>executionResult: boolean"]

    ENTRY --> ENTRY_STATE
    OP --> OP_STATE

    NOTE["當所有 Operations 完成<br>→ Entry.executed = true"]
```

### 狀態更新函數

| 函數 | 說明 |
|---|---|
| `markOperationExecuted(reconEntry, operation, success)` | 標記單一作戰已執行，並自動檢查父項目完成狀態 |
| `checkReconEntryCompleted(reconEntry)` | 檢查 Entry 的所有 Operations 是否都已完成 |
| `updateReconScheduleStatus(saveData)` | 批次更新所有排程項目的完成狀態 |

---

## 作戰篩選

`filterOperationsByType` 從 `reconSchedule` 中篩選符合條件的作戰：

- 篩選條件：`reconEntry.executed == false` 且 `operation.type == operationType` 且 `operation.executed == false`
- 回傳：`{reconEntry, operation}` 配對陣列

---

## 作戰名稱生成

動態生成的作戰名稱格式：`DYNAMIC/{RECON_TYPE}/{OPERATION_TYPE}/{SEQUENCE}`

範例：
- `DYNAMIC/SATELLITE/INFRASTRUCTURE/1`
- `DYNAMIC/UAV/STRIKE/AB/W/2`

### 唯一性保障

名稱生成時同時檢查兩個來源，確保不衝突：

1. `generatedOperations` 登記表（防止跨 tick 重複）
2. 既有計畫表（`airTaskingOrder` 或 `fireSupportPlan`）

| 函數 | 檢查範圍 |
|---|---|
| `generateUniqueAirOperationName` | `generatedOperations.air` + `airTaskingOrder` |
| `generateUniqueGroundOperationName` | `generatedOperations.ground` + `fireSupportPlan` |
| `registerGeneratedOperation` | 將名稱登記至 `generatedOperations` |

---

## 下一波作戰生成（generateNextOperation）

偵察完成後自動遞增模板編號生成下一波作戰：

1. 解析模板名稱中的編號（如 `STRIKE/AB/W/1` → 基底 `STRIKE/AB/W/`、編號 `1`）
2. 遞增編號查找 config 中的下一組模板（如 `STRIKE_AB_W_2`）
3. 若找到 → 使用新模板（`FOUND_NEXT`）
4. 若未找到 → 重用當前模板（`REUSED_CURRENT`）

### 回傳狀態

| 狀態 | 觸發條件 | 回傳的作戰 |
|---|---|---|
| `FOUND_NEXT` | config 中存在 `/N+1` 對應模板 | 套用新模板、`name` 為 `/N+1` |
| `REUSED_CURRENT` | 找不到 `/N+1` 模板 | 重用當前模板與名稱（深拷貝來源作戰的模板內容） |
| `PARSE_ERROR` | 模板名稱結尾不是 `/數字`，無法解析編號 | 原作戰的深拷貝 |
| `UNKNOWN_TYPE` | `operation.type` 不在 `TYPE_CONFIG`（非 `air`/`ground`） | 原作戰的深拷貝 |

### 類型配置對照

| 作戰類型 | config 模板表 | 模板鍵名 | 預設間隔 |
|---|---|---|---|
| `air` | `config.c.packageTemplates` | `packages` | `nil` |
| `ground` | `config.c.fireSupportTaskTemplates` | `fireSupportTasks` | `0` |

---

## 作戰搜尋（hasOperation）

支援兩種搜尋模式：

| 模式 | 範例 | 說明 |
|---|---|---|
| 精確匹配 | `"STRIKE/AB/W/1"` | 完全匹配模板名稱（`findExactMatch`） |
| 前綴匹配 | `"STRIKE/AB/W/"` | 尾碼 `/` 表示前綴搜尋，回傳編號最大者（時間為 tiebreaker）（`findPrefixMatch`） |

> 前綴匹配只採計**已執行**（`operation.executed == true`）的作戰當基底。仍在觀測窗內、尚未執行的作戰會被略過，以免 `generateNextOperation` 在前一波還沒落定時就先產出 `/N+1`。

---

## 待執行作戰檢查（hasPendingOperation）

`hasPendingOperation(reconSchedule, templateName, operationType)` 走訪整個排程，判斷是否已有一筆**精確同名**且**尚未執行**（`operation.executed == false`）的作戰。

- 用途：[recon](recon.md) 在排下一波作戰前先呼叫此函數；若同名 `/N+1` 已在排程中待執行，就跳過新增，避免同一波被重複排入而使打擊包翻倍。
- 與 `hasOperation` 的差異：`hasOperation` 不分執行狀態（且支援前綴），`hasPendingOperation` 只看「尚未執行」的精確同名項目。

---

## 偵察排程查詢

`getLastExecutedOperationsAndNextTime` 單次遍歷找出：

- **最近已過時間的 Entry**：回傳其 air/ground Operations 分類
- **最早未來時間的 Entry**：回傳 `nextReconTime`

供 [recon](recon.md) 模組排程動態作戰時參考。

---

## 公開 API

| 函數 | 說明 |
|---|---|
| `checkReconEntryCompleted(reconEntry)` | 檢查偵察項目所有作戰是否完成 |
| `updateReconScheduleStatus(saveData)` | 更新所有偵察排程項目完成狀態 |
| `filterOperationsByType(reconSchedule, operationType)` | 依類型篩選未執行的作戰 |
| `markOperationExecuted(reconEntry, operation, success)` | 標記作戰已執行 |
| `generateUniqueAirOperationName(operationType, reconType, saveData)` | 生成唯一空中作戰名稱 |
| `generateUniqueGroundOperationName(operationType, reconType, saveData)` | 生成唯一地面作戰名稱 |
| `registerGeneratedOperation(operationType, operationName, saveData)` | 登記已生成的作戰名稱 |
| `getLastExecutedOperationsAndNextTime(reconSchedule)` | 取得最近執行的作戰與下次偵察時間 |
| `hasOperation(reconSchedule, templateName, operationType)` | 搜尋特定作戰是否存在（精確或前綴） |
| `hasPendingOperation(reconSchedule, templateName, operationType)` | 檢查是否已有同名且尚未執行的作戰待排，用於防止重複排入下一波 |
| `generateNextOperation(operation, config)` | 遞增編號生成下一波作戰 |

---

## 相關模組

- [dynamicFireSupportPlan](dynamicFireSupportPlan.md) — 使用篩選、命名、登記功能
- [dynamicATOInsertion](dynamicATOInsertion.md) — 使用篩選、命名、登記功能
- [recon](recon.md) — 使用搜尋、下一波生成、排程查詢功能
- [系統架構](README.md)
