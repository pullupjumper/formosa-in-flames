# refactor/launcher-transloader

## 目標

發射車在程式裡有五種意思：strikePlanner 的 FST 項目、config、存檔、遊戲單位，還有補給車設定裡的配對名字。補給車也同時叫 resupply unit 和 transloader。這次統一用軍語：發射車叫 launcher，補給車叫 transloader，存檔一起改（`docs/missileSystem/naming-review-2026-11-05.md` N7）。

改名前先修兩個 bug，再拿掉 FST 模板裡重複的武器設定，最後做改名。

## 要做到的行為

- LACM 齊射：CSG 裡的 055 照名字開火。之前傳的項目沒有名字，`AttackManager` 找不到單位，一發都沒射。
- SLCM 齊射：從 config 裡還存在的潛艦開火，已經不在的潛艦略過。之前 config 是以名字為 key 的表，被當成空陣列，一發都沒射。
- FST 模板只列發射車名字。開火時武器從該發射車的 config 取，不再在模板重寫一次。之前兩邊的值全部相同。
- `AttackManager` 收的是「攻擊單位」（名字加可選武器），不是發射車專用。船艦、潛艦、發射車共用。
- 存檔的發射車與補給車欄位改名。舊存檔不支援，需要新開局。
- 控制面板文字跟著改：Launcher、Transloader、Launcher Reload、Transloader Reload。
- log 的角色欄位與部署摘要改成 `launcher`、`transloader`。

## 不做

- 不改飛彈連的狀態機、移動、會合、隱蔽、補彈規則。
- 不改「發射陣地」(firing point) 的名字，它是地點。
- 不改描述補彈動作的名字（`RESUPPLY_VIA_SHRL`、`RESUPPLY_RECALL`）。
- 不讀舊存檔，也不寫轉換舊存檔的程式。
- 不做 N8 剩下的事件命名與 `finishReload` 改名。

## 驗收

- 新開局：LACM、SLCM 到時間會發射，log 沒有 `AttackContact: Unit not found`。
- 新開局：FST 開火用的飛彈與改名前相同。
- 控制面板的飛彈連狀態顯示新文字，數值與改名前相同。
- Lua：`busted --lua=luajit spec`、`bash bin/build.sh -c -n -l -i` 沒有新增警告。
- 前端：在 `htmls-app/` 跑 `npm test`、`npm run lint`。
