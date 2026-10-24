# Gloamthread: Two Ends — character and texture generation roadmap

Version 2.0 · Future Phase 2 plan. No image service, provider integration or generated-character runtime is implemented in this pack.

See the [drawing preparation brief](DRAWING_PREPARATION.md) for the inspected fixed-runtime boundaries, a first recognition/animation experiment and ordered follow-up work. It is future design work, separate from the packaged Phase 1 source.

## 1. Player promise

After the fixed-character adventure works, let each player draw or upload a character before starting. Their image shapes a playable character appearance, a balanced build and their visual interpretation of the shared kingdom.

The promise is a recognisable, stylised adaptation with approved abilities. Do not promise perfect animation of every conceivable drawing, unlimited new mechanics, or a freshly coherent full-world tileset without a validated asset pipeline.

Phase 1 establishes the profile, asset and shared-world concepts for that seam. Its implemented catalogs, theme consumers and saves still require fixed Tavi/Neri and Ember/Moss identities; they are not a generated-bundle importer. Future validated bundles must extend these boundaries together. The base game remains available without a provider.

## 2. Non-negotiable world rules

- One room geometry, collision layout, enemy/boss state, progression graph and shared save.
- A theme changes visual assets, not the meaning or location of platforms, doors, attack warnings or hazards.
- Required traversal unlocks such as Threadstep belong to the team and survive profile changes.
- Character colliders remain fixed. A large horn, tail or wing cannot expand or shrink the player's damage/collision rules invisibly.
- Model responses are data proposals. They cannot add scripts, executable expressions, resource loaders or arbitrary ability IDs.
- Every supported pairing, including duplicate builds, can finish the mandatory route.
- Both players see both characters as the same character identities; an environmental theme must not turn a partner into an unrecognisable enemy.

## 3. Stage B0: validate the contract without live models

Prerequisite: the complete eight-room fixed-character slice passes its gate and is enjoyable in two-person playtests.

Create three hand-authored test profiles that use the existing contract: sturdy, agile and balanced. Give them distinct original appearances assembled from project-authored parts. Load any pair through the same join/preview flow as Tavi/Neri. Verify health HUDs, specials, saves, revive and mandatory traversal without hardcoded character-name branches.

Exit evidence: every approved pair completes the route; a missing visual bundle falls back cleanly; invalid special/stat data is rejected; Phase 1 still works with no new services running. This stage is a compatibility test, not a claim that image generation exists.

## 4. Stage B1: image → bounded profile → constructed avatar

Add drawing and image upload at the preparation screen. A vision-capable analysis provider extracts visible, game-relevant features: dominant palette, broad body shape, plant/stone/cloth motifs, wings/ears/horns and a suggested theme. Offer a short optional player description to clarify an ambiguous sketch.

Map that proposal into an approved profile. Example interpretations are design examples, not provider guarantees:

| Image features | Proposed build | Bounded tradeoff |
| --- | --- | --- |
| Broad stone armour | Sturdy | More hearts, heavier special; movement stays within tested route bounds |
| Small winged creature | Agile | Fewer hearts, mobile special; no unlimited flight |
| Plant/lantern creature | Balanced | Normal hearts, a short-range spore or light special |

For the first public experiment, select existing specials and conservative stat presets. Keep core movement unchanged until route tests cover the broader range. A point budget can later trade health, special strength and cooldown, but it must be defined in code and tested rather than invented by a model per request.

Build the appearance from original templates, palette swaps and supported accessories. Reuse the validated animation state set, cell dimensions and pivots. This is more reliable than requiring a fresh animated sheet before every start.

Show both a portrait and an in-engine idle/run/attack preview alongside hearts, special and theme. Let players choose a different interpretation or use a fixed character. Clearly label template-built output; do not describe it as a faithful regenerated drawing.

Exit evidence: genuinely different test drawings yield visibly different approved profiles; unclear images have a usable correction path; repeated attempts cannot exceed stat limits; invalid input never prevents starting the fixed game.

## 5. Stage B2: generated character artwork

Once the profile flow works, replace selected template visuals with newly generated original character images. Keep all gameplay contracts unchanged.

Start with a single transparent character design or portrait, then convert selected designs into the game's limited palette and frame contract. Preserve the chosen original output and its generation record. Rebuilding the game-ready atlas from that retained image should be reproducible; repeating an external model call is not assumed to return identical pixels.

Animation approaches, in increasing risk:

1. Generated portrait plus a template-built playable sprite carrying its colours/features.
2. Generated body/accessory parts fitted to a constrained original rig or frame template.
3. Generated key poses adapted into the fixed animation set with alignment and continuity review.
4. Fully generated multi-state animation, accepted only after state-by-state validation.

A sheet-looking image is not accepted merely because it contains a grid. Check transparency, cell count, frame ordering, feet/baseline, pivots, silhouette continuity, attack readability and actual playback. Keep the collider unchanged. Four-frame idle animation does not establish that running and attacking are usable.

Bound generation attempts per stage. Preserve a validated candidate while retrying an improved one; never replace it with an unchecked later output. If the character art fails, use the constructed avatar or fixed profile and explain the fallback in the preview screen.

Exit evidence: accepted generated characters can complete the same normal-input route, maintain readable animation against both themes, and survive save/load without needing the provider again.

## 6. Stage B3: generated environmental texture bundles

The long-term goal can include a new image for every **required visual asset slot** in a theme bundle. Define those slots first; “every texture” must be a finite inventory, not an unbounded runtime request.

Keep logical asset IDs independent from files. Example slots include stone interior, exposed edge, corner, one-way platform surface, distant skyline, midground silhouettes, decorative foliage, lantern casing and noninteractive wall trim. Gameplay-critical icons and warning contours retain their tested shape and contrast policy.

Generate in this order:

1. Palette and mood settings over the original fixed art.
2. New background layers and decorative props with low collision ambiguity.
3. New tile interiors constrained by the original solid silhouette masks.
4. Matching edge/corner variants, then the complete required tile family.
5. Additional room/biome bundles after one room passes seam and readability checks.

All variants use the same 16×16 tile grid and approved atlas contract. Generated art cannot decide where terrain exists. Theme assembly must preserve canonical alpha/solid boundaries for collision-significant edges, avoid atlas bleed and use the required slots. A background is allowed to be painterly during preparation but must be converted and reviewed against the game's pixel scale before acceptance.

Generate a coherent family from a retained theme reference rather than independent unrelated images for every tile. Review repetitions, border seams, palette coherence, foreground/background separation, partner visibility and hazard readability. An atlas can be structurally valid and still look bad; visual review remains required.

Exit evidence: two generated bundles show different aesthetics on the identical room, no visual-solid mismatch, no missing slots, and a playable route in each view. A full manifest is accepted atomically; partial generation does not silently substitute broken pieces.

## 7. Preparation architecture

Keep analysis, build selection and art creation as separate jobs:

| Stage | Input | Output | Authority |
| --- | --- | --- | --- |
| Image preparation | Uploaded/drawn image and optional description | Normalised image and local input ID | Size/type/decoding limits enforced locally |
| Feature analysis | Normalised image | Small structured trait proposal | Provider may suggest; schema validates |
| Profile selection | Trait proposal | Approved build/profile | Game rules own stats and allowed abilities |
| Art creation | Approved profile and retained style reference | Candidate original images | No gameplay rules generated here |
| Asset assembly | Candidate images and fixed templates/masks | Game-ready atlas/theme bundle | Deterministic tool conversion |
| Validation/preview | Complete candidate bundle | Accepted bundle or fallback | Validators plus player preview |
| Session launch | Two accepted local bundles | Ordinary offline co-op session | Shared canonical game simulation |

A small Python preparation service can host provider adapters and assembly tools. It is a Phase 2 development/deployment choice, not a Phase 1 dependency. Keep provider keys in the service environment; do not bundle them in the Godot client. Do not lock the game architecture to one model name or an unverified endpoint.

If a decision API is used, its natural role is selecting from approved profiles/traits. Image analysis and image creation remain separate capabilities. Verify the selected provider's current official APIs, input support, pricing and limits when implementing; this plan does not claim a particular product integration is ready.

## 8. Job state, cache and fallback

Preparation has explicit states: input received, analysing, profile ready, creating art, assembling, validating, preview ready, accepted, failed or cancelled. Show actual progress stages; do not display invented remaining seconds.

Cache by input hash, normalisation version, profile rules version, style/template version and generation settings. Store the selected accepted outputs, not just a prompt that might yield different images later. Record bundle ID, schema version, source hashes, accepted asset hashes and fallback status.

Use per-stage timeouts, a bounded retry policy and cancellation. Cancelled jobs must not overwrite an accepted bundle. Cache successful independent stages so an atlas validation failure does not necessarily repeat image analysis. Rate/credit limits and unavailable services lead to a clear fallback rather than an unusable Start button.

Available fallbacks, in order: last accepted compatible bundle → constructed template avatar/theme → original Tavi/Neri and Ember/Moss content. Let players explicitly choose a fallback rather than hiding that generation failed.

Gameplay starts only after both players accept compatible bundles. Once started, no combat, room transition, revival or save action waits on a provider. Save bundle IDs and validated manifests; retain the local assets required to resume. If those assets are later missing, offer a compatible fixed presentation while preserving shared progression.

## 9. Acceptance checks for generated bundles

- Schema version, profile/ability IDs and stat ranges are valid.
- Every required animation state and theme slot resolves to a local file within the bundle.
- Images decode; dimensions, frame bounds, pivots and transparency match the declared contract.
- No required asset depends on an expiring remote URL during gameplay.
- Canonical collision and progression data are unchanged by theme application.
- Hearts, damage cues, enemies and both players remain legible in both views.
- Animation state transitions do not produce position jumps or inconsistent silhouettes.
- Asset provenance includes retained original outputs and conversion inputs.
- Save/load and replay function without rerunning generation.
- Failure, cancellation, missing files, invalid outputs and fallback all have exercised paths.
- Human reviewers compare ordinary gameplay, not only portraits or enlarged still images.

## 10. Scope controls and practical difficulty

The split-screen renderer and bounded profile system are manageable engineering work. Consistent animated character art and coherent new tileset families carry the greatest uncertainty. A successful image generation request is not evidence that either content problem is solved.

Do not add unrestricted ability invention, generated physics, generated level geometry, independent room travel, live mid-fight art requests, 3D reconstruction or online multiplayer to this roadmap's first generation experiment.

Budget generation with measured candidate counts, provider costs, preparation times, rejection reasons and accepted-bundle quality. Set limits after a small representative test set; do not promise a precise cost or latency before measuring it.

The go/no-go question is: **do players recognise their drawing in a fun, readable character and a coherent view of the same world?** If not, improve the constrained pipeline before expanding the asset inventory or map.
