# Scrolling-world evidence

Godot 4.7.2 standard/Compatibility on Arch Linux, 25 October 2026. This directory concerns the expanding wave game, not the historical story release.

## Source acceptance

Commands: `godot --headless --path . --editor --import --quit`; `godot --headless --fixed-fps 60 --path . --script tests/arena/run_tests.gd`; the equivalent creator runner `tests/forge/run_tests.gd`; `python3 -m unittest discover -s tools/tests -p 'test_*.py'`; `python3 -m tools.forge.content --validate`, plus `tools.forge.world` and `tools.forge.scenery` validators. Results: 19 arena scenarios, 162 creator assertions, 186 Python tests pass. `checks.json` retains log hashes/summaries and redacted generation accounting.

`ordinary-solo.json` and `ordinary-duo.json` are actual production-App routes using owned synthetic movement/jump/attack/dodge/revive and shop intents. No position/health/damage/currency/progression writes. Solo 20 (seed 18427): 37,872 ticks, all 4 regions/landmarks, 15 loot, furthest x 10,074. Co-op 25 (seed 1791860771): 49,092 ticks, 4 regions/landmarks, 15 loot, 98 split/merge changes, furthest x 10,167. All exploration legs reached, no engine errors or route errors. Random critical hits remain enabled. These bots read positions/cues and shop rapidly; duration does not establish human balance or enjoyment.

Reproduce with `godot --headless --fixed-fps 60 --path . --script tools/arena_playthrough.gd -- --players 2 --waves 25 --seed 1791860771 --output /tmp/route.json`; use players 1/waves 20/seed 18427 for solo.

## Native renderer

`native/` contains actual 1920×1080 Godot captures and source/capture hashes. Run `godot --path . --display-driver wayland --windowed --resolution 1920x1080 --script tools/scrolling_native_qa.gd -- --output /tmp/world-native --profile` on a quiet machine. The controlled fixtures explicitly place actors to isolate merged landmark, split main/cave, sixteen-chunk frontier and independent shop states. P1 also moves 135 pixels through owned input while P2 remains shopping. This is separate from normal-input route evidence.

Wayland/OpenGL Compatibility, Mesa Intel Graphics (ARL), hidden agent workspace with explicit offscreen force_draw. Final 10.12 second split fixture: 32 manually replenished wave-one actors, 77 projectiles observed, normal starter health/immunity; median 10.976 ms, p95 24.522 ms, p99 35.961 ms, max 47.679 ms. These intervals include engine/capture/fixture work and do not certify physical scanout FPS or universal 60 FPS. Replacement anchors are precomputed outside timing; actual wave-one concurrency is lower. Raw process/physics monitors are retained but may include earlier engine sampling windows.

Native review corrected toast/minimap overlap, missing frontier cues and sparse cave detail. Gameplay review fixed held-ready input, freed/revealed pursuit targets, strict layer admission and flyers trapped by ceilings/open platforms. A negative media fixture's shallow cache copy was corrected so it cannot poison later scenarios. No fabricated captures, human tests or timing numbers.

## Budget recovery

The existing blocked job made exactly two image calls after the approved $2 total setting, retaining earlier reservations. Development ledger: $0.55 reserved, $1.45 remaining, $0.50 job maximum; reservations are not actual billing. Explicit crop correction and native preview/acceptance passed under network isolation with no new requests. The private drawing/generated Wizard is installed only in the local fighter library and is intentionally not retained here. Source mocks use temporary job roots.

## Limits

Physical input hardware/hotplug/rollover, audio listening, fresh-human balance/clear time/fun and other hardware remain unverified. Export/package evidence must name its exact committed source separately from these source checks.
