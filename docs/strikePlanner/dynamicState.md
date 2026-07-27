# dynamicState — 動態作戰狀態工具

> 原始碼：`src/modules/strikePlanner/dynamicState.lua`

**職責**：管理 recon-triggered operation 執行狀態、動態作戰命名與 generated operation 登記。

---

## 概述

`dynamicState` 是 [fsemBuilder](fsemBuilder.md) 與 [atoBuilder](atoBuilder.md) 共用的狀態工具。它不負責偵察完成後的排程決策；作戰搜尋、下一波生成與 pending 檢查已內聚於 [operationScheduler](operationScheduler.md)。

---

## 偵察觸發作戰狀態

```mermaid
flowchart TD
    SCHED["reconTriggeredOperations[]"]
    ENTRY["ReconTriggeredOperationBatch"]
    OP["Operation"]

    SCHED --> ENTRY
    ENTRY -->|operations[]| OP

    ENTRY_STATE["executed: boolean"]
    OP_STATE["executed: boolean<br>executionResult: boolean"]

    ENTRY --> ENTRY_STATE
    OP --> OP_STATE

    NOTE["所有 Operations 完成<br>Entry.executed = true"]
```

| 函數 | 說明 |
|---|---|
| `markOperationExecuted(reconEntry, operation, success)` | 標記單一作戰已執行，並自動檢查父批次完成狀態 |
| `checkOperationBatchCompleted(reconEntry)` | 檢查批次內所有 operations 是否都已完成 |
| `updateReconTriggeredOperationStatus(saveData)` | 批次更新所有偵察觸發作戰批次完成狀態 |

---

## 作戰篩選

`filterOperationsByType(reconTriggeredOperations, operationType)` 從尚未完成的 batch 中篩選指定類型、尚未執行的 operation。

篩選條件：

- `operationBatch.executed == false`
- `operation.type == operationType`
- `operation.executed == false`

回傳 `{ operationBatch, operation }` 配對陣列，供 ATO/FSP 動態插入流程消費。

---

## 作戰名稱與登記

動態生成的作戰名稱格式：

```text
DYNAMIC/{RECON_TYPE}/{OPERATION_TYPE}/{SEQUENCE}
```

範例：

- `DYNAMIC/SATELLITE/GND/STRIKE/INFRA/ALL/1`
- `DYNAMIC/UAV/AIR/STRIKE/AB/W/2`

名稱生成時同時檢查兩個來源，避免跨 tick 或既有計畫衝突：

| 函數 | 檢查範圍 |
|---|---|
| `generateUniqueAirOperationName` | `generatedOperations.air` + `airTaskingOrder` |
| `generateUniqueGroundOperationName` | `generatedOperations.ground` + `fireSupportPlan` |
| `registerGeneratedOperation` | 將名稱登記至 `generatedOperations` |

---

## Public API

| 函數 | 說明 |
|---|---|
| `checkOperationBatchCompleted(reconEntry)` | 檢查作戰批次所有作戰是否完成 |
| `updateReconTriggeredOperationStatus(saveData)` | 更新所有偵察觸發作戰批次完成狀態 |
| `filterOperationsByType(reconTriggeredOperations, operationType)` | 依類型篩選未執行的作戰 |
| `markOperationExecuted(reconEntry, operation, success)` | 標記作戰已執行 |
| `generateUniqueAirOperationName(operationType, reconType, saveData)` | 生成唯一空中作戰名稱 |
| `generateUniqueGroundOperationName(operationType, reconType, saveData)` | 生成唯一地面作戰名稱 |
| `registerGeneratedOperation(operationType, operationName, saveData)` | 登記已生成的作戰名稱 |

---

## 相關模組

- [fsemBuilder](fsemBuilder.md) — 使用 ground operation 篩選、命名、登記與完成狀態更新
- [atoBuilder](atoBuilder.md) — 使用 air operation 篩選、命名、登記與完成狀態更新
- [operationScheduler](operationScheduler.md) — 建立 recon-triggered operations 並管理排程查詢與下一波生成
- [系統架構](README.md)
