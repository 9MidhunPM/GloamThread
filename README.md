# GLOAMTHREAD: TWO ENDS

> **Overhead content branch:** this checkout generates `overhead-v1` assets: 128 frames per courier, 48 terrain slots and four original music arrangements. Agent 1's matching overhead rooms/runtime are required before game launch and the integrated content gate. The preserved playable side-view milestone is on `main` at `651f08b`; this asset delivery does not replace its verification record.

**Two couriers. One unraveling kingdom. Two ways of seeing it.**

An original split-screen local co-op pixel action adventure built in Godot 4.7.2 for **Devin Hack Kochi**. Its documentation follows the [corrected event template](https://github.com/anima-regem/devin-hack-kochi-thanushreesuresh-SEOpilot/tree/codex/correct-devin-hack-kochi-thanushreesuresh): [event guidance](RULES.md), [agent guide](AGENTS.md), [change log](CHANGELOG.md), [AI usage record](AI_USAGE.md) and [submission sheet](SUBMISSION.md).

## Event guidance

Devin Hack Kochi allows Devin and other AI tools, models and providers without major AI usage constraints. We maintain an accurate AI assistance record as a project convention. Use current organizer announcements for logistics, participation, eligibility, deadlines and credits; the older shared template's details do not apply. Our offline runtime and original-content requirements are game design choices.

## Project overview

- **Project name:** Gloamthread: Two Ends
- **Short description:** Two players share one computer and one physical world, but each sees it through a different visual theme (Ember and Moss). They fight, revive each other, restore broken bridges from paired anchors and reopen the Lantern Loom so a stranded district can cross home. It is for pairs who enjoy responsive action, exploration and solving a small problem together.
- **Team:** Midhun P M ([9MidhunPM](https://github.com/9MidhunPM)) — solo, with coding-agent assistance recorded in [AI_USAGE.md](AI_USAGE.md).
- **Working demo:** the eight-room adventure, menus and save/Continue flow are implemented on `feat/phase1-runtime`; native/export checks are in progress before candidate publication. See "Current status" below.
- **Technology stack:** Godot 4.7.2 standard (typed GDScript, Compatibility renderer), Python 3 + Pillow + numpy for original asset/audio generation and validation, Git.

### Run the preserved side-view milestone

Use the published `v0.1.0-demo` source/release for these preserved launch steps. This branch's new media requires the matching overhead runtime/content integration described above.

The production game includes title/join, all eight rooms, combat, cooperation, save/Continue, settings and an ending. Twenty engine scenarios include a complete ordinary-input route; native/export acceptance is recorded separately.

1. **Prerequisites and versions:** Arch Linux (first target), Godot **4.7.2 standard** (`godot --version` → `4.7.2.stable…`, not mono), Python ≥ 3.10 with Pillow and numpy, Git. Install with `sudo pacman -Syu --needed godot git python python-pillow python-numpy`. Details in [docs/SETUP.md](docs/SETUP.md).
2. **Dependency installation:** none beyond the system packages above. No npm, .NET, C++, database or service.
3. **Environment setup:** no environment variables, API keys or accounts. Phase 1 runs offline.
4. **Import and launch:** run `godot --headless --path . --editor --import --quit`, then `godot --path .`. The current runtime uses the original production rooms, enemies and art. Choose New journey and confirm the two input assignments. P1 uses WASD, Space jump, F slash, G special, E interact/revive and Shift dash. P2 uses arrows, Period jump, Comma slash, Slash special, M interact/revive and Apostrophe dash. Esc/Enter pause; Tab/Semicolon open the map. Menu selection uses the owner's Up/Down, Jump/Interact confirm and Pause cancel. On Wayland, `godot --display-driver wayland --path .` selects the native display driver. A full normal-input automated route reaches the actual ending; physical controller and fresh-pair playtests are still pending.
5. **Run checks or tests:**
   - `python3 tools/preflight.py` — read-only toolchain check (works now).
   - `python3 tools/check_pack.py` — event guidance, document/link and example checks.
   - `python3 tools/generate_assets.py --seed 18427` — rebuild the full original asset bundle.
   - `python3 tools/validate_assets.py` and `python3 tools/validate_content.py` — full bundle checks.
   - `python3 -m unittest discover -s tools/tests -p 'test_*.py'` — Python boundary and rebuild tests.
   - `python3 tools/gen/rebuild_check.py --seed 18427` — compare two complete output/manifest rebuilds.
   - Runtime checkout: `godot --headless --path . --editor --import --quit`, then `godot --headless --fixed-fps 60 --path . --script tests/run_tests.gd`.

### Overhead media checkpoint

The new packet has 49 original manifested assets, four-facing 128-frame couriers, four music arrangements and 19 SFX including roll. The asset validator, 100 Python tests and Godot media import pass. The old actual-content validator still rejects the new version/terrain; game launch and normal-control overhead acceptance require Agent 1's matching implementation. See [packet evidence](evidence/content/overhead/README.md).

```sh
python3 tools/generate_assets.py --seed 18427
python3 tools/validate_assets.py
python3 -m unittest discover -s tools/tests -p 'test_*.py'
```

### Preserved side-view status

The following records the earlier fixed-character milestone, not overhead gameplay acceptance.

- **Content branch:** eight authored rooms, fixed profiles, dialogue, 47 original manifested art/audio/font assets and the complete Python pipeline. Both full validators and 79 Python tests pass after content QA; two seed-18427 rebuilds matched. See [content evidence](evidence/content/README.md).
- **Runtime branch:** production catalogs/animation/audio, combat, enemies/boss, team progression, anchors/exits/recovery and validated save/settings stores are integrated. Twenty integrated engine scenarios pass, including the complete actual-App route and UI layout checks; the earlier core staged-copy check passed twelve. See [runtime evidence](evidence/runtime/commands.md) and [movement limits](evidence/runtime/traversal.md).
- **Known limitations:** native/export checks are in progress; gamepad hardware, physical keyboard rollover, audio listening and fresh two-person playtests remain unverified. Human first-clear time, balance and enjoyment are not established by the automated route. Keyboard + keyboard is the primary input mode. [STATUS.md](docs/STATUS.md) records the current boundaries.
- **Libraries, APIs, and public datasets used:** [Godot Engine](https://godotengine.org/) 4.7.2 (MIT), [Pillow](https://python-pillow.org/) (MIT-CMU), [NumPy](https://numpy.org/) (BSD-3). No game-content packs, stock art, fonts, music or sound libraries: every shipped sprite, tile, glyph, sound and line of dialogue is authored in this repository.

## Start in this order (design pack)

1. Read [the MVP](MVP.md) to see exactly what the first game contains.
2. Follow [SETUP.md](docs/SETUP.md). On Arch, the essentials are Godot standard, Git, Python, Pillow and numpy; keyboard + keyboard or two controllers are the input setups.
3. Run `python3 tools/preflight.py` and `python3 tools/check_pack.py` from this folder.
4. Build in the order given by [docs/IMPLEMENTATION_PLAN.md](docs/IMPLEMENTATION_PLAN.md) and [docs/TASKS.md](docs/TASKS.md). The first build gate is one room with two independent inputs, two cameras and one world.
5. Inspect the resulting playable milestone, then continue through the complete eight-room adventure before beginning generation.

## The first game

Tavi, an Ember courier, and Neri, a Moss courier, carry the two ends of a living thread through the Weftlands. They must reopen the Lantern Loom before their village's paths unravel. Each sees a different visual interpretation of the same ruins. Their platforms, enemies, hazards, doors and progress remain shared.

- Godot 4.7.2 standard, typed GDScript, Linux desktop first.
- Fixed vertical split screen: two 480×360 views, 960×360 logical composite, nearest filtering and integer scaling.
- Two fixed original characters, two theme presets, eight authored rooms, two enemy types, one miniboss, partner revival, cooperative bridge restoration, shared dash unlock, checkpoints, save/continue, a secret and an ending.
- First-clear target 15–20 minutes, to be measured with real players.
- All game art, animation, music, sound, glyphs, dialogue and maps authored within the project. Engine/tool downloads are permitted; game-content packs are not.
- Phase 1 runs offline and needs no API key, server, account or AI model at runtime.

## Pack map

| File | Use it for |
| --- | --- |
| [Agent 1 brief](docs/AGENT_1_RUNTIME.md) | Godot runtime, integration, verification and release on `feat/phase1-runtime` |
| [Agent 2 brief](docs/AGENT_2_CONTENT.md) | Hand this to the second agent: original content/assets/audio and Python tooling on `feat/phase1-content` in a separate checkout |
| [HANDOFF.md](HANDOFF.md) | **Start here if you are the next agent:** current state, decisions, exact next steps |
| [PLAN_PHASE1.md](docs/PLAN_PHASE1.md) | Full Phase 1 milestone plan with gates and verification |
| [MVP.md](MVP.md) | Exact first-release scope, route, controls, acceptance and cuts |
| [PRD.md](PRD.md) | Product requirements, player paths and larger-world direction |
| [AGENTS.md](AGENTS.md) | Persistent rules for coding agents, including the repository workflow |
| [RULES.md](RULES.md) | Devin Hack Kochi guidance and the corrected template reference |
| [FIRST_AGENT_PROMPT.md](FIRST_AGENT_PROMPT.md) | The build request that started the implementation |
| [SETUP.md](docs/SETUP.md) | What to install first, hardware checks and run/export commands |
| [DECISIONS.md](docs/DECISIONS.md) | Canonical names, scope, rules, dimensions and implementation addenda |
| [ARCHITECTURE.md](docs/ARCHITECTURE.md) | Shared simulation, cameras, inputs, theme layers, saves and contracts |
| [IMPLEMENTATION_PLAN.md](docs/IMPLEMENTATION_PLAN.md) | Ordered milestones and completion gates |
| [TASKS.md](docs/TASKS.md) | Dependency-ordered jobs for agents |
| [STORY_BIBLE.md](docs/STORY_BIBLE.md) | World, characters, playable story beats and larger arc |
| [ART_AUDIO_PIPELINE.md](docs/ART_AUDIO_PIPELINE.md) | Original art/audio generation and quality requirements |
| [TEST_PLAN.md](docs/TEST_PLAN.md) | Automated scenarios, real hardware tests and fun/playtest gates |
| [TRACK_ALIGNMENT.md](docs/TRACK_ALIGNMENT.md) | Track wording, fit and a concrete demonstration script |
| [GENERATION_ROADMAP.md](docs/GENERATION_ROADMAP.md) | Later drawings/uploads, character generation and per-player textures |
| [STATUS.md](docs/STATUS.md) | Honest current state and ongoing progress log |
| [VALIDATION.md](docs/VALIDATION.md) | Checks performed on the starter pack |
| [CHANGELOG.md](CHANGELOG.md) | Timestamped development record |
| [AI_USAGE.md](AI_USAGE.md) | What coding agents did, and how it was reviewed |
| [SUBMISSION.md](SUBMISSION.md) | Submission sheet and checklist |
| [Examples](examples/README.md) | Fixed profiles, theme settings, world graph and team save illustrations |

## Later phases

**Phase 2:** drawing/upload → interpreted traits → bounded profile → original character appearance and a validated visual-theme bundle. Start with supported body templates, then add constrained generated character art and finite texture slots. Keep fixed characters as the offline fallback and regression baseline.

**Phase 3:** expand the finished game region by region toward the planned 96-room world: Lantern Rest hub and six regions. Room count is a production budget, not evidence of playability. Do not generate a huge empty map to satisfy it.

The strongest track fit is **Make Room for Play**. The defining demonstration is two people cooperating in one world while seeing it differently. Fun must be earned through playtesting; a specification cannot guarantee it.
