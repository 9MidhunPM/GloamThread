"""Web export publication failures must preserve the previous complete release."""
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

from tools import package_web


class WebPackageTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.output = self.root / "web"
        self.stage = self.root / ".staging"
        self.output.mkdir()
        self.stage.mkdir()
        self.previous = {"BUILD.json": b'{"release":"previous"}', "index.html": b"previous page", "game-1111111111111111.pck": b"previous pack"}
        for name, data in self.previous.items():
            (self.output / name).write_bytes(data)
        (self.stage / "BUILD.json").write_bytes(b'{"release":"new"}')
        (self.stage / "index.html").write_bytes(b"new page")

    def assert_previous(self):
        self.assertEqual({p.name: p.read_bytes() for p in self.output.iterdir() if p.is_file()}, self.previous)

    def test_publish_replaces_complete_directory(self):
        package_web.publish_export(self.stage, self.output)
        self.assertEqual((self.output / "BUILD.json").read_bytes(), b'{"release":"new"}')
        self.assertEqual((self.output / "index.html").read_bytes(), b"new page")
        self.assertFalse((self.output / "game-1111111111111111.pck").exists())
        self.assertFalse(self.stage.exists())
        self.assertEqual(list(self.root.glob(".web.previous-*")), [])

    def test_failed_publication_restores_previous_directory(self):
        rename = Path.rename

        def fail_stage(path, target):
            if path == self.stage:
                raise OSError("simulated full filesystem")
            return rename(path, target)

        with patch.object(Path, "rename", fail_stage), self.assertRaises(OSError):
            package_web.publish_export(self.stage, self.output)
        self.assert_previous()
        self.assertEqual((self.stage / "index.html").read_bytes(), b"new page")
        self.assertEqual(list(self.root.glob(".web.previous-*")), [])

    def test_failed_backup_preserves_previous_directory(self):
        with patch.object(Path, "rename", side_effect=OSError("simulated permission failure")), self.assertRaises(OSError):
            package_web.publish_export(self.stage, self.output)
        self.assert_previous()
        self.assertTrue(self.stage.is_dir())

    def test_unknown_directory_is_rejected_before_any_rename(self):
        (self.output / "private").mkdir()
        (self.output / "private" / "retained.txt").write_bytes(b"keep")
        with patch.object(Path, "rename") as rename, self.assertRaises(ValueError):
            package_web.publish_export(self.stage, self.output)
        rename.assert_not_called()
        self.assert_previous()
        self.assertEqual((self.output / "private" / "retained.txt").read_bytes(), b"keep")

    def test_symlink_output_is_rejected_before_any_rename(self):
        linked = self.root / "linked"
        linked.symlink_to(self.output, target_is_directory=True)
        with patch.object(Path, "rename") as rename, self.assertRaises(ValueError):
            package_web.publish_export(self.stage, linked)
        rename.assert_not_called()
        self.assert_previous()
        self.assertTrue(linked.is_symlink())

    def test_unknown_regular_file_is_preserved(self):
        extra = self.output / "private.txt"
        extra.write_bytes(b"keep")
        with self.assertRaises(ValueError):
            package_web.publish_export(self.stage, self.output)
        self.assertEqual(extra.read_bytes(), b"keep")
        self.assertEqual((self.output / "BUILD.json").read_bytes(), self.previous["BUILD.json"])

    def test_unexpected_staged_directory_is_not_published(self):
        (self.stage / "private").mkdir()
        with patch.object(Path, "rename") as rename, self.assertRaises(ValueError):
            package_web.publish_export(self.stage, self.output)
        rename.assert_not_called()
        self.assert_previous()

    def test_symlinked_existing_entry_is_not_replaced(self):
        outside = self.root / "outside"
        outside.write_bytes(b"keep")
        (self.output / "preview.png").symlink_to(outside)
        with patch.object(Path, "rename") as rename, self.assertRaises(ValueError):
            package_web.publish_export(self.stage, self.output)
        rename.assert_not_called()
        self.assertEqual(outside.read_bytes(), b"keep")
        self.assertEqual((self.output / "BUILD.json").read_bytes(), self.previous["BUILD.json"])

    def _fake_export(self, *args, **kwargs):
        command = args[0]
        if "--export-release" in command:
            html = Path(command[-1])
            html.write_text("exported page")
            for suffix in (".js", ".wasm", ".pck"):
                html.with_suffix(suffix).write_bytes(b"exported bytes")
        return subprocess.CompletedProcess(command, 0)

    def _prepare_package(self):
        root = self.root / "checkout"
        (root / "build/templates").mkdir(parents=True)
        (root / "build/templates/web_nothreads_release.zip").write_bytes(b"template")
        for name in ("docs/screenshots/arena-split.png", "THIRD_PARTY_NOTICES.md", "docs/licenses/GODOT_LICENSE.txt", "docs/licenses/GODOT_COPYRIGHT.txt"):
            path = root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(b"fixture")
        output = root / "build/web"
        output.mkdir()
        for name, data in self.previous.items():
            (output / name).write_bytes(data)
        return root, output

    def test_copy_failure_during_assembly_preserves_previous_payload(self):
        root, output = self._prepare_package()

        def fake_git(*args):
            return "" if args[0] == "status" else "a" * 40

        with patch.object(package_web, "ROOT", root), patch.object(package_web, "git", fake_git), patch.object(package_web.subprocess, "check_output", return_value="4.7.2.stable.fixture"), patch.object(package_web.subprocess, "run", self._fake_export), patch.object(package_web.shutil, "copyfile", side_effect=OSError("simulated copy failure")), self.assertRaises(OSError):
            package_web.package(output)
        self.assertEqual({p.name: p.read_bytes() for p in output.iterdir()}, self.previous)

    def test_source_change_before_publication_preserves_previous_payload(self):
        root, output = self._prepare_package()
        status_reads = 0

        def fake_git(*args):
            nonlocal status_reads
            if args[0] == "status":
                status_reads += 1
                return " M project.godot" if status_reads == 3 else ""
            return "a" * 40

        with patch.object(package_web, "ROOT", root), patch.object(package_web, "git", fake_git), patch.object(package_web.subprocess, "check_output", return_value="4.7.2.stable.fixture"), patch.object(package_web.subprocess, "run", self._fake_export), self.assertRaisesRegex(ValueError, "Source changed"):
            package_web.package(output)
        self.assertEqual({p.name: p.read_bytes() for p in output.iterdir()}, self.previous)


if __name__ == "__main__":
    unittest.main()
