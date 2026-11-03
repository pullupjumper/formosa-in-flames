# refactor/missile-system-rules

## 目標

`transitions` 已經是唯一寫入狀態的地方，但「下一步要做什麼」的判斷還散在三處，而且和 CMO 呼叫混在一起：`arrival` 的 FP / HA / RL / AHA handler、`cycle` 的四段 start / complete 函式、`init` 的 `sendToFiringPoint`、`startStow`、`evaluateReadiness`。想知道「RELOAD 中的發射車什麼時候走」要讀三個檔案；測試只能 stub 內部呼叫去猜。

目標：package 內新增 `rules` 模組，用純函式把觀察表（state、彈量、會合、經過秒數、policy 開關、配對單位在不在）轉成有順序的步驟名稱清單。`arrival`、`cycle`、`init` 改成「收集觀察 → 問 Rules → 照步驟執行」。這是架構審查候選 #1 的方案 B，接在 `refactor/missile-system-transitions`（方案 A）之後。

## 要做到的行為

- 所有轉換的觸發條件、順序、log 字串和現在相同。
- 唯一差異：`arrival` 和 `cycle` 會先收齊觀察表，所以 `Ammo.isLowAmmo`、`ScenEdit_GetUnit`、`Meeting.hasMet*`、`Meeting.findUnitArea` 這些唯讀查詢會比現在多跑幾次。它們不寫入任何東西，遊戲行為不變。
- `sendToFiringPoint` 與 `evaluateReadiness` 的彈量用 callback 傳給 Rules，只在單位 HIDE 時讀。FSP 每輪都會問，移動中的單位不多讀彈量。
- `staysDeployed`（SAM）與 `isRepositioning` 從 `transitions` 搬到 `rules`；`transitions` 只剩寫入。
- 「補給車還有彈且在作戰區才藏回」留在 cycle 的 handler，因為剩餘彈量要等裝填做完才知道。
- facade 對外函式與參數不變。

## 不做

- 不修「往 FP 途中穿過 RL 被改成 STATIC」的已知風險（下一步；改 `rules` 的 RL 沒會合那一列即可）。
- 不改單位名稱查表（候選 #3）、trigger 名稱協定（候選 #4）、redeploy 改寫 config（候選 #5）。
- 不做跨檔共用的 executor：arrival 的 log 列帶 `system=`，cycle 的由 init 補上，格式不同。

## 驗收

- `rules_spec` 用表格測試涵蓋每個分支，不需要 stub。
- `cycle_spec` 不改就通過；`arrival_spec` 只改掉 stub `Transitions.isRepositioning` 的地方和一個「唯讀查詢沒被呼叫」的斷言；刪掉與 `rules_spec` 重複的純條件測試。
- 在 `src/modules/missileSystem/` 搜 `MISSILE_SYSTEM_STATE.`：比對只出現在 `rules`、`transitions`（寫入）、`meeting`（會合判斷）、`statusView`（顯示）。
- 同一個場景跑自動模式完整一圈（FSP 出發 → FP → 收車 → RL 裝填 → AHA 轉載 → 回 HA），log 和改之前相同。
- `docs/missileSystem/` 加上 rules 說明，arrival / cycle / init / transitions 的文件改成指向 rules。
- Lua：`busted --lua=luajit spec`、`bash bin/build.sh -c -n -l -i` 沒有新增警告。
