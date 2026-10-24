# Gloamthread: Two Ends — Phase 1 implementation plan

Current two-agent execution: use [Agent 1](AGENT_1_RUNTIME.md) and [Agent 2](AGENT_2_CONTENT.md). These briefs replace this original plan's three-worker ownership, generator ownership and pre-M1 parallelism restrictions. Milestone gates and Phase 1 scope remain unchanged. Canonical keyboard defaults and room dimensions are recorded in [DECISIONS.md](DECISIONS.md).

Build the eight-room fixed-character split-screen co-op slice in Godot 4.7.2 using the corrected Devin Hack Kochi template's repository workflow, implementing a one-room two-input tracer first, then combat/recovery, cooperation, original art/audio, the full route, persistence and release verification, with honest evidence at every gate. Current event guidance is in [RULES.md](../RULES.md).

## 0. Pre-implementation baseline (verified 2026-10-24)

This table records the environment before repository bootstrap and M0 work. It is historical context; [STATUS.md](STATUS.md) and [the handoff](../HANDOFF.md) describe the current partial implementation. Publication uses `Midhun P M <midhun.titan@gmail.com>` for project commits and the authorized `9MidhunPM/GloamThread` repository.

| Check | Result |
| --- | --- |
| `python3 tools/preflight.py` | exit 0 — Python 3.14.8, Pillow 13.0.0, Git 2.56, **Godot 4.7.2.stable.arch_linux** |
| `python3 tools/check_pack.py` | exit 0 — docs, 27 links, example contracts pass |
| Godot export templates | **not installed** → needed only for M7 (ask before the ~1 GB download) |
| Gamepads | none connected; user will play **keyboard + keyboard (WASD / arrows)** |
| Display / audio | Wayland + Hyprland; PipeWire. GPU: Intel Arc 140T, 30 GB RAM |
| Git | no repository yet; identity configured (`9MidhunPM`) |
| Hackathon template | Documentation scaffold only. Current correction baseline: `anima-regem/devin-hack-kochi-thanushreesuresh-SEOpilot` at `cb4db78169a8d199b43b077fbcc8f2ff4b798a14`; [RULES.md](../RULES.md) supersedes inherited event details. Original root history is preserved. |
| Project | no `project.godot`, code or assets — documents, 4 example JSONs, 2 Python utilities only |
| numpy 2.5.4 | installed (not listed in SETUP.md; used for audio synthesis) |

Godot 4.7 facts confirmed from official docs/release notes that shape the design:

- Split screen = two `SubViewport`s sharing one `World2D`; `Viewport.canvas_cull_mask` filters `CanvasItem.visibility_layer`, and culling a parent culls its subtree, so only theme **roots** need a bit (common=1, Ember=2, Moss=4; view A mask 1|2, view B mask 1|4).
- `CanvasLayer` children of a SubViewport are never shared across viewports → per-viewport theme parallax backgrounds are isolated for free. Plain `CanvasItem`s under SubViewport B draw into the shared canvas, so every theme-specific in-world node hangs under a masked theme root.
- 4.7 adds `CollisionShape2D.one_way_collision_direction`; `TileMapLayer` (4.3+) replaces `TileMap`; `Window.content_scale_stretch = INTEGER` gives integer scaling + letterbox. No breaking 2D changes in 4.7 affect this plan.
- CLI verified: `--headless`, `--script`, `--import`, `--export-release`, `--write-movie`, `--quit-after`, `--log-file`.

## 1. User decisions (2026-10-24)

1. **Scope:** full Phase 1 (M0–M7). Stop there; no Phase 2/3.
2. **Input:** keyboard/keyboard (WASD + arrows) is the primary mode to build and verify. Gamepad and keyboard+gamepad paths are implemented (data-driven) but recorded as *unverified on hardware* until a pad is plugged in.
3. **Repository:** use the hackathon template as the repo base and follow its workflow (changelog per meaningful change with real timestamps, AI usage log, README/SUBMISSION kept current, commit per milestone and ~every 30 min of meaningful work, conventional commit messages). No push unless a remote is authorized.
4. **Parallelism:** yes — subagents for tool/content subsystems with exclusive paths; I integrate and own engine wiring.

## 2. Repository bootstrap (first commit)

1. `git clone` the template → move its `.git` into `Gloamthread/` so the template commit is the root of history; add the Gloamthread pack as `docs: add Gloamthread Phase 1 planning pack`.
2. Merge, don't overwrite:
   - `README.md`: template header/event links + **Project overview / Run the project / Current status** sections filled with real values, followed by the existing Gloamthread README content. TODOs that cannot be truthfully filled yet are left as explicit TODO.
   - `AGENTS.md`: keep the Gloamthread game guide; append a **"Repository workflow (hackathon template)"** section (changelog/AI usage/commit cadence/credential rules) and link `RULES.md`. The template's generic AGENTS.md text is preserved there, not lost.
   - `RULES.md`, `CHANGELOG.md`, `AI_USAGE.md`, `SUBMISSION.md`, `.github/pull_request_template.md`: copied in; placeholder rows replaced with honest entries (tool recorded as "Devin CLI (Claude)", not Codex; no fabricated event timeline claims).
   - `.gitignore`: template rules + Godot (`.godot/`, `*.tmp`, `build/`, `export_presets.cfg` credentials section is not used), keep `*.import`.
3. `tools/check_pack.py` continues to pass (it scans all `*.md` links) — add the new docs to its required list.
4. CHANGELOG entries use `date -Iseconds` with the machine's timezone; never backdated.

## 3. Settled implementation decisions (gaps the docs leave open)

Recorded in `docs/DECISIONS.md` → "Implementation addenda" when implemented (AGENTS.md: choose the simplest consistent design, record it, continue).

| # | Decision | Why |
| --- | --- | --- |
| D1 | **Collision built programmatically** from the logical tile grid into one `StaticBody2D` with greedy-merged rectangle shapes (+ one-way shapes). `TileMapLayer`s are render-only, one per theme. | Structurally enforces "theme layers contain no collision"; avoids tile-seam ghost collisions; one geometry source. |
| D2 | **Rooms are JSON with ASCII tile rows** (`content/rooms/rXX.json`): `#` solid, `=` one-way, `.` empty, `^` hazard, plus entity lists (spawn pairs, anchors, bridge spans, exits, checkpoint, npc, secret, enemy spawns). Rooms 40–90 × 23–30 tiles. | Inspectable/diffable, authorable by agents, validated by Python and GDScript alike. |
| D3 | **InputRouter polls per device** each physics tick (`Input.is_joy_button_pressed(device,…)`, `get_joy_axis`, `is_physical_key_pressed`) → immutable `CommandSnapshot` per slot with edges. Gameplay never touches `Input`/InputMap. | One owner per player; remapping is data; edge flushing on pause/reconnect trivial. |
| D4 | **Keyboard/keyboard is a first-class mode**: default bindings P1 = WASD + J/K/L/U (jump/attack/special/interact) + Shift dash, P2 = arrows + numpad or `,./;` cluster; rollover caveat shown on the join screen; keyboard "device" split into two named zones. Gamepads remain selectable. | User's actual setup; MVP.md permits K/K as optional with caveat. |
| D5 | **Code-native deterministic art**: parametric part-based sprite composition with per-frame pose tables + ASCII pixel overrides for hero poses; terrain/props from material-plane shading rules with seeded clustered variation (never uniform noise). Source in `assets/source/art/`. | FIRST_AGENT_PROMPT default; no image model/API key assumed; editable source + provenance. |
| D6 | **Audio synthesised with numpy** (Karplus-Strong pluck, additive bell partials, filtered drone, shaped noise) from note tables/instrument JSON → 44.1 kHz 16-bit WAV with loop points. numpy recorded in SETUP.md/preflight. | Pure Python is too slow for 90 s stereo; numpy is an allowed tool dependency, already installed. |
| D7 | **Bitmap font** exported as BMFont `.fnt` + PNG from the 5×7 glyph source → Godot `FontFile`. Fallback: small `GlyphLabel` that blits from the atlas. | Lets Label/RichTextLabel use original glyphs. |
| D8 | **Non-positional audio**: one `AudioDirector` autoload, voice-capped `AudioStreamPlayer` pool on Music/Sfx buses; `audio_listener_enable_2d` off in both SubViewports. | One semantic event → one sound; two cameras can't double it. |
| D9 | **Saves**: `user://save/team_save.json` + `.bak`; write `.tmp` → re-parse → rotate `.bak` → rename. Settings in `user://settings.json`. Device identity stored as `{kind, guid, name}`, never OS index. | ARCHITECTURE §11 atomic/backup contract. |
| D10 | **Same-tick priorities** (scenario-tested): boss-defeat transaction before team wipe; revive completion beats timeout; rescuer damage cancels hold before progress accrues; one transition/recovery transaction at a time via `SessionCoordinator`. | TEST_PLAN §4 requires a chosen deterministic policy. |
| D11 | **Respawn policy**: ordinary enemies respawn on room (re)load; Spoolwarden and secret never; recovery reloads the checkpoint room. | Simplest documented "transient resets" policy. |
| D12 | **Tool packages**: `tools/gen/art/`, `tools/gen/audio/` owned by subagents; `tools/generate_assets.py` is a thin entry I own that calls both and writes `assets/manifest.json`. | Lets art and audio be built in parallel without write conflicts. |

## 4. Target layout (files created only as features land)

```
project.godot  export_presets.cfg  .gitignore  README.md  AGENTS.md  RULES.md  CHANGELOG.md  AI_USAGE.md  SUBMISSION.md
scenes/app/        boot, title, join, pause_menu, settings, map_overlay, ending
scenes/session/    session (SplitPresentation → 2× SubViewportContainer/SubViewport, divider, 2× HUD), hud
scenes/actors/     player, spoolmite, wickwing, spoolwarden, oru, spore_bolt
scenes/world/      room, anchor, bridge, exit_rally, checkpoint, secret_charm, loom_station
scripts/app/       app_controller.gd, settings.gd
scripts/session/   game_session.gd, session_coordinator.gd, team_progress.gd, combat_resolver.gd, recovery.gd
scripts/input/     input_router.gd, command_snapshot.gd, device_slot.gd, bindings.gd
scripts/actors/    player_controller.gd, player_motor.gd, attack.gd, enemy_base.gd, spoolmite.gd, wickwing.gd, spoolwarden.gd
scripts/world/     room_definition.gd, room_loader.gd, collision_builder.gd, world_definition.gd, anchor_pair.gd, exit_rally.gd
scripts/presentation/ follow_camera.gd, theme_presenter.gd, sprite_animator.gd, hud.gd, effects.gd
scripts/persistence/ save_repository.gd, settings_repository.gd
scripts/audio/     audio_director.gd
content/           profiles.json, themes.json, world.json, abilities.json, dialogue.json, rooms/r00..r07.json
assets/source/art/   palettes.json, couriers/, enemies/, terrain/, props/, ui/, font/
assets/source/audio/ instruments.json, cues/, music/
assets/generated/  atlases, backgrounds, font, wav  +  assets/manifest.json
tools/             generate_assets.py, validate_assets.py, validate_content.py, gen/art/, gen/audio/ (+ preflight, check_pack)
tests/             run_tests.gd, scenarios/*.gd, fixtures/
evidence/          commands.md, captures/, playtests/, performance.md
```

## 5. Milestones (dependency order, each with its gate)

Gates follow IMPLEMENTATION_PLAN.md M0–M7 / TASKS.md T01–T18. Evidence → `evidence/commands.md`, `docs/STATUS.md`, `CHANGELOG.md`.

### M0 — Reproducible start (T01) — *me*
1. Repo bootstrap (§2). `project.godot`: Compatibility, `physics_ticks_per_second=60`, viewport 960×360, window override 1920×720, stretch viewport/keep/integer, Nearest filter, `snap_2d_transforms_to_pixel`, autoloads (`AppController`, `AudioDirector`, `InputRouter`).
2. `session.tscn`: two SubViewports, shared `world_2d`, cull masks, divider overlay, diagnostic graybox room from generated placeholder PNGs flagged `diagnostic: true`.
3. `tests/run_tests.gd`: `SceneTree` script discovering `tests/scenarios/*.gd`, real physics ticks, non-zero exit on failure; first scenario = smoke load.
**Gate:** `--import` and `--script tests/run_tests.gd` pass; window shows two views of one graybox. Commit `feat: godot project shell with split presentation and scenario runner`.

### M1 — One room, two players, two cameras (T02–T05) — *me*, contracts frozen here for subagents
1. `content/profiles.json`, `themes.json`, `world.json`, `abilities.json`, `rooms/r00.json` (graybox) + typed GDScript loaders; room/asset schema documented in `docs/CONTRACTS.md` (frozen interface for subagents).
2. `InputRouter` (D3/D4) + join screen (claim device/zone per slot, forbid double claim, show assignment, rollover caveat); disconnect → pause + reassignment panel; focus-out → pause; edges flushed on resume.
3. `PlayerMotor`: 12×24 collider at origin (16,43), coyote, buffer, variable jump, air control, one-way drop-through; players never block each other; tuning in data.
4. `FollowCamera` per viewport (room bounds, smooth target, pixel-aligned display); HUD per side as Controls over each half (outside SubViewports).
5. Scenarios: ownership, no body blocking, pause freeze, single-instance world.
**Gate:** both couriers controlled simultaneously from WASD/arrows ≥5 min incl. opposite movement, simultaneous jumps, pause, ledge approaches; gamepad modes recorded unverified.

### Parallel window opens after M1 (subagents, exclusive paths)
| Subagent | Owns | Delivers |
| --- | --- | --- |
| **Art generator** | `assets/source/art/**`, `tools/gen/art/**`, `tools/validate_assets.py` (art checks) | Tavi/Neri 32 frames (288×208), Oru 8 (288×52), Spoolmite 16, Wickwing 14, Spoolwarden 32 (544×272), 48-slot terrain ×2 themes (160×120), 16 props, 3 parallax layers ×2 (480×360), 8 effects ×6 frames, 20 UI icons (100×80), font 96×48 + `.fnt`; manifest fragments with frame/pivot/state metadata |
| **Audio generator** | `assets/source/audio/**`, `tools/gen/audio/**` | instruments, 18 cues, 3 arrangements (exploration 45–90 s loop, boss 30–60 s loop, ending 15–30 s), loop points, peak checks |
| **Content/validator** | `tools/validate_content.py`, `content/rooms/r01..r07.json` drafts, `content/dialogue.json` from STORY_BIBLE | graph/ID/spawn/gate validation; ASCII room drafts per DECISIONS route; dialogue limited to the font glyph set |
| **Me (integrator)** | everything else | engine code, `generate_assets.py` entry, manifest assembly, integration, docs, commits |

### M2 — Combat and recovery (T06, T07) — *me*
Attack states + per-attack hit set; `CombatResolver` dedupe/damage/knockback/immunity; Ember Arc & Spore Bolt (slow cap, boss immune w/ cue); Spoolmite FSM with alternating target; downed 12 s / hold-revive 1.5 s / interrupts / 2 hearts + immunity; `RecoveryTransaction` (D10, D11). Scenarios for all TEST_PLAN combat/recovery cases.
**Gate:** either player defeats, rescues, recovers without softlock.

### M3 — Cooperation and shared world (T08 + theme proof) — *me*
`AnchorPair` (distinct players, latch, one permanent flag → collision + both arts once), `ExitRally` + single transition transaction with paired safe spawns, checkpoint A, global map/dialogue with one menu owner, graybox rendered in Ember and Moss, scenario proving mask swap changes zero simulation state.
**Gate:** bridge only by two distinct players; no solo exit; pause freezes all; identical geometry both views.

### M4 — Art/audio standard (T09, T10) — *integrate subagent output*
`generate_assets.py --seed 18427` → `assets/manifest.json` (SHA-256, frames, pivots, states); `validate_assets.py` (dims, rects, gutters, palette, state coverage, theme slot parity + identical edge masks, local paths, audio format/peak/loop). `SpriteAnimator` from manifest tables; `ThemePresenter` builds both TileMapLayers + decor roots + per-viewport parallax from one room definition; `AudioDirector` wiring. Capture both views at 1× and review before more rooms.
**Gate:** one finished room is the quality reference; generator/validator results recorded; captures reviewed at native resolution.

### M5 — Complete eight-room adventure (T11–T14) — *me + content subagent drafts*
r00–r04 (Oru, landmarks, prompts, anchor lesson, secret charm, checkpoint B); Wickwing; Spoolwarden (sweep / delayed strike / recoverable charge, stagger seam, Cross-stitch once per window, beatable without) → `boss_spoolwarden`, `threadstep`, `shortcut_bell` committed once; Threadstep motor gate; r06 lesson + gap + `bridge_causeway`; r07 loom stations → `loom_restored`, light chain, skippable sequence, return to r00, ending card (continue / new game swapped / menu). Objective text per flag. Scenarios: pre/post-dash, boss once, Cross-stitch either order, secret once, graph + spawn safety. Manual normal-input full route logged with duration/failures.
**Gate:** fresh-save route to ending with ordinary controls, no debug warps.

### M6 — Persistence and usability (T15, T16) — *me*
`SaveRepository` (D9) with validation, missing/corrupt/truncated/newer handling UI, write-failure notice; autosave coalesced at permanent events. `SettingsRepository` (bindings per slot, deadzone, volumes, reduced shake/flash); remap UI with conflict explanation and device-aware prompts. Hotplug during combat/revive/rally. Save/fault-injection scenarios.
**Gate:** quit/reopen continues safely; malformed saves recover visibly; reconnect never steals the other slot.

### M7 — Release candidate (T17, T18) — *me*
Install 4.7.2 Linux export templates (ask first), preset `Linux`, `--export-release`, run export outside the tree offline. Full A01–A30 matrix in `evidence/` (pass/fail/unverified), performance in r05 at 1920×720 on this laptop via `Performance` monitors → file. Two-human playtests are user-run; recorded only if they happen. Final README/SUBMISSION/CHANGELOG/AI_USAGE/STATUS; provenance summary.
**Gate:** every acceptance item has evidence or explicit unverified/blocked. Stop.

## 6. Verification per layer

| Layer | How |
| --- | --- |
| Content/asset contracts | `tools/validate_content.py`, `tools/validate_assets.py` after every content change |
| Engine load | `godot --headless --path . --import`; `--check-only` on scripts |
| Gameplay logic | `tests/run_tests.gd` scenarios with real physics ticks and synthetic `CommandSnapshot`s injected via the `InputRouter` test seam |
| Rendering | `--write-movie`/`--quit-after` 1× captures of both views under `evidence/captures/`, inspected with the image reader |
| Hardware/humans | logged manually; anything not physically done marked **unverified** |

## 7. Known blockers / will not fake
- Gamepad ownership/hotplug (A02/A03 gamepad legs) unverified until a pad exists; K/K is verified instead.
- Export templates missing → M7 export blocked until installed.
- A27 audio listening, A29 performance, A30 two-human playtests need the user/hardware; recorded only when performed.
- The corrected template permits different AI tools and providers. AI_USAGE records actual assistance as a project convention. Current organizer announcements govern event details; older template dates and credit promises are not reused.
- `docs/.~lock.STORY_BIBLE.md#` is a LibreOffice lock (user state) — left alone, git-ignored.
