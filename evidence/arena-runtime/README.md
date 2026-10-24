# Arena runtime evidence

Recorded 2026-10-25T03:19:21+05:30, Godot4.7.2 standard on Arch Linux. These observations concern the new wave game.

## Ordinary-input routes

Run `godot --headless --fixed-fps 60 --path . --script tools/arena_playthrough.gd -- --players 1 --waves 20 --fighter 0 --output /tmp/arena-route.json`; use fighter1for Nature and players2/waves25for co-op endless. Reports retain source hashes, actual purchases, per-wave state and limitations. The state-aware bot reads combat cues and emits owned keyboard snapshots; it uses production App/lobby and real shop transactions. It never writes position, health, damage, currency or progression. This is automated acceptance, not a human playtest or physical-device test.

- Ember solo:20waves/victory,24,633physics ticks,336combat seconds,454kills.
- Nature solo:20waves/victory,38,018ticks,559combat seconds,454kills.
- Ember+Nature co-op:25waves, actual victory/endless transition and recurringboss,32,497ticks,449combat seconds,759kills.
- All three: no downs or engine errors. Shops were automated rapidly, so measured duration does not establish human10–15minute pacing or difficulty.

## Native rendering

`tools/arena_native_qa.gd` ran a real Wayland/OpenGL Compatibility window on an agent workspace with1920×1080root and640×360world, Mesa Intel Graphics(ARL), no fixed FPS. Its explicit debug fixture manually spawned/replenished32ordinary enemies with owned attacks; observed55projectiles. It is separate from the ordinary-input routes. Initial10second profile: median frame8.647ms,p9514.446ms. Raw process/physics metrics include engine sampling and capture effects; do not infer whole-game hardware guarantees from one short fixture.

Actual title/lobby/creator/crowd/shop render targets were inspected. Shop text overflow/Ready contrast and unsupported font punctuation were found and corrected; refreshed captures follow. No fabricated captures or timings.

Physical controllers, keyboard rollover, music listening, fresh two-human balance/enjoyment and exported offline/native acceptance remain separate gates.

## Final source and export checks

After the targeted redraw/sweep/HUD optimizations, ordinary-input Ember solo20 completed in25,059ticks and co-op25 in34,123ticks, both without downs or engine errors. Final reports retain matching runtime source hashes.

The official Linux QA export also completed25waves in a user/network namespace with no network interfaces, no game-state overrides and no engine errors (34,880ticks). This uses the same gameplay/content with the `arena_qa` observation entry point. The ordinary Linux package separately boots outside the source checkout in that network namespace; helper inventory/status/local-bake checks are separate from executable gameplay.

Refreshed native rendering uses explicit offscreen OpenGL draws on an agent workspace, not physical scanout FPS. A10second32enemy/67projectile fixture measured median6.616ms,p9513.253ms,p9915.588ms,max17.567ms; physics/processp95were10.412/9.774ms. The earlier same forced-draw fixture was17.442msp95. CPU redraw/allocation changes plus lower HUD update frequency contributed; this is a short combined-change observation, not a controlled hardware or human performance guarantee. Raw profiles and actual native captures are retained.


## Reviewed generated starter and cached recovery

The final generated-default solo source route (`ordinary-generated-solo.json`) clears twenty waves in 24,084 ticks, 326 combat seconds and 454 kills without downs or engine errors. It records the selected generated manifest and runtime source hashes. `ordinary-generated-duo.json` is an earlier generated-default co-op twenty-five-wave route (32,584 ticks); the later layering/effect changes are render-only, and its stored source hashes identify that distinction.

`native-generated/` contains the actual shipping-source title/lobby/creator/shop/crowd captures plus distinct special/cue contact sheets. The controlled ten-second fixture reached 32 enemies/67 projectiles: median 6.891 ms, p95 11.779 ms, p99 14.486 ms, maximum 17.406 ms, physics/process p95 10.465/7.323 ms. Same native Wayland/Mesa conditions and explicit offscreen-draw limitations apply. No scanout-FPS or human-play claim.

`real-forge/` records the real retained image pair passing through the native crop editor, actual Python local conversion, animation preview and validated acceptance. It ran with `unshare --user --map-root-user --net`; the budget ledger was unchanged and no requests occurred. The source-only harness is `tools/forge_native_recovery.gd`, with `--job` pointing to the retained local job, `--layout evidence/arena-content/reviewed_fox_source_layout.json` and `--output` to a temporary directory. Private live jobs are intentionally absent from Git; sanitized sources and recipes remain under `assets/arena/source/generated_kiln_fox/`.

`generated-capture-context.json` retains capture/source hashes and conditions; `final-checks.json` records final import/suite summaries (12 arena, 154 creator, 173 Python). All visuals are actual captures. Complete ordinary-input export evidence is recorded separately for the final package revision.
