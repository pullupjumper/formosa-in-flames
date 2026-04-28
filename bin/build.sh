#!/bin/bash

# 預設變數（預設都會執行）
RUN_TEST=false
SKIP_NPM=false
SKIP_LUAMIN=false
EXCLUDE_PATTERNS=()

# 1. 處理參數
while getopts "nlhtx:" opt; do
  case $opt in
    t) RUN_TEST=true ;;
    n) SKIP_NPM=true ;;
    l) SKIP_LUAMIN=true ;;
    x) EXCLUDE_PATTERNS+=("$OPTARG") ;;
    h)
      echo "用法: ./build.sh [-n] [-l] [-h] [-t] [-x pattern]"
      echo "  -t  執行測試"
      echo "  -n  跳過 npm run build (不重新打包前端)"
      echo "  -l  跳過 luamin (不壓縮 Lua 程式碼)"
      echo "  -x  排除要合併的 Lua 檔案（可重複指定，支援 glob）"
      echo "  -h  顯示此說明"
      exit 0
      ;;
    \?) echo "無效參數: -$OPTARG" >&2; exit 1 ;;
  esac
done

# 2. 定位根目錄
cd "$(dirname "$0")/.."

# 3. 執行流程
echo "--- 開始建置流程 ---"

# 步驟 0: 執行測試
if [ "$RUN_TEST" = true ]; then
    echo "🧪 執行 Lua 單元測試 (Busted)..."
    if ! busted --lua=luajit spec; then
        echo "❌ 測試未通過，停止打包流程！"
        exit 1
    fi
    echo "✅ 測試通過"
fi

# 步驟 1: NPM
if [ "$SKIP_NPM" = true ]; then
    echo "⏭️  跳過 NPM 打包步驟"
else
    echo "📦 執行 NPM 打包 (於 htmls-app 目錄)..."

    # 使用括號 ( ) 確保 cd 只在子 shell 生效，跑完會自動回到根目錄
    if ! (cd htmls-app && npm run build); then
        echo "❌ NPM 打包失敗，請檢查 htmls-app 內的程式碼。"
        exit 1
    fi

    echo "✅ NPM 打包完成"
fi

# 步驟 2: Python (這個通常是核心，不建議跳過)
echo "🐍 執行 Python 注入與合併..."
PYTHON_ARGS=()
for pattern in "${EXCLUDE_PATTERNS[@]}"; do
    PYTHON_ARGS+=(--exclude "$pattern")
done

if [ ${#EXCLUDE_PATTERNS[@]} -gt 0 ]; then
    echo "🚫 排除 pattern: ${EXCLUDE_PATTERNS[*]}"
fi

if ! python3 tools/build_lua_scenario.py "${PYTHON_ARGS[@]}"; then echo "❌ Python 失敗"; exit 1; fi

# 步驟 3: Luamin
if [ "$SKIP_LUAMIN" = true ]; then
    echo "⏭️  跳過 Luamin 壓縮"
    # 如果跳過壓縮，我們直接把原本的 main.lua 複製成 _main.lua 確保產出一致
    cp slim/main.lua slim/_main.lua
else
    echo "🗜️  執行 Luamin 壓縮..."
    if command -v luamin >/dev/null 2>&1; then
        luamin -f slim/main.lua > slim/_main.lua
        echo "✅ 壓縮完成"
    else
        echo "⚠️  找不到 luamin，直接複製檔案"
        cp slim/main.lua slim/_main.lua
    fi
fi

echo "🎉 建置成功！"
