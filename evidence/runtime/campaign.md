# Campaign and movement evidence

Recorded 2026-10-25T00:02:04+05:30. Godot 4.7.2 standard, Linux, 60 Hz shared physics. The scenario uses the production AppController, New journey/join/Start intent handlers, owned keyboard-left/right command snapshots and the actual dialogue Skip intent. Gameplay has no actor repositioning, direct damage, forced flags or direct room-load calls. It is an automated route, not human/device acceptance.

## Fresh route

`godot --headless --fixed-fps 60 --path . --script tests/run_tests.gd -- --filter campaign_route`

PASS: all eight rooms, Oru introduction, checkpoints A/B, distinct-player Spindle pair, ordinary gallery and boss attacks, team Threadstep/shortcut, both dash gaps, Causeway pair, Loom dialogue, paired return to r00 and the actual app ending card. The isolated saved campaign validates with Loom restoration present. Both couriers finish at 4/3 hearts and zero recoveries. The fixed-60 run used 9,758 controller-observed physics waits; it does not estimate human clear time or difficulty. A native unaccelerated run also finished; render observations are recorded separately.

Measured jump+dash paths for both characters: r01 launch approximately (715,257), landing (875,256); r06 (442,353) to (603,352), 37 physics waits each. Ground/air dash itself covers 72 px over 12 active ticks. Ordinary full-jump rise is 41.7414 px; short-jump rise 13.7414 px.

## Render-cap independence

`GLOAMTHREAD_RENDER_CAP=30 godot --headless --fixed-fps 30 --path . --script tests/run_tests.gd -- --filter movement_boundaries`

Repeated at 60 and 144. Tick-indexed producer/observer nodes avoid render-coroutine timing. All three runs PASS six-tick coyote/buffer boundaries, seventh-tick expiry, short/full jumps, one-way ascent and per-player drop-through, and solid corners. The same 600-physics-tick replay matches every actor sample exactly (0.0 px maximum deviation), health [5,4] and shared Threadstep state. This is same-machine behaviour, not cross-platform deterministic physics.

## Isolated interaction regressions

`session_transactions` uses labelled controlled fixtures for revive at tick90, timeout at720, rescuer interruption, revive-vs-timeout priority, boss reward before wipe, distinct anchors and single exit transaction. `secret_progression` uses labelled controlled placement to collect the charm once, hide it immediately, attach both cosmetics, preserve it through real save/Continue and keep theme swaps independent of simulation. These are separate from the complete ordinary-input campaign.
