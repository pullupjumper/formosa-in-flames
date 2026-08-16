# dynamicState — 動態作戰狀態工具

> 原始碼：`src/modules/strikePlanner/dynamicState.lua`

**職責**：管理 recon-triggered operation 執行狀態、動態作戰命名與 generated operation 登記。

---

## 概述

`dynamicState` 是 [fsemBuilder](fsemBuilder.md) 與 [atoBuilder](atoBuilder.md) 共用的狀態工具。它不負責偵察完成後的排程決策；作戰搜尋、下一波生成與 pending 檢查已內聚於 [operationScheduler](operationScheduler.md)。

---

## 偵察觸發作戰狀態

`executed` 只有一個意思：**作戰計畫真的被插進去了**（ATO wave 或 FSEM）。放棄的作戰不會被標記，而是直接從 batch 移除，因此 [operationScheduler](operationScheduler.md) 看到的必然只有「已插入」或「仍在重試」兩種狀態。

```mermaid
flowchart TD
    SCHED["reconTriggeredOperationBatches[]"]
    ENTRY["ReconTriggeredOperationBatch"]
    OP["Operation"]

    SCHED --> ENTRY
    ENTRY -->|operations[]| OP

    ENTRY_STATE["executed: boolean"]
    OP_STATE["executed: boolean"]

    ENTRY --> ENTRY_STATE
    OP --> OP_STATE

    NOTE["所有 Operations 完成或被移除<br>Entry.executed = true"]
```

| 函數 | 說明 |
|---|---|
| `markOperationExecuted(reconEntry, operation)` | 標記單一作戰的計畫已插入，並自動檢查父批次完成狀態 |
| `abandonOperation(reconEntry, operation)` | 把放棄的作戰從 batch 移除（以 identity 比對），並檢查父批次完成狀態 |
| `checkOperationBatchCompleted(reconEntry)` | 檢查批次內所有 operations 是否都已完成；operations 被清空的 batch 也視為完成 |
| `updateReconTriggeredOperationStatus(saveData)` | 批次更新所有偵察觸發作戰批次完成狀態 |

移除而非標記，是為了讓排程器能重開同一波：

- 第一波被移除 → `isOperationScheduled` 判定沒排過 → 下次偵察完成時重開第一波
- 第 N 波被移除 → 最新 executed 仍是第 N-1 波 → 重新產生第 N 波，不會跳到第 N+1 波

---

## 觀察窗

`evaluateObservationWindow(currentTime, operationBatch, windowSec)` 是 air 與 ground 共用的重試時窗判定，窗口起點為 `operationBatch.time + operationBatch.delay`（`delay` 未設時視為 0），長度取 `config.c.recon.observationWindowSec`。

| 狀態 | 條件 | 建構器行為 |
|---|---|---|
| `pre_trigger` | 尚未到觸發時間 | 靜默跳過，不輸出日誌 |
| `in_window` | 觸發後、未逾時 | 每個 tick 重新評估；可重試原因保持 pending 並記 `state=observing` |
| `expired` | 超過窗口長度 | 以 `reason=observation_window_expired` 移除該作戰 |

---

## 作戰篩選

`filterOperationsByType(reconTriggeredOperationBatches, operationType)` 從尚未完成的 batch 中篩選指定類型、尚未執行的 operation。

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
| `evaluateObservationWindow(currentTime, operationBatch, windowSec)` | 判定作戰所處的觀察窗狀態 |
| `filterOperationsByType(reconTriggeredOperationBatches, operationType)` | 依類型篩選未執行的作戰 |
| `markOperationExecuted(reconEntry, operation)` | 標記作戰計畫已插入 |
| `abandonOperation(reconEntry, operation)` | 將放棄的作戰從批次移除 |
| `generateUniqueAirOperationName(operationType, reconType, saveData)` | 生成唯一空中作戰名稱 |
| `generateUniqueGroundOperationName(operationType, reconType, saveData)` | 生成唯一地面作戰名稱 |
| `registerGeneratedOperation(operationType, operationName, saveData)` | 登記已生成的作戰名稱 |

`OBSERVATION_STATE` 常數表（`pre_trigger`／`in_window`／`expired`）也由本模組匯出，供兩個建構器比對窗口狀態。

---

## 相關模組

- [fsemBuilder](fsemBuilder.md) — 使用 ground operation 篩選、命名、登記與完成狀態更新
- [atoBuilder](atoBuilder.md) — 使用 air operation 篩選、命名、登記與完成狀態更新
- [operationScheduler](operationScheduler.md) — 建立 recon-triggered operations 並管理排程查詢與下一波生成
- [系統架構](README.md)
