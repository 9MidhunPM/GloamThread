# Project submission record

Not submitted to organizers. This records the current runnable scrolling arena playtest and its evidence.

- Project: **Gloamthread — wave arena**, an original solo/two-player local side-view fighter. Twenty waves, four bosses, personal coins/upgrades, independent shops, revival, six ability families and optional endless. A seeded world expands from four to sixteen screens with raised trails, shallow caves, loot and landmarks; nearby views merge and separated players receive independent views in a fullscreen 1920×1080 design.
- Participant: **Midhun P M**, GitHub `9MidhunPM`; product direction and agent supervision. Fresh human playtests remain pending.
- Repository: [9MidhunPM/GloamThread](https://github.com/9MidhunPM/GloamThread).
- Packaged implementation: [`26c56b48abe4a7154e2546f86f4659f3d18b24aa`](https://github.com/9MidhunPM/GloamThread/commit/26c56b48abe4a7154e2546f86f4659f3d18b24aa). Subsequent documentation records checks without attributing later implementation to this executable.
- Download: [v0.3.0-world playtest](https://github.com/9MidhunPM/GloamThread/releases/tag/v0.3.0-world), Linux x86_64 ZIP and checksum. Archive SHA-256: `03ec3298d053ca06032ebc4eb5d48427b2e4cc3b16f0706a5db23b6bc420b9f8`. `BUILD.json` records the source tree and all payload hashes; all 30 archive entries were checked; GitHub’s uploaded archive digest matches.
- Launch: extract the complete ZIP, `chmod +x Gloamthread.x86_64`, then `./Gloamthread.x86_64`. Wayland can add `--display-driver wayland`; X11 can add `--display-driver x11`. Built-in and accepted fighters need no editor, Python, key, account or network to play. [Controls and authoring setup](docs/ARENA_DEMO.md).
- Walkthrough: choose Solo Run or Local Co-op, select distinct inputs/fighters, start, hold basic attacks and use jump/dodge/special. Buy upgrades or Explore between waves; E/M/Y reopens your own shop and all active players must Ready. Regions open after waves 5/10/15. Discover landmarks, attack caches and collect healing plants. Beat the wave 20 boss, then optionally continue endless. Run power resets on defeat/restart; creations/settings/scores persist.
- Character creation: draw/import original artwork, review the proposed body/family/theme, generate and inspect animation, correct cached crops/masks/pivots, then accept locally. Optional OpenAI authoring uses `gpt-6-luna` and `gpt-image-1-mini` low with a private local key and retained provenance. The configured total allowance is separate from the $0.50 character maximum; reservations survive jobs and corrections make no model calls. The reviewed generated Kiln Fox ships alongside Cinderjack and Thistlepaw. The user's recovered Wizard is private in the local library and excluded from this package.
- Checks: Godot 4.7.2 import, 19 arena scenarios, 162 creator assertions, 186 Python tests and content/world/media validators pass. Source solo 20/co-op 25 routes cover the full map without game-state overrides. The final official Linux QA export completes 25 waves offline outside the checkout in 52,184 ticks with all four regions/landmarks, 15 loot and no route/engine errors. The normal packaged game separately boots offline and its actual native title was inspected. [Exact evidence and commands](evidence/scrolling-world/README.md).
- Limits: physical controllers/hotplug, keyboard rollover, audio listening, fresh-human balance/enjoyment/clear time and other hardware/distributions are unverified. Native split-combat p95 was 24.522 ms offscreen; this is not physical scanout FPS or a 60 FPS guarantee. Generation outputs can require manual correction. Forced 30-frame normal boot exit warns about two audio ObjectDB instances without script/resource errors.
- Technology: Godot 4.7.2 standard (MIT), Python/Pillow/NumPy authoring and optional official OpenAI SDK. Game assets are original authoring or retained original generation with provenance; no resource packs or downloaded replacements. [Notices](THIRD_PARTY_NOTICES.md).
- Development and assistance: [CHANGELOG](CHANGELOG.md), [AI_USAGE](AI_USAGE.md). Real authorship, timestamps and development history are preserved; human review is pending.

## Historical demos

[v0.2.0-arena](https://github.com/9MidhunPM/GloamThread/releases/tag/v0.2.0-arena) preserves the earlier shared-screen wave game at `4e6fd56f2e1971c2be7aec1205f10f6b742495eb`, with [separate evidence](evidence/arena-runtime/README.md).

[v0.1.0-demo](https://github.com/9MidhunPM/GloamThread/releases/tag/v0.1.0-demo) preserves the eight-room story at `34ccb9614cacb4d423c2ef29f85e4a8391841ca1`, with [separate evidence](evidence/release/README.md).

## Event status

Current guidance is **Devin Hack Kochi** in [RULES.md](RULES.md). Organizer eligibility, participation format, submission method and timing have not been certified or completed here. Publishing this GitHub playtest is not an organizer-submission claim.
