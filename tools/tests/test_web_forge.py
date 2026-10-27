"""Hosted Forge ownership, durable queue and billing boundaries; no network."""
from __future__ import annotations

import base64
import copy
from concurrent.futures import ThreadPoolExecutor
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from server.service import ForgeService, correction_files, parse_json, safe_file
from server.store import ServiceError, Store, token_hash
from server.worker import configuration, exclusive_worker, heartbeat, run_once
from tools.forge import jobs
from tools.forge.hosted_accounting import SqliteAccounting
from tools.forge.provider import ForgeError
from tools.tests import test_forge_provider as fixture


def encoded(value: bytes) -> str:
    return base64.b64encode(value).decode()


class HostedForgeTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.store = Store(Path(self.tmp.name) / "private")
        self.service = ForgeService(self.store)
        self.invite = self.store.create_invite("fixture creator")
        self.owner = self.invite["owner_id"]
        self.other = self.store.create_invite("other creator")["owner_id"]
        self.source = fixture.png_bytes()
        self.fx = fixture.ForgeProviderTests()
        self.fx.setUp()
        self.addCleanup(self.fx.doCleanups)

    def create(self, owner=None, **kwargs):
        payload = {"source_png": encoded(self.source), "description": "An original bird courier.",
                   "art_mode": "illustrated-master-v1"}
        payload.update(kwargs)
        return self.service.create_job(owner or self.owner, payload)["job_id"]

    def submit(self, identity, command="analyse", key="fixture-request-1", owner=None, **kwargs):
        return self.service.enqueue(owner or self.owner, identity,
                                    {"command": command, "idempotency_key": key, **kwargs})

    def work(self, **kwargs):
        options = {"config": self.fx.config, "provider": self.fx.provider,
                   "converter": self.fx.converter, "baker": self.fx.baker}
        options.update(kwargs)
        return run_once(self.store, **options)

    def generate(self):
        identity = self.create()
        self.submit(identity, "generate", proposal=copy.deepcopy(fixture.PROPOSAL))
        self.work()
        self.assertEqual(self.service.status(self.owner, identity)["state"], "complete")
        return identity

    def test_invite_codes_are_hashed_and_sessions_revocable(self):
        token = self.store.login(self.invite["code"], "fixture-client")
        self.assertEqual(self.store.owner_for_session(token), self.owner)
        with self.store.connect() as db:
            row = dict(db.execute("SELECT * FROM invites WHERE owner_id=?", (self.owner,)).fetchone())
        self.assertEqual(row["code_hash"], token_hash(self.invite["code"]))
        self.assertNotIn(self.invite["code"], json.dumps(row))
        self.store.revoke(self.owner)
        with self.assertRaises(ServiceError):
            self.store.owner_for_session(token)
        with self.assertRaises(ServiceError):
            self.store.login(self.invite["code"], "fixture-client")

    def test_invite_attempts_are_rate_limited(self):
        for _ in range(10):
            with self.assertRaises(ServiceError):
                self.store.login("incorrect-but-bounded-code", "fixture-client")
        with self.assertRaises(ServiceError) as context:
            self.store.login(self.invite["code"], "fixture-client")
        self.assertEqual(context.exception.status, 429)

    def test_ownership_enforced_for_all_job_operations(self):
        identity = self.create()
        for action in (lambda: self.service.status(self.other, identity),
                       lambda: self.service.snapshot(self.other, identity),
                       lambda: self.submit(identity, owner=self.other),
                       lambda: self.store.cancel(self.other, identity),
                       lambda: self.create(owner=self.other, parent_job_id=identity)):
            with self.subTest(action=action), self.assertRaises(ServiceError) as context:
                action()
            self.assertEqual(context.exception.status, 404)

    def test_opaque_ids_and_source_paths_cannot_escape_storage(self):
        for identity in ("../outside", "a" * 31, "/etc/passwd", "0" * 32):
            with self.assertRaises(ServiceError):
                self.service.status(self.owner, identity)
        with self.assertRaises(ServiceError):
            self.create(source_image="/etc/passwd")
        with self.assertRaises(ServiceError):
            self.create(source_png=encoded(b"not PNG"))

    def test_strict_json_and_correction_allowlist(self):
        for value in (b'{"a":1,"a":2}', b'{"a":NaN}', b'[]'):
            with self.assertRaises(ServiceError):
                parse_json(value)
        for name in ("job.json", "../secret", "rig.json", "provenance.json", "raw/parts.png", "masks/../../secret.png"):
            with self.subTest(name=name), self.assertRaises(ServiceError):
                correction_files({name: encoded(b"{}")})
        with self.assertRaises(ServiceError):
            correction_files({"illustrated_master.png": encoded(b"not PNG")})
        self.assertTrue(safe_file("parts/head.png"))
        self.assertFalse(safe_file("parts/unknown.png"))

    def test_double_submission_returns_same_operation_without_second_provider_call(self):
        identity = self.create()
        first = self.submit(identity)
        again = self.submit(identity)
        self.assertEqual(first["operation_id"], again["operation_id"])
        with self.assertRaises(ServiceError) as context:
            self.submit(identity, description="unsupported")
        self.assertEqual(context.exception.status, 400)
        self.work()
        third = self.submit(identity)
        self.assertEqual(first["operation_id"], third["operation_id"])
        self.assertFalse(self.work())
        self.fx.provider.analyse.assert_called_once()
        self.assertEqual(self.service.status(self.owner, identity)["state"], "awaiting_approval")

    def test_same_idempotency_key_changed_body_conflicts(self):
        identity = self.create()
        self.submit(identity)
        with self.assertRaises(ServiceError) as context:
            self.submit(identity, command="generate", proposal=fixture.PROPOSAL)
        self.assertEqual(context.exception.status, 409)

    def test_one_active_operation_per_invite(self):
        one, two = self.create(), self.create()
        self.submit(one)
        with self.assertRaises(ServiceError) as context:
            self.submit(two, key="another-request")
        self.assertEqual(context.exception.status, 409)
        different = self.create(owner=self.other)
        self.submit(different, owner=self.other)
        self.work()
        self.work()
        self.assertEqual(self.fx.provider.analyse.call_count, 2)

    def test_concurrent_duplicate_submission_accepts_one_operation(self):
        identity = self.create()
        with ThreadPoolExecutor(max_workers=2) as pool:
            replies = list(pool.map(lambda _: self.submit(identity), range(2)))
        self.assertEqual(replies[0]["operation_id"], replies[1]["operation_id"])
        self.work()
        self.fx.provider.analyse.assert_called_once()

    def test_generation_admits_full_candidate_and_snapshot_has_no_server_paths(self):
        identity = self.generate()
        result = self.service.snapshot(self.owner, identity)
        self.assertEqual(result["candidate_dir"], "candidate")
        self.assertEqual(set(name.split("/", 1)[1] for name in result["files"] if name.startswith("candidate/")),
                         {"manifest.json", "character.png", "portrait.png", "background.png", "materials.png", "provenance.json"})
        self.assertNotIn("job.json", result["files"])
        self.assertNotIn("status.json", result["files"])
        text = json.dumps(self.service.status(self.owner, identity))
        self.assertNotIn(str(self.store.root), text)
        self.assertNotIn(self.fx.config["key"], text)
        self.assertFalse((self.store.root / "build/forge/budget.json").exists())
        self.assertEqual(self.fx.provider.image.call_count, 2)

    def test_private_request_totals_and_durable_sqlite_history(self):
        identity = self.create()
        self.submit(identity)
        self.work()
        own = self.service.configuration(self.owner)["budget"]["total_reserved_usd"]
        other = self.service.configuration(self.other)["budget"]["total_reserved_usd"]
        self.assertEqual(own, .05)
        self.assertEqual(other, 0)
        reopened = ForgeService(Store(self.store.root))
        self.assertEqual(reopened.configuration(self.owner)["budget"]["total_reserved_usd"], .05)
        self.assertFalse(reopened.configuration(self.owner)["budget"]["limits_enabled"])

    def test_prospective_stage_estimates_survive_projection_and_restart(self):
        estimates = {"analyse_usd": .05, "generate_usd": .20, "bake_usd": 0}
        self.assertEqual(self.service.configuration(self.owner)["request_estimates"], estimates)
        self.assertEqual(self.service.configuration(None)["budget"]["required_usd"], .05)
        self.assertEqual(self.service.configuration(self.owner)["budget"]["required_usd"], .05)
        identity = self.create()
        self.assertEqual(self.service.status(self.owner, identity)["budget"]["required_usd"], .05)
        self.submit(identity)
        self.work()
        reviewed = self.service.status(self.owner, identity)
        self.assertEqual(reviewed["state"], "awaiting_approval")
        self.assertEqual(reviewed["budget"]["required_usd"], .20)
        self.assertEqual(reviewed["budget"]["job_reserved_usd"], .05)
        self.assertEqual(reviewed["request_estimates"], estimates)
        reopened = ForgeService(Store(self.store.root))
        self.assertEqual(reopened.status(self.owner, identity)["budget"]["required_usd"], .20)
        self.submit(identity, "generate", key="explicit-generation", proposal=fixture.PROPOSAL)
        self.work()
        self.assertEqual(self.service.status(self.owner, identity)["budget"]["required_usd"], 0)
        self.assertEqual(self.service.accounting(self.owner).status()["total_reserved_usd"], .25)
        correction = self.create(parent_job_id=identity)
        self.assertEqual(self.service.status(self.owner, correction)["budget"]["required_usd"], 0)
        self.submit(correction, "bake", key="explicit-free-conversion")
        self.work(config={})
        self.assertEqual(self.service.status(self.owner, correction)["state"], "complete")
        self.assertEqual(self.service.status(self.owner, correction)["budget"]["required_usd"], 0)
        self.assertEqual(self.service.accounting(self.owner).status()["total_reserved_usd"], .25)

    def test_restart_preserves_queued_and_marks_running_uncertain_without_retry(self):
        identity = self.create()
        self.submit(identity)
        running = self.store.claim()
        accounting = self.service.accounting(self.owner)
        accounting.reserve(self.store.require_job(self.owner, identity), "analyse", "request-cache-key")
        other = self.create(owner=self.other)
        self.submit(other, owner=self.other)
        self.store.recover_interrupted()
        self.assertEqual(self.service.status(self.owner, identity)["state"], "uncertain")
        self.assertEqual(accounting.ledger()["reservations"][0]["state"], "uncertain")
        self.work()
        self.assertEqual(self.fx.provider.analyse.call_count, 1)
        self.submit(identity, key="explicit-new-key")
        self.assertFalse(self.work())
        self.assertEqual(self.service.status(self.owner, identity)["state"], "cancelled")

    def test_uncertain_provider_request_cannot_be_replayed_with_new_key(self):
        identity = self.create()
        self.fx.provider.analyse.side_effect = TimeoutError("private provider request body")
        self.submit(identity)
        self.work()
        self.assertEqual(self.service.status(self.owner, identity)["state"], "failed")
        self.submit(identity, key="explicit-new-key")
        self.work()
        self.assertEqual(self.fx.provider.analyse.call_count, 1)
        self.assertEqual(self.service.accounting(self.owner).ledger()["reservations"][0]["state"], "uncertain")

    def test_cancel_before_dispatch_makes_no_request(self):
        identity = self.create()
        self.submit(identity)
        self.store.cancel(self.owner, identity)
        self.assertFalse(self.work())
        self.fx.provider.analyse.assert_not_called()
        self.assertEqual(self.service.status(self.owner, identity)["state"], "cancelled")

    def test_revoke_during_parts_request_prevents_theme_request(self):
        identity = self.create()
        def first_image(*_):
            self.store.revoke(self.owner)
            return self.fx.parts, {"request_id": "fixture"}
        self.fx.provider.image.side_effect = first_image
        self.submit(identity, "generate", proposal=fixture.PROPOSAL)
        self.work()
        self.assertEqual(self.fx.provider.image.call_count, 1)
        self.assertEqual(self.service.status(self.owner, identity)["state"], "cancelled")
        self.assertEqual(self.service.accounting(self.owner).status()["total_reserved_usd"], .1)

    def test_parent_clone_and_sdk_free_correction_preserve_history(self):
        identity = self.generate()
        correction = self.create(parent_job_id=identity)
        source = self.store.require_job(self.owner, identity).parent
        copied = self.store.require_job(self.owner, correction).parent
        self.assertEqual((source / "raw/parts.png").read_bytes(), (copied / "raw/parts.png").read_bytes())
        self.assertFalse((copied / "rig.json").exists())
        before = self.service.accounting(self.owner).ledger()
        self.fx.provider.reset_mock()
        # Use the real cache-admission pipeline but an explicit mocked converter.
        self.submit(correction, "bake", key="free-correction")
        with patch.object(jobs, "settings", side_effect=AssertionError("No settings for conversion")), \
             patch.object(jobs, "OpenAIProvider", side_effect=AssertionError("No SDK for conversion")):
            self.work(config={})
        self.assertEqual(self.service.status(self.owner, correction)["state"], "complete")
        self.assertEqual(self.service.accounting(self.owner).ledger(), before)
        self.fx.provider.image.assert_not_called()
        self.fx.provider.analyse.assert_not_called()
        self.assertTrue((source / "candidate/manifest.json").is_file())

    def test_real_illustrated_master_snapshot_and_free_mask_pivot_correction(self):
        identity = self.create()
        self.submit(identity, "generate", proposal=fixture.PROPOSAL)
        self.work(converter=None, baker=None)
        self.assertEqual(self.service.status(self.owner, identity)["state"], "complete")
        snapshot = self.service.snapshot(self.owner, identity)
        self.assertIn("parts/master.png", snapshot["files"])
        self.assertIn("masks/master.png", snapshot["files"])
        source = self.store.require_job(self.owner, identity).parent
        before_candidate = (source / "candidate/character.png").read_bytes()
        before = self.service.accounting(self.owner).ledger()
        correction = self.create(parent_job_id=identity)
        edits = encoded(json.dumps({"schema_version": 1,
                                    "parts": {"master": {"pivot": [31, 55], "mask_file": "masks/master.png"}}}).encode())
        mask = encoded((source / "masks/master.png").read_bytes())
        self.submit(correction, "bake", key="illustrated-free-bake",
                    files={"rig_edits.json": edits, "masks/master.png": mask})
        self.fx.provider.reset_mock()
        with patch.object(jobs, "OpenAIProvider", side_effect=AssertionError("No SDK for correction")):
            self.work(config={}, converter=None, baker=None)
        self.assertEqual(self.service.status(self.owner, correction)["state"], "complete")
        self.assertIn("parts/master.png", self.service.snapshot(self.owner, correction)["files"])
        self.assertEqual((source / "candidate/character.png").read_bytes(), before_candidate)
        self.assertEqual(self.service.accounting(self.owner).ledger(), before)
        self.fx.provider.image.assert_not_called()
        self.fx.provider.analyse.assert_not_called()

    def test_second_worker_is_refused(self):
        with exclusive_worker(self.store):
            with self.assertRaises(ServiceError):
                with exclusive_worker(self.store):
                    self.fail("second worker acquired exclusive storage")

    def test_only_worker_reads_selected_secret_file_and_heartbeat_contains_no_key(self):
        secret = self.store.root / "provider.env"
        secret.write_text("OPENAI_API_KEY=fixture-file-private\nOPENAI_IMAGE_MODEL=gpt-image-1-mini\nOPENAI_IMAGE_QUALITY=low\n")
        with patch.dict(os.environ, {"FORGE_SECRET_FILE": str(secret), "OPENAI_API_KEY": "fixture-process-private"}, clear=True):
            config = configuration()
        self.assertEqual(config["key"], "fixture-file-private")
        self.assertEqual(config["model"], "gpt-image-1-mini")
        self.assertEqual(config["quality"], "low")
        heartbeat(self.store, config)
        public = json.dumps(self.service.configuration(self.owner))
        self.assertTrue(self.service.configuration(self.owner)["key_present"])
        self.assertNotIn("fixture-file-private", public)
        self.assertNotIn("fixture-process-private", public)
        self.assertNotIn(str(secret), public)
        link = self.store.root / "linked.env"
        link.symlink_to(secret)
        with patch.dict(os.environ, {"FORGE_SECRET_FILE": str(link)}, clear=True):
            with self.assertRaises(ServiceError):
                configuration()

    def test_configuration_reflects_selected_worker_models_without_credentials(self):
        config = {"key": "fixture-secret-private", "analysis_model": "gpt-analysis-fixture",
                  "model": "gpt-image-fixture", "quality": "medium"}
        heartbeat(self.store, config)
        public = self.service.configuration(self.owner)
        self.assertEqual(public["analysis_model"], "gpt-analysis-fixture")
        self.assertEqual(public["image_model"], "gpt-image-fixture")
        self.assertEqual(public["image_quality"], "medium")
        self.assertEqual(public["models"], {"analysis": "gpt-analysis-fixture", "image": "gpt-image-fixture", "quality": "medium"})
        self.assertNotIn(config["key"], (self.store.root / "worker.json").read_text())
        heartbeat(self.store, {**config, "model": config["key"], "quality": "/private/provider.env"})
        public = self.service.configuration(self.owner)
        self.assertEqual(public["image_model"], "unavailable")
        self.assertEqual(public["image_quality"], "unavailable")
        self.assertNotIn(config["key"], json.dumps(public))

    def test_invalid_candidate_cannot_be_downloaded_as_success(self):
        identity = self.generate()
        path = self.store.require_job(self.owner, identity).parent
        (path / "candidate/character.png").write_bytes(b"invalid")
        with self.assertRaises(ForgeError):
            self.service.status(self.owner, identity)
        with self.assertRaises(ForgeError):
            self.service.snapshot(self.owner, identity)

    def test_failed_correction_keeps_parent_candidate_and_history(self):
        identity = self.generate()
        parent = self.store.require_job(self.owner, identity).parent
        previous = (parent / "candidate/manifest.json").read_bytes()
        correction = self.create(parent_job_id=identity)
        before = self.service.accounting(self.owner).ledger()
        invalid = encoded(b'{"schema_version":true}')
        self.submit(correction, "bake", key="bad-correction", files={"source_layout.json": invalid})
        self.work()
        self.assertEqual(self.service.status(self.owner, correction)["state"], "failed")
        self.assertEqual((parent / "candidate/manifest.json").read_bytes(), previous)
        self.assertEqual(self.service.accounting(self.owner).ledger(), before)


if __name__ == "__main__":
    unittest.main()
