# Gloamthread: Two Ends — verification and playtest plan

Version 2.0 · Phase 1 acceptance contract · 24 October 2026.

**Current status:** 18 engine scenarios pass, including the actual-App eight-room route to ending, combat, timing, menus, actual-file persistence and malformed content. Native rendering and exported performance/offline verification are being completed. Physical controllers, audio listening and fresh two-person playtests remain unverified. See [campaign evidence](../evidence/runtime/campaign.md) and [status](STATUS.md).

## 1. Evidence levels

Keep the following evidence separate in every report:

| Level | Establishes | Does not establish |
| --- | --- | --- |
| Document/example checks | IDs, references, budgets and any included example syntax agree | Gameplay exists |
| Godot import / parse | Project and resources can load in the named engine version | Combat or controls work |
| Headless scenarios | Specific game-state behaviours under actual game code | Visible clarity, device input, audio or enjoyment |
| Rendered automated checks | Actual scenes render and scripted inputs affect them | Comfortable controller handling or human game feel |
| Two-device manual check | Simultaneous assigned devices and recovery paths work | New players understand the game |
| Two-human fresh playthrough | The intended adventure is understandable and completable in practice | Every future generated build or room is safe |

Record engine/build version, platform, date, exact scenario, result and evidence location. State failures and untested checks explicitly. Debug warps, forced flags and synthetic boss defeats may isolate a scenario, but never count as an ordinary full-route completion.

## 2. Minimal verification seams

Implement `tests/run_tests.gd` as a small built-in GDScript scenario runner. No downloaded testing addon is required. It should instantiate the real session/room/actor components, issue actions at simulation ticks, assert observable outcomes, print useful failures and exit nonzero when a check fails.

Prefer real Godot physics steps for movement/collision tests. Use temporary save directories and actual serialization for persistence. Stub only external boundaries that cannot be exercised safely; Phase 1 has no model-provider boundary to mock.

Use a Python content validator for room graph references, requirements, anchor pairs, profile bounds and asset IDs. Use the asset validator for frame/palette/atlas/audio contracts. A graph check does not prove a jump, timed dash or two-person puzzle is physically possible.

Current implementation commands:

```sh
python3 tools/generate_assets.py --seed 18427
python3 tools/validate_assets.py
python3 tools/validate_content.py
godot --headless --path . --editor --import
godot --headless --path . --script tests/run_tests.gd
godot --path .
```

For fresh checkouts use `godot --headless --path . --editor --import --quit` before the scenario runner. Use `--fixed-fps 60` for accelerated scenario checks; native performance QA explicitly refuses accelerated/headless runs.

## 3. Acceptance matrix

| ID | Scenario and expected result | Required evidence |
| --- | --- | --- |
| A01 | Fresh start reaches join screen, assigns two distinct devices, shows both characters and starts r00 | Import plus rendered/device check |
| A02 | Hold P1 left while P2 jumps/attacks; each action affects only its assigned actor | Two actual devices; headless ownership scenario |
| A03 | Controller reconnect preserves a clear reassignment choice; disconnected input is neutral and game pauses | Hotplug manual check |
| A04 | Rebinding an action updates the correct player and visible prompts; conflicting assignment is explained | Manual remap + settings reload |
| A05 | Both views show one shared world; an enemy hit in one view loses health once in both | Scenario + simultaneous-view capture |
| A06 | Theme layers contain no colliders/triggers; switching their visibility changes no simulation outcome | Scene/content validation + state comparison |
| A07 | Jump buffer, late ledge jump, short/full jump, corner collision and one-way landing work at intended tick boundaries | Actual physics scenarios + human movement room |
| A08 | One slash damages one target once; simultaneous different players' valid attacks follow the documented damage rule | Combat scenarios |
| A09 | Damage grants recovery immunity; respawn and revive cannot immediately loop damage | Hazard/combat scenarios + manual check |
| A10 | Tavi's Ember Arc and Neri's Spore Bolt affect real enemies; boss slow follows its declared limit | Encounter scenarios + rendered effect check |
| A11 | One anchor activation latches visibly; distinct partner activation restores the authored bridge exactly once | Puzzle scenario + two-human check |
| A12 | One player cannot activate both ends as a substitute for cooperation; completed anchors persist | Scenario and save round trip |
| A13 | A lone player at an exit cannot transition; two living players rally and one activates exactly one room change | Transition scenarios + device check |
| A14 | Downed player remains for 12 simulation seconds; partner's 1.5-second revive restores 2 hearts and immunity | Boundary-timed scenarios + rendered timer |
| A15 | Damage interrupts the rescuer; moving out of range does not accumulate hidden revive progress | Revive scenarios |
| A16 | Downed timeout or both down cause one team recovery; permanent flags survive, encounter state resets, both heal to maximum | Recovery scenarios |
| A17 | Pause, map, dialogue, focus loss and controller disconnect freeze gameplay timers consistently | Scenario + window/device checks |
| A18 | Spoolwarden can be defeated without Cross-stitch; valid stagger/partner follow-up grants its optional payoff once per window | Normal-control fight + isolated scenarios |
| A19 | Boss defeat grants team Threadstep once, opens the shortcut, and stays completed after recovery/reload | Progression scenario + save round trip |
| A20 | r01→r06 is blocked before Threadstep and traversable after it by both characters using normal movement | Pre/post unlock physics + manual route |
| A21 | Causeway Threadweave opens r06→r07; both players can restore the loom and reach the ending | Ordinary two-player full route |
| A22 | Cosmetic secret in r03 is collected once and persists without affecting mandatory progression | Scenario + reload |
| A23 | Save loads at the canonical safe checkpoint with team flags/profiles intact; settings remain separate | Actual file round trip |
| A24 | Missing, corrupt, truncated and unsupported-newer saves produce clear recovery; valid previous data is retained | Fault-injected save tests |
| A25 | Write failure does not erase the previous valid save; a visible notice leaves the current session playable | File-boundary test + UI check |
| A26 | Both themes retain readable floors, hazards, boss tells, HUD and player identities at native resolution | Side-by-side 1× rendered review |
| A27 | Each sound event plays once; music/effects settings persist; muted play retains all required cues | Real audio/device check |
| A28 | An installed release launches, saves and finishes with network disabled and no API key | Offline two-human run |
| A29 | Complete route runs steadily on a named machine at 1920×720; capture frame-time data in the busiest encounter | Measured release-build session |
| A30 | Fresh players complete the adventure without debug tools or spoken developer instructions | Observed two-human playtest and notes |

Pass all applicable gates before calling the eight-room MVP complete. A blocked rendering/audio environment leaves A26/A27 unverified; it does not turn them into source-review passes.

## 4. Detailed edge cases

### Inputs, screens and shared state

- Start with two controllers, then repeat keyboard + controller. Two players on one keyboard are optional and subject to hardware rollover; do not claim universal support.
- Exercise simultaneous directions, attacks, interact and pause inputs. Decide a stable priority for global menu actions and prevent a double confirm from skipping dialogue or starting twice.
- Disconnect either assigned device while moving, while reviving and during a boss warning. The affected actor must not retain a stale held action after pause/reconnect.
- Check when cameras are far apart within the same room: off-camera attacks remain real, but enemies do not update twice because two views can see them.
- At a room boundary, hold both players in the rally zone and spam interact. There is one transition transaction, one new enemy set, one checkpoint decision and safe spawn spacing.
- Repeat the exit test with one player downed or timing out. Recovery/transition arbitration must not create separate rooms or stranded input ownership.

### Combat and recovery

- Attack through the same target for several active ticks. One swing ID may apply damage at most once to that target; independent valid player attacks retain their own IDs.
- Verify no player collision blocks a partner's jump and no friendly attack/projectile damages the partner.
- Take two overlapping enemy hits at the same tick, recover near a hazard, and revive against an arena wall. Immunity and safe positioning prevent a repeated damage trap.
- Pause with 0.1 seconds remaining on downed timeout; wait in real time, then resume. The timer advances only with gameplay simulation.
- Test a rescue completed at the same tick as timeout, plus simultaneous lethal hits. Choose and document deterministic event priority; award neither duplicate revives nor duplicate recovery.
- Checkpoint recovery resets enemies, projectiles, attack state, temporary slows and incomplete boss phases. It keeps defeated-boss, restored-bridge, collected-secret and shared-unlock flags.
- Boss defeat simultaneous with a team wipe must have a single documented persistent result. Test the chosen policy and restore a safe playable state.

### Save and content consistency

- Save immediately after each permanent event: first bridge, boss reward, causeway bridge, secret and final restoration. Close/reopen and verify canonical checkpoint recovery plus the new flag.
- Retain unknown/newer save data for diagnosis and do not silently overwrite it with a blank campaign. Recovery UI must distinguish continue backup from new game.
- Reject checkpoint/profile IDs missing from the loaded content version. Use a declared recovery policy rather than trusting arbitrary saved coordinates.
- Re-enter every room after boss defeat and ending. Enemy persistence policy, shortcuts, Oru's dialogue and restored scenery remain consistent.
- A requested texture or animation missing from the fixed manifest produces an actionable validation error; runtime cosmetic fallback cannot hide a required collider or mechanic.

## 5. Movement and performance checks

At 30, 60 and 144 render caps, feed the same tick-indexed input into the same build for at least 600 physics ticks. Compare unlock/health/encounter outcomes exactly and actor positions within one world pixel. Do not claim cross-platform bitwise physics determinism.

Measure the release build on a named laptop, noting engine version, renderer, display mode, both viewport sizes and settings. Target a steady 60 FPS; record frame-time percentiles and visible transition hitches rather than inferring performance from a screenshot. Test at least one continuous traversal and the boss with both players using effects.

Test 1× 960×360 and the initial 2× 1920×720 window, then one larger and one awkward aspect ratio. Letterboxing must preserve square pixels, readable per-player HUDs and the equal split. Inspect slow scrolling, jump apex and moving thin details for camera shimmer.

## 6. Playtest for enjoyment

Fun cannot be guaranteed by a specification. Observe at least two fresh pairs for the eight-room MVP's human-playtest gate. One pair can supply early technical-proof feedback, but does not complete that full gate. Use ordinary controls, a fresh save and visible in-game prompts. The designer stays silent unless a crash or blocker ends the run. If testers are unavailable, mark the gate unverified and ship only a candidate for playtesting.

Record the following observations, not invented scores:

| Question | Initial target / signal | Revision if missed |
| --- | --- | --- |
| Can both players identify themselves and move? | Within 30 seconds of entering r00 | Simplify join prompts and strengthen silhouettes |
| Can the pair restore the first bridge? | Understand distinct anchors without spoken instructions | Improve latch feedback, anchor framing and prompt placement |
| Does either player feel like an assistant? | Both name a useful action they performed | Rebalance opportunities and special feedback |
| Is danger readable? | Players can explain most recent damage events | Revise tells, colour/shape contrast and clutter |
| Does rescue feel cooperative? | One understandable revive, no repeated punishment loop | Adjust safe recovery, channel timing and enemy pressure |
| Is exploration rewarding? | Players notice the earlier gate or optional secret clue | Improve landmark and return-path composition |
| Does the ending land? | Players describe what they restored and why it mattered | Show residents/bridge change; reduce unexplained text |
| Would they replay or continue? | Ask each player independently, with reasons | Prioritize repeated complaints before adding rooms |

The 15–20-minute first-clear target is a hypothesis. Record actual clear time, retries, confusing waits and inactive time per player. Fix severe boredom, confusion, unreadable damage or one-sided contribution before adding content to hit a room count.

## 7. Release evidence bundle

The implementation report should include:

- Exact startup, validation, import, scenario and packaging commands with outcomes.
- A completed A01–A30 matrix with pass/fail/unverified and evidence paths.
- Rendered captures of both views at spawn, a telegraph, the first bridge, downed/revive, boss exposure, the dash route and ending.
- One ordinary two-player complete-route recording or direct observation log; label any debug-assisted captures separately.
- Playtest notes and the highest-priority revisions, including unresolved limitations.
- Asset provenance summary and offline run result.
- Named-machine performance measurements and controller configurations.

Do not call all content generated, all tests passed, or the game polished when only a subset has evidence. Phase 2 adds its own generated-asset, malformed-bundle, timeout/fallback, stat-budget and duplicate-archetype gates; they are not requirements to implement during Phase 1.
