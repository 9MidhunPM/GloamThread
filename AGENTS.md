# Gloamthread — agent guide

## Active mission

Build and maintain the approved solo/two-player shared-screen wave fighter in [docs/WAVE_FIGHTER_SPEC.md](docs/WAVE_FIGHTER_SPEC.md). It supersedes the previous campaign/overhead requirements. The current approved extension is [docs/SCROLLING_WORLD_PLAN.md](docs/SCROLLING_WORLD_PLAN.md). Read [docs/STATUS.md](docs/STATUS.md) first for actual implementation/evidence; use [README.md](README.md) and [docs/ARENA_DEMO.md](docs/ARENA_DEMO.md) to launch. The old campaign and overhead branches/evidence remain historical references, not acceptance of the current game.

Twenty waves, four stages/bosses, optional endless, personal last-hit wallets and between-wave shops; fixed roster per run. Run power resets. Saved creations/settings/scores persist. Three body rigs and six game-owned ability families support drawn/uploaded characters. Current original and retained-generation content must remain reproducible.

The user also restored the original eight-room Tavi/Neri story as a separate selectable mode. Preserve **STORY MODE (2 PLAYERS)** → `scenes/app/boot.tscn` and the save-safe return to `scenes/arena/boot.tscn`. Each mode has one active scene/world and restores its logical size; do not remove this mode as obsolete campaign scaffolding. The source includes name-led fighter art/kit selection; v0.4 binaries predate both changes.

## Runtime boundaries

- Godot4.7.2standard, typed GDScript, Compatibility, Python3authoring. One authoritative shared world, merged/split scrolling cameras, one audio mix. Target1920×1080with640×360nearest/integer pixel world; letterbox other aspect ratios.
- Godot60Hzphysics owns combat/timers. Pause/focus/device loss freezes shared combat without wall-clock catch-up. One owned input source per player; flush held actions at mode transitions, preserve simultaneous shop confirmations.
- No friendly fire/body blocking. Gameplay-owned colliders, timing, stats and finite ability IDs remain independent of images/body rigs. Generated content never supplies scripts, paths or executable behaviour.
- Session alone owns wave clear/wipe, rewards, revival, shops and results. Reward each accepted death once to lethal source; DOT/chain/projectiles retain ownership. Resolve final clear before same-tick wipe. Both shop panels must ready before advancing.
- Network/model calls are optional pregame authoring through a separate local Python worker. Credentials stay in ignored.env, outside Godot/exports/logs. The user removed local total and per-character dollar caps. Keep durable request estimates/history, explicit Analyse/Generate actions and no automatic retries, fallback or ledger resets. Cached crop/mask/pivot corrections use SDK-free local conversion.
- A candidate is accepted only after full bundle admission. Preserve previous accepted art/jobs on failure, retain source/provenance and display genuine errors. Save settings/scores/creation libraries separately from run power.

## Content and ownership

Use [the shared spec](docs/WAVE_FIGHTER_SPEC.md) for interfaces, [Agent2brief](docs/AGENT_2_WAVE_CONTENT.md) for content work and [asset workflow](docs/AI_ASSET_WORKFLOW.md) for generation/correction. Only the integrator changes entry points/contracts/packaging and merges main. Parallel workers need exclusive files and agreed interfaces; preserve other workers' edits.

All art, animation, scenery, font, UI cues, music and sound must be authored here or retained original generation with provenance. No resource packs, downloaded replacements, stock art/audio or copied characters/maps/UI. Use reference games only for broad qualities. Inspect actual native captures/animation; manifest counts alone do not establish quality.

## Verification and completion

```sh
python3 tools/check_pack.py
python3 -m unittest discover -s tools/tests -p 'test_*.py'
python3 -m tools.forge.content --validate
python3 -m tools.forge.retained --validate
godot --headless --path . --editor --import --quit
godot --headless --fixed-fps 60 --path . --script tests/arena/run_tests.gd
godot --headless --fixed-fps 60 --path . --script tests/forge/run_tests.gd
```

Videos: `./showcase.sh --record FILE.ogv` / `./story_showcase.sh --record FILE.ogv` use Godot Movie Maker (1920×1080, 30 FPS). Movie Maker scales the root viewport texture to cover 16:9, so non-16:9 canvases need a 16:9 movie canvas. Publish MP4 transcodes as release assets; keep only small stills and the intro in `docs/media/` (which has `.gdignore`). Arena accessibility settings are covered by `tests/arena/accessibility.gd`; see [docs/ACCESSIBILITY.md](docs/ACCESSIBILITY.md).

Only explicit authoring rebuilds should run `python3 -m tools.forge.content --build --validate` because it replaces deterministic output. `tools/package_arena.py` requires a clean committed checkout and matching Linux templates. Record exact source/command/engine/display/input and limitations. Ordinary-input routes, controlled recovery fixtures, native render profiles, exported offline checks, physical devices and human playtests are distinct evidence. Never fabricate captures, billing, performance, listening or enjoyment.

Finish the requested milestone and authorized scope, keep STATUS current, and report remaining material gates precisely. Preserve the earlier released demo and honest Git history. Do not expand to networking, arbitrary generated behaviour or the obsolete96room plan.

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
