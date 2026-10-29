# refactor/landing-cargo-run

## 目標

第一波直升機的放飛時間，要倒推「衝鋒舟到岸時間 T」。現在 T 由 heliWave 自己算：它直接讀衝鋒舟登記表，並假設衝鋒舟一律從就位帶外緣（`launchStationFarNm`）放出。

但真正放舟的規則在 AssaultBoat：母艦進入 `landing.acv.area` 就放，不看就位帶。兩邊規則不同，母艦一開始就在區內時，T 會多算一段母艦航行時間，直升機晚到。

改成：T 由 AssaultBoat 估，和放舟用同一條「母艦在區內」規則。heliWave 只問 T，不讀衝鋒舟登記表。

## 要做到的行為

- 只算還沒放出的衝鋒舟（`pending`）。T 取最晚到岸的那一艘。
- 母艦已在 `landing.acv.area` 內：衝鋒舟現在就放，從母艦目前位置直接跑到 S_lane。
- 母艦不在區內：仍假設母艦先航到就位帶外緣再放（區的形狀程式不知道，沿用舊估法）。母艦已比外緣更靠岸，就從原地放。
- 沒有 `pending` 的衝鋒舟，或沒有 lane：T = 現在。舊版沒有衝鋒舟時仍多算一段外緣到岸的時間，這裡改成和 `docs/landingOps/heliWave.md` 寫的一致。
- airlift 的放飛時間跟著 T 變，公式不變。

## 不做

- 不改放舟的觸發條件（還是 `landing.acv.area`）。
- 不估母艦的航線何時進入 `landing.acv.area`（要做多邊形交點）。
- 不處理衝鋒舟母艦沉了的 `Unit not found`（同 `fix-landing-transport-destroyed`）。

## 驗收

- 母艦在 `landing.acv.area` 內時，第一波直升機抵達降落點的時間接近衝鋒舟到岸的時間，不再明顯晚到。
- `busted --lua=luajit spec` 全過；`bash bin/build.sh -c -n -l -i` 沒有新增警告。
