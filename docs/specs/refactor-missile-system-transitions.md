# refactor/missile-system-transitions

## 目標

飛彈連的狀態（STATIC / REPOSITIONING / RELOAD / HIDE）和兩個計時器（裝填開始、收車開始）現在散在 init、cycle、movement、ammo 四個檔案寫入。同一個轉換常拆成兩半：裝填完成時 ammo 先寫 STATIC，cycle 再叫 movement 寫 REPOSITIONING；收車計時器 facade 和定時循環各寫一份。單看一個檔案看不出完整的轉換。

目標：package 內新增一個 transitions 模組，成為唯一寫入狀態與計時器的地方，以有名字的轉換函式表達（例：開始收車、出發、抵達、裝填完成）。movement、ammo 只負責對 CMO 下指令與算彈藥，不再改狀態。這是架構審查候選 #1 的輕量版（A），不做轉換表。

## 要做到的行為

- 所有轉換的觸發條件、順序、log 字串和現在相同，除了下一條。
- 修正：移動指令失敗（沒有可用位置、資料不完整）時，狀態不改成 REPOSITIONING，保持原狀態。現在是先改狀態再移動，失敗後單位不動卻永遠停在 REPOSITIONING，沒有任何路徑能救回。
  - 可見差異：補給車往 AHA 移動失敗後維持 STATIC，下一輪循環會再試，每輪多一條 FAIL log。
  - FSP 派往 FP 失敗：單位已從掩蔽建築卸出，但狀態維持 HIDE，下次 FSP 會再試。
  - 收車倒數結束後移動失敗：收車計時器照舊清掉，不重試，單位維持 STATIC。失敗通常是陣地位置沒設好，重試也不會成功；FSP 下次收車可再觸發。
- 進入 RL / AHA 沒有配對裝填就轉 STATIC，這是設計本意，照舊（手動模式本來就沒有 REPOSITIONING）。
- 「SAM 不收車、裝填完直接回 FP」的判斷在 transitions 裡只寫一次；`Shared.isSAM(dbid)`（決定 WCS 用防空或對地）不屬於狀態機，不動。
- facade 對外函式與參數不變。

## 不做

- 不做純轉換表 + 指令執行器（方案 B）。
- 不改單位名稱查表（候選 #3）、trigger 名稱協定（候選 #4）、redeploy 改寫 config（候選 #5）。
- 不處理下面「已知風險」。
- 不動 `config.lua` 裡各單位的初始狀態值。

## 已知風險（不在這次處理）

自動模式下，發射車往 FP 途中若穿過 RL 區域，會被轉成 STATIC；抵達 FP 時系統認為它不在移動中，WCS 不會開成 FREE。只有 RL 剛好在路上才會發生，需進遊戲確認地圖。

## 驗收

- 在 `src/` 搜尋 `.state =`、`reloadStartTime =`、`stowStartTime =`，飛彈連的寫入只出現在 transitions 模組（`config.lua` 初始值與 groundStateStore 建立初始狀態除外）。
- 同一個場景跑自動模式完整一圈（FSP 出發 → FP → 收車 → RL 裝填 → AHA 轉載 → 回 HA），log 和改之前相同。
- 移動失敗時單位不會卡在 REPOSITIONING。
- `docs/missileSystem/` 加上 transitions 說明，movement / ammo / cycle 的文件不再說它們改狀態。
- Lua：`busted --lua=luajit spec`、`bash bin/build.sh -c -n -l -i` 沒有新增警告。
