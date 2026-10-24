# Gloamthread: Two Ends — MVP

**Superseded for active development:** the user requested overhead perspective on25October2026. Follow [the overhead plan](docs/OVERHEAD_PLAN.md) and [contract](docs/OVERHEAD_CONTRACT.md). This document preserves the side-view milestone scope; shared co-op/original-content principles continue.

Version 2.0 · 24 October 2026 · Owner: Midhun P M.

## The promise

Two players carry opposite ends of the last living thread through a kingdom that each sees differently. They fight, revive each other, restore broken paths, and bring a stranded district home.

Build a short, complete, original pixel-art action adventure first. The initial characters are fixed: Tavi and Neri. Fixed split screen and cooperative interactions are essential; drawing interpretation and live image generation belong to Phase 2.

**Status:** this document specifies the complete MVP target. A diagnostic Godot runtime tracer and the full authored content bundle exist on separate branches; [STATUS.md](docs/STATUS.md) records remaining integration and acceptance. The earlier single-player HTML proof is separate evidence and establishes no co-op, Godot, controller, rendering or audio result.

## Phase boundaries

| Phase | Deliverable | Gate before proceeding |
| --- | --- | --- |
| 1A: technical proof | One room, both characters, separate inputs and cameras, shared collision and enemy | Real simultaneous play, one enemy updated once, stable pixel presentation |
| 1B: fixed-character MVP | Eight rooms, target 15–20 minutes, complete objective and ending | Full route played by two people; save, recovery and accessibility checks pass |
| 2: personalisation | Optional pregame drawing/upload, bounded profiles and new appearance/theme bundles | Generated content passes the same asset and playability contracts; fixed mode still works |
| 3: world expansion | Complete regions toward the planned 96-room world | Each addition passes gameplay, originality, performance and save checks |

Playtime is a first-clear planning hypothesis. A model cannot guarantee fun, polish, or a completion date. Test those with people before expanding.

## Exact Phase 1 content budget

- Two fixed playable characters, Tavi and Neri; one shared campaign save.
- Eight connected rooms in Wickerreach/Lantern Rest; two checkpoints; one NPC, Oru.
- Two ordinary enemy types: Spoolmite and Wickwing.
- One miniboss, The Spoolwarden; one shared traversal unlock, Threadstep.
- Two authored Threadweave anchor pairs, one optional Cross-stitch boss payoff, partner revival.
- One secret pocket inside r03; reward is a shared cosmetic lantern charm.
- Two authored visual themes, Ember and Moss, over identical gameplay geometry.
- Join/device assignment, new/continue, pause/map, settings, checkpoint recovery, ending and replay.
- Original sprites, animations, tiles, backgrounds, UI glyphs, music and sound authored in the project.

Do not quietly add a third enemy type, a ninth room, a skill tree, or a generation service to this milestone.

## Characters and controls

| Character | Identity | Starting hearts | Special | Personal view |
| --- | --- | ---: | --- | --- |
| Tavi | Ash hood, teal mantle, brass spool, amber lantern, hooked shuttle | 5 | Ember Arc: short charged cleave, extra stagger | Ember: warm brass, charred timber, amber seams |
| Neri | Leaf-shaped stitched hood, plum scarf, round green spool, needle baton | 4 | Spore Bolt: short projectile, brief normal-enemy slow | Moss: cool stone, living roots, luminous fungi |

These are initial tuning targets. Both share the same core movement and compact collider, and both can finish every mandatory route. Heart differences must be reconsidered if playtests make Neri consistently frustrating.

- Common actions: move, jump, basic slash, special, interact/revive, Threadstep after unlock, map and pause.
- Two gamepads preferred; keyboard plus one gamepad supported. Device ownership must prevent one input from controlling both players.
- Remappable actions and correct player/device prompts are required. Two players on one keyboard are optional because simultaneous key rollover varies.
- No PvP, friendly fire or body blocking. Players can overlap safely.
- One global pause/map/dialogue state freezes the simulation for both. Focus loss or loss of an assigned controller pauses and offers reassignment.

## The cooperative rules

**Threadweave:** each player activates a distinct anchor in a marked pair. The first anchor visibly latches while the partner reaches the second. Completion restores a predefined bridge permanently. There is no tight synchronisation window, physical rope simulation, or player-built terrain.

**Cross-stitch:** a stagger exposes the Spoolwarden's seam briefly; a strike from the other player triggers a shared burst. Either character can set up or finish it. The boss remains beatable without the bonus.

**Revive:** at zero hearts, a courier unravels into a bundle for 12 seconds. Their partner holds interact nearby for 1.5 seconds; damage to the rescuer interrupts. Revival gives 2 hearts and brief immunity. Timer expiry or both down triggers team recovery at the checkpoint. Permanent unlocks and restoration flags survive; transient encounters reset and both return at maximum hearts.

**Room exits:** both living players must stand in a visible rally zone; one activates the exit. A downed partner must be revived or the team may choose checkpoint recovery. There is no solo room transition or offscreen abandonment.

All timings are starting values for testing, not claims that balance is solved.

## Room plan and progression

| ID | Room | Player experience | Persistent result |
| --- | --- | --- | --- |
| r00 | Lantern Rest | Join, move, meet Oru, see the dark route home | Checkpoint A and clear objective |
| r01 | Mossfoot Atrium | Recognise the landmark and an unreachable causeway | Map branch discovered |
| r02 | Spindle Steps | Learn forgiving jumps and the first anchor pair | Bridge restored |
| r03 | Glasswing Gallery | Learn enemy tells and both specials; optional secret | Cosmetic charm if found |
| r04 | Warden's Landing | Rest, heal, anticipate boss | Checkpoint B |
| r05 | Broken Bell | Defeat Spoolwarden; discover Cross-stitch | Team Threadstep and shortcut to r01 |
| r06 | Severed Causeway | Try a safe dash, cross the old gap, restore second pair | Causeway connection restored |
| r07 | Lantern Loom | Both restore the loom; see the district relight | Ending flag and safe return to r00 |

Main route: r00 ↔ r01 ↔ r02 ↔ r03 ↔ r04 ↔ r05. After the boss, use the opened r05 ↔ r01 shortcut, then r01 ↔ r06 ↔ r07. The r01–r06 link needs team Threadstep; r06–r07 needs the causeway anchor pair. Final restoration opens the return to r00 through the same cooperative transition rules.

The night tide supplies atmosphere, not a countdown. There is no campaign fail state for taking time to explore.

## Presentation contract

- Godot 4.7.2 standard, typed GDScript, Compatibility renderer, Linux desktop first.
- Logical composite 960×360: two 480×360 views side by side; overlay divider. Default window 1920×720.
- World tiles 16×16; player frames 32×48; nearest filtering, integer scaling and letterboxing.
- One shared World2D and simulation; two Camera2D/SubViewport views and independent HUDs.
- Themes alter palette, backgrounds, lighting and decoration. Solid edges, enemy states, hazards and interaction positions remain truthful and legible in both.
- One audio mix. A hit, reward or door emits one sound event, even if visible in both cameras.

## What should make it fun

1. Movement is satisfying before the first enemy appears: responsive turning, variable jump height, coyote time and jump buffering.
2. A partner creates opportunities: bridge restoration, reviving under pressure, and optional boss coordination.
3. Exploration gives a remembered payoff: see a blocked route, earn dash, return through a shortcut, cross it.
4. The two perspectives invite conversation: compare how the same bell tower appears without hiding necessary information.
5. Restoration gives a visible reward: repaired crossings, warmer lanterns, returning residents and an ending with emotional resolution.

Use short teaching encounters, safe practice space and distinct landmarks. Avoid health sponges, repeated empty corridors, a powerless support character, and constant camera/exit arguments.

## Implementation order

1. Establish a one-room two-player movement and camera proof.
2. Add real damage, one enemy, partner revival and checkpoint recovery.
3. Produce one coherent original art/audio scene in both themes.
4. Add Threadweave, rally exits and a persistent bridge.
5. Close the boss → team dash → remembered gate → loom → ending loop.
6. Expand to the eight-room budget; add Oru, secret, map and remaining enemy.
7. Complete remapping/hotplug, save recovery, settings, packaging and human playtests.

Do not implement Phase 2 because a generator sounds more impressive than tuning a jump. See [IMPLEMENTATION_PLAN.md](docs/IMPLEMENTATION_PLAN.md) for ordered tasks and stop conditions.

## Acceptance gate

- [ ] Both players can join with distinct devices and act simultaneously without cross-control.
- [ ] Both views show the same enemy, door, bridge and boss outcomes; no duplicate simulation or rewards.
- [ ] All eight rooms, the return shortcut and the ending work through normal controls.
- [ ] Pre-dash gate blocks both; the shared unlock persists after death, reload and device reassignment.
- [ ] Both anchor pairs restore once, stay restored, and cannot strand either player.
- [ ] Either character can revive the other; interruption, expiry, both-down and checkpoint recovery work.
- [ ] Both specials and the optional Cross-stitch payoff affect real combat; the boss is beatable without the bonus.
- [ ] Either player can pause; map, dialogue, focus loss and controller loss freeze both safely.
- [ ] Save/continue preserve major progress; missing, invalid and unwritable saves have visible, recoverable handling.
- [ ] Original art, complete animation states, readable hazards and single-instance audio pass scene review.
- [ ] Installed Phase 1 starts and finishes offline without account, API key, asset request or generation service.
- [ ] A fresh pair finishes without developer coaching; another pair can recover from death and understand the exit rally.
- [ ] Performance is measured on a named device in the busiest room; no unmeasured “60 fps” claim.
- [ ] The report distinguishes implemented, automated-tested, human-tested, unverified and planned features.

## Explicit exclusions

Phase 1 excludes online/LAN play, dynamic camera merging, separate-room exploration, drawing/upload, live AI, arbitrary abilities, generated world geometry, 3D, terrain destruction, crafting trees, procedural quests and the remaining 88 planned rooms. The later generation feature consumes the same validated character/theme interfaces; it does not replace the fixed baseline.

## Track fit and demo message

Primary track: **Make Room for Play**. Show two people actively experiencing original cooperative exploration and contrasting visual perspectives. The supplied track does not demand online play or runtime AI.

Optional secondary claim: **Works Anyway**, only when deliberately demonstrating the installed game with internet unavailable. Do not claim unrelated tracks or present “generated by agents” alone as the player-facing innovation.

Pitch the finished slice honestly: “Two couriers, two views of one kingdom, and one thread that restores the way home.”
