# Gloamthread: Two Ends — agent guide

## Mission and current state

Build the user-requested original **overhead** local two-player adventure. Read [the overhead plan](docs/OVERHEAD_PLAN.md) and [frozen contract](docs/OVERHEAD_CONTRACT.md) before the older MVP/architecture documents. The new overhead movement, terrain, animation and save contracts replace their side-view assumptions. Preserve Tavi/Neri, fixed split/shared world, original content, eight-room story, responsive combat and cooperation. Continue clear UI/music/screens/experience polish, meaningful atomic commits and regular tested main integration; the user's target exceeds200commits by the end of the effort.

The verified side-view milestone is taggedv0.1.0-demo, with release evidence in docs/STATUS.md. Its tests/captures do not prove overhead gameplay. Root is integrator; lane workers and Agent2 use separate checkouts and exclusive ownership. No empty/padded/backdated commits or rewritten shared history.

## Context map

For the current two-agent build, read [Agent 1](docs/AGENT_1_RUNTIME.md) or [Agent 2](docs/AGENT_2_CONTENT.md) according to the assigned role. Their separate-checkout ownership replaces the older three-worker split in the handoff. Both agents follow the shared data contract in Agent 2's brief; only Agent 1 integrates to `main`.

1. Read README.md, MVP.md and docs/DECISIONS.md before implementing.
2. Follow docs/IMPLEMENTATION_PLAN.md and docs/TASKS.md for dependency order.
3. Read docs/ARCHITECTURE.md before changing simulation, inputs, views or saves.
4. Read docs/ART_AUDIO_PIPELINE.md before authoring content, and docs/STORY_BIBLE.md before adding rooms/dialogue.
5. Use docs/TEST_PLAN.md for acceptance evidence; use PRD.md for wider product requirements.
6. Read docs/GENERATION_ROADMAP.md only when working on its later phase. It must not expand the Phase 1 task.

The latest user instruction outranks these documents. For routine gaps, choose the simplest design consistent with the current slice, record the choice and continue. Resolve document inconsistencies against docs/DECISIONS.md rather than silently implementing conflicting variants.

## Scope and original content

- Godot 4.7.2 standard, typed GDScript, Compatibility renderer, Python 3 asset tools; Linux/Arch first. Do not switch to C++, web or .NET without a user-requested scope change.
- Fixed characters: Tavi and Neri. Threadweave restores predefined bridges through two distinct player-activated anchors. Threadstep is the team dash unlock. Cross-stitch is an optional boss stagger follow-up.
- Eight rooms r00–r07, two enemy types, Spoolwarden miniboss, Oru, two checkpoints, one secret, two visual theme presets and an ending. See MVP.md for the complete boundary.
- Phase 1 has no upload UI, image-generation service, runtime model calls, online/LAN networking, dynamic split/merge camera, independent cross-room exploration, crafting or arbitrary rope/terrain physics.
- No downloaded/bought resource packs, stock sprites, music, sound libraries, game maps or font packs. Tools and engine dependencies are allowed. Original retained image-generation outputs may be used with provenance and asset QA; do not download replacements when generation is unavailable.
- Author coherent sprite shapes, animation, tiles, scenery, UI glyphs, sound and music in editable sources/generators. Random coloured noise or repeated rectangles are not a finished art direction. Retain source and metadata for every shipped asset.
- Use named reference games for broad qualities only. Do not reproduce their characters, signature silhouettes, maps, art, writing, music or UI.

## Architectural invariants

- One shared authoritative World2D; one instance of each gameplay actor, collision layout, trigger, reward and progression state. Each player's SubViewport has a camera and HUD, not a second simulation.
- Render-only Ember/Moss visual layers can vary by viewport. They contain no collision bodies, scripts with gameplay effects, enemy AI or reward triggers. Validate masks and parent visibility rules in the real engine.
- Logical composite 960×360; each view 480×360; overlay divider. Tiles 16×16; character frames 32×48. Nearest sampling, integer scaling/letterboxing and pixel-stable render origins. Simulation positions may remain floating point.
- Physics at 60 Hz. Godot physics processing owns gameplay timers; do not add a second accumulator. Pause, focus loss, device disconnect, dialogue and map pause the shared world consistently. Resume never applies a wall-clock catch-up burst.
- One input owner per player. Never bind a player's actions to all gamepads or use unfiltered global action state for both players. Flush held actions when entering/leaving menus and reconnecting devices.
- No friendly fire or player-body blocking. Hurtboxes and collisions are independent of art, theme and animation frame size.
- Both players stay in one active room. Exit rally zones require both living players; room replacement happens once through the session coordinator, and both spawn safely.
- Team unlocks, boss outcomes, restored bridges and unique secrets are committed once. Permanent traversal is shared and cannot be removed by a generated character profile later.
- Death/revive/timeout and checkpoint reset have explicit state transitions. Freeze encounter updates during recovery/transition. Both views observe the same health, boss and reward state.
- Audio events play once through a shared mix. Do not double audio because there are two cameras/listeners.
- Save team progress and load at a validated checkpoint; version the format, preserve a last-known-good backup and handle write/corruption failure visibly. Device bindings/settings are separate from campaign progress.
- Fixed profiles and future generated profiles cross the same validated data boundary. No executable behaviour or arbitrary file paths from generated content. Do not build the future backend to prove this boundary.

## Working rhythm

Inspect the repository and current status before editing. Preserve unrelated user work. Implement a playable one-room co-op foundation before creating all eight rooms. Integrate at each milestone; do not build a generic engine, ECS, custom editor or framework first.

When delegating, give each worker exclusive files/subsystems and agreed interfaces. Only the integrator changes the project entry point, shared session/input contracts and final packaging concurrently. Keep docs/STATUS.md current with implemented, verified, unverified and blocked work.

Prototype visuals may be simple during movement tests. Replace them with the original art target before declaring the slice complete. Inspect real captures at native resolution and watch animation/audio; a manifest count does not prove quality.

## Commands and evidence

Available content/tool checks:

```sh
python3 tools/preflight.py
python3 tools/check_pack.py
python3 tools/generate_assets.py --seed 18427
python3 tools/validate_assets.py
python3 tools/validate_content.py
python3 -m unittest discover -s tools/tests -p 'test_*.py'
```

Run these engine commands in the runtime/integrated checkout; Agent 1 owns authoritative imports and runtime evidence:

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --script tests/run_tests.gd
godot --path .
```

Use high-level scenario tests around input ownership, simultaneous attacks, one hit per swing, single boss/reward state, revive and team wipe, paired anchors, pre/post-dash routes, exit rally, save/continue, device loss and pause. Check content and provenance separately. A built-in GDScript scenario runner is sufficient; do not require an external testing addon by default.

Record exact commands and outcomes, test configuration, device assignments, engine version and any limitations. A source check or headless import does not prove rendered split screen, correct gamepad behaviour, audio or fun. Debug teleports may isolate a state but never replace a full normal-input playthrough. Never fabricate screenshots, performance numbers or human playtests.

## Completion

Finish the requested milestone, then proceed through the authorized Phase 1 work until the complete MVP passes its gates or a material blocker prevents further progress. Do not stop at a plan or scaffolding when asked to build. Do not expand to the 96-room target or Phase 2 generation before the current authorized scope is complete.

Report what changed, what actually ran, what remains unverified and how to launch. Document a blocker precisely and continue independent useful work where possible. Never label the whole game complete because documents, generated assets or empty rooms exist.

## Repository workflow (from the hackathon template)

This project follows the corrected **Devin Hack Kochi** template guidance in [RULES.md](RULES.md). Use current organizer instructions for event requirements. Devin and other AI tools, models and providers are permitted without major AI usage constraints. This repository maintains CHANGELOG and AI_USAGE records for traceability; that convention adds no event eligibility or provider restriction. The fixed engine, original-content boundary and offline gameplay scope are project decisions.

### Use basic coding patterns

- Prefer straightforward, idiomatic code: small functions, clear names, simple data structures, and modules with one clear responsibility.
- Use the project's existing patterns. Add an abstraction only when an actual repeated need makes the code easier to understand.
- Choose the simplest implementation that meets the current requirement. Avoid unnecessary layers, generic frameworks, premature optimization, and speculative features.
- Keep dependencies few and purposeful. Reuse appropriate standard libraries and established libraries instead of reimplementing them.
- Validate inputs, handle errors explicitly, and show useful failure messages. Do not hide failures behind fabricated success or demo data.
- Keep changes focused. Explain the reason for non-obvious decisions in short comments or project documentation.

### Document every meaningful change

- Update [CHANGELOG.md](CHANGELOG.md) in the same commit as each meaningful change. Record the date and time with timezone, what changed, why, the affected files or feature, validation performed, and known limitations.
- Update [README.md](README.md) whenever setup, commands, environment requirements, project behavior, or demo instructions change.
- Update [AI_USAGE.md](AI_USAGE.md) whenever a coding agent makes a meaningful contribution. Record the task, assistance, human review status, checks, and any corrections. Brief summaries are enough; full chat transcripts are unnecessary. Name the tool actually used.
- Keep claims accurate. Distinguish implemented and verified behavior from planned or incomplete work. Never invent test results, deployment success, AI usage, or commit timestamps.

### Make regular, timely commits

1. Inspect `git status` before editing. Preserve the user's work and identify files belonging to the current task.
2. Finish a small, coherent change, run appropriate checks, and update its documentation.
3. Review the diff and explicitly stage only the files for that change.
4. Commit after each completed milestone. While actively building, aim for a commit about every 30 minutes when meaningful changes are ready. Do not leave a whole session's work for one final commit.
5. Commit completed work before a handoff, a long break, or the end of a work session. If work is incomplete, document its state and use an honest `wip:` message for a useful checkpoint.
6. Use short, descriptive messages, such as `feat: add exit rally zone`, `fix: dedupe slash hits`, or `docs: explain local demo setup`.
7. Do not create empty commits to satisfy the clock. Do not backdate commits, squash away the development record, force-push, or rewrite shared history.
8. Push committed checkpoints only to a remote the user has authorized. This repository's template remote was removed deliberately; never push to the template repository.

### Check work and protect credentials

- Use the project's actual install, run, lint, test, and build commands. Add them to the README as soon as they exist.
- Run checks appropriate to the change. For a documentation-only change, check links and consistency (`python3 tools/check_pack.py`). For code changes, verify the changed behavior and any relevant existing tests.
- Report what ran and what passed, failed, or could not be checked. If a command fails, investigate or document the limitation before handoff.
- Keep credentials, API keys, approved QR codes, and private participant data out of commits and logs. Phase 1 needs none.

### Before submission

- Complete [SUBMISSION.md](SUBMISSION.md), replacing all placeholders with true values.
- Confirm the README gives reproducible setup and demo steps, and that the working demo matches the submitted code with known limitations disclosed.
- Update the changelog and AI usage record, commit the final coherent change, and record the final commit SHA in the submission details. Documentation may record that SHA in a subsequent commit; do not claim later implementation changes belong to the earlier demo.
