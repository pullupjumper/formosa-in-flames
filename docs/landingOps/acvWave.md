# acvWave — 兩棲車存活上限與分波

> 原始碼：`src/modules/landingOps/acvWave.lua`

**職責**：限制每區同時存活的兩棲車數量，並以波次釋放；同時決定氣墊船何時可以出發

---

## 概述

不加控制時，渡輪一次載 56+56 輛，桃園第 2 次釋放就超過一個旅（224 輛），之後仍持續放出。acvWave 規定**每區每車種**（ZBD-05、ZTD-05 各自計算）同時存活數不超過該區的 `capacity`（旅級 112，Penghu 營級 28）。

額度以已放出的車輛 GUID 計算：存活數 = 仍存在的 GUID 數（航行途中也算）。被摧毀的車 `ScenEdit_GetUnit` 回 `nil`，會在下次計算時剔除。GUID 存在 `zoneState.acvGuids`，暫停時間存在 `zoneState.acvPausedAt`（型別見 `schema.lua` 的 `SBJ__ZoneState`）。

---

## 額度與暫停

- 額度 = `capacity - 存活數`，不為負
- 額度算到 0 時記下暫停時間，之後固定回 0
- 暫停中符合任一條件就恢復並補到上限：
  - 戰損：存活數降到 `capacity × (1 - lossRatio)` 以下
  - 逾時：距離暫停達 `holdSec`

同一 tick 內多艘船共用額度：`addACV` 在每輛車放出時立刻登記，先處理的船先拿，後面的船額度自然變少。

### 為什麼 holdSec 不能太短？

逾時不應小於兩棲車抵達灘頭的時間（泛水出發線距岸 2～4 nm、約 8 kt，約 15～30 分鐘）。太短的話前一波還在海上就補下一波，等於沒有上限。

---

## 氣墊船放行

`isFirstWaveFull` 回傳 `true` 的條件（滿足一次即鎖定，之後恆為 `true`）：

- 每個車種的存活數都達到 `capacity`
- 或從第一次呼叫起算已超過 `hovercraftWaitSec`

等待計時從**第一次呼叫**開始（存在 `acvWaitStartedAt`），不是從階段開始。這個結果由 [coordinator](coordinator.md) 的 `stepHovercraft` 用來決定是否放氣墊船。

### 為什麼要有逾時？

兵力不足的區（例如澎湖 ZBD-05 只有 28 輛，見 [hovercraftCapacity](hovercraftCapacity.md)）永遠放不滿 112，若不加逾時，氣墊船會永遠等下去。

---

## 公開 API

| 函式 | 說明 |
|---|---|
| `getQuota(zoneState, config, currentTime)` | 各車種剩餘額度（key 為 `zbd05`、`ztd05`） |
| `isFirstWaveFull(zoneState, config, currentTime)` | 氣墊船是否可放行 |
| `zoneConfig(tuning, zone)` | 共用參數加上該區的 `capacity` |
| `addACV(zoneState, key, guid)` | 登記新放出的車 |

---

## 設定

上限依作戰區規模各自設定：`zones[i].landing.acv.capacity`（Taoyuan、Sishu 各 112，Penghu 營級 28）。呼叫端用 `zoneConfig(tuning, zone)` 把它併入共用參數。

`config.red.amphibOps.tuning.acvWave`（各區共用）：

| 欄位 | 用途 |
|---|---|
| `lossRatio` | 戰損比例，觸發補波 |
| `holdSec` | 暫停逾時補波 |
| `hovercraftWaitSec` | 氣墊船等第一波放滿的上限 |

---

## 相關模組

- [amphibiousAssault](amphibiousAssault.md) — 以額度決定 `isEmpty`／`isPaused`
- [hovercraft](hovercraft.md) — 受 `isFirstWaveFull` 限制
- [assaultTimeline](assaultTimeline.md) — 各區預計波次
- [系統架構](README.md)
