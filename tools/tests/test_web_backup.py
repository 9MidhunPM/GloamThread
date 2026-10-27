"""Private SQLite/artifact backup and restore, with no external/model requests."""
from __future__ import annotations

from contextlib import redirect_stdout
import io
import hashlib
import json
from pathlib import Path
import sqlite3
import tarfile
import tempfile
import unittest
from unittest.mock import patch

from server import backup
from server.service import ForgeService
from server.store import ServiceError, Store
from server.worker import exclusive_worker
from tools.forge.hosted_accounting import SqliteAccounting
from tools.tests.test_forge_provider import png_bytes
import base64


class ForgeBackupTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.folder = Path(self.temporary.name)
        self.root = self.folder / "data"
        self.output = self.folder / "backups"
        self.store = Store(self.root)
        self.invite = self.store.create_invite("private backup fixture")
        self.owner = self.invite["owner_id"]
        self.service = ForgeService(self.store)
        self.source = png_bytes()
        self.identity = self.service.create_job(self.owner, {
            "source_png": base64.b64encode(self.source).decode(),
            "description": "A private original backup drawing.",
            "preferred_name": "Backup fixture"})["job_id"]
        self.job = self.store.require_job(self.owner, self.identity)
        self.accounting = SqliteAccounting(self.store.db_path, self.owner)
        self.accounting.reserve(self.job, "analyse", "mock-received-request")
        self.accounting.mark(self.job, "analyse", "received")

    def create(self):
        return backup.create_backup(self.root, self.output)

    def archives(self):
        return backup.completed_archives(self.output)

    def test_backup_restores_invite_job_source_and_request_history(self):
        original = self.accounting.ledger()
        result = self.create()
        path = Path(result["archive"])
        self.assertEqual(path.stat().st_mode & 0o777, 0o600)
        self.assertEqual(result["sha256"], backup.digest(path))
        with tarfile.open(path, "r:gz") as archive:
            names = archive.getnames()
            self.assertIn("forge.sqlite3", names)
            self.assertIn("owners/" + self.owner + "/jobs/" + self.identity + "/source.png", names)
            self.assertFalse(any(name.endswith(("-wal", "-shm")) for name in names))
            self.assertFalse(any(member.issym() or member.islnk() for member in archive.getmembers()))
            manifest = json.load(archive.extractfile("BACKUP.json"))
            self.assertEqual(manifest["source_data_root"], str(self.root))
            self.assertEqual(manifest["files_sha256"]["forge.sqlite3"], hashlib.sha256(archive.extractfile("forge.sqlite3").read()).hexdigest())
            # Restore to the same absolute mount path: request identities and
            # retained job source paths intentionally remain stable.
            retired = self.folder / "retired-source"
            self.root.rename(retired)
            self.root.mkdir(mode=0o700)
            archive.extractall(self.root, filter="data")
        restored = Store(self.root)
        token = restored.login(self.invite["code"], "restore-fixture")
        self.assertEqual(restored.owner_for_session(token), self.owner)
        self.assertEqual(restored.require_job(self.owner, self.identity).read_bytes(), (retired / self.job.relative_to(self.root)).read_bytes())
        self.assertEqual((restored.require_job(self.owner, self.identity).parent / "source.png").read_bytes(), self.source)
        self.assertEqual(SqliteAccounting(restored.db_path, self.owner).ledger(), original)
        self.assertEqual(ForgeService(restored).status(self.owner, self.identity)["estimated_usd"], .05)

    def test_sqlite_backup_captures_committed_wal_records_without_archiving_wal(self):
        # Keep an idle connection open so the committed row remains in live WAL.
        with self.store.connect() as keeper:
            keeper.execute("INSERT INTO reservations VALUES(?,?,?,?,?,?,?)",
                           ("fixture-wal-job", self.owner, "parts", "fixture-wal-key", 100000, "uncertain", "fixture-time"))
            self.assertTrue(self.store.db_path.with_name("forge.sqlite3-wal").is_file())
            result = self.create()
            with tarfile.open(result["archive"], "r:gz") as archive:
                self.assertFalse(any(name.endswith(("-wal", "-shm")) for name in archive.getnames()))
                restored = self.folder / "sqlite-snapshot.sqlite3"
                restored.write_bytes(archive.extractfile("forge.sqlite3").read())
            connection = sqlite3.connect(restored)
            try:
                self.assertEqual(connection.execute("SELECT state FROM reservations WHERE job_key='fixture-wal-job'").fetchone()[0], "uncertain")
                self.assertEqual(connection.execute("PRAGMA integrity_check").fetchone()[0], "ok")
            finally:
                connection.close()

    def test_secrets_and_unrelated_root_files_are_excluded(self):
        outside = self.folder / "provider.env"
        outside.write_text("OPENAI_API_KEY=fixture-outside-private")
        (self.root / "provider.env").write_text("OPENAI_API_KEY=fixture-inside-private")
        (self.root / "worker.json").write_text('{"ready":true,"key":"fixture-tampered-heartbeat"}')
        result = self.create()
        with tarfile.open(result["archive"], "r:gz") as archive:
            names = archive.getnames()
            self.assertNotIn("provider.env", names)
            self.assertNotIn("worker.json", names)
            for member in archive.getmembers():
                if member.isfile():
                    data = archive.extractfile(member).read()
                    self.assertNotIn(b"fixture-outside-private", data)
                    self.assertNotIn(b"fixture-inside-private", data)
                    self.assertNotIn(b"fixture-tampered-heartbeat", data)

    def test_active_worker_refuses_backup_without_interrupting_it(self):
        with exclusive_worker(self.store):
            with self.assertRaises(ServiceError):
                self.create()
        self.assertEqual(self.archives(), [])

    def test_pending_operations_refuse_backup_without_changing_queue(self):
        result = self.service.enqueue(self.owner, self.identity, {"command": "analyse", "idempotency_key": "pending-backup-fixture"})
        with self.assertRaises(ServiceError) as error:
            self.create()
        self.assertIn("idle", str(error.exception))
        self.assertEqual(self.store.latest_operation(self.owner, self.identity)["operation_id"], result["operation_id"])
        self.assertEqual(self.store.latest_operation(self.owner, self.identity)["state"], "queued")

    def test_failed_copy_preserves_old_completed_backup_and_source_history(self):
        old = Path(self.create()["archive"])
        previous = old.read_bytes()
        history = self.accounting.ledger()
        with patch.object(backup, "copy_owners", side_effect=OSError("fixture disk error")):
            with self.assertRaises(OSError):
                self.create()
        self.assertEqual(self.archives(), [old])
        self.assertEqual(old.read_bytes(), previous)
        self.assertEqual(self.accounting.ledger(), history)
        self.assertEqual(list(self.output.glob(".gloamthread-backup-*")), [])

    def test_symlink_in_owner_artifacts_is_refused_and_never_followed(self):
        old = Path(self.create()["archive"])
        secret = self.folder / "provider.env"
        secret.write_text("OPENAI_API_KEY=fixture-untouched")
        (self.job.parent / "linked-secret.png").symlink_to(secret)
        with self.assertRaises(ServiceError):
            self.create()
        self.assertEqual(self.archives(), [old])
        self.assertEqual(secret.read_text(), "OPENAI_API_KEY=fixture-untouched")

    def test_symlink_directories_database_and_output_are_refused(self):
        for kind in ("owner", "database", "output"):
            with self.subTest(kind=kind):
                link = self.folder / (kind + "-link")
                if kind == "owner":
                    link = self.job.parent / "linked-directory"
                    link.symlink_to(self.folder, target_is_directory=True)
                    arguments = (self.root, self.output)
                elif kind == "database":
                    original = self.store.db_path.with_suffix(".original")
                    self.store.db_path.rename(original)
                    link = self.store.db_path
                    link.symlink_to(original)
                    arguments = (self.root, self.output)
                else:
                    self.output.mkdir(exist_ok=True)
                    link.symlink_to(self.output, target_is_directory=True)
                    arguments = (self.root, link)
                try:
                    with self.assertRaises(ServiceError):
                        backup.create_backup(*arguments)
                finally:
                    link.unlink()
                    if kind == "database":
                        original.rename(self.store.db_path)

    def test_retention_keeps_seven_archives_and_never_clears_request_history(self):
        history = self.accounting.ledger()
        created = [Path(self.create()["archive"]) for _ in range(9)]
        self.assertEqual(set(self.archives()), set(created[-7:]))
        self.assertFalse(created[0].exists())
        self.assertEqual(self.accounting.ledger(), history)
        self.assertEqual(self.job.parent.joinpath("source.png").read_bytes(), self.source)

    def test_missing_database_or_nested_output_does_not_create_empty_success(self):
        missing = self.folder / "missing"
        missing.mkdir()
        with self.assertRaises(ServiceError):
            backup.create_backup(missing, self.output)
        self.assertFalse((missing / "forge.sqlite3").exists())
        with self.assertRaises(ServiceError):
            backup.create_backup(self.root, self.root / "backups")

    def test_cli_result_contains_archive_checksum_not_private_credentials(self):
        output = io.StringIO()
        with redirect_stdout(output):
            code = backup.main(["--data-root", str(self.root), "--output", str(self.output)])
        self.assertEqual(code, 0)
        result = json.loads(output.getvalue())
        self.assertTrue(result["ok"])
        self.assertTrue(Path(result["archive"]).is_file())
        self.assertNotIn(self.invite["code"], output.getvalue())
        self.assertNotIn("private backup fixture", output.getvalue())


if __name__ == "__main__":
    unittest.main()
