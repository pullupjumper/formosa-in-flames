# fix/fast-forward-mine-clearing

> 補寫，行為已實作。

## 目標

快轉測試（`config.red.amphibOps.debug`）跳過前面階段時，每區只佈自己的水雷再掃，不再整張地圖重佈。

## 要做到的行為

- 快轉時各區只佈 `minefields[].zone` 等於該區的那一塊雷區，佈完才開始掃雷。
- 修正前：每區在自己掃完之後才佈三塊雷區，所以掃雷什麼都沒掃到，後面的區又把前面區已清的通道重新佈雷。
- 快轉用的雷格大小改讀 `tuning.mineClearing.cellSizeM`（300 m），不再與障礙方塊共用格子大小。

## 不做

- 不改正式流程（非快轉）的佈雷與掃雷。
- 不改掃雷任務與通道計算。

## 驗收

- `mineClearing_spec` 涵蓋：只佈本區雷區、先佈後掃、雷格用 `cellSizeM`。
- `busted --lua=luajit spec` 全過；`bash bin/build.sh -c -n -l -i` 沒有新增警告。
- `docs/landingOps/mineClearing.md`、`debugFlow.md` 同步。
