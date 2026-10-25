# Implementation status

Current product: solo/two-player scrolling wave fighter with dynamic split screen. The approved [world contract](SCROLLING_WORLD_PLAN.md) extends the [wave specification](WAVE_FIGHTER_SPEC.md). Earlier campaign and overhead work remains historical.

## Implemented

The seeded world begins four screens wide and expands after waves 5/10/15 to sixteen screens (10,240×720 logical pixels). Existing terrain, loot IDs and player positions remain intact. Connected raised routes and shallow caves use the same shared physics world. Four parallax layers, twenty-four authored props, four landmark families, cave texture/support details and visible frontier signs ship with editable sources.

Nearby players share a 640×360 view; separated players receive 320×360 views at the same 3× pixel scale. Downed bodies remain camera targets. There is one simulation and audio mix. Personal shops can close independently for free exploration and reopen with owned interact; all active players Ready. Unique caches pay both active players; plants heal their collector. Existing twenty waves, bosses, six builds, run resets and endless remain.

Spawns use reachable nearby anchors and 96 pixel player clearance. Unseen pursuit preserves enemy identity/HP/status/reward ownership and cancels on visibility/death. Ground foes navigate connected platforms; genuine flying enemies cross open planks while solid terrain still blocks them, using reachable anchors around cave ceilings. Generated character appearance never grants flight.

## Verified source

Godot 4.7.2 import, **19 arena scenarios**, **162 creator assertions**, **186 Python tests** and all world/content/scenery validators pass. These include real Fighter/Chaser/Flyer terrain traversal, multi-seed graph/identity checks, strict media admission, both-view state ownership, independent shops/shared pause, exact loot and pursuit lifecycle regressions.

Ordinary-input automated routes pass without actor/currency/progression overrides: solo 20 waves in 37,872 ticks and co-op 25 including endless in 49,092 ticks. Both reach all four regions/landmarks, collect 15 loot items and complete every planned exploration leg. Furthest observed x exceeds 10,000; co-op records 98 split/merge changes with no engine errors. These are bots, not human playtests.

Actual native 1920×1080 captures cover merged landmark, split main/cave, final frontier, independent shopping and dense split combat. A ten-second controlled 32 enemy/77 projectile offscreen fixture measured median 10.976 ms and p95 24.522 ms frame intervals. It is not physical scanout FPS or a 60 FPS guarantee. [Commands, hashes and limits](../evidence/scrolling-world/README.md). The official QA export at `26c56b48abe4a7154e2546f86f4659f3d18b24aa` completes 25 waves offline outside the checkout (52,184 ticks, no errors), reaching all four regions/landmarks and 15 loot. The normal package boots offline and its actual native title was inspected. All 30 archive entries and payload hashes pass. [Published prerelease](https://github.com/9MidhunPM/GloamThread/releases/tag/v0.3.0-world).

## Generation budget and recovered drawing

The selected `FORGE_TOTAL_BUDGET_USD=2.00` allowance retains the existing history, with $0.50 maximum per character. The UI reports distinct total/job/required amounts. A valid blocked draft resumes without another analysis; malformed caches remain rejected. Mock tests now use isolated temporary storage.

The user's blocked draft produced two real mini images. Its nonconforming board was corrected locally, all 32 poses inspected and the recovered Wizard accepted into the private local fighter library. The real correction/preview/acceptance ran with networking disabled and unchanged ledger. User drawing/raw assets are absent from Git and packages. Current conservative reservation total: $0.55, with $1.45 remaining; this is not actual billing. No automatic retries, ledger resets or extra correction requests occurred. Models remain `gpt-6-luna` and `gpt-image-1-mini`.

## Remaining acceptance

Physical controllers/hotplug, keyboard rollover, audio listening, fresh-human balance/enjoyment/clear time and other hardware/distributions remain unverified. No organizer submission has been made. See [submission record](../SUBMISSION.md) and **Devin Hack Kochi** [event guidance](../RULES.md).
