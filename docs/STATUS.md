# Implementation status

Updated 2026-10-24T22:10:33+05:30. Keep planned work distinct from verified behaviour.

## Parallel execution setup

- Two agent briefs define exclusive ownership, shared data formats, diagnostic-first packets and separate branches/checkouts: [runtime/integration](AGENT_1_RUNTIME.md) and [content/assets](AGENT_2_CONTENT.md).
- Agent 2's assigned checkout is `/home/midhun/Coading/GloamThread-content`, branch `feat/phase1-content`; Agent 1 uses `feat/phase1-runtime` here. The preparation commit is the shared starting point. Checkout/branch creation is verified separately after the preparation commit; this documentation does not assert either agent has completed implementation.
- Agent 1 merges tested content packets and owns runtime/import/release evidence. Agent 2 records its packet SHAs and exact checks in `evidence/content/` and its named changelog/AI-usage sections. M0 remains incomplete at this setup checkpoint.

## Implemented and verified

- Repository bootstrapped on the DevDay Kochi hackathon template; documentation merged. The current review reran `python3 tools/preflight.py` (exit 0) and `python3 tools/check_pack.py` (PASS) with Godot 4.7.2.stable.arch_linux.ed1daf0bf, Python 3.14.8, Pillow 13.0.0 and numpy 2.5.4.
- Publication preparation: original template root retained; the two unpublished project commits use `Midhun P M <midhun.titan@gmail.com>` with identical trees/messages and preserved author dates. `origin` points to the user-authorized `9MidhunPM/GloamThread` repository. Git integrity and whitespace checks passed; a targeted credential-pattern/filename scan of all 52 original tracked blobs found no matches (not an entropy-based audit).

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
