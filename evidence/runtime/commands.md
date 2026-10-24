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

## Shared-session checkpoint — 2026-10-24T22:32:31+05:30

The missing boot/session/player/cameras above have now been implemented. `godot --headless --path . --editor --import --quit --log-file /tmp/gloamthread-session-import.log` exited 0 without resource/script errors. `godot --headless --fixed-fps 60 --path . --script tests/run_tests.gd --log-file /tmp/gloamthread-session-smoke.log -- --filter smoke_session` exited 0: the real session and Godot physics passed one shared room/world/mover, two players, grounded feet, independent movement/jump, body overlap, diverging bounded cameras and shared pause/resume. This scenario explicitly uses `tests/fixtures/m0_room.json` and disables art; normal boot never uses that fixture. No rendered or ordinary-input proof is claimed before Agent 2's packet is merged.

## First content integration — 2026-10-24T22:40:57+05:30

Packet `34e14c96d9c2e78d94007b55ac7af5794b5157ec` was merged cumulatively. Both `python3 tools/validate_assets.py --stage diagnostic` and `python3 tools/validate_content.py --stage diagnostic` passed; `python3 -m unittest discover -s tools/tests -p 'test_*.py'` passed 15 tests. Full-stage completeness is deliberately not asserted.

The integrated suite `godot --headless --fixed-fps 60 --path . --script tests/run_tests.gd --log-file /tmp/gloamthread-integrated-scenarios.log` passed all four scenarios with no script errors; malformed-binding/duplicate-source warnings are expected negative cases. An `evidence/.gdignore` marker excludes retained captures/docs from game-resource import and export.

`godot --headless --path . --editor --import --quit --log-file /tmp/gloamthread-content-import.log` imported six PNG/font resources without errors. `godot --headless --path . --quit-after 120 --log-file /tmp/gloamthread-boot.log` exited 0 with normal startup and no errors. The actual-content scenario command in [traversal.md](traversal.md) passed and produced the retained movement measurements.

An actual app was launched on a hidden Hypruse agent workspace using `godot --path /home/midhun/Coading/Gloamthread --log-file /tmp/gloamthread-visible.log`; renderer was Compatibility/OpenGL 4.6, Mesa 26.2.5, Intel Arc (ARL). [Initial window capture](captures/m0-initial-window.png) is the unmodified window PNG at 2840×1713 pixels; monitor scale 1.25, compositor logical window 2272×1370. It shows equal letterboxed views, both diagnostic couriers, divider and Ember/Moss terrain tints. Because the window was hidden, this proves a rendered initial state, not continuous playback or actual input. The compositor may return stale hidden-window frames.

Hypruse refused background keys to the XWayland window to protect the human's focus. A second launch with `--display-driver wayland` accepted one addressed `d` sendshortcut while leaving human focus untouched, but its subsequent hidden-window screenshot was black. Therefore visible ordinary-key movement, simultaneous physical keyboard actions and motion/pause capture remain unverified. No foreground takeover or human playtest was performed.
