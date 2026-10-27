# feat/c2-map-layers

> 補寫，行為已實作。

## 目標

control panel 的地圖畫出 C2 節點的作戰區、所屬單位與連線。

## 要做到的行為

- C2 節點與其 SAM / 雷達單位以扁平的 `guid → node` payload 送到前端，每筆含 `pos`、`areas`、`type`；修正 `areas` 被插進節點本身的錯誤。
- 每個作戰區只畫一次；C2、SAM、雷達用 NATO 圖示標示（新增 `RadarIcon`），單位以白線連到所屬 C2。
- 重新部署的 SAM 只連到「同類型、作戰區含新位置、距離最近」的 C2；已部署的 SAM 不重複畫。
- SAM 欄位與 `C2Child` / marker 的種類改小寫 `sam` / `radar`。

## 不做

- 不改 C2 指派邏輯。
- 不在 CMO 地圖上畫，只畫在 control panel 的 Leaflet 地圖。

## 驗收

- `unitStatusUI_spec` 涵蓋新 payload 欄位；前端 `c2Nodes.test.ts` 涵蓋節點與連線的整理。
- `busted --lua=luajit spec` 全過；`npx vitest run`、`npx tsc -b` 全過。
- `bash bin/build.sh -c -n -l -i` 沒有新增警告。
