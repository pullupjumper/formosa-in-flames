# Requirements Document

## Introduction

本功能旨在增強現有的火力支援計畫系統，實現基於偵察結果的動態火力支援決策。目前的系統已具備基本的火力支援執行矩陣(FSEM)和火力支援任務(FST)功能，但缺乏根據即時偵察情報動態新增火力任務的能力。

增強後的系統將能夠根據特定時間的偵察結果，自動評估是否需要對目標清單中的目標進行打擊，並在必要時動態新增 FSEM 到現有的 FSP 打擊序列中。

## Requirements

### Requirement 1

**User Story:** 作為火力協調官，我希望系統能夠根據指定的基地和設施類型識別需要進行 BDA 評估的目標

#### Acceptance Criteria

1. WHEN 系統啟動評估流程時 THEN 應根據指定的基地名稱篩選目標
2. WHEN 篩選目標時 THEN 系統應支援多種設施類型（彈藥庫、抗炸機堡、跑道、滑行道、雷達等）
3. IF 目標符合指定的基地和設施類型條件 THEN 系統應將其列入 BDA 評估清單
4. WHEN 目標識別完成時 THEN 系統應準備對篩選出的目標進行戰損評估

### Requirement 2

**User Story:** 作為情報分析官，我希望系統能夠自動評估目標清單並篩選出需要補充打擊的目標

#### Acceptance Criteria

1. WHEN 系統進行 BDA 評估時 THEN 應自動分析目標的損毀狀態和偵察時間點
2. WHEN 評估完成時 THEN 系統應產生需要補充打擊的目標清單
3. IF 目標符合補充打擊條件 THEN 系統應將其加入打擊目標清單
4. WHEN 篩選完成時 THEN 系統應準備為這些目標創建火力任務

### Requirement 3

**User Story:** 作為火力支援指揮官，我希望系統能夠根據篩選後的打擊清單數量決定是否需要執行補充打擊

#### Acceptance Criteria

1. WHEN 篩選完成後 THEN 系統應檢查打擊清單中的目標數量
2. WHEN 打擊清單數量大於指定閾值時 THEN 系統應決定執行補充打擊
3. IF 打擊清單數量未達到指定閾值 THEN 系統應跳過 FSEM 創建程序
4. WHEN 決定執行打擊時 THEN 系統應根據打擊清單、指定基地和設施資料準備新增 FSEM

### Requirement 4

**User Story:** 作為戰術規劃官，我希望系統能夠自動創建新的 FSEM 並將其插入到現有的 FSP 打擊序列中

#### Acceptance Criteria

1. WHEN 決定對目標進行補充打擊時 THEN 系統應自動創建新的 FSEM
2. WHEN 創建 FSEM 時 THEN 系統應包含執行時間、目標清單、執行的打擊單位和武器系統
3. IF 需要插入 FSP 序列 THEN 新 FSEM 應直接插入在序列的最末端
4. WHEN FSEM 插入完成時 THEN 系統應更新整體火力支援時程表

### Requirement 5

**User Story:** 作為情報官，我希望系統能夠根據預定義的偵察時程表，在偵察任務完成後自動觸發 BDA 評估流程

#### Acceptance Criteria

1. WHEN 偵察時程表中的時間點到達時 THEN 系統應在指定延遲後自動啟動評估流程
2. WHEN 系統執行時 THEN 應接受事件腳本傳入的 contacts 參數，避免重複取得聯絡人資料
3. WHEN 偵察任務為大範圍類型（衛星、WZ-8）時 THEN 系統應能夠處理多個 FST 的 FSEM 模板
4. IF 偵察任務為小範圍類型（一般偵察機）時 THEN 系統應處理單一或少數 FST 的 FSEM 模板

### Requirement 6

**User Story:** 作為武器系統操作員，我希望系統能夠根據目標類型和偵察結果自動選擇適當的武器系統和彈藥

#### Acceptance Criteria

1. WHEN 創建 FST 時 THEN 系統應根據 FSEM 模板中指定的武器系統類型分配火力單位
2. WHEN 分配武器時 THEN 系統應使用預定義的 weaponDBID 確保彈藥類型正確
3. IF 不同 FST 需要不同武器系統 THEN 系統應能夠在同一 FSEM 中混合使用多種武器
4. WHEN 武器分配完成時 THEN 系統應驗證所選武器系統的可用性和彈藥庫存