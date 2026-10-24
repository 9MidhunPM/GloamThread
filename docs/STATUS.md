# Implementation status

Updated 2026-10-25T00:09:58+05:30. The implemented Phase 1 game is in final release-candidate verification. Fresh human/controller acceptance is separate.

## Implemented and verified

- Eight authored rooms, Tavi/Neri, two render-only themes over one shared world, Oru/dialogue, two ordinary enemy types, Spoolwarden, both specials, optional Cross-stitch, revive/recovery, checkpoints, distinct-player anchors, exit rally, Threadstep/shortcut, cosmetic secret, Loom and actual return-home ending/replay.
- Title/New/Continue, explicit input/character assignment, per-owner pause/map/dialogue/settings, remapping/deadzone, volume/reduced effects and reconnect. Save failures remain visible and keep the campaign open before title/quit; explicit retry/discard choices are tested. Missing saved pads choose distinct available inputs. Disconnect cancels remapping and transfers menu control safely.
- Strict catalogs eagerly resolve original resources before play. All47 manifested original art/audio/font outputs and all8rooms validate;79 Python tests pass. Editable generators/provenance remain in the repository.
- **18 engine scenarios PASS**, including actual files and the actual-App ordinary-input campaign to ending (both alive, no recovery). Isolated fixtures test recovery/transactions/secret without being counted as the full route. Fresh staged-copy core import/test also passed.
- Movement boundaries PASS at30/60/144 caps: six-tick coyote/buffer, seventh-tick expiry, short/full jumps, one-way/corner handling. The same600physics-tick input trace matches exactly on this machine. See [campaign evidence](../evidence/runtime/campaign.md).
- Native source/Wayland and official Linux release/X11 automated routes reach the actual ending card with real frame-post-draw captures. The X11 release QA measured120FPS median through r05 on Intel Core Ultra7 255H / Mesa Intel ARL; exact raw samples, window dimensions and preliminary-build limits are being retained for final evidence. Source/Wayland was slower and is not the recommended baseline.
- Full content true merge is `822aac2`; the separate UI core `c5b061f` is integrated with AppController. History and actual identities/timestamps remain intact on the authorized `9MidhunPM/GloamThread` remote.

## Release work in progress

- Matching official4.7.2 standard Linux templates are installed; official archive SHA256 verified. Linux/QA export presets work. Final shipping export, outside-checkout network-isolated route, package checksum, exact implementation SHA and release/main publication are next.
- Agent2's extended rendered menu-layout QA is being integrated cumulatively. User-facing original-font states are reviewed at native resolution; no source preview is treated as gameplay evidence.

## Unverified acceptance

- Physical gamepads/hotplug, keyboard hardware rollover, audio listening and fresh two-person playtests are unavailable. Software input/reconnect and single-event audio tests do not establish those gates.
- Human first-clear time, balance, clarity for new pairs and enjoyment remain unverified. The15–20minute target is not a measured result. Ship as a candidate for playtesting, not a fully accepted MVP.
- Final shipping binary's offline/manual/performance acceptance is distinct from preliminary QA exports. No Phase2/3 work is included; the older single-player HTML proof passes no co-op gate.

Current event guidance is **Devin Hack Kochi** in [RULES.md](../RULES.md). The [runtime](AGENT_1_RUNTIME.md) and [content](AGENT_2_CONTENT.md) briefs record separate-checkout ownership. Older M0 notes in HANDOFF are historical.
