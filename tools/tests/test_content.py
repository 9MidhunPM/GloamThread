"""Public content-validator scenarios; synthetic manifests isolate reference rules."""
from __future__ import annotations

from copy import deepcopy
import importlib.util
import json
from pathlib import Path
import shutil
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('validate_content', ROOT / 'tools' / 'validate_content.py')
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class ContentTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        shutil.copytree(ROOT / 'content', self.root / 'content')
        (self.root / 'assets' / 'generated').mkdir(parents=True)
        # Data-only records are intentional here: image/audio structure belongs to
        # validate_assets.py. These tests exercise actual public content validation.
        assets = []
        for asset_id, kind, frames in [
            ('fixed_tavi_v1', 'sprite_atlas', 32), ('fixed_neri_v1', 'sprite_atlas', 32),
            ('diagnostic_terrain_v1', 'tile_atlas', 48), ('diagnostic_mover_v1', 'sprite_atlas', 1),
            ('props_v1', 'sprite_atlas', 16), ('terrain_ember_v1', 'tile_atlas', 48),
            ('terrain_moss_v1', 'tile_atlas', 48),
        ]:
            record = {'id': asset_id, 'kind': kind, 'path': f'assets/generated/{asset_id}.png',
                      'diagnostic': False, 'frames': [[0, 0, 16, 16] for _ in range(frames)]}
            if kind == 'tile_atlas':
                record['tile_ids'] = MODULE.TILE_IDS
            assets.append(record)
        for theme in ('ember', 'moss'):
            for layer in ('far', 'middle', 'near'):
                asset_id = f'background_{theme}_{layer}_v1'
                assets.append({'id': asset_id, 'kind': 'image', 'path': f'assets/generated/{asset_id}.png', 'diagnostic': False})
        assets.append({'id': 'font_v1', 'kind': 'font', 'path': 'assets/generated/font.fnt', 'diagnostic': False})
        (self.root / 'assets' / 'generated' / 'font.fnt').write_text('\n'.join(f'char id={code} x=0 y=0' for code in range(32, 127)))
        self.write('assets/manifest.json', {'schema_version': 1, 'content_version': 'phase1-v1', 'assets': assets})

    def tearDown(self):
        self.temp.cleanup()

    def read(self, path):
        return json.loads((self.root / path).read_text())

    def write(self, path, value):
        (self.root / path).write_text(json.dumps(value, indent=2) + '\n')

    def mutate(self, path, edit):
        value = self.read(path)
        edit(value)
        self.write(path, value)

    def assertInvalid(self, fragment, stage='full'):
        errors = MODULE.validate(self.root, stage)
        self.assertTrue(any(fragment in error for error in errors), '\n'.join(errors))

    def diagnostic(self):
        for path in (self.root / 'content' / 'rooms').glob('*.json'):
            path.unlink()
        shutil.copyfile(ROOT / 'tests/contracts/content_valid_r00.json', self.root / 'content/rooms/r00.json')

    def test_authored_full_data_passes_structural_checks(self):
        self.assertEqual([], MODULE.validate(self.root))

    def test_diagnostic_scope_is_explicit_and_cannot_pass_as_full(self):
        self.diagnostic()
        self.assertEqual([], MODULE.validate(self.root, 'diagnostic'))
        self.assertInvalid('full stage requires room files')
        self.assertInvalid('diagnostic_mover is forbidden')

    def test_fractional_and_boolean_spawn_coordinates_are_rejected(self):
        for value in (6.5, True, '6'):
            with self.subTest(value=value):
                self.mutate('content/rooms/r00.json', lambda d: d['spawns']['start'][0].__setitem__(0, value))
                self.assertInvalid('tile must contain two integers')

    def test_missing_and_duplicate_entity_ids_are_rejected(self):
        for key in (None, 'rest_lantern'):
            with self.subTest(key=key):
                self.mutate('content/rooms/r00.json', lambda d: d['entities'][1].__setitem__('id', key))
                self.assertInvalid('identifier' if key is None else 'duplicate entity id')

    def test_spawn_headroom_and_support_are_required(self):
        path = 'content/rooms/r00.json'
        original = self.read(path)
        for y, marker in ((18, '#'), (18, '^'), (18, '='), (20, '.')):
            with self.subTest(y=y, marker=marker):
                data = deepcopy(original)
                row = list(data['tiles'][y]); row[6] = marker; data['tiles'][y] = ''.join(row)
                self.write(path, data)
                self.assertInvalid('unsafe spawn')

    def test_spawn_pair_must_be_distinct(self):
        self.mutate('content/rooms/r00.json', lambda d: d['spawns']['start'].__setitem__(1, [6, 19]))
        self.assertInvalid('spawn footprints must be distinct')

    def test_invalid_room_dimensions_and_characters_fail(self):
        self.mutate('content/rooms/r00.json', lambda d: d['tiles'].__setitem__(0, 'x' * 60))
        self.assertInvalid('unknown tile character')
        self.mutate('content/rooms/r00.json', lambda d: d['tiles'].__setitem__(0, '.' * 29))
        self.assertInvalid('rectangular')
        self.assertInvalid('room dimensions')

    def test_out_of_bounds_and_fractional_rectangles_fail(self):
        for value in ([55, 18, 8, 2], [1, 18, 3.5, 2], [1, 18, -3, 2]):
            with self.subTest(value=value):
                self.mutate('content/rooms/r00.json', lambda d: d['entities'][2].__setitem__('rect', value))
                self.assertInvalid('rect')

    def test_missing_entrance_reference_is_not_a_start_fallback(self):
        self.mutate('content/rooms/r00.json', lambda d: d['entities'][2].__setitem__('target_entrance', 'missing'))
        self.assertInvalid('target entrance does not resolve')

    def test_exit_gate_must_match_world_graph(self):
        self.mutate('content/rooms/r02.json', lambda d: d['entities'][2].__setitem__('requires_all', []))
        self.assertInvalid('exit progression gate differs')

    def test_world_cannot_bypass_dash_or_boss_rewards(self):
        self.mutate('content/world.json', lambda d: d['connections'][6].__setitem__('requires_all', []))
        self.assertInvalid('wrong progression connection or gate')
        self.mutate('content/world.json', lambda d: d['rooms'][5].__setitem__('challenge_rewards', ['threadstep']))
        self.assertInvalid('wrong challenge rewards')

    def test_graph_requires_both_directed_exits(self):
        self.mutate('content/rooms/r00.json', lambda d: d['entities'].pop(2))
        self.assertInvalid('every graph connection needs both directed rally exits')

    def test_bridge_span_cannot_be_already_solid(self):
        def edit(data):
            row = list(data['tiles'][17]); row[40] = '#'; data['tiles'][17] = ''.join(row)
        self.mutate('content/rooms/r02.json', edit)
        self.assertInvalid('bridge span must be empty')

    def test_anchors_need_distinct_ids_positions_and_supported_approaches(self):
        path = 'content/rooms/r02.json'
        original = self.read(path)
        for field, value, message in [('id', 'spindle_west', 'duplicate interaction id'), ('tile', [31, 16], 'must be distinct'), ('tile', [45, 16], 'supported empty approach')]:
            with self.subTest(field=field, value=value):
                data = deepcopy(original); data['entities'][0]['anchors'][1][field] = value
                self.write(path, data); self.assertInvalid(message)

    def test_room_schema_and_unknown_entity_type_fail_without_exceptions(self):
        self.mutate('content/rooms/r00.json', lambda d: d.__setitem__('schema_version', 2))
        self.assertInvalid('schema_version')
        self.mutate('content/rooms/r00.json', lambda d: d['entities'][0].__setitem__('type', ['checkpoint']))
        self.assertInvalid('unknown entity type')

    def test_unknown_executable_entity_fields_fail(self):
        self.mutate('content/rooms/r00.json', lambda d: d['entities'][0].__setitem__('script', 'res://evil.gd'))
        self.assertInvalid('unexpected or missing entity fields')

    def test_fixed_profiles_cannot_change_abilities_or_collider(self):
        self.mutate('content/profiles.json', lambda d: d['profiles'][0].__setitem__('special_id', 'flight'))
        self.assertInvalid('fixed profile requires')
        self.mutate('content/profiles.json', lambda d: d.__setitem__('collider_contract', 'giant'))
        self.assertInvalid('collider_contract')

    def test_missing_duplicate_and_diagnostic_asset_ids_fail(self):
        original = self.read('assets/manifest.json')
        self.mutate('assets/manifest.json', lambda d: d['assets'].pop(0))
        self.assertInvalid('unresolved asset fixed_tavi_v1')
        self.write('assets/manifest.json', original)
        self.mutate('assets/manifest.json', lambda d: d['assets'].append(deepcopy(d['assets'][0])))
        self.assertInvalid('duplicate asset id')
        self.mutate('assets/manifest.json', lambda d: d['assets'][1].__setitem__('diagnostic', True))
        self.assertInvalid('cannot consume a diagnostic asset')

    def test_unsafe_asset_paths_fail(self):
        original = self.read('assets/manifest.json')
        for value in ('../outside.png', '/tmp/outside.png', 'https://example.test/art.png', 'assets/generated/../../evil.gd', 'assets\\generated\\escape.png', 'assets/generated/script.gd', 'assets/generated/a\x00.png'):
            with self.subTest(value=value):
                data = deepcopy(original); data['assets'][0]['path'] = value
                self.write('assets/manifest.json', data); self.assertInvalid('unsafe asset path')

    def test_invalid_decor_frame_and_gameplay_fields_fail(self):
        self.mutate('content/rooms/r00.json', lambda d: d['decor'][0].__setitem__('frame', 99))
        self.assertInvalid('frame out of bounds')
        self.mutate('content/rooms/r00.json', lambda d: d['decor'][1].__setitem__('damage', 5))
        self.assertInvalid('requires asset_id/frame/position_px/theme/z only')

    def test_unsupported_dialogue_glyph_and_missing_font_glyph_fail(self):
        self.mutate('content/dialogue.json', lambda d: d['sequences']['oru_return'][0].__setitem__('text', 'Welcome — home.'))
        self.assertInvalid('printable ASCII')
        (self.root / 'assets/generated/font.fnt').write_text('char id=32 x=0 y=0\n')
        self.assertInvalid('all 95 printable ASCII glyphs')

    def test_duplicate_json_object_keys_fail(self):
        (self.root / 'content/profiles.json').write_text('{"schema_version":1,"schema_version":2}')
        self.assertInvalid('duplicate JSON key')

    def test_missing_content_file_fails(self):
        (self.root / 'content/dialogue.json').unlink()
        self.assertInvalid('content/dialogue.json')

    def test_checkpoint_entrance_must_resolve(self):
        self.mutate('content/rooms/r00.json', lambda d: d['entities'][0].__setitem__('entrance', 'missing'))
        self.assertInvalid('checkpoint entrance does not resolve')

    def test_malformed_spawn_maps_fail_without_crashing_exit_resolution(self):
        self.mutate('content/rooms/r00.json', lambda d: d.__setitem__('spawns', None))
        self.assertInvalid('must map entrance ids to pairs')
        self.assertInvalid('target entrance does not resolve')

    def test_rally_zone_contains_feet_inside_its_exclusive_bottom(self):
        self.mutate('content/rooms/r00.json', lambda d: d['entities'][2]['rect'].__setitem__(3, 2))
        self.assertInvalid('rally zone needs two safe standing tiles')

    def test_full_authored_rooms_include_one_way_and_hazard_geometry(self):
        for room in (self.root / 'content/rooms').glob('*.json'):
            data = json.loads(room.read_text())
            data['tiles'] = [row.replace('^', '.') for row in data['tiles']]
            room.write_text(json.dumps(data))
        self.assertInvalid('both one-way surfaces and authored hazards')

    def test_shared_contract_fixtures_exercise_same_public_validator(self):
        self.diagnostic()
        shutil.copyfile(ROOT / 'tests/contracts/content_invalid_fractional_spawn.json', self.root / 'content/rooms/r00.json')
        self.assertInvalid('tile must contain two integers', stage='diagnostic')
        for path in (ROOT / 'content/rooms').glob('*.json'):
            shutil.copyfile(path, self.root / 'content/rooms' / path.name)
        shutil.copyfile(ROOT / 'tests/contracts/content_invalid_missing_entrance.json', self.root / 'content/rooms/r00.json')
        self.assertInvalid('target entrance does not resolve')

    def test_both_distinct_bridge_rooms_are_required(self):
        r02 = self.read('content/rooms/r02.json')
        extra = deepcopy(r02['entities'][0])
        extra['id'] = 'duplicate_bridge'
        extra['anchors'][0]['id'] = 'other_west'
        extra['anchors'][1]['id'] = 'other_east'
        r02['entities'].append(extra)
        self.write('content/rooms/r02.json', r02)
        self.mutate('content/rooms/r06.json', lambda d: d['entities'].pop(0))
        self.assertInvalid('one bridge_spindle in r02 and one bridge_causeway in r06')


if __name__ == '__main__':
    unittest.main()
