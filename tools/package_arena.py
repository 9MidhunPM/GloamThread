#!/usr/bin/env python3
"""Export a clean committed arena build and its explicit optional authoring kit."""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]
AUTHORING_FILES = (
    "tools/fighter_forge.py", "tools/ai_assets.py", "tools/forge/__init__.py",
    "tools/forge/provider.py", "tools/forge/jobs.py", "tools/forge/validation.py",
    "tools/forge/rigs.py", "tools/forge/art.py", "requirements-authoring.txt", ".env.example",
)
DOCUMENT_FILES = {
    "docs/ARENA_DEMO.md": "README.md",
    "tools/setup_authoring.sh": "setup_authoring.sh",
    "THIRD_PARTY_NOTICES.md": "THIRD_PARTY_NOTICES.md",
    "docs/licenses/GODOT_LICENSE.txt": "docs/licenses/GODOT_LICENSE.txt",
    "docs/licenses/GODOT_COPYRIGHT.txt": "docs/licenses/GODOT_COPYRIGHT.txt",
    "assets/manifest.json": "provenance/campaign_assets.json",
    "content/arena/catalog.json": "provenance/arena_catalog.json",
    "assets/arena/builtin/index.json": "provenance/builtin_index.json",
    "assets/arena/enemies/index.json": "provenance/enemy_index.json",
    "assets/arena/audio/index.json": "provenance/audio_index.json",
}


def digest(path: Path) -> str:
    value = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            value.update(block)
    return value.hexdigest()


def git(root: Path, *args: str) -> str:
    return subprocess.check_output(["git", *args], cwd=root, text=True).strip()


def clean_revision(root: Path) -> tuple[str, str]:
    # Include untracked source, not only git diff. Ignored build/cache/secret
    # files never enter the explicit package inventory below.
    dirty = git(root, "status", "--porcelain=v1", "--untracked-files=all", "--", ".", ":(exclude)build")
    if dirty:
        raise ValueError("Packaging requires committed tracked and untracked source outside build/.\n" + dirty)
    return git(root, "rev-parse", "HEAD"), git(root, "rev-parse", "HEAD^{tree}")


def project_version(root: Path) -> str:
    match = re.search(r'^config/version="([0-9A-Za-z][0-9A-Za-z.-]{0,63})"\s*$',
                      (root / "project.godot").read_text(encoding="utf-8"), re.MULTILINE)
    if match is None:
        raise ValueError("project.godot needs a safe config/version before packaging.")
    return match.group(1)


def package_inventory(root: Path) -> dict[str, Path]:
    files = {destination: root / source for source, destination in DOCUMENT_FILES.items()}
    files.update({"authoring/" + source: root / source for source in AUTHORING_FILES})
    index = json.loads((root / "assets/arena/builtin/index.json").read_text(encoding="utf-8"))
    if index.get("schema_version") != 1 or not isinstance(index.get("bundles"), list) or not index["bundles"]:
        raise ValueError("Built-in bundle index is invalid.")
    seen: set[str] = set()
    for name in index["bundles"]:
        if not isinstance(name, str) or not re.fullmatch(r"[a-z0-9][a-z0-9_-]{0,63}", name) or name in seen:
            raise ValueError("Built-in bundle index contains an unsafe or duplicate name.")
        seen.add(name)
        for filename in ("manifest.json", "provenance.json"):
            files[f"provenance/fighters/{name}/{filename}"] = root / "assets/arena/builtin" / name / filename
    for destination, source in files.items():
        if not source.is_file() or source.is_symlink() or not source.resolve().is_relative_to(root.resolve()):
            raise ValueError(f"Required regular package source is missing: {destination}")
    # A copied credential template is useful; a populated template is not safe.
    for line in (root / ".env.example").read_text(encoding="utf-8").splitlines():
        match = re.match(r"\s*(?:export\s+)?OPENAI_API_KEY\s*=\s*(.*?)\s*$", line)
        if match and match.group(1) not in ("", "''", '""'):
            raise ValueError(".env.example must have an empty OPENAI_API_KEY.")
    return files


def run_engine(root: Path, label: str, arguments: list[str]) -> None:
    log = root / "build" / f"arena-package-{label}.log"
    log.parent.mkdir(parents=True, exist_ok=True)
    with log.open("w", encoding="utf-8") as stream:
        subprocess.run(["godot", "--headless", "--path", str(root), *arguments], cwd=root,
                       stdout=stream, stderr=subprocess.STDOUT, check=True)
    if re.search(r"(?:SCRIPT )?ERROR:", log.read_text(encoding="utf-8", errors="replace")):
        raise ValueError(f"Engine errors during {label}; inspect {log}.")


def write_archive(root: Path, binary: Path, revision: str, tree: str, engine: str,
                  inventory: dict[str, Path], output: Path, *, check_committed: bool = True) -> dict:
    with binary.open("rb") as stream:
        header = stream.read(20)
    if len(header) < 20 or header[:6] != b"\x7fELF\x02\x01" or int.from_bytes(header[18:20], "little") != 62:
        raise ValueError("Export is not a little-endian Linux x86_64 ELF executable.")
    version = project_version(root)
    name = f"Gloamthread-{version}-linux-x86_64"
    output.mkdir(parents=True, exist_ok=True)
    archive = output / (name + ".zip")
    # A new staging directory and exact zip inventory prevent stale files,
    # previous keys or local job caches entering a later release.
    with tempfile.TemporaryDirectory(prefix=".arena-package-", dir=output) as staging:
        folder = Path(staging) / name
        folder.mkdir()
        payload = {"Gloamthread.x86_64": binary, **inventory}
        hashes: dict[str, str] = {}
        for relative, source in sorted(payload.items()):
            target = folder / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, target)
            target.chmod(0o755 if relative in {"Gloamthread.x86_64", "setup_authoring.sh"} else 0o644)
            hashes[relative] = digest(target)
        build = {
            "schema_version": 1, "version": version, "status": "arena playtest candidate",
            "built_at_utc": datetime.now(timezone.utc).isoformat(timespec="seconds"),
            "implementation_commit": revision, "source_tree": tree,
            "source": f"https://github.com/9MidhunPM/GloamThread/tree/{revision}",
            "platform": "Linux x86_64", "engine": engine, "export_preset": "Linux",
            "executable_sha256": hashes["Gloamthread.x86_64"], "files_sha256": hashes,
            "authoring": {"optional": True, "root": "authoring", "credentials_included": False,
                          "runtime_requires_python": False},
            "known_unverified": ["physical gamepads and keyboard rollover", "fresh-human balance and clear time",
                                 "hardware performance beyond the recorded machine", "generation quality beyond the reviewed live character/theme pair"],
        }
        (folder / "BUILD.json").write_text(json.dumps(build, indent=2) + "\n", encoding="utf-8")
        pending = Path(staging) / archive.name
        with zipfile.ZipFile(pending, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as bundle:
            for relative in [*sorted(payload), "BUILD.json"]:
                bundle.write(folder / relative, name + "/" + relative)
        if check_committed and clean_revision(root) != (revision, tree):
            raise ValueError("Source changed while assembling the archive; the previous package was preserved.")
        pending.replace(archive)
    archive_digest = digest(archive)
    checksum = output / (archive.name + ".sha256")
    checksum.write_text(f"{archive_digest}  {archive.name}\n", encoding="utf-8")
    return {"archive": str(archive), "sha256": archive_digest, "checksum": str(checksum),
            "implementation_commit": revision, "version": version, "files": len(inventory) + 2}


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dry-run", action="store_true", help="Check committed source and show the package inventory without exporting")
    args = parser.parse_args(argv)
    try:
        revision, tree = clean_revision(ROOT)
        inventory = package_inventory(ROOT)
        git(ROOT, "ls-files", "--error-unmatch", "--", "project.godot", "export_presets.cfg",
            *(str(source.relative_to(ROOT)) for source in inventory.values()))
        version = project_version(ROOT)
        if args.dry_run:
            print(json.dumps({"version": version, "implementation_commit": revision,
                              "files": ["Gloamthread.x86_64", *sorted(inventory), "BUILD.json"]}, indent=2))
            return 0
        engine = subprocess.check_output(["godot", "--version"], cwd=ROOT, text=True).strip()
        if not engine.startswith("4.7.2.") or "mono" in engine.lower():
            raise ValueError("This release requires Godot 4.7.2 standard and its matching Linux export template.")
        binary = ROOT / "build/linux-arena/Gloamthread.x86_64"
        binary.parent.mkdir(parents=True, exist_ok=True)
        run_engine(ROOT, "import", ["--editor", "--import", "--quit"])
        run_engine(ROOT, "export", ["--export-release", "Linux", str(binary)])
        if clean_revision(ROOT) != (revision, tree):
            raise ValueError("Source changed during export; no archive was published.")
        # Revalidate source inventory after import/export before copying any file.
        inventory = package_inventory(ROOT)
        result = write_archive(ROOT, binary, revision, tree, engine, inventory, ROOT / "build/packages")
        print(json.dumps(result))
        return 0
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        print(f"Arena packaging failed: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
