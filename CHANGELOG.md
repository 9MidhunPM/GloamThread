# Change log

Record each meaningful project change, newest first. Update this file in the same commit as the change. Use a real timestamp with timezone, for example `YYYY-MM-DDTHH:MM:SS+05:30`. Never backdate an entry.

## Build log

## Agent 1 — runtime and integration

### 2026-10-24T22:32:31+05:30 — Add the shared session and motor before content integration

- Changed: Added boot/session scenes, one authoritative world with two viewports/cameras/HUDs, a manifest image boundary, owned player motor and stable sprite pivot, diagnostic mover, shared focus/pause overlay and an explicit test-only room fixture. Production boot reports missing content rather than substituting test geometry.
- Why: Complete the runtime side of the first parallel handoff and test real physics/session ownership before merging Agent 2's first packet.
- Validation: Fresh headless editor import exited 0 without resource/script errors. The real-session fixture smoke scenario passed: one world/room/mover, two independent nonblocking players, stable grounding, diverging cameras, masks, jump and shared pause/resume. The isolated motor/camera harness passed 19 checks. Visual, actual device and production-content checks remain pending.
- Limitations: This pre-merge checkpoint has no production content/assets yet. The explicit fixture disables art only for engine tests; it cannot satisfy rendered or ordinary-input acceptance. Full manifest/entity validation, one-way drop-through, combat and later milestones are outstanding.

### 2026-10-24T22:23:11+05:30 — Start runtime verification and harden input/room data

- Changed: Added the built-in scenario runner/filter/timeout and shell wrapper, input and room boundary scenarios, generated script UID metadata and runtime evidence. Validated saved controls and analog remapping, neutralized disconnected inputs, prevented duplicate identical-pad reconnect claims, and latched held movement/actions across flush. Room parsing rejects malformed geometry/fractional coordinates/oversized layouts and unsafe or duplicated paired spawns without indexing invalid rows or treating outside-room sentinels as real floors. Updated current setup/status/command instructions.
- Why: Give Agent 1 reproducible engine checks and repair scaffold defects before the parallel content pipeline supplies real rooms/assets.
- Validation: Final Godot run: 2 scenarios passed / 0 failed; wrapper's room filter passed; nonexistent-filter run correctly exited 1. A new held-stick regression first failed and then passed after directional latching was fixed. Editor scan registered 13 scripts but reported the still-missing boot scene despite exit 0; not a complete import/launch pass. Exact commands/configuration and remaining gaps are in `evidence/runtime/commands.md`; pack and whitespace checks run before commit.
- Limitations: Synthetic input only; no physical devices, visible split screen, gameplay, audio, performance or human playtest. Boot/session/player/cameras and Agent 2's authored content remain outstanding; full entity schema validation is not yet implemented.

### 2026-10-24T22:10:33+05:30 — Prepare two-agent parallel execution

- Changed: Added runtime and content agent briefs with exclusive files, shared JSON/asset/audio/room contracts, staged deliverables, separate checkouts/branches and integration gates. Linked the briefs from the agent guide, handoff, README, decisions, task list and original plan. Allocated independent changelog/AI-usage sections; made the pack checker require both briefs.
- Why: Let the second agent start the original content pipeline immediately while Agent 1 completes the playable Godot foundation without competing writes or incompatible formats.
- Validation: Documentation/link/example checks and diff whitespace are run before committing this setup. Checkout/branch creation and remote publication are verified after that commit.
- Limitations: This checkpoint sets up the work; it does not implement or verify the game. Agent 2 must deliver its diagnostic packet before integrated M0 acceptance can pass.

## Agent 2 — content and assets

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
