# fix/missile-panel-saved-layout

## 目標

config 是飛彈連部署的基礎模板。玩家部署後，新的作戰區存在 saveData，遊戲邏輯（移動、會合、隱蔽、SIGINT）都讀 saveData。

但控制面板的部署頁還是用 config 畫地圖。同一個 session 裡沒事，因為 redeploy 會順便改寫 config。存檔再讀檔後，config 變回模板，面板就畫出模板的陣地，不是玩家選的位置。

目標：面板用 saveData 的作戰區畫已部署的發射單位，符合「部署過後就沿用新的部署資料」。這是架構審查候選 #5 縮小後的版本。

## 要做到的行為

- 發射單位在 saveData 裡有作戰區：面板畫 saveData 的作戰區。
- saveData 裡沒有（例如該陣營 ground 沒啟用、還沒 init）：照舊用 config。
- 只讀不寫：產生面板資料不會改到 saveData 或 config。
- 前端判斷「有沒有動過」照舊以注入的資料為基準；讀檔後沒動的單位按 Done 不會被重建。
- Redeploy 只重設被搬動的飛彈連（發射車、補給車、彈藥庫）的單位與狀態。其他飛彈連的狀態、reload 計時、彈藥量不變。開局 saveData 為空，開場仍由 `deploySide` 從 config 建好每一連。

## 不做

- 不改 redeploy 改寫 config 的做法。部署只在開打前或遊玩模式第一次送出，之後鎖住，所以讀檔後不會再部署。`ConfigCodeGenerator.dump` 靠這份改過的 config 匯出位置。
- 不改前端。開打後鎖住部署是前端的事，還沒做；後端這次先保證就算中途 redeploy，也不會弄壞其他飛彈連。

## 驗收

- 遊玩模式：部署 → 存檔 → 讀檔 → 打開控制面板，地圖上的飛彈連在玩家選的位置。
- 編輯模式：同上流程後不動飛彈連直接按 Done，log 沒有重建飛彈連。
- 只搬一連：其他飛彈連的 state、`reloadStartTime`、補給車與彈藥庫彈藥不變（`init_spec` 的 redeployFromControlPanel 測試）。
- Lua：`busted --lua=luajit spec`、`bash bin/build.sh -c -n -l -i` 沒有新增警告。
