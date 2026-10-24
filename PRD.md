# Gloamthread: Two Ends — product requirements

Version 2.0 · 24 October 2026 · Owner: Midhun P M.

## 1. Product definition

Gloamthread: Two Ends is an original side-view pixel-art action exploration RPG for two people playing locally. Tavi and Neri carry opposite ends of the last living thread through the Weftlands, restoring broken paths and helping a stranded district return home.

Each player has a fixed half-screen view, their own character and a distinct visual theme. Both observe one physical world. Exploration, combat, revival and bridge restoration give the partner a material role.

The first release is an eight-room, fixed-character adventure. Drawing/upload-based characters and newly generated theme textures follow as an optional later phase. A large world is an expansion target, not the first deliverable.

**Current status:** this package contains specifications and handoff materials. It does not contain an implemented Godot co-op game. The previous HTML proof is single-player and remains separate; its checks do not establish native co-op correctness.

## 2. Audience, platform and track

- Audience: pairs who enjoy responsive action, exploration, secrets and the pleasure of solving a small problem together.
- Initial platform: Linux desktop, with Arch Linux as the first developer environment.
- Engine: Godot 4.7.2 standard; typed GDScript; Compatibility renderer; Python 3 for original asset/data tools; Git.
- Preferred input: two gamepads. Required alternative: keyboard plus one gamepad.
- Phase 1 runs offline without an account, API key, generation service or downloaded game-content pack.
- Primary track: **Make Room for Play**. Demonstrate an original cooperative experience, not simply an asset-generation interface.
- Optional secondary track: **Works Anyway**, only if offline operation is deliberately designed, tested and demonstrated under that constraint.
- The supplied track text does not require online multiplayer or a model API. Do not invent those eligibility requirements.

## 3. Product pillars

| Pillar | Required expression | Evidence |
| --- | --- | --- |
| Moving is enjoyable | Responsive input, forgiving jump timing, readable landings | Two-person movement playtest before world expansion |
| A partner changes play | Bridge anchors, revival, optional Cross-stitch | Players can name a useful contribution from the other |
| One place holds two perspectives | Ember and Moss views differ while geometry agrees | Same encounter compared side by side |
| Exploration pays off | A remembered gap becomes reachable after a shared unlock | Fresh pair finds return route without coaching |
| Restoration feels consequential | New crossings, light chains, returning activity | Before/after state visible during the ending |
| Original assets belong together | Consistent pixels, silhouettes, palette and sound | Scene review and traceable source inventory |

These are hypotheses to test. Neither this document nor a coding model can guarantee fun.

## 4. Scope and gates

| Phase | Scope | Completion condition |
| --- | --- | --- |
| 1A | One-room fixed-character technical proof | Two real players, separate inputs/cameras, one shared enemy/state |
| 1B | Eight-room fixed-character MVP | Complete route and ending, all MVP acceptance checks |
| 2 | Optional pregame personalisation | Validated profiles/bundles, consistent animation, fixed fallback, no progression regression |
| 3 | Region-by-region production | Reviewed regions toward the 96-room authored budget |

Phase 1B first-clear target is 15–20 minutes. Measure it and revise it; never stretch corridors or enemy health to hit the number. Phase 2 may follow the completed slice before large-map production. Do not implement the generation service while Phase 1 controls, cameras or recovery remain unresolved.

### Exact Phase 1 budget

Two characters; eight rooms; two checkpoints; one named NPC, Oru; two normal enemy types, Spoolmite and Wickwing; one miniboss, The Spoolwarden; team Threadstep unlock; two Threadweave anchor pairs; one optional Cross-stitch combat payoff; one secret cosmetic lantern charm inside r03; one complete ending.

### Planned larger world

| Area | Rooms | Identity |
| --- | ---: | --- |
| Lantern Rest | 6 | Reconnecting settlement and communal looms |
| Wickerreach | 15 | Hanging gardens and moss-grown loom ruins |
| Ashloom Kilns | 15 | Cooled furnaces, soot and copper machinery |
| Bellglass Mire | 15 | Resonant glass and drowned walkways |
| Pale Archive | 15 | Folded records, paper-stone and ink shadows |
| Rootbound Foundry | 15 | Living roots integrated with old machines |
| Nightweft Crown | 15 | Exposed central loom beneath a starless canopy |
| **Total** | **96** | **Authored, interconnected rooms** |

Boss arenas, rest spaces, secrets and transitions count within each allocation. The eight MVP rooms are part of the 96, not extra. Full-game enemy/boss/quest counts and playtime should be budgeted after the first complete region establishes production cost. Do not fill the world with repetitive rooms to satisfy a spreadsheet.

## 5. User stories

### Phase 1: joining and understanding

1. As a player, I want to start without an account or network connection, so that setup does not prevent local play.
2. As a player, I want to claim a distinct controller or keyboard, so that my input moves only my character.
3. As a pair, we want to act simultaneously, so that cooperation feels immediate.
4. As a player, I want clear prompts for my device, so that I can learn actions without guessing.
5. As a player, I want to remap actions, so that I can play comfortably with my available controls.
6. As a player, I want a clear objective after the opening, so that I understand why we are exploring.

### Phase 1: action and cooperation

7. As a player, I want responsive movement and forgiving jump timing, so that mistakes feel fair.
8. As a player, I want my own camera and HUD, so that my character remains readable while my partner moves.
9. As a player, I want the same platforms and enemy outcomes as my partner, so that we can coordinate reliably.
10. As a player, I want a distinct special with understandable tradeoffs, so that my character contributes without making the other redundant.
11. As a player, I want enemies to warn before dangerous attacks, so that I can learn and respond.
12. As a player, I want a visible response when an attack connects, so that combat feels understandable.
13. As a pair, we want to restore a crossing from opposite anchors, so that working together changes the world.
14. As a player, I want to revive my partner under manageable pressure, so that a mistake can become a cooperative moment.
15. As a downed player, I want to understand my remaining rescue time, so that I know what is happening.
16. As a pair, we want a safe checkpoint recovery when rescue fails, so that neither player is stranded.
17. As a pair, we want an optional coordinated boss attack, so that good teamwork receives a satisfying reward.
18. As a player, I want to finish the boss without perfect coordination, so that the bonus does not become an exclusionary timing test.

### Phase 1: exploration and completion

19. As a player, I want to remember a blocked route and return with a new ability, so that exploration rewards attention.
20. As a pair, we want required traversal upgrades shared, so that neither player loses access to the main route.
21. As a player, I want room exits to wait for both of us, so that a partner cannot abandon me.
22. As a player, I want a readable map and landmarks, so that returning through the world is purposeful.
23. As a pair, we want secrets to reward curiosity without blocking progress, so that exploration remains optional.
24. As a player, I want to compare our views of the same location, so that the two visual perspectives become part of the experience.
25. As a pair, we want a visible restoration and clear ending, so that the short adventure resolves its promise.

### Phase 1: interruptions and recovery

26. As a player, I want either person to pause, so that an interruption does not punish the other.
27. As a player, I want both views to stop during dialogue or the map, so that I am not attacked while reading.
28. As a player, I want a disconnected controller to pause with reassignment options, so that losing a device does not kill us.
29. As a pair, we want saved unlocks and restored paths to survive closing the game, so that earned progress persists.
30. As a pair, we want missing or damaged saves handled visibly, so that recovery does not silently erase progress.
31. As a pair, we want a save failure to preserve the last valid file and current session, so that a storage problem is recoverable.
32. As a player, I want reduced shake/flashes and separate sound levels, so that presentation remains comfortable.
33. As a player, I want important cues to use shapes or motion as well as colour and sound, so that I can understand them in different conditions.

### Later-phase stories

34. As a player, I want a drawing to influence my character and visual theme, so that the adventure reflects my imagination.
35. As a player, I want to review and correct an interpreted character profile, so that a mistaken guess does not define my run.
36. As a pair, we want generated characters to obey balanced rules and retain shared traversal, so that unusual drawings do not make the map impossible.
37. As a pair, we want a fixed-character fallback if generation fails, so that a provider problem does not prevent playing.
38. As a player, I want accepted generation results saved locally, so that playing again does not repeat preparation or require connectivity.

## 6. Session and input requirements

- Provide title, new/continue, device assignment, fixed character selection, settings, game, pause, map, dialogue and ending states.
- Each player slot owns one input source. Starting with two gamepads or keyboard plus gamepad must never assign the same source twice accidentally.
- Devices may be reassigned while paused. Continue restores character profile identity, not stale operating-system controller indices.
- Character selection shows hearts, special, theme and common actions. Default Tavi/Neri pairing is immediate; replay may swap player ownership.
- Both players can request global pause. The opener owns menu navigation; either can return to play. Destructive new-game/reset actions require an explicit confirmation.
- Focus loss pauses. Assigned-controller loss pauses and preserves the world while offering reconnect, reassignment or return to menu.
- Map and dialogue pause both views. Keep dialogue brief; advance prompts identify the controlling player and permit agreed skipping.
- No solo mode, AI substitute partner or online matchmaking is required in Phase 1.

## 7. Shared world and split-screen requirements

- One World2D owns collision, actors, attacks, triggers, rewards and progression. Render the same simulation through two SubViewports and two Camera2D nodes.
- Logical composite is 960×360; each view is 480×360; divider overlays the join. Initial window is 1920×720.
- Use 16×16 world tiles and 32×48 character cells. Use nearest filtering, integer scaling with letterboxing and stable pixel presentation.
- Each camera follows its assigned character within the active room bounds. Frames remain predictable during damage, dash, revival and transition.
- Both characters stay in one active room for Phase 1. Independent cameras let them explore different parts of that room without loading different rooms.
- Both living players enter an exit rally zone and one confirms. Show the missing partner's state; do not silently reject interaction.
- Freeze both during transition, load the destination once, place both at validated nonhazardous spawn points, then restore control together.
- If a partner is down, require revival or offer team checkpoint recovery. Never transport only the living character.
- Visual layers contain no collision or gameplay scripts. Both views agree on floor edges, harmful areas, boss state and restored structures.
- Emit each semantic sound event once. Use one coherent music mix and a deliberate single-listener/mixing policy; a second camera must not double loudness.

## 8. Movement, combat and character builds

Both characters share the same tested movement and collider. Start with fixed 60 Hz physics, coyote time, jump buffering, variable jump height, responsive turning and controlled air movement. Put tuning in data and adjust from playtests.

| Property | Tavi | Neri |
| --- | --- | --- |
| Starting maximum hearts | 5 | 4 |
| Basic action | Short melee slash | Short melee slash |
| Special | Ember Arc: charged cleave and extra stagger | Spore Bolt: short projectile and normal-enemy slow |
| Theme | Ember | Moss |
| Shared traversal | Jump; team Threadstep after unlock | Jump; team Threadstep after unlock |

- These are unvalidated starting builds, not guaranteed balance. Cooldowns, damage and recovery must make both enjoyable without forcing a tank/support hierarchy.
- A slash has anticipation, active and recovery states; one attack can hit an enemy only once. Sprite dimensions do not define collision or damage reach.
- Damage has clear direction, brief invulnerability and safe recovery. No friendly fire or player-body blocking.
- Hit feedback uses a contact effect, sound and restrained hit pause/shake. Respect reduced-effect settings.
- Specials have visible readiness and cooldown. Neri's slow must not stack indefinitely; boss slow is capped or immune with readable feedback.
- Threadstep unlocks once for the team after the miniboss. Save it permanently; do not let character switching or later generated profiles remove it.
- Ordinary hazards use clear silhouettes and nearby safe recovery. Repeated respawn damage loops are failures.

## 9. Cooperative interactions and failure

### Threadweave

An authored pair has two anchors, assigned by interaction rather than character identity. Each courier activates a distinct anchor; the first latches visibly while waiting. Completing both restores a predefined bridge once and records its permanent flag. No tight simultaneous-input window is required.

The first pair teaches the mechanic safely at r02. The second applies it dramatically at r06. Restored collision changes once for the shared world, with corresponding art in both themes. A save/load or room return must not create a duplicate bridge or remove its flag.

### Cross-stitch

A boss stagger identifies the initiating player and exposes a marked seam. A hit by the other player within the readable opportunity triggers one shared burst. Either character can initiate or finish. Ordinary hits still work; solo repeated hits by the initiator do not impersonate the cooperative bonus. Missing the opening does not reset the fight or block victory.

### Downing and revival

At zero hearts, a player becomes an unravelled bundle with a clear 12-second countdown. A living partner holds interact nearby for 1.5 seconds; leaving range or taking damage interrupts. Completion restores 2 hearts and brief immunity. Countdown expiry or both players down starts team recovery.

Recover both at the active checkpoint with maximum hearts. Preserve permanent unlocks, defeated unique encounters, restored anchors and collected secret flags. Reset transient enemies, boss attempt state, projectiles and rescue timers. Pause, map, dialogue and transition freeze these timers.

Timing and healing values are tunable first-pass targets. Test accidental griefing, rescue readability and repeated defeat before increasing difficulty.

## 10. World route, encounters and rewards

| ID | Room | Purpose and content |
| --- | --- | --- |
| r00 | Lantern Rest | Oru, checkpoint A, join/controls, dark bridge home |
| r01 | Mossfoot Atrium | Memorable landmark; branch to the dash-gated causeway |
| r02 | Spindle Steps | Safe jumps and first Threadweave pair |
| r03 | Glasswing Gallery | Spoolmite/Wickwing lessons, both specials, secret pocket/charm |
| r04 | Warden's Landing | Checkpoint B, respite and boss warning |
| r05 | Broken Bell | Spoolwarden, optional Cross-stitch, team dash, shortcut to r01 |
| r06 | Severed Causeway | Safe dash practice, remembered gap, second anchor pair |
| r07 | Lantern Loom | Joint restoration, light returning, ending and safe r00 return |

- Initial main links: r00↔r01↔r02↔r03↔r04↔r05.
- Boss victory opens r05↔r01; team Threadstep permits r01↔r06; the causeway pair permits r06↔r07.
- Final restoration opens a safe return to r00 under the same rally/transition rules and records completion.
- Secret pocket stays inside r03. The cosmetic charm is shared, collected once, and never required for progression.
- Spoolmite pauses visibly before a ground charge. Wickwing marks its line before an aerial dive. Introduce separately before combining.
- Spoolwarden uses distinct sweep, delayed ground strike and recoverable charge. Lower health may combine familiar patterns, not introduce an unexplained lethal move.
- Rewards and unique encounter flags commit once. Both players striking the final hit or interacting on one frame must not duplicate rewards.

## 11. Story and visual perspective

The immediate objective is restoring the Lantern Loom so a stranded district can cross home. The night tide is narrative urgency, not a timer. Oru explains the objective briefly; repairs and returning light supply the main exposition.

Ember emphasises warm machinery, brass ribs and amber seams. Moss emphasises roots, cooler stone and luminous growth. Both retain common landmark silhouettes and danger grammar. Do not make theme differences a mandatory “describe the hidden platform to your partner” puzzle in Phase 1.

The complete slice resolves its local story while suggesting that the central loom imposed one brittle pattern on the Weftlands. The proposed campaign explores preserving different perspectives without erasing either. See [STORY_BIBLE.md](docs/STORY_BIBLE.md) for room beats, dialogue drafts and the regional arc.

## 12. Original content and future generation

- Author all shipped sprites, tiles, backgrounds, animation, maps, icons, glyphs, effects, sounds, music and writing within the project.
- No bought/downloaded resource packs, stock content, ripped assets or asset-store art placeholders in a completed slice. Engine, language and tooling dependencies are allowed.
- Broad inspirations concern responsive action, pixel detail and interconnected exploration. Do not copy identifiable characters, silhouettes, maps, scenes, melodies, dialogue, UI or names from existing games.
- Retain editable original sources and a manifest linking dimensions, pivots, animation states, palettes and provenance to built outputs.
- Phase 1 reads fixed character/theme manifests. Prepare the interface, not a speculative generation backend.
- Phase 2 first interprets drawings into allowlisted traits and template-driven appearances; constrained image generation follows only after animation and tileset validation work.
- Generate during pregame, validate results, let players approve profiles, cache accepted assets and provide fixed fallback. Do not place model requests in movement, combat or saving.
- Generated output never changes canonical collision, mandatory team traversal, enemy logic or executable gameplay code. Stats remain bounded and specials come from implemented IDs.
- Preserve character identity, theme bundle and progression references in saves. An unavailable provider must not invalidate an existing local campaign.

## 13. Persistence, settings and accessibility

- Use one versioned campaign save for team progress: profile IDs, checkpoint ID, explored rooms, team unlocks, restored anchors, boss/secret flags and completion.
- Load both at validated checkpoint spawns rather than reconstructing an arbitrary combat frame. Store settings and device bindings separately.
- Save at checkpoints and permanent changes. Coalesce duplicate requests; do not write every physics frame.
- Write safely through a temporary file and replacement, retaining a last-known-good backup. Report failure while preserving the current session and previous valid file.
- Missing save permits new game. Corrupt or unsupported newer save offers explicit recovery; do not silently overwrite it.
- Offer remapping, deadzone adjustment, separate music/effects volume, reduced shake, reduced flashes and readable text.
- Vital cues use shape/motion/text as well as colour or audio. Pause and focus-loss behaviour apply to both players consistently.

## 14. Performance and verification requirements

Target steady 60 fps on the development laptop at 1920×720 with both views; this remains unverified until measured. Record build, device, room, resolution, frame-time behaviour and particle/light load. Two camera views are rendering work, not a reason to simulate actors twice.

Use high-level scenario tests for device ownership, real attacks/damage, revive interruption/expiry, one-time bridge/reward state, pre/post-dash access, room transitions and save recovery. A graph being connected does not prove a jump or simultaneous route is playable.

Headless import and scenario results are useful evidence but do not prove rendering, gamepad ergonomics, audio, frame pacing or fun. Inspect real scenes and play through the complete route with normal controls. Debug warps/unlocks may isolate states but never count as an ordinary completion.

## 15. Phase 1 acceptance and human review

- A clean checkout can generate original assets, validate content, import the project and launch using documented commands once implemented.
- Two distinct devices control two distinct characters simultaneously; focus/controller loss pauses safely and reassignment does not reset progress.
- Both cameras show one consistent physical world, with no duplicate enemies, hits, rewards, triggers or sounds.
- Every required room, checkpoint, anchor pair, boss, shortcut, dash gate and ending works with either player ownership of Tavi/Neri.
- Save/reload after each permanent milestone preserves progress and respawns both safely. Invalid/unwritable save paths have verified recovery.
- Either courier can rescue the other; interruption, expiry, both-down and paused-timer cases behave as specified.
- Cross-stitch works in either role order, while a pair can defeat the boss without it.
- Ember/Moss scenes pass platform-edge, hazard, telegraph, silhouette, frame-origin and native-pixel readability review.
- Installed play from title through ending requires no account, API key, asset download or network.
- At least two fresh pairs attempt the slice. Record completion time, deaths, unprompted confusion, rescue use, exit friction and a brief enjoyment rating. Do not invent results.
- Initial usability targets: pairs identify the opening goal, restore the first bridge without spoken developer coaching, recognise the earlier dash gate and explain the ending. Repeated failures trigger redesign before expansion.
- Ask each player what felt satisfying and what they would change. A high completion rate alone does not establish fun.
- Final delivery reports implemented, automatically checked, visually checked, human-tested, unverified and planned items separately.

## 16. Explicit exclusions

Phase 1 excludes online/LAN networking, dynamically merged cameras, separate-room exploration, AI partner substitution, drawing/upload, runtime image generation, arbitrary model-authored abilities, generated map geometry, a 96-room content dump, 3D, mining/destructible terrain, survival meters, deep crafting, large equipment trees, procedural quests and a combinatorial branching narrative.

Phase 2 personalisation and Phase 3 expansion are distinct gates. The fixed-character game remains the reliable baseline. Scope changes should identify the player benefit, cost and acceptance evidence before implementation.
