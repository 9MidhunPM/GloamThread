# Handoff — Gloamthread: Two Ends (Phase 1 build)

Written 2026-10-24 by Devin CLI (Claude) for the next coding agent (Codex). Read this first, then `AGENTS.md`, `MVP.md`, `docs/DECISIONS.md`, `docs/ARCHITECTURE.md`. The latest user instruction outranks every document.

## 1. User decisions already made (do not re-ask)

1. **Scope:** full Phase 1 (milestones M0–M7 in `docs/IMPLEMENTATION_PLAN.md`). Stop there — no Phase 2 generation, no 96-room world.
2. **Input:** **keyboard + keyboard (WASD / arrows)** is the primary mode to build and verify on the user's laptop. Gamepad and keyboard+gamepad paths must be implemented (data-driven) but recorded as *unverified on hardware* until a pad is plugged in. No gamepads are connected on this machine.
3. **Repository workflow:** the repo history starts from the DevDay Kochi hackathon template. Follow its rules (now merged into `AGENTS.md` → "Repository workflow"): `CHANGELOG.md` entry with a real `date -Iseconds` timestamp in the same commit as each meaningful change; `AI_USAGE.md` row per meaningful agent contribution (name the actual tool, e.g. "Codex"); keep `README.md` and `SUBMISSION.md` truthful; commit per milestone and roughly every 30 minutes of meaningful work with `feat:/fix:/docs:/wip:` messages; never backdate, squash, or force-push. The template `origin` remote was **removed on purpose** — never push to the template repo; only push to a remote the user explicitly authorizes.
4. **Parallelism:** the user approved parallel subagents for independent subsystems with exclusive file ownership (see §6). The integrator (you) owns `project.godot`, scenes, session/input/world engine code, `tools/generate_assets.py`, `assets/manifest.json`, docs and commits.

## 2. Environment (verified 2026-10-24)

| Item | State |
| --- | --- |
| Godot | **4.7.2.stable.arch_linux** at `/usr/bin/godot` (Arch package, standard build) |
| Python | 3.14.8, Pillow 13.0.0, numpy 2.5.4 (numpy is a tool dependency for audio synthesis; recorded in `docs/SETUP.md` and `tools/preflight.py`) |
| Git | 2.56.0; identity configured (`9MidhunPM`, user's email) |
| Display/audio | Wayland + Hyprland, PipeWire; Intel Core Ultra 7 255H, Arc 140T iGPU, 30 GB RAM |
| Export templates | **not installed** (`~/.local/share/godot/export_templates/` absent). Needed only at M7. Ask the user before downloading (~1 GB). |
| Gamepads | none connected |
| Checks | `python3 tools/preflight.py` → exit 0; `python3 tools/check_pack.py` → PASS (58 links) |

Godot CLI flags confirmed present: `--headless`, `--script`, `--check-only`, `--import`, `--export-release`, `--write-movie`, `--quit-after`, `--fixed-fps`, `--log-file`.

## 3. Repository state at handoff

Commits:

- `4163290 docs: add Kochi hackathon rules and participant template` (template root)
- `14509f4 docs: adopt hackathon template workflow and add Gloamthread planning pack`
- a `wip:` commit made together with this file containing the files below.

**M0 in progress.** Written but **not yet run in Godot** (no import, no launch, no test has been executed — treat all of it as unverified until `godot --headless --path . --import` and the smoke scenario pass):

| File | Purpose | Status |
| --- | --- | --- |
| `project.godot` | Compatibility renderer, 60 Hz physics, 960×360 viewport with 1920×720 window override, stretch viewport/keep/integer, Nearest filter, 2D pixel snap, autoloads `InputRouter` + `AudioDirector`, render layers common/ember/moss, physics layers 1–8 named, `run/main_scene = res://scenes/app/boot.tscn` (scene not created yet) | written |
| `scripts/input/command_snapshot.gd` | `CommandSnapshot` (held/pressed/released bitmask + axes), `Action` enum | written |
| `scripts/input/device_source.gd` | `DeviceSource` (KEYBOARD_LEFT, KEYBOARD_RIGHT, GAMEPAD), conflict rule, persistent identity `{kind,guid,name}` | written |
| `scripts/input/bindings.gd` | default bindings per device kind, `to_dict/from_dict`, prompt labels | written |
| `scripts/input/input_router.gd` | autoload: per-device polling each physics tick, slot assignment with conflict rejection, `flush()` latch semantics, hotplug `device_lost/device_returned`, scenario seam `set_test_input()` | written |
| `scripts/audio/audio_director.gd` | autoload: non-positional voice pool, `play_cue/play_music`, `emission_counts` for tests | written |
| `scripts/world/room_definition.gd` | parses/validates `content/rooms/*.json` (ASCII tile rows, spawns, entities) | written |
| `scripts/world/collision_builder.gd` | greedy-merged solid rectangles + one-way runs → one `StaticBody2D` | written |
| `scripts/presentation/graybox_skin.gd` | diagnostic `TileMapLayer` from `assets/generated/diagnostic/tiles_diag.png` (file not generated yet) | written |
| `scripts/world/room.gd` | `Room.build(definition)` → Collision, Common(vis 1), ThemeEmber(vis 2), ThemeMoss(vis 4), Entities; `theme_gameplay_node_count()` guard | written |

Default keyboard bindings (remappable later): **P1 (left zone)** A/D move, W/S up/down, Space jump, F attack, G special, E interact, Shift dash, Esc pause, Tab map. **P2 (right zone)** arrows move, `.` jump, `,` attack, `/` special, M interact, `'` dash, Enter pause, `;` map. Gamepad: stick/d-pad, A jump, X attack, B special, Y interact, RB/RT dash, Start pause, Back map.

## 4. Remaining M0 work (do this first, in order)

1. `tools/generate_assets.py` — create the entry point now with a **diagnostic stage**: write `assets/generated/diagnostic/tiles_diag.png` (160×120 atlas: 8 cols × 6 rows of 16×16 cells, 2 px margin, 4 px separation → 20 px stride; fill slots (0,0) solid fill, (1,0) solid top with lighter edge, (2,0) one-way thin bar, (3,0) hazard chevron), `courier_tavi_diag.png` and `courier_neri_diag.png` (32×48, distinct silhouettes/colours, feet at origin (16,43)), `mover_diag.png` (32×32). Write `assets/manifest.json` with `{"schema_version":1,"generator_version":"0.1","seed":18427,"assets":[{id, path, kind, size, sha256, diagnostic:true}]}`. Deterministic; Pillow only.
2. `content/rooms/r00.json` — graybox version of Lantern Rest for the tracer: `schema_version 1`, `id "r00"`, ≥ 60×23 tiles (wider than one view so cameras diverge), floor, a few ledges and one one-way platform, `spawns: {"start": [[6,19],[9,19]]}` (empty tiles with ground below), `entities: [{"type":"diagnostic_mover","id":"mover","tile":[30,19],"range_tiles":6}]`.
3. `scripts/world/diagnostic_mover.gd` — `Node2D` that oscillates horizontally in `_physics_process` (proves one moving object seen by both cameras).
4. `scripts/actors/player_controller.gd` + `scenes/actors/player.tscn` — `CharacterBody2D`, `collision_layer = 2`, `collision_mask = 1` (players never block each other), `CollisionShape2D` rectangle 12×24 at `position (0,-12)` (origin = feet), `Sprite2D` with `centered = false`, `offset = (-16,-43)`. Reads **only** `InputRouter.snapshot(slot_index)`. M0 motor: gravity ≈ 1400 px/s², jump speed ≈ -330, max speed 110, accel 900 (air 600), max fall 400; M1 adds coyote time, jump buffer, variable jump height, one-way drop-through (DOWN + JUMP).
5. `scripts/presentation/follow_camera.gd` — `Camera2D`, `anchor_mode = DRAG_CENTER`, smoothing disabled; own float smoothing toward `target.global_position + (0,-24)`, clamp centre to `room bounds` inset by (240,180) (centre the view if the room is smaller), then `global_position = rounded`. Also set `limit_*` to room bounds as a guard. `make_current()` in `_ready()`.
6. `scripts/presentation/split_presentation.gd` + `scenes/session/session.tscn`: `Presentation (Control 960×360)` → `ViewA (SubViewportContainer @0,0 480×360, stretch=false)` → `ViewportA (SubViewport 480×360, canvas_cull_mask = 3, audio_listener_enable_2d = false, handle_input_locally = false)` → `WorldRoot (Node2D)` holding `RoomSlot`, `Actors`, `Effects`; `ViewB (@480,0)` → `ViewportB (SubViewport, canvas_cull_mask = 5)` **left empty in the .tscn**. In `_ready()`: `viewport_b.world_2d = viewport_a.world_2d` **before** adding any CanvasItem under ViewportB (CanvasItems register with the canvas on enter-tree, so order matters), then create `FollowCamera` A under ViewportA and B under ViewportB. Divider: 2 px `ColorRect` overlay at x = 479. HUDs: `Control`s over each half **outside** the SubViewports (diagnostic `Label` with slot, device label and position). Theme parallax backgrounds (M4) go in a per-viewport `CanvasLayer` (never shared between viewports).
7. `scripts/session/game_session.gd` — `process_mode = ALWAYS`; `Presentation.process_mode = PAUSABLE`; loads `content/rooms/r00.json` → `Room.build` → `WorldRoot/RoomSlot`; spawns two players at `spawn_positions("start")`, targets cameras; spawns the mover from entities; toggles `get_tree().paused` when `InputRouter.any_just_pressed(PAUSE)` and calls `InputRouter.flush()` on resume; pauses on `NOTIFICATION_APPLICATION_FOCUS_OUT`; shows a `PauseOverlay` `CanvasLayer` (ALWAYS) with a label.
8. `scripts/app/app_controller.gd` + `scenes/app/boot.tscn` — M0 temporary auto-join: `InputRouter.assign(0, DeviceSource.keyboard_left())`, `assign(1, DeviceSource.keyboard_right())`, then instance `session.tscn`. M1 replaces this with the join screen.
9. `tests/scenario.gd` (base `Scenario extends Node`: `failures`, `assert_true/assert_eq`, `await ticks(n)` awaiting `physics_frame`), `tests/run_tests.gd` (`extends SceneTree`; `_initialize()` kicks a coroutine that discovers `res://tests/scenarios/*.gd`, adds each to root, awaits `run()`, prints `PASS/FAIL`, `quit(0|1)`; optional `-- --filter <substring>`), `tests/scenarios/smoke_session.gd` (instance `session.tscn`, tick 30 frames, assert: `viewport_b.world_2d == viewport_a.world_2d`; exactly one `DiagnosticMover` and two players in the tree; players' feet rest on ground (y stable); `room.theme_gameplay_node_count() == 0`; mover position changed). `tools/run_tests.sh` = `godot --headless --fixed-fps 60 --path . --script tests/run_tests.gd "$@"` for fast deterministic ticks; the plain documented command must also work.
10. Verify and record in `evidence/commands.md` + `docs/STATUS.md` + `CHANGELOG.md`: `python3 tools/generate_assets.py --seed 18427`, `godot --headless --path . --import` (commit the generated `*.import` files, never `.godot/`), `godot --headless --path . --script tests/run_tests.gd`, `godot --path .` (check both halves show the graybox in different tints, both couriers move independently from WASD and arrows, pause freezes both). Fix whatever the engine rejects — none of the written GDScript has been parsed by Godot yet (`godot --headless --path . --check-only --script <file>` parses a single script).
11. Commit: `feat: godot project shell with split presentation and scenario runner`.

## 5. Milestones after M0 (full detail in the plan below)

- **M1** (T02–T05): `content/profiles.json`, `themes.json`, `world.json`, `abilities.json` + typed loaders; `tools/validate_content.py` (mirror `RoomDefinition` rules + graph gates from `examples/world_graph.json`); join screen (claim device/zone per slot, forbid double claim, rollover caveat); device-lost pause + reassignment panel; motor polish (coyote, buffer, variable jump, drop-through); per-view HUD (hearts, special readiness, partner state); scenarios: ownership, no body blocking, pause freeze, single-instance world. Freeze `docs/CONTRACTS.md` (room JSON, asset manifest, animation state names, cue IDs) **before** launching subagents.
- **M2** (T06–T07): attacks with anticipation/active/recovery + per-attack hit set; `CombatResolver`; Ember Arc, Spore Bolt (slow cap; boss immune with cue); Spoolmite FSM; downed 12 s / hold-revive 1.5 s / interrupts / 2 hearts + immunity; `RecoveryTransaction`; scenarios for every TEST_PLAN combat/recovery case.
- **M3** (T08): `AnchorPair` (two distinct players, visible latch, one permanent flag → bridge collision + both skins), `ExitRally` + single transition transaction with paired safe spawns, checkpoint A, global map/dialogue with one menu owner, Ember/Moss graybox proof, scenario proving mask swap changes zero simulation state.
- **M4** (T09–T10): integrate subagent art/audio; `generate_assets.py` full pipeline + `validate_assets.py`; `SpriteAnimator` from manifest state tables; `ThemePresenter` (two `TileMapLayer`s + decor roots + per-viewport parallax `CanvasLayer`s from one room definition); `AudioDirector` stream registration; 1× captures of both views reviewed before more rooms.
- **M5** (T11–T14): rooms r00–r07 exactly per `MVP.md`/`DECISIONS.md` route; Oru; Wickwing; Spoolwarden (sweep / delayed strike / recoverable charge; stagger seam; Cross-stitch once per window; beatable without) → `boss_spoolwarden`, `threadstep`, `shortcut_bell` committed once; Threadstep motor gate; r06 safe lesson + gap + `bridge_causeway`; r07 loom stations → `loom_restored`, light chain, skippable sequence, return to r00, ending card; full normal-input route logged.
- **M6** (T15–T16): `SaveRepository` (`user://save/team_save.json` + `.bak`, tmp → re-parse → rotate → rename; missing/corrupt/truncated/newer handling UI; write-failure notice), `SettingsRepository` (bindings per slot, deadzone, volumes, reduced shake/flash), remap UI, hotplug during combat/revive/rally, fault-injected save scenarios.
- **M7** (T17–T18): export templates (ask user), preset `Linux`, `godot --headless --path . --export-release "Linux" build/gloamthread.x86_64`, run offline outside the tree; A01–A30 matrix in `evidence/`; performance in r05 at 1920×720 via `Performance` monitors; final README/SUBMISSION/CHANGELOG/AI_USAGE/STATUS; provenance summary. Two-human playtests are user-run and recorded only if they happen.

## 6. Parallel subagent split (approved by user; start after M1 contracts are frozen)

| Worker | Exclusive paths | Delivers |
| --- | --- | --- |
| Art generator | `assets/source/art/**`, `tools/gen/art/**`, art checks in `tools/validate_assets.py` | Tavi/Neri 32 frames each (288×208 padded atlas, 36×52 cells, origin (16,43)), Oru 8 (288×52), Spoolmite 16 + Wickwing 14 (32×32, 8-col padded), Spoolwarden 32 (544×272, 64×64), 48-slot terrain ×2 themes (160×120, identical edge masks), 16 props, 3 parallax layers ×2 themes (480×360), 8 effects ×6 frames, 20 UI icons (100×80), 5×7 font (96×48) + BMFont `.fnt`; manifest fragments with frame/pivot/state metadata. Code-native parametric art with pose tables; no downloads, no uniform noise. |
| Audio generator | `assets/source/audio/**`, `tools/gen/audio/**` | numpy synthesis: instruments (pluck, bell partials, drone, shaped noise), 18 cues listed in `docs/ART_AUDIO_PIPELINE.md` §6, 3 arrangements (exploration 45–90 s loop, boss 30–60 s loop, ending 15–30 s), 44.1 kHz 16-bit WAV, loop points, peak checks. |
| Content/validator | `tools/validate_content.py`, `content/rooms/r01..r07.json` drafts, `content/dialogue.json` | graph/ID/spawn/gate validation; ASCII room drafts following the route; dialogue restricted to the font glyph set, drawn from `docs/STORY_BIBLE.md`. |
| Integrator (you) | everything else | engine code, `tools/generate_assets.py` entry that calls `tools/gen/art` and `tools/gen/audio` and writes `assets/manifest.json`, integration, docs, commits. |

## 7. Implementation decisions already taken (record in `docs/DECISIONS.md` → "Implementation addenda" as they land)

| # | Decision |
| --- | --- |
| D1 | Collision is built programmatically from the logical tile grid (`CollisionBuilder`); `TileMapLayer`s are render-only, one per theme. |
| D2 | Rooms are JSON with ASCII rows: `#` solid, `=` one-way, `.` empty, `^` hazard; entities as a list (spawn pairs, anchors, bridge spans, exits, checkpoint, npc, secret, enemies). Rooms 30–90 × 23–30 tiles. |
| D3 | `InputRouter` polls per device each physics tick → immutable `CommandSnapshot` per slot. Gameplay never touches `Input`/InputMap; menus read the owning slot's snapshot. |
| D4 | Keyboard/keyboard is first-class (two keyboard zones), rollover caveat shown on join; gamepads selectable. |
| D5 | Code-native deterministic art (parametric parts + pose tables + ASCII overrides), source in `assets/source/art/`, provenance in `assets/manifest.json` (SHA-256). |
| D6 | Audio synthesised with numpy → WAV with loop points. |
| D7 | Bitmap font as BMFont `.fnt` + PNG → Godot `FontFile`; fallback `GlyphLabel` blitting from the atlas. |
| D8 | Non-positional audio via `AudioDirector`; `audio_listener_enable_2d = false` on both SubViewports. |
| D9 | Saves: `user://save/team_save.json` + `.bak`, atomic tmp/rename; settings separate; device identity `{kind,guid,name}` never OS index. |
| D10 | Same-tick priorities: boss-defeat transaction before team wipe; revive completion beats timeout; rescuer damage cancels the hold; one transition/recovery transaction at a time (`SessionCoordinator`). |
| D11 | Ordinary enemies respawn on room (re)load; Spoolwarden and secret never; recovery reloads the checkpoint room. |
| D12 | `tools/gen/art/`, `tools/gen/audio/` owned by subagents; `tools/generate_assets.py` is the thin integrator-owned entry. |

Engine facts behind the split-screen design (from official Godot docs/release notes): two `SubViewport`s sharing one `World2D`; `canvas_cull_mask` filters `visibility_layer`, and a culled parent culls its subtree, so only the theme roots need a bit (common = 1, Ember = 2, Moss = 4; view A mask 3, view B mask 5). `CanvasLayer` children of a SubViewport are never shared → per-viewport parallax. Plain `CanvasItem`s under SubViewport B draw into the shared canvas → anything theme-specific must sit under a masked theme root. Camera2D `make_current` groups are per viewport RID, so two current cameras in two viewports do not fight. Godot 4.7 adds `CollisionShape2D.one_way_collision_direction`; `TileMapLayer` replaces `TileMap`; `Window.content_scale_stretch = INTEGER` gives integer scaling with letterbox.

## 8. Honesty rules for the report

Never claim import, rendering, gamepad, audio, performance or human-playtest results that did not happen. Keep `docs/STATUS.md` split into implemented / verified / unverified / blocked. Known blockers now: no gamepads (gamepad gates unverified), export templates missing (M7), human playtests and performance need the user.

## 9. Full plan (copied from the agent plan file)

See `docs/PLAN_PHASE1.md` — the complete milestone plan with gates, verification per layer and layout. Keep it updated as understanding evolves.
