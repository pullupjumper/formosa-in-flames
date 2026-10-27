# feat/add-units-menu

> 補寫，行為已實作。

## 目標

把各單位各自一個的 `addXXX` 特殊行動，併成一個「新增單位」選單頁。

## 要做到的行為

- 玩家在選單頁勾要新增的單位，按 Done 後才執行勾選的動作。
- 原本的 `addXXX` 特殊行動腳本移除，只留選單入口（`UnitStatusUI` 的選單）。
- 沒勾的單位不新增。

## 不做

- 不改各單位新增的內容與數量。
- 不改兩陣營的可用單位清單。

## 驗收

- `unitStatusUI_spec` 涵蓋新增單位動作只在編輯模式執行。
- `busted --lua=luajit spec` 全過；`bash bin/build.sh -c -n -l -i` 沒有新增警告。
- `src/core/init.lua` 註冊新入口，舊 `addXXX` 名稱已不存在。
