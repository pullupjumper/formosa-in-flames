# fix/landing-transport-destroyed

## 目標

運輸直升機和固定翼運輸機被擊落後，不再每個 tick 噴 `Unit not found with name` ERROR。

原因：`GameApi.ScenEdit_GetUnit` 找不到單位會 `error`，被 `tryCall` 記成 ERROR 再回 `nil`。被擊落的運輸機留在 `units` / `airlift.units`，每個 tick 被 `updateTransports`、`findFlyingTransports` 重複查，直到整波（批）被換掉。

## 要做到的行為

- 擊殺事件發生時，把被擊落的運輸直升機從 `heliWave.units` 移除，運輸機從 `heliWave.airlift.units` 移除（依 GUID，找所有區）。
- 移除後，一波（批）是否結束的判斷不變：移除等同「已被擊殺」，不算還在空中。
- 移除不改變下一波的架數計算：運輸直升機、運輸機的架數只看候選（`waveSize`、`airlift.size`），不看 `units`；`units` 只用來判斷這一波（批）結束了沒。
- 沒有紀錄的 GUID 不報錯，回 `false`。
- `destroyUnits.lua` 在 Z-18（運輸直升機）和 IL-76（運輸機）被擊殺時呼叫同一個 `LandingOps` facade 函式。
- 攻擊直升機的移除（`attackers`）行為不變。

## 不做

- 不改 `GameApi.ScenEdit_GetUnit` 的 `error` 行為。
- 不改輪詢邏輯，輪詢仍把 `GetUnit` 回 `nil` 視為被擊殺（事件沒趕上時的後備）。
- 不處理其他模組的 `Unit not found`（`startMineClearing` 的 `GetMission`、UAV 的 `GetUnit`）。

## 待確認

1. 事件和輪詢誰先到。輪詢搶先時，還是會噴一筆 ERROR；接受這一筆，還是另外做不 `error` 的查詢。

## 驗收

- `busted --lua=luajit spec` 全過。
- `heliWave_spec` 新增：
  - 移除運輸直升機後，該波結束判斷與被擊殺相同，且之後不再對它呼叫 `GetUnit`。
  - 移除運輸機後，同上，且不影響直升機。
  - 沒有紀錄的 GUID 回 `false`。
  - 攻擊直升機移除行為不變。
- `bash bin/build.sh -c -n -l -i` 沒有新增警告。
- 同步更新 `docs/landingOps/heliWave.md` 的「狀態」段。
