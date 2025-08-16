# 動態ATO插入模組 - 需求規格

## 概述
基於衛星或偵察機的偵查結果，自動決策並動態插入新的wave、package到saveData.c.ATO中。

## 核心功能需求

### 1. 偵察觸發機制
- 監控偵察時程並自動觸發目標評估
- 支援衛星和偵察機兩種情報來源
- 根據偵察結果決定是否需要新任務

### 2. 目標評估與決策
- 整合TargetingProcess進行目標分析
- 評估目標威脅等級和優先級
- 決定任務類型和規模需求

### 3. ATO動態插入
- 生成符合ATO結構的wave/package
- 無縫插入現有saveData.c.air.ATO
- 維持數據結構完整性

### 4. 資源衝突管理
- 檢查與現有任務的資源衝突
- 智慧選擇執行時機
- 避免重複分配飛機和武器

## 技術整合要求

### API和模組整合
- 使用GameAPI包裝所有CMO API調用
- 整合TargetingProcess模組
- 支援Utils.safeCall錯誤處理
- 遵循LuaLS類型標註規範

### 數據結構兼容
- 完全相容saveData.c.air.ATO結構
- 支援loadoutStatus狀態追蹤  
- 與launcher模組協作
- 參考dynamicFSP的reconSchedule模式

## 配置結構
模組配置應放在constants.lua中的適當命名空間，包含：
- 偵察觸發參數
- 目標評估閾值
- 任務模板定義
- 資源分配策略