# Agent 2 — content and assets

Build the complete original content bundle for Phase 1 of **Gloamthread: Two Ends** while Agent 1 builds the Godot runtime. Deliver usable content in small integration drops, starting with the assets and room needed to launch M0. Continue through all eight authored rooms and the final art/audio bundle; a diagnostic pack is the first milestone, not the final deliverable.

This brief is the current two-agent assignment. It replaces the older three-worker split and the instruction to wait until M1 before beginning asset work. The fixed contracts below allow both agents to start immediately. The game remains Godot 4.7.2 standard, typed GDScript, Compatibility renderer, Linux first, with Python 3, Pillow and NumPy for development tools. Phase 1 has no runtime model calls, uploaded characters, network service or 96-room expansion.

## 1. Start in your own checkout

Wait for Agent 1 to publish the preparation commit containing both agent briefs and the preallocated log sections. Then use a **separate clone**, not the runtime checkout:

- Repository: `https://github.com/9MidhunPM/GloamThread.git`.
- Your checkout: `/home/midhun/Coading/GloamThread-content`.
- Your branch: `feat/phase1-content`, starting at that preparation commit.
- Agent 1's branch: `feat/phase1-runtime` in `/home/midhun/Coading/Gloamthread`.
- Commit identity: `Midhun P M <midhun.titan@gmail.com>`.

If your checkout or branch already exists, inspect its status, origin and ancestry and preserve its work. Never repurpose the runtime checkout. Read `AGENTS.md`, `README.md`, `MVP.md`, `HANDOFF.md`, `docs/DECISIONS.md`, `docs/ARCHITECTURE.md`, `docs/ART_AUDIO_PIPELINE.md`, `docs/STORY_BIBLE.md`, `docs/TEST_PLAN.md`, the implementation/task plans and `examples/README.md` before authoring. Treat the generation roadmap only as a later-phase boundary.

Initial state at preparation commit `2fea1ef`: only partial project/input/audio/room scaffolding existed, with no engine/gameplay acceptance. Content and runtime have since advanced; [STATUS.md](STATUS.md) and [content evidence](../evidence/content/README.md) record current delivery. Example JSON illustrates contracts; shipped content lives under `content/` and passes the validators.

## 2. Exclusive ownership and integration

You own:

- `content/**`: fixed profiles, themes, world graph, ability data, all room files **including r00**, dialogue and authored presentation data.
- `assets/source/**`, `assets/generated/**`, and `assets/manifest.json`.
- `tools/generate_assets.py`, `tools/validate_assets.py`, `tools/validate_content.py`, `tools/gen/**`, `tools/tests/**`.
- Data-only contract fixtures under `tests/contracts/**`; coordinate names with Agent 1 before adding them.
- `evidence/content/**`, including a `README.md` with your tool setup/commands, packet SHAs, measured checks, previews and remaining integration requests. Agent 1 incorporates applicable instructions into the central README when merging.
- Only the preallocated **Agent 2 — content and assets** sections of `CHANGELOG.md` and `AI_USAGE.md`.

Agent 1 owns `project.godot`, all runtime `scripts/**` and `scenes/**`, every GDScript test, shared runtime contracts, integration/status/player-facing documentation, export and final packaging. Agent 1 alone performs authoritative Godot imports and records importer-generated sidecars; do not create competing sidecar edits. Send required runtime changes and contract corrections to Agent 1 instead of editing their files. Presentation metadata never decides damage, collision, movement, cooldowns or progression transactions.

Keep your branch cumulative. At each coherent drop, run the relevant checks, update only your log sections with an actual timestamp/timezone and tool attribution, explicitly stage your files, commit and push **only `feat/phase1-content`**. Supply the exact commit SHA and handoff described in section 8. Agent 1 will integrate repeated drops through true merges. Preserve the same ancestry: no cherry-pick replay, rebase of published drops, squash of the development record, force-push or publication to `main`. Do not merge runtime work into your content branch merely to preview it; arrange preview/integration with Agent 1.

## 3. Deliver in this order

### Drop A — unblock the one-room tracer

Create the generator, manifest and validators with an explicit diagnostic stage. Produce:

- `assets/generated/diagnostic/tiles_diag.png`: **160×120**, eight columns by six rows of 16×16 cells, 2px padding on each side, 20px stride. First four cells: solid fill, solid top with a readable edge, thin one-way surface and hazard chevron. Existing `GrayboxSkin` depends on this exact path/layout.
- `courier_tavi_diag.png` and `courier_neri_diag.png` in that directory: 32×48, distinct original silhouettes/colours, feet origin `(16,43)`.
- `mover_diag.png`: 32×32, origin `(16,28)`.
- The original bitmap font source and usable PNG/BMFont `.fnt`, so runtime UI can adopt project-authored glyphs early.
- `content/rooms/r00.json`: exactly **60×23** tiles, floor and forgiving ledges, at least one one-way platform, `start` spawns `[[6,19],[9,19]]` with empty headroom and ground below; one `diagnostic_mover` with ID `mover`, tile `[30,19]`, `range_tiles:6`.
- Real fixed profile/theme data and an initial world definition derived from the examples, with `example_only` removed. Diagnostic validation may accept the explicitly incomplete bundle; full validation must report what remains missing.

Use manifest IDs `fixed_tavi_v1` and `fixed_neri_v1` from this first drop onward. Diagnostic sprite records can use the eventual animation contract with one frame referenced by each required clip, marked `diagnostic:true`; they do not satisfy the final animation budget. Preserve the IDs when replacing the images with final atlases. Every diagnostic output still has retained source and provenance.

**Gate:** the diagnostic commands in section 7 pass; Agent 1 can load r00, resolve both profile visuals and the exact diagnostic terrain/mover paths without guessing. Report that the bundle is diagnostic. Deliver this drop before attempting the full art inventory. Agent 1 may use its own temporary test fixture while waiting, but r00 remains exclusively yours.

### Drop B — feed movement, combat and recovery

Complete courier silhouettes and required animations, Spoolmite, slash/special/hit/revive effects, readable hearts/prompts and the associated sound cues. Supply draft r02/r03 layouts using Agent 1's measured movement bounds. Request their current jump/dash envelope rather than inventing final distances. Deliver assets incrementally with stable IDs so real animation and sound can be reviewed during M1/M2.

**Gate:** generated frames, states, pivots, sources and audio pass structural checks; Agent 1 can exercise real combat/recovery presentation. Native-resolution animation and listening remain explicit review gates.

### Drop C — prove the finished visual direction and cooperation

Finish Ember/Moss terrain, backgrounds, props and the r00/r02 compositions first. Add paired-anchor bridge content, checkpoint/Oru data and cooperative cues. Both visual themes must identify the same physical edges and hazards. Keep room landmarks legible at 480×360; stitched material planes and deliberate silhouettes must replace diagnostic rectangles before a finished-room claim.

**Gate:** Agent 1 has one finished room in both views, one bridge interaction and the data for a room transition. Review actual captures and motion at 1× before multiplying room decoration. A contact sheet or manifest count alone does not pass this gate.

### Drop D — close the eight-room adventure

Author r00–r07, Wickwing, Spoolwarden, the shared lantern charm, the boss shortcut, safe dash lesson, causeway anchor pair, Lantern Loom and ending/return dialogue. Include distinct landmarks and original dressing, not eight repeated corridors. Replace r00's diagnostic mover/content with the final Lantern Rest without changing stable entrance/checkpoint references. Finish all three original music arrangements and remaining cues.

**Gate:** all eight rooms and every required reference/gate validate; Agent 1 can integrate the full route. Apply their recorded traversal, boss readability and pacing findings through focused content changes. A static graph pass does not establish that either courier can actually cross a jump or reach an anchor.

### Drop E — finish, rebuild and support integration

Run the full generator twice with seed 18427 and verify identical output/manifest hashes; keep timestamps out of deterministic artifacts. Finish provenance, palette/frame/audio checks, complete all original source inventory and resolve content defects from the actual runtime route. Ensure full content consumes no diagnostic records. Preserve unverified human, gamepad, listening and export checks honestly.

**Gate:** all full-stage commands pass, the required inventory is complete, and Agent 1 has an exact cumulative commit plus evidence/limitations. Stay available for concrete integration defects within your ownership; do not start Phase 2.

## 4. Fixed asset and audio contract

Every JSON manifest uses `schema_version:1`; the bundle uses `content_version:"phase1-v1"`. The asset manifest has `schema_version`, `content_version`, `generator_version`, `seed`, `stage`, `assets`, `sfx` and `music`. `stage` is `diagnostic` or `full`. `sfx` and `music` map the names below to asset IDs.

Every asset record has `id`, `kind`, `path`, `sha256`, `diagnostic` and `sources:[{"path":...,"sha256":...}]`. `kind` is one of `sprite_atlas`, `tile_atlas`, `image`, `font`, `sfx`, `music`. Output paths are repository-relative beneath `assets/generated/`; retained source paths resolve beneath the repository/bundle root. Reject traversal, absolute paths, remote URLs, executable-resource paths, duplicate IDs and unresolved references. Retain editable source and hashes for every shipped output; generation uses repository-authored content, not downloaded resource packs, stock fonts, samples, soundfonts or copied game assets. The font `.fnt` record has `texture_id` referencing its separately manifested PNG image.

Image records add `size:[width,height]`. Atlas records add `cell_size:[width,height]`, `origin:[x,y]`, `frames:[[x,y,width,height],...]`, and `animations:{state:{"frames":[indices],"ticks":[positive_integer_ticks],"loop":boolean}}`. Frame indices and tick lists have equal lengths; every index/rectangle is valid. Tick durations use the game's 60Hz presentation clock. Sprite origins are measured within the unpadded cell; metadata does not alter colliders. Terrain records add `tile_ids`, aligned one-to-one with frame indices.

| Asset family | Required final output |
| --- | --- |
| Tavi/Neri | IDs `fixed_tavi_v1` / `fixed_neri_v1`; 32 frames each, 32×48 cells, origin `(16,43)`, 8×4 padded atlas **288×208** |
| Oru | 8 frames, 32×48 cells, origin `(16,43)`, **288×52**; idle 4, talk 2, restoration acknowledgement 2 |
| Spoolmite | 16 frames, 32×32 cells, origin `(16,28)`, **288×72**; idle 2, walk 4, anticipation 2, charge 2, recovery 2, defeat 4 |
| Wickwing | 14 frames, same cell/origin/atlas as Spoolmite; flap 4, anticipation 2, dive 2, recovery 2, defeat 4; last two atlas cells transparent |
| Spoolwarden | 32 frames, 64×64 cells, origin `(32,59)`, **544×272**; idle 4, three attacks with 2 anticipation + 2 active + 2 recovery each, stagger 4, defeat 6 |
| Terrain | IDs `terrain_ember_v1` / `terrain_moss_v1`; identical 48-slot ordering and canonical edge masks; 16×16 cells, **160×120** each |
| Props | 16 logical props, including anchors, loom, bell, lantern, sign and checkpoint; retained source and declared frame/origin data |
| Backgrounds | Three distinct layers per theme, six images total, initially **480×360**; declared finite extent or deliberately matching scrolling seam |
| Effects | Eight sequences × six frames: slash, Ember Arc, spore impact, dash, hit, weave, revive, restoration; 32×32 cells, with 64×64 allowed for restoration |
| UI | Twenty 16×16 icons, padded 5×4 atlas **100×80** |
| Font | Original 5×7 glyph source; 95 printable ASCII characters + replacement glyph, 16×6 cells of 6×8, **96×48** PNG plus BMFont `.fnt` |
| Audio | Eighteen original semantic cues and three original arrangements; editable instruments, envelopes, note sequences and loop metadata |

Couriers have exactly these clips/counts: `idle` 4, `run` 6, `jump_rise` 2, `fall` 2, `land` 2, `slash` 4, `special` 4, `hurt` 2, `dash` 2, `downed` 2, `revive` 2. Boss clips are `idle`, `sweep_anticipation`, `sweep_active`, `sweep_recovery`, `strike_anticipation`, `strike_active`, `strike_recovery`, `charge_anticipation`, `charge_active`, `charge_recovery`, `stagger`, `defeat`. Keep source frames facing right and origins fixed when mirrored. Initial padding is transparent; any agreed extrusion change must be coordinated and validated rather than rescaling a sheet.

The 48 terrain slots comprise four variants each of solid fill/top/bottom/left/right (20), four outer and four inner corners (8), left/middle/right/single pieces for one-way/hazard/bridge (12), horizontal/vertical/cross/knot seams (4), and stone/brass/root/cloth backgrounds (4). The first four IDs are exactly `solid_fill`, `solid_top`, `one_way_middle`, `hazard_middle`. Publish the remaining stable ordered names in the first packet and keep them identical across both themes; the eight slots in the example JSON are illustrative, not the production inventory.

The exact cue names are:

```text
jump land slash hit hurt dash ember_arc spore_bolt
enemy_warning enemy_defeat boss_stagger cross_stitch
anchor_latched bridge_restored checkpoint downed revive loom_restored
```

Music names are `exploration`, `boss`, `ending`. Target exploration 45–90 seconds looping, boss 30–60 seconds looping, ending 15–30 seconds. Synthesize original 44,100Hz 16-bit PCM WAV; short cues are mono, music stereo. Audio records add `sample_rate`, `channels`, `sample_width_bytes`, `sample_frames`, `loop_start`, `loop_end`. Loop offsets are sample frames, with end exclusive; both are `null` for nonlooping audio. Validate format, conservative peaks and seam continuity. Agent 1 owns the single shared mix and deduplicated gameplay emission. Report actual listening separately from waveform/peak checks.

## 5. Fixed room and progression contract

Rooms use `{schema_version,id,name,tiles,spawns,entities,decor}`. `decor` may be empty. Width is **30–90** tiles and height **23–30**; r00's initial tracer is exactly **60×23**. Tile rows are rectangular strings of `#` solid, `=` one-way, `.` empty and `^` hazard. Integer tile coordinates are mandatory; silently truncating fractional coordinates is invalid. The earlier 40-tile minimum in PLAN_PHASE1 is superseded by this contract and the current loader's 30-tile minimum.

`spawns` maps stable entrance IDs to exactly two feet tiles. Actor/NPC placement uses the current `RoomDefinition.feet_position`: `((x+0.5)*16,(y+1)*16)` pixels. Other point locations use tile centres. Rectangles `[x,y,width,height]` use tile units with positive dimensions. Both spawn footprints need safe ground, collider headroom, no hazards and no forced immediate damage; entrance references must resolve explicitly rather than silently falling back to `start`.

Every entity has an allowlisted `type`, a unique `id`, and these type-specific fields:

| Type | Fields |
| --- | --- |
| `diagnostic_mover` | `tile`, `range_tiles`; diagnostic stage only |
| `spoolmite`, `wickwing`, `spoolwarden` | `tile` |
| `exit` | `rect`, `target_room`, `target_entrance`, `requires_all` |
| `checkpoint` | `tile`, `checkpoint_id`, `entrance` |
| `anchor_pair` | `anchors:[{id,tile},{id,tile}]`, `bridge_rect`, `flag` |
| `npc` | `tile`, `character_id:"oru"`, `dialogue_id`, `restored_dialogue_id` |
| `secret` | `tile`, `flag:"lantern_charm"` |
| `loom` | `stations:[{id,tile},{id,tile}]`, `flag:"loom_restored"` |

Use `decor:[{asset_id,frame,position_px,theme,z}]`, where `theme` is `common`, `ember` or `moss`, positions are pixel coordinates and `frame` references the asset's frame table. These records only place art; they add no collision, AI, rewards or triggers. Gameplay-significant geometry exists only in canonical tiles/entity definitions. Both bridge anchors must be reachable before restoration, and the bridge span must not already be solid in base tiles. Either player can occupy either anchor role; the runtime verifies distinct participation.

Keep the examples' fixed profile fields and IDs: `tavi_fixed`/`neri_fixed`, `fixed_tavi_v1`/`fixed_neri_v1`, `ember_arc`/`spore_bolt`, `ember`/`moss`, 5/4 starting hearts and the shared `courier_v1` collider contract. Fixed theme data retains the example palette/visibility fields, expands the required tile slots to 48 and adds `terrain_asset_id` plus `background_asset_ids` (far, middle, near order) referencing manifested assets. Use the example world envelope (`start_room`, `checkpoints`, `rooms`, `connections`, `requires_all`) with `example_only` removed. Coordinate any additional profile/theme/ability field with Agent 1 before either branch depends on it; asset animation never supplies runtime ability tuning.

| Room | Required authored content |
| --- | --- |
| r00 Lantern Rest | Oru, checkpoint A, controls/arrival space, visible dark bridge home and restored state |
| r01 Mossfoot Atrium | Recognisable bell-tree/brass-arch landmark and remembered dash-gated branch |
| r02 Spindle Steps | Forgiving jumps and first distinct-anchor bridge, flag `bridge_spindle` |
| r03 Glasswing Gallery | Both ordinary enemy lessons, space for specials and one optional cosmetic charm pocket |
| r04 Warden's Landing | Checkpoint B, safe rest and boss anticipation; Oru remains at r00 |
| r05 Broken Bell | Spoolwarden arena, readable tells/exposed seam, victory practice strip and shortcut |
| r06 Severed Causeway | Safe dash practice, required dash route and second pair, flag `bridge_causeway` |
| r07 Lantern Loom | Two loom stations, restoration payoff, ending and safe return exit |

Preserve the exact graph in `examples/world_graph.json`: r00↔r01↔r02; r02↔r03 requires `bridge_spindle`; r03↔r04↔r05; boss shortcut r05↔r01 requires `shortcut_bell`; r01↔r06 requires `threadstep`; r06↔r07 requires `bridge_causeway`; r07↔r00 requires `loom_restored`. Boss challenge rewards are `boss_spoolwarden`, `threadstep`, `shortcut_bell`. Checkpoint IDs are `checkpoint_a` in r00 and `checkpoint_b` in r04. The charm is inside r03, not a ninth room. Avoid character-exclusive gates and keep all exits compatible with both-living-player rally semantics.

## 6. Dialogue, originality and scene quality

`content/dialogue.json` has `schema_version:1`, `content_version:"phase1-v1"` and `sequences`, an object mapping sequence IDs to ordered arrays of `{speaker,text}` records. Required sequence IDs: `oru_intro`, `oru_return`, `bridge_spindle_complete`, `boss_defeated`, `ending`. Use speakers Tavi, Neri and Oru where appropriate; an empty speaker is permitted for narration/ending text. Agent 1 selects sequences from progression and owns pausing, advancing/skipping and unique rewards. The NPC's normal/restored references point to `oru_intro`/`oru_return`.

Adapt the original STORY_BIBLE lines to concise on-screen dialogue and the font's printable ASCII set. Convert curly apostrophes/quotes and long dashes deliberately; validate every shipped dialogue/UI string against available glyphs. Preserve the immediate objective and ending: restore the Lantern Loom so a stranded district can cross home. The night tide is narrative urgency, not a timed campaign failure.

Build coherent cloth, weathered loom, brass, bell-glass and root motifs from retained editable sources. Use deliberate shapes/material planes and separate foreground/midground/distant compositions. Hazards need common silhouettes/anticipation, not colour alone. Both couriers and enemy tells must remain legible against both themes at native resolution, including downed poses and overlapping combat. Original synthesized audio must remain comfortable under repetition. Broad genre qualities are references; recognizable characters, maps, signatures, melodies and copied UI are not source material.

## 7. Verification commands and required failures

Implement these public CLI forms; `--stage` defaults to `full`:

```sh
python3 tools/generate_assets.py --seed 18427 --stage diagnostic
python3 tools/validate_assets.py --stage diagnostic
python3 tools/validate_content.py --stage diagnostic
python3 tools/generate_assets.py --seed 18427
python3 tools/validate_assets.py
python3 tools/validate_content.py
python3 -m unittest discover -s tools/tests -p 'test_*.py'
python3 tools/check_pack.py
git diff --check
```

Diagnostic validation accepts only the explicit first-drop scope and prints that stage. Full validation requires all eight rooms, the full asset/state/audio/font budgets, both themes, valid references and no diagnostic dependency in shipped content. Every failure returns a nonzero exit code and identifies the file/ID/field. Validators are read-only; generation writes only owned generated outputs and manifest.

Meaningful negative fixtures must cover missing/duplicate IDs, invalid schema versions, unsafe paths, wrong hashes/dimensions, out-of-bounds or overlapping frames, bad state/frame/tick lists, absent glyphs/cues, malformed audio/loops, unequal theme edge masks, fractional/out-of-bounds room coordinates, unsafe spawn pairs, broken exit/entrance references, invalid anchor pairs/bridge spans and missing/wrong progression requirements. Keep Python and Agent 1's runtime validation aligned through shared data-only fixtures. Do not equate graph reachability with physical traversal.

Agent 1 runs Godot import and the real-engine scenario runner against each merged drop. Their public runner is `godot --headless --path . --script tests/run_tests.gd`, optionally `-- --filter <substring>`. Supply minimal reproductions/data for runtime failures; keep all `.gd` changes with Agent 1. Visible playback, normal-input route completion, audio listening, gamepad checks, human playtests and export/performance evidence are separate gates. Record only what actually happened.

## 8. Every drop's handoff

Send Agent 1: branch and exact commit SHA; owned files changed; stable IDs/contract additions; commands, stages and outcomes; content/asset inventory remaining; capture/audio evidence actually reviewed; runtime integration needed; known limitations and next drop. Keep implementation claims distinct from static validation and real-engine evidence. Human review stays pending until it happens.

The final Agent 2 delivery is a complete reproducible original Phase 1 bundle and truthful evidence, ready for Agent 1's integrated acceptance and packaging. Publishing content commits does not declare the game complete; Agent 1 owns the final MVP gate and publication to `main`.
