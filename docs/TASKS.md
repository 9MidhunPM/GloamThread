# Agent task backlog — Gloamthread: Two Ends

Version 2.0 · 24 October 2026 · All tasks below are planned, not completed.

Use `IMPLEMENTATION_PLAN.md` for milestone gates. This backlog defines implementation responsibilities and acceptance criteria; it does not grant permission to publish or message third parties.

## Collaboration rules

- Current assignment: [Agent 1](AGENT_1_RUNTIME.md) owns runtime/integration and [Agent 2](AGENT_2_CONTENT.md) owns authored content/assets/Python tools, in separate checkouts. Their ownership and shared contract supersede the older suggested task boundaries below; the dependencies and acceptance gates still apply.
- One integrator owns `project.godot`, the launch scene, shared session wiring, export presets, and final integration. Other agents propose changes to those files through that owner.
- Before parallel work, agree on named input actions, player-slot IDs, resource/manifest versions, room IDs, actor event names, and animation states. Record a changed contract once and notify dependent owners.
- Assign exclusive concrete paths at the start of each task. Suggested boundaries below can be adapted to the actual repository; do not create empty modules merely to match a plan.
- Implementers supply focused verification with their change. Integration tests belong with the affected behaviour; a final QA agent cannot compensate for untested subsystem contracts.
- Integrate in small working increments. Do not leave the final hour for the first import of independently authored scenes.
- Tasks may share a domain owner, but not concurrent write ownership of a file. An active-claim note or task board should list owner, paths, dependencies and status.
- Preserve user changes. Do not reset a shared checkout or overwrite another agent's work to resolve an integration problem.
- No task includes online multiplayer, runtime generation, a 96-room content dump, or a generic engine rewrite.

## Ordered tasks

### T01 — toolchain and project shell

- **Owner/boundary:** integrator; project settings, entry scene, root run instructions, initial `tests/run_tests.gd`.
- **Depends on:** starter pack and local prerequisites.
- **Deliver:** Godot 4.7.2 standard project, Compatibility renderer, fixed physics, logical composition, launch/smoke entry points, ignored editor cache.
- **Accept:** clean import and visible launch actually run; smoke scenario returns useful success/failure; verified tool version and blocked environment checks recorded.

### T02 — fixed data contracts and content validation

- **Owner/boundary:** content/contracts owner; fixed profile/theme/room/save contracts and `tools/validate_content.py`.
- **Depends on:** T01.
- **Deliver:** Tavi/Neri manifests, allowlisted ability IDs, stable room/anchor/checkpoint IDs, original source references, validated reference resolution; future generation fields remain optional data.
- **Accept:** valid fixed examples pass; missing IDs, illegal stats, unknown ability IDs and broken exits fail with useful messages; no API/backend implemented.

### T03 — one world and two views

- **Owner/boundary:** integrator or rendering owner; session scene, SubViewport/camera/HUD layout and theme layer wiring.
- **Depends on:** T01, T02.
- **Deliver:** one authoritative World2D with two 480×360 views and overlay divider; one diagnostic room and two actor slots.
- **Accept:** enemies/physics/triggers are instantiated once; both views observe the same transform changes; integer-scaled presentation and independent camera bounds visually checked.

### T04 — joining, input ownership and device recovery

- **Owner/boundary:** input owner; join UI, device router, action bindings and hotplug handling.
- **Depends on:** T02, T03.
- **Deliver:** two-gamepad and keyboard-plus-gamepad assignment, named actions, reassignment flow, global pause on disconnect/focus loss.
- **Accept:** simultaneous physical inputs do not bleed between players; one controller cannot own both slots; reconnect preserves the other player's assignment; untested hardware explicitly disclosed.

### T05 — shared player motor

- **Owner/boundary:** player owner; movement/collision state, presentation-facing locomotion events and motor scenarios.
- **Depends on:** T03, T04.
- **Deliver:** responsive move/jump, coyote time, jump buffer, variable jump height, stable compact collider, safe room spawn.
- **Accept:** both characters traverse the same authored jumps; no body blocking; collisions and pause behave consistently under representative render caps; actual movement feel reviewed.

### T06 — attacks, specials and damage

- **Owner/boundary:** combat owner; attack/hurtbox logic, ability implementations, damage events and combat scenarios.
- **Depends on:** T02, T05.
- **Deliver:** basic slash, Ember Arc, Spore Bolt, per-attack hit deduplication, immunity, stagger and knockback.
- **Accept:** one swing hits one target once; no friendly fire; cooldowns and damage are bounded; neither special changes mandatory traversal geometry; both heroes remain readable in combat.

### T07 — downed, revive and team recovery

- **Owner/boundary:** session/recovery owner; recovery state machine, checkpoint spawn commands and scenarios.
- **Depends on:** T06.
- **Deliver:** 12-second downed timer, 1.5-second interrupted hold revive, two-heart revival with immunity, timeout/both-down recovery.
- **Accept:** timer freezes in global pause; interrupted revive does not complete; simultaneous downing resets once; permanent flags survive and both players respawn safely at maximum hearts.

### T08 — Threadweave and coordinated exits

- **Owner/boundary:** interaction/world owner; anchor pairs, bridge activation, exit rally and checkpoint interactions.
- **Depends on:** T02, T05, T07.
- **Deliver:** distinct-player anchor participation with visible latching, one permanent bridge instance, both-living-player exit validation and guidance.
- **Accept:** one player cannot satisfy both anchor roles alone; repeated activation is harmless; bridge state survives recovery; downed or absent partner prevents a solo room transition.

### T09 — original asset generator and manifest

- **Owner/boundary:** asset owner; editable source data, `tools/generate_assets.py`, `tools/validate_assets.py`, generated outputs and provenance.
- **Depends on:** T02; agrees with T05/T06 on states/events before final export.
- **Deliver:** Tavi/Neri required animation states, Oru's eight-frame NPC set, terrain/props/enemies/UI/glyphs, original sound/music sources, consistent frame/pivot metadata.
- **Accept:** deterministic local rebuild from retained source; invalid atlas dimensions/state coverage fail validation; no downloaded game-content packs or unchecked image sheets.

### T10 — finished Ember/Moss presentation

- **Owner/boundary:** rendering/art owner; per-view visual roots, themes, backgrounds, lights, effects and camera polish.
- **Depends on:** T03, T09.
- **Deliver:** two coherent visual interpretations of the same diagnostic room with shared actor/hazard grammar.
- **Accept:** theme layers have no colliders/AI/triggers; platform silhouettes and hazard readability match; both native-resolution views inspected during animation and combat.

### T11 — ordinary enemies

- **Owner/boundary:** encounters owner; Spoolmite/Wickwing scenes, finite states, spawn content and encounter scenarios.
- **Depends on:** T06, T09.
- **Deliver:** telegraphed ground charge and aerial dive, meaningful recovery windows, defeat feedback and bounded room respawn rules.
- **Accept:** both characters can defeat both enemy types through normal inputs; no duplicated damage/audio from dual rendering; two-player targeting avoids permanent focus on one courier.

### T12 — Spoolwarden and permanent reward

- **Owner/boundary:** boss owner; r05 encounter, reward integration and boss scenarios; integrator owns shared progression changes.
- **Depends on:** T07, T08, T11.
- **Deliver:** readable limited move set, optional role-symmetric Cross-stitch payoff, team Threadstep unlock, shortcut flag and one-time reward.
- **Accept:** boss is beatable without Cross-stitch; timeout/recovery resets transient phase safely; defeat is recorded once; both players receive dash and shortcut state survives team recovery. T15 later verifies the same flags across close/reload.

### T13 — eight-room route and secrets

- **Owner/boundary:** level owner; r00–r07 data/scenes and room graph, not shared player or combat code.
- **Depends on:** T08, T10, T12; rough room layout may begin after T05.
- **Deliver:** exact route, checkpoints A/B, pre/post-dash gate, safe dash lesson, second anchor pair, r03 cosmetic secret and return connection.
- **Accept:** every room has a purpose; mandatory gates cannot precede their unlocks; no exclusive Tavi/Neri requirement; full normal-input route and return paths traversed by two players.

### T14 — story, objective UI and ending

- **Owner/boundary:** narrative/UI owner; dialogue data, objective text, prompts, map overlay, completion card and ending presentation.
- **Depends on:** T04, T13; narrative data can be prepared earlier from `STORY_BIBLE.md`.
- **Deliver:** concise Oru dialogue, nonverbal visual beats, globally paused dialogue/map, joint Lantern Loom restoration and visible Lantern Rest change.
- **Accept:** players can identify the next goal without developer narration; either can request global pause/map; ending is reachable, acknowledges restoration and distinguishes completion from quitting.

### T15 — campaign persistence and recovery

- **Owner/boundary:** persistence owner; save/settings codecs, migrations/version rejection, atomic writes, backups and save scenarios.
- **Depends on:** T02, T07, T08, T12, T13.
- **Deliver:** one team progress save, separate settings/bindings, safe-checkpoint load, valid continue state and visible failure handling.
- **Accept:** boss/anchors/unlocks/secret/exploration round-trip; malformed/newer saves are preserved and explained; failed write does not destroy the last valid save; no arbitrary combat snapshot restoration.

### T16 — audio, settings and accessibility integration

- **Owner/boundary:** audio/UI owner; shared semantic audio routing, music state, remap/settings UI and reduced-effects presentation.
- **Depends on:** T04, T09, T14.
- **Deliver:** one stereo mix, original music/effects, independent volume levels, reduced shake/flashes, consistent device-aware prompts.
- **Accept:** event sounds play once; actual audio loop reviewed; important cues remain understandable without colour or sound alone; bindings/settings persist and menus do not leak attack inputs.

### T17 — integrated verification and two-person playtest

- **Owner/boundary:** QA integrator; scenario orchestration, results/issue log and approved test fixtures; feature owners fix their files.
- **Depends on:** T05–T16.
- **Deliver:** `TEST_PLAN.md` results, clean import/export checks, required scenario evidence, physical two-device run and fresh-player observation.
- **Accept:** complete ending through ordinary controls, no known progression blocker, documented device/display/audio limitations, named-device performance data; debug hooks do not substitute for a real route.

### T18 — package the Phase 1 candidate and stop

- **Owner/boundary:** integrator; release export, player README, provenance inventory, controls, known gaps and final status.
- **Depends on:** T17 and fixes required by its gate.
- **Deliver:** clean Linux release bundle and concise track demonstration sequence.
- **Accept:** exported build launches and completes under documented conditions; offline behaviour checked where possible; all remaining unverified items are explicit; no claim that Phase 2 or the 96-room game exists.

## Parallel work windows

| Window | Safe concurrent assignments | Integration limit |
| --- | --- | --- |
| After T02 | Input routing, motor design, original asset generation, narrative source preparation | Scene and data interfaces stay owned by the integrator/contracts owner |
| After T06 | Recovery, enemy behaviours, final hero animation/effects | Combat event names/hit semantics must remain stable |
| After T08 | Level assembly, theme presentation, boss work, persistence foundations | Shared progression flags change through one owner |
| Before T17 | UI/audio integration and focused scenario coverage | Freeze new mechanics; integrate and repair instead of adding systems |

## Definition of a task handoff

Each task returns: files changed; behaviour added; relevant contract changes; exact verification run and result; checks unavailable and why; remaining risks; and the next dependent task that can now begin. A task is not complete merely because the code was written, an import passed, or an agent reports success.
