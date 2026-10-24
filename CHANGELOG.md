# Change log

Record each meaningful project change, newest first. Update this file in the same commit as the change. Use a real timestamp with timezone, for example `YYYY-MM-DDTHH:MM:SS+05:30`. Never backdate an entry.

## Build log

## Agent 1 — runtime and integration

### 2026-10-24T22:10:33+05:30 — Prepare two-agent parallel execution

- Changed: Added runtime and content agent briefs with exclusive files, shared JSON/asset/audio/room contracts, staged deliverables, separate checkouts/branches and integration gates. Linked the briefs from the agent guide, handoff, README, decisions, task list and original plan. Allocated independent changelog/AI-usage sections; made the pack checker require both briefs.
- Why: Let the second agent start the original content pipeline immediately while Agent 1 completes the playable Godot foundation without competing writes or incompatible formats.
- Validation: Documentation/link/example checks and diff whitespace are run before committing this setup. Checkout/branch creation and remote publication are verified after that commit.
- Limitations: This checkpoint sets up the work; it does not implement or verify the game. Agent 2 must deliver its diagnostic packet before integrated M0 acceptance can pass.

## Agent 2 — content and assets

### 2026-10-24T22:46:23+05:30 — Align the room handoff with measured movement

- Changed: Recorded the exact full-content packet SHA and Agent 1's committed jump/headroom measurements, command and test conditions in content evidence.
- Why: Replace reliance on source-only ballistic estimates with the available real-physics evidence while keeping diagnostic measurements distinct from full-route acceptance.
- Validation: Read runtime commit `b1ff5d6` and its traversal evidence; pack/link checks and diff whitespace PASS. No asset or room data changed; previous 69-test and deterministic asset results still apply.
- Limitations: Dash remains unmeasured at that runtime checkpoint. Both-character room traversal, animation/readability, audio listening and remaining integrated MVP gates are pending Agent 1 verification.

### 2026-10-24T22:43:33+05:30 — Author the eight-room cooperative story bundle

- Changed: Authored r00-r07 with canonical bidirectional rally exits, two checkpoints, Oru, both anchor pairs, enemy lessons, secret charm, Spoolwarden arena, dash branch, loom and return. Added shared data-only fixtures, 29 content tests, read-only content validation hardening, labelled authoring previews and exact traversal/presentation requests.
- Why: Complete Agent 2's Phase 1 content inventory and give Agent 1 explicit integration data without guessing entrance, progression or asset references. Revised ascent stairs against current motor constants, widened rally rectangles to include standing feet, and fixed malformed spawn/path handling plus bridge distribution enforcement.
- Validation: Both full validators PASS; all 69 Python tests PASS. Pack and diff whitespace PASS. Native r00/r02 authoring compositions and actor sheets inspected. Earlier seed-18427 twice-rebuild hashes remain valid because this drop does not change asset sources.
- Limitations: Physical traversal, dash tuning, real engine presentation/animation, audio listening, ordinary-input playthrough, gamepads, performance, export and human acceptance remain with integrated runtime verification. Room previews are explicitly labelled authoring-only and exercise no physics. Agent 1 owns true-merge integration and main publication.

### 2026-10-24T22:40:32+05:30 — Author the complete original art and audio inventory

- Changed: Completed the full generator with courier animation, Oru, two ordinary enemies, Spoolwarden, both terrain themes, layered backgrounds, props/states, effects and UI. Added editable original audio instruments/cues/scores and synthesis for 18 cues and three arrangements. Hardened asset validation and added reproducible rebuild evidence.
- Why: Give the runtime stable production assets and semantic sound mappings while room geometry and gameplay integration continue independently.
- Validation: Full generation produces 47 manifested assets; full asset validation PASS. Asset/audio/generator suites pass 40 tests. Two rebuilds at seed 18427 produced identical output and manifest hashes. Native authoring/contact-sheet inspection performed; inner-corner orientation corrected. PCM format, peaks, loop joins and a representative simultaneous-event mix checked structurally.
- Limitations: Final room delivery follows separately. Authoring previews do not establish Godot rendering/animation; audio has not been listened to, and runtime mix, traversal, gamepads, performance, exports and human review remain unverified. Diagnostic files are retained for early-runtime compatibility but excluded from the full manifest.

### 2026-10-24T22:29:31+05:30 — Deliver Drop A diagnostic content tracer

- Changed: Added original diagnostic courier/terrain/mover sources and generator, a retained 96-glyph font source and PNG/BMFont export, provenance manifest, real fixed profiles/themes/world/dialogue and the exact r00 tracer layout. Added read-only staged asset/content validators and Python boundary tests; recorded setup and limitations in `evidence/content/README.md`.
- Why: Unblock Agent 1's one-room co-op foundation while preserving stable IDs and strict producer/consumer contracts for final art.
- Validation: Diagnostic generation and both diagnostic validators PASS; 15 Python tests PASS; preflight, pack/link checks and diff whitespace PASS. The full asset validator deliberately fails on the incomplete diagnostic bundle. Native PNG inspection covered both courier silhouettes.
- Limitations: This is diagnostic content. Full assets/rooms/audio, engine import, animation playback, listening, traversal, controllers, performance and human playtests remain unverified or unfinished. Agent 1 owns integration and main publication.

<!-- Agent 2 inserts its newest timestamped entries here. -->

## Earlier development

## 2026-10-24T21:51:38+05:30 — Prepare the template-first GitHub publication

- Changed: Kept the original organizer template commit and corrected the two unpublished project commits to `Midhun P M <midhun.titan@gmail.com>`, preserving their file trees, messages, AI attribution and author dates; retained the original local history under `refs/backup/pre-publication-20261024`. Configured the authorized `https://github.com/9MidhunPM/GloamThread.git` origin. Corrected current-state text in the README, agent guide, first build prompt, setup/decision/implementation docs, status, handoff and submission sheet; marked the original environment table as historical context.
- Why: Publish the existing development sequence under the user's normal account identity, with the template first and an accurate description of the incomplete M0 checkpoint.
- Validation: `python3 tools/preflight.py` exit 0; `python3 tools/check_pack.py` PASS; `git fsck --full` and `git diff --check` passed on the reviewed history. Account profile matches the configured name/email. Targeted credential-pattern and filename scan covered all 3 original commits / 52 unique tracked blobs with no matches; it was not a gitleaks or entropy scan. Replacement commit trees, messages and author dates match their originals.
- Limitations: Publication verification follows the push. No game implementation changed; no Godot import, gameplay, rendered, audio, controller or human-playtest check was performed.

## 2026-10-24T21:42:00+05:30 — wip: M0 engine shell started; handoff written for the next agent

- Changed: Added `project.godot` (Compatibility renderer, 60 Hz physics, 960×360 composite, integer scaling, autoloads, named render/physics layers) and the first scripts: `scripts/input/{command_snapshot,device_source,bindings,input_router}.gd`, `scripts/audio/audio_director.gd`, `scripts/world/{room_definition,collision_builder,room}.gd`, `scripts/presentation/graybox_skin.gd`. Added `HANDOFF.md` (state, decisions, exact remaining M0 steps, milestone plan, subagent split) and `docs/PLAN_PHASE1.md` (full plan). Updated `docs/STATUS.md`.
- Why: The implementing agent's session budget ran low mid-M0; a precise handoff lets the next agent (Codex) continue without re-deriving decisions.
- Validation: `python3 tools/check_pack.py` → PASS. **No Godot command has been run against the new files**; they are unparsed and unverified. The main scene, player, cameras, split presentation, session, scenario runner, diagnostic assets and `content/rooms/r00.json` do not exist yet.
- Limitations: `run/main_scene` points at `res://scenes/app/boot.tscn`, which is not created; `godot --path .` will fail until M0 step 4–8 in `HANDOFF.md` are done.

## 2026-10-24T21:25:00+05:30 — Adopt the hackathon template workflow and add the Gloamthread planning pack

- Changed: Repository history now starts from the DevDay Kochi template commit. Added the Gloamthread design pack (`MVP.md`, `PRD.md`, `FIRST_AGENT_PROMPT.md`, `docs/`, `examples/`, `tools/preflight.py`, `tools/check_pack.py`). Merged the template `README.md` (project overview, run and status sections) with the game README; appended the template's repository workflow to the game-specific `AGENTS.md`; kept `RULES.md`, `SUBMISSION.md`, `AI_USAGE.md`, the pull request template and extended `.gitignore` for Godot. Removed the template `origin` remote so nothing can be pushed to the template repository by accident.
- Why: The user asked to build on the template's rules and documentation while keeping the game's own design contract; one repository must carry both.
- Validation: `python3 tools/preflight.py` → exit 0 (Python 3.14.8, Pillow 13.0.0, Git 2.56.0, Godot 4.7.2.stable.arch_linux). `python3 tools/check_pack.py` → PASS for required documents, relative links and example contracts. No Godot project exists yet, so no import, gameplay or rendering was tested.
- Limitations: Documentation and examples only. No `project.godot`, gameplay code, assets, tests or export. Gamepads were not connected on the development machine; the primary input plan is keyboard + keyboard.

## Template setup — 10 October 2026

- Changed: Added the event README, rules, agent guide, change log, AI usage record, submission checklist, Git ignore rules, and pull request checklist.
- Why: Give participants a consistent starting point for event rules, basic coding patterns, documented changes, and regular commits.
- Validation: Checked local Markdown links, event detail consistency, required documents, and diff whitespace before publishing.
- Limitations: Documentation scaffolding only; no participant project, application, or working demo is included. GitHub publication and template status are verified separately after creation.
