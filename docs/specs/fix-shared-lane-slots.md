# fix/shared-lane-slots

> 補寫，行為已實作。

## 目標

兩棲車、氣墊船、衝鋒舟共用同一張停靠位置表，不再疊在同一個點上。

## 要做到的行為

- 三種載具共用 `zoneState.laneSlots`（每條灘際通道一個陣列，依序是停靠位置）。修正前兩棲車與氣墊船各用一張表，兩者都拿到第 1 格；衝鋒舟上岸後停在 `S_lane` 卻沒佔任何格子。
- 衝鋒舟放出後在 `S_lane` 佔格（`assignShoreSlot`），後面的單位停在它後面。
- 佔中間的格子時，下面的空洞用 `false` 填滿，`laneSlots[laneId]` 永遠是連續陣列。否則存檔會被當成 JSON object，整數 key 讀回來變字串，`findFreeSlot` 會以為每格都空，全部單位疊在第 1 格。
- 格子表格式寫進 `docs/landingOps/routePlanner.md`。

## 不做

- 不改通道選擇與航線計算。
- 不改格子間距。

## 驗收

- `routePlanner_spec`、`assaultBoat_spec`、`hovercraft_spec` 涵蓋：共用同一張表、衝鋒舟佔格、無空洞（`#slots == slot`）、未知灘際通道回 `false`。
- `busted --lua=luajit spec` 全過；`bash bin/build.sh -c -n -l -i` 沒有新增警告。
