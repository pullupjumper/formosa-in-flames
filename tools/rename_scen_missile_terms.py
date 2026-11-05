#!/usr/bin/env python3
"""Rename the AHA / ammunition names baked into a .scen (docs/specs/refactor-missile-system-naming.md).

Renames the arrival events, triggers and zones (AHA -> ATP) and the missile
system keys in the stored SaveData (ammunitions/ammunition/AHA ->
canisterStocks/canisterStock/ATP). A second run finds nothing and writes nothing.

Usage:
  rename_scen_missile_terms.py <scen> [--out FILE | --in-place]
"""
import argparse
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from cmo_scen_v5_decoder import COMPRESSED_RE, decode_blob, encode_blob  # noqa: E402

DESCRIPTION_RULES = [
    (re.compile(rb"(<Description>\((?:China|Taiwan)\) Arrive in )AHA\b"), rb"\1ATP"),
    (re.compile(rb"(<Description>)AHA/"), rb"\1ATP/"),
]
SAVE_DATA_RE = re.compile(rb"(&lt;SaveData&gt;)(.*?)(&lt;/SaveData&gt;)", re.DOTALL)
SAVE_DATA_RULES = [
    (re.compile(rb'"ammunitions":'), rb'"canisterStocks":'),
    (re.compile(rb'"ammunition":'), rb'"canisterStock":'),
    (re.compile(rb'"AHA":'), rb'"ATP":'),
]


def rename(xml_bytes):
    counts = {}
    for pattern, repl in DESCRIPTION_RULES:
        xml_bytes, counts[pattern.pattern.decode()] = pattern.subn(repl, xml_bytes)

    blocks = list(SAVE_DATA_RE.finditer(xml_bytes))
    if len(blocks) > 1:
        raise ValueError(f"expected at most 1 SaveData, found {len(blocks)}")
    if blocks:
        m = blocks[0]
        save_data = m.group(2)
        for pattern, repl in SAVE_DATA_RULES:
            save_data, counts[pattern.pattern.decode()] = pattern.subn(repl, save_data)
        xml_bytes = xml_bytes[:m.start(2)] + save_data + xml_bytes[m.end(2):]
    return xml_bytes, counts


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("scen", type=Path)
    p.add_argument("--out", type=Path, help="output path (default <scen>.renamed.scen)")
    p.add_argument("--in-place", action="store_true", help="overwrite the original, keeping a .bak copy")
    a = p.parse_args()

    scen_bytes = a.scen.read_bytes()
    outer = list(COMPRESSED_RE.finditer(scen_bytes))
    if len(outer) != 1:
        raise ValueError(f"expected exactly 1 Scenario_Compressed, found {len(outer)}")
    om = outer[0]

    xml_bytes = decode_blob(om.group(2).decode("ascii"))
    new_xml, counts = rename(xml_bytes)
    for rule, count in counts.items():
        print(f"  {count:4d}  {rule}")
    if new_xml == xml_bytes:
        print("  nothing to rename, nothing written")
        return

    new_b64 = encode_blob(new_xml)
    if decode_blob(new_b64.decode("ascii")) != new_xml:
        raise RuntimeError("round-trip verification failed, nothing written")

    if a.in_place:
        backup = a.scen.with_suffix(a.scen.suffix + ".bak")
        backup.write_bytes(scen_bytes)
        out = a.scen
        print(f"  backup   {backup.name}")
    else:
        out = a.out or a.scen.with_suffix(".renamed.scen")
    out.write_bytes(scen_bytes[:om.start(2)] + new_b64 + scen_bytes[om.end(2):])
    print(f"  written  {out}")


if __name__ == "__main__":
    main()
