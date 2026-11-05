#!/usr/bin/env python3
"""Rename the AHA / ammunition names baked into a .scen (docs/specs/refactor-missile-system-naming.md).

Renames the arrival events, triggers and zones (AHA -> ATP) and the missile
system keys in the stored SaveData (ammunitions/ammunition/AHA ->
canisterStocks/canisterStock/ATP). The SaveData rules are global inside the
SaveData block, which is safe only while no other module saves an
`ammunition` or `AHA` key. A second run finds nothing and writes nothing.

Usage:
  rename_scen_missile_terms.py <scen> [--out FILE | --in-place]
"""
import argparse
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from cmo_scen_v5_decoder import rewrite_scen  # noqa: E402

BACKUP_SUFFIX = ".pre-rename.bak"

DESCRIPTION_RULES = {
    "arrival events and triggers": (re.compile(rb"(<Description>\((?:China|Taiwan)\) Arrive in )AHA\b"), rb"\1ATP"),
    "position zones": (re.compile(rb"(<Description>)AHA/"), rb"\1ATP/"),
}
SAVE_DATA_RE = re.compile(rb"(&lt;SaveData&gt;)(.*?)(&lt;/SaveData&gt;)", re.DOTALL)
SAVE_DATA_RULES = {
    "SaveData canisterStocks": (re.compile(rb'"ammunitions":'), rb'"canisterStocks":'),
    "SaveData canisterStock links": (re.compile(rb'"ammunition":'), rb'"canisterStock":'),
    "SaveData ATP areas": (re.compile(rb'"AHA":'), rb'"ATP":'),
}
# A scen never converted hits all of these; hitting only some means it is shaped differently
REQUIRED_TOGETHER = ("arrival events and triggers", "SaveData canisterStocks")


def rename(xml_bytes, counts):
    for name, (pattern, repl) in DESCRIPTION_RULES.items():
        xml_bytes, counts[name] = pattern.subn(repl, xml_bytes)

    blocks = list(SAVE_DATA_RE.finditer(xml_bytes))
    if len(blocks) > 1:
        raise ValueError(f"expected at most 1 SaveData, found {len(blocks)}")
    if blocks:
        match = blocks[0]
        save_data = match.group(2)
        for name, (pattern, repl) in SAVE_DATA_RULES.items():
            save_data, counts[name] = pattern.subn(repl, save_data)
        xml_bytes = xml_bytes[:match.start(2)] + save_data + xml_bytes[match.end(2):]

    if any(counts.values()) and not all(counts.get(name) for name in REQUIRED_TOGETHER):
        raise ValueError(f"partial match, nothing written: {counts}")
    return xml_bytes


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("scen", type=Path)
    parser.add_argument("--out", type=Path, help="output path (default <scen>.renamed.scen)")
    parser.add_argument("--in-place", action="store_true",
                        help=f"overwrite the original, keeping a <scen>{BACKUP_SUFFIX} copy")
    args = parser.parse_args()

    out = args.scen if args.in_place else (args.out or args.scen.with_suffix(".renamed.scen"))
    backup = args.scen.with_suffix(args.scen.suffix + BACKUP_SUFFIX)
    if args.in_place and backup.exists():
        raise SystemExit(f"{backup.name} already exists; move it away first")
    if args.in_place:
        backup.write_bytes(args.scen.read_bytes())

    counts = {}
    _, _, written = rewrite_scen(args.scen, lambda xml: rename(xml, counts), out)
    for name, count in counts.items():
        print(f"  {count:4d}  {name}")
    if not written:
        if args.in_place:
            backup.unlink()
        print("  nothing to rename, nothing written")
        return
    if args.in_place:
        print(f"  backup   {backup.name}")
    print(f"  written  {out}")


if __name__ == "__main__":
    main()
