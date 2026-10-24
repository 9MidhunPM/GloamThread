# Movement envelope for Agent 2

Measured with Godot `4.7.2.stable.arch_linux.ed1daf0bf`, 60 Hz real physics, the shared session and the authored diagnostic r00 from content commit `34e14c9`. Command:

```sh
godot --headless --fixed-fps 60 --path . --script tests/run_tests.gd --log-file /tmp/gloamthread-content-session.log -- --filter content_session
```

The scenario resets to an explicit safe location for isolated measurement; it is not a normal-control full-route playthrough. It holds jump for a full leap and uses a running start through owned command snapshots for the horizontal measurement. These are measured feet positions on flat ground, not a certified maximum obstacle gap.

| Measurement | Result |
| --- | --- |
| Full jump feet rise | 41.74 px (about 2.61 tiles) |
| Running same-height jump feet travel | 55.00 px (about 3.44 tiles) |
| Airborne interval | 30 physics ticks |
| Collider | 12 px wide × 24 px tall, origin at feet |
| Minimum full-jump body clearance from floor | 66 px under this flat-ground measurement |
| Dash reach | Not implemented or measured yet |

Motor configuration: gravity 1400 px/s², jump velocity -330 px/s, maximum horizontal speed 110 px/s, ground acceleration 900 px/s², air acceleration 600 px/s², maximum fall 400 px/s, jump-release cut -140 px/s, six-tick coyote time and six-tick buffer. Discrete Godot stepping/contact margin makes the measured result differ from a continuous-trajectory estimate.

For initial authored ordinary routes, keep required rises at most two tiles (32 px). Use conservative one-tile combined rise/gap steps and at most two-tile flat gaps until the actual room geometry passes traversal tests. Provide at least two tiles of standing clearance, and prefer five tiles (80 px) above the takeoff floor where a full uncut jump must fit. Extra headroom near corners helps avoid misleading jumps. Coyote time, damage boosts, overlap exploits and pixel-perfect edge launches must not be required.

The 10-tile remembered gate and 9-tile causeway gap are not yet certified by a dash measurement. Keep their final gap geometry provisional until Threadstep has a measured actual-physics envelope. Every mandatory jump/dash/anchor route still needs both-character traversal and ordinary-input review in the real room.
