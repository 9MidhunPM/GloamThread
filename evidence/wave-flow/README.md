# Wave-one stall and fast replenishment

A pre-fix controlled real-session probe (seed18427) placed a chaser at(580,624) and the fighter at(270,320). The enemy was invisible,434.18px away, and still received zero catch-up warnings after240 pursuit ticks. Spawn sampling repeatedly selected cave anchors. The720px spawn radius was entirely below the960px pursuit threshold.

The fix prefers visible/same-elevation spawn anchors, catches up any continuously unseen enemy, and uses a16px camera margin. Normal warnings24ticks; queued arrival cadence at most18ticks, accepted kills release it, and empty fields request up to three warnings. Pending warnings count toward caps and reserve their positions. Countdown45ticks; clear24ticks. Shops still require every active player's Ready.

Godot4.7.2 /60Hz /headless, seed18427:

```sh
godot --headless --path . --script tests/arena/run_tests.gd -- --filter wave_flow
godot --headless --path . --fixed-fps 60 --script tools/arena_playthrough.gd -- --players 1 --waves 2 --seed 18427 --output /tmp/gloamthread-wave-two-route.json
godot --headless --path . --fixed-fps 60 --script tools/arena_playthrough.gd -- --players 2 --waves 2 --seed 18427 --output /tmp/gloamthread-wave-two-coop-route.json
```

- Focused fixture:1scenario passes,0failures. Controlled actor/session physics verify cave catch-up at180ticks plus42tick warning, preserved node/HP/reward identity, spawn timing/clearance/cap, and wave-one→shop→Ready→wave-two transitions.
- Ordinary-input bot: solo clears two waves in1198ticks; co-op clears two in2267ticks. Both pass with no route/engine errors. Real owned keyboard snapshots and shop calls; no actor health/position/currency/timer writes. JSON reports retain exact source hashes.
- No model/API calls. These are focused source checks, not physical gamepad/human play, visible-render QA, performance measurement, a full20-wave rerun or a new exported release. The older published ZIP does not contain this patch.
