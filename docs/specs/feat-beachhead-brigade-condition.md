# feat/beachhead-brigade-condition

## 目標

取代 `coordinator.lua` `stepAssaultLanding` 的 TODO「Replace with a stricter beachhead condition」。作戰區登陸的兵力達該區規模（桃園、喜樹 為旅級，澎湖為營級），才算灘頭穩固，才進入行政下卸階段。

## 要做到的行為

- `ASSAULT_LANDING` 階段每個 tick 數該區 `ZBD-05` 加 `ZTD-05` 的存活數（`AmphibiousAssault.countUnitsInEachArea`）。
- 合計達該區的 `landing.beachheadVehicles` 時，該區進入 `WAITING_ADMIN_OFFLOADING`。預設值：Taoyuan 168、Sishu 168（約旅級 224 輛的 3/4），Penghu 42（營級，旅的 1/4）。
- 未達門檻，維持 `ASSAULT_LANDING`，不啟動行政下卸。
- 該區沒有統計資料時，視為 0 輛。
- 各區用自己的門檻，分開判斷，互不影響。

### 設定與型別

- `config.red.amphibOps.zones[i].landing.beachheadVehicles`，型別 `SBJ__ZoneLanding`（`src/core/schema.lua`）。

## 不在範圍內

- `WAITING_ADMIN_OFFLOADING` 的絕對安全條件（另有 TODO）。
- 其他車種（PLL-05、PLZ-96 等）不計入門檻。
- 兩棲車補波規則（`acvWave`）不變。

## 驗收

- `spec/modules/landingOps/coordinator_spec.lua`：
  - ZBD-05 + ZTD-05 達門檻 → 經 `WAITING_ADMIN_OFFLOADING` 到 `COMPLETED`，呼叫 `startAdminOffloading`。
  - 差一輛 → 停在 `ASSAULT_LANDING`，不呼叫 `startAdminOffloading`。
  - 門檻取自該區自己的設定。
- `busted --lua=luajit spec` 全過。
- `bash bin/build.sh -c -n -l -i` 無新警告。
