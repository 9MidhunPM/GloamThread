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
