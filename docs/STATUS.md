# Implementation status

Updated 2026-10-24T21:40+05:30. Keep planned work distinct from verified behaviour.

## Implemented and verified

- Repository bootstrapped on the DevDay Kochi hackathon template; documentation merged; `python3 tools/preflight.py` (exit 0) and `python3 tools/check_pack.py` (PASS, 58 links) run on the development machine with Godot 4.7.2.stable.arch_linux, Python 3.14.8, Pillow 13.0.0, numpy 2.5.4.

## Implemented, not yet verified (M0 in progress)

- `project.godot` and the first engine scripts: input contract (`CommandSnapshot`, `DeviceSource`, `Bindings`, `InputRouter` autoload), `AudioDirector` autoload, `RoomDefinition`, `CollisionBuilder`, `GrayboxSkin`, `Room`. **None of these has been parsed, imported or run by Godot yet.** The main scene, player, cameras, split presentation, session, scenario runner, diagnostic assets and `content/rooms/r00.json` are still missing; see `HANDOFF.md` §4 for the exact remaining M0 steps.

## Planned; not implemented

- M0 remainder, then M1–M7: join screen, motor polish, combat, revive/recovery, Threadweave, exits, themes and original art/audio, the eight rooms, boss, Threadstep, persistence, settings, export. Full plan in `docs/PLAN_PHASE1.md`.
- All performance, controller, visual, audio, two-human fun and complete-route acceptance results.

## Blocked or unavailable

- Gamepads: none connected; gamepad ownership and hotplug gates stay unverified until hardware is attached. Primary mode is keyboard + keyboard.
- Export templates for Godot 4.7.2 are not installed; needed at M7 (ask the user before downloading).
- Human playtests and named-device performance measurements require the user.

The older single-player HTML proof is separate evidence for a previous experiment. It does not establish any co-op acceptance criterion.
