#!/usr/bin/env python3
"""Validate authored Phase 1 data. Structural checks do not prove traversal or fun."""
from __future__ import annotations

import argparse
import json
from pathlib import Path, PurePosixPath
import re
import sys
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
ROOM_NAMES = ['Lantern Rest', 'Mossfoot Atrium', 'Spindle Steps', 'Glasswing Gallery',
              "Warden's Landing", 'Broken Bell', 'Severed Causeway', 'Lantern Loom']
ROOM_IDS = tuple(f'r{i:02}' for i in range(8))
REWARDS = {'r02': ['bridge_spindle'], 'r05': ['boss_spoolwarden', 'threadstep', 'shortcut_bell'],
           'r06': ['bridge_causeway'], 'r07': ['loom_restored']}
EDGES = {('r00', 'r01'): [], ('r01', 'r02'): [], ('r02', 'r03'): ['bridge_spindle'],
         ('r03', 'r04'): [], ('r04', 'r05'): [], ('r01', 'r05'): ['shortcut_bell'],
         ('r01', 'r06'): ['threadstep'], ('r06', 'r07'): ['bridge_causeway'],
         ('r00', 'r07'): ['loom_restored']}
TILE_IDS = ['solid_fill', 'solid_top', 'one_way_middle', 'hazard_middle']
for _base in ('solid_fill', 'solid_top'):
    TILE_IDS += [f'{_base}_{i}' for i in range(2, 5)]
for _base in ('solid_bottom', 'solid_left', 'solid_right'):
    TILE_IDS += [_base] + [f'{_base}_{i}' for i in range(2, 5)]
TILE_IDS += [f'corner_{kind}_{corner}' for kind in ('outer', 'inner') for corner in ('tl', 'tr', 'bl', 'br')]
TILE_IDS += [f'{kind}_{part}' for kind in ('one_way', 'hazard') for part in ('left', 'right', 'single')]
TILE_IDS += [f'bridge_{part}' for part in ('left', 'middle', 'right', 'single')]
TILE_IDS += [f'seam_{part}' for part in ('horizontal', 'vertical', 'cross', 'knot')]
TILE_IDS += [f'background_{part}' for part in ('stone', 'brass', 'root', 'cloth')]
FIELDS = {
    'diagnostic_mover': {'tile', 'range_tiles'},
    'spoolmite': {'tile'}, 'wickwing': {'tile'}, 'spoolwarden': {'tile'},
    'exit': {'rect', 'target_room', 'target_entrance', 'requires_all'},
    'checkpoint': {'tile', 'checkpoint_id', 'entrance'},
    'anchor_pair': {'anchors', 'bridge_rect', 'flag'},
    'npc': {'tile', 'character_id', 'dialogue_id', 'restored_dialogue_id'},
    'secret': {'tile', 'flag'}, 'loom': {'stations', 'flag'},
}
IDENTIFIER = re.compile(r'[a-z][a-z0-9_]*\Z')


class Checks:
    def __init__(self, root: Path, stage: str):
        self.root = root.resolve()
        self.stage = stage
        self.errors: list[str] = []
        self.assets: dict[str, dict] = {}
        self.text: list[tuple[str, str]] = []
        self.sequences: set[str] = set()

    def need(self, condition: bool, where: str, message: str) -> bool:
        if not condition:
            self.errors.append(f'{where}: {message}')
        return condition

    def load(self, relative: str) -> dict:
        try:
            # Duplicate object keys must not silently replace authored data.
            def pairs(items):
                result = {}
                for key, value in items:
                    if key in result:
                        raise ValueError(f'duplicate JSON key {key!r}')
                    result[key] = value
                return result
            data = json.loads((self.root / relative).read_text(encoding='utf-8'), object_pairs_hook=pairs)
        except (OSError, ValueError) as exc:
            self.errors.append(f'{relative}: {exc}')
            return {}
        if not self.need(isinstance(data, dict), relative, 'must be a JSON object'):
            return {}
        self.need(type(data.get('schema_version')) is int and data['schema_version'] == 1,
                  relative, 'schema_version must be integer 1')
        self.need('example_only' not in data, relative, 'example_only is not shipped content')
        return data

    def version(self, data: dict, where: str):
        self.need(data.get('content_version') == 'phase1-v1', where, 'content_version must be phase1-v1')

    def identifier(self, value: Any, where: str) -> bool:
        return self.need(isinstance(value, str) and IDENTIFIER.fullmatch(value) is not None,
                         where, 'must be a nonempty lowercase identifier')

    def string(self, value: Any, where: str, empty: bool = False) -> bool:
        ok = isinstance(value, str) and (empty or bool(value.strip()))
        if not self.need(ok, where, 'must be a nonempty string' if not empty else 'must be a string'):
            return False
        self.need(all(32 <= ord(char) <= 126 for char in value), where, 'requires printable ASCII glyphs')
        self.text.append((where, value))
        return True

    def asset(self, value: Any, where: str, kinds: tuple[str, ...] = ()) -> dict:
        if not self.identifier(value, where):
            return {}
        record = self.assets.get(value)
        if not self.need(record is not None, where, f'unresolved asset {value}'):
            return {}
        if kinds:
            self.need(record.get('kind') in kinds, where, f'asset kind must be one of {kinds}')
        if self.stage == 'full':
            self.need(record.get('diagnostic') is False, where, 'full content cannot consume a diagnostic asset')
        return record

    def local_path(self, value: Any, where: str) -> Path | None:
        if not isinstance(value, str):
            self.need(False, where, 'asset path must be a string')
            return None
        path = PurePosixPath(value)
        safe = (not path.is_absolute() and not any(part in ('', '.', '..') for part in value.split('/'))
                and '\\' not in value and ':' not in value and path.parts[:2] == ('assets', 'generated'))
        full = (self.root / value).resolve()
        safe = safe and full.is_relative_to(self.root / 'assets' / 'generated')
        if not self.need(safe, where, 'unsafe asset path; expected assets/generated/...'):
            return None
        return full


def _manifest(c: Checks):
    data = c.load('assets/manifest.json')
    c.version(data, 'assets/manifest.json')
    records = data.get('assets')
    if not c.need(isinstance(records, list), 'assets/manifest.json/assets', 'must be an array'):
        return
    for index, record in enumerate(records):
        where = f'assets/manifest.json/assets/{index}'
        if not c.need(isinstance(record, dict), where, 'must be an object'):
            continue
        if c.identifier(record.get('id'), where + '/id'):
            key = record['id']
            c.need(key not in c.assets, where + '/id', f'duplicate asset id {key}')
            c.assets[key] = record
        c.local_path(record.get('path'), where + '/path')


def _profiles(c: Checks):
    where = 'content/profiles.json'
    data = c.load(where)
    c.version(data, where)
    c.need(data.get('collider_contract') == 'courier_v1', where, 'collider_contract must be courier_v1')
    c.need(data.get('required_team_unlocks_are_separate') is True, where, 'team traversal must remain separate')
    records = data.get('profiles')
    if not c.need(isinstance(records, list), where + '/profiles', 'must be an array'):
        return
    expected = {
        'tavi_fixed': ('Tavi', 'fixed_tavi_v1', 5, 'ember_arc', 'ember'),
        'neri_fixed': ('Neri', 'fixed_neri_v1', 4, 'spore_bolt', 'moss'),
    }
    seen = set()
    for index, record in enumerate(records):
        at = f'{where}/profiles/{index}'
        if not c.need(isinstance(record, dict), at, 'must be an object'):
            continue
        key = record.get('id')
        if not c.need(isinstance(key, str) and key in expected, at + '/id', 'unknown fixed profile'):
            continue
        c.need(key not in seen, at, 'duplicate profile id')
        seen.add(key)
        fields = ('display_name', 'visual_bundle_id', 'max_hearts', 'special_id', 'theme_id')
        c.need(set(record) == {'id', *fields}, at, 'unexpected or missing fixed profile fields')
        for field, value in zip(fields, expected[key]):
            c.need(record.get(field) == value and (field != 'max_hearts' or type(record.get(field)) is int),
                   at + '/' + field, f'fixed profile requires {value!r}')
        c.string(record.get('display_name'), at + '/display_name')
        c.asset(record.get('visual_bundle_id'), at + '/visual_bundle_id', ('sprite_atlas',))
    c.need(seen == set(expected) and len(records) == 2, where, 'exactly Tavi and Neri are required')


def _themes(c: Checks):
    where = 'content/themes.json'
    data = c.load(where)
    c.version(data, where)
    c.need(data.get('geometry_source') == 'canonical_room_data', where, 'geometry must be canonical_room_data')
    c.need(data.get('tile_size') == [16, 16], where, 'tile_size must be [16,16]')
    c.need(data.get('required_tile_slots') == TILE_IDS, where, 'requires the exact ordered 48 terrain slots')
    records = data.get('themes')
    if not c.need(isinstance(records, list), where + '/themes', 'must be an array'):
        return
    seen = set()
    for index, record in enumerate(records):
        at = f'{where}/themes/{index}'
        if not c.need(isinstance(record, dict), at, 'must be an object'):
            continue
        key = record.get('id')
        if not c.need(isinstance(key, str) and key in ('ember', 'moss'), at + '/id', 'unknown theme'):
            continue
        c.need(key not in seen, at, 'duplicate theme id')
        seen.add(key)
        c.need(record.get('visibility_bit') == {'ember': 2, 'moss': 4}[key], at, 'incorrect visibility bit')
        palette = record.get('palette')
        c.need(isinstance(palette, list) and len(palette) == 15 and all(isinstance(x, str) and re.fullmatch(r'#[0-9A-Fa-f]{6}', x) for x in palette),
               at + '/palette', 'requires 15 RGB palette colours')
        c.need(record.get('critical_cues') == 'common_shapes_and_contrast', at, 'critical cue grammar must be shared')
        c.need(record.get('terrain_asset_id') == f'terrain_{key}_v1', at, 'unexpected terrain asset id')
        backgrounds = [f'background_{key}_{layer}_v1' for layer in ('far', 'middle', 'near')]
        c.need(record.get('background_asset_ids') == backgrounds, at, 'requires far/middle/near background IDs')
        if c.stage == 'full':
            terrain = c.asset(record.get('terrain_asset_id'), at + '/terrain_asset_id', ('tile_atlas',))
            c.need(terrain.get('tile_ids') == TILE_IDS, at, 'terrain frame order must match required_tile_slots')
            for asset_id in backgrounds:
                c.asset(asset_id, at + '/background_asset_ids', ('image',))
    c.need(seen == {'ember', 'moss'} and len(records) == 2, where, 'requires exactly Ember and Moss')


def _dialogue(c: Checks):
    where = 'content/dialogue.json'
    data = c.load(where)
    c.version(data, where)
    records = data.get('sequences')
    if not c.need(isinstance(records, dict), where + '/sequences', 'must be an object'):
        return
    c.sequences = set(records)
    c.need({'oru_intro', 'oru_return', 'bridge_spindle_complete', 'boss_defeated', 'ending'} <= c.sequences,
           where, 'missing required dialogue sequence')
    for key, lines in records.items():
        at = where + '/sequences/' + key
        c.identifier(key, at)
        if not c.need(isinstance(lines, list) and bool(lines), at, 'must be a nonempty array'):
            continue
        for index, line in enumerate(lines):
            item_at = f'{at}/{index}'
            if not c.need(isinstance(line, dict) and set(line) == {'speaker', 'text'}, item_at, 'requires speaker and text'):
                continue
            c.need(line['speaker'] in ('', 'Tavi', 'Neri', 'Oru'), item_at + '/speaker', 'unknown speaker')
            c.string(line['speaker'], item_at + '/speaker', empty=True)
            c.string(line['text'], item_at + '/text')
            c.need(isinstance(line['text'], str) and len(line['text']) <= 150, item_at + '/text', 'keep each dialogue line at most 150 characters')


def _room(c: Checks, data: dict, where: str) -> bool:
    c.need(set(data) == {'schema_version', 'id', 'name', 'tiles', 'spawns', 'entities', 'decor'}, where, 'unexpected or missing room fields')
    c.identifier(data.get('id'), where + '/id')
    c.string(data.get('name'), where + '/name')
    rows = data.get('tiles')
    if not c.need(isinstance(rows, list) and bool(rows) and all(isinstance(row, str) for row in rows), where + '/tiles', 'must be nonempty string rows'):
        return False
    width, height = len(rows[0]), len(rows)
    rectangular = all(len(row) == width for row in rows)
    c.need(rectangular, where + '/tiles', 'tile rows must be rectangular')
    c.need(30 <= width <= 90 and 23 <= height <= 30, where + '/tiles', 'room dimensions must be 30..90 by 23..30')
    c.need(all(char in '#=.^' for row in rows for char in row), where + '/tiles', 'unknown tile character')
    if not rectangular:
        return False

    def tile(value, at):
        ok = isinstance(value, list) and len(value) == 2 and all(type(v) is int for v in value)
        if not c.need(ok, at, 'tile must contain two integers'):
            return False
        return c.need(0 <= value[0] < width and 0 <= value[1] < height, at, 'tile out of bounds')

    def rect(value, at):
        ok = isinstance(value, list) and len(value) == 4 and all(type(v) is int for v in value)
        if not c.need(ok, at, 'rect must contain four integers'):
            return False
        x, y, w, h = value
        return c.need(x >= 0 and y >= 0 and w > 0 and h > 0 and x+w <= width and y+h <= height, at, 'rect must have positive size and stay in bounds')

    def safe(value):
        x, y = value
        return 1 <= y < height-1 and rows[y][x] == '.' and rows[y-1][x] == '.' and rows[y+1][x] in '#='

    spawn_points = []
    spawns = data.get('spawns')
    if c.need(isinstance(spawns, dict) and bool(spawns), where + '/spawns', 'must map entrance ids to pairs'):
        for entrance, pair in spawns.items():
            at = where + '/spawns/' + entrance
            c.identifier(entrance, at)
            if not c.need(isinstance(pair, list) and len(pair) == 2, at, 'requires exactly two feet tiles'):
                continue
            c.need(pair[0] != pair[1], at, 'paired spawn footprints must be distinct')
            for index, point in enumerate(pair):
                if tile(point, f'{at}/{index}'):
                    c.need(safe(point), f'{at}/{index}', 'unsafe spawn: require empty collider headroom and supporting ground')
                    spawn_points.append(point)
    entities = data.get('entities')
    if not c.need(isinstance(entities, list), where + '/entities', 'must be an array'):
        return False
    ids = set()
    nested_ids = set()
    bridges = []
    for index, entity in enumerate(entities):
        at = f'{where}/entities/{index}'
        if not c.need(isinstance(entity, dict), at, 'must be an object'):
            continue
        kind = entity.get('type')
        if not c.need(isinstance(kind, str) and kind in FIELDS, at + '/type', 'unknown entity type'):
            continue
        c.need(set(entity) == {'type', 'id'} | FIELDS[kind], at, 'unexpected or missing entity fields')
        key = entity.get('id')
        if c.identifier(key, at + '/id'):
            c.need(key not in ids, at + '/id', 'duplicate entity id')
            ids.add(key)
        point = entity.get('tile')
        valid_tile = tile(point, at + '/tile') if 'tile' in FIELDS[kind] else False
        if valid_tile:
            c.need(rows[point[1]][point[0]] == '.', at + '/tile', 'entity tile must be empty')
            if kind in ('spoolmite', 'spoolwarden', 'checkpoint', 'npc', 'secret', 'diagnostic_mover'):
                c.need(safe(point), at + '/tile', 'ground entity needs empty headroom and supporting ground')
            if kind in ('spoolmite', 'wickwing', 'spoolwarden'):
                c.need(all(abs(point[0]-spawn[0]) > 3 or abs(point[1]-spawn[1]) > 3 for spawn in spawn_points), at + '/tile', 'enemy too close to entrance spawn')
        if kind == 'diagnostic_mover':
            c.need(c.stage == 'diagnostic', at, 'diagnostic_mover is forbidden in full content')
            distance = entity.get('range_tiles')
            c.need(type(distance) is int and distance > 0, at + '/range_tiles', 'must be a positive integer')
            if valid_tile and type(distance) is int:
                c.need(point[0]-distance >= 0 and point[0]+distance < width, at, 'mover range leaves room')
        elif kind == 'exit':
            if rect(entity.get('rect'), at + '/rect'):
                x, y, w, h = entity['rect']
                c.need(w >= 3 and h >= 2, at + '/rect', 'rally zone must fit both couriers')
                safe_cells = [(xx, yy) for yy in range(y, y+h) for xx in range(x, x+w) if safe([xx, yy])]
                c.need(len(safe_cells) >= 2, at + '/rect', 'rally zone needs two safe standing tiles')
            c.identifier(entity.get('target_room'), at + '/target_room')
            c.identifier(entity.get('target_entrance'), at + '/target_entrance')
            requirements = entity.get('requires_all')
            c.need(isinstance(requirements, list) and all(isinstance(flag, str) for flag in requirements) and len(requirements) == len(set(requirements)), at + '/requires_all', 'must be unique flag strings')
        elif kind == 'checkpoint':
            c.identifier(entity.get('checkpoint_id'), at + '/checkpoint_id')
            c.need(isinstance(spawns, dict) and isinstance(entity.get('entrance'), str) and entity['entrance'] in spawns, at + '/entrance', 'checkpoint entrance does not resolve')
        elif kind in ('anchor_pair', 'loom'):
            field = 'anchors' if kind == 'anchor_pair' else 'stations'
            entries = entity.get(field)
            expected_flag = {'r02': 'bridge_spindle', 'r06': 'bridge_causeway'}.get(data.get('id')) if kind == 'anchor_pair' else 'loom_restored'
            c.need(entity.get('flag') == expected_flag and expected_flag is not None, at + '/flag', 'incorrect progression flag or room')
            if c.need(isinstance(entries, list) and len(entries) == 2, at + '/' + field, 'requires exactly two distinct points'):
                points = []
                for number, entry in enumerate(entries):
                    entry_at = f'{at}/{field}/{number}'
                    if not c.need(isinstance(entry, dict) and set(entry) == {'id', 'tile'}, entry_at, 'requires id and tile'):
                        continue
                    if c.identifier(entry.get('id'), entry_at + '/id'):
                        c.need(entry['id'] not in nested_ids and entry['id'] not in ids, entry_at, 'duplicate interaction id')
                        nested_ids.add(entry['id'])
                    if tile(entry.get('tile'), entry_at + '/tile'):
                        c.need(safe(entry['tile']), entry_at, 'interaction needs supported empty approach before restoration')
                        points.append(entry['tile'])
                c.need(len(points) == 2 and points[0] != points[1], at + '/' + field, 'interaction points must be distinct')
            if kind == 'anchor_pair' and rect(entity.get('bridge_rect'), at + '/bridge_rect'):
                x, y, w, h = entity['bridge_rect']
                c.need(h == 1, at + '/bridge_rect', 'bridge span must be one tile thick')
                c.need(all(rows[yy][xx] == '.' for yy in range(y, y+h) for xx in range(x, x+w)), at + '/bridge_rect', 'bridge span must be empty before restoration')
                cells = {(xx, yy) for yy in range(y, y+h) for xx in range(x, x+w)}
                c.need(all(not (cells & previous) for previous in bridges), at + '/bridge_rect', 'bridge spans overlap')
                bridges.append(cells)
        elif kind == 'npc':
            c.need(entity.get('character_id') == 'oru', at, 'only Oru is authored')
            for field, expected in [('dialogue_id', 'oru_intro'), ('restored_dialogue_id', 'oru_return')]:
                c.need(entity.get(field) == expected and expected in c.sequences, at + '/' + field, 'NPC dialogue reference is invalid')
        elif kind == 'secret':
            c.need(entity.get('flag') == 'lantern_charm' and data.get('id') == 'r03', at, 'one lantern_charm belongs inside r03')
    c.need(not (ids & nested_ids), where + '/entities', 'interaction IDs cannot duplicate entity IDs')
    decor = data.get('decor')
    if c.need(isinstance(decor, list), where + '/decor', 'must be an array'):
        for index, entry in enumerate(decor):
            at = f'{where}/decor/{index}'
            if not c.need(isinstance(entry, dict) and set(entry) == {'asset_id', 'frame', 'position_px', 'theme', 'z'}, at, 'requires asset_id/frame/position_px/theme/z only'):
                continue
            record = c.asset(entry.get('asset_id'), at + '/asset_id', ('sprite_atlas', 'tile_atlas'))
            frame = entry.get('frame')
            c.need(type(frame) is int and 0 <= frame < len(record.get('frames', [])), at + '/frame', 'frame out of bounds')
            position = entry.get('position_px')
            c.need(isinstance(position, list) and len(position) == 2 and all(type(v) is int for v in position) and 0 <= position[0] <= width*16 and 0 <= position[1] <= height*16, at + '/position_px', 'requires in-bounds integer pixel position')
            c.need(entry.get('theme') in ('common', 'ember', 'moss'), at + '/theme', 'unknown theme')
            c.need(type(entry.get('z')) is int and -4096 <= entry['z'] <= 4096, at + '/z', 'z must be an integer in Godot range')
    return True


def _world(c: Checks) -> dict[str, dict]:
    where = 'content/world.json'
    world = c.load(where)
    c.version(world, where)
    c.need(world.get('start_room') == 'r00', where, 'start_room must be r00')
    c.need(world.get('checkpoints') == {'checkpoint_a': 'r00', 'checkpoint_b': 'r04'}, where, 'checkpoint IDs/rooms must remain stable')
    records = world.get('rooms')
    seen = set()
    if c.need(isinstance(records, list), where + '/rooms', 'must be an array'):
        for index, record in enumerate(records):
            at = f'{where}/rooms/{index}'
            if not c.need(isinstance(record, dict), at, 'must be an object'):
                continue
            key = record.get('id')
            if not c.need(isinstance(key, str) and key in ROOM_IDS, at + '/id', 'unknown room id'):
                continue
            c.need(key not in seen, at + '/id', 'duplicate room id')
            seen.add(key)
            c.need(record.get('name') == ROOM_NAMES[int(key[1:])], at + '/name', 'incorrect room name')
            c.need(record.get('challenge_rewards') == REWARDS.get(key, []), at + '/challenge_rewards', 'wrong challenge rewards')
        c.need(seen == set(ROOM_IDS) and len(records) == 8, where, 'world must declare exactly r00 through r07')
    edges = world.get('connections')
    seen_edges = set()
    if c.need(isinstance(edges, list), where + '/connections', 'must be an array'):
        for index, edge in enumerate(edges):
            at = f'{where}/connections/{index}'
            if not c.need(isinstance(edge, dict) and set(edge) == {'a', 'b', 'requires_all'}, at, 'requires a/b/requires_all'):
                continue
            if not c.need(isinstance(edge['a'], str) and isinstance(edge['b'], str), at, 'endpoints must be room IDs'):
                continue
            pair = tuple(sorted((edge['a'], edge['b'])))
            c.need(pair not in seen_edges, at, 'duplicate undirected connection')
            seen_edges.add(pair)
            c.need(pair in EDGES and edge['requires_all'] == EDGES.get(pair), at, 'wrong progression connection or gate')
        c.need(seen_edges == set(EDGES) and len(edges) == len(EDGES), where, 'canonical nine connections required')
    paths = sorted((c.root / 'content' / 'rooms').glob('*.json'))
    expected = {'r00'} if c.stage == 'diagnostic' else set(ROOM_IDS)
    c.need({path.stem for path in paths} == expected, 'content/rooms', f'{c.stage} stage requires room files {sorted(expected)}')
    rooms = {}
    for path in paths:
        at = path.relative_to(c.root).as_posix()
        data = c.load(at)
        c.need(data.get('id') == path.stem, at, 'room id must match filename')
        if _room(c, data, at):
            rooms[path.stem] = data
    if c.stage == 'diagnostic':
        room = rooms.get('r00', {})
        c.need(len(room.get('tiles', [])) == 23 and all(len(row) == 60 for row in room.get('tiles', [])), 'content/rooms/r00.json', 'diagnostic room must be exactly 60x23')
        c.need(room.get('spawns', {}).get('start') == [[6, 19], [9, 19]], 'content/rooms/r00.json/spawns/start', 'diagnostic start must remain [[6,19],[9,19]]')
        c.need(any('=' in row for row in room.get('tiles', [])), 'content/rooms/r00.json/tiles', 'diagnostic needs a one-way platform')
        c.need(room.get('entities') == [{'type': 'diagnostic_mover', 'id': 'mover', 'tile': [30, 19], 'range_tiles': 6}], 'content/rooms/r00.json/entities', 'diagnostic requires the exact shared mover fixture')
        c.asset('diagnostic_terrain_v1', 'diagnostic terrain', ('tile_atlas',))
        c.asset('diagnostic_mover_v1', 'diagnostic mover', ('sprite_atlas',))
        return rooms
    directed = set()
    counts: dict[str, list[tuple[str, dict]]] = {}
    for room_id, room in rooms.items():
        for entity in room.get('entities', []):
            if not isinstance(entity, dict) or entity.get('type') not in FIELDS:
                continue
            kind = entity['type']
            counts.setdefault(kind, []).append((room_id, entity))
            at = f'content/rooms/{room_id}.json/entities/{entity.get("id", "?")}'
            if kind == 'exit':
                target = entity.get('target_room')
                if not c.need(isinstance(target, str) and target in rooms, at, 'exit target room missing'):
                    continue
                entrance = entity.get('target_entrance')
                c.need(isinstance(entrance, str) and entrance in rooms[target].get('spawns', {}), at, 'target entrance does not resolve')
                pair = tuple(sorted((room_id, target)))
                c.need(pair in EDGES and entity.get('requires_all') == EDGES.get(pair), at, 'exit progression gate differs from world graph')
                c.need((room_id, target) not in directed, at, 'duplicate directed room exit')
                directed.add((room_id, target))
    required_directed = {(a, b) for pair in EDGES for a, b in (pair, pair[::-1])}
    c.need(directed == required_directed, 'content/rooms/exits', 'every graph connection needs both directed rally exits')
    for kind, count in [('checkpoint', 2), ('npc', 1), ('secret', 1), ('spoolwarden', 1), ('anchor_pair', 2), ('loom', 1)]:
        c.need(len(counts.get(kind, [])) == count, 'content/rooms/' + kind, f'requires exactly {count}')
    c.need({(room_id, entity.get('checkpoint_id')) for room_id, entity in counts.get('checkpoint', [])} == {('r00', 'checkpoint_a'), ('r04', 'checkpoint_b')}, 'content/rooms/checkpoint', 'incorrect checkpoint identity/placement')
    for kind, room_id in [('npc', 'r00'), ('spoolwarden', 'r05'), ('loom', 'r07')]:
        c.need(all(key == room_id for key, _ in counts.get(kind, [])), 'content/rooms/' + kind, f'must be in {room_id}')
    for kind in ('spoolmite', 'wickwing'):
        c.need(any(key == 'r03' for key, _ in counts.get(kind, [])), 'content/rooms/r03.json', f'missing {kind} lesson')
    return rooms


def _font(c: Checks):
    record = c.asset('font_v1', 'font_v1', ('font',))
    if not record:
        return
    path = c.local_path(record.get('path'), 'font_v1/path')
    if path is None:
        return
    try:
        glyphs = {int(value) for value in re.findall(r'^char\s+id=(\d+)\b', path.read_text(encoding='utf-8'), re.MULTILINE)}
    except (OSError, UnicodeError) as exc:
        c.errors.append(f'font_v1: cannot read BMFont glyphs: {exc}')
        return
    c.need(set(range(32, 127)) <= glyphs, 'font_v1', 'font must cover all 95 printable ASCII glyphs')
    for where, text in c.text:
        missing = sorted({ord(char) for char in text} - glyphs)
        c.need(not missing, where, f'font lacks glyphs {missing}')


def validate(root: Path, stage: str = 'full') -> list[str]:
    """Return actionable errors; never mutate content or turn incomplete data into success."""
    if stage not in ('diagnostic', 'full'):
        return [f'stage: unsupported stage {stage!r}']
    checks = Checks(root, stage)
    _manifest(checks)
    _profiles(checks)
    _themes(checks)
    _dialogue(checks)
    _world(checks)
    _font(checks)
    return checks.errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--stage', choices=('diagnostic', 'full'), default='full')
    parser.add_argument('--root', type=Path, default=ROOT, help='repository/bundle root to validate')
    args = parser.parse_args()
    errors = validate(args.root, args.stage)
    for error in errors:
        print('FAIL ' + error, file=sys.stderr)
    if errors:
        print(f'FAIL content stage={args.stage}: {len(errors)} error(s)', file=sys.stderr)
        return 1
    print(f'PASS content stage={args.stage}: authored schemas, references and declared gates')
    if args.stage == 'diagnostic':
        print('Diagnostic only: final rooms, terrain/background references and gameplay acceptance are deferred.')
    print('Structural checks only; physical traversal, rendering, listening and human play remain separate gates.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
