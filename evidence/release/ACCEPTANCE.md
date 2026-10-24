# Phase 1 candidate acceptance

Implementation source: `34ccb9614cacb4d423c2ef29f85e4a8391841ca1`. These rows separate software evidence from physical/human acceptance. **PARTIAL** means the software leg passed but a required manual/hardware leg remains unverified. This is a candidate for playtesting, not a fully accepted MVP.

| ID | Result | Evidence and limit |
| --- | --- | --- |
| A01 | PARTIAL | Actual App title/New/join/start, distinct inputs and native r00 capture pass; physical pair join unverified. |
| A02 | PARTIAL | Owned input isolation/simultaneous attacks pass; actual gamepad and keyboard rollover checks unverified. |
| A03 | PARTIAL | Synthetic disconnect/neutralization/reconnect/menu ownership/remap interruption pass; physical hotplug unavailable. |
| A04 | PARTIAL | Correct-slot remapping, conflict refusal, current HUD prompts, settings round trip and UI fixture inputs pass; physical remap check unverified. |
| A05 | PASS software | Shared World2D, one hit per attack and single boss HP state; native captures show both views of one encounter. |
| A06 | PASS software | Theme collision count zero; swapping themes changes no actor/HP/progression/collision state. |
| A07 | PARTIAL | Six-tick coyote/buffer, seventh expiry, short/full jump, one-way/drop/corners and600tick replay pass; human movement feel unverified. |
| A08 | PASS software | Single-swing dedup, independent simultaneous attacks, no friendly fire/body blocking. |
| A09 | PARTIAL | Damage/revive/reset immunity pass real physics scenarios; manual hazard handling unverified. |
| A10 | PASS software | Ember Arc, real wall-blocked/expiring Spore Bolt, enemy slow and boss immunity pass; native combat/effect capture retained. Human effect readability unverified. |
| A11 | PARTIAL | Distinct owned anchors, visible latch and single restored bridge/cue pass; two-human puzzle leg unverified. |
| A12 | PASS software | Same slot cannot substitute at both ends; completed state and real campaign save persist. |
| A13 | PARTIAL | Both living couriers must rally; simultaneous input produces one deferred transition; physical device leg unverified. |
| A14 | PARTIAL | Exact90tick revival,720tick timeout,2hearts+immunity pass; separate rendered countdown/manual rescue unverified. |
| A15 | PASS software | Damage, release and range interruptions reset the channel. |
| A16 | PASS software | One recovery transaction heals both, resets transients and retains permanent outcomes. |
| A17 | PARTIAL | Shared menu/dialogue/pause/reconnect timers freeze and edges flush in scenarios; physical focus/hotplug combinations unverified. |
| A18 | PASS software | Ordinary slash-only boss defeat without Cross-stitch; either setup/follow-up order and once/window bonus pass. |
| A19 | PASS software | Atomic boss/Threadstep/shortcut grant, persistence validation and same-tick wipe priority pass. |
| A20 | PARTIAL | Locked ability/gated data and post-unlock normal-input traversal by both pass; pre-unlock physical attempt and human dash comfort unverified. |
| A21 | PARTIAL | Full ordinary-input App route restores Causeway/Loom and returns to actual ending; fresh two-human route unverified. |
| A22 | PASS software | Simultaneous secret pickup once, immediate hidden prop, two cosmetic charms, unchanged stats/collision and save/Continue/revisit pass. |
| A23 | PASS software | Actual-file safe checkpoint/profile/flag load; independent settings and controls. |
| A24 | PASS software | Missing/orphaned backup/corrupt/truncated/newer saves, rejected-copy preservation and explicit recovery pass. |
| A25 | PASS software | Faulted writes retain previous valid data; visible queued error and title/quit retry/discard flows preserve live progress. |
| A26 | PARTIAL | Original themes/floors/actors/HUD/boss/ending reviewed in real1x frames; exact2x UI pixel scaling passes. Fresh-pair readability unverified. |
| A27 | PARTIAL | Single semantic emission, pause/gain/loop and saved volumes pass; actual audio listening/device/muted-human acceptance unverified. |
| A28 | PARTIAL | Final package integrity passes; same-source official release QA completes outside checkout with no network routes/addresses. QA runner is additional to shipping resources; two-human offline leg remains unverified. |
| A29 | PASS measured software | Exact-source official release native Wayland,1920x720,2,650r05samples: median120FPS/p95frame8.333ms/max33.331ms on named laptop. Raw report retained; no GPU-time/universal-hardware claim. |
| A30 | UNVERIFIED | No fresh pairs observed. Human first-clear time, balance, confusion and enjoyment remain unknown. |

Scenario commands and movement details are in [campaign evidence](../runtime/campaign.md). Native UI fixtures are separate [component evidence](../content/ui/README.md). Final export/build data and captures are recorded in [release verification](README.md).
