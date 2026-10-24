# Phase 1 room integration and traversal checks

The eight authored rooms are structural content, not a measured playthrough. All heights, jump timing, enemy separation, rally placement and the two visible gap compositions need Agent 1's real motor and normal-input verification before they can be called playable.

## Fixed data supplied

- r00 through r07 contain 18 directed rally exits matching the nine exact undirected world links and their `requires_all` flags.
- `start` remains `[[6,19],[9,19]]` in r00. Checkpoint entrances are `checkpoint_a` in r00 and `checkpoint_b` in r04; ordinary destination entrance names are `from_rXX`. No exit relies on a fallback to `start`.
- Exactly one Oru, two checkpoints, two anchor pairs, one secret charm, one Spoolwarden and one two-station Lantern Loom. r03 teaches Spoolmite before Wickwing and then combines them.
- Room sizes: r00 60x23, r01 70x25, r02 70x25, r03 90x26, r04 54x23, r05 90x26, r06 90x26, r07 64x25. These are tile counts, not a playtime claim.
- The exact diagnostic r00 is retained in `tests/contracts/content_valid_r00.json`, with two invalid data-only variants for fractional spawns and an unresolved target entrance. These fixtures do not become shipped room content.

## Motor measurements requested

Provide the current movement constants and measured maximum reliable horizontal distance at equal height, rise supported by a full jump, short-hop rise, air-control distance, dash duration/distance, coyote/buffer timing and whether dash is allowed airborne. Record both fixed characters, the 12x24 collider and 60 Hz configuration. Practical safe margins must be based on those measurements, not just ballistic formulas.

The live runtime source was inspected: `GRAVITY=1400`, `JUMP_SPEED=-330`, `MAX_SPEED=110`. Continuous ballistic estimates are 38.9 pixels of rise and 51.9 pixels of equal-height travel at full horizontal speed; these are calculations, not engine measurements. All required/secret ascent routes were revised to rises of at most two tiles with adjacent stepping ledges. One-way intermediate ledges were added in r01/r02/r03/r05/r06/r07, and r06's lower recovery bed has an escape shelf. Stable entrance/anchor/checkpoint coordinates were preserved.

Agent 1 subsequently published real-physics measurements in runtime commit `b1ff5d6`, `evidence/runtime/traversal.md`: full jump rise **41.74 px**, running same-height feet travel **55.00 px**, and **30 airborne physics ticks**, using Godot 4.7.2 at 60 Hz and the 12x24 collider. Their exact recorded command was:

```sh
godot --headless --fixed-fps 60 --path . --script tests/run_tests.gd --log-file /tmp/gloamthread-content-session.log -- --filter content_session
```

Agent 1 ran that scenario against Drop A's diagnostic r00, with an isolated reset location and owned command snapshots. Agent 2 read the committed result; this is not an Agent 2 engine run or a full-route playthrough. It supports the two-tile-rise draft limit, but does not certify combined gaps. Their guidance is at most one-tile combined rise/gap steps, two-tile flat gaps, and preferably five tiles of headroom for an uncut jump (measured body clearance 66 px). Check these conditions in each real room, especially under upper shelves. Dash remains unimplemented/unmeasured at that checkpoint.

The broad upper r01 span and r06's nine-tile gap are visual drafts awaiting the measured dash envelope. The r01 route has an accessible approach and a `threadstep` exit requirement; this is not evidence of a physically tuned dash lesson. The r06 gap has a lower safe recovery bed, so it currently demonstrates a crossing without imposing a lethal failure. Agent 1 must report whether ordinary jumping bypasses the intended dash lesson and whether the physical route needs revision.

Both bridge anchor pairs are reachable from the lower safe route before restoration. The elevated bridge is a new crossing/shortcut; its paired exit gate is also tied to the permanent bridge flag. Verify each player can reach either anchor, recover from falling below the unbuilt bridge, and leave after restoration. Never require the bridge itself to reach the second anchor.

## Required real-engine route checks

1. r00: both start feet spawn safely; checkpoint restores at its named pair; Oru does not overlap an exit; the home return remains locked until loom restoration.
2. r01: main lower route is clear below the themed bell-tree landmark and one-way shelves; both players can reach the boss shortcut after victory and the upper causeway branch with Threadstep. Returning through either upper entrance cannot strand a player.
3. r02: normal-input ascent to either anchor before restoration, one-player latch readability, permanent shared bridge, fall recovery and `bridge_spindle` exit gate. The ten-tile bridge span starts empty.
4. r03: first Spoolmite tells are readable before the first Wickwing; specials have space; no mandatory damage; optional charm shelf can be reached without dash and returned from safely. Tune the two-tile platform ladder with measured jumps. A three-tile hazard strip at x59..61/y17 sits on a raised optional shelf under a one-way canopy, with safe end tiles, a warning sign and a clear ground route below. Its underside is above the 48-pixel sprite's head on the main route; it does not turn the first enemy lesson into forced hazard damage.
5. r04: both named checkpoint spawns and both exit rallies are safe; no boss interaction crosses the room boundary.
6. r05: sweep, ground strike and charge have usable dodge/recovery space; upper one-way shelves cannot permanently defeat boss targeting; both entrances are outside immediate boss contact. Boss outcome opens the shortcut once.
7. r06: dash lesson and gap use actual measured distance with safe retry; both anchors remain reachable before restoration; restore `bridge_causeway` and transition together to the Loom.
8. r07: both stations are reachable; either player can occupy either station; restoration permits the return to r00 and keeps the same both-living-player rally semantics.

## Runtime presentation requests

Room `decor` is render-only and contains no conditional gameplay logic. Use the single authoritative progression state to select the supplied latched/lit prop frames for runtime-owned anchors, checkpoints and the Loom. For the ending, r00's decorative lanterns should change from frame 6 to 7, its loom from frame 2 to 3, and the home route should receive the restoration effect while `loom_restored` enables its exit. Keep the warm/cool theme palettes distinct and the physical edge masks identical. The content bundle provides concise ASCII dialogue and optional `charm_found`, `causeway_restored` and `warden_warning` sequences in addition to the five required IDs.

Do not place a second static anchor or checkpoint sprite from decoration over the entity's runtime visual. There are no gameplay scripts, ability tuning fields or collider sizes in presentation data.

## Evidence so far

- The exact diagnostic r00 passed `python3 tools/validate_content.py --stage diagnostic` against the actual diagnostic manifest/font before it was replaced with final Lantern Rest.
- `python3 tools/validate_content.py`: PASS against the actual generated full manifest/font copied from the content checkout.
- `python3 -m unittest discover -s tools/tests -p 'test_content.py'`: 29 tests pass. Tests use intentionally synthetic asset records to isolate content/reference validation; this is not full asset validation. Negative tests cover null spawn maps, NUL/executable paths, missing causeway bridge distribution and rally rectangles whose exclusive bottom omits standing feet.
- Full content is authored and structural rules cover all room files, IDs, schemas, integer coordinates, footprint headroom/support, directed exit references, world flags, checkpoint references, bridge spans, dialogue glyph coverage and render-only decoration.
- Godot imports, normal-input traversal, native animation/readability, audio listening, gamepads, export and human fun/playtime remain separate integration evidence. Agent 1 owns authoritative runtime results.
