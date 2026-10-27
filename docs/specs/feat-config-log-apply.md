# feat/config-log-apply

> 補寫，行為已實作。

## 目標

在 CMO 內產生的 config 程式碼，不用手動複製，改由腳本從 Lua log 寫回 `constants.lua` / `config.lua`。

## 要做到的行為

- `ConfigCodeGenerator.dump(sideName, missileSystemConfigMap)` 把產生的程式碼以 `@@GEN_BEGIN <name>` / `@@GEN_END <name>` 包起來，印進 CMO Lua log。
- `tools/apply_generated_config.py` 讀最新的 `LuaHistory_*.txt`（路徑來自 `$CMO_DIR` 或 `--log-dir`），同名區段取最後一個。
- `*_AREAS_BLOCK`、`*_OPERATIONAL_AREAS_BLOCK`：取代 `constants.lua` 中 `-- START: <name>` 與 `-- END: <name>` 之間的行；`constants.lua` 補上這些標記。
- `CONFIG_<field>`：每個 `config.… = {` 區塊取代 `config.lua` 裡標頭相同的區塊（到第一個剛好是 `}` 的行為止）。
- 找不到標記或區塊時警告並以非零代碼結束；`--dry-run` 不寫檔。

## 不做

- 不處理 `ally` 側的區塊（`constants.lua` 沒有對應標記）。
- 不自動執行腳本。

## 驗收

- `configCodeGenerator_spec` 涵蓋輸出路徑與引用；`tools/tests/test_apply_generated_config.py` 涵蓋解析與取代（`python3 -m unittest discover -s tools/tests`）。
- `busted --lua=luajit spec` 全過。
