# Gloamthread — wave arena

A scrolling side-view pixel fighter for **one or two local players**, with a shared view that splits when you explore apart. Survive 20 waves, buy your own upgrades between rounds, fight four bosses, then choose endless. Draw/import a fighter to propose themed abilities and generate original artwork through an optional local OpenAI authoring worker.

The game uses fullscreen 1920×1080 presentation: a 640×360 pixel shared view, or two 320×360 views at the same 3× scale. The seeded world starts four screens wide and expands to sixteen, with raised routes, shallow caves, caches and landmarks. Godot 4.7.2 standard/Compatibility and Python 3 are the project tools. The approved [specification](docs/WAVE_FIGHTER_SPEC.md), [Agent 2 brief](docs/AGENT_2_WAVE_CONTENT.md), the [scrolling-world contract](docs/SCROLLING_WORLD_PLAN.md) and [current evidence](docs/STATUS.md) distinguish working code from acceptance still in progress.

## Play

[Download the Linux arena playtest](https://github.com/9MidhunPM/GloamThread/releases/tag/v0.4.0-counterplay), or run the source with Godot:

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

Down+Jump drops through a platform. Shops use each player's Up/Down and Attack/Jump independently. Choose Explore to close your panel and move while your partner shops; E/M/Y reopens your own shop during breaks. Every active player must Ready. Regions open after waves 5/10/15 without replacing terrain or moving players. Attack caches to open them; healing plants restore 20% to their collector. Mouse controls also work. Keyboard sharing depends on hardware rollover; physical controller and fresh human balance/listening checks are recorded only when performed.

Chargers commit to a marked rush lane, heavies guard their front but expose counter windows, shooters lock a three-shot burst, and flyers mark their dives. Bait, flank, use cover and punish recovery. [Enemy mechanics](docs/ENEMY_MECHANICS.md).

Run power and coins reset on defeat/restart. Saved fighters/settings/scores are local under Godot's `Gloamthread-Arena` user directory, separate from the old campaign.

## Draw and forge

Character Forge supports a drawing canvas, PNG/JPEG import, editable body/ability/theme proposals, animation preview, raw-board crop correction, part masks/pivots and offline local rebaking. Three built-in fighters (including the reviewed AI-generated Kiln Fox) and accepted creations work without a network or API key. Supported bodies are upright, four-legged and floating; abilities use six tested families.

```sh
python3 -m venv --system-site-packages .venv
.venv/bin/python -m pip install -r requirements-authoring.txt
.venv/bin/python tools/fighter_forge.py status
```

Keep `OPENAI_API_KEY` in the ignored root `.env` (settings in `.env.example`); never paste it into chat or commit it. Godot launches Python without reading the key. Analysis uses `gpt-6-luna`; image edits use `gpt-image-1-mini`, low quality. Generating requires explicit creator actions, retains source/prompts/provenance and validates the complete result before acceptance. No provider calls occur during combat.

The user removed the local total/per-character dollar caps. Old `FORGE_TOTAL_BUDGET_USD` and job limits no longer block generation; the worker retains request estimates and uncertain outcomes as history, not billing receipts. Analyse/Generate remain explicit actions, with no automatic retries or model fallback. Provider account limits still apply. See [worker details](evidence/arena-content/forge/README.md).

If a returned image board needs correction, each part and the complete-character crop must contain visible pixels at the chosen opacity cutoff. Save checks this locally, selects the crop needing attention and keeps the editor open. A click without dragging preserves the old crop. Conversion creates the animation preview; **Accept fighter & play** saves the validated fighter and takes you to the lobby with it selected. Cached corrections make no model request. See [recovery evidence](evidence/creator-recovery/README.md).

## Verify

```sh
python3 -m unittest discover -s tools/tests -p 'test_*.py'
python3 -m tools.forge.content --validate
python3 -m tools.forge.world --validate
python3 -m tools.forge.scenery --validate
godot --headless --fixed-fps 60 --path . --script tests/arena/run_tests.gd
godot --headless --fixed-fps 60 --path . --script tests/forge/run_tests.gd
python3 tools/check_pack.py
```

Rebuild original arena media with `python3 -m tools.forge.content --build --validate`. Source drawings, editable rigs, music and provenance are retained. Test fixtures and headless imports do not establish rendered quality, hardware support or enjoyable combat.

Package a clean checkout with `python3 tools/package_arena.py`; the [Linux play guide](docs/ARENA_DEMO.md) covers the optional authoring helper.

The previous eight-room game and its v0.1 release remain preserved in Git/history and [release evidence](evidence/release/README.md); its tests/performance do not prove the new wave game. Event guidance: **Devin Hack Kochi** in [RULES.md](RULES.md).
