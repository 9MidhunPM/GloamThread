"""Uncapped local accounting migration. Mock providers and temporary data only."""
from __future__ import annotations

import copy
from concurrent.futures import ThreadPoolExecutor
import json
import os
import threading
import unittest
from unittest.mock import patch

from tools.forge import jobs
from tools.forge.jobs import run_job
from tools.forge.provider import ForgeError, public_settings, settings, total_budget_microusd
import tools.tests.test_forge_provider as fixtures


class ForgeBudgetTests(unittest.TestCase):
    def setUp(self):
        self.fx = fixtures.ForgeProviderTests()
        self.fx.setUp()
        self.addCleanup(self.fx.doCleanups)
        self.fx.approve()
        self.path = self.fx.root / "build/forge/budget.json"

    def seed_legacy(self, reservations=None, cap=None):
        kinds = [("analyse", "received"), ("parts", "uncertain"),
                 ("parts", "received"), ("theme", "received")]
        records = reservations if reservations is not None else [
            {"job": f"legacy-job-{number}", "kind": kind,
             "cache_key": f"legacy-request-{number}", "microusd": jobs.RESERVATIONS[kind],
             "state": state, "created_at": "fixture-only"}
            for number, (kind, state) in enumerate(kinds)]
        total = sum(record["microusd"] for record in records)
        jobs.write_json(self.path, {"schema_version": 1,
                                   "cap_microusd": max(500000, total) if cap is None else cap,
                                   "reserved_usd": total / 1e6, "reservations": records})
        return copy.deepcopy(records)

    def assert_uncapped(self, budget):
        self.assertIs(budget["limits_enabled"], False)
        for name in ("total_limit_usd", "total_remaining_usd", "job_limit_usd", "job_remaining_usd"):
            self.assertIsNone(budget[name], name)

    def test_legacy_and_uncertain_records_survive_crossing_old_fifty_cents(self):
        records = self.seed_legacy()
        before = self.path.read_bytes()
        status = jobs.budget_status(self.fx.root, self.fx.job_path, total_cap=0, required=200000)
        self.assert_uncapped(status)
        self.assertAlmostEqual(status["total_reserved_usd"], 0.35)
        self.assertAlmostEqual(status["required_usd"], 0.20)
        self.assertEqual(self.path.read_bytes(), before, "Status must not rewrite legacy history")
        result = self.fx.invoke("generate")
        self.assertEqual(result["state"], "complete")
        self.assert_uncapped(result["budget"])
        ledger = self.fx.ledger()
        self.assertEqual(ledger["reservations"][:4], records)
        self.assertIsNone(ledger["cap_microusd"])
        self.assertAlmostEqual(ledger["reserved_usd"], 0.55)
        self.assertEqual(self.fx.provider.image.call_count, 2)
        self.fx.provider.analyse.assert_not_called()

    def test_generation_continues_above_two_dollars_with_legacy_zero_configuration(self):
        records = [{"job": f"prior-{n}", "kind": "parts", "cache_key": f"request-{n}",
                    "microusd": 100000, "state": "received"} for n in range(25)]
        records.append({"job": "uncertain-analysis", "kind": "analyse", "cache_key": "uncertain-request",
                        "microusd": 50000, "state": "uncertain"})
        previous = self.seed_legacy(records)
        self.fx.config["forge_total_budget_usd"] = "0.00"
        self.fx.job["budget_usd"] = 0
        self.fx.write_job()
        result = self.fx.invoke("generate")
        self.assertEqual(result["state"], "complete")
        self.assert_uncapped(result["budget"])
        self.assertAlmostEqual(result["budget"]["total_reserved_usd"], 2.75)
        self.assertEqual(self.fx.ledger()["reservations"][:26], previous)
        self.assertEqual(self.fx.provider.image.call_count, 2)

    def test_old_numeric_ledger_cap_is_not_an_admission_threshold(self):
        previous = self.seed_legacy(cap=0)
        self.assertEqual(jobs.ledger(self.fx.root)["reservations"], previous)
        self.assertEqual(self.fx.invoke("generate")["state"], "complete")
        self.assertEqual(self.fx.ledger()["reservations"][:4], previous)
        self.assertIsNone(self.fx.ledger()["cap_microusd"])
        self.assertAlmostEqual(self.fx.ledger()["reserved_usd"], 0.55)

    def test_legacy_job_budget_values_are_ignored_without_relaxing_schema(self):
        for value in (0, 0.10, 0.50, 2, -1, None, "old-unused-value", {"ignored": True}):
            with self.subTest(value=value):
                self.fx.job["budget_usd"] = value
                self.fx.write_job()
                job, cap = jobs.read_job(self.fx.job_path)
                self.assertEqual(job["budget_usd"], value)
                self.assertIsNone(cap)
        self.fx.job["schema_version"] = True
        self.fx.write_job()
        with self.assertRaises(ForgeError):
            jobs.read_job(self.fx.job_path)

    def test_distinct_concurrent_jobs_both_dispatch_and_preserve_accounting(self):
        records = [{"job": f"prior-{n}", "kind": "parts", "cache_key": f"fixture-{n}",
                    "microusd": 100000, "state": "received"} for n in range(19)]
        records.append({"job": "prior-analysis", "kind": "analyse", "cache_key": "fixture-analysis",
                        "microusd": 50000, "state": "uncertain"})
        self.seed_legacy(records, cap=2000000)
        self.fx.config["forge_total_budget_usd"] = "0.00"
        gate = threading.Barrier(2)
        def analyse(_source, _description):
            gate.wait(timeout=3)
            return copy.deepcopy(fixtures.PROPOSAL), {"request_id": "req_mock_concurrent"}
        self.fx.provider.analyse.side_effect = analyse
        paths = []
        for number in range(2):
            folder = self.fx.root / f"concurrent-{number}"
            folder.mkdir()
            path = folder / "job.json"
            path.write_text(json.dumps({**self.fx.job, "budget_usd": 0}))
            paths.append(path)
        def invoke(path):
            return run_job("analyse", path, root=self.fx.root, provider=self.fx.provider,
                           config=self.fx.config)
        with ThreadPoolExecutor(max_workers=2) as pool:
            results = list(pool.map(invoke, paths))
        self.assertEqual([r["state"] for r in results], ["awaiting_approval", "awaiting_approval"])
        self.assertEqual(self.fx.provider.analyse.call_count, 2)
        self.fx.provider.image.assert_not_called()
        ledger = self.fx.ledger()
        self.assertAlmostEqual(ledger["reserved_usd"], 2.05)
        self.assertEqual(ledger["reservations"][:20], records)
        self.assertEqual(len({r["job"] for r in ledger["reservations"][20:]}), 2)
        self.assertIsNone(ledger["cap_microusd"])

    def test_retired_configuration_is_ignored_and_public_metadata_has_no_key(self):
        # A disposable fixture, never the workspace's private .env.
        (self.fx.root / ".env").write_text("OPENAI_API_KEY=fixture-secret-do-not-print\nFORGE_TOTAL_BUDGET_USD=not-a-dollar\n")
        with patch.dict(os.environ, {}, clear=True):
            config = settings(self.fx.root)
        public = public_settings(config)
        self.assertIs(public["key_present"], True)
        self.assertIsNone(public["total_budget_usd"])
        self.assertNotIn(config["key"], json.dumps(public))
        self.assertNotIn("key", public)
        for value in ({}, {"forge_total_budget_usd": "0.00"}, {"forge_total_budget_usd": "2.00"},
                      {"forge_total_budget_usd": "unused"}, {"forge_total_budget_usd": True}):
            with self.subTest(value=value):
                self.assertIsNone(total_budget_microusd(value))

    def test_uncertain_attempt_without_cached_output_is_never_automatically_retried(self):
        self.fx.provider.image.side_effect = TimeoutError("fixture provider uncertainty")
        with self.assertRaises(ForgeError):
            self.fx.invoke("generate")
        self.assertEqual(self.fx.provider.image.call_count, 1)
        before = self.path.read_bytes()
        self.assertEqual(self.fx.ledger()["reservations"][0]["state"], "uncertain")
        self.assertFalse((self.fx.job_dir / "raw/parts.png").exists())
        self.fx.provider.image.side_effect = [(self.fx.parts, {"request_id": "must-not-dispatch"})]
        with self.assertRaises(ForgeError):
            self.fx.invoke("generate")
        self.assertEqual(self.fx.provider.image.call_count, 1)
        self.assertEqual(self.path.read_bytes(), before)
        self.fx.converter.assert_not_called()

    def test_missing_key_still_has_a_local_path_hint_without_a_reservation(self):
        self.fx.config["key"] = ""
        self.fx.config["forge_total_budget_usd"] = "0.00"
        with self.assertRaises(ForgeError) as error:
            self.fx.invoke("generate", provider=None)
        self.assertEqual(error.exception.code, "missing_key")
        self.assertIn(str(self.fx.root / ".env"), str(error.exception))
        self.assertTrue(self.fx.status()["retry_allowed"])
        self.assertFalse(self.path.exists())
        self.fx.provider.image.assert_not_called()

    def test_verified_free_cache_conversion_works_without_key_or_legacy_allowance(self):
        self.fx.converter.side_effect = RuntimeError("fixture conversion failure")
        with self.assertRaises(ForgeError):
            self.fx.invoke("generate")
        before = self.path.read_bytes()
        self.assertEqual(self.fx.provider.image.call_count, 2)
        self.fx.config["forge_total_budget_usd"] = "0.00"
        self.fx.config["key"] = ""
        self.fx.job["budget_usd"] = 0
        self.fx.write_job()
        self.fx.converter.side_effect = self.fx.make_candidate
        result = self.fx.invoke("generate", provider=None)
        self.assertEqual(result["state"], "complete")
        self.assert_uncapped(result["budget"])
        self.assertEqual(self.path.read_bytes(), before)
        self.assertEqual(self.fx.provider.image.call_count, 2)
        self.fx.provider.analyse.assert_not_called()

    def test_uncapped_accounting_still_rejects_inconsistent_totals(self):
        self.seed_legacy()
        value = jobs.read_json(self.path)
        value["reserved_usd"] = 99
        jobs.write_json(self.path, value)
        before = self.path.read_bytes()
        with self.assertRaises(ForgeError):
            jobs.ledger(self.fx.root)
        self.assertEqual(self.path.read_bytes(), before)


if __name__ == "__main__":
    unittest.main()
