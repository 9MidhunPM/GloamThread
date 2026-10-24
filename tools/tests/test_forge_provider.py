"""Mock-only acceptance checks for the local forge's public job boundary.

No OpenAI client, private .env, or network endpoint is used by these tests.
The drawing and provider PNGs below are explicit test fixtures, not AI art.
"""
from __future__ import annotations

import copy
import base64
from concurrent.futures import ThreadPoolExecutor
import hashlib
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import threading
from types import SimpleNamespace
import unittest
from unittest.mock import Mock, patch

from PIL import Image, ImageDraw

from tools.forge.jobs import ForgeError, run_job
from tools.forge.provider import OpenAIProvider, public_settings
from tools.forge import jobs
from tools.forge.art import RIG_PARTS, authored_parts, make_rig


PROPOSAL = {
    "name": "Cinder Finch",
    "rig_id": "upright",
    "kit_id": "ember",
    "theme": {
        "name": "Copper Orchard",
        "palette": ["#172838", "#824F3D", "#BE794B", "#E9C58A"],
        "motif": "small stitched leaves and lantern rings",
    },
    "features": ["angular hood", "square brass reel", "short curved beak"],
}


def png_bytes(size=(64, 64), transparent=False, variant=0):
    """Distinct ordinary images with real transparent/opaque fixture pixels."""
    image = Image.new("RGBA", size, (0, 0, 0, 0) if transparent else (23, 40, 56, 255))
    draw = ImageDraw.Draw(image)
    w, h = size
    draw.polygon([(w // 3, h // 5), (w * 2 // 3, h // 4),
                  (w * 3 // 4, h * 4 // 5), (w // 4, h * 4 // 5)],
                 fill=(190, 121 + variant, 75, 255))
    draw.line((w // 3, h // 2, w * 2 // 3, h // 2), fill=(233, 197, 138, 255), width=2)
    stream = io.BytesIO()
    image.save(stream, format="PNG")
    return stream.getvalue()


class ForgeProviderTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.job_dir = self.root / "job"
        self.job_dir.mkdir()
        self.source = self.root / "drawing.png"
        self.source.write_bytes(png_bytes())
        self.job_path = self.job_dir / "job.json"
        self.job = {"schema_version": 1, "source_image": str(self.source),
                    "description": "An upright small bird courier in a copper hood.",
                    "budget_usd": 0.50}
        self.config = {"key": "sk-forge-canary-do-not-print", "model": "gpt-image-1-mini",
                       "quality": "low", "analysis_model": "gpt-6-luna"}
        self.provider = Mock(spec=["analyse", "image"])
        self.provider.analyse.return_value = (copy.deepcopy(PROPOSAL),
                                               {"request_id": "req_mock_analysis", "usage": {"input_tokens": 3}})
        self.parts = png_bytes((1024, 1024), transparent=True)
        self.theme = png_bytes((1024, 1024))
        self.provider.image.side_effect = [
            (self.parts, {"request_id": "req_mock_parts", "usage": {"input_tokens": 4}}),
            (self.theme, {"request_id": "req_mock_theme", "usage": {"input_tokens": 5}}),
        ]
        self.converter = Mock(side_effect=self.make_candidate)
        self.baker = Mock(side_effect=lambda path: self.make_candidate(_stage=path.parent))
        self.write_job()

    def write_job(self):
        self.job_path.write_text(json.dumps(self.job), encoding="utf-8")

    def approve(self):
        self.job["proposal"] = copy.deepcopy(PROPOSAL)
        self.write_job()

    def invoke(self, command, **kwargs):
        options = {"root": self.root, "provider": self.provider, "converter": self.converter,
                   "baker": self.baker, "config": self.config}
        options.update(kwargs)
        return run_job(command, self.job_path, **options)

    def status(self):
        return json.loads((self.job_dir / "status.json").read_text())

    def ledger(self):
        return json.loads((self.root / "build/forge/budget.json").read_text())

    def make_candidate(self, *args, _stage=None):
        """A structurally valid mocked-converter result, never a runtime fixture."""
        stage = Path(args[3]) if len(args) >= 4 else (_stage or self.job_dir)
        # A real successful converter always emits an editable rig beside its bundle.
        (stage / "rig.json").write_text(json.dumps(make_rig(PROPOSAL["rig_id"])))
        target = stage / "candidate"
        target.mkdir(exist_ok=False)
        files = {
            "character.png": self.character_atlas(),
            "portrait.png": png_bytes((128, 128), transparent=True),
            "background.png": png_bytes((640, 360)),
            "materials.png": png_bytes((256, 256)),
            "provenance.json": json.dumps({"schema_version": 1, "fixture": True}).encode(),
        }
        for filename, contents in files.items():
            (target / filename).write_bytes(contents)
        manifest = {"schema_version": 1, "kind": "fighter-character", "id": "cinder-finch",
                    "name": PROPOSAL["name"], "rig_id": PROPOSAL["rig_id"], "kit_id": PROPOSAL["kit_id"],
                    "theme": copy.deepcopy(PROPOSAL["theme"]),
                    "files": {name: hashlib.sha256(data).hexdigest() for name, data in files.items()}}
        (target / "manifest.json").write_text(json.dumps(manifest))
        return target

    def character_atlas(self):
        atlas = Image.new("RGBA", (544, 272))
        for index in range(32):
            frame = Image.open(io.BytesIO(png_bytes(transparent=True, variant=index)))
            # Eight actual silhouettes, rather than color-only frame variations.
            ImageDraw.Draw(frame).line((40, 30, 42 + index % 8, 22 + index % 8),
                                      fill=(233, 197, 138, 255), width=3)
            atlas.paste(frame, ((index % 8) * 68 + 2, (index // 8) * 68 + 2))
        output = io.BytesIO()
        atlas.save(output, format="PNG")
        return output.getvalue()

    def all_json_text(self):
        return "\n".join(path.read_text() for path in self.root.rglob("*.json"))

    def test_public_status_reports_presence_and_models_without_credentials(self):
        result = public_settings(self.config)
        self.assertIs(result["key_present"], True)
        self.assertEqual(result["image_model"], "gpt-image-1-mini")
        self.assertEqual(result["analysis_model"], "gpt-6-luna")
        self.assertNotIn("key", result)
        self.assertNotIn(self.config["key"], json.dumps(result))
        self.assertFalse(public_settings({**self.config, "key": ""})["key_present"])

    def test_analysis_retains_proposal_and_hash_then_awaits_explicit_approval(self):
        status = self.invoke("analyse")
        self.assertEqual(status["state"], "awaiting_approval")
        self.assertEqual(self.status(), status)
        self.assertEqual(json.loads((self.job_dir / "proposal.json").read_text()), PROPOSAL)
        self.assertIn(hashlib.sha256(self.source.read_bytes()).hexdigest(), self.all_json_text())
        self.provider.analyse.assert_called_once_with((self.job_dir / "raw/source.png").read_bytes(), self.job["description"])
        self.provider.image.assert_not_called()
        with self.assertRaises(ForgeError):
            self.invoke("generate")
        self.provider.image.assert_not_called()

    def test_invalid_analysis_proposal_never_reaches_generation(self):
        self.provider.analyse.return_value = ({**PROPOSAL, "rig_id": "flying-dragon"}, {})
        with self.assertRaises(ForgeError):
            self.invoke("analyse")
        self.assertEqual(self.status()["state"], "failed")
        self.assertFalse((self.job_dir / "proposal.json").exists())
        self.provider.analyse.assert_called_once()
        self.provider.image.assert_not_called()

    def test_invalid_source_and_oversized_description_reject_before_provider(self):
        for bad_source, description in ((b"not an image", "bird"), (png_bytes(), "x" * 2001)):
            with self.subTest(description_length=len(description)):
                self.source.write_bytes(bad_source)
                self.job["description"] = description
                self.write_job()
                (self.job_dir / "status.json").unlink(missing_ok=True)
                with self.assertRaises(ForgeError):
                    self.invoke("analyse")
                self.assertEqual(self.status()["state"], "failed")
                self.provider.analyse.assert_not_called()

    def test_empty_and_over_dimension_drawings_reject_before_provider(self):
        empty = io.BytesIO()
        Image.new("RGBA", (64, 64)).save(empty, format="PNG")
        for data in (empty.getvalue(), png_bytes((4097, 4)), b"x" * (20 * 1024 * 1024 + 1)):
            with self.subTest(source_bytes=len(data)):
                self.source.write_bytes(data)
                with self.assertRaises(ForgeError):
                    self.invoke("analyse")
                self.provider.analyse.assert_not_called()
                self.provider.image.assert_not_called()

    def test_approved_proposal_cannot_supply_extra_behavior_or_file_fields(self):
        self.approve()
        self.job["proposal"]["script"] = "res://unsafe.gd"
        self.write_job()
        with self.assertRaises(ForgeError):
            self.invoke("generate")
        self.assertEqual(self.status()["state"], "failed")
        self.provider.image.assert_not_called()

    def test_analysis_budget_is_persisted_before_billable_call(self):
        def inspect_reservation(source, description):
            self.assertEqual(source, (self.job_dir / "raw/source.png").read_bytes())
            self.assertEqual(description, self.job["description"])
            self.assertAlmostEqual(self.ledger()["reserved_usd"], 0.05)
            self.assertGreaterEqual(self.status()["reserved_usd"], 0.05)
            return copy.deepcopy(PROPOSAL), {"request_id": "req_mock_analysis"}
        self.provider.analyse.side_effect = inspect_reservation
        self.invoke("analyse")
        self.provider.analyse.assert_called_once()

    def test_duplicate_worker_for_same_job_never_starts_second_request(self):
        entered = threading.Event()
        release = threading.Event()
        def held_analysis(_source, _description):
            entered.set()
            if not release.wait(5):
                raise AssertionError("Test did not release its mock provider")
            return copy.deepcopy(PROPOSAL), {"request_id": "req_mock_single_worker"}
        self.provider.analyse.side_effect = held_analysis
        with ThreadPoolExecutor(max_workers=1) as pool:
            first = pool.submit(self.invoke, "analyse")
            try:
                self.assertTrue(entered.wait(3), "First worker never reached its mock request")
                with self.assertRaisesRegex(ForgeError, "already running"):
                    self.invoke("analyse")
                self.provider.analyse.assert_called_once()
            finally:
                release.set()
            self.assertEqual(first.result(timeout=3)["state"], "awaiting_approval")
        self.assertAlmostEqual(self.ledger()["reserved_usd"], 0.05)

    def test_two_jobs_racing_for_last_reservation_never_exceed_shared_cap(self):
        # Spend 0.45 through the same public seam, without forging a ledger.
        self.provider.image.side_effect = lambda _s, _p, transparent: (
            self.parts if transparent else self.theme, {"request_id": "req_mock_seed"})
        for number in range(3):
            self.job_dir = self.root / ("seed" + str(number))
            self.job_dir.mkdir()
            self.job_path = self.job_dir / "job.json"
            self.approve()
            self.invoke("generate" if number < 2 else "analyse")
        self.assertAlmostEqual(self.ledger()["reserved_usd"], 0.45)
        paths = []
        for number in range(2):
            folder = self.root / ("race" + str(number))
            folder.mkdir()
            path = folder / "job.json"
            path.write_text(json.dumps({k: v for k, v in self.job.items() if k != "proposal"}))
            paths.append(path)
        start = threading.Barrier(3)
        entered = threading.Event()
        release = threading.Event()
        self.provider.analyse.reset_mock()
        def held_analysis(_source, _description):
            entered.set()
            if not release.wait(5):
                raise AssertionError("Test did not release its budget contender")
            return copy.deepcopy(PROPOSAL), {"request_id": "req_mock_budget_winner"}
        self.provider.analyse.side_effect = held_analysis
        def contender(path):
            start.wait(timeout=3)
            try:
                status = run_job("analyse", path, root=self.root, provider=self.provider,
                                 config=self.config)
                return "ok", status
            except ForgeError as error:
                return "error", str(error)
        with ThreadPoolExecutor(max_workers=2) as pool:
            futures = [pool.submit(contender, path) for path in paths]
            try:
                start.wait(timeout=3)
                self.assertTrue(entered.wait(3), "Neither contender reached the mock request")
            finally:
                release.set()
            results = [future.result(timeout=3) for future in futures]
        self.assertEqual(sorted(kind for kind, _ in results), ["error", "ok"])
        self.assertIn("budget", next(value for kind, value in results if kind == "error").lower())
        self.provider.analyse.assert_called_once()
        self.assertAlmostEqual(self.ledger()["reserved_usd"], 0.50)
        self.assertEqual(sum(record["microusd"] for record in self.ledger()["reservations"]), 500000)

    def test_insufficient_job_budget_never_calls_provider(self):
        self.job["budget_usd"] = 0.01
        self.write_job()
        with self.assertRaises(ForgeError):
            self.invoke("analyse")
        self.assertEqual(self.status()["state"], "failed")
        self.provider.analyse.assert_not_called()
        self.provider.image.assert_not_called()

    def test_timeout_keeps_reservation_does_not_retry_or_echo_provider_text(self):
        self.provider.analyse.side_effect = TimeoutError("provider-body-canary " + self.config["key"])
        with self.assertRaises(ForgeError) as raised:
            self.invoke("analyse")
        self.assertEqual(self.status()["state"], "failed")
        self.assertAlmostEqual(self.ledger()["reserved_usd"], 0.05)
        self.provider.analyse.assert_called_once()
        retained = str(raised.exception) + self.all_json_text()
        self.assertNotIn("provider-body-canary", retained)
        self.assertNotIn(self.config["key"], retained)

    def test_cancel_before_analysis_makes_no_provider_call(self):
        (self.job_dir / "cancel").touch()
        status = self.invoke("analyse")
        self.assertEqual(status["state"], "cancelled")
        self.assertEqual(self.status(), status)
        self.provider.analyse.assert_not_called()
        self.provider.image.assert_not_called()

    def test_cancel_at_dispatch_boundary_prevents_call_but_keeps_reservation(self):
        original = jobs.write_status
        def cancel_at_request(folder, root, state, message, **extra):
            result = original(folder, root, state, message, **extra)
            if state == "analysing":
                (folder / "cancel").touch()
            return result
        with patch.object(jobs, "write_status", side_effect=cancel_at_request):
            status = self.invoke("analyse")
        self.assertEqual(status["state"], "cancelled")
        self.assertAlmostEqual(self.ledger()["reserved_usd"], 0.05)
        self.provider.analyse.assert_not_called()
        self.provider.image.assert_not_called()

    def test_cancel_at_image_dispatch_boundary_prevents_call_but_keeps_reservation(self):
        self.approve()
        original = jobs.write_status
        def cancel_at_request(folder, root, state, message, **extra):
            result = original(folder, root, state, message, **extra)
            if state == "generating":
                (folder / "cancel").touch()
            return result
        with patch.object(jobs, "write_status", side_effect=cancel_at_request):
            status = self.invoke("generate")
        self.assertEqual(status["state"], "cancelled")
        self.assertAlmostEqual(self.ledger()["reserved_usd"], 0.10)
        self.provider.analyse.assert_not_called()
        self.provider.image.assert_not_called()

    def test_analysis_cache_avoids_another_reservation_and_changed_drawing_refuses(self):
        self.invoke("analyse")
        reserved = self.ledger()["reserved_usd"]
        self.assertEqual(self.invoke("analyse")["state"], "awaiting_approval")
        self.provider.analyse.assert_called_once()
        self.assertEqual(self.ledger()["reserved_usd"], reserved)

        self.source.write_bytes(png_bytes(variant=1))
        with self.assertRaises(ForgeError):
            self.invoke("analyse")
        self.provider.analyse.assert_called_once()
        self.assertEqual(self.ledger()["reserved_usd"], reserved)

    def test_corrupted_raw_cache_never_triggers_a_replacement_bill(self):
        self.invoke("analyse")
        reserved = self.ledger()["reserved_usd"]
        (self.job_dir / "raw/proposal.json").write_text('{"invalid":"changed after analysis"}')
        with self.assertRaises(ForgeError):
            self.invoke("analyse")
        self.provider.analyse.assert_called_once()
        self.assertEqual(self.ledger()["reserved_usd"], reserved)

    def test_generation_reserves_each_image_and_retains_raw_hashes(self):
        self.approve()
        seen = []
        def image_request(source, prompt, transparent):
            self.assertEqual(source, (self.job_dir / "raw/source.png").read_bytes())
            self.assertIsInstance(prompt, str)
            self.assertTrue(prompt.strip())
            seen.append(transparent)
            self.assertAlmostEqual(self.ledger()["reserved_usd"], len(seen) * 0.10)
            return (self.parts if transparent else self.theme), {"request_id": "req_mock_" + str(len(seen))}
        self.provider.image.side_effect = image_request
        status = self.invoke("generate")
        self.assertEqual(status["state"], "complete")
        self.assertEqual(Path(status["candidate_path"]), self.job_dir / "candidate")
        self.assertEqual(seen, [True, False])
        self.assertEqual((self.job_dir / "raw/parts.png").read_bytes(), self.parts)
        self.assertEqual((self.job_dir / "raw/theme.png").read_bytes(), self.theme)
        provenance = (self.job_dir / "provenance.json").read_text()
        self.assertIn(hashlib.sha256(self.parts).hexdigest(), provenance)
        self.assertIn(hashlib.sha256(self.theme).hexdigest(), provenance)
        self.assertIn("req_mock_1", provenance)
        self.assertNotIn(self.config["key"], self.all_json_text())
        self.converter.assert_called_once()

    def test_generation_cache_keeps_candidate_bytes_and_does_not_rebill(self):
        self.approve()
        self.invoke("generate")
        candidate = self.job_dir / "candidate"
        before = {p.name: p.read_bytes() for p in candidate.iterdir()}
        reserved = self.ledger()["reserved_usd"]
        status = self.invoke("generate")
        self.assertEqual(status["state"], "complete")
        self.assertEqual({p.name: p.read_bytes() for p in candidate.iterdir()}, before)
        self.assertEqual(self.provider.image.call_count, 2)
        self.assertEqual(self.ledger()["reserved_usd"], reserved)
        self.converter.assert_called_once()

    def test_corrupted_completed_candidate_is_not_replaced_or_rebilled(self):
        self.approve()
        self.invoke("generate")
        image = self.job_dir / "candidate/character.png"
        image.write_bytes(b"locally changed candidate")
        reserved = self.ledger()["reserved_usd"]
        with self.assertRaises(ForgeError):
            self.invoke("generate")
        self.assertEqual(image.read_bytes(), b"locally changed candidate")
        self.assertEqual(self.provider.image.call_count, 2)
        self.assertEqual(self.ledger()["reserved_usd"], reserved)
        self.converter.assert_called_once()

    def test_shared_budget_blocks_later_jobs_before_exceeding_initial_cap(self):
        self.provider.image.side_effect = lambda _s, _p, transparent: (
            self.parts if transparent else self.theme, {"request_id": "req_mock_budget"})
        for number in range(3):
            self.job_dir = self.root / ("job" + str(number))
            self.job_dir.mkdir()
            self.job_path = self.job_dir / "job.json"
            self.approve()
            if number < 2:
                self.assertEqual(self.invoke("generate")["state"], "complete")
            else:
                with self.assertRaises(ForgeError):
                    self.invoke("generate")
                self.assertEqual(self.status()["state"], "failed")
                self.assertFalse((self.job_dir / "candidate").exists())
        self.assertAlmostEqual(self.ledger()["reserved_usd"], 0.40)
        self.assertEqual(self.provider.image.call_count, 4)
        self.assertEqual(self.converter.call_count, 2)

    def test_existing_candidate_is_never_replaced_by_new_generation(self):
        self.approve()
        candidate = self.job_dir / "candidate"
        candidate.mkdir()
        protected = candidate / "accepted-marker.txt"
        protected.write_bytes(b"previously accepted local creation")
        with self.assertRaises(ForgeError):
            self.invoke("generate")
        self.assertEqual(protected.read_bytes(), b"previously accepted local creation")
        self.assertEqual(list(candidate.iterdir()), [protected])
        self.provider.image.assert_not_called()
        self.converter.assert_not_called()

    def test_cancel_during_first_image_retains_bill_and_stops_second_request(self):
        self.approve()
        def first_image(_source, _prompt, transparent):
            self.assertTrue(transparent)
            (self.job_dir / "cancel").touch()
            return self.parts, {"request_id": "req_mock_cancelled_after_call"}
        self.provider.image.side_effect = first_image
        status = self.invoke("generate")
        self.assertEqual(status["state"], "cancelled")
        self.assertAlmostEqual(self.ledger()["reserved_usd"], 0.10)
        self.provider.image.assert_called_once()
        self.converter.assert_not_called()
        self.assertFalse((self.job_dir / "candidate").exists())

    def test_image_failure_is_not_retried_or_sent_to_converter(self):
        self.approve()
        self.provider.image.side_effect = RuntimeError("provider-image-canary " + self.config["key"])
        with self.assertRaises(ForgeError) as raised:
            self.invoke("generate")
        self.provider.image.assert_called_once()
        self.converter.assert_not_called()
        self.assertEqual(self.status()["state"], "failed")
        self.assertAlmostEqual(self.ledger()["reserved_usd"], 0.10)
        retained = str(raised.exception) + self.all_json_text()
        self.assertNotIn("provider-image-canary", retained)
        self.assertNotIn(self.config["key"], retained)

    def test_failed_conversion_never_publishes_partial_candidate(self):
        self.approve()
        def partial_conversion(_parts, _theme, _proposal, stage, _provenance):
            target = stage / "candidate"
            target.mkdir()
            (target / "partial.txt").write_text("incomplete conversion")
            raise RuntimeError("converter-private-canary")
        self.converter.side_effect = partial_conversion
        with self.assertRaises(ForgeError) as raised:
            self.invoke("generate")
        self.assertFalse((self.job_dir / "candidate").exists())
        self.assertEqual(list(self.job_dir.glob(".conversion-*")), [])
        self.assertEqual(self.provider.image.call_count, 2)
        self.assertAlmostEqual(self.ledger()["reserved_usd"], 0.20)
        self.assertEqual(self.status()["state"], "failed")
        self.assertNotIn("converter-private-canary", str(raised.exception) + self.all_json_text())

    def test_failed_local_bake_preserves_the_previous_candidate(self):
        self.approve()
        candidate = self.make_candidate()
        previous = {path.name: path.read_bytes() for path in candidate.iterdir()}
        def failing_bake(path):
            self.make_candidate(_stage=path.parent)
            raise RuntimeError("baker-private-canary")
        self.baker.side_effect = failing_bake
        with self.assertRaises(ForgeError) as raised:
            self.invoke("bake")
        self.assertEqual({path.name: path.read_bytes() for path in candidate.iterdir()}, previous)
        self.assertEqual(list(self.job_dir.glob(".bake-*")), [])
        self.assertEqual(self.status()["state"], "failed")
        self.provider.analyse.assert_not_called()
        self.provider.image.assert_not_called()
        self.assertFalse((self.root / "build/forge/budget.json").exists())
        self.assertNotIn("baker-private-canary", str(raised.exception) + self.all_json_text())

    def test_bake_publication_failure_restores_prior_candidate_and_provenance(self):
        self.approve()
        self.invoke("generate")
        candidate = self.job_dir / "candidate"
        previous = {path.name: path.read_bytes() for path in candidate.iterdir()}
        previous_provenance = (self.job_dir / "provenance.json").read_bytes()
        reserved = self.ledger()["reserved_usd"]
        original_write = jobs.write_json
        original_status = jobs.write_status
        def changed_bake(path):
            result = self.make_candidate(_stage=path.parent)
            manifest_path = result / "manifest.json"
            manifest = json.loads(manifest_path.read_text())
            manifest["name"] = "Cinder Finch Edited"
            manifest_path.write_text(json.dumps(manifest))
            self.assertNotEqual(manifest_path.read_bytes(), previous["manifest.json"])
            return result
        self.baker.side_effect = changed_bake
        for failure in ("provenance", "complete_status"):
            with self.subTest(failure=failure):
                faulted = []
                def fail_provenance(path, value):
                    if Path(path) == self.job_dir / "provenance.json" and not faulted:
                        faulted.append(True)
                        raise OSError("publication-private-canary")
                    return original_write(path, value)
                def fail_complete(folder, root, state, message, **extra):
                    if state == "complete" and not faulted:
                        faulted.append(True)
                        raise OSError("publication-private-canary")
                    return original_status(folder, root, state, message, **extra)
                injection = patch.object(jobs, "write_json", side_effect=fail_provenance) if failure == "provenance" else patch.object(jobs, "write_status", side_effect=fail_complete)
                with injection:
                    with self.assertRaises(ForgeError) as raised:
                        self.invoke("bake")
                self.assertEqual(faulted, [True])
                self.assertEqual({path.name: path.read_bytes() for path in candidate.iterdir()}, previous)
                self.assertEqual((self.job_dir / "provenance.json").read_bytes(), previous_provenance)
                self.assertEqual(self.status()["state"], "failed")
                self.assertEqual(self.provider.image.call_count, 2)
                self.assertEqual(self.ledger()["reserved_usd"], reserved)
                self.assertNotIn("publication-private-canary", str(raised.exception) + self.all_json_text())

    def test_generate_publication_failure_keeps_raw_and_publishes_no_candidate(self):
        self.approve()
        original_write = jobs.write_json
        original_status = jobs.write_status
        prepublication = []
        def converting(parts, theme, proposal, stage, provenance):
            prepublication.append((self.job_dir / "provenance.json").read_bytes())
            return self.make_candidate(parts, theme, proposal, stage, provenance)
        self.converter.side_effect = converting
        for failure in ("provenance", "complete_status"):
            with self.subTest(failure=failure):
                faulted = []
                def fail_provenance(path, value):
                    if (Path(path) == self.job_dir / "provenance.json"
                            and "candidate_sha256" in value and not faulted):
                        faulted.append(True)
                        raise OSError("publication-private-canary")
                    return original_write(path, value)
                def fail_complete(folder, root, state, message, **extra):
                    if state == "complete" and not faulted:
                        faulted.append(True)
                        raise OSError("publication-private-canary")
                    return original_status(folder, root, state, message, **extra)
                injection = patch.object(jobs, "write_json", side_effect=fail_provenance) if failure == "provenance" else patch.object(jobs, "write_status", side_effect=fail_complete)
                with injection:
                    with self.assertRaises(ForgeError) as raised:
                        self.invoke("generate")
                self.assertEqual(faulted, [True])
                self.assertFalse((self.job_dir / "candidate").exists())
                self.assertEqual((self.job_dir / "provenance.json").read_bytes(), prepublication[-1])
                self.assertEqual((self.job_dir / "raw/parts.png").read_bytes(), self.parts)
                self.assertEqual((self.job_dir / "raw/theme.png").read_bytes(), self.theme)
                self.assertEqual(self.provider.image.call_count, 2)
                self.assertAlmostEqual(self.ledger()["reserved_usd"], 0.20)
                self.assertEqual(self.status()["state"], "failed")
                self.assertNotIn("publication-private-canary", str(raised.exception) + self.all_json_text())

    def test_bake_calls_only_local_baker_without_provider_or_reservation(self):
        self.approve()
        status = self.invoke("bake")
        self.assertEqual(status["state"], "complete")
        self.baker.assert_called_once()
        bake_path = self.baker.call_args.args[0]
        self.assertEqual(bake_path.name, "job.json")
        self.assertEqual(bake_path.parent.parent, self.job_dir)
        self.provider.analyse.assert_not_called()
        self.provider.image.assert_not_called()
        self.converter.assert_not_called()
        self.assertFalse((self.root / "build/forge/budget.json").exists())

    def test_local_bake_never_reads_or_requires_paid_provider_configuration(self):
        self.approve()
        for config in (None, {"key": "", "model": "invalid", "quality": "invalid", "analysis_model": "invalid"}):
            with self.subTest(config=config):
                with patch.object(jobs, "settings", side_effect=AssertionError("paid settings must not be read")):
                    status = self.invoke("bake", config=config)
                self.assertEqual(status["state"], "complete")
        self.provider.analyse.assert_not_called()
        self.provider.image.assert_not_called()
        self.assertFalse((self.root / "build/forge/budget.json").exists())

    def raw_part_board(self, proposal):
        """Authored part fixtures mimic a returned separated-parts board."""
        palette = proposal["theme"]["palette"]
        # Drawing fixtures can use six colors while testing a four-color proposal.
        colors = (palette * 2)[:6]
        parts = authored_parts(proposal["rig_id"], colors)
        board = Image.new("RGBA", (1024, 1024))
        master = Image.new("RGBA", (64, 64))
        for number, part in enumerate(parts.values()):
            master.alpha_composite(part)
            crop = part.crop(part.getchannel("A").getbbox())
            crop = crop.resize((crop.width * 3, crop.height * 3), Image.Resampling.NEAREST)
            x0, x1 = (number % 3) * 1024 // 3, ((number % 3) + 1) * 1024 // 3
            y0, y1 = (number // 3) * 1024 // 3, ((number // 3) + 1) * 1024 // 3
            board.alpha_composite(crop, (x0 + (x1 - x0 - crop.width) // 2,
                                         y0 + (y1 - y0 - crop.height) // 2))
        master = master.crop(master.getchannel("A").getbbox())
        master = master.resize((master.width * 3, master.height * 3), Image.Resampling.NEAREST)
        board.alpha_composite(master, (682 + (342 - master.width) // 2,
                                      682 + (342 - master.height) // 2))
        stream = io.BytesIO()
        board.save(stream, format="PNG")
        return stream.getvalue()

    def test_real_converter_and_local_rebake_preserve_all_three_rigs_and_themes(self):
        for rig in RIG_PARTS:
            with self.subTest(rig=rig):
                work = self.root / rig
                work.mkdir()
                self.job_dir = work / "job"
                self.job_dir.mkdir()
                self.job_path = self.job_dir / "job.json"
                proposal = copy.deepcopy(PROPOSAL)
                proposal["rig_id"] = rig
                proposal["theme"]["palette"] += ["#F2DAA4", "#A8BEBC"]
                self.job["proposal"] = proposal
                self.write_job()
                self.provider.image.reset_mock()
                self.provider.image.side_effect = [
                    (self.raw_part_board(proposal), {"request_id": "req_mock_parts_" + rig}),
                    (self.theme, {"request_id": "req_mock_theme_" + rig}),
                ]
                first = self.invoke("generate", root=work, converter=None)
                self.assertEqual(first["state"], "complete")
                candidate = Path(first["candidate_path"])
                manifest = json.loads((candidate / "manifest.json").read_text())
                self.assertEqual(manifest["rig_id"], rig)
                self.assertEqual(set(path.stem for path in (self.job_dir / "parts").glob("*.png")),
                                 set(RIG_PARTS[rig]))
                self.assertTrue((self.job_dir / "rig.json").is_file())
                self.assertTrue((self.job_dir / "source_provenance.json").is_file())
                preserved = {name: (candidate / name).read_bytes()
                             for name in ("background.png", "materials.png", "character.png")}
                editable = {str(path.relative_to(self.job_dir)): path.read_bytes()
                            for path in (self.job_dir / "parts").glob("*.png")}
                editable["rig.json"] = (self.job_dir / "rig.json").read_bytes()
                second = self.invoke("bake", root=work, baker=None, config=None)
                self.assertEqual(second["state"], "complete")
                self.assertEqual(second["candidate_path"], first["candidate_path"])
                for name, data in preserved.items():
                    self.assertEqual((candidate / name).read_bytes(), data, name)
                for name, data in editable.items():
                    self.assertEqual((self.job_dir / name).read_bytes(), data, name)
                self.assertEqual(self.provider.image.call_count, 2)
                self.provider.analyse.assert_not_called()
                self.assertAlmostEqual(second["reserved_usd"], 0.20)

    def test_four_color_proposal_can_use_real_converter(self):
        self.approve()
        self.provider.image.side_effect = [
            (self.raw_part_board(PROPOSAL), {"request_id": "req_mock_four_color_parts"}),
            (self.theme, {"request_id": "req_mock_four_color_theme"}),
        ]
        result = self.invoke("generate", converter=None)
        self.assertEqual(result["state"], "complete")
        self.assertEqual(json.loads((self.job_dir / "candidate/manifest.json").read_text())["theme"]["palette"],
                         PROPOSAL["theme"]["palette"])

    def test_manual_approved_proposal_without_features_generates_without_analysis(self):
        self.approve()
        self.job["proposal"]["features"] = []
        self.write_job()
        self.provider.image.side_effect = [
            (self.raw_part_board(self.job["proposal"]), {"request_id": "req_mock_manual_parts"}),
            (self.theme, {"request_id": "req_mock_manual_theme"}),
        ]
        status = self.invoke("generate", converter=None)
        self.assertEqual(status["state"], "complete")
        self.assertTrue((Path(status["candidate_path"]) / "manifest.json").is_file())
        self.provider.analyse.assert_not_called()
        self.assertEqual(self.provider.image.call_count, 2)
        self.assertAlmostEqual(status["reserved_usd"], 0.20)


class ForgeCLIProcessTests(unittest.TestCase):
    def test_real_cli_bakes_with_space_paths_and_no_provider_or_env_dependencies(self):
        with tempfile.TemporaryDirectory(prefix="forge-cli-") as directory:
            root = Path(directory)
            checkout = Path(__file__).resolve().parents[2]
            (root / "tools").mkdir()
            shutil.copy2(checkout / "tools/fighter_forge.py", root / "tools/fighter_forge.py")
            shutil.copytree(checkout / "tools/forge", root / "tools/forge",
                            ignore=shutil.ignore_patterns("__pycache__"))
            # Any accidental SDK/settings import is a regression in this local command.
            for name in ("openai.py", "dotenv.py"):
                (root / "tools" / name).write_text("raise RuntimeError('offline bake imported a provider dependency')\n")
            (root / ".env").write_text("OPENAI_IMAGE_MODEL=unreviewed-model\nOPENAI_IMAGE_QUALITY=invalid\n")
            folder = root / "job with spaces"
            (folder / "parts").mkdir(parents=True)
            proposal = copy.deepcopy(PROPOSAL)
            proposal["rig_id"], proposal["kit_id"] = "floating", "storm"
            for name, image in authored_parts("floating", proposal["theme"]["palette"]).items():
                image.save(folder / "parts" / (name + ".png"))
            (folder / "rig.json").write_text(json.dumps(make_rig("floating")))
            (folder / "source.png").write_bytes(png_bytes())
            job_path = folder / "job.json"
            job_path.write_text(json.dumps({"schema_version": 1, "source_image": str(folder / "source.png"),
                                            "description": "local fixture", "proposal": proposal, "budget_usd": 0}))
            child_env = {**os.environ, "OPENAI_API_KEY": "", "OPENAI_IMAGE_MODEL": "unreviewed-model"}
            result = subprocess.run([sys.executable, str(root / "tools/fighter_forge.py"), "bake", "--job", str(job_path)],
                                    cwd=root, env=child_env, capture_output=True, text=True, timeout=15)
            self.assertEqual(result.returncode, 0, result.stderr)
            status = json.loads(result.stdout)
            self.assertEqual(status["state"], "complete")
            self.assertEqual(status["reserved_usd"], 0)
            self.assertEqual(Path(status["candidate_path"]), folder / "candidate")
            self.assertFalse((root / "build/forge/budget.json").exists())
            self.assertEqual(jobs.validate_candidate(folder / "candidate")["rig_id"], "floating")
            self.assertEqual(result.stderr, "")


class ForgeOfficialAdapterTests(unittest.TestCase):
    """The optional SDK adapter is replaced in memory; no SDK/key is required."""

    def setUp(self):
        self.config = {"key": "sk-adapter-canary", "model": "gpt-image-1-mini",
                       "quality": "low", "analysis_model": "gpt-6-luna"}
        self.provider = OpenAIProvider(self.config)

    def context(self, client):
        context = Mock()
        context.__enter__ = Mock(return_value=client)
        context.__exit__ = Mock(return_value=False)
        return context

    def test_official_client_disables_retries_and_ignores_endpoint_redirects(self):
        constructor = Mock(return_value=object())
        with patch.dict(sys.modules, {"openai": SimpleNamespace(OpenAI=constructor)}):
            with patch.dict("os.environ", {"OPENAI_BASE_URL": "https://untrusted.invalid"}):
                result = self.provider._client()
        self.assertIs(result, constructor.return_value)
        constructor.assert_called_once_with(api_key=self.config["key"],
                                            base_url="https://api.openai.com/v1",
                                            max_retries=0, timeout=180.0)

    def test_analysis_uses_strict_schema_and_returns_only_safe_request_metadata(self):
        response = SimpleNamespace(status="completed", output_text=json.dumps(PROPOSAL),
                                   _request_id="req_mock_strict",
                                   usage=SimpleNamespace(input_tokens=3, output_tokens=4, total_tokens=7))
        client = Mock()
        client.responses.create.return_value = response
        with patch.object(self.provider, "_client", return_value=self.context(client)):
            proposal, metadata = self.provider.analyse(png_bytes(), "A copper bird.")
        self.assertEqual(proposal, PROPOSAL)
        self.assertEqual(metadata, {"request_id": "req_mock_strict",
                                    "usage": {"input_tokens": 3, "output_tokens": 4, "total_tokens": 7}})
        client.responses.create.assert_called_once()
        request = client.responses.create.call_args.kwargs
        self.assertEqual(request["model"], "gpt-6-luna")
        self.assertIs(request["store"], False)
        self.assertLessEqual(request["max_output_tokens"], 2048)
        self.assertIs(request["text"]["format"]["strict"], True)
        self.assertIs(request["text"]["format"]["schema"]["additionalProperties"], False)
        self.assertNotIn(self.config["key"], json.dumps(request))

    def test_malformed_provider_analysis_is_rejected_without_provider_body(self):
        client = Mock()
        client.responses.create.return_value = SimpleNamespace(
            status="completed", output_text="provider-body-canary " + self.config["key"])
        with patch.object(self.provider, "_client", return_value=self.context(client)):
            with self.assertRaises(ForgeError) as raised:
                self.provider.analyse(png_bytes(), "bird")
        client.responses.create.assert_called_once()
        self.assertNotIn("provider-body-canary", str(raised.exception))
        self.assertNotIn(self.config["key"], str(raised.exception))

    def test_image_provider_error_has_no_retry_fallback_or_sensitive_body(self):
        client = Mock()
        error = RuntimeError("image-provider-canary " + self.config["key"])
        error.status_code = 429
        client.images.edit.side_effect = error
        with patch.object(self.provider, "_client", return_value=self.context(client)):
            with self.assertRaises(ForgeError) as raised:
                self.provider.image(png_bytes(), "an original bird fighter", True)
        client.images.edit.assert_called_once()
        request = client.images.edit.call_args.kwargs
        self.assertEqual(request["model"], "gpt-image-1-mini")
        self.assertEqual(request["n"], 1)
        self.assertEqual(request["size"], "1024x1024")
        self.assertEqual(request["quality"], "low")
        self.assertEqual(request["background"], "transparent")
        self.assertIn("429", str(raised.exception))
        self.assertNotIn("image-provider-canary", str(raised.exception))
        self.assertNotIn(self.config["key"], str(raised.exception))

    def test_image_edit_attaches_original_source_and_explicit_output_settings(self):
        source = png_bytes()
        for transparent in (True, False):
            with self.subTest(transparent=transparent):
                output = png_bytes((1024, 1024), transparent=transparent)
                response = SimpleNamespace(
                    data=[SimpleNamespace(b64_json=base64.b64encode(output).decode("ascii"))],
                    _request_id="req_mock_edit", usage=None)
                client = Mock()
                client.images.edit.return_value = response
                constructor = Mock(return_value=self.context(client))
                with patch.dict(sys.modules, {"openai": SimpleNamespace(OpenAI=constructor)}):
                    received, metadata = self.provider.image(source, "Original copper bird", transparent)
                self.assertEqual(received, output)
                self.assertEqual(metadata, {"request_id": "req_mock_edit", "usage": {}})
                constructor.assert_called_once_with(api_key=self.config["key"],
                                                    base_url="https://api.openai.com/v1",
                                                    max_retries=0, timeout=180.0)
                client.images.edit.assert_called_once()
                request = client.images.edit.call_args.kwargs
                self.assertEqual(request["image"], ("drawing.png", source, "image/png"))
                self.assertEqual(request["prompt"], "Original copper bird")
                self.assertEqual(request["model"], "gpt-image-1-mini")
                self.assertEqual(request["quality"], "low")
                self.assertEqual(request["size"], "1024x1024")
                self.assertEqual(request["n"], 1)
                self.assertEqual(request["output_format"], "png")
                self.assertEqual(request["background"], "transparent" if transparent else "opaque")


if __name__ == "__main__":
    unittest.main()
