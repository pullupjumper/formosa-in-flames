#!/bin/bash

# 預設變數（預設都會執行）
RUN_TEST=false
SKIP_NPM=false
SKIP_LUAMIN=false
SKIP_INJECT=false
PLAY_MODE=false
VERBOSE=false
EXCLUDE_PATTERNS=()
SCEN_PATH="/mnt/c/Program Files (x86)/Steam/steamapps/common/Command - Modern Operations/Scenarios/Formosa in Flames, 2027 (v0.32) (db v516).scen"

# 1. 處理參數
while getopts "nlhtipvx:s:" opt; do
  case $opt in
    t) RUN_TEST=true ;;
    n) SKIP_NPM=true ;;
    l) SKIP_LUAMIN=true ;;
    i) SKIP_INJECT=true ;;
    p) PLAY_MODE=true ;;
    v) VERBOSE=true ;;
    x) EXCLUDE_PATTERNS+=("$OPTARG") ;;
    s) SCEN_PATH="$OPTARG" ;;
    h)
      echo "Usage: ./build.sh [-t] [-n] [-l] [-i] [-p] [-v] [-x pattern] [-s scen_path] [-h]"
      echo "  -t  run tests (Lua busted + frontend vitest)"
      echo "  -n  skip npm run build (do not rebuild frontend)"
      echo "  -l  skip luamin (do not minify Lua)"
      echo "  -i  skip injecting into the scen file"
      echo "  -p  play build: config.isEditMode=false (default is edit mode)"
      echo "  -v  verbose: print per-file details"
      echo "  -x  exclude Lua files from merge (repeatable, glob supported)"
      echo "  -s  scen file to inject into; overwritten in place, .bak kept (default: $SCEN_PATH)"
      echo "  -h  show this help"
      exit 0
      ;;
    \?) echo "Invalid option: -$OPTARG" >&2; exit 1 ;;
  esac
done

# 2. 定位根目錄
cd "$(dirname "$0")/.."

# 3. 輸出小工具（stdout 非 TTY 或 NO_COLOR 時關閉顏色）
if [ -t 1 ] && [ -z "$NO_COLOR" ]; then
    C_BOLD=$'\e[1m'; C_DIM=$'\e[2m'; C_CYAN=$'\e[36m'; C_GREEN=$'\e[32m'
    C_YELLOW=$'\e[33m'; C_RED=$'\e[31m'; C_RESET=$'\e[0m'
else
    C_BOLD=""; C_DIM=""; C_CYAN=""; C_GREEN=""; C_YELLOW=""; C_RED=""; C_RESET=""
fi
export NO_COLOR  # 讓 Python 腳本跟 shell 一致

TOTAL=5
stage() { echo; echo "${C_BOLD}${C_CYAN}▶ [$1/$TOTAL] $2${C_RESET}"; }
skip()  { echo "  ${C_DIM}⏭ skipped${C_RESET}"; }
ok()    { echo "  ${C_GREEN}✓${C_RESET} $1"; }
fail()  { echo "  ${C_RED}✗ $1${C_RESET}"; exit 1; }
warn()  { echo "  ${C_YELLOW}⚠ $1${C_RESET}"; }

# 4. 執行流程
START=$(date +%s)

# 階段 1: 測試
stage 1 "Tests"
if [ "$RUN_TEST" = true ]; then
    busted --lua=luajit spec || fail "Lua tests failed"
    ok "Lua (busted)"
    (cd htmls-app && npm test --silent) || fail "Frontend tests failed"
    ok "Frontend (vitest)"
else
    skip
fi

# 階段 2: NPM 打包
stage 2 "NPM build (htmls-app)"
if [ "$SKIP_NPM" = true ]; then
    skip
else
    if [ "$VERBOSE" = true ]; then
        (cd htmls-app && npm run build) || fail "NPM build failed, check htmls-app"
    else
        NPM_LOG=$(cd htmls-app && npm run build --silent 2>&1) || { echo "$NPM_LOG"; fail "NPM build failed, check htmls-app"; }
        echo "$NPM_LOG" | grep -E "built in|dist/.*\.html" | sed "s/^/  ${C_DIM}/; s/\$/${C_RESET}/"
    fi
    ok "done"
fi

# 階段 3: Lua 清理 + 合併
stage 3 "Lua clean + merge (src → slim/main.lua)"
PYTHON_ARGS=()
for pattern in "${EXCLUDE_PATTERNS[@]}"; do
    PYTHON_ARGS+=(--exclude "$pattern")
done
[ "$VERBOSE" = true ] && PYTHON_ARGS+=(--verbose)

python3 tools/build_lua_scenario.py "${PYTHON_ARGS[@]}" || fail "Lua merge failed"

if [ "$PLAY_MODE" = true ]; then
    sed -i 's/^config\.isEditMode = true$/config.isEditMode = false/' slim/main.lua
    grep -q '^config\.isEditMode = false$' slim/main.lua || fail "isEditMode override not applied"
    ok "play build (isEditMode=false)"
else
    ok "edit build (isEditMode=true)"
fi

# 階段 4: Luamin
stage 4 "Luamin minify (slim/_main.lua)"
if [ "$SKIP_LUAMIN" = true ]; then
    skip
    cp slim/main.lua slim/_main.lua
elif ! command -v luamin >/dev/null 2>&1; then
    warn "luamin not found, copying unminified file"
    cp slim/main.lua slim/_main.lua
# 用管線餵入內容：luamin 的 -f 模式在 stdin 非 TTY 時（CI、編輯器 task）會誤判參數而失敗
elif cat slim/main.lua | luamin -c > slim/_main.lua 2>/dev/null; then
    ok "$(python3 -c "import os;print(f'{os.path.getsize(\"slim/main.lua\"):,} → {os.path.getsize(\"slim/_main.lua\"):,} bytes')")"
else
    warn "luamin failed, falling back to unminified file"
    cp slim/main.lua slim/_main.lua
fi

# 階段 5: 注入 scen
stage 5 "Inject into scen"
if [ "$SKIP_INJECT" = true ]; then
    skip
elif [ ! -f "$SCEN_PATH" ]; then
    fail "scen file not found: $SCEN_PATH"
else
    echo "  ${C_DIM}target   ${C_RESET}$(basename "$SCEN_PATH")"
    python3 tools/cmo_scen_v5_decoder.py inject "$SCEN_PATH" --in-place || fail "scen injection failed"
fi

echo
echo "${C_BOLD}${C_GREEN}🎉 Build complete${C_RESET}  ${C_DIM}($(( $(date +%s) - START ))s)${C_RESET}"
