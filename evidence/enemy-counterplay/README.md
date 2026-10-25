# Enemy counterplay evidence

25 October 2026, Godot 4.7.2 standard/Compatibility on Arch Linux.

Source commands: `godot --headless --path . --editor --import --quit`; `godot --headless --fixed-fps 60 --path . --script tests/arena/run_tests.gd`; the equivalent creator runner `tests/forge/run_tests.gd`; `python3 -m unittest discover -s tools/tests -p 'test_*.py'`. Results: **21 arena scenarios**, **173 creator assertions**, **187 Python tests** pass. `checks.json` retains log hashes and summaries. The new mechanics scenario covers tells, committed aim, guard counters, hit origins, one-hit contacts/rewards, burst timing, shared pause and flyers committed across changing occlusion; existing cave routes and boss/kit tests still pass.

`ordinary-solo.json` clears 20 waves in 36,998 ticks; `ordinary-duo.json` clears 25 including endless in 50,023 ticks. Production App, owned synthetic inputs and real shop transactions are used without actor/health/wallet/progression overrides. Both have no route/engine errors and retain source hashes; random crits remain enabled. Reproduce with `godot --headless --fixed-fps 60 --path . --script tools/arena_playthrough.gd -- --players 2 --waves 25 --seed 1791860771 --output /tmp/route.json`; use players 1/waves 20/seed 18427 for solo. These are bots, not human balance/playtime/fun claims.

`native/` contains four actual 1920×1080 Wayland captures of charge tell/recovery, heavy guard/counter window, shooter aim/burst and flyer mark/dive. Run `godot --path . --display-driver wayland --rendering-method gl_compatibility --fixed-fps 60 --resolution 1920x1080 --script tools/enemy_native_qa.gd -- --output /tmp/enemy-captures`. The controlled fixture explicitly places paired actors/states, freezes encounter/player and uses fixture immunity while stepping real actor/projectile physics. It uses one production App/session/world and temporary settings/records. Captures/source hashes match; errors are empty and all cues were inspected. Hidden-workspace offscreen force_draw is separate from normal input, physical scanout FPS and human tests.

Creator correction/acceptance and uncapped accounting are covered in [separate recovery evidence](../creator-recovery/README.md). Private generated artwork/drawings/jobs are excluded. Physical controllers, listening, human difficulty/enjoyment and other hardware remain unverified; no new performance guarantee is made. Final exported checks must identify their exact committed source separately.


## Published package

[v0.4.0-counterplay](https://github.com/9MidhunPM/GloamThread/releases/tag/v0.4.0-counterplay) packages implementation `a65bf14a2a2676a290aab7505bf2cca5fcf4fede`. Archive SHA-256: `a1960a34bfbd01342e23eb30cfa61f91c46c1222df2f9afaa5ea76e91d1ee6e8`. `package-integrity.json` records all 30 entries/payload hashes, and `published-release.json` records GitHub's matching digest. Credentials, environments, user jobs and private artwork are excluded.

The official QA export completes 25 waves in **50,487 ticks**, outside the checkout with networking disabled, no state overrides and no route/engine errors. `exported-offline-duo.json` and `exported-network.json` retain the route, exact binary hash and `/tmp` execution with only a down loopback and no addresses/routes. Export `Linux QA`, copy it to `/tmp/Gloamthread-Counterplay-QA.x86_64`, then run `unshare --user --map-root-user --net /tmp/Gloamthread-Counterplay-QA.x86_64 --headless --fixed-fps 60 -- --players 2 --waves 25 --seed 1791860771 --output /tmp/route.json` to reproduce.

The normal release separately boots offline (`normal-offline.json`); forced 30-frame exit retains the known two audio ObjectDB exit warnings without script/resource errors. Later documentation records the packaged source identity without adding gameplay to that executable. Further optional tests were skipped at the user's request.
