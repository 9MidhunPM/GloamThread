# GLOAMTHREAD: TWO ENDS

**Two couriers. One unraveling kingdom. Two ways of seeing it.**

An original split-screen local co-op pixel action adventure built in Godot 4.7.2 for **Devin Hack Kochi**. Its documentation follows the [corrected event template](https://github.com/anima-regem/devin-hack-kochi-thanushreesuresh-SEOpilot/tree/codex/correct-devin-hack-kochi-thanushreesuresh): [event guidance](RULES.md), [agent guide](AGENTS.md), [change log](CHANGELOG.md), [AI usage record](AI_USAGE.md) and [submission sheet](SUBMISSION.md).

## Event guidance

Devin Hack Kochi allows Devin and other AI tools, models and providers without major AI usage constraints. We maintain an accurate AI assistance record as a project convention. Use current organizer announcements for logistics, participation, eligibility, deadlines and credits; the older shared template's details do not apply. Our offline runtime and original-content requirements are game design choices.

## Project overview

- **Project name:** Gloamthread: Two Ends
- **Short description:** Two players share one computer and one physical world, but each sees it through a different visual theme (Ember and Moss). They fight, revive each other, restore broken bridges from paired anchors and reopen the Lantern Loom so a stranded district can cross home. It is for pairs who enjoy responsive action, exploration and solving a small problem together.
- **Team:** Midhun P M ([9MidhunPM](https://github.com/9MidhunPM)) — solo, with coding-agent assistance recorded in [AI_USAGE.md](AI_USAGE.md).
- **Working demo:** a diagnostic runtime tracer is verified on `feat/phase1-runtime`; the full eight-room game and exported demo are not complete. See "Current status" below.
- **Technology stack:** Godot 4.7.2 standard (typed GDScript, Compatibility renderer), Python 3 + Pillow + numpy for original asset/audio generation and validation, Git.

### Run the project

The content branch supports the Python commands below. Launch and engine scenarios require Agent 1's runtime checkout or the integrated branch; this content branch does not contain its boot/session implementation yet.

1. **Prerequisites and versions:** Arch Linux (first target), Godot **4.7.2 standard** (`godot --version` → `4.7.2.stable…`, not mono), Python ≥ 3.10 with Pillow and numpy, Git. Install with `sudo pacman -Syu --needed godot git python python-pillow python-numpy`. Details in [docs/SETUP.md](docs/SETUP.md).
2. **Dependency installation:** none beyond the system packages above. No npm, .NET, C++, database or service.
3. **Environment setup:** no environment variables, API keys or accounts. Phase 1 runs offline.
4. **Start the runtime tracer:** `godot --path .` from the runtime/integrated checkout. The complete adventure still needs runtime integration and acceptance checks.
5. **Run checks or tests:**
   - `python3 tools/preflight.py` — read-only toolchain check (works now).
   - `python3 tools/check_pack.py` — event guidance, document/link and example checks.
   - `python3 tools/generate_assets.py --seed 18427` — rebuild the full original asset bundle.
   - `python3 tools/validate_assets.py` and `python3 tools/validate_content.py` — full bundle checks.
   - `python3 -m unittest discover -s tools/tests -p 'test_*.py'` — Python boundary and rebuild tests.
   - `python3 tools/gen/rebuild_check.py --seed 18427` — compare two complete output/manifest rebuilds.
   - Runtime checkout: `godot --headless --path . --editor --import --quit`, then `godot --headless --fixed-fps 60 --path . --script tests/run_tests.gd`.

### Current status

- **Content branch:** eight authored rooms, fixed profiles, dialogue, 47 original manifested art/audio/font assets and the complete Python pipeline. Both full validators and 69 Python tests passed at delivery; two seed-18427 rebuilds matched. See [content evidence](evidence/content/README.md).
- **Runtime branch:** Agent 1's `b1ff5d6` checkpoint integrates the diagnostic packet with one shared world, two owned-input couriers, split views, engine scenarios and measured movement. Its first window capture is a diagnostic snapshot. Production content integration remains separate from these results.
- **Known limitations:** the complete combat/recovery/cooperation/boss/dash/loom/save loop is not accepted. Physical room traversal, animation, listening, ordinary-input playthrough, gamepad hardware, export, performance and human playtests remain pending. Keyboard + keyboard is the primary input mode. [STATUS.md](docs/STATUS.md) records the current boundaries.
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
