# Runtime checkpoint — 2026-10-24

Recorded 2026-10-24T22:23:11+05:30 on Agent 1's `feat/phase1-runtime` branch. Engine: `4.7.2.stable.arch_linux.ed1daf0bf`; standard build, headless on Linux. Project physics configuration: 60 Hz. This checkpoint does not launch a playable session.

## Parallel setup

Preparation commit: `2fea1efd39d42b8b148f384449a56f83bc9d7f7b`, published to `main` and the initial `feat/phase1-runtime` / `feat/phase1-content` branches. The second clone at `/home/midhun/Coading/GloamThread-content` was created from that commit, switched to the content branch, configured as `Midhun P M <midhun.titan@gmail.com>` and verified clean at setup. Its brief is `docs/AGENT_2_CONTENT.md`. Runtime changes after preparation stay on Agent 1's branch.

## Commands and actual outcomes

| Command | Outcome |
| --- | --- |
| `python3 tools/check_pack.py` | PASS: documents/81 links, example profiles/themes, abstract graph and save illustration at preparation; rerun for current docs before committing |
| `git diff --check` | PASS before preparation commit; rerun for runtime checkpoint |
| `godot --headless --path . --editor --import --quit --log-file /tmp/gloamthread-runtime-import.log` | Exit 0; registered 13 scripts/classes and created `.uid` metadata, **but reported missing `res://scenes/app/boot.tscn`**. Not a clean complete-game import or launch pass |
| `godot --headless --path . --script tests/run_tests.gd --log-file /tmp/gloamthread-runtime-scenarios-final.log` | Exit 0: input_routing and room_loading PASS, 2 passed / 0 failed after the final fix. Expected warnings come from malformed-binding and duplicate-device negative cases |
| `godot --headless --path . --script tests/run_tests.gd --log-file /tmp/gloamthread-runner-no-match.log -- --filter no_such_scenario` | Expected exit 1: no matching scenario; prevents an empty filtered run from appearing successful |
| `bash tools/run_tests.sh -- --filter room_loading` | Exit 0: one selected scenario passed; wrapper resolved project root and forwarded arguments |

The new held-stick regression initially failed: flushing omitted directional actions from its latch. Adding directional latching and gating analog strengths by the filtered held state fixed it; the final two-scenario run passed. The retained scenario protects menu/reconnect input flushing.

## What the checks establish

- Real Godot input-event parsing with synthetic gamepad IDs 11/12, reconnect IDs 13/14, and a deliberately shared fixture GUID/name. No physical controllers were involved.
- Saved binding/prompt JSON round trips, malformed-control fallbacks, explicit unbinding, remapped analog axes/deadzone, separate slot ownership, neutral disconnected input and single-slot reconnect matching.
- A held analog direction and held jump are suppressed after flush until release/neutral; no physical gamepad feel or hotplug hardware acceptance is claimed.
- Canonical room feet conversion, integer JSON coordinates, malformed/ragged rows, upper dimension bounds, distinct paired spawns, full body headroom, real in-bounds support and stable entity IDs.
- The asynchronous scenario runner has a 30-second wall-clock timeout. A synchronous infinite loop can block Godot's main thread and requires an external process timeout.

The temporary isolated input harness also passed 80 checks before integration. Its first editor import had sandbox cache/socket errors and an approval-infrastructure failure; only the later non-editor input checks were successful. The repository scenarios above are the committed reproducible evidence.

## Still missing or unverified

Boot/session/player/cameras, real room/content/assets from Agent 2, rendered split screen, shared gameplay pause, collision/movement/combat, full entity-schema validation, audio playback, actual keyboard/gamepad ownership, saves, the eight-room route, export/performance and human playtests. Neither these component scenarios nor the import process's zero exit code passes the integrated M0 gate.
