# GLOAMTHREAD: TWO ENDS

**Two couriers. One unraveling kingdom. Two ways of seeing it.**

An original split-screen local co-op pixel action adventure built in Godot 4.7.2. This repository started from the [DevDay Exchange Community Hackathon: Kochi template](https://github.com/anima-regem/devday-kochi-hackathon-template) and follows its repository workflow: [event rules](RULES.md), [agent guide](AGENTS.md), [change log](CHANGELOG.md), [AI usage record](AI_USAGE.md) and [submission sheet](SUBMISSION.md).

## Project overview

- **Project name:** Gloamthread: Two Ends
- **Short description:** Two players share one computer and one physical world, but each sees it through a different visual theme (Ember and Moss). They fight, revive each other, restore broken bridges from paired anchors and reopen the Lantern Loom so a stranded district can cross home. It is for pairs who enjoy responsive action, exploration and solving a small problem together.
- **Team:** Midhun P M ([9MidhunPM](https://github.com/9MidhunPM)) — solo, with coding-agent assistance recorded in [AI_USAGE.md](AI_USAGE.md).
- **Working demo:** not available yet. An offline desktop build is planned; see "Current status" below.
- **Technology stack:** Godot 4.7.2 standard (typed GDScript, Compatibility renderer), Python 3 + Pillow + numpy for original asset/audio generation and validation, Git.

### Run the project

Commands marked *planned* become usable when the milestone that creates them lands; see [Current status](#current-status).

1. **Prerequisites and versions:** Arch Linux (first target), Godot **4.7.2 standard** (`godot --version` → `4.7.2.stable…`, not mono), Python ≥ 3.10 with Pillow and numpy, Git. Install with `sudo pacman -Syu --needed godot git python python-pillow python-numpy`. Details in [docs/SETUP.md](docs/SETUP.md).
2. **Dependency installation:** none beyond the system packages above. No npm, .NET, C++, database or service.
3. **Environment setup:** no environment variables, API keys or accounts. Phase 1 runs offline.
4. **Start the project:** `godot --path .` *(planned — arrives with milestone M0)*.
5. **Run checks or tests:**
   - `python3 tools/preflight.py` — read-only toolchain check (works now).
   - `python3 tools/check_pack.py` — planning-pack document/link/example check (works now).
   - `python3 tools/validate_content.py`, `python3 tools/generate_assets.py --seed 18427`, `python3 tools/validate_assets.py` *(planned)*.
   - `godot --headless --path . --editor --import --quit` — register scripts on a fresh checkout; currently reports the missing boot scene, so this is not a complete-game import pass.
   - `godot --headless --path . --script tests/run_tests.gd` — input/room component scenarios; also available as `bash tools/run_tests.sh`, with optional `-- --filter room_loading`.

### Current status

- **Current implementation:** M0 is in progress. Project/input/audio/room scaffolding and a built-in scenario runner exist. Two real-engine component scenarios pass for input routing/bindings and room validation; the editor scan registers scripts but reports the missing boot scene. See [runtime evidence](evidence/runtime/commands.md), [HANDOFF.md](HANDOFF.md) and [docs/STATUS.md](docs/STATUS.md).
- **Known limitations:** the main scene, player/session controllers, cameras, room content, generated assets, saves and export are missing, so the game is not runnable yet. Keyboard + keyboard (WASD / arrows) is the primary input mode to build and verify. Physical input, rendered gameplay and audio remain unverified.
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
| [RULES.md](RULES.md) | Hackathon event rules from the template (organizer text) |
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
