# refactor/ground-missile-system-types

> 補寫，行為已實作。多為欄位形狀調整，只有第 3 點有行為差異。

## 目標

`config.<side>.ground` 與 ground context 依「政策」與「飛彈系統類別」分層，走訪時直接迭代 `missileSystemTypes`。

## 要做到的行為

- `config.<side>.ground` 分成 `policy`（如 `isAuto`）與 `missileSystemTypes`（`mlrs`、`srbm`…）。
- 執行期 ground context 的各系統狀態放在 `missileSystemTypes` 之下；程式直接迭代 `missileSystemTypes`，不再靠 `systemTypes` 過濾。
- 發射單位設定新增 `missileSystem` 欄位（標示所屬系統）；目前執行期沒有程式讀它。
- `task.missileSystem` 改名 `missileSystemType`；`systemName` 改名；`MissileRunContext` 單欄位 table 改為直接傳 `isAuto`。
- 頂層 config 欄位搬進陣營 namespace（`config.red.*`、`config.blue.*`、`config.score.*`）。

## 不做

- 不改 reload / hide / 發射的遊戲行為與數值。
- 不為舊存檔做 migration（開新局會重設 saveData）。

## 驗收

- `busted --lua=luajit spec` 全過；`bash bin/build.sh -c -n -l -i` 沒有新增警告。
- `docs/missileSystem/*.md` 與 `docs/naming.md` 同步新路徑。
