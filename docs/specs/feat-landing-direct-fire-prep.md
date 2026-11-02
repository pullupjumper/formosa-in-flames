# feat/landing-direct-fire-prep

## 目標

「直接火力準備」是突擊上陸階段，對登陸區目標的打擊與壓制。現在有兩條路，分散在不同地方：

- 艦砲：052D 的 SAG 打空/機降區，程式在 `sagFireSupport`，任何階段只要有目標就開火。
- 戰機：作戰區進入 `WAITING_ASSAULT` 時排偵察，找到目標由 strikePlanner 派機打，觸發寫在 coordinator 裡。

改成兩條路放在同一個模組 `directFirePrep`。艦砲只在突擊階段開火。`fireSupportGate` 只留 SRBM 暫停開關，不放開火邏輯。

## 要做到的行為

- 艦砲只在該 SAG 所屬作戰區的階段為 `WAITING_ASSAULT`、`MINE_CLEARING`、`BOAT_ASSAULT`、`OBSTACLE_CLEARING`、`ASSAULT_LANDING` 時開火。之前、之後（含行政下卸）都不開火。
- 階段不對時，不查接觸、不改武器管制。
- 艦砲開火前把對地武器管制設為 `TIGHT`（舊版是 `FREE`）。
- 偵察觸發時機不變：進入 `WAITING_ASSAULT` 時排一次。
- 陸基運輸機轉貨不是火力，留在 coordinator。

## 不做

- 不改 strikePlanner 偵察後怎麼派機（`strikeMappings` 不動）。
- 不改每目標彈數的算法。

## 順帶的行為改變

同一個 branch 的 refactor commit 帶出的改變，都是刻意的：

- 快轉掃雷只清本區雷區裡、位在本區航道上的雷。舊版會掃所有區的雷區。三個雷區相距很遠，實際上沒差。
- heliWave 存檔形狀改成 `transport` / `airlift` / `attackHelis`，沒有舊存檔轉換。直升機波次進行中的舊存檔可能讀不了，請改讀登陸作戰開始前的存檔。
- heliWave 日誌欄位改名：`fleet` → `airWave`、`batch` → `wave`、`attackers` → `attackHelis`。

## 待確認

- 目標數多於 `airlandingShotQty` 時，每目標 0 發。傾向：之後再處理。

## 驗收

- 作戰區還在 `MOVING` / `WAITING_ARRIVAL` 時，052D 進入 SAG 區不開火；進入 `WAITING_ASSAULT` 後才開火。
- 偵察仍在進入 `WAITING_ASSAULT` 時排入。
- `busted --lua=luajit spec` 全過；`bash bin/build.sh -c -n -l -i` 沒有新增警告。
