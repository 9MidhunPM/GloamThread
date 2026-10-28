#!/usr/bin/env python3
"""Export a reproducible public browser payload, without the authoring service or secrets."""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import gzip
import hashlib
import html
import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import uuid

ROOT = Path(__file__).resolve().parents[1]
SITE_ASSET = re.compile(r"site-[A-Za-z0-9_-]+\.(?:js|css|png|webp|svg|woff2)")
SITE_REPLACEMENTS = {
    "@@SITE_SCRIPT@@": {".js"},
    "@@SITE_STYLE@@": {".css"},
    "@@SITE_POSTER@@": {".png", ".webp"},
    "@@SITE_FAVICON@@": {".png", ".svg"},
}


def git(*args: str) -> str:
    return subprocess.check_output(["git", *args], cwd=ROOT, text=True).strip()


def _validate_output(output: Path) -> None:
    if output.is_symlink():
        raise ValueError("Web output must not be a symbolic link.")
    if not output.exists():
        return
    if not output.is_dir():
        raise ValueError("Web output must be a directory.")
    for path in output.iterdir():
        name = path.name.removesuffix(".gz")
        known = name in {"BUILD.json", "index.html", "preview.png", "notices.html", "help.html"}
        known = known or SITE_ASSET.fullmatch(name) is not None
        known = known or re.fullmatch(r"(?:index|game-[0-9a-f]{16})\.(?:js|wasm|pck|png|audio\.worklet\.js|audio\.position\.worklet\.js)", name) is not None
        if path.is_symlink() or not path.is_file() or not known:
            raise ValueError("Web output contains an unexpected entry; previous payload was preserved: " + path.name)


def read_site_bundle(directory: Path) -> tuple[dict[str, bytes], dict[str, str]]:
    """Admit a complete, flat website bundle before touching the public release."""
    manifest_path = directory / "site-manifest.json"
    if directory.is_symlink() or not directory.is_dir() or manifest_path.is_symlink() or not manifest_path.is_file():
        raise ValueError("Website build must contain a regular site-manifest.json.")
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (UnicodeError, json.JSONDecodeError) as error:
        raise ValueError("Website build manifest is invalid JSON.") from error
    if not isinstance(manifest, dict) or type(manifest.get("schema_version")) is not int or manifest["schema_version"] != 1:
        raise ValueError("Unsupported website build manifest.")
    names = manifest.get("files")
    if (not isinstance(names, list) or not names or any(not isinstance(name, str) for name in names)
            or len(set(names)) != len(names) or "help.html" not in names
            or any(name != "help.html" and SITE_ASSET.fullmatch(name) is None for name in names)):
        raise ValueError("Website build inventory must list unique public website files, including help.html.")
    hashes = manifest.get("hashes")
    if not isinstance(hashes, dict) or set(hashes) != set(names):
        raise ValueError("Website build must record a SHA-256 hash for every public file.")
    replacements = manifest.get("replacements")
    if not isinstance(replacements, dict) or set(replacements) != set(SITE_REPLACEMENTS):
        raise ValueError("Website build must provide the required shell replacements.")
    for token, suffixes in SITE_REPLACEMENTS.items():
        name = replacements[token]
        if not isinstance(name, str) or name not in names or Path(name).suffix not in suffixes:
            raise ValueError("Website build has an invalid shell replacement: " + token)
    if {path.name for path in directory.iterdir()} != set(names) | {manifest_path.name}:
        raise ValueError("Website build contains unlisted or missing files.")
    files = {}
    for name in names:
        path = directory / name
        if path.is_symlink() or not path.is_file():
            raise ValueError("Website build entries must be regular files: " + name)
        expected = hashes[name]
        if not isinstance(expected, str) or re.fullmatch(r"[0-9a-f]{64}", expected) is None:
            raise ValueError("Website build has an invalid SHA-256 hash: " + name)
        data = path.read_bytes()
        if hashlib.sha256(data).hexdigest() != expected:
            raise ValueError("Website build hash mismatch: " + name)
        # Keep the verified bytes; a concurrent rebuild cannot swap files during export.
        files[name] = data
    return files, replacements


def publish_export(stage: Path, output: Path) -> None:
    """Publish a complete sibling export, restoring the previous tree on failure."""
    _validate_output(output)
    if stage.is_symlink() or not stage.is_dir() or stage.parent != output.parent or stage == output:
        raise ValueError("Web staging must be a real sibling directory.")
    _validate_output(stage)
    backup = output.with_name("." + output.name + ".previous-" + uuid.uuid4().hex)
    previous = output.exists()
    if previous:
        output.rename(backup)
    try:
        stage.rename(output)
    except OSError as error:
        if previous:
            try:
                backup.rename(output)
            except OSError:
                raise OSError("Web publication failed; the previous complete payload remains at " + str(backup)) from error
        raise
    # Cleanup cannot turn an already-published, complete release into a failure.
    if previous:
        shutil.rmtree(backup, ignore_errors=True)


def package(output: Path, allow_dirty: bool = False) -> dict:
    dirty = bool(git("status", "--porcelain=v1", "--untracked-files=all", "--", ".", ":(exclude)build"))
    if dirty and not allow_dirty:
        raise ValueError("Web release packaging requires a clean committed checkout. Use --allow-dirty for local QA only.")
    revision = git("rev-parse", "HEAD")
    tree = git("rev-parse", "HEAD^{tree}")
    source_status = git("status", "--porcelain=v1", "--untracked-files=all", "--", ".", ":(exclude)build")
    engine = subprocess.check_output(["godot", "--version"], text=True).strip()
    if not engine.startswith("4.7.2.stable."):
        raise ValueError("The Web release requires Godot 4.7.2 standard.")
    if not (ROOT / "build/templates/web_nothreads_release.zip").is_file():
        raise ValueError("Run python3 tools/fetch_web_templates.py first.")
    # Existing exported PNGs must not become editor-imported source resources
    # on later builds, adding .import files to an otherwise exact public payload.
    (ROOT / "build/.gdignore").touch(exist_ok=True)
    _validate_output(output)
    output = output.resolve()
    if not output.is_relative_to((ROOT / "build").resolve()):
        raise ValueError("Web output must be below the ignored build directory.")
    output.parent.mkdir(parents=True, exist_ok=True)
    with (ROOT / "build/web-site.log").open("w") as stream:
        subprocess.run(["npm", "--prefix", "web", "run", "build"], cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT, check=True)
    site_files, replacements = read_site_bundle(ROOT / "build/web-site")
    with tempfile.TemporaryDirectory(prefix=".web-export-", dir=output.parent) as folder:
        stage = Path(folder)
        basename = "game-" + revision[:16]
        for label, args in (("import", ["--editor", "--import", "--quit"]), ("export", ["--export-release", "Web", str(stage / (basename + ".html"))])):
            log = ROOT / "build" / f"web-{label}.log"
            with log.open("w") as stream:
                subprocess.run(["godot", "--headless", "--path", str(ROOT), *args], cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT, check=True)
            if re.search(r"(?:SCRIPT )?ERROR:", log.read_text(errors="replace")):
                raise ValueError(f"Godot reported errors; see {log}.")
        (stage / (basename + ".html")).rename(stage / "index.html")
        shell = (stage / "index.html").read_text(encoding="utf-8")
        for token, name in replacements.items():
            if token not in shell:
                raise ValueError("Exported shell is missing website replacement: " + token)
            shell = shell.replace(token, name)
        if re.search(r"@@SITE_[A-Z_]+@@", shell):
            raise ValueError("Exported shell contains an unresolved website replacement.")
        (stage / "index.html").write_text(shell, encoding="utf-8")
        for name, data in site_files.items():
            (stage / name).write_bytes(data)
        shutil.copyfile(ROOT / "docs/screenshots/arena-split.png", stage / "preview.png")
        notices = [("Project notices", "THIRD_PARTY_NOTICES.md"), ("Godot license", "docs/licenses/GODOT_LICENSE.txt"), ("Godot third-party notices", "docs/licenses/GODOT_COPYRIGHT.txt"), ("Three.js license", "docs/licenses/THREE_LICENSE.txt")]
        sections = "".join(f"<h2>{html.escape(title)}</h2><pre>{html.escape((ROOT / path).read_text())}</pre>" for title, path in notices)
        (stage / "notices.html").write_text('<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>Gloamthread licenses</title><style>body{max-width:80ch;margin:40px auto;padding:20px;background:#101a24;color:#eee9d9;font:14px/1.6 monospace}pre{white-space:pre-wrap}a{color:#85d9e7}</style><a href="/">Back to Gloamthread</a><h1>Licenses and notices</h1>' + sections + "</html>")
        allowed = {"index.html", "preview.png", "notices.html", *site_files, *(basename + suffix for suffix in (".js", ".wasm", ".pck", ".png", ".audio.worklet.js", ".audio.position.worklet.js"))}
        _validate_output(stage)
        files = {p.name: p for p in stage.iterdir() if p.is_file()}
        if set(files) - allowed or not {"index.html", basename + ".js", basename + ".wasm", basename + ".pck"} <= files.keys():
            raise ValueError("Unexpected or missing files in public Web export: " + str(sorted(files)))
        manifest = {"schema_version": 1, "implementation_commit": revision, "source_tree": tree, "dirty_qa_build": dirty, "engine": engine, "export_preset": "Web", "built_at_utc": datetime.now(timezone.utc).isoformat(timespec="seconds"), "files": {name: {"bytes": path.stat().st_size, "sha256": hashlib.sha256(path.read_bytes()).hexdigest()} for name, path in files.items()}}
        (stage / "BUILD.json").write_text(json.dumps(manifest, indent=2) + "\n")
        for name, path in files.items():
            if path.suffix in {".js", ".css", ".svg", ".wasm", ".pck", ".html"}:
                with (stage / (name + ".gz")).open("wb") as stream:
                    with gzip.GzipFile(filename="", mode="wb", fileobj=stream, mtime=0, compresslevel=9) as zipped:
                        zipped.write(path.read_bytes())
        # Export into a fresh staging tree, then publish only its explicit inventory.
        if (git("rev-parse", "HEAD") != revision or git("rev-parse", "HEAD^{tree}") != tree
                or git("status", "--porcelain=v1", "--untracked-files=all", "--", ".", ":(exclude)build") != source_status):
            raise ValueError("Source changed during Web export; the previous payload was preserved.")
        publish_export(stage, output)
    return manifest


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT / "build/web")
    parser.add_argument("--allow-dirty", action="store_true", help="Local QA only; record dirty_qa_build=true")
    args = parser.parse_args()
    print(json.dumps(package(args.output, args.allow_dirty), indent=2))


if __name__ == "__main__":
    main()
