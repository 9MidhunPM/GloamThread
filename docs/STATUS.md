# Implementation status

Active product: **solo/two-player shared-screen wave fighter**, approved 25 October 2026. [Contract](WAVE_FIGHTER_SPEC.md), [Agent 2 brief](AGENT_2_WAVE_CONTENT.md), [play guide](ARENA_DEMO.md). The earlier campaign and overhead implementations remain historical.

## Implemented

Fullscreen 1920×1080 UI with a shared 640×360 pixel arena; owned solo/duo inputs; held attacks, jump, dodge and six distinct ability families; six enemy roles and four bosses; twenty waves, four stages and optional endless. Personal last-hit coins, both-player clear bonuses, concurrent shops, ready/reset, hold-to-revive, wave-clear revival and team wipe are session-owned. Saved creations/settings/scores are separate from run power.

The character forge supports drawing/import, editable model proposals, three body rigs, animation previews, mask/pivot edits, cached raw-board crop correction and atomic acceptance. Local corrections preserve earlier drafts/previews and make no model calls. Built-in and accepted fighters cross the same validated bundle boundary and remain playable offline. Generated textures provide scenery, floors, platforms and decorations without changing collision or abilities.

Three built-ins ship: Cinderjack, Thistlepaw and the reviewed generated **Kiln Fox**, now default P1. Its real source drawing, raw image pair, sanitized receipts, crop recipe, editable rig and provenance are retained and rebuild offline. All thirty-two animation poses were inspected. Generation quality across arbitrary drawings and all three body families is not established by this one reviewed pair.

## Verified

Godot 4.7.2 standard import and active suites pass: **12 arena scenarios, 154 creator assertions, 173 Python tests**, plus content/retained-source validators (20 waves, 4 arenas, 6 kits, 30 upgrades, 3 fighter bundles). These include same-tick independent shop input, actual-App defaults, revival/wipe, strict malformed bundle/layout rejection, real Godot-to-Python job serialization and local cached recovery.

Ordinary-input automated routes clear solo twenty waves and co-op twenty-five including the victory/endless transition, without health/position/damage/currency/progression overrides or engine errors. Native Wayland/OpenGL captures cover title, lobby, creator, combat and shops at 1920×1080; the final controlled 32-enemy/67-projectile fixture measured median 6.891 ms, p95 11.779 ms and p99 14.486 ms over ten seconds. This is explicit offscreen native rendering, not scanout FPS or a human playtest. [Evidence and commands](../evidence/arena-runtime/README.md).

An official Linux QA export has also completed twenty-five waves in a network namespace, and the normal package booted outside the checkout without networking. Those earlier export records predate the final generated default/correction UI; final package identity and its independent checks are recorded in [SUBMISSION.md](../SUBMISSION.md) when assembled.

## Live generation and budget

`gpt-6-luna` analysed the original fox drawing successfully. The first `gpt-image-1-mini` edit returned HTTP 403; after project model access was enabled, both real image edits succeeded. Strict conversion rejected the provider's nonconforming layout. Explicit local crops then produced the reviewed fighter and scenery without another request. The actual native correction UI → Python conversion → preview → acceptance also passed under network isolation, with an unchanged budget ledger.

The shared initial $0.50 experiment retains **$0.35 in conservative reservations**: one analysis, one denied/uncertain image attempt and two successful image calls. This is not an actual-billing claim. No automatic retry, model fallback, ledger reset or further paid experiment occurred. The remaining allowance cannot cover another complete two-image job; preflight rejects it before either request.

## Remaining acceptance

Physical controllers/hotplug, keyboard rollover, audio listening, fresh human balance/enjoyment, a measured human 10–15 minute clear and other hardware/distributions remain unverified. No organizer submission has been made. Current event guidance is **Devin Hack Kochi** in [RULES.md](../RULES.md).
