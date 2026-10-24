# Implementation plan — Gloamthread: Two Ends

Version 2.0 · 24 October 2026 · Planning document, not implementation evidence.

Build the fixed-character co-op game first. The first completion target is the eight-room Phase 1 slice in `../MVP.md`, with Tavi and Neri, fixed split screen, two visual themes, and a complete ending. The 96-room production budget and pregame generation system are later work.

## 1. How to use this plan

1. Read `DECISIONS.md`, `../MVP.md`, `ARCHITECTURE.md`, and the applicable part of `ART_AUDIO_PIPELINE.md`.
2. Complete one milestone below, with its verification evidence, before using its completion to unlock dependent work.
3. Use `TASKS.md` to assign bounded agent work. One integrator owns shared entry points, project settings, and integration.
4. Keep the current status in the implementation repository: implemented, verified, partially verified, planned, blocked. Include the exact engine version and commands actually run.
5. Stop after Phase 1 is packaged and playtested. Do not automatically begin image generation, networking, or world expansion.

M0's runtime and the first diagnostic content packet are integrated: boot/session/player/cameras, original diagnostic assets/r00 and four engine scenarios exist with clean import and headless startup. Continuous visible/physical-input acceptance remains outstanding before declaring M0 fully passed. See `STATUS.md` and `../HANDOFF.md` for current evidence and next tasks; later milestones still follow the gates below.

## 2. Dependency path

The critical path is toolchain → one world/two views → independent input/movement → real combat/recovery → cooperative interaction → progression/ending → release verification.

Original art/audio production can run alongside movement and combat once dimensions, pivots, state names, theme layers, and event names are agreed. Do not integrate several incompatible sprite formats and attempt to reconcile them at the end.

| Milestone | Depends on | Concrete output | Gate before proceeding |
| --- | --- | --- | --- |
| M0: reproducible start | Starter pack | Pinned Godot project, Compatibility renderer, README launch instructions, baseline scenario runner | Fresh import and a visible test scene run; actual version and any unavailable checks recorded |
| M1: two-player room | M0 | One room, Tavi/Neri motors, two cameras/HUDs, join screen, explicit device assignment | Both people can move and jump simultaneously; one World2D/one collision scene; no input bleed |
| M2: combat and recovery | M1 | Basic slash, both specials, one Spoolmite, damage, downed/revive/team recovery | Hits are real and deduplicated; revive timing, timeout and both-down recovery verified |
| M3: cooperative exploration | M2 | Anchor-pair bridge, exit rally, checkpoint, map/pause rules, first theme proof | Both players restore the bridge; no solo exit; pause freezes timers; geometry matches in both views |
| M4: art/audio proof | M1 contracts; final gate after M3 | Finished character states, detailed tile family, Ember/Moss views, synthesized event audio/music | In-game footage shows readable characters, platform edges and telegraphs in both halves; source rebuild passes |
| M5: complete adventure | M2–M4 | Eight rooms, Wickwing, Spoolwarden, dash reward, shortcut, secret, Oru, ending | Complete fresh-save route using ordinary two-player controls; every required gate works before/after unlock |
| M6: persistence and usability | M3 state contracts; integrate after M5 | Versioned saves/settings, input remap, hotplug recovery, accessibility, restart/continue | Closing/reopening and malformed-save recovery work; devices reconnect without taking over the other player |
| M7: release candidate | M5–M6 | Clean export, test record, two-player playtest, fixed blockers, honest release notes | Every required Phase 1 acceptance item has evidence or is explicitly failed; do not label incomplete work complete |

## 3. M0 — make the environment boring

- Install and verify the standard Godot toolchain described in `SETUP.md`; do not add .NET, C++, a service, database, or runtime AI dependency.
- Create the smallest Godot project with typed GDScript and the chosen renderer. Keep editor-generated cache files out of version control.
- Establish a launch scene, a headless scenario entry point, and the content/asset manifest versions before parallel work begins.
- Set 60 Hz physics and the 960×360 logical composite with two 480×360 outputs. Fix nearest filtering and integer scaling before judging pixel art.
- Add the minimum generated diagnostic art necessary to see characters, floor, collision, and each camera. Diagnostic art is not the finished art gate.
- Add a smoke scenario that loads the scene and exits with a useful failure result on missing resources or invalid scene paths.

**Complete when:** a clean checkout imports and launches, the smoke scenario is actually run, and the result is recorded. A screenshot of the editor alone is insufficient.

## 4. M1 — prove local multiplayer before making a map

- Build exactly one shared gameplay world with two actor instances and two SubViewports sharing its World2D.
- Route input through a player slot and assigned device. The player motor consumes actions rather than reading global keyboard/gamepad state directly.
- Support two gamepads and keyboard plus gamepad. Make the join screen explain the selected assignment; prevent one physical controller from controlling both slots.
- Add coyote time, jump buffering, variable jump height, a compact collision shape, and stable landing. Tune the same base movement for both characters first.
- Give each viewport its own camera bounds and HUD; draw both players in both views. Keep the divider an overlay and reserve sufficient screen space for combat.
- Handle one global pause, focus loss, and device disconnect; a disconnect must not leave the other player fighting while setup is blocked.

**Complete when:** two real devices control the couriers simultaneously for at least five minutes, including opposite movement, simultaneous jumps, pause, reconnect, and repeated ledge approaches. Record any input mode that could not be physically checked.

## 5. M2 — real combat, then rescue

- Implement slash anticipation/active/recovery, facing, hitbox/hurtbox separation, one hit per target per attack, knockback, and damage immunity.
- Add Tavi's Ember Arc and Neri's Spore Bolt within explicit cooldown and damage bounds. Test both against the same enemy rather than building separate combat engines.
- Create Spoolmite's anticipation, charge, recovery and defeat states. Telegraph shape and timing must remain readable in both themes.
- Implement the 12-second downed state, 1.5-second hold revive, interruption by damage, revive at two hearts, brief immunity, and timeout/both-down team recovery.
- Preserve permanent team flags during recovery while resetting temporary enemies/encounter state. Do not write a partially damaged combat snapshot to the campaign save.
- Add headless scenarios for damage deduplication, immunity, pause during downed/revive, timeout, interrupted revive, and simultaneous downing.

**Complete when:** either player can defeat the enemy, rescue the other, and recover from failure without a softlock. Verify the timer and health outcomes through scenarios, and the clarity of the events through actual play.

## 6. M3 — demonstrate cooperation and the shared world

- Add an anchor pair that records distinct player participation, latches visibly, and restores one authored bridge permanently. It must not require frame-perfect simultaneous button presses.
- Add a room exit rally zone: both living players present, one activates, one transition occurs. Show who is missing. A downed player blocks exit and offers recovery guidance.
- Add checkpoint A and safe spawn positions for both characters. Establish stable IDs for bridge, checkpoint, exit and room flags.
- Add the shared map and global dialogue state. Either player can request pause/map; closing it restores the previous safe state without consuming unintended attack inputs.
- Render one scene in Ember and Moss. Inspect that a visual-layer change does not add/remove a platform, change a hazard, duplicate enemies, or alter a trigger.
- Exercise bridge restoration → recovery → revisit in a targeted integration scenario. Add the close/reload leg when M6 supplies persistence.

**Complete when:** two players can identify and perform the cooperative action without spoken developer coaching; the bridge and exits have one shared state in both views.

## 7. M4 — establish the visual and audio standard once

- Finish the original hero silhouettes and all required animation states using the agreed cells and pivots. Create game-ready output from retained source rather than relying on unchecked generated sheets.
- Build one detailed terrain family with edges, corners, interiors, platform tops and two coherent visual interpretations. Compare native-resolution views side by side.
- Establish readable silhouettes and contact edges under the darkest allowed lighting. Preserve warning shapes and enemy anticipation across themes.
- Generate original PCM effects and note-based music from repository sources. Route each semantic event once to the shared stereo mix.
- Implement the planned asset generator and validator entry points, including dimensions, frame coverage, source provenance and output hashes.
- Test the current character states in motion. A beautiful still frame cannot establish attack readability, consistent animation pivots or a seamless music loop.

**Complete when:** one finished room provides a quality reference for later content, generator/validator results are recorded, and actual captured gameplay is reviewed at logical resolution. Placeholder quality must not silently become the production standard.

## 8. M5 — close the full eight-room loop

Implement the exact route in `DECISIONS.md` and `../MVP.md`; do not improvise another room count while integrating.

1. Assemble r00–r04 with Oru, landmarks, tutorial prompts, anchor lesson, optional secret and checkpoint B.
2. Add Wickwing with an aerial anticipation/dive/recovery cycle distinct from Spoolmite.
3. Prototype the Spoolwarden in r05 with a small readable move set. It must be defeatable through normal attacks and both specials.
4. Add the optional Cross-stitch exposure payoff; either character can stagger and either can follow up. Do not make progression depend on executing it.
5. Grant Threadstep once to the team; persist boss defeat and the shortcut before permitting departure.
6. Open r05↔r01, introduce dash safely in r06, then test the earlier r01 gate with and without the unlock.
7. Restore the second anchor pair at the causeway. Both reach r07, restore the Lantern Loom, see the hub change, and receive a clear completion/replay card.
8. Give each return and failure path an intentional destination. Fix repetitive travel or confusing exits instead of adding unexplained arrows everywhere.

**Complete when:** a full two-player route reaches the ending from a fresh save without debug warps, direct flag edits, invulnerability cheats or private developer explanation. Log duration and failure points; 15–20 minutes is a target to test, not a result to manufacture.

## 9. M6 — make the adventure survivable outside development

- Separate settings/device bindings from team progress. Save fixed profile IDs, checkpoint, explored rooms, unlocks, restored anchor IDs, boss and secret flags once per team.
- Use validated safe-checkpoint loading, atomic replacement and a last-known-good backup. Handle missing, malformed and unsupported future save versions visibly without silently overwriting them.
- Add clear new-game confirmation, continue availability, pause exit, remapping, independent music/effects levels, reduced shake and flashes.
- Test device disconnect during combat, revive and transition readiness. Require an explicit reassignment before resuming if the device identity changes.
- Keep dialogue short and globally paused; show which inputs advance/skip. Essential information also appears through environment and objective cues.
- Ensure permanent rewards are granted exactly once across defeat, recovery, close/reopen and repeat interaction.

**Complete when:** a fresh player can join, understand the objective, interrupt the session, reconnect and continue safely. Actual audio and controller testing remain separate from headless results.

## 10. M7 — prove and package the slice

- Follow `TEST_PLAN.md`; run content validation, asset validation, import, headless scenarios, actual two-device play and a clean release export.
- Conduct a fresh-player playtest with two people. Observe without coaching. Record where either is idle, lost, repeatedly hit without understanding why, unable to see a landing, or unable to rescue a partner.
- Fix progression blockers, input ownership, camera readability and combat feedback before tuning decoration or adding rooms.
- Measure performance in the busiest encounter on a named device and resolution. No claims about 60 fps based on source inspection or a still image.
- Package executable plus required data, readable controls, version, provenance, known gaps and launch instructions. Verify it works with network disabled and without the development editor, if testing conditions permit.
- Prepare a short track demo: two players join → contrasting views of one bridge → cooperative restoration → combat/rescue → short ending. Do not spend most of the presentation browsing settings or showing a future generation mockup.

**Complete when:** the Phase 1 acceptance checklist has specific evidence, the exported game completes normally, and remaining limits are reported plainly.

## 11. Effort and cut rules

These are planning ranges for one developer using coding agents, not delivery promises. New-engine learning, visual iteration, controller hardware and integration failures can dominate the schedule.

| Available effort | Sensible goal | What to cut |
| --- | --- | --- |
| One focused day | Two-room technical showcase: two fixed characters, split screen, one bridge, one simple encounter and a restoration ending | Full eight-room route, second enemy, miniboss, dash progression and most menus; label it a reduced proof, not the Phase 1 MVP |
| Several focused days | M0–M3 and one coherent visual room, with recorded hardware tests | Extra content and polish until input, recovery and shared state are stable |
| Roughly 1–3 focused weeks | A candidate eight-room slice, depending on experience and reuse | Any Phase 2 work, production-world expansion, extra enemies or equipment systems |
| Additional iteration | Playtest-driven polish and release hardening | Room-count inflation and unchecked asset churn |

A showcase cut still needs two-player interaction, a readable goal, recovery and a clear finish. Do not cut the defining cooperative action while retaining a large map. If movement or visual readability fails, reduce content and fix that foundation.

## 12. Risk order and later handoff

1. **Input and shared simulation:** prove independent devices and one gameplay state first.
2. **Half-screen readability:** prove movement/combat at 480×360 before filling rooms.
3. **Recovery/progression safety:** prove revive, exits, boss rewards and saves before a long playthrough.
4. **Coherent assets:** establish one scene standard and enforce it instead of generating hundreds of incompatible images.
5. **Fun and pacing:** observe two people; revise idle roles, sponge enemies, confusing routes and repetitive backtracking.

After Phase 1, preserve its fixed manifest path as the regression baseline. Phase 2 should first replace one character appearance and one theme bundle through those contracts. Add unrestricted input support only as validation succeeds; see `GENERATION_ROADMAP.md`. Phase 3 expands by finished region, with the original slice remaining part of the same authored world.
