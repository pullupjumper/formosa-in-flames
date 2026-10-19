# refactor/amphib-ops-zones

## 目標

整理 landingOps 的命名與規範，讓名稱和實際行為一致；順便補上空/機降區所需的設定。

## 要做到的行為

- `adminUnloading` 全面改名為 `adminOffloading`（模組、spec、docs、`constants.TAGS`、`AMPHIBIOUS_PHASES.WAITING_ADMIN_OFFLOADING`）。
- 距離類設定鍵加上 `Nm` 後綴；新增 `constants.METERS_PER_NM`。
- 新增 `config.red.amphibOps` 欄位：
  - `remainingCargoTransferSec`：空/機降任務開始後，每隔多久補運一次尚未運完的貨物。
  - `airlandingFireQty`：SAG 壓制空/機降區時，全部目標合計的射擊彈數。
  - `bargeRoroPairingRangeNm`：駁船與 RORO 距離小於此值才算同一組。
- 新增 `GameUtils.hasUnit(guid)`，檢查單位 GUID 是否仍存在。
- `neutralizeAirlandingZone.lua` 改名為 `attackAirlandingZone.lua`。
- 文件：新增 `docs/coding-style.md`；`docs/FEATURES.md` 改名為 `docs/features.md`；`docs/naming.md` 與 landingOps 各文件跟著更新。

## 不做

- 不改遊戲流程與數值平衡。
- 不 commit debug 暫改：`amphibiousOps.startTime`、`dynamicOperations.enabled`。

## 驗收

- `busted --lua=luajit spec` 全過。
- `bash bin/build.sh -c -n -l -i` 沒有新增警告。
- 全專案已無 `adminUnloading` / `ADMIN_UNLOADING` 殘留（`grep -ri unloading` 檢查）。
