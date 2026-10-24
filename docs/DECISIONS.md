# Gloamthread: Two Ends — settled decisions

Version 2.0 · 24 October 2026 · Owner: Midhun P M.

This repository includes the planning pack and an integrated M0 diagnostic co-op room with focused component/session evidence. The complete Phase 1 adventure is still missing; see `STATUS.md`. It supersedes the earlier C++/Raylib single-player production plan. The earlier HTML proof remains a separate, single-player experiment.

## Product and phases

- Working title: **GLOAMTHREAD: TWO ENDS**. Pitch: two couriers carrying opposite ends of the last living thread restore a kingdom that each sees differently.
- Genre: original side-view pixel action exploration RPG, local two-player co-op, fixed vertical split screen, Linux desktop first.
- Phase 1: two fixed characters; eight purposeful rooms; a complete 15–20 minute first-clear target; one shared physical world; two authored visual themes. No runtime image analysis or image generation.
- Phase 2: optional pregame drawing/upload → bounded character profile → new character appearance and themed visual asset bundle. Stage this as template-driven construction first, constrained image generation next. Phase 1 remains playable offline without providers.
- Phase 3: grow a finished region at a time toward a planned 96-room world: Lantern Rest hub (6 rooms), plus six regions of 15 rooms each. No completion-time or fun guarantee.
- Primary track: Make Room for Play. Local co-op is multiplayer. Track examples do not impose online play. Secondary Works Anyway is optional only if offline operation is actually demonstrated as an intentional constraint; do not claim all tracks or invent a Luna requirement.

## Stack and presentation

- Godot **4.7.2 standard**, typed GDScript, Compatibility renderer, Python 3 asset/data tools, Git. Version verified against official download and Arch package pages on 24 October 2026; lock this toolchain in the implementation repository. No C++, .NET, Node, database, service, or API key required for Phase 1.
- World tile: 16×16 px. Character cell: 32×48 px. Logical composite: **960×360**, with two **480×360** views side by side. Divider is an overlay, not a third region changing either view's width. Initial window 1920×720; integer scaling and letterboxing, nearest filtering. At smaller displays use a 960×360 1× view or letterbox; never silently stretch pixels non-uniformly. Pixel-stable presentation; fixed 60 Hz physics.
- One World2D and one authoritative simulation. Two SubViewports share it; each has its own Camera2D and HUD. One collision layout and one set of enemies, bosses, triggers, loot and permanent flags. Theme-specific visual layers contain no collision, AI or gameplay triggers.
- Fixed split screen even when players are close. Both stay in one active room for Phase 1; room transition requires both living players in an exit rally zone, and activation by one. Downed partners must be revived or the team can choose checkpoint recovery. No solo transition, dynamic camera merge, online or LAN networking.
- Inputs: keyboard/keyboard (WASD / arrows) is the user-selected primary mode to implement and verify, with the hardware-rollover caveat. Two gamepads and keyboard plus gamepad remain supported paths, hardware-unverified until controllers are available. Keep the defaults in `scripts/input/bindings.gd`. Explicit device-to-player ownership, simultaneous inputs, remapping and hotplug pause. One global pause/map/dialogue state. One stereo mix; avoid double-playing sound events through two listeners.

## Current implementation collaboration

- Two independent checkouts/branches: [Agent 1](AGENT_1_RUNTIME.md) owns Godot runtime, scenario tests, integration and release; [Agent 2](AGENT_2_CONTENT.md) owns all authored content, asset/audio generators, manifest and Python validation, including r00 and the generator entrypoint. This replaces the old three-worker plan. Parallel work may start immediately from the shared diagnostic/data contracts.
- The shared producer/consumer data contract lives in Agent 2's brief. Preserve its schema/ID/coordinate conventions in both Python and GDScript. Any compatibility change must update that contract and both consumers before integration.
- Room dimensions are 30–90 by 23–30 tiles; initial r00 is 60×23. This resolves the older 40-tile minimum proposal against the existing loader and handoff.
- Each agent records its actual contribution in its named changelog/AI-usage section. Agent 2 records tool/setup instructions and evidence in `evidence/content/`; Agent 1 incorporates these into central docs and runs authoritative Godot imports. Only Agent 1 publishes `main` and release artifacts.

## Characters and common mechanics

- **Tavi**, Ember courier: original ash hood, muted teal mantle, brass spool, amber lantern, hooked shuttle; 5 hearts, basic slash; special **Ember Arc**, a short charged cleave with extra stagger. Ember visual theme.
- **Neri**, Moss courier: original plum scarf, leaf-shaped stitched hood, round moss-green spool, needle baton; 4 hearts, basic slash; special **Spore Bolt**, a short-range projectile with brief slow against normal enemies. Moss visual theme. Boss slow is capped or immune, visibly explained.
- Both share the same tested core movement and compact collider. Character differences are tunable initial targets, not measured balance claims. No PvP, friendly fire, or player-body blocking.
- Both can jump, attack, interact, use their special, revive, and Threadweave. **Threadstep** (dash) unlocks for the whole team after the miniboss; it cannot be unequipped. Future generated stats/specials never replace required shared traversal unlocks.
- **Threadweave** connects an authored pair of anchors: each player activates a distinct anchor, the pair visibly latches, a predefined bridge restores permanently. No simulated rope, arbitrary construction or physics tether.
- **Cross-stitch** team payoff in the boss fight: after one player staggers the boss, the other can strike the exposed stitch for a shared burst; either character can perform either role. It is an optional advantage, not a mandatory timing gate. This is the single extra combat co-op payoff; do not expand into skill trees.
- Downed state: 12 seconds; living partner holds interact nearby for 1.5 seconds to revive at 2 hearts with brief immunity; damage to rescuer interrupts. Timeout or both down triggers team recovery at checkpoint. Preserve permanent flags, reset transient encounter state, restore both to their maximum hearts. These are starting tuning targets.
- Same platforms, hazards, boss state and doors in both views; different terrain colours, backgrounds and decoration are cosmetic. Preserve common hazard shapes/contrast. No player sees mechanically safe ground where another sees a lethal surface.

## Phase 1 route and story contract

Realm: the **Weftlands**. Hub keeper **Oru**. Local antagonist/miniboss **The Spoolwarden**. Objective: restore the Lantern Loom so stranded residents can cross home before the night tide severs the district.

| ID | Room | Required purpose |
| --- | --- | --- |
| r00 | Lantern Rest | Join/controls, Oru, checkpoint A, visible dark bridge home |
| r01 | Mossfoot Atrium | Landmark, branch toward a clearly dash-gated causeway |
| r02 | Spindle Steps | Forgiving jump lesson and first two-anchor Threadweave bridge |
| r03 | Glasswing Gallery | Two ordinary enemy types, special lessons and optional secret pocket |
| r04 | Warden's Landing | Checkpoint B and boss anticipation |
| r05 | Broken Bell | Spoolwarden, optional Cross-stitch payoff, team Threadstep reward, shortcut to r01 |
| r06 | Severed Causeway | Safe dash lesson, then dash route and cooperative anchor restoration |
| r07 | Lantern Loom | Both restore loom, changes at r00, ending and replay card |

Main links: r00↔r01↔r02↔r03↔r04↔r05; boss opens r05↔r01 shortcut. r01↔r06 is gated by team Threadstep; r06↔r07 requires the causeway anchor pair. Secret lives inside r03 and does not count as a ninth room. Final restoration opens safe return to r00 (same-room loading semantics apply) and triggers the ending. No required character-exclusive gate.

- Ordinary enemies: **Spoolmite** (telegraphed ground charge), **Wickwing** (telegraphed aerial dive). Exactly two base types in the MVP.
- Two checkpoints, one named NPC, one miniboss, one optional secret collectible, one traversal unlock, two authored anchor-pair interactions, and a complete ending. Secret reward is a shared cosmetic lantern charm; no health upgrade or ninth room in Phase 1.
- Main story is about reconciling perspectives without erasing either. No timed campaign failure, split-perspective mandatory puzzle or long cutscene in Phase 1. The night tide is narrative urgency, not a countdown.

## Originality, data and evidence

- No bought/downloaded resource packs, stock game art/audio/fonts/maps, ripped IP assets, or asset-store placeholders in the completed slice. Engine/tool dependencies are allowed. All game content authored by agents in repository source or retained original generation outputs with provenance.
- Fixed content and later generated bundles use the same validated manifest interfaces. Phase 1 only needs to consume fixed manifests; do not implement the Phase 2 backend early.
- Keep ability IDs allowlisted, stats bounded, colliders fixed, geometry canonical, and presentation separate. An image model never emits executable gameplay code.
- Save team progress once: version, fixed character profile IDs, checkpoint ID, explored rooms, team unlocks, restored anchors, boss/secret flags. Settings/device bindings separate. Load at safe checkpoint, never an arbitrary combat-frame snapshot.
- Asset/content tools use `tools/generate_assets.py`, `tools/validate_content.py` and `tools/validate_assets.py`; the current packet uses explicit `--stage diagnostic`, while default full-stage checks require later complete content. The built-in GDScript runner covers component/session boundaries; full gameplay scenarios are still required. No external test addon is mandatory.
- No claims of shipped co-op, Godot import, gameplay, rendering, audio or performance tests until actually run. This pack's validation only covers its documents and any example data/tooling explicitly included.
