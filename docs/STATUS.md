# Implementation status

Updated 2026-10-24T23:36:24+05:30. The active runtime branch is integrating the full Phase 1 game; this is an implementation checkpoint, not final acceptance.

## Implemented and verified

- All eight authored rooms and 47 original manifested art/audio/font outputs are integrated from content checkpoint `af2cb4c`. Full asset/content validators pass. All 79 Python boundary, asset, audio and generator tests pass.
- The production Godot boundary loads profiles, world, dialogue, rooms, cached sprite frames, animation tables, original font and looped WAV streams. Both theme terrain layers, decorative props and finite per-view backgrounds build from one canonical collision layout. A restored bridge adds one collision surface and updates both skins.
- Shared-world players now have slash hit deduplication, Ember Arc, terrain-blocked Spore Bolt, immunity, down/revive state, one-way drop through and 72 px/12-tick Threadstep. Spoolmite, Wickwing and Spoolwarden have real attack states; optional Cross-stitch supports either role order.
- GameSession owns distinct-player anchor latches, living-pair exit rally, deferred room/recovery transactions, checkpoints, secret, boss reward triple, loom restoration and return-ending state. Shared pause/map/dialogue/reconnect freeze the world; semantic audio events use one mix.
- Campaign and separate settings repositories validate data, preserve backups, protect newer saves and report failures. Actual-file fault scenarios cover write/verify/rotate/replace and explicit recovery.
- Fresh editor import passes without script/resource errors. The integrated engine suite passed 12/12 from a fresh staged-file copy. Isolated combat/production resource checks pass. Exact commands and limitations are in [runtime evidence](../evidence/runtime/commands.md).
- Official standard 4.7.2 templates were downloaded with user approval and the Linux x86_64 templates installed. The archive matches the official asset SHA-256 `f298490b8d44d934be425a5a65a51bf15f422428b229a06a6e11d9ffea248011`.

## In progress

- App menus, explicit join/source selection, remapping and all campaign screen flows are being connected. Agent 2 owns the menu presentation in a separate `feat/phase1-ui` checkout; Agent 1 owns app/session integration.
- An ordinary-input fresh campaign route is being checked against actual physics. Draft dash gaps and recovery routes remain provisional until that run succeeds.
- Linux export, visible native play, original animation review, listening and performance measurement follow the connected screens and route.

## Unverified acceptance

- No physical gamepads or fresh two-person playtests are available. Keyboard + keyboard is primary; physical rollover is a hardware check. No hardware, human-fun or duration claims are inferred from synthetic inputs.
- Whole-suite audio retirement is now awaited on the real mixing clock; the 12-scenario staged-copy run exits cleanly. The runner captures engine errors so a runtime exception cannot silently count as a passing scenario.
- Full normal-control route, visible split-screen motion/audio, packaged offline launch and performance have not passed yet. The earlier single-player HTML proof supplies no co-op evidence.

## Repository and event

History retains the organizer-shared root and actual development commits. Only the authorized `9MidhunPM/GloamThread` remote is used. Current guidance is **Devin Hack Kochi** in [RULES.md](../RULES.md); historical event references are preserved as history. Agents follow [runtime](AGENT_1_RUNTIME.md) and [content](AGENT_2_CONTENT.md) ownership. No Phase 2/3 scope is included.
