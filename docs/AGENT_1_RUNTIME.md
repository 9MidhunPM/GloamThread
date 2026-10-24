# Agent 1 — Gloamthread runtime and integration

## Mission and current state

Implement the complete Phase 1 Godot game in `MVP.md`, integrating Agent 2's original authored bundle in small working increments. The starting code is an unverified partial M0 shell: no boot scene, player/session/camera implementation, room content, assets or scenario runner exists yet. Prove one playable two-player room before expanding the adventure.

Read `../AGENTS.md`, `../HANDOFF.md`, `DECISIONS.md`, `ARCHITECTURE.md`, `TEST_PLAN.md` and [Agent 2's brief](AGENT_2_CONTENT.md). Agent 2's shared data contract is the public producer/consumer interface for both branches. This two-agent arrangement replaces the old three-worker split and the old integrator ownership of `r00`, `generate_assets.py` and the asset manifest. Keep the full M0–M7 dependency order; do not implement Phase 2 or the 96-room world.

## Checkouts, ownership and integration

| Agent | Checkout | Branch |
| --- | --- | --- |
| Agent 1 | `/home/midhun/Coading/Gloamthread` | `feat/phase1-runtime` |
| Agent 2 | `/home/midhun/Coading/GloamThread-content` | `feat/phase1-content` |

Both branches begin from the documentation preparation commit. Agent 1 owns `project.godot`, all Godot scripts/scenes/resources, the real-engine tests and their runtime fixtures, import settings/sidecars, export configuration, runtime evidence, central docs and release packaging. Agent 2 owns all authored `content/`, original asset sources/generated outputs/manifest, the three asset/content tool entrypoints, `tools/gen/`, `tools/tests/`, `tests/contracts/` data fixtures and `evidence/content/`. The exact split is in Agent 2's brief.

Agent 1 alone runs authoritative Godot imports and commits `.import`/`.uid` sidecars, including those below asset directories. Keep `.godot/` out of Git. Neither agent edits the other checkout. Do not author a competing `content/rooms/r00.json`; an Agent-1-owned fixture in `tests/fixtures/` may isolate runtime work until the first content packet arrives.

Use `Midhun P M <midhun.titan@gmail.com>` and real timestamps. Each agent updates only its named sections in `../CHANGELOG.md` and `../AI_USAGE.md`; preserve both sections when merging. Agent 2 records its tool/setup changes in `evidence/content/README.md` for incorporation into the central README at integration. Stage explicit paths and preserve unrelated work.

Agent 2 publishes cumulative checkpoints on its feature branch. Fetch and merge `origin/feat/phase1-content` into the runtime branch using ordinary merges; retain all development commits. Do not repeatedly cherry-pick or rebase this series. Push tested runtime checkpoints to the authorized repository. Agent 1 alone integrates to `main` and publishes release artifacts. Merge the current published runtime branch back into the content branch only at deliberate, committed integration checkpoints when Agent 2 needs runtime feedback.

## Ordered runtime work

### R0 — complete the one-room foundation (M0)

1. Finish boot, temporary keyboard-zone joins, the session scene and the built-in scenario runner. Preserve current bindings in `scripts/input/bindings.gd` and the existing `CommandSnapshot` public API.
2. Create the shared `WorldRoot` once under viewport A. Assign viewport B's `world_2d` before adding its camera. Two 480×360 views use masks 3 and 5, shared actor layer 1, Ember bit 2 and Moss bit 4. Keep HUDs outside the shared world canvas, audio listeners disabled, divider overlaid, nearest filtering and integer scaling.
3. Implement the common 12×24 player collider with feet origin, no player-body blocking, movement/jump and pixel-stable bounded cameras. Begin with the motor values in the original handoff.
4. Load Agent 2's diagnostic `r00`, diagnostic images and single mover as soon as B0 arrives. Until then, use an explicit runtime test fixture; production startup must explain missing content rather than silently substituting a fake game.
5. Implement shared pause/focus handling and flush held inputs on resume. Add smoke scenarios proving two players, one mover/room/collision instance, shared World2D, stable grounded feet, moving object, masks and paused simulation.

Gate: fresh import and scenario run, followed by an actual visible two-keyboard split-screen movement check. Record unavailable checks separately.

### R1 — input, motor and validated data (M1)

Implement join/device ownership, keyboard/keyboard as the primary verification mode, configurable gamepad paths, disconnect/reassignment UI and per-view HUDs. Add coyote time, buffering, variable jump height and one-way drop-through.

Repair the inspected scaffold defects before trusting authored data: malformed unequal rows must not cause indexing failures; coordinates must be integers; spawn support must be inside the real collision grid with full body clearance; exits must reject missing entrances instead of silently falling back. Validate the same entity allowlist and fixtures as Agent 2's Python validator. Preserve the fixed data boundary and prohibit executable content paths.

Fix saved-binding validation, analog remapping and reconnect ownership, including two identical controllers competing for one returning device. Disconnected slots stay neutral and held actions remain flushed until deliberately resumed.

Publish measured movement results under `evidence/runtime/traversal.md`: engine/configuration, motor constants, successful jump rises/gaps, failed boundaries, required headroom and test inputs. These results drive Agent 2's final room geometry.

### R2 — combat and recovery (M2)

Implement attacks with anticipation/active/recovery and unique swing IDs, per-target hit sets, specials, Spoolmite FSM, hurt/immunity/knockback and no friendly fire. Damage timing comes from simulation, never animation callbacks.

Implement the 12-second downed state, 1.5-second interrupted hold revive, two-heart recovery with immunity, and one team-wipe/timeout transaction. Freeze encounter updates during recovery. Revive completion beats timeout; rescuer damage cancels the hold; a boss-defeat transaction commits before a simultaneous team wipe. Preserve permanent state while resetting transient encounters.

Gate: real-engine ownership, collision, simultaneous-attack/deduplication, immunity and boundary-timed revive/recovery scenarios.

### R3 — cooperative exploration (M3)

Implement two distinct-player anchor activations, persistent authored bridges, paired safe spawns, both-living-player exit rallies, single room transitions, checkpoint A, map and global dialogue. Menus have one explicit owner and consume/flush input consistently. Loading failure retains a safe playable state.

Gate: first bridge and room transition work through actual controls; repeated interactions cannot duplicate bridges, room loads or rewards.

### R4 — original presentation and audio proof (M4)

Consume B1 assets through the agreed manifest. Implement metadata-driven animation, theme terrain/decor and per-viewport parallax. Validate theme visibility rules in the real engine. Characters and hazard/telegraph shapes remain readable in both themes at 1×. Register semantic cues/music through one shared `AudioDirector`; confirm event audio is not doubled by the two views.

Review real captures, animation and audio before accepting the full room production. Send bounded asset/data corrections to Agent 2; do not replace its sources from the runtime branch.

### R5 — complete the eight-room adventure (M5)

Integrate B2/B3 rooms incrementally. Implement Wickwing, Oru interactions, cosmetic secret, Spoolwarden's three telegraphed attacks and optional Cross-stitch. Commit boss defeat, team Threadstep and shortcut exactly once. Publish measured dash traversal bounds for Agent 2. Verify the pre/post-dash route, second anchor pair, joint loom restoration, visible hub changes, safe return and ending/replay flow.

Gate: a complete fresh-save route using normal controls, including recovery and return paths. Debug teleports isolate scenarios only.

### R6 — persistence, usability and release (M6–M7)

Implement validated checkpoint saves with atomic replacement, backup, unsupported/corrupt-save recovery and visible write failures. Keep settings/bindings separate. Finish remapping, hotplug edge cases, volume controls, reduced shake/flashes and UI input ownership.

Complete the A01–A30 evidence matrix, check 1×/2×/awkward-aspect presentation, measure busiest-room release performance and build the Linux candidate. Matching export templates require the previously documented approval before a large download. Record hardware and human-playtest gates as unavailable until actually exercised; only a fully evidenced candidate may be called the completed MVP.

## Commands, evidence and stop condition

Run the existing preflight and pack checks, Agent 2's generation/content/asset checks, fresh Godot import and `godot --headless --path . --script tests/run_tests.gd`. The runner must support focused filters, bounded scenario execution and nonzero failures. Use the real session/physics where possible; isolated fixtures must never substitute for integrated packet tests.

Record commands/results under `evidence/runtime/`; update `STATUS.md`, the central README and submission truthfully at milestones. Distinguish source checks, headless scenarios, actual visible/device/audio checks and human playtests.

Continue through the authorized Phase 1 work. A missing content packet blocks only dependent integration: continue owned input, simulation, tests and persistence work. Report the exact dependency and keep a useful committed checkpoint. Do not expand the game or take over Agent 2's files to avoid waiting.
