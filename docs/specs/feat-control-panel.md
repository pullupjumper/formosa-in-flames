# feat/control-panel

> 補寫，行為已實作。

## 目標

把設定選單、單位狀態、EMCON 設定、新增單位四個頁面併成一個 control panel，分編輯模式與遊玩模式。

## 要做到的行為

- 單一特殊行動 `UnitStatusUI.createControlPanel` 開啟 control panel；舊的 `setup-menu`、`unit-status`、`emcon-setting`、`add-units-menu` 頁面與對應 Lua 選單移除。
- `config.isEditMode = true`：沒有任何東西被隱藏或鎖定。
- `config.isEditMode = false`（`bash bin/build.sh -p`）：隱藏 Landing Units 與 Add Units；干擾機、飛機、發射架的部署只接受一次，之後以 `saveData.<side>.isDeploymentLocked` 鎖住。
- 表單空白欄位視為未設定，不送進 JSON parser。
- 前端 `htmls-app/src/pages/control-panel` 取代原本四個頁面；舊頁面還在用的程式搬進 control-panel。

## 不做

- 不改 EMCON、部署、新增單位各自的內容。
- 不改飛彈系統的 reload / hide 邏輯。

## 驗收

- `unitStatusUI_spec` 涵蓋：遊玩模式鎖定、編輯模式不鎖、第二次部署被拒。
- `busted --lua=luajit spec` 全過；前端 `npx vitest run` 與 `npx tsc -b` 全過。
- `bash bin/build.sh -c -n -l -i` 沒有新增警告。
