# Gloamthread: Two Ends — original art and audio pipeline

Version 2.0 · Phase 1 production contract · 24 October 2026.

This document specifies assets to author. No Godot import, sprite set, audio export, generator, or visual review has been completed by creating this planning pack. Read `DECISIONS.md` before changing budgets.

## 1. What the first version must look like

Create a miniature world of stitched cloth, weathered looms, brass fittings, broken bell glass, and roots returning through masonry. Give every room a landmark and a deliberate light source. The result should feel handmade and inhabited at native pixel resolution.

Tavi and Neri are original couriers with separate silhouettes. Avoid a horned white mask, familiar videogame costumes, copied sword shapes, recognizable enemy designs, traced backgrounds, and borrowed UI arrangements. Broad genre references guide clarity and atmosphere only.

Phase 1 contains two fixed, authored characters and Ember/Moss visual themes. Agents author all source art, animation data, music, glyphs, maps, and effects. Runtime image generation belongs to Phase 2; it cannot delay or replace this first asset pipeline.

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
| Common body collision | Proposed 12×24-pixel body, bottom centre at the actor origin; test before locking geometry |
| Sampling | Nearest neighbour; no mipmaps or linear filtering for pixel atlases |
| Scaling | Integer scale with letterboxing; no non-uniform stretching |
| Camera | Smooth simulation target, pixel-aligned displayed position; inspect slow pans for shimmer |
| Animation timing | Frame durations in seconds/ticks, independent of rendering frequency |

The visual origin remains constant through attacks, squash, lantern swings, and knockback. Cloth, weapons, wings added later, and glow never enlarge the collider. World coordinates and collision are shared between both screens.

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

Canonical collision, hazards, anchors, exits, and gameplay entities are authored once. Ember/Moss art follows the same walkable edge masks and anchor positions. A root bridge and a brass bridge occupy identical physical space.

Theme layers may vary stone surface patterns, background silhouettes, leaves or sparks, harmless hanging cloth, and ambient light colours. Their nodes contain no collision bodies, AI, pickups, damage areas, triggers, or save flags.

Keep silhouettes of dangerous surfaces, active boss attacks, interaction markers, and both player characters readable in both themes. Do not theme an actual fire hazard into an apparently safe pool. Shared actor identities remain recognizable when either player looks across the divider.

For Phase 1, share the terrain topology and most tile silhouettes. Prioritize palette/material treatment and two background sets over making two unrelated tilesets. Render-specific layer filtering belongs to presentation; it cannot affect simulation or duplicate sound events.

## 5. Exact initial asset budget

| Family | Required Phase 1 output | Notes |
| --- | --- | --- |
| Couriers | Tavi and Neri, 32 frames each | Separate silhouettes, shared cell/origin contract |
| Oru | 8 frames, 32×48 cells | Idle 4, talk 2, restoration acknowledgement 2; same (16, 43) origin, 288×52 padded atlas |
| Spoolmite | 16 frames, 32×32 cells | Readable charge silhouette |
| Wickwing | 14 frames, 32×32 cells | Two unused atlas slots remain transparent |
| Spoolwarden | 32 frames, 64×64 cells | Visible shuttle, exposed stitch, distinct tells |
| Canonical terrain | 48 logical tile slots | Shape/edge contract shared by both themes |
| Terrain variants | Ember and Moss treatment of all 48 slots | 96 rendered tile images, not 96 collision definitions |
| Props | 16 logical props | Include anchor, loom, bell, lantern, sign, checkpoint and dressing |
| Backgrounds | 3 parallax layers per theme | Six original source images; reuse with room composition changes |
| Effects | 8 short sequences | Slash, Ember Arc, spore impact, dash, hit, weave, revive, restoration |
| UI icons | 20 original 16×16 icons | Hearts, prompts, map marks, abilities, partner state |
| Font | Original 5×7 bitmap glyph source | Printable ASCII plus only explicitly needed extra glyphs |
| Music | 3 original arrangements | Exploration, boss, restored ending |
| Sound | 18 distinct semantic cues | Cue inventory below |

These are scoped production targets, not existing files or proof of artistic quality. Reuse coherent material motifs; add an asset only when an actual slice scene needs it.

### Courier animation rows

Each character uses exactly 32 initial frames: idle 4, run 6, jump rise 2, fall 2, land 2, slash 4, special 4, hurt 2, dash 2, downed 2, revive 2. Interaction may reuse a deliberate idle/reach pose. Give the attack its own visible weapon arc; a sprite animation does not define damage timing.

Pack 8 columns × 4 rows. With 2 pixels of padding on each side, each cell occupies 36×52 atlas pixels; the atlas is 288×208. Actual frame rectangles exclude padding. Start padding transparent and test edges in-engine; if extrusion is needed, document it consistently. Never resample a finished sheet to repair incorrect spacing.

Spoolmite's 16 frames: idle 2, walk 4, anticipation 2, charge 2, recovery 2, defeat 4. Wickwing's 14: flap 4, anticipation 2, dive 2, recovery 2, defeat 4. Pack both on 8-column atlases with 2-pixel padding.

Spoolwarden's 32 frames: idle 4; anticipation 6, active 6 and recovery 6 across its three attacks; stagger 4; defeat 6. Pack 8×4 padded 64×64 cells into 544×272. Reuse frames intentionally between movements rather than inventing a fourth attack to consume atlas space.

Keep the source frames facing right. Mirroring a character also mirrors its lantern and weapon unless those are separate layers; choose one policy and inspect left-facing attacks. Do not change origins to compensate for a mirrored pose. Store each state's frame order and duration in metadata rather than relying on atlas order alone.

Downed poses must read as recoverable, with a visible partner marker and room for the revive indicator. Attack recovery should return to a stable standing pose. Avoid decorative animation on the same cadence as a threat flash.

### Terrain and prop composition

The 48 terrain slots include solid interiors, exposed tops, bottoms, outer corners, inner corners, wall edges, one-way platform segments, and seam material. The implementation agent records exact semantic IDs before drawing. Decorative differences must not change which pixels mark a landing edge.

Allow room-specific arrangements of the same 16 props: rotated broken spindles, layered hanging cloth, intact/broken bell states, background root silhouettes. A room should be identifiable from its landmark and composition without needing a wholly new asset family.

Pack each 48-slot terrain atlas in 8 columns × 6 rows of padded 16×16 cells: 20×20 stride, 160×120 total. The two theme atlases use exactly the same semantic slot ordering. Padding is excluded from source rectangles and physical tile size.

For the first effects budget, use six frames per sequence: 48 frames total. A 32×32 cell suffices for slash, special impacts, dash trail, hit and revive; restoration may use 64×64. Larger effects remain transient visual layers and never determine their own hitboxes. Exact effect rectangles and pivots go in the manifest.

The 20 UI icons can use a 5×4 atlas of padded 16×16 cells, 100×80 overall. Build the original font from 95 printable ASCII characters plus one replacement glyph: 16×6 cells of 6×8 pixels, giving a 96×48 atlas. Each visible glyph occupies at most 5×7 pixels; the remaining row/column supplies spacing. Restrict initial dialogue to this supported character set or explicitly extend it.

Each background layer starts at 480×360 pixels. Layers that scroll horizontally need a deliberately matching seam or a declared finite extent. Design the foreground, midground and distant silhouette as separate original compositions; three copies of one texture at different opacity do not satisfy the parallax art proof.

## 6. Original audio contract

Use Python or equivalent repository-owned synthesis to export PCM WAV: 44.1 kHz, 16-bit; mono short effects, stereo music where useful. Keep note tables, instrument envelopes, oscillator/noise definitions, tempo, and arrangements as editable source. No sampled game sound, downloaded loop, stock soundtrack, or external soundfont.

Build an original restrained motif around a plucked thread, a soft bell partial, and a low warm drone. Exploration leaves space for footsteps and warnings. The boss arrangement changes rhythm and tension; the ending resolves the existing motif. Avoid imitating recognizable melodies.

Required cues: jump, land, slash, confirmed hit, hurt, dash, Ember Arc, Spore Bolt, enemy warning, enemy defeat, boss stagger, Cross-stitch burst, anchor latch, bridge restoration, checkpoint, downed, revive, and loom completion. Some event variants may derive from the same original instrument source; semantic cues still need recognizable envelopes.

Use short attack/release envelopes to prevent clicks, conservative peaks, and a voice cap. Verify no clipping in the loudest two-player boss moment. Provide independent music/effects controls and a comfortable master level. Essential danger remains visible during muted playback.

One semantic sound event produces one sound in the shared stereo mix. Rendering the event in two viewports must not double its volume. Decide one consistent listener/mixing policy for the shared room; Phase 1 does not need competing per-player music tracks.

Keep the three arrangements short enough to finish: an exploration loop of roughly 45–90 seconds, a boss loop of roughly 30–60 seconds and an ending cue of roughly 15–30 seconds. These are authoring budgets, not mandatory timings. Export both the loop points and the original note arrangement; a cut at a nonzero waveform boundary needs a crossfade or envelope treatment.

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
- [ ] Floors, one-way edges and safe landing positions read equally in both themes.
- [ ] Run/attack/downed loops hold their origin; feet do not slide unpredictably.
- [ ] Slow pans do not produce unstable shimmer, filtering or atlas seams.
- [ ] HUD and prompts fit within each 480×360 view without covering attacks.
- [ ] Two-player particles, flashes and sound retain clarity during the boss fight.
- [ ] Reduced-flash and reduced-shake settings preserve useful feedback.
- [ ] At least one continuous human playthrough reviews animation, timing and sound; still images alone do not pass this gate.

Capture evidence with the implementation version and test conditions. If the environment cannot render or play audio, report those gates as unverified. Fix the scene before producing more room art when the style is inconsistent.

## 9. Later generated content

Phase 2 replaces fixed source selection behind the same manifests. First build a drawing-derived character from supported original parts; then test new generated character art; then expand theme generation slot by slot. Keep fixed fallback assets and the complete Phase 1 adventure available.

Generated character frames must pass the same state, origin, silhouette and gameplay-readability checks. Generated environment images must fit predeclared slots and preserve canonical geometry. A pretty portrait or a large composite sheet is not evidence of working animation or a valid tileset.
