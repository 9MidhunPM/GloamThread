# Agent 2 content delivery evidence

This directory records authored content checks. It is not evidence of Godot gameplay.

## Tool setup

Verified on 24 October 2026: Python 3.14.8, Pillow 13.0.0, NumPy 2.5.4,
Godot 4.7.2.stable.arch_linux.ed1daf0bf. No content downloads or runtime services.
Install the system prerequisites described in the central setup document; no
additional Python packages are needed beyond Pillow and NumPy.

## Drop A — diagnostic tracer

Branch: `feat/phase1-content`. Preparation base: `2fea1ef`.
The exact packet SHA is recorded in the next drop's history entry and Git history
(`feat: deliver diagnostic content tracer`); the commit cannot contain its own SHA.

Commands actually run from the content checkout:

```sh
python3 tools/preflight.py
python3 tools/generate_assets.py --seed 18427 --stage diagnostic
python3 tools/validate_assets.py --stage diagnostic
python3 tools/validate_content.py --stage diagnostic
python3 -m unittest discover -s tools/tests -p 'test_*.py'
python3 tools/check_pack.py
git diff --check
```

Results: generation produced six manifested assets; diagnostic asset/content
checks passed; 15 Python tests passed. Planning-pack checks passed. The full
asset validator correctly exited 1 for the diagnostic stage and absent final
inventory. Full generation explicitly reports that final authoring is in progress.

Inventory: 160x120 padded diagnostic terrain, 32x48 Tavi/Neri silhouettes at
feet origin (16,43), 32x32 mover, original 96-glyph PNG/BMFont pair, fixed profiles,
both theme definitions with stable ordered 48 terrain IDs, initial full world
graph and concise dialogue. r00 is 60x23 with the specified spawn/mover contract.

Directly inspected both diagnostic courier PNGs at native resolution. Their
hood, scarf and spool shapes differ. This inspection does not establish animation,
combat readability or a finished art direction. Every output has source hashes.

Runtime integration: load the exact diagnostic paths and fixed profile visual
IDs. Font ID `font_v1` references PNG `font_texture_v1`. Final theme terrain and
background references are explicitly deferred in diagnostic validation. Agent 1
must supply strict entity/entrance/decor consumers and measured jump/dash bounds.

Remaining: complete animation/actor/prop/background/effect/UI inventory, 18 cues,
three arrangements, final eight-room content, traversal and runtime review.
Godot imports, animation playback, listening, gamepads, physical traversal,
performance, exports and human playtests are unverified by Agent 2.

## Drop B — complete original asset inventory

Previous packet: `34e14c96d9c2e78d94007b55ac7af5794b5157ec` (Drop A).
Drop B supplies assets independently of the final room/story packet. The retained
diagnostic image files remain available to the early runtime; they are absent
from the full manifest and are not full-content dependencies.

```sh
python3 tools/generate_assets.py --seed 18427
python3 tools/validate_assets.py
python3 tools/gen/rebuild_check.py --seed 18427
python3 -m unittest discover -s tools/tests -p test_assets.py
python3 -m unittest discover -s tools/tests -p test_audio.py
python3 -m unittest discover -s tools/tests -p test_generation.py
```

Results: 47 full-stage manifested assets; asset validation PASS; 27 asset,
11 audio and two generator tests PASS (40 tests). Two full rebuilds produced
identical hashes for all 47 listed outputs and the manifest, recorded in
`rebuild.json`. The generator's default stage is now usable and complete.

Inventory: 64 courier frames, 70 Oru/enemy/boss frames, both 48-slot terrain
atlases, six finite 480x360 backgrounds, 16 logical props with 21 state frames,
48 effect frames, 20 UI glyphs, the original font, 18 distinct semantic cues,
and 48/36/18-second exploration/boss/ending arrangements. Every asset retains
source paths/hashes. Sources include explicit palettes, pixel/pose recipes,
glyph matrices, instruments, envelopes, cues and note scores.

Native atlas/contact-sheet inspection covered both couriers, Oru, both normal
enemies, boss phases and Ember/Moss authoring compositions. A review corrected
inner-corner highlight orientation. Audio tests cover actual PCM format, peaks,
loop seams and a representative simultaneous-event combination. These checks
do not establish runtime mixing or listening comfort.

Integration: map full manifest frame/tick tables into runtime animation and
register all semantic audio names once through the shared mix. Props expose
`prop_ids` aligned to frames and `logical_props` for inventory checks; the first
16 frame indices remain stable. Full room delivery follows separately. No
finished-room, physical-traversal, engine-import or motion gate is claimed.
