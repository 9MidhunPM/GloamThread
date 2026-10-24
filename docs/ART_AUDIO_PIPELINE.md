# Gloamthread: Two Ends — original art and audio pipeline

Version 3.0 · `overhead-v1` production contract · 25 October 2026.

This document defines the production asset contract. [STATUS.md](STATUS.md) and [content evidence](../evidence/content/README.md) record the authored inventory, validation and pending runtime/motion/listening review. Read `DECISIONS.md` before changing budgets.

## 1. What the first version must look like

Create a miniature world of stitched cloth, weathered looms, brass fittings, broken bell glass, and roots returning through masonry. Give every room a landmark and a deliberate light source. The result should feel handmade and inhabited at native pixel resolution.

Tavi and Neri are original couriers with separate silhouettes. Avoid a horned white mask, familiar videogame costumes, copied sword shapes, recognizable enemy designs, traced backgrounds, and borrowed UI arrangements. Broad genre references guide clarity and atmosphere only.

The overhead revision retains two fixed characters and Ember/Moss themes. The previous side-view milestone is preserved separately. New `overhead-v1` assets require matching runtime/content and cannot be dropped into that older campaign. Agents author all source art, animation data, music, glyphs, maps and effects. Runtime image generation remains future work.

## 2. Non-negotiable presentation contract

| Item | Contract |
| --- | --- |
| World tile | 16×16 pixels; decorative objects may span multiple cells |
| Composite logical canvas | 960×360 pixels |
| Each player's view | 480×360 pixels, fixed vertical split |
| Divider | Overlay on the boundary; never resize one view to accommodate it |
| Initial desktop window | 1920×720, 2× integer presentation |
| Character animation cell | 32×48 pixels |
| Character sprite origin | (16, 43), measured from the top-left of every unpadded cell |
| Common body collision | Runtime-owned overhead 12×10 foot rectangle at anchor offset (0, -5); independent of art |
| Sampling | Nearest neighbour; no mipmaps or linear filtering for pixel atlases |
| Scaling | Integer scale with letterboxing; no non-uniform stretching |
| Camera | Smooth simulation target, pixel-aligned displayed position; inspect slow pans for shimmer |
| Animation timing | Frame durations in seconds/ticks, independent of rendering frequency |

The origin remains constant through attacks, rolls, lantern swings and knockback. Cloth, weapons, later wings and glow never enlarge the collider. Four authored facing banks are ordered down, left, right, up; diagonal movement uses a cardinal visual facing. World coordinates and collision are shared between both screens.

Authoring images may be enlarged for inspection, but review every important pose and room at 1×. A silhouette that works only at 8× has failed its actual display target.

## 3. Palette and material language

Use a compact indexed palette as the starting art system. These proposed colours can change together during the art proof; preserve their semantic roles and contrast rather than treating hex codes as sacred.

| Index / role | Ember | Moss |
| --- | --- | --- |
| 0 transparent | Alpha 0 | Alpha 0 |
| 1 deepest recess | `#10141C` | `#10141C` |
| 2 outline | `#293247` | `#293247` |
| 3 shadow stone | `#41465A` | `#41465A` |
| 4 light stone | `#737B83` | `#737B83` |
| 5 thread / bone | `#D5D2B8` | `#D5D2B8` |
| 6 danger accent | `#F07865` | `#F07865` |
| 7 danger highlight | `#FFE0A1` | `#FFE0A1` |
| 8 material deep | `#4A292B` | `#243F38` |
| 9 material middle | `#845044` | `#3E6B51` |
| 10 material light | `#BC7852` | `#73965D` |
| 11 material highlight | `#E3AD6A` | `#BCD184` |
| 12 atmosphere deep | `#30283E` | `#243C48` |
| 13 atmosphere middle | `#644258` | `#3C6570` |
| 14 atmosphere light | `#A26671` | `#6BA49B` |
| 15 rare glow | `#F5CC83` | `#B5E5B4` |

Shared danger accents also need a shape, anticipation pose, or flashing outline; colour alone never identifies a hazard. Backgrounds use lower local contrast than traversable edges and actors. Characters may use their own compact palette while retaining compatible shadow and outline colours.

Cluster pixels deliberately into material planes and readable silhouettes. Avoid uniform random noise, excessive single-pixel highlights, pillow shading, and detailed foreground clutter across jump edges. More noise is not more detail.

## 4. Two appearances, one physical place

Canonical collision, hazards, anchors, exits and entities are authored once. All terrain slots are opaque 16×16 rectangles in both themes; material boundaries are painted inside the tile. Room JSON owns meaning: `#` wall, `.` floor, `~` water/rift, `^` walkable hazard, `=` walkable bridge. A root bridge and brass bridge occupy identical physical space.

Theme layers may vary stone surface patterns, background silhouettes, leaves or sparks, harmless hanging cloth, and ambient light colours. Their nodes contain no collision bodies, AI, pickups, damage areas, triggers, or save flags.

Keep silhouettes of dangerous surfaces, active boss attacks, interaction markers, and both player characters readable in both themes. Do not theme an actual fire hazard into an apparently safe pool. Shared actor identities remain recognizable when either player looks across the divider.

Share terrain topology and clear material grammar. Bridge restoration removes its named water blocker and adds both skins once; art does not create another floor collider. Render filtering cannot affect simulation or duplicate sound events.

## 5. Exact initial asset budget

| Family | Required Phase 1 output | Notes |
| --- | --- | --- |
| Couriers | Tavi and Neri, 128 frames each | Four authored facings, 32 frames per bank |
| Oru | 8 frames, 32×48 cells | Idle 4, talk 2, restoration acknowledgement 2; same (16, 43) origin, 288×52 padded atlas |
| Spoolmite | 16 frames, 32×32 cells | Readable charge silhouette |
| Wickwing | 14 frames, 32×32 cells | Two unused atlas slots remain transparent |
| Spoolwarden | 32 radial overhead frames, 64×64 cells | Four-strut loom, exposed stitch, distinct tells; directed attacks separate |
| Canonical terrain | 48 logical tile slots | Shape/edge contract shared by both themes |
| Terrain variants | Ember and Moss treatment of all 48 slots | 96 rendered tile images, not 96 collision definitions |
| Props | 16 logical props | Include anchor, loom, bell, lantern, sign, checkpoint and dressing |
| Backgrounds | 3 parallax layers per theme | Six original source images; reuse with room composition changes |
| Effects | 8 short sequences | Slash, Ember Arc, spore impact, dash, hit, weave, revive, restoration |
| UI icons | 20 original 16×16 icons | Hearts, prompts, map marks, abilities, partner state |
| Font | Original 5×7 bitmap glyph source | Printable ASCII plus only explicitly needed extra glyphs |
| Music | 4 original arrangements | Exploration, boss, boss final phase, restored ending |
| Sound | 19 distinct semantic cues | Includes grounded roll and retained legacy jump |

The generated bundle contains 49 manifested original assets. Structural validation establishes inventory/file contracts; engine playback and human review remain separate. Reuse coherent motifs; add an asset only when a scene needs it.

### Courier animation rows

Each facing bank uses these states in order, with keys such as `slash_up`. Four banks contain 128 frames and 36 clips total. Animation mirrors runtime timing; it never defines damage timing.

| State | Frames | Per-frame physics ticks | Loop |
| --- | --- | --- | --- |
| idle | 4 | 10, 10, 10, 10 | yes |
| run | 6 | 5, 5, 5, 5, 5, 5 | yes |
| slash | 5 | 3, 3, 3, 3, 6 | no |
| special | 5 | 4, 4, 3, 4, 7 | no |
| roll | 4 | 3, 3, 3, 3 | no |
| dash | 2 | 6, 6 | no |
| hurt | 2 | 5, 7 | no |
| downed | 2 | 18, 18 | yes |
| revive | 2 | 6, 10 | no |

Pack 8 columns × 16 rows. Padded cells occupy 36×52 pixels; the atlas is 288×832. Frame rectangles exclude padding. Frames stay within their facing/state bank; intentional repeats inside that bank are permitted. Slash active poses start at tick 6 and special release at tick 8. Never resample a sheet to repair spacing.

Spoolmite's 16 frames: idle 2, walk 4, anticipation 2, charge 2, recovery 2, defeat 4. Wickwing's 14: flap 4, anticipation 2, dive 2, recovery 2, defeat 4. Pack both on 8-column atlases with 2-pixel padding.

Spoolwarden's 32 frames: idle 4; anticipation 6, active 6 and recovery 6 across its three attacks; stagger 4; defeat 6. Pack 8×4 padded 64×64 cells into 544×272. Reuse frames intentionally between movements rather than inventing a fourth attack to consume atlas space.

Do not mirror banks to invent missing courier facings. Front/back planes, scarves, arms and spools are authored per direction. Facing latches through attack windup/recovery. Directional effects face +X in source and rotate by quarter turns; centred impacts/restoration remain radial. Store frame order and duration in metadata.

Downed poses must read as recoverable, with a visible partner marker and room for the revive indicator. Attack recovery should return to a stable standing pose. Avoid decorative animation on the same cadence as a threat flash.

### Terrain and prop composition

The ordered terrain inventory has four floor treatments, four wall fills, four wall edges, eight wall corners, four water fills, four water edges, four water corners, four bridges, four seam runes, four background materials and four hazards. Exact IDs/order are frozen in the generator, manifest and validator. Walkability comes from room data. Water must remain distinct from safe floor in both themes.

Allow room-specific arrangements of the same 16 props: rotated broken spindles, layered hanging cloth, intact/broken bell states, background root silhouettes. A room should be identifiable from its landmark and composition without needing a wholly new asset family.

Pack each 48-slot terrain atlas in 8 columns × 6 rows of padded 16×16 cells: 20×20 stride, 160×120 total. The two theme atlases use exactly the same semantic slot ordering. Padding is excluded from source rectangles and physical tile size.

For the first effects budget, use six frames per sequence: 48 frames total. A 32×32 cell suffices for slash, special impacts, dash trail, hit and revive; restoration may use 64×64. Larger effects remain transient visual layers and never determine their own hitboxes. Exact effect rectangles and pivots go in the manifest.

The 20 UI icons can use a 5×4 atlas of padded 16×16 cells, 100×80 overall. Build the original font from 95 printable ASCII characters plus one replacement glyph: 16×6 cells of 6×8 pixels, giving a 96×48 atlas. Each visible glyph occupies at most 5×7 pixels; the remaining row/column supplies spacing. Restrict initial dialogue to this supported character set or explicitly extend it.

Each background layer starts at 480×360 pixels. Layers that scroll horizontally need a deliberately matching seam or a declared finite extent. Design the foreground, midground and distant silhouette as separate original compositions; three copies of one texture at different opacity do not satisfy the parallax art proof.

## 6. Original audio contract

Use Python or equivalent repository-owned synthesis to export PCM WAV: 44.1 kHz, 16-bit; mono short effects, stereo music where useful. Keep note tables, instrument envelopes, oscillator/noise definitions, tempo, and arrangements as editable source. No sampled game sound, downloaded loop, stock soundtrack, or external soundfont.

Build an original keyboard hook with plucked thread, bell, bass and synthesized percussion. Exploration has a buoyant groove with room for warnings. The boss uses a driving 150 BPM pulse, moving harmony, syncopated bass, counterlines, a lighter bridge and reprise. `boss_final` shares the 32-bar grid/hook and adds rhythmic/counterlead intensity. Ending resolves the project motif. References guide broad energy/contrast; no reference melody, transcription, sample or soundfont is used.

Required cues: roll, retained legacy jump, land, slash, confirmed hit, hurt, dash, Ember Arc, Spore Bolt, enemy warning, enemy defeat, boss stagger, Cross-stitch burst, anchor latch, bridge restoration, checkpoint, downed, revive and loom completion. Overhead gameplay emits roll; the legacy cue remains explicit rather than silently reusing a jump sound for it. Semantic cues need recognizable envelopes.

Use short attack/release envelopes to prevent clicks, conservative peaks, and a voice cap. Verify no clipping in the loudest two-player boss moment. Provide independent music/effects controls and a comfortable master level. Essential danger remains visible during muted playback.

One semantic sound event produces one sound in the shared stereo mix. Rendering the event in two viewports must not double its volume. Decide one consistent listener/mixing policy for the shared room; Phase 1 does not need competing per-player music tracks.

Current arrangements are exploration 48 seconds, boss 51.2 seconds, boss final 51.2 seconds and ending 20 seconds. The first three loop; ending does not. Both boss masters retain a 0.27 full-scale peak ceiling; intensity comes from arrangement. Their equal tempo/length permits a runtime switch to preserve musical position. Export loop points and original notes. Smooth envelopes bound endpoint discontinuity; comfort and fatigue still need audible review.

Listen for repeated fatigue as well as first impressions. The jump sound must tolerate many repetitions; the damage warning must cut through music without being painfully louder. A downed cue should draw a partner's attention once, with restrained reminders rather than a continuous alarm.

## 7. Source layout and rebuild contract

The proposed implementation layout is:

- `assets/source/art/`: indexed pixel matrices, palette definitions, original glyphs, animation timing and source illustrations.
- `assets/source/audio/`: note sequences, instruments, synthesis parameters and arrangement data.
- `tools/generate_assets.py`: deterministic conversions and exports from retained source, using explicit seeds for procedural variation.
- `assets/generated/`: game-ready atlases, backgrounds, WAV files and font resources.
- `assets/manifest.json`: stable asset IDs, source/output paths, dimensions, frame metadata, palette/theme, generator version and SHA-256.
- `tools/validate_assets.py`: checks for the contracts below; implemented with the game, not supplied here.

Record dependencies and versions. Engine/tool libraries are permitted; content packs are not. If using an external image model later, retain the selected original output, prompt/reference record, model identifier and post-processing inputs. Rebuilding from the retained image must be reproducible; rerunning a model call need not produce identical pixels.

## 8. Validation gates

### Machine checks to implement

- [ ] Every consumed asset has a stable manifest ID, retained original source and matching output hash.
- [ ] Atlas dimensions, frame counts, frame rectangles and origins match declared contracts.
- [ ] Transparent gutters exist; no frame overlaps an adjacent rectangle.
- [ ] Palette indices are valid; unintended partial alpha is rejected for opaque pixel surfaces.
- [ ] Both themes implement every required terrain slot and preserve its canonical edge mask.
- [ ] No theme node adds collision, AI, triggers or a second simulation actor.
- [ ] Required animations, glyphs, icons and sound event mappings exist.
- [ ] Audio sample format is declared; loop boundaries and peak amplitude are inspected.
- [ ] No asset path depends on a network URL or an absolute developer-machine path.

### Rendered and audible review

- [ ] Tavi and Neri remain distinct while overlapping and during fast attacks.
- [ ] Enemy anticipation is readable on each screen at 1× and at the darkest location.
- [ ] Floor, wall, water, bridge and hazard boundaries read clearly in both themes.
- [ ] Run/attack/downed playback holds its origin; feet do not slide unpredictably.
- [ ] Slow pans do not produce unstable shimmer, filtering or atlas seams.
- [ ] HUD and prompts fit within each 480×360 view without covering attacks.
- [ ] Two-player particles, flashes and sound retain clarity during the boss fight.
- [ ] Reduced-flash and reduced-shake settings preserve useful feedback.
- [ ] At least one continuous human playthrough reviews animation, timing and sound; still images alone do not pass this gate.

Capture evidence with the implementation version and test conditions. If the environment cannot render or play audio, report those gates as unverified. Fix the scene before producing more room art when the style is inconsistent.

## 9. Later generated content

Phase 2 replaces fixed source selection behind the same manifests. First build a drawing-derived character from supported original parts; then test new generated character art; then expand theme generation slot by slot. Keep fixed fallback assets and the complete Phase 1 adventure available.

Generated character frames must pass the same state, origin, silhouette and gameplay-readability checks. Generated environment images must fit predeclared slots and preserve canonical geometry. A pretty portrait or a large composite sheet is not evidence of working animation or a valid tileset.
