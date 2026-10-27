#!/usr/bin/env python3
"""Write ConfigCodeGenerator.dump() output from the newest CMO Lua log into constants.lua / config.lua.

In CMO run:  ConfigCodeGenerator.dump("China", config.red.ground.missileSystemTypes)
Then run:    python tools/apply_generated_config.py [--dry-run]

Log sections look like:
    @@GEN_BEGIN <name>
    ...code...
    @@GEN_END <name>
The last section of each name in the log wins.

- <name> = *_AREAS_BLOCK / *_OPERATIONAL_AREAS_BLOCK: replaces the lines between
  `-- START: <name>` and `-- END: <name>` in constants.lua.
- <name> = CONFIG_<field>: each `config.... = {` ... `}` block replaces the block with the
  same header line in config.lua (block ends at the first line that is exactly `}`).
"""

import argparse
import os
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SECTION_RE = re.compile(r"^@@GEN_BEGIN (\S+)\n(.*?)\n?^@@GEN_END \1$", re.S | re.M)
BLOCK_HEADER_RE = re.compile(r"^config\..* = \{$")

# Output style matches tools/build_lua_scenario.py: two-space indent, dim 9-wide labels, ⚠/✗ marks.
_USE_COLOR = sys.stdout.isatty() and not os.environ.get("NO_COLOR")


def _c(code: str, text: str) -> str:
    return f"\033[{code}m{text}\033[0m" if _USE_COLOR else text


def warn(msg: str) -> None:
    print(_c("33", f"  ⚠ {msg}"))


def error(msg: str) -> None:
    print(_c("31", f"  ✗ {msg}"))


def summary(label: str, value: str) -> None:
    """Aligned `label  value` summary line."""
    print(f"  {_c('2', f'{label:<9}')}{value}")


def find_latest_log(log_dir: Path | None) -> Path:
    if log_dir is None:
        cmo_dir = os.environ.get("CMO_DIR")
        if not cmo_dir:
            error("未設定 CMO_DIR，請設定環境變數或用 --log-dir 指定資料夾")
            sys.exit(1)
        log_dir = Path(cmo_dir) / "Logs"
    if log_dir.is_dir():
        logs = list(log_dir.glob("LuaHistory_*.txt"))
        if logs:
            return max(logs, key=lambda p: p.stat().st_mtime)
    error(f"在 {log_dir} 找不到 LuaHistory_*.txt，請用 --log-dir 指定資料夾")
    sys.exit(1)


def read_text(path: Path) -> str:
    return path.read_bytes().decode("utf-8", errors="replace").replace("\r\n", "\n")


def parse_sections(log_text: str) -> dict[str, str]:
    """Return the last body for each section name."""
    return {m.group(1): m.group(2) for m in SECTION_RE.finditer(log_text)}


def replace_marked(text: str, name: str, body: str) -> str | None:
    """Replace lines between START/END markers; None if markers are missing."""
    lines = text.split("\n")
    start = next((i for i, l in enumerate(lines) if l.strip() == f"-- START: {name}"), None)
    end = next((i for i, l in enumerate(lines) if l.strip() == f"-- END: {name}"), None)
    if start is None or end is None or end < start:
        return None
    new_body = body.split("\n") if body else []
    return "\n".join(lines[: start + 1] + new_body + lines[end:])


def split_blocks(code: str) -> list[tuple[str, list[str]]]:
    """Split generated config code into (header, lines) blocks."""
    blocks, cur = [], None
    for line in code.split("\n"):
        if cur is None:
            if BLOCK_HEADER_RE.match(line):
                cur = [line]
        else:
            cur.append(line)
            if line == "}":
                blocks.append((cur[0], cur))
                cur = None
    return blocks


def replace_block(text: str, header: str, new_lines: list[str]) -> str | None:
    lines = text.split("\n")
    start = next((i for i, l in enumerate(lines) if l == header), None)
    if start is None:
        return None
    end = next((i for i in range(start + 1, len(lines)) if lines[i] == "}"), None)
    if end is None:
        return None
    return "\n".join(lines[:start] + new_lines + lines[end + 1 :])


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--log", type=Path, help="指定 log 檔（預設：最新的 LuaHistory_*.txt）")
    ap.add_argument("--log-dir", type=Path, help="CMO Logs 資料夾")
    ap.add_argument("--constants", type=Path, default=ROOT / "src/core/constants.lua")
    ap.add_argument("--config", type=Path, default=ROOT / "src/core/config.lua")
    ap.add_argument("--dry-run", action="store_true", help="只顯示結果，不寫檔")
    args = ap.parse_args()

    log_path = args.log or find_latest_log(args.log_dir)
    summary("log", str(log_path))
    sections = parse_sections(read_text(log_path))
    if not sections:
        error("log 裡沒有 @@GEN_BEGIN 區段，請先在 CMO 執行 ConfigCodeGenerator.dump(...)")
        sys.exit(1)

    constants_text = read_text(args.constants)
    config_text = read_text(args.config)
    constants_orig, config_orig = constants_text, config_text
    failed = False

    for name, body in sections.items():
        if name.startswith("CONFIG_"):
            blocks = split_blocks(body)
            done = 0
            for header, new_lines in blocks:
                result = replace_block(config_text, header, new_lines)
                if result is None:
                    warn(f"config.lua 找不到區塊: {header}")
                    failed = True
                else:
                    config_text, done = result, done + 1
            summary("config", f"{name}  {done}/{len(blocks)} blocks")
        else:
            result = replace_marked(constants_text, name, body)
            if result is None:
                warn(f"constants.lua 找不到標記: -- START/END: {name}")
                failed = True
            else:
                constants_text = result
                summary("replaced", f"{name}  {len(body.splitlines())} lines")

    if args.dry_run:
        summary("dry-run", "no files written")
    else:
        if constants_text != constants_orig:
            args.constants.write_bytes(constants_text.encode("utf-8"))
            summary("wrote", args.constants.name)
        if config_text != config_orig:
            args.config.write_bytes(config_text.encode("utf-8"))
            summary("wrote", args.config.name)
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
