"""Only complete, admitted website/game payloads may replace the public release."""
import gzip
import hashlib
import json
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
            html.write_text("exported page " + " ".join(package_web.SITE_REPLACEMENTS))
            for suffix in (".js", ".wasm", ".pck"):
                html.with_suffix(suffix).write_bytes(b"exported bytes")
        return subprocess.CompletedProcess(command, 0)

    def _prepare_site(self, directory):
        directory.mkdir(parents=True, exist_ok=True)
        contents = {
            "site-app-12345678.js": b"import('./site-scene-12345678.js')",
            "site-scene-12345678.js": b"export const scene = true;",
            "site-style-12345678.css": b"body { color: white; }",
            "site-poster-12345678.webp": b"poster",
            "site-icon-12345678.svg": b"<svg></svg>",
            "help.html": b"<!doctype html><h1>Player guide</h1>",
        }
        manifest = {
            "schema_version": 1,
            "files": list(contents),
            "hashes": {name: hashlib.sha256(data).hexdigest() for name, data in contents.items()},
            "replacements": dict(zip(package_web.SITE_REPLACEMENTS, (
                "site-app-12345678.js", "site-style-12345678.css", "site-poster-12345678.webp", "site-icon-12345678.svg"))),
        }
        for name, data in contents.items():
            (directory / name).write_bytes(data)
        (directory / "site-manifest.json").write_text(json.dumps(manifest))
        return manifest, contents

    def _prepare_package(self):
        root = self.root / "checkout"
        (root / "build/templates").mkdir(parents=True)
        (root / "build/templates/web_nothreads_release.zip").write_bytes(b"template")
        self._prepare_site(root / "build/web-site")
        for name in ("docs/screenshots/arena-split.png", "THIRD_PARTY_NOTICES.md", "docs/licenses/GODOT_LICENSE.txt", "docs/licenses/GODOT_COPYRIGHT.txt", "docs/licenses/THREE_LICENSE.txt"):
            path = root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(b"fixture")
        output = root / "build/web"
        output.mkdir()
        for name, data in self.previous.items():
            (output / name).write_bytes(data)
        return root, output

    def test_complete_package_includes_verified_site_files_and_compression(self):
        root, output = self._prepare_package()
        source_files, replacements = package_web.read_site_bundle(root / "build/web-site")
        calls = []

        def run(*args, **kwargs):
            calls.append(args[0])
            return self._fake_export(*args, **kwargs)

        with patch.object(package_web, "ROOT", root), patch.object(package_web, "git", side_effect=lambda *args: "" if args[0] == "status" else "a" * 40), patch.object(package_web.subprocess, "check_output", return_value="4.7.2.stable.fixture"), patch.object(package_web.subprocess, "run", run):
            manifest = package_web.package(output)
        self.assertEqual(calls[0], ["npm", "--prefix", "web", "run", "build"])
        self.assertIn("--editor", calls[1])
        shell = (output / "index.html").read_text()
        for token, name in replacements.items():
            self.assertNotIn(token, shell)
            self.assertIn(name, shell)
        self.assertFalse((output / "site-manifest.json").exists())
        for name, data in source_files.items():
            self.assertEqual((output / name).read_bytes(), data)
            self.assertEqual(manifest["files"][name]["sha256"], hashlib.sha256(data).hexdigest())
            if Path(name).suffix in {".js", ".css", ".svg", ".html"}:
                self.assertEqual(gzip.decompress((output / (name + ".gz")).read_bytes()), data)

    def test_site_manifest_rejects_invalid_contracts(self):
        changes = {
            "schema": lambda manifest: manifest.update(schema_version=True),
            "duplicates": lambda manifest: manifest["files"].append(manifest["files"][0]),
            "traversal": lambda manifest: manifest["files"].append("../private.txt"),
            "directory": lambda manifest: manifest["files"].append("site-assets"),
            "non-string": lambda manifest: manifest["files"].append({"file": "help.html"}),
            "missing-help": lambda manifest: manifest["files"].remove("help.html"),
            "missing-hashes": lambda manifest: manifest.pop("hashes"),
            "invalid-hash": lambda manifest: manifest["hashes"].update({"help.html": "unknown"}),
            "missing-token": lambda manifest: manifest["replacements"].pop("@@SITE_STYLE@@"),
            "wrong-type": lambda manifest: manifest["replacements"].update({"@@SITE_SCRIPT@@": "help.html"}),
            "missing-target": lambda manifest: manifest["replacements"].update({"@@SITE_SCRIPT@@": "site-absent.js"}),
        }
        for label, change in changes.items():
            with self.subTest(label=label):
                directory = self.root / label
                manifest, _ = self._prepare_site(directory)
                change(manifest)
                (directory / "site-manifest.json").write_text(json.dumps(manifest))
                with self.assertRaises(ValueError):
                    package_web.read_site_bundle(directory)

    def test_site_manifest_rejects_malformed_json(self):
        for index, content in enumerate((b"{broken", b"\xff", b"null", b"[]")):
            with self.subTest(content=content):
                directory = self.root / str(index)
                self._prepare_site(directory)
                (directory / "site-manifest.json").write_bytes(content)
                with self.assertRaises(ValueError):
                    package_web.read_site_bundle(directory)

    def test_site_rejects_missing_unlisted_symlinked_and_tampered_files(self):
        for label in ("missing", "unlisted", "symlink", "manifest-symlink", "tampered"):
            with self.subTest(label=label):
                directory = self.root / label
                self._prepare_site(directory)
                help_file = directory / "help.html"
                if label == "missing":
                    help_file.unlink()
                elif label == "unlisted":
                    (directory / "private.txt").write_bytes(b"never publish")
                elif label == "symlink":
                    target = self.root / "external-help.html"
                    help_file.rename(target)
                    help_file.symlink_to(target)
                elif label == "manifest-symlink":
                    path = directory / "site-manifest.json"
                    target = self.root / "external-manifest.json"
                    path.rename(target)
                    path.symlink_to(target)
                else:
                    help_file.write_bytes(b"changed after build")
                with self.assertRaises(ValueError):
                    package_web.read_site_bundle(directory)

    def test_failed_site_build_preserves_previous_payload(self):
        root, output = self._prepare_package()
        with patch.object(package_web, "ROOT", root), patch.object(package_web, "git", side_effect=lambda *args: "" if args[0] == "status" else "a" * 40), patch.object(package_web.subprocess, "check_output", return_value="4.7.2.stable.fixture"), patch.object(package_web.subprocess, "run", side_effect=subprocess.CalledProcessError(1, "npm")), self.assertRaises(subprocess.CalledProcessError):
            package_web.package(output)
        self.assertEqual({p.name: p.read_bytes() for p in output.iterdir()}, self.previous)

    def test_tampered_site_stops_before_godot_and_preserves_previous_payload(self):
        root, output = self._prepare_package()
        (root / "build/web-site/help.html").write_bytes(b"changed after build")
        with patch.object(package_web, "ROOT", root), patch.object(package_web, "git", side_effect=lambda *args: "" if args[0] == "status" else "a" * 40), patch.object(package_web.subprocess, "check_output", return_value="4.7.2.stable.fixture"), patch.object(package_web.subprocess, "run", side_effect=self._fake_export) as run, self.assertRaisesRegex(ValueError, "hash mismatch"):
            package_web.package(output)
        self.assertEqual(run.call_count, 1)
        self.assertEqual(run.call_args.args[0], ["npm", "--prefix", "web", "run", "build"])
        self.assertEqual({p.name: p.read_bytes() for p in output.iterdir()}, self.previous)

    def test_unresolved_shell_placeholder_preserves_previous_payload(self):
        root, output = self._prepare_package()

        def export(*args, **kwargs):
            result = self._fake_export(*args, **kwargs)
            if "--export-release" in args[0]:
                path = Path(args[0][-1])
                path.write_text(path.read_text() + " @@SITE_UNKNOWN@@")
            return result

        with patch.object(package_web, "ROOT", root), patch.object(package_web, "git", side_effect=lambda *args: "" if args[0] == "status" else "a" * 40), patch.object(package_web.subprocess, "check_output", return_value="4.7.2.stable.fixture"), patch.object(package_web.subprocess, "run", export), self.assertRaisesRegex(ValueError, "unresolved"):
            package_web.package(output)
        self.assertEqual({p.name: p.read_bytes() for p in output.iterdir()}, self.previous)

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
