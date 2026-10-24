"""Mock-only checks for whole-generation cost/cache preflight.

Every job, ledger and image here is a disposable fixture. No SDK, environment
file, real account or network request is used.
"""
from __future__ import annotations

import json
import unittest
from unittest.mock import patch

from tools.forge import jobs
from tools.forge.jobs import ForgeError, run_job
import tools.tests.test_forge_provider as fixtures


class ForgePreflightTests(unittest.TestCase):
    def setUp(self):
        self.fx = fixtures.ForgeProviderTests()
        self.fx.setUp()
        self.addCleanup(self.fx.doCleanups)
        self.fx.approve()
        self.ledger_path = self.fx.root / "build/forge/budget.json"

    def seed_analysis_reservations(self, count):
        for number in range(count):
            folder = self.fx.root / ("seed-analysis-" + str(number))
            folder.mkdir()
            path = folder / "job.json"
            path.write_text(json.dumps({k: v for k, v in self.fx.job.items() if k != "proposal"}))
            run_job("analyse", path, root=self.fx.root, provider=self.fx.provider,
                    config=self.fx.config)
        self.fx.provider.reset_mock()

    def generate(self):
        with patch.object(jobs, "settings", side_effect=AssertionError("No environment read is permitted")):
            with patch.object(jobs, "OpenAIProvider", side_effect=AssertionError("No SDK is permitted")):
                return self.fx.invoke("generate")

    def seed_parts_only(self):
        # A synthetic interruption after a received parts board leaves no theme
        # attempt. Removing this test marker models an explicit resumed command;
        # the game bridge itself never silently resumes a cancelled job.
        def receive_parts(_source, _prompt, transparent):
            self.assertTrue(transparent)
            (self.fx.job_dir / "cancel").touch()
            return self.fx.parts, {"request_id": "req_mock_retained_parts"}
        self.fx.provider.image.side_effect = receive_parts
        self.assertEqual(self.generate()["state"], "cancelled")
        self.assertTrue((self.fx.job_dir / "raw/parts.png").is_file())
        self.assertFalse((self.fx.job_dir / "raw/theme.png").exists())
        (self.fx.job_dir / "cancel").unlink()
        self.fx.provider.reset_mock()

    def test_shared_fifteen_cents_remaining_never_starts_fresh_twenty_cent_generation(self):
        self.seed_analysis_reservations(7)
        self.assertAlmostEqual(self.fx.ledger()["reserved_usd"], 0.35)
        before = self.ledger_path.read_bytes()
        with self.assertRaises(ForgeError):
            self.generate()
        self.assertEqual(self.fx.provider.image.call_count, 0,
                         "The complete missing-image cost must fit before the first image request")
        self.fx.provider.analyse.assert_not_called()
        self.fx.converter.assert_not_called()
        self.assertEqual(self.ledger_path.read_bytes(), before)
        self.assertEqual(self.fx.status()["state"], "failed")
        self.assertFalse((self.fx.job_dir / "raw/parts.png").exists())

    def test_exact_twenty_cent_job_budget_completes_both_image_requests(self):
        self.fx.job["budget_usd"] = 0.20
        self.fx.write_job()
        status = self.generate()
        self.assertEqual(status["state"], "complete")
        self.assertEqual(self.fx.provider.image.call_count, 2)
        self.assertEqual([call.args[-1] for call in self.fx.provider.image.call_args_list], [True, False])
        self.fx.provider.analyse.assert_not_called()
        self.fx.converter.assert_called_once()
        self.assertAlmostEqual(self.fx.ledger()["reserved_usd"], 0.20)

    def test_valid_cached_parts_need_only_remaining_ten_cent_theme_reservation(self):
        self.seed_analysis_reservations(6)
        self.fx.job["budget_usd"] = 0.20
        self.fx.write_job()
        self.seed_parts_only()
        self.assertAlmostEqual(self.fx.ledger()["reserved_usd"], 0.40)
        self.fx.provider.image.side_effect = [
            (self.fx.theme, {"request_id": "req_mock_only_missing_theme"}),
        ]
        status = self.generate()
        self.assertEqual(status["state"], "complete")
        self.fx.provider.image.assert_called_once()
        self.assertIs(self.fx.provider.image.call_args.args[-1], False)
        self.fx.provider.analyse.assert_not_called()
        self.assertAlmostEqual(self.fx.ledger()["reserved_usd"], 0.50)
        self.assertEqual((self.fx.job_dir / "raw/parts.png").read_bytes(), self.fx.parts)

    def test_corrupt_parts_cache_is_rejected_before_calls_or_reservations(self):
        self.seed_parts_only()
        before = self.ledger_path.read_bytes()
        path = self.fx.job_dir / "raw/parts.png"
        provenance_path = self.fx.job_dir / "provenance.json"
        good_provenance = provenance_path.read_bytes()
        for damage in ("missing_pixels", "changed_pixels", "changed_cache_key"):
            with self.subTest(damage=damage):
                path.write_bytes(self.fx.parts)
                provenance_path.write_bytes(good_provenance)
                if damage == "missing_pixels":
                    path.unlink()
                elif damage == "changed_pixels":
                    path.write_bytes(fixtures.png_bytes((1024, 1024), transparent=True, variant=1))
                else:
                    provenance = json.loads(good_provenance)
                    provenance["requests"]["parts"]["cache_key"] = "0" * 64
                    provenance_path.write_text(json.dumps(provenance))
                with self.assertRaises(ForgeError):
                    self.generate()
                self.fx.provider.image.assert_not_called()
                self.fx.provider.analyse.assert_not_called()
                self.fx.converter.assert_not_called()
                self.assertEqual(self.ledger_path.read_bytes(), before)


if __name__ == "__main__":
    unittest.main()
