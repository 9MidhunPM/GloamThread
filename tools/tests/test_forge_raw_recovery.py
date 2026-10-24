"""Local recovery of retained, hash-verified mock image output.

These fixtures never load a key, SDK, real job or external budget ledger. Mock
generation creates the same durable raw artifacts as a failed local conversion.
"""
from __future__ import annotations

import json
import hashlib
from pathlib import Path
import shutil
import unittest
from unittest.mock import Mock, patch

from PIL import Image

from tools.forge import jobs
from tools.forge.art import authored_parts, make_rig
from tools.forge.jobs import ForgeError, run_job
from tools.forge.validation import BundleError, validate_bundle
import tools.tests.test_forge_provider as fixtures
import tools.tests.test_forge_content as content_fixtures


LAYOUT = {"schema_version": 1, "fixture": "mock converter layout", "columns": 3, "rows": 3}
REASON = "Generated head is blank; correct its source cell before rebaking."


class RawForgeRecoveryTests(unittest.TestCase):
    def setUp(self):
        # Compose the fixture without inheriting/rerunning its provider test cases.
        self.fx = fixtures.ForgeProviderTests()
        self.fx.setUp()
        self.addCleanup(self.fx.doCleanups)
        self.folder = self.fx.job_dir
        self.layout = self.folder / "source_layout.json"
        self.expected_layout = None
        self.converter = Mock(side_effect=self.convert)

    def seed_failed_conversion(self):
        self.fx.approve()
        self.fx.converter.side_effect = BundleError(REASON)
        with self.assertRaises(ForgeError):
            self.fx.invoke("generate")
        self.assertFalse((self.folder / "candidate").exists())
        self.assertFalse((self.folder / "rig.json").exists())
        self.assertTrue((self.folder / "raw/parts.png").is_file())
        self.assertTrue((self.folder / "raw/theme.png").is_file())
        self.budget = self.fx.root / "build/forge/budget.json"
        self.budget_before = self.budget.read_bytes()
        self.fx.provider.reset_mock()
        # Keep the old baker seam successful: negative recovery tests must fail
        # if implementation incorrectly takes that route instead of validating.

    def invoke_local(self, **kwargs):
        options = {"root": self.fx.root, "provider": self.fx.provider,
                   "converter": self.converter, "baker": self.fx.baker, "config": None}
        options.update(kwargs)
        with patch.object(jobs, "settings", side_effect=AssertionError("No provider settings may be read")):
            with patch.object(jobs, "OpenAIProvider", side_effect=AssertionError("No SDK may be constructed")):
                return run_job("bake", self.fx.job_path, **options)

    def assert_no_rebill(self):
        self.fx.provider.analyse.assert_not_called()
        self.fx.provider.image.assert_not_called()
        self.assertEqual(self.budget.read_bytes(), self.budget_before)

    def clear_mock_outputs(self):
        for name in ("candidate", "rig.json", "parts", "master.png", "source_provenance.json"):
            path = self.folder / name
            if path.is_dir() and not path.is_symlink():
                shutil.rmtree(path)
            else:
                path.unlink(missing_ok=True)

    def convert(self, parts, theme, proposal, stage, provenance):
        self.assertEqual(parts.read_bytes(), (self.folder / "raw/parts.png").read_bytes())
        self.assertEqual(theme.read_bytes(), (self.folder / "raw/theme.png").read_bytes())
        self.assertEqual(proposal, self.fx.job["proposal"])
        self.assertEqual(provenance["approved_proposal"], proposal)
        if self.expected_layout is not None:
            self.assertEqual((stage / "source_layout.json").read_bytes(), self.expected_layout)
        result = self.fx.make_candidate(parts, theme, proposal, stage, provenance)
        self.write_editable(stage, proposal, provenance)
        return result

    def write_editable(self, stage, proposal, provenance):
        (stage / "parts").mkdir()
        for name, image in authored_parts(proposal["rig_id"], proposal["theme"]["palette"]).items():
            image.save(stage / "parts" / (name + ".png"))
        (stage / "rig.json").write_text(json.dumps(make_rig(proposal["rig_id"])))
        source_provenance = {
            "schema_version": 1, **provenance, "fixture": "mock local conversion",
        }
        if (stage / "source_layout.json").is_file():
            source_provenance["source_layout_sha256"] = hashlib.sha256((stage / "source_layout.json").read_bytes()).hexdigest()
        (stage / "source_provenance.json").write_text(json.dumps(source_provenance))
        Image.open(stage / "candidate/portrait.png").save(stage / "master.png")

    def test_verified_raw_recovers_candidate_and_editable_parts_without_paid_configuration(self):
        self.seed_failed_conversion()
        status = self.invoke_local()
        self.assertEqual(status["state"], "complete")
        self.assertEqual(Path(status["candidate_path"]), self.folder / "candidate")
        validate_bundle(self.folder / "candidate")
        self.assertTrue((self.folder / "rig.json").is_file())
        self.assertTrue((self.folder / "parts/head.png").is_file())
        self.assertTrue((self.folder / "master.png").is_file())
        self.assertTrue((self.folder / "source_provenance.json").is_file())
        self.converter.assert_called_once()
        self.fx.baker.assert_not_called()
        self.assert_no_rebill()

    def test_layout_is_copied_to_generate_conversion_stage(self):
        self.fx.approve()
        document = (json.dumps(LAYOUT, indent=2) + "\n").encode()
        self.layout.write_bytes(document)
        seen = []
        def generating(parts, theme, proposal, stage, provenance):
            seen.append((stage / "source_layout.json").read_bytes())
            return self.fx.make_candidate(parts, theme, proposal, stage, provenance)
        self.fx.converter.side_effect = generating
        status = self.fx.invoke("generate")
        self.assertEqual(status["state"], "complete")
        self.assertEqual(seen, [document])
        self.assertEqual(self.layout.read_bytes(), document)

    def test_layout_is_copied_to_retained_raw_recovery_stage(self):
        self.seed_failed_conversion()
        document = (json.dumps(LAYOUT, indent=2) + "\n").encode()
        self.expected_layout = document + b" " * (65536 - len(document))
        self.layout.write_bytes(self.expected_layout)
        self.assertEqual(self.invoke_local()["state"], "complete")
        self.assertEqual(self.layout.read_bytes(), self.expected_layout)
        self.converter.assert_called_once()
        self.assert_no_rebill()

    def test_invalid_oversized_or_symlink_layout_never_reaches_converter(self):
        self.seed_failed_conversion()
        outside = self.fx.root / "layout-target.json"
        outside.write_text(json.dumps(LAYOUT))
        for kind in ("invalid_json", "array", "oversized", "schema_bool", "schema_missing", "symlink"):
            with self.subTest(kind=kind):
                self.clear_mock_outputs()
                self.layout.unlink(missing_ok=True)
                if kind == "symlink":
                    self.layout.symlink_to(outside)
                else:
                    self.layout.write_bytes({"invalid_json": b"not-json", "array": b"[]",
                                             "oversized": json.dumps({"padding": "x" * 65536}).encode(),
                                             "schema_bool": b'{"schema_version":true}',
                                             "schema_missing": b'{"fixture":"missing version"}'}[kind])
                with self.assertRaises(ForgeError):
                    self.invoke_local()
                self.converter.assert_not_called()
                self.assertFalse((self.folder / "candidate").exists())
                self.assert_no_rebill()

    def test_missing_or_modified_raw_source_provenance_and_approval_are_rejected(self):
        self.seed_failed_conversion()
        snapshots = {path: path.read_bytes() for path in self.folder.rglob("*") if path.is_file()}
        original_source = self.fx.source.read_bytes()
        for kind in ("missing_source", "changed_source", "missing_parts", "changed_parts",
                     "missing_theme", "changed_theme", "missing_provenance", "invalid_provenance",
                     "missing_approval", "changed_approval", "changed_raw_hash", "changed_original_source"):
            with self.subTest(kind=kind):
                self.clear_mock_outputs()
                for path, data in snapshots.items():
                    path.write_bytes(data)
                self.fx.source.write_bytes(original_source)
                provenance_path = self.folder / "provenance.json"
                provenance = json.loads(provenance_path.read_text())
                if kind.startswith("missing_") and kind.split("_", 1)[1] in ("source", "parts", "theme"):
                    (self.folder / "raw" / (kind.split("_", 1)[1] + ".png")).unlink()
                elif kind.startswith("changed_") and kind.split("_", 1)[1] in ("source", "parts", "theme"):
                    name = kind.split("_", 1)[1]
                    (self.folder / "raw" / (name + ".png")).write_bytes(fixtures.png_bytes((1024, 1024), name != "theme", variant=1))
                elif kind == "missing_provenance":
                    provenance_path.unlink()
                elif kind == "invalid_provenance":
                    provenance_path.write_text("not-json")
                elif kind == "missing_approval":
                    job = json.loads(self.fx.job_path.read_text())
                    job.pop("proposal")
                    self.fx.job_path.write_text(json.dumps(job))
                elif kind == "changed_approval":
                    job = json.loads(self.fx.job_path.read_text())
                    job["proposal"]["name"] = "Different approved design"
                    self.fx.job_path.write_text(json.dumps(job))
                elif kind == "changed_original_source":
                    self.fx.source.write_bytes(fixtures.png_bytes(variant=1))
                else:
                    provenance["requests"]["parts"]["sha256"] = "0" * 64
                    provenance_path.write_text(json.dumps(provenance))
                with self.assertRaises(ForgeError):
                    self.invoke_local()
                self.converter.assert_not_called()
                self.assertFalse((self.folder / "candidate").exists())
                self.assert_no_rebill()

    def test_project_conversion_reason_reaches_generate_and_recovery_status(self):
        self.fx.approve()
        self.fx.converter.side_effect = BundleError(REASON)
        with self.assertRaisesRegex(ForgeError, "Generated head is blank"):
            self.fx.invoke("generate")
        self.assertIn(REASON, self.fx.status()["message"])
        self.budget = self.fx.root / "build/forge/budget.json"
        self.budget_before = self.budget.read_bytes()
        self.fx.provider.reset_mock()
        self.converter.side_effect = BundleError(REASON)
        with self.assertRaisesRegex(ForgeError, "Generated head is blank"):
            self.invoke_local()
        self.assertIn(REASON, self.fx.status()["message"])
        self.assert_no_rebill()

    def test_failed_raw_conversion_preserves_previous_candidate_and_provenance(self):
        self.seed_failed_conversion()
        candidate = self.fx.make_candidate()
        (self.folder / "rig.json").unlink(missing_ok=True)
        previous = {path.name: path.read_bytes() for path in candidate.iterdir()}
        provenance = (self.folder / "provenance.json").read_bytes()
        self.converter.side_effect = BundleError(REASON)
        with self.assertRaises(ForgeError):
            self.invoke_local()
        self.assertEqual({path.name: path.read_bytes() for path in candidate.iterdir()}, previous)
        self.assertEqual((self.folder / "provenance.json").read_bytes(), provenance)
        self.assertFalse((self.folder / "rig.json").exists())
        self.assert_no_rebill()

    def test_failed_raw_publication_preserves_previous_candidate_and_editable_boundary(self):
        self.seed_failed_conversion()
        candidate = self.fx.make_candidate()
        (self.folder / "rig.json").unlink(missing_ok=True)
        previous = {path.name: path.read_bytes() for path in candidate.iterdir()}
        provenance = (self.folder / "provenance.json").read_bytes()
        original_status = jobs.write_status
        def fail_complete(folder, root, state, message, **extra):
            if state == "complete":
                raise OSError("publication test failure")
            return original_status(folder, root, state, message, **extra)
        with patch.object(jobs, "write_status", side_effect=fail_complete):
            with self.assertRaises(ForgeError):
                self.invoke_local()
        self.converter.assert_called_once()
        self.assertEqual({path.name: path.read_bytes() for path in candidate.iterdir()}, previous)
        self.assertEqual((self.folder / "provenance.json").read_bytes(), provenance)
        self.assertFalse((self.folder / "rig.json").exists())
        self.assertFalse((self.folder / "parts").exists())
        self.assertEqual(self.fx.status()["state"], "failed")
        self.assert_no_rebill()

    def test_existing_rig_still_uses_local_baker_without_raw_images(self):
        self.seed_failed_conversion()
        (self.folder / "rig.json").write_text(json.dumps(make_rig("upright")))
        (self.folder / "raw/parts.png").unlink()
        (self.folder / "raw/theme.png").unlink()
        document = (json.dumps(LAYOUT) + "\n").encode()
        self.layout.write_bytes(document)
        (self.folder / "source_provenance.json").write_text(json.dumps({
            "schema_version": 1, "source_layout_sha256": hashlib.sha256(document).hexdigest(),
        }))
        def existing_bake(path):
            self.assertEqual((path.parent / "source_layout.json").read_bytes(), document)
            return self.fx.make_candidate(_stage=path.parent)
        self.fx.baker = Mock(side_effect=existing_bake)
        status = self.invoke_local()
        self.assertEqual(status["state"], "complete")
        self.fx.baker.assert_called_once()
        self.converter.assert_not_called()
        self.assert_no_rebill()

    def test_real_hazy_non_grid_boards_recover_only_after_reviewed_layout_then_rebake_locally(self):
        authored = content_fixtures.FighterContentTests()
        authored.setUp()
        self.addCleanup(authored.tearDown)
        raw, proposal, layout = authored.annotated_raw_job()
        proposal = {key: proposal[key] for key in ("name", "rig_id", "kit_id", "theme", "features")}
        self.fx.job["proposal"] = proposal
        self.fx.write_job()
        self.fx.provider.image.side_effect = [
            ((raw / "raw_parts.png").read_bytes(), {"request_id": "req_mock_hazy_parts"}),
            ((raw / "raw_theme.png").read_bytes(), {"request_id": "req_mock_reviewed_theme"}),
        ]
        with self.assertRaisesRegex(ForgeError, "clipped"):
            self.fx.invoke("generate", converter=None)
        self.assertFalse((self.folder / "rig.json").exists())
        self.assertFalse((self.folder / "candidate").exists())
        self.budget = self.fx.root / "build/forge/budget.json"
        self.budget_before = self.budget.read_bytes()
        self.fx.provider.reset_mock()
        self.layout.write_text(json.dumps(layout))
        first = self.invoke_local(converter=None)
        self.assertEqual(first["state"], "complete")
        candidate = Path(first["candidate_path"])
        self.assertEqual(validate_bundle(candidate)["rig_id"], "upright")
        provenance = json.loads((candidate / "provenance.json").read_text())
        self.assertEqual(provenance["source_layout"], layout)
        self.assertEqual(provenance["source_layout_sha256"], hashlib.sha256(self.layout.read_bytes()).hexdigest())
        self.assertEqual(provenance["bake_inputs"]["source_layout"], layout)
        with Image.open(candidate / "background.png") as background:
            self.assertEqual(background.convert("RGB").getextrema(), ((40, 40), (60, 60), (80, 80)))
        previous = {name: (candidate / name).read_bytes()
                    for name in ("character.png", "background.png", "materials.png")}
        second = self.invoke_local(baker=None, converter=None)
        self.assertEqual(second["state"], "complete")
        for name, data in previous.items():
            self.assertEqual((candidate / name).read_bytes(), data, name)
        self.assertTrue((self.folder / "rig.json").is_file())
        self.assertTrue((self.folder / "master.png").is_file())
        self.assert_no_rebill()

    def assert_existing_layout_change_is_refused(self, change):
        self.seed_failed_conversion()
        if change != "added":
            self.expected_layout = (json.dumps(LAYOUT) + "\n").encode()
            self.layout.write_bytes(self.expected_layout)
        self.invoke_local()
        candidate = self.folder / "candidate"
        previous = {path.name: path.read_bytes() for path in candidate.iterdir()}
        provenance = (self.folder / "provenance.json").read_bytes()
        if change == "removed":
            self.layout.unlink()
        elif change == "added":
            self.layout.write_text(json.dumps(LAYOUT))
        else:
            self.layout.write_text(json.dumps({**LAYOUT, "columns": 4}))
        self.converter.reset_mock()
        self.fx.baker.reset_mock()
        with self.assertRaisesRegex(ForgeError, "new local correction job"):
            self.invoke_local()
        self.assertEqual({path.name: path.read_bytes() for path in candidate.iterdir()}, previous)
        self.assertEqual((self.folder / "provenance.json").read_bytes(), provenance)
        self.converter.assert_not_called()
        self.fx.baker.assert_not_called()
        self.assert_no_rebill()

    def test_adding_layout_after_rig_conversion_requires_new_local_correction_job(self):
        self.assert_existing_layout_change_is_refused("added")

    def test_changing_layout_after_rig_conversion_requires_new_local_correction_job(self):
        self.assert_existing_layout_change_is_refused("changed")

    def test_removing_layout_after_rig_conversion_requires_new_local_correction_job(self):
        self.assert_existing_layout_change_is_refused("removed")


if __name__ == "__main__":
    unittest.main()
