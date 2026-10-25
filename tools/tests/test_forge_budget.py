"""Local allowance migration/recovery checks. Mock providers only, no real keys."""
from __future__ import annotations

import copy
from concurrent.futures import ThreadPoolExecutor
import json
import os
from pathlib import Path
import unittest
from unittest.mock import patch

from tools.forge import jobs
from tools.forge.provider import ForgeError, public_settings, settings, total_budget_microusd
import tools.tests.test_forge_provider as fixtures


class ForgeBudgetTests(unittest.TestCase):
    def setUp(self):
        self.fx = fixtures.ForgeProviderTests()
        self.fx.setUp()
        self.addCleanup(self.fx.doCleanups)
        self.fx.approve()
        self.path = self.fx.root / 'build/forge/budget.json'

    def seed_legacy(self, reservations=None):
        kinds = [('analyse', 'received'), ('parts', 'uncertain'),
                 ('parts', 'received'), ('theme', 'received')]
        records = reservations or [
            {'job': f'legacy-job-{i}', 'kind': kind,
             'cache_key': f'legacy-request-{i}', 'microusd': jobs.RESERVATIONS[kind],
             'state': state, 'created_at': 'fixture-only'}
            for i, (kind, state) in enumerate(kinds)]
        jobs.write_json(self.path, {'schema_version': 1, 'cap_microusd': max(500000, sum(r['microusd'] for r in records)),
                                   'reserved_usd': sum(r['microusd'] for r in records) / 1e6,
                                   'reservations': records})
        return copy.deepcopy(records)

    def test_two_dollar_allowance_preserves_legacy_and_uncertain_reservations(self):
        records = self.seed_legacy()
        before = self.path.read_bytes()
        safe = jobs.budget_status(self.fx.root, total_cap=2000000, required=200000)
        self.assertEqual(safe['total_remaining_usd'], 1.65)
        self.assertEqual(safe['required_usd'], .20)
        self.assertEqual(self.path.read_bytes(), before, 'Status does not rewrite the old ledger')
        self.fx.config['forge_total_budget_usd'] = '2.00'
        self.assertEqual(self.fx.invoke('generate')['state'], 'complete')
        ledger = self.fx.ledger()
        self.assertEqual(ledger['reservations'][:4], records)
        self.assertEqual(ledger['cap_microusd'], 2000000)
        self.assertEqual(ledger['reserved_usd'], .55)
        self.assertEqual(self.fx.provider.image.call_count, 2)
        self.fx.provider.analyse.assert_not_called()

    def test_blocked_valid_draft_resumes_after_limit_change_without_analysis(self):
        self.seed_legacy()
        with self.assertRaises(ForgeError) as error:
            self.fx.invoke('generate')
        self.assertEqual(error.exception.code, 'shared_budget_exceeded')
        failed = self.fx.status()
        self.assertTrue(failed['retry_allowed'])
        self.assertEqual(failed['budget']['total_remaining_usd'], .15)
        self.assertEqual(failed['budget']['job_remaining_usd'], .50)
        self.assertEqual(failed['budget']['required_usd'], .20)
        self.fx.provider.image.assert_not_called()
        provenance = jobs.read_json(self.fx.job_dir / 'provenance.json')
        normalized = (self.fx.job_dir / 'raw/source.png').read_bytes()
        self.fx.config['forge_total_budget_usd'] = '2.00'
        result = self.fx.invoke('generate')
        self.assertEqual(result['state'], 'complete')
        self.assertEqual((self.fx.job_dir / 'raw/source.png').read_bytes(), normalized)
        self.assertEqual(jobs.read_json(self.fx.job_dir / 'provenance.json')['created_at'], provenance['created_at'])
        self.fx.provider.analyse.assert_not_called()
        self.assertEqual(self.fx.provider.image.call_count, 2)

    def test_character_cap_has_a_distinct_failure_before_any_image(self):
        self.fx.config['forge_total_budget_usd'] = '2.00'
        self.fx.job['budget_usd'] = .10
        self.fx.write_job()
        with self.assertRaises(ForgeError) as error:
            self.fx.invoke('generate')
        self.assertEqual(error.exception.code, 'job_budget_exceeded')
        budget = self.fx.status()['budget']
        self.assertEqual(budget['total_remaining_usd'], 2.0)
        self.assertEqual(budget['job_remaining_usd'], .10)
        self.assertEqual(budget['required_usd'], .20)
        self.fx.provider.image.assert_not_called()
        self.assertFalse(self.path.exists())

    def test_lower_limit_blocks_without_erasing_prior_spending(self):
        self.seed_legacy()
        before = self.path.read_bytes()
        self.fx.config['forge_total_budget_usd'] = '.20'
        with self.assertRaises(ForgeError):
            self.fx.invoke('generate')
        self.assertEqual(self.path.read_bytes(), before)
        self.assertEqual(self.fx.status()['budget']['total_remaining_usd'], 0)
        self.fx.provider.image.assert_not_called()

    def test_ledger_cap_cannot_grant_more_than_configured_allowance(self):
        self.seed_legacy()
        ledger = jobs.read_json(self.path)
        ledger['cap_microusd'] = 100000000
        jobs.write_json(self.path, ledger)
        with self.assertRaises(ForgeError) as error:
            self.fx.invoke('generate')
        self.assertEqual(error.exception.code, 'shared_budget_exceeded')
        self.assertEqual(self.fx.status()['budget']['total_limit_usd'], .50)
        self.fx.provider.image.assert_not_called()

    def test_racing_jobs_cannot_exceed_new_total(self):
        records = [{'job': f'prior-{i}', 'kind': 'parts', 'cache_key': f'fixture-{i}',
                    'microusd': 100000, 'state': 'received'} for i in range(19)]
        records.append({'job': 'prior-analysis', 'kind': 'analyse', 'cache_key': 'fixture-analysis',
                        'microusd': 50000, 'state': 'uncertain'})
        self.seed_legacy(records)
        def reserve(number):
            try:
                jobs.reserve(self.fx.root, self.fx.root / f'job-{number}/job.json',
                             'analyse', f'new-{number}', 500000, 2000000)
                return 'reserved'
            except ForgeError as error:
                return error.code
        with ThreadPoolExecutor(max_workers=2) as pool:
            results = list(pool.map(reserve, range(2)))
        self.assertCountEqual(results, ['reserved', 'shared_budget_exceeded'])
        self.assertEqual(self.fx.ledger()['reserved_usd'], 2.0)
        self.assertEqual(self.fx.ledger()['reservations'][:20], records)

    def test_config_uses_explicit_env_limit_and_public_metadata_has_no_key(self):
        (self.fx.root / '.env').write_text('OPENAI_API_KEY=fixture-secret-do-not-print\nFORGE_TOTAL_BUDGET_USD=2.00\n')
        with patch.dict(os.environ, {}, clear=True):
            config = settings(self.fx.root)
        self.assertEqual(total_budget_microusd(config), 2000000)
        public = public_settings(config)
        self.assertEqual(public['total_budget_usd'], 2.0)
        self.assertNotIn(config['key'], json.dumps(public))
        self.assertEqual(total_budget_microusd({}), 500000)
        for invalid in [True, -1, 101, 'nan', 'Infinity', '0.0000001', 'wrong',
                        '1e999999', '0.50000000000000000000000000001']:
            with self.subTest(invalid=invalid), self.assertRaises(ForgeError):
                total_budget_microusd({'forge_total_budget_usd': invalid})

    def test_missing_key_has_a_local_path_hint_and_no_reservation(self):
        self.fx.config['key'] = ''
        self.fx.config['forge_total_budget_usd'] = '2.00'
        with self.assertRaises(ForgeError) as error:
            self.fx.invoke('generate', provider=None)
        self.assertEqual(error.exception.code, 'missing_key')
        self.assertIn(str(self.fx.root / '.env'), str(error.exception))
        self.assertTrue(self.fx.status()['retry_allowed'])
        self.assertFalse(self.path.exists())
        self.fx.provider.image.assert_not_called()

    def test_zero_allowance_still_allows_verified_free_cached_conversion(self):
        self.fx.config['forge_total_budget_usd'] = '2.00'
        self.fx.converter.side_effect = RuntimeError('fixture conversion failure')
        with self.assertRaises(ForgeError):
            self.fx.invoke('generate')
        before = self.path.read_bytes()
        self.assertEqual(self.fx.provider.image.call_count, 2)
        self.fx.config['forge_total_budget_usd'] = '0.00'
        self.fx.config['key'] = ''
        self.fx.converter.side_effect = self.fx.make_candidate
        result = self.fx.invoke('generate', provider=None)
        self.assertEqual(result['state'], 'complete')
        self.assertEqual(result['budget']['total_limit_usd'], 0)
        self.assertEqual(result['budget']['total_remaining_usd'], 0)
        self.assertEqual(self.path.read_bytes(), before)
        self.assertEqual(self.fx.provider.image.call_count, 2)
        self.fx.provider.analyse.assert_not_called()


if __name__ == '__main__':
    unittest.main()
