# Enemy mechanics and counterplay

The six existing roles remain; four now require distinct responses. These changes preserve shared health, kill ownership, wave counts, concurrency caps and terrain routing. Timers use the shared 60 Hz physics clock and stop during pause.

| Enemy | Tell and commitment | Counter |
| --- | --- | --- |
| Charger | A 36-tick amber lane tell turns red near activation. Its direction locks, then it rushes at most 112 logical pixels over 24 ticks. | Jump or dodge across/behind the announced lane. A miss or wall impact stops it and leaves 52 ticks of recovery. |
| Heavy | Frontal amber guard absorbs 65% of direct damage during approach/early windup. It lowers the guard for the final 18 windup ticks and recovery; broken brackets appear teal. | Bait its committed swing, flank with a partner, or use freeze/strong stagger. A rear/control counter breaks the stance and receives a 25% damage bonus; damage over time bypasses the guard. |
| Shooter | Brakes for a 32-tick dashed aim tell, locks aim, then fires three shots nine ticks apart. Each shot has 70% of its previous single-shot damage. | Move off the announced line, use cover or close distance. It cannot turn the burst to follow you and has 48 ticks of recovery. |
| Flyer | Marks a landing point for 34 ticks, then commits to that direction and retreats for 50 ticks. Moving behind terrain cannot rewrite the announced attack. | Leave the mark before activation. Solid contact stops the dive; open one-way planks remain permeable. |

Swarm/chaser pressure and the four existing boss pattern sets remain. These mechanics add choices rather than health inflation. Friendly melee/area/projectile/chain packets carry their actual contact origin, so a heavy's guard uses the arriving hit direction even if the attacker moved elsewhere. Swing hit deduplication, damage-over-time source ownership and single lethal rewards remain authoritative.

`enemy_mechanics.gd` uses actual actors/physics for committed directions, whiff/wall recovery, guard/control/rear windows, piercing/chain hit direction, burst timing, shared pause, one-hit contacts and a target moving behind terrain during a flyer tell/dive. Existing projectile, kit, terrain and boss scenarios remain part of the full suite. Native paired snapshots isolate actual rendered cues, while ordinary-input solo/co-op routes check whole-run integration. None establishes fresh-human balance or enjoyment. [Commands and captured evidence](../evidence/enemy-counterplay/README.md).
