#!/usr/bin/env python3
"""Package a clean committed Linux demo with build identity and required notices."""
from __future__ import annotations

import hashlib
import json
import re
import shutil
import subprocess
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
VERSION_MATCH = re.search(r'^config/version="([A-Za-z0-9][A-Za-z0-9.-]*)"$', (ROOT / "project.godot").read_text(), re.MULTILINE)
if VERSION_MATCH is None:
    raise SystemExit("Project version must be a safe nonempty package identifier.")
VERSION = VERSION_MATCH.group(1)
NAME = f"Gloamthread-{VERSION}-linux-x86_64"


def digest(path: Path) -> str:
    value = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            value.update(block)
    return value.hexdigest()


def main() -> None:
    for args in (["diff", "--quiet"], ["diff", "--cached", "--quiet"]):
        subprocess.run(["git", *args], cwd=ROOT, check=True)
    revision = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    binary = ROOT / "build/linux/Gloamthread.x86_64"
    binary.parent.mkdir(parents=True, exist_ok=True)
    for label, arguments in [
        ("import", ["--editor", "--import", "--quit"]),
        ("export", ["--export-release", "Linux", str(binary)]),
    ]:
        log = ROOT / "build" / ("package-" + label + ".log")
        with log.open("w") as stream:
            subprocess.run(["godot", "--headless", "--path", str(ROOT), *arguments], cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT, check=True)
        if re.search(r"\bERROR:", log.read_text()):
            raise SystemExit(f"Engine errors during {label}; inspect {log}.")
    with binary.open("rb") as stream:
        if stream.read(4) != b"\x7fELF":
            raise SystemExit("The exported Linux executable is not an ELF file.")
    output = ROOT / "build/packages"
    output.mkdir(parents=True, exist_ok=True)
    folder = output / NAME
    folder.mkdir(exist_ok=True)
    files = {
        binary: "Gloamthread.x86_64",
        ROOT / "docs/DEMO.md": "README.md",
        ROOT / "THIRD_PARTY_NOTICES.md": "THIRD_PARTY_NOTICES.md",
        ROOT / "docs/licenses/GODOT_LICENSE.txt": "docs/licenses/GODOT_LICENSE.txt",
        ROOT / "docs/licenses/GODOT_COPYRIGHT.txt": "docs/licenses/GODOT_COPYRIGHT.txt",
        ROOT / "assets/manifest.json": "ASSET_PROVENANCE.json",
    }
    for source, relative in files.items():
        target = folder / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)
    (folder / "Gloamthread.x86_64").chmod(0o755)
    build = {
        "version": VERSION,
        "status": "development build" if VERSION.endswith("-dev") else "candidate for playtesting",
        "implementation_commit": revision,
        "source": f"https://github.com/9MidhunPM/GloamThread/tree/{revision}",
        "platform": "Linux x86_64",
        "engine": "Godot 4.7.2 standard official release template",
        "executable_sha256": digest(binary),
        "known_unverified": ["physical gamepads/hotplug", "keyboard hardware rollover", "audio listening", "fresh two-human playtests", "human balance, clear time and enjoyment"],
    }
    (folder / "BUILD.json").write_text(json.dumps(build, indent=2) + "\n")
    archive = output / (NAME + ".zip")
    with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as bundle:
        # Explicit inventory prevents a previous local package file being published.
        for relative in [*files.values(), "BUILD.json"]:
            bundle.write(folder / relative, NAME + "/" + relative)
    archive_digest = digest(archive)
    (output / "SHA256SUMS").write_text(f"{archive_digest}  {archive.name}\n")
    print(json.dumps({"archive": str(archive), "sha256": archive_digest, "implementation_commit": revision}))


if __name__ == "__main__":
    main()
