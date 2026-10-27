"""Private, operator-run snapshots of the hosted Forge store."""
from __future__ import annotations

import argparse
from contextlib import closing
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import sqlite3
import stat
import tarfile
import tempfile
import uuid

from .store import ServiceError, Store
from .worker import exclusive_worker

ARCHIVE_NAME = re.compile(r"Gloamthread-forge-[0-9]{8}T[0-9]{6}Z-[0-9a-f]{8}\.tar\.gz")
RETAIN = 7


def regular_file(path: Path):
    if not stat.S_ISREG(path.lstat().st_mode):
        raise ServiceError("Backup refuses symlinks and non-regular files.")


def sync_directory(path: Path):
    descriptor = os.open(path, os.O_RDONLY | os.O_DIRECTORY)
    try:
        os.fsync(descriptor)
    finally:
        os.close(descriptor)


def digest(path: Path) -> str:
    result = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            result.update(block)
    return result.hexdigest()


def copy_owners(source: Path, target: Path):
    target.mkdir(mode=0o700)
    if not source.exists() and not source.is_symlink():
        return
    if not stat.S_ISDIR(source.lstat().st_mode):
        raise ServiceError("Backup refuses a symlink or non-directory owner store.")
    for folder, directories, files in os.walk(source, followlinks=False):
        folder = Path(folder)
        destination = target / folder.relative_to(source)
        for name in directories:
            path = folder / name
            if not stat.S_ISDIR(path.lstat().st_mode):
                raise ServiceError("Backup refuses symlinks and non-directory job paths.")
            (destination / name).mkdir(mode=0o700)
        for name in files:
            path = folder / name
            regular_file(path)
            # Do not follow a final-component link if an operator changes the
            # store during copying. Both authoring processes should be stopped.
            descriptor = os.open(path, os.O_RDONLY | os.O_NOFOLLOW)
            with os.fdopen(descriptor, "rb") as stream:
                if not stat.S_ISREG(os.fstat(stream.fileno()).st_mode):
                    raise ServiceError("Backup refuses a changing non-regular job file.")
                output = destination / name
                with output.open("xb") as writer:
                    shutil.copyfileobj(stream, writer)
                output.chmod(0o600)


def completed_archives(output: Path) -> list[Path]:
    archives = []
    for path in output.iterdir():
        if ARCHIVE_NAME.fullmatch(path.name):
            regular_file(path)
            archives.append(path)
    return sorted(archives, key=lambda path: (path.stat().st_mtime_ns, path.name), reverse=True)


def create_backup(data_root: Path | str, output: Path | str) -> dict:
    root = Path(data_root).absolute()
    destination = Path(output).absolute()
    if root.resolve() != root or not root.is_dir():
        raise ServiceError("Choose the existing, real Forge data directory.")
    database = root / "forge.sqlite3"
    if not database.exists():
        raise ServiceError("The existing Forge database is missing; no empty backup was created.")
    regular_file(database)
    for suffix in ("-wal", "-shm"):
        sidecar = database.with_name(database.name + suffix)
        if sidecar.exists() or sidecar.is_symlink():
            regular_file(sidecar)
    if destination.resolve() != destination or destination == root or destination.is_relative_to(root):
        raise ServiceError("Backups must use a real directory outside the live Forge data store.")
    destination.mkdir(parents=True, exist_ok=True, mode=0o700)
    if not stat.S_ISDIR(destination.lstat().st_mode):
        raise ServiceError("Choose a real backup directory.")
    completed_archives(destination)  # Validate existing archive paths before publication/retention.
    store = Store(root)
    created = datetime.now(timezone.utc)
    name = "Gloamthread-forge-" + created.strftime("%Y%m%dT%H%M%SZ") + "-" + uuid.uuid4().hex[:8] + ".tar.gz"
    published = destination / name
    if published.exists():
        raise ServiceError("Backup destination already exists; it was preserved.")
    with exclusive_worker(store):
        # The reservation blocks API database writers while the snapshot is
        # captured. Stop the API too so its pre-commit file work cannot race it.
        with store.transaction() as guarded:
            if guarded.execute("SELECT 1 FROM operations WHERE state IN ('queued','running') LIMIT 1").fetchone():
                raise ServiceError("Wait for the authoring queue to become idle before backing up. No operation was interrupted.", 409)
            with tempfile.TemporaryDirectory(prefix=".gloamthread-backup-", dir=destination) as temporary:
                staging = Path(temporary)
                payload = staging / "payload"
                payload.mkdir(mode=0o700)
                snapshot = payload / "forge.sqlite3"
                with closing(sqlite3.connect(database.as_uri() + "?mode=ro", uri=True)) as source:
                    with closing(sqlite3.connect(snapshot)) as target:
                        source.backup(target)
                        if target.execute("PRAGMA integrity_check").fetchone()[0] != "ok":
                            raise ServiceError("SQLite rejected the backup snapshot; previous archives were preserved.")
                        target.execute("PRAGMA journal_mode=DELETE")
                        target.commit()
                snapshot.chmod(0o600)
                copy_owners(root / "owners", payload / "owners")
                files = {file.relative_to(payload).as_posix(): digest(file)
                         for file in sorted(payload.rglob("*")) if file.is_file()}
                metadata = {"schema_version": 1, "created_at_utc": created.isoformat(timespec="seconds"),
                            "source_data_root": str(root), "files_sha256": files,
                            "restore": "Stop both authoring processes; restore at the same absolute FORGE_DATA_ROOT. Provider secrets are stored separately."}
                manifest = payload / "BACKUP.json"
                manifest.write_text(json.dumps(metadata, indent=2, sort_keys=True) + "\n")
                manifest.chmod(0o600)
                archive = staging / name
                with tarfile.open(archive, "w:gz", compresslevel=6) as package:
                    for file in sorted(payload.rglob("*")):
                        package.add(file, arcname=file.relative_to(payload).as_posix(), recursive=False)
                archive.chmod(0o600)
                with archive.open("rb") as stream:
                    os.fsync(stream.fileno())
                checksum = digest(archive)
                os.replace(archive, published)
                sync_directory(destination)
    # Retention touches completed backup archives only, after the new one is durable.
    archives = completed_archives(destination)
    for old in archives[RETAIN:]:
        old.unlink()
    sync_directory(destination)
    return {"ok": True, "archive": str(published), "sha256": checksum,
            "files": len(files) + 1, "retained_archives": min(len(archives), RETAIN)}


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--data-root", default=os.environ.get("FORGE_DATA_ROOT", "/data/forge"))
    parser.add_argument("--output", required=True, help="Private backup volume outside the live data store")
    args = parser.parse_args(argv)
    try:
        print(json.dumps(create_backup(args.data_root, args.output)))
        return 0
    except ServiceError as error:
        print(json.dumps({"ok": False, "error": str(error)}))
    except (OSError, sqlite3.Error, tarfile.TarError):
        print(json.dumps({"ok": False, "error": "Backup failed; source history and previous completed archives were preserved."}))
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
