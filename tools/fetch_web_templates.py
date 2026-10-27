#!/usr/bin/env python3
"""Extract only the required Web templates from the official release using HTTP ranges."""
from __future__ import annotations

import argparse
import hashlib
import io
from pathlib import Path
import struct
import urllib.request
import zipfile
import zlib

VERSION = "4.7.2"
URL = f"https://github.com/godotengine/godot/releases/download/{VERSION}-stable/Godot_v{VERSION}-stable_export_templates.tpz"
MEMBERS = ("web_nothreads_release.zip", "web_nothreads_debug.zip")
SHA256 = {
    "web_nothreads_release.zip": "d3ee2f08cef0cf3cf6678a6355a92a8db48ccdd35cbd2e8bfd5f0e8a0b4032a0",
    "web_nothreads_debug.zip": "08962aefef811b603541d7951ac67ef00413aad2d978855183c28adee98f626a",
}


def fetch_range(url: str, start: int | None, end: int) -> tuple[bytes, int]:
    if start is None:
        request = urllib.request.Request(url, method="HEAD", headers={"User-Agent": "Gloamthread-template-setup"})
        with urllib.request.urlopen(request, timeout=120) as response:
            size = int(response.headers["Content-Length"])
        start, end = max(0, size - end), size - 1
    span = f"bytes={start}-{end}"
    request = urllib.request.Request(url, headers={"Range": span, "Accept-Encoding": "identity", "User-Agent": "Gloamthread-template-setup"})
    with urllib.request.urlopen(request, timeout=120) as response:
        if response.status != 206 or not response.headers.get("Content-Range", "").startswith("bytes "):
            raise ValueError("The release host must support HTTP ranges; refusing a full multi-platform download.")
        total = int(response.headers["Content-Range"].rsplit("/", 1)[1])
        limit = end if start is None else end - start + 1
        data = response.read(limit + 1)
        if len(data) > limit:
            raise ValueError("Release range exceeded its expected size.")
        return data, total


def download(output: Path) -> dict[str, str]:
    tail, total = fetch_range(URL, None, 131072)
    # ZipFile can inspect a central directory with its preceding payload omitted.
    # Restore absolute local-header offsets when fetching individual entries.
    omitted = total - len(tail)
    output.mkdir(parents=True, exist_ok=True)
    hashes = {}
    with zipfile.ZipFile(io.BytesIO(tail)) as archive:
        for name in MEMBERS:
            info = archive.getinfo("templates/" + name)
            if info.file_size > 128 * 1024 * 1024 or info.compress_size > 128 * 1024 * 1024:
                raise ValueError("Unexpectedly large Web template.")
            offset = info.header_offset + omitted
            header, _ = fetch_range(URL, offset, offset + 29)
            if header[:4] != b"PK\x03\x04":
                raise ValueError("Release ZIP local header is invalid.")
            name_length, extra_length = struct.unpack_from("<HH", header, 26)
            begin = offset + 30 + name_length + extra_length
            compressed, _ = fetch_range(URL, begin, begin + info.compress_size - 1)
            data = zlib.decompress(compressed, -15) if info.compress_type == zipfile.ZIP_DEFLATED else compressed
            if len(data) != info.file_size or zlib.crc32(data) & 0xFFFFFFFF != info.CRC:
                raise ValueError("Web template ZIP checksum failed.")
            if not zipfile.is_zipfile(io.BytesIO(data)):
                raise ValueError("Web template is not a ZIP.")
            if hashlib.sha256(data).hexdigest() != SHA256[name]:
                raise ValueError("The official 4.7.2 Web template SHA-256 does not match.")
            target = output / name
            pending = target.with_suffix(".pending")
            pending.write_bytes(data)
            pending.replace(target)
            hashes[name] = hashlib.sha256(data).hexdigest()
    return hashes


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=Path("build/templates"))
    args = parser.parse_args()
    for name, digest in download(args.output).items():
        print(f"{digest}  {name}")


if __name__ == "__main__":
    main()
