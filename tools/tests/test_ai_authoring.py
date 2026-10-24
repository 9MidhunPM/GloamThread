"""Provider-boundary tests: no network calls or user credentials."""
from contextlib import redirect_stdout, redirect_stderr
import io
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
import ai_assets as ai


class AuthoringTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        (self.root / 'assets/source').mkdir(parents=True)
        (self.root / 'assets/manifest.json').write_text('{"baseline":true}')
        jobs = {name: {'prompt': 'An original project authored pixel art test specimen.', 'background': background}
                for name, background in [('materials', 'opaque'), ('tavi', 'transparent')]}
        (self.root / 'assets/source/image_prompts.json').write_text(json.dumps({'schema_version': 1, 'jobs': jobs}))
        self.config = {'key': 'synthetic-test-secret-never-print', 'model': 'gpt-image-1-mini', 'quality': 'low'}

    def png(self, alpha=False):
        im = Image.new('RGBA', (1024, 1024), (100, 80, 60, 0 if alpha else 255))
        if alpha:
            im.paste((120, 100, 80, 255), (100, 100, 200, 200))
        stream = io.BytesIO()
        im.save(stream, format='PNG')
        return stream.getvalue()

    def test_plan_is_bounded_explicit_and_has_no_key(self):
        work = ai.plan(self.config, 'smoke', self.root)
        self.assertEqual(work['requests'], 2)
        self.assertEqual(work['max_retries'], 0)
        self.assertEqual(work['cost_estimate']['image_output_usd'], .01)
        self.assertEqual([j['n'] for j in work['jobs']], [1, 1])
        self.assertNotIn(self.config['key'], json.dumps(work))
        self.assertFalse((self.root / 'build').exists())

    def test_missing_key_never_calls_provider_or_creates_run(self):
        def forbidden(*_):
            self.fail('Provider must not be called')
        with self.assertRaisesRegex(ai.AuthoringError, 'No API request'):
            ai.generate({**self.config, 'key': ''}, 'smoke', self.root, forbidden)
        self.assertFalse((self.root / 'build').exists())

    def test_real_pngs_and_provenance_retained_without_secrets(self):
        calls = []
        def provider(key, payload):
            calls.append(payload)
            self.assertEqual(key, self.config['key'])
            return self.png(payload['background'] == 'transparent'), {'usage': {'total_tokens': 10}}
        first = ai.generate(self.config, 'smoke', self.root, provider)
        second = ai.generate(self.config, 'materials', self.root, provider)
        self.assertNotEqual(first, second)
        self.assertEqual(len(calls), 3)
        meta = json.loads((first / 'provenance.json').read_text())
        self.assertEqual(meta['status'], 'raw_ready_for_conversion')
        self.assertEqual(len(meta['outputs']), 2)
        self.assertTrue((self.root / 'build/.gdignore').exists())
        for file in first.rglob('*.json'):
            self.assertNotIn(self.config['key'], file.read_text())
        self.assertEqual((first / 'raw/materials.png').read_bytes(), self.png())

    def test_failed_or_opaque_sprite_never_retries_or_hides_raw(self):
        calls = []
        def provider(_key, payload):
            calls.append(payload)
            return self.png(), {}
        with self.assertRaisesRegex(ai.AuthoringError, 'real transparency'):
            ai.generate(self.config, 'smoke', self.root, provider)
        self.assertEqual(len(calls), 2)
        folder = next((self.root / 'build/ai-assets').iterdir())
        self.assertTrue((folder / 'raw/tavi.png').exists())
        self.assertEqual(json.loads((folder / 'provenance.json').read_text())['status'], 'failed_or_interrupted')
        self.assertFalse((folder / 'candidate').exists())

    def test_uncertain_provider_error_is_not_retried_or_echoed(self):
        calls = []
        def provider(*_):
            calls.append(1)
            raise RuntimeError(self.config['key'])
        with self.assertRaises(ai.AuthoringError) as error:
            ai.generate(self.config, 'smoke', self.root, provider)
        self.assertNotIn(self.config['key'], str(error.exception))
        self.assertEqual(len(calls), 1)
        folder = next((self.root / 'build/ai-assets').iterdir())
        attempt = json.loads((folder / 'raw/materials.attempt.json').read_text())
        self.assertEqual(attempt['status'], 'started')
        self.assertFalse((folder / 'candidate').exists())

    def test_env_is_not_executed_or_interpolated_and_symlinks_reject(self):
        (self.root / '.env').write_text('OPENAI_API_KEY="${UNRELATED_SECRET}"\nOPENAI_IMAGE_MODEL=gpt-image-1-mini\n')
        with patch.dict(os.environ, {}, clear=True):
            config = ai.settings(self.root)
        self.assertEqual(config['key'], '${UNRELATED_SECRET}')
        self.assertNotIn('key', ai.public_settings(config))
        (self.root / '.env').unlink()
        (self.root / '.env').symlink_to(self.root / 'outside')
        with self.assertRaisesRegex(ai.AuthoringError, 'symlink'):
            ai.settings(self.root)

    def test_invalid_base_run_and_hash_change_cannot_prepare(self):
        folder = self.root / 'run'
        folder.mkdir()
        (folder / 'provenance.json').write_text(json.dumps({'base_manifest_sha256': 'wrong', 'status': 'raw_ready_for_conversion'}))
        # Validation happens before any converter invocation/import requirement.
        fake = type('Fake', (), {'convert_candidate': lambda *_: self.fail('Must not convert invalid raw')})()
        with patch.dict(sys.modules, {'ai_asset_conversion': fake}):
            with self.assertRaisesRegex(ai.AuthoringError, 'another base'):
                ai.prepare(folder, self.root)
        self.assertFalse((folder / 'candidate').exists())

    def test_decode_rejects_bad_dimensions_formats_and_fake_alpha(self):
        for data, background in [(b'not a png', 'opaque'), (self.png(), 'transparent')]:
            with self.assertRaises(ai.AuthoringError):
                ai.validate_raw(data, background)
        small = io.BytesIO()
        Image.new('RGBA', (64, 64)).save(small, format='PNG')
        with self.assertRaises(ai.AuthoringError):
            ai.validate_raw(small.getvalue(), 'transparent')


if __name__ == '__main__':
    unittest.main()
