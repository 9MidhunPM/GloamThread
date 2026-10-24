# Project submission record

Not submitted to organizers. This records the current runnable arena playtest candidate and its evidence.

- Project: **Gloamthread — wave arena**, an original solo/two-player local side-view fighter. Twenty waves, four bosses, personal kill coins/upgrades, independent shops, revival, six ability families and optional endless share one 640×360 pixel world within a fullscreen 1920×1080 design.
- Participant: **Midhun P M**, GitHub `9MidhunPM`; product direction and agent supervision. Fresh human playtests remain pending.
- Repository: [9MidhunPM/GloamThread](https://github.com/9MidhunPM/GloamThread).
- Packaged implementation: [`4e6fd56f2e1971c2be7aec1205f10f6b742495eb`](https://github.com/9MidhunPM/GloamThread/commit/4e6fd56f2e1971c2be7aec1205f10f6b742495eb). Subsequent documentation records these checks; it adds no later gameplay to that executable.
- Download: [v0.2.0-arena playtest](https://github.com/9MidhunPM/GloamThread/releases/tag/v0.2.0-arena), Linux x86_64 ZIP and checksum. Archive SHA-256: `58c96e7c6c415f2253ac771eff501caa8f4251e02db46f73cb525ac96d378c74`; GitHub's uploaded digest matches. `BUILD.json` identifies the source tree and all payload hashes; all 28 archive entries were checked.
- Launch: extract the complete ZIP, `chmod +x Gloamthread.x86_64`, then `./Gloamthread.x86_64`. Wayland can add `--display-driver wayland`; X11 can add `--display-driver x11`. Built-in and accepted fighters need no editor, Python, key, account or network to play. [Controls and authoring setup](docs/ARENA_DEMO.md).
- Walkthrough: choose Solo Run or Local Co-op, select distinct inputs/fighters, start, hold basic attacks and use jump/dodge/special, buy upgrades and ready every active player between waves. Beat the bosses at waves 5/10/15/20, then optionally continue endless. Run power resets on defeat/restart; creations/settings/scores persist.
- Character creation: draw/import original artwork, review a proposed body/family/theme, generate and inspect animation, correct cached crops/masks/pivots, then accept locally. Optional OpenAI authoring uses `gpt-6-luna` and `gpt-image-1-mini` low with a private local key, bounded budget, retained provenance and no combat calls. The reviewed generated Kiln Fox and its forest/materials ship alongside Cinderjack and Thistlepaw; retained sources rebuild offline.
- Checks: Godot 4.7.2 import; 12 arena scenarios; 154 creator assertions; 173 Python tests; content/source validators. Generated-default solo clears 20 waves; final official Linux QA export clears 25 waves outside the checkout with networking disabled, real shop transactions and no state overrides, downs or engine errors. Actual native cached-layout correction → Python conversion → preview → acceptance passes offline with an unchanged ledger. Normal package boots offline and its visible fullscreen title was inspected. [Exact evidence](evidence/arena-runtime/README.md).
- Limits: physical controllers/hotplug, keyboard rollover, audio listening, fresh-human balance/enjoyment, a measured human 10–15 minute clear and other hardware/distributions are unverified. Native crowd timings are offscreen rendering observations, not scanout FPS. One live generated character/theme pair was reviewed; arbitrary outputs can require manual correction. Mini is scheduled to retire 1 December 2026, with no silent fallback. The forced 30-frame normal boot exit warns about two audio ObjectDB instances; no script/resource errors occurred.
- Technology: Godot 4.7.2 standard (MIT), Python/Pillow/NumPy authoring and optional official OpenAI SDK. Game assets are original project authoring or retained original generation with provenance; no resource packs or downloaded content replacements. [Notices](THIRD_PARTY_NOTICES.md).
- Development and assistance: [CHANGELOG](CHANGELOG.md), [AI_USAGE](AI_USAGE.md). Real authorship, timestamps and development history are preserved; human review is pending.

## Historical demo

[v0.1.0-demo](https://github.com/9MidhunPM/GloamThread/releases/tag/v0.1.0-demo) preserves the earlier eight-room, split-screen story implementation at `34ccb9614cacb4d423c2ef29f85e4a8391841ca1`. It is separate from the current arena, with [its own evidence](evidence/release/README.md).

## Event status

Current event guidance is **Devin Hack Kochi** in [RULES.md](RULES.md). Organizer eligibility, participation format, submission method and timing have not been certified or completed here. Publishing this GitHub playtest is not an organizer-submission claim.
