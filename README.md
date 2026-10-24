# Gloamthread — wave arena

A side-view pixel fighter for **one or two local players** on a shared screen. Survive 20 waves, buy your own upgrades between rounds, fight four bosses, then choose endless. Draw/import a fighter to propose themed abilities and generate original artwork through an optional local OpenAI authoring worker.

The new game uses fullscreen 1920×1080 presentation with a 640×360 pixel arena scaled 3×. Godot 4.7.2 standard/Compatibility and Python 3 are the project tools. The approved [specification](docs/WAVE_FIGHTER_SPEC.md), [Agent 2 brief](docs/AGENT_2_WAVE_CONTENT.md) and [current evidence](docs/STATUS.md) distinguish working code from acceptance still in progress.

## Play

[Download the Linux arena playtest](https://github.com/9MidhunPM/GloamThread/releases/tag/v0.2.0-arena), or run the source with Godot:

```sh
godot --headless --path . --editor --import --quit
godot --path .
```

Choose Solo Run or Local Co-op, change fighters/inputs, then Start Run. F11 toggles fullscreen. For a window: `godot --path . --windowed --resolution 1920x1080`.

| Action | Player 1 | Player 2 | Gamepad |
| --- | --- | --- | --- |
| Move | WASD | Arrows | Left stick |
| Jump | Space | Period | A |
| Basic attack (hold) | F | Comma | X |
| Special | G | Slash | B |
| Dodge | Left Shift | Apostrophe | RB |
| Revive (hold near partner) | E | M | Y |
| Pause | Escape | Enter | Start |

Down+Jump drops through a platform. Shops use each player's Up/Down and Attack/Jump to select/confirm independently; every active player must Ready. Mouse controls also work. Keyboard sharing depends on hardware rollover; physical controller and fresh human balance/listening checks are recorded only when performed.

Run power and coins reset on defeat/restart. Saved fighters/settings/scores are local under Godot's `Gloamthread-Arena` user directory, separate from the old campaign.

## Draw and forge

Character Forge supports a drawing canvas, PNG/JPEG import, editable body/ability/theme proposals, animation preview, raw-board crop correction, part masks/pivots and offline local rebaking. Three built-in fighters (including the reviewed AI-generated Kiln Fox) and accepted creations work without a network or API key. Supported bodies are upright, four-legged and floating; abilities use six tested families.

```sh
python3 -m venv --system-site-packages .venv
.venv/bin/python -m pip install -r requirements-authoring.txt
.venv/bin/python tools/fighter_forge.py status
```

Keep `OPENAI_API_KEY` in the ignored root `.env` (settings in `.env.example`); never paste it into chat or commit it. Godot launches Python without reading the key. Analysis uses `gpt-6-luna`; image edits use `gpt-image-1-mini`, low quality. Generating requires explicit creator actions, retains source/prompts/provenance and validates the complete result before acceptance. No provider calls occur during combat.

The initial experiment has a durable shared $0.50 reservation cap, no automatic retries or model fallback. Reservations are conservative allowances, not billing receipts. The mini image model retires 1 December 2026; changing models requires a fresh cost review. See [worker details](evidence/arena-content/forge/README.md). The live drawing-analysis and image requests succeeded; the resulting fox and forest ship with retained source/provenance. Nonconforming image layouts can be corrected locally from cached output. See [status](docs/STATUS.md).

## Verify

```sh
python3 -m unittest discover -s tools/tests -p 'test_*.py'
python3 -m tools.forge.content --validate
godot --headless --fixed-fps 60 --path . --script tests/arena/run_tests.gd
godot --headless --fixed-fps 60 --path . --script tests/forge/run_tests.gd
python3 tools/check_pack.py
```

Rebuild original arena media with `python3 -m tools.forge.content --build --validate`. Source drawings, editable rigs, music and provenance are retained. Test fixtures and headless imports do not establish rendered quality, hardware support or enjoyable combat.

Package a clean checkout with `python3 tools/package_arena.py`; the [Linux play guide](docs/ARENA_DEMO.md) covers the optional authoring helper.

The previous eight-room game and its v0.1 release remain preserved in Git/history and [release evidence](evidence/release/README.md); its tests/performance do not prove the new wave game. Event guidance: **Devin Hack Kochi** in [RULES.md](RULES.md).
