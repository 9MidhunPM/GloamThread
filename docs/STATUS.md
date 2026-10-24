# Implementation status

Updated 2026-10-24T22:23:11+05:30. Keep planned work distinct from verified behaviour.

## Parallel execution setup

- Two agent briefs define exclusive ownership, shared data formats, diagnostic-first packets and separate branches/checkouts: [runtime/integration](AGENT_1_RUNTIME.md) and [content/assets](AGENT_2_CONTENT.md).
- Preparation commit `2fea1ef` is published to `main`; both feature branches were published from it. Agent 2's separate clone at `/home/midhun/Coading/GloamThread-content` was created and verified on `feat/phase1-content`; Agent 1 uses `feat/phase1-runtime` here. No Agent 2 implementation is claimed by setup alone.
- Agent 1 merges tested content packets and owns runtime/import/release evidence. Agent 2 records its packet SHAs and exact checks in `evidence/content/` and its named changelog/AI-usage sections. M0 remains incomplete at this setup checkpoint.

## Implemented and verified

- Built-in scenario runner, focused filter, zero-match failure and wrapper; two real-engine component scenarios pass for input bindings/routing and canonical room data. Synthetic input covers identical-pad reconnect ownership, analog remapping, release latches and disconnected neutrality; room cases cover unsafe/fractional/ragged data and full-body spawn clearance. See [commands and limitations](../evidence/runtime/commands.md).
- Repository bootstrapped on the DevDay Kochi hackathon template; documentation merged. The current review reran `python3 tools/preflight.py` (exit 0) and `python3 tools/check_pack.py` (PASS) with Godot 4.7.2.stable.arch_linux.ed1daf0bf, Python 3.14.8, Pillow 13.0.0 and numpy 2.5.4.
- Publication preparation: original template root retained; the two unpublished project commits use `Midhun P M <midhun.titan@gmail.com>` with identical trees/messages and preserved author dates. `origin` points to the user-authorized `9MidhunPM/GloamThread` repository. Git integrity and whitespace checks passed; a targeted credential-pattern/filename scan of all 52 original tracked blobs found no matches (not an entropy-based audit).

## Implemented, not yet verified (M0 in progress)

- The editor scan registers scripts/classes and generates UID sidecars, but reports missing `scenes/app/boot.tscn` despite exit 0. This is not a clean integrated import/launch pass. Audio/world rendering/collision behaviour remains unverified; room validation is still a partial boundary rather than the complete entity schema.
- Main scene, player, cameras, split presentation, session, integrated smoke scenario, diagnostic assets and `content/rooms/r00.json` are missing. Continue from the two briefs and original `HANDOFF.md` M0 steps.

## Planned; not implemented

- M0 remainder, then M1–M7: join screen, motor polish, combat, revive/recovery, Threadweave, exits, themes and original art/audio, the eight rooms, boss, Threadstep, persistence, settings, export. Full plan in `docs/PLAN_PHASE1.md`.
- All performance, controller, visual, audio, two-human fun and complete-route acceptance results.

## Blocked or unavailable

- Gamepads: none connected; gamepad ownership and hotplug gates stay unverified until hardware is attached. Primary mode is keyboard + keyboard.
- Export templates for Godot 4.7.2 are not installed; needed at M7 (ask the user before downloading).
- Human playtests and named-device performance measurements require the user.

The older single-player HTML proof is separate evidence for a previous experiment. It does not establish any co-op acceptance criterion.
