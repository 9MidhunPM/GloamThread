"""Scrolling-world authoring and original scenery validation, no broad rebuild."""
from __future__ import annotations
import copy
import json
from pathlib import Path
import tempfile
import unittest
from tools.forge.world import world_data,validate,rebuild as build_world
from tools.forge.scenery import validate as validate_scenery,rebuild as build_scenery
from tools.forge.validation import BundleError,sha256

ROOT=Path(__file__).resolve().parents[2]

class ScrollingWorldContentTests(unittest.TestCase):
    def test_four_templates_keep_main_ground_cave_entries_and_reachable_stairs(self):
        data=validate(world_data());self.assertEqual(data,json.loads((ROOT/'content/arena/world.json').read_text()))
        self.assertEqual(len(data['regions']),4)
        for region in data['regions']:
            self.assertEqual(sum(x['kind']=='cache' for x in region['loot']),4)
            self.assertEqual(sum(x['kind']=='plant' for x in region['loot']),2)
    def test_disconnected_and_outside_geometry_are_rejected(self):
        for mutate in [lambda x:x['templates'][0]['platforms'].remove([96,320,80]),lambda x:x['templates'][0]['platforms'].remove([112,416,48]),lambda x:x['templates'][0]['solids'].append([620,300,80,16]),lambda x:x['regions'][0]['loot'].pop()]:
            data=world_data();mutate(data)
            with self.assertRaises(BundleError):validate(data)
    def test_twenty_four_distinct_props_four_landmarks_and_four_layers(self):
        index=validate_scenery(ROOT);self.assertEqual(len(index['props']),24);self.assertEqual(len(index['landmarks']),4);self.assertEqual(len(index['layers']),4)
    def test_world_and_scenery_rebuild_deterministically_in_isolation(self):
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary);build_world(root);build_scenery(root)
            before={str(file.relative_to(root)):sha256(file) for file in root.rglob('*') if file.is_file()}
            build_world(root);build_scenery(root)
            self.assertEqual(before,{str(file.relative_to(root)):sha256(file) for file in root.rglob('*') if file.is_file()})
            image=root/'assets/arena/scenery/props.png';image.write_bytes(b'tampered')
            with self.assertRaises(BundleError):validate_scenery(root)

if __name__=='__main__':unittest.main()
