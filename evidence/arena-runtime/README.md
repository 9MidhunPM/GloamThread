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
