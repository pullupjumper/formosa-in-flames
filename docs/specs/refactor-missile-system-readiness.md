# refactor/missile-system-readiness

## 目標

現在 strikePlanner 從 missileSystem 拿到發射單位的原始狀態表，自己判斷「在不在掩蔽中」、自己算低彈量，再把狀態表交回去要它出發。「這個飛彈連能不能打」散在 package 外面，狀態列舉也越過了 facade。

目標：missileSystem 的 facade 對外只回答「能不能打、為什麼不能」與「出發到 FP」，原始狀態表不再交出去。行為不變，log 不變。

## 要做到的行為

- 呼叫端只把 ground 狀態當成不透明的把手傳進來，加上飛彈系統類型與單位名稱；不讀裡面的欄位。
- 新增一個 readiness 判斷，回傳一個原因代碼：可以打、找不到狀態、找不到單位、不在掩蔽中、低彈量。代碼字串和現在 FSEM log 的計數鍵一模一樣，所以 log 輸出不變。
- 判斷順序：找不到狀態 → 找不到單位 → 不在掩蔽中 → 低彈量。
- 遊戲單位由呼叫端提供的取單位函式給，只在真的需要時才呼叫；FSEM 每輪一次的單位快取保留，不增加 `ScenEdit_GetUnit` 次數。
- 「已經被派任務」由 strikePlanner 在呼叫 readiness 之前自己判斷，它屬於規劃端。唯一可見差異：已派任務但沒有狀態的單位會被算成「已派任務」而不是「找不到狀態」；實務上不會發生。
- 「出發到 FP」改成只收 ground 狀態、類型、單位名稱，自己找單位與狀態，回傳「是否已就位」與「單位是否不見」。行為和現在 FSP 的判斷相同。
- 只為了測試而公開的函式（取原始狀態、低彈量判斷、單輪循環、重新部署）改成私有；測試改從實際的對外入口進來。
- 原因代碼放 `constants`，因為它是不變的識別碼。

## 不做

- 不改 `airTaskingOrder` 寫死 red / srbm 讀 `reloadTime`；讀 config 不算越過 missileSystem 的 seam，另外處理。
- 不改 `persistentState` 給 SIGINT 走訪發射單位；saveData 的形狀本來就歸 core 管。
- 不改 `startStow`、`getAmmoInventory`；它們已經只收 ground 狀態。
- 不動 Battery 狀態機（架構審查候選 #1），這次只封 seam。

## 驗收

- strikePlanner 不再讀發射單位的 `state` 欄位，也不再引用 missileSystem 的狀態列舉。
- 同一個場景跑一輪 FSEM，log 裡各類計數與字串和改之前相同。
- FSP 部署發射單位的結果（已就位、單位不見）和改之前相同。
- facade 外部沒有任何地方呼叫被改成私有的函式；`spec/moduleBoundary_spec.lua` 通過。
- `docs/missileSystem/init.md` 的 Public API 表反映新的對外函式，並說明 readiness 這個詞。
- Lua：`busted --lua=luajit spec`、`bash bin/build.sh -c -n -l -i` 沒有新增警告。
