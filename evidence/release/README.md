# Preserved side-view Linux milestone

Recorded 2026-10-25T00:53:13+05:30. The user has now requested an overhead adventure; this evidence preserves the verified side-view milestone and is not evidence for the upcoming rewrite.

## Exact build

Implementation: `34ccb9614cacb4d423c2ef29f85e4a8391841ca1`. The shipping ZIP is31,863,795bytes (about31MB), SHA256 `654871d29a60c71d823bd9c23bf1c1cc0591709043f664d4b425b9054bd2481c`. [BUILD.json](BUILD.json) records executable SHA256 `3a558a6c9d075bcfa3eafb71798cfe4fba17a9b9c25f0a1f044f445b13e7aacc`. It contains the standalone official Godot4.7.2 Linux x86_64 release, README, provenance and full engine notices. Archive CRC/inventory/hash checks pass; shipping export logs contain no tests, QA tools, UI preview, source generators or diagnostic art. The QA export adds its runner/resources and selects a test main loop; its gameplay code/assets are from the same immutable source.

## Commands and outcomes

- `python3 tools/package_linux.py` — clean-commit import, shipping Linux export, explicit inventory ZIP and checksums PASS. The script rejects engine errors and dirty tracked source.
- `godot --headless --path . --export-release "Linux QA" build/qa/Gloamthread-QA.x86_64` — same-source official release QA export PASS.
- Copied QA executable to `/tmp/gloamthread-installed-qa-34ccb96/`; launched outside checkout through `unshare -Urn`, native Wayland, no fixed-FPS acceleration. Its namespace had only down loopback, no interface addresses and no routes. Namespace/network metadata are retained beside this file. The host remained online for GitHub publication.
- `GLOAMTHREAD_QA_OUTPUT=/tmp/gloamthread-final34-offline-qa GLOAMTHREAD_QA_COMMIT=34ccb9614cacb4d423c2ef29f85e4a8391841ca1 ./Gloamthread-QA.x86_64 --display-driver wayland` — actual App title/join/New, all8rooms, combat/checkpoints/anchors, boss/dash/Loom and actual return-home ending PASS. The owned-input bot uses normal movement/attack/interaction and actual UI intents; no actor warps, direct damage or forced rewards. It finishes at4/3hearts with zero recoveries; saved campaign validates. [Raw report](report.json) and11real frame-post-draw [captures](captures/ending.png) retained.
- `godot --headless --fixed-fps60 --path . --script tests/run_tests.gd` (use separate `--fixed-fps 60` tokens) —20/20scenarios PASS, no script/resource errors; expected negative-input warnings only.
- Full asset/content validators, preflight,79Python tests, pack links and whitespace PASS. [Movement replay](render-cap-comparison.json) matches600physics ticks at30/60/144 render caps on this machine.

## Performance

Official release template, Compatibility/OpenGL, native Wayland, Intel Core Ultra7 255H / Mesa Intel ARL,60Hz physics, two480x360 views,1920x720 client during all2,650r05samples. Max render cap144, VSync setting1. Engine FPS median120 (min115); process-frame delta median/p95=8.333ms, max33.331ms. CPU physics median2.575ms/p95=4.322ms; CPU process median2.452ms/p95=15.234ms. These are engine/process observations, not GPU timings or a universal hardware guarantee. PNG capture samples are flagged in raw data. A slower earlier Arch editor/source run is not conflated with this official-release result.

Only expected Wayland icon-protocol warning appears in this run. An earlier isolated X11 attempt could not access the host's abstract socket and fell back to Wayland; final QA requests Wayland directly. An immediate forced CLI shutdown smoke can print2audio playback retirement warnings; scenario/native-route teardown waits for the mixing thread and exits cleanly.

## Acceptance limits

[Full matrix](ACCEPTANCE.md). Physical controllers/hotplug, keyboard hardware rollover, audio listening, fresh pairs, human clear time, balance and enjoyment remain unverified. No two-human result or fully accepted MVP claim is made. New overhead gameplay must earn its own evidence.
