# Implementation status

Current product: solo/two-player scrolling wave fighter with dynamic split screen. The approved [world contract](SCROLLING_WORLD_PLAN.md) extends the [wave specification](WAVE_FIGHTER_SPEC.md). Earlier campaign and overhead work remains historical.

## Implemented

The seeded world begins four screens wide and expands after waves 5/10/15 to sixteen screens (10,240×720 logical pixels). Existing terrain, loot IDs and player positions remain intact. Connected raised routes and shallow caves use the same shared physics world. Four parallax layers, twenty-four authored props, four landmark families, cave texture/support details and visible frontier signs ship with editable sources.

Nearby players share a 640×360 view; separated players receive 320×360 views at the same 3× pixel scale. Downed bodies remain camera targets. There is one simulation and audio mix. Personal shops can close independently for free exploration and reopen with owned interact; all active players Ready. Unique caches pay both active players; plants heal their collector. Existing twenty waves, bosses, six builds, run resets and endless remain.

Spawns use reachable nearby anchors and 96 pixel player clearance. Unseen pursuit preserves enemy identity/HP/status/reward ownership and cancels on visibility/death. Ground foes navigate connected platforms; genuine flying enemies cross open planks while solid terrain still blocks them, using reachable anchors around cave ceilings. Generated character appearance never grants flight.

## Previously verified v0.4 counterplay baseline

Chargers now commit to a marked lane and expose miss/wall recovery; heavies use directional guards with rear/control/late-swing counters; shooters announce locked three-shot bursts; flyers mark committed dives and retreat. Contact direction follows actual melee/projectile/chain origins. A moving target crossing behind terrain cannot cancel/rewrite the flyer's announced attack. [Mechanics](ENEMY_MECHANICS.md).

The v0.4 source checkpoint passed **21 arena scenarios, 173 creator assertions and 187 Python tests**. Ordinary-input solo 20 (36,998 ticks) and co-op 25 (50,023 ticks) both pass with no route/engine errors. Four actual native 1080p snapshots were inspected with matching source hashes and no errors. [Current evidence](../evidence/enemy-counterplay/README.md). Physical/human balance and a new performance claim remain unverified. The [v0.4 prerelease](https://github.com/9MidhunPM/GloamThread/releases/tag/v0.4.0-counterplay) packages `a65bf14a2a2676a290aab7505bf2cca5fcf4fede`; its official 25-wave export passes offline in 50,487 ticks, and its normal package boots offline. All 30 archive entries/payload hashes match.

## Verified v0.3 baseline

Godot 4.7.2 import, **19 arena scenarios**, **162 creator assertions**, **186 Python tests** and all world/content/scenery validators pass. These include real Fighter/Chaser/Flyer terrain traversal, multi-seed graph/identity checks, strict media admission, both-view state ownership, independent shops/shared pause, exact loot and pursuit lifecycle regressions.

Ordinary-input automated routes pass without actor/currency/progression overrides: solo 20 waves in 37,872 ticks and co-op 25 including endless in 49,092 ticks. Both reach all four regions/landmarks, collect 15 loot items and complete every planned exploration leg. Furthest observed x exceeds 10,000; co-op records 98 split/merge changes with no engine errors. These are bots, not human playtests.

Actual native 1920×1080 captures cover merged landmark, split main/cave, final frontier, independent shopping and dense split combat. A ten-second controlled 32 enemy/77 projectile offscreen fixture measured median 10.976 ms and p95 24.522 ms frame intervals. It is not physical scanout FPS or a 60 FPS guarantee. [Commands, hashes and limits](../evidence/scrolling-world/README.md). The official QA export at `26c56b48abe4a7154e2546f86f4659f3d18b24aa` completes 25 waves offline outside the checkout (52,184 ticks, no errors), reaching all four regions/landmarks and 15 loot. The normal package boots offline and its actual native title was inspected. All 30 archive entries and payload hashes pass. [Published prerelease](https://github.com/9MidhunPM/GloamThread/releases/tag/v0.3.0-world).

## Creator recovery and accounting

The user removed local total/per-character dollar caps through the parallel Agent 2 session. Legacy settings no longer block generation. `budget.limits_enabled=false` distinguishes numeric request history/estimates from null limits and remaining amounts; provider billing is not inferred from these records. Explicit Analyse/Generate, cache validation, cancellation, uncertain attempt history and no automatic retries remain.

The Save/convert loop was reproduced: a click without dragging replaced a crop with an empty 4×4 rectangle, bounds-only validation admitted it, and the reopened editor obscured the worker error. Pixel/opacity preflight now prevents the doomed conversion, selects the invalid crop and preserves it in the editor; clicks preserve existing crops and failures remain visible. Successful conversion explains the separate acceptance action. Acceptance selects the installed fighter in the lobby rather than silently returning to the title.

The creator suite passes 173 assertions. The real retained drawing completed native conversion, preview, acceptance, lobby selection and entry into combat with networking disabled and unchanged accounting. The recovered latest fighter is installed in the private local library, with a complete editable draft preserved; no additional image request was made. Its drawing/generated art is absent from Git and packages. [Recovery evidence](../evidence/creator-recovery/README.md).

## Remaining acceptance

Physical controllers/hotplug, keyboard rollover, audio listening, fresh-human balance/enjoyment/clear time and other hardware/distributions remain unverified. No organizer submission has been made. See [submission record](../SUBMISSION.md) and **Devin Hack Kochi** [event guidance](../RULES.md).

## Latest source: Story Mode

The arena title now offers **STORY MODE (2 PLAYERS)** for the retained Tavi/Neri eight-room campaign. Story title offers **Back to arena**; story pause offers **Save and return to arena**. Each mode restores its logical resolution; shared inputs/audio persist while scene replacement frees the previous world. Existing save/settings paths are preserved. Tests/import/build were skipped at user request; current source must be restarted, and the v0.4 package predates this wiring.

## Latest source: name-led generation

An explicit Name is now sent before analysis and preserved exactly. Names and weapon descriptions take priority in fresh image prompts, including a sword attached to the front hand and the complete master. Sword archetypes suggest Stone melee instead of Nature shooting, while manual ability choices remain within the compatible attack category. New identity context is cache-bound; old paid artwork remains recoverable and accepted fighters are preserved. Tests, import/build and live image calls were skipped as requested; new-output quality has not been verified. Restart the source game to use this change.

## Latest source: illustrated master and attack discipline

New authoring jobs use art_mode=illustrated-master-v1: one full detailed transparent character, then its environment, using the same two image requests. Its complete design becomes the actual atlas/portrait with 32 authored whole-body cutout poses; original full-resolution input, masks, pivot and pose recipe are retained. Older limb-based jobs remain compatible. A fixed-name/hash-validated transparent PNG can replace a retained draft’s sprite through **Use detailed character cutout PNG**.

The detailed wizard shown by the user was extracted through the built-in image tool, converted locally and accepted into the private library. Actual native preview, all atlas poses and in-game appearance were inspected. Lobby/session/fighter resolve its old Ember metadata to Frost; the request ledger remained unchanged and no user-API-key requests were sent. The built-in cutout edit is separate from those API-key records. Drawings, generated art and native captures remain private; only sanitized metadata is retained publicly.

Shared identity rules now constrain creator/lobby/session/fighter consistently: magic identities use projectile kits, physical weapon identities use melee kits. Existing accepted files are not rewritten. Broad tests/builds were skipped as requested; new generation quality beyond the reviewed cutout and whole-game balance remain unverified.

## Final review integration

All fetched local/origin feature tips are included by ancestry after merging the final-review, sideview prompt and historical overhead heads. The overhead merge retains the current 2D tree because its older session/HUD APIs conflict with the restored product; its history remains accessible. The illustrated implementation was merged at `27eee9e`; subsequent integration retains the same active runtime with expanded physical-role keywords. [Review gallery](FINAL_REVIEW.md) links actual public screenshots and precise evidence boundaries. The v0.4 executable remains older than current source.
