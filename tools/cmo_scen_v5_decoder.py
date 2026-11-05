#!/usr/bin/env python3
"""CMO .scen (v5) decrypt / inject tool.

Usage:
  decode <scen>                      decrypt, write <scen>.decoded.xml
  inject <scen> [--lua FILE] [--out FILE] [--in-place]
                                     put the bundled main.lua back into the scen's
                                     <Description>main.lua</Description><ScriptText>…</ScriptText>
"""
import argparse
import base64
import hashlib
import os
import re
import struct
import sys
import xml.etree.ElementTree as ET
from pathlib import Path
from xml.sax.saxutils import escape

import lz4.block
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes

SALT_TEXT = 'Eg:ù2à[kÝB{ãÞ¬KîâÉ{µ\\µ¥¤4´J»ãvaWÀó±òÈV:£W-(Èª|cêI¹'
PASSWORD = 'âcI}´EjÆãoµËÛÞwÿë6ØçÌP«4lWT¶-áòêªÓb¶þ×r2Z,¬}¶üÿTYá^¦¯H%ÿºÂOð=_Û^&¬oÚýª~ÁtÂRëg{Ñ§kA«Õº½Ë¥PÊ+jbo<_ù¨xKUíTïBGÙøªçäð(tX`íÅuÉù³l(¶WØ$ëèw¬¦ÇJ|Z©*.¼ÏÒ_<·UP=W²üßå3ÂOºÃo_¤«ì8G2¶/R¬mo;>YwsÿJS}W£1ãC?ÍREÚâÙLK¬ä%¡X>ÀZÉUïdp¿o/uÕfé>ÄC©ñ)á6T~åÜ¡9>/ÚÑ«Wl£ÈÄëw{úupU®1ìU%0µõ¨'

LZ4_BLOCK_SIZE = 1024 * 1024  # 原檔觀察到的 block 大小
DEFAULT_LUA = Path(__file__).resolve().parent.parent / "slim" / "main.lua"

SCRIPT_RE = re.compile(
    rb"(<Description>main\.lua</Description>\s*<ScriptText>)(.*?)(</ScriptText>)",
    re.DOTALL,
)
COMPRESSED_RE = re.compile(rb"(<Scenario_Compressed>)(.*?)(</Scenario_Compressed>)", re.DOTALL)


# ---------------------------------------------------------------- 基礎工具
def dotnet_ascii(s):
    return s.encode("ascii", errors="replace")


def derive_key():
    return hashlib.pbkdf2_hmac("sha1", PASSWORD.encode("utf-8"), dotnet_ascii(SALT_TEXT), 1000, 32)


def read_varint(buf, pos):
    value = shift = 0
    while True:
        if pos >= len(buf):
            raise ValueError("Unexpected end of LZ4 stream")
        b = buf[pos]
        pos += 1
        value |= (b & 0x7F) << shift
        if not (b & 0x80):
            return value, pos
        shift += 7


def write_varint(value):
    out = bytearray()
    while True:
        b = value & 0x7F
        value >>= 7
        if value:
            out.append(b | 0x80)
        else:
            out.append(b)
            return bytes(out)


# ---------------------------------------------------------------- 解密
def decrypt_blob(raw):
    iv_len = struct.unpack("<i", raw[:4])[0]
    iv = raw[4:4 + iv_len]
    ciphertext = raw[4 + iv_len:]
    d = Cipher(algorithms.AES(derive_key()), modes.CBC(iv)).decryptor()
    decrypted = d.update(ciphertext) + d.finalize()
    pad = decrypted[-1]
    if not 1 <= pad <= 16 or decrypted[-pad:] != bytes([pad]) * pad:
        raise ValueError("Invalid PKCS#7 padding")
    return decrypted[:-pad]


def lz4_stream_decompress(stream):
    pos = 0
    result = bytearray()
    while pos < len(stream):
        flags, pos = read_varint(stream, pos)
        original_len, pos = read_varint(stream, pos)
        compressed_len = original_len
        if flags & 1:
            compressed_len, pos = read_varint(stream, pos)
        block = stream[pos:pos + compressed_len]
        pos += compressed_len
        if flags & 1:
            block = lz4.block.decompress(block, uncompressed_size=original_len)
        if len(block) != original_len:
            raise ValueError("LZ4 block length mismatch")
        result.extend(block)
    return bytes(result)


def decode_blob(b64_text):
    return lz4_stream_decompress(decrypt_blob(base64.b64decode(b64_text.strip())))


def decode(path):
    root = ET.parse(path).getroot()
    text = root.findtext(".//Scenario_Compressed")
    if not text:
        raise ValueError("Scenario_Compressed not found")
    return decode_blob(text)


# ---------------------------------------------------------------- 加密
def lz4_stream_compress(data):
    out = bytearray()
    for i in range(0, len(data), LZ4_BLOCK_SIZE):
        chunk = data[i:i + LZ4_BLOCK_SIZE]
        comp = lz4.block.compress(chunk, store_size=False)
        if len(comp) < len(chunk):
            out += write_varint(1) + write_varint(len(chunk)) + write_varint(len(comp)) + comp
        else:
            out += write_varint(0) + write_varint(len(chunk)) + chunk
    return bytes(out)


def encrypt_blob(stream, iv=None):
    iv = iv or os.urandom(16)
    pad = 16 - len(stream) % 16
    padded = stream + bytes([pad]) * pad
    e = Cipher(algorithms.AES(derive_key()), modes.CBC(iv)).encryptor()
    return struct.pack("<i", len(iv)) + iv + e.update(padded) + e.finalize()


def encode_blob(xml_bytes):
    return base64.b64encode(encrypt_blob(lz4_stream_compress(xml_bytes)))


# ---------------------------------------------------------------- 注入
def replace_script(xml_bytes, lua_text):
    """把 <Description>main.lua</Description><ScriptText> 的內容換成 lua_text。"""
    matches = list(SCRIPT_RE.finditer(xml_bytes))
    if len(matches) != 1:
        raise ValueError(f"expected exactly 1 main.lua ScriptText, found {len(matches)}")
    m = matches[0]
    normalized = lua_text.replace("\r\n", "\n").replace("\n", "\r\n")
    escaped = escape(normalized).encode("utf-8")
    return xml_bytes[:m.start(2)] + escaped + xml_bytes[m.end(2):]


def rewrite_scen(scen_path, transform, out_path):
    """解開 scen、用 transform(xml_bytes) 改內容、包回去寫到 out_path。transform 沒改東西就不寫。"""
    scen_bytes = Path(scen_path).read_bytes()

    outer = list(COMPRESSED_RE.finditer(scen_bytes))
    if len(outer) != 1:
        raise ValueError(f"expected exactly 1 Scenario_Compressed, found {len(outer)}")
    om = outer[0]

    xml_bytes = decode_blob(om.group(2).decode("ascii"))
    new_xml = transform(xml_bytes)
    if new_xml == xml_bytes:
        return len(xml_bytes), len(new_xml), False
    new_b64 = encode_blob(new_xml)

    # 自我驗證：解回來要和寫進去的一模一樣
    if decode_blob(new_b64.decode("ascii")) != new_xml:
        raise RuntimeError("round-trip verification failed, nothing written")

    new_scen = scen_bytes[:om.start(2)] + new_b64 + scen_bytes[om.end(2):]
    Path(out_path).write_bytes(new_scen)
    return len(xml_bytes), len(new_xml), True


def inject(scen_path, lua_path, out_path):
    lua_text = Path(lua_path).read_text(encoding="utf-8")
    old_len, new_len, _ = rewrite_scen(scen_path, lambda xml: replace_script(xml, lua_text), out_path)
    return old_len, new_len


# ---------------------------------------------------------------- CLI
def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)

    pd = sub.add_parser("decode", help="decrypt scen, write .decoded.xml")
    pd.add_argument("scen", type=Path)

    pi = sub.add_parser("inject", help="inject main.lua into scen")
    pi.add_argument("scen", type=Path)
    pi.add_argument("--lua", type=Path, default=DEFAULT_LUA, help=f"Lua file to inject (default {DEFAULT_LUA})")
    pi.add_argument("--out", type=Path, help="output path (default <scen>.injected.scen)")
    pi.add_argument("--in-place", action="store_true", help="overwrite the original, keeping a .bak copy")

    a = p.parse_args(argv)
    use_color = sys.stdout.isatty() and not os.environ.get("NO_COLOR")
    dim = (lambda t: f"\033[2m{t}\033[0m") if use_color else (lambda t: t)

    if a.cmd == "decode":
        output = a.scen.with_suffix(".decoded.xml")
        data = decode(a.scen)
        output.write_text(data.decode("utf-8-sig"), encoding="utf-8")
        print(f"  {dim('decoded  ')}{output}  ({len(data):,} bytes)")
        return

    if a.in_place:
        backup = a.scen.with_suffix(a.scen.suffix + ".bak")
        backup.write_bytes(a.scen.read_bytes())
        out = a.scen
        print(f"  {dim('backup   ')}{backup.name}")
    else:
        out = a.out or a.scen.with_suffix(".injected.scen")

    old_len, new_len = inject(a.scen, a.lua, out)
    print(f"  {dim('injected ')}{a.lua.name} → {out.name}")
    print(f"  {dim('xml      ')}{old_len:,} → {new_len:,} bytes")


if __name__ == "__main__":
    main()
