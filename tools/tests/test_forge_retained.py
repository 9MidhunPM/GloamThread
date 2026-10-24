"""Offline reconstruction and failure-preserving publication of real retained art."""
from __future__ import annotations
import json
from pathlib import Path
import shutil
import tempfile
import unittest
from unittest.mock import patch
from tools.forge.content import rebuild as rebuild_content
from tools.forge.retained import publish_all,validate_sources
from tools.forge.rigs import write_json
from tools.forge.validation import BundleError,validate_bundle,sha256

ROOT=Path(__file__).resolve().parents[2]


class RetainedGenerationTests(unittest.TestCase):
    def setUp(self):
        self.work=tempfile.TemporaryDirectory();self.root=Path(self.work.name)
        target=self.root/'assets/arena/source';target.mkdir(parents=True)
        shutil.copytree(ROOT/'assets/arena/source/generated_kiln_fox',target/'generated_kiln_fox')
        shutil.copy2(ROOT/'assets/arena/source/retained_generations.json',target/'retained_generations.json')
    def tearDown(self):self.work.cleanup()
    def published_bytes(self):
        folder=self.root/'assets/arena/builtin/kiln-fox-ai'
        return {file.name:file.read_bytes() for file in folder.iterdir() if file.is_file()}
    def test_real_source_receipts_and_approved_manual_recipe_are_bound(self):
        checked=validate_sources(ROOT);self.assertEqual(len(checked),1);item=checked[0]
        self.assertEqual(item['manifest']['id'],'kiln-fox-ai');self.assertEqual(item['proposal']['name'],'Kiln Fox')
        self.assertEqual(item['generation']['provider'],'OpenAI')
        for request in item['generation']['requests'].values():
            self.assertEqual(request['model'],'gpt-image-1-mini');self.assertEqual(request['quality'],'low')
            self.assertEqual(request['automatic_retries'],0);self.assertTrue(request['received_at'])
        layout=json.loads((item['source']/'source_layout.json').read_text())
        self.assertEqual(layout['background_crop'],[0,140,576,324]);self.assertEqual(layout['alpha_cutoff'],192)
    def test_offline_publication_repeats_byte_for_byte_without_credentials(self):
        with patch('socket.create_connection',side_effect=AssertionError('Offline publisher attempted network')):
            self.assertEqual(publish_all(self.root),['kiln-fox-ai']);first=self.published_bytes()
            self.assertEqual(publish_all(self.root),['kiln-fox-ai']);self.assertEqual(self.published_bytes(),first)
        manifest=validate_bundle(self.root/'assets/arena/builtin/kiln-fox-ai');self.assertEqual(manifest['id'],'kiln-fox-ai')
        provenance=json.loads(first['provenance.json']);self.assertEqual(provenance['provider_calls_during_rebuild'],0)
        self.assertTrue(provenance['derived_generated_id'].startswith('kiln-fox-'))
        self.assertEqual(provenance['published_id'],'kiln-fox-ai');self.assertTrue(provenance['bake_sha256'])
        for value in first.values():self.assertNotIn(str(self.root).encode(),value)
    def test_tampered_raw_hash_preserves_published_bundle(self):
        publish_all(self.root);before=self.published_bytes()
        file=self.root/'assets/arena/source/generated_kiln_fox/raw_parts.png';file.write_bytes(b'invalid changed raw board')
        with self.assertRaisesRegex(BundleError,'hash differs'):publish_all(self.root)
        self.assertEqual(self.published_bytes(),before)
    def test_unlisted_edit_metadata_cannot_change_published_art(self):
        publish_all(self.root);before=self.published_bytes()
        source=self.root/'assets/arena/source/generated_kiln_fox'
        write_json(source/'rig_edits.json',{'schema_version':99,'unlisted':'must not be consumed'})
        (source/'parts/unlisted.txt').write_text('Unlisted source metadata is not a declared input.')
        publish_all(self.root);self.assertEqual(self.published_bytes(),before)
    def test_registry_cannot_introduce_arbitrary_source_paths(self):
        source=self.root/'assets/arena/source/generated_kiln_fox';manifest=json.loads((source/'manifest.json').read_text())
        manifest['files']['../../.env']='0'*64;write_json(source/'manifest.json',manifest)
        registry=json.loads((self.root/'assets/arena/source/retained_generations.json').read_text());registry['bundles'][0]['manifest_sha256']=sha256(source/'manifest.json');write_json(self.root/'assets/arena/source/retained_generations.json',registry)
        with self.assertRaisesRegex(BundleError,'allowlist'):validate_sources(self.root)
    def test_complete_rebuild_keeps_generated_third_and_default_players(self):
        shutil.copy2(ROOT/'assets/arena/source/builtin_profiles.json',self.root/'assets/arena/source/builtin_profiles.json')
        shutil.copy2(ROOT/'assets/arena/source/audio.json',self.root/'assets/arena/source/audio.json')
        (self.root/'assets/source/audio').mkdir(parents=True);shutil.copy2(ROOT/'assets/source/audio/instruments.json',self.root/'assets/source/audio/instruments.json')
        (self.root/'tools/gen').mkdir(parents=True);shutil.copy2(ROOT/'tools/gen/audio.py',self.root/'tools/gen/audio.py')
        result=rebuild_content(self.root);self.assertEqual(result['bundles'],3)
        index=json.loads((self.root/'assets/arena/builtin/index.json').read_text())
        self.assertEqual(index['bundles'],['cinderjack','thistlepaw','kiln-fox-ai'])
        self.assertEqual(index['default_players'],['kiln-fox-ai','thistlepaw'])
        before=self.published_bytes();rebuild_content(self.root);self.assertEqual(self.published_bytes(),before)

if __name__=='__main__':unittest.main()
