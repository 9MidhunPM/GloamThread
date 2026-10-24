"""Overhead content boundary and authored-route regressions, independent of art QA."""
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


def entity(data, key):
    return next(item for item in data['entities'] if item['id'] == key)


class ContentTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        shutil.copytree(ROOT / 'content', self.root / 'content')
        # Other lanes own production catalogs/art. Synthetic metadata isolates
        # this public validator until those overhead bundles are integrated.
        for name in ('profiles', 'themes', 'dialogue'):
            path = f'content/{name}.json'
            data = self.read(path)
            data['content_version'] = 'overhead-v1'
            if name == 'profiles': data['collider_contract'] = 'courier_overhead_v1'
            if name == 'themes': data['required_tile_slots'] = MODULE.TILE_IDS.copy()
            self.write(path, data)
        (self.root / 'assets/generated').mkdir(parents=True)
        assets = []
        for key, kind, count in [('fixed_tavi_v1', 'sprite_atlas', 128), ('fixed_neri_v1', 'sprite_atlas', 128),
                                 ('props_v1', 'sprite_atlas', 21), ('terrain_ember_v1', 'tile_atlas', 48),
                                 ('terrain_moss_v1', 'tile_atlas', 48)]:
            record = {'id': key, 'kind': kind, 'path': f'assets/generated/{key}.png', 'diagnostic': False,
                      'frames': [[0, 0, 16, 16] for _ in range(count)]}
            if kind == 'tile_atlas': record['tile_ids'] = MODULE.TILE_IDS.copy()
            assets.append(record)
        for theme in ('ember', 'moss'):
            for layer in ('far', 'middle', 'near'):
                key = f'background_{theme}_{layer}_v1'
                assets.append({'id': key, 'kind': 'image', 'path': f'assets/generated/{key}.png', 'diagnostic': False})
        assets.append({'id': 'font_v1', 'kind': 'font', 'path': 'assets/generated/font.fnt', 'diagnostic': False})
        (self.root / 'assets/generated/font.fnt').write_text('\n'.join(f'char id={code} x=0 y=0' for code in range(32, 127)))
        self.write('assets/manifest.json', {'schema_version': 1, 'content_version': 'overhead-v1', 'assets': assets})

    def tearDown(self):
        self.temp.cleanup()

    def read(self, path):
        return json.loads((self.root / path).read_text())

    def write(self, path, value):
        (self.root / path).write_text(json.dumps(value, indent=2) + '\n')

    def mutate(self, path, edit):
        data = self.read(path)
        edit(data)
        self.write(path, data)

    def paint(self, data, x, y, marker):
        row = list(data['tiles'][y]); row[x] = marker; data['tiles'][y] = ''.join(row)

    def assertInvalid(self, fragment):
        errors = MODULE.validate(self.root)
        self.assertTrue(any(fragment in error for error in errors), '\n'.join(errors))

    def test_authored_overhead_world_and_references_pass(self):
        self.assertEqual([], MODULE.validate(self.root))
        self.assertEqual(48, len(set(MODULE.TILE_IDS)))

    def test_side_view_version_and_diagnostic_stage_are_not_accepted(self):
        self.mutate('content/rooms/r00.json', lambda d: d.__setitem__('content_version', 'phase1-v1'))
        self.assertInvalid('content_version must be overhead-v1')
        self.assertIn('requires full', MODULE.validate(self.root, 'diagnostic')[0])

    def test_fractional_boolean_and_string_spawn_coordinates_are_rejected(self):
        for value in (7.5, True, '7'):
            with self.subTest(value=value):
                self.mutate('content/rooms/r00.json', lambda d: d['spawns']['start'][0].__setitem__(0, value))
                self.assertInvalid('tile must contain two integers')

    def test_water_wall_and_hazard_are_not_safe_spawns(self):
        path = 'content/rooms/r00.json'
        original = self.read(path)
        for marker in '~#^':
            with self.subTest(marker=marker):
                data = deepcopy(original)
                self.paint(data, 7, 15, marker)
                self.write(path, data)
                self.assertInvalid('unsafe spawn')

    def test_adjacent_overhead_walls_do_not_invent_platform_headroom_rules(self):
        self.mutate('content/rooms/r00.json', lambda d: self.paint(d, 7, 14, '#'))
        self.mutate('content/rooms/r00.json', lambda d: self.paint(d, 7, 16, '#'))
        self.assertEqual([], MODULE.validate(self.root))

    def test_paired_spawns_must_be_distinct(self):
        self.mutate('content/rooms/r00.json', lambda d: d['spawns']['start'].__setitem__(1, d['spawns']['start'][0]))
        self.assertInvalid('spawn footprints must be distinct')

    def test_room_dimensions_and_unknown_tiles_fail(self):
        self.mutate('content/rooms/r00.json', lambda d: d['tiles'].__setitem__(0, 'x' * 48))
        self.assertInvalid('unknown tile character')
        self.mutate('content/rooms/r00.json', lambda d: d['tiles'].__setitem__(0, '.' * 29))
        self.assertInvalid('rectangular')
        self.assertInvalid('room dimensions')

    def test_rally_rectangles_require_safe_capacity_and_bounds(self):
        path = 'content/rooms/r00.json'
        original = self.read(path)
        for rect in ([47, 13, 4, 5], [43, 13, 3.5, 4], [43, 13, 1, 1], [29, 5, 4, 4]):
            with self.subTest(rect=rect):
                data = deepcopy(original); entity(data, 'to_atrium')['rect'] = rect
                self.write(path, data); self.assertInvalid('rect')

    def test_cross_room_and_checkpoint_entrances_never_fall_back(self):
        self.mutate('content/rooms/r00.json', lambda d: entity(d, 'to_atrium').__setitem__('target_entrance', 'missing'))
        self.assertInvalid('target entrance does not resolve')
        self.mutate('content/rooms/r00.json', lambda d: entity(d, 'rest_lantern').__setitem__('entrance', 'missing'))
        self.assertInvalid('checkpoint entrance does not resolve')

    def test_intro_and_team_unlock_gates_match_the_world(self):
        self.mutate('content/rooms/r00.json', lambda d: entity(d, 'to_atrium').__setitem__('requires_all', []))
        self.assertInvalid('exit progression gate differs')
        self.mutate('content/world.json', lambda d: d['connections'][6].__setitem__('requires_all', []))
        self.assertInvalid('wrong progression connection or gate')
        self.mutate('content/world.json', lambda d: d['rooms'][5].__setitem__('challenge_rewards', ['threadstep']))
        self.assertInvalid('wrong challenge rewards')

    def test_world_requires_both_rally_directions(self):
        self.mutate('content/rooms/r00.json', lambda d: d['entities'].remove(entity(d, 'to_atrium')))
        self.assertInvalid('every graph connection needs both directed rally exits')

    def test_named_bridge_must_cover_water_not_wall_or_floor(self):
        for marker in '#.=':
            with self.subTest(marker=marker):
                self.mutate('content/rooms/r02.json', lambda d: self.paint(d, 28, 13, marker))
                self.assertInvalid('bridge span must cover water')

    def test_repairs_need_four_tile_spans_and_cannot_be_dash_shortcuts(self):
        self.mutate('content/rooms/r02.json', lambda d: entity(d, 'spindle_pair')['bridge_rect'].__setitem__(2, 3))
        self.assertInvalid('at least four water tiles')

    def test_both_anchors_have_safe_approaches_before_restoration(self):
        self.mutate('content/rooms/r02.json', lambda d: entity(d, 'spindle_pair')['anchors'][1].__setitem__('tile', [34, 9]))
        self.assertInvalid('approaches before restoration')

    def test_authored_dry_bypass_of_paired_repair_is_rejected(self):
        def bypass(data):
            for x in range(28, 32): self.paint(data, x, 2, '=')
        self.mutate('content/rooms/r02.json', bypass)
        self.assertInvalid('walking or Threadstep bypass')

    def test_required_dash_branch_cannot_be_replaced_with_walls(self):
        def close(data):
            data['tiles'] = [row.replace('~', '#') for row in data['tiles']]
        self.mutate('content/rooms/r01.json', close)
        self.assertInvalid('disconnected after all room routes open')

    def test_required_dash_lesson_cannot_be_replaced_with_dry_floor(self):
        def bypass(data):
            data['tiles'] = [row.replace('~', '.') for row in data['tiles']]
        self.mutate('content/rooms/r01.json', bypass)
        self.assertInvalid('Threadstep lesson must require crossing water')

    def test_rally_zone_must_be_physically_reachable(self):
        def isolate(data):
            entity(data, 'to_atrium')['rect'] = [30, 6, 4, 3]
            for y in range(6, 9):
                for x in range(30, 34): self.paint(data, x, y, '.')
            for y in range(5, 10):
                for x in range(29, 35):
                    if y in (5, 9) or x in (29, 34): self.paint(data, x, y, '#')
        self.mutate('content/rooms/r00.json', isolate)
        self.assertInvalid('rally zone needs two safely reachable standing cells')

    def test_duplicate_entities_nested_ids_and_coordinates_fail(self):
        self.mutate('content/rooms/r00.json', lambda d: entity(d, 'oru').__setitem__('id', 'rest_lantern'))
        self.assertInvalid('duplicate entity id')
        self.mutate('content/rooms/r02.json', lambda d: entity(d, 'spindle_pair')['anchors'][1].__setitem__('id', 'spindle_west'))
        self.assertInvalid('duplicate interaction id')
        self.mutate('content/rooms/r02.json', lambda d: entity(d, 'spindle_pair')['anchors'][1].__setitem__('tile', [24, 9]))
        self.assertInvalid('must be distinct')

    def test_unknown_executable_fields_and_entity_types_fail(self):
        self.mutate('content/rooms/r00.json', lambda d: entity(d, 'oru').__setitem__('script', 'res://evil.gd'))
        self.assertInvalid('unexpected or missing entity fields')
        self.mutate('content/rooms/r00.json', lambda d: entity(d, 'oru').__setitem__('type', ['npc']))
        self.assertInvalid('unknown entity type')

    def test_fixed_profiles_keep_overhead_collider_and_abilities(self):
        self.mutate('content/profiles.json', lambda d: d.__setitem__('collider_contract', 'courier_v1'))
        self.assertInvalid('courier_overhead_v1')
        self.mutate('content/profiles.json', lambda d: d['profiles'][0].__setitem__('special_id', 'flight'))
        self.assertInvalid('fixed profile requires')

    def test_old_terrain_mapping_cannot_pass_as_overhead(self):
        self.mutate('content/themes.json', lambda d: d['required_tile_slots'].__setitem__(0, 'solid_fill'))
        self.assertInvalid('ordered 48 terrain slots')

    def test_missing_duplicate_and_diagnostic_assets_fail(self):
        original = self.read('assets/manifest.json')
        self.mutate('assets/manifest.json', lambda d: d['assets'].pop(0))
        self.assertInvalid('unresolved asset fixed_tavi_v1')
        self.write('assets/manifest.json', original)
        self.mutate('assets/manifest.json', lambda d: d['assets'].append(deepcopy(d['assets'][0])))
        self.assertInvalid('duplicate asset id')
        self.mutate('assets/manifest.json', lambda d: d['assets'][1].__setitem__('diagnostic', True))
        self.assertInvalid('cannot consume a diagnostic asset')

    def test_unsafe_asset_paths_and_decor_gameplay_fields_fail(self):
        original = self.read('assets/manifest.json')
        for value in ('../outside.png', '/tmp/outside.png', 'https://example.test/art.png', 'assets/generated/../../evil.gd', 'assets\\generated\\escape.png', 'assets/generated/script.gd', 'assets/generated/a\x00.png'):
            with self.subTest(value=value):
                data = deepcopy(original); data['assets'][0]['path'] = value
                self.write('assets/manifest.json', data); self.assertInvalid('unsafe asset path')
        self.mutate('content/rooms/r00.json', lambda d: d['decor'][0].__setitem__('damage', 5))
        self.assertInvalid('requires asset_id/frame/position_px/theme/z only')

    def test_decor_frame_and_font_glyph_references_are_checked(self):
        self.mutate('content/rooms/r00.json', lambda d: d['decor'][0].__setitem__('frame', 999))
        self.assertInvalid('frame out of bounds')
        self.mutate('content/dialogue.json', lambda d: d['sequences']['oru_return'][0].__setitem__('text', 'Welcome — home.'))
        self.assertInvalid('printable ASCII')
        (self.root / 'assets/generated/font.fnt').write_text('char id=32 x=0 y=0\n')
        self.assertInvalid('all 95 printable ASCII glyphs')

    def test_missing_files_and_duplicate_json_keys_are_not_silent(self):
        (self.root / 'content/dialogue.json').unlink()
        self.assertInvalid('content/dialogue.json')
        (self.root / 'content/profiles.json').write_text('{"schema_version":1,"schema_version":2}')
        self.assertInvalid('duplicate JSON key')

    def test_malformed_spawn_map_fails_without_reference_crash(self):
        self.mutate('content/rooms/r00.json', lambda d: d.__setitem__('spawns', None))
        self.assertInvalid('must map entrance ids to pairs')
        self.assertInvalid('target entrance does not resolve')

    def test_full_world_requires_water_bridge_and_hazard_materials(self):
        for path in (self.root / 'content/rooms').glob('*.json'):
            data = json.loads(path.read_text()); data['tiles'] = [row.replace('^', '.') for row in data['tiles']]
            path.write_text(json.dumps(data))
        self.assertInvalid('water, dry bridges and walkable hazards')

    def test_both_distinct_bridge_rooms_are_required(self):
        r02 = self.read('content/rooms/r02.json')
        extra = deepcopy(entity(r02, 'spindle_pair'))
        extra['id'] = 'duplicate_bridge'
        extra['anchors'][0]['id'] = 'other_west'; extra['anchors'][1]['id'] = 'other_east'
        r02['entities'].append(extra); self.write('content/rooms/r02.json', r02)
        self.mutate('content/rooms/r06.json', lambda d: d['entities'].remove(entity(d, 'causeway_pair')))
        self.assertInvalid('one bridge_spindle in r02 and one bridge_causeway in r06')


if __name__ == '__main__':
    unittest.main()
