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
