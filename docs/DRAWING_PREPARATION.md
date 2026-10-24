# Drawing-based characters and textures — preparation brief

Draft for the next phase · 25 October 2026 · **No drawing importer or generation service is implemented by this brief.**

The player goal is to recognise something they drew in a readable character and a personal view of the kingdom. Begin with a small preparation experiment, while Agent 1 finishes the Phase 1 release candidate. The fixed offline game stays available. This brief makes the first steps in the [generation roadmap](GENERATION_ROADMAP.md) concrete; it does not replace the roadmap's playtest prerequisite.

## Current seams and missing work

Inspection baseline: `b96ad0e86724db62a7d6f22ba26b01b75dcaee1c`. All 79 existing Python tests pass on that source. This is structural/tool evidence, not acceptance of new characters or player drawings.

| Already present | Boundary still to implement later |
| --- | --- |
| Fixed Tavi/Neri profiles resolve original sprite assets and approved specials | The [content catalog](../scripts/presentation/content_catalog.gd) and [offline validator](../tools/validate_content.py) require the two fixed identities. They do not accept arbitrary generated profiles. |
| Original couriers use 32 frames, eleven animation states, 32×48 cells, origin `[16,43]`, and a 288×208 padded atlas | New appearances must preserve this playback contract and pass visual review. A portrait or grid-shaped image does not establish usable animation. |
| Asset checks cover hashes, source retention, frame visibility, alpha, padding, state coverage and canonical terrain masks | [Runtime resource loading](../scripts/presentation/asset_catalog.gd) is tailored to packaged resources; a validated user-bundle install/cache and equivalent admission checks do not exist. |
| Ember/Moss terrain and backgrounds render separately over shared room geometry | [ThemePresenter](../scripts/presentation/theme_presenter.gd) constructs fixed asset names. Merely adding a theme manifest does not install a new theme. |
| Threadstep and permanent restorations belong to the team | [Team saves](../scripts/session/team_progress.gd) accept only the two distinct fixed profile IDs. Bundle identity, missing-bundle recovery and duplicate future builds require explicit compatibility work. |

Keep strict fixed-content checks. Add a separately versioned, bounded preparation contract when its first consumer is built; do not loosen Phase 1 validation to make a future example load.

## First experiment: preserve features before generating animation

Use six project-authored sketch inputs initially: a broad stone figure, a small winged figure, a plant/lantern figure, an asymmetric creature, a monochrome outline, and a busy drawing with an unclear foreground. These are proposed test cases, not existing user drawings or completed tests. Obtain real player sketches for the later recognition test; synthetic examples cannot supply that evidence.

The [research note](research/drawing_pipeline.md) details the subsequent twelve-drawing pilot, four held-out cases, proposed recognition/readability thresholds and official Pillow/Godot guidance. These are trial gates to set before collecting results, not measured accuracy or arbitrary-drawing guarantees. Current recipes draw two particular couriers; a reusable parts assembler is also future work.

For each input, the player identifies up to three features they care about, such as a leaf crown, one large eye or a blue scarf. Keep these explicit choices alongside the interpretation. Let the player correct an uncertain guess before artwork is built.

The first candidate uses an existing gameplay preset and project-authored visual parts. Change silhouette details, colours and supported accessories. Keep movement, hurtboxes, collision, attack timing and required traversal identical to the selected tested preset. Start with Tavi/Neri's existing gameplay choices; sturdy/agile/balanced variants remain later work until route tests establish their budgets. Do not infer flight, invulnerability or a new attack from a drawing.

Show the original input beside a portrait and an actual-size animated preview. Include both Ember and Moss backgrounds. Label a template-built sprite accurately and let the player revise the interpretation, retry, or use a fixed character. A beautiful portrait cannot compensate for an unreadable 32×48 sprite.

Record these outcomes without inventing results:

| Question | Required observation before advancing |
| --- | --- |
| Does the adaptation retain the drawing? | The artist recognises the selected features and accepts or corrects each one; record their words and rejected candidates. |
| Does it animate coherently? | Idle, run, rise, fall, land, slash, special, hurt, dash, downed and revive play without unintended foot/pivot jumps or clipped accessories. |
| Can both players read it? | Inspect both characters at 1× against both themes, during attacks and down/revive, using shape as well as colour. |
| Does it remain playable? | The accepted pairing completes the ordinary route; original gameplay tests stay green. Test duplicate presets separately before allowing them. |
| Can preparation fail safely? | Rejected/cancelled work leaves the last accepted candidate intact, and fixed characters remain startable. |

## Proposed preparation records

Keep these as distinct records rather than one model-produced game manifest:

| Record | Contents | What it can decide |
| --- | --- | --- |
| Input reference | Local input ID, original/normalised hashes, decoding/normalisation version and player-selected features | Which retained drawing is being adapted |
| Trait proposal | Bounded palette/motif/accessory suggestions, evidence notes and unresolved questions | Suggestions to preview and correct |
| Approved appearance | Explicit player acceptance, selected supported parts/style and a reference to an existing gameplay preset | How the character should look |
| Candidate assets | Retained originals, conversion version, output hashes, animation metadata and validation findings | A proposed presentation bundle |
| Accepted bundle | Complete compatible asset inventory, immutable bundle ID/version/hash and acceptance status | Which local presentation may be launched |

The provider, if added later, supplies a trait/art proposal. Game-owned code selects stats and allowlisted abilities. Reject unknown or executable fields at admission, resolve every asset locally, and validate the entire bundle before activation. Keep original inputs local by default; any later external analysis needs a clear indication of which image leaves the device. Do not commit players' private drawings as test fixtures.

Use bounded local input preparation before any interpretation. The research note proposes single-frame PNG/JPEG, trial byte/pixel/dimension limits, full decode after verification, EXIF orientation handling and explicit colour-profile conversion. Preserve the whole drawing and alpha; do not treat automatic background removal or shrinking a photograph as character construction. Normalisation and target-size pixel assembly are separate operations.

An accepted bundle is immutable. A retry creates a candidate with a new identity; it cannot mutate the currently accepted bundle. Cancellation or validation failure cannot replace that bundle. Cache retained accepted pixels and conversion inputs, rather than assuming that repeating a prompt reproduces an image. No gameplay, save, room change or revival waits for preparation or a provider.

## Texture experiment: constrained surfaces, then complete themes

First establish drawing-derived palette and mood over existing art. Then try one background composition and one decorative prop. Only after those read well should generated material fill the existing terrain masks.

Terrain has a finite inventory: the exact 48 ordered slots in [themes.json](../content/themes.json). Tiles are 16×16. Both themes use a 160×120 atlas with 2px transparent gutters and 4px separation. The alpha silhouette for each physical slot is fixed in [the asset validator](../tools/validate_assets.py); material colour cannot add a landing edge or hide a hole. Background layers are currently three finite 480×360 images per view.

Build a family from one approved style reference. Do not request 48 unrelated pictures and assume they form a coherent tileset. Test neighbouring edges/corners, repeated runs, stairs, one-way platforms, restored bridges and hazard boundaries in one existing room. Check the two views side by side while both characters move. Common danger contours, telegraphs, interaction glyphs and actor identities keep their established meaning.

Promote only a complete validated theme. A failed tile does not silently install a partially changed environment. During retries, keep the previous accepted theme or explicitly offer Ember/Moss. Generated imagery never supplies room geometry, collision, progression or gameplay scripts.

An earlier material-board experiment may change only whitelisted interiors in a few slots while keeping a protected contour band, common cue colours and canonical alpha untouched. It stays a preview specimen, with every other slot retained; it is not an accepted partial theme. Equal alpha alone cannot prove colour contrast makes an edge readable.

## Ordered follow-up work

1. Complete the fixed game's remaining acceptance, especially fresh-pair playtests. Retain this brief and read-only seam audit separately from its release source.
2. Define the first bounded appearance/preparation schema and a small local specimen corpus, with input/retention limits and no provider dependency. Test malformed data and acceptance/cancellation without changing campaign saves.
3. Build an offline preview-only experiment for supported parts on existing gameplay presets. Evaluate recognition and animation at native size before wiring new profiles into join/save.
4. Add reviewed bundle admission, resource resolution and missing-bundle fallback. Extend profile/theme consumers and save compatibility together. Test all allowed pairings, including duplicates, on the complete route.
5. Introduce an optional analysis adapter only after the offline flow works. Verify current official provider capabilities, privacy terms, prices and limits at that point; no provider is selected here.
6. Try retained generated portrait/parts, then constrained poses, then texture families. Measure attempts, rejection reasons, preparation time and actual cost before setting promises or expanding the inventory.

The next implementation slice is the offline specimen/preview experiment. Full animation generation, uploads, a backend, new mechanics and generated levels are outside this preparation change.

The [read-only boundary audit](../evidence/content/drawing-boundary.md) records exact baseline paths, small malformed-data probes and the reproduced missing-font startup diagnostic. Agent 1 subsequently reported a focused guard and regression scenario for that diagnostic; final release verification belongs to Agent 1. The validated fixed pack passed its baseline checks. Offline/runtime admission parity, manifest-driven theme lookup and compatible bundle saves remain explicit future tasks.
